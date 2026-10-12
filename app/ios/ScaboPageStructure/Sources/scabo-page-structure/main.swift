//
//  scabo-page-structure — riga di comando del modulo d'impaginazione, per le reti e le misure sul Mac.
//  NON entra nell'app (l'app collega solo la libreria). Scrive SOLO dati privi di testo.
//
//    scabo-page-structure pages  --model M [--cache DIR] [--compute all|cpuOnly|cpuAndGPU|cpuAndNeuralEngine]
//                                --out DIR pdf...
//        Analizza la PRIMA pagina di ciascun PDF (il banco delle 34 pagine è fatto di PDF una-pagina) e
//        scrive <out>/<nome>.pdf.json + <out>/_timings.json.
//    scabo-page-structure volume --model M [--cache DIR] [--compute …] [--pages LISTA|all] --out FILE.json pdf
//        Analizza le pagine di un volume (tutte o la LISTA 0-based separata da virgole) e scrive un solo JSON.
//    scabo-page-structure probe  --out FILE.json pdf
//        Sonda grafica (prefiltro) su ogni pagina del volume: immagini, tracciati, righe da tabella.
//

import Foundation
#if os(macOS)
import PDFKit
import ImageIO
import ScaboPageStructure

func arg(_ name: String) -> String? {
    let a = CommandLine.arguments
    guard let i = a.firstIndex(of: "--" + name), i + 1 < a.count else { return nil }
    return a[i + 1]
}
func positional() -> [String] {
    var out: [String] = []; var skip = false
    for (i, a) in CommandLine.arguments.enumerated() where i >= 2 {
        if skip { skip = false; continue }
        if a.hasPrefix("--") { skip = true; continue }
        out.append(a)
    }
    return out
}
func fail(_ msg: String) -> Never { FileHandle.standardError.write((msg + "\n").data(using: .utf8)!); exit(2) }
func stderr(_ msg: String) { FileHandle.standardError.write((msg + "\n").data(using: .utf8)!) }

let encoder: JSONEncoder = { let e = JSONEncoder(); e.outputFormatting = [.sortedKeys]; return e }()

let mode = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ""

@available(macOS 14.0, *)
func loadModel() -> HeronLayoutModel {
    guard let m = arg("model") else { fail("manca --model") }
    let units = LayoutComputeUnits(rawValue: arg("compute") ?? "all") ?? .all
    let cache = arg("cache").map { URL(fileURLWithPath: $0) }
    do { return try HeronLayoutModel(modelURL: URL(fileURLWithPath: m), cacheDir: cache, computeUnits: units) }
    catch { fail("modello non caricato: \(error)") }
}

struct PageRecord: Codable { let file: String; let layout: PageLayout }
struct TimingRecord: Codable { let page: String; let index: Int; let timings: PageTimings; let nRegions: Int }
struct VolumeRecord: Codable { let file: String; let pageCount: Int; let modelLoadSeconds: Double; let compute: String; let pages: [PageLayout]; let timings: [TimingRecord] }

