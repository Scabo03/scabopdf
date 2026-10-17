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

    private func piece(_ id: String, _ role: String, _ text: String, refresh: String = "") -> ContentSegment {
        ContentSegment(id: id, role: role, text: text, lengthCategory: "", acousticIntro: "", memoryRefresh: refresh)
    }

    /// Nota lunga frazionata (§ 10.6): ogni pezzo di seguito ha lo stesso richiamo del primo pezzo; dal richiamo si salta
    /// solo al primo pezzo (giro «uniformità della lettura», 2026-10-16).
    func test_fractionedNote_continuationPiecesLinkToTheSameCall() {
        let segs = [
            piece("b1", "BODY", "Frase di prova del corpo con il richiamo alla nota di prova 37, e poi altro testo di prova…"),
            piece("b2", "BODY", "Paragrafo di prova senza richiami."),
            piece("n9_n0#0", "NOTE", "37 Primo pezzo della nota di prova.",
                  refresh: "Frase di prova del corpo con il richiamo alla nota di prova"),
            piece("n9_n0#1", "NOTE_CONTINUATION", "Secondo pezzo della nota di prova."),
            piece("n9_n0#2", "NOTE_CONTINUATION", "Terzo pezzo della nota di prova."),
            piece("b3", "BODY", "Paragrafo di prova seguente."),
        ]
        let l = noteCallLinks(segs)
        XCTAssertEqual(l.callOfNote[2], 0)
        XCTAssertEqual(l.callOfNote[3], 0)
        XCTAssertEqual(l.callOfNote[4], 0)
        XCTAssertEqual(l.notesOfCall[0], [2], "dal richiamo si salta al primo pezzo, una volta")
        XCTAssertNil(l.callOfNote[5])
    }

    /// Prova al contrario: un pezzo di seguito che non viene dallo stesso nodo del primo pezzo, o un primo pezzo senza
    /// richiamo riscontrato, non dà alcun legame (un salto sbagliato è peggio di nessun salto).
    func test_fractionedNote_continuationOfAnotherNodeOrOfUnlinkedHead_noLink() {
        let other = [
            piece("b1", "BODY", "Frase di prova con il richiamo 31."),
            piece("n1#0", "NOTE", "31 Nota di prova breve."),
            piece("n2#1", "NOTE_CONTINUATION", "Pezzo di prova di un'altra nota."),
        ]
        let a = noteCallLinks(other)
        XCTAssertEqual(a.callOfNote[1], 0)
        XCTAssertNil(a.callOfNote[2])
        let unlinked = [
            piece("b1", "BODY", "Frase di prova che non richiama nulla."),
            piece("n3#0", "NOTE", "12 Nota di prova senza richiamo."),
            piece("n3#1", "NOTE_CONTINUATION", "Seguito di prova della nota senza richiamo."),
        ]
        XCTAssertTrue(noteCallLinks(unlinked).callOfNote.isEmpty)
    }

    /// Un elemento «risorsa visiva» fra due pezzi della stessa nota è trasparente: il pezzo dopo l'elemento ritrova il
    /// primo pezzo.
    func test_fractionedNote_visualResourceBetweenPieces_isTransparent() {
        let segs = [
            piece("b1", "BODY", "Frase di prova con il richiamo 31."),
            piece("n1#0", "NOTE", "31 Nota di prova breve."),
            piece("v1", VISUAL_RESOURCE_ROLE, "Tabella"),
            piece("n1#1", "NOTE_CONTINUATION", "Seguito di prova della nota."),
        ]
        XCTAssertEqual(noteCallLinks(segs).callOfNote[3], 0)
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
            s("BODY", "Il mugnaio apre le chiuse quando la piena del fiume arriva al ponte 37, perché la ruota…"),
            s("BODY", "Altro paragrafo senza richiami."),
            s("NOTE", "37 Una nota di prova sul mulino e sulla piena…",
              refresh: "Il mugnaio apre le chiuse quando la piena del fiume arriva al ponte"),
        ]
        XCTAssertEqual(noteCallLinks(segs).callOfNote[3], 1)
    }

    /// Richiamo fra parentesi (INBOX D.11, giro «pulizia e rifinitura finale del capitolo note», 2026-10-17): «(12)» subito
    /// dopo una parola o una chiusura, anche col punto di un'abbreviazione, è un richiamo; con le stesse esclusioni.
    func test_parenthesizedCall_links() {
        let inline = [s("BODY", "La tesi del raccolto anticipato è discussa (31)."), s("NOTE", "(31) ROSSI, op. cit., p. 10.")]
        XCTAssertEqual(noteCallLinks(inline).callOfNote[1], 0)
        let deferred = [
            s("BODY", "Il mugnaio apre le chiuse quando la piena del fiume arriva al ponte (37), perché la ruota…"),
            s("BODY", "Altro paragrafo senza richiami."),
            s("NOTE", "(37) Una nota di prova sul mulino e sulla piena…",
              refresh: "Il mugnaio apre le chiuse quando la piena del fiume arriva al ponte"),
        ]
        XCTAssertEqual(noteCallLinks(deferred).callOfNote[2], 0)
        XCTAssertTrue(containsCallNumber("così la dottrina, op. cit. (12)", 12))
        XCTAssertTrue(containsCallNumber("il raccolto (art. 5 del decreto) (12)", 12))
        XCTAssertTrue(containsCallNumber("il raccolto(12)", 12))
    }

    func test_parenthesizedNumberAfterAReferenceAbbreviation_isNotACall() {
        // «art. (5)», «n. (12)»: riferimenti, non richiami; e un numero diverso non conferma
        XCTAssertFalse(containsCallNumber("la vendemmia segue l’art. (5) del calendario delle uve", 5))
        XCTAssertFalse(containsCallNumber("vedi il n. (12) della serie", 12))
        XCTAssertFalse(containsCallNumber("la tesi discussa (13)", 12))
        XCTAssertFalse(containsCallNumber("la tesi discussa (123)", 12))
        XCTAssertFalse(containsCallNumber("la tesi discussa (12 maggio)", 12))
        let segs = [s("BODY", "La vendemmia segue l’art. (5) del calendario delle uve."), s("NOTE", "(5) Una nota di prova.")]
        XCTAssertNil(noteCallLinks(segs).callOfNote[1])
    }

    func test_numberAsReference_isNotACall() {
        // «art. 5» non è il richiamo della nota 5.
        let segs = [s("BODY", "Si applica l’art. 5 del decreto."), s("NOTE", "5 Cfr. Cass. 12 marzo 2010.")]
        XCTAssertNil(noteCallLinks(segs).callOfNote[1])
    }

    func test_deferredNote_doesNotCrossSectionHeading() {
        let segs = [
            s("BODY", "la piena del fiume arriva al ponte 37, perché"),
            s("HEADING_3", "2. La faglia del fortuito."),
            s("BODY", "Nuova sezione."),
            s("NOTE", "37 Nota.", refresh: "la piena del fiume arriva al ponte"),
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
