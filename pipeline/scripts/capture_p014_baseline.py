"""Capture or check snapshot baselines for the P-014 mitigation.

P-014 promotes the NOTE / CROSSREF marker regex into
``apparatus/marker_patterns.py`` (Stage 3 of the Promotion Analysis
Fase 1). The risk is silent regression on ``n_cross_reference`` or
``n_note`` counts if the centralised regex diverges from any of the
existing per-plugin variants. The mitigation is to capture a structural
summary baseline on representative fixtures before the extraction, then
re-run the same script after the extraction and assert byte-equivalence.

Fixtures chosen to maximise coverage with minimal runtime:

- ``dejure_ns_recisione`` — 3 pp, NS minimal narrative case-note.
- ``dejure_dt_concause`` — 59 pp, DT single dense article with
  multi-author and footnote-heavy notes section.
- ``edd_moderna_factoring`` — 14 pp, EM short voce-saggio with
  ``(N)`` + ``v. VOCE`` dual cross-reference subtypes.
- ``edd_storica_lavoro`` — 13 pp, ES voce-contenitore with OCR-fossilised
  numbered notes.
- ``mandrioli_vol_iii`` — 488 pp, Giappichelli heavy ``(N)`` CR minting
  driven by textual regex (largest CR-minting plugin).
- ``marrone`` — 684 pp, BIC heavy multi-block body+note splitter.
- ``codici_penale`` — 2640 pp, Giuffrè codici intra-block article
  splitter with bracketed ``[N]`` cross-references.

Usage::

    python pipeline/scripts/capture_p014_baseline.py --mode write
    python pipeline/scripts/capture_p014_baseline.py --mode check

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
from scabopdf_pipeline.profiles.enciclopedia_moderna import EnciclopediaModernaProfile
from scabopdf_pipeline.profiles.enciclopedia_storica import EnciclopediaStoricaProfile
from scabopdf_pipeline.profiles.giuffre_codici import GiuffreCodiciProfile
from scabopdf_pipeline.profiles.manuale_bic import ManualeBicProfile
from scabopdf_pipeline.profiles.manuale_giappichelli import ManualeGiappichelliProfile
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
    ("p014_baseline_dejure_ns_recisione", DejureNotaSentenzaProfile, "dejure_ns_recisione_nesso_causale.pdf"),
    ("p014_baseline_dejure_dt_concause", DejureDottrinaProfile, "dejure_dt_concause_causalita.pdf"),
    ("p014_baseline_edd_moderna_factoring", EnciclopediaModernaProfile, "edd_factoring.pdf"),
    ("p014_baseline_edd_storica_lavoro", EnciclopediaStoricaProfile, "edd_lavoro.pdf"),
    ("p014_baseline_mandrioli_vol_iii", ManualeGiappichelliProfile, "mandrioli_carratta_vol_iii.pdf"),
    ("p014_baseline_marrone", ManualeBicProfile, "marrone_istituzioni.pdf"),
    ("p014_baseline_codici_penale", GiuffreCodiciProfile, "giuffre_codice_penale.pdf"),
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
