import {
  flattenToReadingOrder,
  parseDocument,
  validateAgainstSchema,
  walkTree,
  type NodeDict,
  type ScabopdfDocument,
} from '../index';

function makeValidDoc(): ScabopdfDocument {
  return {
    schema_version: '0.7.0',
    document_id: '123e4567-e89b-12d3-a456-426614174000',
    metadata: {
      pages_pdf: 2,
      page_size_pt: [595, 842],
      source_pdf_filename: 'esempio.pdf',
    },
    profile: {
      profile_id: 'unknown_generic',
      editorial_family: 'unknown',
      genre: 'unknown',
      confidence: 0.0,
    },
    warnings: ['plugin:test:demo_warning'],
    structure: [
      {
        id: 'node_0',
        type: 'HEADING_1',
        page_index: 0,
        level: 1,
        text: 'Titolo',
        children: [
          { id: 'node_1', type: 'BODY', page_index: 0, text: 'Corpo' },
          {
            id: 'node_2',
            type: 'NOTE',
            page_index: 0,
            text: '(1) una nota',
            length_category: 'SHORT',
          },
        ],
      },
      { id: 'node_3', type: 'BODY', page_index: 1, text: 'Altro corpo' },
    ],
  };
}

describe('validateAgainstSchema', () => {
  test('accepts a conforming document', () => {
    expect(validateAgainstSchema(makeValidDoc())).toEqual([]);
  });

  test('reports failures for a missing required field', () => {
    const broken: unknown = {
      ...makeValidDoc(),
      metadata: { page_size_pt: [595, 842], source_pdf_filename: 'x.pdf' },
    };
    const errors = validateAgainstSchema(broken);
    expect(errors.length).toBeGreaterThan(0);
    expect(errors[0]).toHaveProperty('location');
    expect(errors[0]).toHaveProperty('message');
  });

  test('reports failures for an out-of-vocabulary node type', () => {
    const broken: unknown = {
      ...makeValidDoc(),
      structure: [{ id: 'node_0', type: 'NOT_A_CATEGORY', page_index: 0 }],
    };
    expect(validateAgainstSchema(broken).length).toBeGreaterThan(0);
  });
});

describe('parseDocument', () => {
  test('parses a valid object and surfaces warnings', () => {
    const result = parseDocument(makeValidDoc());
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.document.profile.profile_id).toBe('unknown_generic');
      expect(result.warnings).toEqual(['plugin:test:demo_warning']);
    }
  });

  test('parses a valid JSON string', () => {
    const result = parseDocument(JSON.stringify(makeValidDoc()));
    expect(result.ok).toBe(true);
  });

  test('rejects non-JSON input with an accessible message', () => {
    const result = parseDocument('{ this is not json');
    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.error.kind).toBe('invalid_json');
      expect(result.error.message).toMatch(/ScaboPDF/);
    }
  });

  test('rejects an unsupported schema version with a clear message', () => {
    const result = parseDocument({
      ...makeValidDoc(),
      schema_version: '0.8.0',
    });
    expect(result.ok).toBe(false);
    if (!result.ok && result.error.kind === 'unsupported_version') {
      expect(result.error.foundVersion).toBe('0.8.0');
      expect(result.error.message).toContain('0.8.0');
    } else {
      throw new Error('expected unsupported_version error');
    }
  });

  test('rejects a structurally invalid document', () => {
    const broken: unknown = {
      ...makeValidDoc(),
      metadata: { page_size_pt: [1, 2], source_pdf_filename: 'x.pdf' },
    };
    const result = parseDocument(broken);
    expect(result.ok).toBe(false);
    if (!result.ok && result.error.kind === 'schema_validation') {
      expect(result.error.errors.length).toBeGreaterThan(0);
    } else {
      throw new Error('expected schema_validation error');
    }
  });
});

describe('traversal', () => {
  test('flattenToReadingOrder yields pre-order sequence', () => {
    const ids = flattenToReadingOrder(makeValidDoc()).map(n => n.id);
    expect(ids).toEqual(['node_0', 'node_1', 'node_2', 'node_3']);
  });

  test('walkTree reports correct depth and parent', () => {
    const seen: Array<{ id: string; depth: number; parent: string | null }> =
      [];
    walkTree(makeValidDoc().structure ?? [], (node, depth, parent) => {
      seen.push({ id: node.id, depth, parent: parent ? parent.id : null });
    });
    expect(seen).toEqual([
      { id: 'node_0', depth: 0, parent: null },
      { id: 'node_1', depth: 1, parent: 'node_0' },
      { id: 'node_2', depth: 1, parent: 'node_0' },
      { id: 'node_3', depth: 0, parent: null },
    ]);
  });

  test('handles a document with no structure', () => {
    const doc: ScabopdfDocument = makeValidDoc();
    const noStructure: ScabopdfDocument = { ...doc, structure: undefined };
    expect(flattenToReadingOrder(noStructure)).toEqual([]);
  });

  test('exposes NodeDict typing for consumers', () => {
    const node: NodeDict = { id: 'node_9', type: 'BODY', page_index: 0 };
    expect(node.type).toBe('BODY');
  });
});
