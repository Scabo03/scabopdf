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
