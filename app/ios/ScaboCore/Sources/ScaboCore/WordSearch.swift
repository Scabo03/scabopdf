//
//  WordSearch.swift
//  ScaboCore
//
//  RICERCA PER PAROLE PESATE E SALTO PER NUMERO (giro «la ricerca», 2026-11-26; LAYER2_PRODUCT_DECISIONS § 12.16, decisione 29;
//  misure in docs/BANCO_EMBEDDING.md § 12). Solo Foundation, come `BookSearch.swift`, di cui completa la ricerca nel libro.
//
//  Perché: la ricerca della frase intera non trova nulla quando la domanda dice il concetto con parole proprie (sul banco 352
//  domande su 352 senza un libro coi risultati), mentre una ricerca per parole pesate, senza modelli, porta le voci d'indice da 0,26
//  a 0,76 dei passi giusti fra i primi dieci e le domande a parole proprie da 0 a 0,39 (BANCO_EMBEDDING § 2.1, § 9).
//
//  ── Le parole pesate (BM25) ───────────────────────────────────────────────────────────────────────────────────
//
//  Quando la ricerca ha almeno due parole, oltre alle occorrenze esatte la ricerca nel libro dà i PASSI: i segmenti del flusso di
//  Lettura Continua ordinati per BM25 (k1 = 1,2, b = 0,75) sulle parole della ricerca. Le parole sono le sequenze di lettere e cifre
//  del testo normalizzato con le regole della ricerca (`SearchNormalizer`: maiuscole, accenti, apostrofi e virgolette non contano);
//  l'IDF (ln(1 + (N − df + 0,5) / (df + 0,5))) e la lunghezza media sono quelli dei segmenti del libro, come la BM25 del banco
//  (che li prendeva dalla libreria intera). Ogni parola conta per quanto è rara nel libro: una domanda scritta con parole proprie
//  trova i passi che ne contengono di più, anche senza la frase intera.
//
//  ── Il blocco corto vale il blocco seguente ───────────────────────────────────────────────────────────────────────
//
//  Un segmento di meno di 40 caratteri normalizzati (un titolo, un rimando, una riga sola) porta il suo punteggio al primo segmento
//  lungo successivo (in ordine di lettura), e il passo che si presenta è quello: la regola che sul banco non peggiora nessuna
//  famiglia di domande e toglie i risultati fatti di una riga sola (BANCO_EMBEDDING § 11.3). Il gruppo vale il punteggio migliore.
//
//  ── Il salto per numero ─────────────────────────────────────────────────────────────────────────────────────
//
//  «art. 2043 c.c.», «articolo 2043 del c.c.», «§ 12», «paragrafo 12»: la ricerca riconosce un articolo (col suffisso
//  latino) o un paragrafo, e mette in testa ai passi le intestazioni con quel numero (`ARTICLE_HEADER` dei codici, titoli che si
//  aprono con «§ N» dei manuali). Gli articoli di un libro si dividono in SEQUENZE dove la numerazione riparte (un codice, le sue
//  disposizioni d'attuazione, una legge collegata). Il nome di una sequenza non sta nel testo della lettura: lo si riconosce dalla
//  rubrica del suo articolo 1 per i quattro codici (`codeKeys`). Se la ricerca nomina un codice, il salto va alla sequenza di quel
//  codice; se non lo nomina, o se nel libro non c'è, i candidati sono tutte le sequenze con quel numero, la più lunga per prima.
//

import Foundation

// MARK: - I passi

/// Un passo dato dalla ricerca per parole o dal salto per numero: l'elemento della lettura da raggiungere.
public struct BookSearchPassage: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        /// Un'intestazione d'articolo: il numero (con il suffisso, «2043», «2-bis») e il codice, se riconosciuto.
        case article(number: String, code: BookSearchCode?)
        /// Un titolo che si apre con «§ N».
        case paragraph(number: String)
        /// Un passo dalle parole pesate.
        case words
    }
    public let segmentIndex: Int
    public let kind: Kind
    public let score: Double
    public init(segmentIndex: Int, kind: Kind, score: Double) {
        self.segmentIndex = segmentIndex
        self.kind = kind
        self.score = score
    }
    public var isJump: Bool { if case .words = kind { return false } else { return true } }
}

