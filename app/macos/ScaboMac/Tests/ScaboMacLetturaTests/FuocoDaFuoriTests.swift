//
//  FuocoDaFuoriTests.swift
//  ScaboMacLetturaTests — il salto fra nota e richiamo LETTO DA FUORI (giro «prove della tappa A», 2026-11-09). Lancia l'app vera
//  (`build/ScaboPDF.app`, assemblata da `scripts/build_app.sh`) con la libreria di prova e il libro sintetico, ed esegue le
//  azioni come le esegue VoiceOver: «Vai alla nota N» e «Vai al testo del richiamo» con l'API C d'accessibilità
//  (AXPerformAction col nome dell'azione personalizzata), la voce «Nota e richiamo» del menu «Lettura» premuta per
//  l'accessibilità (come da VO+M). Dopo ognuna misura ciò che VoiceOver usa per spostare il cursore: l'elemento col fuoco
//  dell'APP (`AXFocusedUIElement`, che VoiceOver chiede dall'alto della finestra a ogni avviso) e l'avviso
//  «AXFocusedUIElementChanged» arrivato a un osservatore, col bersaglio. Prima della cura il fuoco dell'app restava il
//  gruppo e il cursore non si muoveva (diario della prova T3).
//
//  Serve un processo fidato per l'accessibilità (il Terminale del Mac di sviluppo, da cui si lancia `swift test`): altrimenti il
//  test si salta col motivo, come senza l'app assemblata. Nessun tasto sintetico. Contenuti sintetici: nessun testo dei volumi.
//
import AppKit
import ApplicationServices
import XCTest

@MainActor
final class FuocoDaFuoriTests: XCTestCase {

    private static var appURL: URL {
        if let p = ProcessInfo.processInfo.environment["SCABOMAC_APP"] { return URL(fileURLWithPath: p) }
        return URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("build/ScaboPDF.app")
    }

    private func attr(_ e: AXUIElement, _ a: String) -> CFTypeRef? {
        var v: CFTypeRef?
        return AXUIElementCopyAttributeValue(e, a as CFString, &v) == .success ? v : nil
    }
    private func elems(_ e: AXUIElement, _ a: String) -> [AXUIElement] { (attr(e, a) as? [AXUIElement]) ?? [] }
    private func ident(_ e: AXUIElement) -> String { (attr(e, "AXIdentifier") as? String) ?? "" }
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

    /// Le notifiche arrivate all'osservatore: (nome, identificatore dell'elemento).
    final class Raccolta { var voci: [(String, String)] = [] }

    func test_salti_spostanoIlFuocoDellApp_lettoDaFuori() async throws {
        guard AXIsProcessTrusted() else { throw XCTSkip("il processo dei test non è un client d'accessibilità fidato") }
        let url = Self.appURL
        guard FileManager.default.fileExists(atPath: url.path) else { throw XCTSkip("manca l'app assemblata: scripts/build_app.sh") }
        guard NSRunningApplication.runningApplications(withBundleIdentifier: "com.scabo.scabopdf.mac").isEmpty else {
            throw XCTSkip("un'altra ScaboPDF è aperta")
        }
        let cfg = NSWorkspace.OpenConfiguration()
        cfg.arguments = ["--libreria-di-prova", "--libro-di-prova"]
        cfg.createsNewApplicationInstance = true
        let running = try await NSWorkspace.shared.openApplication(at: url, configuration: cfg)
        defer { running.forceTerminate() }
        let app = AXUIElementCreateApplication(running.processIdentifier)
        AXUIElementSetMessagingTimeout(app, 10)

        // La finestra di lettura, il gruppo del testo, i suoi figli.
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
        let g = try XCTUnwrap(gruppo, "la finestra di lettura si apre")
        gira(1.0)

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
        func elemento(_ id: String) -> AXUIElement? { elems(g, "AXChildren").first { ident($0) == id } }

        // «Vai alla nota N» dal capoverso che la richiama.
        let richiamo = try XCTUnwrap(elems(g, "AXChildren").first { azioni($0).contains { nome($0).hasPrefix("Vai alla nota") } },
                                     "un capoverso col richiamo")
        let idRichiamo = ident(richiamo)
        let vaiAllaNota = try XCTUnwrap(azioni(richiamo).first { nome($0).hasPrefix("Vai alla nota") })
        raccolta.voci.removeAll()
        XCTAssertEqual(AXUIElementPerformAction(richiamo, vaiAllaNota as CFString), .success)
        gira(0.8)
        let idNota = fuocoDellApp()
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
        gira(0.8)
        XCTAssertEqual(fuocoDellApp(), idRichiamo)
        XCTAssertTrue(raccolta.voci.contains { $0 == ("AXFocusedUIElementChanged", idRichiamo) }, "\(raccolta.voci)")

        // La voce del menu «Lettura» «Nota e richiamo» (⌘J), premuta per l'accessibilità: dal richiamo alla nota.
        let barra = try XCTUnwrap(attr(app, "AXMenuBar")) as! AXUIElement
        let menu = try XCTUnwrap(elems(barra, "AXChildren").first { (attr($0, "AXTitle") as? String) == "Lettura" })
        let voci = elems(menu, "AXChildren").first.map { elems($0, "AXChildren") } ?? []
        let voce = try XCTUnwrap(voci.first { ((attr($0, "AXTitle") as? String) ?? "").hasPrefix("Nota e richiamo") })
        raccolta.voci.removeAll()
        XCTAssertEqual(AXUIElementPerformAction(voce, kAXPressAction as CFString), .success)
        gira(0.8)
        XCTAssertEqual(fuocoDellApp(), idNota, "⌘J dal menu porta alla nota")
        XCTAssertTrue(raccolta.voci.contains { $0 == ("AXFocusedUIElementChanged", idNota) }, "\(raccolta.voci)")
        print("RISULTATO fuoco_da_fuori {\"richiamo\":\"\(idRichiamo)\",\"nota\":\"\(idNota)\"}")
    }
}
