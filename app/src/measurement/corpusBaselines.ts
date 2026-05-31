/**
 * The fixture → corpus → Layer 1 baseline registry.
 *
 * Maps each on-device capture (by its filename-derived slug) to the Layer 1
 * corpus it belongs to and the committed baseline file under
 * pipeline/tests/snapshots/ that carries a `category_counts` map. The baselines
 * are produced by the Python corpus profiles; this registry is the one place
 * that records which baseline file is the structural oracle for which fixture.
 *
 * Not every fixture has a structural baseline: several Layer 1 snapshot families
 * (p040 matches-score, p019/p021 cross-ref digests) carry no category_counts,
 * and a few corpora (e.g. Tesauro, Mandrioli Vol. II/IV) have no full-document
 * structural snapshot at all. Those entries set baselineFile=null and the
 * comparison degrades to a one-sided report (the Generic counts only). The slug
 * and corpus id are content-free; no document text is referenced here.
 */

/** A baseline file under pipeline/tests/snapshots/ (relative name only). */
export interface CorpusBaselineEntry {
  /** Capture basename without the .capture.json suffix (the fixture slug). */
  captureSlug: string;
  /** Layer 1 corpus identifier (matches the baseline naming family). */
  corpusId: string;
  /**
   * Baseline filename under pipeline/tests/snapshots/ that carries
   * `category_counts`, or null when no structural baseline exists for it.
   */
  baselineFile: string | null;
  /** Why there is no structural baseline (only set when baselineFile is null). */
  note?: string;
}

/**
 * The seven seeded fixtures. The four with a baseline use the snapshot that
 * carries `category_counts`; where two snapshots cover the same corpus (Marrone
 * has both p014 and p018, with byte-identical category_counts) the earliest
 * structural snapshot (p014, the Phase-1 full-document summary) is chosen.
 */
export const CORPUS_BASELINES: readonly CorpusBaselineEntry[] = [
  {
    captureSlug: 'compendio_di_diritto_tributario_9788859825753_pdf',
    corpusId: 'tesauro',
    baselineFile: null,
    note: 'only a p040 matches-score snapshot exists for Tesauro; no category_counts baseline.',
  },
  {
    captureSlug: 'corso_di_diritto_processuale_civile_i_9791221112382_pdf',
    corpusId: 'mandrioli_vol_i',
    baselineFile: 'p018_baseline_mandrioli_vol_i.json',
  },
  {
    captureSlug: 'corso_di_diritto_processuale_civile_ii_9791221112399_pdf',
    corpusId: 'mandrioli_vol_ii',
    baselineFile: null,
    note: 'no Vol. II structural snapshot in pipeline/tests/snapshots (only Vol. I and Vol. III).',
  },
  {
    captureSlug:
      'diritto_internazionale_privato_e_processuale_i_9788859826859_pdf',
    corpusId: 'mosconi',
    baselineFile: 'p019_baseline_mosconi.json',
  },
  {
    captureSlug: 'diritto_processuale_civile_vol_iv_9791221112924_pdf',
    corpusId: 'mandrioli_vol_iv',
    baselineFile: null,
    note: 'no Vol. IV structural snapshot in pipeline/tests/snapshots (only Vol. I and Vol. III).',
  },
  {
    captureSlug: 'manuale_del_marrone_pdf',
    corpusId: 'marrone',
    baselineFile: 'p014_baseline_marrone.json',
  },
  {
    captureSlug: 'manuale_di_diritto_privato_9788828829546_pdf',
    corpusId: 'torrente',
    baselineFile: 'p019_baseline_torrente.json',
  },
];

/** Looks up the registry entry for a capture slug, or undefined if unknown. */
export function corpusEntryForSlug(
  slug: string,
): CorpusBaselineEntry | undefined {
  return CORPUS_BASELINES.find(e => e.captureSlug === slug);
}

/**
 * Extracts the `category_counts` map from a parsed Layer 1 baseline object.
 * Returns null when the object carries no category_counts (e.g. a matches-score
 * or pure-digest snapshot), so the caller degrades to a one-sided report rather
 * than inventing data.
 */
export function extractCategoryCounts(
  parsedBaseline: unknown,
): Record<string, number> | null {
  if (typeof parsedBaseline !== 'object' || parsedBaseline === null) {
    return null;
  }
  const counts = (parsedBaseline as { category_counts?: unknown })
    .category_counts;
  if (typeof counts !== 'object' || counts === null) {
    return null;
  }
  const out: Record<string, number> = {};
  for (const [key, value] of Object.entries(counts)) {
    if (typeof value === 'number' && Number.isFinite(value)) {
      out[key] = value;
    }
  }
  return out;
}
