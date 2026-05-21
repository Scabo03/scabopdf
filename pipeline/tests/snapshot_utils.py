"""Lightweight snapshot-baseline tooling for refactor mitigation.

This module provides minimal helpers to capture and compare structural
baselines (typically category-count histograms, apparatus binding rates,
warning counts) on the real-fixture pipelines before and after a refactor
that should be byte-equivalent on its observable outputs.

The tooling is deliberately dependency-free: no ``syrupy`` or external
snapshot library is introduced. Snapshots are stored as plain JSON files
under ``pipeline/tests/snapshots/`` and committed to the repository,
following the same convention as the schema drift baseline at
``shared/schema.json``.

Three entry points:

- :func:`category_counts` extracts a sorted, comparable counter dict
  from a :class:`Document` (string keys for stable JSON serialisation).
- :func:`save_snapshot` writes a JSON baseline. Used by the mitigation
  script before the refactor (Step 0.5 of CARRYOVER v2.21).
- :func:`assert_snapshot_matches` reads the JSON baseline and fails
  with a precise diff if any value has drifted.

The pattern is reusable by any future refactor session that needs a
fast equivalence check against a structural baseline.
"""

from __future__ import annotations

import hashlib
import json
from collections.abc import Iterable
from pathlib import Path
from typing import Any

from scabopdf_pipeline.apparatus.types import ApparatusRefKind
from scabopdf_pipeline.reconstruction.types import Document, Node
from scabopdf_pipeline.schema.categories import SemanticCategory

SNAPSHOTS_ROOT = Path(__file__).parent / "snapshots"
"""Filesystem root for committed JSON snapshot baselines."""


def _iter_nodes(roots: Iterable[Node]) -> Iterable[Node]:
    """Pre-order DFS traversal over a forest of Node roots."""
    for root in roots:
        yield root
        yield from _iter_nodes(root.children)


def category_counts(document: Document) -> dict[str, int]:
    """Return a sorted dict mapping ``SemanticCategory.value`` to its count.

    Sorting by key ensures byte-stable JSON serialisation across runs.
    """
    counts: dict[str, int] = {}
    for node in _iter_nodes(document.root):
        key = node.category.value
        counts[key] = counts.get(key, 0) + 1
    return dict(sorted(counts.items()))


def _ensure_snapshot_dir() -> None:
    SNAPSHOTS_ROOT.mkdir(parents=True, exist_ok=True)


def snapshot_path(name: str) -> Path:
    """Resolve the JSON snapshot path for ``name`` (no ``.json`` suffix)."""
    return SNAPSHOTS_ROOT / f"{name}.json"


def save_snapshot(name: str, data: dict[str, Any]) -> Path:
    """Write ``data`` as pretty-printed JSON under :data:`SNAPSHOTS_ROOT`.

    Returns the path written. Used by the mitigation pre-refactor script
    to record a baseline; called explicitly with ``--write`` mode, never
    automatically.
    """
    _ensure_snapshot_dir()
    target = snapshot_path(name)
    payload = json.dumps(data, indent=2, sort_keys=True, ensure_ascii=False) + "\n"
    target.write_text(payload, encoding="utf-8")
    return target


def load_snapshot(name: str) -> dict[str, Any]:
    """Read a JSON snapshot baseline. Raises ``FileNotFoundError`` if missing.

    The caller decides whether the snapshot is required (post-refactor
    equivalence check) or optional (forward-looking acquisition).
    """
    target = snapshot_path(name)
    if not target.exists():
        raise FileNotFoundError(
            f"snapshot {name!r} not found at {target} — "
            "run the pre-refactor mitigation script first"
        )
    return dict(json.loads(target.read_text(encoding="utf-8")))


def diff_dicts(expected: dict[str, Any], actual: dict[str, Any]) -> list[str]:
    """Return a list of human-readable diff lines, empty if dicts agree."""
    lines: list[str] = []
    expected_keys = set(expected)
    actual_keys = set(actual)
    for key in sorted(expected_keys - actual_keys):
        lines.append(f"  - {key}: removed (was {expected[key]!r})")
    for key in sorted(actual_keys - expected_keys):
        lines.append(f"  - {key}: added ({actual[key]!r})")
    for key in sorted(expected_keys & actual_keys):
        if expected[key] != actual[key]:
            lines.append(f"  - {key}: {expected[key]!r} -> {actual[key]!r}")
    return lines


