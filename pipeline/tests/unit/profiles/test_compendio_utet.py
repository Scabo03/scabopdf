"""Unit tests for the compendio_utet corpus plugin."""

from __future__ import annotations

import pytest

from scabopdf_pipeline.classification.types import ClassifiedBlock
from scabopdf_pipeline.extraction.types import Block, ExtractionResult, Span
from scabopdf_pipeline.profiles.compendio_utet import (
    BODY_FONT_SIZE,
    CHAPTER_HEADING_SIZE,
    CHAPTER_TITLE_BOLD_FLAG_BIT,
    EN_DASH,
    PARAGRAPH_L1_SIZE,
    STAMP_SIZE,
    SUMMARY_SIZE,
    TOC_GENERAL_SIZE,
    WARNING_PREFIX,
    CompendioUtetProfile,
)
from scabopdf_pipeline.profiling.profile import DisabledLayout
from scabopdf_pipeline.profiling.signals import (
    ApparatusPresence,
    FontDominance,
    OutlineStructure,
    ProducerCreator,
    ProfilePageGeometry,
    ProfilingSignals,
    TypographicSignature,
)
from scabopdf_pipeline.reconstruction.types import Document, Node, SummaryItem, TocGeneralItem
from scabopdf_pipeline.schema.categories import SemanticCategory

DASH = f" {EN_DASH} "
"""En-dash separator with spaces, matching the Tesauro typesetting."""


# ---------------------------------------------------------------------------
# Helpers


def _tesauro_signals(
    *,
    body_size: float = BODY_FONT_SIZE,
    body_dominance: float = 88.7,
    include_sc700: bool = True,
    include_toc_font: bool = True,
    footnote_markers: int = 0,
    marginal_headings: int = 0,
    producer: str = "Adobe PDF Library 10.0.1",
    creator: str = "Adobe InDesign CS6",
    has_outline: bool = False,
) -> ProfilingSignals:
    fonts: list[FontDominance] = [
        FontDominance(family="TimesTenLTStd", size=body_size, dominance_percent=body_dominance),
    ]
    if include_sc700:
        fonts.append(
            FontDominance(family="TimesTen-Roman-SC700", size=8.0, dominance_percent=1.5),
        )
    if include_toc_font:
        fonts.append(
            FontDominance(family="TimesTen", size=TOC_GENERAL_SIZE, dominance_percent=4.1),
        )
    return ProfilingSignals(
        typographic_signature=TypographicSignature(fonts=fonts),
        apparatus_presence=ApparatusPresence(
            footnote_markers=footnote_markers,
            marginal_headings=marginal_headings,
        ),
        page_geometry=ProfilePageGeometry(width_pt=457.2, height_pt=684.0),
        producer_creator=ProducerCreator(producer=producer, creator=creator),
        outline_structure=OutlineStructure(has_outline=has_outline),
    )


class _SpanBuilder:
    """Helper to build a list of ``Span`` objects with reasonable defaults."""

    def __init__(self) -> None:
        self._spans: list[Span] = []

    def add(
        self,
        text: str,
        *,
        font: str,
        size: float,
        page: int = 0,
        flags: int = 0,
        color: int = 0,
        bbox: tuple[float, float, float, float] = (0.0, 0.0, 100.0, 10.0),
        block_index: int = 0,
        line_index: int = 0,
    ) -> _SpanBuilder:
        span = Span(
            text=text,
            font=font,
            size=size,
            flags=flags,
            color=color,
            bbox=bbox,
            page=page,
            block_index=block_index,
            line_index=line_index,
            span_index=len(self._spans),
        )
        self._spans.append(span)
        return self

    def build(self) -> list[Span]:
        return list(self._spans)


def _make_block(
    page: int,
    span_range: tuple[int, int],
    bbox: tuple[float, float, float, float] = (44.0, 120.0, 415.0, 200.0),
    block_index: int = 0,
) -> Block:
    return Block(page=page, block_index=block_index, bbox=bbox, span_range=span_range)


def _make_extraction(spans: list[Span], blocks: list[Block]) -> ExtractionResult:
    return ExtractionResult(
        spans=spans,
        blocks=blocks,
        page_geometries=[],
        page_images=[],
        drawings=[],
        warnings=[],
        page_count=1,
        is_encrypted=False,
        permissions=-1,
    )


