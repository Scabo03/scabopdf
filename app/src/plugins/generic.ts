/**
 * Generic extraction plugin — the corpus-agnostic fallback.
 *
 * Turns a raw PDFKit extraction (per page: lines with a font signal) into a
 * ScabopdfDocument with a minimal but useful structure:
 *
 *   - the dominant body font size is estimated as the size that covers the most
 *     text across the document;
 *   - each line is classified by its size relative to that body size — clearly
 *     larger + short lines become HEADING_1..4, clearly smaller lines become
 *     NOTE, everything else is BODY;
 *   - consecutive lines of the same kind within one page are merged into a
 *     single paragraph node (with trailing-hyphen de-hyphenation) so VoiceOver
 *     reads flowing prose, not one choppy line at a time; headings stay their
 *     own nodes.
 *
 * This is deliberately a *minimal* heuristic (objective: "detect euristico
 * minimo body/heading"). Real structure (running headers/footers removal,
 * paragraph breaks from vertical gaps, footnote binding, columns) needs either
 * geometry the bridge does not carry yet or a corpus-specific plugin; those are
 * registered as debt, not attempted here.
 */

import type {
  LengthCategory,
  NodeDict,
  ScabopdfDocument,
  SemanticCategory,
} from '../consumption';
import { SUPPORTED_SCHEMA_VERSION } from '../consumption';
import type {
  PdfExtraction,
  PdfPageExtraction,
  PdfTextLine,
} from '../native/pdfExtraction';
import type { ExtractionPlugin } from './types';

/** A heading is only accepted on a reasonably short line. */
const HEADING_MAX_CHARS = 120;
/** Size ratios (line size / body size) that promote a short line to a heading. */
const HEADING_1_RATIO = 1.5;
const HEADING_2_RATIO = 1.25;
const HEADING_3_RATIO = 1.12;
/** A short, bold line a touch larger than body reads as a minor heading. */
const HEADING_4_BOLD_RATIO = 1.04;
/** Below this ratio a line reads as a note (smaller than body). */
const NOTE_RATIO = 0.85;

/** NOTE length → acoustic regime thresholds (mirrors Layer 1). */
const LENGTH_THRESHOLDS: ReadonlyArray<[number, LengthCategory]> = [
  [50, 'MICRO'],
  [100, 'SHORT'],
  [500, 'MEDIUM'],
  [1000, 'LONG'],
  [3000, 'VERY_LONG'],
];

type Kind =
  | { role: 'BODY' }
  | { role: 'NOTE' }
  | { role: 'HEADING'; level: 1 | 2 | 3 | 4 };

export const genericPlugin: ExtractionPlugin = {
  id: 'generic',
  label: 'Generico',

  // The universal fallback: always eligible, always loses to a corpus-specific
  // plugin that recognises the document.
  matches(): number {
    return 0.05;
  },

  build(extraction: PdfExtraction, sourceName: string): ScabopdfDocument {
    const bodySize = estimateBodySize(extraction);
    const nodes: NodeDict[] = [];
    let counter = 0;
    const nextId = (): string => `node_${counter++}`;

    for (const page of extraction.pages) {
      appendPageNodes(page, bodySize, nodes, nextId);
    }

    const warnings = [
      `plugin:generic:heuristic_extraction_pages_${extraction.pageCount}_nodes_${nodes.length}`,
    ];
    if (bodySize === 0) {
      warnings.push('plugin:generic:no_font_information_all_body');
    }

    return {
      schema_version:
        SUPPORTED_SCHEMA_VERSION as ScabopdfDocument['schema_version'],
      document_id: slug(sourceName),
      metadata: {
        pages_pdf: extraction.pageCount,
        // The bridge does not carry physical page size; layouts never read it.
        page_size_pt: [0, 0],
        source_pdf_filename: sourceName,
      },
      profile: {
        profile_id: 'generic',
        editorial_family: 'generic',
        genre: 'unknown',
        confidence: genericPlugin.matches(extraction),
      },
      warnings,
      transformations: [],
      structure: nodes,
    };
  },
};

