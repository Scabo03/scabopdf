//
//  WordSearchTests.swift — la ricerca per parole pesate, la regola del blocco corto e il salto per numero (WordSearch.swift;
//  giro «la ricerca», 2026-11-26). Testi inventati.
//
import XCTest
@testable import ScaboCore

final class WordSearchTests: XCTestCase {
    private func seg(_ i: Int, _ role: String, _ text: String) -> ContentSegment {
        ContentSegment(id: "node_\(i)", role: role, text: text, lengthCategory: "", acousticIntro: "")
    }
    private func body(_ i: Int, _ t: String) -> ContentSegment { seg(i, "BODY", t) }
    private let filler = " parole comuni di riempimento per allungare il blocco oltre la soglia"
    private func sentence(_ r: BookSearchResult) -> String { BookSearchWording.countSentence(r) }

    func test_passages_rankByWeightedWords_exactHitsAndRotorUnchanged() {
        let segs = [body(0, "Il gatto bianco dorme accanto alla stufa accesa." + filler),
                    body(1, "La torre vecchia del borgo ha un orologio fermo e un gufo grigio." + filler),
                    body(2, "Il gufo vola; la torre nuova è senza campane." + filler),
                    body(3, "Altro testo senza le parole cercate." + filler)]
        let r = BookSearchCorpus(segments: segs).search("torre orologio gufo")
        XCTAssertEqual(r.totalCount, 0, "la frase intera non c'è")
        XCTAssertEqual(r.elementIndices, [], "il rotore resta sulle sole occorrenze esatte")
        XCTAssertEqual(r.passages.map(\.segmentIndex), [1, 2])
        XCTAssertTrue(r.passages.allSatisfy { !$0.isJump })
        XCTAssertGreaterThan(r.passages[0].score, r.passages[1].score)
        // Di serie (giro «scansioni, ricerca e build»): prima le corrispondenze esatte, poi i passi.
        XCTAssertEqual(sentence(r), "Nessun risultato esatto. 2 passi con le parole di «torre orologio gufo», i più pertinenti per primi.")
        // Con «prima i passi pertinenti», l'ordine della decisione 29.
        let passiPrima = BookSearchCorpus(segments: segs).search("torre orologio gufo", settings: .decision29)
        XCTAssertEqual(sentence(passiPrima), "2 passi con le parole di «torre orologio gufo», i più pertinenti per primi. "
                       + "Nessun risultato esatto.")
    }

    func test_bm25_scoreIsTheFormula() {
        // Cinque segmenti: «beta» in due (distingue: al più metà), «alfa» in uno.
        let segs = [body(0, "alfa beta beta" + filler), body(1, "beta gamma" + filler), body(2, "delta" + filler),
                    body(3, "epsilon" + filler), body(4, "zeta" + filler)]
        let p = BookSearchCorpus(segments: segs).passages(normalizedQuery: "alfa beta")
        let dl = segs.map { Double(SearchNormalizer.normalize($0.text).split(separator: " ").count) }
        let n = 5.0, avg = dl.reduce(0, +) / n
        func w(_ tf: Double, _ dl: Double, _ df: Double) -> Double {
            log(1 + (n - df + 0.5) / (df + 0.5)) * tf * 2.2 / (tf + 1.2 * (0.25 + 0.75 * dl / avg))
        }
        XCTAssertEqual(p.map(\.segmentIndex), [0, 1])
        guard p.count == 2 else { return }
        XCTAssertEqual(p[0].score, w(1, dl[0], 1) + w(2, dl[0], 2), accuracy: 1e-12)
        XCTAssertEqual(p[1].score, w(1, dl[1], 2), accuracy: 1e-12)
    }

    func test_shortBlock_countsWithTheFollowingLongBlock() {
        let segs = [seg(0, "HEADING_2", "Usufrutto e abitazione"),
                    body(1, "Il diritto si estingue per non uso." + filler),
                    body(2, "Altro: usufrutto." + filler), body(3, "Testo diverso." + filler), body(4, "Altro testo." + filler)]
        let p = BookSearchCorpus(segments: segs).passages(normalizedQuery: "usufrutto abitazione")
        XCTAssertEqual(p.map(\.segmentIndex), [1, 2], "il titolo corto porta il suo punteggio al blocco lungo che segue")
    }

