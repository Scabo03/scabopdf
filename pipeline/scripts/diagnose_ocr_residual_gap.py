"""Diagnose residual OCR corruption gaps in EdD storica fixtures.

This is a *diagnostic-only* script that runs the full Layer 1 pipeline
(extract → classify → reconstruct → resolve_apparatus →
apply_post_processing → convert_document) on the four
``enciclopedia_storica`` calibrating fixtures and inventories the
character-level OCR corruption patterns that the existing
``_OCR_SUBSTITUTIONS`` table and ``_STRUCTURAL_MARKER_DICTIONARY``
miss.

The script does NOT modify production code. It only emits a report on
stdout that can be used to plan an evidence-based extension of the
substitution table.

Categories investigated:

1. Digit-in-the-middle-of-a-word tokens (``\\b\\w+\\d+\\w+\\b``)
   — the canonical residual gap of the ``1`` / ``0`` substitution
   table.
2. Mid-dot ``·`` contamination (``\\b\\w+·\\w*`` and trailing
   ``\\w+·``) — Adobe Paper Capture often emits ``·`` for ``.``
   inside body text.
3. Apostrophe/quote artefacts (extra spaces around ``'``, double
   quotes, mixed straight/curly).
4. Diacritic loss / corruption candidates: tokens that would be a
   known Italian word with a final accented vowel added back
   (``citta`` → ``città``).
5. Non-ASCII characters outside the allowed body-text class.

Output format: structured stdout with per-fixture tables and a final
ranked report of the top-30 uncovered corrupt tokens, along with a
flat aggregate suggesting candidate new substitutions.

Runtime: ~30s on a modest workstation (the four fixtures total ~110
pages and the pipeline runs at ~9 pages/sec including OCR
substitution).
"""

from __future__ import annotations

import re
import sys
import time
from collections import Counter
from pathlib import Path
from typing import Iterable

REPO_ROOT = Path(__file__).resolve().parents[2]
PIPELINE_ROOT = REPO_ROOT / "pipeline"
sys.path.insert(0, str(PIPELINE_ROOT / "src"))

from scabopdf_pipeline.apparatus import resolve_apparatus  # noqa: E402
from scabopdf_pipeline.classification import classify  # noqa: E402
from scabopdf_pipeline.emission import convert_document  # noqa: E402
from scabopdf_pipeline.extraction import extract  # noqa: E402
from scabopdf_pipeline.postprocessing import apply_post_processing  # noqa: E402
from scabopdf_pipeline.postprocessing.lexicon import ItalianLexicon  # noqa: E402
from scabopdf_pipeline.postprocessing.ocr_substitutions import (  # noqa: E402
    find_lexicon_corrected_form,
    iter_substitutions,
)
from scabopdf_pipeline.profiles.enciclopedia_storica import (  # noqa: E402
    EnciclopediaStoricaProfile,
)
from scabopdf_pipeline.profiling.profile import DocumentProfile  # noqa: E402
from scabopdf_pipeline.reconstruction import reconstruct  # noqa: E402
from scabopdf_pipeline.reconstruction.types import Document, Node  # noqa: E402
from scabopdf_pipeline.schema.categories import SemanticCategory  # noqa: E402

FIXTURES_DIR = PIPELINE_ROOT / "tests" / "fixtures" / "private"

FIXTURES = [
    ("eccesso_potere", FIXTURES_DIR / "edd_eccesso_potere.pdf"),
    ("lavoro", FIXTURES_DIR / "edd_lavoro.pdf"),
    ("pagamento", FIXTURES_DIR / "edd_pagamento.pdf"),
    ("azienda", FIXTURES_DIR / "edd_azienda.pdf"),
]

