"""Unit tests for the manuale_bic corpus plugin (Marrone — BIC accessible series)."""

from __future__ import annotations

import re

from scabopdf_pipeline.apparatus.types import ApparatusRef, ApparatusRefKind
from scabopdf_pipeline.classification.types import ClassifiedBlock
from scabopdf_pipeline.extraction.types import Block, ExtractionResult, Span
from scabopdf_pipeline.profiles.manuale_bic import (
    ANCHOR_MAX_SIZE,
    BODY_SIZE,
    COLOR_GREEN_H1,
    COLOR_INDIGO_H2,
    COLOR_MAROON_H3,
    COLOR_RED_NOTE,
    CROSSREF_FLAG_BITS,
    CROSSREF_SIZE,
    HEADING_1_SIZE,
    HEADING_2_SIZE,
    HEADING_3_SIZE,
    NOTE_MARKER_MAX_VALUE,
    NOTE_MARKER_SIZE,
    WARNING_PREFIX,
    ManualeBicProfile,
    _BlockView,
    _is_back_matter_heading,
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
    TypographicSignature,
)
from scabopdf_pipeline.reconstruction.types import Document, Node
from scabopdf_pipeline.schema.categories import SemanticCategory

# ---------------------------------------------------------------------------
# Flag constants (bit values exported in extraction.flags)

SUPERSCRIPT_FLAG = 0x01
ITALIC_FLAG = 0x02
BOLD_FLAG = 0x10
BOLD_ITALIC_FLAGS = BOLD_FLAG | ITALIC_FLAG


# ---------------------------------------------------------------------------
# Helpers


def _bic_signals(
    *,
    body_size: float = BODY_SIZE,
    body_dominance: float = 99.8,
    body_family: str = "Verdana",
    include_ilovepdf: bool = True,
    include_outline: bool = True,
    entries_count: int = 1562,
    width_pt: float = 595.4,
    height_pt: float = 841.9,
) -> ProfilingSignals:
    fonts = [FontDominance(family=body_family, size=body_size, dominance_percent=body_dominance)]
    producer = "iLovePDF / web service / 2022-10" if include_ilovepdf else "Acrobat Distiller 9.0.0"
    creator = "Microsoft Word 2016" if include_ilovepdf else "Adobe InDesign CS6"
    return ProfilingSignals(
        typographic_signature=TypographicSignature(fonts=fonts),
        apparatus_presence=ApparatusPresence(),
        page_geometry=ProfilePageGeometry(width_pt=width_pt, height_pt=height_pt),
        producer_creator=ProducerCreator(producer=producer, creator=creator),
        outline_structure=OutlineStructure(
            has_outline=include_outline,
            entries_count=entries_count if include_outline else 0,
        ),
    )


def _make_span(
    text: str,
    *,
    font: str = "Verdana",
    size: float = BODY_SIZE,
    flags: int = 0,
    page: int = 10,
    bbox: tuple[float, float, float, float] = (56.0, 100.0, 480.0, 115.0),
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
    page: int = 10,
    bbox: tuple[float, float, float, float] = (56.0, 100.0, 480.0, 600.0),
    span_range: tuple[int, int] = (0, 1),
    block_index: int = 0,
) -> Block:
    return Block(page=page, block_index=block_index, bbox=bbox, span_range=span_range)


def _make_view(
    spans: list[Span],
    *,
    page: int = 10,
    bbox: tuple[float, float, float, float] = (56.0, 100.0, 480.0, 600.0),
    block_index: int = 0,
) -> _BlockView:
    block = _make_block(page=page, bbox=bbox, span_range=(0, len(spans)), block_index=block_index)
    text = "".join(s.text for s in spans)
    return _BlockView(block_index=block_index, block=block, spans=tuple(spans), text=text)


def _empty_view() -> _BlockView:
    return _BlockView(block_index=0, block=_make_block(), spans=(), text="")


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
    page_index: int = 10,
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


def _classify_via_plugin(
    extraction: ExtractionResult,
    tier1: list[ClassifiedBlock],
) -> tuple[list[ClassifiedBlock], ManualeBicProfile]:
    plugin = ManualeBicProfile()
    refined = plugin.refine_classification(extraction, tier1)
    return refined, plugin


# ---------------------------------------------------------------------------
# Class attributes


def test_class_attributes() -> None:
    assert ManualeBicProfile.profile_id == "manuale_bic"
    assert ManualeBicProfile.editorial_family == "bic"
    assert ManualeBicProfile.genre == "manuale_accessibile"


# ---------------------------------------------------------------------------
# matches()


def test_matches_full_marrone_fingerprint_clears_threshold() -> None:
    """Verdana body + iLovePDF + outline scores at the top of the BIC range."""
    score = ManualeBicProfile.matches(_bic_signals())
    # 0.50 (body) + 0.15 (iLovePDF) + 0.10 (outline) = 0.75
    assert score == 0.75
    assert score >= 0.6


def test_matches_verdana_only_scores_05() -> None:
    """Verdana body dominance alone yields 0.50, below the dispatcher threshold."""
    score = ManualeBicProfile.matches(_bic_signals(include_ilovepdf=False, include_outline=False))
    assert score == 0.50
    assert score < 0.6


def test_matches_verdana_plus_ilovepdf_clears_threshold() -> None:
    score = ManualeBicProfile.matches(_bic_signals(include_outline=False))
    # 0.50 + 0.15 = 0.65 — clears threshold even without outline.
    assert score == 0.65
    assert score >= 0.6


def test_matches_verdana_plus_outline_clears_threshold() -> None:
    score = ManualeBicProfile.matches(_bic_signals(include_ilovepdf=False))
    # 0.50 + 0.10 = 0.60 — exactly at threshold.
    assert score == 0.60
    assert score >= 0.6


def test_matches_on_patriarca_like_signals_returns_zero() -> None:
    """A TimesNewRomanPSMT body short-circuits to 0.0."""
    score = ManualeBicProfile.matches(_bic_signals(body_family="TimesNewRomanPSMT"))
    assert score == 0.0


def test_matches_on_torrente_like_signals_returns_zero() -> None:
    """MScotchRoman body short-circuits to 0.0."""
    score = ManualeBicProfile.matches(_bic_signals(body_family="MScotchRoman"))
    assert score == 0.0


def test_matches_on_mandrioli_like_signals_returns_zero() -> None:
    """SimonciniGaramondStd body short-circuits to 0.0."""
    score = ManualeBicProfile.matches(_bic_signals(body_family="SimonciniGaramondStd"))
    assert score == 0.0


def test_matches_on_mosconi_like_signals_returns_zero() -> None:
    """TimesTenLTStd body short-circuits to 0.0."""
    score = ManualeBicProfile.matches(_bic_signals(body_family="TimesTenLTStd"))
    assert score == 0.0


def test_matches_verdana_below_dominance_floor_returns_zero() -> None:
    """A Verdana family below the 50% dominance floor does not credit the signal."""
    score = ManualeBicProfile.matches(_bic_signals(body_dominance=20.0))
    assert score == 0.0


def test_matches_verdana_with_small_size_drift_still_clears_threshold() -> None:
    """Verdana at 12.02pt (within 0.15pt tolerance) is admitted as body."""
    score = ManualeBicProfile.matches(_bic_signals(body_size=12.02))
    assert score >= 0.6


def test_matches_outline_below_threshold_does_not_credit() -> None:
    """A small embedded outline (under 100 entries) does not credit the signal."""
    score = ManualeBicProfile.matches(_bic_signals(include_ilovepdf=False, entries_count=42))
    # 0.50 + 0 outline = 0.50
    assert score == 0.50


# ---------------------------------------------------------------------------
# get_categories / get_post_processing / get_layouts_disabled


def test_get_categories_returns_closed_set() -> None:
    cats = ManualeBicProfile().get_categories()
    expected = {
        SemanticCategory.HEADING_1,
        SemanticCategory.HEADING_2,
        SemanticCategory.HEADING_3,
        SemanticCategory.BODY,
        SemanticCategory.NOTE,
        SemanticCategory.CROSS_REFERENCE,
        SemanticCategory.BOOK_PAGE_ANCHOR,
        SemanticCategory.ARTIFACT_FILIGREE,
        SemanticCategory.ARTIFACT_RUNNING_HEADER,
        SemanticCategory.ARTIFACT_FOOTER,
        SemanticCategory.ARTIFACT_STAMP,
        SemanticCategory.UNCLASSIFIED,
        SemanticCategory.EMPTY_PAGE,
    }
    assert cats == expected


def test_get_categories_size_is_thirteen() -> None:
    assert len(ManualeBicProfile().get_categories()) == 13


def test_get_post_processing_returns_dehyphenate_only() -> None:
    assert ManualeBicProfile().get_post_processing() == ["dehyphenate_with_log"]


def test_get_post_processing_does_not_declare_merge_or_ellipsis() -> None:
    steps = ManualeBicProfile().get_post_processing()
    assert "merge_cross_page_notes" not in steps
    assert "recompose_marginal_ellipsis" not in steps


def test_get_layouts_disabled_returns_empty_list() -> None:
    assert ManualeBicProfile().get_layouts_disabled() == []


# ---------------------------------------------------------------------------
# _BlockView


def test_block_view_primary_font() -> None:
    spans = [_make_span("hi", font="Verdana,Bold")]
    assert _make_view(spans).primary_font == "Verdana,Bold"


def test_block_view_primary_size() -> None:
    spans = [_make_span("hi", size=18.0)]
    assert _make_view(spans).primary_size == 18.0


def test_block_view_primary_color() -> None:
    spans = [_make_span("hi", color=COLOR_GREEN_H1)]
    assert _make_view(spans).primary_color == COLOR_GREEN_H1


def test_block_view_empty_spans_edge_case() -> None:
    view = _empty_view()
    assert view.primary_font == ""
    assert view.primary_size == 0.0
    assert view.primary_color == 0


# ---------------------------------------------------------------------------
# _NodeIdMinter


