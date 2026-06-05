//
//  LayoutAndSeamTests.swift
//  ScaboCoreTests
//
//  Sanity tests NOT derived from a TS oracle (the two Fase 1 oracles —
//  consumption.test.ts and traversalDeep.test.ts — do not exercise `layout.ts`
//  or the extraction seam). They are local invariants that pin the parts of the
//  consumption public surface and the § 10 seam this phase introduces, so a
//  later edit cannot silently change them. Marked explicitly as non-oracle.
//

import XCTest
@testable import ScaboCore

final class LayoutTests: XCTestCase {

    /// The canonical layouts and their order (layout.ts: LAYOUT_IDS).
    func test_layoutIds_areTheThreeCanonicalOnesInOrder() {
        XCTAssertEqual(LAYOUT_IDS, [.continuous, .quick, .doctrine])
        XCTAssertEqual(LayoutId.allCases.count, 3)
    }

    /// The Italian display names (layout.ts: LAYOUT_DISPLAY_NAMES).
    func test_layoutDisplayNames_italian() {
        XCTAssertEqual(LAYOUT_DISPLAY_NAMES[.continuous], "Lettura Continua")
        XCTAssertEqual(LAYOUT_DISPLAY_NAMES[.quick], "Consultazione Rapida")
        XCTAssertEqual(LAYOUT_DISPLAY_NAMES[.doctrine], "Dottrina Inline")
    }

    /// Raw values round-trip (`.continuous` ↔ "continuous").
    func test_layoutId_rawValues() {
        XCTAssertEqual(LayoutId(rawValue: "doctrine"), .doctrine)
        XCTAssertNil(LayoutId(rawValue: "struttura"))
    }
}

final class SeamTests: XCTestCase {

    /// The § 10 boundary type is constructible and value-equal — the contract a
    /// future PDFKit/MuPDF extractor produces and the classifier consumes.
    func test_pdfExtraction_isConstructible() {
        let extraction = PdfExtraction(
            version: 2,
            pageCount: 1,
            pages: [
                PdfPageExtraction(
                    pageIndex: 0,
                    width: 595,
                    height: 842,
                    lines: [
                        PdfTextLine(
                            spans: [
                                PdfSpan(
                                    text: "Ciao",
                                    fontSize: 12,
                                    bold: false,
                                    italic: false,
                                    color: "#000000",
                                    bbox: BBox(x: 0, y: 0, width: 30, height: 12)
                                ),
                            ],
                            bbox: BBox(x: 0, y: 0, width: 30, height: 12)
                        ),
                    ]
                ),
            ]
        )
        XCTAssertEqual(extraction.pages.first?.lines.first?.spans.first?.text, "Ciao")
        XCTAssertEqual(extraction.version, 2)
    }

    /// A stub conformer proves the seam is satisfiable without any PDF engine —
    /// the extractor stays swappable behind `PdfExtracting`.
    func test_pdfExtracting_protocolIsSatisfiable() {
        struct EmptyExtractor: PdfExtracting {
            func extract(fromUri uri: String) throws -> PdfExtraction {
                PdfExtraction(version: 2, pageCount: 0, pages: [])
            }
        }
        let extractor: PdfExtracting = EmptyExtractor()
        XCTAssertEqual(try extractor.extract(fromUri: "file:///x.pdf").pageCount, 0)
    }
}
