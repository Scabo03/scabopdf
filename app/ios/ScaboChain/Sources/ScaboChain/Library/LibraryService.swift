//
//  LibraryService.swift
//  ScaboChain (fino al 2026-11-08 nel bersaglio ScaboApp; spostato senza cambiarne la logica perché l'app
//  Mac, ScaboPDF per Mac, tiene la libreria nella stessa forma dell'iPad: giro «app unica per Mac, tappa A»)
//
//  La facciata applicativa che radica la libreria sul filesystem reale e tiene insieme i tre pezzi
//  di stato persistente dell'app:
//
//    1. lo STORE della libreria (`LibraryStore` di ScaboCore) → metadati, contenitori, collocazioni,
//       recenti, posizione di lettura — un piccolo JSON in Application Support;
//    2. l'ARCHIVIO dei PDF di origine → un file per documento in `Archive/<id>.pdf`, sorgente di
//       verità da cui si rielabora (§ 12.6);
//    3. la CACHE del contenuto elaborato → `Cache/<id>.json`, così la riapertura è IMMEDIATA invece
//       di rielaborare il PDF da capo. La cache è un'ottimizzazione: se manca, è corrotta, o cambia
//       il formato, si rielabora dal PDF d'archivio (degradazione pulita, § 2.5). Accanto, dal giro
//       «ricerca nella libreria» (2026-10-20), `Cache/<id>.search`: il testo di ricerca del libro.
//
//  Le preferenze globali (tema, granularità, toggle pagine, § 4.2 / § 7.7) usano lo stesso confine
//  `KeyValueStore` di ScaboCore, qui radicato su `UserDefaults`.
//
//  Confine: questo file è pura orchestrazione di stato (Foundation + ScaboCore). Niente UIKit,
//  niente PDFKit. L'elaborazione vive nel `DocumentProcessor`; la presentazione nei view controller.
//

import Foundation
import ScaboCore

/// Singleton di servizio per lo stato persistente dell'app.
public final class LibraryService {

    public static let shared = LibraryService()

    /// Lo store della libreria (metadati + organizzazione + stato di lettura).
    public let store: LibraryStore
    /// Le preferenze globali (tema, granularità, toggle pagine).
    public let prefs: KeyValueStore

    private let fileManager = FileManager.default
    private let archiveDir: URL
    private let cacheDir: URL

    /// Versione del formato di cache SCRITTA dalle nuove elaborazioni.
    private static let cacheFormatVersion = ReadingAssembly.cacheFormatVersion   // 6; in ScaboChain dal 2026-10-16 (lo usa anche il pacchetto del Mac)
    /// Versione minima LEGGIBILE.
    ///
    /// STORIA, perché questa costante è delicata. Fino al formato 4 valeva 3, deliberatamente: il 3
    /// (build 19) è retrocompatibile col 4 e accettarlo evitava di invalidare TUTTE le cache
    /// all'aggiornamento — senza quella tolleranza ogni documento già in cache veniva RIELABORATO
    /// all'apertura, un picco di memoria che sul dispositivo espellette l'app (regressione build 20).
    ///
    /// Il formato 5 la alza a 5, e questa volta l'invalidazione è VOLUTA e sanzionata dal
    /// maintainer. La ragione è che il difetto che chiude non è rimediabile a cache ferma: la
    /// pagina del file originale è passata da dato del NODO a dato del SEGMENTO (vedi
    /// `ContentSegment.sourcePage`), e la mappa esatta per le fette dei paragrafi ricuciti
    /// attraverso il salto pagina può nascere solo da una rielaborazione. Ogni documento si
    /// rielabora UNA volta, alla sua prima apertura, uno alla volta e su azione dell'utente —
    /// esattamente il percorso già esercitato di un documento non in cache. Il muro di memoria
    /// della build 20 (il render di ~47k etichette vive) non esiste più: la reading view è a
    /// finestra scorrevole, l'estrazione è a flusso e i volumi enormi si aprono in modalità
    /// leggera. Resta il picco TRANSITORIO dell'estrazione, lo stesso di un'importazione.
    ///
    /// Il formato 6 (2026-10-05, cura dei titoli di paragrafo) la alza a 6 per la stessa ragione:
    /// il canale dei titoli numerati cambia la STRUTTURA (nuove intestazioni, blocchi spezzati al
    /// titolo, note lunghe lette a fine paragrafo invece che a fine capitolo) e la lista delle
    /// abbreviazioni cambia i confini di frase. Nulla di questo è ricavabile da una cache ferma:
    /// senza invalidazione i volumi già importati non mostrerebbero la cura. Ogni documento si
    /// rielabora UNA volta, alla prima apertura, come col formato 5.
    private static let minReadableCacheFormatVersion = ReadingAssembly.minReadableCacheFormatVersion   // 6

