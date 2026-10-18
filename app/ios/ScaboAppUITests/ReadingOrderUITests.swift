//
//  ReadingOrderUITests.swift
//  ScaboAppUITests
//
//  L'ORDINE DI LETTURA delle schermate con le schede (giro «accessibilità e completamento», 2026-10-18; LAYER2 § 12.1):
//  VoiceOver legge il TITOLO della schermata, subito dopo le TRE SCHEDE (Home, Ricerca, Impostazioni, quella selezionata
//  segnata), poi i COMANDI della barra in alto (Indietro, Tag, Affianca, Importa, …), poi il CONTENUTO; nessun elemento
//  due volte. Prima della cura, sull'iPad con iPadOS 27 e sull'iPhone le schede si leggevano per ULTIME, dopo tutta la
//  libreria (misura del giro). Il test fissa l'ordine su ogni schermata con le schede, sull'iPad e sull'iPhone: una
//  regressione futura, anche un cambio del sistema, lo fa diventare rosso.
//
//  Strumento: l'albero d'accessibilità esposto ai test d'interfaccia (lo stesso che percorre VoiceOver), letto in
//  profondità; ogni foglia ha una ZONA: titolo (`screen.title`), scheda (pulsante col nome di una scheda fuori dalla barra
//  in alto e dalle liste), barra (dentro la barra di navigazione), contenuto (il resto). Il seme `-uiTestSeedHomeOrder`
//  crea tre libri, due workspace (il primo con una cartella) e un segnalibro con un tag: nomi inventati.
//

import XCTest

