//
//  LibraryReadings.swift
//  ScaboChain
//
//  Le LETTURE DELLA LIBRERIA fra elaborazione e presentazione, una logica sola per l'iPad e per il Mac (giro «app unica per
//  Mac, tappa A», 2026-11-08). Fino a quel giro questi passi stavano dentro ScaboApp `DocumentOpener.swift`, mescolati alla
//  presentazione UIKit; qui sono spostati SENZA cambiarne l'ordine né le regole, perché l'app Mac (ScaboPDF per Mac) importi,
//  registri e riapra i libri esattamente come l'iPad (LAYER2 § 12.16, decisione 10):
//
//  • la REGISTRAZIONE dopo un'importazione riuscita (§ 12.8): il libro nella libreria, la sorgente nell'archivio, l'impronta
//    del contenuto, la mappa delle pagine, l'albero della Consultazione Rapida, la cache (non per i volumi enormi, che si
//    rielaborano leggeri alla prima riapertura), l'etichetta di generazione, la collocazione facoltativa, l'apertura;
//  • la scelta della CACHE da usare all'apertura (per un volume enorme solo la versione leggera);
//  • la SCRITTURA della lettura dopo una rielaborazione all'apertura, con l'etichetta di generazione;
//  • il RIANCORAGGIO delle annotazioni per contenuto (§ 12.14) e il conio delle ancore mancanti.
//
//  Solo Foundation e ScaboCore: la presentazione resta nelle app.
//

import Foundation
import ScaboCore

/// Una lettura pronta da presentare: il flusso della Lettura Continua, la mappa delle pagine del file originale e, se ci
/// sono, il flusso della Dottrina Inline e l'albero della Consultazione Rapida (mai per i volumi enormi).
public struct LibraryReading {
    public let content: PaginatedContent
    public let pageMap: [String: Int]
    public let doctrineContent: PaginatedContent?
    public let quickConsultTree: [QuickConsultNode]?

    public init(content: PaginatedContent, pageMap: [String: Int], doctrineContent: PaginatedContent?,
                quickConsultTree: [QuickConsultNode]?) {
        self.content = content; self.pageMap = pageMap; self.doctrineContent = doctrineContent
        self.quickConsultTree = quickConsultTree
    }
}

/// L'esito della registrazione di un'importazione riuscita.
public struct RegisteredImport {
    /// Il libro come la libreria l'ha appena creato (lo stesso valore che l'iPad passa al lettore subito dopo).
    public let document: ArchivedDocument
    public let pageMap: [String: Int]
    public let quickConsultTree: [QuickConsultNode]?
    /// Volume enorme (oltre `ReadingAssembly.largeDocumentPageThreshold` pagine): non messo in cache all'importazione,
    /// niente albero né Dottrina Inline; la prossima apertura lo rielabora leggero.
    public let isLarge: Bool
}

extension LibraryService {

    /// Vero se il libro è un volume ENORME: oltre la soglia di pagine si apre alleggerito (granularità grossa, niente
    /// Dottrina Inline né Consultazione Rapida). L'AKN non lo è mai (non ha pagine).
    public func isLarge(_ doc: ArchivedDocument) -> Bool {
        doc.sourcePageCount > ReadingAssembly.largeDocumentPageThreshold
    }

    /// La granularità con cui si elabora questo libro adesso: la regola condivisa (`ReadingAssembly.processingGranularity`)
    /// con la scelta delle Impostazioni (giro «prove rifatte e granularità», 2026-11-10; iPad e Mac la usano entrambi).
    /// All'importazione le pagine non si conoscono ancora: `large` falso (un volume enorme non va in cache all'importazione e
    /// alla prima apertura si prepara leggero, `registerImported`).
    public func processingGranularity(isAkn: Bool, large: Bool) -> Int {
        ReadingAssembly.processingGranularity(chosen: getStoredGranularityLevel(prefs).target, isAkn: isAkn, large: large)
    }

    /// La granularità che la cache di un libro deve avere per aprirsi senza rielaborare: quella con cui si elaborerebbe adesso.
    /// `nil` = va bene qualunque: un volume enorme ha la sua regola (solo la versione leggera), e una lettura ARRIVATA DAL MAC
    /// si adotta così com'è e non si rielabora mai da sé (§ 12.12, decisione 3: la lettura migliore dei modelli andrebbe persa).
    /// Un libro letto a un'altra granularità si rielabora una volta, alla prossima apertura (LAYER2 § 7.7).
    public func requiredCacheGranularity(for doc: ArchivedDocument) -> Int? {
        if isLarge(doc) || doc.readingOrigin == ReadingOrigin.mac { return nil }
        return processingGranularity(isAkn: doc.sourceKind == "akn", large: false)
    }

