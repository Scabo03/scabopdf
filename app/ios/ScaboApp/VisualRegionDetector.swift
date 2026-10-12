//
//  VisualRegionDetector.swift
//  ScaboApp
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

import Foundation
import CoreGraphics
import PDFKit
import os
import ScaboCore
import ScaboPageStructure

/// Fuori dal main actor per costruzione: gira sulla coda di elaborazione di `DocumentProcessor`.
nonisolated enum VisualRegionDetector {

    /// Esito del riconoscimento (conteggi e tempi per il registro; i candidati per la guardia).
    struct Result {
        var candidates: [VisualRegionCandidate] = []
        var pageCount = 0
        var modelPages: [Int] = []
        var analyzedPages = 0
        var probeSeconds = 0.0
        var modelLoadSeconds = 0.0
        var modelSeconds = 0.0
        /// Perché il modello non è girato (nessuna pagina scelta, sistema anteriore a iOS 17, modello assente, errore).
        var skippedReason: String?
        /// Pagine scelte dal prefiltro ma ruotate: il modello non le vede (righe, regioni e ritaglio non sono ancora
        /// trattati nello spazio ruotato; nei 52 volumi della rete le pagine ruotate sono 0).
        var rotatedPagesSkipped = 0
        /// Vero se il modello non si è caricato con le unità di calcolo chieste e gira sulla sola CPU (in fp32 stesso
        /// risultato: 561/563 regioni identiche sull'host, scarti alla quarta cifra delle confidenze).
        var cpuFallback = false
    }

    private static let log = Logger(subsystem: "com.scabo.scabopdf", category: "risorse-visive")

    /// Le pagine scelte senza quelle ruotate (rotazione non multipla di 360°). Pura, per le prove.
    static func excludingRotated(_ pages: [Int], rotation: (Int) -> Int32) -> [Int] {
        pages.filter { ((Int(rotation($0)) % 360) + 360) % 360 == 0 }
    }

    /// Riconosce i candidati del PDF. `onModelPage(fatte, totali)` riporta l'avanzamento sulle pagine mandate al
    /// modello; `isCancelled` è consultato a ogni pagina.
    static func detect(
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
        // 3. Modello sulle sole pagine scelte.
        guard let pdfDoc = PDFDocument(url: pdfURL) else { result.skippedReason = "PDF non leggibile"; return result }
        // La fase si annuncia qui (0 di N): da questo momento il modello lavora davvero.
        onModelPage(0, result.modelPages.count)
        let model: HeronLayoutModel
        do { model = try HeronLayoutModel.bundled(computeUnits: computeUnits) } catch {
            // Un secondo tentativo sulla sola CPU (per esempio se la GPU non ha risorse in quel momento).
            Self.log.error("modello d'impaginazione non caricato (\(computeUnits.rawValue, privacy: .public)): \(error.localizedDescription, privacy: .public)")
            guard computeUnits != .cpuOnly, let cpu = try? HeronLayoutModel.bundled(computeUnits: .cpuOnly) else {
                // Il libro resta senza risorse visive (dichiarato in docs/RISORSE_VISIVE.md § 7): nessuna offerta
                // automatica di rielaborazione: se il modello non parte, riproporla girerebbe a vuoto.
                result.skippedReason = "modello non disponibile"
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
