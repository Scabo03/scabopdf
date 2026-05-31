/**
 * Plugin dispatcher: turns a raw PDF extraction into a reading Document.
 *
 * Mirrors the Layer 1 profiling dispatcher: every registered plugin scores the
 * extraction with `matches()`, the highest scorer above the threshold wins, and
 * the corpus-agnostic Generic plugin is the always-eligible fallback. This
 * session registers only Generic; new corpus plugins drop into PLUGINS.
 */

import type { ScabopdfDocument } from '../consumption';
import type { PdfExtraction } from '../native/pdfExtraction';
import { genericPlugin } from './generic';
import type { ExtractionPlugin } from './types';

export type { ExtractionPlugin } from './types';
export { genericPlugin } from './generic';
export type {
  GenericCategoryContract,
  GenericCoverage,
  GenericSignal,
} from './taxonomy';
export {
  GENERIC_TAXONOMY,
  GENERIC_TAXONOMY_ENTRIES,
  GENERIC_PRODUCED_CATEGORIES,
  GENERIC_DETECTED_SUPPRESSED_CATEGORIES,
  GENERIC_RESERVED_CATEGORIES,
  isGenericProduced,
  LAYER2_PRESENTATION_ONLY_ROLES,
} from './taxonomy';

/** Confidence a corpus plugin must clear to win over the Generic fallback. */
export const DISPATCH_THRESHOLD = 0.6;

/** Corpus-specific plugins, highest priority first. Generic is not here. */
const PLUGINS: readonly ExtractionPlugin[] = [];

/** Selects the plugin that should own the extraction. */
export function selectPlugin(extraction: PdfExtraction): ExtractionPlugin {
  let winner: ExtractionPlugin = genericPlugin;
  let best = -1;
  for (const plugin of PLUGINS) {
    const score = plugin.matches(extraction);
    if (score >= DISPATCH_THRESHOLD && score > best) {
      best = score;
      winner = plugin;
    }
  }
  return winner;
}

/** Builds the reading Document from a PDF extraction, choosing the plugin. */
export function buildDocumentFromPdf(
  extraction: PdfExtraction,
  sourceName: string,
): ScabopdfDocument {
  return selectPlugin(extraction).build(extraction, sourceName);
}
