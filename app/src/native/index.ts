/** Public surface of the native bridge. */

export {
  ReadingView,
  type ReadingViewProps,
  type PageChangeDirection,
  type ReadingSegment,
} from './ReadingView';

export {
  getAccessibilitySettings,
  subscribeAccessibilitySettings,
  type AccessibilitySettings,
} from './accessibilitySettings';