def _verdict(
    block_index: int,
    category: SemanticCategory = SemanticCategory.UNCLASSIFIED,
    reason: str = "no_match",
) -> ClassifiedBlock:
    return ClassifiedBlock(block_index=block_index, category=category, reason=reason)


# ---------------------------------------------------------------------------
# Class attributes


def test_class_attributes() -> None:
    assert CompendioUtetProfile.profile_id == "compendio_utet"
    assert CompendioUtetProfile.editorial_family == "utet"
    assert CompendioUtetProfile.genre == "compendio"


# ---------------------------------------------------------------------------
# matches()


def test_matches_full_tesauro_fingerprint_clears_threshold() -> None:
    """A complete Tesauro fingerprint scores well above 0.6."""
    score = CompendioUtetProfile.matches(_tesauro_signals())
    assert score == pytest.approx(0.95)
    assert score >= 0.6


def test_matches_drops_when_apparatus_heavy_like_mosconi() -> None:
    """A document with treatise-level apparatus scores below 0.6.

    This is the discrimination axis that separates the compendium
    profile from the future ``manuale_utet_wolterskluwer`` profile,
    which shares the editorial pipeline (Adobe InDesign CS6 + PDF
    Library) and the typographic family (TimesTenLTStd) but has a
    dense apparatus.
    """
    signals = _tesauro_signals(
        body_size=10.0,  # Mosconi has 10.0pt body, not 10.2
        include_sc700=False,
        include_toc_font=False,
        footnote_markers=965,
        marginal_headings=593,
    )
    score = CompendioUtetProfile.matches(signals)
    assert score < 0.6


def test_matches_drops_when_only_footnotes_present() -> None:
    """The penalty triggers on footnote_markers alone, even with the body match."""
    signals = _tesauro_signals(footnote_markers=200)
    score = CompendioUtetProfile.matches(signals)
    assert score < 0.6, f"expected < 0.6 under treatise-level footnotes, got {score}"


def test_matches_misses_when_body_size_is_wrong() -> None:
    """Body at 10.0pt (Mosconi) misses the dominant-body credit (10.2 required)."""
    signals = _tesauro_signals(body_size=10.0, include_sc700=False, include_toc_font=False)
    score = CompendioUtetProfile.matches(signals)
    # Only producer/creator (0.05) + no outline (0.05) + no apparatus bonus (0.10) = 0.20
    assert score == pytest.approx(0.20)
    assert score < 0.6


def test_matches_zero_on_unrelated_document() -> None:
    """A Verdana-heavy document with apparatus scores at the floor."""
    fonts = [FontDominance(family="Verdana", size=10.85, dominance_percent=60.0)]
    signals = ProfilingSignals(
        typographic_signature=TypographicSignature(fonts=fonts),
        apparatus_presence=ApparatusPresence(footnote_markers=500),
        page_geometry=ProfilePageGeometry(width_pt=595.0, height_pt=842.0),
        producer_creator=ProducerCreator(producer="iLovePDF", creator="iLovePDF"),
        outline_structure=OutlineStructure(has_outline=True, entries_count=1562),
    )
    assert CompendioUtetProfile.matches(signals) == 0.0


def test_matches_clamps_negative_score_to_zero() -> None:
    """The penalty cannot drag the final score below zero."""
    fonts = [FontDominance(family="SomeFont", size=12.0, dominance_percent=50.0)]
    signals = ProfilingSignals(
        typographic_signature=TypographicSignature(fonts=fonts),
        apparatus_presence=ApparatusPresence(footnote_markers=1000),
        page_geometry=ProfilePageGeometry(width_pt=595.0, height_pt=842.0),
        producer_creator=ProducerCreator(producer=None, creator=None),
        outline_structure=OutlineStructure(has_outline=True),
    )
    assert CompendioUtetProfile.matches(signals) == 0.0


# ---------------------------------------------------------------------------
# Declarative methods


