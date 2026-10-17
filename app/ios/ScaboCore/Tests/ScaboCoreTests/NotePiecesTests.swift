//
//  NotePiecesTests.swift
//  ScaboCoreTests
//
//  La regola dei confini dei pezzi delle note lunghe (`notePieces` in `AknSegments.swift`, giro «cura delle note»,
//  2026-10-16): fine frase in una finestra attorno alla soglia, poi le pause, mai un'iniziale o un'abbreviazione separata
//  dalla parola che segue, nessun pezzo minuscolo, ricomposizione esatta. Testi di prova inventati, mai testo di volumi.
//

import XCTest
@testable import ScaboCore

final class NotePiecesTests: XCTestCase {

    /// Una frase di prova di esattamente `n` caratteri: `tag` in testa (maiuscolo), parole di prova, un punto in fondo;
    /// l'ultima parola ha almeno tre lettere (mai un'abbreviazione). Richiede `n ≥ tag.count + 5`.
    private func frase(_ n: Int, _ tag: String = "Alfa") -> String {
        var s = tag
        while s.count + 6 <= n - 5 { s += " prova" }
        s += " " + String(repeating: "z", count: n - 2 - s.count) + "."
        precondition(s.count == n)
        return s
    }

    /// Parole di prova minuscole, senza punteggiatura, di esattamente `n` caratteri (`n ≥ tag.count + 4`).
    private func parole(_ n: Int, _ tag: String = "prova") -> String {
        var s = tag
        while s.count + 6 <= n - 4 { s += " prova" }
        s += " " + String(repeating: "z", count: n - 1 - s.count)
        precondition(s.count == n)
        return s
    }

    // MARK: - Fine frase nella finestra

    func test_pezzoCorto_prendeLaFraseSeguente_entroUnaVoltaEMezzoLaSoglia() {
        let a = frase(40, "Alfa"), b = frase(90, "Beta"), c = frase(80, "Gamma")
        // Prima: 40 | 90 | 80 (accumulo fino a 100). Ora il pezzo di 40 prende la frase seguente: 131 ≤ 150.
        XCTAssertEqual(notePieces([a, b, c].joined(separator: " "), target: 100), [a + " " + b, c])
    }

    func test_pezzoGiaLungoMezzaSoglia_siChiudeAllaFineFraseSottoLaSoglia() {
        let a = frase(60, "Alfa"), b = frase(60, "Beta"), c = frase(30, "Gamma")
        XCTAssertEqual(notePieces([a, b, c].joined(separator: " "), target: 100), [a, b + " " + c])
    }

    // MARK: - Iniziali e abbreviazioni

    func test_sigleDiIniziali_nonChiudonoLaFrase_soloNelleNote() {
        let t = "Lo afferma A.B. Bianchi in un saggio di prova. Poi continua il discorso."
        XCTAssertEqual(noteSentenceRanges(Array(t)).count, 2, "nelle note la sigla resta col cognome")
        XCTAssertEqual(splitIntoSentences(t).count, 3, "lo spezzatore del corpo resta com'è")
    }

    func test_abbreviazioniDelleCitazioni_nonChiudonoLaFrase_soloNelleNote() {
        let t = "Si veda in Riv. Prova, 2020, p. 3. Poi altro testo di prova."
        XCTAssertEqual(noteSentenceRanges(Array(t)).count, 2)
        XCTAssertEqual(splitIntoSentences(t).count, 3, "lo spezzatore del corpo resta com'è")
        XCTAssertTrue(noteTokenIsAbbreviation(ArraySlice(Array("(Riv."))))
        XCTAssertTrue(noteTokenIsAbbreviation(ArraySlice(Array("A.B.C."))))
        XCTAssertTrue(noteTokenIsAbbreviation(ArraySlice(Array("n.)"))))
        XCTAssertFalse(noteTokenIsAbbreviation(ArraySlice(Array("prova."))))
        XCTAssertFalse(noteTokenIsAbbreviation(ArraySlice(Array("2020."))))
    }

