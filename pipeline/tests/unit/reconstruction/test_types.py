from dataclasses import FrozenInstanceError, fields

import pytest

from scabopdf_pipeline.reconstruction.types import Document, Node
from scabopdf_pipeline.schema.categories import SemanticCategory


def _leaf_node() -> Node:
    return Node(
        id="node_0000",
        category=SemanticCategory.BODY,
        page_index=0,
        block_indices=(0,),
        text="hello",
    )


def test_node_is_frozen() -> None:
    node = _leaf_node()
    with pytest.raises(FrozenInstanceError):
        node.id = "other"  # type: ignore[misc]


def test_document_is_frozen() -> None:
    document = Document()
    with pytest.raises(FrozenInstanceError):
        document.root = (_leaf_node(),)  # type: ignore[misc]


def test_node_has_all_expected_fields() -> None:
    names = {f.name for f in fields(Node)}
    assert names == {
        "id",
        "category",
        "children",
        "page_index",
        "block_indices",
        "text",
        "level",
        "summary_items",
        "apparatus_refs",
    }


def test_document_has_all_expected_fields() -> None:
    names = {f.name for f in fields(Document)}
    assert names == {"root", "warnings", "transformations"}


def test_node_defaults() -> None:
    node = Node(
        id="node_0001",
        category=SemanticCategory.HEADING_1,
        page_index=3,
    )
    assert node.children == ()
    assert node.block_indices == ()
    assert node.text is None
    assert node.level is None
    assert node.summary_items is None
    assert node.apparatus_refs == ()


def test_document_defaults() -> None:
    document = Document()
    assert document.root == ()
    assert document.warnings == ()


def test_node_is_kw_only() -> None:
    with pytest.raises(TypeError):
        Node("node_0000", SemanticCategory.BODY, 0)  # type: ignore[misc,call-arg,arg-type]


def test_document_is_kw_only() -> None:
    with pytest.raises(TypeError):
        Document((_leaf_node(),))  # type: ignore[misc]


def test_node_children_must_be_tuple() -> None:
    parent = Node(
        id="node_0001",
        category=SemanticCategory.HEADING_1,
        page_index=0,
        children=(_leaf_node(),),
        text="title",
        level=1,
    )
    assert isinstance(parent.children, tuple)
    assert parent.children[0].text == "hello"


def test_text_none_is_allowed_for_synthetic_nodes() -> None:
    node = Node(
        id="node_0002",
        category=SemanticCategory.EMPTY_PAGE,
        page_index=7,
        block_indices=(),
        text=None,
    )
    assert node.text is None
    assert node.block_indices == ()
