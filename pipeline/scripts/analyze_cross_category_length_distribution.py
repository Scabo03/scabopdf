"""One-off empirical analysis of Node text-length distribution per semantic category.

Generalises ``analyze_note_length_distribution.py`` to **every** semantic
category emitted by Layer 1. Runs the full Layer 1 pipeline on every
private fixture associated with a corpus plugin, walks every Node in the
emitted Document, and aggregates ``len(node.text or "")`` grouped by
``node.category``.

The output is meant to inform the scope decision about extending the
``length_category`` schema field (currently NOTE-only) to other text-rich
categories such as BODY, ARTICLE_BODY, MARGINAL_GLOSS, EXAMPLE_BOX,
CHAPTER_SUMMARY. The script is not part of the production code and is
not exercised by any test.
"""

from __future__ import annotations

import statistics
import sys
import time
from collections import defaultdict
from collections.abc import Iterator
from pathlib import Path

from scabopdf_pipeline.apparatus import resolve_apparatus
from scabopdf_pipeline.classification import classify
from scabopdf_pipeline.emission import convert_document
from scabopdf_pipeline.extraction import extract
from scabopdf_pipeline.postprocessing import apply_post_processing
from scabopdf_pipeline.profiles.compendio_utet import CompendioUtetProfile
from scabopdf_pipeline.profiles.dejure_dottrina import DejureDottrinaProfile
from scabopdf_pipeline.profiles.dejure_massime import DejureMassimeProfile
from scabopdf_pipeline.profiles.dejure_nota_sentenza import DejureNotaSentenzaProfile
from scabopdf_pipeline.profiles.enciclopedia_moderna import EnciclopediaModernaProfile
from scabopdf_pipeline.profiles.enciclopedia_storica import EnciclopediaStoricaProfile
from scabopdf_pipeline.profiles.giuffre_codici import GiuffreCodiciProfile
from scabopdf_pipeline.profiles.manuale_bic import ManualeBicProfile
from scabopdf_pipeline.profiles.manuale_giappichelli import ManualeGiappichelliProfile
from scabopdf_pipeline.profiles.manuale_giuffre_diretto import (
    ManualeGiuffreDirectoProfile,
)
from scabopdf_pipeline.profiles.manuale_utet_wolterskluwer import (
    ManualeUtetWolterskluwerProfile,
)
from scabopdf_pipeline.profiles.manuale_zanichelli_giuridica import (
    ManualeZanichelliGiuridicaProfile,
)
from scabopdf_pipeline.profiles.materiali_studio import MaterialiStudioProfile
from scabopdf_pipeline.profiling.plugin import ProfilePlugin
from scabopdf_pipeline.profiling.profile import DocumentProfile
from scabopdf_pipeline.reconstruction import Node, reconstruct

FIXTURES_DIR = (
    Path(__file__).resolve().parents[1] / "tests" / "fixtures" / "private"
)


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


def _iter_nodes(node: Node) -> Iterator[Node]:
    yield node
    for child in node.children:
        yield from _iter_nodes(child)


# Buckets per user specification:
# <50, 50-99, 100-499, 500-999, 1000-2999, 3000-9999, >=10000
_BUCKETS: list[tuple[str, int, int]] = [
    ("<50", 0, 49),
    ("50-99", 50, 99),
    ("100-499", 100, 499),
    ("500-999", 500, 999),
    ("1000-2999", 1000, 2999),
    ("3000-9999", 3000, 9999),
    (">=10000", 10000, 10**12),
]


def _classify_buckets(lengths: list[int]) -> dict[str, int]:
    counts = {label: 0 for label, _, _ in _BUCKETS}
    for ln in lengths:
        for label, lo, hi in _BUCKETS:
            if lo <= ln <= hi:
                counts[label] += 1
                break
    return counts


