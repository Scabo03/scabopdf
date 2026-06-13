//
//  ProgressBuildTests.swift
//  ScaboCoreTests
//
//  Verifica del build progress-aware e cancellabile aggiunto ADDITIVAMENTE alla catena di
//  classificazione (sessione import). Gira su macOS via `swift test`: è pura logica su una
//  `PdfExtraction` costruita a mano, senza PDFKit né Simulator.
//
//  Cosa è verificabile QUI:
//    • il reporting di progresso è REALE e monotòno: dato M pagine, i callback arrivano con
//      `done` crescente da 1 a M, esattamente M volte, terminando a (M, M);
//    • la cancellazione cooperativa interrompe il build a una tappa naturale e ritorna `nil`,
//      SENZA produrre un documento (parziale) spacciato per valido;
//    • il percorso non cancellato è IDENTICO al `build(_:sourceName:)` sincrono (fedeltà:
//      il progresso/cancellazione non altera l'output).
//

import XCTest
@testable import ScaboCore

final class ProgressBuildTests: XCTestCase {

    private func line(_ text: String, size: Double = 12, bold: Bool = false) -> PdfTextLine {
        PdfTextLine(
            spans: [PdfSpan(text: text, fontSize: size, bold: bold, italic: false, color: "#000000",
                            bbox: BBox(x: 0, y: 0, width: 0, height: 0))],
            bbox: BBox(x: 0, y: 0, width: 0, height: 0)
        )
    }

    /// Documento sintetico di `pageCount` pagine, ciascuna con un titolo + alcune righe di corpo.
    private func multiPageExtraction(_ pageCount: Int) -> PdfExtraction {
        let pages: [[PdfTextLine]] = (0..<pageCount).map { p in
            [
                line("Capitolo \(p + 1)", size: 20, bold: true),
                line("Primo paragrafo di corpo della pagina \(p + 1) del documento di prova."),
                line("Secondo paragrafo di corpo della pagina \(p + 1), abbastanza lungo da contare."),
                line("Terzo paragrafo di corpo della pagina \(p + 1) per consolidare la stima.")
            ]
        }
        return PdfExtraction(
            version: 2,
            pageCount: pageCount,
            pages: pages.enumerated().map { idx, lines in
                PdfPageExtraction(pageIndex: idx, width: 595, height: 842, lines: lines)
            }
        )
    }

    // MARK: - Progresso reale e monotòno

    func test_progressIsMonotonicAndReachesTotal() {
        let pageCount = 8
        let extraction = multiPageExtraction(pageCount)

        var ticks: [(done: Int, total: Int)] = []
        let document = buildDocumentFromPdf(
            extraction,
            sourceName: "prova.pdf",
            onPageClassified: { done, total in ticks.append((done, total)) },
            isCancelled: { false }
        )

        XCTAssertNotNil(document, "senza cancellazione il build deve completare")
        XCTAssertEqual(ticks.count, pageCount, "un tick per pagina realmente elaborata")
        XCTAssertEqual(ticks.map { $0.total }, Array(repeating: pageCount, count: pageCount),
                       "il totale annunciato è costante = numero di pagine")
        XCTAssertEqual(ticks.map { $0.done }, Array(1...pageCount),
                       "done cresce monotòno 1…M, senza salti né regressioni")
        XCTAssertEqual(ticks.last?.done, pageCount, "l'ultimo tick raggiunge il totale")
    }

    func test_progressBuildMatchesPlainBuild() {
        let extraction = multiPageExtraction(5)

        let plain = buildDocumentFromPdf(extraction, sourceName: "prova.pdf")
        let withProgress = buildDocumentFromPdf(
            extraction,
            sourceName: "prova.pdf",
            onPageClassified: { _, _ in },
            isCancelled: { false }
        )

        // Fedeltà: il percorso progress-aware produce ESATTAMENTE lo stesso documento.
        XCTAssertEqual(withProgress, plain,
                       "il reporting di progresso non altera l'output della classificazione")
    }

    // MARK: - Cancellazione cooperativa

    func test_cancellationStopsEarlyAndReturnsNilNoPartialDocument() {
        let pageCount = 20
        let extraction = multiPageExtraction(pageCount)

        // Cancella dopo aver elaborato 3 pagine: la 4ª tappa naturale rileva la cancellazione.
        var processed = 0
        let document = buildDocumentFromPdf(
            extraction,
            sourceName: "prova.pdf",
            onPageClassified: { _, _ in processed += 1 },
            isCancelled: { processed >= 3 }
        )

        XCTAssertNil(document, "cancellato: nessun documento (neanche parziale) viene restituito")
        XCTAssertLessThan(processed, pageCount, "il build si è fermato prima di elaborare tutte le pagine")
        XCTAssertGreaterThanOrEqual(processed, 3, "ha comunque elaborato le pagine fino al punto di stop")
    }

    func test_cancellationBeforeAnyWork_returnsNilImmediately() {
        let extraction = multiPageExtraction(10)
        var ticks = 0
        let document = buildDocumentFromPdf(
            extraction,
            sourceName: "prova.pdf",
            onPageClassified: { _, _ in ticks += 1 },
            isCancelled: { true }   // già cancellato in partenza
        )
        XCTAssertNil(document, "cancellato in partenza: ritorna nil")
        XCTAssertEqual(ticks, 0, "nessuna pagina elaborata se la cancellazione è immediata")
    }

    func test_emptyExtraction_completesWithZeroTicks() {
        let extraction = PdfExtraction(version: 2, pageCount: 0, pages: [])
        var ticks = 0
        let document = buildDocumentFromPdf(
            extraction,
            sourceName: "vuoto.pdf",
            onPageClassified: { _, _ in ticks += 1 },
            isCancelled: { false }
        )
        XCTAssertNotNil(document, "zero pagine è un documento valido (vuoto), non un errore")
        XCTAssertEqual(ticks, 0, "nessuna pagina → nessun tick di progresso")
        XCTAssertEqual(document?.structure.count, 0)
    }
}
