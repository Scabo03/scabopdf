from dataclasses import FrozenInstanceError, fields

import pytest

from scabopdf_pipeline.apparatus.types import ApparatusRef, ApparatusRefKind
from scabopdf_pipeline.reconstruction.types import Node
from scabopdf_pipeline.schema.categories import SemanticCategory


def test_apparatus_ref_kind_values() -> None:
    assert ApparatusRefKind.CROSS_REF_TARGET == "CROSS_REF_TARGET"
    assert ApparatusRefKind.BODY_ASSOCIATION == "BODY_ASSOCIATION"
    assert ApparatusRefKind.GLOSS_TARGET == "GLOSS_TARGET"


def test_apparatus_ref_is_frozen() -> None:
    ref = ApparatusRef(
        kind=ApparatusRefKind.CROSS_REF_TARGET,
        target_node_id="node_0001",
        source_marker="(1)",
    )
    with pytest.raises(FrozenInstanceError):
        ref.target_node_id = "node_0002"  # type: ignore[misc]


def test_apparatus_ref_is_kw_only() -> None:
    with pytest.raises(TypeError):
        ApparatusRef(ApparatusRefKind.CROSS_REF_TARGET, "node_0001")  # type: ignore[misc]


def test_apparatus_ref_source_marker_default_is_none() -> None:
    ref = ApparatusRef(
        kind=ApparatusRefKind.BODY_ASSOCIATION,
        target_node_id="node_0001",
    )
    assert ref.source_marker is None


def test_apparatus_ref_has_expected_fields() -> None:
    names = {f.name for f in fields(ApparatusRef)}
    assert names == {"kind", "target_node_id", "source_marker"}


def test_node_has_apparatus_refs_field() -> None:
    names = {f.name for f in fields(Node)}
    assert "apparatus_refs" in names


def test_node_apparatus_refs_default_is_empty_tuple() -> None:
    node = Node(
        id="node_0000",
        category=SemanticCategory.BODY,
        page_index=0,
    )
    assert node.apparatus_refs == ()


def test_node_apparatus_refs_must_be_tuple() -> None:
    ref = ApparatusRef(
        kind=ApparatusRefKind.CROSS_REF_TARGET,
        target_node_id="node_0099",
        source_marker="(1)",
    )
    node = Node(
        id="node_0000",
        category=SemanticCategory.CROSS_REFERENCE,
        page_index=0,
        apparatus_refs=(ref,),
    )
    assert isinstance(node.apparatus_refs, tuple)
    assert node.apparatus_refs[0] is ref
