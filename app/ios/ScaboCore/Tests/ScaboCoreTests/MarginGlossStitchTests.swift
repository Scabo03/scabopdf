//
//  MarginGlossStitchTests.swift
//  ScaboCoreTests
//
//  Le note spezzate fra pagine contigue vicino a una GLOSSA A MARGINE (giro «chiusura del capitolo note», 2026-10-18,
//  decisione 2 del maintainer). Sulla pagina B la glossa stampata nel margine sinistro accanto alle note entra nel nodo
//  delle note: in testa, prima del seguito della nota della pagina A, o come nota a sé fatta della sola glossa. Fino alla
//  build 57 la guardia della glossa fermava tutte queste coppie (25 nei manuali di prova: 13 note davvero spezzate, 12 note
//  complete). Ora:
//    • glossa in testa e poi il seguito, prima di ogni apertura: la glossa resta dov'è, nota a sé, e il seguito si ricuce
//      alla testa, con la successione confermata e le guardie della geometria e del corpo tipografico vagliate sulla prima
//      riga del seguito;
//    • coda fatta della sola glossa: la glossa resta dov'è e la testa aspetta la nota seguente della pagina B, che si
//      ricuce se è un seguito senza numero (con tutte le guardie) e la chiude se si apre col numero della nota seguente
//      (la nota della pagina A era completa: nessuna fusione nota-glossa, nessuna nota aperta).
//  Strutture sintetiche con geometria (ascisse e quote come le vede l'aggancio), prove dirette e prove al contrario.
//  Testi neutri, inventati.
//

import XCTest
@testable import ScaboCore

final class MarginGlossStitchTests: XCTestCase {

    /// Una riga di nota come la vede l'aggancio: ascissa `x`, quota `y` (origine in basso), corpo `size`.
    private func row(_ text: String, x: Double, y: Double, size: Double = 8) -> LineSummary {
        summarizeLine(PdfTextLine(
            spans: [PdfSpan(text: text, fontSize: size, bold: false, italic: false, color: "#000000",
                            bbox: BBox(x: x, y: y, width: 300, height: size))],
            bbox: BBox(x: x, y: y, width: 300, height: size)))
    }

    /// Esito della ricucitura su nodi di note sintetici: una nota individuale per nodo (testo = righe unite come le unisce
    /// `splitFootnotes`), salvo i nodi dati con più note (`multi`). Pagina 0 = A, pagina 1 = B; il corpo di entrambe finisce
    /// alla quota 690 e ha il margine sinistro a 60.
    private struct Outcome {
        let count: Int
        let candidates: [AdjacentPageStitchCandidate]
        let texts: [String: String]       // id della nota individuale → testo
        let order: [String: [String]]     // id del nodo → note individuali sopravvissute
    }
    private func run(_ nodes: [(id: String, page: Int, lines: [LineSummary])]) -> Outcome {
        var structure: [NodeDict] = []
        var byId: [String: NodeDict] = [:]
        var order: [String: [String]] = [:]
        var lines: [String: [LineSummary]] = [:]
        for n in nodes {
            structure.append(NodeDict(id: n.id, type: .NOTE, page_index: n.page, text: joinLines(n.lines.map { $0.text })))
            lines[n.id] = n.lines
            var ids: [String] = []
            for (k, f) in splitFootnotes(n.lines, page: n.page).enumerated() {
                let fid = "\(n.id)_n\(k)"
                byId[fid] = NodeDict(id: fid, type: .NOTE, page_index: n.page, text: f.text, length_category: f.lengthCategory)
                ids.append(fid)
            }
            order[n.id] = ids
        }
        let r = stitchAdjacentPageFootnotes(structure, &byId, &order, noteLinesById: lines,
                                            contentBottomByPage: [0: 690, 1: 690], bodyLeftByPage: [0: 60, 1: 60])
        return Outcome(count: r.count, candidates: r.candidates,
                       texts: byId.mapValues { $0.text ?? "" }, order: order)
    }

