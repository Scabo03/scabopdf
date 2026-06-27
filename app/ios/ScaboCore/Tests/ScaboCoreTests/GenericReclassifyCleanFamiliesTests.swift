//
//  GenericReclassifyCleanFamiliesTests.swift
//  ScaboCoreTests
//
//  Riclassificazione delle due famiglie pulite che il classificatore size-only
//  collassa in NOTE: SOMMARIO di capitolo → CHAPTER_SUMMARY, intestazioni di
//  struttura (CAPITOLO/SEZIONE/PARTE/… + ordinale) → HEADING_n. Riclassificazione,
//  non soppressione: non devono mai più essere NOTE (niente "Nota." da zittire).
//  Con le guardie verificate sul banco reale (caps della keyword, lunghezza),
//  e la non-distruttività (id/testo/conteggio invariati).
//

import XCTest
@testable import ScaboCore

final class GenericReclassifyCleanFamiliesTests: XCTestCase {

    private func note(_ text: String, _ id: String = "n", page: Int = 5) -> NodeDict {
        NodeDict(id: id, type: .NOTE, page_index: page, text: text, length_category: .SHORT)
    }
    private func reclass(_ nodes: [NodeDict]) -> [NodeDict] {
        var n = nodes; _ = reclassifyCleanFamilies(&n); return n
    }

    // MARK: - SOMMARIO → CHAPTER_SUMMARY

    func test_sommario_uppercase_becomesChapterSummary() {
        let out = reclass([note("SOMMARIO: 1. La nozione di tributo. – 2. Imposte, tasse, contributi.")])
        XCTAssertEqual(out[0].type, .CHAPTER_SUMMARY)
        XCTAssertNil(out[0].length_category, "una summary non porta regime acustico di nota")
    }
    func test_sommario_mixedCase_becomesChapterSummary() {
        let out = reclass([note("Sommario: 1. Il diritto internazionale privato. – 2. Mancini.")])
        XCTAssertEqual(out[0].type, .CHAPTER_SUMMARY)
    }
    func test_sommario_short_becomesChapterSummary() {
        let out = reclass([note("SOMMARIO: 1. Introduzione.")])
        XCTAssertEqual(out[0].type, .CHAPTER_SUMMARY)
    }

    // MARK: - variante SENZA due punti ("SOMMARIO" secco, isolato): Estratto/Patriarca

    func test_sommario_noColon_uppercase_isolated_becomesChapterSummary() {
        let out = reclass([note("SOMMARIO")])
        XCTAssertEqual(out[0].type, .CHAPTER_SUMMARY)
    }
    func test_sommario_noColon_mixedCase_isolated_becomesChapterSummary() {
        let out = reclass([note("Sommario")])
        XCTAssertEqual(out[0].type, .CHAPTER_SUMMARY)
    }
    func test_sommario_noColon_trailingSpaces_becomesChapterSummary() {
        let out = reclass([note("  SOMMARIO  ")])
        XCTAssertEqual(out[0].type, .CHAPTER_SUMMARY)
    }
    // Estratto: l'etichetta e l'elenco numerato stanno nello STESSO nodo, separati da spazio
    // (non da ":"): "SOMMARIO 1. … – 2. …". La cifra dopo lo spazio apre l'elenco → promosso.
    func test_sommario_inlineElenco_noColon_becomesChapterSummary() {
        let out = reclass([note("SOMMARIO 1. Premessa critica. – 2. Caratteri essenziali del provvedimento.")])
        XCTAssertEqual(out[0].type, .CHAPTER_SUMMARY)
    }
    func test_sommario_inlineElenco_mixedCase_becomesChapterSummary() {
        let out = reclass([note("Sommario 1. L’impresa e l’imprenditore.")])
        XCTAssertEqual(out[0].type, .CHAPTER_SUMMARY)
    }
    // Guardia: "SOMMARIO" + parola (non cifra) NON è un elenco → resta NOTE (precisione).
    func test_guard_sommarioSpaceWord_notReclassified() {
        let out = reclass([note("SOMMARIO delle decisioni piu rilevanti in materia")])
        XCTAssertEqual(out[0].type, .NOTE)
    }
    // Guardie precisione: la parola NON isolata NON è promossa (precisione prima del recall).
    func test_guard_sommarioWithFolio_runningHeader_notReclassified() {
        let out = reclass([note("Sommario VII")])   // testatina d'indice col folio romano
        XCTAssertEqual(out[0].type, .NOTE)
    }
    func test_guard_sommarioWithPeriod_notReclassified() {
        let out = reclass([note("Sommario.")])      // etichetta col punto (Nomofanie) → ambigua
        XCTAssertEqual(out[0].type, .NOTE)
    }
    func test_guard_sommarioInSentence_notReclassified() {
        let out = reclass([note("a un sommario esame del ricorso la sezione provvede")])
        XCTAssertEqual(out[0].type, .NOTE)
    }
    func test_guard_sommarioNotAtStart_notReclassified() {
        let out = reclass([note("(*) Sommario 1. Il senso della ricerca")])  // inizia con (*)
        XCTAssertEqual(out[0].type, .NOTE)
    }
    // Non-regressione del ramo col due punti (deve restare identico a prima).
    func test_colonVariant_withInlineElenco_stillBecomesChapterSummary() {
        let out = reclass([note("SOMMARIO: 1. Premessa. – 2. La giurisdizione. – 3. Profili")])
        XCTAssertEqual(out[0].type, .CHAPTER_SUMMARY)
    }

