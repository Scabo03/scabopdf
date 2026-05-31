# Layer 2 — Generic plugin category taxonomy

This document is the human-facing companion of the machine-checked contract in
`app/src/plugins/taxonomy.ts`. It records which semantic categories the
corpus-agnostic **Generic** plugin handles on Layer 2 (the iOS app), the signal
that determines each one, and how the whole set maps onto the Layer 1
`SemanticCategory` enum.

## Source of truth and discipline

Layer 1 owns the category vocabulary. The canonical enum is
`pipeline/src/scabopdf_pipeline/schema/categories.py`
(`SemanticCategory`), frozen into the contract at
`pipeline/src/scabopdf_pipeline/schema/contract.py` and emitted to
`shared/schema.json` (`$defs.SemanticCategory.enum`, 46 values). The TypeScript
mirror is `app/src/consumption/schema.generated.ts` (the `SemanticCategory`
union) with a runtime copy of the schema at `app/src/consumption/schema.json`.

Layer 2's taxonomy is a **nominal subset** of that enum — never a divergent
renaming. Three guard-rails enforce this:

1. `GENERIC_TAXONOMY` is typed `Record<SemanticCategory, …>`, so the TypeScript
   compiler rejects any key that is not a Layer 1 category and forces every
   Layer 1 category to be classified exactly once.
2. `app/src/plugins/__tests__/taxonomy.test.ts` reads the enum at runtime from
   `consumption/schema.json` and asserts the taxonomy keys are exactly that set
   (name alignment + exhaustiveness), that the coverage buckets partition the
   enum, and — behaviourally — that `genericPlugin.build` only ever emits
   categories marked `produced`.
3. The Generic plugin (`app/src/plugins/generic.ts`) carries a pointer back to
   the taxonomy so the producing code and its contract stay in step.

If Layer 1 ever changes the enum, the test fails until the taxonomy is updated —
the drift cannot be silent. **Layer 2 must never invent a category Layer 1 does
not have**: that would change the inter-layer contract and is the one situation
that requires escalating to a schema change rather than editing this file.

## Coverage buckets

- **produced** — the Generic emits a node of this category today.
- **detected-suppressed** — the Generic _recognises_ lines of this kind as a
  signal but emits **no node** (it drops page furniture and invisible anchors).
  The Layer 1 mapping is conceptual: the dropped lines are not tagged, just
  removed.
- **reserved** — never touched by the Generic; only a corpus-specific plugin or
  a non-PDF backend (XML AKN / EPUB IPZS) emits it.

The signal names below map one-to-one to mechanisms in `generic.ts`: `size-band`
(the `classify()` ratio buckets against the `estimateProfile()` body size),
`colour` (`isSaturated` / `colorDistance` / `isNearWhite`, debt D4), `geometry`
(short-line caps and the top/bottom page bands), `font-weight` (`line.bold`),
`recurrence` (`detectFurniture`, debt D2), and `text-length` (the MICRO…MEGA
acoustic regime annotated onto NOTE nodes).

## Taxonomy table