    func test_noDistinctiveWord_noPassages() {
        // «libro» e «due» sono in tutti i segmenti: nessuna parola distingue, restano le occorrenze esatte.
        let segs = (0..<4).map { body($0, "Il libro due, riga \($0)." + filler) }
        let r = BookSearchCorpus(segments: segs).search("libro due")
        XCTAssertTrue(r.passages.isEmpty)
        XCTAssertEqual(BookSearchWording.countSentence(r), "4 risultati per «libro due».")
        let some = BookSearchCorpus(segments: segs + [body(4, "La piena del fiume." + filler)]).search("piena del libro")
        XCTAssertEqual(some.passages.map(\.segmentIndex), [4], "solo i segmenti con una parola che distingue")
    }

    func test_singleWord_exactOnly_asBefore() {
        let r = BookSearchCorpus(segments: [body(0, "uno due due" + filler)]).search("due")
        XCTAssertTrue(r.passages.isEmpty)
        XCTAssertNil(r.numberQuery)
        XCTAssertEqual(sentence(r), "2 risultati per «due».")
    }

    func test_passageLimit() {
        let segs = (0..<60).map { body($0, "danno e prescrizione \($0)" + filler) }
            + (60..<130).map { body($0, "altro testo \($0)" + filler) }
        let corpus = BookSearchCorpus(segments: segs)
        let r = corpus.search("prescrizione del danno", settings: .decision29)
        XCTAssertEqual(r.passages.count, BookSearchCorpus.passageLimit)
        XCTAssertTrue(sentence(r).hasPrefix("50 passi con le parole di «prescrizione del danno»"), sentence(r))
        // I tre tetti delle impostazioni; di serie 20.
        for limit in SearchSettings.passageLimits {
            var s = SearchSettings.standard
            s.passageLimit = limit
            XCTAssertEqual(corpus.search("prescrizione del danno", settings: s).passages.count, limit)
        }
        let standard = corpus.search("prescrizione del danno")
        XCTAssertEqual(standard.passages.count, 20)
        XCTAssertEqual(sentence(standard), "Nessun risultato esatto. 20 passi con le parole di «prescrizione del danno», i più pertinenti per primi.")
    }

    func test_numberQuery_parse() {
        func p(_ s: String) -> NumberQuery? { NumberQuery.parse(normalized: SearchNormalizer.normalize(s)) }
        XCTAssertEqual(p("art. 2043 c.c."), NumberQuery(target: .article, number: 2043, suffix: nil, code: .civile))
        XCTAssertEqual(p("Articolo 2043 del " + BookSearchCode.civile.spokenName.uppercased())?.code, .civile)
        XCTAssertEqual(p("art 12 cpc")?.code, .proceduraCivile)
        XCTAssertEqual(p("art. 12 c.p.c.")?.code, .proceduraCivile)
        XCTAssertEqual(p("art. 12 c.p.")?.code, .penale)
        XCTAssertEqual(p("art. 12 del " + BookSearchCode.proceduraPenale.spokenName)?.code, .proceduraPenale)
        XCTAssertEqual(p("art. 416-bis")?.label, "416-bis")
        XCTAssertEqual(p("art. 2 bis")?.suffix, "bis")
        XCTAssertNil(p("art. 2043")?.code)
        XCTAssertEqual(p("§ 12"), NumberQuery(target: .paragraph, number: 12, suffix: nil, code: nil))
        XCTAssertEqual(p("paragrafo 7")?.target, .paragraph)
        XCTAssertNil(p("partecipazione 12"))
        XCTAssertNil(p("contratto di locazione"))
    }

    func test_longQueryCitingAnArticle_isNotANumberQuery() {
        let segs = [seg(0, "ARTICLE_HEADER", "Art. 12. Rubrica."), body(1, "Testo." + filler)]
        let q = "che cosa dice la dottrina sulla responsabilità del vettore secondo l'art. 12 nei trasporti di cose"
        XCTAssertNil(BookSearchCorpus(segments: segs).search(q).numberQuery)
    }

