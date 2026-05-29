# Layer 2 — Edge cases from real Layer 1 baselines

> Running log of edge cases observed while exercising the Layer 2 consumption
> and rendering layers against the real Layer 1 baselines under
> `pipeline/tests/snapshots/`. Each entry is a candidate for a focused polish
> session; nothing here blocks the current phase.
>
> First entry: 2026-05-29 (end of Fase 5 — rendering layouts v1).

---

## (1) Schema 0.7.0 modification categories surface in the wild

The XML AKN baseline `legge_capitali` emits AMENDMENT (80), QUOTED_TEXT_NEW
(56), QUOTED_TEXT_OLD (32) and UPDATE_BLOCK (161) — these are the categories
introduced by pattern (bbbb) of CLAUDE.md and are the bulk of the document.
The native reading view's role-to-font switch in
`ScaboReadingContentView.swift` does not yet style them; they fall through to
the body font. Acoustic treatment is also unspecified in SPECS/ARCHITECTURE.

**To resolve:** decide visual + acoustic distinction for these roles. A
likely sketch:

- AMENDMENT: a distinct color + brief intro tone ("modifica") before reading.
- QUOTED_TEXT_OLD / QUOTED_TEXT_NEW: italic + explicit "old version" /
  "new version" prefixes so the user knows which side they are on.
- UPDATE_BLOCK: muted styling; it lives under the synthetic HEADING_1
  containers below and is rapid-scan content.

## (2) Synthetic HEADING_1 containers from the XML AKN backend

Pattern (ffff) "Decreto di promulgazione" and pattern (bbbb)
"Modificazioni attive a altri atti" / "Modificazioni passive di questo atto"
mint HEADING_1 nodes whose text is a fixed editorial string, not document
text. They contain the actual content as children.

The rendering layer currently treats them like any HEADING_1. That works for
linear reading, but the rotor navigation in Consultazione Rapida will list
these container titles alongside real chapters; Layer 2 may want to mark
them as section-dividers rather than chapter-headings.

## (3) Consultazione Rapida is too lenient on modification-heavy documents

`buildQuickConsultLayout` drops NOTE and EDITORIAL_NOTE only. On
`legge_capitali` that removes 23 segments out of 472 — the AMENDMENT family
(168 segments) still dominates, so QuickConsult barely differs from the
continuous layout on modification-heavy texts. A revisit should let the
QuickConsult layout collapse AMENDMENT and UPDATE_BLOCK details, surfacing
only the article skeleton.

## (4) Dottrina Inline is identical to Continuous in v1

`buildDoctrineInlineLayout` is a deliberate stub: it returns the same stream
as Continuous. SPECS § 4.5 requires sentence-level note placement (move the
note to the end of the sentence containing the cross-reference, group
multi-reference notes) which needs an Italian sentence tokenizer and
cross-reference matching against the source spans. Polish required before
this layout is meaningful for doctrinal essays.

## (5) NOTE distribution skewed toward MEGA on modification corpora

`legge_capitali` has 23 NOTE nodes, of which 15 are MEGA and 7 VERY_LONG.
The dark-vs-light contrast between very short notes and mega-notes is
exactly what motivated the six acoustic regimes. The current
`ScaboReadingContentView` does not yet branch on `lengthCategory`; the
attributed-string speech attributes per regime are a separate polish.

## (6) EPUB IPZS surfaces fewer NOTE / AMENDMENT than the AKN twin

For the same act, the EPUB IPZS backend emits a strictly smaller subset of
the modification categories than the XML AKN backend. On `legge_gelli_bianco`:

- XML AKN: NOTE 8, AMENDMENT 14, UPDATE_BLOCK 14.
- EPUB IPZS: NOTE 0, AMENDMENT 8, UPDATE_BLOCK 3.

This is by design (the EPUB backend mirrors the visible IPZS rendering,
which omits much of the modification apparatus). Layer 2 should not assume
parity between the two backends for the same act when offering "switch
source" UX in the future.

## (7) Pagination heuristic is provisional

`DEFAULT_SEGMENTS_PER_PAGE = 20` is a placeholder. Real values must come
from on-device measurement of `UITextView` line height vs the active
DynamicType setting and viewport size. `legge_capitali` produces 24 pages
under this heuristic; a real handheld viewport will paginate differently.

## (8) Capture-script convention: stripped `document_id`

The Layer-1 capture script omits `document_id` from the committed baselines
(it would otherwise be a random per-run UUID and break byte-for-byte
stability). The Layer 2 fixture loader injects a deterministic placeholder
to satisfy the schema. Anyone touching the loader should preserve this.

## (9) Baseline-only debug fields at top level

The committed baselines add top-level `_baseline_id`, `_baseline_source`
and one of `_baseline_xml_akn_metadata` / `_baseline_epub_ipzs_metadata` /
`_baseline_health_verdict`. They violate the schema's
`additionalProperties: false` and must be stripped before `parseDocument`.
The current loader strips by prefix. If the capture script ever adds a
field without the `_baseline_` prefix, the strip will miss it.
