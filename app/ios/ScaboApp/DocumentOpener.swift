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
//    lo colloca facoltativamente nel contenitore di destinazione, e apre il lettore. PRIMA di
//    elaborare, l'impronta del file (DocumentIdentity.swift) dice se è identico a un libro già in
//    libreria: in quel caso l'app lo dice e propone di aprire quello che c'è già, con le sue
//    annotazioni, oppure di importarlo come copia a parte (DuplicateImport.swift, § 12.8).
//
//  La POSIZIONE di lettura viene ripristinata e ri-registrata leggendo/scrivendo solo
//  `ArchivedDocument.readingPosition`: il motore di lettura (ContinuousReadingView/Builder) è usato
//  in SOLA LETTURA, mai modificato.
//

import UIKit
import UniformTypeIdentifiers
import ScaboChain
import ScaboCore

enum DocumentOpener {

    private static var service: LibraryService { .shared }

    /// Soglia di "volume ENORME" (pagine del PDF): oltre questa, l'apertura è alleggerita per
    /// stare nel budget di memoria del dispositivo. Empirica: il Codice civile (2697 pp, ~7900
    /// articoli, ~47k segmenti di lettura → ~47k UILabel = picco ~865 MB) è l'unico del corpus
    /// sopra soglia; ogni manuale sta sotto 900 pp, l'Estratto 465. Vedi il profiling di memoria.
    static let LARGE_DOCUMENT_PAGE_THRESHOLD = ReadingAssembly.largeDocumentPageThreshold
    /// Granularità di lettura grossa per i volumi enormi (§ 7.6, valore ammesso): meno segmenti
    /// → meno etichette → meno memoria (e meno elementi d'accessibilità per VoiceOver). Rete-A
    /// safe: tutto il testo resta, solo raggruppato in blocchi più grandi.
    static let LARGE_DOCUMENT_GRANULARITY = ReadingAssembly.largeDocumentGranularity

    // MARK: - Apertura di un documento d'archivio (§ 2.5)

    /// L'ancora di apertura a un segnalibro (§ 5.6): l'id del segmento marcato più l'indice di
    /// fallback. Quando presente, il lettore parte da quel punto invece che dalla posizione di
    /// lettura ricordata.
    struct BookmarkFocus {
        let anchorSegmentId: String
        let orderIndexHint: Int
        /// Segnalibro orfano (§ 12.14): non si risolve per id, si apre all'inizio della pagina d'origine.
        var isOrphan: Bool = false
        var originalPage: Int? = nil
    }

    /// Risolve l'ancora di un segnalibro in una posizione (indice di lettura 0-based) nel contenuto:
    /// prima per id esatto del segmento (identità di nodo del Layer 1), poi per id-nodo base (senza
    /// suffisso di granularità `#k`), infine ripiega sull'indice di fallback clampato (§ 2.5,
    /// degradazione ragionevole se il nodo non è nello stream corrente).
    static func resolveAnchorIndex(_ content: PaginatedContent, anchor: BookmarkFocus) -> Int {
        let segments = content.pages.flatMap { $0.segments }
        if anchor.isOrphan {
            if let page = anchor.originalPage, let i = segments.firstIndex(where: { $0.sourcePage == page }) { return i }
            return min(max(0, anchor.orderIndexHint), max(0, segments.count - 1))
        }
        if let i = segments.firstIndex(where: { $0.id == anchor.anchorSegmentId }) { return i }
        let base = baseNodeId(anchor.anchorSegmentId)
        if let i = segments.firstIndex(where: { baseNodeId($0.id) == base }) { return i }
        return min(max(0, anchor.orderIndexHint), max(0, segments.count - 1))
    }

    /// Riancora annotazioni e posizione di un documento sul contenuto appena elaborato (sul thread
    /// chiamante: qui si usa solo quando l'apertura ha dovuto rielaborare, evento raro). Ritorna il
    /// documento aggiornato. Nessuna annotazione → nessun lavoro.
    @discardableResult
    static func reanchorAfterProcessing(documentId: String, content: PaginatedContent) -> ArchivedDocument? {
        // La logica sta in ScaboChain (`LibraryReadings.swift`, dal 2026-11-08), condivisa con l'app Mac.
        service.reanchorAfterProcessing(documentId: documentId, content: content)
    }

