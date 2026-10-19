//
//  BookSearchTests.swift
//  ScaboCoreTests
//
//  La ricerca dentro il testo del libro (BookSearch.swift). Testi INVENTATI, mai di un volume.
//

import XCTest
@testable import ScaboCore

final class BookSearchTests: XCTestCase {

    private func seg(_ id: String, _ role: String, _ text: String, page: Int? = nil) -> ContentSegment {
        ContentSegment(id: id, role: role, text: text, lengthCategory: "", acousticIntro: "", sourcePage: page)
    }

    private func body(_ id: String, _ text: String, page: Int? = nil) -> ContentSegment { seg(id, "BODY", text, page: page) }
    private func note(_ id: String, _ text: String) -> ContentSegment { seg(id, "NOTE", text) }
    private func piece(_ id: String, _ text: String) -> ContentSegment { seg(id, "NOTE_CONTINUATION", text) }
    private func heading(_ id: String, _ text: String, level: Int = 2) -> ContentSegment { seg(id, "HEADING_\(level)", text) }

    private func count(_ segments: [ContentSegment], _ q: String, whole: Bool = false) -> Int {
        BookSearchCorpus(segments: segments).search(q, options: BookSearchOptions(wholeWord: whole)).totalCount
    }

    // MARK: Normalizzazione

    func test_normalize_foldsCaseAccentsApostrophesQuotesDashesAndSpaces() {
        XCTAssertEqual(SearchNormalizer.normalize("  PERCHÉ   la  Città\u{00A0}è "), "perche la citta e")
        XCTAssertEqual(SearchNormalizer.normalize("l’arco dell‘ape"), "l'arco dell'ape")
        XCTAssertEqual(SearchNormalizer.normalize("«libro» “verde” „blu“"), "\"libro\" \"verde\" \"blu\"")
        XCTAssertEqual(SearchNormalizer.normalize("anni 1990–2000 — fine"), "anni 1990-2000 - fine")
        XCTAssertEqual(SearchNormalizer.normalize("ﬁore ²"), "fiore 2", "compatibilità: legature e apici")
        XCTAssertEqual(SearchNormalizer.normalize("Straße ΣΟΦΟΣ"), "strasse σοφοσ")
        XCTAssertEqual(SearchNormalizer.normalize("par\u{00AD}ola\u{200B}"), "parola", "trattino morbido e spazio largo zero spariscono")
        XCTAssertEqual(SearchNormalizer.normalize("e\u{0301}"), "e", "segno combinante separato")
        XCTAssertEqual(SearchNormalizer.normalize("l´arco l`arco"), "l'arco l'arco", "accento acuto e grave isolati come apostrofo")
    }

    func test_normalize_tracking_givesTheSameBytes_andOriginsInUTF16() {
        let text = "«Perché» 🐱 l’età"
        let plain = SearchNormalizer.normalizedBytes(text)
        let tracked = SearchNormalizer.normalizedBytesTracking(text)
        XCTAssertEqual(tracked.bytes, plain)
        XCTAssertEqual(tracked.originStart.count, plain.count)
        // «e» di «età» viene dalla «e» accentata in coda: l'origine è il suo offset UTF-16 (l'emoji conta due unità).
        let ns = text as NSString
        let eta = ns.range(of: "età")
        // L'indice è in BYTE del testo normalizzato (l'emoji ne occupa quattro).
        let needle = Array("eta".utf8)
        let k = (0...(plain.count - needle.count)).first { Array(plain[$0..<($0 + needle.count)]) == needle }!
        XCTAssertEqual(Int(tracked.originStart[k]), eta.location)
        XCTAssertEqual(Int(tracked.originEnd[k + 2]), eta.location + eta.length, "la «a» viene dalla «à»")
    }

    // MARK: Che cosa si trova

    func test_search_ignoresCaseAccentsAndTypographicMarks() {
        let s = [body("a", "Perché l’Università apre «La Città» alle 1990–2000.")]
        XCTAssertEqual(count(s, "perche"), 1)
        XCTAssertEqual(count(s, "UNIVERSITA"), 1)
        XCTAssertEqual(count(s, "l'universita"), 1, "apostrofo diritto = tipografico")
        XCTAssertEqual(count(s, "\"la citta\""), 1, "virgolette diritte = caporali")
        XCTAssertEqual(count(s, "1990-2000"), 1, "trattino = lineetta")
        XCTAssertEqual(count(s, "città"), 1)
    }

    func test_search_countsWithoutOverlap_leftToRight() {
        XCTAssertEqual(count([body("a", "aaaa")], "aa"), 2)
        XCTAssertEqual(count([body("a", "il gatto e il gatto")], "gatto"), 2)
    }

