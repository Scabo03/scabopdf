"""normalize_ocr_with_dictionary — reversible OCR glyph normalisation.

Targets the four ``enciclopedia_storica`` calibrating fixtures and any
future plugin operating on OCR-noisy Italian text. The step has two
complementary mechanisms:

1. **Structural marker dictionary.** A closed table of known OCR
   fossilisations on structural marker words (LETTERATURA, FONTI and
   their variants) is applied unconditionally. Each substitution is
   logged as a :class:`Transformation`.

2. **Per-token lexicon-validated substitution.** For each word token
   in the text that is **not** already in the Italian lexicon, the
   step enumerates substitution variants (defined in
   :mod:`postprocessing.ocr_substitutions`) and applies a variant
   only when **exactly one** variant lands in the lexicon at the
   shortest reachable depth. This gives a high-precision /
   lower-recall correction profile that is the only safe choice for
   a step that ships in Layer 1 by default.

Reversibility. Each substitution is recorded as a
:class:`Transformation` with ``original`` carrying the verbatim
pre-step text slice and ``normalized`` carrying the replacement.
Layer 2 reverts the log by walking the transformations in reverse
order and restoring ``original`` at the recorded ``position``. The
order of recording inside the step is *left-to-right*, but the
application of the substitutions on the Node text is *right-to-left*
so that the recorded ``position`` remains a valid slice of the
pre-step text.

Categories. The step processes every Node whose ``text`` is not
``None`` and whose category is in the **text-bearing set** declared
in :data:`_TEXT_BEARING_CATEGORIES`. Synthetic nodes
(``EMPTY_PAGE``, ``ARTIFACT_FILIGREE`` and the like) are skipped.

Documented limitations.

- Tokens shorter than 4 characters are not corrected (see
  :data:`_MIN_TOKEN_LENGTH_FOR_SUBSTITUTION` in
  :mod:`ocr_substitutions`).
- The substitution table is empirical and intentionally narrow; OCR
  corruptions outside the closed substitution table are preserved
  verbatim. The plugin's classifier already retags the surrounding
  block category correctly via tolerant predicates, so leaving the
  raw text untouched is the right fallback.
- Cross-language tokens (German legal terms in Pandettistica voci,
  Latin formulas in classical Roman law voci) are not in the Italian
  lexicon and no substitution variant is either, so they survive
  intact.
"""

from __future__ import annotations

import dataclasses
import re

from scabopdf_pipeline.classification.types import ClassifiedBlock
from scabopdf_pipeline.extraction.types import ExtractionResult
from scabopdf_pipeline.postprocessing.lexicon import ItalianLexicon
from scabopdf_pipeline.postprocessing.ocr_substitutions import (
    apply_case_preserving,
    collect_contextual_rewrite_matches,
    get_structural_marker_dictionary,
    memoised_find_correction,
)
from scabopdf_pipeline.postprocessing.types import Transformation
from scabopdf_pipeline.reconstruction.types import Document, Node, compute_note_length_category
from scabopdf_pipeline.schema.categories import SemanticCategory

STEP_ID = "normalize_ocr_with_dictionary"
"""Registry key under which :func:`normalize_ocr_with_dictionary` is registered."""

_TOKEN_REGEX = re.compile(r"[A-Za-zÀ-ÿ0-9]+(?:[\-·][A-Za-zÀ-ÿ0-9]+)*")
"""Word-token regex used to find candidate substrings inside Node text.

The character class admits ASCII letters, Italian accented vowels and
digits (digits are needed because OCR-corrupted tokens often contain
digits). The optional inner ``[\\-·]`` group allows hyphenated and
mid-dot tokens to be treated as a single unit; the inner segments are
themselves scanned for substitutions when the whole token does not
already pass the lexicon check.
"""

_TEXT_BEARING_CATEGORIES: frozenset[SemanticCategory] = frozenset(
    {
        SemanticCategory.BODY,
        SemanticCategory.NOTE,
        SemanticCategory.TITLE,
        SemanticCategory.HEADING_1,
        SemanticCategory.HEADING_2,
        SemanticCategory.HEADING_3,
        SemanticCategory.HEADING_4,
        SemanticCategory.TOC_GENERAL,
        SemanticCategory.FONTI,
        SemanticCategory.LETTERATURA,
        SemanticCategory.SECTION_LABEL,
        SemanticCategory.UNCLASSIFIED,
        SemanticCategory.CHAPTER_SUMMARY,
        SemanticCategory.MARGINAL_GLOSS,
        SemanticCategory.MARGINAL_HEADING,
    }
)
"""Categories whose ``text`` is subject to OCR normalisation.

Artifact categories (footers, stamps, filigree, empty pages,
book-page anchors) and apparatus reference categories
(``CROSS_REFERENCE``) are excluded: their text is either pure
typographic noise (already stripped) or a marker that the apparatus
binding pass needs to see verbatim.
"""


