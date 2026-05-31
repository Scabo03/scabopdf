/**
 * Integration generator: runs the structural comparison over the REAL on-device
 * captures (test-output-private/extractions/, gitignored, from the Swift
 * ScaboPDFExtractionTests + pull_captures.sh) against the committed Layer 1
 * baselines (pipeline/tests/snapshots/, in the repo). It writes one content-free
 * comparison report per fixture to test-output-private/comparisons/ plus an
 * aggregate index.
 *
 * Skips the whole suite when no captures are present (fresh clone, no local
 * fixtures), and skips an individual fixture whose capture is missing — exactly
 * like the Layer 1 pytest.skip convention. It never asserts that the Generic
 * matches the corpus-specific oracle (it cannot, by design — the Generic is a
 * corpus-agnostic fallback and PDFKit ≠ PyMuPDF); it asserts only that the
 * comparison is well-formed, and emits the numbers for review.
 */

import * as fs from 'fs';
import * as path from 'path';
import { comparisonForCapture } from '../structuralComparison';
import type { StructuralComparisonReport } from '../structuralComparison';
import { CORPUS_BASELINES, extractCategoryCounts } from '../corpusBaselines';
import type { Capture } from '../report';

const REPO_ROOT = path.resolve(__dirname, '../../../..');
const CAPTURES_DIR = path.join(REPO_ROOT, 'test-output-private', 'extractions');
const SNAPSHOTS_DIR = path.join(REPO_ROOT, 'pipeline', 'tests', 'snapshots');
const COMPARISONS_DIR = path.join(
  REPO_ROOT,
  'test-output-private',
  'comparisons',
);

function anyCapturePresent(): boolean {
  if (!fs.existsSync(CAPTURES_DIR)) {
    return false;
  }
  return fs.readdirSync(CAPTURES_DIR).some(f => f.endsWith('.capture.json'));
}

function readCapture(slug: string): Capture | null {
  const p = path.join(CAPTURES_DIR, `${slug}.capture.json`);
  if (!fs.existsSync(p)) {
    return null;
  }
  return JSON.parse(fs.readFileSync(p, 'utf8')) as Capture;
}

function readBaselineCounts(
  file: string | null,
): Record<string, number> | null {
  if (file === null) {
    return null;
  }
  const p = path.join(SNAPSHOTS_DIR, file);
  if (!fs.existsSync(p)) {
    return null;
  }
  return extractCategoryCounts(JSON.parse(fs.readFileSync(p, 'utf8')));
}

const suite = anyCapturePresent() ? describe : describe.skip;

suite('Generic vs Layer 1 — structural comparison', () => {
  beforeAll(() => {
    fs.mkdirSync(COMPARISONS_DIR, { recursive: true });
  });

  const reports: StructuralComparisonReport[] = [];

  it.each(CORPUS_BASELINES.map(e => [e.captureSlug, e] as const))(
    '%s',
    (_slug, entry) => {
      const outcome = comparisonForCapture({
        fixtureSlug: entry.captureSlug,
        corpusId: entry.corpusId,
        baselineFile: entry.baselineFile,
        capture: readCapture(entry.captureSlug),
        baselineCategoryCounts: readBaselineCounts(entry.baselineFile),
      });

      if (outcome.status === 'skipped') {
        // Fixture not seeded on this clone — informational, not a failure.
        console.log(`[structural-comparison] skipped: ${outcome.reason}`);
        return;
      }

      const { report } = outcome;
      // Well-formedness only — never an oracle-match assertion.
      expect(report.fixtureSlug).toBe(entry.captureSlug);
      expect(report.corpusId).toBe(entry.corpusId);
      expect(report.topology.generic.nodeTotal).toBeGreaterThan(0);
      expect(report.baselineAvailable).toBe(entry.baselineFile !== null);
      for (const c of report.categories) {
        expect(c.absDelta).toBe(Math.abs(c.generic - c.baseline));
      }

      fs.writeFileSync(
        path.join(COMPARISONS_DIR, `${entry.captureSlug}.comparison.json`),
        JSON.stringify(report, null, 2),
      );
      reports.push(report);
    },
  );

  afterAll(() => {
    if (reports.length === 0) {
      return;
    }
    const index = reports.map(r => ({
      fixture: r.fixtureSlug,
      corpus: r.corpusId,
      baselineFile: r.baselineFile,
      baselineAvailable: r.baselineAvailable,
      genericNodes: r.topology.generic.nodeTotal,
      baselineNodes: r.topology.baseline?.nodeTotal ?? null,
      producedWithinTolerance: r.producedSummary.withinTolerance,
      producedMaxRelDelta: r.producedSummary.maxRelDelta,
      producedMeanRelDelta: r.producedSummary.meanRelDelta,
    }));
    fs.writeFileSync(
      path.join(COMPARISONS_DIR, '_index.json'),
      JSON.stringify(index, null, 2),
    );
  });
});
