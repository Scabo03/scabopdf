/**
 * Content-free test-report model for the on-device extraction pipeline.
 *
 * A `Capture` is the real device extraction the Swift XCTest layer writes
 * (Caches/scabo-extractions/<slug>.capture.json): the genuine PDFKit output
 * wrapped with timing + size. `buildReport` runs the REAL production pipeline
 * over it — the same `buildDocumentFromPdf` (Generic plugin), `buildLayout` and
 * `paginate` that run in Hermes on-device, which have no platform branches and
 * so produce identical results — and reduces the result to a content-free
 * report: only counts, distributions, timings and (content-free) plugin
 * warnings. No segment text, so the report is safe to commit (privacy contract:
 * document content is never recorded). The full text-bearing tree is returned
 * separately as `dump`, which the caller writes to the gitignored
 * test-output-private/ tree.
 *
 * This is the schema documented in docs/LAYER2_TEST_FRAMEWORK.md.
 */

import type { ScabopdfDocument, NodeDict } from '../consumption';
import { normalizeExtraction, totalLines } from '../native/pdfExtraction';
import { buildDocumentFromPdf } from '../plugins';
import { buildLayout, paginate } from '../rendering';

/** Bump when the report shape changes (independent of the Layer-1 schema). */
export const TEST_REPORT_SCHEMA_VERSION = '1.0';

/** The Swift-captured device extraction (Caches/scabo-extractions/*.json). */
export interface Capture {
  filename: string;
  extractMs: number;
  pdfSizeBytes: number;
  /** Raw PDFKit extraction object; normalised through production logic. */
  extraction: unknown;
}

export interface ExtractionStats {
  pages: number;
  lines: number;
  /** Line count per dominant font size (rounded to 0.5pt). Content-free. */
  fontSizeHistogram: Record<string, number>;
  /** Fraction of lines that are predominantly bold, in [0, 1]. */
  boldLineRatio: number;
  payloadBytes: number;
}

export interface DocumentStats {
  profileId: string;
  nodeTotal: number;
  /** Node count per SemanticCategory (HEADING_1.., BODY, NOTE, …). */
  roleCounts: Record<string, number>;
  /** NOTE node count per length_category (MICRO..MEGA). */
  noteLengthCounts: Record<string, number>;
  /** Content-free plugin warnings (plugin:generic:…). */
  warnings: string[];
}

export interface LayoutStats {
  layoutId: string;
  segmentTotal: number;
  pagesProduced: number;
}

export interface Timings {
  /** Swift/PDFKit extraction, measured on-device (from the capture). */
  extractMs: number;
  /** Generic plugin build, measured here over the real extraction. */
  pluginMs: number;
  layoutMs: number;
  paginateMs: number;
}

export interface ContentFreeReport {
  reportSchemaVersion: string;
  pdfFilename: string;
  pdfSizeBytes: number;
  extraction: ExtractionStats;
  document: DocumentStats;
  layout: LayoutStats;
  timings: Timings;
}

/** The text-bearing artefacts; NEVER committed (gitignored output tree). */
export interface ReportDump {
  document: ScabopdfDocument;
  segmentRoles: string[];
}

export interface BuildReportResult {
  report: ContentFreeReport;
  dump: ReportDump;
}

const LAYOUT_ID = 'continuous' as const;

/** Runs the real pipeline over a capture and returns the content-free report. */
export function buildReport(capture: Capture): BuildReportResult {
  const extraction = normalizeExtraction(capture.extraction);

  const t0 = now();
  const document = buildDocumentFromPdf(extraction, capture.filename);
  const t1 = now();
  const segments = buildLayout(document, LAYOUT_ID);
  const t2 = now();
  const paginated = paginate(segments);
  const t3 = now();

  const { roleCounts, noteLengthCounts, nodeTotal } = walkDocument(document);

  const report: ContentFreeReport = {
    reportSchemaVersion: TEST_REPORT_SCHEMA_VERSION,
    pdfFilename: capture.filename,
    pdfSizeBytes: capture.pdfSizeBytes,
    extraction: {
      pages: extraction.pageCount,
      lines: totalLines(extraction),
      fontSizeHistogram: fontSizeHistogram(extraction),
      boldLineRatio: boldLineRatio(extraction),
      payloadBytes: byteLength(capture.extraction),
    },
    document: {
      profileId: document.profile.profile_id,
      nodeTotal,
      roleCounts,
      noteLengthCounts,
      warnings: document.warnings ?? [],
    },
    layout: {
      layoutId: LAYOUT_ID,
      segmentTotal: paginated.totalSegments,
      pagesProduced: paginated.pages.length,
    },
    timings: {
      extractMs: capture.extractMs,
      pluginMs: round(t1 - t0),
      layoutMs: round(t2 - t1),
      paginateMs: round(t3 - t2),
    },
  };

  return {
    report,
    dump: { document, segmentRoles: segments.map(s => s.role) },
  };
}

/** Walks the node tree counting roles, NOTE length categories and total nodes. */
function walkDocument(doc: ScabopdfDocument): {
  roleCounts: Record<string, number>;
  noteLengthCounts: Record<string, number>;
  nodeTotal: number;
} {
  const roleCounts: Record<string, number> = {};
  const noteLengthCounts: Record<string, number> = {};
  let nodeTotal = 0;
  const walk = (nodes: NodeDict[] | undefined): void => {
    for (const node of nodes ?? []) {
      nodeTotal += 1;
      roleCounts[node.type] = (roleCounts[node.type] ?? 0) + 1;
      if (node.type === 'NOTE' && node.length_category) {
        noteLengthCounts[node.length_category] =
          (noteLengthCounts[node.length_category] ?? 0) + 1;
      }
      walk(node.children);
    }
  };
  walk(doc.structure);
  return { roleCounts, noteLengthCounts, nodeTotal };
}

function fontSizeHistogram(extraction: {
  pages: { lines: { fontSize: number }[] }[];
}): Record<string, number> {
  const hist: Record<string, number> = {};
  for (const page of extraction.pages) {
    for (const line of page.lines) {
      const key = (Math.round(line.fontSize * 2) / 2).toFixed(1);
      hist[key] = (hist[key] ?? 0) + 1;
    }
  }
  return hist;
}

function boldLineRatio(extraction: {
  pages: { lines: { bold: boolean }[] }[];
}): number {
  let total = 0;
  let bold = 0;
  for (const page of extraction.pages) {
    for (const line of page.lines) {
      total += 1;
      if (line.bold) {
        bold += 1;
      }
    }
  }
  return total === 0 ? 0 : round(bold / total, 4);
}

function byteLength(value: unknown): number {
  try {
    return JSON.stringify(value)?.length ?? 0;
  } catch {
    return 0;
  }
}

function now(): number {
  return typeof performance !== 'undefined' && performance.now
    ? performance.now()
    : Date.now();
}

function round(value: number, decimals = 2): number {
  const f = 10 ** decimals;
  return Math.round(value * f) / f;
}
