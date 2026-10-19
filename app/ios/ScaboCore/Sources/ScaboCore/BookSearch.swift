//
//  BookSearch.swift
//  ScaboCore
//
//  RICERCA DENTRO IL TESTO DEL LIBRO APERTO (LAYER2_PRODUCT_DECISIONS § 13.3; giro «ricerca nel libro», 2026-10-19).
//  Solo Foundation: la stessa logica servirà la lettura sul Mac; la presentazione (schermata dei risultati, rotore,
//  tasti) sta nell'app.
//
//  ── Che cosa si cerca ────────────────────────────────────────────────────────────────────────────────────────
//
//  Il testo della LETTURA, cioè ciò che VoiceOver legge, non lo strato di testo del PDF: i segmenti del flusso di Lettura
//  Continua (corpo, titoli, note e pezzi delle note frazionate, testi normativi), con le sillabazioni già ricomposte dalla
//  catena. Restano fuori i ruoli di sola presentazione — `VISUAL_RESOURCE` (l'annuncio di una tabella o figura: il testo
//  della regione resta comunque nel flusso, subito dopo) e `SECTION_DIVIDER` (contenitore sintetico degli atti AKN) — e ciò
//  che l'app aggiunge a voce (intro acustici, rinfresco di memoria prima delle note differite: testo RIPETUTO).
//
//  Il testo si dispone in FLUSSI. Il flusso del CORPO: tutti i segmenti che non sono note, nell'ordine di lettura, uniti da
//  uno spazio — una frase a cavallo di due blocchi dello stesso paragrafo, o di un salto di pagina ricucito, si trova; una
//  nota letta in mezzo al corpo non lo spezza. Un flusso per ogni NOTA: la nota (`NOTE`, `EDITORIAL_NOTE`) e i suoi pezzi
//  di seguito (`NOTE_CONTINUATION`), uniti da uno spazio — una frase a cavallo di due pezzi si trova. Una frase non
//  attraversa mai il confine fra corpo e nota né fra due note (un byte 0 li separa nel buffer, e nessuna ricerca lo contiene).
//
//  ── Normalizzazione (uguale per il testo e per la ricerca) ─────────────────────────────────────────────────────
//
//  Per ogni carattere (scalare Unicode): apostrofi tipografici → «'»; virgolette tipografiche e caporali → «"»; trattini e
//  lineette → «-»; spazi di ogni genere (Unicode White_Space) → uno spazio, e gli spazi di fila diventano uno solo, tolti in
//  testa e in coda; caratteri di formato e di controllo (trattino morbido, spazi di larghezza zero, marcatori di direzione)
//  → niente; ogni altro carattere: scomposizione di compatibilità (NFKD: «ﬁ» → «fi», «²» → «2»), via i segni diacritici,
//  minuscolo, «ß» → «ss», «ς» → «σ». Quindi maiuscole e minuscole, lettere accentate e non accentate, apostrofi e virgolette
//  tipografiche e diritte sono uguali. Le occorrenze si contano da sinistra a destra senza sovrapporsi.
//
//  «Parola intera»: il risultato non deve avere una lettera o una cifra subito prima né subito dopo (il controllo vale sui
//  lati della ricerca che cominciano o finiscono con una lettera o una cifra; un apostrofo, un trattino, una parentesi sono
//  confini: «obbligazione» intera si trova in «l'obbligazione»). Un candidato scartato non consuma testo.
//
//  ── Memoria e tempi ──────────────────────────────────────────────────────────────────────────────────────────
//
//  Il `BookSearchCorpus` è il testo normalizzato del libro in UN buffer di byte UTF-8 (in pratica quasi tutto ASCII) più
//  quattro numeri per segmento: si costruisce in una passata quando serve (alla prima ricerca nel libro aperto) e si
//  scorre con `memchr`/`memcmp`. Misure del giro nel referto § 5.
//

import Foundation

// MARK: - Opzioni e risultati

/// Opzioni della ricerca nel libro.
public struct BookSearchOptions: Equatable, Sendable, Codable {
    /// Solo occorrenze che non hanno una lettera o una cifra subito prima o subito dopo.
    public var wholeWord: Bool
    public init(wholeWord: Bool = false) { self.wholeWord = wholeWord }
}

/// Un'occorrenza trovata.
public struct BookSearchHit: Equatable, Sendable {
    /// Indice, nel flusso di Lettura Continua, del segmento dove l'occorrenza comincia: l'elemento da raggiungere.
    public let segmentIndex: Int
    /// Indice del segmento dove l'occorrenza finisce (uguale a `segmentIndex` se sta in un elemento solo).
    public let endSegmentIndex: Int
    /// Vero se l'occorrenza è nel testo di una nota.
    public let isInNote: Bool
    /// Inizio dell'occorrenza (in byte del testo normalizzato) dentro il segmento d'inizio.
    public let startInSegment: Int
    /// Lunghezza dell'occorrenza in byte del testo normalizzato.
    public let length: Int
}

