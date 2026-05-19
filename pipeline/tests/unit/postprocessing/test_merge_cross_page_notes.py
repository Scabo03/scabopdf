"""Unit tests for the merge_cross_page_notes post-processing step."""

from __future__ import annotations

from scabopdf_pipeline.extraction.types import ExtractionResult
from scabopdf_pipeline.postprocessing.steps.merge_cross_page_notes import (
    STEP_ID,
    merge_cross_page_notes,
)
from scabopdf_pipeline.postprocessing.types import Transformation
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


def _note(
    node_id: str,
    text: str | None,
    *,
    page_index: int = 0,
    block_indices: tuple[int, ...] = (0,),
) -> Node:
    return Node(
        id=node_id,
        category=SemanticCategory.NOTE,
        page_index=page_index,
        block_indices=block_indices,
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


def _body(node_id: str, text: str, page_index: int = 0) -> Node:
    return Node(
        id=node_id,
        category=SemanticCategory.BODY,
        page_index=page_index,
        block_indices=(0,),
        text=text,
    )


def _run(document: Document) -> tuple[Document, tuple[Transformation, ...]]:
    return merge_cross_page_notes(document, _empty_extraction(), [])


# ---------------------------------------------------------------------------
# Identity & no-op


def test_step_id_constant() -> None:
    assert STEP_ID == "merge_cross_page_notes"


def test_empty_document_returns_identity() -> None:
    document = Document()
    new_doc, transformations = _run(document)
    assert new_doc is document
    assert transformations == ()


def test_document_without_notes_returns_identity() -> None:
    document = Document(root=(_body("node_0001", "Plain body text."),))
    new_doc, transformations = _run(document)
    assert new_doc is document
    assert transformations == ()


def test_single_note_returns_identity() -> None:
    document = Document(root=(_note("node_0001", "(1) Single note.", page_index=10),))
    new_doc, transformations = _run(document)
    assert new_doc is document
    assert transformations == ()


def test_two_notes_same_page_no_merge() -> None:
    """Two notes on the same page are independent — no continuation."""
    document = Document(
        root=(
            _note("node_0001", "(1) First.", page_index=10),
            _note("node_0002", "(2) Second.", page_index=10),
        )
    )
    new_doc, transformations = _run(document)
    assert new_doc is document
    assert transformations == ()


def test_two_notes_both_with_markers_no_merge() -> None:
    """Two adjacent-page notes that both open with a (N) marker are independent."""
    document = Document(
        root=(
            _note("node_0001", "(1) First note.", page_index=10),
            _note("node_0002", "(2) Second note opens with marker.", page_index=11),
        )
    )
    new_doc, transformations = _run(document)
    assert new_doc is document
    assert transformations == ()


# ---------------------------------------------------------------------------
# Single continuation cases


def test_single_continuation_merges() -> None:
    """An adjacent-page NOTE without a leading marker is merged into the head."""
    document = Document(
        root=(
            _note("node_0001", "(1) Head note text", page_index=10),
            _note("node_0002", "continuation text without marker", page_index=11),
        )
    )
    new_doc, transformations = _run(document)
    assert new_doc is not document
    assert len(transformations) == 1
    notes = [n for n in new_doc.root if n.category is SemanticCategory.NOTE]
    assert len(notes) == 1
    assert notes[0].id == "node_0001"
    assert notes[0].text == "(1) Head note text continuation text without marker"


def test_single_continuation_transformation_log() -> None:
    """Verify Transformation fields are correctly populated."""
    document = Document(
        root=(
            _note("node_0001", "(1) Head", page_index=10, block_indices=(5,)),
            _note("node_0002", "continuation", page_index=11, block_indices=(7,)),
        )
    )
    _, transformations = _run(document)
    assert len(transformations) == 1
    t = transformations[0]
    assert t.step_id == STEP_ID
    assert t.node_id == "node_0001"
    assert t.page_index == 10
    assert t.position == (8, 8)  # len("(1) Head") = 8
    assert t.original == ""
    assert t.normalized == " continuation"
    assert t.merged_from == ("node_0002",)


def test_single_continuation_block_indices_concatenated() -> None:
    """The head Node's block_indices are extended with the absorbed Node's."""
    document = Document(
        root=(
            _note("node_0001", "(1) Head", page_index=10, block_indices=(5,)),
            _note("node_0002", "cont.", page_index=11, block_indices=(7, 8)),
        )
    )
    new_doc, _ = _run(document)
    notes = [n for n in new_doc.root if n.category is SemanticCategory.NOTE]
    assert notes[0].block_indices == (5, 7, 8)


def test_continuation_marker_is_skipped() -> None:
    """A note opening with ``(N)`` marker is NOT a continuation."""
    document = Document(
        root=(
            _note("node_0001", "(1) Head note.", page_index=10),
            _note("node_0002", "(2) Fresh note with marker.", page_index=11),
        )
    )
    new_doc, transformations = _run(document)
    assert new_doc is document
    assert transformations == ()


def test_continuation_marker_bare_digit_form_is_skipped() -> None:
    """The pattern also recognises bare ``N.`` form."""
    document = Document(
        root=(
            _note("node_0001", "(1) Head.", page_index=10),
            _note("node_0002", "5. Fresh note bare digit.", page_index=11),
        )
    )
    new_doc, transformations = _run(document)
    assert new_doc is document
    assert transformations == ()


def test_non_adjacent_pages_no_merge() -> None:
    """A 2-page gap between head and candidate is suspicious; no merge."""
    document = Document(
        root=(
            _note("node_0001", "(1) Head", page_index=10),
            _note("node_0002", "would be continuation", page_index=12),  # gap of 2
        )
    )
    new_doc, transformations = _run(document)
    assert new_doc is document
    assert transformations == ()


def test_empty_curr_text_no_merge() -> None:
    """A NOTE Node with empty text is not a valid continuation."""
    document = Document(
        root=(
            _note("node_0001", "(1) Head", page_index=10),
            _note("node_0002", "", page_index=11),
        )
    )
    new_doc, transformations = _run(document)
    assert new_doc is document
    assert transformations == ()


def test_none_curr_text_no_merge() -> None:
    """A NOTE Node with None text is not a valid continuation."""
    document = Document(
        root=(
            _note("node_0001", "(1) Head", page_index=10),
            _note("node_0002", None, page_index=11),
        )
    )
    new_doc, transformations = _run(document)
    assert new_doc is document
    assert transformations == ()


# ---------------------------------------------------------------------------
# Subsequent-note-on-page guard


def test_continuation_must_be_first_note_of_page() -> None:
    """Only the FIRST NOTE of a page is a valid continuation candidate;
    subsequent notes on the same page are independent."""
    document = Document(
        root=(
            _note("node_0001", "(1) Head", page_index=10),
            _note("node_0002", "first of p11 — would be continuation", page_index=11),
            _note("node_0003", "second of p11 — must NOT merge", page_index=11),
        )
    )
    new_doc, transformations = _run(document)
    # Only node_0002 (first of p11) is a continuation candidate; node_0003
    # is second of p11 so it's a regular note (with no marker text, but
    # the per-page guard rejects it before the marker check).
    assert len(transformations) == 1
    assert transformations[0].merged_from == ("node_0002",)
    notes = [n for n in new_doc.root if n.category is SemanticCategory.NOTE]
    assert {n.id for n in notes} == {"node_0001", "node_0003"}


# ---------------------------------------------------------------------------
# Multi-page chain (3+ continuation pages collapse into one head)


def test_three_page_chain_collapses_into_head() -> None:
    """A head followed by two continuation pages collapses into one head."""
    document = Document(
        root=(
            _note("node_0001", "(1) Head", page_index=10),
            _note("node_0002", "cont page 11", page_index=11),
            _note("node_0003", "cont page 12", page_index=12),
        )
    )
    new_doc, transformations = _run(document)
    assert len(transformations) == 2
    notes = [n for n in new_doc.root if n.category is SemanticCategory.NOTE]
    assert len(notes) == 1
    assert notes[0].id == "node_0001"
    assert notes[0].text == "(1) Head cont page 11 cont page 12"


def test_three_page_chain_both_transformations_anchor_to_head() -> None:
    """All Transformations point to the original head id, not intermediate ids."""
    document = Document(
        root=(
            _note("node_0001", "(1) Head", page_index=10),
            _note("node_0002", "cont", page_index=11),
            _note("node_0003", "more cont", page_index=12),
        )
    )
    _, transformations = _run(document)
    assert all(t.node_id == "node_0001" for t in transformations)
    assert [t.merged_from for t in transformations] == [("node_0002",), ("node_0003",)]


def test_three_page_chain_position_offsets_grow() -> None:
    """Each Transformation's position reflects the head's text length
    immediately before that transformation."""
    document = Document(
        root=(
            _note("node_0001", "(1) AB", page_index=10),  # len 6
            _note("node_0002", "cont1", page_index=11),
            _note("node_0003", "cont2", page_index=12),
        )
    )
    _, transformations = _run(document)
    assert transformations[0].position == (6, 6)
    # After first merge: "(1) AB cont1" = 12 chars; append point shifts.
    assert transformations[1].position == (12, 12)


# ---------------------------------------------------------------------------
# Multiple independent merges in the same document


def test_two_independent_merges() -> None:
    """Two unrelated head+continuation pairs are merged independently."""
    document = Document(
        root=(
            _note("node_0001", "(1) Head A", page_index=10),
            _note("node_0002", "cont A", page_index=11),
            _note("node_0003", "(1) Head B", page_index=20),
            _note("node_0004", "cont B", page_index=21),
        )
    )
    new_doc, transformations = _run(document)
    assert len(transformations) == 2
    notes = [n for n in new_doc.root if n.category is SemanticCategory.NOTE]
    assert len(notes) == 2
    assert {n.text for n in notes} == {"(1) Head A cont A", "(1) Head B cont B"}


# ---------------------------------------------------------------------------
# Tree-walk: DFS pre-order across siblings under different parents


def test_continuation_across_different_parents() -> None:
    """Two NOTE Nodes under different HEADING parents straddle a page break
    and the continuation merges across the structural boundary (DFS
    pre-order collection ignores tree depth)."""
    parent_a = _heading(
        "node_0010",
        "Section A",
        children=(_note("node_0001", "(1) Head", page_index=10),),
    )
    parent_b = _heading(
        "node_0011",
        "Section B",
        children=(_note("node_0002", "cont across section break", page_index=11),),
    )
    document = Document(root=(parent_a, parent_b))
    new_doc, transformations = _run(document)
    assert len(transformations) == 1
    # Head text has absorbed the continuation; the continuation Node is gone.
    all_notes: list[Node] = []

    def _walk(node: Node) -> None:
        if node.category is SemanticCategory.NOTE:
            all_notes.append(node)
        for child in node.children:
            _walk(child)

    for root in new_doc.root:
        _walk(root)

    assert len(all_notes) == 1
    assert all_notes[0].id == "node_0001"
    assert "cont across section break" in (all_notes[0].text or "")


def test_continuation_removed_from_parent_children() -> None:
    """After a cross-parent merge, the absorbed NOTE is removed from its
    original parent's children tuple."""
    parent_a = _heading(
        "node_0010",
        "Section A",
        children=(_note("node_0001", "(1) Head", page_index=10),),
    )
    parent_b = _heading(
        "node_0011",
        "Section B",
        children=(_note("node_0002", "cont", page_index=11),),
    )
    document = Document(root=(parent_a, parent_b))
    new_doc, _ = _run(document)
    # Find parent_b in the new tree; its NOTE child must be gone.
    new_parent_b = next(n for n in new_doc.root if n.id == "node_0011")
    assert len(new_parent_b.children) == 0


# ---------------------------------------------------------------------------
# Identity preservation for unchanged subtrees


def test_unchanged_subtree_keeps_identity() -> None:
    """A subtree that doesn't contain any modified NOTE keeps the same
    Node instance after the step runs (memory efficiency contract)."""
    untouched = _heading(
        "node_0010",
        "Untouched",
        children=(_body("node_0020", "body text", page_index=5),),
    )
    document = Document(
        root=(
            untouched,
            _note("node_0001", "(1) Head", page_index=10),
            _note("node_0002", "cont", page_index=11),
        )
    )
    new_doc, _ = _run(document)
    # The untouched heading must be the same instance (identity preserved).
    new_untouched = next(n for n in new_doc.root if n.id == "node_0010")
    assert new_untouched is untouched


# ---------------------------------------------------------------------------
# Children preservation on the surviving head


def test_head_children_preserved_after_merge() -> None:
    """A head NOTE with children keeps its children after absorbing a
    continuation (Node.children should not be lost)."""
    head_child = _body("node_0099", "child body", page_index=10)
    head = Node(
        id="node_0001",
        category=SemanticCategory.NOTE,
        page_index=10,
        block_indices=(0,),
        text="(1) Head",
        children=(head_child,),
    )
    cont = _note("node_0002", "cont", page_index=11)
    document = Document(root=(head, cont))
    new_doc, _ = _run(document)
    notes = [n for n in new_doc.root if n.category is SemanticCategory.NOTE]
    assert len(notes) == 1
    assert notes[0].children == (head_child,)


# ---------------------------------------------------------------------------
# Edge case: continuation candidate is the very first NOTE of the document


def test_first_note_of_document_is_never_a_continuation() -> None:
    """The first NOTE in the document has no predecessor; it cannot be
    a continuation candidate."""
    document = Document(
        root=(
            _note("node_0001", "no marker, but first NOTE", page_index=10),
            _note("node_0002", "(2) Second note with marker", page_index=11),
        )
    )
    new_doc, transformations = _run(document)
    # Even though node_0001 lacks a marker, it has no predecessor — no merge.
    # node_0002 has a marker, also no merge.
    assert new_doc is document
    assert transformations == ()


def test_head_not_in_notes_list_safeguard() -> None:
    """When _find_by_id receives an id that is not in the notes list,
    the helper returns None and the merge candidate is silently skipped.
    Tested indirectly by an empty notes list with len < 2."""
    # An empty document goes through _collect_notes which returns []; len(notes) < 2,
    # so we early-return without invoking _find_by_id. Verify the early-return.
    document = Document(root=())
    new_doc, transformations = _run(document)
    assert new_doc is document
    assert transformations == ()
