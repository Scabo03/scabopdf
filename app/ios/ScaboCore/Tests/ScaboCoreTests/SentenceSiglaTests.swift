//
//  SentenceSiglaTests.swift
//  ScaboCoreTests
//
//  Le sigle col punto nel riconoscimento delle frasi (giro «prova 4, segnalibri e sigle», 2026-11-11; Granularity.swift,
//  testata «Le sigle col punto»; LAYER2 § 7.6). Tre forme: la parentesi aperta con una minuscola dopo un terminatore non apre una
//  frase (salvo la voce d'elenco e la parentesi seguita, chiusa, da una maiuscola); le virgolette con una minuscola dopo il punto di
//  una sigla, di un numero o dei puntini; le iniziali seguite da un cognome in maiuscolo e da una virgola; le abbreviazioni delle
//  citazioni di `CITATION_ABBREVIATIONS` (salvo la voce numerata fra parentesi). Ogni prova ha anche il suo rovescio: dove un
//  attacco di frase vero resta un confine. Testi SINTETICI, inventati.
//

import XCTest
@testable import ScaboCore

final class SentenceSiglaTests: XCTestCase {

    private func frasi(_ t: String) -> Int { splitIntoSentences(t).count }

    // MARK: - Forma 1: parentesi e virgolette con la minuscola

    func test_parentesiConMinuscola_dopoIlPunto_continuaLaFrase() {
        XCTAssertEqual(frasi("La gru vola sopra lo stagno grande. (vedi la tavola sette), poi torna al nido. Il pescatore rema."), 2)
        XCTAssertEqual(frasi("La gru vola sopra lo stagno grande. (con la tavola sette). Il pescatore rema."), 2)
        // Nelle note la stessa regola (lo spezzatore delle note usa lo stesso inizio di frase).
        let nota = Array("Il vento gira a nord. (cfr. la tavola sette). Il mare si calma.")
        XCTAssertEqual(noteSentenceRanges(nota).count, 2)
    }

    func test_voceDElencoFraParentesi_restaUnInizio() {
        XCTAssertEqual(frasi("Le prove sono due. (a) La prima riguarda il ponte. (b) La seconda la torre."), 3)
        XCTAssertEqual(frasi("Le prove sono due. (iv) La quarta riguarda il ponte."), 2)
        XCTAssertEqual(frasi("Si veda la tavola. (ro7) Una voce che il lettore ottico ha guastato."), 2)
    }

    func test_parentesiSeguitaDaUnaMaiuscola_restaUnInizio() {
        // Un'etichetta prima della frase che segue, o la fonte di quella prima: ambiguo, resta com'era.
        XCTAssertEqual(frasi("Il vento cambia direzione. (parte seconda del quaderno) Il mare si calma piano."), 2)
        XCTAssertEqual(frasi("Il vento cambia direzione. (diario del capitano, pagina nove) Nessuno risponde."), 2)
    }

    func test_virgoletteConMinuscola_dopoUnaParolaPiena_restanoUnInizio() {
        // Un termine citato che fa da soggetto alla frase nuova.
        XCTAssertEqual(frasi("Il marinaio tace a lungo. «vento contrario» è la sola cosa che dice."), 2)
        XCTAssertEqual(frasi("Il marinaio chiede se torneranno? «forse» risponde il vecchio."), 2)
    }

    func test_virgoletteConMinuscola_dopoUnaSiglaUnNumeroODeiPuntini_continuano() {
        XCTAssertEqual(frasi("Lo stabilisce il Q.Z. «senza alcuna riserva» davanti a tutti."), 1)
        XCTAssertEqual(frasi("Le voci sono queste: 1. «il primo mulino», 2. «il secondo mulino»."), 1)
        XCTAssertEqual(frasi("Il racconto si interrompe ... «e poi tornarono a casa» scrive il cronista."), 1)
    }

    // MARK: - Forma 2: iniziali e cognome in maiuscolo

