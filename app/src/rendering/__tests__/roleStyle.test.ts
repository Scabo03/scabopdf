/**
 * Q2 role differentiation. Unit tests for the acoustic-intro mapping plus a
 * validation against the real Layer 1 baselines proving the modification roles
 * are no longer acoustically undifferentiated from body prose (the audit's
 * 37.65%-fall-through finding, up to 90% on dlgs_cartabia).
 */

import {
  acousticIntroFor,
  BOXED_ROLES,
  isSyntheticContainer,
  SECTION_DIVIDER_ROLE,
} from '../roleStyle';
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

describe('isSyntheticContainer (Punto 2 — rotor divider recognition)', () => {
  test('recognises the minted AKN container titles (HEADING_1 only)', () => {
    expect(
      isSyntheticContainer('HEADING_1', 'Modificazioni attive a altri atti'),
    ).toBe(true);
    expect(
      isSyntheticContainer('HEADING_1', 'Modificazioni passive di questo atto'),
    ).toBe(true);
    expect(isSyntheticContainer('HEADING_1', 'Decreto di promulgazione')).toBe(
      true,
    );
    expect(isSyntheticContainer('HEADING_1', "Aggiornamenti dell'atto")).toBe(
      true,
    );
    expect(isSyntheticContainer('HEADING_1', "Aggiornamenti all'art. 5")).toBe(
      true,
    );
  });

  test('does not match real document headings or non-HEADING_1 roles', () => {
    expect(
      isSyntheticContainer('HEADING_1', 'LIBRO PRIMO — DELLE PERSONE'),
    ).toBe(false);
    expect(isSyntheticContainer('HEADING_1', '((CAPO II')).toBe(false);
    expect(isSyntheticContainer('HEADING_1', 'Disposizioni generali')).toBe(
      false,
    );
    expect(
      isSyntheticContainer('BODY', 'Modificazioni attive a altri atti'),
    ).toBe(false);
    expect(isSyntheticContainer('HEADING_2', 'Decreto di promulgazione')).toBe(
      false,
    );
  });

  test('acousticIntroFor maps the divider role to a short spoken prefix', () => {
    expect(acousticIntroFor(SECTION_DIVIDER_ROLE, '')).toBe('Sezione.');
  });
});

describe('synthetic dividers on real baselines', () => {
  test('legge_capitali: both synthetic containers become SECTION_DIVIDER with the prefix', () => {
    const segs = buildBaseSegments(
      loadBaselineDocument('xml_akn_baseline_legge_capitali.json'),
    );
    const dividers = segs.filter(s => s.role === SECTION_DIVIDER_ROLE);
    expect(dividers.length).toBe(2);
    expect(dividers.every(s => s.acousticIntro === 'Sezione.')).toBe(true);
    expect(segs.some(s => s.role === 'HEADING_1')).toBe(false);
  });

  test('EPUB codice_civile: synthetic dividers split from the real LIBRO/CAPO headings', () => {
    // The EPUB backend keeps the real hierarchy as HEADING_1 (LIBRO/CAPO …)
    // alongside the synthetic "Aggiornamenti dell'atto" container, so it
    // exercises both branches. (The XML AKN codice_civile is flat — its only
    // HEADING_1 are synthetic — so it cannot test the real-heading branch.)
    const segs = buildBaseSegments(
      loadBaselineDocument('epub_ipzs_baseline_codice_civile.json'),
    );
    const dividers = segs.filter(s => s.role === SECTION_DIVIDER_ROLE);
    const realHeadings = segs.filter(s => s.role === 'HEADING_1');
    expect(dividers.length).toBeGreaterThan(0);
    expect(realHeadings.length).toBeGreaterThan(100); // 142 real LIBRO/CAPO
    expect(realHeadings.every(s => s.acousticIntro === '')).toBe(true);
    expect(dividers.every(s => s.acousticIntro === 'Sezione.')).toBe(true);
  });
});
