"""dehyphenate_ocr_aggressive — OCR-aware reversible end-of-line de-hyphenation.

Complements :mod:`postprocessing.steps.dehyphenate` by rescuing the
hyphenation cases that fail the strict lexicon check of
``dehyphenate_with_log`` because of OCR noise inside one of the
fragments. Order in the plugin pipeline matters: this step is
expected to run **after** ``dehyphenate_with_log`` so it inherits
the still-pending hyphenations.

Algorithm.

1. Walk the document tree in pre-order DFS.
2. For every :class:`Node` with a non-``None`` ``text``, scan for
   end-of-line hyphenations matching an **extended** regex
   ``([a-zA-Zàèéìòù0-9]+)[-­]\n([a-zA-Zàèéìòù0-9]+)``. The
   extended class admits digits because OCR-corrupted fragments
   carry digits inside word boundaries (e.g. ``paga-\\n1nenlo``).
3. Skip the match when:

   - both fragments are pure digits (numeric range like
     ``113-330``);
   - the pair ``(prefix, suffix)`` is in the closed preservative
     list :func:`ocr_substitutions.is_hyphen_preservative` (legal
     compounds like ``decreto-legge``).

4. Form ``candidate = (prefix + suffix).lower()`` and consult the
   lexicon. If known, accept the literal join (case-preserved).
5. Otherwise call :func:`ocr_substitutions.memoised_find_correction`
   on the candidate. If a unique lexicon-valid OCR-corrected variant
   exists at the shortest reachable depth, accept the variant
   (case-preserved).
6. Otherwise skip — the hyphenation stays, no transformation is
   recorded.

Each accepted join is logged as a :class:`Transformation` with the
verbatim match (including the hyphen and the embedded ``\\n``) as
``original`` and the corrected join as ``normalized``. Substitutions
on the same Node are applied right-to-left so the recorded
``position`` remains a valid slice of the *pre-step* Node text.

Documented limitations.

- **Cross-Node hyphenation is not handled.** When the word-before
  lives in one Node and the word-after lives in another (multi-block
  paragraph fragments), the step does nothing.
- **Post-hyphen fragments shorter than two characters are rejected**
  as likely OCR noise, mirroring the conservative step.
- **Pure-digit pairs** are kept verbatim (the dash is interpreted
  as a numeric range separator, not a hyphenation).
"""

from __future__ import annotations

import dataclasses
import re

from scabopdf_pipeline.classification.types import ClassifiedBlock
from scabopdf_pipeline.extraction.types import ExtractionResult
from scabopdf_pipeline.postprocessing.lexicon import ItalianLexicon
from scabopdf_pipeline.postprocessing.ocr_substitutions import (
    apply_case_preserving,
    is_hyphen_preservative,
    memoised_find_correction,
)
from scabopdf_pipeline.postprocessing.types import Transformation
from scabopdf_pipeline.reconstruction.types import Document, Node, compute_note_length_category
from scabopdf_pipeline.schema.categories import SemanticCategory

STEP_ID = "dehyphenate_ocr_aggressive"
"""Registry key under which :func:`dehyphenate_ocr_aggressive` is registered."""

_HYPHENATION_REGEX = re.compile(
    "([a-zA-Zàèéìòù0-9]+)[-­]\n([a-zA-Zàèéìòù0-9]+)",
)
"""End-of-line hyphenation regex.

The letter classes are wider than the strict step's: digits are
admitted so OCR-corrupted fragments like ``paga`` followed by
``1nenlo`` get captured as candidates for further inspection.
"""

_MIN_POST_HYPHEN_LEN = 2
"""Minimum length of the post-newline fragment."""


