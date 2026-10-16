//
//  MacProcessor.swift
//  ScaboMacKit
//
//  Il PDF → la lettura che il Mac manda all'iPad (giro «costruzione della linea Mac», 2026-10-16). Usa la catena
//  condivisa (`ProcessingChain`, la stessa dell'iPad) con le due opzioni dell'officina — innesto dei verdetti del modello
//  (`OfficinaGraft`) e frazionamento delle note lunghe ricucite — e prepara la lettura nella STESSA FORMA della cache
//  dell'app per iPad (`PackagedReading`: flussi, albero della Consultazione Rapida, mappa delle pagine, granularità),
//  con la stessa regola dei volumi enormi (granularità 1.200, niente Dottrina Inline né Consultazione Rapida oltre le
//  1.500 pagine): l'iPad la adotta così com'è, senza rielaborarla (§ 12.12, decisione 3).
//

import CoreGraphics
import Foundation
import ScaboChain
import ScaboCore

/// La lettura pronta sul Mac, da mandare all'iPad.
public struct MacReadingReady {
    public let title: String
    public let fileName: String
    public let sha256: String
    public let pageCount: Int
    public let reading: PackagedReading
    /// Righe brevi, prive di testo, su ciò che l'officina ha fatto in più (vanno nell'intestazione del pacchetto).
    public let workshop: [String]
    public let report: OfficinaReport
    public let segments: Int
    public let visualResources: Int
    public let warnings: [String]
    public let seconds: Double
    /// Conteggio dei tipi dei nodi di primo livello del documento grezzo (come il runner della rete).
    public let rawCategories: [String: Int]
    /// Perché il riconoscimento di tabelle e figure non è avvenuto (o non del tutto) per una ragione da riprovare (il
    /// modello non si è caricato); nil se è avvenuto. Va nel pacchetto: l'iPad segna il libro e propone di riprovare.
    public var visualResourcesSkipped: String? = nil
}

public enum MacProcessingOutcome {
    case ready(MacReadingReady)
    case cancelled
    case failure(String)
}

public enum MacProcessor {

    /// Le informazioni sull'app che produce il pacchetto (nome, versione, build, sistema, livello di cure della catena).
    public static func producer(bundle: Bundle = .main) -> ReadingPackageHeader.Producer {
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        let v = ProcessInfo.processInfo.operatingSystemVersion
        let system = v.patchVersion == 0 ? "macOS \(v.majorVersion).\(v.minorVersion)"
            : "macOS \(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
        return .init(app: Testi.nomeApp, version: version, build: build, system: system, cureLevel: ProcessingChain.cureLevel)
    }

    /// Elabora il PDF sul thread chiamante. `granularityTarget == nil` → la regola dell'app (400; 1.200 oltre le 1.500
    /// pagine). `policy` decide l'innesto (`.spenta` = la lettura dell'iPad con il frazionamento delle note).
    public static func process(
        pdfURL: URL,
        policy: OfficinaPolicy = .giro,
        granularityTarget: Int? = nil,
        extractor: ProgressReportingPdfExtractor = PdfKitExtractor(),
        visualCandidates: [VisualRegionCandidate]? = nil,
        onProgress: (ChainProgress) -> Void = { _ in },
        onVisualDetection: (VisualRegionDetector.Result) -> Void = { _ in },
        isCancelled: () -> Bool = { false }
    ) -> MacProcessingOutcome {
        let t0 = Date()
        let fileName = pdfURL.lastPathComponent
        let title = (fileName as NSString).deletingPathExtension
        guard let sha = try? DocumentFingerprint.sha256Hex(ofFileAt: pdfURL) else {
            return .failure("Il PDF scelto non si riesce a leggere dal disco. Controlla che il file esista e riprova.")
        }
        let pageCount = CGPDFDocument(pdfURL as CFURL)?.numberOfPages ?? 0
        let large = ReadingAssembly.isLarge(pageCount: pageCount)
        let target = granularityTarget ?? (large ? ReadingAssembly.largeDocumentGranularity : DEFAULT_GRANULARITY_TARGET)
        let graft = OfficinaGraft(policy: policy)
        var visualDetection: VisualRegionDetector.Result?
        let outcome = ProcessingChain.run(
            fileURL: pdfURL, sourceName: fileName, extractor: extractor,
            options: ChainOptions(granularityTarget: target, buildDoctrine: !large, detectVisualResources: true,
                                  fractionLongNotes: true, graft: policy.isOff ? nil : graft,
                                  visualCandidatesOverride: visualCandidates),
            onProgress: onProgress,
            onVisualDetection: { result in visualDetection = result; onVisualDetection(result) },
            isCancelled: isCancelled)
        switch outcome {
        case .cancelled:
            return .cancelled
        case .failure(let message):
            return .failure(message)
        case .success(let r):
            let pageMap = ReadingAssembly.buildPageMap(r.document, content: r.content, doctrineContent: r.doctrineContent)
            let tree = large ? nil : ReadingAssembly.quickConsultTreeIfAvailable(r.document)
            let reading = PackagedReading(content: r.content, pageMap: pageMap, doctrineContent: large ? nil : r.doctrineContent,
                                          quickConsultTree: tree, contentTarget: target)
            let segs = r.content.pages.flatMap { $0.segments }
            var categories: [String: Int] = [:]
            for n in r.rawDocument.structure { categories[n.type.rawValue, default: 0] += 1 }
            let skipped = visualDetection?.skippedReason.flatMap {
                VisualRegionDetector.retryableSkipReasons.contains($0) ? $0 : nil
            }
            return .ready(MacReadingReady(
                title: title, fileName: fileName, sha256: sha, pageCount: pageCount, reading: reading,
                workshop: r.graftReport ?? [], report: graft.report, segments: segs.count,
                visualResources: segs.filter { $0.visualResource != nil }.count,
                warnings: r.document.warnings, seconds: Date().timeIntervalSince(t0), rawCategories: categories,
                visualResourcesSkipped: skipped))
        }
    }

    /// Il pacchetto da mandare all'iPad. `annotations` nil → non incluse.
    public static func package(_ ready: MacReadingReady, annotations: PackagedAnnotations? = nil,
                               producer: ReadingPackageHeader.Producer = MacProcessor.producer()) throws -> Data {
        try ReadingPackage.write(
            producer: producer,
            source: .init(sha256: ready.sha256, fileName: ready.fileName, title: ready.title, pageCount: ready.pageCount),
            reading: ready.reading, cacheFormat: ReadingAssembly.cacheFormatVersion, workshop: ready.workshop,
            stitchedNotes: ready.report.stitches.count, relabeledIndexLines: ready.report.relabels,
            visualResourcesSkipped: ready.visualResourcesSkipped,
            annotations: annotations)
    }
}
