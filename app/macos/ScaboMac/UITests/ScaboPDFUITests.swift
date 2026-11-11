//
//  ScaboPDFUITests.swift
//  ScaboMacUITests — i test d'interfaccia della Home, dell'importazione e della lettura di ScaboPDF per Mac (giro «app unica
//  per Mac, tappa A», 2026-11-08), visti DA FUORI come li vede un client d'accessibilità: il runner di XCUITest passa dallo
//  stesso servizio di sistema di VoiceOver (DISEGNO_LETTURA_MAC § 3.3). Nella modalità automazione, senza tasti sintetici fuori
//  da XCTest, sull'app già assemblata da `scripts/build_app.sh`, sempre sulla libreria di prova (`--libreria-di-prova`): la
//  libreria vera del Mac non si tocca.
//
//  Il libro è il PDF sintetico che l'app scrive da sé (`--libro-di-prova`, nessun testo dei volumi) oppure, per la misura da
//  fuori su un volume vero, un file messo dal laboratorio nel contenitore dell'app (variabile SCABOMAC_LIBRO; la descrizione
//  dalla vista la scrive l'app in SCABOMAC_DESCRIZIONE). Il runner non può scrivere nel laboratorio: i risultati escono sul
//  registro come righe «RISULTATO <nome> <json>».
//
import XCTest

final class ScaboPDFUITests: XCTestCase {

    private func app(_ argomenti: [String]) -> XCUIApplication {
        let path = ProcessInfo.processInfo.environment["SCABOMAC_APP"]
            ?? URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("build/ScaboPDF.app").path
        let a = XCUIApplication(url: URL(fileURLWithPath: path))
        a.launchArguments = argomenti
        return a
    }

    override func setUp() { continueAfterFailure = false }

    /// L'audit d'accessibilità del sistema, con ogni rilievo scritto sul registro (elemento e motivo) prima di fallire.
    /// `conFoglio`: mentre un foglio è aperto, macOS scurisce la finestra sotto (misurato l'8 novembre 2026: il testo delle righe
    /// della Home vi risulta grigio): il contrasto si misura allora sulla stessa finestra senza foglio, in un audit a parte, e
    /// qui si fanno tutti gli altri controlli.
    private func audit(_ app: XCUIApplication, _ nome: String, conFoglio: Bool = false) throws {
        let tipi: XCUIAccessibilityAuditType = conFoglio ? XCUIAccessibilityAuditType.all.subtracting(.contrast) : .all
        var tagliati: [XCUIElement] = []
        var descrizioniTagliate = Set<String>()
        try app.performAccessibilityAudit(for: tipi) { issue in
            let e = issue.element
            // Un rilievo di contrasto su un elemento che esce dalla cornice della sua finestra o dalla parte visibile della sua area
            // di scorrimento non è misurabile qui: l'audit fotografa un rettangolo quasi vuoto (misurato l'8 novembre 2026 sul
            // pannello dei modelli). Si annota e si rimisura dopo, con l'elemento portato in vista; ogni altro rilievo fa rosso.
            if issue.auditType == .contrast, let el = e, !Self.inVista(el, app) {
                tagliati.append(el)
                descrizioniTagliate.insert(issue.detailedDescription)
                print("RISULTATO audit_\(nome)_tagliato {\"descrizione\": \"\(issue.compactDescription)\", \"cornice\": \"\(el.frame)\"}")
                return true
            }
            print("RISULTATO audit_\(nome) {\"tipo\": \"\(issue.auditType.rawValue)\", \"descrizione\": \"\(issue.compactDescription)\", \"elemento\": \"\(e.map { "\($0.elementType.rawValue) id=\($0.identifier) label=\($0.label.prefix(40))" } ?? "-")\"}")
            return false
        }
        try rimisuraInVista(app, nome, tagliati, descrizioniTagliate)
    }

    /// Un elemento si misura solo se è tutto in vista: dentro una finestra, non tagliato dal bordo della sua area di
    /// scorrimento, raggiungibile sullo schermo.
    private static func inVista(_ el: XCUIElement, _ app: XCUIApplication) -> Bool {
        let f = el.frame
        let finestre = app.windows.allElementsBoundByIndex.map(\.frame)
        let scorrimenti = app.scrollViews.allElementsBoundByIndex.map(\.frame)
        return finestre.contains { $0.insetBy(dx: -1, dy: -1).contains(f) }
            && !scorrimenti.contains { $0.intersects(f) && !$0.insetBy(dx: -1, dy: -1).contains(f) }
            && el.isHittable
    }

