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

/** Walks `nodes` and their descendants in pre-order, calling `visit`. */
export function walkTree(nodes: readonly NodeDict[], visit: NodeVisitor): void {
  const recurse = (
    current: readonly NodeDict[],
    depth: number,
    parent: NodeDict | null,
  ): void => {
    for (const node of current) {
      visit(node, depth, parent);
      const children = node.children;
      if (children !== undefined && children.length > 0) {
        recurse(children, depth + 1, node);
      }
    }
  };
  recurse(nodes, 0, null);
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
