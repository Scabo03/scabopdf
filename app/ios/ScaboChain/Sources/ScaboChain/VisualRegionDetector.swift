//
//  VisualRegionDetector.swift
//  ScaboChain (fino al 2026-10-16 nel bersaglio ScaboApp; condiviso con l'app Mac, logica invariata)
//
//  Il RICONOSCIMENTO DELLE RISORSE VISIVE durante l'elaborazione di un PDF (`LAYER2_PRODUCT_DECISIONS.md` § 7.9,
//  `docs/RISORSE_VISIVE.md`). Tre passi, tutti sul dispositivo, nessun dato esce:
//
//  1. la SONDA grafica di ogni pagina (immagini, filetti, riquadri dal flusso di contenuto: decimi di millisecondo
//     a pagina, un codice da 2.600 pagine in meno di mezzo secondo sul Mac);
//  2. il PREFILTRO sceglie le sole pagine con grafica che si stacca dalla pagina tipica del volume (sul corpus:
//     il 2,5 % delle pagine; i due codici, 29 e 16 pagine su 2.600);
//  3. il MODELLO d'impaginazione (Heron in Core ML, modulo `ScaboPageStructure`) gira solo su quelle pagine e ne
//     ricava i candidati (tabelle e figure, con didascalia e vicini nell'ordine di lettura) per la guardia di
//     ScaboCore, che decide che cosa diventa risorsa visiva.
//
//  Il modello si carica solo se il prefiltro sceglie almeno una pagina, e si rilascia alla fine (memoria). Su iOS
//  anteriori al 17 il modello non si carica: nessuna risorsa, l'elaborazione prosegue come prima. Qualunque errore
//  del modello su una pagina salta quella pagina: il riconoscimento non deve mai fermare un'importazione.
//
//  PROTEZIONE DELLA MEMORIA (giro «costruzione della linea Mac», 2026-10-16). Prima di caricare il modello si guarda
//  quanta memoria il sistema concede ancora all'app (`os_proc_available_memory`, iOS): sotto la soglia il modello non
//  si carica; fra una pagina e l'altra, sotto una soglia più bassa, si ferma (le pagine già viste restano). In entrambi
//  i casi, e quando il modello non si carica, l'elaborazione prosegue senza (le altre) risorse visive e l'esito lo dice
//  (`skippedReason` fra `retryableSkipReasons`): l'app segna il libro, e l'offerta di rielaborazione gli propone di
//  riprovare. Le soglie e il fallimento del caricamento si simulano nei test con `testing`.
//

import Foundation
import CoreGraphics
import PDFKit
import os
import ScaboCore
import ScaboPageStructure

