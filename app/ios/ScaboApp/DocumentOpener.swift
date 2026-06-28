//
//  DocumentOpener.swift
//  ScaboApp
//
//  L'orchestrazione di APERTURA e IMPORTAZIONE di un documento, condivisa da Home, contenitori e
//  Ricerca. Tiene insieme il flusso utente attorno al motore di lettura esistente senza toccarlo:
//
//  • APERTURA (`open`): dato l'id di un documento d'archivio, lo apre AL PUNTO DI LETTURA dove era
//    stato chiuso (§ 2.5). Prima prova la cache del contenuto (riapertura immediata); se manca,
//    rielabora il PDF d'archivio con la stessa finestra di elaborazione bloccante dell'import
//    (§ 12.9), poi scrive la cache. In entrambi i casi registra l'apertura (→ Recenti, → ultimo
//    documento aperto) e ripristina la posizione.
//
//  • IMPORTAZIONE (`startImport`): il tasto + (§ 12.8). Sceglie un PDF col picker di sistema, lo
//    elabora, lo registra nell'archivio (con il referto dei warning, § 12.10), ne scrive la cache,
//    lo colloca facoltativamente nel contenitore di destinazione, e apre il lettore.
//
//  La POSIZIONE di lettura viene ripristinata e ri-registrata leggendo/scrivendo solo
//  `ArchivedDocument.readingPosition`: il motore di lettura (ContinuousReadingView/Builder) è usato
//  in SOLA LETTURA, mai modificato.
//

import UIKit
import UniformTypeIdentifiers
import ScaboCore

enum DocumentOpener {

    private static var service: LibraryService { .shared }

    // MARK: - Apertura di un documento d'archivio (§ 2.5)

    /// Apre il documento `id` al suo punto di lettura. Usa la cache se disponibile, altrimenti
    /// rielabora dal PDF d'archivio. `onClosed` è chiamato quando il lettore viene chiuso (per far
    /// aggiornare i Recenti alla schermata chiamante).
    static func open(documentId id: String, from presenter: UIViewController, onClosed: (() -> Void)? = nil) {
        guard let doc = service.store.document(id: id) else {
            presentError("Il documento non è più disponibile.", from: presenter)
            return
        }

        // Percorso veloce: contenuto in cache → lettore immediato al punto di lettura.
        if let cached = service.loadCache(forDocumentId: id) {
            service.store.recordOpened(id: id)
            presentReader(content: cached.content, document: doc, pageMap: cached.pageMap,
                          from: presenter, onClosed: onClosed)
            return
        }

        // Percorso di rielaborazione: serve il PDF d'archivio.
        guard service.hasArchivedPDF(forDocumentId: id) else {
            presentError(
                "Il file di origine di questo documento non è più disponibile sul dispositivo, "
                + "quindi non può essere riaperto. Reimportalo per leggerlo di nuovo.",
                from: presenter)
            return
        }

        let pdfURL = service.archivedPDFURL(forDocumentId: id)
        let processingVC = ProcessingViewController(fileURL: pdfURL, sourceName: doc.title)
        processingVC.onOutcome = { [weak presenter] outcome in
            presenter?.dismiss(animated: true) {
                guard let presenter else { return }
                switch outcome {
                case .success(let document, let content):
                    let pageMap = buildPageMap(document)
                    service.writeCache(content, pageMap: pageMap, forDocumentId: id)
                    service.store.recordOpened(id: id)
                    presentReader(content: content, document: doc, pageMap: pageMap,
                                  from: presenter, onClosed: onClosed)
                case .cancelled:
                    break
                case .failure(let message):
                    presentError(message, from: presenter)
                }
            }
        }
        presenter.present(processingVC, animated: true)
    }

    /// Riapertura all'AVVIO (§ 2.5): apre l'ultimo documento SOLO se il contenuto è in cache, così
    /// un avvio a freddo non scatena una rielaborazione lunga. Restituisce `false` se non possibile
    /// (allora l'app resta sulla Home — degradazione ragionevole). `onClosed` aggiorna la Home.
    @discardableResult
    static func reopenFromCache(documentId id: String, from presenter: UIViewController, onClosed: (() -> Void)? = nil) -> Bool {
        guard let doc = service.store.document(id: id),
              let cached = service.loadCache(forDocumentId: id) else {
            return false
        }
        service.store.recordOpened(id: id)
        presentReader(content: cached.content, document: doc, pageMap: cached.pageMap,
                      from: presenter, onClosed: onClosed)
        return true
    }

