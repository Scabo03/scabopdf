//
//  DocumentProcessor.swift
//  ScaboApp
//
//  Orchestratore dell'elaborazione di un PDF importato: estrazione → classificazione →
//  impaginazione del corpo, FUORI dal main thread, con progresso REALE e cancellazione pulita.
//
//  Dal 2026-10-16 (giro «costruzione della linea Mac») la CATENA vera e propria vive nel modulo condiviso
//  ScaboChain (`ProcessingChain.run`), che la usa identica anche l'app Mac: qui resta l'involucro dell'app
//  (coda di lavoro, avanzamento e esito consegnati sul main, bandiera d'annullamento, tipi letti dalla UI).
//  L'ordine delle fasi, i controlli d'annullamento, i valori d'avanzamento e i messaggi sono quelli di prima.
//
//  ── Percentuale REALE, mai finta (principio di prodotto, § 12.9) ─────────────────────────────
//
//  L'avanzamento riflette il lavoro VERO, non un timer. L'unità di progresso è la PAGINA: ogni
//  tick corrisponde a una pagina effettivamente elaborata. Le due fasi pesanti — estrazione e
//  classificazione — iterano entrambe le M pagine del documento ed espongono un callback per
//  pagina (PdfKitExtractor.extract progress-aware; buildDocumentFromPdf progress-aware in
//  ScaboCore). L'impaginazione del corpo è un passo finale unico. Il denominatore complessivo è
//  quindi `2·M + 1` "operazioni-pagina" reali: estrazione [1…M], classificazione [M+1…2M],
//  impaginazione (2M+1). La frazione è `done / (2M+1)`, monotòna crescente per costruzione fino a
//  1.0. Nessun progresso simulato/temporizzato: se una fase è grossolana, la barra avanza a
//  SCATTI reali (preferito a una fluidità finta). M è noto solo dopo l'apertura del PDF, perciò
//  prima del primo tick lo stato è "apertura del documento" a frazione 0.
//
//  ── Concorrenza ─────────────────────────────────────────────────────────────────────────────
//
//  `process` gira su una coda di background (`userInitiated`); i callback `onProgress` e l'esito
//  `completion` sono SEMPRE consegnati sul main. La cancellazione è un flag thread-safe
//  consultato alle tappe naturali della catena (per pagina in estrazione e classificazione, e ai
//  confini di fase): `cancel()` può essere chiamato dal main mentre il lavoro gira, e il
//  background ritorna pulito al prossimo checkpoint con esito `.cancelled` — nessun documento
//  parziale viene mai consegnato come successo.
//

import Foundation
import ScaboChain
import ScaboCore

/// Flag di cancellazione thread-safe (impostabile dal main, letto dal background).
final class CancellationFlag {
    private let lock = NSLock()
    private var cancelled = false

    var isCancelled: Bool {
        lock.lock(); defer { lock.unlock() }
        return cancelled
    }

    func cancel() {
        lock.lock(); defer { lock.unlock() }
        cancelled = true
    }
}

/// Orchestratore one-shot. Crearne uno per importazione; `cancel()` lo interrompe.
final class DocumentProcessor {

    /// Esito dell'elaborazione, consegnato sul main.
    enum Outcome {
        /// Documento elaborato e corpo impaginato pronto per la reading view. `content` è il
        /// flusso di Lettura Continua (sempre presente); `doctrineContent` è il flusso di Dottrina
        /// Inline (§ 10), presente SOLO se il documento ha note (altrimenti `nil` → il layout è
        /// disabilitato nel selettore, § 10.3).
        case success(
            document: ScabopdfDocument,
            content: PaginatedContent,
            doctrineContent: PaginatedContent?)
        /// Annullato dall'utente: nessun documento prodotto.
        case cancelled
        /// Fallimento con spiegazione in PROSA italiana comprensibile (§ 12.10), mai il solo
        /// "errore".
        case failure(message: String)
    }

    /// Fase corrente dell'elaborazione (per l'etichetta annunciabile).
    enum Phase {
        case opening
        case extraction
        /// Riconoscimento di tabelle e figure (risorse visive, `VisualRegionDetector`): la sonda di tutte le pagine
        /// e il modello sulle sole pagine scelte dal prefiltro. Fra estrazione e classificazione.
        case visualResources
        case classification
        /// Solo l'officina Mac (innesto dei verdetti del modello d'impaginazione): sull'iPad non accade mai.
        case graft
        case pagination
    }

    /// Avanzamento reale, consegnato sul main.
    struct Progress {
        let phase: Phase
        /// Pagine elaborate nella fase corrente (0 in apertura/impaginazione).
        let unitsDone: Int
        /// Pagine totali del documento (0 finché non note).
        let unitsTotal: Int
        /// Frazione complessiva 0…1 (vedi nota di testata).
        let fraction: Double