final class ReadingOrderUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = true   // vogliamo tutte le schermate, non solo la prima che cade
    }

    func testReadingOrder_titleTabsCommandsContent_onEveryScreenWithTabs() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestSeedHomeOrder"]
        app.launch()
        XCTAssertTrue(app.waitForScreen("ScaboPDF", timeout: 30), "la Home compare")

        check(app, screen: "ScaboPDF", tab: "Home", content: [
            "Libro di prova tre, documento, 3 pagine", "Libro di prova due, documento, 3 pagine",
            "Libro di prova uno, documento, 3 pagine", "Workspaces", "Nuovo workspace",
            "Workspace di prova A, workspace, 1 cartella", "Workspace di prova B, workspace, vuoto"])

        XCTAssertTrue(app.tapTab("Ricerca"), "scheda Ricerca")
        XCTAssertTrue(app.waitForScreen("Ricerca"))
        check(app, screen: "Ricerca", tab: "Ricerca", content: ["Cerca nei documenti"])

        XCTAssertTrue(app.tapTab("Impostazioni"), "scheda Impostazioni")
        XCTAssertTrue(app.waitForScreen("Impostazioni"))
        check(app, screen: "Impostazioni", tab: "Impostazioni", content: [])
        let keyboardRow = app.cells.staticTexts["Comandi da tastiera"].firstMatch
        if keyboardRow.waitForExistence(timeout: 5) {
            keyboardRow.tap()
            XCTAssertTrue(app.waitForScreen("Comandi da tastiera"))
            check(app, screen: "Comandi da tastiera", tab: "Impostazioni", content: [])
            app.backButton.tap()
        } else { XCTFail("riga «Comandi da tastiera» assente") }

        XCTAssertTrue(app.tapTab("Home"), "scheda Home")
        XCTAssertTrue(app.waitForScreen("ScaboPDF"))
        app.buttons["Tag"].firstMatch.tap()
        XCTAssertTrue(app.waitForScreen("Tag"))
        check(app, screen: "Tag", tab: "Home", content: ["Importante"])
        app.cells.staticTexts["Importante"].firstMatch.tap()
        XCTAssertTrue(app.waitForScreen("Segnalibri per tag"))
        check(app, screen: "Segnalibri per tag", tab: "Home", content: [])
        app.backButton.tap()
        XCTAssertTrue(app.waitForScreen("Tag"))
        app.backButton.tap()
        XCTAssertTrue(app.waitForScreen("ScaboPDF"))

        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Workspace di prova A")).firstMatch.tap()
        XCTAssertTrue(app.waitForScreen("Workspace di prova A"))
        check(app, screen: "Workspace di prova A", tab: "Home", content: ["Cartella di prova, cartella, 1 file"])
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Cartella di prova")).firstMatch.tap()
        XCTAssertTrue(app.waitForScreen("Cartella di prova"))
        check(app, screen: "Cartella di prova", tab: "Home", content: ["Libro di prova uno, documento, 3 pagine"])
    }

    // MARK: - Verifica di una schermata

    private struct Leaf {
        let type: String, label: String, identifier: String, frame: CGRect, selected: Bool, zone: String, inCell: Bool
    }

    private func check(_ app: XCUIApplication, screen: String, tab: String, content expected: [String],
                       file: StaticString = #filePath, line: UInt = #line) {
        sleep(1)
        let leaves = self.leaves(app, screen: screen)
        let zones = leaves.map(\.zone)
        let names = leaves.map { "\($0.zone):\($0.label)" }.joined(separator: " | ")
        // 1. prima il titolo della schermata
        XCTAssertEqual(leaves.first?.zone, "titolo", "«\(screen)»: il primo elemento è il titolo — \(names)", file: file, line: line)
        XCTAssertEqual(leaves.first?.label, screen, "«\(screen)»: titolo giusto", file: file, line: line)
        // 2. subito dopo le tre schede, nell'ordine, con quella giusta selezionata
        let tabs = Array(leaves.dropFirst().prefix(3))
        XCTAssertEqual(tabs.map(\.zone), ["scheda", "scheda", "scheda"], "«\(screen)»: le schede subito dopo il titolo — \(names)",
                       file: file, line: line)
        XCTAssertEqual(tabs.map(\.label), XCUIApplication.tabNames, "«\(screen)»: schede nell'ordine", file: file, line: line)
        XCTAssertEqual(tabs.filter(\.selected).map(\.label), [tab], "«\(screen)»: scheda selezionata", file: file, line: line)
        // 3. poi la barra (comandi), poi il contenuto; titolo e schede mai più
        let rest = Array(zones.dropFirst(4))
        XCTAssertFalse(rest.contains("titolo") || rest.contains("scheda"), "«\(screen)»: titolo e schede una volta sola — \(names)",
                       file: file, line: line)
        if let firstContent = rest.firstIndex(of: "contenuto"), let lastBar = rest.lastIndex(of: "barra") {
            XCTAssertLessThan(lastBar, firstContent, "«\(screen)»: i comandi della barra prima del contenuto — \(names)", file: file, line: line)
        }
        // 4. il contenuto atteso c'è, una volta
        for label in expected {
            let n = leaves.filter { $0.zone == "contenuto" && $0.label == label }.count
            XCTAssertEqual(n, 1, "«\(screen)»: «\(label)» nel contenuto una volta (trovato \(n)) — \(names)", file: file, line: line)
        }
        // 5. nessun elemento due volte (stessa etichetta, stesso tipo, stessa cornice). Fuori dalle righe delle liste: lì
        // il difetto nasce (una lista ripete in coda le viste accessibili delle sue intestazioni); dentro, righe diverse
        // fuori schermo possono avere la stessa cornice fittizia.
        var seen = Set<String>()
        for l in leaves where !l.inCell {
            let key = "\(l.type)|\(l.label)|\(Int(l.frame.minX)),\(Int(l.frame.minY)),\(Int(l.frame.width)),\(Int(l.frame.height))"
            XCTAssertTrue(seen.insert(key).inserted, "«\(screen)»: elemento doppio «\(l.label)»", file: file, line: line)
        }
    }

    /// Le foglie dell'albero d'accessibilità in profondità, con la zona. Le figlie di un pulsante (la sua etichetta) e di una
    /// cella con etichetta propria non sono elementi a sé; le barre di scorrimento non si leggono.
    private func leaves(_ app: XCUIApplication, screen: String) -> [Leaf] {
        guard let snapshot = try? app.snapshot() else { XCTFail("snapshot non riuscito"); return [] }
        var out: [Leaf] = []
        var raw: [String] = []
        let leafTypes: Set<XCUIElement.ElementType> = [.button, .staticText, .searchField, .switch, .textField, .link, .image,
                                                       .segmentedControl, .slider, .cell, .tab, .other]
        func walk(_ s: XCUIElementSnapshot, depth: Int, inBar: Bool, inList: Bool, inLeaf: Bool, inCell: Bool = false) {
            let f = s.frame
            raw.append("ORDINE|\(screen)|\(depth)|\(Self.typeName(s.elementType))|\(s.label)|\(s.identifier)|"
                + String(format: "(%.0f,%.0f %.0fx%.0f)", f.minX, f.minY, f.width, f.height) + "|sel=\(s.isSelected)")
            let bar = inBar || s.elementType == .navigationBar
            let list = inList || [.table, .collectionView, .cell].contains(s.elementType)
            let cell = inCell || s.elementType == .cell
            let labelled = !s.label.isEmpty && !s.label.hasPrefix("Barra di scorrimento")
            var isLeaf = false
            if !inLeaf, leafTypes.contains(s.elementType), labelled {
                switch s.elementType {
                case .cell, .other: isLeaf = s.children.isEmpty || s.elementType == .cell
                default: isLeaf = true
                }
            }
            if isLeaf {
                let zone: String
                if s.identifier == "screen.title" { zone = "titolo" }
                else if bar { zone = "barra" }
                else if !list, s.elementType == .button, XCUIApplication.tabNames.contains(s.label) { zone = "scheda" }
                else { zone = "contenuto" }
                out.append(Leaf(type: Self.typeName(s.elementType), label: s.label, identifier: s.identifier, frame: f,
                                selected: s.isSelected, zone: zone, inCell: cell))
            }
            for c in s.children {
                walk(c, depth: depth + 1, inBar: bar, inList: list, inLeaf: inLeaf || isLeaf, inCell: cell)
            }
        }
        walk(snapshot, depth: 0, inBar: false, inList: false, inLeaf: false)
        // Fotografia per il laboratorio (righe ORDINE/VO nel registro del test; nessun testo dei volumi: seme inventato).
        let order = out.enumerated().map { "VO|\(screen)|\($0.offset + 1)|\($0.element.zone)|\($0.element.type)|\($0.element.label)|"
            + String(format: "(%.0f,%.0f %.0fx%.0f)", $0.element.frame.minX, $0.element.frame.minY, $0.element.frame.width,
                     $0.element.frame.height) + "|sel=\($0.element.selected)" }
        print((raw + order).joined(separator: "\n"))
        if let dir = ProcessInfo.processInfo.environment["SCABO_SHOTS"], !dir.isEmpty {
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            let file = URL(fileURLWithPath: dir).appendingPathComponent(screen.replacingOccurrences(of: " ", with: "_") + ".png")
            try? XCUIScreen.main.screenshot().pngRepresentation.write(to: file)
        }
        return out
    }

    static func typeName(_ t: XCUIElement.ElementType) -> String {
        switch t {
        case .application: return "application"
        case .window: return "window"
        case .other: return "other"
        case .button: return "button"
        case .staticText: return "staticText"
        case .cell: return "cell"
        case .table: return "table"
        case .collectionView: return "collectionView"
        case .navigationBar: return "navigationBar"
        case .tabBar: return "tabBar"
        case .toolbar: return "toolbar"
        case .image: return "image"
        case .searchField: return "searchField"
        case .switch: return "switch"
        case .segmentedControl: return "segmentedControl"
        case .scrollView: return "scrollView"
        case .textField: return "textField"
        default: return "type\(t.rawValue)"
        }
    }
}
