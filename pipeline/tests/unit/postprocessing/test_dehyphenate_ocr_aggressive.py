"""Unit tests for :func:`dehyphenate_ocr_aggressive`."""

from __future__ import annotations

import pytest

from scabopdf_pipeline.extraction.types import ExtractionResult
from scabopdf_pipeline.postprocessing.lexicon import ItalianLexicon
from scabopdf_pipeline.postprocessing.ocr_substitutions import clear_correction_cache
from scabopdf_pipeline.postprocessing.steps.dehyphenate_ocr_aggressive import (
    dehyphenate_ocr_aggressive,
)
from scabopdf_pipeline.reconstruction.types import Document, Node, compute_note_length_category
from scabopdf_pipeline.schema.categories import SemanticCategory


@pytest.fixture(autouse=True)
def _isolate_cache() -> None:
    clear_correction_cache()


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


def _node(
    node_id: str,
    text: str | None,
    category: SemanticCategory = SemanticCategory.BODY,
    page_index: int = 0,
    children: tuple[Node, ...] = (),
) -> Node:
    return Node(
        id=node_id,
        category=category,
        page_index=page_index,
        text=text,
        children=children,
    )


# ---------------------------------------------------------------------------
# Literal join cases (would also be caught by dehyphenate_with_log)


def test_literal_join_is_accepted_when_candidate_is_in_lexicon() -> None:
    document = Document(root=(_node("node_0001", "L'evolu-\nzione tecnica."),))
    lexicon = ItalianLexicon.from_word_set({"evoluzione"})

    new_document, transformations = dehyphenate_ocr_aggressive(
        document, _empty_extraction(), [], lexicon=lexicon
    )

    assert new_document.root[0].text == "L'evoluzione tecnica."
    assert len(transformations) == 1
    assert transformations[0].step_id == "dehyphenate_ocr_aggressive"
    assert transformations[0].original == "evolu-\nzione"
    assert transformations[0].normalized == "evoluzione"


def test_literal_join_preserves_case() -> None:
    document = Document(root=(_node("node_0001", "Evolu-\nZione."),))
    lexicon = ItalianLexicon.from_word_set({"evoluzione"})

    new_document, _ = dehyphenate_ocr_aggressive(document, _empty_extraction(), [], lexicon=lexicon)

    assert "EvoluZione" in (new_document.root[0].text or "")


# ---------------------------------------------------------------------------
# OCR-corrected join cases


def test_ocr_corrected_join_is_accepted_when_variant_in_lexicon() -> None:
    """``paga-\\n1nenlo`` merges to ``pagamento`` via ``1n``→``m`` + ``l``→``t``."""
    document = Document(root=(_node("node_0001", "La paga-\n1nenlo è completa."),))
    lexicon = ItalianLexicon.from_word_set({"pagamento"})

    new_document, transformations = dehyphenate_ocr_aggressive(
        document, _empty_extraction(), [], lexicon=lexicon
    )

    assert new_document.root[0].text == "La pagamento è completa."
    assert len(transformations) == 1
    assert transformations[0].original == "paga-\n1nenlo"
    assert transformations[0].normalized == "pagamento"


def test_ocr_corrected_join_handles_depth_two_substitutions() -> None:
    """``giusti-\\n11ia`` merges to ``giustizia`` via ``11``→``z`` (depth 1)."""
    document = Document(root=(_node("node_0001", "il giusti-\n11ia sociale."),))
    lexicon = ItalianLexicon.from_word_set({"giustizia"})

    new_document, transformations = dehyphenate_ocr_aggressive(
        document, _empty_extraction(), [], lexicon=lexicon
    )

    assert new_document.root[0].text == "il giustizia sociale."
    assert len(transformations) == 1


# ---------------------------------------------------------------------------
# Skip cases


def test_skip_when_pair_is_in_preservative_list() -> None:
    document = Document(root=(_node("node_0001", "Il decreto-\nlegge è importante."),))
    lexicon = ItalianLexicon.from_word_set({"decretolegge"})  # would-be join in lex

    new_document, transformations = dehyphenate_ocr_aggressive(
        document, _empty_extraction(), [], lexicon=lexicon
    )

    assert new_document is document
    assert transformations == ()


def test_skip_when_both_fragments_are_digits() -> None:
    document = Document(root=(_node("node_0001", "Vedi pp. 113-\n330."),))
    lexicon = ItalianLexicon.from_word_set(set())

    new_document, transformations = dehyphenate_ocr_aggressive(
        document, _empty_extraction(), [], lexicon=lexicon
    )

    assert new_document is document
    assert transformations == ()


