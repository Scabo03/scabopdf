"""Unit tests for § 6 apparatus resolution.

Each scenario builds a small ``Document`` directly and runs
``resolve_apparatus`` against it, using ``UnknownGenericProfile`` as the
default pass-through plugin. Helpers build a minimal ``ExtractionResult``
whose ``blocks`` carry the bboxes the resolvers need; spans are not used
by tier 1 apparatus and stay empty.
"""

from __future__ import annotations

from scabopdf_pipeline.apparatus.resolver import resolve_apparatus
from scabopdf_pipeline.apparatus.types import ApparatusRefKind
from scabopdf_pipeline.classification.types import ClassifiedBlock
from scabopdf_pipeline.extraction.types import BBox, Block, ExtractionResult
from scabopdf_pipeline.profiles.unknown_generic import UnknownGenericProfile
from scabopdf_pipeline.reconstruction.types import Document, Node
from scabopdf_pipeline.schema.categories import SemanticCategory
from tests.conftest import NoOpProfilePlugin


def _block(idx: int, page: int, bbox: BBox = (0.0, 0.0, 0.0, 0.0)) -> Block:
    return Block(page=page, block_index=idx, bbox=bbox, span_range=(0, 0))


def _extraction(blocks: list[Block]) -> ExtractionResult:
    return ExtractionResult(
        spans=[],
        blocks=blocks,
        page_geometries=[],
        page_images=[],
        drawings=[],
        warnings=[],
        page_count=max((b.page for b in blocks), default=0) + 1,
        is_encrypted=False,
        permissions=-4,
    )


def _classified(n_blocks: int) -> list[ClassifiedBlock]:
    return [
        ClassifiedBlock(block_index=i, category=SemanticCategory.UNCLASSIFIED, reason="no_match")
        for i in range(n_blocks)
    ]


def _all_nodes(document: Document) -> list[Node]:
    out: list[Node] = []

    def _walk(node: Node) -> None:
        out.append(node)
        for child in node.children:
            _walk(child)

    for root in document.root:
        _walk(root)
    return out


def _by_id(document: Document, node_id: str) -> Node:
    for node in _all_nodes(document):
        if node.id == node_id:
            return node
    raise KeyError(node_id)


# (a) Patriarca-like: zero apparatus → resolve_apparatus is a no-op.
def test_document_without_apparatus_is_unchanged() -> None:
    document = Document(
        root=(
            Node(
                id="node_0000",
                category=SemanticCategory.HEADING_1,
                page_index=0,
                block_indices=(0,),
                text="Capitolo",
                level=1,
                children=(
                    Node(
                        id="node_0001",
                        category=SemanticCategory.BODY,
                        page_index=0,
                        block_indices=(1,),
                        text="paragraph",
                    ),
                ),
            ),
        ),
        warnings=(),
    )
    extraction = _extraction([_block(0, 0), _block(1, 0)])
    result = resolve_apparatus(document, extraction, _classified(2), UnknownGenericProfile())
    assert result == document


# (b) Cross-page NOTE merging: hit.
def test_cross_page_note_merging_hit() -> None:
    document = Document(
        root=(
            Node(
                id="note_a",
                category=SemanticCategory.NOTE,
                page_index=0,
                block_indices=(0,),
                text="(1) prima parte",
            ),
            Node(
                id="note_b",
                category=SemanticCategory.NOTE,
                page_index=1,
                block_indices=(1,),
                text="continuazione senza marker",
            ),
        ),
        warnings=(),
    )
    extraction = _extraction([_block(0, 0), _block(1, 1)])
    result = resolve_apparatus(document, extraction, _classified(2), UnknownGenericProfile())
    nodes = _all_nodes(result)
    assert len(nodes) == 1
    merged = nodes[0]
    assert merged.id == "note_a"
    assert merged.text == "(1) prima parte continuazione senza marker"
    assert merged.block_indices == (0, 1)


# (c) Cross-page NOTE merging: rejected because second NOTE has its own marker.
def test_cross_page_note_merging_rejected_when_second_has_marker() -> None:
    document = Document(
        root=(
            Node(
                id="note_a",
                category=SemanticCategory.NOTE,
                page_index=0,
                block_indices=(0,),
                text="(1) testo nota uno",
            ),
            Node(
                id="note_b",
                category=SemanticCategory.NOTE,
                page_index=1,
                block_indices=(1,),
                text="(2) testo nota due",
            ),
        ),
        warnings=(),
    )
    extraction = _extraction([_block(0, 0), _block(1, 1)])
    result = resolve_apparatus(document, extraction, _classified(2), UnknownGenericProfile())
    nodes = _all_nodes(result)
    assert len(nodes) == 2
    assert {n.id for n in nodes} == {"note_a", "note_b"}
    assert _by_id(result, "note_a").text == "(1) testo nota uno"
    assert _by_id(result, "note_b").text == "(2) testo nota due"


