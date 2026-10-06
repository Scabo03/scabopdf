//
//  ScaboMacApp.swift
//  ScaboMac
//
//  Punto d'ingresso dell'app Mac. Una finestra principale minima, le Impostazioni con la scheda «Strumenti»
//  (il pannello), e un comando di menu con scorciatoia (Cmd+Shift+M) che apre lo stesso pannello.
//  Il servizio dei modelli è la simulazione dichiarata; l'annunciatore è quello VoiceOver reale.
//

import ScaboMacKit
import SwiftUI

@main
struct ScaboMacApp: App {
    @StateObject private var model = ScaboMacApp.makeModel()
    @Environment(\.openSettings) private var openSettings

    var body: some Scene {
        WindowGroup(Testi.finestraTitolo) {
            MainWindowView { openSettings() }
                .environmentObject(model)
        }
        .commands {
            CommandMenu(Testi.impostazioniScheda) {
                Button(Testi.menuStrumenti) { openSettings() }
                    .keyboardShortcut("m", modifiers: [.command, .shift])
            }
        }
        Settings {
            TabView {
                ModelsPanelView(model: model)
                    .tabItem { Label(Testi.impostazioniScheda, systemImage: "wrench.and.screwdriver") }
            }
            .frame(minWidth: 640, minHeight: 520)
        }
    }

    @MainActor
    static func makeModel() -> PanelViewModel {
        let catalog: ModelCatalog
        do {
            catalog = try CatalogLoader.loadBundled()
        } catch {
            // Catalogo malformato o assente: l'app si apre comunque, con un catalogo vuoto e la spiegazione.
            // (La validazione è coperta dai test; qui si degrada in prosa invece di andare in crash.)
            NSLog("%@", Testi.catalogoProblemaAvvio((error as? CatalogError)?.spiegazione ?? Testi.catalogoMalformato))
            catalog = ModelCatalog(schemaVersione: ModelCatalog.schemaVersioneCorrente, aggiornatoIl: "", voci: [])
        }
        let service = SimulatedModelService(catalog: catalog)
        return PanelViewModel(service: service, announcer: VoiceOverAnnouncer())
    }
}
