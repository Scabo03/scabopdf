# Layer 2 — Structural validation: Generic vs Layer 1 baseline

This document describes the **structural comparison framework**
(`app/src/measurement/structuralComparison.ts`,
`app/src/measurement/corpusBaselines.ts`): how it compares the on-device Generic
plugin's output against the corresponding Layer 1 baseline, how to read a
report, what "low delta" means, how to run the comparison on a new PDF, and —
crucially — why this is **not** the byte-for-byte equality Layer 1 enforces
internally.

No Python anywhere in this chain: the comparison, the report and its tests are
TypeScript; the extraction it consumes is Swift/PDFKit (measured on-device).
This sits alongside the test pyramid in `docs/LAYER2_TEST_FRAMEWORK.md` and reads
the closed taxonomy in `docs/LAYER2_CATEGORY_TAXONOMY.md`.

## 1. Why this comparison is structural, never byte-for-byte

Layer 1 produces its baselines with **PyMuPDF** plus the corpus-specific Python
profiles. Layer 2's Generic plugin runs over an **on-device PDFKit** extraction.
The two extractors do not see identical spans — colour, bounding boxes and font
sizes drift by small amounts, and PDFKit's line/► span segmentation differs from
PyMuPDF's. A byte-for-byte comparison of the two JSON trees is therefore
**impossible by construction** and is never attempted.

|                           | Layer 1 internal baselines (`pipeline/tests/snapshots/`) | This comparison (Layer 2)                          |
| ------------------------- | -------------------------------------------------------- | -------------------------------------------------- |
| Extractor on both sides   | PyMuPDF vs PyMuPDF (same)                                | PDFKit (Generic) vs PyMuPDF (baseline)             |
| Producer of the structure | the same Python profile                                  | corpus-agnostic Generic vs corpus-specific profile |
| Equality checked          | **byte-for-byte** JSON / SHA digest                      | **per-category counts + tree topology**            |
| Tolerance                 | zero (drift fails the test)                              | a measurable relative tolerance on counts          |
| Purpose                   | regression-lock the Python pipeline                      | measure how close the fallback gets to the oracle  |

The comparison is **structural and semantic**: for each category of the closed
Generic taxonomy it counts the nodes the Generic produces versus the nodes the
Layer 1 baseline records, and reports the absolute and relative delta plus a few
topology metrics. The category **names are shared verbatim** with Layer 1 (the
taxonomy guarantees nominal alignment), so a `SemanticCategory` key means the
same thing on both sides — no remap table is invented.

## 2. What is compared, and what is "not comparable"

The taxonomy's three coverage buckets decide what carries a verdict:

- **produced** (`HEADING_1..4`, `BODY`, `NOTE`) — the Generic's responsibility.
  Only these are banded EXACT / CLOSE / DIVERGENT.
- **detected-suppressed** (`ARTIFACT_*`, `BOOK_PAGE_ANCHOR`) — the Generic
  recognises this furniture as a signal and **drops it on purpose** (emits no
  node). The baseline keeps such nodes for reference, so the Generic showing
  zero is _correct_, not a defect — banded `NOT_COMPARABLE`.
- **reserved** (`ARTICLE_HEADER`, `CROSS_REFERENCE`, `NOTE`-apparatus, the
  DeJure/EdD/AKN vocabulary, …) — only a corpus-specific plugin or a non-PDF
  backend emits these. The Generic produces none; banded `NOT_COMPARABLE`. Their
  baseline counts are still reported for context.

## 3. Reading a report

One report per fixture is written to `test-output-private/comparisons/`
(gitignored, because it derives from the copyright-protected PDFs — the framework
_code_ and the synthetic unit tests are committed, the per-PDF reports are not).
The report is **content-free**: category names, counts and numeric deltas only,
never document text — the same privacy contract the Layer 1 baselines honour.

Top-level fields (`StructuralComparisonReport`):

