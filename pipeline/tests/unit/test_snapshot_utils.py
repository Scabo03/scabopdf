"""Unit tests for the snapshot baseline tooling.

Covers :func:`category_counts`, :func:`save_snapshot`,
:func:`load_snapshot`, :func:`diff_dicts`,
:func:`assert_snapshot_matches` and
:func:`document_structural_summary`. The tests exercise the snapshot
path resolution against a temporary directory to avoid polluting the
committed baselines under ``pipeline/tests/snapshots/``.
"""

from __future__ import annotations

from pathlib import Path

import pytest

from scabopdf_pipeline.postprocessing.types import Transformation
from scabopdf_pipeline.reconstruction.types import Document, Node
from scabopdf_pipeline.schema.categories import SemanticCategory
from tests import snapshot_utils


@pytest.fixture(autouse=True)
def _isolate_snapshots(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    monkeypatch.setattr(snapshot_utils, "SNAPSHOTS_ROOT", tmp_path / "snapshots")


def _make_node(node_id: str, category: SemanticCategory, children: tuple[Node, ...] = ()) -> Node:
    return Node(
        id=node_id,
        category=category,
        text=None,
        page_index=0,
        block_indices=(0,),
        children=children,
        apparatus_refs=(),
    )


def _make_document(*roots: Node, warnings: tuple[str, ...] = (), n_xforms: int = 0) -> Document:
    transformations: tuple[Transformation, ...] = tuple(
        Transformation(
            node_id="node_0001",
            step_id="dehyphenate_with_log",
            page_index=0,
            position=(0, 1),
            original="x",
            normalized="x",
        )
        for _ in range(n_xforms)
    )
    return Document(root=tuple(roots), warnings=warnings, transformations=transformations)


def test_category_counts_returns_sorted_dict() -> None:
    leaf = _make_node("node_0002", SemanticCategory.NOTE)
    root = _make_node("node_0001", SemanticCategory.HEADING_1, children=(leaf,))
    doc = _make_document(root)

    counts = snapshot_utils.category_counts(doc)

    assert list(counts.items()) == sorted(counts.items())
    assert counts == {SemanticCategory.HEADING_1.value: 1, SemanticCategory.NOTE.value: 1}


def test_save_and_load_snapshot_roundtrip(tmp_path: Path) -> None:
    snapshot_utils.save_snapshot("demo", {"a": 1, "b": 2})

    loaded = snapshot_utils.load_snapshot("demo")

    assert loaded == {"a": 1, "b": 2}


def test_save_snapshot_pretty_prints_with_sorted_keys() -> None:
    target = snapshot_utils.save_snapshot("pretty", {"b": 2, "a": 1})

    content = target.read_text(encoding="utf-8")
    assert content.endswith("\n")
    assert content.index('"a"') < content.index('"b"')


def test_load_snapshot_missing_raises() -> None:
    with pytest.raises(FileNotFoundError, match="snapshot 'absent' not found"):
        snapshot_utils.load_snapshot("absent")


def test_diff_dicts_empty_when_equal() -> None:
    assert snapshot_utils.diff_dicts({"a": 1}, {"a": 1}) == []


def test_diff_dicts_reports_value_drift_added_removed() -> None:
    expected = {"a": 1, "b": 2}
    actual = {"a": 5, "c": 3}

    diff = snapshot_utils.diff_dicts(expected, actual)

    assert any("a:" in line and "1" in line and "5" in line for line in diff)
    assert any("b:" in line and "removed" in line for line in diff)
    assert any("c:" in line and "added" in line for line in diff)


def test_assert_snapshot_matches_passes_when_equal() -> None:
    snapshot_utils.save_snapshot("ok", {"a": 1})

    snapshot_utils.assert_snapshot_matches("ok", {"a": 1})


def test_assert_snapshot_matches_raises_with_diff_text() -> None:
    snapshot_utils.save_snapshot("drift", {"a": 1, "b": 2})

    with pytest.raises(AssertionError) as info:
        snapshot_utils.assert_snapshot_matches("drift", {"a": 1, "b": 99})

    message = str(info.value)
    assert "b:" in message
    assert "2" in message and "99" in message
    assert "regenerate the snapshot" in message


def test_document_structural_summary_collects_counts_and_scalars() -> None:
    leaf = _make_node("node_0002", SemanticCategory.NOTE)
    root = _make_node("node_0001", SemanticCategory.HEADING_1, children=(leaf,))
    doc = _make_document(root, warnings=("w_1", "w_2"), n_xforms=3)

    summary = snapshot_utils.document_structural_summary(doc)

    assert summary["n_warnings"] == 2
    assert summary["n_transformations"] == 3
    assert summary["category_counts"] == {
        SemanticCategory.HEADING_1.value: 1,
        SemanticCategory.NOTE.value: 1,
    }


def test_snapshot_path_resolves_under_snapshots_root() -> None:
    path = snapshot_utils.snapshot_path("example")
    assert path.suffix == ".json"
    assert path.parent.name == "snapshots"


def _make_text_node(node_id: str, category: SemanticCategory, *, text: str, page: int = 0) -> Node:
    return Node(
        id=node_id,
        category=category,
        text=text,
        page_index=page,
        block_indices=(page,),
        children=(),
        apparatus_refs=(),
    )


def _make_document_with_mints(
    transformations: tuple[Transformation, ...] = (),
    warnings: tuple[str, ...] = (),
    extra_nodes: tuple[Node, ...] = (),
) -> Document:
    """Build a Document with explicit nodes referenced by transformations/warnings."""
    root_node = _make_text_node("node_0001", SemanticCategory.BODY, text="parent body")
    root = root_node.__class__(
        id=root_node.id,
        category=root_node.category,
        text=root_node.text,
        page_index=root_node.page_index,
        block_indices=root_node.block_indices,
        children=extra_nodes,
        apparatus_refs=root_node.apparatus_refs,
    )
    return Document(root=(root,), warnings=warnings, transformations=transformations)


def test_body_note_splitter_digest_empty_on_clean_document() -> None:
    doc = _make_document_with_mints()

    digest = snapshot_utils.body_note_splitter_digest(doc)

    expected_empty = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    assert digest == expected_empty


def test_body_note_splitter_digest_captures_transformation_split_into() -> None:
    synthetic = _make_text_node("node_0042", SemanticCategory.NOTE, text="(1) hi", page=3)
    tx = Transformation(
        step_id="giappichelli_body_note_splitter",
        node_id="node_0001",
        page_index=3,
        position=(0, 6),
        original="(1) hi",
        normalized="",
        split_into=("node_0042",),
    )
    doc = _make_document_with_mints(transformations=(tx,), extra_nodes=(synthetic,))

    digest = snapshot_utils.body_note_splitter_digest(doc)

    assert digest != ("e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")


def test_body_note_splitter_digest_is_order_sensitive_on_synthetic_text() -> None:
    short_text = _make_text_node("node_0042", SemanticCategory.NOTE, text="short", page=1)
    long_text = _make_text_node(
        "node_0042", SemanticCategory.NOTE, text="much-longer-text-content", page=1
    )
    tx = Transformation(
        step_id="bic_body_note_splitter",
        node_id="node_0001",
        page_index=1,
        position=(0, 5),
        original="hello",
        normalized="",
        split_into=("node_0042",),
    )
    doc_short = _make_document_with_mints(transformations=(tx,), extra_nodes=(short_text,))
    doc_long = _make_document_with_mints(transformations=(tx,), extra_nodes=(long_text,))

    assert snapshot_utils.body_note_splitter_digest(
        doc_short
    ) != snapshot_utils.body_note_splitter_digest(doc_long)


def test_body_note_splitter_digest_captures_warning_minted_nodes() -> None:
    synthetic = _make_text_node("node_0099", SemanticCategory.ARTICLE_HEADER, text="123. ", page=5)
    warnings = (
        ("plugin:giuffre_codici:intra_block_article_split_minted_node_node_0099_page_5_article_2"),
    )
    doc = _make_document_with_mints(warnings=warnings, extra_nodes=(synthetic,))

    digest = snapshot_utils.body_note_splitter_digest(doc)

    assert digest != ("e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")


def test_body_note_splitter_digest_ignores_unrelated_minted_warnings() -> None:
    warnings_cross_ref = (
        "plugin:manuale_utet_wolterskluwer:cross_reference_minted_node_node_0099_page_1_marker_1",
    )
    warnings_anchor = ("plugin:manuale_bic:book_page_anchor_minted_node_node_0099_page_1",)
    doc_cr = _make_document_with_mints(warnings=warnings_cross_ref)
    doc_anchor = _make_document_with_mints(warnings=warnings_anchor)

    empty = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    assert snapshot_utils.body_note_splitter_digest(doc_cr) == empty
    assert snapshot_utils.body_note_splitter_digest(doc_anchor) == empty


def test_body_note_splitter_digest_recognises_all_six_kinds() -> None:
    kinds = (
        "body_note_split_minted",
        "note_section_split_minted",
        "editorial_note_minted",
        "multi_note_split_minted",
        "intra_block_article_split_minted",
        "note_continuation_rescued",
    )
    for kind in kinds:
        warnings = (f"plugin:demo:{kind}_node_node_0099_page_2",)
        doc = _make_document_with_mints(warnings=warnings)
        digest = snapshot_utils.body_note_splitter_digest(doc)
        assert digest != ("e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"), (
            f"kind {kind!r} should match the body+note splitter pattern"
        )


def test_body_note_splitter_summary_combines_structural_and_mint_signals() -> None:
    synthetic_note = _make_text_node("node_0042", SemanticCategory.NOTE, text="(1) one")
    synthetic_editorial = _make_text_node(
        "node_0043", SemanticCategory.EDITORIAL_NOTE, text="(*) editorial"
    )
    synthetic_article = _make_text_node("node_0099", SemanticCategory.ARTICLE_HEADER, text="123.")
    tx_split = Transformation(
        step_id="dejure_dottrina_notes_consolidator",
        node_id="node_0001",
        page_index=0,
        position=(0, 1),
        original="x",
        normalized="",
        split_into=("node_0042", "node_0043"),
    )
    tx_text_only = Transformation(
        step_id="dehyphenate_with_log",
        node_id="node_0001",
        page_index=0,
        position=(0, 1),
        original="x",
        normalized="y",
    )
    warnings = (
        "plugin:giuffre_codici:intra_block_article_split_minted_node_node_0099_page_5_article_2",
        "plugin:demo:unrelated_warning_node_0099",
    )
    doc = _make_document_with_mints(
        transformations=(tx_split, tx_text_only),
        warnings=warnings,
        extra_nodes=(synthetic_note, synthetic_editorial, synthetic_article),
    )

    summary = snapshot_utils.body_note_splitter_summary(doc)

    assert summary["n_transformations"] == 2
    assert summary["n_warnings"] == 2
    assert summary["n_body_note_split_transformations"] == 1
    assert summary["n_body_note_split_minted_warnings"] == 1
    assert summary["n_synthetic_body_note_nodes"] == 3
    assert summary["synthetic_body_note_nodes_by_category"] == {
        SemanticCategory.ARTICLE_HEADER.value: 1,
        SemanticCategory.EDITORIAL_NOTE.value: 1,
        SemanticCategory.NOTE.value: 1,
    }
    assert isinstance(summary["body_note_splitter_digest"], str)
    assert len(summary["body_note_splitter_digest"]) == 64


def test_body_note_splitter_summary_deduplicates_node_across_tx_and_warning() -> None:
    synthetic_note = _make_text_node("node_0042", SemanticCategory.NOTE, text="(1) one")
    tx = Transformation(
        step_id="bic_body_note_splitter",
        node_id="node_0001",
        page_index=0,
        position=(0, 1),
        original="x",
        normalized="",
        split_into=("node_0042",),
    )
    warning_same_id = (
        "plugin:manuale_bic:note_section_split_minted_node_node_0042_page_0_marker_1",
    )
    doc = _make_document_with_mints(
        transformations=(tx,),
        warnings=warning_same_id,
        extra_nodes=(synthetic_note,),
    )

    summary = snapshot_utils.body_note_splitter_summary(doc)

    assert summary["n_synthetic_body_note_nodes"] == 1
    assert summary["synthetic_body_note_nodes_by_category"] == {
        SemanticCategory.NOTE.value: 1,
    }


def test_body_note_splitter_digest_handles_missing_synthetic_node() -> None:
    tx = Transformation(
        step_id="giappichelli_body_note_splitter",
        node_id="node_0001",
        page_index=0,
        position=(0, 1),
        original="x",
        normalized="",
        split_into=("node_9999",),
    )
    doc = _make_document_with_mints(transformations=(tx,))

    digest = snapshot_utils.body_note_splitter_digest(doc)

    assert isinstance(digest, str)
    assert len(digest) == 64


# ---------------------------------------------------------------------------
# CR minting digest tests (P-019)


_EMPTY_SHA256 = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"


def test_cross_ref_minting_digest_empty_on_document_without_cr() -> None:
    doc = _make_document_with_mints()

    digest = snapshot_utils.cross_ref_minting_digest(doc)

    assert digest == _EMPTY_SHA256


def test_cross_ref_minting_digest_captures_cross_reference_nodes() -> None:
    cr = _make_text_node("node_0042", SemanticCategory.CROSS_REFERENCE, text="(1)", page=3)
    doc = _make_document_with_mints(extra_nodes=(cr,))

    digest = snapshot_utils.cross_ref_minting_digest(doc)

    assert digest != _EMPTY_SHA256


def test_cross_ref_minting_digest_is_text_sensitive() -> None:
    cr_a = _make_text_node("node_0042", SemanticCategory.CROSS_REFERENCE, text="(1)", page=3)
    cr_b = _make_text_node("node_0042", SemanticCategory.CROSS_REFERENCE, text="(2)", page=3)
    doc_a = _make_document_with_mints(extra_nodes=(cr_a,))
    doc_b = _make_document_with_mints(extra_nodes=(cr_b,))

    assert snapshot_utils.cross_ref_minting_digest(
        doc_a
    ) != snapshot_utils.cross_ref_minting_digest(doc_b)


def test_cross_ref_minting_digest_recognises_warning_subtypes() -> None:
    template_keys = (
        "cross_reference_minted",
        "inline_cross_reference_minted",
        "cross_reference_note_minted",
        "cross_reference_voce_minted",
        "cross_reference_paragraph_minted",
        "cross_reference_article_minted",
        "cross_reference_sentence_minted",
    )
    for template in template_keys:
        warnings = (f"plugin:demo:{template}_node_node_0099_page_2",)
        doc = _make_document_with_mints(warnings=warnings)
        digest = snapshot_utils.cross_ref_minting_digest(doc)
        assert digest != _EMPTY_SHA256, f"template {template!r} should match the CR minting pattern"


def test_cross_ref_minting_digest_ignores_unresolved_and_split_warnings() -> None:
    warnings = (
        "plugin:demo:cross_reference_unresolved_node_node_0099_marker_1",
        "plugin:demo:note_section_split_minted_node_node_0099_page_2_marker_1",
        "plugin:demo:book_page_anchor_minted_node_node_0099_page_2",
    )
    doc = _make_document_with_mints(warnings=warnings)

    digest = snapshot_utils.cross_ref_minting_digest(doc)

    assert digest == _EMPTY_SHA256


def test_cross_ref_minting_summary_combines_structural_and_mint_signals() -> None:
    cr_note = _make_text_node("node_0042", SemanticCategory.CROSS_REFERENCE, text="(1)")
    cr_voce = _make_text_node(
        "node_0043", SemanticCategory.CROSS_REFERENCE, text="v. CONTRATTO", page=4
    )
    warnings = (
        "plugin:enciclopedia_moderna:cross_reference_note_minted_node_node_0042_page_0_marker_1",
        "plugin:enciclopedia_moderna:cross_reference_voce_minted_node_node_0043_page_4_voce_CONTRATTO",
        "plugin:enciclopedia_moderna:cross_reference_unresolved_node_node_0042_marker_1",
    )
    doc = _make_document_with_mints(warnings=warnings, extra_nodes=(cr_note, cr_voce))

    summary = snapshot_utils.cross_ref_minting_summary(doc)

    assert summary["n_cross_reference"] == 2
    assert summary["n_cross_reference_minted_warnings"] == 2
    assert summary["cross_reference_minted_warnings_by_subtype"] == {
        "note": 1,
        "voce": 1,
    }
    assert isinstance(summary["cross_ref_minting_digest"], str)
    assert len(summary["cross_ref_minting_digest"]) == 64


def test_cross_ref_minting_summary_default_subtype_for_single_subtype_emitters() -> None:
    cr = _make_text_node("node_0042", SemanticCategory.CROSS_REFERENCE, text="(1)")
    warnings = (
        "plugin:dejure_nota_sentenza:cross_reference_minted_node_node_0042_page_0_marker_1",
    )
    doc = _make_document_with_mints(warnings=warnings, extra_nodes=(cr,))

    summary = snapshot_utils.cross_ref_minting_summary(doc)

    assert summary["cross_reference_minted_warnings_by_subtype"] == {"default": 1}


def test_cross_ref_minting_digest_is_order_insensitive_on_input() -> None:
    cr_a = _make_text_node("node_0042", SemanticCategory.CROSS_REFERENCE, text="(1)")
    cr_b = _make_text_node("node_0043", SemanticCategory.CROSS_REFERENCE, text="(2)")
    doc_ab = _make_document_with_mints(extra_nodes=(cr_a, cr_b))
    doc_ba = _make_document_with_mints(extra_nodes=(cr_b, cr_a))

    assert snapshot_utils.cross_ref_minting_digest(
        doc_ab
    ) == snapshot_utils.cross_ref_minting_digest(doc_ba)


# ---------------------------------------------------------------------------
# matches_score_digest / matches_score_summary (P-040, Fase 6)
# ---------------------------------------------------------------------------


def test_matches_score_digest_empty_map_is_stable() -> None:
    assert snapshot_utils.matches_score_digest({}) == snapshot_utils.matches_score_digest({})


def test_matches_score_digest_changes_with_value_drift() -> None:
    base = {"PluginA": 0.50, "PluginB": 0.75}
    drifted = {"PluginA": 0.50, "PluginB": 0.76}
    assert snapshot_utils.matches_score_digest(base) != snapshot_utils.matches_score_digest(drifted)


def test_matches_score_digest_is_order_insensitive_on_input() -> None:
    in_order = {"PluginA": 0.50, "PluginB": 0.75}
    reversed_order = {"PluginB": 0.75, "PluginA": 0.50}
    assert snapshot_utils.matches_score_digest(in_order) == snapshot_utils.matches_score_digest(
        reversed_order
    )


def test_matches_score_digest_handles_int_scores() -> None:
    int_score = {"PluginA": 1}
    float_score = {"PluginA": 1.0}
    assert snapshot_utils.matches_score_digest(int_score) == snapshot_utils.matches_score_digest(
        float_score
    )


def test_matches_score_digest_rounds_to_decimals_argument() -> None:
    base = {"PluginA": 0.5000001, "PluginB": 0.6000001}
    same_under_default = {"PluginA": 0.5000003, "PluginB": 0.6000004}
    assert snapshot_utils.matches_score_digest(base) == snapshot_utils.matches_score_digest(
        same_under_default
    )


def test_matches_score_digest_distinguishes_when_decimals_increased() -> None:
    base = {"PluginA": 0.5000001}
    drifted = {"PluginA": 0.5000003}
    assert snapshot_utils.matches_score_digest(
        base, decimals=10
    ) != snapshot_utils.matches_score_digest(drifted, decimals=10)


def test_matches_score_summary_returns_sorted_scores_and_digest() -> None:
    summary = snapshot_utils.matches_score_summary({"Zeta": 0.30, "Alpha": 0.90})
    assert summary["n_plugins"] == 2
    assert list(summary["scores"].keys()) == ["Alpha", "Zeta"]
    assert summary["scores"]["Alpha"] == 0.9
    assert summary["scores"]["Zeta"] == 0.3
    assert summary["matches_score_digest"] == snapshot_utils.matches_score_digest(
        {"Alpha": 0.90, "Zeta": 0.30}
    )


def test_matches_score_summary_rounds_scores() -> None:
    summary = snapshot_utils.matches_score_summary({"Plugin": 0.1234567890123})
    assert summary["scores"]["Plugin"] == 0.123457


def test_matches_score_summary_empty_map_returns_empty_scores() -> None:
    summary = snapshot_utils.matches_score_summary({})
    assert summary["n_plugins"] == 0
    assert summary["scores"] == {}
    assert summary["matches_score_digest"] == snapshot_utils.matches_score_digest({})
