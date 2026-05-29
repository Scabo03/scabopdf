/**
 * Slices a layout's flat segment stream into pages for the native ReadingView.
 *
 * v1 paginates by a fixed segment count: simple, deterministic, layout-aware
 * by virtue of being applied to the per-layout stream. The real page-size
 * heuristic (segments fitting the viewport at the active font size, with text
 * measurement from the native side) is a polish — the native view's
 * accessibilityScroll path already gives JS the opportunity to re-paginate
 * dynamically, and the design doc reserves that knob.
 */

import type {
  ContentPage,
  ContentSegment,
  PaginatedContent,
} from './contentModel';

/** Heuristic default. Refined later with on-device measurements. */
export const DEFAULT_SEGMENTS_PER_PAGE = 20;

export function paginate(
  segments: ContentSegment[],
  segmentsPerPage: number = DEFAULT_SEGMENTS_PER_PAGE,
): PaginatedContent {
  if (segmentsPerPage <= 0) {
    throw new Error(`segmentsPerPage must be > 0, got ${segmentsPerPage}`);
  }
  const pages: ContentPage[] = [];
  for (let i = 0; i < segments.length; i += segmentsPerPage) {
    pages.push({
      pageNumber: Math.floor(i / segmentsPerPage) + 1,
      segments: segments.slice(i, i + segmentsPerPage),
    });
  }
  if (pages.length === 0) {
    pages.push({ pageNumber: 1, segments: [] });
  }
  return { pages, totalSegments: segments.length };
}
