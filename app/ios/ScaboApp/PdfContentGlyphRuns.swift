//
//  PdfContentGlyphRuns.swift
//  ScaboApp
//
//  Lettura del FLUSSO DI CONTENUTO della pagina con CoreGraphics (CGPDFScanner), a fianco di PDFKit:
//  per ogni operatore di testo (Tj / TJ / ' / ") restituisce i glifi decodificati e lo scarto in em
//  dopo ciascun glifo, cioè l'informazione che PDFKit 27 scarta quando ignora il `Tc` nel decidere i
//  confini di parola (ScaboCore/WordBoundaryRepair.swift, docs/GENERAZIONI_LETTORE.md).
//
//  Fail-safe per costruzione: un run è restituito SOLO se ogni glifo si decodifica attraverso il
//  CMap `ToUnicode` del suo font (Type0 con Identity-H/V a due byte; font semplici a un byte). Senza
//  ToUnicode, con CMap non-Identity, con codice non mappato: il run non esiste e la riparazione non
//  ha di che agire. Immagini e disegni non contano: si leggono solo gli operatori di testo (anche in
//  modo di resa invisibile, come fa PDFKit). Nessun UIKit: lo stesso file compila per macOS (laboratorio) e iOS.
//
//  Stato di testo tracciato: Tf (nome + taglia), Tc, Tw, Tz, salvato/ripristinato da q/Q; i form
//  XObject (`Do`) sono percorsi ricorsivamente con le loro risorse (profondità ≤ 8). Lo scarto dopo un
//  glifo è (Tc/Tfs − adjTJ/1000)·Tz/100 — in em, indipendente dalla matrice di testo: con la
//  convenzione InDesign (`/F 1 Tf` + `11 0 0 11 x y Tm`) il Tc è già in em, con `/F 11 Tf` lo divide la
//  taglia. Td/TD/Tm/T*/'/" segnano «spostamento» (il run successivo non è contiguo) e, se verticale,
//  «riga nuova».
//

import Foundation
import CoreGraphics
import ScaboCore

enum PdfContentGlyphRuns {

    /// I run di testo della pagina, nell'ordine del flusso di contenuto. Vuoto se la pagina non ha
    /// contenuto leggibile o se lo scanner fallisce (la riparazione è allora identità).
    static func runs(for page: CGPDFPage) -> [GlyphRun] {
        let ctx = ScanContext()
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
        return ctx.runs
    }

    // MARK: - CMap ToUnicode

    /// Mappa codice → testo da un flusso `ToUnicode` (bfchar, bfrange a destinazione singola o ad array).
    struct ToUnicode {
        var single: [UInt32: String] = [:]
        var ranges: [(lo: UInt32, hi: UInt32, dst: UInt32)] = []

        func map(_ code: UInt32) -> String? {
            if let s = single[code] { return s }
            for r in ranges where code >= r.lo && code <= r.hi {
                guard let scalar = UnicodeScalar(r.dst + (code - r.lo)) else { return nil }
                return String(Character(scalar))
            }
            return nil
        }