    /// Presenta il lettore Lettura Continua al punto di lettura ricordato, cablando la persistenza
    /// della posizione, l'indicatore di pagina (§ 4.3) e la chiusura.
    private static func presentReader(
        content: PaginatedContent,
        document doc: ArchivedDocument,
        pageMap: [String: Int],
        from presenter: UIViewController,
        onClosed: (() -> Void)?
    ) {
        let reader = ContinuousReadingViewController(
            content: content,
            sourceName: doc.title,
            documentId: doc.id,
            initialReadingPosition: doc.readingPosition,
            onPositionChanged: { index in
                service.store.updateReadingPosition(id: doc.id, position: index)
            },
            sourcePageCount: doc.sourcePageCount,
            showOriginalPages: getStoredShowOriginalPageNumbers(service.prefs),
            sourcePage: sourcePageProvider(pageMap))
        reader.modalPresentationStyle = .fullScreen
        reader.onBack = { [weak presenter] in
            // Tornando alla Home/contenitore, l'ultimo-documento-aperto si azzera: un avvio a
            // freddo dalla Home non riaprirà un lettore (§ 2.5, degradazione ragionevole).
            service.store.setLastOpenDocument(id: nil)
            presenter?.dismiss(animated: true) { onClosed?() }
        }
        presenter.present(reader, animated: true)
    }

    // MARK: - Mappa pagine del file originale (§ 4.3)

    /// Costruisce la mappa id-nodo → pagina del file originale (1-based) dall'albero del documento.
    /// `page_index` è 0-based (convenzione PyMuPDF); l'indicatore mostra la pagina 1-based.
    static func buildPageMap(_ document: ScabopdfDocument) -> [String: Int] {
        var map: [String: Int] = [:]
        func walk(_ nodes: [NodeDict]) {
            for node in nodes {
                map[node.id] = node.page_index + 1
                if !node.children.isEmpty { walk(node.children) }
            }
        }
        walk(document.structure)
        return map
    }

    /// Risolve la pagina del file originale di un segmento. I segmenti granularizzati portano un id
    /// `<idNodo>#<k>`: si risale all'id del nodo (prima del `#`) per la lookup nella mappa.
    private static func sourcePageProvider(_ pageMap: [String: Int]) -> (String) -> Int? {
        { segmentId in
            let base = segmentId.split(separator: "#", maxSplits: 1,
                                       omittingEmptySubsequences: false).first.map(String.init) ?? segmentId
            return pageMap[base]
        }
    }

    // MARK: - Importazione (§ 12.8)

    /// Avvia l'importazione di un PDF dal picker di sistema. `into` è il contenitore di destinazione
    /// (collocazione automatica, § 12.8) oppure `nil` per atterrare "non collocato". `onImported`
    /// notifica la schermata chiamante per aggiornare la lista.
    static func startImport(
        from presenter: UIViewController,
        into destination: ContainerRef? = nil,
        onImported: (() -> Void)? = nil
    ) {
        let controller = ImportController(destination: destination, onImported: onImported)
        controller.begin(from: presenter)
    }

    // MARK: - Errore in prosa (§ 12.10)

    static func presentError(_ message: String, from presenter: UIViewController) {
        let alert = UIAlertController(title: "Operazione non riuscita", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ho capito", style: .default))
        presenter.present(alert, animated: true)
    }
}

// MARK: - ImportController

/// Coordina il ciclo di vita dell'importazione (il picker è asincrono e richiede un delegate
/// ritenuto). Si auto-trattiene nell'insieme `active` finché il picker è aperto, e si rilascia alla
/// fine — così non serve che il chiamante lo conservi.
private final class ImportController: NSObject, UIDocumentPickerDelegate {

    private static var active = Set<ImportController>()

    private let destination: ContainerRef?
    private let onImported: (() -> Void)?
    private weak var presenter: UIViewController?

    init(destination: ContainerRef?, onImported: (() -> Void)?) {
        self.destination = destination
        self.onImported = onImported
    }

    func begin(from presenter: UIViewController) {
        self.presenter = presenter
        Self.active.insert(self)
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf], asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        presenter.present(picker, animated: true)
    }

