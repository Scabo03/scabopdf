/**
 * Pins the Generic category taxonomy contract:
 *
 *   1. Name alignment + exhaustiveness — the taxonomy keys are EXACTLY the
 *      Layer 1 SemanticCategory enum, read at runtime from the committed schema
 *      (`consumption/schema.json`), so no divergent name and no missing/extra
 *      category can slip in. A future Layer 1 enum change that is not mirrored
 *      here fails this suite.
 *   2. Coverage well-formedness — produced/detected-suppressed entries carry at
 *      least one signal; reserved entries carry none; every entry has a
 *      rationale; `category` matches its map key.
 *   3. The produced set is exactly the six categories the Generic emits.
 *   4. The three coverage buckets partition the enum (disjoint + exhaustive).
 *   5. Layer-2 presentation-only roles are NOT Layer 1 categories.
 *   6. Behaviour — genericPlugin.build over varied extractions emits only
 *      categories the taxonomy marks as `produced`.
 */

import schema from '../../consumption/schema.json';
import { buildDocumentFromPdf } from '..';
import type { PdfExtraction, PdfTextLine } from '../../native/pdfExtraction';
import type { NodeDict, SemanticCategory } from '../../consumption';
import {
  GENERIC_DETECTED_SUPPRESSED_CATEGORIES,
  GENERIC_PRODUCED_CATEGORIES,
  GENERIC_RESERVED_CATEGORIES,
  GENERIC_TAXONOMY,
  GENERIC_TAXONOMY_ENTRIES,
  LAYER2_PRESENTATION_ONLY_ROLES,
  isGenericProduced,
} from '../taxonomy';

// The Layer 1 enum, read from the generated contract rather than hardcoded.
const LAYER1_CATEGORIES: readonly string[] = (
  schema as { $defs: { SemanticCategory: { enum: string[] } } }
).$defs.SemanticCategory.enum;

const sorted = (xs: Iterable<string>): string[] => [...xs].sort();

describe('Generic taxonomy — alignment with Layer 1', () => {
  test('taxonomy keys are exactly the Layer 1 SemanticCategory enum', () => {
    expect(sorted(Object.keys(GENERIC_TAXONOMY))).toEqual(
      sorted(LAYER1_CATEGORIES),
    );
  });

  test('no taxonomy key diverges from a Layer 1 name', () => {
    const layer1 = new Set(LAYER1_CATEGORIES);
    for (const key of Object.keys(GENERIC_TAXONOMY)) {
      expect(layer1.has(key)).toBe(true);
    }
  });

  test('every entry.category equals its map key', () => {
    for (const [key, entry] of Object.entries(GENERIC_TAXONOMY)) {
      expect(entry.category).toBe(key);
    }
  });
});

describe('Generic taxonomy — coverage well-formedness', () => {
  test('produced and detected-suppressed entries document at least one signal', () => {
    for (const entry of GENERIC_TAXONOMY_ENTRIES) {
      if (
        entry.coverage === 'produced' ||
        entry.coverage === 'detected-suppressed'
      ) {
        expect(entry.signals.length).toBeGreaterThan(0);
      }
    }
  });

  test('reserved entries carry no signal', () => {
    for (const entry of GENERIC_TAXONOMY_ENTRIES) {
      if (entry.coverage === 'reserved') {
        expect(entry.signals.length).toBe(0);
      }
    }
  });

  test('every entry has a non-empty rationale', () => {
    for (const entry of GENERIC_TAXONOMY_ENTRIES) {
      expect(entry.rationale.trim().length).toBeGreaterThan(0);
    }
  });
});

describe('Generic taxonomy — the produced closed set', () => {
  test('produced is exactly the six categories the Generic emits', () => {
    expect(sorted(GENERIC_PRODUCED_CATEGORIES)).toEqual(
      sorted([
        'HEADING_1',
        'HEADING_2',
        'HEADING_3',
        'HEADING_4',
        'BODY',
        'NOTE',
      ]),
    );
  });

  test('isGenericProduced agrees with the produced set', () => {
    for (const category of LAYER1_CATEGORIES as SemanticCategory[]) {
      expect(isGenericProduced(category)).toBe(
        GENERIC_PRODUCED_CATEGORIES.has(category),
      );
    }
  });
});

