/**
 * Structural comparison framework — Generic (Layer 2) vs Layer 1 baseline.
 *
 * WHAT THIS COMPARES, AND WHY IT IS NOT BYTE-FOR-BYTE.
 *
 * The Generic plugin runs over an on-device PDFKit extraction; the Layer 1
 * baselines in pipeline/tests/snapshots/ are produced by PyMuPDF + the
 * corpus-specific Python profiles. The two extractors do not see identical spans
 * (colour, bbox and size drift by small amounts), so a byte-for-byte comparison
 * is impossible by construction and is never attempted. Layer 1 protects its own
 * output with byte-for-byte baselines internally; THIS comparison is a different
 * thing — structural and semantic. For each category of the closed Generic
 * taxonomy (plugins/taxonomy.ts) it counts the nodes the Generic produces versus
 * the nodes the Layer 1 baseline records, and reports the absolute and relative
 * delta plus a few tree-topology metrics.
 *
 * The category NAMES are shared verbatim with Layer 1 (the taxonomy guarantees
 * nominal alignment), so no remap table is invented here: a SemanticCategory key
 * means the same thing on both sides. The taxonomy's coverage buckets decide
 * what is even comparable: only the `produced` categories (HEADING_1..4, BODY,
 * NOTE) are the Generic's responsibility, so only those carry an EXACT/CLOSE/
 * DIVERGENT verdict. `detected-suppressed` (furniture/anchors the Generic drops
 * on purpose) and `reserved` (corpus-plugin-only) categories are reported with
 * their counts for context but banded NOT_COMPARABLE — the Generic emitting zero
 * of them is correct behaviour, not a defect.
 *
 * CONTENT-FREE. Like the Layer 1 baselines and the Layer 2 ContentFreeReport,
 * the comparison report carries only category names, counts and numeric deltas —
 * never the text of a document (the fixtures are copyright-protected). The
 * fixture slug (filename-derived) and the corpus id are allowed; document text
 * is not present anywhere in the output.
 *
 * This module is pure (no filesystem): it consumes an already-parsed capture and
 * an already-parsed baseline count map. The filesystem glue (locating captures
 * under test-output-private/ and baselines under pipeline/tests/snapshots/, and
 * skipping a missing fixture) lives in the integration test.
 */

import type {
  ScabopdfDocument,
  NodeDict,
  SemanticCategory,
} from '../consumption';
import { normalizeExtraction } from '../native/pdfExtraction';
import { buildDocumentFromPdf, GENERIC_TAXONOMY } from '../plugins';
import type { GenericCoverage } from '../plugins';
import type { Capture } from './report';

/** Bump when the comparison report shape changes (independent of Layer 1). */
export const STRUCTURAL_COMPARISON_SCHEMA_VERSION = '1.0';

/**
 * Default "low delta" tolerance applied to the per-category RELATIVE delta of
 * the `produced` categories: a produced category whose count is within ±15 % of
 * the baseline is banded CLOSE, beyond it DIVERGENT. This is the measurable, low
 * tolerance the brief asks for — defined on counts and structure, never on JSON
 * equality. It is deliberately generous because the Generic is a corpus-agnostic
 * fallback measured against a corpus-specific oracle; see
 * docs/LAYER2_STRUCTURAL_VALIDATION.md for how to read it.
 */
export const STRUCTURAL_REL_TOLERANCE = 0.15;

/** The verdict for one category's count delta. */
export type DeltaBand = 'EXACT' | 'CLOSE' | 'DIVERGENT' | 'NOT_COMPARABLE';

/** One per-category line of the comparison. */
export interface CategoryDelta {
  /** SemanticCategory name, identical on both layers (taxonomy-aligned). */
  category: SemanticCategory;
  /** Taxonomy coverage bucket: produced / detected-suppressed / reserved. */
  coverage: GenericCoverage;
  /** Node count in the Generic output. */
  generic: number;
  /** Node count in the Layer 1 baseline (category_counts). */
  baseline: number;
  /** |generic − baseline|. */
  absDelta: number;
  /** absDelta / baseline, or null when baseline is 0 (relative delta undefined). */
  relDelta: number | null;
  /** Verdict; only `produced` categories can be EXACT/CLOSE/DIVERGENT. */
  band: DeltaBand;
}

/** Topology of the Generic tree (the real, full tree is available). */
export interface GenericTopology {
  nodeTotal: number;
  /** Deepest nesting level (root nodes are depth 1). The Generic emits a flat
   *  reading-order list, so this is 1 — hierarchy assembly is corpus-plugin
   *  work the Generic does not do. */
  maxDepth: number;
  /** HEADING_1..4 counts (the heading hierarchy histogram). */
  headingCountsByLevel: Record<string, number>;
  /** Full per-category node counts. */
  roleCounts: Record<string, number>;
  /** NOTE count per length_category (MICRO..MEGA), when present. */
  noteLengthCounts: Record<string, number>;
}

