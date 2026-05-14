"""Tier 1 generic apparatus resolution — output of § 6.

See ARCHITECTURE.md § 6.1-6.7 for the canonical specification.

This module implements the five generic apparatus resolvers shared across
all profiles, executed in a fixed order on a mutable copy of the
reconstructed tree:

1. ``_resolve_cross_page_note_merging`` — § 6.2. Consecutive ``NOTE`` nodes
   in pre-order DFS reading order are merged when the second is the first
   ``NOTE`` of its page and its text does not start with a numeric marker.
   The second node is detached from its parent; the first absorbs its text
   and ``block_indices``.

2. ``_resolve_cross_references`` — § 6.1. Each ``CROSS_REFERENCE`` is bound
   to the nearest preceding ``NOTE`` (in pre-order DFS) whose leading
   marker matches the cross-reference's number, restricted to the nearest
   ``HEADING_1``/``HEADING_2`` ancestor's subtree.

3. ``_resolve_marginal_positions`` — § 6.3. Each ``MARGINAL_HEADING`` is
   bound to the body-side node on the same page whose vertical centre is
   closest. Candidates are nodes of the main text flow: ``BODY``,
   ``ARTICLE_BODY``, ``HEADING_1``..4, ``ARTICLE_HEADER``, ``EXAMPLE_BOX``.

4. ``_resolve_marginal_glosses`` — § 6.6. Each ``MARGINAL_GLOSS`` is bound
   to the ``NOTE`` on the same page whose vertical centre is closest.

5. ``_resolve_box_associations`` — § 6.5. Intentional no-op: example boxes
   are already in the correct reading-order position thanks to the
   ``(page, y0, x0)`` sort of reconstruction tier 1a. Kept as a named
   resolver for symmetry with the other four and as a future extension
   point.

After the five resolvers run, ``resolve_apparatus`` freezes the mutable
tree back into a ``Document`` and dispatches to ``plugin.refine_apparatus``
for tier 2 (profile-specific refinement).

The tier 1 warning vocabulary is closed (see
``TIER1_WARNING_TEMPLATES``); tier 2 plugins are free to emit any string.
"""

from __future__ import annotations

from collections.abc import Iterator
from dataclasses import dataclass, field

from scabopdf_pipeline.apparatus.constants import (
    CROSS_REF_DIGITS_REGEX,
    NOTE_MARKER_REGEX,
)
from scabopdf_pipeline.apparatus.types import ApparatusRef, ApparatusRefKind
from scabopdf_pipeline.classification.types import ClassifiedBlock
from scabopdf_pipeline.extraction.types import BBox, ExtractionResult
from scabopdf_pipeline.profiling.plugin import ProfilePlugin
from scabopdf_pipeline.reconstruction.types import Document, Node, SummaryItem, TocGeneralItem
from scabopdf_pipeline.schema.categories import SemanticCategory

TIER1_WARNING_TEMPLATES: tuple[str, ...] = (
    "unparseable_cross_reference_node_<id>",
    "unresolved_cross_reference_node_<id>_n_<N>",
    "marginal_heading_without_body_target_node_<id>_page_<P>",
    "gloss_without_note_target_node_<id>_page_<P>",
)
"""Templates of the closed warning vocabulary tier 1 apparatus may emit.

The placeholders ``<id>``, ``<N>``, ``<P>`` are replaced with concrete
values. Tier 2 plugins are free to emit any string.
"""

_BODY_TARGET_CATEGORIES: frozenset[SemanticCategory] = frozenset(
    {
        SemanticCategory.BODY,
        SemanticCategory.ARTICLE_BODY,
        SemanticCategory.HEADING_1,
        SemanticCategory.HEADING_2,
        SemanticCategory.HEADING_3,
        SemanticCategory.HEADING_4,
        SemanticCategory.ARTICLE_HEADER,
        SemanticCategory.EXAMPLE_BOX,
    }
)

_HEADING_SCOPE_CATEGORIES: frozenset[SemanticCategory] = frozenset(
    {SemanticCategory.HEADING_1, SemanticCategory.HEADING_2}
)


@dataclass
class _NodeBuilder:
    """Mutable counterpart of :class:`Node` used by the resolvers."""

    id: str
    category: SemanticCategory
    page_index: int
    block_indices: tuple[int, ...]
    text: str | None
    level: int | None
    summary_items: tuple[SummaryItem, ...] | None = None
    toc_items: tuple[TocGeneralItem, ...] | None = None
    apparatus_refs: list[ApparatusRef] = field(default_factory=list)
    children: list[_NodeBuilder] = field(default_factory=list)
    parent: _NodeBuilder | None = None

    def to_frozen(self) -> Node:
        return Node(
            id=self.id,
            category=self.category,
            children=tuple(c.to_frozen() for c in self.children),
            page_index=self.page_index,
            block_indices=self.block_indices,
            text=self.text,
            level=self.level,
            summary_items=self.summary_items,
            toc_items=self.toc_items,
            apparatus_refs=tuple(self.apparatus_refs),
        )


