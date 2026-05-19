# ruff: noqa: RUF001
"""Unit tests for the giuffre_codici corpus plugin (Codici d'udienza Giuffrè)."""

from __future__ import annotations

import pytest

from scabopdf_pipeline.apparatus.types import ApparatusRef, ApparatusRefKind
from scabopdf_pipeline.classification.types import ClassifiedBlock
from scabopdf_pipeline.extraction.types import Block, ExtractionResult, Span
from scabopdf_pipeline.profiles.giuffre_codici import (
    ARTICLE_NUMBER_SIZE,
    BANNER_MARKER_NAME,
    BANNER_SIZE,
    BODY_APEX_SIZE,
    BODY_SIZE,
    COMMA_MARKER_SIZE,
    FOOTER_SIZE,
    NOTE_SIZE,
    PAGE_GEOMETRY_HEIGHT,
    PAGE_GEOMETRY_WIDTH,
    WARNING_PREFIX,
    CodeType,
    GiuffreCodiciProfile,
    _BlockView,
    _code_type_from_banner_text,
    _max_existing_node_counter,
    _NodeIdMinter,
    _warning_safe,
)
from scabopdf_pipeline.profiling.profile import DisabledLayout
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

ITALIC_FLAG = 0x02
SERIF_FLAG = 0x04
BOLD_FLAG = 0x10
BOLD_ITALIC_FLAGS = BOLD_FLAG | ITALIC_FLAG
SUPERSCRIPT_FLAG = 0x01


# ---------------------------------------------------------------------------
# Helpers


def _codici_signals(
    *,
    body_size: float = BODY_SIZE,
    body_dominance: float = 62.0,
    body_family: str = "PalatinoLinotype-Roman",
    banner_text: str | None = "CODICE PENALE",
    include_banner_marker: bool = True,
    footnote_markers: int = 100,
    producer: str = "PDFsharp 1.31.1789-g (www.pdfsharp.com)",
    creator: str = "PDFsharp 1.31.1789-g (www.pdfsharp.com)",
    width_pt: float = PAGE_GEOMETRY_WIDTH,
    height_pt: float = PAGE_GEOMETRY_HEIGHT,
) -> ProfilingSignals:
    """Build canonical codici signals; tweak with kwargs for per-test cases."""
    fonts = [FontDominance(family=body_family, size=body_size, dominance_percent=body_dominance)]
    specific_markers: list[SpecificMarker] = []
    if include_banner_marker:
        specific_markers.append(
            SpecificMarker(
                name=BANNER_MARKER_NAME,
                present=banner_text is not None,
                value=banner_text,
            )
        )
    return ProfilingSignals(
        typographic_signature=TypographicSignature(fonts=fonts),
        apparatus_presence=ApparatusPresence(footnote_markers=footnote_markers),
        page_geometry=ProfilePageGeometry(width_pt=width_pt, height_pt=height_pt),
        producer_creator=ProducerCreator(producer=producer, creator=creator),
        outline_structure=OutlineStructure(),
        specific_markers=specific_markers,
    )


def _make_span(
    text: str,
    *,
    font: str = "PalatinoLinotype-Roman",
    size: float = BODY_SIZE,
    flags: int = SERIF_FLAG,
    page: int = 100,
    bbox: tuple[float, float, float, float] = (31.0, 100.0, 170.0, 115.0),
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
    bbox: tuple[float, float, float, float] = (31.0, 100.0, 170.0, 400.0),
    span_range: tuple[int, int] = (0, 1),
    block_index: int = 0,
) -> Block:
    return Block(page=page, block_index=block_index, bbox=bbox, span_range=span_range)


def _make_view(
    spans: list[Span],
    *,
    page: int = 100,
    bbox: tuple[float, float, float, float] = (31.0, 100.0, 170.0, 400.0),
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
    apparatus_refs: tuple[ApparatusRef, ...] = (),
) -> Node:
    return Node(
        id=node_id,
        category=category,
        page_index=page_index,
        block_indices=block_indices,
        text=text,
        children=children,
        apparatus_refs=apparatus_refs,
    )


# ---------------------------------------------------------------------------
# Class attributes


def test_class_attributes() -> None:
    assert GiuffreCodiciProfile.profile_id == "giuffre_codici"
    assert GiuffreCodiciProfile.editorial_family == "giuffre_codici"
    assert GiuffreCodiciProfile.genre == "codice"


def test_code_type_enum_has_three_values() -> None:
    assert {member.value for member in CodeType} == {"PENALE", "CIVILE", "UNKNOWN"}


# ---------------------------------------------------------------------------
# _code_type_from_banner_text


def test_code_type_from_banner_text_none_returns_unknown() -> None:
    assert _code_type_from_banner_text(None) is CodeType.UNKNOWN


def test_code_type_from_banner_text_penale() -> None:
    assert _code_type_from_banner_text("CODICE PENALE") is CodeType.PENALE


def test_code_type_from_banner_text_procedura_penale() -> None:
    assert _code_type_from_banner_text("CODICE DI PROCEDURA PENALE") is CodeType.PENALE


def test_code_type_from_banner_text_civile() -> None:
    assert _code_type_from_banner_text("CODICE CIVILE") is CodeType.CIVILE


def test_code_type_from_banner_text_procedura_civile() -> None:
    assert _code_type_from_banner_text("PROCEDURA CIVILE") is CodeType.CIVILE


def test_code_type_from_banner_text_leggi_returns_unknown() -> None:
    """LEGGI alone does not pin the code type."""
    assert _code_type_from_banner_text("LEGGI") is CodeType.UNKNOWN


def test_code_type_from_banner_text_lowercase_normalised() -> None:
    """The mapper is case-insensitive."""
    assert _code_type_from_banner_text("codice penale") is CodeType.PENALE
    assert _code_type_from_banner_text("codice civile") is CodeType.CIVILE


def test_code_type_from_banner_text_empty_string_returns_unknown() -> None:
    assert _code_type_from_banner_text("") is CodeType.UNKNOWN


def test_code_type_from_banner_text_unknown_returns_unknown() -> None:
    assert _code_type_from_banner_text("XYZ") is CodeType.UNKNOWN


# ---------------------------------------------------------------------------
# _NodeIdMinter and _max_existing_node_counter


def test_node_id_minter_starts_at_zero() -> None:
    minter = _NodeIdMinter(start=0)
    assert minter.mint() == "node_0000"
    assert minter.mint() == "node_0001"


def test_node_id_minter_zero_pads_to_four_digits() -> None:
    minter = _NodeIdMinter(start=42)
    assert minter.mint() == "node_0042"


def test_node_id_minter_handles_large_counters() -> None:
    minter = _NodeIdMinter(start=9999)
    assert minter.mint() == "node_9999"
    assert minter.mint() == "node_10000"


def test_max_existing_node_counter_empty_forest_returns_minus_one() -> None:
    assert _max_existing_node_counter(()) == -1


def test_max_existing_node_counter_single_node() -> None:
    root = _node("node_0042", SemanticCategory.BODY, "x")
    assert _max_existing_node_counter((root,)) == 42


def test_max_existing_node_counter_walks_children() -> None:
    child = _node("node_0042", SemanticCategory.BODY, "x")
    parent = _node("node_0003", SemanticCategory.HEADING_1, None, children=(child,))
    assert _max_existing_node_counter((parent,)) == 42


def test_max_existing_node_counter_ignores_unparseable_ids() -> None:
    root = _node("not_a_node_id", SemanticCategory.BODY, "x")
    assert _max_existing_node_counter((root,)) == -1


# ---------------------------------------------------------------------------
# _warning_safe


def test_warning_safe_alphanumerics_pass_through() -> None:
    assert _warning_safe("309") == "309"
    assert _warning_safe("309-bis") == "309-bis"


def test_warning_safe_special_chars_become_underscores() -> None:
    assert _warning_safe("[10², 13, 29 Cost.]") == "_10_13_29_Cost_"


def test_warning_safe_truncates_long_text() -> None:
    text = "a" * 100
    result = _warning_safe(text)
    assert len(result) == 40


# ---------------------------------------------------------------------------
# matches() — score combinations


def test_matches_penale_banner_clears_threshold() -> None:
    """Full penale fingerprint with PENALE banner scores well above 0.6."""
    score = GiuffreCodiciProfile.matches(_codici_signals(banner_text="CODICE PENALE"))
    # 0.50 (PENALE banner) + 0.20 (body) + 0.15 (geometry) + 0.05 (PDFsharp) + 0.10 (footnotes)
    assert score == pytest.approx(1.00)
    assert score >= 0.6


def test_matches_civile_banner_clears_threshold() -> None:
    """Full civile fingerprint with CIVILE banner scores well above 0.6."""
    score = GiuffreCodiciProfile.matches(_codici_signals(banner_text="CODICE CIVILE"))
    assert score == pytest.approx(1.00)
    assert score >= 0.6


def test_matches_procedura_penale_banner_clears_threshold() -> None:
    score = GiuffreCodiciProfile.matches(_codici_signals(banner_text="CODICE DI PROCEDURA PENALE"))
    assert score >= 0.6


def test_matches_leggi_banner_partial_score() -> None:
    """LEGGI banner alone (no PENALE/CIVILE) credits 0.40 instead of 0.50."""
    score = GiuffreCodiciProfile.matches(_codici_signals(banner_text="LEGGI"))
    # 0.40 (LEGGI) + 0.20 + 0.15 + 0.05 + 0.10 = 0.90
    assert score == pytest.approx(0.90)


def test_matches_no_banner_marker_still_clears_threshold() -> None:
    """Without the banner marker, body+geometry+producer+footnotes barely clears."""
    score = GiuffreCodiciProfile.matches(_codici_signals(include_banner_marker=False))
    # 0.20 + 0.15 + 0.05 + 0.10 = 0.50 — below threshold
    assert score == pytest.approx(0.50)


def test_matches_wrong_body_family_penalises() -> None:
    """Times-New-Roman body cannot be a codici document."""
    score = GiuffreCodiciProfile.matches(
        _codici_signals(
            body_family="Times-New-Roman",
            banner_text=None,
            include_banner_marker=False,
        )
    )
    # -0.30 (body penalty) + 0.15 + 0.05 + 0.10 = 0.00 (clamped)
    assert score == pytest.approx(0.00)


