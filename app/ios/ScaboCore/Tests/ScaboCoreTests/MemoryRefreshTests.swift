//
//  MemoryRefreshTests.swift
//  ScaboCoreTests
//
//  Rete del memory refresh per le note differite (§ 7.4/§ 7.5), sui parametri decisi
//  dal maintainer (pavimento 60, tetto 180). Un test per ogni regola: richiamo dopo
//  punto → frase precedente; segmento corto → estensione al pavimento; frase lunga →
//  troncamento pulito al tetto conservando la parte vicina al richiamo; abbreviazione
//  non scambiata per fine-frase; citazione bibliografica saltata; sillabazione ricucita;
//  testa non-prosa scartata.
//

import XCTest
@testable import ScaboCore

final class MemoryRefreshTests: XCTestCase {

    /// Offset di CARATTERE in cui inizia la sottostringa `needle` in `text`.
    private func offset(of needle: String, in text: String) -> Int {
        let r = text.range(of: needle)!
        return text.distance(from: text.startIndex, to: r.lowerBound)
    }

    // MARK: - Regola 3: richiamo subito dopo il punto → frase appena conclusa

    func test_markerRightAfterPeriod_rereadsPreviousSentence() {
        // L'apice cade dopo il punto: la nota commenta la frase appena conclusa.
        let text = "Il pretore urbano amministrava la giustizia tra cittadini romani. "
            + "Dopo di allora le cose cambiarono radicalmente nel tempo."
        let mk = offset(of: "Dopo", in: text)
        let r = memoryRefreshSegment(text, markerOffset: mk)
        XCTAssertTrue(r.contains("Il pretore urbano amministrava"), "rilegge la frase precedente: \(r)")
        XCTAssertTrue(r.contains("romani"))
        XCTAssertFalse(r.contains("Dopo"), "non parte dal vuoto dopo il punto: \(r)")
        XCTAssertFalse(r.isEmpty)
    }

    // MARK: - Regola 1/4: segmento corto → estensione fino al pavimento (≥ 60)

    func test_shortLeadIn_extendsBackToFloor() {
        let text = "Prima frase di contesto sufficientemente lunga per superare il pavimento. "
            + "Breve qui."
        // marcatore a metà della seconda frase (lead-in "Breve " ≈ 6 char < 60).
        let mk = offset(of: "qui", in: text)
        let r = memoryRefreshSegment(text, markerOffset: mk)
        XCTAssertGreaterThanOrEqual(r.count, 60, "esteso fino al pavimento: \(r.count) — \(r)")
        XCTAssertTrue(r.contains("Prima frase di contesto"), "include la frase precedente: \(r)")
        XCTAssertTrue(r.hasSuffix("Breve"), "conserva il lead-in fino al richiamo: \(r)")
    }

    func test_healthyMidSentence_noExtensionNoTruncation() {
        let text = "La dottrina prevalente ritiene che il danno sia risarcibile in ogni caso, qui."
        let mk = offset(of: "qui", in: text)
        let r = memoryRefreshSegment(text, markerOffset: mk)
        // un'unica frase, lead-in già ≥ 60 e ≤ 180: si rilegge dal suo inizio.
        XCTAssertTrue(r.hasPrefix("La dottrina prevalente"), r)
        XCTAssertGreaterThanOrEqual(r.count, 60)
        XCTAssertLessThanOrEqual(r.count, 180)
    }

    // MARK: - Regola 2/5: frase lunga → troncamento pulito al tetto, parte vicina al richiamo

    func test_longSentence_cleanTruncationAtCeiling_keepsNearMarker() {
        let lead = "All'inizio della frase si discute un principio generale del tutto preliminare "
            + "e secondario rispetto al punto che davvero conta, e poi si arriva al cuore della "
            + "questione che riguarda la responsabilità del debitore inadempiente verso il creditore"
        let text = lead + " danneggiato."
        let mk = offset(of: "danneggiato", in: text)
        let r = memoryRefreshSegment(text, markerOffset: mk)
        XCTAssertLessThanOrEqual(r.count, 180, "rispetta il tetto: \(r.count)")
        XCTAssertTrue(r.hasSuffix("creditore"), "conserva la parte vicina al richiamo: \(r)")
        XCTAssertFalse(r.contains("All'inizio della frase"), "scarta la parte lontana dal richiamo: \(r)")
        // taglio pulito: non inizia a metà di una parola (prima lettera = inizio parola).
        let firstWord = r.split(separator: " ").first.map(String.init) ?? ""
        XCTAssertFalse(lead.contains("o" + firstWord), "non inizia a metà parola: \(firstWord)")
    }

