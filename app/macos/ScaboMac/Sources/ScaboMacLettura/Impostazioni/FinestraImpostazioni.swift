//
//  FinestraImpostazioni.swift
//  ScaboMacLettura — le Impostazioni di lettura dell'app Mac (⌘,; giro «app unica per Mac, tappa A», 2026-11-08): la
//  granularità di lettura con i quattro livelli dell'iPad e le note annunciate a voce, con le parole dell'iPad (ScaboChain
//  `ReadingSettingsWording`). Sul Mac la granularità si applica (DISEGNO_LETTURA_MAC § 6.7): vale dai libri aperti dopo la
//  scelta. Le scelte si salvano subito, sulle stesse chiavi dell'iPad.
//
import AppKit
import ScaboChain
import ScaboCore

@MainActor
public final class FinestraImpostazioni: NSWindowController {
    private let prefs: KeyValueStore
    private var livelli: [NSButton] = []
    private let note = NSButton(checkboxWithTitle: ReadingSettingsWording.noteSpokenSwitch, target: nil, action: nil)

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
        let pila = NSStackView(views: viste)
        pila.orientation = .vertical
        pila.alignment = .leading
        pila.spacing = 8
        pila.setCustomSpacing(16, after: spiegazione)
        pila.edgeInsets = NSEdgeInsets(top: 18, left: 20, bottom: 18, right: 20)
        w.contentView = pila
    }

    required init?(coder: NSCoder) { fatalError("non si usa") }

    @objc private func sceltaLivello(_ sender: NSButton) {
        guard let raw = sender.identifier?.rawValue, let livello = GranularityLevel(rawValue: raw) else { return }
        setStoredGranularityLevel(prefs, livello)
        for b in livelli { b.state = b === sender ? .on : .off }
    }

    @objc private func cambiaNote(_ sender: NSButton) {
        PreferenzeLettura.impostaNoteAVoce(prefs, sender.state == .on)
    }
}
