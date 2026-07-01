//
//  ProcessingViewController.swift
//  ScaboApp
//
//  La finestra di elaborazione BLOCCANTE e MODALE (§ 12.9, decisione C). Mentre l'app elabora il
//  PDF importato: oscura lo schermo, blocca l'interazione sottostante, espone l'avanzamento
//  bi-modale (barra visiva + percentuale testuale annunciabile), e offre il tasto Annulla che
//  interrompe l'elaborazione in modo pulito. L'esito (successo / annullamento / errore in prosa)
//  è consegnato al presentatore via `onOutcome`.
//
//  ── Sigillatura modale (§ 2.3) ──────────────────────────────────────────────────────────────
//
//  `accessibilityViewIsModal = true` + `isModalInPresentation = true`: lo swipe VoiceOver resta
//  dentro la finestra (stato di avanzamento + Annulla) e non raggiunge nulla sotto; la finestra
//  non è scartabile con lo swipe-giù. È il container di accessibilità corrente finché è aperta.
//
//  ── Annunci MODERATI (no mitragliamento) ────────────────────────────────────────────────────
//
//  VoiceOver NON annuncia ogni singola percentuale. Si annuncia a scatti sensati: il cambio di
//  FASE (estrazione → struttura → impaginazione) e ogni nuovo DECILE di avanzamento (~10%). La
//  percentuale puntuale resta sempre interrogabile come `accessibilityValue` dell'elemento di
//  stato, senza essere sparata a ogni tick.
//
//  ── Percentuale REALE (mai finta) ───────────────────────────────────────────────────────────
//
//  La barra e la percentuale riflettono il progresso VERO della catena (pagine elaborate),
//  calcolato dal `DocumentProcessor`. Niente avanzamento simulato/temporizzato.
//

import UIKit
import ScaboCore

final class ProcessingViewController: UIViewController {

    /// Esito dell'elaborazione, consegnato al presentatore (che gestisce dismissal e navigazione).
    var onOutcome: ((DocumentProcessor.Outcome) -> Void)?

    private let fileURL: URL
    private let sourceName: String
    private let granularityTarget: Int
    private let buildDoctrine: Bool
    private let processor: DocumentProcessor

    /// Player dei segnali acustici (seam per i test). Stati cablati: `loading` (in loop
    /// mentre l'elaborazione è in corso), `completion` (successo), `error` (fallimento).
    private let signalPlayer: SignalPlaying

    /// Una sola consegna dell'esito (Annulla immediato + completion del processor convergono qui).
    private var finished = false

    /// Ultimo decile annunciato (-1 = nessuno) e ultima etichetta di fase annunciata.
    private var lastAnnouncedDecile = -1
    private var lastAnnouncedPhase = ""

    // MARK: - UI