def test_matches_wrong_geometry_no_geometry_bonus() -> None:
    score = GiuffreCodiciProfile.matches(
        _codici_signals(
            width_pt=595.0, height_pt=842.0, banner_text=None, include_banner_marker=False
        )
    )
    # 0.20 + 0.05 + 0.10 = 0.35
    assert score == pytest.approx(0.35)


def test_matches_low_body_dominance_penalises() -> None:
    """Below the 30% floor the body signal does not credit."""
    score = GiuffreCodiciProfile.matches(
        _codici_signals(body_dominance=20.0, banner_text=None, include_banner_marker=False)
    )
    # -0.30 + 0.15 + 0.05 + 0.10 = 0.00 (clamped)
    assert score == pytest.approx(0.00)


def test_matches_no_pdfsharp_producer() -> None:
    score = GiuffreCodiciProfile.matches(
        _codici_signals(
            banner_text="CODICE PENALE",
            producer="Acrobat",
            creator="Acrobat",
        )
    )
    # 0.50 + 0.20 + 0.15 + 0.10 = 0.95
    assert score == pytest.approx(0.95)


def test_matches_no_footnote_apparatus() -> None:
    score = GiuffreCodiciProfile.matches(
        _codici_signals(banner_text="CODICE PENALE", footnote_markers=0)
    )
    # 0.50 + 0.20 + 0.15 + 0.05 = 0.90
    assert score == pytest.approx(0.90)


def test_matches_on_patriarca_like_signals_well_below_threshold() -> None:
    """Times-New-Roman + A4 geometry + no banner stays well below 0.6."""
    signals = ProfilingSignals(
        typographic_signature=TypographicSignature(
            fonts=[FontDominance(family="Times New Roman", size=11.0, dominance_percent=80.0)]
        ),
        apparatus_presence=ApparatusPresence(),
        page_geometry=ProfilePageGeometry(width_pt=595.0, height_pt=842.0),
        producer_creator=ProducerCreator(producer="Acrobat", creator="Zanichelli"),
        outline_structure=OutlineStructure(),
    )
    score = GiuffreCodiciProfile.matches(signals)
    # -0.30 (penalty) + 0 + 0 + 0 = -0.30 → 0.00
    assert score == pytest.approx(0.00)


def test_matches_on_torrente_like_signals_well_below_threshold() -> None:
    """MScotchRoman body + 481.9 width + no banner stays below 0.6."""
    signals = ProfilingSignals(
        typographic_signature=TypographicSignature(
            fonts=[FontDominance(family="MScotchRoman", size=11.47, dominance_percent=62.0)]
        ),
        apparatus_presence=ApparatusPresence(footnote_markers=0),
        page_geometry=ProfilePageGeometry(width_pt=481.9, height_pt=680.3),
        producer_creator=ProducerCreator(
            producer="PDFsharp 1.31.1789-g (www.pdfsharp.com)",
            creator="PDFsharp 1.31.1789-g (www.pdfsharp.com)",
        ),
        outline_structure=OutlineStructure(),
    )
    score = GiuffreCodiciProfile.matches(signals)
    # -0.30 (penalty: MScotchRoman != PalatinoLinotype) + 0 + 0.05 = -0.25 → 0.00
    assert score == pytest.approx(0.00)


def test_matches_banner_marker_value_none_skips_banner_score() -> None:
    """A SpecificMarker present=False or with value=None falls back to no banner."""
    signals = ProfilingSignals(
        typographic_signature=TypographicSignature(
            fonts=[
                FontDominance(
                    family="PalatinoLinotype-Roman", size=BODY_SIZE, dominance_percent=62.0
                )
            ]
        ),
        apparatus_presence=ApparatusPresence(footnote_markers=100),
        page_geometry=ProfilePageGeometry(
            width_pt=PAGE_GEOMETRY_WIDTH, height_pt=PAGE_GEOMETRY_HEIGHT
        ),
        producer_creator=ProducerCreator(producer="PDFsharp", creator="PDFsharp"),
        outline_structure=OutlineStructure(),
        specific_markers=[SpecificMarker(name=BANNER_MARKER_NAME, present=False, value=None)],
    )
    score = GiuffreCodiciProfile.matches(signals)
    # 0.20 + 0.15 + 0.05 + 0.10 = 0.50 (no banner contribution)
    assert score == pytest.approx(0.50)


def test_matches_banner_marker_non_string_value_ignored() -> None:
    signals = ProfilingSignals(
        typographic_signature=TypographicSignature(
            fonts=[
                FontDominance(
                    family="PalatinoLinotype-Roman", size=BODY_SIZE, dominance_percent=62.0
                )
            ]
        ),
        apparatus_presence=ApparatusPresence(footnote_markers=100),
        page_geometry=ProfilePageGeometry(
            width_pt=PAGE_GEOMETRY_WIDTH, height_pt=PAGE_GEOMETRY_HEIGHT
        ),
        producer_creator=ProducerCreator(producer="PDFsharp", creator="PDFsharp"),
        outline_structure=OutlineStructure(),
        specific_markers=[SpecificMarker(name=BANNER_MARKER_NAME, present=True, value=42)],
    )
    score = GiuffreCodiciProfile.matches(signals)
    # 0.20 + 0.15 + 0.05 + 0.10 = 0.50 (non-string value treated as None)
    assert score == pytest.approx(0.50)


def test_matches_unknown_specific_marker_ignored() -> None:
    """Markers with names other than the banner marker are ignored."""
    signals = ProfilingSignals(
        typographic_signature=TypographicSignature(
            fonts=[
                FontDominance(
                    family="PalatinoLinotype-Roman", size=BODY_SIZE, dominance_percent=62.0
                )
            ]
        ),
        apparatus_presence=ApparatusPresence(footnote_markers=100),
        page_geometry=ProfilePageGeometry(
            width_pt=PAGE_GEOMETRY_WIDTH, height_pt=PAGE_GEOMETRY_HEIGHT
        ),
        producer_creator=ProducerCreator(producer="PDFsharp", creator="PDFsharp"),
        outline_structure=OutlineStructure(),
        specific_markers=[SpecificMarker(name="other_marker", present=True, value="X")],
    )
    score = GiuffreCodiciProfile.matches(signals)
    assert score == pytest.approx(0.50)


# ---------------------------------------------------------------------------
# Declarative methods


def test_get_categories_includes_codici_vocabulary() -> None:
    plugin = GiuffreCodiciProfile()
    categories = plugin.get_categories()
    assert SemanticCategory.ARTICLE_HEADER in categories
    assert SemanticCategory.ARTICLE_BODY in categories
    assert SemanticCategory.PROCEDURAL in categories
    assert SemanticCategory.HEADING_1 in categories
    assert SemanticCategory.HEADING_4 in categories
    assert SemanticCategory.NOTE in categories
    assert SemanticCategory.CROSS_REFERENCE in categories


def test_get_post_processing_declares_dehyphenate() -> None:
    plugin = GiuffreCodiciProfile()
    assert plugin.get_post_processing() == ["dehyphenate_with_log"]


def test_get_layouts_disabled_includes_l3() -> None:
    plugin = GiuffreCodiciProfile()
    layouts = plugin.get_layouts_disabled()
    assert len(layouts) == 1
    assert isinstance(layouts[0], DisabledLayout)
    assert layouts[0].layout == "L3"
    assert "Codici" in layouts[0].reason or "codice" in layouts[0].reason.lower()


# ---------------------------------------------------------------------------
# Signature predicates


def test_is_banner_glyph_detects_BD700x300() -> None:
    span = _make_span("CODICE PENALE", font="BD700x300", size=BANNER_SIZE)
    view = _make_view([span])
    assert GiuffreCodiciProfile._is_banner_glyph(view) is True


def test_is_banner_glyph_rejects_other_fonts() -> None:
    span = _make_span("Some text", font="PalatinoLinotype-Roman")
    view = _make_view([span])
    assert GiuffreCodiciProfile._is_banner_glyph(view) is False


def test_is_banner_glyph_empty_spans_returns_false() -> None:
    view = _make_view([])
    assert GiuffreCodiciProfile._is_banner_glyph(view) is False


def test_is_procedural_block_detects_competenza() -> None:
    span = _make_span(
        "competenza: Trib. monocratico", font="MyriadPro-It", size=NOTE_SIZE, flags=ITALIC_FLAG
    )
    view = _make_view([span])
    assert GiuffreCodiciProfile._is_procedural_block(view) is True


def test_is_procedural_block_rejects_note_without_competenza() -> None:
    span = _make_span("(1) V. art. 8.", font="MyriadPro-Regular", size=NOTE_SIZE)
    view = _make_view([span])
    assert GiuffreCodiciProfile._is_procedural_block(view) is False


def test_is_procedural_block_rejects_body_size() -> None:
    span = _make_span("competenza: Trib.", font="MyriadPro-It", size=BODY_SIZE)
    view = _make_view([span])
    assert GiuffreCodiciProfile._is_procedural_block(view) is False


def test_is_note_block_detects_note_size() -> None:
    span = _make_span("(1) V. art.", font="MyriadPro-Regular", size=NOTE_SIZE)
    view = _make_view([span])
    assert GiuffreCodiciProfile._is_note_block(view) is True


def test_is_note_block_rejects_palatino() -> None:
    span = _make_span("(1) V. art.", font="PalatinoLinotype-Roman", size=NOTE_SIZE)
    view = _make_view([span])
    assert GiuffreCodiciProfile._is_note_block(view) is False


def test_is_hierarchy_heading_detects_libro() -> None:
    span = _make_span("LIBRO PRIMO DEI REATI", font="PalatinoLinotype-Bold", flags=BOLD_FLAG)
    view = _make_view([span])
    assert GiuffreCodiciProfile._is_hierarchy_heading(view) is True


def test_is_hierarchy_heading_detects_titolo() -> None:
    span = _make_span("TITOLO I DELLA PENA", font="PalatinoLinotype-Bold", flags=BOLD_FLAG)
    view = _make_view([span])
    assert GiuffreCodiciProfile._is_hierarchy_heading(view) is True