    private func twoCodes() -> (segs: [ContentSegment], civile7: Int, cpc7: Int) {
        var segs: [ContentSegment] = [], civile7 = -1, cpc7 = -1
        segs.append(seg(segs.count, "HEADING_1", "Primo codice"))
        for n in 1...20 {
            if n == 7 { civile7 = segs.count }
            segs.append(seg(segs.count, "ARTICLE_HEADER", n == 1 ? "Art. 1. Capacità giuridica." : "Art. \(n). Rubrica \(n)."))
            segs.append(body(segs.count, "Testo del primo codice, numero \(n)." + filler))
        }
        segs.append(seg(segs.count, "HEADING_1", "Secondo codice"))
        for n in 1...10 {
            if n == 7 { cpc7 = segs.count }
            segs.append(seg(segs.count, "ARTICLE_HEADER", n == 1 ? "Art. 1. Prova: giudici ordinari." : "Art. \(n). Titolo \(n)."))
            segs.append(body(segs.count, "Testo del secondo codice, numero \(n)." + filler))
        }
        return (segs, civile7, cpc7)
    }

    func test_jump_withTheCode_goesToThatCode() {
        let (segs, _, cpc7) = twoCodes()
        let r = BookSearchCorpus(segments: segs).search("art. 7 c.p.c.")
        XCTAssertEqual(r.passages.filter(\.isJump), [BookSearchPassage(segmentIndex: cpc7, kind: .article(number: "7", code: .proceduraCivile),
                                                                       score: .infinity)])
        XCTAssertEqual(r.passages.first?.segmentIndex, cpc7)
        let cpc = BookSearchCode.proceduraCivile.spokenName
        XCTAssertTrue(sentence(r).hasPrefix("Primo risultato: l'articolo 7 del " + cpc + ". Nessun risultato esatto. Poi "), sentence(r))
        let label = BookSearchWording.passageRowLabel(r.passages[0], snippet: "Art. 7. Titolo 7.", inNote: false, noteNumber: nil,
                                                      section: "Secondo codice", page: 12)
        XCTAssertEqual(label, "C" + cpc.dropFirst() + ": Art. 7. Titolo 7. Secondo codice, pagina 12.")
        let completo = BookSearchWording.passageRowLabel(r.passages[0], snippet: "Art. 7. Titolo 7.", inNote: false, noteNumber: nil,
                                                         section: "Secondo codice", page: 12, announcement: .full)
        XCTAssertEqual(completo, "Articolo del " + cpc + ": Art. 7. Titolo 7. Secondo codice, pagina 12.")
        XCTAssertEqual(BookSearchCorpus.enclosingSection(of: cpc7, segments: segs), segs.firstIndex { $0.text == "Secondo codice" })
    }

    func test_jump_withoutTheCode_candidatesLongestFirst() {
        let (segs, civile7, cpc7) = twoCodes()
        let corpus = BookSearchCorpus(segments: segs)
        let r = corpus.search("articolo 7")
        XCTAssertEqual(r.passages.filter(\.isJump).map(\.segmentIndex), [civile7, cpc7])
        let cc = BookSearchCode.civile.spokenName, cpc = BookSearchCode.proceduraCivile.spokenName
        XCTAssertTrue(sentence(r).hasPrefix("Primi 2 risultati: l'articolo 7 nel " + cc + " e nel " + cpc + "."),
                      sentence(r))
        let other = corpus.search("art. 7 c.p.")
        XCTAssertEqual(other.passages.filter(\.isJump).map(\.segmentIndex), [civile7, cpc7])
        XCTAssertTrue(sentence(other).hasPrefix("In questo libro non riconosco il codice penale. Primi 2 risultati"), sentence(other))
        let missing = corpus.search("art. 99")
        XCTAssertTrue(missing.passages.filter(\.isJump).isEmpty)
        XCTAssertTrue(sentence(missing).hasPrefix("Nessun articolo 99 in questo libro."), sentence(missing))
    }