/// Ciò che una ricerca restituisce: il conteggio esatto e, in ordine di lettura, le occorrenze (al più `limit`).
public struct BookSearchResult: Equatable, Sendable {
    /// La ricerca come l'ha scritta l'utente (senza spazi in testa e in coda).
    public let query: String
    /// La ricerca normalizzata (vuota: nulla da cercare).
    public let normalizedQuery: String
    public let options: BookSearchOptions
    /// Quante occorrenze ci sono in tutto.
    public let totalCount: Int
    /// Le occorrenze in ordine di lettura (le prime `limit`).
    public let hits: [BookSearchHit]
    /// Gli elementi (indici di segmento) dove comincia almeno un'occorrenza, in ordine: le fermate del rotore e dei tasti.
    public let elementIndices: [Int]
    /// Le occorrenze che finiscono in un segmento dopo quello d'inizio (poche: le frasi che attraversano un confine), in
    /// ordine di lettura: servono a `hits(touching:)`, perché dentro una di esse, nell'ordine dei segmenti, possono
    /// cadere le occorrenze di altri flussi (una nota letta in mezzo al corpo), anche molte.
    private let spanningHits: [BookSearchHit]

    init(query: String, normalizedQuery: String, options: BookSearchOptions, totalCount: Int, hits: [BookSearchHit],
         elementIndices: [Int]) {
        self.query = query
        self.normalizedQuery = normalizedQuery
        self.options = options
        self.totalCount = totalCount
        self.hits = hits
        self.elementIndices = elementIndices
        self.spanningHits = hits.filter { $0.endSegmentIndex > $0.segmentIndex }
    }

    public var isTruncated: Bool { hits.count < totalCount }
    public var isEmptyQuery: Bool { normalizedQuery.isEmpty }

    public static func empty(query: String, options: BookSearchOptions) -> BookSearchResult {
        BookSearchResult(query: query, normalizedQuery: "", options: options, totalCount: 0, hits: [], elementIndices: [])
    }

    /// I numeri d'ordine (da 1) delle occorrenze che cominciano nell'elemento `segmentIndex`, o `nil` se nessuna.
    public func ordinals(inElement segmentIndex: Int) -> ClosedRange<Int>? {
        guard let first = Self.lowerBound(hits, segmentIndex) , first < hits.count,
              hits[first].segmentIndex == segmentIndex else { return nil }
        var last = first
        while last + 1 < hits.count, hits[last + 1].segmentIndex == segmentIndex { last += 1 }
        return (first + 1)...(last + 1)
    }

    /// L'elemento con un'occorrenza successivo (`forward`) o precedente a `current`; `nil` se non ce n'è.
    public func adjacentElement(from current: Int, forward: Bool) -> Int? {
        if forward {
            var lo = 0, hi = elementIndices.count
            while lo < hi { let mid = (lo + hi) / 2; if elementIndices[mid] <= current { lo = mid + 1 } else { hi = mid } }
            return lo < elementIndices.count ? elementIndices[lo] : nil
        }
        var lo = 0, hi = elementIndices.count
        while lo < hi { let mid = (lo + hi) / 2; if elementIndices[mid] < current { lo = mid + 1 } else { hi = mid } }
        return lo > 0 ? elementIndices[lo - 1] : nil
    }

    /// Le occorrenze che possono toccare il segmento `segmentIndex`, in ordine di lettura: quelle cominciate in un
    /// segmento precedente e finite in questo o dopo, poi quelle che vi cominciano. Una frase del corpo che scavalca una
    /// nota letta in mezzo è fra queste anche per la nota, ma non vi lascia evidenze (`highlightRanges` la scarta: il
    /// suo testo non è nel flusso della nota).
    public func hits(touching segmentIndex: Int) -> [BookSearchHit] {
        var out = spanningHits.filter { $0.segmentIndex < segmentIndex && $0.endSegmentIndex >= segmentIndex }
        guard let lo = Self.lowerBound(hits, segmentIndex) else { return out }
        var j = lo
        while j < hits.count, hits[j].segmentIndex == segmentIndex { out.append(hits[j]); j += 1 }
        return out
    }

    /// Il primo indice di `hits` con `segmentIndex >= target`.
    private static func lowerBound(_ hits: [BookSearchHit], _ target: Int) -> Int? {
        var lo = 0, hi = hits.count
        while lo < hi { let mid = (lo + hi) / 2; if hits[mid].segmentIndex < target { lo = mid + 1 } else { hi = mid } }
        return lo
    }
}

// MARK: - Normalizzazione