def test_node_id_minter_starts_at_given_counter() -> None:
    minter = _NodeIdMinter(start=42)
    assert minter.mint() == "node_0042"


def test_node_id_minter_monotonically_increasing() -> None:
    minter = _NodeIdMinter(start=42)
    a = minter.mint()
    b = minter.mint()
    c = minter.mint()
    assert (a, b, c) == ("node_0042", "node_0043", "node_0044")


def test_node_id_minter_ids_match_schema_pattern() -> None:
    pattern = re.compile(r"^node_\d+$")
    minter = _NodeIdMinter(start=0)
    for _ in range(5):
        assert pattern.match(minter.mint())


# ---------------------------------------------------------------------------
# _max_existing_node_counter


def test_max_existing_node_counter_empty_returns_minus_one() -> None:
    assert _max_existing_node_counter(()) == -1


def test_max_existing_node_counter_single_root() -> None:
    n = _node("node_0007", SemanticCategory.BODY, "x")
    assert _max_existing_node_counter((n,)) == 7


def test_max_existing_node_counter_walks_children() -> None:
    leaf = _node("node_0042", SemanticCategory.BODY, "leaf")
    root = _node("node_0001", SemanticCategory.HEADING_1, "root", children=(leaf,))
    assert _max_existing_node_counter((root,)) == 42


def test_max_existing_node_counter_ignores_malformed_ids() -> None:
    alien = _node("alien-id", SemanticCategory.BODY, "ignored")
    valid = _node("node_0050", SemanticCategory.BODY, "kept")
    assert _max_existing_node_counter((alien, valid)) == 50


# ---------------------------------------------------------------------------
# Predicate _is_heading_1


def test_is_heading_1_verdana_bolditalic_green_matches() -> None:
    spans = [
        _make_span(
            "Capitolo I",
            font="Verdana,BoldItalic",
            size=HEADING_1_SIZE,
            flags=BOLD_ITALIC_FLAGS,
            color=COLOR_GREEN_H1,
        )
    ]
    assert ManualeBicProfile._is_heading_1(_make_view(spans))


def test_is_heading_1_wrong_color_rejected() -> None:
    spans = [
        _make_span(
            "Capitolo I",
            font="Verdana,BoldItalic",
            size=HEADING_1_SIZE,
            flags=BOLD_ITALIC_FLAGS,
            color=COLOR_INDIGO_H2,
        )
    ]
    assert not ManualeBicProfile._is_heading_1(_make_view(spans))


def test_is_heading_1_wrong_family_rejected() -> None:
    spans = [
        _make_span(
            "Capitolo I",
            font="Arial,BoldItalic",
            size=HEADING_1_SIZE,
            flags=BOLD_ITALIC_FLAGS,
            color=COLOR_GREEN_H1,
        )
    ]
    assert not ManualeBicProfile._is_heading_1(_make_view(spans))


def test_is_heading_1_wrong_size_rejected() -> None:
    spans = [
        _make_span(
            "Capitolo I",
            font="Verdana,BoldItalic",
            size=BODY_SIZE,
            flags=BOLD_ITALIC_FLAGS,
            color=COLOR_GREEN_H1,
        )
    ]
    assert not ManualeBicProfile._is_heading_1(_make_view(spans))


def test_is_heading_1_empty_spans_rejected() -> None:
    assert not ManualeBicProfile._is_heading_1(_empty_view())


def test_is_heading_1_bold_only_no_italic_rejected() -> None:
    """Verdana,Bold (without italic) at 16.08pt #008000 is not HEADING_1."""
    spans = [
        _make_span(
            "Capitolo I",
            font="Verdana,Bold",
            size=HEADING_1_SIZE,
            flags=BOLD_FLAG,
            color=COLOR_GREEN_H1,
        )
    ]
    assert not ManualeBicProfile._is_heading_1(_make_view(spans))


# ---------------------------------------------------------------------------
# Predicate _is_heading_2_premesse


def test_is_heading_2_premesse_matches() -> None:
    spans = [
        _make_span(
            "Premesse",
            font="Verdana,Bold",
            size=HEADING_2_SIZE,
            flags=BOLD_FLAG,
            color=COLOR_INDIGO_H2,
        )
    ]
    assert ManualeBicProfile._is_heading_2_premesse(_make_view(spans))


def test_is_heading_2_premesse_wrong_color_rejected() -> None:
    spans = [
        _make_span(
            "Premesse",
            font="Verdana,Bold",
            size=HEADING_2_SIZE,
            flags=BOLD_FLAG,
            color=COLOR_GREEN_H1,
        )
    ]
    assert not ManualeBicProfile._is_heading_2_premesse(_make_view(spans))


def test_is_heading_2_premesse_text_mismatch_rejected() -> None:
    """An 18pt indigo Bold block whose text doesn't begin with Premesse is rejected."""
    spans = [
        _make_span(
            "Conclusioni",
            font="Verdana,Bold",
            size=HEADING_2_SIZE,
            flags=BOLD_FLAG,
            color=COLOR_INDIGO_H2,
        )
    ]
    assert not ManualeBicProfile._is_heading_2_premesse(_make_view(spans))


def test_is_heading_2_premesse_regular_weight_rejected() -> None:
    """A Verdana regular (no Bold suffix) span at 18pt is not HEADING_2."""
    spans = [
        _make_span(
            "Premesse",
            font="Verdana",
            size=HEADING_2_SIZE,
            flags=0,
            color=COLOR_INDIGO_H2,
        )
    ]
    assert not ManualeBicProfile._is_heading_2_premesse(_make_view(spans))


def test_is_heading_2_premesse_empty_spans_rejected() -> None:
    assert not ManualeBicProfile._is_heading_2_premesse(_empty_view())


# ---------------------------------------------------------------------------
# Predicate _is_heading_3


def test_is_heading_3_bold_matches() -> None:
    spans = [
        _make_span(
            "§ 1 Il diritto",
            font="Verdana,Bold",
            size=HEADING_3_SIZE,
            flags=BOLD_FLAG,
            color=COLOR_MAROON_H3,
        )
    ]
    assert ManualeBicProfile._is_heading_3(_make_view(spans))


def test_is_heading_3_bolditalic_matches() -> None:
    spans = [
        _make_span(
            "§ 5 Le obbligazioni",
            font="Verdana,BoldItalic",
            size=HEADING_3_SIZE,
            flags=BOLD_ITALIC_FLAGS,
            color=COLOR_MAROON_H3,
        )
    ]
    assert ManualeBicProfile._is_heading_3(_make_view(spans))


def test_is_heading_3_wrong_color_rejected() -> None:
    spans = [
        _make_span(
            "§ 1 Il diritto",
            font="Verdana,Bold",
            size=HEADING_3_SIZE,
            flags=BOLD_FLAG,
            color=COLOR_GREEN_H1,
        )
    ]
    assert not ManualeBicProfile._is_heading_3(_make_view(spans))


def test_is_heading_3_wrong_size_rejected() -> None:
    spans = [
        _make_span(
            "§ 1 Il diritto",
            font="Verdana,Bold",
            size=BODY_SIZE,
            flags=BOLD_FLAG,
            color=COLOR_MAROON_H3,
        )
    ]
    assert not ManualeBicProfile._is_heading_3(_make_view(spans))


def test_is_heading_3_empty_spans_rejected() -> None:
    assert not ManualeBicProfile._is_heading_3(_empty_view())


# ---------------------------------------------------------------------------
# Predicate _is_body


def test_is_body_leading_verdana_body_matches() -> None:
    spans = [_make_span("Il diritto è...", font="Verdana", size=BODY_SIZE)]
    assert ManualeBicProfile._is_body(_make_view(spans))


def test_is_body_with_leading_superscript_still_matches() -> None:
    """A block whose first span is a 10.56pt superscript and rest is body is still BODY."""
    spans = [
        _make_span(
            "12",
            font="Verdana,Bold",
            size=CROSSREF_SIZE,
            flags=CROSSREF_FLAG_BITS,
            color=0,
        ),
        _make_span(
            ". Le persone fisiche",
            font="Verdana",
            size=BODY_SIZE,
            flags=0,
            color=0,
            span_index=1,
        ),
    ]
    assert ManualeBicProfile._is_body(_make_view(spans))


def test_is_body_no_verdana_rejected() -> None:
    spans = [_make_span("Times text", font="TimesNewRoman", size=BODY_SIZE)]
    assert not ManualeBicProfile._is_body(_make_view(spans))


def test_is_body_empty_spans_rejected() -> None:
    assert not ManualeBicProfile._is_body(_empty_view())


# ---------------------------------------------------------------------------
# Predicate _volume_marker_kind


def test_volume_marker_kind_primo_volume_frontispiece() -> None:
    view = _make_view([_make_span("Primo volume da pagina 1 a pagina 110.")])
    assert ManualeBicProfile._volume_marker_kind(view) == "frontispiece"


def test_volume_marker_kind_quinto_volume_frontispiece() -> None:
    view = _make_view([_make_span("Quinto volume da pagina 537 a pagina 684.")])
    assert ManualeBicProfile._volume_marker_kind(view) == "frontispiece"


def test_volume_marker_kind_fine_del_primo_volume_end() -> None:
    view = _make_view([_make_span("Fine del primo volume")])
    assert ManualeBicProfile._volume_marker_kind(view) == "end"


def test_volume_marker_kind_fine_del_quarto_volume_end() -> None:
    view = _make_view([_make_span("Testo del paragrafo. Fine del quarto volume.")])
    assert ManualeBicProfile._volume_marker_kind(view) == "end"


def test_volume_marker_kind_body_text_returns_none() -> None:
    view = _make_view([_make_span("Un paragrafo qualsiasi senza marker.")])
    assert ManualeBicProfile._volume_marker_kind(view) is None


# ---------------------------------------------------------------------------
# Predicate _is_note_marker_span


