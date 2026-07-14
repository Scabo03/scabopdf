//
//  HeadingFusionTests.swift
//  ScaboCoreTests
//
//  Fusione posizionale dei titoli spezzati su più righe (`consolidateAdjacentHeadings`).
//  Il segnale è POSIZIONE + STILE, non il testo. Regola d'oro: mai fondere due titoli distinti
//  (perderebbe un punto di navigazione) → precisione > recupero, nel dubbio non fondere.
//

import XCTest
@testable import ScaboCore

final class HeadingFusionTests: XCTestCase {

    /// Riga di heading con geometria esplicita (yTop; altezza riga 18; centrata su x0..x1).
    private func hl(_ text: String, size: Double = 13.6, bold: Bool = true, italic: Bool = false,
                    color: String = "#000000", x0: Double = 120, x1: Double = 360,
                    yTop: Double, lineH: Double = 18) -> LineSummary {
        LineSummary(text: text, fontSize: size, bold: bold, italic: italic, color: color,
                    x0: x0, x1: x1, yTop: yTop, yBottom: yTop - lineH,
                    width: x1 - x0, height: lineH, spans: [])
    }
    private func prof(rivista: Bool = false) -> Profile {
        Profile(bodySize: 11, bodyColor: "#000000", isRivistaDpc: rivista)
    }
    private func fuse(_ items: [GenItem], rivista: Bool = false) -> [GenItem] {
        consolidateAdjacentHeadings(items, prof(rivista: rivista))
    }
    private func headingTexts(_ items: [GenItem]) -> [String] {
        items.compactMap { if case let .heading(sm, _) = $0 { return sm.text } else { return nil } }
    }

    // MARK: - predicato geometrico (positivi/negativi)

    func test_shouldFuse_genuineWrap_centered() {
        // due righe di UN titolo centrato, interlinea singola (baseline-delta ≈ una riga)
        let a = hl("LE ORIGINI DEL NOSTRO SISTEMA", yTop: 501)
        let b = hl("DI GIUSTIZIA AMMINISTRATIVA", yTop: 486)   // baseline-delta 15 / lineH 18 = 0.83
        XCTAssertTrue(headingsShouldFuse(a, b))
    }
    func test_shouldNotFuse_line2StartsWithDigit_tocPageNumber() {
        // riga-2 inizia con un numero di pagina (voce d'indice) → mai una continuazione
        let a = hl("Le assemblee separate e le assemblee speciali", yTop: 501)
        let b = hl("463 15. L’organo amministrativo", yTop: 486)
        XCTAssertFalse(headingsShouldFuse(a, b))
    }
    func test_shouldNotFuse_line2StartsWithItemMarker() {
        let a = hl("La prima sezione del capitolo", yTop: 501)
        let b = hl("2. La seconda sezione", yTop: 486)
        XCTAssertFalse(headingsShouldFuse(a, b))
    }
    func test_shouldNotFuse_line1EndsWithTerminalPunct() {
        let a = hl("Un titolo che finisce con un punto.", yTop: 501)
        let b = hl("Un altro titolo distinto", yTop: 486)
        XCTAssertFalse(headingsShouldFuse(a, b))
    }
    func test_shouldNotFuse_verticalGapTooLarge() {
        // salto di paragrafo/titolo (baseline-delta ≈ 2 righe) → non è un andare a capo
        let a = hl("PRIMO TITOLO DISTINTO", yTop: 501)
        let b = hl("SECONDO TITOLO DISTINTO", yTop: 465)   // delta 36 / 18 = 2.0
        XCTAssertFalse(headingsShouldFuse(a, b))
    }
    func test_shouldNotFuse_differentSize() {
        let a = hl("Titolo grande", size: 16, yTop: 501)
        let b = hl("continuazione piccola", size: 11, yTop: 486)
        XCTAssertFalse(headingsShouldFuse(a, b))
    }
    func test_shouldNotFuse_differentStyle() {
        let a = hl("Titolo in tondo", bold: true, yTop: 501)
        let b = hl("continuazione in corsivo", bold: false, italic: true, yTop: 486)
        XCTAssertFalse(headingsShouldFuse(a, b))
    }
    func test_shouldNotFuse_dottedLeader_indexEntry() {
        let a = hl("Voce d’indice con leader . . . . . . . 42", yTop: 501)
        let b = hl("Un’altra voce d’indice", yTop: 486)
        XCTAssertFalse(headingsShouldFuse(a, b))
    }
    func test_shouldNotFuse_combinedTooLong() {
        let long = String(repeating: "parola ", count: 30)
        XCTAssertFalse(headingsShouldFuse(hl(long, yTop: 501), hl(long, yTop: 486)))
    }
    func test_shouldNotFuse_misalignedNotCentered() {
        // stesso corpo/stile/interlinea ma né stesso x0 né stesso centro → non è un titolo unico
        let a = hl("Testo a sinistra", x0: 60, x1: 200, yTop: 501)
        let b = hl("Testo molto spostato a destra", x0: 300, x1: 460, yTop: 486)
        XCTAssertFalse(headingsShouldFuse(a, b))
    }

