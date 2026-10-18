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
        assertOrder(try speakScreen("Impostazioni"), screen: "Impostazioni", title: "Impostazioni", selected: "Impostazioni",
                    commands: [], content: ["Aspetto della lettura"])
        XCTAssertTrue(app.tapTab("Home"))
        XCTAssertTrue(app.waitForScreen("ScaboPDF"))
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Workspace di prova A")).firstMatch.tap()
        XCTAssertTrue(app.waitForScreen("Workspace di prova A"))
        assertOrder(try speakScreen("Workspace"), screen: "Workspace", title: "Workspace di prova A", selected: "Home",
                    commands: ["ScaboPDF", "Opzioni del contenitore"], content: ["Cartella di prova"])
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
