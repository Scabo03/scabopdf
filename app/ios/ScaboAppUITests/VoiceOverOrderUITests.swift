//
//  VoiceOverOrderUITests.swift
//  ScaboAppUITests
//
//  L'ordine di lettura misurato con VOICEOVER VERO (giro «accessibilità e completamento», 2026-10-18). Da iOS 27 i test
//  d'interfaccia possono accendere VoiceOver e farlo avanzare come lo swipe a destra, leggendo che cosa pronuncia
//  (`XCUIDevice.voiceOverService`). Il test accende VoiceOver, va al primo elemento della schermata e avanza fino in fondo:
//  la sequenza pronunciata deve cominciare col titolo, poi le tre schede, poi i comandi, poi il contenuto, e nessuna voce
//  deve tornare due volte. Su iOS 26.5 il servizio non c'è: lì vale l'albero d'accessibilità (`ReadingOrderUITests`).
//

import XCTest

final class VoiceOverOrderUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = true
    }

    func testVoiceOverSpeaksTitleThenTabsThenCommandsThenContent_home() throws {
        guard #available(iOS 27.0, *) else { throw XCTSkip("il servizio VoiceOver dei test c'è da iOS 27") }
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestSeedHomeOrder"]
        app.launch()
        XCTAssertTrue(app.waitForScreen("ScaboPDF", timeout: 30), "la Home compare")
        let spoken = try speakScreen("Home")
        assertOrder(spoken, screen: "Home", title: "ScaboPDF", selected: "Home",
                    commands: ["Tag", "Importa un documento"],
                    content: ["Libro di prova tre", "Workspaces", "Nuovo workspace", "Workspace di prova B"])
    }

    func testVoiceOverSpeaksTitleThenTabsThenCommandsThenContent_otherScreens() throws {
        guard #available(iOS 27.0, *) else { throw XCTSkip("il servizio VoiceOver dei test c'è da iOS 27") }
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestSeedHomeOrder"]
        app.launch()
        XCTAssertTrue(app.waitForScreen("ScaboPDF", timeout: 30), "la Home compare")
        XCTAssertTrue(app.tapTab("Ricerca"))
        XCTAssertTrue(app.waitForScreen("Ricerca"))
        assertOrder(try speakScreen("Ricerca"), screen: "Ricerca", title: "Ricerca", selected: "Ricerca", commands: [],
                    content: ["Cerca nei documenti", "Libro di prova uno"])
        XCTAssertTrue(app.tapTab("Impostazioni"))
        XCTAssertTrue(app.waitForScreen("Impostazioni"))
        let settings = try speakScreen("Impostazioni")
        assertOrder(settings, screen: "Impostazioni", title: "Impostazioni", selected: "Impostazioni",
                    commands: [], content: ["Aspetto della lettura"])
        assertSettingsRoles(settings)
        XCTAssertTrue(app.tapTab("Home"))
        XCTAssertTrue(app.waitForScreen("ScaboPDF"))
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Workspace di prova A")).firstMatch.tap()
        XCTAssertTrue(app.waitForScreen("Workspace di prova A"))
        assertOrder(try speakScreen("Workspace"), screen: "Workspace", title: "Workspace di prova A", selected: "Home",
                    commands: ["ScaboPDF", "Opzioni del contenitore"], content: ["Cartella di prova"])
    }

    /// La lingua dell'interfaccia (WCAG 3.1.1): VoiceOver dice i tratti («Pulsante», «Intestazione») nella lingua
    /// dell'elemento, quindi la lingua dichiarata si sente. Significativo su un simulatore in un'altra lingua
    /// (laboratorio: un iPad in inglese); su uno in italiano passa comunque. «Workspaces» resta inglese, dichiarato.
    func testInterfaceIsSpokenInItalian_alsoOnADeviceInAnotherLanguage() throws {
        guard #available(iOS 27.0, *) else { throw XCTSkip("il servizio VoiceOver dei test c'è da iOS 27") }
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestSeedHomeOrder"]
        app.launch()
        XCTAssertTrue(app.waitForScreen("ScaboPDF", timeout: 30), "la Home compare")
        let spoken = try speakScreen("Lingua")
        let all = spoken.joined(separator: " | ")
        XCTAssertTrue(spoken.contains { $0.hasPrefix("ScaboPDF") && $0.contains("Intestazione") }, "titolo in italiano — \(all)")
        XCTAssertTrue(spoken.contains { $0.hasPrefix("Tag") && $0.contains("Pulsante") }, "comandi in italiano — \(all)")
        XCTAssertTrue(spoken.contains { $0.hasPrefix("Recenti") && $0.contains("Intestazione") }, "contenuto in italiano — \(all)")
        XCTAssertTrue(spoken.contains { $0.hasPrefix("Workspaces") && $0.contains("Heading") }, "«Workspaces» in inglese — \(all)")
        for u in spoken where !u.hasPrefix("Workspaces") {
            XCTAssertFalse(u.contains(" Button") || u.contains(" Heading"), "nessun tratto in inglese fuori da «Workspaces»: «\(u)»")
        }
    }

    /// Le righe delle Impostazioni hanno il loro ruolo anche dopo lo scorrimento (le righe si riusano): «Comandi da tastiera»
    /// e «Apri le impostazioni di iOS» sono pulsanti, «Interruttore» si sente solo sulle quattro righe con l'interruttore, e
    /// nessuna riga porta il suggerimento di un'altra (revisione indipendente del giro: prima VoiceOver diceva «Comandi da
    /// tastiera, interruttore non attivo» e «Fine — 400 caratteri … Apre Impostazioni iOS»).
    private func assertSettingsRoles(_ spoken: [String], file: StaticString = #filePath, line: UInt = #line) {
        let switches = ["Guida di lettura", "Annuncia le note a voce", "Riquadro visivo per le note",
                        "Mostra numero pagine file originale"]
        for row in ["Comandi da tastiera", "Apri le impostazioni di iOS"] {
            let said = spoken.filter { $0.hasPrefix(row) }
            XCTAssertFalse(said.isEmpty, "«\(row)» pronunciato", file: file, line: line)
            for u in said {
                XCTAssertTrue(u.contains("Pulsante"), "«\(row)» è un pulsante: «\(u)»", file: file, line: line)
                XCTAssertFalse(u.contains("Interruttore"), "«\(row)» non è un interruttore: «\(u)»", file: file, line: line)
            }
        }
        for u in spoken where u.contains("Interruttore") {
            XCTAssertTrue(switches.contains { u.hasPrefix($0) }, "«Interruttore» solo sulle righe con l'interruttore: «\(u)»",
                          file: file, line: line)
        }
        for u in spoken where u.contains("Apre Impostazioni iOS") {
            XCTAssertTrue(u.hasPrefix("Apri le impostazioni di iOS"), "suggerimento di un'altra riga: «\(u)»", file: file, line: line)
        }
    }

    // MARK: - VoiceOver

    /// Accende VoiceOver, torna al primo elemento della schermata e avanza fino all'ultimo: le voci pronunciate in ordine.
    @available(iOS 27.0, *)
    private func speakScreen(_ screen: String) throws -> [String] {
        let vo = XCUIDevice.shared.voiceOverService
        if !vo.isEnabled { try vo.enable() }
        sleep(2)
        // al primo elemento: indietro finché la voce non cambia più
        var last = (try? vo.currentSpeech())?.utterance ?? ""
        for _ in 0..<150 {
            let u = (try? vo.moveBackward())?.utterance ?? last
            if u == last { break }
            last = u
        }
        var spoken = [last]
        var same = 0
        for _ in 0..<150 {
            let u = (try? vo.moveForward())?.utterance ?? spoken.last!
            if u == spoken.last! { same += 1; if same >= 2 { break }; continue }
            same = 0
            spoken.append(u)
        }
        try vo.disable()
        sleep(1)
        let text = spoken.enumerated().map { "VOCE|\(screen)|\($0.offset + 1)|\($0.element)" }.joined(separator: "\n")
        print(text)
        let attachment = XCTAttachment(string: text)
        attachment.name = "voiceover-\(screen)"
        attachment.lifetime = .keepAlways
        add(attachment)
        return spoken
    }

    /// Titolo, poi le tre schede (con la selezionata), poi i comandi attesi, poi il contenuto atteso; nessuna voce due volte.
    private func assertOrder(_ spoken: [String], screen: String, title: String, selected: String, commands: [String],
                             content: [String], file: StaticString = #filePath, line: UInt = #line) {
        let all = spoken.joined(separator: " | ")
        func index(_ text: String, from: Int = 0) -> Int? {
            spoken.indices.first { $0 >= from && spoken[$0].contains(text) }
        }
        XCTAssertTrue(spoken.first?.hasPrefix(title) ?? false, "«\(screen)»: prima il titolo — \(all)", file: file, line: line)
        // le tre schede, nell'ordine: VoiceOver dice «Home, pannello 1 di 3» (e «è selezionato» per quella selezionata, prima
        // del nome; sull'iPhone entrando nella barra anche «Barra pannelli»)
        let tabs = Array(spoken.dropFirst().prefix(3))
        XCTAssertEqual(tabs.count, 3, "«\(screen)»: tre schede dopo il titolo — \(all)", file: file, line: line)
        for (k, name) in XCUIApplication.tabNames.enumerated() where k < tabs.count {
            XCTAssertTrue(tabs[k].contains(name) && tabs[k].contains("\(k + 1) di 3"),
                          "«\(screen)»: scheda \(k + 1) «\(name)» — \(all)", file: file, line: line)
            XCTAssertEqual(tabs[k].localizedCaseInsensitiveContains("selezionat"), name == selected,
                           "«\(screen)»: selezionata solo «\(selected)» — \(all)", file: file, line: line)
        }
        // poi i comandi, nell'ordine, poi il contenuto
        var last = 3
        for c in commands {
            guard let i = index(c, from: 4) else {
                XCTFail("«\(screen)»: comando «\(c)» non pronunciato — \(all)", file: file, line: line); continue
            }
            XCTAssertGreaterThan(i, last, "«\(screen)»: comandi nell'ordine — \(all)", file: file, line: line)
            last = i
        }
        for c in content {
            guard let i = index(c, from: 4) else {
                XCTFail("«\(screen)»: «\(c)» non pronunciato — \(all)", file: file, line: line); continue
            }
            XCTAssertGreaterThan(i, last, "«\(screen)»: il contenuto dopo i comandi — \(all)", file: file, line: line)
        }
        var seen: [String: Int] = [:]
        for u in spoken where !u.hasPrefix("Opzioni") { seen[u, default: 0] += 1 }
        for (u, n) in seen where n > 1 {
            XCTFail("«\(screen)»: «\(u)» pronunciato \(n) volte — \(all)", file: file, line: line)
        }
    }
}
