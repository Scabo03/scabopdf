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

/// `UILabel` che porta con sé il `ContentSegment` da cui è stato costruito, così i
/// test possono ispezionare la corrispondenza segmento→elemento accessibile.
final class SegmentLabel: UILabel {
    /// Il segmento sorgente (ordine, ruolo, testo).
    let segment: ContentSegment

    /// Notifica che VoiceOver ha messo a fuoco QUESTO elemento. La reading view la usa per
    /// ricordare l'ultima posizione di lettura, così il rientro nel testo (dall'interfaccia) torna
    /// dove l'utente era, non al primissimo elemento.
    var onBecomeFocused: (() -> Void)?

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

    /// L'elemento di testo su cui riportare il fuoco al rientro nel container del testo, o `nil`
    /// se nessuno è ancora stato messo a fuoco (in tal caso il chiamante ripiega sul primo).
    var lastFocusedTextElement: NSObject? { lastFocusedElement }

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
            self?.lastViewport = .zero
            self?.setNeedsLayout()
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
        segmentLabels = segments.map { makeLabel(for: $0) }
        segmentLabels.forEach { documentContainer.addSubview($0) }

        // ── Il cuore del vincolo sacro ──────────────────────────────────────────
        // UN solo container, UN solo array piatto e ordinato su TUTTO il documento.
        // Esplicito (non derivato dalla geometria) così l'ordine di lettura è
        // deterministico e il container resta unico per costruzione, attraverso ogni
        // pagina visiva.
        documentContainer.accessibilityElements = segmentLabels
    }

    private func makeLabel(for segment: ContentSegment) -> SegmentLabel {
        let label = SegmentLabel(segment: segment)
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
        label.accessibilityLabel = Self.spokenText(for: segment)

        // Tratto header per heading/divisori: navigazione per intestazioni nel
        // rotore, SENZA introdurre confini allo swipe.
        if Self.isHeadingRole(segment.role) {
            label.accessibilityTraits.insert(.header)
        }

        // Ricorda la posizione di lettura: quando VoiceOver mette a fuoco questa etichetta, diventa
        // l'elemento da ripristinare al rientro nel testo dall'interfaccia.
        label.onBecomeFocused = { [weak self, weak label] in
            self?.lastFocusedElement = label
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

    /// Testo che VoiceOver pronuncia: intro acustica (se presente) + testo.
    static func spokenText(for segment: ContentSegment) -> String {
        let intro = segment.acousticIntro.trimmingCharacters(in: .whitespacesAndNewlines)
        if intro.isEmpty {
            return segment.text
        }
        return "\(intro) \(segment.text)"
    }

    /// Vero per i ruoli da trattare come intestazione (tratto `.header`).
    static func isHeadingRole(_ role: String) -> Bool {
        role.hasPrefix("HEADING_") || role == SECTION_DIVIDER_ROLE
    }

    /// Stile tipografico (Dynamic Type) per ruolo.
    private static func textStyle(for role: String) -> UIFont.TextStyle {
        switch role {
        case "HEADING_1": return .title1
        case "HEADING_2": return .title2
        case "HEADING_3": return .title3
        case "HEADING_4": return .headline
        case SECTION_DIVIDER_ROLE: return .headline
        default: return .body
        }
    }
}
