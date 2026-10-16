//
//  ScaboMacApp.swift
//  ScaboMac
//
//  Punto d'ingresso dell'app Mac. La finestra principale è l'officina (giro «costruzione della linea Mac»,
//  2026-10-16): prepara la lettura di un PDF con la catena condivisa con l'iPad più il modello d'impaginazione, e la
//  manda all'iPad con AirDrop o la salva per il cavo. Le Impostazioni hanno la scheda «Strumenti» (il pannello), che si
//  apre anche dal menu con Cmd+Shift+M. L'annunciatore è quello VoiceOver reale. Il servizio dei modelli è quello vero
//  (scaricamento reale di GLM-OCR attraverso il servizio XPC, «Verifica», rimozione completa).
//

import ScaboMacKit
import SwiftUI

@main
struct ScaboMacApp: App {
    @StateObject private var model = ScaboMacApp.makeModel()
    @StateObject private var officina = OfficinaViewModel(announcer: VoiceOverAnnouncer())
    @Environment(\.openSettings) private var openSettings

    var body: some Scene {
        WindowGroup(Testi.finestraTitolo) {
            OfficinaView(model: officina) { openSettings() }
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
        var problema: String?
        do {
            catalog = try CatalogLoader.loadBundled()
        } catch {
            // Catalogo malformato o assente: l'app si apre comunque, con un catalogo vuoto e la spiegazione in prosa
            // MOSTRATA in testa al pannello (e nel registro di sistema), mai un crash né un silenzio.
            problema = (error as? CatalogError)?.spiegazione ?? Testi.catalogoMalformato
            NSLog("%@", Testi.catalogoProblemaAvvio(problema!))
            catalog = ModelCatalog(schemaVersione: ModelCatalog.schemaVersioneCorrente, aggiornatoIl: "", voci: [])
        }
        // Il servizio VERO (giro del 2026-10-16): scaricamento reale attraverso il servizio XPC, pesi nel contenitore.
        let service = RealModelService(catalog: catalog)
        // Prova del laboratorio (solo con l'argomento esplicito): percorso reale del pannello, poi l'app si chiude.
        if ProvaPannello.richiesta { ProvaPannello.esegui(catalog: catalog) }
        return PanelViewModel(service: service, announcer: VoiceOverAnnouncer(), problemaCatalogo: problema)
    }
}
