//
//  ProcessingChain.swift
//  ScaboChain
//
//  LA CATENA DI ELABORAZIONE di un PDF, una sola per l'iPad e per il Mac (giro «costruzione della linea Mac»,
//  2026-10-16). È il corpo che fino a oggi stava dentro `DocumentProcessor.process` (bersaglio ScaboApp),
//  spostato qui SENZA cambiarne l'ordine, i controlli d'annullamento, i valori d'avanzamento né i messaggi:
//
//    estrazione (per pagina) → risorse visive (sonda, prefiltro, modello sulle pagine scelte) →
//    classificazione (per pagina) → [innesto, solo Mac] → aggancio e piazzamento delle note →
//    corpo della Lettura Continua (con il frazionamento delle note lunghe) + risorse visive →
//    flusso Dottrina Inline (se ci sono note) → guardia di contenuto minima.
//
//  `DocumentProcessor` dell'app è ora solo l'involucro: coda di lavoro, avanzamento e esito consegnati sul main,
//  bandiera d'annullamento. L'app Mac usa la stessa funzione con un'opzione in più, spenta per l'iPad: `graft`
//  (l'innesto dei verdetti del modello d'impaginazione: il fusore, ScaboCore `Fusore.swift`). Il frazionamento delle
//  note lunghe (`fractionLongNotes`, § 10.6, il meccanismo degli atti AKN) è acceso per entrambi dal 2026-10-16
//  (decisione del maintainer: la lettura è la stessa chiunque l'abbia preparata); fino alla build 54 era solo del Mac.
//  Con le opzioni predefinite la sequenza delle chiamate è quella dell'iPad: lo provano le reti dell'iPad
//  (estrazioni e letture identiche sui 52 volumi, catena dell'app = catena della rete = catena del Mac senza innesto).
//
//  ── Percentuale REALE, mai finta (§ 12.9) ─────────────────────────────────────────────────────────────────────
//  L'unità è la PAGINA: estrazione [1…M], classificazione [M+1…2M], impaginazione (2M+1); la frazione è
//  `done / (2M+1)`, monotòna per costruzione. Le risorse visive e l'innesto non spostano la barra (restano «parcheggiati»
//  alla fine dell'estrazione o della classificazione): il loro avanzamento si legge nelle unità della loro fase.
//

import Foundation
import ScaboCore

/// Seam d'iniezione per l'estrazione con avanzamento e annullamento: i test sostituiscono PDFKit con un estrattore
/// deterministico. `PdfKitExtractor` vi si conforma con il metodo già definito.
public protocol ProgressReportingPdfExtractor {
    func extract(
        fromUri uri: String,
        onPageExtracted: (_ done: Int, _ total: Int) -> Void,
        isCancelled: () -> Bool
    ) throws -> PdfExtraction?
}

extension PdfKitExtractor: ProgressReportingPdfExtractor {}

/// La fase della catena (per l'etichetta annunciabile dell'involucro).
public enum ChainPhase: Equatable, Sendable {
    case opening
    case extraction
    /// Riconoscimento di tabelle e figure (risorse visive).
    case visualResources
    case classification
    /// Innesto dei verdetti del modello d'impaginazione (solo Mac): le pagine mandate al modello per il fusore.
    case graft
    case pagination
}

/// Avanzamento reale della catena.
public struct ChainProgress: Equatable, Sendable {
    public let phase: ChainPhase
    /// Pagine elaborate nella fase corrente (0 in apertura/impaginazione).
    public let unitsDone: Int
    /// Pagine totali della fase (0 finché non note).
    public let unitsTotal: Int
    /// Frazione complessiva 0…1.
    public let fraction: Double

    public init(phase: ChainPhase, unitsDone: Int, unitsTotal: Int, fraction: Double) {
        self.phase = phase
        self.unitsDone = unitsDone
        self.unitsTotal = unitsTotal
        self.fraction = fraction
    }
}

/// L'esito di un innesto: l'estrazione e il documento grezzo dopo le operazioni (righe spostate, nodi
/// rietichettati), e un referto PRIVO DI TESTO (conteggi, pagine, operazioni) per il registro e il pannello.
public struct ChainGraftOutput {
    public var extraction: PdfExtraction
    public var rawDocument: ScabopdfDocument
    public var report: [String]

    public init(extraction: PdfExtraction, rawDocument: ScabopdfDocument, report: [String]) {
        self.extraction = extraction
        self.rawDocument = rawDocument
        self.report = report
    }
}

/// L'innesto (solo Mac): dopo la classificazione, prima dell'aggancio delle note. Non scrive mai testo: sposta righe
/// nell'estrazione (e allora ricostruisce il documento con la stessa classificazione) o rietichetta nodi.
public protocol ChainGraft {
    func graft(
        extraction: PdfExtraction,
        rawDocument: ScabopdfDocument,
        pdfURL: URL,
        sourceName: String,
        onPage: (_ done: Int, _ total: Int) -> Void,
        isCancelled: () -> Bool
    ) -> ChainGraftOutput?
}

