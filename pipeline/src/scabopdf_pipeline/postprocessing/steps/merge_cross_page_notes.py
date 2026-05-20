"""merge_cross_page_notes — fuse cross-page NOTE continuations into their head.

See ARCHITECTURE.md § 7 for the canonical specification of the
post-processing phase. This module promotes the placeholder previously
listed in :data:`postprocessing.registry._PROFILE_SPECIFIC_PLACEHOLDERS`
to a real implementation, introduced together with the consolidation
of the :class:`scabopdf_pipeline.profiles.manuale_giappichelli.
ManualeGiappichelliProfile` (Mandrioli-Carratta series, Giappichelli
30th edition). The step closes the cross-page note residue that the
pre-promotion plugin left behind: empirical inspection on the Vol. III
fixture identifies ~241 pages whose footnote band opens with the
continuation of a note interrupted by the page break, and the same
pattern affects ~222 pages on Vol. IV. The pre-promotion plugin
recovered 466 NOTE Nodes on Vol. III (63 % of the 744 markers); after
this step lands, the count rises to ~700+ (94 %+) by detaching every
marker-less NOTE from its standalone position and merging its text
back into the preceding NOTE in reading order.

Algorithm.

1. Walk the document tree depth-first, **pre-order**, collecting
   every ``NOTE`` node in reading order regardless of tree position.
   The flat list ignores sibling boundaries: a continuation can sit
   under a different parent (typically a different ``HEADING_2`` /
   ``HEADING_3`` than the head, because the page break may straddle
   a structural division).

2. For each consecutive pair ``(prev, curr)`` of NOTE nodes in the
   flat list:

   - if ``curr`` is **not** the first NOTE of its page, skip — it is
     a regular subsequent note on the same page;
   - if ``curr.text`` is ``None`` or empty, skip;
   - if ``curr.text`` starts with the configured continuation marker
     pattern (default: ``r"^\\s*\\(\\d+\\)"``), skip — ``curr`` opens a
     fresh note with its own marker, not a continuation;
   - **boundary guard**: if ``prev.text`` already starts with a marker
     ``(M)`` and ``M >= 100`` (suspiciously high), keep the merge
     (Mandrioli notes are numbered per chapter and a chapter can have
     more than 100 notes); the guard is not about marker value but
     about a different invariant — see below.
   - **scope guard**: limit the merge to NOTE nodes whose
     ``page_index`` differs by **exactly 1** from ``prev.page_index``.
     A continuation by definition opens on the page immediately after
     the head; a gap of two pages indicates either a blank page
     (rare) or a structural issue, and we do not silently fuse across
     larger gaps.
   - otherwise merge ``curr`` into the **most recent surviving head**
     (via an anchor redirect table, so a chain of 3+ continuation
     pages collapses correctly into the single head from page N).
     Append ``" " + curr.text`` to the head's text and concatenate
     ``curr.block_indices`` into the head's block_indices.

3. Record one :class:`Transformation` per merge on the surviving head
   (Layer 2 reverts a chain by walking the log in reverse so each
   continuation re-emerges in order):

   - ``step_id`` = :data:`STEP_ID`
   - ``node_id`` = head id
   - ``page_index`` = head page_index
   - ``position`` = ``(end_of_pre_text, end_of_pre_text)`` — the
     append point in the head's pre-step text
   - ``original`` = ``""`` — nothing was at the append point before
   - ``normalized`` = ``" " + curr.text`` — what was appended
   - ``merged_from`` = ``(curr.id,)`` — Layer 2 can rematerialise the
     consumed continuation as a separate sibling

4. Detach every continuation Node from its parent (the structural
   counterpart of the text append). Subtrees that did not change keep
   their identity, mirroring the convention of the existing steps.

Marker pattern is configurable through the module-level
:data:`_CONTINUATION_MARKER_REGEX`. The default
``r"^\\s*\\(\\d+\\)"`` matches the Mandrioli parenthesised
``(N)`` form. A future plugin whose marker is differently shaped
(e.g. bare digit with trailing dot, OCR-derived variants) can either
patch the constant at import time or, preferably, the step can be
generalised in a future schema-additive bump that lets a plugin
declare its marker shape in
:meth:`ProfilePlugin.get_post_processing_options` (does not exist yet).

The step is symmetric with the tier 1
``_resolve_cross_page_note_merging`` resolver in
:mod:`scabopdf_pipeline.apparatus.resolver`: both honour the same
"first NOTE of the page without leading marker" predicate, but the
post-processing step (a) produces a :class:`Transformation` log so
Layer 2 can offer "raw mode" reading, (b) runs **after** any tier 2
splitter has materialised the structural NOTE Nodes (Giappichelli
body+note splitter), and (c) populates ``merged_from`` for structural
reversibility per schema 0.5.0. To avoid double-merging, plugins that
declare this step in :meth:`ProfilePlugin.get_post_processing` cause
the tier 1 resolver to skip its own pass (see
:func:`apparatus.resolver._resolve_cross_page_note_merging`).

The function is pure: it takes the current :class:`Document` plus the
raw extraction artefacts and returns a new :class:`Document` plus the
tuple of :class:`Transformation` recorded in this step. Subtrees that
did not change keep their identity.
"""