/// I quattro codici che il salto riconosce.
public enum BookSearchCode: String, CaseIterable, Sendable {
    case civile = "c.c.", proceduraCivile = "c.p.c.", penale = "c.p.", proceduraPenale = "c.p.p."
    /// Il nome detto a voce.
    public var spokenName: String {
        switch self {
        case .civile: return "codice civile"
        case .proceduraCivile: return "codice di procedura civile"
        case .penale: return "codice penale"
        case .proceduraPenale: return "codice di procedura penale"
        }
    }
    /// Le forme con cui una ricerca nomina il codice (testo normalizzato), le più lunghe prima.
    static let aliases: [(String, BookSearchCode)] = [
        ("codice di procedura civile", .proceduraCivile), ("codice di procedura penale", .proceduraPenale),
        ("cod. proc. civ.", .proceduraCivile), ("cod. proc. pen.", .proceduraPenale), ("proc. civ.", .proceduraCivile),
        ("proc. pen.", .proceduraPenale), ("codice civile", .civile), ("codice penale", .penale), ("cod. civ.", .civile),
        ("cod. pen.", .penale), ("c.p.c.", .proceduraCivile), ("c.p.p.", .proceduraPenale), ("c.c.", .civile), ("c.p.", .penale),
        ("cpc", .proceduraCivile), ("cpp", .proceduraPenale), ("cc", .civile), ("cp", .penale),
    ]
    /// Le parole della rubrica dell'articolo 1 che riconoscono il codice di una sequenza (testo normalizzato).
    static let codeKeys: [(String, BookSearchCode)] = [
        ("capacita giuridica", .civile), ("giudici ordinari", .proceduraCivile),
        ("reati e pene", .penale), ("giurisdizione penale", .proceduraPenale),
    ]
}

/// Ciò che la ricerca chiede per numero.
public struct NumberQuery: Equatable, Sendable {
    public enum Target: Equatable, Sendable { case article, paragraph }
    public let target: Target
    public let number: Int
    public let suffix: String?
    public let code: BookSearchCode?
    /// Una ricerca con più parole di così non è una domanda per numero (una domanda che cita un articolo ne ha di solito meno di 10).
    public static let maxWords = 12
    /// «2043», «2-bis».
    public var label: String { suffix.map { "\(number)-\($0)" } ?? "\(number)" }

    static let suffixes = "bis|ter|quater|quinquies|sexies|septies|octies|novies|nonies|decies|undecies|duodecies|terdecies|quaterdecies|quinquiesdecies"
    private static let articleQuery = try! NSRegularExpression(
        pattern: "(?:^|[^\\p{L}\\p{N}])(?:art|artt|articolo|articoli)\\.?\\s*(\\d{1,4})(?:\\s*-?\\s*(\(suffixes)))?(?![\\p{L}\\p{N}])(.*)$")
    private static let paragraphQuery = try! NSRegularExpression(
        pattern: "(?:§+|(?:^|[^\\p{L}\\p{N}])(?:paragrafo|par\\.))\\s*(\\d{1,4})(?:\\s*-?\\s*(\(suffixes)))?(?![\\p{L}\\p{N}])")

    /// La domanda per numero contenuta nella ricerca (testo già normalizzato), o `nil`.
    public static func parse(normalized q: String) -> NumberQuery? {
        let ns = q as NSString, all = NSRange(location: 0, length: ns.length)
        func g(_ m: NSTextCheckingResult, _ i: Int) -> String? {
            let r = m.range(at: i); return r.location == NSNotFound ? nil : ns.substring(with: r)
        }
        if let m = paragraphQuery.firstMatch(in: q, range: all), let n = g(m, 1).flatMap(Int.init) {
            return NumberQuery(target: .paragraph, number: n, suffix: g(m, 2), code: nil)
        }
        if let m = articleQuery.firstMatch(in: q, range: all), let n = g(m, 1).flatMap(Int.init) {
            let rest = " " + (g(m, 3) ?? "") + " "
            var code: BookSearchCode?
            for (alias, c) in BookSearchCode.aliases where Self.containsAlias(rest, alias) { code = c; break }
            return NumberQuery(target: .article, number: n, suffix: g(m, 2), code: code)
        }
        return nil
    }