    func test_paragraphJump() {
        let segs = [seg(0, "HEADING_3", "§ 12. Il contratto in generale"), body(1, "Testo." + filler),
                    seg(2, "HEADING_3", "§ 13. Altro"), body(3, "Testo." + filler)]
        let r = BookSearchCorpus(segments: segs).search("§ 12")
        XCTAssertEqual(r.passages, [BookSearchPassage(segmentIndex: 0, kind: .paragraph(number: "12"), score: .infinity)])
        XCTAssertEqual(sentence(r), "Primo risultato: il paragrafo 12. Poi un risultato esatto.")
    }

    func test_passageRow_snippetOnTheRarestWord_andEntryHit() {
        let segs = [body(0, "Alfa beta gamma" + filler), body(1, "beta beta delta" + filler)]
        let corpus = BookSearchCorpus(segments: segs)
        let r = corpus.search("alfa beta")
        let p = r.passages[0]
        XCTAssertEqual(p.segmentIndex, 0)
        let sn = corpus.snippet(for: p, normalizedQuery: r.normalizedQuery, segments: segs)
        XCTAssertEqual((sn.text as NSString).substring(with: sn.match), "Alfa")
        let hit = corpus.entryHit(for: p)
        XCTAssertEqual([hit.segmentIndex, hit.endSegmentIndex, hit.startInSegment, hit.length], [0, 0, 0, 0])
        XCTAssertEqual(BookSearchWording.passageRowLabel(p, snippet: "Alfa beta", inNote: false, noteNumber: nil, section: nil, page: 3),
                       "Alfa beta. Pagina 3.", "annuncio breve: subito il testo")
        XCTAssertEqual(BookSearchWording.passageRowLabel(p, snippet: "Alfa beta", inNote: false, noteNumber: nil, section: nil, page: 3,
                                                         announcement: .full), "Passo pertinente: Alfa beta. Pagina 3.")
        XCTAssertEqual(BookSearchWording.exactRowLabel(snippet: "Alfa beta", inNote: false, noteNumber: nil, section: nil, page: 3,
                                                       announcement: .full), "Corrispondenza esatta: Alfa beta. Pagina 3.")
        XCTAssertEqual(BookSearchWording.exactRowLabel(snippet: "Alfa beta", inNote: false, noteNumber: nil, section: nil, page: 3,
                                                       announcement: .brief), "Alfa beta. Pagina 3.")
        // «beta» è in tutti e due i segmenti (non distingue): il passo è solo quello con «alfa».
        XCTAssertEqual(r.passages.map(\.segmentIndex), [0])
        XCTAssertEqual(sentence(r), "Un risultato esatto. Poi un passo con le parole di «alfa beta», i più pertinenti per primi.")
        XCTAssertEqual(sentence(corpus.search("alfa beta", settings: .decision29)),
                       "Un passo con le parole di «alfa beta», i più pertinenti per primi. Poi un risultato esatto.")
    }

    // MARK: Le impostazioni della ricerca (giro «scansioni, ricerca e build», 2026-11-28)

    func test_jumpOff_theNumberIsAWordLikeTheOthers() {
        let (segs, _, _) = twoCodes()
        var s = SearchSettings.standard
        s.numberJump = false
        let r = BookSearchCorpus(segments: segs).search("art. 7 c.p.c.", settings: s)
        XCTAssertNil(r.numberQuery)
        XCTAssertTrue(r.jumps.isEmpty)
        XCTAssertFalse(sentence(r).hasPrefix("Primo risultato"), sentence(r))
    }

    func test_mainCode_saysTheFirstAndHowManyBelow() {
        let (segs, civile7, cpc7) = twoCodes()
        var s = SearchSettings.standard
        s.codeChoice = .mainCode
        let r = BookSearchCorpus(segments: segs).search("articolo 7", settings: s)
        XCTAssertEqual(r.jumps.map(\.segmentIndex), [civile7, cpc7], "lo stesso elenco: il codice più ampio per primo")
        let cc = BookSearchCode.civile.spokenName
        XCTAssertTrue(sentence(r).hasPrefix("Primo risultato: l'articolo 7 del " + cc + ". Subito sotto, l'articolo 7 in un'altra parte del libro."),
                      sentence(r))
        XCTAssertTrue(r.focusesMainCode, "dopo «Cerca» il fuoco va sulla prima riga, l'articolo del codice più ampio")
        XCTAssertFalse(BookSearchCorpus(segments: segs).search("articolo 7").focusesMainCode, "di serie: sulla frase del conteggio")
        let withTheCode = BookSearchCorpus(segments: segs).search("art. 7 c.p.c.", settings: s)
        XCTAssertFalse(withTheCode.focusesMainCode, "un articolo solo: nulla da scegliere, il fuoco resta sulla frase")
    }

