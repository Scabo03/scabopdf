//
//  BookmarkGestureWiringTests.swift
//  ScaboAppTests
//
//  Wiring dell'accesso NON-VoiceOver agli strumenti sull'elemento (segnalibri § 5 + sottolineature
//  § 6): il long press sulla reading view apre un MENÙ d'azione, instradato al coordinatore. Verifica
//  che l'instradamento passi i dati giusti e che il recognizer resti configurato «swipe-safe» (la
//  config del gesto NON deve cambiare aggiungendo le sottolineature).
//
//  ── Cosa è verificabile QUI (e cosa NO) ─────────────────────────────────────────────────────────
//
//  Il Simulator non consegna tocchi reali né riproduce VoiceOver: il gesto sotto le dita resta
//  collaudo device. Qui si verifica l'instradamento (view → coordinatore) e la CONFIGURAZIONE del
//  recognizer.
//

import UIKit
import XCTest

@testable import ScaboApp
import ScaboCore

/// Spia del coordinatore: registra l'invocazione del menù (e le azioni-segnalibro, ancora usate
/// dalle azioni VoiceOver).
private final class SpyElementCoordinator: ReadingElementCoordinator {
    var existing: Bookmark?
    var menuPresented: (segmentId: String, orderIndex: Int, text: String)?

    func existingBookmark(forSegmentId id: String) -> Bookmark? { existing }
    func addBookmark(segmentId: String, orderIndex: Int, segmentText: String) {}
    func editBookmark(_ bookmark: Bookmark) {}
    func removeBookmark(_ bookmark: Bookmark) {}
    func presentElementMenu(segmentId: String, orderIndex: Int, segmentText: String, sourcePoint: CGPoint) {
        menuPresented = (segmentId, orderIndex, segmentText)
    }
}

final class BookmarkGestureWiringTests: XCTestCase {

    private func makeRenderedView() -> ContinuousReadingView {
        let view = ContinuousReadingView(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        view.render([
            ContentSegment(id: "n0", role: "BODY", text: "Primo elemento.", lengthCategory: "", acousticIntro: ""),
            ContentSegment(id: "n1", role: "BODY", text: "Secondo elemento.", lengthCategory: "", acousticIntro: ""),
        ])
        view.layoutIfNeeded()
        return view
    }

    // MARK: - Configurazione swipe-safe del recognizer (invariata dall'aggiunta delle sottolineature)

    func test_longPressRecognizer_isSingle_andSwipeSafeConfigured() {
        let view = makeRenderedView()
        let recognizer = view.longPressGestureForTesting
        XCTAssertNotNil(recognizer, "esiste un unico recognizer di long press sul container")
        XCTAssertEqual(recognizer?.minimumPressDuration, 0.5, "0.5s: uno swipe non resta mai fermo così a lungo")
        XCTAssertEqual(recognizer?.delaysTouchesBegan, false, "nessun ritardo sull'inizio del tocco (tap/swipe)")
        XCTAssertEqual(recognizer?.delaysTouchesEnded, false, "nessun ritardo sul rilascio del tocco")
    }

    // MARK: - Instradamento del long press al menù d'azione

    func test_openElementMenu_routesToCoordinator_withElementData() {
        let view = makeRenderedView()
        let spy = SpyElementCoordinator()
        view.elementCoordinator = spy

        view.openElementMenu(for: view.segmentLabels[1], sourcePoint: .zero)

        XCTAssertEqual(spy.menuPresented?.segmentId, "n1")
        XCTAssertEqual(spy.menuPresented?.orderIndex, 1, "usa l'indice di lettura cablato dell'elemento")
        XCTAssertEqual(spy.menuPresented?.text, "Secondo elemento.")
    }

    func test_openElementMenu_isNoOp_withoutCoordinator() {
        let view = makeRenderedView()
        view.openElementMenu(for: view.segmentLabels[0], sourcePoint: .zero)
        XCTAssertNil(view.elementCoordinator)
    }

    // MARK: - Le azioni-segnalibro VoiceOver restano disponibili (non toccate dalle sottolineature)

    func test_bookmarkVoiceOverActions_addWhenUnmarked_editWhenMarked() {
        let view = makeRenderedView()
        let spy = SpyElementCoordinator()
        view.elementCoordinator = spy

        spy.existing = nil
        let addActions = view.bookmarkActions(for: view.segmentLabels[0])
        XCTAssertEqual(addActions?.map { $0.name }, ["Aggiungi segnalibro"])

        spy.existing = Bookmark(id: "b", anchorSegmentId: "n0", orderIndexHint: 0, preview: "x", createdAt: Date())
        let editActions = view.bookmarkActions(for: view.segmentLabels[0])
        XCTAssertEqual(editActions?.map { $0.name }, ["Modifica segnalibro", "Rimuovi segnalibro"])
    }
}
