//
//  ContentAnchorTests.swift
//  ScaboCoreTests
//
//  Le ancore per contenuto (ContentAnchor.swift) e il riancoraggio (AnnotationReanchoring.swift).
//  Testi SINTETICI e neutri: nessun frammento di volume.
//

import XCTest
@testable import ScaboCore

final class ContentAnchorTests: XCTestCase {

    // MARK: - Fixture

    private func seg(_ id: String, _ text: String, role: String = "BODY", page: Int? = 1) -> ContentSegment {
        ContentSegment(id: id, role: role, text: text, lengthCategory: "", acousticIntro: "", sourcePage: page)
    }

    /// Un flusso di prova: frasi lunghe e distinte (sopra `edgeLength`), più etichette corte ripetute.
    private func flow() -> [ContentSegment] {
        [
            seg("node_0", "Capitolo primo", role: "HEADING_2", page: 1),
            seg("node_1", "La prima frase del capitolo parla della brezza che scende dalla collina verso il lago al tramonto.", page: 1),
            seg("node_2", "La seconda frase racconta del faro acceso sulla scogliera e del vento che piega gli ulivi.", page: 1),
            seg("node_3", "(1) Una nota breve a piè di pagina che rimanda al secondo capitolo per il seguito.", role: "NOTE", page: 1),
            seg("node_4", "(Omissis).", page: 2),
            seg("node_5", "La terza frase apre la seconda pagina con il racconto del mulino e del fiume in piena.", page: 2),
            seg("node_6", "(Omissis).", page: 2),
            seg("node_7", "La quarta frase chiude il capitolo con la neve sui tetti e il silenzio della valle addormentata.", page: 2),
        ]
    }

    // MARK: - Normalizzazione

    func test_normalize_ignoresSpacingHyphenationPunctuationAndPlaceholders() {
        let a = TextFingerprint.normalize("La brez-za scen-de, dalla collina!")
        let b = TextFingerprint.normalize("Labrezza scende dalla   collina \u{FFFC}")
        XCTAssertEqual(a, b)
        XCTAssertEqual(a, "labrezzascendedallacollina")
        XCTAssertEqual(TextFingerprint.normalize("Città 1992 — ÀÈ"), "città1992àè")
        XCTAssertEqual(TextFingerprint.normalize("... — ( )"), "")
    }

    func test_digest_isStableAndTextFree() {
        let d = TextFingerprint.digest("abc")
        XCTAssertEqual(d.count, 32)
        XCTAssertEqual(d, TextFingerprint.digest("abc"))
        XCTAssertNotEqual(d, TextFingerprint.digest("abd"))
        XCTAssertFalse(d.contains("abc"))
    }

    func test_wordMap_mapsNormalizedCharsBackToWords() {
        let (chars, words) = TextFingerprint.normalizeWithWordMap("Uno, due  tre-quattro.")
        XCTAssertEqual(String(chars), "unoduetrequattro")
        XCTAssertEqual(words.first, 0)
        XCTAssertEqual(words[3], 1)        // 'd' di due
        XCTAssertEqual(words.last, 2)      // 'o' di tre-quattro (una parola: run di non-spazi)
    }

    // MARK: - Conio

    func test_anchor_carriesFingerprintsNotText() throws {
        let index = ContentAnchorIndex(segments: flow())
        let a = try XCTUnwrap(index.anchor(forIndex: 1))
        XCTAssertEqual(a.role, "BODY")
        XCTAssertEqual(a.sourcePage, 1)
        XCTAssertGreaterThan(a.length, TextFingerprint.edgeLength)
        XCTAssertNotEqual(a.head, a.tail)
        XCTAssertNotEqual(a.whole, a.head)
        XCTAssertEqual(a.orderIndexHint, 1)
        let json = String(decoding: try JSONEncoder().encode(a), as: UTF8.self)
        XCTAssertFalse(json.lowercased().contains("brezza"), "l'ancora non deve portare testo")
    }

    func test_anchor_shortText_headEqualsTailEqualsWhole_withPageRank() throws {
        let index = ContentAnchorIndex(segments: flow())
        let first = try XCTUnwrap(index.anchor(forIndex: 4))
        let second = try XCTUnwrap(index.anchor(forIndex: 6))
        XCTAssertEqual(first.whole, first.head)
        XCTAssertEqual(first.whole, first.tail)
        XCTAssertEqual(first.pageOccurrence, 0)
        XCTAssertEqual(second.pageOccurrence, 1)
        XCTAssertEqual(second.pageOccurrenceCount, 2)
    }

    // MARK: - Risoluzione: la scala

