/**
 * Dottrina Inline — doctrinal essays, encyclopedia entries, treatises.
 *
 * v1 is identical to the continuous layout: each NOTE segment carries its
 * length_category (MICRO..MEGA) so the audio layer can later pick the right
 * acoustic regime; the structural placement of the note is whatever the
 * Layer 1 tree produced. SPECS § 4.5 mandates per-sentence inline insertion
 * (notes moved to the end of the sentence containing the cross-reference,
 * multi-reference grouping) — that requires walking the surrounding BODY
 * text and is a polish deferred to a later session, recorded in
 * docs/LAYER2_EDGE_CASES.md.
 */

import type { ScabopdfDocument } from '../../consumption';
import { buildBaseSegments } from '../buildSegments';
import type { ContentSegment } from '../contentModel';

export function buildDoctrineInlineLayout(
  doc: ScabopdfDocument,
): ContentSegment[] {
  return buildBaseSegments(doc);
}
