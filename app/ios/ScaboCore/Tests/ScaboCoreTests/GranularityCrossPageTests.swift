//
//  GranularityCrossPageTests.swift
//  ScaboCoreTests
//
//  Brick 2 — ricostruzione del corpo attraverso le pagine in granularizeBody:
//  de-sillabazione della giunzione + trattenimento dell'apparato dentro un paragrafo
//  aperto, con le guardie anti-fusione (CAPS, SHORT, LIST-next, next-uppercase).
//

import XCTest
@testable import ScaboCore

final class GranularityCrossPageTests: XCTestCase {

    private func seg(_ role: String, _ text: String, _ id: String) -> ContentSegment {
        ContentSegment(id: id, role: role, text: text, lengthCategory: "", acousticIntro: "")
    }
    private let BODY = SemanticCategory.BODY.rawValue
    private let NOTE = SemanticCategory.NOTE.rawValue
    private let H4 = SemanticCategory.HEADING_4.rawValue

    private func joinedBody(_ out: [ContentSegment]) -> String {
        out.filter { $0.role == BODY }.map { $0.text }.joined(separator: " ⟂ ")
    }

    // MARK: de-sillabazione

    func test_dehyphenate_adjacentBodyHalves() {
        let out = granularizeBody([
            seg(BODY, "Nel racconto biblico la prima cronaca di un processo è amministrata dalla giu-", "a"),
            seg(BODY, "stizia contenuta nei poemi omerici e nelle saghe antiche del nord.", "b"),
        ])
        let body = out.filter { $0.role == BODY }.map { $0.text }.joined(separator: " ")
        XCTAssertTrue(body.contains("giustizia contenuta"), "trattino di fine riga assorbito: \(body)")
        XCTAssertFalse(body.contains("giu- stizia"))
        XCTAssertFalse(body.contains("giu-stizia"))  // niente trattino residuo
    }

    func test_dehyphenate_onlyWhenNextLowercase() {
        // trattino + maiuscola (NON sillabazione): resta com'era (spazio), nessuna distorsione.
        let out = granularizeBody([
            seg(BODY, "Il movimento era diviso tra le posizioni pro-", "a"),
            seg(BODY, "Stato e quelle contrarie, secondo una linea netta e dichiarata.", "b"),
        ])
        let body = out.filter { $0.role == BODY }.map { $0.text }.joined(separator: " ")
        XCTAssertFalse(body.contains("proStato"), "non de-sillabare prima di maiuscola: \(body)")
    }

    // MARK: apparato trattenuto (mai dentro il periodo)

    func test_noteHeld_movedAfterReconstructedParagraph() {
        let out = granularizeBody([
            seg(BODY, "La prima cronaca di un processo si trova nei poemi e racconta della giu-", "a"),
            seg(NOTE, "3. Iliade, 18, 497-508.", "n"),
            seg(BODY, "stizia contenuta nei versi antichi. Si tratta di una controversia per un omicidio.", "b"),
        ])
        // il paragrafo è ricucito (parola intera) e la nota è DOPO, non dentro la parola.
        let firstNoteIdx = out.firstIndex { $0.role == NOTE }!
        let bodyBefore = out[..<firstNoteIdx].contains { $0.role == BODY && $0.text.contains("giustizia contenuta nei versi") }
        XCTAssertTrue(bodyBefore, "la parola spezzata è ricomposta PRIMA della nota")
        XCTAssertEqual(out.last?.role, NOTE, "la nota è ri-emessa dopo il paragrafo ricucito")
        XCTAssertFalse(joinedBody(out).contains("giu- "))
    }

    func test_noteHeld_noterm_midClause() {
        let out = granularizeBody([
            seg(BODY, "Il giudice nel decidere le controversie deve seguire le norme del diritto e", "a"),
            seg(NOTE, "12. V. Cass. n. 731.", "n"),
            seg(BODY, "non può discostarsene se non nei casi previsti dalla legge vigente in materia.", "b"),
        ])
        let body = out.filter { $0.role == BODY }.map { $0.text }.joined(separator: " ")
        XCTAssertTrue(body.contains("del diritto e non può discostarsene"), "ricucitura mid-periodo: \(body)")
        XCTAssertEqual(out.last?.role, NOTE)
    }