switch mode {
case "pages":
    guard #available(macOS 14.0, *) else { fail("serve macOS 14") }
    guard let outDir = arg("out") else { fail("manca --out") }
    try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
    let model = loadModel()
    stderr("modello caricato in \(String(format: "%.2f", model.loadSeconds)) s")
    let analyzer = PageStructureAnalyzer(model: model)
    var timings: [TimingRecord] = []
    for path in positional() {
        let name = (path as NSString).lastPathComponent
        guard let doc = PDFDocument(url: URL(fileURLWithPath: path)), let page = doc.page(at: 0) else { stderr("illeggibile: \(name)"); continue }
        do {
            let (layout, t) = try analyzer.analyze(page: page, pageIndex: 0)
            try encoder.encode(PageRecord(file: name, layout: layout)).write(to: URL(fileURLWithPath: outDir).appendingPathComponent(name + ".json"))
            timings.append(TimingRecord(page: name, index: 0, timings: t, nRegions: layout.regions.count))
            stderr("\(name): \(layout.nDetections) rilevazioni → \(layout.nClusters) cluster → \(layout.regions.count) regioni in \(String(format: "%.3f", t.total)) s (inferenza \(String(format: "%.3f", t.infer)))")
        } catch { stderr("errore su \(name): \(error)") }
    }
    let rec: [String: AnyCodableTimings] = ["timings": AnyCodableTimings(model: model.loadSeconds, pages: timings)]
    try? encoder.encode(rec).write(to: URL(fileURLWithPath: outDir).appendingPathComponent("_timings.json"))

case "volume":
    guard #available(macOS 14.0, *) else { fail("serve macOS 14") }
    guard let out = arg("out"), let path = positional().first else { fail("uso: volume --model M --out FILE pdf") }
    let model = loadModel()
    let analyzer = PageStructureAnalyzer(model: model)
    guard let doc = PDFDocument(url: URL(fileURLWithPath: path)) else { fail("PDF illeggibile") }
    var wanted: [Int] = Array(0..<doc.pageCount)
    if let list = arg("pages"), list != "all" { wanted = list.split(separator: ",").compactMap { Int($0) }.filter { $0 >= 0 && $0 < doc.pageCount } }
    var pages: [PageLayout] = []; var timings: [TimingRecord] = []
    for i in wanted {
        guard let page = doc.page(at: i) else { continue }
        do {
            let (layout, t) = try autoreleasepool { try analyzer.analyze(page: page, pageIndex: i) }
            pages.append(layout); timings.append(TimingRecord(page: "\(i)", index: i, timings: t, nRegions: layout.regions.count))
        } catch { stderr("errore pagina \(i): \(error)") }
    }
    let rec = VolumeRecord(file: (path as NSString).lastPathComponent, pageCount: doc.pageCount, modelLoadSeconds: model.loadSeconds,
                           compute: arg("compute") ?? "all", pages: pages, timings: timings)
    do { try encoder.encode(rec).write(to: URL(fileURLWithPath: out)) } catch { fail("scrittura fallita: \(error)") }
    stderr("\((path as NSString).lastPathComponent): \(pages.count) pagine analizzate")

case "probe":
    guard let out = arg("out"), let path = positional().first else { fail("uso: probe --out FILE pdf") }
    guard let doc = CGPDFDocument(URL(fileURLWithPath: path) as CFURL) else { fail("PDF illeggibile") }
    struct ProbeRecord: Codable { let page: Int; let seconds: Double; let profile: PageGraphicsProfile }
    struct ProbeVolume: Codable { let file: String; let pageCount: Int; let pages: [ProbeRecord] }
    var recs: [ProbeRecord] = []
    for i in 0..<doc.numberOfPages {
        guard let page = doc.page(at: i + 1) else { continue }
        let t0 = Date()
        let prof = autoreleasepool { PageGraphicsProbe.profile(of: page, collectBoxes: CommandLine.arguments.contains("--boxes")) }
        recs.append(ProbeRecord(page: i, seconds: Date().timeIntervalSince(t0), profile: prof))
    }
    do { try encoder.encode(ProbeVolume(file: (path as NSString).lastPathComponent, pageCount: doc.numberOfPages, pages: recs)).write(to: URL(fileURLWithPath: out)) } catch { fail("scrittura fallita: \(error)") }
    stderr("\((path as NSString).lastPathComponent): sonda su \(recs.count) pagine")

case "candidates":
    // Candidati per ScaboCore da un'impaginazione di volume (`volume`) e dalla sonda con i riquadri (`probe --boxes 1`).
    guard let lp = arg("layout"), let pp = arg("probe"), let out = arg("out") else { fail("uso: candidates --layout L.json --probe P.json --out C.json") }
    struct LayoutVolume: Codable { let pages: [PageLayout] }
    struct ProbeRec: Codable { let page: Int; let profile: PageGraphicsProfile }
    struct ProbeVol: Codable { let pages: [ProbeRec] }
    do {
        let layout = try JSONDecoder().decode(LayoutVolume.self, from: Data(contentsOf: URL(fileURLWithPath: lp)))
        let probe = try JSONDecoder().decode(ProbeVol.self, from: Data(contentsOf: URL(fileURLWithPath: pp)))
        var boxes: [Int: [[Double]]] = [:]
        for p in probe.pages { boxes[p.page] = p.profile.paintedBoxes }
        let cands = layout.pages.flatMap { VisualCandidateBuilder.candidates(from: $0, paintedBoxes: boxes[$0.pageIndex] ?? []) }
        try encoder.encode(cands).write(to: URL(fileURLWithPath: out))
        stderr("candidati: \(cands.count)")
    } catch { fail("candidates: \(error)") }

case "select":
    // Le pagine che il prefiltro manda al modello, da una sonda di volume (`probe`).
    guard let pp = arg("probe") else { fail("uso: select --probe P.json") }
    struct ProbeRec2: Codable { let page: Int; let profile: PageGraphicsProfile }
    struct ProbeVol2: Codable { let pages: [ProbeRec2] }
    do {
        let probe = try JSONDecoder().decode(ProbeVol2.self, from: Data(contentsOf: URL(fileURLWithPath: pp)))
        let ordered = probe.pages.sorted { $0.page < $1.page }
        let sel = PageGraphicsProbe.pagesForModel(ordered.map { $0.profile }).map { ordered[$0].page }
        print(String(data: try encoder.encode(sel), encoding: .utf8)!)
    } catch { fail("select: \(error)") }

case "render-digest":
    var out: [String: String] = [:]
    for path in positional() {
        guard let doc = PDFDocument(url: URL(fileURLWithPath: path)), let page = doc.page(at: 0) else { continue }
        out[(path as NSString).lastPathComponent] = _renderedInputDigest(page: page) ?? "?"
    }
    print(String(data: try! encoder.encode(out), encoding: .utf8)!)

case "render-png":
    guard let outDir = arg("out") else { fail("manca --out") }
    try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
    for path in positional() {
        guard let doc = PDFDocument(url: URL(fileURLWithPath: path)), let page = doc.page(at: 0), let png = _renderedInputPNG(page: page) else { continue }
        try? png.write(to: URL(fileURLWithPath: outDir).appendingPathComponent((path as NSString).lastPathComponent + ".png"))
    }

case "detect-images":
    guard #available(macOS 14.0, *) else { fail("serve macOS 14") }
    let model = loadModel()
    var out: [String: [[String: Any]]] = [:]
    for path in positional() {
        guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil), let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { continue }
        let dets = (try? model._detectionsForCheck(image: img)) ?? []
        out[(path as NSString).lastPathComponent] = dets.map { ["label": $0.0, "confidence": $0.1, "bbox": $0.2] }
    }
    let data = try! JSONSerialization.data(withJSONObject: out, options: [.sortedKeys])
    FileManager.default.createFile(atPath: arg("out") ?? "/dev/stdout", contents: data)

