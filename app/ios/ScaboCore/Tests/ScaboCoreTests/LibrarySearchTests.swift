//
//  LibrarySearchTests.swift
//  ScaboCoreTests
//
//  La ricerca nel testo di tutti i libri (LibrarySearch.swift) e i richiami di nota come confine di «Parola intera»
//  (BookSearch.swift). Testi INVENTATI, mai di un volume.
//

import XCTest
@testable import ScaboCore

final class LibrarySearchTests: XCTestCase {

    private func seg(_ id: String, _ role: String, _ text: String) -> ContentSegment {
        ContentSegment(id: id, role: role, text: text, lengthCategory: "", acousticIntro: "", sourcePage: nil)
    }
    private func body(_ id: String, _ text: String) -> ContentSegment { seg(id, "BODY", text) }
    private func note(_ id: String, _ text: String) -> ContentSegment { seg(id, "NOTE", text) }

    private func count(_ segments: [ContentSegment], _ q: String, whole: Bool) -> Int {
        BookSearchCorpus(segments: segments).search(q, options: BookSearchOptions(wholeWord: whole)).totalCount
    }

    private let stamp = LibrarySearchText.SourceStamp(size: 1234, modifiedNanoseconds: 987_654_321)

    // MARK: Il richiamo di nota attaccato alla parola (Parte 3)

    /// La parola col numero del richiamo incollato, come la dà la lettura, e la nota letta subito dopo (legata al richiamo).
    private var calledWord: [ContentSegment] {
        [body("p#0", "Il carro della lanterna12 resta fermo al bivio."), note("n12", "12 Una nota inventata sul carro.")]
    }

    func test_wholeWord_findsTheWordWithTheNoteCallAttached() {
        XCTAssertEqual(count(calledWord, "lanterna", whole: true), 1, "il richiamo 12 è un confine")
        XCTAssertEqual(count(calledWord, "lanterna", whole: false), 1)
        XCTAssertEqual(BookSearchCorpus(segments: calledWord).callBoundaryCount, 1)
    }

    func test_wholeWord_theCallItselfIsAToken_butNoPieceOfTheWord() {
        XCTAssertEqual(count(calledWord, "12", whole: true), 2, "il richiamo e il numero in testa alla nota")
        XCTAssertEqual(count(calledWord, "lantern", whole: true), 0, "un pezzo di parola resta un pezzo")
        XCTAssertEqual(count(calledWord, "anterna", whole: true), 0)
        XCTAssertEqual(count(calledWord, "lanterna1", whole: true), 0, "il confine sta prima delle cifre, non in mezzo")
        XCTAssertEqual(count(calledWord, "lanterna12", whole: true), 1, "la forma incollata si trova ancora")
    }

    func test_noBoundary_withoutANoteCalledThere() {
        // Lo stesso testo senza la nota 12: le cifre non sono un richiamo che la lettura conosca.
        XCTAssertEqual(count([body("p", "Il carro della lanterna12 resta fermo.")], "lanterna", whole: true), 0)
        // Una nota 7, non 12: nessun confine dopo «lanterna».
        let other = [body("p#0", "Il carro della lanterna12 resta fermo al bivio7."), note("n7", "7 Altra nota.")]
        XCTAssertEqual(count(other, "lanterna", whole: true), 0)
        XCTAssertEqual(count(other, "bivio", whole: true), 1, "il richiamo 7 sì")
    }

    func test_noBoundary_whenTheNumberIsAttachedTwiceInTheSegment() {
        let twice = [body("p#0", "La sigla B12 e la lanterna12 nel bivio."), note("n12", "12 Una nota.")]
        XCTAssertEqual(count(twice, "lanterna", whole: true), 0, "nel dubbio non si tocca")
        XCTAssertEqual(count(twice, "b", whole: true), 0)
    }

