//
//  KeyboardUITests.swift
//  ScaboAppUITests
//
//  La TASTIERA (WCAG 2.1.1 Keyboard e 2.1.2 No Keyboard Trap, livello A; giro «accessibilità e completamento»,
//  2026-10-18), provata con la tastiera hardware del simulatore dentro XCTest (`typeKey`). Seme `-uiTestSeedKeyboardBooks`:
//  due libri con titoli, un richiamo e la sua nota lunga letta a fine sezione, trenta paragrafi più in là; il primo libro si
//  riapre sulla nota (testo inventato).
//
//  Che cosa si prova: i tasti arrivano al lettore (⌘E apre gli strumenti dell'elemento) ed Esc chiude la lettura; ⌘J porta
//  dalla nota al testo del richiamo e ritorno; con la tastiera italiana ⌘+ ingrandisce e ⌘- rimpicciolisce il testo; nello
//  split screen (iPad) i comandi di lettura valgono per la metà che comanda, ⌥⌘← e ⌥⌘→ scelgono la metà, Esc chiede se
//  chiudere la metà, nella domanda Esc annulla e A capo chiude, e dallo split si torna alla Home con la sola tastiera.
//
//  Due cose imparate misurando (registro dell'app, iPad iOS 27): `typeKey` manda il tasto nella posizione della tastiera
//  americana e il simulatore in italiano lo legge con la disposizione italiana («=» diventa «ì», «]» diventa «+», «/»
//  diventa «-»; lettere, frecce e A capo restano uguali); il tasto Esc non arriva all'app e si prova con Comando-punto, che
//  il sistema consegna come Esc, e A capo con «\n»; con VoiceOver acceso, nel simulatore i comandi col Comando
//  non scattano (la lettera arriva senza il modificatore riconosciuto), quindi qui si prova senza VoiceOver e il punto
//  d'arrivo si legge dalla posizione degli elementi sullo schermo.
//

import XCTest

