//
//  TraversalDeepTests.swift
//  ScaboCoreTests
//
//  XCTest translation of the TypeScript oracle
//  `app/src/consumption/__tests__/traversalDeep.test.ts` (77 LOC).
//
//  The TS regression proves the iterative `walkTree` does not overflow on a
//  deeply nested document (the recursive predecessor threw around ~4300 frames).
//  The Swift `walkTree` is likewise iterative, so the walk itself is bounded by
//  the heap.
//
//  Swift-specific divergence, documented rather than silenced (Piano § 4): a
//  20000-deep chain of *value* structs is also deallocated recursively by ARC
//  when it goes out of scope — a concern absent in JS (garbage collected). That
//  teardown recursion, not `walkTree`, is what could overflow the default test
//  stack. The deep test therefore builds, walks AND lets the chain deallocate on
//  a worker `Thread` with an enlarged stack; `walkTree`'s iterative nature
//  remains the behaviour under test (it completes at a depth far beyond any
//  recursive Swift stack at the default size). The chain is kept local to the
//  worker so it never deallocates on the small test-runner stack.
//

import XCTest
@testable import ScaboCore

final class TraversalDeepTests: XCTestCase {

    /// Runs `body` on a thread with a large stack and waits for it to finish.
    private func onLargeStack(_ body: @escaping () -> Void) {
        let done = DispatchSemaphore(value: 0)
        let thread = Thread {
            body()
            done.signal()
        }
        thread.stackSize = 64 * 1024 * 1024 // 64 MiB
        thread.start()
        done.wait()
    }

    /// TS: walkTree deep nesting "visits a 20000-deep linear chain without
    /// overflowing the stack".
    func test_walkTree_deepLinearChain_doesNotOverflow() {
        var count = 0
        var maxDepth = 0

        onLargeStack {
            // Build the chain bottom-up, exactly like the TS. `NodeDict` is a
            // value type whose `children` array is copy-on-write, so each step
            // is O(1) and the whole build is O(n).
            var leaf = NodeDict(id: "node_20000", type: .BODY, page_index: 0, text: "x")
            var i = 19999
            while i >= 0 {
                leaf = NodeDict(id: "node_\(i)", type: .BODY, page_index: 0, text: "x", children: [leaf])
                i -= 1
            }

            walkTree([leaf]) { _, depth, _ in
                count += 1
                if depth > maxDepth { maxDepth = depth }
            }
            // `leaf` deallocates here, on the 64 MiB worker stack.
        }

        XCTAssertEqual(count, 20001)
        XCTAssertEqual(maxDepth, 20000)
    }

    /// TS: walkTree deep nesting "preserves pre-order, depth and parent on a
    /// branching tree". Uses arbitrary id strings (a/a1/...): `walkTree`
    /// traverses in-memory nodes and never inspects the id pattern.
    func test_walkTree_branchingTree_preservesPreOrderDepthParent() {
        let tree: [NodeDict] = [
            NodeDict(
                id: "a",
                type: .HEADING_1,
                page_index: 0,
                text: "A",
                children: [
                    NodeDict(id: "a1", type: .BODY, page_index: 0, text: "A1"),
                    NodeDict(
                        id: "a2",
                        type: .BODY,
                        page_index: 0,
                        text: "A2",
                        children: [
                            NodeDict(id: "a2a", type: .BODY, page_index: 0, text: "A2A"),
                        ]
                    ),
                ]
            ),
            NodeDict(id: "b", type: .BODY, page_index: 0, text: "B"),
        ]

        struct Visit: Equatable { let id: String; let depth: Int; let parent: String? }
        var visited: [Visit] = []
        walkTree(tree) { node, depth, parent in
            visited.append(Visit(id: node.id, depth: depth, parent: parent?.id))
        }

        XCTAssertEqual(visited, [
            Visit(id: "a", depth: 0, parent: nil),
            Visit(id: "a1", depth: 1, parent: "a"),
            Visit(id: "a2", depth: 1, parent: "a"),
            Visit(id: "a2a", depth: 2, parent: "a2"),
            Visit(id: "b", depth: 0, parent: nil),
        ])
    }
}