| Category                  | Signal(s)                        | Covered by Generic?                         | Layer 1 enum |
| ------------------------- | -------------------------------- | ------------------------------------------- | ------------ |
| `HEADING_1`               | size-band, geometry, colour      | ✅ produced                                 | ✅           |
| `HEADING_2`               | size-band, geometry, colour      | ✅ produced                                 | ✅           |
| `HEADING_3`               | size-band, geometry, colour      | ✅ produced                                 | ✅           |
| `HEADING_4`               | size-band, geometry, font-weight | ✅ produced                                 | ✅           |
| `BODY`                    | size-band                        | ✅ produced                                 | ✅           |
| `NOTE`                    | size-band, text-length           | ✅ produced                                 | ✅           |
| `ARTIFACT_RUNNING_HEADER` | recurrence, geometry             | ⚠️ detected, suppressed                     | ✅           |
| `ARTIFACT_FOOTER`         | recurrence, geometry             | ⚠️ detected, suppressed                     | ✅           |
| `ARTIFACT_FILIGREE`       | recurrence, colour               | ⚠️ detected, suppressed                     | ✅           |
| `BOOK_PAGE_ANCHOR`        | colour                           | ⚠️ detected, suppressed                     | ✅           |
| `ARTICLE_HEADER`          | —                                | ❌ reserved (legal-codes plugin)            | ✅           |
| `ARTICLE_BODY`            | —                                | ❌ reserved (legal-codes / AKN)             | ✅           |
| `PROCEDURAL`              | —                                | ❌ reserved (codici sub-parser)             | ✅           |
| `BODY_CONTINUATION`       | —                                | ❌ reserved (no cross-page paragraph model) | ✅           |
| `NOTE_CONTINUATION`       | —                                | ❌ reserved (no cross-page note model)      | ✅           |
| `MARGINAL_HEADING`        | —                                | ❌ reserved (corpus marginal apparatus)     | ✅           |
| `MARGINAL_GLOSS`          | —                                | ❌ reserved (corpus marginal apparatus)     | ✅           |
| `EXAMPLE_BOX`             | —                                | ❌ reserved (corpus layout signal)          | ✅           |
| `CHAPTER_SUMMARY`         | —                                | ❌ reserved (corpus signature)              | ✅           |
| `TOC_GENERAL`             | —                                | ❌ reserved (Sommario / dotted-leader)      | ✅           |
| `INDEX_ENTRY`             | —                                | ❌ reserved (back-matter index)             | ✅           |
| `EDITORIAL_NOTE`          | —                                | ❌ reserved (DeJure / AKN)                  | ✅           |
| `MASSIMA_LABEL`           | —                                | ❌ reserved (DeJure Massime)                | ✅           |
| `REFERRAL`                | —                                | ❌ reserved (DeJure)                        | ✅           |
| `TITLE`                   | —                                | ❌ reserved (DeJure / EdD)                  | ✅           |
| `FONTE_LABEL`             | —                                | ❌ reserved (DeJure)                        | ✅           |
| `FONTE_VALUE`             | —                                | ❌ reserved (DeJure)                        | ✅           |
| `META_LABEL`              | —                                | ❌ reserved (DeJure)                        | ✅           |
| `META_VALUE`              | —                                | ❌ reserved (DeJure)                        | ✅           |
| `AUTHORS`                 | —                                | ❌ reserved (DeJure)                        | ✅           |
| `SECTION_LABEL`           | —                                | ❌ reserved (DeJure / EdD)                  | ✅           |
| `GENRE_BANNER`            | —                                | ❌ reserved (DeJure)                        | ✅           |
| `SUBTITLE`                | —                                | ❌ reserved (DeJure)                        | ✅           |
| `HEADING_LETTER_INITIAL`  | —                                | ❌ reserved (EdD drop-cap)                  | ✅           |
| `FONTI`                   | —                                | ❌ reserved (EdD)                           | ✅           |
| `LETTERATURA`             | —                                | ❌ reserved (EdD)                           | ✅           |
| `AMENDMENT`               | —                                | ❌ reserved (XML AKN / EPUB)                | ✅           |
| `QUOTED_TEXT_OLD`         | —                                | ❌ reserved (XML AKN / EPUB)                | ✅           |
| `QUOTED_TEXT_NEW`         | —                                | ❌ reserved (XML AKN / EPUB)                | ✅           |
| `UPDATE_BLOCK`            | —                                | ❌ reserved (XML AKN / EPUB)                | ✅           |
| `CROSS_REFERENCE`         | —                                | ❌ reserved (corpus / apparatus minting)    | ✅           |
| `LIST_ITEM`               | —                                | ❌ reserved (geometric indentation)         | ✅           |
| `ARTIFACT_STAMP`          | —                                | ❌ reserved (one-off stamp by signature)    | ✅           |
| `ARTIFACT_PAGE_HEADER`    | —                                | ❌ reserved (distinct page-header artifact) | ✅           |
| `EMPTY_PAGE`              | —                                | ❌ reserved (no node emitted)               | ✅           |
| `UNCLASSIFIED`            | —                                | ❌ reserved (Generic always commits)        | ✅           |

Every row's `category` name **is** a Layer 1 enum value — the last column is ✅
for all 46. The full prose rationale for each row lives next to the entry in
`app/src/plugins/taxonomy.ts`.

## Layer-2 presentation-only roles

One role on the rendering `role` axis is **not** a Layer 1 category:

| Role              | Where minted                                                      | Why                                                                                                                                                                                                                      |
| ----------------- | ----------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `SECTION_DIVIDER` | `rendering/buildSegments.ts` via `roleStyle.SECTION_DIVIDER_ROLE` | The synthetic HEADING_1 containers the XML AKN / EPUB backends produce ("Decreto di promulgazione", "Modificazioni attive/passive", "Aggiornamenti…") are reclassified so they do not read as ordinary chapter headings. |

This is an **addition** on the presentation axis, never a rename of a Layer 1
category, and the Generic plugin never emits it. `ContentSegment.role` is an
opaque string consumed by the native ReadingView, so this presentation role
flows through without changing the binary contract the Swift side reads. It is
declared in `LAYER2_PRESENTATION_ONLY_ROLES` and the test asserts it is not a
Layer 1 enum member.