| Field                               | Meaning                                                                                                           |
| ----------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| `fixtureSlug`, `corpusId`           | Filename-derived slug + Layer 1 corpus id (allowed; not content).                                                 |
| `baselineFile`, `baselineAvailable` | The snapshot used, and whether a structural baseline exists at all.                                               |
| `categories[]`                      | Per-category delta lines (see below), produced first.                                                             |
| `producedSummary`                   | Focused roll-up over the produced categories (the Generic's remit).                                               |
| `topology.generic`                  | Full Generic tree metrics: `nodeTotal`, `maxDepth`, heading/NOTE histograms.                                      |
| `topology.baseline`                 | Counts-only metrics (`nodeTotal`, heading histogram); `maxDepthKnown:false` because the baseline carries no tree. |

Each `categories[]` line:

| Field                  | Meaning                                                              |
| ---------------------- | -------------------------------------------------------------------- | ------------------ | --- |
| `category`, `coverage` | The `SemanticCategory` and its taxonomy bucket.                      |
| `generic`, `baseline`  | Node counts on each side.                                            |
| `absDelta`             | `                                                                    | generic − baseline | `.  |
| `relDelta`             | `absDelta / baseline`, or `null` when the baseline count is 0.       |
| `band`                 | `EXACT` / `CLOSE` / `DIVERGENT` (produced only) or `NOT_COMPARABLE`. |

### What "low delta" means

The bands are defined on the **relative** per-category delta of the produced
categories, with a default tolerance `STRUCTURAL_REL_TOLERANCE = 0.15` (±15 %):

- **EXACT** — identical counts.
- **CLOSE** — within ±15 % of the baseline (a "low delta").
- **DIVERGENT** — beyond ±15 %, or the Generic produced a category the baseline
  has none of.

`producedSummary.withinTolerance` is `true` only when every produced category is
EXACT or CLOSE. **It is informational, not a pass/fail gate.** The Generic is a
corpus-agnostic fallback measured against a corpus-specific oracle, so a `false`
is _expected_ on:

- **colour-coded corpora** (e.g. Marrone/BIC): the Generic over-detects headings
  by size/colour and cannot map heading _levels_ the way a corpus plugin does, so
  `HEADING_*` deltas are large and `NOTE` is 0 against a baseline of thousands.
  This is the documented D4 limitation, not a regression.
- **heading-implicit corpora** (e.g. Torrente): heads that are not size- or
  colour-distinct are under-detected; the apparatus categories
  (`CROSS_REFERENCE`, `MARGINAL_HEADING`) the baseline mints are entirely
  out of the Generic's reach.

The number that matters is the **trend** over time on the produced categories:
when a future corpus plugin lands for a corpus, its `withinTolerance` should flip
to `true` and `maxRelDelta` should collapse toward 0. The framework measures the
gap a corpus plugin is meant to close; it does not pretend the Generic closes it.

## 4. Running the comparison

Prerequisite: a populated `test-output-private/extractions/` (the on-device
captures). Produce it with the test-pyramid workflow in
`docs/LAYER2_TEST_FRAMEWORK.md` §3 (`seed_fixtures.sh` → `ScaboPDFExtractionTests`
→ `pull_captures.sh`).

```sh
cd app && npx jest structuralComparison
```

- The unit suite (`structuralComparison.test.ts`) runs everywhere — it uses only
  synthetic inputs and pins the delta math, banding, topology and skip logic.
- The integration generator (`structuralComparison.integration.test.ts`) reads
  the captures and the committed baselines, writes the per-fixture reports +
  `_index.json`, and **skips** (whole suite, or per fixture) when a capture is
  absent — so a fresh clone with no local fixtures stays green, exactly like the
  Layer 1 `pytest.skip` convention.

### Adding a new PDF

1. Seed the PDF and capture it on a Simulator (the workflow above) so a
   `<slug>.capture.json` lands in `test-output-private/extractions/`.
2. Add one entry to `CORPUS_BASELINES` in `corpusBaselines.ts`: the capture slug,
   the Layer 1 `corpusId`, and the baseline filename under
   `pipeline/tests/snapshots/` that carries a `category_counts` map — or `null`
   with a `note` when no structural baseline exists (several snapshot families,
   e.g. `p040` matches-scores and `p019`/`p021` digests, carry no
   `category_counts`; a one-sided report is produced instead).
3. Re-run `npx jest structuralComparison`. No category remap is needed: the names
   are taxonomy-aligned with Layer 1.

If a baseline category cannot be mapped to a taxonomy category, **stop** — that
means the closed taxonomy has a hole or the inter-layer contract changed, which
touches the foundations and must be raised, not patched here.

## 5. The current fixture coverage

Four of the seven seeded fixtures have a structural (`category_counts`) baseline
and produce a two-sided comparison: Mandrioli Vol. I (`p018`), Mosconi (`p019`),
Marrone (`p014`), Torrente (`p019`). Tesauro and Mandrioli Vol. II / Vol. IV have
no full-document structural snapshot in the repo, so they produce a one-sided
report (the Generic counts only, `baselineAvailable:false`) — honest about the
absence rather than inventing an oracle.
