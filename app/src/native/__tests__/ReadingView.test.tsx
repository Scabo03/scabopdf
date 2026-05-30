/**
 * Tests for the ReadingView wrapper: prop pass-through to the generated Fabric
 * host component, and the next/previous narrowing in forwardPageChange that
 * silently drops any other native direction string.
 */

import { render } from '@testing-library/react-native';
import { ReadingView, type ReadingSegment } from '../ReadingView';

const segments: ReadingSegment[] = [
  { role: 'BODY', text: 'corpo', lengthCategory: '' },
];

type HostTree = { type: string; props: Record<string, unknown> };

describe('ReadingView wrapper', () => {
  test('mounts the native ScaboReadingView and passes props through', () => {
    const { toJSON } = render(
      <ReadingView
        pageContent={segments}
        pageNumber={3}
        textColor="#101010"
        bodyFontSize={18}
      />,
    );
    const tree = toJSON() as HostTree;
    expect(tree.type).toBe('ScaboReadingView');
    expect(tree.props.pageNumber).toBe(3);
    expect(tree.props.pageContent).toEqual(segments);
    expect(tree.props.textColor).toBe('#101010');
    expect(tree.props.bodyFontSize).toBe(18);
  });

  test('leaves onRequestPageChange undefined when no callback is given', () => {
    const { toJSON } = render(
      <ReadingView pageContent={segments} pageNumber={1} />,
    );
    const tree = toJSON() as HostTree;
    expect(tree.props.onRequestPageChange).toBeUndefined();
  });

  test('forwards next/previous events and drops unknown directions', () => {
    const cb = jest.fn();
    const { toJSON } = render(
      <ReadingView
        pageContent={segments}
        pageNumber={2}
        onRequestPageChange={cb}
      />,
    );
    const tree = toJSON() as HostTree;
    const handler = tree.props.onRequestPageChange as (e: {
      nativeEvent: { direction: string; fromPage: number };
    }) => void;
    handler({ nativeEvent: { direction: 'next', fromPage: 2 } });
    handler({ nativeEvent: { direction: 'previous', fromPage: 2 } });
    handler({ nativeEvent: { direction: 'sideways', fromPage: 2 } });
    expect(cb).toHaveBeenCalledTimes(2);
    expect(cb).toHaveBeenNthCalledWith(1, 'next', 2);
    expect(cb).toHaveBeenNthCalledWith(2, 'previous', 2);
  });
});
