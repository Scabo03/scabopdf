//
//  NoteJumpAnchoredTests.swift
//  ScaboCoreTests
//
//  Il riscontro ANCORATO del salto fra nota e richiamo (giro «accessibilità e completamento», 2026-10-18, INBOX D.16):
//  per una nota differita il numero della nota deve seguire SUBITO la coda della frase del richiamo. Lega dove la regola
//  di parola non riconosce il richiamo pur essendoci (dopo un punto, dopo un altro numero, a cavallo di due segmenti); non
//  lega mai nei testi normativi né con un rinfresco corto. Testi inventati.
//

import XCTest
@testable import ScaboCore

final class NoteJumpAnchoredTests: XCTestCase {

    private func s(_ role: String, _ text: String, refresh: String = "", id: String? = nil) -> ContentSegment {
        ContentSegment(id: id ?? UUID().uuidString, role: role, text: text, lengthCategory: "",
                       acousticIntro: "", memoryRefresh: refresh)
    }

    private let sentence = "Il mugnaio apre le chiuse quando la piena del fiume arriva al ponte."

    /// Richiamo dopo il punto («…ponte.37»): la regola di parola non lo vede, il riscontro ancorato sì; salto inverso.
    func test_callAfterAPeriod_links_andTheCallLinksBack() {
        let segs = [
            s("HEADING_3", "1. La stagione del raccolto."),
            s("BODY", "\(sentence)37 Poi la ruota gira fino a sera."),
            s("BODY", "Altro paragrafo di prova senza richiami."),
            s("NOTE", "37 Una nota di prova sul mulino.", refresh: sentence),
        ]
        XCTAssertFalse(containsCallNumber(segs[1].text, 37), "la regola di parola non lo riconosce")
        let l = noteCallLinks(segs)
        XCTAssertEqual(l.callOfNote[3], 1)
        XCTAssertEqual(l.notesOfCall[1], [3], "dal richiamo si salta alla nota")
    }

    /// Richiamo attaccato a un anno («…nel 1990» seguito dal richiamo 12, che il lettore di sistema scrive «199012»).
    func test_callGluedToAYear_links() {
        let refresh = "Il mulino fu costruito sulla riva del fiume nel 1990"
        let segs = [s("BODY", "\(refresh)12 e da allora macina il grano."), s("NOTE", "12 Nota di prova.", refresh: refresh)]
        XCTAssertEqual(noteCallLinks(segs).callOfNote[1], 0)
    }

    /// La frase finisce un segmento e il numero apre il segmento di testo seguente: il richiamo è il primo.
    func test_numberAtTheStartOfTheNextTextSegment_linksToTheSentence() {
        let segs = [
            s("BODY", sentence),
            s("BODY", "37 Poi la ruota gira fino a sera."),
            s("NOTE", "37 Una nota di prova sul mulino.", refresh: sentence),
        ]
        XCTAssertEqual(noteCallLinks(segs).callOfNote[2], 0)
    }

    /// La frase a cavallo di due segmenti consecutivi (granularità), il numero dentro il secondo: il richiamo è il secondo.
    func test_sentenceStraddlingTwoSegments_linksToTheSecond() {
        let segs = [
            s("BODY", "Il mugnaio apre le chiuse quando la piena", id: "n7#0"),
            s("BODY", "del fiume arriva al ponte.37 Poi la ruota gira.", id: "n7#1"),
            s("NOTE", "37 Una nota di prova sul mulino.", refresh: sentence),
        ]
        XCTAssertEqual(noteCallLinks(segs).callOfNote[2], 1)
    }

    /// Prove al contrario: un altro numero dopo la frase, un numero più lungo, un numero che non segue la frase.
    func test_otherNumber_longerNumber_numberElsewhere_noLink() {
        let other = [s("BODY", "\(sentence)38 Poi la ruota."), s("NOTE", "37 Nota di prova.", refresh: sentence)]
        XCTAssertNil(noteCallLinks(other).callOfNote[1], "un altro numero")
        let longer = [s("BODY", "\(sentence)371 Poi la ruota."), s("NOTE", "37 Nota di prova.", refresh: sentence)]
        XCTAssertNil(noteCallLinks(longer).callOfNote[1], "37 non è 371")
        let elsewhere = [s("BODY", "\(sentence) Poi la ruota, scritta nel registro.37"), s("NOTE", "37 Nota.", refresh: sentence)]
        XCTAssertNil(noteCallLinks(elsewhere).callOfNote[1], "il numero non segue la frase del richiamo")
    }

