//
//  AccessibilitaVisteTests.swift
//  ScaboMacKitTests
//
//  Verifica STRUTTURALE dell'accessibilità delle viste, in-process: le viste SwiftUI vengono ospitate in una
//  finestra AppKit e si interroga l'albero di accessibilità (NSAccessibility) che VoiceOver leggerebbe —
//  senza VoiceOver, senza automazione e senza permessi di sistema (che sono il motivo per cui i test
//  d'interfaccia XCUITest non possono girare in questo ambiente: vedi README.md § «Test d'interfaccia»).
//  Si verifica: ordine degli elementi, intestazioni dei ruoli, gruppo per ogni voce con riassunto,
//  pulsanti delle azioni con etichetta, nessuna informazione affidata al solo colore (lo stato è testo).
//

import AppKit
import ScaboCore
import SwiftUI
import XCTest
@testable import ScaboMacKit

@MainActor
final class AccessibilitaVisteTests: XCTestCase {

    /// Visita ricorsiva dell'albero di accessibilità: (ruolo, etichetta/valore/titolo).
    private func walk(_ element: Any, depth: Int = 0, into out: inout [(String, String)]) {
        guard depth < 40 else { return }
        guard let ax = element as? NSAccessibilityProtocol else { return }
        let role = ax.accessibilityRole()?.rawValue ?? "?"
        let label = ax.accessibilityLabel() ?? (ax.accessibilityValue() as? String) ?? ax.accessibilityTitle() ?? ""
        out.append((role, label))
        for child in ax.accessibilityChildren() ?? [] { walk(child, depth: depth + 1, into: &out) }
    }

    private func host<V: View>(_ view: V) -> NSWindow {
        _ = NSApplication.shared
        let hosting = NSHostingView(rootView: view)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 900), styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = hosting
        // Senza un cliente di accessibilità attivo SwiftUI non costruisce i nodi: la finestra va messa a schermo e
        // all'albero va chiesta esplicitamente l'interfaccia «arricchita» (è ciò che fa VoiceOver quando si collega).
        window.orderFrontRegardless()
        hosting.setAccessibilityElement(true)
        _ = hosting.accessibilityAttributeValue(NSAccessibility.Attribute(rawValue: "AXEnhancedUserInterface"))
        hosting.setAccessibilityEnhancedUserInterfaceIfPossible()
        window.layoutIfNeeded()
        hosting.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        return window
    }

    private func elements(of window: NSWindow) -> [(String, String)] {
        var out: [(String, String)] = []
        walk(window.contentView as Any, into: &out)
        return out
    }

    func test_finestraPrincipale_intestazioneTestoPulsante_inQuestoOrdine() throws {
        let w = host(MainWindowView(apriPannello: {}))
        let els = elements(of: w).filter { !$0.1.isEmpty }
        try XCTSkipIf(els.isEmpty, "l'albero di accessibilità SwiftUI non è materializzato in questo ambiente")
        let labels = els.map { $0.1 }
        XCTAssertEqual(labels.first, Testi.finestraTitolo)
        XCTAssertTrue(labels.contains(Testi.finestraSpiegazione1))
        XCTAssertTrue(labels.contains(Testi.apriPannello))
        XCTAssertEqual(els.first { $0.1 == Testi.apriPannello }?.0, NSAccessibility.Role.button.rawValue)
    }

    func test_pannello_ruoliComeIntestazioni_vociComeGruppi_azioniComePulsanti() throws {
        let c = try CatalogLoader.loadBundled()
        let s = SimulatedModelService(catalog: c)
        let m = PanelViewModel(service: s, announcer: RecordingAnnouncer(), prefs: InMemoryKeyValueStore())
        let w = host(ModelsPanelView(model: m))
        let els = elements(of: w)
        try XCTSkipIf(els.filter { !$0.1.isEmpty }.isEmpty, "albero di accessibilità non materializzato")
        let labels = els.map { $0.1 }
        for r in ModelRole.allCases { XCTAssertTrue(labels.contains(r.nome), "manca l'intestazione del ruolo \(r.nome)") }
        // Ogni voce è un gruppo il cui riassunto porta nome, ruolo, stato e dimensione.
        for v in c.voci {
            let riassunto = Testi.riassuntoVoce(nome: v.nome, ruolo: v.ruolo.nome, stato: m.state(of: v.id).inParole,
                                                dimensione: v.dimensioneInParole, provvisoria: v.provvisoria)
            XCTAssertTrue(labels.contains(riassunto), "manca il riassunto della voce \(v.id)")
        }
        // Le azioni sono pulsanti con etichetta in prosa.
        let bottoni = els.filter { $0.0 == NSAccessibility.Role.button.rawValue }.map { $0.1 }
        XCTAssertTrue(bottoni.contains(Testi.azioneScarica))
        XCTAssertTrue(bottoni.contains(Testi.azioneVerificaSistema))
        // Ordine: il titolo del pannello precede il primo ruolo, che precede la prima voce.
        let iTitolo = labels.firstIndex(of: Testi.menuStrumenti.replacingOccurrences(of: "…", with: "")) ?? -1
        let iRuolo = labels.firstIndex(of: ModelRole.allCases[0].nome) ?? -1
        XCTAssertTrue(iTitolo >= 0 && iTitolo < iRuolo)
    }

    func test_statoNonAffidatoAlColore_ogniStatoHaTesto() {
        let stati: [ModelState] = [.nonScaricato, .inScaricamento(percento: 10), .scaricato, .rimozioneInCorso,
                                   .sistemaDisponibile, .sistemaNonDisponibile, .errore(.connessioneAssente)]
        for s in stati { XCTAssertGreaterThan(s.inParole.count, 8) }
    }
}

extension NSView {
    /// Imita il collegamento di VoiceOver: imposta l'attributo «AXEnhancedUserInterface» sull'app e sulla vista.
    func setAccessibilityEnhancedUserInterfaceIfPossible() {
        let attr = NSAccessibility.Attribute(rawValue: "AXEnhancedUserInterface")
        NSApp.accessibilitySetValue(true, forAttribute: attr)
        self.accessibilitySetValue(true, forAttribute: attr)
    }
}