describe('Generic taxonomy — the three buckets partition the enum', () => {
  test('disjoint and exhaustive', () => {
    const produced = GENERIC_PRODUCED_CATEGORIES;
    const detected = GENERIC_DETECTED_SUPPRESSED_CATEGORIES;
    const reserved = GENERIC_RESERVED_CATEGORIES;

    // Disjoint.
    for (const c of produced) {
      expect(detected.has(c)).toBe(false);
      expect(reserved.has(c)).toBe(false);
    }
    for (const c of detected) {
      expect(reserved.has(c)).toBe(false);
    }

    // Exhaustive: the union is the whole enum, no overlaps.
    const union = new Set<string>([...produced, ...detected, ...reserved]);
    expect(union.size).toBe(LAYER1_CATEGORIES.length);
    expect(sorted(union)).toEqual(sorted(LAYER1_CATEGORIES));
  });
});

describe('Generic taxonomy — Layer-2 presentation-only roles', () => {
  test('SECTION_DIVIDER is not a Layer 1 SemanticCategory', () => {
    const layer1 = new Set(LAYER1_CATEGORIES);
    for (const role of LAYER2_PRESENTATION_ONLY_ROLES) {
      expect(layer1.has(role)).toBe(false);
    }
  });
});

// ── Behaviour: the Generic only ever emits `produced` categories ──────────────

function line(
  text: string,
  fontSize = 12,
  bold = false,
  color = '#000000',
): PdfTextLine {
  return {
    spans: [{ text, fontSize, bold, italic: false, color, bbox: [0, 0, 0, 0] }],
    bbox: [0, 0, 0, 0],
  };
}

function extraction(pages: PdfTextLine[][]): PdfExtraction {
  return {
    version: 2,
    pageCount: pages.length,
    pages: pages.map((lines, pageIndex) => ({
      pageIndex,
      width: 595,
      height: 842,
      lines,
    })),
  };
}

function everyNodeType(nodes: NodeDict[], acc: Set<string>): void {
  for (const node of nodes) {
    acc.add(node.type);
    everyNodeType(node.children ?? [], acc);
  }
}

describe('Generic plugin emits only `produced` categories', () => {
  test('a mixed document (heading sizes, colour heading, body, note) stays in the closed set', () => {
    const doc = buildDocumentFromPdf(
      extraction([
        [
          line('Titolo Grande', 24, true),
          line('Sottotitolo medio', 16, true),
          line('Sezione minore', 14, true),
          line('Intestazione colorata', 12, false, '#1a7f37'),
          line('Questo è il corpo del testo che domina per conteggio righe.'),
          line('Seconda riga di corpo per consolidare la stima di body size.'),
          line('Terza riga di corpo del testo normale a dodici punti.'),
          line('Quarta riga di corpo del testo normale a dodici punti.'),
          line('1 una nota a piè di pagina molto più piccola del corpo.', 8),
        ],
      ]),
      'misto.pdf',
    );

    const types = new Set<string>();
    everyNodeType(doc.structure ?? [], types);

    expect(types.size).toBeGreaterThan(0);
    for (const type of types) {
      expect(GENERIC_PRODUCED_CATEGORIES.has(type as SemanticCategory)).toBe(
        true,
      );
    }
  });

  test('a body-only document never emits a reserved or suppressed category', () => {
    const doc = buildDocumentFromPdf(
      extraction([
        Array.from({ length: 8 }, (_, i) =>
          line(`Riga ${i + 1} di puro corpo del testo, dodici punti, nera.`),
        ),
      ]),
      'corpo.pdf',
    );

    const types = new Set<string>();
    everyNodeType(doc.structure ?? [], types);

    for (const type of types) {
      expect(GENERIC_RESERVED_CATEGORIES.has(type as SemanticCategory)).toBe(
        false,
      );
      expect(
        GENERIC_DETECTED_SUPPRESSED_CATEGORIES.has(type as SemanticCategory),
      ).toBe(false);
    }
  });
});
