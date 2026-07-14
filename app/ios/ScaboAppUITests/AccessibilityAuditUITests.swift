//
//  AccessibilityAuditUITests.swift
//  ScaboAppUITests
//
//  La RETE DI VERIFICA dell'accessibilità (giro «aree scoperte»). Esegue
//  `performAccessibilityAudit` (iOS 17+) su ogni schermata raggiungibile senza un
//  documento: controlla contrasto, dimensione dei bersagli, etichette mancanti,
//  Dynamic Type, clipping del testo, tratti. Il test FALLISCE se l'audit trova
//  problemi — è lo strumento che sostituisce il collaudo umano mancante.
//
//  Nota: le schermate che richiedono un documento aperto (reading view, split) sono
//  verificate a livello unit (dimensioni dei pulsanti barra, etichette, registro
//  earcon→alternativa) in `ScaboAppTests`, perché aprire un PDF reale in un UI-test
//  richiederebbe un fixture fuori dal repo.
//

import XCTest

final class AccessibilityAuditUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = true  // vogliamo l'elenco COMPLETO dei problemi, non solo il primo
    }

    /// Audit di ogni schermata raggiungibile dalla navigazione a tab + il chooser.
    func testAccessibilityAudit_reachableScreens() throws {
        guard #available(iOS 17.0, *) else {
            throw XCTSkip("performAccessibilityAudit richiede iOS 17+")
        }
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestFreshStart"]
        app.launch()

        // 1. Schermata di scelta tema alla prima apertura (accessibile PRIMA di ogni config).
        audit(app, screen: "Prima apertura (scelta tema)")

        // Procedi verso l'app scegliendo un tema (o saltando se il chooser non c'è).
        let followSystem = app.staticTexts["Segui il sistema"].firstMatch
        if followSystem.waitForExistence(timeout: 3) {
            followSystem.tap()
        }

        // 2. Home (Recenti / Spazi).
        _ = app.tabBars.firstMatch.waitForExistence(timeout: 3)
        audit(app, screen: "Home")

        // 3. Ricerca.
        tapTab(app, "Ricerca")
        audit(app, screen: "Ricerca")

        // 4. Impostazioni.
        tapTab(app, "Impostazioni")
        audit(app, screen: "Impostazioni")

        // 5. Pannello «Comandi da tastiera» dentro Impostazioni (se presente).
        let keyboardRow = app.cells.staticTexts["Comandi da tastiera"].firstMatch
        if keyboardRow.waitForExistence(timeout: 2) {
            keyboardRow.tap()
            audit(app, screen: "Comandi da tastiera")
        }
    }

    // MARK: - Helper

    @available(iOS 17.0, *)
    private func audit(_ app: XCUIApplication, screen: String) {
        var report: [String] = []
        do {
            try app.performAccessibilityAudit { issue in
                let el = issue.element
                // FALSO POSITIVO documentato: la `UISearchBar` di sistema (dentro `UISearchController`)
                // gestisce da sé il layout del placeholder; il clip del placeholder non è
                // controllabile dall'autore e la barra ha già un `accessibilityLabel` corretto.
                // È l'UNICO caso soppresso, e in modo stretto (solo textClipped su un searchField).
                if issue.auditType == .textClipped, el?.elementType == .searchField {
                    return true  // gestito: non è un difetto d'autore
                }
                let label = el?.label ?? "?"
                let type = el.map { "\($0.elementType.rawValue)" } ?? "?"
                let frame = el.map { "\($0.frame)" } ?? "?"
                report.append("• [\(issue.auditType.rawValue)] \(issue.compactDescription) — «\(label)» type:\(type) frame:\(frame)")
                return false  // non sopprimere: ogni altro problema è un fallimento reale
            }
        } catch {
            // `performAccessibilityAudit` lancia già; l'handler ha raccolto i dettagli.
        }
        XCTAssertTrue(
            report.isEmpty,
            "Audit accessibilità FALLITO su «\(screen)» (\(report.count)):\n" + report.joined(separator: "\n"))
    }

    private func tapTab(_ app: XCUIApplication, _ name: String) {
        let tab = app.tabBars.buttons[name]
        if tab.waitForExistence(timeout: 3) { tab.tap() }
    }
}