case "ro-check":
    // Ordine del porto sugli elementi pre-ordine di docling (`elements_pre_ro`, `page_size`, `ro_order` nei JSON del banco).
    var results: [String: [String: [Int]]] = [:]
    for path in positional() {
        guard let data = FileManager.default.contents(atPath: path), let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let els = j["elements_pre_ro"] as? [[String: Any]], let ps = j["page_size"] as? [Double] else { continue }
        let W = ps[0], H = ps[1]
        let elems = els.compactMap { e -> (cid: Int, label: String, pageNo: Int, l: Double, t: Double, r: Double, b: Double)? in
            guard let bb = e["bbox_tl"] as? [Double], let cid = e["cid"] as? Int, let lab = e["label"] as? String else { return nil }
            return (cid: cid, label: lab, pageNo: (e["page_no"] as? Int) ?? 1, l: bb[0], t: bb[1], r: bb[2], b: bb[3])
        }
        results[(path as NSString).lastPathComponent] = ["swift_order": _readingOrderCheck(elements: elems, pageWidth: W, pageHeight: H), "docling_order": j["ro_order"] as? [Int] ?? []]
    }
    print(String(data: try! encoder.encode(results), encoding: .utf8)!)

default:
    stderr("uso: scabo-page-structure <pages|volume|probe|ro-check> …")
    exit(2)
}

struct AnyCodableTimings: Codable { let model: Double; let pages: [TimingRecord] }
#else
print("scabo-page-structure: solo macOS")
#endif
