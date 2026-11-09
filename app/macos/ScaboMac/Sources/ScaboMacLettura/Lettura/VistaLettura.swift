//
//  VistaLettura.swift
//  ScaboMacLettura — il contenitore del testo della lettura sul Mac (giro «app unica per Mac, tappa A», 2026-11-08; dal
//  prototipo del giro «disegno della lettura per Mac», `docs/DISEGNO_LETTURA_MAC.md` § 2-5). UNA NSView, il gruppo «Testo del
//  documento», dentro una NSScrollView; i suoi figli d'accessibilità sono gli elementi virtuali, uno per blocco di granularità,
//  creati tutti alla prima richiesta (oggetti leggeri) e interrogati pigramente. Rotori sul gruppo (tipi di sistema per i
//  titoli per livello, le tabelle e le immagini; il nome nostro per la ricerca), azioni per elemento, gancio del fuoco,
//  scorrimento alla riga del fuoco. Disegna solo le righe visibili. Tutto ciò che si dice viene dal modulo `ReadingSpeech`.
//
import AppKit
import ScaboCore

public final class VistaLettura: NSView, NSAccessibilityCustomRotorItemSearchDelegate {

    public private(set) var modello: ReadingSpeechModel
    public var impostazioni: ReadingSpeechSettings {
        didSet { if oldValue != impostazioni { needsDisplay = true } }
    }
    /// Nella prima tappa del Mac non ci sono segnalibri (tappa B): nessuna azione di segnalibro.
    public let statoSegnalibri: ReadingBookmarkState = .unavailable
    public var ricercaAttiva: BookSearchResult? = nil
    public let altezzaRiga: CGFloat = 28
    /// Il diario delle richieste d'accessibilità: spento, si accende solo per le prove (argomento `--diario`, i banchi).
    public let diario: Diario = { let d = Diario(); d.attivo = false; return d }()

    /// L'elemento che ha il fuoco (l'indice) e il ruolo di quello di prima (per il segnale della bibliografia).
    public private(set) var fuoco: Int? = nil
    public private(set) var ruoloPrecedente: String? = nil
    /// I segnali calcolati a ogni arrivo del fuoco (per la descrizione e per il diario).
    public private(set) var segnaliEmessi: [(indice: Int, segnali: [AudioSignal], origine: OrigineFuoco)] = []
    public private(set) var annunci: [String] = []
    /// Prova a secco delle azioni: non muove il fuoco, annota solo il bersaglio (serve alla descrizione dalla vista).
    public var provaASecco = false
    public var ultimoBersaglioProva: Int? = nil
    /// Vero mentre la vista si descrive da sé: il fuoco arriva su ogni elemento, ma non si suona e non si registra la
    /// posizione di lettura.
    public var descrizioneInCorso = false

    /// Il fuoco è arrivato su un elemento (la posizione di lettura: la registra chi ha aperto il libro).
    public var quandoCambiaIlFuoco: ((Int) -> Void)?
    /// Chi suona i segnali, se acceso (il gancio è pronto; i suoni si accendono solo dopo la prova d'orecchio T2).
    public var suonatore: (([AudioSignal]) -> Void)?

    private var elementi: [ElementoLettura]? = nil
    private var rotoriCache: [NSAccessibilityCustomRotor] = []
    private var rotoreDi: [ObjectIdentifier: ReadingRotor] = [:]
    private var rotoriPerRicerca: Bool? = nil

    public enum OrigineFuoco: String { case accessibilita, tastiera, programma }

    public init(modello: ReadingSpeechModel, impostazioni: ReadingSpeechSettings) {
        self.modello = modello
        self.impostazioni = impostazioni
        super.init(frame: NSRect(x: 0, y: 0, width: 800, height: CGFloat(max(1, modello.segments.count)) * 28))
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel(Parole.gruppoTesto)
        setAccessibilityIdentifier("lettura.testo")
    }

    public convenience init(segmenti: [ContentSegment], impostazioni: ReadingSpeechSettings) {
        self.init(modello: ReadingSpeechModel(segments: segmenti), impostazioni: impostazioni)
    }

    required init?(coder: NSCoder) { fatalError("non si usa") }

    public override var isFlipped: Bool { true }
    public override var acceptsFirstResponder: Bool { true }
    public var conteggio: Int { modello.segments.count }

    // MARK: Il gruppo visto dall'accessibilità