    /// Gli elementi che l'audit ha trovato tagliati si portano in vista scorrendo la loro area e il contrasto si rimisura:
    /// nessun elemento resta senza misura (revisione del giro della tappa A, rilievo R7). Rosso se un elemento non si porta in
    /// vista o se, in vista, il contrasto non basta.
    private func rimisuraInVista(_ app: XCUIApplication, _ nome: String, _ tagliati: [XCUIElement], _ descrizioni: Set<String>) throws {
        guard !tagliati.isEmpty else { return }
        for el in tagliati where !Self.inVista(el, app) {
            // L'area di scorrimento dell'elemento: nella finestra in primo piano (quella dell'audit; le finestre dell'app si
            // sovrappongono sullo schermo), la più vicina fra quelle che lo contengono in orizzontale (in verticale ne esce).
            let f = el.frame
            let candidate = app.windows.element(boundBy: 0).scrollViews.allElementsBoundByIndex
                .filter { $0.frame.minX <= f.midX && f.midX <= $0.frame.maxX }
            func distanza(_ a: XCUIElement) -> CGFloat { max(0, a.frame.minY - f.maxY, f.minY - a.frame.maxY) }
            guard let area = candidate.min(by: { distanza($0) < distanza($1) }) else { continue }
            for passo in [-200.0, 200.0] where !Self.inVista(el, app) {
                for _ in 0..<6 where !Self.inVista(el, app) { area.scroll(byDeltaX: 0, deltaY: passo) }
            }
            print("RISULTATO audit_rimisura_scorrimento {\"in_vista\": \(Self.inVista(el, app)), \"cornice\": \"\(el.frame)\"}")
        }
        var ancoraTagliate = Set<String>()
        try app.performAccessibilityAudit(for: .contrast) { issue in
            if let el = issue.element, !Self.inVista(el, app) {
                ancoraTagliate.insert(issue.detailedDescription)
                print("RISULTATO audit_\(nome)_tagliato_dopo {\"descrizione\": \"\(issue.detailedDescription)\", \"cornice\": \"\(el.frame)\"}")
                return true
            }
            print("RISULTATO audit_\(nome)_in_vista {\"descrizione\": \"\(issue.detailedDescription)\"}")
            return false
        }
        let senzaMisura = descrizioni.intersection(ancoraTagliate)
        XCTAssertTrue(senzaMisura.isEmpty, "elementi rimasti senza misura del contrasto: \(senzaMisura)")
        print("RISULTATO audit_\(nome)_rimisurati {\"tagliati\": \(descrizioni.count), \"senza_misura\": \(senzaMisura.count)}")
    }

    /// Diagnostica a richiesta (SCABOMAC_ALBERI=1): gli alberi della Home e della finestra «Modelli e officina» sul registro.
    func test_diagnostica_alberi() throws {
        guard ProcessInfo.processInfo.environment["SCABOMAC_ALBERI"] == "1" else { throw XCTSkip("a richiesta") }
        let app = app(["--libreria-di-prova"])
        app.launch()
        defer { app.terminate() }
        XCTAssertTrue(app.windows["home.finestra"].waitForExistence(timeout: 10))
        print("ALBERO home INIZIO\n\(app.debugDescription)\nALBERO FINE")
        app.typeKey("m", modifierFlags: [.command, .shift])
        XCTAssertTrue(app.windows["modelli.finestra"].waitForExistence(timeout: 10))
        print("ALBERO modelli INIZIO\n\(app.windows["modelli.finestra"].debugDescription)\nALBERO FINE")
    }

    private func scrivi(_ nome: String, _ dati: [String: Any]) {
        let d = (try? JSONSerialization.data(withJSONObject: dati, options: [.sortedKeys])) ?? Data()
        print("RISULTATO \(nome) \(String(data: d, encoding: .utf8) ?? "{}")")
    }

