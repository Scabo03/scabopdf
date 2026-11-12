//
//  ScaboMacApp.swift
//  ScaboMac — il punto d'ingresso di ScaboPDF per Mac, l'APP UNICA del Mac (giro «app unica per Mac, tappa A», 2026-11-08;
//  LAYER2 § 12.16, decisioni 8-10). È l'app dell'iPad — Home, importazione, libreria, lettura — più la finestra in più dei
//  modelli, dove l'officina di prima vive intatta: il pannello dei modelli e la preparazione della lettura migliore con
//  l'esportazione del pacchetto per l'iPad. Dal giro «ScaboPDF per Mac su TestFlight» (2026-11-12) anche il pannello
//  «Diagnostica» (nascosto; lo mostra una scelta delle Impostazioni): il diario, la variante dei titoli, le prove guidate.
//
//  Il ciclo di vita è AppKit (delegato e menu in codice): la lettura è AppKit puro (DISEGNO_LETTURA_MAC § 2), le viste
//  dell'officina restano SwiftUI e si ospitano in una finestra. Finestre: la Home (principale), una finestra di lettura per
//  libro, «Modelli e officina» (⌘⇧M), le Impostazioni di lettura (⌘,).
//
//  Argomenti di lancio per le prove (nessuno cambia ciò che l'app fa per l'utente):
//    --libreria-di-prova      una libreria a parte, svuotata all'avvio (i test non toccano la libreria vera)
//    --libreria-di-prova-continua  la stessa libreria a parte, senza svuotarla (prove su due lanci)
//    --libro-di-prova         scrive il PDF sintetico (ScaboMacLettura `LibroSintetico`) e lo importa col percorso vero
//    --importa <percorso>     importa un file che sta già nel contenitore dell'app
//    --descrivi-in <percorso> appena una lettura si apre, scrive lì la sua descrizione dalla vista (formato 2) e quella del
//                             modulo accanto (`.modulo.jsonl`), per il confronto da fuori
//    --diario <percorso>      il diario della diagnostica (`Diagnostica`) in quel file invece che nella sua cartella, riscritto
//                             intero ogni due secondi (su un filo a parte) e all'uscita: le richieste d'accessibilità della
//                             lettura, i fermi del filo principale (sentinella dall'avvio), le fasi dell'apertura, i tasti arrivati
//                             all'app e la finestra in primo piano, solo codici (i test e il laboratorio)
//    --variante-titoli <A|B|C|D>  la variante dei titoli per questo lancio, senza salvarla (i test da fuori)
//    --apri-primo             apre all'avvio il primo libro dell'elenco della Home (misure di tempi e memoria)
//    --raggio-finestra <n>    i figli finestrati con una finestra di 2n+1 elementi invece di 401 (prove d'orecchio e test da fuori)
//    -ScaboMacProvaPannello   la prova del laboratorio sul pannello (giro del 2026-10-16), poi l'app si chiude
//
import AppKit
import ScaboChain
import ScaboCore
import ScaboMacKit
import ScaboMacLettura
import SwiftUI

