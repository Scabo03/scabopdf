//
//  HeadFragmentRecompositionTests.swift
//  ScaboCoreTests
//
//  Le TESTE-FRAMMENTO (giro «pulizia e rifinitura finale del capitolo note», 2026-10-17): l'estrazione stacca dalla nota
//  vera un frammento che comincia con un numero spurio a inizio riga (un numero d'articolo o di pagina, una data), e la
//  ricucitura fra pagine contigue univa la coda della pagina seguente al frammento, lasciando la nota divisa in due. Ora
//  il frammento torna nella sua nota quando la successione oltre la pagina lo prova (la prima nota numerata dopo la coda
//  porta il numero della nota vera più uno) e la sua riga sta al margine delle righe di seguito, non al rientro delle
//  aperture. Estrazioni sintetiche con geometria, pipeline reale; ogni condizione ha la sua prova al contrario. Testi
//  neutri, inventati.
//

import XCTest
@testable import ScaboCore

final class HeadFragmentRecompositionTests: XCTestCase {

    private let opening = 74.0   // rientro delle aperture di nota
    private let margin = 60.0    // margine delle righe di seguito

    private func line(_ text: String, size: Double, x: Double, y: Double) -> PdfTextLine {
        PdfTextLine(spans: [PdfSpan(text: text, fontSize: size, bold: false, italic: false, color: "#000000",
                                    bbox: BBox(x: x, y: y, width: 420, height: size))],
                    bbox: BBox(x: x, y: y, width: 420, height: size))
    }
    private func bodyLines(_ tag: String) -> [PdfTextLine] {
        (0..<6).map { line("Riga di corpo \(tag) numero \($0) che prosegue il discorso", size: 10, x: 60, y: 760 - Double($0) * 14) }
    }
    /// Pagina A: la nota 20 (chiusa), la nota 21 su due righe, poi il frammento con il numero spurio; pagina B: la coda e
    /// la nota `next`.
    private func pages(fragment: String = "680. Sul tema la nota prosegue e", fragmentX: Double? = nil,
                       next: Int = 22, openingX: Double? = nil, bodyBetween: Bool = false) -> PdfExtraction {
        let ox = openingX ?? opening
        var a = bodyLines("a")
        a.append(line("20 Una nota chiusa", size: 8, x: ox, y: 151))
        a.append(line("su due righe.", size: 8, x: margin, y: 140))
        a.append(line("21 La nota vera comincia qui e rinvia a quanto detto a p.", size: 8, x: ox, y: 129))
        a.append(line("seconda riga della nota vera che rinvia ancora a p.", size: 8, x: margin, y: 118))
        if bodyBetween { a.append(line("Riga di corpo frapposta che chiude la pagina", size: 10, x: 60, y: 107)) }
        a.append(line(fragment, size: 8, x: fragmentX ?? margin, y: bodyBetween ? 96 : 107))
        var b = bodyLines("b")
        b.append(line("continua sulla pagina seguente fino al punto.", size: 8, x: margin, y: 140))
        b.append(line("\(next) Nota nuova della seconda pagina.", size: 8, x: ox, y: 129))
        return PdfExtraction(version: 2, pageCount: 2,
                             pages: [PdfPageExtraction(pageIndex: 0, width: 595, height: 842, lines: a),
                                     PdfPageExtraction(pageIndex: 1, width: 595, height: 842, lines: b)], producer: nil)
    }
    private func placed(_ ex: PdfExtraction) -> (ScabopdfDocument, NotePlacementStats) {
        bindAndPlaceNotes(buildDocumentFromPdf(ex, sourceName: "t.pdf"), ex)
    }
    private func noteTexts(_ doc: ScabopdfDocument) -> [String] {
        doc.structure.filter { $0.type == .NOTE }.map { $0.text ?? "" }
    }
    private let whole = "21 La nota vera comincia qui e rinvia a quanto detto a p. seconda riga della nota vera che rinvia ancora a p. "
        + "680. Sul tema la nota prosegue e continua sulla pagina seguente fino al punto."

    func test_recomposes_theFragmentWithItsNote_whenSuccessionAndGeometryProveIt() {
        let (doc, stats) = placed(pages())
        let notes = noteTexts(doc)
        XCTAssertTrue(notes.contains(whole), "la nota intera, nell'ordine: \(notes)")
        XCTAssertFalse(notes.contains { $0.hasPrefix("680.") }, "il frammento non è più una nota a sé")
        XCTAssertTrue(notes.contains("22 Nota nuova della seconda pagina."))
        XCTAssertTrue(notes.contains("20 Una nota chiusa su due righe."))
        XCTAssertEqual(stats.stitchedAdjacentPage, 1)
        XCTAssertNotNil(stats.adjacentPageCandidates.first?.recomposedFragmentId)
        XCTAssertEqual(stats.adjacentPageCandidates.first?.succession, "confermata")
    }