    /// Il percorso dei contenitori dalla finestra all'elemento con l'identificatore dato (indentazione dell'albero del runner).
    private func percorso(in albero: String, finoA id: String) -> [String] {
        let righe = albero.components(separatedBy: "\n")
        guard let k = righe.firstIndex(where: { $0.contains("identifier: '\(id)'") }) else { return [] }
        func rientro(_ r: String) -> Int { r.prefix { $0 == " " }.count }
        var out = [righe[k].trimmingCharacters(in: .whitespaces)]
        var livello = rientro(righe[k])
        var j = k - 1
        while j >= 0 {
            let r = righe[j]
            if rientro(r) < livello, !r.trimmingCharacters(in: .whitespaces).isEmpty {
                out.insert(r.trimmingCharacters(in: .whitespaces), at: 0)
                livello = rientro(r)
                if r.contains("Window") { break }
            }
            j -= 1
        }
        return out.map { String($0.prefix(90)) }
    }

    func test_home_vuota_ordineDiLetturaEAudit() throws {
        let app = app(["--libreria-di-prova"])
        app.launch()
        defer { app.terminate() }
        let home = app.windows["home.finestra"]
        XCTAssertTrue(home.waitForExistence(timeout: 10))
        XCTAssertEqual(home.title, "ScaboPDF", "il titolo della Home, come la schermata dell'iPad")
        XCTAssertTrue(home.buttons["home.barra.importa"].exists, "«Importa un documento» nella barra")
        XCTAssertTrue(home.buttons["home.barra.modelli"].exists, "la finestra in più, «Modelli e officina»")
        XCTAssertTrue(home.staticTexts["home.vuota"].exists, "la libreria vuota lo dice")
        // Ordine: la barra (i comandi) viene prima del contenuto nell'albero della finestra.
        let albero = app.debugDescription
        let iBarra = albero.range(of: "home.barra.importa")?.lowerBound, iVuota = albero.range(of: "home.vuota")?.lowerBound
        XCTAssertNotNil(iBarra); XCTAssertNotNil(iVuota)
        if let a = iBarra, let b = iVuota { XCTAssertLessThan(a, b, "prima i comandi, poi il contenuto") }
        XCTAssertTrue(app.menuBars.menuBarItems["Archivio"].exists)
        XCTAssertTrue(app.menuBars.menuBarItems["Libro"].exists)
        XCTAssertTrue(app.menuBars.menuBarItems["Lettura"].exists)
        XCTAssertTrue(app.menuBars.menuBarItems["Finestra"].exists)
        try audit(app, "home")
        scrivi("home_vuota", ["voci_barra_menu": app.menuBars.menuBarItems.allElementsBoundByIndex.map(\.title)])
    }

    func test_importazione_libroDiProva_lettura_menu_audit() throws {
        let app = app(["--libreria-di-prova", "--libro-di-prova"])
        app.launch()
        defer { app.terminate() }
        let lettura = app.windows["lettura.finestra"]
        XCTAssertTrue(lettura.waitForExistence(timeout: 60), "dopo l'importazione si apre la lettura, come sull'iPad")
        let gruppo = lettura.groups["Testo del documento"]
        XCTAssertTrue(gruppo.waitForExistence(timeout: 10), "il gruppo «Testo del documento»")
        let testi = gruppo.staticTexts
        let n = testi.count
        XCTAssertGreaterThanOrEqual(n, 10)
        let primo = testi.element(boundBy: 0)
        let valorePrimo = primo.value as? String ?? ""
        XCTAssertTrue(valorePrimo.hasPrefix("Intestazione di livello"), valorePrimo)
        // Il libro è entrato nella libreria: la Home lo elenca.
        let home = app.windows["home.finestra"]
        XCTAssertTrue(home.exists)
        XCTAssertGreaterThanOrEqual(home.tables["home.libri"].tableRows.count, 1)
        // Il menu «Lettura» con le sue scorciatoie (DISEGNO § 5.2).
        app.menuBars.menuBarItems["Lettura"].click()
        let voci = app.menuBars.menuBarItems["Lettura"].menuItems
        let titoli = voci.allElementsBoundByIndex.map(\.title).filter { !$0.isEmpty }
        XCTAssertEqual(titoli, ["Nota e richiamo", "Intestazione successiva", "Intestazione precedente", "Salta la risorsa"])
        // Le scorciatoie (⌘J, ⌥⌘↓, ⌥⌘↑) le prova il test d'unità del menu: il runner non le espone.
        app.typeKey(.escape, modifierFlags: [])
        // Contenitori: dalla finestra al primo elemento.
        let albero = app.debugDescription
        let via = percorso(in: albero, finoA: "lettura.elemento.0")
        XCTAssertFalse(via.isEmpty)
        try audit(app, "lettura")
        scrivi("lettura_sintetica", ["elementi_da_fuori": n, "primo": String(valorePrimo.prefix(40)),
                                     "percorso_finestra_primo_elemento": via, "profondita": max(0, via.count - 1),
                                     "menu_lettura": titoli])
    }

