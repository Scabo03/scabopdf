//
//  Cells.swift
//  ScaboPageStructure
//
//  Celle di testo = righe PDFKit (equivalente delle `textline_cells` di docling-parse). Porto fedele dal
//  prototipo. Il testo serve SOLO in memoria al post-processing (celle vuote, fusioni di testo spezzato):
//  non esce mai dal modulo.
//

import Foundation
import PDFKit

/// Una riga di testo della pagina, in punti, origine alto-sinistra.
struct Cell {
    let index: Int
    let text: String
    let rect: LayoutBox
    let confidence: Double = 1.0
}

/// Estrae le righe di testo della pagina con PDFKit (`selectionsByLine`), nell'ordine del testo del PDF.
func extractCells(page: PDFPage) -> [Cell] {
    let crop = page.bounds(for: .cropBox)
    guard let all = page.selection(for: crop) else { return [] }
    var cells: [Cell] = []
    for sel in all.selectionsByLine() {
        let s = (sel.string ?? "").replacingOccurrences(of: "\u{02}", with: "-")
        if s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { continue }
        let r = sel.bounds(for: page)
        if r.isNull || r.isEmpty { continue }
        let bb = LayoutBox(l: Double(r.minX - crop.minX), t: Double(crop.maxY - r.maxY), r: Double(r.maxX - crop.minX), b: Double(crop.maxY - r.minY))
        cells.append(Cell(index: cells.count, text: s, rect: bb))
    }
    return cells
}
