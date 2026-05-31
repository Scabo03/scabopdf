/**
 * Deterministic unit tests for the structural comparison framework, on synthetic
 * inputs only (no private fixtures) — green on a fresh clone. They pin the delta
 * math, the taxonomy-driven banding, the topology metrics, the well-formedness
 * of the report and the missing-fixture skip.
 */

import type {
  NodeDict,
  ScabopdfDocument,
  SemanticCategory,
} from '../../consumption';
import { GENERIC_TAXONOMY } from '../../plugins';
import type { Capture } from '../report';
import example from '../__fixtures__/example.capture.json';
import {
  STRUCTURAL_COMPARISON_SCHEMA_VERSION,
  STRUCTURAL_REL_TOLERANCE,
  baselineTopology,
  buildStructuralComparison,
  compareCategoryCounts,
  comparisonForCapture,
  documentTopology,
} from '../structuralComparison';
import {
  CORPUS_BASELINES,
  corpusEntryForSlug,
  extractCategoryCounts,
} from '../corpusBaselines';

function makeDoc(structure: NodeDict[]): ScabopdfDocument {
  return {
    schema_version: '0.7.0',
    document_id: 'synthetic',
    metadata: {
      pages_pdf: 1,
      page_size_pt: [0, 0],
      source_pdf_filename: 's.pdf',
    },
    profile: {
      profile_id: 'generic',
      editorial_family: 'generic',
      genre: 'unknown',
      confidence: 0.05,
    },
    warnings: [],
    transformations: [],
    structure,
  } as ScabopdfDocument;
}

function node(
  id: string,
  type: SemanticCategory,
  children: NodeDict[] = [],
  extra: Partial<NodeDict> = {},
): NodeDict {
  return { id, type, page_index: 0, text: id, children, ...extra };
}

describe('compareCategoryCounts — delta math and taxonomy banding', () => {
  const deltas = compareCategoryCounts(
    { HEADING_1: 10, BODY: 100, NOTE: 5 },
    {
      HEADING_1: 10,
      BODY: 90,
      NOTE: 50,
      CROSS_REFERENCE: 200,
      ARTIFACT_FOOTER: 30,
    },
  );
  const by = (c: string): (typeof deltas)[number] | undefined =>
    deltas.find(d => d.category === c);

  it('EXACT when counts are equal', () => {
    expect(by('HEADING_1')).toMatchObject({
      absDelta: 0,
      relDelta: 0,
      band: 'EXACT',
    });
  });

  it('CLOSE within the relative tolerance', () => {
    // |100-90|/90 = 0.1111 <= 0.15
    expect(by('BODY')).toMatchObject({ absDelta: 10, band: 'CLOSE' });
    expect(by('BODY')?.relDelta).toBeCloseTo(0.1111, 3);
  });

  it('DIVERGENT beyond the relative tolerance', () => {
    // |5-50|/50 = 0.9 > 0.15
    expect(by('NOTE')).toMatchObject({ absDelta: 45, band: 'DIVERGENT' });
  });

  it('reserved categories are NOT_COMPARABLE regardless of delta', () => {
    expect(by('CROSS_REFERENCE')).toMatchObject({
      generic: 0,
      baseline: 200,
      band: 'NOT_COMPARABLE',
    });
  });

  it('detected-suppressed categories are NOT_COMPARABLE', () => {
    expect(by('ARTIFACT_FOOTER')).toMatchObject({ band: 'NOT_COMPARABLE' });
  });

  it('omits categories absent on both sides', () => {
    expect(by('PROCEDURAL')).toBeUndefined();
    expect(by('EXAMPLE_BOX')).toBeUndefined();
  });

  it('produced categories sort before reserved/detected-suppressed', () => {
    const firstReservedIdx = deltas.findIndex(d => d.coverage !== 'produced');
    const lastProducedIdx = deltas.map(d => d.coverage).lastIndexOf('produced');
    expect(lastProducedIdx).toBeLessThan(firstReservedIdx);
  });

  it('every reported category is a known taxonomy category', () => {
    for (const d of deltas) {
      expect(GENERIC_TAXONOMY[d.category]).toBeDefined();
      expect(d.coverage).toBe(GENERIC_TAXONOMY[d.category].coverage);
    }
  });
});

