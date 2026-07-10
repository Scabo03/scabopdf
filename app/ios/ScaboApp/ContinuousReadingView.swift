//
//  ContinuousReadingView.swift
//  ScaboApp
//
//  Reading view UIKit per il Layout "Lettura Continua". Rende il CORPO di un documento
//  classificato (ScaboCore) come contenuto accessibile VoiceOver, in SCROLL VERTICALE
//  sopra un contenitore nativo che RICICLA (`UICollectionView`): solo le celle visibili
//  (più il margine di riciclo di UIKit) sono elementi di accessibilità vivi, il resto è
//  fuori dalla finestra. È la finestra scorrevole nativa validata nel prototipo Fase 0.
//
//  ── PERCHÉ il contenitore nativo verticale ─────────────────────────────────────────
//
//  Il muro di memoria che rendeva illeggibili i volumi medio-grandi a VoiceOver era la
//  materializzazione di TUTTI gli elementi di accessibilità in un array piatto (~400 KB
//  per elemento, misurato su device: 3742 elementi → ~1544 MB). Il riciclo nativo tiene
//  vive solo le celle attorno al fuoco: sul banco, 50.000 elementi a VoiceOver acceso
//  stavano in decine di MB, con continuità di swipe perfetta in verticale. Il paging
//  ORIZZONTALE è stato abbandonato (VoiceOver si murava sulla prima pagina). Vedi i
//  referti del prototipo e dell'approfondimento verticale.
//
//  ── VINCOLO INVIOLABILE — swipe orizzontale continuo (§ 2.2) ────────────────────────
//
//  Lo swipe VoiceOver elemento-per-elemento scorre fluido da un capo all'altro del
//  documento, senza mai percepire un confine interno. In `UICollectionView` questo è la
//  continuità NATIVA delle liste lunghe (Contatti/Mail/Safari): VoiceOver naviga le celle
//  in ordine e scorre-e-materializza da solo. Il contenitore è UNO (la collection), i suoi
//  elementi sono le celle; nessun confine di pagina esiste a livello di accessibilità.
//
//  ── Il senso di pagina nel verticale (§ 3.3 / § 4, Opzione A) ───────────────────────
//
//  La "pagina di visualizzazione" orizzontale sintetica è caduta. Il senso di pagina
//  coincide con la PAGINA REALE del PDF: uno stacco visivo discreto (`PageMarkerView`) in
//  testa alla prima cella di ogni pagina originale. È NON focalizzabile e MUTO per
//  VoiceOver (§ 4.5: nessun annuncio automatico del cambio pagina): la cella è un elemento
//  foglia, le sue sotto-viste non sono esposte. Il numero di pagina del file originale
//  resta un dato del SEGMENTO (`pageProvider` = `sourcePage` del controller, che pesca
//  `page_index` del nodo): indipendente dall'impaginazione, si conserva per costruzione.
//
//  ── Bi-modale / strumenti al riuso della cella ──────────────────────────────────────
//
//  Ogni cella ha resa VISIVA (UILabel per ruolo, Dynamic Type, underline additivo) e
//  ACCESSIBILE (etichetta parlata mai vuota). Poiché le celle si RICICLANO, la resa —
//  underline compreso — si (ri)applica a OGNI configurazione (`SegmentCell.configure`),
//  non una volta a etichette persistenti. Nessun gesto VoiceOver ridefinito. Onestà: il
//  Simulator non riproduce VoiceOver; la continuità dello swipe e i fuochi si certificano
//  su device reale.
//

import UIKit
import ScaboCore

/// Il coordinatore degli strumenti sull'elemento di testo (§ 5 segnalibri, § 6 sottolineature): la
/// reading view gli chiede lo stato (segnalibro esistente) e gli instrada le azioni. Lo implementa
/// il view controller, che ha lo store e le finestre modali. `weak` per rompere il ciclo di retain.
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
    /// sottolineatura secondo lo stato. `sourcePoint` è nel sistema di coordinate della reading view.
    func presentElementMenu(segmentId: String, orderIndex: Int, segmentText: String, sourcePoint: CGPoint)
}

// MARK: - Marcatore di pagina originale (Opzione A): stacco visivo, MUTO per VoiceOver

/// Stacco discreto in testa alla prima cella di una pagina del file originale: una linea sottile e
/// un'etichetta "p. N". Puramente visivo — vive dentro una cella-elemento-foglia, quindi VoiceOver
/// non lo raggiunge né lo annuncia (§ 4.5).
final class PageMarkerView: UIView {
    private let line = UIView()
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = false
        line.backgroundColor = .separator
        line.translatesAutoresizingMaskIntoConstraints = false
        label.font = .preferredFont(forTextStyle: .caption2)
        label.textColor = .tertiaryLabel
        // La dimensione è pilotata ESPLICITAMENTE dalla leva "dimensione del testo" (via
        // `applyTextSizeTraits`), non dall'auto-adeguamento di UIKit: così lo stacco scala col corpo e
        // la sua altezza (in cache) combacia sempre con la resa. Il cambio di Dynamic Type di sistema è
        // gestito dalla reading view con una ri-misura completa (percorso cambio-larghezza).
        label.adjustsFontForContentSizeCategory = false
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(line)
        addSubview(label)
        NSLayoutConstraint.activate([
            line.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            line.leadingAnchor.constraint(equalTo: leadingAnchor),
            line.trailingAnchor.constraint(equalTo: trailingAnchor),
            line.heightAnchor.constraint(equalToConstant: 1),
            label.topAnchor.constraint(equalTo: line.bottomAnchor, constant: 2),
            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
        ])
    }
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func setPageNumber(_ page: Int?) {
        label.text = page.map { "p. \($0)" } ?? ""
    }

    /// Applica allo stacco la categoria di dimensione testo EFFETTIVA (leva + Dynamic Type di
    /// sistema), così il marcatore scala col corpo e la sua altezza resta congruente con la misura.
    func applyTextSizeTraits(_ traits: UITraitCollection) {
        label.font = .preferredFont(forTextStyle: .caption2, compatibleWith: traits)
    }
}

// MARK: - Cella-segmento (l'elemento di accessibilità riciclabile)

/// La cella che rende UN segmento. È l'elemento di accessibilità foglia (etichetta parlata, tratto
/// header, azioni-segnalibro a richiesta, earcon al fuoco). Si RICICLA: `configure` riapplica tutta
/// la resa (testo, font, underline, marcatore di pagina) ogni volta. Porta con sé il `ContentSegment`
/// così i test possono ispezionare la corrispondenza segmento→cella.
final class SegmentCell: UICollectionViewCell {
    static let reuseId = "SegmentCell"

    let textLabel = UILabel()
    private let pageMarker = PageMarkerView()
    private let stack = UIStackView()

    /// La reading view proprietaria (debole): fornisce azioni-segnalibro ed earcon su richiesta.
    weak var host: ContinuousReadingView?
    /// Il segmento e l'indice di lettura correnti (aggiornati a ogni `configure`).
    private(set) var segment: ContentSegment?
    private(set) var readingIndex: Int = 0

