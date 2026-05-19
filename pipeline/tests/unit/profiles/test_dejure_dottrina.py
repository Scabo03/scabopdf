"""Unit tests for the dejure_dottrina corpus plugin."""

from __future__ import annotations

import pytest

from scabopdf_pipeline.apparatus.types import ApparatusRefKind
from scabopdf_pipeline.classification.types import ClassifiedBlock
from scabopdf_pipeline.extraction.types import Block, ExtractionResult, Span
from scabopdf_pipeline.profiles.dejure_dottrina import (
    _CROSSREF_INLINE_PATTERN,
    _CROSSREF_MAX_MARKER_VALUE,
    _EDITORIAL_NOTE_PREFIX_PATTERN,
    _FOOTER_PATTERN,
    _NODE_ID_PATTERN,
    _NOTE_MARKER_PATTERN,
    _NOTE_SPLIT_PATTERN,
    _SECTION_HEADING_STYLE_A_PATTERN,
    _SOMMARIO_TRIM_PATTERN,
    _SUBSECTION_HEADING_PATTERN,
    BANNER_SIZE,
    BODY_SIZE,
    CONFIDENCE_ARIAL_BODY_DOMINANT,
    CONFIDENCE_ASPOSE_PRODUCER,
    CONFIDENCE_BANNER_BOLD_PRESENT,
    CONFIDENCE_LETTER_GEOMETRY,
    CONFIDENCE_NS_BANNER_PRESENT_PENALTY,
    CONFIDENCE_TITLE_BOLD_ABSENT_PENALTY,
    CONFIDENCE_TITLE_BOLD_PRESENT,
    COPYRIGHT_SIZE,
    SPECIFIC_MARKER_BANNER_TEXT_NAME,
    TITLE_SIZE,
    WARNING_PREFIX,
    WARNING_TEMPLATES,
    DejureDottrinaProfile,
    _BlockView,
    _iter_nodes,
    _max_existing_node_counter,
    _NodeIdMinter,
)
from scabopdf_pipeline.profiling.signals import (
    ApparatusPresence,
    FontDominance,
    OutlineStructure,
    ProducerCreator,
    ProfilePageGeometry,
    ProfilingSignals,
    SpecificMarker,
    TypographicSignature,
)
from scabopdf_pipeline.reconstruction.types import Document, Node
from scabopdf_pipeline.schema.categories import SemanticCategory

BOLD_FLAG = 0x10
ITALIC_FLAG = 0x02


# ---------------------------------------------------------------------------
# Helpers


def _dottrina_signals(
    *,
    body_family: str = "ArialMT",
    body_size: float = BODY_SIZE,
    body_dominance: float = 70.0,
    include_title_bold: bool = True,
    include_banner_bold: bool = True,
    producer: str = "Aspose.PDF for .NET 18.4",
    creator: str = "Aspose.PDF for .NET 18.4",
    width_pt: float = 612.0,
    height_pt: float = 792.0,
    marginal_headings: int = 0,
    banner_marker_value: object | None = "DOTTRINA",
    include_banner_marker: bool = False,
) -> ProfilingSignals:
    fonts = [
        FontDominance(family=body_family, size=body_size, dominance_percent=body_dominance),
    ]
    if include_title_bold:
        fonts.append(FontDominance(family="Arial-BoldMT", size=TITLE_SIZE, dominance_percent=0.5))
    if include_banner_bold:
        fonts.append(FontDominance(family="Arial-BoldMT", size=BANNER_SIZE, dominance_percent=1.0))
    markers: list[SpecificMarker] = []
    if include_banner_marker:
        markers.append(
            SpecificMarker(
                name=SPECIFIC_MARKER_BANNER_TEXT_NAME,
                present=banner_marker_value is not None,
                value=banner_marker_value,
            )
        )
    return ProfilingSignals(
        typographic_signature=TypographicSignature(fonts=fonts),
        apparatus_presence=ApparatusPresence(marginal_headings=marginal_headings),
        page_geometry=ProfilePageGeometry(width_pt=width_pt, height_pt=height_pt),
        producer_creator=ProducerCreator(producer=producer, creator=creator),
        outline_structure=OutlineStructure(),
        specific_markers=markers,
    )


def _make_span(
    text: str,
    *,
    font: str = "ArialMT",
    size: float = BODY_SIZE,
    flags: int = 0,
    page: int = 0,
    bbox: tuple[float, float, float, float] = (70.0, 300.0, 550.0, 320.0),
    block_index: int = 0,
    line_index: int = 0,
    span_index: int = 0,
    color: int = 0,
) -> Span:
    return Span(
        text=text,
        font=font,
        size=size,
        flags=flags,
        color=color,
        bbox=bbox,
        page=page,
        block_index=block_index,
        line_index=line_index,
        span_index=span_index,
    )


def _make_block(
    page: int = 0,
    bbox: tuple[float, float, float, float] = (70.0, 200.0, 550.0, 600.0),
    span_range: tuple[int, int] = (0, 1),
    block_index: int = 0,
) -> Block:
    return Block(page=page, block_index=block_index, bbox=bbox, span_range=span_range)


def _make_view(
    spans: list[Span],
    *,
    page: int = 0,
    bbox: tuple[float, float, float, float] = (70.0, 200.0, 550.0, 600.0),
    block_index: int = 0,
) -> _BlockView:
    block = _make_block(page=page, bbox=bbox, span_range=(0, len(spans)), block_index=block_index)
    text = "".join(s.text for s in spans)
    return _BlockView(block_index=block_index, block=block, spans=tuple(spans), text=text)


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
    reason: str = "tier1_default",
) -> ClassifiedBlock:
    return ClassifiedBlock(block_index=block_index, category=category, reason=reason)


# ---------------------------------------------------------------------------
# Section 1: Profile identity


def test_profile_identity() -> None:
    plugin = DejureDottrinaProfile()
    assert plugin.profile_id == "dejure_dottrina"
    assert plugin.editorial_family == "dejure"
    assert plugin.genre == "dottrina"


def test_profile_identity_classvars() -> None:
    """Class-level attributes mirror the instance values."""
    assert DejureDottrinaProfile.profile_id == "dejure_dottrina"
    assert DejureDottrinaProfile.editorial_family == "dejure"
    assert DejureDottrinaProfile.genre == "dottrina"


def test_plugin_registered_in_builtins() -> None:
    from scabopdf_pipeline.profiles import BUILTIN_PLUGINS

    assert DejureDottrinaProfile in BUILTIN_PLUGINS


# ---------------------------------------------------------------------------
# Section 2: declarative methods


def test_get_categories_covers_dottrina_specific_set() -> None:
    cats = DejureDottrinaProfile().get_categories()
    expected = {
        SemanticCategory.GENRE_BANNER,
        SemanticCategory.TITLE,
        SemanticCategory.META_VALUE,
        SemanticCategory.FONTE_VALUE,
        SemanticCategory.AUTHORS,
        SemanticCategory.TOC_GENERAL,
        SemanticCategory.HEADING_1,
        SemanticCategory.HEADING_2,
        SemanticCategory.SECTION_LABEL,
        SemanticCategory.NOTE,
        SemanticCategory.EDITORIAL_NOTE,
        SemanticCategory.CROSS_REFERENCE,
        SemanticCategory.BODY,
    }
    assert expected <= cats


def test_get_categories_includes_artifact_carriers() -> None:
    cats = DejureDottrinaProfile().get_categories()
    assert SemanticCategory.ARTIFACT_FOOTER in cats
    assert SemanticCategory.ARTIFACT_PAGE_HEADER in cats
    assert SemanticCategory.ARTIFACT_RUNNING_HEADER in cats
    assert SemanticCategory.ARTIFACT_STAMP in cats


def test_get_categories_includes_empty_and_unclassified() -> None:
    cats = DejureDottrinaProfile().get_categories()
    assert SemanticCategory.UNCLASSIFIED in cats
    assert SemanticCategory.EMPTY_PAGE in cats


def test_get_categories_excludes_ns_referral() -> None:
    """DT has no 'Nota a:' field, hence no REFERRAL category."""
    cats = DejureDottrinaProfile().get_categories()
    assert SemanticCategory.REFERRAL not in cats


def test_get_categories_excludes_mm_specific() -> None:
    """MM-specific categories never appear in DT."""
    cats = DejureDottrinaProfile().get_categories()
    assert SemanticCategory.MASSIMA_LABEL not in cats
    assert SemanticCategory.FONTE_LABEL not in cats


def test_get_post_processing_only_dehyphenate() -> None:
    assert DejureDottrinaProfile().get_post_processing() == ["dehyphenate_with_log"]


def test_get_layouts_disabled_is_empty() -> None:
    assert DejureDottrinaProfile().get_layouts_disabled() == []


def test_get_categories_returns_set() -> None:
    """The contract is a set, not a list."""
    cats = DejureDottrinaProfile().get_categories()
    assert isinstance(cats, set)


# ---------------------------------------------------------------------------
# Section 3: matches()


def test_matches_clears_threshold_on_default_signals() -> None:
    score = DejureDottrinaProfile.matches(_dottrina_signals())
    assert score >= 0.6


def test_matches_default_signals_returns_0_80() -> None:
    """Empirical baseline 0.80 on the calibrated three DT fixtures."""
    score = DejureDottrinaProfile.matches(_dottrina_signals())
    assert score == pytest.approx(0.80)


def test_matches_clears_on_explicit_dottrina_banner_marker() -> None:
    signals = _dottrina_signals(include_banner_marker=True, banner_marker_value="DOTTRINA")
    score = DejureDottrinaProfile.matches(signals)
    assert score >= 0.6


def test_matches_drops_below_threshold_on_ns_banner_marker() -> None:
    """NS-style banner penalty drops the score below 0.6."""
    signals = _dottrina_signals(include_banner_marker=True, banner_marker_value="NOTE E DOTTRINA")
    score = DejureDottrinaProfile.matches(signals)
    assert score < 0.6


def test_matches_drops_below_threshold_when_title_bold_absent() -> None:
    """MM case: 13pt bold absent triggers the -0.20 penalty."""
    signals = _dottrina_signals(include_title_bold=False)
    score = DejureDottrinaProfile.matches(signals)
    assert score < 0.6
    assert score == pytest.approx(0.50)


def test_matches_clears_when_full_signals_no_marker() -> None:
    """Without a banner marker, the full positive score is preserved."""
    signals = _dottrina_signals(include_banner_marker=False)
    score = DejureDottrinaProfile.matches(signals)
    assert score == pytest.approx(0.80)


def test_matches_below_threshold_on_non_arial_body() -> None:
    signals = _dottrina_signals(
        body_family="OpenSans-Regular",
        include_title_bold=False,
        include_banner_bold=False,
    )
    score = DejureDottrinaProfile.matches(signals)
    assert score < 0.6


