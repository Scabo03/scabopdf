/**
 * Loader for the Layer-1 baseline JSON files that ship under
 * pipeline/tests/snapshots/. They are full Layer-1 emissions for real,
 * public-domain Italian legal texts (Akoma Ntoso XML and IPZS EPUB
 * backends), so they make excellent integration fixtures for Layer 2 — the
 * rendering layer is exercised against the same complexity Layer 1 produces.
 *
 * The committed baselines add a few `_baseline_*` debug fields at the top
 * level (id, source path, structural verdict). Those violate the schema's
 * `additionalProperties: false` rule, so we strip them before validating.
 *
 * The fixtures live OUTSIDE app/ and we read them from disk at test time
 * rather than copying their text into the Layer-2 tree (the text comes from
 * statutes that are public domain, but we still avoid duplication).
 */

import { readFileSync } from 'node:fs';
import path from 'node:path';

import { parseDocument } from '../../consumption';
import type { ScabopdfDocument } from '../../consumption';

const SNAPSHOTS_DIR = path.resolve(
  __dirname,
  '..',
  '..',
  '..',
  '..',
  'pipeline',
  'tests',
  'snapshots',
);

export function loadBaselineDocument(filename: string): ScabopdfDocument {
  const fullPath = path.join(SNAPSHOTS_DIR, filename);
  const raw = readFileSync(fullPath, 'utf8');
  const parsed = JSON.parse(raw) as Record<string, unknown>;

  // Strip top-level _baseline_* debug fields the capture script adds for
  // traceability. They would otherwise fail additionalProperties: false.
  const stripped: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(parsed)) {
    if (!key.startsWith('_baseline_')) {
      stripped[key] = value;
    }
  }
  // The capture script also strips document_id to keep the baselines stable
  // byte-for-byte across runs (it is otherwise a random per-run UUID). The
  // schema requires it; inject a deterministic placeholder so validation
  // passes.
  if (stripped.document_id === undefined) {
    stripped.document_id = '00000000-0000-4000-8000-000000000000';
  }

  const result = parseDocument(stripped);
  if (!result.ok) {
    throw new Error(
      `Baseline ${filename} did not validate: ${result.error.message}`,
    );
  }
  return result.document;
}

/**
 * The fixtures used by the rendering tests. Chosen to cover:
 * - smallest XML AKN + EPUB IPZS fixtures (fast happy path),
 * - mid-size fixtures (more typographic variety),
 * - legge_capitali XML (exercises AMENDMENT / QUOTED_TEXT_* /
 *   UPDATE_BLOCK — categories introduced in schema 0.7.0).
 */
export const BASELINE_FIXTURES = [
  'xml_akn_baseline_legge_56_2007.json',
  'xml_akn_baseline_legge_gelli_bianco.json',
  'xml_akn_baseline_legge_capitali.json',
  'epub_ipzs_baseline_legge_56_2007.json',
  'epub_ipzs_baseline_legge_gelli_bianco.json',
] as const;
