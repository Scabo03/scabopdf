//
//  PageStructureAnalyzer.swift
//  ScaboPageStructure
//
//  La pagina intera: resa → Heron (Core ML) → righe PDFKit come celle → post-processing di docling →
//  assemblaggio (`PageAssembleModel`) → ordine di lettura a regole → fusioni di testo spezzato →
//  associazione delle didascalie. Porto fedele del ciclo `run` del prototipo del laboratorio
//  («struttura nativa», `HeronNative/main.swift`), con l'uscita resa PRIVA DI TESTO.
//

import Foundation
import PDFKit

/// Una regione riconosciuta sulla pagina. Nessun testo: tipo, riquadro, confidenza, ordine.
public struct LayoutRegion: Codable, Equatable, Sendable {
    /// Posizione nell'ordine di lettura della pagina (0-based), come `order` del prototipo.
    public var order: Int
    /// Etichetta di docling (`table`, `picture`, `caption`, `text`, `section_header`, …).
    public var label: String
    /// `[l, t, r, b]` in punti, origine alto-sinistra, relativa al cropBox; arrotondata al decimo.
    public var bbox: [Double]
    /// Confidenza del modello, arrotondata a 1e-4.
    public var confidence: Double
    /// 1 = elemento di primo livello; 2 = figlio di una figura o di un contenitore.
    public var level: Int
    /// Id del cluster genitore per i figli (come `child_of` del prototipo), altrimenti `nil`.
    public var childOf: Int?
    /// Id del cluster di questa regione.
    public var clusterId: Int
    /// Numero di righe PDFKit assegnate alla regione dal post-processing.
    public var nCells: Int
    /// Indici (nell'elenco pre-ordine) degli elementi di testo fusi in questo dal predittore.
    public var merged: [Int]
    /// Per tabelle, figure e codice: l'`order` della didascalia associata da docling, se c'è.
    public var captionOrder: Int?

    public init(order: Int, label: String, bbox: [Double], confidence: Double, level: Int, childOf: Int?,
                clusterId: Int, nCells: Int, merged: [Int], captionOrder: Int? = nil) {
        self.order = order; self.label = label; self.bbox = bbox; self.confidence = confidence; self.level = level
        self.childOf = childOf; self.clusterId = clusterId; self.nCells = nCells; self.merged = merged
        self.captionOrder = captionOrder
    }
}

/// L'impaginazione riconosciuta di una pagina. Priva di testo.
public struct PageLayout: Codable, Equatable, Sendable {
    /// Indice 0-based della pagina nel documento.
    public var pageIndex: Int
    /// Dimensioni del cropBox in punti.
    public var width: Double
    public var height: Double
    public var regions: [LayoutRegion]
    public var nDetections: Int
    public var nClusters: Int
    public var nCells: Int

    public init(pageIndex: Int, width: Double, height: Double, regions: [LayoutRegion], nDetections: Int, nClusters: Int, nCells: Int) {
        self.pageIndex = pageIndex; self.width = width; self.height = height; self.regions = regions
        self.nDetections = nDetections; self.nClusters = nClusters; self.nCells = nCells
    }
}

/// Tempi di una pagina, in secondi (misure; non fanno parte del verdetto).
public struct PageTimings: Codable, Sendable {
    public var total: Double, render: Double, infer: Double, cells: Double, post: Double, order: Double
}

@available(iOS 17.0, macOS 14.0, *)
public final class PageStructureAnalyzer {
    public let model: HeronLayoutModel

    public init(model: HeronLayoutModel) { self.model = model }

