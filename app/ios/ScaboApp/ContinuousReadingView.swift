//
//  ContinuousReadingView.swift
//  ScaboApp
//
//  Reading view UIKit per il Layout "Lettura Continua" (gradino 2). Rende il CORPO
//  di un documento classificato (ScaboCore) come contenuto accessibile VoiceOver,
//  PAGINATO-MA-CONTINUO: pagine logiche di visualizzazione come presentazione,
//  sopra un UNICO container di accessibilità esteso a tutto il documento.
//
//  ── PERCHÉ paginato-ma-continuo (correzione della sessione 1) ────────────────────
//
//  La sessione 1 presentava il corpo come scroll verticale continuo, scartando la
//  pagina logica. Il prodotto (LAYER2_PRODUCT_DECISIONS.md § 3.3) prescrive invece
//  che il container del testo sia organizzato in PAGINE LOGICHE di visualizzazione
//  (blocchi finiti che riempiono lo schermo, stacco netto fra pagina e pagina,
//  paging orizzontale, NON scroll verticale continuo) MENTRE il container di
//  accessibilità sottostante resta UNITARIO E CONTINUO. L'analisi diagnostica
//  (docs/ANALYSIS_READING_VIEW_PAGINATION.md) ha stabilito che lo strato di
//  container della sessione 1 era già corretto e va conservato; va riscritto solo
//  lo strato di presentazione. Questo file lo fa.
//
//  ── VINCOLO INVIOLABILE — principio sacro del prodotto (§ 2.2) ──────────────────
//
//  Lo swipe orizzontale VoiceOver nel container del testo non deve MAI essere
//  ostacolato da un confine di PAGINA LOGICA: scorre fluido dall'ultimo elemento di
//  una pagina al primo della successiva senza handoff né blocco; unica eccezione è
//  il primo/ultimo elemento ASSOLUTO del documento.
//
//  Come è realizzato (modello identificato dall'analisi — UN container sigillato,
//  paging solo VISIVO):
//    • `documentContainer` è UN SOLO container di accessibilità. Il suo
//      `accessibilityElements` è UN UNICO array piatto e ordinato di TUTTI i
//      segmenti del documento, impostato in `rebuildLabels()` indipendentemente
//      dalla geometria. A livello di accessibilità i confini di pagina NON
//      ESISTONO: VoiceOver attraversa un solo array, quindi nessun oggetto-confine
//      può frapporsi ai bordi di pagina.
//    • Le PAGINE sono un fatto puramente VISIVO dello scroll: una `UIScrollView`
//      con `isPagingEnabled` orizzontale, il cui contenuto è largo `nPagine ×
//      viewport`. Ogni segmento è posato (a frame) nella colonna della sua pagina.
//      Il gesto nativo a tre dita opera il paging; quando VoiceOver mette a fuoco
//      un elemento di un'altra pagina, lo scroll lo porta in vista. Le pagine NON
//      frammentano il container.
//    • NON si usa l'architettura "un container per pagina" (es. UIPageViewController
//      con sotto-container per pagina): è quella del guasto Acrobat
//      (focus-hijacking ai confini) e il prodotto non la prescrive. ScaboPDF, non
//      essendo un viewer PDF, tiene UN container immune al passaggio fra pagine.
//
//  ── Impaginazione per misura (il punto tecnico non banale, § 3.3 / § 4.1) ───────
//
//  Le pagine logiche NON corrispondono alle pagine fisiche del PDF: si dimensionano
//  in base alla dimensione tipografica (Dynamic Type), all'orientamento e allo
//  schermo. Per questo l'impaginazione è calcolata QUI (la view ha la geometria),
//  non in ScaboCore (`Pagination.paginate` è un chunk per CONTEGGIO di segmenti,
//  geometry-agnostic: NON è la pagina-di-viewport; la view lo appiattisce e
//  ricalcola). Il packing è greedy per altezza misurata: ogni elemento è posato
//  intero su una pagina; se non entra nello spazio residuo va INTERO alla pagina
//  successiva — un elemento non è MAI spezzato a cavallo di due pagine. Si ricalcola
//  su cambio di viewport (rotazione) e di categoria Dynamic Type.
//
//  Caso limite dichiarato: un singolo elemento più alto di un'intera pagina occupa
//  una pagina propria; se eccede l'altezza, eccede visivamente in basso (clip per
//  l'utente vedente), ma il testo resta INTEGRO nell'`accessibilityLabel` — la
//  lettura VoiceOver, esperienza primaria, è completa. Il bounding della dimensione
//  dell'elemento è compito della granularità di lettura (§ 7.6), sessione futura.
//
//  ── Design bi-modale / seam / onestà sulla verifica ─────────────────────────────
//
//  Bi-modale: ogni segmento ha resa VISIVA (UILabel per ruolo, Dynamic Type) ed
//  accessibile (etichetta non vuota). Nessun gesto VoiceOver ridefinito. La view NON
//  importa PDFKit: consuma il modello già prodotto. Onestà: il Simulator NON
//  riproduce VoiceOver. Qui si garantisce la correttezza ARCHITETTURALE (container
//  unico, array piatto continuo su tutto il documento, ordine, paging visivo
//  presente); che lo swipe "scorra fluido" sul confine di pagina e che lo scroll
//  agganci pulito la pagina al passaggio di focus si certifica solo su iPhone reale
//  con VoiceOver (TestFlight).
//

import UIKit
import ScaboCore

