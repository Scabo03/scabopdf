//
//  BenchFromRequestTests.swift
//  ScaboPageStructureTests
//
//  Banco a richiesta (come `RealPdfBenchTests` dell'app): legge un FILE di richiesta, non variabili
//  d'ambiente, perché il processo del simulatore non vede l'ambiente della shell. Senza richiesta il test
//  si salta: i PDF del corpus stanno FUORI dal repo e non entrano mai nei test.
//
//  Richiesta (`/tmp/scabo_layout_request.json`, percorso alternativo in SCABO_LAYOUT_REQUEST):
//    {"model": "<.mlmodelc o .mlpackage>", "compute": "all", "outDir": "<cartella>",
//     "mode": "pages" | "volume", "pdfs": ["<percorso assoluto>", …], "pages": {"<pdf>": [0, 3, …]}}
//  Uscita: per "pages" un `<nome>.pdf.json` per PDF (prima pagina) come la riga di comando, più
//  `_timings.json`; per "volume" un `<nome>.layout.json` per PDF con le pagine richieste (o tutte).
//  Tutto privo di testo.
//

import XCTest
import PDFKit
import ImageIO
#if canImport(UIKit)
import UIKit
#endif
@testable import ScaboPageStructure

final class BenchFromRequestTests: XCTestCase {

    struct Request: Decodable {
        let model: String
        let compute: String?
        let outDir: String
        let mode: String?
        let pdfs: [String]
        let pages: [String: [Int]]?
    }
    struct PageRecord: Encodable { let file: String; let layout: PageLayout }
    struct TimingRecord: Encodable { let page: String; let index: Int; let timings: PageTimings; let nRegions: Int }
    struct TimingsFile: Encodable { let model: Double; let platform: String; let pages: [TimingRecord] }
    struct VolumeRecord: Encodable { let file: String; let pageCount: Int; let modelLoadSeconds: Double; let compute: String; let platform: String; let pages: [PageLayout]; let timings: [TimingRecord] }

    func test_layoutBench_fromRequest() throws {
        let path = ProcessInfo.processInfo.environment["SCABO_LAYOUT_REQUEST"] ?? "/tmp/scabo_layout_request.json"
        guard let data = FileManager.default.contents(atPath: path) else {
            throw XCTSkip("nessuna richiesta in \(path): banco saltato (i PDF del corpus non stanno nel repo)")
        }
        guard #available(iOS 17.0, macOS 14.0, *) else { throw XCTSkip("serve iOS 17 / macOS 14") }
        let req = try JSONDecoder().decode(Request.self, from: data)
        let units = LayoutComputeUnits(rawValue: req.compute ?? "all") ?? .all
        let cache = URL(fileURLWithPath: req.outDir).appendingPathComponent("_cache_modello")
        let model = try HeronLayoutModel(modelURL: URL(fileURLWithPath: req.model), cacheDir: cache, computeUnits: units)
        let analyzer = PageStructureAnalyzer(model: model)
        try FileManager.default.createDirectory(atPath: req.outDir, withIntermediateDirectories: true)
        let enc = JSONEncoder(); enc.outputFormatting = [.sortedKeys]
        #if os(iOS)
        let platform = "iOS \(UIDevice.current.systemVersion) \(UIDevice.current.model)"
        #else
        let platform = "macOS \(ProcessInfo.processInfo.operatingSystemVersionString)"
        #endif
        if req.mode == "detect-images" {
            // `pdfs` qui elenca immagini PNG 640×640 già rese (dal Mac): stesso ingresso, calcolo a confronto.
            var out: [String: [[String: Any]]] = [:]
            for png in req.pdfs {
                guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: png) as CFURL, nil), let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { continue }
                out[(png as NSString).lastPathComponent] = try model._detectionsForCheck(image: img).map { ["label": $0.0, "confidence": $0.1, "bbox": $0.2] }
            }
            try JSONSerialization.data(withJSONObject: out, options: [.sortedKeys]).write(to: URL(fileURLWithPath: req.outDir).appendingPathComponent("_detect_images.json"))
            return
        }
        if req.mode == "render-digest" {
            var out: [String: String] = [:]
            for pdf in req.pdfs {
                guard let doc = PDFDocument(url: URL(fileURLWithPath: pdf)), let page = doc.page(at: 0) else { continue }
                out[(pdf as NSString).lastPathComponent] = _renderedInputDigest(page: page) ?? "?"
            }
            try enc.encode(out).write(to: URL(fileURLWithPath: req.outDir).appendingPathComponent("_render_digest.json"))
            return
        }
        if (req.mode ?? "pages") == "pages" {
            var timings: [TimingRecord] = []
            for pdf in req.pdfs {
                let name = (pdf as NSString).lastPathComponent
                guard let doc = PDFDocument(url: URL(fileURLWithPath: pdf)), let page = doc.page(at: 0) else { XCTFail("illeggibile \(name)"); continue }
                let (layout, t) = try analyzer.analyze(page: page, pageIndex: 0)
                try enc.encode(PageRecord(file: name, layout: layout)).write(to: URL(fileURLWithPath: req.outDir).appendingPathComponent(name + ".json"))
                timings.append(TimingRecord(page: name, index: 0, timings: t, nRegions: layout.regions.count))
            }
            try enc.encode(TimingsFile(model: model.loadSeconds, platform: platform, pages: timings))
                .write(to: URL(fileURLWithPath: req.outDir).appendingPathComponent("_timings.json"))
        } else {
            for pdf in req.pdfs {
                let name = (pdf as NSString).lastPathComponent
                guard let doc = PDFDocument(url: URL(fileURLWithPath: pdf)) else { XCTFail("illeggibile \(name)"); continue }
                let wanted = req.pages?[pdf] ?? Array(0..<doc.pageCount)
                var pages: [PageLayout] = []; var timings: [TimingRecord] = []
                for i in wanted where i >= 0 && i < doc.pageCount {
                    guard let page = doc.page(at: i) else { continue }
                    let (layout, t) = try autoreleasepool { try analyzer.analyze(page: page, pageIndex: i) }
                    pages.append(layout); timings.append(TimingRecord(page: "\(i)", index: i, timings: t, nRegions: layout.regions.count))
                }
                try enc.encode(VolumeRecord(file: name, pageCount: doc.pageCount, modelLoadSeconds: model.loadSeconds, compute: units.rawValue, platform: platform, pages: pages, timings: timings))
                    .write(to: URL(fileURLWithPath: req.outDir).appendingPathComponent((name as NSString).deletingPathExtension + ".layout.json"))
            }
        }
    }
}
