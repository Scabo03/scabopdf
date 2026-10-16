//
//  ScaboChainTests.swift
//  ScaboChainTests
//
//  Prove sull'host (macOS) della catena condivisa: l'estrattore con le sue cure gira sul Mac con la stessa lettura
//  di taglia, tratti e colore; la catena con le opzioni dell'iPad non innesta e, dal 2026-10-16, fraziona le note lunghe
//  come il Mac e gli atti AKN; l'innesto (solo Mac) si accende solo a richiesta; l'annullamento è pulito. PDF e documenti
//  sintetici con parole di prova: nessun testo dei volumi.
//

import CoreGraphics
import CoreText
import Foundation
import ScaboCore
import XCTest
@testable import ScaboChain

enum SyntheticPDF {
    /// Scrive un PDF di `pages` pagine (595×842 pt) disegnate dal blocco (indice di pagina) e ne restituisce l'URL.
    static func make(pages: Int = 1, _ draw: (CGContext, Int) -> Void) -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("sintetico-catena-\(UUID().uuidString).pdf")
        var box = CGRect(x: 0, y: 0, width: 595, height: 842)
        let ctx = CGContext(url as CFURL, mediaBox: &box, nil)!
        for p in 0..<pages {
            ctx.beginPDFPage(nil)
            draw(ctx, p)
            ctx.endPDFPage()
        }
        ctx.closePDF()
        return url
    }

    /// Una riga di testo neutro con font, taglia e colore dati.
    static func text(_ ctx: CGContext, _ s: String, x: CGFloat, y: CGFloat, font name: String = "Helvetica",
                     size: CGFloat = 11, color: CGColor = CGColor(red: 0, green: 0, blue: 0, alpha: 1)) {
        let font = CTFontCreateWithName(name as CFString, size, nil)
        let attr = NSAttributedString(string: s, attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
        ])
        let line = CTLineCreateWithAttributedString(attr)
        ctx.textPosition = CGPoint(x: x, y: y)
        CTLineDraw(line, ctx)
    }

    /// Un documento di prova: un titolo in grassetto e qualche capoverso per pagina.
    static func smallBook(pages: Int = 2) -> URL {
        make(pages: pages) { ctx, p in
            text(ctx, "Capitolo di prova \(p + 1)", x: 72, y: 760, font: "Helvetica-Bold", size: 16)
            var y: CGFloat = 720
            for k in 0..<12 {
                text(ctx, "Questa è la riga \(k + 1) di un capoverso di prova della pagina \(p + 1), scritta per il banco.",
                     x: 72, y: y)
                y -= 16
            }
        }
    }
}

final class EstrattoreSulMacTests: XCTestCase {

    func test_tagliaTrattiEColore_comeSulTelefono() throws {
        let url = SyntheticPDF.make { ctx, _ in
            SyntheticPDF.text(ctx, "Riga nera di prova", x: 72, y: 760)
            SyntheticPDF.text(ctx, "Riga rossa in grassetto", x: 72, y: 730, font: "Helvetica-Bold", size: 14,
                              color: CGColor(red: 1, green: 0, blue: 0, alpha: 1))
            SyntheticPDF.text(ctx, "Riga grigia in corsivo", x: 72, y: 700, font: "Helvetica-Oblique",
                              color: CGColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1))
        }
        defer { try? FileManager.default.removeItem(at: url) }
        let ex = try PdfKitExtractor().extract(fromUri: url.absoluteString)
        XCTAssertEqual(ex.pageCount, 1)
        let lines = ex.pages[0].lines
        XCTAssertEqual(lines.count, 3)
        let first = lines.map { $0.spans.first { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }! }
        XCTAssertEqual(first[0].fontSize, 11, accuracy: 0.01)
        XCTAssertFalse(first[0].bold)
        XCTAssertEqual(first[0].color, "#000000")
        XCTAssertEqual(first[1].fontSize, 14, accuracy: 0.01)
        XCTAssertTrue(first[1].bold)
        // I colori passano dalla conversione nello spazio sRGB (il PDF sintetico li scrive in RGB generico): il rosso
        // resta rosso pieno, il grigio resta grigio neutro. L'uguaglianza esatta con iOS è materia della rete di parità
        // sui 52 volumi (estrazione macOS contro iOS 27), non di un PDF sintetico.
        XCTAssertTrue(first[1].color.hasPrefix("#FF"), first[1].color)
        XCTAssertNotEqual(first[1].color, "#000000")
        XCTAssertTrue(first[2].italic)
        let g = first[2].color
        XCTAssertEqual(g.count, 7)
        XCTAssertEqual(g.dropFirst(1).prefix(2), g.dropFirst(3).prefix(2))
        XCTAssertEqual(g.dropFirst(3).prefix(2), g.dropFirst(5).prefix(2))
        XCTAssertNotEqual(g, "#000000")
        // Coordinate della pagina, origine in basso a sinistra (convenzione del seam).
        XCTAssertGreaterThan(lines[0].bbox.y, lines[1].bbox.y)
    }

    func test_estrazioneAFlusso_chunkPiccoloUgualeAChunkEnorme() throws {
        let url = SyntheticPDF.smallBook(pages: 5)
        defer { try? FileManager.default.removeItem(at: url) }
        let small = try PdfKitExtractor().extract(fromUri: url.absoluteString, onPageExtracted: { _, _ in },
                                                  isCancelled: { false }, chunkPages: 2)
        let big = try PdfKitExtractor().extract(fromUri: url.absoluteString, onPageExtracted: { _, _ in },
                                                isCancelled: { false }, chunkPages: 1000)
        XCTAssertEqual(small, big)
    }
}

