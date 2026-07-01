//
//  ContinuousReadingViewController.swift
//  ScaboApp
//
//  Ospita il Layout "Lettura Continua" su DUE container di accessibilità separati e CHIUSI
//  (§ 2.3, § 3.1): il container del TESTO (`ContinuousReadingView`, dove vive solo il documento)
//  e il container dell'INTERFACCIA (`ReadingInterfaceBar`, per ora titolo + Indietro, struttura
//  permanente per la futura toolbar). Riceve dall'esterno il contenuto già elaborato dal flusso
//  di import/elaborazione: nessun caricamento autonomo nel percorso utente.
//
//  ── Sigillatura con array-di-radice attivo + modalità + scrub (§ 2.2/§ 2.3) ──────────────────
//
//  La prova su dispositivo (TestFlight build 3) della versione APERTA ha confermato il difetto
//  predetto: senza modalità lo swipe lineare ATTRAVERSA il confine fra i container (swipe indietro
//  dal primissimo elemento del testo scivolava nell'interfaccia; swipe avanti dall'interfaccia
//  saltava nel testo). Il § 2.2 (il primo/ultimo elemento ASSOLUTO del testo è il limite dello
//  swipe) impone che ciò non accada.
//
//  Build 4 (correzione precedente, INSUFFICIENTE — diagnosi sotto): si era usato il SOLO
//  `accessibilityViewIsModal` sul container attivo, lasciando però la radice con ENTRAMBI i
//  container sempre presenti (`view.accessibilityElements = [interfaceBar, readingView]`). La prova
//  su dispositivo ha rivelato che la blindatura tiene nelle pagine INTERNE ma SI ROMPE ai DUE
//  ESTREMI ASSOLUTI: dal primissimo elemento del testo lo swipe indietro raggiungeva ancora la
//  barra; dall'interfaccia lo swipe avanti rientrava nel testo forzandolo al primissimo elemento.
//
//  Causa radice: il pruning dei FRATELLI di `accessibilityViewIsModal` è applicato da UIKit durante
//  la visita AUTOMATICA della gerarchia di viste; quando il padre espone un `accessibilityElements`
//  ESPLICITO, VoiceOver consuma quell'array e l'esclusione modale del sibling NON è applicata in
//  modo affidabile. Nelle pagine interne i due array dei container non si incontrano mai (ci si
//  muove dentro l'unico array piatto dei segmenti), quindi il buco è invisibile; l'UNICA giunzione
//  reale è [ultimo elemento dell'interfaccia ↔ primo segmento] e, simmetricamente, [ultimo segmento
//  ↔ fine]. È esattamente lì, e solo lì, che il modale-da-solo lasciava concatenati i due container
//  nello swipe lineare ("come l'elemento prima o dopo normalmente", oss. dello sviluppatore). Il
//  "funziona nelle pagine interne" non era prova di sigillo: era solo l'array dei segmenti
//  contiguo, lontano dalla giunzione. La modalità-da-sola, di fatto, non sigillava nulla.
//
//  Meccanismo adottato (build 5): il sigillo è STRUTTURALE. La radice espone nel suo
//  `accessibilityElements` SOLO il container ATTIVO ( `[readingView]` quando il testo è attivo,
//  `[interfaceBar]` quando l'interfaccia è attiva). Sparita dall'array la controparte, sparisce la
//  giunzione: lo swipe indietro dal primo segmento e avanti dall'ultimo cadono sul bordo dell'array
//  del PROPRIO container → scatta il segnale standard iOS "fine raggiunta" (§ 2.2, unica eccezione
//  ammessa al non-blocco). Nessun elemento dell'altro container è più raggiungibile né via swipe né
//  via tocco. Il flag `accessibilityViewIsModal` resta impostato sul container attivo come RINFORZO
//  semantico (modalità), ma il portante del sigillo è la selezione dell'array di radice. Il
//  passaggio fra i due container avviene SOLO col gesto di scrub a due dita (escape), che commuta
//  quale container è esposto+modale, in entrambe le direzioni. Nessun gesto VoiceOver è ridefinito
//  (§ 2.4): si definisce solo la risposta all'azione di escape.
//
//  La navigazione DENTRO il testo (intra-pagina e inter-pagina logica) è INVARIATA: `Continuous
//  ReadingView` non è toccata; il suo unico array piatto e continuo dei segmenti resta intatto, e
//  la radice ne espone l'intero container. Il § 2.2 di continuità del testo, che già funziona, non
//  è toccato in alcun modo da questa correzione (che vive interamente nel view controller).
//
//  ── Ripristino della posizione di lettura (difetto a sé, corretto qui) ───────────────────────
//
//  Il rientro nel testo dall'interfaccia NON deve resettare la posizione: si torna all'elemento
//  DOVE l'utente era, non al primissimo. La reading view ricorda l'ultimo segmento messo a fuoco
//  (`lastFocusedTextElement`), e la riattivazione del container del testo riporta il fuoco LÌ, non
//  sul primo elemento.
//
//  Onestà sulla verifica: i test (Simulator) certificano la STRUTTURA — i due container sono
//  oggetti distinti con `accessibilityElements` DISGIUNTI; la radice espone SOLO il container
//  attivo (perciò la controparte è assente dall'array piatto di swipe, estremi assoluti compresi);
//  l'escape commuta quale container è esposto+modale; la POSIZIONE ricordata sopravvive al ciclo
//  interfaccia→testo via scrub. Il confinamento effettivo dello swipe all'orecchio (incluso il
//  segnale "fine raggiunta" ai due estremi) e lo spostamento reale del fuoco sono comportamento
//  VoiceOver RUNTIME non riproducibile dal Simulator: li certifica lo sviluppatore su dispositivo
//  (TestFlight); per raggiungere la barra deve usare lo SCRUB a due dita.
//

