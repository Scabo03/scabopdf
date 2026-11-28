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
//  ── Formato (versione 2, little-endian; la 1 aveva lo stesso formato e le regole dei richiami di prima) ───────────────────────────────────────────────────────────────────
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
    /// 2 (giro «rifiniture e cure per capacità», build 64): i confini dei richiami seguono i legami nuovi fra nota e richiamo
    /// (note di chiusura; richiamo lontano dalla fine del pezzo o attaccato a un anno). I testi di versione 1 si riscrivono
    /// in sottofondo dalla cache, senza rielaborare il libro.
    public static let formatVersion: UInt32 = 2
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

    /// Quanti byte di testo normalizzato porta il file (la lunghezza del libro per il peso delle parole); `nil` se non vale.
    public static func textByteCount(of data: Data) -> Int? {
        data.withUnsafeBytes { header($0)?.textCount }
    }
}

// MARK: - I risultati di una ricerca nella libreria

/// Un libro con risultati: occorrenze esatte, o (ricerca di più parole) le parole cercate che vi pesano.
public struct LibrarySearchBookResult: Equatable, Sendable {
    public let documentId: String
    public let title: String
    /// Le occorrenze esatte (0 per un libro che ha solo le parole: ricerca di più parole, giro «la ricerca»).
    public let count: Int
    /// Il peso delle parole della ricerca nel libro (BM25 sui libri), 0 per una ricerca di una parola.
    public let wordScore: Double
    public init(documentId: String, title: String, count: Int, wordScore: Double = 0) {
        self.documentId = documentId
        self.title = title
        self.count = count
        self.wordScore = wordScore
    }
}

