//
//  PdfKitExtractorTests.swift
//  ScaboAppTests
//
//  Rete di verifica dell'estrattore PDF on-device `PdfKitExtractor`
//  (banda POST-MAC, punto 2 del piano). Gira ON-SIMULATOR: PDFKit richiede il
//  contesto app e NON è disponibile nel `swift test` macOS di ScaboCore.
//
//  Disciplina test-first del progetto, adattata al fatto che il cuore PDFKit non
//  aveva unit test (Piano § 4, zona ad alta attenzione): la rete è scritta dal
//  comportamento atteso dell'estrattore validato e ne blinda gli invarianti
//  strutturali, più la catena END-TO-END che è il vero criterio di riuscita.
//
//  Materiale: PDF **sintetizzati in-test** con `UIGraphicsPDFRenderer`. Sono
//  ermetici, deterministici e verdi su clone pulito (le 7 capture reali sono
//  gitignored / copyright). Esercitano il percorso PDFKit reale: `PDFDocument`
//  → `attributedString` → `selection(for:)` → bbox.
//
//  Catena verificata: PDF reale → PdfKitExtractor → PdfExtraction → Generic
//  (buildDocumentFromPdf) → ScabopdfDocument validato (validateAgainstSchema).
//

import PDFKit
import UIKit
import XCTest

@testable import ScaboApp
import ScaboCore

final class PdfKitExtractorTests: XCTestCase {

    private let extractor = PdfKitExtractor()

    // MARK: - Generazione di PDF reali in-test

    /// Un blocco di testo da disegnare in pagina.
    private struct Block {
        let text: String
        let size: CGFloat
        let bold: Bool
        let color: UIColor
    }