def test_is_note_marker_span_matches() -> None:
    span = _make_span(
        "Note",
        font="Verdana,Bold",
        size=NOTE_MARKER_SIZE,
        flags=BOLD_FLAG,
        color=COLOR_RED_NOTE,
    )
    assert ManualeBicProfile._is_note_marker_span(span)


def test_is_note_marker_span_with_trailing_whitespace_matches() -> None:
    span = _make_span(
        "Note  ",
        font="Verdana,Bold",
        size=NOTE_MARKER_SIZE,
        flags=BOLD_FLAG,
        color=COLOR_RED_NOTE,
    )
    assert ManualeBicProfile._is_note_marker_span(span)


def test_is_note_marker_span_wrong_color_rejected() -> None:
    span = _make_span(
        "Note",
        font="Verdana,Bold",
        size=NOTE_MARKER_SIZE,
        flags=BOLD_FLAG,
        color=0x000000,
    )
    assert not ManualeBicProfile._is_note_marker_span(span)


def test_is_note_marker_span_wrong_size_rejected() -> None:
    span = _make_span(
        "Note",
        font="Verdana,Bold",
        size=18.0,
        flags=BOLD_FLAG,
        color=COLOR_RED_NOTE,
    )
    assert not ManualeBicProfile._is_note_marker_span(span)


def test_is_note_marker_span_regular_weight_rejected() -> None:
    span = _make_span(
        "Note",
        font="Verdana",
        size=NOTE_MARKER_SIZE,
        flags=0,
        color=COLOR_RED_NOTE,
    )
    assert not ManualeBicProfile._is_note_marker_span(span)


# ---------------------------------------------------------------------------
# Predicate _is_crossref_span


def test_is_crossref_span_matches() -> None:
    span = _make_span(
        "12",
        font="Verdana,Bold",
        size=CROSSREF_SIZE,
        flags=CROSSREF_FLAG_BITS,
    )
    assert ManualeBicProfile._is_crossref_span(span)


def test_is_crossref_span_non_superscript_rejected() -> None:
    """A 10.56pt Verdana,Bold span without the SUPERSCRIPT bit is rejected."""
    span = _make_span(
        "12",
        font="Verdana,Bold",
        size=CROSSREF_SIZE,
        flags=BOLD_FLAG,  # no superscript bit
    )
    assert not ManualeBicProfile._is_crossref_span(span)


def test_is_crossref_span_whitespace_rejected() -> None:
    span = _make_span(
        " 12 ",
        font="Verdana,Bold",
        size=CROSSREF_SIZE,
        flags=CROSSREF_FLAG_BITS,
    )
    # Strict numeric pattern matches the stripped text "12" → accepted.
    # Plugin: _is_crossref_span strips before matching, so whitespace is allowed.
    assert ManualeBicProfile._is_crossref_span(span)


def test_is_crossref_span_non_numeric_rejected() -> None:
    span = _make_span(
        "abc",
        font="Verdana,Bold",
        size=CROSSREF_SIZE,
        flags=CROSSREF_FLAG_BITS,
    )
    assert not ManualeBicProfile._is_crossref_span(span)


def test_is_crossref_span_wrong_size_rejected() -> None:
    span = _make_span(
        "12",
        font="Verdana,Bold",
        size=BODY_SIZE,
        flags=CROSSREF_FLAG_BITS,
    )
    assert not ManualeBicProfile._is_crossref_span(span)


def test_is_crossref_span_extra_flag_bits_rejected() -> None:
    """A superscript bold span with extra flag bits beyond 17 is rejected."""
    span = _make_span(
        "12",
        font="Verdana,Bold",
        size=CROSSREF_SIZE,
        flags=CROSSREF_FLAG_BITS | ITALIC_FLAG,
    )
    assert not ManualeBicProfile._is_crossref_span(span)


# ---------------------------------------------------------------------------
# refine_classification


def test_refine_classification_sentinel_passes_through() -> None:
    sentinel = ClassifiedBlock(
        block_index=-1,
        category=SemanticCategory.EMPTY_PAGE,
        subcategory="42",
        reason="empty_page",
    )
    refined, _ = _classify_via_plugin(_make_extraction([], []), [sentinel])
    assert refined[0] is sentinel


def test_refine_classification_empty_spans_passes_through() -> None:
    blocks = [_make_block(span_range=(0, 0))]
    ext = _make_extraction([], blocks)
    refined, _ = _classify_via_plugin(ext, [_verdict(0, reason="custom_reason")])
    assert refined[0].reason == "custom_reason"
    assert refined[0].category is SemanticCategory.UNCLASSIFIED


def test_refine_classification_volume_frontispiece_becomes_stamp() -> None:
    spans = [
        _make_span(
            "Matteo Marrone ... Primo volume da pagina 1 a pagina 110 del testo originale.",
            font="Verdana,Bold",
            size=24.0,
        )
    ]
    blocks = [_make_block(span_range=(0, 1), page=0)]
    ext = _make_extraction(spans, blocks)
    refined, plugin = _classify_via_plugin(ext, [_verdict(0)])
    assert refined[0].category is SemanticCategory.ARTIFACT_STAMP
    assert any(
        w.startswith(f"{WARNING_PREFIX}:volume_frontispiece_block_0_page_0_marker_primo")
        for w in plugin._pending_warnings
    )


def test_refine_classification_end_of_volume_keeps_category_warns() -> None:
    """The end-of-volume marker emits a warning only; classification untouched."""
    spans = [
        _make_span(
            "Testo finale del paragrafo. Fine del primo volume",
            font="Verdana",
            size=BODY_SIZE,
        )
    ]
    blocks = [_make_block(span_range=(0, 1), page=106)]
    ext = _make_extraction(spans, blocks)
    refined, plugin = _classify_via_plugin(ext, [_verdict(0)])
    # Verdict stays UNCLASSIFIED (the end-of-volume hook does not reclassify)
    assert refined[0].category is SemanticCategory.UNCLASSIFIED
    assert any(
        w.startswith(f"{WARNING_PREFIX}:volume_end_block_0_page_106_marker_primo")
        for w in plugin._pending_warnings
    )


def test_refine_classification_heading_1_on_unclassified() -> None:
    spans = [
        _make_span(
            "Capitolo I",
            font="Verdana,BoldItalic",
            size=HEADING_1_SIZE,
            flags=BOLD_ITALIC_FLAGS,
            color=COLOR_GREEN_H1,
        )
    ]
    blocks = [_make_block(span_range=(0, 1))]
    ext = _make_extraction(spans, blocks)
    refined, _ = _classify_via_plugin(ext, [_verdict(0)])
    assert refined[0].category is SemanticCategory.HEADING_1
    assert refined[0].reason == "bic_heading_1_chapter"


def test_refine_classification_heading_1_rescued_from_running_header() -> None:
    """A green 16.08pt block tier 1 mis-classified as ARTIFACT_RUNNING_HEADER is rescued."""
    spans = [
        _make_span(
            "Capitolo II",
            font="Verdana,BoldItalic",
            size=HEADING_1_SIZE,
            flags=BOLD_ITALIC_FLAGS,
            color=COLOR_GREEN_H1,
        )
    ]
    blocks = [_make_block(span_range=(0, 1))]
    ext = _make_extraction(spans, blocks)
    refined, _ = _classify_via_plugin(
        ext,
        [_verdict(0, category=SemanticCategory.ARTIFACT_RUNNING_HEADER, reason="header_zone")],
    )
    assert refined[0].category is SemanticCategory.HEADING_1


def test_refine_classification_premesse_on_unclassified() -> None:
    spans = [
        _make_span(
            "Premesse",
            font="Verdana,Bold",
            size=HEADING_2_SIZE,
            flags=BOLD_FLAG,
            color=COLOR_INDIGO_H2,
        )
    ]
    blocks = [_make_block(span_range=(0, 1), page=7)]
    ext = _make_extraction(spans, blocks)
    refined, _ = _classify_via_plugin(ext, [_verdict(0)])
    assert refined[0].category is SemanticCategory.HEADING_2
    assert refined[0].reason == "bic_heading_2_premesse"


def test_refine_classification_second_premesse_warns_duplicate() -> None:
    """Two Premesse blocks on the same page produce a duplicate warning on the second."""
    span_a = _make_span(
        "Premesse",
        font="Verdana,Bold",
        size=HEADING_2_SIZE,
        flags=BOLD_FLAG,
        color=COLOR_INDIGO_H2,
        page=7,
        block_index=0,
    )
    span_b = _make_span(
        "Premesse",
        font="Verdana,Bold",
        size=HEADING_2_SIZE,
        flags=BOLD_FLAG,
        color=COLOR_INDIGO_H2,
        page=7,
        block_index=1,
        span_index=0,
    )
    blocks = [
        _make_block(span_range=(0, 1), page=7, block_index=0),
        _make_block(span_range=(1, 2), page=7, block_index=1),
    ]
    ext = _make_extraction([span_a, span_b], blocks)
    refined, plugin = _classify_via_plugin(ext, [_verdict(0), _verdict(1)])
    assert refined[0].category is SemanticCategory.HEADING_2
    assert refined[1].category is SemanticCategory.HEADING_2
    assert any(
        w == f"{WARNING_PREFIX}:premesse_duplicate_page_7_block_1" for w in plugin._pending_warnings
    )


def test_refine_classification_paragrafo_heading_3() -> None:
    spans = [
        _make_span(
            "§ 1 L'ordinamento giuridico romano",
            font="Verdana,Bold",
            size=HEADING_3_SIZE,
            flags=BOLD_FLAG,
            color=COLOR_MAROON_H3,
        )
    ]
    blocks = [_make_block(span_range=(0, 1))]
    ext = _make_extraction(spans, blocks)
    refined, _ = _classify_via_plugin(ext, [_verdict(0)])
    assert refined[0].category is SemanticCategory.HEADING_3
    assert refined[0].reason == "bic_heading_3_paragrafo"