def test_is_hierarchy_heading_detects_capo() -> None:
    span = _make_span("CAPO I DISPOSIZIONI", font="PalatinoLinotype-Bold", flags=BOLD_FLAG)
    view = _make_view([span])
    assert GiuffreCodiciProfile._is_hierarchy_heading(view) is True


def test_is_hierarchy_heading_detects_sezione() -> None:
    span = _make_span("SEZIONE I LE CAMERE", font="PalatinoLinotype-Bold", flags=BOLD_FLAG)
    view = _make_view([span])
    assert GiuffreCodiciProfile._is_hierarchy_heading(view) is True


def test_is_hierarchy_heading_rejects_article_header() -> None:
    span = _make_span("309. Disposizioni", font="PalatinoLinotype-Bold", flags=BOLD_FLAG)
    view = _make_view([span])
    assert GiuffreCodiciProfile._is_hierarchy_heading(view) is False


def test_is_hierarchy_heading_requires_bold() -> None:
    span = _make_span("LIBRO PRIMO", font="PalatinoLinotype-Roman", flags=SERIF_FLAG)
    view = _make_view([span])
    assert GiuffreCodiciProfile._is_hierarchy_heading(view) is False


def test_hierarchy_level_libro_is_one() -> None:
    span = _make_span("LIBRO PRIMO", font="PalatinoLinotype-Bold", flags=BOLD_FLAG)
    view = _make_view([span])
    assert GiuffreCodiciProfile._hierarchy_level(view) == 1


def test_hierarchy_level_parte_is_one() -> None:
    span = _make_span("PARTE PRIMA", font="PalatinoLinotype-Bold", flags=BOLD_FLAG)
    view = _make_view([span])
    assert GiuffreCodiciProfile._hierarchy_level(view) == 1


def test_hierarchy_level_titolo_is_two() -> None:
    span = _make_span("TITOLO I", font="PalatinoLinotype-Bold", flags=BOLD_FLAG)
    view = _make_view([span])
    assert GiuffreCodiciProfile._hierarchy_level(view) == 2


def test_hierarchy_level_capo_is_three() -> None:
    span = _make_span("CAPO I", font="PalatinoLinotype-Bold", flags=BOLD_FLAG)
    view = _make_view([span])
    assert GiuffreCodiciProfile._hierarchy_level(view) == 3


def test_hierarchy_level_sezione_is_four() -> None:
    span = _make_span("SEZIONE I", font="PalatinoLinotype-Bold", flags=BOLD_FLAG)
    view = _make_view([span])
    assert GiuffreCodiciProfile._hierarchy_level(view) == 4


def test_hierarchy_level_unknown_keyword_defaults_to_one() -> None:
    """Defensive default for any future keyword."""
    span = _make_span("STRANO XYZ", font="PalatinoLinotype-Bold", flags=BOLD_FLAG)
    view = _make_view([span])
    assert GiuffreCodiciProfile._hierarchy_level(view) == 1


def test_is_article_header_detects_pure_number_trigger() -> None:
    span = _make_span(
        "309", font="PalatinoLinotype-Bold", size=ARTICLE_NUMBER_SIZE, flags=BOLD_FLAG
    )
    view = _make_view([span])
    assert GiuffreCodiciProfile._is_article_header(view) is True


def test_is_article_header_detects_with_trailing_dot() -> None:
    span = _make_span(
        "309.", font="PalatinoLinotype-Bold", size=ARTICLE_NUMBER_SIZE, flags=BOLD_FLAG
    )
    view = _make_view([span])
    assert GiuffreCodiciProfile._is_article_header(view) is True


def test_is_article_header_detects_bis_suffix() -> None:
    span = _make_span(
        "309-bis", font="PalatinoLinotype-Bold", size=ARTICLE_NUMBER_SIZE, flags=BOLD_FLAG
    )
    view = _make_view([span])
    assert GiuffreCodiciProfile._is_article_header(view) is True


def test_is_article_header_rejects_text() -> None:
    span = _make_span(
        "Some text", font="PalatinoLinotype-Bold", size=ARTICLE_NUMBER_SIZE, flags=BOLD_FLAG
    )
    view = _make_view([span])
    assert GiuffreCodiciProfile._is_article_header(view) is False


def test_is_article_header_requires_bold() -> None:
    span = _make_span(
        "309", font="PalatinoLinotype-Roman", size=ARTICLE_NUMBER_SIZE, flags=SERIF_FLAG
    )
    view = _make_view([span])
    assert GiuffreCodiciProfile._is_article_header(view) is False


def test_is_article_header_requires_correct_size() -> None:
    span = _make_span("309", font="PalatinoLinotype-Bold", size=BODY_SIZE, flags=BOLD_FLAG)
    view = _make_view([span])
    assert GiuffreCodiciProfile._is_article_header(view) is False


def test_is_abrogated_inline_detects_rubric() -> None:
    spans = [
        _make_span("141", font="PalatinoLinotype-Bold", size=ARTICLE_NUMBER_SIZE, flags=BOLD_FLAG),
        _make_span(". [Delitti contro i culti ammessi nello Stato]."),
    ]
    view = _make_view(spans)
    assert GiuffreCodiciProfile._is_abrogated_inline(view) is True


def test_is_abrogated_inline_rejects_normal_article() -> None:
    spans = [
        _make_span("142", font="PalatinoLinotype-Bold", size=ARTICLE_NUMBER_SIZE, flags=BOLD_FLAG),
        _make_span(". Disposizioni in materia di reati"),
    ]
    view = _make_view(spans)
    assert GiuffreCodiciProfile._is_abrogated_inline(view) is False


def test_is_range_abrogated_detects_civile_range() -> None:
    span = _make_span(
        "152-153", font="PalatinoLinotype-Bold", size=ARTICLE_NUMBER_SIZE, flags=BOLD_FLAG
    )
    extra = _make_span(". (1).")
    view = _make_view([span, extra])
    assert GiuffreCodiciProfile._is_range_abrogated(view) is True


def test_is_range_abrogated_detects_en_dash() -> None:
    """The pattern admits both ASCII hyphen and Unicode en-dash."""
    span = _make_span(
        "152–153", font="PalatinoLinotype-Bold", size=ARTICLE_NUMBER_SIZE, flags=BOLD_FLAG
    )
    extra = _make_span(". (1).")
    view = _make_view([span, extra])
    assert GiuffreCodiciProfile._is_range_abrogated(view) is True


def test_is_range_abrogated_rejects_single_number() -> None:
    span = _make_span(
        "152", font="PalatinoLinotype-Bold", size=ARTICLE_NUMBER_SIZE, flags=BOLD_FLAG
    )
    extra = _make_span(". Disposizione")
    view = _make_view([span, extra])
    assert GiuffreCodiciProfile._is_range_abrogated(view) is False


def test_is_range_abrogated_requires_article_size() -> None:
    span = _make_span("152-153", font="PalatinoLinotype-Bold", size=BODY_SIZE, flags=BOLD_FLAG)
    view = _make_view([span])
    assert GiuffreCodiciProfile._is_range_abrogated(view) is False


def test_is_omissis_detects_marker() -> None:
    span = _make_span(
        "9-55. – (Omissis).",
        font="PalatinoLinotype-Italic",
        size=BODY_SIZE,
        flags=ITALIC_FLAG,
    )
    view = _make_view([span])
    assert GiuffreCodiciProfile._is_omissis(view) is True


def test_is_omissis_requires_italic() -> None:
    span = _make_span(
        "9-55. – (Omissis).",
        font="PalatinoLinotype-Roman",
        size=BODY_SIZE,
        flags=SERIF_FLAG,
    )
    view = _make_view([span])
    assert GiuffreCodiciProfile._is_omissis(view) is False


def test_is_omissis_no_marker_returns_false() -> None:
    span = _make_span(
        "Normale testo italico",
        font="PalatinoLinotype-Italic",
        size=BODY_SIZE,
        flags=ITALIC_FLAG,
    )
    view = _make_view([span])
    assert GiuffreCodiciProfile._is_omissis(view) is False


def test_is_article_body_detects_roman() -> None:
    span = _make_span(
        "1. Entro dieci giorni",
        font="PalatinoLinotype-Roman",
        size=BODY_SIZE,
        flags=SERIF_FLAG,
    )
    view = _make_view([span])
    assert GiuffreCodiciProfile._is_article_body(view) is True


def test_is_article_body_detects_italic() -> None:
    span = _make_span(
        "Testo italico",
        font="PalatinoLinotype-Italic",
        size=BODY_SIZE,
        flags=ITALIC_FLAG,
    )
    view = _make_view([span])
    assert GiuffreCodiciProfile._is_article_body(view) is True


def test_is_article_body_rejects_bold() -> None:
    """Bold is reserved for ARTICLE_HEADER and hierarchy."""
    span = _make_span("1.", font="PalatinoLinotype-Bold", size=BODY_SIZE, flags=BOLD_FLAG)
    view = _make_view([span])
    assert GiuffreCodiciProfile._is_article_body(view) is False


# ---------------------------------------------------------------------------
# refine_classification — banner detection + per-block routing


def test_refine_classification_detects_penale_from_banner() -> None:
    """A document with PENALE banner spans is detected as CodeType.PENALE."""
    banner_span = _make_span("CODICE PENALE", font="BD700x300", size=BANNER_SIZE, page=100)
    body_span = _make_span(
        "Body text",
        font="PalatinoLinotype-Roman",
        size=BODY_SIZE,
        block_index=1,
        page=100,
    )
    blocks = [
        _make_block(span_range=(0, 1), block_index=0, page=100),
        _make_block(span_range=(1, 2), block_index=1, page=100),
    ]
    extraction = _make_extraction([banner_span, body_span], blocks)
    plugin = GiuffreCodiciProfile()
    plugin.refine_classification(extraction, [_verdict(0), _verdict(1)])
    assert plugin._code_type is CodeType.PENALE


def test_refine_classification_detects_civile_from_banner() -> None:
    banner_span = _make_span("CODICE CIVILE", font="BD700x300", size=BANNER_SIZE, page=100)
    blocks = [_make_block(span_range=(0, 1), block_index=0, page=100)]
    extraction = _make_extraction([banner_span], blocks)
    plugin = GiuffreCodiciProfile()
    plugin.refine_classification(extraction, [_verdict(0)])
    assert plugin._code_type is CodeType.CIVILE