    // MARK: - consolidamento sul flusso di item

    func test_consolidate_twoLineTitle_fusedWithSpace() {
        let out = fuse([
            .heading(hl("LE ORIGINI DEL NOSTRO SISTEMA", yTop: 501), level: 3),
            .heading(hl("DI GIUSTIZIA AMMINISTRATIVA", yTop: 486), level: 3)])
        XCTAssertEqual(headingTexts(out), ["LE ORIGINI DEL NOSTRO SISTEMA DI GIUSTIZIA AMMINISTRATIVA"])
    }
    func test_consolidate_threeLineTitle_chains_viaReanchor() {
        // titolo a 3 righe: si re-àncora all'ultima riga fisica per il controllo d'interlinea
        let out = fuse([
            .heading(hl("I DELITTI", yTop: 501), level: 1),
            .heading(hl("CONTRO LA SICUREZZA DELLO STATO", yTop: 486), level: 1),
            .heading(hl("E CONTRO L’ORDINE PUBBLICO", yTop: 471), level: 1)])
        XCTAssertEqual(headingTexts(out),
                       ["I DELITTI CONTRO LA SICUREZZA DELLO STATO E CONTRO L’ORDINE PUBBLICO"])
    }
    func test_consolidate_differentLevel_notFused() {
        let out = fuse([
            .heading(hl("Titolo di livello 2", yTop: 501), level: 2),
            .heading(hl("Sottotitolo di livello 3", yTop: 486), level: 3)])
        XCTAssertEqual(headingTexts(out).count, 2)
    }
    func test_consolidate_bodyBetween_notFused() {
        let out = fuse([
            .heading(hl("Un titolo", yTop: 501), level: 2),
            .run(.body, [hl("del corpo in mezzo", yTop: 480)]),
            .heading(hl("Un altro titolo", yTop: 450), level: 2)])
        XCTAssertEqual(headingTexts(out).count, 2)   // il corpo interrompe l'adiacenza
    }
    func test_consolidate_rivistaGatedOff_identity() {
        let items: [GenItem] = [
            .heading(hl("La responsabilidad penal de las personas", yTop: 501), level: 3),
            .heading(hl("del modelo italiano de imputación", yTop: 486), level: 3)]
        XCTAssertEqual(headingTexts(fuse(items, rivista: true)).count, 2)   // Rivista esclusa
        XCTAssertEqual(headingTexts(fuse(items, rivista: false)).count, 1)  // altrove fusa
    }
    func test_consolidate_distinctTitles_notFused_goldenRule() {
        // due titoli DISTINTI a salto di interlinea → mai fusi (regola d'oro: no perdita di nav.)
        let out = fuse([
            .heading(hl("PRIMO CAPITOLO", yTop: 501), level: 2),
            .heading(hl("SECONDO CAPITOLO", yTop: 465), level: 2)])   // gap = 2 righe
        XCTAssertEqual(headingTexts(out).count, 2)
    }
}
