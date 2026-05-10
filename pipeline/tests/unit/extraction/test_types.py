import dataclasses

import pytest

from scabopdf_pipeline.extraction import flags
from scabopdf_pipeline.extraction.types import (
    Block,
    DrawingInfo,
    ExtractionResult,
    PageGeometry,
    PageImageInfo,
    Span,
)


def _make_span(flag_value: int = 0) -> Span:
    return Span(
        text="hello",
        font="Helvetica",
        size=12.0,
        flags=flag_value,
        color=0,
        bbox=(0.0, 0.0, 10.0, 10.0),
        page=0,
        block_index=0,
        line_index=0,
        span_index=0,
    )


def test_span_construction() -> None:
    s = _make_span()
    assert s.text == "hello"
    assert s.font == "Helvetica"
    assert s.size == 12.0


def test_span_is_frozen() -> None:
    s = _make_span()
    with pytest.raises(dataclasses.FrozenInstanceError):
        s.text = "mutated"  # type: ignore[misc]


def test_span_flag_properties_all_off() -> None:
    s = _make_span(0)
    assert s.is_superscript is False
    assert s.is_italic is False
    assert s.is_serif is False
    assert s.is_monospace is False
    assert s.is_bold is False


def test_span_flag_properties_each_bit() -> None:
    assert _make_span(flags.SUPERSCRIPT).is_superscript is True
    assert _make_span(flags.ITALIC).is_italic is True
    assert _make_span(flags.SERIF).is_serif is True
    assert _make_span(flags.MONOSPACE).is_monospace is True
    assert _make_span(flags.BOLD).is_bold is True


def test_span_flag_properties_combined() -> None:
    s = _make_span(flags.BOLD | flags.ITALIC)
    assert s.is_bold is True
    assert s.is_italic is True
    assert s.is_serif is False


def test_block_is_frozen() -> None:
    b = Block(page=0, block_index=0, bbox=(0.0, 0.0, 1.0, 1.0), span_range=(0, 3))
    with pytest.raises(dataclasses.FrozenInstanceError):
        b.page = 1  # type: ignore[misc]


def test_page_image_info_defaults_empty_bboxes() -> None:
    info = PageImageInfo(page=0, count=0, has_full_page_image=False)
    assert info.bboxes == []


def test_extraction_result_holds_all_fields() -> None:
    span = _make_span()
    block = Block(page=0, block_index=0, bbox=(0.0, 0.0, 1.0, 1.0), span_range=(0, 1))
    geom = PageGeometry(page=0, width_pt=595.0, height_pt=842.0, rotation=0)
    img = PageImageInfo(page=0, count=0, has_full_page_image=False)
    drw = DrawingInfo(page=0, bbox=(0.0, 0.0, 100.0, 1.0), kind="horizontal_rule")
    result = ExtractionResult(
        spans=[span],
        blocks=[block],
        page_geometries=[geom],
        page_images=[img],
        drawings=[drw],
        warnings=[],
        page_count=1,
        is_encrypted=False,
        permissions=-4,
    )
    assert len(result.spans) == 1
    assert result.blocks[0].span_range == (0, 1)
    assert result.drawings[0].kind == "horizontal_rule"
    assert result.page_count == 1