    /// Nei testi normativi (flusso con articoli) un numero in apice dopo «art. N» è il comma: niente riscontro ancorato.
    func test_normativeText_noAnchoredLink() {
        let refresh = "Articolo di prova inserito nel calendario delle uve dall’art. 2"
        let body = "\(refresh)4 del regolamento di prova."
        let discursive = [s("BODY", body), s("NOTE", "4 Nota di prova.", refresh: refresh)]
        XCTAssertEqual(noteCallLinks(discursive).callOfNote[1], 0, "in un testo discorsivo il riscontro ancorato lega")
        let normative = [s("ARTICLE_HEADER", "Art. 9 Articolo di prova"), s("BODY", body), s("NOTE", "4 Nota di prova.", refresh: refresh)]
        XCTAssertNil(noteCallLinks(normative).callOfNote[2], "in un testo normativo no")
    }

    /// Un rinfresco corto (meno di 12 lettere/cifre) non lega nulla, nemmeno ancorato.
    func test_shortRefresh_noLink() {
        let segs = [s("BODY", "Lo dice il mulino.37 Poi."), s("NOTE", "37 Nota di prova.", refresh: "il mulino.")]
        XCTAssertNil(noteCallLinks(segs).callOfNote[1])
    }

    /// La frase a cavallo non scavalca un'intestazione: il segmento prima del richiamo deve essere testo.
    func test_straddleNeverCrossesAHeading() {
        let segs = [
            s("HEADING_3", "Il mugnaio apre le chiuse quando la piena"),
            s("BODY", "del fiume arriva al ponte.37 Poi la ruota gira."),
            s("NOTE", "37 Una nota di prova sul mulino.", refresh: sentence),
        ]
        XCTAssertNil(noteCallLinks(segs).callOfNote[2])
    }

    /// Dove la regola di parola lega già, il legame è quello di prima (il riscontro ancorato non lo tocca).
    func test_existingWordRuleLink_isUnchanged() {
        let segs = [
            s("BODY", "Il mugnaio apre le chiuse quando la piena del fiume arriva al ponte 37, perché la ruota…"),
            s("BODY", "Altro paragrafo di prova."),
            s("NOTE", "37 Nota di prova.", refresh: "Il mugnaio apre le chiuse quando la piena del fiume arriva al ponte"),
        ]
        XCTAssertEqual(noteCallLinks(segs).callOfNote[2], 0)
    }

    /// I pezzi di seguito di una nota frazionata ereditano il legame nuovo del primo pezzo.
    func test_fractionedNote_piecesInheritTheAnchoredLink() {
        let segs = [
            s("BODY", "\(sentence)37 Poi la ruota gira fino a sera."),
            s("NOTE", "37 Primo pezzo della nota di prova.", refresh: sentence, id: "n9_n0#0"),
            s("NOTE_CONTINUATION", "Secondo pezzo della nota di prova.", id: "n9_n0#1"),
        ]
        let l = noteCallLinks(segs)
        XCTAssertEqual(l.callOfNote[1], 0)
        XCTAssertEqual(l.callOfNote[2], 0)
        XCTAssertEqual(l.notesOfCall[0], [1], "dal richiamo si salta al primo pezzo, una volta")
    }

    /// Gli aiuti del riscontro: numero intero dopo la coda, coda a cavallo con almeno un carattere per parte.
    func test_anchoredHelpers() {
        XCTAssertTrue(anchoredNumber(after: "ponte", in: "allaponte37poi", "37"))
        XCTAssertFalse(anchoredNumber(after: "ponte", in: "allaponte371poi", "37"))
        XCTAssertTrue(anchoredNumber(after: "ponte", in: "ponte37", "37"))
        XCTAssertTrue(numberOpens("37poi", "37"))
        XCTAssertFalse(numberOpens("370", "37"))
        XCTAssertTrue(anchoredNumber(straddling: "laquiete", "delponte37poi", "quietedelponte", "37"))
        XCTAssertFalse(anchoredNumber(straddling: "laquietedelponte", "37poi", "quietedelponte", "37"),
                       "la coda intera nel primo segmento non è «a cavallo»")
    }
}
