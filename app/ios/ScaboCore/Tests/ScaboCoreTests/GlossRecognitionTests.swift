//
//  GlossRecognitionTests.swift
//  ScaboCoreTests
//
//  Riconoscimento geometrico delle glosse laterali (§ docs/GLOSSE_LATERALI.md):
//  riga PICCOLA + FUORI dalla colonna del corpo (margine) → MARGINAL_GLOSS, fuori
//  dal flusso letto; nota PICCOLA ma DENTRO la colonna → resta NOTE e agganciabile;
//  folio/numero-romano a margine → NON glossa; colonna stimata PER-PAGINA (margini
//  alternati); astensione quando la colonna è incerta.
//

import XCTest
@testable import ScaboCore

final class GlossRecognitionTests: XCTestCase {

    // riga a posizione x esplicita (la bbox di LINEA governa x0/x1 in summarizeLine)
    private func lineAt(_ text: String, size: Double, x0: Double, x1: Double, y: Double) -> PdfTextLine {
        let bbox = BBox(x: x0, y: y, width: x1 - x0, height: size)
        return PdfTextLine(
            spans: [PdfSpan(text: text, fontSize: size, bold: false, italic: false,
                            color: "#000000", bbox: bbox)],
            bbox: bbox)
    }
    private func page(_ idx: Int, _ lines: [PdfTextLine], width: Double = 595, height: Double = 842) -> PdfPageExtraction {
        PdfPageExtraction(pageIndex: idx, width: width, height: height, lines: lines)
    }
    private func doc(_ pages: [PdfPageExtraction]) -> ScabopdfDocument {
        buildDocumentFromPdf(PdfExtraction(version: 2, pageCount: pages.count, pages: pages), sourceName: "g.pdf")
    }
    private func bodyLines(_ n: Int, size: Double = 10) -> [PdfTextLine] {
        (0..<n).map { lineAt("Riga di corpo numero \($0) abbastanza lunga da riempire la colonna.",
                             size: size, x0: 100, x1: 450, y: 60 + Double($0) * 14) }
    }
    private func nodes(_ d: ScabopdfDocument, _ cat: SemanticCategory) -> [NodeDict] {
        d.structure.filter { $0.type == cat }
    }
    private func texts(_ d: ScabopdfDocument, _ cat: SemanticCategory) -> String {
        nodes(d, cat).map { $0.text ?? "" }.joined(separator: " | ")
    }

    // colonna del corpo ≈ [100, 450]; glossa a sinistra (x1<95), nota in colonna.
    func test_marginGloss_becomesMarginalGloss_realNoteStaysNote() {
        var lines = bodyLines(6)
        lines.insert(lineAt("Socialità del diritto", size: 6.5, x0: 40, x1: 85, y: 75), at: 1)   // glossa sx
        lines.append(lineAt("12 Nota vera a piè di pagina nella colonna.", size: 8.0, x0: 100, x1: 420, y: 800))  // nota in colonna
        let d = doc([page(0, lines)])

        XCTAssertTrue(texts(d, .MARGINAL_GLOSS).contains("Socialità del diritto"),
                      "la glossa a margine diventa MARGINAL_GLOSS")
        XCTAssertTrue(texts(d, .NOTE).contains("Nota vera a piè"),
                      "la nota dentro la colonna resta NOTE")
        XCTAssertFalse(texts(d, .NOTE).contains("Socialità"), "la glossa NON resta NOTE")
        XCTAssertFalse(texts(d, .MARGINAL_GLOSS).contains("Nota vera"), "la nota NON diventa glossa")
    }

    func test_marginalGloss_excludedFromReadingFlow_butKeptInDocument() {
        var lines = bodyLines(6)
        lines.insert(lineAt("Norma giuridica e norma morale", size: 6.5, x0: 40, x1: 85, y: 75), at: 2)
        let d = doc([page(0, lines)])
        // resta nel documento (categoria conservata, reversibile)…
        XCTAssertEqual(nodes(d, .MARGINAL_GLOSS).count, 1)
        // …ma NON entra nel flusso letto
        let read = buildBaseSegments(d).map { $0.text }.joined(separator: " ")
        XCTAssertFalse(read.contains("Norma giuridica e norma morale"), "la glossa è scartata dal flusso letto")
        XCTAssertTrue(read.contains("Riga di corpo"), "il corpo è letto")
    }

    func test_folioAndRomanInMargin_areNotGlosses() {
        var lines = bodyLines(6)
        lines.insert(lineAt("728", size: 6.5, x0: 40, x1: 85, y: 50), at: 0)        // folio numerico a margine
        lines.insert(lineAt("VIII", size: 6.5, x0: 40, x1: 85, y: 300), at: 4)      // romano di capitolo a margine
        let d = doc([page(0, lines)])
        XCTAssertEqual(nodes(d, .MARGINAL_GLOSS).count, 0, "folio e romano a margine NON sono glosse")
        XCTAssertFalse(texts(d, .MARGINAL_GLOSS).contains("728"))
        XCTAssertFalse(texts(d, .MARGINAL_GLOSS).contains("VIII"))
    }