    func test_resolve_exact_sameContentDifferentIdsAndSpacing() throws {
        let old = ContentAnchorIndex(segments: flow())
        let a = try XCTUnwrap(old.anchor(forIndex: 5))
        // Rielaborazione: un nodo in meno prima (gli id scalano), spazi diversi (generazione 26 vs 27).
        var new = flow(); new.remove(at: 0)
        new[4] = seg("node_4", "La terza frase apre la seconda pagina con il racconto del mulino edel fiume in piena.", page: 2)
        let r = ContentAnchorIndex(segments: new).resolve(a)
        XCTAssertEqual(r.level, .exact)
        XCTAssertEqual(r.index, 4)
        XCTAssertEqual(new[4].id, "node_4") // lo stesso id di prima indicava un ALTRO passo: l'ancora non ci casca
    }

    func test_resolve_contained_whenSegmentsWereMerged() throws {
        let old = ContentAnchorIndex(segments: flow())
        let a = try XCTUnwrap(old.anchor(forIndex: 2))
        var new = flow()
        let merged = new[1].text + " " + new[2].text
        new.remove(at: 2)
        new[1] = seg("node_1", merged, page: 1)
        let r = ContentAnchorIndex(segments: new).resolve(a)
        XCTAssertEqual(r.level, .contained)
        XCTAssertEqual(r.index, 1)
    }

    func test_resolve_headOnly_whenSegmentWasSplit() throws {
        let old = ContentAnchorIndex(segments: flow())
        let a = try XCTUnwrap(old.anchor(forIndex: 7))
        var new = flow()
        let words = new[7].text.split(separator: " ")
        new[7] = seg("node_7", words.prefix(8).joined(separator: " "), page: 2)
        new.append(seg("node_8", words.dropFirst(8).joined(separator: " "), page: 2))
        let r = ContentAnchorIndex(segments: new).resolve(a)
        XCTAssertEqual(r.level, .headOnly)
        XCTAssertEqual(r.index, 7)
        XCTAssertGreaterThanOrEqual(r.confidence, ContentAnchorIndex.relocationThreshold)
    }

    func test_resolve_headAndTail_whenInnerTextChanged() throws {
        let old = ContentAnchorIndex(segments: flow())
        let a = try XCTUnwrap(old.anchor(forIndex: 1))
        var new = flow()
        new[1] = seg("node_1", "La prima frase del capitolo parla della brezza che SALE dalla collina verso il lago al tramonto.", page: 1)
        let r = ContentAnchorIndex(segments: new).resolve(a)
        XCTAssertEqual(r.level, .headAndTail)
        XCTAssertEqual(r.index, 1)
    }

    func test_resolve_tailOnly_isOrphan() throws {
        let old = ContentAnchorIndex(segments: flow())
        let a = try XCTUnwrap(old.anchor(forIndex: 1))
        var new = flow()
        new[1] = seg("node_1", "Un inizio del tutto diverso da prima, e poi la brezza che scende dalla collina verso il lago al tramonto.", page: 1)
        let r = ContentAnchorIndex(segments: new).resolve(a)
        XCTAssertEqual(r.level, .orphan)
        XCTAssertNil(r.index)
    }

    func test_resolve_removedSegment_isOrphan_neverTheSameIdElsewhere() throws {
        let old = ContentAnchorIndex(segments: flow())
        let a = try XCTUnwrap(old.anchor(forIndex: 3))   // la nota
        var new = flow(); new.remove(at: 3)               // la cura la toglie; node_3 ora è un altro testo
        let r = ContentAnchorIndex(segments: new).resolve(a)
        XCTAssertEqual(r.level, .orphan)
        XCTAssertNil(r.index)
    }

    // MARK: - Ambiguità → orfana, mai un salto sicuro nel posto sbagliato

    func test_resolve_repeatedShortTextOnSamePage_usesRankOnlyIfCountUnchanged() throws {
        let old = ContentAnchorIndex(segments: flow())
        let second = try XCTUnwrap(old.anchor(forIndex: 6))
        // Stesso numero di «(Omissis).» nella pagina: il rango decide.
        var same = flow(); same.remove(at: 0)
        XCTAssertEqual(ContentAnchorIndex(segments: same).resolve(second).index, 5)
        // Un'occorrenza in più nella pagina: il rango non dice più nulla → orfana.
        var more = flow(); more.insert(seg("node_x", "(Omissis).", page: 2), at: 5)
        let r = ContentAnchorIndex(segments: more).resolve(second)
        XCTAssertEqual(r.level, .orphan)
        XCTAssertTrue(r.reason.contains("candidati equivalenti"))
    }