    func test_libroGiaPresente_poiEliminazioneConConferma() throws {
        // Primo lancio: la libreria di prova vuota, il libro importato.
        let primo = app(["--libreria-di-prova", "--libro-di-prova"])
        primo.launch()
        XCTAssertTrue(primo.windows["lettura.finestra"].waitForExistence(timeout: 60))
        primo.terminate()
        // Secondo lancio, la stessa libreria: lo stesso file è riconosciuto dall'impronta.
        let app = app(["--libreria-di-prova-continua", "--libro-di-prova"])
        app.launch()
        defer { app.terminate() }
        let domanda = app.staticTexts["Questo libro è già nella tua libreria"]
        XCTAssertTrue(domanda.waitForExistence(timeout: 30), "«Libro già presente», con le parole dell'iPad")
        XCTAssertTrue(app.buttons["Apri il libro che hai già"].exists)
        XCTAssertTrue(app.buttons["Importa come copia a parte"].exists)
        XCTAssertTrue(app.buttons["Annulla"].exists)
        try audit(app, "doppione", conFoglio: true)
        app.buttons["Apri il libro che hai già"].click()
        let lettura = app.windows["lettura.finestra"]
        XCTAssertTrue(lettura.waitForExistence(timeout: 30), "si apre il libro che c'era")
        lettura.typeKey("w", modifierFlags: [.command])
        let home = app.windows["home.finestra"]
        XCTAssertTrue(home.waitForExistence(timeout: 10))
        XCTAssertEqual(home.tables["home.libri"].tableRows.count, 1, "un libro solo: nessuna copia")
        try audit(app, "home_con_libro")   // il contrasto delle righe, senza fogli
        // Eliminazione definitiva dal menu «Libro», con la conferma in prosa.
        home.tables["home.libri"].tableRows.element(boundBy: 0).click()
        app.menuBars.menuBarItems["Libro"].click()
        let elimina = app.menuBars.menuBarItems["Libro"].menuItems["Elimina definitivamente…"]
        XCTAssertTrue(elimina.waitForExistence(timeout: 5))
        let attiva = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: elimina)
        wait(for: [attiva], timeout: 10)
        elimina.click()
        XCTAssertTrue(app.staticTexts["Eliminare definitivamente?"].waitForExistence(timeout: 10))
        try audit(app, "elimina", conFoglio: true)
        app.buttons["Elimina definitivamente"].click()
        XCTAssertTrue(home.staticTexts["home.vuota"].waitForExistence(timeout: 10), "la libreria è di nuovo vuota")
    }

    func test_tastiera_titoloSuccessivoEFuoco() throws {
        let app = app(["--libreria-di-prova", "--libro-di-prova"])
        app.launch()
        defer { app.terminate() }
        let lettura = app.windows["lettura.finestra"]
        XCTAssertTrue(lettura.waitForExistence(timeout: 60))
        let gruppo = lettura.groups["Testo del documento"]
        XCTAssertTrue(gruppo.waitForExistence(timeout: 10))
        // Freccia giù sposta il fuoco di un elemento; ⌥⌘↓ va al titolo successivo (il menu «Lettura»).
        lettura.typeKey(.downArrow, modifierFlags: [])
        lettura.typeKey(.downArrow, modifierFlags: [.command, .option])
        let col = gruppo.staticTexts.matching(NSPredicate(format: "hasKeyboardFocus == true")).firstMatch
        var valore = ""
        if col.waitForExistence(timeout: 5) { valore = col.value as? String ?? "" }
        scrivi("tastiera", ["elemento_col_fuoco": String(valore.prefix(40))])
        XCTAssertTrue(valore.hasPrefix("Intestazione di livello"), "il fuoco è sul titolo successivo: «\(valore.prefix(40))»")
    }

    /// ⌘J con un tasto vero (giro «prova 4, segnalibri e sigle», 2026-11-11): nel diario delle prove 3 rifatta e 4 nessun ⌘J è
    /// arrivato all'app con VoiceOver acceso. Senza VoiceOver la scorciatoia deve arrivare: dal capoverso col richiamo alla nota e
    /// ritorno, come la voce «Nota e richiamo» del menu. Se questo test passa, la via dei tasti dell'app funziona.
    func test_tastiera_notaERichiamo() throws {
        let app = app(["--libreria-di-prova", "--libro-di-prova"])
        app.launch()
        defer { app.terminate() }
        let lettura = app.windows["lettura.finestra"]
        XCTAssertTrue(lettura.waitForExistence(timeout: 60))
        let gruppo = lettura.groups["Testo del documento"]
        XCTAssertTrue(gruppo.waitForExistence(timeout: 10))
        func colFuoco() -> String {
            let e = gruppo.staticTexts.matching(NSPredicate(format: "hasKeyboardFocus == true")).firstMatch
            return e.waitForExistence(timeout: 5) ? (e.value as? String ?? "") : ""
        }
        // Dal titolo del primo capitolo al capoverso col richiamo della nota 1, poi ⌘J: la nota; ⌘J di nuovo: il capoverso.
        lettura.typeKey(.downArrow, modifierFlags: [])
        let capoverso = colFuoco()
        lettura.typeKey("j", modifierFlags: [.command])
        let nota = colFuoco()
        lettura.typeKey("j", modifierFlags: [.command])
        let ritorno = colFuoco()
        scrivi("tastiera_nota", ["capoverso": String(capoverso.prefix(12)), "nota": String(nota.prefix(12)),
                                 "ritorno": String(ritorno.prefix(12))])
        XCTAssertFalse(capoverso.isEmpty || capoverso.hasPrefix("Nota"), "dopo Freccia giù il fuoco è sul capoverso")
        XCTAssertTrue(nota.hasPrefix("Nota"), "⌘J porta alla nota: «\(nota.prefix(20))»")
        XCTAssertEqual(ritorno, capoverso, "⌘J di nuovo riporta al capoverso col richiamo")
    }

    /// La misura da fuori su un volume vero (a richiesta: SCABOMAC_LIBRO e SCABOMAC_DESCRIZIONE, percorsi nel contenitore).
    func test_misuraDaFuori_volumeVero() throws {
        let env = ProcessInfo.processInfo.environment
        guard let libro = env["SCABOMAC_LIBRO"], let descr = env["SCABOMAC_DESCRIZIONE"] else {
            throw XCTSkip("a richiesta: SCABOMAC_LIBRO e SCABOMAC_DESCRIZIONE")
        }
        let t0 = Date()
        let app = app(["--libreria-di-prova", "--importa", libro, "--descrivi-in", descr])
        app.launch()
        defer { app.terminate() }
        let lettura = app.windows["lettura.finestra"]
        XCTAssertTrue(lettura.waitForExistence(timeout: 900), "il volume si importa e si apre")
        let gruppo = lettura.groups["Testo del documento"]
        XCTAssertTrue(gruppo.waitForExistence(timeout: 60))
        let tApertura = Date().timeIntervalSince(t0)
        // Dal giro «prove della tappa A» (2026-11-09) un libro lungo espone come figli il primo elemento, una finestra attorno
        // al fuoco (all'apertura: dall'inizio) e l'ultimo (DISEGNO § 2.3-2.4): il runner li conta tutti, e l'ultimo figlio è
        // l'ultimo elemento del libro.
        let n = gruppo.staticTexts.count
        let ultimoFiglio = n > 0 ? gruppo.staticTexts.element(boundBy: n - 1).identifier : ""
        // Un campione di elementi della finestra, per identificatore.
        let indici = (env["SCABOMAC_INDICI"] ?? "0,1,2,10,100,200,300,400")
            .split(separator: ",").compactMap { Int($0) }
        var campione: [[String: Any]] = []
        for i in indici {
            let e = app.descendants(matching: .any).matching(NSPredicate(format: "identifier == %@", "lettura.elemento.\(i)")).firstMatch
            guard e.waitForExistence(timeout: 5) else { campione.append(["i": i, "esiste": false]); continue }
            campione.append(["i": i, "esiste": true, "testo": e.value as? String ?? "", "valore": e.label])
        }
        let via = percorso(in: app.debugDescription, finoA: "lettura.elemento.0")
        scrivi("misura_da_fuori", ["secondi_fino_alla_lettura": tApertura, "elementi_contati_dal_runner": n,
                                   "ultimo_figlio": ultimoFiglio,
                                   "campione": campione, "percorso_finestra_primo_elemento": via,
                                   "profondita": max(0, via.count - 1)])
    }
}
