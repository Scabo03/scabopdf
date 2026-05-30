/** Public surface of the rendering layer. */

export type {
  ContentSegment,
  ContentPage,
  PaginatedContent,
} from './contentModel';

export { buildBaseSegments } from './buildSegments';
export {
  acousticIntroFor,
  BOXED_ROLES,
  isSyntheticContainer,
  SECTION_DIVIDER_ROLE,
} from './roleStyle';
export { buildContinuousLayout } from './layouts/continuous';
export { buildQuickConsultLayout } from './layouts/quickConsult';
export { buildDoctrineInlineLayout } from './layouts/doctrineInline';

export { paginate, DEFAULT_SEGMENTS_PER_PAGE } from './pagination';

import type { LayoutId, ScabopdfDocument } from '../consumption';
import type { ContentSegment } from './contentModel';
import { buildContinuousLayout } from './layouts/continuous';
import { buildDoctrineInlineLayout } from './layouts/doctrineInline';
import { buildQuickConsultLayout } from './layouts/quickConsult';

/** Dispatches a document to the requested layout's builder. */
export function buildLayout(
  doc: ScabopdfDocument,
  layout: LayoutId,
): ContentSegment[] {
  switch (layout) {
    case 'continuous':
      return buildContinuousLayout(doc);
    case 'quick':
      return buildQuickConsultLayout(doc);
    case 'doctrine':
      return buildDoctrineInlineLayout(doc);
  }
}
