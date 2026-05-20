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