# (d) Simple cross-reference resolution within scope.
def test_cross_reference_resolves_to_note_in_scope() -> None:
    document = Document(
        root=(
            Node(
                id="heading",
                category=SemanticCategory.HEADING_1,
                page_index=0,
                block_indices=(0,),
                text="Capitolo I",
                level=1,
                children=(
                    Node(
                        id="note",
                        category=SemanticCategory.NOTE,
                        page_index=0,
                        block_indices=(1,),
                        text="(1) testo della nota",
                    ),
                    Node(
                        id="body",
                        category=SemanticCategory.BODY,
                        page_index=0,
                        block_indices=(2,),
                        text="paragrafo",
                        children=(
                            Node(
                                id="cross_ref",
                                category=SemanticCategory.CROSS_REFERENCE,
                                page_index=0,
                                block_indices=(3,),
                                text="1",
                            ),
                        ),
                    ),
                ),
            ),
        ),
        warnings=(),
    )
    extraction = _extraction([_block(i, 0) for i in range(4)])
    result = resolve_apparatus(document, extraction, _classified(4), UnknownGenericProfile())
    cr = _by_id(result, "cross_ref")
    assert len(cr.apparatus_refs) == 1
    ref = cr.apparatus_refs[0]
    assert ref.kind == ApparatusRefKind.CROSS_REF_TARGET
    assert ref.target_node_id == "note"
    assert ref.source_marker == "(1)"
    assert result.warnings == ()


# (e) Unresolved cross-reference: no matching NOTE.
def test_cross_reference_unresolved_emits_warning() -> None:
    document = Document(
        root=(
            Node(
                id="heading",
                category=SemanticCategory.HEADING_1,
                page_index=0,
                block_indices=(0,),
                text="Capitolo I",
                level=1,
                children=(
                    Node(
                        id="cross_ref",
                        category=SemanticCategory.CROSS_REFERENCE,
                        page_index=0,
                        block_indices=(1,),
                        text="3",
                    ),
                ),
            ),
        ),
        warnings=(),
    )
    extraction = _extraction([_block(0, 0), _block(1, 0)])
    result = resolve_apparatus(document, extraction, _classified(2), UnknownGenericProfile())
    cr = _by_id(result, "cross_ref")
    assert cr.apparatus_refs == ()
    assert "unresolved_cross_reference_node_cross_ref_n_3" in result.warnings


# (f) Unparseable cross-reference.
def test_cross_reference_unparseable_emits_warning() -> None:
    document = Document(
        root=(
            Node(
                id="cross_ref",
                category=SemanticCategory.CROSS_REFERENCE,
                page_index=0,
                block_indices=(0,),
                text="asd",
            ),
        ),
        warnings=(),
    )
    extraction = _extraction([_block(0, 0)])
    result = resolve_apparatus(document, extraction, _classified(1), UnknownGenericProfile())
    cr = _by_id(result, "cross_ref")
    assert cr.apparatus_refs == ()
    assert "unparseable_cross_reference_node_cross_ref" in result.warnings


# (g) Cross-reference scope: bind to the NOTE in the same chapter, not the
# previous chapter's NOTE with the same marker.
def test_cross_reference_scope_picks_local_note() -> None:
    document = Document(
        root=(
            Node(
                id="chap1",
                category=SemanticCategory.HEADING_1,
                page_index=0,
                block_indices=(0,),
                text="Capitolo I",
                level=1,
                children=(
                    Node(
                        id="note_chap1",
                        category=SemanticCategory.NOTE,
                        page_index=0,
                        block_indices=(1,),
                        text="(1) nota del primo capitolo",
                    ),
                ),
            ),
            Node(
                id="chap2",
                category=SemanticCategory.HEADING_1,
                page_index=1,
                block_indices=(2,),
                text="Capitolo II",
                level=1,
                children=(
                    Node(
                        id="note_chap2",
                        category=SemanticCategory.NOTE,
                        page_index=1,
                        block_indices=(3,),
                        text="(1) nota del secondo capitolo",
                    ),
                    Node(
                        id="cross_ref",
                        category=SemanticCategory.CROSS_REFERENCE,
                        page_index=1,
                        block_indices=(4,),
                        text="1",
                    ),
                ),
            ),
        ),
        warnings=(),
    )
    extraction = _extraction([_block(0, 0), _block(1, 0), _block(2, 1), _block(3, 1), _block(4, 1)])
    result = resolve_apparatus(document, extraction, _classified(5), UnknownGenericProfile())
    cr = _by_id(result, "cross_ref")
    assert len(cr.apparatus_refs) == 1
    assert cr.apparatus_refs[0].target_node_id == "note_chap2"