/// La normalizzazione condivisa da testo e ricerca (vedi l'intestazione del file).
public enum SearchNormalizer {
    static let apostrophes: Set<UInt32> = [
        0x0060, 0x00B4, 0x02B9, 0x02BC, 0x2018, 0x2019, 0x201A, 0x201B, 0x2032, 0x2035, 0x2039, 0x203A,
    ]
    static let quotes: Set<UInt32> = [0x00AB, 0x00BB, 0x201C, 0x201D, 0x201E, 0x201F, 0x2033, 0x2036, 0x301D, 0x301E]
    static let dashes: Set<UInt32> = [0x2010, 0x2011, 0x2012, 0x2013, 0x2014, 0x2015, 0x2212, 0xFE58, 0xFE63, 0xFF0D]
    /// Unicode White_Space.
    static let whitespace: Set<UInt32> = Set([0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x20, 0x85, 0xA0, 0x1680, 0x2028, 0x2029,
                                              0x202F, 0x205F, 0x3000] + Array(0x2000...0x200A))

    /// La ricerca (o un testo qualsiasi) normalizzata, come stringa.
    public static func normalize(_ text: String) -> String {
        String(decoding: normalizedBytes(text), as: UTF8.self)
    }

    /// La ricerca normalizzata in byte UTF-8.
    static func normalizedBytes(_ text: String) -> [UInt8] {
        var cache: [UInt32: [UInt8]] = [:]
        var sink = PlainSink()
        feed(text, cache: &cache, sink: &sink)
        return sink.bytes
    }

    /// Normalizzazione con l'ORIGINE di ogni byte: per il byte `k`, l'intervallo (in unità UTF-16 del testo originale)
    /// del carattere da cui viene. Stessi byte di `normalizedBytes`.
    static func normalizedBytesTracking(_ text: String) -> (bytes: [UInt8], originStart: [Int32], originEnd: [Int32]) {
        var cache: [UInt32: [UInt8]] = [:]
        var sink = TrackingSink()
        feed(text, cache: &cache, sink: &sink)
        return (sink.bytes, sink.originStart, sink.originEnd)
    }

    /// Mappa di un carattere non ASCII: i byte normalizzati (0x20 per uno spazio), vuoto se il carattere sparisce.
    static func mapNonASCII(_ v: UInt32) -> [UInt8] {
        guard let s = Unicode.Scalar(v) else { return [] }
        if apostrophes.contains(v) { return [0x27] }
        if quotes.contains(v) { return [0x22] }
        if dashes.contains(v) { return [0x2D] }
        if whitespace.contains(v) { return [0x20] }
        switch s.properties.generalCategory {
        case .format, .control: return []
        default: break
        }
        var out: [UInt8] = []
        for t in String(s).decomposedStringWithCompatibilityMapping.unicodeScalars {
            if isCombining(t) { continue }
            let tv = t.value
            if whitespace.contains(tv) { out.append(0x20); continue }
            if apostrophes.contains(tv) { out.append(0x27); continue }
            if quotes.contains(tv) { out.append(0x22); continue }
            if dashes.contains(tv) { out.append(0x2D); continue }
            if tv < 0x80 {
                if let b = mapASCII(UInt8(tv)) { out.append(b) }
                continue
            }
            switch t.properties.generalCategory {
            case .format, .control: continue
            default: break
            }
            for u in String(t).lowercased().unicodeScalars {
                if isCombining(u) { continue }
                switch u.value {
                case 0xDF: out.append(0x73); out.append(0x73)  // ß → ss
                case 0x3C2: out.append(contentsOf: Array("σ".utf8))  // ς → σ
                default:
                    if u.value < 0x80 { if let b = mapASCII(UInt8(u.value)) { out.append(b) } } else { out.append(contentsOf: Array(String(u).utf8)) }
                }
            }
        }
        return out
    }

    /// Mappa di un byte ASCII: 0x20 per uno spazio, `nil` se sparisce (controlli).
    @inline(__always)
    static func mapASCII(_ b: UInt8) -> UInt8? {
        switch b {
        case 0x41...0x5A: return b | 0x20
        case 0x09...0x0D, 0x20: return 0x20
        case 0x60: return 0x27
        case 0x00...0x08, 0x0E...0x1F, 0x7F: return nil
        default: return b
        }
    }

    static func isCombining(_ s: Unicode.Scalar) -> Bool {
        switch s.properties.generalCategory {
        case .nonspacingMark, .spacingMark, .enclosingMark: return true
        default: return false
        }
    }

    /// Vero se lo scalare è una lettera o una cifra (il confine della «parola intera»).
    static func isWordScalar(_ v: UInt32) -> Bool {
        if v < 0x80 { return (v >= 0x61 && v <= 0x7A) || (v >= 0x30 && v <= 0x39) || (v >= 0x41 && v <= 0x5A) }
        guard let s = Unicode.Scalar(v) else { return false }
        switch s.properties.generalCategory {
        case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter,
             .decimalNumber, .letterNumber, .otherNumber:
            return true
        default:
            return false
        }
    }