    func test_callBoundaries_rules() {
        func positions(_ text: String, _ numbers: Set<Int>) -> [Int] {
            BookSearchCorpus.callBoundaries(in: Array(SearchNormalizer.normalize(text).utf8), numbers: numbers)
        }
        XCTAssertEqual(positions("lanterna12 x", [12]), [8])
        XCTAssertEqual(positions("lanterna012 x", [12]), [], "zero in testa")
        XCTAssertEqual(positions("lanterna1234 x", [1234]), [], "più di tre cifre")
        XCTAssertEqual(positions("lanterna 12 x", [12]), [], "dopo uno spazio la parola è già intera")
        XCTAssertEqual(positions("19912 x", [12]), [], "dopo una cifra")
        XCTAssertEqual(positions("città12 x", [12]), [5], "lettera accentata (normalizzata)")
        XCTAssertEqual(positions("σοφία3 x", [3]), [10], "lettera non latina (due byte ciascuna)")
    }

    // MARK: Il testo di ricerca di un libro

    private let books: [String: [ContentSegment]] = [
        "a": [ContentSegment(id: "h", role: "HEADING_2", text: "Capitolo del vento", lengthCategory: "", acousticIntro: "", sourcePage: 1),
              ContentSegment(id: "b#0", role: "BODY", text: "Il Vento soffia sulla città; il vento è freddo.", lengthCategory: "",
                             acousticIntro: "", sourcePage: 1),
              ContentSegment(id: "b#1", role: "BODY", text: "Poi la lanterna3 si spegne.", lengthCategory: "", acousticIntro: "",
                             sourcePage: 2),
              ContentSegment(id: "n3", role: "NOTE", text: "3 Il vento della nota.", lengthCategory: "SHORT", acousticIntro: "",
                             sourcePage: 2)],
        "b": [ContentSegment(id: "b", role: "BODY", text: "Nessun soffio qui, solo l'eventualità di una lanterna.",
                             lengthCategory: "", acousticIntro: "", sourcePage: 1)],
        "c": [ContentSegment(id: "b", role: "BODY", text: "VENTO! vento, Vènto.", lengthCategory: "", acousticIntro: "", sourcePage: 1)],
    ]

    private func libraryFiles() -> [String: Data] {
        books.mapValues { LibrarySearchText.encode(segments: $0, stamp: stamp) }
    }

    private let queries: [(String, Bool)] = [
        ("vento", false), ("vento", true), ("lanterna", true), ("lanterna", false), ("città", false), ("soffia sulla", false),
        ("vento della nota", false), ("ventualit", false), ("ventualit", true), ("", false), ("assente", false),
        ("freddo. poi la", false), ("3", true),
    ]

    func test_file_roundTrip_stampAndCounts_equalTheBookSearch() {
        for (id, segments) in books {
            let data = LibrarySearchText.encode(segments: segments, stamp: stamp)
            XCTAssertEqual(LibrarySearchText.stamp(of: data), stamp)
            let corpus = BookSearchCorpus(segments: segments)
            for (q, whole) in queries {
                let opts = BookSearchOptions(wholeWord: whole)
                XCTAssertEqual(LibrarySearchText.count(PreparedBookSearch(q, options: opts), in: data),
                               corpus.search(q, options: opts).totalCount, "libro \(id), «\(q)» intera \(whole)")
            }
        }
    }

    func test_file_isRejected_whenDamagedOrOfAnotherVersion() {
        let good = LibrarySearchText.encode(segments: books["a"]!, stamp: stamp)
        XCTAssertNotNil(LibrarySearchText.count(PreparedBookSearch("vento"), in: good))
        XCTAssertNil(LibrarySearchText.count(PreparedBookSearch("vento"), in: good.dropLast()), "troncato")
        var otherVersion = good
        otherVersion[8] = otherVersion[8] &+ 1
        XCTAssertNil(LibrarySearchText.stamp(of: otherVersion), "un'altra versione non vale")
        var notOurs = good
        notOurs[0] = 0x41
        XCTAssertNil(LibrarySearchText.count(PreparedBookSearch("vento"), in: notOurs))
        XCTAssertNil(LibrarySearchText.stamp(of: Data()))
    }

