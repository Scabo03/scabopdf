"""Unit tests for ``postprocessing.types`` and the ``Document.transformations`` field."""

from __future__ import annotations

from dataclasses import FrozenInstanceError, fields

import pytest

from scabopdf_pipeline.postprocessing.types import Transformation
from scabopdf_pipeline.reconstruction.types import Document


def test_transformation_has_all_expected_fields() -> None:
    names = {f.name for f in fields(Transformation)}
    assert names == {
        "step_id",
        "node_id",
        "page_index",
        "position",
        "original",
        "normalized",
        "split_into",
        "merged_from",
    }


def test_transformation_is_frozen() -> None:
    t = Transformation(
        step_id="dehyphenate_with_log",
        node_id="node_0001",
        page_index=12,
        position=(0, 12),
        original="evolu-\nzione",
        normalized="evoluzione",
    )
    with pytest.raises(FrozenInstanceError):
        t.original = "other"  # type: ignore[misc]


def test_transformation_is_kw_only() -> None:
    with pytest.raises(TypeError):
        Transformation(  # type: ignore[misc]
            "dehyphenate_with_log",
            "node_0001",
            12,
            (0, 12),
            "evolu-\nzione",
            "evoluzione",
        )


def test_transformation_roundtrips_via_construction() -> None:
    t = Transformation(
        step_id="dehyphenate_with_log",
        node_id="node_0042",
        page_index=3,
        position=(10, 22),
        original="trasfor-\nmazione",
        normalized="trasformazione",
    )
    assert t.step_id == "dehyphenate_with_log"
    assert t.node_id == "node_0042"
    assert t.page_index == 3
    assert t.position == (10, 22)
    assert t.original == "trasfor-\nmazione"
    assert t.normalized == "trasformazione"


def test_document_transformations_default_is_empty_tuple() -> None:
    document = Document()
    assert document.transformations == ()
    assert isinstance(document.transformations, tuple)


def test_document_transformations_can_be_set_at_construction() -> None:
    t = Transformation(
        step_id="dehyphenate_with_log",
        node_id="node_0001",
        page_index=0,
        position=(0, 12),
        original="evolu-\nzione",
        normalized="evoluzione",
    )
    document = Document(transformations=(t,))
    assert document.transformations == (t,)


def test_document_is_frozen_on_transformations_too() -> None:
    document = Document()
    with pytest.raises(FrozenInstanceError):
        document.transformations = ()  # type: ignore[misc]


def test_transformation_structural_fields_default_to_none() -> None:
    """Schema 0.5.0 added ``split_into`` and ``merged_from`` as optional.

    Steps performing purely textual rewrites (``dehyphenate_with_log``)
    construct ``Transformation`` without naming the structural fields;
    both default to ``None`` so downstream consumers can branch on
    presence without writing default-handling boilerplate.
    """
    t = Transformation(
        step_id="dehyphenate_with_log",
        node_id="node_0001",
        page_index=0,
        position=(0, 12),
        original="evolu-\nzione",
        normalized="evoluzione",
    )
    assert t.split_into is None
    assert t.merged_from is None


def test_transformation_accepts_split_into_tuple() -> None:
    """Structural transformations populate ``split_into`` with synthetic ids."""
    t = Transformation(
        step_id="giappichelli_body_note_splitter",
        node_id="node_0100",
        page_index=42,
        position=(120, 280),
        original="...embedded note text...",
        normalized="",
        split_into=("node_2000", "node_2001"),
    )
    assert t.split_into == ("node_2000", "node_2001")
    assert t.merged_from is None


def test_transformation_accepts_merged_from_tuple() -> None:
    """Structural transformations populate ``merged_from`` with absorbed ids."""
    t = Transformation(
        step_id="merge_cross_page_notes",
        node_id="node_0050",
        page_index=10,
        position=(80, 80),
        original="",
        normalized=" continuation text",
        merged_from=("node_0080",),
    )
    assert t.merged_from == ("node_0080",)
    assert t.split_into is None
