"""Unit tests for the enciclopedia_moderna corpus plugin."""

from __future__ import annotations

import pytest

from scabopdf_pipeline.apparatus.constants import (
    INLINE_PARENTHESISED_CROSSREF_REGEX as _CROSSREF_INLINE_NOTE_PATTERN,
)
from scabopdf_pipeline.apparatus.constants import (
    LEADING_PARENTHESISED_NOTE_MARKER_REGEX as _NOTE_LEADING_MARKER_PATTERN,
)
from scabopdf_pipeline.apparatus.types import ApparatusRefKind
from scabopdf_pipeline.classification.types import ClassifiedBlock
from scabopdf_pipeline.extraction.types import Block, ExtractionResult, Span
from scabopdf_pipeline.profiles.enciclopedia_moderna import (
    _CROSSREF_INLINE_VOCE_PATTERN,
    _CROSSREF_MAX_MARKER_VALUE,
    _FONTI_LABEL_PATTERN,
    _LETTERATURA_LABEL_PATTERN,
    _PARAGRAPH_HEADING_PATTERN,
    _SEZIONE_HEADING_PATTERN,
    _SOMMARIO_TRIM_PATTERN,
    _TOC_ITEM_PATTERN,
    APICE_SIZE,
    BODY_SIZE,
    CONFIDENCE_HELVETICA_COPYRIGHT_PRESENT,
    CONFIDENCE_NOTE_FAMILY_PRESENT,
    CONFIDENCE_SIMONCINI_BODY_DOMINANT,
    CONFIDENCE_TIMES_FOOTER_PRESENT,
    COPYRIGHT_SIZE,
    DROP_CAP_MIN_SIZE,
    FOOTER_ENTE_SIZE,
    HELVETICA_BOLD_FAMILY_FRAGMENT,
    LEXICON_ALLOWLIST,
    NOTE_SIZE,
    SIMONCINI_BOLD_FAMILY,
    SIMONCINI_ITALIC_FAMILY,
    SIMONCINI_REGULAR_FAMILY,
    SOMMARIO_SIZE,
    TIMES_NEW_ROMAN_FAMILY,
    WARNING_PREFIX,
    WARNING_TEMPLATES,
    EnciclopediaModernaProfile,
    _BlockView,
)
from scabopdf_pipeline.profiling.signals import (
    ApparatusPresence,
    FontDominance,
    OutlineStructure,
    ProducerCreator,
    ProfilePageGeometry,
    ProfilingSignals,
    TypographicSignature,
)
from scabopdf_pipeline.reconstruction.minting import (
    _NODE_ID_PATTERN,
)
from scabopdf_pipeline.reconstruction.minting import (
    NodeIdMinter as _NodeIdMinter,
)
from scabopdf_pipeline.reconstruction.minting import (
    iter_nodes_pre_order as _iter_nodes,
)
from scabopdf_pipeline.reconstruction.minting import (
    max_existing_node_counter as _max_existing_node_counter,
)
from scabopdf_pipeline.reconstruction.types import Document, Node
from scabopdf_pipeline.schema.categories import SemanticCategory

BOLD_FLAG = 0x10
ITALIC_FLAG = 0x02


# ---------------------------------------------------------------------------
# Helpers


def _moderna_signals(
    *,
    body_family: str = SIMONCINI_REGULAR_FAMILY,
    body_size: float = BODY_SIZE,
    body_dominance: float = 70.0,
    include_note_family: bool = True,
    include_bold_heading: bool = True,
    include_times_footer: bool = True,
    include_helvetica_copyright: bool = True,
    producer: str = "PDFsharp 1.31.1789-g (www.pdfsharp.com)",
    creator: str = "PDFsharp 1.31.1789-g (www.pdfsharp.com)",
    width_pt: float = 481.89,
    height_pt: float = 680.32,
    marginal_headings: int = 0,
) -> ProfilingSignals:
    fonts = [
        FontDominance(family=body_family, size=body_size, dominance_percent=body_dominance),
    ]
    if include_note_family:
        fonts.append(
            FontDominance(family=SIMONCINI_REGULAR_FAMILY, size=NOTE_SIZE, dominance_percent=15.0)
        )
    if include_bold_heading:
        fonts.append(
            FontDominance(family=SIMONCINI_BOLD_FAMILY, size=BODY_SIZE, dominance_percent=0.5)
        )
    if include_times_footer:
        fonts.append(
            FontDominance(
                family=TIMES_NEW_ROMAN_FAMILY,
                size=FOOTER_ENTE_SIZE,
                dominance_percent=0.1,
            )
        )
    if include_helvetica_copyright:
        fonts.append(
            FontDominance(family="Helvetica-Bold", size=COPYRIGHT_SIZE, dominance_percent=0.05)
        )
    return ProfilingSignals(
        typographic_signature=TypographicSignature(fonts=fonts),
        apparatus_presence=ApparatusPresence(marginal_headings=marginal_headings),
        page_geometry=ProfilePageGeometry(width_pt=width_pt, height_pt=height_pt),
        producer_creator=ProducerCreator(producer=producer, creator=creator),
        outline_structure=OutlineStructure(),
        specific_markers=[],
    )


def _make_span(
    text: str,
    *,
    font: str = SIMONCINI_REGULAR_FAMILY,
    size: float = BODY_SIZE,
    flags: int = 0,
    page: int = 0,
    bbox: tuple[float, float, float, float] = (70.0, 300.0, 250.0, 320.0),
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
    bbox: tuple[float, float, float, float] = (70.0, 200.0, 250.0, 600.0),
    span_range: tuple[int, int] = (0, 1),
    block_index: int = 0,
) -> Block:
    return Block(page=page, block_index=block_index, bbox=bbox, span_range=span_range)


