//
//  NoteFlowOriginTests.swift
//  ScaboCoreTests
//
//  La GUARDIA D'ORIGINE della ricucitura nel flusso (giro «pulizia e rifinitura finale del capitolo note», 2026-10-17):
//  `mergeNoteContinuations` unisce due pezzi di nota solo se la coda segue SUBITO la testa nel documento d'origine
//  (`ContentSegment.noteOriginPrevious`, annotato da `bindAndPlaceNotes` con `annotateNoteOriginPrevious`). Senza la
//  guardia, una nota spostata al suo richiamo poteva trovarsi accanto al frammento di un'altra nota e venirvi incollata.
//  Ogni regola ha la sua prova al contrario. Testi neutri, inventati.
//

import XCTest
@testable import ScaboCore

final class NoteFlowOriginTests: XCTestCase {

    private func note(_ id: String, _ text: String, previous: String?) -> ContentSegment {
        var s = ContentSegment(id: id, role: SemanticCategory.NOTE.rawValue, text: text,
                               lengthCategory: "SHORT", acousticIntro: "Nota.")
        s.noteOriginPrevious = previous
        return s
    }

    // MARK: - la guardia nella ricucitura nel flusso

    func test_merges_whenTheTailFollowsTheHeadInTheOrigin() {
        let r = mergeNoteContinuations([note("node_1_n0", "3 Una nota che resta aperta e", previous: ""),
                                        note("node_1_n1", "continua qui.", previous: "node_1_n0")])
        XCTAssertEqual(r.map { $0.text }, ["3 Una nota che resta aperta e continua qui."])
        XCTAssertEqual(r.first?.id, "node_1_n0", "la nota unita conserva l'id della testa")
    }

    func test_noMerge_whenAnotherNoteSitsBetweenInTheOrigin() {
        // la testa è stata spostata al suo richiamo e il frammento seguiva un'altra nota: mai incollati
        let r = mergeNoteContinuations([note("node_5_n0", "4 Una nota spostata al suo richiamo e", previous: ""),
                                        note("node_3_n0", "continua un'altra nota.", previous: "node_2_n0")])
        XCTAssertEqual(r.count, 2)
    }

    func test_noMerge_whenSomethingElseSitsBetweenInTheOrigin() {
        // subito prima della coda, nell'origine, c'è un corpo (o un titolo, o una glossa): il vuoto
        let r = mergeNoteContinuations([note("node_1_n0", "5 Una nota che resta aperta e", previous: ""),
                                        note("node_3_n0", "continua dopo una riga di corpo.", previous: "")])
        XCTAssertEqual(r.count, 2)
    }

    func test_chain_eachPieceMustFollowTheLastOneAbsorbed() {
        let r = mergeNoteContinuations([note("node_1_n0", "6 Una nota lunga che resta aperta e", previous: ""),
                                        note("node_2_n0", "prosegue sulla pagina seguente e", previous: "node_1_n0"),
                                        note("node_3_n0", "si chiude su quella dopo.", previous: "node_2_n0")])
        XCTAssertEqual(r.map { $0.text },
                       ["6 Una nota lunga che resta aperta e prosegue sulla pagina seguente e si chiude su quella dopo."])
        // al contrario: il terzo pezzo dichiara come precedente la TESTA, non l'ultimo pezzo assorbito
        let wrong = mergeNoteContinuations([note("node_1_n0", "6 Una nota lunga che resta aperta e", previous: ""),
                                            note("node_2_n0", "prosegue sulla pagina seguente e", previous: "node_1_n0"),
                                            note("node_3_n0", "si chiude su quella dopo.", previous: "node_1_n0")])
        XCTAssertEqual(wrong.count, 2)
    }

    func test_withoutOriginInformation_theRuleOfBeforeHolds() {
        // segmenti costruiti fuori dall'aggancio (nessuna informazione): la regola di prima
        let r = mergeNoteContinuations([note("a", "7 Una nota che resta aperta e", previous: nil),
                                        note("b", "continua qui.", previous: nil)])
        XCTAssertEqual(r.count, 1)
    }

    // MARK: - l'annotazione dell'ordine d'origine

    func test_annotate_previousNoteOrEmpty() {
        let structure = [
            NodeDict(id: "node_1", type: .BODY, page_index: 0, text: "corpo"),
            NodeDict(id: "node_2", type: .NOTE, page_index: 0, text: "due note"),
            NodeDict(id: "node_3", type: .BODY, page_index: 1, text: "corpo"),
            NodeDict(id: "node_4", type: .NOTE, page_index: 1, text: "una nota"),
            NodeDict(id: "node_5", type: .NOTE, page_index: 1, text: "un'altra"),
        ]
        let order = ["node_2": ["node_2_n0", "node_2_n1"], "node_4": ["node_4_n0"], "node_5": ["node_5_n0"]]
        var byId: [String: NodeDict] = [:]
        for ids in order.values { for f in ids { byId[f] = NodeDict(id: f, type: .NOTE, page_index: 0, text: f) } }
        annotateNoteOriginPrevious(structure, original: order, surviving: order, &byId)
        XCTAssertEqual(byId["node_2_n0"]?.noteOriginPrevious, "", "dopo un corpo: il vuoto")
        XCTAssertEqual(byId["node_2_n1"]?.noteOriginPrevious, "node_2_n0")
        XCTAssertEqual(byId["node_4_n0"]?.noteOriginPrevious, "", "un corpo in mezzo")
        XCTAssertEqual(byId["node_5_n0"]?.noteOriginPrevious, "node_4_n0", "due nodi di note di seguito")
    }

