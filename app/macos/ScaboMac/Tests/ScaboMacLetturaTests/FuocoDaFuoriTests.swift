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
}