def test_matches_zero_on_a4_geometry_non_arial() -> None:
    signals = _dottrina_signals(
        body_family="OpenSans-Regular",
        width_pt=595.0,
        height_pt=842.0,
        producer="Skia/PDF",
        creator="Skia/PDF",
        include_title_bold=False,
        include_banner_bold=False,
    )
    score = DejureDottrinaProfile.matches(signals)
    assert score == 0.0


def test_matches_credits_letter_geometry() -> None:
    letter = _dottrina_signals()
    a4 = _dottrina_signals(width_pt=595.0, height_pt=842.0)
    assert DejureDottrinaProfile.matches(letter) > DejureDottrinaProfile.matches(a4)


def test_matches_credits_aspose_producer() -> None:
    with_aspose = _dottrina_signals(producer="Aspose.PDF for .NET 18.4")
    without = _dottrina_signals(producer="Unknown", creator="Unknown")
    assert DejureDottrinaProfile.matches(with_aspose) > DejureDottrinaProfile.matches(without)


def test_matches_credits_aspose_creator_when_producer_missing() -> None:
    signals = _dottrina_signals(producer="", creator="Aspose.PDF for .NET 18.4")
    score = DejureDottrinaProfile.matches(signals)
    assert score >= 0.6


def test_matches_credits_title_bold_signal() -> None:
    with_title = _dottrina_signals(include_title_bold=True)
    without = _dottrina_signals(include_title_bold=False)
    assert DejureDottrinaProfile.matches(with_title) > DejureDottrinaProfile.matches(without)


def test_matches_credits_banner_bold_signal() -> None:
    with_banner = _dottrina_signals(include_banner_bold=True)
    without = _dottrina_signals(include_banner_bold=False)
    assert DejureDottrinaProfile.matches(with_banner) > DejureDottrinaProfile.matches(without)


def test_matches_penalises_marginal_apparatus() -> None:
    clean = _dottrina_signals(marginal_headings=0)
    apparatus = _dottrina_signals(marginal_headings=4051)
    assert DejureDottrinaProfile.matches(clean) > DejureDottrinaProfile.matches(apparatus)


def test_matches_zero_on_torrente_signature() -> None:
    signals = _dottrina_signals(
        body_family="MScotchRoman",
        body_size=11.47,
        producer="PDFsharp 1.31.1789-g",
        creator="PDFsharp 1.31.1789-g",
        include_title_bold=False,
        include_banner_bold=False,
        marginal_headings=4051,
    )
    score = DejureDottrinaProfile.matches(signals)
    assert score == 0.0


def test_matches_zero_on_verdana_body() -> None:
    signals = _dottrina_signals(
        body_family="Verdana",
        producer="Adobe PDF Library 9.0",
        creator="Adobe InDesign CS3",
        include_title_bold=False,
        include_banner_bold=False,
    )
    score = DejureDottrinaProfile.matches(signals)
    assert score == 0.0


def test_matches_zero_on_times_new_roman_body() -> None:
    signals = _dottrina_signals(
        body_family="Times-New-Roman",
        producer="",
        creator="",
        include_title_bold=False,
        include_banner_bold=False,
    )
    score = DejureDottrinaProfile.matches(signals)
    assert score == 0.0


def test_matches_clamps_at_zero() -> None:
    """Penalty stack does not produce a negative score; clamped at 0.0."""
    signals = _dottrina_signals(
        body_family="TimesTenLTStd",
        marginal_headings=1000,
        producer="",
        creator="",
        include_title_bold=False,
        include_banner_bold=False,
        include_banner_marker=True,
        banner_marker_value="NOTE E DOTTRINA",
    )
    score = DejureDottrinaProfile.matches(signals)
    assert score == 0.0


def test_matches_letter_tolerance_accepts_small_drift() -> None:
    signals = _dottrina_signals(width_pt=612.5, height_pt=792.4)
    score = DejureDottrinaProfile.matches(signals)
    assert score >= 0.6


def test_matches_low_body_dominance_drops_arial_bonus() -> None:
    signals = _dottrina_signals(body_dominance=20.0)
    high = _dottrina_signals(body_dominance=80.0)
    assert DejureDottrinaProfile.matches(signals) < DejureDottrinaProfile.matches(high)


def test_matches_positive_contribution_magnitudes_match_constants() -> None:
    """The five positive magnitudes sum to 0.80 (0.30+0.20+0.10+0.10+0.10)."""
    total = (
        CONFIDENCE_ARIAL_BODY_DOMINANT
        + CONFIDENCE_ASPOSE_PRODUCER
        + CONFIDENCE_LETTER_GEOMETRY
        + CONFIDENCE_TITLE_BOLD_PRESENT
        + CONFIDENCE_BANNER_BOLD_PRESENT
    )
    assert total == pytest.approx(0.80)


def test_matches_ns_banner_penalty_magnitude() -> None:
    """The NS banner penalty must equal CONFIDENCE_NS_BANNER_PRESENT_PENALTY."""
    baseline = _dottrina_signals(include_banner_marker=True, banner_marker_value="DOTTRINA")
    ns_doc = _dottrina_signals(include_banner_marker=True, banner_marker_value="NOTE E DOTTRINA")
    delta = DejureDottrinaProfile.matches(baseline) - DejureDottrinaProfile.matches(ns_doc)
    assert delta == pytest.approx(-CONFIDENCE_NS_BANNER_PRESENT_PENALTY)


def test_matches_title_bold_absent_penalty_magnitude() -> None:
    with_title = _dottrina_signals(include_title_bold=True)
    without = _dottrina_signals(include_title_bold=False)
    delta = DejureDottrinaProfile.matches(with_title) - DejureDottrinaProfile.matches(without)
    # +0.10 (present credit) minus (-0.20 absent penalty) = +0.30 swing.
    expected = CONFIDENCE_TITLE_BOLD_PRESENT - CONFIDENCE_TITLE_BOLD_ABSENT_PENALTY
    assert delta == pytest.approx(expected)


def test_matches_empty_specific_markers_no_penalty() -> None:
    """Empty specific_markers list does not trigger NS penalty."""
    signals = _dottrina_signals(include_banner_marker=False)
    score = DejureDottrinaProfile.matches(signals)
    assert score == pytest.approx(0.80)


def test_matches_unrelated_specific_marker_ignored() -> None:
    """A SpecificMarker with a different name is ignored."""
    base = _dottrina_signals(include_banner_marker=False)
    signals = ProfilingSignals(
        typographic_signature=base.typographic_signature,
        apparatus_presence=base.apparatus_presence,
        page_geometry=base.page_geometry,
        producer_creator=base.producer_creator,
        outline_structure=base.outline_structure,
        specific_markers=[SpecificMarker(name="some_unrelated_marker", present=True, value="X")],
    )
    score = DejureDottrinaProfile.matches(signals)
    assert score == pytest.approx(0.80)


def test_matches_banner_marker_value_none_no_penalty() -> None:
    """When the banner marker carries value None (MM case), no NS penalty applies."""
    signals = _dottrina_signals(include_banner_marker=True, banner_marker_value=None)
    score = DejureDottrinaProfile.matches(signals)
    assert score == pytest.approx(0.80)


def test_matches_aspose_in_creator_only() -> None:
    """Aspose in creator only suffices to credit the producer."""
    with_creator = _dottrina_signals(producer="Other", creator="Aspose.PDF for .NET 18.4")
    without = _dottrina_signals(producer="Other", creator="Other")
    assert DejureDottrinaProfile.matches(with_creator) > DejureDottrinaProfile.matches(without)


# ---------------------------------------------------------------------------
# Section 4: Predicates — _is_genre_banner


def test_is_genre_banner_matches_dottrina_text() -> None:
    view = _make_view(
        [_make_span("DOTTRINA", font="Arial-BoldMT", size=BANNER_SIZE, flags=BOLD_FLAG)]
    )
    assert DejureDottrinaProfile._is_genre_banner(view)


def test_is_genre_banner_rejects_other_text() -> None:
    view = _make_view(
        [_make_span("MASSIMA", font="Arial-BoldMT", size=BANNER_SIZE, flags=BOLD_FLAG)]
    )
    assert not DejureDottrinaProfile._is_genre_banner(view)


def test_is_genre_banner_rejects_wrong_size() -> None:
    view = _make_view(
        [_make_span("DOTTRINA", font="Arial-BoldMT", size=BODY_SIZE, flags=BOLD_FLAG)]
    )
    assert not DejureDottrinaProfile._is_genre_banner(view)


def test_is_genre_banner_rejects_non_bold_family() -> None:
    view = _make_view([_make_span("DOTTRINA", font="ArialMT", size=BANNER_SIZE)])
    assert not DejureDottrinaProfile._is_genre_banner(view)


def test_is_genre_banner_rejects_empty_spans() -> None:
    view = _BlockView(block_index=0, block=_make_block(), spans=(), text="")
    assert not DejureDottrinaProfile._is_genre_banner(view)


def test_is_genre_banner_accepts_trailing_whitespace() -> None:
    view = _make_view(
        [_make_span("DOTTRINA  ", font="Arial-BoldMT", size=BANNER_SIZE, flags=BOLD_FLAG)]
    )
    assert DejureDottrinaProfile._is_genre_banner(view)


# ---------------------------------------------------------------------------
# Predicates — _is_page_header_tagline


def test_is_page_header_tagline_matches_fragment() -> None:
    view = _make_view([_make_span("Banche dati editoriali GFL", font="ArialMT", size=BODY_SIZE)])
    assert DejureDottrinaProfile._is_page_header_tagline(view)


def test_is_page_header_tagline_matches_anywhere_in_text() -> None:
    view = _make_view(
        [_make_span("prefix Banche dati editoriali GFL suffix", font="ArialMT", size=BODY_SIZE)]
    )
    assert DejureDottrinaProfile._is_page_header_tagline(view)


def test_is_page_header_tagline_rejects_unrelated_text() -> None:
    view = _make_view([_make_span("Plain prose", font="ArialMT", size=BODY_SIZE)])
    assert not DejureDottrinaProfile._is_page_header_tagline(view)


# ---------------------------------------------------------------------------
# Predicates — _is_title


def test_is_title_matches_bold_13pt() -> None:
    view = _make_view(
        [_make_span("Some title", font="Arial-BoldMT", size=TITLE_SIZE, flags=BOLD_FLAG)]
    )
    assert DejureDottrinaProfile._is_title(view)


def test_is_title_matches_bilingual_title() -> None:
    """Bilingual " - " separator does not affect the predicate."""
    view = _make_view(
        [
            _make_span(
                "Titolo in italiano - English subtitle",
                font="Arial-BoldMT",
                size=TITLE_SIZE,
                flags=BOLD_FLAG,
            )
        ]
    )
    assert DejureDottrinaProfile._is_title(view)


