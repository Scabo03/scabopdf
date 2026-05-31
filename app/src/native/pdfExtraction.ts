/**
 * TS-facing wrapper around the NativePdfExtractor TurboModule.
 *
 * Calls the native PDFKit extractor and parses its JSON payload (shape version
 * 2: per-page lines, each a sequence of spans with text + font signal + colour
 * + bbox) into typed structures the Generic plugin consumes. Throws a readable
 * Italian error when the native module is unavailable (Android / jest) or the
 * payload is invalid, so the caller can surface it to VoiceOver instead of
 * failing silently (SPECS § 0, P0).
 */

import NativePdfExtractor from './NativePdfExtractor';

/** A page-local bounding box `[x, y, w, h]`, origin bottom-left, y up. */
export type BBox = [number, number, number, number];

/** One maximal run of uniform typographic attributes within a laid-out line. */
export interface PdfSpan {
  text: string;
  /** Font point size (0 if PDFKit reported none, e.g. a scanned PDF). */
  fontSize: number;
  bold: boolean;
  italic: boolean;
  /** Resolved fill colour as "#rrggbb" (PDF default → "#000000"). */
  color: string;
  bbox: BBox;
}

/** One laid-out line of text: its spans plus the union bbox. */
export interface PdfTextLine {
  spans: PdfSpan[];
  bbox: BBox;
}

/** The lines extracted from a single PDF page, in reading order. */
export interface PdfPageExtraction {
  /** 0-based page index, matching PDFKit / the Layer 1 PageIndex convention. */
  pageIndex: number;
  /** Page (cropBox) width/height in points, for normalising bbox positions. */
  width: number;
  height: number;
  lines: PdfTextLine[];
}

/** The full structured extraction of a PDF. */
export interface PdfExtraction {
  /** Payload shape version (2 = per-span). */
  version: number;
  pageCount: number;
  pages: PdfPageExtraction[];
}

/**
 * A line reduced to a single signal vector. `text`/`fontSize`/`bold` reproduce
 * the legacy char-weighted line aggregate exactly (so size-based classification
 * is unchanged across the per-span migration); `italic`/`color`/geometry are the
 * new signals a multi-signal plugin uses. Keeps the raw spans for finer checks.
 */
export interface LineSummary {
  text: string;
  /** Character-weighted dominant font size. */
  fontSize: number;
  /** True when ≥ 60 % of characters are bold (legacy threshold). */
  bold: boolean;
  /** True when ≥ 60 % of characters are italic. */
  italic: boolean;
  /** Dominant fill colour (by character count). */
  color: string;
  /** Left edge / right edge of the line bbox (page-local). */
  x0: number;
  x1: number;
  /** Top / bottom y of the line bbox (origin bottom-left, so yTop ≥ yBottom). */
  yTop: number;
  yBottom: number;
  width: number;
  height: number;
  spans: PdfSpan[];
}

/** Extracts a PDF at a local file URI into typed, structured text. */
export async function extractPdf(uri: string): Promise<PdfExtraction> {
  if (NativePdfExtractor == null) {
    throw new Error('Estrazione PDF non disponibile su questa piattaforma.');
  }
  const json = await NativePdfExtractor.extractToJson(uri);
  let parsed: unknown;
  try {
    parsed = JSON.parse(json);
  } catch {
    throw new Error('Il PDF non ha prodotto dati leggibili.');
  }
  return normalizeExtraction(parsed);
}

/** Total number of non-empty lines across every page. */
export function totalLines(extraction: PdfExtraction): number {
  return extraction.pages.reduce((sum, page) => sum + page.lines.length, 0);
}

/**
 * Reduces a line to a single signal vector. The char-weighted size + bold ratio
 * match the legacy per-line aggregate so classification is migration-stable.
 */