    /// Riconosce l'impaginazione di una pagina. Il testo delle righe resta in memoria (post-processing e
    /// fusioni) e non esce: l'uscita porta solo tipi, riquadri, confidenze e ordini.
    public func analyze(page: PDFPage, pageIndex: Int) throws -> (PageLayout, PageTimings) {
        let t0 = Date()
        guard let (img, W, H) = HeronPageRenderer.renderPage(page) else {
            let box = page.bounds(for: .cropBox)
            return (PageLayout(pageIndex: pageIndex, width: Double(box.width), height: Double(box.height), regions: [], nDetections: 0, nClusters: 0, nCells: 0),
                    PageTimings(total: 0, render: 0, infer: 0, cells: 0, post: 0, order: 0))
        }
        let tRender = Date().timeIntervalSince(t0)
        let t1 = Date(); let dets = try model.predict(image: img, pageW: W, pageH: H); let tInfer = Date().timeIntervalSince(t1)
        let t2 = Date(); let cells = extractCells(page: page); let tCells = Date().timeIntervalSince(t2)
        let t3 = Date()
        let clusters = dets.enumerated().map { Cluster(id: $0.offset, label: $0.element.label, confidence: $0.element.confidence, bbox: $0.element.bbox) }
        var pp = LayoutPostprocessor(pageW: W, pageH: H, cells: cells, clusters: clusters)
        let finalClusters = pp.postprocess()
        let tPost = Date().timeIntervalSince(t3)
        // assemblaggio (PageAssembleModel) → elementi
        let t4 = Date()
        var elems: [PageElement] = []; var ncells: [Int: Int] = [:]
        for c in finalClusters {
            let lab = c.label
            if TEXT_ELEM_LABELS.contains(lab) || TABLE_LABELS.contains(lab) || lab == FIGURE_LABEL || CONTAINER_LABELS.contains(lab) {
                let lines = c.cells.map { $0.text.replacingOccurrences(of: "\u{02}", with: "-").trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                let text = TEXT_ELEM_LABELS.contains(lab) ? sanitizeLines(lines) : ""
                ncells[c.id] = c.cells.count
                elems.append(PageElement(cid: c.id, label: lab, text: text, pageNo: 1, pageW: W, pageH: H, box: ROBox(topLeft: c.bbox, pageHeight: H)))
            }
        }
        // cid progressivi come in docling (cid = posizione nell'elenco assemblato)
        let roIn = elems.enumerated().map { PageElement(cid: $0.offset, label: $0.element.label, text: $0.element.text, pageNo: 1, pageW: W, pageH: H, box: $0.element.box) }
        let ro = ReadingOrderPredictor()
        let sorted = ro.predictReadingOrder(roIn)
        let merges = ro.predictMerges(sorted)
        let toCaptions = ro.predictToCaptions(sorted)
        let tRO = Date().timeIntervalSince(t4)
        var merged = Set<Int>(); for (_, v) in merges { for m in v { merged.insert(m) } }
        var regions: [LayoutRegion] = []; var order = 0
        var orderOfCid: [Int: Int] = [:]
        var captionCidOfRegion: [Int: Int] = [:]   // indice in `regions` → cid della didascalia
        let clusterById: [Int: Cluster] = Dictionary(uniqueKeysWithValues: finalClusters.map { ($0.id, $0) })
        func round4(_ x: Double) -> Double { (x * 10000).rounded() / 10000 }
        for e in sorted {
            if merged.contains(e.cid) { continue }
            let orig = elems[e.cid]; let c = clusterById[orig.cid]!
            // Come docling (readingorder_model): i contenitori form/key_value_region emettono SOLO i figli; la
            // figura emette sé stessa e poi i figli; la tabella (senza TableFormer) resta un blocco solo.
            func childItems(_ parent: Cluster) {
                for ch in parent.children {
                    regions.append(LayoutRegion(order: order, label: ch.label, bbox: ch.bbox.roundedArray, confidence: round4(ch.confidence),
                                                level: 2, childOf: parent.id, clusterId: ch.id, nCells: ch.cells.count, merged: []))
                    order += 1
                }
            }
            if CONTAINER_LABELS.contains(orig.label) { childItems(c); continue }
            orderOfCid[e.cid] = order
            if let caps = toCaptions[e.cid], let cap = caps.first { captionCidOfRegion[regions.count] = cap }
            regions.append(LayoutRegion(order: order, label: orig.label, bbox: c.bbox.roundedArray, confidence: round4(c.confidence),
                                        level: 1, childOf: nil, clusterId: c.id, nCells: ncells[orig.cid] ?? 0, merged: merges[e.cid] ?? []))
            order += 1
            if orig.label == FIGURE_LABEL { childItems(c) }
        }
        for (k, capCid) in captionCidOfRegion { regions[k].captionOrder = orderOfCid[capCid] }
        let total = Date().timeIntervalSince(t0)
        return (PageLayout(pageIndex: pageIndex, width: W, height: H, regions: regions, nDetections: dets.count, nClusters: finalClusters.count, nCells: cells.count),
                PageTimings(total: total, render: tRender, infer: tInfer, cells: tCells, post: tPost, order: tRO))
    }
}

/// Ricompone le righe di un elemento di testo come il `sanitize` del prototipo (che replica
/// `TextElement` di docling): sillabazione a fine riga, spazi, legature. Serve solo alle fusioni.
func sanitizeLines(_ lines: [String]) -> String {
    if lines.isEmpty { return "" }
    var ls = lines
    for ix in 0..<(ls.count - 1) {
        let prev = ls[ix], line = ls[ix + 1]
        if prev.hasSuffix("-") {
            let pw = prev.split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "_" }), lw = line.split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "_" })
            if let a = pw.last, let b = lw.first, a.allSatisfy({ $0.isLetter || $0.isNumber }), b.allSatisfy({ $0.isLetter || $0.isNumber }) { ls[ix] = String(prev.dropLast()) }
        } else { ls[ix] += " " }
    }
    var s = ls.joined()
    for (a, b) in [("⁄", "/"), ("’", "'"), ("‘", "'"), ("“", "\""), ("”", "\""), ("•", "·"), ("ﬁ", "fi"), ("ﬂ", "fl"), ("ﬀ", "ff"), ("ﬃ", "ffi"), ("ﬄ", "ffl")] { s = s.replacingOccurrences(of: a, with: b) }
    return s.trimmingCharacters(in: .whitespacesAndNewlines)
}