def test_is_title_rejects_9pt() -> None:
    view = _make_view([_make_span("title", font="Arial-BoldMT", size=BANNER_SIZE, flags=BOLD_FLAG)])
    assert not DejureDottrinaProfile._is_title(view)


def test_is_title_rejects_regular_font() -> None:
    view = _make_view([_make_span("title", font="ArialMT", size=TITLE_SIZE)])
    assert not DejureDottrinaProfile._is_title(view)


def test_is_title_rejects_empty_spans() -> None:
    view = _BlockView(block_index=0, block=_make_block(), spans=(), text="")
    assert not DejureDottrinaProfile._is_title(view)


# ---------------------------------------------------------------------------
# Predicates — _is_metadata_block


def test_is_metadata_block_accepts_fonte() -> None:
    view = _make_view([_make_span("Fonte: Rivista X, 2024", font="ArialMT", size=BANNER_SIZE)])
    assert DejureDottrinaProfile._is_metadata_block(view)


def test_is_metadata_block_accepts_autori() -> None:
    view = _make_view([_make_span("Autori: Mario Rossi", font="ArialMT", size=BANNER_SIZE)])
    assert DejureDottrinaProfile._is_metadata_block(view)


def test_is_metadata_block_accepts_bold_labels() -> None:
    view = _make_view(
        [
            _make_span(
                "Fonte: X Autori: Y",
                font="Arial-BoldMT",
                size=BANNER_SIZE,
                flags=BOLD_FLAG,
            )
        ]
    )
    assert DejureDottrinaProfile._is_metadata_block(view)


def test_is_metadata_block_rejects_nota_a_field() -> None:
    """A meta block containing Nota a: belongs to NS, not DT."""
    view = _make_view(
        [
            _make_span(
                "Fonte: X Nota a: Y Autori: Z",
                font="ArialMT",
                size=BANNER_SIZE,
            )
        ]
    )
    assert not DejureDottrinaProfile._is_metadata_block(view)


def test_is_metadata_block_rejects_wrong_size() -> None:
    view = _make_view([_make_span("Fonte: X", font="ArialMT", size=BODY_SIZE)])
    assert not DejureDottrinaProfile._is_metadata_block(view)


def test_is_metadata_block_rejects_non_arial() -> None:
    view = _make_view([_make_span("Fonte: X", font="Times-Roman", size=BANNER_SIZE)])
    assert not DejureDottrinaProfile._is_metadata_block(view)


def test_is_metadata_block_rejects_text_without_labels() -> None:
    view = _make_view([_make_span("body text with no label", font="ArialMT", size=BANNER_SIZE)])
    assert not DejureDottrinaProfile._is_metadata_block(view)


def test_is_metadata_block_rejects_empty_spans() -> None:
    view = _BlockView(block_index=0, block=_make_block(), spans=(), text="")
    assert not DejureDottrinaProfile._is_metadata_block(view)


# ---------------------------------------------------------------------------
# Predicates — _is_sommario_block


def test_is_sommario_block_starts_with_sommario() -> None:
    view = _make_view([_make_span("Sommario 1. Tema. — 2. Altro.", font="ArialMT", size=BODY_SIZE)])
    assert DejureDottrinaProfile._is_sommario_block(view)


def test_is_sommario_block_accepts_editorial_prefix() -> None:
    """The (*) Sommario variant is accepted by the predicate."""
    view = _make_view([_make_span("(*) Sommario 1. Tema.", font="ArialMT", size=BODY_SIZE)])
    assert DejureDottrinaProfile._is_sommario_block(view)


def test_is_sommario_block_rejects_other_text() -> None:
    view = _make_view([_make_span("Indice analitico", font="ArialMT", size=BODY_SIZE)])
    assert not DejureDottrinaProfile._is_sommario_block(view)


def test_is_sommario_block_rejects_wrong_size() -> None:
    view = _make_view([_make_span("Sommario", font="ArialMT", size=BANNER_SIZE)])
    assert not DejureDottrinaProfile._is_sommario_block(view)


def test_is_sommario_block_rejects_empty_spans() -> None:
    view = _BlockView(block_index=0, block=_make_block(), spans=(), text="")
    assert not DejureDottrinaProfile._is_sommario_block(view)


# ---------------------------------------------------------------------------
# Predicates — _is_subsection_heading


def test_is_subsection_heading_matches_two_dot_numbered() -> None:
    view = _make_view(
        [
            _make_span(
                "4.1. Premessa sul tema",
                font="Arial-BoldMT",
                size=BODY_SIZE,
                flags=BOLD_FLAG,
            )
        ]
    )
    assert DejureDottrinaProfile._is_subsection_heading(view)


def test_is_subsection_heading_rejects_single_dot() -> None:
    view = _make_view([_make_span("1. Tema", font="Arial-BoldMT", size=BODY_SIZE, flags=BOLD_FLAG)])
    assert not DejureDottrinaProfile._is_subsection_heading(view)


def test_is_subsection_heading_rejects_regular_font() -> None:
    view = _make_view([_make_span("4.1. Tema", font="ArialMT", size=BODY_SIZE)])
    assert not DejureDottrinaProfile._is_subsection_heading(view)


def test_is_subsection_heading_rejects_empty_spans() -> None:
    view = _BlockView(block_index=0, block=_make_block(), spans=(), text="")
    assert not DejureDottrinaProfile._is_subsection_heading(view)


# ---------------------------------------------------------------------------
# Predicates — _is_section_heading


def test_is_section_heading_matches_uppercase_numbered() -> None:
    view = _make_view(
        [
            _make_span(
                "1. INQUADRAMENTO DEL TEMA",
                font="Arial-BoldMT",
                size=BODY_SIZE,
                flags=BOLD_FLAG,
            )
        ]
    )
    assert DejureDottrinaProfile._is_section_heading(view)


def test_is_section_heading_rejects_lowercase_after_number() -> None:
    view = _make_view([_make_span("1. tema", font="Arial-BoldMT", size=BODY_SIZE, flags=BOLD_FLAG)])
    assert not DejureDottrinaProfile._is_section_heading(view)


def test_is_section_heading_rejects_regular_font() -> None:
    """Style B inline headings (regular font) are NOT classified."""
    view = _make_view([_make_span("1. TEMA", font="ArialMT", size=BODY_SIZE)])
    assert not DejureDottrinaProfile._is_section_heading(view)


def test_is_section_heading_rejects_no_number() -> None:
    view = _make_view([_make_span("TEMA", font="Arial-BoldMT", size=BODY_SIZE, flags=BOLD_FLAG)])
    assert not DejureDottrinaProfile._is_section_heading(view)


def test_is_section_heading_rejects_empty_spans() -> None:
    view = _BlockView(block_index=0, block=_make_block(), spans=(), text="")
    assert not DejureDottrinaProfile._is_section_heading(view)


# ---------------------------------------------------------------------------
# Predicates — _is_notes_section


def test_is_notes_section_standalone_marker() -> None:
    view = _make_view([_make_span("Note:", font="Arial-BoldMT", size=BODY_SIZE, flags=BOLD_FLAG)])
    assert DejureDottrinaProfile._is_notes_section(view)


def test_is_notes_section_variant_with_space() -> None:
    view = _make_view([_make_span("Note :", font="Arial-BoldMT", size=BODY_SIZE, flags=BOLD_FLAG)])
    assert DejureDottrinaProfile._is_notes_section(view)


def test_is_notes_section_glued_with_first_note() -> None:
    view = _make_view(
        [
            _make_span(
                "Note:(1) Prima nota.",
                font="Arial-BoldMT",
                size=BODY_SIZE,
                flags=BOLD_FLAG,
            )
        ]
    )
    assert DejureDottrinaProfile._is_notes_section(view)


def test_is_notes_section_rejects_wrong_family() -> None:
    view = _make_view([_make_span("Note:", font="ArialMT", size=BODY_SIZE)])
    assert not DejureDottrinaProfile._is_notes_section(view)


def test_is_notes_section_rejects_unrelated_text() -> None:
    view = _make_view(
        [_make_span("Tema centrale", font="Arial-BoldMT", size=BODY_SIZE, flags=BOLD_FLAG)]
    )
    assert not DejureDottrinaProfile._is_notes_section(view)


def test_is_notes_section_rejects_empty_spans() -> None:
    view = _BlockView(block_index=0, block=_make_block(), spans=(), text="")
    assert not DejureDottrinaProfile._is_notes_section(view)


# ---------------------------------------------------------------------------
# Predicates — _is_footer


def test_is_footer_matches_pagina_n_di_m() -> None:
    view = _make_view(
        [_make_span("Pagina 3 di 15", font="ArialItalic", size=BODY_SIZE, flags=ITALIC_FLAG)]
    )
    assert DejureDottrinaProfile._is_footer(view)


def test_is_footer_arial_italic_mt() -> None:
    view = _make_view(
        [_make_span("Pagina 1 di 1", font="Arial-ItalicMT", size=BODY_SIZE, flags=ITALIC_FLAG)]
    )
    assert DejureDottrinaProfile._is_footer(view)


def test_is_footer_rejects_non_italic() -> None:
    view = _make_view([_make_span("Pagina 1 di 1", font="ArialMT", size=BODY_SIZE)])
    assert not DejureDottrinaProfile._is_footer(view)


def test_is_footer_rejects_other_text() -> None:
    view = _make_view(
        [_make_span("italic body", font="ArialItalic", size=BODY_SIZE, flags=ITALIC_FLAG)]
    )
    assert not DejureDottrinaProfile._is_footer(view)


def test_is_footer_rejects_empty_spans() -> None:
    view = _BlockView(block_index=0, block=_make_block(), spans=(), text="")
    assert not DejureDottrinaProfile._is_footer(view)


# ---------------------------------------------------------------------------
# Predicates — _is_copyright_stamp


def test_is_copyright_stamp_servizio_fragment() -> None:
    view = _make_view(
        [
            _make_span(
                "SERVIZIO GESTIONE RISORSE DOCUMENTARIE",
                font="ArialMT",
                size=COPYRIGHT_SIZE,
            )
        ]
    )
    assert DejureDottrinaProfile._is_copyright_stamp(view)


def test_is_copyright_stamp_giuffre_fragment() -> None:
    view = _make_view(
        [
            _make_span(
                "© Copyright Giuffrè Francis Lefebvre S.p.A. 2025",
                font="ArialMT",
                size=COPYRIGHT_SIZE,
            )
        ]
    )
    assert DejureDottrinaProfile._is_copyright_stamp(view)


