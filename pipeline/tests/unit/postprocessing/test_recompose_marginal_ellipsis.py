"""Unit tests for the recompose_marginal_ellipsis post-processing step."""

from __future__ import annotations

from scabopdf_pipeline.extraction.types import ExtractionResult
from scabopdf_pipeline.postprocessing.steps.recompose_marginal_ellipsis import (
    STEP_ID,
    recompose_marginal_ellipsis,
)
from scabopdf_pipeline.reconstruction.types import Document, Node
from scabopdf_pipeline.schema.categories import SemanticCategory

# ---------------------------------------------------------------------------
# Helpers


def _empty_extraction() -> ExtractionResult:
    return ExtractionResult(
        spans=[],
        blocks=[],
        page_geometries=[],
        page_images=[],
        drawings=[],
        warnings=[],
        page_count=0,
        is_encrypted=False,
        permissions=0,
    )


def _marginal(
    node_id: str,
    text: str,
    *,
    page_index: int = 0,
    block_indices: tuple[int, ...] = (0,),
) -> Node:
    return Node(
        id=node_id,
        category=SemanticCategory.MARGINAL_HEADING,
        page_index=page_index,
        block_indices=block_indices,
        text=text,
    )


def _body(node_id: str, text: str, page_index: int = 0) -> Node:
    return Node(
        id=node_id,
        category=SemanticCategory.BODY,
        page_index=page_index,
        block_indices=(0,),
        text=text,
    )


def _heading(node_id: str, text: str, children: tuple[Node, ...] = ()) -> Node:
    return Node(
        id=node_id,
        category=SemanticCategory.HEADING_2,
        page_index=0,
        block_indices=(0,),
        text=text,
        level=2,
        children=children,
    )


def _run(document: Document) -> tuple[Document, ...]:
    """Apply the step and return both the new document and its transformations."""
    new_doc, transformations = recompose_marginal_ellipsis(document, _empty_extraction(), [])
    return new_doc, transformations  # type: ignore[return-value]


# ---------------------------------------------------------------------------
# Identity & no-op


def test_empty_document_returns_identity() -> None:
    document = Document()
    new_doc, transformations = recompose_marginal_ellipsis(document, _empty_extraction(), [])
    assert new_doc is document
    assert transformations == ()


def test_document_without_marginals_returns_identity() -> None:
    document = Document(root=(_body("node_0001", "Plain prose body."),))
    new_doc, transformations = recompose_marginal_ellipsis(document, _empty_extraction(), [])
    assert new_doc is document
    assert transformations == ()


def test_marginal_pair_without_ellipsis_left_alone() -> None:
    document = Document(
        root=(
            _marginal("node_0001", "First marginal heading."),
            _marginal("node_0002", "Second marginal heading."),
        )
    )
    new_doc, transformations = recompose_marginal_ellipsis(document, _empty_extraction(), [])
    assert new_doc is document
    assert transformations == ()


def test_orphan_trailing_ellipsis_left_alone() -> None:
    """A head segment ending with '...' but no continuation is left as is."""
    document = Document(
        root=(
            _marginal("node_0001", "Foo bar..."),
            _body("node_0002", "Body paragraph that follows."),
        )
    )
    new_doc, transformations = recompose_marginal_ellipsis(document, _empty_extraction(), [])
    assert new_doc is document
    assert transformations == ()


def test_orphan_leading_ellipsis_left_alone() -> None:
    """A segment starting with '...' without a preceding ending '...' is left as is."""
    document = Document(
        root=(
            _marginal("node_0001", "Foo bar."),
            _marginal("node_0002", "...baz qux"),
        )
    )
    new_doc, transformations = recompose_marginal_ellipsis(document, _empty_extraction(), [])
    assert new_doc is document
    assert transformations == ()


def test_open_chain_without_terminator_left_alone() -> None:
    """A chain where every following segment also ends with '...' (no terminator) is not merged."""
    document = Document(
        root=(
            _marginal("node_0001", "Foo bar..."),
            _marginal("node_0002", "...baz qux..."),
        )
    )
    new_doc, transformations = recompose_marginal_ellipsis(document, _empty_extraction(), [])
    assert new_doc is document
    assert transformations == ()


# ---------------------------------------------------------------------------
# Pair merge


def test_simple_pair_merges_and_logs_transformation() -> None:
    """A head ending in '...' and a terminator starting in '...' fuse into one node."""
    head = _marginal("node_0001", "Foo bar...", page_index=4, block_indices=(10,))
    tail = _marginal("node_0002", "...baz qux", page_index=5, block_indices=(20,))
    document = Document(root=(head, tail))

    new_doc, transformations = recompose_marginal_ellipsis(document, _empty_extraction(), [])

    assert new_doc is not document
    assert len(new_doc.root) == 1
    merged = new_doc.root[0]
    assert merged.id == "node_0001"
    assert merged.category is SemanticCategory.MARGINAL_HEADING
    assert merged.text == "Foo bar baz qux"
    assert merged.page_index == 4
    assert merged.block_indices == (10, 20)

    assert len(transformations) == 1
    transformation = transformations[0]
    assert transformation.step_id == STEP_ID
    assert transformation.node_id == "node_0001"
    assert transformation.page_index == 4
    # Position covers the trailing '...' in the pre-step head text "Foo bar..."
    assert transformation.position == (7, 10)
    assert transformation.original == "..."
    assert transformation.normalized == " baz qux"
    # Schema 0.5.0 structural reversibility: the absorbed segment id is
    # recorded on ``merged_from`` so Layer 2 can rematerialise it.
    assert transformation.merged_from == ("node_0002",)
    assert transformation.split_into is None