    /// La cache del libro, se si può usare per aprirlo. Per un volume enorme solo la versione LEGGERA (granularità grossa
    /// marcata): una cache pesante di build precedenti si rielabora. Per gli altri libri qualunque cache leggibile;
    /// `requiredTarget` vuole in più che la cache sia stata costruita a quella granularità (dal 2026-11-10 lo passano sia
    /// l'iPad sia il Mac, con `requiredCacheGranularity`; senza, qualunque granularità: la riapertura all'avvio).
    public func openableCachedReading(for doc: ArchivedDocument, requiredTarget: Int? = nil) -> LibraryReading? {
        let large = isLarge(doc)
        guard let cached = loadCache(forDocumentId: doc.id) else { return nil }
        if large {
            guard cached.contentTarget == ReadingAssembly.largeDocumentGranularity else { return nil }
        } else if let required = requiredTarget {
            guard (cached.contentTarget ?? DEFAULT_GRANULARITY_TARGET) == required else { return nil }
        }
        return LibraryReading(content: cached.content, pageMap: cached.pageMap,
                              doctrineContent: large ? nil : cached.doctrineContent,
                              quickConsultTree: large ? nil : cached.quickConsultTree)
    }

    /// Dopo una rielaborazione riuscita (all'apertura: cache mancante o non usabile): scrive la cache — per un volume enorme
    /// la versione leggera, senza albero né Dottrina Inline, con la granularità marcata — e registra con quale lettore di
    /// sistema e quale build il libro è stato elaborato. Ritorna la lettura da presentare.
    @discardableResult
    public func storeProcessedReading(
        documentId id: String, document: ScabopdfDocument, content: PaginatedContent, doctrineContent: PaginatedContent?,
        large: Bool, target: Int, visualResourcesSkipped: String?
    ) -> LibraryReading {
        let pageMap = ReadingAssembly.buildPageMap(document, content: content, doctrineContent: doctrineContent)
        let tree = large ? nil : ReadingAssembly.quickConsultTreeIfAvailable(document)
        writeCache(content, pageMap: pageMap,
                   doctrineContent: large ? nil : doctrineContent, quickConsultTree: tree,
                   contentTarget: target, forDocumentId: id)
        store.recordProcessed(id: id, systemVersion: SystemGeneration.current, appBuild: SystemGeneration.appBuild,
                              visualResourcesSkipped: visualResourcesSkipped)
        return LibraryReading(content: content, pageMap: pageMap,
                              doctrineContent: large ? nil : doctrineContent, quickConsultTree: tree)
    }