import UIKit
import ScaboCore

final class ContinuousReadingViewController: UIViewController {

    // MARK: - Container del testo e dell'interfaccia

    private let readingView = ContinuousReadingView()
    private let interfaceBar = ReadingInterfaceBar()

    /// Contenuto di corpo da rendere (iniettato dal flusso di elaborazione).
    private let content: PaginatedContent

    /// Azione del tasto Indietro: torna alla Home. Impostata dal presentatore.
    var onBack: (() -> Void)?

    /// Id del documento (per la persistenza della posizione di lettura). Vuoto se non pertinente
    /// (es. test che istanziano il lettore senza libreria).
    private let documentId: String

    /// Posizione di lettura da ripristinare all'apertura (§ 2.5): indice 0-based nel flusso. 0 =
    /// inizio (nessun ripristino, VoiceOver si posa sul primo elemento).
    private let initialReadingPosition: Int

    /// Notifica del cambio di posizione di lettura, inoltrata alla persistenza dal presentatore.
    private let onPositionChanged: ((Int) -> Void)?

    /// Numero di pagine del PDF di origine, per l'indicatore doppio (§ 4.3). 0 = non pertinente.
    private let sourcePageCount: Int

    /// Se mostrare anche la pagina del file originale nell'indicatore (toggle globale, § 4.2).
    private let showOriginalPages: Bool

    /// Mappa id-segmento → pagina del file originale (1-based), o `nil` se non disponibile per quel
    /// segmento. Iniettata dal presentatore (costruita dalla mappa nodo→pagina del documento).
    private let sourcePage: ((String) -> Int?)?

    /// Flusso Dottrina Inline (§ 10), `nil` se il documento non ha note → il selettore mostra il
    /// layout disabilitato (§ 10.3). Si apre SEMPRE in `.continuous` (default, § 3.4).
    private let doctrineContent: PaginatedContent?

    /// Albero della Consultazione Rapida (§ 8), `nil` se il documento non ha gerarchia → il
    /// selettore mostra il Layout disabilitato (§ 8.8). Si apre SEMPRE in `.continuous`.
    private let quickConsultTree: [QuickConsultNode]?

    /// Titolo del documento (per la catena gerarchica estesa, § 7).
    private let documentTitle: String

    /// La vista ad albero della Consultazione Rapida, creata pigramente al primo ingresso nel
    /// Layout (è il TERZO container di accessibilità, alternativo al testo).
    private var quickConsultView: QuickConsultView?

    /// Stato dell'albero (tendine espanse) persistito per documento (§ 2.5 / § 8.2).
    private lazy var quickExpandedState: Set<String> = loadQuickExpandedState()

    /// Mappa id-nodo → testo per il contenuto delle foglie (costruita dal flusso Lettura Continua).
    private lazy var quickNodeText: [String: String] = buildQuickNodeText()

    /// Layout attualmente reso. Default `.continuous` per ogni documento (l'Estratto e tutti gli
    /// altri partono identici a prima); Dottrina Inline è una scelta esplicita dal selettore.
    private var currentLayout: LayoutId = .continuous

    /// Ultima posizione di lettura nota IN LETTURA CONTINUA (l'unica persistita, § 2.5). In Dottrina
    /// Inline gli indici sono di un altro flusso e NON sovrascrivono questa: così la riapertura al
    /// punto giusto in Lettura Continua resta intatta e l'Estratto è al sicuro.
    private var continuousPosition: Int

    /// Osservatore del cambio di stato di VoiceOver (riaggancio in lettura). Rimosso in deinit.
    private var voiceOverObserver: NSObjectProtocol?

