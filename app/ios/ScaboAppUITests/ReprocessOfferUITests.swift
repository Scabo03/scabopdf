//
//  ReprocessOfferUITests.swift
//  ScaboAppUITests
//
//  L'offerta di rielaborazione e l'avviso delle orfane (giro «ancore», docs/ANCORE_ANNOTAZIONI.md § 5):
//  percorso completo da VoiceOver-utente, con l'audit di accessibilità su ogni schermata nuova.
//  Seme DEBUG `-uiTestSeedReprocess`: un libro sintetico «vecchio» con un segnalibro senza ancora.
//

import XCTest

final class ReprocessOfferUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launchSeeded() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestSeedReprocess"]
        app.launch()
        return app
    }

    private func element(_ app: XCUIApplication, containing text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    /// Apre l'offerta, la rifiuta al secondo gesto, la accetta, verifica l'esito e torna alla lettura precedente.
    func testOffer_isTwoStep_resultDeclaresOrphans_andRevertRestores() throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("performAccessibilityAudit richiede iOS 17+") }
        let app = launchSeeded()

        let row = app.cells["home.offer"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "la Home offre la lettura migliore")
        audit(app, screen: "Home con l'offerta")
        row.tap()

        let book = app.cells.containing(NSPredicate(format: "label CONTAINS %@", "Libro di prova")).firstMatch
        XCTAssertTrue(book.waitForExistence(timeout: 5))
        audit(app, screen: "Elenco della lettura migliore")
        book.tap()

        let accept = app.buttons["offer.accept"]
        XCTAssertTrue(accept.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["offer.what"].exists)
        XCTAssertTrue(app.staticTexts["offer.time"].exists)
        XCTAssertTrue(app.staticTexts["offer.annotations"].exists)
        audit(app, screen: "Offerta di rielaborazione")

        // Primo gesto: «Rielabora…» apre la conferma; «Annulla» (primo e in evidenza) non fa partire nulla.
        accept.tap()
        let cancel = app.buttons["confirm.reprocess.cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        audit(app, screen: "Conferma della rielaborazione")
        cancel.tap()
        XCTAssertTrue(accept.waitForExistence(timeout: 5), "annullare lascia l'offerta aperta, nulla è partito")
        XCTAssertFalse(app.staticTexts["Rielaborazione conclusa"].exists)

        // Secondo gesto, voluto: parte.
        accept.tap()
        XCTAssertTrue(app.buttons["confirm.reprocess.ok"].waitForExistence(timeout: 5))
        app.buttons["confirm.reprocess.ok"].tap()

        let done = app.staticTexts["Rielaborazione conclusa"]
        XCTAssertTrue(done.waitForExistence(timeout: 120), "la rielaborazione si conclude")
        let text = app.staticTexts["result.text"]
        XCTAssertTrue(text.exists)
        XCTAssertTrue(text.label.contains("Da ricollocare: 1"), "il segnalibro senza ancora è dichiarato, non spostato: \(text.label)")
        audit(app, screen: "Esito della rielaborazione")

        // Torna alla lettura precedente: l'offerta ricompare (l'etichetta è tornata quella di prima).
        app.buttons["result.revert"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.cells["home.offer"].waitForExistence(timeout: 10))
    }

    /// Dopo aver tenuto la nuova lettura, il segnalibro orfano è dichiarato «da ricollocare» nella vista
    /// globale dei segnalibri per tag (raggiungibile dalla Home; il pannello del lettore è un contenitore
    /// chiuso che XCUI non apre senza i gesti di VoiceOver: la finestra del lettore ha il suo test unitario).
    func testOrphanBookmark_isDeclaredInTheGlobalBookmarksView() throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("performAccessibilityAudit richiede iOS 17+") }
        let app = launchSeeded()
        XCTAssertTrue(app.cells["home.offer"].waitForExistence(timeout: 10))
        app.cells["home.offer"].tap()
        app.cells.containing(NSPredicate(format: "label CONTAINS %@", "Libro di prova")).firstMatch.tap()
        XCTAssertTrue(app.buttons["offer.accept"].waitForExistence(timeout: 5))
        app.buttons["offer.accept"].tap()
        XCTAssertTrue(app.buttons["confirm.reprocess.ok"].waitForExistence(timeout: 5))
        app.buttons["confirm.reprocess.ok"].tap()
        XCTAssertTrue(app.staticTexts["Rielaborazione conclusa"].waitForExistence(timeout: 120))
        app.buttons["result.keep"].tap()
        // Secondo gesto anche qui: tenere la nuova lettura cancella quella di prima.
        let keep = app.buttons["confirm.keep.ok"]
        XCTAssertTrue(keep.waitForExistence(timeout: 5))
        audit(app, screen: "Conferma: tenere la nuova lettura")
        keep.tap()
        // Aspetta che conferma ed esito si siano chiusi (le animazioni hanno tempi diversi fra 26.5 e 27).
        let gone = NSPredicate(format: "exists == false")
        expectation(for: gone, evaluatedWith: app.staticTexts["Rielaborazione conclusa"])
        waitForExpectations(timeout: 10)
        let back = app.navigationBars["Lettura migliore"].buttons.element(boundBy: 0)
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        back.tap()
        let tags = app.navigationBars.buttons["Tag"]
        XCTAssertTrue(tags.waitForExistence(timeout: 10), "di nuovo in Home")
        XCTAssertFalse(app.cells["home.offer"].exists, "tenuta la nuova lettura, l'offerta non c'è più")

        tags.tap()
        let tag = app.cells.containing(NSPredicate(format: "label CONTAINS %@", "Importante")).firstMatch
        XCTAssertTrue(tag.waitForExistence(timeout: 5))
        tag.tap()
        let orphan = element(app, containing: "da ricollocare")
        XCTAssertTrue(orphan.waitForExistence(timeout: 5), "il segnalibro non ritrovato è dichiarato")
        audit(app, screen: "Segnalibri per tag con un orfano")
    }

    // MARK: - Audit (stesso criterio di AccessibilityAuditUITests)

    @available(iOS 17.0, *)
    private func audit(_ app: XCUIApplication, screen: String) {
        var report: [String] = []
        do {
            try app.performAccessibilityAudit { issue in
                let el = issue.element
                if issue.auditType == .textClipped, el?.elementType == .searchField { return true }
                report.append("• [\(issue.auditType.rawValue)] \(issue.compactDescription) — «\(el?.label ?? "?")» type:\(el.map { "\($0.elementType.rawValue)" } ?? "?")")
                return false
            }
        } catch {
            // L'audit lancia quando un rilievo non è gestito (già nel resoconto); se il resoconto è vuoto, il
            // lancio è un errore dell'audit stesso: non deve passare in silenzio.
            if report.isEmpty { XCTFail("Audit su «\(screen)» non eseguito: \(error)") }
        }
        XCTAssertTrue(report.isEmpty, "Audit accessibilità FALLITO su «\(screen)» (\(report.count)):\n" + report.joined(separator: "\n"))
    }
}