    public override func isAccessibilityElement() -> Bool { true }
    public override func accessibilityRole() -> NSAccessibility.Role? { .group }
    public override func accessibilityLabel() -> String? { Parole.gruppoTesto }
    public override func accessibilityChildren() -> [Any]? { diario.registra(-1, "gruppo:AXChildren"); return figli() }
    public override func accessibilityChildrenInNavigationOrder() -> [any NSAccessibilityElementProtocol]? {
        diario.registra(-1, "gruppo:AXChildrenInNavigationOrder"); return figli()
    }
    public override func accessibilityVisibleChildren() -> [Any]? {
        diario.registra(-1, "gruppo:AXVisibleChildren")
        let righe = righeVisibili
        return righe.isEmpty ? [] : Array(figli()[righe])
    }
    public override func accessibilityCustomRotors() -> [NSAccessibilityCustomRotor] {
        diario.registra(-1, "gruppo:AXCustomRotors"); return rotori()
    }

    /// I figli: tutti gli elementi, costruiti UNA volta alla prima richiesta.
    public func figli() -> [ElementoLettura] {
        if let e = elementi { return e }
        let e = (0..<conteggio).map { ElementoLettura(indice: $0, vista: self) }
        elementi = e
        return e
    }
    public func elemento(_ i: Int) -> ElementoLettura { figli()[i] }

    // MARK: Il parlato (tutto dal modulo)

    public func segmento(_ i: Int) -> ContentSegment { modello.segments[i] }
    public func testoPronunciato(_ i: Int) -> String {
        ReadingSpeech.intendedAccessibilityLabel(for: segmento(i), restoreNoteIntro: impostazioni.noteSpokenLabels)
    }
    public func valore(_ i: Int) -> String? { modello.value(forIndex: i, search: ricercaAttiva) }
    public func azioni(_ i: Int) -> [ReadingAction] {
        modello.actions(forIndex: i, bookmark: statoSegnalibri, settings: impostazioni)
    }
    public func azioniPersonalizzate(_ i: Int) -> [NSAccessibilityCustomAction] {
        azioni(i).map { a in
            NSAccessibilityCustomAction(name: a.name) { [weak self] in self?.esegui(a, da: i) ?? false }
        }
    }

    /// Esegue un'azione dall'elemento `i`. Le azioni di navigazione spostano il fuoco al bersaglio del modulo.
    @discardableResult
    public func esegui(_ a: ReadingAction, da i: Int) -> Bool {
        switch a {
        case .goToCall(let t), .skipVisualResource(let t), .goToNote(let t, _):
            if provaASecco { ultimoBersaglioProva = t } else { spostaFuoco(a: t) }
            return true
        case .addBookmark, .editBookmark, .removeBookmark, .extractVisualResource, .elementTools:
            // Non offerte nella prima tappa del Mac (le impostazioni le tolgono dal modulo): qui non arrivano.
            return false
        }
    }

    // MARK: Il fuoco

    /// Il fuoco arriva su `i` (da VoiceOver via AXFocused, dalla tastiera o dal programma): i segnali del modulo, la riga
    /// in vista, il diario, la posizione di lettura.
    public func riceviFuoco(_ i: Int, origine: OrigineFuoco) {
        guard i >= 0, i < conteggio else { return }
        let s = segmento(i)
        let segnali = ReadingSpeech.focusSignals(for: s, previousFocusedRole: ruoloPrecedente,
                                                 noteSpokenLabels: impostazioni.noteSpokenLabels)
        segnaliEmessi.append((i, segnali, origine))
        if segnaliEmessi.count > 4096 { segnaliEmessi.removeFirst(2048) }
        let precedente = fuoco
        fuoco = i
        ruoloPrecedente = s.role
        scrollToVisible(rettangolo(i))
        diario.registra(i, "fuoco:\(origine.rawValue):\(segnali.map(\.rawValue).joined(separator: "+"))")
        if !segnali.isEmpty, !provaASecco, !descrizioneInCorso { suonatore?(segnali) }
        if let p = precedente { setNeedsDisplay(rettangolo(p)) }
        setNeedsDisplay(rettangolo(i))
        if !provaASecco, !descrizioneInCorso { quandoCambiaIlFuoco?(i) }
    }

    /// Sposta il fuoco per programma (azioni, menu, apertura) e lo dice all'accessibilità, così il cursore di VoiceOver segue.
    public func spostaFuoco(a i: Int) {
        guard i >= 0, i < conteggio else { return }
        riceviFuoco(i, origine: .programma)
        NSAccessibility.post(element: elemento(i), notification: .focusedUIElementChanged)
    }

    /// Fuoco iniziale all'apertura: la riga in vista e il fuoco dichiarato, senza registrare una posizione nuova.
    public func impostaFuocoIniziale(_ i: Int) {
        guard conteggio > 0 else { return }
        let k = min(max(0, i), conteggio - 1)
        fuoco = k
        ruoloPrecedente = nil
        scrollToVisible(rettangolo(k))
        needsDisplay = true
    }

