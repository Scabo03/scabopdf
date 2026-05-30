# Layer 2 — Edge cases from real Layer 1 baselines

> Running log of edge cases observed while exercising the Layer 2 consumption
> and rendering layers against the real Layer 1 baselines under
> `pipeline/tests/snapshots/`. Each entry is a candidate for a focused polish
> session.
>
> **Update 2026-05-30 (structured audit — see `LAYER2_AUDIT_REPORT.md`):** the
> original "nothing here blocks the current phase" no longer holds. The audit
> quantified the impact of these debts across all 24 structure-bearing baselines
> and found entry (1) to be **blocking** for a usable TestFlight build on the
> legal corpus (37.65% of all segments read with no role distinction, up to 90%
> on `dlgs_cartabia`). Re-prioritisations and new entries are appended in the
> "## 2026-05-30 audit revision" section at the foot of this file; the original
> entries below are preserved as written.
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

---

## 2026-05-30 audit revision

Cross-referenced against the full baseline set and the live code by the
five-axis audit (`LAYER2_AUDIT_REPORT.md`). The "six debts" the audit brief
referred to map to entries (1)–(7); (8) and (9) are **informational test-harness
notes, not product debts** — relabel them as such. Re-prioritisations and new
entries follow.

### Re-prioritisation of existing entries

- **(1) → split, P0 / BLOCKING.** Severely understated as a `legge_capitali`
  corner case. Measured corpus-wide: `UPDATE_BLOCK` (20.5% of all segments),
  `LIST_ITEM` (10.6%), `AMENDMENT` (5.4%), `QUOTED_TEXT_OLD/NEW` (1.1%) all hit
  the Swift `font(forRole:)` `default:` body branch — **37.65% of 73,255
  segments**; 13/24 docs ≥30%, `dlgs_cartabia` 90%. Split into **(1a)** generic
  structural roles (`LIST_ITEM`, `UPDATE_BLOCK`) — add to the switch before
  TestFlight; **(1b)** the 0.7.0 modification family (`AMENDMENT`,
  `QUOTED_TEXT_OLD/NEW`) — old/new prefixes + distinct regime. **Blocking.**
- **(2) → P1.** On AKN the editorial hierarchy is flat: `codice_civile` AKN has
  HEADING_1=2 (both synthetic "Modificazioni" containers), 3258 ARTICLE_HEADER,
  zero real chapter headings. A HEADING_1 rotor lists only the two containers.
  Mark synthetic containers with a divider/`isSynthetic` flag; key the rotor on
  ARTICLE_HEADER for AKN codes.
- **(3) → P1.** `buildQuickConsultLayout` drops 0.0% on 16/24 docs (only
  NOTE+EDITORIAL_NOTE). Collapse `UPDATE_BLOCK`/`AMENDMENT`/`QUOTED_TEXT_*` so it
  surfaces the article skeleton. Not a hard blocker (Continuous is default).
- **(4) → P2 (unchanged).** Doctrina==Continuous; affects only doctrinal corpora,
  none in the structure-bearing baseline set.
- **(5) → P1.** `ScaboReadingContentView` never reads `lengthCategory`. NOTE skews
  hard to MEGA/VERY_LONG where present (`dlgs_cartabia` 19 MEGA, `legge_capitali`
  15 MEGA). Interim: spoken "nota lunga / molto lunga" prefix for VERY_LONG/MEGA.
- **(6) → P2 (unchanged, informational).** EPUB emits fewer mods than the AKN twin
  by design.
- **(7) → P1.** `DEFAULT_SEGMENTS_PER_PAGE=20` is content-blind: `codice_civile`
  AKN → 428 pages. Length-weight pages. Degraded but functional.
- **(8) and (9) → Informational (not product debts).** Correct test-loader
  behaviour. (9)'s `_baseline_` prefix-strip is a tiny harness fragility, no more.

### New entries from the audit

- **(10) [P0 / BLOCKING — needs on-device VoiceOver] Native reading view may not
  be the VoiceOver element.** `ScaboReadingContentView` is installed as the
  Fabric `contentView` (layout slot); `RCTViewComponentView.accessibilityElement`
  defaults to the host `self`. If so, `UIAccessibilityReadingContent`,
  `causesPageTurn` and `accessibilityScroll` are all dormant. Verify on device;
  candidate fix `- (NSObject *)accessibilityElement { return _contentView; }`.
  (Axis 2 #1 / Axis 4.)
- **(11) [P0 — design decision] Parent + child double/triple reading.**
  `buildBaseSegments` emits every text-bearing node; AKN AMENDMENT/QUOTED_TEXT
  children repeat the parent's text verbatim, so it is read 2–3× (80/80 AMENDMENT
  on `legge_capitali`). Decide parent-only vs children-only vs distinct-regime.
  (Axis 3 HIGH.)
- **(12) [P1 — needs device] Async page-turn contract race.**
  `accessibilityScroll` returns `true` synchronously while the new page arrives
  later via JS, and posts `.pageScrolled` with `nil` (no announce, no focus).
  Add a `pendingPageTurn` flag consumed in `updatePageContent`, post
  `.screenChanged`, and `return false` at the first/last page. (Axis 2 #3,#5.)
- **(13) [P1 — accessibility] Dynamic Type not honored.** `font(forRole:)` uses
  `.preferredFont(...).withSize(...)`, discarding content-size scaling; no
  `UIFontMetrics`, no trait observer. Reading body pinned at 18pt. (Axis 4 ALTO.)
- **(14) [P1 — UX] Reader is a navigation dead-end.** No Back/Close control once
  a document is open; no spoken open-success confirmation; page-of-total never
  voiced though `pageNumber` is plumbed. (Axis 4 ALTO.)
- **(15) [P2 — latent, HIGH on first PDF corpus] No artifact/anchor filtering.**
  `buildBaseSegments` would voice `ARTIFACT_*`, `BOOK_PAGE_ANCHOR`,
  `CROSS_REFERENCE`, `UNCLASSIFIED`. Invisible on XML/EPUB (zero artifacts) but
  the 13 PDF plugins emit thousands (Marrone: 693 footers, 1473 anchors, 1489
  cross-refs). Add a skip-set mirroring `quickConsult`'s `COLLAPSED_ROLES`. (Axis 3.)
- **(16) [P2] `LIST_ITEM` has no list semantics anywhere** (10.6% of all
  segments, 17/24 docs). Falls through to body font and carries no "elemento N" /
  indentation affordance — losing statutory enumeration structure. (Axis 5 N1.)
- **(17) [P3] Synthetic-container child cardinality is large/unbounded** —
  `legge_capitali` "Modificazioni attive" holds 139 children; `codice_civile` AKN
  containers aggregate 1812 UPDATE_BLOCK. Under fixed pagination a container
  spans 70+ pages with no intra-container landmark. (Axis 5 N2.)

### Resolved this session

- The latent `walkTree` stack-overflow crash (was a robustness debt) is **fixed**
  (iterative traversal + regression test).
- The silent busy state on open (was an accessibility debt) is **fixed**
  (VoiceOver announcement).
- The native-boundary / defensive-branch **test-coverage gaps are largely closed**
  (+11 tests). The App.tsx integration suite remains open debt.
