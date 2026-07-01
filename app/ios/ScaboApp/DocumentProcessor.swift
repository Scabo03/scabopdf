//
//  DocumentProcessor.swift
//  ScaboApp
//
//  Orchestratore dell'elaborazione di un PDF importato: estrazione → classificazione →
//  impaginazione del corpo, FUORI dal main thread, con progresso REALE e cancellazione pulita.
//  Vive nel target app perché orchestra la catena on-device (PdfKitExtractor → ScaboCore →
//  ContinuousBodyBuilder); l'estrazione PDFKit resta confinata dietro il seam, l'orchestratore
//  non importa PDFKit.
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
import ScaboCore

/// Seam d'iniezione per l'estrazione progress-aware: permette ai test di sostituire PDFKit con un
/// estrattore deterministico (numero di pagine noto, cancellazione controllata) senza Simulator
/// né file reali. `PdfKitExtractor` vi si conforma con il metodo già definito.
protocol ProgressReportingPdfExtractor {
    func extract(
        fromUri uri: String,
        onPageExtracted: (_ done: Int, _ total: Int) -> Void,
        isCancelled: () -> Bool
    ) throws -> PdfExtraction?
}

extension PdfKitExtractor: ProgressReportingPdfExtractor {}

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
        case classification
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
            case .classification: return "Riconoscimento della struttura"
            case .pagination: return "Impaginazione"
            }
        }
    }

    private let extractor: ProgressReportingPdfExtractor
    private let flag = CancellationFlag()
    private let workQueue = DispatchQueue(label: "scabopdf.document-processing", qos: .userInitiated)
    private var didComplete = false

    init(extractor: ProgressReportingPdfExtractor = PdfKitExtractor()) {
        self.extractor = extractor
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
        let uri = fileURL.absoluteString

        workQueue.async { [weak self] in
            guard let self else { return }

            func report(_ progress: Progress) {
                DispatchQueue.main.async { onProgress(progress) }
            }
            func finish(_ outcome: Outcome) {
                DispatchQueue.main.async {
                    guard !self.didComplete else { return }
                    self.didComplete = true
                    completion(outcome)
                }
            }

            if self.flag.isCancelled { finish(.cancelled); return }
            report(Progress(phase: .opening, unitsDone: 0, unitsTotal: 0, fraction: 0))

            // ── Fase 1: estrazione (per pagina) ────────────────────────────────────────────────
            let extraction: PdfExtraction?
            do {
                extraction = try self.extractor.extract(
                    fromUri: uri,
                    onPageExtracted: { done, total in
                        let denom = Double(2 * total + 1)
                        report(Progress(
                            phase: .extraction, unitsDone: done, unitsTotal: total,
                            fraction: denom > 0 ? Double(done) / denom : 0))
                    },
                    isCancelled: { self.flag.isCancelled }
                )
            } catch {
                finish(.failure(message: Self.proseMessage(from: error)))
                return
            }
            guard let extraction else { finish(.cancelled); return }
            let pageCount = extraction.pageCount

            // ── Fase 2: classificazione (per pagina) ───────────────────────────────────────────
            let rawDocument = buildDocumentFromPdf(
                extraction,
                sourceName: sourceName,
                onPageClassified: { done, total in
                    let denom = Double(2 * total + 1)
                    report(Progress(
                        phase: .classification, unitsDone: done, unitsTotal: total,
                        fraction: denom > 0 ? Double(total + done) / denom : 1))
                },
                isCancelled: { self.flag.isCancelled }
            )
            guard let rawDocument else { finish(.cancelled); return }

            // ── Aggancio e piazzamento delle note (capitolo NOTE) ──────────────────────────────
            // Tra classificazione e impaginazione: aggancia ogni richiamo alla sua nota e
            // riposiziona le note nell'albero (brevi a fine frase, lunghe a fine sezione, § 7.3).
            // Le non agganciate restano in posizione (lette, mai perse). Richiede l'estrazione
            // (i segnali di dimensione/parentesi degli span che la classificazione collassa).
            // `document` è il piazzamento LETTURA CONTINUA (default, storico invariato).
            let document = bindAndPlaceNotes(rawDocument, extraction).document
            // Il documento ha note? (decide se Dottrina Inline è disponibile, § 10.3.)
            let hasNotes = rawDocument.structure.contains {
                $0.type == .NOTE || $0.type == .EDITORIAL_NOTE
            }

            // ── Fase 3: impaginazione del corpo (passo finale unico) ───────────────────────────
            if self.flag.isCancelled { finish(.cancelled); return }
            report(Progress(
                phase: .pagination, unitsDone: 0, unitsTotal: pageCount,
                fraction: pageCount > 0 ? Double(2 * pageCount) / Double(2 * pageCount + 1) : 0.5))

            let content: PaginatedContent
            var doctrineContent: PaginatedContent?
            do {
                content = try ContinuousBodyBuilder.bodyPaginatedContent(from: document, target: granularityTarget)
                // Dottrina Inline (§ 10): SOLO se ci sono note E se `buildDoctrine` (per i volumi
                // enormi lo si salta: è un secondo flusso da decine di migliaia di segmenti che
                // raddoppierebbe la memoria all'apertura, e la Lettura Continua di default non lo
                // usa — vedi la gate sui volumi enormi in DocumentOpener). Stesso aggancio,
                // piazzamento tutto-inline a fine frase del richiamo (§ 10.2).
                if hasNotes && buildDoctrine {
                    let doctrineDoc = bindAndPlaceNotes(
                        rawDocument, extraction, placement: .doctrineInline).document
                    doctrineContent = try ContinuousBodyBuilder.bodyPaginatedContent(from: doctrineDoc, target: granularityTarget)
                }
            } catch {
                finish(.failure(message: Self.proseMessage(from: error)))
                return
            }

            // Guardia di contenuto minima (§ 12.10/12.11): se il PDF ha pagine ma non se ne è
            // ricavato ALCUN testo (tipico delle scansioni di sole immagini senza livello di
            // testo), aprire un lettore vuoto ingannerebbe l'utente. Si fallisce con prosa chiara
            // anziché spacciare un documento monco per completo.
            if pageCount > 0 && document.structure.isEmpty {
                finish(.failure(message:
                    "Il PDF è stato aperto, ma non contiene testo leggibile: con ogni probabilità "
                    + "è una scansione di immagini priva del livello di testo. ScaboPDF non può "
                    + "renderlo accessibile. Serve un PDF con testo selezionabile (o un passaggio "
                    + "di OCR prima dell'importazione)."))
                return
            }

            if self.flag.isCancelled { finish(.cancelled); return }
            report(Progress(phase: .pagination, unitsDone: pageCount, unitsTotal: pageCount, fraction: 1.0))
            finish(.success(document: document, content: content, doctrineContent: doctrineContent))
        }
    }

    /// Richiesta di cancellazione cooperativa. Sicura da chiamare dal main mentre il lavoro gira:
    /// il background si ferma al prossimo checkpoint e consegna `.cancelled`.
    func cancel() {
        flag.cancel()
    }

    /// Riduce un errore a una spiegazione in prosa italiana. Gli errori dell'estrattore portano
    /// già un `localizedDescription` leggibile; il fallback copre il caso generico.
    private static func proseMessage(from error: Error) -> String {
        let described = (error as NSError).localizedDescription
        if !described.isEmpty {
            return described
        }
        return "Si è verificato un problema durante l'elaborazione del documento e non è stato "
            + "possibile completarla."
    }
}
