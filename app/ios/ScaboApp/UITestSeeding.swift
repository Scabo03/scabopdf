//
//  UITestSeeding.swift
//  ScaboApp
//
//  Semi per gli UI-test, SOLO in DEBUG (assenti da Release/TestFlight). `-uiTestSeedReprocess` crea un
//  libro sintetico (PDF generato qui, testo neutro, nessun volume) etichettato come elaborato da una
//  build vecchia, con un segnalibro creato prima delle ancore: è il caso che l'offerta di
//  rielaborazione deve trattare (il segnalibro senza ancora diventa «da ricollocare», dichiarato).
//  `-uiTestSeedDuplicateImport` crea lo stesso libro sintetico già in libreria (con impronta, cache e
//  un segnalibro) e lascia in `tmp` una copia identica del suo PDF: la Home la «importa» al primo
//  apparire, così il test UI percorre la schermata «Libro già presente» (DuplicateImport.swift).
//  `-uiTestSeedVisualResource` crea un libro con una tabella già riconosciuta come risorsa visiva (giro 2026-10-12);
//  `-uiTestSeedVisualResourceControl` crea lo stesso libro SENZA l'elemento «risorsa visiva» (stesso titolo, stessi
//  paragrafi): il termine di paragone dell'audit di accessibilità.
//

#if DEBUG
import UIKit
import ScaboCore

enum UITestSeeding {
    /// Il file che la Home «importa» nel seme del libro già presente.
    static let duplicateImportFileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("Libro di prova.pdf")   // stesso nome del libro: la copia prende lo stesso titolo

    static func applyIfRequested() {
        let args = CommandLine.arguments
        if args.contains("-uiTestSeedDuplicateImport") { seedDuplicateImport(); return }
        if args.contains("-uiTestSeedVisualResourceControl") { seedVisualResource(withResource: false); return }
        if args.contains("-uiTestSeedVisualResource") { seedVisualResource(withResource: true); return }
        guard args.contains("-uiTestSeedReprocess") else { return }
        let service = LibraryService.shared
        // Libreria pulita per un test deterministico.
        for d in service.store.allDocuments() {
            service.store.deleteDocumentFromArchive(id: d.id)
            service.deleteFiles(forDocumentId: d.id)
        }
        let doc = service.store.addDocument(title: "Libro di prova", sourceFileName: "libro-di-prova.pdf", sourcePageCount: 3)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("libro-di-prova.pdf")
        try? syntheticPdf().write(to: url)
        try? service.storePDF(from: url, forDocumentId: doc.id)
        service.store.recordProcessed(id: doc.id, systemVersion: SystemGeneration.current, appBuild: "40")
        let tag = service.store.tags().first { $0.name == "Importante" } ?? service.store.createTag(name: "Importante")
        service.store.addBookmark(documentId: doc.id, anchorSegmentId: "node_3", orderIndexHint: 3,
                                  name: "Segnalibro di prova", preview: "Segnalibro di prova", originalPage: 2,
                                  tagIds: tag.map { [$0.id] } ?? [])
        service.store.recordOpened(id: doc.id)
    }

    /// Un libro già in libreria (impronta calcolata, cache scritta, un segnalibro, elaborato da QUESTA
    /// build: nessuna offerta di rielaborazione), più una copia identica del PDF da importare.
    private static func seedDuplicateImport() {
        let service = LibraryService.shared
        for d in service.store.allDocuments() {
            service.store.deleteDocumentFromArchive(id: d.id)
            service.deleteFiles(forDocumentId: d.id)
        }
        let pdf = syntheticPdf()
        let doc = service.store.addDocument(title: "Libro di prova", sourceFileName: "libro-di-prova.pdf", sourcePageCount: 3)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("libro-di-prova.pdf")
        try? pdf.write(to: url)
        try? service.storePDF(from: url, forDocumentId: doc.id)
        if let sha = DocumentIdentity.fingerprintOfArchivedSource(doc, service: service) {
            service.store.setSourceSha256(id: doc.id, sha)
        }
        // Una cache minima: aprire «il libro che hai già» non passa dall'elaborazione.
        let segments = (0..<3).map { i in
            ContentSegment(id: "node_\(i)", role: "BODY", text: "Paragrafo \(i + 1) del libro di prova, già in libreria.",
                           lengthCategory: "", acousticIntro: "", sourcePage: i + 1)
        }
        service.writeCache(PaginatedContent(pages: [ContentPage(pageNumber: 1, segments: segments)], totalSegments: 3),
                           pageMap: [:], doctrineContent: nil, quickConsultTree: nil,
                           contentTarget: DEFAULT_GRANULARITY_TARGET, forDocumentId: doc.id)
        service.store.recordProcessed(id: doc.id, systemVersion: SystemGeneration.current, appBuild: SystemGeneration.appBuild)
        let tag = service.store.tags().first { $0.name == "Importante" } ?? service.store.createTag(name: "Importante")
        service.store.addBookmark(documentId: doc.id, anchorSegmentId: "node_1", orderIndexHint: 1,
                                  name: "Segnalibro di prova", preview: "Segnalibro di prova", originalPage: 2,
                                  tagIds: tag.map { [$0.id] } ?? [])
        service.store.recordOpened(id: doc.id)
        try? FileManager.default.removeItem(at: duplicateImportFileURL)
        try? pdf.write(to: duplicateImportFileURL)
    }