    /// Passa il testo al ricevitore, carattere per carattere (scansione UTF-8 a mano: veloce sui volumi grandi).
    static func feed<S: NormalizedSink>(_ text: String, cache: inout [UInt32: [UInt8]], sink: inout S) {
        var copy = text
        copy.withUTF8 { buf in
            let n = buf.count
            var i = 0
            var utf16 = 0
            while i < n {
                let b0 = buf[i]
                if b0 < 0x80 {
                    if let m = mapASCII(b0) {
                        if m == 0x20 { sink.space(origin: utf16, end: utf16 + 1) } else { sink.byte(m, origin: utf16, end: utf16 + 1) }
                    }
                    i += 1
                    utf16 += 1
                    continue
                }
                // Decodifica a mano di uno scalare UTF-8 (il testo di una Swift String è UTF-8 valido).
                var v: UInt32
                var len: Int
                if b0 & 0xE0 == 0xC0 { v = UInt32(b0 & 0x1F); len = 2 }
                else if b0 & 0xF0 == 0xE0 { v = UInt32(b0 & 0x0F); len = 3 }
                else { v = UInt32(b0 & 0x07); len = 4 }
                if i + len > n { break }
                for k in 1..<len { v = (v << 6) | UInt32(buf[i + k] & 0x3F) }
                let units = len == 4 ? 2 : 1
                let mapped: [UInt8]
                if let c = cache[v] { mapped = c } else { mapped = mapNonASCII(v); cache[v] = mapped }
                for m in mapped {
                    if m == 0x20 { sink.space(origin: utf16, end: utf16 + units) } else { sink.byte(m, origin: utf16, end: utf16 + units) }
                }
                i += len
                utf16 += units
            }
        }
        sink.finish()
    }
}

/// Il ricevitore dei byte normalizzati: raccoglie, comprime gli spazi di fila, toglie quelli in testa e in coda.
protocol NormalizedSink {
    mutating func space(origin: Int, end: Int)
    mutating func byte(_ b: UInt8, origin: Int, end: Int)
    mutating func finish()
}

struct PlainSink: NormalizedSink {
    var bytes: [UInt8] = []
    var pendingSpace = false
    @inline(__always) mutating func space(origin: Int, end: Int) { pendingSpace = true }
    @inline(__always) mutating func byte(_ b: UInt8, origin: Int, end: Int) {
        if pendingSpace { if !bytes.isEmpty { bytes.append(0x20) }; pendingSpace = false }
        bytes.append(b)
    }
    mutating func finish() { pendingSpace = false }
}

struct TrackingSink: NormalizedSink {
    var bytes: [UInt8] = []
    var originStart: [Int32] = []
    var originEnd: [Int32] = []
    var pendingSpace = false
    var pendingStart = 0, pendingEnd = 0
    mutating func space(origin: Int, end: Int) {
        if !pendingSpace { pendingSpace = true; pendingStart = origin; pendingEnd = end }
    }
    mutating func byte(_ b: UInt8, origin: Int, end: Int) {
        if pendingSpace {
            if !bytes.isEmpty { bytes.append(0x20); originStart.append(Int32(pendingStart)); originEnd.append(Int32(pendingEnd)) }
            pendingSpace = false
        }
        bytes.append(b)
        originStart.append(Int32(origin))
        originEnd.append(Int32(end))
    }
    mutating func finish() { pendingSpace = false }
}

// MARK: - Il testo del libro, pronto per cercare

/// I ruoli che non si cercano (sola presentazione, vedi l'intestazione).
let BOOK_SEARCH_EXCLUDED_ROLES: Set<String> = [VISUAL_RESOURCE_ROLE, SECTION_DIVIDER_ROLE]

/// Ruolo di nota (testa o pezzo).
func isBookSearchNoteRole(_ role: String) -> Bool {
    role == SemanticCategory.NOTE.rawValue || role == SemanticCategory.EDITORIAL_NOTE.rawValue
        || role == SemanticCategory.NOTE_CONTINUATION.rawValue
}

/// Ruolo di titolo per «la sezione in cui sta» un risultato (gli stessi del rotore Intestazioni).
func isBookSearchHeadingRole(_ role: String) -> Bool {
    role.hasPrefix("HEADING_") || role == SemanticCategory.ARTICLE_HEADER.rawValue
}

/// Il testo normalizzato del libro aperto: un buffer di byte e la posizione di ogni segmento. Immutabile dopo la
/// costruzione, quindi si può usare da un'altra coda.
public final class BookSearchCorpus: @unchecked Sendable {
    /// Numero di segmenti del flusso da cui è costruito.
    public let segmentCount: Int
    /// Byte normalizzati: il flusso del corpo, poi un flusso per nota, separati da un byte 0.
    let buffer: [UInt8]
    /// Per segmento: inizio nel buffer (-1 se il segmento non porta testo cercabile) e lunghezza in byte.
    let segmentStart: [Int32]
    let segmentLength: [Int32]
    /// Vero per i segmenti di nota.
    let segmentIsNote: [Bool]
    /// Per segmento: l'indice del titolo più vicino all'indietro (compreso il segmento stesso), -1 se nessuno.
    let headingAtOrBefore: [Int32]
    /// Inizi dei segmenti nell'ordine del buffer (crescenti) e i loro indici, per risalire da un byte al segmento.
    private let orderedStarts: [Int32]
    private let orderedSegments: [Int32]

