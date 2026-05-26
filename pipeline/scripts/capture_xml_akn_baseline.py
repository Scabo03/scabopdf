"""Capture or check XML AKN parser snapshot baselines (N-NNN family).

The XML AKN backend produces a ``ScabopdfDocument`` per fixture via
``parse(xml_path) → to_scabopdf_document(...) → model_dump(mode="json")``.
The snapshot is the entire emitted dict with ``document_id`` removed
(non-deterministic UUID) plus three bookkeeping keys (``_baseline_id``,
``_baseline_source``, ``_baseline_xml_akn_metadata``) appended for
traceability and FRBR-metadata side-channel validation.

The N-NNN family covers thirteen fixtures at the closure of debt (xvii):

* N-001 — legge_56_2007 (smallest BEN_FORMATO, 5 nodes)
* N-002 — legge_gelli_bianco (headless-paragraph convention)
* N-003 — dlgs_231_2001 (15 chapters)
* N-004 — legge_bilancio_2023 (articolo-unico patologico)
* N-005 — codice_strada (large code)
* N-006 — codice_procedura_penale (largest article count, 906)
* N-007 — tuf_dlgs_58_1998 (largest BEN_FORMATO, 4 MB)
* N-008 — codice_penale FRAGMENTED (987 synthetic articles)
* N-009 — codice_civile FRAGMENTED (3256 synthetic articles)
* N-010 — legge_capitali (AKN modifications calibration, debt xiv:
  80 AMENDMENT + 88 QUOTED_TEXT + 161 UPDATE_BLOCK)
* N-011 — dl_rilancio (D.L. 34/2020 "Rilancio", debt xvii edge case:
  zero body-side `<mod>`, 1031 UPDATE_BLOCK with single-type
  "insertion" — atto modificato senza essere modificatore narrativo)
* N-012 — dlgs_cartabia (D.Lgs. 149/2022 "Riforma Cartabia", debt xvii
  stress test: 483 AMENDMENT + 518 QUOTED_TEXT + 1287 UPDATE_BLOCK,
  cross-epoch URN binding R.D. 1940/1941/1942, nuovo valore
  `type="split"`)
* N-013 — dlgs_correttivo_appalti (D.Lgs. 209/2024 "Correttivo Codice
  Appalti", debt xvii mid-size: 221 AMENDMENT + 214 QUOTED_TEXT + 453
  UPDATE_BLOCK + forma URN-FRBR con frammento `~art_NN__para_NN`)

Usage::

    python pipeline/scripts/capture_xml_akn_baseline.py --mode write
    python pipeline/scripts/capture_xml_akn_baseline.py --mode check

In ``check`` mode the script exits non-zero if any baseline drifts
from its committed snapshot under ``pipeline/tests/snapshots/``.
Missing fixtures (typically due to a fresh clone without local PDFs)
are reported and skipped, not failed — the integration tests apply the
same convention via ``_skip_if_missing``.

The script is the canonical regeneration entry-point after any schema
bump (every committed N-* baseline carries the ``schema_version``
field and must be updated when the contract bumps), parser change
(any change that shifts Node ids, adds/removes fields, or rebalances
warnings must regenerate every affected baseline deliberately) or new
fixture (a new ``test_baseline_holds_for_<name>`` test in
``test_xml_akn_parser.py`` is paired with a new entry in the
``_BASELINES`` tuple below).
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

from scabopdf_pipeline.xml_akn import parse  # noqa: E402
from scabopdf_pipeline.xml_akn.emitter import to_scabopdf_document  # noqa: E402

_FIXTURE_ROOT = _REPO_ROOT / "pipeline" / "tests" / "fixtures"
_CALIBRATION = _FIXTURE_ROOT / "normattiva_calibration"
_EXPLORATION = _FIXTURE_ROOT / "normattiva_exploration"
_SNAPSHOT_ROOT = _REPO_ROOT / "pipeline" / "tests" / "snapshots"


_BASELINES: tuple[tuple[str, Path, str], ...] = (
    (
        "N-001",
        _CALIBRATION / "legge_56_2007" / "legge_56_2007.xml",
        "xml_akn_baseline_legge_56_2007.json",
    ),
    (
        "N-002",
        _CALIBRATION / "legge_gelli_bianco" / "legge_gelli_bianco.xml",
        "xml_akn_baseline_legge_gelli_bianco.json",
    ),
    (
        "N-003",
        _CALIBRATION / "dlgs_231_2001" / "dlgs_231_2001.xml",
        "xml_akn_baseline_dlgs_231_2001.json",
    ),
    (
        "N-004",
        _CALIBRATION / "legge_bilancio_2023" / "legge_bilancio_2023.xml",
        "xml_akn_baseline_legge_bilancio_2023.json",
    ),
    (
        "N-005",
        _CALIBRATION / "codice_strada" / "codice_strada.xml",
        "xml_akn_baseline_codice_strada.json",
    ),
    (
        "N-006",
        _CALIBRATION / "codice_procedura_penale" / "codice_procedura_penale.xml",
        "xml_akn_baseline_codice_procedura_penale.json",
    ),
    (
        "N-007",
        _CALIBRATION / "tuf_dlgs_58_1998" / "tuf_dlgs_58_1998.xml",
        "xml_akn_baseline_tuf_dlgs_58_1998.json",
    ),
    (
        "N-008",
        _EXPLORATION / "codice_penale" / "codice_penale.xml",
        "xml_akn_baseline_codice_penale.json",
    ),
    (
        "N-009",
        _CALIBRATION / "codice_civile" / "codice_civile.xml",
        "xml_akn_baseline_codice_civile.json",
    ),
    (
        "N-010",
        _EXPLORATION / "legge_capitali" / "legge_capitali.xml",
        "xml_akn_baseline_legge_capitali.json",
    ),
    (
        "N-011",
        _EXPLORATION / "dl_rilancio" / "dl_rilancio.xml",
        "xml_akn_baseline_dl_rilancio.json",
    ),
    (
        "N-012",
        _EXPLORATION / "dlgs_cartabia" / "dlgs_cartabia.xml",
        "xml_akn_baseline_dlgs_cartabia.json",
    ),
    (
        "N-013",
        _EXPLORATION / "dlgs_correttivo_appalti" / "dlgs_correttivo_appalti.xml",
        "xml_akn_baseline_dlgs_correttivo_appalti.json",
    ),
)


def _build_baseline_dict(baseline_id: str, xml_path: Path) -> dict[str, object]:
    """Produce the snapshot dict for one N-NNN baseline.

    Reproduces the helper convention of
    ``tests/integration/test_xml_akn_parser._parse_and_emit_dict`` plus
    the bookkeeping keys appended at the top level for traceability.
    """
    result = parse(xml_path)
    sdoc = to_scabopdf_document(result, xml_path)
    data: dict[str, object] = sdoc.model_dump(mode="json")
    data.pop("document_id", None)
    bookkeeping: dict[str, object] = {
        "_baseline_id": baseline_id,
        "_baseline_source": str(xml_path.relative_to(_REPO_ROOT)),
        "_baseline_xml_akn_metadata": {
            "work_uri": result.metadata.work_uri,
            "work_alias_urn": result.metadata.work_alias_urn,
            "work_alias_eli": result.metadata.work_alias_eli,
            "act_name_attribute": result.metadata.act_name_attribute,
            "title": result.metadata.title,
        },
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


def _write_one(baseline_id: str, xml_path: Path, snapshot_name: str) -> int:
    if not xml_path.exists():
        print(f"[{baseline_id}] SKIP — fixture missing: {xml_path}")
        return 0
    data = _build_baseline_dict(baseline_id, xml_path)
    snapshot_path = _SNAPSHOT_ROOT / snapshot_name
    snapshot_path.write_text(
        json.dumps(data, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    n_nodes = _count_nodes(data.get("structure", []))
    print(f"[{baseline_id}] WROTE {snapshot_path.name}  (n_nodes={n_nodes})")
    return 0


def _check_one(baseline_id: str, xml_path: Path, snapshot_name: str) -> int:
    if not xml_path.exists():
        print(f"[{baseline_id}] SKIP — fixture missing: {xml_path}")
        return 0
    snapshot_path = _SNAPSHOT_ROOT / snapshot_name
    if not snapshot_path.exists():
        print(f"[{baseline_id}] FAIL — snapshot missing: {snapshot_path}")
        return 1
    actual = _build_baseline_dict(baseline_id, xml_path)
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
    for baseline_id, xml_path, snapshot_name in selected:
        if args.mode == "write":
            rc |= _write_one(baseline_id, xml_path, snapshot_name)
        else:
            rc |= _check_one(baseline_id, xml_path, snapshot_name)
    return rc


if __name__ == "__main__":
    sys.exit(main())