def test_refine_classification_unknown_when_no_banner() -> None:
    """A document with no BD700x300 spans falls back to CodeType.UNKNOWN."""
    body_span = _make_span("Body", font="PalatinoLinotype-Roman", size=BODY_SIZE)
    blocks = [_make_block(span_range=(0, 1), block_index=0)]
    extraction = _make_extraction([body_span], blocks)
    plugin = GiuffreCodiciProfile()
    plugin.refine_classification(extraction, [_verdict(0)])
    assert plugin._code_type is CodeType.UNKNOWN


def test_refine_classification_dominant_penale_wins_over_civile() -> None:
    """When both PENALE and CIVILE banner texts appear, the dominant one wins."""
    p1 = _make_span("CODICE PENALE", font="BD700x300", size=BANNER_SIZE, page=100)
    p2 = _make_span("CODICE PENALE", font="BD700x300", size=BANNER_SIZE, page=101, block_index=1)
    c1 = _make_span("CODICE CIVILE", font="BD700x300", size=BANNER_SIZE, page=102, block_index=2)
    blocks = [
        _make_block(span_range=(0, 1), block_index=0, page=100),
        _make_block(span_range=(1, 2), block_index=1, page=101),
        _make_block(span_range=(2, 3), block_index=2, page=102),
    ]
    extraction = _make_extraction([p1, p2, c1], blocks)
    plugin = GiuffreCodiciProfile()
    plugin.refine_classification(extraction, [_verdict(0), _verdict(1), _verdict(2)])
    assert plugin._code_type is CodeType.PENALE


def test_refine_classification_emits_code_type_warning() -> None:
    banner_span = _make_span("CODICE PENALE", font="BD700x300", size=BANNER_SIZE)
    blocks = [_make_block(span_range=(0, 1), block_index=0)]
    extraction = _make_extraction([banner_span], blocks)
    plugin = GiuffreCodiciProfile()
    plugin.refine_classification(extraction, [_verdict(0)])
    assert any("code_type_detected_penale" in w for w in plugin._pending_warnings)


def test_refine_classification_emits_unknown_warning_when_no_banner() -> None:
    body_span = _make_span("x")
    blocks = [_make_block(span_range=(0, 1), block_index=0)]
    extraction = _make_extraction([body_span], blocks)
    plugin = GiuffreCodiciProfile()
    plugin.refine_classification(extraction, [_verdict(0)])
    assert any("code_type_unknown_no_banner_found" in w for w in plugin._pending_warnings)


def test_refine_classification_promotes_unclassified_to_article_header() -> None:
    """An UNCLASSIFIED block with PalatinoLinotype-Bold 8.98pt trigger gets promoted."""
    banner_span = _make_span("CODICE PENALE", font="BD700x300", size=BANNER_SIZE, page=100)
    header_span = _make_span(
        "309",
        font="PalatinoLinotype-Bold",
        size=ARTICLE_NUMBER_SIZE,
        flags=BOLD_FLAG,
        page=100,
        block_index=1,
    )
    blocks = [
        _make_block(span_range=(0, 1), block_index=0, page=100),
        _make_block(span_range=(1, 2), block_index=1, page=100),
    ]
    extraction = _make_extraction([banner_span, header_span], blocks)
    plugin = GiuffreCodiciProfile()
    refined = plugin.refine_classification(extraction, [_verdict(0), _verdict(1)])
    assert refined[1].category is SemanticCategory.ARTICLE_HEADER


def test_refine_classification_promotes_unclassified_to_article_body() -> None:
    banner_span = _make_span("CODICE PENALE", font="BD700x300", size=BANNER_SIZE, page=100)
    body_span = _make_span(
        "1. Entro dieci",
        font="PalatinoLinotype-Roman",
        size=BODY_SIZE,
        flags=SERIF_FLAG,
        page=100,
        block_index=1,
    )
    blocks = [
        _make_block(span_range=(0, 1), block_index=0, page=100),
        _make_block(span_range=(1, 2), block_index=1, page=100),
    ]
    extraction = _make_extraction([banner_span, body_span], blocks)
    plugin = GiuffreCodiciProfile()
    refined = plugin.refine_classification(extraction, [_verdict(0), _verdict(1)])
    assert refined[1].category is SemanticCategory.ARTICLE_BODY


def test_refine_classification_promotes_unclassified_to_note() -> None:
    banner_span = _make_span("CODICE PENALE", font="BD700x300", size=BANNER_SIZE, page=100)
    note_span = _make_span(
        "(1) V. art. 8.",
        font="MyriadPro-Regular",
        size=NOTE_SIZE,
        page=100,
        block_index=1,
    )
    blocks = [
        _make_block(span_range=(0, 1), block_index=0, page=100),
        _make_block(span_range=(1, 2), block_index=1, page=100),
    ]
    extraction = _make_extraction([banner_span, note_span], blocks)
    plugin = GiuffreCodiciProfile()
    refined = plugin.refine_classification(extraction, [_verdict(0), _verdict(1)])
    assert refined[1].category is SemanticCategory.NOTE


def test_refine_classification_promotes_to_procedural_on_penale() -> None:
    banner_span = _make_span("CODICE PENALE", font="BD700x300", size=BANNER_SIZE, page=100)
    proc_span = _make_span(
        "competenza: Trib. monocratico",
        font="MyriadPro-It",
        size=NOTE_SIZE,
        flags=ITALIC_FLAG,
        page=100,
        block_index=1,
    )
    blocks = [
        _make_block(span_range=(0, 1), block_index=0, page=100),
        _make_block(span_range=(1, 2), block_index=1, page=100),
    ]
    extraction = _make_extraction([banner_span, proc_span], blocks)
    plugin = GiuffreCodiciProfile()
    refined = plugin.refine_classification(extraction, [_verdict(0), _verdict(1)])
    assert refined[1].category is SemanticCategory.PROCEDURAL
    assert any("procedural_block_detected" in w for w in plugin._pending_warnings)


def test_refine_classification_civile_does_not_promote_to_procedural() -> None:
    """On the civile branch competenza: blocks remain NOTE."""
    banner_span = _make_span("CODICE CIVILE", font="BD700x300", size=BANNER_SIZE, page=100)
    proc_span = _make_span(
        "competenza: Trib. monocratico",
        font="MyriadPro-It",
        size=NOTE_SIZE,
        flags=ITALIC_FLAG,
        page=100,
        block_index=1,
    )
    blocks = [
        _make_block(span_range=(0, 1), block_index=0, page=100),
        _make_block(span_range=(1, 2), block_index=1, page=100),
    ]
    extraction = _make_extraction([banner_span, proc_span], blocks)
    plugin = GiuffreCodiciProfile()
    refined = plugin.refine_classification(extraction, [_verdict(0), _verdict(1)])
    assert refined[1].category is SemanticCategory.NOTE


def test_refine_classification_promotes_to_heading_1_libro() -> None:
    banner_span = _make_span("CODICE PENALE", font="BD700x300", size=BANNER_SIZE, page=100)
    head_span = _make_span(
        "LIBRO PRIMO DEI REATI",
        font="PalatinoLinotype-Bold",
        size=BODY_SIZE,
        flags=BOLD_FLAG,
        page=100,
        block_index=1,
    )
    blocks = [
        _make_block(span_range=(0, 1), block_index=0, page=100),
        _make_block(span_range=(1, 2), block_index=1, page=100),
    ]
    extraction = _make_extraction([banner_span, head_span], blocks)
    plugin = GiuffreCodiciProfile()
    refined = plugin.refine_classification(extraction, [_verdict(0), _verdict(1)])
    assert refined[1].category is SemanticCategory.HEADING_1


def test_refine_classification_promotes_to_heading_2_titolo() -> None:
    banner_span = _make_span("CODICE PENALE", font="BD700x300", size=BANNER_SIZE, page=100)
    head_span = _make_span(
        "TITOLO I DELLA PENA",
        font="PalatinoLinotype-Bold",
        size=BODY_SIZE,
        flags=BOLD_FLAG,
        page=100,
        block_index=1,
    )
    blocks = [
        _make_block(span_range=(0, 1), block_index=0, page=100),
        _make_block(span_range=(1, 2), block_index=1, page=100),
    ]
    extraction = _make_extraction([banner_span, head_span], blocks)
    plugin = GiuffreCodiciProfile()
    refined = plugin.refine_classification(extraction, [_verdict(0), _verdict(1)])
    assert refined[1].category is SemanticCategory.HEADING_2


def test_refine_classification_promotes_to_heading_3_capo() -> None:
    banner_span = _make_span("CODICE PENALE", font="BD700x300", size=BANNER_SIZE, page=100)
    head_span = _make_span(
        "CAPO I DISPOSIZIONI",
        font="PalatinoLinotype-Bold",
        size=BODY_SIZE,
        flags=BOLD_FLAG,
        page=100,
        block_index=1,
    )
    blocks = [
        _make_block(span_range=(0, 1), block_index=0, page=100),
        _make_block(span_range=(1, 2), block_index=1, page=100),
    ]
    extraction = _make_extraction([banner_span, head_span], blocks)
    plugin = GiuffreCodiciProfile()
    refined = plugin.refine_classification(extraction, [_verdict(0), _verdict(1)])
    assert refined[1].category is SemanticCategory.HEADING_3


def test_refine_classification_promotes_to_heading_4_sezione() -> None:
    banner_span = _make_span("CODICE PENALE", font="BD700x300", size=BANNER_SIZE, page=100)
    head_span = _make_span(
        "SEZIONE I LE CAMERE",
        font="PalatinoLinotype-Bold",
        size=BODY_SIZE,
        flags=BOLD_FLAG,
        page=100,
        block_index=1,
    )
    blocks = [
        _make_block(span_range=(0, 1), block_index=0, page=100),
        _make_block(span_range=(1, 2), block_index=1, page=100),
    ]
    extraction = _make_extraction([banner_span, head_span], blocks)
    plugin = GiuffreCodiciProfile()
    refined = plugin.refine_classification(extraction, [_verdict(0), _verdict(1)])
    assert refined[1].category is SemanticCategory.HEADING_4