/// La finestra in più: il pannello dei modelli e l'officina, scelti con un selettore in alto (un controllo solo, senza i
/// gruppi muti che le schede di SwiftUI aggiungono attorno alla pagina; rilievo dell'audit di sistema, presente anche
/// nell'officina di prima).
struct ModelliEOfficinaView: View {
    @ObservedObject var pannello: PanelViewModel
    @ObservedObject var officina: OfficinaViewModel
    @State private var scheda = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker(Parole.modelliEOfficina, selection: $scheda) {
                Text(Parole.schedaModelli).tag(0)
                Text(Parole.schedaOfficina).tag(1)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityIdentifier("modelli.scheda")
            if scheda == 0 {
                ModelsPanelView(model: pannello)
            } else {
                OfficinaView(model: officina) { scheda = 0 }
                    .environmentObject(pannello)
            }
        }
        .padding(8)
        .frame(minWidth: 680, minHeight: 540)
        // Il contenitore ha un nome: l'audit di sistema non vuole gruppi muti, e VoiceOver lo dice entrando.
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Parole.modelliEOfficina)
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
    /// La diagnostica dell'app: il diario (uno solo per l'app, dall'avvio se acceso, dato a ogni finestra di lettura), la
    /// variante dei titoli, il pannello.
    private var diagnostica: Diagnostica!
    private var finestraDiagnostica: FinestraDiagnostica?
    /// La libreria a parte della prova guidata (la libreria vera non si tocca), tenuta viva finché serve.
    private var prova: (libreria: LibreriaMac, importazione: ImportazioneMac, presentatore: PresentatoreAppKit)?
    /// L'ultima richiesta d'apertura per libro e in assoluto (la preparazione gira su un filo a parte).
    private var richiesteDiApertura: [String: UUID] = [:]
    private var ultimaRichiesta: UUID?

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
        if let r = argomento("--raggio-finestra").flatMap(Int.init), r >= 1 {
            // Solo per le prove: una finestra di figli piccola, per sentire la svolta della finestra sul libro sintetico.
            VistaLettura.raggioFinestra = r
            VistaLettura.margineFinestra = max(1, r / 4)
        }
        let service: LibraryService
        var radiceProve: URL?
        if argomenti.contains("--libreria-di-prova") || argomenti.contains("--libreria-di-prova-continua") {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let radice = support.appendingPathComponent("ScaboPDF-prove", isDirectory: true)
            if argomenti.contains("--libreria-di-prova") { try? FileManager.default.removeItem(at: radice) }
            service = LibraryService(rootDirectory: radice, prefs: InMemoryKeyValueStore())
            radiceProve = radice
        } else {
            service = LibraryService.shared
        }
        // La variante dei titoli: quella scelta nel pannello (la C se nessuno ha scelto), o quella dell'argomento di prova.
        VarianteTitoli.attiva = argomento("--variante-titoli").flatMap { VarianteTitoli.Lettera(rawValue: $0.uppercased()) }
            ?? PreferenzeDiagnostica.variante(service.prefs)
        // Il diario dall'avvio, se il maintainer l'ha lasciato acceso (o col file dell'argomento di prova), con la sentinella del
        // filo principale: così copre anche l'importazione e l'apertura. Si scrive ogni due secondi su un filo a parte.
        // Con la libreria di prova anche il diario sta nella sua cartella (i test non scrivono fra i diari veri).
        diagnostica = Diagnostica(prefs: service.prefs,
                                  cartella: radiceProve?.appendingPathComponent("Diagnostica", isDirectory: true) ?? Diagnostica.cartellaStandard())
        diagnostica.visteAperte = { [weak self] in self?.letture.map(\.vista) ?? [] }
        if let path = argomento("--diario") {
            diagnostica.accendi(su: URL(fileURLWithPath: path), motivo: "argomento")
        } else if PreferenzeDiagnostica.diarioAcceso(service.prefs) {
            diagnostica.accendi(motivo: "avvio")
        }
        MenuPrincipale.voceDiagnostica(in: NSApp.mainMenu)?.isHidden = !PreferenzeDiagnostica.mostrata(service.prefs)
        pannello = Self.makeModel()
        officina = OfficinaViewModel(announcer: VoiceOverAnnouncer())
        libreria = LibreriaMac(service: service)
        // Un libro eliminato chiude la sua finestra di lettura, se è aperta.
        libreria.quandoElimina.append { [weak self] id in
            self?.letture.filter { $0.documentId == id }.forEach { $0.window?.close() }
        }
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
            // Lo stesso file da un lancio all'altro (un PDF riscritto porterebbe date nuove, quindi un'impronta nuova): così
            // «Libro già presente» si prova anche da fuori.
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("Libro di prova.pdf")
            if FileManager.default.fileExists(atPath: url.path) || (try? LibroSintetico.scrivi(in: url)) != nil { fileInArrivo.append(url) }
        }
        if let p = argomento("--importa") { fileInArrivo.append(URL(fileURLWithPath: p)) }
        if !fileInArrivo.isEmpty {
            importazione.importa(fileInArrivo)
            fileInArrivo.removeAll()
        } else if argomenti.contains("--apri-primo"), let primo = libreria.libri().first {
            importazione.apri(primo.id)
        } else if let ultimo = service.store.lastOpenDocumentId {
            // Riapertura all'avvio (§ 2.5): l'ultimo libro lasciato aperto, solo se la sua lettura in cache si apre; mai una
            // rielaborazione all'avvio, come l'iPad.
            importazione.riapriAllAvvio(ultimo)
        }
    }

    // I tasti e le finestre nel diario: `Diagnostica` (dal giro «ScaboPDF per Mac su TestFlight», 2026-11-12).

    // MARK: Le finestre

    /// Apre il libro in una finestra sua. La preparazione (modello del parlato e indice delle ancore, secondi sul volume più
    /// grande) gira su un filo a parte; il filo principale resta libero e costruisce la finestra quando è pronta.
    /// `libreria`: quella del libro (la libreria a parte della prova guidata; di solito quella dell'app). `raggio`: la finestra
    /// dei figli di questa lettura (la prova guidata con la finestra piccola), altrimenti quella di sempre.
    @MainActor private func apriFinestraDiLettura(_ doc: ArchivedDocument, _ lettura: LibraryReading,
                                                  libreria lib: LibreriaMac? = nil, raggio: Int? = nil) {
        // Ogni richiesta ha un segno: alla fine della preparazione si apre solo se è ancora l'ultima per quel libro, e va davanti
        // solo se è l'ultima in assoluto (rilievo della revisione del giro: un libro chiesto due volte, due libri di fila).
        let segno = UUID()
        richiesteDiApertura[doc.id] = segno
        ultimaRichiesta = segno
        let diario = diagnostica.diario
        diario?.registraFatto(-3, "apertura:preparazione:inizio")
        let t0 = Date()
        let app = RiferimentoApp(app: self)
        DispatchQueue.global(qos: .userInitiated).async {
            let preparazione = PreparazioneLettura(documento: doc, lettura: lettura)
            let ms = Int(Date().timeIntervalSince(t0) * 1000)
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    diario?.registraFatto(-3, "apertura:preparazione:\(ms)ms")
                    app.app?.mostraFinestraDiLettura(doc, lettura, preparazione, segno: segno, libreria: lib, raggio: raggio)
                }
            }
        }
    }

    /// Il riferimento debole all'app che attraversa il filo della preparazione (usato solo sul filo principale).
    private struct RiferimentoApp: @unchecked Sendable { weak var app: ScaboMacApp? }

    @MainActor private func mostraFinestraDiLettura(_ richiesto: ArchivedDocument, _ lettura: LibraryReading,
                                                    _ preparazione: PreparazioneLettura, segno: UUID,
                                                    libreria lib: LibreriaMac? = nil, raggio: Int? = nil) {
        let libreria: LibreriaMac = lib ?? self.libreria
        // Una richiesta più recente per lo stesso libro prende il posto di questa; un libro eliminato intanto non si apre; il
        // documento si rilegge dalla libreria, con la posizione di adesso.
        guard richiesteDiApertura[richiesto.id] == segno else { diagnostica.diario?.registraFatto(-3, "apertura:superata"); return }
        richiesteDiApertura[richiesto.id] = nil
        guard let doc = libreria.service.store.document(id: richiesto.id) else {
            diagnostica.diario?.registraFatto(-3, "apertura:libro-eliminato"); return
        }
        if let aperta = letture.first(where: { $0.documentId == doc.id }) {
            aperta.chiusaPerSostituzione = true
            aperta.window?.close()
        }
        let t0 = Date()
        let f = FinestraLettura(documento: doc, lettura: lettura, libreria: libreria, preparazione: preparazione)
        if let r = raggio { f.vista.impostaFinestra(raggio: r) }
        diagnostica.collega(f.vista)
        f.quandoSiChiude = { [weak self] chiusa in
            self?.letture.removeAll { $0 === chiusa }
            self?.diagnostica.scriviInSottofondo()
        }
        letture.append(f)
        f.mostra(inPrimoPiano: segno == ultimaRichiesta)
        diagnostica.diario?.registraFatto(-3, "apertura:elementi:\(f.vista.conteggio)")
        diagnostica.diario?.registraFatto(-3, "apertura:finestra:\(Int(Date().timeIntervalSince(t0) * 1000))ms")
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
            guard let d = diagnostica?.diario else { return }
            d.registraFatto(-3, "uscita")
            diagnostica.scriviAdesso()
        }
    }

    // MARK: ComandiApp

    @objc func importaDocumento(_ sender: Any?) {
        MainActor.assumeIsolated {
            mostraHome(nil)
            guard let w = home.window else { return }
            let pannello = NSOpenPanel()
            pannello.allowedContentTypes = [.pdf, .xml]
            pannello.allowsMultipleSelection = false
            pannello.canChooseDirectories = false
            pannello.message = LibraryWording.importDocument
            let scelto: (NSApplication.ModalResponse) -> Void = { [weak self] r in
                guard r == .OK, let url = pannello.url else { return }
                self?.importazione.importa(url)   // durante un'elaborazione entra in coda
            }
            // Durante un'elaborazione la Home ha già il suo foglio: il pannello si apre come finestra a sé.
            if importazione.occupato { pannello.begin(completionHandler: scelto) } else { pannello.beginSheetModal(for: w, completionHandler: scelto) }
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
                let ospite = NSHostingController(rootView: ModelliEOfficinaView(pannello: pannello, officina: officina))
                let w = NSWindow(contentViewController: ospite)
                // La vista SwiftUI è il primo risponditore: così Tab gira fra i suoi controlli, come nella finestra
                // delle impostazioni dell'officina di prima.
                w.initialFirstResponder = ospite.view
                ospite.view.setAccessibilityLabel(Parole.modelliEOfficina)
                w.title = Parole.modelliEOfficina
                w.setAccessibilityIdentifier("modelli.finestra")
                w.isReleasedWhenClosed = false
                w.setFrameAutosaveName("modelliEOfficina")
                modelli = NSWindowController(window: w)
            }
            modelli?.showWindow(nil)
            modelli?.window?.makeKeyAndOrderFront(nil)
            if let w = modelli?.window, let v = w.contentView { w.makeFirstResponder(v) }
        }
    }

    @objc func mostraImpostazioni(_ sender: Any?) {
        MainActor.assumeIsolated {
            if impostazioni == nil {
                impostazioni = FinestraImpostazioni(prefs: libreria.prefs)
                // Le note a voce valgono subito anche nei libri aperti.
                impostazioni?.quandoCambianoLeNote = { [weak self] in self?.letture.forEach { $0.aggiornaImpostazioni() } }
                // «Mostra il menu Diagnostica»: la voce del menu «Finestra» compare o sparisce; nascondendola, il diario si spegne
                // e il pannello si chiude (nessuno strumento resta acceso senza che si veda).
                impostazioni?.quandoCambiaLaDiagnostica = { [weak self] si in
                    guard let self else { return }
                    MenuPrincipale.voceDiagnostica(in: NSApp.mainMenu)?.isHidden = !si
                    if !si {
                        self.diagnostica.spegni()
                        PreferenzeDiagnostica.impostaDiario(self.libreria.prefs, false)
                        self.finestraDiagnostica?.close()
                    }
                }
            }
            impostazioni?.window?.center()
            impostazioni?.showWindow(nil)
            impostazioni?.window?.makeKeyAndOrderFront(nil)
        }
    }

    @objc func mostraDiagnostica(_ sender: Any?) {
        MainActor.assumeIsolated {
            if finestraDiagnostica == nil {
                let f = FinestraDiagnostica(diagnostica: diagnostica)
                f.quandoCambiaIlDiario = { [weak self] si in
                    guard let self else { return }
                    PreferenzeDiagnostica.impostaDiario(self.libreria.prefs, si)
                }
                f.quandoCambiaLaVariante = { [weak self] l in
                    guard let self else { return }
                    PreferenzeDiagnostica.impostaVariante(self.libreria.prefs, l)
                    VarianteTitoli.attiva = l
                    self.letture.forEach { $0.vista.titoliCambiati() }
                    self.diagnostica.annota("variante-titoli:\(l.rawValue)")
                }
                f.quandoApreIlLibroDiProva = { [weak self] piccola in self?.apriLibroDiProva(finestraPiccola: piccola) }
                finestraDiagnostica = f
            }
            finestraDiagnostica?.aggiorna()
            finestraDiagnostica?.window?.center()
            finestraDiagnostica?.showWindow(nil)
            finestraDiagnostica?.window?.makeKeyAndOrderFront(nil)
        }
    }

    /// LA PROVA GUIDATA (pannello «Diagnostica»): il libro sintetico che l'app scrive da sé (`LibroSintetico`, nessun testo dei
    /// volumi), importato col percorso vero in una libreria A PARTE, svuotata a ogni prova (`Application Support/ScaboPDF-prove`,
    /// la stessa dell'argomento `--libreria-di-prova`: la libreria vera non si tocca), con le impostazioni di partenza e, se
    /// chiesto, la finestra dei figli piccola, di tre elementi. Se il diario è spento, si accende (e resta acceso).
    @MainActor private func apriLibroDiProva(finestraPiccola: Bool) {
        if !diagnostica.acceso {
            diagnostica.accendi(motivo: "prova-guidata")
            PreferenzeDiagnostica.impostaDiario(libreria.prefs, true)
        }
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let radice = support.appendingPathComponent("ScaboPDF-prove", isDirectory: true)
        letture.filter { $0.documentId == prova?.libreria.libri().first?.id }.forEach { $0.window?.close() }
        try? FileManager.default.removeItem(at: radice)
        let lib = LibreriaMac(service: LibraryService(rootDirectory: radice, prefs: InMemoryKeyValueStore()))
        let imp = ImportazioneMac(libreria: lib)
        let raggio: Int? = finestraPiccola ? 1 : nil
        let pres = PresentatoreAppKit(finestra: finestraDiagnostica?.window ?? home.window) { [weak self] doc, lettura in
            self?.apriFinestraDiLettura(doc, lettura, libreria: lib, raggio: raggio)
        }
        imp.presentatore = pres
        prova = (lib, imp, pres)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Libro di prova.pdf")
        guard FileManager.default.fileExists(atPath: url.path) || (try? LibroSintetico.scrivi(in: url)) != nil else { return }
        diagnostica.annota("prova-guidata:libro-di-prova:finestra-\(finestraPiccola ? "piccola" : "normale")")
        imp.importa(url)
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