    static func containsAlias(_ text: String, _ alias: String) -> Bool {
        var from = text.startIndex
        while let r = text.range(of: alias, range: from..<text.endIndex) {
            let before = r.lowerBound == text.startIndex ? nil : text[text.index(before: r.lowerBound)]
            let after = r.upperBound == text.endIndex ? nil : text[r.upperBound]
            let edge: (Character?) -> Bool = { c in c.map { !($0.isLetter || $0.isNumber || $0 == ".") } ?? true }
            if edge(before) && edge(after) { return true }
            from = text.index(after: r.lowerBound)
        }
        return false
    }
}

// MARK: - L'indice delle intestazioni numerate

/// Le intestazioni d'articolo e di paragrafo di un libro, con le sequenze degli articoli e il codice riconosciuto.
struct NumberedHeadings {
    struct Article { let segment: Int; let number: Int; let suffix: String?; let sequence: Int }
    struct Sequence { var count: Int; var code: BookSearchCode? }
    var articles: [Article] = []
    var sequences: [Sequence] = []
    var paragraphs: [String: Int] = [:]   // «12», «12-bis» -> segmento (il primo)

    private static let articleHead = try! NSRegularExpression(
        pattern: "^\\s*(?:art\\.?\\s*|articolo\\s+)?(\\d{1,4})(?:\\s*-?\\s*(\(NumberQuery.suffixes)))?(?![\\p{L}\\p{N}])")
    private static let paragraphHead = try! NSRegularExpression(
        pattern: "^\\s*§+\\s*(\\d{1,4})(?:\\s*-?\\s*(\(NumberQuery.suffixes)))?(?![\\p{L}\\p{N}])")

    init(segments: [ContentSegment]) {
        var last = -1
        var firstOfSequence: [Int: String] = [:]
        for (i, s) in segments.enumerated() {
            let isArticle = s.role == SemanticCategory.ARTICLE_HEADER.rawValue
            guard isArticle || s.role.hasPrefix("HEADING_") else { continue }
            let head = SearchNormalizer.normalize(String(s.text.prefix(160)))
            let ns = head as NSString, all = NSRange(location: 0, length: ns.length)
            func g(_ m: NSTextCheckingResult, _ k: Int) -> String? {
                let r = m.range(at: k); return r.location == NSNotFound ? nil : ns.substring(with: r)
            }
            if isArticle, let m = Self.articleHead.firstMatch(in: head, range: all), let n = g(m, 1).flatMap(Int.init) {
                if sequences.isEmpty || n < last - 50 || (n == 1 && last >= 5) { sequences.append(Sequence(count: 0, code: nil)) }
                let q = sequences.count - 1
                sequences[q].count += 1
                if n == 1, firstOfSequence[q] == nil { firstOfSequence[q] = head }
                articles.append(Article(segment: i, number: n, suffix: g(m, 2), sequence: q))
                last = n
            } else if !isArticle, let m = Self.paragraphHead.firstMatch(in: head, range: all), let n = g(m, 1) {
                let key = g(m, 2).map { "\(n)-\($0)" } ?? n
                if paragraphs[key] == nil { paragraphs[key] = i }
            }
        }
        // Il codice di una sequenza dalla rubrica del suo articolo 1; un codice non si dà a due sequenze (la più lunga lo tiene).
        var taken: [BookSearchCode: Int] = [:]
        for (q, head) in firstOfSequence {
            guard let code = BookSearchCode.codeKeys.first(where: { head.contains($0.0) })?.1 else { continue }
            if let other = taken[code], sequences[other].count >= sequences[q].count { continue }
            if let other = taken[code] { sequences[other].code = nil }
            sequences[q].code = code
            taken[code] = q
        }
    }