    /// La REGISTRAZIONE dopo un'importazione riuscita (§ 12.8-12.10), nell'ordine dell'iPad: il libro (titolo = nome del file
    /// senza estensione), la sorgente nell'archivio (PDF o XML AKN, la sorgente di verità, § 12.6), l'impronta del contenuto
    /// (quella del file scelto, già calcolata prima di elaborare; se manca, quella della copia d'archivio; se l'archiviazione
    /// fallisce il libro resta senza impronta, perché non si propone mai di «aprire» un libro senza il suo file), la mappa delle
    /// pagine, la cache (non per i volumi enormi), l'etichetta di generazione, la collocazione facoltativa, l'apertura.
    /// `contentTarget` è la granularità con cui `content` è stato costruito: dal 2026-11-10 quella scelta nelle Impostazioni,
    /// sull'iPad come sul Mac (`processingGranularity`).
    public func registerImported(
        document: ScabopdfDocument, content: PaginatedContent, doctrineContent: PaginatedContent?,
        sourceName: String, localCopy: URL, isAkn: Bool, sha256: String?, visualResourcesSkipped: String?,
        destination: ContainerRef?, contentTarget: Int = DEFAULT_GRANULARITY_TARGET
    ) -> RegisteredImport {
        let sourceKind: String? = isAkn ? "akn" : nil
        // Il titolo di default è il nome del file senza estensione (modificabile poi).
        let title = (sourceName as NSString).deletingPathExtension
        // L'AKN non ha pagine fisiche (§4): sourcePageCount=0 → indicatore di pagina inerte.
        let sourcePageCount = isAkn ? 0 : document.metadata.pages_pdf
        let doc = store.addDocument(
            title: title.isEmpty ? sourceName : title,
            sourceFileName: sourceName,
            sourcePageCount: sourcePageCount,
            warnings: document.warnings,
            sourceKind: sourceKind)
        // Archivia la sorgente (PDF o XML AKN, sorgente di verità §12.6) e la cache del contenuto.
        var archived = false
        do {
            try storeSource(from: localCopy, forDocumentId: doc.id, kind: sourceKind)
            archived = true
        } catch {
            // L'archiviazione è fallita: il documento resta apribile ora dalla cache, ma non rielaborabile in futuro.
            store.renameDocument(id: doc.id, to: doc.title)  // no-op, mantiene il record
        }
        if archived, let fingerprint = sha256
            ?? DocumentIdentity.fingerprintOfArchivedSource(store.document(id: doc.id) ?? doc, service: self) {
            store.setSourceSha256(id: doc.id, fingerprint)
        }
        let pageMap = ReadingAssembly.buildPageMap(document, content: content, doctrineContent: doctrineContent)
        // Volume ENORME: apertura alleggerita (niente albero né Dottrina) e NON in cache — la prossima apertura lo
        // rielabora leggero (granularità grossa). L'AKN non è mai "large" (sourcePageCount=0).
        let large = sourcePageCount > ReadingAssembly.largeDocumentPageThreshold
        let tree = large ? nil : ReadingAssembly.quickConsultTreeIfAvailable(document)
        if !large {
            writeCache(content, pageMap: pageMap,
                       doctrineContent: doctrineContent, quickConsultTree: tree,
                       contentTarget: contentTarget, forDocumentId: doc.id)
        }
        // Etichetta di generazione (anche per l'enorme non in cache: è comunque stato elaborato ora).
        store.recordProcessed(id: doc.id, systemVersion: SystemGeneration.current, appBuild: SystemGeneration.appBuild,
                              visualResourcesSkipped: visualResourcesSkipped)
        if let destination { store.addCollocation(documentId: doc.id, to: destination) }
        store.recordOpened(id: doc.id)
        return RegisteredImport(document: doc, pageMap: pageMap, quickConsultTree: tree, isLarge: large)
    }

    /// Riancora annotazioni e posizione di un documento sul contenuto appena elaborato (sul thread chiamante: si usa solo
    /// quando l'apertura ha dovuto rielaborare, evento raro). Ritorna il documento aggiornato. Nessuna annotazione →
    /// nessun lavoro.
    @discardableResult
    public func reanchorAfterProcessing(documentId: String, content: PaginatedContent) -> ArchivedDocument? {
        guard let doc = store.document(id: documentId) else { return nil }
        let hasAnything = !(doc.bookmarks ?? []).isEmpty || !(doc.underlines ?? []).isEmpty || doc.readingPosition > 0
        guard hasAnything else { return doc }
        let out = AnnotationReanchoring.reanchor(
            bookmarks: doc.bookmarks ?? [], underlines: doc.underlines ?? [], readingPosition: doc.readingPosition,
            readingAnchor: doc.readingAnchor, in: ContentAnchorIndex(segments: content.pages.flatMap { $0.segments }))
        store.applyAnnotationState(
            documentId: documentId, bookmarks: out.bookmarks, underlines: out.underlines,
            readingPosition: out.readingPosition, readingAnchor: out.readingAnchor,
            readingPositionIsApproximate: out.readingPositionIsApproximate ? true : nil)
        return store.document(id: documentId)
    }

    // MARK: Fuori dal filo principale (giro «prove rifatte e granularità», 2026-11-10)
    //
    // I tre lavori della libreria che stavano sul filo principale, su iPad e Mac: la REGISTRAZIONE dopo un'importazione, la
    // SCRITTURA DELLA CACHE alla prima riapertura e il RIANCORAGGIO di un libro già letto dopo una rielaborazione. Misurati
    // per parti sul volume più grande del banco (iPad simulato iOS 27, la stessa libreria del Mac): 0,008 s, 0,14 s e 1,7 s.
    // (I fermi di circa 0,3 s che il giro «prove della tappa A» vedeva sul Mac alla fine dell'importazione e della riapertura
    // sono quasi tutti l'animazione di chiusura del foglio d'elaborazione: `NSWindow.endSheet` trattiene il filo principale
    // circa 0,26 s, prova di laboratorio; non è un lavoro della libreria e qui non si tocca.) Qui i loro passi pesanti —
    // copia nell'archivio, impronta, mappa delle pagine, albero della Consultazione Rapida, codifica e scrittura della cache,
    // indice delle ancore e riancoraggio — girano su una coda a parte; le modifiche della libreria in memoria (che non è
    // protetta fra fili) restano sul filo principale, nello STESSO ORDINE delle versioni sincrone qui sopra, che restano per i
    // test e i banchi. Il risultato è lo stesso, al byte: stessa cache, stessi campi del libro, stesso ordine dei recenti.
    // Chi chiama è sul filo principale; `completion` arriva sul filo principale.