from __future__ import annotations

import dataclasses
import re

from scabopdf_pipeline.classification.types import ClassifiedBlock
from scabopdf_pipeline.extraction.types import ExtractionResult
from scabopdf_pipeline.postprocessing.types import Transformation
from scabopdf_pipeline.reconstruction.types import Document, Node, compute_note_length_category
from scabopdf_pipeline.schema.categories import SemanticCategory

STEP_ID = "merge_cross_page_notes"
"""Registry key under which :func:`merge_cross_page_notes` is registered."""

_CONTINUATION_MARKER_REGEX = re.compile(r"^\s*\(?(\d+)\)?[\.\s]")
"""Regex that recognises the leading numeric marker of a fresh NOTE.

Matches the Mandrioli parenthesised form ``(N)`` and the bare digit
form ``N.`` that the prior three plugins (Patriarca, Tesauro,
Mosconi) exhibit. Equivalent in shape to
:data:`apparatus.constants.NOTE_MARKER_REGEX` — kept private to this
module to underline that the post-processing predicate is a
self-contained policy and is not coupled to the tier 1 resolver's
copy. A future schema-additive bump that lets a plugin override the
marker shape would replace both copies with a per-plugin lookup.
"""


def merge_cross_page_notes(
    document: Document,
    extraction: ExtractionResult,
    classified_blocks: list[ClassifiedBlock],
) -> tuple[Document, tuple[Transformation, ...]]:
    """Fuse cross-page NOTE continuations into their head NOTE.

    Parameters
    ----------
    document
        Document to process. Treated as immutable; the result is a new
        :class:`Document` when at least one continuation is merged, the
        same instance otherwise.
    extraction
        Forwarded for signature symmetry with the step protocol; not
        consumed by this step.
    classified_blocks
        Forwarded for signature symmetry; not consumed.

    Returns
    -------
    tuple[Document, tuple[Transformation, ...]]
        The (possibly new) document and the tuple of transformations
        this step recorded. When no continuation is fused, the original
        ``document`` is returned and the tuple is empty.
    """
    del extraction, classified_blocks
    notes = _collect_notes(document.root)
    if len(notes) < 2:
        return document, ()

    plan = _plan_merges(notes)
    if not plan.merges:
        return document, ()

    new_root = _apply_merges(document.root, plan)
    return dataclasses.replace(document, root=new_root), tuple(plan.transformations)


@dataclasses.dataclass
class _MergePlan:
    """Aggregated result of the merge planning pass.

    ``replacements`` maps a head's pre-step id to the post-step
    :class:`Node` carrying the fused text, used by :func:`_apply_merges`
    when it rebuilds the tree. ``merges`` is the list of (head_id,
    absorbed_id) pairs for telemetry-style assertions in tests.
    ``transformations`` is the per-merge log emitted to the
    orchestrator. ``to_remove`` is the set of absorbed ids the tree
    rebuilder must drop.
    """

    replacements: dict[str, Node]
    merges: list[tuple[str, str]]
    transformations: list[Transformation]
    to_remove: set[str]


def _collect_notes(roots: tuple[Node, ...]) -> list[Node]:
    """Return every ``NOTE`` node in DFS pre-order across the forest."""
    out: list[Node] = []

    def _visit(node: Node) -> None:
        if node.category is SemanticCategory.NOTE:
            out.append(node)
        for child in node.children:
            _visit(child)

    for root in roots:
        _visit(root)
    return out


