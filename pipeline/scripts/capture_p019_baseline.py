"""Capture or check cross-reference minting snapshot baselines for P-019.

P-019 is the cross-reference minting framework documented in CLAUDE.md
as pattern ``(xxx)``. Nine plugin implementations cover the same
logical pattern of "mint one or more synthetic ``CROSS_REFERENCE`` Node
siblings from inline markers detected in the host" but diverge across
six orthogonal axes (input shape, pattern count, multi-subtype
tracking, scope boundary, conditional dispatch, geometric guards):

Family A — span-level / typographic
-----------------------------------

- ``manuale_utet_wolterskluwer`` (Mosconi) — single typographic
  superscript predicate (``TimesTenLTStd-Roman`` + ``size in {5.2, 5.8}pt``
  + ``span.is_superscript``), 1 subtype, scope per-chapter via tier 1
  resolver, ~34 LOC.
- ``manuale_bic`` (Marrone) — single typographic superscript predicate
  (``Verdana,Bold`` + ``size 10.56pt`` + ``is_superscript`` + back-matter
  filter on ``Bibliografia`` / ``Indice analitico``), 1 subtype, scope
  per-chapter override forward, ~111 LOC plus ~117 LOC of binding
  override.

Family B1 — textual single-pattern
----------------------------------

- ``manuale_giappichelli`` (Mandrioli) — single textual regex
  ``(?<!p\\.\\s)(?<!p\\.)\\((\\d+)\\)`` with negative lookaround
  excluding ``p. NN`` page references, 1 subtype, scope per-chapter
  via tier 1 resolver, ~39 LOC.
- ``dejure_nota_sentenza`` (NS) — single textual regex
  ``INLINE_PARENTHESISED_CROSSREF_REGEX`` shared via
  ``apparatus.constants``, max marker value 99, scope per-document,
  ~25 LOC.
- ``dejure_dottrina`` (DT) — byte-equivalent to NS modulo
  ``max_marker_value=500`` and per-article scope via
  ``_compute_article_boundaries``, ~25 LOC. NS/DT are the pair
  unified by pattern ``(xxx)`` of CLAUDE.md.

Family B2 — textual two-patterns
--------------------------------

- ``enciclopedia_moderna`` (EM) — two textual regexes ``\\(\\d+\\)``
  numeric and ``v\\.\\s+NOMEVOCE``, two subtypes encoded in the
  warning template (``cross_reference_note_minted`` /
  ``cross_reference_voce_minted``), scope per-document, ~64 LOC.
- ``enciclopedia_storica`` (ES) — byte-equivalent to EM modulo
  OCR-noise tolerance in the surrounding predicates, ~55 LOC.
- ``giuffre_codici`` (codici) — two patterns dispatched on the
  instance flag ``_code_type ∈ {PENALE, CIVILE}``: simple ``[N]`` for
  PENALE, elaborated ``[N c.c.]`` / ``[N Cost.]`` / ``[N ss.]`` for
  CIVILE, single subtype warning template (``cross_reference_minted``),
  scope per-document on ``ARTICLE_BODY`` only, ~76 LOC.

Family B3 — textual three-patterns global
-----------------------------------------

- ``manuale_giuffre_diretto`` (Torrente) — three textual regexes
  ``§ N``, ``art. N c.c.`` and ``Cass. <date> n. <n>`` with
  marker normalisation (``130-bis``/``130 bis``/``130bis`` → ``130-bis``),
  three subtypes encoded by leading-char (``§``/``art.``/``Cass.``) and
  by warning template suffix, scope global-document with marker index
  built in ``refine_apparatus``, ~65 LOC plus ~70 LOC of binding override.

The Fase 5 diagnostic concluded that a unifying factory would require
≥6 callable parameters where 90 % of the body would be plugin-specific
— promotion is over-engineering and was rejected for seven of the
nine implementations. The exception is the NS+DT pair (byte-equivalent
modulo two scalar constants) promoted to ``_dejure_shared`` in the
follow-up commit (pattern ``(xxx)``). The mitigation introduced by
this script is regression protection only: per-fixture digests of
every cross-reference mint event so any future session that touches
mint order, host allocation, marker text, subtype distribution or
binding scope surfaces as a digest divergence — even when
``category_counts`` and ``n_warnings`` are numerically unchanged.

Fixtures chosen to maximise coverage of the four structural families
listed above:

- ``mosconi`` — Mosconi-Campiglio (Family A span-level superscript,
  per-chapter via tier 1).
- ``mandrioli_vol_iii`` — Mandrioli Vol. III (Family B1 textual
  regex, negative lookaround, per-chapter via tier 1).
- ``marrone`` — BIC Marrone (Family A span-level superscript +
  back-matter filter + per-chapter override forward).
- ``torrente`` — Torrente-Schlesinger (Family B3 three-subtype
  global scope with marker normalisation).
- ``dejure_ns_recisione`` — NS Recisione (Family B1 shared regex via
  ``apparatus.constants``; the short narrative archetype carries
  zero inline ``(N)`` markers, so this baseline pins the
  ``empty-mint-trail`` code path: every byte-equivalent refactor
  must preserve the empty digest).
- ``dejure_ns_giudizio`` — NS Giudizio Universale (Family B1 shared
  regex; the long academic archetype carries 53 inline ``(N)``
  markers, pinning the ``many-mints`` code path that the empty-fixture
  cannot exercise).
- ``dejure_dt_cartabia`` — DT Cartabia (Family B1 shared regex,
  per-article scope, the largest DT bundle 7 articles 184 pp).
- ``edd_moderna_factoring`` — EM Factoring (Family B2 two-subtype
  ``(N)`` + ``v. NOMEVOCE``).
- ``edd_storica_lavoro`` — ES Lavoro (Family B2 byte-equivalent to
  EM under OCR-tolerant predicates).
- ``codici_penale`` — Codici Penale (Family B2 dual-mode
  ``_code_type`` dispatch on simple ``[N]`` form).

Usage::

    python pipeline/scripts/capture_p019_baseline.py --mode write
    python pipeline/scripts/capture_p019_baseline.py --mode check
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
from scabopdf_pipeline.profiles.manuale_giuffre_diretto import ManualeGiuffreDirectoProfile
from scabopdf_pipeline.profiles.manuale_utet_wolterskluwer import (
    ManualeUtetWolterskluwerProfile,
)
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
    """Run the full Layer 1 pipeline and return a CR minting summary."""
    profile = _make_profile(plugin)
    extraction = extract(fixture)
    classified = classify(extraction, profile, plugin)
    document = reconstruct(extraction, classified, profile, plugin)
    document = resolve_apparatus(document, extraction, classified, plugin)
    document = apply_post_processing(document, extraction, classified, plugin)
    convert_document(document, extraction, profile, fixture)
    return snapshot_utils.cross_ref_minting_summary(document)


_BASELINES: list[tuple[str, Callable[[], ProfilePlugin], str]] = [
    (
        "p019_baseline_mosconi",
        ManualeUtetWolterskluwerProfile,
        "mosconi_campiglio.pdf",
    ),
    (
        "p019_baseline_mandrioli_vol_iii",
        ManualeGiappichelliProfile,
        "mandrioli_carratta_vol_iii.pdf",
    ),
    ("p019_baseline_marrone", ManualeBicProfile, "marrone_istituzioni.pdf"),
    (
        "p019_baseline_torrente",
        ManualeGiuffreDirectoProfile,
        "torrente_schlesinger.pdf",
    ),
    (
        "p019_baseline_dejure_ns_recisione",
        DejureNotaSentenzaProfile,
        "dejure_ns_recisione_nesso_causale.pdf",
    ),
    (
        "p019_baseline_dejure_ns_giudizio",
        DejureNotaSentenzaProfile,
        "dejure_ns_giudizio_universale.pdf",
    ),
    (
        "p019_baseline_dejure_dt_cartabia",
        DejureDottrinaProfile,
        "dejure_dt_riforma_cartabia.pdf",
    ),
    (
        "p019_baseline_edd_moderna_factoring",
        EnciclopediaModernaProfile,
        "edd_factoring.pdf",
    ),
    (
        "p019_baseline_edd_storica_lavoro",
        EnciclopediaStoricaProfile,
        "edd_lavoro.pdf",
    ),
    (
        "p019_baseline_codici_penale",
        GiuffreCodiciProfile,
        "giuffre_codice_penale.pdf",
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
