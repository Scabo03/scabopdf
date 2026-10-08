//
//  CodiciLawTitlesTests.swift
//  ScaboCoreTests
//
//  Ramo Codici — foglia 5: il titolo d'apertura di un atto ristampato (leggi complementari) diventa
//  HEADING_1, come i Libri (decisione del giro finale, 2026-10-08; era HEADING_3). Segnali solo del dispositivo: taglia del corpo (il grassetto è perso), margine sinistro della
//  pagina, riga che attraversa il canalino fra le colonne, citazione dell'atto in apertura. Testi di prova.
//

import XCTest
@testable import ScaboCore

final class CodiciLawTitlesTests: XCTestCase {

    private let body = 7.5

    /// Riga a taglia `size` da `x0` a `x1`, linea di base `y`.
    private func line(_ text: String, x0: Double, x1: Double, y: Double, size: Double = 7.48) -> PdfTextLine {
        let box = BBox(x: x0, y: y, width: x1 - x0, height: size)
        return PdfTextLine(spans: [PdfSpan(text: text, fontSize: size, bold: false, italic: false, color: "#000000", bbox: box)],
                           bbox: box)
    }
    private func articleLine(_ number: String, _ rest: String, y: Double, x0: Double = 39.7) -> PdfTextLine {
        let numBox = BBox(x: x0, y: y, width: 12, height: 9)
        let restBox = BBox(x: x0 + 12, y: y, width: 120, height: 7.48)
        return PdfTextLine(spans: [
            PdfSpan(text: number, fontSize: 9, bold: false, italic: false, color: "#000000", bbox: numBox),
            PdfSpan(text: rest, fontSize: 7.48, bold: false, italic: false, color: "#000000", bbox: restBox),
        ], bbox: BBox(x: x0, y: y, width: 132, height: 9))
    }
    private func sm(_ l: PdfTextLine) -> LineSummary { summarizeLine(l) }
    private func headings(_ items: [GenItem]) -> [(String, Int)] {
        items.compactMap { if case let .heading(s, level) = $0 { return (s.text, level) } else { return nil } }
    }
    private func bodies(_ items: [GenItem]) -> [String] {
        items.compactMap { if case let .run(.body, ls) = $0 { return joinLines(ls.map { $0.text }) } else { return nil } }
    }

    // MARK: - Promosso

    func test_lawTitle_twoRows_promotedToHeading1_materiaStaysBody() {
        let lines = [
            line("MATERIA DI PROVA", x0: 140, x1: 220, y: 500),
            line("L. 12 marzo 2001, n. 99. – Norme di prova per la disciplina di un istituto qualunque", x0: 31.2, x1: 326, y: 488),
            line("e delle sue conseguenze (G.U. 1 aprile 2001, n. 76).", x0: 31.2, x1: 200, y: 479),
            articleLine("1", ". Oggetto. – [I]. La presente legge di prova disciplina.", y: 466),
        ].map(sm)
        let items = splitCodiciArticleRun(lines, body)
        let h = headings(items)
        XCTAssertEqual(h.first?.1, 1)
        XCTAssertEqual(h.first?.0, "L. 12 marzo 2001, n. 99. – Norme di prova per la disciplina di un istituto qualunque e delle sue conseguenze (G.U. 1 aprile 2001, n. 76).")
        XCTAssertEqual(bodies(items).first, "MATERIA DI PROVA", "la materia centrata resta corpo, a sé")
        XCTAssertEqual(h.count, 2, "il titolo e l'articolo")
    }

    func test_lawTitle_firstRowSplitInTwoPieces_byPdfKit() {
        let lines = [
            line("D.lgs. 3 giugno 2010, n. 12.", x0: 31.2, x1: 140, y: 488),
            line("– Disposizioni di prova sull'istituto qualunque della legge", x0: 144, x1: 326, y: 488),
            line("delega (G.U. 4 giugno 2010, n. 13).", x0: 31.2, x1: 170, y: 479),
        ].map(sm)
        let h = headings(splitCodiciArticleRun(lines, body))
        XCTAssertEqual(h.count, 1)
        XCTAssertEqual(h.first?.0, "D.lgs. 3 giugno 2010, n. 12. – Disposizioni di prova sull'istituto qualunque della legge delega (G.U. 4 giugno 2010, n. 13).")
    }

    func test_lawTitle_openingForms() {
        for opening in ["D.m. 1o luglio 2003. – Titolo di prova",
                        "Regio decreto 3 marzo 1931, n. 7001. – Titolo di prova",
                        "D.l. 9 aprile 2031, n. 7777, conv. in legge di prova",
                        "Reg. (UE) n. 2031/9999 di prova, titolo di prova",
                        "Decisione quadro 2031/999/GAI di prova"] {
            XCTAssertTrue(codiciOpensLawCitation(opening), opening)
        }
        XCTAssertFalse(codiciOpensLawCitation("Legge di prova senza data"))
        XCTAssertFalse(codiciOpensLawCitation("L. 12 marzo 2001, n. 99 . . . . . 412"), "voce d'indice: niente trattino")
    }

