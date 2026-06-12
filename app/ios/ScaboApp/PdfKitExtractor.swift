//
//  PdfKitExtractor.swift
//  ScaboApp
//
//  The on-device PDF extractor (Piano di migrazione, banda POST-MAC punto 2).
//  Opens a PDF with Apple PDFKit and produces the boundary value type
//  `PdfExtraction` (ScaboCore) behind the `PdfExtracting` seam. It is the single
//  component in the app that knows PDFKit; the classifier consumes only the
//  returned `PdfExtraction` (§ 10 del piano).
//
//  ── Decisione A vs B (vedi docs/PDFKIT_EXTRACTOR.md per la motivazione estesa) ──
//
//  Scelta: **A — trapianto dell'algoritmo di estrazione validato, confine
//  riscritto pulito.** L'estrattore PDFKit preesistente nel pod RN
//  (`ScaboNative/ScaboPdfExtractor.swift`) NON era intriso di React: importava
//  solo Foundation/PDFKit/UIKit, zero simboli RN. L'accoppiamento RN viveva tutto
//  ai BORDI — il ritorno come stringa JSON (per attraversare il bridge JS),
//  l'annotazione `@objc`, il TurboModule `.mm`, le chiamate a `ScaboLog`. Il
//  CUORE (ricostruzione run/line via `attributedString`, geometria via
//  `PDFSelection`, risoluzione colore, fallback scanned, convenzione coordinate
//  page-local origin-in-basso-a-sinistra) è esattamente ciò che ha prodotto le 7
//  capture reali v2 su cui l'intera migrazione si è calibrata: conoscenza
//  validata contro PDF veri, priva di unit test (Piano § 4, zona ad alta
//  attenzione). Riscriverlo da zero significherebbe ri-derivare le stesse
//  chiamate PDFKit e ri-scoprire gli stessi casi limite, col rischio concreto di
//  perderne uno in silenzio — qualità più bassa, non più alta. Trapiantare il
//  cuore e SCARTARE i bordi produce il risultato più completo e robusto e per
//  giunta più pulito del punto di partenza: il ritorno tipizzato `PdfExtraction`
//  elimina il round-trip serialise→JSON.parse che esisteva solo per il bridge.
//
//  Cosa cambia rispetto all'originale (i bordi, riscritti):
//    * ritorna `PdfExtraction` tipizzato invece di una `String` JSON;
//    * conforma a `PdfExtracting` (metodo d'istanza) invece di `@objc static`;
//    * nessuna dipendenza da `ScaboLog` (le metriche content-free erano una
//      preoccupazione dell'era RN; non fanno parte del contratto del seam).
//
//  Cosa NON cambia (il cuore, verbatim): la convenzione coordinate (page-local,
//  origin bottom-left, relativa al cropBox — la stessa che `summarizeLine` e
//  `detectFurniture` consumano via `yTop/height`), la preservazione degli span
//  whitespace (spaziatura inter-parola), lo split su "\n" dentro un run che
//  attraversa più righe impaginate, la regola di drop (scarta una riga solo se
//  tutti gli span uniti danno whitespace), il fallback scanned (`plainLines`),
//  la risoluzione colore RGB-poi-bianco, i messaggi d'errore italiani.
//
//  L'originale nel pod resta intatto e dormiente (ancora referenziato dal
//  TurboModule RN) finché non si smantella RN: il trapianto è puramente additivo
//  e non tocca l'apparato Pods/RN.
//
//  Compute puro: nessun requisito di main-thread; safe da chiamare off-main.
//

import Foundation
import PDFKit
import ScaboCore
import UIKit

/// Structured PDF text extraction via Apple PDFKit, behind the `PdfExtracting`
/// seam. Produces the per-span schema (`version: 2`) that ScaboCore's classifier
/// consumes: per page, laid-out lines, each a sequence of spans carrying
/// text + font size + bold + italic + resolved colour + page-local bbox.
struct PdfKitExtractor: PdfExtracting {

    /// Extracts the PDF at `uri` (a local `file://` URI or a filesystem path)
    /// into a `PdfExtraction`. Throws an `NSError` carrying a readable Italian
    /// message when the path is invalid, the PDF cannot be opened, or it is
    /// password-protected.
    func extract(fromUri uri: String) throws -> PdfExtraction {
        guard let url = Self.fileURL(from: uri) else {
            throw Self.makeError("Percorso del file PDF non valido.")
        }
        guard let document = PDFDocument(url: url) else {
            throw Self.makeError("Impossibile aprire il PDF. Potrebbe essere danneggiato.")
        }
        if document.isLocked {
            throw Self.makeError("Il PDF è protetto da password e non può essere letto.")
        }

        let pageCount = document.pageCount
        var pages: [PdfPageExtraction] = []
        pages.reserveCapacity(pageCount)
        for index in 0..<pageCount {
            guard let page = document.page(at: index) else { continue }
            let cropBox = page.bounds(for: .cropBox)
            let lines = Self.lines(for: page, cropBox: cropBox)
            pages.append(PdfPageExtraction(
                pageIndex: index,
                width: Double(cropBox.width),
                height: Double(cropBox.height),
                lines: lines
            ))
        }

        return PdfExtraction(version: 2, pageCount: pageCount, pages: pages)
    }

    // MARK: - Line / span extraction

