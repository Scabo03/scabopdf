from scabopdf_pipeline.classification.types import ClassifiedBlock
from scabopdf_pipeline.extraction.types import (
    Block,
    ExtractionResult,
    PageGeometry,
    Span,
)
from scabopdf_pipeline.profiles.unknown_generic import UnknownGenericProfile
from scabopdf_pipeline.profiling.profile import DocumentProfile
from scabopdf_pipeline.reconstruction import Node, reconstruct
from scabopdf_pipeline.schema.categories import SemanticCategory

PAGE_W = 600.0
PAGE_H = 800.0


def _profile() -> DocumentProfile:
    return DocumentProfile(
        profile_id="unknown_generic",
        editorial_family="unknown",
        genre="unknown",
        confidence=0.0,
    )


def _plugin() -> UnknownGenericProfile:
    return UnknownGenericProfile()


def _build_inputs(
    block_specs: list[tuple[SemanticCategory, int, float, str]],
    *,
    x0_per_block: list[float] | None = None,
    extra_classified: list[ClassifiedBlock] | None = None,
    pages: list[int] | None = None,
) -> tuple[ExtractionResult, list[ClassifiedBlock]]:
    """Build an ExtractionResult and matching list[ClassifiedBlock].

    Each entry in ``block_specs`` produces one ``Block`` with a single
    ``Span`` carrying the given text. ``extra_classified`` lets the caller
    append sentinel ``ClassifiedBlock``s (``block_index=-1``) that do not
    correspond to a real block. ``pages`` overrides the page set used to
    synthesise ``PageGeometry`` entries; defaults to the union of the pages
    referenced by ``block_specs`` and ``extra_classified``.
    """
    spans: list[Span] = []
    blocks: list[Block] = []
    classified: list[ClassifiedBlock] = []

    for i, (category, page, y0, text) in enumerate(block_specs):
        x0 = x0_per_block[i] if x0_per_block is not None else 10.0
        bbox = (x0, y0, x0 + 100.0, y0 + 10.0)
        spans.append(
            Span(
                text=text,
                font="Helvetica",
                size=10.0,
                flags=0,
                color=0,
                bbox=bbox,
                page=page,
                block_index=i,
                line_index=0,
                span_index=0,
            )
        )
        blocks.append(
            Block(
                page=page,
                block_index=i,
                bbox=bbox,
                span_range=(i, i + 1),
            )
        )
        classified.append(
            ClassifiedBlock(
                block_index=i,
                category=category,
                reason="test",
            )
        )

    if extra_classified is not None:
        classified.extend(extra_classified)

    if pages is None:
        block_pages = {p for _, p, _, _ in block_specs}
        sentinel_pages = set()
        if extra_classified is not None:
            for cb in extra_classified:
                if cb.subcategory is not None:
                    sentinel_pages.add(int(cb.subcategory))
        pages = sorted(block_pages | sentinel_pages)

    geometries = [
        PageGeometry(page=p, width_pt=PAGE_W, height_pt=PAGE_H, rotation=0) for p in pages
    ]
    extraction = ExtractionResult(
        spans=spans,
        blocks=blocks,
        page_geometries=geometries,
        page_images=[],
        drawings=[],
        warnings=[],
        page_count=len(geometries),
        is_encrypted=False,
        permissions=-4,
    )
    return extraction, classified


def _collect_block_indices(nodes: tuple[Node, ...]) -> list[int]:
    result: list[int] = []
    for node in nodes:
        result.extend(node.block_indices)
        result.extend(_collect_block_indices(node.children))
    return result


# ---------------------------------------------------------------------------
# (a) sorting mono-colonna
# ---------------------------------------------------------------------------


def test_sort_mono_column_orders_by_page_then_y_then_x() -> None:
    extraction, classified = _build_inputs(
        [
            (SemanticCategory.BODY, 1, 100.0, "B"),
            (SemanticCategory.BODY, 0, 50.0, "A"),
            (SemanticCategory.BODY, 0, 200.0, "C"),
        ]
    )
    document = reconstruct(extraction, classified, _profile(), _plugin())
    assert [n.text for n in document.root] == ["A", "C", "B"]
    assert [n.block_indices for n in document.root] == [(1,), (2,), (0,)]