    /// La coda dei lavori pesanti: seriale, così i lavori di uno stesso libro non si accavallano.
    public static let heavyWorkQueue = DispatchQueue(label: "com.scabo.scabopdf.libreria.lavori-pesanti", qos: .userInitiated)

    /// `registerImported` con i passi pesanti fuori dal filo principale.
    public func registerImportedOffMain(
        document: ScabopdfDocument, content: PaginatedContent, doctrineContent: PaginatedContent?,
        sourceName: String, localCopy: URL, isAkn: Bool, sha256: String?, visualResourcesSkipped: String?,
        destination: ContainerRef?, contentTarget: Int = DEFAULT_GRANULARITY_TARGET,
        completion: @escaping (RegisteredImport) -> Void
    ) {
        dispatchPrecondition(condition: .onQueue(.main))
        let sourceKind: String? = isAkn ? "akn" : nil
        let title = (sourceName as NSString).deletingPathExtension
        let sourcePageCount = isAkn ? 0 : document.metadata.pages_pdf
        let doc = store.addDocument(
            title: title.isEmpty ? sourceName : title, sourceFileName: sourceName, sourcePageCount: sourcePageCount,
            warnings: document.warnings, sourceKind: sourceKind)
        let large = sourcePageCount > ReadingAssembly.largeDocumentPageThreshold
        Self.heavyWorkQueue.async {
            var archived = false
            do {
                try self.storeSource(from: localCopy, forDocumentId: doc.id, kind: sourceKind)
                archived = true
            } catch {}
            let fingerprint = archived ? (sha256 ?? DocumentIdentity.fingerprintOfArchivedSource(doc, service: self)) : nil
            let pageMap = ReadingAssembly.buildPageMap(document, content: content, doctrineContent: doctrineContent)
            let tree = large ? nil : ReadingAssembly.quickConsultTreeIfAvailable(document)
            if !large {
                self.writeCache(content, pageMap: pageMap, doctrineContent: doctrineContent, quickConsultTree: tree,
                                contentTarget: contentTarget, forDocumentId: doc.id)
            }
            DispatchQueue.main.async {
                if !archived { self.store.renameDocument(id: doc.id, to: doc.title) }   // come la versione sincrona
                if let fingerprint { self.store.setSourceSha256(id: doc.id, fingerprint) }
                self.store.recordProcessed(id: doc.id, systemVersion: SystemGeneration.current, appBuild: SystemGeneration.appBuild,
                                           visualResourcesSkipped: visualResourcesSkipped)
                if let destination { self.store.addCollocation(documentId: doc.id, to: destination) }
                self.store.recordOpened(id: doc.id)
                completion(RegisteredImport(document: doc, pageMap: pageMap, quickConsultTree: tree, isLarge: large))
            }
        }
    }

    /// `storeProcessedReading` con la mappa, l'albero e la scrittura della cache fuori dal filo principale.
    public func storeProcessedReadingOffMain(
        documentId id: String, document: ScabopdfDocument, content: PaginatedContent, doctrineContent: PaginatedContent?,
        large: Bool, target: Int, visualResourcesSkipped: String?, completion: @escaping (LibraryReading) -> Void
    ) {
        dispatchPrecondition(condition: .onQueue(.main))
        Self.heavyWorkQueue.async {
            let pageMap = ReadingAssembly.buildPageMap(document, content: content, doctrineContent: doctrineContent)
            let tree = large ? nil : ReadingAssembly.quickConsultTreeIfAvailable(document)
            self.writeCache(content, pageMap: pageMap, doctrineContent: large ? nil : doctrineContent, quickConsultTree: tree,
                            contentTarget: target, forDocumentId: id)
            DispatchQueue.main.async {
                self.store.recordProcessed(id: id, systemVersion: SystemGeneration.current, appBuild: SystemGeneration.appBuild,
                                           visualResourcesSkipped: visualResourcesSkipped)
                completion(LibraryReading(content: content, pageMap: pageMap,
                                          doctrineContent: large ? nil : doctrineContent, quickConsultTree: tree))
            }
        }
    }

