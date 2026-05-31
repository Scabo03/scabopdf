/**
 * Generic extraction plugin — the corpus-agnostic fallback.
 *
 * Turns a per-span PDFKit extraction into a ScabopdfDocument using a
 * MULTI-SIGNAL heuristic (size + colour + geometry), not size alone. The
 * real-on-device measurements of 2026-05-31 showed size-only failed on the
 * majority of corpora; this version uses the enriched bridge to close the
 * measured debts:
 *
 *   - D1 (Vol. IV collapse): the body size is the LARGEST size bucket that is at
 *     least half as frequent (by line count) as the most frequent one, so a
 *     note-heavy volume whose notes outnumber the body no longer mistakes the
 *     note size for the body size (which made every body line read as a heading).
 *   - D2 (running header/footer as false headings): lines that recur in the same
 *     top/bottom page band across many pages are page furniture and are dropped.
 *   - D4 (colour-coded headings, e.g. BIC): a substantial line whose dominant
 *     colour is clearly distinct from the body colour is a heading candidate —
 *     the plugin does not know any corpus palette, only "consistent non-body
 *     colour = structural signal".
 *   - D3 (note fragmentation): dropping furniture lets adjacent note lines merge
 *     into coherent paragraphs instead of one-line MICRO fragments.
 *
 * D6 (inline emphasis / superscript markers) is now physically visible in the
 * spans; it is consumed as an internal signal (italic in the line summary,
 * leading-small-span detection is available) but NOT surfaced as new content
 * model fields — the existing roles remain the contract. Surfacing emphasis to
 * VoiceOver is a deferred accessibility decision.
 *
 * Still a corpus-agnostic heuristic: it loses to any corpus-specific plugin.
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
  LineSummary,
} from '../native/pdfExtraction';
import { summarizeLine } from '../native/pdfExtraction';
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

/** RGB distance beyond which a colour counts as "distinct from body". */
const COLOR_DISTANCE_MIN = 100;
/** Min RGB saturation (max−min channel) for a colour to read as structural:
 *  headings are saturated (green/indigo/maroon), not greys/watermarks. */
const COLOR_SATURATION_MIN = 40;
/** A colour-distinct line must be at least this fraction of the body size. */
const COLOR_HEADING_MIN_RATIO = 0.95;
/** Page bands (fraction of height) where running furniture lives. */
const TOP_BAND = 0.9;
const BOTTOM_BAND = 0.1;
/** A furniture candidate is short. */
const FURNITURE_MAX_CHARS = 60;

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

interface Profile {
  bodySize: number;
  bodyColor: string;
}