    func test_nessunPezzo_finisceConUnaSiglaDiIniziali() {
        // La parte dopo la sigla è più lunga di 40 caratteri: l'unione dei pezzi corti non la salverebbe.
        let t = (1...6).map { "Frase \($0) di prova in cui scrive A.B. Bianchi con altre parole di prova qui e ancora altre." }
            .joined(separator: " ")
        let pieces = notePieces(t, target: 60)
        XCTAssertGreaterThan(pieces.count, 1)
        XCTAssertFalse(pieces.contains { $0.hasSuffix("A.B.") })
        XCTAssertEqual(pieces.joined(separator: " "), t)
    }

    // MARK: - Frasi lunghissime: le pause

    func test_fraseLunghissima_siTagliaDopoIlPuntoEVirgola_primaDellaVirgola() {
        let a = "Alfa " + parole(64) + ";"            // 70 caratteri
        let b = " " + parole(29) + ","                 // fino a 101: la virgola è la più vicina alla soglia
        let c = " " + parole(117) + "."                // 220 in tutto
        let pieces = notePieces(a + b + c, target: 100)
        XCTAssertEqual(pieces.count, 2)
        XCTAssertEqual(pieces[0], a, "il punto e virgola vince sulla virgola più vicina")
        XCTAssertEqual(pieces.joined(separator: " "), a + b + c)
    }

    func test_fraseLunghissima_senzaPuntoEVirgola_siTagliaAllaVirgolaPiuVicina() {
        let a = "Alfa " + parole(54) + ","            // 60
        let b = " " + parole(39) + ","                 // 101
        let c = " " + parole(118) + "."                // 221
        let pieces = notePieces(a + b + c, target: 100)
        XCTAssertEqual(pieces.first, a + b)
        XCTAssertEqual(pieces.joined(separator: " "), a + b + c)
    }

    /// Giro «pulizia e rifinitura finale del capitolo note» (2026-10-17): nelle note-elenco (un elenco di voci senza punti
    /// fermi, ciascuna con la sua etichetta fra parentesi che introduce un elenco) il taglio non cade più dopo i due punti
    /// dell'etichetta, che resta col primo elemento del suo elenco.
    func test_fraseLunghissima_maiTagliataDopoIDuePuntiDiUnEtichettaFraParentesi() {
        let voce = "Legge sulla tutela del raccolto (sui frutteti) (in nota a: artt. 11, 12, 13, 14)"
        let t = Array(repeating: voce, count: 6).joined(separator: " ")   // circa 500 caratteri, nessun punto fermo
        let pieces = notePieces(t, target: 100)
        XCTAssertGreaterThan(pieces.count, 1)
        for p in pieces.dropLast() { XCTAssertFalse(p.hasSuffix("in nota a:"), "etichetta separata dal suo elenco: \(p)") }
        XCTAssertEqual(pieces.joined(separator: " "), t)
    }

    func test_fraseLunghissima_dopoIDuePuntiFuoriDaParentesi_siTagliaAncora() {
        // prova al contrario: i due punti fuori da una parentesi restano un buon punto di taglio
        let a = "Alfa " + parole(64) + ":"            // 70 caratteri
        let b = " " + parole(29) + ","                 // fino a 101
        let c = " " + parole(117) + "."                // 220 in tutto
        XCTAssertEqual(notePieces(a + b + c, target: 100).first, a)
    }

    func test_fraseLunghissima_maiTagliataDopoUnAbbreviazione() {
        let t = "Alfa " + parole(92) + " n. 12 " + parole(150) + "."
        let pieces = notePieces(t, target: 100)
        XCTAssertGreaterThan(pieces.count, 1)
        for p in pieces.dropLast() { XCTAssertFalse(p.hasSuffix(" n."), "abbreviazione separata dalla parola che segue") }
        XCTAssertEqual(pieces.joined(separator: " "), t)
    }

    // MARK: - Pezzi corti, ricomposizione, limiti

    func test_pezzoSottoQuarantaCaratteri_siUnisceAlPrecedente() {
        let a = frase(90, "Alfa"), b = frase(30, "Beta")
        XCTAssertEqual(notePieces(a + " " + b, target: 100), [a + " " + b], "la nota resta intera: nessun pezzo minuscolo")
    }