    func test_resolve_recurringHeaderOnManyPages_isOrphanWhenItsPageLostIt() throws {
        var pages = flow()
        for p in 1...4 { pages.append(seg("node_h\(p)", "Titolo corrente ripetuto in testa a ogni pagina del volume", role: "NOTE", page: p + 2)) }
        let old = ContentAnchorIndex(segments: pages)
        let a = try XCTUnwrap(old.anchor(forIndex: pages.count - 2))   // la testatina di pagina 5
        // La cura toglie la testatina di pagina 5 ma non le altre (caso limite): orfana, non «la più vicina».
        var new = pages; new.remove(at: pages.count - 2)
        let r = ContentAnchorIndex(segments: new).resolve(a)
        XCTAssertEqual(r.level, .orphan)
    }

    func test_resolve_exactMatchFarAway_isAcceptedOnlyIfLongAndUnique() throws {
        let old = ContentAnchorIndex(segments: flow())
        let longOne = try XCTUnwrap(old.anchor(forIndex: 5))
        let shortOne = try XCTUnwrap(old.anchor(forIndex: 4))
        var new = flow()
        new[5] = seg("node_5", new[5].text, page: 40)   // il testo lungo è migrato a pagina 40 (unico)
        new[4] = seg("node_4", new[4].text, page: 40)   // i due testi corti pure
        new[6] = seg("node_6", new[6].text, page: 41)
        XCTAssertEqual(ContentAnchorIndex(segments: new).resolve(longOne).level, .exact)
        let r = ContentAnchorIndex(segments: new).resolve(shortOne)
        XCTAssertEqual(r.level, .orphan, "un testo corto ritrovato lontano è troppo debole")
        XCTAssertTrue(r.reason.contains("lontano"))
    }

    // MARK: - Citazioni (sottolineature)

    func test_quoteAnchor_resolvesWordsAcrossSpacingChange() throws {
        let old = ContentAnchorIndex(segments: flow())
        let q = try XCTUnwrap(old.quoteAnchor(forIndex: 2, startWord: 5, endWord: 7))   // tre parole
        var new = flow(); new.remove(at: 0)
        new[1] = seg("node_1", "La seconda frase racconta  del faro ac-ceso sulla scogliera e del vento che piega gli ulivi.", page: 1)
        let r = try XCTUnwrap(ContentAnchorIndex(segments: new).resolve(q))
        XCTAssertEqual(r.segmentIndex, 1)
        let words = WordTokenizer.words(new[1].text)
        XCTAssertEqual(words[r.startWord...r.endWord].joined(separator: " "), "faro ac-ceso sulla")
    }

    func test_quoteAnchor_repeatedQuote_disambiguatedByContext_orOrphan() throws {
        let text = "alfa beta gamma delta alfa beta gamma omega alfa beta gamma delta fine"
        let index = ContentAnchorIndex(segments: [seg("node_0", text)])
        let q = try XCTUnwrap(index.quoteAnchor(forIndex: 0, startWord: 4, endWord: 6))   // il secondo «alfa beta gamma»
        let r = try XCTUnwrap(index.resolve(q))
        XCTAssertEqual(r.startWord, 4)
        // Senza contesto distinguibile (testo periodico: prefisso e suffisso uguali per ogni ripetizione): orfana.
        let periodic = Array(repeating: "ab", count: 40).joined(separator: " ")
        let twin = ContentAnchorIndex(segments: [seg("node_0", periodic)])
        let q2 = try XCTUnwrap(twin.quoteAnchor(forIndex: 0, startWord: 18, endWord: 19))
        XCTAssertNil(twin.resolve(q2))
    }

    func test_quoteAnchor_isOrphanWhenWordsVanished() throws {
        let old = ContentAnchorIndex(segments: flow())
        let q = try XCTUnwrap(old.quoteAnchor(forIndex: 1, startWord: 9, endWord: 11))
        var new = flow()   // le parole 9-11 non ci sono più, il resto del segmento sì
        new[1] = seg("node_1", "La prima frase del capitolo parla della brezza che va verso il lago al tramonto.", page: 1)
        XCTAssertNil(ContentAnchorIndex(segments: new).resolve(q))
    }

    // MARK: - Riancoraggio completo

