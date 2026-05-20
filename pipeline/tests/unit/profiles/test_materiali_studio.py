# ruff: noqa: RUF001
"""Unit tests for the materiali_studio corpus plugin."""

from __future__ import annotations

import pytest

from scabopdf_pipeline.classification.types import ClassifiedBlock
from scabopdf_pipeline.extraction.types import Block, ExtractionResult, Span
from scabopdf_pipeline.profiles.materiali_studio import (
    APPARATUS_PRESENCE_THRESHOLD,
    BODY_DOMINANCE_MIN_PERCENT,
    COLOR_GREY_LIGHT_CENTER,
    COLOR_GREY_MEDIUM_CENTER,
    COLOR_MODE_SCAN_BLOCK_LIMIT,
    HEADING_LINE_MAX_CHARS,
    WARNING_PREFIX,
    MaterialiStudioProfile,
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
from scabopdf_pipeline.reconstruction.types import Document, Node
from scabopdf_pipeline.schema.categories import SemanticCategory

BOLD_FLAG = 0x10
ITALIC_FLAG = 0x02


# ---------------------------------------------------------------------------
# Helpers


def _signals(
    *,
    producer: str = "Skia/PDF m116 Google Docs Renderer",
    creator: str = "",
    body_family: str = "Arial-BoldMT",
    body_size: float = 25.0,
    body_dominance: float = 99.0,
    width_pt: float = 596.0,
    height_pt: float = 842.0,
    marginal_headings: int = 0,
    footnote_markers: int = 0,
    italic_9pt_blocks: int = 0,
) -> ProfilingSignals:
    fonts = [
        FontDominance(family=body_family, size=body_size, dominance_percent=body_dominance),
    ]
    return ProfilingSignals(
        typographic_signature=TypographicSignature(fonts=fonts),
        apparatus_presence=ApparatusPresence(
            marginal_headings=marginal_headings,
            footnote_markers=footnote_markers,
            italic_9pt_blocks=italic_9pt_blocks,
        ),
        page_geometry=ProfilePageGeometry(width_pt=width_pt, height_pt=height_pt),
        producer_creator=ProducerCreator(producer=producer, creator=creator),
        outline_structure=OutlineStructure(),
    )


def _span(
    text: str,
    *,
    font: str = "Arial-BoldMT",
    size: float = 25.0,
    flags: int = BOLD_FLAG,
    color: int = 0,
    page: int = 0,
    bbox: tuple[float, float, float, float] = (72.0, 100.0, 500.0, 130.0),
    block_index: int = 0,
    line_index: int = 0,
    span_index: int = 0,
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


def _block(
    *,
    page: int = 0,
    block_index: int = 0,
    bbox: tuple[float, float, float, float] = (72.0, 100.0, 500.0, 200.0),
    span_range: tuple[int, int] = (0, 1),
) -> Block:
    return Block(page=page, block_index=block_index, bbox=bbox, span_range=span_range)


def _view(
    spans: list[Span],
    *,
    page: int = 0,
    bbox: tuple[float, float, float, float] = (72.0, 100.0, 500.0, 200.0),
    block_index: int = 0,
) -> _BlockView:
    block = _block(page=page, block_index=block_index, bbox=bbox, span_range=(0, len(spans)))
    text = "".join(s.text for s in spans)
    line_count = len({s.line_index for s in spans}) or 1
    leading = None
    for s in spans:
        if s.text.strip():
            leading = s
            break
    if leading is None and spans:
        leading = spans[0]
    return _BlockView(
        block_index=block_index,
        block=block,
        spans=tuple(spans),
        text=text,
        line_count=line_count,
        leading_span=leading,
    )


def _extraction(spans: list[Span], blocks: list[Block]) -> ExtractionResult:
    return ExtractionResult(
        spans=list(spans),
        blocks=list(blocks),
        page_geometries=[],
        page_images=[],
        drawings=[],
        warnings=[],
        page_count=1,
        is_encrypted=False,
        permissions=-1,
    )


def _verdict(
    block_index: int = 0,
    category: SemanticCategory = SemanticCategory.UNCLASSIFIED,
    reason: str = "no_match",
) -> ClassifiedBlock:
    return ClassifiedBlock(block_index=block_index, category=category, reason=reason)


# ===========================================================================
# matches() tests
# ===========================================================================


class TestMatches:
    def test_gdocs_arial_a4(self) -> None:
        score = MaterialiStudioProfile.matches(_signals())
        assert 0.74 <= score <= 0.76

    def test_word_arial_a4(self) -> None:
        sig = _signals(
            producer="Microsoft® Word per Microsoft 365",
            creator="Microsoft® Word per Microsoft 365",
        )
        score = MaterialiStudioProfile.matches(sig)
        assert 0.74 <= score <= 0.76

    def test_word_no_trademark_variant_matches(self) -> None:
        sig = _signals(producer="Microsoft Word 2019", creator="")
        score = MaterialiStudioProfile.matches(sig)
        assert score >= 0.70

    def test_word_arial_letter_us(self) -> None:
        sig = _signals(
            producer="Microsoft® Word per Microsoft 365",
            width_pt=612.0,
            height_pt=792.0,
        )
        score = MaterialiStudioProfile.matches(sig)
        assert score >= 0.70

    def test_wrong_producer_short_circuits(self) -> None:
        sig = _signals(producer="Adobe PDF Library 15.0", creator="Adobe InDesign CC")
        assert MaterialiStudioProfile.matches(sig) == 0.0

    def test_aspose_producer_short_circuits(self) -> None:
        sig = _signals(producer="Aspose.PDF for .NET 18.4")
        assert MaterialiStudioProfile.matches(sig) == 0.0

    def test_pdfsharp_producer_short_circuits(self) -> None:
        sig = _signals(producer="PDFsharp 1.31.1789-g")
        assert MaterialiStudioProfile.matches(sig) == 0.0

    def test_acrobat_distiller_short_circuits(self) -> None:
        sig = _signals(producer="Acrobat Distiller 11.0")
        assert MaterialiStudioProfile.matches(sig) == 0.0

    def test_paper_capture_short_circuits(self) -> None:
        sig = _signals(producer="Acrobat 11.0.23 Paper Capture Plug-in")
        assert MaterialiStudioProfile.matches(sig) == 0.0

    def test_empty_producer_creator(self) -> None:
        sig = _signals(producer="", creator="")
        assert MaterialiStudioProfile.matches(sig) == 0.0

    def test_none_producer_creator(self) -> None:
        sig = ProfilingSignals(
            typographic_signature=TypographicSignature(),
            apparatus_presence=ApparatusPresence(),
            page_geometry=ProfilePageGeometry(width_pt=596.0, height_pt=842.0),
            producer_creator=ProducerCreator(),
            outline_structure=OutlineStructure(),
        )
        assert MaterialiStudioProfile.matches(sig) == 0.0

    def test_skia_without_google_docs_short_circuits(self) -> None:
        sig = _signals(producer="Skia/PDF m116")
        assert MaterialiStudioProfile.matches(sig) == 0.0

    def test_google_docs_without_skia_short_circuits(self) -> None:
        sig = _signals(producer="Google Docs Export")
        assert MaterialiStudioProfile.matches(sig) == 0.0

    def test_non_arial_body_score(self) -> None:
        sig = _signals(body_family="TimesNewRoman")
        score = MaterialiStudioProfile.matches(sig)
        assert score < 0.70
        assert score >= 0.50

    def test_below_dominance_threshold_no_credit(self) -> None:
        sig = _signals(body_dominance=BODY_DOMINANCE_MIN_PERCENT - 0.5)
        score = MaterialiStudioProfile.matches(sig)
        assert score < 0.70

    def test_non_a4_non_letter_geometry_penalty(self) -> None:
        sig = _signals(width_pt=400.0, height_pt=600.0)
        score = MaterialiStudioProfile.matches(sig)
        assert 0.40 <= score < 0.60

    def test_marginal_apparatus_penalty(self) -> None:
        sig = _signals(marginal_headings=APPARATUS_PRESENCE_THRESHOLD + 1)
        score = MaterialiStudioProfile.matches(sig)
        assert score == pytest.approx(0.55, abs=0.01)

    def test_footnote_apparatus_penalty(self) -> None:
        sig = _signals(footnote_markers=APPARATUS_PRESENCE_THRESHOLD + 100)
        score = MaterialiStudioProfile.matches(sig)
        assert score == pytest.approx(0.55, abs=0.01)

    def test_editorial_marker_co_present_penalty(self) -> None:
        sig = _signals(
            producer="Microsoft® Word per Microsoft 365",
            creator="Aspose.PDF for .NET 18.4",
        )
        score = MaterialiStudioProfile.matches(sig)
        assert 0.40 <= score < 0.70

    def test_score_clamped_to_zero_minimum(self) -> None:
        sig = _signals(
            producer="Microsoft® Word per Microsoft 365",
            body_family="TimesNewRoman",
            width_pt=400.0,
            height_pt=600.0,
            marginal_headings=APPARATUS_PRESENCE_THRESHOLD + 1,
            footnote_markers=APPARATUS_PRESENCE_THRESHOLD + 1,
        )
        # 0.40 + 0 - 0.10 - 0.20 = 0.10 (only one apparatus penalty fires)
        score = MaterialiStudioProfile.matches(sig)
        assert score >= 0.0

    def test_score_clamped_to_one_maximum(self) -> None:
        # All positive signals; cannot exceed 0.75
        score = MaterialiStudioProfile.matches(_signals())
        assert score <= 1.0


# ===========================================================================
# Declarative methods
# ===========================================================================


class TestDeclarativeMethods:
    def test_profile_id(self) -> None:
        assert MaterialiStudioProfile.profile_id == "materiali_studio"

    def test_editorial_family(self) -> None:
        assert MaterialiStudioProfile.editorial_family == "user_generated"

    def test_genre(self) -> None:
        assert MaterialiStudioProfile.genre == "study_notes"

    def test_get_categories_contains_headings(self) -> None:
        plugin = MaterialiStudioProfile()
        cats = plugin.get_categories()
        assert SemanticCategory.HEADING_1 in cats
        assert SemanticCategory.HEADING_2 in cats
        assert SemanticCategory.HEADING_3 in cats
        assert SemanticCategory.HEADING_4 in cats

    def test_get_categories_contains_body_and_list_item(self) -> None:
        plugin = MaterialiStudioProfile()
        cats = plugin.get_categories()
        assert SemanticCategory.BODY in cats
        assert SemanticCategory.LIST_ITEM in cats

    def test_get_categories_contains_artifacts(self) -> None:
        plugin = MaterialiStudioProfile()
        cats = plugin.get_categories()
        assert SemanticCategory.ARTIFACT_FILIGREE in cats
        assert SemanticCategory.EMPTY_PAGE in cats
        assert SemanticCategory.UNCLASSIFIED in cats

    def test_get_post_processing(self) -> None:
        plugin = MaterialiStudioProfile()
        assert plugin.get_post_processing() == ["dehyphenate_with_log"]

    def test_get_layouts_disabled(self) -> None:
        plugin = MaterialiStudioProfile()
        assert plugin.get_layouts_disabled() == []


# ===========================================================================
# _detect_color_mode
# ===========================================================================


class TestDetectColorMode:
    def test_mono_only_bold_returns_false(self) -> None:
        spans = [_span("body", flags=BOLD_FLAG, color=0)]
        blocks = [_block(span_range=(0, 1))]
        ext = _extraction(spans, blocks)
        assert MaterialiStudioProfile._detect_color_mode(ext) is False

    def test_single_color_non_bold_returns_false(self) -> None:
        spans = [_span("body", font="ArialMT", flags=0, color=0)]
        blocks = [_block(span_range=(0, 1))]
        ext = _extraction(spans, blocks)
        assert MaterialiStudioProfile._detect_color_mode(ext) is False

    def test_two_distinct_colors_returns_true(self) -> None:
        spans = [
            _span("banner", font="ArialMT", flags=0, color=0x666666),
            _span("subtitle", font="ArialMT", flags=0, color=0x434343),
        ]
        blocks = [_block(span_range=(0, 2))]
        ext = _extraction(spans, blocks)
        assert MaterialiStudioProfile._detect_color_mode(ext) is True

    def test_non_arial_spans_ignored(self) -> None:
        spans = [
            _span("body", font="TimesNewRoman", flags=0, color=0),
            _span("body", font="TimesNewRoman", flags=0, color=0x666666),
        ]
        blocks = [_block(span_range=(0, 2))]
        ext = _extraction(spans, blocks)
        assert MaterialiStudioProfile._detect_color_mode(ext) is False

    def test_bold_spans_excluded(self) -> None:
        spans = [
            _span("body", font="Arial-BoldMT", flags=BOLD_FLAG, color=0),
            _span("body", font="Arial-BoldMT", flags=BOLD_FLAG, color=0x666666),
        ]
        blocks = [_block(span_range=(0, 2))]
        ext = _extraction(spans, blocks)
        # Both spans are bold; should not enter color mode
        assert MaterialiStudioProfile._detect_color_mode(ext) is False

    def test_scan_limit_break_on_long_doc_no_color(self) -> None:
        # Many blocks all with color=0 — never hits 2 distinct, scan terminates
        # at COLOR_MODE_SCAN_BLOCK_LIMIT via the break statement.
        many_spans = [
            _span("x", font="ArialMT", flags=0, color=0, block_index=i)
            for i in range(COLOR_MODE_SCAN_BLOCK_LIMIT + 5)
        ]
        many_blocks = [
            _block(block_index=i, span_range=(i, i + 1))
            for i in range(COLOR_MODE_SCAN_BLOCK_LIMIT + 5)
        ]
        ext = _extraction(many_spans, many_blocks)
        assert MaterialiStudioProfile._detect_color_mode(ext) is False

    def test_scan_limit_honored(self) -> None:
        # Beyond limit, additional colors are not counted
        many_blocks = []
        many_spans = []
        for i in range(COLOR_MODE_SCAN_BLOCK_LIMIT + 5):
            many_spans.append(_span("x", font="ArialMT", flags=0, color=0, block_index=i))
            many_blocks.append(_block(block_index=i, span_range=(i, i + 1)))
        # All have color=0, single distinct → False
        # Then add a second color at block 0
        many_spans[0] = _span("x", font="ArialMT", flags=0, color=0x666666)
        # That makes 2 distinct on block 0 + 1 → True early
        ext = _extraction(many_spans, many_blocks)
        assert MaterialiStudioProfile._detect_color_mode(ext) is True


# ===========================================================================
# _is_grey_at
# ===========================================================================


class TestIsGreyAt:
    def test_exact_grey_light(self) -> None:
        assert MaterialiStudioProfile._is_grey_at(0x666666, COLOR_GREY_LIGHT_CENTER) is True

    def test_exact_grey_medium(self) -> None:
        assert MaterialiStudioProfile._is_grey_at(0x434343, COLOR_GREY_MEDIUM_CENTER) is True

    def test_within_tolerance(self) -> None:
        # 102 + 10 = 112 = 0x70
        assert MaterialiStudioProfile._is_grey_at(0x707070, COLOR_GREY_LIGHT_CENTER) is True

    def test_outside_tolerance(self) -> None:
        # Big jump
        assert MaterialiStudioProfile._is_grey_at(0x808080, COLOR_GREY_LIGHT_CENTER) is False

    def test_non_grey_color_rejected(self) -> None:
        # 0x665544: R=0x66, G=0x55, B=0x44 — not equal
        assert MaterialiStudioProfile._is_grey_at(0x665544, COLOR_GREY_LIGHT_CENTER) is False

    def test_black_with_nonzero_center_false(self) -> None:
        assert MaterialiStudioProfile._is_grey_at(0, COLOR_GREY_LIGHT_CENTER) is False

    def test_black_with_zero_center_true(self) -> None:
        # Black matches itself when center is 0
        # 0 = 0,0,0; center 0; all channels match
        # R == G == B == 0; abs(0 - 0) == 0 <= tolerance
        # The early-return short-circuit returns False only when color==0 AND center != 0
        assert MaterialiStudioProfile._is_grey_at(0, 0) is True


# ===========================================================================
# Predicates — _is_decorative_separator
# ===========================================================================


class TestDecorativeSeparator:
    def test_em_dash_only(self) -> None:
        view = _view([_span("—————————————", color=0)])
        assert MaterialiStudioProfile._is_decorative_separator(view) is True

    def test_mixed_em_dash_hyphens(self) -> None:
        view = _view([_span("—-----------------------")])
        assert MaterialiStudioProfile._is_decorative_separator(view) is True

    def test_multi_line_em_dash(self) -> None:
        view = _view([_span("—----------\n----------")])
        assert MaterialiStudioProfile._is_decorative_separator(view) is True

    def test_short_string_not_separator(self) -> None:
        view = _view([_span("--")])
        assert MaterialiStudioProfile._is_decorative_separator(view) is False

    def test_all_whitespace_not_separator(self) -> None:
        view = _view([_span("       \n   ")])
        assert MaterialiStudioProfile._is_decorative_separator(view) is False

    def test_normal_text_not_separator(self) -> None:
        view = _view([_span("Lorem ipsum dolor sit")])
        assert MaterialiStudioProfile._is_decorative_separator(view) is False

    def test_i_decoration(self) -> None:
        view = _view([_span("IIIIIIIIIIIIIIIIIIIIIIIII")])
        assert MaterialiStudioProfile._is_decorative_separator(view) is True

    def test_four_dashes_too_short(self) -> None:
        view = _view([_span("----")])
        # length = 4, below the 5-char floor
        assert MaterialiStudioProfile._is_decorative_separator(view) is False


# ===========================================================================
# Predicates — _is_parte_allcaps
# ===========================================================================


class TestParteAllcaps:
    def test_basic_allcaps(self) -> None:
        view = _view([_span("I DIRITTI REALI")])
        assert MaterialiStudioProfile._is_parte_allcaps(view) is True

    def test_with_apostrophe(self) -> None:
        view = _view([_span("LA PUBBLICITA' IMMOBILIARE")])
        assert MaterialiStudioProfile._is_parte_allcaps(view) is True

    def test_with_accented_uppercase(self) -> None:
        view = _view([_span("LE OBBLIGAZIONI NASCENTI DA FATTO ILLECITO")])
        assert MaterialiStudioProfile._is_parte_allcaps(view) is True

    def test_lowercase_rejected(self) -> None:
        view = _view([_span("I diritti reali")])
        assert MaterialiStudioProfile._is_parte_allcaps(view) is False

    def test_too_short_rejected(self) -> None:
        view = _view([_span("OK")])
        assert MaterialiStudioProfile._is_parte_allcaps(view) is False

    def test_too_long_rejected(self) -> None:
        text = "A" * (HEADING_LINE_MAX_CHARS + 5)
        view = _view([_span(text)])
        assert MaterialiStudioProfile._is_parte_allcaps(view) is False

    def test_three_lines_rejected(self) -> None:
        spans = [
            _span("LE OBBLIGAZIONI", line_index=0),
            _span("NASCENTI DALLA", line_index=1),
            _span("LEGGE COMUNE", line_index=2),
        ]
        view = _view(spans)
        assert MaterialiStudioProfile._is_parte_allcaps(view) is False

    def test_two_lines_accepted(self) -> None:
        spans = [
            _span("LE OBBLIGAZIONI ", line_index=0),
            _span("NASCENTI DALLA LEGGE", line_index=1),
        ]
        view = _view(spans)
        assert MaterialiStudioProfile._is_parte_allcaps(view) is True


# ===========================================================================
# Predicates — _is_capitolo
# ===========================================================================


class TestCapitolo:
    def test_lowercase_cap(self) -> None:
        view = _view([_span("Cap. 1")])
        assert MaterialiStudioProfile._is_capitolo(view) is True

    def test_uppercase_cap(self) -> None:
        view = _view([_span("CAP. 24")])
        assert MaterialiStudioProfile._is_capitolo(view) is True

    def test_cap_with_bis_suffix(self) -> None:
        view = _view([_span("CAP. 72-BIS")])
        assert MaterialiStudioProfile._is_capitolo(view) is True

    def test_cap_with_title(self) -> None:
        view = _view([_span("CAP. 5 - La proprietà")])
        assert MaterialiStudioProfile._is_capitolo(view) is True

    def test_cap_with_em_dash_title(self) -> None:
        view = _view([_span("Cap. 7 — Il possesso")])
        assert MaterialiStudioProfile._is_capitolo(view) is True

    def test_cap_with_en_dash_title(self) -> None:
        view = _view([_span("CAP. 81 – LA PUBBLICITA")])
        assert MaterialiStudioProfile._is_capitolo(view) is True

    def test_not_cap_pattern_rejected(self) -> None:
        view = _view([_span("Capitolo 1: introduzione")])
        assert MaterialiStudioProfile._is_capitolo(view) is False

    def test_too_long_rejected(self) -> None:
        view = _view([_span("Cap. 1 - " + "a" * HEADING_LINE_MAX_CHARS)])
        assert MaterialiStudioProfile._is_capitolo(view) is False

    def test_three_lines_rejected(self) -> None:
        spans = [
            _span("Cap. 1 - Lorem", line_index=0),
            _span("ipsum dolor", line_index=1),
            _span("sit amet", line_index=2),
        ]
        view = _view(spans)
        assert MaterialiStudioProfile._is_capitolo(view) is False


# ===========================================================================
# Predicates — _is_section_letter
# ===========================================================================


class TestSectionLetter:
    def test_basic_section(self) -> None:
        view = _view([_span("A. NOZIONI GENERALI.")])
        assert MaterialiStudioProfile._is_section_letter(view) is True

    def test_apostrophe_in_title(self) -> None:
        view = _view([_span("D. L'IPOTECA.")])
        assert MaterialiStudioProfile._is_section_letter(view) is True

    def test_lowercase_rejected(self) -> None:
        view = _view([_span("a. nozioni generali")])
        assert MaterialiStudioProfile._is_section_letter(view) is False

    def test_no_capital_after_dot_rejected(self) -> None:
        view = _view([_span("A. 12 nozioni")])
        assert MaterialiStudioProfile._is_section_letter(view) is False

    def test_too_long_rejected(self) -> None:
        view = _view([_span("A. " + "X" * HEADING_LINE_MAX_CHARS)])
        assert MaterialiStudioProfile._is_section_letter(view) is False

    def test_multi_line_rejected(self) -> None:
        spans = [
            _span("A. NOZIONI", line_index=0),
            _span("GENERALI.", line_index=1),
            _span("CONTINUATION", line_index=2),
        ]
        view = _view(spans)
        assert MaterialiStudioProfile._is_section_letter(view) is False


# ===========================================================================
# Predicates — _is_colon_or_dot_label
# ===========================================================================


class TestColonDotLabel:
    def test_colon_label(self) -> None:
        view = _view([_span("Diritto Europeo:")])
        assert MaterialiStudioProfile._is_colon_or_dot_label(view) is True

    def test_dot_label(self) -> None:
        view = _view([_span("Prolusione.")])
        assert MaterialiStudioProfile._is_colon_or_dot_label(view) is True

    def test_lowercase_start_rejected(self) -> None:
        view = _view([_span("diritto europeo:")])
        assert MaterialiStudioProfile._is_colon_or_dot_label(view) is False

    def test_too_short_rejected(self) -> None:
        view = _view([_span("Eu:")])
        assert MaterialiStudioProfile._is_colon_or_dot_label(view) is False

    def test_too_long_rejected(self) -> None:
        view = _view([_span("D" + "a" * 200 + ":")])
        assert MaterialiStudioProfile._is_colon_or_dot_label(view) is False

    def test_multi_line_rejected(self) -> None:
        spans = [
            _span("Prolusione.", line_index=0),
            _span("Continuation.", line_index=1),
        ]
        view = _view(spans)
        assert MaterialiStudioProfile._is_colon_or_dot_label(view) is False

    def test_neither_colon_nor_dot_rejected(self) -> None:
        view = _view([_span("Prolusione")])
        assert MaterialiStudioProfile._is_colon_or_dot_label(view) is False

    def test_dot_with_trailing_space(self) -> None:
        view = _view([_span("Prolusione.  ")])
        assert MaterialiStudioProfile._is_colon_or_dot_label(view) is True


# ===========================================================================
# Predicates — _is_dash_bullet
# ===========================================================================


class TestDashBullet:
    def test_dash_bullet_indented(self) -> None:
        view = _view(
            [_span("- prima voce")],
            bbox=(90.0, 100.0, 500.0, 130.0),
        )
        assert MaterialiStudioProfile._is_dash_bullet(view) is True

    def test_dash_bullet_at_body_margin_rejected(self) -> None:
        view = _view(
            [_span("- foo")],
            bbox=(72.0, 100.0, 500.0, 130.0),
        )
        assert MaterialiStudioProfile._is_dash_bullet(view) is False

    def test_three_spaces_bullet(self) -> None:
        view = _view(
            [_span("-   text after three spaces")],
            bbox=(90.0, 100.0, 500.0, 130.0),
        )
        assert MaterialiStudioProfile._is_dash_bullet(view) is True

    def test_no_dash_at_start_rejected(self) -> None:
        view = _view(
            [_span("text without dash")],
            bbox=(90.0, 100.0, 500.0, 130.0),
        )
        assert MaterialiStudioProfile._is_dash_bullet(view) is False

    def test_too_short_rejected(self) -> None:
        view = _view(
            [_span("-")],
            bbox=(90.0, 100.0, 500.0, 130.0),
        )
        assert MaterialiStudioProfile._is_dash_bullet(view) is False


# ===========================================================================
# Color-aware predicate
# ===========================================================================


class TestColorAwarePredicate:
    def test_bold_leading_returns_none(self) -> None:
        plugin = MaterialiStudioProfile()
        plugin._color_mode = True
        view = _view([_span("text", font="Arial-BoldMT", flags=BOLD_FLAG, color=0)])
        assert plugin._color_aware_predicate(view) is None

    def test_non_arial_returns_none(self) -> None:
        plugin = MaterialiStudioProfile()
        plugin._color_mode = True
        view = _view([_span("text", font="TimesNewRoman", flags=0, color=0x666666)])
        assert plugin._color_aware_predicate(view) is None

    def test_grey_light_promoted_heading_1(self) -> None:
        plugin = MaterialiStudioProfile()
        plugin._color_mode = True
        view = _view([_span("I SINGOLI CONTRATTI", font="ArialMT", flags=0, color=0x666666)])
        result = plugin._color_aware_predicate(view)
        assert result is not None
        assert result.category is SemanticCategory.HEADING_1

    def test_grey_medium_promoted_heading_3(self) -> None:
        plugin = MaterialiStudioProfile()
        plugin._color_mode = True
        view = _view([_span("Il deposito", font="ArialMT", flags=0, color=0x434343)])
        result = plugin._color_aware_predicate(view)
        assert result is not None
        assert result.category is SemanticCategory.HEADING_3

    def test_black_cap_promoted_heading_2(self) -> None:
        plugin = MaterialiStudioProfile()
        plugin._color_mode = True
        view = _view([_span("CAP. 42 - GLI ALTRI CONTRATTI", font="ArialMT", flags=0, color=0)])
        result = plugin._color_aware_predicate(view)
        assert result is not None
        assert result.category is SemanticCategory.HEADING_2

    def test_black_non_cap_returns_none(self) -> None:
        plugin = MaterialiStudioProfile()
        plugin._color_mode = True
        view = _view([_span("ordinary text", font="ArialMT", flags=0, color=0)])
        assert plugin._color_aware_predicate(view) is None

    def test_no_leading_returns_none(self) -> None:
        plugin = MaterialiStudioProfile()
        plugin._color_mode = True
        view = _BlockView(
            block_index=0,
            block=_block(span_range=(0, 0)),
            spans=(),
            text="",
            line_count=0,
            leading_span=None,
        )
        assert plugin._color_aware_predicate(view) is None


# ===========================================================================
# refine_classification — end-to-end mono mode
# ===========================================================================


class TestRefineClassificationMono:
    def test_empty_extraction(self) -> None:
        plugin = MaterialiStudioProfile()
        ext = _extraction([], [])
        out = plugin.refine_classification(ext, [])
        assert out == []
        # Warning queued: mono mode detected
        assert any("mono_mode" in w for w in plugin._pending_warnings)

    def test_artifact_passthrough(self) -> None:
        plugin = MaterialiStudioProfile()
        ext = _extraction(
            [_span("header")],
            [_block(span_range=(0, 1))],
        )
        verdict = _verdict(0, SemanticCategory.ARTIFACT_RUNNING_HEADER, "header_zone")
        out = plugin.refine_classification(ext, [verdict])
        assert out[0].category is SemanticCategory.ARTIFACT_RUNNING_HEADER

    def test_empty_page_passthrough(self) -> None:
        plugin = MaterialiStudioProfile()
        ext = _extraction([], [])
        verdict = ClassifiedBlock(
            block_index=-1,
            category=SemanticCategory.EMPTY_PAGE,
            subcategory="0",
            reason="empty_page",
        )
        out = plugin.refine_classification(ext, [verdict])
        assert out[0].category is SemanticCategory.EMPTY_PAGE
        assert out[0].block_index == -1

    def test_missing_view_passthrough(self) -> None:
        plugin = MaterialiStudioProfile()
        # Block with empty span range
        ext = _extraction([], [_block(span_range=(0, 0))])
        out = plugin.refine_classification(ext, [_verdict(0)])
        assert out[0].category is SemanticCategory.UNCLASSIFIED

    def test_em_dash_classified_filigree(self) -> None:
        plugin = MaterialiStudioProfile()
        ext = _extraction(
            [_span("—-------------------------")],
            [_block(span_range=(0, 1))],
        )
        out = plugin.refine_classification(ext, [_verdict(0)])
        assert out[0].category is SemanticCategory.ARTIFACT_FILIGREE

    def test_parte_allcaps_promoted(self) -> None:
        plugin = MaterialiStudioProfile()
        ext = _extraction(
            [_span("I DIRITTI REALI")],
            [_block(span_range=(0, 1))],
        )
        out = plugin.refine_classification(ext, [_verdict(0)])
        assert out[0].category is SemanticCategory.HEADING_1

    def test_capitolo_promoted(self) -> None:
        plugin = MaterialiStudioProfile()
        ext = _extraction(
            [_span("CAP. 5 - Le obbligazioni")],
            [_block(span_range=(0, 1))],
        )
        out = plugin.refine_classification(ext, [_verdict(0)])
        assert out[0].category is SemanticCategory.HEADING_2

    def test_section_letter_promoted(self) -> None:
        plugin = MaterialiStudioProfile()
        ext = _extraction(
            [_span("A. NOZIONI GENERALI.")],
            [_block(span_range=(0, 1))],
        )
        out = plugin.refine_classification(ext, [_verdict(0)])
        assert out[0].category is SemanticCategory.HEADING_3

    def test_colon_label_promoted(self) -> None:
        plugin = MaterialiStudioProfile()
        ext = _extraction(
            [_span("Diritto Europeo:")],
            [_block(span_range=(0, 1))],
        )
        out = plugin.refine_classification(ext, [_verdict(0)])
        assert out[0].category is SemanticCategory.HEADING_4

    def test_dot_label_promoted(self) -> None:
        plugin = MaterialiStudioProfile()
        ext = _extraction(
            [_span("Prolusione.")],
            [_block(span_range=(0, 1))],
        )
        out = plugin.refine_classification(ext, [_verdict(0)])
        assert out[0].category is SemanticCategory.HEADING_4

    def test_dash_bullet_promoted(self) -> None:
        plugin = MaterialiStudioProfile()
        ext = _extraction(
            [_span("- prima voce")],
            [_block(span_range=(0, 1), bbox=(90.0, 100.0, 500.0, 130.0))],
        )
        out = plugin.refine_classification(ext, [_verdict(0)])
        assert out[0].category is SemanticCategory.LIST_ITEM

    def test_body_default(self) -> None:
        plugin = MaterialiStudioProfile()
        ext = _extraction(
            [_span("Lorem ipsum dolor sit amet consectetur, etc...")],
            [_block(span_range=(0, 1))],
        )
        out = plugin.refine_classification(ext, [_verdict(0)])
        assert out[0].category is SemanticCategory.BODY

    def test_decimal_pattern_warning_queued(self) -> None:
        plugin = MaterialiStudioProfile()
        ext = _extraction(
            [_span("1.1 introduzione")],
            [_block(span_range=(0, 1))],
        )
        plugin.refine_classification(ext, [_verdict(0)])
        assert any("decimal_hierarchical" in w for w in plugin._pending_warnings)

    def test_roman_pattern_warning_queued(self) -> None:
        plugin = MaterialiStudioProfile()
        ext = _extraction(
            [_span("III. introduzione")],
            [_block(span_range=(0, 1))],
        )
        plugin.refine_classification(ext, [_verdict(0)])
        assert any("roman_hierarchical" in w for w in plugin._pending_warnings)


# ===========================================================================
# refine_classification — end-to-end color mode
# ===========================================================================


class TestRefineClassificationColor:
    def _color_mode_extraction(self) -> ExtractionResult:
        """Build an extraction with enough color signal to trigger color mode."""
        spans = [
            _span(
                "I SINGOLI CONTRATTI",
                font="ArialMT",
                flags=0,
                color=0x666666,
                block_index=0,
            ),
            _span("CAP. 39", font="ArialMT", flags=0, color=0, block_index=1),
            _span(
                "Il deposito",
                font="ArialMT",
                flags=0,
                color=0x434343,
                block_index=2,
            ),
            _span(
                "Body text Arial Bold",
                font="Arial-BoldMT",
                flags=BOLD_FLAG,
                color=0,
                block_index=3,
            ),
        ]
        blocks = [
            _block(block_index=0, span_range=(0, 1)),
            _block(block_index=1, span_range=(1, 2)),
            _block(block_index=2, span_range=(2, 3)),
            _block(block_index=3, span_range=(3, 4)),
        ]
        return _extraction(spans, blocks)

    def test_color_mode_promotes_heading_1(self) -> None:
        plugin = MaterialiStudioProfile()
        ext = self._color_mode_extraction()
        verdicts = [_verdict(i) for i in range(4)]
        out = plugin.refine_classification(ext, verdicts)
        assert plugin._color_mode is True
        assert out[0].category is SemanticCategory.HEADING_1

    def test_color_mode_promotes_heading_2(self) -> None:
        plugin = MaterialiStudioProfile()
        ext = self._color_mode_extraction()
        verdicts = [_verdict(i) for i in range(4)]
        out = plugin.refine_classification(ext, verdicts)
        assert out[1].category is SemanticCategory.HEADING_2

    def test_color_mode_promotes_heading_3(self) -> None:
        plugin = MaterialiStudioProfile()
        ext = self._color_mode_extraction()
        verdicts = [_verdict(i) for i in range(4)]
        out = plugin.refine_classification(ext, verdicts)
        assert out[2].category is SemanticCategory.HEADING_3

    def test_color_mode_body_default(self) -> None:
        plugin = MaterialiStudioProfile()
        ext = self._color_mode_extraction()
        verdicts = [_verdict(i) for i in range(4)]
        out = plugin.refine_classification(ext, verdicts)
        assert out[3].category is SemanticCategory.BODY


# ===========================================================================
# refine_reconstruction
# ===========================================================================


class TestRefineReconstruction:
    def test_passthrough_no_warnings(self) -> None:
        plugin = MaterialiStudioProfile()
        doc = Document(root=())
        out = plugin.refine_reconstruction(doc, _extraction([], []), [])
        assert out is doc

    def test_passthrough_with_pending_warnings(self) -> None:
        plugin = MaterialiStudioProfile()
        plugin._pending_warnings = [f"{WARNING_PREFIX}:mono_mode_no_color_signal"]
        doc = Document(root=())
        out = plugin.refine_reconstruction(doc, _extraction([], []), [])
        assert WARNING_PREFIX + ":mono_mode_no_color_signal" in out.warnings
        # _pending_warnings cleared after flush
        assert plugin._pending_warnings == []

    def test_preserves_existing_warnings(self) -> None:
        plugin = MaterialiStudioProfile()
        plugin._pending_warnings = [f"{WARNING_PREFIX}:mono_mode_no_color_signal"]
        doc = Document(root=(), warnings=("prior_warning",))
        out = plugin.refine_reconstruction(doc, _extraction([], []), [])
        assert "prior_warning" in out.warnings
        assert WARNING_PREFIX + ":mono_mode_no_color_signal" in out.warnings


# ===========================================================================
# refine_apparatus
# ===========================================================================


class TestRefineApparatus:
    def test_passthrough(self) -> None:
        plugin = MaterialiStudioProfile()
        doc = Document(root=(Node(id="node_0001", category=SemanticCategory.BODY, page_index=0),))
        out = plugin.refine_apparatus(doc, _extraction([], []), [])
        assert out is doc


# ===========================================================================
# _view helper
# ===========================================================================


class TestView:
    def test_view_with_spans(self) -> None:
        spans = [_span("text")]
        ext = _extraction(spans, [_block(span_range=(0, 1))])
        view = MaterialiStudioProfile._view(ext, 0)
        assert view is not None
        assert view.text == "text"
        assert view.line_count == 1

    def test_view_empty_spans_returns_none(self) -> None:
        ext = _extraction([], [_block(span_range=(0, 0))])
        view = MaterialiStudioProfile._view(ext, 0)
        assert view is None

    def test_view_multi_line_count(self) -> None:
        spans = [
            _span("line1", line_index=0),
            _span("line2", line_index=1),
            _span("line3", line_index=2),
        ]
        ext = _extraction(spans, [_block(span_range=(0, 3))])
        view = MaterialiStudioProfile._view(ext, 0)
        assert view is not None
        assert view.line_count == 3

    def test_view_leading_span_skips_whitespace(self) -> None:
        spans = [
            _span("   "),
            _span("real_text"),
        ]
        ext = _extraction(spans, [_block(span_range=(0, 2))])
        view = MaterialiStudioProfile._view(ext, 0)
        assert view is not None
        assert view.leading_span is not None
        assert view.leading_span.text == "real_text"

    def test_view_all_whitespace_returns_first_span(self) -> None:
        spans = [_span("   "), _span("\t\n")]
        ext = _extraction(spans, [_block(span_range=(0, 2))])
        view = MaterialiStudioProfile._view(ext, 0)
        assert view is not None
        assert view.leading_span is not None
        assert view.leading_span.text == "   "


# ===========================================================================
# Bidirectional non-promotion vs sister plugins (signal-level)
# ===========================================================================


class TestSisterPluginNonPromotion:
    """Verify the producer short-circuit blocks promotion on every editorial
    fixture signature simulated synthetically.
    """

    @pytest.mark.parametrize(
        "producer",
        [
            "Aspose.PDF for .NET 18.4",
            "PDFsharp 1.31.1789-g",
            "PDFsharp 1.50.5147",
            "Acrobat Distiller 11.0.23",
            "Acrobat 11.0.23 Paper Capture Plug-in",
            "iLovePDF 2.0",
            "PScript5.dll Version 5.2.2",
            "Adobe PDF Library 15.0",
            "Adobe InDesign CC 14.0",
            "ABCpdf 11.0",
        ],
    )
    def test_editorial_producer_clamps_to_zero(self, producer: str) -> None:
        sig = _signals(producer=producer, creator=producer)
        assert MaterialiStudioProfile.matches(sig) == 0.0


# ===========================================================================
# Sanity: get_categories includes pass-throughs
# ===========================================================================


def test_categories_contains_bookpageanchor() -> None:
    plugin = MaterialiStudioProfile()
    assert SemanticCategory.BOOK_PAGE_ANCHOR in plugin.get_categories()