    func azzeraStato() {
        fuoco = nil; ruoloPrecedente = nil; segnaliEmessi.removeAll(); annunci.removeAll(); ultimoBersaglioProva = nil
    }

    /// L'annuncio a voce (VoiceOver lo dice; l'elenco serve ai test).
    public func annuncia(_ testo: String) {
        annunci.append(testo)
        if let w = window {
            NSAccessibility.post(element: w, notification: .announcementRequested,
                                 userInfo: [.announcement: testo, .priority: NSAccessibilityPriorityLevel.high.rawValue])
        }
    }

    // MARK: Comandi (i duplicati della barra dei menu arrivano qui)

    /// ⌘J: salto nota ↔ richiamo dall'elemento in lettura; senza bersaglio, la frase del modulo.
    @discardableResult public func saltaNotaRichiamo() -> Bool {
        guard let f = fuoco, let t = modello.noteCallJumpTarget(from: f) else {
            annuncia(ReadingSpeech.noNoteOrCallToReach); return false
        }
        spostaFuoco(a: t); return true
    }
    /// Titolo successivo o precedente (qualsiasi livello).
    @discardableResult public func titolo(avanti: Bool) -> Bool {
        let da = fuoco ?? (avanti ? -1 : conteggio)
        guard let t = modello.nextHeadingIndex(from: da, level: nil, forward: avanti) else { return false }
        spostaFuoco(a: t); return true
    }
    /// «Salta la risorsa» dall'elemento in lettura, se l'elemento la offre.
    @discardableResult public func saltaRisorsa() -> Bool {
        guard let f = fuoco else { return false }
        for a in azioni(f) { if case .skipVisualResource = a { return esegui(a, da: f) } }
        return false
    }
    public var risorsaInLettura: Bool {
        guard let f = fuoco else { return false }
        return azioni(f).contains { if case .skipVisualResource = $0 { return true } else { return false } }
    }

    // MARK: Geometria

    /// Il margine sinistro dove si disegna la barra del fuoco: fuori dalla cornice dell'elemento, così dentro la cornice ci sono
    /// solo il testo e il suo fondo (l'audit di sistema del contrasto misura lì).
    public let margineFuoco: CGFloat = 10
    public func rettangolo(_ i: Int) -> NSRect {
        NSRect(x: margineFuoco, y: CGFloat(i) * altezzaRiga, width: max(0, bounds.width - margineFuoco), height: altezzaRiga)
    }
    public func corniceSchermo(_ i: Int) -> NSRect {
        guard let w = window else { return .zero }
        return w.convertToScreen(convert(rettangolo(i), to: nil))
    }
    public var righeVisibili: Range<Int> {
        // Il rettangolo visibile dentro i bordi della vista: fuori da una finestra AppKit può darne uno non finito (misurato:
        // la conversione in intero fermava il processo).
        let r = visibleRect.intersection(bounds)
        guard conteggio > 0, !r.isNull, !r.isEmpty, r.minY.isFinite, r.maxY.isFinite else { return 0..<0 }
        let primo = max(0, Int(floor(r.minY / altezzaRiga)))
        let ultimo = min(conteggio, Int(ceil(r.maxY / altezzaRiga)) + 1)
        return primo < ultimo ? primo..<ultimo : 0..<0
    }

    // MARK: Rotori (tipi di sistema per i titoli e le risorse; nome nostro per la ricerca)

    public func rotori() -> [NSAccessibilityCustomRotor] {
        let conRicerca = ReadingSpeechModel.activeSearch(ricercaAttiva) != nil
        if rotoriPerRicerca == conRicerca, !rotoriCache.isEmpty { return rotoriCache }
        rotoriCache = []; rotoreDi = [:]
        for r in modello.installedRotors(searchActive: conRicerca) {
            let rotore: NSAccessibilityCustomRotor
            switch r {
            case .searchResults: rotore = NSAccessibilityCustomRotor(label: ReadingSpeech.searchRotorName, itemSearchDelegate: self)
            case .headings: rotore = NSAccessibilityCustomRotor(rotorType: .heading, itemSearchDelegate: self)
            case .headingLevel(let n): rotore = NSAccessibilityCustomRotor(rotorType: Self.tipoLivello(n), itemSearchDelegate: self)
            case .tables: rotore = NSAccessibilityCustomRotor(rotorType: .table, itemSearchDelegate: self)
            case .images: rotore = NSAccessibilityCustomRotor(rotorType: .image, itemSearchDelegate: self)
            }
            rotoriCache.append(rotore); rotoreDi[ObjectIdentifier(rotore)] = r
        }
        rotoriPerRicerca = conRicerca
        return rotoriCache
    }