    func test_annotate_aFootnoteAbsorbedByTheBindingCountsAsItsHead() {
        let structure = [NodeDict(id: "node_1", type: .NOTE, page_index: 0, text: "tre note")]
        let original = ["node_1": ["node_1_n0", "node_1_n1", "node_1_n2"]]
        let surviving = ["node_1": ["node_1_n0", "node_1_n2"]]   // node_1_n1 ricucita dentro node_1_n0
        var byId = ["node_1_n0": NodeDict(id: "node_1_n0", type: .NOTE, page_index: 0, text: "a"),
                    "node_1_n2": NodeDict(id: "node_1_n2", type: .NOTE, page_index: 0, text: "c")]
        annotateNoteOriginPrevious(structure, original: original, surviving: surviving, &byId)
        XCTAssertEqual(byId["node_1_n2"]?.noteOriginPrevious, "node_1_n0")
    }

    func test_annotate_isNeverEncoded() throws {
        var n = NodeDict(id: "node_1_n0", type: .NOTE, page_index: 0, text: "x")
        n.noteOriginPrevious = "node_0_n0"
        let json = String(decoding: try JSONEncoder().encode(n), as: UTF8.self)
        XCTAssertFalse(json.contains("node_0_n0"), "campo interno: mai serializzato")
        var s = ContentSegment(id: "a", role: "NOTE", text: "x", lengthCategory: "", acousticIntro: "")
        s.noteOriginPrevious = "node_0_n0"
        let js = String(decoding: try JSONEncoder().encode(s), as: UTF8.self)
        XCTAssertFalse(js.contains("node_0_n0"), "campo interno e transitorio: la cache non cambia")
        var t = s
        t.noteOriginPrevious = nil
        XCTAssertEqual(s, t, "non entra nell'uguaglianza")
    }

    // MARK: - sulla catena vera (estrazione sintetica): la nota spostata al richiamo non si incolla al frammento

    private func line(_ text: String, size: Double, y: Double) -> PdfTextLine {
        PdfTextLine(spans: [PdfSpan(text: text, fontSize: size, bold: false, italic: false, color: "#000000",
                                    bbox: BBox(x: 60, y: y, width: 420, height: size))],
                    bbox: BBox(x: 60, y: y, width: 420, height: size))
    }

    func test_chain_aMovedNoteIsNotGluedToTheFragmentThatFollowedSomethingElse() {
        // Il corpo richiama la nota (1) alla fine della sua ultima frase. Nell'apparato, PRIMA della nota (1), c'è un
        // frammento senza numero (la riga di un'altra nota, come nei codici a due colonne). La nota (1) si sposta al
        // richiamo, cioè subito prima del frammento nel flusso: resta aperta, il frammento comincia in minuscolo. Prima di
        // questo giro le due venivano incollate; ora no, perché nell'origine il frammento segue il corpo, non la nota.
        var lines = (0..<6).map { line("Riga di corpo numero \($0) che prosegue il discorso", size: 10, y: 760 - Double($0) * 14) }
        lines.append(line("Ultima riga del corpo con il richiamo alla nota (1).", size: 10, y: 676))
        lines.append(line("frammento di un'altra nota che resta dov'era.", size: 8, y: 140))
        lines.append(line("(1) Nota richiamata che resta aperta e", size: 8, y: 129))
        let ex = PdfExtraction(version: 2, pageCount: 1,
                               pages: [PdfPageExtraction(pageIndex: 0, width: 595, height: 842, lines: lines)], producer: nil)
        let doc = bindAndPlaceNotes(buildDocumentFromPdf(ex, sourceName: "t.pdf"), ex).document
        let flow = granularizeBody(buildLayout(doc, .continuous))
        let notes = flow.filter { $0.role == SemanticCategory.NOTE.rawValue }.map { $0.text }
        XCTAssertTrue(notes.contains("(1) Nota richiamata che resta aperta e"), "la nota resta sola: \(notes)")
        XCTAssertTrue(notes.contains { $0.hasPrefix("frammento") }, "il frammento resta dov'era, separato: \(notes)")
        XCTAssertFalse(notes.contains { $0.contains("aperta e frammento") }, "mai incollate: \(notes)")
    }
}
