//
//  GranularityTests.swift
//  ScaboCoreTests
//
//  Rete di verifica del motore di granularità (`Granularity.swift`), regole di
//  prodotto § 7.6 / § 7.7. Logica pura: gira nel `swift test` macOS di ScaboCore.
//
//  Pinano gli invarianti inderogabili: blocchi ~target ma mai a cavallo di confini
//  di struttura; frasi mai spezzate (un blocco eccede pur di non spezzare); inizio
//  frase / fine punto fermo; note e unità normative non toccate; determinismo;
//  target parametrico.
//

import XCTest
@testable import ScaboCore

final class GranularityTests: XCTestCase {

    // MARK: - Helpers

    private func seg(_ id: String, _ role: String, _ text: String) -> ContentSegment {
        ContentSegment(id: id, role: role, text: text, lengthCategory: "", acousticIntro: "")
    }

    private func body(_ id: String, _ text: String) -> ContentSegment {
        seg(id, SemanticCategory.BODY.rawValue, text)
    }

    /// `k` frasi distinte, ciascuna ~40 caratteri, ciascuna chiusa da punto fermo.
    private func sentences(_ k: Int) -> String {
        (1...k).map { "Questa e la frase numero \($0) di prova." }.joined(separator: " ")
    }

    // MARK: - Passthrough e casi degeneri

    func test_emptyInput_producesEmpty() {
        XCTAssertEqual(granularizeBody([]), [])
    }

    func test_nonBodySegmentsPassThroughUnchanged() {
        let input = [
            seg("h", "HEADING_1", "Titolo"),
            seg("nt", "NOTE", "Una nota qualsiasi."),
            seg("pr", "PROCEDURAL", "Scheda operativa."),
            seg("sd", SECTION_DIVIDER_ROLE, "Sezione"),
        ]
        // Nessun BODY: tutto passa identico, nello stesso ordine.
        XCTAssertEqual(granularizeBody(input), input)
    }

    // MARK: - § 7.7 — i documenti normativi NON sono granularizzati

    func test_normativeNativeUnitsAreNotGranularized() {
        // Un articolo con commi: ARTICLE_HEADER + ARTICLE_BODY (anche lunghi).
        let longComma = sentences(20)  // ben oltre 400 caratteri
        let input = [
            seg("ah", "ARTICLE_HEADER", "Art. 1218"),
            seg("ab1", "ARTICLE_BODY", longComma),
            seg("ab2", "ARTICLE_BODY", "Comma secondo."),
        ]
        // Le unità native restano quelle strutturali, invariate: nessuno split per
        // caratteri, identità preservata.
        XCTAssertEqual(granularizeBody(input, target: 400), input)
    }

    // MARK: - § 7.6 (1) — confine di unità strutturale chiude il run

    func test_structuralBoundary_headingSplitsRuns_noMergeAcross() {
        let input = [
            body("a", "Frase uno. Frase due."),
            seg("h", "HEADING_1", "Titolo di sezione"),
            body("b", "Frase tre."),
        ]
        let out = granularizeBody(input, target: 400)
        XCTAssertEqual(out.map { $0.role }, ["BODY", "HEADING_1", "BODY"])
        // L'intestazione passa identica (confine, non granularizzata).
        XCTAssertEqual(out[1], input[1])
        // Il corpo prima e dopo l'intestazione NON è fuso attraverso il confine.
        XCTAssertEqual(out[0].text, "Frase uno. Frase due.")
        XCTAssertEqual(out[2].text, "Frase tre.")
        XCTAssertEqual(out[0].id, "a#0")
        XCTAssertEqual(out[2].id, "b#0")
    }

    // MARK: - § 7.6 — assembla paragrafi corti intorno al target

    func test_shortParagraphsWithinUnitAreMerged() {
        let input = [body("p1", "Frase a."), body("p2", "Frase b."), body("p3", "Frase c.")]
        let out = granularizeBody(input, target: 400)
        XCTAssertEqual(out.count, 1, "tre paragrafi corti nella stessa unità → un blocco")
        XCTAssertEqual(out[0].text, "Frase a. Frase b. Frase c.")
        XCTAssertEqual(out[0].role, "BODY")
        XCTAssertEqual(out[0].id, "p1#0")
    }

    // MARK: - § 7.6 (2)/(3) — split lungo solo ai confini di frase

    func test_longBodySplitsAtSentenceBoundaries_neverMidSentence() {
        let target = 150
        let input = [body("b", sentences(10))]  // ~400 char, 10 frasi
        let out = granularizeBody(input, target: target)

        XCTAssertGreaterThan(out.count, 1, "un corpo lungo si spezza in più blocchi")
        for blockSegment in out {
            let text = blockSegment.text
            // Inizio frase (maiuscola) e fine a punto fermo: nessuna frase spezzata.
            XCTAssertEqual(text.first, "Q", "ogni blocco inizia all'inizio di una frase")
            XCTAssertEqual(text.last, ".", "ogni blocco finisce a un punto fermo")
            XCTAssertEqual(blockSegment.role, "BODY")
        }
        // Contenuto integro: la concatenazione dei blocchi ricostruisce il testo.
        XCTAssertEqual(out.map { $0.text }.joined(separator: " "), sentences(10))
        // Ids deterministici per blocco del run.
        XCTAssertEqual(out.map { $0.id }, (0..<out.count).map { "b#\($0)" })
    }

