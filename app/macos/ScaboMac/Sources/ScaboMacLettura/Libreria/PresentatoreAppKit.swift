//
//  PresentatoreAppKit.swift
//  ScaboMacLettura — le schermate dell'importazione e dell'apertura sul Mac (giro «app unica per Mac, tappa A», 2026-11-08):
//  la schermata d'elaborazione bloccante, «Libro già presente», gli errori in prosa. Le parole sono quelle dell'iPad
//  (ScaboChain `ProcessingWording`, `DuplicateImport`, `LibraryWording`); gli annunci dell'avanzamento seguono la stessa regola
//  (la fase quando cambia, poi un annuncio a ogni decile, la percentuale come valore interrogabile); i segnali «in corso»,
//  «fatto» ed «errore» sono i suoni dell'iPad. Le schermate sono fogli della finestra che le chiede: mentre sono aperte il
//  resto della finestra non si raggiunge (§ 2.3), e Annulla (anche con Esc) chiude.
//
import AppKit
import ScaboChain
import ScaboCore

/// La schermata d'elaborazione bloccante (§ 12.9).
@MainActor
final class SchermataElaborazione: NSWindowController {
    private let barra = NSProgressIndicator()
    private let stato = NSTextField(labelWithString: "")
    private let annulla = NSButton(title: ProcessingWording.cancelTitle, target: nil, action: nil)
    private var annunci = ProcessingAnnouncements()
    private var processore: DocumentProcessing?
    private var consegnato = false
    /// Il testo lo legge un lettore delle scansioni: la fase d'estrazione si chiama «Lettura delle scansioni».
    var scansione = false
    private var esito: ((DocumentProcessor.Outcome, String?) -> Void)?

    init(nome: String) {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 190), styleMask: [.titled], backing: .buffered, defer: false)
        w.title = ProcessingWording.title
        w.setAccessibilityIdentifier("elaborazione.finestra")
        super.init(window: w)
        let titolo = NSTextField(labelWithString: ProcessingWording.title)
        titolo.font = .boldSystemFont(ofSize: 15)
        let file = NSTextField(labelWithString: nome)
        file.lineBreakMode = .byTruncatingMiddle
        barra.isIndeterminate = false
        barra.minValue = 0; barra.maxValue = 1
        barra.setAccessibilityElement(false)   // la percentuale la dice l'elemento di stato, una volta sola
        stato.setAccessibilityIdentifier("elaborazione.stato")
        annulla.target = self
        annulla.action = #selector(annullaPremuto)
        annulla.keyEquivalent = "\u{1b}"
        annulla.setAccessibilityIdentifier("elaborazione.annulla")
        let pila = NSStackView(views: [titolo, file, barra, stato, annulla])
        pila.orientation = .vertical
        pila.alignment = .leading
        pila.spacing = 10
        pila.edgeInsets = NSEdgeInsets(top: 18, left: 20, bottom: 18, right: 20)
        barra.widthAnchor.constraint(equalToConstant: 400).isActive = true
        w.contentView = pila
        mostraStato(fase: ProcessingWording.openingPhaseLabel, percento: 0)
    }

    required init?(coder: NSCoder) { fatalError("non si usa") }

    func avvia(su genitore: NSWindow?, fileURL: URL, nome: String, granularita: Int, dottrina: Bool,
               processore: DocumentProcessing, esito: @escaping (DocumentProcessor.Outcome, String?) -> Void) {
        self.processore = processore
        self.esito = esito
        if let genitore, let w = window { genitore.beginSheet(w) } else { showWindow(nil) }
        SegnaliMac.shared.suonaInGiro(.loading)
        processore.process(fileURL: fileURL, sourceName: nome, granularityTarget: granularita, buildDoctrine: dottrina,
                           onProgress: { [weak self] p in self?.applica(p) },
                           completion: { [weak self] o in self?.chiudi(o) })
    }

    private func applica(_ p: DocumentProcessor.Progress) {
        let frazione = ProcessingWording.clampedFraction(p.fraction)
        let percento = ProcessingWording.percent(ofClampedFraction: frazione)
        barra.doubleValue = frazione
        mostraStato(fase: p.phaseLabel, percento: percento)
        let fase = scansione && p.phaseLabel == ParoleScansioni.faseEstrazioneCatena ? ParoleScansioni.faseLettura : p.phaseLabel
        for testo in annunci.announcements(phaseLabel: fase, percent: percento, fraction: frazione) {
            NSAccessibility.post(element: window as Any, notification: .announcementRequested,
                                 userInfo: [.announcement: testo, .priority: NSAccessibilityPriorityLevel.medium.rawValue])
        }
    }

    private func mostraStato(fase faseChain: String, percento: Int) {
        let fase = scansione && faseChain == ParoleScansioni.faseEstrazioneCatena ? ParoleScansioni.faseLettura : faseChain
        stato.stringValue = ProcessingWording.statusText(phaseLabel: fase, percent: percento)
        stato.setAccessibilityLabel(fase)
        stato.setAccessibilityValue(ProcessingWording.spokenPercent(percento))
    }

    @objc private func annullaPremuto() {
        processore?.cancel()
        annulla.isEnabled = false
        chiudi(.cancelled)
    }

    private func chiudi(_ o: DocumentProcessor.Outcome) {
        guard !consegnato else { return }
        consegnato = true
        SegnaliMac.shared.ferma(.loading)
        switch o {
        case .success: SegnaliMac.shared.suona([.completion])
        case .failure: SegnaliMac.shared.suona([.error])
        case .cancelled: break
        }
        let saltate = (processore as? RisorseVisiveSaltate)?.visualResourcesMissingReason
        if let w = window, let genitore = w.sheetParent { genitore.endSheet(w) } else { window?.orderOut(nil) }
        let e = esito
        esito = nil
        e?(o, saltate)
    }
}

