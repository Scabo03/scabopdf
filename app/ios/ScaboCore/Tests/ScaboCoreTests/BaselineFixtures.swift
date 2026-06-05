//
//  BaselineFixtures.swift
//  ScaboCoreTests
//
//  Loader for the Layer-1 baseline JSON files committed under
//  pipeline/tests/snapshots/. Faithful translation of
//  `app/src/rendering/__tests__/baselineFixtures.ts`.
//
//  They are full Layer-1 emissions for real, public-domain Italian legal texts
//  (Akoma Ntoso XML and IPZS EPUB backends), so they exercise the rendering layer
//  against the same complexity Layer 1 produces.
//
//  Like the TS, the fixtures live OUTSIDE the app/library tree and are read from
//  disk at test time rather than copied in (avoiding multi-MB duplication). The
//  TS resolves them from `__dirname`; here the snapshots directory is derived from
//  `#filePath` of this source — this file lives at
//  <repo>/app/ios/ScaboCore/Tests/ScaboCoreTests/BaselineFixtures.swift, so six
//  parent steps reach the repo root. This evaluates at build time to the local
//  checkout path, which is correct for `swift test` run in the same sandbox.
//
//  Two TS preprocessing steps and their Swift equivalents:
//   * The capture script adds top-level `_baseline_*` debug fields, which the TS
//     strips because `additionalProperties: false`. Swift's `JSONDecoder` ignores
//     unknown keys by default, so no stripping is needed.
//   * The capture script omits `document_id` (otherwise a random per-run UUID) to
//     keep baselines byte-stable; the schema requires it. As in the TS, a
//     deterministic placeholder is injected before parsing.
//
//  If the snapshots directory is absent (e.g. a partial checkout), the loader
//  throws `XCTSkip` so the suite stays green, per the project fixture convention
//  in CLAUDE.md. A present-but-invalid baseline is a real failure, not a skip.
//

import XCTest
@testable import ScaboCore

enum BaselineFixtureError: Error {
    case parseFailed(String, DocumentLoadError)
}

let SNAPSHOTS_DIR: URL = {
    var url = URL(fileURLWithPath: #filePath)
    for _ in 0..<6 { url.deleteLastPathComponent() }
    return url.appendingPathComponent("pipeline/tests/snapshots")
}()

/// Loads and parses a committed Layer-1 baseline into a `ScabopdfDocument`.
/// Throws `XCTSkip` when the file is missing.
func loadBaselineDocument(_ filename: String) throws -> ScabopdfDocument {
    let url = SNAPSHOTS_DIR.appendingPathComponent(filename)
    guard FileManager.default.fileExists(atPath: url.path) else {
        throw XCTSkip(
            "Baseline \(filename) not present at \(url.path). "
            + "It ships under pipeline/tests/snapshots/ on a full checkout."
        )
    }

    let raw = try Data(contentsOf: url)
    // Inject document_id when absent (the capture script strips it). _baseline_*
    // top-level fields are left in place — the decoder ignores unknown keys.
    var object = try JSONSerialization.jsonObject(with: raw) as! [String: Any]
    if object["document_id"] == nil {
        object["document_id"] = "00000000-0000-4000-8000-000000000000"
    }
    let injected = try JSONSerialization.data(withJSONObject: object)

    switch parseDocument(injected) {
    case .success(let document, _):
        return document
    case .failure(let error):
        throw BaselineFixtureError.parseFailed(filename, error)
    }
}

/// The fixtures used by the rendering layout tests. Chosen to cover the smallest
/// XML AKN + EPUB IPZS fixtures (fast happy path), mid-size fixtures (more
/// typographic variety), and legge_capitali (AMENDMENT / QUOTED_TEXT_* /
/// UPDATE_BLOCK — categories introduced in schema 0.7.0).
let BASELINE_FIXTURES: [String] = [
    "xml_akn_baseline_legge_56_2007.json",
    "xml_akn_baseline_legge_gelli_bianco.json",
    "xml_akn_baseline_legge_capitali.json",
    "epub_ipzs_baseline_legge_56_2007.json",
    "epub_ipzs_baseline_legge_gelli_bianco.json",
]