def test_is_copyright_stamp_rejects_wrong_size() -> None:
    view = _make_view(
        [
            _make_span(
                "SERVIZIO GESTIONE RISORSE DOCUMENTARIE",
                font="ArialMT",
                size=BODY_SIZE,
            )
        ]
    )
    assert not DejureDottrinaProfile._is_copyright_stamp(view)


def test_is_copyright_stamp_rejects_other_text() -> None:
    view = _make_view([_make_span("plain", font="ArialMT", size=COPYRIGHT_SIZE)])
    assert not DejureDottrinaProfile._is_copyright_stamp(view)


def test_is_copyright_stamp_rejects_empty_spans() -> None:
    view = _BlockView(block_index=0, block=_make_block(), spans=(), text="")
    assert not DejureDottrinaProfile._is_copyright_stamp(view)


# ---------------------------------------------------------------------------
# Predicates — _is_body


def test_is_body_matches_arial_12pt_regular() -> None:
    view = _make_view([_make_span("body text", font="ArialMT", size=BODY_SIZE)])
    assert DejureDottrinaProfile._is_body(view)


def test_is_body_admits_italic_leading() -> None:
    view = _make_view(
        [_make_span("ratione temporis", font="Arial-ItalicMT", size=BODY_SIZE, flags=ITALIC_FLAG)]
    )
    assert DejureDottrinaProfile._is_body(view)


def test_is_body_rejects_bold_arial_12pt() -> None:
    view = _make_view(
        [_make_span("bold body", font="Arial-BoldMT", size=BODY_SIZE, flags=BOLD_FLAG)]
    )
    assert not DejureDottrinaProfile._is_body(view)


def test_is_body_rejects_non_arial_family() -> None:
    view = _make_view([_make_span("text", font="Times-New-Roman", size=BODY_SIZE)])
    assert not DejureDottrinaProfile._is_body(view)


def test_is_body_rejects_wrong_size() -> None:
    view = _make_view([_make_span("text", font="ArialMT", size=BANNER_SIZE)])
    assert not DejureDottrinaProfile._is_body(view)


def test_is_body_rejects_empty_spans() -> None:
    view = _BlockView(block_index=0, block=_make_block(), spans=(), text="")
    assert not DejureDottrinaProfile._is_body(view)


# ---------------------------------------------------------------------------
# Section 5: refine_classification end-to-end


def test_refine_classification_classifies_banner() -> None:
    span = _make_span("DOTTRINA", font="Arial-BoldMT", size=BANNER_SIZE, flags=BOLD_FLAG)
    block = _make_block(span_range=(0, 1), block_index=0)
    extraction = _make_extraction([span], [block])
    plugin = DejureDottrinaProfile()
    result = plugin.refine_classification(extraction, [_verdict(0)])
    assert result[0].category is SemanticCategory.GENRE_BANNER


def test_refine_classification_promotes_banner_from_running_header() -> None:
    """Banner sitting in the page header zone is rescued from ARTIFACT_RUNNING_HEADER."""
    span = _make_span("DOTTRINA", font="Arial-BoldMT", size=BANNER_SIZE, flags=BOLD_FLAG)
    block = _make_block(span_range=(0, 1), block_index=0)
    extraction = _make_extraction([span], [block])
    plugin = DejureDottrinaProfile()
    result = plugin.refine_classification(
        extraction, [_verdict(0, SemanticCategory.ARTIFACT_RUNNING_HEADER)]
    )
    assert result[0].category is SemanticCategory.GENRE_BANNER


def test_refine_classification_classifies_page_header_tagline() -> None:
    span = _make_span("Banche dati editoriali GFL", font="ArialMT", size=BODY_SIZE)
    block = _make_block(span_range=(0, 1), block_index=0)
    extraction = _make_extraction([span], [block])
    plugin = DejureDottrinaProfile()
    result = plugin.refine_classification(extraction, [_verdict(0)])
    assert result[0].category is SemanticCategory.ARTIFACT_PAGE_HEADER


def test_refine_classification_classifies_title() -> None:
    span = _make_span("Some title", font="Arial-BoldMT", size=TITLE_SIZE, flags=BOLD_FLAG)
    block = _make_block(span_range=(0, 1), block_index=0)
    extraction = _make_extraction([span], [block])
    plugin = DejureDottrinaProfile()
    result = plugin.refine_classification(extraction, [_verdict(0)])
    assert result[0].category is SemanticCategory.TITLE


def test_refine_classification_classifies_metadata_block() -> None:
    span = _make_span("Fonte: X Autori: Y", font="ArialMT", size=BANNER_SIZE)
    block = _make_block(span_range=(0, 1), block_index=0)
    extraction = _make_extraction([span], [block])
    plugin = DejureDottrinaProfile()
    result = plugin.refine_classification(extraction, [_verdict(0)])
    assert result[0].category is SemanticCategory.META_VALUE


def test_refine_classification_skips_metadata_with_nota_a() -> None:
    """A meta block containing Nota a: is left as tier 1 verdict."""
    span = _make_span("Fonte: X Nota a: Y Autori: Z", font="ArialMT", size=BANNER_SIZE)
    block = _make_block(span_range=(0, 1), block_index=0)
    extraction = _make_extraction([span], [block])
    plugin = DejureDottrinaProfile()
    result = plugin.refine_classification(extraction, [_verdict(0)])
    assert result[0].category is SemanticCategory.UNCLASSIFIED


def test_refine_classification_classifies_sommario() -> None:
    span = _make_span("Sommario 1. Tema.", font="ArialMT", size=BODY_SIZE)
    block = _make_block(span_range=(0, 1), block_index=0)
    extraction = _make_extraction([span], [block])
    plugin = DejureDottrinaProfile()
    result = plugin.refine_classification(extraction, [_verdict(0)])
    assert result[0].category is SemanticCategory.TOC_GENERAL


def test_refine_classification_classifies_section_heading_style_a() -> None:
    span = _make_span("1. INQUADRAMENTO", font="Arial-BoldMT", size=BODY_SIZE, flags=BOLD_FLAG)
    block = _make_block(span_range=(0, 1), block_index=0)
    extraction = _make_extraction([span], [block])
    plugin = DejureDottrinaProfile()
    result = plugin.refine_classification(extraction, [_verdict(0)])
    assert result[0].category is SemanticCategory.HEADING_1


def test_refine_classification_classifies_subsection_heading() -> None:
    span = _make_span("4.1. Premessa", font="Arial-BoldMT", size=BODY_SIZE, flags=BOLD_FLAG)
    block = _make_block(span_range=(0, 1), block_index=0)
    extraction = _make_extraction([span], [block])
    plugin = DejureDottrinaProfile()
    result = plugin.refine_classification(extraction, [_verdict(0)])
    assert result[0].category is SemanticCategory.HEADING_2


def test_refine_classification_classifies_notes_label() -> None:
    span = _make_span("Note:", font="Arial-BoldMT", size=BODY_SIZE, flags=BOLD_FLAG)
    block = _make_block(span_range=(0, 1), block_index=0)
    extraction = _make_extraction([span], [block])
    plugin = DejureDottrinaProfile()
    result = plugin.refine_classification(extraction, [_verdict(0)])
    assert result[0].category is SemanticCategory.SECTION_LABEL


def test_refine_classification_classifies_body() -> None:
    span = _make_span("body paragraph", font="ArialMT", size=BODY_SIZE)
    block = _make_block(span_range=(0, 1), block_index=0)
    extraction = _make_extraction([span], [block])
    plugin = DejureDottrinaProfile()
    result = plugin.refine_classification(extraction, [_verdict(0)])
    assert result[0].category is SemanticCategory.BODY


def test_refine_classification_classifies_footer() -> None:
    span = _make_span("Pagina 1 di 15", font="ArialItalic", size=BODY_SIZE, flags=ITALIC_FLAG)
    block = _make_block(span_range=(0, 1), block_index=0)
    extraction = _make_extraction([span], [block])
    plugin = DejureDottrinaProfile()
    result = plugin.refine_classification(extraction, [_verdict(0)])
    assert result[0].category is SemanticCategory.ARTIFACT_FOOTER


def test_refine_classification_classifies_copyright_stamp() -> None:
    span = _make_span("SERVIZIO GESTIONE RISORSE DOCUMENTARIE", font="ArialMT", size=COPYRIGHT_SIZE)
    block = _make_block(span_range=(0, 1), block_index=0)
    extraction = _make_extraction([span], [block])
    plugin = DejureDottrinaProfile()
    result = plugin.refine_classification(extraction, [_verdict(0)])
    assert result[0].category is SemanticCategory.ARTIFACT_STAMP


def test_refine_classification_preserves_sentinel() -> None:
    """A sentinel verdict with block_index = -1 passes through."""
    plugin = DejureDottrinaProfile()
    extraction = _make_extraction([], [])
    sentinel = ClassifiedBlock(
        block_index=-1,
        category=SemanticCategory.EMPTY_PAGE,
        subcategory="0",
        reason="empty_page",
    )
    result = plugin.refine_classification(extraction, [sentinel])
    assert result == [sentinel]


def test_refine_classification_preserves_unclassified_on_unknown_block() -> None:
    span = _make_span("strange", font="OpenSans-Bold", size=14.0, flags=BOLD_FLAG)
    block = _make_block(span_range=(0, 1), block_index=0)
    extraction = _make_extraction([span], [block])
    plugin = DejureDottrinaProfile()
    result = plugin.refine_classification(extraction, [_verdict(0)])
    assert result[0].category is SemanticCategory.UNCLASSIFIED


def test_refine_classification_passes_through_empty_span_block() -> None:
    """A block with no spans (view is None) passes through."""
    block = _make_block(span_range=(0, 0), block_index=0)
    extraction = _make_extraction([], [block])
    plugin = DejureDottrinaProfile()
    result = plugin.refine_classification(extraction, [_verdict(0)])
    assert result[0].category is SemanticCategory.UNCLASSIFIED


def test_refine_classification_notes_region_retags_body_as_note() -> None:
    plugin = DejureDottrinaProfile()
    extraction = _make_extraction(
        [
            _make_span(
                "Note:", font="Arial-BoldMT", size=BODY_SIZE, flags=BOLD_FLAG, block_index=0
            ),
            _make_span("continuation prose", font="ArialMT", size=BODY_SIZE, block_index=1),
        ],
        [
            _make_block(block_index=0, span_range=(0, 1)),
            _make_block(block_index=1, span_range=(1, 2)),
        ],
    )
    refined = plugin.refine_classification(extraction, [_verdict(0), _verdict(1)])
    assert refined[0].category is SemanticCategory.SECTION_LABEL
    assert refined[1].category is SemanticCategory.NOTE