def test_refine_classification_promotes_banner_to_filigree() -> None:
    """A BD700x300 banner glyph is classified as ARTIFACT_FILIGREE."""
    banner_span = _make_span("CODICE PENALE", font="BD700x300", size=BANNER_SIZE, page=100)
    blocks = [_make_block(span_range=(0, 1), block_index=0, page=100)]
    extraction = _make_extraction([banner_span], blocks)
    plugin = GiuffreCodiciProfile()
    refined = plugin.refine_classification(extraction, [_verdict(0)])
    assert refined[0].category is SemanticCategory.ARTIFACT_FILIGREE


def test_refine_classification_handles_abrogated_article() -> None:
    banner_span = _make_span("CODICE PENALE", font="BD700x300", size=BANNER_SIZE, page=100)
    art_span = _make_span(
        "141",
        font="PalatinoLinotype-Bold",
        size=ARTICLE_NUMBER_SIZE,
        flags=BOLD_FLAG,
        page=100,
        block_index=1,
        span_index=0,
    )
    rub_span = _make_span(
        ". [Delitti contro i culti].",
        font="PalatinoLinotype-Italic",
        size=BODY_SIZE,
        flags=ITALIC_FLAG,
        page=100,
        block_index=1,
        span_index=1,
    )
    blocks = [
        _make_block(span_range=(0, 1), block_index=0, page=100),
        _make_block(span_range=(1, 3), block_index=1, page=100),
    ]
    extraction = _make_extraction([banner_span, art_span, rub_span], blocks)
    plugin = GiuffreCodiciProfile()
    refined = plugin.refine_classification(extraction, [_verdict(0), _verdict(1)])
    assert refined[1].category is SemanticCategory.ARTICLE_HEADER
    assert refined[1].reason == "giuffre_codici_article_header_abrogated"
    assert any("abrogated_article_detected" in w for w in plugin._pending_warnings)


def test_refine_classification_handles_range_abrogated_civile() -> None:
    banner_span = _make_span("CODICE CIVILE", font="BD700x300", size=BANNER_SIZE, page=100)
    range_span = _make_span(
        "152-153",
        font="PalatinoLinotype-Bold",
        size=ARTICLE_NUMBER_SIZE,
        flags=BOLD_FLAG,
        page=100,
        block_index=1,
        span_index=0,
    )
    after_span = _make_span(
        ". (1).",
        font="PalatinoLinotype-Roman",
        size=BODY_SIZE,
        page=100,
        block_index=1,
        span_index=1,
    )
    blocks = [
        _make_block(span_range=(0, 1), block_index=0, page=100),
        _make_block(span_range=(1, 3), block_index=1, page=100),
    ]
    extraction = _make_extraction([banner_span, range_span, after_span], blocks)
    plugin = GiuffreCodiciProfile()
    refined = plugin.refine_classification(extraction, [_verdict(0), _verdict(1)])
    # Range header is classified as ARTICLE_HEADER (both `_is_article_header` and
    # `_is_range_abrogated` would fire — first one wins, but the abrogation
    # detection runs on the result anyway via `_is_abrogated_inline` since the
    # range pattern's text doesn't contain `[`; so it's a plain ARTICLE_HEADER
    # with abrogation marker downstream).
    assert refined[1].category is SemanticCategory.ARTICLE_HEADER


def test_refine_classification_handles_omissis_civile() -> None:
    banner_span = _make_span("CODICE CIVILE", font="BD700x300", size=BANNER_SIZE, page=100)
    om_span = _make_span(
        "9-55. – (Omissis).",
        font="PalatinoLinotype-Italic",
        size=BODY_SIZE,
        flags=ITALIC_FLAG,
        page=100,
        block_index=1,
    )
    blocks = [
        _make_block(span_range=(0, 1), block_index=0, page=100),
        _make_block(span_range=(1, 2), block_index=1, page=100),
    ]
    extraction = _make_extraction([banner_span, om_span], blocks)
    plugin = GiuffreCodiciProfile()
    refined = plugin.refine_classification(extraction, [_verdict(0), _verdict(1)])
    assert refined[1].category is SemanticCategory.ARTICLE_BODY
    assert refined[1].reason == "giuffre_codici_article_body_omissis"
    assert any("omissis_article_detected" in w for w in plugin._pending_warnings)


def test_refine_classification_leaves_tier1_verdicts_untouched() -> None:
    """Tier 1 ARTIFACT_FOOTER verdicts stay ARTIFACT_FOOTER, not reclassified."""
    banner_span = _make_span("CODICE PENALE", font="BD700x300", size=BANNER_SIZE, page=100)
    footer_span = _make_span(
        "© Giuffrè",
        font="TimesNewRoman",
        size=FOOTER_SIZE,
        page=100,
        block_index=1,
    )
    blocks = [
        _make_block(span_range=(0, 1), block_index=0, page=100),
        _make_block(span_range=(1, 2), block_index=1, page=100),
    ]
    extraction = _make_extraction([banner_span, footer_span], blocks)
    plugin = GiuffreCodiciProfile()
    refined = plugin.refine_classification(
        extraction,
        [_verdict(0), _verdict(1, category=SemanticCategory.ARTIFACT_FOOTER, reason="footer_zone")],
    )
    assert refined[1].category is SemanticCategory.ARTIFACT_FOOTER


def test_refine_classification_handles_sentinel_block_index() -> None:
    """Synthetic EMPTY_PAGE verdicts (block_index = -1) pass through unchanged."""
    blocks: list[Block] = []
    extraction = _make_extraction([], blocks)
    plugin = GiuffreCodiciProfile()
    sentinel = ClassifiedBlock(
        block_index=-1,
        category=SemanticCategory.EMPTY_PAGE,
        reason="empty_page",
    )
    refined = plugin.refine_classification(extraction, [sentinel])
    assert refined[0] is sentinel


def test_refine_classification_block_with_no_spans_passes_through() -> None:
    blocks = [_make_block(span_range=(0, 0), block_index=0)]
    extraction = _make_extraction([], blocks)
    plugin = GiuffreCodiciProfile()
    refined = plugin.refine_classification(extraction, [_verdict(0)])
    assert refined[0].category is SemanticCategory.UNCLASSIFIED


# ---------------------------------------------------------------------------
# refine_reconstruction — intra-block article splitter


def test_intra_block_splitter_keeps_single_article_untouched() -> None:
    """A block with exactly one article header trigger remains a single Node."""
    banner = _make_span("CODICE PENALE", font="BD700x300", size=BANNER_SIZE, page=100)
    trig = _make_span(
        "309",
        font="PalatinoLinotype-Bold",
        size=ARTICLE_NUMBER_SIZE,
        flags=BOLD_FLAG,
        page=100,
        block_index=1,
    )
    rest = _make_span(
        ". Riesame ordinanze.",
        font="PalatinoLinotype-Bold",
        size=BODY_SIZE,
        flags=BOLD_FLAG,
        page=100,
        block_index=1,
        span_index=1,
    )
    blocks = [
        _make_block(span_range=(0, 1), block_index=0, page=100),
        _make_block(span_range=(1, 3), block_index=1, page=100),
    ]
    extraction = _make_extraction([banner, trig, rest], blocks)
    plugin = GiuffreCodiciProfile()
    plugin.refine_classification(extraction, [_verdict(0), _verdict(1)])
    header = _node(
        "node_0000",
        SemanticCategory.ARTICLE_HEADER,
        "309. Riesame ordinanze.",
        page_index=100,
        block_indices=(1,),
    )
    doc = Document(root=(header,))
    new_doc = plugin.refine_reconstruction(doc, extraction, [])
    assert len(new_doc.root) == 1


def test_intra_block_splitter_splits_two_articles() -> None:
    """A block with two article-number triggers yields two ARTICLE_HEADER Nodes."""
    banner = _make_span("CODICE PENALE", font="BD700x300", size=BANNER_SIZE, page=100)
    trig1 = _make_span(
        "89",
        font="PalatinoLinotype-Bold",
        size=ARTICLE_NUMBER_SIZE,
        flags=BOLD_FLAG,
        page=100,
        block_index=1,
        span_index=0,
    )
    rest1 = _make_span(
        ". Rubrica art89.",
        page=100,
        block_index=1,
        span_index=1,
    )
    trig2 = _make_span(
        "90",
        font="PalatinoLinotype-Bold",
        size=ARTICLE_NUMBER_SIZE,
        flags=BOLD_FLAG,
        page=100,
        block_index=1,
        span_index=2,
    )
    rest2 = _make_span(
        ". Rubrica art90.",
        page=100,
        block_index=1,
        span_index=3,
    )
    blocks = [
        _make_block(span_range=(0, 1), block_index=0, page=100),
        _make_block(span_range=(1, 5), block_index=1, page=100),
    ]
    extraction = _make_extraction([banner, trig1, rest1, trig2, rest2], blocks)
    plugin = GiuffreCodiciProfile()
    plugin.refine_classification(extraction, [_verdict(0), _verdict(1)])
    header = _node(
        "node_0000",
        SemanticCategory.ARTICLE_HEADER,
        "89. Rubrica art89.90. Rubrica art90.",
        page_index=100,
        block_indices=(1,),
    )
    doc = Document(root=(header,))
    new_doc = plugin.refine_reconstruction(doc, extraction, [])
    # Host + synthetic ARTICLE_HEADER + synthetic ARTICLE_BODY (since "Rubrica art90." is non-empty)
    article_headers = [n for n in new_doc.root if n.category is SemanticCategory.ARTICLE_HEADER]
    assert len(article_headers) == 2
    article_bodies = [n for n in new_doc.root if n.category is SemanticCategory.ARTICLE_BODY]
    assert len(article_bodies) == 1


