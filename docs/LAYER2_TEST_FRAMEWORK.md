# Layer 2 — On-device test & observability framework

This document describes the test and observability framework for the React
Native app (Layer 2): how the app's PDF-reading pipeline is exercised against
real PDFs on a Simulator, what it measures, and what is committed vs kept local.

It is the contract every future corpus plugin's verification reuses. No Python
anywhere: iOS-native (Swift/XCTest), Ruby (xcodeproj project edits), bash
(simctl glue), TypeScript (report generation).

## 1. The test pyramid

Three layers, from broad+slow to narrow+fast:

1. **XCUITest E2E** (`app/ios/ScaboPDFUITests`). Drives the *real* app — document
   picker included — and reads the accessibility tree as VoiceOver does. It is
   the only layer that exercises the full chain in Hermes on-device. It requires
   the Simulator's accessibility-automation backbone, which the current
   sandboxed CI cannot initialise (`axremoted` / "AX loaded notification"
   timeout); it runs on an unrestricted macOS session. Built and checked in;
   execution deferred to a Mac.

2. **XCTest extraction unit** (`app/ios/ScaboPDFExtractionTests`). A plain
   (non-UI) XCTest, so it needs no accessibility daemon and runs on the
   sandboxed Simulator. It calls the real Swift/PDFKit `ScaboPdfExtractor.extract`
   on the seeded fixtures and produces the first objective on-device extraction
   measurements — replacing the worthless PyMuPDF proxy with the engine the app
   actually ships. It captures the real extraction JSON for layer 3.

3. **TypeScript report integration** (`app/src/measurement`). Runs the *real*
   production `buildDocumentFromPdf` (Generic plugin), `buildLayout` and
   `paginate` over the captured device extraction. Those modules are pure,
   platform-independent TypeScript with no native branches, so their output is
   identical to what runs in Hermes on-device — this is not a proxy, it is the
   production code over real device inputs. It reduces the result to a
   content-free report.

The split between (2) and (3) is the language boundary: extraction is Swift
(device-specific, hence measured on-device); classification/layout are
deterministic TS (measured by re-running the real code over the real
extraction).

## 2. Unified observability channel

All layers (and production) emit through one Apple `os.Logger` channel,
subsystem `com.scabo.scabopdf` (`app/ios/ScaboNative/ScaboLog.swift`,
`app/src/native/diag.ts`). Two regimes, governed by the privacy contract in
`docs/ARCHITECTURE.md` ("no PII ever; filenames yes, document content never"):

- **events** — content-free metrics + errors (`.notice`/`.error`, persisted →
  visible in Console.app and Settings → Privacy & Security → Analytics on a real
  device, and via `simctl log stream` on the Simulator).
- **snapshots** — heavy JSON that may carry text; a no-op unless test mode
  (`--scabo-test-mode`), and even then written to a file under Caches, never to
  the persisted log.

## 3. Workflow

```sh
# 1. Build + install the app on a booted Simulator (Debug, Metro running).
# 2. Seed the private PDFs into the app container:
app/ios/scripts/seed_fixtures.sh
# 3. Run the on-device extraction measurements:
( cd app/ios && xcodebuild test -workspace ScaboPDF.xcworkspace -scheme ScaboPDF \
    -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' \
    -derivedDataPath build/sim -only-testing:ScaboPDFExtractionTests )
# 4. Pull the captures to the host:
app/ios/scripts/pull_captures.sh
# 5. Generate the content-free reports + (gitignored) full dumps:
( cd app && npx jest measureRealCaptures )
```

Re-seeding/re-pulling is idempotent. With no captures present, the generator
skips (the fresh-clone fixture convention).

## 4. The content-free report schema (v1.0)

One report per PDF (`app/src/measurement/report.ts`,
`ContentFreeReport`). Counts, distributions, timings and content-free plugin
warnings only — never segment text.

| Field | Meaning |
| --- | --- |
| `reportSchemaVersion` | Report schema version (independent of the Layer-1 schema). |
| `pdfFilename`, `pdfSizeBytes` | Source PDF name (allowed) and byte size. |
| `extraction.pages`, `.lines` | Pages and non-empty text lines from PDFKit. |
| `extraction.fontSizeHistogram` | Line count per dominant font size (0.5pt buckets). |
| `extraction.boldLineRatio` | Fraction of predominantly-bold lines. |
| `extraction.payloadBytes` | Size of the raw extraction JSON. |
| `document.profileId` | Winning plugin (`generic` until corpus plugins land). |
| `document.nodeTotal` | Total nodes built. |
| `document.roleCounts` | Node count per `SemanticCategory` (HEADING_n/BODY/NOTE/…). |
| `document.noteLengthCounts` | NOTE count per `length_category` (MICRO..MEGA). |
| `document.warnings` | Content-free plugin warnings (`plugin:generic:…`). |
| `layout.layoutId`, `.segmentTotal`, `.pagesProduced` | Layout + pagination outcome. |
| `timings.extractMs` | Swift/PDFKit extraction (on-device). |
| `timings.pluginMs`, `.layoutMs`, `.paginateMs` | TS pipeline stages. |