def dehyphenate_ocr_aggressive(
    document: Document,
    extraction: ExtractionResult,
    classified_blocks: list[ClassifiedBlock],
    lexicon: ItalianLexicon | None = None,
) -> tuple[Document, tuple[Transformation, ...]]:
    """Apply OCR-aware reversible end-of-line de-hyphenation to ``document``.

    Parameters
    ----------
    document
        Document to scan. Treated as immutable.
    extraction
        Forwarded for signature symmetry; not consumed.
    classified_blocks
        Forwarded for signature symmetry; not consumed.
    lexicon
        Optional :class:`ItalianLexicon`. When ``None``, the default
        bundled-wordlist lexicon is used.

    Returns
    -------
    tuple[Document, tuple[Transformation, ...]]
        The (possibly new) document and the tuple of transformations
        this step recorded. When no substitution happens, the
        original ``document`` is returned and the tuple is empty.
    """
    del extraction, classified_blocks
    active_lexicon = lexicon if lexicon is not None else ItalianLexicon()
    transformations: list[Transformation] = []
    new_root = tuple(_process_node(node, active_lexicon, transformations) for node in document.root)
    unchanged = all(new is old for new, old in zip(new_root, document.root, strict=True))
    if unchanged and not transformations:
        return document, ()
    return dataclasses.replace(document, root=new_root), tuple(transformations)


def _process_node(
    node: Node,
    lexicon: ItalianLexicon,
    transformations: list[Transformation],
) -> Node:
    """Recursively rewrite ``node`` and its descendants."""
    new_children = tuple(_process_node(child, lexicon, transformations) for child in node.children)
    children_changed = any(
        new is not old for new, old in zip(new_children, node.children, strict=True)
    )
    if node.text is None:
        if children_changed:
            return dataclasses.replace(node, children=new_children)
        return node

    new_text, node_transformations = _dehyphenate_text(
        text=node.text,
        node_id=node.id,
        page_index=node.page_index,
        lexicon=lexicon,
    )
    if node_transformations:
        transformations.extend(node_transformations)

    if new_text == node.text and not children_changed:
        return node

    new_length_category = (
        compute_note_length_category(new_text)
        if node.category is SemanticCategory.NOTE
        else node.length_category
    )
    if new_text == node.text:
        return dataclasses.replace(node, children=new_children)
    return dataclasses.replace(
        node,
        text=new_text,
        children=new_children,
        length_category=new_length_category,
    )


def _dehyphenate_text(
    *,
    text: str,
    node_id: str,
    page_index: int,
    lexicon: ItalianLexicon,
) -> tuple[str, list[Transformation]]:
    """Apply OCR-aware de-hyphenation to a single string and produce its log."""
    accepted: list[tuple[re.Match[str], str]] = []
    for match in _HYPHENATION_REGEX.finditer(text):
        before, after = match.group(1), match.group(2)
        if len(after) < _MIN_POST_HYPHEN_LEN:
            continue
        if before.isdigit() and after.isdigit():
            # Numeric range (e.g. ``113-330``), not a hyphenation.
            continue
        if is_hyphen_preservative(before, after):
            continue
        candidate_lower = (before + after).lower()
        # Try the literal join first.
        if lexicon.is_known(candidate_lower):
            joined = apply_case_preserving(before + after, candidate_lower)
            accepted.append((match, joined))
            continue
        # Try OCR-corrected variants.
        correction = memoised_find_correction(candidate_lower, lexicon)
        if correction is None:
            continue
        # Project the casing of the literal join (prefix + suffix)
        # onto the OCR-corrected form. The literal join carries the
        # source casing so case preservation behaves identically on
        # the corrected output.
        normalized = apply_case_preserving(before + after, correction)
        accepted.append((match, normalized))

    if not accepted:
        return text, []

    transformations: list[Transformation] = [
        Transformation(
            step_id=STEP_ID,
            node_id=node_id,
            page_index=page_index,
            position=(match.start(), match.end()),
            original=match.group(0),
            normalized=normalized,
        )
        for match, normalized in accepted
    ]

    new_text = text
    for match, normalized in reversed(accepted):
        new_text = new_text[: match.start()] + normalized + new_text[match.end() :]

    return new_text, transformations