    /// I salti per una domanda per numero, nell'ordine dell'elenco.
    func jumps(for q: NumberQuery) -> [BookSearchPassage] {
        switch q.target {
        case .paragraph:
            return paragraphs[q.label].map { [BookSearchPassage(segmentIndex: $0, kind: .paragraph(number: q.label), score: .infinity)] } ?? []
        case .article:
            var found = articles.filter { $0.number == q.number && $0.suffix == q.suffix }
            var seen = Set<Int>()
            found = found.filter { seen.insert($0.sequence).inserted }   // la prima intestazione per sequenza
            if let code = q.code, found.contains(where: { sequences[$0.sequence].code == code }) {
                found = found.filter { sequences[$0.sequence].code == code }
            }
            found.sort { sequences[$0.sequence].count > sequences[$1.sequence].count }
            return found.map { BookSearchPassage(segmentIndex: $0.segment, kind: .article(number: q.label, code: sequences[$0.sequence].code),
                                                 score: .infinity) }
        }
    }
}

// MARK: - L'indice delle parole

/// Le parole dei segmenti del libro, per BM25. Si costruisce alla prima ricerca di più parole.
final class BookWordIndex {
    static let k1 = 1.2, b = 0.75, shortSegment = 40
    private let termIds: [String: Int32]
    private let postings: [[(segment: Int32, tf: Int32)]]
    private let length: [Int32]
    private let documents: Int
    private let averageLength: Double
    /// Per ogni segmento, il segmento che lo rappresenta (sé stesso, o il primo lungo che segue un corto).
    let representative: [Int32]

    init(corpus: BookSearchCorpus) {
        let n = corpus.segmentCount
        var length = [Int32](repeating: 0, count: n)
        var termIds: [String: Int32] = [:]
        var postings: [[(segment: Int32, tf: Int32)]] = []
        var docs = 0, total = 0
        var rep = [Int32](repeating: -1, count: n)
        corpus.buffer.withUnsafeBufferPointer { buf in
            for s in 0..<n where corpus.segmentStart[s] >= 0 {
                let start = Int(corpus.segmentStart[s]), end = start + Int(corpus.segmentLength[s])
                var counts: [Int32: Int32] = [:]
                var i = start, tokenStart = -1, words: Int32 = 0
                func flush(_ to: Int) {
                    guard tokenStart >= 0 else { return }
                    let word = String(decoding: UnsafeBufferPointer(rebasing: buf[tokenStart..<to]), as: UTF8.self)
                    let id: Int32
                    if let known = termIds[word] { id = known } else { id = Int32(postings.count); termIds[word] = id; postings.append([]) }
                    counts[id, default: 0] += 1
                    words += 1
                    tokenStart = -1
                }
                while i < end {
                    let b0 = buf[i]
                    let width = b0 < 0x80 ? 1 : (b0 >= 0xF0 ? 4 : (b0 >= 0xE0 ? 3 : 2))
                    let v = b0 < 0x80 ? UInt32(b0) : BookSearchCorpus.decode(buf, at: i)
                    if SearchNormalizer.isWordScalar(v) { if tokenStart < 0 { tokenStart = i } } else { flush(i) }
                    i += width
                }
                flush(end)
                for (id, tf) in counts { postings[Int(id)].append((Int32(s), tf)) }
                length[s] = words
                docs += 1
                total += Int(words)
            }
        }
        self.termIds = termIds
        self.postings = postings
        self.length = length
        documents = max(1, docs)
        averageLength = docs > 0 ? Double(total) / Double(docs) : 1
        // Il blocco corto vale il blocco seguente.
        var next: Int32 = -1
        for s in stride(from: n - 1, through: 0, by: -1) {
            guard corpus.segmentStart[s] >= 0 else { continue }
            if Int(corpus.segmentLength[s]) < Self.shortSegment {
                rep[s] = next >= 0 ? next : Int32(s)
            } else {
                rep[s] = Int32(s)
                next = Int32(s)
            }
        }
        representative = rep
    }