    /// `reanchorAfterProcessing` con l'indice delle ancore e il riancoraggio fuori dal filo principale; lo stato delle
    /// annotazioni si legge e si scrive sul filo principale.
    public func reanchorAfterProcessingOffMain(documentId: String, content: PaginatedContent,
                                               completion: @escaping (ArchivedDocument?) -> Void) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard let doc = store.document(id: documentId) else { completion(nil); return }
        let hasAnything = !(doc.bookmarks ?? []).isEmpty || !(doc.underlines ?? []).isEmpty || doc.readingPosition > 0
        guard hasAnything else { completion(doc); return }
        Self.heavyWorkQueue.async {
            let out = AnnotationReanchoring.reanchor(
                bookmarks: doc.bookmarks ?? [], underlines: doc.underlines ?? [], readingPosition: doc.readingPosition,
                readingAnchor: doc.readingAnchor, in: ContentAnchorIndex(segments: content.pages.flatMap { $0.segments }))
            DispatchQueue.main.async {
                self.store.applyAnnotationState(
                    documentId: documentId, bookmarks: out.bookmarks, underlines: out.underlines,
                    readingPosition: out.readingPosition, readingAnchor: out.readingAnchor,
                    readingPositionIsApproximate: out.readingPositionIsApproximate ? true : nil)
                completion(self.store.document(id: documentId))
            }
        }
    }

    /// La riapertura di un libro dopo una rielaborazione riuscita, i tre passi dell'iPad e del Mac in fila — la lettura in
    /// cache, l'apertura registrata, le annotazioni riancorate — con i lavori pesanti fuori dal filo principale.
    /// `completion(libro aggiornato, lettura)` sul filo principale.
    public func completeReprocessedOpening(
        documentId id: String, document: ScabopdfDocument, content: PaginatedContent, doctrineContent: PaginatedContent?,
        large: Bool, target: Int, visualResourcesSkipped: String?,
        completion: @escaping (ArchivedDocument?, LibraryReading) -> Void
    ) {
        storeProcessedReadingOffMain(documentId: id, document: document, content: content, doctrineContent: doctrineContent,
                                     large: large, target: target, visualResourcesSkipped: visualResourcesSkipped) { reading in
            self.store.recordOpened(id: id)
            self.reanchorAfterProcessingOffMain(documentId: id, content: content) { doc in completion(doc, reading) }
        }
    }

    /// Conia le ancore per contenuto MANCANTI delle annotazioni del documento, a contenuto fermo (il flusso appena
    /// presentato è quello su cui gli id correnti sono veri): la migrazione gratuita delle annotazioni create prima delle
    /// ancore (docs/ANCORE_ANNOTAZIONI.md). Prima la verifica (§ 12.14 «al suo posto, verificato»): se un'annotazione punta
    /// per id a un segmento che non ha il contenuto della sua ancora, si riancora tutto per contenuto. Una sola scrittura,
    /// solo se c'è qualcosa da coniare.
    public func mintMissingAnchors(documentId: String, in index: ContentAnchorIndex) {
        guard let doc = store.document(id: documentId) else { return }
        if AnnotationReanchoring.needsReanchoring(
            bookmarks: doc.bookmarks ?? [], underlines: doc.underlines ?? [], readingPosition: doc.readingPosition,
            readingAnchor: doc.readingAnchor, in: index) {
            let out = AnnotationReanchoring.reanchor(
                bookmarks: doc.bookmarks ?? [], underlines: doc.underlines ?? [], readingPosition: doc.readingPosition,
                readingAnchor: doc.readingAnchor, in: index)
            store.applyAnnotationState(
                documentId: documentId, bookmarks: out.bookmarks, underlines: out.underlines,
                readingPosition: out.readingPosition, readingAnchor: out.readingAnchor,
                readingPositionIsApproximate: out.readingPositionIsApproximate ? true : doc.readingPositionIsApproximate)
            return mintMissingAnchors(documentId: documentId, in: index)
        }
        let out = AnnotationReanchoring.mintMissingAnchors(
            bookmarks: doc.bookmarks ?? [], underlines: doc.underlines ?? [], readingPosition: doc.readingPosition,
            readingAnchor: doc.readingAnchor, in: index)
        guard out.minted > 0 else { return }
        store.applyAnnotationState(
            documentId: documentId, bookmarks: out.bookmarks, underlines: out.underlines,
            readingPosition: doc.readingPosition, readingAnchor: out.readingAnchor,
            readingPositionIsApproximate: doc.readingPositionIsApproximate)
    }
}
