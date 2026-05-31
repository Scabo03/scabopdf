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

export {
  extractPdf,
  totalLines,
  summarizeLine,
  type PdfExtraction,
  type PdfPageExtraction,
  type PdfTextLine,
  type PdfSpan,
  type BBox,
  type LineSummary,
} from './pdfExtraction';

export {
  logEvent,
  logError,
  snapshot,
  isTestMode,
  subsystem,
  LogCategory,
  type LogLevel,
  type LogMetadata,
} from './diag';
