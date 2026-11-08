//
//  ScaboMacUITests.swift
//  ScaboMacUITests — test d'interfaccia (XCUITest) dell'officina dentro ScaboPDF per Mac (giro «costruzione della linea
//  Mac», 2026-10-16; dal giro «app unica per Mac, tappa A», 2026-11-08, l'officina e il pannello stanno nella finestra «Modelli
//  e officina» dell'app unica, che ⌘⇧M apre come prima apriva il pannello; i test della Home e della lettura sono in
//  ScaboPDFUITests.swift).
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
                .appendingPathComponent("build/ScaboPDF.app").path
        return XCUIApplication(url: URL(fileURLWithPath: path))
    }

    override func setUp() {
        continueAfterFailure = false
    }

    /// Lancia l'app sulla libreria di prova (vuota) e apre la finestra «Modelli e officina» con ⌘⇧M, come prima il pannello.
    private func lanciaConModelli() -> XCUIApplication {
        let app = app()
        app.launchArguments = ["--libreria-di-prova"]
        app.launch()
        XCTAssertTrue(app.windows["home.finestra"].waitForExistence(timeout: 10))
        app.typeKey("m", modifierFlags: [.command, .shift])
        XCTAssertTrue(app.windows["modelli.finestra"].waitForExistence(timeout: 10), "la finestra «Modelli e officina»")
        return app
    }

    /// L'audit d'accessibilità del sistema, con ogni rilievo scritto sul registro (elemento e motivo) prima di fallire.
    private func audit(_ app: XCUIApplication, _ nome: String) throws {
        try app.performAccessibilityAudit { issue in
            let e = issue.element
            // Un rilievo di contrasto su un elemento che esce dalla cornice della sua finestra o dalla parte visibile della sua area
            // di scorrimento non è misurabile: l'audit fotografa un rettangolo quasi vuoto (misurato l'8 novembre 2026 sul
            // pannello dei modelli). Si scrive nel registro e non fa rosso; ogni altro rilievo sì.
            if issue.auditType == .contrast, let el = e {
                let f = el.frame
                let finestre = app.windows.allElementsBoundByIndex.map(\.frame)
                let scorrimenti = app.scrollViews.allElementsBoundByIndex.map(\.frame)
                let dentro = finestre.contains { $0.insetBy(dx: -1, dy: -1).contains(f) }
                    && !scorrimenti.contains { $0.intersects(f) && !$0.insetBy(dx: -1, dy: -1).contains(f) }
                    && el.isHittable   // fuori dalla parte visibile della sua area di scorrimento: non raggiungibile sullo schermo
                if !dentro {
                    print("RISULTATO audit_\(nome)_tagliato {\"descrizione\": \"\(issue.compactDescription)\", \"cornice\": \"\(f)\"}")
                    return true
                }
            }
            print("RISULTATO audit_\(nome) {\"tipo\": \"\(issue.auditType.rawValue)\", \"descrizione\": \"\(issue.compactDescription)\", \"elemento\": \"\(e.map { "\($0.elementType.rawValue) id=\($0.identifier) label=\($0.label.prefix(40)) cornice=\($0.frame)" } ?? "-")\"}")
            return false
        }
    }

    /// Diagnostica a richiesta (TEST_RUNNER_SCABOMAC_ALBERI=1): chi ha il fuoco della tastiera a ogni Tab nella finestra dei modelli.
    func test_diagnostica_giroDiTab() throws {
        guard ProcessInfo.processInfo.environment["SCABOMAC_ALBERI"] == "1" else { throw XCTSkip("a richiesta") }
        let app = lanciaConModelli()
        defer { app.terminate() }
        for k in 0..<14 {
            let f = app.descendants(matching: .any).matching(NSPredicate(format: "hasKeyboardFocus == true AND elementType != %d", XCUIElement.ElementType.window.rawValue)).firstMatch
            print("RISULTATO tab_\(k) \(f.exists ? "\(f.elementType.rawValue) id=\(f.identifier) label=\(f.label.prefix(30))" : "nessuno")")
            app.typeKey(.tab, modifierFlags: [])
        }
    }

    /// Il percorso solo tastiera con Tab vale solo con la «navigazione da tastiera» di sistema accesa (Impostazioni di Sistema,
    /// Tastiera): spenta, Tab non porta ai pulsanti in nessuna app del Mac. Misurato l'8 novembre 2026: su questo Mac è
    /// spenta, e i due test falliscono allo stesso modo anche sull'officina di prima (codice `358617b`): si saltano col motivo.
    /// Code non cambia mai le impostazioni di sistema del maintainer.
    private func richiedeNavigazioneDaTastiera() throws {
        if UserDefaults.standard.integer(forKey: "AppleKeyboardUIMode") & 2 == 0 {
            throw XCTSkip("la navigazione da tastiera di sistema è spenta: Tab non porta ai pulsanti (vale con l'impostazione accesa)")
        }
    }

    /// Fuoco della tastiera: su macOS `hasFocus` non esiste (è di tvOS); l'attributo è `hasKeyboardFocus`.
    private func haFuoco(_ e: XCUIElement) -> Bool { (e.value(forKey: "hasKeyboardFocus") as? Bool) ?? false }

    func test_auditAccessibilita_officinaEPannello() throws {
        let app = lanciaConModelli()
        defer { app.terminate() }
        XCTAssertTrue(app.descendants(matching: .any)["voce.glm-ocr"].waitForExistence(timeout: 5), "il pannello deve essere aperto")
        try audit(app, "pannello")
        app.windows["modelli.finestra"].radioButtons["Officina"].click()
        XCTAssertTrue(app.buttons["preparaLettura"].waitForExistence(timeout: 5), "la scheda dell'officina")
        try audit(app, "officina")
    }

    func test_pannello_soloTastiera_confermaENo_nienteParte() throws {
        try richiedeNavigazioneDaTastiera()
        let app = lanciaConModelli()
        defer { app.terminate() }
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
        let app = lanciaConModelli()
        defer { app.terminate() }
        let heron = app.descendants(matching: .any)["voce.docling-layout-heron"]
        XCTAssertTrue(heron.waitForExistence(timeout: 5))
        XCTAssertTrue(heron.label.contains("già incluso"), heron.label)
        XCTAssertEqual(heron.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'azione.'")).count, 0)
    }

    func test_officina_pulsantePrincipale_daTastiera() throws {
        try richiedeNavigazioneDaTastiera()
        let app = lanciaConModelli()
        defer { app.terminate() }
        app.windows["modelli.finestra"].radioButtons["Officina"].click()
        let prepara = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Prepara la lettura'")).firstMatch
        XCTAssertTrue(prepara.waitForExistence(timeout: 10))
        for _ in 0..<30 where !haFuoco(prepara) { app.typeKey(.tab, modifierFlags: []) }
        XCTAssertTrue(haFuoco(prepara), "«Prepara la lettura di un PDF…» si raggiunge con Tab")
    }
}
