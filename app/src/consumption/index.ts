/**
 * Public surface of the consumption layer: the typed contract, the loader,
 * the runtime validator, the reading-order traversal helpers and the layout
 * identifiers.
 */

// Curated re-export of the generated contract types (the file also declares
// many leaf aliases we deliberately keep internal).
export type {
  ScabopdfDocument,
  DocumentMetadata,
  DocumentProfileDict,
  TransformationDict,
  NodeDict,
  ChapterSummaryItem,
  TocGeneralItem,
  ApparatusRefDict,
  SemanticCategory,
  ApparatusRefKind,
  LengthCategory,
} from './schema.generated';

export { validateAgainstSchema } from './validate';
export type { SchemaValidationError } from './validate';

export { parseDocument, SUPPORTED_SCHEMA_VERSION } from './document';
export type { DocumentLoadError, DocumentLoadResult } from './document';

export { walkTree, flattenToReadingOrder } from './traversal';
export type { NodeVisitor } from './traversal';

export { LAYOUT_IDS, LAYOUT_DISPLAY_NAMES } from './layout';
export type { LayoutId } from './layout';
