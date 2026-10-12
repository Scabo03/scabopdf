//
//  NoteJumpTests.swift
//  ScaboCoreTests
//
//  Legami nota ↔ testo del richiamo (`noteCallLinks`, § 7.12). Regola d'oro: senza riscontro del
//  richiamo, nessun legame — un salto sbagliato è peggio di nessun salto.
//

import XCTest
@testable import ScaboCore

final class NoteJumpTests: XCTestCase {

    private func s(_ role: String, _ text: String, refresh: String = "") -> ContentSegment {
        ContentSegment(id: UUID().uuidString, role: role, text: text, lengthCategory: "",
                       acousticIntro: "", memoryRefresh: refresh)
    }

    func test_inlineNote_linksToPrecedingTextWithCall() {
        let segs = [
            s("BODY", "La tesi del raccolto anticipato è discussa 31."),
            s("NOTE", "31 ROSSI, op. cit., p. 10."),
        ]
        let l = noteCallLinks(segs)
        XCTAssertEqual(l.callOfNote[1], 0)
        XCTAssertEqual(l.notesOfCall[0], [1])
    }

    func test_inlineNotes_groupAfterSameSentence_allLink() {
        let segs = [
            s("BODY", "Con gli studi di Staub 194, Stoll 195, Larenz 196."),
            s("NOTE", "194 STAUB, op. cit."), s("NOTE", "195 STOLL, op. cit."), s("NOTE", "196 LARENZ, op. cit."),
        ]
        let l = noteCallLinks(segs)
        XCTAssertEqual(l.notesOfCall[0], [1, 2, 3])
    }

    func test_deferredNote_linksBackThroughRefreshPhrase() {
        let segs = [
            s("HEADING_3", "1. La stagione del raccolto."),
            s("BODY", "Paradigmatico è il caso in cui la responsabilità sia proporzionale 37, giacché la funzione…"),
            s("BODY", "Altro paragrafo senza richiami."),
            s("NOTE", "37 Anche per altri argomenti a favore…",
              refresh: "Paradigmatico è il caso in cui la responsabilità sia proporzionale"),
        ]
        XCTAssertEqual(noteCallLinks(segs).callOfNote[3], 1)
    }

    func test_numberAsReference_isNotACall() {
        // «art. 5» non è il richiamo della nota 5.
        let segs = [s("BODY", "Si applica l’art. 5 del decreto."), s("NOTE", "5 Cfr. Cass. 12 marzo 2010.")]
        XCTAssertNil(noteCallLinks(segs).callOfNote[1])
    }

    func test_deferredNote_doesNotCrossSectionHeading() {
        let segs = [
            s("BODY", "la responsabilità sia proporzionale 37, giacché"),
            s("HEADING_3", "2. La faglia del fortuito."),
            s("BODY", "Nuova sezione."),
            s("NOTE", "37 Nota.", refresh: "la responsabilità sia proporzionale"),
        ]
        XCTAssertNil(noteCallLinks(segs).callOfNote[3], "il richiamo sta nella stessa sezione della nota")
    }

    func test_noMatch_noLink() {
        let segs = [s("BODY", "Testo che non richiama nulla."), s("NOTE", "12 Una nota orfana.")]
        XCTAssertTrue(noteCallLinks(segs).callOfNote.isEmpty)
    }

    /// L'elemento «risorsa visiva» è additivo e trasparente: una figura collocata fra il blocco e le sue note in linea
    /// non diventa il richiamo, e il legame resta col blocco (giro risorse visive, 2026-10-12).
    func test_inlineNote_skipsVisualResourceElement() {
        let segs = [
            s("BODY", "La tesi del raccolto anticipato è discussa 31."),
            s(VISUAL_RESOURCE_ROLE, "Figura: Schema del raccolto"),
            s("NOTE", "31 ROSSI, op. cit., p. 10."),
        ]
        let l = noteCallLinks(segs)
        XCTAssertEqual(l.callOfNote[2], 0)
        XCTAssertEqual(l.notesOfCall[0], [2])
        XCTAssertNil(l.notesOfCall[1])
    }

    func test_deferredNote_neverLinksToVisualResourceElement() {
        let segs = [
            s("HEADING_3", "1. La stagione del raccolto."),
            s(VISUAL_RESOURCE_ROLE, "Tabella: la stagione del raccolto secondo la tesi prevalente 5"),
            s("NOTE", "5 Così la tesi prevalente.", refresh: "la stagione del raccolto secondo la tesi prevalente"),
        ]
        XCTAssertNil(noteCallLinks(segs).callOfNote[2])
    }
}
