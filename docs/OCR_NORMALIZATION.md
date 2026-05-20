# OCR normalisation pipeline for `enciclopedia_storica`

Status: real implementation as of 2026-05-20. Landed in commits
`d262e2d` (bundled lexicon + `ItalianLexicon` extension),
`1fcfefa` (two new postprocessing steps + plugin wiring),
`81c7c46` (66 unit tests at 100/100/98 % coverage).

## Why this exists

The four `enciclopedia_storica` calibrating fixtures (Adobe Paper
Capture 11.0.23 + Times-Roman family, scanned 2019-2020 from EdD
base volumes I-XLVI 1958-1985) carry pervasive OCR glyph noise that
the conservative `dehyphenate_with_log` step alone cannot recover.
The diagnostic ran in this session over the four fixtures revealed
three families of corruption worth addressing:

1. **End-of-line hyphenations whose joined form fails the strict
   lexicon check** because of OCR noise inside one of the fragments —
   e.g. `paga-\n1nenlo` (PyMuPDF's literal reading) needs to become
   `pagamento`, but the literal join `paga1nenlo` is not in the
   lexicon. The strict step refuses to merge; we want an aggressive
   second pass that consults an OCR substitution table before giving
   up.
2. **Standalone OCR-corrupted body tokens** — `giusti11ia` for
   `giustizia`, `con1litti` for `conflitti`, `paga1nento` for
   `pagamento`, `s11e` for `sue`, `Bccesso` for `Eccesso`. These are
   per-token corruptions outside any hyphenation context. The fix is
   token-by-token substitution validated by the same lexicon.
3. **Structural-marker fossilisations** — `LrnaRATURA` for
   `LETTERATURA`, `LnTEHATURA` for the same, and a few other variants
   of the section labels that head the bibliographic apparatus. These
   are closed-vocabulary corruptions: the corrupted forms have no
   legitimate non-OCR reading, so the substitution applies
   unconditionally.

The diagnostic also documented a fourth corruption class — corrupted
article numbers (`n82`, `u91`, `8rn`, `rr68` for `1182`, `1191`,
`1168` &c.) — but this case touches Layer 1's role boundary (textual
restoration vs. structural recognition) and is deliberately deferred
to a future session.

## Philosophy

The pipeline does not apply textual transformations in blind
preprocessing. Every intervention on the original text respects four
constraints (echoing `ANALYSIS_GIUFFRE_ENCICLOPEDIA.md` § 9):

1. **Posterior to analysis** — the intervention happens after a
   complete reconstruction of the document, not in streaming during
   extraction.
2. **Justified by lexicon evidence** — a per-token substitution
   fires only when (a) the literal token is **not** in the lexicon
   and (b) **exactly one** substitution variant lands in the lexicon
   at the shortest reachable depth. Ambiguity refuses to choose.
3. **Declared to the user** — every accepted substitution is recorded
   as a `Transformation` in `Document.transformations` so a consumer
   of the JSON knows when the text they see is not the literal form
   of the PDF.
4. **Reversible** — the `Transformation` log carries `position`,
   `original` and `normalized`. Layer 2 reverts the log walking it in
   reverse (right-to-left positions, restore `original` at each
   recorded slice).

## Architecture

Four steps run in declared order on every `enciclopedia_storica`
document:

```
dehyphenate_with_log
    └── conservative end-of-line de-hyphenation, strict lexicon
dehyphenate_ocr_aggressive
    └── OCR-aware second pass, depth-2 substitution variant search
normalize_ocr_with_dictionary
    └── closed structural-marker dictionary + per-token cleanup
merge_cross_page_notes
    └── multi-page note merging
```

The orchestrator chains the `Transformation` tuples; each step sees
the document after every prior step has taken effect.

### `ItalianLexicon` backends

Three construction modes (see
`pipeline/src/scabopdf_pipeline/postprocessing/lexicon.py`):

- `ItalianLexicon()` — preferred. Loads the bundled gzipped wordlist
  from `scabopdf_pipeline.resources.lexicon.italian_wordlist.txt.gz`
  (~280 000 lowercase Italian words including inflected forms, MIT
  licence from napolux/paroleitaliane). The load is cached for the
  process lifetime via an `lru_cache(maxsize=1)`.