def test_sort_breaks_y_ties_by_x() -> None:
    extraction, classified = _build_inputs(
        [
            (SemanticCategory.BODY, 0, 100.0, "right"),
            (SemanticCategory.BODY, 0, 100.0, "left"),
        ],
        x0_per_block=[300.0, 50.0],
    )
    document = reconstruct(extraction, classified, _profile(), _plugin())
    assert [n.text for n in document.root] == ["left", "right"]


# ---------------------------------------------------------------------------
# (b) cross-page merging happy path
# ---------------------------------------------------------------------------


def test_cross_page_merge_concatenates_body_at_page_top() -> None:
    extraction, classified = _build_inputs(
        [
            (SemanticCategory.BODY, 0, 400.0, "first part"),
            (SemanticCategory.BODY, 1, 50.0, "second part"),
        ]
    )
    document = reconstruct(extraction, classified, _profile(), _plugin())
    assert len(document.root) == 1
    merged = document.root[0]
    assert merged.text == "first part second part"
    assert merged.block_indices == (0, 1)
    assert merged.page_index == 0


# ---------------------------------------------------------------------------
# (c) cross-page merging rejected when the top-of-page block is a heading
# ---------------------------------------------------------------------------


def test_cross_page_merge_rejected_when_text_matches_heading_pattern() -> None:
    extraction, classified = _build_inputs(
        [
            (SemanticCategory.BODY, 0, 400.0, "intro paragraph"),
            (SemanticCategory.BODY, 1, 50.0, "CAPITOLO II Le obbligazioni"),
        ]
    )
    document = reconstruct(extraction, classified, _profile(), _plugin())
    assert len(document.root) == 2
    assert document.root[0].text == "intro paragraph"
    assert document.root[1].text == "CAPITOLO II Le obbligazioni"


def test_cross_page_merge_blocked_by_intervening_heading() -> None:
    extraction, classified = _build_inputs(
        [
            (SemanticCategory.BODY, 0, 400.0, "first body"),
            (SemanticCategory.HEADING_2, 0, 700.0, "New Section"),
            (SemanticCategory.BODY, 1, 50.0, "second body"),
        ]
    )
    document = reconstruct(extraction, classified, _profile(), _plugin())
    # No merge: the H2 between the two BODY blocks is a barrier. The second
    # BODY ends up as a child of the (orphan-attached) H2, since heading
    # assembly tracks the H2 as the current heading container for any
    # following BODY content.
    assert len(document.root) == 2
    assert document.root[0].text == "first body"
    assert document.root[0].block_indices == (0,)
    h2 = document.root[1]
    assert h2.category == SemanticCategory.HEADING_2
    assert len(h2.children) == 1
    assert h2.children[0].text == "second body"
    assert h2.children[0].block_indices == (2,)
    # H2 produces an orphan warning (no H1 ancestor).
    assert document.warnings == ("orphan_heading_level_2_page_0",)


# ---------------------------------------------------------------------------
# (d) hierarchy H1 → H2 → H3 → BODY
# ---------------------------------------------------------------------------


def test_hierarchy_h1_h2_h3_body() -> None:
    extraction, classified = _build_inputs(
        [
            (SemanticCategory.HEADING_1, 0, 50.0, "H1"),
            (SemanticCategory.HEADING_2, 0, 100.0, "H2"),
            (SemanticCategory.HEADING_3, 0, 150.0, "H3"),
            (SemanticCategory.BODY, 0, 200.0, "body"),
        ]
    )
    document = reconstruct(extraction, classified, _profile(), _plugin())
    assert len(document.root) == 1
    h1 = document.root[0]
    assert h1.category == SemanticCategory.HEADING_1
    assert h1.level == 1
    assert len(h1.children) == 1
    h2 = h1.children[0]
    assert h2.category == SemanticCategory.HEADING_2
    assert h2.level == 2
    assert len(h2.children) == 1
    h3 = h2.children[0]
    assert h3.category == SemanticCategory.HEADING_3
    assert h3.level == 3
    assert len(h3.children) == 1
    body = h3.children[0]
    assert body.category == SemanticCategory.BODY
    assert body.children == ()
    assert body.text == "body"
    assert document.warnings == ()


# ---------------------------------------------------------------------------
# (e) orphan H3 without an H2 parent
# ---------------------------------------------------------------------------