    /// Le parole della ricerca (testo normalizzato) con il loro peso nel libro e se distinguono (compaiono al più in metà dei
    /// segmenti).
    func weightedTerms(_ normalizedQuery: String) -> [(id: Int32, idf: Double, distinctive: Bool)] {
        var seen = Set<Int32>(), out: [(Int32, Double, Bool)] = []
        var word = ""
        func take() {
            defer { word = "" }
            guard !word.isEmpty, let id = termIds[word], seen.insert(id).inserted else { return }
            let df = Double(postings[Int(id)].count)
            out.append((id, log(1 + (Double(documents) - df + 0.5) / (df + 0.5)), df <= 0.5 * Double(documents)))
        }
        for u in normalizedQuery.unicodeScalars {
            if SearchNormalizer.isWordScalar(u.value) { word.unicodeScalars.append(u) } else { take() }
        }
        take()
        return out
    }

    /// I passi per BM25, i migliori `limit`, coi corti già riportati al blocco seguente. Il punteggio è quello di BM25 su tutte
    /// le parole; ma un passo deve contenere almeno una parola che DISTINGUE (presente al più in metà dei segmenti del libro):
    /// «la piena del fiume» non dà come passi tutti i segmenti che dicono «del». Se nessuna parola distingue («libro due» in un
    /// libro dove tutte e due sono ovunque), niente passi: restano le occorrenze esatte.
    func rank(_ normalizedQuery: String, limit: Int) -> [BookSearchPassage] {
        let terms = weightedTerms(normalizedQuery)
        guard terms.contains(where: \.distinctive) else { return [] }
        var score: [Int32: Double] = [:]
        var distinguished = Set<Int32>()
        for (id, idf, distinctive) in terms {
            for p in postings[Int(id)] {
                let tf = Double(p.tf), dl = Double(length[Int(p.segment)])
                score[p.segment, default: 0] += idf * tf * (Self.k1 + 1) / (tf + Self.k1 * (1 - Self.b + Self.b * dl / averageLength))
                if distinctive { distinguished.insert(p.segment) }
            }
        }
        var group: [Int32: Double] = [:]
        for (s, v) in score where distinguished.contains(s) {
            let r = representative[Int(s)]
            if v > group[r] ?? -1 { group[r] = v }
        }
        return group.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .prefix(limit).map { BookSearchPassage(segmentIndex: Int($0.key), kind: .words, score: $0.value) }
    }
}

// MARK: - Le parole di un segmento

extension BookWordIndex {
    /// Le parole (sequenze di lettere e cifre) del testo normalizzato fra `from` e `to`, come intervalli di byte.
    static func forEachWord(_ buf: UnsafeBufferPointer<UInt8>, from: Int, to: Int, _ body: (Int, Int) -> Void) {
        var i = from, start = -1
        while i < to {
            let b0 = buf[i]
            let width = b0 < 0x80 ? 1 : (b0 >= 0xF0 ? 4 : (b0 >= 0xE0 ? 3 : 2))
            let v = b0 < 0x80 ? UInt32(b0) : BookSearchCorpus.decode(buf, at: i)
            if SearchNormalizer.isWordScalar(v) {
                if start < 0 { start = i }
            } else if start >= 0 {
                body(start, i)
                start = -1
            }
            i += width
        }
        if start >= 0 { body(start, to) }
    }

    /// L'IDF della parola nel libro, o `nil` se il libro non la contiene.
    func idf(_ word: String) -> Double? {
        guard let id = termIds[word] else { return nil }
        let df = Double(postings[Int(id)].count)
        return log(1 + (Double(documents) - df + 0.5) / (df + 0.5))
    }
}

// MARK: - Le righe dei passi

extension BookSearchCorpus {
    /// Dove porta un passo: l'inizio del suo elemento (un'occorrenza di lunghezza zero, per il salto della lettura).
    public func entryHit(for passage: BookSearchPassage) -> BookSearchHit {
        let s = passage.segmentIndex
        return BookSearchHit(segmentIndex: s, endSegmentIndex: s, isInNote: s < segmentCount && segmentIsNote[s],
                             startInSegment: 0, length: 0)
    }

