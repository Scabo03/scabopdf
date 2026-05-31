/**
 * Layer 2 — Generic plugin category taxonomy contract.
 *
 * This module is the single, explicit, *closed* declaration of which semantic
 * categories the corpus-agnostic Generic plugin (`./generic.ts`) handles, and
 * — for each — the discriminating signal it uses today (post commit 3a811f8,
 * the multi-signal `size + colour + geometry + furniture` rewrite).
 *
 * The category names are the SemanticCategory strings of the Layer 1 contract
 * (`shared/schema.json` $defs.SemanticCategory, mirrored in TypeScript by
 * `consumption/schema.generated.ts`). Layer 1 is the source of truth: Layer 2's
 * taxonomy is a *nominal subset* of that enum, never a divergent renaming. The
 * `GENERIC_TAXONOMY` map below is typed `Record<SemanticCategory, …>`, so the
 * TypeScript compiler refuses any key that is not a Layer 1 category and forces
 * every Layer 1 category to be classified exactly once. The accompanying
 * `__tests__/taxonomy.test.ts` pins the same invariants against the runtime
 * enum read from the committed schema, so a future Layer 1 enum change that is
 * not reflected here fails the suite rather than drifting silently.
 *
 * Three coverage buckets, deliberately distinct (the brief asks to separate
 * "what the Generic classifies now" from "what is reserved for corpus plugins"):
 *
 *   - `produced`            — the Generic emits a node of this category today.
 *   - `detected-suppressed` — the Generic *recognises* lines of this kind as a
 *                             signal but emits NO node for them (it drops page
 *                             furniture and invisible anchors). The mapping to a
 *                             Layer 1 category is conceptual: the Generic does
 *                             not tag the dropped lines, it simply removes them.
 *   - `reserved`            — never touched by the Generic; only a corpus-
 *                             specific plugin (ARTICLE_HEADER/PROCEDURAL/…) or a
 *                             non-PDF backend (AMENDMENT/QUOTED_TEXT_OLD/NEW/…)
 *                             emits it. The `rationale` says why it is out of reach of
 *                             a corpus-agnostic heuristic.
 *
 * No new signals are invented here: every `signals` entry maps to a mechanism
 * that already exists in `generic.ts`. Where the Generic does not cover a
 * category, it is marked `reserved` with a one-line reason.
 */

import type { SemanticCategory } from '../consumption';

/**
 * The discriminating mechanisms the Generic uses, each tied to concrete code in
 * `generic.ts`. A category's `signals` lists which of these determine it.
 */
export type GenericSignal =
  /** Size ratio (line size / estimated body size) — `classify()` ratio buckets
   *  HEADING_1_RATIO 1.5, HEADING_2_RATIO 1.25, HEADING_3_RATIO 1.12,
   *  HEADING_4_BOLD_RATIO 1.04, NOTE_RATIO 0.85; body size from
   *  `estimateProfile()`. */
  | 'size-band'
  /** Saturated, body-distinct colour (`isSaturated`, `colorDistance`,
   *  COLOR_DISTANCE_MIN 100, COLOR_SATURATION_MIN 40) — debt D4; also
   *  `isNearWhite` for invisible-anchor suppression. */
  | 'colour'
  /** Page geometry — short-line cap (HEADING_MAX_CHARS 120, FURNITURE_MAX_CHARS
   *  60) and top/bottom page bands (TOP_BAND 0.9, BOTTOM_BAND 0.1). */
  | 'geometry'
  /** Bold weight flag on the line (`line.bold`) — promotes a slightly-larger
   *  short line to HEADING_4. */
  | 'font-weight'
  /** Cross-page recurrence (`detectFurniture`) — a normalised line recurring in
   *  the same band / colour / anywhere across many pages is furniture (debt D2). */
  | 'recurrence'
  /** Merged-text length → MICRO…MEGA acoustic regime (`lengthCategoryFor`,
   *  LENGTH_THRESHOLDS). Not a *classifying* signal; it annotates NOTE nodes. */
  | 'text-length';

