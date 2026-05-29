/**
 * The reading layouts ScaboPDF offers.
 *
 * There are exactly THREE layouts. An earlier draft (and SPECS.md, which is
 * stale on this point) listed a fourth, "Struttura Visibile / Apparato
 * Critico"; it was dropped as redundant. The binding source is
 * LAYER2_PRODUCT_DECISIONS.md.
 *
 * Layout-specific rendering lives in the rendering layer (later phase); this
 * module only fixes the canonical identifiers and their Italian display
 * names so the rest of the app shares one source of truth.
 */

export type LayoutId = 'continuous' | 'quick' | 'doctrine';

export const LAYOUT_IDS: readonly LayoutId[] = [
  'continuous',
  'quick',
  'doctrine',
];

/** Italian display names (UI language is Italian in phase 1). */
export const LAYOUT_DISPLAY_NAMES: Readonly<Record<LayoutId, string>> = {
  continuous: 'Lettura Continua',
  quick: 'Consultazione Rapida',
  doctrine: 'Dottrina Inline',
};
