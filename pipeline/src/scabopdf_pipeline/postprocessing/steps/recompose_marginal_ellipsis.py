"""recompose_marginal_ellipsis — fuse marginal headings split by '...' markers.

See ARCHITECTURE.md § 7 for the canonical specification of the
post-processing phase. This module promotes the placeholder previously
listed in :data:`postprocessing.registry._PROFILE_SPECIFIC_PLACEHOLDERS`
to a real implementation, introduced together with the third corpus
plugin :class:`scabopdf_pipeline.profiles.manuale_utet_wolterskluwer.
ManualeUtetWolterskluwerProfile` (Mosconi-Campiglio treatise, UTET /
Wolters Kluwer 2024). Approximately 13 % of the marginal headings in
that manual are split across two consecutive nodes by a typographic
``...`` continuation marker that the original page layout uses to
signal that the marginal phrase continues on the next page.

Algorithm.

1. Walk the document tree depth-first, **pre-order**, collecting
   every ``MARGINAL_HEADING`` node in reading order regardless of
   tree position. The flat list ignores sibling boundaries: two
   marginals can chain across different parent nodes (e.g. one under
   a HEADING_3 paragraph at the end of page N and the continuation
   under a different HEADING_3 paragraph at the start of page N+1).
2. Scan the flat list for chains of two or more consecutive marginal
   nodes where the head segment ends with ``...`` (or U+2026) and
   each subsequent segment starts with ``...``. A chain terminates
   at the first segment that does not also end with ``...`` — that
   terminal segment carries the rest of the phrase. An open chain
   whose final segment also ends with ``...`` is treated as
   incomplete and left untouched.
3. For each detected chain, compute the merged head node:

   - ``id``, ``page_index``, ``level``, ``summary_items``,
     ``toc_items``, ``apparatus_refs`` and ``children`` are
     inherited from the head segment.
   - ``block_indices`` is the concatenation of every segment's
     ``block_indices``, preserving order. Layer 2 can therefore still
     trace the merged node back to every originating extraction block.
   - ``text`` is built by stripping the trailing marker from each
     non-terminal segment and the leading marker from each non-head
     segment, then joining the cleaned segments with a single ASCII
     space. Adjacent whitespace is absorbed by the stripping regex.

4. Rebuild the document tree: at the original tree position of each
   head segment substitute the merged node; at the original tree
   position of each absorbed segment remove the node. The tree's
   identity is preserved on every subtree that does not contain a
   merged or absorbed node.
5. A single :class:`Transformation` is recorded per chain, on the
   head node. It captures the textual change as an intra-Node
   substitution: ``position`` covers the trailing marker slice of the
   head node's pre-step text, ``original`` is the literal trailing
   match (``"..."``, U+2026, possibly with adjacent whitespace
   absorbed by the regex), and ``normalized`` is the substring of the
   post-step head text from the same start offset onward — the
   appended content contributed by the absorbed segments. Layer 2
   reverts the textual change by substituting ``original`` for the
   ``normalized`` slice at the recorded position. The pre-/post-text
   reversibility convention matches
   :class:`postprocessing.types.Transformation` exactly.

Reversibility scope.

The current :class:`Transformation` model records intra-Node text
substitutions. The marginal-ellipsis merge is structurally inter-Node:
the absorbed segments are removed from the tree, and their ``id``,
``page_index`` and tree position are not encoded in the log. The
recorded transformation lets Layer 2 restore the head node's text to
its pre-step value but does not let it rebuild the absorbed segments
as separate nodes. This is acceptable because the two-segment state
was a typographic layout artefact of cross-page continuation; the
fused single-Node state is the semantically correct representation
the editorial analysis confirms. A future schema bump extending
``Transformation`` with optional ``merged_from`` fields could provide
full structural reversibility; the current 0.4.0 schema does not.

Documented limitations.

- **Chains require a valid terminator.** A head segment ending in
  ``...`` with no following marginal in reading order starting in
  ``...``, or an open chain whose final non-terminal segment ends in
  ``...`` but is not followed by any marginal that doesn't, is left
  untouched. The corpus plugin's :meth:`refine_reconstruction` emits
  the appropriate diagnostic warnings during its own tree walk.
- **Absorbed segments' children are discarded.** Marginal nodes in
  Mosconi never carry children; the step does not attempt subtree
  merging.

The function is pure: it takes the current :class:`Document` plus the
raw extraction artefacts and returns a new :class:`Document` plus the
tuple of :class:`Transformation` recorded in this step. Subtrees that
did not change keep their identity, mirroring the convention of
:func:`postprocessing.steps.dehyphenate.dehyphenate_with_log`.
"""

