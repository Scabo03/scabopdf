"""Capture or check matches() score snapshot baselines for P-040.

P-040 is the cross-plugin ``matches()`` framework consolidation
documented in CLAUDE.md as pattern ``(yyy)``. Thirteen corpus plugin
implementations cover the same logical pattern of "score a document
against a profile-specific fingerprint" but diverge across four
structural families:

Family A — additive accumulator (8 plugin)
------------------------------------------

- Patriarca / Zanichelli, Tesauro / Compendio UTET, Mosconi / UWK,
  Mandrioli / Giappichelli, Torrente / Giuffrè diretto, EM, ES:
  ``score = 0.0`` followed by a sequence of positive contributions
  (font signature predicates, page geometry checks, producer
  substring checks, outline presence, apparatus thresholds) and
  zero or more symmetric penalties, ``return max(0.0, score)``.

Family B — DeJure Aspose triplet (3 plugin)
-------------------------------------------

- NS, MM, DT: ~95 % byte-equivalent on five contributions
  (Arial body dominance, Aspose producer, Letter geometry, bold
  title family, marginal apparatus penalty) plus one plugin-specific
  axis (banner / label / banner sister) and bidirectional ``matches()``
  symmetry via the ``dejure_banner_text`` SpecificMarker.

Family C — short-circuit (2 plugin)
-----------------------------------

- BIC: ``if not verdana_dominant: return 0.0`` then additive
  accumulator.
- materiali_studio: ``if not (gdocs or word): return 0.0`` then
  accumulator with ``max(0.0, min(1.0, score))`` clamp.

Family D — SpecificMarker-driven (1 plugin)
-------------------------------------------

- giuffre_codici: BD700x300 banner SpecificMarker is the primary
  signal (+0.50 PENALE/CIVILE, +0.40 LEGGI), accumulator follows.

The Fase 6 diagnostic concluded that a full unifying factory would
require six callable parameters of which ~60 % of the body would be
plugin-specific — promotion is over-engineering for the per-plugin
top-level recipe. The mitigation strategy is **mixed mode** (pattern
``(xxx)`` extended to scoring functions): extract six composable
primitives into ``profiling/match_helpers.py`` (``has_font_signature``,
``has_font_size_band_dominance``, ``is_geometry_close``,
``is_geometry_in_range``, ``producer_or_creator_contains``,
``find_specific_marker``) and let every plugin call them inline.

This script captures the matches() score for every plugin on every
representative fixture; the per-fixture digest is the regression-
protection counterpart of the property-based equivalence test suite
at ``tests/unit/profiling/test_matches_property.py``: the property
tests catch drift on synthetic signals, the digest catches drift on
the real calibrating corpus. Together they form the safety net
referenced by CLAUDE.md pattern ``(yyy)``.

Fixtures chosen to maximise coverage of the four families above:

- ``patriarca`` — Zanichelli ~150 pp (Family A simple, no clamp)
- ``tesauro`` — Compendio UTET, sister of Mosconi (Family A symmetric)
- ``mosconi`` — UWK 600 pp (Family A with multi-axis apparatus)
- ``mandrioli_vol_iii`` — Giappichelli 498 pp (Family A dense)
- ``marotta`` — Roman-law control sample (Family A non-promotion)
- ``torrente`` — Giuffrè diretto 1559 pp (Family A with penalty)
- ``marrone`` — BIC Marrone 684 pp (Family C short-circuit)
- ``dejure_ns_recisione`` — NS short narrative (Family B empty marker)
- ``dejure_ns_giudizio`` — NS long academic (Family B dense marker)
- ``dejure_mm_concause`` — MM single massima (Family B)
- ``dejure_dt_concause`` — DT single article (Family B)
- ``edd_factoring`` — EM 14 pp (Family A range geometry)
- ``edd_lavoro`` — ES 13 pp (Family A OCR band-summed)
- ``materiali_tributario`` — materiali_studio Word (Family C short-circuit)

Usage::

    python pipeline/scripts/capture_p040_baseline.py --mode write
    python pipeline/scripts/capture_p040_baseline.py --mode check
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

REPO_PIPELINE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_PIPELINE / "src"))
sys.path.insert(0, str(REPO_PIPELINE))

from scabopdf_pipeline.profiles.compendio_utet import CompendioUtetProfile
from scabopdf_pipeline.profiles.dejure_dottrina import DejureDottrinaProfile
from scabopdf_pipeline.profiles.dejure_massime import DejureMassimeProfile
from scabopdf_pipeline.profiles.dejure_nota_sentenza import DejureNotaSentenzaProfile
from scabopdf_pipeline.profiles.enciclopedia_moderna import EnciclopediaModernaProfile
from scabopdf_pipeline.profiles.enciclopedia_storica import EnciclopediaStoricaProfile
from scabopdf_pipeline.profiles.giuffre_codici import GiuffreCodiciProfile
from scabopdf_pipeline.profiles.manuale_bic import ManualeBicProfile
from scabopdf_pipeline.profiles.manuale_giappichelli import ManualeGiappichelliProfile
from scabopdf_pipeline.profiles.manuale_giuffre_diretto import ManualeGiuffreDirectoProfile
from scabopdf_pipeline.profiles.manuale_utet_wolterskluwer import (
    ManualeUtetWolterskluwerProfile,
)
from scabopdf_pipeline.profiles.manuale_zanichelli_giuridica import (
    ManualeZanichelliGiuridicaProfile,
)
from scabopdf_pipeline.profiles.materiali_studio import MaterialiStudioProfile
from scabopdf_pipeline.profiling.plugin import ProfilePlugin
from tests import snapshot_utils
from tests.integration.test_layer1_end_to_end import _build_signals_from_fixture

FIXTURES_DIR = REPO_PIPELINE / "tests" / "fixtures" / "private"

_PLUGIN_CLASSES: tuple[type[ProfilePlugin], ...] = (
    ManualeZanichelliGiuridicaProfile,
    CompendioUtetProfile,
    ManualeUtetWolterskluwerProfile,
    ManualeGiappichelliProfile,
    ManualeGiuffreDirectoProfile,
    ManualeBicProfile,
    DejureNotaSentenzaProfile,
    DejureMassimeProfile,
    DejureDottrinaProfile,
    EnciclopediaModernaProfile,
    EnciclopediaStoricaProfile,
    GiuffreCodiciProfile,
    MaterialiStudioProfile,
)

_BASELINES: tuple[tuple[str, str], ...] = (
    ("p040_baseline_patriarca", "patriarca_benazzo.pdf"),
    ("p040_baseline_tesauro", "tesauro_compendio.pdf"),
    ("p040_baseline_mosconi", "mosconi_campiglio.pdf"),
    ("p040_baseline_mandrioli_vol_iii", "mandrioli_carratta_vol_iii.pdf"),
    ("p040_baseline_marotta", "marotta_cittadinanza_romana.pdf"),
    ("p040_baseline_torrente", "torrente_schlesinger.pdf"),
    ("p040_baseline_marrone", "marrone_istituzioni.pdf"),
    ("p040_baseline_dejure_ns_recisione", "dejure_ns_recisione_nesso_causale.pdf"),
    ("p040_baseline_dejure_ns_giudizio", "dejure_ns_giudizio_universale.pdf"),
    ("p040_baseline_dejure_mm_concause", "dejure_mm_concause_naturali.pdf"),
    ("p040_baseline_dejure_dt_concause", "dejure_dt_concause_causalita.pdf"),
    ("p040_baseline_edd_factoring", "edd_factoring.pdf"),
    ("p040_baseline_edd_lavoro", "edd_lavoro.pdf"),
    ("p040_baseline_materiali_tributario", "materiali_diritto_tributario.pdf"),
    (
        "p040_baseline_materiali_privato_con_toc",
        "materiali_diritto_privato_con_toc.pdf",
    ),
)


def _score_all_plugins(fixture: Path) -> dict[str, float]:
    """Build ProfilingSignals from the fixture and score against every plugin."""
    signals = _build_signals_from_fixture(fixture)
    return {cls.__name__: cls.matches(signals) for cls in _PLUGIN_CLASSES}


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

    for snapshot_name, fixture_filename in _BASELINES:
        fixture = FIXTURES_DIR / fixture_filename
        if not fixture.exists():
            skipped.append(f"{snapshot_name} (fixture missing: {fixture_filename})")
            continue
        print(f"--- {snapshot_name} ({fixture_filename}) ---", flush=True)
        scores = _score_all_plugins(fixture)
        summary = snapshot_utils.matches_score_summary(scores)
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