def test_orphan_heading_level_3_attaches_to_root_with_warning() -> None:
    extraction, classified = _build_inputs(
        [
            (SemanticCategory.HEADING_1, 0, 50.0, "H1"),
            (SemanticCategory.HEADING_3, 0, 100.0, "H3"),
        ]
    )
    document = reconstruct(extraction, classified, _profile(), _plugin())
    assert len(document.root) == 2
    assert document.root[0].category == SemanticCategory.HEADING_1
    assert document.root[1].category == SemanticCategory.HEADING_3
    assert document.warnings == ("orphan_heading_level_3_page_0",)


# ---------------------------------------------------------------------------
# (f) ARTICLE_HEADER + ARTICLE_BODY happy path
# ---------------------------------------------------------------------------


def test_article_body_attaches_to_most_recent_article_header() -> None:
    extraction, classified = _build_inputs(
        [
            (SemanticCategory.ARTICLE_HEADER, 0, 50.0, "Art. 1"),
            (SemanticCategory.ARTICLE_BODY, 0, 100.0, "article text"),
        ]
    )
    document = reconstruct(extraction, classified, _profile(), _plugin())
    assert len(document.root) == 1
    article_header = document.root[0]
    assert article_header.category == SemanticCategory.ARTICLE_HEADER
    assert len(article_header.children) == 1
    article_body = article_header.children[0]
    assert article_body.category == SemanticCategory.ARTICLE_BODY
    assert article_body.text == "article text"
    assert document.warnings == ()


# ---------------------------------------------------------------------------
# (g) ARTICLE_BODY orphan (no preceding ARTICLE_HEADER)
# ---------------------------------------------------------------------------


def test_orphan_article_body_attaches_to_container_with_warning() -> None:
    extraction, classified = _build_inputs(
        [
            (SemanticCategory.ARTICLE_BODY, 0, 50.0, "lone article body"),
        ]
    )
    document = reconstruct(extraction, classified, _profile(), _plugin())
    assert len(document.root) == 1
    assert document.root[0].category == SemanticCategory.ARTICLE_BODY
    assert document.warnings == ("article_body_without_header_page_0",)


def test_orphan_article_body_under_heading_attaches_to_heading() -> None:
    extraction, classified = _build_inputs(
        [
            (SemanticCategory.HEADING_1, 0, 50.0, "H1"),
            (SemanticCategory.ARTICLE_BODY, 0, 100.0, "orphaned"),
        ]
    )
    document = reconstruct(extraction, classified, _profile(), _plugin())
    assert len(document.root) == 1
    h1 = document.root[0]
    assert h1.category == SemanticCategory.HEADING_1
    assert len(h1.children) == 1
    assert h1.children[0].category == SemanticCategory.ARTICLE_BODY
    assert document.warnings == ("article_body_without_header_page_0",)


# ---------------------------------------------------------------------------
# (h) pass-through tier 2 with unknown_generic
# ---------------------------------------------------------------------------


def test_tier2_passthrough_with_unknown_generic() -> None:
    extraction, classified = _build_inputs(
        [
            (SemanticCategory.HEADING_1, 0, 50.0, "Title"),
            (SemanticCategory.BODY, 0, 100.0, "body text"),
            (SemanticCategory.ARTICLE_HEADER, 0, 200.0, "Art. 1"),
            (SemanticCategory.ARTICLE_BODY, 0, 250.0, "article text"),
        ]
    )
    plugin = _plugin()
    document = reconstruct(extraction, classified, _profile(), plugin)
    # Pass-through means refine_reconstruction returns the same document
    # without modification: applying it again must yield the same result.
    assert plugin.refine_reconstruction(document, extraction, classified) is document


# ---------------------------------------------------------------------------
# (i) integration: block_indices preservation
# ---------------------------------------------------------------------------


def test_block_indices_are_preserved_exactly_once() -> None:
    sentinel = ClassifiedBlock(
        block_index=-1,
        category=SemanticCategory.EMPTY_PAGE,
        subcategory="2",
        reason="empty_page",
    )
    extraction, classified = _build_inputs(
        [
            (SemanticCategory.HEADING_1, 0, 50.0, "Title"),
            (SemanticCategory.BODY, 0, 100.0, "first body"),
            (SemanticCategory.HEADING_2, 0, 200.0, "Subtitle"),
            (SemanticCategory.BODY, 0, 250.0, "second body"),
            (SemanticCategory.BODY, 1, 50.0, "merged continuation"),
            (SemanticCategory.ARTICLE_HEADER, 1, 300.0, "Art. 1"),
            (SemanticCategory.ARTICLE_BODY, 1, 350.0, "article text"),
            (SemanticCategory.ARTIFACT_RUNNING_HEADER, 1, 10.0, "header"),
        ],
        extra_classified=[sentinel],
    )
    document = reconstruct(extraction, classified, _profile(), _plugin())
    collected = _collect_block_indices(document.root)
    real_indices = sorted(cb.block_index for cb in classified if cb.block_index >= 0)
    assert sorted(collected) == real_indices
    assert len(collected) == len(set(collected))


