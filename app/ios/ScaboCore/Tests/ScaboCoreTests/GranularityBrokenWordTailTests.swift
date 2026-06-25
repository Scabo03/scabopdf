//
//  GranularityBrokenWordTailTests.swift
//  ScaboCoreTests
//
//  Mattone 3 — la CODA di una parola spezzata col trattino di fine riga, finita
//  incollata al numero di richiamo e classificata NOTE dal classificatore size-only
//  ("…più ecce-" / NOTE "zionali.14" / "Si parla…"). Il run de-sillaba la coda nella
//  parola e rimuove il SOLO numero di richiamo (la nota vera resta letta a fondo
//  pagina); il frammento-NOTE spurio sparisce. Con le guardie del PALETTO: la regola
//  scatta solo sul pattern coda-spezzata-+-numero e non tocca nessun altro richiamo.
//

import XCTest
@testable import ScaboCore

final class GranularityBrokenWordTailTests: XCTestCase {

    private func seg(_ role: String, _ text: String, _ id: String) -> ContentSegment {
        ContentSegment(id: id, role: role, text: text, lengthCategory: "", acousticIntro: "")
    }
    private let BODY = SemanticCategory.BODY.rawValue
    private let NOTE = SemanticCategory.NOTE.rawValue

    private func joinedBody(_ out: [ContentSegment]) -> String {
        out.filter { $0.role == BODY }.map { $0.text }.joined(separator: " ")
    }

    // MARK: - Caso canonico (riproduce gli 8 casi reali di Delitti)

    func test_brokenWordTail_fusedAndMarkerRemoved() {
        let out = granularizeBody([
            seg(BODY, "I giornali tendono a esaltare i personaggi più romanzeschi, più ecce-", "a"),
            seg(NOTE, "zionali.14", "n"),
            seg(BODY, "Si parla di “bassa stampa” riferendosi a una certa stampa popolare.", "b"),
        ])
        let body = joinedBody(out)
        XCTAssertTrue(body.contains("più eccezionali."), "parola ricucita: \(body)")
        XCTAssertFalse(body.contains("ecce-"), "trattino assorbito")
        XCTAssertFalse(body.contains("zionali.14"), "frammento NON resta nel corpo")
        XCTAssertFalse(body.contains("14"), "numero di richiamo rimosso dalla coda")
        XCTAssertFalse(out.contains { $0.role == NOTE }, "il frammento-NOTE spurio è sparito")
        XCTAssertTrue(body.contains("eccezionali. Si parla"), "la frase prosegue nello stesso flusso")
    }

    func test_brokenWordTail_multiWordTail() {
        // "confronta-" + "no nel processo" → "confrontano nel processo"; marker 65 rimosso.
        let out = granularizeBody([
            seg(BODY, "Il caso è raccontato dando spazio alle parti che sono coinvolte e si confronta-", "a"),
            seg(NOTE, "no nel processo.65", "n"),
            seg(BODY, "In una gara al sensazionalismo le notizie si rincorrono ogni giorno.", "b"),
        ])
        let body = joinedBody(out)
        XCTAssertTrue(body.contains("si confrontano nel processo."), "coda multi-parola ricucita: \(body)")
        XCTAssertFalse(body.contains("65"), "numero di richiamo rimosso")
        XCTAssertFalse(out.contains { $0.role == NOTE })
    }

    // MARK: - PALETTO: nessun altro richiamo toccato

    func test_paletto_inlineMarkerInBodyUntouched() {
        // Un richiamo "(14)" dentro una FRASE NORMALE (nodo BODY) NON è un frammento
        // trattenuto: resta intatto e leggibile. La regola non lo raggiunge mai.
        let out = granularizeBody([
            seg(BODY, "La dottrina prevalente (14) ritiene che la regola si applichi sempre nei processi.", "a"),
        ])
        let body = joinedBody(out)
        XCTAssertTrue(body.contains("(14)"), "il richiamo in frase normale resta: \(body)")
    }

    func test_paletto_realFootnoteStartingWithNumber_notFused() {
        // Nota VERA (inizia col proprio numero "14. …"): mai ricucita, mai privata del
        // numero — è apparato, non coda di parola. Resta letta (ri-emessa dopo, mattone 2).
        let out = granularizeBody([
            seg(BODY, "Il romanzo d’appendice racconta vicende giudiziarie in forma popola-", "a"),
            seg(NOTE, "14. D. Buzzati, “Più penoso che grande questo romanzo”, in Corriere, 1951.", "n"),
            seg(BODY, "Pratiche come il perp walk danno risalto alla scena pubblica del fermo.", "b"),
        ])
        XCTAssertTrue(out.contains { $0.role == NOTE && ($0.text).hasPrefix("14.") },
                      "la nota vera resta, col suo numero")
        XCTAssertTrue(joinedBody(out).contains("popola-") == false
                      || joinedBody(out).contains("14.") == false,
                      "il numero della nota vera non finisce nel corpo")
    }