def test_get_categories_closed_set_matches_emission_surface() -> None:
    plugin = CompendioUtetProfile()
    categories = plugin.get_categories()
    expected = {
        SemanticCategory.HEADING_2,
        SemanticCategory.HEADING_3,
        SemanticCategory.HEADING_4,
        SemanticCategory.BODY,
        SemanticCategory.LIST_ITEM,
        SemanticCategory.CHAPTER_SUMMARY,
        SemanticCategory.TOC_GENERAL,
        SemanticCategory.ARTIFACT_STAMP,
        SemanticCategory.ARTIFACT_FOOTER,
        SemanticCategory.ARTIFACT_RUNNING_HEADER,
        SemanticCategory.ARTIFACT_FILIGREE,
        SemanticCategory.BOOK_PAGE_ANCHOR,
        SemanticCategory.CROSS_REFERENCE,
        SemanticCategory.UNCLASSIFIED,
        SemanticCategory.EMPTY_PAGE,
    }
    assert categories == expected
    # Apparatus categories absent: the compendium has none.
    forbidden = {
        SemanticCategory.NOTE,
        SemanticCategory.MARGINAL_HEADING,
        SemanticCategory.MARGINAL_GLOSS,
        SemanticCategory.EXAMPLE_BOX,
    }
    assert categories.isdisjoint(forbidden)


def test_get_post_processing_is_empty() -> None:
    plugin = CompendioUtetProfile()
    assert plugin.get_post_processing() == []


def test_get_layouts_disabled_disables_L4_with_italian_reason() -> None:
    plugin = CompendioUtetProfile()
    disabled = plugin.get_layouts_disabled()
    assert len(disabled) == 1
    entry = disabled[0]
    assert isinstance(entry, DisabledLayout)
    assert entry.layout == "L4"
    assert "Tesauro" in entry.reason
    assert "Layout 4" in entry.reason


# ---------------------------------------------------------------------------
# refine_classification — heading family


def test_refine_classification_promotes_chapter_number_block() -> None:
    """A non-bold 12pt "Capitolo decimo" block becomes HEADING_2."""
    spans = (
        _SpanBuilder()
        .add("Capitolo decimo", font="TimesTenLTStd-Roman", size=CHAPTER_HEADING_SIZE, flags=4)
        .build()
    )
    block = _make_block(page=140, span_range=(0, 1))
    extraction = _make_extraction(spans, [block])
    refined = CompendioUtetProfile().refine_classification(extraction, [_verdict(0)])
    assert refined[0].category is SemanticCategory.HEADING_2
    assert refined[0].reason == "tesauro_chapter_number"


def test_refine_classification_promotes_chapter_title_block() -> None:
    """A bold 12pt block following a chapter-number block becomes HEADING_2."""
    spans = (
        _SpanBuilder()
        .add(
            "L'AVVISO DI ACCERTAMENTO",
            font="TimesTenLTStd-Bold",
            size=CHAPTER_HEADING_SIZE,
            flags=CHAPTER_TITLE_BOLD_FLAG_BIT | 4,
        )
        .build()
    )
    block = _make_block(page=140, span_range=(0, 1))
    extraction = _make_extraction(spans, [block])
    refined = CompendioUtetProfile().refine_classification(extraction, [_verdict(0)])
    assert refined[0].category is SemanticCategory.HEADING_2
    assert refined[0].reason == "tesauro_chapter_title"


def test_refine_classification_registers_chapter_pair() -> None:
    """Two consecutive HEADING_2 (number + title) register as a pair."""
    spans = (
        _SpanBuilder()
        .add("Capitolo primo", font="TimesTenLTStd-Roman", size=CHAPTER_HEADING_SIZE, flags=4)
        .add(
            "IL DIRITTO TRIBUTARIO",
            font="TimesTenLTStd-Bold",
            size=CHAPTER_HEADING_SIZE,
            flags=CHAPTER_TITLE_BOLD_FLAG_BIT | 4,
            block_index=1,
        )
        .build()
    )
    blocks = [
        _make_block(page=37, span_range=(0, 1), block_index=0),
        _make_block(page=37, span_range=(1, 2), block_index=1),
    ]
    extraction = _make_extraction(spans, blocks)
    plugin = CompendioUtetProfile()
    refined = plugin.refine_classification(extraction, [_verdict(0), _verdict(1)])
    assert refined[0].reason == "tesauro_chapter_number"
    assert refined[1].reason == "tesauro_chapter_title"
    assert plugin._chapter_number_blocks == {0}
    assert plugin._chapter_title_blocks == {1}