    /// Conia le ancore per contenuto MANCANTI delle annotazioni del documento, a contenuto fermo (il
    /// flusso appena presentato è quello su cui gli id correnti sono veri): è la migrazione gratuita
    /// delle annotazioni create prima delle ancore (docs/ANCORE_ANNOTAZIONI.md). Una sola scrittura,
    /// solo se c'è qualcosa da coniare. La logica sta in ScaboChain (`LibraryReadings.swift`).
    static func mintMissingAnchors(documentId: String, in index: ContentAnchorIndex) {
        service.mintMissingAnchors(documentId: documentId, in: index)
    }

    /// L'id-nodo base di un id-segmento, togliendo l'eventuale suffisso di granularità `#k`.
    static func baseNodeId(_ segmentId: String) -> String {
        segmentId.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
            .first.map(String.init) ?? segmentId
    }

    /// Apre il documento `id` al suo punto di lettura. Usa la cache se disponibile, altrimenti
    /// rielabora dal PDF d'archivio. `onClosed` è chiamato quando il lettore viene chiuso (per far
    /// aggiornare i Recenti alla schermata chiamante). `focusAnchor`, se presente, apre a un
    /// segnalibro (§ 5.6) invece che alla posizione ricordata.
    /// `librarySearch`, dal tab Ricerca della Home: appena il lettore compare si apre «Cerca nel libro» con quella ricerca
    /// già fatta (la lista dei risultati del libro), e scegliendo un risultato la lettura va lì con il rotore attivo.
    static func open(
        documentId id: String, from presenter: UIViewController,
        focusAnchor: BookmarkFocus? = nil, librarySearch: (query: String, wholeWord: Bool)? = nil,
        onClosed: (() -> Void)? = nil
    ) {
        guard let doc = service.store.document(id: id) else {
            presentError(LibraryWording.documentNoLongerAvailable, from: presenter)
            return
        }

        // I volumi ENORMI (oltre LARGE_DOCUMENT_PAGE_THRESHOLD pagine: i codici) si aprono ALLEGGERITI
        // (granularità grossa, niente Dottrina Inline né Consultazione Rapida) per stare nel budget di
        // memoria del dispositivo. Usano la cache SOLO se è già quella leggera (`contentTarget` marcato);
        // una cache pesante di build precedenti si rielabora UNA volta, leggera, e da lì in poi si
        // riapre dalla cache come ogni altro libro. Nessun volume si rielabora a ogni apertura. La
        // Lettura Continua — il default — non ha bisogno né dell'albero né del flusso Dottrina.
        let large = doc.sourcePageCount > Self.LARGE_DOCUMENT_PAGE_THRESHOLD

        // Percorso veloce: contenuto in cache → lettore immediato. Per i volumi ENORMI si usa la
        // cache SOLO se è già la versione LEGGERA (granularità grossa, `contentTarget` marcato):
        // una cache pesante a granularità fine (scritta da build precedenti) viene ignorata qui e
        // rielaborata leggera sotto (il suo decode è transitorio e rilasciato subito).
        // Dal giro «prove rifatte e granularità» (2026-11-10) la cache deve anche essere della granularità scelta nelle
        // Impostazioni (LAYER2 § 7.7, la regola condivisa col Mac `requiredCacheGranularity`): un libro letto a un'altra
        // granularità si rielabora qui, una volta, con la schermata d'elaborazione, e le annotazioni si riancorano per contenuto.
        if let cached = service.openableCachedReading(for: doc, requiredTarget: service.requiredCacheGranularity(for: doc)) {
            service.store.recordOpened(id: id)
            presentReader(content: cached.content, document: doc, pageMap: cached.pageMap,
                          doctrineContent: cached.doctrineContent,
                          quickConsultTree: cached.quickConsultTree,
                          focusAnchor: focusAnchor, librarySearch: librarySearch, from: presenter, onClosed: onClosed)
            return
        }

        // Una cache c'è ma non si usa (volume enorme con la cache pesante delle build precedenti): prima di
        // rielaborare, le annotazioni ricevono l'ancora su quel contenuto (fermo, gli id sono veri), così il
        // riancoraggio dopo l'elaborazione le ritrova invece di dichiararle tutte orfane.
        if let stale = service.loadCache(forDocumentId: id) {
            mintMissingAnchors(documentId: id, in: ContentAnchorIndex(segments: stale.content.pages.flatMap { $0.segments }))
        }

        // Percorso di rielaborazione: serve la sorgente d'archivio (PDF o XML AKN). Senza la sorgente non si rielabora: una
        // lettura in cache a un'altra granularità si apre com'è (la regola del Mac), invece di dire che il libro non si apre.
        guard service.hasArchivedSource(forDocumentId: id, kind: doc.sourceKind) else {
            if let existing = service.openableCachedReading(for: doc, requiredTarget: nil) {
                service.store.recordOpened(id: id)
                presentReader(content: existing.content, document: doc, pageMap: existing.pageMap,
                              doctrineContent: existing.doctrineContent, quickConsultTree: existing.quickConsultTree,
                              focusAnchor: focusAnchor, librarySearch: librarySearch, from: presenter, onClosed: onClosed)
            } else {
                presentError(LibraryWording.sourceMissing, from: presenter)
            }
            return
        }

        let isAkn = doc.sourceKind == "akn"
        let target = service.processingGranularity(isAkn: isAkn, large: large)
        let sourceURL = service.archivedSourceURL(forDocumentId: id, kind: doc.sourceKind)
        let processor: DocumentProcessing = isAkn ? AknDocumentProcessor() : DocumentProcessor()
        let processingVC = ProcessingViewController(
            fileURL: sourceURL, sourceName: doc.title, granularityTarget: target,
            buildDoctrine: !large, processor: processor)
        processingVC.onOutcome = { [weak presenter, weak processingVC] outcome in
            let visualSkipped = processingVC?.visualResourcesMissingReason
            if case .success(let document, let content, let doctrineContent) = outcome {
                // Cache SEMPRE, ma per gli enormi è la versione LEGGERA (content a granularità grossa, niente albero né
                // Dottrina, `contentTarget` marcato): la prossima apertura la riconosce e la usa senza rielaborare. Con
                // l'etichetta di generazione. La cache mancava (o era di un'altra granularità): il contenuto è nuovo, le
                // annotazioni si riancorano per contenuto (§ 12.14), mai per id. Dal giro «prove rifatte e granularità»
                // (2026-11-10) i passi pesanti girano fuori dal filo principale (ScaboChain `completeReprocessedOpening`)
                // mentre la schermata d'elaborazione resta su: niente fermo (sul volume più grande fino a 1,2 s), e la Home
                // sotto non si tocca finché il lettore non è pronto.
                service.completeReprocessedOpening(
                    documentId: id, document: document, content: content, doctrineContent: doctrineContent,
                    large: large, target: target, visualResourcesSkipped: visualSkipped) { updated, reading in
                    presenter?.dismiss(animated: true) {
                        guard let presenter else { return }
                        presentReader(content: content, document: updated ?? doc, pageMap: reading.pageMap,
                                      doctrineContent: reading.doctrineContent, quickConsultTree: reading.quickConsultTree,
                                      focusAnchor: focusAnchor, librarySearch: librarySearch, from: presenter, onClosed: onClosed)
                    }
                }
                return
            }
            presenter?.dismiss(animated: true) {
                guard let presenter else { return }
                if case .failure(let message) = outcome { presentError(message, from: presenter) }
            }
        }
        presenter.present(processingVC, animated: Motion.animated())
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
                      doctrineContent: cached.doctrineContent,
                      quickConsultTree: cached.quickConsultTree, from: presenter, onClosed: onClosed)
        return true
    }

    /// Costruisce l'albero della Consultazione Rapida dal documento, o `nil` se non c'è una
    /// gerarchia consultabile (§ 8.8) → il selettore mostrerà il layout disabilitato con motivo.
    static func quickConsultTreeIfAvailable(_ document: ScabopdfDocument) -> [QuickConsultNode]? {
        ReadingAssembly.quickConsultTreeIfAvailable(document)   // spostata in ScaboChain (2026-10-16), invariata
    }

    /// Presenta il lettore al punto di lettura ricordato, cablando la persistenza della posizione,
    /// l'indicatore di pagina (§ 4.3), il flusso Dottrina Inline (§ 10) per il selettore, e la
    /// chiusura. Apre SEMPRE in Lettura Continua (default, § 3.4): l'Estratto e ogni documento
    /// partono identici a prima; Dottrina Inline è una scelta esplicita dal selettore.
    private static func presentReader(
        content: PaginatedContent,
        document doc: ArchivedDocument,
        pageMap: [String: Int],
        doctrineContent: PaginatedContent?,
        quickConsultTree: [QuickConsultNode]?,
        focusAnchor: BookmarkFocus? = nil,
        librarySearch: (query: String, wholeWord: Bool)? = nil,
        from presenter: UIViewController,
        onClosed: (() -> Void)?
    ) {
        // Posizione iniziale: il segnalibro se si apre a uno (§ 5.6), altrimenti il punto ricordato.
        let initialPosition = focusAnchor.map { resolveAnchorIndex(content, anchor: $0) }
            ?? doc.readingPosition
        let anchors = ReaderAnchorBox()
        let reader = ContinuousReadingViewController(
            content: content,
            sourceName: doc.title,
            documentId: doc.id,
            initialReadingPosition: initialPosition,
            onPositionChanged: { index in
                service.store.updateReadingPosition(id: doc.id, position: index, anchor: anchors.anchor(forIndex: index))
            },
            sourcePageCount: doc.sourcePageCount,
            showOriginalPages: getStoredShowOriginalPageNumbers(service.prefs),
            sourcePage: sourcePageProvider(pageMap),
            doctrineContent: doctrineContent,
            quickConsultTree: quickConsultTree,
            anchorBox: anchors)
        reader.onAnchorIndexReady = { index in mintMissingAnchors(documentId: doc.id, in: index) }
        reader.pendingLibrarySearch = librarySearch
        reader.modalPresentationStyle = .fullScreen
        // Posizione ritrovata solo per pagina dopo una rielaborazione (§ 12.14): lo si dice.
        // Senza le pagine del file originale (un testo normativo) si riparte vicino al punto di prima.
        if focusAnchor == nil, doc.readingPositionIsApproximate == true {
            let announcement = LibraryWording.approximatePositionAnnouncement(isAkn: doc.sourceKind == "akn")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                UIAccessibility.post(notification: .announcement, argument: announcement)
            }
        }
        // Split da dentro il file (§ 11.1): il reader si chiude, si sceglie la seconda metà dal
        // presentatore, e lo split parte con QUESTO documento a sinistra. Instradato dal presentatore
        // per unificare l'uscita con l'attivazione dalla Home (il documento che resta si riapre lì).
        reader.onSplitRequested = { [weak presenter] in
            guard let presenter else { return }
            presenter.dismiss(animated: true) {
                DocumentChooserViewController.present(from: presenter) { rightId in
                    SplitScreenViewController.present(
                        leftDocumentId: doc.id, rightDocumentId: rightId, restoring: nil, from: presenter
                    ) { survivorId in
                        presenter.dismiss(animated: true) {
                            DocumentOpener.open(documentId: survivorId, from: presenter, onClosed: onClosed)
                        }
                    }
                }
            }
        }
        reader.onBack = { [weak presenter] in
            // Tornando alla Home/contenitore, l'ultimo-documento-aperto si azzera: un avvio a
            // freddo dalla Home non riaprirà un lettore (§ 2.5, degradazione ragionevole).
            service.store.setLastOpenDocument(id: nil)
            presenter?.dismiss(animated: true) { onClosed?() }
        }
        presentRobustly(reader, from: presenter)
    }

    // MARK: - Metà EMBEDDED per lo split screen (§ 11)

    /// Costruisce una reading view EMBEDDED (§ 11) per un documento, da usare come metà dello split.
    /// Riusa la stessa politica di `open` (cache se disponibile; per i volumi ENORMI granularità
    /// grossa, niente Dottrina/albero; altrimenti rielabora dal PDF d'archivio). `onPositionChanged`
    /// è inoltrato al padre split per la sincronizzazione dei regimi (§ 11.4/§ 11.5). Ritorna `nil`
    /// (via completion) se il documento o il suo PDF non sono disponibili.
    static func loadEmbeddedHalf(
        documentId id: String,
        from presenter: UIViewController,
        onPositionChanged: @escaping (Int) -> Void,
        completion: @escaping (ContinuousReadingViewController?) -> Void
    ) {
        guard let doc = service.store.document(id: id) else { completion(nil); return }
        let large = doc.sourcePageCount > Self.LARGE_DOCUMENT_PAGE_THRESHOLD

        // La stessa regola dell'apertura (dal 2026-11-10): la cache della granularità scelta, altrimenti la rielaborazione,
        // con le ancore coniate prima sul contenuto vecchio e il riancoraggio dopo; senza PDF, la cache com'è.
        if let cached = service.openableCachedReading(for: doc, requiredTarget: service.requiredCacheGranularity(for: doc)) {
            completion(makeEmbeddedReader(
                doc: doc, content: cached.content, pageMap: cached.pageMap,
                doctrine: cached.doctrineContent,
                tree: cached.quickConsultTree, onPositionChanged: onPositionChanged))
            return
        }
        if let stale = service.loadCache(forDocumentId: id) {
            mintMissingAnchors(documentId: id, in: ContentAnchorIndex(segments: stale.content.pages.flatMap { $0.segments }))
        }

        guard service.hasArchivedPDF(forDocumentId: id) else {
            if let existing = service.openableCachedReading(for: doc, requiredTarget: nil) {
                completion(makeEmbeddedReader(
                    doc: doc, content: existing.content, pageMap: existing.pageMap, doctrine: existing.doctrineContent,
                    tree: existing.quickConsultTree, onPositionChanged: onPositionChanged))
            } else {
                completion(nil)
            }
            return
        }
        let target = service.processingGranularity(isAkn: false, large: large)
        let processingVC = ProcessingViewController(
            fileURL: service.archivedPDFURL(forDocumentId: id), sourceName: doc.title,
            granularityTarget: target, buildDoctrine: !large)
        processingVC.onOutcome = { [weak presenter, weak processingVC] outcome in
            let visualSkipped = processingVC?.visualResourcesMissingReason
            guard case .success(let document, let content, let doctrineContent) = outcome else {
                presenter?.dismiss(animated: true) { completion(nil) }
                return
            }
            // I passi pesanti fuori dal filo principale, con la schermata d'elaborazione ancora su (come l'apertura): la cache,
            // poi le annotazioni e la posizione riancorate per contenuto (§ 12.14).
            service.storeProcessedReadingOffMain(
                documentId: id, document: document, content: content, doctrineContent: doctrineContent,
                large: large, target: target, visualResourcesSkipped: visualSkipped) { reading in
                service.reanchorAfterProcessingOffMain(documentId: id, content: content) { updated in
                    presenter?.dismiss(animated: true) {
                        completion(makeEmbeddedReader(
                            doc: updated ?? doc, content: content, pageMap: reading.pageMap,
                            doctrine: reading.doctrineContent, tree: reading.quickConsultTree, onPositionChanged: onPositionChanged))
                    }
                }
            }
        }
        presenter.present(processingVC, animated: Motion.animated())
    }

    /// Costruisce il VC reading in modalità embedded per una metà (§ 11), cablando la persistenza
    /// della posizione (per-documento, § 2.5) e inoltrando il cambio posizione al padre split.
    private static func makeEmbeddedReader(
        doc: ArchivedDocument, content: PaginatedContent, pageMap: [String: Int],
        doctrine: PaginatedContent?, tree: [QuickConsultNode]?,
        onPositionChanged: @escaping (Int) -> Void
    ) -> ContinuousReadingViewController {
        let anchors = ReaderAnchorBox()
        let reader = ContinuousReadingViewController(
            content: content, sourceName: doc.title, documentId: doc.id,
            initialReadingPosition: doc.readingPosition,
            onPositionChanged: { index in
                service.store.updateReadingPosition(id: doc.id, position: index, anchor: anchors.anchor(forIndex: index))
                onPositionChanged(index)
            },
            sourcePageCount: doc.sourcePageCount,
            showOriginalPages: getStoredShowOriginalPageNumbers(service.prefs),
            sourcePage: sourcePageProvider(pageMap),
            doctrineContent: doctrine, quickConsultTree: tree, embedded: true, anchorBox: anchors)
        reader.onAnchorIndexReady = { index in mintMissingAnchors(documentId: doc.id, in: index) }
        service.store.recordOpened(id: doc.id)
        return reader
    }

    /// Presenta il lettore in modo robusto: se il presentatore ha già QUALCOSA di presentato
    /// (uno stato residuo/instabile), lo chiude PRIMA, così il reader non viene mai presentato
    /// sopra uno stato di presentazione corrotto (una delle possibili cause del crash secco
    /// all'apertura). Nessun force-unwrap; se anche il present fallisse, l'app resta sulla Home.
    static func presentRobustly(_ reader: UIViewController, from presenter: UIViewController) {
        if let existing = presenter.presentedViewController {
            existing.dismiss(animated: false) { presenter.present(reader, animated: Motion.animated()) }
        } else {
            presenter.present(reader, animated: Motion.animated())
        }
    }

    // MARK: - Mappa pagine del file originale (§ 4.3)

    /// Costruisce la mappa id-nodo → pagina del file originale (1-based) dall'albero del documento.
    /// `page_index` è 0-based (convenzione PyMuPDF); l'indicatore mostra la pagina 1-based.
    /// La mappa porta DUE strati, e l'ordine conta:
    /// 1. lo strato per NODO (id-nodo → pagina), che copre ogni segmento non affettato;
    /// 2. sopra, lo strato per SEGMENTO costruito dai flussi di lettura già impaginati, che è
    ///    l'unico esatto per le fette `<idNodo>#<k>` di un paragrafo ricucito attraverso il salto
    ///    pagina — quelle fette stanno su pagine diverse dalla testa del paragrafo, e con il solo
    ///    strato per nodo l'indicatore restava indietro di tutte le pagine attraversate.
    static func buildPageMap(
        _ document: ScabopdfDocument,
        content: PaginatedContent? = nil,
        doctrineContent: PaginatedContent? = nil
    ) -> [String: Int] {
        // Spostata in ScaboChain (2026-10-16, giro «costruzione della linea Mac»), invariata: la usa anche il Mac.
        ReadingAssembly.buildPageMap(document, content: content, doctrineContent: doctrineContent)
    }

    /// Risolve la pagina del file originale di un segmento: prima la voce ESATTA del segmento
    /// (strato 2), poi — per le cache costruite prima dello strato per segmento — l'id del nodo
    /// (prima del `#`), che è il comportamento storico.
    private static func sourcePageProvider(_ pageMap: [String: Int]) -> (String) -> Int? {
        { segmentId in
            if let exact = pageMap[segmentId] { return exact }
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

    #if DEBUG
    /// SOLO per i test UI (assente in Release): avvia l'importazione di un file già scelto, senza il
    /// picker di sistema, che XCUI non guida. Stesso flusso di `startImport` da lì in poi.
    static func importFileForUITest(at url: URL, from presenter: UIViewController, onImported: (() -> Void)? = nil) {
        let controller = ImportController(destination: nil, onImported: onImported)
        controller.begin(withPickedFile: url, from: presenter)
    }
    #endif

    // MARK: - Errore in prosa (§ 12.10)

    static func presentError(_ message: String, from presenter: UIViewController) {
        let alert = UIAlertController(title: LibraryWording.errorTitle, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: LibraryWording.errorDismiss, style: .default))
        presenter.present(alert, animated: true)
    }
}

