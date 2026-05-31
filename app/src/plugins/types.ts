/**
 * On-device extraction plugins.
 *
 * These mirror, on Layer 2, the role the Python ProfilePlugin family plays in
 * Layer 1: each plugin recognises a corpus and turns a raw PDF extraction into
 * the reading Document the rest of the app already consumes. The app then runs
 * `buildLayout` / `paginate` / `ReadingView` over that Document unchanged — the
 * PDF path and the .scabopdf.json path converge on the same model.
 *
 * This session ships only the corpus-agnostic "Generic" plugin. Future plugins
 * (AKN, EPUB, Giuffré codici, …) subclass nothing — they implement this small
 * interface and register in the dispatcher; the highest-confidence match wins,
 * with Generic as the always-eligible fallback.
 */

import type { ScabopdfDocument } from '../consumption';
import type { PdfExtraction } from '../native/pdfExtraction';

export interface ExtractionPlugin {
  /** Stable identifier; mirrors a Layer 1 profile_id. */
  readonly id: string;
  /** Human-facing Italian label, for diagnostics / warnings. */
  readonly label: string;
  /**
   * Confidence in [0, 1] that this plugin should own the extraction. The
   * dispatcher selects the highest scorer above the dispatch threshold and
   * falls back to Generic otherwise.
   */
  matches(extraction: PdfExtraction): number;
  /** Builds the reading Document from the extraction. */
  build(extraction: PdfExtraction, sourceName: string): ScabopdfDocument;
}