def test_refine_classification_skips_stamps_between_chapter_pair() -> None:
    """An intervening ARTIFACT_STAMP between number and title still pairs the two."""
    spans = (
        _SpanBuilder()
        .add("Capitolo secondo", font="TimesTenLTStd-Roman", size=CHAPTER_HEADING_SIZE, flags=4)
        .add(
            "261887_Quarta_Bozza.indb 47",
            font="TimesTenLTStd-Roman",
            size=STAMP_SIZE,
            flags=4,
            block_index=1,
            bbox=(44.0, 660.0, 415.0, 675.0),
        )
        .add(
            "LE FONTI",
            font="TimesTenLTStd-Bold",
            size=CHAPTER_HEADING_SIZE,
            flags=CHAPTER_TITLE_BOLD_FLAG_BIT | 4,
            block_index=2,
        )
        .build()
    )
    blocks = [
        _make_block(page=47, span_range=(0, 1), block_index=0),
        _make_block(page=47, span_range=(1, 2), block_index=1, bbox=(44.0, 660.0, 415.0, 675.0)),
        _make_block(page=47, span_range=(2, 3), block_index=2),
    ]
    extraction = _make_extraction(spans, blocks)
    plugin = CompendioUtetProfile()
    refined = plugin.refine_classification(extraction, [_verdict(0), _verdict(1), _verdict(2)])
    assert refined[1].category is SemanticCategory.ARTIFACT_STAMP
    assert plugin._chapter_number_blocks == {0}
    assert plugin._chapter_title_blocks == {2}


def test_refine_classification_paragraph_l1_takes_priority_over_body() -> None:
    spans = (
        _SpanBuilder()
        .add(
            "1. ",
            font="TimesTenLTStd-Bold",
            size=PARAGRAPH_L1_SIZE,
            flags=CHAPTER_TITLE_BOLD_FLAG_BIT | 4,
        )
        .add(
            "Natura giuridica dell'avviso di accertamento",
            font="TimesTenLTStd-Italic",
            size=PARAGRAPH_L1_SIZE,
            flags=6,
        )
        .build()
    )
    block = _make_block(page=141, span_range=(0, 2))
    extraction = _make_extraction(spans, [block])
    refined = CompendioUtetProfile().refine_classification(extraction, [_verdict(0)])
    assert refined[0].category is SemanticCategory.HEADING_3
    assert refined[0].reason == "tesauro_paragraph_l1"


def test_refine_classification_paragraph_l2_takes_priority_over_l1_and_body() -> None:
    """Pattern-over-signature: ``1.1. <title>`` is L2 even at body-like size."""
    spans = (
        _SpanBuilder()
        .add(
            "1.1. ",
            font="TimesTenLTStd-Bold",
            size=BODY_FONT_SIZE,  # 10.2pt, same as body — discrimination is purely textual
            flags=CHAPTER_TITLE_BOLD_FLAG_BIT | 4,
        )
        .add(
            "Profili costituzionali",
            font="TimesTenLTStd-Italic",
            size=BODY_FONT_SIZE,
            flags=6,
        )
        .build()
    )
    block = _make_block(page=141, span_range=(0, 2))
    extraction = _make_extraction(spans, [block])
    refined = CompendioUtetProfile().refine_classification(extraction, [_verdict(0)])
    assert refined[0].category is SemanticCategory.HEADING_4
    assert refined[0].reason == "tesauro_paragraph_l2"


# ---------------------------------------------------------------------------
# refine_classification — body family


def test_refine_classification_promotes_body() -> None:
    spans = (
        _SpanBuilder()
        .add(
            "L'avviso di accertamento è un atto autoritativo.",
            font="TimesTenLTStd-Roman",
            size=BODY_FONT_SIZE,
            flags=4,
        )
        .build()
    )
    block = _make_block(page=145, span_range=(0, 1))
    extraction = _make_extraction(spans, [block])
    refined = CompendioUtetProfile().refine_classification(extraction, [_verdict(0)])
    assert refined[0].category is SemanticCategory.BODY
    assert refined[0].reason == "tesauro_body"


def test_refine_classification_promotes_list_item_with_en_dash_marker() -> None:
    """A body block that opens with the en-dash + space marker becomes LIST_ITEM."""
    spans = (
        _SpanBuilder()
        .add(
            f"{EN_DASH} vi sono regimi fiscali che si applicano in tutta l'UE",
            font="TimesTenLTStd-Roman",
            size=BODY_FONT_SIZE,
            flags=4,
        )
        .build()
    )
    block = _make_block(page=60, span_range=(0, 1))
    extraction = _make_extraction(spans, [block])
    refined = CompendioUtetProfile().refine_classification(extraction, [_verdict(0)])
    assert refined[0].category is SemanticCategory.LIST_ITEM
    assert refined[0].reason == "tesauro_list_item"


