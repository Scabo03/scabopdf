//
//  ReprocessOfferUITests.swift
//  ScaboAppUITests
//
//  L'offerta di rielaborazione e l'avviso delle orfane (giro «ancore», docs/ANCORE_ANNOTAZIONI.md § 5):
//  percorso completo da VoiceOver-utente, con l'audit di accessibilità su ogni schermata nuova.
//  Seme DEBUG `-uiTestSeedReprocess`: un libro sintetico «vecchio» con un segnalibro senza ancora.
//

import XCTest

final class ReprocessOfferUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launchSeeded() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestSeedReprocess"]
        app.launch()
        return app
    }

    private func element(_ app: XCUIApplication, containing text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    /// Apre l'offerta, la rifiuta al secondo gesto, la accetta, verifica l'esito e torna alla lettura precedente.
    func testOffer_isTwoStep_resultDeclaresOrphans_andRevertRestores() throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("performAccessibilityAudit richiede iOS 17+") }
        let app = launchSeeded()

        let row = app.cells["home.offer"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "la Home offre la lettura migliore")
        audit(app, screen: "Home con l'offerta")
        row.tap()

        let book = app.cells.containing(NSPredicate(format: "label CONTAINS %@", "Libro di prova")).firstMatch
        XCTAssertTrue(book.waitForExistence(timeout: 5))
        audit(app, screen: "Elenco della lettura migliore")
        book.tap()

        let accept = app.buttons["offer.accept"]
        let offerShown = accept.waitForExistence(timeout: 10)
        if !offerShown { print("GERARCHIA senza l'offerta:\n\(app.debugDescription)") }
        XCTAssertTrue(offerShown, "l'offerta compare")
        XCTAssertTrue(app.staticTexts["offer.what"].exists)
        XCTAssertTrue(app.staticTexts["offer.time"].exists)
        XCTAssertTrue(app.staticTexts["offer.annotations"].exists)
        audit(app, screen: "Offerta di rielaborazione")

        // Primo gesto: «Rielabora…» apre la conferma; «Annulla» (primo e in evidenza) non fa partire nulla.
        accept.tap()
        let cancel = app.buttons["confirm.reprocess.cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        audit(app, screen: "Conferma della rielaborazione")
        cancel.tap()
        XCTAssertTrue(accept.waitForExistence(timeout: 5), "annullare lascia l'offerta aperta, nulla è partito")
        XCTAssertFalse(app.staticTexts["Rielaborazione conclusa"].exists)

        // Secondo gesto, voluto: parte.
        accept.tap()
        XCTAssertTrue(app.buttons["confirm.reprocess.ok"].waitForExistence(timeout: 5))
        app.buttons["confirm.reprocess.ok"].tap()

        let done = app.staticTexts["Rielaborazione conclusa"]
        XCTAssertTrue(done.waitForExistence(timeout: 120), "la rielaborazione si conclude")
        let text = app.staticTexts["result.text"]
        XCTAssertTrue(text.exists)
        XCTAssertTrue(text.label.contains("Da ricollocare: 1"), "il segnalibro senza ancora è dichiarato, non spostato: \(text.label)")
        audit(app, screen: "Esito della rielaborazione")

        // Torna alla lettura precedente: l'offerta ricompare (l'etichetta è tornata quella di prima).
        app.buttons["result.revert"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.cells["home.offer"].waitForExistence(timeout: 10))
    }

    /// Dopo aver tenuto la nuova lettura, il segnalibro orfano è dichiarato «da ricollocare» nella vista
    /// globale dei segnalibri per tag (raggiungibile dalla Home; il pannello del lettore è un contenitore
    /// chiuso che XCUI non apre senza i gesti di VoiceOver: la finestra del lettore ha il suo test unitario).
    func testOrphanBookmark_isDeclaredInTheGlobalBookmarksView() throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("performAccessibilityAudit richiede iOS 17+") }
        let app = launchSeeded()
        XCTAssertTrue(app.cells["home.offer"].waitForExistence(timeout: 10))
        app.cells["home.offer"].tap()
        app.cells.containing(NSPredicate(format: "label CONTAINS %@", "Libro di prova")).firstMatch.tap()
        let offerShown = app.buttons["offer.accept"].waitForExistence(timeout: 10)
        if !offerShown { print("GERARCHIA senza l'offerta (segnalibro orfano):\n\(app.debugDescription)") }
        XCTAssertTrue(offerShown, "l'offerta compare")
        app.buttons["offer.accept"].tap()
        XCTAssertTrue(app.buttons["confirm.reprocess.ok"].waitForExistence(timeout: 5))
        app.buttons["confirm.reprocess.ok"].tap()
        XCTAssertTrue(app.staticTexts["Rielaborazione conclusa"].waitForExistence(timeout: 120))
        app.buttons["result.keep"].tap()
        // Secondo gesto anche qui: tenere la nuova lettura cancella quella di prima.
        let keep = app.buttons["confirm.keep.ok"]
        XCTAssertTrue(keep.waitForExistence(timeout: 5))
        audit(app, screen: "Conferma: tenere la nuova lettura")
        keep.tap()
        // Aspetta che conferma ed esito si siano chiusi (le animazioni hanno tempi diversi fra 26.5 e 27).
        let gone = NSPredicate(format: "exists == false")
        expectation(for: gone, evaluatedWith: app.staticTexts["Rielaborazione conclusa"])
        waitForExpectations(timeout: 10)
        let back = app.backButton(onScreen: "Lettura migliore")
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        back.tap()
        let tags = app.navigationBars.buttons["Tag"]
        XCTAssertTrue(tags.waitForExistence(timeout: 10), "di nuovo in Home")
        XCTAssertFalse(app.cells["home.offer"].exists, "tenuta la nuova lettura, l'offerta non c'è più")

        tags.tap()
        let tag = app.cells.containing(NSPredicate(format: "label CONTAINS %@", "Importante")).firstMatch
        XCTAssertTrue(tag.waitForExistence(timeout: 5))
        tag.tap()
        let orphan = element(app, containing: "da ricollocare")
        XCTAssertTrue(orphan.waitForExistence(timeout: 5), "il segnalibro non ritrovato è dichiarato")
        audit(app, screen: "Segnalibri per tag con un orfano")
    }

    /// I tre tipi di libro davanti all'offerta (giro «pulizia e rifinitura finale del capitolo note», 2026-10-17, decisione 1
    /// del maintainer): il PDF elaborato sull'iPad e il testo normativo importato prima dei pezzi nuovi delle note la
    /// ricevono, la lettura arrivata dal Mac no. Il testo normativo si rielabora davvero, con la catena dei testi normativi
    /// (con quella dei PDF fallirebbe), e si torna alla lettura precedente.
    func testThreeKindsOfBook_pdfAndNormativeTextReceiveTheOffer_macReadingDoesNot() throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("performAccessibilityAudit richiede iOS 17+") }
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestSeedReprocessKinds"]
        app.launch()

        let row = app.cells["home.offer"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "la Home offre la lettura migliore")
        row.tap()
        func cell(_ title: String) -> XCUIElement {
            app.cells.containing(NSPredicate(format: "label CONTAINS %@", title)).firstMatch
        }
        let akn = cell("Testo normativo di prova")
        XCTAssertTrue(akn.waitForExistence(timeout: 5), "il testo normativo importato prima dei pezzi nuovi riceve l'offerta")
        XCTAssertTrue(cell("Libro di prova").exists, "il PDF elaborato sull'iPad con una build vecchia la riceve")
        if cell("Lettura dal Mac di prova").exists { print("GERARCHIA dell'elenco con la lettura dal Mac:\n\(app.debugDescription)") }
        XCTAssertFalse(cell("Lettura dal Mac di prova").exists, "la lettura arrivata dal Mac no: la rifà il Mac aggiornato")
        audit(app, screen: "Elenco della lettura migliore con i tre tipi di libro")
        akn.tap()

        let what = app.staticTexts["offer.what"]
        XCTAssertTrue(what.waitForExistence(timeout: 5))
        XCTAssertTrue(what.label.contains("testo normativo"), what.label)
        XCTAssertFalse(what.label.contains("pagina"), "le cure dei soli PDF non si promettono a un testo normativo: \(what.label)")
        audit(app, screen: "Offerta per un testo normativo")
        app.buttons["offer.accept"].tap()
        XCTAssertTrue(app.buttons["confirm.reprocess.ok"].waitForExistence(timeout: 5))
        app.buttons["confirm.reprocess.ok"].tap()
        XCTAssertTrue(app.staticTexts["Rielaborazione conclusa"].waitForExistence(timeout: 120), "il testo normativo si rielabora")
        XCTAssertTrue(app.staticTexts["result.text"].exists)
        audit(app, screen: "Esito della rielaborazione di un testo normativo")

        // Torna alla lettura precedente: l'offerta per il testo normativo ricompare.
        app.buttons["result.revert"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.cells["home.offer"].waitForExistence(timeout: 10))
    }

    // MARK: - Audit (stesso criterio di AccessibilityAuditUITests)

    @available(iOS 17.0, *)
    private func audit(_ app: XCUIApplication, screen: String) {
        var report: [String] = []
        let systemRule = SystemAuditRule(app: app, screen: screen)
        do {
            try app.performAccessibilityAudit { issue in
                let el = issue.element
                if issue.auditType == .textClipped, el?.elementType == .searchField { return true }
                // Rilievi del SISTEMA sull'iPad (barra delle schede galleggiante, testo attorno a un foglio): vedi
                // `SystemAuditRule`, accettati con condizioni e tetti e stampati; ogni altro rilievo fa fallire.
                if systemRule.accept(issue) { return true }
                print("AUDIT «\(screen)» RILIEVO: \(issue.compactDescription) — \(issue.detailedDescription) — «\(el?.label ?? "?")» "
                      + "frame:\(el.map { "\($0.frame)" } ?? "?")")
                if report.isEmpty { print("AUDIT gerarchia:\n\(app.debugDescription)") }
                report.append("• [\(issue.auditType.rawValue)] \(issue.compactDescription) — «\(el?.label ?? "?")» type:\(el.map { "\($0.elementType.rawValue)" } ?? "?")")
                return false
            }
        } catch {
            // L'audit lancia quando un rilievo non è gestito (già nel resoconto); se il resoconto è vuoto, il
            // lancio è un errore dell'audit stesso: non deve passare in silenzio.
            if report.isEmpty { XCTFail("Audit su «\(screen)» non eseguito: \(error)") }
        }
        XCTAssertTrue(report.isEmpty, "Audit accessibilità FALLITO su «\(screen)» (\(report.count)):\n" + report.joined(separator: "\n"))
    }
}

