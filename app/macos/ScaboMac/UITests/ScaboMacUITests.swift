//
//  ScaboMacUITests.swift
//  ScaboMacUITests — test d'interfaccia (XCUITest) dell'app Mac (giro «costruzione della linea Mac», 2026-10-16).
//
//  COME SI LANCIANO. Su macOS XCUITest richiede la «modalità automazione», che si abilita UNA volta con la password
//  dell'amministratore (senza, il runner si blocca e lascia a schermo un dialogo di sistema — accaduto il 2026-10-05):
//
//      automationmodetool enable-automationmode-without-authentication
//      cd app/macos/ScaboMac && scripts/build_app.sh && \
//        xcodebuild test -project UITests/ScaboMacUITests.xcodeproj -scheme ScaboMacUITests -destination 'platform=macOS'
//
//  I test aprono l'app GIÀ ASSEMBLATA da `scripts/build_app.sh` (variabile SCABOMAC_APP per un'altra copia), firmata e con
//  la sandbox: è l'app vera, non una variante di prova. Non dipendono da ScaboMacKit (identificativi d'accessibilità
//  letterali) e non avviano MAI uno scaricamento vero: arrivano alla domanda di conferma e rispondono «No, lascia».
//
//  Che cosa provano: audit d'accessibilità sulla finestra dell'officina e sul pannello (gli audit validi su macOS:
//  contrasto, rilevamento degli elementi, area, descrizione sufficiente, gerarchia, azioni — niente Dynamic Type né testo
//  tagliato, che su macOS non esistono); il percorso SOLO TASTIERA del pannello: Cmd+Shift+M apre il pannello, Tab arriva
//  a «Scarica» di GLM-OCR, Spazio chiede conferma con dimensione e fonte, Tab arriva a «No, lascia», Spazio chiude la
//  domanda e nulla parte; la voce di Heron dice «già incluso» e non ha azioni.
//

import XCTest

final class ScaboMacUITests: XCTestCase {

    private func app() -> XCUIApplication {
        let path = ProcessInfo.processInfo.environment["SCABOMAC_APP"]
            ?? URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("build/ScaboMac.app").path
        return XCUIApplication(url: URL(fileURLWithPath: path))
    }

    override func setUp() {
        continueAfterFailure = false
    }

    /// Fuoco della tastiera: su macOS `hasFocus` non esiste (è di tvOS); l'attributo è `hasKeyboardFocus`.
    private func haFuoco(_ e: XCUIElement) -> Bool { (e.value(forKey: "hasKeyboardFocus") as? Bool) ?? false }

    func test_auditAccessibilita_officinaEPannello() throws {
        let app = app()
        app.launch()
        defer { app.terminate() }
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))
        try app.performAccessibilityAudit()
        app.typeKey("m", modifierFlags: [.command, .shift])
        XCTAssertTrue(app.descendants(matching: .any)["voce.glm-ocr"].waitForExistence(timeout: 5), "il pannello deve essere aperto")
        try app.performAccessibilityAudit()
    }

    func test_pannello_soloTastiera_confermaENo_nienteParte() {
        let app = app()
        app.launch()
        defer { app.terminate() }
        app.typeKey("m", modifierFlags: [.command, .shift])
        let scarica = app.buttons["azione.scarica.glm-ocr"]
        XCTAssertTrue(scarica.waitForExistence(timeout: 5), "GLM-OCR non scaricato: c'è «Scarica»")
        for _ in 0..<60 where !haFuoco(scarica) { app.typeKey(.tab, modifierFlags: []) }
        XCTAssertTrue(haFuoco(scarica), "«Scarica» si raggiunge con Tab")
        app.typeKey(" ", modifierFlags: [])
        let domanda = app.staticTexts["conferma.scarica.domanda.glm-ocr"]
        XCTAssertTrue(domanda.waitForExistence(timeout: 3), "prima la domanda, con dimensione e fonte")
        XCTAssertTrue((domanda.value as? String ?? domanda.label).contains("gigabyte"))
        let no = app.buttons["conferma.scarica.no.glm-ocr"]
        for _ in 0..<10 where !haFuoco(no) { app.typeKey(.tab, modifierFlags: []) }
        XCTAssertTrue(haFuoco(no), "«No, lascia» si raggiunge con Tab")
        app.typeKey(" ", modifierFlags: [])
        XCTAssertFalse(domanda.waitForExistence(timeout: 1), "la domanda si chiude")
        XCTAssertFalse(app.buttons["azione.annulla.glm-ocr"].exists, "nessuno scaricamento è partito")
        XCTAssertTrue(app.buttons["azione.scarica.glm-ocr"].exists)
    }

    func test_heron_giaIncluso_senzaAzioni() {
        let app = app()
        app.launch()
        defer { app.terminate() }
        app.typeKey("m", modifierFlags: [.command, .shift])
        let heron = app.descendants(matching: .any)["voce.docling-layout-heron"]
        XCTAssertTrue(heron.waitForExistence(timeout: 5))
        XCTAssertTrue(heron.label.contains("già incluso"), heron.label)
        XCTAssertEqual(heron.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'azione.'")).count, 0)
    }

    func test_officina_pulsantePrincipale_daTastiera() {
        let app = app()
        app.launch()
        defer { app.terminate() }
        let prepara = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Prepara la lettura'")).firstMatch
        XCTAssertTrue(prepara.waitForExistence(timeout: 10))
        for _ in 0..<30 where !haFuoco(prepara) { app.typeKey(.tab, modifierFlags: []) }
        XCTAssertTrue(haFuoco(prepara), "«Prepara la lettura di un PDF…» si raggiunge con Tab")
    }
}