    func test_wholeWord_respectsLettersAndDigits_butNotApostrophesOrHyphens() {
        let s = [body("a", "L'obbligazione e le obbligazioni del socio-economico; articolo, art. 12, 120.")]
        XCTAssertEqual(count(s, "obbligazione", whole: true), 1, "dopo l'apostrofo è parola intera")
        XCTAssertEqual(count(s, "obbligazion", whole: false), 2)
        XCTAssertEqual(count(s, "obbligazion", whole: true), 0)
        XCTAssertEqual(count(s, "economico", whole: true), 1, "il trattino è un confine")
        XCTAssertEqual(count(s, "art", whole: true), 1, "non dentro «articolo»")
        XCTAssertEqual(count(s, "12", whole: true), 1, "non dentro «120»")
        XCTAssertEqual(count(s, "art.", whole: true), 1, "il punto finale non chiede confine")
    }

    func test_wholeWord_rejectedCandidateDoesNotConsume() {
        XCTAssertEqual(count([body("a", "xab ab")], "ab", whole: true), 1)
        XCTAssertEqual(count([body("a", "abab ab")], "ab", whole: true), 1)
    }

    func test_phraseAcrossTwoBodyBlocks_isFound_andStartsInTheFirst() {
        let s = [body("p#0", "Il quaderno blu racconta"), body("p#1", "una storia di nuvole lente.")]
        let corpus = BookSearchCorpus(segments: s)
        let r = corpus.search("racconta una storia")
        XCTAssertEqual(r.totalCount, 1)
        XCTAssertEqual(r.hits.first?.segmentIndex, 0)
        XCTAssertEqual(r.hits.first?.endSegmentIndex, 1)
        XCTAssertEqual(r.elementIndices, [0])
    }

    func test_noteReadInsideTheBody_doesNotBreakTheBody_andIsSearchedOnItsOwn() {
        let s = [body("p#0", "La lampada si accende 3"), note("n3", "3 Lampada di ottone verde."),
                 body("p#1", "e la stanza diventa gialla.")]
        XCTAssertEqual(count(s, "accende 3 e la stanza"), 1, "il corpo resta unito attorno alla nota")
        XCTAssertEqual(count(s, "ottone verde"), 1)
        XCTAssertEqual(count(s, "verde. e la stanza"), 0, "fra nota e corpo non c'è frase")
        XCTAssertEqual(count(s, "accende 3 3 lampada"), 0)
    }

    func test_phraseAcrossNotePieces_isFound_evenWithAVisualResourceInBetween() {
        let vr = seg("vr_p1_0", VISUAL_RESOURCE_ROLE, "Tabella, pagina 2")
        let s = [note("n7", "7 Lo sciame di api ronza sul davanzale."), vr,
                 piece("n7#1", "Poi il giardino torna muto."), body("b", "Corpo dopo.")]
        let corpus = BookSearchCorpus(segments: s)
        let r = corpus.search("davanzale. poi il giardino")
        XCTAssertEqual(r.totalCount, 1)
        XCTAssertEqual(r.hits.first?.isInNote, true)
        XCTAssertEqual(r.hits.first?.segmentIndex, 0)
        XCTAssertEqual(r.hits.first?.endSegmentIndex, 2)
        XCTAssertEqual(count(s, "tabella"), 0, "l'annuncio della risorsa visiva non si cerca")
    }

    func test_twoNotesInARow_doNotJoin() {
        let s = [note("n1", "1 Fine della prima."), note("n2", "2 Inizio della seconda.")]
        XCTAssertEqual(count(s, "prima. 2 inizio"), 0)
        XCTAssertEqual(count(s, "della"), 2)
    }

    func test_sectionDividers_areNotSearched() {
        let s = [seg("d", SECTION_DIVIDER_ROLE, "Contenitore sintetico"), body("b", "testo vero")]
        XCTAssertEqual(count(s, "contenitore"), 0)
        XCTAssertEqual(count(s, "testo vero"), 1)
    }

    func test_hitsAreInReadingOrder_withNotesInterleaved() {
        let s = [body("a", "uno verde"), note("n1", "1 verde in nota"), body("b", "due verde")]
        let r = BookSearchCorpus(segments: s).search("verde")
        XCTAssertEqual(r.hits.map(\.segmentIndex), [0, 1, 2])
        XCTAssertEqual(r.hits.map(\.isInNote), [false, true, false])
    }

    func test_emptyOrPunctuationOnlyQuery_isEmpty() {
        let corpus = BookSearchCorpus(segments: [body("a", "qualcosa")])
        XCTAssertTrue(corpus.search("   ").isEmptyQuery)
        XCTAssertTrue(corpus.search("\u{00AD}").isEmptyQuery)
        XCTAssertFalse(corpus.search("-").isEmptyQuery)
    }