/// Fuori dal main actor per costruzione: gira sulla coda di elaborazione di `DocumentProcessor`.
nonisolated public enum VisualRegionDetector {

    /// Esito del riconoscimento (conteggi e tempi per il registro; i candidati per la guardia).
    public struct Result {
        public var candidates: [VisualRegionCandidate] = []
        public var pageCount = 0
        public var modelPages: [Int] = []
        public var analyzedPages = 0
        public var probeSeconds = 0.0
        public var modelLoadSeconds = 0.0
        public var modelSeconds = 0.0
        /// Perché il modello non è girato (nessuna pagina scelta, sistema anteriore a iOS 17, modello assente, errore).
        public var skippedReason: String?
        /// Pagine scelte dal prefiltro ma ruotate: il modello non le vede (righe, regioni e ritaglio non sono ancora
        /// trattati nello spazio ruotato; nei 52 volumi della rete le pagine ruotate sono 0).
        public var rotatedPagesSkipped = 0
        /// Vero se il modello non si è caricato con le unità di calcolo chieste e gira sulla sola CPU (in fp32 stesso
        /// risultato: 561/563 regioni identiche sull'host, scarti alla quarta cifra delle confidenze).
        public var cpuFallback = false

        public init() {}
    }

    private static let log = Logger(subsystem: "com.scabo.scabopdf", category: "risorse-visive")

    /// Memoria che il sistema deve concedere ancora all'app per caricare il modello (byte). Il modello fp32 pesa 164 MB
    /// e in uso arriva a circa 360 MB (misura del giro «struttura nativa» sul Mac); il resto è margine per il rendering
    /// delle pagine e per l'elaborazione che continua.
    public static let minimumAvailableMemoryToLoad: UInt64 = 600 * 1024 * 1024
    /// Sotto questa soglia, fra una pagina e l'altra, il modello si ferma (le pagine già viste restano).
    public static let minimumAvailableMemoryPerPage: UInt64 = 250 * 1024 * 1024

    /// Le ragioni per cui il riconoscimento non è avvenuto (o non del tutto) e conviene riprovarlo più avanti: il libro
    /// si segna e l'offerta di rielaborazione glielo propone. Le altre (nessuna pagina con grafica, sistema anteriore a
    /// iOS 17, annullato, PDF non leggibile) non si riprovano.
    public static let memoryBeforeLoadReason = "memoria insufficiente per il modello"
    public static let memoryDuringModelReason = "memoria insufficiente durante il riconoscimento"
    public static let modelUnavailableReason = "modello non disponibile"
    public static let retryableSkipReasons: Set<String> = [memoryBeforeLoadReason, memoryDuringModelReason, modelUnavailableReason]

    /// Ganci per le prove: fallimento simulato del caricamento del modello e memoria disponibile simulata (byte), prima
    /// del caricamento e fra una pagina e l'altra del modello.
    public struct TestHooks: Sendable {
        public var failModelLoad = false
        public var availableMemoryBytes: UInt64?
        public var availableMemoryDuringModelBytes: UInt64?
        public init(failModelLoad: Bool = false, availableMemoryBytes: UInt64? = nil, availableMemoryDuringModelBytes: UInt64? = nil) {
            self.failModelLoad = failModelLoad
            self.availableMemoryBytes = availableMemoryBytes
            self.availableMemoryDuringModelBytes = availableMemoryDuringModelBytes
        }
    }
    /// Solo prove e scenari di sviluppo (si imposta prima di elaborare; in produzione resta vuoto).
    nonisolated(unsafe) public static var testing = TestHooks()

    /// La memoria che il sistema concede ancora all'app (byte), o nil se non la dice (Mac; simulatore senza limite:
    /// `os_proc_available_memory` vale 0).
    public static func availableMemory(duringModel: Bool = false) -> UInt64? {
        if duringModel, let simulated = testing.availableMemoryDuringModelBytes { return simulated }
        if let simulated = testing.availableMemoryBytes { return simulated }
        #if os(iOS)
        let v = os_proc_available_memory()
        return v > 0 ? UInt64(v) : nil
        #else
        return nil
        #endif
    }

    private struct SimulatedModelFailure: Error {}

    /// Le pagine scelte senza quelle ruotate (rotazione non multipla di 360°). Pura, per le prove.
    public static func excludingRotated(_ pages: [Int], rotation: (Int) -> Int32) -> [Int] {
        pages.filter { ((Int(rotation($0)) % 360) + 360) % 360 == 0 }
    }

    /// Riconosce i candidati del PDF. `onModelPage(fatte, totali)` riporta l'avanzamento sulle pagine mandate al
    /// modello; `isCancelled` è consultato a ogni pagina.
    public static func detect(
        pdfURL: URL,
        computeUnits: LayoutComputeUnits = .all,
        onModelPage: (Int, Int) -> Void = { _, _ in },
        isCancelled: () -> Bool = { false }
    ) -> Result {
        var result = Result()
        guard let cgDoc = CGPDFDocument(pdfURL as CFURL) else { result.skippedReason = "PDF non leggibile"; return result }
        let n = cgDoc.numberOfPages
        result.pageCount = n
        // Sotto iOS 17 il modello non gira: nemmeno la sonda (sarebbe lavoro inutile a ogni importazione).
        guard #available(iOS 17.0, macOS 14.0, *) else { result.skippedReason = "sistema anteriore a iOS 17"; return result }
        // 1-2. Sonda dell'intero documento e prefiltro.
        let t0 = Date()
        var profiles: [PageGraphicsProfile] = []
        profiles.reserveCapacity(n)
        for i in 0..<n {
            if i % 64 == 0, isCancelled() { result.skippedReason = "annullato"; return result }
            let profile: PageGraphicsProfile = autoreleasepool {
                guard let page = cgDoc.page(at: i + 1) else { return PageGraphicsProfile() }
                return PageGraphicsProbe.profile(of: page, collectBoxes: true)
            }
            profiles.append(profile)
        }
        result.probeSeconds = Date().timeIntervalSince(t0)
        let chosen = PageGraphicsProbe.pagesForModel(profiles)
        result.modelPages = Self.excludingRotated(chosen) { cgDoc.page(at: $0 + 1)?.rotationAngle ?? 0 }
        result.rotatedPagesSkipped = chosen.count - result.modelPages.count
        guard !result.modelPages.isEmpty else { result.skippedReason = "nessuna pagina con grafica"; return result }
        // 3. Modello sulle sole pagine scelte, se la memoria lo consente.
        guard let pdfDoc = PDFDocument(url: pdfURL) else { result.skippedReason = "PDF non leggibile"; return result }
        if let free = availableMemory(), free < minimumAvailableMemoryToLoad {
            result.skippedReason = memoryBeforeLoadReason
            Self.log.error("riconoscimento di tabelle e figure non eseguito: memoria disponibile \(free / 1_048_576, privacy: .public) MB")
            return result
        }
        // La fase si annuncia qui (0 di N): da questo momento il modello lavora davvero.
        onModelPage(0, result.modelPages.count)
        let model: HeronLayoutModel
        do {
            if testing.failModelLoad { throw SimulatedModelFailure() }
            model = try HeronLayoutModel.bundled(computeUnits: computeUnits)
        } catch {
            // Un secondo tentativo sulla sola CPU (per esempio se la GPU non ha risorse in quel momento).
            Self.log.error("modello d'impaginazione non caricato (\(computeUnits.rawValue, privacy: .public)): \(error.localizedDescription, privacy: .public)")
            guard computeUnits != .cpuOnly, !testing.failModelLoad, let cpu = try? HeronLayoutModel.bundled(computeUnits: .cpuOnly) else {
                // Il libro resta senza risorse visive, l'elaborazione prosegue; l'app segna il libro e l'offerta di
                // rielaborazione gli propone di riprovare (giro del 2026-10-16: prima non si riproponeva).
                result.skippedReason = modelUnavailableReason
                Self.log.error("riconoscimento di tabelle e figure non eseguito: modello non disponibile")
                return result
            }
            model = cpu
            result.cpuFallback = true
        }
        result.modelLoadSeconds = model.loadSeconds
        let analyzer = PageStructureAnalyzer(model: model)
        let t1 = Date()
        for (k, index) in result.modelPages.enumerated() {
            if isCancelled() { result.skippedReason = "annullato"; break }
            if let free = availableMemory(duringModel: true), free < minimumAvailableMemoryPerPage {
                result.skippedReason = memoryDuringModelReason
                Self.log.error("riconoscimento fermato a pagina \(k, privacy: .public) di \(result.modelPages.count, privacy: .public): memoria \(free / 1_048_576, privacy: .public) MB")
                break
            }
            autoreleasepool {
                guard let page = pdfDoc.page(at: index), let (layout, _) = try? analyzer.analyze(page: page, pageIndex: index) else { return }
                result.analyzedPages += 1
                let records = VisualCandidateBuilder.candidates(from: layout, paintedBoxes: profiles[index].paintedBoxes)
                result.candidates.append(contentsOf: records.map(Self.candidate))
            }
            onModelPage(k + 1, result.modelPages.count)
        }
        result.modelSeconds = Date().timeIntervalSince(t1)
        return result
    }

    /// Dal record del modulo al tipo di ScaboCore (stesse chiavi, campo per campo).
    static func candidate(_ r: VisualCandidateRecord) -> VisualRegionCandidate {
        VisualRegionCandidate(pageIndex: r.pageIndex, label: r.label, bbox: r.bbox, confidence: r.confidence,
                              captionBBox: r.captionBBox, pageWidth: r.pageWidth, pageHeight: r.pageHeight,
                              previousTextBBox: r.previousTextBBox, nextTextBBox: r.nextTextBBox,
                              graphicsInside: r.graphicsInside)
    }
}