    func test_blockMayStayUnderTargetButNeverSplitsASentence() {
        // Frase singola più lunga del target: resta intera, blocco unico > target.
        let oneLongSentence = (1...40).map { "parola\($0)" }.joined(separator: " ") + "."
        XCTAssertGreaterThan(oneLongSentence.count, 100)
        let out = granularizeBody([body("b", oneLongSentence)], target: 100)
        XCTAssertEqual(out.count, 1, "una frase non si spezza, anche se eccede il target")
        XCTAssertGreaterThan(out[0].text.count, 100)
        XCTAssertEqual(out[0].text, oneLongSentence)
    }

    // MARK: - Determinismo e target parametrico

    func test_isDeterministic() {
        let input = [body("b", sentences(12)), seg("h", "HEADING_2", "X"), body("c", sentences(3))]
        XCTAssertEqual(granularizeBody(input, target: 200), granularizeBody(input, target: 200))
    }

    func test_targetParameterControlsBlockCount() {
        let input = [body("b", sentences(20))]
        let fine = granularizeBody(input, target: 100)
        let coarse = granularizeBody(input, target: 1000)
        XCTAssertGreaterThan(fine.count, coarse.count, "target più fine → più blocchi")
        // Default = 400 (granularità fine del prodotto).
        XCTAssertEqual(DEFAULT_GRANULARITY_TARGET, 400)
    }

    // MARK: - Ordine globale preservato (interleaving struttura/corpo)

    func test_globalOrderPreservedAcrossInterleaving() {
        let input = [
            seg("h1", "HEADING_1", "Capitolo"),
            body("b1", sentences(10)),   // splitta in ≥2 blocchi a target 150
            seg("h2", "HEADING_2", "Sezione"),
            body("b2", "Frase singola."),
        ]
        let out = granularizeBody(input, target: 150)
        // Heading invariati e nelle posizioni attese; corpo granularizzato in mezzo.
        XCTAssertEqual(out.first, input[0])
        XCTAssertTrue(out.contains(input[2]))
        let h2Index = out.firstIndex(of: input[2])!
        // Prima di h2: h1 + i blocchi di b1 (tutti BODY). Dopo h2: i blocchi di b2.
        XCTAssertTrue(out[1..<h2Index].allSatisfy { $0.role == "BODY" })
        XCTAssertTrue(out[(h2Index + 1)...].allSatisfy { $0.role == "BODY" })
        XCTAssertEqual(out.last?.text, "Frase singola.")
    }

    // MARK: - Segmentatore di frase (euristica conservativa)

    func test_sentenceSplitter_splitsRealBoundaries() {
        XCTAssertEqual(splitIntoSentences("Prima frase. Seconda frase."),
                       ["Prima frase.", "Seconda frase."])
        XCTAssertEqual(splitIntoSentences("Davvero? Si. Bene!"),
                       ["Davvero?", "Si.", "Bene!"])
    }

    func test_sentenceSplitter_doesNotSplitOnLegalAbbreviations() {
        // "art." , "c.c." non sono confini: una sola frase.
        XCTAssertEqual(
            splitIntoSentences("Vedi art. 1218 c.c. per il dettaglio.").count, 1)
        // "n." e "cfr." idem.
        XCTAssertEqual(
            splitIntoSentences("Cfr. la nota n. 5 del manuale.").count, 1)
        // "ecc." non spezza prima di una minuscola.
        XCTAssertEqual(
            splitIntoSentences("Crediti, debiti, ecc. sono obbligazioni.").count, 1)
    }

    func test_sentenceSplitter_doesNotSplitOnSingleInitial() {
        // Iniziale puntata "F." dentro un nome: una sola frase fino al punto finale.
        let s = splitIntoSentences("Secondo F. Gazzoni la tesi e errata. Tuttavia resta dubbia.")
        XCTAssertEqual(s.count, 2)
        XCTAssertTrue(s[0].contains("F. Gazzoni"))
    }

    func test_sentenceSplitter_digitEndedSentenceIsABoundary() {
        // "1218." (punto dopo cifre) è confine se segue una maiuscola.
        let s = splitIntoSentences("Vedi l'articolo 1218. Il debitore risponde.")
        XCTAssertEqual(s.count, 2)
        XCTAssertEqual(s[1], "Il debitore risponde.")
    }

    func test_sentenceSplitter_noStrongPunctuationStaysOneSentence() {
        XCTAssertEqual(splitIntoSentences("Testo senza punto fermo finale"),
                       ["Testo senza punto fermo finale"])
    }
}