/// Ciò che una ricerca nella libreria restituisce: i libri con almeno un risultato e i libri che non si sono potuti
/// cercare (testo di ricerca non ancora pronto).
public struct LibrarySearchResult: Equatable, Sendable {
    public let query: String
    public let normalizedQuery: String
    public let options: BookSearchOptions
    /// Una parola: i libri con occorrenze, in ordine alfabetico del titolo, come l'archivio. Più parole (`byWords`): i libri
    /// con occorrenze e i più pertinenti fra quelli che hanno solo le parole, in ordine di peso delle parole.
    public let books: [LibrarySearchBookResult]
    /// Quanti libri non hanno ancora un testo di ricerca valido.
    public let notReady: Int
    /// Vero se i libri sono in ordine di peso delle parole (ricerca di almeno due parole).
    public let byWords: Bool
    /// L'ordine scelto nelle impostazioni della ricerca (con `byWords`): per pertinenza, o prima i libri con la frase intera.
    public let order: SearchSettings.LibraryOrder
    public init(query: String, normalizedQuery: String, options: BookSearchOptions, books: [LibrarySearchBookResult], notReady: Int,
                byWords: Bool = false, order: SearchSettings.LibraryOrder = .relevance) {
        self.byWords = byWords
        self.order = order
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
    /// Quanti libri senza la frase intera si danno al più, i più pertinenti (giro «la ricerca»).
    public static let wordOnlyBookLimit = 10

    /// `order` (impostazioni della ricerca): per pertinenza (di serie) i libri per peso delle parole; «prima la frase esatta» prima i
    /// libri che hanno la frase intera, poi gli altri, ciascun gruppo per peso delle parole.
    public static func run(_ query: String, options: BookSearchOptions,
                           books: [(documentId: String, title: String)],
                           order: SearchSettings.LibraryOrder = .relevance,
                           searchText: (String) -> Data?) -> LibrarySearchResult {
        let prepared = PreparedBookSearch(query, options: options)
        guard !prepared.isEmpty else {
            return LibrarySearchResult(query: prepared.query, normalizedQuery: "", options: options, books: [], notReady: 0)
        }
        // Più parole: ogni parola si conta da sola («Parola intera», come le parole della ricerca nel libro).
        // Come nel libro: la ricerca per parole parte da due parole; contano quelle di almeno tre caratteri e i numeri.
        let terms = LibraryWordWeights.terms(prepared.normalizedQuery)
        let byWords = LibraryWordWeights.wordCount(prepared.normalizedQuery) >= 2 && !terms.isEmpty
        let termSearches = byWords ? terms.map { PreparedBookSearch($0, options: BookSearchOptions(wholeWord: true)) } : []
        var rows: [(book: (documentId: String, title: String), count: Int, tf: [Int], length: Int)] = []
        var notReady = 0
        for book in books {
            // Un libro alla volta: il file mappato si lascia andare alla fine di ogni giro.
            let r: (Int, [Int], Int)? = autoreleasepool {
                guard let data = searchText(book.documentId), let n = LibrarySearchText.count(prepared, in: data) else { return nil }
                let tf = termSearches.map { LibrarySearchText.count($0, in: data) ?? 0 }
                return (n, tf, LibrarySearchText.textByteCount(of: data) ?? 0)
            }
            guard let r else { notReady += 1; continue }
            rows.append((book, r.0, r.1, r.2))
        }
        let found: [LibrarySearchBookResult]
        if byWords {
            let scores = LibraryWordWeights.scores(tf: rows.map(\.tf), length: rows.map(\.length))
            var listed = rows.indices.filter { rows[$0].count > 0 || scores[$0] > 0 }
            listed.sort { scores[$0] != scores[$1] ? scores[$0] > scores[$1] : $0 < $1 }
            if order == .exactFirst {
                // Stabile: dentro ciascun gruppo resta l'ordine per peso delle parole.
                listed = listed.filter { rows[$0].count > 0 } + listed.filter { rows[$0].count == 0 }
            }
            var wordOnly = 0
            listed = listed.filter { k in
                guard rows[k].count == 0 else { return true }
                wordOnly += 1
                return wordOnly <= wordOnlyBookLimit
            }
            found = listed.map { k in
                LibrarySearchBookResult(documentId: rows[k].book.documentId, title: rows[k].book.title, count: rows[k].count,
                                        wordScore: scores[k])
            }
        } else {
            found = rows.filter { $0.count > 0 }.map {
                LibrarySearchBookResult(documentId: $0.book.documentId, title: $0.book.title, count: $0.count)
            }
        }
        return LibrarySearchResult(query: prepared.query, normalizedQuery: prepared.normalizedQuery, options: options,
                                   books: found, notReady: notReady, byWords: byWords, order: order)
    }
}

/// Il peso delle parole di una ricerca nei libri (giro «la ricerca», LAYER2 § 12.16): BM25 dove il documento è il libro intero
/// (k1 1,2, b 0,75; la lunghezza è quella del testo normalizzato in byte; l'IDF sui libri cercati). I libri senza la frase intera
/// sono al più `LibrarySearch.wordOnlyBookLimit`, i più pesanti. Nessun filtro della parola che distingue, a differenza del libro:
/// in una libreria omogenea una parola presente in più di metà dei libri distingue ancora per frequenza (sul banco il filtro
/// toglieva il libro giusto dal primo posto a 0,04 delle domande). Il testo di ricerca di oggi basta: nessun formato nuovo.
enum LibraryWordWeights {
    /// Quanti caratteri deve avere almeno una parola per contare nella libreria (i numeri contano sempre).
    static var minimumLetters = 3

    /// Le parole distinte della ricerca normalizzata (sequenze di lettere e cifre), in ordine. Nella libreria contano le parole
    /// di almeno `minimumLetters` caratteri e quelle con una cifra: «e», «di», «il» sono in tutti i libri (non pesano) e ognuna
    /// costerebbe una scansione intera di ogni libro.
    static func terms(_ normalized: String) -> [String] {
        var out: [String] = [], word = ""
        for u in normalized.unicodeScalars + [" "] {
            if SearchNormalizer.isWordScalar(u.value) { word.unicodeScalars.append(u); continue }
            let counts = word.unicodeScalars.count >= minimumLetters || word.unicodeScalars.contains { $0.properties.numericType != nil }
            if !word.isEmpty, counts, !out.contains(word) { out.append(word) }
            word = ""
        }
        return out
    }