/** How the Generic relates to a given Layer 1 category. */
export type GenericCoverage = 'produced' | 'detected-suppressed' | 'reserved';

/** The per-category contract entry. */
export interface GenericCategoryContract {
  /** The Layer 1 SemanticCategory (the key is the same string). */
  readonly category: SemanticCategory;
  /** Whether the Generic produces it, detects-and-drops it, or reserves it. */
  readonly coverage: GenericCoverage;
  /** The signals that determine it. Empty for `reserved`. */
  readonly signals: readonly GenericSignal[];
  /** The discriminating signal in prose, or the reason it is reserved. */
  readonly rationale: string;
}

/**
 * The complete, exhaustive map from every Layer 1 category to its Generic
 * coverage. Typed `Record<SemanticCategory, …>`: the compiler enforces that the
 * keys are exactly the Layer 1 enum — no missing category, no invented name.
 */
export const GENERIC_TAXONOMY: Record<
  SemanticCategory,
  GenericCategoryContract
> = {
  // ── Produced by the Generic today ──────────────────────────────────────────
  HEADING_1: {
    category: 'HEADING_1',
    coverage: 'produced',
    signals: ['size-band', 'geometry', 'colour'],
    rationale:
      'Short line (≤120 chars) whose size ratio to body is ≥1.5 (HEADING_1_RATIO); or a saturated, body-distinct colour heading (colorDistance>100, saturation>40) sized ≥1.25 of body. classify() → {HEADING, level:1}.',
  },
  HEADING_2: {
    category: 'HEADING_2',
    coverage: 'produced',
    signals: ['size-band', 'geometry', 'colour'],
    rationale:
      'Short line with size ratio ≥1.25 (HEADING_2_RATIO); or a colour heading sized ≥1.12 of body. classify() → {HEADING, level:2}.',
  },
  HEADING_3: {
    category: 'HEADING_3',
    coverage: 'produced',
    signals: ['size-band', 'geometry', 'colour'],
    rationale:
      'Short line with size ratio ≥1.12 (HEADING_3_RATIO); or the catch-all level for a colour heading that clears COLOR_HEADING_MIN_RATIO but not the larger bands. classify() → {HEADING, level:3}.',
  },
  HEADING_4: {
    category: 'HEADING_4',
    coverage: 'produced',
    signals: ['size-band', 'geometry', 'font-weight'],
    rationale:
      'Short, BOLD line only slightly larger than body, ratio ≥1.04 (HEADING_4_BOLD_RATIO and line.bold). classify() → {HEADING, level:4}.',
  },
  BODY: {
    category: 'BODY',
    coverage: 'produced',
    signals: ['size-band'],
    rationale:
      'Default class: size ratio between NOTE_RATIO (0.85) and the heading bands, or no font information at all (ratio===0). Consecutive BODY lines are merged into one paragraph node by appendPageNodes.',
  },
  NOTE: {
    category: 'NOTE',
    coverage: 'produced',
    signals: ['size-band', 'text-length'],
    rationale:
      'Line clearly smaller than body, size ratio ≤0.85 (NOTE_RATIO). Runs of NOTE lines merge into one node; length_category (MICRO…MEGA) is computed from the merged text length (lengthCategoryFor).',
  },

  // ── Detected by the Generic but emitted as NO node (furniture / anchors) ─────
  ARTIFACT_RUNNING_HEADER: {
    category: 'ARTIFACT_RUNNING_HEADER',
    coverage: 'detected-suppressed',
    signals: ['recurrence', 'geometry'],
    rationale:
      'detectFurniture: a short line (≤60 chars) in the TOP page band (yFrac ≥0.9) whose digit-normalised text recurs across ≥15% of pages. Dropped so it cannot read as a false heading (debt D2). Not tagged — the mapping is conceptual.',
  },
  ARTIFACT_FOOTER: {
    category: 'ARTIFACT_FOOTER',
    coverage: 'detected-suppressed',
    signals: ['recurrence', 'geometry'],
    rationale:
      'detectFurniture: same recurrence in the BOTTOM page band (yFrac ≤0.1). Dropped, not tagged.',
  },
  ARTIFACT_FILIGREE: {
    category: 'ARTIFACT_FILIGREE',
    coverage: 'detected-suppressed',
    signals: ['recurrence', 'colour'],
    rationale:
      'detectFurniture: a normalised line recurring on a MAJORITY (≥50%) of pages anywhere (watermark/copyright), or a saturated per-page colour marker recurring ≥15% of pages. Dropped, not tagged.',
  },
  BOOK_PAGE_ANCHOR: {
    category: 'BOOK_PAGE_ANCHOR',
    coverage: 'detected-suppressed',
    signals: ['colour'],
    rationale:
      'Near-white invisible text (every RGB channel >230, isNearWhite) and saturated per-page colour markers are skipped in appendPageNodes. Dropped, never emitted as a node.',
  },

  // ── Reserved for corpus-specific plugins / non-PDF backends ──────────────────
  ARTICLE_HEADER: {
    category: 'ARTICLE_HEADER',
    coverage: 'reserved',
    signals: [],
    rationale:
      'Legal-codes structure. Requires a giuffre_codici-class plugin (banner-glyph code-type + bold article-number triggers). The Generic has no notion of articles.',
  },
  ARTICLE_BODY: {
    category: 'ARTICLE_BODY',
    coverage: 'reserved',
    signals: [],
    rationale:
      'Per-comma body of a legal article; minted alongside ARTICLE_HEADER by the legal-codes / AKN backends only.',
  },
  PROCEDURAL: {
    category: 'PROCEDURAL',
    coverage: 'reserved',
    signals: [],
    rationale:
      'Procedural sub-block of a code (penale c.p.p.). Corpus-specific sub-parser; the Generic does not recognise it.',
  },
  BODY_CONTINUATION: {
    category: 'BODY_CONTINUATION',
    coverage: 'reserved',
    signals: [],
    rationale:
      'The Generic merges consecutive body lines into a single BODY node; it has no cross-page paragraph-continuation model to mint a continuation node.',
  },
  NOTE_CONTINUATION: {
    category: 'NOTE_CONTINUATION',
    coverage: 'reserved',
    signals: [],
    rationale:
      'The Generic merges note runs into a single NOTE node; it has no cross-page note-continuation model.',
  },
  MARGINAL_HEADING: {
    category: 'MARGINAL_HEADING',
    coverage: 'reserved',
    signals: [],
    rationale:
      'Marginal apparatus keyed on corpus-specific font + margin geometry (e.g. Mandrioli Vol. I/II). Outside the Generic signal set.',
  },
  MARGINAL_GLOSS: {
    category: 'MARGINAL_GLOSS',
    coverage: 'reserved',
    signals: [],
    rationale:
      'Margin gloss keyed on a corpus-specific font + bbox.x0 guard; corpus-specific.',
  },
  EXAMPLE_BOX: {
    category: 'EXAMPLE_BOX',
    coverage: 'reserved',
    signals: [],
    rationale:
      'Boxed worked example; needs a corpus-specific layout signal the Generic does not measure.',
  },
  CHAPTER_SUMMARY: {
    category: 'CHAPTER_SUMMARY',
    coverage: 'reserved',
    signals: [],
    rationale:
      'Editorial chapter summary with a corpus-specific signature (e.g. small-caps SOMMARIO label). Corpus-specific.',
  },
  TOC_GENERAL: {
    category: 'TOC_GENERAL',
    coverage: 'reserved',
    signals: [],
    rationale:
      'Table of contents; recognised via a Sommario header + dotted-leader entry pattern (materiali_studio pattern eeee), not by the Generic.',
  },
  INDEX_ENTRY: {
    category: 'INDEX_ENTRY',
    coverage: 'reserved',
    signals: [],
    rationale:
      'Back-matter analytic index entry; corpus-specific (often double-column).',
  },
  EDITORIAL_NOTE: {
    category: 'EDITORIAL_NOTE',
    coverage: 'reserved',
    signals: [],
    rationale:
      'Editorial (*) note; minted by the DeJure-family / AKN backends. The Generic only emits plain NOTE.',
  },
  MASSIMA_LABEL: {
    category: 'MASSIMA_LABEL',
    coverage: 'reserved',
    signals: [],
    rationale:
      'DeJure Massime label marker; recognised only by dejure_massime.',
  },
  REFERRAL: {
    category: 'REFERRAL',
    coverage: 'reserved',
    signals: [],
    rationale:
      'DeJure referral line, discriminated structurally by reading-order position after a label. DeJure-family only.',
  },
  TITLE: {
    category: 'TITLE',
    coverage: 'reserved',
    signals: [],
    rationale:
      'Document/article title in the DeJure & EdD pipelines; the Generic treats a large short line as a HEADING, not a TITLE.',
  },
  FONTE_LABEL: {
    category: 'FONTE_LABEL',
    coverage: 'reserved',
    signals: [],
    rationale: 'DeJure "Fonte:" label marker; DeJure-family only.',
  },
  FONTE_VALUE: {
    category: 'FONTE_VALUE',
    coverage: 'reserved',
    signals: [],
    rationale:
      'DeJure source value (size-discriminated from body after a FONTE_LABEL); DeJure-family only.',
  },
  META_LABEL: {
    category: 'META_LABEL',
    coverage: 'reserved',
    signals: [],
    rationale: 'DeJure metadata label; DeJure-family only.',
  },
  META_VALUE: {
    category: 'META_VALUE',
    coverage: 'reserved',
    signals: [],
    rationale:
      'DeJure metadata value (umbrella, later decomposed); DeJure-family only.',
  },
  AUTHORS: {
    category: 'AUTHORS',
    coverage: 'reserved',
    signals: [],
    rationale:
      'DeJure "Autori:" value (incl. multi-author / bilingual); DeJure-family only.',
  },
  SECTION_LABEL: {
    category: 'SECTION_LABEL',
    coverage: 'reserved',
    signals: [],
    rationale:
      'Structural label such as "Note:" that anchors a notes section; minted by the DeJure / EdD plugins.',
  },
  GENRE_BANNER: {
    category: 'GENRE_BANNER',
    coverage: 'reserved',
    signals: [],
    rationale:
      'Editorial banner ("DOTTRINA", "NOTE E DOTTRINA"); DeJure-family discriminator, not a Generic concept.',
  },
  SUBTITLE: {
    category: 'SUBTITLE',
    coverage: 'reserved',
    signals: [],
    rationale:
      'Editorial subtitle line (e.g. DeJure NS "Quotidiano del …"); DeJure-family only.',
  },
  HEADING_LETTER_INITIAL: {
    category: 'HEADING_LETTER_INITIAL',
    coverage: 'reserved',
    signals: [],
    rationale:
      'Encyclopedia drop-cap: a single uppercase letter at >30pt opening an alphabetic section. Emitted by the EdD plugins. The Generic would treat a one-letter span as a non-substantial marker and drop it.',
  },
  FONTI: {
    category: 'FONTI',
    coverage: 'reserved',
    signals: [],
    rationale: 'Named "FONTI." bibliographic section; EdD plugins only.',
  },
  LETTERATURA: {
    category: 'LETTERATURA',
    coverage: 'reserved',
    signals: [],
    rationale: 'Named "LETTERATURA." bibliographic section; EdD plugins only.',
  },
  AMENDMENT: {
    category: 'AMENDMENT',
    coverage: 'reserved',
    signals: [],
    rationale:
      'AKN legislative modification; produced exclusively by the XML AKN / EPUB IPZS backends, never by the PDF Generic plugin.',
  },
  QUOTED_TEXT_OLD: {
    category: 'QUOTED_TEXT_OLD',
    coverage: 'reserved',
    signals: [],
    rationale: 'AKN previgent (old) quoted text; AKN/EPUB backends only.',
  },
  QUOTED_TEXT_NEW: {
    category: 'QUOTED_TEXT_NEW',
    coverage: 'reserved',
    signals: [],
    rationale: 'AKN new quoted text; AKN/EPUB backends only.',
  },
  UPDATE_BLOCK: {
    category: 'UPDATE_BLOCK',
    coverage: 'reserved',
    signals: [],
    rationale:
      'AKN structured modification record (active/passive); AKN/EPUB backends only.',
  },
  CROSS_REFERENCE: {
    category: 'CROSS_REFERENCE',
    coverage: 'reserved',
    signals: [],
    rationale:
      'Inline reference marker minted as a synthetic node by corpus plugins / the apparatus resolver. The Generic does not mint synthetic reference nodes.',
  },
  LIST_ITEM: {
    category: 'LIST_ITEM',
    coverage: 'reserved',
    signals: [],
    rationale:
      'List item keyed on geometric indentation / bullet glyph (materiali_studio). The Generic folds such lines into BODY.',
  },
  ARTIFACT_STAMP: {
    category: 'ARTIFACT_STAMP',
    coverage: 'reserved',
    signals: [],
    rationale:
      'Copyright / frontispiece stamp identified by a corpus-specific text regex. The Generic only drops *recurring* furniture, not a one-off stamp by signature.',
  },
  ARTIFACT_PAGE_HEADER: {
    category: 'ARTIFACT_PAGE_HEADER',
    coverage: 'reserved',
    signals: [],
    rationale:
      'A distinct page-header artifact category; the Generic only models running-header furniture (ARTIFACT_RUNNING_HEADER).',
  },
  EMPTY_PAGE: {
    category: 'EMPTY_PAGE',
    coverage: 'reserved',
    signals: [],
    rationale:
      'The Generic emits no node for a page with no content; it never tags an EMPTY_PAGE node.',
  },
  UNCLASSIFIED: {
    category: 'UNCLASSIFIED',
    coverage: 'reserved',
    signals: [],
    rationale:
      'The Generic always commits a line to BODY / NOTE / HEADING; it never emits the fallback category.',
  },
};