def test_empty_page_sentinel_becomes_node_at_correct_position() -> None:
    sentinel = ClassifiedBlock(
        block_index=-1,
        category=SemanticCategory.EMPTY_PAGE,
        subcategory="3",
        reason="empty_page",
    )
    extraction, classified = _build_inputs(
        [
            (SemanticCategory.BODY, 0, 100.0, "before"),
            (SemanticCategory.BODY, 5, 100.0, "after"),
        ],
        extra_classified=[sentinel],
        pages=[0, 3, 5],
    )
    document = reconstruct(extraction, classified, _profile(), _plugin())
    texts_categories = [(n.text, n.category) for n in document.root]
    assert texts_categories == [
        ("before", SemanticCategory.BODY),
        (None, SemanticCategory.EMPTY_PAGE),
        ("after", SemanticCategory.BODY),
    ]
    empty_node = document.root[1]
    assert empty_node.page_index == 3
    assert empty_node.block_indices == ()
    assert empty_node.text is None


# ---------------------------------------------------------------------------
# Bonus: deterministic, leggible node ids
# ---------------------------------------------------------------------------


def test_node_ids_are_zero_padded_and_deterministic() -> None:
    extraction, classified = _build_inputs(
        [
            (SemanticCategory.HEADING_1, 0, 50.0, "H1"),
            (SemanticCategory.BODY, 0, 100.0, "body"),
        ]
    )
    document_a = reconstruct(extraction, classified, _profile(), _plugin())
    document_b = reconstruct(extraction, classified, _profile(), _plugin())
    ids_a = [n.id for n in document_a.root] + [c.id for n in document_a.root for c in n.children]
    ids_b = [n.id for n in document_b.root] + [c.id for n in document_b.root for c in n.children]
    assert ids_a == ids_b
    assert all(node_id.startswith("node_") for node_id in ids_a)
    assert all(len(node_id) == len("node_0000") for node_id in ids_a)


# ---------------------------------------------------------------------------
# (b.5) tier 1b.5 — consolidation of adjacent multi-line heading fragments
# Closes debt (vii) of the materiali_studio plugin (CARRYOVER v2.16.1).
# ---------------------------------------------------------------------------


def _build_heading_pair_inputs(
    *,
    text1: str,
    text2: str,
    y0_1: float = 50.0,
    height_1: float = 28.0,
    y0_2: float = 80.0,
    height_2: float = 28.0,
    x0_1: float = 100.0,
    x0_2: float = 100.0,
    font_1: str = "Arial-BoldMT",
    font_2: str = "Arial-BoldMT",
    size_1: float = 25.0,
    size_2: float = 25.0,
    flags_1: int = 16,
    flags_2: int = 16,
    color_1: int = 0,
    color_2: int = 0,
    category_1: SemanticCategory = SemanticCategory.HEADING_1,
    category_2: SemanticCategory = SemanticCategory.HEADING_1,
    page: int = 0,
) -> tuple[ExtractionResult, list[ClassifiedBlock]]:
    """Build a two-block extraction tailored to exercise the adjacent-heading
    consolidation predicate. All knobs default to a "should fuse" configuration
    that the tests then perturb to verify the predicate's rejection paths.
    """
    spans = [
        Span(
            text=text1,
            font=font_1,
            size=size_1,
            flags=flags_1,
            color=color_1,
            bbox=(x0_1, y0_1, x0_1 + 200.0, y0_1 + height_1),
            page=page,
            block_index=0,
            line_index=0,
            span_index=0,
        ),
        Span(
            text=text2,
            font=font_2,
            size=size_2,
            flags=flags_2,
            color=color_2,
            bbox=(x0_2, y0_2, x0_2 + 200.0, y0_2 + height_2),
            page=page,
            block_index=1,
            line_index=0,
            span_index=0,
        ),
    ]
    blocks = [
        Block(
            page=page,
            block_index=0,
            bbox=(x0_1, y0_1, x0_1 + 200.0, y0_1 + height_1),
            span_range=(0, 1),
        ),
        Block(
            page=page,
            block_index=1,
            bbox=(x0_2, y0_2, x0_2 + 200.0, y0_2 + height_2),
            span_range=(1, 2),
        ),
    ]
    classified = [
        ClassifiedBlock(block_index=0, category=category_1, reason="test"),
        ClassifiedBlock(block_index=1, category=category_2, reason="test"),
    ]
    extraction = ExtractionResult(
        spans=spans,
        blocks=blocks,
        page_geometries=[PageGeometry(page=page, width_pt=PAGE_W, height_pt=PAGE_H, rotation=0)],
        page_images=[],
        drawings=[],
        warnings=[],
        page_count=1,
        is_encrypted=False,
        permissions=-4,
    )
    return extraction, classified