    private let card: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 16
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Elaborazione del documento"
        label.font = UIFont.preferredFont(forTextStyle: .headline)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let fileLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: .subheadline)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let progressView: UIProgressView = {
        let view = UIProgressView(progressViewStyle: .default)
        view.progress = 0
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// Elemento di stato bi-modale: visivamente mostra "Fase — NN%"; per VoiceOver porta la fase
    /// come `accessibilityLabel` e la percentuale come `accessibilityValue` (interrogabile a
    /// richiesta, senza annunci a raffica).
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isAccessibilityElement = true
        return label
    }()

    private let cancelButton: UIButton = {
        var config = UIButton.Configuration.bordered()
        config.title = "Annulla"
        let button = UIButton(configuration: config)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.translatesAutoresizingMaskIntoConstraints = false
        button.accessibilityLabel = "Annulla"
        button.accessibilityHint = "Interrompe l'elaborazione e torna alla schermata iniziale"
        return button
    }()

    // MARK: - Init

    init(
        fileURL: URL,
        sourceName: String,
        granularityTarget: Int = DEFAULT_GRANULARITY_TARGET,
        buildDoctrine: Bool = true,
        processor: DocumentProcessor = DocumentProcessor(),
        signalPlayer: SignalPlaying = SignalPlayer.shared
    ) {
        self.fileURL = fileURL
        self.sourceName = sourceName
        self.granularityTarget = granularityTarget
        self.buildDoctrine = buildDoctrine
        self.processor = processor
        self.signalPlayer = signalPlayer
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
        isModalInPresentation = true   // niente swipe-giù per scartare
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) non supportato: ProcessingViewController è costruito in codice.")
    }

    // MARK: - Ciclo di vita

    override func viewDidLoad() {
        super.viewDidLoad()
        // Oscura lo schermo sottostante (blocco visivo + modale).
        view.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        layoutCard()
        fileLabel.text = sourceName
        applyStatus(phaseLabel: "Apertura del documento", percent: 0)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)

        // Sigillatura modale di accessibilità: solo stato + Annulla raggiungibili via swipe.
        view.accessibilityViewIsModal = true
        view.accessibilityElements = [statusLabel, cancelButton]
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Avvia l'elaborazione DOPO la comparsa (gli annunci VoiceOver atterrano nel container
        // modale corretto). Una sola volta.
        startProcessingIfNeeded()
    }

    private var started = false
    private func startProcessingIfNeeded() {
        guard !started else { return }
        started = true
        // Segnale di stato "in corso": parte all'avvio reale dell'elaborazione e gira in
        // loop finché non arriva l'esito (clip breve, l'elaborazione può durare di più).
        signalPlayer.playLooping(.loading)
        processor.process(
            fileURL: fileURL,
            sourceName: sourceName,
            granularityTarget: granularityTarget,
            buildDoctrine: buildDoctrine,
            onProgress: { [weak self] progress in self?.apply(progress) },
            completion: { [weak self] outcome in self?.finish(outcome) }
        )
    }

    // MARK: - Avanzamento

    private func apply(_ progress: DocumentProcessor.Progress) {
        let fraction = max(0, min(1, progress.fraction))
        let percent = Int((fraction * 100).rounded())
        progressView.setProgress(Float(fraction), animated: true)
        applyStatus(phaseLabel: progress.phaseLabel, percent: percent)
        announceModerately(phaseLabel: progress.phaseLabel, percent: percent, fraction: fraction)
    }

    private func applyStatus(phaseLabel: String, percent: Int) {
        statusLabel.text = "\(phaseLabel) — \(percent)%"
        statusLabel.accessibilityLabel = phaseLabel
        statusLabel.accessibilityValue = "\(percent) per cento"
    }

    /// Annunci a scatti sensati: cambio di fase e ogni nuovo decile. Mai ogni singolo tick.
    private func announceModerately(phaseLabel: String, percent: Int, fraction: Double) {
        if phaseLabel != lastAnnouncedPhase {
            lastAnnouncedPhase = phaseLabel
            UIAccessibility.post(notification: .announcement, argument: phaseLabel)
        }
        let decile = Int(fraction * 10)
        if decile != lastAnnouncedDecile, percent > 0 {
            lastAnnouncedDecile = decile
            UIAccessibility.post(notification: .announcement, argument: "\(percent) per cento")
        }
    }

    // MARK: - Annulla / esito

    @objc private func cancelTapped() {
        // Cancellazione cooperativa del lavoro in background + risposta immediata in UI.
        processor.cancel()
        cancelButton.isEnabled = false
        finish(.cancelled)
    }

    /// Punto unico e idempotente di consegna dell'esito (Annulla e completion del processor
    /// convergono qui; il primo vince, il resto è ignorato).
    private func finish(_ outcome: DocumentProcessor.Outcome) {
        guard !finished else { return }
        finished = true
        // Chiude il segnale "in corso" e suona l'esito: completamento o errore. Su
        // annullamento non si suona nulla (l'utente torna alla Home nuda in silenzio).
        signalPlayer.stop(.loading)
        switch outcome {
        case .success:
            signalPlayer.play(.completion)
        case .failure:
            signalPlayer.play(.error)
        case .cancelled:
            break
        }
        onOutcome?(outcome)
    }

    // MARK: - Introspezione per i test

    /// Vero se la finestra è un container modale sigillato (swipe confinato a stato + Annulla).
    var isModalSealedForTesting: Bool { view.accessibilityViewIsModal }
    /// La percentuale puntuale esposta a VoiceOver come valore dell'elemento di stato.
    var statusValueForTesting: String? { statusLabel.accessibilityValue }
    /// La frazione attuale della barra visiva.
    var progressFractionForTesting: Float { progressView.progress }
    /// Applica un avanzamento (per verificare gli aggiornamenti UI senza avviare l'elaborazione).
    func applyForTesting(_ progress: DocumentProcessor.Progress) { apply(progress) }
    /// Simula il tocco su Annulla (senza avviare l'elaborazione reale).
    func cancelForTesting() { cancelTapped() }
    /// Consegna un esito (per verificare i segnali acustici di stato senza l'elaborazione reale).
    func finishForTesting(_ outcome: DocumentProcessor.Outcome) { finish(outcome) }
    /// Avvia il segnale "in corso" come farebbe l'avvio reale (per i test, senza estrazione).
    func startSignalForTesting() { startProcessingIfNeeded() }

    // MARK: - Layout

    private func layoutCard() {
        view.addSubview(card)
        let stack = UIStackView(arrangedSubviews: [titleLabel, fileLabel, progressView, statusLabel, cancelButton])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            card.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            card.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            card.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),
            card.widthAnchor.constraint(lessThanOrEqualToConstant: 420),

            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -24),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -24),
        ])
    }
}
