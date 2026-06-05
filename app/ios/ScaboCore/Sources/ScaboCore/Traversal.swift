//
//  Traversal.swift
//  ScaboCore
//
//  Tree-traversal helpers over the reading-order forest. Faithful translation
//  of `app/src/consumption/traversal.ts`.
//
//  `walkTree` is implemented with an explicit work-list rather than recursion,
//  for the same reason the TypeScript is: a deeply nested (but contract-valid —
//  `NodeDict.children` is unbounded) document must not overflow the call stack
//  on the render path. The iterative form is bounded by the heap. Visit order is
//  identical to a recursive pre-order walk: children are pushed in reverse so
//  siblings pop left-to-right and each node's subtree is visited before the next
//  sibling.
//

import Foundation

/// Visitor invoked for every node in pre-order (depth-first):
/// `(node, depth, parent)`. `parent` is `nil` for roots.
public typealias NodeVisitor = (_ node: NodeDict, _ depth: Int, _ parent: NodeDict?) -> Void

/// Walks `nodes` and their descendants in pre-order, calling `visit`.
public func walkTree(_ nodes: [NodeDict], _ visit: NodeVisitor) {
    struct Frame {
        let node: NodeDict
        let depth: Int
        let parent: NodeDict?
    }

    var stack: [Frame] = []

    func pushReversed(_ list: [NodeDict], _ depth: Int, _ parent: NodeDict?) {
        var i = list.count - 1
        while i >= 0 {
            stack.append(Frame(node: list[i], depth: depth, parent: parent))
            i -= 1
        }
    }

    pushReversed(nodes, 0, nil)
    while let frame = stack.popLast() {
        visit(frame.node, frame.depth, frame.parent)
        if !frame.node.children.isEmpty {
            pushReversed(frame.node.children, frame.depth + 1, frame.node)
        }
    }
}

/// Flattens the whole document into a single pre-order sequence of nodes — the
/// layout-agnostic reading order. Empty when the document has no structure.
public func flattenToReadingOrder(_ document: ScabopdfDocument) -> [NodeDict] {
    var out: [NodeDict] = []
    walkTree(document.structure) { node, _, _ in out.append(node) }
    return out
}