- pyspellchecker fallback — runs only if the bundled resource is
  missing for any reason. Keeps existing environments working without
  a forced upgrade.
- `ItalianLexicon.from_word_set({...})` — deterministic in-memory
  lookup for unit tests.

A future Hunspell backend (with affix expansion) is documented as a
possible extension; the `is_known(word) -> bool` API is stable and
preserves caller code regardless of the underlying backend.

### Substitution table

`pipeline/src/scabopdf_pipeline/postprocessing/ocr_substitutions.py`
declares the empirical superset of OCR glyph confusions observed on
the calibrating fixtures:

| Source | Replacements | Where it fires |
| --- | --- | --- |
| `0` | `o` | `s0ggetto` → `soggetto` |
| `1` | `i`, `l`, `t`, `f` | `di1itto` → `diritto`; `con1litti` → `conflitti` |
| `11` | `ll`, `ii`, `zi`, `z`, `u`, `n` | `vi11io` → `vizio`; `s11e` → `sue` |
| `1n` | `m` | `paga1nenlo` → `pagame…lo` then `l → t` |
| `rn` | `m` | `co1n` → `com` (some shapes) |
| `l` | `t` | `pagamenlo` → `pagamento` |
| `n` | `u` | rare; mostly proper names |
| `b` | `e` | `Bccesso` → `Eccesso` |
| `h` | `r` | `LETrERATURA` family |

Each entry is gated by lexicon validation, so the table is safe to
extend even when individual entries look generous.

### Depth-preferred disambiguation

The variant generator runs BFS up to depth 2 (configurable). A
correction is accepted only when the **shallowest non-empty layer**
yields exactly one lexicon-valid variant. If two variants land in
the same depth, the helper returns `None` (no correction). This
mirrors the empirical observation that single-edit corrections are
more likely than compound corrections.

### Structural-marker dictionary

A closed list of `(corrupted_form, canonical_form)` pairs in
`ocr_substitutions._STRUCTURAL_MARKER_DICTIONARY` is applied
unconditionally because the corrupted forms are not Italian words
and have no legitimate non-OCR reading. Entries cover six
LETTERATURA fossilisations and two FONTI fossilisations. Adding new
entries is safe: the matcher uses literal `str.find`, no regex
risk.

### Preservative compounds

`ocr_substitutions._HYPHEN_PRESERVATIVE_PAIRS` lists `(prefix,
suffix)` pairs whose hyphen must survive line breaks. Today's set:
`decreto-legge`, `legge-delega`, `ex-articolo`, `ex-lege`,
`ex-tunc`, `ex-nunc`, `post-scriptum`. The dehyphenator looks the
pair up lowercase and refuses to merge if present. Even without
this set, the lexicon validation alone would refuse to merge most
of these (the joined form is not in the bundled wordlist) — the
preservative list is a safety net for compounds whose joined form
might happen to be in the lexicon.

## What is **not** in scope

- **Cross-Node hyphenation.** When the word-before lives in one Node
  and the word-after lives in another, neither dehyphenator handles
  the case. Documented limitation; a future iteration can walk
  reading-order pairs of adjacent Nodes.
- **Hyphenation across footnote markers** (`or-\n(I)`, `ra-\n(7)`).
  These are structural collisions, not OCR noise; merging them
  would corrupt the apparatus binding. The diagnostic measured
  ~42 % of broad hyphenation candidates fall into this class.
- **Article-number OCR corruption** (`n82`/`u91`/`8rn`/`rr68` for
  Codice civile articles). Touches Layer 1's role boundary; deferred.
- **SOMMARIO OCR fossilisations** (`SolUlAJUO`, `So1n1.r.a10`). The
  destruction is too severe to recover by substitution; the plugin's
  classifier emits `sommario_unrecoverable_*` warnings instead.

## Empirical impact

See `CARRYOVER.md` v2.18 § "Sessione corrente" for the per-fixture
numbers (`n_dehyphenations`, `n_dehyphenations_ocr_aggressive`,
`n_ocr_normalizations`, `n_merge_cross_page_notes`) measured on the
four calibrating fixtures post-landing.
