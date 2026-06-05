//
//  LayoutsTests.swift
//  ScaboCoreTests
//
//  XCTest translation of `app/src/rendering/__tests__/layouts.test.ts` (118 LOC):
//  the three layouts run on a curated set of real Layer 1 baselines, plus the
//  layout-specific spot checks and the pagination knob. Adds the end-to-end
//  rendering-pipeline test the Fase 2 GenericPluginTests deliberately deferred
//  (TS `generic.test.ts` "buildDocumentFromPdf flows into the rendering
//  pipeline"), now that buildLayout/paginate exist.
//
//  The TS `describe.each(BASELINE_FIXTURES)` is reproduced as a loop over
//  BASELINE_FIXTURES inside each grouped test method.
//

import XCTest
@testable import ScaboCore

final class LayoutsTests: XCTestCase {

    // MARK: describe.each(BASELINE_FIXTURES)

    /// TS: "document parses and continuous yields at least one segment".
    func test_eachFixture_continuousYieldsWellFormedSegments() throws {
        for file in BASELINE_FIXTURES {
            let doc = try loadBaselineDocument(file)
            let segments = buildContinuousLayout(doc)
            XCTAssertGreaterThan(segments.count, 0, "\(file)")
            for segment in segments.prefix(50) {
                XCTAssertNotNil(
                    segment.id.range(of: "^node_\\d+$", options: .regularExpression),
                    "\(file): id \(segment.id)"
                )
                XCTAssertGreaterThan(segment.role.count, 0, "\(file)")
                XCTAssertGreaterThan(segment.text.count, 0, "\(file)")
            }
        }
    }

    /// TS: "quickConsult drops NOTE / EDITORIAL_NOTE segments".
    func test_eachFixture_quickConsultDropsNotes() throws {
        for file in BASELINE_FIXTURES {
            let doc = try loadBaselineDocument(file)
            let continuous = buildContinuousLayout(doc)
            let quick = buildQuickConsultLayout(doc)
            XCTAssertLessThanOrEqual(quick.count, continuous.count, "\(file)")
            for segment in quick {
                XCTAssertNotEqual(segment.role, "NOTE", "\(file)")
                XCTAssertNotEqual(segment.role, "EDITORIAL_NOTE", "\(file)")
            }
        }
    }

    /// TS: "doctrine v1 matches continuous (sentence-level inline deferred)".
    func test_eachFixture_doctrineMatchesContinuous() throws {
        for file in BASELINE_FIXTURES {
            let doc = try loadBaselineDocument(file)
            XCTAssertEqual(buildDoctrineInlineLayout(doc).count, buildContinuousLayout(doc).count, "\(file)")
        }
    }

    /// TS: "paginate yields sequential 1-based page numbers and covers all segments".
    func test_eachFixture_paginateSequentialAndComplete() throws {
        for file in BASELINE_FIXTURES {
            let doc = try loadBaselineDocument(file)
            let stream = buildContinuousLayout(doc)
            let result = try paginate(stream)
            XCTAssertEqual(result.totalSegments, stream.count, "\(file)")
            XCTAssertGreaterThan(result.pages.count, 0, "\(file)")
            for (i, page) in result.pages.enumerated() {
                XCTAssertEqual(page.pageNumber, i + 1, "\(file)")
            }
            let recovered = result.pages.flatMap { $0.segments }
            XCTAssertEqual(recovered.count, stream.count, "\(file)")
        }
    }

    // MARK: layout-specific spot checks

    /// TS: "NOTE segments carry length_category when present (legge_capitali)".
    func test_spot_noteLengthCategoryValid() throws {
        let doc = try loadBaselineDocument("xml_akn_baseline_legge_capitali.json")
        let noteSegments = buildContinuousLayout(doc).filter { $0.role == "NOTE" }
        if !noteSegments.isEmpty {
            let valid: Set<String> = ["", "MICRO", "SHORT", "MEDIUM", "LONG", "VERY_LONG", "MEGA"]
            for seg in noteSegments {
                XCTAssertTrue(valid.contains(seg.lengthCategory), seg.lengthCategory)
            }
        }
    }