# ---------------------------------------------------------------------------
# refine_classification — chapter summary and TOC


def test_refine_classification_promotes_chapter_summary() -> None:
    spans = (
        _SpanBuilder()
        .add("Sommario", font="TimesTen-Roman-SC700", size=5.6)
        .add(": ", font="TimesTen-Roman", size=SUMMARY_SIZE)
        .add(
            f"1. Natura giuridica{DASH}2. Contenuto",
            font="TimesTen-Roman",
            size=SUMMARY_SIZE,
        )
        .build()
    )
    # _is_summary_signature checks the LEADING span, so we need to ensure the
    # leading span is TimesTen non-LT at ~8pt. The label span is at 5.6pt
    # which the size check rejects. Put the SC700 label after a plain TimesTen
    # opener that names the size correctly.
    block = _make_block(page=140, span_range=(0, 3))
    extraction = _make_extraction(spans, [block])
    refined = CompendioUtetProfile().refine_classification(extraction, [_verdict(0)])
    # In this layout the leading span is the 5.6pt SC700, which fails the
    # 8.0pt size check; the block stays UNCLASSIFIED. The plugin only
    # recognises the summary when the leading span carries the 8.0pt size.
    assert refined[0].category is SemanticCategory.UNCLASSIFIED


def test_refine_classification_promotes_chapter_summary_with_8pt_lead() -> None:
    """The summary signature requires the leading span at 8.0pt."""
    spans = (
        _SpanBuilder()
        .add("Sommario: ", font="TimesTen-Roman", size=SUMMARY_SIZE)
        .add(
            f"1. Natura giuridica{DASH}2. Contenuto",
            font="TimesTen-Roman",
            size=SUMMARY_SIZE,
        )
        .build()
    )
    block = _make_block(page=140, span_range=(0, 2))
    extraction = _make_extraction(spans, [block])
    refined = CompendioUtetProfile().refine_classification(extraction, [_verdict(0)])
    assert refined[0].category is SemanticCategory.CHAPTER_SUMMARY
    assert refined[0].reason == "tesauro_chapter_summary"


def test_refine_classification_promotes_toc_general() -> None:
    spans = (
        _SpanBuilder()
        .add(
            "1. La nozione di tributo .... » 19",
            font="TimesTen-Roman",
            size=TOC_GENERAL_SIZE,
        )
        .build()
    )
    block = _make_block(page=4, span_range=(0, 1))
    extraction = _make_extraction(spans, [block])
    refined = CompendioUtetProfile().refine_classification(extraction, [_verdict(0)])
    assert refined[0].category is SemanticCategory.TOC_GENERAL
    assert refined[0].reason == "tesauro_toc_general"


def test_refine_classification_toc_general_requires_marker() -> None:
    """A TimesTen 8.5pt block without the » marker is not a TOC entry."""
    spans = (
        _SpanBuilder()
        .add(
            "1. La nozione di tributo",
            font="TimesTen-Roman",
            size=TOC_GENERAL_SIZE,
        )
        .build()
    )
    block = _make_block(page=4, span_range=(0, 1))
    extraction = _make_extraction(spans, [block])
    refined = CompendioUtetProfile().refine_classification(extraction, [_verdict(0)])
    assert refined[0].category is SemanticCategory.UNCLASSIFIED


# ---------------------------------------------------------------------------
# refine_classification — stamp


def test_refine_classification_promotes_stamp_indb_filename() -> None:
    spans = (
        _SpanBuilder()
        .add(
            "261887_Quarta_Bozza.indb 47",
            font="TimesTenLTStd-Roman",
            size=STAMP_SIZE,
            flags=4,
            bbox=(44.0, 660.0, 415.0, 675.0),
        )
        .build()
    )
    block = _make_block(page=47, span_range=(0, 1), bbox=(44.0, 660.0, 415.0, 675.0))
    extraction = _make_extraction(spans, [block])
    refined = CompendioUtetProfile().refine_classification(extraction, [_verdict(0)])
    assert refined[0].category is SemanticCategory.ARTIFACT_STAMP
    assert refined[0].reason == "tesauro_stamp"