def normalize_ocr_with_dictionary(
    document: Document,
    extraction: ExtractionResult,
    classified_blocks: list[ClassifiedBlock],
    lexicon: ItalianLexicon | None = None,
) -> tuple[Document, tuple[Transformation, ...]]:
    """Apply reversible OCR normalisation to text-bearing Nodes in ``document``.

    Parameters
    ----------
    document
        Document to scan. Treated as immutable; the result is a new
        :class:`Document` when at least one substitution happens,
        the same instance otherwise.
    extraction
        Forwarded for signature symmetry with the step protocol; not
        consumed.
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
    marker_dict = get_structural_marker_dictionary()

    transformations: list[Transformation] = []
    new_root = tuple(
        _process_node(node, active_lexicon, marker_dict, transformations) for node in document.root
    )
    unchanged = all(new is old for new, old in zip(new_root, document.root, strict=True))
    if unchanged and not transformations:
        return document, ()
    return dataclasses.replace(document, root=new_root), tuple(transformations)


def _process_node(
    node: Node,
    lexicon: ItalianLexicon,
    marker_dict: tuple[tuple[str, str], ...],
    transformations: list[Transformation],
) -> Node:
    """Recursively rewrite ``node`` and its descendants."""
    new_children = tuple(
        _process_node(child, lexicon, marker_dict, transformations) for child in node.children
    )
    children_changed = any(
        new is not old for new, old in zip(new_children, node.children, strict=True)
    )

    if node.text is None or node.category not in _TEXT_BEARING_CATEGORIES:
        if children_changed:
            return dataclasses.replace(node, children=new_children)
        return node

    new_text, node_transformations = _normalize_text(
        text=node.text,
        node_id=node.id,
        page_index=node.page_index,
        lexicon=lexicon,
        marker_dict=marker_dict,
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


def _normalize_text(
    *,
    text: str,
    node_id: str,
    page_index: int,
    lexicon: ItalianLexicon,
    marker_dict: tuple[tuple[str, str], ...],
) -> tuple[str, list[Transformation]]:
    """Apply OCR normalisation to a single string and return its log."""
    accepted: list[tuple[int, int, str, str]] = []

    # Pass 0 — contextual regex rewrites (unconditional, position-sensitive
    # numeric and typographic patterns: ``\d+o`` → ``\d+0`` (year/citation
    # closing zero confusion), trailing ``\d+·`` → ``\d+.`` (middle-dot
    # confusion in citation lists), ``art. ll<NN>`` → ``art. 11<NN>``
    # (roman-numeral-for-digit-pair confusion), ``•·`` ornament removal
    # at small-caps quoted-phrase boundaries, line-leading ``·`` strip
    # before uppercase). These patterns lie outside the per-token
    # lexicon-validated model of Pass 2 because the source tokens are
    # numeric or punctuation and never enter the Italian lexicon.
    for start, end, original, replaced, _description in collect_contextual_rewrite_matches(text):
        accepted.append((start, end, original, replaced))

    # Pass 1 — structural marker dictionary (unconditional).
    for corrupted, canonical in marker_dict:
        start = 0
        while True:
            idx = text.find(corrupted, start)
            if idx == -1:
                break
            accepted.append((idx, idx + len(corrupted), corrupted, canonical))
            start = idx + len(corrupted)

    # Pass 2 — lexicon-validated per-token substitution.
    blocked_ranges = sorted((start, end) for start, end, _, _ in accepted)
    for match in _TOKEN_REGEX.finditer(text):
        start, end = match.start(), match.end()
        if _overlaps_any(start, end, blocked_ranges):
            continue
        original = match.group(0)
        # Skip tokens that look like pure numeric runs or roman
        # numerals — they are not in the Italian lexicon and are not
        # OCR-corrupted body text.
        if original.isdigit():
            continue
        correction = memoised_find_correction(original, lexicon)
        if correction is None:
            continue
        normalized = apply_case_preserving(original, correction)
        if normalized == original:
            continue
        accepted.append((start, end, original, normalized))

    if not accepted:
        return text, []

    # Sort acceptances left-to-right; build Transformation log; apply
    # right-to-left so positions in the log stay valid against the
    # pre-step text.
    accepted.sort(key=lambda entry: entry[0])

    transformations: list[Transformation] = [
        Transformation(
            step_id=STEP_ID,
            node_id=node_id,
            page_index=page_index,
            position=(start, end),
            original=original,
            normalized=normalized,
        )
        for (start, end, original, normalized) in accepted
    ]

    new_text = text
    for start, end, _, normalized in reversed(accepted):
        new_text = new_text[:start] + normalized + new_text[end:]

    return new_text, transformations


def _overlaps_any(start: int, end: int, ranges: list[tuple[int, int]]) -> bool:
    """Return True iff ``[start, end)`` overlaps any range in ``ranges``."""
    return any(start < r_end and r_start < end for r_start, r_end in ranges)
