import XCTest
@testable import ScaboCore

/// Regola d'oro sulla riga del folio (giro «titoli e testatine»): una riga di PDFKit che fonde due righe FISICHE —
/// la testatina o il piè con una riga di contenuto — non si toglie mai intera. Testi sintetici.
final class FusedRowFurnitureTests: XCTestCase {

    private func span(_ t: String, x: Double, y: Double, size: Double = 10) -> PdfSpan {
        PdfSpan(text: t, fontSize: size, bold: false, italic: false, color: "#000000",
                bbox: BBox(x: x, y: y, width: Double(t.count) * size * 0.5, height: size * 1.2))
    }
    private func line(_ spans: [PdfSpan]) -> PdfTextLine {
        let x0 = spans.map { $0.bbox.x }.min()!, x1 = spans.map { $0.bbox.x + $0.bbox.width }.max()!
        let y0 = spans.map { $0.bbox.y }.min()!, y1 = spans.map { $0.bbox.y + $0.bbox.height }.max()!
        return PdfTextLine(spans: spans, bbox: BBox(x: x0, y: y0, width: x1 - x0, height: y1 - y0))
    }

    func test_disjointRows_detected_superscriptAndSameRow_not() {
        // corpo a quota 60 e piè «Pag. 12» a quota 40: due righe fisiche
        XCTAssertTrue(lineJoinsDisjointRows(line([span("ultima riga di corpo di prova.", x: 60, y: 60),
                                                  span("Pag. 12", x: 200, y: 40)])))
        // stessa riga fisica, due pezzi
        XCTAssertFalse(lineJoinsDisjointRows(line([span("Titolo corrente", x: 60, y: 780), span("12", x: 400, y: 780)])))
        // richiamo in apice: sovrapposto alla fascia della riga
        XCTAssertFalse(lineJoinsDisjointRows(line([span("parola", x: 60, y: 500), span("3", x: 100, y: 504, size: 6)])))
        XCTAssertFalse(lineJoinsDisjointRows(line([span("una sola", x: 60, y: 500)])))
    }

    func test_folioRow_fusedWithBodyLine_isKept_plainFooterRemoved() {
        // 40 pagine col piè «Pag. N» alla stessa quota. Su dieci pagine PDFKit lo fonde con l'ultima riga di corpo:
        // le righe fuse stanno tutte alla quota dell'ultima riga del blocco di testo, e fanno da sole uno «slot»
        // della riga del folio (folio come ultimo token): senza la regola d'oro sparivano intere.
        let fused = Set(5..<15)
        let pages = (0..<40).map { i -> PdfPageExtraction in
            var lines = [line([span("Riga di corpo numero \(i) di un paragrafo di prova qualunque.", x: 60, y: 500)])]
            if fused.contains(i) {
                // testo diverso su ogni pagina (come nella realtà): nessun canale di ricorrenza lo vede
                let w = ["alfa", "beta", "gamma", "delta", "epsilon", "zeta", "eta", "theta", "iota", "kappa"][i - 5]
                lines.append(line([span("e la frase \(w) della pagina si chiude qui.", x: 60, y: 60),
                                   span("Pag. \(i + 10)", x: 200, y: 40)]))
            } else {
                lines.append(line([span("Pag. \(i + 10)", x: 200, y: 40)]))
            }
            return PdfPageExtraction(pageIndex: i, width: 400, height: 800, lines: lines)
        }
        let furniture = detectFurniture(PdfExtraction(version: 2, pageCount: 40, pages: pages))
        XCTAssertTrue(furniture.contains("3:1"), "il piè «Pag. N» da solo è mobilia")
        for i in fused { XCTAssertFalse(furniture.contains("\(i):1"), "il piè fuso con l'ultima riga di corpo (p. \(i)) resta letto") }
    }
}
