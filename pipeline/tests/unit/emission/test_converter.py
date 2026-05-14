"""Unit tests for ``scabopdf_pipeline.emission.converter.convert_document``."""

from __future__ import annotations

from uuid import UUID

from scabopdf_pipeline.apparatus.types import ApparatusRef, ApparatusRefKind
from scabopdf_pipeline.emission.converter import convert_document
from scabopdf_pipeline.extraction.types import (
    Block,
    ExtractionResult,
    PageGeometry,
    Span,
)
from scabopdf_pipeline.postprocessing.types import Transformation
from scabopdf_pipeline.profiling.profile import DocumentProfile
from scabopdf_pipeline.reconstruction.types import Document, Node
from scabopdf_pipeline.schema.categories import SemanticCategory
from scabopdf_pipeline.schema.contract import ScabopdfDocument


def _empty_extraction(page_count: int = 1) -> ExtractionResult:
    """A minimal ``ExtractionResult`` with ``page_count`` pages."""
    geometries = [
        PageGeometry(page=i, width_pt=595.0, height_pt=842.0, rotation=0) for i in range(page_count)
    ]
    return ExtractionResult(
        spans=[],
        blocks=[],
        page_geometries=geometries,
        page_images=[],
        drawings=[],
        warnings=[],
        page_count=page_count,
        is_encrypted=False,
        permissions=-1,
    )


def _profile(warnings: list[str] | None = None) -> DocumentProfile:
    return DocumentProfile(
        profile_id="unknown_generic",
        editorial_family="unknown",
        genre="unknown",
        layouts_available=[],
        layouts_disabled=[],
        post_processing=[],
        categories_emitted=set(),
        confidence=0.0,
        warnings=warnings or [],
    )


def test_convert_minimal_single_heading() -> None:
    """A single HEADING_1 node round-trips into a ScabopdfDocument with one structure entry."""
    node = Node(
        id="node_0001",
        category=SemanticCategory.HEADING_1,
        page_index=0,
        block_indices=(0,),
        text="Title",
        level=1,
    )
    doc = Document(root=(node,))
    extraction = _empty_extraction()

    result = convert_document(doc, extraction, _profile(), "doc.pdf")

    assert isinstance(result, ScabopdfDocument)
    assert len(result.structure) == 1
    assert result.structure[0].id == "node_0001"
    assert result.structure[0].type == SemanticCategory.HEADING_1
    assert result.structure[0].text == "Title"
    assert result.structure[0].level == 1


def test_convert_preserves_three_level_nesting() -> None:
    """Three levels of nesting are reproduced exactly in the emitted tree."""
    leaf = Node(
        id="node_0003",
        category=SemanticCategory.BODY,
        page_index=0,
        block_indices=(2,),
        text="leaf",
    )
    inner = Node(
        id="node_0002",
        category=SemanticCategory.HEADING_2,
        page_index=0,
        block_indices=(1,),
        text="inner",
        level=2,
        children=(leaf,),
    )
    root = Node(
        id="node_0001",
        category=SemanticCategory.HEADING_1,
        page_index=0,
        block_indices=(0,),
        text="root",
        level=1,
        children=(inner,),
    )
    document = Document(root=(root,))

    result = convert_document(document, _empty_extraction(), _profile(), "x.pdf")

    assert result.structure[0].id == "node_0001"
    assert result.structure[0].children[0].id == "node_0002"
    assert result.structure[0].children[0].children[0].id == "node_0003"
    assert result.structure[0].children[0].children[0].text == "leaf"


