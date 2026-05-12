"""Unit tests for :func:`dehyphenate_with_log`.

All tests build an explicit ``Document`` plus a deterministic
``ItalianLexicon.from_word_set(...)`` so the behaviour is independent
of the pyspellchecker dictionary.
"""

from __future__ import annotations

from scabopdf_pipeline.extraction.types import ExtractionResult
from scabopdf_pipeline.postprocessing.lexicon import ItalianLexicon
from scabopdf_pipeline.postprocessing.steps.dehyphenate import dehyphenate_with_log
from scabopdf_pipeline.reconstruction.types import Document, Node
from scabopdf_pipeline.schema.categories import SemanticCategory


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


def _node(node_id: str, text: str | None, page_index: int = 0) -> Node:
    return Node(
        id=node_id,
        category=SemanticCategory.BODY,
        page_index=page_index,
        text=text,
    )


def test_dehyphenate_applies_when_candidate_is_known() -> None:
    document = Document(root=(_node("node_0001", "evolu-\nzione del diritto"),))
    lexicon = ItalianLexicon.from_word_set({"evoluzione"})

    new_document, transformations = dehyphenate_with_log(
        document, _empty_extraction(), [], lexicon=lexicon
    )

    assert new_document.root[0].text == "evoluzione del diritto"
    assert len(transformations) == 1
    t = transformations[0]
    assert t.step_id == "dehyphenate_with_log"
    assert t.node_id == "node_0001"
    assert t.page_index == 0
    assert t.original == "evolu-\nzione"
    assert t.normalized == "evoluzione"
    original_text = document.root[0].text
    assert original_text is not None
    assert original_text[t.position[0] : t.position[1]] == "evolu-\nzione"


def test_dehyphenate_skips_when_candidate_unknown() -> None:
    document = Document(root=(_node("node_0001", "evolu-\nzione del diritto"),))
    lexicon = ItalianLexicon.from_word_set({"casa"})

    new_document, transformations = dehyphenate_with_log(
        document, _empty_extraction(), [], lexicon=lexicon
    )

    assert new_document is document
    assert transformations == ()


def test_dehyphenate_ignores_inline_hyphens_without_newline() -> None:
    document = Document(root=(_node("node_0001", "ar-ti-co-lo"),))
    lexicon = ItalianLexicon.from_word_set({"articolo", "arti", "colo"})

    new_document, transformations = dehyphenate_with_log(
        document, _empty_extraction(), [], lexicon=lexicon
    )

    assert new_document is document
    assert transformations == ()


def test_dehyphenate_ignores_double_newline() -> None:
    document = Document(root=(_node("node_0001", "evolu-\n\nzione"),))
    lexicon = ItalianLexicon.from_word_set({"evoluzione"})

    new_document, transformations = dehyphenate_with_log(
        document, _empty_extraction(), [], lexicon=lexicon
    )

    assert new_document is document
    assert transformations == ()


def test_dehyphenate_handles_soft_hyphen() -> None:
    document = Document(root=(_node("node_0001", "evolu­\nzione"),))
    lexicon = ItalianLexicon.from_word_set({"evoluzione"})

    new_document, transformations = dehyphenate_with_log(
        document, _empty_extraction(), [], lexicon=lexicon
    )

    assert new_document.root[0].text == "evoluzione"
    assert len(transformations) == 1
    assert transformations[0].original == "evolu­\nzione"
    assert transformations[0].normalized == "evoluzione"


def test_dehyphenate_preserves_case_of_pre_hyphen_fragment() -> None:
    document = Document(root=(_node("node_0001", "Evolu-\nzione"),))
    lexicon = ItalianLexicon.from_word_set({"evoluzione"})

    new_document, transformations = dehyphenate_with_log(
        document, _empty_extraction(), [], lexicon=lexicon
    )

    assert new_document.root[0].text == "Evoluzione"
    assert transformations[0].normalized == "Evoluzione"


def test_dehyphenate_records_separate_transformations_for_each_hit() -> None:
    text = "evolu-\nzione e poi trasfor-\nmazione."
    document = Document(root=(_node("node_0001", text),))
    lexicon = ItalianLexicon.from_word_set({"evoluzione", "trasformazione"})

    new_document, transformations = dehyphenate_with_log(
        document, _empty_extraction(), [], lexicon=lexicon
    )

    assert new_document.root[0].text == "evoluzione e poi trasformazione."
    assert len(transformations) == 2
    assert {t.normalized for t in transformations} == {"evoluzione", "trasformazione"}
    # The recorded positions slice the *pre-step* text correctly.
    for t in transformations:
        assert text[t.position[0] : t.position[1]] == t.original


def test_dehyphenate_skips_node_with_none_text() -> None:
    document = Document(root=(_node("node_0001", None),))
    lexicon = ItalianLexicon.from_word_set({"anything"})

    new_document, transformations = dehyphenate_with_log(
        document, _empty_extraction(), [], lexicon=lexicon
    )

    assert new_document is document
    assert transformations == ()


def test_dehyphenate_no_op_returns_input_document() -> None:
    document = Document(root=(_node("node_0001", "testo senza hyphenation"),))
    lexicon = ItalianLexicon.from_word_set({"testo"})

    new_document, transformations = dehyphenate_with_log(
        document, _empty_extraction(), [], lexicon=lexicon
    )

    assert new_document is document
    assert transformations == ()


def test_dehyphenate_recurses_into_deep_subtree() -> None:
    leaf = _node("node_0003", "evolu-\nzione", page_index=2)
    inner = Node(
        id="node_0002",
        category=SemanticCategory.HEADING_2,
        page_index=2,
        text="capitolo secondo",
        level=2,
        children=(leaf,),
    )
    root = Node(
        id="node_0001",
        category=SemanticCategory.HEADING_1,
        page_index=2,
        text="parte prima",
        level=1,
        children=(inner,),
    )
    document = Document(root=(root,))
    lexicon = ItalianLexicon.from_word_set({"evoluzione"})

    new_document, transformations = dehyphenate_with_log(
        document, _empty_extraction(), [], lexicon=lexicon
    )

    new_leaf = new_document.root[0].children[0].children[0]
    assert new_leaf.text == "evoluzione"
    assert len(transformations) == 1
    assert transformations[0].node_id == "node_0003"
    assert transformations[0].page_index == 2


def test_dehyphenate_rejects_post_hyphen_fragment_shorter_than_two_chars() -> None:
    document = Document(root=(_node("node_0001", "test-\no fine"),))
    lexicon = ItalianLexicon.from_word_set({"testo"})

    new_document, transformations = dehyphenate_with_log(
        document, _empty_extraction(), [], lexicon=lexicon
    )

    assert new_document is document
    assert transformations == ()
