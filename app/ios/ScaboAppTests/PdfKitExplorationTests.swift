//
//  PdfKitExplorationTests.swift
//  ScaboAppTests
//
//  HARNESS DI ESPLORAZIONE — additivo, isolato, non di regressione.
//
//  Scopo: FOTOGRAFARE cosa l'estrattore on-device `PdfKitExtractor` (PDFKit)
//  cattura davvero, a livello di segnale grezzo, su tre documenti reali del
//  corpus privato (patriarca_benazzo, marrone_istituzioni,
//  mandrioli_carratta_vol_iii). Non è un test con verdetto: non asserisce nulla
//  oltre "l'estrazione non lancia". Produce dump leggibili in
//  /tmp/scabo_pdfkit_exploration/ che la sessione legge per redigere il report.
//
//  Due strumenti per documento:
//    (A) Censimento whole-doc sull'ORIGINALE INTATTO (apertura PDFDocument +
//        attributedString, nessuna riscrittura, nessun bbox costoso): istogramma
//        fontSize, istogramma COLORE risolto (stessa regola dell'estrattore:
//        getRed→hex, poi getWhite→hex, poi nero), conteggi bold/italic, pagine
//        senza testo (scanned/image). È la prova autoritativa sulla palette,
//        perché legge la sorgente non toccata.
//    (B) Estrazione reale via `PdfKitExtractor().extract(...)` su un PDF-CAMPIONE
//        di pagine consecutive (ricavato con PDFKit dall'originale): fornisce i
//        fatti che richiedono il bbox (geometria via PDFSelection) e l'apparato
//        note, incluso il confine cross-page sul Mandrioli.
//
//  Il campione (B) è un sottoinsieme RI-SERIALIZZATO: la palette autoritativa
//  resta (A) sull'originale; (B) serve per bbox/note/dump per-span e per
//  confermare che i colori del campione combacino col censimento.
//
//  Niente dipendenze nuove: PDFKit/UIKit/ScaboCore/ScaboApp già linkati.
//

import PDFKit
import UIKit
import XCTest

@testable import ScaboApp
import ScaboCore

final class PdfKitExplorationTests: XCTestCase {

    // MARK: - Localizzazione fixture e output (via #filePath, host filesystem)

    private func repoRoot() -> URL {
        // .../app/ios/ScaboAppTests/PdfKitExplorationTests.swift  →  4 su = repo
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // ScaboAppTests
            .deletingLastPathComponent() // ios
            .deletingLastPathComponent() // app
            .deletingLastPathComponent() // repo root
    }

    private func fixture(_ slug: String) -> URL {
        repoRoot().appendingPathComponent("pipeline/tests/fixtures/private/\(slug).pdf")
    }

