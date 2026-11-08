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
        for testo in annunci.announcements(phaseLabel: p.phaseLabel, percent: percento, fraction: frazione) {
            NSAccessibility.post(element: window as Any, notification: .announcementRequested,
                                 userInfo: [.announcement: testo, .priority: NSAccessibilityPriorityLevel.medium.rawValue])
        }
    }

    private func mostraStato(fase: String, percento: Int) {
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
        let saltate = (processore as? DocumentProcessor)?.visualResourcesMissingReason
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
    private let apriLetturaInFinestra: (ArchivedDocument, LibraryReading) -> Void

    public init(finestra: NSWindow?, apriLettura: @escaping (ArchivedDocument, LibraryReading) -> Void) {
        self.finestra = finestra
        self.apriLetturaInFinestra = apriLettura
    }

    public func elabora(fileURL: URL, nome: String, granularita: Int, dottrina: Bool, processore: DocumentProcessing,
                        esito: @escaping (DocumentProcessor.Outcome, String?) -> Void) {
        let s = SchermataElaborazione(nome: nome)
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
