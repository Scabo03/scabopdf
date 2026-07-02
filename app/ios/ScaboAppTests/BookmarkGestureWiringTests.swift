//
//  BookmarkGestureWiringTests.swift
//  ScaboAppTests
//
//  Wiring dell'accesso NON-VoiceOver alla creazione segnalibro (§ 5.7): il long press sulla reading
//  view deve CONVERGERE sullo stesso percorso dell'azione personalizzata VoiceOver
//  (`presentBookmarkEditor` → stesso coordinatore → stesso editor → stesso addBookmark/editBookmark),
//  e il suo recognizer deve essere configurato in modo da non ostacolare mai lo swipe orizzontale.
//
//  ── Cosa è verificabile QUI (e cosa NO) ─────────────────────────────────────────────────────────
//
//  Il Simulator NON consegna tocchi reali ai gesture recognizer né riproduce VoiceOver: il gesto
//  sotto le dita (0.5s di pressione, il fallimento del long press durante uno swipe, la coesistenza
//  col paging) resta collaudo DEVICE. Qui si verifica ciò che è deterministico a livello di API: la
//  LOGICA di dispatch (crea vs modifica) su cui il gesto converge, e la CONFIGURAZIONE swipe-safe del
//  recognizer (durata minima, nessun ritardo su tap/swipe, un solo recognizer).
//

import UIKit
import XCTest

@testable import ScaboApp
import ScaboCore

/// Spia del coordinatore: registra quale metodo del percorso condiviso viene invocato.
private final class SpyBookmarkCoordinator: ReadingBookmarkCoordinator {
    var existing: Bookmark?
    var added: (segmentId: String, orderIndex: Int, text: String)?
    var edited: Bookmark?
    var removed: Bookmark?

    func existingBookmark(forSegmentId id: String) -> Bookmark? { existing }
    func addBookmark(segmentId: String, orderIndex: Int, segmentText: String) {
        added = (segmentId, orderIndex, segmentText)
    }
    func editBookmark(_ bookmark: Bookmark) { edited = bookmark }
    func removeBookmark(_ bookmark: Bookmark) { removed = bookmark }
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

    // MARK: - Configurazione swipe-safe del recognizer

    func test_longPressRecognizer_isSingle_andSwipeSafeConfigured() {
        let view = makeRenderedView()
        let recognizer = view.longPressGestureForTesting
        XCTAssertNotNil(recognizer, "esiste un unico recognizer di long press sul container")
        XCTAssertEqual(recognizer?.minimumPressDuration, 0.5, "0.5s: uno swipe non resta mai fermo così a lungo")
        XCTAssertEqual(recognizer?.delaysTouchesBegan, false, "nessun ritardo sull'inizio del tocco (tap/swipe)")
        XCTAssertEqual(recognizer?.delaysTouchesEnded, false, "nessun ritardo sul rilascio del tocco")
    }

    // MARK: - Convergenza: stessa dispatch dell'azione VoiceOver

    func test_presentBookmarkEditor_dispatchesAdd_forUnmarkedElement() {
        let view = makeRenderedView()
        let spy = SpyBookmarkCoordinator()
        spy.existing = nil  // elemento non ancora marcato
        view.bookmarkCoordinator = spy

        view.presentBookmarkEditor(for: view.segmentLabels[1])

        XCTAssertEqual(spy.added?.segmentId, "n1")
        XCTAssertEqual(spy.added?.orderIndex, 1, "usa l'indice di lettura cablato dell'elemento")
        XCTAssertEqual(spy.added?.text, "Secondo elemento.")
        XCTAssertNil(spy.edited, "elemento non marcato → creazione, non modifica")
    }

    func test_presentBookmarkEditor_dispatchesEdit_forMarkedElement() {
        let view = makeRenderedView()
        let spy = SpyBookmarkCoordinator()
        let existing = Bookmark(id: "b1", anchorSegmentId: "n1", orderIndexHint: 1,
                                preview: "Secondo elemento.", createdAt: Date())
        spy.existing = existing
        view.bookmarkCoordinator = spy

        view.presentBookmarkEditor(for: view.segmentLabels[1])

        XCTAssertEqual(spy.edited, existing, "elemento già marcato → modifica dello stesso segnalibro")
        XCTAssertNil(spy.added, "nessuna creazione doppia")
        XCTAssertNil(spy.removed, "il long press non rimuove mai (crea/modifica soltanto)")
    }

    func test_presentBookmarkEditor_isNoOp_withoutCoordinator() {
        let view = makeRenderedView()
        // Nessun coordinatore (es. documento non reale nei test): non deve fare nulla né crashare.
        view.presentBookmarkEditor(for: view.segmentLabels[0])
        XCTAssertNil(view.bookmarkCoordinator)
    }
}
