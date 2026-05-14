"""Unit tests for the manuale_utet_wolterskluwer corpus plugin (Mosconi-Campiglio)."""

from __future__ import annotations

import pytest

from scabopdf_pipeline.classification.types import ClassifiedBlock
from scabopdf_pipeline.extraction.types import Block, ExtractionResult, Span
from scabopdf_pipeline.profiles.manuale_utet_wolterskluwer import (
    BODY_FONT_SIZE,
    CHAPTER_HEADING_SIZE,
    EXAMPLE_BOX_MIN_TEXT_LENGTH,
    EXAMPLE_BOX_SIZE,
    LEFT_MARGIN_X_THRESHOLD,
    MARGINAL_HEADING_SIZE,
    NOTE_BODY_SIZE,
    NOTE_MARKER_SIZE,
    PARAGRAPH_HEADING_SIZE,
    RIGHT_MARGIN_X_THRESHOLD,
    WARNING_PREFIX,
    ManualeUtetWolterskluwerProfile,
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
from scabopdf_pipeline.reconstruction.types import Document, Node
from scabopdf_pipeline.schema.categories import SemanticCategory

BOLD_FLAG = 0x10
SUPERSCRIPT_FLAG = 0x01


# ---------------------------------------------------------------------------
# Helpers


def _mosconi_signals(
    *,
    body_size: float = BODY_FONT_SIZE,
    body_dominance: float = 33.0,
    footnote_markers: int = 965,
    marginal_headings: int = 593,
    italic_9pt_blocks: int = 420,
    producer: str = "Adobe PDF Library 10.0.1",
    creator: str = "Adobe InDesign CS6",
    has_outline: bool = False,
) -> ProfilingSignals:
    fonts = [
        FontDominance(family="TimesTenLTStd", size=body_size, dominance_percent=body_dominance),
    ]
    return ProfilingSignals(
        typographic_signature=TypographicSignature(fonts=fonts),
        apparatus_presence=ApparatusPresence(
            footnote_markers=footnote_markers,
            marginal_headings=marginal_headings,
            italic_9pt_blocks=italic_9pt_blocks,
        ),
        page_geometry=ProfilePageGeometry(width_pt=457.2, height_pt=684.0),
        producer_creator=ProducerCreator(producer=producer, creator=creator),
        outline_structure=OutlineStructure(has_outline=has_outline),
    )


class _SpanBuilder:
    """Build a list of Span objects with reasonable Mosconi defaults."""

    def __init__(self) -> None:
        self._spans: list[Span] = []

    def add(
        self,
        text: str,
        *,
        font: str = "TimesTenLTStd-Roman",
        size: float = BODY_FONT_SIZE,
        page: int = 0,
        flags: int = 4,
        color: int = 0,
        bbox: tuple[float, float, float, float] = (90.0, 120.0, 400.0, 130.0),
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
    bbox: tuple[float, float, float, float] = (90.0, 120.0, 400.0, 130.0),
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
    assert ManualeUtetWolterskluwerProfile.profile_id == "manuale_utet_wolterskluwer"
    assert ManualeUtetWolterskluwerProfile.editorial_family == "utet"
    assert ManualeUtetWolterskluwerProfile.genre == "manuale"


# ---------------------------------------------------------------------------
# matches()


def test_matches_full_mosconi_fingerprint_clears_threshold() -> None:
    """A complete Mosconi fingerprint scores at or near the maximum."""
    score = ManualeUtetWolterskluwerProfile.matches(_mosconi_signals())
    assert score == pytest.approx(1.00)
    assert score >= 0.6


def test_matches_score_on_tesauro_like_signals_stays_below_threshold() -> None:
    """A Tesauro-like document (body 10.2pt, zero apparatus) stays below 0.6.

    This is the symmetric discrimination axis to the Tesauro plugin's
    apparatus-presence penalty. The body is at 10.2pt (Tesauro size),
    not 10.0pt (Mosconi size), so the body bonus does not fire; and
    all apparatus counts are zero, so the apparatus bonuses do not
    fire and the no-apparatus penalty does.
    """
    signals = _mosconi_signals(
        body_size=10.2,
        footnote_markers=0,
        marginal_headings=0,
        italic_9pt_blocks=0,
    )
    score = ManualeUtetWolterskluwerProfile.matches(signals)
    assert score < 0.6


def test_matches_score_on_patriarca_like_signals_is_zero() -> None:
    """A Times New Roman document with zero apparatus scores at the floor."""
    fonts = [FontDominance(family="TimesNewRoman", size=11.0, dominance_percent=81.0)]
    signals = ProfilingSignals(
        typographic_signature=TypographicSignature(fonts=fonts),
        apparatus_presence=ApparatusPresence(),
        page_geometry=ProfilePageGeometry(width_pt=595.0, height_pt=842.0),
        producer_creator=ProducerCreator(producer="Acrobat Distiller", creator="Zanichelli"),
        outline_structure=OutlineStructure(has_outline=True, entries_count=20),
    )
    assert ManualeUtetWolterskluwerProfile.matches(signals) == 0.0


def test_matches_missing_body_signal_drops_below_threshold() -> None:
    """Without the TimesTenLTStd 10.0pt body signal the score does not clear 0.6."""
    fonts = [FontDominance(family="OtherFamily", size=10.0, dominance_percent=80.0)]
    signals = ProfilingSignals(
        typographic_signature=TypographicSignature(fonts=fonts),
        apparatus_presence=ApparatusPresence(
            footnote_markers=965,
            marginal_headings=593,
            italic_9pt_blocks=420,
        ),
        page_geometry=ProfilePageGeometry(width_pt=457.2, height_pt=684.0),
        producer_creator=ProducerCreator(producer=None, creator=None),
        outline_structure=OutlineStructure(has_outline=False),
    )
    score = ManualeUtetWolterskluwerProfile.matches(signals)
    # Apparatus (0.25 + 0.15 + 0.10) + no outline (0.05) = 0.55, below 0.6.
    assert score == pytest.approx(0.55)
    assert score < 0.6


def test_matches_only_footnotes_still_clears_threshold() -> None:
    """A Mosconi-like document with footnotes but no marginals or boxes still wins."""
    signals = _mosconi_signals(marginal_headings=0, italic_9pt_blocks=0)
    score = ManualeUtetWolterskluwerProfile.matches(signals)
    # 0.40 + 0.25 + 0 + 0 + 0.05 + 0.05 = 0.75
    assert score == pytest.approx(0.75)
    assert score >= 0.6


def test_matches_clamps_negative_score_to_zero() -> None:
    """The no-apparatus penalty cannot drag the score below zero."""
    fonts = [FontDominance(family="OtherFamily", size=15.0, dominance_percent=50.0)]
    signals = ProfilingSignals(
        typographic_signature=TypographicSignature(fonts=fonts),
        apparatus_presence=ApparatusPresence(),
        page_geometry=ProfilePageGeometry(width_pt=595.0, height_pt=842.0),
        producer_creator=ProducerCreator(producer=None, creator=None),
        outline_structure=OutlineStructure(has_outline=True),
    )
    assert ManualeUtetWolterskluwerProfile.matches(signals) == 0.0


def test_matches_below_apparatus_threshold_does_not_credit_signal() -> None:
    """Apparatus counts below the threshold (50) do not award the bonus."""
    signals = _mosconi_signals(
        footnote_markers=10,
        marginal_headings=10,
        italic_9pt_blocks=10,
    )
    score = ManualeUtetWolterskluwerProfile.matches(signals)
    # Body 0.40 + UTET 0.05 + no outline 0.05 = 0.50. Apparatus counts
    # are non-zero so the no-apparatus penalty is not applied.
    assert score == pytest.approx(0.50)


# ---------------------------------------------------------------------------
# Declarative methods


def test_get_categories_includes_apparatus_categories() -> None:
    plugin = ManualeUtetWolterskluwerProfile()
    categories = plugin.get_categories()
    expected_present = {
        SemanticCategory.HEADING_1,
        SemanticCategory.HEADING_2,
        SemanticCategory.HEADING_3,
        SemanticCategory.BODY,
        SemanticCategory.NOTE,
        SemanticCategory.MARGINAL_HEADING,
        SemanticCategory.EXAMPLE_BOX,
        SemanticCategory.CROSS_REFERENCE,
        SemanticCategory.ARTIFACT_STAMP,
    }
    assert expected_present.issubset(categories)


def test_get_categories_excludes_legal_code_specific_categories() -> None:
    """Mosconi is a treatise; categories specific to legal codes must not appear."""
    plugin = ManualeUtetWolterskluwerProfile()
    categories = plugin.get_categories()
    forbidden = {
        SemanticCategory.ARTICLE_HEADER,
        SemanticCategory.ARTICLE_BODY,
        SemanticCategory.MASSIMA_LABEL,
    }
    assert categories.isdisjoint(forbidden)


def test_get_post_processing_declares_both_steps() -> None:
    plugin = ManualeUtetWolterskluwerProfile()
    assert plugin.get_post_processing() == [
        "dehyphenate_with_log",
        "recompose_marginal_ellipsis",
    ]


def test_get_layouts_disabled_returns_empty() -> None:
    """Mosconi exercises every Layer 2 layout."""
    plugin = ManualeUtetWolterskluwerProfile()
    assert plugin.get_layouts_disabled() == []


def test_get_layouts_disabled_returns_list_of_disabled_layout_type() -> None:
    """The return type matches the ProfilePlugin contract."""
    plugin = ManualeUtetWolterskluwerProfile()
    assert isinstance(plugin.get_layouts_disabled(), list)
    for entry in plugin.get_layouts_disabled():
        assert isinstance(entry, DisabledLayout)


# ---------------------------------------------------------------------------
# refine_classification — sentinels & preservation


def test_refine_classification_preserves_sentinel_verdicts() -> None:
    plugin = ManualeUtetWolterskluwerProfile()
    extraction = _make_extraction([], [])
    sentinel = ClassifiedBlock(
        block_index=-1,
        category=SemanticCategory.EMPTY_PAGE,
        subcategory="5",
        reason="empty_page",
    )
    refined = plugin.refine_classification(extraction, [sentinel])
    assert refined == [sentinel]


def test_refine_classification_preserves_tier1_filigree_verdicts() -> None:
    """Tier 1 ARTIFACT_FILIGREE verdicts are not reclassified by the plugin."""
    spans = _SpanBuilder().add("watermark", size=BODY_FONT_SIZE).build()
    block = _make_block(page=0, span_range=(0, 1))
    extraction = _make_extraction(spans, [block])
    verdict = _verdict(0, category=SemanticCategory.ARTIFACT_FILIGREE, reason="filigree")
    plugin = ManualeUtetWolterskluwerProfile()
    refined = plugin.refine_classification(extraction, [verdict])
    assert refined[0].category is SemanticCategory.ARTIFACT_FILIGREE
    assert refined[0].reason == "filigree"


# ---------------------------------------------------------------------------
# refine_classification — chapter heading family


def test_refine_classification_promotes_chapter_number_block() -> None:
    """A 12pt block with text matching the Italian ordinal pattern becomes HEADING_2."""
    spans = _SpanBuilder().add("Capitolo Primo", size=CHAPTER_HEADING_SIZE, flags=4).build()
    block = _make_block(page=50, span_range=(0, 1))
    extraction = _make_extraction(spans, [block])
    refined = ManualeUtetWolterskluwerProfile().refine_classification(extraction, [_verdict(0)])
    assert refined[0].category is SemanticCategory.HEADING_2
    assert refined[0].reason == "utet_wolterskluwer_chapter_number"


def test_refine_classification_promotes_chapter_title_after_chapter_number() -> None:
    """A 12pt block following a chapter number becomes HEADING_2 chapter title."""
    spans = (
        _SpanBuilder()
        .add("Capitolo Primo", size=CHAPTER_HEADING_SIZE, flags=4)
        .add(
            "NOZIONE E OGGETTO DEL DIRITTO INTERNAZIONALE",
            size=CHAPTER_HEADING_SIZE,
            flags=4,
        )
        .build()
    )
    block_a = _make_block(page=50, span_range=(0, 1), block_index=0)
    block_b = _make_block(page=50, span_range=(1, 2), block_index=1)
    extraction = _make_extraction(spans, [block_a, block_b])
    refined = ManualeUtetWolterskluwerProfile().refine_classification(
        extraction, [_verdict(0), _verdict(1)]
    )
    assert refined[0].reason == "utet_wolterskluwer_chapter_number"
    assert refined[1].category is SemanticCategory.HEADING_2
    assert refined[1].reason == "utet_wolterskluwer_chapter_title"


def test_refine_classification_chapter_title_after_stamp_still_promoted() -> None:
    """An ARTIFACT_STAMP between number and title does not break pair detection."""
    spans = (
        _SpanBuilder()
        .add("Capitolo Primo", size=CHAPTER_HEADING_SIZE)
        .add("265955_Primepagina.indb", size=9.0)
        .add("NOZIONE E OGGETTO", size=CHAPTER_HEADING_SIZE)
        .build()
    )
    blocks = [
        _make_block(page=4, span_range=(0, 1), block_index=0),
        _make_block(page=4, span_range=(1, 2), block_index=1),
        _make_block(page=4, span_range=(2, 3), block_index=2),
    ]
    extraction = _make_extraction(spans, blocks)
    refined = ManualeUtetWolterskluwerProfile().refine_classification(
        extraction, [_verdict(0), _verdict(1), _verdict(2)]
    )
    assert refined[0].reason == "utet_wolterskluwer_chapter_number"
    assert refined[1].category is SemanticCategory.ARTIFACT_STAMP
    assert refined[2].reason == "utet_wolterskluwer_chapter_title"


def test_refine_classification_classifies_front_matter_heading_as_h1() -> None:
    """A 12pt block not matching the chapter pattern becomes HEADING_1 (front matter)."""
    spans = _SpanBuilder().add("ABBREVIAZIONI", size=CHAPTER_HEADING_SIZE).build()
    block = _make_block(page=3, span_range=(0, 1))
    extraction = _make_extraction(spans, [block])
    refined = ManualeUtetWolterskluwerProfile().refine_classification(extraction, [_verdict(0)])
    assert refined[0].category is SemanticCategory.HEADING_1
    assert refined[0].reason == "utet_wolterskluwer_front_matter_heading"


# ---------------------------------------------------------------------------
# refine_classification — paragraph heading


def test_refine_classification_promotes_paragraph_heading_h3() -> None:
    """A 10.5pt composite (number + bold title) becomes HEADING_3."""
    spans = (
        _SpanBuilder()
        .add(
            "1. ",
            font="TimesTenLTStd-Roman",
            size=PARAGRAPH_HEADING_SIZE,
            flags=4,
        )
        .add(
            "Premessa",
            font="TimesTenLTStd-Bold",
            size=PARAGRAPH_HEADING_SIZE,
            flags=BOLD_FLAG,
        )
        .build()
    )
    block = _make_block(page=53, span_range=(0, 2))
    extraction = _make_extraction(spans, [block])
    refined = ManualeUtetWolterskluwerProfile().refine_classification(extraction, [_verdict(0)])
    assert refined[0].category is SemanticCategory.HEADING_3
    assert refined[0].reason == "utet_wolterskluwer_paragraph_heading"


def test_refine_classification_paragraph_heading_requires_bold_title() -> None:
    """A 10.5pt number span without a bold title span does not become HEADING_3."""
    spans = (
        _SpanBuilder()
        .add("1. ", font="TimesTenLTStd-Roman", size=PARAGRAPH_HEADING_SIZE)
        .add("Premessa", font="TimesTenLTStd-Roman", size=PARAGRAPH_HEADING_SIZE)  # not bold
        .build()
    )
    block = _make_block(page=53, span_range=(0, 2))
    extraction = _make_extraction(spans, [block])
    refined = ManualeUtetWolterskluwerProfile().refine_classification(extraction, [_verdict(0)])
    assert refined[0].category is not SemanticCategory.HEADING_3


# ---------------------------------------------------------------------------
# refine_classification — body


def test_refine_classification_promotes_body_block() -> None:
    """A 10.0pt TimesTenLTStd-Roman block becomes BODY."""
    spans = _SpanBuilder().add("Body prose continues for a while.", size=BODY_FONT_SIZE).build()
    block = _make_block(page=55, span_range=(0, 1))
    extraction = _make_extraction(spans, [block])
    refined = ManualeUtetWolterskluwerProfile().refine_classification(extraction, [_verdict(0)])
    assert refined[0].category is SemanticCategory.BODY
    assert refined[0].reason == "utet_wolterskluwer_body"


def test_refine_classification_promotes_body_italic_block() -> None:
    """A 10.0pt TimesTenLTStd-Italic block also becomes BODY (variant)."""
    spans = (
        _SpanBuilder()
        .add(
            "lex fori",
            font="TimesTenLTStd-Italic",
            size=BODY_FONT_SIZE,
            flags=4 | 0x02,
        )
        .build()
    )
    block = _make_block(page=55, span_range=(0, 1))
    extraction = _make_extraction(spans, [block])
    refined = ManualeUtetWolterskluwerProfile().refine_classification(extraction, [_verdict(0)])
    assert refined[0].category is SemanticCategory.BODY


# ---------------------------------------------------------------------------
# refine_classification — marginal heading


def test_refine_classification_promotes_left_marginal_heading() -> None:
    """A 7.0pt block on the left margin (x < threshold) becomes MARGINAL_HEADING."""
    spans = _SpanBuilder().add("Marginale di sinistra", size=MARGINAL_HEADING_SIZE).build()
    block = _make_block(
        page=55,
        span_range=(0, 1),
        bbox=(40.0, 200.0, 75.0, 220.0),  # x0 < 80
    )
    extraction = _make_extraction(spans, [block])
    refined = ManualeUtetWolterskluwerProfile().refine_classification(extraction, [_verdict(0)])
    assert refined[0].category is SemanticCategory.MARGINAL_HEADING
    assert refined[0].reason == "utet_wolterskluwer_marginal_heading"


def test_refine_classification_promotes_right_marginal_heading() -> None:
    """A 7.0pt block on the right margin (x > threshold) becomes MARGINAL_HEADING."""
    spans = _SpanBuilder().add("Marginale di destra", size=MARGINAL_HEADING_SIZE).build()
    block = _make_block(
        page=55,
        span_range=(0, 1),
        bbox=(400.0, 200.0, 440.0, 220.0),  # x0 > 370
    )
    extraction = _make_extraction(spans, [block])
    refined = ManualeUtetWolterskluwerProfile().refine_classification(extraction, [_verdict(0)])
    assert refined[0].category is SemanticCategory.MARGINAL_HEADING


def test_refine_classification_does_not_promote_centered_7pt_block() -> None:
    """A 7.0pt block in the body column (x between thresholds) is not a marginal."""
    spans = _SpanBuilder().add("piccolo testo nel corpo", size=MARGINAL_HEADING_SIZE).build()
    block = _make_block(
        page=55,
        span_range=(0, 1),
        bbox=(150.0, 200.0, 250.0, 220.0),  # x0 well inside body
    )
    extraction = _make_extraction(spans, [block])
    refined = ManualeUtetWolterskluwerProfile().refine_classification(extraction, [_verdict(0)])
    assert refined[0].category is not SemanticCategory.MARGINAL_HEADING


def test_left_and_right_margin_thresholds_have_a_gap() -> None:
    """Sanity: the two margin thresholds do not overlap (body column is non-empty)."""
    assert LEFT_MARGIN_X_THRESHOLD < RIGHT_MARGIN_X_THRESHOLD


# ---------------------------------------------------------------------------
# refine_classification — example box


def test_refine_classification_promotes_example_box() -> None:
    """An italic-9.0pt block with body length >= 100 becomes EXAMPLE_BOX."""
    long_text = "Approfondimento: " + "a" * (EXAMPLE_BOX_MIN_TEXT_LENGTH + 5)
    spans = (
        _SpanBuilder()
        .add(
            long_text,
            font="TimesTenLTStd-Italic",
            size=EXAMPLE_BOX_SIZE,
            flags=4 | 0x02,
        )
        .build()
    )
    block = _make_block(page=80, span_range=(0, 1))
    extraction = _make_extraction(spans, [block])
    refined = ManualeUtetWolterskluwerProfile().refine_classification(extraction, [_verdict(0)])
    assert refined[0].category is SemanticCategory.EXAMPLE_BOX
    assert refined[0].reason == "utet_wolterskluwer_example_box"


def test_refine_classification_rejects_short_italic_9pt_block() -> None:
    """An italic-9.0pt block shorter than the minimum is not an EXAMPLE_BOX."""
    spans = (
        _SpanBuilder()
        .add("Breve italico", font="TimesTenLTStd-Italic", size=EXAMPLE_BOX_SIZE, flags=0x02)
        .build()
    )
    block = _make_block(page=80, span_range=(0, 1))
    extraction = _make_extraction(spans, [block])
    refined = ManualeUtetWolterskluwerProfile().refine_classification(extraction, [_verdict(0)])
    assert refined[0].category is SemanticCategory.UNCLASSIFIED


def test_refine_classification_filters_front_matter_index_residue() -> None:
    """An italic-9.0pt block opening with an index keyword is filtered and warned."""
    text = "Sezione I — Il regolamento in materia civile " * 5
    spans = (
        _SpanBuilder()
        .add(text, font="TimesTenLTStd-Italic", size=EXAMPLE_BOX_SIZE, flags=0x02)
        .build()
    )
    block = _make_block(page=10, span_range=(0, 1))
    extraction = _make_extraction(spans, [block])
    plugin = ManualeUtetWolterskluwerProfile()
    refined = plugin.refine_classification(extraction, [_verdict(0)])
    assert refined[0].category is not SemanticCategory.EXAMPLE_BOX
    assert any(
        w.startswith(f"{WARNING_PREFIX}:example_box_in_front_matter_filtered")
        for w in plugin._pending_warnings
    )


# ---------------------------------------------------------------------------
# refine_classification — note


def test_refine_classification_promotes_note_block() -> None:
    """A block opening with a 4.7pt number span + 8.0pt body becomes NOTE."""
    spans = (
        _SpanBuilder()
        .add("12. ", font="TimesTenLTStd-Roman", size=NOTE_MARKER_SIZE)
        .add(
            "Corpo della nota a piè di pagina con riferimenti.",
            font="TimesTenLTStd-Roman",
            size=NOTE_BODY_SIZE,
        )
        .build()
    )
    block = _make_block(page=55, span_range=(0, 2))
    extraction = _make_extraction(spans, [block])
    refined = ManualeUtetWolterskluwerProfile().refine_classification(extraction, [_verdict(0)])
    assert refined[0].category is SemanticCategory.NOTE
    assert refined[0].reason == "utet_wolterskluwer_note"


def test_refine_classification_promotes_note_continuation_block() -> None:
    """A pure 8.0pt block without a numeric marker becomes NOTE (continuation)."""
    spans = (
        _SpanBuilder()
        .add(
            "Continuazione della nota precedente sulla stessa pagina.",
            font="TimesTenLTStd-Roman",
            size=NOTE_BODY_SIZE,
        )
        .build()
    )
    block = _make_block(page=55, span_range=(0, 1))
    extraction = _make_extraction(spans, [block])
    refined = ManualeUtetWolterskluwerProfile().refine_classification(extraction, [_verdict(0)])
    assert refined[0].category is SemanticCategory.NOTE
    assert refined[0].reason == "utet_wolterskluwer_note_continuation"


# ---------------------------------------------------------------------------
# refine_classification — artifact stamp


def test_refine_classification_promotes_stamp_filename_block() -> None:
    """A block whose text matches the InDesign filename pattern becomes ARTIFACT_STAMP."""
    spans = _SpanBuilder().add("265955_Primepagina.indb", size=9.0).build()
    block = _make_block(page=0, span_range=(0, 1))
    extraction = _make_extraction(spans, [block])
    refined = ManualeUtetWolterskluwerProfile().refine_classification(extraction, [_verdict(0)])
    assert refined[0].category is SemanticCategory.ARTIFACT_STAMP


def test_refine_classification_promotes_stamp_datetime_block() -> None:
    """A block whose text matches the date/time pattern becomes ARTIFACT_STAMP."""
    spans = _SpanBuilder().add("13/06/24 3:39 PM", size=9.0).build()
    block = _make_block(page=0, span_range=(0, 1))
    extraction = _make_extraction(spans, [block])
    refined = ManualeUtetWolterskluwerProfile().refine_classification(extraction, [_verdict(0)])
    assert refined[0].category is SemanticCategory.ARTIFACT_STAMP


def test_refine_classification_rescues_stamp_absorbed_into_footer() -> None:
    """A FOOTER verdict whose text is a stamp is promoted to ARTIFACT_STAMP."""
    spans = _SpanBuilder().add("265955_Terza_Bozza.indb", size=8.0).build()
    block = _make_block(page=4, span_range=(0, 1))
    extraction = _make_extraction(spans, [block])
    verdict = _verdict(0, category=SemanticCategory.ARTIFACT_FOOTER, reason="footer")
    refined = ManualeUtetWolterskluwerProfile().refine_classification(extraction, [verdict])
    assert refined[0].category is SemanticCategory.ARTIFACT_STAMP
    assert refined[0].reason == "utet_wolterskluwer_stamp_from_footer"


def test_refine_classification_preserves_non_stamp_footer() -> None:
    """A FOOTER verdict whose text is not a stamp stays ARTIFACT_FOOTER."""
    spans = _SpanBuilder().add("© Wolters Kluwer Italia", size=8.0).build()
    block = _make_block(page=55, span_range=(0, 1))
    extraction = _make_extraction(spans, [block])
    verdict = _verdict(0, category=SemanticCategory.ARTIFACT_FOOTER, reason="footer")
    refined = ManualeUtetWolterskluwerProfile().refine_classification(extraction, [verdict])
    assert refined[0].category is SemanticCategory.ARTIFACT_FOOTER


# ---------------------------------------------------------------------------
# refine_classification — unknown signature


def test_refine_classification_leaves_unknown_signature_unclassified() -> None:
    """A block whose signature does not match any branch stays UNCLASSIFIED."""
    spans = _SpanBuilder().add("Verdana text", font="Verdana", size=11.0).build()
    block = _make_block(page=0, span_range=(0, 1))
    extraction = _make_extraction(spans, [block])
    refined = ManualeUtetWolterskluwerProfile().refine_classification(extraction, [_verdict(0)])
    assert refined[0].category is SemanticCategory.UNCLASSIFIED


# ---------------------------------------------------------------------------
# refine_reconstruction — chapter fusion


def _node(
    node_id: str,
    category: SemanticCategory,
    text: str,
    *,
    page_index: int = 50,
    block_indices: tuple[int, ...] = (0,),
    children: tuple[Node, ...] = (),
    level: int | None = None,
) -> Node:
    return Node(
        id=node_id,
        category=category,
        page_index=page_index,
        block_indices=block_indices,
        text=text,
        level=level,
        children=children,
    )


def test_refine_reconstruction_fuses_chapter_pair() -> None:
    """A registered chapter number + title pair fuses into one HEADING_2 node."""
    plugin = ManualeUtetWolterskluwerProfile()
    plugin._chapter_number_blocks = {0}
    plugin._chapter_title_blocks = {1}
    number_node = _node(
        "node_0001", SemanticCategory.HEADING_2, "Capitolo Primo", block_indices=(0,)
    )
    title_node = _node(
        "node_0002",
        SemanticCategory.HEADING_2,
        "NOZIONE E OGGETTO",
        block_indices=(1,),
    )
    document = Document(root=(number_node, title_node))
    extraction = _make_extraction([], [])
    result = plugin.refine_reconstruction(document, extraction, [])
    assert len(result.root) == 1
    fused = result.root[0]
    assert fused.id == "node_0001"
    assert fused.text == "Capitolo Primo. NOZIONE E OGGETTO"
    assert fused.block_indices == (0, 1)
    assert fused.level == 2


def test_refine_reconstruction_chapter_title_not_adjacent_emits_warning() -> None:
    """A chapter number whose title node is missing emits the diagnostic warning."""
    plugin = ManualeUtetWolterskluwerProfile()
    plugin._chapter_number_blocks = {0}
    plugin._chapter_title_blocks = set()  # title not registered
    number_node = _node(
        "node_0001", SemanticCategory.HEADING_2, "Capitolo Primo", block_indices=(0,)
    )
    other_node = _node(
        "node_0002", SemanticCategory.BODY, "Body that is not a title.", block_indices=(1,)
    )
    document = Document(root=(number_node, other_node))
    extraction = _make_extraction([], [])
    result = plugin.refine_reconstruction(document, extraction, [])
    assert any(
        w.startswith(f"{WARNING_PREFIX}:chapter_title_not_adjacent") for w in result.warnings
    )


# ---------------------------------------------------------------------------
# refine_reconstruction — inline cross-reference minting


def test_refine_reconstruction_mints_cross_reference_node_for_inline_superscript() -> None:
    """A BODY block with an inline superscript-digit span yields a synthetic CROSS_REFERENCE."""
    spans = (
        _SpanBuilder()
        .add("Prima della nota ", size=BODY_FONT_SIZE)
        .add("5", font="TimesTenLTStd-Roman", size=5.8, flags=4 | SUPERSCRIPT_FLAG)
        .add(", dopo la nota.", size=BODY_FONT_SIZE)
        .build()
    )
    block = _make_block(page=55, span_range=(0, 3), block_index=0)
    extraction = _make_extraction(spans, [block])
    body_node = _node(
        "node_0001",
        SemanticCategory.BODY,
        "Prima della nota 5, dopo la nota.",
        block_indices=(0,),
    )
    document = Document(root=(body_node,))
    plugin = ManualeUtetWolterskluwerProfile()
    result = plugin.refine_reconstruction(document, extraction, [])
    assert len(result.root) == 2
    assert result.root[0].id == "node_0001"
    assert result.root[0].category is SemanticCategory.BODY
    assert result.root[1].category is SemanticCategory.CROSS_REFERENCE
    assert result.root[1].text == "5"
    assert result.root[1].block_indices == (0,)


def test_refine_reconstruction_ignores_non_digit_superscript_spans() -> None:
    """A superscript span whose text is not a pure digit does not produce a CROSS_REFERENCE."""
    spans = (
        _SpanBuilder()
        .add("Testo ", size=BODY_FONT_SIZE)
        .add("a", size=5.8, flags=4 | SUPERSCRIPT_FLAG)
        .build()
    )
    block = _make_block(page=55, span_range=(0, 2), block_index=0)
    extraction = _make_extraction(spans, [block])
    body_node = _node(
        "node_0001",
        SemanticCategory.BODY,
        "Testo a",
        block_indices=(0,),
    )
    document = Document(root=(body_node,))
    plugin = ManualeUtetWolterskluwerProfile()
    result = plugin.refine_reconstruction(document, extraction, [])
    crossref_count = sum(1 for n in result.root if n.category is SemanticCategory.CROSS_REFERENCE)
    assert crossref_count == 0


# ---------------------------------------------------------------------------
# refine_reconstruction — note consolidation


def test_refine_reconstruction_consolidates_note_continuation() -> None:
    """Adjacent NOTE siblings on the same page where the second is unmarked are fused."""
    note_a = _node(
        "node_0001",
        SemanticCategory.NOTE,
        "5. Prima parte della nota,",
        page_index=55,
        block_indices=(10,),
    )
    note_b = _node(
        "node_0002",
        SemanticCategory.NOTE,
        "che continua sulla riga successiva.",
        page_index=55,
        block_indices=(11,),
    )
    document = Document(root=(note_a, note_b))
    extraction = _make_extraction([], [])
    plugin = ManualeUtetWolterskluwerProfile()
    result = plugin.refine_reconstruction(document, extraction, [])
    assert len(result.root) == 1
    merged = result.root[0]
    assert merged.id == "node_0001"
    assert merged.text == "5. Prima parte della nota, che continua sulla riga successiva."
    assert merged.block_indices == (10, 11)


def test_refine_reconstruction_does_not_consolidate_distinct_marked_notes() -> None:
    """Adjacent NOTE siblings on the same page both opening with markers stay separate."""
    note_a = _node(
        "node_0001",
        SemanticCategory.NOTE,
        "5. Nota cinque.",
        page_index=55,
        block_indices=(10,),
    )
    note_b = _node(
        "node_0002",
        SemanticCategory.NOTE,
        "6. Nota sei.",
        page_index=55,
        block_indices=(11,),
    )
    document = Document(root=(note_a, note_b))
    extraction = _make_extraction([], [])
    plugin = ManualeUtetWolterskluwerProfile()
    result = plugin.refine_reconstruction(document, extraction, [])
    assert len(result.root) == 2


def test_refine_reconstruction_does_not_consolidate_notes_across_pages() -> None:
    """Adjacent NOTE siblings on different pages are NOT consolidated by the plugin."""
    note_a = _node(
        "node_0001",
        SemanticCategory.NOTE,
        "5. Prima parte,",
        page_index=55,
        block_indices=(10,),
    )
    note_b = _node(
        "node_0002",
        SemanticCategory.NOTE,
        "continuazione sulla pagina dopo.",
        page_index=56,
        block_indices=(11,),
    )
    document = Document(root=(note_a, note_b))
    extraction = _make_extraction([], [])
    plugin = ManualeUtetWolterskluwerProfile()
    result = plugin.refine_reconstruction(document, extraction, [])
    assert len(result.root) == 2


# ---------------------------------------------------------------------------
# refine_reconstruction — marginal orphan warning


def test_refine_reconstruction_emits_marginal_orphan_warning() -> None:
    """A MARGINAL_HEADING ending in '...' with no chain successor emits an orphan warning."""
    orphan = _node(
        "node_0001",
        SemanticCategory.MARGINAL_HEADING,
        "Trailing dots without continuation...",
        page_index=55,
    )
    body = _node("node_0002", SemanticCategory.BODY, "Body that follows.", page_index=55)
    document = Document(root=(orphan, body))
    extraction = _make_extraction([], [])
    plugin = ManualeUtetWolterskluwerProfile()
    result = plugin.refine_reconstruction(document, extraction, [])
    assert any(
        w.startswith(f"{WARNING_PREFIX}:marginal_ellipsis_orphan_marker") for w in result.warnings
    )


def test_refine_reconstruction_does_not_warn_on_valid_marginal_chain() -> None:
    """A valid MARGINAL_HEADING chain (head ends '...', tail starts '...') is silent."""
    head = _node("node_0001", SemanticCategory.MARGINAL_HEADING, "Foo bar...", page_index=55)
    tail = _node("node_0002", SemanticCategory.MARGINAL_HEADING, "...baz qux", page_index=56)
    document = Document(root=(head, tail))
    extraction = _make_extraction([], [])
    plugin = ManualeUtetWolterskluwerProfile()
    result = plugin.refine_reconstruction(document, extraction, [])
    assert not any(
        w.startswith(f"{WARNING_PREFIX}:marginal_ellipsis_orphan_marker") for w in result.warnings
    )


# ---------------------------------------------------------------------------
# refine_reconstruction — warning flushing & state


def test_refine_reconstruction_flushes_pending_warnings_to_document() -> None:
    """Warnings accumulated during refine_classification flush into Document.warnings."""
    plugin = ManualeUtetWolterskluwerProfile()
    plugin._pending_warnings = [f"{WARNING_PREFIX}:test_warning_foo"]
    document = Document()
    extraction = _make_extraction([], [])
    result = plugin.refine_reconstruction(document, extraction, [])
    assert f"{WARNING_PREFIX}:test_warning_foo" in result.warnings


def test_refine_reconstruction_clears_pending_warnings_after_flush() -> None:
    """The pending warnings list is drained after refine_reconstruction returns."""
    plugin = ManualeUtetWolterskluwerProfile()
    plugin._pending_warnings = [f"{WARNING_PREFIX}:test_warning_foo"]
    document = Document()
    extraction = _make_extraction([], [])
    plugin.refine_reconstruction(document, extraction, [])
    assert plugin._pending_warnings == []


def test_refine_classification_resets_instance_state_between_runs() -> None:
    """A second call to refine_classification starts from a clean slate."""
    plugin = ManualeUtetWolterskluwerProfile()
    plugin._pending_warnings = ["stale_warning"]
    plugin._chapter_number_blocks = {99}
    plugin._chapter_title_blocks = {100}
    extraction = _make_extraction([], [])
    plugin.refine_classification(extraction, [])
    assert plugin._pending_warnings == []
    assert plugin._chapter_number_blocks == set()
    assert plugin._chapter_title_blocks == set()


# ---------------------------------------------------------------------------
# refine_apparatus


def test_refine_apparatus_is_passthrough() -> None:
    """The plugin returns the document unchanged from refine_apparatus."""
    document = Document(root=(_node("node_0001", SemanticCategory.BODY, "body"),))
    extraction = _make_extraction([], [])
    plugin = ManualeUtetWolterskluwerProfile()
    result = plugin.refine_apparatus(document, extraction, [])
    assert result is document
