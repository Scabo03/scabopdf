"""Diagnostic-only scan of OCR-corruption patterns in article / paragraph /
section numbers across the four ``enciclopedia_storica`` private fixtures.

Goal.
-----

The current OCR normalisation pipeline (commit ``1fcfefa``) handles
running-prose word corruption via per-character substitutions plus a
small closed dictionary of structural-marker fossilisations
(``LETTERATURA`` variants). It does **not** today touch the *number*
domain — section numerals, paragraph numbers, article numbers, year
fragments — even though the Adobe Paper Capture 11.0.23 OCR pipeline
fossilises a recognisable family of these markers (``Sez. lll`` for
``Sez. III``, ``xo.`` for ``10.``, ``•·`` for paragraph bullets,
``1953·`` with trailing bullet, etc.).

This script runs the full Layer 1 pipeline on each of the four EdD
storica fixtures, walks every text-bearing Node, and scans the text
with a closed set of regex patterns inspired by the analysis. It
counts occurrences per pattern per fixture and prints up to five
example occurrences (Node id, page index, ~80-char context window) so
the operator can categorise the dominant patterns and decide whether
to extend the per-character table, the structural-marker dictionary
or to introduce a new context-sensitive substitution model.

This is diagnostic-only. The script writes nothing to disk and does
not touch production code or production data.
"""

from __future__ import annotations

import re
import sys
import time
from collections.abc import Iterator
from pathlib import Path
from typing import NamedTuple

from scabopdf_pipeline.apparatus import resolve_apparatus
from scabopdf_pipeline.classification import classify
from scabopdf_pipeline.emission import convert_document
from scabopdf_pipeline.extraction import extract
from scabopdf_pipeline.postprocessing import apply_post_processing
from scabopdf_pipeline.profiles.enciclopedia_storica import EnciclopediaStoricaProfile
from scabopdf_pipeline.profiling.plugin import ProfilePlugin
from scabopdf_pipeline.profiling.profile import DocumentProfile
from scabopdf_pipeline.reconstruction import Node, reconstruct
from scabopdf_pipeline.schema.categories import SemanticCategory

FIXTURES_DIR = (
    Path(__file__).resolve().parents[1] / "tests" / "fixtures" / "private"
)

# ---------------------------------------------------------------------------
# Categories whose ``text`` carries content we care about scanning.

_TEXT_BEARING_CATEGORIES: frozenset[SemanticCategory] = frozenset(
    {
        SemanticCategory.BODY,
        SemanticCategory.NOTE,
        SemanticCategory.TITLE,
        SemanticCategory.HEADING_1,
        SemanticCategory.HEADING_2,
        SemanticCategory.HEADING_3,
        SemanticCategory.HEADING_4,
        SemanticCategory.SECTION_LABEL,
        SemanticCategory.FONTI,
        SemanticCategory.LETTERATURA,
        SemanticCategory.TOC_GENERAL,
        SemanticCategory.SUBTITLE,
        SemanticCategory.META_VALUE,
    }
)

# ---------------------------------------------------------------------------
# Pattern catalogue. Each entry is (label, regex, description).
#
# The patterns are intentionally narrow: they look for tokens that
# are *unlikely* to be legitimate Italian text and are *likely* to be
# OCR fossils of structural numbers.