    /// Il contesto di un passo per la sua riga. Un passo per parole: attorno alla prima occorrenza della parola più rara della
    /// ricerca (in evidenza); un salto: il suo titolo.
    public func snippet(for passage: BookSearchPassage, normalizedQuery: String,
                        segments: [ContentSegment]) -> (text: String, match: NSRange) {
        let s = passage.segmentIndex
        guard s < segments.count else { return ("", NSRange(location: 0, length: 0)) }
        let whole = (BookSearchWording.sectionTitle(segments[s].text, limit: 160), NSRange(location: 0, length: 0))
        guard case .words = passage.kind, segmentStart[s] >= 0 else { return whole }
        let index = wordIndex
        var wanted: [String: Double] = [:]
        var word = ""
        for u in normalizedQuery.unicodeScalars + [" "] {
            if SearchNormalizer.isWordScalar(u.value) { word.unicodeScalars.append(u); continue }
            if !word.isEmpty, let idf = index.idf(word) { wanted[word] = idf }
            word = ""
        }
        var best: (start: Int, length: Int, idf: Double)?
        let start = Int(segmentStart[s])
        buffer.withUnsafeBufferPointer { buf in
            BookWordIndex.forEachWord(buf, from: start, to: start + Int(segmentLength[s])) { a, b in
                let w = String(decoding: UnsafeBufferPointer(rebasing: buf[a..<b]), as: UTF8.self)
                if let idf = wanted[w], idf > (best?.idf ?? -1) { best = (a - start, b - a, idf) }
            }
        }
        guard let best else { return whole }
        let hit = BookSearchHit(segmentIndex: s, endSegmentIndex: s, isInNote: segmentIsNote[s],
                                startInSegment: best.start, length: best.length)
        return snippet(for: hit, segments: segments)
    }

    /// Il titolo di livello (non un articolo) più vicino prima del segmento: dove sta un articolo raggiunto per numero.
    public static func enclosingSection(of index: Int, segments: [ContentSegment]) -> Int? {
        var k = min(index, segments.count) - 1
        while k >= 0 {
            if segments[k].role.hasPrefix("HEADING_") { return k }
            k -= 1
        }
        return nil
    }
}

// MARK: - Le frasi dei passi

extension BookSearchWording {
    /// «articolo N» col nome del codice se riconosciuto, «paragrafo N».
    public static func jumpName(_ p: BookSearchPassage) -> String? {
        switch p.kind {
        case let .article(number, code): return "articolo \(number)" + (code.map { " del \($0.spokenName)" } ?? "")
        case let .paragraph(number): return "paragrafo \(number)"
        case .words: return nil
        }
    }

    /// «l'articolo 12», «il paragrafo 12».
    static func withArticle(_ name: String) -> String { name.hasPrefix("articolo") ? "l'" + name : "il " + name }

