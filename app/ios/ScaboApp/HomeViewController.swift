//
//  HomeViewController.swift
//  ScaboApp
//
//  La Home NUDA (decisione A): un solo pulsante "Importa". Niente recenti, niente libreria,
//  niente memoria del punto di lettura — sono versioni future (§ 12), esplicitamente fuori scope.
//  Il flusso minimo è: Importa → scelta del PDF col document picker di sistema → finestra di
//  elaborazione bloccante → all'esito positivo si apre AUTOMATICAMENTE la reading view; il tasto
//  Indietro della reading view riporta qui. Reimportare = nuova elaborazione da capo. Nessuna
//  persistenza.
//
//  ── Confine di responsabilità ───────────────────────────────────────────────────────────────
//
//  La Home orchestra soltanto: presenta il picker, copia in locale il file scelto, presenta la
//  finestra di elaborazione e instrada l'esito (apri lettore / mostra errore in prosa / torna in
//  Home). Il lavoro pesante vive nel `DocumentProcessor` (fuori dal main); l'estrazione PDFKit
//  resta confinata nel suo estrattore. Qui non si importa PDFKit.
//

import UIKit
import UniformTypeIdentifiers
import ScaboCore

final class HomeViewController: UIViewController {

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "ScaboPDF"
        label.font = UIFont.preferredFont(forTextStyle: .largeTitle)
        label.adjustsFontForContentSizeCategory = true
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.accessibilityTraits.insert(.header)
        return label
    }()

    private let importButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "Importa"
        config.buttonSize = .large
        let button = UIButton(configuration: config)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.translatesAutoresizingMaskIntoConstraints = false
        button.accessibilityLabel = "Importa un documento PDF"
        button.accessibilityHint = "Apre la scelta di un file PDF dal dispositivo"
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        layoutHome()
        importButton.addTarget(self, action: #selector(importTapped), for: .touchUpInside)
    }

    private func layoutHome() {
        view.addSubview(titleLabel)
        view.addSubview(importButton)
        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: importButton.topAnchor, constant: -32),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),

            importButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            importButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    // MARK: - Import

    @objc private func importTapped() {
        // Document picker di sistema. `asCopy: true` consegna una copia nel sandbox dell'app:
        // niente risorsa security-scoped da gestire a mano oltre il callback.
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf], asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }

    /// Avvia l'elaborazione su una copia locale del PDF che l'app possiede, presentando la
    /// finestra di elaborazione bloccante. Alla conclusione la copia temporanea è rimossa.
    private func startProcessing(originalURL: URL) {
        guard let localCopy = copyIntoTemporary(originalURL) else {
            presentError(
                "Non è stato possibile leggere il file scelto. Riprova selezionandolo di nuovo.")
            return
        }
        let sourceName = originalURL.lastPathComponent

        let processingVC = ProcessingViewController(fileURL: localCopy, sourceName: sourceName)
        processingVC.onOutcome = { [weak self] outcome in
            self?.dismiss(animated: true) {   // chiude la finestra di elaborazione
                try? FileManager.default.removeItem(at: localCopy)   // pulizia copia temporanea
                self?.handleOutcome(outcome, sourceName: sourceName)
            }
        }
        present(processingVC, animated: true)
    }

    private func handleOutcome(_ outcome: DocumentProcessor.Outcome, sourceName: String) {
        switch outcome {
        case .success(_, let content):
            openReader(content: content, sourceName: sourceName)
        case .cancelled:
            break   // torna alla Home nuda, senza messaggi
        case .failure(let message):
            presentError(message)
        }
    }

    /// Apre AUTOMATICAMENTE la reading view sul documento elaborato. Il suo Indietro torna qui.
    private func openReader(content: PaginatedContent, sourceName: String) {
        let reader = ContinuousReadingViewController(content: content, sourceName: sourceName)
        reader.modalPresentationStyle = .fullScreen
        reader.onBack = { [weak self] in self?.dismiss(animated: true) }
        present(reader, animated: true)
    }

    // MARK: - Helpers

    /// Copia il file in una posizione temporanea che l'app controlla, così l'elaborazione lunga
    /// non dipende dal ciclo di vita dell'URL del picker. `nil` se la copia fallisce.
    private func copyIntoTemporary(_ source: URL) -> URL? {
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("scabo_import_\(UUID().uuidString).pdf")
        do {
            try FileManager.default.copyItem(at: source, to: destination)
            return destination
        } catch {
            return nil
        }
    }

    /// Messaggio d'errore in prosa comprensibile (§ 12.10): niente solo "errore".
    private func presentError(_ message: String) {
        let alert = UIAlertController(
            title: "Importazione non riuscita", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ho capito", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UIDocumentPickerDelegate

extension HomeViewController: UIDocumentPickerDelegate {

    func documentPicker(
        _ controller: UIDocumentPickerViewController,
        didPickDocumentsAt urls: [URL]
    ) {
        guard let url = urls.first else { return }
        startProcessing(originalURL: url)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        // L'utente ha annullato la scelta del file: nessuna azione, resta in Home nuda.
    }
}
