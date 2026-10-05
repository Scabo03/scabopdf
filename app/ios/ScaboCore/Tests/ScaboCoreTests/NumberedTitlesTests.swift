//
//  NumberedTitlesTests.swift
//  ScaboCoreTests
//
//  Canale dei titoli numerati del tronco (`recognizeNumberedTitles`, `numberedTitleLevel`) e
//  abbreviazioni delle citazioni giuridiche (`splitIntoSentences`). Ogni caso negativo è un
//  falso titolo misurato sul corpus (docs/CURA_INTESTAZIONI.md): la regola d'oro è non
//  promuovere nel dubbio.
//

import XCTest
@testable import ScaboCore

final class NumberedTitlesTests: XCTestCase {

    private let body = 11.5
    private let colWidth = 300.0

    /// Riga con span espliciti: `parts` = [(testo, taglia)]; geometria in coordinate PDF (origine
    /// in basso). Larghezza di default = colonna piena.
    private func line(_ parts: [(String, Double)], yTop: Double, width: Double = 300,
                      x0: Double = 70) -> LineSummary {
        let text = parts.map { $0.0 }.joined()
        let n = parts.reduce(0) { $0 + $1.0.count }
        let mean = parts.reduce(0.0) { $0 + $1.1 * Double($1.0.count) } / Double(max(1, n))
        let spans = parts.map {
            PdfSpan(text: $0.0, fontSize: $0.1, bold: false, italic: false, color: "#000000",
                    bbox: BBox(x: x0, y: yTop - 12, width: width, height: 12))
        }
        return LineSummary(text: text, fontSize: mean, bold: false, italic: false, color: "#000000",
                           x0: x0, x1: x0 + width, yTop: yTop, yBottom: yTop - 12,
                           width: width, height: 12, spans: spans)
    }
    private func bodyLine(_ t: String, yTop: Double, width: Double = 300) -> LineSummary {
        line([(t, body)], yTop: yTop, width: width)
    }
    private func profile(codici: Bool = false, rivista: Bool = false) -> Profile {
        Profile(bodySize: body, bodyColor: "#000000", isRivistaDpc: rivista, isCodici: codici)
    }
    private func run(_ lines: [LineSummary], codici: Bool = false, rivista: Bool = false) -> [GenItem] {
        recognizeNumberedTitles([.run(.body, lines)], profile(codici: codici, rivista: rivista),
                                colWidth: colWidth, colX1: 70 + colWidth)
    }
    private func titles(_ items: [GenItem]) -> [String] {
        items.compactMap { if case let .numberedTitle(sm, _) = $0 { return sm.text } else { return nil } }
    }

    // MARK: - numerazione: profondità arbitraria, punto finale obbligatorio

    func test_depth_parsesArbitraryDepth() {
        XCTAssertEqual(numberedTitleDepth("2. Il reticolo di fatti"), 1)
        XCTAssertEqual(numberedTitleDepth("3.2. Il problema"), 2)
        XCTAssertEqual(numberedTitleDepth("5.3.1. Il danno evitabile."), 3)
        XCTAssertEqual(numberedTitleDepth("1.2.3.4. Quarto livello"), 4)
        XCTAssertEqual(numberedTitleDepth("§ 12. La sentenza"), 1)
        XCTAssertEqual(numberedTitleDepth("7.2. «Danno intrinseco»"), 2)
    }

    func test_depth_rejectsNonTitles() {
        XCTAssertNil(numberedTitleDepth("48.2.15 (Ulp. 56 ad ed.)"), "citazione del Digesto: niente punto finale")
        XCTAssertNil(numberedTitleDepth("1.000 Euro di sanzione"), "importo: componente a 3 cifre")
        XCTAssertNil(numberedTitleDepth("12.3.2010 La sentenza"), "data: anno a 4 cifre")
        XCTAssertNil(numberedTitleDepth("2. ha abrogato l’art. 70"), "minuscola: prosa")
        XCTAssertNil(numberedTitleDepth("22 maggio 1978, n. 194"), "data senza punto")
        XCTAssertNil(numberedTitleDepth("Il titolo senza numero"))
    }

    // MARK: - con supporto di taglia (titolo «piccolo», +4…+9%)

