"""Tier 1 generic reconstruction — output of § 5.1, 5.3, 5.5.

See ARCHITECTURE.md § 5 for the canonical specification.

This module implements the three-phase generic reconstruction shared
across all profiles:

1. ``tier 1a`` — column-aware sorting. In v1 only mono-column is supported:
   blocks are sorted by ``(page, bbox.y0, bbox.x0)``. CPython's sort is
   stable, so the original ``ExtractionResult.blocks`` order acts as an
   implicit fourth-level tie-breaker. Multi-column support is deferred to
   profile-specific plugins (Codici Giuffrè, Enciclopedia moderna) that
   will reorder in ``refine_reconstruction``.

2. ``tier 1b`` — cross-page paragraph merging (§ 5.5). A BODY/ARTICLE_BODY
   block that begins at the top of its page
   (``bbox.y0 < page_height * CROSS_PAGE_TOP_FRACTION``) and does not match
   a heading pattern is merged into the previous BODY/ARTICLE_BODY node.
   The backward scan walks past page-decoration categories (artifacts,
   anchors, notes, marginalia, cross-references, unclassified, empty
   pages) but stops at any heading-like category (HEADING_1..4,
   ARTICLE_HEADER): a heading between two body blocks signals a new
   section, not a continuation.

3. ``tier 1c`` — hierarchy assembly (§ 5.3). Blocks are folded into a tree
   guided by their semantic category, a running heading stack
   (``heading_stack[i-1]`` = current ``HEADING_i`` builder when present)
   and a current ARTICLE_HEADER. Scope semantics for ARTICLE_HEADER: a
   current ARTICLE_HEADER stays open until either (a) another
   ARTICLE_HEADER replaces it, or (b) any HEADING_N arrives, which clears
   it. While an ARTICLE_HEADER is open it acts as the container for all
   non-structural categories (notes, marginalia, artifacts, anchors,
   unclassified, empty pages, cross-references) and for ARTICLE_BODY;
   plain BODY paragraphs intentionally bypass ARTICLE_HEADER and attach to
   the most recent HEADING_N or to the root.

After tier 1, ``reconstruct`` dispatches to ``plugin.refine_reconstruction``
for tier 2 (profile-specific refinement).

The tier 1 warning vocabulary is closed:

- ``orphan_heading_level_N_page_M`` — HEADING_N without HEADING_(N-1)
  ancestor on the stack.
- ``article_body_without_header_page_M`` — ARTICLE_BODY without an open
  ARTICLE_HEADER.

Plugins are free to emit any warning string in tier 2.
"""

from __future__ import annotations

from dataclasses import dataclass, field

from scabopdf_pipeline.classification.headings import detect_heading_pattern
from scabopdf_pipeline.classification.types import ClassifiedBlock
from scabopdf_pipeline.extraction.types import (
    Block,
    ExtractionResult,
    PageGeometry,
)
from scabopdf_pipeline.profiling.plugin import ProfilePlugin
from scabopdf_pipeline.profiling.profile import DocumentProfile
from scabopdf_pipeline.reconstruction.constants import CROSS_PAGE_TOP_FRACTION
from scabopdf_pipeline.reconstruction.types import Document, Node
from scabopdf_pipeline.schema.categories import SemanticCategory

TIER1_WARNING_TEMPLATES: tuple[str, ...] = (
    "orphan_heading_level_N_page_M",
    "article_body_without_header_page_M",
)
"""Templates of the closed warning vocabulary tier 1 may emit.

The placeholders ``N`` and ``M`` are replaced with concrete values. Tier 2
plugins are free to emit any string.
"""

_HEADING_LEVELS: dict[SemanticCategory, int] = {
    SemanticCategory.HEADING_1: 1,
    SemanticCategory.HEADING_2: 2,
    SemanticCategory.HEADING_3: 3,
    SemanticCategory.HEADING_4: 4,
}

_MERGEABLE_CATEGORIES: frozenset[SemanticCategory] = frozenset(
    {SemanticCategory.BODY, SemanticCategory.ARTICLE_BODY}
)