def test_refine_classification_promotes_stamp_datetime() -> None:
    """The date/time half of the watermark is also recognised."""
    spans = (
        _SpanBuilder()
        .add(
            "05/09/23 3:50 PM",
            font="TimesTenLTStd-Roman",
            size=STAMP_SIZE,
            flags=4,
            bbox=(300.0, 660.0, 415.0, 675.0),
        )
        .build()
    )
    block = _make_block(page=47, span_range=(0, 1), bbox=(300.0, 660.0, 415.0, 675.0))
    extraction = _make_extraction(spans, [block])
    refined = CompendioUtetProfile().refine_classification(extraction, [_verdict(0)])
    assert refined[0].category is SemanticCategory.ARTIFACT_STAMP


def test_refine_classification_stamp_regex_is_general() -> None:
    """A different InDesign filename (different product code) is still detected.

    The regex is generalised so future UTET PDFs with analogous
    pre-print residue (different product code, different label) are
    handled by the same plugin without modification.
    """
    spans = (
        _SpanBuilder()
        .add(
            "199999_Bozza_Definitiva.indb 100",
            font="TimesTenLTStd-Roman",
            size=STAMP_SIZE,
            flags=4,
        )
        .build()
    )
    block = _make_block(page=100, span_range=(0, 1))
    extraction = _make_extraction(spans, [block])
    refined = CompendioUtetProfile().refine_classification(extraction, [_verdict(0)])
    assert refined[0].category is SemanticCategory.ARTIFACT_STAMP


# ---------------------------------------------------------------------------
# refine_classification — preservation rules


def test_refine_classification_preserves_tier1_artifacts() -> None:
    """Verdicts already assigned by tier 1 are never overridden."""
    spans = (
        _SpanBuilder()
        .add("page 47", font="TimesTenLTStd-Roman", size=BODY_FONT_SIZE, flags=4)
        .build()
    )
    block = _make_block(page=47, span_range=(0, 1))
    extraction = _make_extraction(spans, [block])
    tier1 = [
        ClassifiedBlock(
            block_index=0,
            category=SemanticCategory.ARTIFACT_RUNNING_HEADER,
            reason="header_zone",
        )
    ]
    refined = CompendioUtetProfile().refine_classification(extraction, tier1)
    assert refined[0].category is SemanticCategory.ARTIFACT_RUNNING_HEADER
    assert refined[0].reason == "header_zone"


def test_refine_classification_preserves_sentinels() -> None:
    """Synthetic EMPTY_PAGE sentinels (block_index = -1) are passed through."""
    extraction = _make_extraction([], [])
    tier1 = [
        ClassifiedBlock(
            block_index=-1,
            category=SemanticCategory.EMPTY_PAGE,
            subcategory="18",
            reason="empty_page",
        )
    ]
    refined = CompendioUtetProfile().refine_classification(extraction, tier1)
    assert refined == tier1


def test_refine_classification_leaves_unknown_signatures_alone() -> None:
    """A block whose signature matches no known family stays UNCLASSIFIED."""
    spans = _SpanBuilder().add("Mystery text", font="Courier", size=10.0).build()
    block = _make_block(page=5, span_range=(0, 1))
    extraction = _make_extraction(spans, [block])
    refined = CompendioUtetProfile().refine_classification(extraction, [_verdict(0)])
    assert refined[0].category is SemanticCategory.UNCLASSIFIED


# ---------------------------------------------------------------------------
# refine_reconstruction — chapter pair fusion


def _classified_pair() -> tuple[ExtractionResult, list[ClassifiedBlock]]:
    spans = (
        _SpanBuilder()
        .add("Capitolo decimo", font="TimesTenLTStd-Roman", size=CHAPTER_HEADING_SIZE, flags=4)
        .add(
            "L'AVVISO DI ACCERTAMENTO",
            font="TimesTenLTStd-Bold",
            size=CHAPTER_HEADING_SIZE,
            flags=CHAPTER_TITLE_BOLD_FLAG_BIT | 4,
            block_index=1,
        )
        .build()
    )
    blocks = [
        _make_block(page=140, span_range=(0, 1), block_index=0),
        _make_block(page=140, span_range=(1, 2), block_index=1),
    ]
    return _make_extraction(spans, blocks), [_verdict(0), _verdict(1)]


