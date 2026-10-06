//
//  ScaboMacUITests.swift
//  ScaboMacUITests — test d'interfaccia (XCUITest) dello scheletro.
//
//  STATO: scritti, NON eseguibili in questo giro. Due prerequisiti mancano, entrambi fuori dal controllo di uno
//  script: (1) un bersaglio di test UI dentro un progetto Xcode (il pacchetto SwiftPM non può ospitarlo);
//  (2) la «modalità automazione» di macOS, che va abilitata a mano con autenticazione:
//        automationmodetool enable-automationmode-without-authentication
//      (chiede la password dell'amministratore; senza, XCUITest si blocca «before establishing connection» e lascia
//      a schermo un dialogo di sistema — accaduto il 2026-10-05 con i test Catalyst). Vedi README.md.
//
//  Cosa fanno quando potranno girare: audit di accessibilità su finestra principale e pannello (gli audit validi su
//  macOS: contrasto, rilevamento elementi, area di tocco, descrizione sufficiente, parent/child, azioni — niente
//  Dynamic Type né testo tagliato, che su macOS non esistono) e un percorso SOLO TASTIERA: Cmd+Shift+M apre il
//  pannello, Tab raggiunge il primo pulsante «Scarica», Spazio lo attiva, Tab raggiunge «Annulla lo scaricamento».
//

import XCTest

final class ScaboMacUITests: XCTestCase {

    func test_auditAccessibilita_finestraEPannello() throws {
        let app = XCUIApplication()
        app.launch()
        try app.performAccessibilityAudit()
        app.typeKey("m", modifierFlags: [.command, .shift])
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 3))
        try app.performAccessibilityAudit()
    }

    func test_percorsoSoloTastiera() {
        let app = XCUIApplication()
        app.launch()
        app.typeKey("m", modifierFlags: [.command, .shift])
        let scarica = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'azione.scarica.'")).firstMatch
        XCTAssertTrue(scarica.waitForExistence(timeout: 3))
        // Tab finché il focus di tastiera arriva al primo «Scarica», poi Spazio.
        for _ in 0..<40 where !scarica.hasFocus { app.typeKey(.tab, modifierFlags: []) }
        XCTAssertTrue(scarica.hasFocus)
        app.typeKey(" ", modifierFlags: [])
        let annulla = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'azione.annulla.'")).firstMatch
        XCTAssertTrue(annulla.waitForExistence(timeout: 3))
    }
}