/// Il presentatore dell'app: fogli sulla finestra della Home; la lettura in una finestra sua.
@MainActor
public final class PresentatoreAppKit: PresentatoreImportazione {
    private weak var finestra: NSWindow?
    private var elaborazioneAperta: SchermataElaborazione?
    private var sceltaAperta: SchermataScansione?
    private let apriLetturaInFinestra: (ArchivedDocument, LibraryReading) -> Void

    public init(finestra: NSWindow?, apriLettura: @escaping (ArchivedDocument, LibraryReading) -> Void) {
        self.finestra = finestra
        self.apriLetturaInFinestra = apriLettura
    }

    public func elabora(fileURL: URL, nome: String, granularita: Int, dottrina: Bool, processore: DocumentProcessing,
                        scansione: Bool, esito: @escaping (DocumentProcessor.Outcome, String?) -> Void) {
        let s = SchermataElaborazione(nome: nome)
        s.scansione = scansione
        elaborazioneAperta = s
        s.avvia(su: finestra, fileURL: fileURL, nome: nome, granularita: granularita, dottrina: dottrina,
                processore: processore) { [weak self] o, saltate in
            self?.elaborazioneAperta = nil
            esito(o, saltate)
        }
    }

    public func chiediLibroGiaPresente(esistente: ArchivedDocument, copie: Int, scelta: @escaping (SceltaDoppione) -> Void) {
        let a = NSAlert()
        a.messageText = DuplicateImport.heading
        a.informativeText = DuplicateImport.explanation(existing: esistente, copies: copie)
        a.addButton(withTitle: DuplicateImport.openExistingTitle)       // predefinita (Invio)
        a.addButton(withTitle: DuplicateImport.importAsCopyTitle)
        let annulla = a.addButton(withTitle: DuplicateImport.cancelTitle)
        annulla.keyEquivalent = "\u{1b}"
        a.window.title = DuplicateImport.screenTitle
        a.window.setAccessibilityIdentifier("doppione.finestra")
        let rispondi: (NSApplication.ModalResponse) -> Void = { r in
            switch r {
            case .alertFirstButtonReturn: scelta(.apriQuelloCheHai)
            case .alertSecondButtonReturn: scelta(.importaComeCopia)
            default: scelta(.annulla)
            }
        }
        if let finestra { a.beginSheetModal(for: finestra, completionHandler: rispondi) } else { rispondi(a.runModal()) }
    }

