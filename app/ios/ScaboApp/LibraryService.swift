//
//  LibraryService.swift
//  ScaboApp
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
//       il formato, si rielabora dal PDF d'archivio (degradazione pulita, § 2.5).
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
final class LibraryService {

    static let shared = LibraryService()

    /// Lo store della libreria (metadati + organizzazione + stato di lettura).
    let store: LibraryStore
    /// Le preferenze globali (tema, granularità, toggle pagine).
    let prefs: KeyValueStore

    private let fileManager = FileManager.default
    private let archiveDir: URL
    private let cacheDir: URL

    /// Versione del formato di cache SCRITTA dalle nuove elaborazioni.
    private static let cacheFormatVersion = 5
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
    private static let minReadableCacheFormatVersion = 5

    private init() {
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let root = support.appendingPathComponent("ScaboPDF", isDirectory: true)
        archiveDir = root.appendingPathComponent("Archive", isDirectory: true)
        cacheDir = root.appendingPathComponent("Cache", isDirectory: true)
        try? fileManager.createDirectory(at: archiveDir, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)

        let libraryURL = root.appendingPathComponent("library.json")
        store = LibraryStore(persistence: FileLibraryPersistence(url: libraryURL))
        prefs = UserDefaultsKeyValueStore()
    }

    // MARK: - Archivio PDF (sorgente di verità)

    /// Il percorso d'archivio del PDF di origine di un documento.
    func archivedPDFURL(forDocumentId id: String) -> URL {
        archiveDir.appendingPathComponent("\(id).pdf")
    }

    /// Vero se il PDF d'archivio esiste (necessario per rielaborare in caso di cache mancante).
    func hasArchivedPDF(forDocumentId id: String) -> Bool {
        fileManager.fileExists(atPath: archivedPDFURL(forDocumentId: id).path)
    }

    /// Copia il PDF importato (una copia temporanea) nell'archivio sotto l'id del documento.
    func storePDF(from temporaryURL: URL, forDocumentId id: String) throws {
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
    func cacheURLForTesting(forDocumentId id: String) -> URL { cacheURL(forDocumentId: id) }

    /// Contenuto + mappa pagine + (se presente) flusso Dottrina Inline in cache, o `nil` se
    /// assente/corrotto/di formato superato (→ si rielabora dal PDF d'archivio).
    func loadCache(forDocumentId id: String)
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
    func cachedContent(forDocumentId id: String) -> PaginatedContent? {
        loadCache(forDocumentId: id)?.content
    }

    /// Scrive (o aggiorna) la cache: contenuto Lettura Continua + mappa pagine + Dottrina Inline.
    func writeCache(
        _ content: PaginatedContent, pageMap: [String: Int],
        doctrineContent: PaginatedContent?, quickConsultTree: [QuickConsultNode]?,
        contentTarget: Int, forDocumentId id: String
    ) {
        let wrapped = CachedContent(
            formatVersion: Self.cacheFormatVersion, content: content,
            pageMap: pageMap, doctrineContent: doctrineContent, quickConsultTree: quickConsultTree,
            contentTarget: contentTarget)
        if let data = try? JSONEncoder().encode(wrapped) {
            try? data.write(to: cacheURL(forDocumentId: id), options: .atomic)
        }
    }

    /// Rimuove sorgente (PDF o AKN) e cache di un documento dal disco (eliminazione definitiva).
    func deleteFiles(forDocumentId id: String) {
        try? fileManager.removeItem(at: archivedPDFURL(forDocumentId: id))
        try? fileManager.removeItem(at: archivedSourceURL(forDocumentId: id, kind: "akn"))
        try? fileManager.removeItem(at: cacheURL(forDocumentId: id))
    }

    // MARK: - Archivio sorgente generico (PDF o AKN)

    /// Percorso d'archivio della sorgente secondo il formato: `<id>.pdf` (default/PDF) o
    /// `<id>.xml` (AKN). È la sorgente di verità da cui si rielabora quando la cache manca (§12.6).
    func archivedSourceURL(forDocumentId id: String, kind: String?) -> URL {
        let ext = (kind == "akn") ? "xml" : "pdf"
        return archiveDir.appendingPathComponent("\(id).\(ext)")
    }

    /// Vero se la sorgente d'archivio del formato dato esiste (necessaria per rielaborare).
    func hasArchivedSource(forDocumentId id: String, kind: String?) -> Bool {
        fileManager.fileExists(atPath: archivedSourceURL(forDocumentId: id, kind: kind).path)
    }

    /// Copia la sorgente importata (copia temporanea) nell'archivio sotto l'id del documento,
    /// con l'estensione del formato. Simmetrico a `storePDF` (§12.6).
    func storeSource(from temporaryURL: URL, forDocumentId id: String, kind: String?) throws {
        let destination = archivedSourceURL(forDocumentId: id, kind: kind)
        if fileManager.fileExists(atPath: destination.path) {
            try? fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: temporaryURL, to: destination)
    }
}
