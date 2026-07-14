//
//  ReadingInterfaceBar.swift
//  ScaboApp
//
//  Il SECONDO container di accessibilità della reading view (§ 2.3, § 3.1): la zona
//  dell'interfaccia, separata e CHIUSA rispetto al container del testo. In questa sessione ospita
//  due soli elementi — il titolo "Lettura Continua" e il tasto "Indietro" — ma è posata fin d'ora
//  come il container permanente dove in futuro vivrà la barra strumenti piena (selettore Layout,
//  indicatore di pagina, ecc.).
//
//  ── Container chiuso (il punto strutturale, inderogabile) ────────────────────────────────────
//
//  `isAccessibilityElement = false` (è un container, non una foglia) e `accessibilityElements` è
//  l'elenco ESPLICITO e ordinato dei soli elementi d'interfaccia: VoiceOver, dentro questo
//  container, attraversa esclusivamente [Indietro, titolo]. Mai un elemento di testo del
//  documento. Lo `accessibilityContainerType = .semanticGroup` dichiara la natura di gruppo.
//
//  Scenario blindato (§ 2.2/§ 2.3): il container ATTIVO è modale (lo decide il view controller),
//  così lo swipe non sconfina mai fra i container. Il passaggio DA/VERSO il container del testo
//  avviene SOLO col gesto di scrub a due dita: l'override `accessibilityPerformEscape` instrada
//  l'`onEscape` impostato dal view controller, che riattiva il container del testo riportando il
//  fuoco dove l'utente era. Nessun gesto VoiceOver è ridefinito (§ 2.4): si definisce solo la
//  risposta dell'elemento all'azione di escape. (Vedi la nota di testata del view controller per
//  perché la versione "aperta con tocco" non è realizzabile in modo affidabile senza modalità.)
//

import UIKit
import ScaboCore

final class ReadingInterfaceBar: UIView {

