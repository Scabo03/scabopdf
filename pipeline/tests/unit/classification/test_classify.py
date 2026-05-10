from scabopdf_pipeline.classification import classify
from scabopdf_pipeline.classification.types import ClassifiedBlock
from scabopdf_pipeline.extraction import flags
from scabopdf_pipeline.extraction.types import (
    Block,
    ExtractionResult,
    PageGeometry,
    Span,
)
from scabopdf_pipeline.profiles.unknown_generic import UnknownGenericProfile
from scabopdf_pipeline.profiling.profile import DocumentProfile
from scabopdf_pipeline.schema.categories import SemanticCategory

PAGE_W = 600.0
PAGE_H = 800.0


def _profile() -> DocumentProfile:
    return DocumentProfile(
        profile_id="unknown_generic",
        editorial_family="unknown",
        genre="unknown",
        confidence=0.0,
    )


def _plugin() -> UnknownGenericProfile:
    return UnknownGenericProfile()


def _geom(page: int = 0) -> PageGeometry:
    return PageGeometry(page=page, width_pt=PAGE_W, height_pt=PAGE_H, rotation=0)


def _span(
    text: str,
    *,
    size: float = 10.0,
    flag_value: int = 0,
    page: int = 0,
    block_index: int = 0,
    span_index: int = 0,
) -> Span:
    return Span(
        text=text,
        font="Helvetica",
        size=size,
        flags=flag_value,
        color=0,
        bbox=(0.0, 0.0, 10.0, 10.0),
        page=page,
        block_index=block_index,
        line_index=0,
        span_index=span_index,
    )


def _extraction(
    spans: list[Span],
    blocks: list[Block],
    geometries: list[PageGeometry],
) -> ExtractionResult:
    return ExtractionResult(
        spans=spans,
        blocks=blocks,
        page_geometries=geometries,
        page_images=[],
        drawings=[],
        warnings=[],
        page_count=len(geometries),
        is_encrypted=False,
        permissions=-4,
    )


def test_empty_page_synthesizes_sentinel_when_page_has_no_blocks() -> None:
    extraction = _extraction(spans=[], blocks=[], geometries=[_geom(0)])
    results = classify(extraction, _profile(), _plugin())
    assert len(results) == 1
    assert results[0] == ClassifiedBlock(
        block_index=-1,
        category=SemanticCategory.EMPTY_PAGE,
        subcategory="0",
        reason="empty_page",
    )


def test_empty_page_does_not_synthesize_when_page_has_blocks() -> None:
    span = _span("hello", size=10.0)
    block = Block(page=0, block_index=0, bbox=(50.0, 400.0, 200.0, 420.0), span_range=(0, 1))
    extraction = _extraction(spans=[span], blocks=[block], geometries=[_geom(0)])
    results = classify(extraction, _profile(), _plugin())
    assert len(results) == 1
    assert results[0].block_index == 0
    assert results[0].category is not SemanticCategory.EMPTY_PAGE


def test_filigree_positive() -> None:
    span = _span("© Giuffrè 2026", size=14.0)
    block = Block(
        page=0,
        block_index=0,
        bbox=(20.0, 30.0, 580.0, 60.0),
        span_range=(0, 1),
    )
    extraction = _extraction([span], [block], [_geom(0)])
    results = classify(extraction, _profile(), _plugin())
    assert results[0].category is SemanticCategory.ARTIFACT_FILIGREE
    assert results[0].reason == "filigree"


def test_filigree_negative_missing_keyword() -> None:
    span = _span("Titolo del libro", size=14.0)
    block = Block(
        page=0,
        block_index=0,
        bbox=(20.0, 30.0, 580.0, 60.0),
        span_range=(0, 1),
    )
    extraction = _extraction([span], [block], [_geom(0)])
    results = classify(extraction, _profile(), _plugin())
    assert results[0].category is not SemanticCategory.ARTIFACT_FILIGREE


def test_header_zone_positive() -> None:
    span = _span("Capitolo I", size=10.0)
    block = Block(
        page=0,
        block_index=0,
        bbox=(50.0, 10.0, 200.0, 30.0),
        span_range=(0, 1),
    )
    extraction = _extraction([span], [block], [_geom(0)])
    results = classify(extraction, _profile(), _plugin())
    assert results[0].category is SemanticCategory.ARTIFACT_RUNNING_HEADER
    assert results[0].reason == "header_zone"