def test_refine_classification_notes_region_resets_at_next_banner() -> None:
    """Multi-article bundle: a second GENRE_BANNER closes the notes region."""
    plugin = DejureDottrinaProfile()
    extraction = _make_extraction(
        [
            _make_span(
                "Note:", font="Arial-BoldMT", size=BODY_SIZE, flags=BOLD_FLAG, block_index=0
            ),
            _make_span("note content", font="ArialMT", size=BODY_SIZE, block_index=1),
            _make_span(
                "DOTTRINA",
                font="Arial-BoldMT",
                size=BANNER_SIZE,
                flags=BOLD_FLAG,
                block_index=2,
            ),
            _make_span("body of article 2", font="ArialMT", size=BODY_SIZE, block_index=3),
        ],
        [
            _make_block(block_index=0, span_range=(0, 1)),
            _make_block(block_index=1, span_range=(1, 2)),
            _make_block(block_index=2, span_range=(2, 3)),
            _make_block(block_index=3, span_range=(3, 4)),
        ],
    )
    refined = plugin.refine_classification(extraction, [_verdict(i) for i in range(4)])
    assert refined[0].category is SemanticCategory.SECTION_LABEL
    assert refined[1].category is SemanticCategory.NOTE
    assert refined[2].category is SemanticCategory.GENRE_BANNER
    # After banner, the notes region closed → body 3 stays BODY.
    assert refined[3].category is SemanticCategory.BODY


def test_refine_classification_body_before_notes_label_stays_body() -> None:
    plugin = DejureDottrinaProfile()
    extraction = _make_extraction(
        [
            _make_span("body before notes", font="ArialMT", size=BODY_SIZE, block_index=0),
            _make_span(
                "Note:", font="Arial-BoldMT", size=BODY_SIZE, flags=BOLD_FLAG, block_index=1
            ),
        ],
        [
            _make_block(block_index=0, span_range=(0, 1)),
            _make_block(block_index=1, span_range=(1, 2)),
        ],
    )
    refined = plugin.refine_classification(extraction, [_verdict(0), _verdict(1)])
    assert refined[0].category is SemanticCategory.BODY
    assert refined[1].category is SemanticCategory.SECTION_LABEL


def test_refine_classification_resets_state_each_invocation() -> None:
    plugin = DejureDottrinaProfile()
    plugin._pending_warnings.append("leftover")
    plugin._minted_crossref_ids.add("node_xxxx")
    plugin._minted_note_ids.add("node_yyyy")
    plugin._minted_editorial_note_ids.add("node_zzzz")
    plugin.refine_classification(_make_extraction([], []), [])
    assert plugin._pending_warnings == []
    assert plugin._minted_crossref_ids == set()
    assert plugin._minted_note_ids == set()
    assert plugin._minted_editorial_note_ids == set()


def test_refine_classification_sentinel_block_in_notes_region() -> None:
    """Sentinel block_index = -1 inside a notes region passes through unchanged."""
    plugin = DejureDottrinaProfile()
    extraction = _make_extraction(
        [
            _make_span(
                "Note:", font="Arial-BoldMT", size=BODY_SIZE, flags=BOLD_FLAG, block_index=0
            ),
        ],
        [_make_block(block_index=0, span_range=(0, 1))],
    )
    sentinel = ClassifiedBlock(
        block_index=-1, category=SemanticCategory.EMPTY_PAGE, reason="empty_page"
    )
    refined = plugin.refine_classification(extraction, [_verdict(0), sentinel])
    assert refined[0].category is SemanticCategory.SECTION_LABEL
    assert refined[1].category is SemanticCategory.EMPTY_PAGE


def test_refine_classification_section_label_without_notes_marker_no_open() -> None:
    """A SECTION_LABEL whose text is not 'Note:' does not open a notes region."""
    plugin = DejureDottrinaProfile()
    # First tier 1 SECTION_LABEL with unrelated text — we pass through.
    extraction = _make_extraction(
        [
            _make_span("Some other label", font="ArialMT", size=BODY_SIZE, block_index=0),
            _make_span("body content", font="ArialMT", size=BODY_SIZE, block_index=1),
        ],
        [
            _make_block(block_index=0, span_range=(0, 1)),
            _make_block(block_index=1, span_range=(1, 2)),
        ],
    )
    refined = plugin.refine_classification(
        extraction,
        [
            _verdict(0, SemanticCategory.SECTION_LABEL),
            _verdict(1),
        ],
    )
    # Body stays BODY because no notes region was opened.
    assert refined[1].category is SemanticCategory.BODY


# ---------------------------------------------------------------------------
# Section 6: refine_reconstruction — _decompose_metadata


def test_decompose_metadata_produces_two_siblings() -> None:
    plugin = DejureDottrinaProfile()
    host = Node(
        id="node_0010",
        category=SemanticCategory.META_VALUE,
        page_index=0,
        block_indices=(2,),
        text="Fonte: Rivista X, 2024Autori: Mario Rossi",
    )
    document = Document(root=(host,))
    refined = plugin.refine_reconstruction(document, _make_extraction([], []), [])
    cats = [n.category for n in refined.root]
    assert cats == [SemanticCategory.FONTE_VALUE, SemanticCategory.AUTHORS]


def test_decompose_metadata_records_transformation() -> None:
    plugin = DejureDottrinaProfile()
    host = Node(
        id="node_0010",
        category=SemanticCategory.META_VALUE,
        page_index=0,
        block_indices=(2,),
        text="Fonte: AAutori: B",
    )
    refined = plugin.refine_reconstruction(Document(root=(host,)), _make_extraction([], []), [])
    metadata_tx = [
        t for t in refined.transformations if t.step_id == "dejure_dottrina_metadata_decompose"
    ]
    assert len(metadata_tx) == 1
    assert metadata_tx[0].split_into is not None
    assert len(metadata_tx[0].split_into) == 2


def test_decompose_metadata_unparseable_missing_fonte() -> None:
    plugin = DejureDottrinaProfile()
    host = Node(
        id="node_0010",
        category=SemanticCategory.META_VALUE,
        page_index=0,
        block_indices=(2,),
        text="Autori: Mario Rossi",  # missing Fonte:
    )
    refined = plugin.refine_reconstruction(Document(root=(host,)), _make_extraction([], []), [])
    assert len(refined.root) == 1
    assert refined.root[0].category is SemanticCategory.META_VALUE
    assert any("metadata_block_unparseable" in w for w in refined.warnings)


def test_decompose_metadata_unparseable_missing_autori() -> None:
    plugin = DejureDottrinaProfile()
    host = Node(
        id="node_0010",
        category=SemanticCategory.META_VALUE,
        page_index=0,
        block_indices=(2,),
        text="Fonte: Rivista X, 2024",  # missing Autori:
    )
    refined = plugin.refine_reconstruction(Document(root=(host,)), _make_extraction([], []), [])
    assert len(refined.root) == 1
    assert refined.root[0].category is SemanticCategory.META_VALUE
    assert any("metadata_block_unparseable" in w for w in refined.warnings)


def test_decompose_metadata_emits_field_warnings() -> None:
    plugin = DejureDottrinaProfile()
    host = Node(
        id="node_0010",
        category=SemanticCategory.META_VALUE,
        page_index=0,
        block_indices=(2,),
        text="Fonte: AAutori: B",
    )
    refined = plugin.refine_reconstruction(Document(root=(host,)), _make_extraction([], []), [])
    field_warnings = [w for w in refined.warnings if "metadata_field_minted" in w]
    assert len(field_warnings) == 2


def test_decompose_metadata_multi_author_value_preserved() -> None:
    plugin = DejureDottrinaProfile()
    host = Node(
        id="node_0010",
        category=SemanticCategory.META_VALUE,
        page_index=0,
        block_indices=(2,),
        text="Fonte: AAutori: Francesco Callari,Vittorio Coppola",
    )
    refined = plugin.refine_reconstruction(Document(root=(host,)), _make_extraction([], []), [])
    authors = next(n for n in refined.root if n.category is SemanticCategory.AUTHORS)
    assert authors.text is not None
    assert "Francesco Callari,Vittorio Coppola" in authors.text


def test_decompose_metadata_unparseable_node_with_no_block_indices() -> None:
    """Host with empty block_indices still emits the unparseable warning."""
    plugin = DejureDottrinaProfile()
    host = Node(
        id="node_0010",
        category=SemanticCategory.META_VALUE,
        page_index=0,
        block_indices=(),
        text="Random text without labels",
    )
    refined = plugin.refine_reconstruction(Document(root=(host,)), _make_extraction([], []), [])
    unparseable = [w for w in refined.warnings if "metadata_block_unparseable" in w]
    assert len(unparseable) == 1
    assert "_block_-1_" in unparseable[0]


# ---------------------------------------------------------------------------
# refine_reconstruction — _parse_toc_general


def test_parse_toc_general_extracts_two_items() -> None:
    plugin = DejureDottrinaProfile()
    host = Node(
        id="node_0001",
        category=SemanticCategory.TOC_GENERAL,
        page_index=0,
        block_indices=(3,),
        text="Sommario 1. Tema. — 2. Altro.",
    )
    refined = plugin.refine_reconstruction(Document(root=(host,)), _make_extraction([], []), [])
    toc = next(n for n in refined.root if n.category is SemanticCategory.TOC_GENERAL)
    assert toc.toc_items is not None
    assert len(toc.toc_items) == 2
    assert toc.toc_items[0].number == "1"
    assert toc.toc_items[0].title == "Tema"
    assert toc.toc_items[1].number == "2"
    assert toc.toc_items[1].title == "Altro"


def test_parse_toc_general_accepts_editorial_prefix() -> None:
    plugin = DejureDottrinaProfile()
    host = Node(
        id="node_0001",
        category=SemanticCategory.TOC_GENERAL,
        page_index=0,
        block_indices=(3,),
        text="(*) Sommario 1. Tema.",
    )
    refined = plugin.refine_reconstruction(Document(root=(host,)), _make_extraction([], []), [])
    toc = next(n for n in refined.root if n.category is SemanticCategory.TOC_GENERAL)
    assert toc.toc_items is not None
    assert len(toc.toc_items) == 1
    assert toc.toc_items[0].number == "1"


def test_parse_toc_general_unparseable_emits_warning() -> None:
    plugin = DejureDottrinaProfile()
    host = Node(
        id="node_0001",
        category=SemanticCategory.TOC_GENERAL,
        page_index=0,
        block_indices=(3,),
        text="Sommario ",  # empty after prefix strip
    )
    refined = plugin.refine_reconstruction(Document(root=(host,)), _make_extraction([], []), [])
    assert any("toc_general_unparseable" in w for w in refined.warnings)


