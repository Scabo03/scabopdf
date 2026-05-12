"""dehyphenate_with_log — reversible end-of-line de-hyphenation.

See ARCHITECTURE.md § 7.2 for the canonical specification.

Algorithm.

1. Walk the document tree in pre-order DFS.
2. For every :class:`Node` with a non-``None`` ``text``, scan for
   end-of-line hyphenations matching the regex
   ``([letters]+)[-\\u00AD]\\n([letters]+)``. The letter class covers
   ASCII letters and the most common Italian accented vowels. ``+``
   is greedy and naturally caps at the first non-letter character, so
   the prose "max 30 characters back" bound from § 7.2 is enforced
   implicitly by the lexical structure of words.
3. For each match, form ``candidate = group1 + group2`` and consult
   the Italian lexicon (:class:`ItalianLexicon.is_known`,
   case-insensitive) to decide whether the join is legitimate.
4. If the candidate is a known word and the post-hyphen fragment has
   at least two characters, the substitution is recorded as a
   :class:`Transformation`. Otherwise the hyphen is left untouched and
   no transformation is logged.
5. After scanning, all accepted substitutions on the same Node are
   applied **right-to-left** so that each ``position`` recorded in the
   log remains a valid slice of the *pre-step* Node text. Layer 2
   reverts the log in reverse order.

Documented limitations.

- **Hyphenation across two Nodes is not handled.** When the
  word-before-the-hyphen lives in one Node and the
  word-after-the-newline lives in another (which can happen with
  cross-block paragraph fragments), the step does nothing on either
  Node. A future extension may walk the reading-order DFS and look at
  pairs of adjacent Nodes; v0.2 stays per-Node.
- **Candidates with the post-hyphen fragment shorter than two
  characters are rejected** as likely OCR noise.
- **Nodes with ``text is None``** (e.g. ``EMPTY_PAGE`` synthetic
  nodes) are skipped without any work or transformation.
- **Double newlines** (``-\\n\\n``) never match the regex: the
  pattern requires exactly one newline. Paragraph breaks are
  preserved.
- **The match is case-preserving**: ``"Evolu-\\nzione"`` → group 1
  ``"Evolu"`` and group 2 ``"zione"`` concatenate to ``"Evoluzione"``,
  while the lexicon lookup is case-insensitive.

The function is pure: it takes the current ``Document`` plus the raw
extraction artefacts and returns a new ``Document`` plus the tuple of
:class:`Transformation` recorded in this step. Subtrees that did not
change keep their identity, which lets the orchestrator detect "no
work happened" trivially.
"""

from __future__ import annotations

import dataclasses
import re

from scabopdf_pipeline.classification.types import ClassifiedBlock
from scabopdf_pipeline.extraction.types import ExtractionResult
from scabopdf_pipeline.postprocessing.lexicon import ItalianLexicon
from scabopdf_pipeline.postprocessing.types import Transformation
from scabopdf_pipeline.reconstruction.types import Document, Node

STEP_ID = "dehyphenate_with_log"
"""Registry key under which :func:`dehyphenate_with_log` is registered."""

_HYPHENATION_END_REGEX = re.compile("([a-zA-Zàèéìòù]+)[-\u00ad]\n([a-zA-Zàèéìòù]+)")
"""Regex that matches a single end-of-line hyphenation.

The hyphen character class accepts the ASCII ``-`` and the Unicode
soft hyphen ``U+00AD``. The newline is required to be a single ``\\n``;
``\\n\\n`` (paragraph break) does not match. The letter classes cover
ASCII letters and the most common Italian accented vowels.
"""

_MIN_POST_HYPHEN_LEN = 2
"""Minimum length of the post-newline fragment to accept a substitution.

Single-letter post-hyphen fragments are typically OCR noise or
mis-tokenised punctuation; rejecting them keeps the false-positive
rate low without losing meaningful joins.
"""


def dehyphenate_with_log(
    document: Document,
    extraction: ExtractionResult,
    classified_blocks: list[ClassifiedBlock],
    lexicon: ItalianLexicon | None = None,
) -> tuple[Document, tuple[Transformation, ...]]:
    """Apply reversible end-of-line de-hyphenation to ``document``.

    Parameters
    ----------
    document
        Document to scan. Treated as immutable; the result is a new
        :class:`Document` when at least one substitution happens, the
        same instance otherwise.
    extraction
        Forwarded for signature symmetry with the step protocol; not
        consumed by this step.
    classified_blocks
        Forwarded for signature symmetry; not consumed.
    lexicon
        Optional :class:`ItalianLexicon`. When ``None``, the default
        constructor is used (and pyspellchecker must be installed).
        Tests typically pass ``ItalianLexicon.from_word_set(...)`` for
        determinism.

    Returns
    -------
    tuple[Document, tuple[Transformation, ...]]
        The (possibly new) document and the tuple of transformations
        this step recorded. When no substitution happens, the original
        ``document`` is returned and the tuple is empty.
    """
    del extraction, classified_blocks
    if lexicon is None:
        lexicon = ItalianLexicon()

    new_transformations: list[Transformation] = []
    new_root = tuple(_process_node(node, lexicon, new_transformations) for node in document.root)

    unchanged = all(new is old for new, old in zip(new_root, document.root, strict=True))
    if unchanged and not new_transformations:
        return document, ()

    return dataclasses.replace(document, root=new_root), tuple(new_transformations)


def _process_node(
    node: Node,
    lexicon: ItalianLexicon,
    transformations: list[Transformation],
) -> Node:
    """Recursively rewrite ``node`` and its descendants, recording transformations.

    Returns the original ``node`` when neither the text nor any
    descendant changed; otherwise returns a frozen rebuilt copy.
    """
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
    if new_text == node.text:
        return dataclasses.replace(node, children=new_children)
    return dataclasses.replace(node, text=new_text, children=new_children)


def _dehyphenate_text(
    *,
    text: str,
    node_id: str,
    page_index: int,
    lexicon: ItalianLexicon,
) -> tuple[str, list[Transformation]]:
    """Apply de-hyphenation to a single string and produce its transformation log.

    Substitutions are applied right-to-left so that each recorded
    ``position`` remains a valid slice of the input ``text`` after the
    other substitutions are applied.
    """
    accepted: list[tuple[re.Match[str], str]] = []
    for match in _HYPHENATION_END_REGEX.finditer(text):
        before, after = match.group(1), match.group(2)
        if len(after) < _MIN_POST_HYPHEN_LEN:
            continue
        candidate = before + after
        if not lexicon.is_known(candidate):
            continue
        accepted.append((match, candidate))

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