/** All entries as an array, in declaration order. */
export const GENERIC_TAXONOMY_ENTRIES: readonly GenericCategoryContract[] =
  Object.values(GENERIC_TAXONOMY);

function categoriesWithCoverage(
  coverage: GenericCoverage,
): ReadonlySet<SemanticCategory> {
  return new Set(
    GENERIC_TAXONOMY_ENTRIES.filter(e => e.coverage === coverage).map(
      e => e.category,
    ),
  );
}

/** Categories the Generic plugin emits as nodes today. */
export const GENERIC_PRODUCED_CATEGORIES: ReadonlySet<SemanticCategory> =
  categoriesWithCoverage('produced');

/** Categories the Generic recognises as a signal but drops (emits no node). */
export const GENERIC_DETECTED_SUPPRESSED_CATEGORIES: ReadonlySet<SemanticCategory> =
  categoriesWithCoverage('detected-suppressed');

/** Categories reserved for corpus-specific plugins / non-PDF backends. */
export const GENERIC_RESERVED_CATEGORIES: ReadonlySet<SemanticCategory> =
  categoriesWithCoverage('reserved');

/** True iff the Generic plugin can emit a node of this category. */
export function isGenericProduced(category: SemanticCategory): boolean {
  return GENERIC_PRODUCED_CATEGORIES.has(category);
}

/**
 * Layer-2 presentation roles that are NOT Layer 1 SemanticCategory values.
 *
 * `SECTION_DIVIDER` is minted in `rendering/buildSegments.ts` (via
 * `roleStyle.SECTION_DIVIDER_ROLE`) for the synthetic HEADING_1 containers the
 * XML AKN / EPUB backends produce, so they do not read as ordinary chapter
 * headings. It is an *addition* on the presentation `role` axis, never a
 * rename of a Layer 1 category, and the Generic plugin never emits it. The
 * native ReadingView consumes `ContentSegment.role` as an opaque string, so
 * this presentation role flows through without changing the binary contract.
 */
export const LAYER2_PRESENTATION_ONLY_ROLES = ['SECTION_DIVIDER'] as const;