def test_refine_classification_abbreviazioni_heading_3() -> None:
    spans = [
        _make_span(
            "Abbreviazioni principali",
            font="Verdana,Bold",
            size=HEADING_3_SIZE,
            flags=BOLD_FLAG,
            color=COLOR_MAROON_H3,
        )
    ]
    blocks = [_make_block(span_range=(0, 1), page=5)]
    ext = _make_extraction(spans, blocks)
    refined, _ = _classify_via_plugin(ext, [_verdict(0)])
    assert refined[0].category is SemanticCategory.HEADING_3
    assert refined[0].reason == "bic_heading_3_abbreviazioni"


def test_refine_classification_second_abbreviazioni_warns_duplicate() -> None:
    span_a = _make_span(
        "Abbreviazioni principali",
        font="Verdana,Bold",
        size=HEADING_3_SIZE,
        flags=BOLD_FLAG,
        color=COLOR_MAROON_H3,
        page=110,
        block_index=0,
    )
    span_b = _make_span(
        "Abbreviazioni principali",
        font="Verdana,Bold",
        size=HEADING_3_SIZE,
        flags=BOLD_FLAG,
        color=COLOR_MAROON_H3,
        page=110,
        block_index=1,
    )
    blocks = [
        _make_block(span_range=(0, 1), page=110, block_index=0),
        _make_block(span_range=(1, 2), page=110, block_index=1),
    ]
    ext = _make_extraction([span_a, span_b], blocks)
    _, plugin = _classify_via_plugin(ext, [_verdict(0), _verdict(1)])
    assert any(
        w == f"{WARNING_PREFIX}:abbreviazioni_duplicate_page_110_block_1"
        for w in plugin._pending_warnings
    )


def test_refine_classification_heading_3_signature_unmatched_text_warns() -> None:
    """A 13.92pt maroon block with text matching neither pattern stays UNCLASSIFIED + warning."""
    spans = [
        _make_span(
            "Testo strano sconosciuto",
            font="Verdana,Bold",
            size=HEADING_3_SIZE,
            flags=BOLD_FLAG,
            color=COLOR_MAROON_H3,
        )
    ]
    blocks = [_make_block(span_range=(0, 1), page=50)]
    ext = _make_extraction(spans, blocks)
    refined, plugin = _classify_via_plugin(ext, [_verdict(0)])
    assert refined[0].category is SemanticCategory.UNCLASSIFIED
    assert any(
        w.startswith(f"{WARNING_PREFIX}:heading_pattern_unmatched_block_0_page_50")
        for w in plugin._pending_warnings
    )


def test_refine_classification_body_promotion() -> None:
    spans = [_make_span("Il diritto romano è la radice ...", font="Verdana", size=BODY_SIZE)]
    blocks = [_make_block(span_range=(0, 1))]
    ext = _make_extraction(spans, blocks)
    refined, _ = _classify_via_plugin(ext, [_verdict(0)])
    assert refined[0].category is SemanticCategory.BODY
    assert refined[0].reason == "bic_body"


def test_refine_classification_body_with_leading_superscript_still_body() -> None:
    """A body block whose first span is a 10.56pt superscript still gets BODY."""
    spans = [
        _make_span(
            "12",
            font="Verdana,Bold",
            size=CROSSREF_SIZE,
            flags=CROSSREF_FLAG_BITS,
        ),
        _make_span(
            ". Le persone fisiche sono ...",
            font="Verdana",
            size=BODY_SIZE,
            span_index=1,
        ),
    ]
    blocks = [_make_block(span_range=(0, 2))]
    ext = _make_extraction(spans, blocks)
    refined, _ = _classify_via_plugin(ext, [_verdict(0)])
    assert refined[0].category is SemanticCategory.BODY


def test_refine_classification_preserves_tier1_filigree_verdict() -> None:
    """A tier 1 ARTIFACT_FILIGREE verdict on an unrelated block stays unchanged."""
    spans = [_make_span("watermark", font="Verdana", size=8.0)]
    blocks = [_make_block(span_range=(0, 1))]
    ext = _make_extraction(spans, blocks)
    refined, _ = _classify_via_plugin(
        ext, [_verdict(0, category=SemanticCategory.ARTIFACT_FILIGREE, reason="filigree")]
    )
    assert refined[0].category is SemanticCategory.ARTIFACT_FILIGREE


def test_refine_classification_unrecognised_block_stays_unclassified() -> None:
    """A block matching no plugin predicate stays UNCLASSIFIED."""
    spans = [_make_span("strange", font="UnknownFont", size=5.0)]
    blocks = [_make_block(span_range=(0, 1))]
    ext = _make_extraction(spans, blocks)
    refined, _ = _classify_via_plugin(ext, [_verdict(0)])
    assert refined[0].category is SemanticCategory.UNCLASSIFIED


# ---------------------------------------------------------------------------
# refine_reconstruction — body+note splitter


def _reconstruct(
    document: Document,
    extraction: ExtractionResult,
    *,
    plugin: ManualeBicProfile | None = None,
) -> tuple[Document, ManualeBicProfile]:
    p = plugin or ManualeBicProfile()
    return p.refine_reconstruction(document, extraction, []), p


def test_refine_reconstruction_empty_document_passes_through() -> None:
    ext = _make_extraction([], [])
    new_doc, _ = _reconstruct(Document(root=()), ext)
    assert new_doc.root == ()
    assert new_doc.transformations == ()


def test_refine_reconstruction_body_without_note_marker_unchanged() -> None:
    spans = [_make_span("Paragrafo senza note.", font="Verdana", size=BODY_SIZE)]
    blocks = [_make_block(span_range=(0, 1), block_index=0)]
    ext = _make_extraction(spans, blocks)
    parent = _node(
        "node_0001",
        SemanticCategory.HEADING_3,
        "§ 1",
        children=(
            _node("node_0002", SemanticCategory.BODY, "Paragrafo senza note.", block_indices=(0,)),
        ),
    )
    new_doc, _ = _reconstruct(Document(root=(parent,)), ext)
    assert len(new_doc.root) == 1
    assert len(new_doc.root[0].children) == 1
    assert new_doc.root[0].children[0].category is SemanticCategory.BODY


def test_refine_reconstruction_body_with_one_note_mints_one_note() -> None:
    body_text = "Il diritto è un sistema.Note1. Una nota di chiarimento."
    spans = [
        _make_span("Il diritto è un sistema.", font="Verdana", size=BODY_SIZE, span_index=0),
        _make_span(
            "Note",
            font="Verdana,Bold",
            size=NOTE_MARKER_SIZE,
            flags=BOLD_FLAG,
            color=COLOR_RED_NOTE,
            line_index=1,
            span_index=1,
        ),
        _make_span(
            "1. Una nota di chiarimento.",
            font="Verdana",
            size=BODY_SIZE,
            line_index=2,
            span_index=2,
        ),
    ]
    blocks = [_make_block(span_range=(0, 3), block_index=0)]
    ext = _make_extraction(spans, blocks)
    parent = _node(
        "node_0001",
        SemanticCategory.HEADING_3,
        "§ 1",
        children=(
            _node(
                "node_0002",
                SemanticCategory.BODY,
                body_text,
                block_indices=(0,),
            ),
        ),
    )
    new_doc, _ = _reconstruct(Document(root=(parent,)), ext)
    children = new_doc.root[0].children
    assert len(children) == 2
    assert children[0].category is SemanticCategory.BODY
    assert children[1].category is SemanticCategory.NOTE
    assert len(new_doc.transformations) == 1


def test_refine_reconstruction_body_with_three_notes_mints_three() -> None:
    body_text = "Body.Note1. nota uno.2. nota due.3. nota tre."
    spans = [
        _make_span("Body.", font="Verdana", size=BODY_SIZE, span_index=0),
        _make_span(
            "Note",
            font="Verdana,Bold",
            size=NOTE_MARKER_SIZE,
            flags=BOLD_FLAG,
            color=COLOR_RED_NOTE,
            line_index=1,
            span_index=1,
        ),
        _make_span("1. nota uno.", font="Verdana", size=BODY_SIZE, line_index=2, span_index=0),
        _make_span("2. nota due.", font="Verdana", size=BODY_SIZE, line_index=3, span_index=0),
        _make_span("3. nota tre.", font="Verdana", size=BODY_SIZE, line_index=4, span_index=0),
    ]
    blocks = [_make_block(span_range=(0, 5), block_index=0)]
    ext = _make_extraction(spans, blocks)
    parent = _node(
        "node_0001",
        SemanticCategory.HEADING_3,
        "§ 1",
        children=(_node("node_0002", SemanticCategory.BODY, body_text, block_indices=(0,)),),
    )
    new_doc, _ = _reconstruct(Document(root=(parent,)), ext)
    children = new_doc.root[0].children
    notes = [c for c in children if c.category is SemanticCategory.NOTE]
    assert len(notes) == 3


def test_refine_reconstruction_multi_block_body_marker_in_second_block() -> None:
    """When the Note marker sits inside the SECOND block of a multi-block BODY."""
    spans = [
        _make_span(
            "Prima parte del corpo.", font="Verdana", size=BODY_SIZE, block_index=0, span_index=0
        ),
        _make_span(
            "Seconda parte del corpo.", font="Verdana", size=BODY_SIZE, block_index=1, span_index=0
        ),
        _make_span(
            "Note",
            font="Verdana,Bold",
            size=NOTE_MARKER_SIZE,
            flags=BOLD_FLAG,
            color=COLOR_RED_NOTE,
            block_index=1,
            line_index=1,
            span_index=1,
        ),
        _make_span(
            "1. nota numero uno.",
            font="Verdana",
            size=BODY_SIZE,
            block_index=1,
            line_index=2,
            span_index=2,
        ),
    ]
    blocks = [
        _make_block(span_range=(0, 1), block_index=0),
        _make_block(span_range=(1, 4), block_index=1),
    ]
    ext = _make_extraction(spans, blocks)
    body_text = "Prima parte del corpo. Seconda parte del corpo.Note1. nota numero uno."
    parent = _node(
        "node_0001",
        SemanticCategory.HEADING_3,
        "§ 1",
        children=(
            _node(
                "node_0002",
                SemanticCategory.BODY,
                body_text,
                block_indices=(0, 1),
            ),
        ),
    )
    new_doc, _ = _reconstruct(Document(root=(parent,)), ext)
    children = new_doc.root[0].children
    notes = [c for c in children if c.category is SemanticCategory.NOTE]
    assert len(notes) == 1