PATTERNS: list[tuple[str, re.Pattern[str], str]] = [
    # 1. ``Sez.`` + corrupted roman: lowercase L's or mixed l/I tokens
    #    immediately after the canonical "Sez." marker.
    (
        "sez_lowercase_l",
        re.compile(r"\bSez\.\s+[lI]{1,4}\b"),
        "Sez. <token> where token is 1-4 chars of [lI] (e.g. 'Sez. lll', 'Sez. lI', 'Sez. lII')",
    ),
    # 2. Cap. with lowercase-l corruption.
    (
        "cap_lowercase_l",
        re.compile(r"\bCap\.\s+[lI]{1,4}\b"),
        "Cap. <token> where token is 1-4 chars of [lI]",
    ),
    # 3. Standalone lowercase-l roman tokens: ll, lll, llll on word
    #    boundaries (likely II, III, IIII or II, but always suspect).
    #    We exclude single 'l' alone since 'l' is a legitimate Italian
    #    article.
    (
        "standalone_ll_lll",
        re.compile(r"(?<![A-Za-z])l{2,4}(?![A-Za-z])"),
        "Standalone ll / lll / llll tokens (no surrounding letters)",
    ),
    # 4. Standalone lI / lII / Il / IlI tokens (mixed-case roman corruption).
    (
        "standalone_mixed_l_I",
        re.compile(r"(?<![A-Za-z])(?:lI|IlI?|llI|lII|XlI{1,3}|XIl|XlII|XlV|XIl{1,2}|VIl{1,2})(?![A-Za-z])"),
        "Standalone mixed-case roman tokens (lI, IlI, llI, lII, XlI, XIl, etc.)",
    ),
    # 5. ``xo`` / ``xO`` / ``XO`` standalone (likely 10 / X.0)
    (
        "standalone_xo",
        re.compile(r"(?<![A-Za-z])[xX][oO0](?![A-Za-z])"),
        "Standalone 'xo'/'XO'/'xO' tokens (likely 10)",
    ),
    # 6. ``xo.`` ``xO.`` at start of paragraph or after period (paragraph 10)
    (
        "paragraph_xo_dot",
        re.compile(r"(?:^|(?<=[\s.]))[xX][oO0]\."),
        "'xo.' opening a paragraph (likely '10.')",
    ),
    # 7. ``s.`` standalone as paragraph number (likely 5.)
    (
        "paragraph_s_dot",
        re.compile(r"(?:^|(?<=\n)|(?<=\s\s))s\.\s"),
        "'s. ' at start of paragraph (likely '5. ')",
    ),
    # 8. Bullet middle-dot ``·`` after a digit (year corruption like 1953·).
    (
        "digit_trailing_middle_dot",
        re.compile(r"\b\d{1,4}·"),
        "Digit immediately followed by middle-dot · (e.g. '1953·')",
    ),
    # 9. Leading middle-dot or bullet on a line (paragraph bullet fossil).
    (
        "leading_bullet_dot",
        re.compile(r"(?:^|\n)\s*[•·]+"),
        "Line-leading bullet/middle-dot sequences (•, ·, •·)",
    ),
    # 10. ``•·`` combined bullet+middle-dot anywhere (paragraph 4 fossil per analysis)
    (
        "bullet_middle_dot_combo",
        re.compile(r"•·"),
        "Combined '•·' glyph cluster",
    ),
    # 11. Article numbers with degree-symbol-like contamination ``4°``
    #     when surrounded by oddly broken context (e.g. ``art . 4°``).
    (
        "art_degree_contamination",
        re.compile(r"\bart\s*\.?\s*\d+\s*[°ºoO0]"),
        "art. <digits><degree-like> (e.g. 'art. 4°', 'art. 1o')",
    ),
    # 12. Roman numeral inside Sez./Cap./Par. with strict OCR-confusion
    #     character class (more permissive than #1/#2): allow stray
    #     lowercase l / I / V / X mixed in nonconventional sequences.
    (
        "section_marker_corrupt_roman",
        re.compile(r"\b(?:Sez|Cap|Par|Tit|Lib)\.\s+[lIVXivx]{1,6}\b"),
        "Sez./Cap./Par./Tit./Lib. + 1-6 chars from {l,I,V,X,i,v,x} (catches both clean and corrupted)",
    ),
    # 13. ``1n`` token NOT preceded/followed by a letter that would make
    #     it a legitimate Italian fragment (catches '1n89' year fossil).
    (
        "1n_year_fragment",
        re.compile(r"\b1n\d{2,3}\b"),
        "'1n' + digits (year fossil like '1n89', would otherwise produce m89)",
    ),
    # 14. ``s.`` followed by a single digit (possible 'sez.' OCR or '5.' opener).
    (
        "s_dot_digit",
        re.compile(r"\bs\.\s*\d"),
        "'s.' immediately followed by digit (could be malformed 'sez.' or '5.')",
    ),
    # 15. Digit followed by 'o' that is not a known Italian word
    #     (catches '5o' meaning 50, '4o' meaning 40 etc., very narrow).
    (
        "digit_o_standalone",
        re.compile(r"(?<![A-Za-z])\d+[oO](?![A-Za-z])"),
        "Standalone <digits>+o token (e.g. '5o' → 50)",
    ),
    # 16. Lowercase 'i' standalone roman one in section context.
    (
        "section_marker_lowercase_i",
        re.compile(r"\b(?:Sez|Cap|Par)\.\s+i{1,4}\.\s"),
        "Sez./Cap./Par. + 1-4 lowercase 'i's (e.g. 'Sez. i.', 'Sez. iii.')",
    ),
    # 17. Trailing bullet glyph on what looks like a date year ``\d{4}·``
    #     (specialisation of #8 for years).
    (
        "year_trailing_bullet",
        re.compile(r"\b(?:1[89]\d{2}|20\d{2})·"),
        "Year (1800-2099) immediately followed by middle-dot (e.g. '1953·')",
    ),
    # 18. ``°`` standalone or ``·°`` cluster surfacing on an isolated
    #     digit token.
    (
        "digit_degree_dot_cluster",
        re.compile(r"\b\d+[°ºo][·.,]"),
        "<digits>+degree-like + punct (e.g. '4°.', '1953°,')",
    ),
]


