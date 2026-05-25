"""Capture or check EPUB IPZS parser snapshot baselines (E-NNN family).

The EPUB IPZS backend produces a ``ScabopdfDocument`` per fixture via
``parse(epub_path) → to_scabopdf_document(...) → model_dump(mode="json")``.
The snapshot is the entire emitted dict with ``document_id`` removed
(non-deterministic UUID) plus three bookkeeping keys (``_baseline_id``,
``_baseline_source``, ``_baseline_epub_ipzs_metadata``) appended for
traceability and OPF-metadata side-channel validation.

The E-NNN family covers all 11 calibration + exploration fixtures at
landing of the EPUB IPZS backend (debt xv) on 2026-05-25:

* E-001 — legge_56_2007 (smallest STRUCTURED, ~12 nodes, no apparatus)
* E-002 — legge_gelli_bianco (STRUCTURED, 18 articles, mid-size)
* E-003 — dlgs_231_2001 (STRUCTURED, 109 articles)
* E-004 — legge_bilancio_2023 (STRUCTURED, 29 articles + external PDF links)
* E-005 — codice_strada (STRUCTURED, 266 articles + signatures)
* E-006 — codice_procedura_penale (STRUCTURED, 906 articles)
* E-007 — tuf_dlgs_58_1998 (STRUCTURED, 563 articles)
* E-008 — codice_penale (FLAT_ATTACHMENT, 987 attachment-just-text)
* E-009 — codice_civile (FLAT_ATTACHMENT, 3256 attachment-just-text)
* E-010 — legge_capitali (STRUCTURED, 28 articles + ins-akn AMENDMENTs)
* E-011 — legge_finanziaria_2007 (STRUCTURED, 1297 commi spread across
  14 article-num pages, the SPLIT_ARTICLE-of-one case)

Usage::

    python pipeline/scripts/capture_epub_ipzs_baseline.py --mode write
    python pipeline/scripts/capture_epub_ipzs_baseline.py --mode check

In ``check`` mode the script exits non-zero if any baseline drifts
from its committed snapshot under ``pipeline/tests/snapshots/``.
Missing fixtures (typically due to a fresh clone without local EPUBs)
are reported and skipped, not failed.

The script is the canonical regeneration entry-point after any schema
bump (every committed E-* baseline carries the ``schema_version``
field), parser change (any change that shifts Node ids, adds/removes
fields, or rebalances warnings must regenerate every affected baseline
deliberately), or new fixture.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
_SRC = _REPO_ROOT / "pipeline" / "src"
if str(_SRC) not in sys.path:
    sys.path.insert(0, str(_SRC))

from scabopdf_pipeline.epub_ipzs import parse  # noqa: E402
from scabopdf_pipeline.epub_ipzs.emitter import to_scabopdf_document  # noqa: E402

_FIXTURE_ROOT = _REPO_ROOT / "pipeline" / "tests" / "fixtures"
_CALIBRATION = _FIXTURE_ROOT / "normattiva_calibration"
_EXPLORATION = _FIXTURE_ROOT / "normattiva_exploration"
_SNAPSHOT_ROOT = _REPO_ROOT / "pipeline" / "tests" / "snapshots"


_BASELINES: tuple[tuple[str, Path, str], ...] = (
    (
        "E-001",
        _CALIBRATION / "legge_56_2007" / "legge_56_2007.epub",
        "epub_ipzs_baseline_legge_56_2007.json",
    ),
    (
        "E-002",
        _CALIBRATION / "legge_gelli_bianco" / "legge_gelli_bianco.epub",
        "epub_ipzs_baseline_legge_gelli_bianco.json",
    ),
    (
        "E-003",
        _CALIBRATION / "dlgs_231_2001" / "dlgs_231_2001.epub",
        "epub_ipzs_baseline_dlgs_231_2001.json",
    ),
    (
        "E-004",
        _CALIBRATION / "legge_bilancio_2023" / "legge_bilancio_2023.epub",
        "epub_ipzs_baseline_legge_bilancio_2023.json",
    ),
    (
        "E-005",
        _CALIBRATION / "codice_strada" / "codice_strada.epub",
        "epub_ipzs_baseline_codice_strada.json",
    ),
    (
        "E-006",
        _CALIBRATION / "codice_procedura_penale" / "codice_procedura_penale.epub",
        "epub_ipzs_baseline_codice_procedura_penale.json",
    ),
    (
        "E-007",
        _CALIBRATION / "tuf_dlgs_58_1998" / "tuf_dlgs_58_1998.epub",
        "epub_ipzs_baseline_tuf_dlgs_58_1998.json",
    ),
    (
        "E-008",
        _EXPLORATION / "codice_penale" / "codice_penale.epub",
        "epub_ipzs_baseline_codice_penale.json",
    ),
    (
        "E-009",
        _CALIBRATION / "codice_civile" / "codice_civile.epub",
        "epub_ipzs_baseline_codice_civile.json",
    ),
    (
        "E-010",
        _EXPLORATION / "legge_capitali" / "legge_capitali.epub",
        "epub_ipzs_baseline_legge_capitali.json",
    ),
    (
        "E-011",
        _EXPLORATION / "legge_finanziaria_2007" / "legge_finanziaria_2007.epub",
        "epub_ipzs_baseline_legge_finanziaria_2007.json",
    ),
)


def _build_baseline_dict(baseline_id: str, epub_path: Path) -> dict[str, object]:
    """Produce the snapshot dict for one E-NNN baseline."""
    result = parse(epub_path)
    sdoc = to_scabopdf_document(result, epub_path)
    data: dict[str, object] = sdoc.model_dump(mode="json")
    data.pop("document_id", None)
    bookkeeping: dict[str, object] = {
        "_baseline_id": baseline_id,
        "_baseline_source": str(epub_path.relative_to(_REPO_ROOT)),
        "_baseline_epub_ipzs_metadata": {
            "title": result.metadata.title,
            "creator": result.metadata.creator,
            "identifier": result.metadata.identifier,
            "generator": result.metadata.generator,
        },
        "_baseline_health_verdict": result.health_report.verdict.value,
    }
    # Insert bookkeeping at the top of the dict for human-readable layout
    out: dict[str, object] = {}
    for k, v in bookkeeping.items():
        out[k] = v
    for k, v in data.items():
        out[k] = v
    # Reorder: schema_version first (matching existing baseline convention)
    if "schema_version" in out:
        ordered: dict[str, object] = {"schema_version": out["schema_version"]}
        for k, v in out.items():
            if k == "schema_version":
                continue
            ordered[k] = v
        return ordered
    return out


def _write_one(baseline_id: str, epub_path: Path, snapshot_name: str) -> int:
    if not epub_path.exists():
        print(f"[{baseline_id}] SKIP — fixture missing: {epub_path}")
        return 0
    data = _build_baseline_dict(baseline_id, epub_path)
    snapshot_path = _SNAPSHOT_ROOT / snapshot_name
    snapshot_path.write_text(
        json.dumps(data, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    n_nodes = _count_nodes(data.get("structure", []))
    print(f"[{baseline_id}] WROTE {snapshot_path.name}  (n_nodes={n_nodes})")
    return 0


def _check_one(baseline_id: str, epub_path: Path, snapshot_name: str) -> int:
    if not epub_path.exists():
        print(f"[{baseline_id}] SKIP — fixture missing: {epub_path}")
        return 0
    snapshot_path = _SNAPSHOT_ROOT / snapshot_name
    if not snapshot_path.exists():
        print(f"[{baseline_id}] FAIL — snapshot missing: {snapshot_path}")
        return 1
    actual = _build_baseline_dict(baseline_id, epub_path)
    expected = json.loads(snapshot_path.read_text(encoding="utf-8"))
    if actual == expected:
        print(f"[{baseline_id}] OK     {snapshot_path.name}")
        return 0
    print(f"[{baseline_id}] DRIFT  {snapshot_path.name}")
    return 1


def _count_nodes(structure: object) -> int:
    """Count Nodes recursively (root forest + descendants)."""
    if not isinstance(structure, list):
        return 0
    total = 0
    for node in structure:
        if isinstance(node, dict):
            total += 1
            total += _count_nodes(node.get("children", []))
    return total


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument(
        "--mode",
        choices=("write", "check"),
        required=True,
        help="write: regenerate the baseline snapshot files; "
        "check: assert byte-for-byte equality between current parser "
        "output and committed snapshot.",
    )
    p.add_argument(
        "--only",
        metavar="ID",
        action="append",
        default=None,
        help="Restrict to a specific baseline id (repeatable). Useful for partial regeneration.",
    )
    args = p.parse_args(argv)

    selected = _BASELINES
    if args.only:
        wanted = set(args.only)
        selected = tuple(b for b in _BASELINES if b[0] in wanted)
        missing = wanted - {b[0] for b in selected}
        if missing:
            print(f"warning: unknown baseline ids ignored: {sorted(missing)}")

    rc = 0
    for baseline_id, epub_path, snapshot_name in selected:
        if args.mode == "write":
            rc |= _write_one(baseline_id, epub_path, snapshot_name)
        else:
            rc |= _check_one(baseline_id, epub_path, snapshot_name)
    return rc


if __name__ == "__main__":
    sys.exit(main())
