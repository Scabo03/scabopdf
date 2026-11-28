//
//  CatenaScansioni.swift
//  ScaboMacKit — LA CATENA CONDIVISA SU UNA SCANSIONE, CON LE TABELLE VISTE (giro «migliorie del banco nelle app», 2026-11-21;
//  LAYER2 § 12.16, decisione 23; variante D del giro 2 del banco OCR, docs/BANCO_OCR.md § 18.2).
//
//  Sulle pagine col testo le tabelle e le figure le trova il riconoscimento delle risorse visive della catena (sonda grafica, prefiltro,
//  modello sulle pagine scelte: `VisualRegionDetector`, ScaboChain). Su una pagina scansionata la sonda vede solo l'immagine della pagina:
//  le tabelle le vede invece il modello d'impaginazione che la via delle scansioni già esegue sull'immagine della pagina letta
//  (`EstrattoreScansioni`). Qui quelle regioni arrivano alla catena come candidate delle risorse visive, insieme a quelle che il
//  riconoscimento della catena trova sulle altre pagine: la GUARDIA è quella condivisa con l'iPad (ScaboCore `VisualResources`), che
//  decide che cosa diventa risorsa visiva, la mette nel flusso in aggiunta al testo (il testo della tabella resta dov'era) e la fa
//  annunciare con le stesse parole e gli stessi rotori dell'iPad. La catena condivisa non cambia: la si chiama con le candidate già
//  pronte (`ChainOptions.visualCandidatesOverride`), dopo aver letto le pagine.
//
//  Quando non c'è nulla da aggiungere (miglioria spenta, nessuna pagina letta, nessuna tabella né figura vista) la catena gira
//  esattamente come prima, col riconoscimento al suo posto: stesse uscite al byte.
//

import Foundation
import ScaboChain
import ScaboCore

/// Chi, dopo l'estrazione, sa quali tabelle e figure ha visto sulle pagine che ha letto.
public protocol FonteRisorseScansioni: AnyObject {
    /// Le candidate delle risorse visive viste sulle pagine lette e messe nell'estrazione (spazio della pagina dell'estrazione).
    var candidateRisorse: [VisualRegionCandidate] { get }
    /// Le pagine (0-based) lette dal lettore e messe nell'estrazione.
    var pagineLette: [Int] { get }
    /// L'innesto delle regioni di Heron sulle pagine lette (`InnestoScansioni`), da mettere davanti all'innesto `poi` della catena;
    /// nil se non c'è nulla da innestare (giro «scansioni, ricerca e build», 2026-11-28).
    func innesto(poi: ChainGraft?) -> ChainGraft?
}

public extension FonteRisorseScansioni {
    func innesto(poi: ChainGraft?) -> ChainGraft? { nil }
}

public enum CatenaScansioni {

    /// Un estrattore che restituisce l'estrazione già fatta (stesso avanzamento per pagina della catena, come le reti).
    struct EstrazioneFatta: ProgressReportingPdfExtractor {
        let estrazione: PdfExtraction
        func extract(fromUri uri: String, onPageExtracted: (Int, Int) -> Void, isCancelled: () -> Bool) throws -> PdfExtraction? {
            for p in 0..<estrazione.pageCount { onPageExtracted(p + 1, estrazione.pageCount) }
            return estrazione
        }
    }

    /// Un estrattore che ripete l'errore dell'estrazione: la catena lo dice con le sue parole.
    struct EstrazioneFallita: ProgressReportingPdfExtractor {
        let errore: Error
        func extract(fromUri uri: String, onPageExtracted: (Int, Int) -> Void, isCancelled: () -> Bool) throws -> PdfExtraction? {
            throw errore
        }
    }

    /// Le candidate per la catena: quelle del riconoscimento sulle pagine NON lette dal lettore, poi quelle viste sulle pagine lette.
    static func unisci(rilevate: [VisualRegionCandidate], scansioni: [VisualRegionCandidate], pagineLette: [Int]) -> [VisualRegionCandidate] {
        let lette = Set(pagineLette)
        return rilevate.filter { !lette.contains($0.pageIndex) } + scansioni
    }