    func test_ricomposizioneEsatta_eNessunPezzoOltreLaFinestra() {
        var parts: [String] = []
        for k in 0..<40 {
            switch k % 5 {
            case 0: parts.append(frase(35 + k, "Alfa"))
            case 1: parts.append(frase(120 + k, "Beta"))
            case 2: parts.append("Gamma " + parole(90) + "; " + parole(80) + ", " + parole(140 + k) + ".")
            case 3: parts.append(frase(20, "Delta"))
            default: parts.append("Lo scrive A.B. Bianchi in Riv. Prova, p. 3, con " + parole(60) + ".")
            }
        }
        let t = parts.joined(separator: " ")
        for target in [100, 400] {
            let pieces = notePieces(t, target: target)
            XCTAssertEqual(pieces.joined(separator: " "), t, "target \(target)")
            for p in pieces { XCTAssertLessThanOrEqual(p.count, notePieceMaxLength(target: target), "target \(target)") }
            XCTAssertFalse(pieces.contains { $0.first?.isWhitespace == true || $0.last?.isWhitespace == true })
        }
    }

    func test_spaziInterni_restanoQuelliDellaNota() {
        let a = frase(60, "Alfa"), b = "Beta  con  spazi  doppi  di  prova  qui.", c = frase(70, "Gamma")
        let t = a + " " + b + " " + c
        let pieces = notePieces(t, target: 100)
        XCTAssertEqual(pieces.joined(separator: " "), t)
        XCTAssertTrue(pieces.contains { $0.contains("con  spazi") }, "il ripiego a parola di prima comprimeva gli spazi doppi")
    }

    func test_parolaPiuLungaDellaFinestra_nessunCrollo_eTestoIntatto() {
        let t = "Alfa " + String(repeating: "x", count: 300) + " fine della prova."
        let pieces = notePieces(t, target: 100)
        XCTAssertEqual(pieces.joined(separator: " "), t)
    }

    func test_testoSenzaFrasi_restaIntero() {
        XCTAssertEqual(notePieces("   ", target: 100), ["   "])
    }

    // MARK: - Il frazionamento della nota

    func test_frazionamento_ruoliIdIntroEPaginaSuiPezzi() {
        let t = (1...8).map { frase(70 + $0, "Frase\($0)") }.joined(separator: " ")
        let note = ContentSegment(id: "n9", role: "NOTE", text: t, lengthCategory: "LONG", acousticIntro: "Nota.",
                                  memoryRefresh: "richiamo di prova", sourcePage: 7)
        let out = fractionLongNoteSegments([note], target: 200)
        XCTAssertGreaterThan(out.count, 1)
        XCTAssertEqual(out[0].id, "n9#0")
        XCTAssertEqual(out[0].role, "NOTE")
        XCTAssertEqual(out[0].acousticIntro, "Nota.")
        XCTAssertEqual(out[0].lengthCategory, "LONG")
        XCTAssertEqual(out[0].memoryRefresh, "richiamo di prova")
        for (k, s) in out.enumerated().dropFirst() {
            XCTAssertEqual(s.id, "n9#\(k)")
            XCTAssertEqual(s.role, "NOTE_CONTINUATION")
            XCTAssertEqual(s.acousticIntro, "")
            XCTAssertEqual(s.lengthCategory, "")
        }
        XCTAssertTrue(out.allSatisfy { $0.sourcePage == 7 })
        XCTAssertEqual(out.map { $0.text }.joined(separator: " "), t)
    }

    func test_notaAppenaSopraLaSoglia_conUnaCodaMinima_restaIntera() {
        let note = ContentSegment(id: "n1", role: "NOTE", text: frase(390, "Alfa") + " " + frase(25, "Beta"),
                                  lengthCategory: "MEDIUM", acousticIntro: "Nota.", sourcePage: 3)
        let out = fractionLongNoteSegments([note], target: 400)
        XCTAssertEqual(out, [note], "prima: un pezzo di 390 e uno di 25; ora la nota resta una")
    }
}