def _plan_merges(notes: list[Node]) -> _MergePlan:
    """Walk consecutive NOTE pairs and plan the cross-page merges."""
    first_note_id_per_page: dict[int, str] = {}
    for nb in notes:
        first_note_id_per_page.setdefault(nb.page_index, nb.id)

    head_text: dict[str, str] = {}
    head_block_indices: dict[str, tuple[int, ...]] = {}
    head_page_index: dict[str, int] = {}
    head_template: dict[str, Node] = {}
    anchor_redirect: dict[str, str] = {}
    merges: list[tuple[str, str]] = []
    transformations: list[Transformation] = []
    to_remove: set[str] = set()

    for i in range(1, len(notes)):
        prev = notes[i - 1]
        curr = notes[i]
        if first_note_id_per_page.get(curr.page_index) != curr.id:
            continue
        if not curr.text:
            continue
        if _CONTINUATION_MARKER_REGEX.match(curr.text):
            continue
        if curr.page_index - prev.page_index != 1:
            # Larger gaps are suspicious — leave the continuation alone
            # rather than silently fuse across a blank-page or structural
            # discontinuity. The plugin's diagnostic warning bag (or a
            # downstream review) can surface this as needed.
            continue

        anchor_id = prev.id
        while anchor_id in anchor_redirect:
            anchor_id = anchor_redirect[anchor_id]
        if anchor_id not in head_text:
            # First time we touch this anchor — seed the mutable state
            # from the pre-step head Node.
            anchor_node = _find_by_id(notes, anchor_id)
            if anchor_node is None or anchor_node.text is None:
                continue
            head_text[anchor_id] = anchor_node.text
            head_block_indices[anchor_id] = anchor_node.block_indices
            head_page_index[anchor_id] = anchor_node.page_index
            head_template[anchor_id] = anchor_node

        pre_text = head_text[anchor_id]
        append = " " + curr.text
        position = (len(pre_text), len(pre_text))

        head_text[anchor_id] = pre_text + append
        head_block_indices[anchor_id] = head_block_indices[anchor_id] + curr.block_indices

        transformations.append(
            Transformation(
                step_id=STEP_ID,
                node_id=anchor_id,
                page_index=head_page_index[anchor_id],
                position=position,
                original="",
                normalized=append,
                merged_from=(curr.id,),
            )
        )
        merges.append((anchor_id, curr.id))
        anchor_redirect[curr.id] = anchor_id
        to_remove.add(curr.id)

    replacements: dict[str, Node] = {}
    for anchor_id, template in head_template.items():
        merged_text = head_text[anchor_id]
        # length_category MUST be recomputed: the text grew by appending
        # one or more continuations, so a SHORT head may now be MEDIUM
        # and a LONG one may shift to VERY_LONG. The other length fields
        # (summary_items, toc_items) stay invariant — they belong to
        # CHAPTER_SUMMARY / TOC_GENERAL, not NOTE.
        replacements[anchor_id] = Node(
            id=template.id,
            category=template.category,
            children=template.children,
            page_index=template.page_index,
            block_indices=head_block_indices[anchor_id],
            text=merged_text,
            level=template.level,
            summary_items=template.summary_items,
            toc_items=template.toc_items,
            length_category=compute_note_length_category(merged_text),
            apparatus_refs=template.apparatus_refs,
        )

    return _MergePlan(
        replacements=replacements,
        merges=merges,
        transformations=transformations,
        to_remove=to_remove,
    )


def _find_by_id(notes: list[Node], target_id: str) -> Node | None:
    for note in notes:
        if note.id == target_id:
            return note
    return None


def _apply_merges(roots: tuple[Node, ...], plan: _MergePlan) -> tuple[Node, ...]:
    """Rebuild the tree applying the planned replacements and removals.

    Subtrees that did not contain any modified Node keep their identity
    (same ``Node`` instance), so a document with a single continuation
    chain emits a minimally-rewritten forest.
    """

    def _rebuild_node(node: Node) -> Node | None:
        if node.id in plan.to_remove:
            return None
        new_children = _rebuild_children(node.children)
        if node.id in plan.replacements:
            replacement = plan.replacements[node.id]
            if new_children is node.children:
                return replacement
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
                length_category=replacement.length_category,
                apparatus_refs=replacement.apparatus_refs,
            )
        if new_children is node.children:
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