def test_convert_preserves_apparatus_refs() -> None:
    """A node with two ApparatusRefs is mapped to two ApparatusRefDicts in order."""
    refs = (
        ApparatusRef(
            kind=ApparatusRefKind.CROSS_REF_TARGET,
            target_node_id="node_0002",
            source_marker="(1)",
        ),
        ApparatusRef(
            kind=ApparatusRefKind.BODY_ASSOCIATION,
            target_node_id="node_0003",
            source_marker=None,
        ),
    )
    node = Node(
        id="node_0001",
        category=SemanticCategory.CROSS_REFERENCE,
        page_index=0,
        block_indices=(0,),
        text="1",
        apparatus_refs=refs,
    )
    result = convert_document(Document(root=(node,)), _empty_extraction(), _profile(), "x.pdf")

    emitted = result.structure[0].apparatus_refs
    assert len(emitted) == 2
    assert emitted[0].kind == ApparatusRefKind.CROSS_REF_TARGET
    assert emitted[0].target_node_id == "node_0002"
    assert emitted[0].source_marker == "(1)"
    assert emitted[1].kind == ApparatusRefKind.BODY_ASSOCIATION
    assert emitted[1].source_marker is None


def test_convert_tuple_block_indices_becomes_list() -> None:
    """``block_indices`` flows from tuple (Python) to list (JSON), content unchanged."""
    node = Node(
        id="node_0001",
        category=SemanticCategory.BODY,
        page_index=0,
        block_indices=(2, 5, 9),
        text="body",
    )
    result = convert_document(Document(root=(node,)), _empty_extraction(), _profile(), "x.pdf")

    emitted = result.structure[0].block_indices
    assert isinstance(emitted, list)
    assert emitted == [2, 5, 9]


def test_convert_text_none_for_empty_page() -> None:
    """``text=None`` (e.g. ``EMPTY_PAGE``) is preserved as ``None`` in the NodeDict."""
    node = Node(
        id="node_0001",
        category=SemanticCategory.EMPTY_PAGE,
        page_index=3,
        block_indices=(),
        text=None,
    )
    result = convert_document(Document(root=(node,)), _empty_extraction(), _profile(), "x.pdf")
    assert result.structure[0].text is None


def test_convert_level_none_for_non_heading() -> None:
    """``level=None`` for a non-heading category is preserved."""
    node = Node(
        id="node_0001",
        category=SemanticCategory.BODY,
        page_index=0,
        block_indices=(0,),
        text="body",
        level=None,
    )
    result = convert_document(Document(root=(node,)), _empty_extraction(), _profile(), "x.pdf")
    assert result.structure[0].level is None


def test_convert_merges_warnings_document_first_then_profile() -> None:
    """Warnings are concatenated in order: document.warnings then profile.warnings."""
    doc = Document(root=(), warnings=("a", "b"))
    profile = _profile(warnings=["c", "d"])
    result = convert_document(doc, _empty_extraction(), profile, "x.pdf")

    assert result.warnings == ["a", "b", "c", "d"]


def test_convert_generates_uuid_document_id() -> None:
    """``document_id`` is a UUID and changes across calls on the same input."""
    doc = Document(root=())
    a = convert_document(doc, _empty_extraction(), _profile(), "x.pdf")
    b = convert_document(doc, _empty_extraction(), _profile(), "x.pdf")

    assert isinstance(a.document_id, UUID)
    assert isinstance(b.document_id, UUID)
    assert a.document_id != b.document_id


def test_convert_schema_version_is_literal() -> None:
    """``schema_version`` is the v0.2.0 literal on every emission."""
    result = convert_document(Document(root=()), _empty_extraction(), _profile(), "x.pdf")
    assert result.schema_version == "0.3.0"


def test_convert_transformations_default_is_empty_list() -> None:
    """A ``Document`` with no transformations produces an empty list in the JSON."""
    result = convert_document(Document(root=()), _empty_extraction(), _profile(), "x.pdf")
    assert result.transformations == []


def test_convert_populates_transformations_field_by_field() -> None:
    """Each :class:`Transformation` is mapped field-by-field to a TransformationDict."""
    t1 = Transformation(
        step_id="dehyphenate_with_log",
        node_id="node_0001",
        page_index=0,
        position=(0, 12),
        original="evolu-\nzione",
        normalized="evoluzione",
    )
    t2 = Transformation(
        step_id="dehyphenate_with_log",
        node_id="node_0002",
        page_index=1,
        position=(30, 47),
        original="trasfor-\nmazione",
        normalized="trasformazione",
    )
    document = Document(root=(), transformations=(t1, t2))

    result = convert_document(document, _empty_extraction(), _profile(), "x.pdf")

    assert len(result.transformations) == 2
    first, second = result.transformations
    assert first.step_id == t1.step_id
    assert first.node_id == t1.node_id
    assert first.page_index == t1.page_index
    assert first.position == t1.position
    assert first.original == t1.original
    assert first.normalized == t1.normalized
    assert second.node_id == t2.node_id
    assert second.original == t2.original


