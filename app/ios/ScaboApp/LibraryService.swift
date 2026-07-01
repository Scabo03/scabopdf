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
    private static let cacheFormatVersion = 4
    /// Versione minima LEGGIBILE. Il formato 3 (build 19, senza l'albero della Consultazione
    /// Rapida) è RETROCOMPATIBILE col 4: `content`/`pageMap`/`doctrineContent` hanno la stessa
    /// forma, il campo `quickConsultTree` è opzionale (nil sul 3 → Consultazione Rapida non
    /// disponibile per quel documento finché non viene rielaborato). Accettare il 3 evita di
    /// invalidare TUTTE le cache all'aggiornamento: senza questo, ogni documento già in cache
    /// verrebbe RIELABORATO all'apertura — un picco di memoria che sul dispositivo espelle l'app
    /// (regressione build 20). Con questo, i documenti cachati si aprono leggeri come in build 19.
    private static let minReadableCacheFormatVersion = 3

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
        /// Mappa id-nodo → pagina del file originale (1-based), per l'indicatore doppio (§ 4.3).
        var pageMap: [String: Int]
        /// Flusso Dottrina Inline (§ 10), `nil` se il documento non ha note. Aggiunto al formato 3.
        var doctrineContent: PaginatedContent?
        /// Albero della Consultazione Rapida (§ 8), `nil` se il documento non ha gerarchia.
        /// Aggiunto al formato 4 (vecchie cache senza albero → invalidate → rielabora).
        var quickConsultTree: [QuickConsultNode]?
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
            quickConsultTree: [QuickConsultNode]?)? {
        guard let data = try? Data(contentsOf: cacheURL(forDocumentId: id)),
              let cached = try? JSONDecoder().decode(CachedContent.self, from: data),
              cached.formatVersion >= Self.minReadableCacheFormatVersion,
              cached.formatVersion <= Self.cacheFormatVersion else {
            // Cache assente, corrotta, o di formato non compatibile → rielabora dal PDF.
            // Non deve MAI far crashare: un fallimento di decodifica cade qui via `try?`.
            return nil
        }
        return (cached.content, cached.pageMap, cached.doctrineContent, cached.quickConsultTree)
    }

    /// Il solo contenuto elaborato in cache (riapertura all'avvio).
    func cachedContent(forDocumentId id: String) -> PaginatedContent? {
        loadCache(forDocumentId: id)?.content
    }

    /// Scrive (o aggiorna) la cache: contenuto Lettura Continua + mappa pagine + Dottrina Inline.
    func writeCache(
        _ content: PaginatedContent, pageMap: [String: Int],
        doctrineContent: PaginatedContent?, quickConsultTree: [QuickConsultNode]?,
        forDocumentId id: String
    ) {
        let wrapped = CachedContent(
            formatVersion: Self.cacheFormatVersion, content: content,
            pageMap: pageMap, doctrineContent: doctrineContent, quickConsultTree: quickConsultTree)
        if let data = try? JSONEncoder().encode(wrapped) {
            try? data.write(to: cacheURL(forDocumentId: id), options: .atomic)
        }
    }

    /// Rimuove PDF e cache di un documento dal disco (chiamata all'eliminazione definitiva).
    func deleteFiles(forDocumentId id: String) {
        try? fileManager.removeItem(at: archivedPDFURL(forDocumentId: id))
        try? fileManager.removeItem(at: cacheURL(forDocumentId: id))
    }
}
