/**
 * Consultazione Rapida — high density, optimized for finding a specific
 * article quickly with the VoiceOver rotor.
 *
 * v1 simply drops NOTE and EDITORIAL_NOTE segments so the linear flow shows
 * only the structural body. The note content remains in the source Document
 * and can be re-surfaced later via an "expand notes" action; that polish
 * needs the on-demand UI and is deferred.
 */

import type { ScabopdfDocument } from '../../consumption';
import { buildBaseSegments } from '../buildSegments';
import type { ContentSegment } from '../contentModel';

const COLLAPSED_ROLES = new Set(['NOTE', 'EDITORIAL_NOTE']);

export function buildQuickConsultLayout(
  doc: ScabopdfDocument,
): ContentSegment[] {
  return buildBaseSegments(doc).filter(
    segment => !COLLAPSED_ROLES.has(segment.role),
  );
}
