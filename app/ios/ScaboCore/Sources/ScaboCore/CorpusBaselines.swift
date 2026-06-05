//
//  CorpusBaselines.swift
//  ScaboCore
//
//  The fixture → corpus → Layer 1 baseline registry. Faithful translation of
//  `app/src/measurement/corpusBaselines.ts`, preserved AS-IS.
//
//  Maps each on-device capture (by its filename-derived slug) to the Layer 1
//  corpus it belongs to and the committed baseline file under
//  pipeline/tests/snapshots/ that carries a `category_counts` map. Not every
//  fixture has a structural baseline (some snapshot families carry no
//  category_counts, and a few corpora have no full-document structural snapshot);
//  those set `baselineFile = nil` and the comparison degrades to a one-sided
//  report. The slug and corpus id are content-free.
//

import Foundation

/// A baseline file under pipeline/tests/snapshots/ (relative name only).
public struct CorpusBaselineEntry: Equatable, Sendable {
    /// Capture basename without the .capture.json suffix (the fixture slug).
    public var captureSlug: String
    /// Layer 1 corpus identifier (matches the baseline naming family).
    public var corpusId: String
    /// Baseline filename carrying `category_counts`, or nil when none exists.
    public var baselineFile: String?
    /// Why there is no structural baseline (only set when baselineFile is nil).
    public var note: String?

    public init(captureSlug: String, corpusId: String, baselineFile: String?, note: String? = nil) {
        self.captureSlug = captureSlug
        self.corpusId = corpusId
        self.baselineFile = baselineFile
        self.note = note
    }
}

/// The seven seeded fixtures. The four with a baseline use the snapshot carrying
/// `category_counts`; where two snapshots cover a corpus the earliest structural
/// snapshot is chosen. Verbatim from corpusBaselines.ts.
public let CORPUS_BASELINES: [CorpusBaselineEntry] = [
    CorpusBaselineEntry(
        captureSlug: "compendio_di_diritto_tributario_9788859825753_pdf",
        corpusId: "tesauro",
        baselineFile: nil,
        note: "only a p040 matches-score snapshot exists for Tesauro; no category_counts baseline."
    ),
    CorpusBaselineEntry(
        captureSlug: "corso_di_diritto_processuale_civile_i_9791221112382_pdf",
        corpusId: "mandrioli_vol_i",
        baselineFile: "p018_baseline_mandrioli_vol_i.json"
    ),
    CorpusBaselineEntry(
        captureSlug: "corso_di_diritto_processuale_civile_ii_9791221112399_pdf",
        corpusId: "mandrioli_vol_ii",
        baselineFile: nil,
        note: "no Vol. II structural snapshot in pipeline/tests/snapshots (only Vol. I and Vol. III)."
    ),
    CorpusBaselineEntry(
        captureSlug: "diritto_internazionale_privato_e_processuale_i_9788859826859_pdf",
        corpusId: "mosconi",
        baselineFile: "p019_baseline_mosconi.json"
    ),
    CorpusBaselineEntry(
        captureSlug: "diritto_processuale_civile_vol_iv_9791221112924_pdf",
        corpusId: "mandrioli_vol_iv",
        baselineFile: nil,
        note: "no Vol. IV structural snapshot in pipeline/tests/snapshots (only Vol. I and Vol. III)."
    ),
    CorpusBaselineEntry(
        captureSlug: "manuale_del_marrone_pdf",
        corpusId: "marrone",
        baselineFile: "p014_baseline_marrone.json"
    ),
    CorpusBaselineEntry(
        captureSlug: "manuale_di_diritto_privato_9788828829546_pdf",
        corpusId: "torrente",
        baselineFile: "p019_baseline_torrente.json"
    ),
]

/// Looks up the registry entry for a capture slug, or nil if unknown.
public func corpusEntryForSlug(_ slug: String) -> CorpusBaselineEntry? {
    CORPUS_BASELINES.first { $0.captureSlug == slug }
}

/// Extracts the `category_counts` map from a parsed Layer 1 baseline object.
/// Returns nil when the object carries no category_counts (e.g. a matches-score or
/// pure-digest snapshot), so the caller degrades to a one-sided report rather than
/// inventing data.
///
/// `parsed` is an already-decoded JSON value (`JSONSerialization` output or an
/// equivalent Swift dictionary). Mirrors the TS `unknown` input. Only finite
/// numeric values are kept; JSON booleans (which bridge to `NSNumber`) are
/// excluded, matching the TS `typeof value === 'number'` guard.
public func extractCategoryCounts(_ parsed: Any?) -> [String: Int]? {
    guard let object = parsed as? [String: Any] else { return nil }
    guard let counts = object["category_counts"] as? [String: Any] else { return nil }
    var out: [String: Int] = [:]
    for (key, value) in counts {
        if let n = finiteJSONNumber(value) {
            out[key] = Int(n)
        }
    }
    return out
}

/// Returns the numeric value of a JSON scalar, excluding booleans and non-finite
/// values; nil for anything else. (JSON booleans bridge to `NSNumber`, so they are
/// filtered via the CoreFoundation boolean type id.)
private func finiteJSONNumber(_ value: Any) -> Double? {
    guard let number = value as? NSNumber else { return nil }
    if CFGetTypeID(number) == CFBooleanGetTypeID() { return nil }
    let d = number.doubleValue
    return d.isFinite ? d : nil
}
