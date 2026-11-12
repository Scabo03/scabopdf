//
//  FinestraDiagnostica.swift
//  ScaboMacLettura — il PANNELLO «Diagnostica» (giro «ScaboPDF per Mac su TestFlight», 2026-11-12; LAYER2 § 12.16, decisione
//  17): una finestra AppKit come le Impostazioni, pensata per VoiceOver — ogni controllo con la sua etichetta, le spiegazioni
//  come testo statico subito dopo il loro controllo, nell'ordine di lettura. Dall'alto: la versione e
//  la build in chiaro; il diario (acceso o spento, dove si scrive, la cartella nel Finder, l'esportazione in un file); la variante
//  dei titoli, applicata subito; le prove guidate col libro sintetico che l'app scrive da sé, in una libreria a parte. Esc chiude.
//
import AppKit
import ScaboCore

@MainActor
public final class FinestraDiagnostica: NSWindowController {
    private let diagnostica: Diagnostica
    let interruttoreDiario = NSButton(checkboxWithTitle: Parole.diagnosticaDiarioInterruttore, target: nil, action: nil)
    let statoDiario = NSTextField(wrappingLabelWithString: "")
    let mostraCartella = NSButton(title: Parole.diagnosticaMostraCartella, target: nil, action: nil)
    let esporta = NSButton(title: Parole.diagnosticaEsporta, target: nil, action: nil)
    private(set) var varianti: [NSButton] = []
    let finestraPiccola = NSButton(checkboxWithTitle: Parole.diagnosticaFinestraPiccola, target: nil, action: nil)
    let apriLibro = NSButton(title: Parole.diagnosticaApriLibroDiProva, target: nil, action: nil)

    /// Chiamata quando il maintainer sceglie una variante dei titoli (l'app la salva e la applica alle letture aperte).
    public var quandoCambiaLaVariante: ((VarianteTitoli.Lettera) -> Void)?
    /// Chiamata quando il maintainer apre il libro di prova (`true`: con la finestra dei figli piccola).
    public var quandoApreIlLibroDiProva: ((Bool) -> Void)?
    /// Chiamata quando il diario si accende o si spegne dal pannello (l'app salva la scelta).
    public var quandoCambiaIlDiario: ((Bool) -> Void)?