/// Il coordinatore degli strumenti sull'elemento di testo (§ 5 segnalibri, § 6 sottolineature): la
/// reading view gli chiede lo stato (segnalibro esistente) e gli instrada le azioni. Lo implementa
/// il view controller, che ha lo store e le finestre modali. `weak` per rompere il ciclo di retain.
///
/// Due vie d'accesso distinte convergono qui: le **azioni personalizzate VoiceOver** (solo per i
/// segnalibri — § 5.1) usano `existingBookmark`/`addBookmark`/`editBookmark`/`removeBookmark`; il
/// **long press** dei vedenti (§ 5 + § 6) apre `presentElementMenu`, il menù unico con le voci
/// applicabili di segnalibro E sottolineatura. Le sottolineature NON hanno azioni VoiceOver
/// (decisione di prodotto: strumento solo-visivo/solo-vedenti).
protocol ReadingElementCoordinator: AnyObject {
    /// Il segnalibro che marca l'elemento con questo id-segmento, o `nil` se non ce n'è.
    func existingBookmark(forSegmentId id: String) -> Bookmark?
    /// Apre la finestra di creazione segnalibro (§ 5.7) per l'elemento indicato.
    func addBookmark(segmentId: String, orderIndex: Int, segmentText: String)
    /// Apre la finestra di modifica del segnalibro esistente.
    func editBookmark(_ bookmark: Bookmark)
    /// Rimuove il segnalibro (con l'annuncio VoiceOver).
    func removeBookmark(_ bookmark: Bookmark)
    /// Presenta il menù d'azione dei vedenti sull'elemento (§ 5 + § 6): voci di segnalibro e di
    /// sottolineatura secondo lo stato. `sourcePoint` è la posizione del dito nel sistema di
    /// coordinate della reading view (per l'ancoraggio del popover su iPad).
    func presentElementMenu(segmentId: String, orderIndex: Int, segmentText: String, sourcePoint: CGPoint)
}

/// `UILabel` che porta con sé il `ContentSegment` da cui è stato costruito, così i
/// test possono ispezionare la corrispondenza segmento→elemento accessibile.
final class SegmentLabel: UILabel {
    /// Il segmento sorgente (ordine, ruolo, testo).
    let segment: ContentSegment

    /// Notifica che VoiceOver ha messo a fuoco QUESTO elemento. La reading view la usa per
    /// ricordare l'ultima posizione di lettura, così il rientro nel testo (dall'interfaccia) torna
    /// dove l'utente era, non al primissimo elemento.
    var onBecomeFocused: (() -> Void)?

    /// La reading view proprietaria (debole): fornisce le azioni-segnalibro SU RICHIESTA, quando
    /// VoiceOver interroga l'elemento a fuoco. NON è un closure per-etichetta né un array
    /// pre-costruito: sui volumi enormi non aggiunge peso per-elemento (le azioni si costruiscono
    /// solo per l'elemento correntemente a fuoco). Vedi la nota di memoria in `makeLabel`.
    weak var owner: ContinuousReadingView?

    /// Indice di lettura 0-based dell'elemento nel flusso, cablato alla costruzione: così la
    /// costruzione delle azioni-segnalibro a fuoco è O(1), senza scandire tutte le etichette (sui
    /// volumi enormi, ~47k elementi, una scansione lineare a ogni swipe sarebbe percepibile).
    var readingIndex: Int = 0

    /// Azioni personalizzate VoiceOver (swipe verticale, § 5.1): calcolate PIGRAMENTE dall'owner solo
    /// quando VoiceOver le chiede per l'elemento a fuoco. `nil` (nessun owner o nessun coordinatore,
    /// es. nei test) → nessuna azione, comportamento storico invariato.
    override var accessibilityCustomActions: [UIAccessibilityCustomAction]? {
        get { owner?.bookmarkActions(for: self) }
        set { /* di sola-lettura: le azioni derivano dallo stato dei segnalibri */ }
    }

    init(segment: ContentSegment) {
        self.segment = segment
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) non supportato: SegmentLabel è costruita in codice.")
    }

    /// Hook standard di VoiceOver (UIAccessibilityFocus): NON ridefinisce alcun gesto (§ 2.4), si
    /// limita a registrare che questo elemento ha ricevuto il fuoco.
    override func accessibilityElementDidBecomeFocused() {
        onBecomeFocused?()
    }
}

/// La reading view del Layout "Lettura Continua": pagine logiche di visualizzazione
/// (paging orizzontale) sopra un container di accessibilità unico e continuo.
final class ContinuousReadingView: UIView {

    // MARK: - Sottoviste

    /// Scroll a PAGING ORIZZONTALE: ogni pagina riempie lo schermo, con stacco netto
    /// fra una pagina e la successiva. È il dispositivo di presentazione; non tocca
    /// l'accessibilità.
    private let scrollView = UIScrollView()

    /// IL container di accessibilità unico per l'INTERO documento (content view del
    /// paging scroll). Il suo `accessibilityElements` è l'array piatto e ordinato di
    /// tutti i segmenti; le pagine sono solo le colonne visive del suo frame.
    private let documentContainer = UIView()

    // MARK: - Stato

    /// Le etichette per-segmento, in ordine di lettura. Sola lettura per i test.
    private(set) var segmentLabels: [SegmentLabel] = []

    /// I segmenti correnti (ordine di lettura).
    private var segments: [ContentSegment] = []

    /// Per ogni pagina VISIVA, l'indice (in `segmentLabels`) del suo primo elemento.
    /// È bookkeeping di sola PRESENTAZIONE: l'accessibilità resta l'array piatto.
    /// `count` == numero di pagine visive. Esposto per i test sul confine di pagina.
    private(set) var pageStartElementIndices: [Int] = []

    /// L'ultimo viewport impaginato: evita ricalcoli inutili a parità di dimensione.
    private var lastViewport: CGSize = .zero

    /// Token dell'osservatore di cambio Dynamic Type (rimosso in deinit).
    private var contentSizeObserver: NSObjectProtocol?

    /// Azione di uscita dal container del testo (gesto di scrub a due dita = "escape" di
    /// VoiceOver, § 2.3/§ 2.4): impostata dal view controller per passare al container
    /// dell'interfaccia. Nil → l'escape non fa nulla (comportamento di default). Additivo: i test
    /// che istanziano la view direttamente non lo impostano e l'escape resta inerte.
    var onEscape: (() -> Void)?