    func test_sizeSupported_titleSplitsBodyRun() {
        let items = run([
            bodyLine("…e chiude il paragrafo precedente.", yTop: 500),
            line([("2. Il reticolo di fatti oggetto del giudizio", 12.48)], yTop: 480, width: 250),
            bodyLine("L’art. 1229 del codice civile del 1865 disponeva", yTop: 460),
        ])
        XCTAssertEqual(items.count, 3, "corpo | titolo | corpo: il confine c'è davvero")
        XCTAssertEqual(titles(items), ["2. Il reticolo di fatti oggetto del giudizio"])
        guard case .run(.body, let before) = items[0], case .run(.body, let after) = items[2] else {
            return XCTFail("attesi due run di corpo attorno al titolo")
        }
        XCTAssertEqual(before.count, 1); XCTAssertEqual(after.count, 1)
    }

    func test_sizeSupported_continuationLinesAreMerged_evenInSmallCaps() {
        // Maiuscoletto con parola spezzata (Storia della codificazione p.110): la continuazione
        // apre con una minuscola maiuscoletta a 9,96 ma porta maiuscole a 12,48.
        let items = run([
            line([("6. L", 12.48), ("A RESTAURAZIONE: CRISI DEL MODELLO NAPO-", 9.96)], yTop: 480, width: 280),
            line([("LEONICO", 9.96), (".", 12.48)], yTop: 466, width: 80),
            bodyLine("Gli anni di transizione. – La caduta dei regimi", yTop: 440),
        ])
        XCTAssertEqual(titles(items).count, 1)
        XCTAssertTrue(titles(items)[0].hasSuffix("LEONICO."), "la riga di continuazione è nel titolo")
    }

    func test_sizeSupported_bodySizedLineIsNeverAContinuation() {
        let items = run([
            line([("3.1. La fattispecie base", 12.48)], yTop: 480, width: 200),
            line([("centi", 12.48), (" Gli artt. 589-bis e 590-bis sanzionano", body)], yTop: 466),
        ])
        XCTAssertEqual(titles(items), ["3.1. La fattispecie base"],
                       "una riga che porta testo alla taglia del corpo è corpo")
    }

    // MARK: - alla taglia del corpo: solo numerazione multipla, riga corta

    func test_bodySize_depth2_shortLine_isTitle() {
        let items = run([
            bodyLine("…si conclude la trattazione precedente.", yTop: 500),
            bodyLine("4.1. Il lavoro a tempo parziale.", yTop: 480, width: 180),
            bodyLine("Il contratto di lavoro a tempo parziale è", yTop: 460),
        ])
        XCTAssertEqual(titles(items), ["4.1. Il lavoro a tempo parziale."])
    }

    func test_bodySize_depth1_isNeverATitle() {
        // Enumerazioni e commi di corpo («1. Ai fini…»): a taglia-corpo e profondità 1 restano corpo.
        let items = run([
            bodyLine("Il decreto dispone quanto segue.", yTop: 500),
            bodyLine("1. Ai fini del presente decreto si intende per:", yTop: 480, width: 200),
        ])
        XCTAssertTrue(titles(items).isEmpty)
    }

    func test_bodySize_depth2_fullWidthProse_isNotTitle() {
        // Paragrafo di prosa numerato a tutta giustezza (Rivista DPC 4-2020, Lineamenti p.482).
        let items = run([
            bodyLine("…fine del paragrafo.", yTop: 500),
            bodyLine("1.1. Le riflessioni che qui propongo riguardano problemi della", yTop: 480, width: 296),
        ])
        XCTAssertTrue(titles(items).isEmpty)
    }

    func test_bodySize_depth2_endingWithColon_isNotTitle() {
        let items = run([
            bodyLine("…fine del paragrafo.", yTop: 500),
            bodyLine("2.1. Le ipotesi sono le seguenti:", yTop: 480, width: 160),
        ])
        XCTAssertTrue(titles(items).isEmpty)
    }

    func test_bodySize_depth3_shortLine_isTitle() {
        let items = run([
            bodyLine("…fine del paragrafo.", yTop: 500),
            bodyLine("5.3.1. Il danno evitabile.", yTop: 480, width: 130),
        ])
        XCTAssertEqual(titles(items), ["5.3.1. Il danno evitabile."])
    }

