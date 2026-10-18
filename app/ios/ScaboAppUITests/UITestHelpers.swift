//
//  UITestHelpers.swift
//  ScaboAppUITests
//
//  Aiuti condivisi dai test d'interfaccia (giro «accessibilità e completamento», 2026-10-18).
//
//  Le SCHEDE: sull'iPhone sono una `tabBar` in basso; sull'iPad dal 2024 sono una barra galleggiante in alto che i test
//  d'interfaccia NON vedono come `tabBar` (è un contenitore generico con pulsanti). I test scritti per la barra dell'iPhone
//  (`app.tabBars…`) sull'iPad aspettavano invano o toccavano a vuoto: qui la scheda si cerca come pulsante col nome della
//  scheda, fuori dalla barra di navigazione e dalle liste, su entrambi gli apparecchi.
//  Il TITOLO della schermata: dal giro è un'intestazione nostra sotto la barra in alto (identificatore `screen.title`),
//  non più il titolo della barra di navigazione.
//

import XCTest

extension XCUIApplication {

    /// I nomi delle schede, nell'ordine.
    static let tabNames = ["Home", "Ricerca", "Impostazioni"]

    /// Il pulsante della scheda `name` (iPhone: nella `tabBar`; iPad: nella barra galleggiante), se c'è.
    func tabButton(_ name: String) -> XCUIElement? {
        if tabBars.firstMatch.exists, tabBars.buttons[name].exists { return tabBars.buttons[name] }
        let byName = NSPredicate(format: "label == %@", name)
        // Fuori dalla barra di navigazione: un «indietro» può chiamarsi come una scheda («Impostazioni»).
        let navFrames = navigationBars.buttons.matching(byName).allElementsBoundByIndex.map(\.frame)
        return buttons.matching(byName).allElementsBoundByIndex.first { b in b.isHittable && !navFrames.contains(b.frame) }
    }

    /// Tocca la scheda `name`; falso se la scheda non si trova (il test lo dice, non tocca a vuoto in silenzio).
    @discardableResult
    func tapTab(_ name: String, timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let tab = tabButton(name) { tab.tap(); return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        return false
    }

    /// Il titolo della schermata (l'intestazione sotto la barra in alto).
    var screenTitle: XCUIElement { staticTexts["screen.title"] }

    /// Aspetta che la schermata col titolo `title` sia in vista.
    func waitForScreen(_ title: String, timeout: TimeInterval = 15) -> Bool {
        let predicate = NSPredicate(format: "identifier == 'screen.title' AND label == %@", title)
        return staticTexts.matching(predicate).firstMatch.waitForExistence(timeout: timeout)
    }

    /// Il pulsante «indietro» della barra in alto (il primo pulsante della barra di navigazione).
    var backButton: XCUIElement { navigationBars.buttons.element(boundBy: 0) }

    /// Il pulsante «indietro» della schermata col titolo `title`, quando la schermata è in vista; altrimenti un elemento
    /// che non esiste (chi chiama ne aspetta l'esistenza).
    func backButton(onScreen title: String, timeout: TimeInterval = 5) -> XCUIElement {
        waitForScreen(title, timeout: timeout) ? backButton : navigationBars["nessuna barra: «\(title)» non è in vista"]
    }
}