from __future__ import annotations

import dataclasses
import re

from scabopdf_pipeline.classification.types import ClassifiedBlock
from scabopdf_pipeline.extraction.types import ExtractionResult
from scabopdf_pipeline.postprocessing.types import Transformation
from scabopdf_pipeline.reconstruction.types import Document, Node
from scabopdf_pipeline.schema.categories import SemanticCategory

STEP_ID = "recompose_marginal_ellipsis"
"""Registry key under which :func:`recompose_marginal_ellipsis` is registered."""

_TRAILING_ELLIPSIS = re.compile(r"\s*(?:\.\.\.|…)\s*$")
"""Regex matching the trailing continuation marker on a marginal heading.

The leading ``\\s*`` and trailing ``\\s*`` absorb any whitespace
adjacent to the marker so the captured slice covers the entire
continuation suffix of the head segment. The marker itself is either
three consecutive ASCII dots (``...``) or the Unicode horizontal
ellipsis character (``\\u2026``, U+2026): PyMuPDF can emit either
depending on the font and the text layer of the source PDF.
"""

_LEADING_ELLIPSIS = re.compile(r"^\s*(?:\.\.\.|…)\s*")
"""Regex matching the leading continuation marker on a marginal heading.

Symmetric to :data:`_TRAILING_ELLIPSIS`: accepts either ``...`` or
``\\u2026`` and absorbs adjacent whitespace so the cleaned segment
text never starts with stray spaces after the prefix is removed.
"""


def recompose_marginal_ellipsis(
    document: Document,
    extraction: ExtractionResult,
    classified_blocks: list[ClassifiedBlock],
) -> tuple[Document, tuple[Transformation, ...]]:
    """Fuse chains of MARGINAL_HEADING nodes split by ``...`` continuation markers.

    Parameters
    ----------
    document
        Document to process. Treated as immutable; the result is a new
        :class:`Document` when at least one chain is fused, the same
        instance otherwise.
    extraction
        Forwarded for signature symmetry with the step protocol; not
        consumed by this step.
    classified_blocks
        Forwarded for signature symmetry; not consumed.

    Returns
    -------
    tuple[Document, tuple[Transformation, ...]]
        The (possibly new) document and the tuple of transformations
        this step recorded. When no chain is merged, the original
        ``document`` is returned and the tuple is empty.
    """
    del extraction, classified_blocks
    marginals = _collect_marginals(document.root)
    chains = _find_chains(marginals)
    if not chains:
        return document, ()

    transformations: list[Transformation] = []
    replacements: dict[str, Node] = {}
    to_remove: set[str] = set()
    for chain in chains:
        head_replacement = _build_merged_head(chain, transformations)
        replacements[chain[0].id] = head_replacement
        for absorbed in chain[1:]:
            to_remove.add(absorbed.id)

    new_root = _rebuild_tree(document.root, replacements, to_remove)
    return dataclasses.replace(document, root=new_root), tuple(transformations)


def _collect_marginals(roots: tuple[Node, ...]) -> list[Node]:
    """Return every ``MARGINAL_HEADING`` node in DFS pre-order across the forest.

    The flat list ignores sibling boundaries: chains can cross any
    parent boundary because the editorial continuation is a layout
    property (the typesetter's ``...`` marker) independent of the
    semantic tree structure produced by tier 1 reconstruction.
    """
    out: list[Node] = []

    def _visit(node: Node) -> None:
        if node.category is SemanticCategory.MARGINAL_HEADING and node.text is not None:
            out.append(node)
        for child in node.children:
            _visit(child)

    for root in roots:
        _visit(root)
    return out


