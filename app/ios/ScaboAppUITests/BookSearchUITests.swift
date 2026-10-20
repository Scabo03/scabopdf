//
//  BookSearchUITests.swift
//  ScaboAppUITests
//
//  LA RICERCA DENTRO IL LIBRO (giro «ricerca nel libro», 2026-10-19; LAYER2 § 13.3), provata nell'app vera. Seme
//  `-uiTestSeedKeyboardBooks` (due libri con testo inventato: un richiamo e la sua nota lunga letta a fine sezione, due
//  sezioni, trenta paragrafi prima e dopo; il primo libro si riapre sulla nota).
//
//  Senza VoiceOver, con la tastiera hardware del simulatore: ⌘F apre «Cerca nel libro», A capo cerca, la riga del
//  conteggio dice quanti risultati, il risultato scelto porta la lettura lì (anche dentro una nota); Annulla lascia la
//  lettura dov'era; ⌘G e Maiuscole ⌘G scorrono i risultati nella lettura, senza vicoli ciechi; zero risultati si spiegano;
//  l'audit d'accessibilità della finestra. Con VOICEOVER VERO (da iOS 27, `XCUIDevice.voiceOverService`): l'ordine della
//  finestra (titolo, Annulla, campo, «Parola intera», conteggio, risultati), il conteggio detto subito dopo la ricerca, e
//  dopo il doppio tap su un risultato il fuoco di VoiceOver sull'elemento della lettura che lo contiene. Il rotore
//  «Risultati della ricerca» non si gira dai test (il servizio non ha il rotore): lo provano i test di unità sul rotore
//  stesso (`BookSearchAppTests`). Come in `KeyboardUITests`: Esc si manda con Comando-punto e A capo con «\n»; con
//  VoiceOver acceso nel simulatore i comandi col Comando non scattano, quindi la finestra si apre prima di accenderlo.
//

import XCTest