/**
 * Topology derivable from a Layer 1 baseline. The baseline carries category
 * counts only (no tree), so node depth is unknown and the NOTE length
 * distribution is unavailable — only counts-derived metrics are present.
 */
export interface BaselineTopology {
  nodeTotal: number;
  headingCountsByLevel: Record<string, number>;
  /** Always false: the baseline has no tree, so depth cannot be measured. */
  maxDepthKnown: false;
}

/** Focused summary over the `produced` categories — the Generic's remit. */
export interface ProducedSummary {
  /** The produced category names present on either side. */
  categories: string[];
  /** Worst relative delta among produced categories with a non-zero baseline. */
  maxRelDelta: number | null;
  /** Mean relative delta among produced categories with a non-zero baseline. */
  meanRelDelta: number | null;
  /**
   * True iff every produced category is EXACT or CLOSE. Null when no baseline is
   * available (nothing to be within tolerance of). Informational: a false here
   * on a colour-coded or heading-implicit corpus is expected (see the doc), not
   * a test failure.
   */
  withinTolerance: boolean | null;
  /** The relative tolerance used for the CLOSE/DIVERGENT cut. */
  relTolerance: number;
}

export interface StructuralComparisonReport {
  schemaVersion: string;
  /** Filename-derived fixture slug (allowed; not document content). */
  fixtureSlug: string;
  /** Layer 1 corpus identifier (matches the baseline naming family). */
  corpusId: string;
  /** The baseline file under pipeline/tests/snapshots, or null when none. */
  baselineFile: string | null;
  /** False when no structural (category_counts) baseline exists for this corpus. */
  baselineAvailable: boolean;
  /** Per-category deltas, produced first, then detected-suppressed, then reserved. */
  categories: CategoryDelta[];
  producedSummary: ProducedSummary;
  topology: {
    generic: GenericTopology;
    baseline: BaselineTopology | null;
  };
}

const HEADING_LEVELS = ['HEADING_1', 'HEADING_2', 'HEADING_3', 'HEADING_4'];

const COVERAGE_ORDER: Record<GenericCoverage, number> = {
  produced: 0,
  'detected-suppressed': 1,
  reserved: 2,
};

function round(value: number, decimals = 4): number {
  const f = 10 ** decimals;
  return Math.round(value * f) / f;
}

/** Walks a document tree computing the full Generic topology. */
export function documentTopology(doc: ScabopdfDocument): GenericTopology {
  const roleCounts: Record<string, number> = {};
  const noteLengthCounts: Record<string, number> = {};
  let nodeTotal = 0;
  let maxDepth = 0;
  const walk = (nodes: NodeDict[] | undefined, depth: number): void => {
    for (const node of nodes ?? []) {
      nodeTotal += 1;
      maxDepth = Math.max(maxDepth, depth);
      roleCounts[node.type] = (roleCounts[node.type] ?? 0) + 1;
      if (node.type === 'NOTE' && node.length_category) {
        noteLengthCounts[node.length_category] =
          (noteLengthCounts[node.length_category] ?? 0) + 1;
      }
      walk(node.children, depth + 1);
    }
  };
  walk(doc.structure, 1);
  const headingCountsByLevel: Record<string, number> = {};
  for (const level of HEADING_LEVELS) {
    const n = roleCounts[level];
    if (n !== undefined && n > 0) {
      headingCountsByLevel[level] = n;
    }
  }
  return {
    nodeTotal,
    maxDepth,
    headingCountsByLevel,
    roleCounts,
    noteLengthCounts,
  };
}

/** Derives the (counts-only) topology of a Layer 1 baseline. */
export function baselineTopology(
  counts: Record<string, number>,
): BaselineTopology {
  let nodeTotal = 0;
  const headingCountsByLevel: Record<string, number> = {};
  for (const [category, n] of Object.entries(counts)) {
    nodeTotal += n;
    if (HEADING_LEVELS.includes(category) && n > 0) {
      headingCountsByLevel[category] = n;
    }
  }
  return { nodeTotal, headingCountsByLevel, maxDepthKnown: false };
}

/**
 * Compares two per-category count maps, banding each category by the taxonomy.
 * Iterates every taxonomy category but emits a line only when at least one side
 * is non-zero (keeps the report compact). When `comparable` is false (no
 * baseline), every band is NOT_COMPARABLE.
 */
