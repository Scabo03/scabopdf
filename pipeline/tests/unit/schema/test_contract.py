"""Unit tests for the v0.3.0 Pydantic contract models."""

from __future__ import annotations

from uuid import UUID, uuid4

import pytest
from pydantic import ValidationError

from scabopdf_pipeline.apparatus.types import ApparatusRefKind
from scabopdf_pipeline.schema.categories import SemanticCategory
from scabopdf_pipeline.schema.contract import (
    ApparatusRefDict,
    DocumentMetadata,
    DocumentProfileDict,
    NodeDict,
    ScabopdfDocument,
    TransformationDict,
)


def _minimal_document() -> ScabopdfDocument:
    return ScabopdfDocument(
        schema_version="0.3.0",
        document_id=uuid4(),
        metadata=DocumentMetadata(
            pages_pdf=10,
            page_size_pt=(457.2, 684.0),
            source_pdf_filename="sample.pdf",
        ),
        profile=DocumentProfileDict(
            profile_id="manuale_giappichelli",
            editorial_family="giappichelli",
            genre="treatise",
            confidence=0.94,
        ),
    )


def test_minimal_document_validates() -> None:
    doc = _minimal_document()
    assert isinstance(doc, ScabopdfDocument)
    assert doc.schema_version == "0.3.0"
    assert doc.warnings == []
    assert doc.structure == []


def test_missing_required_field_raises() -> None:
    with pytest.raises(ValidationError):
        ScabopdfDocument.model_validate(
            {
                "schema_version": "0.3.0",
                "document_id": str(uuid4()),
                "metadata": {
                    "pages_pdf": 10,
                    "page_size_pt": [457.2, 684.0],
                    "source_pdf_filename": "sample.pdf",
                },
            }
        )


def test_recursive_node_tree_validates() -> None:
    leaf = NodeDict(id="node_0003", type=SemanticCategory.BODY, page_index=0, text="leaf")
    inner = NodeDict(
        id="node_0002",
        type=SemanticCategory.HEADING_2,
        page_index=0,
        text="inner",
        level=2,
        children=[leaf],
    )
    root = NodeDict(
        id="node_0001",
        type=SemanticCategory.HEADING_1,
        page_index=0,
        text="root",
        level=1,
        children=[inner],
    )
    assert root.children[0].children[0].text == "leaf"


def test_node_id_pattern_rejects_bad_format() -> None:
    with pytest.raises(ValidationError):
        NodeDict.model_validate(
            {
                "id": "node-0001",
                "type": "BODY",
                "page_index": 0,
            }
        )
    with pytest.raises(ValidationError):
        NodeDict.model_validate(
            {
                "id": "0001",
                "type": "BODY",
                "page_index": 0,
            }
        )


def test_node_id_pattern_accepts_variable_length() -> None:
    short = NodeDict(id="node_1", type=SemanticCategory.BODY, page_index=0, text="x")
    long_ = NodeDict(id="node_123456", type=SemanticCategory.BODY, page_index=0, text="x")
    assert short.id == "node_1"
    assert long_.id == "node_123456"


def test_apparatus_ref_valid_kind() -> None:
    ref = ApparatusRefDict(
        kind=ApparatusRefKind.CROSS_REF_TARGET,
        target_node_id="node_0042",
        source_marker="(1)",
    )
    assert ref.kind == ApparatusRefKind.CROSS_REF_TARGET
    assert ref.target_node_id == "node_0042"


def test_apparatus_ref_invalid_kind_raises() -> None:
    with pytest.raises(ValidationError):
        ApparatusRefDict.model_validate(
            {
                "kind": "INVALID_KIND",
                "target_node_id": "node_0042",
            }
        )


def test_apparatus_ref_invalid_target_id_pattern_raises() -> None:
    with pytest.raises(ValidationError):
        ApparatusRefDict.model_validate(
            {
                "kind": "CROSS_REF_TARGET",
                "target_node_id": "n0042",
            }
        )


def test_schema_version_literal_rejects_other_strings() -> None:
    with pytest.raises(ValidationError):
        ScabopdfDocument.model_validate(
            {
                "schema_version": "0.2.0",
                "document_id": str(uuid4()),
                "metadata": {
                    "pages_pdf": 10,
                    "page_size_pt": [457.2, 684.0],
                    "source_pdf_filename": "sample.pdf",
                },
                "profile": {
                    "profile_id": "p",
                    "editorial_family": "e",
                    "genre": "g",
                    "confidence": 0.5,
                },
            }
        )


def test_round_trip_dump_validate_equivalence() -> None:
    original = _minimal_document()
    dumped = original.model_dump(mode="json")
    rebuilt = ScabopdfDocument.model_validate(dumped)
    assert rebuilt == original


def test_extra_fields_forbidden() -> None:
    with pytest.raises(ValidationError):
        ScabopdfDocument.model_validate(
            {
                "schema_version": "0.3.0",
                "document_id": str(uuid4()),
                "metadata": {
                    "pages_pdf": 10,
                    "page_size_pt": [457.2, 684.0],
                    "source_pdf_filename": "sample.pdf",
                },
                "profile": {
                    "profile_id": "p",
                    "editorial_family": "e",
                    "genre": "g",
                    "confidence": 0.5,
                },
                "unexpected_extra": "rejected",
            }
        )