// MARK: - ImportController

/// Coordina il ciclo di vita dell'importazione (il picker è asincrono e richiede un delegate
/// ritenuto). Si auto-trattiene nell'insieme `active` finché il picker è aperto, e si rilascia alla
/// fine — così non serve che il chiamante lo conservi.
private final class ImportController: NSObject, UIDocumentPickerDelegate {

    private static var active = Set<ImportController>()
    /// Vero mentre un'importazione sta controllando l'impronta del file scelto (prima dell'elaborazione o della schermata
    /// «Libro già presente»): un secondo tocco su + in quell'istante non apre un secondo flusso (rilievo della revisione).
    private static var identityCheckInProgress = false

    private let destination: ContainerRef?
    private let onImported: (() -> Void)?
    private weak var presenter: UIViewController?

    init(destination: ContainerRef?, onImported: (() -> Void)?) {
        self.destination = destination
        self.onImported = onImported
    }

    func begin(from presenter: UIViewController) {
        guard !Self.identityCheckInProgress else { return }
        self.presenter = presenter
        Self.active.insert(self)
        // PDF + AKN (XML di Normattiva). L'import non-PDF è la piattaforma XML/EPUB (§12.8): qui si
        // aggiunge l'XML AKN accanto al PDF; l'EPUB è un passo successivo.
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf, .xml], asCopy: true)
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

    #if DEBUG
    /// Come `begin` + scelta del file, ma con un file già dato (test UI).
    func begin(withPickedFile url: URL, from presenter: UIViewController) {
        guard !Self.identityCheckInProgress else { return }
        self.presenter = presenter
        Self.active.insert(self)
        startProcessing(originalURL: url, presenter: presenter)
    }
    #endif

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        finish()
    }

    private func startProcessing(originalURL: URL, presenter: UIViewController) {
        // Dispatch sul formato: XML AKN → orchestratore AKN; altrimenti PDF (invariato).
        let isAkn = originalURL.pathExtension.lowercased() == "xml"
        guard let localCopy = LibraryService.copyIntoTemporary(originalURL, ext: isAkn ? "xml" : "pdf") else {
            DocumentOpener.presentError(LibraryWording.unreadablePickedFile, from: presenter)
            finish()
            return
        }
        let sourceName = originalURL.lastPathComponent

        // LIBRO GIÀ PRESENTE (§ 12.8): l'impronta del file, prima di elaborare. Un file identico a un
        // libro in libreria non si rielabora in silenzio come copia nuova: l'app lo dice e propone di
        // aprire quello che c'è già (scelta predefinita), o di importarlo come copia a parte.
        Self.identityCheckInProgress = true
        DocumentIdentity.existingDocuments(matchingFileAt: localCopy) { [weak self, weak presenter] sha256, matches in
            Self.identityCheckInProgress = false
            guard let self, let presenter else {
                try? FileManager.default.removeItem(at: localCopy); self?.finish(); return
            }
            guard let existing = matches.first else {
                self.process(localCopy: localCopy, sourceName: sourceName, isAkn: isAkn, sha256: sha256, presenter: presenter)
                return
            }
            let onImported = self.onImported
            let destination = self.destination
            DuplicateImportViewController.present(existing: existing, copies: matches.count, from: presenter) { [weak self, weak presenter] choice in
                guard let self, let presenter else {
                    try? FileManager.default.removeItem(at: localCopy); self?.finish(); return
                }
                switch choice {
                case .openExisting:
                    try? FileManager.default.removeItem(at: localCopy)
                    self.finish()
                    // Importando da dentro un contenitore, il libro che c'è già viene collocato anche lì (una collocazione
                    // in più, mai un duplicato: § 12.6), come avrebbe fatto l'importazione.
                    if let destination { LibraryService.shared.store.addCollocation(documentId: existing.id, to: destination) }
                    DocumentOpener.open(documentId: existing.id, from: presenter, onClosed: onImported)
                case .importAsCopy:
                    self.process(localCopy: localCopy, sourceName: sourceName, isAkn: isAkn, sha256: sha256, presenter: presenter)
                case .cancel:
                    try? FileManager.default.removeItem(at: localCopy)
                    self.finish()
                }
            }
        }
    }

    /// L'elaborazione nella schermata dedicata (§ 12.9), poi la registrazione (`handleOutcome`).
    private func process(localCopy: URL, sourceName: String, isAkn: Bool, sha256: String?, presenter: UIViewController) {
        let processor: DocumentProcessing = isAkn ? AknDocumentProcessor() : DocumentProcessor()
        // La granularità scelta nelle Impostazioni (dal 2026-11-10, la regola condivisa col Mac); prima dell'elaborazione le
        // pagine non si conoscono: un volume enorme non va in cache qui e alla prima apertura si prepara leggero.
        let target = LibraryService.shared.processingGranularity(isAkn: isAkn, large: false)
        let processingVC = ProcessingViewController(
            fileURL: localCopy, sourceName: sourceName, granularityTarget: target, processor: processor)
        processingVC.onOutcome = { [weak self, weak presenter, weak processingVC] outcome in
            let visualSkipped = processingVC?.visualResourcesMissingReason
            // La copia temporanea è la sorgente dell'archiviazione (§12.6): si rimuove DOPO che la registrazione l'ha copiata in
            // archivio, non prima. Dal giro «prove rifatte e granularità» (2026-11-10) la registrazione fa i suoi passi pesanti
            // fuori dal filo principale, con la schermata d'elaborazione ancora su (`handleOutcome`).
            guard let self else { try? FileManager.default.removeItem(at: localCopy); return }
            self.handleOutcome(
                outcome, sourceName: sourceName, localCopy: localCopy, isAkn: isAkn, sha256: sha256, presenter: presenter,
                visualSkipped: visualSkipped, contentTarget: target)
        }
        presenter.present(processingVC, animated: Motion.animated())
    }

    private func handleOutcome(
        _ outcome: DocumentProcessor.Outcome,
        sourceName: String,
        localCopy: URL,
        isAkn: Bool,
        sha256: String?,
        presenter: UIViewController?,
        visualSkipped: String? = nil,
        contentTarget: Int = DEFAULT_GRANULARITY_TARGET
    ) {
        guard case .success(let document, let content, let doctrineContent) = outcome else {
            presenter?.dismiss(animated: true) { [weak self, weak presenter] in
                try? FileManager.default.removeItem(at: localCopy)
                if case .failure(let message) = outcome, let presenter { DocumentOpener.presentError(message, from: presenter) }
                self?.finish()
            }
            return
        }
        // La registrazione (libro, sorgente d'archivio, impronta, mappa delle pagine, cache, generazione, collocazione,
        // apertura) è la logica condivisa con l'app Mac: ScaboChain `LibraryReadings.swift`, con i passi pesanti fuori dal
        // filo principale (dal 2026-11-10; stesso risultato della versione sincrona).
        LibraryService.shared.registerImportedOffMain(
            document: document, content: content, doctrineContent: doctrineContent,
            sourceName: sourceName, localCopy: localCopy, isAkn: isAkn, sha256: sha256,
            visualResourcesSkipped: visualSkipped, destination: destination, contentTarget: contentTarget) { [weak self, weak presenter] registered in
            try? FileManager.default.removeItem(at: localCopy)
            self?.onImported?()
            presenter?.dismiss(animated: true) { [weak self, weak presenter] in
                // Apertura automatica del lettore sul documento appena importato (al primo elemento).
                if let presenter {
                    DocumentOpener.presentReaderAfterImport(
                        content: content, document: registered.document, pageMap: registered.pageMap,
                        doctrineContent: registered.isLarge ? nil : doctrineContent, quickConsultTree: registered.quickConsultTree,
                        from: presenter, onImported: self?.onImported)
                }
                self?.finish()
            }
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
        doctrineContent: PaginatedContent?,
        quickConsultTree: [QuickConsultNode]?,
        from presenter: UIViewController,
        onImported: (() -> Void)?
    ) {
        let anchors = ReaderAnchorBox()
        let reader = ContinuousReadingViewController(
            content: content,
            sourceName: doc.title,
            documentId: doc.id,
            initialReadingPosition: doc.readingPosition,
            onPositionChanged: { index in
                service.store.updateReadingPosition(id: doc.id, position: index, anchor: anchors.anchor(forIndex: index))
            },
            sourcePageCount: doc.sourcePageCount,
            showOriginalPages: getStoredShowOriginalPageNumbers(service.prefs),
            sourcePage: sourcePageProvider(pageMap),
            doctrineContent: doctrineContent,
            quickConsultTree: quickConsultTree,
            anchorBox: anchors)
        reader.onAnchorIndexReady = { index in mintMissingAnchors(documentId: doc.id, in: index) }
        reader.modalPresentationStyle = .fullScreen
        reader.onBack = { [weak presenter] in
            service.store.setLastOpenDocument(id: nil)
            presenter?.dismiss(animated: true) { onImported?() }
        }
        presentRobustly(reader, from: presenter)
    }
}