_HEADING_BARRIERS: frozenset[SemanticCategory] = frozenset(
    {
        SemanticCategory.HEADING_1,
        SemanticCategory.HEADING_2,
        SemanticCategory.HEADING_3,
        SemanticCategory.HEADING_4,
        SemanticCategory.ARTICLE_HEADER,
    }
)


@dataclass
class _Item:
    """Intermediate representation shared by tier 1a/1b.

    ``block`` is ``None`` only for sentinel ``ClassifiedBlock``s with
    ``block_index == -1`` (currently only ``EMPTY_PAGE``). Sentinels also
    have ``text=None`` and ``block_indices=[]`` and sort to ``y0=0``,
    ``x0=0`` within their page.
    """

    classified: ClassifiedBlock
    block: Block | None
    page: int
    bbox_y0: float
    bbox_x0: float
    text: str | None
    block_indices: list[int]


@dataclass
class _NodeBuilder:
    """Mutable counterpart of :class:`Node` used during hierarchy assembly."""

    id: str
    category: SemanticCategory
    page_index: int
    block_indices: list[int]
    text: str | None
    level: int | None = None
    children: list[_NodeBuilder] = field(default_factory=list)

    def to_frozen(self) -> Node:
        return Node(
            id=self.id,
            category=self.category,
            children=tuple(c.to_frozen() for c in self.children),
            page_index=self.page_index,
            block_indices=tuple(self.block_indices),
            text=self.text,
            level=self.level,
            summary_items=None,
            apparatus_refs=(),
        )


def reconstruct(
    extraction: ExtractionResult,
    classified_blocks: list[ClassifiedBlock],
    profile: DocumentProfile,
    plugin: ProfilePlugin,
) -> Document:
    """Build the reading-order tree from extraction + classification.

    Pure function: does not mutate its inputs and reads no external state.
    Runs tier 1a (sort), tier 1b (cross-page merge), tier 1c (hierarchy)
    in order, then dispatches to ``plugin.refine_reconstruction`` for tier
    2.

    ``profile`` is currently unused by tier 1 but is part of the public
    signature for symmetry with ``classify()``.
    """
    del profile  # reserved for future tier 1 logic; tier 2 receives the plugin.

    geometries_by_page = {geom.page: geom for geom in extraction.page_geometries}

    sorted_items = _sort_mono_column(classified_blocks, extraction)
    merged_items = _merge_cross_page(sorted_items, geometries_by_page)
    root, warnings = _assemble_hierarchy(merged_items)

    document = Document(root=root, warnings=warnings)
    return plugin.refine_reconstruction(document, extraction, classified_blocks)


def _sort_mono_column(
    classified: list[ClassifiedBlock], extraction: ExtractionResult
) -> list[_Item]:
    items: list[_Item] = []
    for cb in classified:
        if cb.block_index < 0:
            page = _sentinel_page(cb)
            items.append(
                _Item(
                    classified=cb,
                    block=None,
                    page=page,
                    bbox_y0=0.0,
                    bbox_x0=0.0,
                    text=None,
                    block_indices=[],
                )
            )
            continue
        block = extraction.blocks[cb.block_index]
        text = _block_text(extraction, block)
        items.append(
            _Item(
                classified=cb,
                block=block,
                page=block.page,
                bbox_y0=block.bbox[1],
                bbox_x0=block.bbox[0],
                text=text,
                block_indices=[cb.block_index],
            )
        )
    items.sort(key=lambda it: (it.page, it.bbox_y0, it.bbox_x0))
    return items


def _sentinel_page(cb: ClassifiedBlock) -> int:
    """Parse the page index a sentinel ClassifiedBlock carries as subcategory."""
    if cb.subcategory is None:
        return 0
    return int(cb.subcategory)


def _block_text(extraction: ExtractionResult, block: Block) -> str:
    start, end = block.span_range
    return "".join(s.text for s in extraction.spans[start:end])


