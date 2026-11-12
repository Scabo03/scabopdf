//
//  FinestraImpostazioni.swift
//  ScaboMacLettura — le Impostazioni di lettura dell'app Mac (⌘,; giro «app unica per Mac, tappa A», 2026-11-08): la
//  granularità di lettura con i quattro livelli dell'iPad e le note annunciate a voce, con le parole dell'iPad (ScaboChain
//  `ReadingSettingsWording`). Sul Mac la granularità si applica (DISEGNO_LETTURA_MAC § 6.7): vale dai libri aperti dopo la
//  scelta. Le note a voce valgono subito, anche nei libri già aperti (sul Mac le Impostazioni si aprono mentre si legge). Le
//  scelte si salvano subito, sulle stesse chiavi dell'iPad.
//  Dal giro «ScaboPDF per Mac su TestFlight» (2026-11-12), in fondo, «Per chi sviluppa ScaboPDF»: la scelta che mostra il menu
//  «Diagnostica» (spenta se nessuno l'ha accesa; su una chiave del Mac, `PreferenzeDiagnostica`).
//
import AppKit
import ScaboChain
import ScaboCore

@MainActor
public final class FinestraImpostazioni: NSWindowController {
    private let prefs: KeyValueStore
    private var livelli: [NSButton] = []
    let note = NSButton(checkboxWithTitle: ReadingSettingsWording.noteSpokenSwitch, target: nil, action: nil)
    let diagnostica = NSButton(checkboxWithTitle: Parole.impostazioniMostraDiagnostica, target: nil, action: nil)
    /// Chiamata quando cambia «Annuncia le note a voce»: chi tiene le finestre di lettura le aggiorna subito.
    public var quandoCambianoLeNote: (() -> Void)?
    /// Chiamata quando cambia «Mostra la diagnostica nel menu Finestra»: l'app mostra o nasconde la voce del menu «Finestra».
    public var quandoCambiaLaDiagnostica: ((Bool) -> Void)?

    public init(prefs: KeyValueStore) {
        self.prefs = prefs
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 360), styleMask: [.titled, .closable],
                         backing: .buffered, defer: false)
        w.title = Parole.impostazioni
        w.setAccessibilityIdentifier("impostazioni.finestra")
        w.isReleasedWhenClosed = false
        super.init(window: w)

        let titoloGranularita = NSTextField(labelWithString: ReadingSettingsWording.granularityTitle)
        titoloGranularita.font = .boldSystemFont(ofSize: 13)
        titoloGranularita.setAccessibilityRole(.staticText)
        var viste: [NSView] = [titoloGranularita]
        let scelto = getStoredGranularityLevel(prefs)
        for (livello, nome) in ReadingSettingsWording.granularityLevels {
            let b = NSButton(radioButtonWithTitle: nome, target: self, action: #selector(sceltaLivello(_:)))
            b.state = livello == scelto ? .on : .off
            b.identifier = NSUserInterfaceItemIdentifier(livello.rawValue)
            b.setAccessibilityIdentifier("impostazioni.granularita.\(livello.rawValue)")
            livelli.append(b)
            viste.append(b)
        }
        let spiegazione = NSTextField(wrappingLabelWithString: ReadingSettingsWording.granularityFooter + " " + Parole.granularitaQuandoVale)
        spiegazione.preferredMaxLayoutWidth = 470
        viste.append(spiegazione)
        note.target = self
        note.action = #selector(cambiaNote(_:))
        note.state = PreferenzeLettura.noteAVoce(prefs) ? .on : .off
        note.setAccessibilityIdentifier("impostazioni.noteAVoce")
        let spiegazioneNote = NSTextField(wrappingLabelWithString: Parole.noteAVoceSpiegazione)
        spiegazioneNote.preferredMaxLayoutWidth = 470
        viste += [note, spiegazioneNote]
        let titoloSviluppo = NSTextField(labelWithString: Parole.impostazioniSviluppo)
        titoloSviluppo.font = .boldSystemFont(ofSize: 13)
        titoloSviluppo.setAccessibilityRole(.staticText)
        diagnostica.target = self
        diagnostica.action = #selector(cambiaDiagnostica(_:))
        diagnostica.state = PreferenzeDiagnostica.mostrata(prefs) ? .on : .off
        diagnostica.setAccessibilityIdentifier("impostazioni.diagnostica")
        let spiegazioneDiagnostica = NSTextField(wrappingLabelWithString: Parole.impostazioniMostraDiagnosticaSpiegazione)
        spiegazioneDiagnostica.preferredMaxLayoutWidth = 470
        viste += [titoloSviluppo, diagnostica, spiegazioneDiagnostica]
        let pila = NSStackView(views: viste)
        pila.orientation = .vertical
        pila.alignment = .leading
        pila.spacing = 8
        pila.setCustomSpacing(16, after: spiegazione)
        pila.setCustomSpacing(16, after: spiegazioneNote)
        pila.edgeInsets = NSEdgeInsets(top: 18, left: 20, bottom: 18, right: 20)
        w.contentView = pila
    }

    required init?(coder: NSCoder) { fatalError("non si usa") }

    @objc private func sceltaLivello(_ sender: NSButton) {
        guard let raw = sender.identifier?.rawValue, let livello = GranularityLevel(rawValue: raw) else { return }
        setStoredGranularityLevel(prefs, livello)
        for b in livelli { b.state = b === sender ? .on : .off }
    }

    @objc func cambiaNote(_ sender: NSButton) {
        PreferenzeLettura.impostaNoteAVoce(prefs, sender.state == .on)
        quandoCambianoLeNote?()
    }

    @objc func cambiaDiagnostica(_ sender: NSButton) {
        PreferenzeDiagnostica.impostaMostrata(prefs, sender.state == .on)
        quandoCambiaLaDiagnostica?(sender.state == .on)
    }
}