    /// Un libro con una TABELLA già riconosciuta (giro risorse visive, 2026-10-12): PDF sintetico con una tabella
    /// disegnata (filetti e parole neutre) e una cache il cui flusso porta l'elemento «risorsa visiva» seguito dal testo
    /// della tabella, come lo produce l'elaborazione. Elaborato da QUESTA build: nessuna offerta di rielaborazione.
    /// Con `withResource == false` il flusso è lo stesso senza l'elemento «risorsa visiva» (controllo dell'audit).
    private static func seedVisualResource(withResource: Bool) {
        let service = LibraryService.shared
        for d in service.store.allDocuments() {
            service.store.deleteDocumentFromArchive(id: d.id)
            service.deleteFiles(forDocumentId: d.id)
        }
        let doc = service.store.addDocument(title: "Libro con tabella", sourceFileName: "libro-con-tabella.pdf", sourcePageCount: 1)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("libro-con-tabella.pdf")
        try? syntheticPdfWithTable().write(to: url)
        try? service.storePDF(from: url, forDocumentId: doc.id)
        let page = 1
        func seg(_ id: String, _ role: String, _ text: String) -> ContentSegment {
            ContentSegment(id: id, role: role, text: text, lengthCategory: "", acousticIntro: "", sourcePage: page)
        }
        let table = ContentSegment(
            id: "vr_p0_0", role: VISUAL_RESOURCE_ROLE, text: "Tabella: Il raccolto per stagione", lengthCategory: "",
            acousticIntro: acousticIntroFor(VISUAL_RESOURCE_ROLE, ""), memoryRefresh: "", sourcePage: page,
            visualResource: VisualResourcePayload(kind: .table, pageIndex: 0, bbox: [60, 200, 360, 320], containedElements: 2))
        let segments = [
            seg("node_0", "HEADING_1", "Capitolo primo"),
            seg("node_1", "BODY", "Il paragrafo che precede la tabella del raccolto."),
        ] + (withResource ? [table] : []) + [
            seg("node_2", "BODY", "Stagione Raccolto Primavera Grano"),
            seg("node_3", "BODY", "Estate Orzo Autunno Uva"),
            seg("node_4", "BODY", "Il paragrafo che segue la tabella."),
        ]
        service.writeCache(PaginatedContent(pages: [ContentPage(pageNumber: 1, segments: segments)], totalSegments: segments.count),
                           pageMap: [:], doctrineContent: nil, quickConsultTree: nil,
                           contentTarget: DEFAULT_GRANULARITY_TARGET, forDocumentId: doc.id)
        service.store.recordProcessed(id: doc.id, systemVersion: SystemGeneration.current, appBuild: SystemGeneration.appBuild)
        service.store.recordOpened(id: doc.id)
    }

    private static func syntheticPdfWithTable() -> Data {
        UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 420, height: 595)).pdfData { ctx in
            ctx.beginPage()
            let font = UIFont.systemFont(ofSize: 12)
            ("Capitolo primo" as NSString).draw(at: CGPoint(x: 60, y: 70), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 16)])
            ("Il paragrafo che precede la tabella del raccolto." as NSString).draw(at: CGPoint(x: 60, y: 120), withAttributes: [.font: font])
            let cg = ctx.cgContext
            cg.setStrokeColor(UIColor.black.cgColor); cg.setLineWidth(1)
            for r in 0...3 { cg.move(to: CGPoint(x: 60, y: 200 + r * 40)); cg.addLine(to: CGPoint(x: 360, y: 200 + r * 40)) }
            for c in 0...2 { cg.move(to: CGPoint(x: 60 + c * 150, y: 200)); cg.addLine(to: CGPoint(x: 60 + c * 150, y: 320)) }
            cg.strokePath()
            for (i, w) in ["Stagione", "Raccolto", "Primavera", "Grano", "Estate", "Orzo"].enumerated() {
                (w as NSString).draw(at: CGPoint(x: 70 + (i % 2) * 150, y: 212 + (i / 2) * 40), withAttributes: [.font: font])
            }
            ("Il paragrafo che segue la tabella." as NSString).draw(at: CGPoint(x: 60, y: 360), withAttributes: [.font: font])
        }
    }

    private static func syntheticPdf() -> Data {
        let page = CGRect(x: 0, y: 0, width: 420, height: 595)
        let paragraphs = [
            "Il primo capitolo racconta della brezza che scende dalla collina verso il lago al tramonto.",
            "Il secondo paragrafo parla del faro acceso sulla scogliera e del vento che piega gli ulivi.",
            "Il terzo paragrafo descrive il mulino sul fiume e le chiuse aperte di notte per il grano.",
            "Il quarto paragrafo chiude la pagina con la neve sui tetti e il silenzio della valle.",
        ]
        return UIGraphicsPDFRenderer(bounds: page).pdfData { ctx in
            for p in 0..<3 {
                ctx.beginPage()
                var y: CGFloat = 60
                for text in paragraphs {
                    let s = "\(text) Pagina \(p + 1)."
                    (s as NSString).draw(in: CGRect(x: 40, y: y, width: 340, height: 80),
                                         withAttributes: [.font: UIFont.systemFont(ofSize: 12)])
                    y += 90
                }
            }
        }
    }
}
#endif