def _iter_nodes(node: Node) -> Iterator[Node]:
    yield node
    for child in node.children:
        yield from _iter_nodes(child)


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


class Occurrence(NamedTuple):
    node_id: str
    category: str
    page: int | None
    match_text: str
    context: str


def _context_window(text: str, start: int, end: int, span: int = 40) -> str:
    """Return ``text[start-span:end+span]`` (clipped) with newlines visualised."""
    lo = max(0, start - span)
    hi = min(len(text), end + span)
    snippet = text[lo:hi].replace("\n", "\\n").replace("\t", "\\t")
    prefix = "..." if lo > 0 else ""
    suffix = "..." if hi < len(text) else ""
    return f"{prefix}{snippet}{suffix}"


def _scan_node(
    node: Node,
    pattern_hits: dict[str, list[Occurrence]],
) -> None:
    if node.category not in _TEXT_BEARING_CATEGORIES:
        return
    text = node.text or ""
    if not text:
        return
    cat_label = (
        node.category.value if hasattr(node.category, "value") else str(node.category)
    )
    for label, regex, _desc in PATTERNS:
        for m in regex.finditer(text):
            pattern_hits[label].append(
                Occurrence(
                    node_id=node.id,
                    category=cat_label,
                    page=node.page_index,
                    match_text=m.group(0),
                    context=_context_window(text, m.start(), m.end()),
                )
            )


def _run_one(fixture: Path) -> tuple[dict[str, list[Occurrence]], int, int, float]:
    plugin = EnciclopediaStoricaProfile()
    profile = _make_profile(plugin)
    t0 = time.monotonic()
    extraction = extract(fixture)
    classified = classify(extraction, profile, plugin)
    document = reconstruct(extraction, classified, profile, plugin)
    document = resolve_apparatus(document, extraction, classified, plugin)
    document = apply_post_processing(document, extraction, classified, plugin)
    convert_document(document, extraction, profile, fixture)
    elapsed = time.monotonic() - t0
    pattern_hits: dict[str, list[Occurrence]] = {label: [] for label, _, _ in PATTERNS}
    all_nodes = [n for root in document.root for n in _iter_nodes(root)]
    text_nodes = [n for n in all_nodes if n.category in _TEXT_BEARING_CATEGORIES]
    for n in text_nodes:
        _scan_node(n, pattern_hits)
    return pattern_hits, extraction.page_count, len(text_nodes), elapsed


FIXTURES: list[tuple[str, str]] = [
    ("ES eccesso_potere", "edd_eccesso_potere.pdf"),
    ("ES lavoro", "edd_lavoro.pdf"),
    ("ES pagamento", "edd_pagamento.pdf"),
    ("ES azienda", "edd_azienda.pdf"),
]


