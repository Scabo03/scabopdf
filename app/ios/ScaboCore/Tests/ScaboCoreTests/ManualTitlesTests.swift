//
//  ManualTitlesTests.swift
//  ScaboCoreTests
//
//  Voce 2 del giro «titoli e testatine»: i titoli «§ N.» composti tutti in grassetto a taglia di corpo
//  (canale numerato) e le sezioni in maiuscoletto rimaste corpo o nota (`promoteSectionLabels`). Testi di prova.
//

import XCTest
@testable import ScaboCore

final class ManualTitlesTests: XCTestCase {

    private let body = 11.5

    private func line(_ parts: [(String, Double, Bool)], yTop: Double, width: Double = 300, x0: Double = 70) -> LineSummary {
        let text = parts.map { $0.0 }.joined()
        let spans = parts.map {
            PdfSpan(text: $0.0, fontSize: $0.1, bold: $0.2, italic: false, color: "#000000",
                    bbox: BBox(x: x0, y: yTop - 12, width: width, height: 12))
        }
        let n = parts.reduce(0) { $0 + $1.0.count }
        let mean = parts.reduce(0.0) { $0 + $1.1 * Double($1.0.count) } / Double(max(1, n))
        return LineSummary(text: text, fontSize: mean, bold: parts.allSatisfy { $0.2 }, italic: false, color: "#000000",
                           x0: x0, x1: x0 + width, yTop: yTop, yBottom: yTop - 12, width: width, height: 12, spans: spans)
    }
    private func bodyLine(_ t: String, yTop: Double) -> LineSummary { line([(t, body, false)], yTop: yTop) }
    private func run(_ lines: [LineSummary]) -> [GenItem] {
        recognizeNumberedTitles([.run(.body, lines)], Profile(bodySize: body, bodyColor: "#000000"),
                                colWidth: 300, colX1: 370)
    }
    private func titles(_ items: [GenItem]) -> [(String, Int)] {
        items.compactMap { if case let .numberedTitle(sm, d) = $0 { return (sm.text, d) } else { return nil } }
    }

    // MARK: - «§ N.» in grassetto pieno

    func test_boldParagraphTitle_afterGap_isNumberedTitleDepth1_withBoldContinuation() {
        let lines = [
            bodyLine("Fine del paragrafo precedente di prova.", yTop: 600),
            line([("§ ", 10.98, true), ("12. Titolo di prova del paragrafo", 11.47, true)], yTop: 570),
            line([("che continua sulla seconda riga", 11.47, true)], yTop: 556),
            bodyLine("Il corpo del paragrafo comincia qui e prosegue.", yTop: 542),
        ]
        let t = titles(run(lines))
        XCTAssertEqual(t.count, 1)
        XCTAssertEqual(t.first?.1, 1)
        XCTAssertEqual(t.first?.0, "§ 12. Titolo di prova del paragrafo che continua sulla seconda riga")
    }

    func test_boldParagraphTitle_bisSuffix_andLowercase_accepted() {
        let lines = [bodyLine("Fine della frase precedente.", yTop: 600),
                     line([("§ 231-bis. ", 11.47, true), ("la regola di prova", 11.47, true)], yTop: 570),
                     bodyLine("Il corpo comincia qui.", yTop: 556)]
        XCTAssertEqual(titles(run(lines)).map { $0.0 }, ["§ 231-bis. la regola di prova"])
    }

    func test_boldParagraphTitle_withoutGap_orNotBold_staysBody() {
        // senza stacco: è la continuazione del paragrafo, non un titolo
        let noGap = [bodyLine("riga di corpo che va a capo e cita il", yTop: 600),
                     line([("§ 12. Titolo in grassetto di prova", 11.47, true)], yTop: 586)]
        XCTAssertTrue(titles(run(noGap)).isEmpty)
        // regolare (non grassetto): un rinvio «§ 125.» a capo resta corpo
        let regular = [bodyLine("Fine della frase precedente.", yTop: 600),
                       line([("§ 125. Rinvio di prova a capo", 11.47, false)], yTop: 570)]
        XCTAssertTrue(titles(run(regular)).isEmpty)
        // grassetto solo in parte: corpo
        let partial = [bodyLine("Fine della frase precedente.", yTop: 600),
                       line([("§ 12. Titolo", 11.47, true), (" e poi testo normale", 11.47, false)], yTop: 570)]
        XCTAssertTrue(titles(run(partial)).isEmpty)
    }

    // MARK: - Sezioni in maiuscoletto

    func test_sectionLabels_promotedToHeading3() {
        var nodes = [
            NodeDict(id: "n0", type: .BODY, page_index: 0, text: "Sezione prima – I PROCEDIMENTI DI PROVA"),
            NodeDict(id: "n1", type: .NOTE, page_index: 0, text: "SEZ. I: LA DISCIPLINA DI PROVA"),
            NodeDict(id: "n2", type: .BODY, page_index: 0, text: "Cass., sez. V, 12 marzo 2020, n. 1234, in una citazione"),
            NodeDict(id: "n3", type: .BODY, page_index: 0, text: "Sezione seconda – Un titolo a lettere miste di prova"),
            NodeDict(id: "n4", type: .BODY, page_index: 0, text: "Sezione prima"),
        ]
        XCTAssertEqual(promoteSectionLabels(&nodes), 2)
        XCTAssertEqual(nodes.map { $0.type }, [.HEADING_3, .HEADING_3, .BODY, .BODY, .BODY])
        XCTAssertEqual(nodes[0].level, 3)
    }

    func test_sectionLabel_tooLong_staysBody() {
        let long = "Sezione prima – " + String(repeating: "TITOLO LUNGO DI PROVA ", count: 8)
        var nodes = [NodeDict(id: "n0", type: .BODY, page_index: 0, text: long)]
        XCTAssertEqual(promoteSectionLabels(&nodes), 0)
    }
}
