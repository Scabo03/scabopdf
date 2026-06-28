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

    /// Indicatore di pagina (§ 4.3): singolo di norma ("100 di 1985"), doppio quando il toggle
    /// pagine originali è attivo ("30 di 1472 — 100 di 1985"). Vive in QUESTO container
    /// d'interfaccia (chiuso): non è mai raggiungibile dallo swipe orizzontale di lettura, quindi
    /// non interferisce col vincolo costitutivo (§ 2.2). L'utente lo consulta scrubando alla barra.
    let pageIndicatorLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: .footnote)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .label
        label.textAlignment = .right
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isAccessibilityElement = true
        label.isHidden = true   // nascosto finché non c'è un'impaginazione da mostrare
        return label
    }()

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
        addSubview(pageIndicatorLabel)

        pageIndicatorLabel.setContentHuggingPriority(.required, for: .horizontal)
        pageIndicatorLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        NSLayoutConstraint.activate([
            backButton.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            backButton.centerYAnchor.constraint(equalTo: centerYAnchor),

            pageIndicatorLabel.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
            pageIndicatorLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: backButton.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: pageIndicatorLabel.leadingAnchor, constant: -8),
        ])

        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)

        // ── Container chiuso: elenco esplicito e ordinato dei soli elementi d'interfaccia ──────
        isAccessibilityElement = false
        accessibilityContainerType = .semanticGroup
        refreshAccessibilityElements()
    }

    /// Aggiorna l'ordine di lettura del container in base alla visibilità dell'indicatore: sempre
    /// [Indietro, titolo], e in coda l'indicatore di pagina quando presente. Ordine logico
    /// dall'azione di uscita, al titolo, all'orientamento di pagina.
    private func refreshAccessibilityElements() {
        var elements: [NSObject] = [backButton, titleLabel]
        if !pageIndicatorLabel.isHidden { elements.append(pageIndicatorLabel) }
        accessibilityElements = elements
    }

    /// Imposta l'indicatore di pagina (§ 4.3). `visualizationTotal == 0` lo nasconde (nessuna
    /// impaginazione disponibile). Quando `showOriginal` è vero si mostra la forma DOPPIA
    /// (pagina del file originale prima, di visualizzazione dopo), altrimenti la forma SINGOLA
    /// (solo visualizzazione). La resa è bi-modale (§ 2.1): testo compatto a video, etichetta
    /// estesa per VoiceOver con i qualificatori "del file originale" / "di visualizzazione".
    func setPageIndicator(
        visualizationCurrent: Int,
        visualizationTotal: Int,
        originalCurrent: Int?,
        originalTotal: Int,
        showOriginal: Bool
    ) {
        guard visualizationTotal > 0 else {
            pageIndicatorLabel.isHidden = true
            pageIndicatorLabel.text = nil
            refreshAccessibilityElements()
            return
        }
        let visText = "\(visualizationCurrent) di \(visualizationTotal)"
        if showOriginal, let original = originalCurrent, originalTotal > 0 {
            pageIndicatorLabel.text = "\(original) di \(originalTotal) — \(visText)"
            pageIndicatorLabel.accessibilityLabel =
                "pagina \(original) di \(originalTotal) del file originale, "
                + "pagina \(visualizationCurrent) di \(visualizationTotal) di visualizzazione"
        } else {
            pageIndicatorLabel.text = visText
            pageIndicatorLabel.accessibilityLabel =
                "pagina \(visualizationCurrent) di \(visualizationTotal) di visualizzazione"
        }
        pageIndicatorLabel.isHidden = false
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
