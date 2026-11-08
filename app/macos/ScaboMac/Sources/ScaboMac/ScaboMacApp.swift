//
//  ScaboMacApp.swift
//  ScaboMac — il punto d'ingresso di ScaboPDF per Mac, l'APP UNICA del Mac (giro «app unica per Mac, tappa A», 2026-11-08;
//  LAYER2 § 12.16, decisioni 8-10). È l'app dell'iPad — Home, importazione, libreria, lettura — più la finestra in più dei
//  modelli, dove l'officina di prima vive intatta: il pannello dei modelli e la preparazione della lettura migliore con
//  l'esportazione del pacchetto per l'iPad.
//
//  Il ciclo di vita è AppKit (delegato e menu in codice): la lettura è AppKit puro (DISEGNO_LETTURA_MAC § 2), le viste
//  dell'officina restano SwiftUI e si ospitano in una finestra. Finestre: la Home (principale), una finestra di lettura per
//  libro, «Modelli e officina» (⌘⇧M), le Impostazioni di lettura (⌘,).
//
//  Argomenti di lancio per le prove (nessuno cambia ciò che l'app fa per l'utente):
//    --libreria-di-prova      una libreria a parte, svuotata all'avvio (i test non toccano la libreria vera)
//    --libro-di-prova         scrive il PDF sintetico (ScaboMacLettura `LibroSintetico`) e lo importa col percorso vero
//    --importa <percorso>     importa un file che sta già nel contenitore dell'app
//    --descrivi-in <percorso> appena una lettura si apre, scrive lì la sua descrizione dalla vista (formato 2) e quella del
//                             modulo accanto (`.modulo.jsonl`), per il confronto da fuori
//    --diario <percorso>      registra le richieste d'accessibilità della lettura e le scrive lì all'uscita
//    --segnali-acustici       accende i segnali delle note al gancio del fuoco (prove d'orecchio)
//    -ScaboMacProvaPannello   la prova del laboratorio sul pannello (giro del 2026-10-16), poi l'app si chiude
//
import AppKit
import ScaboChain
import ScaboCore
import ScaboMacKit
import ScaboMacLettura
import SwiftUI

/// La finestra in più: il pannello dei modelli e l'officina, in due schede.
struct ModelliEOfficinaView: View {
    @ObservedObject var pannello: PanelViewModel
    @ObservedObject var officina: OfficinaViewModel
    @State private var scheda = 0

    var body: some View {
        TabView(selection: $scheda) {
            ModelsPanelView(model: pannello)
                .tabItem { Text(Parole.schedaModelli) }
                .tag(0)
            OfficinaView(model: officina) { scheda = 0 }
                .environmentObject(pannello)
                .tabItem { Text(Parole.schedaOfficina) }
                .tag(1)
        }
        .padding(8)
        .frame(minWidth: 680, minHeight: 540)
    }
}

@main
final class ScaboMacApp: NSObject, NSApplicationDelegate, ComandiApp {

    static func main() {
        let app = NSApplication.shared
        let delegato = ScaboMacApp()
        app.delegate = delegato
        app.setActivationPolicy(.regular)
        app.run()
    }

    private var libreria: LibreriaMac!
    private var importazione: ImportazioneMac!
    private var presentatore: PresentatoreAppKit!
    private var home: FinestraHome!
    private var letture: [FinestraLettura] = []
    private var modelli: NSWindowController?
    private var impostazioni: FinestraImpostazioni?
    private var pannello: PanelViewModel!
    private var officina: OfficinaViewModel!
    private var fileInArrivo: [URL] = []
    private var pronto = false
    private let argomenti = ProcessInfo.processInfo.arguments

    private func argomento(_ nome: String) -> String? {
        guard let i = argomenti.firstIndex(of: nome), i + 1 < argomenti.count else { return nil }
        return argomenti[i + 1]
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = MenuPrincipale.barra(comandi: self)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated { avvia() }
    }

    @MainActor private func avvia() {
        pannello = Self.makeModel()
        officina = OfficinaViewModel(announcer: VoiceOverAnnouncer())
        let service: LibraryService
        if argomenti.contains("--libreria-di-prova") {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let radice = support.appendingPathComponent("ScaboPDF-prove", isDirectory: true)
            try? FileManager.default.removeItem(at: radice)
            service = LibraryService(rootDirectory: radice, prefs: InMemoryKeyValueStore())
        } else {
            service = LibraryService.shared
        }
        libreria = LibreriaMac(service: service)
        importazione = ImportazioneMac(libreria: libreria)
        home = FinestraHome(libreria: libreria, importazione: importazione, comandi: self)
        presentatore = PresentatoreAppKit(finestra: home.window) { [weak self] doc, lettura in
            self?.apriFinestraDiLettura(doc, lettura)
        }
        importazione.presentatore = presentatore
        home.showWindow(nil)
        home.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        // I libri importati prima dell'impronta la ricevono in sottofondo, come sull'iPad.
        DocumentIdentity.fingerprintMissingDocumentsInBackground(service: service)
        pronto = true

        if argomenti.contains("--libro-di-prova") {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("Libro di prova.pdf")
            if (try? LibroSintetico.scrivi(in: url)) != nil { fileInArrivo.append(url) }
        }
        if let p = argomento("--importa") { fileInArrivo.append(URL(fileURLWithPath: p)) }
        if !fileInArrivo.isEmpty {
            importazione.importa(fileInArrivo)
            fileInArrivo.removeAll()
        } else if let ultimo = service.store.lastOpenDocumentId, let doc = service.store.document(id: ultimo),
                  service.hasCache(forDocumentId: doc.id) {
            // Riapertura all'avvio (§ 2.5): l'ultimo libro lasciato aperto, solo se la sua lettura è pronta.
            importazione.apri(doc.id)
        }
    }