    func test_bodySize_multiline_hangingIndentAfterGap_isTitle() {
        // Rizzo p.260: stacco 20,7 pt, continuazioni rientrate di 14,2 pt, chiusura su riga corta.
        let items = run([
            bodyLine("…nel processo penale.", yTop: 520, width: 120),
            line([("2.1.1. Certezze e dubbi ragionevoli: l’evitabilità dell’evento da parte", body)], yTop: 488, width: 296),
            // Riga piena ma rientrata: più stretta di 0,85×colonna, eppure arriva al margine destro.
            line([("della condotta alternativa lecita nei reati omissivi, nel momento", body)], yTop: 474, width: 250, x0: 118),
            line([("posi sostanzialmente omissivi.", body)], yTop: 460, width: 130, x0: 84.2),
            line([("Il problema della matrice della legge di copertura", body)], yTop: 436, width: 280, x0: 84.2),
        ])
        XCTAssertEqual(titles(items).count, 1)
        XCTAssertTrue(titles(items)[0].hasSuffix("omissivi."))
    }

    func test_bodySize_multiline_doesNotSwallowNextParagraphFirstLine() {
        // Titolo su una riga piena, poi la prima riga (rientrata) del paragrafo senza stacco dopo.
        let items = run([
            bodyLine("…fine della scheda precedente.", yTop: 520, width: 120),
            line([("2.3. Sentenza CG 10 maggio 1995, causa C-384/93, Alpine Investments", body)], yTop: 488, width: 299),
            line([("Nell’ambito di una controversia tra la Alpine Investments, società olandese spe-", body)], yTop: 474, width: 285, x0: 84),
            line([("cializzata nella consulenza sugli investimenti, ed il Ministero", body)], yTop: 460, width: 299),
        ])
        XCTAssertTrue(titles(items).allSatisfy { !$0.contains("Nell’ambito") })
    }

    func test_bodySize_multiline_proseParagraph_isNotTitle() {
        // Paragrafo di prosa numerato: prima riga, poi le altre tornano al margine (nessun rientro sporgente).
        let items = run([
            bodyLine("…fine del paragrafo.", yTop: 520, width: 120),
            line([("1.1. Le riflessioni che qui propongo riguardano problemi della", body)], yTop: 488, width: 296, x0: 84),
            line([("pena. Stanno al centro della discussione.", body)], yTop: 474, width: 200, x0: 70),
        ])
        XCTAssertTrue(titles(items).isEmpty)
    }

    func test_bodySize_multiline_withoutGap_isNotTitle() {
        let items = run([
            bodyLine("…fine del paragrafo.", yTop: 500, width: 120),
            line([("2.1.1. Certezze e dubbi ragionevoli: l’evitabilità dell’evento", body)], yTop: 488, width: 296),
            line([("posi sostanzialmente omissivi.", body)], yTop: 474, width: 130, x0: 84.2),
        ])
        XCTAssertTrue(titles(items).isEmpty, "senza stacco verticale prima: nel dubbio corpo")
    }

    // MARK: - guardie contro i falsi titoli

    func test_indexEntryWithPageNumber_isNotTitle() {
        let items = run([line([("1.1. Definizioni 1", 12.48)], yTop: 480, width: 200)])
        XCTAssertTrue(titles(items).isEmpty, "voce d'indice: numero di pagina in coda")
    }

    func test_superscriptNoteCallAtEnd_isAllowed() {
        let items = run([line([("2. Premessa", 12.48), (" 3", 6.0)], yTop: 480, width: 120)])
        XCTAssertEqual(titles(items).count, 1, "il richiamo di nota in apice non è un numero di pagina")
    }