    public init(diagnostica: Diagnostica, info: [String: Any]? = Bundle.main.infoDictionary) {
        self.diagnostica = diagnostica
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 640), styleMask: [.titled, .closable],
                         backing: .buffered, defer: false)
        w.title = Parole.diagnostica
        w.setAccessibilityIdentifier("diagnostica.finestra")
        w.isReleasedWhenClosed = false
        super.init(window: w)

        func titolo(_ testo: String) -> NSTextField {
            let t = NSTextField(labelWithString: testo)
            t.font = .boldSystemFont(ofSize: 13)
            t.setAccessibilityRole(.staticText)
            return t
        }
        func testo(_ s: String) -> NSTextField {
            let t = NSTextField(wrappingLabelWithString: s)
            t.preferredMaxLayoutWidth = 550
            return t
        }
        let v = Diagnostica.versione(info)
        let versione = testo(Parole.diagnosticaVersione(v.versione, v.build))
        versione.setAccessibilityIdentifier("diagnostica.versione")

        interruttoreDiario.target = self
        interruttoreDiario.action = #selector(cambiaDiario(_:))
        interruttoreDiario.setAccessibilityIdentifier("diagnostica.diario")
        statoDiario.preferredMaxLayoutWidth = 550
        statoDiario.setAccessibilityIdentifier("diagnostica.diario.stato")
        mostraCartella.target = self
        mostraCartella.action = #selector(mostraLaCartella(_:))
        mostraCartella.setAccessibilityIdentifier("diagnostica.cartella")
        esporta.target = self
        esporta.action = #selector(esportaIlDiario(_:))
        esporta.setAccessibilityIdentifier("diagnostica.esporta")

        var viste: [NSView] = [testo(Parole.diagnosticaSpiegazione), versione,
                               titolo(Parole.diagnosticaDiarioTitolo), interruttoreDiario,
                               testo(Parole.diagnosticaDiarioSpiegazione), statoDiario, mostraCartella, esporta,
                               titolo(Parole.diagnosticaTitoliTitolo), testo(Parole.diagnosticaTitoliSpiegazione)]
        for l in VarianteTitoli.Lettera.allCases {
            let b = NSButton(radioButtonWithTitle: VarianteTitoli.nome(l), target: self, action: #selector(sceltaVariante(_:)))
            b.identifier = NSUserInterfaceItemIdentifier(l.rawValue)
            b.setAccessibilityIdentifier("diagnostica.variante.\(l.rawValue)")
            varianti.append(b)
            viste.append(b)
        }
        finestraPiccola.setAccessibilityIdentifier("diagnostica.finestraPiccola")
        finestraPiccola.state = .on
        apriLibro.target = self
        apriLibro.action = #selector(apriIlLibroDiProva(_:))
        apriLibro.setAccessibilityIdentifier("diagnostica.libroDiProva")
        viste += [titolo(Parole.diagnosticaProveTitolo), testo(Parole.diagnosticaProveSpiegazione), finestraPiccola, apriLibro,
                  testo(Parole.diagnosticaIstruzioni)]
        let pila = NSStackView(views: viste)
        pila.orientation = .vertical
        pila.alignment = .leading
        pila.spacing = 8
        for dopo in [versione, esporta, varianti.last!] { pila.setCustomSpacing(18, after: dopo) }
        pila.edgeInsets = NSEdgeInsets(top: 18, left: 20, bottom: 18, right: 20)
        w.contentView = pila
        aggiorna()
        diagnostica.quandoCambia.append { [weak self] in self?.aggiorna() }
    }

    required init?(coder: NSCoder) { fatalError("non si usa") }

    /// Rilegge lo stato: il diario (acceso, il suo file) e la variante attiva.
    public func aggiorna() {
        interruttoreDiario.state = diagnostica.acceso ? .on : .off
        if diagnostica.acceso, let f = diagnostica.file {
            statoDiario.stringValue = Parole.diagnosticaDiarioAcceso(f.lastPathComponent)
        } else {
            statoDiario.stringValue = Parole.diagnosticaDiarioSpento
        }
        for b in varianti { b.state = b.identifier?.rawValue == VarianteTitoli.lettera ? .on : .off }
    }

    @objc func cambiaDiario(_ sender: NSButton) {
        if sender.state == .on { diagnostica.accendi() } else { diagnostica.spegni() }
        quandoCambiaIlDiario?(sender.state == .on)
        aggiorna()
    }

    @objc func sceltaVariante(_ sender: NSButton) {
        guard let raw = sender.identifier?.rawValue, let l = VarianteTitoli.Lettera(rawValue: raw) else { return }
        quandoCambiaLaVariante?(l)
        aggiorna()
    }

    @objc func apriIlLibroDiProva(_ sender: Any?) {
        quandoApreIlLibroDiProva?(finestraPiccola.state == .on)
        aggiorna()
    }

    @objc func mostraLaCartella(_ sender: Any?) { diagnostica.mostraCartella() }

    @objc func esportaIlDiario(_ sender: Any?) {
        guard let w = window else { return }
        guard let sorgente = diagnostica.fileDaEsportare else { annuncia(Parole.diagnosticaEsportaNessuno); return }
        let pannello = NSSavePanel()
        pannello.nameFieldStringValue = sorgente.lastPathComponent
        pannello.allowedContentTypes = [.plainText]
        pannello.beginSheetModal(for: w) { [weak self] r in
            guard r == .OK, let url = pannello.url else { return }
            MainActor.assumeIsolated {
                do { try self?.diagnostica.esporta(verso: url); self?.annuncia(Parole.diagnosticaEsportaFatto) }
                catch { self?.annuncia(Parole.diagnosticaEsportaProblema) }
            }
        }
    }

    /// Un annuncio di VoiceOver dalla finestra del pannello.
    private func annuncia(_ testo: String) {
        guard let w = window else { return }
        NSAccessibility.post(element: w, notification: .announcementRequested,
                             userInfo: [.announcement: testo, .priority: NSAccessibilityPriorityLevel.high.rawValue])
    }

    /// Esc chiude il pannello, come «Chiudi».
    public override func cancelOperation(_ sender: Any?) { window?.performClose(sender) }
}
