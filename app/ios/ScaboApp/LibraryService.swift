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

    /// Versione del formato di cache: un cambiamento del modello `PaginatedContent` la fa
    /// incrementare, invalidando le cache vecchie (che ripiegano sulla rielaborazione dal PDF).
    private static let cacheFormatVersion = 1

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
    }

    private func cacheURL(forDocumentId id: String) -> URL {
        cacheDir.appendingPathComponent("\(id).json")
    }

    /// Il contenuto elaborato in cache, o `nil` se assente/corrotto/di formato superato (→ si
    /// rielabora dal PDF d'archivio).
    func cachedContent(forDocumentId id: String) -> PaginatedContent? {
        guard let data = try? Data(contentsOf: cacheURL(forDocumentId: id)),
              let cached = try? JSONDecoder().decode(CachedContent.self, from: data),
              cached.formatVersion == Self.cacheFormatVersion else {
            return nil
        }
        return cached.content
    }

    /// Scrive (o aggiorna) la cache del contenuto elaborato di un documento.
    func writeCache(_ content: PaginatedContent, forDocumentId id: String) {
        let wrapped = CachedContent(formatVersion: Self.cacheFormatVersion, content: content)
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