def test_refine_reconstruction_minted_note_text_starts_with_marker() -> None:
    body_text = "Body.Note1. nota."
    spans = [
        _make_span("Body.", font="Verdana", size=BODY_SIZE, span_index=0),
        _make_span(
            "Note",
            font="Verdana,Bold",
            size=NOTE_MARKER_SIZE,
            flags=BOLD_FLAG,
            color=COLOR_RED_NOTE,
            line_index=1,
            span_index=1,
        ),
        _make_span("1. nota.", font="Verdana", size=BODY_SIZE, line_index=2, span_index=2),
    ]
    blocks = [_make_block(span_range=(0, 3), block_index=0)]
    ext = _make_extraction(spans, blocks)
    parent = _node(
        "node_0001",
        SemanticCategory.HEADING_3,
        "§ 1",
        children=(_node("node_0002", SemanticCategory.BODY, body_text, block_indices=(0,)),),
    )
    new_doc, _ = _reconstruct(Document(root=(parent,)), ext)
    notes = [c for c in new_doc.root[0].children if c.category is SemanticCategory.NOTE]
    assert len(notes) == 1
    assert notes[0].text is not None
    # The note text should start with "1. " for the apparatus resolver's NOTE_MARKER_REGEX
    assert re.match(r"^\d+\.\s", notes[0].text)


def test_refine_reconstruction_transformation_split_into_populated() -> None:
    body_text = "Body.Note1. nota."
    spans = [
        _make_span("Body.", font="Verdana", size=BODY_SIZE, span_index=0),
        _make_span(
            "Note",
            font="Verdana,Bold",
            size=NOTE_MARKER_SIZE,
            flags=BOLD_FLAG,
            color=COLOR_RED_NOTE,
            line_index=1,
            span_index=1,
        ),
        _make_span("1. nota.", font="Verdana", size=BODY_SIZE, line_index=2, span_index=2),
    ]
    blocks = [_make_block(span_range=(0, 3), block_index=0)]
    ext = _make_extraction(spans, blocks)
    parent = _node(
        "node_0001",
        SemanticCategory.HEADING_3,
        "§ 1",
        children=(_node("node_0002", SemanticCategory.BODY, body_text, block_indices=(0,)),),
    )
    new_doc, _ = _reconstruct(Document(root=(parent,)), ext)
    assert len(new_doc.transformations) == 1
    t = new_doc.transformations[0]
    assert t.split_into is not None
    assert len(t.split_into) == 1
    notes = [c for c in new_doc.root[0].children if c.category is SemanticCategory.NOTE]
    assert t.split_into[0] == notes[0].id


def test_refine_reconstruction_transformation_step_id() -> None:
    body_text = "Body.Note1. nota."
    spans = [
        _make_span("Body.", font="Verdana", size=BODY_SIZE, span_index=0),
        _make_span(
            "Note",
            font="Verdana,Bold",
            size=NOTE_MARKER_SIZE,
            flags=BOLD_FLAG,
            color=COLOR_RED_NOTE,
            line_index=1,
            span_index=1,
        ),
        _make_span("1. nota.", font="Verdana", size=BODY_SIZE, line_index=2, span_index=2),
    ]
    blocks = [_make_block(span_range=(0, 3), block_index=0)]
    ext = _make_extraction(spans, blocks)
    parent = _node(
        "node_0001",
        SemanticCategory.HEADING_3,
        "§ 1",
        children=(_node("node_0002", SemanticCategory.BODY, body_text, block_indices=(0,)),),
    )
    new_doc, _ = _reconstruct(Document(root=(parent,)), ext)
    assert new_doc.transformations[0].step_id == "bic_body_note_splitter"


def test_refine_reconstruction_emits_per_mint_warning() -> None:
    body_text = "Body.Note1. nota."
    spans = [
        _make_span("Body.", font="Verdana", size=BODY_SIZE, span_index=0, page=42),
        _make_span(
            "Note",
            font="Verdana,Bold",
            size=NOTE_MARKER_SIZE,
            flags=BOLD_FLAG,
            color=COLOR_RED_NOTE,
            line_index=1,
            span_index=1,
            page=42,
        ),
        _make_span(
            "1. nota.",
            font="Verdana",
            size=BODY_SIZE,
            line_index=2,
            span_index=2,
            page=42,
        ),
    ]
    blocks = [_make_block(span_range=(0, 3), block_index=0, page=42)]
    ext = _make_extraction(spans, blocks)
    parent = _node(
        "node_0001",
        SemanticCategory.HEADING_3,
        "§ 1",
        page_index=42,
        children=(
            _node(
                "node_0002",
                SemanticCategory.BODY,
                body_text,
                page_index=42,
                block_indices=(0,),
            ),
        ),
    )
    new_doc, _ = _reconstruct(Document(root=(parent,)), ext)
    notes = [c for c in new_doc.root[0].children if c.category is SemanticCategory.NOTE]
    note_id = notes[0].id
    expected = f"{WARNING_PREFIX}:note_section_split_minted_node_{note_id}_page_42_marker_1"
    assert expected in new_doc.warnings


def test_refine_reconstruction_body_text_none_unchanged() -> None:
    parent = _node(
        "node_0001",
        SemanticCategory.HEADING_3,
        "§ 1",
        children=(_node("node_0002", SemanticCategory.BODY, None, block_indices=(0,)),),
    )
    ext = _make_extraction([], [])
    new_doc, _ = _reconstruct(Document(root=(parent,)), ext)
    children = new_doc.root[0].children
    assert len(children) == 1
    assert children[0].text is None


# ---------------------------------------------------------------------------
# refine_reconstruction — cross-reference minting


def test_refine_reconstruction_body_without_crossref_unchanged() -> None:
    spans = [_make_span("Paragrafo senza riferimenti.", font="Verdana", size=BODY_SIZE)]
    blocks = [_make_block(span_range=(0, 1), block_index=0)]
    ext = _make_extraction(spans, blocks)
    parent = _node(
        "node_0001",
        SemanticCategory.HEADING_3,
        "§ 1",
        children=(
            _node(
                "node_0002",
                SemanticCategory.BODY,
                "Paragrafo senza riferimenti.",
                block_indices=(0,),
            ),
        ),
    )
    new_doc, _ = _reconstruct(Document(root=(parent,)), ext)
    children = new_doc.root[0].children
    assert all(c.category is not SemanticCategory.CROSS_REFERENCE for c in children)


def test_refine_reconstruction_body_with_one_crossref_mints_one_sibling() -> None:
    spans = [
        _make_span("Vedi nota ", font="Verdana", size=BODY_SIZE, span_index=0),
        _make_span(
            "12",
            font="Verdana,Bold",
            size=CROSSREF_SIZE,
            flags=CROSSREF_FLAG_BITS,
            span_index=1,
        ),
        _make_span(" del paragrafo.", font="Verdana", size=BODY_SIZE, span_index=2),
    ]
    blocks = [_make_block(span_range=(0, 3), block_index=0)]
    ext = _make_extraction(spans, blocks)
    parent = _node(
        "node_0001",
        SemanticCategory.HEADING_3,
        "§ 1",
        children=(
            _node(
                "node_0002",
                SemanticCategory.BODY,
                "Vedi nota 12 del paragrafo.",
                block_indices=(0,),
            ),
        ),
    )
    new_doc, _ = _reconstruct(Document(root=(parent,)), ext)
    children = new_doc.root[0].children
    crossrefs = [c for c in children if c.category is SemanticCategory.CROSS_REFERENCE]
    assert len(crossrefs) == 1
    assert crossrefs[0].text == "12"


def test_refine_reconstruction_body_with_three_crossrefs_mints_three() -> None:
    spans = [
        _make_span("Vedi ", font="Verdana", size=BODY_SIZE, span_index=0),
        _make_span(
            "1", font="Verdana,Bold", size=CROSSREF_SIZE, flags=CROSSREF_FLAG_BITS, span_index=1
        ),
        _make_span(" e ", font="Verdana", size=BODY_SIZE, span_index=2),
        _make_span(
            "2", font="Verdana,Bold", size=CROSSREF_SIZE, flags=CROSSREF_FLAG_BITS, span_index=3
        ),
        _make_span(" e ", font="Verdana", size=BODY_SIZE, span_index=4),
        _make_span(
            "3", font="Verdana,Bold", size=CROSSREF_SIZE, flags=CROSSREF_FLAG_BITS, span_index=5
        ),
    ]
    blocks = [_make_block(span_range=(0, 6), block_index=0)]
    ext = _make_extraction(spans, blocks)
    parent = _node(
        "node_0001",
        SemanticCategory.HEADING_3,
        "§ 1",
        children=(
            _node("node_0002", SemanticCategory.BODY, "Vedi 1 e 2 e 3.", block_indices=(0,)),
        ),
    )
    new_doc, _ = _reconstruct(Document(root=(parent,)), ext)
    crossrefs = [
        c for c in new_doc.root[0].children if c.category is SemanticCategory.CROSS_REFERENCE
    ]
    assert len(crossrefs) == 3
    assert {c.text for c in crossrefs} == {"1", "2", "3"}
    for c in crossrefs:
        assert c.text is not None and c.text.isdigit()


