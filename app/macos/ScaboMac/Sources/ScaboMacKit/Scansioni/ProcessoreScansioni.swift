//
//  ProcessoreScansioni.swift
//  ScaboMacKit — l'elaborazione di un PDF con scansioni all'importazione del Mac (giro «migliorie del banco nelle app», 2026-11-21).
//
//  È `DocumentProcessor` (ScaboChain, quello dell'iPad: stesse opzioni, stessi esiti, stesso avanzamento, consegna sul main) con una sola
//  differenza: la catena passa da `CatenaScansioni.run`, così le tabelle e le figure viste sulle pagine lette arrivano alla catena come
//  candidate delle risorse visive. I PDF col testo non passano di qui (l'importazione usa `DocumentProcessor`, come l'iPad).
//

import Foundation
import ScaboChain
import ScaboCore

public final class ProcessoreScansioni: DocumentProcessing {
    private let estrattore: EstrattoreScansioni
    private let flag = CancellationFlag()
    private let workQueue = DispatchQueue(label: "scabopdf.scansioni-processing", qos: .userInitiated)
    private var didComplete = false
    /// L'esito dell'ultimo riconoscimento delle risorse visive della catena (come `DocumentProcessor`).
    public private(set) var lastVisualDetection: VisualRegionDetector.Result?

    public init(estrattore: EstrattoreScansioni) { self.estrattore = estrattore }

    /// Come `DocumentProcessor.visualResourcesMissingReason`: il riconoscimento non avvenuto per una ragione da riprovare.
    public var visualResourcesMissingReason: String? {
        guard let reason = lastVisualDetection?.skippedReason, VisualRegionDetector.retryableSkipReasons.contains(reason) else { return nil }
        return reason
    }

    public func process(fileURL: URL, sourceName: String, granularityTarget: Int, buildDoctrine: Bool,
                        onProgress: @escaping (DocumentProcessor.Progress) -> Void,
                        completion: @escaping (DocumentProcessor.Outcome) -> Void) {
        workQueue.async { [weak self] in
            guard let self else { return }
            func finish(_ outcome: DocumentProcessor.Outcome) {
                DispatchQueue.main.async {
                    guard !self.didComplete else { return }
                    self.didComplete = true
                    completion(outcome)
                }
            }
            let outcome = CatenaScansioni.run(
                fileURL: fileURL, sourceName: sourceName, extractor: self.estrattore, fonte: self.estrattore,
                options: ChainOptions(granularityTarget: granularityTarget, buildDoctrine: buildDoctrine, detectVisualResources: true),
                onProgress: { p in
                    let mapped = DocumentProcessor.Progress(p)
                    DispatchQueue.main.async { onProgress(mapped) }
                },
                onVisualDetection: { self.lastVisualDetection = $0 },
                isCancelled: { self.flag.isCancelled })
            switch outcome {
            case .success(let r): finish(.success(document: r.document, content: r.content, doctrineContent: r.doctrineContent))
            case .cancelled: finish(.cancelled)
            case .failure(let message): finish(.failure(message: message))
            }
        }
    }

    public func cancel() { flag.cancel() }
}