Synthetic example (from `__fixtures__/example.capture.json`):

```json
{
  "reportSchemaVersion": "1.0",
  "pdfFilename": "synthetic-example.pdf",
  "pdfSizeBytes": 1024,
  "extraction": {
    "pages": 1, "lines": 4,
    "fontSizeHistogram": { "8.0": 1, "10.0": 2, "16.0": 1 },
    "boldLineRatio": 0.25, "payloadBytes": 421
  },
  "document": {
    "profileId": "generic", "nodeTotal": 3,
    "roleCounts": { "HEADING_1": 1, "BODY": 1, "NOTE": 1 },
    "noteLengthCounts": { "SHORT": 1 },
    "warnings": ["plugin:generic:heuristic_extraction_pages_1_nodes_3"]
  },
  "layout": { "layoutId": "continuous", "segmentTotal": 3, "pagesProduced": 1 },
  "timings": { "extractMs": 12, "pluginMs": 0, "layoutMs": 0, "paginateMs": 0 }
}
```

(`timings` are machine-dependent; `pluginMs`/`layoutMs`/`paginateMs` are
sub-millisecond on the trivial synthetic input.)

## 5. What is committed vs local

- **Committed**: the framework code (targets, scripts, `report.ts`, the
  deterministic synthetic unit test, this doc, the report schema). Content-free
  baseline reports are committed in a future session, once the Generic output on
  the 7 PDFs is reviewed and stable (the current output has known heuristic
  gaps — see the session report and `docs/ARCHITECTURE.md` debts).
- **Gitignored** (`test-output-private/`): the extraction captures, the
  text-bearing dumps, and the per-PDF reports generated locally. These derive
  from copyright-protected PDFs and inherit the same treatment as the fixtures
  themselves (`*.pdf` is gitignored).

## 6. Measured impact of the per-span enrichment (2026-05-31)

The bridge was enriched from per-line `{text, fontSize, bold}` to per-span
`{text, fontSize, bold, italic, color, bbox}` + page geometry, and the Generic
became multi-signal (size + colour + geometry). Content-free deltas on the 7
fixtures (role counts; pre = size-only, post = multi-signal):

| Fixture (corpus) | key delta |
| --- | --- |
| Dir. proc. civ. Vol. IV (Giappichelli) | **D1 closed**: HEADING_3 7694 → 16; NOTE 4 → 915 (real MICRO..MEGA spread). The body size is no longer mistaken for the note size. |
| Manuale dir. privato (Torrente) | **D2 closed**: HEADING_2 1560 → 0 — the per-page `[§ N]` running header and the `© Giuffrè` watermark are dropped as furniture. |
| Manuale del Marrone (BIC) | **D4 unblocked**: 486 colour-driven headings now seen (green/indigo/maroon) vs the old 554 spurious-by-size + 0 colour; the 670 MICRO "notes" were invisible 1pt white anchors, now removed. Exact level mapping still needs a corpus plugin. |
| Compendio tributario (Tesauro) | **D3 de-noised**: NOTE 544 → 63 — the 481 dropped were ALL MICRO artifacts (page numbers); the 63 real MED/LONG/VL/MEGA notes are preserved. |
| Dir. internazionale (Mosconi) | NOTE 1325 → 1200 (112 MICRO artifacts removed; real notes preserved). |
| Corso proc. civ. I & II (Mandrioli) | unchanged (already clean Photoshop pipeline) — no regression. |

Debt status: **D1 closed**, **D2 closed**, **D3 substantially de-noised**,
**D4 physically unblocked** (colour visible + used; precise level mapping is
corpus-plugin work), **D6** signals available and used internally (surfacing
inline emphasis to VoiceOver is a deferred accessibility decision). Remaining
Generic limits: colour-heading level mapping on fully colour-coded corpora
(Marrone), and under-detection of real headings on corpora whose heads are not
size/colour-distinct (Torrente) — both are by design the job of corpus plugins,
which the enriched bridge now enables.