    /// Vincolo di larghezza a PIENA pagina: senza di esso l'auto-dimensionamento del flow layout
    /// dimensiona la cella alla larghezza del suo CONTENUTO (un segmento corto → cella stretta), e più
    /// celle corte finirebbero AFFIANCATE sulla stessa riga — rompendo sia la resa visiva sia l'ORDINE
    /// di lettura di VoiceOver (che segue la disposizione visiva). Fissando la larghezza, ogni cella
    /// occupa una riga propria e solo l'altezza varia: impilamento verticale, ordine sequenziale.
    private var widthConstraint: NSLayoutConstraint!

    override init(frame: CGRect) {
        super.init(frame: frame)

        widthConstraint = contentView.widthAnchor.constraint(equalToConstant: UIScreen.main.bounds.width)
        widthConstraint.priority = .required - 1  // evita conflitti coi vincoli transitori del self-sizing
        widthConstraint.isActive = true

        pageMarker.translatesAutoresizingMaskIntoConstraints = false
        textLabel.numberOfLines = 0
        textLabel.lineBreakMode = .byWordWrapping
        // Dimensione pilotata esplicitamente dalla leva (via `sizingTraits` in `configure`), non
        // dall'auto-adeguamento di UIKit: garantisce misurato == reso (vedi PageMarkerView).
        textLabel.adjustsFontForContentSizeCategory = false
        textLabel.textColor = .label
        textLabel.isAccessibilityElement = false
        textLabel.translatesAutoresizingMaskIntoConstraints = false

        stack.axis = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(pageMarker)
        stack.addArrangedSubview(textLabel)
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
        ])

        // La cella È l'elemento accessibile foglia: le sotto-viste (testo, marcatore) non sono esposte.
        isAccessibilityElement = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    /// (Ri)applica TUTTA la resa per il segmento dato. Chiamata a ogni `cellForItemAt` (riuso).
    func configure(
        segment: ContentSegment,
        index: Int,
        host: ContinuousReadingView,
        underlineIntervals: [ClosedRange<Int>]?,
        pageStart: Bool,
        pageNumber: Int?,
        width: CGFloat,
        sizingTraits: UITraitCollection
    ) {
        self.segment = segment
        self.readingIndex = index
        self.host = host
        if width > 0 { widthConstraint.constant = width }

        // Font alla dimensione EFFETTIVA (leva + Dynamic Type di sistema), IDENTICO a quello con cui la
        // reading view misura l'altezza (`measuredHeight`): è ciò che tiene misurato == reso.
        textLabel.font = UIFont.preferredFont(
            forTextStyle: ContinuousReadingView.textStyle(for: segment.role), compatibleWith: sizingTraits)
        // Resa visiva: underline additivo (rete A: il parlato NON cambia), altrimenti testo puro.
        if let intervals = underlineIntervals, !intervals.isEmpty {
            textLabel.attributedText = ContinuousReadingView.underlinedAttributedString(
                for: segment, intervals: intervals, sizingTraits: sizingTraits)
        } else {
            textLabel.attributedText = nil
            textLabel.text = segment.text
        }

        // Resa accessibile: etichetta mai vuota, parlato byte-identico al modello storico.
        accessibilityLabel = ContinuousReadingView.intendedAccessibilityLabel(for: segment)
        // NIENTE tratto `.header` sulle celle-titolo. Se le celle lo esponessero, il rotore
        // Intestazioni INCORPORATO di VoiceOver le scandirebbe — ma vede solo la finestra, quindi
        // salterebbe in modo capriccioso i titoli fuori finestra (osservato al collaudo). Tolto
        // `.header`, il rotore incorporato non ha nulla da scandire e la navigazione titoli passa
        // interamente ai rotori su misura (`.heading`/`.headingLevelN`), che vedono TUTTI i titoli
        // dal `headingIndex`. La qualifica di intestazione è reintrodotta nel parlato (vedi
        // `headingQualifier`), così non si perde il segnale acustico "è un titolo, di livello N".
        accessibilityTraits = .staticText

        // Stacco di pagina originale (Opzione A): visivo, muto per VoiceOver. Scala con la leva.
        pageMarker.isHidden = !pageStart
        pageMarker.setPageNumber(pageStart ? pageNumber : nil)
        pageMarker.applyTextSizeTraits(sizingTraits)
    }

    /// Azioni-segnalibro costruite PIGRAMENTE dall'host solo per la cella a fuoco (§ 5.1): nessun peso
    /// per-elemento. `nil` (nessun host/coordinatore) → nessuna azione, comportamento storico invariato.
    override var accessibilityCustomActions: [UIAccessibilityCustomAction]? {
        get {
            guard let segment else { return nil }
            return host?.bookmarkActions(forSegment: segment, orderIndex: readingIndex)
        }
        set { /* sola lettura: derivano dallo stato dei segnalibri */ }
    }

    /// Hook standard di VoiceOver: NON ridefinisce gesti (§ 2.4), registra il fuoco e fa scattare gli
    /// earcon (nota / ingresso bibliografia) e l'aggiornamento della posizione di lettura.
    override func accessibilityElementDidBecomeFocused() {
        guard let segment else { return }
        host?.cellDidBecomeFocused(index: readingIndex, segment: segment)
    }
}

/// La reading view del Layout "Lettura Continua": scroll verticale nativo riciclante, contenitore di
/// accessibilità unico e continuo su tutto il documento (le celle sono i suoi elementi, finestrati).
final class ContinuousReadingView: UIView {

    // MARK: - Sottoviste

    /// Il contenitore nativo che ricicla: scroll VERTICALE, celle auto-dimensionanti. È l'unico
    /// container di accessibilità del testo; VoiceOver ne attraversa le celle visibili (finestra).
    private let collectionView: UICollectionView

    // MARK: - Stato

    /// I segmenti correnti (ordine di lettura). Modello leggero: ~1 KB/segmento, tenuto tutto; solo
    /// la RESA (celle/accessibilità) è finestrata.
    private var segments: [ContentSegment] = []

    /// Mappa id-segmento → indice, per il salto a segnalibro e la risoluzione d'ancora (O(1)).
    private var idToIndex: [String: Int] = [:]

    /// Indici (in `segments`) che aprono una nuova PAGINA del file originale — gli stacchi visivi e la
    /// nozione di "pagina" nel verticale (Opzione A). Ricostruita a ogni render dalla `pageProvider`.
    private(set) var pageStartElementIndices: [Int] = []

    /// Indice LEGGERO delle intestazioni (indice-di-lettura + livello), in ordine, costruito dal modello
    /// dei segmenti a ogni render. È il dato che il rotore Intestazioni consulta per saltare a titoli
    /// anche FUORI dalla finestra: i titoli non materializzati non sono elementi di accessibilità vivi
    /// (nessun muro di memoria), ma i loro indice+livello vivono qui e il rotore li raggiunge scorrendo
    /// e materializzando la sola cella bersaglio (meccanismo validato in Fase 0).
    private(set) var headingIndex: [(index: Int, level: Int)] = []