def test_refine_reconstruction_multi_block_body_scans_all_blocks() -> None:
    spans = [
        _make_span("Prima parte ", font="Verdana", size=BODY_SIZE, block_index=0, span_index=0),
        _make_span(
            "5",
            font="Verdana,Bold",
            size=CROSSREF_SIZE,
            flags=CROSSREF_FLAG_BITS,
            block_index=0,
            span_index=1,
        ),
        _make_span(" seconda parte ", font="Verdana", size=BODY_SIZE, block_index=1, span_index=0),
        _make_span(
            "7",
            font="Verdana,Bold",
            size=CROSSREF_SIZE,
            flags=CROSSREF_FLAG_BITS,
            block_index=1,
            span_index=1,
        ),
    ]
    blocks = [
        _make_block(span_range=(0, 2), block_index=0),
        _make_block(span_range=(2, 4), block_index=1),
    ]
    ext = _make_extraction(spans, blocks)
    parent = _node(
        "node_0001",
        SemanticCategory.HEADING_3,
        "§ 1",
        children=(
            _node(
                "node_0002",
                SemanticCategory.BODY,
                "Prima parte 5 seconda parte 7.",
                block_indices=(0, 1),
            ),
        ),
    )
    new_doc, _ = _reconstruct(Document(root=(parent,)), ext)
    crossrefs = [
        c for c in new_doc.root[0].children if c.category is SemanticCategory.CROSS_REFERENCE
    ]
    assert {c.text for c in crossrefs} == {"5", "7"}


def test_refine_reconstruction_minted_crossref_has_empty_apparatus_refs() -> None:
    spans = [
        _make_span("Vedi ", font="Verdana", size=BODY_SIZE, span_index=0),
        _make_span(
            "9", font="Verdana,Bold", size=CROSSREF_SIZE, flags=CROSSREF_FLAG_BITS, span_index=1
        ),
    ]
    blocks = [_make_block(span_range=(0, 2), block_index=0)]
    ext = _make_extraction(spans, blocks)
    parent = _node(
        "node_0001",
        SemanticCategory.HEADING_3,
        "§ 1",
        children=(_node("node_0002", SemanticCategory.BODY, "Vedi 9.", block_indices=(0,)),),
    )
    new_doc, _ = _reconstruct(Document(root=(parent,)), ext)
    crossrefs = [
        c for c in new_doc.root[0].children if c.category is SemanticCategory.CROSS_REFERENCE
    ]
    assert crossrefs[0].apparatus_refs == ()


def test_refine_reconstruction_minted_crossref_ids_match_schema_pattern() -> None:
    spans = [
        _make_span("Vedi ", font="Verdana", size=BODY_SIZE, span_index=0),
        _make_span(
            "9", font="Verdana,Bold", size=CROSSREF_SIZE, flags=CROSSREF_FLAG_BITS, span_index=1
        ),
    ]
    blocks = [_make_block(span_range=(0, 2), block_index=0)]
    ext = _make_extraction(spans, blocks)
    parent = _node(
        "node_0001",
        SemanticCategory.HEADING_3,
        "§ 1",
        children=(_node("node_0002", SemanticCategory.BODY, "Vedi 9.", block_indices=(0,)),),
    )
    new_doc, _ = _reconstruct(Document(root=(parent,)), ext)
    pattern = re.compile(r"^node_\d+$")
    for c in new_doc.root[0].children:
        if c.category is SemanticCategory.CROSS_REFERENCE:
            assert pattern.match(c.id)


def test_refine_reconstruction_emits_crossref_per_mint_warning() -> None:
    spans = [
        _make_span("Vedi ", font="Verdana", size=BODY_SIZE, span_index=0, page=42),
        _make_span(
            "9",
            font="Verdana,Bold",
            size=CROSSREF_SIZE,
            flags=CROSSREF_FLAG_BITS,
            span_index=1,
            page=42,
        ),
    ]
    blocks = [_make_block(span_range=(0, 2), block_index=0, page=42)]
    ext = _make_extraction(spans, blocks)
    parent = _node(
        "node_0001",
        SemanticCategory.HEADING_3,
        "§ 1",
        page_index=42,
        children=(
            _node(
                "node_0002",
                SemanticCategory.BODY,
                "Vedi 9.",
                page_index=42,
                block_indices=(0,),
            ),
        ),
    )
    new_doc, _ = _reconstruct(Document(root=(parent,)), ext)
    crossref = next(
        c for c in new_doc.root[0].children if c.category is SemanticCategory.CROSS_REFERENCE
    )
    expected = f"{WARNING_PREFIX}:cross_reference_minted_node_{crossref.id}_page_42_marker_9"
    assert expected in new_doc.warnings


def test_refine_reconstruction_crossref_tracked_in_minted_ids_set() -> None:
    spans = [
        _make_span("Vedi ", font="Verdana", size=BODY_SIZE, span_index=0),
        _make_span(
            "9", font="Verdana,Bold", size=CROSSREF_SIZE, flags=CROSSREF_FLAG_BITS, span_index=1
        ),
    ]
    blocks = [_make_block(span_range=(0, 2), block_index=0)]
    ext = _make_extraction(spans, blocks)
    parent = _node(
        "node_0001",
        SemanticCategory.HEADING_3,
        "§ 1",
        children=(_node("node_0002", SemanticCategory.BODY, "Vedi 9.", block_indices=(0,)),),
    )
    plugin = ManualeBicProfile()
    new_doc, _ = _reconstruct(Document(root=(parent,)), ext, plugin=plugin)
    crossrefs = [
        c for c in new_doc.root[0].children if c.category is SemanticCategory.CROSS_REFERENCE
    ]
    assert crossrefs[0].id in plugin._minted_crossref_ids


# ---------------------------------------------------------------------------
# Premesse dedup


def test_premesse_dedup_drops_second_on_same_page() -> None:
    page = 7
    first = _node("node_0001", SemanticCategory.HEADING_2, "Premesse", page_index=page)
    second = _node("node_0002", SemanticCategory.HEADING_2, "Premesse", page_index=page)
    # Both Premesse must be children of a common parent for the dedup to fire.
    parent = _node(
        "node_0000",
        SemanticCategory.HEADING_1,
        "Capitolo I",
        page_index=page,
        children=(first, second),
    )
    ext = _make_extraction([], [])
    new_doc, _ = _reconstruct(Document(root=(parent,)), ext)
    children = new_doc.root[0].children
    h2 = [c for c in children if c.category is SemanticCategory.HEADING_2]
    assert len(h2) == 1
    assert h2[0].id == "node_0001"


def test_premesse_dedup_single_occurrence_unchanged() -> None:
    page = 7
    only = _node("node_0001", SemanticCategory.HEADING_2, "Premesse", page_index=page)
    parent = _node(
        "node_0000",
        SemanticCategory.HEADING_1,
        "Capitolo I",
        children=(only,),
    )
    ext = _make_extraction([], [])
    new_doc, _ = _reconstruct(Document(root=(parent,)), ext)
    h2 = [c for c in new_doc.root[0].children if c.category is SemanticCategory.HEADING_2]
    assert len(h2) == 1


def test_premesse_dedup_other_text_unaffected() -> None:
    """Two HEADING_2 nodes with text != Premesse on the same page are both kept."""
    a = _node("node_0001", SemanticCategory.HEADING_2, "Capitolo Uno", page_index=7)
    b = _node("node_0002", SemanticCategory.HEADING_2, "Capitolo Due", page_index=7)
    parent = _node(
        "node_0000",
        SemanticCategory.HEADING_1,
        "Capitolo I",
        children=(a, b),
    )
    ext = _make_extraction([], [])
    new_doc, _ = _reconstruct(Document(root=(parent,)), ext)
    h2 = [c for c in new_doc.root[0].children if c.category is SemanticCategory.HEADING_2]
    assert len(h2) == 2


# ---------------------------------------------------------------------------
# refine_apparatus


def test_refine_apparatus_empty_document_passes_through() -> None:
    plugin = ManualeBicProfile()
    empty_doc = Document(root=())
    ext = _make_extraction([], [])
    out = plugin.refine_apparatus(empty_doc, ext, [])
    assert out is empty_doc


def test_refine_apparatus_non_empty_emits_language_mismatch_warning() -> None:
    plugin = ManualeBicProfile()
    doc = Document(root=(_node("node_0001", SemanticCategory.BODY, "x"),))
    ext = _make_extraction([], [])
    out = plugin.refine_apparatus(doc, ext, [])
    assert f"{WARNING_PREFIX}:language_metadata_mismatch_lang_en-US" in out.warnings


def test_refine_apparatus_preserves_prior_warnings() -> None:
    plugin = ManualeBicProfile()
    doc = Document(
        root=(_node("node_0001", SemanticCategory.BODY, "x"),),
        warnings=("prior_warning_one", "prior_warning_two"),
    )
    ext = _make_extraction([], [])
    out = plugin.refine_apparatus(doc, ext, [])
    assert "prior_warning_one" in out.warnings
    assert "prior_warning_two" in out.warnings
    assert f"{WARNING_PREFIX}:language_metadata_mismatch_lang_en-US" in out.warnings


# ---------------------------------------------------------------------------
# Consolidation: note continuation rescue (residuo 2)


def test_note_continuation_rescue_preceded_by_note_promotes_to_note() -> None:
    """A BODY whose text starts with ``N. `` and whose preceding sibling
    is a NOTE is converted to one synthetic NOTE Node.
    """
    spans = [_make_span("13. nota tredici.", font="Verdana", size=BODY_SIZE, span_index=0)]
    blocks = [_make_block(span_range=(0, 1), block_index=0)]
    ext = _make_extraction(spans, blocks)
    note = _node("node_0001", SemanticCategory.NOTE, "12. nota dodici.")
    body = _node(
        "node_0002",
        SemanticCategory.BODY,
        "13. nota tredici.",
        block_indices=(0,),
    )
    parent = _node(
        "node_0000",
        SemanticCategory.HEADING_3,
        "§ 1",
        children=(note, body),
    )
    new_doc, _ = _reconstruct(Document(root=(parent,)), ext)
    children = new_doc.root[0].children
    notes = [c for c in children if c.category is SemanticCategory.NOTE]
    bodies = [c for c in children if c.category is SemanticCategory.BODY]
    assert len(notes) == 2
    assert not bodies


