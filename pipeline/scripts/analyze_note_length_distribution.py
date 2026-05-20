"""One-off empirical analysis of NOTE Node text-length distribution cross-corpus.

Runs the full Layer 1 pipeline on every private fixture associated with a
plugin that emits NOTE Nodes, collects ``len(node.text)`` for every NOTE
(after stripping the leading ``(N)`` marker), and prints a per-fixture
distribution plus a cross-corpus aggregated table.

Output is plain text, written to stdout. The script is meant to inform
the Layout 4 acoustic-regime threshold decision (Task 1 of the
2026-05-20 session); it is not part of the production code and is not
exercised by any test.
"""

from __future__ import annotations

import re
import statistics
import sys
import time
from collections.abc import Iterable, Iterator
from pathlib import Path

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
from scabopdf_pipeline.reconstruction import Node, reconstruct
from scabopdf_pipeline.schema.categories import SemanticCategory

FIXTURES_DIR = (
    Path(__file__).resolve().parents[1] / "tests" / "fixtures" / "private"
)

# Strip leading "(N) " or "(N)" or "N) " marker if present, so the
# measured length reflects the textual body of the note, not the
# typographic marker the editorial pipeline glued on.
_MARKER_RE = re.compile(r"^\s*\(?\d+\)\s*")


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