    /// La catena condivisa (`ProcessingChain.run`) su un PDF con pagine lette dall'estrattore delle scansioni. `estrattore` è quello
    /// che la catena chiamerebbe (anche avvolto, per esempio da un registratore); `fonte` dà, dopo l'estrazione, le tabelle e le figure
    /// viste. Stessi avanzamenti, stesse fasi e stesso esito della catena; in più, le risorse visive delle pagine lette.
    public static func run(
        fileURL: URL,
        sourceName: String,
        extractor: ProgressReportingPdfExtractor,
        fonte: FonteRisorseScansioni,
        options: ChainOptions,
        onProgress: (ChainProgress) -> Void,
        onVisualDetection: (VisualRegionDetector.Result) -> Void = { _ in },
        isCancelled: () -> Bool
    ) -> ChainOutcome {
        // Le candidate già date (reti) o il riconoscimento spento: la catena com'è.
        guard options.visualCandidatesOverride == nil, options.detectVisualResources else {
            return ProcessingChain.run(fileURL: fileURL, sourceName: sourceName, extractor: extractor, options: options,
                                       onProgress: onProgress, onVisualDetection: onVisualDetection, isCancelled: isCancelled)
        }
        if isCancelled() { return .cancelled }
        // Fase 1: l'estrazione, con l'avanzamento che la catena darebbe (apertura, poi pagina per pagina).
        onProgress(ChainProgress(phase: .opening, unitsDone: 0, unitsTotal: 0, fraction: 0))
        let estrazione: PdfExtraction
        do {
            guard let e = try extractor.extract(
                fromUri: fileURL.absoluteString,
                onPageExtracted: { done, total in
                    let denom = Double(2 * total + 1)
                    onProgress(ChainProgress(phase: .extraction, unitsDone: done, unitsTotal: total,
                                             fraction: denom > 0 ? Double(done) / denom : 0))
                },
                isCancelled: isCancelled) else { return .cancelled }
            estrazione = e
        } catch {
            return ProcessingChain.run(fileURL: fileURL, sourceName: sourceName, extractor: EstrazioneFallita(errore: error),
                                       options: options, onProgress: { _ in }, onVisualDetection: onVisualDetection, isCancelled: isCancelled)
        }
        // Dalla seconda passata della catena non si ripetono l'apertura e l'estrazione (già dette).
        let avanti: (ChainProgress) -> Void = { p in
            if p.phase != .opening && p.phase != .extraction { onProgress(p) }
        }
        // L'innesto delle regioni di Heron sulle pagine lette (miglioria `colonne` e `righeDiTabella`), davanti a quello della catena.
        var opzioni = options
        if let innesto = fonte.innesto(poi: options.graft) { opzioni.graft = innesto }
        let scansioni = fonte.candidateRisorse
        guard !scansioni.isEmpty else {
            // Nessuna tabella né figura da aggiungere: la catena con il suo riconoscimento, come prima.
            return ProcessingChain.run(fileURL: fileURL, sourceName: sourceName, extractor: EstrazioneFatta(estrazione: estrazione),
                                       options: opzioni, onProgress: avanti, onVisualDetection: onVisualDetection, isCancelled: isCancelled)
        }
        // Fase 1-bis: lo stesso riconoscimento della catena (stesse opzioni, stesso avanzamento), poi le candidate delle pagine lette.
        let pagine = estrazione.pageCount
        let parcheggiata = pagine > 0 ? Double(pagine) / Double(2 * pagine + 1) : 0
        let rilevate = VisualRegionDetector.detect(
            pdfURL: fileURL,
            onModelPage: { done, total in
                onProgress(ChainProgress(phase: .visualResources, unitsDone: done, unitsTotal: total, fraction: parcheggiata))
            },
            isCancelled: isCancelled)
        onVisualDetection(rilevate)
        if isCancelled() { return .cancelled }
        var o = opzioni
        o.visualCandidatesOverride = unisci(rilevate: rilevate.candidates, scansioni: scansioni, pagineLette: fonte.pagineLette)
        return ProcessingChain.run(fileURL: fileURL, sourceName: sourceName, extractor: EstrazioneFatta(estrazione: estrazione),
                                   options: o, onProgress: avanti, onVisualDetection: { _ in }, isCancelled: isCancelled)
    }
}