/// Un innesto di prova: non tocca nulla e scrive un referto; conta le chiamate.
private final class InnestoDiProva: ChainGraft {
    var calls = 0
    func graft(extraction: PdfExtraction, rawDocument: ScabopdfDocument, pdfURL: URL, sourceName: String,
               onPage: (Int, Int) -> Void, isCancelled: () -> Bool) -> ChainGraftOutput? {
        calls += 1
        onPage(1, 1)
        return ChainGraftOutput(extraction: extraction, rawDocument: rawDocument, report: ["innesto di prova: 0 operazioni"])
    }
}

final class CatenaTests: XCTestCase {

    private func run(_ url: URL, _ options: ChainOptions, cancelled: Bool = false) -> (ChainOutcome, [ChainProgress]) {
        var progress: [ChainProgress] = []
        let out = ProcessingChain.run(fileURL: url, sourceName: "prova.pdf", extractor: PdfKitExtractor(),
                                      options: options, onProgress: { progress.append($0) }, isCancelled: { cancelled })
        return (out, progress)
    }

    func test_opzioniDellIpad_successo_avanzamentoMonotono_nessunInnesto() throws {
        let url = SyntheticPDF.smallBook(pages: 3)
        defer { try? FileManager.default.removeItem(at: url) }
        let (out, progress) = run(url, ChainOptions(detectVisualResources: false))
        guard case .success(let r) = out else { return XCTFail("atteso successo, ottenuto \(out)") }
        XCTAssertFalse(r.content.pages.flatMap { $0.segments }.isEmpty)
        XCTAssertNil(r.graftReport)
        XCTAssertEqual(progress.first?.phase, .opening)
        XCTAssertEqual(progress.last?.fraction, 1.0)
        XCTAssertFalse(progress.contains { $0.phase == .graft })
        for (a, b) in zip(progress, progress.dropFirst()) { XCTAssertLessThanOrEqual(a.fraction, b.fraction) }
    }

    func test_innestoSoloSeRichiesto_frazionamentoComeSulMac() throws {
        let url = SyntheticPDF.smallBook(pages: 2)
        defer { try? FileManager.default.removeItem(at: url) }
        let graft = InnestoDiProva()
        let (plain, _) = run(url, ChainOptions(detectVisualResources: false))
        let (mac, progress) = run(url, ChainOptions(detectVisualResources: false, fractionLongNotes: true, graft: graft))
        guard case .success(let a) = plain, case .success(let b) = mac else { return XCTFail("attesi due successi") }
        XCTAssertEqual(graft.calls, 1)
        XCTAssertEqual(b.graftReport, ["innesto di prova: 0 operazioni"])
        XCTAssertTrue(progress.contains { $0.phase == .graft })
        // Nessuna nota lunga e un innesto che non tocca nulla: la lettura è la stessa.
        XCTAssertEqual(a.content, b.content)
    }