    func test_noRecomposition_whenTheFragmentLineIsIndentedLikeAnOpening() {
        // la riga del frammento sta al rientro delle aperture: potrebbe aprire una nota, non si ricompone
        let (doc, stats) = placed(pages(fragmentX: opening))
        XCTAssertNil(stats.adjacentPageCandidates.first?.recomposedFragmentId)
        XCTAssertFalse(noteTexts(doc).contains(whole))
        XCTAssertTrue(noteTexts(doc).contains { $0.hasPrefix("21 ") && !$0.contains("680.") }, "la nota vera resta com'era")
    }

    func test_noRecomposition_whenTheSuccessionDoesNotResumeWithTheTrueNoteNumber() {
        // dopo la coda la successione riprende con 23, non con 22: nulla prova che il frammento appartenga alla nota 21
        let (doc, stats) = placed(pages(next: 23))
        XCTAssertNil(stats.adjacentPageCandidates.first?.recomposedFragmentId)
        XCTAssertFalse(noteTexts(doc).contains(whole))
    }

    func test_noRecomposition_whenTheFragmentCarriesTheNextNumber() {
        // il «frammento» porta il numero 22: è la nota seguente vera (e la successione dopo la coda è 23)
        let (doc, stats) = placed(pages(fragment: "22 Nota seguente che resta aperta e", next: 23))
        XCTAssertNil(stats.adjacentPageCandidates.first?.recomposedFragmentId)
        XCTAssertTrue(noteTexts(doc).contains { $0.hasPrefix("22 Nota seguente") })
    }

    func test_noRecomposition_whenTheFragmentCarriesTheTrueNoteNumberPlusOne_evenIfTheNextOneRepeatsIt() {
        // il frammento porta il numero 22 e anche la nota dopo la coda porta 22: numerazione doppia, nel dubbio non si tocca
        let (doc, stats) = placed(pages(fragment: "22 Nota seguente che resta aperta e", next: 22))
        XCTAssertNil(stats.adjacentPageCandidates.first?.recomposedFragmentId)
        XCTAssertTrue(noteTexts(doc).contains { $0.hasPrefix("21 ") && !$0.contains("22 Nota seguente") })
    }

    func test_noRecomposition_withoutAMeasurableContinuationMargin() {
        // una sola riga di seguito nel nodo: il margine non è misurabile, nel dubbio non si ricompone
        var a = bodyLines("a")
        a.append(line("21 La nota vera comincia qui e rinvia a quanto detto a p.", size: 8, x: opening, y: 129))
        a.append(line("680. Sul tema la nota prosegue e", size: 8, x: margin, y: 118))
        var b = bodyLines("b")
        b.append(line("continua sulla pagina seguente fino al punto.", size: 8, x: margin, y: 140))
        b.append(line("22 Nota nuova della seconda pagina.", size: 8, x: opening, y: 129))
        let ex = PdfExtraction(version: 2, pageCount: 2,
                               pages: [PdfPageExtraction(pageIndex: 0, width: 595, height: 842, lines: a),
                                       PdfPageExtraction(pageIndex: 1, width: 595, height: 842, lines: b)], producer: nil)
        let (_, stats) = placed(ex)
        XCTAssertNil(stats.adjacentPageCandidates.first?.recomposedFragmentId)
    }

    func test_noRecomposition_withoutAMeasurableOpeningIndent() {
        // aperture e righe di seguito allo stesso margine: la geometria non distingue, nel dubbio non si ricompone
        let (doc, stats) = placed(pages(openingX: margin))
        XCTAssertNil(stats.adjacentPageCandidates.first?.recomposedFragmentId)
        XCTAssertFalse(noteTexts(doc).contains(whole))
    }

    func test_noRecomposition_whenTheTrueNoteIsInAnotherNode() {
        // una riga di corpo fra la nota vera e il frammento: due nodi diversi, non righe contigue dell'apparato
        let (doc, stats) = placed(pages(bodyBetween: true))
        XCTAssertNil(stats.adjacentPageCandidates.first?.recomposedFragmentId)
        XCTAssertFalse(noteTexts(doc).contains(whole))
    }

    func test_footnoteLineRanges_mirrorsSplitFootnotes() {
        let lines = [line("12 Prima nota.", size: 8, x: 74, y: 140), line("seguito della prima.", size: 8, x: 60, y: 129),
                     line("* Nota a simbolo.", size: 8, x: 74, y: 118), line("13 Terza nota.", size: 8, x: 74, y: 107)]
            .map { summarizeLine($0) }
        XCTAssertEqual(footnoteLineRanges(lines), [0..<2, 2..<3, 3..<4])
        XCTAssertEqual(splitFootnotes(lines, page: 0).count, footnoteLineRanges(lines).count)
    }
}
