"""Unit tests for :func:`normalize_ocr_with_dictionary`."""

from __future__ import annotations

import dataclasses

import pytest

from scabopdf_pipeline.extraction.types import ExtractionResult
from scabopdf_pipeline.postprocessing.lexicon import ItalianLexicon
from scabopdf_pipeline.postprocessing.ocr_substitutions import clear_correction_cache
from scabopdf_pipeline.postprocessing.steps.normalize_ocr_with_dictionary import (
    normalize_ocr_with_dictionary,
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
# Closed structural-marker dictionary


def test_structural_marker_letteratura_variant_is_replaced() -> None:
    document = Document(root=(_node("node_0001", "vedi LrnaRATURA."),))
    lexicon = ItalianLexicon.from_word_set(set())

    new_document, transformations = normalize_ocr_with_dictionary(
        document, _empty_extraction(), [], lexicon=lexicon
    )

    assert new_document.root[0].text == "vedi LETTERATURA."
    assert len(transformations) == 1
    t = transformations[0]
    assert t.step_id == "normalize_ocr_with_dictionary"
    assert t.original == "LrnaRATURA"
    assert t.normalized == "LETTERATURA"


def test_multiple_structural_marker_occurrences_are_all_replaced() -> None:
    document = Document(root=(_node("node_0001", "LrnaRATURA e LnTEHATURA."),))
    lexicon = ItalianLexicon.from_word_set(set())

    new_document, transformations = normalize_ocr_with_dictionary(
        document, _empty_extraction(), [], lexicon=lexicon
    )

    assert new_document.root[0].text == "LETTERATURA e LETTERATURA."
    assert len(transformations) == 2


# ---------------------------------------------------------------------------
# Per-token lexicon-validated substitution


def test_unique_lexicon_match_corrects_token() -> None:
    document = Document(root=(_node("node_0001", "il c0sa importante."),))
    lexicon = ItalianLexicon.from_word_set({"cosa", "il", "importante"})

    new_document, transformations = normalize_ocr_with_dictionary(
        document, _empty_extraction(), [], lexicon=lexicon
    )

    assert new_document.root[0].text == "il cosa importante."
    assert len(transformations) == 1
    t = transformations[0]
    assert t.original == "c0sa"
    assert t.normalized == "cosa"


def test_token_already_in_lexicon_is_not_changed() -> None:
    document = Document(root=(_node("node_0001", "il casa importante."),))
    lexicon = ItalianLexicon.from_word_set({"casa", "il", "importante"})

    new_document, transformations = normalize_ocr_with_dictionary(
        document, _empty_extraction(), [], lexicon=lexicon
    )

    assert new_document is document
    assert transformations == ()


def test_ambiguous_correction_leaves_token_unchanged() -> None:
    document = Document(root=(_node("node_0001", "il all1 cosa."),))
    # Both ``alli`` and ``alll`` in lex → ambiguous → no substitution.
    lexicon = ItalianLexicon.from_word_set({"alli", "alll", "il", "cosa"})

    new_document, transformations = normalize_ocr_with_dictionary(
        document, _empty_extraction(), [], lexicon=lexicon
    )

    assert new_document.root[0].text == "il all1 cosa."
    assert transformations == ()


def test_uppercase_token_keeps_uppercase_after_correction() -> None:
    document = Document(root=(_node("node_0001", "Bccesso di potere."),))
    lexicon = ItalianLexicon.from_word_set({"eccesso"})

    new_document, transformations = normalize_ocr_with_dictionary(
        document, _empty_extraction(), [], lexicon=lexicon
    )

    assert new_document.root[0].text == "Eccesso di potere."
    assert transformations[0].normalized == "Eccesso"


def test_pure_digit_tokens_are_skipped() -> None:
    document = Document(root=(_node("node_0001", "vedi 1234 dopo."),))
    lexicon = ItalianLexicon.from_word_set({"vedi", "dopo"})

    new_document, transformations = normalize_ocr_with_dictionary(
        document, _empty_extraction(), [], lexicon=lexicon
    )

    assert new_document is document
    assert transformations == ()


def test_short_tokens_are_skipped() -> None:
    """Tokens shorter than the substitution threshold are never corrected."""
    document = Document(root=(_node("node_0001", "a c0 ad."),))
    lexicon = ItalianLexicon.from_word_set({"co"})

    new_document, transformations = normalize_ocr_with_dictionary(
        document, _empty_extraction(), [], lexicon=lexicon
    )

    # ``c0`` is only 2 chars; the helper refuses to correct.
    assert new_document is document
    assert transformations == ()


# ---------------------------------------------------------------------------
# Category gating


def test_artifact_category_is_skipped() -> None:
    """ARTIFACT_FOOTER text is preserved verbatim."""
    document = Document(
        root=(
            _node(
                "node_0001",
                "LrnaRATURA",
                category=SemanticCategory.ARTIFACT_FOOTER,
            ),
        )
    )
    lexicon = ItalianLexicon.from_word_set(set())

    new_document, transformations = normalize_ocr_with_dictionary(
        document, _empty_extraction(), [], lexicon=lexicon
    )

    assert new_document is document
    assert transformations == ()


def test_cross_reference_category_is_skipped() -> None:
    """CROSS_REFERENCE markers are preserved for the apparatus resolver."""
    document = Document(
        root=(
            _node(
                "node_0001",
                "(11)",
                category=SemanticCategory.CROSS_REFERENCE,
            ),
        )
    )
    lexicon = ItalianLexicon.from_word_set(set())

    new_document, transformations = normalize_ocr_with_dictionary(
        document, _empty_extraction(), [], lexicon=lexicon
    )

    assert new_document is document
    assert transformations == ()


def test_text_none_node_is_skipped() -> None:
    document = Document(root=(_node("node_0001", None),))
    lexicon = ItalianLexicon.from_word_set(set())

    new_document, transformations = normalize_ocr_with_dictionary(
        document, _empty_extraction(), [], lexicon=lexicon
    )

    assert new_document is document
    assert transformations == ()


def test_non_text_bearing_parent_with_modified_children_is_rebuilt() -> None:
    """A parent Node outside the text-bearing set is rebuilt when its descendants change."""
    child = _node("node_0002", "il c0sa importante.")
    # ARTIFACT_FOOTER parents are not normally trees, but the recursive
    # walk must still propagate changes from descendants. We exercise the
    # branch in `_process_node` that skips the parent's own text but
    # rebuilds it when children are modified.
    parent = _node(
        "node_0001",
        None,
        category=SemanticCategory.ARTIFACT_FOOTER,
        children=(child,),
    )
    document = Document(root=(parent,))
    lexicon = ItalianLexicon.from_word_set({"cosa", "il", "importante"})

    new_document, transformations = normalize_ocr_with_dictionary(
        document, _empty_extraction(), [], lexicon=lexicon
    )

    assert new_document is not document
    assert new_document.root[0].children[0].text == "il cosa importante."
    assert len(transformations) == 1


# ---------------------------------------------------------------------------
# Tree recursion + NOTE length_category recompute


def test_children_are_processed_recursively() -> None:
    child = _node("node_0002", "c0sa nel figlio.")
    parent = _node("node_0001", "padre senza modifiche.", children=(child,))
    document = Document(root=(parent,))
    lexicon = ItalianLexicon.from_word_set({"cosa", "padre", "senza", "modifiche", "nel", "figlio"})

    new_document, transformations = normalize_ocr_with_dictionary(
        document, _empty_extraction(), [], lexicon=lexicon
    )

    assert len(transformations) == 1
    assert new_document.root[0].children[0].text == "cosa nel figlio."


def test_note_length_category_is_recomputed_on_correction() -> None:
    """A NOTE node sees its length_category recomputed after substitution."""
    short_corrupted = (
        "LrnaRATURA " + " ".join(["alpha"] * 5)  # ~50 chars worth: under SHORT threshold
    )
    note = _node(
        "node_0001",
        short_corrupted,
        category=SemanticCategory.NOTE,
    )
    document = Document(root=(note,))
    lexicon = ItalianLexicon.from_word_set(set())

    new_document, _ = normalize_ocr_with_dictionary(
        document, _empty_extraction(), [], lexicon=lexicon
    )

    new_text = new_document.root[0].text
    assert new_text is not None
    expected = compute_note_length_category(new_text)
    assert new_document.root[0].length_category == expected


def test_non_note_category_keeps_existing_length_category() -> None:
    body = dataclasses.replace(
        _node("node_0001", "c0sa importante."),
        length_category=None,
    )
    document = Document(root=(body,))
    lexicon = ItalianLexicon.from_word_set({"cosa", "importante"})

    new_document, _ = normalize_ocr_with_dictionary(
        document, _empty_extraction(), [], lexicon=lexicon
    )

    # BODY does not own a length_category; it stays None regardless of text change.
    assert new_document.root[0].length_category is None


# ---------------------------------------------------------------------------
# Identity preservation when nothing changes


def test_identity_when_no_change() -> None:
    document = Document(root=(_node("node_0001", "tutto bene."),))
    lexicon = ItalianLexicon.from_word_set({"tutto", "bene"})

    new_document, transformations = normalize_ocr_with_dictionary(
        document, _empty_extraction(), [], lexicon=lexicon
    )

    assert new_document is document
    assert transformations == ()


# ---------------------------------------------------------------------------
# Default lexicon path


def test_default_lexicon_is_used_when_none_passed() -> None:
    """When the caller passes no lexicon the step builds the bundled default."""
    document = Document(root=(_node("node_0001", "Bccesso di potere."),))
    new_document, transformations = normalize_ocr_with_dictionary(document, _empty_extraction(), [])
    # The bundled wordlist contains ``eccesso``, so the substitution fires.
    assert "Eccesso" in (new_document.root[0].text or "")
    assert any(t.normalized == "Eccesso" for t in transformations)


# ---------------------------------------------------------------------------
# Position validity (reversibility)


def test_transformation_position_is_valid_slice_of_original_text() -> None:
    """Each transformation position points at the verbatim original substring."""
    text = "Vedi LrnaRATURA e c0sa importante."
    document = Document(root=(_node("node_0001", text),))
    lexicon = ItalianLexicon.from_word_set({"cosa", "vedi", "importante"})

    new_document, transformations = normalize_ocr_with_dictionary(
        document, _empty_extraction(), [], lexicon=lexicon
    )

    for t in transformations:
        start, end = t.position
        assert text[start:end] == t.original

    assert new_document.root[0].text == "Vedi LETTERATURA e cosa importante."


# ---------------------------------------------------------------------------
# Marker dictionary cannot conflict with token substitution


def test_marker_dictionary_position_is_not_re_processed_by_token_pass() -> None:
    """A range claimed by the marker pass is excluded from the per-token pass."""
    document = Document(root=(_node("node_0001", "vedi LrnaRATURA dopo."),))
    lexicon = ItalianLexicon.from_word_set({"letteratura", "vedi", "dopo"})

    new_document, transformations = normalize_ocr_with_dictionary(
        document, _empty_extraction(), [], lexicon=lexicon
    )

    # Exactly one substitution: the marker dict; the per-token pass
    # must not duplicate the work on the inner tokens of LrnaRATURA.
    assert len(transformations) == 1
    assert new_document.root[0].text == "vedi LETTERATURA dopo."