export function compareCategoryCounts(
  generic: Record<string, number>,
  baseline: Record<string, number>,
  opts: { relTolerance?: number; comparable?: boolean } = {},
): CategoryDelta[] {
  const tol = opts.relTolerance ?? STRUCTURAL_REL_TOLERANCE;
  const comparable = opts.comparable ?? true;
  const out: CategoryDelta[] = [];
  for (const category of Object.keys(GENERIC_TAXONOMY) as SemanticCategory[]) {
    const g = generic[category] ?? 0;
    const b = baseline[category] ?? 0;
    if (g === 0 && b === 0) {
      continue;
    }
    const coverage = GENERIC_TAXONOMY[category].coverage;
    const absDelta = Math.abs(g - b);
    const relDelta = b > 0 ? round(absDelta / b) : null;
    let band: DeltaBand;
    if (!comparable || coverage !== 'produced') {
      band = 'NOT_COMPARABLE';
    } else if (absDelta === 0) {
      band = 'EXACT';
    } else if (b === 0) {
      // Generic produced something the baseline has none of: a real divergence.
      band = 'DIVERGENT';
    } else {
      band = (relDelta as number) <= tol ? 'CLOSE' : 'DIVERGENT';
    }
    out.push({
      category,
      coverage,
      generic: g,
      baseline: b,
      absDelta,
      relDelta,
      band,
    });
  }
  out.sort(
    (a, b) =>
      COVERAGE_ORDER[a.coverage] - COVERAGE_ORDER[b.coverage] ||
      a.category.localeCompare(b.category),
  );
  return out;
}

function summarizeProduced(
  categories: CategoryDelta[],
  baselineAvailable: boolean,
  relTolerance: number,
): ProducedSummary {
  const produced = categories.filter(c => c.coverage === 'produced');
  const names = produced.map(c => c.category);
  if (!baselineAvailable) {
    return {
      categories: names,
      maxRelDelta: null,
      meanRelDelta: null,
      withinTolerance: null,
      relTolerance,
    };
  }
  const rels = produced
    .filter(c => c.baseline > 0 && c.relDelta !== null)
    .map(c => c.relDelta as number);
  const maxRelDelta = rels.length > 0 ? Math.max(...rels) : null;
  const meanRelDelta =
    rels.length > 0
      ? round(rels.reduce((a, b) => a + b, 0) / rels.length)
      : null;
  const withinTolerance = produced.every(
    c => c.band === 'EXACT' || c.band === 'CLOSE',
  );
  return {
    categories: names,
    maxRelDelta,
    meanRelDelta,
    withinTolerance,
    relTolerance,
  };
}

/** Builds the full comparison report from a Generic document and a baseline. */
export function buildStructuralComparison(args: {
  document: ScabopdfDocument;
  fixtureSlug: string;
  corpusId: string;
  baselineFile: string | null;
  baselineCategoryCounts: Record<string, number> | null;
  relTolerance?: number;
}): StructuralComparisonReport {
  const relTolerance = args.relTolerance ?? STRUCTURAL_REL_TOLERANCE;
  const baselineAvailable = args.baselineCategoryCounts !== null;
  const genericTopology = documentTopology(args.document);
  const categories = compareCategoryCounts(
    genericTopology.roleCounts,
    args.baselineCategoryCounts ?? {},
    { relTolerance, comparable: baselineAvailable },
  );
  return {
    schemaVersion: STRUCTURAL_COMPARISON_SCHEMA_VERSION,
    fixtureSlug: args.fixtureSlug,
    corpusId: args.corpusId,
    baselineFile: args.baselineFile,
    baselineAvailable,
    categories,
    producedSummary: summarizeProduced(
      categories,
      baselineAvailable,
      relTolerance,
    ),
    topology: {
      generic: genericTopology,
      baseline: args.baselineCategoryCounts
        ? baselineTopology(args.baselineCategoryCounts)
        : null,
    },
  };
}

/** The result of attempting a comparison for one fixture. */
export type ComparisonOutcome =
  | { status: 'compared'; report: StructuralComparisonReport }
  | { status: 'skipped'; fixtureSlug: string; reason: string };

/**
 * Orchestrates one fixture: builds the Generic document from the capture (when
 * present) and compares it to the baseline (when present).
 *
 * - capture === null  → skipped (the fixture PDF was not seeded on this clone).
 * - baselineCategoryCounts === null → a one-sided report (baselineAvailable
 *   false): the Generic counts are still reported, with no oracle to compare to.
 *
 * The missing-fixture skip keeps the suite green on a fresh clone, exactly like
 * the Layer 1 pytest.skip convention.
 */
export function comparisonForCapture(args: {
  fixtureSlug: string;
  corpusId: string;
  baselineFile: string | null;
  capture: Capture | null;
  baselineCategoryCounts: Record<string, number> | null;
  relTolerance?: number;
}): ComparisonOutcome {
  if (args.capture === null) {
    return {
      status: 'skipped',
      fixtureSlug: args.fixtureSlug,
      reason:
        `fixture "${args.fixtureSlug}" not seeded; seed the private PDFs and ` +
        'capture them on a Simulator (see docs/LAYER2_TEST_FRAMEWORK.md §3: ' +
        'seed_fixtures.sh + the ScaboPDFExtractionTests run + pull_captures.sh).',
    };
  }
  const extraction = normalizeExtraction(args.capture.extraction);
  const document = buildDocumentFromPdf(extraction, args.capture.filename);
  return {
    status: 'compared',
    report: buildStructuralComparison({
      document,
      fixtureSlug: args.fixtureSlug,
      corpusId: args.corpusId,
      baselineFile: args.baselineFile,
      baselineCategoryCounts: args.baselineCategoryCounts,
      relTolerance: args.relTolerance,
    }),
  };
}
