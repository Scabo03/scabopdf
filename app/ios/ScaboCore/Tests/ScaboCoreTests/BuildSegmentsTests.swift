//
//  BuildSegmentsTests.swift
//  ScaboCoreTests
//
//  XCTest translation of `app/src/rendering/__tests__/buildSegments.test.ts`
//  (70 LOC). Covers buildBaseSegments' text-less-node skip (its documented core
//  job, never exercised by the baseline fixtures which carry no EMPTY_PAGE /
//  anchor-only nodes) and the paginate page-size guard.
//
//  Golden rule (Piano § 4): each test names the TS test it mirrors.
//

import XCTest
@testable import ScaboCore

final class BuildSegmentsTests: XCTestCase {

    /// Mirrors the TS `docWith(structure)` helper.
    private func docWith(_ structure: [NodeDict]) -> ScabopdfDocument {
        ScabopdfDocument(
            schema_version: "0.7.0",
            document_id: "00000000-0000-4000-8000-000000000000",
            metadata: DocumentMetadata(
                pages_pdf: 1,
                page_size_pt: [595, 842],
                source_pdf_filename: "x.pdf"
            ),
            profile: DocumentProfileDict(
                profile_id: "unknown_generic",
                editorial_family: "unknown",
                genre: "unknown",
                confidence: 0
            ),
            structure: structure
        )
    }

    // MARK: buildBaseSegments skips text-less nodes

    /// TS: "drops null/empty/undefined-text and anchor-only nodes, keeps real text".
    func test_skipsTextLessNodes() {
        let doc = docWith([
            NodeDict(id: "node_0", type: .EMPTY_PAGE, page_index: 0, text: nil),
            NodeDict(id: "node_1", type: .BOOK_PAGE_ANCHOR, page_index: 0),
            NodeDict(id: "node_2", type: .BODY, page_index: 0, text: ""),
            NodeDict(id: "node_3", type: .BODY, page_index: 0, text: "reale"),
        ])
        let segs = buildBaseSegments(doc)
        XCTAssertEqual(segs.map { $0.id }, ["node_3"])
        XCTAssertEqual(segs.first, ContentSegment(
            id: "node_3",
            role: "BODY",
            text: "reale",
            lengthCategory: "",
            acousticIntro: ""
        ))
    }

    /// TS: "NOTE keeps its length_category; non-NOTE gets the empty string".
    func test_noteKeepsLengthCategory() {
        let doc = docWith([
            NodeDict(id: "node_0", type: .NOTE, page_index: 0, text: "(1) nota", length_category: .MEGA),
            NodeDict(id: "node_1", type: .BODY, page_index: 0, text: "corpo"),
        ])
        let segs = buildBaseSegments(doc)
        XCTAssertEqual(segs[0].lengthCategory, "MEGA")
        XCTAssertEqual(segs[1].lengthCategory, "")
    }

    // MARK: paginate guard

    /// TS: "throws on a non-positive page size".
    func test_paginateThrowsOnNonPositivePageSize() {
        XCTAssertThrowsError(try paginate([], 0)) { error in
            XCTAssertTrue("\(error)".contains("segmentsPerPage must be > 0"))
        }
        XCTAssertThrowsError(try paginate([], -5)) { error in
            XCTAssertTrue("\(error)".contains("segmentsPerPage must be > 0"))
        }
    }

    // MARK: solo le note VERE annunciano "Nota." (collaudo d'orecchio — bug 1)
    //
    // Il Generic è size-only: una testatina o un titolo di sezione in maiuscoletto a
    // taglia inferiore al corpo collassa in NOTE, e a orecchio si sentiva "Nota."
    // prima di un'intestazione. Sul solo flusso del backend euristico ("generic"),
    // una NOTE il cui testo non si apre con un marcatore di nota perde l'intro; il
    // testo resta letto (nessun contenuto perso). I backend strutturati (AKN) NON
    // sono toccati: una loro nota tiene sempre l'intro.

    private func genericDocWith(_ structure: [NodeDict]) -> ScabopdfDocument {
        var doc = docWith(structure)
        doc.profile = DocumentProfileDict(
            profile_id: "generic", editorial_family: "generic", genre: "unknown", confidence: 0.05)
        return doc
    }

    func test_genericNote_withoutMarker_losesNotaIntro() {
        let doc = genericDocWith([
            // testatina / titolo di sezione collassato in NOTE (niente marcatore)
            NodeDict(id: "node_0", type: .NOTE, page_index: 0,
                     text: "UNA LUNGA STORIA. ASSASSINII E PROCESSI", length_category: .MICRO),
            // nota VERA, si apre col numero d'apertura → tiene l'intro
            NodeDict(id: "node_1", type: .NOTE, page_index: 0,
                     text: "1. S. Humbert, La chronique judiciaire.", length_category: .SHORT),
        ])
        let segs = buildBaseSegments(doc)
        XCTAssertEqual(segs[0].acousticIntro, "", "il titolo di sezione collassato in NOTE non annuncia 'Nota.'")
        XCTAssertEqual(segs[0].text, "UNA LUNGA STORIA. ASSASSINII E PROCESSI", "il testo resta invariato, letto in posizione")
        XCTAssertEqual(segs[1].acousticIntro, "Nota.", "la nota vera (apre col numero) tiene l'intro")
    }

    func test_genericNote_withSymbolMarker_keepsIntro() {
        let doc = genericDocWith([
            NodeDict(id: "node_0", type: .NOTE, page_index: 0, text: "* Nota a piè di pagina.", length_category: .MICRO),
            NodeDict(id: "node_1", type: .NOTE, page_index: 0, text: "(12) altra nota.", length_category: .MICRO),
        ])
        let segs = buildBaseSegments(doc)
        XCTAssertEqual(segs[0].acousticIntro, "Nota.", "marcatore simbolo (*) → nota vera")
        XCTAssertEqual(segs[1].acousticIntro, "Nota.", "marcatore numerico fra parentesi → nota vera")
    }

    func test_nonGenericNote_withoutMarker_keepsIntro() {
        // Backend strutturato (es. AKN): profile_id ≠ "generic" → nessuna soppressione.
        let doc = docWith([  // docWith usa profile_id "unknown_generic"
            NodeDict(id: "node_0", type: .NOTE, page_index: 0,
                     text: "Una nota d'autore senza numero d'apertura.", length_category: .LONG),
        ])
        let segs = buildBaseSegments(doc)
        XCTAssertEqual(segs[0].acousticIntro, "Nota lunga.",
                       "una nota di backend strutturato tiene sempre l'intro, anche senza marcatore")
    }
}
