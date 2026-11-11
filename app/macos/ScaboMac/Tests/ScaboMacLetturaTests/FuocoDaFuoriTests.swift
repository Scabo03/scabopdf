//
//  FuocoDaFuoriTests.swift
//  ScaboMacLetturaTests — il salto fra nota e richiamo e i figli finestrati LETTI DA FUORI (giro «prove della tappa A»,
//  2026-11-09). Lancia l'app vera (`build/ScaboPDF.app`, assemblata da `scripts/build_app.sh`) con la libreria di prova e il libro
//  sintetico, e fa ciò che fa VoiceOver con l'API C d'accessibilità:
//  - i salti: «Vai alla nota N» e «Vai al testo del richiamo» (AXPerformAction col nome dell'azione personalizzata) e la voce
//    «Nota e richiamo» del menu «Lettura» premuta per l'accessibilità (come da VO+M). Dopo ognuna misura ciò che VoiceOver usa
//    per spostare il cursore: l'elemento col fuoco dell'APP (`AXFocusedUIElement`, che VoiceOver chiede dall'alto della finestra
//    a ogni avviso) e l'avviso «AXFocusedUIElementChanged» arrivato a un osservatore, col bersaglio. Prima della cura il fuoco
//    dell'app restava il gruppo e il cursore non si muoveva (diario della prova T3; sull'app della tappa A questo test fallisce);
//  - i figli finestrati, con la finestra piccola delle prove (`--raggio-finestra 4`, 9 elementi sui 24 del libro): il percorso
//    integrale passo per passo come lo fa VoiceOver (i figli del gruppo, il seguente dell'elemento corrente, il fuoco su di
//    lui), senza salti né vicoli ciechi, poi VO+Fine, i passi indietro, VO+Inizio e i passi avanti.
//
//  Serve un processo fidato per l'accessibilità (il Terminale del Mac di sviluppo, da cui si lancia `swift test`), e un'app
//  assemblata non più vecchia dei sorgenti: altrimenti il test si salta col motivo. Nessun tasto sintetico. Contenuti
//  sintetici: nessun testo dei volumi.
//
import AppKit
import ApplicationServices
import XCTest

@MainActor
final class FuocoDaFuoriTests: XCTestCase {

