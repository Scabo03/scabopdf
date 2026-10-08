//
//  RowSplitTests.swift
//  ScaboCoreTests
//
//  Righe fuse (giro finale 2026-10-08, voce 5): la riga di PDFKit che unisce la testatina o il piè a una riga di
//  contenuto si riporta alle sue righe fisiche; tutto il resto resta com'è. Ogni guardia ha il suo test, che fallisce
//  togliendo la guardia (prova al contrario eseguita a mano nel giro). Testi di prova; geometria reale (origine in basso).
//

import XCTest
@testable import ScaboCore

final class RowSplitTests: XCTestCase {

    private let H = 680.0

    /// Span con la sommità a `top` (asse y verso l'alto), larghezza proporzionale al testo.
    private func span(_ text: String, x: Double = 60, top: Double, size: Double = 10, color: String = "#000000") -> PdfSpan {
        PdfSpan(text: text, fontSize: size, bold: false, italic: false, color: color,
                bbox: BBox(x: x, y: top - size, width: Double(text.count) * size * 0.5, height: size))
    }
    /// La riga come la consegna PDFKit: tutti gli span insieme, riquadro che li contiene.
    private func fused(_ spans: [PdfSpan]) -> PdfTextLine {
        let boxes = spans.map { $0.bbox }.filter { $0.width > 0 || $0.height > 0 }
        let x0 = boxes.map { $0.x }.min() ?? 0, y0 = boxes.map { $0.y }.min() ?? 0
        let x1 = boxes.map { $0.x + $0.width }.max() ?? 0, y1 = boxes.map { $0.y + $0.height }.max() ?? 0
        return PdfTextLine(spans: spans, bbox: BBox(x: x0, y: y0, width: x1 - x0, height: y1 - y0))
    }
    private func letters(_ lines: [PdfTextLine]) -> [Character] {
        lines.flatMap { $0.spans.map { $0.text } }.joined().filter { !$0.isWhitespace }.sorted()
    }
    private func texts(_ lines: [PdfTextLine]) -> [String] { lines.map { $0.spans.map { $0.text }.joined() } }

    // 1
    func test_runningHeadFusedWithFirstBodyRow_splitsTopDown_lettersKept() {
        let line = fused([span("Prima riga di prova del corpo", top: 560), span("Testatina di prova", x: 200, top: 650, size: 8)])
        let out = splittingFusedBandRows([line], pageHeight: H)
        XCTAssertEqual(texts(out), ["Testatina di prova", "Prima riga di prova del corpo"], "due righe, dall'alto in basso")
        XCTAssertEqual(letters(out), letters([line]), "nessuna lettera aggiunta o tolta")
        XCTAssertEqual(out[0].bbox.y + out[0].bbox.height, 650, accuracy: 0.01, "la riga in banda ha il suo riquadro")
    }

    // 2
    func test_noteCallOnItsOwnBand_staysWithItsRow() {
        let line = fused([span("Riga di prova con un richiamo", top: 650), span("(1)", x: 210, top: 657, size: 6)])
        XCTAssertEqual(splittingFusedBandRows([line], pageHeight: H).count, 1)
    }

    // 3
    func test_dropCapOfOneLetter_staysWithItsRow() {
        let line = fused([span("Q", x: 40, top: 676, size: 30), span("uesta riga di prova apre il capitolo", top: 640)])
        XCTAssertEqual(splittingFusedBandRows([line], pageHeight: H).count, 1)
    }

    // 4
    func test_bareNumberMidPage_gluedToRunningHead_isNotDetached() {
        let line = fused([span("Testatina di prova", x: 200, top: 650, size: 8), span("2.", top: 310)])
        XCTAssertEqual(splittingFusedBandRows([line], pageHeight: H).count, 1, "staccato, il numero salirebbe in cima alla pagina")
    }

    // 5
    func test_blackLineWithWhiteHeadBand_isNotSplit() {
        let line = fused([span("Riga di prova del corpo che porta quasi tutte le lettere della riga fusa", top: 560),
                          span("Fascia", x: 200, top: 650, size: 8, color: "#ffffff")])
        XCTAssertEqual(splittingFusedBandRows([line], pageHeight: H).count, 1, "la fascia bianca da sola sarebbe scartata")
    }

    // 6
    func test_nearWhiteTabLine_withBlackContentBand_isSplit() {
        let line = fused([span("Linguetta bianca di prova lunga", x: 200, top: 650, size: 8, color: "#ffffff"),
                          span("Corpo nero", top: 600)])
        let out = splittingFusedBandRows([line], pageHeight: H)
        XCTAssertEqual(texts(out), ["Linguetta bianca di prova lunga", "Corpo nero"], "il contenuto nero torna una riga a sé")
    }

    // 7
    func test_spanWithNullBox_orBlank_doesNotFoundABand() {
        let blank = PdfSpan(text: "   ", fontSize: 10, bold: false, italic: false, color: "#000000", bbox: BBox(x: 60, y: 200, width: 10, height: 10))
        let nullBox = PdfSpan(text: "xy", fontSize: 10, bold: false, italic: false, color: "#000000", bbox: BBox(x: 0, y: 0, width: 0, height: 0))
        let line = fused([span("Testatina di prova", x: 200, top: 650, size: 8), nullBox, blank])
        let out = splittingFusedBandRows([line], pageHeight: H)
        XCTAssertEqual(out.count, 1)
        XCTAssertEqual(texts(out), texts([line]))
    }

    // 8
    func test_fusionMidPage_noRowInTheBands_isNotSplit() {
        let line = fused([span("Riga di prova a metà pagina", top: 410), span("Altra riga di prova a metà pagina", top: 390)])
        XCTAssertEqual(splittingFusedBandRows([line], pageHeight: H).count, 1)
    }

    func test_ordinaryRow_unchanged() {
        let line = fused([span("Una riga", top: 650), span(" di prova", x: 100, top: 650)])
        XCTAssertEqual(texts(splittingFusedBandRows([line], pageHeight: H)), texts([line]))
    }
}