    /// Quante parole (di ogni lunghezza) ha la ricerca normalizzata.
    static func wordCount(_ normalized: String) -> Int {
        normalized.split(whereSeparator: { !$0.unicodeScalars.allSatisfy { SearchNormalizer.isWordScalar($0.value) } }).count
    }

    /// Per libro, il punteggio. `tf[libro][parola]`, `length[libro]`.
    static func scores(tf: [[Int]], length: [Int]) -> [Double] {
        let n = Double(tf.count)
        guard n > 0, let width = tf.first?.count else { return [] }
        let average = max(1, Double(length.reduce(0, +)) / n)
        let idf = (0..<width).map { t -> Double in
            let df = Double(tf.filter { $0[t] > 0 }.count)
            return log(1 + (n - df + 0.5) / (df + 0.5))
        }
        let k1 = BookWordIndex.k1, b = BookWordIndex.b
        return tf.indices.map { i in
            var s = 0.0
            for t in 0..<width where tf[i][t] > 0 {
                let f = Double(tf[i][t])
                s += idf[t] * f * (k1 + 1) / (f + k1 * (1 - b + b * Double(length[i]) / average))
            }
            return s
        }
    }
}

// MARK: - Le frasi della ricerca nella libreria

extension BookSearchWording {
    /// La frase del riassunto, detta subito dopo la ricerca: quanti libri e quanti risultati in tutto, o perché nessuno.
    public static func librarySummary(_ r: LibrarySearchResult) -> String {
        if r.isEmptyQuery { return "Scrivi una parola o una frase da cercare nel testo dei libri." }
        let q = "«\(r.query)»"
        var s: String
        if r.byWords, !r.books.isEmpty {
            let withPhrase = r.books.filter { $0.count > 0 }.count
            let results = r.totalCount == 1 ? "un risultato" : "\(number(r.totalCount)) risultati"
            if r.books.count == 1 {
                s = "Un libro con le parole di \(q)" + (withPhrase == 1 ? ", e con la frase intera: \(results)." : "; la frase intera non c'è.")
            } else {
                s = "\(number(r.books.count)) libri con le parole di \(q)"
                if r.order == .exactFirst && withPhrase > 0 && withPhrase < r.books.count {
                    // «Prima la frase esatta»: i gruppi detti una volta, col numero dei risultati della frase.
                    let times = r.totalCount == 1 ? "una volta" : "\(number(r.totalCount)) volte"
                    s += withPhrase == 1
                        ? ": prima quello con la frase intera, che la contiene \(times), poi gli altri, i più pertinenti per primi."
                        : ": prima i \(number(withPhrase)) con la frase intera, \(results) in tutto, poi gli altri; in ciascun gruppo i "
                            + "più pertinenti per primi."
                } else {
                    s += ", i più pertinenti per primi."
                    switch withPhrase {
                    case 0: s += " La frase intera non c'è in nessun libro."
                    case 1: s += " In uno c'è anche la frase intera: \(results)."
                    default: s += " In \(number(withPhrase)) c'è anche la frase intera: \(results) in tutto."
                    }
                }
            }
        } else {
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
        if count == 0 { return "\(title), nessun risultato esatto" }
        return count == 1 ? "\(title), un risultato" : "\(title), \(number(count)) risultati"
    }
}

extension BookSearchResult {
    /// Un risultato vuoto che porta la ricerca normalizzata (per il suggerimento).
    func withNormalized(_ normalized: String) -> BookSearchResult {
        BookSearchResult(query: query, normalizedQuery: normalized, options: options, totalCount: 0, hits: [], elementIndices: [])
    }
}
