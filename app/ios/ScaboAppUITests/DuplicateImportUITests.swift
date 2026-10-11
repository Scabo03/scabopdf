//
//  DuplicateImportUITests.swift
//  ScaboAppUITests
//
//  «Libro già presente» (giro «identità», 2026-10-11, DuplicateImport.swift): il percorso completo da
//  VoiceOver-utente, con l'audit di accessibilità sulla schermata. Seme DEBUG `-uiTestSeedDuplicateImport`:
//  un libro sintetico già in libreria (impronta, cache, un segnalibro) e una copia identica del suo PDF
//  che la Home importa al primo apparire, senza il picker di sistema.
//
//  Che cosa si verifica: la schermata ha il titolo, la spiegazione in prosa e tre scelte nell'ordine
//  «Apri il libro che hai già» (predefinita), «Importa come copia a parte», «Annulla»; «Annulla» torna
//  alla Home senza libri nuovi; «Apri» apre il libro esistente dalla cache SENZA elaborazione e senza
//  libri nuovi; «Importa come copia» passa dall'elaborazione e lascia un secondo libro. Il numero dei
//  libri si legge dai Recenti dopo un riavvio senza seme (la libreria del simulatore resta).
//

import XCTest

final class DuplicateImportUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launchSeeded() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestSeedDuplicateImport"]
        app.launch()
        return app
    }

    /// Riavvio SENZA seme: la libreria resta com'è; i Recenti dicono quanti «Libro di prova» ci sono.
    private func relaunchAndCountProvaBooks(_ app: XCUIApplication) -> Int {
        app.terminate()
        let again = XCUIApplication()
        again.launch()
        // Sotto carico (suite in parallelo) il riavvio può superare i 10 s: si aspetta la Home fino a 30 s.
        XCTAssertTrue(again.tabBars.firstMatch.waitForExistence(timeout: 30), "la Home riappare al riavvio")
        _ = again.navigationBars["ScaboPDF"].waitForExistence(timeout: 5)
        return again.cells.containing(NSPredicate(format: "label CONTAINS %@", "Libro di prova")).count
    }

    private func waitForDuplicateScreen(_ app: XCUIApplication) {
        let open = app.buttons["duplicate.open"]
        XCTAssertTrue(open.waitForExistence(timeout: 15), "la schermata «Libro già presente» compare")
        XCTAssertTrue(app.navigationBars["Libro già presente"].exists)
        XCTAssertTrue(app.staticTexts["Questo libro è già nella tua libreria"].exists)
        let text = app.staticTexts["duplicate.text"]
        XCTAssertTrue(text.exists)
        XCTAssertTrue(text.label.contains("Libro di prova"), text.label)
        XCTAssertTrue(text.label.contains("un segnalibro"), text.label)
        XCTAssertTrue(app.buttons["duplicate.copy"].exists)
        XCTAssertTrue(app.buttons["duplicate.cancel"].exists)
        // Ordine di lettura: apri, poi copia, poi annulla (la predefinita per prima).
        let y = [open, app.buttons["duplicate.copy"], app.buttons["duplicate.cancel"]].map { $0.frame.minY }
        XCTAssertTrue(y[0] < y[1] && y[1] < y[2], "ordine delle scelte: \(y)")
    }

    func testDuplicateScreen_isAccessible_andCancelLeavesTheLibraryAsItWas() throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("performAccessibilityAudit richiede iOS 17+") }
        let app = launchSeeded()
        waitForDuplicateScreen(app)
        audit(app, screen: "Libro già presente")
        app.buttons["duplicate.cancel"].tap()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5), "si torna alla Home")
        XCTAssertFalse(app.buttons["duplicate.open"].exists)
        XCTAssertFalse(app.staticTexts["Elaborazione del documento"].exists, "annullare non elabora nulla")
        XCTAssertEqual(relaunchAndCountProvaBooks(app), 1, "nessun libro nuovo")
    }

    func testOpenExisting_opensTheBookYouHave_withoutProcessing_andWithoutANewBook() throws {
        let app = launchSeeded()
        waitForDuplicateScreen(app)
        app.buttons["duplicate.open"].tap()
        // Il libro esistente ha la cache: niente finestra di elaborazione, la schermata se ne va.
        let gone = NSPredicate(format: "exists == false")
        expectation(for: gone, evaluatedWith: app.buttons["duplicate.open"])
        waitForExpectations(timeout: 10)
        XCTAssertFalse(app.staticTexts["Elaborazione del documento"].waitForExistence(timeout: 3), "aprire il libro che c'è già non rielabora")
        XCTAssertEqual(relaunchAndCountProvaBooks(app), 1, "nessun libro nuovo: si è aperto quello di prima")
    }

    func testImportAsCopy_processesTheFile_andLeavesASecondBook() throws {
        let app = launchSeeded()
        waitForDuplicateScreen(app)
        app.buttons["duplicate.copy"].tap()
        let gone = NSPredicate(format: "exists == false")
        expectation(for: gone, evaluatedWith: app.buttons["duplicate.copy"])
        waitForExpectations(timeout: 10)
        // L'elaborazione del PDF sintetico è breve: si aspetta che la finestra di elaborazione, se vista, sia sparita.
        let processing = app.staticTexts["Elaborazione del documento"]
        if processing.waitForExistence(timeout: 5) {
            expectation(for: gone, evaluatedWith: processing)
            waitForExpectations(timeout: 90)
        }
        sleep(5)
        XCTAssertEqual(relaunchAndCountProvaBooks(app), 2, "la copia a parte è un secondo libro")
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
            if report.isEmpty { XCTFail("Audit su «\(screen)» non eseguito: \(error)") }
        }
        XCTAssertTrue(report.isEmpty, "Audit accessibilità FALLITO su «\(screen)» (\(report.count)):\n" + report.joined(separator: "\n"))
    }
}