    /// Il testo di ricerca scritto su disco vale finché le regole del testo da cercare non cambiano: questa prova fotografa
    /// le regole (normalizzazione, flussi, confini dei richiami) su un campione inventato. Se diventa rossa perché le regole
    /// sono cambiate apposta, va alzata `LibrarySearchText.formatVersion` (i testi vecchi si riscrivono in sottofondo) e
    /// aggiornata qui l'impronta insieme alla versione; mai l'una senza l'altra (revisione del giro, rilievo 3).
    func test_formatVersion_isTiedToTheRulesOfTheText() {
        let sample = [
            ContentSegment(id: "h", role: "HEADING_2", text: "Perché l’Università — «Città» ﬁne", lengthCategory: "", acousticIntro: "", sourcePage: nil),
            ContentSegment(id: "b", role: "BODY", text: "Straße σοφός e\u{0301} par\u{00AD}ola lanterna7 ²", lengthCategory: "", acousticIntro: "", sourcePage: nil),
            ContentSegment(id: "n7", role: "NOTE", text: "7 Nota  di   prova.", lengthCategory: "", acousticIntro: "", sourcePage: nil),
            ContentSegment(id: "n7#1", role: "NOTE_CONTINUATION", text: "Seguito.", lengthCategory: "", acousticIntro: "", sourcePage: nil),
        ]
        let corpus = BookSearchCorpus(segments: sample)
        let fingerprint = corpus.buffer.reduce(UInt64(1469598103934665603)) { ($0 ^ UInt64($1)) &* 1099511628211 }
        XCTAssertEqual(LibrarySearchText.formatVersion, 1)
        XCTAssertEqual(corpus.wordBoundaries, [Int32(corpus.buffer.firstIndex(of: 0x37)!)], "il richiamo 7 attaccato")
        XCTAssertEqual(fingerprint, LibrarySearchTests.rulesFingerprintV1,
                       "le regole del testo da cercare sono cambiate: alzare LibrarySearchText.formatVersion e aggiornare l'impronta")
    }
    static let rulesFingerprintV1: UInt64 = 1621835139919584941

    // MARK: La ricerca nella libreria, con la prova al contrario

    /// Il conteggio atteso, calcolato in modo indipendente dal motore: il testo dei flussi unito a mano, `range(of:)` di
    /// Foundation, confini di parola scritti qui (lettere e cifre, più i richiami noti del libro di prova).
    private func expectedCounts(_ q: String, whole: Bool) -> [String: Int] {
        var out: [String: Int] = [:]
        let needle = SearchNormalizer.normalize(q)
        guard !needle.isEmpty else { return [:] }
        for (id, segments) in books {
            let bodyText = segments.filter { $0.role != "NOTE" }.map { SearchNormalizer.normalize($0.text) }.joined(separator: " ")
            let notes = segments.filter { $0.role == "NOTE" }.map { SearchNormalizer.normalize($0.text) }
            var n = 0
            for stream in [bodyText] + notes {
                var from = stream.startIndex
                while let r = stream.range(of: needle, range: from..<stream.endIndex) {
                    let before = r.lowerBound > stream.startIndex ? stream[stream.index(before: r.lowerBound)] : " "
                    let after = r.upperBound < stream.endIndex ? stream[r.upperBound] : " "
                    // il richiamo «3» dopo «lanterna» nel libro a
                    let callLeft = stream[..<r.lowerBound].hasSuffix("lanterna") && needle.first!.isNumber
                    let callRight = stream[r.upperBound...].hasPrefix("3 ") && stream[..<r.upperBound].hasSuffix("lanterna")
                    let okLeft = !whole || !(needle.first!.isLetter || needle.first!.isNumber) || !(before.isLetter || before.isNumber) || callLeft
                    let okRight = !whole || !(needle.last!.isLetter || needle.last!.isNumber) || !(after.isLetter || after.isNumber) || callRight
                    if okLeft && okRight { n += 1; from = r.upperBound } else { from = stream.index(after: r.lowerBound) }
                }
            }
            if n > 0 { out[id] = n }
        }
        return out
    }

    /// Le differenze fra ciò che la ricerca nella libreria ha restituito e l'atteso (vuoto: uguali).
    private func differences(_ result: LibrarySearchResult, _ expected: [String: Int]) -> [String] {
        var diffs: [String] = []
        let got = Dictionary(uniqueKeysWithValues: result.books.map { ($0.documentId, $0.count) })
        for id in Set(got.keys).union(expected.keys).sorted() where got[id] != expected[id] {
            diffs.append("\(id): \(got[id] ?? 0) invece di \(expected[id] ?? 0)")
        }
        return diffs
    }