def resolve_apparatus(
    document: Document,
    extraction: ExtractionResult,
    classified_blocks: list[ClassifiedBlock],
    plugin: ProfilePlugin,
) -> Document:
    """Resolve apparatus relations on ``document`` and dispatch to the plugin.

    Pure function: does not mutate its inputs and reads no external state.
    Runs the five tier 1 resolvers in fixed order on a mutable copy of the
    tree, freezes the result, and calls ``plugin.refine_apparatus`` for
    tier 2 (profile-specific refinement).

    See ARCHITECTURE.md § 6 for the canonical specification.
    """
    root_builders, builders_by_id = _thaw(document.root)
    bbox_by_node_id = _bbox_by_node_id(builders_by_id, extraction)
    warnings: list[str] = []

    _resolve_cross_page_note_merging(root_builders, builders_by_id, warnings)
    _resolve_cross_references(root_builders, warnings)
    _resolve_marginal_positions(root_builders, bbox_by_node_id, warnings)
    _resolve_marginal_glosses(root_builders, bbox_by_node_id, warnings)
    _resolve_box_associations(root_builders)

    new_document = Document(
        root=tuple(b.to_frozen() for b in root_builders),
        warnings=document.warnings + tuple(warnings),
    )
    return plugin.refine_apparatus(new_document, extraction, classified_blocks)


def _thaw(
    roots: tuple[Node, ...],
) -> tuple[list[_NodeBuilder], dict[str, _NodeBuilder]]:
    builders_by_id: dict[str, _NodeBuilder] = {}

    def _thaw_node(node: Node, parent: _NodeBuilder | None) -> _NodeBuilder:
        builder = _NodeBuilder(
            id=node.id,
            category=node.category,
            page_index=node.page_index,
            block_indices=node.block_indices,
            text=node.text,
            level=node.level,
            summary_items=node.summary_items,
            toc_items=node.toc_items,
            apparatus_refs=list(node.apparatus_refs),
            parent=parent,
        )
        builders_by_id[node.id] = builder
        for child in node.children:
            builder.children.append(_thaw_node(child, builder))
        return builder

    root_builders = [_thaw_node(n, None) for n in roots]
    return root_builders, builders_by_id


def _iter_builders(roots: list[_NodeBuilder]) -> Iterator[_NodeBuilder]:
    """Pre-order DFS traversal of the mutable tree."""

    def _walk(builder: _NodeBuilder) -> Iterator[_NodeBuilder]:
        yield builder
        for child in builder.children:
            yield from _walk(child)

    for root in roots:
        yield from _walk(root)


def _bbox_by_node_id(
    builders_by_id: dict[str, _NodeBuilder],
    extraction: ExtractionResult,
) -> dict[str, BBox | None]:
    """Map each builder id to its source block bbox, or None if synthetic."""
    bbox_by_id: dict[str, BBox | None] = {}
    n_blocks = len(extraction.blocks)
    for node_id, builder in builders_by_id.items():
        if not builder.block_indices:
            bbox_by_id[node_id] = None
            continue
        idx = builder.block_indices[0]
        if idx < 0 or idx >= n_blocks:
            bbox_by_id[node_id] = None
            continue
        bbox_by_id[node_id] = extraction.blocks[idx].bbox
    return bbox_by_id


