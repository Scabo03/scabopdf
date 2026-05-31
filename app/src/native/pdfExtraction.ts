/**
 * TS-facing wrapper around the NativePdfExtractor TurboModule.
 *
 * Calls the native PDFKit extractor and parses its JSON payload into typed
 * structures the Generic plugin consumes. Throws a readable Italian error when
 * the native module is unavailable (Android / jest) or the payload is invalid,
 * so the caller can surface it to VoiceOver instead of failing silently
 * (SPECS § 0, P0).
 */

import NativePdfExtractor from './NativePdfExtractor';

/** One laid-out line of text on a PDF page, with the font signal we keep. */
export interface PdfTextLine {
  /** Trimmed line text. */
  text: string;
  /** Character-weighted dominant font point size (0 if PDFKit reported none). */
  fontSize: number;
  /** True when the line is predominantly bold. */
  bold: boolean;
}

/** The lines extracted from a single PDF page, in reading order. */
export interface PdfPageExtraction {
  /** 0-based page index, matching PDFKit / the Layer 1 PageIndex convention. */
  pageIndex: number;
  lines: PdfTextLine[];
}

/** The full structured extraction of a PDF. */
export interface PdfExtraction {
  pageCount: number;
  pages: PdfPageExtraction[];
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
 * Defensive normaliser: the native payload is trusted but parsed at the
 * boundary, so a malformed shape degrades to an empty extraction rather than
 * crashing the reader.
 */
function normalizeExtraction(parsed: unknown): PdfExtraction {
  if (typeof parsed !== 'object' || parsed === null) {
    return { pageCount: 0, pages: [] };
  }
  const obj = parsed as { pageCount?: unknown; pages?: unknown };
  const pages = Array.isArray(obj.pages)
    ? obj.pages.map(normalizePage).filter((p): p is PdfPageExtraction => p !== null)
    : [];
  const pageCount =
    typeof obj.pageCount === 'number' ? obj.pageCount : pages.length;
  return { pageCount, pages };
}

function normalizePage(raw: unknown): PdfPageExtraction | null {
  if (typeof raw !== 'object' || raw === null) {
    return null;
  }
  const obj = raw as { pageIndex?: unknown; lines?: unknown };
  const pageIndex = typeof obj.pageIndex === 'number' ? obj.pageIndex : 0;
  const lines = Array.isArray(obj.lines)
    ? obj.lines.map(normalizeLine).filter((l): l is PdfTextLine => l !== null)
    : [];
  return { pageIndex, lines };
}

function normalizeLine(raw: unknown): PdfTextLine | null {
  if (typeof raw !== 'object' || raw === null) {
    return null;
  }
  const obj = raw as { text?: unknown; fontSize?: unknown; bold?: unknown };
  const text = typeof obj.text === 'string' ? obj.text.trim() : '';
  if (text.length === 0) {
    return null;
  }
  return {
    text,
    fontSize: typeof obj.fontSize === 'number' ? obj.fontSize : 0,
    bold: obj.bold === true,
  };
}