def test_intra_block_splitter_emits_warning_on_split() -> None:
    banner = _make_span("CODICE PENALE", font="BD700x300", size=BANNER_SIZE, page=100)
    trig1 = _make_span(
        "89",
        font="PalatinoLinotype-Bold",
        size=ARTICLE_NUMBER_SIZE,
        flags=BOLD_FLAG,
        page=100,
        block_index=1,
        span_index=0,
    )
    trig2 = _make_span(
        "90",
        font="PalatinoLinotype-Bold",
        size=ARTICLE_NUMBER_SIZE,
        flags=BOLD_FLAG,
        page=100,
        block_index=1,
        span_index=1,
    )
    blocks = [
        _make_block(span_range=(0, 1), block_index=0, page=100),
        _make_block(span_range=(1, 3), block_index=1, page=100),
    ]
    extraction = _make_extraction([banner, trig1, trig2], blocks)
    plugin = GiuffreCodiciProfile()
    plugin.refine_classification(extraction, [_verdict(0), _verdict(1)])
    header = _node(
        "node_0000",
        SemanticCategory.ARTICLE_HEADER,
        "8990",
        page_index=100,
        block_indices=(1,),
    )
    new_doc = plugin.refine_reconstruction(Document(root=(header,)), extraction, [])
    warnings_str = " ".join(new_doc.warnings)
    assert "intra_block_article_split_block_1_count_2" in warnings_str


def test_intra_block_splitter_skips_node_without_block_indices() -> None:
    """A Node with empty block_indices is left untouched."""
    banner = _make_span("CODICE PENALE", font="BD700x300", size=BANNER_SIZE, page=100)
    blocks = [_make_block(span_range=(0, 1), block_index=0, page=100)]
    extraction = _make_extraction([banner], blocks)
    plugin = GiuffreCodiciProfile()
    plugin.refine_classification(extraction, [_verdict(0)])
    header = _node(
        "node_0000",
        SemanticCategory.ARTICLE_HEADER,
        "309",
        page_index=100,
        block_indices=(),
    )
    new_doc = plugin.refine_reconstruction(Document(root=(header,)), extraction, [])
    assert len(new_doc.root) == 1


def test_intra_block_splitter_runs_on_non_article_header_too() -> None:
    """The splitter is signal-agnostic on host category: a NOTE Node
    carrying article-number triggers gets its host text truncated and
    one synthetic ARTICLE_HEADER minted per trigger (regression: the
    original splitter only ran on ARTICLE_HEADER Nodes and missed
    ~90% of penale articles glued inside NOTE-continuation blocks)."""
    banner = _make_span("CODICE PENALE", font="BD700x300", size=BANNER_SIZE, page=100)
    leading_note = _make_span(
        "(1) Prior note.",
        font="MyriadPro-Regular",
        size=NOTE_SIZE,
        page=100,
        block_index=1,
        span_index=0,
    )
    trig1 = _make_span(
        "89",
        font="PalatinoLinotype-Bold",
        size=ARTICLE_NUMBER_SIZE,
        flags=BOLD_FLAG,
        page=100,
        block_index=1,
        span_index=1,
    )
    trig2 = _make_span(
        "90",
        font="PalatinoLinotype-Bold",
        size=ARTICLE_NUMBER_SIZE,
        flags=BOLD_FLAG,
        page=100,
        block_index=1,
        span_index=2,
    )
    blocks = [
        _make_block(span_range=(0, 1), block_index=0, page=100),
        _make_block(span_range=(1, 4), block_index=1, page=100),
    ]
    extraction = _make_extraction([banner, leading_note, trig1, trig2], blocks)
    plugin = GiuffreCodiciProfile()
    plugin.refine_classification(extraction, [_verdict(0), _verdict(1)])
    note = _node("node_0000", SemanticCategory.NOTE, "(1) Prior note.8990", block_indices=(1,))
    new_doc = plugin.refine_reconstruction(Document(root=(note,)), extraction, [])
    note_nodes = [n for n in new_doc.root if n.category is SemanticCategory.NOTE]
    article_headers = [n for n in new_doc.root if n.category is SemanticCategory.ARTICLE_HEADER]
    assert len(note_nodes) == 1
    assert note_nodes[0].text == "(1) Prior note."  # truncated to pre-trigger
    assert len(article_headers) == 2


# ---------------------------------------------------------------------------
# refine_reconstruction — heading-with-inline-article (civile only)


def test_heading_inline_article_splits_on_civile() -> None:
    """A HEADING_3 CAPO block with an inline article splits in 3 Nodes."""
    banner = _make_span("CODICE CIVILE", font="BD700x300", size=BANNER_SIZE, page=104)
    head_kw = _make_span(
        "CAPO I – Delle fonti del diritto",
        font="PalatinoLinotype-Bold",
        size=BODY_SIZE,
        flags=BOLD_FLAG,
        page=104,
        block_index=1,
        span_index=0,
    )
    art_num = _make_span(
        "1",
        font="PalatinoLinotype-Bold",
        size=ARTICLE_NUMBER_SIZE,
        flags=BOLD_FLAG,
        page=104,
        block_index=1,
        span_index=1,
    )
    art_rest = _make_span(
        ". Indicazione delle fonti. – Sono fonti del diritto:",
        font="PalatinoLinotype-Roman",
        size=BODY_SIZE,
        page=104,
        block_index=1,
        span_index=2,
    )
    blocks = [
        _make_block(span_range=(0, 1), block_index=0, page=104),
        _make_block(span_range=(1, 4), block_index=1, page=104),
    ]
    extraction = _make_extraction([banner, head_kw, art_num, art_rest], blocks)
    plugin = GiuffreCodiciProfile()
    plugin.refine_classification(extraction, [_verdict(0), _verdict(1)])
    heading = _node(
        "node_0000",
        SemanticCategory.HEADING_3,
        "CAPO I – Delle fonti del diritto1. Indicazione delle fonti. – Sono fonti del diritto:",
        page_index=104,
        block_indices=(1,),
    )
    new_doc = plugin.refine_reconstruction(Document(root=(heading,)), extraction, [])
    headings = [n for n in new_doc.root if n.category is SemanticCategory.HEADING_3]
    article_headers = [n for n in new_doc.root if n.category is SemanticCategory.ARTICLE_HEADER]
    article_bodies = [n for n in new_doc.root if n.category is SemanticCategory.ARTICLE_BODY]
    assert len(headings) == 1
    assert len(article_headers) == 1
    assert len(article_bodies) == 1
    assert "1" in article_headers[0].text  # type: ignore[operator]


def test_heading_inline_article_also_splits_on_penale() -> None:
    """The generic splitter runs on both code types, so a HEADING_3
    CAPO block with an inline article trigger gets split on the penale
    too (CAPO+article inline observed empirically on penale p101 with
    arts. 71/72/73)."""
    banner = _make_span("CODICE PENALE", font="BD700x300", size=BANNER_SIZE, page=100)
    head_kw = _make_span(
        "CAPO I",
        font="PalatinoLinotype-Bold",
        size=BODY_SIZE,
        flags=BOLD_FLAG,
        page=100,
        block_index=1,
        span_index=0,
    )
    art_num = _make_span(
        "1",
        font="PalatinoLinotype-Bold",
        size=ARTICLE_NUMBER_SIZE,
        flags=BOLD_FLAG,
        page=100,
        block_index=1,
        span_index=1,
    )
    blocks = [
        _make_block(span_range=(0, 1), block_index=0, page=100),
        _make_block(span_range=(1, 3), block_index=1, page=100),
    ]
    extraction = _make_extraction([banner, head_kw, art_num], blocks)
    plugin = GiuffreCodiciProfile()
    plugin.refine_classification(extraction, [_verdict(0), _verdict(1)])
    heading = _node(
        "node_0000",
        SemanticCategory.HEADING_3,
        "CAPO I delle fonti.1",
        page_index=100,
        block_indices=(1,),
    )
    new_doc = plugin.refine_reconstruction(Document(root=(heading,)), extraction, [])
    # Heading host truncated + 1 synthetic ARTICLE_HEADER minted.
    headings = [n for n in new_doc.root if n.category is SemanticCategory.HEADING_3]
    article_headers = [n for n in new_doc.root if n.category is SemanticCategory.ARTICLE_HEADER]
    assert len(headings) == 1
    assert len(article_headers) == 1


def test_heading_inline_article_skipped_when_pattern_does_not_match() -> None:
    """A regular HEADING_3 without the inline article pattern stays intact."""
    banner = _make_span("CODICE CIVILE", font="BD700x300", size=BANNER_SIZE, page=104)
    head_kw = _make_span(
        "CAPO I – Delle fonti del diritto",
        font="PalatinoLinotype-Bold",
        size=BODY_SIZE,
        flags=BOLD_FLAG,
        page=104,
        block_index=1,
    )
    blocks = [
        _make_block(span_range=(0, 1), block_index=0, page=104),
        _make_block(span_range=(1, 2), block_index=1, page=104),
    ]
    extraction = _make_extraction([banner, head_kw], blocks)
    plugin = GiuffreCodiciProfile()
    plugin.refine_classification(extraction, [_verdict(0), _verdict(1)])
    heading = _node(
        "node_0000",
        SemanticCategory.HEADING_3,
        "CAPO I – Delle fonti del diritto",
        page_index=104,
        block_indices=(1,),
    )
    new_doc = plugin.refine_reconstruction(Document(root=(heading,)), extraction, [])
    assert len(new_doc.root) == 1


# ---------------------------------------------------------------------------
# refine_reconstruction — multi-note splitter


def test_multi_note_splitter_splits_two_notes() -> None:
    banner = _make_span("CODICE PENALE", font="BD700x300", size=BANNER_SIZE, page=100)
    blocks = [_make_block(span_range=(0, 1), block_index=0, page=100)]
    extraction = _make_extraction([banner], blocks)
    plugin = GiuffreCodiciProfile()
    plugin.refine_classification(extraction, [_verdict(0)])
    note = _node(
        "node_0000",
        SemanticCategory.NOTE,
        "(1) Prima nota. (2) Seconda nota.",
        page_index=100,
        block_indices=(0,),
    )
    new_doc = plugin.refine_reconstruction(Document(root=(note,)), extraction, [])
    notes = [n for n in new_doc.root if n.category is SemanticCategory.NOTE]
    assert len(notes) == 2


def test_multi_note_splitter_singleton_untouched() -> None:
    banner = _make_span("CODICE PENALE", font="BD700x300", size=BANNER_SIZE, page=100)
    blocks = [_make_block(span_range=(0, 1), block_index=0, page=100)]
    extraction = _make_extraction([banner], blocks)
    plugin = GiuffreCodiciProfile()
    plugin.refine_classification(extraction, [_verdict(0)])
    note = _node(
        "node_0000",
        SemanticCategory.NOTE,
        "(1) Solo una nota.",
        page_index=100,
        block_indices=(0,),
    )
    new_doc = plugin.refine_reconstruction(Document(root=(note,)), extraction, [])
    assert len(new_doc.root) == 1