        /// Etichetta della fase in prosa per VoiceOver.
        var phaseLabel: String {
            switch phase {
            case .opening: return "Apertura del documento"
            case .extraction: return "Estrazione del testo"
            case .visualResources: return "Riconoscimento di tabelle e figure"
            case .classification: return "Riconoscimento della struttura"
            case .graft: return "Riconoscimento della struttura delle pagine"
            case .pagination: return "Impaginazione"
            }
        }
    }

    private let extractor: ProgressReportingPdfExtractor
    private let flag = CancellationFlag()
    private let workQueue = DispatchQueue(label: "scabopdf.document-processing", qos: .userInitiated)
    private var didComplete = false
    /// Riconoscimento delle risorse visive (tabelle e figure). Spento solo nei test che non lo riguardano.
    private let detectVisualResources: Bool
    /// L'esito dell'ultimo riconoscimento (conteggi e tempi), leggibile dopo `completion` (registro, test).
    private(set) var lastVisualDetection: VisualRegionDetector.Result?
    /// Le decisioni della guardia sull'ultimo flusso costruito (Lettura Continua).
    private(set) var lastVisualReport: VisualResourcesReport?

    /// Perché il riconoscimento di tabelle e figure dell'ultima elaborazione non è avvenuto (o non del tutto) per una
    /// ragione da riprovare più avanti (memoria, modello: `VisualRegionDetector.retryableSkipReasons`); nil altrimenti.
    /// Chi registra l'elaborazione la segna sul libro, e l'offerta di rielaborazione glielo propone (giro del 2026-10-16).
    var visualResourcesMissingReason: String? {
        guard let reason = lastVisualDetection?.skippedReason,
              VisualRegionDetector.retryableSkipReasons.contains(reason) else { return nil }
        return reason
    }

    init(extractor: ProgressReportingPdfExtractor = PdfKitExtractor(), detectVisualResources: Bool = true) {
        self.extractor = extractor
        self.detectVisualResources = detectVisualResources
    }

    /// Avvia l'elaborazione del file `fileURL` (una copia locale che il chiamante possiede) in
    /// background. `onProgress` e `completion` arrivano sul main; `completion` esattamente una
    /// volta. Idempotente rispetto a una `cancel()` già avvenuta.
    func process(
        fileURL: URL,
        sourceName: String,
        granularityTarget: Int = DEFAULT_GRANULARITY_TARGET,
        buildDoctrine: Bool = true,
        onProgress: @escaping (Progress) -> Void,
        completion: @escaping (Outcome) -> Void
    ) {
        workQueue.async { [weak self] in
            guard let self else { return }

            func finish(_ outcome: Outcome) {
                DispatchQueue.main.async {
                    guard !self.didComplete else { return }
                    self.didComplete = true
                    completion(outcome)
                }
            }

            // La catena condivisa (ScaboChain), con le opzioni dell'iPad: niente innesto; le note lunghe si frazionano
            // come sul Mac e negli atti AKN (§ 10.6, dal 2026-10-16: la lettura è la stessa chiunque l'abbia preparata).
            let outcome = ProcessingChain.run(
                fileURL: fileURL,
                sourceName: sourceName,
                extractor: self.extractor,
                options: ChainOptions(granularityTarget: granularityTarget, buildDoctrine: buildDoctrine,
                                      detectVisualResources: self.detectVisualResources),
                onProgress: { progress in
                    let mapped = Progress(progress)
                    DispatchQueue.main.async { onProgress(mapped) }
                },
                onVisualDetection: { self.lastVisualDetection = $0 },
                isCancelled: { self.flag.isCancelled })
            switch outcome {
            case .success(let result):
                self.lastVisualReport = result.visualReport
                finish(.success(document: result.document, content: result.content, doctrineContent: result.doctrineContent))
            case .cancelled:
                finish(.cancelled)
            case .failure(let message):
                finish(.failure(message: message))
            }
        }
    }

    /// Richiesta di cancellazione cooperativa. Sicura da chiamare dal main mentre il lavoro gira:
    /// il background si ferma al prossimo checkpoint e consegna `.cancelled`.
    func cancel() {
        flag.cancel()
    }
}

extension DocumentProcessor.Progress {
    /// Dall'avanzamento della catena condivisa (stessi valori, fase per fase).
    init(_ p: ChainProgress) {
        let phase: DocumentProcessor.Phase
        switch p.phase {
        case .opening: phase = .opening
        case .extraction: phase = .extraction
        case .visualResources: phase = .visualResources
        case .classification: phase = .classification
        case .graft: phase = .graft
        case .pagination: phase = .pagination
        }
        self.init(phase: phase, unitsDone: p.unitsDone, unitsTotal: p.unitsTotal, fraction: p.fraction)
    }
}