def test_pair_merge_reversibility_property() -> None:
    """Applying the transformation in reverse restores the head text exactly."""
    head_text = "Premessa..."
    tail_text = "...al titolo"
    head = _marginal("node_0001", head_text)
    tail = _marginal("node_0002", tail_text)
    document = Document(root=(head, tail))

    new_doc, transformations = recompose_marginal_ellipsis(document, _empty_extraction(), [])
    merged = new_doc.root[0]
    transformation = transformations[0]

    # Reversibility convention: post[position[0] : position[0] + len(normalized)] == normalized
    assert merged.text is not None
    assert (
        merged.text[
            transformation.position[0] : transformation.position[0] + len(transformation.normalized)
        ]
        == transformation.normalized
    )
    # And substituting original back yields pre-step head text.
    pre = (
        merged.text[: transformation.position[0]]
        + transformation.original
        + merged.text[transformation.position[0] + len(transformation.normalized) :]
    )
    assert pre == head_text


def test_pair_merge_strips_adjacent_whitespace() -> None:
    """Whitespace adjacent to the '...' markers is absorbed by the strip regex."""
    head = _marginal("node_0001", "Foo bar  ...  ")
    tail = _marginal("node_0002", "  ...  baz qux")
    document = Document(root=(head, tail))

    new_doc, transformations = recompose_marginal_ellipsis(document, _empty_extraction(), [])
    merged = new_doc.root[0]
    assert merged.text == "Foo bar baz qux"
    assert len(transformations) == 1


# ---------------------------------------------------------------------------
# Chains of 3+


def test_chain_of_three_merges_into_one_node() -> None:
    """A 3-segment chain (head + middle + terminal) fuses into a single node."""
    head = _marginal("node_0001", "Inizio frase...", page_index=10, block_indices=(100,))
    middle = _marginal("node_0002", "...metà frase...", page_index=11, block_indices=(101,))
    terminal = _marginal("node_0003", "...fine frase", page_index=12, block_indices=(102,))
    document = Document(root=(head, middle, terminal))

    new_doc, transformations = recompose_marginal_ellipsis(document, _empty_extraction(), [])
    assert len(new_doc.root) == 1
    merged = new_doc.root[0]
    assert merged.text == "Inizio frase metà frase fine frase"
    assert merged.block_indices == (100, 101, 102)
    assert merged.id == "node_0001"
    assert merged.page_index == 10

    assert len(transformations) == 1
    transformation = transformations[0]
    assert transformation.position == (12, 15)
    assert transformation.original == "..."
    assert transformation.normalized == " metà frase fine frase"
    # Schema 0.5.0: the two absorbed segment ids appear in chain order.
    assert transformation.merged_from == ("node_0002", "node_0003")
    assert transformation.split_into is None


def test_chain_of_four_merges_into_one_node() -> None:
    """A 4-segment chain (head + two middles + terminal) fuses correctly."""
    nodes = (
        _marginal("node_0001", "A..."),
        _marginal("node_0002", "...B..."),
        _marginal("node_0003", "...C..."),
        _marginal("node_0004", "...D"),
    )
    document = Document(root=nodes)

    new_doc, transformations = recompose_marginal_ellipsis(document, _empty_extraction(), [])
    assert len(new_doc.root) == 1
    assert new_doc.root[0].text == "A B C D"
    assert len(transformations) == 1


# ---------------------------------------------------------------------------
# Multiple chains, mixed content


def test_two_independent_chains_in_one_document() -> None:
    """Two unrelated ellipsis pairs both fuse, yielding two transformations."""
    document = Document(
        root=(
            _marginal("node_0001", "Alpha..."),
            _marginal("node_0002", "...beta"),
            _body("node_0003", "Some intervening body."),
            _marginal("node_0004", "Gamma..."),
            _marginal("node_0005", "...delta"),
        )
    )

    new_doc, transformations = recompose_marginal_ellipsis(document, _empty_extraction(), [])
    assert len(new_doc.root) == 3
    assert new_doc.root[0].text == "Alpha beta"
    assert new_doc.root[1].text == "Some intervening body."
    assert new_doc.root[1].category is SemanticCategory.BODY
    assert new_doc.root[2].text == "Gamma delta"
    assert len(transformations) == 2
    assert transformations[0].node_id == "node_0001"
    assert transformations[1].node_id == "node_0004"