    /// Indice dell'ultimo elemento messo a fuoco (o preimpostato), o `nil`. La posizione di lettura.
    private var lastFocusedIndex: Int?

    /// Ruolo dell'ultimo segmento a fuoco, per l'earcon di blocco bibliografico (una volta all'ingresso).
    private var lastFocusedRole: String?

    /// Token dell'osservatore di cambio Dynamic Type (rimosso in deinit).
    private var contentSizeObserver: NSObjectProtocol?

    /// Il NOSTRO recognizer di long press (§ 5.7): tenuto a parte perché la `UICollectionView` ne
    /// installa uno proprio, e i test devono ispezionare il nostro, non quello del sistema.
    private var longPressRecognizer: UILongPressGestureRecognizer?

    // MARK: - Cache delle altezze (rifinitura perf)
    //
    // Un'altezza MISURATA per elemento, servita da `sizeForItemAt`, così l'offset di scroll è ESATTO
    // su decine di migliaia di elementi. Dati LEGGERI — un `CGFloat` per elemento (~pochi byte),
    // NON elementi di accessibilità vivi: la memoria non risale. `-1` = non ancora misurato (misura
    // pigra al primo bisogno, poi in cache). L'etichetta di misura è una UILabel riusata configurata
    // come quella della cella, così l'altezza combacia con la resa reale (niente clip né salti).
    private var heightCache: [CGFloat] = []
    private let sizingLabel = UILabel()
    private var cachedMarkerHeight: CGFloat = 0
    private var lastMeasuredWidth: CGFloat = 0

    // MARK: - Leva "dimensione del testo" (Fase 0 accessibilità visiva)
    //
    // Una sola leva applicabile DAL VIVO: la dimensione del testo del DOCUMENTO (solo il corpo reso —
    // la chrome dell'interfaccia resta sul Dynamic Type di sistema). È un OFFSET in passi sulla scala
    // delle categorie Dynamic Type a partire dalla dimensione di sistema, così si INTEGRA con la
    // scelta dell'utente invece di combatterla (HIG Apple: Dynamic Type). La dimensione effettiva è
    // calcolata `compatibleWith` una `UITraitCollection` esplicita, IDENTICA nella misura (label di
    // misura) e nella resa (cella): è ciò che tiene l'altezza in cache combaciante con la resa reale
    // (nessun clip/gap). Il cambio di dimensione — e il cambio di Dynamic Type di sistema — passano
    // per lo STESSO percorso del cambio-larghezza (reset cache + invalidate) con ripristino posizione.

    /// La scala ordinata delle categorie Dynamic Type, dalla più piccola standard di Apple alla massima
    /// di accessibilità (AX5). Il minimo `.extraSmall` tiene il corpo ~14pt (sopra il minimo iOS di
    /// 11pt, HIG Apple); il massimo AX5 supera ampiamente il 200% richiesto da WCAG 2.2 SC 1.4.4.
    private static let categoryLadder: [UIContentSizeCategory] = [
        .extraSmall, .small, .medium, .large, .extraLarge, .extraExtraLarge, .extraExtraExtraLarge,
        .accessibilityMedium, .accessibilityLarge, .accessibilityExtraLarge,
        .accessibilityExtraExtraLarge, .accessibilityExtraExtraExtraLarge,
    ]

    /// La dimensione di sistema corrente (Dynamic Type): la base da cui la leva scosta. Aggiornata
    /// all'init e a ogni notifica di cambio Dynamic Type.
    private var systemBaselineCategory: UIContentSizeCategory = .large

    /// Offset della leva in passi sul ladder (0 = come il sistema; >0 più grande; <0 più piccolo).
    private var textSizeOffsetSteps = 0

    private func ladderIndex(of category: UIContentSizeCategory) -> Int {
        Self.categoryLadder.firstIndex(of: category) ?? 3  // 3 = .large
    }

    /// L'indice sul ladder della dimensione di sistema risolta (mai `.unspecified`).
    private var resolvedBaselineIndex: Int {
        ladderIndex(of: systemBaselineCategory == .unspecified ? .large : systemBaselineCategory)
    }

    /// L'indice EFFETTIVO = base di sistema + offset leva, clampato agli estremi del ladder.
    private var effectiveCategoryIndex: Int {
        min(max(0, resolvedBaselineIndex + textSizeOffsetSteps), Self.categoryLadder.count - 1)
    }

    /// La categoria di dimensione testo EFFETTIVA (sistema + leva).
    private var effectiveContentSizeCategory: UIContentSizeCategory {
        Self.categoryLadder[effectiveCategoryIndex]
    }

    /// La `UITraitCollection` esplicita con cui si calcolano i font in MISURA e in RESA (identica nei
    /// due → misurato == reso).
    private var textSizeTraitCollection: UITraitCollection {
        UITraitCollection(preferredContentSizeCategory: effectiveContentSizeCategory)
    }

    // MARK: - Callback e collaboratori (impostati dal view controller)

    /// Azione di escape (scrub a due dita, § 2.3/§ 2.4): passa al container dell'interfaccia.
    var onEscape: (() -> Void)?

    /// Notifica del cambio di posizione di lettura (§ 2.5): indice 0-based dell'elemento a fuoco.
    var onReadingPositionChanged: ((Int) -> Void)?

    /// Notifica che l'impaginazione (qui: gli stacchi di pagina) è stata ricalcolata.
    var onPaginationChanged: (() -> Void)?

    /// Paging GUIDATO DALL'UTENTE (scroll manuale): indice del primo elemento visibile raggiunto.
    var onUserScroll: ((Int) -> Void)?

    /// Fornitore della pagina del file originale per id-segmento (= `sourcePage` del controller). Guida
    /// gli stacchi visivi di pagina (Opzione A). `nil` → nessuno stacco (test / documenti senza pagine).
    var pageProvider: ((String) -> Int?)?

    /// Player dei segnali acustici (seam per i test). Earcon-nota e earcon-bibliografia al fuoco.
    var signalPlayer: SignalPlaying = SignalPlayer.shared

    /// Il coordinatore degli strumenti (§ 5 / § 6). `nil` → nessuna azione (test). `weak`.
    weak var elementCoordinator: ReadingElementCoordinator?

    // MARK: - Init