/// Le opzioni della catena. Le predefinite sono quelle dell'iPad.
public struct ChainOptions {
    /// Granularità del corpo (§ 7.6): 400 di norma, 1.200 per i volumi enormi.
    public var granularityTarget: Int
    /// Costruire il flusso Dottrina Inline (se ci sono note). Spento per i volumi enormi.
    public var buildDoctrine: Bool
    /// Riconoscere tabelle e figure (risorse visive). Spento solo nei test che non lo riguardano.
    public var detectVisualResources: Bool
    /// Frazionamento delle note lunghe (§ 10.6, `fractionLongNoteSegments`: il meccanismo degli atti AKN, soglia = la
    /// granularità del corpo). Acceso per l'iPad e per il Mac dal 2026-10-16 (decisione del maintainer: la lettura è la
    /// stessa chiunque l'abbia preparata); spento solo dalle reti e dai banchi che riproducono la lettura dell'iPad fino
    /// alla build 54.
    public var fractionLongNotes: Bool
    /// Solo Mac: l'innesto dei verdetti del modello d'impaginazione (il fusore).
    public var graft: ChainGraft?
    /// Solo reti: i candidati delle risorse visive già catturati (per esempio nel simulatore di una generazione) al
    /// posto del riconoscimento dal vivo. `nil` = riconoscimento dal vivo (se `detectVisualResources`).
    public var visualCandidatesOverride: [VisualRegionCandidate]?

    public init(granularityTarget: Int = DEFAULT_GRANULARITY_TARGET, buildDoctrine: Bool = true,
                detectVisualResources: Bool = true, fractionLongNotes: Bool = true, graft: ChainGraft? = nil,
                visualCandidatesOverride: [VisualRegionCandidate]? = nil) {
        self.granularityTarget = granularityTarget
        self.buildDoctrine = buildDoctrine
        self.detectVisualResources = detectVisualResources
        self.fractionLongNotes = fractionLongNotes
        self.graft = graft
        self.visualCandidatesOverride = visualCandidatesOverride
    }
}

/// Il risultato di un'elaborazione riuscita.
public struct ChainResult {
    /// Il documento con le note agganciate e piazzate per la Lettura Continua.
    public let document: ScabopdfDocument
    /// Il documento grezzo (classificato, dopo l'eventuale innesto, prima dell'aggancio delle note): per le reti e i
    /// conteggi delle categorie, come il runner del banco.
    public let rawDocument: ScabopdfDocument
    /// Il flusso della Lettura Continua.
    public let content: PaginatedContent
    /// Il flusso della Dottrina Inline (§ 10), solo se il documento ha note e se richiesto.
    public let doctrineContent: PaginatedContent?
    /// Le decisioni della guardia delle risorse visive sul flusso della Lettura Continua.
    public let visualReport: VisualResourcesReport?
    /// Il referto dell'innesto (solo Mac), privo di testo.
    public let graftReport: [String]?
}

public enum ChainOutcome {
    case success(ChainResult)
    case cancelled
    /// Spiegazione in prosa italiana comprensibile (§ 12.10), mai il solo «errore».
    case failure(message: String)
}

public enum ProcessingChain {

    /// Il LIVELLO DI CURE della catena: l'ultima build dell'app per iPad che ha portato una cura della lettura da offrire
    /// ai libri già elaborati (§ 12.13). L'offerta «Lettura migliore disponibile» dell'iPad lo usa come `latestCureBuild`
    /// (sui dispositivi che possono riconoscere tabelle e figure), e il pacchetto del Mac lo porta: la lettura del Mac
    /// contiene le cure fino a qui. Si aggiorna nel giro che porta una cura nuova, una volta sola, qui.
    /// 55: le note lunghe frazionate anche quando l'iPad elabora da sé un PDF (giro del 2026-10-16).
    /// 56: le note spezzate fra pagine contigue ricucite sull'iPad, e i pezzi delle note lunghe chiusi a fine frase
    /// (giro «cura delle note», 2026-10-16 sera). Le letture del Mac la ricevono dal Mac (`curesFromTheMacOnly`).
    public static let cureLevel = 56

    /// Le cure che OGNI lettura preparata dal Mac contiene già, qualunque livello porti il suo pacchetto: il Mac fraziona
    /// le note lunghe dalla sua prima lettura (build 54, livello 53), quindi la cura 55 non manca a nessuna lettura arrivata
    /// dal Mac e l'offerta non la propone a quei libri (rielaborarli sull'iPad toglierebbe anzi l'innesto del Mac).
    public static let curesAlwaysInMacReadings: Set<Int> = [55]