    func test_paletto_longNoteWithLowercaseStart_isBrick2NotFragment() {
        // Caso reale #414: "comu-" / nota lunga che inizia minuscola ("logia francese…") /
        // "nicazione…" (continuazione minuscola). La parola si completa nel BODY DOPO la
        // nota (mattone 2), NON nella nota: niente ricucitura-frammento, nota preservata.
        let longNote = "logia francese è il magistrato del pubblico ministero che sostiene "
            + "l’accusa davanti alla Corte di assise. 21. Conseil supérieur, 2019, p. 59."
        let out = granularizeBody([
            seg(BODY, "I magistrati francesi hanno definito i loro rapporti con i mezzi di comu-", "a"),
            seg(NOTE, longNote, "n"),
            seg(BODY, "nicazione e in particolare di comunicazione giudiziaria nel paese.", "b"),
        ])
        let body = joinedBody(out)
        XCTAssertTrue(body.contains("mezzi di comunicazione"), "parola completata dal BODY dopo la nota: \(body)")
        XCTAssertTrue(out.contains { $0.role == NOTE && $0.text == longNote }, "la nota lunga è preservata")
    }

    // MARK: - Nota lunga PIAZZATA fra corpo-trattino e frammento (multi-trattenuto)

    func test_placedNoteBetween_fragmentStillFused_realNoteKept() {
        // bindAndPlaceNotes può inserire una nota lunga piazzata FRA "preoccu-" e la coda
        // "pazione.19". L'apparato trattenuto ha 2 elementi: si fonde SOLO il frammento, la
        // nota vera resta (ri-emessa dopo). È il caso che falliva con la guardia count==1.
        let placed = "211. A. Tizio, Un titolo lungo di nota differita, Editore, Città 2009, p. 211."
        let out = granularizeBody([
            seg(BODY, "Lavorerei meglio, in tutta franchezza, se non avessi alcuna preoccu-", "a"),
            seg(NOTE, placed, "p"),
            seg(NOTE, "pazione.19", "n"),
            seg(BODY, "Pratiche come il perp walk danno risalto alla cattura pubblica.", "b"),
        ])
        let body = joinedBody(out)
        XCTAssertTrue(body.contains("alcuna preoccupazione."), "frammento fuso anche con nota in mezzo: \(body)")
        XCTAssertFalse(body.contains("pazione.19"))
        XCTAssertTrue(out.contains { $0.role == NOTE && $0.text == placed }, "la nota vera piazzata NON è persa")
        XCTAssertFalse(out.contains { $0.role == NOTE && $0.text.contains("pazione") }, "il frammento spurio è sparito")
    }

    // MARK: - Guardie del frammento (helper diretti)

    func test_guard_tooLongTail_notFragment() {
        let seg1 = seg(NOTE, "zione una lunghissima coda che è chiaramente prosa vera e non un troncone.14", "n")
        XCTAssertNil(brokenWordTailCompletion(seg1))
    }

    func test_guard_noTrailingMarker_notFragment() {
        // coda senza numero di richiamo finale → non è il pattern (la prende il mattone 2).
        XCTAssertNil(brokenWordTailCompletion(seg(NOTE, "zionali", "n")))
    }

    func test_guard_openDoesNotEndWithHyphen_notFragment() {
        let held = [seg(NOTE, "zionali.14", "n")]
        XCTAssertNil(wordTailFragmentInHeld(held, openRunLast: "una frase che finisce con virgola,")?.completion)
    }

    func test_guard_uppercaseStart_notFragment() {
        // inizia maiuscola → non completa una parola (è una nota/frase) → nil.
        XCTAssertNil(brokenWordTailCompletion(seg(NOTE, "Zionali.14", "n")))
    }

    func test_inHeld_findsFragmentAmongRealNotes_keepsContext() {
        // [nota vera, frammento]: trova il frammento (indice 1), la nota vera resta.
        let held = [seg(NOTE, "12. A. Autore, Opera, 2010, p. 12.", "r"), seg(NOTE, "zionali.14", "f")]
        let r = wordTailFragmentInHeld(held, openRunLast: "più ecce-")
        XCTAssertEqual(r?.index, 1)
        XCTAssertEqual(r?.completion, "zionali.")
    }

    func test_completion_keepsSentencePeriodDropsOnlyNumber() {
        let c = brokenWordTailCompletion(seg(NOTE, "na coscienza.30", "n"))
        XCTAssertEqual(c, "na coscienza.", "tiene il punto di frase, toglie il solo numero")
    }

    func test_firstAlphaIsLower() {
        XCTAssertTrue(firstAlphaIsLower("zionali.14"))
        XCTAssertTrue(firstAlphaIsLower("  no nel processo.65"))
        XCTAssertFalse(firstAlphaIsLower("14. Autore"))
        XCTAssertFalse(firstAlphaIsLower("Zionali"))
        XCTAssertFalse(firstAlphaIsLower("123"))
    }
}
