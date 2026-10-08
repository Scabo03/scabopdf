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
            seg("node_1", "La prima frase del capitolo parla della brezza che scende dalla collina verso il lago al tramonto, quando le barche rientrano e i pescatori contano le reti.", page: 1),
            seg("node_2", "La seconda frase racconta del faro acceso sulla scogliera e del vento che piega gli ulivi, mentre il guardiano annota le ore sul registro di bordo.", page: 1),
            seg("node_3", "(1) Una nota breve a piè di pagina che rimanda al secondo capitolo per il seguito della vicenda e per le fonti citate dall'autore.", role: "NOTE", page: 1),
            seg("node_4", "(Omissis).", page: 2),
            seg("node_5", "La terza frase apre la seconda pagina con il racconto del mulino e del fiume in piena, delle chiuse aperte di notte e del grano portato a valle.", page: 2),
            seg("node_6", "(Omissis).", page: 2),
            seg("node_7", "La quarta frase chiude il capitolo con la neve sui tetti e il silenzio della valle addormentata, finché il primo carro non rompe il gelo della strada.", page: 2),
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
        XCTAssertEqual(first.windowRank, 0)
        XCTAssertEqual(second.windowRank, 1)
        XCTAssertEqual(second.windowCount, 2)
    }

    // MARK: - Risoluzione: la scala

    func test_resolve_exact_sameContentDifferentIdsAndSpacing() throws {
        let old = ContentAnchorIndex(segments: flow())
        let a = try XCTUnwrap(old.anchor(forIndex: 5))
        // Rielaborazione: un nodo in meno prima (gli id scalano), spazi diversi (generazione 26 vs 27).
        var new = flow(); new.remove(at: 0)
        new[4] = seg("node_4", "La terza frase apre la seconda pagina con il racconto del mulino edel fiume in piena, delle chiuse aperte di notte e del grano portato a valle.", page: 2)
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
        let long = "La quarta frase chiude il capitolo con la neve sui tetti e il silenzio della valle addormentata, finché il primo carro non rompe il gelo della strada maestra; poi vengono i cani del pastore, le campane della pieve, il fumo dei camini accesi uno dopo l'altro lungo la via che sale verso il castello, e infine la voce del banditore che annuncia il mercato del giovedì nella piazza grande sotto la torre."
        var base = flow(); base[7] = seg("node_7", long, page: 2)
        let oldLong = ContentAnchorIndex(segments: base)
        let aLong = try XCTUnwrap(oldLong.anchor(forIndex: 7))
        let words = long.split(separator: " ")
        new = base
        new[7] = seg("node_7", words.prefix(32).joined(separator: " "), page: 2)   // ≥ 128 lettere, pezzo iniziale
        new.append(seg("node_8", words.dropFirst(32).joined(separator: " "), page: 2))
        let r = ContentAnchorIndex(segments: new).resolve(aLong)
        XCTAssertEqual(r.level, .headOnly)
        XCTAssertEqual(r.index, 7)
        XCTAssertGreaterThanOrEqual(r.confidence, ContentAnchorIndex.relocationThreshold)
        // Un pezzo iniziale sotto le 128 lettere è troppo poco: orfana, dichiarata.
        var tiny = base
        tiny[7] = seg("node_7", words.prefix(12).joined(separator: " "), page: 2)
        tiny.append(seg("node_8", words.dropFirst(12).joined(separator: " "), page: 2))
        XCTAssertEqual(ContentAnchorIndex(segments: tiny).resolve(aLong).level, .orphan)
        _ = a
    }

    func test_resolve_headAndTail_whenInnerTextChanged() throws {
        // Testa (64) e coda (64) uguali, interno diverso: l'ordine delle righe cambiato da una generazione.
        let head = "La prima frase del capitolo parla della brezza che scende dalla collina verso il lago"
        let tail = "quando le barche rientrano in porto e i pescatori contano le reti sulla banchina del molo"
        var base = flow()
        base[1] = seg("node_1", head + " al tramonto, con le prime luci del paese che si accendono una dopo l'altra, " + tail, page: 1)
        let old = ContentAnchorIndex(segments: base)
        let a = try XCTUnwrap(old.anchor(forIndex: 1))
        var new = base
        new[1] = seg("node_1", head + " con le prime luci del paese che si accendono una dopo l'altra, al tramonto, " + tail, page: 1)
        let r = ContentAnchorIndex(segments: new).resolve(a)
        XCTAssertEqual(r.level, .headAndTail)
        XCTAssertEqual(r.index, 1)
    }

    func test_resolve_tailOnly_isOrphan() throws {
        let old = ContentAnchorIndex(segments: flow())
        let a = try XCTUnwrap(old.anchor(forIndex: 1))
        var new = flow()
        new[1] = seg("node_1", "Un inizio del tutto diverso da prima, e poi la brezza che scende dalla collina verso il lago al tramonto, quando le barche rientrano e i pescatori contano le reti.", page: 1)
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

    func test_resolve_contained_requiresARealAddition_notJustAFolio() throws {
        // Il titolo del paragrafo più il folio (la testatina corrente) non è una fusione del titolo.
        let old = ContentAnchorIndex(segments: flow())
        let a = try XCTUnwrap(old.anchor(forIndex: 5))
        var new = flow(); new[5] = seg("node_5", flow()[5].text + " 341", page: 2)
        let r = ContentAnchorIndex(segments: new).resolve(a)
        XCTAssertEqual(r.level, .orphan)
    }

    func test_resolve_containedInTheMiddle_isOrphan_notAMerge() throws {
        // Un titolo citato DENTRO un sommario non è una fusione: solo le estremità contano.
        let old = ContentAnchorIndex(segments: flow())
        let a = try XCTUnwrap(old.anchor(forIndex: 5))
        var new = flow(); new.remove(at: 5)
        new.insert(seg("node_x", "Sommario del capitolo: " + flow()[5].text + " E poi il resto del sommario con gli altri paragrafi.", page: 2), at: 5)
        XCTAssertEqual(ContentAnchorIndex(segments: new).resolve(a).level, .orphan)
    }

    func test_resolve_headOnly_refusesWhenTheHeadIsRepeatedInTheWindow() throws {
        // Un passo ristampato quasi alla lettera due pagine dopo (stesse prime lettere, coda diversa): tolto il
        // testo originale, la ristampa NON è il primo pezzo di una spezzatura. Regressione vista nella prova al
        // contrario della rete sulle annotazioni (giro finale 2026-10-08).
        let passage = "Quando il mulino di prova resta fermo per la piena, il mugnaio di prova annota sul quaderno verde le ore perse e le sacche di grano rimaste nel magazzino della valle"
        func doc(original: String) -> [ContentSegment] {
            [seg("node_0", "Primo paragrafo di prova che apre la pagina con parole neutre e abbastanza numerose da superare la testa.", page: 10),
             seg("node_1", original, page: 10),
             seg("node_2", "Secondo paragrafo di prova fra le due versioni, con altre parole neutre per riempire la pagina.", page: 11),
             seg("node_3", passage + ".", page: 12),   // la ristampa: più corta del vecchio, stessa testa
             seg("node_4", passage + " (testo previgente ristampato più lungo, con una coda che continua ancora).", page: 12)]
        }
        let old = ContentAnchorIndex(segments: doc(original: passage + " (9). Sei."))
        let a = try XCTUnwrap(old.anchor(forIndex: 1))
        // il testo originale sparisce: due segmenti della finestra hanno la stessa testa → orfana, mai la ristampa
        let gone = doc(original: "Testo sostituito di prova con parole neutre e abbastanza lunghe da avere una testa e una coda distinte.")
        XCTAssertEqual(ContentAnchorIndex(segments: gone).resolve(a).level, .orphan)
        // prova al contrario: senza le ristampe nella finestra la stessa spezzatura si ricolloca
        var split = Array(doc(original: passage + " (9). Sei.").prefix(3))
        split[1] = seg("node_1", passage, page: 10)
        split.insert(seg("node_1b", "(9). Sei.", page: 10), at: 2)
        let r = ContentAnchorIndex(segments: split).resolve(a)
        XCTAssertEqual(r.level, .headOnly)
        XCTAssertEqual(r.index, 1)
    }

    func test_resolve_headOnly_requiresTheNewSegmentToBeAPieceOfTheOld() throws {
        let old = ContentAnchorIndex(segments: flow())
        let a = try XCTUnwrap(old.anchor(forIndex: 5))
        var new = flow()
        // Stesse prime 64 lettere ma PIÙ LUNGO e diverso in coda: non è una spezzatura del vecchio → orfana.
        new[5] = seg("node_5", "La terza frase apre la seconda pagina con il racconto del mulino e del fiume in piena, delle chiuse e di tutt'altro, con una coda diversa e più lunga del testo di partenza.", page: 2)
        XCTAssertEqual(ContentAnchorIndex(segments: new).resolve(a).level, .orphan)
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
        XCTAssertTrue(r.reason.contains("gemelli"))
        // Un gemello SPARITO: il superstite potrebbe essere l'altro → orfana, non «l'unico rimasto».
        var fewer = flow(); fewer.remove(at: 4)
        let r2 = ContentAnchorIndex(segments: fewer).resolve(second)
        XCTAssertEqual(r2.level, .orphan)
    }

    func test_resolve_recurringHeaderOnManyPages_isOrphanWhenItsPageLostIt() throws {
        var pages = flow()
        for p in 1...4 { pages.append(seg("node_h\(p)", "Titolo corrente ripetuto in testa a ogni pagina del volume, con il nome della parte e del capitolo in corso", role: "NOTE", page: p + 2)) }
        let old = ContentAnchorIndex(segments: pages)
        let a = try XCTUnwrap(old.anchor(forIndex: pages.count - 2))   // la testatina di pagina 5
        // La cura toglie la testatina di pagina 5 ma non le altre (caso limite): orfana, non «la più vicina».
        var new = pages; new.remove(at: pages.count - 2)
        let r = ContentAnchorIndex(segments: new).resolve(a)
        XCTAssertEqual(r.level, .orphan)
    }

    func test_resolve_exactMatchFarAway_isOrphan_evenIfLongAndUnique() throws {
        // Un libro non sposta un passo di quaranta pagine; i codici ripetono la stessa nota alla lettera in
        // cento punti: il gemello lontano NON è il passo marcato (rete sulle annotazioni, prova «orfana»).
        let old = ContentAnchorIndex(segments: flow())
        let longOne = try XCTUnwrap(old.anchor(forIndex: 5))
        let shortOne = try XCTUnwrap(old.anchor(forIndex: 4))
        var new = flow()
        new[5] = seg("node_5", new[5].text, page: 40)
        new[4] = seg("node_4", new[4].text, page: 40)
        new[6] = seg("node_6", new[6].text, page: 41)
        let r1 = ContentAnchorIndex(segments: new).resolve(longOne)
        XCTAssertEqual(r1.level, .orphan)
        XCTAssertTrue(r1.reason.contains("lontano"))
        let r = ContentAnchorIndex(segments: new).resolve(shortOne)
        XCTAssertEqual(r.level, .orphan, "un testo corto ritrovato lontano è troppo debole")
        XCTAssertTrue(r.reason.contains("lontano"))
        // Senza pagina d'origine nota, invece, l'unico riscontro esatto lungo vale.
        var noPage = longOne; noPage.sourcePage = nil
        XCTAssertEqual(ContentAnchorIndex(segments: new).resolve(noPage).level, .exact)
        // Un candidato SENZA pagina non passa il filtro quando la pagina d'origine è nota.
        var unknown = flow(); unknown[5] = seg("node_5", unknown[5].text, page: nil)
        XCTAssertEqual(ContentAnchorIndex(segments: unknown).resolve(longOne).level, .orphan)
    }

    // MARK: - Citazioni (sottolineature)

    func test_quoteAnchor_resolvesWordsAcrossSpacingChange() throws {
        let old = ContentAnchorIndex(segments: flow())
        let q = try XCTUnwrap(old.quoteAnchor(forIndex: 2, startWord: 5, endWord: 7))   // tre parole
        var new = flow(); new.remove(at: 0)
        new[1] = seg("node_1", "La seconda frase racconta  del faro ac-ceso sulla scogliera e del vento che piega gli ulivi, mentre il guardiano annota le ore sul registro di bordo.", page: 1)
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
        new[1] = seg("node_1", "La prima frase del capitolo parla della brezza che va verso il lago al tramonto, quando le barche rientrano e i pescatori contano le reti.", page: 1)
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

    func test_orphanUnderline_neverBlocksOrTouchesTheNewSegments() throws {
        let store = LibraryStore(persistence: InMemoryLibraryPersistence())
        let d = store.addDocument(title: "t", sourceFileName: "t.pdf", sourcePageCount: 1)
        let u = try XCTUnwrap(store.addUnderline(documentId: d.id, spans: [UnderlineSpan(segmentId: "node_1", startWord: 0, endWord: 3)], preview: ""))
        var orphan = u; orphan.isOrphan = true
        store.applyAnnotationState(documentId: d.id, bookmarks: [], underlines: [orphan], readingPosition: 0,
                                   readingAnchor: nil, readingPositionIsApproximate: nil)
        XCTAssertTrue(store.underlinesTouching(documentId: d.id, segmentId: "node_1").isEmpty)
        XCTAssertNotNil(store.addUnderline(documentId: d.id, spans: [UnderlineSpan(segmentId: "node_1", startWord: 1, endWord: 2)], preview: ""),
                        "lo stesso id ora indica un altro passo: l'orfana non blocca")
        XCTAssertEqual(store.underlines(documentId: d.id).count, 2, "l'orfana resta salvata")
    }

    func test_verification_detectsAnnotationsWhoseIdNoLongerHoldsTheirContent() throws {
        let old = ContentAnchorIndex(segments: flow())
        let b = Bookmark(id: "b", anchorSegmentId: "node_5", orderIndexHint: 5, preview: "", createdAt: Date(),
                         anchor: old.anchor(forIndex: 5))
        // Contenuto fermo: tutto al suo posto.
        XCTAssertFalse(AnnotationReanchoring.needsReanchoring(bookmarks: [b], underlines: [], readingPosition: 5,
                                                              readingAnchor: old.anchor(forIndex: 5), in: old))
        // Cache nuova ma riancoraggio mai avvenuto (app chiusa a metà): node_5 ora è un altro passo.
        var shifted = flow(); shifted.remove(at: 0)
        let new = ContentAnchorIndex(segments: shifted.enumerated().map { i, s in
            ContentSegment(id: "node_\(i)", role: s.role, text: s.text, lengthCategory: "", acousticIntro: "", sourcePage: s.sourcePage) })
        XCTAssertTrue(AnnotationReanchoring.needsReanchoring(bookmarks: [b], underlines: [], readingPosition: 0,
                                                             readingAnchor: nil, in: new))
        let out = AnnotationReanchoring.reanchor(bookmarks: [b], underlines: [], readingPosition: 0, readingAnchor: nil, in: new)
        XCTAssertEqual(out.bookmarks[0].anchorSegmentId, "node_4", "ritrovato per contenuto")
        XCTAssertFalse(AnnotationReanchoring.needsReanchoring(bookmarks: out.bookmarks, underlines: [], readingPosition: 0,
                                                              readingAnchor: nil, in: new))
    }

    func test_quote_neverMatchesInsideALongerWord() throws {
        let old = ContentAnchorIndex(segments: [seg("node_0", "Il porto di mare accoglie le barche dei pescatori all'alba, prima che il sole scaldi il molo.")])
        let q = try XCTUnwrap(old.quoteAnchor(forIndex: 0, startWord: 1, endWord: 1))   // «porto»
        // La parola è sparita; le stesse lettere restano solo DENTRO una parola più lunga: orfana, non lì.
        let new = ContentAnchorIndex(segments: [seg("node_0", "Il trasporto di mare accoglie le barche dei pescatori all'alba, prima che il sole scaldi il molo.")])
        XCTAssertNil(new.resolve(q))
    }

    func test_anchorsCarryNoText_neitherSegmentNorQuote() throws {
        let index = ContentAnchorIndex(segments: flow())
        let a = try XCTUnwrap(index.anchor(forIndex: 2))
        let q = try XCTUnwrap(index.quoteAnchor(forIndex: 2, startWord: 4, endWord: 6))
        let json = String(decoding: try JSONEncoder().encode(a), as: UTF8.self) + String(decoding: try JSONEncoder().encode(q), as: UTF8.self)
        for word in WordTokenizer.words(flow()[2].text) where word.count >= 4 {
            XCTAssertFalse(json.lowercased().contains(TextFingerprint.normalize(word)), "nessuna parola del testo nell'ancora")
        }
    }

    func test_mintMissingAnchors_neverOnOrphans() {
        let index = ContentAnchorIndex(segments: flow())
        let orphan = Bookmark(id: "o", anchorSegmentId: "node_2", orderIndexHint: 2, preview: "", createdAt: Date(), isOrphan: true)
        let out = AnnotationReanchoring.mintMissingAnchors(bookmarks: [orphan], underlines: [], readingPosition: 0,
                                                           readingAnchor: index.anchor(forIndex: 0), in: index)
        XCTAssertNil(out.bookmarks[0].anchor)
        XCTAssertEqual(out.minted, 0)
    }
}
