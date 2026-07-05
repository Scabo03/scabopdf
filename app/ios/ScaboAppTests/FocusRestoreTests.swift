//
//  FocusRestoreTests.swift
//  ScaboAppTests
//
//  Regressione dei due bug di navigazione/focus (build 25/26), che condividevano UNA radice: la
//  reading view raggiungeva una posizione non-iniziale SOLO via `UIAccessibility.post(.screenChanged)`
//  — che a VoiceOver spento non fa nulla ed è scavalcato dal reset automatico di VoiceOver. Il fix
//  instrada tutti i percorsi sul meccanismo SANO (scroll visivo indipendente da VoiceOver + fuoco).
//
//  MODELLO VERTICALE NATIVO (Fase 1 finestra scorrevole): non esistono più "pagine di visualizzazione"
//  orizzontali. La verifica "il ripristino ha scrollato al bersaglio, non a 0" usa due grandezze:
//  `topVisibleElementIndexForTesting` (proxy dello SCROLL: 0 = inizio, N = scrollato) e
//  `currentReadingElementIndex` (la posizione di lettura TRACCIATA). Il comportamento del FUOCO
//  VoiceOver resta collaudo device (il Simulator non riproduce VoiceOver).
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
                               + "colonna stretta della pagina di prova.",
                           lengthCategory: "", acousticIntro: "")
        }
    }

    /// Una view resa in una FINESTRA (necessaria perché la collection materializzi celle, quindi
    /// perché `topVisibleElementIndexForTesting` sia significativo) con contenuto multi-schermata.
    private func multiPageView() -> (ContinuousReadingView, UIWindow) {
        let view = ContinuousReadingView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        window.addSubview(view)
        window.makeKeyAndVisible()
        view.render(manySegments(40))
        view.layoutIfNeeded()
        return (view, window)
    }

    // MARK: - Bug 2: il salto al segnalibro SCROLLA al bersaglio (VoiceOver spento)

    func test_goToElement_scrollsToTargetPage_notToStart_withoutVoiceOver() {
        let (view, _) = multiPageView()
        XCTAssertTrue(view.contentSpansMultiplePages, "il banco deve estendersi oltre una schermata")
        XCTAssertEqual(view.topVisibleElementIndexForTesting, 0, "si parte dall'inizio")

        let target = view.elementCount - 1  // ultimo elemento: lontano dall'inizio
        view.goToElement(atIndex: target, focus: true)  // VoiceOver spento nel Simulator → solo scroll
        view.layoutIfNeeded()

        XCTAssertGreaterThan(view.topVisibleElementIndexForTesting ?? 0, 0, "NON è tornato a inizio file (bug 2)")
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
        rv.layoutIfNeeded()
        XCTAssertEqual(rv.currentReadingElementIndex, 30, "riapertura: posizione tracciata = salvata")
        XCTAssertGreaterThan(rv.topVisibleElementIndexForTesting ?? 0, 0, "scroll alla posizione, NON a inizio file")
    }

    // MARK: - Bug 1: dopo interruzione simulata, la posizione resta salvata (non torna a 0)

    func test_interruption_restoresSnapshot_notStart() {
        let (vc, _) = makeReader(initial: 30)
        let rv = vc.textContainerForTesting
        rv.layoutIfNeeded()
        XCTAssertEqual(rv.currentReadingElementIndex, 30)

        // Sospensione: si fotografa la posizione corrente (30).
        NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
        spinMainLoop()

        // Interruzione: VoiceOver rispedisce a inizio file → simuliamo lo scroll a inizio.
        rv.revealElement(atIndex: 0)
        rv.layoutIfNeeded()
        XCTAssertEqual(rv.topVisibleElementIndexForTesting, 0, "reset simulato a inizio file")

        // Ripresa: il ripristino deve riportare alla posizione fotografata, NON a 0.
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        spinMainLoop()
        rv.layoutIfNeeded()

        XCTAssertEqual(rv.currentReadingElementIndex, 30, "ripristinato alla posizione salvata, non a 0 (bug 1)")
        XCTAssertGreaterThan(rv.topVisibleElementIndexForTesting ?? 0, 0)
    }

    // MARK: - Bug aperto: spegnere/riaccendere VoiceOver a metà lettura non torna a inizio file

    func test_voiceOverReactivation_protectsPosition_notPersistZero_andRestoresScroll() {
        var persisted: [Int] = []
        let content = PaginatedContent(pages: [ContentPage(pageNumber: 1, segments: manySegments(40))],
                                       totalSegments: 40)
        let vc = ContinuousReadingViewController(
            content: content, documentId: "", initialReadingPosition: 30,
            onPositionChanged: { persisted.append($0) }, signalPlayer: SilentSignals())
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 300))
        window.rootViewController = vc
        window.makeKeyAndVisible()
        vc.loadViewIfNeeded()
        vc.view.layoutIfNeeded()
        vc.viewDidAppear(false)

        let rv = vc.textContainerForTesting
        rv.layoutIfNeeded()
        XCTAssertEqual(rv.currentReadingElementIndex, 30, "si legge a metà file")
        persisted.removeAll()

        // Riaccensione di VoiceOver: si apre la protezione sulla posizione reale (~30).
        vc.beginVoiceOverProtectionForTesting()
        XCTAssertTrue(vc.isProtectingReadingPositionForTesting)

        // VoiceOver rispedisce il fuoco a inizio file: emette onReadingPositionChanged(0).
        rv.cellDidBecomeFocused(index: 0, segment: rv.currentSegments[0])

        XCTAssertFalse(persisted.contains(0), "lo 0 spurio del reset NON viene mai persistito")
        XCTAssertEqual(rv.currentReadingElementIndex, 30, "posizione reale protetta, non inizio file")
        rv.layoutIfNeeded()
        XCTAssertGreaterThan(rv.topVisibleElementIndexForTesting ?? 0, 0, "scroll ri-portato alla posizione, non a 0")
    }

    // MARK: - Ordine del DEVICE: il reset azzera lo scroll PRIMA della notifica → l'ancora regge

    func test_deviceOrder_resetBeforeNotification_stickyAnchorSurvives_restoresToN() {
        let content = PaginatedContent(pages: [ContentPage(pageNumber: 1, segments: manySegments(40))],
                                       totalSegments: 40)
        let vc = ContinuousReadingViewController(
            content: content, documentId: "", initialReadingPosition: 30, signalPlayer: SilentSignals())
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 300))
        window.rootViewController = vc
        window.makeKeyAndVisible()
        vc.loadViewIfNeeded()
        vc.view.layoutIfNeeded()
        vc.viewDidAppear(false)
        let rv = vc.textContainerForTesting
        rv.layoutIfNeeded()
        XCTAssertEqual(rv.currentReadingElementIndex, 30)

        // (1) IL RESET del device, PRIMA della notifica: VoiceOver porta scroll E fuoco a inizio file.
        rv.revealElement(atIndex: 0)                                 // scroll programmatico a inizio
        rv.cellDidBecomeFocused(index: 0, segment: rv.currentSegments[0])  // fuoco a 0 (non protetto ancora)
        rv.layoutIfNeeded()

        // Una lettura "dal vivo" ora darebbe 0 — MA l'ancora reale ha retto a 30 (è la differenza).
        XCTAssertEqual(rv.topVisibleElementIndexForTesting, 0, "lo scroll è a inizio file (reset simulato)")
        XCTAssertEqual(rv.currentReadingElementIndex, 0, "il fuoco è a inizio file")
        XCTAssertEqual(vc.stickyReadingPositionForTesting, 30,
                       "l'ancora reale NON è stata azzerata dal reset (indici 0 e scroll programmatico ignorati)")

        // (2) Ora arriva la notifica di riaccensione: si protegge/ripristina la posizione ANCORA (30).
        vc.beginVoiceOverProtectionForTesting()
        XCTAssertTrue(vc.isProtectingReadingPositionForTesting, "target=sticky>0 → protezione attiva")
        rv.layoutIfNeeded()

        XCTAssertEqual(rv.currentReadingElementIndex, 30, "ripristinato alla posizione reale, non a 0")
        XCTAssertGreaterThan(rv.topVisibleElementIndexForTesting ?? 0, 0)
    }

    private func spinMainLoop() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.15))
    }
}