    func test_limitKeepsTheExactCount() {
        let s = (0..<30).map { body("b\($0)", "seme seme") }
        let r = BookSearchCorpus(segments: s).search("seme", limit: 10)
        XCTAssertEqual(r.totalCount, 60)
        XCTAssertEqual(r.hits.count, 10)
        XCTAssertTrue(r.isTruncated)
    }

    // MARK: Fermate, numeri d'ordine, posizioni

    func test_elementStops_andOrdinals() {
        let s = [body("a", "nebbia e nebbia"), body("b", "sole"), body("c", "nebbia")]
        let r = BookSearchCorpus(segments: s).search("nebbia")
        XCTAssertEqual(r.elementIndices, [0, 2])
        XCTAssertEqual(r.ordinals(inElement: 0), 1...2)
        XCTAssertEqual(r.ordinals(inElement: 2), 3...3)
        XCTAssertNil(r.ordinals(inElement: 1))
        XCTAssertEqual(r.adjacentElement(from: 0, forward: true), 2)
        XCTAssertEqual(r.adjacentElement(from: 1, forward: true), 2)
        XCTAssertNil(r.adjacentElement(from: 2, forward: true))
        XCTAssertEqual(r.adjacentElement(from: 2, forward: false), 0)
        XCTAssertNil(r.adjacentElement(from: 0, forward: false))
        XCTAssertEqual(r.adjacentElement(from: -1, forward: true), 0)
    }

    func test_hitsTouching_includeAPhraseArrivingFromTheBlockBefore() {
        let s = [body("p#0", "Il vento soffia forte"), body("p#1", "sulla collina verde."), body("p#2", "verde ancora")]
        let r = BookSearchCorpus(segments: s).search("forte sulla")
        XCTAssertEqual(r.hits(touching: 0).count, 1)
        XCTAssertEqual(r.hits(touching: 1).count, 1, "la frase arriva a cavallo dal blocco prima")
        XCTAssertEqual(r.hits(touching: 2).count, 0)
    }

    func test_highlightRanges_mapBackToTheOriginalText() {
        let text = "Il «Ponte» 🌉 sull’Àdige è lungo; il ponte è alto."
        let s = [body("a", text)]
        let corpus = BookSearchCorpus(segments: s)
        let r = corpus.search("ponte")
        XCTAssertEqual(r.totalCount, 2)
        let ranges = corpus.highlightRanges(forSegment: 0, text: text, hits: r.hits)
        let ns = text as NSString
        XCTAssertEqual(ranges.map { ns.substring(with: $0) }, ["Ponte", "ponte"])
        let adige = corpus.search("l'adige")
        let r2 = corpus.highlightRanges(forSegment: 0, text: text, hits: adige.hits)
        XCTAssertEqual(r2.map { ns.substring(with: $0) }, ["l’Àdige"])
    }

    func test_highlightRanges_ofAPhraseAcrossTwoBlocks_coverBothParts() {
        let s = [body("p#0", "La strada sale verso"), body("p#1", "il colle alto.")]
        let corpus = BookSearchCorpus(segments: s)
        let r = corpus.search("verso il colle")
        let a = corpus.highlightRanges(forSegment: 0, text: s[0].text, hits: r.hits)
        let b = corpus.highlightRanges(forSegment: 1, text: s[1].text, hits: r.hits)
        XCTAssertEqual(a.map { (s[0].text as NSString).substring(with: $0) }, ["verso"])
        XCTAssertEqual(b.map { (s[1].text as NSString).substring(with: $0) }, ["il colle"])
    }

    func test_snippet_containsTheMatch_withEllipsesWhereCut() {
        let long = String(repeating: "parola ", count: 30) + "TROVAMI qui " + String(repeating: "altra ", count: 30)
        let s = [body("a", long)]
        let corpus = BookSearchCorpus(segments: s)
        let r = corpus.search("trovami")
        let sn = corpus.snippet(for: r.hits[0], segments: s, radius: 40)
        XCTAssertEqual((sn.text as NSString).substring(with: sn.match), "TROVAMI")
        XCTAssertTrue(sn.text.hasPrefix("…"))
        XCTAssertTrue(sn.text.hasSuffix("…"))
        XCTAssertLessThan(sn.text.count, 120)
    }