    /// Il ripristino della posizione avviene una sola volta, alla prima comparsa.
    private var didRestorePosition = false

    /// Player dei segnali acustici (seam per i test). Cablato: `mode1`, riprodotto
    /// all'attivazione del Layout Lettura Continua (l'unico Layout reso oggi).
    private let signalPlayer: SignalPlaying

    /// Il segnale di attivazione del Layout suona una sola volta alla comparsa.
    private var didPlayModeSignal = false

    private static let interfaceBarHeight: CGFloat = 44

    // MARK: - Init

    /// Costruisce la reading view sul contenuto già elaborato. `sourceName` è conservato per usi
    /// futuri (referto, persistenza); il titolo del container d'interfaccia è fisso
    /// "Lettura Continua".
    init(
        content: PaginatedContent,
        sourceName: String = "",
        documentId: String = "",
        initialReadingPosition: Int = 0,
        onPositionChanged: ((Int) -> Void)? = nil,
        sourcePageCount: Int = 0,
        showOriginalPages: Bool = false,
        sourcePage: ((String) -> Int?)? = nil,
        doctrineContent: PaginatedContent? = nil,
        quickConsultTree: [QuickConsultNode]? = nil,
        signalPlayer: SignalPlaying = SignalPlayer.shared
    ) {
        self.content = content
        self.quickConsultTree = quickConsultTree
        self.documentTitle = sourceName
        self.documentId = documentId
        self.initialReadingPosition = initialReadingPosition
        self.continuousPosition = max(0, initialReadingPosition)
        self.onPositionChanged = onPositionChanged
        self.sourcePageCount = sourcePageCount
        self.showOriginalPages = showOriginalPages
        self.sourcePage = sourcePage
        self.doctrineContent = doctrineContent
        self.signalPlayer = signalPlayer
        super.init(nibName: nil, bundle: nil)
    }

    deinit {
        if let token = voiceOverObserver {
            NotificationCenter.default.removeObserver(token)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) non supportato: ContinuousReadingViewController è costruito in codice.")
    }

