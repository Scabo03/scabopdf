//
//  RegionCropper.swift
//  ScaboPageStructure
//
//  Il ritaglio di una risorsa visiva come immagine PNG, per l'azione «Estrai come immagine»
//  (`LAYER2_PRODUCT_DECISIONS.md` § 7.9 e § 14.2: estrazione proporzionata, un riquadro alla volta).
//  Contiene SOLO la regione della risorsa, con un margine di pochi punti: mai la pagina intera. Una regione
//  che coprisse quasi tutta la pagina non si ritaglia (`nil`). Nessun UIKit: CoreGraphics + PDFKit + ImageIO,
//  identico su iOS e macOS.
//

import Foundation
import PDFKit
import CoreGraphics
import ImageIO

public enum RegionCropper {

    /// Frazione della pagina oltre la quale un ritaglio non si fa (sarebbe, di fatto, la pagina intera).
    public static let maxPageFraction = 0.85

    /// Il rettangolo da ritagliare in coordinate PDF della pagina (origine basso-sinistra), già col margine
    /// e chiuso dentro il cropBox; `nil` se la regione è vuota o copre troppa pagina.
    /// `region` è `[l, t, r, b]` in punti, origine alto-sinistra, relativa al cropBox.
    public static func cropRect(region: [Double], cropBox: CGRect, margin: Double = 4) -> CGRect? {
        guard region.count == 4 else { return nil }
        let l = region[0], t = region[1], r = region[2], b = region[3]
        guard r > l, b > t else { return nil }
        let pageArea = Double(cropBox.width * cropBox.height)
        guard pageArea > 0, (r - l) * (b - t) < maxPageFraction * pageArea else { return nil }
        var rect = CGRect(x: cropBox.minX + CGFloat(l - margin), y: cropBox.maxY - CGFloat(b + margin),
                          width: CGFloat(r - l + 2 * margin), height: CGFloat(b - t + 2 * margin))
        rect = rect.intersection(cropBox)
        guard !rect.isNull, rect.width > 1, rect.height > 1 else { return nil }
        guard Double(rect.width * rect.height) < maxPageFraction * pageArea else { return nil }
        return rect
    }

    /// PNG del ritaglio a `dpi` punti per pollice (300 di norma), con il lato lungo limitato a `maxPixels`.
    public static func pngData(page: PDFPage, region: [Double], dpi: Double = 300, maxPixels: Int = 3000, margin: Double = 4) -> Data? {
        let crop = page.bounds(for: .cropBox)
        guard let rect = cropRect(region: region, cropBox: crop, margin: margin) else { return nil }
        var scale = CGFloat(dpi / 72)
        let longSide = max(rect.width, rect.height) * scale
        if longSide > CGFloat(maxPixels) { scale *= CGFloat(maxPixels) / longSide }
        let w = Int((rect.width * scale).rounded()), h = Int((rect.height * scale).rounded())
        guard w > 0, h > 0, let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                                 space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.scaleBy(x: scale, y: scale)
        ctx.translateBy(x: -rect.minX, y: -rect.minY)
        ctx.clip(to: rect)
        page.draw(with: .cropBox, to: ctx)
        guard let img = ctx.makeImage() else { return nil }
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data as CFMutableData, "public.png" as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, img, nil)
        return CGImageDestinationFinalize(dest) ? data as Data : nil
    }
}
