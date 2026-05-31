/**
 * Integration generator: runs the real pipeline over the REAL on-device
 * extraction captures and writes per-PDF content-free reports + (gitignored)
 * full dumps. The captures come from the Swift XCTest layer
 * (ScaboPDFExtractionTests) via app/ios/scripts/pull_captures.sh, landing in
 * test-output-private/extractions/.
 *
 * Skips entirely when no captures are present, so the suite stays green on a
 * fresh clone with no local fixtures (the project fixture convention). When
 * captures exist it asserts each one is consumable end-to-end (nodes built,
 * layout paginates to >= 1 page, segments produced) and emits the reports.
 *
 * Privacy: only content-free reports go to reports/; the text-bearing dump goes
 * to dumps/. Both live under test-output-private/ (gitignored). Committing the
 * validated baseline reports is a deliberate later step (decision 4).
 */

import * as fs from 'fs';
import * as path from 'path';
import { buildReport } from '../report';
import type { Capture, ContentFreeReport } from '../report';

const REPO_ROOT = path.resolve(__dirname, '../../../..');
const OUT_ROOT = path.join(REPO_ROOT, 'test-output-private');
const CAPTURES_DIR = path.join(OUT_ROOT, 'extractions');
const REPORTS_DIR = path.join(OUT_ROOT, 'reports');
const DUMPS_DIR = path.join(OUT_ROOT, 'dumps');

function captureFiles(): string[] {
  if (!fs.existsSync(CAPTURES_DIR)) {
    return [];
  }
  return fs
    .readdirSync(CAPTURES_DIR)
    .filter(f => f.endsWith('.capture.json'))
    .sort();
}

const files = captureFiles();
const suite = files.length > 0 ? describe : describe.skip;

suite('real on-device captures -> content-free reports', () => {
  beforeAll(() => {
    fs.mkdirSync(REPORTS_DIR, { recursive: true });
    fs.mkdirSync(DUMPS_DIR, { recursive: true });
  });

  const summaries: ContentFreeReport[] = [];

  it.each(files)('%s is consumable and produces a report', file => {
    const base = file.replace(/\.capture\.json$/, '');
    const capture = JSON.parse(
      fs.readFileSync(path.join(CAPTURES_DIR, file), 'utf8'),
    ) as Capture;

    const { report, dump } = buildReport(capture);

    // Consumability assertions.
    expect(report.document.nodeTotal).toBeGreaterThan(0);
    expect(report.layout.segmentTotal).toBeGreaterThan(0);
    expect(report.layout.pagesProduced).toBeGreaterThanOrEqual(1);

    fs.writeFileSync(
      path.join(REPORTS_DIR, `${base}.report.json`),
      JSON.stringify(report, null, 2),
    );
    fs.writeFileSync(
      path.join(DUMPS_DIR, `${base}.dump.json`),
      JSON.stringify(dump, null, 2),
    );
    summaries.push(report);
  });

  afterAll(() => {
    if (summaries.length === 0) {
      return;
    }
    // A single aggregate index for quick comparison across PDFs.
    const index = summaries.map(r => ({
      pdf: r.pdfFilename,
      pages: r.extraction.pages,
      lines: r.extraction.lines,
      nodes: r.document.nodeTotal,
      roles: r.document.roleCounts,
      noteLengths: r.document.noteLengthCounts,
      segments: r.layout.segmentTotal,
      pagesProduced: r.layout.pagesProduced,
      timings: r.timings,
    }));
    fs.writeFileSync(
      path.join(REPORTS_DIR, '_index.json'),
      JSON.stringify(index, null, 2),
    );
  });
});