def test_parse_toc_general_emits_parsed_warning() -> None:
    plugin = DejureDottrinaProfile()
    host = Node(
        id="node_0001",
        category=SemanticCategory.TOC_GENERAL,
        page_index=0,
        block_indices=(3,),
        text="Sommario 1. Tema. — 2. Altro.",
    )
    refined = plugin.refine_reconstruction(Document(root=(host,)), _make_extraction([], []), [])
    parsed = [w for w in refined.warnings if "toc_general_parsed" in w]
    assert len(parsed) == 1
    assert "_items_2" in parsed[0]


def test_parse_toc_general_carries_no_page_numbers() -> None:
    plugin = DejureDottrinaProfile()
    host = Node(
        id="node_0001",
        category=SemanticCategory.TOC_GENERAL,
        page_index=0,
        block_indices=(3,),
        text="Sommario 1. Intro — 2. Body.",
    )
    refined = plugin.refine_reconstruction(Document(root=(host,)), _make_extraction([], []), [])
    toc = next(n for n in refined.root if n.category is SemanticCategory.TOC_GENERAL)
    assert toc.toc_items is not None
    assert all(item.page_number is None for item in toc.toc_items)


# ---------------------------------------------------------------------------
# refine_reconstruction — _consolidate_notes_sections + _split_notes_text


def test_consolidate_notes_glued_block_mints_notes() -> None:
    plugin = DejureDottrinaProfile()
    section = Node(
        id="node_0050",
        category=SemanticCategory.SECTION_LABEL,
        page_index=13,
        block_indices=(66,),
        text="Note:(1) Prima.(2) Seconda.(3) Terza.",
    )
    refined = plugin.refine_reconstruction(Document(root=(section,)), _make_extraction([], []), [])
    notes = [n for n in refined.root if n.category is SemanticCategory.NOTE]
    assert len(notes) == 3
    assert notes[0].text is not None
    assert notes[0].text.startswith("(1)")


def test_consolidate_notes_mints_editorial_note_alongside_numeric() -> None:
    """Pattern (ww): (*) chunks are minted as EDITORIAL_NOTE."""
    plugin = DejureDottrinaProfile()
    section = Node(
        id="node_0050",
        category=SemanticCategory.SECTION_LABEL,
        page_index=13,
        block_indices=(66,),
        text="Note:(*) Contributo approvato. (1) Prima. (2) Seconda.",
    )
    refined = plugin.refine_reconstruction(Document(root=(section,)), _make_extraction([], []), [])
    editorials = [n for n in refined.root if n.category is SemanticCategory.EDITORIAL_NOTE]
    notes = [n for n in refined.root if n.category is SemanticCategory.NOTE]
    assert len(editorials) == 1
    assert len(notes) == 2


def test_consolidate_notes_pure_editorial_only() -> None:
    plugin = DejureDottrinaProfile()
    section = Node(
        id="node_0050",
        category=SemanticCategory.SECTION_LABEL,
        page_index=13,
        block_indices=(66,),
        text="Note:(*) Editorial only.",
    )
    refined = plugin.refine_reconstruction(Document(root=(section,)), _make_extraction([], []), [])
    editorials = [n for n in refined.root if n.category is SemanticCategory.EDITORIAL_NOTE]
    notes = [n for n in refined.root if n.category is SemanticCategory.NOTE]
    assert len(editorials) == 1
    assert len(notes) == 0


def test_consolidate_notes_standalone_marker_unparseable() -> None:
    """A standalone 'Note:' marker without content produces no notes."""
    plugin = DejureDottrinaProfile()
    section = Node(
        id="node_0050",
        category=SemanticCategory.SECTION_LABEL,
        page_index=13,
        block_indices=(66,),
        text="Note:",
    )
    refined = plugin.refine_reconstruction(Document(root=(section,)), _make_extraction([], []), [])
    notes = [n for n in refined.root if n.category is SemanticCategory.NOTE]
    assert notes == []
    # The plain "Note:" survives untouched.
    section_label = next(n for n in refined.root if n.category is SemanticCategory.SECTION_LABEL)
    assert section_label.text == "Note:"


def test_consolidate_notes_absorbs_following_body() -> None:
    plugin = DejureDottrinaProfile()
    section = Node(
        id="node_0050",
        category=SemanticCategory.SECTION_LABEL,
        page_index=13,
        block_indices=(66,),
        text="Note:(1) Prima.(2) Seconda con continuazione",
    )
    body = Node(
        id="node_0051",
        category=SemanticCategory.NOTE,  # post-tier-2 retag
        page_index=14,
        block_indices=(68,),
        text="che prosegue.(3) Terza.",
    )
    refined = plugin.refine_reconstruction(
        Document(root=(section, body)), _make_extraction([], []), []
    )
    notes = [n for n in refined.root if n.category is SemanticCategory.NOTE]
    assert len(notes) >= 3


def test_consolidate_notes_bounded_by_next_banner() -> None:
    """Multi-article bundle: next GENRE_BANNER stops notes absorption."""
    plugin = DejureDottrinaProfile()
    section = Node(
        id="node_0050",
        category=SemanticCategory.SECTION_LABEL,
        page_index=13,
        block_indices=(66,),
        text="Note:(1) Solo questa.",
    )
    banner = Node(
        id="node_0051",
        category=SemanticCategory.GENRE_BANNER,
        page_index=14,
        block_indices=(70,),
        text="DOTTRINA",
    )
    second_body = Node(
        id="node_0052",
        category=SemanticCategory.BODY,
        page_index=14,
        block_indices=(71,),
        text="Body of article 2.",
    )
    refined = plugin.refine_reconstruction(
        Document(root=(section, banner, second_body)), _make_extraction([], []), []
    )
    # The banner survives intact.
    banners = [n for n in refined.root if n.category is SemanticCategory.GENRE_BANNER]
    assert len(banners) == 1


def test_consolidate_notes_passthrough_artifact_footer() -> None:
    """ARTIFACT_FOOTER siblings are passed through after notes."""
    plugin = DejureDottrinaProfile()
    section = Node(
        id="node_0050",
        category=SemanticCategory.SECTION_LABEL,
        page_index=13,
        block_indices=(66,),
        text="Note:(1) A.(2) B.",
    )
    footer = Node(
        id="node_0051",
        category=SemanticCategory.ARTIFACT_FOOTER,
        page_index=13,
        block_indices=(67,),
        text="Pagina 14 di 22",
    )
    refined = plugin.refine_reconstruction(
        Document(root=(section, footer)), _make_extraction([], []), []
    )
    artifact_present = any(n.category is SemanticCategory.ARTIFACT_FOOTER for n in refined.root)
    assert artifact_present


def test_consolidate_notes_stops_at_heading_boundary() -> None:
    plugin = DejureDottrinaProfile()
    section = Node(
        id="node_0050",
        category=SemanticCategory.SECTION_LABEL,
        page_index=13,
        block_indices=(66,),
        text="Note:(1) Solo questa.",
    )
    heading = Node(
        id="node_0051",
        category=SemanticCategory.HEADING_1,
        page_index=14,
        block_indices=(68,),
        text="2. NUOVA SEZIONE",
    )
    refined = plugin.refine_reconstruction(
        Document(root=(section, heading)), _make_extraction([], []), []
    )
    heading_node = next(n for n in refined.root if n.category is SemanticCategory.HEADING_1)
    assert heading_node.text == "2. NUOVA SEZIONE"


def test_consolidate_notes_records_transformation_with_split_into_merged_from() -> None:
    plugin = DejureDottrinaProfile()
    section = Node(
        id="node_0050",
        category=SemanticCategory.SECTION_LABEL,
        page_index=13,
        block_indices=(66,),
        text="Note:(1) A.(2) B.",
    )
    body = Node(
        id="node_0051",
        category=SemanticCategory.NOTE,
        page_index=14,
        block_indices=(67,),
        text="(3) C.",
    )
    refined = plugin.refine_reconstruction(
        Document(root=(section, body)), _make_extraction([], []), []
    )
    txs = [t for t in refined.transformations if "notes_section" in t.step_id]
    assert len(txs) == 1
    assert txs[0].split_into is not None
    assert len(txs[0].split_into) == 3
    assert txs[0].merged_from is not None
    assert "node_0051" in txs[0].merged_from


def test_consolidate_notes_unparseable_emits_warning() -> None:
    """When the notes text contains no markers, an unparseable warning is emitted."""
    plugin = DejureDottrinaProfile()
    # The SECTION_LABEL has text after the marker but no (N) or (*) chunk.
    section = Node(
        id="node_0050",
        category=SemanticCategory.SECTION_LABEL,
        page_index=13,
        block_indices=(66,),
        text="Note: some prose with no markers at all",
    )
    refined = plugin.refine_reconstruction(Document(root=(section,)), _make_extraction([], []), [])
    assert any("note_section_unparseable" in w for w in refined.warnings)


# ---------------------------------------------------------------------------
# refine_reconstruction — _maybe_mint_cross_references


def test_mint_cross_references_inline_markers() -> None:
    plugin = DejureDottrinaProfile()
    body = Node(
        id="node_0040",
        category=SemanticCategory.BODY,
        page_index=1,
        block_indices=(10,),
        text="Caso Urgenda(1), Affaire du siècle(2), e altro.",
    )
    refined = plugin.refine_reconstruction(Document(root=(body,)), _make_extraction([], []), [])
    crossrefs = [n for n in refined.root if n.category is SemanticCategory.CROSS_REFERENCE]
    assert len(crossrefs) == 2
    assert crossrefs[0].text == "(1)"
    assert crossrefs[1].text == "(2)"


def test_mint_cross_references_skips_large_markers() -> None:
    """Markers above _CROSSREF_MAX_MARKER_VALUE (500) are skipped."""
    plugin = DejureDottrinaProfile()
    body = Node(
        id="node_0040",
        category=SemanticCategory.BODY,
        page_index=1,
        block_indices=(10,),
        text="reference(1), year(2024). ",
    )
    refined = plugin.refine_reconstruction(Document(root=(body,)), _make_extraction([], []), [])
    crossrefs = [n for n in refined.root if n.category is SemanticCategory.CROSS_REFERENCE]
    assert len(crossrefs) == 1
    assert crossrefs[0].text == "(1)"


def test_mint_cross_references_no_match_returns_unchanged() -> None:
    plugin = DejureDottrinaProfile()
    body = Node(
        id="node_0040",
        category=SemanticCategory.BODY,
        page_index=1,
        block_indices=(10,),
        text="Body prose without any inline marker.",
    )
    refined = plugin.refine_reconstruction(Document(root=(body,)), _make_extraction([], []), [])
    crossrefs = [n for n in refined.root if n.category is SemanticCategory.CROSS_REFERENCE]
    assert crossrefs == []