        static func parse(_ data: Data) -> ToUnicode {
            var tu = ToUnicode()
            guard let s = String(data: data, encoding: .isoLatin1) else { return tu }
            // Token esadecimali e parentesi quadre di un segmento bfchar/bfrange.
            func tokens(_ seg: Substring) -> [String] {
                var out: [String] = []; var cur = ""; var inHex = false
                for ch in seg {
                    if ch == "<" { inHex = true; cur = "" }
                    else if ch == ">" { inHex = false; out.append(cur) }
                    else if inHex { cur.append(ch) }
                    else if ch == "[" || ch == "]" { out.append(String(ch)) }
                }
                return out
            }
            func utf16(_ hex: String) -> String {
                var units: [UInt16] = []
                var i = hex.startIndex
                while i < hex.endIndex {
                    let j = hex.index(i, offsetBy: 4, limitedBy: hex.endIndex) ?? hex.endIndex
                    if let v = UInt16(hex[i..<j], radix: 16) { units.append(v) }
                    i = j
                }
                return String(decoding: units, as: UTF16.self)
            }
            var from = s.startIndex
            while let b = s.range(of: "beginbfchar", range: from..<s.endIndex),
                  let e = s.range(of: "endbfchar", range: b.upperBound..<s.endIndex) {
                let t = tokens(s[b.upperBound..<e.lowerBound])
                var k = 0
                while k + 1 < t.count {
                    if let src = UInt32(t[k], radix: 16) { tu.single[src] = utf16(t[k + 1]) }
                    k += 2
                }
                from = e.upperBound
            }
            from = s.startIndex
            while let b = s.range(of: "beginbfrange", range: from..<s.endIndex),
                  let e = s.range(of: "endbfrange", range: b.upperBound..<s.endIndex) {
                let t = tokens(s[b.upperBound..<e.lowerBound])
                var k = 0
                while k + 2 < t.count {
                    guard let lo = UInt32(t[k], radix: 16), let hi = UInt32(t[k + 1], radix: 16) else { k += 1; continue }
                    if t[k + 2] == "[" {
                        var m = k + 3; var code = lo
                        while m < t.count && t[m] != "]" { tu.single[code] = utf16(t[m]); code += 1; m += 1 }
                        k = m + 1
                    } else {
                        if t[k + 2].count <= 4, let dst = UInt32(t[k + 2], radix: 16) {
                            tu.ranges.append((lo, hi, dst))
                        } else {
                            // destinazione a più unità (es. legatura): si incrementa l'ultima
                            let base = utf16(t[k + 2])
                            if let last = base.unicodeScalars.last {
                                var code = lo; var sc = last.value
                                let head = String(String.UnicodeScalarView(base.unicodeScalars.dropLast()))
                                while code <= hi {
                                    if let scalar = UnicodeScalar(sc) { tu.single[code] = head + String(Character(scalar)) }
                                    code += 1; sc += 1
                                }
                            }
                        }
                        k += 3
                    }
                }
                from = e.upperBound
            }
            return tu
        }
    }

    struct FontInfo {
        let twoByte: Bool
        let toUnicode: ToUnicode?
        var usable: Bool { toUnicode != nil }
    }

    static func loadFont(_ dict: CGPDFDictionaryRef) -> FontInfo {
        var subtypeName: UnsafePointer<Int8>? = nil
        var subtype = ""
        if CGPDFDictionaryGetName(dict, "Subtype", &subtypeName), let n = subtypeName { subtype = String(cString: n) }
        var twoByte = false
        if subtype == "Type0" {
            var encName: UnsafePointer<Int8>? = nil
            if CGPDFDictionaryGetName(dict, "Encoding", &encName), let n = encName, String(cString: n).hasPrefix("Identity") {
                twoByte = true
            } else {
                return FontInfo(twoByte: true, toUnicode: nil)   // CMap predefinito non-Identity: fuori scopo
            }
        }
        var stream: CGPDFStreamRef? = nil
        guard CGPDFDictionaryGetStream(dict, "ToUnicode", &stream), let st = stream else {
            return FontInfo(twoByte: twoByte, toUnicode: nil)
        }
        var fmt = CGPDFDataFormat.raw
        guard let data = CGPDFStreamCopyData(st, &fmt) else { return FontInfo(twoByte: twoByte, toUnicode: nil) }
        return FontInfo(twoByte: twoByte, toUnicode: ToUnicode.parse(data as Data))
    }

    // MARK: - Stato dello scanner

    struct TextState {
        var tc: Double = 0
        var tw: Double = 0
        var tz: Double = 100
        var tfs: Double = 0
        var font: FontInfo? = nil
    }

    final class ScanContext {
        var state = TextState()
        var stack: [TextState] = []
        var resources: [CGPDFDictionaryRef] = []
        var parentStreams: [CGPDFContentStreamRef] = []
        var fontCache: [String: FontInfo] = [:]
        var runs: [GlyphRun] = []
        var depth = 0
        var current: GlyphRun? = nil
        /// Td/TD/Tm/T*/BT/ET/Do fra due operatori di testo → il prossimo run non è contiguo.
        var movedSinceLastShow = true
        /// Spostamento verticale (Td con ty ≠ 0, Tm, T*, ', ", BT) → il prossimo run è su un'altra riga.
        var newLineSinceLastShow = true

        func font(named name: String) -> FontInfo? {
            if let f = fontCache[name] { return f }
            for res in resources.reversed() {
                var fonts: CGPDFDictionaryRef? = nil
                guard CGPDFDictionaryGetDictionary(res, "Font", &fonts), let fd = fonts else { continue }
                var f: CGPDFDictionaryRef? = nil
                if CGPDFDictionaryGetDictionary(fd, name, &f), let fdict = f {
                    let fi = PdfContentGlyphRuns.loadFont(fdict)
                    fontCache[name] = fi
                    return fi
                }
            }
            return nil
        }

