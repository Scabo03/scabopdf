"""Tier 1 generic classification — output of § 4.4.

See ARCHITECTURE.md § 4.4 for the canonical specification.

This module implements the generic classification heuristics shared across
all profiles. Five heuristics are tried in a fixed order, "first match wins":

1. ``empty_page`` — page-level. A page with zero extracted blocks produces
   a synthetic ``ClassifiedBlock`` with ``block_index = -1`` and the page
   index stored in ``subcategory``. The other four heuristics do not run on
   such pages because there are no blocks to inspect.
2. ``filigree`` — block-level. Wide block near the top of the page with at
   least one large-font span and a copyright keyword in its text.
3. ``header_zone`` — block-level. Block entirely within the top
   ``HEADER_ZONE_FRACTION`` of the page with low character count.
4. ``footer_zone`` — block-level. Symmetric to ``header_zone`` at the
   bottom of the page.
5. ``tiny_font_anchor`` — block-level. Every span in the block has
   ``size < TINY_FONT_MAX_SIZE`` (Marrone-style invisible anchors).
6. ``superscript_cross_reference`` — block-level. The block has a single
   superscript span whose text is one to four digits.

Blocks that match no heuristic become ``UNCLASSIFIED`` with reason
``no_match``. Blocks with an empty span range are treated the same way:
they have no signals to classify on.

After tier 1, the orchestrator dispatches to the plugin's
``refine_classification`` for tier 2 (profile-specific rules).
"""

from __future__ import annotations

import re

from scabopdf_pipeline.classification.types import ClassifiedBlock
from scabopdf_pipeline.extraction.types import (
    Block,
    ExtractionResult,
    PageGeometry,
    Span,
)
from scabopdf_pipeline.profiling.plugin import ProfilePlugin
from scabopdf_pipeline.profiling.profile import DocumentProfile
from scabopdf_pipeline.schema.categories import SemanticCategory

HEADER_ZONE_FRACTION = 0.08
"""Top fraction of the page considered the header zone (ARCHITECTURE.md § 4.4)."""

FOOTER_ZONE_FRACTION = 0.08
"""Bottom fraction of the page considered the footer zone (ARCHITECTURE.md § 4.4)."""

HEADER_FOOTER_MAX_CHARS = 100
"""Maximum character count (exclusive) for a header/footer candidate (§ 4.4)."""

TINY_FONT_MAX_SIZE = 2.0
"""Font size (exclusive, in points) below which a block is a page anchor (§ 4.4)."""

FILIGREE_MIN_FONT_SIZE = 12.0
"""Minimum font size (inclusive, in points) for a filigree candidate (§ 4.4)."""

FILIGREE_MIN_WIDTH_FRACTION = 0.70
"""Minimum block width as a fraction of page width for a filigree candidate (§ 4.4)."""

FILIGREE_MAX_TOP_FRACTION = 0.20
"""Maximum bbox.y0 as a fraction of page height for a filigree candidate (§ 4.4)."""

FILIGREE_KEYWORDS: tuple[str, ...] = (
    "Versione riservata",
    "Biblioteca It. Ciechi",
    "© Giuffrè",
)
"""Copyright/library keywords that mark a filigree (ARCHITECTURE.md § 4.4)."""

TIER1_REASONS: tuple[str, ...] = (
    "empty_page",
    "filigree",
    "header_zone",
    "footer_zone",
    "tiny_font_anchor",
    "superscript_cross_reference",
    "no_match",
)
"""Closed vocabulary of ``reason`` strings that tier 1 may emit.

Plugins are free to use any string in tier 2; only tier 1 is restricted.
"""

_SUPERSCRIPT_NUMERIC_PATTERN = re.compile(r"^\d{1,4}$")


