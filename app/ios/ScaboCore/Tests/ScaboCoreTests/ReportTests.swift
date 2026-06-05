//
//  ReportTests.swift
//  ScaboCoreTests
//
//  XCTest translation of `app/src/measurement/__tests__/report.test.ts` (70).
//  Deterministic unit test for the report builder on the committed SYNTHETIC
//  capture (no private fixtures): pins the report schema and proves the real
//  pipeline (Generic plugin + layout + paginate) is driven end-to-end and reduced
//  to a content-free report.
//

import XCTest
@testable import ScaboCore

final class ReportTests: XCTestCase {

    private func built() throws -> BuildReportResult {
        try buildReport(try exampleCapture())
    }

    /// TS: "pins the report schema version and the source filename".
    func test_pinsSchemaAndFilename() throws {
        let report = try built().report
        XCTAssertEqual(report.reportSchemaVersion, TEST_REPORT_SCHEMA_VERSION)
        XCTAssertEqual(report.pdfFilename, "synthetic-example.pdf")
        XCTAssertEqual(report.pdfSizeBytes, 1024)
    }

    /// TS: "measures the extraction layer content-free".
    func test_measuresExtractionContentFree() throws {
        let report = try built().report
        XCTAssertEqual(report.extraction.pages, 1)
        XCTAssertEqual(report.extraction.lines, 7)
        XCTAssertEqual(report.extraction.fontSizeHistogram["10.0"], 5)
        XCTAssertEqual(report.extraction.fontSizeHistogram["16.0"], 1)
        XCTAssertEqual(report.extraction.fontSizeHistogram["8.0"], 1)
        XCTAssertEqual(report.extraction.boldLineRatio, 1.0 / 7.0, accuracy: 0.001)
    }

    /// TS: "classifies via the real Generic plugin: heading, merged body, note".
    func test_classifiesViaGeneric() throws {
        let report = try built().report
        XCTAssertEqual(report.document.profileId, "generic")
        XCTAssertEqual(report.document.nodeTotal, 3)
        XCTAssertEqual(report.document.roleCounts["HEADING_1"], 1)
        XCTAssertEqual(report.document.roleCounts["BODY"], 1)
        XCTAssertEqual(report.document.roleCounts["NOTE"], 1)
        let noteLen = report.document.noteLengthCounts.values.reduce(0, +)
        XCTAssertEqual(noteLen, 1)
        XCTAssertTrue(report.document.warnings.contains { $0.hasPrefix("plugin:generic:") })
    }

    /// TS: "produces a consumable layout".
    func test_producesLayout() throws {
        let report = try built().report
        XCTAssertEqual(report.layout.layoutId, "continuous")
        XCTAssertEqual(report.layout.segmentTotal, 3)
        XCTAssertGreaterThanOrEqual(report.layout.pagesProduced, 1)
    }

    /// TS: "records timings as numbers".
    func test_recordsTimings() throws {
        let t = try built().report.timings
        for v in [t.extractMs, t.pluginMs, t.layoutMs, t.paginateMs] {
            XCTAssertGreaterThanOrEqual(v, 0)
        }
    }

    /// TS: "keeps text only in the dump, never in the report".
    func test_textOnlyInDump() throws {
        let result = try built()
        XCTAssertGreaterThan(result.dump.document.structure.count, 0)
        let data = try JSONEncoder().encode(result.report)
        let serialised = String(data: data, encoding: .utf8)!
        XCTAssertFalse(serialised.contains("Capitolo"))
        XCTAssertFalse(serialised.contains("paragrafo"))
    }
}
