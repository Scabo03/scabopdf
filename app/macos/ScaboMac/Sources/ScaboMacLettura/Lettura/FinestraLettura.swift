//
//  FinestraLettura.swift
//  ScaboMacLettura — la finestra di lettura di un libro (giro «app unica per Mac, tappa A», 2026-11-08; DISEGNO_LETTURA_MAC
//  § 2.5): AppKit puro, una finestra per libro, con la vista a scorrimento e dentro il gruppo «Testo del documento». Nella
//  tappa A la finestra non ha ancora la barra degli strumenti (la ricerca e il selettore dei layout arrivano con le loro tappe):
//  dalla finestra al primo elemento ci sono la vista a scorrimento e il gruppo, come nel prototipo misurato da fuori.
//
//  Qui: la posizione di lettura (§ 2.5) — si riapre dove si era, e a ogni arrivo del fuoco si registra con l'ancora per
//  contenuto, come sull'iPad —; le impostazioni del parlato (note a voce; VoiceOver acceso o spento, osservato); i comandi del
//  menu «Lettura», gli stessi delle azioni del modulo con le scorciatoie del disegno (§ 5.2).
//
import AppKit
import ScaboChain
import ScaboCore

/// Ciò che la finestra calcola sul libro prima di mostrarsi: il modello del parlato coi legami nota ↔ richiamo (con le opzioni
/// delle cure mirate del libro, dalla sua impronta, come sull'iPad) e l'indice delle ancore per contenuto. È lavoro puro sui
/// segmenti, senza finestre né libreria: l'app lo fa FUORI dal filo principale (dal giro «prove della tappa A», 2026-11-09),
/// perché sul volume più grande dura secondi e in quel tempo l'app non risponderebbe a VoiceOver. L'indice si consegna a un
/// filo solo: chi lo costruisce lo passa alla finestra e non lo tocca più.
public struct PreparazioneLettura: @unchecked Sendable {
    public let modello: ReadingSpeechModel
    public let indice: ContentAnchorIndex

    public init(documento: ArchivedDocument, lettura: LibraryReading) {
        let segmenti = lettura.content.pages.flatMap { $0.segments }
        modello = ReadingSpeechModel(segments: segmenti, noteJumpOptions: NoteJumpOptions.forFingerprint(documento.sourceSha256))
        indice = ContentAnchorIndex(segments: segmenti)
    }
}

@MainActor
public final class FinestraLettura: NSWindowController, NSWindowDelegate, NSMenuItemValidation {
    public let documentId: String
    public let vista: VistaLettura
    public let scorrimento = NSScrollView()
    private let libreria: LibreriaMac
    private let ancore = ReaderAnchorBox()
    private var osservatoreVoiceOver: NSKeyValueObservation?
    /// Chiamata quando la finestra si chiude (la Home aggiorna l'elenco e chi tiene le finestre la dimentica).
    public var quandoSiChiude: ((FinestraLettura) -> Void)?
    /// La finestra si chiude perché lo stesso libro si riapre in una finestra nuova: la riapertura all'avvio non si tocca.
    public var chiusaPerSostituzione = false
    /// La frase da dire all'apertura se la posizione è stata ritrovata solo per pagina dopo una rielaborazione (§ 12.14), con
    /// le parole dell'iPad; `nil` altrimenti.
    public let annuncioPosizione: String?

    /// Le impostazioni del parlato per il Mac nella tappa A: niente «Strumenti elemento» né «Estrai come immagine» (tappe
    /// successive), le note a voce secondo le preferenze, VoiceOver come lo dice il sistema.
    public static func impostazioni(prefs: KeyValueStore, voiceOver: Bool) -> ReadingSpeechSettings {
        ReadingSpeechSettings(noteSpokenLabels: PreferenzeLettura.noteAVoce(prefs), voiceOverRunning: voiceOver,
                              elementToolsAvailable: false, visualExtractionAvailable: false)
    }

