//
//  SplitScreenWiringTests.swift
//  ScaboAppTests
//
//  Smoke test STRUTTURALE dello split screen (§ 11): che il view controller si costruisca, impagini
//  le due metà + barra + linea senza crash, esponga i SEI container, che lo scrub cicli fra loro, e
//  che i comandi di regime (§ 11.4) e di spostamento linea (§ 11.7) aggiornino lo stato.
//
//  Onestà: il Simulator NON certifica il comportamento VoiceOver reale (sigillo dei container, fuoco
//  unico, scrub sotto le dita), i gesti, né la memoria dei due volumi vivi sul device — tutto ciò
//  resta collaudo device. Qui si verifica solo la struttura e il cablaggio dei comandi.
//

import UIKit
import XCTest

@testable import ScaboApp
import ScaboCore

final class SplitScreenWiringTests: XCTestCase {

    private func makeHalf() -> ContinuousReadingViewController {
        let content = PaginatedContent(pages: [ContentPage(pageNumber: 1, segments: [
            ContentSegment(id: "s0", role: "HEADING_1", text: "Capo I", lengthCategory: "", acousticIntro: ""),
            ContentSegment(id: "s1", role: "BODY", text: "Primo comma del testo.", lengthCategory: "", acousticIntro: ""),
            ContentSegment(id: "s2", role: "BODY", text: "Secondo comma del testo.", lengthCategory: "", acousticIntro: ""),
        ])], totalSegments: 3)
        // documentId vuoto → nessuna interazione con lo store (metà "di prova").
        return ContinuousReadingViewController(content: content, embedded: true)
    }

    private func makeSplit() -> SplitScreenViewController {
        let vc = SplitScreenViewController.makeForTesting(
            left: makeHalf(), right: makeHalf(),
            split: SplitState(leftDocumentId: "a", rightDocumentId: "b"))
        vc.view.frame = CGRect(x: 0, y: 0, width: 1194, height: 834)
        vc.loadViewIfNeeded()
        vc.view.layoutIfNeeded()
        return vc
    }

    override func tearDown() {
        // Lo split VC scrive lo stato nello store al viewDidLoad; ripulisci per non lasciare residui.
        LibraryService.shared.store.setSplitState(nil)
        super.tearDown()
    }

    func test_splitScreen_composesSixContainers_withoutCrash() {
        let vc = makeSplit()
        XCTAssertEqual(vc.orderedContainerCountForTesting, 6, "testo A, barra A, split, barra B, testo B, linea")
        XCTAssertEqual(vc.activeContainerIndexForTesting, 0, "all'ingresso comanda la metà sinistra (testo A)")
    }

    func test_scrub_cyclesThroughAllContainers_andWraps() {
        let vc = makeSplit()
        var seen: [Int] = [vc.activeContainerIndexForTesting]
        for _ in 0..<6 { vc.advanceActiveForTesting(); seen.append(vc.activeContainerIndexForTesting) }
        XCTAssertEqual(seen, [0, 1, 2, 3, 4, 5, 0], "lo scrub cicla i sei container e torna all'inizio")
    }

    func test_selectRegime_updatesState() {
        let vc = makeSplit()
        vc.selectRegimeForTesting(.absolute)
        XCTAssertEqual(vc.splitStateForTesting.regime, .absolute)
        vc.selectRegimeForTesting(.partial)
        XCTAssertEqual(vc.splitStateForTesting.regime, .partial)
    }

    func test_moveDivider_updatesFraction() {
        let vc = makeSplit()
        let before = vc.splitStateForTesting.dividerFraction
        vc.moveDividerForTesting(towards: .right)
        XCTAssertEqual(vc.splitStateForTesting.dividerFraction, before + SplitState.fractionStep, accuracy: 0.0001)
    }
}