    func test_numberWrappedMidSentence_isNotTitle() {
        // Una riga che inizia con «12.» dentro una frase (la precedente non chiude, nessuno stacco).
        let items = run([
            bodyLine("come previsto dall’art.", yTop: 500, width: 120),
            line([("12. Il giudice provvede", 12.48)], yTop: 488, width: 200),
        ])
        XCTAssertTrue(titles(items).isEmpty, "«art.» non chiude: senza stacco è la citazione che continua")
        let withGap = run([
            bodyLine("come previsto dall’art.", yTop: 500, width: 120),
            line([("12. Il giudice provvede", 12.48)], yTop: 470, width: 200),
        ])
        XCTAssertEqual(titles(withGap).count, 1, "con uno stacco verticale è un titolo")
        let mid = run([
            bodyLine("secondo quanto disposto dal comma", yTop: 500, width: 296),
            line([("2. Le norme di attuazione", 12.48)], yTop: 488, width: 200),
        ])
        XCTAssertTrue(titles(mid).isEmpty, "la riga precedente non chiude e non c'è stacco")
    }

    func test_runningHeaderWithBigFolioAndSmallName_isNotTitle() {
        // «2. Roberto Sacchi» (rivista 1720-951X): folio 14 pt, nome 9 pt su corpo 11.
        let items = run([line([("2.", 14), (" Roberto Sacchi", 9)], yTop: 780, width: 116)])
        XCTAssertTrue(titles(items).isEmpty)
    }

    func test_gate_offOnCodiciAndRivistaDpc() {
        let l = [line([("1. Nozione di contratto", 12.48)], yTop: 480, width: 200)]
        XCTAssertTrue(titles(run(l, codici: true)).isEmpty, "commi e articoli sono del ramo codici")
        XCTAssertTrue(titles(run(l, rivista: true)).isEmpty, "Rivista DPC esclusa")
        XCTAssertEqual(titles(run(l)).count, 1)
    }

    // MARK: - livello relativo alla gerarchia già emessa

    private func h(_ type: SemanticCategory, _ text: String) -> NodeDict {
        NodeDict(id: "x", type: type, page_index: 0, text: text)
    }

    func test_level_underChapter_addsDepth() {
        let pre = [h(.HEADING_2, "La causalità nella struttura del giudizio"), h(.BODY, "…")]
        XCTAssertEqual(numberedTitleLevel(depth: 1, preceding: pre), 3)
        XCTAssertEqual(numberedTitleLevel(depth: 2, preceding: pre), 4)
    }

    func test_level_siblingKeepsLevel_childGoesDeeper() {
        let pre = [h(.HEADING_2, "Capitolo"), h(.HEADING_3, "3. La teoria del doppio nesso"),
                   h(.HEADING_4, "3.1. Lesioni contestuali")]
        XCTAssertEqual(numberedTitleLevel(depth: 2, preceding: pre), 4, "fratello di 3.1")
        XCTAssertEqual(numberedTitleLevel(depth: 1, preceding: pre), 3, "fratello di 3.")
        XCTAssertEqual(numberedTitleLevel(depth: 3, preceding: pre), 4, "tetto HEADING_4")
    }

    func test_level_capsAtFourAndDefaultsWithoutHierarchy() {
        XCTAssertEqual(numberedTitleLevel(depth: 1, preceding: [h(.HEADING_3, "CAPITOLO PRIMO")]), 4)
        XCTAssertEqual(numberedTitleLevel(depth: 1, preceding: []), 3)
    }

    // MARK: - abbreviazioni delle citazioni (lista chiusa estesa)

    func test_citationAbbreviations_doNotSplitSentences() {
        for t in [
            "Il giudice amministrativo (cfr. Cons. Stato, sez. V, 9 giugno 1970, n. 523) lo ammette.",
            "Lo afferma Cass. Sez. un. 12 marzo 2010, n. 1234, in modo netto.",
            "Pubblicata in G.U. 27 dicembre 1947, n. 298, edizione straordinaria.",
            "Ai sensi del d.P.R. 22 dicembre 1986, n. 917, si applica.",
            "È la c.d. Legge Pinto che prevede l’equa riparazione.",
            "Lo ha chiarito la sent. 203/1989 della Corte costituzionale.",
        ] {
            XCTAssertEqual(splitIntoSentences(t).count, 1, t)
        }
    }

    func test_codeAbbreviationsAtSentenceEnd_stillClose() {
        // Escluse di proposito: chiudono spesso una frase.
        XCTAssertEqual(splitIntoSentences("Lo prevede l’art. 7 c.p.a. Il dibattito è aperto.").count, 2)
        XCTAssertEqual(splitIntoSentences("È previsto nel t.u.f. La concezione è diversa.").count, 2)
    }
}