def _resolve_cross_page_note_merging(
    root_builders: list[_NodeBuilder],
    builders_by_id: dict[str, _NodeBuilder],
    warnings: list[str],
) -> None:
    """Merge cross-page ``NOTE`` continuations into the previous ``NOTE``.

    See ARCHITECTURE.md § 6.2. For each consecutive pair of ``NOTE`` nodes
    in pre-order DFS reading order (filtered to ``NOTE`` only), if the
    second node is the first ``NOTE`` of its page and its text does not
    start with a numeric marker (``NOTE_MARKER_REGEX``), it is merged into
    the preceding one: their texts are joined by a single space, the
    ``block_indices`` are concatenated, and the second node is detached
    from its parent.
    """
    del warnings  # 7a does not emit warnings in tier 1.

    note_builders = [
        b for b in _iter_builders(root_builders) if b.category == SemanticCategory.NOTE
    ]
    if len(note_builders) < 2:
        return

    first_note_id_per_page: dict[int, str] = {}
    for nb in note_builders:
        first_note_id_per_page.setdefault(nb.page_index, nb.id)

    anchor_redirect: dict[str, str] = {}
    to_remove: set[str] = set()

    for i in range(1, len(note_builders)):
        prev = note_builders[i - 1]
        curr = note_builders[i]
        if first_note_id_per_page.get(curr.page_index) != curr.id:
            continue
        if curr.text is None:
            continue
        if NOTE_MARKER_REGEX.match(curr.text):
            continue

        anchor_id = prev.id
        while anchor_id in anchor_redirect:
            anchor_id = anchor_redirect[anchor_id]
        anchor = builders_by_id[anchor_id]
        assert anchor.text is not None

        anchor.text = anchor.text + " " + curr.text
        anchor.block_indices = anchor.block_indices + curr.block_indices
        anchor_redirect[curr.id] = anchor_id
        to_remove.add(curr.id)

    if to_remove:
        _detach_builders(root_builders, to_remove)


def _detach_builders(root_builders: list[_NodeBuilder], to_remove: set[str]) -> None:
    root_builders[:] = [b for b in root_builders if b.id not in to_remove]
    for b in root_builders:
        _detach_recursive(b, to_remove)


def _detach_recursive(builder: _NodeBuilder, to_remove: set[str]) -> None:
    builder.children[:] = [c for c in builder.children if c.id not in to_remove]
    for c in builder.children:
        _detach_recursive(c, to_remove)


def _resolve_cross_references(
    root_builders: list[_NodeBuilder],
    warnings: list[str],
) -> None:
    """Bind each ``CROSS_REFERENCE`` to its target ``NOTE``.

    See ARCHITECTURE.md § 6.1. The number ``N`` is extracted from the
    cross-reference text with ``CROSS_REF_DIGITS_REGEX``; an unparseable
    text emits ``unparseable_cross_reference_node_<id>``. The target is the
    most recent ``NOTE`` in pre-order DFS reading order whose leading
    marker (parsed with ``NOTE_MARKER_REGEX``) matches ``N`` and whose
    position falls inside the same hierarchical scope as the
    cross-reference.

    The generic tier 1 scope is "the subtree of the nearest ``HEADING_1``
    or ``HEADING_2`` ancestor". If no such ancestor exists the scope
    extends to the whole document. Profile-specific rules (e.g. per-article
    scope for Giuffrè legal codes) refine this in ``refine_apparatus``.

    If no matching note is found, the cross-reference receives no
    ``ApparatusRef`` and the warning
    ``unresolved_cross_reference_node_<id>_n_<N>`` is emitted.
    """
    all_builders = list(_iter_builders(root_builders))
    index_by_id = {b.id: i for i, b in enumerate(all_builders)}

    for cr in all_builders:
        if cr.category != SemanticCategory.CROSS_REFERENCE:
            continue
        if cr.text is None:
            warnings.append(f"unparseable_cross_reference_node_{cr.id}")
            continue
        digit_match = CROSS_REF_DIGITS_REGEX.match(cr.text)
        if digit_match is None:
            warnings.append(f"unparseable_cross_reference_node_{cr.id}")
            continue
        n = int(digit_match.group(1))

        scope_root = _find_scope_root(cr)
        if scope_root is None:
            scope_ids = {b.id for b in all_builders}
        else:
            scope_ids = {b.id for b in _iter_builders([scope_root])}

        cr_index = index_by_id[cr.id]
        target: _NodeBuilder | None = None
        for j in range(cr_index - 1, -1, -1):
            candidate = all_builders[j]
            if candidate.id not in scope_ids:
                continue
            if candidate.category != SemanticCategory.NOTE:
                continue
            if candidate.text is None:
                continue
            marker_match = NOTE_MARKER_REGEX.match(candidate.text)
            if marker_match is None:
                continue
            if int(marker_match.group(1)) != n:
                continue
            target = candidate
            break

        if target is None:
            warnings.append(f"unresolved_cross_reference_node_{cr.id}_n_{n}")
            continue

        cr.apparatus_refs.append(
            ApparatusRef(
                kind=ApparatusRefKind.CROSS_REF_TARGET,
                target_node_id=target.id,
                source_marker=f"({n})",
            )
        )


def _find_scope_root(builder: _NodeBuilder) -> _NodeBuilder | None:
    current = builder.parent
    while current is not None:
        if current.category in _HEADING_SCOPE_CATEGORIES:
            return current
        current = current.parent
    return None