# (h) MARGINAL_HEADING binds to the closest body-side node by y_center.
def test_marginal_heading_binds_to_closest_body() -> None:
    document = Document(
        root=(
            Node(
                id="body_far",
                category=SemanticCategory.BODY,
                page_index=0,
                block_indices=(0,),
                text="paragrafo lontano",
            ),
            Node(
                id="body_near",
                category=SemanticCategory.BODY,
                page_index=0,
                block_indices=(1,),
                text="paragrafo vicino",
            ),
            Node(
                id="margin",
                category=SemanticCategory.MARGINAL_HEADING,
                page_index=0,
                block_indices=(2,),
                text="titolo marginale",
            ),
        ),
        warnings=(),
    )
    extraction = _extraction(
        [
            _block(0, 0, bbox=(0.0, 100.0, 100.0, 120.0)),
            _block(1, 0, bbox=(0.0, 200.0, 100.0, 220.0)),
            _block(2, 0, bbox=(0.0, 205.0, 50.0, 215.0)),
        ]
    )
    result = resolve_apparatus(document, extraction, _classified(3), UnknownGenericProfile())
    margin = _by_id(result, "margin")
    assert len(margin.apparatus_refs) == 1
    ref = margin.apparatus_refs[0]
    assert ref.kind == ApparatusRefKind.BODY_ASSOCIATION
    assert ref.target_node_id == "body_near"
    assert ref.source_marker is None


# (i) MARGINAL_HEADING with no body candidate on its page → warning.
def test_marginal_heading_without_target_emits_warning() -> None:
    document = Document(
        root=(
            Node(
                id="margin",
                category=SemanticCategory.MARGINAL_HEADING,
                page_index=7,
                block_indices=(0,),
                text="titolo marginale orfano",
            ),
        ),
        warnings=(),
    )
    extraction = _extraction([_block(0, 7, bbox=(0.0, 100.0, 50.0, 110.0))])
    result = resolve_apparatus(document, extraction, _classified(1), UnknownGenericProfile())
    margin = _by_id(result, "margin")
    assert margin.apparatus_refs == ()
    assert "marginal_heading_without_body_target_node_margin_page_7" in result.warnings


# (j) MARGINAL_GLOSS binds to the closest NOTE on its page.
def test_marginal_gloss_binds_to_closest_note() -> None:
    document = Document(
        root=(
            Node(
                id="note_far",
                category=SemanticCategory.NOTE,
                page_index=0,
                block_indices=(0,),
                text="(1) nota lontana",
            ),
            Node(
                id="note_near",
                category=SemanticCategory.NOTE,
                page_index=0,
                block_indices=(1,),
                text="(2) nota vicina",
            ),
            Node(
                id="gloss",
                category=SemanticCategory.MARGINAL_GLOSS,
                page_index=0,
                block_indices=(2,),
                text="glossa",
            ),
        ),
        warnings=(),
    )
    extraction = _extraction(
        [
            _block(0, 0, bbox=(0.0, 100.0, 100.0, 120.0)),
            _block(1, 0, bbox=(0.0, 200.0, 100.0, 220.0)),
            _block(2, 0, bbox=(0.0, 205.0, 50.0, 215.0)),
        ]
    )
    result = resolve_apparatus(document, extraction, _classified(3), UnknownGenericProfile())
    gloss = _by_id(result, "gloss")
    assert len(gloss.apparatus_refs) == 1
    ref = gloss.apparatus_refs[0]
    assert ref.kind == ApparatusRefKind.GLOSS_TARGET
    assert ref.target_node_id == "note_near"
    assert ref.source_marker is None


# (k) EXAMPLE_BOX gets no apparatus_refs and emits no warning (no-op).
def test_example_box_is_left_untouched() -> None:
    document = Document(
        root=(
            Node(
                id="heading",
                category=SemanticCategory.HEADING_1,
                page_index=0,
                block_indices=(0,),
                text="Capitolo I",
                level=1,
                children=(
                    Node(
                        id="body",
                        category=SemanticCategory.BODY,
                        page_index=0,
                        block_indices=(1,),
                        text="paragrafo",
                    ),
                    Node(
                        id="box",
                        category=SemanticCategory.EXAMPLE_BOX,
                        page_index=0,
                        block_indices=(2,),
                        text="contenuto del box",
                    ),
                ),
            ),
        ),
        warnings=(),
    )
    extraction = _extraction([_block(i, 0) for i in range(3)])
    result = resolve_apparatus(document, extraction, _classified(3), UnknownGenericProfile())
    box = _by_id(result, "box")
    assert box.apparatus_refs == ()
    assert result.warnings == ()
    assert result == document