def main() -> int:
    print("=" * 100)
    print("EdD storica — OCR article/paragraph/section NUMBER corruption diagnostic")
    print("=" * 100)
    print()
    print("Patterns scanned:")
    for label, regex, desc in PATTERNS:
        print(f"  [{label:<35}]  {regex.pattern}")
        print(f"      {desc}")
    print()

    per_fixture: dict[str, dict[str, list[Occurrence]]] = {}
    per_fixture_meta: dict[str, tuple[int, int, float]] = {}

    for label, fname in FIXTURES:
        fixture = FIXTURES_DIR / fname
        if not fixture.exists():
            print(f"--> SKIP {label} (fixture missing: {fname})")
            continue
        print(f"--> running {label} ({fname})... ", end="", flush=True)
        try:
            hits, pages, n_text_nodes, elapsed = _run_one(fixture)
        except Exception as exc:  # noqa: BLE001
            print(f"FAILED: {exc}")
            continue
        per_fixture[label] = hits
        per_fixture_meta[label] = (pages, n_text_nodes, elapsed)
        total = sum(len(v) for v in hits.values())
        print(
            f"{pages}pp, {n_text_nodes} text-bearing Nodes, {total} matches, {elapsed:.1f}s"
        )
    print()

    # Summary table: rows = patterns, columns = fixtures.
    print("=" * 100)
    print("SUMMARY TABLE (counts per pattern per fixture)")
    print("=" * 100)
    fixture_labels = list(per_fixture.keys())
    header = f"{'pattern':<37}" + "".join(f"{lbl:>22}" for lbl in fixture_labels) + f"{'TOTAL':>10}"
    print(header)
    print("-" * len(header))
    grand_total: dict[str, int] = {label: 0 for label, _, _ in PATTERNS}
    for label, _, _ in PATTERNS:
        row = f"{label:<37}"
        running = 0
        for flbl in fixture_labels:
            cnt = len(per_fixture[flbl].get(label, []))
            running += cnt
            row += f"{cnt:>22}"
        row += f"{running:>10}"
        grand_total[label] = running
        print(row)
    print("-" * len(header))
    # Per-fixture column total
    col_total_row = f"{'TOTAL':<37}"
    overall = 0
    for flbl in fixture_labels:
        col_sum = sum(len(v) for v in per_fixture[flbl].values())
        overall += col_sum
        col_total_row += f"{col_sum:>22}"
    col_total_row += f"{overall:>10}"
    print(col_total_row)
    print()

    # Per-pattern detail: 5 example occurrences per pattern per fixture.
    print("=" * 100)
    print("EXAMPLE OCCURRENCES (up to 5 per pattern per fixture)")
    print("=" * 100)
    for label, _regex, desc in PATTERNS:
        total = grand_total[label]
        if total == 0:
            continue
        print()
        print(f"[{label}] {desc}")
        print(f"  total across fixtures: {total}")
        for flbl in fixture_labels:
            occs = per_fixture[flbl].get(label, [])
            if not occs:
                continue
            print(f"  -- {flbl}: {len(occs)} occurrences --")
            for occ in occs[:5]:
                page_str = f"p.{occ.page}" if occ.page is not None else "p.?"
                print(
                    f"    [{occ.node_id} {occ.category} {page_str}] "
                    f"match={occ.match_text!r}  ctx={occ.context!r}"
                )

    # Dominant patterns >=10 occurrences in any single fixture.
    print()
    print("=" * 100)
    print("DOMINANT PATTERNS (>= 10 occurrences in at least one fixture)")
    print("=" * 100)
    for label, _, desc in PATTERNS:
        max_per_fixture = max(
            (len(per_fixture[flbl].get(label, [])) for flbl in fixture_labels),
            default=0,
        )
        if max_per_fixture >= 10:
            per_fix = ", ".join(
                f"{flbl}={len(per_fixture[flbl].get(label, []))}" for flbl in fixture_labels
            )
            print(f"  [{label}] max_in_a_fixture={max_per_fixture}  {per_fix}")
            print(f"      {desc}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