    // MARK: - Dove si ferma

    func test_continuation_stopsAfterShortRow_orClosedParenthesis_andAtStructure() {
        let lines = [
            line("L. 12 marzo 2001, n. 99. – Norme di prova (G.U. 1 aprile 2001, n. 76).", x0: 31.2, x1: 300, y: 488),
            line("(Stralcio)", x0: 40, x1: 80, y: 479),
            line("CAPO I", x0: 150, x1: 180, y: 466),
        ].map(sm)
        let items = splitCodiciArticleRun(lines, body)
        XCTAssertEqual(headings(items).first?.0, "L. 12 marzo 2001, n. 99. – Norme di prova (G.U. 1 aprile 2001, n. 76).")
        XCTAssertTrue(bodies(items).contains("(Stralcio)"), "lo stralcio resta corpo")
        XCTAssertEqual(headings(items).map { $0.1 }, [1, 2], "titolo dell'atto (primo livello), poi CAPO dalla foglia di struttura")
    }

    // MARK: - Rifiutato

    func test_rejected_indexSize_column_noDash_runningHead() {
        // lo stesso testo a 6 pt (sommario, indice cronologico)
        XCTAssertNil(codiciLawTitleEnd([sm(line("L. 12 marzo 2001, n. 99. – Norme di prova", x0: 31.2, x1: 326, y: 488, size: 6))], from: 0, body))
        // confinato nella colonna sinistra (non attraversa il canalino)
        XCTAssertNil(codiciLawTitleEnd([sm(line("L. 12 marzo 2001, n. 99. – Norme", x0: 31.2, x1: 175, y: 488))], from: 0, body))
        // in colonna destra
        XCTAssertNil(codiciLawTitleEnd([sm(line("L. 12 marzo 2001, n. 99. – Norme di prova", x0: 184, x1: 326, y: 488))], from: 0, body))
        // rientrato come un articolo
        XCTAssertNil(codiciLawTitleEnd([sm(line("L. 12 marzo 2001, n. 99. – Norme di prova", x0: 39.7, x1: 326, y: 488))], from: 0, body))
        // testatina maiuscola a 9,98 pt
        XCTAssertNil(codiciLawTitleEnd([sm(line("L. 12 MARZO 2001, N. 99", x0: 31.2, x1: 326, y: 520, size: 9.98))], from: 0, body))
        // citazione nel corpo dopo altre parole
        XCTAssertNil(codiciLawTitleEnd([sm(line("secondo la L. 12 marzo 2031, n. 99. – prova", x0: 31.2, x1: 326, y: 488))], from: 0, body))
    }

    func test_afterLeggiComplementariDivider_innerPartOfAnAct_goesUnderTheAct() {
        func node(_ t: SemanticCategory, _ text: String) -> NodeDict { NodeDict(id: "n", type: t, page_index: 9, text: text, level: t == .BODY ? nil : 1) }
        var nodes = [node(.HEADING_1, "LIBRO PRIMO - Libro di prova"), node(.BODY, "LEGGI COMPLEMENTARI"),
                     node(.HEADING_1, "L. 12 marzo 2031, n. 99. – Legge di prova (G.U. 1 aprile 2031, n. 76)."),
                     node(.HEADING_1, "PARTE I - Parte di prova dell'atto")]
        _ = normalizeCodiciStructure(&nodes)
        XCTAssertEqual(nodes.map { $0.type }, [.HEADING_1, .BODY, .HEADING_1, .HEADING_2], "la PARTE dell'atto va sotto l'atto")
        // prova al contrario: senza la divisoria nessuna retrocessione
        var noDivider = [node(.HEADING_1, "LIBRO PRIMO - Libro di prova"),
                         node(.HEADING_1, "L. 12 marzo 2031, n. 99. – Legge di prova (G.U. 1 aprile 2031, n. 76)."),
                         node(.HEADING_1, "PARTE I - Parte di prova dell'atto")]
        _ = normalizeCodiciStructure(&noDivider)
        XCTAssertEqual(noDivider.map { $0.type }, [.HEADING_1, .HEADING_1, .HEADING_1])
    }

    func test_noteRun_neverOpensLawTitle() {
        let lines = [line("L. 12 marzo 2001, n. 99. – Norme di prova (G.U. 1 aprile 2001, n. 76).", x0: 31.2, x1: 300, y: 488)].map(sm)
        XCTAssertTrue(headings(splitCodiciArticleRun(lines, body, role: .note)).isEmpty)
    }
}