# (l) Tier 2 dispatch: the plugin sees the post-tier-1 Document and may
# extend it. A sentinel plugin proves the dispatch happens.
class _SentinelPlugin(NoOpProfilePlugin):
    def refine_apparatus(
        self,
        document: Document,
        extraction: ExtractionResult,
        classified_blocks: list[ClassifiedBlock],
    ) -> Document:
        del extraction, classified_blocks
        return Document(
            root=document.root,
            warnings=(*document.warnings, "sentinel_refine_apparatus_called"),
        )


def test_tier2_unknown_generic_is_passthrough() -> None:
    document = Document(
        root=(
            Node(
                id="body",
                category=SemanticCategory.BODY,
                page_index=0,
                block_indices=(0,),
                text="paragrafo",
            ),
        ),
        warnings=("preexisting_tier1_warning",),
    )
    extraction = _extraction([_block(0, 0)])
    result_unknown = resolve_apparatus(
        document, extraction, _classified(1), UnknownGenericProfile()
    )
    result_sentinel = resolve_apparatus(document, extraction, _classified(1), _SentinelPlugin())
    assert "sentinel_refine_apparatus_called" not in result_unknown.warnings
    assert "preexisting_tier1_warning" in result_unknown.warnings
    assert "sentinel_refine_apparatus_called" in result_sentinel.warnings
    assert "preexisting_tier1_warning" in result_sentinel.warnings


# (m) Integration invariant: a small document with NOTE, MARGINAL_HEADING,
# MARGINAL_GLOSS, CROSS_REFERENCE and a BODY all on the same page; the
# sum of all apparatus_refs equals the manually-computed expected count.
def test_total_apparatus_refs_matches_expected_bindings() -> None:
    document = Document(
        root=(
            Node(
                id="heading",
                category=SemanticCategory.HEADING_1,
                page_index=0,
                block_indices=(0,),
                text="Capitolo",
                level=1,
                children=(
                    Node(
                        id="note",
                        category=SemanticCategory.NOTE,
                        page_index=0,
                        block_indices=(1,),
                        text="(1) testo della nota",
                    ),
                    Node(
                        id="body",
                        category=SemanticCategory.BODY,
                        page_index=0,
                        block_indices=(2,),
                        text="paragrafo",
                    ),
                    Node(
                        id="margin",
                        category=SemanticCategory.MARGINAL_HEADING,
                        page_index=0,
                        block_indices=(3,),
                        text="titolo marginale",
                    ),
                    Node(
                        id="gloss",
                        category=SemanticCategory.MARGINAL_GLOSS,
                        page_index=0,
                        block_indices=(4,),
                        text="glossa",
                    ),
                    Node(
                        id="cross_ref",
                        category=SemanticCategory.CROSS_REFERENCE,
                        page_index=0,
                        block_indices=(5,),
                        text="1",
                    ),
                ),
            ),
        ),
        warnings=(),
    )
    # bboxes: heading near top, body mid-page, margin aligned with body,
    # note near bottom, gloss aligned with note, cross_ref at end.
    extraction = _extraction(
        [
            _block(0, 0, bbox=(0.0, 0.0, 100.0, 30.0)),
            _block(1, 0, bbox=(0.0, 300.0, 100.0, 320.0)),
            _block(2, 0, bbox=(0.0, 100.0, 100.0, 120.0)),
            _block(3, 0, bbox=(0.0, 105.0, 50.0, 115.0)),
            _block(4, 0, bbox=(0.0, 305.0, 50.0, 315.0)),
            _block(5, 0, bbox=(0.0, 400.0, 20.0, 410.0)),
        ]
    )
    result = resolve_apparatus(document, extraction, _classified(6), UnknownGenericProfile())
    total = sum(len(n.apparatus_refs) for n in _all_nodes(result))
    # Expected manual count:
    #   margin → body                  (BODY_ASSOCIATION)
    #   gloss  → note                  (GLOSS_TARGET)
    #   cross_ref(1) → note            (CROSS_REF_TARGET)
    assert total == 3

    margin_refs = _by_id(result, "margin").apparatus_refs
    gloss_refs = _by_id(result, "gloss").apparatus_refs
    cr_refs = _by_id(result, "cross_ref").apparatus_refs
    assert margin_refs[0].kind == ApparatusRefKind.BODY_ASSOCIATION
    assert margin_refs[0].target_node_id == "body"
    assert gloss_refs[0].kind == ApparatusRefKind.GLOSS_TARGET
    assert gloss_refs[0].target_node_id == "note"
    assert cr_refs[0].kind == ApparatusRefKind.CROSS_REF_TARGET
    assert cr_refs[0].target_node_id == "note"
    assert cr_refs[0].source_marker == "(1)"
    assert result.warnings == ()