    func test_snippet_ofAPhraseAcrossBlocks_joinsTheParts() {
        let s = [body("p#0", "Il fiume corre veloce"), body("p#1", "verso il mare grande.")]
        let corpus = BookSearchCorpus(segments: s)
        let r = corpus.search("veloce verso il")
        let sn = corpus.snippet(for: r.hits[0], segments: s)
        XCTAssertEqual((sn.text as NSString).substring(with: sn.match), "veloce verso il")
        XCTAssertTrue(sn.text.hasSuffix("mare grande."))
    }

    func test_headingOfAHit_isTheNearestTitleBefore_evenForANoteReadLater() {
        let s = [heading("h1", "Capitolo del vento"), body("a", "brezza leggera"), heading("h2", "Capitolo della pioggia"),
                 body("b", "goccia"), note("n1", "1 brezza nella nota")]
        let corpus = BookSearchCorpus(segments: s)
        let r = corpus.search("brezza")
        XCTAssertEqual(r.hits.compactMap { corpus.headingIndex(for: $0) }, [0, 2])
    }

    func test_normativeText_articleHeaderIsTheSection() {
        let s = [seg("art1", "ARTICLE_HEADER", "Art. 1. Delle stelle"), body("c1", "Le stelle cadenti si contano."),
                 seg("art2", "ARTICLE_HEADER", "Art. 2. Dei pianeti"), body("c2", "I pianeti girano.")]
        let corpus = BookSearchCorpus(segments: s)
        let r = corpus.search("pianeti")
        XCTAssertEqual(r.totalCount, 2)
        XCTAssertEqual(corpus.headingIndex(for: r.hits[0]), 2, "nel titolo dell'articolo stesso")
        XCTAssertEqual(corpus.headingIndex(for: r.hits[1]), 2)
    }

    func test_dehyphenatedWordsOfTheReading_areFoundWhole() {
        // La catena ricompone le parole spezzate a fine riga: si cerca il testo della lettura, non il PDF.
        let s = [body("a", "La responsabilità contrattuale si estende.")]
        XCTAssertEqual(count(s, "responsabilita", whole: true), 1)
        XCTAssertEqual(count(s, "responsa- bilita"), 0)
    }

    // MARK: Frasi

    func test_wording_countSentences() {
        let corpus = BookSearchCorpus(segments: [body("a", "uno due due")])
        XCTAssertEqual(BookSearchWording.countSentence(corpus.search("uno")), "Un risultato per «uno».")
        XCTAssertEqual(BookSearchWording.countSentence(corpus.search("due")), "2 risultati per «due».")
        let none = BookSearchWording.countSentence(corpus.search("tre", options: BookSearchOptions(wholeWord: true)))
        XCTAssertTrue(none.hasPrefix("Nessun risultato per «tre»."), none)
        XCTAssertTrue(none.contains("togliere «Parola intera»"), none)
        let phrase = BookSearchWording.countSentence(corpus.search("tre quattro"))
        XCTAssertTrue(phrase.contains("meno parole"), phrase)
        XCTAssertEqual(BookSearchWording.countSentence(corpus.search(" ")), "Scrivi una parola o una frase da cercare nel libro.")
        let many = BookSearchCorpus(segments: (0..<3).map { body("b\($0)", "x x") }).search("x", limit: 2)
        XCTAssertTrue(BookSearchWording.countSentence(many).contains("Qui sotto i primi 2"))
    }

    func test_wording_positionValue_andNumbers() {
        XCTAssertEqual(BookSearchWording.positionValue(ordinals: 4...4, total: 12), "risultato 4 di 12")
        XCTAssertEqual(BookSearchWording.positionValue(ordinals: 4...5, total: 12), "risultati 4 e 5 di 12")
        XCTAssertEqual(BookSearchWording.positionValue(ordinals: 4...6, total: 12345), "risultati da 4 a 6 di 12.345")
        XCTAssertEqual(BookSearchWording.noteNumber("12 Vedi sopra."), "12")
        XCTAssertEqual(BookSearchWording.noteNumber("(3) Altra."), "3")
        XCTAssertNil(BookSearchWording.noteNumber("Nota senza numero"))
        XCTAssertEqual(BookSearchWording.rowLabel(snippet: "…il ponte…", inNote: true, noteNumber: "4",
                                                 section: "Capitolo dei ponti", page: 12),
                       "…il ponte… Nella nota 4, Capitolo dei ponti, pagina 12.")
        XCTAssertEqual(BookSearchWording.rowLabel(snippet: "Titolo", inNote: false, noteNumber: nil,
                                                 section: "Titolo", page: nil, isHeadingItself: true),
                       "Titolo. Nel titolo.")
        XCTAssertEqual(BookSearchWording.rowLabel(snippet: "testo", inNote: false, noteNumber: nil, section: nil, page: nil),
                       "testo")
    }
}