describe('compareCategoryCounts — edge cases', () => {
  it('baseline 0 with generic > 0 is DIVERGENT and relDelta null', () => {
    const d = compareCategoryCounts({ HEADING_4: 7 }, {}).find(
      x => x.category === 'HEADING_4',
    );
    expect(d).toMatchObject({
      generic: 7,
      baseline: 0,
      relDelta: null,
      band: 'DIVERGENT',
    });
  });

  it('comparable=false bands everything NOT_COMPARABLE', () => {
    const deltas = compareCategoryCounts(
      { HEADING_1: 3, BODY: 9 },
      {},
      { comparable: false },
    );
    expect(deltas.every(d => d.band === 'NOT_COMPARABLE')).toBe(true);
  });

  it('respects a custom relative tolerance', () => {
    // |12-10|/10 = 0.2; CLOSE at tol 0.25, DIVERGENT at the 0.15 default.
    expect(
      compareCategoryCounts(
        { BODY: 12 },
        { BODY: 10 },
        { relTolerance: 0.25 },
      ).find(d => d.category === 'BODY')?.band,
    ).toBe('CLOSE');
    expect(
      compareCategoryCounts({ BODY: 12 }, { BODY: 10 }).find(
        d => d.category === 'BODY',
      )?.band,
    ).toBe('DIVERGENT');
  });
});

describe('documentTopology', () => {
  const doc = makeDoc([
    node('n0', 'HEADING_1', [
      node('n1', 'BODY'),
      node(
        'n2',
        'NOTE',
        [node('n3', 'NOTE', [], { length_category: 'MICRO' })],
        {
          length_category: 'SHORT',
        },
      ),
    ]),
    node('n4', 'HEADING_2'),
  ]);
  const topo = documentTopology(doc);

  it('counts total nodes and the deepest nesting', () => {
    expect(topo.nodeTotal).toBe(5);
    expect(topo.maxDepth).toBe(3);
  });

  it('histograms headings by level and notes by length', () => {
    expect(topo.headingCountsByLevel).toEqual({ HEADING_1: 1, HEADING_2: 1 });
    expect(topo.noteLengthCounts).toEqual({ SHORT: 1, MICRO: 1 });
    expect(topo.roleCounts.NOTE).toBe(2);
  });
});

describe('baselineTopology', () => {
  it('sums counts and extracts heading levels; depth is unknown', () => {
    const t = baselineTopology({
      HEADING_1: 13,
      HEADING_3: 208,
      BODY: 2261,
      NOTE: 1454,
    });
    expect(t.nodeTotal).toBe(13 + 208 + 2261 + 1454);
    expect(t.headingCountsByLevel).toEqual({ HEADING_1: 13, HEADING_3: 208 });
    expect(t.maxDepthKnown).toBe(false);
  });
});