    private func finish() {
        Self.active.remove(self)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first, let presenter else { finish(); return }
        startProcessing(originalURL: url, presenter: presenter)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        finish()
    }

    private func startProcessing(originalURL: URL, presenter: UIViewController) {
        guard let localCopy = copyIntoTemporary(originalURL) else {
            DocumentOpener.presentError(
                "Non è stato possibile leggere il file scelto. Riprova selezionandolo di nuovo.",
                from: presenter)
            finish()
            return
        }
        let sourceName = originalURL.lastPathComponent

        let processingVC = ProcessingViewController(fileURL: localCopy, sourceName: sourceName)
        processingVC.onOutcome = { [weak self, weak presenter] outcome in
            presenter?.dismiss(animated: true) {
                try? FileManager.default.removeItem(at: localCopy)
                guard let self, let presenter else { self?.finish(); return }
                self.handleOutcome(outcome, sourceName: sourceName, localCopy: localCopy, presenter: presenter)
            }
        }
        presenter.present(processingVC, animated: true)
    }

    private func handleOutcome(
        _ outcome: DocumentProcessor.Outcome,
        sourceName: String,
        localCopy: URL,
        presenter: UIViewController
    ) {
        let service = LibraryService.shared
        switch outcome {
        case .success(let document, let content):
            // Il titolo di default è il nome del file senza estensione (modificabile poi).
            let title = (sourceName as NSString).deletingPathExtension
            let doc = service.store.addDocument(
                title: title.isEmpty ? sourceName : title,
                sourceFileName: sourceName,
                sourcePageCount: document.metadata.pages_pdf,
                warnings: document.warnings)
            // Archivia il PDF (sorgente di verità) e la cache del contenuto.
            do {
                try service.storePDF(from: localCopy, forDocumentId: doc.id)
            } catch {
                // L'archiviazione del PDF è fallita: il documento resta comunque apribile ora dalla
                // cache, ma non rielaborabile in futuro. Si avvisa in prosa senza bloccare la lettura.
                service.store.renameDocument(id: doc.id, to: doc.title)  // no-op, mantiene il record
            }
            let pageMap = DocumentOpener.buildPageMap(document)
            service.writeCache(content, pageMap: pageMap, forDocumentId: doc.id)
            if let destination { service.store.addCollocation(documentId: doc.id, to: destination) }
            service.store.recordOpened(id: doc.id)
            onImported?()
            // Apertura automatica del lettore sul documento appena importato (al primo elemento).
            DocumentOpener.presentReaderAfterImport(
                content: content, document: doc, pageMap: pageMap, from: presenter, onImported: onImported)
        case .cancelled:
            break
        case .failure(let message):
            DocumentOpener.presentError(message, from: presenter)
        }
        finish()
    }

    private func copyIntoTemporary(_ source: URL) -> URL? {
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("scabo_import_\(UUID().uuidString).pdf")
        do {
            try FileManager.default.copyItem(at: source, to: destination)
            return destination
        } catch {
            return nil
        }
    }
}

// MARK: - Apertura post-import

extension DocumentOpener {
    /// Apre il lettore subito dopo un import riuscito (al primo elemento), cablando la persistenza
    /// della posizione e l'aggiornamento della schermata chiamante alla chiusura.
    fileprivate static func presentReaderAfterImport(
        content: PaginatedContent,
        document doc: ArchivedDocument,
        pageMap: [String: Int],
        from presenter: UIViewController,
        onImported: (() -> Void)?
    ) {
        let reader = ContinuousReadingViewController(
            content: content,
            sourceName: doc.title,
            documentId: doc.id,
            initialReadingPosition: doc.readingPosition,
            onPositionChanged: { index in
                service.store.updateReadingPosition(id: doc.id, position: index)
            },
            sourcePageCount: doc.sourcePageCount,
            showOriginalPages: getStoredShowOriginalPageNumbers(service.prefs),
            sourcePage: sourcePageProvider(pageMap))
        reader.modalPresentationStyle = .fullScreen
        reader.onBack = { [weak presenter] in
            service.store.setLastOpenDocument(id: nil)
            presenter?.dismiss(animated: true) { onImported?() }
        }
        presenter.present(reader, animated: true)
    }
}
