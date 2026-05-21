"""Capture or check body+note splitter snapshot baselines for P-018.

P-018 is the body+note glued splitter framework documented in
CLAUDE.md as pattern ``(www)``. Five plugin implementations cover
the same logical pattern of "decompose a host Node into one or more
synthetic Node siblings driven by an editorial-pipeline-specific
trigger" but diverge across four orthogonal axes (trigger predicate,
host strategy, mint category, mint scope):

- ``manuale_giappichelli`` (Mandrioli) — typographic size signature
  trigger (``SimonciniGaramondStd 10.98pt`` body + ≥30 % NOTE-sized
  spans), single-block scope, NOTE mint, ~350 LOC.
- ``manuale_bic`` (Marrone) — line-level red marker trigger
  (``Verdana,Bold 12pt color #ff0000`` exact match), multi-block
  scope plus a continuation-rescue layer, NOTE mint, ~425 LOC.
- ``dejure_nota_sentenza`` (NS) — text-marker regex on the
  concatenated notes section text (lookahead on the ``(N) ``
  literal sequence), NOTE mint, ~40 LOC.
- ``dejure_dottrina`` (DT) — extended text-marker regex with
  lookahead on ``(N) ``, ``(*) `` and ``(*) `` (em-space) with
  NOTE / EDITORIAL_NOTE dispatch, ~66 LOC.
- ``giuffre_codici`` (codici) — signal-agnostic typographic + regex
  trigger (PalatinoLinotype-Bold ≥ 8.5 pt + article-number pattern),
  walk every Node carrying ``block_indices``, mint
  ``(ARTICLE_HEADER, ARTICLE_BODY)`` pair per non-leading trigger,
  ~178 LOC.

The Fase 4 diagnostic concluded that a unifying factory would
require ≥4 callable parameters where 90 % of the body would be
plugin-specific — promotion is over-engineering and was rejected.
The mitigation introduced by this script is **regression protection
only**: per-fixture digests of every synthetic-Node mint event so
any future session that touches mint order, host truncation, page
allocation or text length surfaces as a digest divergence — even
when ``category_counts`` and ``n_transformations`` are numerically
unchanged. The digest combines Transformation ``split_into`` (the
canonical mint trail for Mandrioli, BIC, NS, DT) with the
warning-based mint trail (the codici intra-block splitter records
mints via warnings rather than Transformations — a documented gap
that the digest covers without retrofit).

Fixtures chosen to maximise coverage of the three structural
variants (span-level size-band, span-level line-marker,
text-level multi-sibling, signal-agnostic universal walk):

- ``mandrioli_vol_i`` — Photoshop pipeline (NOTE 7.98 pt regime),
  Vol. I has clean block boundaries and minimal body+note gluing.
- ``mandrioli_vol_iii`` — InDesign pipeline (NOTE 9.0 pt regime),
  ~95 % of blocks are glued — the highest-stress fixture for the
  body+note glued splitter.
- ``marrone`` — BIC accessibility pipeline, multi-block glued
  scenarios plus the cross-page continuation rescuer.
- ``codici_penale`` — high-impact fixture for the codici
  intra-block splitter (5815 ARTICLE_HEADER post-consolidation).
- ``codici_civile`` — peak-density fixture for intra-block split
  (~45 % of header-bearing blocks fuse 2-7 articles).

Usage::

    python pipeline/scripts/capture_p018_baseline.py --mode write
    python pipeline/scripts/capture_p018_baseline.py --mode check
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
    """Run the full Layer 1 pipeline and return a body+note splitter summary."""
    profile = _make_profile(plugin)
    extraction = extract(fixture)
    classified = classify(extraction, profile, plugin)
    document = reconstruct(extraction, classified, profile, plugin)
    document = resolve_apparatus(document, extraction, classified, plugin)
    document = apply_post_processing(document, extraction, classified, plugin)
    convert_document(document, extraction, profile, fixture)
    return snapshot_utils.body_note_splitter_summary(document)


_BASELINES: list[tuple[str, Callable[[], ProfilePlugin], str]] = [
    (
        "p018_baseline_mandrioli_vol_i",
        ManualeGiappichelliProfile,
        "mandrioli_carratta_vol_i.pdf",
    ),
    (
        "p018_baseline_mandrioli_vol_iii",
        ManualeGiappichelliProfile,
        "mandrioli_carratta_vol_iii.pdf",
    ),
    ("p018_baseline_marrone", ManualeBicProfile, "marrone_istituzioni.pdf"),
    (
        "p018_baseline_codici_penale",
        GiuffreCodiciProfile,
        "giuffre_codice_penale.pdf",
    ),
    (
        "p018_baseline_codici_civile",
        GiuffreCodiciProfile,
        "giuffre_codice_civile.pdf",
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
