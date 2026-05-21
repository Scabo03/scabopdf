"""Capture or check apparatus-binding snapshot baselines for P-021.

P-021 is the pattern of overriding the tier 1 generic cross-reference
binding resolver (``apparatus.resolver._resolve_cross_references``)
with a plugin-specific scope predicate. Three plugins implement
divergent scope predicates today:

- ``manuale_bic`` — per-chapter scope (the ``HEADING_1`` ancestor
  defines the binding scope; ~1430/1489 CR bind = 96.0 %).
- ``dejure_dottrina`` — per-article scope (the ``GENRE_BANNER``
  boundary defines the article scope; ~100 % CR binding rate on the
  three DT fixtures).
- ``manuale_giuffre_diretto`` (Torrente) — global scope (no
  hierarchy; ~7000 CR globally indexed via marker → HEADING_4).

The Fase 3 diagnostic (CARRYOVER v2.22) concluded that the three
implementations diverge on three orthogonal axes (scope boundary,
marker normalisation, CR iteration pattern) and a unifying factory
would be over-engineering. The pattern stays plugin-local. The
P-021 mitigation introduced by this script is **regression
protection only**: capture per-fixture digests of every
``CROSS_REF_TARGET`` binding so a future session that touches the
apparatus resolver or the Node minting order surfaces any silent
rebind via :func:`snapshot_utils.cross_ref_binding_digest`.

Risk-A=H exposure: the existing P-014 and Phase 3 baselines protect
``n_cross_reference`` and ``n_warnings``, but a regression that
rebinds a CR Node to a different (wrong) target leaves both counters
unchanged and would slip past the baseline assertion. The per-binding
digest catches this because the sorted ``(source_id, marker,
target_id)`` triple changes when any single binding rebinds.

Fixtures chosen to maximise coverage of the three scope strategies:

- ``marrone`` — BIC per-chapter scope, 13 HEADING_1 chapters,
  1430 / 1489 CR_TARGET bindings.
- ``dejure_dt_cartabia`` — DT per-article scope, 7 articles (largest
  multi-article bundle), 460 CR_TARGET bindings.
- ``torrente`` — Torrente global scope, 1559-page fixture with
  several thousand CR_TARGET bindings.

Usage::

    python pipeline/scripts/capture_p021_baseline.py --mode write
    python pipeline/scripts/capture_p021_baseline.py --mode check
"""

from __future__ import annotations

import argparse
import sys
from collections.abc import Callable
from pathlib import Path
from typing import Any

REPO_PIPELINE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_PIPELINE / "src"))
sys.path.insert(0, str(REPO_PIPELINE))

from scabopdf_pipeline.apparatus import resolve_apparatus
from scabopdf_pipeline.classification import classify
from scabopdf_pipeline.emission import convert_document
from scabopdf_pipeline.extraction import extract
from scabopdf_pipeline.postprocessing import apply_post_processing
from scabopdf_pipeline.profiles.dejure_dottrina import DejureDottrinaProfile
from scabopdf_pipeline.profiles.manuale_bic import ManualeBicProfile
from scabopdf_pipeline.profiles.manuale_giuffre_diretto import ManualeGiuffreDirectoProfile
from scabopdf_pipeline.profiling.plugin import ProfilePlugin
from scabopdf_pipeline.profiling.profile import DocumentProfile
from scabopdf_pipeline.reconstruction import reconstruct
from tests import snapshot_utils

FIXTURES_DIR = REPO_PIPELINE / "tests" / "fixtures" / "private"


def _make_profile(plugin: ProfilePlugin, confidence: float = 0.90) -> DocumentProfile:
    return DocumentProfile(
        profile_id=plugin.profile_id,
        editorial_family=plugin.editorial_family,
        genre=plugin.genre,
        layouts_available=["L1", "L2", "L3", "L4"],
        layouts_disabled=plugin.get_layouts_disabled(),
        post_processing=plugin.get_post_processing(),
        categories_emitted=plugin.get_categories(),
        confidence=confidence,
        warnings=[],
    )


def _run_pipeline(plugin: ProfilePlugin, fixture: Path) -> dict[str, Any]:
    """Run the full Layer 1 pipeline and return an apparatus-binding summary."""
    profile = _make_profile(plugin)
    extraction = extract(fixture)
    classified = classify(extraction, profile, plugin)
    document = reconstruct(extraction, classified, profile, plugin)
    document = resolve_apparatus(document, extraction, classified, plugin)
    document = apply_post_processing(document, extraction, classified, plugin)
    convert_document(document, extraction, profile, fixture)
    return snapshot_utils.apparatus_binding_summary(document)


_BASELINES: list[tuple[str, Callable[[], ProfilePlugin], str]] = [
    ("p021_baseline_marrone", ManualeBicProfile, "marrone_istituzioni.pdf"),
    (
        "p021_baseline_dejure_dt_cartabia",
        DejureDottrinaProfile,
        "dejure_dt_riforma_cartabia.pdf",
    ),
    ("p021_baseline_torrente", ManualeGiuffreDirectoProfile, "torrente_schlesinger.pdf"),
]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--mode",
        choices=("write", "check"),
        required=True,
        help="write: capture baselines; check: assert against committed snapshots",
    )
    args = parser.parse_args(argv)

    skipped: list[str] = []
    failures: list[str] = []
    written: list[str] = []
    checked: list[str] = []

    for snapshot_name, plugin_cls, fixture_filename in _BASELINES:
        fixture = FIXTURES_DIR / fixture_filename
        if not fixture.exists():
            skipped.append(f"{snapshot_name} (fixture missing: {fixture_filename})")
            continue
        print(f"--- {snapshot_name} ({fixture_filename}) ---", flush=True)
        summary = _run_pipeline(plugin_cls(), fixture)
        if args.mode == "write":
            target = snapshot_utils.save_snapshot(snapshot_name, summary)
            written.append(str(target.relative_to(REPO_PIPELINE.parent)))
        else:
            try:
                snapshot_utils.assert_snapshot_matches(snapshot_name, summary)
                checked.append(snapshot_name)
            except AssertionError as exc:
                failures.append(f"{snapshot_name}:\n{exc}")

    print()
    print("=" * 70)
    if args.mode == "write":
        print(f"Wrote {len(written)} baselines:")
        for entry in written:
            print(f"  - {entry}")
    else:
        print(f"Checked {len(checked)} baselines:")
        for entry in checked:
            print(f"  - {entry} OK")
    if skipped:
        print(f"Skipped {len(skipped)} (fixture missing):")
        for entry in skipped:
            print(f"  - {entry}")
    if failures:
        print(f"FAILED {len(failures)}:")
        for entry in failures:
            print(entry)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
