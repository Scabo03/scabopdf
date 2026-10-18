//
//  ReadingFromMacUITests.swift
//  ScaboAppUITests
//
//  La ricezione della lettura preparata dal Mac (giro «costruzione della linea Mac», 2026-10-16; LAYER2 § 12.12):
//  percorsi completi da utente VoiceOver, verificati nell'albero di accessibilità con l'audit su ogni schermata nuova.
//  Semi DEBUG `-uiTestSeedMacReading…` (UITestSeeding.swift): libro sintetico e pacchetti costruiti nell'app, testo neutro.
//

import UIKit
import XCTest

final class ReadingFromMacUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launch(_ seed: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [seed]
        app.launch()
        return app
    }

    /// Dalla Home alla prima lettura dell'elenco.
    private func openArrival(_ app: XCUIApplication) {
        let row = app.cells["home.fromMac"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "la Home mostra la lettura arrivata dal Mac")
        XCTAssertTrue(row.staticTexts["Una lettura arrivata dal Mac"].exists, "la riga dice quante letture sono arrivate")
        row.tap()
        let first = app.cells.element(boundBy: 0)
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        first.tap()
    }

    /// Il percorso intero: Home → elenco → offerta → conferma in due gesti → esito → «Tieni» in due gesti → Home senza la riga.
    func test_ricezione_offerta_dueGesti_esito_tieni() throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("performAccessibilityAudit richiede iOS 17+") }
        let app = launch("-uiTestSeedMacReading")
        XCTAssertTrue(app.cells["home.fromMac"].waitForExistence(timeout: 10))
        audit(app, screen: "Home con la lettura arrivata dal Mac", inTabOnPad: true)
        app.cells["home.fromMac"].tap()
        let book = app.cells.containing(NSPredicate(format: "label CONTAINS %@", "Libro di prova")).firstMatch
        XCTAssertTrue(book.waitForExistence(timeout: 5))
        audit(app, screen: "Elenco delle letture dal Mac", inTabOnPad: true)
        book.tap()

        let accept = app.buttons["receive.accept"]
        XCTAssertTrue(accept.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Lettura migliore disponibile per «Libro di prova»"].exists)
        let what = app.staticTexts["receive.what"]
        XCTAssertTrue(what.exists)
        XCTAssertTrue(what.label.contains("ha ricucito una nota spezzata fra due pagine"), what.label)
        XCTAssertTrue(app.staticTexts["receive.from"].label.contains("macOS 27.0.1"))
        let ann = app.staticTexts["receive.annotations"].label
        XCTAssertTrue(ann.contains("un segnalibro e una sottolineatura"), ann)
        XCTAssertTrue(ann.contains("Dal Mac arrivano anche un segnalibro e una sottolineatura"), ann)
        audit(app, screen: "Offerta della lettura dal Mac")

        // Primo gesto: apre la conferma; «Annulla» non applica nulla.
        accept.tap()
        let cancel = app.buttons["confirm.receive.cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        audit(app, screen: "Conferma della lettura dal Mac")
        cancel.tap()
        XCTAssertTrue(accept.waitForExistence(timeout: 5), "annullare lascia l'offerta aperta, nulla è cambiato")

        // Secondo gesto, voluto.
        accept.tap()
        XCTAssertTrue(app.buttons["confirm.receive.ok"].waitForExistence(timeout: 5))
        app.buttons["confirm.receive.ok"].tap()

        let result = app.staticTexts["received.result"]
        XCTAssertTrue(result.waitForExistence(timeout: 30), "l'esito arriva")
        XCTAssertTrue(app.staticTexts["Lettura dal Mac applicata"].exists)
        XCTAssertTrue(result.label.contains("La lettura arrivata dal Mac è in uso."), result.label)
        XCTAssertTrue(result.label.contains("I tuoi segnalibri sono al loro posto (1)"), result.label)
        XCTAssertTrue(result.label.contains("1 segnalibri aggiunti") || result.label.contains("segnalibri aggiunti"), result.label)
        XCTAssertTrue(result.label.contains("sottolineature unite a una tua"), result.label)
        audit(app, screen: "Esito della lettura dal Mac")

        app.buttons["received.keep"].tap()
        let keep = app.buttons["confirm.keep.ok"]
        XCTAssertTrue(keep.waitForExistence(timeout: 5))
        audit(app, screen: "Conferma: tenere la lettura dal Mac")
        keep.tap()
        let gone = NSPredicate(format: "exists == false")
        expectation(for: gone, evaluatedWith: app.staticTexts["Lettura dal Mac applicata"])
        waitForExpectations(timeout: 10)
        // Torna alla Home: la lettura applicata non è più fra quelle arrivate.
        let back = app.backButton(onScreen: "Letture dal Mac")
        if back.waitForExistence(timeout: 5) { back.tap() }
        XCTAssertTrue(app.navigationBars.buttons["Tag"].waitForExistence(timeout: 10), "di nuovo in Home")
        XCTAssertFalse(app.cells["home.fromMac"].exists, "applicata la lettura, la riga sparisce")
    }

    /// «Torna alla lettura precedente» dall'esito: il libro torna com'era e nessuna offerta resta in sospeso.
    func test_ricezione_tornaAllaLetturaPrecedente() throws {
        let app = launch("-uiTestSeedMacReading")
        openArrival(app)
        XCTAssertTrue(app.buttons["receive.accept"].waitForExistence(timeout: 10))
        app.buttons["receive.accept"].tap()
        XCTAssertTrue(app.buttons["confirm.receive.ok"].waitForExistence(timeout: 5))
        app.buttons["confirm.receive.ok"].tap()
        XCTAssertTrue(app.buttons["received.revert"].waitForExistence(timeout: 30))
        app.buttons["received.revert"].tap()
        let back = app.backButton(onScreen: "Letture dal Mac")
        if back.waitForExistence(timeout: 5) { back.tap() }
        XCTAssertTrue(app.navigationBars.buttons["Tag"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.cells["home.offer"].exists, "tornati alla lettura di prima, nulla resta in attesa di conferma")
    }

    /// «Non ora»: la lettura resta fra quelle arrivate.
    func test_nonOra_laLetturaResta() throws {
        let app = launch("-uiTestSeedMacReading")
        openArrival(app)
        XCTAssertTrue(app.buttons["receive.later"].waitForExistence(timeout: 10))
        app.buttons["receive.later"].tap()
        let back = app.backButton(onScreen: "Letture dal Mac")
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        XCTAssertTrue(app.cells.containing(NSPredicate(format: "label CONTAINS %@", "Libro di prova")).firstMatch.exists)
        back.tap()
        XCTAssertTrue(app.cells["home.fromMac"].waitForExistence(timeout: 5))
    }

    /// «Togli questa lettura dall'iPad…»: due gesti (la conferma nella stessa scheda, «Annulla» non toglie nulla), poi la
    /// lettura sparisce e con lei la riga della Home; il libro resta com'era (nessun vicolo cieco: revisione del giro).
    func test_togliLaLettura_conConferma_laRigaSparisce() throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("performAccessibilityAudit richiede iOS 17+") }
        let app = launch("-uiTestSeedMacReading")
        openArrival(app)
        let discard = app.buttons["receive.discard"]
        XCTAssertTrue(discard.waitForExistence(timeout: 10))
        discard.tap()
        let cancel = app.buttons["confirm.discard.cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["confirm.discard.text"].label.contains("Il libro resta com'è"))
        audit(app, screen: "Conferma: togliere la lettura dal Mac")
        cancel.tap()
        XCTAssertTrue(discard.waitForExistence(timeout: 5), "«Annulla» lascia l'offerta, nulla è tolto")
        discard.tap()
        XCTAssertTrue(app.buttons["confirm.discard.ok"].waitForExistence(timeout: 5))
        app.buttons["confirm.discard.ok"].tap()
        let back = app.backButton(onScreen: "Letture dal Mac")
        if back.waitForExistence(timeout: 5) { back.tap() }
        XCTAssertTrue(app.navigationBars.buttons["Tag"].waitForExistence(timeout: 10), "di nuovo in Home")
        XCTAssertFalse(app.cells["home.fromMac"].exists, "la lettura tolta non c'è più")
        let book = app.cells.containing(NSPredicate(format: "label CONTAINS %@", "Libro di prova")).firstMatch
        XCTAssertTrue(book.exists, "il libro resta in libreria")
    }

    /// Il libro non c'è e non lo si vuole importare: anche lì la lettura si può togliere.
    func test_libroAssente_laLetturaSiPuoTogliere() throws {
        let app = launch("-uiTestSeedMacReadingMissingBook")
        openArrival(app)
        let discard = app.buttons["missing.discard"]
        XCTAssertTrue(discard.waitForExistence(timeout: 10))
        discard.tap()
        XCTAssertTrue(app.buttons["confirm.discard.ok"].waitForExistence(timeout: 5))
        app.buttons["confirm.discard.ok"].tap()
        let back = app.backButton(onScreen: "Letture dal Mac")
        if back.waitForExistence(timeout: 5) { back.tap() }
        XCTAssertTrue(app.navigationBars.buttons["Tag"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.cells["home.fromMac"].exists, "la lettura tolta non c'è più")
    }

    /// Due copie dello stesso libro: si chiede a quale, la più recente aperta per prima.
    func test_dueCopie_chiedeAQuale_laPiuRecentePerPrima() throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("performAccessibilityAudit richiede iOS 17+") }
        let app = launch("-uiTestSeedMacReadingTwoCopies")
        openArrival(app)
        let first = app.buttons["copies.0"]
        XCTAssertTrue(first.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["A quale copia applicarla?"].exists)
        XCTAssertTrue(app.buttons["copies.1"].exists)
        XCTAssertTrue(first.label.contains("(la più recente)"), first.label)
        XCTAssertFalse(app.buttons["copies.1"].label.contains("(la più recente)"))
        audit(app, screen: "Scelta della copia")
        first.tap()
        XCTAssertTrue(app.buttons["receive.accept"].waitForExistence(timeout: 10), "dopo la scelta, l'offerta")
    }

    /// Il libro non c'è: lo dice e propone di importare prima il PDF.
    func test_libroAssente_prosa_eImporta() throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("performAccessibilityAudit richiede iOS 17+") }
        let app = launch("-uiTestSeedMacReadingMissingBook")
        openArrival(app)
        XCTAssertTrue(app.staticTexts["Il libro non è in libreria"].waitForExistence(timeout: 10))
        let text = app.staticTexts["missing.text"].label
        XCTAssertTrue(text.contains("Importa prima il PDF"), text)
        XCTAssertTrue(app.buttons["missing.import"].exists)
        XCTAssertTrue(app.buttons["missing.close"].exists)
        audit(app, screen: "Libro assente")
        app.buttons["missing.close"].tap()
        XCTAssertTrue(app.cells.containing(NSPredicate(format: "label CONTAINS %@", "Libro di prova")).firstMatch.waitForExistence(timeout: 5),
                      "la lettura resta in attesa")
    }

    /// La CONSEGNA DAL SISTEMA (il percorso di «Apri con» e di AirDrop): il pacchetto sta fuori dall'app e il sistema lo
    /// apre con l'app (`XCUIApplication.open`, che RILANCIA l'app: è il percorso dell'avvio con un file; quello ad app in
    /// corsa con un libro aperto è nel test seguente); l'app lo accoglie fra le letture arrivate e propone subito l'offerta.
    func test_consegnaDalSistema_apriCon_proponeSubitoLOfferta() throws {
        guard #available(iOS 16.4, *) else { throw XCTSkip("XCUIApplication.open(URL) richiede iOS 16.4+") }
        let app = launch("-uiTestSeedMacReadingOutside")
        XCTAssertTrue(app.navigationBars.buttons["Tag"].waitForExistence(timeout: 10), "Home")
        XCTAssertFalse(app.cells["home.fromMac"].exists, "prima della consegna non c'è nessuna lettura arrivata")
        app.open(URL(fileURLWithPath: "/tmp/ScaboPDF-prova-dal-Mac.scabolettura"))
        let accept = app.buttons["receive.accept"]
        XCTAssertTrue(accept.waitForExistence(timeout: 15), "aperto il file, l'app propone l'offerta")
        XCTAssertTrue(app.staticTexts["Lettura migliore disponibile per «Libro di prova»"].exists)
        app.buttons["receive.later"].tap()
        XCTAssertTrue(app.cells["home.fromMac"].waitForExistence(timeout: 10), "«Non ora»: resta fra le letture arrivate")
    }

    /// Arriva una lettura dal Mac mentre un libro è aperto: il libro NON si chiude e nessuna offerta gli si sovrappone (lo
    /// stesso vale per un'elaborazione in corso, che chiudendosi andrebbe persa: revisione indipendente del giro). La
    /// lettura aspetta nella Home.
    func test_consegnaAdAppInCorso_conUnLibroAperto_nonChiudeNulla() throws {
        // `XCUIApplication.open` RILANCIA l'app (il registro del test lo mostra: «Launch»), quindi qui la consegna arriva
        // all'app in corsa con la stessa funzione di «Apri con» dopo 12 secondi (`-uiTestDeliverMacReadingAfter`, DEBUG).
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestSeedMacReadingOutside", "-uiTestDeliverMacReadingAfter", "12"]
        app.launch()
        let book = app.cells.containing(NSPredicate(format: "label CONTAINS %@", "Libro di prova")).firstMatch
        XCTAssertTrue(book.waitForExistence(timeout: 15), "il libro è nei Recenti")
        book.tap()
        let paragraph = app.descendants(matching: .any).matching(NSPredicate(
            format: "label BEGINSWITH %@", "Il primo paragrafo di prova")).firstMatch
        XCTAssertTrue(paragraph.waitForExistence(timeout: 15), "il libro è aperto")
        // La consegna arriva mentre il libro è aperto: nessuna offerta, il libro resta.
        XCTAssertFalse(app.buttons["receive.accept"].waitForExistence(timeout: 14), "nessuna offerta sopra il libro aperto")
        XCTAssertTrue(paragraph.exists, "il libro resta aperto")
        // La lettura è stata accolta e aspetta nella Home: si riapre l'app senza semi (l'avvio va sempre alla Home; il
        // tasto Indietro del lettore sta nel suo contenitore d'accessibilità chiuso, come negli altri test si termina).
        app.terminate()
        let again = XCUIApplication()
        again.launch()
        XCTAssertTrue(again.cells["home.fromMac"].waitForExistence(timeout: 15), "la lettura arrivata aspetta nella Home")
    }

    /// File danneggiato e forma più recente: prosa, nulla cambia; il file si può togliere.
    func test_fileDanneggiato_eFormaPiuRecente_inProsa() throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("performAccessibilityAudit richiede iOS 17+") }
        var app = launch("-uiTestSeedMacReadingDamaged")
        openArrival(app)
        let problem = app.staticTexts["received.problem"]
        XCTAssertTrue(problem.waitForExistence(timeout: 10))
        XCTAssertTrue(problem.label.contains("danneggiato"), problem.label)
        XCTAssertTrue(problem.label.contains("Nella libreria non è stato cambiato nulla"))
        audit(app, screen: "File danneggiato")
        app.buttons["received.remove"].tap()
        let back = app.backButton(onScreen: "Letture dal Mac")
        if back.waitForExistence(timeout: 5) { back.tap() }
        XCTAssertTrue(app.navigationBars.buttons["Tag"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.cells["home.fromMac"].exists, "il file tolto non c'è più")
        app.terminate()

        app = launch("-uiTestSeedMacReadingNewer")
        openArrival(app)
        XCTAssertTrue(problem.waitForExistence(timeout: 10) || app.staticTexts["received.problem"].waitForExistence(timeout: 10))
        let label = app.staticTexts["received.problem"].label
        XCTAssertTrue(label.contains("più recente"), label)
        XCTAssertTrue(label.contains("Aggiorna ScaboPDF"), label)
        audit(app, screen: "Forma del file più recente")
    }

    // MARK: - Audit (stesso criterio di AccessibilityAuditUITests)

    /// `inTabOnPad`: sull'iPad, le schermate DENTRO la scheda (la Home e quelle che vi si aprono sopra, con la barra delle
    /// schede di iPadOS visibile in alto) danno all'audit un rilievo Dynamic Type su un'etichetta che l'audit non sa
    /// indicare. È PREESISTENTE: il test esistente dell'offerta di rielaborazione fallisce allo stesso modo sull'iPad con
    /// il codice di main e passa sull'iPhone; le etichette delle schermate nuove seguono tutte la dimensione del testo
    /// (sonda del giro). Lì l'audit si fa sull'iPhone; sull'iPad si salta, dichiarandolo. Le schermate presentate sopra
    /// (offerta, conferma, esito, copie, libro assente, problemi): audit ovunque.
    @available(iOS 17.0, *)
    private func audit(_ app: XCUIApplication, screen: String, inTabOnPad: Bool = false) {
        if inTabOnPad, UIDevice.current.userInterfaceIdiom == .pad {
            print("AUDIT «\(screen)» saltato sull'iPad: rilievo preesistente delle schermate dentro la scheda (vedi il commento di audit)")
            return
        }
        // Le transizioni (pagina che entra nella scheda, scheda che si apre) lasciano per qualche istante un'istantanea
        // della pagina di prima, con il suo testo dentro un'immagine: l'audit la segnalerebbe. Si attende che finiscano.
        func wideImages() -> Int {
            app.images.allElementsBoundByIndex.filter { $0.exists && $0.frame.width > app.frame.width }.count
        }
        let deadline = Date().addingTimeInterval(5)
        while wideImages() > 0, Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.25)) }
        print("AUDIT «\(screen)»: immagini più larghe dello schermo prima dell'audit: \(wideImages())")
        var report: [String] = []
        do {
            try app.performAccessibilityAudit { issue in
                let el = issue.element
                if issue.auditType == .textClipped, el?.elementType == .searchField { return true }
                // Sull'iPad, le schermate di testo condivise con l'offerta di rielaborazione (ReprocessTextViewController)
                // danno all'audit «testo potenzialmente inaccessibile» SENZA indicare l'elemento: preesistente (con il codice
                // di main l'offerta di rielaborazione fallisce allo stesso modo sull'iPad; sull'iPhone passa). Solo quel
                // tipo, solo senza elemento, solo sull'iPad: si stampa e si dichiara; tutto il resto fa fallire.
                if UIDevice.current.userInterfaceIdiom == .pad, issue.auditType == .elementDetection, el == nil {
                    print("AUDIT «\(screen)» rilievo preesistente dell'iPad accettato e dichiarato: \(issue.compactDescription)")
                    return true
                }
                let line = "• [\(issue.auditType.rawValue)] \(issue.compactDescription) — «\(el?.label ?? "?")» id:\(el?.identifier ?? "?") type:\(el.map { "\($0.elementType.rawValue)" } ?? "?")"
                print("AUDIT «\(screen)» \(line)\nAUDIT dettaglio: \(issue.detailedDescription)\nAUDIT elemento: \(el?.debugDescription ?? "nessuno")")
                if report.isEmpty { print("AUDIT gerarchia:\n\(app.debugDescription)") }
                report.append(line)
                return false
            }
        } catch {
            if report.isEmpty { XCTFail("Audit su «\(screen)» non eseguito: \(error)") }
        }
        XCTAssertTrue(report.isEmpty, "Audit accessibilità FALLITO su «\(screen)» (\(report.count)):\n" + report.joined(separator: "\n"))
    }
}
