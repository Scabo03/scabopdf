/**
 * Public ReadingView wrapper around the Codegen-generated Fabric component.
 *
 * Callers in the rest of the app import this; they never touch the generated
 * artifact. The wrapper narrows the event direction from a string to a typed
 * union and guards against being rendered on Android (deferred — see
 * LAYER2_NATIVE_READING_MODULE.md section 8).
 */

import { Platform, type ViewProps } from 'react-native';
import ScaboReadingViewNativeComponent, {
  type PageChangeEvent,
  type ReadingSegment,
} from './ScaboReadingViewNativeComponent';

export type { ReadingSegment };
export type PageChangeDirection = 'next' | 'previous';

export interface ReadingViewProps extends ViewProps {
  /** The current page as an ordered list of renderable segments. */
  pageContent: readonly ReadingSegment[];
  /** Logical 1-based page number echoed back in page-change events. */
  pageNumber: number;
  /** Body text color (hex). */
  textColor?: string;
  /** Body font size in pt. */
  bodyFontSize?: number;
  /**
   * Called when VoiceOver finishes the current page; JS advances and pushes
   * the next page back via `pageContent`/`pageNumber`.
   */
  onRequestPageChange?: (
    direction: PageChangeDirection,
    fromPage: number,
  ) => void;
}

export function ReadingView({
  onRequestPageChange,
  ...rest
}: ReadingViewProps) {
  if (Platform.OS !== 'ios') {
    return null;
  }

  return (
    <ScaboReadingViewNativeComponent
      {...rest}
      onRequestPageChange={
        onRequestPageChange === undefined
          ? undefined
          : event => forwardPageChange(event.nativeEvent, onRequestPageChange)
      }
    />
  );
}

function forwardPageChange(
  payload: PageChangeEvent,
  callback: (direction: PageChangeDirection, fromPage: number) => void,
): void {
  const { direction, fromPage } = payload;
  if (direction === 'next' || direction === 'previous') {
    callback(direction, fromPage);
  }
}