def assert_snapshot_matches(name: str, actual: dict[str, Any]) -> None:
    """Compare ``actual`` against the saved baseline. Raise on drift.

    The exception message lists every key whose value drifted, so test
    output points the developer directly to the regression.
    """
    expected = load_snapshot(name)
    drift = diff_dicts(expected, actual)
    if drift:
        diff_text = "\n".join(drift)
        raise AssertionError(
            f"snapshot {name!r} drift:\n{diff_text}\n"
            f"if the new behaviour is intentional, regenerate the snapshot "
            f"via the pre-refactor mitigation script"
        )


def document_structural_summary(document: Document) -> dict[str, Any]:
    """Return a compact structural summary for snapshot baselines.

    Includes the full :func:`category_counts` plus the scalar counts of
    ``warnings`` and ``transformations`` on the Document.
    """
    summary: dict[str, Any] = {"category_counts": category_counts(document)}
    summary["n_warnings"] = len(document.warnings)
    summary["n_transformations"] = len(document.transformations)
    return summary


def cross_ref_binding_digest(document: Document) -> str:
    """Return a SHA-256 hex digest of every ``CROSS_REF_TARGET`` binding.

    Walks the document tree, collects every
    :class:`apparatus.types.ApparatusRef` of kind ``CROSS_REF_TARGET``
    attached to a ``CROSS_REFERENCE`` Node, and computes a stable
    digest over the sorted ``(source_node_id, source_marker,
    target_node_id)`` triples. Two documents whose binding rate is
    numerically identical but whose per-binding targets diverge
    produce different digests, catching the silent-rebind regression
    of pattern (ll) of CLAUDE.md and the related risk-A=H exposure
    documented in the P-021 diagnostic.

    Returns the empty-digest of an empty triple list when the document
    has no ``CROSS_REF_TARGET`` bindings.
    """
    triples: list[tuple[str, str, str]] = []
    for node in _iter_nodes(document.root):
        if node.category is not SemanticCategory.CROSS_REFERENCE:
            continue
        for ref in node.apparatus_refs:
            if ref.kind is not ApparatusRefKind.CROSS_REF_TARGET:
                continue
            triples.append((node.id, ref.source_marker or "", ref.target_node_id))
    triples.sort()
    serial = "\n".join(f"{src}|{mark}|{tgt}" for src, mark, tgt in triples)
    return hashlib.sha256(serial.encode("utf-8")).hexdigest()


def apparatus_binding_summary(document: Document) -> dict[str, Any]:
    """Return a compact apparatus-binding summary for snapshot baselines.

    Combines :func:`document_structural_summary` with the per-binding
    digest produced by :func:`cross_ref_binding_digest` plus the
    explicit counts of bound and unbound ``CROSS_REFERENCE`` Nodes.

    Used by the P-021 mitigation baselines for fixtures whose plugins
    override the tier 1 generic apparatus binding (BIC per-chapter
    scope, DT per-article scope, Torrente global scope) to catch
    silent rebind regressions that a category-count check cannot
    detect on its own.
    """
    summary = document_structural_summary(document)
    n_cross_ref_target = 0
    n_cross_reference = 0
    for node in _iter_nodes(document.root):
        if node.category is not SemanticCategory.CROSS_REFERENCE:
            continue
        n_cross_reference += 1
        for ref in node.apparatus_refs:
            if ref.kind is ApparatusRefKind.CROSS_REF_TARGET:
                n_cross_ref_target += 1
                break
    summary["n_cross_reference"] = n_cross_reference
    summary["n_cross_ref_target_bound"] = n_cross_ref_target
    summary["n_cross_ref_unbound"] = n_cross_reference - n_cross_ref_target
    summary["cross_ref_binding_digest"] = cross_ref_binding_digest(document)
    return summary


__all__ = [
    "SNAPSHOTS_ROOT",
    "apparatus_binding_summary",
    "assert_snapshot_matches",
    "category_counts",
    "cross_ref_binding_digest",
    "diff_dicts",
    "document_structural_summary",
    "load_snapshot",
    "save_snapshot",
    "snapshot_path",
]