    private func headNode(_ text: String = "13 Una nota che resta aperta e") -> (id: String, page: Int, lines: [LineSummary]) {
        (id: "nA", page: 0, lines: [row(text, x: 74, y: 140)])
    }
    /// La nota 14 della pagina B, con due righe di seguito nella colonna (60): misura la colonna delle note della pagina.
    private func nextNote(_ id: String = "nC", y: Double = 106) -> (id: String, page: Int, lines: [LineSummary]) {
        (id: id, page: 1, lines: [row("14 Nota nuova della pagina seguente", x: 74, y: y),
                                  row("che prosegue nella colonna", x: 60, y: y - 11),
                                  row("e si chiude qui.", x: 60, y: y - 22)])
    }

    // MARK: - glossa in testa alla coda, poi il seguito

    private func glossThenContinuation(continuationX: Double = 60, continuationY: Double = 128,
                                       continuationSize: Double = 8, headText: String = "13 Una nota che resta aperta e",
                                       withNext: Bool = true, glossFirstWord: String = "Titoletto",
                                       continuationText: String = "continua sulla pagina seguente") -> Outcome {
        var nodes = [headNode(headText),
                     (id: "nB", page: 1, lines: [row(glossFirstWord, x: 40, y: 150), row("a margine", x: 40, y: 139),
                                                 row(continuationText, x: continuationX, y: continuationY,
                                                     size: continuationSize),
                                                 row("fino al punto.", x: 60, y: continuationY - 11)])]
        if withNext {
            nodes[1].lines += [row("14 Nota nuova della pagina seguente", x: 74, y: 95),
                               row("che prosegue nella colonna", x: 60, y: 84), row("e si chiude qui.", x: 60, y: 73)]
        }
        return run(nodes)
    }

    func test_glossThenContinuation_glossStays_continuationStitched() {
        let r = glossThenContinuation()
        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(r.candidates.first?.reason, "ricucita")
        XCTAssertEqual(r.candidates.first?.marginGloss, "glossa in testa alla coda")
        XCTAssertEqual(r.candidates.first?.tailX0, 60, "la geometria della coda è quella della prima riga del seguito")
        XCTAssertEqual(r.texts["nA_n0"], "13 Una nota che resta aperta e continua sulla pagina seguente fino al punto.")
        XCTAssertEqual(r.texts["nB_n0"], "Titoletto a margine", "la glossa resta, da sola, al suo posto")
        XCTAssertEqual(r.order["nB"], ["nB_n0", "nB_n1"], "nessuna nota individuale tolta: la glossa e la nota 14 restano")
        XCTAssertEqual(r.texts["nB_n1"], "14 Nota nuova della pagina seguente che prosegue nella colonna e si chiude qui.")
    }

    func test_glossThenContinuation_dehyphenatesTheBrokenWord() {
        let r = run([headNode("13 Una nota che resta aperta e conti-"),
                     (id: "nB", page: 1, lines: [row("Titoletto a margine", x: 40, y: 150),
                                                 row("nua sulla pagina seguente.", x: 60, y: 139),
                                                 row("14 Nota nuova della pagina seguente", x: 74, y: 117),
                                                 row("che prosegue nella colonna", x: 60, y: 106),
                                                 row("e si chiude qui.", x: 60, y: 95)])])
        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(r.texts["nA_n0"], "13 Una nota che resta aperta e continua sulla pagina seguente.")
        XCTAssertEqual(r.texts["nB_n0"], "Titoletto a margine")
    }