def _quartiles(lengths: list[int]) -> tuple[int, int, int]:
    if not lengths:
        return (0, 0, 0)
    s = sorted(lengths)
    n = len(s)
    return (
        s[max(0, n // 4 - 1)],
        s[max(0, n // 2 - 1)],
        s[max(0, (3 * n) // 4 - 1)],
    )


def _format_aggregate_row(label: str, lengths: list[int]) -> str:
    n = len(lengths)
    if n == 0:
        return f"{label:<28}  n=0"
    mn, mx = min(lengths), max(lengths)
    mean = round(statistics.mean(lengths))
    median = round(statistics.median(lengths))
    q1, _q2, q3 = _quartiles(lengths)
    bucket_counts = _classify_buckets(lengths)
    parts = [
        f"{label:<28}",
        f"n={n:>6}",
        f"min={mn:>5}",
        f"q1={q1:>6}",
        f"med={median:>6}",
        f"q3={q3:>6}",
        f"max={mx:>7}",
        f"mean={mean:>6}",
    ]
    pct_parts = []
    for blabel, _, _ in _BUCKETS:
        pct = 100.0 * bucket_counts[blabel] / n
        pct_parts.append(f"{blabel}:{pct:.0f}%")
    return "  ".join(parts) + "  [" + " ".join(pct_parts) + "]"


def _collect_lengths_by_category(
    fixture: Path,
    plugin: ProfilePlugin,
) -> tuple[dict[str, list[int]], int]:
    """Run the full Layer 1 pipeline and return (per-category lengths, page count)."""
    profile = _make_profile(plugin)
    extraction = extract(fixture)
    classified = classify(extraction, profile, plugin)
    document = reconstruct(extraction, classified, profile, plugin)
    document = resolve_apparatus(document, extraction, classified, plugin)
    document = apply_post_processing(document, extraction, classified, plugin)
    convert_document(document, extraction, profile, fixture)

    by_category: dict[str, list[int]] = defaultdict(list)
    for root in document.root:
        for n in _iter_nodes(root):
            cat = n.category.value if n.category is not None else "<NONE>"
            text = n.text or ""
            by_category[cat].append(len(text))
    return by_category, extraction.page_count


def _run_one(
    label: str,
    fixture: Path,
    plugin: ProfilePlugin,
) -> tuple[dict[str, list[int]], int]:
    print(f"--> running {label}  ({fixture.name}, ", end="", flush=True)
    t0 = time.monotonic()
    try:
        by_cat, pages = _collect_lengths_by_category(fixture, plugin)
    except Exception as exc:  # noqa: BLE001
        print(f"FAILED after {time.monotonic() - t0:.1f}s: {exc}")
        return {}, 0
    total_nodes = sum(len(v) for v in by_cat.values())
    print(
        f"{pages}pp, {total_nodes} nodes, "
        f"{len(by_cat)} categories, "
        f"{time.monotonic() - t0:.1f}s)"
    )
    return by_cat, pages


# Same shape as the NOTE-only script PLAN, extended with the four plugins
# that the NOTE-only script omitted because they emit few or no notes
# (Zanichelli/Patriarca, UTET/Tesauro, DeJure Massime, Materiali Studio):
# they matter here because the scope decision is about BODY / ARTICLE_BODY
# / MARGINAL_GLOSS / EXAMPLE_BOX / CHAPTER_SUMMARY which they emit in
# production.
PLAN: list[tuple[str, str, type[ProfilePlugin]]] = [
    # (label, fixture filename, plugin class)
    ("patriarca (zanichelli)", "patriarca_benazzo.pdf", ManualeZanichelliGiuridicaProfile),
    ("tesauro (compendio UTET)", "tesauro_compendio.pdf", CompendioUtetProfile),
    ("mosconi (UTET-WK)", "mosconi_campiglio.pdf", ManualeUtetWolterskluwerProfile),
    ("mandrioli vol I (giappichelli)", "mandrioli_carratta_vol_i.pdf", ManualeGiappichelliProfile),
    ("mandrioli vol II (giappichelli)", "mandrioli_carratta_vol_ii.pdf", ManualeGiappichelliProfile),
    ("mandrioli vol III (giappichelli)", "mandrioli_carratta_vol_iii.pdf", ManualeGiappichelliProfile),
    ("mandrioli vol IV (giappichelli)", "mandrioli_carratta_vol_iv.pdf", ManualeGiappichelliProfile),
    ("torrente (giuffre_diretto)", "torrente_schlesinger.pdf", ManualeGiuffreDirectoProfile),
    ("marrone (BIC)", "marrone_istituzioni.pdf", ManualeBicProfile),
    ("NS recisione", "dejure_ns_recisione_nesso_causale.pdf", DejureNotaSentenzaProfile),
    ("NS giudizio universale", "dejure_ns_giudizio_universale.pdf", DejureNotaSentenzaProfile),
    ("NS stella raccolta", "dejure_ns_stella_raccolta.pdf", DejureNotaSentenzaProfile),
    ("MM procedura civile", "dejure_mm_procedura_civile.pdf", DejureMassimeProfile),
    ("MM concause naturali", "dejure_mm_concause_naturali.pdf", DejureMassimeProfile),
    ("MM responsabilita civile", "dejure_mm_responsabilita_civile_massivo.pdf", DejureMassimeProfile),
    ("DT bundle procedura", "dejure_dt_bundle_procedura_civile.pdf", DejureDottrinaProfile),
    ("DT concause causalita", "dejure_dt_concause_causalita.pdf", DejureDottrinaProfile),
    ("DT cartabia", "dejure_dt_riforma_cartabia.pdf", DejureDottrinaProfile),
    ("EM abuso pos. dominante", "edd_abuso_posizione_dominante.pdf", EnciclopediaModernaProfile),
    ("EM factoring", "edd_factoring.pdf", EnciclopediaModernaProfile),
    ("EM giudizio legittimita", "edd_giudizio_legittimita_costituzionale.pdf", EnciclopediaModernaProfile),
    ("ES eccesso potere", "edd_eccesso_potere.pdf", EnciclopediaStoricaProfile),
    ("ES lavoro", "edd_lavoro.pdf", EnciclopediaStoricaProfile),
    ("ES pagamento", "edd_pagamento.pdf", EnciclopediaStoricaProfile),
    ("ES azienda", "edd_azienda.pdf", EnciclopediaStoricaProfile),
    ("giuffre codice civile", "giuffre_codice_civile.pdf", GiuffreCodiciProfile),
    ("giuffre codice penale", "giuffre_codice_penale.pdf", GiuffreCodiciProfile),
    ("materiali teoria generale", "materiali_teoria_generale.pdf", MaterialiStudioProfile),
    ("materiali diritto tributario", "materiali_diritto_tributario.pdf", MaterialiStudioProfile),
    ("materiali diritto privato I", "materiali_diritto_privato_i.pdf", MaterialiStudioProfile),
    ("materiali diritto privato II", "materiali_diritto_privato_ii.pdf", MaterialiStudioProfile),
]


# Categories of explicit interest for the scope decision (always shown in
# the per-plugin breakdown when present). NOTE included as reference.
_INTEREST_CATEGORIES: list[str] = [
    "BODY",
    "ARTICLE_BODY",
    "MARGINAL_GLOSS",
    "EXAMPLE_BOX",
    "CHAPTER_SUMMARY",
    "NOTE",
    "EDITORIAL_NOTE",
]

# Cut-off below which a category is omitted from the global aggregate
# table for readability. Categories with very few nodes carry no
# statistical signal.
_GLOBAL_MIN_NODES = 50

# Cut-off above which a non-interest category is also added to the
# per-plugin breakdown for visibility into long-tailed apparatus
# categories (HEADING_*, TOC_GENERAL, FONTI, LETTERATURA, etc.).
_PER_PLUGIN_EXTRA_MIN_NODES = 100


def main() -> int:
    print("=" * 110)
    print(
        "Cross-category Node text-length empirical distribution — every fixture, every category"
    )
    print(
        "Length = len(node.text or '')  (no marker stripping; raw text as emitted)"
    )
    print("=" * 110)
    print()

    # global[category] = list[int]
    global_by_cat: dict[str, list[int]] = defaultdict(list)
    # per_plugin[plugin_label][category] = list[int]
    per_plugin: dict[str, dict[str, list[int]]] = defaultdict(
        lambda: defaultdict(list)
    )

    t_start = time.monotonic()
    for label, fname, plugin_cls in PLAN:
        fixture = FIXTURES_DIR / fname
        if not fixture.exists():
            print(f"--> SKIP {label} (fixture missing: {fname})")
            continue
        by_cat, _pages = _run_one(label, fixture, plugin_cls())
        plugin_label = plugin_cls.__name__.replace("Profile", "")
        for cat, lengths in by_cat.items():
            global_by_cat[cat].extend(lengths)
            per_plugin[plugin_label][cat].extend(lengths)
    print(f"\nTotal pipeline runtime: {time.monotonic() - t_start:.1f}s\n")

    # ------------------------------------------------------------------
    # GLOBAL PER-CATEGORY TABLE
    # ------------------------------------------------------------------
    print("=" * 110)
    print(
        "GLOBAL CROSS-CORPUS PER-CATEGORY DISTRIBUTION  "
        "(only categories with >= "
        f"{_GLOBAL_MIN_NODES} nodes)"
    )
    print(
        "Buckets: <50 | 50-99 | 100-499 | 500-999 | 1000-2999 | 3000-9999 | >=10000"
    )
    print("=" * 110)
    sorted_global = sorted(
        global_by_cat.items(), key=lambda kv: len(kv[1]), reverse=True
    )
    for cat, lengths in sorted_global:
        if len(lengths) < _GLOBAL_MIN_NODES:
            continue
        print(_format_aggregate_row(cat, lengths))
    print()
    print("Categories below the threshold (skipped above):")
    skipped = [
        (cat, len(lengths))
        for cat, lengths in sorted_global
        if len(lengths) < _GLOBAL_MIN_NODES
    ]
    for cat, n in skipped:
        print(f"  {cat:<28}  n={n}")
    print()

    # ------------------------------------------------------------------
    # PER-PLUGIN BREAKDOWN FOR CATEGORIES OF INTEREST
    # ------------------------------------------------------------------
    # Build the set of categories that appear in the per-plugin section:
    # always the explicit interest list, plus any other category with
    # >= _PER_PLUGIN_EXTRA_MIN_NODES globally.
    extra_categories = sorted(
        {
            cat
            for cat, lengths in global_by_cat.items()
            if len(lengths) >= _PER_PLUGIN_EXTRA_MIN_NODES
            and cat not in _INTEREST_CATEGORIES
        }
    )
    show_categories = list(_INTEREST_CATEGORIES) + extra_categories

    print("=" * 110)
    print(
        "PER-PLUGIN BREAKDOWN — categories of interest + every category with >= "
        f"{_PER_PLUGIN_EXTRA_MIN_NODES} global nodes"
    )
    print("=" * 110)
    for plugin_label in sorted(per_plugin.keys()):
        print()
        print(f"--- {plugin_label} ---")
        plugin_cats = per_plugin[plugin_label]
        for cat in show_categories:
            lengths = plugin_cats.get(cat, [])
            if not lengths:
                continue
            print("  " + _format_aggregate_row(cat, lengths))

    # ------------------------------------------------------------------
    # FOCUSED SUMMARY ON CATEGORIES OF INTEREST
    # ------------------------------------------------------------------
    print()
    print("=" * 110)
    print(
        "FOCUSED SUMMARY — categories of interest for the scope decision"
    )
    print("=" * 110)
    for cat in _INTEREST_CATEGORIES:
        lengths = global_by_cat.get(cat, [])
        if not lengths:
            print(f"{cat:<28}  n=0  (not emitted by any plugin)")
            continue
        print(_format_aggregate_row(cat, lengths))

    return 0


if __name__ == "__main__":
    sys.exit(main())