    /// La frase del conteggio quando la ricerca ha dato passi o chiede un numero, nell'ordine dell'elenco: prima i salti, poi le
    /// corrispondenze esatte e i passi per parole nell'ordine scelto nelle impostazioni (`SearchSettings.order`).
    static func passagesSentence(_ r: BookSearchResult) -> String {
        let q = "«\(r.query)»"
        let jumps = r.jumps
        let words = r.wordPassages.count
        var out: [String] = []
        if let nq = r.numberQuery {
            let what = nq.target == .article ? "articolo \(nq.label)" : "paragrafo \(nq.label)"
            let codes = jumps.compactMap { p -> BookSearchCode? in if case let .article(_, c) = p.kind { return c }; return nil }
            if let code = nq.code, !jumps.isEmpty, !codes.contains(code) {
                out.append("In questo libro non riconosco il \(code.spokenName).")
            }
            switch jumps.count {
            case 0: out.append("Nessun \(what) in questo libro.")
            case 1: out.append("Primo risultato: \(withArticle(jumpName(jumps[0]) ?? what)).")
            case _ where r.settings.codeChoice == .mainCode:
                // «Vai al codice principale»: si dice il primo (il codice più ampio), poi quanti altri stanno subito sotto.
                let others = jumps.count - 1
                out.append("Primo risultato: \(withArticle(jumpName(jumps[0]) ?? what)). Subito sotto, "
                    + (others == 1 ? "lo stesso numero in un'altra parte del libro." : "lo stesso numero in altre \(number(others)) parti del libro."))
            default:
                var places = codes.map { "nel \($0.spokenName)" }
                let others = jumps.count - codes.count
                if others == 1 { places.append("in un'altra parte del libro") }
                if others > 1 { places.append("in altre \(number(others)) parti del libro") }
                let list = places.count == 1 ? places[0]
                    : places.dropLast().joined(separator: ", ") + " e " + places[places.count - 1]
                out.append("Primi \(number(jumps.count)) risultati: \(withArticle(what)) \(list).")
            }
        }
        guard !jumps.isEmpty || words > 0 else {
            out.append(exactCountSentence(r))
            return out.joined(separator: " ")
        }
        func wordsPart(first: Bool) -> String? {
            guard words > 0 else { return nil }
            let n = words == 1 ? "Un passo" : "\(number(words)) passi"
            return (first ? n : "Poi " + n.lowercased()) + " con le parole di \(q), i più pertinenti per primi."
        }
        func exactPart(first: Bool) -> String {
            switch r.totalCount {
            case 0: return "Nessun risultato esatto."
            case 1: return first ? "Un risultato esatto." : "Poi un risultato esatto."
            default:
                var s = (first ? "" : "Poi ") + "\(number(r.totalCount)) risultati esatti, in ordine di lettura."
                if r.isTruncated {
                    s += " Dei risultati esatti, qui sotto i primi \(number(r.hits.count)): per restringere, aggiungi un'altra parola"
                    s += r.options.wholeWord ? "." : " o scegli «Parola intera»."
                }
                return s
            }
        }
        if r.wordPassagesFirst {
            if let w = wordsPart(first: jumps.isEmpty) { out.append(w) }
            out.append(exactPart(first: false))
        } else {
            out.append(exactPart(first: jumps.isEmpty))
            // Dopo «Nessun risultato esatto.» i passi si dicono senza «Poi».
            if let w = wordsPart(first: jumps.isEmpty && r.totalCount == 0) { out.append(w) }
        }
        return out.joined(separator: " ")
    }

    /// La frase parlata della riga di un passo. Un salto: il codice (se riconosciuto), il titolo dell'articolo o del paragrafo,
    /// dove sta. Un passo per parole: «Passo:», il contesto, dove sta.
    public static func passageRowLabel(_ p: BookSearchPassage, snippet: String, inNote: Bool, noteNumber: String?,
                                       section: String?, page: Int?, isHeadingItself: Bool = false,
                                       announcement: SearchSettings.Announcement = .brief) -> String {
        let full = announcement == .full
        switch p.kind {
        case let .article(_, code):
            // Il nome del codice resta anche nell'annuncio breve: distingue i candidati con lo stesso numero.
            let name = code.map { $0.spokenName.prefix(1).uppercased() + $0.spokenName.dropFirst() }
            let head = full ? (code.map { "Articolo del \($0.spokenName): " } ?? "Articolo: ") : (name.map { $0 + ": " } ?? "")
            return rowLabel(snippet: head + snippet, inNote: inNote, noteNumber: noteNumber, section: section, page: page)
        case .paragraph:
            return (full ? "Paragrafo: " : "")
                + rowLabel(snippet: snippet, inNote: inNote, noteNumber: noteNumber, section: section, page: page)
        case .words:
            return (full ? "Passo pertinente: " : "")
                + rowLabel(snippet: snippet, inNote: inNote, noteNumber: noteNumber, section: section, page: page,
                           isHeadingItself: isHeadingItself)
        }
    }

    /// La frase parlata della riga di una corrispondenza esatta: con l'annuncio completo, il tipo in testa.
    public static func exactRowLabel(snippet: String, inNote: Bool, noteNumber: String?, section: String?, page: Int?,
                                     isHeadingItself: Bool = false, announcement: SearchSettings.Announcement) -> String {
        (announcement == .full ? "Corrispondenza esatta: " : "")
            + rowLabel(snippet: snippet, inNote: inNote, noteNumber: noteNumber, section: section, page: page,
                       isHeadingItself: isHeadingItself)
    }

    /// Il valore di un elemento fra le fermate nell'ordine dei risultati («risultato 3 di 25»), con «anche sui passi pertinenti».
    public static func stopValue(rank: Int, of total: Int) -> String {
        "risultato \(number(rank)) di \(number(total))"
    }
}