def test_multi_note_splitter_emits_warning_per_minted_note() -> None:
    banner = _make_span("CODICE PENALE", font="BD700x300", size=BANNER_SIZE, page=100)
    blocks = [_make_block(span_range=(0, 1), block_index=0, page=100)]
    extraction = _make_extraction([banner], blocks)
    plugin = GiuffreCodiciProfile()
    plugin.refine_classification(extraction, [_verdict(0)])
    note = _node(
        "node_0000",
        SemanticCategory.NOTE,
        "(1) Prima. (2) Seconda. (3) Terza.",
        page_index=100,
        block_indices=(0,),
    )
    new_doc = plugin.refine_reconstruction(Document(root=(note,)), extraction, [])
    minted_warnings = [w for w in new_doc.warnings if "multi_note_split_minted_node" in w]
    assert len(minted_warnings) == 2  # 2 chunks minted (host keeps chunk 1)


def test_multi_note_splitter_skips_non_note_nodes() -> None:
    banner = _make_span("CODICE PENALE", font="BD700x300", size=BANNER_SIZE, page=100)
    blocks = [_make_block(span_range=(0, 1), block_index=0, page=100)]
    extraction = _make_extraction([banner], blocks)
    plugin = GiuffreCodiciProfile()
    plugin.refine_classification(extraction, [_verdict(0)])
    body = _node(
        "node_0000",
        SemanticCategory.ARTICLE_BODY,
        "(1) Prima. (2) Seconda.",
        page_index=100,
        block_indices=(0,),
    )
    new_doc = plugin.refine_reconstruction(Document(root=(body,)), extraction, [])
    assert len(new_doc.root) == 1


# ---------------------------------------------------------------------------
# refine_reconstruction — cross-reference minting


def test_crossref_minter_penale_simple_brackets() -> None:
    """[309] inline triggers a CROSS_REFERENCE Node on the penale."""
    banner = _make_span("CODICE PENALE", font="BD700x300", size=BANNER_SIZE, page=100)
    blocks = [_make_block(span_range=(0, 1), block_index=0, page=100)]
    extraction = _make_extraction([banner], blocks)
    plugin = GiuffreCodiciProfile()
    plugin.refine_classification(extraction, [_verdict(0)])
    body = _node(
        "node_0000",
        SemanticCategory.ARTICLE_BODY,
        "vedi [309] e anche [575] per ulteriori dettagli.",
        page_index=100,
        block_indices=(0,),
    )
    new_doc = plugin.refine_reconstruction(Document(root=(body,)), extraction, [])
    crossrefs = [n for n in new_doc.root if n.category is SemanticCategory.CROSS_REFERENCE]
    assert len(crossrefs) == 2
    assert crossrefs[0].text == "[309]"
    assert crossrefs[1].text == "[575]"


def test_crossref_minter_penale_excludes_roman_comma_markers() -> None:
    """[I] is a comma marker and must NOT be minted as CROSS_REFERENCE."""
    banner = _make_span("CODICE PENALE", font="BD700x300", size=BANNER_SIZE, page=100)
    blocks = [_make_block(span_range=(0, 1), block_index=0, page=100)]
    extraction = _make_extraction([banner], blocks)
    plugin = GiuffreCodiciProfile()
    plugin.refine_classification(extraction, [_verdict(0)])
    body = _node(
        "node_0000",
        SemanticCategory.ARTICLE_BODY,
        "Vedi [I] del comma.",
        page_index=100,
        block_indices=(0,),
    )
    new_doc = plugin.refine_reconstruction(Document(root=(body,)), extraction, [])
    crossrefs = [n for n in new_doc.root if n.category is SemanticCategory.CROSS_REFERENCE]
    assert len(crossrefs) == 0


def test_crossref_minter_civile_elaborated_form() -> None:
    """On the civile, elaborated forms [N Cost.] are minted."""
    banner = _make_span("CODICE CIVILE", font="BD700x300", size=BANNER_SIZE, page=104)
    blocks = [_make_block(span_range=(0, 1), block_index=0, page=104)]
    extraction = _make_extraction([banner], blocks)
    plugin = GiuffreCodiciProfile()
    plugin.refine_classification(extraction, [_verdict(0)])
    body = _node(
        "node_0000",
        SemanticCategory.ARTICLE_BODY,
        "Vedi [252 Cost.] e anche [1362 ss. c.c.] del codice civile.",
        page_index=104,
        block_indices=(0,),
    )
    new_doc = plugin.refine_reconstruction(Document(root=(body,)), extraction, [])
    crossrefs = [n for n in new_doc.root if n.category is SemanticCategory.CROSS_REFERENCE]
    assert len(crossrefs) == 2


def test_crossref_minter_civile_excludes_comma_markers() -> None:
    banner = _make_span("CODICE CIVILE", font="BD700x300", size=BANNER_SIZE, page=104)
    blocks = [_make_block(span_range=(0, 1), block_index=0, page=104)]
    extraction = _make_extraction([banner], blocks)
    plugin = GiuffreCodiciProfile()
    plugin.refine_classification(extraction, [_verdict(0)])
    body = _node(
        "node_0000",
        SemanticCategory.ARTICLE_BODY,
        "Riferimento al [I] comma e poi vedi [10 c.c.] e [II] del comma.",
        page_index=104,
        block_indices=(0,),
    )
    new_doc = plugin.refine_reconstruction(Document(root=(body,)), extraction, [])
    crossrefs = [n for n in new_doc.root if n.category is SemanticCategory.CROSS_REFERENCE]
    assert len(crossrefs) == 1
    assert crossrefs[0].text == "[10 c.c.]"


def test_crossref_minter_civile_handles_compound_with_exponent() -> None:
    """[10², 13, 29 Cost.] is recognised as a single elaborated marker."""
    banner = _make_span("CODICE CIVILE", font="BD700x300", size=BANNER_SIZE, page=104)
    blocks = [_make_block(span_range=(0, 1), block_index=0, page=104)]
    extraction = _make_extraction([banner], blocks)
    plugin = GiuffreCodiciProfile()
    plugin.refine_classification(extraction, [_verdict(0)])
    body = _node(
        "node_0000",
        SemanticCategory.ARTICLE_BODY,
        "Riferimento [10², 13, 29 Cost.] del compound.",
        page_index=104,
        block_indices=(0,),
    )
    new_doc = plugin.refine_reconstruction(Document(root=(body,)), extraction, [])
    crossrefs = [n for n in new_doc.root if n.category is SemanticCategory.CROSS_REFERENCE]
    assert len(crossrefs) >= 1


def test_crossref_minter_emits_warning_per_mint() -> None:
    banner = _make_span("CODICE PENALE", font="BD700x300", size=BANNER_SIZE, page=100)
    blocks = [_make_block(span_range=(0, 1), block_index=0, page=100)]
    extraction = _make_extraction([banner], blocks)
    plugin = GiuffreCodiciProfile()
    plugin.refine_classification(extraction, [_verdict(0)])
    body = _node(
        "node_0000",
        SemanticCategory.ARTICLE_BODY,
        "vedi [309]",
        page_index=100,
        block_indices=(0,),
    )
    new_doc = plugin.refine_reconstruction(Document(root=(body,)), extraction, [])
    assert any("cross_reference_minted_node" in w for w in new_doc.warnings)


def test_crossref_minter_does_not_mint_for_non_body_nodes() -> None:
    banner = _make_span("CODICE PENALE", font="BD700x300", size=BANNER_SIZE, page=100)
    blocks = [_make_block(span_range=(0, 1), block_index=0, page=100)]
    extraction = _make_extraction([banner], blocks)
    plugin = GiuffreCodiciProfile()
    plugin.refine_classification(extraction, [_verdict(0)])
    note = _node(
        "node_0000",
        SemanticCategory.NOTE,
        "(1) vedi [309]",
        page_index=100,
        block_indices=(0,),
    )
    new_doc = plugin.refine_reconstruction(Document(root=(note,)), extraction, [])
    crossrefs = [n for n in new_doc.root if n.category is SemanticCategory.CROSS_REFERENCE]
    assert len(crossrefs) == 0


def test_crossref_minter_empty_body_text_skipped() -> None:
    banner = _make_span("CODICE PENALE", font="BD700x300", size=BANNER_SIZE, page=100)
    blocks = [_make_block(span_range=(0, 1), block_index=0, page=100)]
    extraction = _make_extraction([banner], blocks)
    plugin = GiuffreCodiciProfile()
    plugin.refine_classification(extraction, [_verdict(0)])
    body = _node(
        "node_0000",
        SemanticCategory.ARTICLE_BODY,
        "",
        page_index=100,
        block_indices=(0,),
    )
    new_doc = plugin.refine_reconstruction(Document(root=(body,)), extraction, [])
    assert len(new_doc.root) == 1


# ---------------------------------------------------------------------------
# refine_apparatus — binding


def test_refine_apparatus_binds_simple_penale_crossref() -> None:
    banner = _make_span("CODICE PENALE", font="BD700x300", size=BANNER_SIZE, page=100)
    blocks = [_make_block(span_range=(0, 1), block_index=0, page=100)]
    extraction = _make_extraction([banner], blocks)
    plugin = GiuffreCodiciProfile()
    plugin.refine_classification(extraction, [_verdict(0)])
    art_header = _node(
        "node_0001",
        SemanticCategory.ARTICLE_HEADER,
        "309. Riesame.",
        page_index=100,
        block_indices=(0,),
    )
    body = _node(
        "node_0002",
        SemanticCategory.ARTICLE_BODY,
        "vedi [309]",
        page_index=100,
        block_indices=(0,),
    )
    doc = Document(root=(art_header, body))
    new_doc = plugin.refine_reconstruction(doc, extraction, [])
    new_doc = plugin.refine_apparatus(new_doc, extraction, [])
    crossrefs = [n for n in new_doc.root if n.category is SemanticCategory.CROSS_REFERENCE]
    assert len(crossrefs) == 1
    assert crossrefs[0].apparatus_refs
    assert crossrefs[0].apparatus_refs[0].kind is ApparatusRefKind.CROSS_REF_TARGET
    assert crossrefs[0].apparatus_refs[0].target_node_id == "node_0001"


