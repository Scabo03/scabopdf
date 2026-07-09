//
//  AknDocumentProcessor.swift
//  ScaboApp
//
//  Orchestratore dell'importazione di un file AKN (Normattiva), PARALLELO a
//  `DocumentProcessor` (PDF) e mai ramificato dentro di esso (scelta anti-regressione).
//  Non passa da PDFKit né dai plugin di classificazione visiva: parsa l'XML via
//  `buildAknDocument` (ScaboCore) e impagina via `AknBodyBuilder` (rifinitura dei
//  tre attriti inclusa). Conforme a `DocumentProcessing` così riusa la stessa
//  schermata di avanzamento (`ProcessingViewController`) del percorso PDF.
//
//  L'AKN non ha pagine e il parse è veloce: l'avanzamento è a tappe di fase
//  (apertura → riconoscimento struttura → impaginazione), non per-pagina.
//

import Foundation
import ScaboCore

/// Confine comune fra gli orchestratori di importazione (PDF e AKN), consumato da
/// `ProcessingViewController`. Entrambi consegnano `onProgress`/`completion` sul main.
protocol DocumentProcessing: AnyObject {
    func process(
        fileURL: URL,
        sourceName: String,
        granularityTarget: Int,
        buildDoctrine: Bool,
        onProgress: @escaping (DocumentProcessor.Progress) -> Void,
        completion: @escaping (DocumentProcessor.Outcome) -> Void
    )
    func cancel()
}

extension DocumentProcessor: DocumentProcessing {}

/// Orchestratore one-shot per l'import AKN. Crearne uno per importazione.
final class AknDocumentProcessor: DocumentProcessing {

    private let flag = CancellationFlag()
    private let workQueue = DispatchQueue(label: "scabopdf.akn-processing", qos: .userInitiated)
    private var didComplete = false

    func process(
        fileURL: URL,
        sourceName: String,
        granularityTarget: Int = DEFAULT_GRANULARITY_TARGET,
        buildDoctrine: Bool = true,
        onProgress: @escaping (DocumentProcessor.Progress) -> Void,
        completion: @escaping (DocumentProcessor.Outcome) -> Void
    ) {
        workQueue.async { [weak self] in
            guard let self else { return }
            func report(_ phase: DocumentProcessor.Phase, _ fraction: Double) {
                DispatchQueue.main.async {
                    onProgress(DocumentProcessor.Progress(
                        phase: phase, unitsDone: 0, unitsTotal: 0, fraction: fraction))
                }
            }
            func finish(_ outcome: DocumentProcessor.Outcome) {
                DispatchQueue.main.async {
                    guard !self.didComplete else { return }
                    self.didComplete = true
                    completion(outcome)
                }
            }

            if self.flag.isCancelled { finish(.cancelled); return }
            report(.opening, 0)

            guard let data = try? Data(contentsOf: fileURL) else {
                finish(.failure(message:
                    "Non è stato possibile leggere il file selezionato. Riprova selezionandolo di nuovo."))
                return
            }
            if self.flag.isCancelled { finish(.cancelled); return }

            // Fase struttura: detector + parser AKN → ScabopdfDocument.
            report(.classification, 0.4)
            let document: ScabopdfDocument
            do {
                document = try buildAknDocument(data, sourceName: sourceName)
            } catch let AknParseError.refused(_, explanation) {
                // Spiegazione in prosa del detector (NOT_AKN / INVALID_XML), §12.10.
                finish(.failure(message: explanation))
                return
            } catch {
                finish(.failure(message:
                    "Il file non è un documento Akoma Ntoso leggibile e non può essere importato."))
                return
            }
            if self.flag.isCancelled { finish(.cancelled); return }

            // Fase impaginazione: rifinitura AKN (note frazionate, comma, modifiche) + paginazione.
            report(.pagination, 0.8)
            let content: PaginatedContent
            do {
                content = try AknBodyBuilder.bodyPaginatedContent(from: document, target: granularityTarget)
            } catch {
                finish(.failure(message:
                    "L'impaginazione del documento non è riuscita e non è stato possibile aprirlo."))
                return
            }

            if content.pages.isEmpty {
                finish(.failure(message:
                    "Il file Akoma Ntoso è stato letto, ma non contiene testo normativo estraibile."))
                return
            }
            if self.flag.isCancelled { finish(.cancelled); return }
            report(.pagination, 1.0)
            // Dottrina Inline (§10) non disponibile per l'AKN in v1: le note normative restano in
            // posizione strutturale (§7.2); il selettore la mostra disabilitata (doctrineContent nil).
            finish(.success(document: document, content: content, doctrineContent: nil))
        }
    }

    func cancel() {
        flag.cancel()
    }
}