    private func outputDir() -> URL {
        let d = URL(fileURLWithPath: "/tmp/scabo_pdfkit_exploration", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    // MARK: - Colore: stessa regola del cuore dell'estrattore

    private func hexColour(_ color: UIColor?) -> String {
        guard let color = color else { return "#000000" }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if color.getRed(&r, green: &g, blue: &b, alpha: &a) { return hx(r, g, b) }
        var w: CGFloat = 0
        if color.getWhite(&w, alpha: &a) { return hx(w, w, w) }
        return "#000000"
    }

    private func hx(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> String {
        func c(_ v: CGFloat) -> Int { max(0, min(255, Int((v * 255).rounded()))) }
        return String(format: "#%02X%02X%02X", c(r), c(g), c(b))
    }

    // MARK: - (A) Censimento whole-doc sull'originale intatto

    private func census(_ url: URL) -> [String: Any] {
        guard let doc = PDFDocument(url: url) else {
            return ["error": "impossibile aprire \(url.lastPathComponent)"]
        }
        var sizeHist: [String: Int] = [:]      // fontSize (arrotondato 0.25) → run
        var colourHist: [String: Int] = [:]    // hex → run
        var colourExample: [String: [String: Any]] = [:]
        var boldRuns = 0, italicRuns = 0, noFontRuns = 0
        var emptyPages: [Int] = []
        var totalRuns = 0, totalChars = 0
        let pageCount = doc.pageCount

        for i in 0..<pageCount {
            guard let p = doc.page(at: i),
                  let attr = p.attributedString, attr.length > 0 else {
                emptyPages.append(i)
                continue
            }
            let ns = attr.string as NSString
            attr.enumerateAttributes(in: NSRange(location: 0, length: attr.length), options: []) { a, r, _ in
                totalRuns += 1
                totalChars += r.length
                var size = 0.0, bold = false, italic = false
                if let f = a[.font] as? UIFont {
                    size = Double(f.pointSize)
                    let t = f.fontDescriptor.symbolicTraits
                    bold = t.contains(.traitBold)
                    italic = t.contains(.traitItalic)
                } else {
                    noFontRuns += 1
                }
                if bold { boldRuns += 1 }
                if italic { italicRuns += 1 }
                let sk = String(format: "%.2f", (size * 4).rounded() / 4)
                sizeHist[sk, default: 0] += 1
                let col = self.hexColour(a[.foregroundColor] as? UIColor)
                colourHist[col, default: 0] += 1
                if colourExample[col] == nil {
                    let snip = ns.substring(with: r).trimmingCharacters(in: .whitespacesAndNewlines)
                    colourExample[col] = ["text": String(snip.prefix(48)), "page": i]
                }
            }
        }

        return [
            "pageCount": pageCount,
            "totalRuns": totalRuns,
            "totalChars": totalChars,
            "boldRuns": boldRuns,
            "italicRuns": italicRuns,
            "noFontRuns": noFontRuns,
            "emptyOrImagePages": emptyPages.count,
            "emptyOrImagePagesSample": Array(emptyPages.prefix(20)),
            "fontSizeHistogramByRun": sizeHist,
            "colourHistogramByRun": colourHist,
            "colourExamples": colourExample,
        ]
    }

    // MARK: - (B) PDF-campione di pagine consecutive dall'originale

    private func subsetURL(original: URL, pages: [Int], slug: String) -> URL? {
        guard let src = PDFDocument(url: original) else { return nil }
        let out = PDFDocument()
        var dest = 0
        for s in pages where s >= 0 && s < src.pageCount {
            if let pg = src.page(at: s)?.copy() as? PDFPage {
                out.insert(pg, at: dest)
                dest += 1
            }
        }
        guard dest > 0 else { return nil }
        let u = outputDir().appendingPathComponent("subset_\(slug).pdf")
        return out.write(to: u) ? u : nil
    }

    /// Dump per-pagina dell'estrazione reale (campione): righe, span, geometria.
    private func dumpExtraction(_ ex: PdfExtraction, originalPages: [Int]) -> [String: Any] {
        var pagesOut: [[String: Any]] = []
        var sizeHist: [String: Int] = [:]
        var zeroBBoxSpans = 0, resolvedBBoxSpans = 0, totalSpans = 0

        for (local, page) in ex.pages.enumerated() {
            let origIndex = local < originalPages.count ? originalPages[local] : page.pageIndex
            var linesOut: [[String: Any]] = []
            for line in page.lines {
                var spansOut: [[String: Any]] = []
                for s in line.spans {
                    totalSpans += 1
                    if s.bbox.width > 0 && s.bbox.height > 0 { resolvedBBoxSpans += 1 } else { zeroBBoxSpans += 1 }
                    let sk = String(format: "%.2f", (s.fontSize * 4).rounded() / 4)
                    sizeHist[sk, default: 0] += 1
                    spansOut.append([
                        "t": String(s.text.prefix(140)),
                        "sz": s.fontSize,
                        "b": s.bold,
                        "i": s.italic,
                        "c": s.color,
                        "bbox": [s.bbox.x, s.bbox.y, s.bbox.width, s.bbox.height],
                    ])
                }
                linesOut.append([
                    "y": line.bbox.y,
                    "h": line.bbox.height,
                    "text": String(line.spans.map { $0.text }.joined().prefix(220)),
                    "nSpans": line.spans.count,
                    "spans": spansOut,
                ])
            }
            pagesOut.append([
                "originalPageIndex": origIndex,
                "width": page.width,
                "height": page.height,
                "nLines": page.lines.count,
                "nSpans": page.lines.reduce(0) { $0 + $1.spans.count },
                "lines": linesOut,
            ])
        }

        return [
            "version": ex.version,
            "nSampledPages": ex.pages.count,
            "totalSpansSample": totalSpans,
            "resolvedBBoxSpans": resolvedBBoxSpans,
            "zeroBBoxSpans": zeroBBoxSpans,
            "sampleSizeHistogramBySpan": sizeHist,
            "pages": pagesOut,
        ]
    }

    /// Euristica note cross-page: per ogni pagina del campione, banda inferiore
    /// (yFrac < 0.32) a dimensione "nota". Riporta il testo della banda in ordine
    /// di lettura (alto→basso) così da leggere a vista la continuità sul confine.
    private func crossPageNoteScan(_ ex: PdfExtraction, originalPages: [Int], noteSize: Double) -> [String: Any] {
        var perPage: [[String: Any]] = []
        for (local, page) in ex.pages.enumerated() {
            let h = page.height > 0 ? page.height : 1
            var band: [PdfSpan] = []
            for line in page.lines {
                for s in line.spans {
                    let yFrac = s.bbox.y / h
                    if abs(s.fontSize - noteSize) <= 0.7 && yFrac < 0.32 && s.bbox.height > 0 {
                        band.append(s)
                    }
                }
            }
            // Ordine di lettura nota: y decrescente (alto→basso), poi x crescente.
            band.sort { a, b in
                if abs(a.bbox.y - b.bbox.y) > 1.5 { return a.bbox.y > b.bbox.y }
                return a.bbox.x < b.bbox.x
            }
            let text = band.map { $0.text }.joined()
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            let last = trimmed.last.map(String.init) ?? ""
            let endsClosed = [".", "!", "?", "»", "\"", ")", ":"].contains(last)
            let origIndex = local < originalPages.count ? originalPages[local] : page.pageIndex
            perPage.append([
                "originalPageIndex": origIndex,
                "bandSpanCount": band.count,
                "bandText": String(trimmed.prefix(1400)),
                "endsClosed": endsClosed,
                "lastChar": last,
            ])
        }
        return ["noteSizeUsed": noteSize, "perPage": perPage]
    }

    private func write(_ obj: [String: Any], to name: String) {
        guard JSONSerialization.isValidJSONObject(obj),
              let data = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]) else {
            NSLog("[esplorazione] serializzazione fallita per \(name)")
            return
        }
        let u = outputDir().appendingPathComponent(name)
        do {
            try data.write(to: u, options: .atomic)
            NSLog("[esplorazione] scritto \(u.path) (\(data.count) byte)")
        } catch {
            NSLog("[esplorazione] scrittura fallita \(name): \(error.localizedDescription)")
        }
    }

    // MARK: - Driver per documento

    private func explore(slug: String, window: [Int], noteSize: Double) throws {
        let url = fixture(slug)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("fixture mancante: \(url.path)")
        }

        // (A) censimento whole-doc su originale intatto
        let cen = census(url)
        NSLog("[esplorazione] \(slug) censimento: \(cen["pageCount"] ?? "?") pagine, "
              + "\((cen["colourHistogramByRun"] as? [String: Int])?.count ?? 0) colori distinti, "
              + "\((cen["fontSizeHistogramByRun"] as? [String: Int])?.count ?? 0) size distinte")

        // (B) estrazione reale su campione
        var extractionDump: [String: Any] = ["note": "campione non costruito"]
        var crossPage: [String: Any] = [:]
        if let sub = subsetURL(original: url, pages: window, slug: slug) {
            let ex = try PdfKitExtractor().extract(fromUri: sub.path)
            extractionDump = dumpExtraction(ex, originalPages: window)
            crossPage = crossPageNoteScan(ex, originalPages: window, noteSize: noteSize)
            NSLog("[esplorazione] \(slug) campione: \(ex.pages.count) pagine, "
                  + "\(extractionDump["totalSpansSample"] ?? "?") span, "
                  + "bbox risolti \(extractionDump["resolvedBBoxSpans"] ?? "?")/\(extractionDump["totalSpansSample"] ?? "?")")
        } else {
            NSLog("[esplorazione] \(slug) ATTENZIONE: campione non costruito")
        }

        let report: [String: Any] = [
            "slug": slug,
            "sampleWindowOriginalPages": window,
            "census": cen,
            "sampleExtraction": extractionDump,
            "crossPageNoteScan": crossPage,
        ]
        write(report, to: "\(slug).json")
    }

    // MARK: - Test (un metodo per documento, così uno lento non blocca gli altri)

    func test_explore_patriarca_benazzo() throws {
        // 504 pagine, caso base. Finestra mid-body.
        try explore(slug: "patriarca_benazzo", window: Array(40...47), noteSize: 8.0)
    }

    func test_explore_marrone_istituzioni() throws {
        // 684 pagine. Stress COLORE: censimento whole-doc decide se PDFKit vede
        // la palette. Finestra ampia per intercettare § maroon, marcatori rossi
        // e, con un po' di fortuna, un capo verde.
        try explore(slug: "marrone_istituzioni", window: Array(60...84), noteSize: 9.0)
    }

    func test_explore_mandrioli_vol_iii() throws {
        // 498 pagine. Crash test NOTE cross-page (PyMuPDF: 1161 NOTE, 951 sintetiche
        // dal body+note splitter). Finestra densa di corpo+note.
        try explore(slug: "mandrioli_carratta_vol_iii", window: Array(70...94), noteSize: 9.0)
    }
}
