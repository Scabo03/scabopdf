/**
 * Tests for the Generic extraction plugin and the dispatcher.
 *
 * Beyond the heuristic itself, the final block runs the produced Document
 * through the real rendering pipeline (buildLayout + paginate) to prove the PDF
 * path converges on the same ContentSegment model the .scabopdf.json path uses.
 */

import { buildDocumentFromPdf, genericPlugin, selectPlugin } from '..';
import type { PdfExtraction, PdfTextLine } from '../../native/pdfExtraction';
import { buildLayout, paginate } from '../../rendering';

// Builds a single-span line in the v2 shape; bbox is a stub for the size-only
// assertions here (geometry-aware tests live with the heuristics).
function line(text: string, fontSize = 12, bold = false): PdfTextLine {
  return {
    spans: [
      { text, fontSize, bold, italic: false, color: '#000000', bbox: [0, 0, 0, 0] },
    ],
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

describe('genericPlugin.build', () => {
  test('classifies a larger short line as a heading and prose as body', () => {
    const doc = genericPlugin.build(
      extraction([
        [
          line('Capitolo Primo', 20, true),
          line('Questo è il primo paragrafo del corpo del testo.'),
          line('e continua sulla riga successiva senza interruzioni.'),
        ],
      ]),
      'manuale.pdf',
    );
    const structure = doc.structure ?? [];
    expect(structure[0]?.type).toBe('HEADING_1');
    expect(structure[0]?.text).toBe('Capitolo Primo');
    expect(structure[0]?.level).toBe(1);
    // The two body lines merge into one paragraph node.
    expect(structure[1]?.type).toBe('BODY');
    expect(structure[1]?.text).toBe(
      'Questo è il primo paragrafo del corpo del testo. e continua sulla riga successiva senza interruzioni.',
    );
    expect(structure).toHaveLength(2);
  });

  test('assigns heading levels by size ratio', () => {
    const doc = genericPlugin.build(
      extraction([
        [
          line('Titolone', 18),
          line('Sottotitolo', 15),
          line('Minore', 13.5),
          line('corpo del documento normale qui presente'),
        ],
      ]),
      'x.pdf',
    );
    const types = (doc.structure ?? []).map(n => n.type);
    expect(types).toEqual(['HEADING_1', 'HEADING_2', 'HEADING_3', 'BODY']);
  });

  test('classifies smaller text as a NOTE with a length_category', () => {
    const doc = genericPlugin.build(
      extraction([
        [
          line('corpo del testo di riferimento a dimensione normale'),
          line('1. Una nota a piè di pagina molto più piccola.', 8),
        ],
      ]),
      'x.pdf',
    );
    const note = (doc.structure ?? []).find(n => n.type === 'NOTE');
    expect(note).toBeDefined();
    expect(note?.length_category).toBe('MICRO');
  });

  test('de-hyphenates a word broken across two lines', () => {
    const doc = genericPlugin.build(
      extraction([[line('responsabi-'), line('lità civile del debitore')]]),
      'x.pdf',
    );
    expect(doc.structure?.[0]?.text).toBe('responsabilità civile del debitore');
  });

  test('breaks paragraph runs at page boundaries', () => {
    const doc = genericPlugin.build(
      extraction([[line('prima pagina di testo')], [line('seconda pagina')]]),
      'x.pdf',
    );
    const structure = doc.structure ?? [];
    expect(structure).toHaveLength(2);
    expect(structure[0]?.page_index).toBe(0);
    expect(structure[1]?.page_index).toBe(1);
  });

  test('falls back to all-BODY when no font information is present', () => {
    const doc = genericPlugin.build(
      extraction([[line('riga uno', 0), line('riga due', 0)]]),
      'x.pdf',
    );
    expect((doc.structure ?? []).every(n => n.type === 'BODY')).toBe(true);
    expect(doc.warnings).toContain(
      'plugin:generic:no_font_information_all_body',
    );
  });

  test('produces a well-formed empty Document for an empty extraction', () => {
    const doc = genericPlugin.build(extraction([]), 'vuoto.pdf');
    expect(doc.structure).toEqual([]);
    expect(doc.metadata.source_pdf_filename).toBe('vuoto.pdf');
    expect(doc.document_id).toBe('vuoto');
    expect(doc.schema_version).toBe('0.7.0');
  });

  test('mints unique sequential node ids', () => {
    const doc = genericPlugin.build(
      extraction([[line('Titolo', 20), line('corpo'), line('altro corpo')]]),
      'x.pdf',
    );
    const ids = (doc.structure ?? []).map(n => n.id);
    expect(new Set(ids).size).toBe(ids.length);
    expect(ids[0]).toBe('node_0');
  });
});

describe('dispatcher', () => {
  test('selects the Generic plugin (only registered plugin this session)', () => {
    expect(selectPlugin(extraction([[line('x')]]))).toBe(genericPlugin);
  });

  test('buildDocumentFromPdf flows into the rendering pipeline', () => {
    const doc = buildDocumentFromPdf(
      extraction([
        [
          line('Capitolo', 20, true),
          line('Testo del corpo del capitolo che scorre.'),
        ],
      ]),
      'manuale.pdf',
    );
    const segments = buildLayout(doc, 'continuous');
    const { pages } = paginate(segments);
    expect(segments.length).toBeGreaterThan(0);
    expect(segments[0]?.role).toBe('HEADING_1');
    expect(pages[0]?.segments.length).toBe(segments.length);
  });
});