def _find_chains(marginals: list[Node]) -> list[list[Node]]:
    """Return the list of valid chains found in the flat reading-order list.

    A valid chain has length at least 2: a head segment whose text
    ends with ``...`` (or U+2026), followed by one or more marginals
    each starting with the same marker. The chain terminates at the
    first marginal that does not also end with the marker. An open
    chain whose final candidate segment also ends with the marker (no
    terminator found) is rejected.
    """
    chains: list[list[Node]] = []
    n = len(marginals)
    i = 0
    while i < n:
        head = marginals[i]
        assert head.text is not None
        if not _ends_with_ellipsis(head.text):
            i += 1
            continue
        chain: list[Node] = [head]
        j = i + 1
        terminated = False
        while j < n:
            nxt = marginals[j]
            assert nxt.text is not None
            if not _starts_with_ellipsis(nxt.text):
                break
            chain.append(nxt)
            if not _ends_with_ellipsis(nxt.text):
                terminated = True
                j += 1
                break
            j += 1
        if terminated:
            chains.append(chain)
            i = j
        else:
            i += 1
    return chains


def _build_merged_head(chain: list[Node], transformations: list[Transformation]) -> Node:
    """Return the merged head node and append the chain's Transformation entry."""
    assert len(chain) >= 2
    head = chain[0]
    assert head.text is not None

    cleaned_segments: list[str] = [_TRAILING_ELLIPSIS.sub("", head.text)]
    for segment in chain[1:-1]:
        assert segment.text is not None
        cleaned = _LEADING_ELLIPSIS.sub("", segment.text)
        cleaned = _TRAILING_ELLIPSIS.sub("", cleaned)
        cleaned_segments.append(cleaned)
    terminal = chain[-1]
    assert terminal.text is not None
    cleaned_segments.append(_LEADING_ELLIPSIS.sub("", terminal.text))

    merged_text = " ".join(seg.strip() for seg in cleaned_segments if seg.strip())

    trailing_match = _TRAILING_ELLIPSIS.search(head.text)
    assert trailing_match is not None
    position = (trailing_match.start(), trailing_match.end())
    original = trailing_match.group(0)
    normalized = merged_text[position[0] :]

    transformations.append(
        Transformation(
            step_id=STEP_ID,
            node_id=head.id,
            page_index=head.page_index,
            position=position,
            original=original,
            normalized=normalized,
        )
    )

    new_block_indices = head.block_indices
    for segment in chain[1:]:
        new_block_indices = new_block_indices + segment.block_indices

    return Node(
        id=head.id,
        category=head.category,
        children=head.children,
        page_index=head.page_index,
        block_indices=new_block_indices,
        text=merged_text,
        level=head.level,
        summary_items=head.summary_items,
        toc_items=head.toc_items,
        apparatus_refs=head.apparatus_refs,
    )


def _rebuild_tree(
    roots: tuple[Node, ...],
    replacements: dict[str, Node],
    to_remove: set[str],
) -> tuple[Node, ...]:
    """Walk the tree and substitute / drop nodes per the merge plan.

    Subtrees containing no merged head and no absorbed segment retain
    their identity (the same ``Node`` instance is returned).
    """

    def _rebuild_node(node: Node) -> Node | None:
        if node.id in to_remove:
            return None
        new_children = _rebuild_children(node.children)
        if node.id in replacements:
            replacement = replacements[node.id]
            return Node(
                id=replacement.id,
                category=replacement.category,
                children=new_children,
                page_index=replacement.page_index,
                block_indices=replacement.block_indices,
                text=replacement.text,
                level=replacement.level,
                summary_items=replacement.summary_items,
                toc_items=replacement.toc_items,
                apparatus_refs=replacement.apparatus_refs,
            )
        if new_children == node.children:
            return node
        return dataclasses.replace(node, children=new_children)

    def _rebuild_children(children: tuple[Node, ...]) -> tuple[Node, ...]:
        new: list[Node] = []
        changed = False
        for child in children:
            rebuilt = _rebuild_node(child)
            if rebuilt is None:
                changed = True
                continue
            if rebuilt is not child:
                changed = True
            new.append(rebuilt)
        return tuple(new) if changed else children

    return _rebuild_children(roots)


def _ends_with_ellipsis(text: str) -> bool:
    return bool(_TRAILING_ELLIPSIS.search(text))


def _starts_with_ellipsis(text: str) -> bool:
    return bool(_LEADING_ELLIPSIS.match(text))
