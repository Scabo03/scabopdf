//
//  PageGraphicsProbe.swift
//  ScaboPageStructure
//
//  La SONDA GRAFICA della pagina: il prefiltro economico che decide su quali pagine vale la pena far girare il
//  modello d'impaginazione. Legge il flusso di contenuto con CoreGraphics (`CGPDFScanner`, come
//  `PdfContentGlyphRuns` dell'app per il testo) e conta ciò che una tabella, uno schema, un diagramma o
//  un'illustrazione lasciano nel PDF: immagini (XObject /Image e immagini in linea) con la loro superficie
//  sulla pagina, tracciati dipinti (filetti orizzontali e verticali, rettangoli, curve, diagonali), sfumature.
//  Il testo non si legge. I form XObject si percorrono ricorsivamente con la loro matrice (profondità ≤ 8).
//
//  Nessun Core ML, nessun UIKit: compila per iOS e macOS e costa pochi millisecondi a pagina.
//

import Foundation
import CoreGraphics

/// Il profilo grafico di una pagina (conteggi; nessun testo).
public struct PageGraphicsProfile: Codable, Equatable, Sendable {
    /// Immagini dipinte (XObject /Image e immagini in linea).
    public var images: Int = 0
    /// Superficie della più grande, e somma delle superfici (tetto 1), in frazione della pagina.
    public var imageMaxAreaFraction: Double = 0
    public var imageAreaFraction: Double = 0
    /// Immagini che coprono almeno l'85 % della pagina (la pagina scansionata sotto il testo OCR).
    public var fullPageImages: Int = 0
    /// Immagini piccole (< 1 % della pagina: loghi, fregi, bolli).
    public var smallImages: Int = 0
    /// Segmenti dipinti orizzontali e verticali lunghi almeno 15 pt (linee o rettangoli sottili).
    public var hRules: Int = 0
    public var vRules: Int = 0
    /// Rettangoli dipinti con entrambi i lati ≥ 15 pt e sotto l'85 % della pagina.
    public var rects: Int = 0
    /// Curve e segmenti obliqui dipinti.
    public var curves: Int = 0
    public var diagonals: Int = 0
    /// Operatori di sfumatura (`sh`) e operatori di pittura totali.
    public var shadings: Int = 0
    public var paintOps: Int = 0

    /// Riquadri `[l, t, r, b]` (punti, origine alto-sinistra, relativi al cropBox) di ciò che è dipinto: filetti,
    /// rettangoli, tracciati curvi e immagini (esclusi gli sfondi a tutta pagina). Servono alla guardia per sapere
    /// se una regione del modello contiene qualche disegno. Vuoto se non richiesto.
    public var paintedBoxes: [[Double]] = []

    public init() {}
}

public enum PageGraphicsProbe {

    /// Profilo grafico della pagina. Una pagina illeggibile dà il profilo vuoto. Con `collectBoxes` raccoglie
    /// anche i riquadri di ciò che è dipinto (`paintedBoxes`).
    public static func profile(of page: CGPDFPage, collectBoxes: Bool = false) -> PageGraphicsProfile {
        let box = page.getBoxRect(.cropBox)
        let ctx = ProbeContext(pageArea: max(1, Double(box.width * box.height)))
        ctx.collect = collectBoxes; ctx.cropBox = box
        if let dict = page.dictionary {
            var res: CGPDFDictionaryRef? = nil
            if CGPDFDictionaryGetDictionary(dict, "Resources", &res), let r = res { ctx.resources.append(r) }
        }
        let stream = CGPDFContentStreamCreateWithPage(page)
        ctx.parentStreams.append(stream)
        let scanner = CGPDFScannerCreate(stream, operatorTable, Unmanaged.passUnretained(ctx).toOpaque())
        CGPDFScannerScan(scanner)
        CGPDFScannerRelease(scanner)
        CGPDFContentStreamRelease(stream)
        ctx.profile.imageAreaFraction = min(1, ctx.profile.imageAreaFraction)
        return ctx.profile
    }

    // MARK: - Stato

