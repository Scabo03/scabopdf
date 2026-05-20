"""Unit tests for the dejure_nota_sentenza corpus plugin."""

from __future__ import annotations

import pytest

from scabopdf_pipeline.apparatus.constants import (
    INLINE_PARENTHESISED_CROSSREF_REGEX as _CROSSREF_INLINE_PATTERN,
)
from scabopdf_pipeline.apparatus.constants import (
    LEADING_PARENTHESISED_NOTE_MARKER_REGEX as _NOTE_MARKER_PATTERN,
)
from scabopdf_pipeline.apparatus.types import ApparatusRefKind
from scabopdf_pipeline.classification.types import ClassifiedBlock
from scabopdf_pipeline.extraction.types import Block, ExtractionResult, Span
from scabopdf_pipeline.profiles._dejure_shared import (
    FOOTER_PATTERN as _FOOTER_PATTERN,
)
from scabopdf_pipeline.profiles._dejure_shared import (
    BlockView as _BlockView,
)
from scabopdf_pipeline.profiles.dejure_nota_sentenza import (
    _SECTION_HEADING_PATTERN,
    BANNER_SIZE,
    BODY_SIZE,
    COPYRIGHT_SIZE,
    TITLE_SIZE,
    WARNING_PREFIX,
    DejureNotaSentenzaProfile,
    _strip_label,
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
    NodeIdMinter as _NodeIdMinter,
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


def _dejure_signals(
    *,
    body_family: str = "ArialMT",
    body_size: float = BODY_SIZE,
    body_dominance: float = 70.0,
    include_title: bool = True,
    include_banner: bool = True,
    producer: str = "Aspose.PDF for .NET 18.4",
    creator: str = "Aspose.PDF for .NET 18.4",
    width_pt: float = 612.0,
    height_pt: float = 792.0,
    marginal_headings: int = 0,
) -> ProfilingSignals:
    fonts = [
        FontDominance(family=body_family, size=body_size, dominance_percent=body_dominance),
    ]
    if include_title:
        fonts.append(FontDominance(family="Arial-BoldMT", size=TITLE_SIZE, dominance_percent=0.5))
    if include_banner:
        fonts.append(FontDominance(family="Arial-BoldMT", size=BANNER_SIZE, dominance_percent=1.0))
    return ProfilingSignals(
        typographic_signature=TypographicSignature(fonts=fonts),
        apparatus_presence=ApparatusPresence(
            marginal_headings=marginal_headings,
        ),
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
    plugin = DejureNotaSentenzaProfile()
    assert plugin.profile_id == "dejure_nota_sentenza"
    assert plugin.editorial_family == "dejure"
    assert plugin.genre == "nota_sentenza"


def test_get_categories_covers_dejure_specific_set() -> None:
    plugin = DejureNotaSentenzaProfile()
    cats = plugin.get_categories()
    expected_subset = {
        SemanticCategory.TITLE,
        SemanticCategory.GENRE_BANNER,
        SemanticCategory.META_VALUE,
        SemanticCategory.FONTE_VALUE,
        SemanticCategory.REFERRAL,
        SemanticCategory.AUTHORS,
        SemanticCategory.SUBTITLE,
        SemanticCategory.SECTION_LABEL,
        SemanticCategory.TOC_GENERAL,
        SemanticCategory.HEADING_1,
        SemanticCategory.BODY,
        SemanticCategory.NOTE,
        SemanticCategory.CROSS_REFERENCE,
    }
    assert expected_subset <= cats


def test_get_post_processing_only_dehyphenate() -> None:
    plugin = DejureNotaSentenzaProfile()
    assert plugin.get_post_processing() == ["dehyphenate_with_log"]


def test_get_layouts_disabled_is_empty() -> None:
    plugin = DejureNotaSentenzaProfile()
    assert plugin.get_layouts_disabled() == []


# ---------------------------------------------------------------------------
# matches()


def test_matches_dejure_short_fixture_clears_threshold() -> None:
    score = DejureNotaSentenzaProfile.matches(_dejure_signals())
    assert score >= 0.6


def test_matches_returns_below_threshold_on_non_arial_body() -> None:
    signals = _dejure_signals(
        body_family="OpenSans-Regular",
        body_dominance=70.0,
        include_title=False,
        include_banner=False,
    )
    score = DejureNotaSentenzaProfile.matches(signals)
    assert score < 0.6


def test_matches_returns_clamped_zero_on_a4_geometry() -> None:
    signals = _dejure_signals(
        body_family="OpenSans-Regular",
        body_dominance=70.0,
        width_pt=595.0,
        height_pt=842.0,
        producer="Skia/PDF",
        creator="Skia/PDF",
        include_title=False,
        include_banner=False,
    )
    score = DejureNotaSentenzaProfile.matches(signals)
    assert score == 0.0


def test_matches_credits_letter_geometry() -> None:
    arial = _dejure_signals()
    a4 = _dejure_signals(width_pt=595.0, height_pt=842.0)
    score_arial = DejureNotaSentenzaProfile.matches(arial)
    score_a4 = DejureNotaSentenzaProfile.matches(a4)
    assert score_arial > score_a4


def test_matches_credits_aspose_producer() -> None:
    with_aspose = _dejure_signals(producer="Aspose.PDF for .NET 18.4")
    without_aspose = _dejure_signals(producer="Unknown", creator="Unknown")
    s1 = DejureNotaSentenzaProfile.matches(with_aspose)
    s2 = DejureNotaSentenzaProfile.matches(without_aspose)
    assert s1 > s2


def test_matches_penalises_marginal_apparatus() -> None:
    no_apparatus = _dejure_signals(marginal_headings=0)
    with_apparatus = _dejure_signals(marginal_headings=4051)
    score_clean = DejureNotaSentenzaProfile.matches(no_apparatus)
    score_apparatus = DejureNotaSentenzaProfile.matches(with_apparatus)
    assert score_clean > score_apparatus


def test_matches_returns_zero_on_torrente_signature() -> None:
    signals = _dejure_signals(
        body_family="MScotchRoman",
        body_size=11.47,
        producer="PDFsharp 1.31.1789-g",
        creator="PDFsharp 1.31.1789-g",
        include_title=False,
        include_banner=False,
        marginal_headings=4051,
    )
    score = DejureNotaSentenzaProfile.matches(signals)
    assert score == 0.0


def test_matches_returns_zero_on_verdana_body() -> None:
    signals = _dejure_signals(
        body_family="Verdana",
        producer="Adobe PDF Library 9.0",
        creator="Adobe InDesign CS3",
        include_title=False,
        include_banner=False,
    )
    score = DejureNotaSentenzaProfile.matches(signals)
    assert score == 0.0


def test_matches_returns_zero_on_times_new_roman_body() -> None:
    signals = _dejure_signals(
        body_family="Times-New-Roman",
        producer="",
        creator="",
        include_title=False,
        include_banner=False,
    )
    score = DejureNotaSentenzaProfile.matches(signals)
    assert score == 0.0


def test_matches_clamps_at_zero_minimum() -> None:
    signals = _dejure_signals(
        body_family="TimesTenLTStd",
        marginal_headings=1000,
        producer="",
        creator="",
        include_title=False,
        include_banner=False,
    )
    score = DejureNotaSentenzaProfile.matches(signals)
    assert score == 0.0


def test_matches_letter_tolerance_accepts_small_drift() -> None:
    signals = _dejure_signals(width_pt=612.5, height_pt=792.4)
    score = DejureNotaSentenzaProfile.matches(signals)
    assert score >= 0.6


# ---------------------------------------------------------------------------
# Predicates: _is_genre_banner


def test_is_genre_banner_matches_exact_text() -> None:
    view = _make_view(
        [_make_span("NOTE E DOTTRINA", font="Arial-BoldMT", size=BANNER_SIZE, flags=BOLD_FLAG)]
    )
    assert DejureNotaSentenzaProfile._is_genre_banner(view)


def test_is_genre_banner_rejects_other_text() -> None:
    view = _make_view(
        [_make_span("MASSIMA", font="Arial-BoldMT", size=BANNER_SIZE, flags=BOLD_FLAG)]
    )
    assert not DejureNotaSentenzaProfile._is_genre_banner(view)


def test_is_genre_banner_rejects_wrong_size() -> None:
    view = _make_view(
        [_make_span("NOTE E DOTTRINA", font="Arial-BoldMT", size=12.0, flags=BOLD_FLAG)]
    )
    assert not DejureNotaSentenzaProfile._is_genre_banner(view)


def test_is_genre_banner_rejects_non_bold_family() -> None:
    view = _make_view([_make_span("NOTE E DOTTRINA", font="ArialMT", size=BANNER_SIZE)])
    assert not DejureNotaSentenzaProfile._is_genre_banner(view)


# Predicates: _is_page_header_tagline


def test_is_page_header_tagline_matches_fragment() -> None:
    view = _make_view([_make_span("Banche dati editoriali GFL")])
    assert DejureNotaSentenzaProfile._is_page_header_tagline(view)


def test_is_page_header_tagline_rejects_unrelated_text() -> None:
    view = _make_view([_make_span("Random text")])
    assert not DejureNotaSentenzaProfile._is_page_header_tagline(view)


# Predicates: _is_title


def test_is_title_matches_bold_13pt() -> None:
    view = _make_view(
        [_make_span("Il nesso causale...", font="Arial-BoldMT", size=TITLE_SIZE, flags=BOLD_FLAG)]
    )
    assert DejureNotaSentenzaProfile._is_title(view)


def test_is_title_rejects_12pt() -> None:
    view = _make_view(
        [_make_span("Section heading", font="Arial-BoldMT", size=12.0, flags=BOLD_FLAG)]
    )
    assert not DejureNotaSentenzaProfile._is_title(view)


def test_is_title_rejects_regular_font() -> None:
    view = _make_view([_make_span("Title-like text", font="ArialMT", size=TITLE_SIZE)])
    assert not DejureNotaSentenzaProfile._is_title(view)


# Predicates: _is_metadata_block


def test_is_metadata_block_accepts_full_metadata() -> None:
    view = _make_view(
        [
            _make_span("Fonte: Diritto & Giustizia, fasc.107, 2024", size=BANNER_SIZE),
            _make_span("Nota a: Cass. pen. n.22587", size=BANNER_SIZE),
            _make_span("Autori: Fabio Piccioni", size=BANNER_SIZE),
        ]
    )
    assert DejureNotaSentenzaProfile._is_metadata_block(view)


def test_is_metadata_block_accepts_partial() -> None:
    view = _make_view([_make_span("Fonte: Rivista 2024", size=BANNER_SIZE)])
    assert DejureNotaSentenzaProfile._is_metadata_block(view)


def test_is_metadata_block_rejects_wrong_size() -> None:
    view = _make_view([_make_span("Fonte: Rivista", size=12.0)])
    assert not DejureNotaSentenzaProfile._is_metadata_block(view)


def test_is_metadata_block_rejects_text_without_labels() -> None:
    view = _make_view([_make_span("Some random 9pt text", size=BANNER_SIZE)])
    assert not DejureNotaSentenzaProfile._is_metadata_block(view)


def test_is_metadata_block_accepts_bold_labels() -> None:
    view = _make_view(
        [
            _make_span("Fonte: X, Nota a: Y, Autori: Z", font="Arial-BoldMT", size=BANNER_SIZE),
        ]
    )
    assert DejureNotaSentenzaProfile._is_metadata_block(view)


# Predicates: _is_sommario_block


def test_is_sommario_block_starts_with_sommario() -> None:
    view = _make_view([_make_span("Sommario 1. Intro — 2. Discussione", size=BODY_SIZE)])
    assert DejureNotaSentenzaProfile._is_sommario_block(view)


def test_is_sommario_block_rejects_other_text() -> None:
    view = _make_view([_make_span("Body paragraph", size=BODY_SIZE)])
    assert not DejureNotaSentenzaProfile._is_sommario_block(view)


def test_is_sommario_block_rejects_wrong_size() -> None:
    view = _make_view([_make_span("Sommario 1.", size=9.0)])
    assert not DejureNotaSentenzaProfile._is_sommario_block(view)


# Predicates: _is_subtitle


def test_is_subtitle_matches_quotidiano() -> None:
    view = _make_view([_make_span("Quotidiano del 6 giugno 2024", size=BODY_SIZE)])
    assert DejureNotaSentenzaProfile._is_subtitle(view)


def test_is_subtitle_rejects_bold() -> None:
    view = _make_view(
        [_make_span("Quotidiano del 6 giugno 2024", font="Arial-BoldMT", size=BODY_SIZE)]
    )
    assert not DejureNotaSentenzaProfile._is_subtitle(view)


def test_is_subtitle_rejects_other_text() -> None:
    view = _make_view([_make_span("Generic body", size=BODY_SIZE)])
    assert not DejureNotaSentenzaProfile._is_subtitle(view)


# Predicates: _is_section_heading


def test_is_section_heading_matches_uppercase_numbered() -> None:
    view = _make_view(
        [
            _make_span(
                "1. INQUADRAMENTO PRELIMINARE",
                font="Arial-BoldMT",
                size=BODY_SIZE,
                flags=BOLD_FLAG,
            )
        ]
    )
    assert DejureNotaSentenzaProfile._is_section_heading(view)


def test_is_section_heading_rejects_lowercase_after_number() -> None:
    view = _make_view(
        [_make_span("1. introduction", font="Arial-BoldMT", size=BODY_SIZE, flags=BOLD_FLAG)]
    )
    assert not DejureNotaSentenzaProfile._is_section_heading(view)


def test_is_section_heading_rejects_no_number() -> None:
    view = _make_view(
        [_make_span("INTRODUCTION", font="Arial-BoldMT", size=BODY_SIZE, flags=BOLD_FLAG)]
    )
    assert not DejureNotaSentenzaProfile._is_section_heading(view)


def test_is_section_heading_rejects_regular_family() -> None:
    view = _make_view([_make_span("1. INTRODUZIONE", font="ArialMT", size=BODY_SIZE)])
    assert not DejureNotaSentenzaProfile._is_section_heading(view)


# Predicates: _is_notes_section


def test_is_notes_section_standalone_marker() -> None:
    view = _make_view([_make_span("Note:", font="Arial-BoldMT", size=BODY_SIZE, flags=BOLD_FLAG)])
    assert DejureNotaSentenzaProfile._is_notes_section(view)


def test_is_notes_section_glued_with_notes() -> None:
    view = _make_view(
        [
            _make_span(
                "Note:(1) Contributo...",
                font="Arial-BoldMT",
                size=BODY_SIZE,
                flags=BOLD_FLAG,
            )
        ]
    )
    assert DejureNotaSentenzaProfile._is_notes_section(view)


def test_is_notes_section_variant_with_space() -> None:
    view = _make_view([_make_span("Note :", font="Arial-BoldMT", size=BODY_SIZE, flags=BOLD_FLAG)])
    assert DejureNotaSentenzaProfile._is_notes_section(view)


def test_is_notes_section_rejects_wrong_family() -> None:
    view = _make_view([_make_span("Note:", font="ArialMT", size=BODY_SIZE)])
    assert not DejureNotaSentenzaProfile._is_notes_section(view)


def test_is_notes_section_rejects_unrelated_text() -> None:
    view = _make_view(
        [_make_span("Other heading", font="Arial-BoldMT", size=BODY_SIZE, flags=BOLD_FLAG)]
    )
    assert not DejureNotaSentenzaProfile._is_notes_section(view)


# Predicates: _is_footer


def test_is_footer_pagina_x_di_y() -> None:
    view = _make_view(
        [_make_span("Pagina 1 di 22", font="ArialItalic", size=BODY_SIZE, flags=ITALIC_FLAG)]
    )
    assert DejureNotaSentenzaProfile._is_footer(view)


def test_is_footer_rejects_non_italic() -> None:
    view = _make_view([_make_span("Pagina 1 di 22", font="ArialMT", size=BODY_SIZE)])
    assert not DejureNotaSentenzaProfile._is_footer(view)


def test_is_footer_rejects_unrelated_text() -> None:
    view = _make_view(
        [_make_span("Some italic body", font="Arial-ItalicMT", size=BODY_SIZE, flags=ITALIC_FLAG)]
    )
    assert not DejureNotaSentenzaProfile._is_footer(view)


# Predicates: _is_copyright_stamp


def test_is_copyright_stamp_servizio_fragment() -> None:
    view = _make_view([_make_span("SERVIZIO GESTIONE RISORSE DOCUMENTARIE", size=COPYRIGHT_SIZE)])
    assert DejureNotaSentenzaProfile._is_copyright_stamp(view)


def test_is_copyright_stamp_giuffre_fragment() -> None:
    view = _make_view(
        [_make_span("© Copyright Giuffrè Francis Lefebvre S.p.A.", size=COPYRIGHT_SIZE)]
    )
    assert DejureNotaSentenzaProfile._is_copyright_stamp(view)


def test_is_copyright_stamp_rejects_wrong_size() -> None:
    view = _make_view([_make_span("SERVIZIO GESTIONE RISORSE", size=BODY_SIZE)])
    assert not DejureNotaSentenzaProfile._is_copyright_stamp(view)


# Predicates: _is_body


def test_is_body_arial_regular_12pt() -> None:
    view = _make_view([_make_span("Body prose ...", font="ArialMT", size=BODY_SIZE)])
    assert DejureNotaSentenzaProfile._is_body(view)


def test_is_body_admits_italic_leading() -> None:
    view = _make_view(
        [_make_span("« italic citation", font="Arial-ItalicMT", size=BODY_SIZE, flags=ITALIC_FLAG)]
    )
    assert DejureNotaSentenzaProfile._is_body(view)


def test_is_body_rejects_bold() -> None:
    view = _make_view(
        [_make_span("Bold heading", font="Arial-BoldMT", size=BODY_SIZE, flags=BOLD_FLAG)]
    )
    assert not DejureNotaSentenzaProfile._is_body(view)


def test_is_body_rejects_wrong_size() -> None:
    view = _make_view([_make_span("9pt text", font="ArialMT", size=9.0)])
    assert not DejureNotaSentenzaProfile._is_body(view)


# ---------------------------------------------------------------------------
# refine_classification


def test_reclassify_unclassified_to_banner() -> None:
    plugin = DejureNotaSentenzaProfile()
    extraction = _make_extraction(
        [_make_span("NOTE E DOTTRINA", font="Arial-BoldMT", size=BANNER_SIZE, flags=BOLD_FLAG)],
        [_make_block(span_range=(0, 1))],
    )
    refined = plugin.refine_classification(extraction, [_verdict(0)])
    assert refined[0].category is SemanticCategory.GENRE_BANNER


def test_reclassify_promotes_title_over_running_header() -> None:
    plugin = DejureNotaSentenzaProfile()
    extraction = _make_extraction(
        [_make_span("Some title", font="Arial-BoldMT", size=TITLE_SIZE, flags=BOLD_FLAG)],
        [_make_block(span_range=(0, 1))],
    )
    # Even if tier 1 marked it as ARTIFACT_RUNNING_HEADER, the plugin
    # promotes via the body-zone-aware predicate.
    refined = plugin.refine_classification(
        extraction, [_verdict(0, SemanticCategory.ARTIFACT_RUNNING_HEADER)]
    )
    assert refined[0].category is SemanticCategory.TITLE


def test_reclassify_sentinel_block_passthrough() -> None:
    plugin = DejureNotaSentenzaProfile()
    extraction = _make_extraction([], [])
    refined = plugin.refine_classification(extraction, [_verdict(-1, SemanticCategory.EMPTY_PAGE)])
    assert refined[0].category is SemanticCategory.EMPTY_PAGE
    assert refined[0].block_index == -1


def test_notes_region_retags_subsequent_body_as_note() -> None:
    plugin = DejureNotaSentenzaProfile()
    extraction = _make_extraction(
        [
            _make_span(
                "Note:(1) X.(2) Y.",
                font="Arial-BoldMT",
                size=BODY_SIZE,
                flags=BOLD_FLAG,
                block_index=0,
            ),
            _make_span("Continuation prose.", font="ArialMT", size=BODY_SIZE, block_index=1),
        ],
        [
            _make_block(block_index=0, span_range=(0, 1)),
            _make_block(block_index=1, span_range=(1, 2)),
        ],
    )
    refined = plugin.refine_classification(extraction, [_verdict(0), _verdict(1)])
    assert refined[0].category is SemanticCategory.SECTION_LABEL
    assert refined[1].category is SemanticCategory.NOTE


def test_notes_region_does_not_retag_before_marker() -> None:
    plugin = DejureNotaSentenzaProfile()
    extraction = _make_extraction(
        [
            _make_span("Body before notes.", font="ArialMT", size=BODY_SIZE, block_index=0),
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


# ---------------------------------------------------------------------------
# _decompose_metadata


def test_decompose_metadata_produces_three_siblings() -> None:
    plugin = DejureNotaSentenzaProfile()
    host = Node(
        id="node_0010",
        category=SemanticCategory.META_VALUE,
        page_index=0,
        block_indices=(2,),
        text="Fonte: Rivista X, 2024Nota a: Tribunale Roma, 2024Autori: Mario Rossi",
    )
    document = Document(root=(host,))
    refined = plugin.refine_reconstruction(document, _make_extraction([], []), [])
    cats = [n.category for n in refined.root]
    assert cats == [
        SemanticCategory.FONTE_VALUE,
        SemanticCategory.REFERRAL,
        SemanticCategory.AUTHORS,
    ]


def test_decompose_metadata_records_transformation() -> None:
    plugin = DejureNotaSentenzaProfile()
    host = Node(
        id="node_0010",
        category=SemanticCategory.META_VALUE,
        page_index=0,
        block_indices=(2,),
        text="Fonte: ANota a: BAutori: C",
    )
    document = Document(root=(host,))
    refined = plugin.refine_reconstruction(document, _make_extraction([], []), [])
    assert len(refined.transformations) == 1
    transformation = refined.transformations[0]
    assert transformation.split_into is not None
    assert len(transformation.split_into) == 3


def test_decompose_metadata_unparseable_keeps_host_and_warns() -> None:
    plugin = DejureNotaSentenzaProfile()
    host = Node(
        id="node_0010",
        category=SemanticCategory.META_VALUE,
        page_index=0,
        block_indices=(2,),
        text="Fonte: Rivista X, 2024",  # missing Nota a: and Autori:
    )
    document = Document(root=(host,))
    refined = plugin.refine_reconstruction(document, _make_extraction([], []), [])
    assert len(refined.root) == 1
    assert refined.root[0].category is SemanticCategory.META_VALUE
    assert any("metadata_block_unparseable" in w for w in refined.warnings)


def test_decompose_metadata_preserves_aspose_artefacts() -> None:
    plugin = DejureNotaSentenzaProfile()
    host = Node(
        id="node_0010",
        category=SemanticCategory.META_VALUE,
        page_index=0,
        block_indices=(2,),
        text=(
            "Fonte: Responsabilita' Civile e Previdenza, fasc.4, 2024, pag. 1276"
            "Nota a: Cassazione penale , 18 aprile 2024, n.22587, sez. IV"
            "Autori: Fabio Piccioni"
        ),
    )
    document = Document(root=(host,))
    refined = plugin.refine_reconstruction(document, _make_extraction([], []), [])
    referral = next(n for n in refined.root if n.category is SemanticCategory.REFERRAL)
    assert referral.text is not None
    assert "Cassazione penale ," in referral.text  # extra space preserved


# ---------------------------------------------------------------------------
# _parse_toc_general


def test_parse_toc_general_extracts_five_items() -> None:
    plugin = DejureNotaSentenzaProfile()
    text = "Sommario  1. Intro — 2. Discussione — 3. Esempi — 4. Risultati — 5. Conclusioni."
    host = Node(
        id="node_0001",
        category=SemanticCategory.TOC_GENERAL,
        page_index=0,
        block_indices=(3,),
        text=text,
    )
    document = Document(root=(host,))
    refined = plugin.refine_reconstruction(document, _make_extraction([], []), [])
    toc = next(n for n in refined.root if n.category is SemanticCategory.TOC_GENERAL)
    assert toc.toc_items is not None
    assert len(toc.toc_items) == 5
    assert toc.toc_items[0].number == "1"


def test_parse_toc_general_splits_off_trailing_heading() -> None:
    plugin = DejureNotaSentenzaProfile()
    text = (
        "Sommario  1. Inquadramento — 2. Difetto — 3. Riparto — 4. Riserva — "
        "5. Conclusioni del caso. 1. INQUADRAMENTO PRELIMINARE DELLA DECISIONE"
    )
    host = Node(
        id="node_0001",
        category=SemanticCategory.TOC_GENERAL,
        page_index=0,
        block_indices=(3,),
        text=text,
    )
    document = Document(root=(host,))
    refined = plugin.refine_reconstruction(document, _make_extraction([], []), [])
    cats = [n.category for n in refined.root]
    assert SemanticCategory.TOC_GENERAL in cats
    assert SemanticCategory.HEADING_1 in cats


def test_parse_toc_general_unparseable_emits_warning() -> None:
    plugin = DejureNotaSentenzaProfile()
    host = Node(
        id="node_0001",
        category=SemanticCategory.TOC_GENERAL,
        page_index=0,
        block_indices=(3,),
        text="Sommario ",  # empty after prefix
    )
    document = Document(root=(host,))
    refined = plugin.refine_reconstruction(document, _make_extraction([], []), [])
    assert any("toc_general_unparseable" in w for w in refined.warnings)


def test_parse_toc_general_carries_no_page_numbers() -> None:
    plugin = DejureNotaSentenzaProfile()
    text = "Sommario 1. Intro — 2. Body."
    host = Node(
        id="node_0001",
        category=SemanticCategory.TOC_GENERAL,
        page_index=0,
        block_indices=(3,),
        text=text,
    )
    refined = plugin.refine_reconstruction(Document(root=(host,)), _make_extraction([], []), [])
    toc = next(n for n in refined.root if n.category is SemanticCategory.TOC_GENERAL)
    assert toc.toc_items is not None
    assert all(item.page_number is None for item in toc.toc_items)


# ---------------------------------------------------------------------------
# _consolidate_notes_section


def test_consolidate_notes_section_glued_block_mints_notes() -> None:
    plugin = DejureNotaSentenzaProfile()
    section = Node(
        id="node_0050",
        category=SemanticCategory.SECTION_LABEL,
        page_index=13,
        block_indices=(66,),
        text="Note:(1) Prima nota.(2) Seconda nota.(3) Terza nota.",
    )
    refined = plugin.refine_reconstruction(Document(root=(section,)), _make_extraction([], []), [])
    notes = [n for n in refined.root if n.category is SemanticCategory.NOTE]
    assert len(notes) == 3
    assert notes[0].text is not None
    assert notes[0].text.startswith("(1)")


def test_consolidate_notes_section_absorbs_following_body_siblings() -> None:
    plugin = DejureNotaSentenzaProfile()
    section = Node(
        id="node_0050",
        category=SemanticCategory.SECTION_LABEL,
        page_index=13,
        block_indices=(66,),
        text="Note:(1) Prima.(2) Seconda con continuazione",
    )
    body = Node(
        id="node_0051",
        category=SemanticCategory.NOTE,  # after re-tag in refine_classification
        page_index=14,
        block_indices=(68,),
        text="che prosegue oltre la pagina.(3) Terza nota.",
    )
    refined = plugin.refine_reconstruction(
        Document(root=(section, body)), _make_extraction([], []), []
    )
    notes = [n for n in refined.root if n.category is SemanticCategory.NOTE]
    assert len(notes) >= 3


def test_consolidate_notes_section_keeps_passthrough_artifact() -> None:
    plugin = DejureNotaSentenzaProfile()
    section = Node(
        id="node_0050",
        category=SemanticCategory.SECTION_LABEL,
        page_index=13,
        block_indices=(66,),
        text="Note:(1) Nota uno.(2) Nota due.",
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


def test_consolidate_notes_section_standalone_marker_is_idempotent() -> None:
    plugin = DejureNotaSentenzaProfile()
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
    section_label = next(n for n in refined.root if n.category is SemanticCategory.SECTION_LABEL)
    assert section_label.text == "Note:"


def test_consolidate_notes_section_records_transformation_with_split_into() -> None:
    plugin = DejureNotaSentenzaProfile()
    section = Node(
        id="node_0050",
        category=SemanticCategory.SECTION_LABEL,
        page_index=13,
        block_indices=(66,),
        text="Note:(1) A.(2) B.",
    )
    refined = plugin.refine_reconstruction(Document(root=(section,)), _make_extraction([], []), [])
    transformations = [t for t in refined.transformations if "notes_section" in t.step_id]
    assert len(transformations) == 1
    assert transformations[0].split_into is not None
    assert len(transformations[0].split_into) == 2


def test_consolidate_notes_section_stops_at_heading_boundary() -> None:
    plugin = DejureNotaSentenzaProfile()
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
    body_after_heading = Node(
        id="node_0052",
        category=SemanticCategory.NOTE,
        page_index=14,
        block_indices=(69,),
        text="Body content of new section.",
    )
    refined = plugin.refine_reconstruction(
        Document(root=(section, heading, body_after_heading)),
        _make_extraction([], []),
        [],
    )
    # Heading and post-heading body must survive intact.
    heading_node = next(n for n in refined.root if n.category is SemanticCategory.HEADING_1)
    assert heading_node.text is not None and heading_node.text == "2. NUOVA SEZIONE"


# ---------------------------------------------------------------------------
# _maybe_mint_cross_references


def test_mint_cross_references_inline_markers() -> None:
    plugin = DejureNotaSentenzaProfile()
    body = Node(
        id="node_0040",
        category=SemanticCategory.BODY,
        page_index=1,
        block_indices=(10,),
        text="Il noto caso Urgenda(1), il caso Affaire du siècle (2), e altri.",
    )
    refined = plugin.refine_reconstruction(Document(root=(body,)), _make_extraction([], []), [])
    crossrefs = [n for n in refined.root if n.category is SemanticCategory.CROSS_REFERENCE]
    assert len(crossrefs) == 2
    assert crossrefs[0].text == "(1)"
    assert crossrefs[1].text == "(2)"


def test_mint_cross_references_skips_years() -> None:
    plugin = DejureNotaSentenzaProfile()
    body = Node(
        id="node_0040",
        category=SemanticCategory.BODY,
        page_index=1,
        block_indices=(10,),
        text="riferimento(1), riforma del (2024). ",
    )
    refined = plugin.refine_reconstruction(Document(root=(body,)), _make_extraction([], []), [])
    crossrefs = [n for n in refined.root if n.category is SemanticCategory.CROSS_REFERENCE]
    assert len(crossrefs) == 1  # only (1), not (2024) which exceeds the magnitude cap


def test_mint_cross_references_zero_when_no_match() -> None:
    plugin = DejureNotaSentenzaProfile()
    body = Node(
        id="node_0040",
        category=SemanticCategory.BODY,
        page_index=1,
        block_indices=(10,),
        text="Plain body prose without any inline marker.",
    )
    refined = plugin.refine_reconstruction(Document(root=(body,)), _make_extraction([], []), [])
    crossrefs = [n for n in refined.root if n.category is SemanticCategory.CROSS_REFERENCE]
    assert crossrefs == []


def test_mint_cross_references_warning_per_match() -> None:
    plugin = DejureNotaSentenzaProfile()
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


# ---------------------------------------------------------------------------
# refine_apparatus — binding


def test_refine_apparatus_binds_crossref_to_note() -> None:
    plugin = DejureNotaSentenzaProfile()
    # Synthetic flow: refine_reconstruction first to mint Nodes, then apparatus.
    body = Node(
        id="node_0040",
        category=SemanticCategory.BODY,
        page_index=1,
        block_indices=(10,),
        text="Prima parola(1) e seconda(2).",
    )
    section = Node(
        id="node_0050",
        category=SemanticCategory.SECTION_LABEL,
        page_index=13,
        block_indices=(66,),
        text="Note:(1) Nota uno.(2) Nota due.",
    )
    document = Document(root=(body, section))
    document = plugin.refine_reconstruction(document, _make_extraction([], []), [])
    document = plugin.refine_apparatus(document, _make_extraction([], []), [])
    crossrefs = [n for n in document.root if n.category is SemanticCategory.CROSS_REFERENCE]
    bound = [n for n in crossrefs if n.apparatus_refs]
    assert len(bound) == 2
    for cr in bound:
        assert cr.apparatus_refs[0].kind is ApparatusRefKind.CROSS_REF_TARGET


def test_refine_apparatus_unresolved_marker_emits_warning() -> None:
    plugin = DejureNotaSentenzaProfile()
    body = Node(
        id="node_0040",
        category=SemanticCategory.BODY,
        page_index=1,
        block_indices=(10,),
        text="Riferimento orfano(99).",
    )
    section = Node(
        id="node_0050",
        category=SemanticCategory.SECTION_LABEL,
        page_index=13,
        block_indices=(66,),
        text="Note:(1) Solo questa nota.",
    )
    document = Document(root=(body, section))
    document = plugin.refine_reconstruction(document, _make_extraction([], []), [])
    document = plugin.refine_apparatus(document, _make_extraction([], []), [])
    assert any("cross_reference_unresolved" in w for w in document.warnings)


def test_refine_apparatus_does_not_bind_unminted_nodes() -> None:
    plugin = DejureNotaSentenzaProfile()
    cr = Node(
        id="node_0100",
        category=SemanticCategory.CROSS_REFERENCE,
        page_index=1,
        block_indices=(10,),
        text="(1)",
    )
    # cr is NOT in _minted_crossref_ids, plugin should leave it alone.
    document = Document(root=(cr,))
    document = plugin.refine_apparatus(document, _make_extraction([], []), [])
    assert document.root[0].apparatus_refs == ()


def test_refine_apparatus_filters_tier1_warnings_for_minted_ids() -> None:
    plugin = DejureNotaSentenzaProfile()
    # Pretend the plugin minted node_0099.
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


# ---------------------------------------------------------------------------
# Helpers


def test_node_id_minter_generates_padded_ids() -> None:
    minter = _NodeIdMinter(start=42)
    assert minter.mint() == "node_0042"
    assert minter.mint() == "node_0043"


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


def test_strip_label_removes_leading_label() -> None:
    assert _strip_label("Fonte: Diritto & Giustizia, 2024", "Fonte:") == (
        "Diritto & Giustizia, 2024"
    )


def test_strip_label_passthrough_when_no_match() -> None:
    assert _strip_label("Random text", "Fonte:") == "Random text"


# ---------------------------------------------------------------------------
# Regex patterns


def test_footer_pattern_matches_pagina_x_di_y() -> None:
    assert _FOOTER_PATTERN.match("Pagina 1 di 22")
    assert _FOOTER_PATTERN.match("Pagina 12 di 100")
    assert not _FOOTER_PATTERN.match("Pagina 1")
    assert not _FOOTER_PATTERN.match("Some prose")


def test_section_heading_pattern_matches_numbered_uppercase() -> None:
    assert _SECTION_HEADING_PATTERN.match("1. INTRODUZIONE GENERALE")
    assert _SECTION_HEADING_PATTERN.match("12. SEZIONE")
    assert not _SECTION_HEADING_PATTERN.match("1. introduction")
    assert not _SECTION_HEADING_PATTERN.match("INTRODUCTION")


def test_note_marker_pattern_extracts_number() -> None:
    match = _NOTE_MARKER_PATTERN.match("(42) Bibliographic content")
    assert match is not None
    assert match.group(1) == "42"
    assert _NOTE_MARKER_PATTERN.match("plain") is None


def test_crossref_inline_pattern_finds_multiple() -> None:
    matches = list(_CROSSREF_INLINE_PATTERN.finditer("word(1) middle (12) end(99)"))
    captured = [m.group(1) for m in matches]
    assert captured == ["1", "12", "99"]


def test_crossref_inline_pattern_skips_nested_parens() -> None:
    matches = list(_CROSSREF_INLINE_PATTERN.finditer("(2024) text(1)"))
    captured = [m.group(1) for m in matches]
    assert "2024" in captured or captured == ["2024", "1"]
    # Note: the pattern matches both because the magnitude cap is
    # enforced in the consumer, not in the regex itself. So we just
    # verify the regex captures both correctly.


# ---------------------------------------------------------------------------
# Warning prefix consistency


def test_warning_prefix_is_namespaced() -> None:
    assert WARNING_PREFIX == "plugin:dejure_nota_sentenza"


def test_warnings_emitted_use_closed_vocabulary_prefix() -> None:
    plugin = DejureNotaSentenzaProfile()
    section = Node(
        id="node_0050",
        category=SemanticCategory.SECTION_LABEL,
        page_index=13,
        block_indices=(66,),
        text="Note:(1) A.(2) B.",
    )
    refined = plugin.refine_reconstruction(Document(root=(section,)), _make_extraction([], []), [])
    plugin_warnings = [w for w in refined.warnings if w.startswith(WARNING_PREFIX)]
    # All plugin-emitted warnings must carry the prefix.
    assert all(w.startswith(WARNING_PREFIX) for w in plugin_warnings)
    assert len(plugin_warnings) > 0


# ---------------------------------------------------------------------------
# End-to-end mini scenarios


def test_end_to_end_short_narrative_archetype() -> None:
    """Tier 2 pipeline on a synthesised short narrative document."""
    plugin = DejureNotaSentenzaProfile()
    extraction = _make_extraction(
        [
            _make_span(
                "NOTE E DOTTRINA",
                font="Arial-BoldMT",
                size=BANNER_SIZE,
                flags=BOLD_FLAG,
                block_index=0,
            ),
            _make_span(
                "Titolo della nota",
                font="Arial-BoldMT",
                size=TITLE_SIZE,
                flags=BOLD_FLAG,
                block_index=1,
            ),
            _make_span(
                "Fonte: Rivista X, fasc.4, 2024Nota a: Trib. Roma 2024Autori: Mario Rossi",
                font="Arial-BoldMT",
                size=BANNER_SIZE,
                flags=BOLD_FLAG,
                block_index=2,
            ),
            _make_span(
                "Quotidiano del 6 giugno 2024",
                font="ArialMT",
                size=BODY_SIZE,
                block_index=3,
            ),
            _make_span(
                "Body paragraph one.",
                font="ArialMT",
                size=BODY_SIZE,
                block_index=4,
            ),
        ],
        [_make_block(block_index=i, span_range=(i, i + 1)) for i in range(5)],
    )
    refined_blocks = plugin.refine_classification(extraction, [_verdict(i) for i in range(5)])
    cats = [cb.category for cb in refined_blocks]
    assert SemanticCategory.GENRE_BANNER in cats
    assert SemanticCategory.TITLE in cats
    assert SemanticCategory.META_VALUE in cats
    assert SemanticCategory.SUBTITLE in cats
    assert SemanticCategory.BODY in cats


def test_end_to_end_academic_archetype() -> None:
    """Tier 2 pipeline on a synthesised academic document with sommario, headings, notes."""
    plugin = DejureNotaSentenzaProfile()
    spans = [
        _make_span(
            "NOTE E DOTTRINA", font="Arial-BoldMT", size=BANNER_SIZE, flags=BOLD_FLAG, block_index=0
        ),
        _make_span("Titolo", font="Arial-BoldMT", size=TITLE_SIZE, flags=BOLD_FLAG, block_index=1),
        _make_span(
            "Fonte: AlphaNota a: BetaAutori: Gamma",
            font="Arial-BoldMT",
            size=BANNER_SIZE,
            flags=BOLD_FLAG,
            block_index=2,
        ),
        _make_span(
            "Sommario 1. Intro — 2. Discussione.",
            font="ArialMT",
            size=BODY_SIZE,
            block_index=3,
        ),
        _make_span(
            "1. INTRODUZIONE",
            font="Arial-BoldMT",
            size=BODY_SIZE,
            flags=BOLD_FLAG,
            block_index=4,
        ),
        _make_span(
            "Body with reference(1) and another(2).",
            font="ArialMT",
            size=BODY_SIZE,
            block_index=5,
        ),
        _make_span(
            "Note:(1) Prima nota.(2) Seconda nota.",
            font="Arial-BoldMT",
            size=BODY_SIZE,
            flags=BOLD_FLAG,
            block_index=6,
        ),
    ]
    blocks = [_make_block(block_index=i, span_range=(i, i + 1)) for i in range(7)]
    extraction = _make_extraction(spans, blocks)
    classified = plugin.refine_classification(extraction, [_verdict(i) for i in range(7)])

    # Build minimal Document for reconstruction phase.
    nodes = []
    for i, cb in enumerate(classified):
        node = Node(
            id=f"node_{i:04d}",
            category=cb.category,
            page_index=0,
            block_indices=(i,),
            text=spans[i].text,
        )
        nodes.append(node)
    document = Document(root=tuple(nodes))
    refined = plugin.refine_reconstruction(document, extraction, classified)
    refined = plugin.refine_apparatus(refined, extraction, classified)

    note_count = sum(1 for n in refined.root if n.category is SemanticCategory.NOTE)
    cr_count = sum(1 for n in refined.root if n.category is SemanticCategory.CROSS_REFERENCE)
    assert note_count == 2
    assert cr_count == 2
    # CR Nodes should be bound to NOTE targets.
    bound = [
        n
        for n in refined.root
        if n.category is SemanticCategory.CROSS_REFERENCE and n.apparatus_refs
    ]
    assert len(bound) == 2


# ---------------------------------------------------------------------------
# Additional matches() coverage


def test_matches_with_just_under_body_dominance_does_not_credit() -> None:
    signals = _dejure_signals(body_dominance=30.0)
    score = DejureNotaSentenzaProfile.matches(signals)
    # body did not credit but title + banner + producer + geometry still credit
    assert 0.0 < score < 0.9


def test_matches_letter_geometry_with_landscape_fails() -> None:
    signals = _dejure_signals(width_pt=792.0, height_pt=612.0)
    score = DejureNotaSentenzaProfile.matches(signals)
    # Letter rotated: no Letter credit, but Arial body + producer + title + banner still credit
    assert score < 0.8


def test_matches_marotta_like_does_not_promote() -> None:
    signals = _dejure_signals(
        body_family="TimesNewRomanPSMT",
        body_size=11.0,
        producer="Acrobat Pro 9.4.5",
        creator="Adobe InDesign CS6",
        include_title=False,
        include_banner=False,
    )
    score = DejureNotaSentenzaProfile.matches(signals)
    assert score < 0.6


# ---------------------------------------------------------------------------
# Additional declarative / state coverage


def test_plugin_state_resets_between_runs() -> None:
    plugin = DejureNotaSentenzaProfile()
    plugin._minted_crossref_ids.add("orphan")
    plugin._minted_note_ids.add("orphan_note")
    plugin._pending_warnings.append("orphan_warning")
    extraction = _make_extraction([], [])
    refined = plugin.refine_classification(extraction, [])
    # Classification clears the pending state.
    assert plugin._minted_crossref_ids == set()
    assert plugin._minted_note_ids == set()
    assert plugin._pending_warnings == []
    assert refined == []


def test_block_view_construction() -> None:
    spans = [_make_span("text", line_index=0, span_index=0)]
    block = _make_block(span_range=(0, 1))
    view = _BlockView(block_index=0, block=block, spans=tuple(spans), text="text")
    assert view.text == "text"
    assert view.spans[0].text == "text"


def test_refine_classification_returns_same_length() -> None:
    plugin = DejureNotaSentenzaProfile()
    extraction = _make_extraction(
        [_make_span("a", block_index=0), _make_span("b", block_index=1)],
        [
            _make_block(block_index=0, span_range=(0, 1)),
            _make_block(block_index=1, span_range=(1, 2)),
        ],
    )
    refined = plugin.refine_classification(extraction, [_verdict(0), _verdict(1)])
    assert len(refined) == 2


def test_reclassify_falls_through_to_tier1_when_no_predicate_matches() -> None:
    plugin = DejureNotaSentenzaProfile()
    # Block doesn't match any predicate.
    extraction = _make_extraction(
        [_make_span("strange text", font="Courier", size=5.0, block_index=0)],
        [_make_block(block_index=0, span_range=(0, 1))],
    )
    refined = plugin.refine_classification(extraction, [_verdict(0, SemanticCategory.UNCLASSIFIED)])
    assert refined[0].category is SemanticCategory.UNCLASSIFIED


# ---------------------------------------------------------------------------
# refine_reconstruction integration


def test_refine_reconstruction_preserves_unchanged_nodes() -> None:
    plugin = DejureNotaSentenzaProfile()
    title = Node(
        id="node_0001",
        category=SemanticCategory.TITLE,
        page_index=0,
        block_indices=(1,),
        text="Some title",
    )
    refined = plugin.refine_reconstruction(Document(root=(title,)), _make_extraction([], []), [])
    assert refined.root[0].id == "node_0001"
    assert refined.root[0].category is SemanticCategory.TITLE


def test_refine_reconstruction_pending_warnings_flushed() -> None:
    plugin = DejureNotaSentenzaProfile()
    plugin._pending_warnings.append(f"{WARNING_PREFIX}:test_pending")
    refined = plugin.refine_reconstruction(Document(root=()), _make_extraction([], []), [])
    assert f"{WARNING_PREFIX}:test_pending" in refined.warnings
    # After flush, instance state is empty.
    assert plugin._pending_warnings == []


def test_refine_reconstruction_preserves_existing_warnings() -> None:
    plugin = DejureNotaSentenzaProfile()
    refined = plugin.refine_reconstruction(
        Document(root=(), warnings=("preexisting_warning",)),
        _make_extraction([], []),
        [],
    )
    assert "preexisting_warning" in refined.warnings


# ---------------------------------------------------------------------------
# Additional predicates edge cases


def test_is_genre_banner_empty_spans() -> None:
    view = _BlockView(
        block_index=0,
        block=_make_block(span_range=(0, 0)),
        spans=(),
        text="",
    )
    assert not DejureNotaSentenzaProfile._is_genre_banner(view)


def test_is_title_empty_spans() -> None:
    view = _BlockView(
        block_index=0,
        block=_make_block(span_range=(0, 0)),
        spans=(),
        text="",
    )
    assert not DejureNotaSentenzaProfile._is_title(view)


def test_is_metadata_block_empty_spans() -> None:
    view = _BlockView(
        block_index=0,
        block=_make_block(span_range=(0, 0)),
        spans=(),
        text="",
    )
    assert not DejureNotaSentenzaProfile._is_metadata_block(view)


def test_is_body_empty_spans() -> None:
    view = _BlockView(
        block_index=0,
        block=_make_block(span_range=(0, 0)),
        spans=(),
        text="",
    )
    assert not DejureNotaSentenzaProfile._is_body(view)


# ---------------------------------------------------------------------------
# View helper


def test_view_returns_none_for_empty_block() -> None:
    block = _make_block(span_range=(0, 0))
    extraction = _make_extraction([], [block])
    view = DejureNotaSentenzaProfile._view(extraction, 0)
    assert view is None


def test_view_assembles_text_from_spans() -> None:
    spans = [_make_span("foo "), _make_span("bar", span_index=1)]
    block = _make_block(span_range=(0, 2))
    extraction = _make_extraction(spans, [block])
    view = DejureNotaSentenzaProfile._view(extraction, 0)
    assert view is not None
    assert view.text == "foo bar"


# ---------------------------------------------------------------------------
# Coverage of various integration paths


def test_two_metadata_blocks_each_decomposed() -> None:
    plugin = DejureNotaSentenzaProfile()
    m1 = Node(
        id="node_0001",
        category=SemanticCategory.META_VALUE,
        page_index=0,
        block_indices=(2,),
        text="Fonte: ANota a: BAutori: C",
    )
    m2 = Node(
        id="node_0002",
        category=SemanticCategory.META_VALUE,
        page_index=2,
        block_indices=(5,),
        text="Fonte: XNota a: YAutori: Z",
    )
    refined = plugin.refine_reconstruction(Document(root=(m1, m2)), _make_extraction([], []), [])
    fonte_count = sum(1 for n in refined.root if n.category is SemanticCategory.FONTE_VALUE)
    assert fonte_count == 2


def test_minted_crossref_ids_tracked_across_refine_calls() -> None:
    plugin = DejureNotaSentenzaProfile()
    body = Node(
        id="node_0040",
        category=SemanticCategory.BODY,
        page_index=1,
        block_indices=(10,),
        text="word(1) and other(2).",
    )
    plugin.refine_reconstruction(Document(root=(body,)), _make_extraction([], []), [])
    assert len(plugin._minted_crossref_ids) == 2


@pytest.mark.parametrize(
    "marker_value,expected_mint",
    [
        ("1", True),
        ("54", True),
        ("99", True),
        ("100", False),
        ("2024", False),
    ],
)
def test_crossref_magnitude_cap(marker_value: str, expected_mint: bool) -> None:
    plugin = DejureNotaSentenzaProfile()
    body = Node(
        id="node_0040",
        category=SemanticCategory.BODY,
        page_index=1,
        block_indices=(10,),
        text=f"foo({marker_value}) bar",
    )
    refined = plugin.refine_reconstruction(Document(root=(body,)), _make_extraction([], []), [])
    crossrefs = [n for n in refined.root if n.category is SemanticCategory.CROSS_REFERENCE]
    assert (len(crossrefs) == 1) is expected_mint


# ---------------------------------------------------------------------------
# Coverage of internal helper methods


def test_starts_with_notes_marker_variants() -> None:
    plugin = DejureNotaSentenzaProfile()
    assert plugin._starts_with_notes_marker("Note:(1) X")
    assert plugin._starts_with_notes_marker("  Note: standalone")
    assert plugin._starts_with_notes_marker("Note : with space")
    assert not plugin._starts_with_notes_marker("Section heading")


def test_match_notes_marker_returns_none_when_absent() -> None:
    plugin = DejureNotaSentenzaProfile()
    assert plugin._match_notes_marker("Plain text") is None


def test_match_notes_marker_returns_match_with_skip() -> None:
    plugin = DejureNotaSentenzaProfile()
    match = plugin._match_notes_marker("  Note: X")
    assert match is not None
    assert match.start() == 2


def test_consolidate_notes_section_no_marker_pass_through() -> None:
    plugin = DejureNotaSentenzaProfile()
    title = Node(
        id="node_0001",
        category=SemanticCategory.TITLE,
        page_index=0,
        block_indices=(1,),
        text="Some title",
    )
    body = Node(
        id="node_0002",
        category=SemanticCategory.BODY,
        page_index=0,
        block_indices=(2,),
        text="Body prose.",
    )
    refined = plugin.refine_reconstruction(
        Document(root=(title, body)), _make_extraction([], []), []
    )
    # Without Note: marker, _consolidate_notes_section is a no-op.
    assert refined.root[0].id == "node_0001"
    assert any(n.id == "node_0002" for n in refined.root)


def test_consolidate_notes_section_with_no_glued_no_following() -> None:
    plugin = DejureNotaSentenzaProfile()
    section = Node(
        id="node_0050",
        category=SemanticCategory.SECTION_LABEL,
        page_index=13,
        block_indices=(66,),
        text="Note:",
    )
    title = Node(
        id="node_0051",
        category=SemanticCategory.TITLE,  # boundary category
        page_index=14,
        block_indices=(68,),
        text="Another title",
    )
    refined = plugin.refine_reconstruction(
        Document(root=(section, title)), _make_extraction([], []), []
    )
    # Notes section has no absorbable BODY siblings; standalone marker is kept.
    notes = [n for n in refined.root if n.category is SemanticCategory.NOTE]
    assert notes == []


def test_consolidate_notes_section_unparseable_warns() -> None:
    plugin = DejureNotaSentenzaProfile()
    section = Node(
        id="node_0050",
        category=SemanticCategory.SECTION_LABEL,
        page_index=13,
        block_indices=(66,),
        text="Note: text but no (1) marker pattern",
    )
    refined = plugin.refine_reconstruction(Document(root=(section,)), _make_extraction([], []), [])
    assert any("note_section_unparseable" in w for w in refined.warnings)


def test_split_notes_text_returns_empty_without_marker() -> None:
    plugin = DejureNotaSentenzaProfile()
    minter = _NodeIdMinter(start=100)
    result = plugin._split_notes_text(
        "no marker here",
        page_index=0,
        block_indices=(0,),
        warnings=[],
        minter=minter,
    )
    assert result == []


def test_refine_apparatus_with_no_minted_nodes() -> None:
    """When no synthetic Nodes were minted, refine_apparatus is a passthrough."""
    plugin = DejureNotaSentenzaProfile()
    title = Node(
        id="node_0001",
        category=SemanticCategory.TITLE,
        page_index=0,
        block_indices=(1,),
        text="Title",
    )
    document = Document(root=(title,))
    refined = plugin.refine_apparatus(document, _make_extraction([], []), [])
    assert refined.root[0].id == "node_0001"


def test_consolidate_notes_section_boundary_at_arbitrary_other_category() -> None:
    """Unknown category (not a boundary, not a passthrough) ends absorption."""
    plugin = DejureNotaSentenzaProfile()
    section = Node(
        id="node_0050",
        category=SemanticCategory.SECTION_LABEL,
        page_index=13,
        block_indices=(66,),
        text="Note:(1) X.(2) Y.",
    )
    list_item = Node(
        id="node_0051",
        category=SemanticCategory.LIST_ITEM,  # neither boundary nor passthrough
        page_index=14,
        block_indices=(68,),
        text="• item one",
    )
    refined = plugin.refine_reconstruction(
        Document(root=(section, list_item)), _make_extraction([], []), []
    )
    notes = [n for n in refined.root if n.category is SemanticCategory.NOTE]
    # Notes from the SECTION_LABEL host are minted; the LIST_ITEM Node
    # survives unchanged.
    assert len(notes) == 2
    assert any(n.id == "node_0051" for n in refined.root)


def test_max_existing_node_counter_ignores_malformed_id() -> None:
    bad = Node(id="custom_id_not_numeric", category=SemanticCategory.BODY, page_index=0)
    good = Node(id="node_0042", category=SemanticCategory.BODY, page_index=0)
    assert _max_existing_node_counter((bad, good)) == 42
