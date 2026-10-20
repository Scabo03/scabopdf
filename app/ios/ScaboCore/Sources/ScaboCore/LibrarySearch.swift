//
//  LibrarySearch.swift
//  ScaboCore
//
//  RICERCA NEL TESTO DI TUTTI I LIBRI (tab Ricerca della Home; LAYER2_PRODUCT_DECISIONS § 13.2-13.3; giro «ricerca nella
//  libreria», 2026-10-20). Solo Foundation, come `BookSearch.swift`.
//
//  ── Il testo di ricerca di un libro ────────────────────────────────────────────────────────────────────────────
//
//  Per ogni libro l'app scrive, accanto alla cache della lettura, un file con il TESTO DI RICERCA: gli stessi byte del
//  `BookSearchCorpus` costruito dagli stessi segmenti (il flusso del corpo e un flusso per nota, normalizzati) e i confini
//  dei richiami di nota. Una ricerca nella libreria scorre questi file un libro alla volta, con la stessa scansione della
//  ricerca nel libro (`PreparedBookSearch.scan`): il numero di risultati di un libro è quello che la ricerca dentro quel
//  libro aperto dirà. Il file è mappato in memoria e lasciato subito dopo: la memoria è quella di un libro, mai di tutti.
//
//  Il file porta il TIMBRO della cache da cui è nato (dimensione e data di modifica): se la cache cambia senza che il testo
//  di ricerca sia stato riscritto, il timbro non coincide e il testo non vale (l'app lo riscrive in sottofondo). Così un
//  risultato non viene mai da una lettura che non è più quella del libro.
//
//  ── Formato (versione 1, little-endian) ───────────────────────────────────────────────────────────────────────
//
//      0  «SCABORIC»                       8 byte
//      8  versione del formato             UInt32
//     12  riservato (0)                    UInt32
//     16  timbro: dimensione della cache   Int64
//     24  timbro: modifica (nanosecondi)   Int64
//     32  byte del testo (n)               UInt32
//     36  confini (k)                      UInt32
//     40  testo                            n byte, poi zeri fino a un multiplo di 4
//      …  confini                          k × Int32 (posizioni nel testo, crescenti)
//
//  Nessun testo del libro lascia il dispositivo: il file sta nella cartella della cache dell'app (§ 12.12).
//

import Foundation

public enum LibrarySearchText {
    /// Versione del formato del file. Va alzata se cambia il formato o cambiano le regole del testo da cercare
    /// (normalizzazione, flussi, confini): un file di versione diversa non vale e si riscrive.
    public static let formatVersion: UInt32 = 1
    static let magic: [UInt8] = Array("SCABORIC".utf8)
    static let headerSize = 40

    /// Il timbro della cache da cui il testo di ricerca è nato.
    public struct SourceStamp: Equatable, Sendable {
        public var size: Int64
        public var modifiedNanoseconds: Int64
        public init(size: Int64, modifiedNanoseconds: Int64) {
            self.size = size
            self.modifiedNanoseconds = modifiedNanoseconds
        }
    }

    /// Il file del testo di ricerca dei segmenti di Lettura Continua di un libro.
    public static func encode(segments: [ContentSegment], stamp: SourceStamp) -> Data {
        encode(BookSearchCorpus(segments: segments), stamp: stamp)
    }

    /// Il file del testo di ricerca di un testo già pronto.
    public static func encode(_ corpus: BookSearchCorpus, stamp: SourceStamp) -> Data {
        let n = corpus.buffer.count, k = corpus.wordBoundaries.count
        let padded = (n + 3) & ~3
        var data = Data(capacity: headerSize + padded + 4 * k)
        data.append(contentsOf: magic)
        appendLE(&data, formatVersion)
        appendLE(&data, UInt32(0))
        appendLE(&data, stamp.size)
        appendLE(&data, stamp.modifiedNanoseconds)
        appendLE(&data, UInt32(n))
        appendLE(&data, UInt32(k))
        data.append(contentsOf: corpus.buffer)
        if padded > n { data.append(contentsOf: [UInt8](repeating: 0, count: padded - n)) }
        for b in corpus.wordBoundaries { appendLE(&data, b) }
        return data
    }

    private static func appendLE<T: FixedWidthInteger>(_ data: inout Data, _ v: T) {
        withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) }
    }

    /// L'intestazione letta, se il file è integro e della versione corrente.
    struct Header {
        let stamp: SourceStamp
        let textCount: Int
        let boundaryCount: Int
        var boundariesOffset: Int { LibrarySearchText.headerSize + ((textCount + 3) & ~3) }
    }

    static func header(_ raw: UnsafeRawBufferPointer) -> Header? {
        guard raw.count >= headerSize, Array(raw[0..<8]) == magic else { return nil }
        func u32(_ o: Int) -> UInt32 { UInt32(littleEndian: raw.loadUnaligned(fromByteOffset: o, as: UInt32.self)) }
        func i64(_ o: Int) -> Int64 { Int64(littleEndian: raw.loadUnaligned(fromByteOffset: o, as: Int64.self)) }
        guard u32(8) == formatVersion else { return nil }
        let h = Header(stamp: SourceStamp(size: i64(16), modifiedNanoseconds: i64(24)),
                       textCount: Int(u32(32)), boundaryCount: Int(u32(36)))
        guard raw.count == h.boundariesOffset + 4 * h.boundaryCount else { return nil }
        return h
    }

    /// Il timbro del file, o `nil` se il file non è integro o è di un'altra versione.
    public static func stamp(of data: Data) -> SourceStamp? {
        data.withUnsafeBytes { header($0)?.stamp }
    }

    /// Quante occorrenze della ricerca ci sono nel testo di ricerca `data` (le stesse regole e la stessa scansione della
    /// ricerca nel libro); `nil` se il file non è integro o è di un'altra versione.
    public static func count(_ search: PreparedBookSearch, in data: Data) -> Int? {
        data.withUnsafeBytes { raw -> Int? in
            guard let h = header(raw) else { return nil }
            guard !search.isEmpty else { return 0 }
            let text = UnsafeBufferPointer(rebasing: raw.bindMemory(to: UInt8.self)[headerSize..<(headerSize + h.textCount)])
            var bounds = [Int32](repeating: 0, count: h.boundaryCount)
            for i in 0..<h.boundaryCount {
                bounds[i] = Int32(littleEndian: raw.loadUnaligned(fromByteOffset: h.boundariesOffset + 4 * i, as: Int32.self))
            }
            return bounds.withUnsafeBufferPointer { b in search.scan(text, boundaries: b) { _ in } }
        }
    }
}