def _merge_cross_page(
    items: list[_Item], geometries_by_page: dict[int, PageGeometry]
) -> list[_Item]:
    output: list[_Item] = []
    for item in items:
        if _is_cross_page_continuation(item, geometries_by_page):
            target = _find_merge_target(output)
            if target is not None:
                assert target.text is not None
                assert item.text is not None
                target.text = target.text + " " + item.text
                target.block_indices.extend(item.block_indices)
                continue
        output.append(item)
    return output


def _is_cross_page_continuation(item: _Item, geometries_by_page: dict[int, PageGeometry]) -> bool:
    if item.classified.category not in _MERGEABLE_CATEGORIES:
        return False
    if item.block is None or item.text is None:
        return False
    geom = geometries_by_page.get(item.page)
    if geom is None:
        return False
    if item.bbox_y0 >= geom.height_pt * CROSS_PAGE_TOP_FRACTION:
        return False
    return detect_heading_pattern(item.text) is None


def _find_merge_target(output: list[_Item]) -> _Item | None:
    for prev in reversed(output):
        cat = prev.classified.category
        if cat in _MERGEABLE_CATEGORIES:
            return prev
        if cat in _HEADING_BARRIERS:
            return None
    return None


def _assemble_hierarchy(
    items: list[_Item],
) -> tuple[tuple[Node, ...], tuple[str, ...]]:
    root_builders: list[_NodeBuilder] = []
    heading_stack: list[_NodeBuilder] = []
    current_article_header: _NodeBuilder | None = None
    warnings: list[str] = []
    counter = 0

    def mint(item: _Item, level: int | None = None) -> _NodeBuilder:
        nonlocal counter
        builder = _NodeBuilder(
            id=f"node_{counter:04d}",
            category=item.classified.category,
            page_index=item.page,
            block_indices=list(item.block_indices),
            text=item.text,
            level=level,
        )
        counter += 1
        return builder

    for item in items:
        category = item.classified.category

        if category in _HEADING_LEVELS:
            level = _HEADING_LEVELS[category]
            builder = mint(item, level=level)
            if level == 1:
                root_builders.append(builder)
            elif len(heading_stack) >= level - 1:
                heading_stack[level - 2].children.append(builder)
            else:
                root_builders.append(builder)
                warnings.append(f"orphan_heading_level_{level}_page_{item.page}")
            heading_stack[level - 1 :] = [builder]
            current_article_header = None
            continue

        if category == SemanticCategory.ARTICLE_HEADER:
            builder = mint(item)
            _attach(builder, heading_stack[-1] if heading_stack else None, root_builders)
            current_article_header = builder
            continue

        if category == SemanticCategory.BODY:
            builder = mint(item)
            heading_parent = heading_stack[-1] if heading_stack else None
            _attach(builder, heading_parent, root_builders)
            continue

        if category == SemanticCategory.ARTICLE_BODY:
            builder = mint(item)
            if current_article_header is not None:
                current_article_header.children.append(builder)
            else:
                warnings.append(f"article_body_without_header_page_{item.page}")
                fallback_parent = heading_stack[-1] if heading_stack else None
                _attach(builder, fallback_parent, root_builders)
            continue

        # Every other category (artifacts, anchors, notes, marginalia,
        # cross-references, unclassified, empty pages). Container is the
        # current ARTICLE_HEADER if open, otherwise the most recent
        # heading, otherwise the root.
        builder = mint(item)
        container: _NodeBuilder | None
        if current_article_header is not None:
            container = current_article_header
        elif heading_stack:
            container = heading_stack[-1]
        else:
            container = None
        _attach(builder, container, root_builders)

    root = tuple(b.to_frozen() for b in root_builders)
    return root, tuple(warnings)


def _attach(
    builder: _NodeBuilder,
    parent: _NodeBuilder | None,
    root_builders: list[_NodeBuilder],
) -> None:
    if parent is None:
        root_builders.append(builder)
    else:
        parent.children.append(builder)