    final class ProbeContext {
        let pageArea: Double
        var profile = PageGraphicsProfile()
        var ctm = CGAffineTransform.identity
        var stack: [CGAffineTransform] = []
        var resources: [CGPDFDictionaryRef] = []
        var parentStreams: [CGPDFContentStreamRef] = []
        var depth = 0
        /// Form XObject attraversati sulla pagina: oltre `maxFormVisits` la sonda smette di scendere (un PDF patologico
        /// che richiama le stesse forme a cascata renderebbe la sonda esponenziale a ogni importazione).
        var formVisits = 0
        // Il tracciato in costruzione, già in coordinate di pagina.
        var current: CGPoint? = nil
        var subpathStart: CGPoint? = nil
        var pendingH = 0, pendingV = 0, pendingRects = 0, pendingCurves = 0, pendingDiag = 0
        // Raccolta dei riquadri dipinti (solo se richiesta).
        var collect = false
        var cropBox = CGRect.zero
        var pendingBounds: CGRect? = nil

        init(pageArea: Double) { self.pageArea = pageArea }

        func grow(_ p: CGPoint) {
            guard collect else { return }
            pendingBounds = pendingBounds.map { $0.union(CGRect(origin: p, size: .zero)) } ?? CGRect(origin: p, size: .zero)
        }
        func record(_ r: CGRect) {
            guard collect, !r.isNull else { return }
            let rr = r.standardized
            if Double(rr.width * rr.height) >= 0.85 * pageArea { return }   // sfondo a tutta pagina: non conta
            profile.paintedBoxes.append([Double(rr.minX - cropBox.minX), Double(cropBox.maxY - rr.maxY),
                                         Double(rr.maxX - cropBox.minX), Double(cropBox.maxY - rr.minY)])
        }

        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y).applying(ctm) }

        func segment(to p: CGPoint) {
            if let a = current { classify(a, p); grow(a) }
            grow(p)
            current = p
        }
        func classify(_ a: CGPoint, _ b: CGPoint) {
            let dx = abs(b.x - a.x), dy = abs(b.y - a.y)
            if dy < 0.75 && dx >= 15 { pendingH += 1 }
            else if dx < 0.75 && dy >= 15 { pendingV += 1 }
            else if dx >= 15 || dy >= 15 { pendingDiag += 1 }
        }
        func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) {
            let r = CGRect(x: x, y: y, width: w, height: h).standardized.applying(ctm)
            let W = r.width, H = r.height
            if H < 2 && W >= 15 { pendingH += 1 }
            else if W < 2 && H >= 15 { pendingV += 1 }
            else if W >= 15 && H >= 15 && Double(W * H) < 0.85 * pageArea { pendingRects += 1 }
            if collect, Double(W * H) < 0.85 * pageArea { pendingBounds = pendingBounds.map { $0.union(r) } ?? r }
            current = r.origin; subpathStart = r.origin
        }
        func paint() {
            profile.paintOps += 1
            if let b = pendingBounds, b.width >= 1 || b.height >= 1 { record(b) }
            profile.hRules += pendingH; profile.vRules += pendingV; profile.rects += pendingRects
            profile.curves += pendingCurves; profile.diagonals += pendingDiag
            discard()
        }
        func discard() {
            pendingH = 0; pendingV = 0; pendingRects = 0; pendingCurves = 0; pendingDiag = 0
            current = nil; subpathStart = nil; pendingBounds = nil
        }
        func image() {
            let unit = CGRect(x: 0, y: 0, width: 1, height: 1).applying(ctm)
            record(unit)
            let frac = Double(abs(unit.width * unit.height)) / pageArea
            profile.images += 1
            profile.imageMaxAreaFraction = max(profile.imageMaxAreaFraction, frac)
            profile.imageAreaFraction += frac
            if frac >= 0.85 { profile.fullPageImages += 1 }
            if frac < 0.01 { profile.smallImages += 1 }
        }
    }

    private static func context(_ info: UnsafeMutableRawPointer?) -> ProbeContext {
        Unmanaged<ProbeContext>.fromOpaque(info!).takeUnretainedValue()
    }

    private static func pop(_ sc: CGPDFScannerRef, _ n: Int) -> [CGFloat]? {
        var out = [CGFloat](repeating: 0, count: n)
        for i in stride(from: n - 1, through: 0, by: -1) {
            var v: CGPDFReal = 0
            guard CGPDFScannerPopNumber(sc, &v) else { return nil }
            out[i] = v
        }
        return out
    }

    // MARK: - Tabella degli operatori

    static let operatorTable: CGPDFOperatorTableRef = {
        let table = CGPDFOperatorTableCreate()!
        CGPDFOperatorTableSetCallback(table, "q") { _, info in let c = context(info); c.stack.append(c.ctm) }
        CGPDFOperatorTableSetCallback(table, "Q") { _, info in let c = context(info); if let m = c.stack.popLast() { c.ctm = m } }
        CGPDFOperatorTableSetCallback(table, "cm") { sc, info in
            guard let v = pop(sc, 6) else { return }
            let c = context(info)
            c.ctm = CGAffineTransform(a: v[0], b: v[1], c: v[2], d: v[3], tx: v[4], ty: v[5]).concatenating(c.ctm)
        }
        CGPDFOperatorTableSetCallback(table, "m") { sc, info in
            guard let v = pop(sc, 2) else { return }
            let c = context(info); let p = c.point(v[0], v[1]); c.current = p; c.subpathStart = p; c.grow(p)
        }
        CGPDFOperatorTableSetCallback(table, "l") { sc, info in
            guard let v = pop(sc, 2) else { return }
            let c = context(info); c.segment(to: c.point(v[0], v[1]))
        }
        CGPDFOperatorTableSetCallback(table, "c") { sc, info in
            guard let v = pop(sc, 6) else { return }
            let c = context(info); c.pendingCurves += 1; c.grow(c.point(v[0], v[1])); c.grow(c.point(v[2], v[3])); let e = c.point(v[4], v[5]); c.grow(e); c.current = e
        }
        for op in ["v", "y"] {
            CGPDFOperatorTableSetCallback(table, op) { sc, info in
                guard let v = pop(sc, 4) else { return }
                let c = context(info); c.pendingCurves += 1; c.grow(c.point(v[0], v[1])); let e = c.point(v[2], v[3]); c.grow(e); c.current = e
            }
        }
        CGPDFOperatorTableSetCallback(table, "h") { _, info in
            let c = context(info); if let s = c.subpathStart { c.segment(to: s) }
        }
        CGPDFOperatorTableSetCallback(table, "re") { sc, info in
            guard let v = pop(sc, 4) else { return }
            context(info).rect(v[0], v[1], v[2], v[3])
        }
        for op in ["S", "f", "F", "f*", "B", "B*"] {
            CGPDFOperatorTableSetCallback(table, op) { _, info in context(info).paint() }
        }
        // `s`, `b`, `b*` chiudono il sotto-tracciato prima di dipingere.
        for op in ["s", "b", "b*"] {
            CGPDFOperatorTableSetCallback(table, op) { _, info in
                let c = context(info)
                if let s = c.subpathStart { c.segment(to: s) }
                c.paint()
            }
        }
        CGPDFOperatorTableSetCallback(table, "n") { _, info in context(info).discard() }
        CGPDFOperatorTableSetCallback(table, "sh") { _, info in context(info).profile.shadings += 1 }
        // Immagine in linea: CoreGraphics consegna il flusso a `EI`.
        CGPDFOperatorTableSetCallback(table, "EI") { _, info in context(info).image() }
        CGPDFOperatorTableSetCallback(table, "Do") { sc, info in
            let c = context(info); var name: UnsafePointer<Int8>? = nil
            guard CGPDFScannerPopName(sc, &name), let n = name else { return }
            for res in c.resources.reversed() {
                var xo: CGPDFDictionaryRef? = nil
                guard CGPDFDictionaryGetDictionary(res, "XObject", &xo), let xd = xo else { continue }
                var st: CGPDFStreamRef? = nil
                guard CGPDFDictionaryGetStream(xd, n, &st), let stream = st, let d = CGPDFStreamGetDictionary(stream) else { continue }
                var sub: UnsafePointer<Int8>? = nil
                guard CGPDFDictionaryGetName(d, "Subtype", &sub), let sn = sub else { return }
                let subtype = String(cString: sn)
                if subtype == "Image" { c.image(); return }
                guard subtype == "Form", c.depth < 8, c.formVisits < PageGraphicsProbe.maxFormVisits,
                      let parent = c.parentStreams.last else { return }
                c.formVisits += 1
                var formRes: CGPDFDictionaryRef? = nil
                let pushed = CGPDFDictionaryGetDictionary(d, "Resources", &formRes)
                if pushed, let fr = formRes { c.resources.append(fr) }
                let savedCTM = c.ctm, savedStack = c.stack
                var matrix: CGPDFArrayRef? = nil
                if CGPDFDictionaryGetArray(d, "Matrix", &matrix), let m = matrix, CGPDFArrayGetCount(m) == 6 {
                    var v = [CGFloat](repeating: 0, count: 6)
                    for i in 0..<6 { var x: CGPDFReal = 0; _ = CGPDFArrayGetNumber(m, i, &x); v[i] = x }
                    c.ctm = CGAffineTransform(a: v[0], b: v[1], c: v[2], d: v[3], tx: v[4], ty: v[5]).concatenating(c.ctm)
                }
                c.depth += 1
                let cs = CGPDFContentStreamCreateWithStream(stream, formRes ?? d, parent)
                c.parentStreams.append(cs)
                let scanner = CGPDFScannerCreate(cs, operatorTable, info)
                CGPDFScannerScan(scanner)
                CGPDFScannerRelease(scanner)
                c.parentStreams.removeLast()
                CGPDFContentStreamRelease(cs)
                c.depth -= 1
                c.ctm = savedCTM; c.stack = savedStack
                if pushed { c.resources.removeLast() }
                return
            }
        }
        return table
    }()
}