// MARK: - I risultati di una ricerca nella libreria

/// Un libro con risultati.
public struct LibrarySearchBookResult: Equatable, Sendable {
    public let documentId: String
    public let title: String
    public let count: Int
    public init(documentId: String, title: String, count: Int) {
        self.documentId = documentId
        self.title = title
        self.count = count
    }
}

/// Ciò che una ricerca nella libreria restituisce: i libri con almeno un risultato e i libri che non si sono potuti
/// cercare (testo di ricerca non ancora pronto).
public struct LibrarySearchResult: Equatable, Sendable {
    public let query: String
    public let normalizedQuery: String
    public let options: BookSearchOptions
    /// In ordine alfabetico del titolo, come l'archivio.
    public let books: [LibrarySearchBookResult]
    /// Quanti libri non hanno ancora un testo di ricerca valido.
    public let notReady: Int
    public init(query: String, normalizedQuery: String, options: BookSearchOptions, books: [LibrarySearchBookResult], notReady: Int) {
        self.query = query
        self.normalizedQuery = normalizedQuery
        self.options = options
        self.books = books
        self.notReady = notReady
    }
    public var totalCount: Int { books.reduce(0) { $0 + $1.count } }
    public var isEmptyQuery: Bool { normalizedQuery.isEmpty }
}

/// La ricerca nella libreria, indipendente da dove stanno i file: per ogni libro, chi chiama dà il testo di ricerca
/// (mappato) o `nil` se non c'è o non vale per la lettura attuale.
public enum LibrarySearch {
    public static func run(_ query: String, options: BookSearchOptions,
                           books: [(documentId: String, title: String)],
                           searchText: (String) -> Data?) -> LibrarySearchResult {
        let prepared = PreparedBookSearch(query, options: options)
        guard !prepared.isEmpty else {
            return LibrarySearchResult(query: prepared.query, normalizedQuery: "", options: options, books: [], notReady: 0)
        }
        var found: [LibrarySearchBookResult] = []
        var notReady = 0
        for book in books {
            // Un libro alla volta: il file mappato si lascia andare alla fine di ogni giro.
            let n: Int? = autoreleasepool {
                guard let data = searchText(book.documentId) else { return nil }
                return LibrarySearchText.count(prepared, in: data)
            }
            guard let n else { notReady += 1; continue }
            if n > 0 { found.append(LibrarySearchBookResult(documentId: book.documentId, title: book.title, count: n)) }
        }
        return LibrarySearchResult(query: prepared.query, normalizedQuery: prepared.normalizedQuery, options: options,
                                   books: found, notReady: notReady)
    }
}

// MARK: - Le frasi della ricerca nella libreria

extension BookSearchWording {
    /// La frase del riassunto, detta subito dopo la ricerca: quanti libri e quanti risultati in tutto, o perché nessuno.
    public static func librarySummary(_ r: LibrarySearchResult) -> String {
        if r.isEmptyQuery { return "Scrivi una parola o una frase da cercare nel testo dei libri." }
        let q = "«\(r.query)»"
        var s: String
        switch (r.books.count, r.totalCount) {
        case (0, _):
            s = "Nel testo dei libri nessun risultato per \(q)."
            if r.notReady == 0 { s += " " + librarySuggestion(r) }
        case (1, 1):
            s = "Un libro, un risultato per \(q)."
        case (1, let t):
            s = "Un libro, \(number(t)) risultati in tutto per \(q)."
        case (let b, let t):
            s = "\(number(b)) libri, \(number(t)) risultati in tutto per \(q)."
        }
        if r.notReady == 1 {
            s += " Un libro non si è potuto cercare: il suo testo di ricerca non è ancora pronto."
        } else if r.notReady > 1 {
            s += " \(number(r.notReady)) libri non si sono potuti cercare: il loro testo di ricerca non è ancora pronto."
        }
        return s
    }

    /// Il suggerimento per zero risultati nella libreria (le stesse regole della ricerca nel libro).
    static func librarySuggestion(_ r: LibrarySearchResult) -> String {
        suggestion(BookSearchResult.empty(query: r.query, options: r.options).withNormalized(r.normalizedQuery))
    }

    /// La frase di una riga di libro: il titolo e quanti risultati.
    public static func libraryBookRow(title: String, count: Int) -> String {
        count == 1 ? "\(title), un risultato" : "\(title), \(number(count)) risultati"
    }
}

extension BookSearchResult {
    /// Un risultato vuoto che porta la ricerca normalizzata (per il suggerimento).
    func withNormalized(_ normalized: String) -> BookSearchResult {
        BookSearchResult(query: query, normalizedQuery: normalized, options: options, totalCount: 0, hits: [], elementIndices: [])
    }
}
