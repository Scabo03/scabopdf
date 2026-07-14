//
//  EstrattoTitlesTests.swift
//  ScaboCoreTests
//
//  Foglia titoli-Estratto (taglia+struttura, gated isEstrattoChrome). Capitolo: run
//  MAIUSCOLO a ~corpo×1.04 → heading capitolo. Paragrafo: riga ~corpo×0.96 (banda stretta)
//  con prefisso numero+Maiuscola/"Segue" → heading paragrafo. Gated: no-op altrove.
//

import XCTest
@testable import ScaboCore

final class EstrattoTitlesTests: XCTestCase {

    private let body = 12.0
    private func ln(_ text: String, _ size: Double, x0: Double = 50) -> LineSummary {
        LineSummary(text: text, fontSize: size, bold: false, italic: false, color: "#000000",
                    x0: x0, x1: x0 + 200, yTop: 600, yBottom: 588, width: 200, height: 12, spans: [])
    }
    private func prof(_ estratto: Bool) -> Profile {
        Profile(bodySize: body, bodyColor: "#000000", isEstrattoChrome: estratto)
    }

    // MARK: - predicati

    func test_chapterTitleLine() {
        XCTAssertTrue(estrattoIsChapterTitleLine(ln("LA NOZIONE DI PROVVEDIMENTO", 12.48), body))   // caps + 1.04
        XCTAssertFalse(estrattoIsChapterTitleLine(ln("La nozione di provvedimento", 12.48), body))  // non maiuscolo
        XCTAssertFalse(estrattoIsChapterTitleLine(ln("LA NOZIONE DI PROVVEDIMENTO", 12.0), body))   // taglia corpo
    }
    func test_paraSizeLine() {
        XCTAssertTrue(estrattoIsParaSizeLine(ln("x", 11.52), body))
        XCTAssertFalse(estrattoIsParaSizeLine(ln("x", 11.75), body))  // corpo-con-richiamo, fuori banda stretta
        XCTAssertFalse(estrattoIsParaSizeLine(ln("x", 12.0), body))   // corpo
    }
    func test_paraTitleStarts() {
        XCTAssertTrue(estrattoParaTitleStarts("1 Premessa critica"))
        XCTAssertTrue(estrattoParaTitleStarts("10 Segue: la non del tutto sclerotizzata"))
        XCTAssertFalse(estrattoParaTitleStarts("113, comma 1, della Cost. 23"))  // 3 cifre = citazione
        XCTAssertFalse(estrattoParaTitleStarts("1 gennaio 2020, n. 5"))          // minuscola = data
        XCTAssertFalse(estrattoParaTitleStarts("Premessa critica"))             // niente numero
    }
    func test_lineEndsWithCallMarker() {
        XCTAssertTrue(lineEndsWithCallMarker("le contraddizioni del medesimo 21"))
        XCTAssertFalse(lineEndsWithCallMarker("Premessa critica"))
    }

    // MARK: - gating

    func test_gatedOff_isNoOp() {
        let items: [GenItem] = [.run(.body, [ln("LA NOZIONE DI PROVVEDIMENTO", 12.48),
                                             ln("1 Premessa critica", 11.52)])]
        let out = recognizeEstrattoTitles(items, prof(false))   // non-Estratto → identità
        guard case .run(.body, let lines) = out[0] else { return XCTFail("atteso run invariato") }
        XCTAssertEqual(out.count, 1); XCTAssertEqual(lines.count, 2)
    }

    // MARK: - riconoscimento (gated on)

    func test_chapterTitle_fusedWithCapitolo_singleHeading() {
        // FUSIONE: "CAPITOLO N" + titolo di capitolo → UN solo HEADING_2 (non due tronconi in
        // navigazione). Il testo unisce marcatore + titolo; rete A: nessuna lettera persa.
        let items: [GenItem] = [
            .run(.note, [ln("CAPITOLO I", 9.65)]),                 // marcatore CAPITOLO N
            .run(.body, [ln("LA NOZIONE DI PROVVEDIMENTO E LA SUA PERDURANTE", 12.48),
                         ln("ATTUALITÀ NELL’ODIERNA REALTÀ GIURIDICA E FATTUALE", 12.48)])]
        let out = recognizeEstrattoTitles(items, prof(true))
        XCTAssertEqual(out.count, 1)               // UN heading fuso
        guard case .heading(let sm, let lvl) = out[0] else { return XCTFail("atteso heading capitolo") }
        XCTAssertEqual(lvl, 2)
        XCTAssertTrue(sm.text.contains("CAPITOLO I"), "marcatore fuso nel titolo")
        XCTAssertTrue(sm.text.contains("LA NOZIONE") && sm.text.contains("ATTUALITÀ"), "titolo a due righe unito")
    }