_BUCKETS: list[tuple[str, int, int]] = [
    ("<50", 0, 49),
    ("50-99", 50, 99),
    ("100-199", 100, 199),
    ("200-499", 200, 499),
    ("500-999", 500, 999),
    ("1000-1499", 1000, 1499),
    ("1500-2999", 1500, 2999),
    ("3000-4999", 3000, 4999),
    (">=5000", 5000, 10**9),
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


def _format_row(
    label: str,
    n: int,
    lengths: list[int],
) -> tuple[str, dict[str, int]]:
    bucket_counts = _classify_buckets(lengths)
    if not lengths:
        return (
            f"{label:<48}  n=0   (no NOTE Nodes emitted)",
            bucket_counts,
        )
    mn, mx = min(lengths), max(lengths)
    mean = round(statistics.mean(lengths))
    median = round(statistics.median(lengths))
    q1, q2, q3 = _quartiles(lengths)
    parts = [
        f"{label:<48}",
        f"n={n:>5}",
        f"min={mn:>4}",
        f"q1={q1:>5}",
        f"med={median:>5}",
        f"q3={q3:>5}",
        f"max={mx:>6}",
        f"mean={mean:>5}",
    ]
    pct_parts = []
    for blabel, _, _ in _BUCKETS:
        pct = 100.0 * bucket_counts[blabel] / n
        pct_parts.append(f"{blabel}:{pct:.0f}%")
    return "  ".join(parts) + "  [" + " ".join(pct_parts) + "]", bucket_counts


def _collect_note_lengths(
    fixture: Path,
    plugin: ProfilePlugin,
) -> tuple[list[int], int, list[str]]:
    """Run the full Layer 1 pipeline and return (note_lengths, page_count, samples).

    ``note_lengths`` is the list of ``len(stripped_text)`` for every NOTE
    Node in the emitted Document; ``samples`` is a list of up to 3 short
    text samples (truncated to 80 chars) for quick eyeballing.
    """
    profile = _make_profile(plugin)
    extraction = extract(fixture)
    classified = classify(extraction, profile, plugin)
    document = reconstruct(extraction, classified, profile, plugin)
    document = resolve_apparatus(document, extraction, classified, plugin)
    document = apply_post_processing(document, extraction, classified, plugin)
    # Touch convert_document to make sure the emitted shape is consistent
    # with what production sees (no-op for our needs, but a sanity-check).
    convert_document(document, extraction, profile, fixture)

    all_nodes = [n for root in document.root for n in _iter_nodes(root)]
    note_nodes = [n for n in all_nodes if n.category is SemanticCategory.NOTE]
    lengths: list[int] = []
    samples: list[str] = []
    for n in note_nodes:
        text = n.text or ""
        stripped = _MARKER_RE.sub("", text)
        lengths.append(len(stripped))
        if len(samples) < 3:
            samples.append(stripped[:80].replace("\n", " "))
    return lengths, extraction.page_count, samples


def _run_one(
    label: str,
    fixture: Path,
    plugin: ProfilePlugin,
) -> tuple[list[int], int, list[str]]:
    print(f"--> running {label}  ({fixture.name}, ", end="", flush=True)
    t0 = time.monotonic()
    try:
        lengths, pages, samples = _collect_note_lengths(fixture, plugin)
    except Exception as exc:  # noqa: BLE001
        print(f"FAILED after {time.monotonic() - t0:.1f}s: {exc}")
        return [], 0, []
    print(f"{pages}pp, {len(lengths)} NOTE, {time.monotonic() - t0:.1f}s)")
    return lengths, pages, samples


PLAN: list[tuple[str, str, type[ProfilePlugin]]] = [
    # (label, fixture filename, plugin class)
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
]


def main() -> int:
    print("=" * 100)
    print("NOTE Node text-length empirical distribution — cross-corpus panoramica")
    print("Stripping leading marker via regex r'^\\s*\\(?\\d+\\)\\s*'")
    print("=" * 100)
    print()

    per_fixture_lengths: dict[str, list[int]] = {}
    per_plugin_lengths: dict[str, list[int]] = {}
    samples_log: dict[str, list[str]] = {}

    t_start = time.monotonic()
    for label, fname, plugin_cls in PLAN:
        fixture = FIXTURES_DIR / fname
        if not fixture.exists():
            print(f"--> SKIP {label} (fixture missing: {fname})")
            continue
        lengths, _pages, samples = _run_one(label, fixture, plugin_cls())
        per_fixture_lengths[label] = lengths
        plugin_label = plugin_cls.__name__.replace("Profile", "")
        per_plugin_lengths.setdefault(plugin_label, []).extend(lengths)
        samples_log[label] = samples
    print(f"\nTotal pipeline runtime: {time.monotonic() - t_start:.1f}s\n")

    print("=" * 100)
    print("PER-FIXTURE DISTRIBUTION (fasce: <50, 50-99, 100-199, 200-499, 500-999, 1000-1499, 1500-2999, 3000-4999, >=5000)")
    print("=" * 100)
    for label, lengths in per_fixture_lengths.items():
        row, _ = _format_row(label, len(lengths), lengths)
        print(row)

    print()
    print("=" * 100)
    print("PER-PLUGIN AGGREGATE DISTRIBUTION")
    print("=" * 100)
    for plugin_label, lengths in per_plugin_lengths.items():
        row, _ = _format_row(plugin_label, len(lengths), lengths)
        print(row)

    print()
    print("=" * 100)
    print("GLOBAL CROSS-CORPUS DISTRIBUTION")
    print("=" * 100)
    all_lengths: list[int] = []
    for lengths in per_fixture_lengths.values():
        all_lengths.extend(lengths)
    row, global_buckets = _format_row("TOTAL", len(all_lengths), all_lengths)
    print(row)
    print()
    print("Global bucket counts (absolute):")
    for blabel, _, _ in _BUCKETS:
        cnt = global_buckets[blabel]
        pct = 100.0 * cnt / max(1, len(all_lengths))
        print(f"  {blabel:>12}  {cnt:>7}  ({pct:>5.1f}%)")

    print()
    print("Long-tail breakdown (> 1500 chars total):")
    long_lengths = [ln for ln in all_lengths if ln >= 1500]
    print(f"  count_>=1500: {len(long_lengths)}  ({100.0*len(long_lengths)/max(1,len(all_lengths)):.1f}% of global)")
    if long_lengths:
        q1, q2, q3 = _quartiles(long_lengths)
        print(
            f"  min={min(long_lengths)}  q1={q1}  median={q2}  q3={q3}  max={max(long_lengths)}"
        )

    print()
    print("Mega-tail (> 5000 chars):")
    mega = [ln for ln in all_lengths if ln >= 5000]
    print(f"  count_>=5000: {len(mega)}  ({100.0*len(mega)/max(1,len(all_lengths)):.1f}% of global)")
    if mega:
        q1, q2, q3 = _quartiles(mega)
        print(
            f"  min={min(mega)}  q1={q1}  median={q2}  q3={q3}  max={max(mega)}"
        )

    print()
    print("=" * 100)
    print("Per-fixture textual samples (first 3 NOTE, truncated to 80 chars)")
    print("=" * 100)
    for label, samples in samples_log.items():
        if not samples:
            continue
        print(f"  {label}:")
        for i, s in enumerate(samples, 1):
            print(f"    [{i}] {s!r}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