// MARK: - La granularità delle Impostazioni (giro «prove rifatte e granularità», 2026-11-10)

/// La granularità scelta nelle Impostazioni entra nell'elaborazione anche sull'iPad (LAYER2 § 7.7). Seme
/// `-uiTestSeedKeyboardBooks`: due libri già elaborati a 400, con una cache dal testo suo (inventato) e in archivio il PDF
/// sintetico, dal testo diverso. Così il contenuto dice da dove viene la lettura: il testo della cache seminata vuol dire
/// «aperto dalla cache, nessuna rielaborazione»; il testo del PDF vuol dire «rielaborato dalla sorgente»; e la lunghezza del
/// primo blocco dice a quale granularità. (La schermata d'elaborazione del PDF sintetico dura troppo poco perché XCTest, che
/// dopo il tocco aspetta l'app ferma, la veda: campo, iPad iOS 27; non si usa.) Le Impostazioni tornano al predefinito.
final class GranularityUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestSeedKeyboardBooks"]
        app.launch()
        XCTAssertTrue(app.waitForScreen("ScaboPDF", timeout: 30), "la Home compare")
        return app
    }

    private func scegli(_ app: XCUIApplication, _ livello: String) {
        XCTAssertTrue(app.tapTab("Impostazioni"), "scheda Impostazioni")
        XCTAssertTrue(app.waitForScreen("Impostazioni"))
        let riga = app.cells.staticTexts[livello].firstMatch
        for _ in 0..<6 where !(riga.exists && riga.isHittable) { app.swipeUp() }
        XCTAssertTrue(riga.waitForExistence(timeout: 10), "«\(livello)» fra le Impostazioni")
        riga.tap()
        XCTAssertTrue(app.tapTab("Home"), "scheda Home")
    }

    /// Apre il libro, aspetta che la lettura mostri `testo` (anche dopo un'elaborazione), restituisce l'etichetta del primo
    /// elemento che lo contiene (il primo blocco di lettura) e torna alla Home.
    private func apri(_ app: XCUIApplication, _ titolo: String, mostrando testo: String) -> String {
        let libro = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", titolo)).firstMatch
        XCTAssertTrue(libro.waitForExistence(timeout: 10), "«\(titolo)» fra i recenti")
        libro.tap()
        let lettura = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", testo)).firstMatch
        let aperto = lettura.waitForExistence(timeout: 120)
        if !aperto { print("GERARCHIA dopo l'apertura di «\(titolo)»:\n\(app.debugDescription)") }
        XCTAssertTrue(aperto, "il libro è aperto e la lettura mostra «\(testo)»")
        let blocco = lettura.label
        sleep(1)   // il lettore diventa destinatario dei tasti quando è comparso
        // Esc (Comando-punto, KeyboardUITests) chiude la lettura; un tasto innocuo prima, perché nel simulatore il primo tasto
        // a volte non arriva, e un secondo Esc se la Home non torna.
        app.typeKey(XCUIKeyboardKey.shift, modifierFlags: [])
        app.typeKey(".", modifierFlags: .command)
        if !libro.waitForExistence(timeout: 5) { app.typeKey(".", modifierFlags: .command) }
        XCTAssertTrue(libro.waitForExistence(timeout: 15), "di nuovo sulla Home")
        return blocco
    }

    /// Al predefinito si legge la cache seminata (a 400): nessuna rielaborazione.
    func testDefaultGranularity_opensFromTheCache() throws {
        let app = launch()
        scegli(app, "Fine — 400 caratteri")
        _ = apri(app, "Libro tastiera due", mostrando: "Capitolo primo del libro due")
    }

    /// A un'altra granularità il libro si rielabora dalla sorgente alla prossima apertura, coi blocchi di quella granularità,
    /// e dalla volta dopo si riapre uguale; tornando al predefinito i blocchi tornano più corti.
    func testOtherGranularity_reprocessesWithItsBlocks_andBack() throws {
        let app = launch()
        scegli(app, "Fine — 400 caratteri")
        scegli(app, "Ampia — 900 caratteri")
        let primo900 = apri(app, "Libro tastiera due", mostrando: "Il primo capitolo racconta")
        let secondo900 = apri(app, "Libro tastiera due", mostrando: "Il primo capitolo racconta")
        XCTAssertEqual(secondo900, primo900, "riaperto a 900: la stessa lettura")
        scegli(app, "Fine — 400 caratteri")
        let primo400 = apri(app, "Libro tastiera due", mostrando: "Il primo capitolo racconta")
        let secondo400 = apri(app, "Libro tastiera due", mostrando: "Il primo capitolo racconta")
        XCTAssertEqual(secondo400, primo400, "riaperto a 400: la stessa lettura")
        XCTAssertLessThan(primo400.count, primo900.count, "a 400 il primo blocco è più corto che a 900")
        print("GRANULARITA primo blocco: 900 → \(primo900.count) caratteri, 400 → \(primo400.count) caratteri")
    }
}
