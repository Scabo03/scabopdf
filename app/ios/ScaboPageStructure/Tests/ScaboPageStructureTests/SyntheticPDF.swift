//
//  SyntheticPDF.swift
//  ScaboPageStructureTests
//
//  PDF sintetici disegnati al volo con CoreGraphics: nessuna pagina reale, nessun testo di volumi.
//

import Foundation
import CoreGraphics
import CoreText

enum SyntheticPDF {
    /// Scrive un PDF di una pagina (595×842 pt) disegnato dal blocco e ne restituisce l'URL temporaneo.
    static func make(width: CGFloat = 595, height: CGFloat = 842, _ draw: (CGContext) -> Void) -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("sintetico-\(UUID().uuidString).pdf")
        var box = CGRect(x: 0, y: 0, width: width, height: height)
        let ctx = CGContext(url as CFURL, mediaBox: &box, nil)!
        ctx.beginPDFPage(nil)
        draw(ctx)
        ctx.endPDFPage()
        ctx.closePDF()
        return url
    }

    /// Una piccola immagine a tinta unita (nessun contenuto).
    static func image(_ w: Int = 40, _ h: Int = 30) -> CGImage {
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        ctx.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage()!
    }

    /// Testo neutro (parole di prova, mai di un volume) in Helvetica.
    static func text(_ ctx: CGContext, _ s: String, x: CGFloat, y: CGFloat, size: CGFloat = 11) {
        let font = CTFontCreateWithName("Helvetica" as CFString, size, nil)
        let attr = NSAttributedString(string: s, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font])
        let line = CTLineCreateWithAttributedString(attr)
        ctx.textPosition = CGPoint(x: x, y: y)
        CTLineDraw(line, ctx)
    }
}
