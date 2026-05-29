/**
 * Layout-agnostic base traversal: walks the document tree in pre-order and
 * emits one ContentSegment per node that carries text. Synthetic nodes
 * without text (EMPTY_PAGE, anchor-only nodes) are skipped. NOTE segments
 * preserve length_category for the acoustic-regime hook.
 *
 * Each layout builder starts from this stream and applies its own filtering
 * or transformation.
 */

import type { ScabopdfDocument } from '../consumption';
import { walkTree } from '../consumption';
import type { ContentSegment } from './contentModel';

export function buildBaseSegments(doc: ScabopdfDocument): ContentSegment[] {
  const out: ContentSegment[] = [];
  walkTree(doc.structure ?? [], node => {
    const text = node.text;
    if (text === null || text === undefined || text.length === 0) {
      return;
    }
    out.push({
      id: node.id,
      role: node.type,
      text,
      lengthCategory: node.length_category ?? '',
    });
  });
  return out;
}
