/**
 * Q2 role differentiation. Unit tests for the acoustic-intro mapping plus a
 * validation against the real Layer 1 baselines proving the modification roles
 * are no longer acoustically undifferentiated from body prose (the audit's
 * 37.65%-fall-through finding, up to 90% on dlgs_cartabia).
 */

import { acousticIntroFor, BOXED_ROLES } from '../roleStyle';
import { buildBaseSegments } from '../index';
import { loadBaselineDocument } from './baselineFixtures';

describe('acousticIntroFor', () => {
  test('maps each modification role to a distinct spoken intro', () => {
    expect(acousticIntroFor('AMENDMENT', '')).toBe('Modifica.');
    expect(acousticIntroFor('QUOTED_TEXT_OLD', '')).toBe('Testo previgente.');
    expect(acousticIntroFor('QUOTED_TEXT_NEW', '')).toBe('Nuovo testo.');
    expect(acousticIntroFor('UPDATE_BLOCK', '')).toBe('Aggiornamento.');
    expect(acousticIntroFor('EDITORIAL_NOTE', '')).toBe('Nota editoriale.');
    // The four box roles get four distinct intros (a blind jurist can tell
    // amendment / old / new / update apart, the Normattiva-level requirement).
    const intros = new Set([...BOXED_ROLES].map(r => acousticIntroFor(r, '')));
    expect(intros.size).toBe(BOXED_ROLES.size);
  });

  test('NOTE folds its length regime into the intro', () => {
    expect(acousticIntroFor('NOTE', 'SHORT')).toBe('Nota.');
    expect(acousticIntroFor('NOTE', 'LONG')).toBe('Nota lunga.');
    expect(acousticIntroFor('NOTE', 'VERY_LONG')).toBe('Nota lunga.');
    expect(acousticIntroFor('NOTE', 'MEGA')).toBe('Nota molto lunga.');
  });

  test('body / article / heading / list roles get no acoustic prefix', () => {
    for (const r of [
      'BODY',
      'ARTICLE_BODY',
      'ARTICLE_HEADER',
      'HEADING_1',
      'LIST_ITEM',
      '',
    ]) {
      expect(acousticIntroFor(r, '')).toBe('');
    }
  });
});

describe('role distinction is effective on real baselines', () => {
  test('dlgs_cartabia: every modification segment carries an intro', () => {
    const segs = buildBaseSegments(
      loadBaselineDocument('xml_akn_baseline_dlgs_cartabia.json'),
    );
    const modSegs = segs.filter(s =>
      [
        'AMENDMENT',
        'QUOTED_TEXT_OLD',
        'QUOTED_TEXT_NEW',
        'UPDATE_BLOCK',
      ].includes(s.role),
    );
    expect(modSegs.length).toBeGreaterThan(1000); // the doc is modification-heavy
    expect(modSegs.every(s => s.acousticIntro.length > 0)).toBe(true);

    // The audit found ~90% of this doc's segments undifferentiated. After Q2
    // only body/article prose and list items lack an acoustic intro; assert the
    // undifferentiated-and-unstyled share collapsed well below that.
    const stylelessRoles = new Set(['ARTICLE_BODY', 'BODY']);
    const undifferentiated = segs.filter(
      s => s.acousticIntro === '' && stylelessRoles.has(s.role),
    );
    // ARTICLE_BODY prose is *correctly* read as body; what matters is that the
    // modification family (previously undifferentiated) is now all intro'd.
    const intro = segs.filter(s => s.acousticIntro.length > 0).length;
    expect(intro).toBeGreaterThan(undifferentiated.length * 0.5);
  });

  test('legge_capitali: intros line up one-to-one with roles', () => {
    const segs = buildBaseSegments(
      loadBaselineDocument('xml_akn_baseline_legge_capitali.json'),
    );
    for (const s of segs) {
      expect(s.acousticIntro).toBe(acousticIntroFor(s.role, s.lengthCategory));
    }
  });
});