def test_consolidation_fuses_two_adjacent_heading_fragments() -> None:
    """The canonical case: two same-page HEADING_1 fragments, same x0,
    typical vertical leading, identical typography → fused into one Node.
    """
    extraction, classified = _build_heading_pair_inputs(
        text1="LE OBBLIGAZIONI NASCENTI DALLA",
        text2="LEGGE",
    )
    document = reconstruct(extraction, classified, _profile(), _plugin())
    assert len(document.root) == 1
    head = document.root[0]
    assert head.category is SemanticCategory.HEADING_1
    assert head.text == "LE OBBLIGAZIONI NASCENTI DALLA LEGGE"
    assert sorted(head.block_indices) == [0, 1]


def test_consolidation_skipped_when_x0_differs_beyond_tolerance() -> None:
    extraction, classified = _build_heading_pair_inputs(
        text1="FRAGMENT ONE",
        text2="FRAGMENT TWO",
        x0_1=100.0,
        x0_2=110.0,
    )
    document = reconstruct(extraction, classified, _profile(), _plugin())
    assert len(document.root) == 2


def test_consolidation_skipped_when_vertical_gap_exceeds_threshold() -> None:
    extraction, classified = _build_heading_pair_inputs(
        text1="FIRST",
        text2="SECOND",
        y0_1=50.0,
        height_1=28.0,
        y0_2=120.0,
        height_2=28.0,
    )
    document = reconstruct(extraction, classified, _profile(), _plugin())
    assert len(document.root) == 2


def test_consolidation_skipped_when_vertical_gap_is_negative() -> None:
    extraction, classified = _build_heading_pair_inputs(
        text1="FIRST",
        text2="OVERLAPPING",
        y0_1=50.0,
        height_1=28.0,
        y0_2=60.0,
        height_2=28.0,
    )
    document = reconstruct(extraction, classified, _profile(), _plugin())
    assert len(document.root) == 2


def test_consolidation_skipped_when_first_ends_with_terminator() -> None:
    extraction, classified = _build_heading_pair_inputs(
        text1="FIRST SENTENCE.",
        text2="SECOND SENTENCE",
    )
    document = reconstruct(extraction, classified, _profile(), _plugin())
    assert len(document.root) == 2


def test_consolidation_skipped_when_typographic_signatures_differ() -> None:
    extraction, classified = _build_heading_pair_inputs(
        text1="FIRST",
        text2="SECOND",
        size_2=22.0,
    )
    document = reconstruct(extraction, classified, _profile(), _plugin())
    assert len(document.root) == 2


def test_consolidation_skipped_when_fonts_differ() -> None:
    extraction, classified = _build_heading_pair_inputs(
        text1="FIRST",
        text2="SECOND",
        font_2="TimesNewRomanPS-BoldMT",
    )
    document = reconstruct(extraction, classified, _profile(), _plugin())
    assert len(document.root) == 2


def test_consolidation_skipped_when_categories_differ() -> None:
    """HEADING_1 + HEADING_2 must NOT be fused. The pair survives as two
    distinct Nodes; the hierarchy-assembly phase then nests the HEADING_2
    under the HEADING_1, so ``document.root`` carries a single HEADING_1
    with one HEADING_2 child rather than the two flat siblings the fusion
    would have produced.
    """
    extraction, classified = _build_heading_pair_inputs(
        text1="HEADING TEXT",
        text2="SUBHEAD TEXT",
        category_2=SemanticCategory.HEADING_2,
    )
    document = reconstruct(extraction, classified, _profile(), _plugin())
    assert len(document.root) == 1
    parent = document.root[0]
    assert parent.category is SemanticCategory.HEADING_1
    assert parent.text == "HEADING TEXT"
    assert len(parent.children) == 1
    child = parent.children[0]
    assert child.category is SemanticCategory.HEADING_2
    assert child.text == "SUBHEAD TEXT"


