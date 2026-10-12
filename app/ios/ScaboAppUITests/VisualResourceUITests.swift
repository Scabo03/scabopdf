//
//  VisualResourceUITests.swift
//  ScaboAppUITests
//
//  La RISORSA VISIVA nella lettura (giro 2026-10-12, `docs/RISORSE_VISIVE.md`), dall'albero di accessibilità reale:
//  l'elemento è annunciato come tale, il testo della tabella resta raggiungibile come elementi ordinari subito dopo, e
//  l'audit di accessibilità della schermata di lettura con la risorsa NON aggiunge rilievi rispetto allo stesso libro
//  senza l'elemento (seme `-uiTestSeedVisualResourceControl`). Il confronto conta i rilievi per tipo e descrizione
//  completa: un testo tagliato nella cella nuova non si nasconde dietro un rilievo già presente nella barra. I rilievi
//  già presenti (su iPhone: il selettore del layout troncato in «L…», `ReadingInterfaceBar`, preesistente al giro) sono
//  allegati al risultato e dichiarati nel referto. Seme DEBUG `-uiTestSeedVisualResource`: un libro sintetico (PDF
//  generato, parole neutre) con una tabella già riconosciuta. Le azioni personalizzate sono verificate nei test unitari
//  ospitati (`VisualResourceTests`), dove sono leggibili; qui nessun foglio di sistema viene aperto.
//

import XCTest

final class VisualResourceUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = true
    }

    private func element(_ app: XCUIApplication, _ format: String, _ text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: format, text)).firstMatch
    }

    func testVisualResource_isAnnounced_textStaysReachable_andAuditAddsNothing() throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("performAccessibilityAudit richiede iOS 17+") }
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestSeedVisualResource"]
        app.launch()

        let book = app.cells.containing(NSPredicate(format: "label CONTAINS %@", "Libro con tabella")).firstMatch
        XCTAssertTrue(book.waitForExistence(timeout: 15), "il libro è nei Recenti")
        book.tap()

        let resource = element(app, "label == %@", "Risorsa visiva. Tabella: Il raccolto per stagione")
        XCTAssertTrue(resource.waitForExistence(timeout: 15), "la risorsa visiva è un elemento annunciato come tale")
        let firstRow = element(app, "label == %@", "Stagione Raccolto Primavera Grano")
        let secondRow = element(app, "label == %@", "Estate Orzo Autunno Uva")
        XCTAssertTrue(firstRow.exists, "il testo della tabella resta un elemento raggiungibile")
        XCTAssertTrue(secondRow.exists)
        // Ordine di lettura: annuncio, poi il testo della regione, poi il paragrafo che segue.
        let after = element(app, "label == %@", "Il paragrafo che segue la tabella.")
        XCTAssertTrue(after.exists)
        let ys = [resource, firstRow, secondRow, after].map { $0.frame.minY }
        XCTAssertTrue(ys[0] < ys[1] && ys[1] < ys[2] && ys[2] < ys[3], "ordine verticale: \(ys)")
        let withResource = auditIssues(app)
        app.terminate()

        // Lo stesso libro, nella stessa vista di lettura, senza l'elemento «risorsa visiva».
        let control = XCUIApplication()
        control.launchArguments += ["-uiTestSeedVisualResourceControl"]
        control.launch()
        let plain = control.cells.containing(NSPredicate(format: "label CONTAINS %@", "Libro con tabella")).firstMatch
        XCTAssertTrue(plain.waitForExistence(timeout: 15), "il libro di controllo è nei Recenti")
        plain.tap()
        XCTAssertTrue(element(control, "label == %@", "Il paragrafo che segue la tabella.").waitForExistence(timeout: 15))
        XCTAssertFalse(element(control, "label BEGINSWITH %@", "Risorsa visiva").exists, "il controllo non ha la risorsa")
        let baseline = auditIssues(control)

        let extra = withResource.filter { key, n in n > baseline[key, default: 0] }
        attach("Rilievi audit della lettura con la risorsa visiva", withResource)
        attach("Rilievi audit della stessa lettura senza risorse (preesistenti)", baseline)
        XCTAssertTrue(extra.isEmpty, "la risorsa visiva aggiunge rilievi di accessibilità:\n"
                      + extra.map { "• \($0.key) ×\($0.value)" }.sorted().joined(separator: "\n"))
    }

    /// I rilievi dell'audit sulla schermata, contati per (tipo, descrizione completa, etichetta dell'elemento).
    private func auditIssues(_ app: XCUIApplication) -> [String: Int] {
        guard #available(iOS 17.0, *) else { return [:] }
        var issues: [String: Int] = [:]
        do {
            try app.performAccessibilityAudit { issue in
                let key = "[\(issue.auditType.rawValue)] \(issue.detailedDescription) — «\(issue.element?.label ?? "?")»"
                issues[key, default: 0] += 1
                return true  // raccolto qui: il confronto con la vista di controllo decide
            }
        } catch {
            issues["errore dell'audit: \(error)", default: 0] += 1
        }
        return issues
    }

    private func attach(_ name: String, _ issues: [String: Int]) {
        let text = issues.isEmpty ? "nessun rilievo" : issues.map { "• \($0.key) ×\($0.value)" }.sorted().joined(separator: "\n")
        let a = XCTAttachment(string: text)
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }
}
