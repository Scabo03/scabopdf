"""Unit tests for the enciclopedia_storica corpus plugin."""

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
from scabopdf_pipeline.profiles.enciclopedia_storica import (
    _CROSSREF_INLINE_VOCE_PATTERN,
    _CROSSREF_MAX_MARKER_VALUE,
    _FONTI_LABEL_PATTERN,
    _LETTERATURA_LABEL_PATTERN,
    _LETTERATURA_OCR_TOLERANT_PATTERN,
    _PARAGRAPH_HEADING_PATTERN,
    _SEZIONE_HEADING_OCR_TOLERANT_PATTERN,
    _SOMMARIO_PATTERN,
    _VARIANT_B_OPENING_PATTERN,
    _VARIANT_C_OPENING_PATTERN,
    _VOLUME_FOOTER_PATTERN,
    BODY_SIZE_MIN,
    CONFIDENCE_PAPER_CAPTURE_PRODUCER,
    LEXICON_ALLOWLIST,
    NOTE_SIZE_MAX,
    PAPER_CAPTURE_PRODUCER_FRAGMENT,
    TIMES_FAMILY_PREFIX,
    TIMES_ITALIC_FAMILY,
    TIMES_REGULAR_FAMILY,
    WARNING_PREFIX,
    WARNING_TEMPLATES,
    EnciclopediaStoricaProfile,
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

# ---------------------------------------------------------------------------
# Helpers


def _storica_signals(
    *,
    producer: str = "Acrobat 11.0.23 Paper Capture Plug-in",
    creator: str = "PDF24 Creator",
    body_family: str = TIMES_REGULAR_FAMILY,
    body_size: float = 9.1,
    body_dominance: float = 70.0,
    include_italic_note: bool = True,
    include_simoncini: bool = False,
    width_pt: float = 510.24,
    height_pt: float = 708.66,
) -> ProfilingSignals:
    fonts = [
        FontDominance(family=body_family, size=body_size, dominance_percent=body_dominance),
    ]
    if include_italic_note:
        fonts.append(FontDominance(family=TIMES_ITALIC_FAMILY, size=7.7, dominance_percent=2.0))
    if include_simoncini:
        fonts.append(FontDominance(family="SimonciniGaramond", size=9.0, dominance_percent=5.0))
    return ProfilingSignals(
        typographic_signature=TypographicSignature(fonts=fonts),
        apparatus_presence=ApparatusPresence(),
        page_geometry=ProfilePageGeometry(width_pt=width_pt, height_pt=height_pt),
        producer_creator=ProducerCreator(producer=producer, creator=creator),
        outline_structure=OutlineStructure(),
        specific_markers=[],
    )


def _make_span(
    text: str,
    *,
    font: str = TIMES_REGULAR_FAMILY,
    size: float = 9.0,
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
    plugin = EnciclopediaStoricaProfile()
    assert plugin.profile_id == "enciclopedia_storica"
    assert plugin.editorial_family == "giuffre_edd"
    assert plugin.genre == "enciclopedia_storica"


def test_profile_identity_classvars() -> None:
    assert EnciclopediaStoricaProfile.profile_id == "enciclopedia_storica"
    assert EnciclopediaStoricaProfile.editorial_family == "giuffre_edd"
    assert EnciclopediaStoricaProfile.genre == "enciclopedia_storica"


def test_plugin_registered_in_builtins() -> None:
    from scabopdf_pipeline.profiles import BUILTIN_PLUGINS

    assert EnciclopediaStoricaProfile in BUILTIN_PLUGINS


# ---------------------------------------------------------------------------
# Section 2: declarative methods


def test_get_categories_covers_storica_set() -> None:
    cats = EnciclopediaStoricaProfile().get_categories()
    expected = {
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
    cats = EnciclopediaStoricaProfile().get_categories()
    assert SemanticCategory.ARTIFACT_FOOTER in cats
    assert SemanticCategory.ARTIFACT_RUNNING_HEADER in cats
    assert SemanticCategory.ARTIFACT_STAMP in cats
    assert SemanticCategory.BOOK_PAGE_ANCHOR in cats


def test_get_categories_excludes_dejure_and_codici_specific() -> None:
    cats = EnciclopediaStoricaProfile().get_categories()
    assert SemanticCategory.GENRE_BANNER not in cats
    assert SemanticCategory.MASSIMA_LABEL not in cats
    assert SemanticCategory.ARTICLE_HEADER not in cats


def test_get_post_processing_includes_dehyphenation() -> None:
    """Dehyphenation is critical on storica (970-1881 hyphens in fixtures)."""
    assert "dehyphenate_with_log" in EnciclopediaStoricaProfile().get_post_processing()


def test_get_post_processing_includes_cross_page_merge() -> None:
    assert "merge_cross_page_notes" in EnciclopediaStoricaProfile().get_post_processing()


def test_get_layouts_disabled_disables_L4() -> None:
    disabled = EnciclopediaStoricaProfile().get_layouts_disabled()
    assert len(disabled) == 1
    assert disabled[0].layout == "L4"
    assert "OCR" in disabled[0].reason or "unreliable" in disabled[0].reason


def test_warning_templates_are_a_tuple() -> None:
    assert isinstance(WARNING_TEMPLATES, tuple)
    assert all(w.startswith(WARNING_PREFIX) for w in WARNING_TEMPLATES)


# ---------------------------------------------------------------------------
# Section 2b: lexicon allowlist (debt (xi) closure)


def test_lexicon_allowlist_is_a_frozenset() -> None:
    assert isinstance(LEXICON_ALLOWLIST, frozenset)
    assert len(LEXICON_ALLOWLIST) > 0


def test_lexicon_allowlist_entries_are_lowercase() -> None:
    """Convention from CLAUDE.md pattern (dddd): entries written lowercase."""
    for entry in LEXICON_ALLOWLIST:
        assert entry == entry.lower(), f"{entry!r} is not lowercase"


def test_lexicon_allowlist_includes_latin_legal_core() -> None:
    """The allowlist must cover the empirical latinismi gap of the EdD storica fixtures."""
    expected_core = {
        "actio",
        "exceptio",
        "ius",
        "stipulatio",
        "traditio",
        "dolus",
        "praetor",
        "usucapio",
        "fideicommissum",
    }
    assert expected_core.issubset(LEXICON_ALLOWLIST)


def test_lexicon_allowlist_includes_classical_jurists() -> None:
    """The allowlist must cover the empirical Roman-jurist gap of the EdD storica fixtures."""
    expected_jurists = {"ulpiano", "papiniano", "labeone", "massurio", "tribonio"}
    assert expected_jurists.issubset(LEXICON_ALLOWLIST)


def test_get_lexicon_allowlist_returns_the_module_constant() -> None:
    """The classmethod returns the same frozenset as the module-level constant."""
    assert EnciclopediaStoricaProfile.get_lexicon_allowlist() is LEXICON_ALLOWLIST


# ---------------------------------------------------------------------------
# Section 3: matches()


def test_matches_clears_threshold_on_default_signals() -> None:
    score = EnciclopediaStoricaProfile.matches(_storica_signals())
    assert score >= 0.6


def test_matches_default_signals_returns_full_positive() -> None:
    """Full positive ceiling = 0.45 + 0.20 + 0.10 + 0.10 = 0.85."""
    score = EnciclopediaStoricaProfile.matches(_storica_signals())
    assert score == pytest.approx(0.85)


def test_matches_paper_capture_alone_dominant() -> None:
    """Paper Capture producer accounts for 0.45 of the score."""
    signals = _storica_signals(
        body_family="OpenSans-Regular",
        include_italic_note=False,
        width_pt=400.0,
        height_pt=400.0,
    )
    score = EnciclopediaStoricaProfile.matches(signals)
    # Paper Capture (+0.45) - non-Times penalty (-0.40) = 0.05; geometry
    # out of envelope adds nothing.
    assert score < 0.6  # but > 0 because no SimonciniGaramond


def test_matches_drops_below_threshold_on_simoncini_penalty() -> None:
    """SimonciniGaramond signature triggers the moderna discriminator."""
    signals = _storica_signals(include_simoncini=True)
    score = EnciclopediaStoricaProfile.matches(signals)
    # 0.85 - 0.30 = 0.55, below threshold.
    assert score < 0.6


def test_matches_drops_below_threshold_on_non_paper_capture_producer() -> None:
    """Without Paper Capture, the +0.45 contribution is missing."""
    signals = _storica_signals(producer="PDFsharp", creator="PDFsharp")
    score = EnciclopediaStoricaProfile.matches(signals)
    # 0.85 - 0.45 = 0.40, below threshold.
    assert score < 0.6


def test_matches_drops_below_threshold_on_arial_body() -> None:
    """DeJure NS/MM/DT use ArialMT — must NOT match storica."""
    signals = _storica_signals(
        body_family="ArialMT",
        include_italic_note=False,
        producer="Aspose.PDF for .NET",
    )
    score = EnciclopediaStoricaProfile.matches(signals)
    assert score < 0.6


def test_matches_credits_italic_note_present() -> None:
    with_italic = _storica_signals(include_italic_note=True)
    without = _storica_signals(include_italic_note=False)
    assert EnciclopediaStoricaProfile.matches(with_italic) > EnciclopediaStoricaProfile.matches(
        without
    )


def test_matches_accepts_8_5pt_body_under_ocr_drift() -> None:
    """The body band [8.0, 9.7] accepts 8.5pt OCR drift (azienda fixture)."""
    signals = _storica_signals(body_size=8.5)
    score = EnciclopediaStoricaProfile.matches(signals)
    assert score >= 0.6


def test_matches_accepts_9_5pt_body_under_ocr_drift() -> None:
    """The body band [8.0, 9.7] accepts 9.5pt OCR drift (eccesso fixture)."""
    signals = _storica_signals(body_size=9.53)
    score = EnciclopediaStoricaProfile.matches(signals)
    assert score >= 0.6


def test_matches_rejects_outside_body_band() -> None:
    """Body size 7.0pt is in note band, not body band."""
    signals = _storica_signals(body_size=7.0, include_italic_note=False)
    score = EnciclopediaStoricaProfile.matches(signals)
    # Paper Capture credit + non-Times-like body penalty
    assert score < 0.6


def test_matches_accepts_creator_paper_capture_when_producer_missing() -> None:
    signals = _storica_signals(
        producer="",
        creator="Acrobat 11.0.23 Paper Capture Plug-in",
    )
    score = EnciclopediaStoricaProfile.matches(signals)
    assert score >= 0.6


def test_matches_credits_geometry() -> None:
    in_env = _storica_signals(width_pt=510.24, height_pt=708.66)
    out_env = _storica_signals(width_pt=400.0, height_pt=400.0)
    assert EnciclopediaStoricaProfile.matches(in_env) > EnciclopediaStoricaProfile.matches(out_env)


def test_matches_accepts_481_697_vol_xxxi_geometry() -> None:
    """Pagamento Vol XXXI 1981 geometry inside envelope."""
    signals = _storica_signals(width_pt=481.89, height_pt=697.32)
    score = EnciclopediaStoricaProfile.matches(signals)
    assert score >= 0.6


def test_matches_returns_non_negative() -> None:
    signals = _storica_signals(
        producer="OpenSans",
        creator="OpenSans",
        body_family="OpenSans-Regular",
        include_italic_note=False,
        include_simoncini=True,
        width_pt=400.0,
        height_pt=400.0,
    )
    score = EnciclopediaStoricaProfile.matches(signals)
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
    score = EnciclopediaStoricaProfile.matches(signals)
    assert score == 0.0


# ---------------------------------------------------------------------------
# Section 4: predicate cascade


def test_is_footer_ente_recognises_canonical() -> None:
    spans = [_make_span("Enciclopedia del Diritto - Volume XIV - 1965")]
    view = _make_view(spans)
    assert EnciclopediaStoricaProfile._is_footer_ente(view)


def test_is_footer_ente_rejects_non_matching() -> None:
    spans = [_make_span("Other text not the footer.")]
    view = _make_view(spans)
    assert not EnciclopediaStoricaProfile._is_footer_ente(view)


def test_is_fonti_label_recognises_canonical() -> None:
    spans = [_make_span("FONTI. — Art. 1.")]
    view = _make_view(spans)
    assert EnciclopediaStoricaProfile._is_fonti_label(view)


def test_is_fonti_label_rejects_non_matching() -> None:
    spans = [_make_span("not FONTI label.")]
    view = _make_view(spans)
    assert not EnciclopediaStoricaProfile._is_fonti_label(view)


def test_is_letteratura_label_canonical() -> None:
    spans = [_make_span("LETTERATURA. — Ascarelli.")]
    view = _make_view(spans)
    assert EnciclopediaStoricaProfile._is_letteratura_label_canonical(view)


def test_is_letteratura_label_ocr_fossilised_lntehatura() -> None:
    """Galgano 1977 has ``LnTEHATURA`` OCR fossilisation."""
    spans = [_make_span("LnTEHATURA. — Sull'argomento")]
    view = _make_view(spans)
    # Canonical predicate should NOT fire.
    assert not EnciclopediaStoricaProfile._is_letteratura_label_canonical(view)
    # Tolerant predicate should fire.
    assert EnciclopediaStoricaProfile._is_letteratura_label_ocr_tolerant(view)


def test_is_letteratura_label_ocr_tolerant_returns_false_when_canonical_fires() -> None:
    """Canonical form must NOT fire the tolerant predicate (avoid double-count)."""
    spans = [_make_span("LETTERATURA. — A")]
    view = _make_view(spans)
    assert EnciclopediaStoricaProfile._is_letteratura_label_canonical(view)
    assert not EnciclopediaStoricaProfile._is_letteratura_label_ocr_tolerant(view)


def test_is_sommario_recognises_canonical() -> None:
    spans = [_make_span("SOMMARIO: 1. Premesse.")]
    view = _make_view(spans)
    assert EnciclopediaStoricaProfile._is_sommario(view)


def test_is_sommario_case_insensitive() -> None:
    spans = [_make_span("Sommario: 1. Topic.")]
    view = _make_view(spans)
    assert EnciclopediaStoricaProfile._is_sommario(view)


def test_is_sommario_rejects_fossilised_solulajuo() -> None:
    """OCR-destroyed ``SolUlAJUO`` is NOT recovered (documented limitation)."""
    spans = [_make_span("SolUlAJUO: 1. Premesse.")]
    view = _make_view(spans)
    assert not EnciclopediaStoricaProfile._is_sommario(view)


def test_is_sezione_heading_recognises_canonical() -> None:
    spans = [_make_span("Sez. I. Premesse.")]
    view = _make_view(spans)
    assert EnciclopediaStoricaProfile._is_sezione_heading(view)


def test_is_sezione_heading_recognises_ocr_degraded_lll() -> None:
    """OCR degrades III to lll; predicate accepts both forms."""
    spans = [_make_span("Sez. lll. Title.")]
    view = _make_view(spans)
    assert EnciclopediaStoricaProfile._is_sezione_heading(view)


def test_is_sezione_heading_rejects_non_matching() -> None:
    spans = [_make_span("Sezione without dot")]
    view = _make_view(spans)
    assert not EnciclopediaStoricaProfile._is_sezione_heading(view)


def test_is_paragraph_heading_recognises_canonical() -> None:
    spans = [_make_span("12. Title of paragrafo.")]
    view = _make_view(spans)
    assert EnciclopediaStoricaProfile._is_paragraph_heading(view)


def test_is_paragraph_heading_rejects_destroyed_ocr_bullet() -> None:
    """``•·`` OCR-destroyed paragrafo number is NOT recovered."""
    spans = [_make_span("•· Title.")]
    view = _make_view(spans)
    assert not EnciclopediaStoricaProfile._is_paragraph_heading(view)


def test_is_paragraph_heading_rejects_lowercase_start() -> None:
    spans = [_make_span("12. lowercase title.")]
    view = _make_view(spans)
    assert not EnciclopediaStoricaProfile._is_paragraph_heading(view)


def test_is_note_recognises_body_size_band() -> None:
    spans = [_make_span("(1) Nota content.", size=7.7)]
    view = _make_view(spans)
    assert EnciclopediaStoricaProfile._is_note(view)


def test_is_note_recognises_italic_band() -> None:
    spans = [_make_span("Italic nota.", font=TIMES_ITALIC_FAMILY, size=7.4)]
    view = _make_view(spans)
    assert EnciclopediaStoricaProfile._is_note(view)


def test_is_note_rejects_body_size() -> None:
    spans = [_make_span("Not a note.", size=9.0)]
    view = _make_view(spans)
    assert not EnciclopediaStoricaProfile._is_note(view)


def test_is_note_rejects_wrong_family() -> None:
    spans = [_make_span("Note candidate.", font="OpenSans", size=7.5)]
    view = _make_view(spans)
    assert not EnciclopediaStoricaProfile._is_note(view)


def test_is_note_rejects_empty_spans() -> None:
    view = _BlockView(block_index=0, block=_make_block(), spans=(), text="")
    assert not EnciclopediaStoricaProfile._is_note(view)


def test_is_body_recognises_band() -> None:
    spans = [_make_span("Body content.", size=9.1)]
    view = _make_view(spans)
    assert EnciclopediaStoricaProfile._is_body(view)


def test_is_body_rejects_outside_band() -> None:
    spans = [_make_span("Too small.", size=6.5)]
    view = _make_view(spans)
    assert not EnciclopediaStoricaProfile._is_body(view)


def test_is_body_rejects_wrong_family() -> None:
    spans = [_make_span("body candidate.", font="OpenSans", size=9.0)]
    view = _make_view(spans)
    assert not EnciclopediaStoricaProfile._is_body(view)


def test_is_body_rejects_empty_spans() -> None:
    view = _BlockView(block_index=0, block=_make_block(), spans=(), text="")
    assert not EnciclopediaStoricaProfile._is_body(view)


# ---------------------------------------------------------------------------
# Section 5: variant opening detection (pattern (ddd))


def test_detect_variant_b_romana_canonical() -> None:
    spans = [_make_span("II. — ECCESSO DI POTERE")]
    view = _make_view(spans, page=0)
    variant = EnciclopediaStoricaProfile._detect_variant_opening(view)
    assert variant == "b_sotto_voce_romana"


def test_detect_variant_b_romana_ocr_il_form() -> None:
    """OCR-degraded ``Il .`` form for ``II.`` is recognised."""
    spans = [_make_span("Il . — ECCESSO DI POTERE")]
    view = _make_view(spans, page=0)
    variant = EnciclopediaStoricaProfile._detect_variant_opening(view)
    assert variant == "b_sotto_voce_romana"


def test_detect_variant_c_lettera_canonical() -> None:
    spans = [_make_span("c) DIRITTO PRIVATO")]
    view = _make_view(spans, page=0)
    variant = EnciclopediaStoricaProfile._detect_variant_opening(view)
    assert variant == "c_sotto_voce_lettera"


def test_detect_variant_c_lettera_galgano_style() -> None:
    spans = [_make_span("a) PREMESSE PROBLEMATICHE")]
    view = _make_view(spans, page=0)
    variant = EnciclopediaStoricaProfile._detect_variant_opening(view)
    assert variant == "c_sotto_voce_lettera"


def test_detect_variant_a_voce_saggio_default() -> None:
    """A block starting with a capitalised word and no variant marker
    is classified as variante A.
    """
    spans = [_make_span("DISCREZIONALITÀ amministrativa")]
    view = _make_view(spans, page=0)
    variant = EnciclopediaStoricaProfile._detect_variant_opening(view)
    assert variant == "a_voce_saggio_singola"


def test_detect_variant_returns_none_on_empty() -> None:
    spans = [_make_span("   ")]
    view = _make_view(spans, page=0)
    variant = EnciclopediaStoricaProfile._detect_variant_opening(view)
    assert variant is None


def test_detect_variant_returns_none_on_single_letter() -> None:
    """Single letter is not a variant opening."""
    spans = [_make_span("X")]
    view = _make_view(spans, page=0)
    variant = EnciclopediaStoricaProfile._detect_variant_opening(view)
    assert variant is None


# ---------------------------------------------------------------------------
# Section 6: refine_classification end-to-end


def test_refine_classification_promotes_footer_ente() -> None:
    spans = [_make_span("Enciclopedia del Diritto - Volume XIV - 1965")]
    blocks = [_make_block(span_range=(0, 1), block_index=0)]
    extraction = _make_extraction(spans, blocks)
    plugin = EnciclopediaStoricaProfile()
    refined = plugin.refine_classification(extraction, [_verdict(0)])
    assert refined[0].category is SemanticCategory.ARTIFACT_FOOTER


def test_refine_classification_promotes_fonti_label() -> None:
    # Use a non-page-0 verdict to avoid variant opening firing first.
    spans = [_make_span("FONTI. — Art. 1.", page=2)]
    blocks = [_make_block(page=2, span_range=(0, 1), block_index=0)]
    extraction = _make_extraction(spans, blocks)
    plugin = EnciclopediaStoricaProfile()
    refined = plugin.refine_classification(extraction, [_verdict(0)])
    assert refined[0].category is SemanticCategory.SECTION_LABEL
    assert "fonti" in refined[0].reason


def test_refine_classification_promotes_letteratura_label() -> None:
    spans = [_make_span("LETTERATURA. — Ascarelli", page=2)]
    blocks = [_make_block(page=2, span_range=(0, 1), block_index=0)]
    extraction = _make_extraction(spans, blocks)
    plugin = EnciclopediaStoricaProfile()
    refined = plugin.refine_classification(extraction, [_verdict(0)])
    assert refined[0].category is SemanticCategory.SECTION_LABEL
    assert "letteratura" in refined[0].reason


def test_refine_classification_promotes_letteratura_ocr_fossilised() -> None:
    spans = [_make_span("LnTEHATURA. — Sull'argomento", page=2)]
    blocks = [_make_block(page=2, span_range=(0, 1), block_index=0)]
    extraction = _make_extraction(spans, blocks)
    plugin = EnciclopediaStoricaProfile()
    refined = plugin.refine_classification(extraction, [_verdict(0)])
    assert refined[0].category is SemanticCategory.SECTION_LABEL
    assert "ocr_tolerant" in refined[0].reason


def test_refine_classification_promotes_sezione_heading() -> None:
    spans = [_make_span("Sez. I. Premesse.", page=2)]
    blocks = [_make_block(page=2, span_range=(0, 1), block_index=0)]
    extraction = _make_extraction(spans, blocks)
    plugin = EnciclopediaStoricaProfile()
    refined = plugin.refine_classification(extraction, [_verdict(0)])
    assert refined[0].category is SemanticCategory.HEADING_2


def test_refine_classification_promotes_paragraph_heading() -> None:
    spans = [_make_span("12. Premesse generali.", page=2)]
    blocks = [_make_block(page=2, span_range=(0, 1), block_index=0)]
    extraction = _make_extraction(spans, blocks)
    plugin = EnciclopediaStoricaProfile()
    refined = plugin.refine_classification(extraction, [_verdict(0)])
    assert refined[0].category is SemanticCategory.HEADING_1


def test_refine_classification_promotes_sommario() -> None:
    spans = [_make_span("SOMMARIO: 1. Intro.", page=2)]
    blocks = [_make_block(page=2, span_range=(0, 1), block_index=0)]
    extraction = _make_extraction(spans, blocks)
    plugin = EnciclopediaStoricaProfile()
    refined = plugin.refine_classification(extraction, [_verdict(0)])
    assert refined[0].category is SemanticCategory.TOC_GENERAL


def test_refine_classification_promotes_note() -> None:
    spans = [_make_span("(1) Nota body.", size=7.7, page=2)]
    blocks = [_make_block(page=2, span_range=(0, 1), block_index=0)]
    extraction = _make_extraction(spans, blocks)
    plugin = EnciclopediaStoricaProfile()
    refined = plugin.refine_classification(extraction, [_verdict(0)])
    assert refined[0].category is SemanticCategory.NOTE


def test_refine_classification_promotes_body() -> None:
    spans = [_make_span("Body prose.", size=9.0, page=2)]
    blocks = [_make_block(page=2, span_range=(0, 1), block_index=0)]
    extraction = _make_extraction(spans, blocks)
    plugin = EnciclopediaStoricaProfile()
    refined = plugin.refine_classification(extraction, [_verdict(0)])
    assert refined[0].category is SemanticCategory.BODY


def test_refine_classification_emits_variant_warning_on_page_1() -> None:
    spans = [_make_span("c) DIRITTO PRIVATO", page=0)]
    blocks = [_make_block(page=0, span_range=(0, 1), block_index=0)]
    extraction = _make_extraction(spans, blocks)
    plugin = EnciclopediaStoricaProfile()
    refined = plugin.refine_classification(extraction, [_verdict(0)])
    assert refined[0].category is SemanticCategory.TITLE
    assert any("variant_c" in w for w in plugin._pending_warnings)


def test_refine_classification_variant_fires_only_once() -> None:
    spans = [
        _make_span("II. — ECCESSO DI POTERE", page=0),
        _make_span("a) ANOTHER OPENING", page=0),
    ]
    blocks = [
        _make_block(page=0, span_range=(0, 1), block_index=0),
        _make_block(page=0, span_range=(1, 2), block_index=1),
    ]
    extraction = _make_extraction(spans, blocks)
    plugin = EnciclopediaStoricaProfile()
    refined = plugin.refine_classification(extraction, [_verdict(0), _verdict(1)])
    # First block is variant B; second block must not be re-promoted to TITLE.
    assert refined[0].category is SemanticCategory.TITLE
    assert refined[1].category is not SemanticCategory.TITLE


def test_refine_classification_preserves_negative_block_index() -> None:
    plugin = EnciclopediaStoricaProfile()
    verdicts = [_verdict(-1, SemanticCategory.EMPTY_PAGE)]
    refined = plugin.refine_classification(_make_extraction([], []), verdicts)
    assert refined[0].category is SemanticCategory.EMPTY_PAGE


def test_refine_classification_preserves_unclassified_on_no_match() -> None:
    spans = [_make_span("???", font="OpenSans", size=15.0, page=2)]
    blocks = [_make_block(page=2, span_range=(0, 1), block_index=0)]
    extraction = _make_extraction(spans, blocks)
    plugin = EnciclopediaStoricaProfile()
    refined = plugin.refine_classification(extraction, [_verdict(0)])
    assert refined[0].category is SemanticCategory.UNCLASSIFIED


def test_refine_classification_retags_body_inside_fonti() -> None:
    spans = [
        _make_span("FONTI. — Art. 1.", page=2),
        _make_span("Art. 2 c.c.", size=9.0, page=2),
    ]
    blocks = [
        _make_block(page=2, span_range=(0, 1), block_index=0),
        _make_block(page=2, span_range=(1, 2), block_index=1),
    ]
    extraction = _make_extraction(spans, blocks)
    plugin = EnciclopediaStoricaProfile()
    refined = plugin.refine_classification(
        extraction, [_verdict(0), _verdict(1, SemanticCategory.BODY)]
    )
    assert refined[0].category is SemanticCategory.SECTION_LABEL
    assert refined[1].category is SemanticCategory.FONTI


def test_refine_classification_retags_body_inside_letteratura() -> None:
    spans = [
        _make_span("LETTERATURA. — Ascarelli", page=2),
        _make_span("Profili giuridici", size=9.0, page=2),
    ]
    blocks = [
        _make_block(page=2, span_range=(0, 1), block_index=0),
        _make_block(page=2, span_range=(1, 2), block_index=1),
    ]
    extraction = _make_extraction(spans, blocks)
    plugin = EnciclopediaStoricaProfile()
    refined = plugin.refine_classification(
        extraction, [_verdict(0), _verdict(1, SemanticCategory.BODY)]
    )
    assert refined[0].category is SemanticCategory.SECTION_LABEL
    assert refined[1].category is SemanticCategory.LETTERATURA


def test_refine_classification_letteratura_ocr_fossilised_retags_body() -> None:
    """A LETTERATURA region opened by an OCR-fossilised marker retags too."""
    spans = [
        _make_span("LnTEHATURA. — Sull'argomento", page=2),
        _make_span("Biblio entry.", size=9.0, page=2),
    ]
    blocks = [
        _make_block(page=2, span_range=(0, 1), block_index=0),
        _make_block(page=2, span_range=(1, 2), block_index=1),
    ]
    extraction = _make_extraction(spans, blocks)
    plugin = EnciclopediaStoricaProfile()
    refined = plugin.refine_classification(
        extraction, [_verdict(0), _verdict(1, SemanticCategory.BODY)]
    )
    assert refined[1].category is SemanticCategory.LETTERATURA


# ---------------------------------------------------------------------------
# Section 7: refine_reconstruction


def test_refine_reconstruction_mints_note_crossref() -> None:
    plugin = EnciclopediaStoricaProfile()
    body = Node(
        id="node_0001",
        category=SemanticCategory.BODY,
        page_index=0,
        block_indices=(0,),
        text="Cita (3) nel testo.",
    )
    doc = Document(root=(body,), warnings=(), transformations=())
    out = plugin.refine_reconstruction(doc, _make_extraction([], []), [])
    crossrefs = [n for n in out.root if n.category is SemanticCategory.CROSS_REFERENCE]
    assert len(crossrefs) == 1
    assert crossrefs[0].text == "(3)"


def test_refine_reconstruction_mints_voce_crossref() -> None:
    plugin = EnciclopediaStoricaProfile()
    body = Node(
        id="node_0001",
        category=SemanticCategory.BODY,
        page_index=0,
        block_indices=(0,),
        text="Si rinvia v. DICHIARAZIONE DI PUBBLICA UTILITÀ per approfondimenti.",
    )
    doc = Document(root=(body,), warnings=(), transformations=())
    out = plugin.refine_reconstruction(doc, _make_extraction([], []), [])
    crossrefs = [n for n in out.root if n.category is SemanticCategory.CROSS_REFERENCE]
    assert len(crossrefs) == 1
    text = crossrefs[0].text
    assert text is not None
    assert "DICHIARAZIONE" in text


def test_refine_reconstruction_descends_into_children() -> None:
    plugin = EnciclopediaStoricaProfile()
    inner = Node(
        id="node_0002",
        category=SemanticCategory.BODY,
        page_index=0,
        block_indices=(1,),
        text="Cita (5).",
    )
    parent = Node(
        id="node_0001",
        category=SemanticCategory.HEADING_1,
        page_index=0,
        block_indices=(0,),
        text="1. Premesse.",
        children=(inner,),
    )
    doc = Document(root=(parent,), warnings=(), transformations=())
    out = plugin.refine_reconstruction(doc, _make_extraction([], []), [])
    inner_after = out.root[0].children
    crossrefs = [n for n in inner_after if n.category is SemanticCategory.CROSS_REFERENCE]
    assert len(crossrefs) == 1


def test_refine_reconstruction_skips_marker_above_cap() -> None:
    plugin = EnciclopediaStoricaProfile()
    body = Node(
        id="node_0001",
        category=SemanticCategory.BODY,
        page_index=0,
        block_indices=(0,),
        text="Year (1965) reference.",
    )
    doc = Document(root=(body,), warnings=(), transformations=())
    out = plugin.refine_reconstruction(doc, _make_extraction([], []), [])
    crossrefs = [n for n in out.root if n.category is SemanticCategory.CROSS_REFERENCE]
    assert crossrefs == []


def test_refine_reconstruction_propagates_pending_warnings() -> None:
    plugin = EnciclopediaStoricaProfile()
    plugin._pending_warnings = [f"{WARNING_PREFIX}:variant_b_sotto_voce_romana_page_0"]
    doc = Document(root=(), warnings=("prior_warning",), transformations=())
    out = plugin.refine_reconstruction(doc, _make_extraction([], []), [])
    assert "prior_warning" in out.warnings
    assert any("variant_b" in w for w in out.warnings)


# ---------------------------------------------------------------------------
# Section 8: refine_apparatus


def test_refine_apparatus_binds_crossref_to_note() -> None:
    plugin = EnciclopediaStoricaProfile()
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


def test_refine_apparatus_emits_unresolved_warning() -> None:
    plugin = EnciclopediaStoricaProfile()
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


def test_refine_apparatus_filters_tier1_warnings() -> None:
    plugin = EnciclopediaStoricaProfile()
    plugin._minted_crossref_note_ids.add("node_0010")
    plugin._minted_crossref_voce_ids.add("node_0011")
    doc = Document(
        root=(),
        warnings=(
            "unparseable_cross_reference_node_node_0011",
            "unresolved_cross_reference_node_node_0010_n_5",
            "kept_warning",
        ),
        transformations=(),
    )
    out = plugin.refine_apparatus(doc, _make_extraction([], []), [])
    assert "kept_warning" in out.warnings
    assert all("unparseable_cross_reference_node_node_0011" not in w for w in out.warnings)


def test_refine_apparatus_no_op_on_empty_document() -> None:
    plugin = EnciclopediaStoricaProfile()
    doc = Document(root=(), warnings=(), transformations=())
    out = plugin.refine_apparatus(doc, _make_extraction([], []), [])
    assert out.root == ()


def test_refine_apparatus_preserves_transformations() -> None:
    plugin = EnciclopediaStoricaProfile()
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


# ---------------------------------------------------------------------------
# Section 9: helper functions


def test_node_id_minter_starts_correctly() -> None:
    minter = _NodeIdMinter(start=15)
    assert minter.mint() == "node_0015"
    assert minter.mint() == "node_0016"


def test_max_existing_node_counter_no_nodes() -> None:
    assert _max_existing_node_counter(()) == -1


def test_max_existing_node_counter_recursive() -> None:
    inner = Node(id="node_0099", category=SemanticCategory.BODY, page_index=0)
    parent = Node(
        id="node_0001",
        category=SemanticCategory.HEADING_1,
        page_index=0,
        children=(inner,),
    )
    assert _max_existing_node_counter((parent,)) == 99


def test_max_existing_node_counter_ignores_non_matching() -> None:
    nodes = (Node(id="non_standard_id", category=SemanticCategory.BODY, page_index=0),)
    assert _max_existing_node_counter(nodes) == -1


def test_iter_nodes_pre_order() -> None:
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


# ---------------------------------------------------------------------------
# Section 10: regex patterns


@pytest.mark.parametrize(
    "text,expected_match",
    [
        ("Volume XIV - 1965", True),
        ("Volume XXIII - 1973", True),
        ("Volume XXXI - 1981", True),
        ("Volume IV - 1959", True),
        ("Aggiornamento II - 1998", False),
        ("not a volume", False),
    ],
)
def test_volume_footer_pattern(text: str, expected_match: bool) -> None:
    matched = bool(_VOLUME_FOOTER_PATTERN.search(text))
    assert matched is expected_match


@pytest.mark.parametrize(
    "text,expected_variant",
    [
        ("I. — TITLE", "b_sotto_voce_romana"),
        ("II. — TITLE", "b_sotto_voce_romana"),
        ("XXIII. — TITLE", "b_sotto_voce_romana"),
        ("not a variant", None),
    ],
)
def test_variant_b_opening_pattern(text: str, expected_variant: str | None) -> None:
    matched = bool(_VARIANT_B_OPENING_PATTERN.match(text))
    if expected_variant == "b_sotto_voce_romana":
        assert matched
    else:
        assert not matched


@pytest.mark.parametrize(
    "text,expected_match",
    [
        ("a) PREMESSE", True),
        ("c) DIRITTO PRIVATO", True),
        ("e) TITOLO", True),
        ("f) NOT_MATCH", False),  # outside [a-e]
        ("a) lowercase", False),
    ],
)
def test_variant_c_opening_pattern(text: str, expected_match: bool) -> None:
    matched = bool(_VARIANT_C_OPENING_PATTERN.match(text))
    assert matched is expected_match


@pytest.mark.parametrize(
    "text,expected_match",
    [
        ("Sez. I. Title", True),
        ("Sez. lll. OCR-degraded.", True),
        ("Sezione Title (no dot)", False),
    ],
)
def test_sezione_heading_ocr_tolerant_pattern(text: str, expected_match: bool) -> None:
    matched = bool(_SEZIONE_HEADING_OCR_TOLERANT_PATTERN.match(text))
    assert matched is expected_match


@pytest.mark.parametrize(
    "text,expected_match",
    [
        ("1. Title", True),
        ("23. Long Title.", True),
        ("400. Three digit.", True),
        ("4. lowercase wrong", False),
        ("not a paragrafo", False),
    ],
)
def test_paragraph_heading_pattern(text: str, expected_match: bool) -> None:
    matched = bool(_PARAGRAPH_HEADING_PATTERN.match(text))
    assert matched is expected_match


@pytest.mark.parametrize(
    "text,expected_match",
    [
        ("FONTI. — Art.", True),
        ("FONTI.", True),
        ("not FONTI", False),
    ],
)
def test_fonti_label_pattern(text: str, expected_match: bool) -> None:
    matched = bool(_FONTI_LABEL_PATTERN.match(text))
    assert matched is expected_match


@pytest.mark.parametrize(
    "text,expected_match",
    [
        ("LETTERATURA. — Asca", True),
        ("LETTERATURA.", True),
        ("Letteratura italiana", False),
    ],
)
def test_letteratura_label_pattern(text: str, expected_match: bool) -> None:
    matched = bool(_LETTERATURA_LABEL_PATTERN.match(text))
    assert matched is expected_match


@pytest.mark.parametrize(
    "text,expected_match",
    [
        ("LETTERATURA. — Asca", True),
        ("LnTEHATURA. — Sull'argomento", True),
        ("LETTEHATURA - x", True),
        ("Letterallml-x", False),  # Rare fossil ending in 'l', not 'a'
        ("Lab Test (short word)", False),
    ],
)
def test_letteratura_ocr_tolerant_pattern(text: str, expected_match: bool) -> None:
    matched = bool(_LETTERATURA_OCR_TOLERANT_PATTERN.match(text))
    assert matched is expected_match


@pytest.mark.parametrize(
    "text,expected_match",
    [
        ("SOMMARIO: 1. Topic.", True),
        ("Sommario: 1. Topic.", True),
        ("sommario: 1. Topic.", True),
        ("SolUlAJUO: not recoverable.", False),
    ],
)
def test_sommario_pattern(text: str, expected_match: bool) -> None:
    matched = bool(_SOMMARIO_PATTERN.match(text))
    assert matched is expected_match


def test_crossref_inline_note_pattern() -> None:
    text = "Cita (1) e (2) e (12345)."
    matches = list(_CROSSREF_INLINE_NOTE_PATTERN.finditer(text))
    assert [m.group(1) for m in matches] == ["1", "2", "12345"]


def test_crossref_inline_voce_pattern() -> None:
    text = "Per approfondimenti v. DICHIARAZIONE DI PUBBLICA UTILITÀ continua."
    matches = list(_CROSSREF_INLINE_VOCE_PATTERN.finditer(text))
    assert len(matches) == 1


def test_crossref_max_marker_value_constant() -> None:
    assert _CROSSREF_MAX_MARKER_VALUE == 500


def test_node_id_pattern() -> None:
    assert _NODE_ID_PATTERN.match("node_0042") is not None
    assert _NODE_ID_PATTERN.match("invalid_0042") is None


def test_note_leading_marker_pattern() -> None:
    match = _NOTE_LEADING_MARKER_PATTERN.match("(7) Note body.")
    assert match is not None
    assert match.group(1) == "7"


# ---------------------------------------------------------------------------
# Section 11: constants sanity


def test_size_bands_separable() -> None:
    """The note band must be strictly below the body band."""
    assert NOTE_SIZE_MAX <= BODY_SIZE_MIN


def test_paper_capture_fragment() -> None:
    assert PAPER_CAPTURE_PRODUCER_FRAGMENT == "Paper Capture"


def test_times_family_prefix() -> None:
    assert TIMES_FAMILY_PREFIX == "Times"


def test_confidence_paper_capture_dominant() -> None:
    """Paper Capture confidence is the single strongest signal."""
    assert CONFIDENCE_PAPER_CAPTURE_PRODUCER == 0.45