def test_header_zone_negative_in_middle_of_page() -> None:
    span = _span("body text", size=10.0)
    block = Block(
        page=0,
        block_index=0,
        bbox=(50.0, 400.0, 200.0, 420.0),
        span_range=(0, 1),
    )
    extraction = _extraction([span], [block], [_geom(0)])
    results = classify(extraction, _profile(), _plugin())
    assert results[0].category is SemanticCategory.UNCLASSIFIED


def test_footer_zone_positive() -> None:
    span = _span("123", size=10.0)
    block = Block(
        page=0,
        block_index=0,
        bbox=(280.0, 770.0, 320.0, 790.0),
        span_range=(0, 1),
    )
    extraction = _extraction([span], [block], [_geom(0)])
    results = classify(extraction, _profile(), _plugin())
    assert results[0].category is SemanticCategory.ARTIFACT_FOOTER
    assert results[0].reason == "footer_zone"


def test_footer_zone_negative_too_many_chars() -> None:
    long_text = "x" * 200
    span = _span(long_text, size=10.0)
    block = Block(
        page=0,
        block_index=0,
        bbox=(20.0, 770.0, 580.0, 790.0),
        span_range=(0, 1),
    )
    extraction = _extraction([span], [block], [_geom(0)])
    results = classify(extraction, _profile(), _plugin())
    assert results[0].category is SemanticCategory.UNCLASSIFIED


def test_tiny_font_anchor_positive() -> None:
    span = _span("42", size=1.0)
    block = Block(
        page=0,
        block_index=0,
        bbox=(50.0, 400.0, 60.0, 410.0),
        span_range=(0, 1),
    )
    extraction = _extraction([span], [block], [_geom(0)])
    results = classify(extraction, _profile(), _plugin())
    assert results[0].category is SemanticCategory.BOOK_PAGE_ANCHOR
    assert results[0].reason == "tiny_font_anchor"


def test_tiny_font_anchor_negative_normal_size() -> None:
    span = _span("body", size=10.0)
    block = Block(
        page=0,
        block_index=0,
        bbox=(50.0, 400.0, 200.0, 420.0),
        span_range=(0, 1),
    )
    extraction = _extraction([span], [block], [_geom(0)])
    results = classify(extraction, _profile(), _plugin())
    assert results[0].category is SemanticCategory.UNCLASSIFIED


def test_superscript_cross_reference_positive() -> None:
    span = _span("12", size=8.0, flag_value=flags.SUPERSCRIPT)
    block = Block(
        page=0,
        block_index=0,
        bbox=(120.0, 400.0, 130.0, 410.0),
        span_range=(0, 1),
    )
    extraction = _extraction([span], [block], [_geom(0)])
    results = classify(extraction, _profile(), _plugin())
    assert results[0].category is SemanticCategory.CROSS_REFERENCE
    assert results[0].reason == "superscript_cross_reference"


def test_superscript_cross_reference_negative_not_superscript() -> None:
    span = _span("12", size=8.0, flag_value=0)
    block = Block(
        page=0,
        block_index=0,
        bbox=(120.0, 400.0, 130.0, 410.0),
        span_range=(0, 1),
    )
    extraction = _extraction([span], [block], [_geom(0)])
    results = classify(extraction, _profile(), _plugin())
    assert results[0].category is SemanticCategory.UNCLASSIFIED


def test_superscript_cross_reference_negative_multi_span() -> None:
    spans = [
        _span("1", size=8.0, flag_value=flags.SUPERSCRIPT, span_index=0),
        _span("2", size=8.0, flag_value=flags.SUPERSCRIPT, span_index=1),
    ]
    block = Block(
        page=0,
        block_index=0,
        bbox=(120.0, 400.0, 140.0, 410.0),
        span_range=(0, 2),
    )
    extraction = _extraction(spans, [block], [_geom(0)])
    results = classify(extraction, _profile(), _plugin())
    assert results[0].category is SemanticCategory.UNCLASSIFIED