TEXT_BEARING_CATEGORIES = frozenset(
    {
        SemanticCategory.BODY,
        SemanticCategory.NOTE,
        SemanticCategory.TITLE,
        SemanticCategory.HEADING_1,
        SemanticCategory.HEADING_2,
        SemanticCategory.HEADING_3,
        SemanticCategory.HEADING_4,
        SemanticCategory.TOC_GENERAL,
        SemanticCategory.FONTI,
        SemanticCategory.LETTERATURA,
        SemanticCategory.SECTION_LABEL,
        SemanticCategory.CHAPTER_SUMMARY,
        SemanticCategory.MARGINAL_GLOSS,
        SemanticCategory.MARGINAL_HEADING,
    }
)

# --- regexes -----------------------------------------------------------

_DIGIT_IN_MIDDLE_RE = re.compile(r"\b[A-Za-zÀ-ÿ]+\d+[A-Za-zÀ-ÿ]+(?:\d+[A-Za-zÀ-ÿ]+)*\b")
"""Tokens containing at least one digit between two letter runs.

Excludes pure numeric tokens (years, article numbers, note markers)
because they are legitimate text. Excludes leading or trailing digits
(``19o`` → ``190``-like patterns are not what we are after; we want
``paga1nenlo``-style residuals).
"""

_MIDDOT_TOKEN_RE = re.compile(r"\b[A-Za-zÀ-ÿ0-9]+·[A-Za-zÀ-ÿ0-9]*")
"""Tokens with an embedded or trailing middle-dot ``·`` (U+00B7).

Empirically the Paper Capture pipeline emits ``·`` for ``.`` inside
running prose, so this pattern surfaces every residual bullet
contamination.
"""

_APO_SPACED_RE = re.compile(r"\b[A-Za-zÀ-ÿ]+\s+'\s+[A-Za-zÀ-ÿ]+\b")
"""Apostrophe with whitespace on at least one side: ``dell ' articolo``."""

_BODY_TEXT_ALLOWED = re.compile(
    r"[A-Za-zÀ-ÿçÇ0-9 .,;:!?()'\"\-—–…/\[\]§•·\n\t\r’‘“”«»°ªº&%+]"
)
"""Character class admitting every glyph legitimately found in EdD storica body text.

Whatever lies outside is reported and counted.
"""

_PURE_DIGITS_RE = re.compile(r"^\d+$")
_TOKEN_RE = re.compile(r"\b[A-Za-zÀ-ÿ0-9]+\b")

# Italian final-accented-vowel candidates we want to test for diacritic loss.
_ACCENT_CANDIDATES = ("à", "è", "é", "ì", "ò", "ó", "ù")


# --- pipeline helpers --------------------------------------------------


def _make_profile() -> DocumentProfile:
    plugin = EnciclopediaStoricaProfile()
    return DocumentProfile(
        profile_id=plugin.profile_id,
        editorial_family=plugin.editorial_family,
        genre=plugin.genre,
        layouts_available=["L1", "L2", "L3"],
        layouts_disabled=plugin.get_layouts_disabled(),
        post_processing=plugin.get_post_processing(),
        categories_emitted=plugin.get_categories(),
        confidence=0.85,
        warnings=[],
    )


def _iter_text_nodes(node: Node) -> Iterable[Node]:
    if node.text is not None and node.category in TEXT_BEARING_CATEGORIES:
        yield node
    for child in node.children:
        yield from _iter_text_nodes(child)


def _document_text_iter(document: Document) -> Iterable[tuple[str, str]]:
    for root in document.root:
        for node in _iter_text_nodes(root):
            assert node.text is not None
            yield (node.category.value, node.text)


# --- corruption catalogues ---------------------------------------------


def _classify_digit_token(token: str, lexicon: ItalianLexicon) -> tuple[str, str | None, int | None]:
    """Tell whether the existing substitution table corrects ``token``.

    Returns a triple ``(status, corrected, depth)``:
    - ``"already_in_lexicon"`` — ``token.lower()`` is already a word.
    - ``"covered"`` — the existing table corrects it.
    - ``"uncovered"`` — no single unambiguous correction found.
    """
    if lexicon.is_known(token):
        return ("already_in_lexicon", None, None)
    correction = find_lexicon_corrected_form(token, lexicon)
    if correction is not None:
        # Determine depth by replaying the BFS up to max_substitutions=2.
        return ("covered", correction, 2)
    return ("uncovered", None, None)


