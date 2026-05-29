/**
 * Rendering integration tests: run each of the three layouts on a curated set
 * of real Layer 1 baselines (XML AKN + EPUB IPZS), assert structural shape.
 */

import {
  buildContinuousLayout,
  buildDoctrineInlineLayout,
  buildLayout,
  buildQuickConsultLayout,
  DEFAULT_SEGMENTS_PER_PAGE,
  paginate,
} from '../index';
import { BASELINE_FIXTURES, loadBaselineDocument } from './baselineFixtures';

describe.each(BASELINE_FIXTURES)('layouts on %s', file => {
  test('document parses and continuous yields at least one segment', () => {
    const doc = loadBaselineDocument(file);
    const segments = buildContinuousLayout(doc);
    expect(segments.length).toBeGreaterThan(0);
    for (const segment of segments.slice(0, 50)) {
      expect(segment.id).toMatch(/^node_\d+$/);
      expect(typeof segment.role).toBe('string');
      expect(segment.role.length).toBeGreaterThan(0);
      expect(segment.text.length).toBeGreaterThan(0);
    }
  });

  test('quickConsult drops NOTE / EDITORIAL_NOTE segments', () => {
    const doc = loadBaselineDocument(file);
    const continuous = buildContinuousLayout(doc);
    const quick = buildQuickConsultLayout(doc);
    expect(quick.length).toBeLessThanOrEqual(continuous.length);
    for (const segment of quick) {
      expect(segment.role).not.toBe('NOTE');
      expect(segment.role).not.toBe('EDITORIAL_NOTE');
    }
  });

  test('doctrine v1 matches continuous (sentence-level inline deferred)', () => {
    const doc = loadBaselineDocument(file);
    expect(buildDoctrineInlineLayout(doc).length).toBe(
      buildContinuousLayout(doc).length,
    );
  });

  test('paginate yields sequential 1-based page numbers and covers all segments', () => {
    const doc = loadBaselineDocument(file);
    const stream = buildContinuousLayout(doc);
    const { pages, totalSegments } = paginate(stream);
    expect(totalSegments).toBe(stream.length);
    expect(pages.length).toBeGreaterThan(0);
    pages.forEach((page, i) => {
      expect(page.pageNumber).toBe(i + 1);
    });
    const recovered = pages.flatMap(p => p.segments);
    expect(recovered.length).toBe(stream.length);
  });
});

describe('layout-specific spot checks', () => {
  test('NOTE segments carry length_category when present (legge_capitali)', () => {
    const doc = loadBaselineDocument('xml_akn_baseline_legge_capitali.json');
    const noteSegments = buildContinuousLayout(doc).filter(
      s => s.role === 'NOTE',
    );
    if (noteSegments.length > 0) {
      const valid = new Set([
        '',
        'MICRO',
        'SHORT',
        'MEDIUM',
        'LONG',
        'VERY_LONG',
        'MEGA',
      ]);
      for (const seg of noteSegments) {
        expect(valid.has(seg.lengthCategory)).toBe(true);
      }
    }
  });

  test('legge_capitali XML exposes AMENDMENT-family categories (schema 0.7.0)', () => {
    const doc = loadBaselineDocument('xml_akn_baseline_legge_capitali.json');
    const roles = new Set(buildContinuousLayout(doc).map(s => s.role));
    // legge_capitali is the calibration fixture for AKN modifications
    // (pattern (bbbb)). It must light up AMENDMENT and UPDATE_BLOCK at least.
    expect(roles.has('AMENDMENT')).toBe(true);
    expect(roles.has('UPDATE_BLOCK')).toBe(true);
  });

  test('buildLayout dispatcher routes to the right builder', () => {
    const doc = loadBaselineDocument('xml_akn_baseline_legge_56_2007.json');
    expect(buildLayout(doc, 'continuous').length).toBe(
      buildContinuousLayout(doc).length,
    );
    expect(buildLayout(doc, 'quick').length).toBe(
      buildQuickConsultLayout(doc).length,
    );
    expect(buildLayout(doc, 'doctrine').length).toBe(
      buildDoctrineInlineLayout(doc).length,
    );
  });

  test('pagination respects the segmentsPerPage knob', () => {
    const doc = loadBaselineDocument('xml_akn_baseline_legge_56_2007.json');
    const stream = buildContinuousLayout(doc);
    const small = paginate(stream, 1);
    expect(small.pages.length).toBe(stream.length || 1);
  });

  test('paginate of an empty stream still yields one empty page', () => {
    const empty = paginate([], DEFAULT_SEGMENTS_PER_PAGE);
    expect(empty.pages.length).toBe(1);
    expect(empty.pages[0]?.pageNumber).toBe(1);
    expect(empty.pages[0]?.segments.length).toBe(0);
  });
});