    private static var radicePacchetto: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }
    private static var appURL: URL {
        if let p = ProcessInfo.processInfo.environment["SCABOMAC_APP"] { return URL(fileURLWithPath: p) }
        return radicePacchetto.appendingPathComponent("build/ScaboPDF.app")
    }

    private func attr(_ e: AXUIElement, _ a: String) -> CFTypeRef? {
        var v: CFTypeRef?
        return AXUIElementCopyAttributeValue(e, a as CFString, &v) == .success ? v : nil
    }
    private func elems(_ e: AXUIElement, _ a: String) -> [AXUIElement] { (attr(e, a) as? [AXUIElement]) ?? [] }
    private func ident(_ e: AXUIElement) -> String { (attr(e, "AXIdentifier") as? String) ?? "" }
    private func indice(_ e: AXUIElement) -> Int? {
        let s = ident(e)
        return s.hasPrefix("lettura.elemento.") ? Int(s.dropFirst("lettura.elemento.".count)) : nil
    }
    private func azioni(_ e: AXUIElement) -> [String] {
        var nomi: CFArray?
        AXUIElementCopyActionNames(e, &nomi)
        return (nomi as? [String]) ?? []
    }
    /// Il nome di un'azione personalizzata come lo vede un client: «Name:Vai alla nota 1\nTarget:…\nSelector:…».
    private func nome(_ grezzo: String) -> String {
        grezzo.components(separatedBy: "\n").first { $0.hasPrefix("Name:") }.map { String($0.dropFirst(5)) } ?? grezzo
    }
    private func gira(_ secondi: Double) { CFRunLoopRunInMode(.defaultMode, secondi, false) }
    @discardableResult private func focalizza(_ e: AXUIElement) -> AXError {
        AXUIElementSetAttributeValue(e, "AXFocused" as CFString, kCFBooleanTrue)
    }

    /// Le notifiche arrivate all'osservatore: (nome, identificatore dell'elemento).
    final class Raccolta { var voci: [(String, String)] = [] }

    /// I prerequisiti: client fidato, app assemblata e non più vecchia dei sorgenti della lettura, nessun'altra ScaboPDF aperta.
    private func prerequisiti() throws -> URL {
        guard AXIsProcessTrusted() else { throw XCTSkip("il processo dei test non è un client d'accessibilità fidato") }
        let url = Self.appURL
        let eseguibile = url.appendingPathComponent("Contents/MacOS/ScaboMac")
        guard let dataApp = (try? eseguibile.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate else {
            throw XCTSkip("manca l'app assemblata: scripts/build_app.sh")
        }
        if ProcessInfo.processInfo.environment["SCABOMAC_APP"] == nil {
            let sorgenti = Self.radicePacchetto.appendingPathComponent("Sources")
            let piùRecente = (FileManager.default.enumerator(at: sorgenti, includingPropertiesForKeys: [.contentModificationDateKey])?
                .compactMap { ($0 as? URL).flatMap { try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate } }
                .max()) ?? .distantPast
            guard dataApp >= piùRecente else { throw XCTSkip("l'app assemblata è più vecchia dei sorgenti: rifai scripts/build_app.sh") }
        }
        // L'app di un test precedente può essere ancora in chiusura: si aspetta qualche secondo prima di dire che ce n'è un'altra.
        let limite = Date().addingTimeInterval(8)
        while !NSRunningApplication.runningApplications(withBundleIdentifier: "com.scabo.scabopdf.mac").isEmpty, Date() < limite { gira(0.1) }
        guard NSRunningApplication.runningApplications(withBundleIdentifier: "com.scabo.scabopdf.mac").isEmpty else {
            throw XCTSkip("un'altra ScaboPDF è aperta")
        }
        return url
    }

    /// Chiude l'app del test e aspetta che sia chiusa davvero.
    private func chiudi(_ r: NSRunningApplication) {
        r.forceTerminate()
        let limite = Date().addingTimeInterval(8)
        while !r.isTerminated, Date() < limite { gira(0.1) }
    }

    /// Lancia l'app col libro sintetico e restituisce l'app, il suo elemento e il gruppo del testo.
    private func lancia(_ argomenti: [String]) async throws -> (NSRunningApplication, AXUIElement, AXUIElement) {
        let cfg = NSWorkspace.OpenConfiguration()
        cfg.arguments = ["--libreria-di-prova", "--libro-di-prova"] + argomenti
        cfg.createsNewApplicationInstance = true
        let running = try await NSWorkspace.shared.openApplication(at: try prerequisiti(), configuration: cfg)
        let app = AXUIElementCreateApplication(running.processIdentifier)
        AXUIElementSetMessagingTimeout(app, 10)
        var gruppo: AXUIElement?
        let limite = Date().addingTimeInterval(90)
        while gruppo == nil, Date() < limite {
            if let w = elems(app, "AXWindows").first(where: { ident($0) == "lettura.finestra" }) {
                var coda = elems(w, "AXChildren")
                while !coda.isEmpty, gruppo == nil {
                    let e = coda.removeFirst()
                    if ident(e) == "lettura.testo" { gruppo = e } else { coda += elems(e, "AXChildren") }
                }
            }
            if gruppo == nil { gira(0.25) }
        }
        guard let g = gruppo else { chiudi(running); throw XCTSkip("la finestra di lettura non si è aperta in 90 s") }
        gira(1.0)
        return (running, app, g)
    }

    func test_salti_spostanoIlFuocoDellApp_lettoDaFuori() async throws {
        let (running, app, g) = try await lancia([])
        defer { chiudi(running) }

        // L'osservatore degli avvisi del fuoco, come VoiceOver.
        var obs: AXObserver?
        let raccolta = Raccolta()
        let cb: AXObserverCallback = { _, el, nome, ref in
            let r = Unmanaged<Raccolta>.fromOpaque(ref!).takeUnretainedValue()
            var v: CFTypeRef?
            AXUIElementCopyAttributeValue(el, "AXIdentifier" as CFString, &v)
            r.voci.append((nome as String, (v as? String) ?? ""))
        }
        XCTAssertEqual(AXObserverCreate(running.processIdentifier, cb, &obs), .success)
        let o = try XCTUnwrap(obs)
        XCTAssertEqual(AXObserverAddNotification(o, app, "AXFocusedUIElementChanged" as CFString,
                                                 Unmanaged.passUnretained(raccolta).toOpaque()), .success)
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(o), .defaultMode)
        defer { CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(o), .defaultMode) }

        func fuocoDellApp() -> String {
            guard let f = attr(app, "AXFocusedUIElement") else { return "" }
            return ident(f as! AXUIElement)
        }
        /// Aspetta (fino a cinque secondi) che l'elemento col fuoco dell'app cambi da `prima`, e lascia arrivare gli avvisi.
        func aspettaFuocoDiverso(da prima: String) -> String {
            let limite = Date().addingTimeInterval(5)
            while fuocoDellApp() == prima, Date() < limite { gira(0.05) }
            gira(0.2)
            return fuocoDellApp()
        }
        func elemento(_ id: String) -> AXUIElement? { elems(g, "AXChildren").first { ident($0) == id } }

        // «Vai alla nota N» dal capoverso che la richiama.
        let richiamo = try XCTUnwrap(elems(g, "AXChildren").first { azioni($0).contains { nome($0).hasPrefix("Vai alla nota") } },
                                     "un capoverso col richiamo")
        let idRichiamo = ident(richiamo)
        let vaiAllaNota = try XCTUnwrap(azioni(richiamo).first { nome($0).hasPrefix("Vai alla nota") })
        raccolta.voci.removeAll()
        let primaDelSalto = fuocoDellApp()
        XCTAssertEqual(AXUIElementPerformAction(richiamo, vaiAllaNota as CFString), .success)
        let idNota = aspettaFuocoDiverso(da: primaDelSalto)
        XCTAssertTrue(idNota.hasPrefix("lettura.elemento."), "il fuoco dell'app è un elemento del testo, non il gruppo: «\(idNota)»")
        XCTAssertNotEqual(idNota, idRichiamo, "il fuoco si è spostato")
        let nota = try XCTUnwrap(elemento(idNota), "la nota è fra i figli del gruppo")
        XCTAssertTrue(azioni(nota).contains { nome($0) == "Vai al testo del richiamo" }, "il bersaglio è la nota")
        XCTAssertTrue(raccolta.voci.contains { $0 == ("AXFocusedUIElementChanged", idNota) },
                      "l'avviso del fuoco col bersaglio: \(raccolta.voci)")

        // «Vai al testo del richiamo» dalla nota: si torna al capoverso.
        let vaiAlRichiamo = try XCTUnwrap(azioni(nota).first { nome($0) == "Vai al testo del richiamo" })
        raccolta.voci.removeAll()
        XCTAssertEqual(AXUIElementPerformAction(nota, vaiAlRichiamo as CFString), .success)
        XCTAssertEqual(aspettaFuocoDiverso(da: idNota), idRichiamo)
        XCTAssertTrue(raccolta.voci.contains { $0 == ("AXFocusedUIElementChanged", idRichiamo) }, "\(raccolta.voci)")

        // La voce del menu «Lettura» «Nota e richiamo» (⌘J), premuta per l'accessibilità: dal richiamo alla nota.
        let barra = try XCTUnwrap(attr(app, "AXMenuBar")) as! AXUIElement
        let menu = try XCTUnwrap(elems(barra, "AXChildren").first { (attr($0, "AXTitle") as? String) == "Lettura" })
        let voci = elems(menu, "AXChildren").first.map { elems($0, "AXChildren") } ?? []
        let voce = try XCTUnwrap(voci.first { ((attr($0, "AXTitle") as? String) ?? "").hasPrefix("Nota e richiamo") })
        raccolta.voci.removeAll()
        XCTAssertEqual(AXUIElementPerformAction(voce, kAXPressAction as CFString), .success)
        XCTAssertEqual(aspettaFuocoDiverso(da: idRichiamo), idNota, "⌘J dal menu porta alla nota")
        XCTAssertTrue(raccolta.voci.contains { $0 == ("AXFocusedUIElementChanged", idNota) }, "\(raccolta.voci)")
        print("RISULTATO fuoco_da_fuori {\"richiamo\":\"\(idRichiamo)\",\"nota\":\"\(idNota)\"}")
    }

    /// Un salto a cui il client NON si posa (giro «prove rifatte», 2026-11-10). Il diario della T3 rifatta: tre salti su sette,
    /// tutti partiti dal menu delle azioni di VoiceOver, sono arrivati all'app ma il cursore è rimasto sulla partenza — subito
    /// dopo l'azione VoiceOver ha riletto il valore della partenza e non ha chiesto le azioni del bersaglio, cosa che fa a ogni
    /// arrivo. Qui il client fa lo stesso: esegue «Vai alla nota», rilegge la partenza e non tocca il bersaglio. L'app deve
    /// RIPETERE l'avviso del fuoco col bersaglio (all'avviso ripetuto VoiceOver richiede l'elemento col fuoco e ci va). Sull'app
    /// di prima della cura l'avviso arriva una volta sola: il test fallisce.
    func test_salto_senzaArrivo_ripeteLAvviso_lettoDaFuori() async throws {
        let (running, app, g) = try await lancia([])
        defer { chiudi(running) }
        let (raccolta, o) = try osservatore(running, app)
        defer { CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(o), .defaultMode) }
        let richiamo = try XCTUnwrap(elems(g, "AXChildren").first { azioni($0).contains { nome($0).hasPrefix("Vai alla nota") } })
        let vaiAllaNota = try XCTUnwrap(azioni(richiamo).first { nome($0).hasPrefix("Vai alla nota") })
        gira(0.5); raccolta.voci.removeAll()
        XCTAssertEqual(AXUIElementPerformAction(richiamo, vaiAllaNota as CFString), .success)
        _ = attr(richiamo, "AXValue")   // come VoiceOver alla chiusura del suo menu: rilegge la partenza
        _ = azioni(richiamo)            // e posarsi sulla partenza non è l'arrivo al bersaglio
        gira(1.8)
        let idNota = fuocoDellApp(app)
        XCTAssertTrue(idNota.hasPrefix("lettura.elemento.") && idNota != ident(richiamo), "il fuoco dell'app è il bersaglio: «\(idNota)»")
        let avvisi = raccolta.voci.filter { $0 == ("AXFocusedUIElementChanged", idNota) }.count
        XCTAssertGreaterThanOrEqual(avvisi, 2, "l'avviso col bersaglio si ripete se nessuno ci si posa: \(raccolta.voci)")
        print("RISULTATO salto_senza_arrivo {\"avvisi_col_bersaglio\":\(avvisi)}")
    }

    /// Due salti di fila allo STESSO bersaglio, con un passo di VoiceOver in mezzo (diario della T3 rifatta: J1 e J2, J4 e J5,
    /// e i secondi di ogni coppia persi). VoiceOver, all'avviso, chiede l'elemento col fuoco dell'app e si sposta solo se la
    /// risposta è cambiata rispetto all'ultima che ha avuto: al secondo salto la risposta deve essere un elemento DIVERSO (lo
    /// stesso indice, un oggetto nuovo), ed essere fra i figli. Sull'app di prima della cura è lo stesso: il test fallisce.
    func test_salti_stessoBersaglio_rispostaCambiata_lettoDaFuori() async throws {
        let (running, app, g) = try await lancia([])
        defer { chiudi(running) }
        let richiamo = try XCTUnwrap(elems(g, "AXChildren").first { azioni($0).contains { nome($0).hasPrefix("Vai alla nota") } })
        func vaiAllaNota() throws -> String { try XCTUnwrap(azioni(richiamo).first { nome($0).hasPrefix("Vai alla nota") }) }
        // J1: dal richiamo alla nota; il client chiede l'elemento col fuoco (come VoiceOver all'avviso) e ci si posa.
        XCTAssertEqual(AXUIElementPerformAction(richiamo, try vaiAllaNota() as CFString), .success)
        gira(0.1)   // VoiceOver chiede l'elemento col fuoco e ci si posa entro qualche decina di millesimi (diari)
        let prima = try XCTUnwrap(attr(app, "AXFocusedUIElement")) as! AXUIElement
        XCTAssertFalse(azioni(prima).isEmpty)
        // Un passo indietro, come VO+Freccia sinistra: il client dà il fuoco al richiamo; l'app non avvisa nulla.
        XCTAssertEqual(focalizza(richiamo), .success)
        gira(0.3)
        // J2: di nuovo «Vai alla nota» dallo stesso richiamo.
        XCTAssertEqual(AXUIElementPerformAction(richiamo, try vaiAllaNota() as CFString), .success)
        gira(0.1)
        let dopo = try XCTUnwrap(attr(app, "AXFocusedUIElement")) as! AXUIElement
        XCTAssertFalse(azioni(dopo).isEmpty, "il client si posa sul bersaglio")
        XCTAssertEqual(ident(dopo), ident(prima), "lo stesso bersaglio; il vecchio elemento risponde ancora")
        XCTAssertFalse(CFEqual(prima, dopo), "la risposta è un elemento diverso dall'ultima: VoiceOver la vede cambiata")
        XCTAssertTrue(elems(g, "AXChildren").contains { CFEqual($0, dopo) }, "l'elemento nuovo è fra i figli del gruppo")
        print("RISULTATO stesso_bersaglio {\"risposta_cambiata\":\(!CFEqual(prima, dopo))}")
    }

    /// Il salto a cui il client si posa subito (ne chiede le azioni, come VoiceOver all'arrivo): un avviso solo, nessuna
    /// ripetizione, così VoiceOver non dice due volte il bersaglio. Verde anche sull'app di prima della cura.
    func test_salto_conArrivo_unAvvisoSolo_lettoDaFuori() async throws {
        let (running, app, g) = try await lancia([])
        defer { chiudi(running) }
        let (raccolta, o) = try osservatore(running, app)
        defer { CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(o), .defaultMode) }
        let richiamo = try XCTUnwrap(elems(g, "AXChildren").first { azioni($0).contains { nome($0).hasPrefix("Vai alla nota") } })
        let vaiAllaNota = try XCTUnwrap(azioni(richiamo).first { nome($0).hasPrefix("Vai alla nota") })
        gira(0.5); raccolta.voci.removeAll()
        XCTAssertEqual(AXUIElementPerformAction(richiamo, vaiAllaNota as CFString), .success)
        let bersaglio = try XCTUnwrap(attr(app, "AXFocusedUIElement")) as! AXUIElement
        let idNota = ident(bersaglio)
        XCTAssertFalse(azioni(bersaglio).isEmpty, "il client si posa: ne chiede le azioni")
        gira(1.8)
        let avvisi = raccolta.voci.filter { $0 == ("AXFocusedUIElementChanged", idNota) }.count
        XCTAssertEqual(avvisi, 1, "un avviso solo: \(raccolta.voci)")
    }

    /// L'osservatore degli avvisi del fuoco dell'app, come VoiceOver (per i test dell'arrivo).
    private func osservatore(_ running: NSRunningApplication, _ app: AXUIElement) throws -> (Raccolta, AXObserver) {
        var obs: AXObserver?
        let raccolta = Raccolta()
        let cb: AXObserverCallback = { _, el, nome, ref in
            let r = Unmanaged<Raccolta>.fromOpaque(ref!).takeUnretainedValue()
            var v: CFTypeRef?
            AXUIElementCopyAttributeValue(el, "AXIdentifier" as CFString, &v)
            r.voci.append((nome as String, (v as? String) ?? ""))
        }
        XCTAssertEqual(AXObserverCreate(running.processIdentifier, cb, &obs), .success)
        let o = try XCTUnwrap(obs)
        XCTAssertEqual(AXObserverAddNotification(o, app, "AXFocusedUIElementChanged" as CFString,
                                                 Unmanaged.passUnretained(raccolta).toOpaque()), .success)
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(o), .defaultMode)
        return (raccolta, o)
    }
    private func fuocoDellApp(_ app: AXUIElement) -> String {
        guard let f = attr(app, "AXFocusedUIElement") else { return "" }
        return ident(f as! AXUIElement)
    }

    /// I figli finestrati da fuori, con la finestra piccola delle prove: il percorso di VoiceOver, elemento per elemento,
    /// sull'intero libro sintetico senza salti né vicoli ciechi, VO+Fine con i passi indietro, VO+Inizio con i passi avanti.
    func test_figliFinestrati_percorsoIntegrale_lettoDaFuori() async throws {
        let (running, _, g) = try await lancia(["--raggio-finestra", "4"])
        defer { chiudi(running) }
        var figli = elems(g, "AXChildren")
        XCTAssertEqual(figli.count, 10, "nove della finestra più l'ultimo elemento: \(figli.map(ident))")
        var corrente = try XCTUnwrap(figli.first)
        XCTAssertEqual(indice(corrente), 0)
        XCTAssertEqual(focalizza(corrente), .success)
        var passi = 0
        while true {
            figli = elems(g, "AXChildren")
            XCTAssertLessThanOrEqual(figli.count, 12)
            let k = try XCTUnwrap(figli.firstIndex { CFEqual($0, corrente) }, "vicolo cieco a \(ident(corrente))")
            guard k + 1 < figli.count else { break }
            let seguente = figli[k + 1]
            XCTAssertEqual(indice(seguente), (indice(corrente) ?? -2) + 1, "nessun salto dopo \(ident(corrente))")
            XCTAssertEqual(focalizza(seguente), .success)
            corrente = seguente
            passi += 1
            XCTAssertLessThan(passi, 100)
        }
        let ultimoIndice = try XCTUnwrap(indice(corrente))
        XCTAssertEqual(passi, ultimoIndice, "un passo per elemento, fino all'ultimo")
        // VO+Fine dall'inizio: l'ultimo figlio è l'ultimo elemento; tre passi indietro, uno alla volta.
        let inizio = try XCTUnwrap(elems(g, "AXChildren").first)
        focalizza(inizio)
        let fine = try XCTUnwrap(elems(g, "AXChildren").last)
        XCTAssertEqual(indice(fine), ultimoIndice)
        focalizza(fine)
        var c = fine
        for atteso in [ultimoIndice - 1, ultimoIndice - 2, ultimoIndice - 3] {
            let f = elems(g, "AXChildren")
            let k = try XCTUnwrap(f.firstIndex { CFEqual($0, c) })
            c = f[k - 1]
            XCTAssertEqual(indice(c), atteso)
            focalizza(c)
        }
        // VO+Inizio: il primo elemento; poi tre passi avanti.
        c = try XCTUnwrap(elems(g, "AXChildren").first)
        XCTAssertEqual(indice(c), 0)
        focalizza(c)
        for atteso in [1, 2, 3] {
            let f = elems(g, "AXChildren")
            let k = try XCTUnwrap(f.firstIndex { CFEqual($0, c) })
            c = f[k + 1]
            XCTAssertEqual(indice(c), atteso)
            focalizza(c)
        }
        print("RISULTATO finestrati_da_fuori {\"passi\":\(passi),\"ultimo\":\(ultimoIndice)}")
    }

    // MARK: I comandi standard di VoiceOver (giro «comandi da tastiera e VoiceOver sul Mac», 2026-11-11, DISEGNO § 5.4)

    /// VO+J, «vai all'elemento collegato» (guida di VoiceOver per macOS, comandi di navigazione; configurazione predefinita di
    /// VoiceOver: `Global.navigateLink`), da fuori come lo fa VoiceOver: l'elemento sotto il cursore dà i suoi elementi collegati
    /// (`AXLinkedUIElements`) e il primo riceve il fuoco, come dopo ogni spostamento del cursore; l'elemento col fuoco dell'app
    /// diventa lui. Nel libro sintetico: il capoverso col richiamo della nota 1 (elemento 1) e la nota (elemento 2), andata e
    /// ritorno; il titolo non ha collegamenti. Con VoiceOver acceso, è il salto fra nota e richiamo con un comando di VoiceOver.
    /// Sull'app di prima del giro fallisce: nessun elemento ha collegamenti (`SCABOMAC_APP` = la copia di prima).
    func test_voJ_elementiCollegati_notaERichiamo_lettoDaFuori() async throws {
        let (running, app, g) = try await lancia(["--raggio-finestra", "4"])
        defer { chiudi(running) }
        func figlio(_ i: Int) -> AXUIElement? { elems(g, "AXChildren").first { indice($0) == i } }
        func fuocoDellApp() -> Int? { attr(app, "AXFocusedUIElement").flatMap { indice($0 as! AXUIElement) } }
        let titolo = try XCTUnwrap(figlio(0)), richiamo = try XCTUnwrap(figlio(1))
        XCTAssertTrue(elems(titolo, "AXLinkedUIElements").isEmpty, "il titolo non ha collegamenti")
        let daRichiamo = elems(richiamo, "AXLinkedUIElements")
        XCTAssertEqual(daRichiamo.compactMap(indice), [2], "il capoverso è collegato alla sua nota")
        XCTAssertEqual(focalizza(richiamo), .success); gira(0.3)
        XCTAssertEqual(fuocoDellApp(), 1)
        // VO+J: il cursore va al primo elemento collegato e gli dà il fuoco.
        let nota = try XCTUnwrap(daRichiamo.first)
        XCTAssertEqual(focalizza(nota), .success); gira(0.3)
        XCTAssertEqual(fuocoDellApp(), 2, "VO+J dal richiamo: il fuoco dell'app è la nota")
        let daNota = elems(nota, "AXLinkedUIElements")
        XCTAssertEqual(daNota.compactMap(indice), [1], "la nota è collegata al testo del suo richiamo")
        XCTAssertEqual(focalizza(try XCTUnwrap(daNota.first)), .success); gira(0.3)
        XCTAssertEqual(fuocoDellApp(), 1, "VO+J dalla nota: si torna al richiamo")
        print("RISULTATO voj_da_fuori {\"richiamo\":1,\"nota\":2}")
    }

    /// I comandi dei titoli di VoiceOver (VO+Comando+H e VO+Comando+Maiuscole+H, la Navigazione rapida con H e con le cifre)
    /// cercano nel contenitore il rotore del tipo che corrisponde alla chiave («This allows assistive technologies to assign
    /// keyboard commands and gestures for these common search types», AppKit, `NSAccessibilityCustomRotor.h`; in VoiceOver
    /// `hasCustomRotorMatchingSearchKey:`). Da fuori, la stessa ricerca per chiave sul gruppo trova TUTTI i titoli del libro, anche
    /// quelli fuori dalla finestra dei figli (sei titoli, finestra di nove elementi), avanti e indietro, e per livello; il
    /// titolo lontano, ricevuto il fuoco, entra fra i figli. Passa anche sull'app di prima: è la guardia di ciò che c'era già.
    func test_comandiDeiTitoli_ricercaPerChiave_tuttiITitoli_lettoDaFuori() async throws {
        let (running, app, g) = try await lancia(["--raggio-finestra", "4"])
        defer { chiudi(running) }
        func figlio(_ i: Int) -> AXUIElement? { elems(g, "AXChildren").first { indice($0) == i } }
        func cerca(_ chiave: String, da: AXUIElement, avanti: Bool) -> [Int] {
            let p: [String: Any] = ["AXSearchKey": [chiave], "AXStartElement": da,
                                    "AXDirection": avanti ? "AXDirectionNext" : "AXDirectionPrevious", "AXResultsLimit": 30]
            var v: CFTypeRef?
            guard AXUIElementCopyParameterizedAttributeValue(g, "AXResultsForSearchPredicate" as CFString, p as CFDictionary, &v) == .success,
                  let r = v as? [[String: Any]] else { return [] }
            return r.compactMap { ($0["AXSearchResultElement"]).flatMap { indice($0 as! AXUIElement) } }
        }
        let esposti = Set(elems(g, "AXChildren").compactMap(indice))
        XCTAssertFalse(esposti.contains(16), "il titolo 16 è fuori dalla finestra dei figli")
        let primo = try XCTUnwrap(figlio(1)), ultimo = try XCTUnwrap(figlio(23))
        XCTAssertEqual(cerca("AXHeadingSearchKey", da: primo, avanti: true), [4, 8, 12, 16, 20])
        XCTAssertEqual(cerca("AXHeadingLevel1SearchKey", da: primo, avanti: true), [4, 8, 12, 16, 20])
        XCTAssertEqual(cerca("AXHeadingSearchKey", da: ultimo, avanti: false), [20, 16, 12, 8, 4, 0])
        // Il cursore va sul titolo lontano e gli dà il fuoco: l'app lo dice col fuoco e lo espone fra i figli.
        let p: [String: Any] = ["AXSearchKey": ["AXHeadingSearchKey"], "AXStartElement": ultimo, "AXDirection": "AXDirectionPrevious",
                                "AXResultsLimit": 3]
        var v: CFTypeRef?
        XCTAssertEqual(AXUIElementCopyParameterizedAttributeValue(g, "AXResultsForSearchPredicate" as CFString, p as CFDictionary, &v), .success)
        let lontano = try XCTUnwrap(((v as? [[String: Any]])?.last?["AXSearchResultElement"])) as! AXUIElement
        XCTAssertEqual(indice(lontano), 12)
        XCTAssertEqual(focalizza(lontano), .success); gira(0.3)
        XCTAssertEqual(attr(app, "AXFocusedUIElement").flatMap { indice($0 as! AXUIElement) }, 12)
        XCTAssertTrue(Set(elems(g, "AXChildren").compactMap(indice)).contains(12), "il titolo raggiunto è fra i figli")
        print("RISULTATO titoli_da_fuori {\"avanti\":5,\"indietro\":6}")
    }
}