    /// Un documento con una nota lunga: le opzioni dell'iPad la frazionano (decisione del 2026-10-16) con lo STESSO
    /// meccanismo degli atti AKN e del Mac (`fractionLongNoteSegments`, soglia = granularità): primo pezzo NOTE con
    /// l'annuncio e il regime della nota intera, pezzi seguenti NOTE_CONTINUATION muti, testo ricomposto identico. Con il
    /// frazionamento spento (solo per riprodurre la lettura dell'iPad fino alla build 54) la nota resta intera.
    func test_opzioniDellIpad_frazionanoLeNoteLungheComeGliAttiAkn() throws {
        XCTAssertTrue(ChainOptions().fractionLongNotes, "le opzioni predefinite sono quelle dell'iPad: frazionamento acceso")
        let sentences = (1...16).map { "Frase di prova numero \($0) della nota lunga, scritta per il banco della catena." }
        let noteText = "7 " + sentences.joined(separator: " ")
        XCTAssertGreaterThan(noteText.count, DEFAULT_GRANULARITY_TARGET)
        let doc = ScabopdfDocument(
            schema_version: "0.7.0", document_id: "00000000-0000-4000-8000-000000000000",
            metadata: DocumentMetadata(pages_pdf: 1, page_size_pt: [595, 842], source_pdf_filename: "prova.pdf"),
            profile: DocumentProfileDict(profile_id: "unknown_generic", editorial_family: "unknown", genre: "unknown",
                                         confidence: 0),
            structure: [
                NodeDict(id: "node_0", type: .HEADING_1, page_index: 0, text: "Capitolo di prova"),
                NodeDict(id: "node_1", type: .BODY, page_index: 0, text: "Capoverso di prova del corpo."),
                NodeDict(id: "node_2", type: .NOTE, page_index: 0, text: noteText, length_category: .VERY_LONG),
            ])
        let on = try ContinuousBodyBuilder.bodyPaginatedContentWithVisual(from: doc, visual: nil).content
            .pages.flatMap { $0.segments }
        let off = try ContinuousBodyBuilder.bodyPaginatedContentWithVisual(from: doc, visual: nil, fractionLongNotes: false)
            .content.pages.flatMap { $0.segments }
        // Lo stesso meccanismo, non una copia: la catena dà esattamente ciò che dà `fractionLongNoteSegments`.
        XCTAssertEqual(on, fractionLongNoteSegments(off, target: DEFAULT_GRANULARITY_TARGET))
        let pieces = on.filter { $0.role == "NOTE" || $0.role == "NOTE_CONTINUATION" }
        XCTAssertGreaterThan(pieces.count, 1)
        XCTAssertEqual(pieces.first?.role, "NOTE")
        XCTAssertEqual(pieces.first?.id, "node_2#0")
        XCTAssertEqual(pieces.first?.acousticIntro, "Nota lunga.")
        XCTAssertEqual(pieces.first?.lengthCategory, "VERY_LONG")
        XCTAssertTrue(pieces.dropFirst().allSatisfy { $0.role == "NOTE_CONTINUATION" && $0.acousticIntro.isEmpty })
        XCTAssertTrue(pieces.allSatisfy { $0.text.count <= notePieceMaxLength(target: DEFAULT_GRANULARITY_TARGET) })
        XCTAssertEqual(pieces.map { $0.text }.joined(separator: " "), noteText, "il testo ricomposto è la nota di prima")
        XCTAssertEqual(off.filter { $0.role == "NOTE" }.map { $0.text }, [noteText])
        XCTAssertFalse(off.contains { $0.role == "NOTE_CONTINUATION" })
    }

    func test_annullamento_nessunDocumentoParziale() throws {
        let url = SyntheticPDF.smallBook(pages: 2)
        defer { try? FileManager.default.removeItem(at: url) }
        let (out, _) = run(url, ChainOptions(detectVisualResources: false), cancelled: true)
        guard case .cancelled = out else { return XCTFail("atteso annullamento, ottenuto \(out)") }
    }

    func test_pdfIllegibile_prosaNonSoloErrore() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("non-un-pdf-\(UUID().uuidString).pdf")
        try Data("non è un PDF".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let (out, _) = run(url, ChainOptions(detectVisualResources: false))
        guard case .failure(let message) = out else { return XCTFail("atteso fallimento, ottenuto \(out)") }
        XCTAssertTrue(message.contains("PDF"))
        XCTAssertFalse(message.lowercased() == "errore")
    }

    func test_mappaDellePagine_strati_nodoPoiSegmento() {
        let doc = ScabopdfDocument(
            schema_version: "0.7.0", document_id: "doc_prova",
            metadata: DocumentMetadata(pages_pdf: 3, page_size_pt: [595, 842], source_pdf_filename: "prova.pdf"),
            profile: DocumentProfileDict(profile_id: "generic", editorial_family: "generic", genre: "manuale", confidence: 1),
            structure: [NodeDict(id: "node_1", type: .BODY, page_index: 0, text: "uno")])
        let seg = ContentSegment(id: "node_1#1", role: "BODY", text: "uno", lengthCategory: "", acousticIntro: "", sourcePage: 2)
        let content = PaginatedContent(pages: [ContentPage(pageNumber: 1, segments: [seg])], totalSegments: 1)
        let map = ReadingAssembly.buildPageMap(doc, content: content)
        XCTAssertEqual(map["node_1"], 1)
        XCTAssertEqual(map["node_1#1"], 2)
        XCTAssertTrue(ReadingAssembly.isLarge(pageCount: 1501))
        XCTAssertFalse(ReadingAssembly.isLarge(pageCount: 1500))
    }
}
