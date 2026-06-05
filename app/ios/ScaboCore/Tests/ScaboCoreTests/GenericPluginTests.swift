//
//  GenericPluginTests.swift
//  ScaboCoreTests
//
//  PART A — XCTest translation of the TS oracle `app/src/plugins/__tests__/
//  generic.test.ts` (174 LOC), plus an end-to-end seam exercise.
//
//  Deliberately NOT translated: the TS test
//  "buildDocumentFromPdf flows into the rendering pipeline" calls `buildLayout`
//  / `paginate` from `../../rendering`, which is Fase 3 (the rendering layer is
//  not in ScaboCore yet). It is out of this phase's scope and will be covered
//  when Fase 3 lands rendering — not a fidelity gap, a scope boundary.
//
//  FIDELITY over improvement: these assertions pin the Generic's behaviour,
//  collapse included (e.g. the "unique ids" case where the body size estimate
//  lands on the heading size — the test asserts ids, not types, exactly as the
//  TS does).
//

import XCTest
@testable import ScaboCore

final class GenericPluginTests: XCTestCase {

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

    // MARK: genericPlugin.build

    /// TS: "classifies a larger short line as a heading and prose as body".
    func test_build_headingThenMergedBody() {
        let doc = genericPlugin.build(
            extraction([[
                line("Capitolo Primo", size: 20, bold: true),
                line("Questo è il primo paragrafo del corpo del testo."),
                line("e continua sulla riga successiva senza interruzioni."),
                line("Una terza riga di corpo per consolidare la stima."),
                line("Una quarta riga di corpo del testo normale."),
                line("Una quinta riga di corpo del testo normale."),
            ]]),
            sourceName: "manuale.pdf"
        )
        let structure = doc.structure
        XCTAssertEqual(structure.count, 2)
        XCTAssertEqual(structure[0].type, .HEADING_1)
        XCTAssertEqual(structure[0].text, "Capitolo Primo")
        XCTAssertEqual(structure[0].level, 1)
        XCTAssertEqual(structure[1].type, .BODY)
        XCTAssertTrue(structure[1].text?.contains("Questo è il primo paragrafo del corpo del testo.") ?? false)
    }

    /// TS: "assigns heading levels by size ratio".
    func test_build_headingLevelsByRatio() {
        let doc = genericPlugin.build(
            extraction([[
                line("Titolone", size: 18),
                line("Sottotitolo", size: 15),
                line("Minore", size: 13.5),
                line("corpo del documento normale qui presente"),
                line("seconda riga di corpo a dimensione normale"),
                line("terza riga di corpo a dimensione normale"),
                line("quarta riga di corpo a dimensione normale"),
                line("quinta riga di corpo a dimensione normale"),
            ]]),
            sourceName: "x.pdf"
        )
        XCTAssertEqual(doc.structure.map { $0.type }, [.HEADING_1, .HEADING_2, .HEADING_3, .BODY])
    }

    /// TS: "classifies smaller text as a NOTE with a length_category".
    func test_build_smallerTextIsNote() {
        let doc = genericPlugin.build(
            extraction([[
                line("corpo del testo di riferimento a dimensione normale"),
                line("1. Una nota a piè di pagina molto più piccola.", size: 8),
            ]]),
            sourceName: "x.pdf"
        )
        let note = doc.structure.first { $0.type == .NOTE }
        XCTAssertNotNil(note)
        XCTAssertEqual(note?.length_category, .MICRO)
    }

    /// TS: "de-hyphenates a word broken across two lines".
    func test_build_deHyphenates() {
        let doc = genericPlugin.build(
            extraction([[line("responsabi-"), line("lità civile del debitore")]]),
            sourceName: "x.pdf"
        )
        XCTAssertEqual(doc.structure.first?.text, "responsabilità civile del debitore")
    }

    /// TS: "breaks paragraph runs at page boundaries".
    func test_build_breaksAtPageBoundaries() {
        let doc = genericPlugin.build(
            extraction([[line("prima pagina di testo")], [line("seconda pagina")]]),
            sourceName: "x.pdf"
        )
        XCTAssertEqual(doc.structure.count, 2)
        XCTAssertEqual(doc.structure[0].page_index, 0)
        XCTAssertEqual(doc.structure[1].page_index, 1)
    }

    /// TS: "falls back to all-BODY when no font information is present".
    func test_build_allBodyWhenNoFont() {
        let doc = genericPlugin.build(
            extraction([[line("riga uno", size: 0), line("riga due", size: 0)]]),
            sourceName: "x.pdf"
        )
        XCTAssertTrue(doc.structure.allSatisfy { $0.type == .BODY })
        XCTAssertTrue(doc.warnings.contains("plugin:generic:no_font_information_all_body"))
    }

    /// TS: "produces a well-formed empty Document for an empty extraction".
    func test_build_emptyExtraction() {
        let doc = genericPlugin.build(extraction([]), sourceName: "vuoto.pdf")
        XCTAssertEqual(doc.structure, [])
        XCTAssertEqual(doc.metadata.source_pdf_filename, "vuoto.pdf")
        XCTAssertEqual(doc.document_id, "vuoto")
        XCTAssertEqual(doc.schema_version, "0.7.0")
    }

    /// TS: "mints unique sequential node ids". (Asserts ids, not types — the
    /// body-size estimate collapses here, faithfully.)
    func test_build_uniqueSequentialIds() {
        let doc = genericPlugin.build(
            extraction([[line("Titolo", size: 20), line("corpo"), line("altro corpo")]]),
            sourceName: "x.pdf"
        )
        let ids = doc.structure.map { $0.id }
        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertEqual(ids.first, "node_0")
    }

    // MARK: dispatcher

    /// TS: "selects the Generic plugin (only registered plugin this session)".
    func test_dispatcher_selectsGeneric() {
        XCTAssertTrue(selectPlugin(extraction([[line("x")]])) === genericPlugin)
    }

    // MARK: end-to-end seam (PdfExtraction → document model → contract)

    /// Exercises the whole Fase 2 across the § 10 seam: a `PdfExtraction` flows
    /// through the Generic into a `ScabopdfDocument`, which is then re-validated
    /// against the Layer 1 contract via the Fase 1 `parseDocument`.
    func test_seam_extractionToDocument_isContractValid() {
        let ext = extraction([[
            line("Capitolo", size: 20, bold: true),
            line("Testo del corpo del capitolo che scorre."),
            line("Seconda riga di corpo del capitolo."),
            line("Terza riga di corpo del capitolo."),
            line("Quarta riga di corpo del capitolo."),
        ]])
        let doc = buildDocumentFromPdf(ext, sourceName: "manuale.pdf")

        // Produced model: heading first, then a merged body paragraph.
        XCTAssertEqual(doc.structure.first?.type, .HEADING_1)
        XCTAssertEqual(flattenToReadingOrder(doc).count, doc.structure.count)

        // Round-trips through the Fase 1 contract validator.
        let data = try! JSONEncoder().encode(doc)
        guard case .success(let parsed, _) = parseDocument(data) else {
            return XCTFail("Generic-produced document did not validate against the contract")
        }
        XCTAssertEqual(parsed.profile.profile_id, "generic")
        XCTAssertEqual(parsed.metadata.source_pdf_filename, "manuale.pdf")
    }
}