final class KeyboardUITests: XCTestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
        try voiceOverOff()
    }

    override func tearDownWithError() throws {
        try voiceOverOff()
        try super.tearDownWithError()
    }

    /// VoiceOver spento prima e dopo ogni test: con VoiceOver acceso un tocco seleziona e non attiva, e un test che lo
    /// lasciasse acceso farebbe cadere il seguente al primo tocco.
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
        warmUp(app)
        return app
    }

    /// Un tasto innocuo (Maiuscole da solo): nel simulatore il primo tasto dopo l'avvio a volte non arriva all'app (campo:
    /// ⌘] sintetizzato da XCTest e assente dal registro dell'app; nella corsa prima, arrivato).
    private func warmUp(_ app: XCUIApplication) {
        app.typeKey(XCUIKeyboardKey.shift, modifierFlags: [])
        sleep(1)
    }

    /// Esc. XCTest nel simulatore non fa arrivare all'app il tasto Esc (`XCUIKeyboardKey.escape` sintetizzato, nessuna
    /// pressione nel registro dell'app; nemmeno il carattere di escape); Comando-punto sì, e il sistema lo consegna come
    /// `UIKeyInputEscape`, lo stesso ingresso del tasto Esc (campo, registro dell'app, iPad iOS 27): si prova con quello.
    private func escape(_ app: XCUIApplication) {
        app.typeKey(".", modifierFlags: .command)
    }

    /// A capo. Come per Esc: `XCUIKeyboardKey.return` e «\r» non arrivano all'app, «\n» sì, come A capo (campo, registro
    /// dell'app, iPad iOS 27).
    private func enter(_ app: XCUIApplication) {
        app.typeKey("\n", modifierFlags: [])
    }

    /// Un elemento di lettura che contiene `text`.
    private func reading(_ app: XCUIApplication, _ text: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    /// Vero se l'elemento è in vista nella parte alta della schermata (dove la lettura porta l'elemento raggiunto).
    private func isNearTheTop(_ app: XCUIApplication, _ element: XCUIElement) -> Bool {
        element.exists && element.frame.minY < app.frame.height * 0.4
    }

    private func open(_ app: XCUIApplication, _ title: String, showing text: String) {
        let book = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
        XCTAssertTrue(book.waitForExistence(timeout: 10), "«\(title)» fra i recenti")
        book.tap()
        let opened = reading(app, text).waitForExistence(timeout: 20)
        if !opened { print("GERARCHIA dopo l'apertura di «\(title)»:\n\(app.debugDescription)") }
        XCTAssertTrue(opened, "il libro è aperto")
        sleep(1)   // il lettore diventa destinatario dei tasti quando è comparso
        warmUp(app)
    }

    /// Sceglie `title` nel foglio «Aggiungi un file» dello split: le righe della Home, dietro il foglio, hanno lo stesso
    /// testo e non vanno toccate (la riga si cerca dentro la larghezza del foglio, data dalla sua barra).
    private func choose(_ app: XCUIApplication, _ title: String) {
        let bar = app.navigationBars["Aggiungi un file"]
        XCTAssertTrue(bar.waitForExistence(timeout: 10), "la scelta del file è aperta")
        sleep(1)
        let sheet = bar.frame
        let row = app.cells.allElementsBoundByIndex.first { cell in
            cell.frame.minX >= sheet.minX - 1 && cell.frame.maxX <= sheet.maxX + 1 && cell.staticTexts[title].exists
        }
        if row == nil { print("GERARCHIA della scelta:\n\(app.debugDescription)") }
        XCTAssertNotNil(row, "«\(title)» nella scelta")
        row?.tap()
        sleep(2)   // il foglio si chiude; dopo il primo libro se ne apre un altro con lo stesso titolo
    }

    // MARK: - Lettore a schermo intero

    /// Nel lettore Esc chiude la lettura: dalla lettura si esce con la sola tastiera.
    func testReader_escapeReturnsHome() throws {
        let app = launch()
        open(app, "Libro tastiera due", showing: "Capitolo primo del libro due")
        escape(app)
        XCTAssertTrue(app.waitForScreen("ScaboPDF", timeout: 10), "Esc torna alla Home")
    }

    /// ⌘E apre gli strumenti dell'elemento come finestra di dialogo, e lì Esc è «Annulla»: nessuna trappola.
    func testReader_commandE_opensTheTools_andEscapeCancels() throws {
        let app = launch()
        open(app, "Libro tastiera due", showing: "Capitolo primo del libro due")
        app.typeKey("e", modifierFlags: .command)
        let tools = app.alerts["Strumenti elemento"]
        let shown = tools.waitForExistence(timeout: 5)
        if !shown { print("GERARCHIA dopo ⌘E:\n\(app.debugDescription)") }
        XCTAssertTrue(shown, "⌘E apre gli strumenti dell'elemento")
        XCTAssertTrue(tools.buttons["Aggiungi segnalibro"].exists)
        XCTAssertTrue(tools.buttons["Annulla"].exists)
        escape(app)
        XCTAssertTrue(tools.waitForNonExistence(timeout: 5), "Esc chiude gli strumenti")
        XCTAssertTrue(reading(app, "Capitolo primo del libro due").exists, "si resta nella lettura")
    }

    /// Esc dato subito dopo ⌘E, prima che la finestra degli strumenti prenda i tasti, chiude solo la finestra: la lettura
    /// resta. Prima della cura, sull'iPad iOS 26.5, quell'Esc arrivava al lettore come «Indietro» (campo, 2 corse su 3).
    func testReader_escapeRightAfterCommandE_closesOnlyTheTools() throws {
        let app = launch()
        open(app, "Libro tastiera due", showing: "Capitolo primo del libro due")
        app.typeKey("e", modifierFlags: .command)
        escape(app)
        let tools = app.alerts["Strumenti elemento"]
        XCTAssertTrue(tools.waitForNonExistence(timeout: 5), "la finestra degli strumenti è chiusa")
        let stayed = reading(app, "Capitolo primo del libro due").waitForExistence(timeout: 5)
        if !stayed { print("GERARCHIA dopo ⌘E ed Esc di seguito:\n\(app.debugDescription)") }
        XCTAssertTrue(stayed, "si resta nella lettura")
    }

    /// ⌘J: il libro si riapre sulla nota, lontana dal richiamo; ⌘J porta il testo del richiamo in cima, ⌘J riporta la nota.
    func testReader_commandJ_jumpsBetweenNoteAndCall() throws {
        let app = launch()
        open(app, "Libro tastiera uno", showing: "Una nota di prova lunga")
        let note = reading(app, "Una nota di prova lunga")
        let call = reading(app, "Nel libro uno si racconta")
        sleep(1)
        print("TASTI|apertura: nota \(note.exists ? "\(note.frame)" : "assente"), richiamo \(call.exists ? "\(call.frame)" : "assente"), schermo \(app.frame)")
        XCTAssertTrue(isNearTheTop(app, note), "la lettura si riapre sulla nota")
        XCTAssertFalse(isNearTheTop(app, call), "il richiamo è lontano dalla nota")
        app.typeKey("j", modifierFlags: .command)
        XCTAssertTrue(call.waitForExistence(timeout: 5) && isNearTheTop(app, call), "⌘J porta al testo del richiamo")
        XCTAssertFalse(isNearTheTop(app, note), "la nota non è più in cima")
        app.typeKey("j", modifierFlags: .command)
        XCTAssertTrue(note.waitForExistence(timeout: 5) && isNearTheTop(app, note), "⌘J dal richiamo torna alla nota")
    }

    /// Con la tastiera italiana (la disposizione del simulatore in italiano) ⌘+ ingrandisce e ⌘- rimpicciolisce il testo:
    /// il «+» italiano è un tasto a sé (l'«=» del comando principale lì è Maiuscole+0, che il sistema non riconosce).
    func testReader_textSizeKeys_workOnAnItalianKeyboard() throws {
        guard Locale.preferredLanguages.first?.hasPrefix("it") == true else {
            throw XCTSkip("la prova è per la disposizione italiana della tastiera (simulatore in italiano)")
        }
        let app = launch()
        open(app, "Libro tastiera due", showing: "Capitolo primo del libro due")
        let heading = reading(app, "Capitolo primo del libro due")
        let before = heading.frame.height
        app.typeKey("]", modifierFlags: .command)     // il «+» della tastiera italiana
        sleep(2)
        let larger = heading.frame.height
        app.typeKey("/", modifierFlags: .command)     // il «-» della tastiera italiana
        sleep(2)
        let back = heading.frame.height
        print("TASTI|altezza del titolo \(before), dopo ⌘+ \(larger), dopo ⌘- \(back)")
        XCTAssertGreaterThan(larger, before, "⌘+ ingrandisce il testo")
        XCTAssertLessThan(back, larger, "⌘- rimpicciolisce il testo")
    }

    // MARK: - Split screen (solo iPad)

    /// Comandi alla metà che comanda, scelta della metà, Esc e la domanda, uscita da tastiera.
    func testSplit_keyboardCommandsFollowTheCommandingHalf_andThereIsNoTrap() throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else { throw XCTSkip("lo split screen è solo dell'iPad (§ 11.1)") }
        let app = launch()
        app.buttons["Affianca due documenti"].firstMatch.tap()
        for title in ["Libro tastiera uno", "Libro tastiera due"] { choose(app, title) }
        // all'ingresso è esposto solo il testo della metà sinistra (i contenitori sono sigillati, § 2.3)
        let opened = reading(app, "del libro uno").waitForExistence(timeout: 20)
        if !opened { print("GERARCHIA dello split:\n\(app.debugDescription)") }
        XCTAssertTrue(opened, "lo split è aperto, con la metà sinistra")
        sleep(1)
        // ⌥⌘←: comanda la sinistra; ⌥↓: il titolo seguente della metà sinistra va in cima
        app.typeKey(XCUIKeyboardKey.leftArrow, modifierFlags: [.command, .alternate])
        sleep(1)
        app.typeKey(XCUIKeyboardKey.downArrow, modifierFlags: .alternate)
        let left = reading(app, "Sezione seconda del libro uno")
        XCTAssertTrue(left.waitForExistence(timeout: 5) && isNearTheTop(app, left),
                      "il comando di lettura vale per la metà sinistra")
        // ⌥⌘→: comanda la destra (ora è esposto il suo testo); ⌥↓ vale per lei
        app.typeKey(XCUIKeyboardKey.rightArrow, modifierFlags: [.command, .alternate])
        XCTAssertTrue(reading(app, "Capitolo primo del libro due").waitForExistence(timeout: 5),
                      "⌥⌘→ porta alla metà destra")
        app.typeKey(XCUIKeyboardKey.downArrow, modifierFlags: .alternate)
        let right = reading(app, "Sezione seconda del libro due")
        XCTAssertTrue(right.waitForExistence(timeout: 5) && isNearTheTop(app, right),
                      "dopo ⌥⌘→ il comando di lettura vale per la metà destra")
        // Esc chiede se chiudere la metà che comanda; nella domanda Esc annulla
        escape(app)
        let question = app.alerts.firstMatch
        XCTAssertTrue(question.waitForExistence(timeout: 5), "Esc chiede se chiudere la metà che comanda")
        XCTAssertTrue(question.staticTexts["Chiudi metà destra"].exists, "la domanda è sulla metà destra, quella che comanda")
        sleep(1)
        escape(app)
        XCTAssertTrue(question.waitForNonExistence(timeout: 5), "nella domanda Esc annulla")
        sleep(1)
        // di nuovo Esc, e A capo chiude la metà: la metà che resta torna a schermo intero, poi Esc alla Home
        escape(app)
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5), "dopo «Annulla» lo split riceve di nuovo i tasti")
        sleep(1)   // la finestra della domanda finisce di comparire e riceve i tasti
        enter(app)
        XCTAssertTrue(app.alerts.firstMatch.waitForNonExistence(timeout: 5), "A capo chiude la metà")
        XCTAssertTrue(reading(app, "libro uno").waitForExistence(timeout: 20), "la metà che resta torna a schermo intero")
        sleep(2)
        escape(app)
        XCTAssertTrue(app.waitForScreen("ScaboPDF", timeout: 15), "dallo split alla Home con la sola tastiera")
    }
}