    /// Le cure che una lettura arrivata dal Mac riceve SOLO dal Mac, con una lettura nuova preparata da una catena del Mac
    /// che le contiene, e non dalla rielaborazione sull'iPad: rielaborando sull'iPad la lettura del Mac perderebbe il suo
    /// innesto (la rietichettatura dell'indice analitico, nella politica predefinita del Mac) senza che l'offerta lo dica.
    /// 56: la ricucitura fra pagine contigue e i pezzi a fine frase (giro «cura delle note», 2026-10-16 sera, rilievo della
    /// revisione indipendente): la catena del Mac le contiene dalla sua versione con questo livello di cure. Confermato dal
    /// maintainer il 2026-10-17 (decisione 1 del giro «pulizia e rifinitura finale del capitolo note»): le letture del Mac
    /// si rifanno dal Mac aggiornato.
    public static let curesFromTheMacOnly: Set<Int> = [56]

    /// Le cure che cambiano anche la lettura dei TESTI NORMATIVI (AKN): solo queste si offrono a un testo normativo già
    /// importato (decisione 1 del maintainer, 2026-10-17). La catena AKN non passa dall'estrazione dei PDF; la tocca solo
    /// ciò che è condiviso con le note dei PDF.
    /// 56: i pezzi delle note lunghe chiusi a fine frase (lo spezzatore è uno, `notePieces`).
    public static let curesForAknActs: Set<Int> = [56]