    /// A4 a punti (la geometria che le capture v2 usano: 595 × 842).
    private let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)

    /// Scrive un PDF reale su file temporaneo: ogni blocco è una riga disegnata a
    /// y crescente (origine in alto a sinistra, convenzione UIKit; PDFKit la
    /// rilegge in spazio PDF con origine in basso). Ritorna l'URL file://.
    private func makePDF(_ blocks: [Block], pages: Int = 1) throws -> URL {
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("scabo_pdfkit_test_\(UUID().uuidString).pdf")
        try renderer.writePDF(to: url) { ctx in
            for _ in 0..<pages {
                ctx.beginPage()
                var y: CGFloat = 60
                for b in blocks {
                    let font: UIFont = b.bold
                        ? UIFont.boldSystemFont(ofSize: b.size)
                        : UIFont.systemFont(ofSize: b.size)
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: font,
                        .foregroundColor: b.color,
                    ]
                    (b.text as NSString).draw(at: CGPoint(x: 72, y: y), withAttributes: attrs)
                    y += b.size + 14
                }
            }
        }
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    /// Documento canonico: un titolo grande, corpo a 11pt, una nota a 8pt.
    private func canonicalBlocks() -> [Block] {
        [
            Block(text: "Capitolo Primo — Le obbligazioni", size: 24, bold: true, color: .black),
            Block(text: "Il rapporto obbligatorio lega due soggetti determinati.", size: 11, bold: false, color: .black),
            Block(text: "Il creditore ha diritto alla prestazione dovuta dal debitore.", size: 11, bold: false, color: .black),
            Block(text: "La prestazione deve essere suscettibile di valutazione economica.", size: 11, bold: false, color: .black),
            Block(text: "L'inadempimento espone il debitore al risarcimento del danno.", size: 11, bold: false, color: .black),
            Block(text: "Cfr. art. 1218 c.c. sulla responsabilità del debitore.", size: 8, bold: false, color: .black),
        ]
    }

    // MARK: - 1. Estrazione ben formata (schema v2)

    func test_extract_producesWellFormedV2Extraction() throws {
        let url = try makePDF(canonicalBlocks())
        let extraction = try extractor.extract(fromUri: url.absoluteString)

        XCTAssertEqual(extraction.version, 2, "schema per-span")
        XCTAssertEqual(extraction.pageCount, 1)
        XCTAssertEqual(extraction.pages.count, 1)

        let page = try XCTUnwrap(extraction.pages.first)
        XCTAssertEqual(page.pageIndex, 0)
        XCTAssertEqual(page.width, 595, accuracy: 1.0)
        XCTAssertEqual(page.height, 842, accuracy: 1.0)
        XCTAssertFalse(page.lines.isEmpty, "il testo disegnato deve produrre righe")

        // Ogni riga ha almeno uno span; il testo concatenato copre titolo e corpo.
        for line in page.lines {
            XCTAssertFalse(line.spans.isEmpty)
        }
        let allText = page.lines
            .flatMap { $0.spans }
            .map { $0.text }
            .joined()
        XCTAssertTrue(allText.contains("Capitolo Primo"), "titolo recuperato; testo=\(allText)")
        XCTAssertTrue(allText.contains("creditore"), "corpo recuperato")

        // Il segnale dimensione sopravvive: la riga più grande (titolo) supera il
        // corpo. È il segnale su cui il Generic discrimina.
        let sizes = page.lines.flatMap { $0.spans }.map { $0.fontSize }.filter { $0 > 0 }
        let maxSize = try XCTUnwrap(sizes.max())
        let minSize = try XCTUnwrap(sizes.min())
        XCTAssertGreaterThan(maxSize, minSize, "titolo grande vs corpo")
        XCTAssertGreaterThan(maxSize / minSize, 1.5, "ratio titolo/corpo da heading")

        // Almeno una riga porta geometria non degenere (bbox via PDFSelection).
        let hasGeometry = page.lines.contains { $0.bbox.width > 0 && $0.bbox.height > 0 }
        XCTAssertTrue(hasGeometry, "almeno una riga deve avere bbox risolto")

        // Colore in forma "#rrggbb" su ogni span.
        for span in page.lines.flatMap({ $0.spans }) {
            XCTAssertEqual(span.color.count, 7)
            XCTAssertEqual(span.color.first, "#")
        }
    }

    // MARK: - 2. End-to-end: PDF → estrattore → Generic → Document valido

    func test_extract_thenGeneric_producesValidDocument() throws {
        let url = try makePDF(canonicalBlocks())
        let extraction = try extractor.extract(fromUri: url.absoluteString)

        let document = buildDocumentFromPdf(extraction, sourceName: "capitolo_primo.pdf")

        // (a) Il documento è VALIDO contro il contratto Layer 1: round-trip
        //     encode → validateAgainstSchema senza errori strutturali.
        let data = try JSONEncoder().encode(document)
        let errors = validateAgainstSchema(data)
        XCTAssertEqual(errors, [], "documento non conforme: \(errors)")

        // (b) Struttura non vuota e sensata: un titolo + del corpo.
        XCTAssertFalse(document.structure.isEmpty)
        let headings = document.structure.filter {
            [.HEADING_1, .HEADING_2, .HEADING_3, .HEADING_4].contains($0.type)
        }
        XCTAssertFalse(headings.isEmpty, "il titolo grande deve emergere come heading")
        XCTAssertTrue(
            headings.contains { ($0.text ?? "").contains("Capitolo Primo") },
            "il testo del titolo deve essere preservato nel nodo heading"
        )
        XCTAssertTrue(
            document.structure.contains { $0.type == .BODY },
            "le righe di corpo devono produrre almeno un nodo BODY"
        )

        // (c) Metadati coerenti con la sorgente.
        XCTAssertEqual(document.metadata.pages_pdf, 1)
        XCTAssertEqual(document.metadata.source_pdf_filename, "capitolo_primo.pdf")
        XCTAssertEqual(document.document_id, "capitolo_primo")
    }

    // MARK: - 3. Errori di apertura

    func test_extract_invalidPath_throws() {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("non_esiste_\(UUID().uuidString).pdf")
        XCTAssertThrowsError(try extractor.extract(fromUri: missing.absoluteString)) { error in
            // Messaggio leggibile (italiano) preservato dal cuore validato.
            let message = (error as NSError).localizedDescription
            XCTAssertFalse(message.isEmpty)
        }
    }

    // MARK: - 4. Multi-pagina: indici 0-based sequenziali

    func test_extract_multiPage_sequentialIndices() throws {
        let url = try makePDF(canonicalBlocks(), pages: 2)
        let extraction = try extractor.extract(fromUri: url.absoluteString)

        XCTAssertEqual(extraction.pageCount, 2)
        XCTAssertEqual(extraction.pages.count, 2)
        XCTAssertEqual(extraction.pages.map { $0.pageIndex }, [0, 1])
    }

    // MARK: - 5. Degradazione: PDF senza testo non rompe la catena

    func test_extract_imageOnlyPdf_degradesGracefully() throws {
        // Una pagina con solo un rettangolo riempito, nessun testo.
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("scabo_pdfkit_image_\(UUID().uuidString).pdf")
        try renderer.writePDF(to: url) { ctx in
            ctx.beginPage()
            UIColor.lightGray.setFill()
            ctx.fill(CGRect(x: 100, y: 100, width: 200, height: 200))
        }
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }

        // Non deve lanciare; la pagina esiste anche senza testo estraibile.
        let extraction = try extractor.extract(fromUri: url.absoluteString)
        XCTAssertEqual(extraction.version, 2)
        XCTAssertEqual(extraction.pageCount, 1)
        XCTAssertEqual(extraction.pages.count, 1)

        // E la catena a valle regge: Generic produce comunque un documento valido.
        let document = buildDocumentFromPdf(extraction, sourceName: "scansione.pdf")
        let errors = validateAgainstSchema(try JSONEncoder().encode(document))
        XCTAssertEqual(errors, [])
    }
}
