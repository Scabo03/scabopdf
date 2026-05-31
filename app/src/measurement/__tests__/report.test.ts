/**
 * Deterministic unit test for the report builder, run on a committed SYNTHETIC
 * capture (no private fixtures). Green on a fresh clone; it pins the report
 * schema and proves the real pipeline (Generic plugin + layout + paginate) is
 * driven end-to-end and reduced to a content-free report.
 */

import { buildReport, TEST_REPORT_SCHEMA_VERSION } from '../report';
import type { Capture } from '../report';
import example from '../__fixtures__/example.capture.json';

describe('buildReport (synthetic capture)', () => {
  const { report, dump } = buildReport(example as Capture);

  it('pins the report schema version and the source filename', () => {
    expect(report.reportSchemaVersion).toBe(TEST_REPORT_SCHEMA_VERSION);
    expect(report.pdfFilename).toBe('synthetic-example.pdf');
    expect(report.pdfSizeBytes).toBe(1024);
  });

  it('measures the extraction layer content-free', () => {
    expect(report.extraction.pages).toBe(1);
    expect(report.extraction.lines).toBe(4);
    // One 16pt + two 10pt + one 8pt line.
    expect(report.extraction.fontSizeHistogram['10.0']).toBe(2);
    expect(report.extraction.fontSizeHistogram['16.0']).toBe(1);
    expect(report.extraction.fontSizeHistogram['8.0']).toBe(1);
    expect(report.extraction.boldLineRatio).toBeCloseTo(0.25, 5);
  });

  it('classifies via the real Generic plugin: heading, merged body, note', () => {
    // 10pt dominates -> body; 16pt (1.6x) -> HEADING_1; 8pt (0.8x) -> NOTE.
    expect(report.document.profileId).toBe('generic');
    expect(report.document.nodeTotal).toBe(3);
    expect(report.document.roleCounts.HEADING_1).toBe(1);
    expect(report.document.roleCounts.BODY).toBe(1);
    expect(report.document.roleCounts.NOTE).toBe(1);
    // The NOTE carries a length_category.
    const noteLen = Object.values(report.document.noteLengthCounts).reduce(
      (a, b) => a + b,
      0,
    );
    expect(noteLen).toBe(1);
    // Content-free heuristic warning is present.
    expect(
      report.document.warnings.some(w => w.startsWith('plugin:generic:')),
    ).toBe(true);
  });

  it('produces a consumable layout', () => {
    expect(report.layout.layoutId).toBe('continuous');
    expect(report.layout.segmentTotal).toBe(3);
    expect(report.layout.pagesProduced).toBeGreaterThanOrEqual(1);
  });

  it('records timings as numbers', () => {
    for (const v of Object.values(report.timings)) {
      expect(typeof v).toBe('number');
      expect(v).toBeGreaterThanOrEqual(0);
    }
  });

  it('keeps text only in the dump, never in the report', () => {
    expect(dump.document.structure?.length ?? 0).toBeGreaterThan(0);
    // The content-free report serialises without any segment text.
    const serialised = JSON.stringify(report);
    expect(serialised).not.toContain('Capitolo');
    expect(serialised).not.toContain('paragrafo');
  });
});
