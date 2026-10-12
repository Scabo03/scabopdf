//
//  VisualCandidateBuilder.swift
//  ScaboPageStructure
//
//  Dalle regioni del modello ai CANDIDATI per la guardia di ScaboCore (`VisualRegionCandidate`, stesse chiavi JSON):
//  per ogni tabella o figura di primo livello, la didascalia che docling le associa, le regioni di testo che il
//  modello legge subito prima e subito dopo, e quanti oggetti dipinti (filetti, riquadri, immagini) stanno nella
//  regione secondo la sonda grafica. Un'unica fonte per l'app e per le reti sul Mac (riga di comando).
//

import Foundation

/// Un candidato, nelle chiavi JSON di `ScaboCore.VisualRegionCandidate`. Nessun testo.
public struct VisualCandidateRecord: Codable, Equatable, Sendable {
    public var pageIndex: Int
    public var label: String
    public var bbox: [Double]
    public var confidence: Double
    public var captionBBox: [Double]?
    public var pageWidth: Double
    public var pageHeight: Double
    public var previousTextBBox: [Double]?
    public var nextTextBBox: [Double]?
    public var graphicsInside: Int?
}

public enum VisualCandidateBuilder {

    /// Etichette di docling che portano testo da leggere (per collocare una figura senza testo).
    static let textual: Set<String> = ["text", "list_item", "section_header", "title", "caption", "footnote", "code", "formula",
                                       "checkbox_selected", "checkbox_unselected"]

    /// I candidati di una pagina. `paintedBoxes` (dalla sonda grafica con `collectBoxes`) dà `graphicsInside`;
    /// `nil` lo lascia non misurato.
    public static func candidates(from layout: PageLayout, paintedBoxes: [[Double]]?) -> [VisualCandidateRecord] {
        let regs = layout.regions.sorted { $0.order < $1.order }
        let top = regs.filter { $0.level == 1 }
        var out: [VisualCandidateRecord] = []
        for (i, r) in top.enumerated() where r.label == "table" || r.label == "picture" {
            let cap = r.captionOrder.flatMap { co in regs.first { $0.order == co }?.bbox }
            let prev = top[..<i].last { textual.contains($0.label) }?.bbox
            let next = top[(i + 1)...].first { textual.contains($0.label) }?.bbox
            out.append(VisualCandidateRecord(
                pageIndex: layout.pageIndex, label: r.label, bbox: r.bbox, confidence: r.confidence, captionBBox: cap,
                pageWidth: layout.width, pageHeight: layout.height, previousTextBBox: prev, nextTextBBox: next,
                graphicsInside: paintedBoxes.map { graphicsCount(region: r.bbox, boxes: $0) }))
        }
        return out
    }

    /// Quanti oggetti dipinti appartengono alla regione: quelli il cui centro cade dentro la regione ristretta di
    /// 3 punti per lato (un filetto che ne sfiora solo il bordo, come quello sotto una testatina, non conta), più
    /// quelli che la CONTENGONO (il riquadro grigio di sfondo dietro una tabella senza filetti).
    public static func graphicsCount(region r: [Double], boxes: [[Double]]) -> Int {
        guard r.count == 4 else { return 0 }
        let inset = 3.0
        let rcx = (r[0] + r[2]) / 2, rcy = (r[1] + r[3]) / 2
        return boxes.reduce(0) { n, b in
            guard b.count == 4 else { return n }
            let cx = (b[0] + b[2]) / 2, cy = (b[1] + b[3]) / 2
            let inside = cx > r[0] + inset && cx < r[2] - inset && cy > r[1] + inset && cy < r[3] - inset
            let encloses = b[0] <= rcx && b[2] >= rcx && b[1] <= rcy && b[3] >= rcy
                && (b[2] - b[0]) * (b[3] - b[1]) >= (r[2] - r[0]) * (r[3] - r[1])
            return n + ((inside || encloses) ? 1 : 0)
        }
    }
}
