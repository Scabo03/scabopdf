/**
 * The shape of the content the native ReadingView consumes. Layout builders
 * produce a stream of these; the pagination util chunks the stream into
 * pages; the native view renders each page.
 *
 * The role field is the SemanticCategory string from the Layer 1 contract
 * (e.g. 'HEADING_1', 'BODY', 'NOTE'). It is passed verbatim to native so the
 * UIView can pick the typographic style and acoustic regime per segment.
 */

/** A single renderable, accessible chunk of text. */
export interface ContentSegment {
  /** Node id from the source document — stable identity for diffing. */
  id: string;
  /** SemanticCategory of the originating node. */
  role: string;
  /** Display text. */
  text: string;
  /**
   * Acoustic regime ('MICRO' | 'SHORT' | 'MEDIUM' | 'LONG' | 'VERY_LONG' |
   * 'MEGA') for NOTE segments; empty string for any other role. Matches the
   * native side which uses an empty string to mean "not applicable".
   */
  lengthCategory: string;
  /**
   * Spoken role intro the native view prepends before reading the text (Q2),
   * e.g. 'Modifica.' for AMENDMENT or 'Nuovo testo.' for QUOTED_TEXT_NEW.
   * Empty string for roles that need no acoustic prefix. Derived from role
   * (+ lengthCategory for NOTE) by roleStyle.acousticIntroFor.
   */
  acousticIntro: string;
}

/** A page of content delivered to the native view. */
export interface ContentPage {
  /** 1-based logical page number. */
  pageNumber: number;
  segments: ContentSegment[];
}

/** A layout's full output: an ordered list of pages. */
export interface PaginatedContent {
  pages: ContentPage[];
  totalSegments: number;
}