        func moved(newLine: Bool = true) {
            movedSinceLastShow = true
            if newLine { newLineSinceLastShow = true }
        }

        /// Aggiunge i glifi di una stringa al run corrente. Falso (e run annullato) se non decodificabile.
        func append(_ str: CGPDFStringRef) -> Bool {
            guard let font = state.font, font.usable, state.tfs > 0, let glyphs = decode(str, font) else {
                // Run non decodificabile: i run seguenti non devono «continuare» quello prima di lui.
                current = nil; moved(); return false
            }
            let base = (state.tc / state.tfs) * (state.tz / 100)
            if current == nil {
                current = GlyphRun(glyphs: [], gapsEm: [], ownsGaps: state.tc > 0,
                                   continuesPrevious: !movedSinceLastShow, sameLineAsPrevious: !newLineSinceLastShow)
            }
            for g in glyphs { current!.glyphs.append(g); current!.gapsEm.append(base) }
            return true
        }

        func adjust(_ tj: Double) {
            guard let cur = current, !cur.gapsEm.isEmpty else { return }
            current!.gapsEm[cur.gapsEm.count - 1] += (-tj / 1000) * (state.tz / 100)
        }

        /// Aggiustamento TJ che precede il primo glifo di un run contiguo al precedente: va sullo scarto
        /// finale del run precedente (la giunzione). Se c'è stato uno spostamento, non ha vicino: si ignora.
        func adjustPreviousJunction(_ tj: Double) {
            guard !movedSinceLastShow, let last = runs.indices.last, !runs[last].gapsEm.isEmpty else { return }
            runs[last].gapsEm[runs[last].gapsEm.count - 1] += (-tj / 1000) * (state.tz / 100)
        }

        func close() {
            if let r = current, !r.glyphs.isEmpty {
                runs.append(r)
                movedSinceLastShow = false
                newLineSinceLastShow = false
            }
            current = nil
        }

        private func decode(_ str: CGPDFStringRef, _ font: FontInfo) -> [String]? {
            guard let tu = font.toUnicode, let ptr = CGPDFStringGetBytePtr(str) else { return nil }
            let n = CGPDFStringGetLength(str)
            var out: [String] = []
            if font.twoByte {
                guard n % 2 == 0 else { return nil }
                var i = 0
                while i < n {
                    let code = UInt32(ptr[i]) << 8 | UInt32(ptr[i + 1])
                    guard let s = tu.map(code) else { return nil }
                    out.append(s); i += 2
                }
            } else {
                for i in 0..<n {
                    guard let s = tu.map(UInt32(ptr[i])) else { return nil }
                    out.append(s)
                }
            }
            return out
        }
    }

    private static func context(_ info: UnsafeMutableRawPointer?) -> ScanContext {
        Unmanaged<ScanContext>.fromOpaque(info!).takeUnretainedValue()
    }

    // MARK: - Tabella degli operatori