def test_mint_cross_references_warning_per_match() -> None:
    plugin = DejureDottrinaProfile()
    body = Node(
        id="node_0040",
        category=SemanticCategory.BODY,
        page_index=1,
        block_indices=(10,),
        text="Word(1) other(2) further(3).",
    )
    refined = plugin.refine_reconstruction(Document(root=(body,)), _make_extraction([], []), [])
    mint_warnings = [w for w in refined.warnings if "cross_reference_minted" in w]
    assert len(mint_warnings) == 3


def test_mint_cross_references_on_heading_1_also() -> None:
    """The plugin mints CR on HEADING_1 Nodes (Style A inline marker leakage)."""
    plugin = DejureDottrinaProfile()
    heading = Node(
        id="node_0040",
        category=SemanticCategory.HEADING_1,
        page_index=1,
        block_indices=(10,),
        text="1. SOME HEADING(1)",
    )
    refined = plugin.refine_reconstruction(Document(root=(heading,)), _make_extraction([], []), [])
    crossrefs = [n for n in refined.root if n.category is SemanticCategory.CROSS_REFERENCE]
    assert len(crossrefs) == 1


def test_mint_cross_references_skipped_on_note_nodes() -> None:
    """Synthetic NOTE Nodes do not undergo CR minting (markers inside note text)."""
    plugin = DejureDottrinaProfile()
    section = Node(
        id="node_0050",
        category=SemanticCategory.SECTION_LABEL,
        page_index=13,
        block_indices=(66,),
        text="Note:(1) Reference to (2) within note.",
    )
    refined = plugin.refine_reconstruction(Document(root=(section,)), _make_extraction([], []), [])
    # Only the note Node should appear, no CR mints inside it.
    crossrefs = [n for n in refined.root if n.category is SemanticCategory.CROSS_REFERENCE]
    assert crossrefs == []


# ---------------------------------------------------------------------------
# refine_reconstruction — Document construction


def test_refine_reconstruction_preserves_existing_warnings() -> None:
    plugin = DejureDottrinaProfile()
    doc = Document(root=(), warnings=("preexisting",))
    refined = plugin.refine_reconstruction(doc, _make_extraction([], []), [])
    assert "preexisting" in refined.warnings


def test_refine_reconstruction_flushes_pending_warnings() -> None:
    plugin = DejureDottrinaProfile()
    plugin._pending_warnings = ["plugin:dejure_dottrina:custom_warning"]
    doc = Document(root=(), warnings=())
    refined = plugin.refine_reconstruction(doc, _make_extraction([], []), [])
    assert "plugin:dejure_dottrina:custom_warning" in refined.warnings
    assert plugin._pending_warnings == []


def test_refine_reconstruction_preserves_existing_transformations() -> None:
    plugin = DejureDottrinaProfile()
    from scabopdf_pipeline.postprocessing.types import Transformation

    pre = Transformation(
        step_id="some_step",
        node_id="node_0001",
        page_index=0,
        position=(0, 1),
        original="a",
        normalized="b",
    )
    doc = Document(root=(), transformations=(pre,))
    refined = plugin.refine_reconstruction(doc, _make_extraction([], []), [])
    assert pre in refined.transformations


# ---------------------------------------------------------------------------
# Section 7: refine_apparatus


def test_compute_article_boundaries_single_banner() -> None:
    """A forest with one GENRE_BANNER produces one boundary."""
    plugin = DejureDottrinaProfile()
    banner = Node(
        id="node_0001",
        category=SemanticCategory.GENRE_BANNER,
        page_index=0,
        block_indices=(0,),
        text="DOTTRINA",
    )
    body = Node(
        id="node_0002",
        category=SemanticCategory.BODY,
        page_index=0,
        block_indices=(1,),
        text="body",
    )
    all_nodes = [banner, body]
    boundaries = plugin._compute_article_boundaries(all_nodes)
    assert boundaries == [(0, 2)]


def test_compute_article_boundaries_multiple_banners() -> None:
    plugin = DejureDottrinaProfile()
    nodes = [
        Node(id="node_0001", category=SemanticCategory.GENRE_BANNER, page_index=0, text="DOTTRINA"),
        Node(id="node_0002", category=SemanticCategory.BODY, page_index=0, text="body 1"),
        Node(
            id="node_0003", category=SemanticCategory.GENRE_BANNER, page_index=10, text="DOTTRINA"
        ),
        Node(id="node_0004", category=SemanticCategory.BODY, page_index=10, text="body 2"),
        Node(
            id="node_0005", category=SemanticCategory.GENRE_BANNER, page_index=20, text="DOTTRINA"
        ),
        Node(id="node_0006", category=SemanticCategory.BODY, page_index=20, text="body 3"),
    ]
    boundaries = plugin._compute_article_boundaries(nodes)
    assert boundaries == [(0, 2), (2, 4), (4, 6)]


def test_compute_article_boundaries_no_banner_single_scope() -> None:
    plugin = DejureDottrinaProfile()
    body = Node(
        id="node_0001",
        category=SemanticCategory.BODY,
        page_index=0,
        text="body",
    )
    boundaries = plugin._compute_article_boundaries([body])
    assert boundaries == [(0, 1)]


def test_compute_article_boundaries_prefix_before_banner() -> None:
    """Pre-banner prefix becomes its own scope."""
    plugin = DejureDottrinaProfile()
    nodes = [
        Node(id="node_0001", category=SemanticCategory.BODY, page_index=0, text="prefix"),
        Node(id="node_0002", category=SemanticCategory.GENRE_BANNER, page_index=1, text="DOTTRINA"),
        Node(id="node_0003", category=SemanticCategory.BODY, page_index=1, text="body"),
    ]
    boundaries = plugin._compute_article_boundaries(nodes)
    assert boundaries == [(0, 1), (1, 3)]


def test_compute_article_boundaries_empty_forest() -> None:
    plugin = DejureDottrinaProfile()
    assert plugin._compute_article_boundaries([]) == [(0, 0)]


def test_refine_apparatus_binds_crossref_to_note() -> None:
    plugin = DejureDottrinaProfile()
    body = Node(
        id="node_0040",
        category=SemanticCategory.BODY,
        page_index=1,
        block_indices=(10,),
        text="Caso(1) altro(2).",
    )
    section = Node(
        id="node_0050",
        category=SemanticCategory.SECTION_LABEL,
        page_index=13,
        block_indices=(66,),
        text="Note:(1) Prima.(2) Seconda.",
    )
    document = Document(root=(body, section))
    document = plugin.refine_reconstruction(document, _make_extraction([], []), [])
    document = plugin.refine_apparatus(document, _make_extraction([], []), [])
    crossrefs = [n for n in document.root if n.category is SemanticCategory.CROSS_REFERENCE]
    bound = [n for n in crossrefs if n.apparatus_refs]
    assert len(bound) == 2
    for cr in bound:
        assert cr.apparatus_refs[0].kind is ApparatusRefKind.CROSS_REF_TARGET


def test_refine_apparatus_unresolved_emits_warning() -> None:
    plugin = DejureDottrinaProfile()
    body = Node(
        id="node_0040",
        category=SemanticCategory.BODY,
        page_index=1,
        block_indices=(10,),
        text="riferimento orfano(99).",
    )
    section = Node(
        id="node_0050",
        category=SemanticCategory.SECTION_LABEL,
        page_index=13,
        block_indices=(66,),
        text="Note:(1) Solo questa.",
    )
    document = Document(root=(body, section))
    document = plugin.refine_reconstruction(document, _make_extraction([], []), [])
    document = plugin.refine_apparatus(document, _make_extraction([], []), [])
    assert any("cross_reference_unresolved" in w for w in document.warnings)


def test_refine_apparatus_per_article_scope() -> None:
    """CR (1) in article 1 binds to NOTE (1) of article 1, NOT article 2."""
    plugin = DejureDottrinaProfile()
    banner_1 = Node(
        id="node_0001",
        category=SemanticCategory.GENRE_BANNER,
        page_index=0,
        block_indices=(0,),
        text="DOTTRINA",
    )
    body_1 = Node(
        id="node_0002",
        category=SemanticCategory.BODY,
        page_index=0,
        block_indices=(1,),
        text="art 1 body(1).",
    )
    section_1 = Node(
        id="node_0003",
        category=SemanticCategory.SECTION_LABEL,
        page_index=2,
        block_indices=(5,),
        text="Note:(1) Nota dell'articolo uno.",
    )
    banner_2 = Node(
        id="node_0010",
        category=SemanticCategory.GENRE_BANNER,
        page_index=10,
        block_indices=(20,),
        text="DOTTRINA",
    )
    body_2 = Node(
        id="node_0011",
        category=SemanticCategory.BODY,
        page_index=10,
        block_indices=(21,),
        text="art 2 body(1).",
    )
    section_2 = Node(
        id="node_0012",
        category=SemanticCategory.SECTION_LABEL,
        page_index=12,
        block_indices=(25,),
        text="Note:(1) Nota dell'articolo due.",
    )
    document = Document(root=(banner_1, body_1, section_1, banner_2, body_2, section_2))
    document = plugin.refine_reconstruction(document, _make_extraction([], []), [])
    document = plugin.refine_apparatus(document, _make_extraction([], []), [])
    crossrefs = [
        n for n in _iter_nodes(document.root) if n.category is SemanticCategory.CROSS_REFERENCE
    ]
    notes = [n for n in _iter_nodes(document.root) if n.category is SemanticCategory.NOTE]
    # Two CR were minted (one per article) and bind to different NOTEs.
    bound_targets = {cr.apparatus_refs[0].target_node_id for cr in crossrefs if cr.apparatus_refs}
    note_ids = {n.id for n in notes}
    assert len(bound_targets) == 2
    assert bound_targets <= note_ids


def test_refine_apparatus_filters_tier1_warnings_on_minted_ids() -> None:
    plugin = DejureDottrinaProfile()
    plugin._minted_crossref_ids.add("node_0099")
    document = Document(
        root=(),
        warnings=(
            "unparseable_cross_reference_node_node_0099",
            "unresolved_cross_reference_node_node_0099_n_1",
            "unrelated_warning",
        ),
    )
    document = plugin.refine_apparatus(document, _make_extraction([], []), [])
    assert "unrelated_warning" in document.warnings
    assert "unparseable_cross_reference_node_node_0099" not in document.warnings
    assert "unresolved_cross_reference_node_node_0099_n_1" not in document.warnings


def test_refine_apparatus_does_not_bind_unminted_nodes() -> None:
    """CR Nodes not in _minted_crossref_ids stay untouched."""
    plugin = DejureDottrinaProfile()
    cr = Node(
        id="node_0100",
        category=SemanticCategory.CROSS_REFERENCE,
        page_index=1,
        block_indices=(10,),
        text="(1)",
    )
    document = Document(root=(cr,))
    document = plugin.refine_apparatus(document, _make_extraction([], []), [])
    assert document.root[0].apparatus_refs == ()