/**
 * Estimates the body font size as the rounded size covering the most text
 * (by character count) across the document. Returns 0 when no line carries
 * font information (image PDF fallback), in which case everything is BODY.
 */
function estimateBodySize(extraction: PdfExtraction): number {
  const charsBySize = new Map<number, number>();
  for (const page of extraction.pages) {
    for (const line of page.lines) {
      if (line.fontSize > 0) {
        const key = Math.round(line.fontSize * 2) / 2; // round to 0.5pt
        charsBySize.set(key, (charsBySize.get(key) ?? 0) + line.text.length);
      }
    }
  }
  let best = 0;
  let bestChars = -1;
  for (const [size, chars] of charsBySize) {
    if (chars > bestChars) {
      best = size;
      bestChars = chars;
    }
  }
  return best;
}

function classify(line: PdfTextLine, bodySize: number): Kind {
  if (bodySize === 0 || line.fontSize === 0) {
    return { role: 'BODY' };
  }
  const ratio = line.fontSize / bodySize;
  const short = line.text.length <= HEADING_MAX_CHARS;
  if (short) {
    if (ratio >= HEADING_1_RATIO) {
      return { role: 'HEADING', level: 1 };
    }
    if (ratio >= HEADING_2_RATIO) {
      return { role: 'HEADING', level: 2 };
    }
    if (ratio >= HEADING_3_RATIO) {
      return { role: 'HEADING', level: 3 };
    }
    if (line.bold && ratio >= HEADING_4_BOLD_RATIO) {
      return { role: 'HEADING', level: 4 };
    }
  }
  if (ratio <= NOTE_RATIO) {
    return { role: 'NOTE' };
  }
  return { role: 'BODY' };
}

/**
 * Emits the nodes for one page: headings as standalone nodes, runs of
 * consecutive BODY (or NOTE) lines merged into one paragraph node.
 */
function appendPageNodes(
  page: PdfPageExtraction,
  bodySize: number,
  out: NodeDict[],
  nextId: () => string,
): void {
  let runRole: 'BODY' | 'NOTE' | null = null;
  let runLines: string[] = [];

  const flushRun = (): void => {
    if (runRole === null || runLines.length === 0) {
      runRole = null;
      runLines = [];
      return;
    }
    const text = joinLines(runLines);
    const type: SemanticCategory = runRole;
    const node: NodeDict = {
      id: nextId(),
      type,
      page_index: page.pageIndex,
      text,
      children: [],
    };
    if (runRole === 'NOTE') {
      node.length_category = lengthCategoryFor(text);
    }
    out.push(node);
    runRole = null;
    runLines = [];
  };

  for (const line of page.lines) {
    const kind = classify(line, bodySize);
    if (kind.role === 'HEADING') {
      flushRun();
      out.push({
        id: nextId(),
        type: `HEADING_${kind.level}` as SemanticCategory,
        page_index: page.pageIndex,
        text: line.text,
        level: kind.level,
        children: [],
      });
      continue;
    }
    if (runRole !== null && runRole !== kind.role) {
      flushRun();
    }
    runRole = kind.role;
    runLines.push(line.text);
  }
  flushRun();
}

/** Joins lines into one paragraph, de-hyphenating a word broken at line end. */
function joinLines(lines: string[]): string {
  let out = '';
  for (const raw of lines) {
    const line = raw.trim();
    if (line.length === 0) {
      continue;
    }
    if (out.length === 0) {
      out = line;
      continue;
    }
    if (/[A-Za-zÀ-ÿ]-$/.test(out)) {
      out = out.slice(0, -1) + line.replace(/^\s+/, '');
    } else {
      out = `${out} ${line}`;
    }
  }
  return out;
}

function lengthCategoryFor(text: string): LengthCategory {
  const length = text.trim().length;
  for (const [threshold, category] of LENGTH_THRESHOLDS) {
    if (length < threshold) {
      return category;
    }
  }
  return 'MEGA';
}

/** A stable, filesystem-ish id derived from the source file name. */
function slug(name: string): string {
  const base = name.replace(/\.[^.]+$/, '');
  const cleaned = base
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '');
  return cleaned.length > 0 ? cleaned : 'documento';
}