def test_consolidation_skipped_when_categories_are_not_headings() -> None:
    """Adjacent BODY blocks with identical typographic signature must NEVER
    be fused by tier 1b.5 — the predicate is gated on HEADING_N categories
    specifically. The y0 values are chosen well below the cross-page-top
    fraction so the unrelated tier 1b cross-page BODY merge does not fire
    either (which would also collapse them, but for a different reason).
    """
    extraction, classified = _build_heading_pair_inputs(
        text1="First body paragraph",
        text2="Second body paragraph",
        category_1=SemanticCategory.BODY,
        category_2=SemanticCategory.BODY,
        y0_1=400.0,
        y0_2=430.0,
    )
    document = reconstruct(extraction, classified, _profile(), _plugin())
    assert len(document.root) == 2
    assert document.root[0].text == "First body paragraph"
    assert document.root[1].text == "Second body paragraph"


def test_consolidation_skipped_when_pages_differ() -> None:
    """The fusion never crosses a page boundary — that is handled by the
    upstream tier 1b cross-page BODY merge, not by this heading-fusion.
    """
    extraction, classified = _build_heading_pair_inputs(
        text1="FIRST",
        text2="SECOND",
        page=0,
    )
    extraction.blocks[1] = Block(
        page=1,
        block_index=1,
        bbox=extraction.blocks[1].bbox,
        span_range=extraction.blocks[1].span_range,
    )
    extraction.spans[1] = Span(
        text=extraction.spans[1].text,
        font=extraction.spans[1].font,
        size=extraction.spans[1].size,
        flags=extraction.spans[1].flags,
        color=extraction.spans[1].color,
        bbox=extraction.spans[1].bbox,
        page=1,
        block_index=1,
        line_index=0,
        span_index=0,
    )
    extraction.page_geometries.append(
        PageGeometry(page=1, width_pt=PAGE_W, height_pt=PAGE_H, rotation=0)
    )
    document = reconstruct(extraction, classified, _profile(), _plugin())
    assert len(document.root) == 2


def test_consolidation_chain_fuses_three_fragments() -> None:
    """Three adjacent HEADING_1 with identical style and uniform gap should
    all collapse into one Node via the sequential fold over output[-1].
    """
    spans = []
    blocks = []
    classified = []
    for i, (y0, text) in enumerate(((50.0, "A"), (80.0, "B"), (110.0, "C"))):
        spans.append(
            Span(
                text=text,
                font="Arial-BoldMT",
                size=25.0,
                flags=16,
                color=0,
                bbox=(100.0, y0, 300.0, y0 + 28.0),
                page=0,
                block_index=i,
                line_index=0,
                span_index=0,
            )
        )
        blocks.append(
            Block(
                page=0,
                block_index=i,
                bbox=(100.0, y0, 300.0, y0 + 28.0),
                span_range=(i, i + 1),
            )
        )
        classified.append(
            ClassifiedBlock(block_index=i, category=SemanticCategory.HEADING_1, reason="test")
        )
    extraction = ExtractionResult(
        spans=spans,
        blocks=blocks,
        page_geometries=[PageGeometry(page=0, width_pt=PAGE_W, height_pt=PAGE_H, rotation=0)],
        page_images=[],
        drawings=[],
        warnings=[],
        page_count=1,
        is_encrypted=False,
        permissions=-4,
    )
    document = reconstruct(extraction, classified, _profile(), _plugin())
    assert len(document.root) == 1
    assert document.root[0].text == "A B C"
    assert sorted(document.root[0].block_indices) == [0, 1, 2]


def test_consolidation_skipped_when_combined_length_exceeds_cap() -> None:
    """The cap (500 chars) blocks pathological fusion. Two synthetic
    HEADING_1 of 300 chars each (legitimate by signature/geometry) are
    NOT fused because 300 + 300 > 500."""
    long_a = "A" * 300
    long_b = "B" * 300
    extraction, classified = _build_heading_pair_inputs(text1=long_a, text2=long_b)
    document = reconstruct(extraction, classified, _profile(), _plugin())
    assert len(document.root) == 2