export const genericPlugin: ExtractionPlugin = {
  id: 'generic',
  label: 'Generico',

  // The universal fallback: always eligible, always loses to a corpus-specific
  // plugin that recognises the document.
  matches(): number {
    return 0.05;
  },

  build(extraction: PdfExtraction, sourceName: string): ScabopdfDocument {
    const profile = estimateProfile(extraction);
    const furniture = detectFurniture(extraction);
    const nodes: NodeDict[] = [];
    let counter = 0;
    const nextId = (): string => `node_${counter++}`;

    for (const page of extraction.pages) {
      appendPageNodes(page, profile, furniture, nodes, nextId);
    }

    const warnings = [
      `plugin:generic:heuristic_extraction_pages_${extraction.pageCount}_nodes_${nodes.length}`,
    ];
    if (profile.bodySize === 0) {
      warnings.push('plugin:generic:no_font_information_all_body');
    }
    if (furniture.size > 0) {
      warnings.push(`plugin:generic:furniture_lines_removed_${furniture.size}`);
    }

    return {
      schema_version:
        SUPPORTED_SCHEMA_VERSION as ScabopdfDocument['schema_version'],
      document_id: slug(sourceName),
      metadata: {
        pages_pdf: extraction.pageCount,
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
 * Estimates the body profile. Body size = the LARGEST size bucket that is at
 * least half as frequent (by line count) as the most frequent bucket — robust
 * to note-heavy documents where the smaller note size dominates the counts
 * (which otherwise made body lines look like headings). Body colour = the
 * colour covering the most characters.
 */
function estimateProfile(extraction: PdfExtraction): Profile {
  const linesBySize = new Map<number, number>();
  const charsByColor = new Map<string, number>();
  for (const page of extraction.pages) {
    for (const line of page.lines) {
      const sm = summarizeLine(line);
      if (sm.fontSize > 0) {
        const key = Math.round(sm.fontSize * 2) / 2; // round to 0.5pt
        linesBySize.set(key, (linesBySize.get(key) ?? 0) + 1);
      }
      charsByColor.set(
        sm.color,
        (charsByColor.get(sm.color) ?? 0) + sm.text.length,
      );
    }
  }

  let topCount = 0;
  for (const count of linesBySize.values()) {
    topCount = Math.max(topCount, count);
  }
  let bodySize = 0;
  for (const [size, count] of linesBySize) {
    if (count >= topCount * 0.5 && size > bodySize) {
      bodySize = size;
    }
  }

  let bodyColor = '#000000';
  let bestChars = -1;
  for (const [color, chars] of charsByColor) {
    if (chars > bestChars) {
      bestChars = chars;
      bodyColor = color;
    }
  }

  return { bodySize, bodyColor };
}

/**
 * Detects running headers/footers: short lines that recur, in the same top or
 * bottom page band, across many pages (normalising away page numbers). Returns
 * a set of "page:line" keys to skip.
 */
function detectFurniture(extraction: PdfExtraction): Set<string> {
  interface Candidate {
    key: string;
    norm: string;
  }
  // Two recurrence channels: lines in the top/bottom band (running
  // headers/footers), and saturated-colour lines anywhere (per-page colour
  // markers such as page anchors "Pag. N"). Real colour headings have unique
  // text per occurrence, so their norms do not recur and they survive.
  const bandCandidates: Candidate[] = [];
  const colorCandidates: Candidate[] = [];
  const generalCandidates: Candidate[] = [];
  const bandPages = new Map<string, Set<number>>();
  const colorPages = new Map<string, Set<number>>();
  const generalPages = new Map<string, Set<number>>();

  const track = (
    map: Map<string, Set<number>>,
    norm: string,
    pageIndex: number,
  ): void => {
    let pages = map.get(norm);
    if (!pages) {
      pages = new Set();
      map.set(norm, pages);
    }
    pages.add(pageIndex);
  };

  extraction.pages.forEach(page => {
    const height = page.height;
    page.lines.forEach((line, lineIndex) => {
      const sm = summarizeLine(line);
      if (sm.text.length === 0) {
        return;
      }
      const norm = sm.text.replace(/\d+/g, '#').toLowerCase().trim();
      const key = `${page.pageIndex}:${lineIndex}`;
      // General majority-recurrence applies at any length (a recurring long
      // copyright/watermark line is still furniture).
      generalCandidates.push({ key, norm });
      track(generalPages, norm, page.pageIndex);
      // Band / colour furniture are short headers/footers/markers only.
      if (sm.text.length > FURNITURE_MAX_CHARS) {
        return;
      }
      const yFrac = height > 0 ? sm.yTop / height : 0.5;
      if (yFrac >= TOP_BAND || yFrac <= BOTTOM_BAND) {
        bandCandidates.push({ key, norm });
        track(bandPages, norm, page.pageIndex);
      }
      if (isSaturated(sm.color)) {
        colorCandidates.push({ key, norm });
        track(colorPages, norm, page.pageIndex);
      }
    });
  });

  // Band / colour furniture recurs on ≥15 % of pages; a line recurring on a
  // majority of pages anywhere (a watermark) is furniture regardless of band.
  const minPages = Math.max(5, Math.ceil(extraction.pageCount * 0.15));
  const majorityPages = Math.max(5, Math.ceil(extraction.pageCount * 0.5));
  const furniture = new Set<string>();
  for (const { key, norm } of bandCandidates) {
    if ((bandPages.get(norm)?.size ?? 0) >= minPages) {
      furniture.add(key);
    }
  }
  for (const { key, norm } of colorCandidates) {
    if ((colorPages.get(norm)?.size ?? 0) >= minPages) {
      furniture.add(key);
    }
  }
  for (const { key, norm } of generalCandidates) {
    if ((generalPages.get(norm)?.size ?? 0) >= majorityPages) {
      furniture.add(key);
    }
  }
  return furniture;
}

function classify(line: LineSummary, profile: Profile): Kind {
  const { bodySize, bodyColor } = profile;
  const short = line.text.length <= HEADING_MAX_CHARS;
  const ratio = bodySize > 0 && line.fontSize > 0 ? line.fontSize / bodySize : 0;

  // Colour-distinct, substantial, at-least-body-size short lines are heading
  // candidates regardless of size (D4). Pure markers (digits/punctuation) and
  // near-white invisible anchors are excluded.
  const colorHeading =
    short &&
    isSubstantial(line.text) &&
    isSaturated(line.color) &&
    colorDistance(line.color, bodyColor) > COLOR_DISTANCE_MIN &&
    (ratio === 0 || ratio >= COLOR_HEADING_MIN_RATIO);

  if (colorHeading) {
    // Level by size relative to body when known, else a mid level.
    if (ratio >= HEADING_2_RATIO) {
      return { role: 'HEADING', level: 1 };
    }
    if (ratio >= HEADING_3_RATIO) {
      return { role: 'HEADING', level: 2 };
    }
    return { role: 'HEADING', level: 3 };
  }

  if (ratio === 0) {
    return { role: 'BODY' };
  }

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
 * Emits the nodes for one page: furniture and invisible-anchor lines skipped,
 * headings as standalone nodes, runs of consecutive BODY (or NOTE) lines merged
 * into one paragraph node (skipped furniture no longer fragments a note run).
 */
function appendPageNodes(
  page: PdfPageExtraction,
  profile: Profile,
  furniture: Set<string>,
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
    const node: NodeDict = {
      id: nextId(),
      type: runRole as SemanticCategory,
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

  page.lines.forEach((line, lineIndex) => {
    if (furniture.has(`${page.pageIndex}:${lineIndex}`)) {
      return;
    }
    const sm = summarizeLine(line);
    if (isNearWhite(sm.color)) {
      return; // invisible white text (page anchors on a white page)
    }
    const kind = classify(sm, profile);
    if (kind.role === 'HEADING') {
      flushRun();
      out.push({
        id: nextId(),
        type: `HEADING_${kind.level}` as SemanticCategory,
        page_index: page.pageIndex,
        text: sm.text,
        level: kind.level,
        children: [],
      });
      return;
    }
    if (runRole !== null && runRole !== kind.role) {
      flushRun();
    }
    runRole = kind.role;
    runLines.push(sm.text);
  });
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

/** A heading must carry actual letters, not be a bare marker (digits/symbols). */
function isSubstantial(text: string): boolean {
  return (text.match(/[A-Za-zÀ-ÿ]/g)?.length ?? 0) >= 2;
}

function isNearWhite(color: string): boolean {
  const [r, g, b] = rgb(color);
  return r > 230 && g > 230 && b > 230;
}

/** A saturated colour (clearly not a grey/near-grey) reads as structural. */
function isSaturated(color: string): boolean {
  const [r, g, b] = rgb(color);
  return Math.max(r, g, b) - Math.min(r, g, b) > COLOR_SATURATION_MIN;
}

function colorDistance(a: string, b: string): number {
  const [ar, ag, ab] = rgb(a);
  const [br, bg, bb] = rgb(b);
  return Math.sqrt((ar - br) ** 2 + (ag - bg) ** 2 + (ab - bb) ** 2);
}

function rgb(color: string): [number, number, number] {
  const m = /^#([0-9a-fA-F]{6})$/.exec(color);
  if (m === null) {
    return [0, 0, 0];
  }
  const h = m[1] ?? '000000';
  return [
    parseInt(h.slice(0, 2), 16),
    parseInt(h.slice(2, 4), 16),
    parseInt(h.slice(4, 6), 16),
  ];
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