def test_collision_superscript_in_header_zone_becomes_header() -> None:
    """Order matters: header_zone is checked before superscript_cross_reference."""
    span = _span("12", size=8.0, flag_value=flags.SUPERSCRIPT)
    block = Block(
        page=0,
        block_index=0,
        bbox=(50.0, 10.0, 60.0, 25.0),
        span_range=(0, 1),
    )
    extraction = _extraction([span], [block], [_geom(0)])
    results = classify(extraction, _profile(), _plugin())
    assert results[0].category is SemanticCategory.ARTIFACT_RUNNING_HEADER
    assert results[0].reason == "header_zone"


def test_unknown_generic_passthrough_preserves_tier1() -> None:
    """unknown_generic.refine_classification returns tier1 verdicts unchanged."""
    spans = [
        _span("Capitolo I", size=10.0, span_index=0),
        _span("body", size=10.0, page=0, block_index=1, span_index=0),
        _span("123", size=10.0, page=0, block_index=2, span_index=0),
    ]
    blocks = [
        Block(page=0, block_index=0, bbox=(50.0, 10.0, 200.0, 30.0), span_range=(0, 1)),
        Block(page=0, block_index=1, bbox=(50.0, 400.0, 200.0, 420.0), span_range=(1, 2)),
        Block(page=0, block_index=2, bbox=(280.0, 770.0, 320.0, 790.0), span_range=(2, 3)),
    ]
    extraction = _extraction(spans, blocks, [_geom(0)])
    results = classify(extraction, _profile(), _plugin())
    assert [cb.category for cb in results] == [
        SemanticCategory.ARTIFACT_RUNNING_HEADER,
        SemanticCategory.UNCLASSIFIED,
        SemanticCategory.ARTIFACT_FOOTER,
    ]


def test_classify_preserves_all_chars_and_block_references() -> None:
    """Conservation invariant: every real block has exactly one ClassifiedBlock,
    and the sum of characters across classified blocks equals the sum across
    the original extraction spans."""
    spans = [
        _span("Header", size=10.0, span_index=0),
        _span("body of paragraph", size=10.0, page=0, block_index=1, span_index=0),
        _span("more body text here", size=10.0, page=1, block_index=0, span_index=0),
        _span("99", size=10.0, page=1, block_index=1, span_index=0),
    ]
    blocks = [
        Block(page=0, block_index=0, bbox=(50.0, 10.0, 200.0, 30.0), span_range=(0, 1)),
        Block(page=0, block_index=1, bbox=(50.0, 400.0, 200.0, 420.0), span_range=(1, 2)),
        Block(page=1, block_index=0, bbox=(50.0, 400.0, 300.0, 420.0), span_range=(2, 3)),
        Block(page=1, block_index=1, bbox=(280.0, 770.0, 320.0, 790.0), span_range=(3, 4)),
    ]
    geometries = [_geom(0), _geom(1)]
    extraction = _extraction(spans, blocks, geometries)

    results = classify(extraction, _profile(), _plugin())

    real_indices = sorted(cb.block_index for cb in results if cb.block_index != -1)
    assert real_indices == list(range(len(extraction.blocks)))

    total_extraction_chars = sum(len(s.text) for s in extraction.spans)
    total_classified_chars = 0
    for cb in results:
        if cb.block_index == -1:
            continue
        block = extraction.blocks[cb.block_index]
        start, end = block.span_range
        total_classified_chars += sum(len(s.text) for s in extraction.spans[start:end])
    assert total_classified_chars == total_extraction_chars


def test_classify_visits_pages_in_geometry_order() -> None:
    """Page-major output ordering: page 0 blocks first, then page 1."""
    spans = [
        _span("p1", page=1, span_index=0),
        _span("p0", page=0, span_index=0),
    ]
    blocks = [
        Block(page=1, block_index=0, bbox=(50.0, 400.0, 100.0, 420.0), span_range=(0, 1)),
        Block(page=0, block_index=0, bbox=(50.0, 400.0, 100.0, 420.0), span_range=(1, 2)),
    ]
    extraction = _extraction(spans, blocks, [_geom(0), _geom(1)])
    results = classify(extraction, _profile(), _plugin())
    # page 0's block (flat index 1) is visited before page 1's block (flat index 0)
    assert [cb.block_index for cb in results] == [1, 0]