    func test_singleWord_passagesOnRequest() {
        let segs = [body(0, "Il fiume esce dagli argini." + filler), body(1, "Testo diverso senza la parola." + filler),
                    body(2, "Altro testo ancora." + filler)]
        let corpus = BookSearchCorpus(segments: segs)
        XCTAssertTrue(corpus.search("fiume").passages.isEmpty, "di serie, come prima")
        var s = SearchSettings.standard
        s.singleWordPassages = true
        let r = corpus.search("fiume", settings: s)
        XCTAssertEqual(r.passages.map(\.segmentIndex), [0])
        XCTAssertEqual(sentence(r), "Un risultato esatto. Poi un passo con la parola «fiume», i più pertinenti per primi.")
    }

    /// Un libro inventato per le fermate: la frase esatta negli elementi 0 e 2, le parole da sole anche nell'elemento 1; altri cinque
    /// elementi senza le parole, così tutte e due distinguono.
    private func stopsBook() -> [ContentSegment] {
        [body(0, "La torre vecchia del borgo." + filler),
         body(1, "La torre nuova, la torre alta, la torre di vedetta." + filler),
         body(2, "Una torre vecchia e un'altra torre vecchia, torre vecchia ancora." + filler)]
            + (3..<8).map { body($0, "Testo diverso numero \($0)." + filler) }
    }

    func test_rotorStops_default_exactInReadingOrder_asBefore() {
        let d = BookSearchCorpus(segments: stopsBook()).search("torre vecchia")
        XCTAssertEqual(d.elementIndices, [0, 2])
        XCTAssertEqual(d.stopIndices, [0, 2], "di serie le fermate sono le occorrenze esatte, in ordine di lettura")
        XCTAssertEqual(d.adjacentStop(from: -1, forward: true), 0)
        XCTAssertEqual(d.adjacentStop(from: 1, forward: true), 2, "in ordine di lettura, da qualunque elemento")
        XCTAssertEqual(d.adjacentStop(from: 1, forward: false), 0)
        XCTAssertEqual(d.adjacentStop(from: 1, forward: true, lastStop: 0), 2, "di serie l'ultima fermata non conta")
        XCTAssertNil(d.adjacentStop(from: 2, forward: true))
        XCTAssertNil(d.stopRank(inElement: 0))
        XCTAssertTrue(d.isStop(2) && !d.isStop(1))
    }

    func test_rotorStops_withPassages_inTheOrderOfTheList_andLeavingAStop() {
        var s = SearchSettings.standard
        s.rotorIncludesPassages = true
        let corpus = BookSearchCorpus(segments: stopsBook())
        let r = corpus.search("torre vecchia", settings: s)
        XCTAssertEqual(r.wordPassages.map(\.segmentIndex), [2, 0, 1], "i passi, i più pertinenti per primi")
        XCTAssertEqual(r.stopIndices, [0, 2, 1], "prima le esatte in ordine di lettura, poi il passo che resta, una volta sola")
        XCTAssertEqual(r.stopRank(inElement: 2)?.rank, 2)
        XCTAssertEqual(r.stopRank(inElement: 2)?.of, 3)
        XCTAssertNil(r.stopRank(inElement: 5))
        XCTAssertEqual(r.adjacentStop(from: 0, forward: true), 2)
        XCTAssertEqual(r.adjacentStop(from: 2, forward: true), 1)
        XCTAssertNil(r.adjacentStop(from: 1, forward: true), "dopo l'ultima, niente")
        XCTAssertEqual(r.adjacentStop(from: 1, forward: false), 2)
        XCTAssertNil(r.adjacentStop(from: 0, forward: false), "prima della prima, niente")
        // Chi lascia la fermata 2 (legge l'elemento 3) riparte da lì: avanti la fermata dopo, indietro lei stessa.
        XCTAssertEqual(r.adjacentStop(from: 3, forward: true, lastStop: 2), 1)
        XCTAssertEqual(r.adjacentStop(from: 3, forward: false, lastStop: 2), 2)
        XCTAssertNil(r.adjacentStop(from: 3, forward: true, lastStop: 1))
        // Senza un'ultima fermata: la prima, o l'ultima.
        XCTAssertEqual(r.adjacentStop(from: 3, forward: true), 0)
        XCTAssertEqual(r.adjacentStop(from: 3, forward: false), 1)
        XCTAssertNotNil(ReadingSpeechModel.activeSearch(r))
        // Con «prima i passi pertinenti» le fermate seguono l'elenco: i passi, poi le esatte che mancano (nessuna).
        s.order = .passagesFirst
        XCTAssertEqual(corpus.search("torre vecchia", settings: s).stopIndices, [2, 0, 1])
        // Con un salto per numero, il salto viene per primo.
        let (segs, civile7, cpc7) = twoCodes()
        var j = SearchSettings.standard
        j.rotorIncludesPassages = true
        XCTAssertEqual(Array(BookSearchCorpus(segments: segs).search("articolo 7", settings: j).stopIndices.prefix(2)), [civile7, cpc7])
    }