def _diacritic_loss_candidate(token: str, lexicon: ItalianLexicon) -> str | None:
    """Return the accented form of ``token`` if it is a plausible diacritic loss."""
    lo = token.lower()
    if lexicon.is_known(lo):
        return None
    if len(lo) < 3:
        return None
    # Try replacing the final vowel with each accented variant.
    if lo[-1] in "aeiou":
        for accent in _ACCENT_CANDIDATES:
            candidate = lo[:-1] + accent
            if lexicon.is_known(candidate):
                return candidate
    return None


# --- main --------------------------------------------------------------


def main() -> int:
    print(f"Repo root: {REPO_ROOT}")
    print(f"Fixtures dir: {FIXTURES_DIR}")
    lexicon = ItalianLexicon()
    print(f"Lexicon size: {lexicon.size()}")
    print(f"Existing substitutions: {list(iter_substitutions())}")
    print()

    profile = _make_profile()

    per_fixture_summary: list[dict] = []
    aggregate_digit_uncovered: Counter[str] = Counter()
    aggregate_digit_covered: Counter[str] = Counter()
    aggregate_middot: Counter[str] = Counter()
    aggregate_apo_spaced: Counter[str] = Counter()
    aggregate_diacritic_loss: Counter[str] = Counter()
    aggregate_bad_chars: Counter[str] = Counter()
    aggregate_uncovered_digit_token_to_chars: Counter[str] = Counter()
    aggregate_uncovered_examples: dict[str, str] = {}

    for fixture_name, fixture_path in FIXTURES:
        if not fixture_path.exists():
            print(f"[SKIP] {fixture_name}: fixture missing at {fixture_path}")
            continue
        t0 = time.perf_counter()
        print(f"[{fixture_name}] running pipeline on {fixture_path.name}")
        plugin = EnciclopediaStoricaProfile()
        extraction = extract(fixture_path)
        classified = classify(extraction, profile, plugin)
        document = reconstruct(extraction, classified, profile, plugin)
        document = resolve_apparatus(document, extraction, classified, plugin)
        document = apply_post_processing(document, extraction, classified, plugin)
        scabopdf_document = convert_document(document, extraction, profile, fixture_path)
        del scabopdf_document  # not consumed; ensures emission path is exercised
        t_pipeline = time.perf_counter() - t0

        # Per-fixture counters
        digit_covered: Counter[str] = Counter()
        digit_uncovered: Counter[str] = Counter()
        middot_tokens: Counter[str] = Counter()
        apo_spaced: Counter[str] = Counter()
        diacritic_loss: Counter[str] = Counter()
        bad_chars: Counter[str] = Counter()
        total_tokens = 0
        total_text_chars = 0

        for _category, text in _document_text_iter(document):
            total_text_chars += len(text)
            # Digit-in-middle tokens.
            for m in _DIGIT_IN_MIDDLE_RE.finditer(text):
                tok = m.group(0)
                status, _correction, _depth = _classify_digit_token(tok, lexicon)
                if status == "covered":
                    digit_covered[tok.lower()] += 1
                elif status == "uncovered":
                    digit_uncovered[tok.lower()] += 1
                    if tok.lower() not in aggregate_uncovered_examples:
                        # store a 60-char window of context
                        start = max(0, m.start() - 30)
                        end = min(len(text), m.end() + 30)
                        aggregate_uncovered_examples[tok.lower()] = text[start:end].replace(
                            "\n", " "
                        )
            # Middle-dot tokens.
            for m in _MIDDOT_TOKEN_RE.finditer(text):
                middot_tokens[m.group(0).lower()] += 1
            # Apostrophe spacing artefacts.
            for m in _APO_SPACED_RE.finditer(text):
                apo_spaced[m.group(0).lower()] += 1
            # Diacritic-loss candidates (sample every token).
            for m in _TOKEN_RE.finditer(text):
                tok = m.group(0)
                total_tokens += 1
                if _PURE_DIGITS_RE.match(tok):
                    continue
                candidate = _diacritic_loss_candidate(tok, lexicon)
                if candidate is not None:
                    diacritic_loss[tok.lower()] += 1
            # Non-allowed body-text characters.
            for ch in text:
                if not _BODY_TEXT_ALLOWED.match(ch):
                    bad_chars[ch] += 1

        # Aggregate
        for tok, n in digit_uncovered.items():
            aggregate_digit_uncovered[tok] += n
            aggregate_uncovered_digit_token_to_chars[tok] = sum(
                1 for ch in tok if ch.isdigit()
            )
        for tok, n in digit_covered.items():
            aggregate_digit_covered[tok] += n
        for tok, n in middot_tokens.items():
            aggregate_middot[tok] += n
        for tok, n in apo_spaced.items():
            aggregate_apo_spaced[tok] += n
        for tok, n in diacritic_loss.items():
            aggregate_diacritic_loss[tok] += n
        for ch, n in bad_chars.items():
            aggregate_bad_chars[ch] += n

        per_fixture_summary.append(
            {
                "fixture": fixture_name,
                "pages": extraction.page_count,
                "total_tokens": total_tokens,
                "total_chars": total_text_chars,
                "digit_in_middle_covered": sum(digit_covered.values()),
                "digit_in_middle_uncovered": sum(digit_uncovered.values()),
                "digit_in_middle_uncovered_unique": len(digit_uncovered),
                "middot_tokens": sum(middot_tokens.values()),
                "middot_unique": len(middot_tokens),
                "apo_spaced": sum(apo_spaced.values()),
                "diacritic_loss_occ": sum(diacritic_loss.values()),
                "diacritic_loss_unique": len(diacritic_loss),
                "bad_char_occ": sum(bad_chars.values()),
                "bad_char_unique": len(bad_chars),
                "pipeline_secs": t_pipeline,
            }
        )

    # -----------------------------------------------------------------
    # Report
    # -----------------------------------------------------------------
    print()
    print("=" * 80)
    print("PER-FIXTURE SUMMARY")
    print("=" * 80)
    header = (
        f"{'fixture':<18}{'pp':>4}{'tok':>8}{'chars':>9}"
        f"{'D-cov':>7}{'D-unc':>7}{'D-uU':>6}"
        f"{'·tok':>6}{'·U':>5}{'apo':>5}"
        f"{'dia':>5}{'diaU':>5}{'bad':>5}{'badU':>5}{'secs':>7}"
    )
    print(header)
    for row in per_fixture_summary:
        print(
            f"{row['fixture']:<18}{row['pages']:>4}{row['total_tokens']:>8}"
            f"{row['total_chars']:>9}"
            f"{row['digit_in_middle_covered']:>7}"
            f"{row['digit_in_middle_uncovered']:>7}"
            f"{row['digit_in_middle_uncovered_unique']:>6}"
            f"{row['middot_tokens']:>6}{row['middot_unique']:>5}"
            f"{row['apo_spaced']:>5}"
            f"{row['diacritic_loss_occ']:>5}{row['diacritic_loss_unique']:>5}"
            f"{row['bad_char_occ']:>5}{row['bad_char_unique']:>5}"
            f"{row['pipeline_secs']:>7.2f}"
        )
    print()
    print("Legend:")
    print(
        "  D-cov / D-unc / D-uU = digit-in-middle tokens: covered "
        "/ uncovered occ. / uncovered unique"
    )
    print("  ·tok / ·U = middle-dot · token occ. / unique forms")
    print("  apo = apostrophe-with-spaces occ. (dell ' articolo)")
    print("  dia / diaU = diacritic-loss candidate occ. / unique")
    print("  bad / badU = non-allowed character occ. / unique")
    print()

    # -----------------------------------------------------------------
    # Top-30 ranking sections
    # -----------------------------------------------------------------
    def _print_top(name: str, counter: Counter[str], k: int = 30) -> None:
        print()
        print("-" * 80)
        print(f"{name} — top {k} (total occ {sum(counter.values())}, unique {len(counter)})")
        print("-" * 80)
        for tok, n in counter.most_common(k):
            ctx = aggregate_uncovered_examples.get(tok, "")
            print(f"  {n:>6}  {tok!r:<40}  …{ctx!r}…" if ctx else f"  {n:>6}  {tok!r}")

    _print_top("UNCOVERED digit-in-middle tokens", aggregate_digit_uncovered, 30)
    _print_top("COVERED digit-in-middle tokens (sanity check)", aggregate_digit_covered, 15)
    _print_top("MIDDLE-DOT (·) tokens", aggregate_middot, 30)
    _print_top("APOSTROPHE-SPACED tokens", aggregate_apo_spaced, 15)
    _print_top("DIACRITIC-LOSS candidates", aggregate_diacritic_loss, 30)

    # Non-allowed characters
    print()
    print("-" * 80)
    print(
        f"NON-ALLOWED CHARACTERS — total occ {sum(aggregate_bad_chars.values())}, "
        f"unique {len(aggregate_bad_chars)}"
    )
    print("-" * 80)
    for ch, n in aggregate_bad_chars.most_common(30):
        print(f"  {n:>6}  U+{ord(ch):04X}  {ch!r}")

    # -----------------------------------------------------------------
    # Heuristic ranking of recommended new substitutions
    # -----------------------------------------------------------------
    print()
    print("=" * 80)
    print("HEURISTIC: candidate new substitutions inferred from uncovered tokens")
    print("=" * 80)
    # For each uncovered token we try the catalogue of plausible
    # single-digit-to-letter substitutions and report which ones, if
    # added to the table, would shift the token into "covered".
    candidate_substitutions: Counter[tuple[str, str]] = Counter()
    candidate_supporting_tokens: dict[tuple[str, str], list[str]] = {}
    digit_candidates_for_each_digit = {
        "0": ("o", "a", "e", "c"),
        "1": ("i", "l", "t", "f", "j", "r"),
        "2": ("z", "s"),
        "3": ("e", "s", "b"),
        "4": ("a", "h"),
        "5": ("s", "b"),
        "6": ("e", "g", "o", "b"),
        "7": ("t", "f", "i", "l"),
        "8": ("g", "s", "b"),
        "9": ("g", "q", "p"),
    }
    for tok, n in aggregate_digit_uncovered.items():
        lo = tok.lower()
        for i, ch in enumerate(lo):
            if not ch.isdigit():
                continue
            for repl in digit_candidates_for_each_digit.get(ch, ()):
                cand = lo[:i] + repl + lo[i + 1 :]
                if lexicon.is_known(cand):
                    candidate_substitutions[(ch, repl)] += n
                    candidate_supporting_tokens.setdefault((ch, repl), []).append(
                        f"{tok}→{cand} ({n}x)"
                    )

    print()
    print("Per single-character digit→letter substitution, sum of uncovered token occurrences")
    print("that would become covered if added (single-edit only):")
    for (src, repl), n in candidate_substitutions.most_common(30):
        examples = candidate_supporting_tokens.get((src, repl), [])[:5]
        print(f"  '{src}' -> '{repl}' : {n:>5} occ.  e.g. {examples}")

    # Per-letter-substitution suggestion too (letter pairs in the
    # current table cover ``l→t``, ``n→u``, ``b→e``, ``h→r``; we look
    # for the next ones).
    letter_candidates = {
        "c": ("e", "o"),
        "e": ("c", "o"),
        "o": ("c", "e"),
        "i": ("l", "t"),
        "u": ("n", "il", "ii"),
        "r": ("h",),
        "t": ("l", "f"),
        "f": ("t", "l"),
        "m": ("rn", "in"),
        "n": ("u", "h", "ti"),
        "a": ("o",),
    }
    candidate_letter_substitutions: Counter[tuple[str, str]] = Counter()
    candidate_letter_supporting: dict[tuple[str, str], list[str]] = {}
    # We need to scan tokens that are NOT digit-in-middle but that are
    # still not in the lexicon. Collect a sample.
    print()
    print("Single-letter candidate substitutions — frequency-weighted analysis on the")
    print("aggregate body of non-lexicon tokens (sampled from the four fixtures):")
    # Collect non-lexicon tokens
    non_lex_counter: Counter[str] = Counter()
    for fixture_name, fixture_path in FIXTURES:
        if not fixture_path.exists():
            continue
        plugin = EnciclopediaStoricaProfile()
        extraction = extract(fixture_path)
        classified = classify(extraction, profile, plugin)
        document = reconstruct(extraction, classified, profile, plugin)
        document = resolve_apparatus(document, extraction, classified, plugin)
        document = apply_post_processing(document, extraction, classified, plugin)
        for _cat, text in _document_text_iter(document):
            for m in _TOKEN_RE.finditer(text):
                tok = m.group(0)
                if len(tok) < 4 or _PURE_DIGITS_RE.match(tok):
                    continue
                lo = tok.lower()
                if not lexicon.is_known(lo):
                    non_lex_counter[lo] += 1

    print(
        f"  Non-lexicon tokens (≥4 chars, not pure digits): "
        f"{sum(non_lex_counter.values())} occ., {len(non_lex_counter)} unique."
    )
    for tok, n in non_lex_counter.items():
        for i, ch in enumerate(tok):
            for repl in letter_candidates.get(ch, ()):
                cand = tok[:i] + repl + tok[i + len(ch) :] if len(repl) != 1 else tok[:i] + repl + tok[i + 1 :]
                if lexicon.is_known(cand):
                    candidate_letter_substitutions[(ch, repl)] += n
                    candidate_letter_supporting.setdefault((ch, repl), []).append(
                        f"{tok}→{cand} ({n}x)"
                    )

    print()
    print("Top letter→letter substitutions (single-edit, lexicon-validated):")
    for (src, repl), n in candidate_letter_substitutions.most_common(30):
        already = any(
            src == existing_src and repl in existing_repls
            for existing_src, existing_repls in iter_substitutions()
        )
        flag = " (already in table)" if already else ""
        examples = candidate_letter_supporting.get((src, repl), [])[:5]
        print(f"  '{src}' -> '{repl}' : {n:>5} occ.{flag}  e.g. {examples}")

    # -----------------------------------------------------------------
    # Top non-lexicon tokens overall (residual visibility)
    # -----------------------------------------------------------------
    print()
    print("=" * 80)
    print("Top-50 most frequent NON-LEXICON tokens (≥4 chars, residual visibility)")
    print("=" * 80)
    for tok, n in non_lex_counter.most_common(50):
        print(f"  {n:>5}  {tok!r}")

    # -----------------------------------------------------------------
    # Aggregate summary lines for fast skim
    # -----------------------------------------------------------------
    total_covered = sum(aggregate_digit_covered.values())
    total_uncovered = sum(aggregate_digit_uncovered.values())
    total_digit_in_middle = total_covered + total_uncovered
    if total_digit_in_middle:
        pct = 100.0 * total_uncovered / total_digit_in_middle
    else:
        pct = 0.0
    print()
    print("=" * 80)
    print("AGGREGATE")
    print("=" * 80)
    print(
        f"  digit-in-middle tokens — total: {total_digit_in_middle}, "
        f"covered by current table: {total_covered}, uncovered: {total_uncovered} ({pct:.1f}%)"
    )
    print(f"  middle-dot tokens: {sum(aggregate_middot.values())} occ.")
    print(f"  diacritic-loss candidates: {sum(aggregate_diacritic_loss.values())} occ.")
    print(f"  apostrophe-spaced: {sum(aggregate_apo_spaced.values())} occ.")
    print(
        f"  non-allowed chars: {sum(aggregate_bad_chars.values())} occ., "
        f"{len(aggregate_bad_chars)} unique."
    )

    return 0


if __name__ == "__main__":
    sys.exit(main())