    // MARK: Le finestre

    @MainActor private func apriFinestraDiLettura(_ doc: ArchivedDocument, _ lettura: LibraryReading) {
        if let aperta = letture.first(where: { $0.documentId == doc.id }) { aperta.window?.close() }
        let f = FinestraLettura(documento: doc, lettura: lettura, libreria: libreria)
        f.quandoSiChiude = { [weak self] chiusa in
            self?.letture.removeAll { $0 === chiusa }
            if let path = self?.argomento("--diario") { try? chiusa.vista.diario.scrivi(su: URL(fileURLWithPath: path)) }
        }
        letture.append(f)
        f.mostra()
        if let path = argomento("--descrivi-in") {
            let libro = (doc.sourceFileName as NSString).deletingPathExtension
            let dallaVista = f.vista.descrizioneDallaVista(libro: libro, layout: .continuousReading)
            let delModulo = f.vista.descrizioneDelModulo(libro: libro, layout: .continuousReading)
            try? dallaVista.encoded().write(to: URL(fileURLWithPath: path))
            try? delModulo.encoded().write(to: URL(fileURLWithPath: path + ".modulo.jsonl"))
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        MainActor.assumeIsolated {
            if pronto { importazione.importa(urls) } else { fileInArrivo += urls }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { mostraHome(nil) }
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        MainActor.assumeIsolated {
            if let path = argomento("--diario"), let f = letture.last { try? f.vista.diario.scrivi(su: URL(fileURLWithPath: path)) }
        }
    }

    // MARK: ComandiApp

    @objc func importaDocumento(_ sender: Any?) {
        MainActor.assumeIsolated {
            mostraHome(nil)
            guard let w = home.window, !importazione.occupato else { return }
            let pannello = NSOpenPanel()
            pannello.allowedContentTypes = [.pdf, .xml]
            pannello.allowsMultipleSelection = false
            pannello.canChooseDirectories = false
            pannello.message = LibraryWording.importDocument
            pannello.beginSheetModal(for: w) { [weak self] r in
                guard r == .OK, let url = pannello.url else { return }
                self?.importazione.importa(url)
            }
        }
    }

    @objc func mostraHome(_ sender: Any?) {
        MainActor.assumeIsolated {
            home.showWindow(nil)
            home.window?.makeKeyAndOrderFront(nil)
        }
    }

    @objc func mostraModelliEOfficina(_ sender: Any?) {
        MainActor.assumeIsolated {
            if modelli == nil {
                let w = NSWindow(contentViewController: NSHostingController(
                    rootView: ModelliEOfficinaView(pannello: pannello, officina: officina)))
                w.title = Parole.modelliEOfficina
                w.setAccessibilityIdentifier("modelli.finestra")
                w.isReleasedWhenClosed = false
                w.setFrameAutosaveName("modelliEOfficina")
                modelli = NSWindowController(window: w)
            }
            modelli?.showWindow(nil)
            modelli?.window?.makeKeyAndOrderFront(nil)
        }
    }

    @objc func mostraImpostazioni(_ sender: Any?) {
        MainActor.assumeIsolated {
            if impostazioni == nil { impostazioni = FinestraImpostazioni(prefs: libreria.prefs) }
            impostazioni?.window?.center()
            impostazioni?.showWindow(nil)
            impostazioni?.window?.makeKeyAndOrderFront(nil)
        }
    }

    // MARK: Il pannello dei modelli (invariato dall'officina)

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
        // Il servizio VERO: scaricamento reale attraverso il servizio XPC, pesi nel contenitore.
        let service = RealModelService(catalog: catalog)
        // Prova del laboratorio (solo con l'argomento esplicito): percorso reale del pannello, poi l'app si chiude.
        if ProvaPannello.richiesta { ProvaPannello.esegui(catalog: catalog) }
        return PanelViewModel(service: service, announcer: VoiceOverAnnouncer(), problemaCatalogo: problema)
    }
}