    /// La libreria dell'app: `Application Support/ScaboPDF/` (sull'iPad e, dentro il contenitore della sandbox, sul Mac).
    private convenience init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let root = support.appendingPathComponent("ScaboPDF", isDirectory: true)
        self.init(rootDirectory: root, prefs: UserDefaultsKeyValueStore())
    }

    /// Una libreria radicata in `root`, nella stessa forma (`library.json`, `Archive/`, `Cache/`): l'app usa `shared`; i test
    /// e il banco del Mac una cartella propria.
    public init(rootDirectory root: URL, prefs: KeyValueStore) {
        archiveDir = root.appendingPathComponent("Archive", isDirectory: true)
        cacheDir = root.appendingPathComponent("Cache", isDirectory: true)
        try? fileManager.createDirectory(at: archiveDir, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)

        let libraryURL = root.appendingPathComponent("library.json")
        store = LibraryStore(persistence: FileLibraryPersistence(url: libraryURL))
        self.prefs = prefs
    }

    // MARK: - Archivio PDF (sorgente di verità)

    /// Il percorso d'archivio del PDF di origine di un documento.
    public func archivedPDFURL(forDocumentId id: String) -> URL {
        archiveDir.appendingPathComponent("\(id).pdf")
    }

    /// Vero se il PDF d'archivio esiste (necessario per rielaborare in caso di cache mancante).
    public func hasArchivedPDF(forDocumentId id: String) -> Bool {
        fileManager.fileExists(atPath: archivedPDFURL(forDocumentId: id).path)
    }

    /// Copia il PDF importato (una copia temporanea) nell'archivio sotto l'id del documento.
    public func storePDF(from temporaryURL: URL, forDocumentId id: String) throws {
        let destination = archivedPDFURL(forDocumentId: id)
        if fileManager.fileExists(atPath: destination.path) {
            try? fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: temporaryURL, to: destination)
    }

    // MARK: - Cache del contenuto elaborato

    private struct CachedContent: Codable {
        var formatVersion: Int
        var content: PaginatedContent
        /// Mappa → pagina del file originale (1-based), per l'indicatore (§ 4.3). Dal formato 5
        /// porta due strati: id-nodo (storico) e, sopra, id-SEGMENTO per le fette `<idNodo>#<k>`
        /// dei paragrafi ricuciti attraverso il salto pagina, che è l'unico strato esatto per loro.
        var pageMap: [String: Int]
        /// Flusso Dottrina Inline (§ 10), `nil` se il documento non ha note. Aggiunto al formato 3.
        var doctrineContent: PaginatedContent?
        /// Albero della Consultazione Rapida (§ 8), `nil` se il documento non ha gerarchia.
        /// Aggiunto al formato 4 (vecchie cache senza albero → invalidate → rielabora).
        var quickConsultTree: [QuickConsultNode]?
        /// Granularità con cui il `content` è stato costruito (§ 7.6). `nil` sulle cache più
        /// vecchie (trattate come granularità di default). Per i volumi ENORMI il content è
        /// costruito a granularità grossa (meno segmenti → meno memoria all'apertura); questo
        /// campo permette all'apertura di riconoscere una cache "leggera" già pronta da una
        /// cache "pesante" a granularità fine da rielaborare. Additivo (formato 4 invariato).
        var contentTarget: Int?
    }

    private func cacheURL(forDocumentId id: String) -> URL {
        cacheDir.appendingPathComponent("\(id).json")
    }

    /// URL del file di cache di un documento (per i test: simulare una cache di formato vecchio).
    public func cacheURLForTesting(forDocumentId id: String) -> URL { cacheURL(forDocumentId: id) }

    /// Vero se esiste un file di cache (senza decodificarlo): un libro con la cache si apre anche senza il file d'archivio.
    public func hasCache(forDocumentId id: String) -> Bool {
        fileManager.fileExists(atPath: cacheURL(forDocumentId: id).path)
    }

    /// Contenuto + mappa pagine + (se presente) flusso Dottrina Inline in cache, o `nil` se
    /// assente/corrotto/di formato superato (→ si rielabora dal PDF d'archivio).
    public func loadCache(forDocumentId id: String)
        -> (content: PaginatedContent, pageMap: [String: Int], doctrineContent: PaginatedContent?,
            quickConsultTree: [QuickConsultNode]?, contentTarget: Int?)? {
        guard let data = try? Data(contentsOf: cacheURL(forDocumentId: id)),
              let cached = try? JSONDecoder().decode(CachedContent.self, from: data),
              cached.formatVersion >= Self.minReadableCacheFormatVersion,
              cached.formatVersion <= Self.cacheFormatVersion else {
            // Cache assente, corrotta, o di formato non compatibile → rielabora dal PDF.
            // Non deve MAI far crashare: un fallimento di decodifica cade qui via `try?`.
            return nil
        }
        return (cached.content, cached.pageMap, cached.doctrineContent, cached.quickConsultTree, cached.contentTarget)
    }

    /// Il solo contenuto elaborato in cache (riapertura all'avvio).
    public func cachedContent(forDocumentId id: String) -> PaginatedContent? {
        loadCache(forDocumentId: id)?.content
    }

    /// Scrive (o aggiorna) la cache: contenuto Lettura Continua + mappa pagine + Dottrina Inline. Ritorna se la
    /// scrittura è riuscita (scrittura atomica: se fallisce, la cache di prima resta intatta). I chiamanti storici
    /// ignorano l'esito; la ricezione della lettura dal Mac lo controlla (giro del 2026-10-16).
    @discardableResult
    public func writeCache(
        _ content: PaginatedContent, pageMap: [String: Int],
        doctrineContent: PaginatedContent?, quickConsultTree: [QuickConsultNode]?,
        contentTarget: Int, forDocumentId id: String
    ) -> Bool {
        let wrapped = CachedContent(
            formatVersion: Self.cacheFormatVersion, content: content,
            pageMap: pageMap, doctrineContent: doctrineContent, quickConsultTree: quickConsultTree,
            contentTarget: contentTarget)
        guard let data = try? JSONEncoder().encode(wrapped) else { return false }
        guard (try? data.write(to: cacheURL(forDocumentId: id), options: .atomic)) != nil else { return false }
        // Il testo di ricerca della libreria nasce dagli stessi segmenti, timbrato con la cache appena scritta.
        if let stamp = cacheStamp(forDocumentId: id) {
            writeSearchTextInBackground(segments: content.pages.flatMap { $0.segments }, stamp: stamp, forDocumentId: id)
        }
        return true
    }

    /// Rimuove sorgente (PDF o AKN), cache e testo di ricerca di un documento dal disco (eliminazione definitiva).
    public func deleteFiles(forDocumentId id: String) {
        try? fileManager.removeItem(at: archivedPDFURL(forDocumentId: id))
        try? fileManager.removeItem(at: archivedSourceURL(forDocumentId: id, kind: "akn"))
        try? fileManager.removeItem(at: cacheURL(forDocumentId: id))
        Self.searchTextQueue.sync { try? fileManager.removeItem(at: searchTextURL(forDocumentId: id)) }
        discardPreviousReading(forDocumentId: id)
    }

    // MARK: - Testo di ricerca della libreria (tab Ricerca, § 13.2; ScaboCore LibrarySearch.swift)
    //
    // Per ogni libro `<id>.search` accanto alla cache: il testo normalizzato della lettura, timbrato con dimensione e data
    // di modifica della cache da cui è nato. Si scrive a ogni scrittura della cache (elaborazione, rielaborazione,
    // ricezione di una lettura dal Mac), si mette da parte e si rimette con la lettura precedente, si cancella con il libro.
    // Un timbro che non coincide con la cache di adesso vuol dire «non vale»: lo si riscrive in sottofondo
    // (`LibrarySearchIndex.catchUp`), e intanto il libro si dice «non ancora pronto», mai cercato su una lettura vecchia.

    /// Coda seriale di ogni scrittura e cancellazione dei testi di ricerca: l'ultima scrittura chiesta è l'ultima eseguita.
    public static let searchTextQueue = DispatchQueue(label: "com.scabo.scabopdf.testo-di-ricerca", qos: .utility)

    public func searchTextURL(forDocumentId id: String) -> URL { cacheDir.appendingPathComponent("\(id).search") }
    private func previousSearchTextURL(_ id: String) -> URL { cacheDir.appendingPathComponent("\(id).prev.search") }

    /// Il timbro della cache del documento (dimensione e data di modifica), o `nil` se la cache non c'è.
    public func cacheStamp(forDocumentId id: String) -> LibrarySearchText.SourceStamp? {
        guard let attrs = try? fileManager.attributesOfItem(atPath: cacheURL(forDocumentId: id).path),
              let size = (attrs[.size] as? NSNumber)?.int64Value,
              let date = attrs[.modificationDate] as? Date else { return nil }
        return LibrarySearchText.SourceStamp(size: size, modifiedNanoseconds: Int64((date.timeIntervalSince1970 * 1e9).rounded()))
    }

    /// Scrive il testo di ricerca in sottofondo (la costruzione è un'altra passata sul testo del libro: ≤ 0,1 s sul Mac
    /// per il volume più grande). `completion`, se c'è, arriva sulla coda dei testi di ricerca.
    public func writeSearchTextInBackground(segments: [ContentSegment], stamp: LibrarySearchText.SourceStamp,
                                     forDocumentId id: String, completion: (() -> Void)? = nil) {
        let url = searchTextURL(forDocumentId: id)
        Self.searchTextQueue.async {
            let data = LibrarySearchText.encode(segments: segments, stamp: stamp)
            try? data.write(to: url, options: .atomic)
            completion?()
        }
    }

    /// Il testo di ricerca del documento, mappato in memoria, se vale per la cache di adesso; `nil` altrimenti (assente,
    /// danneggiato, di un'altra versione, o nato da una cache che non c'è più).
    public func validSearchText(forDocumentId id: String) -> Data? {
        guard let stamp = cacheStamp(forDocumentId: id),
              let data = try? Data(contentsOf: searchTextURL(forDocumentId: id), options: .alwaysMapped),
              LibrarySearchText.stamp(of: data) == stamp else { return nil }
        return data
    }

    /// Vero se il documento ha la cache ma non un testo di ricerca valido (da riscrivere in sottofondo).
    public func needsSearchText(forDocumentId id: String) -> Bool {
        // La mappatura non legge il file: dell'intestazione si tocca una pagina sola.
        hasCache(forDocumentId: id) && validSearchText(forDocumentId: id) == nil
    }

    /// Il solo contenuto di Lettura Continua di una cache (per riscrivere il testo di ricerca), con il timbro letto prima e
    /// dopo: `nil` se la cache manca, non si legge, o è cambiata nel frattempo.
    public func cachedContentForSearchText(forDocumentId id: String) -> (segments: [ContentSegment], stamp: LibrarySearchText.SourceStamp)? {
        struct ContentOnly: Decodable { var formatVersion: Int; var content: PaginatedContent }
        guard let before = cacheStamp(forDocumentId: id),
              let data = try? Data(contentsOf: cacheURL(forDocumentId: id)),
              let cached = try? JSONDecoder().decode(ContentOnly.self, from: data),
              cached.formatVersion >= Self.minReadableCacheFormatVersion, cached.formatVersion <= Self.cacheFormatVersion,
              cacheStamp(forDocumentId: id) == before else { return nil }
        return (cached.content.pages.flatMap { $0.segments }, before)
    }

    // MARK: - Lettura precedente (offerta di rielaborazione, § 12.13 / § 12.14)
    //
    // Prima di una rielaborazione la cache corrente diventa `<id>.prev.json` e lo stato delle
    // annotazioni (`ReadingSnapshot`) si salva in `<id>.prev-state.json`. Restano finché l'utente non
    // conferma la nuova lettura; «Torna alla lettura precedente» li rimette esattamente com'erano.

    private func previousCacheURL(_ id: String) -> URL { cacheDir.appendingPathComponent("\(id).prev.json") }
    private func previousStateURL(_ id: String) -> URL { cacheDir.appendingPathComponent("\(id).prev-state.json") }

    /// Vero se il documento ha una lettura precedente in attesa di conferma.
    public func hasPreviousReading(forDocumentId id: String) -> Bool {
        fileManager.fileExists(atPath: previousStateURL(id).path)
    }

    /// Mette da parte la cache corrente (se c'è) e la fotografia dello stato. Una sola lettura
    /// precedente: se ne esisteva già una non confermata, si tiene quella PIÙ VECCHIA (è la lettura
    /// da cui l'utente era partito).
    public func stashPreviousReading(_ snapshot: ReadingSnapshot, forDocumentId id: String) throws {
        guard !hasPreviousReading(forDocumentId: id) else { return }
        let cache = cacheURL(forDocumentId: id)
        if fileManager.fileExists(atPath: cache.path) {
            try? fileManager.removeItem(at: previousCacheURL(id))
            try fileManager.copyItem(at: cache, to: previousCacheURL(id))
        }
        // Il testo di ricerca segue la cache (se la copia non porta la stessa data, il timbro non coincide e si riscrive).
        Self.searchTextQueue.sync {
            try? fileManager.removeItem(at: previousSearchTextURL(id))
            try? fileManager.copyItem(at: searchTextURL(forDocumentId: id), to: previousSearchTextURL(id))
        }
        let enc = JSONEncoder()
        try enc.encode(snapshot).write(to: previousStateURL(id), options: .atomic)
    }

    public func previousReadingSnapshot(forDocumentId id: String) -> ReadingSnapshot? {
        guard let data = try? Data(contentsOf: previousStateURL(id)) else { return nil }
        return try? JSONDecoder().decode(ReadingSnapshot.self, from: data)
    }

    /// Rimette la cache precedente al suo posto (o, se non c'era, toglie quella nuova: il libro si
    /// rielaborerà all'apertura come prima). Ritorna la fotografia dello stato da ripristinare.
    public func restorePreviousCache(forDocumentId id: String) -> ReadingSnapshot? {
        guard let snapshot = previousReadingSnapshot(forDocumentId: id) else { return nil }
        let cache = cacheURL(forDocumentId: id)
        try? fileManager.removeItem(at: cache)
        if fileManager.fileExists(atPath: previousCacheURL(id).path) {
            try? fileManager.moveItem(at: previousCacheURL(id), to: cache)
        }
        // Il testo di ricerca della lettura precedente torna con lei; quello della lettura nuova se ne va.
        Self.searchTextQueue.sync {
            try? fileManager.removeItem(at: searchTextURL(forDocumentId: id))
            try? fileManager.moveItem(at: previousSearchTextURL(id), to: searchTextURL(forDocumentId: id))
        }
        try? fileManager.removeItem(at: previousStateURL(id))
        return snapshot
    }

    /// Conferma la nuova lettura: la precedente si cancella.
    public func discardPreviousReading(forDocumentId id: String) {
        try? fileManager.removeItem(at: previousCacheURL(id))
        try? fileManager.removeItem(at: previousStateURL(id))
        Self.searchTextQueue.sync { try? fileManager.removeItem(at: previousSearchTextURL(id)) }
    }

    // MARK: - Archivio sorgente generico (PDF o AKN)

    /// Percorso d'archivio della sorgente secondo il formato: `<id>.pdf` (default/PDF) o
    /// `<id>.xml` (AKN). È la sorgente di verità da cui si rielabora quando la cache manca (§12.6).
    public func archivedSourceURL(forDocumentId id: String, kind: String?) -> URL {
        let ext = (kind == "akn") ? "xml" : "pdf"
        return archiveDir.appendingPathComponent("\(id).\(ext)")
    }

    /// Vero se la sorgente d'archivio del formato dato esiste (necessaria per rielaborare).
    public func hasArchivedSource(forDocumentId id: String, kind: String?) -> Bool {
        fileManager.fileExists(atPath: archivedSourceURL(forDocumentId: id, kind: kind).path)
    }

    /// Copia la sorgente importata (copia temporanea) nell'archivio sotto l'id del documento,
    /// con l'estensione del formato. Simmetrico a `storePDF` (§12.6).
    public func storeSource(from temporaryURL: URL, forDocumentId id: String, kind: String?) throws {
        let destination = archivedSourceURL(forDocumentId: id, kind: kind)
        if fileManager.fileExists(atPath: destination.path) {
            try? fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: temporaryURL, to: destination)
    }
}
