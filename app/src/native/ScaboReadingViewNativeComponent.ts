/**
 * Codegen spec for the Fabric Native Component that hosts the reading view.
 *
 * Naming convention: the file MUST end with NativeComponent.ts for Codegen to
 * detect it. The component name 'ScaboReadingView' is what Codegen emits and
 * what the iOS RCTViewComponentView subclass binds to.
 *
 * The prop surface is intentionally minimal in Fase 4: pageContent (the
 * current page as an ordered list of segments) plus a few style props and one
 * direct event for page-turn requests. The content-model shape is finalised
 * in Fase 5 (LAYER2_NATIVE_READING_MODULE.md decision 3).
 */

// These deep imports are the canonical Codegen entry points; they have no
// top-level re-export and are documented by React Native as such.
// eslint-disable-next-line @react-native/no-deep-imports
import codegenNativeComponent from 'react-native/Libraries/Utilities/codegenNativeComponent';
import type {
  DirectEventHandler,
  Float,
  Int32,
} from 'react-native/Libraries/Types/CodegenTypes';
import type { HostComponent, ViewProps } from 'react-native';

/** A single piece of renderable text in the page, with its semantic role. */
export type ReadingSegment = Readonly<{
  /**
   * Free-form role tag — values from the Layer-1 contract (e.g. 'BODY',
   * 'HEADING_1', 'NOTE', 'ARTICLE_HEADER', 'CROSS_REFERENCE'). Kept as a
   * string here so the role vocabulary can grow with Fase 5 without bumping
   * the native module API.
   */
  role: string;
  text: string;
  /**
   * The acoustic regime (length_category) for NOTE segments; empty string for
   * any other role. Native will later attach speech attributes per regime.
   */
  lengthCategory: string;
  /**
   * Spoken role intro VoiceOver reads before the text (e.g. 'Modifica.',
   * 'Nuovo testo.'); empty string when the role needs no acoustic prefix.
   */
  acousticIntro: string;
}>;

/** Payload of the onRequestPageChange event. */
export type PageChangeEvent = Readonly<{
  /** 'next' or 'previous'. */
  direction: string;
  /** The page number the request originated from. */
  fromPage: Int32;
}>;

export interface NativeProps extends ViewProps {
  /** The ordered segments to render and expose to VoiceOver for this page. */
  pageContent: ReadonlyArray<ReadingSegment>;
  /** Logical page number (1-based), used in events. */
  pageNumber: Int32;
  /** Body text color (hex). */
  textColor?: string;
  /** Body font size in pt. */
  bodyFontSize?: Float;
  /**
   * Fired from accessibilityScroll on the native side when VoiceOver finishes
   * a page. JS owns pagination and pushes the next page down as props.
   */
  onRequestPageChange?: DirectEventHandler<PageChangeEvent>;
}

export default codegenNativeComponent<NativeProps>(
  'ScaboReadingView',
) as HostComponent<NativeProps>;