def test_note_continuation_rescue_preceded_by_body_not_rescued() -> None:
    """A BODY starting with ``N. `` whose preceding sibling is a BODY (not
    NOTE, not artifact) stays a BODY — the structural guard rejects.
    """
    spans = [_make_span("200. anno fondamentale.", font="Verdana", size=BODY_SIZE, span_index=0)]
    blocks = [_make_block(span_range=(0, 1), block_index=0)]
    ext = _make_extraction(spans, blocks)
    body_a = _node("node_0001", SemanticCategory.BODY, "Previous body sentence.")
    body_b = _node(
        "node_0002",
        SemanticCategory.BODY,
        "200. anno fondamentale.",
        block_indices=(0,),
    )
    parent = _node(
        "node_0000",
        SemanticCategory.HEADING_3,
        "§ 1",
        children=(body_a, body_b),
    )
    new_doc, _ = _reconstruct(Document(root=(parent,)), ext)
    children = new_doc.root[0].children
    notes = [c for c in children if c.category is SemanticCategory.NOTE]
    assert not notes


def test_note_continuation_rescue_skips_artifact_between_note_and_body() -> None:
    """When ARTIFACT_FOOTER sits between the preceding NOTE and the
    BODY note-continuation, the rescuer still fires.
    """
    spans = [_make_span("13. nota tredici.", font="Verdana", size=BODY_SIZE, span_index=0)]
    blocks = [_make_block(span_range=(0, 1), block_index=0)]
    ext = _make_extraction(spans, blocks)
    note = _node("node_0001", SemanticCategory.NOTE, "12. nota dodici.")
    footer = _node("node_0002", SemanticCategory.ARTIFACT_FOOTER, "Pag. 5 6")
    body = _node(
        "node_0003",
        SemanticCategory.BODY,
        "13. nota tredici.",
        block_indices=(0,),
    )
    parent = _node(
        "node_0000",
        SemanticCategory.HEADING_3,
        "§ 1",
        children=(note, footer, body),
    )
    new_doc, _ = _reconstruct(Document(root=(parent,)), ext)
    children = new_doc.root[0].children
    notes = [c for c in children if c.category is SemanticCategory.NOTE]
    assert len(notes) == 2


def test_note_continuation_rescue_rejects_year_like_marker() -> None:
    """A BODY whose text starts with ``1927. ...`` (a year, above
    NOTE_MARKER_MAX_VALUE) is NOT promoted, even with a NOTE preceding sibling.
    """
    spans = [_make_span("1927. anno cruciale.", font="Verdana", size=BODY_SIZE, span_index=0)]
    blocks = [_make_block(span_range=(0, 1), block_index=0)]
    ext = _make_extraction(spans, blocks)
    note = _node("node_0001", SemanticCategory.NOTE, "12. nota dodici.")
    body = _node(
        "node_0002",
        SemanticCategory.BODY,
        "1927. anno cruciale.",
        block_indices=(0,),
    )
    parent = _node(
        "node_0000",
        SemanticCategory.HEADING_3,
        "§ 1",
        children=(note, body),
    )
    new_doc, _ = _reconstruct(Document(root=(parent,)), ext)
    children = new_doc.root[0].children
    notes = [c for c in children if c.category is SemanticCategory.NOTE]
    assert len(notes) == 1  # only the pre-existing NOTE survives


def test_note_continuation_rescue_splits_multi_note_body() -> None:
    """A BODY containing multiple ``N. `` markers gets split into one
    synthetic NOTE per marker via the multi-note splitter.
    """
    spans = [
        _make_span("13. nota tre.", font="Verdana", size=BODY_SIZE, line_index=0, span_index=0),
        _make_span("14. nota qua.", font="Verdana", size=BODY_SIZE, line_index=1, span_index=0),
        _make_span("15. nota cin.", font="Verdana", size=BODY_SIZE, line_index=2, span_index=0),
    ]
    blocks = [_make_block(span_range=(0, 3), block_index=0)]
    ext = _make_extraction(spans, blocks)
    note = _node("node_0001", SemanticCategory.NOTE, "12. nota dodici.")
    body = _node(
        "node_0002",
        SemanticCategory.BODY,
        "13. nota tre.14. nota qua.15. nota cin.",
        block_indices=(0,),
    )
    parent = _node(
        "node_0000",
        SemanticCategory.HEADING_3,
        "§ 1",
        children=(note, body),
    )
    new_doc, _ = _reconstruct(Document(root=(parent,)), ext)
    children = new_doc.root[0].children
    notes = [c for c in children if c.category is SemanticCategory.NOTE]
    # 1 original NOTE + 3 synthetic NOTEs from the rescuer
    assert len(notes) == 4


def test_is_back_matter_heading_recognises_bibliografia() -> None:
    bibliografia = _node("node_0000", SemanticCategory.HEADING_1, "Bibliografia")
    assert _is_back_matter_heading(bibliografia) is True


def test_is_back_matter_heading_recognises_indice_analitico() -> None:
    indice = _node("node_0001", SemanticCategory.HEADING_1, "Indice analitico")
    assert _is_back_matter_heading(indice) is True


def test_is_back_matter_heading_rejects_chapter() -> None:
    chapter = _node("node_0002", SemanticCategory.HEADING_1, "Capitolo I - Ius")
    assert _is_back_matter_heading(chapter) is False


def test_is_back_matter_heading_rejects_text_none() -> None:
    blank = _node("node_0003", SemanticCategory.HEADING_1, None)
    assert _is_back_matter_heading(blank) is False


# ---------------------------------------------------------------------------
# Consolidation: book_page_anchor inline minting (residuo 1)


def test_anchor_minting_mixed_block_emits_synthetic_anchor() -> None:
    """A BODY block containing a 0.96pt numeric Verdana span (anchor)
    plus the 12pt body spans yields one synthetic BOOK_PAGE_ANCHOR Node.
    """
    spans = [
        _make_span("3", font="Verdana", size=0.96, bbox=(56.0, 80.0, 60.0, 81.0), span_index=0),
        _make_span("Body sentence here.", font="Verdana", size=BODY_SIZE, span_index=1),
    ]
    blocks = [_make_block(span_range=(0, 2), block_index=0)]
    ext = _make_extraction(spans, blocks)
    body = _node(
        "node_0001",
        SemanticCategory.BODY,
        "3Body sentence here.",
        block_indices=(0,),
    )
    parent = _node(
        "node_0000",
        SemanticCategory.HEADING_3,
        "§ 1",
        children=(body,),
    )
    new_doc, _ = _reconstruct(Document(root=(parent,)), ext)
    children = new_doc.root[0].children
    anchors = [c for c in children if c.category is SemanticCategory.BOOK_PAGE_ANCHOR]
    assert len(anchors) == 1
    assert anchors[0].text == "3"


def test_anchor_minting_skips_all_1pt_block() -> None:
    """A block where every span is < 2pt is left to tier 1
    ``tiny_font_anchor``; the plugin walker does NOT re-mint anchors
    inside an already-anchor Node.
    """
    spans = [_make_span("3", font="Verdana", size=0.96, span_index=0)]
    blocks = [_make_block(span_range=(0, 1), block_index=0)]
    ext = _make_extraction(spans, blocks)
    anchor = _node(
        "node_0001",
        SemanticCategory.BOOK_PAGE_ANCHOR,
        "3",
        block_indices=(0,),
    )
    parent = _node(
        "node_0000",
        SemanticCategory.HEADING_3,
        "§ 1",
        children=(anchor,),
    )
    new_doc, _ = _reconstruct(Document(root=(parent,)), ext)
    anchors = [
        c for c in new_doc.root[0].children if c.category is SemanticCategory.BOOK_PAGE_ANCHOR
    ]
    assert len(anchors) == 1  # the pre-existing tier 1 anchor stays, no re-minting


def test_anchor_minting_rejects_non_numeric_1pt() -> None:
    """A 0.96pt Verdana span with non-digit text does not mint an anchor."""
    spans = [
        _make_span("v", font="Verdana", size=0.96, span_index=0),
        _make_span("Body sentence.", font="Verdana", size=BODY_SIZE, span_index=1),
    ]
    blocks = [_make_block(span_range=(0, 2), block_index=0)]
    ext = _make_extraction(spans, blocks)
    body = _node(
        "node_0001",
        SemanticCategory.BODY,
        "vBody sentence.",
        block_indices=(0,),
    )
    parent = _node(
        "node_0000",
        SemanticCategory.HEADING_3,
        "§ 1",
        children=(body,),
    )
    new_doc, _ = _reconstruct(Document(root=(parent,)), ext)
    anchors = [
        c for c in new_doc.root[0].children if c.category is SemanticCategory.BOOK_PAGE_ANCHOR
    ]
    assert not anchors


def test_anchor_minting_recognises_arial_anchor() -> None:
    """An Arial 0.96pt numeric span is also recognised as an anchor."""
    spans = [
        _make_span("12", font="Arial", size=0.96, span_index=0),
        _make_span("Body sentence.", font="Verdana", size=BODY_SIZE, span_index=1),
    ]
    blocks = [_make_block(span_range=(0, 2), block_index=0)]
    ext = _make_extraction(spans, blocks)
    body = _node(
        "node_0001",
        SemanticCategory.BODY,
        "12Body sentence.",
        block_indices=(0,),
    )
    parent = _node(
        "node_0000",
        SemanticCategory.HEADING_3,
        "§ 1",
        children=(body,),
    )
    new_doc, _ = _reconstruct(Document(root=(parent,)), ext)
    anchors = [
        c for c in new_doc.root[0].children if c.category is SemanticCategory.BOOK_PAGE_ANCHOR
    ]
    assert len(anchors) == 1
    assert anchors[0].text == "12"


