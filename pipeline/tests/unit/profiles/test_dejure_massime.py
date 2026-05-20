"""Unit tests for the dejure_massime corpus plugin."""

from __future__ import annotations

import pytest

from scabopdf_pipeline.classification.types import ClassifiedBlock
from scabopdf_pipeline.extraction.types import Block, ExtractionResult, Span
from scabopdf_pipeline.profiles._dejure_shared import BlockView as _BlockView
from scabopdf_pipeline.profiles.dejure_massime import (
    _REFERRAL_PATTERN,
    BODY_SIZE,
    COPYRIGHT_SIZE,
    LABEL_SIZE,
    NS_TITLE_SIZE,
    WARNING_PREFIX,
    DejureMassimeProfile,
)
from scabopdf_pipeline.profiles.dejure_nota_sentenza import DejureNotaSentenzaProfile
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
ITALIC_FLAG = 0x02


# ---------------------------------------------------------------------------
# Helpers


def _massime_signals(
    *,
    body_family: str = "ArialMT",
    body_size: float = BODY_SIZE,
    body_dominance: float = 80.0,
    include_label_bold: bool = True,
    include_title_bold: bool = True,
    include_ns_title_bold: bool = False,
    producer: str = "Aspose.PDF for .NET 18.4",
    creator: str = "Aspose.PDF for .NET 18.4",
    width_pt: float = 612.0,
    height_pt: float = 792.0,
    marginal_headings: int = 0,
) -> ProfilingSignals:
    fonts = [
        FontDominance(family=body_family, size=body_size, dominance_percent=body_dominance),
    ]
    if include_label_bold:
        fonts.append(FontDominance(family="Arial-BoldMT", size=LABEL_SIZE, dominance_percent=4.0))
    if include_title_bold:
        fonts.append(FontDominance(family="Arial-BoldMT", size=BODY_SIZE, dominance_percent=6.0))
    if include_ns_title_bold:
        fonts.append(
            FontDominance(family="Arial-BoldMT", size=NS_TITLE_SIZE, dominance_percent=0.5)
        )
    return ProfilingSignals(
        typographic_signature=TypographicSignature(fonts=fonts),
        apparatus_presence=ApparatusPresence(marginal_headings=marginal_headings),
        page_geometry=ProfilePageGeometry(width_pt=width_pt, height_pt=height_pt),
        producer_creator=ProducerCreator(producer=producer, creator=creator),
        outline_structure=OutlineStructure(),
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
# Declarative methods


def test_profile_identity() -> None:
    plugin = DejureMassimeProfile()
    assert plugin.profile_id == "dejure_massime"
    assert plugin.editorial_family == "dejure"
    assert plugin.genre == "massime"


def test_get_categories_covers_dejure_specific_set() -> None:
    plugin = DejureMassimeProfile()
    cats = plugin.get_categories()
    expected = {
        SemanticCategory.MASSIMA_LABEL,
        SemanticCategory.REFERRAL,
        SemanticCategory.TITLE,
        SemanticCategory.BODY,
        SemanticCategory.FONTE_LABEL,
        SemanticCategory.FONTE_VALUE,
    }
    assert expected <= cats


def test_get_categories_includes_artifact_carriers() -> None:
    cats = DejureMassimeProfile().get_categories()
    assert SemanticCategory.ARTIFACT_FOOTER in cats
    assert SemanticCategory.ARTIFACT_STAMP in cats
    assert SemanticCategory.ARTIFACT_PAGE_HEADER in cats


def test_get_categories_excludes_nota_sentenza_categories() -> None:
    """Massime has no GENRE_BANNER, no TOC_GENERAL, no SECTION_LABEL."""
    cats = DejureMassimeProfile().get_categories()
    assert SemanticCategory.GENRE_BANNER not in cats
    assert SemanticCategory.TOC_GENERAL not in cats
    assert SemanticCategory.SECTION_LABEL not in cats
    assert SemanticCategory.AUTHORS not in cats


def test_get_post_processing_only_dehyphenate() -> None:
    assert DejureMassimeProfile().get_post_processing() == ["dehyphenate_with_log"]


def test_get_layouts_disabled_is_empty() -> None:
    assert DejureMassimeProfile().get_layouts_disabled() == []


# ---------------------------------------------------------------------------
# matches()


def test_matches_clears_threshold_on_default_signals() -> None:
    score = DejureMassimeProfile.matches(_massime_signals())
    assert score >= 0.6


def test_matches_default_signals_returns_0_80() -> None:
    """Empirical baseline 0.80 on the calibrated three MM fixtures."""
    score = DejureMassimeProfile.matches(_massime_signals())
    assert score == pytest.approx(0.80)


def test_matches_below_threshold_on_non_arial_body() -> None:
    signals = _massime_signals(
        body_family="OpenSans-Regular",
        include_label_bold=False,
        include_title_bold=False,
    )
    score = DejureMassimeProfile.matches(signals)
    assert score < 0.6


def test_matches_zero_on_a4_geometry_non_arial() -> None:
    signals = _massime_signals(
        body_family="OpenSans-Regular",
        width_pt=595.0,
        height_pt=842.0,
        producer="Skia/PDF",
        creator="Skia/PDF",
        include_label_bold=False,
        include_title_bold=False,
    )
    score = DejureMassimeProfile.matches(signals)
    assert score == 0.0


def test_matches_credits_letter_geometry() -> None:
    letter = _massime_signals()
    a4 = _massime_signals(width_pt=595.0, height_pt=842.0)
    assert DejureMassimeProfile.matches(letter) > DejureMassimeProfile.matches(a4)


def test_matches_credits_aspose_producer() -> None:
    with_aspose = _massime_signals(producer="Aspose.PDF for .NET 18.4")
    without = _massime_signals(producer="Unknown", creator="Unknown")
    assert DejureMassimeProfile.matches(with_aspose) > DejureMassimeProfile.matches(without)


def test_matches_credits_aspose_creator_when_producer_missing() -> None:
    signals = _massime_signals(producer="", creator="Aspose.PDF for .NET 18.4")
    score = DejureMassimeProfile.matches(signals)
    assert score >= 0.6


def test_matches_credits_title_bold_signal() -> None:
    with_title = _massime_signals(include_title_bold=True)
    without = _massime_signals(include_title_bold=False)
    assert DejureMassimeProfile.matches(with_title) > DejureMassimeProfile.matches(without)


def test_matches_credits_label_bold_signal() -> None:
    with_label = _massime_signals(include_label_bold=True)
    without = _massime_signals(include_label_bold=False)
    assert DejureMassimeProfile.matches(with_label) > DejureMassimeProfile.matches(without)


def test_matches_penalises_ns_title_bold_present() -> None:
    """The -0.30 penalty when 13pt bold Arial is present (NS title)."""
    mm = _massime_signals(include_ns_title_bold=False)
    ns_doc = _massime_signals(include_ns_title_bold=True)
    s_mm = DejureMassimeProfile.matches(mm)
    s_ns = DejureMassimeProfile.matches(ns_doc)
    assert s_mm - s_ns == pytest.approx(0.30)


def test_matches_below_threshold_on_ns_signature() -> None:
    """MM does not promote on a NS fixture (13pt bold present)."""
    signals = _massime_signals(include_ns_title_bold=True)
    score = DejureMassimeProfile.matches(signals)
    assert score < 0.6


def test_matches_penalises_marginal_apparatus() -> None:
    clean = _massime_signals(marginal_headings=0)
    apparatus = _massime_signals(marginal_headings=4051)
    assert DejureMassimeProfile.matches(clean) > DejureMassimeProfile.matches(apparatus)


def test_matches_zero_on_torrente_signature() -> None:
    signals = _massime_signals(
        body_family="MScotchRoman",
        body_size=11.47,
        producer="PDFsharp 1.31.1789-g",
        creator="PDFsharp 1.31.1789-g",
        include_label_bold=False,
        include_title_bold=False,
        marginal_headings=4051,
    )
    score = DejureMassimeProfile.matches(signals)
    assert score == 0.0


def test_matches_zero_on_verdana_body() -> None:
    signals = _massime_signals(
        body_family="Verdana",
        producer="Adobe PDF Library 9.0",
        creator="Adobe InDesign CS3",
        include_label_bold=False,
        include_title_bold=False,
    )
    score = DejureMassimeProfile.matches(signals)
    assert score == 0.0


def test_matches_zero_on_times_new_roman_body() -> None:
    signals = _massime_signals(
        body_family="Times-New-Roman",
        producer="",
        creator="",
        include_label_bold=False,
        include_title_bold=False,
    )
    score = DejureMassimeProfile.matches(signals)
    assert score == 0.0


def test_matches_clamps_at_zero() -> None:
    """Penalty stack does not produce a negative score; clamped at 0.0."""
    signals = _massime_signals(
        body_family="TimesTenLTStd",
        marginal_headings=1000,
        producer="",
        creator="",
        include_label_bold=False,
        include_title_bold=False,
        include_ns_title_bold=True,
    )
    score = DejureMassimeProfile.matches(signals)
    assert score == 0.0


def test_matches_letter_tolerance_accepts_small_drift() -> None:
    signals = _massime_signals(width_pt=612.5, height_pt=792.4)
    score = DejureMassimeProfile.matches(signals)
    assert score >= 0.6


def test_matches_low_body_dominance_drops_arial_bonus() -> None:
    signals = _massime_signals(body_dominance=20.0)
    high = _massime_signals(body_dominance=80.0)
    assert DejureMassimeProfile.matches(signals) < DejureMassimeProfile.matches(high)


# ---------------------------------------------------------------------------
# Bidirectional symmetry vs NS


def test_matches_below_threshold_on_ns_long_signature() -> None:
    """MM stays below 0.6 on a NS-shaped fixture (banner + title + sommario)."""
    signals = _massime_signals(include_ns_title_bold=True)
    assert DejureMassimeProfile.matches(signals) < 0.6


def test_ns_matches_below_threshold_on_mm_signature() -> None:
    """NS stays below 0.6 on a MM-shaped fixture (no 13pt bold present)."""
    signals = _massime_signals(include_ns_title_bold=False)
    assert DejureNotaSentenzaProfile.matches(signals) < 0.6


def test_bidirectional_symmetry_mm_higher_on_mm_signature() -> None:
    mm_doc = _massime_signals(include_ns_title_bold=False)
    assert DejureMassimeProfile.matches(mm_doc) > DejureNotaSentenzaProfile.matches(mm_doc)


def test_bidirectional_symmetry_ns_higher_on_ns_signature() -> None:
    ns_doc = _massime_signals(include_ns_title_bold=True)
    assert DejureNotaSentenzaProfile.matches(ns_doc) > DejureMassimeProfile.matches(ns_doc)


# ---------------------------------------------------------------------------
# Predicates — _is_massima_label


def test_is_massima_label_matches_exact_text() -> None:
    view = _make_view(
        [_make_span("MASSIMA", font="Arial-BoldMT", size=LABEL_SIZE, flags=BOLD_FLAG)]
    )
    assert DejureMassimeProfile._is_massima_label(view)


def test_is_massima_label_rejects_other_text() -> None:
    view = _make_view([_make_span("Fonte:", font="Arial-BoldMT", size=LABEL_SIZE, flags=BOLD_FLAG)])
    assert not DejureMassimeProfile._is_massima_label(view)


def test_is_massima_label_rejects_wrong_size() -> None:
    view = _make_view([_make_span("MASSIMA", font="Arial-BoldMT", size=BODY_SIZE, flags=BOLD_FLAG)])
    assert not DejureMassimeProfile._is_massima_label(view)


def test_is_massima_label_rejects_non_bold() -> None:
    view = _make_view([_make_span("MASSIMA", font="ArialMT", size=LABEL_SIZE)])
    assert not DejureMassimeProfile._is_massima_label(view)


def test_is_massima_label_rejects_empty_view() -> None:
    view = _BlockView(block_index=0, block=_make_block(), spans=(), text="")
    assert not DejureMassimeProfile._is_massima_label(view)


def test_is_massima_label_accepts_trailing_whitespace() -> None:
    """The strip() normalisation tolerates Aspose trailing whitespace."""
    view = _make_view(
        [_make_span("MASSIMA  ", font="Arial-BoldMT", size=LABEL_SIZE, flags=BOLD_FLAG)]
    )
    assert DejureMassimeProfile._is_massima_label(view)


# ---------------------------------------------------------------------------
# Predicates — _is_fonte_label


def test_is_fonte_label_matches_exact_text() -> None:
    view = _make_view([_make_span("Fonte:", font="Arial-BoldMT", size=LABEL_SIZE, flags=BOLD_FLAG)])
    assert DejureMassimeProfile._is_fonte_label(view)


def test_is_fonte_label_rejects_wrong_text() -> None:
    view = _make_view(
        [_make_span("MASSIMA", font="Arial-BoldMT", size=LABEL_SIZE, flags=BOLD_FLAG)]
    )
    assert not DejureMassimeProfile._is_fonte_label(view)


def test_is_fonte_label_rejects_non_bold() -> None:
    view = _make_view([_make_span("Fonte:", font="ArialMT", size=LABEL_SIZE)])
    assert not DejureMassimeProfile._is_fonte_label(view)


def test_is_fonte_label_rejects_wrong_size() -> None:
    view = _make_view([_make_span("Fonte:", font="Arial-BoldMT", size=BODY_SIZE, flags=BOLD_FLAG)])
    assert not DejureMassimeProfile._is_fonte_label(view)


# ---------------------------------------------------------------------------
# Predicates — _is_title


def test_is_title_matches_bold_12pt() -> None:
    view = _make_view(
        [_make_span("Some title text", font="Arial-BoldMT", size=BODY_SIZE, flags=BOLD_FLAG)]
    )
    assert DejureMassimeProfile._is_title(view)


def test_is_title_matches_classificatory_title() -> None:
    """Section 14.4: classificatory title in MAIUSCOLO must still match."""
    view = _make_view(
        [
            _make_span(
                "RESPONSABILITÀ CIVILE - Cose in custodia",
                font="Arial-BoldMT",
                size=BODY_SIZE,
                flags=BOLD_FLAG,
            )
        ]
    )
    assert DejureMassimeProfile._is_title(view)


def test_is_title_rejects_non_bold() -> None:
    view = _make_view([_make_span("title", font="ArialMT", size=BODY_SIZE)])
    assert not DejureMassimeProfile._is_title(view)


def test_is_title_rejects_wrong_size() -> None:
    view = _make_view([_make_span("title", font="Arial-BoldMT", size=LABEL_SIZE, flags=BOLD_FLAG)])
    assert not DejureMassimeProfile._is_title(view)


def test_is_title_rejects_empty_view() -> None:
    view = _BlockView(block_index=0, block=_make_block(), spans=(), text="")
    assert not DejureMassimeProfile._is_title(view)


# ---------------------------------------------------------------------------
# Predicates — _is_body


def test_is_body_matches_arial_12pt_regular() -> None:
    view = _make_view([_make_span("body text", font="ArialMT", size=BODY_SIZE)])
    assert DejureMassimeProfile._is_body(view)


def test_is_body_matches_arial_italic_opening() -> None:
    """A body paragraph that opens with an italic Latinism."""
    view = _make_view(
        [_make_span("ratione temporis", font="Arial-ItalicMT", size=BODY_SIZE, flags=ITALIC_FLAG)]
    )
    assert DejureMassimeProfile._is_body(view)


def test_is_body_rejects_bold_arial_12pt() -> None:
    """Bold 12pt is TITLE, not BODY."""
    view = _make_view(
        [_make_span("bold body", font="Arial-BoldMT", size=BODY_SIZE, flags=BOLD_FLAG)]
    )
    assert not DejureMassimeProfile._is_body(view)


def test_is_body_rejects_non_arial_family() -> None:
    view = _make_view([_make_span("text", font="Times-New-Roman", size=BODY_SIZE)])
    assert not DejureMassimeProfile._is_body(view)


def test_is_body_rejects_wrong_size() -> None:
    view = _make_view([_make_span("text", font="ArialMT", size=LABEL_SIZE)])
    assert not DejureMassimeProfile._is_body(view)


# ---------------------------------------------------------------------------
# Predicates — _is_fonte_value


def test_is_fonte_value_matches_arial_9pt_regular() -> None:
    view = _make_view([_make_span("Guida al diritto 2025, 42", font="ArialMT", size=LABEL_SIZE)])
    assert DejureMassimeProfile._is_fonte_value(view)


def test_is_fonte_value_rejects_bold_arial_9pt() -> None:
    """Bold 9pt is MASSIMA or Fonte: label, not fonte value."""
    view = _make_view([_make_span("text", font="Arial-BoldMT", size=LABEL_SIZE, flags=BOLD_FLAG)])
    assert not DejureMassimeProfile._is_fonte_value(view)


def test_is_fonte_value_rejects_arial_12pt() -> None:
    view = _make_view([_make_span("text", font="ArialMT", size=BODY_SIZE)])
    assert not DejureMassimeProfile._is_fonte_value(view)


# ---------------------------------------------------------------------------
# Predicates — _is_footer


def test_is_footer_matches_pagina_n_di_m() -> None:
    view = _make_view(
        [_make_span("Pagina 3 di 15", font="ArialItalic", size=BODY_SIZE, flags=ITALIC_FLAG)]
    )
    assert DejureMassimeProfile._is_footer(view)


def test_is_footer_matches_arial_italic_mt_family() -> None:
    """The Arial-ItalicMT inline family also matches the footer family check."""
    view = _make_view(
        [_make_span("Pagina 1 di 1", font="Arial-ItalicMT", size=BODY_SIZE, flags=ITALIC_FLAG)]
    )
    assert DejureMassimeProfile._is_footer(view)


def test_is_footer_rejects_non_italic() -> None:
    view = _make_view([_make_span("Pagina 1 di 1", font="ArialMT", size=BODY_SIZE)])
    assert not DejureMassimeProfile._is_footer(view)


def test_is_footer_rejects_other_text() -> None:
    view = _make_view(
        [_make_span("body italic", font="ArialItalic", size=BODY_SIZE, flags=ITALIC_FLAG)]
    )
    assert not DejureMassimeProfile._is_footer(view)


# ---------------------------------------------------------------------------
# Predicates — _is_copyright_stamp


def test_is_copyright_stamp_matches_servizio_gestione() -> None:
    view = _make_view(
        [_make_span("SERVIZIO GESTIONE RISORSE DOCUMENTARIE", font="ArialMT", size=COPYRIGHT_SIZE)]
    )
    assert DejureMassimeProfile._is_copyright_stamp(view)


def test_is_copyright_stamp_matches_copyright_giuffre() -> None:
    view = _make_view(
        [
            _make_span(
                "© Copyright Giuffrè Francis Lefebvre S.p.A. 2025 07/11/2025",
                font="ArialMT",
                size=COPYRIGHT_SIZE,
            )
        ]
    )
    assert DejureMassimeProfile._is_copyright_stamp(view)


def test_is_copyright_stamp_rejects_wrong_size() -> None:
    view = _make_view(
        [_make_span("SERVIZIO GESTIONE RISORSE DOCUMENTARIE", font="ArialMT", size=BODY_SIZE)]
    )
    assert not DejureMassimeProfile._is_copyright_stamp(view)


def test_is_copyright_stamp_rejects_other_text_at_copyright_size() -> None:
    view = _make_view([_make_span("normal text", font="ArialMT", size=COPYRIGHT_SIZE)])
    assert not DejureMassimeProfile._is_copyright_stamp(view)


# ---------------------------------------------------------------------------
# REFERRAL pattern


@pytest.mark.parametrize(
    "text, organo, sede, data, numero",
    [
        (
            "Cassazione civile sez. III - 24/10/2025, n. 28281",
            "Cassazione civile sez. III",
            None,
            "24/10/2025",
            "28281",
        ),
        (
            "Cassazione civile sez. trib. - 24/10/2025, n. 28307",
            "Cassazione civile sez. trib.",
            None,
            "24/10/2025",
            "28307",
        ),
        (
            "Cassazione civile sez. lav. - 16/10/2025, n. 27626",
            "Cassazione civile sez. lav.",
            None,
            "16/10/2025",
            "27626",
        ),
        (
            "Cassazione civile sez. un. - 26/09/2025, n. 26271",
            "Cassazione civile sez. un.",
            None,
            "26/09/2025",
            "26271",
        ),
        (
            "Corte appello sez. I - L'Aquila, 31/03/2022, n. 489",
            "Corte appello sez. I",
            "L'Aquila",
            "31/03/2022",
            "489",
        ),
        (
            "Consiglio di Stato sez. VI - 22/06/2018, n. 3838",
            "Consiglio di Stato sez. VI",
            None,
            "22/06/2018",
            "3838",
        ),
        (
            "Tribunale sez. III - Bari, 09/02/2011, n. 454",
            "Tribunale sez. III",
            "Bari",
            "09/02/2011",
            "454",
        ),
        ("Tribunale - Piacenza, 21/12/2010, n. 900", "Tribunale", "Piacenza", "21/12/2010", "900"),
        ("Tribunale - Modena, 06/09/2004,", "Tribunale", "Modena", "06/09/2004", None),
    ],
)
def test_referral_pattern_parses_all_variants(
    text: str,
    organo: str,
    sede: str | None,
    data: str,
    numero: str | None,
) -> None:
    match = _REFERRAL_PATTERN.match(text)
    assert match is not None
    assert match.group("organo").strip() == organo
    parsed_sede = match.group("sede")
    if parsed_sede is not None:
        parsed_sede = parsed_sede.strip()
    assert parsed_sede == sede
    assert match.group("data") == data
    assert match.group("numero") == numero


def test_referral_pattern_rejects_pure_body_text() -> None:
    """A body paragraph should not match the referral pattern."""
    text = "Ricorre il vizio di omessa motivazione quando la sentenza..."
    assert _REFERRAL_PATTERN.match(text) is None


def test_referral_pattern_rejects_title_text() -> None:
    """A title should not match the referral pattern."""
    text = "RESPONSABILITÀ CIVILE - Cose in custodia"
    assert _REFERRAL_PATTERN.match(text) is None


# ---------------------------------------------------------------------------
# refine_classification — single-pass cascade


def test_refine_classification_classifies_massima_label() -> None:
    span = _make_span("MASSIMA", font="Arial-BoldMT", size=LABEL_SIZE, flags=BOLD_FLAG)
    block = _make_block(span_range=(0, 1), block_index=0)
    extraction = _make_extraction([span], [block])
    plugin = DejureMassimeProfile()
    result = plugin.refine_classification(extraction, [_verdict(0)])
    assert result[0].category is SemanticCategory.MASSIMA_LABEL


def test_refine_classification_classifies_fonte_label() -> None:
    span = _make_span("Fonte:", font="Arial-BoldMT", size=LABEL_SIZE, flags=BOLD_FLAG)
    block = _make_block(span_range=(0, 1), block_index=0)
    extraction = _make_extraction([span], [block])
    plugin = DejureMassimeProfile()
    result = plugin.refine_classification(extraction, [_verdict(0)])
    assert result[0].category is SemanticCategory.FONTE_LABEL


def test_refine_classification_classifies_title() -> None:
    span = _make_span("Title text", font="Arial-BoldMT", size=BODY_SIZE, flags=BOLD_FLAG)
    block = _make_block(span_range=(0, 1), block_index=0)
    extraction = _make_extraction([span], [block])
    plugin = DejureMassimeProfile()
    result = plugin.refine_classification(extraction, [_verdict(0)])
    assert result[0].category is SemanticCategory.TITLE


def test_refine_classification_classifies_body() -> None:
    span = _make_span("body paragraph text", font="ArialMT", size=BODY_SIZE)
    block = _make_block(span_range=(0, 1), block_index=0)
    extraction = _make_extraction([span], [block])
    plugin = DejureMassimeProfile()
    result = plugin.refine_classification(extraction, [_verdict(0)])
    assert result[0].category is SemanticCategory.BODY


def test_refine_classification_classifies_fonte_value() -> None:
    span = _make_span("Guida al diritto 2025, 42", font="ArialMT", size=LABEL_SIZE)
    block = _make_block(span_range=(0, 1), block_index=0)
    extraction = _make_extraction([span], [block])
    plugin = DejureMassimeProfile()
    result = plugin.refine_classification(extraction, [_verdict(0)])
    assert result[0].category is SemanticCategory.FONTE_VALUE


def test_refine_classification_classifies_footer() -> None:
    span = _make_span("Pagina 1 di 15", font="ArialItalic", size=BODY_SIZE, flags=ITALIC_FLAG)
    block = _make_block(span_range=(0, 1), block_index=0)
    extraction = _make_extraction([span], [block])
    plugin = DejureMassimeProfile()
    result = plugin.refine_classification(extraction, [_verdict(0)])
    assert result[0].category is SemanticCategory.ARTIFACT_FOOTER


def test_refine_classification_classifies_copyright_stamp() -> None:
    span = _make_span(
        "SERVIZIO GESTIONE RISORSE DOCUMENTARIE",
        font="ArialMT",
        size=COPYRIGHT_SIZE,
    )
    block = _make_block(span_range=(0, 1), block_index=0)
    extraction = _make_extraction([span], [block])
    plugin = DejureMassimeProfile()
    result = plugin.refine_classification(extraction, [_verdict(0)])
    assert result[0].category is SemanticCategory.ARTIFACT_STAMP


def test_refine_classification_preserves_tier1_for_empty_page_sentinel() -> None:
    """A sentinel verdict with block_index = -1 (EMPTY_PAGE) passes through."""
    plugin = DejureMassimeProfile()
    extraction = _make_extraction([], [])
    sentinel = ClassifiedBlock(
        block_index=-1,
        category=SemanticCategory.EMPTY_PAGE,
        subcategory="0",
        reason="empty_page",
    )
    result = plugin.refine_classification(extraction, [sentinel])
    assert result == [sentinel]


def test_refine_classification_preserves_unclassified_when_no_predicate_matches() -> None:
    """An OpenSans block that no predicate captures stays UNCLASSIFIED."""
    span = _make_span("strange", font="OpenSans-Bold", size=14.0, flags=BOLD_FLAG)
    block = _make_block(span_range=(0, 1), block_index=0)
    extraction = _make_extraction([span], [block])
    plugin = DejureMassimeProfile()
    result = plugin.refine_classification(extraction, [_verdict(0)])
    assert result[0].category is SemanticCategory.UNCLASSIFIED


# ---------------------------------------------------------------------------
# refine_classification — stateful FSM retagging


def test_referral_after_massima_label_is_retagged_referral() -> None:
    """The first BODY-classified block after a MASSIMA_LABEL becomes REFERRAL."""
    spans = [
        _make_span("MASSIMA", font="Arial-BoldMT", size=LABEL_SIZE, flags=BOLD_FLAG, block_index=0),
        _make_span(
            "Cassazione civile sez. III - 24/10/2025, n. 28281",
            font="ArialMT",
            size=BODY_SIZE,
            block_index=1,
        ),
    ]
    blocks = [
        _make_block(span_range=(0, 1), block_index=0),
        _make_block(span_range=(1, 2), block_index=1),
    ]
    extraction = _make_extraction(spans, blocks)
    plugin = DejureMassimeProfile()
    result = plugin.refine_classification(extraction, [_verdict(0), _verdict(1)])
    assert result[0].category is SemanticCategory.MASSIMA_LABEL
    assert result[1].category is SemanticCategory.REFERRAL
    assert result[1].reason == "dejure_massime_referral_after_massima_label"


def test_referral_retagging_emits_diagnostic_warning() -> None:
    spans = [
        _make_span("MASSIMA", font="Arial-BoldMT", size=LABEL_SIZE, flags=BOLD_FLAG, block_index=0),
        _make_span(
            "Cassazione civile sez. III - 24/10/2025, n. 28281",
            font="ArialMT",
            size=BODY_SIZE,
            block_index=1,
        ),
    ]
    blocks = [
        _make_block(span_range=(0, 1), block_index=0),
        _make_block(span_range=(1, 2), block_index=1),
    ]
    extraction = _make_extraction(spans, blocks)
    plugin = DejureMassimeProfile()
    plugin.refine_classification(extraction, [_verdict(0), _verdict(1)])
    assert any(
        w.startswith(f"{WARNING_PREFIX}:referral_reclassified_block_1_page_0")
        for w in plugin._pending_warnings
    )


def test_referral_retagging_with_unparseable_text_still_promotes() -> None:
    """An unparseable referral still gets promoted but a warning is emitted."""
    spans = [
        _make_span("MASSIMA", font="Arial-BoldMT", size=LABEL_SIZE, flags=BOLD_FLAG, block_index=0),
        _make_span(
            "weird non-matching text",
            font="ArialMT",
            size=BODY_SIZE,
            block_index=1,
        ),
    ]
    blocks = [
        _make_block(span_range=(0, 1), block_index=0),
        _make_block(span_range=(1, 2), block_index=1),
    ]
    extraction = _make_extraction(spans, blocks)
    plugin = DejureMassimeProfile()
    result = plugin.refine_classification(extraction, [_verdict(0), _verdict(1)])
    assert result[1].category is SemanticCategory.REFERRAL
    assert any("referral_pattern_unmatched" in w for w in plugin._pending_warnings)


def test_second_body_after_massima_stays_body() -> None:
    """After REFERRAL is consumed, subsequent BODY blocks stay BODY."""
    spans = [
        _make_span("MASSIMA", font="Arial-BoldMT", size=LABEL_SIZE, flags=BOLD_FLAG, block_index=0),
        _make_span(
            "Cassazione civile sez. III - 24/10/2025, n. 28281",
            font="ArialMT",
            size=BODY_SIZE,
            block_index=1,
        ),
        _make_span("body paragraph one", font="ArialMT", size=BODY_SIZE, block_index=2),
        _make_span("body paragraph two", font="ArialMT", size=BODY_SIZE, block_index=3),
    ]
    blocks = [_make_block(span_range=(i, i + 1), block_index=i) for i in range(4)]
    extraction = _make_extraction(spans, blocks)
    plugin = DejureMassimeProfile()
    result = plugin.refine_classification(extraction, [_verdict(i) for i in range(4)])
    assert result[1].category is SemanticCategory.REFERRAL
    assert result[2].category is SemanticCategory.BODY
    assert result[3].category is SemanticCategory.BODY


def test_referral_retagging_skips_through_artifact_footer_cross_page() -> None:
    """If a footer interleaves MASSIMA and REFERRAL (cross-page), retagging still works."""
    spans = [
        _make_span("MASSIMA", font="Arial-BoldMT", size=LABEL_SIZE, flags=BOLD_FLAG, block_index=0),
        _make_span(
            "Pagina 1 di 15",
            font="ArialItalic",
            size=BODY_SIZE,
            flags=ITALIC_FLAG,
            block_index=1,
        ),
        _make_span(
            "Cassazione civile sez. III - 24/10/2025, n. 28281",
            font="ArialMT",
            size=BODY_SIZE,
            block_index=2,
        ),
    ]
    blocks = [_make_block(span_range=(i, i + 1), block_index=i) for i in range(3)]
    extraction = _make_extraction(spans, blocks)
    plugin = DejureMassimeProfile()
    result = plugin.refine_classification(extraction, [_verdict(i) for i in range(3)])
    assert result[0].category is SemanticCategory.MASSIMA_LABEL
    assert result[1].category is SemanticCategory.ARTIFACT_FOOTER
    assert result[2].category is SemanticCategory.REFERRAL


def test_multi_massima_each_referral_retagged_independently() -> None:
    """In a multi-massima sequence each MASSIMA boundary resets the FSM."""
    spans = [
        _make_span("MASSIMA", font="Arial-BoldMT", size=LABEL_SIZE, flags=BOLD_FLAG, block_index=0),
        _make_span(
            "Cassazione civile sez. III - 24/10/2025, n. 28281",
            font="ArialMT",
            size=BODY_SIZE,
            block_index=1,
        ),
        _make_span("body one", font="ArialMT", size=BODY_SIZE, block_index=2),
        _make_span("MASSIMA", font="Arial-BoldMT", size=LABEL_SIZE, flags=BOLD_FLAG, block_index=3),
        _make_span(
            "Cassazione civile sez. II - 24/10/2025, n. 28284",
            font="ArialMT",
            size=BODY_SIZE,
            block_index=4,
        ),
        _make_span("body two", font="ArialMT", size=BODY_SIZE, block_index=5),
    ]
    blocks = [_make_block(span_range=(i, i + 1), block_index=i) for i in range(6)]
    extraction = _make_extraction(spans, blocks)
    plugin = DejureMassimeProfile()
    result = plugin.refine_classification(extraction, [_verdict(i) for i in range(6)])
    assert result[0].category is SemanticCategory.MASSIMA_LABEL
    assert result[1].category is SemanticCategory.REFERRAL
    assert result[2].category is SemanticCategory.BODY
    assert result[3].category is SemanticCategory.MASSIMA_LABEL
    assert result[4].category is SemanticCategory.REFERRAL
    assert result[5].category is SemanticCategory.BODY


def test_multi_fonte_value_after_label_collected_as_siblings() -> None:
    """Multi-line Fonte (analysis § 14.2): multiple FONTE_VALUE siblings."""
    spans = [
        _make_span("Fonte:", font="Arial-BoldMT", size=LABEL_SIZE, flags=BOLD_FLAG, block_index=0),
        _make_span(
            "Giustizia Civile Massimario 2020",
            font="ArialMT",
            size=LABEL_SIZE,
            block_index=1,
        ),
        _make_span(
            "Responsabilita' Civile e Previdenza 2020, 4, 1292",
            font="ArialMT",
            size=LABEL_SIZE,
            block_index=2,
        ),
    ]
    blocks = [_make_block(span_range=(i, i + 1), block_index=i) for i in range(3)]
    extraction = _make_extraction(spans, blocks)
    plugin = DejureMassimeProfile()
    result = plugin.refine_classification(extraction, [_verdict(i) for i in range(3)])
    assert result[0].category is SemanticCategory.FONTE_LABEL
    assert result[1].category is SemanticCategory.FONTE_VALUE
    assert result[2].category is SemanticCategory.FONTE_VALUE


def test_full_massima_sequence_classification() -> None:
    """A complete six-Node massima cycle is classified end-to-end.

    The six categories in order: MASSIMA_LABEL, REFERRAL, TITLE, BODY,
    FONTE_LABEL, FONTE_VALUE.
    """
    spans = [
        _make_span("MASSIMA", font="Arial-BoldMT", size=LABEL_SIZE, flags=BOLD_FLAG, block_index=0),
        _make_span(
            "Cassazione civile sez. III - 24/10/2025, n. 28281",
            font="ArialMT",
            size=BODY_SIZE,
            block_index=1,
        ),
        _make_span(
            "Title text", font="Arial-BoldMT", size=BODY_SIZE, flags=BOLD_FLAG, block_index=2
        ),
        _make_span("Body of the massima.", font="ArialMT", size=BODY_SIZE, block_index=3),
        _make_span("Fonte:", font="Arial-BoldMT", size=LABEL_SIZE, flags=BOLD_FLAG, block_index=4),
        _make_span("Guida al diritto 2025, 42", font="ArialMT", size=LABEL_SIZE, block_index=5),
    ]
    blocks = [_make_block(span_range=(i, i + 1), block_index=i) for i in range(6)]
    extraction = _make_extraction(spans, blocks)
    plugin = DejureMassimeProfile()
    result = plugin.refine_classification(extraction, [_verdict(i) for i in range(6)])
    expected = [
        SemanticCategory.MASSIMA_LABEL,
        SemanticCategory.REFERRAL,
        SemanticCategory.TITLE,
        SemanticCategory.BODY,
        SemanticCategory.FONTE_LABEL,
        SemanticCategory.FONTE_VALUE,
    ]
    assert [r.category for r in result] == expected


def test_title_only_block_without_preceding_referral_classified_title() -> None:
    """Section 14.5: TITLE at top of page N+1 without preceding REFERRAL on same page."""
    spans = [
        _make_span(
            "Title text", font="Arial-BoldMT", size=BODY_SIZE, flags=BOLD_FLAG, block_index=0
        ),
    ]
    blocks = [_make_block(span_range=(0, 1), block_index=0)]
    extraction = _make_extraction(spans, blocks)
    plugin = DejureMassimeProfile()
    result = plugin.refine_classification(extraction, [_verdict(0)])
    assert result[0].category is SemanticCategory.TITLE


def test_classificatory_title_detected_as_title() -> None:
    """Section 14.4: classificatory uppercase titles still TITLE."""
    spans = [
        _make_span(
            "RESPONSABILITÀ CIVILE - Cose in custodia",
            font="Arial-BoldMT",
            size=BODY_SIZE,
            flags=BOLD_FLAG,
            block_index=0,
        ),
    ]
    blocks = [_make_block(span_range=(0, 1), block_index=0)]
    extraction = _make_extraction(spans, blocks)
    plugin = DejureMassimeProfile()
    result = plugin.refine_classification(extraction, [_verdict(0)])
    assert result[0].category is SemanticCategory.TITLE


def test_classification_clears_pending_warnings_on_new_invocation() -> None:
    """Each invocation resets the pending warnings queue."""
    plugin = DejureMassimeProfile()
    plugin._pending_warnings.append("leftover_warning_from_previous_run")
    plugin.refine_classification(_make_extraction([], []), [])
    assert plugin._pending_warnings == []


# ---------------------------------------------------------------------------
# refine_reconstruction — pass-through hook


def test_refine_reconstruction_passthrough_no_warnings() -> None:
    """With no pending warnings, the Document is returned identical."""
    plugin = DejureMassimeProfile()
    doc = Document(root=(Node(id="node_0001", category=SemanticCategory.BODY, page_index=0),))
    result = plugin.refine_reconstruction(doc, _make_extraction([], []), [])
    assert result is doc


def test_refine_reconstruction_flushes_pending_warnings() -> None:
    plugin = DejureMassimeProfile()
    plugin._pending_warnings = ["plugin:dejure_massime:referral_reclassified_block_1_page_0"]
    doc = Document(root=(), warnings=("preexisting",))
    result = plugin.refine_reconstruction(doc, _make_extraction([], []), [])
    assert "preexisting" in result.warnings
    assert "plugin:dejure_massime:referral_reclassified_block_1_page_0" in result.warnings
    # Queue is cleared after flush.
    assert plugin._pending_warnings == []


def test_refine_reconstruction_does_not_modify_root_or_transformations() -> None:
    plugin = DejureMassimeProfile()
    plugin._pending_warnings = ["plugin:dejure_massime:referral_reclassified_block_0_page_0"]
    node = Node(id="node_0001", category=SemanticCategory.BODY, page_index=0)
    doc = Document(root=(node,), transformations=())
    result = plugin.refine_reconstruction(doc, _make_extraction([], []), [])
    assert result.root == doc.root
    assert result.transformations == doc.transformations


# ---------------------------------------------------------------------------
# refine_apparatus — pass-through hook


def test_refine_apparatus_returns_document_unchanged() -> None:
    plugin = DejureMassimeProfile()
    node = Node(id="node_0001", category=SemanticCategory.MASSIMA_LABEL, page_index=0)
    doc = Document(root=(node,), warnings=("w1",))
    result = plugin.refine_apparatus(doc, _make_extraction([], []), [])
    assert result is doc


# ---------------------------------------------------------------------------
# WARNING_PREFIX shape


def test_warning_prefix_is_plugin_namespace() -> None:
    assert WARNING_PREFIX == "plugin:dejure_massime"


def test_warning_templates_share_common_prefix() -> None:
    from scabopdf_pipeline.profiles.dejure_massime import WARNING_TEMPLATES

    for tpl in WARNING_TEMPLATES:
        assert tpl.startswith(WARNING_PREFIX + ":")


# ---------------------------------------------------------------------------
# _BlockView helper


def test_block_view_carries_block_and_spans() -> None:
    spans = [_make_span("text", block_index=2)]
    block = _make_block(block_index=2, span_range=(0, 1))
    view = _BlockView(block_index=2, block=block, spans=tuple(spans), text="text")
    assert view.block_index == 2
    assert view.text == "text"
    assert view.spans == tuple(spans)


def test_view_helper_returns_none_on_empty_block() -> None:
    """_view returns None when the block has zero spans."""
    block = _make_block(span_range=(0, 0), block_index=0)
    extraction = _make_extraction([], [block])
    view = DejureMassimeProfile._view(extraction, 0)
    assert view is None


def test_view_helper_builds_proper_view() -> None:
    span = _make_span("hello", block_index=0)
    block = _make_block(span_range=(0, 1), block_index=0)
    extraction = _make_extraction([span], [block])
    view = DejureMassimeProfile._view(extraction, 0)
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
    view = DejureMassimeProfile._view(extraction, 0)
    assert view is not None
    assert view.text == "hello world"