// MARK: - Il prefiltro: quali pagine vanno al modello

extension PageGraphicsProbe {

    /// Tetto ai form XObject attraversati per pagina (vedi `ProbeContext.formVisits`).
    public static let maxFormVisits = 2_000
    /// Superficie minima (in frazione di pagina) di un'immagine perché la pagina vada al modello: sotto ci sono solo
    /// loghi, bolli e fregi. Sopra l'85 % è lo sfondo di una pagina scansionata o una tavola a tutta pagina: non conta.
    public static let minImageFraction = 0.05
    public static let maxImageFraction = 0.85
    /// Quanti filetti orizzontali, verticali e riquadri IN PIÙ della pagina tipica del volume fanno pensare a una tabella o
    /// a uno schema. La pagina tipica è la moda di (orizzontali, verticali, riquadri) sulle pagine del volume: assorbe
    /// l'arredo che si ripete su ogni pagina (testatine filettate, linguette, filigrane disegnate).
    /// Misurato sui 52 volumi del corpus (giro «risorse visive», 2026-10-12): 556 pagine su 22.626 (2,5 %) vanno al
    /// modello e coprono 110 delle 111 risorse accettate dalla guardia sulle regioni di tutte le pagine; l'esclusa è una
    /// cornice decorativa.
    public static let extraHorizontalRules = 5
    public static let extraVerticalRules = 3
    public static let extraRects = 2

    /// Gli indici (0-based) delle pagine da mandare al modello, dati i profili di TUTTE le pagine del documento.
    public static func pagesForModel(_ profiles: [PageGraphicsProfile]) -> [Int] {
        guard !profiles.isEmpty else { return [] }
        var counts: [[Int]: Int] = [:]
        var firstSeen: [[Int]: Int] = [:]
        for (i, p) in profiles.enumerated() {
            let key = [p.hRules, p.vRules, p.rects]
            counts[key, default: 0] += 1
            if firstSeen[key] == nil { firstSeen[key] = i }
        }
        // moda; a parità, la combinazione vista per prima (deterministico)
        let mode = counts.max { a, b in a.value != b.value ? a.value < b.value : firstSeen[a.key]! > firstSeen[b.key]! }!.key
        return profiles.enumerated().compactMap { i, p in
            let image = p.imageMaxAreaFraction >= minImageFraction && p.imageMaxAreaFraction < maxImageFraction
            let vector = p.hRules - mode[0] >= extraHorizontalRules || p.vRules - mode[1] >= extraVerticalRules
                || p.rects - mode[2] >= extraRects
            return (image || vector) ? i : nil
        }
    }
}