    // margini alternati recto/verso: stima della colonna PER-PAGINA.
    func test_perPageColumn_alternatingMargins_bothRecognised() {
        let p0 = page(0, bodyLines(6) + [lineAt("Glossa a sinistra", size: 6.5, x0: 40, x1: 88, y: 75)])
        let p1 = page(1, bodyLines(6) + [lineAt("Glossa a destra", size: 6.5, x0: 470, x1: 545, y: 75)])
        let d = doc([p0, p1])
        let g = texts(d, .MARGINAL_GLOSS)
        XCTAssertTrue(g.contains("Glossa a sinistra"), "glossa nel margine sinistro (verso)")
        XCTAssertTrue(g.contains("Glossa a destra"), "glossa nel margine destro (recto)")
        XCTAssertEqual(nodes(d, .MARGINAL_GLOSS).count, 2)
    }

    // stima colonna ROBUSTA: una riga corpo-larga con x0 anomalo (bordo pagina) NON
    // deve collassare il bordo-colonna e far sfuggire la glossa (causa reale delle
    // sfuggite del Torrente: colX0 stimato a ~9 col min invece di ~100 con la mediana).
    func test_outlierBodyLine_doesNotHideGloss() {
        var lines = bodyLines(6)  // colonna a x0=100, x1=450
        // outlier: riga corpo-larga che parte dal bordo sinistro (x0=9)
        lines.append(lineAt("Riga anomala che parte dal bordo sinistro della pagina molto larga.",
                            size: 10, x0: 9, x1: 300, y: 500))
        // glossa a margine sinistro
        lines.insert(lineAt("Servitù", size: 6.5, x0: 40, x1: 85, y: 120), at: 2)
        let d = doc([page(0, lines)])
        XCTAssertTrue(texts(d, .MARGINAL_GLOSS).contains("Servitù"),
                      "la glossa è riconosciuta nonostante l'outlier di colonna (mediana, non min)")
    }

    // astensione: senza colonna stimabile (poche righe-corpo) una riga a margine resta NOTE.
    func test_abstain_whenColumnUnknown() {
        // 2 sole righe-corpo (< MIN_BODY_LINES_FOR_COLUMN) + una riga piccola "a margine"
        let lines = bodyLines(2) + [lineAt("Forse glossa forse no", size: 6.5, x0: 40, x1: 85, y: 90)]
        let d = doc([page(0, lines)])
        XCTAssertEqual(nodes(d, .MARGINAL_GLOSS).count, 0, "colonna incerta → astensione (niente scarto)")
        XCTAssertTrue(texts(d, .NOTE).contains("Forse glossa"), "nel dubbio resta NOTE (contenuto conservato)")
    }

    // Rete B a livello unità: la glossa non interferisce con l'aggancio della nota vera.
    func test_glossDoesNotBreakNoteBinding() {
        var lines = bodyLines(6)
        // corpo con richiamo SMALLER "7" + nota vera "7" in colonna + glossa a margine
        lines.append(PdfTextLine(spans: [
            PdfSpan(text: "Testo con richiamo", fontSize: 10, bold: false, italic: false, color: "#000000",
                    bbox: BBox(x: 100, y: 700, width: 200, height: 10)),
            PdfSpan(text: "7", fontSize: 6, bold: false, italic: false, color: "#000000",
                    bbox: BBox(x: 300, y: 700, width: 6, height: 6)),
            PdfSpan(text: " e fine frase qui.", fontSize: 10, bold: false, italic: false, color: "#000000",
                    bbox: BBox(x: 306, y: 700, width: 120, height: 10)),
        ], bbox: BBox(x: 100, y: 700, width: 340, height: 10)))
        lines.append(lineAt("7 La nota vera richiamata.", size: 8.0, x0: 100, x1: 420, y: 800))
        lines.insert(lineAt("Glossa marginale", size: 6.5, x0: 40, x1: 85, y: 120), at: 1)
        let raw = doc([page(0, lines)])
        let (placed, stats) = bindAndPlaceNotes(raw, PdfExtraction(version: 2, pageCount: 1, pages: [page(0, lines)]))
        XCTAssertEqual(stats.boundSamePage, 1, "la nota vera resta agganciata nonostante la glossa")
        XCTAssertTrue(placed.structure.contains { $0.type == .MARGINAL_GLOSS }, "la glossa resta categorizzata")
        XCTAssertFalse(placed.structure.contains { $0.type == .MARGINAL_GLOSS && ($0.text ?? "").contains("nota vera") })
    }
}