def classify(
    extraction: ExtractionResult,
    profile: DocumentProfile,
    plugin: ProfilePlugin,
) -> list[ClassifiedBlock]:
    """Classify every block in ``extraction``, then dispatch to the plugin.

    Pure function: it neither mutates ``extraction`` nor reads any external
    state. The order of the returned list is page-major: pages are visited
    in the order of ``extraction.page_geometries``, and within each page the
    original flat index order of ``extraction.blocks`` is preserved.

    ``profile`` is currently unused by tier 1 but is part of the public
    signature so plugins (called via ``plugin.refine_classification``) can be
    given the same ``DocumentProfile`` the rest of the pipeline sees.
    """
    del profile  # reserved for future tier 1 heuristics; tier 2 receives the plugin.

    blocks_by_page: dict[int, list[tuple[int, Block]]] = {}
    for flat_idx, block in enumerate(extraction.blocks):
        blocks_by_page.setdefault(block.page, []).append((flat_idx, block))

    tier1: list[ClassifiedBlock] = []
    for geom in extraction.page_geometries:
        page_blocks = blocks_by_page.get(geom.page, [])
        if not page_blocks:
            tier1.append(
                ClassifiedBlock(
                    block_index=-1,
                    category=SemanticCategory.EMPTY_PAGE,
                    subcategory=str(geom.page),
                    reason="empty_page",
                )
            )
            continue
        for flat_idx, block in page_blocks:
            tier1.append(_classify_block(extraction, block, flat_idx, geom))

    return plugin.refine_classification(extraction, tier1)


def _classify_block(
    extraction: ExtractionResult,
    block: Block,
    flat_idx: int,
    geom: PageGeometry,
) -> ClassifiedBlock:
    spans = _block_spans(extraction, block)
    if not spans:
        return ClassifiedBlock(
            block_index=flat_idx,
            category=SemanticCategory.UNCLASSIFIED,
            reason="no_match",
        )

    if _is_filigree(block, spans, geom):
        return ClassifiedBlock(
            block_index=flat_idx,
            category=SemanticCategory.ARTIFACT_FILIGREE,
            reason="filigree",
        )
    if _is_header_zone(block, spans, geom):
        return ClassifiedBlock(
            block_index=flat_idx,
            category=SemanticCategory.ARTIFACT_RUNNING_HEADER,
            reason="header_zone",
        )
    if _is_footer_zone(block, spans, geom):
        return ClassifiedBlock(
            block_index=flat_idx,
            category=SemanticCategory.ARTIFACT_FOOTER,
            reason="footer_zone",
        )
    if _is_tiny_font_anchor(spans):
        return ClassifiedBlock(
            block_index=flat_idx,
            category=SemanticCategory.BOOK_PAGE_ANCHOR,
            reason="tiny_font_anchor",
        )
    if _is_superscript_cross_reference(spans):
        return ClassifiedBlock(
            block_index=flat_idx,
            category=SemanticCategory.CROSS_REFERENCE,
            reason="superscript_cross_reference",
        )
    return ClassifiedBlock(
        block_index=flat_idx,
        category=SemanticCategory.UNCLASSIFIED,
        reason="no_match",
    )


def _block_spans(extraction: ExtractionResult, block: Block) -> list[Span]:
    start, end = block.span_range
    return extraction.spans[start:end]


def _block_text(spans: list[Span]) -> str:
    return "".join(s.text for s in spans)


def _is_filigree(block: Block, spans: list[Span], geom: PageGeometry) -> bool:
    block_width = block.bbox[2] - block.bbox[0]
    if block_width < FILIGREE_MIN_WIDTH_FRACTION * geom.width_pt:
        return False
    if block.bbox[1] > FILIGREE_MAX_TOP_FRACTION * geom.height_pt:
        return False
    if not any(s.size >= FILIGREE_MIN_FONT_SIZE for s in spans):
        return False
    text_lower = _block_text(spans).lower()
    return any(kw.lower() in text_lower for kw in FILIGREE_KEYWORDS)


def _is_header_zone(block: Block, spans: list[Span], geom: PageGeometry) -> bool:
    if block.bbox[3] > HEADER_ZONE_FRACTION * geom.height_pt:
        return False
    return len(_block_text(spans)) < HEADER_FOOTER_MAX_CHARS


def _is_footer_zone(block: Block, spans: list[Span], geom: PageGeometry) -> bool:
    if block.bbox[1] < (1.0 - FOOTER_ZONE_FRACTION) * geom.height_pt:
        return False
    return len(_block_text(spans)) < HEADER_FOOTER_MAX_CHARS


def _is_tiny_font_anchor(spans: list[Span]) -> bool:
    return all(s.size < TINY_FONT_MAX_SIZE for s in spans)


def _is_superscript_cross_reference(spans: list[Span]) -> bool:
    if len(spans) != 1:
        return False
    span = spans[0]
    if not span.is_superscript:
        return False
    return bool(_SUPERSCRIPT_NUMERIC_PATTERN.match(span.text))
