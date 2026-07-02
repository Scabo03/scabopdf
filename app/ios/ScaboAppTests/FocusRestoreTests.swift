//
//  FocusRestoreTests.swift
//  ScaboAppTests
//
//  Regressione dei due bug di navigazione/focus (build 25/26), che condividevano UNA radice: la
//  reading view raggiungeva una posizione non-iniziale SOLO via `UIAccessibility.post(.screenChanged)`
//  — che a VoiceOver spento non fa nulla (niente scroll → inizio file) ed è scavalcato dal reset
//  automatico di VoiceOver dopo un modale/interruzione di sistema. Il fix instrada tutti i percorsi
//  sul meccanismo SANO (scroll visivo indipendente da VoiceOver + fuoco), come lo scrub toolbar→testo.
//
//  Questi test pinnano il comportamento a VoiceOver SPENTO (deterministico nel Simulator): che il
//  salto/ripristino porti alla PAGINA del bersaglio, non a 0. Il comportamento del FUOCO VoiceOver e
//  la corsa reale col reset restano collaudo device (il Simulator non riproduce VoiceOver).
//

import UIKit
import XCTest

@testable import ScaboApp
import ScaboCore

private final class SilentSignals: SignalPlaying {
    func play(_ signal: AudioSignal) {}
    func playLooping(_ signal: AudioSignal) {}
    func stop(_ signal: AudioSignal) {}
}

final class FocusRestoreTests: XCTestCase {

    private func manySegments(_ n: Int) -> [ContentSegment] {
        (0..<n).map {
            ContentSegment(id: "n\($0)", role: "BODY",
                           text: "Paragrafo \($0) con testo sufficiente a occupare più righe nella "
                               + "colonna stretta della pagina logica di prova.",
                           lengthCategory: "", acousticIntro: "")
        }
    }

    private func multiPageView() -> ContinuousReadingView {
        let view = ContinuousReadingView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        view.render(manySegments(40))
        view.layoutIfNeeded()
        return view
    }

    // MARK: - Bug 2: il salto al segnalibro SCROLLA al bersaglio (VoiceOver spento)

    func test_goToElement_scrollsToTargetPage_notToStart_withoutVoiceOver() {
        let view = multiPageView()
        XCTAssertGreaterThan(view.visualPageCount, 1, "il banco deve avere più pagine visive")
        XCTAssertEqual(view.currentVisualPage, 0, "si parte da pagina 0")

        let target = view.elementCount - 1  // ultimo elemento: su una pagina diversa da 0
        let expectedPage = view.visualPageIndex(ofElementAt: target)
        view.goToElement(atIndex: target, focus: true)  // VoiceOver spento nel Simulator → solo scroll

        XCTAssertEqual(view.currentVisualPage, expectedPage, "atterra sulla pagina del bersaglio")
        XCTAssertGreaterThan(view.currentVisualPage, 0, "NON è tornato a inizio file (bug 2)")
        XCTAssertEqual(view.currentReadingElementIndex, target, "posizione ricordata = bersaglio")
    }

    // MARK: - Ripristino della posizione iniziale alla riapertura (VoiceOver spento)

    private func makeReader(initial: Int) -> (ContinuousReadingViewController, UIWindow) {
        let content = PaginatedContent(pages: [ContentPage(pageNumber: 1, segments: manySegments(40))],
                                       totalSegments: 40)
        let vc = ContinuousReadingViewController(
            content: content, documentId: "", initialReadingPosition: initial, signalPlayer: SilentSignals())
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 300))
        window.rootViewController = vc
        window.makeKeyAndVisible()
        vc.loadViewIfNeeded()
        vc.view.layoutIfNeeded()
        vc.viewDidAppear(false)  // scatena il ripristino della posizione iniziale
        return (vc, window)
    }

    func test_reopen_restoresSavedPosition_notStart_withoutVoiceOver() {
        let (vc, _) = makeReader(initial: 30)
        let rv = vc.textContainerForTesting
        let expected = rv.visualPageIndex(ofElementAt: 30)
        XCTAssertEqual(rv.currentVisualPage, expected, "riapertura: scroll alla posizione salvata")
        XCTAssertGreaterThan(rv.currentVisualPage, 0, "NON a inizio file")
    }

    // MARK: - Bug 1: dopo interruzione simulata, la posizione resta salvata (non torna a 0)

    func test_interruption_restoresSnapshot_notStart() {
        let (vc, _) = makeReader(initial: 30)
        let rv = vc.textContainerForTesting
        let expected = rv.visualPageIndex(ofElementAt: 30)
        XCTAssertEqual(rv.currentVisualPage, expected)

        // Sospensione: si fotografa la posizione corrente (30).
        NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
        spinMainLoop()

        // Interruzione: VoiceOver rispedisce a inizio file → simuliamo lo scroll a pagina 0.
        rv.revealElement(atIndex: 0)
        XCTAssertEqual(rv.currentVisualPage, 0, "reset simulato a inizio file")

        // Ripresa: il ripristino deve riportare alla posizione fotografata, NON a 0.
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        spinMainLoop()

        XCTAssertEqual(rv.currentVisualPage, expected, "ripristinato alla posizione salvata, non a 0 (bug 1)")
        XCTAssertGreaterThan(rv.currentVisualPage, 0)
    }

    private func spinMainLoop() {
        // Gli osservatori sono su `queue: .main` → il blocco gira al prossimo giro di run loop.
        RunLoop.main.run(until: Date().addingTimeInterval(0.15))
    }
}