def _make_view(
    spans: list[Span],
    *,
    page: int = 0,
    bbox: tuple[float, float, float, float] = (70.0, 200.0, 250.0, 600.0),
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
    plugin = EnciclopediaModernaProfile()
    assert plugin.profile_id == "enciclopedia_moderna"
    assert plugin.editorial_family == "giuffre_edd"
    assert plugin.genre == "enciclopedia_moderna"


def test_profile_identity_classvars() -> None:
    assert EnciclopediaModernaProfile.profile_id == "enciclopedia_moderna"
    assert EnciclopediaModernaProfile.editorial_family == "giuffre_edd"
    assert EnciclopediaModernaProfile.genre == "enciclopedia_moderna"


def test_plugin_registered_in_builtins() -> None:
    from scabopdf_pipeline.profiles import BUILTIN_PLUGINS

    assert EnciclopediaModernaProfile in BUILTIN_PLUGINS


# ---------------------------------------------------------------------------
# Section 2: declarative methods


def test_get_categories_covers_edd_specific_set() -> None:
    cats = EnciclopediaModernaProfile().get_categories()
    expected = {
        SemanticCategory.HEADING_LETTER_INITIAL,
        SemanticCategory.TITLE,
        SemanticCategory.HEADING_1,
        SemanticCategory.HEADING_2,
        SemanticCategory.BODY,
        SemanticCategory.NOTE,
        SemanticCategory.CROSS_REFERENCE,
        SemanticCategory.SECTION_LABEL,
        SemanticCategory.FONTI,
        SemanticCategory.LETTERATURA,
        SemanticCategory.TOC_GENERAL,
    }
    assert expected <= cats


def test_get_categories_includes_artifact_carriers() -> None:
    cats = EnciclopediaModernaProfile().get_categories()
    assert SemanticCategory.ARTIFACT_FOOTER in cats
    assert SemanticCategory.ARTIFACT_RUNNING_HEADER in cats
    assert SemanticCategory.ARTIFACT_STAMP in cats
    assert SemanticCategory.BOOK_PAGE_ANCHOR in cats


def test_get_categories_includes_empty_and_unclassified() -> None:
    cats = EnciclopediaModernaProfile().get_categories()
    assert SemanticCategory.UNCLASSIFIED in cats
    assert SemanticCategory.EMPTY_PAGE in cats


def test_get_categories_excludes_dejure_specific() -> None:
    cats = EnciclopediaModernaProfile().get_categories()
    assert SemanticCategory.GENRE_BANNER not in cats
    assert SemanticCategory.META_VALUE not in cats
    assert SemanticCategory.FONTE_VALUE not in cats
    assert SemanticCategory.AUTHORS not in cats
    assert SemanticCategory.REFERRAL not in cats
    assert SemanticCategory.MASSIMA_LABEL not in cats


def test_get_post_processing_dehyphenate_and_cross_page() -> None:
    assert EnciclopediaModernaProfile().get_post_processing() == [
        "dehyphenate_with_log",
        "merge_cross_page_notes",
    ]


def test_get_layouts_disabled_is_empty() -> None:
    assert EnciclopediaModernaProfile().get_layouts_disabled() == []


def test_get_categories_returns_set() -> None:
    cats = EnciclopediaModernaProfile().get_categories()
    assert isinstance(cats, set)


def test_warning_templates_are_a_tuple() -> None:
    assert isinstance(WARNING_TEMPLATES, tuple)
    assert all(w.startswith(WARNING_PREFIX) for w in WARNING_TEMPLATES)


def test_lexicon_allowlist_is_a_frozenset() -> None:
    assert isinstance(LEXICON_ALLOWLIST, frozenset)
    assert len(LEXICON_ALLOWLIST) > 0


def test_lexicon_allowlist_includes_latin_legal_core() -> None:
    """The EdD moderna allowlist mirrors the storica latinismi for parity across the family."""
    expected_core = {
        "actio",
        "exceptio",
        "ius",
        "stipulatio",
        "traditio",
        "dolus",
        "praetor",
        "usucapio",
    }
    assert expected_core.issubset(LEXICON_ALLOWLIST)


def test_get_lexicon_allowlist_returns_the_module_constant() -> None:
    assert EnciclopediaModernaProfile.get_lexicon_allowlist() is LEXICON_ALLOWLIST


# ---------------------------------------------------------------------------
# Section 3: matches()


def test_matches_clears_threshold_on_default_signals() -> None:
    score = EnciclopediaModernaProfile.matches(_moderna_signals())
    assert score >= 0.6


def test_matches_default_signals_returns_full_positive() -> None:
    """Full positive ceiling = 0.45 + 0.10 + 0.05 + 0.10 + 0.10 + 0.05 = 0.85."""
    score = EnciclopediaModernaProfile.matches(_moderna_signals())
    assert score == pytest.approx(0.85)


def test_matches_drops_below_threshold_on_simoncini_std_family() -> None:
    """Giappichelli uses 'SimonciniGaramondStd' — must NOT match EdD moderna."""
    signals = _moderna_signals(body_family="SimonciniGaramondStd")
    score = EnciclopediaModernaProfile.matches(signals)
    assert score < 0.6


def test_matches_drops_below_threshold_on_arial_body() -> None:
    """DT/NS/MM use ArialMT — must NOT match EdD moderna."""
    signals = _moderna_signals(
        body_family="ArialMT",
        include_note_family=False,
        include_bold_heading=False,
        include_times_footer=False,
        include_helvetica_copyright=False,
    )
    score = EnciclopediaModernaProfile.matches(signals)
    assert score < 0.6


def test_matches_drops_below_threshold_on_times_roman_body() -> None:
    """EdD storica uses Times-Roman OCR — must route to its own plugin."""
    signals = _moderna_signals(
        body_family="Times-Roman",
        include_note_family=False,
        include_bold_heading=False,
        include_times_footer=False,
        include_helvetica_copyright=False,
    )
    score = EnciclopediaModernaProfile.matches(signals)
    assert score < 0.6


def test_matches_drops_below_threshold_on_palatino_body() -> None:
    """Codici Giuffrè / Tesauro / Mosconi use PalatinoLinotype — must not collide."""
    signals = _moderna_signals(
        body_family="PalatinoLinotype",
        include_note_family=False,
        include_bold_heading=False,
        include_times_footer=False,
        include_helvetica_copyright=False,
    )
    score = EnciclopediaModernaProfile.matches(signals)
    assert score < 0.6


def test_matches_drops_below_threshold_on_low_body_dominance() -> None:
    """Below the 30% body dominance floor the body signal is not credited."""
    signals = _moderna_signals(
        body_dominance=10.0,
        include_note_family=False,
        include_bold_heading=False,
        include_times_footer=False,
        include_helvetica_copyright=False,
    )
    score = EnciclopediaModernaProfile.matches(signals)
    assert score < 0.6


def test_matches_drops_below_threshold_on_marginal_apparatus() -> None:
    """Mosconi/Mandrioli/Torrente/BIC carry substantial marginal apparatus
    (hundreds to thousands of marginal headings).
    """
    signals = _moderna_signals(marginal_headings=500)
    score = EnciclopediaModernaProfile.matches(signals)
    # 500 marginal headings is well above the 200 threshold; penalty fires.
    assert score < 0.85


def test_matches_no_marginal_penalty_on_edd_apparatus_density() -> None:
    """An EdD moderna fixture with ~60 marginal-like blocks (two-column
    note layout) must NOT trigger the marginal penalty; the threshold is
    set high enough (200) to exclude legitimate note columns.
    """
    signals = _moderna_signals(marginal_headings=60)
    score = EnciclopediaModernaProfile.matches(signals)
    assert score == pytest.approx(0.85)


def test_matches_credits_note_family_present() -> None:
    with_notes = _moderna_signals(include_note_family=True)
    without = _moderna_signals(include_note_family=False)
    assert EnciclopediaModernaProfile.matches(with_notes) > EnciclopediaModernaProfile.matches(
        without
    )


def test_matches_credits_bold_heading_present() -> None:
    with_bold = _moderna_signals(include_bold_heading=True)
    without = _moderna_signals(include_bold_heading=False)
    assert EnciclopediaModernaProfile.matches(with_bold) > EnciclopediaModernaProfile.matches(
        without
    )


def test_matches_credits_times_footer_present() -> None:
    with_footer = _moderna_signals(include_times_footer=True)
    without = _moderna_signals(include_times_footer=False)
    assert EnciclopediaModernaProfile.matches(with_footer) > EnciclopediaModernaProfile.matches(
        without
    )


def test_matches_credits_helvetica_copyright_present() -> None:
    with_helvetica = _moderna_signals(include_helvetica_copyright=True)
    without = _moderna_signals(include_helvetica_copyright=False)
    assert EnciclopediaModernaProfile.matches(with_helvetica) > EnciclopediaModernaProfile.matches(
        without
    )


def test_matches_credits_page_geometry() -> None:
    """In-envelope geometry credits +0.05."""
    in_env = _moderna_signals(width_pt=481.89, height_pt=680.32)
    out_env = _moderna_signals(width_pt=595.0, height_pt=842.0)
    assert EnciclopediaModernaProfile.matches(in_env) > EnciclopediaModernaProfile.matches(out_env)


def test_matches_accepts_504_725_aggiornamenti_geometry() -> None:
    """The Aggiornamenti pre-2014 geometry (504x725) is inside the envelope."""
    signals = _moderna_signals(width_pt=504.6, height_pt=725.7)
    score = EnciclopediaModernaProfile.matches(signals)
    assert score >= 0.6


def test_matches_accepts_482_699_tematici_geometry() -> None:
    """The Tematici/Annali geometry (482x699) is inside the envelope."""
    signals = _moderna_signals(width_pt=481.89, height_pt=698.74)
    score = EnciclopediaModernaProfile.matches(signals)
    assert score >= 0.6


def test_matches_returns_non_negative() -> None:
    """Even with multiple penalties, the score floors at 0.0."""
    signals = _moderna_signals(
        body_family="OpenSans-Regular",
        body_dominance=5.0,
        include_note_family=False,
        include_bold_heading=False,
        include_times_footer=False,
        include_helvetica_copyright=False,
        width_pt=400.0,
        height_pt=400.0,
        marginal_headings=200,
    )
    score = EnciclopediaModernaProfile.matches(signals)
    assert score == 0.0


def test_matches_zero_on_empty_signature() -> None:
    signals = ProfilingSignals(
        typographic_signature=TypographicSignature(fonts=[]),
        apparatus_presence=ApparatusPresence(),
        page_geometry=ProfilePageGeometry(width_pt=400.0, height_pt=400.0),
        producer_creator=ProducerCreator(),
        outline_structure=OutlineStructure(),
        specific_markers=[],
    )
    score = EnciclopediaModernaProfile.matches(signals)
    assert score == 0.0


def test_matches_distiller_2001_pipeline_clears_threshold() -> None:
    """The Acrobat Distiller 4.0 pipeline (Giudizio fixture) must still clear."""
    signals = _moderna_signals(producer="Acrobat Distiller 4.0 for Windows")
    score = EnciclopediaModernaProfile.matches(signals)
    assert score >= 0.6


def test_matches_pdflib_aggiornamenti_pipeline_clears_threshold() -> None:
    """The PDFlib+PDI 9.x pipeline (Mare/Aggiornamenti) must still clear."""
    signals = _moderna_signals(
        producer="PDFlib+PDI 9.2.0 (Win64)",
        creator="Adobe Acrobat Pro 11.0.7",
    )
    score = EnciclopediaModernaProfile.matches(signals)
    assert score >= 0.6


def test_matches_empty_producer_melchionda_clears() -> None:
    """Melchionda Agg. I 1997 has empty producer — must still clear."""
    signals = _moderna_signals(producer="", creator="")
    score = EnciclopediaModernaProfile.matches(signals)
    assert score >= 0.6


# ---------------------------------------------------------------------------
# Section 4: predicate cascade


def test_is_drop_cap_recognises_single_letter() -> None:
    spans = [_make_span("A", size=35.92, font=SIMONCINI_REGULAR_FAMILY)]
    view = _make_view(spans)
    assert EnciclopediaModernaProfile._is_letter_initial_drop_cap(view)


def test_is_drop_cap_rejects_small_size() -> None:
    spans = [_make_span("A", size=BODY_SIZE)]
    view = _make_view(spans)
    assert not EnciclopediaModernaProfile._is_letter_initial_drop_cap(view)


def test_is_drop_cap_rejects_multi_char() -> None:
    spans = [_make_span("AB", size=35.92)]
    view = _make_view(spans)
    assert not EnciclopediaModernaProfile._is_letter_initial_drop_cap(view)


def test_is_drop_cap_rejects_lowercase() -> None:
    spans = [_make_span("a", size=35.92)]
    view = _make_view(spans)
    assert not EnciclopediaModernaProfile._is_letter_initial_drop_cap(view)


def test_is_drop_cap_rejects_non_simoncini_family() -> None:
    spans = [_make_span("A", size=35.92, font="OpenSans-Regular")]
    view = _make_view(spans)
    assert not EnciclopediaModernaProfile._is_letter_initial_drop_cap(view)


def test_is_drop_cap_rejects_empty_spans() -> None:
    view = _BlockView(block_index=0, block=_make_block(), spans=(), text="")
    assert not EnciclopediaModernaProfile._is_letter_initial_drop_cap(view)


def test_is_footer_ente_recognises_canonical() -> None:
    spans = [
        _make_span(
            "Enciclopedia del Diritto — Aggiornamento II — 1998",
            font=TIMES_NEW_ROMAN_FAMILY,
            size=12.0,
        )
    ]
    view = _make_view(spans)
    assert EnciclopediaModernaProfile._is_footer_ente(view)


def test_is_footer_ente_rejects_non_times_family() -> None:
    spans = [_make_span("Enciclopedia del Diritto", font=SIMONCINI_REGULAR_FAMILY, size=12.0)]
    view = _make_view(spans)
    assert not EnciclopediaModernaProfile._is_footer_ente(view)


def test_is_footer_ente_rejects_text_mismatch() -> None:
    spans = [_make_span("Other text", font=TIMES_NEW_ROMAN_FAMILY, size=12.0)]
    view = _make_view(spans)
    assert not EnciclopediaModernaProfile._is_footer_ente(view)


def test_is_footer_ente_rejects_empty_spans() -> None:
    view = _BlockView(block_index=0, block=_make_block(), spans=(), text="")
    assert not EnciclopediaModernaProfile._is_footer_ente(view)


def test_is_copyright_stamp_recognises_copyright_giuffre() -> None:
    spans = [
        _make_span(
            "Copyright Giuffrè Editore — RIPRODUZIONE RISERVATA",
            font="Helvetica-Bold",
            size=COPYRIGHT_SIZE,
        )
    ]
    view = _make_view(spans)
    assert EnciclopediaModernaProfile._is_copyright_stamp(view)


def test_is_copyright_stamp_recognises_riproduzione_riservata() -> None:
    spans = [_make_span("... RIPRODUZIONE RISERVATA", font="Helvetica-Bold", size=COPYRIGHT_SIZE)]
    view = _make_view(spans)
    assert EnciclopediaModernaProfile._is_copyright_stamp(view)


def test_is_copyright_stamp_rejects_wrong_family() -> None:
    spans = [
        _make_span("Copyright Giuffrè Editore", font=SIMONCINI_REGULAR_FAMILY, size=COPYRIGHT_SIZE)
    ]
    view = _make_view(spans)
    assert not EnciclopediaModernaProfile._is_copyright_stamp(view)


def test_is_copyright_stamp_rejects_wrong_size() -> None:
    spans = [_make_span("Copyright Giuffrè", font="Helvetica-Bold", size=12.0)]
    view = _make_view(spans)
    assert not EnciclopediaModernaProfile._is_copyright_stamp(view)


def test_is_copyright_stamp_rejects_text_mismatch() -> None:
    spans = [_make_span("not a copyright line", font="Helvetica-Bold", size=COPYRIGHT_SIZE)]
    view = _make_view(spans)
    assert not EnciclopediaModernaProfile._is_copyright_stamp(view)


def test_is_copyright_stamp_rejects_empty_spans() -> None:
    view = _BlockView(block_index=0, block=_make_block(), spans=(), text="")
    assert not EnciclopediaModernaProfile._is_copyright_stamp(view)


def test_is_fonti_label_recognises_canonical_dash() -> None:
    spans = [_make_span("FONTI. — Art. 1; art. 2.", font=SIMONCINI_BOLD_FAMILY, size=BODY_SIZE)]
    view = _make_view(spans)
    assert EnciclopediaModernaProfile._is_fonti_label(view)


def test_is_fonti_label_recognises_ascii_hyphen() -> None:
    spans = [_make_span("FONTI. - Art. 1; art. 2.", font=SIMONCINI_BOLD_FAMILY, size=BODY_SIZE)]
    view = _make_view(spans)
    assert EnciclopediaModernaProfile._is_fonti_label(view)


def test_is_fonti_label_rejects_non_bold() -> None:
    spans = [_make_span("FONTI. — Art. 1", font=SIMONCINI_REGULAR_FAMILY, size=BODY_SIZE)]
    view = _make_view(spans)
    assert not EnciclopediaModernaProfile._is_fonti_label(view)


def test_is_fonti_label_rejects_text_mismatch() -> None:
    spans = [_make_span("Other heading", font=SIMONCINI_BOLD_FAMILY, size=BODY_SIZE)]
    view = _make_view(spans)
    assert not EnciclopediaModernaProfile._is_fonti_label(view)


def test_is_fonti_label_rejects_empty_spans() -> None:
    view = _BlockView(block_index=0, block=_make_block(), spans=(), text="")
    assert not EnciclopediaModernaProfile._is_fonti_label(view)


def test_is_letteratura_label_recognises_canonical() -> None:
    spans = [
        _make_span("LETTERATURA. — ASCARELLI, Studi...", font=SIMONCINI_BOLD_FAMILY, size=BODY_SIZE)
    ]
    view = _make_view(spans)
    assert EnciclopediaModernaProfile._is_letteratura_label(view)


def test_is_letteratura_label_rejects_non_bold() -> None:
    spans = [_make_span("LETTERATURA. — ASCARELLI", font=SIMONCINI_REGULAR_FAMILY, size=BODY_SIZE)]
    view = _make_view(spans)
    assert not EnciclopediaModernaProfile._is_letteratura_label(view)


def test_is_letteratura_label_rejects_empty_spans() -> None:
    view = _BlockView(block_index=0, block=_make_block(), spans=(), text="")
    assert not EnciclopediaModernaProfile._is_letteratura_label(view)


def test_is_sommario_recognises_three_span_pattern() -> None:
    spans = [
        _make_span("S", font=SIMONCINI_REGULAR_FAMILY, size=SOMMARIO_SIZE),
        _make_span("OMMARIO", font=SIMONCINI_REGULAR_FAMILY, size=APICE_SIZE),
        _make_span(
            ": 1. Intro. — 2. Sviluppi.",
            font=SIMONCINI_REGULAR_FAMILY,
            size=SOMMARIO_SIZE,
        ),
    ]
    view = _make_view(spans)
    assert EnciclopediaModernaProfile._is_sommario(view)


def test_is_sommario_recognises_inline_sommario() -> None:
    """Some pipelines emit ``"Sommario."`` as a single span."""
    spans = [_make_span("Sommario. — 1. Intro.", font=SIMONCINI_REGULAR_FAMILY, size=SOMMARIO_SIZE)]
    view = _make_view(spans)
    assert EnciclopediaModernaProfile._is_sommario(view)


def test_is_sommario_rejects_wrong_size() -> None:
    spans = [_make_span("SOMMARIO:", font=SIMONCINI_REGULAR_FAMILY, size=BODY_SIZE)]
    view = _make_view(spans)
    assert not EnciclopediaModernaProfile._is_sommario(view)


def test_is_sommario_rejects_wrong_family() -> None:
    spans = [_make_span("SOMMARIO:", font="OpenSans-Regular", size=SOMMARIO_SIZE)]
    view = _make_view(spans)
    assert not EnciclopediaModernaProfile._is_sommario(view)


def test_is_sommario_rejects_empty_spans() -> None:
    view = _BlockView(block_index=0, block=_make_block(), spans=(), text="")
    assert not EnciclopediaModernaProfile._is_sommario(view)


def test_is_sezione_heading_recognises_canonical() -> None:
    spans = [_make_span("Sez. I. Premesse generali.", font=SIMONCINI_BOLD_FAMILY, size=BODY_SIZE)]
    view = _make_view(spans)
    assert EnciclopediaModernaProfile._is_sezione_heading(view)


def test_is_sezione_heading_recognises_high_roman() -> None:
    spans = [
        _make_span("Sez. XXIII. Disposizioni finali.", font=SIMONCINI_BOLD_FAMILY, size=BODY_SIZE)
    ]
    view = _make_view(spans)
    assert EnciclopediaModernaProfile._is_sezione_heading(view)


def test_is_sezione_heading_rejects_non_bold() -> None:
    spans = [_make_span("Sez. I. Title", font=SIMONCINI_REGULAR_FAMILY, size=BODY_SIZE)]
    view = _make_view(spans)
    assert not EnciclopediaModernaProfile._is_sezione_heading(view)


def test_is_sezione_heading_rejects_no_dot() -> None:
    spans = [_make_span("Sez I Title", font=SIMONCINI_BOLD_FAMILY, size=BODY_SIZE)]
    view = _make_view(spans)
    assert not EnciclopediaModernaProfile._is_sezione_heading(view)


def test_is_sezione_heading_rejects_empty_spans() -> None:
    view = _BlockView(block_index=0, block=_make_block(), spans=(), text="")
    assert not EnciclopediaModernaProfile._is_sezione_heading(view)


def test_is_paragraph_heading_recognises_one_digit() -> None:
    spans = [_make_span("1. Premesse.", font=SIMONCINI_BOLD_FAMILY, size=BODY_SIZE)]
    view = _make_view(spans)
    assert EnciclopediaModernaProfile._is_paragraph_heading(view)


def test_is_paragraph_heading_recognises_three_digits() -> None:
    spans = [_make_span("123. Disposizioni.", font=SIMONCINI_BOLD_FAMILY, size=BODY_SIZE)]
    view = _make_view(spans)
    assert EnciclopediaModernaProfile._is_paragraph_heading(view)


def test_is_paragraph_heading_rejects_non_bold() -> None:
    spans = [_make_span("1. Premesse.", font=SIMONCINI_REGULAR_FAMILY, size=BODY_SIZE)]
    view = _make_view(spans)
    assert not EnciclopediaModernaProfile._is_paragraph_heading(view)


def test_is_paragraph_heading_rejects_text_mismatch() -> None:
    spans = [_make_span("text body prose", font=SIMONCINI_BOLD_FAMILY, size=BODY_SIZE)]
    view = _make_view(spans)
    assert not EnciclopediaModernaProfile._is_paragraph_heading(view)


def test_is_paragraph_heading_rejects_empty_spans() -> None:
    view = _BlockView(block_index=0, block=_make_block(), spans=(), text="")
    assert not EnciclopediaModernaProfile._is_paragraph_heading(view)


def test_is_voce_title_recognises_page_1_bold() -> None:
    spans = [
        _make_span(
            "ABUSO DI POSIZIONE DOMINANTE", font=SIMONCINI_BOLD_FAMILY, size=BODY_SIZE, page=0
        )
    ]
    view = _make_view(spans, page=0)
    assert EnciclopediaModernaProfile._is_voce_title(view)


def test_is_voce_title_rejects_page_2_bold() -> None:
    """A bold block on page > 0 is not the voce title (could be a heading)."""
    spans = [_make_span("Title-like", font=SIMONCINI_BOLD_FAMILY, size=BODY_SIZE, page=1)]
    view = _make_view(spans, page=1)
    assert not EnciclopediaModernaProfile._is_voce_title(view)


def test_is_voce_title_rejects_numbered_paragraph_pattern() -> None:
    spans = [_make_span("1. Heading", font=SIMONCINI_BOLD_FAMILY, size=BODY_SIZE, page=0)]
    view = _make_view(spans, page=0)
    assert not EnciclopediaModernaProfile._is_voce_title(view)


def test_is_voce_title_rejects_fonti_pattern() -> None:
    spans = [_make_span("FONTI. — Art. 1", font=SIMONCINI_BOLD_FAMILY, size=BODY_SIZE, page=0)]
    view = _make_view(spans, page=0)
    assert not EnciclopediaModernaProfile._is_voce_title(view)


def test_is_voce_title_rejects_letteratura_pattern() -> None:
    spans = [_make_span("LETTERATURA. —", font=SIMONCINI_BOLD_FAMILY, size=BODY_SIZE, page=0)]
    view = _make_view(spans, page=0)
    assert not EnciclopediaModernaProfile._is_voce_title(view)


def test_is_voce_title_rejects_sezione_pattern() -> None:
    spans = [_make_span("Sez. I. Premesse.", font=SIMONCINI_BOLD_FAMILY, size=BODY_SIZE, page=0)]
    view = _make_view(spans, page=0)
    assert not EnciclopediaModernaProfile._is_voce_title(view)


def test_is_voce_title_rejects_lowercase_start() -> None:
    spans = [_make_span("lowercase content", font=SIMONCINI_BOLD_FAMILY, size=BODY_SIZE, page=0)]
    view = _make_view(spans, page=0)
    assert not EnciclopediaModernaProfile._is_voce_title(view)


def test_is_voce_title_rejects_empty_spans() -> None:
    block = _make_block(page=0, span_range=(0, 0))
    view = _BlockView(block_index=0, block=block, spans=(), text="")
    assert not EnciclopediaModernaProfile._is_voce_title(view)


def test_is_voce_title_rejects_empty_text() -> None:
    spans = [_make_span("  ", font=SIMONCINI_BOLD_FAMILY, size=BODY_SIZE, page=0)]
    view = _make_view(spans, page=0)
    assert not EnciclopediaModernaProfile._is_voce_title(view)


def test_is_note_recognises_regular() -> None:
    spans = [_make_span("(1) Nota content.", font=SIMONCINI_REGULAR_FAMILY, size=NOTE_SIZE)]
    view = _make_view(spans)
    assert EnciclopediaModernaProfile._is_note(view)


def test_is_note_recognises_italic() -> None:
    spans = [_make_span("Italic nota.", font=SIMONCINI_ITALIC_FAMILY, size=NOTE_SIZE)]
    view = _make_view(spans)
    assert EnciclopediaModernaProfile._is_note(view)


def test_is_note_rejects_body_size() -> None:
    spans = [_make_span("Not a note.", font=SIMONCINI_REGULAR_FAMILY, size=BODY_SIZE)]
    view = _make_view(spans)
    assert not EnciclopediaModernaProfile._is_note(view)


def test_is_note_rejects_wrong_family() -> None:
    spans = [_make_span("Note?", font="OpenSans-Regular", size=NOTE_SIZE)]
    view = _make_view(spans)
    assert not EnciclopediaModernaProfile._is_note(view)


def test_is_note_rejects_empty_spans() -> None:
    view = _BlockView(block_index=0, block=_make_block(), spans=(), text="")
    assert not EnciclopediaModernaProfile._is_note(view)


def test_is_body_recognises_regular() -> None:
    spans = [_make_span("Body prose.", font=SIMONCINI_REGULAR_FAMILY, size=BODY_SIZE)]
    view = _make_view(spans)
    assert EnciclopediaModernaProfile._is_body(view)


def test_is_body_recognises_italic_body() -> None:
    spans = [_make_span("Italic body.", font=SIMONCINI_ITALIC_FAMILY, size=BODY_SIZE)]
    view = _make_view(spans)
    assert EnciclopediaModernaProfile._is_body(view)


def test_is_body_rejects_note_size() -> None:
    spans = [_make_span("(1)", font=SIMONCINI_REGULAR_FAMILY, size=NOTE_SIZE)]
    view = _make_view(spans)
    assert not EnciclopediaModernaProfile._is_body(view)


def test_is_body_rejects_wrong_family() -> None:
    spans = [_make_span("body?", font="OpenSans-Regular", size=BODY_SIZE)]
    view = _make_view(spans)
    assert not EnciclopediaModernaProfile._is_body(view)


def test_is_body_rejects_empty_spans() -> None:
    view = _BlockView(block_index=0, block=_make_block(), spans=(), text="")
    assert not EnciclopediaModernaProfile._is_body(view)


# ---------------------------------------------------------------------------
# Section 5: refine_classification end-to-end


def test_refine_classification_promotes_drop_cap_to_letter_initial() -> None:
    spans = [_make_span("A", size=35.92)]
    blocks = [_make_block(span_range=(0, 1))]
    extraction = _make_extraction(spans, blocks)
    plugin = EnciclopediaModernaProfile()
    refined = plugin.refine_classification(extraction, [_verdict(0)])
    assert refined[0].category is SemanticCategory.HEADING_LETTER_INITIAL


def test_refine_classification_promotes_footer_ente() -> None:
    spans = [
        _make_span(
            "Enciclopedia del Diritto — Aggiornamento II — 1998",
            font=TIMES_NEW_ROMAN_FAMILY,
            size=12.0,
        )
    ]
    blocks = [_make_block(span_range=(0, 1))]
    extraction = _make_extraction(spans, blocks)
    plugin = EnciclopediaModernaProfile()
    refined = plugin.refine_classification(extraction, [_verdict(0)])
    assert refined[0].category is SemanticCategory.ARTIFACT_FOOTER


def test_refine_classification_promotes_copyright_stamp() -> None:
    spans = [
        _make_span(
            "Copyright Giuffrè Editore",
            font="Helvetica-Bold",
            size=COPYRIGHT_SIZE,
        )
    ]
    blocks = [_make_block(span_range=(0, 1))]
    extraction = _make_extraction(spans, blocks)
    plugin = EnciclopediaModernaProfile()
    refined = plugin.refine_classification(extraction, [_verdict(0)])
    assert refined[0].category is SemanticCategory.ARTIFACT_STAMP


def test_refine_classification_promotes_fonti_to_section_label() -> None:
    spans = [_make_span("FONTI. — Art. 1; art. 2.", font=SIMONCINI_BOLD_FAMILY, size=BODY_SIZE)]
    blocks = [_make_block(span_range=(0, 1))]
    extraction = _make_extraction(spans, blocks)
    plugin = EnciclopediaModernaProfile()
    refined = plugin.refine_classification(extraction, [_verdict(0)])
    assert refined[0].category is SemanticCategory.SECTION_LABEL
    assert "fonti" in refined[0].reason


def test_refine_classification_promotes_letteratura_to_section_label() -> None:
    spans = [
        _make_span("LETTERATURA. — ASCARELLI, Studi", font=SIMONCINI_BOLD_FAMILY, size=BODY_SIZE)
    ]
    blocks = [_make_block(span_range=(0, 1))]
    extraction = _make_extraction(spans, blocks)
    plugin = EnciclopediaModernaProfile()
    refined = plugin.refine_classification(extraction, [_verdict(0)])
    assert refined[0].category is SemanticCategory.SECTION_LABEL
    assert "letteratura" in refined[0].reason


def test_refine_classification_promotes_sezione_to_heading_2() -> None:
    spans = [_make_span("Sez. I. Premesse.", font=SIMONCINI_BOLD_FAMILY, size=BODY_SIZE)]
    blocks = [_make_block(span_range=(0, 1))]
    extraction = _make_extraction(spans, blocks)
    plugin = EnciclopediaModernaProfile()
    refined = plugin.refine_classification(extraction, [_verdict(0)])
    assert refined[0].category is SemanticCategory.HEADING_2


def test_refine_classification_promotes_paragraph_to_heading_1() -> None:
    spans = [_make_span("3. Concetti.", font=SIMONCINI_BOLD_FAMILY, size=BODY_SIZE)]
    blocks = [_make_block(span_range=(0, 1))]
    extraction = _make_extraction(spans, blocks)
    plugin = EnciclopediaModernaProfile()
    refined = plugin.refine_classification(extraction, [_verdict(0)])
    assert refined[0].category is SemanticCategory.HEADING_1


def test_refine_classification_promotes_voce_title() -> None:
    spans = [_make_span("ABUSO DI POSIZIONE DOMINANTE", font=SIMONCINI_BOLD_FAMILY, size=BODY_SIZE)]
    blocks = [_make_block(span_range=(0, 1))]
    extraction = _make_extraction(spans, blocks)
    plugin = EnciclopediaModernaProfile()
    refined = plugin.refine_classification(extraction, [_verdict(0)])
    assert refined[0].category is SemanticCategory.TITLE


def test_refine_classification_promotes_note() -> None:
    spans = [_make_span("(1) Nota a piè.", font=SIMONCINI_REGULAR_FAMILY, size=NOTE_SIZE)]
    blocks = [_make_block(span_range=(0, 1))]
    extraction = _make_extraction(spans, blocks)
    plugin = EnciclopediaModernaProfile()
    refined = plugin.refine_classification(extraction, [_verdict(0)])
    assert refined[0].category is SemanticCategory.NOTE


def test_refine_classification_promotes_body() -> None:
    spans = [_make_span("Body prose.", font=SIMONCINI_REGULAR_FAMILY, size=BODY_SIZE)]
    blocks = [_make_block(span_range=(0, 1))]
    extraction = _make_extraction(spans, blocks)
    plugin = EnciclopediaModernaProfile()
    refined = plugin.refine_classification(extraction, [_verdict(0)])
    assert refined[0].category is SemanticCategory.BODY


def test_refine_classification_promotes_sommario_to_toc_general() -> None:
    spans = [
        _make_span("S", font=SIMONCINI_REGULAR_FAMILY, size=SOMMARIO_SIZE),
        _make_span("OMMARIO", font=SIMONCINI_REGULAR_FAMILY, size=APICE_SIZE),
        _make_span(": 1. Intro. — 2. Sviluppi.", font=SIMONCINI_REGULAR_FAMILY, size=SOMMARIO_SIZE),
    ]
    blocks = [_make_block(span_range=(0, 3))]
    extraction = _make_extraction(spans, blocks)
    plugin = EnciclopediaModernaProfile()
    refined = plugin.refine_classification(extraction, [_verdict(0)])
    assert refined[0].category is SemanticCategory.TOC_GENERAL


def test_refine_classification_preserves_negative_block_index() -> None:
    """Synthetic verdicts (block_index < 0, e.g. EMPTY_PAGE) pass through."""
    plugin = EnciclopediaModernaProfile()
    verdicts = [_verdict(-1, SemanticCategory.EMPTY_PAGE)]
    refined = plugin.refine_classification(_make_extraction([], []), verdicts)
    assert refined[0].category is SemanticCategory.EMPTY_PAGE


def test_refine_classification_preserves_missing_block() -> None:
    """A block_index pointing at a block with no spans passes through."""
    blocks = [_make_block(span_range=(0, 0))]
    extraction = _make_extraction([], blocks)
    plugin = EnciclopediaModernaProfile()
    refined = plugin.refine_classification(extraction, [_verdict(0, SemanticCategory.UNCLASSIFIED)])
    assert refined[0].category is SemanticCategory.UNCLASSIFIED


def test_refine_classification_retags_body_inside_fonti_region() -> None:
    spans = [
        _make_span("FONTI. — Art. 1.", font=SIMONCINI_BOLD_FAMILY, size=BODY_SIZE),
        _make_span("Art. 2 c.c.; art. 3.", font=SIMONCINI_REGULAR_FAMILY, size=BODY_SIZE),
        _make_span("Art. 4 ulteriori.", font=SIMONCINI_REGULAR_FAMILY, size=BODY_SIZE),
    ]
    blocks = [
        _make_block(span_range=(0, 1), block_index=0),
        _make_block(span_range=(1, 2), block_index=1),
        _make_block(span_range=(2, 3), block_index=2),
    ]
    extraction = _make_extraction(spans, blocks)
    plugin = EnciclopediaModernaProfile()
    refined = plugin.refine_classification(
        extraction,
        [_verdict(0), _verdict(1, SemanticCategory.BODY), _verdict(2, SemanticCategory.BODY)],
    )
    assert refined[0].category is SemanticCategory.SECTION_LABEL
    assert refined[1].category is SemanticCategory.FONTI
    assert refined[2].category is SemanticCategory.FONTI


def test_refine_classification_retags_body_inside_letteratura_region() -> None:
    spans = [
        _make_span("LETTERATURA. — ASCARELLI", font=SIMONCINI_BOLD_FAMILY, size=BODY_SIZE),
        _make_span("ASQUINI, Profili", font=SIMONCINI_REGULAR_FAMILY, size=BODY_SIZE),
    ]
    blocks = [
        _make_block(span_range=(0, 1), block_index=0),
        _make_block(span_range=(1, 2), block_index=1),
    ]
    extraction = _make_extraction(spans, blocks)
    plugin = EnciclopediaModernaProfile()
    refined = plugin.refine_classification(
        extraction, [_verdict(0), _verdict(1, SemanticCategory.BODY)]
    )
    assert refined[0].category is SemanticCategory.SECTION_LABEL
    assert refined[1].category is SemanticCategory.LETTERATURA


def test_refine_classification_letteratura_closes_fonti_region() -> None:
    spans = [
        _make_span("FONTI. — Art. 1.", font=SIMONCINI_BOLD_FAMILY, size=BODY_SIZE),
        _make_span("Art. 2 c.c.", font=SIMONCINI_REGULAR_FAMILY, size=BODY_SIZE),
        _make_span("LETTERATURA. —", font=SIMONCINI_BOLD_FAMILY, size=BODY_SIZE),
        _make_span("BIBLIO entry.", font=SIMONCINI_REGULAR_FAMILY, size=BODY_SIZE),
    ]
    blocks = [
        _make_block(span_range=(0, 1), block_index=0),
        _make_block(span_range=(1, 2), block_index=1),
        _make_block(span_range=(2, 3), block_index=2),
        _make_block(span_range=(3, 4), block_index=3),
    ]
    extraction = _make_extraction(spans, blocks)
    plugin = EnciclopediaModernaProfile()
    refined = plugin.refine_classification(
        extraction,
        [
            _verdict(0),
            _verdict(1, SemanticCategory.BODY),
            _verdict(2),
            _verdict(3, SemanticCategory.BODY),
        ],
    )
    assert refined[1].category is SemanticCategory.FONTI
    assert refined[3].category is SemanticCategory.LETTERATURA


def test_refine_classification_heading_closes_region() -> None:
    """A subsequent HEADING_1 closes the FONTI region (false positive guard)."""
    spans = [
        _make_span("FONTI. — Art. 1.", font=SIMONCINI_BOLD_FAMILY, size=BODY_SIZE),
        _make_span("Art. 2.", font=SIMONCINI_REGULAR_FAMILY, size=BODY_SIZE),
        _make_span("5. New section.", font=SIMONCINI_BOLD_FAMILY, size=BODY_SIZE),
        _make_span("Body after.", font=SIMONCINI_REGULAR_FAMILY, size=BODY_SIZE),
    ]
    blocks = [_make_block(span_range=(i, i + 1), block_index=i) for i in range(4)]
    extraction = _make_extraction(spans, blocks)
    plugin = EnciclopediaModernaProfile()
    refined = plugin.refine_classification(
        extraction,
        [
            _verdict(0),
            _verdict(1, SemanticCategory.BODY),
            _verdict(2),
            _verdict(3, SemanticCategory.BODY),
        ],
    )
    assert refined[1].category is SemanticCategory.FONTI
    assert refined[2].category is SemanticCategory.HEADING_1
    assert refined[3].category is SemanticCategory.BODY


def test_refine_classification_emits_fonti_letteratura_warnings() -> None:
    spans = [
        _make_span("FONTI. — Art. 1.", font=SIMONCINI_BOLD_FAMILY, size=BODY_SIZE),
        _make_span("LETTERATURA. — Asca", font=SIMONCINI_BOLD_FAMILY, size=BODY_SIZE),
    ]
    blocks = [_make_block(span_range=(i, i + 1), block_index=i) for i in range(2)]
    extraction = _make_extraction(spans, blocks)
    plugin = EnciclopediaModernaProfile()
    plugin.refine_classification(extraction, [_verdict(0), _verdict(1)])
    pending = plugin._pending_warnings
    assert any("fonti_section_opened" in w for w in pending)
    assert any("letteratura_section_opened" in w for w in pending)


def test_refine_classification_emits_drop_cap_warning() -> None:
    spans = [_make_span("A", size=35.92)]
    blocks = [_make_block(span_range=(0, 1))]
    extraction = _make_extraction(spans, blocks)
    plugin = EnciclopediaModernaProfile()
    plugin.refine_classification(extraction, [_verdict(0)])
    assert any("drop_cap_letter_initial" in w for w in plugin._pending_warnings)


def test_refine_classification_unclassified_preserved_on_no_match() -> None:
    spans = [_make_span("???", font="OpenSans-Regular", size=99.0)]
    blocks = [_make_block(span_range=(0, 1))]
    extraction = _make_extraction(spans, blocks)
    plugin = EnciclopediaModernaProfile()
    refined = plugin.refine_classification(extraction, [_verdict(0)])
    assert refined[0].category is SemanticCategory.UNCLASSIFIED


# ---------------------------------------------------------------------------
# Section 6: refine_reconstruction — TOC parsing


def test_parse_toc_general_simple() -> None:
    plugin = EnciclopediaModernaProfile()
    node = Node(
        id="node_0001",
        category=SemanticCategory.TOC_GENERAL,
        page_index=0,
        block_indices=(0,),
        text="SOMMARIO: 1. Intro. — 2. Sviluppi. — 3. Conclusioni.",
    )
    warnings: list[str] = []
    out = plugin._parse_toc_general(node, warnings)
    assert len(out) == 1
    assert out[0].toc_items is not None
    items = out[0].toc_items
    assert items is not None
    assert len(items) == 3
    assert items[0].number == "1"
    assert items[0].title == "Intro"
    assert items[1].title == "Sviluppi"
    assert items[2].title == "Conclusioni"


def test_parse_toc_general_composite_numbers() -> None:
    """Composite numbers like ``1.1`` are preserved."""
    plugin = EnciclopediaModernaProfile()
    node = Node(
        id="node_0001",
        category=SemanticCategory.TOC_GENERAL,
        page_index=0,
        block_indices=(0,),
        text="SOMMARIO: 1.1. Sub-topic A. — 1.2. Sub-topic B.",
    )
    warnings: list[str] = []
    out = plugin._parse_toc_general(node, warnings)
    items = out[0].toc_items
    assert items is not None
    assert items[0].number == "1.1"
    assert items[1].number == "1.2"


def test_parse_toc_general_unparseable_emits_warning() -> None:
    """A TOC with no parseable entries emits a warning and preserves the node."""
    plugin = EnciclopediaModernaProfile()
    node = Node(
        id="node_0002",
        category=SemanticCategory.TOC_GENERAL,
        page_index=0,
        block_indices=(0,),
        text="No items here just prose.",
    )
    warnings: list[str] = []
    out = plugin._parse_toc_general(node, warnings)
    assert out == [node]
    assert any("toc_general_unparseable" in w for w in warnings)


def test_parse_toc_general_emits_parsed_warning() -> None:
    plugin = EnciclopediaModernaProfile()
    node = Node(
        id="node_0003",
        category=SemanticCategory.TOC_GENERAL,
        page_index=0,
        block_indices=(0,),
        text="SOMMARIO: 1. Topic.",
    )
    warnings: list[str] = []
    plugin._parse_toc_general(node, warnings)
    assert any("toc_general_parsed" in w and "items_1" in w for w in warnings)


# ---------------------------------------------------------------------------
# Section 7: refine_reconstruction — CR minting (numbered)


def test_mint_inline_note_crossref_in_body() -> None:
    plugin = EnciclopediaModernaProfile()
    node = Node(
        id="node_0001",
        category=SemanticCategory.BODY,
        page_index=2,
        block_indices=(5,),
        text="Cita la nota (3) e poi prosegue.",
    )
    warnings: list[str] = []
    minter = _NodeIdMinter(start=100)
    out = plugin._maybe_mint_cross_references(node, warnings, minter)
    assert len(out) == 2
    assert out[0] is node
    assert out[1].category is SemanticCategory.CROSS_REFERENCE
    assert out[1].text == "(3)"
    assert out[1].id == "node_0100"
    assert any("cross_reference_note_minted" in w for w in warnings)


def test_mint_no_crossref_when_no_marker() -> None:
    plugin = EnciclopediaModernaProfile()
    node = Node(
        id="node_0001",
        category=SemanticCategory.BODY,
        page_index=0,
        block_indices=(0,),
        text="No marker here.",
    )
    out = plugin._maybe_mint_cross_references(node, [], _NodeIdMinter(start=100))
    assert out == [node]


def test_mint_skips_year_references() -> None:
    """Magnitude cap filters ``(2024)``-shaped years."""
    plugin = EnciclopediaModernaProfile()
    node = Node(
        id="node_0001",
        category=SemanticCategory.BODY,
        page_index=0,
        block_indices=(0,),
        text="Riferimento (2024) e poi anche (12).",
    )
    warnings: list[str] = []
    out = plugin._maybe_mint_cross_references(node, warnings, _NodeIdMinter(start=100))
    minted = [n for n in out if n.category is SemanticCategory.CROSS_REFERENCE]
    assert len(minted) == 1
    assert minted[0].text == "(12)"


def test_mint_multiple_inline_note_crossref() -> None:
    plugin = EnciclopediaModernaProfile()
    node = Node(
        id="node_0001",
        category=SemanticCategory.BODY,
        page_index=0,
        block_indices=(0,),
        text="Vedi (3), (4) e infine (5).",
    )
    out = plugin._maybe_mint_cross_references(node, [], _NodeIdMinter(start=100))
    minted = [n for n in out if n.category is SemanticCategory.CROSS_REFERENCE]
    assert len(minted) == 3
    assert minted[0].text == "(3)"
    assert minted[1].text == "(4)"
    assert minted[2].text == "(5)"


def test_mint_returns_node_only_when_text_is_none() -> None:
    plugin = EnciclopediaModernaProfile()
    node = Node(
        id="node_0001",
        category=SemanticCategory.BODY,
        page_index=0,
        block_indices=(0,),
        text=None,
    )
    out = plugin._maybe_mint_cross_references(node, [], _NodeIdMinter(start=100))
    assert out == [node]


# ---------------------------------------------------------------------------
# Section 7b: refine_reconstruction — CR minting (voce)


def test_mint_inline_voce_crossref() -> None:
    plugin = EnciclopediaModernaProfile()
    node = Node(
        id="node_0001",
        category=SemanticCategory.BODY,
        page_index=0,
        block_indices=(0,),
        text="Per approfondimenti v. CONTRATTO PRELIMINARE, 2021 si rinvia.",
    )
    warnings: list[str] = []
    out = plugin._maybe_mint_cross_references(node, warnings, _NodeIdMinter(start=200))
    minted = [n for n in out if n.category is SemanticCategory.CROSS_REFERENCE]
    assert len(minted) == 1
    text = minted[0].text
    assert text is not None
    assert text.startswith("v.")
    assert "CONTRATTO PRELIMINARE" in text
    assert any("cross_reference_voce_minted" in w for w in warnings)


def test_mint_inline_voce_crossref_without_year() -> None:
    plugin = EnciclopediaModernaProfile()
    node = Node(
        id="node_0001",
        category=SemanticCategory.BODY,
        page_index=0,
        block_indices=(0,),
        text="Cfr. v. FATTO GIURIDICO e poi continua.",
    )
    out = plugin._maybe_mint_cross_references(node, [], _NodeIdMinter(start=200))
    minted = [n for n in out if n.category is SemanticCategory.CROSS_REFERENCE]
    assert len(minted) == 1
    text = minted[0].text
    assert text is not None
    assert "FATTO GIURIDICO" in text


def test_mint_inline_mixed_note_and_voce() -> None:
    plugin = EnciclopediaModernaProfile()
    node = Node(
        id="node_0001",
        category=SemanticCategory.BODY,
        page_index=0,
        block_indices=(0,),
        text="La nota (1) e poi v. CONTRATTO, 2021.",
    )
    out = plugin._maybe_mint_cross_references(node, [], _NodeIdMinter(start=300))
    minted = [n for n in out if n.category is SemanticCategory.CROSS_REFERENCE]
    assert len(minted) == 2
    # Note minted first, then voce per the predicate order.
    assert minted[0].text == "(1)"
    text1 = minted[1].text
    assert text1 is not None
    assert text1.startswith("v.")


# ---------------------------------------------------------------------------
# Section 8: refine_reconstruction end-to-end


def test_refine_reconstruction_no_changes_on_empty_document() -> None:
    plugin = EnciclopediaModernaProfile()
    doc = Document(root=(), warnings=(), transformations=())
    extraction = _make_extraction([], [])
    out = plugin.refine_reconstruction(doc, extraction, [])
    assert out.root == ()
    assert out.warnings == ()
    assert out.transformations == ()


def test_refine_reconstruction_mints_in_body_node() -> None:
    plugin = EnciclopediaModernaProfile()
    body = Node(
        id="node_0001",
        category=SemanticCategory.BODY,
        page_index=0,
        block_indices=(0,),
        text="Cita (1) nel testo.",
    )
    doc = Document(root=(body,), warnings=(), transformations=())
    extraction = _make_extraction([], [])
    out = plugin.refine_reconstruction(doc, extraction, [])
    crossrefs = [n for n in out.root if n.category is SemanticCategory.CROSS_REFERENCE]
    assert len(crossrefs) == 1


def test_refine_reconstruction_descends_into_children() -> None:
    plugin = EnciclopediaModernaProfile()
    child = Node(
        id="node_0002",
        category=SemanticCategory.BODY,
        page_index=0,
        block_indices=(1,),
        text="Vedi (2).",
    )
    parent = Node(
        id="node_0001",
        category=SemanticCategory.HEADING_1,
        page_index=0,
        block_indices=(0,),
        text="1. Intro.",
        children=(child,),
    )
    doc = Document(root=(parent,), warnings=(), transformations=())
    out = plugin.refine_reconstruction(doc, _make_extraction([], []), [])
    crossrefs = [
        n for r in out.root for n in r.children if n.category is SemanticCategory.CROSS_REFERENCE
    ]
    assert len(crossrefs) == 1


def test_refine_reconstruction_parses_toc_general() -> None:
    plugin = EnciclopediaModernaProfile()
    toc = Node(
        id="node_0001",
        category=SemanticCategory.TOC_GENERAL,
        page_index=0,
        block_indices=(0,),
        text="SOMMARIO: 1. Topic A. — 2. Topic B.",
    )
    doc = Document(root=(toc,), warnings=(), transformations=())
    out = plugin.refine_reconstruction(doc, _make_extraction([], []), [])
    assert out.root[0].toc_items is not None
    assert len(out.root[0].toc_items) == 2


def test_refine_reconstruction_propagates_pending_warnings() -> None:
    plugin = EnciclopediaModernaProfile()
    plugin._pending_warnings = [f"{WARNING_PREFIX}:drop_cap_letter_initial_block_0_page_0"]
    doc = Document(root=(), warnings=("prior_warning",), transformations=())
    out = plugin.refine_reconstruction(doc, _make_extraction([], []), [])
    assert "prior_warning" in out.warnings
    assert any("drop_cap_letter_initial" in w for w in out.warnings)


def test_refine_reconstruction_preserves_existing_transformations() -> None:
    plugin = EnciclopediaModernaProfile()
    from scabopdf_pipeline.postprocessing.types import Transformation

    existing = Transformation(
        step_id="prior",
        node_id="node_0001",
        page_index=0,
        position=(0, 5),
        original="abcde",
        normalized="abcde",
    )
    doc = Document(root=(), warnings=(), transformations=(existing,))
    out = plugin.refine_reconstruction(doc, _make_extraction([], []), [])
    assert existing in out.transformations


# ---------------------------------------------------------------------------
# Section 9: refine_apparatus


def test_refine_apparatus_binds_crossref_to_note() -> None:
    plugin = EnciclopediaModernaProfile()
    note = Node(
        id="node_0002",
        category=SemanticCategory.NOTE,
        page_index=0,
        block_indices=(1,),
        text="(1) Nota a piè.",
    )
    cr = Node(
        id="node_0010",
        category=SemanticCategory.CROSS_REFERENCE,
        page_index=0,
        block_indices=(0,),
        text="(1)",
    )
    plugin._minted_crossref_note_ids.add("node_0010")
    doc = Document(root=(note, cr), warnings=(), transformations=())
    out = plugin.refine_apparatus(doc, _make_extraction([], []), [])
    cr_after = next(n for n in out.root if n.id == "node_0010")
    assert len(cr_after.apparatus_refs) == 1
    assert cr_after.apparatus_refs[0].kind is ApparatusRefKind.CROSS_REF_TARGET
    assert cr_after.apparatus_refs[0].target_node_id == "node_0002"


def test_refine_apparatus_emits_unresolved_warning_when_no_target() -> None:
    plugin = EnciclopediaModernaProfile()
    cr = Node(
        id="node_0010",
        category=SemanticCategory.CROSS_REFERENCE,
        page_index=0,
        block_indices=(0,),
        text="(99)",
    )
    plugin._minted_crossref_note_ids.add("node_0010")
    doc = Document(root=(cr,), warnings=(), transformations=())
    out = plugin.refine_apparatus(doc, _make_extraction([], []), [])
    assert any("cross_reference_note_unresolved" in w for w in out.warnings)


def test_refine_apparatus_ignores_unminted_crossref() -> None:
    plugin = EnciclopediaModernaProfile()
    cr = Node(
        id="node_0010",
        category=SemanticCategory.CROSS_REFERENCE,
        page_index=0,
        block_indices=(0,),
        text="(1)",
    )
    # Note: minted set is empty
    doc = Document(root=(cr,), warnings=(), transformations=())
    out = plugin.refine_apparatus(doc, _make_extraction([], []), [])
    cr_after = next(n for n in out.root if n.id == "node_0010")
    assert len(cr_after.apparatus_refs) == 0


def test_refine_apparatus_filters_tier1_warnings_on_minted_crossref() -> None:
    plugin = EnciclopediaModernaProfile()
    plugin._minted_crossref_note_ids.add("node_0010")
    plugin._minted_crossref_voce_ids.add("node_0011")
    doc = Document(
        root=(),
        warnings=(
            "unparseable_cross_reference_node_node_0011",
            "unresolved_cross_reference_node_node_0010_n_1",
            "kept_warning",
        ),
        transformations=(),
    )
    out = plugin.refine_apparatus(doc, _make_extraction([], []), [])
    assert "kept_warning" in out.warnings
    assert all("unparseable_cross_reference_node_node_0011" not in w for w in out.warnings)
    assert all("unresolved_cross_reference_node_node_0010_n_1" not in w for w in out.warnings)


def test_refine_apparatus_preserves_transformations() -> None:
    plugin = EnciclopediaModernaProfile()
    from scabopdf_pipeline.postprocessing.types import Transformation

    existing = Transformation(
        step_id="prior",
        node_id="node_0001",
        page_index=0,
        position=(0, 5),
        original="abcde",
        normalized="abcde",
    )
    doc = Document(root=(), warnings=(), transformations=(existing,))
    out = plugin.refine_apparatus(doc, _make_extraction([], []), [])
    assert existing in out.transformations


def test_refine_apparatus_descends_into_children() -> None:
    """Children Nodes are walked too."""
    plugin = EnciclopediaModernaProfile()
    note = Node(
        id="node_0002",
        category=SemanticCategory.NOTE,
        page_index=0,
        block_indices=(1,),
        text="(1) Nota.",
    )
    inner_cr = Node(
        id="node_0010",
        category=SemanticCategory.CROSS_REFERENCE,
        page_index=0,
        block_indices=(0,),
        text="(1)",
    )
    plugin._minted_crossref_note_ids.add("node_0010")
    parent = Node(
        id="node_0001",
        category=SemanticCategory.HEADING_1,
        page_index=0,
        block_indices=(),
        children=(inner_cr,),
    )
    doc = Document(root=(parent, note), warnings=(), transformations=())
    out = plugin.refine_apparatus(doc, _make_extraction([], []), [])
    cr_after = out.root[0].children[0]
    assert len(cr_after.apparatus_refs) == 1


# ---------------------------------------------------------------------------
# Section 10: helper functions


def test_node_id_minter_starts_at_value() -> None:
    minter = _NodeIdMinter(start=42)
    assert minter.mint() == "node_0042"
    assert minter.mint() == "node_0043"


def test_node_id_minter_zero_pads_correctly() -> None:
    minter = _NodeIdMinter(start=0)
    assert minter.mint() == "node_0000"


def test_max_existing_node_counter_no_nodes() -> None:
    assert _max_existing_node_counter(()) == -1


def test_max_existing_node_counter_simple() -> None:
    nodes = (
        Node(id="node_0005", category=SemanticCategory.BODY, page_index=0),
        Node(id="node_0010", category=SemanticCategory.BODY, page_index=0),
    )
    assert _max_existing_node_counter(nodes) == 10


def test_max_existing_node_counter_descends_into_children() -> None:
    inner = Node(id="node_0099", category=SemanticCategory.BODY, page_index=0)
    parent = Node(
        id="node_0001",
        category=SemanticCategory.HEADING_1,
        page_index=0,
        children=(inner,),
    )
    assert _max_existing_node_counter((parent,)) == 99


def test_max_existing_node_counter_ignores_non_matching_id() -> None:
    """Synthetic node ids that don't follow the ``node_NNNN`` pattern are skipped."""
    nodes = (Node(id="custom_id", category=SemanticCategory.BODY, page_index=0),)
    assert _max_existing_node_counter(nodes) == -1


def test_iter_nodes_pre_order_dfs() -> None:
    leaf = Node(id="node_0003", category=SemanticCategory.BODY, page_index=0)
    branch = Node(
        id="node_0002",
        category=SemanticCategory.HEADING_2,
        page_index=0,
        children=(leaf,),
    )
    root = Node(
        id="node_0001",
        category=SemanticCategory.HEADING_1,
        page_index=0,
        children=(branch,),
    )
    nodes = _iter_nodes((root,))
    assert [n.id for n in nodes] == ["node_0001", "node_0002", "node_0003"]


def test_iter_nodes_empty_forest() -> None:
    assert _iter_nodes(()) == []


# ---------------------------------------------------------------------------
# Section 11: regex patterns


@pytest.mark.parametrize(
    "text,expected_match",
    [
        ("1. Premesse.", True),
        ("23. Capitolo.", True),
        ("400. Three-digit heading.", True),
        ("9999. Four-digit not a heading.", False),
        ("not a heading", False),
        ("(1) marker inline", False),
    ],
)
def test_paragraph_heading_pattern(text: str, expected_match: bool) -> None:
    matched = bool(_PARAGRAPH_HEADING_PATTERN.match(text))
    assert matched is expected_match


@pytest.mark.parametrize(
    "text,expected_match",
    [
        ("Sez. I. Title.", True),
        ("Sez. XXIII. End.", True),
        ("Sezione Title", False),
        ("Sez I title (no period)", False),
    ],
)
def test_sezione_heading_pattern(text: str, expected_match: bool) -> None:
    matched = bool(_SEZIONE_HEADING_PATTERN.match(text))
    assert matched is expected_match


@pytest.mark.parametrize(
    "text,expected_match",
    [
        ("FONTI. — Art. 1.", True),
        ("FONTI. - Art. 1.", True),
        ("FONTI.", True),
        ("fonti minuscolo", False),
        ("not FONTI prefix", False),
    ],
)
def test_fonti_label_pattern(text: str, expected_match: bool) -> None:
    matched = bool(_FONTI_LABEL_PATTERN.match(text))
    assert matched is expected_match


@pytest.mark.parametrize(
    "text,expected_match",
    [
        ("LETTERATURA. — A", True),
        ("LETTERATURA. - A", True),
        ("LETTERATURA.", True),
        ("Letteratura mista", False),
    ],
)
def test_letteratura_label_pattern(text: str, expected_match: bool) -> None:
    matched = bool(_LETTERATURA_LABEL_PATTERN.match(text))
    assert matched is expected_match


@pytest.mark.parametrize(
    "text,expected_match",
    [
        ("SOMMARIO: 1. Topic.", True),
        ("S OMMARIO: 1. Topic.", True),
        ("Sommario. — 1. Topic.", True),
        ("not a sommario", False),
    ],
)
def test_sommario_trim_pattern(text: str, expected_match: bool) -> None:
    matched = bool(_SOMMARIO_TRIM_PATTERN.match(text))
    assert matched is expected_match


@pytest.mark.parametrize(
    "text,expected_match,expected_marker",
    [
        ("(1) Nota.", True, "1"),
        ("(99) Nota.", True, "99"),
        ("Not a note", False, None),
    ],
)
def test_note_leading_marker_pattern(
    text: str, expected_match: bool, expected_marker: str | None
) -> None:
    match = _NOTE_LEADING_MARKER_PATTERN.match(text)
    if expected_match:
        assert match is not None
        assert match.group(1) == expected_marker
    else:
        assert match is None


def test_crossref_inline_note_pattern_finds_simple() -> None:
    text = "Citiamo la (3) e (5) ma non (12345)."
    matches = list(_CROSSREF_INLINE_NOTE_PATTERN.finditer(text))
    assert len(matches) == 3
    assert [m.group(1) for m in matches] == ["3", "5", "12345"]


def test_crossref_inline_note_pattern_skips_trailing_digit() -> None:
    """``(N)`` preceded by a digit is filtered as a run-on."""
    text = "art. 1234(5) qui."
    matches = list(_CROSSREF_INLINE_NOTE_PATTERN.finditer(text))
    assert matches == []


def test_crossref_inline_voce_pattern_finds_simple() -> None:
    text = "v. CONTRATTO PRELIMINARE, 2021 si rinvia."
    matches = list(_CROSSREF_INLINE_VOCE_PATTERN.finditer(text))
    assert len(matches) == 1
    assert "CONTRATTO PRELIMINARE" in matches[0].group(0)


def test_crossref_inline_voce_pattern_without_year() -> None:
    text = "Cfr. v. FATTO GIURIDICO e prosegue."
    matches = list(_CROSSREF_INLINE_VOCE_PATTERN.finditer(text))
    assert len(matches) == 1


def test_crossref_max_marker_value_constant() -> None:
    assert _CROSSREF_MAX_MARKER_VALUE == 500


def test_node_id_pattern() -> None:
    match = _NODE_ID_PATTERN.match("node_0042")
    assert match is not None
    assert match.group(1) == "0042"
    assert _NODE_ID_PATTERN.match("invalid_0042") is None


def test_toc_item_pattern() -> None:
    match = _TOC_ITEM_PATTERN.match("3. Disposizioni finali")
    assert match is not None
    assert match.group(1) == "3"
    assert match.group(2) == "Disposizioni finali"


# ---------------------------------------------------------------------------
# Section 12: confidence constants sanity


def test_confidence_constants_sum_to_ceiling() -> None:
    """All positive contributions sum to 0.85 (full positive ceiling)."""
    total = (
        CONFIDENCE_SIMONCINI_BODY_DOMINANT
        + CONFIDENCE_NOTE_FAMILY_PRESENT
        + 0.05  # bold heading
        + CONFIDENCE_TIMES_FOOTER_PRESENT
        + CONFIDENCE_HELVETICA_COPYRIGHT_PRESENT
        + 0.05  # page geometry
    )
    assert total == pytest.approx(0.85)


def test_helvetica_bold_family_fragment_prefix() -> None:
    """The fragment is a prefix-match string, not a complete family name."""
    assert HELVETICA_BOLD_FAMILY_FRAGMENT == "Helvetica-Bold"


def test_drop_cap_min_size_below_empirical() -> None:
    """Floor must be below the empirical 35.9pt but above any body size."""
    assert DROP_CAP_MIN_SIZE < 35.9
    assert DROP_CAP_MIN_SIZE > BODY_SIZE


def test_size_constants_consistent_with_empirical_drift() -> None:
    """All sizes mirror the nominal expectations; PyMuPDF emits -0.02pt drift."""
    assert BODY_SIZE == 9.0
    assert NOTE_SIZE == 7.5
    assert SOMMARIO_SIZE == 6.5
    assert APICE_SIZE == 5.0
