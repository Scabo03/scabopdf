//
//  Geometry.swift
//  ScaboPageStructure
//
//  Rettangoli del porto di docling. Porto fedele dal prototipo del laboratorio «struttura nativa»
//  (`HeronNative/Geometry.swift`, 2026-10-12), che a sua volta replica `docling_core` BoundingBox.
//  Nessuna modifica numerica: la parità con il prototipo (rete della Parte 1) dipende da questo.
//

import Foundation

/// Rettangolo in punti PDF, origine ALTO-sinistra (come i cluster di docling: l, t, r, b),
/// relativo al cropBox della pagina.
public struct LayoutBox: Equatable, Sendable {
    public var l: Double, t: Double, r: Double, b: Double

    public init(l: Double, t: Double, r: Double, b: Double) {
        self.l = l; self.t = t; self.r = r; self.b = b
    }

    public var width: Double { r - l }
    public var height: Double { b - t }
    func area() -> Double { abs(r - l) * abs(b - t) }
    func intersectionArea(_ o: LayoutBox) -> Double {
        let left = max(l, o.l), right = min(r, o.r), top = max(t, o.t), bottom = min(b, o.b)
        let w = right - left, h = bottom - top
        if w <= 0 || h <= 0 { return 0 }
        return w * h
    }
    func iou(_ o: LayoutBox, eps: Double = 1.0e-6) -> Double {
        let i = intersectionArea(o)
        let u = abs(l - r) * abs(t - b) + abs(o.l - o.r) * abs(o.t - o.b) - i
        return i / (u + eps)
    }
    func intersectionOverSelf(_ o: LayoutBox) -> Double {
        let i = intersectionArea(o); let a = area()
        return a > 0 ? i / a : 0
    }
    func overlapsHorizontally(_ o: LayoutBox) -> Bool { !(r <= o.l || o.r <= l) }
    func overlapsVertically(_ o: LayoutBox) -> Bool { !(b <= o.t || o.b <= t) }
    func overlaps(_ o: LayoutBox) -> Bool { overlapsHorizontally(o) && overlapsVertically(o) }
    func union(_ o: LayoutBox) -> LayoutBox { LayoutBox(l: min(l, o.l), t: min(t, o.t), r: max(r, o.r), b: max(b, o.b)) }
    /// Coordinate arrotondate al decimo di punto (come l'uscita del prototipo).
    public var roundedArray: [Double] { [l, t, r, b].map { ($0 * 10).rounded() / 10 } }
}

/// Rettangolo con origine BASSO-sinistra (come `PageElement` del predittore d'ordine di docling: l, b, r, t).
struct ROBox {
    var l: Double, b: Double, r: Double, t: Double
    init(l: Double, b: Double, r: Double, t: Double) { self.l = l; self.b = b; self.r = r; self.t = t }
    /// da alto-sinistra a basso-sinistra (`to_bottom_left_origin`)
    init(topLeft bb: LayoutBox, pageHeight H: Double) { l = bb.l; r = bb.r; t = H - bb.t; b = H - bb.b }
    func overlapsHorizontally(_ o: ROBox) -> Bool { !(r <= o.l || o.r <= l) }
    func overlapsVertically(_ o: ROBox) -> Bool { !(t <= o.b || o.t <= b) }
    func overlaps(_ o: ROBox) -> Bool { overlapsHorizontally(o) && overlapsVertically(o) }
    func isStrictlyAbove(_ o: ROBox, eps: Double = 1.0e-3) -> Bool { (b + eps) > o.t }
    func isStrictlyLeftOf(_ o: ROBox, eps: Double = 1.0e-3) -> Bool { (r + eps) < o.l }
    func overlapsVerticallyWithIoU(_ o: ROBox, iou: Double) -> Bool {
        guard overlapsVertically(o) else { return false }
        let u0 = min(b, o.b), u1 = max(t, o.t), i0 = max(b, o.b), i1 = min(t, o.t)
        return (i1 - i0) / (u1 - u0) > iou
    }
}
