# ruff: noqa: RUF001
"""Unit tests for the materiali_studio corpus plugin."""

from __future__ import annotations

import pytest

from scabopdf_pipeline.classification.types import ClassifiedBlock
from scabopdf_pipeline.extraction.types import Block, ExtractionResult, Span
from scabopdf_pipeline.profiles.materiali_studio import (
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
from scabopdf_pipeline.profiling.typography_constants import APPARATUS_PRESENCE_THRESHOLD
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


# ===========================================================================
# Predicates — _classify_decimal_heading
# ===========================================================================


class TestDecimalHeading:
    """Decimal heading convention updated in CARRYOVER v2.33 (debt (v)):
    depth-1 → HEADING_2, depth-2 → HEADING_3, depth-3 → HEADING_4,
    depth-4+ → unsupported. Was depth-2→HEADING_2 before; the change is
    forward-looking (no real-fixture regression among the four prior
    monoculture fixtures, which exercise zero decimal headings) and
    aligns with the natural reading where the chapter occupies HEADING_1.
    """

    def test_depth_2_returns_heading_3(self) -> None:
        plugin = MaterialiStudioProfile()
        view = _view([_span("1.1 Introduzione")])
        result = plugin._classify_decimal_heading(view)
        assert result is not None
        assert result.category is SemanticCategory.HEADING_3

    def test_depth_3_returns_heading_4(self) -> None:
        plugin = MaterialiStudioProfile()
        view = _view([_span("1.1.1 Sotto-paragrafo")])
        result = plugin._classify_decimal_heading(view)
        assert result is not None
        assert result.category is SemanticCategory.HEADING_4

    def test_depth_4_returns_none_with_warning(self) -> None:
        plugin = MaterialiStudioProfile()
        view = _view([_span("1.1.1.1 Quarto livello")])
        result = plugin._classify_decimal_heading(view)
        assert result is None
        assert any("depth_exceeded" in w for w in plugin._pending_warnings)

    def test_multi_digit_numbers(self) -> None:
        plugin = MaterialiStudioProfile()
        view = _view([_span("12.34 Numerazione a due cifre")])
        result = plugin._classify_decimal_heading(view)
        assert result is not None
        assert result.category is SemanticCategory.HEADING_3

    def test_depth_5_returns_none_with_warning(self) -> None:
        plugin = MaterialiStudioProfile()
        view = _view([_span("1.2.3.4.5 Profondità eccessiva")])
        result = plugin._classify_decimal_heading(view)
        assert result is None
        assert any("depth_exceeded" in w for w in plugin._pending_warnings)

    def test_no_match_no_decimal(self) -> None:
        plugin = MaterialiStudioProfile()
        view = _view([_span("Plain body text without numbering")])
        assert plugin._classify_decimal_heading(view) is None

    def test_match_single_int_promoted_heading_2(self) -> None:
        plugin = MaterialiStudioProfile()
        # Single integer like "1. Foo" is now recognised as a depth-1
        # decimal heading (HEADING_2). The v2.33 convention treats the
        # integer-only prefix as a valid hierarchical numbering when
        # followed by an uppercase title; the title length cap and the
        # single-line guard filter false positives from body sentences.
        view = _view([_span("1. Foo")])
        result = plugin._classify_decimal_heading(view)
        assert result is not None
        assert result.category is SemanticCategory.HEADING_2

    def test_no_match_lowercase_after_dot(self) -> None:
        plugin = MaterialiStudioProfile()
        # Lowercase after the numbering rejects the match (body sentence).
        view = _view([_span("1.1 introduzione minuscola")])
        assert plugin._classify_decimal_heading(view) is None

    def test_no_match_too_long(self) -> None:
        plugin = MaterialiStudioProfile()
        view = _view([_span("1.1 " + "Y" * HEADING_LINE_MAX_CHARS)])
        assert plugin._classify_decimal_heading(view) is None

    def test_no_match_multi_line(self) -> None:
        plugin = MaterialiStudioProfile()
        spans = [
            _span("1.1 Titolo", line_index=0),
            _span("continuation", line_index=1),
            _span("third line", line_index=2),
        ]
        view = _view(spans)
        assert plugin._classify_decimal_heading(view) is None

    def test_no_match_cross_reference_inline(self) -> None:
        plugin = MaterialiStudioProfile()
        # A cross-reference like "art. 1.1 c.c." does not start with the
        # digit (block opens with "art.") so the anchor fails.
        view = _view([_span("art. 1.1 c.c. è applicabile")])
        assert plugin._classify_decimal_heading(view) is None

    def test_no_match_date_pattern(self) -> None:
        plugin = MaterialiStudioProfile()
        # Date "25.12.2023" lacks an uppercase letter after the numeral.
        view = _view([_span("25.12.2023 questo è il body con la data")])
        # The "questo" lowercase q after 2023 prevents match.
        assert plugin._classify_decimal_heading(view) is None

    def test_match_with_dot_after_numbering(self) -> None:
        # Allows the pattern "1.1. Title" with a trailing dot after the
        # numbering before the space.
        plugin = MaterialiStudioProfile()
        view = _view([_span("1.1. Titolo con punto dopo numerazione")])
        result = plugin._classify_decimal_heading(view)
        assert result is not None
        assert result.category is SemanticCategory.HEADING_3


# ===========================================================================
# Predicates — _classify_roman_heading + _is_valid_roman_numeral
# ===========================================================================


class TestRomanHeading:
    def test_ii_returns_heading_1(self) -> None:
        plugin = MaterialiStudioProfile()
        view = _view([_span("II. STORIA")])
        result = plugin._classify_roman_heading(view)
        assert result is not None
        assert result.category is SemanticCategory.HEADING_1

    def test_iii_returns_heading_1(self) -> None:
        plugin = MaterialiStudioProfile()
        view = _view([_span("III. CARATTERI GENERALI")])
        result = plugin._classify_roman_heading(view)
        assert result is not None
        assert result.category is SemanticCategory.HEADING_1

    def test_iv_returns_heading_1(self) -> None:
        plugin = MaterialiStudioProfile()
        view = _view([_span("IV. DOTTRINA E GIURISPRUDENZA")])
        result = plugin._classify_roman_heading(view)
        assert result is not None
        assert result.category is SemanticCategory.HEADING_1

    def test_ix_returns_heading_1(self) -> None:
        plugin = MaterialiStudioProfile()
        view = _view([_span("IX. CONCLUSIONI")])
        result = plugin._classify_roman_heading(view)
        assert result is not None

    def test_xiv_returns_heading_1(self) -> None:
        plugin = MaterialiStudioProfile()
        view = _view([_span("XIV. APPENDICE")])
        result = plugin._classify_roman_heading(view)
        assert result is not None
        assert result.category is SemanticCategory.HEADING_1

    def test_single_letter_i_returns_none(self) -> None:
        # "I." as single letter is deliberately handled by section_letter,
        # not by the roman predicate.
        plugin = MaterialiStudioProfile()
        view = _view([_span("I. Foo")])
        assert plugin._classify_roman_heading(view) is None

    def test_single_letter_v_returns_none(self) -> None:
        plugin = MaterialiStudioProfile()
        view = _view([_span("V. Roma")])
        assert plugin._classify_roman_heading(view) is None

    def test_single_letter_c_returns_none(self) -> None:
        plugin = MaterialiStudioProfile()
        view = _view([_span("C. USUFRUTTO")])
        assert plugin._classify_roman_heading(view) is None

    def test_invalid_roman_iiiiii_returns_none(self) -> None:
        plugin = MaterialiStudioProfile()
        # Eight Is in a row is not a canonical roman numeral.
        view = _view([_span("IIIIIIII. INVALID")])
        assert plugin._classify_roman_heading(view) is None

    def test_lowercase_after_dot_returns_none(self) -> None:
        plugin = MaterialiStudioProfile()
        view = _view([_span("II. introduzione minuscola")])
        assert plugin._classify_roman_heading(view) is None

    def test_too_long_returns_none(self) -> None:
        plugin = MaterialiStudioProfile()
        view = _view([_span("II. " + "Y" * HEADING_LINE_MAX_CHARS)])
        assert plugin._classify_roman_heading(view) is None

    def test_multi_line_returns_none(self) -> None:
        plugin = MaterialiStudioProfile()
        spans = [
            _span("II. STORIA", line_index=0),
            _span("CONT", line_index=1),
            _span("MORE", line_index=2),
        ]
        view = _view(spans)
        assert plugin._classify_roman_heading(view) is None

    def test_valid_roman_basic(self) -> None:
        assert MaterialiStudioProfile._is_valid_roman_numeral("II") is True
        assert MaterialiStudioProfile._is_valid_roman_numeral("III") is True
        assert MaterialiStudioProfile._is_valid_roman_numeral("IV") is True
        assert MaterialiStudioProfile._is_valid_roman_numeral("IX") is True
        assert MaterialiStudioProfile._is_valid_roman_numeral("XX") is True
        assert MaterialiStudioProfile._is_valid_roman_numeral("XXXVIII") is True

    def test_invalid_roman_too_short(self) -> None:
        assert MaterialiStudioProfile._is_valid_roman_numeral("I") is False
        assert MaterialiStudioProfile._is_valid_roman_numeral("") is False

    def test_invalid_roman_too_long(self) -> None:
        assert MaterialiStudioProfile._is_valid_roman_numeral("X" * 9) is False

    def test_invalid_roman_garbage(self) -> None:
        assert MaterialiStudioProfile._is_valid_roman_numeral("IIIIII") is False
        assert MaterialiStudioProfile._is_valid_roman_numeral("XVIIII") is False


# ===========================================================================
# Section letter still wins over roman on single letters like "C."
# ===========================================================================


class TestRomanVsSectionLetterDispatch:
    def test_single_c_goes_through_section_letter(self) -> None:
        # End-to-end: "C. USUFRUTTO" must end up as HEADING_3 via the
        # section-letter predicate, not as HEADING_1 via the roman.
        plugin = MaterialiStudioProfile()
        ext = _extraction(
            [_span("C. USUFRUTTO, USO E ABITAZIONE")],
            [_block(span_range=(0, 1))],
        )
        out = plugin.refine_classification(ext, [_verdict(0)])
        assert out[0].category is SemanticCategory.HEADING_3


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

    def test_decimal_n_m_promoted_heading_3(self) -> None:
        plugin = MaterialiStudioProfile()
        ext = _extraction(
            [_span("1.1 Introduzione")],
            [_block(span_range=(0, 1))],
        )
        out = plugin.refine_classification(ext, [_verdict(0)])
        assert out[0].category is SemanticCategory.HEADING_3
        assert any(
            "heading_3_decimal" in w and "numbering_1.1" in w for w in plugin._pending_warnings
        )

    def test_decimal_n_m_k_promoted_heading_4(self) -> None:
        plugin = MaterialiStudioProfile()
        ext = _extraction(
            [_span("2.3.4 Argomento specifico")],
            [_block(span_range=(0, 1))],
        )
        out = plugin.refine_classification(ext, [_verdict(0)])
        assert out[0].category is SemanticCategory.HEADING_4
        assert any(
            "heading_4_decimal" in w and "numbering_2.3.4" in w for w in plugin._pending_warnings
        )

    def test_decimal_n_m_k_l_unsupported_falls_to_body(self) -> None:
        plugin = MaterialiStudioProfile()
        ext = _extraction(
            [_span("4.1.2.3 Sotto-sotto-paragrafo")],
            [_block(span_range=(0, 1))],
        )
        out = plugin.refine_classification(ext, [_verdict(0)])
        # Depth 4 is unsupported in v2.33; the block falls through to BODY
        # and emits the depth_exceeded warning.
        assert out[0].category is SemanticCategory.BODY
        assert any(
            "depth_exceeded" in w and "numbering_4.1.2.3" in w for w in plugin._pending_warnings
        )

    def test_decimal_depth_5_unsupported_warning(self) -> None:
        plugin = MaterialiStudioProfile()
        ext = _extraction(
            [_span("1.2.3.4.5 Profondità eccessiva")],
            [_block(span_range=(0, 1))],
        )
        out = plugin.refine_classification(ext, [_verdict(0)])
        # Depth 5: not promoted, falls through to BODY
        assert out[0].category is SemanticCategory.BODY
        assert any("decimal_hierarchical_depth_exceeded" in w for w in plugin._pending_warnings)

    def test_roman_ii_promoted_heading_1(self) -> None:
        plugin = MaterialiStudioProfile()
        ext = _extraction(
            [_span("II. STORIA")],
            [_block(span_range=(0, 1))],
        )
        out = plugin.refine_classification(ext, [_verdict(0)])
        assert out[0].category is SemanticCategory.HEADING_1
        assert any("heading_1_roman" in w and "numeral_II" in w for w in plugin._pending_warnings)

    def test_roman_iii_promoted_heading_1(self) -> None:
        plugin = MaterialiStudioProfile()
        ext = _extraction(
            [_span("III. CARATTERI GENERALI")],
            [_block(span_range=(0, 1))],
        )
        out = plugin.refine_classification(ext, [_verdict(0)])
        assert out[0].category is SemanticCategory.HEADING_1
        assert any("numeral_III" in w for w in plugin._pending_warnings)

    def test_roman_ix_promoted_heading_1(self) -> None:
        plugin = MaterialiStudioProfile()
        ext = _extraction(
            [_span("IX. CONCLUSIONI")],
            [_block(span_range=(0, 1))],
        )
        out = plugin.refine_classification(ext, [_verdict(0)])
        assert out[0].category is SemanticCategory.HEADING_1
        assert any("numeral_IX" in w for w in plugin._pending_warnings)


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


def test_categories_contains_toc_general() -> None:
    """The plugin now emits TOC_GENERAL for Word/GDocs automatic ToC entries."""
    plugin = MaterialiStudioProfile()
    assert SemanticCategory.TOC_GENERAL in plugin.get_categories()


# ===========================================================================
# debt-(v) consolidation: Word automatic ToC (Sommario) recognition.
# Landed in CARRYOVER v2.33 after empirical calibration against
# materiali_diritto_privato_con_toc.pdf (Microsoft Word per Microsoft 365,
# A4, Calibri body, three-level hierarchical ToC with dotted leader).
# ===========================================================================


from scabopdf_pipeline.profiles.materiali_studio import (  # noqa: E402
    BODY_FAMILY_PREFIXES,
    _is_user_body_family,
    _parse_toc_entry_text,
)


class TestCalibriBodyFamilySupport:
    """matches() must clear the 0.6 dispatcher threshold on Word documents
    with Calibri as the dominant body family (the canonical Word default
    since Word 2007). The four prior calibrating fixtures used Arial
    monoculture; the debt-(v) fixture exposes Calibri.
    """

    def test_word_calibri_a4_clears_threshold(self) -> None:
        sig = _signals(
            producer="Microsoft® Word per Microsoft 365",
            creator="Microsoft® Word per Microsoft 365",
            body_family="Calibri",
            body_size=11.04,
            body_dominance=98.0,
        )
        score = MaterialiStudioProfile.matches(sig)
        assert score >= 0.70

    def test_word_calibri_bold_variant_recognised(self) -> None:
        sig = _signals(
            producer="Microsoft® Word per Microsoft 365",
            body_family="Calibri-Bold",
            body_dominance=95.0,
        )
        score = MaterialiStudioProfile.matches(sig)
        assert score >= 0.70

    def test_arial_still_recognised(self) -> None:
        # Backward compatibility with the four prior fixtures.
        sig = _signals(body_family="ArialMT")
        score = MaterialiStudioProfile.matches(sig)
        assert score >= 0.70

    def test_unknown_family_no_credit(self) -> None:
        sig = _signals(body_family="TimesNewRomanPSMT")
        score = MaterialiStudioProfile.matches(sig)
        assert score < 0.70

    def test_body_family_prefixes_constant(self) -> None:
        assert "Arial" in BODY_FAMILY_PREFIXES
        assert "Calibri" in BODY_FAMILY_PREFIXES

    def test_is_user_body_family_arial_variants(self) -> None:
        assert _is_user_body_family("ArialMT")
        assert _is_user_body_family("Arial-BoldMT")
        assert _is_user_body_family("Arial-ItalicMT")

    def test_is_user_body_family_calibri_variants(self) -> None:
        assert _is_user_body_family("Calibri")
        assert _is_user_body_family("Calibri-Bold")
        assert _is_user_body_family("Calibri-Italic")

    def test_is_user_body_family_rejects_unknown(self) -> None:
        assert not _is_user_body_family("TimesNewRomanPSMT")
        assert not _is_user_body_family("Verdana")
        assert not _is_user_body_family("Helvetica")


class TestTocHeaderPredicate:
    """``_classify_toc_header`` recognises the Word/GDocs automatic ToC
    header marker (Sommario / Indice / Contents / Table of Contents)
    when typeset as a bold user-body-family span ≥ 14pt.
    """

    def test_sommario_calibri_bold_18pt(self) -> None:
        spans = [_span("Sommario ", font="Calibri-Bold", size=18.0, flags=BOLD_FLAG)]
        view = _view(spans, block_index=3, page=1)
        plugin = MaterialiStudioProfile()
        plugin._color_mode = False
        plugin._pending_warnings = []
        verdict = plugin._classify_toc_header(view)
        assert verdict is not None
        assert verdict.category is SemanticCategory.HEADING_1
        assert verdict.reason == "materiali_studio_heading_1_toc_header"

    def test_indice_italian_variant(self) -> None:
        spans = [_span("Indice", font="Calibri-Bold", size=16.0, flags=BOLD_FLAG)]
        view = _view(spans)
        plugin = MaterialiStudioProfile()
        plugin._pending_warnings = []
        assert plugin._classify_toc_header(view) is not None

    def test_indice_generale_italian_variant(self) -> None:
        spans = [_span("Indice generale", font="Calibri-Bold", size=14.0, flags=BOLD_FLAG)]
        view = _view(spans)
        plugin = MaterialiStudioProfile()
        plugin._pending_warnings = []
        assert plugin._classify_toc_header(view) is not None

    def test_contents_english_variant(self) -> None:
        spans = [_span("Contents", font="Arial-BoldMT", size=18.0, flags=BOLD_FLAG)]
        view = _view(spans)
        plugin = MaterialiStudioProfile()
        plugin._pending_warnings = []
        assert plugin._classify_toc_header(view) is not None

    def test_table_of_contents_english(self) -> None:
        spans = [_span("Table of Contents", font="Arial-BoldMT", size=18.0, flags=BOLD_FLAG)]
        view = _view(spans)
        plugin = MaterialiStudioProfile()
        plugin._pending_warnings = []
        assert plugin._classify_toc_header(view) is not None

    def test_case_insensitive(self) -> None:
        spans = [_span("SOMMARIO", font="Calibri-Bold", size=18.0, flags=BOLD_FLAG)]
        view = _view(spans)
        plugin = MaterialiStudioProfile()
        plugin._pending_warnings = []
        assert plugin._classify_toc_header(view) is not None

    def test_rejects_body_sized_sommario(self) -> None:
        # An inline body mention of "Sommario" at body size must NOT promote.
        spans = [_span("Sommario", font="Calibri", size=11.04, flags=0)]
        view = _view(spans)
        plugin = MaterialiStudioProfile()
        plugin._pending_warnings = []
        assert plugin._classify_toc_header(view) is None

    def test_rejects_non_bold_at_size(self) -> None:
        spans = [_span("Sommario", font="Calibri", size=18.0, flags=0)]
        view = _view(spans)
        plugin = MaterialiStudioProfile()
        plugin._pending_warnings = []
        assert plugin._classify_toc_header(view) is None

    def test_rejects_non_user_family(self) -> None:
        spans = [_span("Sommario", font="TimesNewRomanPSMT", size=18.0, flags=BOLD_FLAG)]
        view = _view(spans)
        plugin = MaterialiStudioProfile()
        plugin._pending_warnings = []
        assert plugin._classify_toc_header(view) is None

    def test_rejects_non_matching_text(self) -> None:
        spans = [_span("Premessa", font="Calibri-Bold", size=18.0, flags=BOLD_FLAG)]
        view = _view(spans)
        plugin = MaterialiStudioProfile()
        plugin._pending_warnings = []
        assert plugin._classify_toc_header(view) is None

    def test_rejects_size_below_floor(self) -> None:
        spans = [_span("Sommario", font="Calibri-Bold", size=12.0, flags=BOLD_FLAG)]
        view = _view(spans)
        plugin = MaterialiStudioProfile()
        plugin._pending_warnings = []
        assert plugin._classify_toc_header(view) is None

    def test_emits_warning(self) -> None:
        spans = [_span("Sommario", font="Calibri-Bold", size=18.0, flags=BOLD_FLAG)]
        view = _view(spans, block_index=3, page=1)
        plugin = MaterialiStudioProfile()
        plugin._pending_warnings = []
        plugin._classify_toc_header(view)
        assert any("heading_1_toc_header_block_3_page_1" in w for w in plugin._pending_warnings)


class TestTocEntryPredicate:
    """``_classify_toc_entry`` recognises a dotted-leader ToC entry block
    of the Word/GDocs format ``"<title> .................. <page>"``.
    """

    def test_capitolo_entry_with_em_dash(self) -> None:
        text = "Capitolo I — Nozioni Generali ......................... 3 "
        spans = [_span(text, font="Calibri", size=11.04, flags=0)]
        view = _view(spans, block_index=4, page=1)
        plugin = MaterialiStudioProfile()
        plugin._pending_warnings = []
        verdict = plugin._classify_toc_entry(view)
        assert verdict is not None
        assert verdict.category is SemanticCategory.TOC_GENERAL

    def test_decimal_entry_depth_one(self) -> None:
        text = "1. Definizione di obbligazione ............................. 3 "
        spans = [_span(text, font="Calibri", size=11.04, flags=0)]
        view = _view(spans)
        plugin = MaterialiStudioProfile()
        plugin._pending_warnings = []
        assert plugin._classify_toc_entry(view) is not None

    def test_decimal_entry_depth_two(self) -> None:
        text = "2.1 Il soggetto attivo ...................................... 3 "
        spans = [_span(text, font="Calibri", size=11.04, flags=0)]
        view = _view(spans)
        plugin = MaterialiStudioProfile()
        plugin._pending_warnings = []
        assert plugin._classify_toc_entry(view) is not None

    def test_entry_glued_to_leader_no_whitespace(self) -> None:
        # Word occasionally omits the space between title and dotted leader.
        text = "2. Inadempimento....................................... 5 "
        spans = [_span(text, font="Calibri", size=11.04, flags=0)]
        view = _view(spans)
        plugin = MaterialiStudioProfile()
        plugin._pending_warnings = []
        assert plugin._classify_toc_entry(view) is not None

    def test_short_dotted_run_no_whitespace_rejected(self) -> None:
        # A body sentence like "Foo... 3" with 3 dots and no whitespace
        # must NOT match (the no-whitespace branch requires 6+ dots).
        text = "Foo... 3"
        spans = [_span(text, font="Calibri", size=11.04, flags=0)]
        view = _view(spans)
        plugin = MaterialiStudioProfile()
        plugin._pending_warnings = []
        assert plugin._classify_toc_entry(view) is None

    def test_unicode_ellipsis_leader(self) -> None:
        text = "Premessa ………… 7"  # U+2026 ellipsis x4
        spans = [_span(text, font="Calibri", size=11.04, flags=0)]
        view = _view(spans)
        plugin = MaterialiStudioProfile()
        plugin._pending_warnings = []
        assert plugin._classify_toc_entry(view) is not None

    def test_no_dotted_leader_rejected(self) -> None:
        text = "Capitolo I — Nozioni Generali"
        spans = [_span(text, font="Calibri", size=11.04, flags=0)]
        view = _view(spans)
        plugin = MaterialiStudioProfile()
        plugin._pending_warnings = []
        assert plugin._classify_toc_entry(view) is None

    def test_no_page_number_rejected(self) -> None:
        text = "Capitolo I — Nozioni Generali ......................... "
        spans = [_span(text, font="Calibri", size=11.04, flags=0)]
        view = _view(spans)
        plugin = MaterialiStudioProfile()
        plugin._pending_warnings = []
        assert plugin._classify_toc_entry(view) is None

    def test_non_user_family_rejected(self) -> None:
        text = "Foo ......................... 3"
        spans = [_span(text, font="TimesNewRomanPSMT", size=11.04, flags=0)]
        view = _view(spans)
        plugin = MaterialiStudioProfile()
        plugin._pending_warnings = []
        assert plugin._classify_toc_entry(view) is None

    def test_emits_warning(self) -> None:
        text = "Capitolo I — Nozioni Generali ......................... 3"
        spans = [_span(text, font="Calibri", size=11.04, flags=0)]
        view = _view(spans, block_index=4, page=1)
        plugin = MaterialiStudioProfile()
        plugin._pending_warnings = []
        plugin._classify_toc_entry(view)
        assert any("toc_entry_dotted_leader_block_4_page_1" in w for w in plugin._pending_warnings)


class TestCapitoloFullPredicate:
    """``_classify_capitolo_full`` recognises the body-side
    ``Capitolo <roman> — title`` chapter heading convention.
    """

    def test_capitolo_roman_em_dash(self) -> None:
        text = "Capitolo I — Nozioni Generali "
        spans = [_span(text, font="Calibri-Bold", size=18.0, flags=BOLD_FLAG)]
        view = _view(spans, block_index=18, page=2)
        plugin = MaterialiStudioProfile()
        plugin._pending_warnings = []
        verdict = plugin._classify_capitolo_full(view)
        assert verdict is not None
        assert verdict.category is SemanticCategory.HEADING_1
        assert verdict.reason == "materiali_studio_heading_1_capitolo_full"

    def test_capitolo_roman_en_dash(self) -> None:
        text = "Capitolo II – Le Fonti delle Obbligazioni"
        spans = [_span(text, font="Calibri-Bold", size=18.0, flags=BOLD_FLAG)]
        view = _view(spans)
        plugin = MaterialiStudioProfile()
        plugin._pending_warnings = []
        assert plugin._classify_capitolo_full(view) is not None

    def test_capitolo_roman_ascii_hyphen(self) -> None:
        text = "Capitolo III - L'Adempimento"
        spans = [_span(text, font="Calibri-Bold", size=18.0, flags=BOLD_FLAG)]
        view = _view(spans)
        plugin = MaterialiStudioProfile()
        plugin._pending_warnings = []
        assert plugin._classify_capitolo_full(view) is not None

    def test_capitolo_roman_colon(self) -> None:
        text = "Capitolo IV: Modalità"
        spans = [_span(text, font="Calibri-Bold", size=18.0, flags=BOLD_FLAG)]
        view = _view(spans)
        plugin = MaterialiStudioProfile()
        plugin._pending_warnings = []
        assert plugin._classify_capitolo_full(view) is not None

    def test_capitolo_without_separator_rejected(self) -> None:
        text = "Capitolo I Nozioni Generali"
        spans = [_span(text, font="Calibri-Bold", size=18.0, flags=BOLD_FLAG)]
        view = _view(spans)
        plugin = MaterialiStudioProfile()
        plugin._pending_warnings = []
        assert plugin._classify_capitolo_full(view) is None

    def test_capitolo_lowercase_keyword_rejected(self) -> None:
        # Case-insensitive — "capitolo" passes but the leading capital is
        # expected by Word default. We accept both per docstring.
        text = "capitolo I — title "
        spans = [_span(text, font="Calibri-Bold", size=18.0, flags=BOLD_FLAG)]
        view = _view(spans)
        plugin = MaterialiStudioProfile()
        plugin._pending_warnings = []
        assert plugin._classify_capitolo_full(view) is not None

    def test_not_bold_rejected(self) -> None:
        text = "Capitolo I — Nozioni Generali"
        spans = [_span(text, font="Calibri", size=18.0, flags=0)]
        view = _view(spans)
        plugin = MaterialiStudioProfile()
        plugin._pending_warnings = []
        assert plugin._classify_capitolo_full(view) is None

    def test_emits_warning(self) -> None:
        text = "Capitolo I — Nozioni Generali"
        spans = [_span(text, font="Calibri-Bold", size=18.0, flags=BOLD_FLAG)]
        view = _view(spans, block_index=18, page=2)
        plugin = MaterialiStudioProfile()
        plugin._pending_warnings = []
        plugin._classify_capitolo_full(view)
        assert any("heading_1_capitolo_full_block_18_page_2" in w for w in plugin._pending_warnings)


class TestDecimalHeadingDepthOneConvention:
    """The updated convention (debt-(v) consolidation): depth-1 → HEADING_2,
    depth-2 → HEADING_3, depth-3 → HEADING_4, depth-4+ → unsupported.
    """

    def test_depth_one_promotes_heading_2(self) -> None:
        text = "1. Definizione di obbligazione "
        spans = [_span(text, font="Calibri-Bold", size=14.04, flags=BOLD_FLAG)]
        view = _view(spans, block_index=19, page=2)
        plugin = MaterialiStudioProfile()
        plugin._pending_warnings = []
        verdict = plugin._classify_decimal_heading(view)
        assert verdict is not None
        assert verdict.category is SemanticCategory.HEADING_2
        assert verdict.reason == "materiali_studio_heading_2_decimal"

    def test_depth_two_promotes_heading_3(self) -> None:
        text = "2.1 Il soggetto attivo "
        spans = [_span(text, font="Calibri-Bold", size=12.0, flags=BOLD_FLAG)]
        view = _view(spans)
        plugin = MaterialiStudioProfile()
        plugin._pending_warnings = []
        verdict = plugin._classify_decimal_heading(view)
        assert verdict is not None
        assert verdict.category is SemanticCategory.HEADING_3

    def test_depth_three_promotes_heading_4(self) -> None:
        text = "2.1.3 Argomento sub-paragrafo"
        spans = [_span(text, font="Calibri-Bold", size=11.0, flags=BOLD_FLAG)]
        view = _view(spans)
        plugin = MaterialiStudioProfile()
        plugin._pending_warnings = []
        verdict = plugin._classify_decimal_heading(view)
        assert verdict is not None
        assert verdict.category is SemanticCategory.HEADING_4

    def test_depth_four_unsupported_and_warns(self) -> None:
        text = "1.2.3.4 Sub-sub-sub"
        spans = [_span(text, font="Calibri-Bold", size=11.0, flags=BOLD_FLAG)]
        view = _view(spans, block_index=99, page=5)
        plugin = MaterialiStudioProfile()
        plugin._pending_warnings = []
        verdict = plugin._classify_decimal_heading(view)
        assert verdict is None
        assert any("decimal_hierarchical_depth_exceeded" in w for w in plugin._pending_warnings)

    def test_no_uppercase_after_number_rejected(self) -> None:
        text = "1.1 lowercase prose"
        spans = [_span(text, font="Calibri-Bold", size=12.0, flags=BOLD_FLAG)]
        view = _view(spans)
        plugin = MaterialiStudioProfile()
        plugin._pending_warnings = []
        assert plugin._classify_decimal_heading(view) is None


class TestParseTocEntryText:
    """The module-level helper ``_parse_toc_entry_text`` returns a
    ``TocGeneralItem`` decomposing the verbatim Node text into
    ``(number, title, page_number)``.
    """

    def test_capitolo_roman_entry(self) -> None:
        item = _parse_toc_entry_text("Capitolo I — Nozioni Generali ......................... 3 ")
        assert item is not None
        assert item.number == "Capitolo I"
        assert item.title == "Nozioni Generali"
        assert item.page_number == 3

    def test_decimal_depth_one_entry(self) -> None:
        item = _parse_toc_entry_text("1. Definizione di obbligazione ........................ 3 ")
        assert item is not None
        assert item.number == "1"
        assert item.title == "Definizione di obbligazione"
        assert item.page_number == 3

    def test_decimal_depth_two_entry(self) -> None:
        item = _parse_toc_entry_text("2.1 Il soggetto attivo ................................ 3 ")
        assert item is not None
        assert item.number == "2.1"
        assert item.title == "Il soggetto attivo"
        assert item.page_number == 3

    def test_glued_no_space_before_leader(self) -> None:
        item = _parse_toc_entry_text("2. Inadempimento....................................... 5 ")
        assert item is not None
        assert item.number == "2"
        assert item.title == "Inadempimento"
        assert item.page_number == 5

    def test_unparseable_returns_none(self) -> None:
        item = _parse_toc_entry_text("a body sentence without leader nor page number")
        assert item is None

    def test_section_letter_prefix(self) -> None:
        item = _parse_toc_entry_text("A. Premesse ............... 7")
        assert item is not None
        assert item.number == "A"
        assert item.title == "Premesse"
        assert item.page_number == 7

    def test_no_prefix_only_title(self) -> None:
        item = _parse_toc_entry_text("Bibliografia ............ 142")
        assert item is not None
        assert item.title == "Bibliografia"
        assert item.page_number == 142


class TestRefineReconstructionPopulatesTocItems:
    """``refine_reconstruction`` walks the tree and populates
    ``toc_items`` on TOC_GENERAL Nodes; non-TOC_GENERAL Nodes pass
    through unchanged.
    """

    @staticmethod
    def _make_node(
        node_id: str,
        category: SemanticCategory,
        text: str | None = None,
        children: tuple[Node, ...] = (),
        page_index: int = 1,
    ) -> Node:
        return Node(
            id=node_id,
            category=category,
            children=children,
            page_index=page_index,
            block_indices=(0,),
            text=text,
        )

    def test_populates_toc_items_on_toc_general_node(self) -> None:
        toc_node = self._make_node(
            "node_0001",
            SemanticCategory.TOC_GENERAL,
            text="Capitolo I — Nozioni Generali ......................... 3 ",
        )
        doc = Document(root=(toc_node,))
        ext = _extraction([], [])
        plugin = MaterialiStudioProfile()
        plugin._pending_warnings = []
        new_doc = plugin.refine_reconstruction(doc, ext, [])
        assert len(new_doc.root) == 1
        new_node = new_doc.root[0]
        assert new_node.toc_items is not None
        assert len(new_node.toc_items) == 1
        item = new_node.toc_items[0]
        assert item.number == "Capitolo I"
        assert item.title == "Nozioni Generali"
        assert item.page_number == 3

    def test_unparseable_toc_node_emits_warning(self) -> None:
        toc_node = self._make_node(
            "node_0001",
            SemanticCategory.TOC_GENERAL,
            text="some body text not a toc entry",
        )
        doc = Document(root=(toc_node,))
        ext = _extraction([], [])
        plugin = MaterialiStudioProfile()
        plugin._pending_warnings = []
        new_doc = plugin.refine_reconstruction(doc, ext, [])
        assert new_doc.root[0].toc_items is None
        assert any("toc_entry_unparseable_node_node_0001" in w for w in new_doc.warnings)

    def test_non_toc_node_unchanged(self) -> None:
        heading = self._make_node("node_0001", SemanticCategory.HEADING_1, text="Sommario ")
        doc = Document(root=(heading,))
        ext = _extraction([], [])
        plugin = MaterialiStudioProfile()
        plugin._pending_warnings = []
        new_doc = plugin.refine_reconstruction(doc, ext, [])
        new_node = new_doc.root[0]
        assert new_node.toc_items is None
        assert new_node.category is SemanticCategory.HEADING_1

    def test_nested_toc_under_heading_populated(self) -> None:
        toc_child = self._make_node(
            "node_0002",
            SemanticCategory.TOC_GENERAL,
            text="1. Definizione ............. 3 ",
        )
        heading = self._make_node(
            "node_0001",
            SemanticCategory.HEADING_1,
            text="Sommario ",
            children=(toc_child,),
        )
        doc = Document(root=(heading,))
        ext = _extraction([], [])
        plugin = MaterialiStudioProfile()
        plugin._pending_warnings = []
        new_doc = plugin.refine_reconstruction(doc, ext, [])
        new_heading = new_doc.root[0]
        new_toc = new_heading.children[0]
        assert new_toc.toc_items is not None
        assert new_toc.toc_items[0].number == "1"
        assert new_toc.toc_items[0].title == "Definizione"
        assert new_toc.toc_items[0].page_number == 3

    def test_warning_flush_preserves_document_warnings(self) -> None:
        toc_node = self._make_node(
            "node_0001",
            SemanticCategory.TOC_GENERAL,
            text="Capitolo I ............. 3 ",
        )
        doc = Document(root=(toc_node,), warnings=("preexisting_warning",))
        ext = _extraction([], [])
        plugin = MaterialiStudioProfile()
        plugin._pending_warnings = ["plugin:materiali_studio:test_warning"]
        new_doc = plugin.refine_reconstruction(doc, ext, [])
        assert "preexisting_warning" in new_doc.warnings
        assert "plugin:materiali_studio:test_warning" in new_doc.warnings


class TestReclassifyCascadeOrder:
    """The reclassify cascade must dispatch ToC predicates BEFORE the
    generic heading/body predicates so that ``Sommario`` and dotted-leader
    ToC entries are recognised even when they would also match a
    lower-priority predicate.
    """

    def test_sommario_word_dispatch_before_decimal(self) -> None:
        # Even if the text matched a decimal heading shape (it doesn't,
        # but the dispatch order is what we test), Sommario should fire
        # the ToC header branch.
        spans = [_span("Sommario", font="Calibri-Bold", size=18.0, flags=BOLD_FLAG)]
        view = _view(spans, block_index=3, page=1)
        plugin = MaterialiStudioProfile()
        plugin._color_mode = False
        plugin._pending_warnings = []
        verdict = plugin._reclassify(_verdict(block_index=3), view)
        assert verdict.category is SemanticCategory.HEADING_1
        assert verdict.reason == "materiali_studio_heading_1_toc_header"

    def test_toc_entry_dispatch_before_decimal(self) -> None:
        # "1. Definizione ........ 3" matches both _classify_toc_entry
        # (TOC_GENERAL) AND _classify_decimal_heading (HEADING_2). The
        # cascade must pick TOC_GENERAL.
        text = "1. Definizione di obbligazione ......................... 3 "
        spans = [_span(text, font="Calibri", size=11.04, flags=0)]
        view = _view(spans, block_index=5, page=1)
        plugin = MaterialiStudioProfile()
        plugin._color_mode = False
        plugin._pending_warnings = []
        verdict = plugin._reclassify(_verdict(block_index=5), view)
        assert verdict.category is SemanticCategory.TOC_GENERAL

    def test_capitolo_full_dispatch_before_color_aware(self) -> None:
        # In color_mode True, the color predicate would fire on the leading
        # span's color. We test that a Capitolo-style body chapter heading
        # still routes through _classify_capitolo_full FIRST when it's bold.
        text = "Capitolo I — Nozioni Generali "
        spans = [_span(text, font="Calibri-Bold", size=18.0, flags=BOLD_FLAG, color=0x1F3864)]
        view = _view(spans, block_index=18, page=2)
        plugin = MaterialiStudioProfile()
        plugin._color_mode = True
        plugin._pending_warnings = []
        verdict = plugin._reclassify(_verdict(block_index=18), view)
        assert verdict.category is SemanticCategory.HEADING_1
        assert verdict.reason == "materiali_studio_heading_1_capitolo_full"


class TestWarningTemplatesCoverage:
    """The new closed-vocabulary entries are declared in WARNING_TEMPLATES
    (consumed by the framework-derived validation registry in
    pipeline/src/scabopdf_pipeline/warning_framework.py)."""

    def test_toc_header_template_declared(self) -> None:
        templates = MaterialiStudioProfile.get_warning_templates()
        assert any("heading_1_toc_header" in t for t in templates)

    def test_capitolo_full_template_declared(self) -> None:
        templates = MaterialiStudioProfile.get_warning_templates()
        assert any("heading_1_capitolo_full" in t for t in templates)

    def test_toc_entry_template_declared(self) -> None:
        templates = MaterialiStudioProfile.get_warning_templates()
        assert any("toc_entry_dotted_leader" in t for t in templates)

    def test_toc_entry_unparseable_template_declared(self) -> None:
        templates = MaterialiStudioProfile.get_warning_templates()
        assert any("toc_entry_unparseable_node" in t for t in templates)
