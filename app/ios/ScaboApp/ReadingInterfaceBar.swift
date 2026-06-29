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

    /// Titolo del Layout corrente, "Lettura Continua".
    let titleLabel: UILabel = {
        let label = UILabel()
        label.text = LAYOUT_DISPLAY_NAMES[.continuous]  // "Lettura Continua"
        label.font = UIFont.preferredFont(forTextStyle: .headline)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .label
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isAccessibilityElement = true
        label.accessibilityTraits.insert(.header)
        return label
    }()

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
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

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
        addSubview(titleLabel)
        addSubview(pageIndicatorStack)

        pageIndicatorStack.setContentHuggingPriority(.required, for: .horizontal)
        pageIndicatorStack.setContentCompressionResistancePriority(.required, for: .horizontal)

        NSLayoutConstraint.activate([
            backButton.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            backButton.centerYAnchor.constraint(equalTo: centerYAnchor),

            pageIndicatorStack.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
            pageIndicatorStack.centerYAnchor.constraint(equalTo: centerYAnchor),

            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: backButton.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: pageIndicatorStack.leadingAnchor, constant: -8),
        ])

        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)

        // ── Container chiuso: elenco esplicito e ordinato dei soli elementi d'interfaccia ──────
        isAccessibilityElement = false
        accessibilityContainerType = .semanticGroup
        refreshAccessibilityElements()
    }

    /// Aggiorna l'ordine di lettura del container in base alla visibilità dei box: sempre
    /// [Indietro, titolo], poi — quando presenti — il box pagina ORIGINALE e infine quello di
    /// VISUALIZZAZIONE. L'ordine originale→visualizzazione segue il § 4.3.
    private func refreshAccessibilityElements() {
        var elements: [NSObject] = [backButton, titleLabel]
        if !originalPageLabel.isHidden { elements.append(originalPageLabel) }
        if !visualizationPageLabel.isHidden { elements.append(visualizationPageLabel) }
        accessibilityElements = elements
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
        guard visualizationTotal > 0 else {
            originalPageLabel.isHidden = true
            visualizationPageLabel.isHidden = true
            refreshAccessibilityElements()
            return
        }

        // Box di visualizzazione: sempre presente.
        visualizationPageLabel.text = "\(visualizationCurrent) di \(visualizationTotal)"
        visualizationPageLabel.accessibilityLabel =
            "pagina \(visualizationCurrent) di \(visualizationTotal) di visualizzazione"
        visualizationPageLabel.isHidden = false

        // Box del file originale: solo in modalità doppia, con dato disponibile.
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
