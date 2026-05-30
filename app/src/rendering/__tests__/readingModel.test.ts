/**
 * Q1 read-once reading model, validated against the REAL Layer 1 baselines
 * (not mocks). The AKN topology nests AMENDMENT/QUOTED_TEXT children whose text
 * is a verbatim substring of the parent; the reading model must voice every
 * character exactly once (no 2-3x re-reading) while skipping nothing.
 */

import { loadBaselineDocument } from './baselineFixtures';
import { buildBaseSegments } from '../index';
import { walkTree } from '../../consumption';
import type { NodeDict, ScabopdfDocument } from '../../consumption';

/** The naive pre-Q1 behaviour: one segment per text-bearing node, verbatim. */
function naiveCharCount(doc: ScabopdfDocument): number {
  let chars = 0;
  walkTree(doc.structure ?? [], node => {
    if (node.text) {
      chars += node.text.length;
    }
  });
  return chars;
}

function leafTexts(doc: ScabopdfDocument): string[] {
  const leaves: string[] = [];
  walkTree(doc.structure ?? [], node => {
    if ((node.children ?? []).length === 0 && node.text && node.text.trim()) {
      leaves.push(node.text.trim());
    }
  });
  return leaves;
}

function findNode(
  nodes: readonly NodeDict[],
  pred: (n: NodeDict) => boolean,
): NodeDict | null {
  for (const n of nodes) {
    if (pred(n)) {
      return n;
    }
    const inChild = findNode(n.children ?? [], pred);
    if (inChild) {
      return inChild;
    }
  }
  return null;
}

describe('Q1 read-once model on real baselines', () => {
  test('dlgs_cartabia: verbatim duplication is removed (worst-case doc)', () => {
    const doc = loadBaselineDocument('xml_akn_baseline_dlgs_cartabia.json');
    const segs = buildBaseSegments(doc);
    const emitted = segs.reduce((a, s) => a + s.text.length, 0);
    const naive = naiveCharCount(doc);
    // Measured ~39% reduction; assert a substantial drop so a regression that
    // reintroduces parent/child re-reading fails here.
    expect(emitted).toBeLessThan(naive * 0.75);
  });

  test('legge_capitali: a nested QUOTED_TEXT_NEW is never re-read inside a parent', () => {
    const doc = loadBaselineDocument('xml_akn_baseline_legge_capitali.json');
    const quoted = findNode(
      doc.structure ?? [],
      n => n.type === 'QUOTED_TEXT_NEW' && (n.text?.length ?? 0) > 200,
    );
    expect(quoted).not.toBeNull();
    const qText = quoted!.text!;
    const segs = buildBaseSegments(doc);

    // The quoted text is emitted exactly once as its own segment...
    expect(segs.filter(s => s.text === qText)).toHaveLength(1);
    // ...and never embedded inside its parent chain (ARTICLE_BODY / AMENDMENT),
    // which is exactly the old verbatim duplication. (A separate apparatus NOTE
    // may legitimately re-quote the text; that is Layer-1 content, not a
    // parent/child re-read, so we scope the check to the ancestor roles.)
    const embeddedInParentChain = segs.filter(
      s =>
        (s.role === 'ARTICLE_BODY' || s.role === 'AMENDMENT') &&
        s.text.length > qText.length &&
        s.text.includes(qText),
    );
    expect(embeddedInParentChain).toEqual([]);
  });

  test('nothing is skipped: every leaf text still appears in the stream', () => {
    const doc = loadBaselineDocument('xml_akn_baseline_legge_capitali.json');
    const segs = buildBaseSegments(doc);
    const haystack = segs.map(s => s.text).join('\n');
    for (const leaf of leafTexts(doc)) {
      expect(haystack.includes(leaf)).toBe(true);
    }
  });

  test('modification roles survive to the segment stream (distinct from body)', () => {
    const doc = loadBaselineDocument('xml_akn_baseline_legge_capitali.json');
    const roles = new Set(buildBaseSegments(doc).map(s => s.role));
    for (const r of [
      'ARTICLE_BODY',
      'AMENDMENT',
      'QUOTED_TEXT_NEW',
      'QUOTED_TEXT_OLD',
      'UPDATE_BLOCK',
    ]) {
      expect(roles.has(r)).toBe(true);
    }
  });

  test('flat document (codice_civile) is unchanged — no over-subtraction', () => {
    const doc = loadBaselineDocument('xml_akn_baseline_codice_civile.json');
    const emitted = buildBaseSegments(doc).reduce(
      (a, s) => a + s.text.length,
      0,
    );
    expect(emitted).toBe(naiveCharCount(doc));
  });
});
