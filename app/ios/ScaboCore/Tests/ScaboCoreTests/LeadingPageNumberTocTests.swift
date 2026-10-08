//
//  LeadingPageNumberTocTests.swift
//  ScaboCoreTests
//
//  Sommario iniziale col numero di pagina IN TESTA alla voce (decisione 3 del manutentore, giro finale 2026-10-08):
//  le sue pagine diventano un sommario non letto (TOC_GENERAL) invece di una pila di titoli falsi. Ogni condizione ha
//  la sua prova al contrario. Testi di prova.
//

import XCTest
@testable import ScaboCore

final class LeadingPageNumberTocTests: XCTestCase {

    private func line(_ text: String, top: Double, x0: Double = 60, x1: Double = 300, size: Double = 10) -> PdfTextLine {
        let box = BBox(x: x0, y: top - size * 1.2, width: x1 - x0, height: size * 1.2)
        return PdfTextLine(spans: [PdfSpan(text: text, fontSize: size, bold: false, italic: false, color: "#000000", bbox: box)], bbox: box)
    }
    private func entries(from first: Int, count: Int, step: Int = 3, top: Double = 700) -> [PdfTextLine] {
        (0..<count).map { line("\(first + $0 * step) Voce di prova numero \($0) del sommario", top: top - Double($0) * 14) }
    }
    private func prose(_ n: Int, top: Double) -> [PdfTextLine] {
        (0..<n).map { line("Riga di prosa di prova numero \($0) che arriva fino al margine destro della pagina.", top: top - Double($0) * 14,
                           x1: 420) }
    }
    private func toc(_ pages: [[PdfTextLine]]) -> Set<Int> {
        let ps = pages.enumerated().map { PdfPageExtraction(pageIndex: $0.offset, width: 480, height: 680, lines: $0.element) }
        let e = PdfExtraction(version: 2, pageCount: 40, pages: ps + (ps.count..<40).map {
            PdfPageExtraction(pageIndex: $0, width: 480, height: 680, lines: prose(20, top: 650)) })
        return detectFrontMatterNoLeaderIndex(e, [], 30)
    }

    func test_leadingNumbers_afterTitle_areContents_andTheRegionContinues() {
        let p0 = [line("Sommario", top: 720)] + entries(from: 1, count: 12)
        let p1 = entries(from: 40, count: 14)            // pagina seguente senza titolo: la regione continua
        let p2 = prose(20, top: 650)                     // la prosa chiude la regione
        XCTAssertEqual(toc([p0, p1, p2]), [0, 1])
    }

    func test_counterProofs_staysRead() {
        // numeri decrescenti nella pagina
        XCTAssertEqual(toc([[line("Sommario", top: 720)] + entries(from: 60, count: 12, step: -3)]), [], "decrescenti")
        // senza il titolo del sommario la regione non si apre
        XCTAssertEqual(toc([entries(from: 1, count: 12)]), [], "senza titolo")
        // «1. Titolo» non è la voce col numero di pagina in testa
        let numbered = [line("Sommario", top: 720)] + (0..<12).map { line("\($0 + 1). Titolo di prova del paragrafo", top: 700 - Double($0) * 14) }
        XCTAssertEqual(toc([numbered]), [], "numerati col punto")
        // un blocco di prosa sulla pagina: astensione, la pagina resta letta
        let withProse = [line("Sommario", top: 720)] + entries(from: 1, count: 12) + prose(3, top: 480 - 28)
        XCTAssertEqual(toc([withProse]), [], "con prosa")
    }
}