    func test_inizialiConCognomeInMaiuscoloEVirgola_continuano() {
        XCTAssertEqual(frasi("Sul punto si veda Q.Z. ZORBELLINI, Il mulino del borgo, ristampa anastatica."), 1)
        XCTAssertEqual(frasi("Sul punto si veda Q.Z. DE ZORBELLINI, Il mulino del borgo."), 1)
    }

    func test_inizialiSenzaVirgola_oCognomeMinuscolo_restanoUnConfine() {
        // Una firma seguita da un titolo in maiuscolo, o un nome seguito da una frase: niente forma 2.
        XCTAssertEqual(frasi("Firmato dal curatore Q.Z. INTRODUZIONE GENERALE DEL QUADERNO dei mulini."), 2)
        XCTAssertEqual(frasi("Lo racconta il curatore Q.Z. Poi il racconto prosegue con la piena."), 2)
    }

    // MARK: - Forma 3: le abbreviazioni delle citazioni

    func test_abbreviazioniDelleCitazioni_nonChiudonoLaFrase() {
        XCTAssertEqual(frasi("Lo prevede il d. lgs. 999 del duemilasettantasette, in vigore da ieri."), 1)
        XCTAssertEqual(frasi("Si veda la disp. trans. 77 del codice dei mulini."), 1)
        XCTAssertEqual(frasi("Lo scrive Zorbellini et al. (duemila) nel quaderno."), 1)
        XCTAssertEqual(frasi("È la regola del d.p.c.m. 12 del mese scorso."), 1)
    }

    func test_abbreviazioneDelleCitazioni_seguitaDaUnaVoceNumerata_restaUnConfine() {
        // La nota seguente di un codice annotato: «(2) V. …» comincia una voce nuova.
        XCTAssertEqual(frasi("Lo vieta il vecchio regolamento del c. nav. (2) Ogni barca paga il pedaggio al molo grande."), 2)
        // Un richiamo seguito dal punto continua la frase: il confine viene dopo il richiamo.
        let richiamo = "Lo vieta il vecchio regolamento del c. nav. (2). Ogni barca paga il pedaggio al molo grande."
        XCTAssertEqual(frasi(richiamo), 2)
        XCTAssertTrue(splitIntoSentences(richiamo)[0].hasSuffix("(2)."))
    }

    func test_sentenceBoundaryOffsets_seguonoLeStesseForme() {
        let t = "Lo prevede il d. lgs. 999 del duemila. (vedi la tavola), poi altro. Il pescatore rema."
        XCTAssertEqual(sentenceBoundaryOffsets(t).count, 1, "un confine solo, prima di «Il pescatore»")
    }

    func test_pezziDiNota_nonSiTaglianoDopoUnAbbreviazioneDelleCitazioni() {
        // Una frase lunghissima di una nota, senza punti fermi, con molte citazioni «d.lg.»: nessun pezzo comincia col numero.
        let voce = "d.lg. 999 del primo giorno, che regola i mulini del borgo e i ponti di pietra sul fiume grande"
        let nota = (1...20).map { "\($0)) \(voce)" }.joined(separator: "; ") + "."
        let pezzi = notePieces(nota, target: 400)
        XCTAssertGreaterThan(pezzi.count, 1)
        for p in pezzi.dropFirst() {
            XCTAssertFalse(p.trimmingCharacters(in: .whitespaces).first?.isNumber == true
                           && nota.contains("d.lg. " + p.trimmingCharacters(in: .whitespaces).prefix(3)),
                           "un pezzo non comincia col numero staccato dalla sua sigla")
        }
        XCTAssertEqual(pezzi.joined(separator: " ").filter { !$0.isWhitespace }, nota.filter { !$0.isWhitespace })
    }

    // MARK: - Testo intatto

    func test_leFrasiRicompongonoIlTesto() {
        let t = "Lo dice il Q.Z. «senza riserve». (vedi sopra), e poi Q.Z. ZORBELLINI, Il mulino. Fine del d. lgs. 7 e del resto."
        XCTAssertEqual(splitIntoSentences(t).joined(separator: " "), t)
    }
}