    /// Byte normalizzati in tutto (per le misure).
    public var normalizedByteCount: Int { buffer.count }

    public init(segments: [ContentSegment]) {
        segmentCount = segments.count
        var buffer: [UInt8] = []
        buffer.reserveCapacity(segments.reduce(0) { $0 + $1.text.utf8.count } + segments.count + 16)
        var start = [Int32](repeating: -1, count: segments.count)
        var length = [Int32](repeating: 0, count: segments.count)
        var isNote = [Bool](repeating: false, count: segments.count)
        var heading = [Int32](repeating: -1, count: segments.count)
        var oStarts: [Int32] = []
        var oSegs: [Int32] = []
        oStarts.reserveCapacity(segments.count)
        oSegs.reserveCapacity(segments.count)
        var cache: [UInt32: [UInt8]] = [:]

        func normalized(_ i: Int) -> [UInt8] {
            var sink = PlainSink()
            SearchNormalizer.feed(segments[i].text, cache: &cache, sink: &sink)
            return sink.bytes
        }

        // Titolo più vicino all'indietro.
        var lastHeading: Int32 = -1
        for (i, s) in segments.enumerated() {
            if isBookSearchHeadingRole(s.role) { lastHeading = Int32(i) }
            heading[i] = lastHeading
            isNote[i] = isBookSearchNoteRole(s.role)
        }

        // 1. Il flusso del corpo.
        var bodyHasText = false
        for (i, s) in segments.enumerated() where !isNote[i] && !BOOK_SEARCH_EXCLUDED_ROLES.contains(s.role) {
            let bytes = normalized(i)
            guard !bytes.isEmpty else { continue }
            if bodyHasText { buffer.append(0x20) }
            start[i] = Int32(buffer.count)
            length[i] = Int32(bytes.count)
            oStarts.append(Int32(buffer.count))
            oSegs.append(Int32(i))
            buffer.append(contentsOf: bytes)
            bodyHasText = true
        }
        buffer.append(0)

        // 2. Un flusso per nota: la testa e i pezzi di seguito (le risorse visive in mezzo non interrompono).
        var openNote = false
        var noteHasText = false
        for (i, s) in segments.enumerated() {
            if BOOK_SEARCH_EXCLUDED_ROLES.contains(s.role) { continue }
            guard isNote[i] else {
                if openNote { buffer.append(0); openNote = false }
                continue
            }
            let continuation = s.role == SemanticCategory.NOTE_CONTINUATION.rawValue
            if !continuation || !openNote {
                if openNote { buffer.append(0) }
                openNote = true
                noteHasText = false
            }
            let bytes = normalized(i)
            guard !bytes.isEmpty else { continue }
            if noteHasText { buffer.append(0x20) }
            start[i] = Int32(buffer.count)
            length[i] = Int32(bytes.count)
            oStarts.append(Int32(buffer.count))
            oSegs.append(Int32(i))
            buffer.append(contentsOf: bytes)
            noteHasText = true
        }
        if openNote { buffer.append(0) }

        self.buffer = buffer
        self.segmentStart = start
        self.segmentLength = length
        self.segmentIsNote = isNote
        self.headingAtOrBefore = heading
        self.orderedStarts = oStarts
        self.orderedSegments = oSegs
    }