    func test_glossThenContinuation_withoutConfirmedSuccession_staysOpen() {
        // prova al contrario: nessuna nota numerata dopo il seguito sulla pagina B, la successione non conferma. La glossa
        // comincia in minuscolo perché il predicato dell'app valga e la coppia arrivi alla guardia della glossa: anche così
        // il seguito non si ricuce senza la conferma
        let r = glossThenContinuation(withNext: false, glossFirstWord: "titoletto")
        XCTAssertEqual(r.candidates.first?.predicate, true)
        XCTAssertEqual(r.count, 0)
        XCTAssertEqual(r.candidates.first?.reason, "coda aperta da una glossa a margine: successione non confermata")
        XCTAssertEqual(r.texts["nB_n0"], "titoletto a margine continua sulla pagina seguente fino al punto.",
                       "la coda resta com'era, glossa compresa")
        XCTAssertEqual(r.texts["nA_n0"], "13 Una nota che resta aperta e")
    }

    func test_glossThenContinuation_continuationAmongTheBodyLines_staysOpen() {
        let r = glossThenContinuation(continuationY: 740)
        XCTAssertEqual(r.count, 0)
        XCTAssertEqual(r.candidates.first?.reason, "coda aperta da una glossa a margine: seguito non sotto il corpo")
    }

    func test_glossThenContinuation_differentTypeSize_staysOpen() {
        let r = glossThenContinuation(continuationSize: 10)
        XCTAssertEqual(r.count, 0)
        XCTAssertEqual(r.candidates.first?.reason, "coda aperta da una glossa a margine: corpo tipografico diverso")
    }

    func test_glossThenContinuation_continuationOutsideTheColumn_staysOpen() {
        // prova al contrario: la prima riga del «seguito» sta anch'essa a sinistra della colonna delle note, ma non alla
        // stessa ascissa della glossa: non è un seguito sicuro, la coppia resta aperta
        let r = glossThenContinuation(continuationX: 50)
        XCTAssertEqual(r.count, 0)
        XCTAssertEqual(r.candidates.first?.reason, "coda aperta da una glossa a margine: seguito fuori dalla colonna")
        XCTAssertEqual(r.texts["nA_n0"], "13 Una nota che resta aperta e")
    }

    func test_glossThenContinuation_continuationNumberedAsTheNextNote_staysOpen() {
        // prova al contrario: il «seguito» comincia col numero della nota seguente (14, attaccato a una virgola, quindi non è
        // un'apertura di nota per l'estrazione): potrebbe essere la nota 14 stessa, non si ricuce
        let r = glossThenContinuation(continuationText: "14,5 per cento della somma resta dovuto")
        XCTAssertEqual(r.count, 0)
        XCTAssertEqual(r.candidates.first?.reason,
                       "coda aperta da una glossa a margine: seguito numerato come la nota seguente")
        XCTAssertEqual(r.texts["nA_n0"], "13 Una nota che resta aperta e")
    }

    // MARK: - coda fatta della sola glossa

    func test_glossOnly_thenTheTrueContinuation_stitchesTheContinuation() {
        let r = run([headNode(),
                     (id: "nG", page: 1, lines: [row("Titoletto", x: 40, y: 150), row("a margine", x: 40, y: 139)]),
                     (id: "nB", page: 1, lines: [row("continua sulla pagina seguente fino al punto.", x: 60, y: 128)]),
                     nextNote()])
        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(r.candidates.count, 2)
        XCTAssertEqual(r.candidates[0].tailId, "nG_n0")
        XCTAssertEqual(r.candidates[0].marginGloss, "coda fatta della sola glossa: si vaglia la nota seguente")
        XCTAssertFalse(r.candidates[0].stitched)
        XCTAssertEqual(r.candidates[1].tailId, "nB_n0")
        XCTAssertEqual(r.candidates[1].headId, "nA_n0", "la testa resta quella: la glossa non la sostituisce")
        XCTAssertEqual(r.candidates[1].reason, "ricucita")
        XCTAssertEqual(r.texts["nA_n0"], "13 Una nota che resta aperta e continua sulla pagina seguente fino al punto.")
        XCTAssertEqual(r.order["nG"], ["nG_n0"], "la glossa resta al suo posto")
        XCTAssertEqual(r.order["nB"], [], "il seguito è passato alla testa")
    }