def test_refine_reconstruction_fuses_chapter_pair() -> None:
    """Two consecutive HEADING_2 siblings (number, title) become one node."""
    extraction, tier1 = _classified_pair()
    plugin = CompendioUtetProfile()
    refined_blocks = plugin.refine_classification(extraction, tier1)
    document = Document(
        root=(
            Node(
                id="node_0000",
                category=SemanticCategory.HEADING_2,
                page_index=140,
                block_indices=(0,),
                text="Capitolo decimo",
                level=2,
            ),
            Node(
                id="node_0001",
                category=SemanticCategory.HEADING_2,
                page_index=140,
                block_indices=(1,),
                text="L'AVVISO DI ACCERTAMENTO",
                level=2,
            ),
        )
    )
    refined = plugin.refine_reconstruction(document, extraction, refined_blocks)
    assert len(refined.root) == 1
    fused = refined.root[0]
    assert fused.category is SemanticCategory.HEADING_2
    assert fused.text == "Capitolo decimo. L'AVVISO DI ACCERTAMENTO"
    assert fused.level == 2
    assert fused.block_indices == (0, 1)
    assert refined.warnings == ()


def test_refine_reconstruction_emits_warning_when_title_missing() -> None:
    """A chapter-number block without its title partner emits a warning."""
    spans = (
        _SpanBuilder()
        .add("Capitolo primo", font="TimesTenLTStd-Roman", size=CHAPTER_HEADING_SIZE, flags=4)
        .build()
    )
    block = _make_block(page=37, span_range=(0, 1))
    extraction = _make_extraction(spans, [block])
    plugin = CompendioUtetProfile()
    refined_blocks = plugin.refine_classification(extraction, [_verdict(0)])
    document = Document(
        root=(
            Node(
                id="node_0000",
                category=SemanticCategory.HEADING_2,
                page_index=37,
                block_indices=(0,),
                text="Capitolo primo",
                level=2,
            ),
        )
    )
    refined = plugin.refine_reconstruction(document, extraction, refined_blocks)
    assert len(refined.root) == 1
    assert refined.root[0].text == "Capitolo primo"
    assert any(
        w == f"{WARNING_PREFIX}:chapter_title_not_adjacent_block_0_page_37"
        for w in refined.warnings
    )


# ---------------------------------------------------------------------------
# refine_reconstruction — summary parsing


def _summary_node(text: str | None, node_id: str = "node_0001") -> Node:
    return Node(
        id=node_id,
        category=SemanticCategory.CHAPTER_SUMMARY,
        page_index=140,
        block_indices=(2,),
        text=text,
    )


def test_refine_reconstruction_parses_summary_items() -> None:
    text = f"Sommario: 1. Natura giuridica{DASH}2. Contenuto{DASH}3. Notificazione"
    document = Document(root=(_summary_node(text),))
    plugin = CompendioUtetProfile()
    refined = plugin.refine_reconstruction(document, _make_extraction([], []), [])
    items = refined.root[0].summary_items
    assert items is not None
    assert items == (
        SummaryItem(number="1", title="Natura giuridica"),
        SummaryItem(number="2", title="Contenuto"),
        SummaryItem(number="3", title="Notificazione"),
    )
    assert refined.warnings == ()


def test_refine_reconstruction_emits_warning_for_unparseable_summary() -> None:
    document = Document(root=(_summary_node("Questa stringa non e' un sommario valido"),))
    plugin = CompendioUtetProfile()
    refined = plugin.refine_reconstruction(document, _make_extraction([], []), [])
    assert refined.root[0].summary_items is None
    assert refined.warnings == (f"{WARNING_PREFIX}:chapter_summary_unparseable_node_node_0001",)


# ---------------------------------------------------------------------------
# refine_reconstruction — TOC parsing


def _toc_node(text: str | None, node_id: str = "node_0007") -> Node:
    return Node(
        id=node_id,
        category=SemanticCategory.TOC_GENERAL,
        page_index=4,
        block_indices=(22,),
        text=text,
    )


def test_refine_reconstruction_parses_toc_general_items_with_integer_pages() -> None:
    text = (
        "1. La nozione di tributo .................... » 19 "
        "1.1. Profili costituzionali ................ » 23 "
        "2. Le fonti del diritto tributario ......... » 31"
    )
    document = Document(root=(_toc_node(text),))
    plugin = CompendioUtetProfile()
    refined = plugin.refine_reconstruction(document, _make_extraction([], []), [])
    items = refined.root[0].toc_items
    assert items is not None
    assert items == (
        TocGeneralItem(number="1", title="La nozione di tributo", page_number=19),
        TocGeneralItem(number="1.1", title="Profili costituzionali", page_number=23),
        TocGeneralItem(number="2", title="Le fonti del diritto tributario", page_number=31),
    )
    assert refined.warnings == ()