final class BookSearchUITests: XCTestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
        try voiceOverOff()
    }

    override func tearDownWithError() throws {
        try voiceOverOff()
        try super.tearDownWithError()
    }

    private func voiceOverOff() throws {
        guard #available(iOS 27.0, *) else { return }
        let vo = XCUIDevice.shared.voiceOverService
        guard vo.isEnabled else { return }
        try vo.disable()
        let deadline = Date().addingTimeInterval(10)
        while vo.isEnabled, Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.25)) }
        sleep(1)
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestSeedKeyboardBooks"]
        app.launch()
        XCTAssertTrue(app.waitForScreen("ScaboPDF", timeout: 30), "la Home compare")
        app.typeKey(XCUIKeyboardKey.shift, modifierFlags: [])   // il primo tasto dopo l'avvio a volte non arriva
        sleep(1)
        return app
    }

    private func reading(_ app: XCUIApplication, _ text: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    /// Vero se l'elemento è (o compare entro qualche secondo: subito dopo la chiusura di una finestra l'albero può essere
    /// ancora vuoto per un momento) nella parte alta della schermata.
    private func isNearTheTop(_ app: XCUIApplication, _ element: XCUIElement) -> Bool {
        _ = element.waitForExistence(timeout: 5)
        let near = element.exists && element.frame.minY < app.frame.height * 0.4
        if !near {
            // Per capire un rosso: che cosa c'è in cima alla lettura (testo inventato del seme).
            let top = app.collectionViews.firstMatch.staticTexts.allElementsBoundByIndex.prefix(3)
                .map { "\(Int($0.frame.minY)): \($0.label.prefix(50))" }
            let home = app.staticTexts.matching(NSPredicate(format: "identifier == 'screen.title'")).firstMatch
            print("IN CIMA: \(top) — cercato \(element.exists ? "a y \(Int(element.frame.minY))" : "assente")"
                  + " — titolo di schermata: \(home.exists ? home.label : "nessuno")")
        }
        return near
    }

    private func open(_ app: XCUIApplication, _ title: String, showing text: String) {
        let book = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
        XCTAssertTrue(book.waitForExistence(timeout: 10), "«\(title)» fra i recenti")
        book.tap()
        XCTAssertTrue(reading(app, text).waitForExistence(timeout: 20), "il libro è aperto")
        sleep(1)
        app.typeKey(XCUIKeyboardKey.shift, modifierFlags: [])
        sleep(1)
    }

    private var searchBar: (XCUIApplication) -> XCUIElement { { $0.navigationBars["Cerca nel libro"] } }

    /// Un elemento della finestra per identificatore, di qualunque tipo (le righe dei risultati sono pulsanti, il
    /// conteggio è un testo).
    private func item(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    /// ⌘F nel lettore apre la finestra «Cerca nel libro», col campo pronto per scrivere.
    private func openSearch(_ app: XCUIApplication) {
        app.typeKey("f", modifierFlags: .command)
        let shown = searchBar(app).waitForExistence(timeout: 8)
        if !shown { print("GERARCHIA dopo ⌘F:\n\(app.debugDescription)") }
        XCTAssertTrue(shown, "⌘F apre «Cerca nel libro»")
        let field = app.textFields["ricerca.campo"].waitForExistence(timeout: 5)
        if !field { print("GERARCHIA della finestra:\n\(app.debugDescription)") }
        XCTAssertTrue(field, "il campo")
        sleep(1)
    }

    /// Scrive la ricerca e la esegue (A capo); aspetta la frase del conteggio che contiene `countText`. Sull'iPhone iOS 27,
    /// alla prima comparsa della tastiera dopo l'avvio, l'A capo sintetico dei test può non arrivare al campo (la frase
    /// resta quella d'aiuto, nessuna ricerca parte: suite del 2026-10-19): in quel caso lo si ripete UNA volta, e lo si
    /// scrive nel registro della prova. Una ricerca partita e sbagliata resta rossa.
    @discardableResult
    private func search(_ app: XCUIApplication, _ text: String, expect countText: String) -> XCUIElement {
        app.typeText(text)
        app.typeKey("\n", modifierFlags: [])
        let count = app.staticTexts["ricerca.conteggio"]
        let started = NSPredicate(format: "NOT (label BEGINSWITH %@)", "Scrivi una parola")
        if XCTWaiter.wait(for: [expectation(for: started, evaluatedWith: count)], timeout: 4) != .completed {
            print("A CAPO NON ARRIVATO al campo: ripetuto una volta")
            app.typeKey("\n", modifierFlags: [])
        }
        let predicate = NSPredicate(format: "label CONTAINS %@", countText)
        let ok = expectation(for: predicate, evaluatedWith: count)
        let result = XCTWaiter.wait(for: [ok], timeout: 10)
        if result != .completed { print("CONTEGGIO: «\(count.label)»\n\(app.debugDescription)") }
        XCTAssertEqual(result, .completed, "il conteggio contiene «\(countText)»")
        return count
    }

    // MARK: - Senza VoiceOver, con la tastiera

    /// ⌘F, una frase che sta nel corpo e in una nota: due risultati, quello nella nota lo dice; scelto, la lettura va lì.
    func testCommandF_findsTheTextOfNotesToo_andTheChosenResultOpensThere() throws {
        let app = launch()
        open(app, "Libro tastiera due", showing: "Capitolo primo del libro due")
        openSearch(app)
        search(app, "PIENA del fiume", expect: "2 risultati per «PIENA del fiume».")
        let first = item(app, "ricerca.risultato.0"), second = item(app, "ricerca.risultato.1")
        XCTAssertTrue(first.exists && second.exists)
        XCTAssertFalse(first.label.contains("Nella nota"), first.label)
        XCTAssertTrue(second.label.contains("Nella nota 1"), "dice che è in una nota: «\(second.label)»")
        XCTAssertTrue(second.label.contains("Capitolo primo del libro due"), "la sezione: «\(second.label)»")
        second.tap()
        XCTAssertTrue(searchBar(app).waitForNonExistence(timeout: 8), "la finestra si chiude")
        let note = reading(app, "Una nota di prova lunga sul mulino")
        XCTAssertTrue(note.waitForExistence(timeout: 8))
        XCTAssertTrue(isNearTheTop(app, note), "la lettura è sulla nota (in cima alla schermata)")
    }

    /// Annulla (Esc) chiude la finestra e la lettura resta dov'era: il primo libro si riapre sulla nota e lì resta.
    func testCancel_leavesTheReadingWhereItWas() throws {
        let app = launch()
        open(app, "Libro tastiera uno", showing: "Una nota di prova lunga")
        let note = reading(app, "Una nota di prova lunga")
        XCTAssertTrue(isNearTheTop(app, note), "si riapre sulla nota")
        openSearch(app)
        search(app, "faro", expect: "Un risultato per «faro».")
        app.typeKey(".", modifierFlags: .command)   // Esc
        XCTAssertTrue(searchBar(app).waitForNonExistence(timeout: 8), "Esc chiude la finestra")
        sleep(1)
        XCTAssertTrue(isNearTheTop(app, reading(app, "Una nota di prova lunga")), "la lettura non si è mossa")
    }

    /// ⌘G e Maiuscole ⌘G percorrono i risultati nella lettura; dopo l'ultimo la lettura non si muove (nessun salto a vuoto).
    func testCommandG_andShiftCommandG_stepThroughTheResults() throws {
        let app = launch()
        open(app, "Libro tastiera due", showing: "Capitolo primo del libro due")
        openSearch(app)
        search(app, "sezione", expect: "3 risultati per «sezione».")
        app.typeKey(".", modifierFlags: .command)   // Esc: la ricerca resta, la lettura non si muove
        XCTAssertTrue(searchBar(app).waitForNonExistence(timeout: 8))
        sleep(1)
        let stops = ["Una nota di prova lunga", "Sezione seconda del libro due", "Sezione terza del libro due"]
        for stop in stops {
            app.typeKey("g", modifierFlags: .command)
            sleep(1)
            XCTAssertTrue(isNearTheTop(app, reading(app, stop)), "⌘G porta a «\(stop)»")
        }
        app.typeKey("g", modifierFlags: .command)   // oltre l'ultimo
        sleep(1)
        XCTAssertTrue(isNearTheTop(app, reading(app, stops[2])), "dopo l'ultimo la lettura resta")
        app.typeKey("g", modifierFlags: [.command, .shift])
        sleep(1)
        XCTAssertTrue(isNearTheTop(app, reading(app, stops[1])), "Maiuscole ⌘G torna al precedente")
    }

    /// Zero risultati: detto in prosa, con un suggerimento; con «Parola intera» il suggerimento è di toglierla.
    func testZeroResults_areExplained_withASuggestion() throws {
        let app = launch()
        open(app, "Libro tastiera due", showing: "Capitolo primo del libro due")
        openSearch(app)
        let count = search(app, "nessunaparolacosì", expect: "Nessun risultato per «nessunaparolacosì».")
        XCTAssertTrue(count.label.contains("Prova"), count.label)
        let toggle = app.switches["ricerca.parolaIntera"]
        XCTAssertTrue(toggle.exists, "l'interruttore «Parola intera»")
        // «mulin» dentro «mulino»: con «Parola intera» nessun risultato, e il suggerimento è di toglierla.
        let field = app.textFields["ricerca.campo"]
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 30))   // il campo vuoto: l'interruttore non cerca
        toggle.tap()
        field.tap()
        let whole = search(app, "mulin", expect: "Nessun risultato per «mulin».")
        XCTAssertTrue(whole.label.contains("togliere «Parola intera»"), whole.label)
    }

    /// Sceglie `title` nel foglio «Aggiungi un file» dello split (come in `KeyboardUITests`).
    private func choose(_ app: XCUIApplication, _ title: String) {
        let bar = app.navigationBars["Aggiungi un file"]
        XCTAssertTrue(bar.waitForExistence(timeout: 10), "la scelta del file è aperta")
        sleep(1)
        let sheet = bar.frame
        let row = app.cells.allElementsBoundByIndex.first { cell in
            cell.frame.minX >= sheet.minX - 1 && cell.frame.maxX <= sheet.maxX + 1 && cell.staticTexts[title].exists
        }
        XCTAssertNotNil(row, "«\(title)» nella scelta")
        row?.tap()
        sleep(2)
    }

    /// Nello split (iPad) la ricerca è della metà che comanda: ⌘F apre la finestra da quella metà, Esc nella finestra la
    /// chiude senza toccare lo split (nessuna domanda «Chiudi metà»), e subito dopo ⌘G porta ai risultati in quella metà.
    func testSplit_searchBelongsToTheCommandingHalf_withoutTraps() throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else { throw XCTSkip("lo split screen è solo dell'iPad (§ 11.1)") }
        let app = launch()
        app.buttons["Affianca due documenti"].firstMatch.tap()
        for title in ["Libro tastiera uno", "Libro tastiera due"] { choose(app, title) }
        XCTAssertTrue(reading(app, "del libro uno").waitForExistence(timeout: 20), "lo split è aperto")
        sleep(1)
        app.typeKey(XCUIKeyboardKey.rightArrow, modifierFlags: [.command, .alternate])   // comanda la destra
        XCTAssertTrue(reading(app, "Capitolo primo del libro due").waitForExistence(timeout: 5), "la metà destra comanda")
        sleep(1)
        openSearch(app)
        search(app, "sezione", expect: "3 risultati per «sezione».")
        app.typeKey(".", modifierFlags: .command)   // Esc
        XCTAssertTrue(searchBar(app).waitForNonExistence(timeout: 8), "Esc chiude la finestra")
        XCTAssertFalse(app.alerts.firstMatch.waitForExistence(timeout: 2), "Esc non chiede di chiudere la metà")
        sleep(1)
        app.typeKey("g", modifierFlags: .command)
        XCTAssertTrue(isNearTheTop(app, reading(app, "sezione del libro due")), "⌘G vale per la metà che comanda")
        // Riaperta sull'ultima ricerca, la finestra riceve i tasti: Esc la chiude, sempre senza la domanda (revisione).
        sleep(1)
        app.typeKey("f", modifierFlags: .command)
        XCTAssertTrue(searchBar(app).waitForExistence(timeout: 8), "⌘F la riapre")
        XCTAssertTrue(app.staticTexts["ricerca.conteggio"].waitForExistence(timeout: 5), "sull'ultima ricerca")
        sleep(1)
        app.typeKey(".", modifierFlags: .command)   // Esc
        XCTAssertTrue(searchBar(app).waitForNonExistence(timeout: 8), "Esc chiude la finestra riaperta")
        XCTAssertFalse(app.alerts.firstMatch.waitForExistence(timeout: 2), "Esc non chiede di chiudere la metà")
    }

    /// Riaperta su una ricerca in corso, la finestra riceve i tasti anche a schermo intero: ⌘F porta al campo, Esc dal
    /// campo la chiude (revisione del giro: prima ⌘F nella finestra riaperta non arrivava).
    func testReopenedWindow_commandFGoesToTheField_andEscClosesIt() throws {
        let app = launch()
        open(app, "Libro tastiera due", showing: "Capitolo primo del libro due")
        openSearch(app)
        search(app, "faro", expect: "per «faro»")
        app.typeKey(".", modifierFlags: .command)   // Esc
        XCTAssertTrue(searchBar(app).waitForNonExistence(timeout: 8), "Annulla")
        sleep(1)
        app.typeKey("f", modifierFlags: .command)
        XCTAssertTrue(searchBar(app).waitForExistence(timeout: 8), "⌘F la riapre")
        XCTAssertTrue(app.staticTexts["ricerca.conteggio"].waitForExistence(timeout: 5), "sull'ultima ricerca")
        sleep(1)
        app.typeKey("f", modifierFlags: .command)
        let field = app.textFields["ricerca.campo"]
        let focused = expectation(for: NSPredicate(format: "hasKeyboardFocus == true"), evaluatedWith: field)
        XCTAssertEqual(XCTWaiter.wait(for: [focused], timeout: 5), .completed, "⌘F nella finestra riaperta porta al campo")
        app.typeKey(".", modifierFlags: .command)   // Esc dal campo
        XCTAssertTrue(searchBar(app).waitForNonExistence(timeout: 8), "Esc chiude la finestra")
    }

    /// L'audit d'accessibilità della finestra con i risultati (iPhone e iPad; sull'iPad i rilievi di sistema sotto un foglio
    /// sono quelli dichiarati e accettati con tetto in `SystemAuditRule`).
    func testAccessibilityAudit_ofTheSearchWindowWithResults() throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("performAccessibilityAudit richiede iOS 17+") }
        let app = launch()
        open(app, "Libro tastiera due", showing: "Capitolo primo del libro due")
        openSearch(app)
        search(app, "libro due", expect: "risultati per «libro due»")
        sleep(1)
        let rule = SystemAuditRule(app: app, screen: "Cerca nel libro")
        try app.performAccessibilityAudit { issue in rule.accept(issue) }
    }

    // MARK: - Con VoiceOver vero (iOS 27)

    // Il fuoco dopo «Annulla» in Dottrina Inline e in Consultazione Rapida (revisione del giro, R7) non si prova qui con
    // VoiceOver vero: la barra si raggiunge solo con lo scrub a due dita, che il servizio VoiceOver dei test non ha, e con
    // VoiceOver acceso i comandi col Comando non arrivano; senza VoiceOver la barra non è nell'albero e il fuoco non c'è.
    // Le correzioni hanno le prove di unità dell'albero (`BookSearchAppTests`); il resto è da sentire sul dispositivo.

    /// Ordine della finestra, conteggio detto subito, e fuoco sull'elemento giusto dopo il doppio tap su un risultato.
    func testVoiceOver_countIsSpokenFirst_andTheChosenResultGetsTheFocus() throws {
        guard #available(iOS 27.0, *) else { throw XCTSkip("il servizio VoiceOver dei test c'è da iOS 27") }
        let app = launch()
        open(app, "Libro tastiera due", showing: "Capitolo primo del libro due")
        openSearch(app)
        app.typeText("faro")
        let vo = XCUIDevice.shared.voiceOverService
        try vo.enable()
        sleep(2)
        var said: [String] = []
        // L'ordine: dal primo elemento della finestra in avanti fino al primo risultato.
        var last = (try? vo.currentSpeech())?.utterance ?? ""
        for _ in 0..<20 {
            let u = (try? vo.moveBackward())?.utterance ?? last
            if u == last { break }
            last = u
        }
        said.append(last)
        for _ in 0..<12 {
            let u = (try? vo.moveForward())?.utterance ?? ""
            if u == said.last { break }
            said.append(u)
        }
        let order = said.joined(separator: " | ")
        print("VOCE|ricerca|ordine|\(order)")
        func position(_ text: String) -> Int? { said.firstIndex { $0.contains(text) } }
        guard let title = position("Cerca nel libro"), let cancel = position("Annulla"),
              let field = said.indices.first(where: { $0 > title && said[$0].contains("Cerca nel libro") }),
              let whole = position("Parola intera") else {
            return XCTFail("titolo, Annulla, campo, Parola intera: \(order)")
        }
        XCTAssertLessThan(title, cancel, order)
        XCTAssertLessThan(cancel, field, order)
        XCTAssertLessThan(field, whole, order)
        // Cerca (A capo) col fuoco sul campo: VoiceOver dice subito il conteggio.
        _ = try? vo.moveBackward()
        while let u = (try? vo.currentSpeech())?.utterance, !u.contains("Cerca nel libro"), (try? vo.moveBackward()) != nil {}
        app.typeKey("\n", modifierFlags: [])
        sleep(3)
        let afterSearch = (try? vo.currentSpeech())?.utterance ?? ""
        print("VOCE|ricerca|dopo la ricerca|\(afterSearch)")
        XCTAssertTrue(afterSearch.hasPrefix("Un risultato per «faro»"), "il conteggio detto subito: «\(afterSearch)»")
        let row = (try? vo.moveForward())?.utterance ?? ""
        print("VOCE|ricerca|primo risultato|\(row)")
        XCTAssertTrue(row.hasPrefix("Il faro si accende sulla scogliera"), "poi il primo risultato: «\(row)»")
        // Doppio tap (con VoiceOver il doppio tap attiva l'elemento a fuoco): la finestra si chiude e la lettura è lì.
        item(app, "ricerca.risultato.0").doubleTap()
        XCTAssertTrue(searchBar(app).waitForNonExistence(timeout: 10), "la finestra si chiude")
        sleep(3)
        let landed = (try? vo.currentSpeech())?.utterance ?? ""
        print("VOCE|ricerca|dopo il salto|\(landed)")
        XCTAssertTrue(landed.hasPrefix("Il faro si accende sulla scogliera"), "il fuoco sull'elemento che contiene il risultato: «\(landed)»")
        XCTAssertFalse(landed.contains("Pulsante"), "è l'elemento della lettura, non la riga del risultato: «\(landed)»")
        let attachment = XCTAttachment(string: said.joined(separator: "\n") + "\n" + afterSearch + "\n" + row + "\n" + landed)
        attachment.name = "voiceover-ricerca"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

/// LA RICERCA NEL TESTO DI TUTTI I LIBRI dal tab Ricerca, ed ESC come «Annulla»/«Chiudi» nelle finestre (giro «ricerca
/// nella libreria», 2026-10-20). Seme `-uiTestSeedKeyboardBooks` (due libri inventati; «faro» una volta in ciascuno).
/// Senza VoiceOver, con la tastiera hardware del simulatore (Esc = Comando-punto, A capo = «\n», come in `KeyboardUITests`).
final class LibrarySearchUITests: XCTestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestSeedKeyboardBooks"]
        app.launch()
        XCTAssertTrue(app.waitForScreen("ScaboPDF", timeout: 30), "la Home compare")
        app.typeKey(XCUIKeyboardKey.shift, modifierFlags: [])   // il primo tasto dopo l'avvio a volte non arriva
        sleep(1)
        return app
    }

    private func item(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func reading(_ app: XCUIApplication, _ text: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    /// Nel tab Ricerca scrive `text` e preme Cerca; aspetta la frase del riassunto che contiene `expect`.
    @discardableResult
    private func searchLibrary(_ app: XCUIApplication, _ text: String, expect: String) -> XCUIElement {
        XCTAssertTrue(app.tapTab("Ricerca"), "scheda Ricerca")
        XCTAssertTrue(app.waitForScreen("Ricerca"))
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), "il campo di ricerca")
        field.tap()
        sleep(1)
        app.typeText(text)
        app.typeKey("\n", modifierFlags: [])
        let summary = item(app, "libreria.riassunto")
        if !summary.waitForExistence(timeout: 6) {
            print("A CAPO NON ARRIVATO al campo: ripetuto una volta")
            app.typeKey("\n", modifierFlags: [])
        }
        let ok = XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "label CONTAINS %@", expect), evaluatedWith: summary)],
                                timeout: 15)
        if ok != .completed { print("RIASSUNTO: «\(summary.exists ? summary.label : "assente")»\n\(app.debugDescription)") }
        XCTAssertEqual(ok, .completed, "il riassunto contiene «\(expect)»")
        return summary
    }

    /// Dal tab Ricerca: il riassunto (quanti libri, quanti risultati) prima dei libri, un libro per riga col titolo e il
    /// numero di risultati, i titoli trovabili come prima; scelto un libro, la sua lista; scelto un risultato, la lettura lì
    /// con le frecce dei risultati (la ricerca è attiva); Esc riporta alla Ricerca con i risultati di prima.
    func testLibrary_textOfAllBooks_bookList_thenTheReadingWithTheSearchActive() throws {
        let app = launch()
        let summary = searchLibrary(app, "faro", expect: "2 libri, 2 risultati in tutto per «faro».")
        let first = item(app, "libreria.libro.0"), second = item(app, "libreria.libro.1")
        XCTAssertTrue(first.exists && second.exists, "un libro per riga")
        XCTAssertEqual(first.label, "Libro tastiera due, un risultato")
        XCTAssertEqual(second.label, "Libro tastiera uno, un risultato")
        XCTAssertTrue(summary.frame.minY < first.frame.minY && first.frame.minY < second.frame.minY,
                      "prima il riassunto, poi i libri in ordine")
        XCTAssertTrue(app.staticTexts["Nessun titolo o nome di file con «faro»"].exists, "la sezione dei titoli c'è e lo dice")
        first.tap()
        // Il libro si apre sulla sua lista dei risultati: «Cerca nel libro» con la ricerca già fatta.
        let count = app.staticTexts["ricerca.conteggio"]
        let listed = XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "label == %@", "Un risultato per «faro»."),
                                                      evaluatedWith: count)], timeout: 20)
        if listed != .completed { print("LISTA DEL LIBRO:\n\(app.debugDescription)") }
        XCTAssertEqual(listed, .completed, "la lista dei risultati del libro, con la ricerca già fatta")
        XCTAssertEqual(app.textFields["ricerca.campo"].value as? String, "faro")
        item(app, "ricerca.risultato.0").tap()
        XCTAssertTrue(app.navigationBars["Cerca nel libro"].waitForNonExistence(timeout: 8), "la lista si chiude")
        let hit = reading(app, "Il faro si accende sulla scogliera")
        XCTAssertTrue(hit.waitForExistence(timeout: 8), "la lettura è sul risultato")
        // La ricerca è attiva nella lettura: l'elemento dice quale risultato porta (il valore del rotore «Risultati della
        // ricerca»; la barra con le frecce senza VoiceOver non è nell'albero dei test).
        let value = XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "value == %@", "risultato 1 di 1"), evaluatedWith: hit)],
                                   timeout: 8)
        XCTAssertEqual(value, .completed, "la ricerca è attiva nella lettura: «\(hit.value as? String ?? "-")»")
        sleep(1)
        app.typeKey(".", modifierFlags: .command)   // Esc nel lettore: «Indietro»
        XCTAssertTrue(app.waitForScreen("Ricerca", timeout: 10), "si torna alla Ricerca")
        XCTAssertTrue(item(app, "libreria.riassunto").label.contains("2 libri, 2 risultati"), "con i risultati di prima")
    }

    /// I titoli e i nomi dei file restano trovabili come prima, mentre si scrive.
    func testLibrary_titlesAreStillFoundWhileTyping() throws {
        let app = launch()
        XCTAssertTrue(app.tapTab("Ricerca"))
        XCTAssertTrue(app.waitForScreen("Ricerca"))
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        app.typeText("tastiera uno")
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Libro tastiera uno")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "il titolo si trova mentre si scrive")
        XCTAssertTrue(item(app, "libreria.cercaNelTesto").exists, "e la riga per cercarlo anche nel testo")
    }

    func testLibrary_accessibilityAudit_ofTheResults() throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("performAccessibilityAudit richiede iOS 17+") }
        let app = launch()
        searchLibrary(app, "libro", expect: "2 libri")
        app.typeKey(XCUIKeyboardKey.shift, modifierFlags: [])
        sleep(1)
        let rule = SystemAuditRule(app: app, screen: "Ricerca nel testo dei libri")
        try app.performAccessibilityAudit { issue in
            // Lo stesso falso positivo documentato della barra di ricerca di sistema (AccessibilityAuditUITests).
            if issue.auditType == .textClipped, issue.element?.elementType == .searchField { return true }
            if rule.accept(issue) { return true }
            print("AUDIT RICERCA NEL TESTO RILIEVO: \(issue.compactDescription) — \(issue.detailedDescription) — «\(issue.element?.label ?? "?")»")
            return false
        }
    }

    // MARK: - Esc come «Annulla» o «Chiudi»

    /// Sopra il lettore: le finestre «Aggiungi segnalibro» e «Aggiungi sottolineatura» (dagli strumenti dell'elemento, ⌘E)
    /// si chiudono con Esc come con «Annulla», e il libro resta aperto (la barra con «Segnalibri» senza VoiceOver non è
    /// nell'albero dei test: la finestra dei Segnalibri la provano le prove d'unità, `LibrarySearchAppTests`).
    func testEscape_closesTheWindowsOverTheReader_andNeverTheBookBelow() throws {
        let app = launch()
        let book = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Libro tastiera due")).firstMatch
        XCTAssertTrue(book.waitForExistence(timeout: 10))
        book.tap()
        XCTAssertTrue(reading(app, "Capitolo primo del libro due").waitForExistence(timeout: 20), "il libro è aperto")
        sleep(1)
        app.typeKey(XCUIKeyboardKey.shift, modifierFlags: [])
        for action in ["Aggiungi segnalibro", "Aggiungi sottolineatura"] {
            app.typeKey("e", modifierFlags: .command)
            let choice = app.buttons[action]
            XCTAssertTrue(choice.waitForExistence(timeout: 8), "gli strumenti dell'elemento offrono «\(action)»")
            choice.tap()
            let cancel = app.navigationBars.buttons["Annulla"]
            XCTAssertTrue(cancel.waitForExistence(timeout: 8), "«\(action)»: la finestra con «Annulla»")
            sleep(1)
            app.typeKey(".", modifierFlags: .command)   // Esc
            XCTAssertTrue(cancel.waitForNonExistence(timeout: 8), "«\(action)»: Esc fa «Annulla»")
            sleep(1)
            XCTAssertTrue(reading(app, "Capitolo primo del libro due").exists, "«\(action)»: il libro sotto è ancora aperto")
            XCTAssertFalse(app.waitForScreen("ScaboPDF", timeout: 1), "«\(action)»: non si è tornati alla Home")
        }
    }

    /// Sopra la Home (qui dal tab Ricerca): il menù Opzioni si chiude con Esc senza scegliere nulla; il Referto si chiude
    /// con Esc come con «Chiudi»; la schermata sotto resta.
    func testEscape_closesTheOptionsAndTheReport_overTheSearchTab() throws {
        let app = launch()
        XCTAssertTrue(app.tapTab("Ricerca"))
        XCTAssertTrue(app.waitForScreen("Ricerca"))
        let options = app.buttons.matching(NSPredicate(format: "label == %@", "Opzioni")).firstMatch
        XCTAssertTrue(options.waitForExistence(timeout: 5))
        options.tap()
        let reportAction = app.buttons["Referto di elaborazione"]
        XCTAssertTrue(reportAction.waitForExistence(timeout: 5), "il menù Opzioni")
        sleep(1)
        app.typeKey(".", modifierFlags: .command)   // Esc sul menù: lo chiude, nessuna scelta
        XCTAssertTrue(reportAction.waitForNonExistence(timeout: 5), "Esc chiude il menù")
        XCTAssertTrue(app.waitForScreen("Ricerca", timeout: 5), "la Ricerca resta")
        options.tap()
        XCTAssertTrue(reportAction.waitForExistence(timeout: 5))
        reportAction.tap()
        let report = app.navigationBars["Referto di elaborazione"]
        XCTAssertTrue(report.waitForExistence(timeout: 8), "il Referto")
        sleep(1)
        app.typeKey(".", modifierFlags: .command)   // Esc
        XCTAssertTrue(report.waitForNonExistence(timeout: 8), "Esc fa «Chiudi»")
        XCTAssertTrue(app.waitForScreen("Ricerca", timeout: 5), "la Ricerca resta")
    }

    // MARK: - Con VoiceOver vero (iOS 27)

    /// Dopo «Cerca» VoiceOver dice prima quanti libri e quanti risultati in tutto, poi ogni libro col titolo e il numero
    /// dei risultati; il doppio tap su un libro apre la sua lista, e VoiceOver dice subito il conteggio del libro.
    func testVoiceOver_summaryFirst_thenEachBook_thenTheBookList() throws {
        guard #available(iOS 27.0, *) else { throw XCTSkip("il servizio VoiceOver dei test c'è da iOS 27") }
        let app = launch()
        XCTAssertTrue(app.tapTab("Ricerca"))
        XCTAssertTrue(app.waitForScreen("Ricerca"))
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        sleep(1)
        app.typeText("faro")
        let vo = XCUIDevice.shared.voiceOverService
        try vo.enable()
        defer {
            try? vo.disable()
            let deadline = Date().addingTimeInterval(10)
            while vo.isEnabled, Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.25)) }
        }
        sleep(2)
        app.typeKey("\n", modifierFlags: [])
        sleep(3)
        let summary = (try? vo.currentSpeech())?.utterance ?? ""
        print("VOCE|libreria|dopo la ricerca|\(summary)")
        XCTAssertTrue(summary.hasPrefix("2 libri, 2 risultati in tutto per «faro»."), "prima quanti libri e quanti risultati: «\(summary)»")
        let first = (try? vo.moveForward())?.utterance ?? ""
        let second = (try? vo.moveForward())?.utterance ?? ""
        print("VOCE|libreria|libri|\(first) | \(second)")
        XCTAssertTrue(first.hasPrefix("Libro tastiera due, un risultato"), "poi ogni libro: «\(first)»")
        XCTAssertTrue(second.hasPrefix("Libro tastiera uno, un risultato"), "in ordine: «\(second)»")
        item(app, "libreria.libro.0").doubleTap()
        XCTAssertTrue(app.staticTexts["ricerca.conteggio"].waitForExistence(timeout: 20), "la lista del libro")
        sleep(3)
        let list = (try? vo.currentSpeech())?.utterance ?? ""
        print("VOCE|libreria|lista del libro|\(list)")
        XCTAssertTrue(list.hasPrefix("Un risultato per «faro»."), "nella lista del libro il conteggio detto subito: «\(list)»")
        let attachment = XCTAttachment(string: [summary, first, second, list].joined(separator: "\n"))
        attachment.name = "voiceover-libreria"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