    // MARK: - intestazioni di struttura → HEADING_n

    func test_capitolo_word_becomesHeading2() {
        let out = reclass([note("CAPITOLO TERZO")])
        XCTAssertEqual(out[0].type, .HEADING_2)
        XCTAssertEqual(out[0].level, 2)
        XCTAssertNil(out[0].length_category)
    }
    func test_capitolo_roman_becomesHeading2() {
        let out = reclass([note("CAPITOLO LXXII-BIS")])
        XCTAssertEqual(out[0].type, .HEADING_2)
    }
    func test_sezione_becomesHeading3() {
        let out = reclass([note("SEZIONE TERZA")])
        XCTAssertEqual(out[0].type, .HEADING_3)
        XCTAssertEqual(out[0].level, 3)
    }
    func test_parte_becomesHeading1() {
        let out = reclass([note("PARTE PRIMA")])
        XCTAssertEqual(out[0].type, .HEADING_1)
        XCTAssertEqual(out[0].level, 1)
    }
    func test_titolo_libro_becomeHeading1() {
        XCTAssertEqual(reclass([note("TITOLO II")])[0].type, .HEADING_1)
        XCTAssertEqual(reclass([note("LIBRO PRIMO")])[0].type, .HEADING_1)
    }
    func test_capo_becomesHeading2() {
        XCTAssertEqual(reclass([note("CAPO I")])[0].type, .HEADING_2)
    }

    // MARK: - GUARDIE / TRAPPOLE (restano NOTE)

    func test_guard_bodyProseWithLowercaseTitolo_notReclassified() {
        // la trappola reale (Mercato p149): prosa di corpo che cita "titolo secondo…",
        // keyword MINUSCOLA e riga lunga → NON è un'intestazione.
        let trap = note("titolo secondo della parte quarta, concernente l’appello al pubblico "
            + "risparmio. In un medesimo contesto si collocano poi le disposizioni seguenti.")
        XCTAssertEqual(reclass([trap])[0].type, .NOTE, "prosa di corpo non diventa heading")
    }
    func test_guard_longMergedStructLine_notReclassified() {
        // un nodo > 70 char che inizia con CAPITOLO ma prosegue in prosa (merge) → NON heading.
        let merged = note("CAPITOLO TERZO della disciplina dei contratti, dove si esamina a fondo "
            + "ogni profilo della materia con dovizia di esempi e richiami giurisprudenziali.")
        XCTAssertEqual(reclass([merged])[0].type, .NOTE)
    }
    func test_guard_realFootnote_notReclassified() {
        XCTAssertEqual(reclass([note("14. D. Buzzati, in Corriere della Sera, 1951.")])[0].type, .NOTE)
    }
    func test_guard_bodyNodeStartingSommario_notTouched() {
        // solo i nodi NOTE sono riclassificati: un BODY che inizia "Sommario:" resta BODY.
        let body = NodeDict(id: "b", type: .BODY, page_index: 5, text: "Sommario: come anticipato…")
        XCTAssertEqual(reclass([body])[0].type, .BODY)
    }
    func test_guard_plainNote_staysNote() {
        let out = reclass([note("Si tratta di una nota qualunque senza marcatore di apertura.")])
        XCTAssertEqual(out[0].type, .NOTE)
    }
    func test_guard_capitoloLowercaseMidSentence_notReclassified() {
        XCTAssertEqual(reclass([note("Il capitolo terzo affronta la questione centrale.")])[0].type, .NOTE)
    }

    // MARK: - non-distruttività (rete A/allineamento binding)

    func test_inPosition_countOrderIdTextPreserved() {
        let input = [
            note("BODY-ish nota vera 1. Autore.", "n0", page: 1),
            note("SOMMARIO: 1. X. – 2. Y.", "n1", page: 1),
            note("CAPITOLO PRIMO", "n2", page: 2),
        ]
        let out = reclass(input)
        XCTAssertEqual(out.count, input.count, "nessun nodo aggiunto o tolto")
        XCTAssertEqual(out.map { $0.id }, ["n0", "n1", "n2"], "ordine e id invariati")
        XCTAssertEqual(out.map { $0.text }, input.map { $0.text }, "testo invariato (rete A)")
        XCTAssertEqual(out[0].type, .NOTE)
        XCTAssertEqual(out[1].type, .CHAPTER_SUMMARY)
        XCTAssertEqual(out[2].type, .HEADING_2)  // CAPITOLO → HEADING_2
    }
    func test_noMatches_returnsZeroCounts() {
        var n = [note("una nota"), NodeDict(id: "b", type: .BODY, page_index: 1, text: "corpo")]
        let r = reclassifyCleanFamilies(&n)
        XCTAssertEqual(r.summary, 0)
        XCTAssertEqual(r.heading, 0)
    }
}