    func test_settings_decoding_goesThroughTheCheckOfTheLimit() throws {
        let dec = JSONDecoder()
        XCTAssertEqual(try dec.decode(SearchSettings.self, from: Data(#"{"passageLimit": 33}"#.utf8)).passageLimit, 20,
                       "un tetto fuori dai tre torna al predefinito")
        XCTAssertEqual(try dec.decode(SearchSettings.self, from: Data("{}".utf8)), .standard, "ogni valore mancante: il predefinito")
        let s = SearchSettings(order: .passagesFirst, passageLimit: 10, numberJump: false, codeChoice: .mainCode, singleWordPassages: true,
                               rotorIncludesPassages: true, announcement: .full, libraryOrder: .exactFirst)
        XCTAssertEqual(try dec.decode(SearchSettings.self, from: try JSONEncoder().encode(s)), s)
        XCTAssertTrue(s.sameList(as: SearchSettings(order: .passagesFirst, passageLimit: 10, numberJump: false, singleWordPassages: true)),
                      "codice principale, rotore, annuncio e libreria non cambiano l'elenco")
        XCTAssertFalse(s.sameList(as: .standard))
    }

    func test_settings_storedAndRestored_unknownValuesFallBack() {
        let store = InMemoryKeyValueStore()
        XCTAssertEqual(getStoredSearchSettings(store), .standard)
        let s = SearchSettings(order: .passagesFirst, passageLimit: 50, numberJump: false, codeChoice: .mainCode, singleWordPassages: true,
                               rotorIncludesPassages: true, announcement: .full, libraryOrder: .exactFirst)
        setStoredSearchSettings(store, s)
        XCTAssertEqual(getStoredSearchSettings(store), s)
        let broken = InMemoryKeyValueStore([PreferenceKeys.searchPassageLimit: "33", PreferenceKeys.searchOrder: "altro"])
        XCTAssertEqual(getStoredSearchSettings(broken), .standard)
    }

    func test_settingsWording_everyQuestionHasTwoOptions_andRoundTrips() {
        XCTAssertEqual(SearchSettingsWording.questions.map(\.id), SearchSettingsQuestion.Id.allCases)
        for q in SearchSettingsWording.questions {
            XCTAssertGreaterThanOrEqual(q.options.count, 2, q.title)
            XCTAssertEqual(q.selectedIndex(in: .standard), q.id == .passageLimit ? 1 : 0, "i predefiniti: \(q.title)")
            for (i, o) in q.options.enumerated() {
                XCTAssertEqual(q.selectedIndex(in: q.choosing(i, in: .standard)), i, q.title)
                XCTAssertTrue(o.explanation.hasSuffix("."), "spiegazione in frase completa: \(o.name)")
                XCTAssertEqual(o.spoken, o.name + ". " + o.explanation)
            }
        }
    }
}