    // MARK: guardie anti-fusione (zero falsi-fusione)

    func test_guard_capsHeadingNotMerged() {
        let out = granularizeBody([
            seg(BODY, "SCHEMA RIASSUNTIVO DELLE RISERVE COSTITUZIONALI PREVISTE", "a"),
            seg(NOTE, "1. nota.", "n"),
            seg(BODY, "zionali: il procedimento legislativo ordinario e quello aggravato di revisione.", "b"),
        ])
        XCTAssertFalse(joinedBody(out).contains("PREVISTE zionali"), "schema maiuscolo NON fuso col seguito")
        XCTAssertFalse(joinedBody(out).contains("PREVISTEzionali"))
    }

    func test_guard_shortOpenNotMerged() {
        let out = granularizeBody([
            seg(BODY, "– a", "a"),
            seg(NOTE, "1. nota.", "n"),
            seg(BODY, "seguito dell'estinzione del reato per prescrizione maturata nel frattempo.", "b"),
        ])
        // frammento corto: non è target di ricucitura → la nota NON è trattenuta dopo di esso.
        XCTAssertFalse(joinedBody(out).contains("– a seguito dell'estinzione"))
    }

    func test_guard_listMarkerNextNotMerged() {
        let out = granularizeBody([
            seg(BODY, "La Repubblica ha il compito di rimuovere gli ostacoli di ordine economico e", "a"),
            seg(NOTE, "1. nota.", "n"),
            seg(BODY, "a) la politica europea che concerne i rapporti con gli altri Stati membri.", "b"),
        ])
        XCTAssertFalse(joinedBody(out).contains("economico e a) la politica"), "elenco NON fuso")
    }

    func test_guard_uppercaseNextNotMerged() {
        let out = granularizeBody([
            seg(BODY, "La dottrina prevalente su questo punto è quella sostenuta da autori come secondo", "a"),
            seg(NOTE, "1. nota.", "n"),
            seg(BODY, "Bianca e Castronovo, che escludono ogni responsabilità in questa ipotesi.", "b"),
        ])
        // next maiuscolo (nome proprio o nuovo periodo): conservativo, NON si fonde.
        XCTAssertFalse(joinedBody(out).contains("secondo Bianca e Castronovo"))
    }

    func test_completeParagraph_noteNotHeld() {
        // run chiuso (punto fermo): la nota NON è trattenuta, resta al suo posto.
        let out = granularizeBody([
            seg(BODY, "Questa è una frase completa che termina regolarmente con il punto fermo finale.", "a"),
            seg(NOTE, "1. nota.", "n"),
            seg(BODY, "Questo è un nuovo paragrafo che inizia in maiuscolo come di consueto in italiano.", "b"),
        ])
        let noteIdx = out.firstIndex { $0.role == NOTE }!
        XCTAssertTrue(out[..<noteIdx].contains { $0.role == BODY }, "prima della nota c'è il primo paragrafo")
        XCTAssertTrue(out[(noteIdx + 1)...].contains { $0.role == BODY }, "dopo la nota c'è il secondo paragrafo")
    }

    func test_headingClosesRun_notHeld() {
        let out = granularizeBody([
            seg(BODY, "Un paragrafo che finisce a metà periodo e prosegue dopo, in teoria, ma qui c'è un", "a"),
            seg(H4, "NUOVA SEZIONE", "h"),
            seg(BODY, "titolo che chiude il run: il corpo non attraversa mai un confine di intestazione.", "b"),
        ])
        XCTAssertTrue(out.contains { $0.role == H4 }, "l'intestazione passa invariata")
        XCTAssertFalse(joinedBody(out).contains("qui c'è un titolo che chiude"), "non si fonde oltre un heading")
    }
}