export function summarizeLine(line: PdfTextLine): LineSummary {
  let weightedSize = 0;
  let sizeWeight = 0;
  let boldChars = 0;
  let italicChars = 0;
  let total = 0;
  let text = '';
  const colorChars: Record<string, number> = {};
  for (const span of line.spans) {
    text += span.text;
    const n = span.text.length;
    if (span.fontSize > 0) {
      weightedSize += span.fontSize * n;
      sizeWeight += n;
    }
    if (span.bold) {
      boldChars += n;
    }
    if (span.italic) {
      italicChars += n;
    }
    total += n;
    colorChars[span.color] = (colorChars[span.color] ?? 0) + n;
  }
  let color = '#000000';
  let bestChars = -1;
  for (const [c, n] of Object.entries(colorChars)) {
    if (n > bestChars) {
      bestChars = n;
      color = c;
    }
  }
  const [x, y, w, h] = line.bbox;
  return {
    text: text.trim(),
    fontSize: sizeWeight > 0 ? weightedSize / sizeWeight : 0,
    bold: total > 0 && boldChars / total >= 0.6,
    italic: total > 0 && italicChars / total >= 0.6,
    color,
    x0: x,
    x1: x + w,
    yTop: y + h,
    yBottom: y,
    width: w,
    height: h,
    spans: line.spans,
  };
}

/**
 * Defensive normaliser: the native payload is trusted but parsed at the
 * boundary, so a malformed shape degrades to an empty extraction rather than
 * crashing the reader. Exported so the test/measurement layer can normalise a
 * captured device extraction with the exact production logic.
 */
export function normalizeExtraction(parsed: unknown): PdfExtraction {
  if (typeof parsed !== 'object' || parsed === null) {
    return { version: 0, pageCount: 0, pages: [] };
  }
  const obj = parsed as {
    version?: unknown;
    pageCount?: unknown;
    pages?: unknown;
  };
  const pages = Array.isArray(obj.pages)
    ? obj.pages.map(normalizePage).filter((p): p is PdfPageExtraction => p !== null)
    : [];
  return {
    version: typeof obj.version === 'number' ? obj.version : 0,
    pageCount: typeof obj.pageCount === 'number' ? obj.pageCount : pages.length,
    pages,
  };
}

function normalizePage(raw: unknown): PdfPageExtraction | null {
  if (typeof raw !== 'object' || raw === null) {
    return null;
  }
  const obj = raw as {
    pageIndex?: unknown;
    width?: unknown;
    height?: unknown;
    lines?: unknown;
  };
  const lines = Array.isArray(obj.lines)
    ? obj.lines.map(normalizeLine).filter((l): l is PdfTextLine => l !== null)
    : [];
  return {
    pageIndex: typeof obj.pageIndex === 'number' ? obj.pageIndex : 0,
    width: typeof obj.width === 'number' ? obj.width : 0,
    height: typeof obj.height === 'number' ? obj.height : 0,
    lines,
  };
}

function normalizeLine(raw: unknown): PdfTextLine | null {
  if (typeof raw !== 'object' || raw === null) {
    return null;
  }
  const obj = raw as { spans?: unknown; bbox?: unknown };
  const spans = Array.isArray(obj.spans)
    ? obj.spans.map(normalizeSpan).filter((s): s is PdfSpan => s !== null)
    : [];
  if (spans.length === 0 || spans.every(s => s.text.trim().length === 0)) {
    return null;
  }
  return { spans, bbox: normalizeBBox(obj.bbox) };
}

function normalizeSpan(raw: unknown): PdfSpan | null {
  if (typeof raw !== 'object' || raw === null) {
    return null;
  }
  const obj = raw as {
    text?: unknown;
    fontSize?: unknown;
    bold?: unknown;
    italic?: unknown;
    color?: unknown;
    bbox?: unknown;
  };
  // Keep whitespace-only spans (inter-word spacing); the line is dropped only
  // when all its spans join to whitespace (see normalizeLine).
  const text = typeof obj.text === 'string' ? obj.text : '';
  if (text.length === 0) {
    return null;
  }
  return {
    text,
    fontSize: typeof obj.fontSize === 'number' ? obj.fontSize : 0,
    bold: obj.bold === true,
    italic: obj.italic === true,
    color: typeof obj.color === 'string' ? obj.color : '#000000',
    bbox: normalizeBBox(obj.bbox),
  };
}

function normalizeBBox(raw: unknown): BBox {
  if (
    Array.isArray(raw) &&
    raw.length === 4 &&
    raw.every(v => typeof v === 'number')
  ) {
    return [raw[0], raw[1], raw[2], raw[3]] as BBox;
  }
  return [0, 0, 0, 0];
}