def _resolve_marginal_positions(
    root_builders: list[_NodeBuilder],
    bbox_by_node_id: dict[str, BBox | None],
    warnings: list[str],
) -> None:
    """Bind each ``MARGINAL_HEADING`` to the closest body-side node on its page.

    See ARCHITECTURE.md § 6.3. The candidate target categories are the
    main-flow content nodes: ``BODY``, ``ARTICLE_BODY``, ``HEADING_1``..4,
    ``ARTICLE_HEADER``, ``EXAMPLE_BOX``. Proximity is measured between
    bbox vertical centres on the same page; the closest candidate wins,
    regardless of distance. If no candidate exists the marginal heading
    is left unbound and the warning
    ``marginal_heading_without_body_target_node_<id>_page_<P>`` is emitted.
    """
    _resolve_marginal_to_target(
        root_builders=root_builders,
        bbox_by_node_id=bbox_by_node_id,
        warnings=warnings,
        source_category=SemanticCategory.MARGINAL_HEADING,
        target_categories=_BODY_TARGET_CATEGORIES,
        ref_kind=ApparatusRefKind.BODY_ASSOCIATION,
        warning_prefix="marginal_heading_without_body_target_node",
    )


def _resolve_marginal_glosses(
    root_builders: list[_NodeBuilder],
    bbox_by_node_id: dict[str, BBox | None],
    warnings: list[str],
) -> None:
    """Bind each ``MARGINAL_GLOSS`` to the closest ``NOTE`` on its page.

    See ARCHITECTURE.md § 6.6. Same y-centre proximity rule as
    ``_resolve_marginal_positions`` but the candidate set is restricted to
    ``NOTE`` nodes. If no candidate exists the gloss is left unbound and
    the warning ``gloss_without_note_target_node_<id>_page_<P>`` is
    emitted.
    """
    _resolve_marginal_to_target(
        root_builders=root_builders,
        bbox_by_node_id=bbox_by_node_id,
        warnings=warnings,
        source_category=SemanticCategory.MARGINAL_GLOSS,
        target_categories=frozenset({SemanticCategory.NOTE}),
        ref_kind=ApparatusRefKind.GLOSS_TARGET,
        warning_prefix="gloss_without_note_target_node",
    )


def _resolve_marginal_to_target(
    *,
    root_builders: list[_NodeBuilder],
    bbox_by_node_id: dict[str, BBox | None],
    warnings: list[str],
    source_category: SemanticCategory,
    target_categories: frozenset[SemanticCategory],
    ref_kind: ApparatusRefKind,
    warning_prefix: str,
) -> None:
    targets_by_page: dict[int, list[_NodeBuilder]] = {}
    for builder in _iter_builders(root_builders):
        if builder.category not in target_categories:
            continue
        if bbox_by_node_id.get(builder.id) is None:
            continue
        targets_by_page.setdefault(builder.page_index, []).append(builder)

    for source in _iter_builders(root_builders):
        if source.category != source_category:
            continue
        source_bbox = bbox_by_node_id.get(source.id)
        if source_bbox is None:
            warnings.append(f"{warning_prefix}_{source.id}_page_{source.page_index}")
            continue
        candidates = targets_by_page.get(source.page_index, [])
        if not candidates:
            warnings.append(f"{warning_prefix}_{source.id}_page_{source.page_index}")
            continue
        source_y = (source_bbox[1] + source_bbox[3]) / 2.0
        best: _NodeBuilder | None = None
        best_distance = float("inf")
        for candidate in candidates:
            cand_bbox = bbox_by_node_id[candidate.id]
            assert cand_bbox is not None
            cand_y = (cand_bbox[1] + cand_bbox[3]) / 2.0
            distance = abs(source_y - cand_y)
            if distance < best_distance:
                best = candidate
                best_distance = distance
        assert best is not None
        source.apparatus_refs.append(ApparatusRef(kind=ref_kind, target_node_id=best.id))


def _resolve_box_associations(root_builders: list[_NodeBuilder]) -> None:
    """No-op: ``EXAMPLE_BOX`` nodes are already in reading-order position.

    See ARCHITECTURE.md § 6.5. Boxes are sorted into their correct
    structural position by the ``(page, y0, x0)`` sort of reconstruction
    tier 1a, so no additional binding is needed at this stage. This
    function is kept as a named resolver for symmetry with the other
    four and as a future extension point — for example, profile-specific
    refinements that want to attach a box to a non-spatial owning section
    can subclass the behaviour in ``refine_apparatus``.
    """
    del root_builders