    /// Il segmento che contiene il byte `offset` del buffer (il più grande inizio ≤ offset).
    func segment(containingByte offset: Int) -> Int {
        var lo = 0, hi = orderedStarts.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if Int(orderedStarts[mid]) <= offset { lo = mid + 1 } else { hi = mid }
        }
        return lo > 0 ? Int(orderedSegments[lo - 1]) : 0
    }

    /// Quante occorrenze tenere al massimo nell'elenco (il conteggio resta esatto oltre).
    public static let defaultHitLimit = 50_000
    /// Quante posizioni raccogliere al massimo durante la scansione (memoria: 4 byte ciascuna).
    static let collectLimit = 2_000_000

    /// Cerca `query` in tutto il libro. Il conteggio è esatto; le occorrenze, in ordine di lettura, sono al più `limit`.
    public func search(_ query: String, options: BookSearchOptions = BookSearchOptions(),
                       limit: Int = BookSearchCorpus.defaultHitLimit) -> BookSearchResult {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let needle = SearchNormalizer.normalizedBytes(trimmed)
        guard !needle.isEmpty else { return .empty(query: trimmed, options: options) }
        let normalizedQuery = String(decoding: needle, as: UTF8.self)
        let checkLeft = options.wholeWord && SearchNormalizer.isWordScalar(Self.firstScalar(needle))
        let checkRight = options.wholeWord && SearchNormalizer.isWordScalar(Self.lastScalar(needle))
        var offsets: [Int32] = []
        var total = 0
        buffer.withUnsafeBufferPointer { hay in
            needle.withUnsafeBufferPointer { ndl in
                guard let h = hay.baseAddress, let q = ndl.baseAddress else { return }
                let n = hay.count, m = ndl.count
                guard m <= n else { return }
                let first = Int32(ndl[0])
                var i = 0
                while i <= n - m {
                    guard let p = memchr(h + i, first, n - m - i + 1) else { break }
                    let j = h.distance(to: p.assumingMemoryBound(to: UInt8.self))
                    if memcmp(h + j, q, m) == 0
                        && (!checkLeft || !Self.isWordBefore(hay, j))
                        && (!checkRight || !Self.isWordAt(hay, j + m)) {
                        total += 1
                        if offsets.count < Self.collectLimit { offsets.append(Int32(j)) }
                        i = j + m
                    } else {
                        i = j + 1
                    }
                }
            }
        }
        // Dal byte al segmento; ordine di lettura (le note seguono il corpo nel buffer, non nel flusso).
        var keyed: [(seg: Int32, off: Int32, end: Int32)] = []
        keyed.reserveCapacity(offsets.count)
        let m = needle.count
        for o in offsets {
            let s = segment(containingByte: Int(o))
            let e = segment(containingByte: Int(o) + m - 1)
            keyed.append((Int32(s), o - segmentStart[s], Int32(e)))
        }
        keyed.sort { $0.seg != $1.seg ? $0.seg < $1.seg : $0.off < $1.off }
        let kept = keyed.prefix(max(0, limit))
        let hits = kept.map { k in
            BookSearchHit(segmentIndex: Int(k.seg), endSegmentIndex: Int(k.end), isInNote: segmentIsNote[Int(k.seg)],
                          startInSegment: Int(k.off), length: m)
        }
        var elements: [Int] = []
        for h in hits where elements.last != h.segmentIndex { elements.append(h.segmentIndex) }
        return BookSearchResult(query: trimmed, normalizedQuery: normalizedQuery, options: options,
                                totalCount: total, hits: hits, elementIndices: elements)
    }

    // MARK: Confini di parola sul buffer

    static func firstScalar(_ b: [UInt8]) -> UInt32 { decode(b, at: 0) }

    static func lastScalar(_ b: [UInt8]) -> UInt32 {
        var k = b.count - 1
        while k > 0, b[k] & 0xC0 == 0x80 { k -= 1 }
        return decode(b, at: k)
    }

    static func decode(_ b: [UInt8], at i: Int) -> UInt32 {
        b.withUnsafeBufferPointer { decode($0, at: i) }
    }

    @inline(__always)
    static func decode(_ b: UnsafeBufferPointer<UInt8>, at i: Int) -> UInt32 {
        let b0 = b[i]
        if b0 < 0x80 { return UInt32(b0) }
        var v: UInt32, len: Int
        if b0 & 0xE0 == 0xC0 { v = UInt32(b0 & 0x1F); len = 2 }
        else if b0 & 0xF0 == 0xE0 { v = UInt32(b0 & 0x0F); len = 3 }
        else { v = UInt32(b0 & 0x07); len = 4 }
        guard i + len <= b.count else { return 0 }
        for k in 1..<len { v = (v << 6) | UInt32(b[i + k] & 0x3F) }
        return v
    }

    @inline(__always)
    static func isWordBefore(_ b: UnsafeBufferPointer<UInt8>, _ j: Int) -> Bool {
        guard j > 0 else { return false }
        var k = j - 1
        if b[k] < 0x80 { return SearchNormalizer.isWordScalar(UInt32(b[k])) }
        while k > 0, b[k] & 0xC0 == 0x80 { k -= 1 }
        return SearchNormalizer.isWordScalar(decode(b, at: k))
    }

    @inline(__always)
    static func isWordAt(_ b: UnsafeBufferPointer<UInt8>, _ k: Int) -> Bool {
        guard k < b.count else { return false }
        return SearchNormalizer.isWordScalar(decode(b, at: k))
    }

    // MARK: Da un'occorrenza al testo originale

    /// Il titolo (indice di segmento) della sezione in cui sta l'occorrenza, o `nil`.
    public func headingIndex(for hit: BookSearchHit) -> Int? {
        let h = headingAtOrBefore[hit.segmentIndex]
        return h >= 0 ? Int(h) : nil
    }

    /// L'intervallo (in unità UTF-16 di `text`) che corrisponde ai byte normalizzati `range` del segmento con quel testo.
    /// `range` è relativo all'inizio del segmento e viene ristretto alla sua lunghezza.
    public static func originalRange(ofNormalized range: Range<Int>, in text: String) -> NSRange? {
        let t = SearchNormalizer.normalizedBytesTracking(text)
        guard !t.bytes.isEmpty else { return nil }
        let lo = max(0, min(range.lowerBound, t.bytes.count - 1))
        let hi = max(lo + 1, min(range.upperBound, t.bytes.count))
        let s = Int(t.originStart[lo]), e = Int(t.originEnd[hi - 1])
        return NSRange(location: s, length: max(0, e - s))
    }

    /// Gli intervalli da evidenziare (unità UTF-16 del testo del segmento) per le occorrenze che toccano il segmento
    /// `segmentIndex`, compresa la parte che vi arriva da un'occorrenza cominciata prima.
    public func highlightRanges(forSegment segmentIndex: Int, text: String, hits: [BookSearchHit]) -> [NSRange] {
        guard segmentIndex >= 0, segmentIndex < segmentCount, segmentStart[segmentIndex] >= 0 else { return [] }
        let segStart = Int(segmentStart[segmentIndex]), segLen = Int(segmentLength[segmentIndex])
        var normalizedRanges: [Range<Int>] = []
        for h in hits where h.segmentIndex <= segmentIndex && h.endSegmentIndex >= segmentIndex {
            let absStart = Int(segmentStart[h.segmentIndex]) + h.startInSegment
            let lo = max(absStart, segStart) - segStart
            let hi = min(absStart + h.length, segStart + segLen) - segStart
            if hi > lo { normalizedRanges.append(lo..<hi) }
        }
        guard !normalizedRanges.isEmpty else { return [] }
        let t = SearchNormalizer.normalizedBytesTracking(text)
        guard t.bytes.count == segLen else { return [] }
        return normalizedRanges.map { r in
            let s = Int(t.originStart[r.lowerBound]), e = Int(t.originEnd[r.upperBound - 1])
            return NSRange(location: s, length: max(0, e - s))
        }
    }

    /// Un breve contesto attorno all'occorrenza, preso dal testo originale: qualche parola prima e dopo (con «…» dove si
    /// taglia), e l'intervallo dell'occorrenza dentro il contesto (per renderla visibile).
    public func snippet(for hit: BookSearchHit, segments: [ContentSegment], radius: Int = 60) -> (text: String, match: NSRange) {
        guard hit.segmentIndex < segments.count else { return ("", NSRange(location: 0, length: 0)) }
        let startText = segments[hit.segmentIndex].text as NSString
        let startLen = Int(segmentLength[hit.segmentIndex])
        let inFirst = min(hit.length, startLen - hit.startInSegment)
        guard let first = Self.originalRange(ofNormalized: hit.startInSegment..<(hit.startInSegment + max(1, inFirst)),
                                             in: startText as String) else { return ("", NSRange(location: 0, length: 0)) }
        var before = startText.substring(to: first.location)
        var matched = startText.substring(with: first)
        var after = startText.substring(from: first.location + first.length)
        // Un'occorrenza a cavallo: il resto sta all'inizio dei segmenti seguenti dello stesso flusso.
        if hit.endSegmentIndex != hit.segmentIndex, hit.endSegmentIndex < segments.count {
            var remaining = hit.length - inFirst - 1  // lo spazio fra i due segmenti
            var k = hit.segmentIndex + 1
            after = ""
            while k <= hit.endSegmentIndex, k < segments.count {
                guard segmentStart[k] >= 0, segmentIsNote[k] == segmentIsNote[hit.segmentIndex] else { k += 1; continue }
                let text = segments[k].text
                let len = Int(segmentLength[k])
                let take = min(remaining, len)
                if take > 0, let r = Self.originalRange(ofNormalized: 0..<take, in: text) {
                    let ns = text as NSString
                    matched += " " + ns.substring(with: r)
                    after = ns.substring(from: r.location + r.length)
                }
                remaining -= take + 1
                k += 1
            }
        }
        before = Self.tail(of: before, radius: radius)
        after = Self.head(of: after, radius: radius)
        let text = before + matched + after
        let match = NSRange(location: (before as NSString).length, length: (matched as NSString).length)
        return (text, match)
    }

    /// Le ultime parole di `s` entro `radius` caratteri, con «…» davanti se si taglia.
    static func tail(of s: String, radius: Int) -> String {
        let collapsed = s.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        guard collapsed.count > radius else { return collapsed }
        var cut = String(collapsed.suffix(radius))
        if let space = cut.firstIndex(of: " ") { cut = String(cut[cut.index(after: space)...]) }
        return "…" + cut
    }

    /// Le prime parole di `s` entro `radius` caratteri, con «…» in fondo se si taglia.
    static func head(of s: String, radius: Int) -> String {
        let collapsed = s.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        guard collapsed.count > radius else { return collapsed }
        var cut = String(collapsed.prefix(radius))
        if let space = cut.lastIndex(of: " ") { cut = String(cut[..<space]) }
        return cut + "…"
    }
}