    // MARK: - Ciclo di vita

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        embedContainers()
        wireContainers()
        readingView.render(content)
        // Persistenza della posizione di lettura (§ 2.5): ogni cambio di fuoco aggiorna lo store e
        // l'indicatore di pagina in toolbar (§ 4.3, silenzioso: nessun annuncio, § 4.5).
        readingView.onReadingPositionChanged = { [weak self] index in
            guard let self else { return }
            // La posizione si PERSISTE solo in Lettura Continua (l'indice di Dottrina Inline è di
            // un altro flusso e non deve corrompere il punto di lettura salvato, § 2.5).
            if self.currentLayout == .continuous {
                self.continuousPosition = index
                self.onPositionChanged?(index)
            }
            self.updatePageIndicator()
        }
        // Ricalcolo dell'impaginazione visiva (rotazione, Dynamic Type) → aggiorna il totale pagine.
        readingView.onPaginationChanged = { [weak self] in self?.updatePageIndicator() }
        // Selettore di Layout (§ 3.4): Dottrina Inline disponibile solo se il documento ha note
        // (§ 10.3). Default Lettura Continua.
        configureLayoutSelector()
        // Segnalibri e tag (§ 5): azioni personalizzate sugli elementi + pulsante Segnalibri in
        // toolbar. Attivi solo per un documento reale (id non vuoto).
        setUpBookmarks()
        // Posizione di lettura ricordata: la si preimposta come ultima posizione (senza spostare
        // ancora il fuoco) così il rientro nel testo e il ripristino alla comparsa vi puntano.
        readingView.presetReadingPosition(toIndex: initialReadingPosition)
        // Riaggancio di VoiceOver in lettura (§ 2.5, caso distinto dalla riapertura del documento):
        // quando VoiceOver si riattiva mentre questa schermata è in primo piano, il fuoco non deve
        // cadere sul primo elemento del file. Si osserva il cambio di stato e si riporta il fuoco
        // dove l'utente era (ritorno diretto al segmento). Vedi `voiceOverStatusChanged`.
        voiceOverObserver = NotificationCenter.default.addObserver(
            forName: UIAccessibility.voiceOverStatusDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in self?.voiceOverStatusChanged() }
        // Si entra leggendo: il testo è il container attivo (modale). Nessun fuoco forzato qui:
        // alla comparsa VoiceOver si posa sul primo elemento (o sulla posizione ripristinata).
        activateTextContainer(restoreFocus: false)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Attivazione del Layout Lettura Continua: suona il segnale `mode1` una volta sola,
        // alla comparsa effettiva (dopo l'apertura automatica dal flusso di import). Si
        // mischia col parlato VoiceOver d'ingresso senza sopprimerlo (sessione `.mixWithOthers`).
        guard !didPlayModeSignal else { return }
        didPlayModeSignal = true
        signalPlayer.play(.mode1)
        restoreReadingPositionIfNeeded()
        updatePageIndicator()
    }

    // MARK: - Selettore di Layout (§ 3.4 / § 10)

    /// (Ri)configura il selettore della toolbar con il layout corrente e la disponibilità di
    /// Dottrina Inline, instradando la scelta a `switchLayout`.
    private func configureLayoutSelector() {
        interfaceBar.configureLayoutSelector(
            current: currentLayout,
            doctrineAvailable: doctrineContent != nil,
            quickAvailable: quickConsultTree != nil
        ) { [weak self] layout in self?.switchLayout(to: layout) }
    }

    /// Cambia il layout reso. Lettura Continua ⇄ Dottrina Inline: ridisegna il flusso scelto,
    /// riconfigura il selettore, suona il segnale di attivazione del Layout (asset esistenti
    /// `mode-1`/`mode-3`, § AudioSignals — nessun audio nuovo), e posiziona il fuoco. La POSIZIONE
    /// di lettura ricordata in Lettura Continua è preservata e ripristinata al ritorno; entrando in
    /// Dottrina Inline il fuoco parte dal primo elemento (mappatura cross-layout = rinvio).
    private func switchLayout(to layout: LayoutId) {
        guard layout != currentLayout else { return }
        // Consultazione Rapida (§ 8): è una VISTA AD ALBERO distinta, non un flusso piatto. Mostra
        // il container-albero al posto del testo; gli altri due Layout restano sul flusso continuo.
        if layout == .quick {
            guard let roots = quickConsultTree else { return }  // disabilitato: nessuna gerarchia
            currentLayout = .quick
            showQuickConsult(roots)
            configureLayoutSelector()
            signalPlayer.play(.mode1)
            return
        }
        let target: PaginatedContent
        switch layout {
        case .doctrine:
            guard let doctrine = doctrineContent else { return }  // disabilitato: nessuna nota
            target = doctrine
        case .continuous, .quick:
            target = content
        }
        let comingFromQuick = currentLayout == .quick
        currentLayout = layout
        if comingFromQuick { hideQuickConsult() }
        readingView.render(target)
        view.layoutIfNeeded()
        configureLayoutSelector()
        interfaceBar.setQuickControls(visible: false, canNavigate: false)
        signalPlayer.play(layout == .doctrine ? .mode3 : .mode1)
        let focusTarget: Any
        if layout == .continuous {
            readingView.presetReadingPosition(toIndex: continuousPosition)
            focusTarget = readingView.element(atIndex: continuousPosition) ?? readingView
        } else {
            focusTarget = readingView.element(atIndex: 0) ?? readingView
        }
        activateTextContainer(restoreFocus: false)
        UIAccessibility.post(notification: .screenChanged, argument: focusTarget)
    }

    // MARK: - Consultazione Rapida (§ 8): vista ad albero collassabile

    /// Mostra il container-albero: lo crea pigramente, lo rende attivo (sigillo strutturale →
    /// lo swipe resta nell'albero), mostra i controlli §8.5 in toolbar, posa il fuoco sulla prima
    /// voce. § 8.7: da Lettura Continua a Rapida si ripristina l'ultimo stato dell'albero.
    private func showQuickConsult(_ roots: [QuickConsultNode]) {
        let tree = quickConsultView ?? makeQuickConsultView(roots)
        readingView.isHidden = true
        tree.isHidden = false
        view.layoutIfNeeded()
        view.accessibilityElements = [tree]
        readingView.accessibilityViewIsModal = false
        tree.accessibilityViewIsModal = true
        interfaceBar.setQuickControls(visible: true, canNavigate: tree.canNavigateExpandedLeaves)
        UIAccessibility.post(notification: .screenChanged, argument: tree.firstRowElement ?? tree)
    }

    /// Nasconde il container-albero e torna al container del testo (al passaggio a un altro Layout).
    private func hideQuickConsult() {
        quickConsultView?.isHidden = true
        quickConsultView?.accessibilityViewIsModal = false
        readingView.isHidden = false
    }

    /// Crea la vista ad albero, la inserisce nella gerarchia (sovrapposta al testo), e ne cabla
    /// la persistenza dello stato e l'escape verso l'interfaccia.
    private func makeQuickConsultView(_ roots: [QuickConsultNode]) -> QuickConsultView {
        let tree = QuickConsultView(roots: roots, nodeText: quickNodeText,
                                    documentTitle: documentTitle, expanded: quickExpandedState)
        tree.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tree)
        NSLayoutConstraint.activate([
            tree.topAnchor.constraint(equalTo: interfaceBar.bottomAnchor),
            tree.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tree.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tree.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        tree.onEscape = { [weak self] in self?.activateInterfaceContainer() }
        tree.onExpansionChanged = { [weak self] expanded in
            guard let self else { return }
            self.quickExpandedState = expanded
            self.saveQuickExpandedState(expanded)
            // Le frecce §8.5 sono attive solo con ≥ 2 foglie espanse.
            self.interfaceBar.setQuickControls(
                visible: true, canNavigate: self.quickConsultView?.canNavigateExpandedLeaves ?? false)
        }
        quickConsultView = tree
        return tree
    }

    /// Costruisce la mappa id-nodo → testo dal flusso di Lettura Continua (i segmenti portano l'id
    /// del nodo, eventualmente granularizzato `id#k`): per il contenuto delle foglie nell'albero.
    private func buildQuickNodeText() -> [String: String] {
        var map: [String: String] = [:]
        for page in content.pages {
            for seg in page.segments {
                let base = seg.id.split(separator: "#", maxSplits: 1,
                                        omittingEmptySubsequences: false).first.map(String.init) ?? seg.id
                if let existing = map[base] { map[base] = existing + " " + seg.text }
                else { map[base] = seg.text }
            }
        }
        return map
    }

    private func quickExpandedDefaultsKey() -> String { "scabo.quickExpanded.\(documentId)" }

    private func loadQuickExpandedState() -> Set<String> {
        guard !documentId.isEmpty,
              let saved = UserDefaults.standard.array(forKey: quickExpandedDefaultsKey()) as? [String]
        else { return [] }
        return Set(saved)
    }

    private func saveQuickExpandedState(_ expanded: Set<String>) {
        guard !documentId.isEmpty else { return }
        UserDefaults.standard.set(Array(expanded), forKey: quickExpandedDefaultsKey())
    }

    // MARK: - Riaggancio di VoiceOver in lettura (ANCORA al tasto Indietro, definitiva)

    /// VoiceOver è stato attivato/disattivato. Alla RIATTIVAZIONE, mentre la reading view è in primo
    /// piano, VoiceOver — ricostruendo l'albero di accessibilità — atterrerebbe sul PRIMO elemento
    /// del container del testo (il primo segmento del file), facendo perdere il segno.
    ///
    /// Il collaudo su dispositivo ha ESCLUSO il ritorno diretto al segmento (il fuoco veniva
    /// comunque sbalzato a inizio documento): si adotta perciò l'ANCORA FORZATA al tasto Indietro,
    /// decisa e definitiva. A ogni riattivazione si sposta il fuoco sul tasto Indietro in alto a
    /// sinistra; da lì l'utente fa scrub e rientra nel container del testo DOVE era (il rientro via
    /// scrub ripristina l'ultima posizione, vedi `activateTextContainer(restoreFocus:)`), senza che
    /// il fuoco entri mai nel testo all'inizio del file. Nessuna eccezione. Si posta SUBITO e di
    /// nuovo dopo un breve ritardo, per vincere con certezza la corsa col fuoco automatico di
    /// VoiceOver alla riattivazione.
    @objc private func voiceOverStatusChanged() {
        guard UIAccessibility.isVoiceOverRunning, isViewLoaded, view.window != nil else { return }
        UIAccessibility.post(notification: .screenChanged, argument: reengagementTarget())
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self, UIAccessibility.isVoiceOverRunning, self.view.window != nil else { return }
            UIAccessibility.post(notification: .screenChanged, argument: self.reengagementTarget())
        }
    }

    /// L'ancora del riaggancio: SEMPRE il tasto Indietro (scelta definitiva, vedi sopra).
    private func reengagementTarget() -> NSObject { interfaceBar.backButton }

    // MARK: - Indicatore di pagina (§ 4.3)

    /// Ricalcola e applica l'indicatore di pagina in toolbar: pagina di visualizzazione corrente su
    /// totale (sempre), più la pagina del file originale quando il toggle è attivo e il dato è
    /// disponibile (§ 4.2/§ 4.3). Silenzioso: aggiorna solo il valore, nessun annuncio (§ 4.5).
    private func updatePageIndicator() {
        let total = readingView.visualPageCount
        let index = readingView.currentReadingElementIndex ?? max(0, initialReadingPosition)
        let visualPage = (readingView.visualPageIndex(ofElementAt: index) ?? 0) + 1
        var originalCurrent: Int? = nil
        if showOriginalPages, sourcePageCount > 0,
           let segId = readingView.segmentId(atIndex: index),
           let page = sourcePage?(segId) {
            originalCurrent = page
        }
        interfaceBar.setPageIndicator(
            visualizationCurrent: total > 0 ? visualPage : 0,
            visualizationTotal: total,
            originalCurrent: originalCurrent,
            originalTotal: sourcePageCount,
            showOriginal: originalCurrent != nil)
    }

    /// Ripristina il fuoco VoiceOver all'elemento della posizione di lettura ricordata (§ 2.5),
    /// una sola volta alla prima comparsa. Solo se la posizione non è l'inizio (per l'inizio si
    /// lascia il comportamento naturale: VoiceOver si posa sul primo elemento). Il layout è già
    /// avvenuto (viewDidAppear), quindi lo scroll porta la pagina in vista.
    private func restoreReadingPositionIfNeeded() {
        guard !didRestorePosition else { return }
        didRestorePosition = true
        guard initialReadingPosition > 0,
              let target = readingView.element(atIndex: initialReadingPosition) else { return }
        UIAccessibility.post(notification: .screenChanged, argument: target)
    }

    private func embedContainers() {
        interfaceBar.translatesAutoresizingMaskIntoConstraints = false
        readingView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(interfaceBar)
        view.addSubview(readingView)

        NSLayoutConstraint.activate([
            interfaceBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            interfaceBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            interfaceBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            interfaceBar.heightAnchor.constraint(equalToConstant: Self.interfaceBarHeight),

            readingView.topAnchor.constraint(equalTo: interfaceBar.bottomAnchor),
            readingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            readingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            readingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        // La radice espone nel suo `accessibilityElements` SOLO il container ATTIVO: è il sigillo
        // strutturale (vedi nota di testata). Quale dei due sia esposto lo decidono le `activate…`,
        // chiamate da `viewDidLoad` (testo attivo all'ingresso). Qui NON si fissa l'array: lo fissa
        // `activateTextContainer(restoreFocus:)` subito dopo, evitando uno stato in cui entrambi i
        // container sarebbero transitoriamente concatenati.
    }

    private func wireContainers() {
        interfaceBar.onBack = { [weak self] in self?.onBack?() }
        // Scrub a due dita (escape): UNICA via di passaggio fra container nello scenario blindato.
        // Commuta quale container è modale, in entrambe le direzioni.
        readingView.onEscape = { [weak self] in self?.activateInterfaceContainer() }
        // Dall'interfaccia si rientra nel container ATTIVO: testo, oppure albero in Rapida.
        interfaceBar.onEscape = { [weak self] in
            guard let self else { return }
            if self.currentLayout == .quick, let tree = self.quickConsultView {
                self.view.accessibilityElements = [tree]
                self.interfaceBar.accessibilityViewIsModal = false
                tree.accessibilityViewIsModal = true
                UIAccessibility.post(notification: .screenChanged, argument: tree.firstRowElement ?? tree)
            } else {
                self.activateTextContainer(restoreFocus: true)
            }
        }
        // Controlli §8.5 della Consultazione Rapida.
        interfaceBar.onResetStructure = { [weak self] in self?.confirmResetStructure() }
        interfaceBar.onPrevExpanded = { [weak self] in self?.quickConsultView?.navigateExpandedLeaf(forward: false) }
        interfaceBar.onNextExpanded = { [weak self] in self?.quickConsultView?.navigateExpandedLeaf(forward: true) }
    }

    /// "Reset struttura" (§ 8.5): pop-up di conferma (testo visivo esplicito per l'utente vedente;
    /// l'utente VoiceOver lo capisce dall'etichetta estesa) e, su conferma, comprime tutto l'albero.
    private func confirmResetStructure() {
        let alert = UIAlertController(
            title: "Reset struttura",
            message: "Comprimi tutte le tendine dell'albero e torna alla struttura di base "
                   + "(solo le voci del livello più alto).",
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Annulla", style: .cancel))
        alert.addAction(UIAlertAction(title: "Conferma", style: .destructive) { [weak self] _ in
            self?.quickConsultView?.collapseAll()
            self?.interfaceBar.setQuickControls(visible: true, canNavigate: false)
        })
        present(alert, animated: true)
    }

    // MARK: - Commutazione fra i due container (modalità sul container attivo)

    /// Rende ATTIVO il container del testo: la radice espone SOLO il testo (sigillo strutturale →
    /// lo swipe non può raggiungere l'interfaccia a nessun elemento, estremi assoluti compresi), col
    /// flag modale sul testo come rinforzo. Se `restoreFocus`, riporta il fuoco all'ULTIMO elemento
    /// di lettura (non al primo): è la correzione del reset di posizione, che vale ANCHE qui perché
    /// ora l'unica via di rientro nel testo è lo scrub (la giunzione di swipe è stata rimossa).
    private func activateTextContainer(restoreFocus: Bool) {
        view.accessibilityElements = [readingView]
        interfaceBar.accessibilityViewIsModal = false
        readingView.accessibilityViewIsModal = true
        if restoreFocus {
            // Posizione ricordata se esiste, altrimenti il container del testo (→ primo elemento).
            let target: Any = readingView.lastFocusedTextElement ?? readingView
            UIAccessibility.post(notification: .screenChanged, argument: target)
        }
    }

    /// Rende ATTIVO il container dell'interfaccia: la radice espone SOLO l'interfaccia (sigillo
    /// strutturale → lo swipe resta confinato fra [Indietro, titolo] e non rientra nel testo), col
    /// flag modale sull'interfaccia come rinforzo. Porta il fuoco sul tasto Indietro.
    private func activateInterfaceContainer() {
        view.accessibilityElements = [interfaceBar]
        readingView.accessibilityViewIsModal = false
        interfaceBar.accessibilityViewIsModal = true
        UIAccessibility.post(notification: .screenChanged, argument: interfaceBar.backButton)
    }

    // MARK: - Segnalibri e tag (§ 5)

    /// Lo store della libreria (segnalibri per-documento + tag globali). Confine di persistenza già
    /// predisposto per iCloud/Mac; nessuno store parallelo.
    private var libraryStore: LibraryStore { LibraryService.shared.store }

    /// Aggancia il coordinatore dei segnalibri al container del testo e mostra il pulsante
    /// Segnalibri in toolbar. Solo per un documento reale (id non vuoto): nei test senza libreria
    /// tutto resta invariato (nessuna azione, pulsante nascosto).
    private func setUpBookmarks() {
        guard !documentId.isEmpty else { return }
        readingView.bookmarkCoordinator = self
        interfaceBar.setBookmarksAvailable(true)
        interfaceBar.onBookmarks = { [weak self] in self?.openBookmarksWindow() }
    }

    /// Apre la finestra dei Segnalibri del documento (§ 5.4). È un container modale (§ 2.3); alla
    /// scelta di una voce si chiude e si salta al punto.
    private func openBookmarksWindow() {
        BookmarksWindowViewController.present(
            from: self, store: libraryStore, documentId: documentId
        ) { [weak self] anchorId, hint in
            self?.jumpToBookmark(anchorSegmentId: anchorId, hint: hint)
        }
    }

    /// Salta all'elemento di un segnalibro (§ 5.4). Se si è in un Layout che non rende il flusso
    /// continuo (Consultazione Rapida) o in Dottrina Inline (indici di un altro flusso), si torna
    /// prima a Lettura Continua, così il segnalibro atterra su un elemento reso e coerente con l'id
    /// con cui è stato creato.
    private func jumpToBookmark(anchorSegmentId: String, hint: Int) {
        if currentLayout != .continuous { switchLayout(to: .continuous) }
        let index = readingView.indexOfSegment(anchorId: anchorSegmentId, hint: hint)
        activateTextContainer(restoreFocus: false)
        if let element = readingView.element(atIndex: index) {
            UIAccessibility.post(notification: .screenChanged, argument: element)
        }
    }

    /// Anteprima (prime parole) dell'elemento marcato, per la lista dei segnalibri (§ 5.4).
    private static func previewText(_ text: String, wordLimit: Int = 12) -> String {
        let words = text.split(whereSeparator: { $0.isWhitespace })
        let head = words.prefix(wordLimit).map(String.init).joined(separator: " ")
        return words.count > wordLimit ? head + "…" : head
    }

    /// Riporta il fuoco all'elemento d'origine dopo un'operazione sui segnalibri (§ 2.3) e posta un
    /// breve annuncio di conferma. L'annuncio è leggermente ritardato per non essere sovrascritto dal
    /// cambio di schermo (calibratura all'orecchio sul dispositivo).
    private func announceAndReturnFocus(_ message: String, toSegmentId id: String, hint: Int) {
        let index = readingView.indexOfSegment(anchorId: id, hint: hint)
        activateTextContainer(restoreFocus: false)
        if let element = readingView.element(atIndex: index) {
            UIAccessibility.post(notification: .screenChanged, argument: element)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }

    // MARK: - Introspezione per i test (struttura dei due container + posizione)

    /// Il container del testo (sola lettura).
    var textContainerForTesting: ContinuousReadingView { readingView }
    /// Il container dell'interfaccia (sola lettura).
    var interfaceContainerForTesting: ReadingInterfaceBar { interfaceBar }
    /// Gli elementi esposti dalla radice: nello scenario blindato è il SOLO container attivo
    /// (sigillo strutturale). La controparte inattiva NON compare qui, perciò non è raggiungibile
    /// via swipe a nessun elemento, estremi assoluti compresi.
    var rootAccessibilityContainersForTesting: [NSObject] {
        (view.accessibilityElements as? [NSObject]) ?? []
    }
    /// Vero se il container del testo è il modale attivo (swipe confinato al testo, § 2.2).
    var textContainerIsModalForTesting: Bool { readingView.accessibilityViewIsModal }
    /// Vero se il container dell'interfaccia è il modale attivo.
    var interfaceContainerIsModalForTesting: Bool { interfaceBar.accessibilityViewIsModal }
    /// L'elemento di testo su cui il rientro riporterebbe il fuoco (posizione ricordata), per
    /// verificare che il ciclo interfaccia→testo NON resetti la posizione.
    var textFocusRestoreTargetForTesting: NSObject? { readingView.lastFocusedTextElement }
    /// L'elemento bersaglio del ripristino della posizione di lettura iniziale (§ 2.5), per i test.
    var restoredPositionTargetForTesting: NSObject? { readingView.element(atIndex: initialReadingPosition) }
    /// L'indice di posizione di lettura corrente esposto dalla view, per i test.
    var currentReadingPositionForTesting: Int? { readingView.currentReadingElementIndex }
    /// L'elemento su cui il riaggancio di VoiceOver riporta il fuoco: SEMPRE il tasto Indietro
    /// (ancora definitiva). Per i test.
    var reengagementTargetForTesting: NSObject? { reengagementTarget() }
    /// Forza l'aggiornamento dell'indicatore di pagina (per i test, senza ciclo di vita reale).
    func updatePageIndicatorForTesting() { updatePageIndicator() }
    /// Il layout attualmente reso (per i test del selettore).
    var currentLayoutForTesting: LayoutId { currentLayout }
    /// Vero se Dottrina Inline è disponibile (il documento ha note, § 10.3), per i test.
    var doctrineAvailableForTesting: Bool { doctrineContent != nil }
    /// Vero se Consultazione Rapida è disponibile (il documento ha gerarchia, § 8.8), per i test.
    var quickAvailableForTesting: Bool { quickConsultTree != nil }
    /// La vista ad albero (se creata), per i test.
    var quickConsultViewForTesting: QuickConsultView? { quickConsultView }
    /// Numero di segmenti correntemente resi (per verificare che lo switch cambi davvero il flusso).
    var renderedSegmentCountForTesting: Int { readingView.segmentLabels.count }
    /// Cambia layout come farebbe il selettore (per i test, senza UIMenu).
    func switchLayoutForTesting(to layout: LayoutId) { switchLayout(to: layout) }
}

// MARK: - ReadingBookmarkCoordinator (§ 5.1 / § 5.7)

extension ContinuousReadingViewController: ReadingBookmarkCoordinator {

    func existingBookmark(forSegmentId id: String) -> Bookmark? {
        libraryStore.bookmarks(documentId: documentId).first { $0.anchorSegmentId == id }
    }

    func addBookmark(segmentId: String, orderIndex: Int, segmentText: String) {
        let preview = Self.previewText(segmentText)
        let page = sourcePage?(segmentId)
        BookmarkEditorViewController.present(
            from: self, title: "Nuovo segnalibro", preview: preview,
            tags: libraryStore.tags(), initialName: nil, initialTagIds: []
        ) { [weak self] name, tagIds in
            guard let self else { return }
            self.libraryStore.addBookmark(
                documentId: self.documentId, anchorSegmentId: segmentId, orderIndexHint: orderIndex,
                name: name, preview: preview, originalPage: page, tagIds: tagIds)
            self.announceAndReturnFocus("Segnalibro aggiunto.", toSegmentId: segmentId, hint: orderIndex)
        }
    }

    func editBookmark(_ bookmark: Bookmark) {
        BookmarkEditorViewController.present(
            from: self, title: "Modifica segnalibro", preview: bookmark.preview,
            tags: libraryStore.tags(), initialName: bookmark.name, initialTagIds: Set(bookmark.tagIds)
        ) { [weak self] name, tagIds in
            guard let self else { return }
            self.libraryStore.updateBookmark(
                documentId: self.documentId, bookmarkId: bookmark.id, name: name, tagIds: tagIds)
            self.announceAndReturnFocus(
                "Segnalibro aggiornato.", toSegmentId: bookmark.anchorSegmentId, hint: bookmark.orderIndexHint)
        }
    }

    func removeBookmark(_ bookmark: Bookmark) {
        libraryStore.deleteBookmark(documentId: documentId, bookmarkId: bookmark.id)
        announceAndReturnFocus(
            "Segnalibro rimosso.", toSegmentId: bookmark.anchorSegmentId, hint: bookmark.orderIndexHint)
    }
}