def test_refine_apparatus_unresolved_when_target_missing() -> None:
    banner = _make_span("CODICE PENALE", font="BD700x300", size=BANNER_SIZE, page=100)
    blocks = [_make_block(span_range=(0, 1), block_index=0, page=100)]
    extraction = _make_extraction([banner], blocks)
    plugin = GiuffreCodiciProfile()
    plugin.refine_classification(extraction, [_verdict(0)])
    body = _node(
        "node_0001",
        SemanticCategory.ARTICLE_BODY,
        "vedi [999]",  # target does not exist
        page_index=100,
        block_indices=(0,),
    )
    doc = Document(root=(body,))
    new_doc = plugin.refine_reconstruction(doc, extraction, [])
    new_doc = plugin.refine_apparatus(new_doc, extraction, [])
    crossrefs = [n for n in new_doc.root if n.category is SemanticCategory.CROSS_REFERENCE]
    assert len(crossrefs) == 1
    assert not crossrefs[0].apparatus_refs
    assert any("cross_reference_unresolved_node" in w for w in new_doc.warnings)


def test_refine_apparatus_does_not_bind_elaborated_form() -> None:
    """[N c.c.] with codice qualifier is not bound — external reference."""
    banner = _make_span("CODICE CIVILE", font="BD700x300", size=BANNER_SIZE, page=104)
    blocks = [_make_block(span_range=(0, 1), block_index=0, page=104)]
    extraction = _make_extraction([banner], blocks)
    plugin = GiuffreCodiciProfile()
    plugin.refine_classification(extraction, [_verdict(0)])
    art = _node(
        "node_0001",
        SemanticCategory.ARTICLE_HEADER,
        "1362.",
        page_index=104,
        block_indices=(0,),
    )
    body = _node(
        "node_0002",
        SemanticCategory.ARTICLE_BODY,
        "vedi [1362 c.c.]",
        page_index=104,
        block_indices=(0,),
    )
    doc = Document(root=(art, body))
    new_doc = plugin.refine_reconstruction(doc, extraction, [])
    new_doc = plugin.refine_apparatus(new_doc, extraction, [])
    crossrefs = [n for n in new_doc.root if n.category is SemanticCategory.CROSS_REFERENCE]
    assert len(crossrefs) == 1
    # The qualifier makes the form elaborated — not bound.
    assert not crossrefs[0].apparatus_refs


def test_refine_apparatus_filters_tier1_warnings() -> None:
    """Tier 1 unparseable_cross_reference_* warnings on minted Nodes are dropped."""
    banner = _make_span("CODICE PENALE", font="BD700x300", size=BANNER_SIZE, page=100)
    blocks = [_make_block(span_range=(0, 1), block_index=0, page=100)]
    extraction = _make_extraction([banner], blocks)
    plugin = GiuffreCodiciProfile()
    plugin.refine_classification(extraction, [_verdict(0)])
    body = _node(
        "node_0001",
        SemanticCategory.ARTICLE_BODY,
        "vedi [309]",
        page_index=100,
        block_indices=(0,),
    )
    doc = Document(
        root=(body,),
        warnings=(
            "unparseable_cross_reference_node_node_0002",
            "unrelated_warning",
        ),
    )
    new_doc = plugin.refine_reconstruction(doc, extraction, [])
    new_doc = plugin.refine_apparatus(new_doc, extraction, [])
    # The minted Node id is node_0002 (next after node_0001). The filter drops
    # the matching tier 1 warning but keeps the unrelated one.
    assert "unparseable_cross_reference_node_node_0002" not in new_doc.warnings
    assert "unrelated_warning" in new_doc.warnings


def test_build_article_marker_index_walks_forest() -> None:
    art1 = _node("node_0001", SemanticCategory.ARTICLE_HEADER, "1.", page_index=100)
    art2 = _node("node_0002", SemanticCategory.ARTICLE_HEADER, "2-bis.", page_index=100)
    other = _node("node_0003", SemanticCategory.ARTICLE_BODY, "x", page_index=100)
    parent = _node("node_0000", SemanticCategory.HEADING_1, None, children=(art1, art2, other))
    index = GiuffreCodiciProfile._build_article_marker_index((parent,))
    assert index == {"1": "node_0001", "2-bis": "node_0002"}


def test_build_article_marker_index_first_wins_on_collision() -> None:
    """When two articles have the same number, the first one in pre-order wins."""
    art1 = _node("node_0001", SemanticCategory.ARTICLE_HEADER, "1.", page_index=100)
    art2 = _node("node_0002", SemanticCategory.ARTICLE_HEADER, "1.", page_index=200)
    parent = _node("node_0000", SemanticCategory.HEADING_1, None, children=(art1, art2))
    index = GiuffreCodiciProfile._build_article_marker_index((parent,))
    assert index["1"] == "node_0001"


def test_build_article_marker_index_skips_unparseable_text() -> None:
    """A node with non-numeric text is silently skipped."""
    art = _node("node_0001", SemanticCategory.ARTICLE_HEADER, "non-numeric", page_index=100)
    index = GiuffreCodiciProfile._build_article_marker_index((art,))
    assert index == {}


def test_build_article_marker_index_skips_none_text() -> None:
    art = _node("node_0001", SemanticCategory.ARTICLE_HEADER, None, page_index=100)
    index = GiuffreCodiciProfile._build_article_marker_index((art,))
    assert index == {}


# ---------------------------------------------------------------------------
# _is_article_number_trigger


def test_is_article_number_trigger_accepts_bold_number() -> None:
    span = _make_span(
        "309",
        font="PalatinoLinotype-Bold",
        size=ARTICLE_NUMBER_SIZE,
        flags=BOLD_FLAG,
    )
    assert GiuffreCodiciProfile._is_article_number_trigger(span) is True


def test_is_article_number_trigger_accepts_range() -> None:
    span = _make_span(
        "152-153",
        font="PalatinoLinotype-Bold",
        size=ARTICLE_NUMBER_SIZE,
        flags=BOLD_FLAG,
    )
    assert GiuffreCodiciProfile._is_article_number_trigger(span) is True


def test_is_article_number_trigger_rejects_text() -> None:
    span = _make_span(
        "Testo",
        font="PalatinoLinotype-Bold",
        size=ARTICLE_NUMBER_SIZE,
        flags=BOLD_FLAG,
    )
    assert GiuffreCodiciProfile._is_article_number_trigger(span) is False


def test_is_article_number_trigger_rejects_non_palatino() -> None:
    span = _make_span(
        "309",
        font="MyriadPro-Regular",
        size=ARTICLE_NUMBER_SIZE,
        flags=BOLD_FLAG,
    )
    assert GiuffreCodiciProfile._is_article_number_trigger(span) is False


def test_is_article_number_trigger_rejects_non_bold() -> None:
    span = _make_span(
        "309",
        font="PalatinoLinotype-Roman",
        size=ARTICLE_NUMBER_SIZE,
        flags=SERIF_FLAG,
    )
    assert GiuffreCodiciProfile._is_article_number_trigger(span) is False


def test_is_article_number_trigger_rejects_small_size() -> None:
    span = _make_span(
        "309",
        font="PalatinoLinotype-Bold",
        size=BODY_SIZE,  # 7.48 < 8.5
        flags=BOLD_FLAG,
    )
    assert GiuffreCodiciProfile._is_article_number_trigger(span) is False


# ---------------------------------------------------------------------------
# End-to-end integration — synthetic mini document


def test_end_to_end_synthetic_penale_document() -> None:
    """A mini synthetic penale document goes through all three refine_* phases."""
    banner = _make_span("CODICE PENALE", font="BD700x300", size=BANNER_SIZE, page=100)
    libro = _make_span(
        "LIBRO PRIMO DEI REATI",
        font="PalatinoLinotype-Bold",
        size=BODY_SIZE,
        flags=BOLD_FLAG,
        page=100,
        block_index=1,
    )
    art_num = _make_span(
        "309",
        font="PalatinoLinotype-Bold",
        size=ARTICLE_NUMBER_SIZE,
        flags=BOLD_FLAG,
        page=100,
        block_index=2,
    )
    art_rest = _make_span(
        ". Riesame ordinanze.",
        font="PalatinoLinotype-Bold",
        size=BODY_SIZE,
        flags=BOLD_FLAG,
        page=100,
        block_index=2,
        span_index=1,
    )
    body = _make_span(
        "1. Entro dieci giorni vedi [575]",
        font="PalatinoLinotype-Roman",
        size=BODY_SIZE,
        page=100,
        block_index=3,
    )
    blocks = [
        _make_block(span_range=(0, 1), block_index=0, page=100),
        _make_block(span_range=(1, 2), block_index=1, page=100),
        _make_block(span_range=(2, 4), block_index=2, page=100),
        _make_block(span_range=(4, 5), block_index=3, page=100),
    ]
    extraction = _make_extraction([banner, libro, art_num, art_rest, body], blocks)
    plugin = GiuffreCodiciProfile()
    refined = plugin.refine_classification(
        extraction,
        [_verdict(0), _verdict(1), _verdict(2), _verdict(3)],
    )
    assert plugin._code_type is CodeType.PENALE
    assert refined[0].category is SemanticCategory.ARTIFACT_FILIGREE
    assert refined[1].category is SemanticCategory.HEADING_1
    assert refined[2].category is SemanticCategory.ARTICLE_HEADER
    assert refined[3].category is SemanticCategory.ARTICLE_BODY


# ---------------------------------------------------------------------------
# WARNING_PREFIX


def test_warning_prefix_constant() -> None:
    assert WARNING_PREFIX == "plugin:giuffre_codici"


# ---------------------------------------------------------------------------
# Extra coverage — edge cases on size constants and tolerances


def test_body_apex_size_constant() -> None:
    assert pytest.approx(5.20) == BODY_APEX_SIZE


def test_comma_marker_size_constant() -> None:
    assert pytest.approx(4.99) == COMMA_MARKER_SIZE


def test_footer_size_constant() -> None:
    assert pytest.approx(11.38) == FOOTER_SIZE
