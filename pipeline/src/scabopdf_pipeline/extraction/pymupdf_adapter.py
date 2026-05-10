"""PyMuPDF adapter — the only module in Layer 1 that imports ``fitz``.

Implements ``extract`` per ARCHITECTURE.md § 3: text spans, block boundaries,
per-page geometry, image metadata, horizontal-rule drawings, and warnings for
suspicious encoding or restricted permissions.
"""

from __future__ import annotations

from pathlib import Path
from typing import Any, cast

import fitz

from scabopdf_pipeline.extraction.types import (
    BBox,
    Block,
    DrawingInfo,
    ExtractionResult,
    PageGeometry,
    PageImageInfo,
    Span,
)

HORIZONTAL_RULE_MAX_HEIGHT_PT = 2.0
HORIZONTAL_RULE_MIN_WIDTH_PT = 100.0
FULL_PAGE_IMAGE_AREA_RATIO = 0.90


def extract(source: str | Path | bytes) -> ExtractionResult:
    """Open ``source`` with PyMuPDF and return the full extraction result."""
    doc = _open(source)
    try:
        spans: list[Span] = []
        blocks: list[Block] = []
        page_geometries: list[PageGeometry] = []
        page_images: list[PageImageInfo] = []
        drawings: list[DrawingInfo] = []

        # If still locked after best-effort empty authenticate, skip page walk:
        # PyMuPDF raises on page access. Surface what we know and warn.
        if not doc.needs_pass:
            for page_index in range(doc.page_count):
                page = doc[page_index]
                page_geometries.append(_build_page_geometry(page, page_index))
                _append_spans_and_blocks(spans, blocks, page, page_index)
                page_images.append(_build_page_image_info(page, page_index))
                drawings.extend(_build_drawings(page, page_index))

        warnings = _collect_warnings(doc)

        return ExtractionResult(
            spans=spans,
            blocks=blocks,
            page_geometries=page_geometries,
            page_images=page_images,
            drawings=drawings,
            warnings=warnings,
            page_count=int(doc.page_count),
            is_encrypted=bool(doc.is_encrypted),
            permissions=int(doc.permissions),
        )
    finally:
        doc.close()


def _open(source: str | Path | bytes) -> Any:
    if isinstance(source, bytes):
        doc = fitz.open(stream=source, filetype="pdf")
    else:
        doc = fitz.open(str(source))
    if doc.needs_pass:
        # Best-effort: many "encrypted" PDFs use an empty user password.
        doc.authenticate("")
    return doc


def _build_page_geometry(page: Any, page_index: int) -> PageGeometry:
    rect = page.rect
    return PageGeometry(
        page=page_index,
        width_pt=float(rect.width),
        height_pt=float(rect.height),
        rotation=int(page.rotation),
    )


def _append_spans_and_blocks(
    spans: list[Span],
    blocks: list[Block],
    page: Any,
    page_index: int,
) -> None:
    raw = cast(dict[str, Any], page.get_text("dict"))
    for raw_block in raw.get("blocks", []):
        if raw_block.get("type", 0) != 0:
            continue  # image blocks: handled separately in PageImageInfo
        block_index = int(raw_block.get("number", 0))
        start = len(spans)
        for line_index, raw_line in enumerate(raw_block.get("lines", [])):
            for span_index, raw_span in enumerate(raw_line.get("spans", [])):
                spans.append(
                    Span(
                        text=str(raw_span.get("text", "")),
                        font=str(raw_span.get("font", "")),
                        size=float(raw_span.get("size", 0.0)),
                        flags=int(raw_span.get("flags", 0)),
                        color=int(raw_span.get("color", 0)),
                        bbox=_as_bbox(raw_span.get("bbox", (0.0, 0.0, 0.0, 0.0))),
                        page=page_index,
                        block_index=block_index,
                        line_index=line_index,
                        span_index=span_index,
                    )
                )
        end = len(spans)
        blocks.append(
            Block(
                page=page_index,
                block_index=block_index,
                bbox=_as_bbox(raw_block.get("bbox", (0.0, 0.0, 0.0, 0.0))),
                span_range=(start, end),
            )
        )


def _build_page_image_info(page: Any, page_index: int) -> PageImageInfo:
    rect = page.rect
    page_area = float(rect.width) * float(rect.height)
    bboxes: list[BBox] = []
    has_full_page_image = False
    raw = cast(dict[str, Any], page.get_text("dict"))
    for raw_block in raw.get("blocks", []):
        if raw_block.get("type", 0) != 1:
            continue
        bbox = _as_bbox(raw_block.get("bbox", (0.0, 0.0, 0.0, 0.0)))
        bboxes.append(bbox)
        if page_area > 0:
            area = (bbox[2] - bbox[0]) * (bbox[3] - bbox[1])
            if area / page_area >= FULL_PAGE_IMAGE_AREA_RATIO:
                has_full_page_image = True
    return PageImageInfo(
        page=page_index,
        count=len(bboxes),
        has_full_page_image=has_full_page_image,
        bboxes=bboxes,
    )


def _build_drawings(page: Any, page_index: int) -> list[DrawingInfo]:
    out: list[DrawingInfo] = []
    for raw in page.get_drawings():
        rect = raw["rect"]
        height = float(rect.y1) - float(rect.y0)
        width = float(rect.x1) - float(rect.x0)
        if height <= HORIZONTAL_RULE_MAX_HEIGHT_PT and width >= HORIZONTAL_RULE_MIN_WIDTH_PT:
            out.append(
                DrawingInfo(
                    page=page_index,
                    bbox=(float(rect.x0), float(rect.y0), float(rect.x1), float(rect.y1)),
                    kind="horizontal_rule",
                )
            )
    return out


def _collect_warnings(doc: Any) -> list[str]:
    warnings: list[str] = []
    if doc.needs_pass:
        warnings.append("document is encrypted and could not be authenticated")
        return warnings
    warnings.extend(_encoding_warnings(doc))
    return warnings


def _encoding_warnings(doc: Any) -> list[str]:
    warnings: list[str] = []
    seen_xrefs: set[int] = set()
    for page_index in range(doc.page_count):
        for entry in doc.get_page_fonts(page_index, full=True):
            xref = int(entry[0])
            if xref in seen_xrefs:
                continue
            seen_xrefs.add(xref)
            name = str(entry[4])
            encoding = str(entry[5])
            if encoding != "Custom":
                continue
            to_unicode = doc.xref_get_key(xref, "ToUnicode")
            if to_unicode == ("null", "null"):
                warnings.append(
                    f"font {name!r} uses Custom encoding without ToUnicode CMap; "
                    "extracted text may be garbled"
                )
    return warnings


def _as_bbox(value: Any) -> BBox:
    return (float(value[0]), float(value[1]), float(value[2]), float(value[3]))
