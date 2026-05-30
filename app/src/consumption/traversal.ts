/**
 * Tree-traversal helpers over the reading-order forest.
 *
 * The document's `structure` is a forest of `NodeDict` roots, each with a
 * recursive `children` array. These helpers walk it; layout-specific shaping
 * (note placement, collapsing, regime markers) is the rendering layer's job
 * in a later phase.
 */

import type { NodeDict, ScabopdfDocument } from './schema.generated';

/** Visitor invoked for every node in pre-order (depth-first). */
export type NodeVisitor = (
  node: NodeDict,
  depth: number,
  parent: NodeDict | null,
) => void;

/**
 * Walks `nodes` and their descendants in pre-order, calling `visit`.
 *
 * Implemented with an explicit work-list rather than recursion so a deeply
 * nested (but schema-valid — `NodeDict.children` is unbounded) document cannot
 * overflow the JS call stack. The stack ceiling is small on Hermes under the
 * New Architecture, so a recursive walk could crash the render path on input
 * that the parser accepts; the iterative form is bounded by the heap instead.
 * Order is identical to the recursive walk: children are pushed in reverse so
 * siblings pop left-to-right and each node's subtree is visited before the
 * next sibling.
 */
export function walkTree(nodes: readonly NodeDict[], visit: NodeVisitor): void {
  interface Frame {
    node: NodeDict;
    depth: number;
    parent: NodeDict | null;
  }
  const stack: Frame[] = [];
  const pushReversed = (
    list: readonly NodeDict[],
    depth: number,
    parent: NodeDict | null,
  ): void => {
    for (let i = list.length - 1; i >= 0; i--) {
      const node = list[i];
      if (node !== undefined) {
        stack.push({ node, depth, parent });
      }
    }
  };

  pushReversed(nodes, 0, null);
  let frame = stack.pop();
  while (frame !== undefined) {
    visit(frame.node, frame.depth, frame.parent);
    const children = frame.node.children;
    if (children !== undefined && children.length > 0) {
      pushReversed(children, frame.depth + 1, frame.node);
    }
    frame = stack.pop();
  }
}

/**
 * Flattens the whole document into a single pre-order sequence of nodes —
 * the layout-agnostic reading order. The rendering layer builds each layout
 * on top of this.
 */
export function flattenToReadingOrder(doc: ScabopdfDocument): NodeDict[] {
  const out: NodeDict[] = [];
  walkTree(doc.structure ?? [], node => out.push(node));
  return out;
}