    public func scegliLettoreScansioni(nome: String, senzaTesto: Int, totale: Int, lettori: [LettoreDisponibile], predefinito: String,
                                       apriPannello: @escaping () -> Void, scelta: @escaping (String?) -> Void) {
        let s = SchermataScansione(nome: nome, senzaTesto: senzaTesto, totale: totale, lettori: lettori, predefinito: predefinito,
                                   apriPannello: apriPannello)
        sceltaAperta = s
        s.mostra(su: finestra) { [weak self] id in
            self?.sceltaAperta = nil
            scelta(id)
        }
    }

    public func proponiAltroLettore(messaggio: String, altro: LettoreDisponibile, risposta: @escaping (Bool) -> Void) {
        let a = NSAlert()
        a.alertStyle = .warning
        a.messageText = ParoleScansioni.altroLettoreTitolo
        a.informativeText = messaggio
        a.addButton(withTitle: ParoleScansioni.leggiConNome(altro.nome))   // predefinita (Invio)
        let annulla = a.addButton(withTitle: ParoleScansioni.annulla)
        annulla.keyEquivalent = "\u{1b}"
        a.window.setAccessibilityIdentifier("scansione.altroLettore")
        let rispondi: (NSApplication.ModalResponse) -> Void = { r in risposta(r == .alertFirstButtonReturn) }
        if let finestra { a.beginSheetModal(for: finestra, completionHandler: rispondi) } else { rispondi(a.runModal()) }
    }

    public func mostraErrore(_ messaggio: String) {
        let a = NSAlert()
        a.alertStyle = .warning
        a.messageText = LibraryWording.errorTitle
        a.informativeText = messaggio
        a.addButton(withTitle: LibraryWording.errorDismiss)
        if let finestra { a.beginSheetModal(for: finestra) } else { a.runModal() }
    }

    public func apriLettura(documento: ArchivedDocument, lettura: LibraryReading) {
        apriLetturaInFinestra(documento, lettura)
    }
}

/// LA SCHERMATA DELLA SCANSIONE (giro «modelli e scansioni», 2026-11-18; LAYER2 § 12.16, decisione 21): dice che il PDF è una
/// scansione, fa scegliere il lettore (il predefinito già scelto) e avvia. Ordine per VoiceOver: titolo, spiegazione, scelta del
/// lettore (pulsanti d'opzione in un gruppo che si chiama come la domanda), l'avviso del lettore non installato col pulsante del
/// pannello dei modelli, Avvia, Annulla. Invio avvia, Esc annulla.
@MainActor
final class SchermataScansione: NSWindowController {
    private var opzioni: [(id: String, bottone: NSButton)] = []
    private var esito: ((String?) -> Void)?
    private let apriPannello: () -> Void
    private let avvia = NSButton(title: ParoleScansioni.avvia, target: nil, action: nil)