    /// Override dell'escape standard di VoiceOver. NON ridefinisce un gesto (§ 2.4): risponde solo
    /// all'azione di escape sull'elemento corrente, instradandola all'`onEscape` del controller.
    override func accessibilityPerformEscape() -> Bool {
        guard let onEscape else { return false }
        onEscape()
        return true
    }

    /// L'ultimo `SegmentLabel` che ha ricevuto il fuoco VoiceOver (debole: si azzera al re-render
    /// e non trattiene l'etichetta). È la posizione di lettura corrente da ripristinare al rientro
    /// nel testo dall'interfaccia.
    private weak var lastFocusedElement: SegmentLabel?

    /// Ruolo dell'ULTIMO segmento messo a fuoco, per l'earcon di blocco bibliografico:
    /// l'effetto bibliografia suona solo sulla transizione di fuoco *da non-LETTERATURA a
    /// LETTERATURA* (ingresso del blocco), non su ogni voce adiacente dello stesso blocco
    /// (vedi `makeLabel`). Resettato a `nil` quando si ricostruisce il contenuto.
    private var lastFocusedRole: String?

    /// L'elemento di testo su cui riportare il fuoco al rientro nel container del testo, o `nil`
    /// se nessuno è ancora stato messo a fuoco (in tal caso il chiamante ripiega sul primo).
    var lastFocusedTextElement: NSObject? { lastFocusedElement }

    /// Notifica del cambio di posizione di lettura (§ 2.5): porta l'indice 0-based dell'elemento
    /// appena messo a fuoco nel flusso continuo. Il view controller la inoltra alla persistenza.
    /// Additivo: i test che istanziano la view direttamente non lo impostano e nessuno è notificato.
    var onReadingPositionChanged: ((Int) -> Void)?

    /// L'indice (in `segmentLabels`) dell'ultimo elemento messo a fuoco, o `nil` se nessuno.
    var currentReadingElementIndex: Int? {
        guard let element = lastFocusedElement else { return nil }
        return index(of: element)
    }

    /// L'elemento accessibile di indice dato (per il ripristino del fuoco), o `nil` se fuori range.
    func element(atIndex index: Int) -> NSObject? {
        guard index >= 0, index < segmentLabels.count else { return nil }
        return segmentLabels[index]
    }

    /// L'id del segmento di indice dato (per mappare la posizione alla pagina del file originale),
    /// o `nil` se fuori range.
    func segmentId(atIndex index: Int) -> String? {
        guard index >= 0, index < segmentLabels.count else { return nil }
        return segmentLabels[index].segment.id
    }

    /// Notifica che l'impaginazione VISIVA è stata ricalcolata (cambio viewport o Dynamic Type):
    /// il numero di pagine di visualizzazione può essere cambiato, e l'indicatore in toolbar va
    /// aggiornato. Additivo: chi non lo imposta non è notificato.
    var onPaginationChanged: (() -> Void)?

    /// Preimposta la posizione di lettura ripristinata SENZA spostare il fuoco: registra l'elemento
    /// come ultima posizione, così il successivo `screenChanged` del view controller vi porta il
    /// fuoco. Sicuro anche prima che le pagine visive siano calcolate.
    func presetReadingPosition(toIndex index: Int) {
        guard index > 0, index < segmentLabels.count else { return }
        lastFocusedElement = segmentLabels[index]
    }

    /// Indice di un elemento per IDENTITÀ (le label sono classi: niente Equatable di valore).
    private func index(of label: SegmentLabel) -> Int? {
        segmentLabels.firstIndex { $0 === label }
    }

    /// Player dei segnali acustici (seam per i test: § AudioSignals). Quando il fuoco
    /// VoiceOver entra in una NOTA VERA con un regime di lunghezza, si riproduce il
    /// segnale-nota del regime (§ 10.4/§ 10.5 del documento di prodotto). Default: il
    /// player condiviso; i test iniettano una spia.
    var signalPlayer: SignalPlaying = SignalPlayer.shared

    /// Il coordinatore degli strumenti sull'elemento (§ 5 / § 6), impostato dal view controller solo
    /// quando il documento è reale (id non vuoto). `nil` → nessuna azione (test, comportamento storico
    /// invariato). `weak`: il view controller possiede la view, non viceversa.
    weak var elementCoordinator: ReadingElementCoordinator?

    /// Costruisce le azioni-segnalibro VoiceOver per l'elemento a fuoco (§ 5.1). Chiamato PIGRAMENTE
    /// dal getter di `SegmentLabel.accessibilityCustomActions`, quindi solo per l'elemento
    /// correntemente interrogato da VoiceOver: nessun costo per-elemento sui volumi enormi. Elemento
    /// non marcato → "aggiungi segnalibro"; elemento marcato → "modifica" + "rimuovi". Le
    /// sottolineature NON compaiono qui: sono solo-vedenti (via long press), non hanno azioni VoiceOver.
    func bookmarkActions(for label: SegmentLabel) -> [UIAccessibilityCustomAction]? {
        guard let coordinator = elementCoordinator else { return nil }
        let segment = label.segment
        if let bookmark = coordinator.existingBookmark(forSegmentId: segment.id) {
            return [
                UIAccessibilityCustomAction(name: "Modifica segnalibro") { [weak coordinator] _ in
                    coordinator?.editBookmark(bookmark); return true
                },
                UIAccessibilityCustomAction(name: "Rimuovi segnalibro") { [weak coordinator] _ in
                    coordinator?.removeBookmark(bookmark); return true
                },
            ]
        }
        return [
            UIAccessibilityCustomAction(name: "Aggiungi segnalibro") { [weak coordinator] _ in
                coordinator?.addBookmark(
                    segmentId: segment.id, orderIndex: label.readingIndex, segmentText: segment.text)
                return true
            },
        ]
    }

