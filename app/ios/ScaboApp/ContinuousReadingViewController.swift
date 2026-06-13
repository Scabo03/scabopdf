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

    /// Azione del tasto Indietro: torna alla Home nuda. Impostata dal presentatore.
    var onBack: (() -> Void)?

    private static let interfaceBarHeight: CGFloat = 44

    // MARK: - Init

    /// Costruisce la reading view sul contenuto già elaborato. `sourceName` è conservato per usi
    /// futuri (referto, persistenza); il titolo del container d'interfaccia è fisso
    /// "Lettura Continua".
    init(content: PaginatedContent, sourceName: String = "") {
        self.content = content
        super.init(nibName: nil, bundle: nil)
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
        // Si entra leggendo: il testo è il container attivo (modale). Nessun fuoco forzato qui:
        // alla comparsa VoiceOver si posa sul primo elemento del testo, ed è ciò che si vuole.
        activateTextContainer(restoreFocus: false)
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
        interfaceBar.onEscape = { [weak self] in self?.activateTextContainer(restoreFocus: true) }
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
}