# ---------------------------------------------------------------------------
# Consolidation: refine_apparatus profile-specific CR -> NOTE binding
# (residuo 3)


def test_refine_apparatus_binds_cr_forward_to_note_in_same_chapter() -> None:
    """A plugin-minted CR with marker N binds to a NOTE Node with text
    ``"N. ..."`` that appears AFTER it in pre-order DFS within the same
    HEADING_1 chapter (forward scan, not the tier 1 backward scan).
    """
    plugin = ManualeBicProfile()
    cr = _node("node_0002", SemanticCategory.CROSS_REFERENCE, "12")
    plugin._minted_crossref_ids = {"node_0002"}
    body = _node(
        "node_0001",
        SemanticCategory.BODY,
        "body referring to 12.",
        children=(cr,),
    )
    note = _node("node_0003", SemanticCategory.NOTE, "12. nota dodici.")
    chapter = _node(
        "node_0000",
        SemanticCategory.HEADING_1,
        "Capitolo I",
        children=(body, note),
    )
    doc = Document(root=(chapter,))
    ext = _make_extraction([], [])
    out = plugin.refine_apparatus(doc, ext, [])

    def find(roots: tuple[Node, ...], node_id: str) -> Node | None:
        for r in roots:
            if r.id == node_id:
                return r
            found = find(r.children, node_id)
            if found is not None:
                return found
        return None

    bound = find(out.root, "node_0002")
    assert bound is not None
    assert len(bound.apparatus_refs) == 1
    assert bound.apparatus_refs[0].kind is ApparatusRefKind.CROSS_REF_TARGET
    assert bound.apparatus_refs[0].target_node_id == "node_0003"


def test_refine_apparatus_unbound_cr_emits_unresolved_warning() -> None:
    """A plugin-minted CR with marker N whose chapter contains no NOTE
    with that marker stays unbound and emits the closed-vocabulary
    ``cross_reference_unresolved_node_<id>_marker_<N>`` warning.
    """
    plugin = ManualeBicProfile()
    cr = _node("node_0002", SemanticCategory.CROSS_REFERENCE, "99")
    plugin._minted_crossref_ids = {"node_0002"}
    body = _node(
        "node_0001",
        SemanticCategory.BODY,
        "body with crossref 99.",
        children=(cr,),
    )
    chapter = _node(
        "node_0000",
        SemanticCategory.HEADING_1,
        "Capitolo I",
        children=(body,),
    )
    doc = Document(root=(chapter,))
    ext = _make_extraction([], [])
    out = plugin.refine_apparatus(doc, ext, [])
    assert any(
        w == f"{WARNING_PREFIX}:cross_reference_unresolved_node_node_0002_marker_99"
        for w in out.warnings
    )


def test_refine_apparatus_filters_tier1_unresolved_warning_for_minted_cr() -> None:
    """Tier 1 ``unresolved_cross_reference_node_<id>_n_<N>`` warnings
    whose Node id belongs to a plugin-minted CR are dropped (the
    plugin's forward-scan override resolved them).
    """
    plugin = ManualeBicProfile()
    plugin._minted_crossref_ids = {"node_0002"}
    cr = _node("node_0002", SemanticCategory.CROSS_REFERENCE, "12")
    note = _node("node_0003", SemanticCategory.NOTE, "12. nota.")
    body = _node(
        "node_0001",
        SemanticCategory.BODY,
        "body referring to 12.",
        children=(cr,),
    )
    chapter = _node(
        "node_0000",
        SemanticCategory.HEADING_1,
        "Capitolo I",
        children=(body, note),
    )
    doc = Document(
        root=(chapter,),
        warnings=(
            "unresolved_cross_reference_node_node_0002_n_12",
            "unresolved_cross_reference_node_node_0099_n_5",  # foreign — keep
        ),
    )
    ext = _make_extraction([], [])
    out = plugin.refine_apparatus(doc, ext, [])
    assert "unresolved_cross_reference_node_node_0002_n_12" not in out.warnings
    assert "unresolved_cross_reference_node_node_0099_n_5" in out.warnings


def test_refine_apparatus_chapter_separation_independent_bindings() -> None:
    """A CR with marker N in chapter A binds only to chapter A's NOTE N,
    even if chapter B has a NOTE with the same marker preceding the CR
    in DFS order. The chapter-scope guard prevents cross-chapter
    bindings.
    """
    plugin = ManualeBicProfile()
    plugin._minted_crossref_ids = {"node_0006"}
    note_a = _node("node_0002", SemanticCategory.NOTE, "5. nota cap A.")
    body_a = _node("node_0001", SemanticCategory.BODY, "body cap A.")
    chap_a = _node(
        "node_0000",
        SemanticCategory.HEADING_1,
        "Capitolo I",
        children=(body_a, note_a),
    )
    cr_b = _node("node_0006", SemanticCategory.CROSS_REFERENCE, "5")
    body_b = _node(
        "node_0005",
        SemanticCategory.BODY,
        "body cap B with 5.",
        children=(cr_b,),
    )
    note_b = _node("node_0007", SemanticCategory.NOTE, "5. nota cap B.")
    chap_b = _node(
        "node_0004",
        SemanticCategory.HEADING_1,
        "Capitolo II",
        children=(body_b, note_b),
    )
    doc = Document(root=(chap_a, chap_b))
    ext = _make_extraction([], [])
    out = plugin.refine_apparatus(doc, ext, [])

    def find(roots: tuple[Node, ...], node_id: str) -> Node | None:
        for r in roots:
            if r.id == node_id:
                return r
            found = find(r.children, node_id)
            if found is not None:
                return found
        return None

    bound = find(out.root, "node_0006")
    assert bound is not None
    assert len(bound.apparatus_refs) == 1
    # Must bind to chapter B's note, not chapter A's
    assert bound.apparatus_refs[0].target_node_id == "node_0007"


def test_refine_apparatus_non_minted_cr_apparatus_refs_preserved() -> None:
    """A CR Node NOT minted by the plugin (e.g. tier 1's
    standalone-superscript-digit emission) keeps its existing
    apparatus_refs.
    """
    plugin = ManualeBicProfile()
    plugin._minted_crossref_ids = set()  # nothing minted
    tier1_ref = ApparatusRef(kind=ApparatusRefKind.CROSS_REF_TARGET, target_node_id="node_external")
    cr = _node(
        "node_0002",
        SemanticCategory.CROSS_REFERENCE,
        "12",
        apparatus_refs=(tier1_ref,),
    )
    body = _node(
        "node_0001",
        SemanticCategory.BODY,
        "body.",
        children=(cr,),
    )
    chapter = _node(
        "node_0000",
        SemanticCategory.HEADING_1,
        "Capitolo I",
        children=(body,),
    )
    doc = Document(root=(chapter,))
    ext = _make_extraction([], [])
    out = plugin.refine_apparatus(doc, ext, [])

    def find(roots: tuple[Node, ...], node_id: str) -> Node | None:
        for r in roots:
            if r.id == node_id:
                return r
            found = find(r.children, node_id)
            if found is not None:
                return found
        return None

    untouched = find(out.root, "node_0002")
    assert untouched is not None
    assert len(untouched.apparatus_refs) == 1
    assert untouched.apparatus_refs[0].target_node_id == "node_external"


# ---------------------------------------------------------------------------
# Cross-reference minting under back-matter (Bibliografia) is suppressed


def test_crossref_minting_skipped_under_bibliografia_heading() -> None:
    """Inline cross-references inside a Bibliografia HEADING_1 subtree
    are NOT minted (those references point to bibliography entries, not
    NOTE Nodes).
    """
    spans = [
        _make_span(
            "12",
            font="Verdana,Bold",
            size=CROSSREF_SIZE,
            flags=CROSSREF_FLAG_BITS,
            span_index=0,
        ),
    ]
    blocks = [_make_block(span_range=(0, 1), block_index=0)]
    ext = _make_extraction(spans, blocks)
    body = _node(
        "node_0001",
        SemanticCategory.BODY,
        "body with crossref 12.",
        block_indices=(0,),
    )
    bibliografia = _node(
        "node_0000",
        SemanticCategory.HEADING_1,
        "Bibliografia",
        children=(body,),
    )
    new_doc, _ = _reconstruct(Document(root=(bibliografia,)), ext)
    crs = [c for c in new_doc.root[0].children if c.category is SemanticCategory.CROSS_REFERENCE]
    assert not crs


def test_crossref_minting_runs_under_chapter_heading() -> None:
    """Inline cross-references inside a regular chapter HEADING_1 subtree
    ARE minted.
    """
    spans = [
        _make_span(
            "12",
            font="Verdana,Bold",
            size=CROSSREF_SIZE,
            flags=CROSSREF_FLAG_BITS,
            span_index=0,
        ),
    ]
    blocks = [_make_block(span_range=(0, 1), block_index=0)]
    ext = _make_extraction(spans, blocks)
    body = _node(
        "node_0001",
        SemanticCategory.BODY,
        "body with crossref 12.",
        block_indices=(0,),
    )
    chapter = _node(
        "node_0000",
        SemanticCategory.HEADING_1,
        "Capitolo I - Ius",
        children=(body,),
    )
    new_doc, _ = _reconstruct(Document(root=(chapter,)), ext)
    crs = [c for c in new_doc.root[0].children if c.category is SemanticCategory.CROSS_REFERENCE]
    assert len(crs) == 1


# ---------------------------------------------------------------------------
# Module-level constants


def test_note_marker_max_value_above_observed_chapter_max() -> None:
    """NOTE_MARKER_MAX_VALUE is comfortably above the densest Marrone
    chapter's max marker (395 in Capitolo VII).
    """
    assert NOTE_MARKER_MAX_VALUE > 395


def test_anchor_max_size_matches_tier1_threshold() -> None:
    """ANCHOR_MAX_SIZE mirrors the tier 1 tiny_font_anchor threshold."""
    assert ANCHOR_MAX_SIZE == 2.0
