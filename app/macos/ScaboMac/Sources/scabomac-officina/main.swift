//
//  scabomac-officina — riga di comando dell'officina Mac per le reti e il banco (giro «costruzione della linea
//  Mac», 2026-10-16). NON entra nell'app: l'app collega solo la libreria ScaboMacKit. Le uscite vanno nel laboratorio
//  fuori repo (contengono il testo dei volumi quando lo contengono gli artefatti del banco).
//
//    scabomac-officina fusore-caso --casi FILE.json --base DIR --out DIR [--caso ID]
//        Esegue i casi del banco (`casi.json`, formato del fusore Python) con il fusore SWIFT di ScaboCore: legge
//        `<base>/artifacts/<stem>.scabopdf.json|.extraction.json` e i verdetti delle cartelle del caso, scrive
//        `<out>/<id>/document_fuso.json|extraction_fusa.json`, `operazioni.json` e `referto_fusione.txt`.
//    scabomac-officina confronta-fusi --tipo documento|estrazione --a FILE --b FILE
//        Decodifica due artefatti fusi (per esempio Python e Swift) e dice se sono identici come dati; se no, dove
//        (id dei nodi o pagine e righe), mai il testo.
//    scabomac-officina catena --lista LISTA.json --corpus DIR --out DIR [--politica giro|spenta|banco] [--granularita N]
//                             [--estrazioni DIR] [--regioni DIR] [--solo STEM] [--salva-catture DIR] [--lettura]
//        La catena DEL MAC (quella dell'app: MacProcessor) sui volumi della lista: dal vivo (estrazione PDFKit di macOS,
//        modello d'impaginazione sul Mac) oppure, con `--estrazioni`/`--regioni`, dalle catture di un simulatore (stesso
//        formato del banco). Scrive per volume `<stem>.rv.reading.json` (lettura completa, risorse visive comprese) e
//        `<stem>.reading.json` (senza gli elementi «risorsa visiva»), nel formato del runner della rete, più
//        `<stem>.officina.json` (referto dell'innesto, privo di testo) e una riga di riepilogo per volume. Con
//        `--salva-catture` scrive anche l'estrazione di PDFKit di macOS (`<stem>.extraction.json`) e le regioni del
//        modello sul Mac (`<stem>.regions.json`), nel formato delle catture del simulatore (confronto canonico). Con
//        `--lettura` scrive anche `<stem>.lettura.json`: la lettura INTERA nella forma della cache dell'iPad (i due flussi,
//        la mappa delle pagine, l'albero, la granularità; chiavi ordinate), per il confronto byte per byte con la lettura
//        che l'iPad prepara da sé (giro «uniformità della lettura», 2026-10-16).
//    scabomac-officina pacchetto --pdf FILE.pdf --out FILE.scabolettura [--politica giro|spenta|banco]
//        Prepara e scrive il pacchetto della lettura come l'app (senza annotazioni).
//    scabomac-officina verdetti-confronta --pdf VOLUME.pdf --dir CARTELLA --prefisso P
//        Confronta i verdetti DAL VIVO del modulo (`analyzeWithRegionTexts` sulla pagina del volume intero, sul Mac) con i
//        verdetti su file del laboratorio (`<P>NNN.pdf.json`): etichette, ordini, riquadri e testo normalizzato per pagina.
//

import Foundation
import PDFKit
import ScaboChain
import ScaboCore
import ScaboMacKit
import ScaboPageStructure

func arg(_ name: String) -> String? {
    let a = CommandLine.arguments
    guard let i = a.firstIndex(of: "--" + name), i + 1 < a.count else { return nil }
    return a[i + 1]
}
func fail(_ msg: String, code: Int32 = 2) -> Never {
    FileHandle.standardError.write((msg + "\n").data(using: .utf8)!)
    exit(code)
}
func say(_ msg: String) { print(msg); fflush(stdout) }   // riga per riga anche se l'uscita va in un file

let encoder: JSONEncoder = { let e = JSONEncoder(); e.outputFormatting = [.sortedKeys]; return e }()

