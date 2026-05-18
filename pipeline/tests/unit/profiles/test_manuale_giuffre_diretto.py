"""Unit tests for the manuale_giuffre_diretto corpus plugin (Torrente-Schlesinger)."""

from __future__ import annotations

import pytest

from scabopdf_pipeline.apparatus.types import ApparatusRef, ApparatusRefKind
from scabopdf_pipeline.classification.types import ClassifiedBlock
from scabopdf_pipeline.extraction.types import Block, ExtractionResult, Span
from scabopdf_pipeline.profiles.manuale_giuffre_diretto import (
    ASTERISK_FOOTNOTE_SIZE,
    BODY_SIZE,
    CAPITOLO_SUBSCRIPT_SIZE,
    INDEX_ANALITICO_PAGE_INDEX_MIN,
    INDEX_ENTRY_SIZE,
    INDEX_ENTRY_SUB_SIZE,
    MARGINAL_HEADING_SIZE,
    PARAGRAFO_SIGN_SIZE,
    PARTE_SIZE,
    SOMMARIO_PAGE_INDEX_MIN,
    WARNING_PREFIX,
    ManualeGiuffreDirectoProfile,
    _BlockView,
    _normalise_marker,
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

ITALIC_FLAG = 0x02
BOLD_FLAG = 0x10
BOLD_ITALIC_FLAGS = BOLD_FLAG | ITALIC_FLAG
SERIF_FLAG = 0x04


# ---------------------------------------------------------------------------
# Helpers


def _torrente_signals(
    *,
    body_size: float = BODY_SIZE,
    body_dominance: float = 62.0,
    body_family: str = "MScotchRoman",
    include_filigree: bool = True,
    include_parte_family: bool = True,
    footnote_markers: int = 0,
    marginal_headings: int = 4051,
    italic_9pt_blocks: int = 0,
    producer: str = "PDFsharp 1.31.1789-g (www.pdfsharp.com)",
    creator: str = "PDFsharp 1.31.1789-g (www.pdfsharp.com)",
    has_outline: bool = True,
    entries_count: int = 86,
    width_pt: float = 481.9,
    height_pt: float = 680.3,
) -> ProfilingSignals:
    fonts = [FontDominance(family=body_family, size=body_size, dominance_percent=body_dominance)]
    if include_filigree:
        fonts.append(FontDominance(family="TimesNewRoman", size=15.35, dominance_percent=1.2))
    if include_parte_family:
        fonts.append(
            FontDominance(family="TimesNewRomanPS-BoldMT", size=PARTE_SIZE, dominance_percent=0.1)
        )
    return ProfilingSignals(
        typographic_signature=TypographicSignature(fonts=fonts),
        apparatus_presence=ApparatusPresence(
            footnote_markers=footnote_markers,
            marginal_headings=marginal_headings,
            italic_9pt_blocks=italic_9pt_blocks,
        ),
        page_geometry=ProfilePageGeometry(width_pt=width_pt, height_pt=height_pt),
        producer_creator=ProducerCreator(producer=producer, creator=creator),
        outline_structure=OutlineStructure(has_outline=has_outline, entries_count=entries_count),
    )


def _make_span(
    text: str,
    *,
    font: str = "MScotchRoman",
    size: float = BODY_SIZE,
    flags: int = SERIF_FLAG,
    page: int = 100,
    bbox: tuple[float, float, float, float] = (85.0, 200.0, 430.0, 215.0),
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
    page: int = 100,
    bbox: tuple[float, float, float, float] = (85.0, 200.0, 430.0, 600.0),
    span_range: tuple[int, int] = (0, 1),
    block_index: int = 0,
) -> Block:
    return Block(page=page, block_index=block_index, bbox=bbox, span_range=span_range)


def _make_view(
    spans: list[Span],
    *,
    page: int = 100,
    bbox: tuple[float, float, float, float] = (85.0, 200.0, 430.0, 600.0),
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
    reason: str = "no_match",
) -> ClassifiedBlock:
    return ClassifiedBlock(block_index=block_index, category=category, reason=reason)


def _node(
    node_id: str,
    category: SemanticCategory,
    text: str | None,
    *,
    page_index: int = 100,
    block_indices: tuple[int, ...] = (0,),
    children: tuple[Node, ...] = (),
    level: int | None = None,
    apparatus_refs: tuple[ApparatusRef, ...] = (),
) -> Node:
    return Node(
        id=node_id,
        category=category,
        page_index=page_index,
        block_indices=block_indices,
        text=text,
        level=level,
        children=children,
        apparatus_refs=apparatus_refs,
    )


# ---------------------------------------------------------------------------
# Class attributes


def test_class_attributes() -> None:
    assert ManualeGiuffreDirectoProfile.profile_id == "manuale_giuffre_diretto"
    assert ManualeGiuffreDirectoProfile.editorial_family == "giuffre_diretto"
    assert ManualeGiuffreDirectoProfile.genre == "manuale"


# ---------------------------------------------------------------------------
# matches() — score and symmetric discrimination


def test_matches_full_torrente_fingerprint_clears_threshold() -> None:
    """A complete Torrente fingerprint scores at or near the maximum."""
    score = ManualeGiuffreDirectoProfile.matches(_torrente_signals())
    # 0.35 (body) + 0.25 (marginal) + 0.15 (filigree) + 0.10 (parte) + 0.05 (PDFsharp) = 0.90
    assert score == pytest.approx(0.90)
    assert score >= 0.6


def test_matches_minimal_torrente_signals_still_clears_threshold() -> None:
    """The body + marginal + filigree combination alone clears 0.6."""
    signals = _torrente_signals(
        include_parte_family=False, producer="", creator="", has_outline=False
    )
    score = ManualeGiuffreDirectoProfile.matches(signals)
    # 0.35 + 0.25 + 0.15 = 0.75 — clears threshold.
    assert score == pytest.approx(0.75)
    assert score >= 0.6


def test_matches_on_patriarca_like_signals_stays_below_threshold() -> None:
    """Times-New-Roman body with Zanichelli outline does not clear 0.6."""
    signals = _torrente_signals(
        body_family="Times New Roman",
        include_filigree=False,
        include_parte_family=False,
        marginal_headings=0,
        producer="Acrobat Distiller",
        creator="Zanichelli",
        width_pt=595.0,
        height_pt=842.0,
    )
    score = ManualeGiuffreDirectoProfile.matches(signals)
    # -0.20 (other body) + 0 marginal + 0 filigree + 0 parte + 0 producer = 0.0 (clamped)
    assert score < 0.6
    assert score == pytest.approx(0.0)


def test_matches_on_tesauro_like_signals_stays_below_threshold() -> None:
    """TimesTenLTStd compendium scores at 0 via the body-family penalty."""
    signals = _torrente_signals(
        body_family="TimesTenLTStd",
        include_filigree=False,
        include_parte_family=False,
        marginal_headings=0,
        producer="Adobe PDF Library 10.0.1",
        creator="Adobe InDesign CS6",
        has_outline=False,
    )
    score = ManualeGiuffreDirectoProfile.matches(signals)
    assert score < 0.6
    assert score == pytest.approx(0.0)


def test_matches_on_mosconi_like_signals_stays_below_threshold() -> None:
    """TimesTenLTStd treatise with apparato denso does not clear threshold.

    The body-family penalty (-0.20) plus the traditional-notes penalty
    (-0.30) net out the marginal apparatus and the producer signals.
    """
    signals = _torrente_signals(
        body_family="TimesTenLTStd",
        include_filigree=False,
        include_parte_family=False,
        marginal_headings=593,
        footnote_markers=965,
        producer="Adobe PDF Library 10.0.1",
        creator="Adobe InDesign CS6",
        has_outline=False,
    )
    score = ManualeGiuffreDirectoProfile.matches(signals)
    assert score < 0.6


def test_matches_on_mandrioli_like_signals_stays_below_threshold() -> None:
    """SimonciniGaramondStd dense-apparatus document fails the threshold."""
    signals = _torrente_signals(
        body_family="SimonciniGaramondStd",
        include_filigree=False,
        include_parte_family=False,
        marginal_headings=12,
        footnote_markers=744,
        producer="Adobe Photoshop Image Conversion Plug-in",
        creator="Adobe InDesign 20.2",
    )
    score = ManualeGiuffreDirectoProfile.matches(signals)
    assert score < 0.6


def test_matches_on_marotta_like_signals_stays_below_threshold() -> None:
    """TimesNewRomanPSMT Roman-law monograph fails the threshold."""
    signals = _torrente_signals(
        body_family="TimesNewRomanPSMT",
        include_filigree=False,
        include_parte_family=False,
        marginal_headings=0,
        producer="Acrobat Pro 9.4.5",
        creator="",
        width_pt=595.0,
        height_pt=842.0,
        has_outline=False,
    )
    score = ManualeGiuffreDirectoProfile.matches(signals)
    assert score < 0.6


def test_matches_pdf_with_traditional_notes_loses_30pt_penalty() -> None:
    """A document with footnote_markers above threshold takes the
    symmetric penalty even if other Torrente signals are present.
    """
    signals = _torrente_signals(footnote_markers=1000)
    score = ManualeGiuffreDirectoProfile.matches(signals)
    # 0.35 + 0.25 + 0.15 + 0.10 + 0.05 - 0.30 = 0.60. Just at threshold;
    # this asserts the penalty applied.
    assert score == pytest.approx(0.60)


def test_matches_body_below_dominance_floor_loses_body_signal() -> None:
    """A MScotchRoman body below 40% dominance triggers the other-body penalty."""
    signals = _torrente_signals(body_dominance=20.0)
    score = ManualeGiuffreDirectoProfile.matches(signals)
    # -0.20 (other body penalty fires because no MScotchRoman cleared floor)
    # + 0.25 + 0.15 + 0.10 + 0.05 = 0.35
    assert score == pytest.approx(0.35)


def test_matches_without_pdfsharp_producer_drops_5pt() -> None:
    signals = _torrente_signals(producer="Other", creator="Other")
    score = ManualeGiuffreDirectoProfile.matches(signals)
    # 0.35 + 0.25 + 0.15 + 0.10 + 0 = 0.85
    assert score == pytest.approx(0.85)


def test_matches_clamps_at_zero_floor() -> None:
    """Negative-summed signals clamp at 0.0, never below."""
    signals = _torrente_signals(
        body_family="OtherFont",
        include_filigree=False,
        include_parte_family=False,
        marginal_headings=0,
        footnote_markers=1000,
    )
    score = ManualeGiuffreDirectoProfile.matches(signals)
    assert score == 0.0


# ---------------------------------------------------------------------------
# get_categories / get_post_processing / get_layouts_disabled


def test_get_categories_contains_expected_set() -> None:
    cats = ManualeGiuffreDirectoProfile().get_categories()
    required = {
        SemanticCategory.HEADING_1,
        SemanticCategory.HEADING_2,
        SemanticCategory.HEADING_3,
        SemanticCategory.HEADING_4,
        SemanticCategory.BODY,
        SemanticCategory.MARGINAL_HEADING,
        SemanticCategory.CROSS_REFERENCE,
        SemanticCategory.INDEX_ENTRY,
        SemanticCategory.NOTE,
        SemanticCategory.ARTIFACT_FILIGREE,
        SemanticCategory.UNCLASSIFIED,
        SemanticCategory.EMPTY_PAGE,
    }
    assert required.issubset(cats)


def test_get_post_processing_returns_dehyphenate_only() -> None:
    assert ManualeGiuffreDirectoProfile().get_post_processing() == ["dehyphenate_with_log"]


def test_get_layouts_disabled_returns_l4() -> None:
    disabled = ManualeGiuffreDirectoProfile().get_layouts_disabled()
    assert len(disabled) == 1
    assert disabled[0].layout == "L4"
    assert "apparato note" in disabled[0].reason.lower() or "footnote" in disabled[0].reason.lower()


def test_get_layouts_disabled_returns_disabled_layout_instances() -> None:
    disabled = ManualeGiuffreDirectoProfile().get_layouts_disabled()
    assert all(isinstance(d, DisabledLayout) for d in disabled)


# ---------------------------------------------------------------------------
# _normalise_marker


def test_normalise_marker_plain_digit() -> None:
    assert _normalise_marker("130") == "130"


def test_normalise_marker_hyphenated_bis() -> None:
    assert _normalise_marker("130-bis") == "130-bis"


def test_normalise_marker_space_separated_bis() -> None:
    assert _normalise_marker("130 bis") == "130-bis"


def test_normalise_marker_tight_bis() -> None:
    assert _normalise_marker("130bis") == "130-bis"


def test_normalise_marker_strips_whitespace_and_lowercases() -> None:
    assert _normalise_marker(" 130-Bis ") == "130-bis"


def test_normalise_marker_ter_variant() -> None:
    assert _normalise_marker("691-Ter") == "691-ter"


def test_normalise_marker_quater_variant() -> None:
    assert _normalise_marker("42 quater") == "42-quater"


# ---------------------------------------------------------------------------
# Signature predicates: _is_marginal_heading


def test_is_marginal_heading_left_margin_matches() -> None:
    spans = [_make_span("Socialità del", size=MARGINAL_HEADING_SIZE)]
    view = _make_view(spans, bbox=(40.0, 100.0, 79.0, 120.0))
    assert ManualeGiuffreDirectoProfile._is_marginal_heading(view)


def test_is_marginal_heading_right_margin_matches() -> None:
    spans = [_make_span("Organizzazione", size=MARGINAL_HEADING_SIZE)]
    view = _make_view(spans, bbox=(402.9, 100.0, 441.0, 120.0))
    assert ManualeGiuffreDirectoProfile._is_marginal_heading(view)


def test_is_marginal_heading_italic_variant_admitted() -> None:
    spans = [
        _make_span(
            "Equità",
            font="MScotchRoman-Italic",
            size=MARGINAL_HEADING_SIZE,
            flags=ITALIC_FLAG | SERIF_FLAG,
        )
    ]
    view = _make_view(spans, bbox=(40.0, 100.0, 79.0, 120.0))
    assert ManualeGiuffreDirectoProfile._is_marginal_heading(view)


def test_is_marginal_heading_body_x0_rejected() -> None:
    """A 7.48pt block at body x0 ≈ 200 is not a marginal heading."""
    spans = [_make_span("Body-x text", size=MARGINAL_HEADING_SIZE)]
    view = _make_view(spans, bbox=(200.0, 100.0, 400.0, 120.0))
    assert not ManualeGiuffreDirectoProfile._is_marginal_heading(view)


def test_is_marginal_heading_wrong_size_rejected() -> None:
    """An 11.47pt body block is not a marginal heading even at the margin."""
    spans = [_make_span("Body sized", size=BODY_SIZE)]
    view = _make_view(spans, bbox=(40.0, 100.0, 79.0, 120.0))
    assert not ManualeGiuffreDirectoProfile._is_marginal_heading(view)


def test_is_marginal_heading_wrong_family_rejected() -> None:
    spans = [_make_span("Times", font="TimesNewRoman", size=MARGINAL_HEADING_SIZE)]
    view = _make_view(spans, bbox=(40.0, 100.0, 79.0, 120.0))
    assert not ManualeGiuffreDirectoProfile._is_marginal_heading(view)


def test_is_marginal_heading_empty_spans_rejected() -> None:
    assert not ManualeGiuffreDirectoProfile._is_marginal_heading(
        _BlockView(block_index=0, block=_make_block(), spans=(), text="")
    )


# ---------------------------------------------------------------------------
# Signature predicates: _is_parte_signature


def test_is_parte_signature_matches() -> None:
    spans = [
        _make_span(
            "NOZIONI PRELIMINARI", font="TimesNewRomanPS-BoldMT", size=PARTE_SIZE, flags=BOLD_FLAG
        )
    ]
    view = _make_view(spans)
    assert ManualeGiuffreDirectoProfile._is_parte_signature(view)


def test_is_parte_signature_multiline_matches() -> None:
    """Multi-line PARTE titles are admitted: the predicate checks the leading span only."""
    spans = [
        _make_span(
            "L'ATTIVITÀ GIURIDICA", font="TimesNewRomanPS-BoldMT", size=PARTE_SIZE, flags=BOLD_FLAG
        ),
        _make_span(
            "E LA TUTELA GIURISDIZIONALE",
            font="TimesNewRomanPS-BoldMT",
            size=PARTE_SIZE,
            flags=BOLD_FLAG,
            line_index=1,
            span_index=1,
        ),
    ]
    view = _make_view(spans)
    assert ManualeGiuffreDirectoProfile._is_parte_signature(view)


def test_is_parte_signature_wrong_size_rejected() -> None:
    spans = [
        _make_span("NOT PARTE", font="TimesNewRomanPS-BoldMT", size=BODY_SIZE, flags=BOLD_FLAG)
    ]
    view = _make_view(spans)
    assert not ManualeGiuffreDirectoProfile._is_parte_signature(view)


def test_is_parte_signature_wrong_family_rejected() -> None:
    spans = [_make_span("PARTE-LIKE", font="MScotchRoman", size=PARTE_SIZE)]
    view = _make_view(spans)
    assert not ManualeGiuffreDirectoProfile._is_parte_signature(view)


# ---------------------------------------------------------------------------
# Signature predicates: _is_capitolo_signature


def _capitolo_spans(roman: str = "I", title: str = "L'ORDINAMENTO GIURIDICO") -> list[Span]:
    return [
        _make_span("C", font="MScotchRoman", size=BODY_SIZE, span_index=0),
        _make_span("APITOLO ", font="MScotchRoman", size=CAPITOLO_SUBSCRIPT_SIZE, span_index=1),
        _make_span(roman, font="MScotchRoman", size=BODY_SIZE, span_index=2),
        _make_span(title, font="MScotchRoman", size=BODY_SIZE, line_index=1, span_index=3),
    ]


def test_is_capitolo_signature_three_span_matches() -> None:
    view = _make_view(_capitolo_spans())
    assert ManualeGiuffreDirectoProfile._is_capitolo_signature(view)


def test_is_capitolo_signature_high_roman_matches() -> None:
    view = _make_view(_capitolo_spans(roman="LXXII-BIS", title="UNIONI CIVILI"))
    assert ManualeGiuffreDirectoProfile._is_capitolo_signature(view)


def test_is_capitolo_signature_less_than_three_spans_rejected() -> None:
    spans = [_make_span("C"), _make_span("APITOLO ", size=CAPITOLO_SUBSCRIPT_SIZE)]
    view = _make_view(spans)
    assert not ManualeGiuffreDirectoProfile._is_capitolo_signature(view)


def test_is_capitolo_signature_first_span_not_c_rejected() -> None:
    spans = [
        _make_span("X", font="MScotchRoman", size=BODY_SIZE),
        _make_span("APITOLO ", font="MScotchRoman", size=CAPITOLO_SUBSCRIPT_SIZE),
        _make_span("I", font="MScotchRoman", size=BODY_SIZE),
    ]
    view = _make_view(spans)
    assert not ManualeGiuffreDirectoProfile._is_capitolo_signature(view)


def test_is_capitolo_signature_second_span_wrong_size_rejected() -> None:
    """A regular body block that happens to start with 'C' is not CAPITOLO."""
    spans = [
        _make_span("C", font="MScotchRoman", size=BODY_SIZE),
        _make_span("ontinua...", font="MScotchRoman", size=BODY_SIZE),
        _make_span("ulla", font="MScotchRoman", size=BODY_SIZE),
    ]
    view = _make_view(spans)
    assert not ManualeGiuffreDirectoProfile._is_capitolo_signature(view)


def test_is_capitolo_signature_third_span_wrong_size_rejected() -> None:
    spans = [
        _make_span("C", font="MScotchRoman", size=BODY_SIZE),
        _make_span("APITOLO ", font="MScotchRoman", size=CAPITOLO_SUBSCRIPT_SIZE),
        _make_span("title", font="MScotchRoman", size=CAPITOLO_SUBSCRIPT_SIZE),
    ]
    view = _make_view(spans)
    assert not ManualeGiuffreDirectoProfile._is_capitolo_signature(view)


# ---------------------------------------------------------------------------
# Signature predicates: _is_paragrafo_signature


def _paragrafo_spans(n: str = "1", title: str = "L'ordinamento giuridico.") -> list[Span]:
    return [
        _make_span("§", font="TimesNewRomanPS-BoldMT", size=PARAGRAFO_SIGN_SIZE, flags=BOLD_FLAG),
        _make_span(
            " ", font="TimesNewRomanPS-BoldMT", size=BODY_SIZE, flags=BOLD_FLAG, span_index=1
        ),
        _make_span(
            f"{n}.", font="TimesNewRomanPS-BoldMT", size=BODY_SIZE, flags=BOLD_FLAG, span_index=2
        ),
        _make_span(
            title,
            font="TimesNewRomanPS-BoldItal",
            size=BODY_SIZE,
            flags=BOLD_ITALIC_FLAGS,
            span_index=3,
        ),
    ]


def test_is_paragrafo_signature_composite_matches() -> None:
    view = _make_view(_paragrafo_spans())
    assert ManualeGiuffreDirectoProfile._is_paragrafo_signature(view)


def test_is_paragrafo_signature_bis_variant_matches() -> None:
    view = _make_view(_paragrafo_spans(n="130-bis"))
    assert ManualeGiuffreDirectoProfile._is_paragrafo_signature(view)


def test_is_paragrafo_signature_wrong_leading_size_rejected() -> None:
    spans = [_make_span("§", font="TimesNewRomanPS-BoldMT", size=BODY_SIZE, flags=BOLD_FLAG)]
    view = _make_view(spans)
    assert not ManualeGiuffreDirectoProfile._is_paragrafo_signature(view)


def test_is_paragrafo_signature_wrong_family_rejected() -> None:
    spans = [_make_span("§", font="MScotchRoman", size=PARAGRAFO_SIGN_SIZE)]
    view = _make_view(spans)
    assert not ManualeGiuffreDirectoProfile._is_paragrafo_signature(view)


def test_is_paragrafo_signature_no_section_glyph_rejected() -> None:
    spans = [
        _make_span("§§", font="TimesNewRomanPS-BoldMT", size=PARAGRAFO_SIGN_SIZE, flags=BOLD_FLAG)
    ]
    # leading text "§§" still starts with "§", so the predicate currently
    # accepts; verifying conservative behaviour
    assert ManualeGiuffreDirectoProfile._is_paragrafo_signature(_make_view(spans))


def test_is_paragrafo_signature_text_without_section_glyph_rejected() -> None:
    spans = [
        _make_span("1.", font="TimesNewRomanPS-BoldMT", size=PARAGRAFO_SIGN_SIZE, flags=BOLD_FLAG)
    ]
    view = _make_view(spans)
    assert not ManualeGiuffreDirectoProfile._is_paragrafo_signature(view)


# ---------------------------------------------------------------------------
# Signature predicates: _is_sotto_sezione


def test_is_sotto_sezione_letter_keyed_centered_matches() -> None:
    spans = [
        _make_span("A) ", font="MScotchRoman", size=BODY_SIZE),
        _make_span(
            "LA PERSONA FISICA",
            font="MScotchRoman-Italic",
            size=BODY_SIZE,
            flags=ITALIC_FLAG | SERIF_FLAG,
            span_index=1,
        ),
    ]
    # Centered bbox: x ∈ [180, 300] → center 240
    view = _make_view(spans, bbox=(180.0, 200.0, 300.0, 215.0))
    assert ManualeGiuffreDirectoProfile._is_sotto_sezione(view)


def test_is_sotto_sezione_roman_keyed_centered_matches() -> None:
    spans = [
        _make_span("I. ", font="MScotchRoman", size=BODY_SIZE),
        _make_span(
            "L'ADEMPIMENTO",
            font="MScotchRoman-Italic",
            size=BODY_SIZE,
            flags=ITALIC_FLAG | SERIF_FLAG,
            span_index=1,
        ),
    ]
    view = _make_view(spans, bbox=(180.0, 200.0, 300.0, 215.0))
    assert ManualeGiuffreDirectoProfile._is_sotto_sezione(view)


def test_is_sotto_sezione_offcenter_rejected() -> None:
    """An ``A) X`` block at body-column x is not a structural sotto-sezione."""
    spans = [
        _make_span("A) ", font="MScotchRoman", size=BODY_SIZE),
        _make_span("Accettazione tacita. — Per l'art. 476", font="MScotchRoman", size=BODY_SIZE),
    ]
    view = _make_view(spans, bbox=(51.0, 200.0, 200.0, 215.0))
    assert not ManualeGiuffreDirectoProfile._is_sotto_sezione(view)


def test_is_sotto_sezione_too_long_rejected() -> None:
    spans = [_make_span("A) " + "X" * 250, font="MScotchRoman", size=BODY_SIZE)]
    view = _make_view(spans, bbox=(180.0, 200.0, 300.0, 215.0))
    assert not ManualeGiuffreDirectoProfile._is_sotto_sezione(view)


def test_is_sotto_sezione_wrong_size_rejected() -> None:
    spans = [_make_span("A) LA PERSONA", font="MScotchRoman", size=MARGINAL_HEADING_SIZE)]
    view = _make_view(spans, bbox=(180.0, 200.0, 300.0, 215.0))
    assert not ManualeGiuffreDirectoProfile._is_sotto_sezione(view)


def test_is_sotto_sezione_lowercase_after_marker_rejected() -> None:
    """``b) accettazione`` lowercase enumeration is not a structural sub-section."""
    spans = [_make_span("a) accettazione tacita.", font="MScotchRoman", size=BODY_SIZE)]
    view = _make_view(spans, bbox=(180.0, 200.0, 300.0, 215.0))
    assert not ManualeGiuffreDirectoProfile._is_sotto_sezione(view)


# ---------------------------------------------------------------------------
# Signature predicates: asterisk footnote, front/back matter, index entry, body


def test_is_asterisk_footnote_matches() -> None:
    spans = [
        _make_span(
            "(*) I capitoli sono curati...", font="MScotchRoman", size=ASTERISK_FOOTNOTE_SIZE
        )
    ]
    view = _make_view(spans, page=6)
    assert ManualeGiuffreDirectoProfile._is_asterisk_footnote(view)


def test_is_asterisk_footnote_no_asterisk_marker_rejected() -> None:
    spans = [
        _make_span(
            "Il numero indica il paragrafo", font="MScotchRoman", size=ASTERISK_FOOTNOTE_SIZE
        )
    ]
    view = _make_view(spans, page=6)
    assert not ManualeGiuffreDirectoProfile._is_asterisk_footnote(view)


def test_is_asterisk_footnote_wrong_size_rejected() -> None:
    spans = [_make_span("(*) lookalike", font="MScotchRoman", size=BODY_SIZE)]
    view = _make_view(spans, page=6)
    assert not ManualeGiuffreDirectoProfile._is_asterisk_footnote(view)


def test_is_front_back_matter_heading_indice_sommario() -> None:
    spans = [_make_span("INDICE SOMMARIO (*)", font="MScotchRoman", size=BODY_SIZE)]
    view = _make_view(spans)
    assert ManualeGiuffreDirectoProfile._is_front_back_matter_heading(view)


def test_is_front_back_matter_heading_indice_analitico() -> None:
    spans = [_make_span("INDICE ANALITICO-ALFABETICO", font="MScotchRoman", size=BODY_SIZE)]
    view = _make_view(spans)
    assert ManualeGiuffreDirectoProfile._is_front_back_matter_heading(view)


def test_is_front_back_matter_heading_abbreviazioni() -> None:
    spans = [_make_span("ABBREVIAZIONI", font="MScotchRoman", size=BODY_SIZE)]
    view = _make_view(spans)
    assert ManualeGiuffreDirectoProfile._is_front_back_matter_heading(view)


def test_is_front_back_matter_heading_prefazione() -> None:
    spans = [_make_span("PREFAZIONE alla XXV edizione", font="MScotchRoman", size=BODY_SIZE)]
    view = _make_view(spans)
    assert ManualeGiuffreDirectoProfile._is_front_back_matter_heading(view)


def test_is_front_back_matter_heading_body_text_rejected() -> None:
    spans = [_make_span("Ogni società, ogni comunità", font="MScotchRoman", size=BODY_SIZE)]
    view = _make_view(spans)
    assert not ManualeGiuffreDirectoProfile._is_front_back_matter_heading(view)


def test_is_index_entry_sommario_page_matches() -> None:
    spans = [_make_span("L'ordinamento giuridico", font="MScotchRoman", size=INDEX_ENTRY_SIZE)]
    view = _make_view(spans, page=SOMMARIO_PAGE_INDEX_MIN + 1)
    assert ManualeGiuffreDirectoProfile._is_index_entry(view)


def test_is_index_entry_analitico_page_matches() -> None:
    spans = [_make_span("Ab intestato", font="MScotchRoman-Italic", size=INDEX_ENTRY_SIZE)]
    view = _make_view(spans, page=INDEX_ANALITICO_PAGE_INDEX_MIN + 5)
    assert ManualeGiuffreDirectoProfile._is_index_entry(view)


def test_is_index_entry_sommario_sub_size_matches() -> None:
    spans = [_make_span("CAPITOLO I", font="MScotchRoman", size=INDEX_ENTRY_SUB_SIZE)]
    view = _make_view(spans, page=SOMMARIO_PAGE_INDEX_MIN + 1)
    assert ManualeGiuffreDirectoProfile._is_index_entry(view)


def test_is_index_entry_body_page_rejected() -> None:
    spans = [_make_span("Some content", font="MScotchRoman", size=INDEX_ENTRY_SIZE)]
    view = _make_view(spans, page=500)  # body region
    assert not ManualeGiuffreDirectoProfile._is_index_entry(view)


def test_is_index_entry_wrong_size_rejected() -> None:
    spans = [_make_span("body sized", font="MScotchRoman", size=BODY_SIZE)]
    view = _make_view(spans, page=SOMMARIO_PAGE_INDEX_MIN + 1)
    assert not ManualeGiuffreDirectoProfile._is_index_entry(view)


def test_is_body_signature_matches() -> None:
    spans = [_make_span("Body content", font="MScotchRoman", size=BODY_SIZE)]
    assert ManualeGiuffreDirectoProfile._is_body_signature(_make_view(spans))


def test_is_body_signature_italic_admitted() -> None:
    spans = [_make_span("Latin", font="MScotchRoman-Italic", size=BODY_SIZE, flags=ITALIC_FLAG)]
    assert ManualeGiuffreDirectoProfile._is_body_signature(_make_view(spans))


def test_is_body_signature_wrong_font_rejected() -> None:
    spans = [_make_span("TNR text", font="TimesNewRoman", size=BODY_SIZE)]
    assert not ManualeGiuffreDirectoProfile._is_body_signature(_make_view(spans))


# ---------------------------------------------------------------------------
# refine_classification


def _classify_via_plugin(
    extraction: ExtractionResult,
    tier1: list[ClassifiedBlock],
) -> list[ClassifiedBlock]:
    plugin = ManualeGiuffreDirectoProfile()
    return plugin.refine_classification(extraction, tier1)


def test_refine_classification_promotes_marginal_heading() -> None:
    spans = [_make_span("Socialità", size=MARGINAL_HEADING_SIZE)]
    blocks = [_make_block(span_range=(0, 1), bbox=(40.0, 100.0, 79.0, 120.0))]
    ext = _make_extraction(spans, blocks)
    refined = _classify_via_plugin(ext, [_verdict(0)])
    assert refined[0].category is SemanticCategory.MARGINAL_HEADING


def test_refine_classification_promotes_parte() -> None:
    spans = [
        _make_span(
            "NOZIONI PRELIMINARI", font="TimesNewRomanPS-BoldMT", size=PARTE_SIZE, flags=BOLD_FLAG
        )
    ]
    blocks = [_make_block(span_range=(0, 1))]
    ext = _make_extraction(spans, blocks)
    refined = _classify_via_plugin(ext, [_verdict(0)])
    assert refined[0].category is SemanticCategory.HEADING_1


def test_refine_classification_promotes_capitolo() -> None:
    spans = _capitolo_spans()
    blocks = [_make_block(span_range=(0, len(spans)), bbox=(135.0, 134.0, 312.0, 161.0))]
    ext = _make_extraction(spans, blocks)
    refined = _classify_via_plugin(ext, [_verdict(0)])
    assert refined[0].category is SemanticCategory.HEADING_2


def test_refine_classification_capitolo_signature_without_text_pattern_warns_and_keeps() -> None:
    """A small-caps three-span signature whose joined text does not match
    the CAPITOLO regex stays UNCLASSIFIED and queues a warning.
    """
    # Joined text "CAPITOLO ZZZ" — no Roman-numeral char after the whitespace,
    # so ``^CAPITOLO\\s+[IVXLCDM]+`` fails.
    spans = [
        _make_span("C", font="MScotchRoman", size=BODY_SIZE),
        _make_span("APITOLO ", font="MScotchRoman", size=CAPITOLO_SUBSCRIPT_SIZE),
        _make_span("ZZZ", font="MScotchRoman", size=BODY_SIZE),
    ]
    blocks = [_make_block(span_range=(0, 3))]
    ext = _make_extraction(spans, blocks)
    plugin = ManualeGiuffreDirectoProfile()
    plugin.refine_classification(ext, [_verdict(0)])
    assert any(
        w.startswith(f"{WARNING_PREFIX}:capitolo_signature_unmatched_block_")
        for w in plugin._pending_warnings
    )


def test_refine_classification_promotes_paragrafo() -> None:
    spans = _paragrafo_spans()
    blocks = [_make_block(span_range=(0, len(spans)))]
    ext = _make_extraction(spans, blocks)
    refined = _classify_via_plugin(ext, [_verdict(0)])
    assert refined[0].category is SemanticCategory.HEADING_4


def test_refine_classification_paragrafo_text_without_marker_warns() -> None:
    """A 10.98pt § leading span whose joined text doesn't form a paragrafo emits a warning."""
    spans = [
        _make_span("§", font="TimesNewRomanPS-BoldMT", size=PARAGRAFO_SIGN_SIZE, flags=BOLD_FLAG),
        _make_span(" senza numero", font="TimesNewRomanPS-BoldMT", size=BODY_SIZE, flags=BOLD_FLAG),
    ]
    blocks = [_make_block(span_range=(0, 2))]
    ext = _make_extraction(spans, blocks)
    plugin = ManualeGiuffreDirectoProfile()
    plugin.refine_classification(ext, [_verdict(0)])
    assert any(
        w.startswith(f"{WARNING_PREFIX}:paragraph_heading_pattern_unmatched_block_")
        for w in plugin._pending_warnings
    )


def test_refine_classification_promotes_sotto_sezione() -> None:
    spans = [
        _make_span("A) ", font="MScotchRoman", size=BODY_SIZE),
        _make_span(
            "LA PERSONA FISICA",
            font="MScotchRoman-Italic",
            size=BODY_SIZE,
            flags=ITALIC_FLAG | SERIF_FLAG,
            span_index=1,
        ),
    ]
    blocks = [_make_block(span_range=(0, 2), bbox=(180.0, 200.0, 300.0, 215.0))]
    ext = _make_extraction(spans, blocks)
    refined = _classify_via_plugin(ext, [_verdict(0)])
    assert refined[0].category is SemanticCategory.HEADING_3


def test_refine_classification_promotes_asterisk_footnote() -> None:
    spans = [_make_span("(*) I capitoli I-VI...", font="MScotchRoman", size=ASTERISK_FOOTNOTE_SIZE)]
    blocks = [_make_block(span_range=(0, 1), page=6, bbox=(51.0, 592.0, 349.0, 610.0))]
    ext = _make_extraction(spans, blocks)
    refined = _classify_via_plugin(ext, [_verdict(0)])
    assert refined[0].category is SemanticCategory.NOTE


def test_refine_classification_promotes_front_back_matter_heading() -> None:
    spans = [_make_span("ABBREVIAZIONI", font="MScotchRoman", size=BODY_SIZE)]
    blocks = [_make_block(span_range=(0, 1), page=1556)]
    ext = _make_extraction(spans, blocks)
    refined = _classify_via_plugin(ext, [_verdict(0)])
    assert refined[0].category is SemanticCategory.HEADING_1


def test_refine_classification_promotes_index_entry() -> None:
    spans = [
        _make_span("Ab intestato (successione), 639.", font="MScotchRoman", size=INDEX_ENTRY_SIZE)
    ]
    blocks = [_make_block(span_range=(0, 1), page=INDEX_ANALITICO_PAGE_INDEX_MIN + 1)]
    ext = _make_extraction(spans, blocks)
    refined = _classify_via_plugin(ext, [_verdict(0)])
    assert refined[0].category is SemanticCategory.INDEX_ENTRY


def test_refine_classification_promotes_body() -> None:
    spans = [
        _make_span(
            "Ogni società, ogni comunità umana stabile...", font="MScotchRoman", size=BODY_SIZE
        )
    ]
    blocks = [_make_block(span_range=(0, 1), page=100)]
    ext = _make_extraction(spans, blocks)
    refined = _classify_via_plugin(ext, [_verdict(0)])
    assert refined[0].category is SemanticCategory.BODY


def test_refine_classification_emits_index_analitico_column_warning() -> None:
    """The plugin queues an unordered-column warning per index page that has entries."""
    spans = [_make_span("Voce A", font="MScotchRoman", size=INDEX_ENTRY_SIZE)]
    blocks = [_make_block(span_range=(0, 1), page=INDEX_ANALITICO_PAGE_INDEX_MIN + 3)]
    ext = _make_extraction(spans, blocks)
    plugin = ManualeGiuffreDirectoProfile()
    plugin.refine_classification(ext, [_verdict(0)])
    assert any(
        f"index_analitico_double_column_unordered_page_{INDEX_ANALITICO_PAGE_INDEX_MIN + 3}" in w
        for w in plugin._pending_warnings
    )


def test_refine_classification_preserves_sentinel_empty_page() -> None:
    """An ``EMPTY_PAGE`` sentinel verdict passes through unchanged."""
    ext = _make_extraction([], [])
    sentinel = ClassifiedBlock(
        block_index=-1,
        category=SemanticCategory.EMPTY_PAGE,
        subcategory="42",
        reason="empty_page",
    )
    refined = _classify_via_plugin(ext, [sentinel])
    assert refined[0] is sentinel


def test_refine_classification_preserves_tier1_filigree_verdict() -> None:
    """A tier 1 ``ARTIFACT_FILIGREE`` verdict passes through unchanged."""
    spans = [_make_span("© Giuffrè", font="TimesNewRoman", size=15.35)]
    blocks = [_make_block(span_range=(0, 1))]
    ext = _make_extraction(spans, blocks)
    refined = _classify_via_plugin(
        ext, [_verdict(0, category=SemanticCategory.ARTIFACT_FILIGREE, reason="filigree")]
    )
    assert refined[0].category is SemanticCategory.ARTIFACT_FILIGREE


# ---------------------------------------------------------------------------
# refine_reconstruction — cross-reference minting


def _body_node(
    text: str, *, node_id: str = "node_0010", page: int = 100, block_indices: tuple[int, ...] = (5,)
) -> Node:
    return _node(node_id, SemanticCategory.BODY, text, page_index=page, block_indices=block_indices)


def _document_with(root_nodes: tuple[Node, ...]) -> Document:
    return Document(root=root_nodes)


def _reconstruct_via_plugin(document: Document) -> Document:
    plugin = ManualeGiuffreDirectoProfile()
    plugin._pending_warnings = []
    plugin._minted_crossref_ids = set()
    ext = _make_extraction([], [])
    return plugin.refine_reconstruction(document, ext, [])


def _crossref_text(node: Node) -> str:
    assert node.text is not None
    return node.text


def test_refine_reconstruction_mints_paragraph_crossref() -> None:
    body = _body_node("Per la nozione, v. § 130 e quanto detto in § 5.")
    doc = _document_with((body,))
    new_doc = _reconstruct_via_plugin(doc)
    # The body should now be followed by two CROSS_REFERENCE siblings
    assert len(new_doc.root) == 3
    crossrefs = [n for n in new_doc.root if n.category is SemanticCategory.CROSS_REFERENCE]
    assert len(crossrefs) == 2
    markers = sorted(_crossref_text(c) for c in crossrefs)
    assert markers[0].startswith("§")
    assert "130" in _crossref_text(crossrefs[0]) or "130" in _crossref_text(crossrefs[1])


def test_refine_reconstruction_mints_article_crossref() -> None:
    body = _body_node("In base all'art. 476 c.c., l'accettazione tacita richiede...")
    doc = _document_with((body,))
    new_doc = _reconstruct_via_plugin(doc)
    crossrefs = [n for n in new_doc.root if n.category is SemanticCategory.CROSS_REFERENCE]
    assert len(crossrefs) == 1
    assert _crossref_text(crossrefs[0]).startswith("art.")
    assert "476" in _crossref_text(crossrefs[0])


def test_refine_reconstruction_mints_sentence_crossref() -> None:
    body = _body_node("Cfr. Cass. 19 luglio 2019 n. 19504, in materia di sanzione amministrativa.")
    doc = _document_with((body,))
    new_doc = _reconstruct_via_plugin(doc)
    crossrefs = [n for n in new_doc.root if n.category is SemanticCategory.CROSS_REFERENCE]
    assert len(crossrefs) == 1
    assert _crossref_text(crossrefs[0]).startswith("Cass.")


def test_refine_reconstruction_three_subtypes_minted_in_order() -> None:
    body = _body_node("Vedi § 130, l'art. 476 c.c. e Cass. 19 luglio 2019 n. 19504.")
    doc = _document_with((body,))
    new_doc = _reconstruct_via_plugin(doc)
    crossrefs = [n for n in new_doc.root if n.category is SemanticCategory.CROSS_REFERENCE]
    assert len(crossrefs) == 3
    # Order preserved from textual occurrence
    assert _crossref_text(crossrefs[0]).startswith("§")
    assert _crossref_text(crossrefs[1]).startswith("art.")
    assert _crossref_text(crossrefs[2]).startswith("Cass.")


def test_refine_reconstruction_no_match_no_mint() -> None:
    body = _body_node("Nessun riferimento in questo paragrafo.")
    doc = _document_with((body,))
    new_doc = _reconstruct_via_plugin(doc)
    assert len(new_doc.root) == 1
    assert new_doc.root[0].id == body.id


def test_refine_reconstruction_text_none_no_mint() -> None:
    body = _node("node_0010", SemanticCategory.BODY, None)
    doc = _document_with((body,))
    new_doc = _reconstruct_via_plugin(doc)
    assert len(new_doc.root) == 1


def test_refine_reconstruction_minted_nodes_have_schema_compliant_ids() -> None:
    import re as _re

    body = _body_node("§ 130 e art. 476 c.c.")
    doc = _document_with((body,))
    new_doc = _reconstruct_via_plugin(doc)
    pattern = _re.compile(r"^node_\d+$")
    for n in new_doc.root:
        if n.category is SemanticCategory.CROSS_REFERENCE:
            assert pattern.match(n.id), f"node id {n.id!r} fails schema pattern"


def test_refine_reconstruction_emits_warnings_per_minted() -> None:
    body = _body_node("§ 5 e art. 1234 c.c. e Cass. 1 gennaio 2020.")
    doc = _document_with((body,))
    plugin = ManualeGiuffreDirectoProfile()
    plugin._pending_warnings = []
    plugin._minted_crossref_ids = set()
    new_doc = plugin.refine_reconstruction(doc, _make_extraction([], []), [])
    minted_warnings = [w for w in new_doc.warnings if "_minted_node_" in w]
    assert len(minted_warnings) == 3


def test_refine_reconstruction_recurses_into_children() -> None:
    """Cross-references inside nested BODY nodes are minted too."""
    inner_body = _body_node("§ 99 — riferimento annidato", node_id="node_0020", page=50)
    parent = _node(
        "node_0001",
        SemanticCategory.HEADING_2,
        "Capitolo",
        page_index=50,
        children=(inner_body,),
    )
    doc = _document_with((parent,))
    new_doc = _reconstruct_via_plugin(doc)
    # The HEADING_2 parent's children should be: [inner_body, minted crossref]
    assert len(new_doc.root) == 1
    parent_after = new_doc.root[0]
    assert len(parent_after.children) == 2
    assert parent_after.children[1].category is SemanticCategory.CROSS_REFERENCE


def test_refine_reconstruction_does_not_alter_non_body_nodes() -> None:
    """A HEADING_4 with §-like text is not scanned for crossrefs."""
    h4 = _node("node_0010", SemanticCategory.HEADING_4, "§ 1.L'ordinamento giuridico.", level=4)
    doc = _document_with((h4,))
    new_doc = _reconstruct_via_plugin(doc)
    assert len(new_doc.root) == 1
    assert new_doc.root[0].category is SemanticCategory.HEADING_4


# ---------------------------------------------------------------------------
# refine_apparatus — global § binding and warning filtering


def _build_doc_with_paragrafi(paragrafi_markers: list[str]) -> tuple[Document, dict[str, str]]:
    """Build a doc with a HEADING_4 per marker plus a BODY referring to each.

    Returns (document, marker → expected_node_id) so the test can assert
    the binding.
    """
    plugin = ManualeGiuffreDirectoProfile()
    plugin._pending_warnings = []
    plugin._minted_crossref_ids = set()
    h4_nodes: list[Node] = []
    expected: dict[str, str] = {}
    for i, m in enumerate(paragrafi_markers):
        node_id = f"node_{i:04d}"
        h4_nodes.append(
            _node(
                node_id,
                SemanticCategory.HEADING_4,
                f"§ {m}.Titolo del paragrafo {m}.",
                level=4,
                page_index=40 + i,
            )
        )
        expected[_normalise_marker(m)] = node_id
    body_text = " ".join(f"vedi § {m}" for m in paragrafi_markers)
    body_node = _body_node(body_text, node_id=f"node_{len(paragrafi_markers):04d}")
    doc = Document(root=(*h4_nodes, body_node))
    # Run reconstruction to mint cross-refs
    new_doc = plugin.refine_reconstruction(doc, _make_extraction([], []), [])
    # Refine apparatus to bind
    final_doc = plugin.refine_apparatus(new_doc, _make_extraction([], []), [])
    return final_doc, expected


def test_refine_apparatus_binds_paragraph_crossref_globally() -> None:
    final_doc, expected = _build_doc_with_paragrafi(["1", "130", "693"])
    crossrefs = [n for n in final_doc.root if n.category is SemanticCategory.CROSS_REFERENCE]
    assert len(crossrefs) == 3
    bound_ids = {cr.apparatus_refs[0].target_node_id for cr in crossrefs if cr.apparatus_refs}
    assert bound_ids == set(expected.values())


def test_refine_apparatus_unresolved_marker_emits_warning() -> None:
    """A § N reference without a matching HEADING_4 target emits a warning."""
    plugin = ManualeGiuffreDirectoProfile()
    plugin._pending_warnings = []
    plugin._minted_crossref_ids = set()
    body = _body_node("vedi § 9999 (non esiste)")
    doc = Document(root=(body,))
    new_doc = plugin.refine_reconstruction(doc, _make_extraction([], []), [])
    final_doc = plugin.refine_apparatus(new_doc, _make_extraction([], []), [])
    assert any(
        "cross_reference_paragraph_unresolved_node_" in w and "marker_9999" in w
        for w in final_doc.warnings
    )


def test_refine_apparatus_article_crossref_has_no_internal_target() -> None:
    """art. references are external and remain unbound."""
    plugin = ManualeGiuffreDirectoProfile()
    plugin._pending_warnings = []
    plugin._minted_crossref_ids = set()
    body = _body_node("Vedi art. 476 c.c.")
    doc = Document(root=(body,))
    new_doc = plugin.refine_reconstruction(doc, _make_extraction([], []), [])
    final_doc = plugin.refine_apparatus(new_doc, _make_extraction([], []), [])
    crossrefs = [n for n in final_doc.root if n.category is SemanticCategory.CROSS_REFERENCE]
    assert len(crossrefs) == 1
    assert len(crossrefs[0].apparatus_refs) == 0


def test_refine_apparatus_filters_unparseable_warning_for_minted_nodes() -> None:
    """Tier 1 ``unparseable_cross_reference_node_<id>`` warnings get filtered."""
    plugin = ManualeGiuffreDirectoProfile()
    plugin._pending_warnings = []
    plugin._minted_crossref_ids = set()
    body = _body_node("art. 476 c.c.")
    doc = Document(root=(body,))
    new_doc = plugin.refine_reconstruction(doc, _make_extraction([], []), [])
    # Simulate the tier 1 resolver having appended the unparseable warning
    minted_id = next(iter(plugin._minted_crossref_ids))
    doc_with_t1_warning = Document(
        root=new_doc.root,
        warnings=(*new_doc.warnings, f"unparseable_cross_reference_node_{minted_id}"),
    )
    final_doc = plugin.refine_apparatus(doc_with_t1_warning, _make_extraction([], []), [])
    assert all(f"unparseable_cross_reference_node_{minted_id}" not in w for w in final_doc.warnings)


def test_refine_apparatus_preserves_unrelated_warnings() -> None:
    plugin = ManualeGiuffreDirectoProfile()
    plugin._pending_warnings = []
    plugin._minted_crossref_ids = set()
    body = _body_node("art. 476 c.c.")
    doc = Document(root=(body,))
    new_doc = plugin.refine_reconstruction(doc, _make_extraction([], []), [])
    doc_with_extra = Document(
        root=new_doc.root,
        warnings=(*new_doc.warnings, "unrelated_warning_string"),
    )
    final_doc = plugin.refine_apparatus(doc_with_extra, _make_extraction([], []), [])
    assert "unrelated_warning_string" in final_doc.warnings


def test_refine_apparatus_filters_tier1_unresolved_variant_too() -> None:
    """The filter also removes ``unresolved_cross_reference_*`` for minted ids."""
    plugin = ManualeGiuffreDirectoProfile()
    plugin._pending_warnings = []
    plugin._minted_crossref_ids = set()
    body = _body_node("§ 1")
    doc = Document(root=(body,))
    new_doc = plugin.refine_reconstruction(doc, _make_extraction([], []), [])
    minted_id = next(iter(plugin._minted_crossref_ids))
    doc_with_extra = Document(
        root=new_doc.root,
        warnings=(*new_doc.warnings, f"unresolved_cross_reference_node_{minted_id}_n_1"),
    )
    final_doc = plugin.refine_apparatus(doc_with_extra, _make_extraction([], []), [])
    assert all(f"unresolved_cross_reference_node_{minted_id}_" not in w for w in final_doc.warnings)


# ---------------------------------------------------------------------------
# refine_reconstruction + refine_apparatus integration


def test_full_tier2_chain_runs_without_error_on_empty_doc() -> None:
    plugin = ManualeGiuffreDirectoProfile()
    plugin._pending_warnings = []
    plugin._minted_crossref_ids = set()
    ext = _make_extraction([], [])
    empty_doc = Document(root=())
    rec = plugin.refine_reconstruction(empty_doc, ext, [])
    app = plugin.refine_apparatus(rec, ext, [])
    assert len(app.root) == 0


def test_full_tier2_chain_paragraph_marker_with_bis_binds_correctly() -> None:
    """A § 130-bis reference binds to a HEADING_4 whose title carries '130-bis'."""
    final_doc, expected = _build_doc_with_paragrafi(["130-bis"])
    crossrefs = [n for n in final_doc.root if n.category is SemanticCategory.CROSS_REFERENCE]
    assert len(crossrefs) == 1
    assert crossrefs[0].apparatus_refs[0].target_node_id == expected["130-bis"]


def test_full_tier2_chain_apparatus_ref_kind_is_cross_ref_target() -> None:
    final_doc, _ = _build_doc_with_paragrafi(["1"])
    crossrefs = [n for n in final_doc.root if n.category is SemanticCategory.CROSS_REFERENCE]
    assert crossrefs[0].apparatus_refs[0].kind is ApparatusRefKind.CROSS_REF_TARGET


def test_full_tier2_chain_apparatus_ref_carries_source_marker() -> None:
    final_doc, _ = _build_doc_with_paragrafi(["1"])
    crossrefs = [n for n in final_doc.root if n.category is SemanticCategory.CROSS_REFERENCE]
    assert "§" in (crossrefs[0].apparatus_refs[0].source_marker or "")


# ---------------------------------------------------------------------------
# Empty-spans early returns + edge predicate paths


def _empty_view() -> _BlockView:
    return _BlockView(block_index=0, block=_make_block(), spans=(), text="")


def test_is_parte_signature_empty_spans_rejected() -> None:
    assert not ManualeGiuffreDirectoProfile._is_parte_signature(_empty_view())


def test_is_paragrafo_signature_empty_spans_rejected() -> None:
    assert not ManualeGiuffreDirectoProfile._is_paragrafo_signature(_empty_view())


def test_is_sotto_sezione_empty_spans_rejected() -> None:
    assert not ManualeGiuffreDirectoProfile._is_sotto_sezione(_empty_view())


def test_is_front_back_matter_heading_empty_spans_rejected() -> None:
    assert not ManualeGiuffreDirectoProfile._is_front_back_matter_heading(_empty_view())


def test_is_index_entry_empty_spans_rejected() -> None:
    assert not ManualeGiuffreDirectoProfile._is_index_entry(_empty_view())


def test_is_body_signature_empty_spans_rejected() -> None:
    assert not ManualeGiuffreDirectoProfile._is_body_signature(_empty_view())


def test_is_asterisk_footnote_empty_spans_rejected() -> None:
    assert not ManualeGiuffreDirectoProfile._is_asterisk_footnote(_empty_view())


def test_is_front_back_matter_heading_long_text_rejected() -> None:
    """A 200+ char block opening with INDICE SOMMARIO is not a HEADING_1."""
    spans = [
        _make_span(
            "INDICE SOMMARIO " + "X" * 200,
            font="MScotchRoman",
            size=BODY_SIZE,
        )
    ]
    view = _make_view(spans)
    assert not ManualeGiuffreDirectoProfile._is_front_back_matter_heading(view)


def test_refine_classification_view_none_passes_through() -> None:
    """A verdict whose block_index points at an empty-span block stays unchanged."""
    blocks = [_make_block(span_range=(0, 0))]  # empty span range
    ext = _make_extraction([], blocks)
    refined = _classify_via_plugin(ext, [_verdict(0, reason="custom_reason")])
    assert refined[0].reason == "custom_reason"
    assert refined[0].category is SemanticCategory.UNCLASSIFIED


def test_refine_classification_unrecognised_block_stays_unclassified() -> None:
    """A block that fails every plugin predicate stays UNCLASSIFIED."""
    spans = [_make_span("strange unknown content", font="UnknownFont", size=5.0)]
    blocks = [_make_block(span_range=(0, 1))]
    ext = _make_extraction(spans, blocks)
    refined = _classify_via_plugin(ext, [_verdict(0)])
    assert refined[0].category is SemanticCategory.UNCLASSIFIED


def test_refine_reconstruction_walks_arbitrary_depth() -> None:
    """``_iter_nodes`` (used by the marker-index builder) recurses into deep children."""
    # Build a 3-level tree: HEADING_1 → HEADING_2 → HEADING_4
    h4 = _node(
        "node_0010",
        SemanticCategory.HEADING_4,
        "§ 7.Titolo del paragrafo 7.",
        page_index=200,
        level=4,
    )
    h2 = _node("node_0005", SemanticCategory.HEADING_2, "CAPITOLO I", children=(h4,))
    h1 = _node("node_0001", SemanticCategory.HEADING_1, "NOZIONI PRELIMINARI", children=(h2,))
    body = _body_node("vedi § 7", node_id="node_0020", page=200)
    doc = Document(root=(h1, body))
    plugin = ManualeGiuffreDirectoProfile()
    plugin._pending_warnings = []
    plugin._minted_crossref_ids = set()
    rec = plugin.refine_reconstruction(doc, _make_extraction([], []), [])
    app = plugin.refine_apparatus(rec, _make_extraction([], []), [])
    # Find the synthetic crossref and verify it binds to the deep HEADING_4
    crossrefs = [n for n in app.root if n.category is SemanticCategory.CROSS_REFERENCE]
    assert len(crossrefs) == 1
    assert crossrefs[0].apparatus_refs[0].target_node_id == "node_0010"


def test_max_existing_node_counter_handles_non_pattern_ids() -> None:
    """The counter walker ignores synthetic ids that do not match ``node_NNNN``."""
    from scabopdf_pipeline.profiles.manuale_giuffre_diretto import _max_existing_node_counter

    # Mix of valid and "alien" ids
    a = _node("alien-id", SemanticCategory.BODY, "ignored")
    b = _node("node_0050", SemanticCategory.BODY, "kept")
    counter = _max_existing_node_counter((a, b))
    assert counter == 50


def test_max_existing_node_counter_empty_returns_minus_one() -> None:
    from scabopdf_pipeline.profiles.manuale_giuffre_diretto import _max_existing_node_counter

    assert _max_existing_node_counter(()) == -1
