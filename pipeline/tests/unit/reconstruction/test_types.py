from dataclasses import FrozenInstanceError, fields

import pytest

from scabopdf_pipeline.reconstruction.types import (
    Document,
    Node,
    compute_note_length_category,
)
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
        "toc_items",
        "length_category",
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
    assert node.toc_items is None
    assert node.length_category is None
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


class TestComputeNoteLengthCategory:
    """Exhaustive coverage of the schema 0.6.0 helper.

    The thresholds are documented in
    :func:`compute_note_length_category` and in ``docs/SCHEMA_v0.6.0.md``:

    - ``MICRO``      —   0 ≤ n <   50
    - ``SHORT``      —  50 ≤ n <  100
    - ``MEDIUM``     — 100 ≤ n <  500
    - ``LONG``       — 500 ≤ n < 1000
    - ``VERY_LONG``  — 1000 ≤ n < 3000
    - ``MEGA``       — n ≥ 3000

    The helper strips the leading ``(N)`` or ``N`` marker before
    measuring, so a "(42) " prefix does not inflate the bucket choice.
    """

    def test_none_returns_none(self) -> None:
        assert compute_note_length_category(None) is None

    def test_empty_string_returns_none(self) -> None:
        assert compute_note_length_category("") is None

    def test_pure_marker_returns_none(self) -> None:
        # Just "(1) " gets stripped to empty, hence None.
        assert compute_note_length_category("(1) ") is None

    def test_marker_with_one_char_is_micro(self) -> None:
        assert compute_note_length_category("(1) X") == "MICRO"

    @pytest.mark.parametrize("text_length", [1, 25, 49])
    def test_micro_boundaries(self, text_length: int) -> None:
        assert compute_note_length_category("a" * text_length) == "MICRO"

    @pytest.mark.parametrize("text_length", [50, 75, 99])
    def test_short_boundaries(self, text_length: int) -> None:
        assert compute_note_length_category("a" * text_length) == "SHORT"

    @pytest.mark.parametrize("text_length", [100, 250, 499])
    def test_medium_boundaries(self, text_length: int) -> None:
        assert compute_note_length_category("a" * text_length) == "MEDIUM"

    @pytest.mark.parametrize("text_length", [500, 750, 999])
    def test_long_boundaries(self, text_length: int) -> None:
        assert compute_note_length_category("a" * text_length) == "LONG"

    @pytest.mark.parametrize("text_length", [1000, 2000, 2999])
    def test_very_long_boundaries(self, text_length: int) -> None:
        assert compute_note_length_category("a" * text_length) == "VERY_LONG"

    @pytest.mark.parametrize("text_length", [3000, 5000, 121399])
    def test_mega_boundaries(self, text_length: int) -> None:
        assert compute_note_length_category("a" * text_length) == "MEGA"

    def test_marker_strip_preserves_post_marker_length(self) -> None:
        # "(99) " is 5 chars; the 50-char body must be measured at 50.
        body = "x" * 50
        assert compute_note_length_category("(99) " + body) == "SHORT"

    def test_bare_marker_form_stripped(self) -> None:
        # The bare "1 " form (Mosconi pattern after marker stripping)
        # is also recognised by the strip regex.
        body = "y" * 50
        assert compute_note_length_category("1 " + body) == "SHORT"

    def test_no_marker_text_not_stripped(self) -> None:
        # Plain text without a leading marker is measured as-is.
        assert compute_note_length_category("plain text without marker") == "MICRO"