func describe(_ op: FusoreOperation) -> [String: Any] {
    switch op {
    case .relabel(let node, let from, let to, let reason): return ["op": "relabel", "node": node, "from": from, "to": to, "reason": reason]
    case .merge(let head, let tail, let reason): return ["op": "merge", "head": head, "tail": tail, "reason": reason]
    case .split(let node, let at, let h, let t, let minted, let reason):
        return ["op": "split", "node": node, "at_char": at, "head_type": h, "tail_type": t, "minted": minted, "reason": reason]
    case .stitchMultipage(let a, let b, let n, let from):
        return ["op": "stitch_multipage", "page_a": a, "page_b": b, "lines_moved": n, "from_index": from]
    case .reorderPage(let page, let lines, let moved): return ["op": "reorder_page", "page": page, "lines": lines, "moved": moved]
    }
}

func writeOps(_ ops: [FusoreOperation], _ referto: [String], to dir: URL) throws {
    let data = try JSONSerialization.data(withJSONObject: ops.map(describe), options: [.sortedKeys])
    try data.write(to: dir.appendingPathComponent("operazioni.json"))
    try (referto.joined(separator: "\n") + "\n").write(to: dir.appendingPathComponent("referto_fusione.txt"), atomically: true, encoding: .utf8)
}

let mode = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ""