    static let operatorTable: CGPDFOperatorTableRef = {
        let table = CGPDFOperatorTableCreate()!
        CGPDFOperatorTableSetCallback(table, "q") { _, info in let c = context(info); c.stack.append(c.state) }
        CGPDFOperatorTableSetCallback(table, "Q") { _, info in let c = context(info); if let s = c.stack.popLast() { c.state = s } }
        CGPDFOperatorTableSetCallback(table, "Tf") { sc, info in
            let c = context(info)
            var size: CGPDFReal = 0; var name: UnsafePointer<Int8>? = nil
            guard CGPDFScannerPopNumber(sc, &size), CGPDFScannerPopName(sc, &name), let n = name else { c.state.font = nil; return }
            c.state.tfs = Double(size)
            c.state.font = c.font(named: String(cString: n))
        }
        CGPDFOperatorTableSetCallback(table, "Tc") { sc, info in var v: CGPDFReal = 0; if CGPDFScannerPopNumber(sc, &v) { context(info).state.tc = Double(v) } }
        CGPDFOperatorTableSetCallback(table, "Tw") { sc, info in var v: CGPDFReal = 0; if CGPDFScannerPopNumber(sc, &v) { context(info).state.tw = Double(v) } }
        CGPDFOperatorTableSetCallback(table, "Tz") { sc, info in var v: CGPDFReal = 0; if CGPDFScannerPopNumber(sc, &v) { context(info).state.tz = Double(v) } }
        for op in ["Tm", "T*", "BT", "ET"] {
            CGPDFOperatorTableSetCallback(table, op) { _, info in context(info).moved() }
        }
        for op in ["Td", "TD"] {
            CGPDFOperatorTableSetCallback(table, op) { sc, info in
                var ty: CGPDFReal = 0; var tx: CGPDFReal = 0
                let okY = CGPDFScannerPopNumber(sc, &ty); let okX = CGPDFScannerPopNumber(sc, &tx)
                context(info).moved(newLine: !(okX && okY && abs(Double(ty)) < 1e-6))
            }
        }
        CGPDFOperatorTableSetCallback(table, "Tj") { sc, info in
            let c = context(info); var s: CGPDFStringRef? = nil
            guard CGPDFScannerPopString(sc, &s), let str = s else { return }
            c.current = nil
            if c.append(str) { c.close() }
        }
        CGPDFOperatorTableSetCallback(table, "'") { sc, info in
            let c = context(info); var s: CGPDFStringRef? = nil
            guard CGPDFScannerPopString(sc, &s), let str = s else { return }
            c.moved(); c.current = nil
            if c.append(str) { c.close() }
        }
        CGPDFOperatorTableSetCallback(table, "\"") { sc, info in
            let c = context(info); var s: CGPDFStringRef? = nil; var ac: CGPDFReal = 0; var aw: CGPDFReal = 0
            guard CGPDFScannerPopString(sc, &s), CGPDFScannerPopNumber(sc, &ac), CGPDFScannerPopNumber(sc, &aw), let str = s else { return }
            c.state.tc = Double(ac); c.state.tw = Double(aw)
            c.moved(); c.current = nil
            if c.append(str) { c.close() }
        }
        CGPDFOperatorTableSetCallback(table, "TJ") { sc, info in
            let c = context(info); var arr: CGPDFArrayRef? = nil
            guard CGPDFScannerPopArray(sc, &arr), let a = arr else { return }
            c.current = nil
            var ok = true
            for i in 0..<CGPDFArrayGetCount(a) {
                var s: CGPDFStringRef? = nil; var num: CGPDFReal = 0
                if CGPDFArrayGetString(a, i, &s), let str = s {
                    if !c.append(str) { ok = false; break }
                } else if CGPDFArrayGetNumber(a, i, &num) {
                    if c.current == nil {
                        // Numero PRIMA del primo glifo: sposta la penna fra il run precedente contiguo e
                        // questo → è parte dello scarto di giunzione, posseduto dal run precedente.
                        c.adjustPreviousJunction(Double(num))
                    } else {
                        c.adjust(Double(num))
                    }
                }
            }
            if ok { c.close() } else { c.current = nil }
        }
        CGPDFOperatorTableSetCallback(table, "Do") { sc, info in
            let c = context(info); var name: UnsafePointer<Int8>? = nil
            guard CGPDFScannerPopName(sc, &name), let n = name, c.depth < 8, let parent = c.parentStreams.last else { return }
            for res in c.resources.reversed() {
                var xo: CGPDFDictionaryRef? = nil
                guard CGPDFDictionaryGetDictionary(res, "XObject", &xo), let xd = xo else { continue }
                var st: CGPDFStreamRef? = nil
                guard CGPDFDictionaryGetStream(xd, n, &st), let stream = st, let d = CGPDFStreamGetDictionary(stream) else { continue }
                var sub: UnsafePointer<Int8>? = nil
                guard CGPDFDictionaryGetName(d, "Subtype", &sub), let sn = sub, String(cString: sn) == "Form" else { return }
                var formRes: CGPDFDictionaryRef? = nil
                let pushed = CGPDFDictionaryGetDictionary(d, "Resources", &formRes)
                if pushed, let fr = formRes { c.resources.append(fr) }
                c.moved()
                let saved = c.state, savedStack = c.stack, savedCache = c.fontCache
                c.fontCache = [:]; c.depth += 1
                let cs = CGPDFContentStreamCreateWithStream(stream, formRes ?? d, parent)
                c.parentStreams.append(cs)
                let scanner = CGPDFScannerCreate(cs, operatorTable, info)
                CGPDFScannerScan(scanner)
                CGPDFScannerRelease(scanner)
                c.parentStreams.removeLast()
                CGPDFContentStreamRelease(cs)
                c.depth -= 1
                c.state = saved; c.stack = savedStack; c.fontCache = savedCache
                if pushed { c.resources.removeLast() }
                c.moved()
                return
            }
        }
        return table
    }()
}