    private func runLibrary(_ q: String, whole: Bool, files: [String: Data], dropOne: Bool = false) -> LibrarySearchResult {
        let titles = ["a": "Libro del vento", "b": "Libro senza vento", "c": "Libro gridato"]
        let list = titles.keys.sorted().map { (documentId: $0, title: titles[$0]!) }
        let r = LibrarySearch.run(q, options: BookSearchOptions(wholeWord: whole), books: list) { files[$0] }
        guard dropOne, let k = r.books.firstIndex(where: { $0.count > 0 }) else { return r }
        // PROVA AL CONTRARIO: un risultato tolto di proposito.
        var books = r.books
        let b = books[k]
        books[k] = LibrarySearchBookResult(documentId: b.documentId, title: b.title, count: b.count - 1)
        return LibrarySearchResult(query: r.query, normalizedQuery: r.normalizedQuery, options: r.options,
                                   books: books.filter { $0.count > 0 }, notReady: r.notReady)
    }

    func test_library_findsEverythingAndOnlyTheRightThing_inEveryBook() {
        let files = libraryFiles()
        for (q, whole) in queries {
            let r = runLibrary(q, whole: whole, files: files)
            XCTAssertEqual(differences(r, expectedCounts(q, whole: whole)), [], "«\(q)» intera \(whole)")
            XCTAssertEqual(r.notReady, 0)
        }
        let vento = runLibrary("vento", whole: true, files: files)
        XCTAssertEqual(vento.books.map(\.documentId), ["a", "c"], "in ordine e solo i libri con risultati")
        XCTAssertEqual(vento.totalCount, 7)
    }

    func test_library_counterProof_aResultRemovedOnPurpose_failsTheComparison() {
        let files = libraryFiles()
        var red = 0
        for (q, whole) in queries where !(expectedCounts(q, whole: whole).isEmpty) {
            let r = runLibrary(q, whole: whole, files: files, dropOne: true)
            if !differences(r, expectedCounts(q, whole: whole)).isEmpty { red += 1 } else {
                XCTFail("la prova al contrario non è rossa per «\(q)»")
            }
        }
        XCTAssertGreaterThan(red, 5)
    }

    func test_library_booksWithoutAValidText_areCountedAsNotReady() {
        var files = libraryFiles()
        files["b"] = files["b"]!.dropLast()   // danneggiato
        files["c"] = nil                       // mai scritto
        let r = runLibrary("vento", whole: false, files: files)
        XCTAssertEqual(r.books.map(\.documentId), ["a"])
        XCTAssertEqual(r.notReady, 2)
        XCTAssertTrue(BookSearchWording.librarySummary(r).contains("2 libri non si sono potuti cercare"), BookSearchWording.librarySummary(r))
    }

    func test_wording_summaryAndRows() {
        let files = libraryFiles()
        XCTAssertEqual(BookSearchWording.librarySummary(runLibrary("vento", whole: false, files: files)),
                       "2 libri, 7 risultati in tutto per «vento».")
        XCTAssertEqual(BookSearchWording.librarySummary(runLibrary("soffia sulla", whole: false, files: files)),
                       "Un libro, un risultato per «soffia sulla».")
        XCTAssertEqual(BookSearchWording.librarySummary(runLibrary("lanterna", whole: false, files: files)),
                       "2 libri, 2 risultati in tutto per «lanterna».")
        XCTAssertEqual(BookSearchWording.librarySummary(runLibrary("il vento", whole: false, files: files)),
                       "Un libro, 3 risultati in tutto per «il vento».")
        let none = BookSearchWording.librarySummary(runLibrary("ventualit", whole: true, files: files))
        XCTAssertTrue(none.hasPrefix("Nel testo dei libri nessun risultato per «ventualit»."), none)
        XCTAssertTrue(none.contains("togliere «Parola intera»"), none)
        XCTAssertEqual(BookSearchWording.libraryBookRow(title: "Libro del vento", count: 1), "Libro del vento, un risultato")
        XCTAssertEqual(BookSearchWording.libraryBookRow(title: "Libro del vento", count: 12345), "Libro del vento, 12.345 risultati")
    }
}