    override init(frame: CGRect) {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        // NIENTE `estimatedItemSize`/self-sizing a runtime: l'altezza di ogni cella è MISURATA una
        // volta e servita da `sizeForItemAt` (cache delle altezze). Così l'offset di scroll è esatto
        // su decine di migliaia di elementi — il salto lontano atterra pronto e il primo scroll è
        // fluido — senza auto-dimensionare cella per cella mentre si scorre (che causava tentennamento
        // sul salto lungo e scatti al primo scroll dei giganti).
        collectionView = UICollectionView(frame: frame, collectionViewLayout: layout)
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

        // Base della leva dimensione = dimensione di sistema corrente (Dynamic Type). L'offset parte a 0
        // (nessuno scostamento) finché l'utente non muove la leva o il documento applica quello salvato.
        systemBaselineCategory = UIApplication.shared.preferredContentSizeCategory

        // Etichetta di misura riusata, configurata come la `textLabel` della cella. Dimensione pilotata
        // esplicitamente (font impostato a ogni misura con `compatibleWith`), non auto-adeguata.
        sizingLabel.numberOfLines = 0
        sizingLabel.lineBreakMode = .byWordWrapping
        sizingLabel.adjustsFontForContentSizeCategory = false

        collectionView.backgroundColor = .systemBackground
        // §2.2 (swipe orizzontale mai ostacolato): l'indicatore di scorrimento verticale è una barra
        // laterale puramente visiva che, dopo una cella molto alta (note lunghe dei testi normativi),
        // VoiceOver aggancia come elemento ADJUSTABLE, intrappolando lo swipe (il gesto diventa
        // micro-scorrimento invece di avanzamento elemento-per-elemento). Disattivarlo lo toglie
        // dall'albero di accessibilità senza costo: non ha valore per VoiceOver. Emerso al gate AKN.
        collectionView.showsVerticalScrollIndicator = false
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.contentInsetAdjustmentBehavior = .always
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(SegmentCell.self, forCellWithReuseIdentifier: SegmentCell.reuseId)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        // Long press (§ 5.7, accesso non-VoiceOver): individua la cella sotto il dito. Fermo 0.5s;
        // ogni swipe lo fa fallire e lo scroll vince. Nessun ritardo su tap/swipe.
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.5
        longPress.delaysTouchesBegan = false
        longPress.delaysTouchesEnded = false
        collectionView.addGestureRecognizer(longPress)
        longPressRecognizer = longPress

        // Cambio di Dynamic Type di SISTEMA → aggiorna la base della leva e RI-MISURA COMPLETAMENTE
        // conservando la posizione (Fase 0: sanamento dell'incoerenza latente). Prima qui si faceva
        // SOLO `reconfigureVisibleCells()`, che riconfigurava le celle visibili col nuovo font ma NON
        // azzerava la cache delle altezze: le altezze fuori schermo restavano quelle vecchie → clip/gap
        // al ritorno. Ora si riusa lo stesso percorso del cambio-larghezza (reset cache + invalidate).
        contentSizeObserver = NotificationCenter.default.addObserver(
            forName: UIContentSizeCategory.didChangeNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let self else { return }
            let newCategory = (note.userInfo?[UIContentSizeCategory.newValueUserInfoKey]
                as? UIContentSizeCategory) ?? UIApplication.shared.preferredContentSizeCategory
            self.systemBaselineCategory = newCategory
            self.remeasurePreservingPosition()
        }
    }

    // MARK: - Escape (§ 2.3/§ 2.4)

    override func accessibilityPerformEscape() -> Bool {
        guard let onEscape else { return false }
        onEscape()
        return true
    }

    // MARK: - Rendering (API pubblica della view)

    /// Renderizza un layout di ScaboCore (le pagine logiche di `PaginatedContent` sono chunk
    /// geometry-agnostic: si appiattiscono; la vera nozione di pagina qui è quella del file originale).
    func render(_ content: PaginatedContent) {
        render(content.pages.flatMap { $0.segments })
    }

    /// Renderizza una sequenza piatta di segmenti in ordine di lettura.
    func render(_ segments: [ContentSegment]) {
        self.segments = segments
        idToIndex = [:]
        for (i, s) in segments.enumerated() where idToIndex[s.id] == nil { idToIndex[s.id] = i }
        lastFocusedIndex = nil
        lastFocusedRole = nil
        recomputePageStarts()
        rebuildHeadingIndexAndRotors()
        resetHeightCache()  // nuovo contenuto → nuove altezze da misurare
        collectionView.reloadData()
        onPaginationChanged?()
    }

    /// Ricostruisce gli indici di inizio-pagina-originale dalla `pageProvider` (Opzione A).
    private func recomputePageStarts() {
        guard let pageProvider, !segments.isEmpty else {
            pageStartElementIndices = segments.isEmpty ? [] : [0]
            return
        }
        var starts: [Int] = []
        var prev: Int? = nil
        for (i, s) in segments.enumerated() {
            let page = pageProvider(s.id)
            if i == 0 || page != prev { starts.append(i) }
            prev = page
        }
        pageStartElementIndices = starts.isEmpty ? [0] : starts
    }

    // MARK: - Posizione di lettura / fuoco

    /// L'indice dell'ultimo elemento messo a fuoco (o preimpostato), o `nil`.
    var currentReadingElementIndex: Int? { lastFocusedIndex }

    /// L'elemento accessibile di indice dato, SE la sua cella è materializzata (visibile), altrimenti
    /// `nil`. Per il ripristino del fuoco si usa `goToElement`, che prima scrolla e materializza.
    func element(atIndex index: Int) -> NSObject? {
        guard index >= 0, index < segments.count else { return nil }
        return collectionView.cellForItem(at: IndexPath(item: index, section: 0))
    }

    /// L'ultima cella di testo messa a fuoco, se ancora materializzata. Nel modello riciclante il
    /// ripristino del fuoco passa da `goToElement(atIndex:)` (per indice), non da questo riferimento.
    var lastFocusedTextElement: NSObject? {
        guard let i = lastFocusedIndex else { return nil }
        return collectionView.cellForItem(at: IndexPath(item: i, section: 0))
    }

    /// L'id del segmento di indice dato (per mappare la posizione alla pagina del file originale).
    func segmentId(atIndex index: Int) -> String? {
        guard index >= 0, index < segments.count else { return nil }
        return segments[index].id
    }

    /// Preimposta la posizione di lettura SENZA spostare il fuoco (registra l'indice).
    func presetReadingPosition(toIndex index: Int) {
        guard index > 0, index < segments.count else { return }
        lastFocusedIndex = index
    }

    /// Chiamata dalla cella al fuoco: aggiorna la posizione e fa scattare gli earcon (§ 10.4/§ 10.5).
    func cellDidBecomeFocused(index: Int, segment: ContentSegment) {
        lastFocusedIndex = index
        onReadingPositionChanged?(index)
        if let noteSignal = Self.noteSignal(for: segment) {
            signalPlayer.play(noteSignal)
        }
        // Earcon di blocco bibliografico: una volta all'INGRESSO del blocco LETTERATURA.
        if segment.role == SemanticCategory.LETTERATURA.rawValue, lastFocusedRole != segment.role {
            signalPlayer.play(.bibliography)
        }
        lastFocusedRole = segment.role
    }

    /// Porta in vista (scroll VISIVO) l'elemento SENZA spostare il fuoco: sincronizzazione del follower
    /// nello split (§ 11.4). Ricorda anche la posizione.
    func revealElement(atIndex index: Int) {
        guard index >= 0, index < segments.count else { return }
        collectionView.scrollToItem(at: IndexPath(item: index, section: 0), at: .top, animated: false)
        presetReadingPosition(toIndex: index)
    }

