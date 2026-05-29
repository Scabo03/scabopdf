/**
 * Lettura Continua — linear flow: heading -> body -> notes after section.
 *
 * The Layer-1 tree already places notes as children of their containing
 * structural unit (HEADING_N or ARTICLE_BODY), so the pre-order base
 * traversal produces the right reading order without further work. Special
 * per-profile reorderings (DeJure massima title-first, BIC volume dedupe)
 * are deferred to a polish session — see docs/LAYER2_EDGE_CASES.md.
 */

import type { ScabopdfDocument } from '../../consumption';
import { buildBaseSegments } from '../buildSegments';
import type { ContentSegment } from '../contentModel';

export function buildContinuousLayout(doc: ScabopdfDocument): ContentSegment[] {
  return buildBaseSegments(doc);
}