    /// `preparazione`: il modello e l'indice già calcolati fuori dal filo principale (l'app); senza, si calcolano qui (i test).
    public init(documento doc: ArchivedDocument, lettura: LibraryReading, libreria: LibreriaMac,
                voiceOver: Bool = NSWorkspace.shared.isVoiceOverEnabled, preparazione: PreparazioneLettura? = nil) {
        self.documentId = doc.id
        self.libreria = libreria
        annuncioPosizione = doc.readingPositionIsApproximate == true
            ? LibraryWording.approximatePositionAnnouncement(isAkn: doc.sourceKind == "akn") : nil
        let pronta = preparazione ?? PreparazioneLettura(documento: doc, lettura: lettura)
        vista = VistaLettura(modello: pronta.modello, impostazioni: Self.impostazioni(prefs: libreria.prefs, voiceOver: voiceOver))
        let w = NSWindow(contentRect: NSRect(x: 160, y: 120, width: 900, height: 680),
                         styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
        w.title = doc.title
        w.setAccessibilityIdentifier("lettura.finestra")
        w.isReleasedWhenClosed = false
        super.init(window: w)
        w.delegate = self
        scorrimento.documentView = vista
        scorrimento.hasVerticalScroller = true
        scorrimento.autohidesScrollers = false
        scorrimento.setAccessibilityIdentifier("lettura.scorrimento")
        w.contentView = scorrimento
        vista.frame.size.width = scorrimento.contentSize.width
        vista.autoresizingMask = [.width]

        // Le ancore per contenuto della posizione (come sull'iPad): l'indice è della preparazione; le annotazioni senza ancora
        // la ricevono a contenuto fermo.
        let indice = pronta.indice
        ancore.index = indice
        libreria.service.mintMissingAnchors(documentId: doc.id, in: indice)
        let id = doc.id
        vista.quandoCambiaIlFuoco = { [weak self] i in
            guard let self else { return }
            self.libreria.service.store.updateReadingPosition(id: id, position: i, anchor: self.ancore.anchor(forIndex: i))
        }
        if PreferenzeLettura.segnaliAcustici(libreria.prefs) {
            vista.suonatore = { segnali in SegnaliMac.shared.suona(segnali) }
        }
        vista.impostaFuocoIniziale(doc.readingPosition)
        w.makeFirstResponder(vista)
        // La ripetizione dell'avviso di un salto parte solo con questa finestra in primo piano e l'app attiva (rilievo della
        // revisione del giro «prove rifatte»: un avviso da una finestra lasciata riporterebbe lì il cursore).
        vista.ripetizionePossibile = { [weak w] in w?.isKeyWindow == true && NSApp.isActive }
        osservatoreVoiceOver = NSWorkspace.shared.observe(\.isVoiceOverEnabled, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in self?.aggiornaImpostazioni() }
        }
    }

    required init?(coder: NSCoder) { fatalError("non si usa") }

    /// Rilegge le impostazioni del parlato (note a voce dalle preferenze, VoiceOver dal sistema): quando VoiceOver si accende
    /// o si spegne, e quando cambiano le note a voce nelle Impostazioni.
    public func aggiornaImpostazioni(voiceOver: Bool = NSWorkspace.shared.isVoiceOverEnabled) {
        vista.impostazioni = Self.impostazioni(prefs: libreria.prefs, voiceOver: voiceOver)
    }

    /// Mostra la finestra e porta il cursore di VoiceOver sull'elemento della posizione di lettura. `inPrimoPiano` falso (un
    /// libro chiesto prima di un altro, finito di preparare dopo): la finestra si apre dietro quella attiva, senza prenderle
    /// il fuoco, e l'annuncio della posizione approssimata aspetta che diventi la finestra attiva.
    public func mostra(inPrimoPiano: Bool = true) {
        guard inPrimoPiano else {
            window?.order(.below, relativeTo: NSApp.keyWindow?.windowNumber ?? 0)
            annuncioInAttesa = annuncioPosizione
            return
        }
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        if let f = vista.fuoco, f < vista.conteggio {
            NSAccessibility.post(element: vista.elemento(f), notification: .focusedUIElementChanged)
        }
        annunciaPosizione(annuncioPosizione)
    }

