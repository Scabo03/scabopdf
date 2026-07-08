//
//  AknDetectorTests.swift
//  ScaboCoreTests
//
//  Verifica il detector AKN Swift sui 13 fixture Normattiva reali committati
//  (calibration + exploration). Attesi: 11 OK + 2 FRAGMENTED (codice_penale,
//  codice_civile). Gira su macOS via `swift test`.
//

import XCTest
@testable import ScaboCore

final class AknDetectorTests: XCTestCase {

    // FIXTURES_DIR = <repo>/pipeline/tests/fixtures (da SNAPSHOTS_DIR di BaselineFixtures).
    private var fixturesDir: URL {
        SNAPSHOTS_DIR.deletingLastPathComponent().appendingPathComponent("fixtures")
    }

    private func xmlURL(_ group: String, _ name: String) -> URL {
        fixturesDir.appendingPathComponent("\(group)/\(name)/\(name).xml")
    }

    private let cases: [(group: String, name: String, expected: AknHealthVerdict)] = [
        ("normattiva_calibration", "legge_56_2007", .ok),
        ("normattiva_calibration", "legge_gelli_bianco", .ok),
        ("normattiva_calibration", "dlgs_231_2001", .ok),
        ("normattiva_calibration", "legge_bilancio_2023", .ok),
        ("normattiva_calibration", "codice_strada", .ok),
        ("normattiva_calibration", "codice_procedura_penale", .ok),
        ("normattiva_calibration", "tuf_dlgs_58_1998", .ok),
        ("normattiva_calibration", "codice_civile", .fragmented),
        ("normattiva_exploration", "codice_penale", .fragmented),
        ("normattiva_exploration", "legge_capitali", .ok),
        ("normattiva_exploration", "dl_rilancio", .ok),
        ("normattiva_exploration", "dlgs_cartabia", .ok),
        ("normattiva_exploration", "dlgs_correttivo_appalti", .ok),
    ]

    func test_detector_verdicts_on_13_fixtures() throws {
        for c in cases {
            let url = xmlURL(c.group, c.name)
            guard let data = try? Data(contentsOf: url) else {
                throw XCTSkip("fixture assente: \(url.path)")
            }
            let report = detectAknHealth(data)
            XCTAssertEqual(report.verdict, c.expected,
                "\(c.name): atteso \(c.expected.rawValue), ottenuto \(report.verdict.rawValue) "
                + "(bodyArticles=\(report.summary?.bodyArticleCount ?? -1) "
                + "attDocs=\(report.summary?.attachmentDocCount ?? -1))")
        }
    }
}