    static func tipoLivello(_ n: Int) -> NSAccessibilityCustomRotor.RotorType {
        switch n {
        case 1: return .headingLevel1
        case 2: return .headingLevel2
        case 3: return .headingLevel3
        case 4: return .headingLevel4
        case 5: return .headingLevel5
        default: return .headingLevel6
        }
    }

    public func rotoreDelModulo(_ rotore: NSAccessibilityCustomRotor) -> ReadingRotor? { rotoreDi[ObjectIdentifier(rotore)] }

    /// Il prossimo (o precedente) elemento del rotore a partire da `corrente`, con il filtro di testo se c'è; tutto dal
    /// modulo: indice dei titoli, indice delle risorse, risultati della ricerca.
    public func prossimo(nel rotore: ReadingRotor, da corrente: Int?, avanti: Bool, filtro: String = "") -> Int? {
        var da = corrente ?? (avanti ? -1 : conteggio)
        while true {
            let t: Int?
            switch rotore {
            case .headings: t = modello.nextHeadingIndex(from: da, level: nil, forward: avanti)
            case .headingLevel(let n): t = modello.nextHeadingIndex(from: da, level: n, forward: avanti)
            case .tables: t = modello.nextVisualIndex(from: da, kind: .table, forward: avanti)
            case .images: t = modello.nextVisualIndex(from: da, kind: .figure, forward: avanti)
            case .searchResults:
                let indici = ReadingSpeechModel.activeSearch(ricercaAttiva)?.elementIndices ?? []
                t = avanti ? indici.first(where: { $0 > da }) : indici.last(where: { $0 < da })
            }
            guard let trovato = t else { return nil }
            if filtro.isEmpty || testoPronunciato(trovato).localizedCaseInsensitiveContains(filtro) { return trovato }
            da = trovato
        }
    }

    public func rotor(_ rotore: NSAccessibilityCustomRotor,
                      resultFor p: NSAccessibilityCustomRotor.SearchParameters) -> NSAccessibilityCustomRotor.ItemResult? {
        guard let r = rotoreDelModulo(rotore) else { return nil }
        let corrente = (p.currentItem?.targetElement as? ElementoLettura)?.indice
        let avanti = p.searchDirection == .next
        diario.registra(corrente ?? -1, "rotore:\(r.code):\(avanti ? "avanti" : "indietro")")
        guard let t = prossimo(nel: r, da: corrente, avanti: avanti, filtro: p.filterString) else { return nil }
        return NSAccessibilityCustomRotor.ItemResult(targetElement: elemento(t))
    }

    // MARK: Disegno (solo le righe visibili) e tastiera

    public override func draw(_ dirtyRect: NSRect) {
        NSColor.textBackgroundColor.setFill(); dirtyRect.fill()
        // Il colore pieno del testo (non quello delle etichette, trasparente all'85 %), corpo 16 di peso medio, su una riga sola
        // troncata in coda: tratti pieni, contrasto pieno (l'audit di sistema bocciava a volte il tondo sottile, misurato).
        let riga1 = NSMutableParagraphStyle(); riga1.lineBreakMode = .byTruncatingTail
        let normale: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 16, weight: .medium), .foregroundColor: NSColor.textColor,
                                                      .paragraphStyle: riga1]
        let titolo: [NSAttributedString.Key: Any] = [.font: NSFont.boldSystemFont(ofSize: 16), .foregroundColor: NSColor.textColor,
                                                     .paragraphStyle: riga1]
        for i in righeVisibili {
            let riga = rettangolo(i)
            guard riga.intersects(dirtyRect) else { continue }
            if fuoco == i {
                // La riga col fuoco ha una barra nel margine, non uno sfondo: il testo resta sul suo fondo, col contrasto pieno.
                NSColor.labelColor.setFill()
                NSBezierPath(roundedRect: NSRect(x: 2, y: riga.minY + 3, width: 5, height: riga.height - 6), xRadius: 2, yRadius: 2).fill()
            }
            // Si vede ciò che si sente (il testo pronunciato, qualifica del titolo compresa): la stessa resa per chi guarda e per
            // chi ascolta, e l'audit di sistema del contrasto ritrova nell'immagine il testo dell'elemento (misurato l'8 novembre).
            let t = String(testoPronunciato(i).prefix(160))
            (t as NSString).draw(in: riga.insetBy(dx: 6, dy: 4),
                                 withAttributes: ReadingSpeech.isHeadingRole(segmento(i).role) ? titolo : normale)
        }
    }

    public override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 125: riceviFuoco(min(conteggio - 1, (fuoco ?? -1) + 1), origine: .tastiera)   // freccia giù
        case 126: riceviFuoco(max(0, (fuoco ?? 1) - 1), origine: .tastiera)                // freccia su
        default: super.keyDown(with: event)
        }
    }
}