    func test_chapterMarker_withoutFollowingTitle_emittedAlone() {
        // "CAPITOLO N" seguito da corpo NON-titolo (nessuna promozione) → il marcatore esce
        // invariato (nessuna fusione forzata, nessun corpo perso).
        let items: [GenItem] = [
            .run(.note, [ln("CAPITOLO I", 9.65)]),
            .run(.body, [ln("Testo di corpo normale che non è un titolo di capitolo.", 12.0)])]
        let out = recognizeEstrattoTitles(items, prof(true))
        XCTAssertEqual(out.count, 2)               // CAPITOLO + corpo, distinti
        guard case .run(.note, let cl) = out[0] else { return XCTFail("marcatore CAPITOLO invariato") }
        XCTAssertEqual(cl.first?.text, "CAPITOLO I")
        guard case .run(.body, _) = out[1] else { return XCTFail("corpo invariato") }
    }

    func test_chapterTitle_notPromoted_withoutPrecedingCapitolo() {
        // Mezzotitolo/occhiello (es. titolo del libro): all-caps a taglia-capitolo ma NON dopo
        // "CAPITOLO N" → resta corpo (niente promosso per sbaglio).
        let items: [GenItem] = [.run(.body, [ln("IL PROVVEDIMENTO AMMINISTRATIVO", 12.48)])]
        let out = recognizeEstrattoTitles(items, prof(true))
        XCTAssertEqual(out.count, 1)
        guard case .run(.body, _) = out[0] else { return XCTFail("senza CAPITOLO deve restare corpo") }
    }

    func test_paragraphTitle_split_fromBody() {
        let items: [GenItem] = [.run(.body, [
            ln("1 Premessa critica", 11.52),
            ln("Attualmente a livello dottrinale è in atto un profondo ripensamento.", 12.0),
            ln("Nel corso della trattazione si tornerà più volte sul punto.", 12.0)])]
        let out = recognizeEstrattoTitles(items, prof(true))
        XCTAssertEqual(out.count, 2)
        guard case .heading(let sm, let lvl) = out[0] else { return XCTFail("atteso heading paragrafo") }
        XCTAssertEqual(lvl, 3); XCTAssertEqual(sm.text, "1 Premessa critica")
        guard case .run(.body, let bl) = out[1] else { return XCTFail("atteso corpo") }
        XCTAssertEqual(bl.count, 2)
    }

    func test_paragraphTitle_multiLineTitle_merged_stopsAtBody() {
        let items: [GenItem] = [.run(.body, [
            ln("2 Caratteri essenziali del provvedimento amministrativo: a)", 11.52),
            ln("finalizzazione al raggiungimento di interessi pubblici con-", 11.52),
            ln("creti; b) unilateralità; c) inoppugnabilità", 11.52),
            ln("il motivo, intesi come elementi costitutivi dell’atto stesso 31", 11.75)])]  // corpo-con-richiamo
        let out = recognizeEstrattoTitles(items, prof(true))
        XCTAssertEqual(out.count, 2)
        guard case .heading(let sm, _) = out[0] else { return XCTFail("atteso heading") }
        XCTAssertTrue(sm.text.contains("Caratteri") && sm.text.contains("inoppugnabilità"), "titolo multi-riga unito")
        guard case .run(.body, let bl) = out[1] else { return XCTFail("atteso corpo") }
        XCTAssertEqual(bl.count, 1, "la riga-corpo (11.75, fuori banda) NON entra nel titolo")
    }

    func test_bodyWithMarker_atParaSize_notPromoted_ifNoNumberPrefix() {
        // riga corpo-con-richiamo a 11.52 ma SENZA prefisso-numero → resta corpo.
        let items: [GenItem] = [.run(.body, [ln("le contraddizioni del medesimo 21", 11.52)])]
        let out = recognizeEstrattoTitles(items, prof(true))
        XCTAssertEqual(out.count, 1)
        guard case .run(.body, _) = out[0] else { return XCTFail("deve restare corpo") }
    }
}