def test_convert_extracts_basename_of_source_filename() -> None:
    """Only the basename of ``source_pdf_filename`` is retained in the metadata."""
    result = convert_document(
        Document(root=()),
        _empty_extraction(),
        _profile(),
        "/path/to/file.pdf",
    )
    assert result.metadata.source_pdf_filename == "file.pdf"


def test_convert_zero_pages_yields_origin_size_and_zero_count() -> None:
    """ExtractionResult with zero pages → page_size_pt=(0.0, 0.0), pages_pdf=0."""
    extraction = ExtractionResult(
        spans=[],
        blocks=[],
        page_geometries=[],
        page_images=[],
        drawings=[],
        warnings=[],
        page_count=0,
        is_encrypted=False,
        permissions=-1,
    )
    result = convert_document(Document(root=()), extraction, _profile(), "x.pdf")

    assert result.metadata.pages_pdf == 0
    assert result.metadata.page_size_pt == (0.0, 0.0)


def test_convert_page_size_taken_from_first_geometry() -> None:
    """``page_size_pt`` comes from ``extraction.page_geometries[0]``."""
    extraction = ExtractionResult(
        spans=[],
        blocks=[],
        page_geometries=[
            PageGeometry(page=0, width_pt=457.2, height_pt=684.0, rotation=0),
            PageGeometry(page=1, width_pt=999.9, height_pt=111.1, rotation=0),
        ],
        page_images=[],
        drawings=[],
        warnings=[],
        page_count=2,
        is_encrypted=False,
        permissions=-1,
    )
    result = convert_document(Document(root=()), extraction, _profile(), "x.pdf")

    assert result.metadata.page_size_pt == (457.2, 684.0)


def test_convert_profile_block_fields() -> None:
    """The profile block carries profile_id, editorial_family, genre, confidence."""
    profile = DocumentProfile(
        profile_id="manuale_giappichelli",
        editorial_family="giappichelli",
        genre="treatise",
        layouts_available=["L1"],
        layouts_disabled=[],
        post_processing=["merge_cross_page_notes"],
        categories_emitted={SemanticCategory.HEADING_1, SemanticCategory.BODY},
        confidence=0.94,
        warnings=[],
    )
    result = convert_document(Document(root=()), _empty_extraction(), profile, "x.pdf")

    assert result.profile.profile_id == "manuale_giappichelli"
    assert result.profile.editorial_family == "giappichelli"
    assert result.profile.genre == "treatise"
    assert result.profile.confidence == 0.94


def test_convert_uses_extraction_blocks_indirectly() -> None:
    """convert_document is structurally stable even when extraction has real blocks.

    Sanity smoke test that ``ExtractionResult`` with non-empty blocks/spans
    is accepted; the converter only reads ``page_count`` and
    ``page_geometries`` from extraction, so those blocks are not exercised
    directly here.
    """
    span = Span(
        text="hello",
        font="Helvetica",
        size=12.0,
        flags=0,
        color=0,
        bbox=(0, 0, 10, 10),
        page=0,
        block_index=0,
        line_index=0,
        span_index=0,
    )
    block = Block(page=0, block_index=0, bbox=(0, 0, 10, 10), span_range=(0, 1))
    extraction = ExtractionResult(
        spans=[span],
        blocks=[block],
        page_geometries=[PageGeometry(page=0, width_pt=595.0, height_pt=842.0, rotation=0)],
        page_images=[],
        drawings=[],
        warnings=[],
        page_count=1,
        is_encrypted=False,
        permissions=-1,
    )
    result = convert_document(Document(root=()), extraction, _profile(), "x.pdf")

    assert result.metadata.pages_pdf == 1
    assert result.metadata.page_size_pt == (595.0, 842.0)
