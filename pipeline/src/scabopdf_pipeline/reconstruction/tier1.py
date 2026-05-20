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

2b. ``tier 1b.5`` — adjacent multi-line heading consolidation (added in
   the 20 May 2026 session that closed the materiali_studio debt vii).
   See :func:`_consolidate_adjacent_headings`. Conservative: only
   fuses pairs of adjacent same-page items whose post-classification
   verdict is the same HEADING_N category, whose typographic signature
   is identical across every span of both blocks, whose bbox.x0 agree
   within ±2pt, whose vertical gap sits in [0, 8pt], and whose
   combined length stays under 500 chars. Skipped if the prior item
   ends with a sentence terminator. Plugin-specific fusion patterns
   (Tesauro chapter pair, Mandrioli CAPITOLO composite) have
   heterogeneous signatures across halves and are therefore not
   touched by this generic pass.

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
from scabopdf_pipeline.reconstruction.types import Document, Node, compute_note_length_category
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
        length_category = (
            compute_note_length_category(self.text)
            if self.category is SemanticCategory.NOTE
            else None
        )
        return Node(
            id=self.id,
            category=self.category,
            children=tuple(c.to_frozen() for c in self.children),
            page_index=self.page_index,
            block_indices=tuple(self.block_indices),
            text=self.text,
            level=self.level,
            summary_items=None,
            toc_items=None,
            length_category=length_category,
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
    consolidated_items = _consolidate_adjacent_headings(merged_items, extraction)
    root, warnings = _assemble_hierarchy(consolidated_items)

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


_HEADING_FUSION_CATEGORIES: frozenset[SemanticCategory] = frozenset(
    {
        SemanticCategory.HEADING_1,
        SemanticCategory.HEADING_2,
        SemanticCategory.HEADING_3,
        SemanticCategory.HEADING_4,
    }
)

_HEADING_FUSION_X0_TOLERANCE_PT: float = 2.0
"""Maximum permitted difference in ``bbox.x0`` between two adjacent
heading fragments for them to be considered the same logical heading.
Two points of slack absorbs PyMuPDF's typical sub-pixel jitter on the
horizontal axis without admitting blocks aligned to different columns.
"""

_HEADING_FUSION_VERTICAL_GAP_MAX_PT: float = 8.0
"""Maximum permitted vertical gap between two adjacent heading fragments.
8pt accommodates the typical line-leading of body and heading sizes
without admitting blocks separated by a full empty line. The gap is
measured as ``current.bbox_y0 - prev.bbox_y1``; negative gaps
(overlapping blocks) are rejected.
"""

_HEADING_FUSION_COMBINED_TEXT_MAX_CHARS: int = 500
"""Maximum permitted combined text length of two fused heading fragments.
Headings are short by convention; 500 chars is well above any natural
heading and well below a body paragraph. Prevents pathological fusion
chains on misclassified blocks.
"""

_HEADING_FUSION_SENTENCE_TERMINATORS: frozenset[str] = frozenset({".", "!", "?", ":"})
"""Trailing characters on the prior fragment that block fusion. A
heading fragment whose text ends with sentence punctuation is by
construction a self-contained heading; the next adjacent block is a
new logical unit, not a continuation of the same heading.
"""


def _consolidate_adjacent_headings(items: list[_Item], extraction: ExtractionResult) -> list[_Item]:
    """Fuse pairs of adjacent ``_Item`` that form a single wrapped heading.

    Tier 1b.5 — a conservative post-classification pass that closes the
    "multi-line subtitle not fused into a single HEADING" debt (vii) of
    the materiali_studio plugin (CARRYOVER v2.16.1) and the analogous
    case in any future plugin or corpus.

    PyMuPDF normally emits a multi-line heading as a single ``Block``
    with multiple line-indexed ``Span``s (the typical case), but
    occasionally a typographic discontinuity (an extra vertical gap, a
    subtle baseline shift) breaks its intra-block grouping and produces
    two separate ``Block``s for the two halves of the same logical
    heading. The plugin's heading-recognition predicate may then match
    only the first half, missing the continuation, or both halves with
    the second being a small fragment that does not naturally form a
    heading on its own.

    The fusion predicate is deliberately strict to stay corpus-agnostic
    and avoid interfering with the plugin-specific fusion patterns
    already established (Tesauro chapter heading "Capitolo N" + title,
    Mosconi chapter pair, Mandrioli CAPITOLO small-caps composite —
    these typically have *different* typographic signatures between
    halves and are therefore skipped by this generic pass). Two adjacent
    ``_Item``s are fused into one only when *all* of the following hold:

    - both items have a real ``Block`` (no sentinel ``EMPTY_PAGE``);
    - both items share the same ``page``;
    - both items have already been classified as the *same* category,
      and that category is one of ``HEADING_1`` / ``HEADING_2`` /
      ``HEADING_3`` / ``HEADING_4`` (the fusion is opt-out for BODY,
      NOTE, ARTIFACT_*, CROSS_REFERENCE, etc. so it cannot accidentally
      glue paragraphs);
    - their ``bbox.x0`` values are within
      :data:`_HEADING_FUSION_X0_TOLERANCE_PT` of each other (same
      left-aligned or same centered column);
    - their vertical gap is in ``[0, _HEADING_FUSION_VERTICAL_GAP_MAX_PT]``
      (typical line-leading, not a full empty line);
    - all spans of *both* blocks share an identical typographic
      signature ``(size, font, flags, color)`` reduced to **a single
      distinct value** across the two blocks (a wrapped heading is by
      construction homogeneous);
    - the prior item's text does not end with a sentence-terminator
      (``.``, ``!``, ``?``, ``:``) that would mark a self-contained
      heading;
    - the combined text length stays under
      :data:`_HEADING_FUSION_COMBINED_TEXT_MAX_CHARS`.

    When fusion happens the prior item absorbs the current item: text is
    concatenated with a single space, ``block_indices`` are extended,
    and the bbox anchor is left at the prior's coordinates (sorting has
    already happened, so the bbox does not influence downstream order).
    """
    if not items:
        return items
    output: list[_Item] = [items[0]]
    for current in items[1:]:
        prev = output[-1]
        if _can_fuse_heading_fragments(prev, current, extraction):
            assert prev.text is not None and current.text is not None
            prev.text = prev.text + " " + current.text
            prev.block_indices.extend(current.block_indices)
            # Re-anchor ``prev.block`` to the just-absorbed block so the
            # next iteration's vertical-gap check is measured against the
            # latest absorbed y1 rather than against the original first
            # block's y1. Without this, a chain of three same-style
            # fragments collapses only the first two when the third's
            # gap from the first's y1 exceeds the threshold.
            prev.block = current.block
        else:
            output.append(current)
    return output


def _can_fuse_heading_fragments(prev: _Item, current: _Item, extraction: ExtractionResult) -> bool:
    """Predicate for :func:`_consolidate_adjacent_headings` — see docstring."""
    if prev.block is None or current.block is None:
        return False
    if prev.text is None or current.text is None:
        return False
    if prev.classified.category not in _HEADING_FUSION_CATEGORIES:
        return False
    if prev.classified.category is not current.classified.category:
        return False
    if prev.page != current.page:
        return False
    if abs(prev.bbox_x0 - current.bbox_x0) > _HEADING_FUSION_X0_TOLERANCE_PT:
        return False
    vertical_gap = current.bbox_y0 - prev.block.bbox[3]
    if vertical_gap < 0.0 or vertical_gap > _HEADING_FUSION_VERTICAL_GAP_MAX_PT:
        return False
    prev_trimmed = prev.text.rstrip()
    if prev_trimmed and prev_trimmed[-1] in _HEADING_FUSION_SENTENCE_TERMINATORS:
        return False
    combined_len = len(prev.text) + 1 + len(current.text)
    if combined_len > _HEADING_FUSION_COMBINED_TEXT_MAX_CHARS:
        return False
    return _share_single_typographic_signature(prev.block, current.block, extraction)


def _share_single_typographic_signature(b1: Block, b2: Block, extraction: ExtractionResult) -> bool:
    """Return ``True`` iff every span of both blocks has the same
    ``(size, font, flags, color)`` tuple — a single signature shared
    across the two blocks.

    The "single signature" condition is the heading-wrap invariant: a
    multi-line heading is typographically homogeneous, while a chapter
    pair "Capitolo N" + title or a small-caps composite "CAPITOLO" +
    title is by construction heterogeneous and will be skipped.
    """
    s1, e1 = b1.span_range
    s2, e2 = b2.span_range
    spans1 = extraction.spans[s1:e1]
    spans2 = extraction.spans[s2:e2]
    if not spans1 or not spans2:
        return False
    signatures = {(s.size, s.font, s.flags, s.color) for s in spans1}
    signatures.update((s.size, s.font, s.flags, s.color) for s in spans2)
    return len(signatures) == 1


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