switch mode {
case "fusore-caso":
    guard let casiPath = arg("casi"), let basePath = arg("base"), let outPath = arg("out") else {
        fail("uso: fusore-caso --casi FILE.json --base DIR --out DIR [--caso ID]")
    }
    let specs: [BenchCase]
    do { specs = try JSONDecoder().decode([BenchCase].self, from: Data(contentsOf: URL(fileURLWithPath: casiPath))) }
    catch { fail("casi illeggibili: \(error)") }
    let wanted = arg("caso")
    let base = URL(fileURLWithPath: basePath), out = URL(fileURLWithPath: outPath)
    var rc: Int32 = 0
    for spec in specs where wanted == nil || spec.id == wanted {
        let dir = out.appendingPathComponent(spec.id)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let t0 = Date()
        do {
            switch try BenchCaseRunner.run(spec, base: base) {
            case .document(let o):
                try encoder.encode(o.value).write(to: dir.appendingPathComponent("document_fuso.json"))
                try writeOps(o.operations, ["== caso \(spec.id) (fusore Swift) =="] + o.referto, to: dir)
                say("\(spec.id): documento, \(o.operations.count) operazioni, \(o.words) parole, \(String(format: "%.1f", Date().timeIntervalSince(t0))) s")
            case .extraction(let o):
                try encoder.encode(o.value).write(to: dir.appendingPathComponent("extraction_fusa.json"))
                try writeOps(o.operations, ["== caso \(spec.id) (fusore Swift) =="] + o.referto, to: dir)
                say("\(spec.id): estrazione, \(o.operations.count) operazioni, \(o.words) parole, \(String(format: "%.1f", Date().timeIntervalSince(t0))) s")
            }
        } catch {
            say("\(spec.id): FALLITO — \(error)")
            rc = 1
        }
    }
    exit(rc)

case "confronta-fusi":
    guard let tipo = arg("tipo"), let a = arg("a"), let b = arg("b") else { fail("uso: confronta-fusi --tipo documento|estrazione --a FILE --b FILE") }
    do {
        let da = try Data(contentsOf: URL(fileURLWithPath: a)), db = try Data(contentsOf: URL(fileURLWithPath: b))
        if tipo == "documento" {
            let x = try JSONDecoder().decode(ScabopdfDocument.self, from: da), y = try JSONDecoder().decode(ScabopdfDocument.self, from: db)
            if x == y { say("IDENTICI (documento, \(x.structure.count) nodi di primo livello)"); exit(0) }
            func flat(_ n: [NodeDict]) -> [NodeDict] { n.flatMap { [$0] + flat($0.children) } }
            let fx = flat(x.structure), fy = flat(y.structure)
            say("DIVERSI: nodi \(fx.count) contro \(fy.count)")
            var shown = 0
            for (p, q) in zip(fx, fy) where p != q && shown < 10 {
                say("  \(p.id)/\(q.id): tipo \(p.type.rawValue)/\(q.type.rawValue), pagina \(p.page_index)/\(q.page_index), testo uguale: \(p.text == q.text), regime \(p.length_category?.rawValue ?? "-")/\(q.length_category?.rawValue ?? "-")")
                shown += 1
            }
            exit(1)
        } else {
            let x = try JSONDecoder().decode(PdfExtraction.self, from: da), y = try JSONDecoder().decode(PdfExtraction.self, from: db)
            if x == y { say("IDENTICHE (estrazione, \(x.pages.count) pagine)"); exit(0) }
            say("DIVERSE")
            for (p, q) in zip(x.pages, y.pages) where p != q {
                say("  pagina \(p.pageIndex + 1): righe \(p.lines.count)/\(q.lines.count)")
            }
            exit(1)
        }
    } catch { fail("confronto impossibile: \(error)") }

case "verdetti-confronta":
    guard let pdfPath = arg("pdf"), let dir = arg("dir"), let prefix = arg("prefisso") else {
        fail("uso: verdetti-confronta --pdf VOLUME.pdf --dir CARTELLA --prefisso P")
    }
    guard #available(macOS 14.0, *) else { fail("serve macOS 14") }
    guard let pdf = PDFDocument(url: URL(fileURLWithPath: pdfPath)) else { fail("PDF illeggibile") }
    let model: HeronLayoutModel
    do { model = try HeronLayoutModel.bundled(computeUnits: .all) } catch { fail("modello non caricato: \(error)") }
    let analyzer = PageStructureAnalyzer(model: model)
    struct Rec: Decodable { let items: [LayoutVerdictItem] }
    let names = ((try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? []).filter { $0.hasPrefix(prefix) && $0.hasSuffix(".pdf.json") }.sorted()
    var same = 0, differ = 0
    for name in names {
        let digits = name.dropFirst(prefix.count).prefix { $0.isNumber }
        guard let page = Int(digits), let lab = try? JSONDecoder().decode(Rec.self, from: Data(contentsOf: URL(fileURLWithPath: dir).appendingPathComponent(name))),
              let p = pdf.page(at: page - 1), let (layout, texts, _) = try? analyzer.analyzeWithRegionTexts(page: p, pageIndex: page - 1) else {
            say("\(name): non confrontabile"); differ += 1; continue
        }
        let live = zip(layout.regions, texts).map { LayoutVerdictItem(label: $0.label, order: $0.order, bbox: $0.bbox, text: $1) }
        let labelsOK = live.map { "\($0.order):\($0.label)" } == lab.items.map { "\($0.order):\($0.label)" }
        // Testo identico carattere per carattere (più severo dell'ancoraggio del fusore, che normalizza).
        let textsOK = live.map { $0.text ?? "" } == lab.items.map { $0.text ?? "" }
        let bboxOK = live.count == lab.items.count && zip(live, lab.items).allSatisfy { a, b in
            guard let x = a.bbox, let y = b.bbox, x.count == 4, y.count == 4 else { return a.bbox == b.bbox }
            return zip(x, y).allSatisfy { abs($0 - $1) <= 0.11 }
        }
        if labelsOK && textsOK && bboxOK { same += 1 } else {
            differ += 1
            say("\(name): etichette \(labelsOK ? "uguali" : "DIVERSE") (\(live.count) contro \(lab.items.count)), testi \(textsOK ? "uguali" : "DIVERSI"), riquadri \(bboxOK ? "uguali" : "DIVERSI")")
        }
    }
    say("pagine con verdetti identici: \(same) su \(names.count); diverse: \(differ)")
    exit(differ == 0 ? 0 : 1)

case "catena":
    guard let lista = arg("lista"), let corpus = arg("corpus"), let outDir = arg("out") else {
        fail("uso: catena --lista LISTA.json --corpus DIR --out DIR [--politica giro|spenta|banco] [--granularita N] [--estrazioni DIR] [--regioni DIR]")
    }
    let policy: OfficinaPolicy = arg("politica") == "spenta" ? .spenta : (arg("politica") == "banco" ? .banco : .giro)
    let target = arg("granularita").flatMap(Int.init)
    let vols: [String]
    do { vols = try JSONDecoder().decode([String].self, from: Data(contentsOf: URL(fileURLWithPath: lista))) }
    catch { fail("lista illeggibile: \(error)") }
    let only = arg("solo")
    var rc: Int32 = 0
    for v in vols {
        let stem = String(v.dropLast(4))
        if let only, !stem.hasSuffix(only) { continue }
        let pdf = URL(fileURLWithPath: corpus).appendingPathComponent(v)
        var extractor: ProgressReportingPdfExtractor = PdfKitExtractor()
        var candidates: [VisualRegionCandidate]? = nil
        if let e = arg("estrazioni") {
            let path = URL(fileURLWithPath: e).appendingPathComponent(stem + ".extraction.json")
            guard let ex = try? JSONDecoder().decode(PdfExtraction.self, from: Data(contentsOf: path)) else {
                say("\(stem): estrazione catturata illeggibile"); rc = 1; continue
            }
            extractor = CapturedExtractor(extraction: ex)
        }
        if let r = arg("regioni") {
            let path = URL(fileURLWithPath: r).appendingPathComponent(stem + ".regions.json")
            guard let c = try? JSONDecoder().decode([VisualRegionCandidate].self, from: Data(contentsOf: path)) else {
                say("\(stem): regioni catturate illeggibili"); rc = 1; continue
            }
            candidates = c
        }
        let t0 = Date()
        let recorder = RecordingExtractor(extractor)
        var detected: [VisualRegionCandidate]? = nil
        let outcome = autoreleasepool {
            MacProcessor.process(pdfURL: pdf, policy: policy, granularityTarget: target, extractor: recorder,
                                 visualCandidates: candidates, onVisualDetection: { detected = $0.candidates })
        }
        if let dir = arg("salva-catture") {
            let base = URL(fileURLWithPath: dir).appendingPathComponent(stem)
            try? FileManager.default.createDirectory(at: base.deletingLastPathComponent(), withIntermediateDirectories: true)
            let sorted = JSONEncoder()
            sorted.outputFormatting = [.sortedKeys]
            if let e = recorder.recorded { try? JSONEncoder().encode(e).write(to: URL(fileURLWithPath: base.path + ".extraction.json")) }
            if let c = detected ?? candidates { try? sorted.encode(c).write(to: URL(fileURLWithPath: base.path + ".regions.json")) }
            recorder.recorded = nil
        }
        guard case .ready(let r) = outcome else { say("\(stem): FALLITA"); rc = 1; continue }
        let base = URL(fileURLWithPath: outDir).appendingPathComponent(stem)
        try? FileManager.default.createDirectory(at: base.deletingLastPathComponent(), withIntermediateDirectories: true)
        let segs = r.reading.content.pages.flatMap { $0.segments }
        do {
            try RunnerReading.encode(label: r.fileName, categories: r.rawCategories, segments: segs)
                .write(to: URL(fileURLWithPath: base.path + ".rv.reading.json"))
            try RunnerReading.encode(label: r.fileName, categories: r.rawCategories, segments: segs.filter { $0.visualResource == nil })
                .write(to: URL(fileURLWithPath: base.path + ".reading.json"))
            try encoder.encode(r.report).write(to: URL(fileURLWithPath: base.path + ".officina.json"))
            if CommandLine.arguments.contains("--lettura") {
                try encoder.encode(r.reading).write(to: URL(fileURLWithPath: base.path + ".lettura.json"))
            }
        } catch { say("\(stem): scrittura fallita"); rc = 1; continue }
        say("\(stem): \(segs.count) segmenti, \(r.visualResources) risorse, modello su \(r.report.modelPages.count) pagine, "
            + "ricuciture \(r.report.stitches.count), rietichettature \(r.report.relabels), \(String(format: "%.1f", Date().timeIntervalSince(t0))) s")
    }
    exit(rc)

case "pacchetto":
    guard let pdfPath = arg("pdf"), let out = arg("out") else { fail("uso: pacchetto --pdf FILE.pdf --out FILE.scabolettura") }
    let policy: OfficinaPolicy = arg("politica") == "spenta" ? .spenta : (arg("politica") == "banco" ? .banco : .giro)
    guard case .ready(let r) = MacProcessor.process(pdfURL: URL(fileURLWithPath: pdfPath), policy: policy) else { fail("elaborazione fallita", code: 1) }
    do {
        let data = try MacProcessor.package(r, producer: .init(app: Testi.nomeApp, version: "officina", build: "0",
                                                               system: MacProcessor.producer().system, cureLevel: ProcessingChain.cureLevel))
        try data.write(to: URL(fileURLWithPath: out))
        let segs = r.reading.content.pages.flatMap { $0.segments }
        try RunnerReading.encode(label: r.fileName, categories: r.rawCategories, segments: segs)
            .write(to: URL(fileURLWithPath: out + ".reading.json"))
        // La lettura intera nella forma della cache (flussi, mappa, albero, granularità), per il confronto d'andata e
        // ritorno con ciò che l'iPad scrive nella sua cache dopo averla adottata.
        let sorted = JSONEncoder()
        sorted.outputFormatting = [.sortedKeys]
        try sorted.encode(r.reading).write(to: URL(fileURLWithPath: out + ".lettura.json"))
        say("pacchetto: \(data.count) byte, \(segs.count) segmenti, \(r.visualResources) risorse, granularità \(r.reading.contentTarget), "
            + "Dottrina \(r.reading.doctrineContent != nil ? "sì" : "no"), Consultazione \(r.reading.quickConsultTree != nil ? "sì" : "no"); "
            + "controlli in \(out).reading.json e \(out).lettura.json")
    } catch { fail("pacchetto non scritto: \(error)", code: 1) }

default:
    fail("uso: scabomac-officina <fusore-caso|confronta-fusi|verdetti-confronta|catena|pacchetto> …")
}

/// Un estrattore che conserva l'estrazione restituita (per salvarla accanto alla lettura: reti).
final class RecordingExtractor: ProgressReportingPdfExtractor {
    let inner: ProgressReportingPdfExtractor
    var recorded: PdfExtraction?
    init(_ inner: ProgressReportingPdfExtractor) { self.inner = inner }
    func extract(fromUri uri: String, onPageExtracted: (Int, Int) -> Void, isCancelled: () -> Bool) throws -> PdfExtraction? {
        let e = try inner.extract(fromUri: uri, onPageExtracted: onPageExtracted, isCancelled: isCancelled)
        recorded = e
        return e
    }
}

/// Un estrattore che restituisce un'estrazione già catturata (reti: la catena del Mac sugli stessi dati del simulatore).
struct CapturedExtractor: ProgressReportingPdfExtractor {
    let extraction: PdfExtraction
    func extract(fromUri uri: String, onPageExtracted: (Int, Int) -> Void, isCancelled: () -> Bool) throws -> PdfExtraction? {
        for p in 0..<extraction.pageCount { onPageExtracted(p + 1, extraction.pageCount) }
        return extraction
    }
}

/// La lettura nel formato del runner della rete (stessi campi e stessa codifica: pretty + chiavi ordinate).
enum RunnerReading {
    struct SegmentDump: Codable {
        let role: String
        let lengthCategory: String
        let acousticIntro: String
        let text: String
        let page: Int?
        var visual: VisualResourcePayload? = nil
    }
    struct ReadingOut: Codable {
        let label: String
        let categories: [String: Int]
        let segments: [SegmentDump]
    }
    static func encode(label: String, categories: [String: Int], segments: [ContentSegment]) throws -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try enc.encode(ReadingOut(label: label, categories: categories, segments: segments.map {
            SegmentDump(role: $0.role, lengthCategory: $0.lengthCategory, acousticIntro: $0.acousticIntro, text: $0.text,
                        page: $0.sourcePage, visual: $0.visualResource)
        }))
    }
}