    /// Porta la reading view all'elemento `index` col meccanismo SANO: SCROLL visivo (onora la
    /// posizione anche a VoiceOver spento) e, se `focus` e VoiceOver è attivo, vi posta il fuoco su una
    /// cella CONCRETA (materializzata dallo scroll). È il pattern validato nel prototipo Fase 0.
    func goToElement(atIndex index: Int, focus: Bool) {
        guard index >= 0, index < segments.count else { return }
        let ip = IndexPath(item: index, section: 0)
        collectionView.scrollToItem(at: ip, at: .top, animated: false)
        collectionView.layoutIfNeeded()
        presetReadingPosition(toIndex: index)
        if focus, UIAccessibility.isVoiceOverRunning {
            let target: Any = collectionView.cellForItem(at: ip) ?? self
            UIAccessibility.post(notification: .screenChanged, argument: target)
        }
    }

    /// Risolve l'ancora di un segnalibro (§ 5.6): id esatto, poi id-nodo base (senza `#k`), infine il
    /// fallback clampato (§ 2.5).
    func indexOfSegment(anchorId: String, hint: Int) -> Int {
        if let i = idToIndex[anchorId] { return i }
        let base = Self.baseNodeId(anchorId)
        if let i = segments.firstIndex(where: { Self.baseNodeId($0.id) == base }) { return i }
        return min(max(0, hint), max(0, segments.count - 1))
    }

    /// L'id-nodo base di un id-segmento (toglie il suffisso di granularità `#k`).
    static func baseNodeId(_ segmentId: String) -> String {
        segmentId.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
            .first.map(String.init) ?? segmentId
    }

    // MARK: - Azioni sull'elemento (§ 5 / § 6)