    // MARK: - Regola 7: abbreviazione non scambiata per fine-frase

    func test_abbreviationDotIsNotASentenceBoundary() {
        let text = "Secondo l'art. 1218 c.c. il debitore risponde dei danni qui."
        let mk = offset(of: "qui", in: text)
        let r = memoryRefreshSegment(text, markerOffset: mk)
        XCTAssertTrue(r.contains("art. 1218 c.c. il debitore risponde"),
                      "i punti di abbreviazione NON tagliano la frase: \(r)")
    }

    // MARK: - Regola 7: ricucitura delle sillabazioni di fine riga

    func test_hyphenationStitched() {
        XCTAssertEqual(stitchHyphenation("sul-la c.d. rivalutazio-ne del credito"),
                       "sulla c.d. rivalutazione del credito")
        XCTAssertEqual(stitchHyphenation("am-messa dalla Cassazione"), "ammessa dalla Cassazione")
        // composto reale: il trattino resta.
        XCTAssertEqual(stitchHyphenation("regime ex-articolo"), "regime ex-articolo")
    }

    func test_refreshStitchesHyphenationInSegment() {
        let text = "La norma riguarda la rivalutazio-ne del credito del lavoratore subordinato qui."
        let mk = offset(of: "qui", in: text)
        let r = memoryRefreshSegment(text, markerOffset: mk)
        XCTAssertTrue(r.contains("rivalutazione"), "sillabazione ricucita nel rinfresco: \(r)")
        XCTAssertFalse(r.contains("rivalutazio-ne"))
    }

    // MARK: - Regola 7: scarto della testa non-prosa

    func test_stripDirtyHead_dropsMarkerTailAndStrayPunctuation() {
        XCTAssertEqual(stripDirtyHead("19), essa è stata ammessa"), "essa è stata ammessa")
        XCTAssertEqual(stripDirtyHead("(19) il danno"), "il danno")
        XCTAssertEqual(stripDirtyHead("» esclude però"), "esclude però")
        // congiunzioni iniziali conservate (sono il legame logico, § 7.5).
        XCTAssertEqual(stripDirtyHead("ma tuttavia il punto"), "ma tuttavia il punto")
    }

    // MARK: - Regola 6: citazione bibliografica saltata nel para-titolo

    func test_paraTitolo_skipsOpeningCitation() {
        let note = "(178) Così E. MERLIN, L'ordinanza di pagamento, in Riv. dir. proc., 1994, "
            + "p. 1022. Si verificherebbe una sorta di solve et repete in senso ampio."
        let p = noteParaTitolo(note)
        XCTAssertTrue(p.hasPrefix("Si verificherebbe"), "salta la citazione: \(p)")
        XCTAssertFalse(p.contains("MERLIN"), "non riporta il rinvio bibliografico: \(p)")
    }

    func test_paraTitolo_keepsSubstantiveOpening() {
        let note = "(22) A meno che non risulti che l'assistenza del lavoratore non sia stata effettiva."
        let p = noteParaTitolo(note)
        XCTAssertTrue(p.hasPrefix("A meno che"), "apertura sostanziale conservata: \(p)")
    }

    func test_paraTitolo_capsWordCount() {
        let note = "(1) " + Array(repeating: "parola", count: 40).joined(separator: " ")
        XCTAssertLessThanOrEqual(noteParaTitolo(note, maxWords: 18).split(separator: " ").count, 18)
    }

    // MARK: - Bordi

    func test_markerAtStart_returnsEmpty() {
        XCTAssertEqual(memoryRefreshSegment("Qualche testo qui.", markerOffset: 0), "")
        XCTAssertEqual(memoryRefreshSegment("", markerOffset: 5), "")
    }
}
