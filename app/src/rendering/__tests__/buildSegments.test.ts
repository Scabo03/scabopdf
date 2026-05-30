/**
 * Unit tests for buildBaseSegments' text-less-node skip (the module's
 * documented core job, never exercised by the baseline fixtures because those
 * carry no EMPTY_PAGE / anchor-only nodes) and the paginate page-size guard.
 */

import { buildBaseSegments, paginate } from '../index';
import type { ScabopdfDocument } from '../../consumption';

function docWith(structure: ScabopdfDocument['structure']): ScabopdfDocument {
  return {
    schema_version: '0.7.0',
    document_id: '00000000-0000-4000-8000-000000000000',
    metadata: {
      pages_pdf: 1,
      page_size_pt: [595, 842],
      source_pdf_filename: 'x.pdf',
    },
    profile: {
      profile_id: 'unknown_generic',
      editorial_family: 'unknown',
      genre: 'unknown',
      confidence: 0,
    },
    structure,
  };
}

describe('buildBaseSegments skips text-less nodes', () => {
  test('drops null/empty/undefined-text and anchor-only nodes, keeps real text', () => {
    const doc = docWith([
      { id: 'node_0', type: 'EMPTY_PAGE', page_index: 0, text: null },
      { id: 'node_1', type: 'BOOK_PAGE_ANCHOR', page_index: 0 },
      { id: 'node_2', type: 'BODY', page_index: 0, text: '' },
      { id: 'node_3', type: 'BODY', page_index: 0, text: 'reale' },
    ]);
    const segs = buildBaseSegments(doc);
    expect(segs.map(s => s.id)).toEqual(['node_3']);
    expect(segs[0]).toEqual({
      id: 'node_3',
      role: 'BODY',
      text: 'reale',
      lengthCategory: '',
    });
  });

  test('NOTE keeps its length_category; non-NOTE gets the empty string', () => {
    const doc = docWith([
      {
        id: 'node_0',
        type: 'NOTE',
        page_index: 0,
        text: '(1) nota',
        length_category: 'MEGA',
      },
      { id: 'node_1', type: 'BODY', page_index: 0, text: 'corpo' },
    ]);
    const segs = buildBaseSegments(doc);
    expect(segs[0]?.lengthCategory).toBe('MEGA');
    expect(segs[1]?.lengthCategory).toBe('');
  });
});

describe('paginate guard', () => {
  test('throws on a non-positive page size', () => {
    expect(() => paginate([], 0)).toThrow(/segmentsPerPage must be > 0/);
    expect(() => paginate([], -5)).toThrow(/segmentsPerPage must be > 0/);
  });
});