    /// Costruisce le azioni-segnalibro VoiceOver per il segmento a fuoco (§ 5.1).
    func bookmarkActions(forSegment segment: ContentSegment, orderIndex: Int) -> [UIAccessibilityCustomAction]? {
        guard let coordinator = elementCoordinator else { return nil }
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
                    segmentId: segment.id, orderIndex: orderIndex, segmentText: segment.text)
                return true
            },
        ]
    }

    /// Apre il menù d'azione dei vedenti (§ 5 + § 6) per il segmento all'indice dato: instrada al
    /// coordinatore, che costruisce le voci di segnalibro e sottolineatura secondo lo stato.
    func openElementMenu(forSegmentAt index: Int, sourcePoint: CGPoint) {
        guard index >= 0, index < segments.count else { return }
        let segment = segments[index]
        elementCoordinator?.presentElementMenu(
            segmentId: segment.id, orderIndex: index,
            segmentText: segment.text, sourcePoint: sourcePoint)
    }

    /// Long press (accesso non-VoiceOver): individua la cella sotto il dito e apre il menù d'azione.
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        guard !UIAccessibility.isVoiceOverRunning else { return }
        guard elementCoordinator != nil else { return }
        let point = gesture.location(in: collectionView)
        guard let ip = collectionView.indexPathForItem(at: point) else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        openElementMenu(forSegmentAt: ip.item, sourcePoint: gesture.location(in: self))
    }

    // MARK: - Navigazione per lo split (§ 11.4 / § 11.5)

    /// Numero di elementi (segmenti) resi.
    var elementCount: Int { segments.count }

    /// I segmenti CORRENTEMENTE resi, in ordine (per la finestra di selezione underline § 6.2).
    var currentSegments: [ContentSegment] { segments }

    /// Numero di segmenti resi (per i test, sostituisce l'introspezione su `segmentLabels`).
    var renderedSegmentCount: Int { segments.count }

    /// Il primo elemento (indice) della "pagina" indicata (nel verticale = pagina del file originale).
    func firstElementIndex(ofVisualPage page: Int) -> Int? {
        guard page >= 0, page < pageStartElementIndices.count else { return nil }
        return pageStartElementIndices[page]
    }

    /// L'unità strutturale (0-based) dell'elemento: il numero di intestazioni fino a quell'elemento.
    func structuralUnitIndex(ofElementAt index: Int) -> Int {
        guard index >= 0, index < segments.count else { return 0 }
        var unit = 0
        for i in 0...index where Self.isHeadingRole(segments[i].role) { unit += 1 }
        return max(0, unit)
    }

    /// Numero totale di unità strutturali (intestazioni), minimo 1.
    var structuralUnitCount: Int {
        let headings = segments.reduce(0) { $0 + (Self.isHeadingRole($1.role) ? 1 : 0) }
        return max(1, headings)
    }

    /// Il primo elemento (indice) dell'unità strutturale indicata (l'intestazione che la apre).
    func firstElementIndex(ofUnit unit: Int) -> Int? {
        guard !segments.isEmpty else { return nil }
        if unit <= 0 { return 0 }
        var seen = 0
        for (i, s) in segments.enumerated() where Self.isHeadingRole(s.role) {
            seen += 1
            if seen == unit { return i }
        }
        return segments.count - 1
    }

    // MARK: - Navigazione per intestazioni (rotore Intestazioni + per livello, § 2.4 — meccanica NATIVA)
    //
    // Si replica il comportamento nativo di VoiceOver esponendo i tipi di rotore DI SISTEMA `.heading`
    // (tutte le intestazioni, in sequenza) e `.headingLevelN` (salto tra intestazioni dello STESSO
    // livello). Entrambi poggiano sulla STESSA informazione — il livello di ciascun titolo — letto dal
    // ruolo già prodotto dalla classificazione (non ridefinito qui). L'`itemSearchBlock` calcola il
    // bersaglio dal `headingIndex` (che copre ANCHE i titoli fuori finestra), poi scorre e materializza
    // la sola cella bersaglio (Fase 0): nessun titolo fuori finestra è un elemento di accessibilità vivo.

    /// Livello (1…6) del ruolo se è un'intestazione navigabile dal rotore, o `nil`. Deriva dal ruolo
    /// prodotto dalla classificazione: HEADING_1…4 → 1…4; ARTICLE_HEADER (l'articolo dei codici, sotto
    /// le quattro divisioni LIBRO/TITOLO/CAPO/SEZIONE) → 5. `SECTION_DIVIDER` (contenitore editoriale
    /// sintetico del backend XML AKN) è deliberatamente ESCLUSO dal rotore, coerente con l'intento
    /// dichiarato in `RoleStyle` ("keeps them out of any future Headings rotor").
    static func headingLevel(for role: String) -> Int? {
        switch role {
        case "HEADING_1": return 1
        case "HEADING_2": return 2
        case "HEADING_3": return 3
        case "HEADING_4": return 4
        case "ARTICLE_HEADER": return 5
        default: return nil
        }
    }

    private static func systemRotorType(forLevel level: Int?) -> UIAccessibilityCustomRotor.SystemRotorType {
        switch level {
        case 1: return .headingLevel1
        case 2: return .headingLevel2
        case 3: return .headingLevel3
        case 4: return .headingLevel4
        case 5: return .headingLevel5
        case 6: return .headingLevel6
        default: return .heading  // nil = rotore Intestazioni (tutti i livelli, in sequenza)
        }
    }

    /// I livelli di intestazione presenti nel documento, in ordine (per esporre un rotore per-livello
    /// solo per i livelli che esistono davvero).
    var headingLevelsPresent: [Int] { Array(Set(headingIndex.map { $0.level })).sorted() }

    /// Ricostruisce l'indice leggero delle intestazioni e (re)installa i rotori di sistema. Chiamata a
    /// ogni render. Il rotore Intestazioni (`.heading`) c'è sempre; i rotori per-livello solo per i
    /// livelli presenti.
    private func rebuildHeadingIndexAndRotors() {
        headingIndex = segments.enumerated().compactMap { i, s in
            Self.headingLevel(for: s.role).map { (index: i, level: $0) }
        }
        var rotors = [headingRotor(level: nil)]  // .heading — tutte le intestazioni, in sequenza
        for level in headingLevelsPresent {
            rotors.append(headingRotor(level: level))  // .headingLevelN — stesso livello
        }
        collectionView.accessibilityCustomRotors = rotors
    }

    private func headingRotor(level: Int?) -> UIAccessibilityCustomRotor {
        UIAccessibilityCustomRotor(systemType: Self.systemRotorType(forLevel: level)) { [weak self] predicate in
            self?.headingSearch(predicate, level: level)
        }
    }

    /// Cuore della navigazione: dato l'elemento a fuoco e la direzione (su/giù del rotore), trova il
    /// titolo successivo/precedente (filtrato per livello se il rotore è per-livello) LEGGENDO il
    /// `headingIndex` — quindi anche titoli lontanissimi fuori finestra — poi scorre e materializza la
    /// cella bersaglio e la restituisce a VoiceOver. Da lì lo swipe elemento-per-elemento prosegue
    /// continuo (la finestra si è ricostruita attorno all'atterraggio).
    private func headingSearch(
        _ predicate: UIAccessibilityCustomRotorSearchPredicate, level: Int?
    ) -> UIAccessibilityCustomRotorItemResult? {
        guard !headingIndex.isEmpty else { return nil }

        // Indice corrente: la cella a fuoco se è nota, altrimenti l'ultima posizione ricordata, altrimenti
        // il primo elemento visibile (o -1 → il primo titolo è "successivo").
        let current: Int
        if let cell = predicate.currentItem.targetElement as? SegmentCell {
            current = cell.readingIndex
        } else if let idx = lastFocusedIndex {
            current = idx
        } else {
            current = (collectionView.indexPathsForVisibleItems.map(\.item).min() ?? 0) - 1
        }

        let forward = predicate.searchDirection == .next
        guard let t = nextHeadingIndex(from: current, level: level, forward: forward) else {
            return nil  // oltre l'ultimo / prima del primo titolo → fine
        }

        let ip = IndexPath(item: t, section: 0)
        collectionView.scrollToItem(at: ip, at: .top, animated: false)
        collectionView.layoutIfNeeded()
        presetReadingPosition(toIndex: t)  // ricorda la posizione: lo swipe da qui è continuo
        // Nota: su un salto LONTANO con celle auto-dimensionanti l'offset è stimato e la cella può non
        // essere ancora materializzata (piccolo stagger + eventuale suono di "fine" al primo swipe).
        // È il residuo della rifinitura perf "primo scroll sui giganti" (stima/cache delle altezze),
        // fase successiva dedicata: qui non lo si forza per non aggiungere latenza senza risolverlo.
        guard let cell = collectionView.cellForItem(at: ip) else { return nil }
        return UIAccessibilityCustomRotorItemResult(targetElement: cell, targetRange: nil)
    }

    /// Indice-di-lettura del titolo successivo (`forward`) o precedente rispetto a `current`, filtrato
    /// per `level` (nil = qualsiasi livello). Puro e testabile: è la logica di sequenza del rotore, che
    /// legge il `headingIndex` (titoli anche fuori finestra) senza toccare celle o VoiceOver.
    func nextHeadingIndex(from current: Int, level: Int?, forward: Bool) -> Int? {
        let candidates = level == nil ? headingIndex : headingIndex.filter { $0.level == level }
        return forward
            ? candidates.first(where: { $0.index > current })?.index
            : candidates.last(where: { $0.index < current })?.index
    }

    // MARK: - Sottolineature (§ 6) — resa additiva, solo-visiva, RIAPPLICATA al riuso

    /// Mappa id-segmento → intervalli di parole (inclusivi) da sottolineare. Costruita dal view
    /// controller; qui è consumata a ogni configurazione di cella (riuso-sicuro).
    private var underlineRangesBySegmentId: [String: [ClosedRange<Int>]] = [:]

    /// Colore/spessore della sottolineatura (regime UI).
    private static let underlineStyle = NSUnderlineStyle.thick

    /// Imposta gli intervalli e riconfigura le celle visibili (le altre riprenderanno la resa al riuso).
    func setUnderlineRanges(_ map: [String: [ClosedRange<Int>]]) {
        underlineRangesBySegmentId = map
        reconfigureVisibleCells()
    }

    /// Riconfigura le celle attualmente visibili senza ricrearle (riapplica underline / stacchi / font).
    private func reconfigureVisibleCells() {
        let visible = collectionView.indexPathsForVisibleItems
        guard !visible.isEmpty else { return }
        collectionView.reconfigureItems(at: visible)
    }

    /// Costruisce l'`attributedText` di un segmento con l'attributo `.underlineStyle` sugli intervalli
    /// di parole indicati. L'underline è un ATTRIBUTO del testo (§ 6.5): resta sotto i glifi esatti a
    /// qualunque corpo carattere e a-capo, senza calcoli geometrici.
    static func underlinedAttributedString(
        for segment: ContentSegment, intervals: [ClosedRange<Int>],
        sizingTraits: UITraitCollection = UITraitCollection(preferredContentSizeCategory: .large)
    ) -> NSAttributedString {
        let text = segment.text
        let font = UIFont.preferredFont(forTextStyle: textStyle(for: segment.role), compatibleWith: sizingTraits)
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

    // MARK: - Introspezione per i test

    /// Gli elementi accessibili ESPOSTI: nel modello finestrato sono le celle VISIBILI (in ordine di
    /// lettura), non tutto il documento. È il cuore del risparmio di memoria.
    var exposedAccessibilityElements: [NSObject] {
        collectionView.indexPathsForVisibleItems.sorted()
            .compactMap { collectionView.cellForItem(at: $0) }
    }

    /// Vero se la view del testo si espone come elemento foglia. DEVE essere falso: è un container
    /// (VoiceOver ne attraversa le celle, non la mette a fuoco come un unico blocco).
    var isDocumentContainerAnAccessibilityElement: Bool { isAccessibilityElement }

    /// Numero di "pagine" (nel verticale = pagine del file originale con almeno un segmento).
    var visualPageCount: Int { pageStartElementIndices.count }

    /// La "pagina" (originale) dell'elemento di indice dato, o `nil` se fuori range.
    func visualPageIndex(ofElementAt index: Int) -> Int? {
        guard index >= 0, index < segments.count, !pageStartElementIndices.isEmpty else { return nil }
        var page = 0
        for (p, start) in pageStartElementIndices.enumerated() where start <= index { page = p }
        return page
    }

    /// La "pagina" attualmente in vista (dal primo elemento visibile).
    var currentVisualPage: Int {
        let top = collectionView.indexPathsForVisibleItems.map(\.item).min() ?? 0
        return visualPageIndex(ofElementAt: top) ?? 0
    }

    /// Vero se il contenuto si estende oltre un viewport (scroll necessario).
    var contentSpansMultiplePages: Bool {
        collectionView.contentSize.height > collectionView.bounds.height + 0.5
    }

    /// Il NOSTRO recognizer di long press (§ 5.7), per i test (config swipe-safe). NON quello che la
    /// `UICollectionView` installa per conto suo.
    var longPressGestureForTesting: UILongPressGestureRecognizer? { longPressRecognizer }

    /// Indice dell'elemento in cima alla porzione visibile (proxy dello SCROLL per i test di
    /// ripristino posizione: 0 = inizio file, N = scrollato alla posizione). Richiede una finestra.
    var topVisibleElementIndexForTesting: Int? {
        collectionView.indexPathsForVisibleItems.map(\.item).min()
    }

    /// Costruisce e configura una cella per l'indice dato SENZA passare dal ciclo di riciclo: per i
    /// test unitari, che (senza finestra/VoiceOver) non materializzano celle. Riflette esattamente la
    /// resa di `cellForItemAt`.
    func makeConfiguredCellForTesting(at index: Int) -> SegmentCell? {
        guard index >= 0, index < segments.count else { return nil }
        let cell = SegmentCell(frame: .zero)
        configure(cell, at: index)
        return cell
    }

    // MARK: - Configurazione della cella (unico punto di verità di resa)

    private func configure(_ cell: SegmentCell, at index: Int) {
        let segment = segments[index]
        let intervals = underlineRangesBySegmentId[segment.id]
        let pageStart = isPageStart(index)
        let pageNumber = pageProvider?(segment.id)
        // Piena larghezza: la cella occupa tutta la riga (solo l'altezza varia). Fallback a UIScreen
        // finché il collection non ha bounds (es. cella costruita a mano nei test prima del layout).
        let width = collectionView.bounds.width > 0 ? collectionView.bounds.width : UIScreen.main.bounds.width
        cell.configure(
            segment: segment, index: index, host: self,
            underlineIntervals: intervals, pageStart: pageStart, pageNumber: pageNumber, width: width,
            sizingTraits: textSizeTraitCollection)
    }

    private func isPageStart(_ index: Int) -> Bool {
        guard pageProvider != nil else { return false }
        return pageStartElementIndices.contains(index)
    }

    // MARK: - Misura delle altezze (cache)

    /// Altezza (misurata, in cache) della cella dell'elemento `index`. Replica esattamente la resa
    /// della cella: inset verticali dello stack (8+8) + eventuale marcatore di pagina + altezza della
    /// label per il testo alla larghezza della colonna. Misura pigra e in cache; prima che la larghezza
    /// sia nota restituisce una stima innocua (ricalcolata al primo layout valido).
    private func measuredHeight(at index: Int) -> CGFloat {
        guard index >= 0, index < segments.count else { return 44 }
        if index < heightCache.count, heightCache[index] >= 0 { return heightCache[index] }
        let width = collectionView.bounds.width
        guard width > 0 else { return 44 }
        let labelWidth = max(1, width - 40)  // inset orizzontali dello stack: 20 + 20
        let segment = segments[index]
        sizingLabel.font = UIFont.preferredFont(
            forTextStyle: Self.textStyle(for: segment.role), compatibleWith: textSizeTraitCollection)
        sizingLabel.text = segment.text
        let labelH = ceil(sizingLabel.sizeThatFits(
            CGSize(width: labelWidth, height: .greatestFiniteMagnitude)).height)
        var markerH: CGFloat = 0
        if isPageStart(index) {
            if cachedMarkerHeight <= 0 { cachedMarkerHeight = computeMarkerHeight() }
            markerH = cachedMarkerHeight
        }
        let h = 16 + markerH + labelH  // stack top 8 + bottom 8
        if index < heightCache.count { heightCache[index] = h }
        return h
    }

    private func resetHeightCache() {
        heightCache = [CGFloat](repeating: -1, count: segments.count)
    }

    /// Altezza misurata dell'elemento (per i test: verifica che combaci con la resa reale della cella).
    func measuredHeightForTesting(at index: Int) -> CGFloat { measuredHeight(at: index) }

    /// Altezza (costante) del marcatore di pagina, misurata una volta per larghezza.
    private func computeMarkerHeight() -> CGFloat {
        let width = collectionView.bounds.width
        guard width > 0 else { return 0 }
        let marker = PageMarkerView(frame: .zero)
        marker.setPageNumber(1)
        marker.applyTextSizeTraits(textSizeTraitCollection)
        let size = marker.systemLayoutSizeFitting(
            CGSize(width: width - 40, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
        return ceil(size.height)
    }

    /// Al cambio di larghezza (rotazione, split) le altezze cambiano: azzera la cache e ricalcola.
    override func layoutSubviews() {
        super.layoutSubviews()
        let width = collectionView.bounds.width
        if width > 0, width != lastMeasuredWidth {
            lastMeasuredWidth = width
            cachedMarkerHeight = 0
            resetHeightCache()
            collectionView.collectionViewLayout.invalidateLayout()
        }
    }

    // MARK: - Leva "dimensione del testo": applicazione live + ripristino posizione (Fase 0)

    /// Imposta l'offset INIZIALE della dimensione del testo SENZA re-misura, per l'apertura (prima del
    /// primo `render`): la misura successiva userà già la categoria giusta, senza uno scatto d'avvio.
    func setInitialTextSizeOffset(_ steps: Int) {
        textSizeOffsetSteps = steps
    }

    /// L'offset corrente della leva (per la persistenza globale).
    var textSizeOffset: Int { textSizeOffsetSteps }

    /// Vero se c'è ancora margine per ingrandire / rimpicciolire (per abilitare i pulsanti ai limiti).
    var canIncreaseTextSize: Bool { effectiveCategoryIndex < Self.categoryLadder.count - 1 }
    var canDecreaseTextSize: Bool { effectiveCategoryIndex > 0 }

    /// Cambia la dimensione del testo DAL VIVO di `delta` passi sul ladder, riusando ESATTAMENTE il
    /// percorso del cambio-larghezza (reset cache + invalidate) e CONSERVANDO la posizione di lettura.
    /// Ritorna l'offset effettivo dopo il clamp (invariato — e nessuna re-misura — se già al limite).
    @discardableResult
    func changeTextSize(by delta: Int) -> Int {
        let newIndex = min(max(0, effectiveCategoryIndex + delta), Self.categoryLadder.count - 1)
        let newOffset = newIndex - resolvedBaselineIndex
        guard newOffset != textSizeOffsetSteps else { return textSizeOffsetSteps }  // già al limite
        textSizeOffsetSteps = newOffset
        remeasurePreservingPosition()
        return textSizeOffsetSteps
    }

    /// Ri-applica il layout dopo un cambio che altera le altezze (leva dimensione o Dynamic Type di
    /// sistema): stessa meccanica del cambio-larghezza — azzera cache-marcatore e cache-altezze,
    /// riconfigura le celle visibili col nuovo font, invalida il layout — poi RIPORTA la vista
    /// sull'elemento dov'era (posizione di lettura conservata: l'utente non è sbalzato altrove né a
    /// inizio file). L'offset di scroll è esatto perché le altezze sono MISURATE, non stimate.
    private func remeasurePreservingPosition() {
        let anchor = lastFocusedIndex
            ?? collectionView.indexPathsForVisibleItems.map(\.item).min()
            ?? 0
        cachedMarkerHeight = 0
        resetHeightCache()
        reconfigureVisibleCells()
        collectionView.collectionViewLayout.invalidateLayout()
        collectionView.layoutIfNeeded()
        guard anchor >= 0, anchor < segments.count else { return }
        let ip = IndexPath(item: anchor, section: 0)
        collectionView.scrollToItem(at: ip, at: .top, animated: false)
        collectionView.layoutIfNeeded()
        lastFocusedIndex = anchor
        // Rientro del fuoco VoiceOver sullo STESSO elemento: non è un cambio di schermo, quindi
        // `.layoutChanged` (riposiziona il fuoco senza semantica di nuova schermata), non `.screenChanged`.
        if UIAccessibility.isVoiceOverRunning {
            let target: Any = collectionView.cellForItem(at: ip) ?? collectionView
            UIAccessibility.post(notification: .layoutChanged, argument: target)
        }
    }

    /// Forza una dimensione effettiva nota (base data, offset azzerato) e ri-misura: per i test
    /// deterministici, indipendenti dalla dimensione di sistema dell'host.
    func setTextSizeCategoryForTesting(_ category: UIContentSizeCategory) {
        systemBaselineCategory = category
        textSizeOffsetSteps = 0
        remeasurePreservingPosition()
    }

    // MARK: - Mappature ruolo → stile / semantica (INVARIATE: unica fonte del parlato)

    /// Testo che VoiceOver pronuncia: intro acustica (se presente) + rinfresco di contesto + testo.
    static func spokenText(for segment: ContentSegment) -> String {
        spoken(intro: segment.acousticIntro, segment: segment)
    }

    /// L'etichetta accessibile INTESA per un segmento — l'unica fonte del parlato (byte-identica con o
    /// senza underline, rete A). Una nota vera col segnale acustico perde solo l'intro verbale (§ 10.4).
    static func intendedAccessibilityLabel(for segment: ContentSegment) -> String {
        let base = noteSignal(for: segment) == nil
            ? spokenText(for: segment)
            : spoken(intro: "", segment: segment)
        // Reintroduzione della qualifica di intestazione NEL PARLATO (rimedio approvato): tolto il
        // tratto `.header` dalle celle (perché il rotore Intestazioni incorporato non le scandisca),
        // l'orecchio in lettura lineare perderebbe il segnale "è un titolo". Lo restituiamo qui,
        // meglio ancora per livello, così il titolo suona qualificato senza reintrodurre `.header`.
        let qualifier = headingQualifier(for: segment.role)
        return qualifier.isEmpty ? base : "\(qualifier) \(base)"
    }

    /// Qualifica parlata anteposta a un titolo, per LIVELLO reale (letto dal ruolo prodotto dalla
    /// classificazione). `ARTICLE_HEADER` → "Articolo." (l'articolo dei codici); HEADING_1…4 →
    /// "Intestazione di livello N." Vuota per i non-titoli (e per `SECTION_DIVIDER`, che ha già il
    /// suo intro "Sezione." e resta fuori dal rotore). Sostituisce l'annuncio nativo "intestazione"
    /// perso con `.header`, differenziando i livelli come chiesto.
    static func headingQualifier(for role: String) -> String {
        switch role {
        case "ARTICLE_HEADER": return "Articolo."
        case "HEADING_1": return "Intestazione di livello 1."
        case "HEADING_2": return "Intestazione di livello 2."
        case "HEADING_3": return "Intestazione di livello 3."
        case "HEADING_4": return "Intestazione di livello 4."
        default: return ""
        }
    }

    /// Compone `[intro] [memoryRefresh] [text]`, scartando le parti vuote. Il testo è sempre presente.
    static func spoken(intro: String, segment: ContentSegment) -> String {
        [intro, segment.memoryRefresh, segment.text]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// Il segnale-nota per il segmento, o `nil` se non è una nota vera con regime.
    static func noteSignal(for segment: ContentSegment) -> AudioSignal? {
        guard segment.role == SemanticCategory.NOTE.rawValue,
              !segment.acousticIntro.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return nil }
        return AudioSignal.noteSignal(forLengthCategory: segment.lengthCategory)
    }

    /// Vero per i ruoli da trattare come intestazione (tratto `.header`).
    static func isHeadingRole(_ role: String) -> Bool {
        role.hasPrefix("HEADING_") || role == SECTION_DIVIDER_ROLE || role == "ARTICLE_HEADER"
    }

    /// Stile tipografico (Dynamic Type) per ruolo.
    static func textStyle(for role: String) -> UIFont.TextStyle {
        switch role {
        case "HEADING_1": return .title1
        case "HEADING_2": return .title2
        case "HEADING_3": return .title3
        case "HEADING_4": return .headline
        case "ARTICLE_HEADER": return .headline
        case SECTION_DIVIDER_ROLE: return .headline
        default: return .body
        }
    }
}

// MARK: - Data source / delegate

extension ContinuousReadingView: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    func collectionView(_ cv: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        segments.count
    }

    func collectionView(_ cv: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = cv.dequeueReusableCell(withReuseIdentifier: SegmentCell.reuseId, for: indexPath) as! SegmentCell
        configure(cell, at: indexPath.item)
        return cell
    }

    func collectionView(
        _ cv: UICollectionView, layout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        // Larghezza piena; altezza MISURATA e in cache (offset di scroll esatto → salto lontano pronto,
        // primo scroll fluido, senza auto-dimensionamento a runtime).
        CGSize(width: cv.bounds.width, height: measuredHeight(at: indexPath.item))
    }
}

extension ContinuousReadingView: UIScrollViewDelegate {
    /// Aggiorna la posizione reale SOLO su scroll guidato dall'utente (i reset programmatici non sono
    /// `isDragging` e non falsano la posizione tracciata).
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView.isDragging || scrollView.isDecelerating else { return }
        let top = collectionView.indexPathsForVisibleItems.map(\.item).min() ?? 0
        onUserScroll?(top)
    }
}