    /// TS: "legge_capitali XML exposes AMENDMENT-family categories (schema 0.7.0)".
    func test_spot_leggeCapitaliExposesModificationRoles() throws {
        let doc = try loadBaselineDocument("xml_akn_baseline_legge_capitali.json")
        let roles = Set(buildContinuousLayout(doc).map { $0.role })
        XCTAssertTrue(roles.contains("AMENDMENT"))
        XCTAssertTrue(roles.contains("UPDATE_BLOCK"))
    }

    /// TS: "buildLayout dispatcher routes to the right builder".
    func test_spot_dispatcherRoutesCorrectly() throws {
        let doc = try loadBaselineDocument("xml_akn_baseline_legge_56_2007.json")
        XCTAssertEqual(buildLayout(doc, .continuous).count, buildContinuousLayout(doc).count)
        XCTAssertEqual(buildLayout(doc, .quick).count, buildQuickConsultLayout(doc).count)
        XCTAssertEqual(buildLayout(doc, .doctrine).count, buildDoctrineInlineLayout(doc).count)
    }

    /// TS: "pagination respects the segmentsPerPage knob".
    func test_spot_paginationKnob() throws {
        let doc = try loadBaselineDocument("xml_akn_baseline_legge_56_2007.json")
        let stream = buildContinuousLayout(doc)
        let small = try paginate(stream, 1)
        // TS `stream.length || 1`: stream.count, or 1 when empty.
        XCTAssertEqual(small.pages.count, stream.isEmpty ? 1 : stream.count)
    }

    /// TS: "paginate of an empty stream still yields one empty page".
    func test_spot_emptyStreamOnePage() throws {
        let empty = try paginate([], DEFAULT_SEGMENTS_PER_PAGE)
        XCTAssertEqual(empty.pages.count, 1)
        XCTAssertEqual(empty.pages.first?.pageNumber, 1)
        XCTAssertEqual(empty.pages.first?.segments.count, 0)
    }

    // MARK: end-to-end PDF path → rendering pipeline (deferred from Fase 2)

    private func line(_ text: String, size: Double = 12, bold: Bool = false) -> PdfTextLine {
        PdfTextLine(
            spans: [PdfSpan(text: text, fontSize: size, bold: bold, italic: false, color: "#000000",
                            bbox: BBox(x: 0, y: 0, width: 0, height: 0))],
            bbox: BBox(x: 0, y: 0, width: 0, height: 0)
        )
    }

    private func extraction(_ pages: [[PdfTextLine]]) -> PdfExtraction {
        PdfExtraction(
            version: 2,
            pageCount: pages.count,
            pages: pages.enumerated().map { idx, lines in
                PdfPageExtraction(pageIndex: idx, width: 595, height: 842, lines: lines)
            }
        )
    }

    /// TS: generic.test.ts "buildDocumentFromPdf flows into the rendering
    /// pipeline" — the PDF path converges on the same ContentSegment model the
    /// .scabopdf.json path uses (Fase 2 GenericPluginTests left this for Fase 3).
    func test_buildDocumentFromPdf_flowsIntoRenderingPipeline() throws {
        let doc = buildDocumentFromPdf(
            extraction([[
                line("Capitolo", size: 20, bold: true),
                line("Testo del corpo del capitolo che scorre."),
                line("Seconda riga di corpo del capitolo."),
                line("Terza riga di corpo del capitolo."),
                line("Quarta riga di corpo del capitolo."),
            ]]),
            sourceName: "manuale.pdf"
        )
        let segments = buildLayout(doc, .continuous)
        let pages = try paginate(segments).pages
        XCTAssertGreaterThan(segments.count, 0)
        XCTAssertEqual(segments.first?.role, "HEADING_1")
        XCTAssertEqual(pages.first?.segments.count, segments.count)
    }
}
