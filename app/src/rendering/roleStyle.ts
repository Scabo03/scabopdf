/**
 * Role differentiation (Q2). A blind jurist must be able to tell, at least as
 * well as on Normattiva, whether what is being read is the article text, an
 * amendment instruction, the previgent (old) text, the new text, or an update
 * note. We carry that distinction acoustically through a spoken intro phrase
 * prepended to the segment by the native view, computed here so it is pure and
 * testable against the real Layer 1 baselines.
 *
 * The intro is a parallel "role" dimension to the six MICRO→MEGA length
 * regimes: NOTE additionally folds its length_category in so a very long note
 * is announced as such before the reader commits to it (closes edge case 5).
 *
 * Visual differentiation (tinted blocks / indentation / a visible label) is
 * the native view's job — see ScaboReadingContentView.swift — keyed off the
 * same `role` string; this module owns only the spoken dimension.
 */

/** Roles framed as distinct blocks (Normattiva "box" style) on the native side. */
export const BOXED_ROLES: ReadonlySet<string> = new Set([
  'AMENDMENT',
  'QUOTED_TEXT_OLD',
  'QUOTED_TEXT_NEW',
  'UPDATE_BLOCK',
]);

/**
 * The spoken intro VoiceOver reads before a segment's text, or '' when the
 * role needs no acoustic prefix (body/article prose, headings, list items —
 * which are differentiated typographically, not acoustically).
 */
export function acousticIntroFor(role: string, lengthCategory: string): string {
  switch (role) {
    case 'AMENDMENT':
      return 'Modifica.';
    case 'QUOTED_TEXT_OLD':
      return 'Testo previgente.';
    case 'QUOTED_TEXT_NEW':
      return 'Nuovo testo.';
    case 'UPDATE_BLOCK':
      return 'Aggiornamento.';
    case 'EDITORIAL_NOTE':
      return 'Nota editoriale.';
    case 'NOTE':
      if (lengthCategory === 'MEGA') {
        return 'Nota molto lunga.';
      }
      if (lengthCategory === 'VERY_LONG' || lengthCategory === 'LONG') {
        return 'Nota lunga.';
      }
      return 'Nota.';
    default:
      return '';
  }
}