def test_refine_apparatus_preserves_existing_transformations() -> None:
    plugin = DejureDottrinaProfile()
    from scabopdf_pipeline.postprocessing.types import Transformation

    tx = Transformation(
        step_id="some_step",
        node_id="node_0001",
        page_index=0,
        position=(0, 1),
        original="a",
        normalized="b",
    )
    document = Document(root=(), transformations=(tx,))
    refined = plugin.refine_apparatus(document, _make_extraction([], []), [])
    assert tx in refined.transformations


# ---------------------------------------------------------------------------
# Section 8: Misc helpers and constants


def test_node_id_minter_generates_padded_ids() -> None:
    minter = _NodeIdMinter(start=42)
    assert minter.mint() == "node_0042"
    assert minter.mint() == "node_0043"
    assert minter.mint() == "node_0044"


def test_node_id_minter_starts_from_zero() -> None:
    minter = _NodeIdMinter(start=0)
    assert minter.mint() == "node_0000"


def test_max_existing_node_counter_walks_tree() -> None:
    leaf = Node(id="node_0099", category=SemanticCategory.BODY, page_index=0)
    parent = Node(
        id="node_0010",
        category=SemanticCategory.HEADING_1,
        page_index=0,
        children=(leaf,),
    )
    assert _max_existing_node_counter((parent,)) == 99


def test_max_existing_node_counter_empty_forest() -> None:
    assert _max_existing_node_counter(()) == -1


def test_max_existing_node_counter_skips_non_matching_ids() -> None:
    """Nodes with non-matching ids contribute -1 (not raised)."""
    odd = Node(id="some_other_id", category=SemanticCategory.BODY, page_index=0)
    assert _max_existing_node_counter((odd,)) == -1


def test_iter_nodes_pre_order_dfs() -> None:
    grandchild = Node(id="node_0003", category=SemanticCategory.BODY, page_index=0)
    child = Node(
        id="node_0002",
        category=SemanticCategory.HEADING_2,
        page_index=0,
        children=(grandchild,),
    )
    root = Node(
        id="node_0001",
        category=SemanticCategory.HEADING_1,
        page_index=0,
        children=(child,),
    )
    nodes = _iter_nodes((root,))
    assert [n.id for n in nodes] == ["node_0001", "node_0002", "node_0003"]


def test_iter_nodes_empty_forest() -> None:
    assert _iter_nodes(()) == []


def test_node_id_pattern_matches_padded_id() -> None:
    assert _NODE_ID_PATTERN.match("node_0000")
    assert _NODE_ID_PATTERN.match("node_9999")
    assert _NODE_ID_PATTERN.match("node_12345")  # any number of digits


def test_node_id_pattern_rejects_invalid_ids() -> None:
    assert _NODE_ID_PATTERN.match("node_abc") is None
    assert _NODE_ID_PATTERN.match("NODE_0000") is None
    assert _NODE_ID_PATTERN.match("some_other_id") is None


def test_warning_prefix_is_namespaced() -> None:
    assert WARNING_PREFIX == "plugin:dejure_dottrina"


def test_warning_templates_share_common_prefix() -> None:
    assert len(WARNING_TEMPLATES) > 0
    for tpl in WARNING_TEMPLATES:
        assert tpl.startswith(WARNING_PREFIX + ":")


def test_block_view_carries_block_and_spans() -> None:
    spans = [_make_span("text", block_index=2)]
    block = _make_block(block_index=2, span_range=(0, 1))
    view = _BlockView(block_index=2, block=block, spans=tuple(spans), text="text")
    assert view.block_index == 2
    assert view.text == "text"
    assert view.spans == tuple(spans)


def test_view_helper_returns_none_on_empty_block() -> None:
    block = _make_block(span_range=(0, 0), block_index=0)
    extraction = _make_extraction([], [block])
    view = DejureDottrinaProfile._view(extraction, 0)
    assert view is None


def test_view_helper_builds_proper_view() -> None:
    span = _make_span("hello", block_index=0)
    block = _make_block(span_range=(0, 1), block_index=0)
    extraction = _make_extraction([span], [block])
    view = DejureDottrinaProfile._view(extraction, 0)
    assert view is not None
    assert view.text == "hello"
    assert len(view.spans) == 1


def test_view_helper_joins_multiple_spans() -> None:
    spans = [
        _make_span("hello ", block_index=0, span_index=0),
        _make_span("world", block_index=0, span_index=1),
    ]
    block = _make_block(span_range=(0, 2), block_index=0)
    extraction = _make_extraction(spans, [block])
    view = DejureDottrinaProfile._view(extraction, 0)
    assert view is not None
    assert view.text == "hello world"


# ---------------------------------------------------------------------------
# Regex patterns


def test_footer_pattern_matches_pagina_x_di_y() -> None:
    assert _FOOTER_PATTERN.match("Pagina 1 di 22")
    assert _FOOTER_PATTERN.match("Pagina 12 di 100")
    assert not _FOOTER_PATTERN.match("Pagina 1")
    assert not _FOOTER_PATTERN.match("plain text")


def test_section_heading_style_a_pattern() -> None:
    assert _SECTION_HEADING_STYLE_A_PATTERN.match("1. INQUADRAMENTO")
    assert _SECTION_HEADING_STYLE_A_PATTERN.match("12. TEMA")
    assert not _SECTION_HEADING_STYLE_A_PATTERN.match("1. tema")
    assert not _SECTION_HEADING_STYLE_A_PATTERN.match("INTRODUCTION")


def test_subsection_heading_pattern_captures_numbers() -> None:
    match = _SUBSECTION_HEADING_PATTERN.match("4.1. Premessa")
    assert match is not None
    assert match.group(1) == "4"
    assert match.group(2) == "1"


def test_subsection_heading_pattern_rejects_single_dot() -> None:
    assert _SUBSECTION_HEADING_PATTERN.match("1. Tema") is None


def test_sommario_trim_pattern_strips_prefix() -> None:
    """The prefix strip handles both 'Sommario ' and '(*) Sommario '."""
    assert _SOMMARIO_TRIM_PATTERN.sub("", "Sommario 1. Tema.") == "1. Tema."
    assert _SOMMARIO_TRIM_PATTERN.sub("", "(*) Sommario 1. Tema.") == "1. Tema."


def test_note_marker_pattern_extracts_number() -> None:
    match = _NOTE_MARKER_PATTERN.match("(42) Bibliographic content")
    assert match is not None
    assert match.group(1) == "42"
    assert _NOTE_MARKER_PATTERN.match("plain") is None


def test_note_split_pattern_splits_numeric_chunks() -> None:
    chunks = _NOTE_SPLIT_PATTERN.split("(1) A. (2) B. (3) C.")
    cleaned = [c for c in chunks if c.strip()]
    assert len(cleaned) == 3


def test_note_split_pattern_splits_editorial_chunk() -> None:
    chunks = _NOTE_SPLIT_PATTERN.split("(*) Editorial. (1) First.")
    cleaned = [c for c in chunks if c.strip()]
    assert len(cleaned) == 2
    assert cleaned[0].startswith("(*)")


def test_editorial_note_prefix_pattern() -> None:
    assert _EDITORIAL_NOTE_PREFIX_PATTERN.match("(*) Some editorial content")
    assert _EDITORIAL_NOTE_PREFIX_PATTERN.match("(*) editorial")
    assert _EDITORIAL_NOTE_PREFIX_PATTERN.match("(1) numeric") is None


def test_crossref_inline_pattern_finds_multiple() -> None:
    matches = list(_CROSSREF_INLINE_PATTERN.finditer("word(1) middle (12) end(99)"))
    captured = [m.group(1) for m in matches]
    assert captured == ["1", "12", "99"]


def test_crossref_inline_pattern_skips_nested_digit_run_ons() -> None:
    """The pattern requires the open paren to not be preceded by a digit."""
    matches = list(_CROSSREF_INLINE_PATTERN.finditer("0(1)"))
    captured = [m.group(1) for m in matches]
    # The '0(' pattern means the match is suppressed.
    assert captured == []


def test_crossref_max_marker_value_constant() -> None:
    """The cap is at 500, accommodating cartabia's longest article ~250 notes."""
    assert _CROSSREF_MAX_MARKER_VALUE == 500


# ---------------------------------------------------------------------------
# Helper predicates: _starts_with_notes_marker, _match_notes_marker


def test_starts_with_notes_marker_recognises_variants() -> None:
    assert DejureDottrinaProfile._starts_with_notes_marker("Note:")
    assert DejureDottrinaProfile._starts_with_notes_marker("Note :")
    assert DejureDottrinaProfile._starts_with_notes_marker("  Note:(1) X.")
    assert not DejureDottrinaProfile._starts_with_notes_marker("Other label:")
    assert not DejureDottrinaProfile._starts_with_notes_marker("")


def test_match_notes_marker_returns_match_object() -> None:
    match = DejureDottrinaProfile._match_notes_marker("Note:(1) X")
    assert match is not None
    assert match.group(0) == "Note:"


def test_match_notes_marker_tolerates_leading_whitespace() -> None:
    match = DejureDottrinaProfile._match_notes_marker("  Note:")
    assert match is not None


def test_match_notes_marker_returns_none_on_unrelated_text() -> None:
    assert DejureDottrinaProfile._match_notes_marker("Other:") is None


# ---------------------------------------------------------------------------
# End-to-end mini scenario


def test_end_to_end_single_article_synthetic() -> None:
    """A minimal single-article pipeline: classification + reconstruction + apparatus."""
    plugin = DejureDottrinaProfile()
    spans = [
        _make_span(
            "DOTTRINA", font="Arial-BoldMT", size=BANNER_SIZE, flags=BOLD_FLAG, block_index=0
        ),
        _make_span(
            "Some title", font="Arial-BoldMT", size=TITLE_SIZE, flags=BOLD_FLAG, block_index=1
        ),
        _make_span("Fonte: X Autori: Y", font="ArialMT", size=BANNER_SIZE, block_index=2),
        _make_span("body text(1).", font="ArialMT", size=BODY_SIZE, block_index=3),
        _make_span(
            "Note:(1) Note one.",
            font="Arial-BoldMT",
            size=BODY_SIZE,
            flags=BOLD_FLAG,
            block_index=4,
        ),
    ]
    blocks = [_make_block(span_range=(i, i + 1), block_index=i) for i in range(5)]
    extraction = _make_extraction(spans, blocks)
    refined_blocks = plugin.refine_classification(extraction, [_verdict(i) for i in range(5)])
    expected = [
        SemanticCategory.GENRE_BANNER,
        SemanticCategory.TITLE,
        SemanticCategory.META_VALUE,
        SemanticCategory.BODY,
        SemanticCategory.SECTION_LABEL,
    ]
    assert [r.category for r in refined_blocks] == expected