    init(nome: String, senzaTesto: Int, totale: Int, lettori: [LettoreDisponibile], predefinito: String, apriPannello: @escaping () -> Void) {
        self.apriPannello = apriPannello
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 300), styleMask: [.titled], backing: .buffered, defer: false)
        w.title = ParoleScansioni.titolo
        w.setAccessibilityIdentifier("scansione.finestra")
        super.init(window: w)
        let titolo = NSTextField(labelWithString: ParoleScansioni.titolo)
        titolo.font = .boldSystemFont(ofSize: 15)
        titolo.setAccessibilityRole(.staticText)
        let spiegazione = NSTextField(wrappingLabelWithString: ParoleScansioni.spiegazione(nome: nome, senzaTesto: senzaTesto, totale: totale))
        spiegazione.setAccessibilityIdentifier("scansione.spiegazione")
        let domanda = NSTextField(labelWithString: ParoleScansioni.sceltaLettore)
        domanda.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
        domanda.setAccessibilityElement(false)
        let gruppo = NSStackView()
        gruppo.orientation = .vertical
        gruppo.alignment = .leading
        gruppo.setAccessibilityElement(true)
        gruppo.setAccessibilityRole(.radioGroup)
        gruppo.setAccessibilityLabel(ParoleScansioni.sceltaLettore)
        var mancanti: [LettoreDisponibile] = []
        let scelto = lettori.first { $0.id == predefinito && $0.installato }?.id ?? lettori.first { $0.installato }?.id
        for l in lettori {
            let nomeVisto = l.nome.prefix(1).uppercased() + l.nome.dropFirst()
            let b = NSButton(radioButtonWithTitle: "\(nomeVisto): \(l.descrizione)", target: nil, action: #selector(sceltaCambiata(_:)))
            b.target = self
            b.isEnabled = l.installato
            b.state = l.id == scelto ? .on : .off
            b.setAccessibilityIdentifier("scansione.lettore.\(l.id)")
            gruppo.addArrangedSubview(b)
            opzioni.append((l.id, b))
            if !l.installato { mancanti.append(l) }
        }
        var viste: [NSView] = [titolo, spiegazione, domanda, gruppo]
        for l in mancanti {
            let nota = NSTextField(wrappingLabelWithString: ParoleScansioni.nonInstallato(l.nome))
            nota.setAccessibilityIdentifier("scansione.nonInstallato.\(l.id)")
            let pannello = NSButton(title: ParoleScansioni.apriPannello, target: self, action: #selector(apriPannelloPremuto))
            pannello.setAccessibilityIdentifier("scansione.apriPannello")
            viste += [nota, pannello]
        }
        avvia.target = self
        avvia.action = #selector(avviaPremuto)
        avvia.keyEquivalent = "\r"
        avvia.isEnabled = scelto != nil
        avvia.setAccessibilityIdentifier("scansione.avvia")
        let annulla = NSButton(title: ParoleScansioni.annulla, target: self, action: #selector(annullaPremuto))
        annulla.keyEquivalent = "\u{1b}"
        annulla.setAccessibilityIdentifier("scansione.annulla")
        let pulsanti = NSStackView(views: [avvia, annulla])
        pulsanti.orientation = .horizontal
        viste.append(pulsanti)
        let pila = NSStackView(views: viste)
        pila.orientation = .vertical
        pila.alignment = .leading
        pila.spacing = 10
        pila.edgeInsets = NSEdgeInsets(top: 18, left: 20, bottom: 18, right: 20)
        spiegazione.widthAnchor.constraint(equalToConstant: 480).isActive = true
        w.contentView = pila
        w.initialFirstResponder = opzioni.first { $0.bottone.state == .on }?.bottone ?? avvia
    }
    required init?(coder: NSCoder) { fatalError("non si usa") }

    func mostra(su genitore: NSWindow?, esito: @escaping (String?) -> Void) {
        self.esito = esito
        if let genitore, let w = window { genitore.beginSheet(w) } else { showWindow(nil) }
    }

    @objc private func sceltaCambiata(_ b: NSButton) {
        for o in opzioni { o.bottone.state = o.bottone === b ? .on : .off }
    }
    @objc private func avviaPremuto() { chiudi(opzioni.first { $0.bottone.state == .on }?.id) }
    @objc private func annullaPremuto() { chiudi(nil) }
    @objc private func apriPannelloPremuto() { apriPannello() }

    private func chiudi(_ id: String?) {
        if let w = window, let genitore = w.sheetParent { genitore.endSheet(w) } else { window?.orderOut(nil) }
        let e = esito
        esito = nil
        e?(id)
    }
}