    /// Elabora il PDF `fileURL` (una copia locale) sul thread chiamante. `onProgress` è chiamato sul thread chiamante;
    /// `isCancelled` è consultato alle tappe naturali (per pagina e ai confini di fase). `onVisualDetection` riceve
    /// l'esito del riconoscimento delle risorse visive appena c'è (registro, test), anche se poi si annulla.
    public static func run(
        fileURL: URL,
        sourceName: String,
        extractor: ProgressReportingPdfExtractor,
        options: ChainOptions = ChainOptions(),
        onProgress: (ChainProgress) -> Void,
        onVisualDetection: (VisualRegionDetector.Result) -> Void = { _ in },
        isCancelled: () -> Bool
    ) -> ChainOutcome {
        let uri = fileURL.absoluteString

        if isCancelled() { return .cancelled }
        onProgress(ChainProgress(phase: .opening, unitsDone: 0, unitsTotal: 0, fraction: 0))

        // ── Fase 1: estrazione (per pagina) ────────────────────────────────────────────────────────────────────
        var extraction: PdfExtraction
        do {
            guard let extracted = try extractor.extract(
                fromUri: uri,
                onPageExtracted: { done, total in
                    let denom = Double(2 * total + 1)
                    onProgress(ChainProgress(
                        phase: .extraction, unitsDone: done, unitsTotal: total,
                        fraction: denom > 0 ? Double(done) / denom : 0))
                },
                isCancelled: isCancelled
            ) else { return .cancelled }
            extraction = extracted
        } catch {
            return .failure(message: proseMessage(from: error))
        }
        let pageCount = extraction.pageCount

        // ── Fase 1-bis: risorse visive (tabelle e figure) ─────────────────────────────────────────────────────────
        // Sonda di tutte le pagine (millisecondi), modello sulle sole pagine scelte dal prefiltro. La barra resta dov'è
        // (fine dell'estrazione): l'avanzamento reale si legge nelle pagine del modello (unità della fase). La fase si
        // annuncia solo se il modello gira davvero. Il modello si rilascia qui, prima della classificazione, per non
        // sommare la sua memoria a quella del documento in costruzione.
        var visualCandidates: [VisualRegionCandidate] = []
        if let given = options.visualCandidatesOverride {
            visualCandidates = given
        } else if options.detectVisualResources {
            let parked = pageCount > 0 ? Double(pageCount) / Double(2 * pageCount + 1) : 0
            let detection = VisualRegionDetector.detect(
                pdfURL: fileURL,
                onModelPage: { done, total in
                    onProgress(ChainProgress(phase: .visualResources, unitsDone: done, unitsTotal: total, fraction: parked))
                },
                isCancelled: isCancelled)
            onVisualDetection(detection)
            visualCandidates = detection.candidates
        }
        if isCancelled() { return .cancelled }

        // ── Fase 2: classificazione (per pagina) ─────────────────────────────────────────────────────────────────
        guard var rawDocument = buildDocumentFromPdf(
            extraction,
            sourceName: sourceName,
            onPageClassified: { done, total in
                let denom = Double(2 * total + 1)
                onProgress(ChainProgress(
                    phase: .classification, unitsDone: done, unitsTotal: total,
                    fraction: denom > 0 ? Double(total + done) / denom : 1))
            },
            isCancelled: isCancelled
        ) else { return .cancelled }

        // ── Fase 2-bis (solo Mac): innesto dei verdetti del modello d'impaginazione ───────────────────────────────
        // Prima dell'aggancio delle note: lo spostamento di righe vale a livello d'estrazione (il documento si
        // ricostruisce con la stessa classificazione), le rietichettature a livello di nodo. Mai testo nuovo.
        var graftReport: [String]?
        if let graft = options.graft {
            let parked = pageCount > 0 ? Double(2 * pageCount) / Double(2 * pageCount + 1) : 0.5
            guard let out = graft.graft(
                extraction: extraction, rawDocument: rawDocument, pdfURL: fileURL, sourceName: sourceName,
                onPage: { done, total in
                    onProgress(ChainProgress(phase: .graft, unitsDone: done, unitsTotal: total, fraction: parked))
                },
                isCancelled: isCancelled) else { return .cancelled }
            extraction = out.extraction
            rawDocument = out.rawDocument
            graftReport = out.report
            if isCancelled() { return .cancelled }
        }

        // ── Aggancio e piazzamento delle note (capitolo NOTE) ────────────────────────────────────────────────────
        // Tra classificazione e impaginazione: aggancia ogni richiamo alla sua nota e riposiziona le note nell'albero
        // (brevi a fine frase, lunghe a fine sezione, § 7.3). Le non agganciate restano in posizione (lette, mai perse).
        // Richiede l'estrazione (i segnali di dimensione/parentesi degli span che la classificazione collassa).
        let document = bindAndPlaceNotes(rawDocument, extraction).document
        // Il documento ha note? (decide se Dottrina Inline è disponibile, § 10.3.)
        let hasNotes = rawDocument.structure.contains {
            $0.type == .NOTE || $0.type == .EDITORIAL_NOTE
        }

        // ── Fase 3: impaginazione del corpo (passo finale unico) ──────────────────────────────────────────────────
        if isCancelled() { return .cancelled }
        onProgress(ChainProgress(
            phase: .pagination, unitsDone: 0, unitsTotal: pageCount,
            fraction: pageCount > 0 ? Double(2 * pageCount) / Double(2 * pageCount + 1) : 0.5))

        let content: PaginatedContent
        var doctrineContent: PaginatedContent?
        let visualReport: VisualResourcesReport?
        do {
            let visual = visualCandidates.isEmpty ? nil : VisualInput(candidates: visualCandidates, extraction: extraction)
            let (built, report) = try ContinuousBodyBuilder.bodyPaginatedContentWithVisual(
                from: document, target: options.granularityTarget, visual: visual,
                fractionLongNotes: options.fractionLongNotes)
            content = built
            visualReport = report
            // Dottrina Inline (§ 10): SOLO se ci sono note E se `buildDoctrine` (per i volumi enormi lo si salta: è un
            // secondo flusso da decine di migliaia di segmenti). Stesso aggancio, piazzamento tutto-inline a fine frase
            // del richiamo (§ 10.2).
            if hasNotes && options.buildDoctrine {
                let doctrineDoc = bindAndPlaceNotes(
                    rawDocument, extraction, placement: .doctrineInline).document
                doctrineContent = try ContinuousBodyBuilder.bodyPaginatedContentWithVisual(
                    from: doctrineDoc, target: options.granularityTarget, visual: visual,
                    fractionLongNotes: options.fractionLongNotes).content
            }
        } catch {
            return .failure(message: proseMessage(from: error))
        }

        // Guardia di contenuto minima (§ 12.10/12.11): se il PDF ha pagine ma non se ne è ricavato ALCUN testo (tipico
        // delle scansioni di sole immagini senza livello di testo), aprire un lettore vuoto ingannerebbe l'utente.
        if pageCount > 0 && document.structure.isEmpty {
            return .failure(message:
                "Il PDF è stato aperto, ma non contiene testo leggibile: con ogni probabilità "
                + "è una scansione di immagini priva del livello di testo. ScaboPDF non può "
                + "renderlo accessibile. Serve un PDF con testo selezionabile (o un passaggio "
                + "di OCR prima dell'importazione).")
        }

        if isCancelled() { return .cancelled }
        onProgress(ChainProgress(phase: .pagination, unitsDone: pageCount, unitsTotal: pageCount, fraction: 1.0))
        return .success(ChainResult(document: document, rawDocument: rawDocument, content: content,
                                    doctrineContent: doctrineContent, visualReport: visualReport, graftReport: graftReport))
    }

    /// Riduce un errore a una spiegazione in prosa italiana. Gli errori dell'estrattore portano già un
    /// `localizedDescription` leggibile; il ripiego copre il caso generico.
    static func proseMessage(from error: Error) -> String {
        let described = (error as NSError).localizedDescription
        if !described.isEmpty {
            return described
        }
        return "Si è verificato un problema durante l'elaborazione del documento e non è stato "
            + "possibile completarla."
    }
}
