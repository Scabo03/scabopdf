"""Extraction dataclasses — output of § 3 (block extraction).

See ARCHITECTURE.md § 3.3 for the canonical specification.

All dataclasses are frozen: extraction is a pure read-only pass over the PDF,
nothing downstream should mutate the result.
"""

from __future__ import annotations

from dataclasses import dataclass, field

from scabopdf_pipeline.extraction import flags as flag_bits

BBox = tuple[float, float, float, float]

# PageIndex is a 0-based PDF page index, matching the indexing convention
# of PyMuPDF (fitz). All Block.page, Span.page, PageGeometry.page,
# PageImageInfo.page, DrawingInfo.page and Node.page_index fields use
# this semantic. Layer 1 never stores 1-based "book pages": those live
# only inside ``BOOK_PAGE_ANCHOR`` nodes and are recovered by the
# corresponding profile plugin.
PageIndex = int


@dataclass(frozen=True, kw_only=True)
class Span:
    text: str
    font: str
    size: float
    flags: int
    color: int
    bbox: BBox
    page: PageIndex
    block_index: int
    line_index: int
    span_index: int

    @property
    def is_superscript(self) -> bool:
        return flag_bits.has_flag(self.flags, flag_bits.SUPERSCRIPT)

    @property
    def is_italic(self) -> bool:
        return flag_bits.has_flag(self.flags, flag_bits.ITALIC)

    @property
    def is_serif(self) -> bool:
        return flag_bits.has_flag(self.flags, flag_bits.SERIF)

    @property
    def is_monospace(self) -> bool:
        return flag_bits.has_flag(self.flags, flag_bits.MONOSPACE)

    @property
    def is_bold(self) -> bool:
        return flag_bits.has_flag(self.flags, flag_bits.BOLD)


@dataclass(frozen=True, kw_only=True)
class Block:
    page: PageIndex
    block_index: int
    bbox: BBox
    span_range: tuple[int, int]
    """Half-open [start, end) range into ExtractionResult.spans."""


@dataclass(frozen=True, kw_only=True)
class PageGeometry:
    page: PageIndex
    width_pt: float
    height_pt: float
    rotation: int


@dataclass(frozen=True, kw_only=True)
class PageImageInfo:
    page: PageIndex
    count: int
    has_full_page_image: bool
    bboxes: list[BBox] = field(default_factory=list)


@dataclass(frozen=True, kw_only=True)
class DrawingInfo:
    page: PageIndex
    bbox: BBox
    kind: str
    """Currently only ``"horizontal_rule"``."""


@dataclass(frozen=True, kw_only=True)
class ExtractionResult:
    spans: list[Span]
    blocks: list[Block]
    page_geometries: list[PageGeometry]
    page_images: list[PageImageInfo]
    drawings: list[DrawingInfo]
    warnings: list[str]
    page_count: int
    is_encrypted: bool
    permissions: int
