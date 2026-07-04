//
//  GiappichelliSectionBibliographyTests.swift
//  ScaboCoreTests
//
//  Trattenimento della bibliografia di sezione fino a fine sezione (Lezioni di giustizia
//  amm.va). `holdGiappichelliSectionBibliography` sposta ogni blocco LETTERATURA appena prima
//  del titolo che apre la sezione successiva. È una PERMUTAZIONE PURA: rete A per costruzione
//  (multiset invariato, testo mai toccato). Isolato a Lezioni dalla presenza dei titoli §.
//

import XCTest
@testable import ScaboCore

final class GiappichelliSectionBibliographyTests: XCTestCase {

    private func seg(_ id: String, _ role: SemanticCategory, _ text: String) -> ContentSegment {
        ContentSegment(id: id, role: role.rawValue, text: text, lengthCategory: "", acousticIntro: "")
    }
    private func h4(_ id: String, _ text: String) -> ContentSegment { seg(id, .HEADING_4, text) }
    private func body(_ id: String, _ text: String) -> ContentSegment { seg(id, .BODY, text) }
    private func lett(_ id: String, _ text: String) -> ContentSegment { seg(id, .LETTERATURA, text) }

    private func ids(_ s: [ContentSegment]) -> [String] { s.map { $0.id } }

    // MARK: - spostamento

    func test_sectionOpeningBiblio_movedToSectionEnd() {
        // § 1 → bibliografia → corpo → § 2 : la bibliografia di §1 va a fine §1 (prima di §2)
        let input = [
            h4("s1", "§ 1. Premessa"),
            lett("l1", "BENVENUTI, Giustizia amministrativa, in Enc. dir., 1970"),
            body("b1", "Nel diritto amministrativo la garanzia del cittadino…"),
            body("b2", "Nello Stato di diritto più evoluto…"),
            h4("s2", "§ 2. Gli istituti della giustizia amministrativa"),
        ]
        let out = holdGiappichelliSectionBibliography(input)
        XCTAssertEqual(ids(out), ["s1", "b1", "b2", "l1", "s2"], "biblio dopo il corpo, prima di §2")
    }

    func test_midParagraphIntrusion_paragraphRestitched_biblioAtEnd() {
        // § 1 → corpo1 → bibliografia in mezzo → corpo2 → § 2 :
        // corpo1 e corpo2 diventano adiacenti (discorso ricucito), la bibliografia va a fine sezione.
        let input = [
            h4("s1", "§ 1. L’interesse legittimo"),
            body("b1", "…è una posizione qualificata"),
            lett("l1", "SANDULLI, Manuale di diritto amministrativo, 1989"),
            body("b2", "Non è sufficiente, però, la configurabilità…"),
            h4("s2", "§ 2. Considerazioni"),
        ]
        let out = holdGiappichelliSectionBibliography(input)
        XCTAssertEqual(ids(out), ["s1", "b1", "b2", "l1", "s2"], "corpo1+corpo2 adiacenti, biblio a fine sezione")
        // il paragrafo non è più spezzato: fra b1 e b2 non c'è più la bibliografia
        let i1 = out.firstIndex { $0.id == "b1" }!, i2 = out.firstIndex { $0.id == "b2" }!
        XCTAssertEqual(i2, i1 + 1, "corpo continuo, niente bibliografia in mezzo")
    }

    func test_multipleLetteraturaBlocks_stayTogether_atEnd() {
        let input = [
            h4("s1", "§ 1. Premessa"),
            lett("l1", "AA.VV., Prima opera, Milano 2019"),
            lett("l2", "ROSSI, Seconda opera, in Riv., 2020"),
            body("b1", "Testo della sezione."),
            h4("s2", "§ 2. Segue"),
        ]
        let out = holdGiappichelliSectionBibliography(input)
        XCTAssertEqual(ids(out), ["s1", "b1", "l1", "l2", "s2"], "le due voci restano insieme, a fine sezione")
    }

    func test_lastSection_biblioAtDocumentEnd() {
        let input = [
            h4("s1", "§ 1. Premessa"),
            lett("l1", "BENVENUTI, opera, 1970"),
            body("b1", "Ultimo corpo."),
        ]
        let out = holdGiappichelliSectionBibliography(input)
        XCTAssertEqual(ids(out), ["s1", "b1", "l1"], "ultima sezione: bibliografia a fondo documento")
    }

    func test_chapterBoundary_flushesPendingBiblio() {
        // la bibliografia dell'ultimo § di un capitolo esce prima del sommario del capitolo dopo
        let input = [
            h4("s1", "§ 1. Ultimo della sezione"),
            lett("l1", "ROSSI, opera, 2020"),
            body("b1", "corpo"),
            seg("sm", .CHAPTER_SUMMARY, "SOMMARIO: 1. …"),
            h4("s2", "§ 1. Nuovo capitolo"),
        ]
        let out = holdGiappichelliSectionBibliography(input)
        XCTAssertEqual(ids(out), ["s1", "b1", "l1", "sm", "s2"], "biblio prima del sommario del capitolo dopo")
    }

    // MARK: - rete A (permutazione pura)

    func test_purePermutation_multisetInvariant() {
        let input = [
            h4("s1", "§ 1. Premessa"), lett("l1", "AA.VV., opera, 2019"),
            body("b1", "uno"), body("b2", "due"),
            h4("s2", "§ 2. Segue"), lett("l2", "ROSSI, opera, 2020"), body("b3", "tre"),
        ]
        let out = holdGiappichelliSectionBibliography(input)
        XCTAssertEqual(out.count, input.count, "nessun segmento perso o duplicato")
        XCTAssertEqual(Set(ids(out)), Set(ids(input)), "stesso insieme di segmenti")
        // testo invariato per ogni id (nessuna parola toccata)
        let inById = Dictionary(uniqueKeysWithValues: input.map { ($0.id, $0.text) })
        for s in out { XCTAssertEqual(s.text, inById[s.id], "testo invariato per \(s.id)") }
    }

    // MARK: - isolamento (guardia §) e no-op

    func test_noSectionMarkers_noOp() {
        // volume-famiglia a note numerate: HEADING_4 NON a firma § (o assenti) → nessuno spostamento
        let input = [
            seg("h", .HEADING_4, "1. Paragrafo numerato"),   // non è "§ N."
            lett("l1", "ROSSI, opera, 2020"),
            body("b1", "corpo"),
        ]
        let out = holdGiappichelliSectionBibliography(input)
        XCTAssertEqual(ids(out), ["h", "l1", "b1"], "niente § → no-op (byte-identico)")
    }

    func test_noHeadings_noOp() {
        let input = [lett("l1", "ROSSI, opera, 2020"), body("b1", "corpo")]
        let out = holdGiappichelliSectionBibliography(input)
        XCTAssertEqual(ids(out), ["l1", "b1"], "nessun heading → no-op")
    }
}
