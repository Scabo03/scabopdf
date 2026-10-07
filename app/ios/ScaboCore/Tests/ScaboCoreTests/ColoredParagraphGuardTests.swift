//
//  ColoredParagraphGuardTests.swift
//  ScaboCoreTests
//
//  Guardia «paragrafo colorato» del canale a colore (D4): una pila di righe colorate a taglia di corpo che
//  arrivano al margine è un paragrafo (resta corpo); i titoli colorati veri — corti, su due righe, o più
//  grandi del corpo — restano titoli. Testi di prova.
//

import XCTest
@testable import ScaboCore

final class ColoredParagraphGuardTests: XCTestCase {

    private let green = "#2E7D32"
    private let words = ["alfa", "beta", "gamma", "delta", "epsilon", "zeta", "eta", "theta", "iota", "kappa"]

    private func ln(_ text: String, y: Double, w: Double, size: Double = 10, color: String = "#000000") -> PdfTextLine {
        let box = BBox(x: 60, y: y, width: w, height: size * 1.2)
        return PdfTextLine(spans: [PdfSpan(text: text, fontSize: size, bold: false, italic: false, color: color, bbox: box)],
                           bbox: box)
    }
    /// Pagina: corpo nero a 10 pt (righe piene a 400 di larghezza) e, in mezzo, le righe colorate date.
    private func page(_ index: Int, colored: [(String, Double, Double)]) -> PdfPageExtraction {
        var lines: [PdfTextLine] = []
        var y = 760.0
        for k in 0..<8 {
            lines.append(ln("Riga di corpo \(words[k]) \(index) che riempie la colonna di prova fino al margine e", y: y, w: 400))
            y -= 12
        }
        y -= 10
        for c in colored {
            lines.append(ln(c.0, y: y, w: c.1, size: c.2, color: green)); y -= c.2 * 1.2
        }
        y -= 10
        for k in 0..<8 {
            lines.append(ln("Altra riga di corpo \(words[k]) \(index) che riempie la colonna fino al margine e", y: y, w: 400))
            y -= 12
        }
        return PdfPageExtraction(pageIndex: index, width: 595, height: 842, lines: lines)
    }
    private func headings(_ p: PdfPageExtraction, _ e: PdfExtraction) -> [String] {
        let profile = estimateProfile(e)
        return pageItems(p, profile, [], 0, [:]).compactMap {
            if case let .heading(sm, _) = $0 { return sm.text } else { return nil }
        }
    }
    private func doc(_ special: PdfPageExtraction) -> PdfExtraction {
        var pages = (0..<4).map { page($0, colored: []) }
        pages[2] = special
        return PdfExtraction(version: 2, pageCount: pages.count, pages: pages)
    }

    func test_coloredAbstract_eightFullLines_staysBody() {
        let abstract = (0..<8).map { k -> (String, Double, Double) in
            (k == 7 ? "e si chiude la frase \(words[k]) dell'abstract di prova." : "Riga \(words[k]) di un abstract colorato di prova che arriva al margine", k == 7 ? 250 : 398, 10)
        }
        let p = page(2, colored: abstract)
        XCTAssertEqual(headings(p, doc(p)), [], "un paragrafo colorato a taglia di corpo non è una pila di titoli")
    }

    func test_shortColoredTitle_andTwoRowTitle_stayTitles() {
        let p = page(2, colored: [("Titolo colorato di prova", 160, 10)])
        XCTAssertEqual(headings(p, doc(p)), ["Titolo colorato di prova"])
        let p2 = page(2, colored: [("Titolo colorato di prova che va a capo fino al margine destro", 398, 10),
                                   ("e finisce sulla seconda riga", 180, 10)])
        XCTAssertEqual(headings(p2, doc(p2)), ["Titolo colorato di prova che va a capo fino al margine destro e finisce sulla seconda riga"],
                       "due righe: sotto la soglia del paragrafo, restano titolo (fuso dalla fusione dei titoli spezzati)")
    }

    func test_threeRowColoredTitle_largerThanBody_staysTitle() {
        let rows: [(String, Double, Double)] = [("Titolo colorato grande di prova", 398, 12),
                                               ("che va a capo su tre righe", 398, 12),
                                               ("fino alla fine", 120, 12)]
        let p = page(2, colored: rows)
        XCTAssertEqual(headings(p, doc(p)), ["Titolo colorato grande di prova che va a capo su tre righe fino alla fine"],
                       "a 1,2 × corpo la guardia non scatta: resta titolo")
    }

    func test_threeColoredLines_withOnlyOneFull_stayTitles() {
        // tre righe colorate corte (sommario di titoli, elenco): non sono un paragrafo
        let p = page(2, colored: [("Primo titolo colorato", 150, 10), ("Secondo titolo colorato", 160, 10),
                                  ("Terzo titolo colorato fino al margine destro della colonna di prova", 398, 10)])
        XCTAssertEqual(headings(p, doc(p)).joined(separator: " "),
                       "Primo titolo colorato Secondo titolo colorato Terzo titolo colorato fino al margine destro della colonna di prova",
                       "una sola riga piena: non è un paragrafo, le righe restano titoli")
    }
}