def test_document_id_accepts_uuid_string() -> None:
    raw = str(uuid4())
    doc = ScabopdfDocument.model_validate(
        {
            "schema_version": "0.3.0",
            "document_id": raw,
            "metadata": {
                "pages_pdf": 10,
                "page_size_pt": [457.2, 684.0],
                "source_pdf_filename": "sample.pdf",
            },
            "profile": {
                "profile_id": "p",
                "editorial_family": "e",
                "genre": "g",
                "confidence": 0.5,
            },
        }
    )
    assert isinstance(doc.document_id, UUID)
    assert str(doc.document_id) == raw


def test_document_id_rejects_non_uuid_string() -> None:
    with pytest.raises(ValidationError):
        ScabopdfDocument.model_validate(
            {
                "schema_version": "0.3.0",
                "document_id": "not-a-uuid",
                "metadata": {
                    "pages_pdf": 10,
                    "page_size_pt": [457.2, 684.0],
                    "source_pdf_filename": "sample.pdf",
                },
                "profile": {
                    "profile_id": "p",
                    "editorial_family": "e",
                    "genre": "g",
                    "confidence": 0.5,
                },
            }
        )


def test_confidence_out_of_range_rejected() -> None:
    with pytest.raises(ValidationError):
        DocumentProfileDict.model_validate(
            {
                "profile_id": "p",
                "editorial_family": "e",
                "genre": "g",
                "confidence": 1.5,
            }
        )
    with pytest.raises(ValidationError):
        DocumentProfileDict.model_validate(
            {
                "profile_id": "p",
                "editorial_family": "e",
                "genre": "g",
                "confidence": -0.1,
            }
        )


def test_page_size_pt_requires_exactly_two_floats() -> None:
    with pytest.raises(ValidationError):
        DocumentMetadata.model_validate(
            {
                "pages_pdf": 1,
                "page_size_pt": [457.2],
                "source_pdf_filename": "x.pdf",
            }
        )
    with pytest.raises(ValidationError):
        DocumentMetadata.model_validate(
            {
                "pages_pdf": 1,
                "page_size_pt": [1.0, 2.0, 3.0],
                "source_pdf_filename": "x.pdf",
            }
        )


def test_transformation_dict_round_trip() -> None:
    t = TransformationDict(
        step_id="dehyphenate_with_log",
        node_id="node_0042",
        page_index=12,
        position=(1234, 1246),
        original="evolu-\nzione",
        normalized="evoluzione",
    )
    dumped = t.model_dump(mode="json")
    assert dumped["step_id"] == "dehyphenate_with_log"
    assert dumped["node_id"] == "node_0042"
    assert dumped["page_index"] == 12
    assert dumped["position"] == [1234, 1246]
    assert dumped["original"] == "evolu-\nzione"
    assert dumped["normalized"] == "evoluzione"
    rebuilt = TransformationDict.model_validate(dumped)
    assert rebuilt == t


def test_transformation_dict_rejects_bad_node_id_pattern() -> None:
    with pytest.raises(ValidationError):
        TransformationDict.model_validate(
            {
                "step_id": "dehyphenate_with_log",
                "node_id": "n0042",
                "page_index": 0,
                "position": [0, 12],
                "original": "evolu-\nzione",
                "normalized": "evoluzione",
            }
        )


def test_transformation_dict_position_requires_two_ints() -> None:
    with pytest.raises(ValidationError):
        TransformationDict.model_validate(
            {
                "step_id": "dehyphenate_with_log",
                "node_id": "node_0042",
                "page_index": 0,
                "position": [0],
                "original": "evolu-\nzione",
                "normalized": "evoluzione",
            }
        )
    with pytest.raises(ValidationError):
        TransformationDict.model_validate(
            {
                "step_id": "dehyphenate_with_log",
                "node_id": "node_0042",
                "page_index": 0,
                "position": [0, 12, 24],
                "original": "evolu-\nzione",
                "normalized": "evoluzione",
            }
        )


def test_scabopdf_document_transformations_default_is_empty_list() -> None:
    doc = _minimal_document()
    assert doc.transformations == []


def test_scabopdf_document_accepts_transformations_field() -> None:
    t = TransformationDict(
        step_id="dehyphenate_with_log",
        node_id="node_0001",
        page_index=0,
        position=(0, 12),
        original="evolu-\nzione",
        normalized="evoluzione",
    )
    doc = ScabopdfDocument(
        schema_version="0.3.0",
        document_id=uuid4(),
        metadata=DocumentMetadata(
            pages_pdf=1,
            page_size_pt=(457.2, 684.0),
            source_pdf_filename="sample.pdf",
        ),
        profile=DocumentProfileDict(
            profile_id="p",
            editorial_family="e",
            genre="g",
            confidence=0.5,
        ),
        transformations=[t],
    )
    assert doc.transformations == [t]