    /// Tasto "Indietro": torna alla Home nuda (azione impostata dal controller).
    let backButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Indietro", for: .normal)
        button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .body)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.translatesAutoresizingMaskIntoConstraints = false
        button.accessibilityLabel = "Indietro"
        button.accessibilityHint = "Chiude il documento e torna alla schermata iniziale"
        return button
    }()

    /// Selettore di Layout (§ 3.4) al centro della barra: mostra il layout corrente e, al doppio
    /// tap, apre il menù delle scelte (Lettura Continua / Dottrina Inline). Sostituisce il vecchio
    /// titolo statico (mostrava già il nome del layout). Vive in QUESTO container d'interfaccia,
    /// mai raggiungibile dallo swipe del testo (§ 2.2). È un `UIButton` con `UIMenu`: VoiceOver lo
    /// annuncia come pulsante a comparsa, ne legge il valore corrente, e la scelta è navigabile.
    let layoutSelectorButton: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.titleLabel?.lineBreakMode = .byTruncatingTail
        button.tintColor = .label
        button.translatesAutoresizingMaskIntoConstraints = false
        button.showsMenuAsPrimaryAction = true   // il doppio tap apre il menù, non un'azione separata
        return button
    }()

    /// Pulsante Segnalibri (§ 5.4): apre la finestra dei segnalibri del documento corrente. Vive in
    /// QUESTO container d'interfaccia (chiuso): mai raggiungibile dallo swipe di lettura (§ 2.2).
    let bookmarksButton: UIButton = {
        let b = UIButton(type: .system)
        b.setImage(UIImage(systemName: "bookmark"), for: .normal)
        b.accessibilityLabel = "Segnalibri"
        b.accessibilityHint = "Apre i segnalibri del documento e il filtro per tag"
        b.isHidden = true   // visibile solo quando il documento è reale (lo abilita il controller)
        return b
    }()

    /// Azione del pulsante Segnalibri (impostata dal controller).
    var onBookmarks: (() -> Void)?

    /// Pulsante Split screen (§ 11.1, attivazione da dentro un file): apre lo split con questo
    /// documento in una metà. Solo iPad, solo full-screen (mai in una metà già embedded).
    let splitButton: UIButton = {
        let b = UIButton(type: .system)
        b.setImage(UIImage(systemName: "rectangle.split.2x1"), for: .normal)
        b.accessibilityLabel = "Affianca"
        b.accessibilityHint = "Apre questo documento in split screen accanto a un altro"
        b.isHidden = true
        return b
    }()

    /// Azione del pulsante Split (impostata dal controller).
    var onSplit: (() -> Void)?

    // ── Dimensione del testo (Fase 0 accessibilità visiva) ────────────────────────────────────
    // Due pulsanti — rimpicciolisci / ingrandisci — che cambiano la dimensione del testo del
    // documento DAL VIVO. Vivono in QUESTO container d'interfaccia (chiuso): raggiungibili solo
    // scrubando alla barra, mai dallo swipe di lettura (§ 2.2).

    let decreaseTextSizeButton: UIButton = {
        let b = UIButton(type: .system)
        b.setImage(UIImage(systemName: "textformat.size.smaller"), for: .normal)
        b.accessibilityLabel = "Testo più piccolo"
        b.accessibilityHint = "Riduce la dimensione del testo del documento"
        b.isHidden = true
        return b
    }()
    let increaseTextSizeButton: UIButton = {
        let b = UIButton(type: .system)
        b.setImage(UIImage(systemName: "textformat.size.larger"), for: .normal)
        b.accessibilityLabel = "Testo più grande"
        b.accessibilityHint = "Aumenta la dimensione del testo del documento"
        b.isHidden = true
        return b
    }()

    /// Azioni dei pulsanti dimensione (impostate dal controller).
    var onDecreaseTextSize: (() -> Void)?
    var onIncreaseTextSize: (() -> Void)?

    private lazy var textSizeStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [decreaseTextSizeButton, increaseTextSizeButton])
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .center
        stack.isHidden = true
        return stack
    }()

    /// Mostra/nasconde i pulsanti dimensione del testo e ne imposta lo stato abilitato ai limiti.
    func setTextSizeControls(available: Bool, canDecrease: Bool = true, canIncrease: Bool = true) {
        textSizeStack.isHidden = !available
        decreaseTextSizeButton.isHidden = !available
        increaseTextSizeButton.isHidden = !available
        if available { setTextSizeButtonsEnabled(canDecrease: canDecrease, canIncrease: canIncrease) }
        refreshAccessibilityElements()
    }

    /// Aggiorna il solo stato abilitato dei pulsanti dimensione (ai limiti della scala).
    func setTextSizeButtonsEnabled(canDecrease: Bool, canIncrease: Bool) {
        decreaseTextSizeButton.isEnabled = canDecrease
        increaseTextSizeButton.isEnabled = canIncrease
        decreaseTextSizeButton.accessibilityTraits = canDecrease ? .button : [.button, .notEnabled]
        increaseTextSizeButton.accessibilityTraits = canIncrease ? .button : [.button, .notEnabled]
    }

    /// Mostra/nasconde il pulsante Segnalibri (§ 5.4). Il controller lo abilita solo per un
    /// documento reale (id non vuoto); nei test senza libreria resta nascosto e l'interfaccia è
    /// identica a prima.
    func setBookmarksAvailable(_ available: Bool) {
        bookmarksButton.isHidden = !available
        refreshAccessibilityElements()
    }

    /// Mostra/nasconde il pulsante Split (§ 11.1). Il controller lo abilita solo full-screen su iPad.
    func setSplitAvailable(_ available: Bool) {
        splitButton.isHidden = !available
        refreshAccessibilityElements()
    }

    /// Layout-id usato come fallback quando il selettore non è ancora configurato.
    private var currentLayout: LayoutId = .continuous
    /// Inoltrata dal controller: l'utente ha scelto un layout dal menù.
    private var onLayoutSelected: ((LayoutId) -> Void)?

    /// Indicatore di pagina (§ 4.3) come DUE BOX DISTINTI e separati. Quando ci sono entrambe le
    /// numerazioni (toggle pagine originali attivo) si mostrano due elementi accessibili a sé —
    /// `originalPageLabel` e `visualizationPageLabel` — letti SEPARATAMENTE da VoiceOver, ciascuno
    /// con la propria etichetta che chiarisce quale numerazione è (così con lo scrub l'utente
    /// distingue quale numero sta sentendo). In modalità singola resta il solo box della
    /// numerazione continua (di visualizzazione). Vivono in QUESTO container d'interfaccia (chiuso):
    /// mai raggiungibili dallo swipe orizzontale di lettura → nessuna interferenza col vincolo
    /// costitutivo (§ 2.2). L'utente li consulta scrubando alla barra.

    /// Box della pagina del FILE ORIGINALE (mostrato solo in modalità doppia).
    let originalPageLabel = ReadingInterfaceBar.makePageBox()

    /// Box della pagina di VISUALIZZAZIONE (numerazione continua, sempre presente con impaginazione).
    let visualizationPageLabel = ReadingInterfaceBar.makePageBox()

    /// Contenitore visivo dei due box, allineato a destra. La gestione della visibilità del singolo
    /// box passa per `isHidden` sui box (uno stack li impacchetta automaticamente).
    private lazy var pageIndicatorStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [originalPageLabel, visualizationPageLabel])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        return stack
    }()

    // ── Controlli specifici della Consultazione Rapida (§ 8.5): Reset struttura + frecce ──────
    // Compaiono SOLO quando il Layout attivo è Consultazione Rapida; in quel Layout l'indicatore
    // di pagina del bar è nascosto (la pagina sta nelle etichette dell'albero, § 8.4).

    /// "Reset struttura" (§ 8.5): comprime tutto l'albero, previo pop-up di conferma.
    let resetStructureButton: UIButton = {
        let b = UIButton(type: .system)
        b.setImage(UIImage(systemName: "arrow.up.left.and.arrow.down.right.circle"), for: .normal)
        b.accessibilityLabel = "Reset struttura"
        b.accessibilityHint = "Comprime tutte le tendine dell'albero. Chiede conferma."
        return b
    }()
    /// Freccia "precedente" (§ 8.5): va alla foglia espansa precedente.
    let prevExpandedButton: UIButton = {
        let b = UIButton(type: .system)
        b.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        b.accessibilityLabel = "Elemento espanso precedente"
        return b
    }()
    /// Freccia "successivo" (§ 8.5): va alla foglia espansa successiva.
    let nextExpandedButton: UIButton = {
        let b = UIButton(type: .system)
        b.setImage(UIImage(systemName: "chevron.right"), for: .normal)
        b.accessibilityLabel = "Elemento espanso successivo"
        return b
    }()

    private lazy var quickControlsStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [resetStructureButton, prevExpandedButton, nextExpandedButton])
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .center
        stack.isHidden = true   // visibile solo in Consultazione Rapida
        return stack
    }()

    /// Lo stack di destra impacchetta indicatore-pagina e controlli-quick: si mostra l'uno o gli
    /// altri secondo il Layout attivo (uno stack collassa gli arranged hidden).
    private lazy var rightStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [splitButton, bookmarksButton, textSizeStack, quickControlsStack, pageIndicatorStack])
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    /// Azioni dei controlli quick (impostate dal controller).
    var onResetStructure: (() -> Void)?
    var onPrevExpanded: (() -> Void)?
    var onNextExpanded: (() -> Void)?

    /// Costruisce un box-etichetta per l'indicatore: padding, sfondo tenue e angoli, così i due box
    /// si distinguono visivamente (bi-modale, § 2.1). È un elemento accessibile a sé.
    private static func makePageBox() -> InsetLabel {
        let label = InsetLabel()
        label.font = UIFont.preferredFont(forTextStyle: .footnote)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .label
        label.textAlignment = .center
        label.numberOfLines = 1
        label.backgroundColor = .tertiarySystemFill
        label.layer.cornerRadius = 6
        label.layer.masksToBounds = true
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.isAccessibilityElement = true
        label.isHidden = true
        return label
    }

    /// Azione del tasto Indietro (impostata dal controller).
    var onBack: (() -> Void)?

    /// Azione di escape (scrub a due dita): passa al container del testo.
    var onEscape: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) non supportato: ReadingInterfaceBar è costruita in codice.")
    }

    private func setUp() {
        backgroundColor = .secondarySystemBackground
        addSubview(backButton)
        addSubview(layoutSelectorButton)
        addSubview(rightStack)

        rightStack.setContentHuggingPriority(.required, for: .horizontal)
        rightStack.setContentCompressionResistancePriority(.required, for: .horizontal)

        NSLayoutConstraint.activate([
            backButton.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            backButton.centerYAnchor.constraint(equalTo: centerYAnchor),

            rightStack.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
            rightStack.centerYAnchor.constraint(equalTo: centerYAnchor),

            layoutSelectorButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            layoutSelectorButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            layoutSelectorButton.leadingAnchor.constraint(greaterThanOrEqualTo: backButton.trailingAnchor, constant: 8),
            layoutSelectorButton.trailingAnchor.constraint(lessThanOrEqualTo: rightStack.leadingAnchor, constant: -8),
        ])

        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        bookmarksButton.addTarget(self, action: #selector(bookmarksTapped), for: .touchUpInside)
        splitButton.addTarget(self, action: #selector(splitTapped), for: .touchUpInside)
        decreaseTextSizeButton.addTarget(self, action: #selector(decreaseTextSizeTapped), for: .touchUpInside)
        increaseTextSizeButton.addTarget(self, action: #selector(increaseTextSizeTapped), for: .touchUpInside)
        resetStructureButton.addTarget(self, action: #selector(resetTapped), for: .touchUpInside)
        prevExpandedButton.addTarget(self, action: #selector(prevTapped), for: .touchUpInside)
        nextExpandedButton.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)

        // Bersagli di tocco ≥ 44×44 pt (HIG Apple; WCAG 2.5.8 [2.2] chiede ≥ 24pt): i pulsanti a icona
        // erano altrimenti sotto misura. L'altezza riempie la barra (44pt); la larghezza minima 44 è sui
        // pulsanti a icona (quelli testuali sono già larghi). Verificato da unit test sui frame resi.
        let iconButtons = [bookmarksButton, splitButton, decreaseTextSizeButton, increaseTextSizeButton,
                           resetStructureButton, prevExpandedButton, nextExpandedButton]
        for b in iconButtons {
            b.widthAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        }
        for b in [backButton, layoutSelectorButton] + iconButtons {
            b.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        }
        // Menù iniziale (solo Lettura Continua finché il controller non lo configura).
        configureLayoutSelector(current: .continuous, doctrineAvailable: false,
                                quickAvailable: false, onSelect: { _ in })

        // ── Container chiuso: elenco esplicito e ordinato dei soli elementi d'interfaccia ──────
        isAccessibilityElement = false
        accessibilityContainerType = .semanticGroup
        refreshAccessibilityElements()
    }

    /// Aggiorna l'ordine di lettura del container: [Indietro, selettore Layout], poi — quando
    /// presenti — il box pagina ORIGINALE e infine quello di VISUALIZZAZIONE (§ 4.3).
    private func refreshAccessibilityElements() {
        var elements: [NSObject] = [backButton, layoutSelectorButton]
        if !splitButton.isHidden { elements.append(splitButton) }
        if !bookmarksButton.isHidden { elements.append(bookmarksButton) }
        if !decreaseTextSizeButton.isHidden { elements.append(decreaseTextSizeButton) }
        if !increaseTextSizeButton.isHidden { elements.append(increaseTextSizeButton) }
        if !quickControlsStack.isHidden {
            elements.append(resetStructureButton)
            elements.append(prevExpandedButton)
            elements.append(nextExpandedButton)
        }
        if !originalPageLabel.isHidden { elements.append(originalPageLabel) }
        if !visualizationPageLabel.isHidden { elements.append(visualizationPageLabel) }
        accessibilityElements = elements
    }

    /// Mostra/nasconde i controlli specifici della Consultazione Rapida (§ 8.5). In quel Layout
    /// l'indicatore di pagina del bar è nascosto (la pagina sta nelle etichette dell'albero, § 8.4).
    /// `canNavigate` abilita le frecce solo con ≥ 2 foglie espanse (altrimenti oscurate).
    func setQuickControls(visible: Bool, canNavigate: Bool) {
        quickControlsStack.isHidden = !visible
        pageIndicatorStack.isHidden = visible || (originalPageLabel.isHidden && visualizationPageLabel.isHidden)
        prevExpandedButton.isEnabled = canNavigate
        nextExpandedButton.isEnabled = canNavigate
        prevExpandedButton.accessibilityTraits = canNavigate ? .button : [.button, .notEnabled]
        nextExpandedButton.accessibilityTraits = canNavigate ? .button : [.button, .notEnabled]
        refreshAccessibilityElements()
    }

    @objc private func resetTapped() { onResetStructure?() }
    @objc private func prevTapped() { onPrevExpanded?() }
    @objc private func nextTapped() { onNextExpanded?() }
    @objc private func decreaseTextSizeTapped() { onDecreaseTextSize?() }
    @objc private func increaseTextSizeTapped() { onIncreaseTextSize?() }

    // MARK: - Selettore di Layout (§ 3.4)

    /// Configura il selettore: `current` è il layout attivo, `doctrineAvailable` decide se la voce
    /// Dottrina Inline è scegliibile (§ 10.3: disabilitata, con motivo esplicito, se il documento
    /// non ha note). `onSelect` è invocato quando l'utente sceglie un layout dal menù.
    func configureLayoutSelector(
        current: LayoutId, doctrineAvailable: Bool, quickAvailable: Bool,
        onSelect: @escaping (LayoutId) -> Void
    ) {
        currentLayout = current
        onLayoutSelected = onSelect

        let continuousAction = UIAction(
            title: LAYOUT_DISPLAY_NAMES[.continuous] ?? "Lettura Continua",
            state: current == .continuous ? .on : .off
        ) { [weak self] _ in self?.onLayoutSelected?(.continuous) }

        // Consultazione Rapida (§ 8): disponibile solo se il documento ha una gerarchia
        // consultabile (§ 8.8); altrimenti disabilitata con motivo esplicito (come Dottrina Inline).
        let quickTitle = quickAvailable
            ? (LAYOUT_DISPLAY_NAMES[.quick] ?? "Consultazione Rapida")
            : "Consultazione Rapida — non disponibile (nessuna gerarchia)"
        let quickAction = UIAction(
            title: quickTitle,
            attributes: quickAvailable ? [] : [.disabled],
            state: current == .quick ? .on : .off
        ) { [weak self] _ in self?.onLayoutSelected?(.quick) }

        let doctrineTitle = doctrineAvailable
            ? (LAYOUT_DISPLAY_NAMES[.doctrine] ?? "Dottrina Inline")
            : "Dottrina Inline — non disponibile (nessuna nota)"
        let doctrineAction = UIAction(
            title: doctrineTitle,
            attributes: doctrineAvailable ? [] : [.disabled],
            state: current == .doctrine ? .on : .off
        ) { [weak self] _ in self?.onLayoutSelected?(.doctrine) }

        layoutSelectorButton.menu = UIMenu(
            title: "Layout di lettura", children: [continuousAction, quickAction, doctrineAction])
        let name = LAYOUT_DISPLAY_NAMES[current] ?? "Lettura Continua"
        layoutSelectorButton.setTitle(name, for: .normal)
        layoutSelectorButton.accessibilityLabel = "Layout di lettura, \(name)"
        layoutSelectorButton.accessibilityHint = "Doppio tap per scegliere il layout di lettura"
    }

    /// Imposta l'indicatore di pagina (§ 4.3) come due box separati. `visualizationTotal == 0`
    /// nasconde entrambi (nessuna impaginazione). Con `showOriginal` vero e dato disponibile si
    /// mostrano DUE box distinti — originale e visualizzazione — ciascuno elemento accessibile a sé
    /// con la propria etichetta qualificata (bi-modale, § 2.1); altrimenti il solo box di
    /// visualizzazione.
    func setPageIndicator(
        visualizationCurrent: Int,
        visualizationTotal: Int,
        originalCurrent: Int?,
        originalTotal: Int,
        showOriginal: Bool
    ) {
        // Box di visualizzazione e box del file originale sono INDIPENDENTI (Opzione A verticale: la
        // pagina di visualizzazione sintetica cade — `visualizationTotal == 0` la nasconde — mentre la
        // pagina del file originale resta l'unico indicatore, § 4).
        if visualizationTotal > 0 {
            visualizationPageLabel.text = "\(visualizationCurrent) di \(visualizationTotal)"
            visualizationPageLabel.accessibilityLabel =
                "pagina \(visualizationCurrent) di \(visualizationTotal) di visualizzazione"
            visualizationPageLabel.isHidden = false
        } else {
            visualizationPageLabel.isHidden = true
        }

        // Box del file originale: se richiesto e con dato disponibile.
        if showOriginal, let original = originalCurrent, originalTotal > 0 {
            originalPageLabel.text = "\(original) di \(originalTotal)"
            originalPageLabel.accessibilityLabel =
                "pagina \(original) di \(originalTotal) del file originale"
            originalPageLabel.isHidden = false
        } else {
            originalPageLabel.isHidden = true
        }
        refreshAccessibilityElements()
    }

    @objc private func backTapped() {
        onBack?()
    }

    @objc private func bookmarksTapped() {
        onBookmarks?()
    }

    @objc private func splitTapped() {
        onSplit?()
    }

    override func accessibilityPerformEscape() -> Bool {
        guard let onEscape else { return false }
        onEscape()
        return true
    }
}

/// `UILabel` con padding interno, per rendere i box dell'indicatore di pagina come riquadri
/// distinti (sfondo + angoli + spazio attorno al testo).
final class InsetLabel: UILabel {
    var insets = UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8)

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + insets.left + insets.right,
                      height: size.height + insets.top + insets.bottom)
    }
}
