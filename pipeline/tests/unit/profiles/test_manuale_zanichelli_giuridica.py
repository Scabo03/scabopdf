"""Unit tests for the manuale_zanichelli_giuridica corpus plugin."""

from __future__ import annotations

from typing import ClassVar

import pytest

from scabopdf_pipeline.classification.types import ClassifiedBlock
from scabopdf_pipeline.extraction.types import Block, ExtractionResult, Span
from scabopdf_pipeline.profiles.manuale_zanichelli_giuridica import (
    BODY_DOMINANCE_MIN_PERCENT,
    BODY_FONT_SIZE,
    CHAPTER_HEADING_FONT,
    CHAPTER_HEADING_SIZE,
    EN_DASH,
    EXPECTED_PAGE_HEIGHT,
    EXPECTED_PAGE_WIDTH,
    PARAGRAPH_HEADING_FONT,
    PARAGRAPH_HEADING_SIZE,
    SUMMARY_FONT_SIZE,
    WARNING_PREFIX,
    ManualeZanichelliGiuridicaProfile,
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
from scabopdf_pipeline.reconstruction.types import Document, Node, SummaryItem
from scabopdf_pipeline.schema.categories import SemanticCategory

DASH = f" {EN_DASH} "
"""Standard ``EN DASH`` separator used in Patriarca chapter summaries."""


# ---------------------------------------------------------------------------
# Helpers


def _patriarca_signals(
    *,
    body_dominance: float = 81.0,
    include_summary: bool = True,
    producer: str | None = "",
    creator: str | None = "",
    width_pt: float = EXPECTED_PAGE_WIDTH,
    height_pt: float = EXPECTED_PAGE_HEIGHT,
    has_outline: bool = False,
) -> ProfilingSignals:
    fonts = [
        FontDominance(
            family="TimesNewRomanPSMT",
            size=BODY_FONT_SIZE,
            dominance_percent=body_dominance,
        ),
    ]
    if include_summary:
        fonts.append(
            FontDominance(
                family="Helvetica-Light",
                size=SUMMARY_FONT_SIZE,
                dominance_percent=2.0,
            )
        )
    return ProfilingSignals(
        typographic_signature=TypographicSignature(fonts=fonts),
        apparatus_presence=ApparatusPresence(),
        page_geometry=ProfilePageGeometry(width_pt=width_pt, height_pt=height_pt),
        producer_creator=ProducerCreator(producer=producer, creator=creator),
        outline_structure=OutlineStructure(has_outline=has_outline),
    )


class _SpanBuilder:
    """Helper to build a list of ``Span`` objects with reasonable defaults."""

    def __init__(self) -> None:
        self._spans: list[Span] = []

    def add(
        self,
        text: str,
        *,
        font: str,
        size: float,
        page: int = 0,
        flags: int = 0,
        color: int = 0,
        bbox: tuple[float, float, float, float] = (0.0, 0.0, 100.0, 10.0),
        block_index: int = 0,
        line_index: int = 0,
    ) -> _SpanBuilder:
        span = Span(
            text=text,
            font=font,
            size=size,
            flags=flags,
            color=color,
            bbox=bbox,
            page=page,
            block_index=block_index,
            line_index=line_index,
            span_index=len(self._spans),
        )
        self._spans.append(span)
        return self

    def build(self) -> list[Span]:
        return list(self._spans)


def _make_block(
    page: int,
    span_range: tuple[int, int],
    bbox: tuple[float, float, float, float] = (34.0, 120.0, 450.0, 200.0),
    block_index: int = 0,
) -> Block:
    return Block(page=page, block_index=block_index, bbox=bbox, span_range=span_range)


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


# ---------------------------------------------------------------------------
# Class attributes


def test_class_attributes() -> None:
    assert ManualeZanichelliGiuridicaProfile.profile_id == "manuale_zanichelli_giuridica"
    assert ManualeZanichelliGiuridicaProfile.editorial_family == "zanichelli"
    assert ManualeZanichelliGiuridicaProfile.genre == "manuale_giuridico"


# ---------------------------------------------------------------------------
# matches()


def test_matches_full_patriarca_fingerprint_clears_threshold() -> None:
    score = ManualeZanichelliGiuridicaProfile.matches(_patriarca_signals())
    assert score == pytest.approx(0.9)
    assert score >= 0.6


def test_matches_misses_when_body_not_dominant() -> None:
    signals = _patriarca_signals(body_dominance=BODY_DOMINANCE_MIN_PERCENT - 5.0)
    score = ManualeZanichelliGiuridicaProfile.matches(signals)
    assert score == pytest.approx(0.4)
    assert score < 0.6


def test_matches_misses_when_summary_font_absent() -> None:
    signals = _patriarca_signals(include_summary=False)
    score = ManualeZanichelliGiuridicaProfile.matches(signals)
    assert score == pytest.approx(0.7)
    assert score >= 0.6


def test_matches_with_only_body_marker_clears_threshold() -> None:
    """Body dominance alone is not enough to clear 0.6: it's worth exactly 0.5."""
    signals = _patriarca_signals(
        include_summary=False,
        producer="SomeDTP",
        creator="SomeCreator",
        width_pt=500.0,
        height_pt=700.0,
        has_outline=True,
    )
    score = ManualeZanichelliGiuridicaProfile.matches(signals)
    assert score == pytest.approx(0.5)
    assert score < 0.6


def test_matches_returns_zero_on_unrelated_document() -> None:
    fonts = [
        FontDominance(family="Verdana", size=10.85, dominance_percent=50.0),
    ]
    signals = ProfilingSignals(
        typographic_signature=TypographicSignature(fonts=fonts),
        apparatus_presence=ApparatusPresence(),
        page_geometry=ProfilePageGeometry(width_pt=595.0, height_pt=842.0),
        producer_creator=ProducerCreator(producer="iLovePDF", creator="iLovePDF"),
        outline_structure=OutlineStructure(has_outline=True, entries_count=1562),
    )
    assert ManualeZanichelliGiuridicaProfile.matches(signals) == 0.0


# ---------------------------------------------------------------------------
# Declarative methods


def test_get_categories_is_closed_superset() -> None:
    plugin = ManualeZanichelliGiuridicaProfile()
    categories = plugin.get_categories()
    expected = {
        SemanticCategory.HEADING_1,
        SemanticCategory.HEADING_2,
        SemanticCategory.HEADING_3,
        SemanticCategory.BODY,
        SemanticCategory.CHAPTER_SUMMARY,
        SemanticCategory.UNCLASSIFIED,
        SemanticCategory.ARTIFACT_FILIGREE,
        SemanticCategory.ARTIFACT_RUNNING_HEADER,
        SemanticCategory.ARTIFACT_FOOTER,
        SemanticCategory.BOOK_PAGE_ANCHOR,
        SemanticCategory.CROSS_REFERENCE,
        SemanticCategory.EMPTY_PAGE,
    }
    assert categories == expected
    # No apparatus categories: Patriarca has none.
    forbidden = {
        SemanticCategory.NOTE,
        SemanticCategory.MARGINAL_HEADING,
        SemanticCategory.MARGINAL_GLOSS,
        SemanticCategory.EXAMPLE_BOX,
    }
    assert categories.isdisjoint(forbidden)


def test_get_post_processing_is_empty() -> None:
    plugin = ManualeZanichelliGiuridicaProfile()
    assert plugin.get_post_processing() == []


def test_get_layouts_disabled_disables_L4_only() -> None:
    plugin = ManualeZanichelliGiuridicaProfile()
    disabled = plugin.get_layouts_disabled()
    assert len(disabled) == 1
    entry = disabled[0]
    assert isinstance(entry, DisabledLayout)
    assert entry.layout == "L4"
    assert "Layout 4" in entry.reason
    assert "note" in entry.reason.lower()


# ---------------------------------------------------------------------------
# refine_classification()


def test_refine_classification_promotes_heading_1() -> None:
    spans = (
        _SpanBuilder()
        .add("Capitolo I", font=CHAPTER_HEADING_FONT, size=CHAPTER_HEADING_SIZE)
        .build()
    )
    block = _make_block(page=20, span_range=(0, 1))
    extraction = _make_extraction(spans, [block])
    tier1 = [
        ClassifiedBlock(block_index=0, category=SemanticCategory.UNCLASSIFIED, reason="no_match")
    ]
    plugin = ManualeZanichelliGiuridicaProfile()
    refined = plugin.refine_classification(extraction, tier1)
    assert refined[0].category is SemanticCategory.HEADING_1
    assert refined[0].reason == "zanichelli_heading_1_chapter"


def test_refine_classification_promotes_heading_2_section() -> None:
    spans = (
        _SpanBuilder()
        .add("Sezione A", font=CHAPTER_HEADING_FONT, size=CHAPTER_HEADING_SIZE)
        .build()
    )
    block = _make_block(page=295, span_range=(0, 1))
    extraction = _make_extraction(spans, [block])
    tier1 = [
        ClassifiedBlock(block_index=0, category=SemanticCategory.UNCLASSIFIED, reason="no_match")
    ]
    refined = ManualeZanichelliGiuridicaProfile().refine_classification(extraction, tier1)
    assert refined[0].category is SemanticCategory.HEADING_2
    assert refined[0].reason == "zanichelli_heading_2_section"


def test_refine_classification_promotes_heading_3_paragraph() -> None:
    spans = (
        _SpanBuilder()
        .add(
            "3. Le forme del trasferimento",
            font=PARAGRAPH_HEADING_FONT,
            size=PARAGRAPH_HEADING_SIZE,
        )
        .build()
    )
    block = _make_block(page=50, span_range=(0, 1))
    extraction = _make_extraction(spans, [block])
    tier1 = [
        ClassifiedBlock(block_index=0, category=SemanticCategory.UNCLASSIFIED, reason="no_match")
    ]
    refined = ManualeZanichelliGiuridicaProfile().refine_classification(extraction, tier1)
    assert refined[0].category is SemanticCategory.HEADING_3
    assert refined[0].reason == "zanichelli_heading_3_paragraph"


def test_refine_classification_promotes_chapter_summary_via_helvetica() -> None:
    spans = (
        _SpanBuilder()
        .add("Sommario  ", font="Helvetica-Bold", size=SUMMARY_FONT_SIZE)
        .add(
            f"1. L'impresa e l'imprenditore{DASH}2. La nozione di imprenditore",
            font="Helvetica-Light",
            size=SUMMARY_FONT_SIZE,
        )
        .build()
    )
    block = _make_block(page=20, span_range=(0, 2))
    extraction = _make_extraction(spans, [block])
    tier1 = [
        ClassifiedBlock(block_index=0, category=SemanticCategory.UNCLASSIFIED, reason="no_match")
    ]
    refined = ManualeZanichelliGiuridicaProfile().refine_classification(extraction, tier1)
    assert refined[0].category is SemanticCategory.CHAPTER_SUMMARY
    assert refined[0].reason == "zanichelli_summary_helvetica_9pt"


def test_refine_classification_promotes_body() -> None:
    spans = (
        _SpanBuilder()
        .add(
            "L'impresa è un'attività economica esercitata professionalmente.",
            font="TimesNewRomanPSMT",
            size=BODY_FONT_SIZE,
        )
        .build()
    )
    block = _make_block(page=20, span_range=(0, 1))
    extraction = _make_extraction(spans, [block])
    tier1 = [
        ClassifiedBlock(block_index=0, category=SemanticCategory.UNCLASSIFIED, reason="no_match")
    ]
    refined = ManualeZanichelliGiuridicaProfile().refine_classification(extraction, tier1)
    assert refined[0].category is SemanticCategory.BODY
    assert refined[0].reason == "zanichelli_body"


def test_refine_classification_preserves_tier1_artifacts() -> None:
    """Verdicts already assigned by tier 1 are never overridden."""
    spans = (
        _SpanBuilder()
        .add(
            "30 | Diritto delle imprese",
            font="TimesNewRomanPSMT",
            size=BODY_FONT_SIZE,
        )
        .build()
    )
    block = _make_block(page=29, span_range=(0, 1), bbox=(34.0, 30.0, 450.0, 45.0))
    extraction = _make_extraction(spans, [block])
    tier1 = [
        ClassifiedBlock(
            block_index=0,
            category=SemanticCategory.ARTIFACT_RUNNING_HEADER,
            reason="header_zone",
        )
    ]
    refined = ManualeZanichelliGiuridicaProfile().refine_classification(extraction, tier1)
    assert refined[0].category is SemanticCategory.ARTIFACT_RUNNING_HEADER
    assert refined[0].reason == "header_zone"


def test_refine_classification_preserves_sentinels() -> None:
    """Synthetic ``EMPTY_PAGE`` sentinels (block_index = -1) are passed through."""
    extraction = _make_extraction([], [])
    tier1 = [
        ClassifiedBlock(
            block_index=-1,
            category=SemanticCategory.EMPTY_PAGE,
            subcategory="3",
            reason="empty_page",
        )
    ]
    refined = ManualeZanichelliGiuridicaProfile().refine_classification(extraction, tier1)
    assert refined == tier1


def test_refine_classification_emits_warning_for_unmatched_19pt_block() -> None:
    """A 19pt block whose text matches neither Capitolo nor Sezione triggers a warning."""
    spans = (
        _SpanBuilder()
        .add("Titolo strano", font=CHAPTER_HEADING_FONT, size=CHAPTER_HEADING_SIZE)
        .build()
    )
    block = _make_block(page=42, span_range=(0, 1))
    extraction = _make_extraction(spans, [block])
    tier1 = [
        ClassifiedBlock(block_index=0, category=SemanticCategory.UNCLASSIFIED, reason="no_match")
    ]
    plugin = ManualeZanichelliGiuridicaProfile()
    refined = plugin.refine_classification(extraction, tier1)
    # The block stays UNCLASSIFIED — the plugin will not commit to HEADING_*
    # when the text pattern fails.
    assert refined[0].category is SemanticCategory.UNCLASSIFIED
    # The warning is queued for the next reconstruction pass.
    document = plugin.refine_reconstruction(Document(), extraction, refined)
    assert f"{WARNING_PREFIX}:heading_19pt_pattern_unmatched_block_0_page_42" in document.warnings


def test_refine_classification_drops_long_chapter_candidates() -> None:
    """A block sharing the 19pt signature but too long is not promoted to H1."""
    long_text = "Capitolo I " + ("very long body text " * 20)
    spans = (
        _SpanBuilder().add(long_text, font=CHAPTER_HEADING_FONT, size=CHAPTER_HEADING_SIZE).build()
    )
    block = _make_block(page=10, span_range=(0, 1))
    extraction = _make_extraction(spans, [block])
    tier1 = [
        ClassifiedBlock(block_index=0, category=SemanticCategory.UNCLASSIFIED, reason="no_match")
    ]
    refined = ManualeZanichelliGiuridicaProfile().refine_classification(extraction, tier1)
    assert refined[0].category is SemanticCategory.UNCLASSIFIED


def test_refine_classification_drops_long_paragraph_candidates() -> None:
    """A 12pt-bold block longer than the H3 cap is not promoted to HEADING_3."""
    long_text = "3. " + ("Front matter sommario generale entry text " * 10)
    spans = (
        _SpanBuilder()
        .add(long_text, font=PARAGRAPH_HEADING_FONT, size=PARAGRAPH_HEADING_SIZE)
        .build()
    )
    block = _make_block(page=10, span_range=(0, 1))
    extraction = _make_extraction(spans, [block])
    tier1 = [
        ClassifiedBlock(block_index=0, category=SemanticCategory.UNCLASSIFIED, reason="no_match")
    ]
    refined = ManualeZanichelliGiuridicaProfile().refine_classification(extraction, tier1)
    assert refined[0].category is SemanticCategory.UNCLASSIFIED


def test_refine_classification_ignores_empty_span_blocks() -> None:
    """A block whose span_range is empty is left untouched."""
    block = _make_block(page=10, span_range=(0, 0))
    extraction = _make_extraction([], [block])
    tier1 = [
        ClassifiedBlock(block_index=0, category=SemanticCategory.UNCLASSIFIED, reason="no_match")
    ]
    refined = ManualeZanichelliGiuridicaProfile().refine_classification(extraction, tier1)
    assert refined[0].category is SemanticCategory.UNCLASSIFIED


# ---------------------------------------------------------------------------
# refine_reconstruction()


def _summary_node(text: str | None, node_id: str = "node_0001") -> Node:
    return Node(
        id=node_id,
        category=SemanticCategory.CHAPTER_SUMMARY,
        page_index=20,
        block_indices=(0,),
        text=text,
    )


def test_refine_reconstruction_parses_three_items() -> None:
    text = (
        f"Sommario  1. L'impresa e l'imprenditore{DASH}"
        f"2. La nozione di imprenditore{DASH}"
        "3. La capacità per l'esercizio dell'impresa"
    )
    document = Document(root=(_summary_node(text),))
    refined = ManualeZanichelliGiuridicaProfile().refine_reconstruction(
        document, _make_extraction([], []), []
    )
    items = refined.root[0].summary_items
    assert items is not None
    assert len(items) == 3
    assert items[0] == SummaryItem(number="1", title="L'impresa e l'imprenditore")
    assert items[1] == SummaryItem(number="2", title="La nozione di imprenditore")
    assert items[2] == SummaryItem(number="3", title="La capacità per l'esercizio dell'impresa")
    assert refined.warnings == ()


def test_refine_reconstruction_handles_unparseable_summary() -> None:
    text = "Questo non e' un sommario valido"
    document = Document(root=(_summary_node(text, node_id="node_0002"),))
    plugin = ManualeZanichelliGiuridicaProfile()
    refined = plugin.refine_reconstruction(document, _make_extraction([], []), [])
    assert refined.root[0].summary_items is None
    assert refined.warnings == (f"{WARNING_PREFIX}:chapter_summary_unparseable_node_node_0002",)


def test_refine_reconstruction_supports_multilevel_numerations() -> None:
    """Composite numerations (``1.1``) parse just like flat ones."""
    document = Document(root=(_summary_node(f"Sommario  1.1. Premessa{DASH}1.2. Conclusione"),))
    refined = ManualeZanichelliGiuridicaProfile().refine_reconstruction(
        document, _make_extraction([], []), []
    )
    items = refined.root[0].summary_items
    assert items is not None
    assert items[0].number == "1.1"
    assert items[1].number == "1.2"


def test_refine_reconstruction_returns_node_unchanged_when_no_summary_children() -> None:
    """A document with no CHAPTER_SUMMARY is forwarded unchanged."""
    plain = Node(
        id="node_0000",
        category=SemanticCategory.BODY,
        page_index=0,
        block_indices=(0,),
        text="body text",
    )
    document = Document(root=(plain,), warnings=("tier1_warning",))
    plugin = ManualeZanichelliGiuridicaProfile()
    refined = plugin.refine_reconstruction(document, _make_extraction([], []), [])
    assert refined.root[0] is plain
    # Tier 1 warnings are preserved, plugin adds none.
    assert refined.warnings == ("tier1_warning",)


def test_refine_reconstruction_flushes_pending_classifier_warnings() -> None:
    """Warnings queued in refine_classification surface in refine_reconstruction."""
    plugin = ManualeZanichelliGiuridicaProfile()
    spans = (
        _SpanBuilder()
        .add("Titolo strano", font=CHAPTER_HEADING_FONT, size=CHAPTER_HEADING_SIZE)
        .build()
    )
    block = _make_block(page=99, span_range=(0, 1))
    extraction = _make_extraction(spans, [block])
    tier1 = [
        ClassifiedBlock(block_index=0, category=SemanticCategory.UNCLASSIFIED, reason="no_match")
    ]
    refined_blocks = plugin.refine_classification(extraction, tier1)
    document = Document()
    refined = plugin.refine_reconstruction(document, extraction, refined_blocks)
    assert refined.warnings == (f"{WARNING_PREFIX}:heading_19pt_pattern_unmatched_block_0_page_99",)
    # Second call without re-running classification has nothing left to flush.
    second = plugin.refine_reconstruction(Document(), extraction, refined_blocks)
    assert second.warnings == ()


# ---------------------------------------------------------------------------
# refine_apparatus()


def test_refine_apparatus_is_passthrough() -> None:
    plugin = ManualeZanichelliGiuridicaProfile()
    document = Document(
        root=(
            Node(
                id="node_0000",
                category=SemanticCategory.BODY,
                page_index=0,
                block_indices=(0,),
                text="hello",
            ),
        ),
    )
    assert plugin.refine_apparatus(document, _make_extraction([], []), []) is document


# ---------------------------------------------------------------------------
# Summary parsing edge cases


class _ExposingPlugin(ManualeZanichelliGiuridicaProfile):
    """Test-only subclass that exposes the private parser for direct testing."""

    profile_id: ClassVar[str] = "test_exposing"

    @staticmethod
    def parse(text: str | None) -> tuple[SummaryItem, ...] | None:
        return ManualeZanichelliGiuridicaProfile._parse_chapter_summary(text)


def test_parse_chapter_summary_returns_none_for_none_text() -> None:
    assert _ExposingPlugin.parse(None) is None


def test_parse_chapter_summary_returns_none_for_empty_text() -> None:
    assert _ExposingPlugin.parse("Sommario   ") is None


def test_parse_chapter_summary_single_item_without_separator() -> None:
    """A summary with a single entry parses cleanly without any en-dash."""
    items = _ExposingPlugin.parse("Sommario  1. Premessa")
    assert items is not None
    assert items == (SummaryItem(number="1", title="Premessa"),)


def test_parse_chapter_summary_normalises_internal_whitespace() -> None:
    items = _ExposingPlugin.parse(
        f"Sommario  1. Titolo   con   spazi   doppi{DASH}2. Altro\n\ntitolo"
    )
    assert items is not None
    assert items[0].title == "Titolo con spazi doppi"
    assert items[1].title == "Altro titolo"


def test_parse_chapter_summary_rejects_segment_without_number() -> None:
    """If any segment fails the (number, title) parse, the whole summary is unparseable."""
    assert _ExposingPlugin.parse(f"Sommario  1. Premessa{DASH}senza numero") is None


def test_parse_chapter_summary_rejects_empty_segment() -> None:
    """An en-dash with nothing on the right makes the whole summary unparseable."""
    assert _ExposingPlugin.parse(f"Sommario  1. Premessa{DASH}") is None


def test_parse_chapter_summary_rejects_segment_with_blank_title() -> None:
    """A segment that matches the number prefix but has only whitespace after is rejected."""
    # The literal "\\u2007" is a non-breaking-space placeholder that the
    # title pattern would otherwise capture and then collapse to the empty
    # string in the whitespace normaliser.
    assert _ExposingPlugin.parse("Sommario  1.   ") is None


def test_refine_classification_leaves_unknown_signature_untouched() -> None:
    """A block whose signature matches none of the four families stays UNCLASSIFIED."""
    spans = (
        _SpanBuilder().add("Mysterious text in a mystery font", font="Courier", size=10.0).build()
    )
    block = _make_block(page=5, span_range=(0, 1))
    extraction = _make_extraction(spans, [block])
    tier1 = [
        ClassifiedBlock(block_index=0, category=SemanticCategory.UNCLASSIFIED, reason="no_match")
    ]
    refined = ManualeZanichelliGiuridicaProfile().refine_classification(extraction, tier1)
    assert refined[0].category is SemanticCategory.UNCLASSIFIED
    assert refined[0].reason == "no_match"


def test_refine_reconstruction_rebuilds_parents_around_modified_summary() -> None:
    """A modified CHAPTER_SUMMARY child triggers a rebuild of its parent node."""
    summary_text = f"Sommario  1. Premessa{DASH}2. Conclusione"
    summary = Node(
        id="node_0001",
        category=SemanticCategory.CHAPTER_SUMMARY,
        page_index=20,
        block_indices=(1,),
        text=summary_text,
    )
    chapter = Node(
        id="node_0000",
        category=SemanticCategory.HEADING_1,
        page_index=20,
        block_indices=(0,),
        text="Capitolo I",
        level=1,
        children=(summary,),
    )
    document = Document(root=(chapter,))
    plugin = ManualeZanichelliGiuridicaProfile()
    refined = plugin.refine_reconstruction(document, _make_extraction([], []), [])
    # The parent must be a new Node instance (children tuple changed),
    # carrying every other field unchanged.
    new_chapter = refined.root[0]
    assert new_chapter is not chapter
    assert new_chapter.id == chapter.id
    assert new_chapter.category is chapter.category
    assert new_chapter.level == 1
    assert new_chapter.text == chapter.text
    # The child is the rewritten summary with populated items.
    new_summary = new_chapter.children[0]
    assert new_summary.summary_items is not None
    assert len(new_summary.summary_items) == 2