    /// Apre il menù d'azione dei vedenti sull'elemento (§ 5 + § 6): instrada al coordinatore, che
    /// costruisce le voci di segnalibro e sottolineatura secondo lo stato. Punto d'ingresso unico del
    /// long press. `sourcePoint` è nel sistema di coordinate della reading view (per il popover iPad).
    func openElementMenu(for label: SegmentLabel, sourcePoint: CGPoint) {
        elementCoordinator?.presentElementMenu(
            segmentId: label.segment.id, orderIndex: label.readingIndex,
            segmentText: label.segment.text, sourcePoint: sourcePoint)
    }

    /// Long press (§ 5 + § 6, accesso NON-VoiceOver): individua l'elemento sotto il dito e apre il
    /// menù d'azione (segnalibro + sottolineatura). Reagisce solo a `.began` (una volta per pressione).
    ///
    /// Convivenza col vincolo sovrano dello swipe orizzontale (§ 2.2): il recognizer è UNO solo,
    /// condiviso; richiede il dito fermo (entro `allowableMovement`, ~10pt) per `minimumPressDuration`
    /// (0.5s), quindi qualunque swipe — che per definizione si muove — lo fa fallire e lascia vincere
    /// il paging dello scroll. Nessun `require(toFail:)` (bloccherebbe una pressione ferma) e nessuna
    /// simultaneità: i due gesti sono mutuamente esclusivi per natura (movimento vs immobilità), e
    /// `delaysTouches*` = false garantisce zero latenza su tap e swipe. Con VoiceOver attivo il gesto
    /// è intercettato da VoiceOver; qui usciamo comunque subito, così restano le azioni personalizzate.
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        guard !UIAccessibility.isVoiceOverRunning else { return }
        guard elementCoordinator != nil else { return }
        let point = gesture.location(in: documentContainer)
        guard let label = segmentLabels.first(where: { $0.frame.contains(point) }) else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        openElementMenu(for: label, sourcePoint: gesture.location(in: self))
    }

    /// Risolve l'ancora di un segnalibro (§ 5.6) in una posizione nello stream corrente: per id
    /// esatto del segmento, poi per id-nodo base (senza suffisso di granularità `#k`), infine
    /// ripiega sull'indice di fallback clampato (degradazione ragionevole, § 2.5). Usato per il
    /// salto al segnalibro dalla finestra Segnalibri.
    func indexOfSegment(anchorId: String, hint: Int) -> Int {
        if let i = segmentLabels.firstIndex(where: { $0.segment.id == anchorId }) { return i }
        let base = Self.baseNodeId(anchorId)
        if let i = segmentLabels.firstIndex(where: { Self.baseNodeId($0.segment.id) == base }) { return i }
        return min(max(0, hint), max(0, segmentLabels.count - 1))
    }

    /// L'id-nodo base di un id-segmento (toglie l'eventuale suffisso di granularità `#k`).
    static func baseNodeId(_ segmentId: String) -> String {
        segmentId.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
            .first.map(String.init) ?? segmentId
    }

    // MARK: - Navigazione per lo split (§ 11.4 / § 11.5) — indice, pagina, unità strutturale

    /// Numero di elementi (segmenti) resi.
    var elementCount: Int { segmentLabels.count }

    /// Il primo elemento (indice) della pagina visiva indicata, o `nil` se fuori range / non
    /// impaginato. Per il regime "segui-pagina" (§ 11.5).
    func firstElementIndex(ofVisualPage page: Int) -> Int? {
        guard page >= 0, page < pageStartElementIndices.count else { return nil }
        return pageStartElementIndices[page]
    }

    /// L'unità strutturale (0-based) a cui appartiene l'elemento: il numero di intestazioni fino a
    /// quell'elemento incluso. Per il regime "segui-livello" (§ 11.5). Un documento senza intestazioni
    /// ha una sola unità (0).
    func structuralUnitIndex(ofElementAt index: Int) -> Int {
        guard index >= 0, index < segmentLabels.count else { return 0 }
        var unit = 0
        for i in 0...index where Self.isHeadingRole(segmentLabels[i].segment.role) { unit += 1 }
        // L'unità 0 è "prima della prima intestazione"; ogni intestazione apre l'unità successiva.
        return max(0, unit - (Self.isHeadingRole(segmentLabels[index].segment.role) ? 0 : 0))
    }

    /// Numero totale di unità strutturali (intestazioni), minimo 1.
    var structuralUnitCount: Int {
        let headings = segmentLabels.reduce(0) { $0 + (Self.isHeadingRole($1.segment.role) ? 1 : 0) }
        return max(1, headings)
    }

    /// Porta in vista (scroll VISIVO) l'elemento indicato SENZA spostare il fuoco VoiceOver: è la
    /// sincronizzazione del follower nello split (§ 11.4), dove il fuoco resta sulla metà-guida e la
    /// metà che segue si allinea visivamente. Ricorda anche la posizione, così quando il fuoco entra
    /// nella metà-follower vi trova il punto sincronizzato.
    func revealElement(atIndex index: Int) {
        guard index >= 0, index < segmentLabels.count else { return }
        layoutIfNeeded()
        guard let page = visualPageIndex(ofElementAt: index) else { return }
        scrollView.setContentOffset(CGPoint(x: CGFloat(page) * bounds.width, y: 0), animated: false)
        presetReadingPosition(toIndex: index)
    }

    /// Porta la reading view all'elemento di indice `index` col meccanismo SANO (lo stesso che rende
    /// corretto lo scrub toolbar→testo): SCROLL visivo indipendente da VoiceOver — così la posizione
    /// è onorata ANCHE a VoiceOver spento — e, se `focus` e VoiceOver è attivo, vi posta il fuoco su
    /// un elemento CONCRETO. I percorsi di ripristino/salto (posizione iniziale, salto al segnalibro,
    /// ripristino dopo interruzione) prima si affidavano al SOLO `screenChanged`, che a VoiceOver
    /// spento non fa nulla (niente scroll → inizio file) ed è scavalcato dal reset automatico di
    /// VoiceOver dopo la chiusura di un modale/interfaccia di sistema. Questo metodo colma entrambe.
    func goToElement(atIndex index: Int, focus: Bool) {
        guard index >= 0, index < segmentLabels.count else { return }
        revealElement(atIndex: index)
        if focus, UIAccessibility.isVoiceOverRunning {
            UIAccessibility.post(notification: .screenChanged, argument: segmentLabels[index])
        }
    }

    /// La pagina visiva attualmente in vista (dallo scroll offset), per i test del posizionamento.
    var currentVisualPage: Int {
        guard bounds.width > 0 else { return 0 }
        return Int((scrollView.contentOffset.x / bounds.width).rounded())
    }

    /// Il primo elemento (indice) dell'unità strutturale indicata (l'intestazione che la apre), o
    /// `nil` se fuori range. Unità 0 = inizio documento.
    func firstElementIndex(ofUnit unit: Int) -> Int? {
        guard !segmentLabels.isEmpty else { return nil }
        if unit <= 0 { return 0 }
        var seen = 0
        for (i, label) in segmentLabels.enumerated() where Self.isHeadingRole(label.segment.role) {
            seen += 1
            if seen == unit { return i }
        }
        return segmentLabels.count - 1
    }

    // MARK: - Sottolineature (§ 6) — resa grafica additiva, solo-visiva

    /// I segmenti CORRENTEMENTE resi, in ordine (per la finestra di selezione a due fasi § 6.2, che
    /// ha bisogno dei blocchi consecutivi per le frecce `<`/`>`).
    var currentSegments: [ContentSegment] { segmentLabels.map { $0.segment } }

    /// Mappa id-segmento → intervalli di parole (inclusivi) da sottolineare. La costruisce il view
    /// controller una volta per render/mutazione dalle `Underline` dello store; qui è solo consumata.
    private var underlineRangesBySegmentId: [String: [ClosedRange<Int>]] = [:]

    /// Gli id dei segmenti a cui è attualmente applicato l'`attributedText` sottolineato: serve a
    /// ripristinare a testo puro quelli che non lo sono più (sottolineatura eliminata/modificata).
    private var styledSegmentIds: Set<String> = []

    /// Colore/spessore della sottolineatura (dettaglio grafico, regime UI): riga spessa color testo,
    /// ben visibile come strumento di marcatura per chi vede.
    private static let underlineStyle = NSUnderlineStyle.thick

    /// Imposta gli intervalli da sottolineare e (ri)applica la resa grafica. Chiamata dal view
    /// controller all'avvio e dopo ogni mutazione delle sottolineature.
    func setUnderlineRanges(_ map: [String: [ClosedRange<Int>]]) {
        underlineRangesBySegmentId = map
        applyUnderlineStyling()
    }

    /// (Ri)applica l'`attributedText` sottolineato ai soli segmenti interessati, e ripristina a testo
    /// puro quelli non più sottolineati. Additiva: **`accessibilityLabel` è ri-asserito identico**
    /// (rete A, il parlato non cambia). Tocca solo le etichette in mappa o già stilizzate → nessun
    /// costo per-elemento sul resto (i segmenti sottolineati sono pochissimi).
    private func applyUnderlineStyling() {
        let shouldStyle = Set(underlineRangesBySegmentId.filter { !$0.value.isEmpty }.keys)
        for label in segmentLabels {
            let id = label.segment.id
            if let intervals = underlineRangesBySegmentId[id], !intervals.isEmpty {
                label.attributedText = Self.underlinedAttributedString(
                    for: label.segment, intervals: intervals)
                // Rete A: il parlato resta esattamente quello (l'attributedText NON lo ridefinisce).
                label.accessibilityLabel = Self.intendedAccessibilityLabel(for: label.segment)
            } else if styledSegmentIds.contains(id) {
                // Non più sottolineato: torna al testo puro (path storico).
                label.attributedText = nil
                label.text = label.segment.text
                label.accessibilityLabel = Self.intendedAccessibilityLabel(for: label.segment)
            }
        }
        styledSegmentIds = shouldStyle
    }

    /// Costruisce l'`attributedText` di un segmento con l'attributo `.underlineStyle` sugli intervalli
    /// di parole indicati. L'underline è un ATTRIBUTO del testo (non una riga disegnata a parte):
    /// così resta sotto i glifi esatti a qualunque corpo carattere e con qualunque a-capo, senza
    /// calcoli geometrici (§ 6.5, requisito Dynamic Type). Il font è quello scalato corrente del ruolo.
    static func underlinedAttributedString(
        for segment: ContentSegment, intervals: [ClosedRange<Int>]
    ) -> NSAttributedString {
        let text = segment.text
        let font = UIFont.preferredFont(forTextStyle: textStyle(for: segment.role))
        let attributed = NSMutableAttributedString(
            string: text, attributes: [.font: font, .foregroundColor: UIColor.label])
        let words = WordTokenizer.wordRanges(text)
        guard !words.isEmpty else { return attributed }
        for interval in intervals {
            let lo = max(0, interval.lowerBound)
            let hi = min(words.count - 1, interval.upperBound)
            guard lo <= hi else { continue }
            let charRange = words[lo].lowerBound..<words[hi].upperBound
            let nsRange = NSRange(charRange, in: text)
            attributed.addAttribute(.underlineStyle, value: underlineStyle.rawValue, range: nsRange)
            attributed.addAttribute(.underlineColor, value: UIColor.label, range: nsRange)
        }
        return attributed
    }

    // MARK: - Metrica di lettura

    private enum Metrics {
        static let horizontalInset: CGFloat = 20
        static let verticalInset: CGFloat = 16
        static let interSegmentSpacing: CGFloat = 16
    }

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) non supportato: ContinuousReadingView è costruita in codice.")
    }

    deinit {
        if let token = contentSizeObserver {
            NotificationCenter.default.removeObserver(token)
        }
    }

    private func setUp() {
        backgroundColor = .systemBackground

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.isPagingEnabled = true
        scrollView.alwaysBounceVertical = false
        scrollView.alwaysBounceHorizontal = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        // Niente aggiustamento da safe area: i confini di pagina devono allinearsi
        // esattamente alla larghezza del viewport, senza offset.
        scrollView.contentInsetAdjustmentBehavior = .never
        addSubview(scrollView)

        // È un CONTAINER, non un elemento foglia: VoiceOver non lo mette a fuoco, ne
        // attraversa gli `accessibilityElements`. Frame gestito a mano in relayout.
        documentContainer.isAccessibilityElement = false
        scrollView.addSubview(documentContainer)

        // UN SOLO recognizer condiviso per il long press (§ 5.7, accesso non-VoiceOver): niente
        // peso per-elemento. Sta sul container del contenuto, così `location(in:)` mappa direttamente
        // ai frame dei segmenti. Convive col paging orizzontale senza toccarlo (vedi `handleLongPress`):
        // 0.5s a dito fermo → apre l'editor; ogni swipe lo fa fallire e lo scroll vince. Nessun
        // ritardo introdotto su tap/swipe.
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.5
        longPress.delaysTouchesBegan = false
        longPress.delaysTouchesEnded = false
        documentContainer.addGestureRecognizer(longPress)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        // Ricalcola l'impaginazione quando cambia la dimensione testo dell'utente
        // (Dynamic Type): le pagine logiche dipendono dalla tipografia (§ 4.1).
        contentSizeObserver = NotificationCenter.default.addObserver(
            forName: UIContentSizeCategory.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            // Il corpo carattere è cambiato: ricostruisci la resa dell'underline col font SCALATO
            // corrente, così la riga resta sotto i glifi giusti a qualunque dimensione (§ 6.5, nota
            // dello sviluppatore su Dynamic Type). L'underline è un ATTRIBUTO del testo, posato dal
            // renderer sotto i glifi esatti: ri-derivandolo col nuovo font l'allineamento è garantito.
            self.applyUnderlineStyling()
            self.lastViewport = .zero
            self.setNeedsLayout()
        }
    }

    // MARK: - Rendering (API pubblica della view)

    /// Renderizza un layout di ScaboCore. Le pagine logiche di `PaginatedContent`
    /// sono un chunk geometry-agnostic (per conteggio di segmenti) e NON sono la
    /// pagina-di-viewport: vengono APPIATTITE, e la view ricalcola le pagine VISIVE
    /// per misura (vedi docstring di testata). Il container di accessibilità resta
    /// unico e continuo su tutta la sequenza.
    func render(_ content: PaginatedContent) {
        render(content.pages.flatMap { $0.segments })
    }

    /// Renderizza una sequenza piatta di segmenti in ordine di lettura.
    func render(_ segments: [ContentSegment]) {
        self.segments = segments
        rebuildLabels()
        // Forza un nuovo calcolo di impaginazione al prossimo layout.
        lastViewport = .zero
        setNeedsLayout()
        layoutIfNeeded()
    }

    // MARK: - Costruzione degli elementi (accessibilità: indipendente dalla geometria)

    /// (Ri)costruisce un `SegmentLabel` per segmento e fissa il container di
    /// accessibilità. Sincrono e indipendente dal viewport: il container è valido
    /// subito dopo `render`, anche prima che il layout (le pagine VISIVE) sia
    /// calcolato.
    private func rebuildLabels() {
        segmentLabels.forEach { $0.removeFromSuperview() }
        // Le etichette precedenti spariscono: la posizione di lettura ricordata non è più valida.
        lastFocusedElement = nil
        lastFocusedRole = nil
        segmentLabels = segments.map { makeLabel(for: $0) }
        // Indice di lettura cablato: azioni-segnalibro a fuoco in O(1) (vedi `SegmentLabel.readingIndex`).
        for (i, label) in segmentLabels.enumerated() { label.readingIndex = i }
        segmentLabels.forEach { documentContainer.addSubview($0) }

        // ── Il cuore del vincolo sacro ──────────────────────────────────────────
        // UN solo container, UN solo array piatto e ordinato su TUTTO il documento.
        // Esplicito (non derivato dalla geometria) così l'ordine di lettura è
        // deterministico e il container resta unico per costruzione, attraverso ogni
        // pagina visiva.
        documentContainer.accessibilityElements = segmentLabels

        // Riapplica la resa grafica delle sottolineature (§ 6) alle nuove etichette (il re-render le
        // ha ricostruite). Additiva e solo-visiva: non tocca `accessibilityLabel`.
        styledSegmentIds = []
        applyUnderlineStyling()
    }

    private func makeLabel(for segment: ContentSegment) -> SegmentLabel {
        let label = SegmentLabel(segment: segment)
        // Owner debole per le azioni-segnalibro calcolate su richiesta (§ 5.1): nessun peso
        // per-elemento sui volumi enormi (le azioni si costruiscono solo per l'elemento a fuoco).
        label.owner = self
        // Frame manuali (l'impaginazione per misura posa le label a coordinate).
        label.translatesAutoresizingMaskIntoConstraints = true
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping

        // Resa VISIVA: stile tipografico per ruolo, con Dynamic Type.
        label.font = UIFont.preferredFont(forTextStyle: Self.textStyle(for: segment.role))
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .label
        label.text = segment.text

        // Resa ACCESSIBILE: etichetta mai vuota (un elemento senza resa è bug
        // critico). Include l'intro acustica del ruolo quando presente.
        label.isAccessibilityElement = true

        // Segnale-nota del regime di lunghezza (solo per le note VERE). Quando esiste,
        // il segnale acustico SOSTITUISCE l'intro verbale ("Nota."/"Nota lunga."): il
        // documento di prodotto (§ 10.4) prescrive che la conoscenza del regime arrivi
        // "esclusivamente dal segnale acustico, senza alcun annuncio verbale di durata
        // o caratterizzazione". Il CONTENUTO della nota resta integro nell'etichetta
        // (rete A): si toglie solo il prefisso parlato, non il testo.
        let noteSignal = Self.noteSignal(for: segment)
        // Composizione del parlato: [intro verbale] + [rinfresco di contesto] + [testo].
        // Quando un segnale-nota è presente, SOSTITUISCE l'intro verbale ("Nota lunga.")
        // ma il rinfresco di contesto (§ 7.4/§ 7.5) RESTA: è il recap della frase del
        // richiamo, additivo, mai sostitutivo del contenuto (rete A). L'etichetta parlata è
        // calcolata da `intendedAccessibilityLabel` e ri-asserita identica quando un segmento
        // riceve la resa visiva della sottolineatura (§ 6): il parlato NON cambia di un byte.
        label.accessibilityLabel = Self.intendedAccessibilityLabel(for: segment)

        // Tratto header per heading/divisori: navigazione per intestazioni nel
        // rotore, SENZA introdurre confini allo swipe.
        if Self.isHeadingRole(segment.role) {
            label.accessibilityTraits.insert(.header)
        }

        // Ricorda la posizione di lettura: quando VoiceOver mette a fuoco questa etichetta, diventa
        // l'elemento da ripristinare al rientro nel testo dall'interfaccia. Se è una nota vera con
        // un regime, riproduce QUI il segnale-nota di apertura (il fuoco entra nella nota, § 10.5).
        let role = segment.role
        label.onBecomeFocused = { [weak self, weak label] in
            guard let self else { return }
            self.lastFocusedElement = label
            // Posizione di lettura aggiornata (§ 2.5): notifica l'indice per la persistenza.
            if let label, let idx = self.index(of: label) {
                self.onReadingPositionChanged?(idx)
            }
            if let noteSignal {
                self.signalPlayer.play(noteSignal)
            }
            // Earcon di blocco bibliografico: precede il blocco LETTERATURA, una volta
            // all'INGRESSO (transizione di fuoco da non-LETTERATURA a LETTERATURA), non
            // su ogni voce adiacente dello stesso blocco — così non risulta martellante.
            if role == SemanticCategory.LETTERATURA.rawValue, self.lastFocusedRole != role {
                self.signalPlayer.play(.bibliography)
            }
            self.lastFocusedRole = role
        }
        return label
    }

    // MARK: - Layout: impaginazione per misura (presentazione, NON accessibilità)

    override func layoutSubviews() {
        super.layoutSubviews()
        let viewport = bounds.size
        guard viewport.width > 0, viewport.height > 0 else { return }
        if viewport != lastViewport {
            lastViewport = viewport
            relayoutPages(viewport: viewport)
        }
    }

    /// Posa i `SegmentLabel` in colonne larghe quanto il viewport (pagine visive),
    /// con packing greedy per altezza misurata. Aggiorna `pageStartElementIndices`,
    /// la dimensione del container e il `contentSize` del paging scroll. NON tocca
    /// l'array di accessibilità.
    private func relayoutPages(viewport: CGSize) {
        let hInset = Metrics.horizontalInset
        let vInset = Metrics.verticalInset
        let gap = Metrics.interSegmentSpacing

        let pageWidth = viewport.width
        let textWidth = max(1, pageWidth - 2 * hInset)
        let pageTop = vInset
        let pageBottom = max(pageTop + 1, viewport.height - vInset)

        guard !segmentLabels.isEmpty else {
            pageStartElementIndices = []
            documentContainer.frame = CGRect(origin: .zero, size: .zero)
            scrollView.contentSize = .zero
            onPaginationChanged?()
            return
        }

        var pageIndex = 0
        var cursorY = pageTop
        pageStartElementIndices = [0]

        for (index, label) in segmentLabels.enumerated() {
            let height = measuredHeight(label, width: textWidth)
            // Spaziatura se posato sulla pagina corrente (zero se è il primo della pagina).
            let spacingHere = (cursorY == pageTop) ? 0 : gap
            // Se l'elemento INTERO non entra nello spazio residuo della pagina (e la
            // pagina non è vuota), va INTERO alla pagina successiva: mai spezzato.
            if index > 0, cursorY > pageTop, cursorY + spacingHere + height > pageBottom {
                pageIndex += 1
                cursorY = pageTop
                pageStartElementIndices.append(index)
            }
            let spacing = (cursorY == pageTop) ? 0 : gap
            let y = cursorY + spacing
            let x = CGFloat(pageIndex) * pageWidth + hInset
            label.frame = CGRect(x: x, y: y, width: textWidth, height: height)
            cursorY = y + height
        }

        let pageCount = pageIndex + 1
        documentContainer.frame = CGRect(
            x: 0, y: 0, width: CGFloat(pageCount) * pageWidth, height: viewport.height)
        scrollView.contentSize = documentContainer.bounds.size
        onPaginationChanged?()
    }

    /// Altezza necessaria a una label per il suo testo, alla larghezza data e al
    /// font Dynamic Type corrente. È la misura su cui si decide il confine di pagina.
    private func measuredHeight(_ label: UILabel, width: CGFloat) -> CGFloat {
        let fitting = label.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return ceil(fitting.height)
    }

    // MARK: - Introspezione per i test

    /// Gli elementi accessibili ESPOSTI dal container, nell'ordine che VoiceOver
    /// attraversa. Unica superficie di accessibilità: un solo array piatto su tutto
    /// il documento.
    var exposedAccessibilityElements: [NSObject] {
        (documentContainer.accessibilityElements as? [NSObject]) ?? []
    }

    /// Vero se il container si espone come elemento foglia. DEVE essere falso.
    var isDocumentContainerAnAccessibilityElement: Bool {
        documentContainer.isAccessibilityElement
    }

    /// Il recognizer di long press per la creazione segnalibro (§ 5.7), per verificarne nei test la
    /// configurazione «swipe-safe» (durata + niente ritardo su tap/swipe) e l'unicità.
    var longPressGestureForTesting: UILongPressGestureRecognizer? {
        documentContainer.gestureRecognizers?
            .compactMap { $0 as? UILongPressGestureRecognizer }.first
    }

    /// Numero di pagine VISIVE prodotte dall'impaginazione corrente (0 se vuoto).
    var visualPageCount: Int { pageStartElementIndices.count }

    /// Vero se la presentazione è a paging orizzontale (sempre, by design).
    var isHorizontallyPaged: Bool { scrollView.isPagingEnabled }

    /// Vero se il contenuto si estende oltre un singolo viewport (≥ 2 pagine visive).
    var contentSpansMultiplePages: Bool {
        scrollView.contentSize.width > bounds.width + 0.5
    }

    /// La pagina VISIVA dell'elemento di indice dato (in `segmentLabels`), o `nil`
    /// se l'indice è fuori range o l'impaginazione non è ancora stata calcolata.
    func visualPageIndex(ofElementAt index: Int) -> Int? {
        guard index >= 0, index < segmentLabels.count, !pageStartElementIndices.isEmpty else {
            return nil
        }
        // Numero di inizi-pagina con start <= index, meno uno.
        var page = 0
        for (p, start) in pageStartElementIndices.enumerated() where start <= index {
            page = p
        }
        return page
    }

    /// Frame (in spazio contenuto) dell'elemento di indice dato — per verificare che
    /// le pagine successive stiano più a destra (paging orizzontale).
    func elementFrameInContent(at index: Int) -> CGRect? {
        guard index >= 0, index < segmentLabels.count else { return nil }
        return segmentLabels[index].frame
    }

    /// Vero se lo scroll NON espone propri sotto-elementi di accessibilità (così il
    /// solo container è `documentContainer`: nessun container per-pagina).
    var scrollViewHasNoAccessibilityElements: Bool {
        scrollView.accessibilityElements == nil
    }

    // MARK: - Mappature ruolo → stile / semantica

    /// Testo che VoiceOver pronuncia: intro acustica (se presente) + rinfresco di
    /// contesto (se nota differita) + testo. Le parti vuote sono omesse.
    static func spokenText(for segment: ContentSegment) -> String {
        spoken(intro: segment.acousticIntro, segment: segment)
    }

    /// L'etichetta accessibile INTESA per un segmento — l'unica fonte del parlato, usata sia da
    /// `makeLabel` sia dalla riapplicazione della resa visiva delle sottolineature (§ 6), così il
    /// parlato è byte-identico con o senza underline (rete A). Una nota vera col segnale acustico
    /// perde solo l'intro verbale (§ 10.4), il contenuto resta.
    static func intendedAccessibilityLabel(for segment: ContentSegment) -> String {
        noteSignal(for: segment) == nil
            ? spokenText(for: segment)
            : spoken(intro: "", segment: segment)
    }

    /// Compone il parlato con un `intro` esplicito (vuoto quando il segnale-nota lo
    /// sostituisce): `[intro] [memoryRefresh] [text]`, scartando le parti vuote. Il
    /// `text` (contenuto) è sempre presente: il rinfresco è additivo (rete A).
    static func spoken(intro: String, segment: ContentSegment) -> String {
        [intro, segment.memoryRefresh, segment.text]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// Il segnale-nota da riprodurre quando il fuoco entra in QUESTO segmento, o `nil`
    /// se non è una nota vera con un regime. La discriminazione "nota vera" riusa la
    /// scelta già fatta a monte: una `NOTE` con `acousticIntro` NON vuota è una nota
    /// d'apparato (avrebbe detto "Nota."); una `NOTE` con intro svuotata è una testatina
    /// collassata dal classificatore size-only (`suppressCollapsedHeadingNoteIntros`) e
    /// NON deve avere segnale. `EDITORIAL_NOTE` non porta `length_category` → nessun
    /// segnale, mantiene il suo intro verbale "Nota editoriale.".
    static func noteSignal(for segment: ContentSegment) -> AudioSignal? {
        guard segment.role == SemanticCategory.NOTE.rawValue,
              !segment.acousticIntro.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return nil
        }
        return AudioSignal.noteSignal(forLengthCategory: segment.lengthCategory)
    }

    /// Vero per i ruoli da trattare come intestazione (tratto `.header`).
    static func isHeadingRole(_ role: String) -> Bool {
        // ARTICLE_HEADER = l'intestazione d'articolo dei codici (categoria propria dopo lo
        // spostamento da HEADING_4): resta navigabile dal rotore "intestazioni" e fa scattare
        // l'earcon di transizione strutturale, esattamente come quando era HEADING_4.
        role.hasPrefix("HEADING_") || role == SECTION_DIVIDER_ROLE || role == "ARTICLE_HEADER"
    }

    /// Stile tipografico (Dynamic Type) per ruolo.
    private static func textStyle(for role: String) -> UIFont.TextStyle {
        switch role {
        case "HEADING_1": return .title1
        case "HEADING_2": return .title2
        case "HEADING_3": return .title3
        case "HEADING_4": return .headline
        case "ARTICLE_HEADER": return .headline   // intestazione d'articolo (ex HEADING_4)
        case SECTION_DIVIDER_ROLE: return .headline
        default: return .body
        }
    }
}