def test_chain_with_non_marginal_intervening_node_still_merges() -> None:
    """A non-marginal node between two marginals does not break the chain.

    The step walks marginals in DFS pre-order across the whole tree
    and pairs any head ending in ``...`` with the next marginal in
    reading order starting with ``...``. Intervening body / heading
    nodes are skipped: the editorial continuation marker is a
    typographic layout cue that crosses semantic boundaries between
    consecutive paragraphs in the Mosconi treatise.
    """
    document = Document(
        root=(
            _marginal("node_0001", "Foo bar..."),
            _body("node_0002", "Body paragraph."),
            _marginal("node_0003", "...baz qux"),
        )
    )
    new_doc, transformations = recompose_marginal_ellipsis(document, _empty_extraction(), [])
    assert new_doc is not document
    assert len(transformations) == 1
    merged = new_doc.root[0]
    assert merged.text == "Foo bar baz qux"
    # The body sibling and the absorbed marginal are gone from the root.
    assert len(new_doc.root) == 2
    assert new_doc.root[1].id == "node_0002"
    assert new_doc.root[1].category is SemanticCategory.BODY


# ---------------------------------------------------------------------------
# Nested trees


def test_chain_inside_heading_subtree_is_merged() -> None:
    """Recursion into a HEADING's children merges ellipsis chains there."""
    chain = (
        _marginal("node_0002", "Tassativi..."),
        _marginal("node_0003", "...elementi"),
    )
    heading = _heading("node_0001", "Capitolo I", children=chain)
    document = Document(root=(heading,))

    new_doc, transformations = recompose_marginal_ellipsis(document, _empty_extraction(), [])
    assert len(new_doc.root) == 1
    new_heading = new_doc.root[0]
    assert new_heading.id == "node_0001"
    assert new_heading.category is SemanticCategory.HEADING_2
    assert len(new_heading.children) == 1
    assert new_heading.children[0].text == "Tassativi elementi"
    assert len(transformations) == 1
    assert transformations[0].node_id == "node_0002"


def test_chains_across_different_parents_are_merged() -> None:
    """An ellipsis head under one parent pairs with a tail under another.

    Real Mosconi continuations cross sibling boundaries: the head
    segment can live under one HEADING_3 paragraph and the terminal
    segment under the next HEADING_3 paragraph, because the typesetter
    breaks the marginal phrase across the page boundary that happens
    to coincide with the paragraph transition. The flat reading-order
    walk catches the pair regardless of tree position; the head node
    keeps its tree position and the absorbed segment is removed from
    its (different) parent.
    """
    parent_a = _heading(
        "node_0001",
        "Chapter A",
        children=(_marginal("node_0002", "Trailing..."),),
    )
    parent_b = _heading(
        "node_0003",
        "Chapter B",
        children=(_marginal("node_0004", "...leading"),),
    )
    document = Document(root=(parent_a, parent_b))

    new_doc, transformations = recompose_marginal_ellipsis(document, _empty_extraction(), [])
    assert new_doc is not document
    assert len(transformations) == 1
    # The head node stayed under Chapter A with merged text;
    # the absorbed segment was removed from Chapter B.
    chapter_a = new_doc.root[0]
    chapter_b = new_doc.root[1]
    assert chapter_a.id == "node_0001"
    assert chapter_b.id == "node_0003"
    assert len(chapter_a.children) == 1
    assert chapter_a.children[0].id == "node_0002"
    assert chapter_a.children[0].text == "Trailing leading"
    assert chapter_b.children == ()


# ---------------------------------------------------------------------------
# Document.warnings & transformations preservation


def test_step_preserves_document_warnings() -> None:
    """Pre-existing warnings on the document survive the step."""
    document = Document(
        root=(
            _marginal("node_0001", "Foo..."),
            _marginal("node_0002", "...bar"),
        ),
        warnings=("plugin:test:something",),
    )
    new_doc, _ = recompose_marginal_ellipsis(document, _empty_extraction(), [])
    assert new_doc.warnings == ("plugin:test:something",)


def test_step_preserves_pre_existing_transformations() -> None:
    """Pre-existing transformations on the document survive the step.

    The orchestrator accumulates transformations across steps by
    concatenating the per-step tuples; the step itself does not
    duplicate them. ``dataclasses.replace`` on ``Document`` preserves
    the ``transformations`` field automatically when the step rebuilds
    the document.
    """
    from scabopdf_pipeline.postprocessing.types import Transformation

    earlier = Transformation(
        step_id="dehyphenate_with_log",
        node_id="node_other",
        page_index=0,
        position=(0, 1),
        original="a",
        normalized="b",
    )
    document = Document(
        root=(
            _marginal("node_0001", "Foo..."),
            _marginal("node_0002", "...bar"),
        ),
        transformations=(earlier,),
    )
    new_doc, _ = recompose_marginal_ellipsis(document, _empty_extraction(), [])
    assert new_doc.transformations == (earlier,)