// MARK: - Le frasi della ricerca (italiano piano, uguali per iPad, iPhone e Mac)

public enum BookSearchWording {
    private static let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.numberStyle = .decimal
        return f
    }()

    /// «12.345».
    public static func number(_ n: Int) -> String { numberFormatter.string(from: NSNumber(value: n)) ?? "\(n)" }

    /// La frase del conteggio, detta subito dopo la ricerca: quanti risultati, o perché nessuno e che cosa provare.
    public static func countSentence(_ r: BookSearchResult) -> String {
        if r.isEmptyQuery { return "Scrivi una parola o una frase da cercare nel libro." }
        let q = "«\(r.query)»"
        switch r.totalCount {
        case 0: return "Nessun risultato per \(q). " + suggestion(r)
        case 1: return "Un risultato per \(q)."
        default:
            var s = "\(number(r.totalCount)) risultati per \(q)."
            if r.isTruncated {
                s += " Qui sotto i primi \(number(r.hits.count)), in ordine di lettura: per restringere, aggiungi un'altra parola"
                s += r.options.wholeWord ? "." : " o scegli «Parola intera»."
            }
            return s
        }
    }

    /// Il suggerimento per zero risultati.
    public static func suggestion(_ r: BookSearchResult) -> String {
        if r.options.wholeWord {
            return "Prova a togliere «Parola intera»: così si trova anche dentro parole più lunghe."
        }
        if r.normalizedQuery.contains(" ") {
            return "Prova con meno parole, o con una parola sola: maiuscole, accenti e apostrofi non contano."
        }
        return "Prova con una parte della parola, o controlla come è scritta: maiuscole, accenti e apostrofi non contano."
    }

    /// Il valore dell'elemento della lettura che contiene risultati: «risultato 4 di 12», «risultati 4 e 5 di 12»,
    /// «risultati da 4 a 6 di 12».
    public static func positionValue(ordinals: ClosedRange<Int>, total: Int) -> String {
        let t = number(total)
        if ordinals.count == 1 { return "risultato \(number(ordinals.lowerBound)) di \(t)" }
        if ordinals.count == 2 { return "risultati \(number(ordinals.lowerBound)) e \(number(ordinals.upperBound)) di \(t)" }
        return "risultati da \(number(ordinals.lowerBound)) a \(number(ordinals.upperBound)) di \(t)"
    }

    /// Ciò che si dice quando non c'è un risultato dopo (o prima di) quello raggiunto. Con un elenco troncato (più di
    /// `defaultHitLimit` occorrenze) le fermate finiscono con le prime occorrenze: lo si dice, con il modo di arrivare
    /// alle altre, invece di «era l'ultimo».
    public static func noMoreResults(forward: Bool, result: BookSearchResult) -> String {
        guard forward else { return "Non ci sono altri risultati prima di questo: era il primo." }
        guard result.isTruncated else { return "Non ci sono altri risultati dopo questo: era l'ultimo." }
        return "Non ci sono altri risultati fra i primi \(number(result.hits.count)), su \(number(result.totalCount)) in "
            + "tutto: per arrivare agli altri, restringi la ricerca, per esempio con più parole o con «Parola intera»."
    }

    /// Il numero di una nota, dalle cifre in testa al suo testo («12 Cfr. …» → «12»), o `nil`.
    public static func noteNumber(_ noteText: String) -> String? {
        let head = noteText.drop(while: { $0 == " " || $0 == "(" || $0 == "[" })
        let digits = head.prefix(while: { $0.isASCII && $0.isNumber })
        return digits.isEmpty || digits.count > 4 ? nil : String(digits)
    }

    /// Il titolo della sezione accorciato per una riga di risultato (entro `limit` caratteri, a fine parola).
    public static func sectionTitle(_ heading: String, limit: Int = 90) -> String {
        let collapsed = heading.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        guard collapsed.count > limit else { return collapsed }
        var cut = String(collapsed.prefix(limit))
        if let space = cut.lastIndex(of: " ") { cut = String(cut[..<space]) }
        return cut + "…"
    }

    /// La frase parlata di una riga di risultato: il contesto, poi dove sta — nella nota, la sezione (o «nel titolo» se
    /// il risultato è nel titolo stesso), la pagina del file originale.
    public static func rowLabel(snippet: String, inNote: Bool, noteNumber: String?, section: String?, page: Int?,
                                isHeadingItself: Bool = false) -> String {
        var parts: [String] = []
        if inNote { parts.append(noteNumber.map { "nella nota \($0)" } ?? "in una nota") }
        if isHeadingItself { parts.append("nel titolo") } else if let section, !section.isEmpty { parts.append(section) }
        if let page { parts.append("pagina \(number(page))") }
        guard !parts.isEmpty else { return snippet }
        var location = parts.joined(separator: ", ")
        location = location.prefix(1).uppercased() + location.dropFirst()
        let endsWithStop = snippet.last.map { ".…!?:;".contains($0) } ?? true
        return snippet + (endsWithStop ? " " : ". ") + location + "."
    }
}