describe('buildStructuralComparison — well-formedness', () => {
  const doc = makeDoc([
    node('n0', 'HEADING_1'),
    node('n1', 'BODY'),
    node('n2', 'NOTE'),
  ]);

  it('produces a well-formed report with a baseline', () => {
    const report = buildStructuralComparison({
      document: doc,
      fixtureSlug: 'demo',
      corpusId: 'demo_corpus',
      baselineFile: 'demo_baseline.json',
      baselineCategoryCounts: {
        HEADING_1: 1,
        BODY: 1,
        NOTE: 1,
        CROSS_REFERENCE: 5,
      },
    });
    expect(report.schemaVersion).toBe(STRUCTURAL_COMPARISON_SCHEMA_VERSION);
    expect(report.baselineAvailable).toBe(true);
    expect(report.topology.baseline).not.toBeNull();
    // All produced categories match exactly => within tolerance.
    expect(report.producedSummary.withinTolerance).toBe(true);
    expect(report.producedSummary.maxRelDelta).toBe(0);
    expect(report.producedSummary.relTolerance).toBe(STRUCTURAL_REL_TOLERANCE);
  });

  it('produces a one-sided report without a baseline', () => {
    const report = buildStructuralComparison({
      document: doc,
      fixtureSlug: 'demo',
      corpusId: 'demo_corpus',
      baselineFile: null,
      baselineCategoryCounts: null,
    });
    expect(report.baselineAvailable).toBe(false);
    expect(report.topology.baseline).toBeNull();
    expect(report.producedSummary.withinTolerance).toBeNull();
    expect(report.categories.every(c => c.band === 'NOT_COMPARABLE')).toBe(
      true,
    );
  });

  it('flags divergence when the Generic count is far from the baseline', () => {
    const report = buildStructuralComparison({
      document: doc,
      fixtureSlug: 'demo',
      corpusId: 'demo_corpus',
      baselineFile: 'demo.json',
      baselineCategoryCounts: { HEADING_1: 50, BODY: 1, NOTE: 1 },
    });
    expect(report.producedSummary.withinTolerance).toBe(false);
    expect(report.categories.find(c => c.category === 'HEADING_1')?.band).toBe(
      'DIVERGENT',
    );
  });
});

describe('comparisonForCapture — skip and run', () => {
  it('skips with an explicit message when the fixture is missing', () => {
    const outcome = comparisonForCapture({
      fixtureSlug: 'missing_fixture',
      corpusId: 'x',
      baselineFile: null,
      capture: null,
      baselineCategoryCounts: null,
    });
    expect(outcome.status).toBe('skipped');
    if (outcome.status === 'skipped') {
      expect(outcome.reason).toMatch(/not seeded/);
      expect(outcome.reason).toMatch(/LAYER2_TEST_FRAMEWORK\.md/);
    }
  });

  it('runs the real Generic pipeline over a present capture', () => {
    const outcome = comparisonForCapture({
      fixtureSlug: 'synthetic',
      corpusId: 'synthetic_corpus',
      baselineFile: 'synthetic.json',
      capture: example as Capture,
      baselineCategoryCounts: { HEADING_1: 1, BODY: 1, NOTE: 1 },
    });
    expect(outcome.status).toBe('compared');
    if (outcome.status === 'compared') {
      // The synthetic capture yields exactly 1 HEADING_1 + 1 BODY + 1 NOTE.
      const { report } = outcome;
      expect(report.topology.generic.nodeTotal).toBe(3);
      expect(report.producedSummary.withinTolerance).toBe(true);
    }
  });
});

describe('corpusBaselines registry', () => {
  it('covers the seven seeded fixtures with unique slugs', () => {
    const slugs = CORPUS_BASELINES.map(e => e.captureSlug);
    expect(slugs.length).toBe(7);
    expect(new Set(slugs).size).toBe(7);
  });

  it('every entry either points to a baseline file or documents its absence', () => {
    for (const e of CORPUS_BASELINES) {
      if (e.baselineFile === null) {
        expect(e.note ?? '').not.toBe('');
      } else {
        expect(e.baselineFile).toMatch(/\.json$/);
      }
    }
  });

  it('resolves a known slug and rejects an unknown one', () => {
    expect(corpusEntryForSlug('manuale_del_marrone_pdf')?.corpusId).toBe(
      'marrone',
    );
    expect(corpusEntryForSlug('nope')).toBeUndefined();
  });

  it('extractCategoryCounts reads category_counts and ignores digest-only baselines', () => {
    expect(
      extractCategoryCounts({ category_counts: { BODY: 3, NOTE: 2 } }),
    ).toEqual({
      BODY: 3,
      NOTE: 2,
    });
    expect(extractCategoryCounts({ matches_score_digest: 'abc' })).toBeNull();
    expect(extractCategoryCounts(null)).toBeNull();
  });
});