    func test_reanchor_relocatesOrphansAndCounts() throws {
        let oldFlow = flow()
        let old = ContentAnchorIndex(segments: oldFlow)
        let b1 = Bookmark(id: "b1", anchorSegmentId: "node_5", orderIndexHint: 5, preview: "", originalPage: 2,
                          createdAt: Date(), anchor: old.anchor(forIndex: 5))
        let b2 = Bookmark(id: "b2", anchorSegmentId: "node_3", orderIndexHint: 3, preview: "", originalPage: 1,
                          createdAt: Date(), anchor: old.anchor(forIndex: 3))
        let legacy = Bookmark(id: "b3", anchorSegmentId: "node_7", orderIndexHint: 7, preview: "", createdAt: Date())
        let u = Underline(id: "u1", spans: [UnderlineSpan(segmentId: "node_7", startWord: 2, endWord: 4,
                                                          anchor: old.quoteAnchor(forIndex: 7, startWord: 2, endWord: 4))],
                          preview: "", createdAt: Date())
        var new = oldFlow; new.remove(at: 3)   // la nota sparisce: tutto scala di uno
        let out = AnnotationReanchoring.reanchor(bookmarks: [b1, b2, legacy], underlines: [u], readingPosition: 7,
                                                 readingAnchor: old.anchor(forIndex: 7), in: ContentAnchorIndex(segments: new))
        XCTAssertEqual(out.report.bookmarksRelocated, 1)
        XCTAssertEqual(out.report.bookmarksOrphaned, 1)
        XCTAssertEqual(out.report.bookmarksWithoutAnchor, 1)
        XCTAssertEqual(out.bookmarks[0].orderIndexHint, 4)               // ricollocato per contenuto (l'indice scala)
        XCTAssertEqual(out.bookmarks[0].anchorSegmentId, new[4].id)
        XCTAssertEqual(out.bookmarks[1].isOrphan, true)                  // la nota non c'è più
        XCTAssertEqual(out.bookmarks[1].anchorSegmentId, "node_3")       // posizione corrente invariata, dichiarata orfana
        XCTAssertEqual(out.bookmarks[2].isOrphan, true)                  // senza ancora: mai per id
        XCTAssertEqual(out.report.underlinesRelocated, 1)
        XCTAssertEqual(out.underlines[0].spans[0].segmentId, new[6].id)
        XCTAssertEqual(out.readingPosition, 6)
        XCTAssertFalse(out.readingPositionIsApproximate)
        XCTAssertEqual(out.report.positionLevel, .exact)
    }

    func test_reanchor_positionFallsBackToPage_andSaysSo() throws {
        let old = ContentAnchorIndex(segments: flow())
        var new = flow(); new.remove(at: 7)
        let out = AnnotationReanchoring.reanchor(bookmarks: [], underlines: [], readingPosition: 7,
                                                 readingAnchor: old.anchor(forIndex: 7), in: ContentAnchorIndex(segments: new))
        XCTAssertTrue(out.readingPositionIsApproximate)
        XCTAssertTrue(out.report.positionByPage)
        XCTAssertEqual(new[out.readingPosition].sourcePage, 2)
    }

    func test_mintMissingAnchors_usesCurrentIdsAtStableContent() throws {
        let index = ContentAnchorIndex(segments: flow())
        let legacy = Bookmark(id: "b", anchorSegmentId: "node_2", orderIndexHint: 2, preview: "", createdAt: Date())
        let u = Underline(id: "u", spans: [UnderlineSpan(segmentId: "node_5", startWord: 0, endWord: 1)], preview: "", createdAt: Date())
        let out = AnnotationReanchoring.mintMissingAnchors(bookmarks: [legacy], underlines: [u], readingPosition: 1,
                                                           readingAnchor: nil, in: index)
        XCTAssertEqual(out.minted, 3)
        XCTAssertEqual(out.bookmarks[0].anchor, index.anchor(forIndex: 2))
        XCTAssertNotNil(out.underlines[0].spans[0].anchor)
        XCTAssertEqual(out.readingAnchor, index.anchor(forIndex: 1))
        // Idempotente: non riconia ciò che c'è già.
        let again = AnnotationReanchoring.mintMissingAnchors(bookmarks: out.bookmarks, underlines: out.underlines,
                                                             readingPosition: 1, readingAnchor: out.readingAnchor, in: index)
        XCTAssertEqual(again.minted, 0)
    }

    func test_libraryJSON_withoutAnchorFields_stillDecodes() throws {
        let json = """
        {"id":"b","anchorSegmentId":"node_1","orderIndexHint":1,"preview":"","tagIds":[],"createdAt":0}
        """
        let b = try JSONDecoder().decode(Bookmark.self, from: Data(json.utf8))
        XCTAssertNil(b.anchor)
        XCTAssertNil(b.isOrphan)
    }

    func test_indexBuild_isFastEnoughOnACodeSizedFlow() {
        var many: [ContentSegment] = []
        for i in 0..<47_000 {
            many.append(seg("node_\(i)", "Articolo \(i). Testo di prova sufficientemente lungo per avere testa e coda distinte nel segmento numero \(i).", page: i / 20 + 1))
        }
        let start = Date()
        let index = ContentAnchorIndex(segments: many)
        let built = Date().timeIntervalSince(start)
        let a = index.anchor(forIndex: 30_000)!
        let r = index.resolve(a)
        XCTAssertEqual(r.index, 30_000)
        XCTAssertLessThan(built, 5.0, "indice su 47k segmenti costruito in \(built) s")
    }
}
