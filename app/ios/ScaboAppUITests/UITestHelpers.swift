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

    /// Vero se è aperto un foglio: sull'iPad la sua barra di navigazione è più stretta dello schermo.
    var isShowingSheet: Bool {
        let width = frame.width
        return navigationBars.allElementsBoundByIndex.contains { $0.exists && $0.isHittable && $0.frame.width < width * 0.9 }
    }
}

// MARK: - Rilievi di sistema dell'audit d'accessibilità

/// I rilievi dell'audit d'accessibilità che vengono dal SISTEMA e non dall'app, accettati in modo stretto: si stampano nel
/// registro del test (dichiarati) e non fanno fallire; ogni altro rilievo fa fallire. Misure del giro «accessibilità e
/// completamento» (2026-10-18), iPad iOS 27, sulla copia di partenza `8db0bcd` (sonde di laboratorio):
/// 1. **Dynamic Type sulle etichette della barra delle schede galleggiante di iPadOS.** Sulla Home 3 rilievi «User will not
///    be able to change the font size of this UILabel», senza elemento, con la barra in vista; 0 con la barra nascosta: sono
///    le tre etichette delle schede, una vista di sistema di cui l'app non regola il carattere. Accettati solo sull'iPad,
///    senza elemento, su un'etichetta, al più uno per scheda in ogni audit, e solo con la barra delle schede in vista o
///    sotto un foglio.
/// 2. **«Testo potenzialmente inaccessibile» senza elemento attorno a un foglio.** La schermata «Libro già presente» come
///    foglio: 4 rilievi; la stessa a schermo intero: 0. È il testo della schermata sotto, visibile ai lati del foglio e
///    volutamente fuori da VoiceOver mentre il foglio è aperto. Accettati solo sull'iPad, senza elemento, e solo con un
///    foglio aperto (`XCUIApplication.isShowingSheet`).
@available(iOS 17.0, *)
final class SystemAuditRule {
    private let app: XCUIApplication
    private let screen: String
    private let sheet: Bool
    private var tabLabels = 0

    init(app: XCUIApplication, screen: String) {
        self.app = app
        self.screen = screen
        self.sheet = app.isShowingSheet
    }

    /// Vero se il rilievo è uno dei rilievi di sistema descritti sopra (e allora lo stampa come dichiarato).
    func accept(_ issue: XCUIAccessibilityAuditIssue) -> Bool {
        guard UIDevice.current.userInterfaceIdiom == .pad, issue.element == nil else { return false }
        var accepted = false
        switch issue.auditType {
        case .dynamicType:
            let tabsInView = XCUIApplication.tabNames.allSatisfy { app.tabButton($0) != nil }
            if issue.detailedDescription.contains("UILabel"), tabLabels < XCUIApplication.tabNames.count, tabsInView || sheet {
                tabLabels += 1
                accepted = true
            }
        case .elementDetection:
            accepted = sheet
        default:
            break
        }
        if accepted {
            print("AUDIT «\(screen)» rilievo di sistema dell'iPad accettato e dichiarato: \(issue.compactDescription) — "
                  + issue.detailedDescription)
        }
        return accepted
    }
}
