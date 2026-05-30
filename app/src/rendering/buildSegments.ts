/**
 * Layout-agnostic base traversal: walks the document tree in reading order and
 * emits one ContentSegment per node that carries text. Synthetic nodes without
 * text (EMPTY_PAGE, anchor-only nodes) are skipped. NOTE segments preserve
 * length_category for the acoustic-regime hook.
 *
 * Read-once model (Q1). The Layer 1 AKN topology nests modification nodes
 * whose text is a verbatim substring of their parent: ARTICLE_BODY ⊃ AMENDMENT
 * ⊃ QUOTED_TEXT_NEW/OLD. Emitting every text-bearing node naively read the same
 * legislative text two or three times in a row. Instead, a node's own text is
 * emitted only for the spans its children do NOT already reproduce, and the
 * children are recursed at their position inside the parent text — so every
 * character is voiced exactly once, at the most specific role that covers it
 * (the article framing in ARTICLE_BODY, the amendment instruction in AMENDMENT,
 * the quoted text in QUOTED_TEXT_*). Children whose text is not a contiguous
 * substring of the parent (e.g. UPDATE_BLOCK under a synthetic container, or
 * EPUB commi) are disjoint content and are emitted in full after the parent —
 * the pre-existing behaviour, with no duplication.
 *
 * The walk uses an explicit work-list (not recursion) so a deeply nested but
 * schema-valid document cannot overflow the JS call stack on Hermes.
 *
 * Each layout builder starts from this stream and applies its own filtering
 * or transformation.
 */

import type { ScabopdfDocument } from '../consumption';
import type { NodeDict } from '../consumption';
import type { ContentSegment } from './contentModel';

type Work =
  | { kind: 'segment'; segment: ContentSegment }
  | { kind: 'node'; node: NodeDict };

function segmentFor(node: NodeDict, text: string): ContentSegment {
  return {
    id: node.id,
    role: node.type,
    text,
    lengthCategory: node.length_category ?? '',
  };
}

/** Pushes the parent's own text for `[start, end)` as a segment, trimmed. */
function pushSlice(
  items: Work[],
  node: NodeDict,
  text: string,
  start: number,
  end: number,
): void {
  if (end <= start) {
    return;
  }
  const slice = text.slice(start, end).trim();
  if (slice.length === 0) {
    return;
  }
  items.push({ kind: 'segment', segment: segmentFor(node, slice) });
}

/** Builds the ordered work-items a node expands into (children + own text). */
function expand(node: NodeDict): Work[] {
  const text = node.text ?? '';
  const children = node.children ?? [];

  if (children.length === 0) {
    return text.length > 0
      ? [{ kind: 'segment', segment: segmentFor(node, text) }]
      : [];
  }

  // Place each child at its first occurrence as a contiguous substring of the
  // parent text (the Layer 1 modification topology reproduces the child text
  // verbatim inside the parent). Children whose text is not found are disjoint
  // content and are emitted, in tree order, after the parent's own text.
  const placed: { child: NodeDict; start: number; end: number }[] = [];
  const disjoint: NodeDict[] = [];
  for (const child of children) {
    const childText = child.text ?? '';
    const idx = childText.length > 0 ? text.indexOf(childText) : -1;
    if (idx >= 0) {
      placed.push({ child, start: idx, end: idx + childText.length });
    } else {
      disjoint.push(child);
    }
  }

  const items: Work[] = [];

  if (placed.length === 0) {
    // No child reproduces the parent text: emit the parent in full, then the
    // children in pre-order. (Synthetic containers, EPUB commi, plain prose.)
    if (text.length > 0) {
      items.push({ kind: 'segment', segment: segmentFor(node, text) });
    }
    for (const child of children) {
      items.push({ kind: 'node', node: child });
    }
    return items;
  }

  // Interleave the parent's uncovered spans with the substring children, in
  // textual order (which is the physical reading order). Overlapping matches
  // (rare — identical child texts) are clamped so a span is never re-emitted.
  placed.sort((a, b) => a.start - b.start || a.end - b.end);
  let cursor = 0;
  for (const { child, start, end } of placed) {
    pushSlice(items, node, text, cursor, start);
    items.push({ kind: 'node', node: child });
    cursor = Math.max(cursor, end);
  }
  pushSlice(items, node, text, cursor, text.length);
  for (const child of disjoint) {
    items.push({ kind: 'node', node: child });
  }
  return items;
}

export function buildBaseSegments(doc: ScabopdfDocument): ContentSegment[] {
  const out: ContentSegment[] = [];
  const stack: Work[] = [];
  const pushReversed = (items: Work[]): void => {
    for (let i = items.length - 1; i >= 0; i--) {
      const item = items[i];
      if (item !== undefined) {
        stack.push(item);
      }
    }
  };

  pushReversed((doc.structure ?? []).map(node => ({ kind: 'node', node })));

  let work = stack.pop();
  while (work !== undefined) {
    if (work.kind === 'segment') {
      out.push(work.segment);
    } else {
      pushReversed(expand(work.node));
    }
    work = stack.pop();
  }
  return out;
}