def test_skip_when_post_hyphen_fragment_too_short() -> None:
    document = Document(root=(_node("node_0001", "La paga-\na completa."),))
    lexicon = ItalianLexicon.from_word_set({"pagaa"})

    new_document, transformations = dehyphenate_ocr_aggressive(
        document, _empty_extraction(), [], lexicon=lexicon
    )

    assert new_document is document
    assert transformations == ()


def test_skip_when_no_valid_correction_exists() -> None:
    document = Document(root=(_node("node_0001", "La normazi-\nyyyz qualcosa."),))
    lexicon = ItalianLexicon.from_word_set(set())

    new_document, transformations = dehyphenate_ocr_aggressive(
        document, _empty_extraction(), [], lexicon=lexicon
    )

    assert new_document is document
    assert transformations == ()


def test_no_hyphenation_in_text_returns_input_identity() -> None:
    document = Document(root=(_node("node_0001", "Tutto bene senza sillabazione."),))
    lexicon = ItalianLexicon.from_word_set({"casa"})

    new_document, transformations = dehyphenate_ocr_aggressive(
        document, _empty_extraction(), [], lexicon=lexicon
    )

    assert new_document is document
    assert transformations == ()


# ---------------------------------------------------------------------------
# Tree recursion + NOTE length_category recompute


def test_children_are_processed_recursively() -> None:
    child = _node("node_0002", "il paga-\n1nenlo del figlio.")
    parent = _node("node_0001", "padre senza modifiche.", children=(child,))
    document = Document(root=(parent,))
    lexicon = ItalianLexicon.from_word_set({"pagamento"})

    new_document, transformations = dehyphenate_ocr_aggressive(
        document, _empty_extraction(), [], lexicon=lexicon
    )

    assert len(transformations) == 1
    assert new_document.root[0].children[0].text == "il pagamento del figlio."


def test_note_length_category_is_recomputed_after_join() -> None:
    note_text = "evolu-\nzione del diritto."
    note = _node(
        "node_0001",
        note_text,
        category=SemanticCategory.NOTE,
    )
    document = Document(root=(note,))
    lexicon = ItalianLexicon.from_word_set({"evoluzione"})

    new_document, _ = dehyphenate_ocr_aggressive(document, _empty_extraction(), [], lexicon=lexicon)

    new_text = new_document.root[0].text
    assert new_text is not None
    assert new_document.root[0].length_category == compute_note_length_category(new_text)


def test_text_none_node_is_skipped() -> None:
    document = Document(root=(_node("node_0001", None),))
    lexicon = ItalianLexicon.from_word_set(set())

    new_document, transformations = dehyphenate_ocr_aggressive(
        document, _empty_extraction(), [], lexicon=lexicon
    )

    assert new_document is document
    assert transformations == ()


def test_text_none_node_with_modified_children_is_rebuilt() -> None:
    child = _node("node_0002", "evolu-\nzione del diritto.")
    parent = _node("node_0001", None, children=(child,))
    document = Document(root=(parent,))
    lexicon = ItalianLexicon.from_word_set({"evoluzione"})

    new_document, _ = dehyphenate_ocr_aggressive(document, _empty_extraction(), [], lexicon=lexicon)

    assert new_document is not document
    assert new_document.root[0].children[0].text == "evoluzione del diritto."


# ---------------------------------------------------------------------------
# Reversibility (position validity)


def test_transformation_position_is_valid_slice_of_original_text() -> None:
    text = "La paga-\n1nenlo e l'evolu-\nzione."
    document = Document(root=(_node("node_0001", text),))
    lexicon = ItalianLexicon.from_word_set({"pagamento", "evoluzione"})

    _new_document, transformations = dehyphenate_ocr_aggressive(
        document, _empty_extraction(), [], lexicon=lexicon
    )

    for t in transformations:
        start, end = t.position
        assert text[start:end] == t.original


def test_multiple_substitutions_apply_right_to_left() -> None:
    """Right-to-left application keeps recorded positions valid against pre-step text."""
    text = "La paga-\n1nenlo e l'evolu-\nzione."
    document = Document(root=(_node("node_0001", text),))
    lexicon = ItalianLexicon.from_word_set({"pagamento", "evoluzione"})

    new_document, transformations = dehyphenate_ocr_aggressive(
        document, _empty_extraction(), [], lexicon=lexicon
    )

    assert len(transformations) == 2
    final_text = new_document.root[0].text
    assert final_text == "La pagamento e l'evoluzione."


# ---------------------------------------------------------------------------
# Default lexicon path


def test_default_lexicon_is_used_when_none_passed() -> None:
    document = Document(root=(_node("node_0001", "L'evolu-\nzione tecnica."),))
    new_document, transformations = dehyphenate_ocr_aggressive(document, _empty_extraction(), [])
    # The bundled wordlist knows ``evoluzione``.
    assert "evoluzione" in (new_document.root[0].text or "")
    assert len(transformations) == 1