    /// Walks a page's attributed string, grouping uniform-attribute runs into
    /// spans and breaking spans into lines at laid-out "\n" boundaries. Falls
    /// back to the plain page string (one span, no font/colour/bbox) for scanned
    /// / image-only PDFs.
    private static func lines(for page: PDFPage, cropBox: CGRect) -> [PdfTextLine] {
        guard let attributed = page.attributedString, attributed.length > 0 else {
            return plainLines(for: page)
        }

        let full = attributed.string as NSString
        var result: [PdfTextLine] = []
        var currentSpans: [PdfSpan] = []

        func flush() {
            // Keep whitespace-only spans (inter-word spaces that PDFKit splits
            // into their own attribute run) so the joined line text preserves
            // spacing; drop only a line whose text is entirely whitespace.
            let joined = currentSpans.map { $0.text }.joined()
            if !joined.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                result.append(PdfTextLine(
                    spans: currentSpans,
                    bbox: unionBBox(currentSpans.map { $0.bbox })
                ))
            }
            currentSpans = []
        }

        attributed.enumerateAttributes(
            in: NSRange(location: 0, length: full.length),
            options: []
        ) { attrs, range, _ in
            var size = 0.0
            var bold = false
            var italic = false
            if let font = attrs[.font] as? UIFont {
                size = Double(font.pointSize)
                let traits = font.fontDescriptor.symbolicTraits
                bold = traits.contains(.traitBold)
                italic = traits.contains(.traitItalic)
            }
            let colour = hexString(from: attrs[.foregroundColor] as? UIColor)

            // A run can span several laid-out lines: PDFKit separates them
            // with "\n".
            let runText = full.substring(with: range)
            let segments = runText.components(separatedBy: "\n")
            var offset = 0
            for (i, segment) in segments.enumerated() {
                if i > 0 {
                    flush()
                    offset += 1 // the "\n" itself
                }
                let segLen = (segment as NSString).length
                if segLen > 0 {
                    let spanRange = NSRange(location: range.location + offset, length: segLen)
                    let bbox = spanBBox(page: page, range: spanRange, cropBox: cropBox)
                    currentSpans.append(PdfSpan(
                        text: segment, fontSize: size, bold: bold,
                        italic: italic, color: colour, bbox: bbox
                    ))
                }
                offset += segLen
            }
        }
        flush()
        return result
    }

    /// Image / scanned fallback: page text as lines of one bare span (no font,
    /// colour or geometry) so the reader still degrades gracefully.
    private static func plainLines(for page: PDFPage) -> [PdfTextLine] {
        guard let string = page.string else { return [] }
        return string.components(separatedBy: "\n").compactMap { raw in
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return nil }
            let zero = BBox(x: 0, y: 0, width: 0, height: 0)
            let span = PdfSpan(text: trimmed, fontSize: 0, bold: false, italic: false,
                               color: "#000000", bbox: zero)
            return PdfTextLine(spans: [span], bbox: zero)
        }
    }

    // MARK: - Geometry / colour helpers

    /// Page-local bbox of a character range via a PDFKit selection. Returns a
    /// `BBox` (origin bottom-left, cropBox-relative), or a zero box when the
    /// range has no resolvable geometry.
    private static func spanBBox(page: PDFPage, range: NSRange, cropBox: CGRect) -> BBox {
        let zero = BBox(x: 0, y: 0, width: 0, height: 0)
        guard range.length > 0, let selection = page.selection(for: range) else {
            return zero
        }
        let rect = selection.bounds(for: page)
        if rect.isNull || rect.isInfinite || rect.isEmpty {
            return zero
        }
        return BBox(
            x: round2(Double(rect.minX - cropBox.minX)),
            y: round2(Double(rect.minY - cropBox.minY)),
            width: round2(Double(rect.width)),
            height: round2(Double(rect.height))
        )
    }

    /// Union of page-local bboxes.
    private static func unionBBox(_ boxes: [BBox]) -> BBox {
        let valid = boxes.filter { $0.width > 0 || $0.height > 0 }
        guard let first = valid.first else { return BBox(x: 0, y: 0, width: 0, height: 0) }
        var minX = first.x, minY = first.y
        var maxX = first.x + first.width, maxY = first.y + first.height
        for b in valid.dropFirst() {
            minX = min(minX, b.x); minY = min(minY, b.y)
            maxX = max(maxX, b.x + b.width); maxY = max(maxY, b.y + b.height)
        }
        return BBox(x: round2(minX), y: round2(minY),
                    width: round2(maxX - minX), height: round2(maxY - minY))
    }

    /// Resolves a colour to "#rrggbb". Absent colour (PDF default) → black.
    private static func hexString(from color: UIColor?) -> String {
        guard let color = color else { return "#000000" }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if color.getRed(&r, green: &g, blue: &b, alpha: &a) {
            return hex(r, g, b)
        }
        var w: CGFloat = 0
        if color.getWhite(&w, alpha: &a) {
            return hex(w, w, w)
        }
        return "#000000"
    }

    private static func hex(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> String {
        func c(_ v: CGFloat) -> Int { max(0, min(255, Int((v * 255).rounded()))) }
        return String(format: "#%02X%02X%02X", c(r), c(g), c(b))
    }

    private static func round2(_ v: Double) -> Double {
        (v * 100).rounded() / 100
    }

    // MARK: - Misc helpers

    private static func fileURL(from uri: String) -> URL? {
        if let url = URL(string: uri), url.isFileURL {
            return url
        }
        return URL(fileURLWithPath: uri)
    }

    private static func makeError(_ message: String) -> NSError {
        NSError(
            domain: "PdfKitExtractor",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}
