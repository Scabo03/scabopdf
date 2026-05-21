"""Capture or check snapshot baselines for the Phase 3 refactor.

Phase 3 of the Promotion Analysis promotes patterns P-016 (stateful
notes-region walk) and P-017 (multi-sibling notes-section consolidator)
from the two DeJure plugins (:mod:`dejure_nota_sentenza` and
:mod:`dejure_dottrina`) to shared helpers in
:mod:`profiles._dejure_shared`. The risk is silent regression on:

- The number of synthetic NOTE Nodes minted by the consolidator
  (``n_note`` in :func:`snapshot_utils.category_counts`).
- The DT-specific ``EDITORIAL_NOTE`` category emission, not exercised
  by any NS fixture.
- The per-mint warning count (``n_warnings`` on the
  :class:`Document`).
- The :class:`Transformation` log structural reversibility
  (``n_transformations``).

Fixtures chosen to maximise coverage with minimal runtime:

- ``dejure_ns_giudizio`` — 22 pp, long academic NS exercising the
  P-017 consolidator with 54 minted NOTE Nodes (the canonical case
  the ``recisione`` fixture does not exercise).
- ``dejure_dt_bundle_procedura`` — 56 pp, 3-article DT bundle
  exercising the multi-article scope of P-017 via the GENRE_BANNER
  boundary closure.
- ``dejure_dt_cartabia`` — 184 pp, 7-article DT bundle (largest
  multi-article fixture), 459 minted NOTE + 2 EDITORIAL_NOTE.

The existing P-014 baselines (under
``pipeline/tests/snapshots/p014_baseline_*``) already cover
``dejure_ns_recisione`` (short narrative, no notes section, exercises
the EARLY-RETURN path of the consolidator) and ``dejure_dt_concause``
(single dense article with 96 NOTE + 1 EDITORIAL_NOTE); the Phase 3
baselines below extend the coverage to the remaining NS+DT fixtures
that exercise the consolidator under additional structural pressure.

Usage::

    python pipeline/scripts/capture_phase3_baseline.py --mode write
    python pipeline/scripts/capture_phase3_baseline.py --mode check

In ``check`` mode the script exits non-zero if any baseline drifts from
its committed snapshot under ``pipeline/tests/snapshots/``.
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
from scabopdf_pipeline.profiles.dejure_nota_sentenza import DejureNotaSentenzaProfile
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
    """Run the full Layer 1 pipeline and return a structural summary."""
    profile = _make_profile(plugin)
    extraction = extract(fixture)
    classified = classify(extraction, profile, plugin)
    document = reconstruct(extraction, classified, profile, plugin)
    document = resolve_apparatus(document, extraction, classified, plugin)
    document = apply_post_processing(document, extraction, classified, plugin)
    convert_document(document, extraction, profile, fixture)
    return snapshot_utils.document_structural_summary(document)


_BASELINES: list[tuple[str, Callable[[], ProfilePlugin], str]] = [
    (
        "phase3_baseline_dejure_ns_giudizio",
        DejureNotaSentenzaProfile,
        "dejure_ns_giudizio_universale.pdf",
    ),
    (
        "phase3_baseline_dejure_dt_bundle_procedura",
        DejureDottrinaProfile,
        "dejure_dt_bundle_procedura_civile.pdf",
    ),
    (
        "phase3_baseline_dejure_dt_cartabia",
        DejureDottrinaProfile,
        "dejure_dt_riforma_cartabia.pdf",
    ),
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