    /// L'annuncio della posizione approssimata non ancora detto (finestra aperta dietro).
    private var annuncioInAttesa: String?

    /// Come l'iPad: un secondo e mezzo dopo l'apertura, perché VoiceOver abbia già detto la finestra.
    private func annunciaPosizione(_ annuncio: String?) {
        guard let annuncio else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let w = self?.window else { return }
            NSAccessibility.post(element: w, notification: .announcementRequested,
                                 userInfo: [.announcement: annuncio, .priority: NSAccessibilityPriorityLevel.high.rawValue])
        }
    }

    /// La finestra in primo piano è il libro che si riapre all'avvio (con più libri aperti vale l'ultimo usato).
    public func windowDidBecomeKey(_ notification: Notification) {
        libreria.service.store.setLastOpenDocument(id: documentId)
        if let a = annuncioInAttesa { annuncioInAttesa = nil; annunciaPosizione(a) }
    }

    public func windowWillClose(_ notification: Notification) {
        osservatoreVoiceOver = nil
        // Chiudendo il libro si torna alla Home: all'avvio seguente non si riapre (§ 2.5, come «Indietro» sull'iPad). Solo se
        // era questo il libro da riaprire, e non quando lo stesso libro si riapre in una finestra nuova.
        if !chiusaPerSostituzione, libreria.service.store.lastOpenDocumentId == documentId {
            libreria.service.store.setLastOpenDocument(id: nil)
        }
        libreria.avvisa()
        quandoSiChiude?(self)
    }

    // MARK: Il menu «Lettura» (gli stessi comandi delle azioni, DISEGNO § 5.2)

    @objc public func saltaNotaRichiamo(_ sender: Any?) { notaComando("nota-richiamo", sender); vista.saltaNotaRichiamo() }
    @objc public func titoloSuccessivo(_ sender: Any?) { notaComando("titolo-successivo", sender); vista.titolo(avanti: true) }
    @objc public func titoloPrecedente(_ sender: Any?) { notaComando("titolo-precedente", sender); vista.titolo(avanti: false) }
    @objc public func saltaRisorsa(_ sender: Any?) { notaComando("salta-risorsa", sender); vista.saltaRisorsa() }

    /// Il comando del menu «Lettura» nel diario delle prove: se è arrivato dalla scorciatoia (un tasto) o dalla voce del menu
    /// (VO+M, un clic). Il diario della T3 rifatta non sapeva dire se ⌘J e ⌥⌘↓ fossero arrivati all'app (giro «prove rifatte»).
    private func notaComando(_ nome: String, _ sender: Any?) {
        vista.diario.registra(vista.fuoco ?? -1, "menu:\(nome):\(Self.via(sender, evento: NSApp.currentEvent))")
    }

    /// «tasto» solo se l'evento in corso è la pressione della scorciatoia di quella voce (Comando e il suo carattere, appena
    /// arrivata); altrimenti «voce» (VO+M, un clic, Invio nel menu, la voce premuta per l'accessibilità). Prima bastava un
    /// evento di tasto qualunque: un Invio nel menu o l'ultimo tasto ricevuto passavano per scorciatoia (rilievo della
    /// revisione del giro «prove rifatte»).
    static func via(_ sender: Any?, evento: NSEvent?) -> String {
        guard let voce = sender as? NSMenuItem, !voce.keyEquivalent.isEmpty, let e = evento, e.type == .keyDown,
              e.modifierFlags.contains(.command),
              ProcessInfo.processInfo.systemUptime - e.timestamp < 1,
              (e.charactersIgnoringModifiers ?? "").lowercased() == voce.keyEquivalent.lowercased() else { return "voce" }
        return "tasto"
    }

    public func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(saltaRisorsa(_:)) { return vista.risorsaInLettura }
        return true
    }
}