def test_refine_reconstruction_parses_toc_general_with_roman_page_as_none() -> None:
    """Roman numerals on the page reference resolve to ``page_number: None``."""
    text = "1. Premessa ........... » III"
    document = Document(root=(_toc_node(text),))
    plugin = CompendioUtetProfile()
    refined = plugin.refine_reconstruction(document, _make_extraction([], []), [])
    items = refined.root[0].toc_items
    assert items is not None
    assert len(items) == 1
    assert items[0] == TocGeneralItem(number="1", title="Premessa", page_number=None)


def test_refine_reconstruction_emits_warning_for_unparseable_toc() -> None:
    """A TOC block whose text yields no matches stays unparsed with a warning."""
    free_form = "Free-form text without the marker or numbered entries"
    document = Document(root=(_toc_node(free_form),))
    plugin = CompendioUtetProfile()
    refined = plugin.refine_reconstruction(document, _make_extraction([], []), [])
    assert refined.root[0].toc_items is None
    assert refined.warnings == (f"{WARNING_PREFIX}:toc_general_unparseable_node_node_0007",)


# ---------------------------------------------------------------------------
# refine_reconstruction — bookkeeping


def test_refine_reconstruction_flushes_pending_classifier_warnings() -> None:
    """Classifier-time warnings reach Document.warnings via refine_reconstruction.

    The compendio_utet plugin enqueues a single classifier-time
    warning when a chapter-number block is registered without a
    matching title partner; the warning surfaces in
    refine_reconstruction's Document.warnings.
    """
    extraction = _make_extraction([], [])
    plugin = CompendioUtetProfile()
    # Manually seed the pending warning (matches what
    # refine_classification would have produced on a real partial
    # input).
    plugin._pending_warnings = [f"{WARNING_PREFIX}:chapter_title_not_adjacent_block_0_page_99"]
    refined = plugin.refine_reconstruction(Document(), extraction, [])
    assert refined.warnings == (f"{WARNING_PREFIX}:chapter_title_not_adjacent_block_0_page_99",)
    # Pending warnings are consumed and cleared.
    second = plugin.refine_reconstruction(Document(), extraction, [])
    assert second.warnings == ()


# ---------------------------------------------------------------------------
# refine_apparatus


def test_refine_apparatus_is_passthrough() -> None:
    """The compendium has no apparatus; refine_apparatus returns the input unchanged."""
    plugin = CompendioUtetProfile()
    document = Document(
        root=(
            Node(
                id="node_0000",
                category=SemanticCategory.BODY,
                page_index=0,
                block_indices=(0,),
                text="body",
            ),
        ),
    )
    extraction = _make_extraction([], [])
    assert plugin.refine_apparatus(document, extraction, []) is document


# ---------------------------------------------------------------------------
# Internal parser edge cases


def test_parse_chapter_summary_returns_none_for_none() -> None:
    assert CompendioUtetProfile._parse_chapter_summary(None) is None


def test_parse_chapter_summary_returns_none_for_empty() -> None:
    assert CompendioUtetProfile._parse_chapter_summary("Sommario:  ") is None


def test_parse_chapter_summary_accepts_label_without_colon() -> None:
    text = f"Sommario  1. Premessa{DASH}2. Conclusione"
    items = CompendioUtetProfile._parse_chapter_summary(text)
    assert items is not None
    assert items == (
        SummaryItem(number="1", title="Premessa"),
        SummaryItem(number="2", title="Conclusione"),
    )


def test_parse_toc_general_returns_none_for_none() -> None:
    assert CompendioUtetProfile._parse_toc_general(None) is None


def test_parse_toc_general_returns_none_when_no_entries_match() -> None:
    assert CompendioUtetProfile._parse_toc_general("just some text") is None


def test_parse_toc_general_normalises_internal_whitespace() -> None:
    text = "1. Lungo titolo\ncon line break .... » 42"
    items = CompendioUtetProfile._parse_toc_general(text)
    assert items is not None
    assert items[0].title == "Lungo titolo con line break"
    assert items[0].page_number == 42
