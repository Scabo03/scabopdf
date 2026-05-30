/**
 * Regression test for the iterative walkTree: a deeply nested (schema-valid)
 * document must not overflow the call stack. The recursive predecessor threw
 * RangeError around ~4300 frames (lower on Hermes); the explicit work-list is
 * bounded by the heap. Also re-asserts pre-order on a small branching tree so
 * the iterative rewrite preserves the visit order the recursive one had.
 */

import { walkTree, type NodeDict } from '../index';

describe('walkTree deep nesting', () => {
  test('visits a 20000-deep linear chain without overflowing the stack', () => {
    let leaf: NodeDict = {
      id: 'node_20000',
      type: 'BODY',
      page_index: 0,
      text: 'x',
    };
    for (let i = 19999; i >= 0; i--) {
      leaf = {
        id: `node_${i}`,
        type: 'BODY',
        page_index: 0,
        text: 'x',
        children: [leaf],
      };
    }

    let count = 0;
    let maxDepth = 0;
    expect(() =>
      walkTree([leaf], (_node, depth) => {
        count += 1;
        if (depth > maxDepth) {
          maxDepth = depth;
        }
      }),
    ).not.toThrow();
    expect(count).toBe(20001);
    expect(maxDepth).toBe(20000);
  });

  test('preserves pre-order, depth and parent on a branching tree', () => {
    const tree: NodeDict[] = [
      {
        id: 'a',
        type: 'HEADING_1',
        page_index: 0,
        text: 'A',
        children: [
          { id: 'a1', type: 'BODY', page_index: 0, text: 'A1' },
          {
            id: 'a2',
            type: 'BODY',
            page_index: 0,
            text: 'A2',
            children: [{ id: 'a2a', type: 'BODY', page_index: 0, text: 'A2A' }],
          },
        ],
      },
      { id: 'b', type: 'BODY', page_index: 0, text: 'B' },
    ];

    const visited: Array<[string, number, string | null]> = [];
    walkTree(tree, (node, depth, parent) => {
      visited.push([node.id, depth, parent?.id ?? null]);
    });

    expect(visited).toEqual([
      ['a', 0, null],
      ['a1', 1, 'a'],
      ['a2', 1, 'a'],
      ['a2a', 2, 'a2'],
      ['b', 0, null],
    ]);
  });
});