    func test_glossOnly_thenTheNextNote_isACompleteNote_noStitch() {
        // le 12 note complete: dopo la glossa si apre la nota seguente; la nota della pagina A resta com'è
        let r = run([headNode("13 Una nota completa, chiusa da un punto."),
                     (id: "nG", page: 1, lines: [row("Titoletto", x: 40, y: 150), row("a margine", x: 40, y: 139)]),
                     nextNote(y: 128)])
        XCTAssertEqual(r.count, 0)
        XCTAssertEqual(r.candidates.count, 1)
        XCTAssertEqual(r.candidates[0].reason, "coda aperta da una glossa a margine")
        XCTAssertEqual(r.texts["nA_n0"], "13 Una nota completa, chiusa da un punto.")
        XCTAssertEqual(r.texts["nG_n0"], "Titoletto a margine")
        XCTAssertEqual(r.order["nC"], ["nC_n0"])
    }

    func test_glossOnly_sameNodeAsTheNextNote_isACompleteNote_noStitch() {
        // la glossa e la nota seguente nello stesso nodo (la forma più frequente delle note complete)
        let r = run([headNode("13 Una nota completa, chiusa da un punto."),
                     (id: "nB", page: 1, lines: [row("Titoletto", x: 40, y: 150), row("a margine", x: 40, y: 139),
                                                 row("14 Nota nuova della pagina seguente", x: 74, y: 128),
                                                 row("che prosegue nella colonna", x: 60, y: 117),
                                                 row("e si chiude qui.", x: 60, y: 106)])])
        XCTAssertEqual(r.count, 0)
        XCTAssertEqual(r.texts["nA_n0"], "13 Una nota completa, chiusa da un punto.")
        XCTAssertEqual(r.texts["nB_n0"], "Titoletto a margine")
        XCTAssertEqual(r.order["nB"], ["nB_n0", "nB_n1"])
    }

    func test_glossOnly_thenAContinuationInTheMargin_staysOpen() {
        // prova al contrario: dopo la glossa una «coda» che sta anch'essa nel margine (un'altra glossa): non si ricuce
        let r = run([headNode(),
                     (id: "nG", page: 1, lines: [row("Titoletto", x: 40, y: 150), row("a margine", x: 40, y: 139)]),
                     (id: "nG2", page: 1, lines: [row("Altro titoletto a margine", x: 40, y: 128)]),
                     nextNote()])
        XCTAssertEqual(r.count, 0)
        XCTAssertEqual(r.texts["nA_n0"], "13 Una nota che resta aperta e")
    }

    // MARK: - la separazione

    func test_marginGlossSeparation() {
        let gloss = [row("Titoletto", x: 40, y: 150), row("a margine", x: 40, y: 139)]
        let cont = [row("continua la nota", x: 60, y: 128), row("fino al punto.", x: 60, y: 117)]
        let next = [row("14 Nota nuova", x: 74, y: 106), row("che prosegue.", x: 60, y: 95)]
        XCTAssertEqual(marginGlossSeparation(gloss + cont + next, bodyLeft: 60),
                       .glossThenContinuation(gloss: gloss, continuation: cont))
        XCTAssertEqual(marginGlossSeparation(gloss + next, bodyLeft: 60), .glossOnly)
        XCTAssertEqual(marginGlossSeparation(gloss, bodyLeft: 60), .glossOnly)
        // nel dubbio non si separa nulla: senza la colonna del corpo, o con la prima riga nella colonna
        XCTAssertEqual(marginGlossSeparation(gloss + cont, bodyLeft: nil), .unrecognized)
        XCTAssertEqual(marginGlossSeparation(cont + next, bodyLeft: 60), .unrecognized)
        XCTAssertEqual(marginGlossSeparation([], bodyLeft: 60), .unrecognized)
    }
}
