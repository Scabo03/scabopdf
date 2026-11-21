//
//  DisplayedPageRenderTests.swift
//  ScaboPageStructureTests
//
//  La resa della pagina COME SI MOSTRA (giro «migliorie del banco nelle app», 2026-11-21): con il riquadro di ritaglio spostato
//  dall'origine e con la pagina ruotata, la resa per il modello e il ritaglio delle risorse visive sono quelli della pagina diritta col
//  riquadro all'origine; sulle pagine diritte col riquadro all'origine sono identici al byte alla resa di prima. La resa e il ritaglio di
//  prima sono copiati qui, come riferimento del difetto: sulle pagine spostate e ruotate non danno la pagina (prova al contrario dentro i
//  test; e i test della pagina spostata e ruotata, fatti girare sul codice di prima, falliscono). Pagine sintetiche, nessun testo.
//

import CoreGraphics
import Foundation
import ImageIO
import PDFKit
import XCTest
@testable import ScaboPageStructure

final class DisplayedPageRenderTests: XCTestCase {

    static let width: CGFloat = 420, height: CGFloat = 595

    /// Una pagina con contrassegni noti nello spazio della pagina diritta (larghezza × altezza): un quadrato nero in alto a sinistra, una
    /// barra grigia in basso, un riquadro scuro a destra. `rotation`: il contenuto sta nel riquadro non ruotato girato in senso antiorario
    /// e la pagina dichiara `/Rotate rotation` (così si mostra diritta, come la salvano gli scanner). `margin` > 0: MediaBox più grande di
    /// `margin` per lato e CropBox spostato sul contenuto.
    static func page(rotation: Int, margin: CGFloat = 0) throws -> (PDFPage, URL) {
        let (w, h) = rotation == 90 || rotation == 270 ? (height, width) : (width, height)
        var box = CGRect(x: 0, y: 0, width: w + 2 * margin, height: h + 2 * margin)
        let dir = FileManager.default.temporaryDirectory
        let raw = dir.appendingPathComponent("resa-grezza-\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: raw) }
        guard let ctx = CGContext(raw as CFURL, mediaBox: &box, nil) else { throw NSError(domain: "prova", code: 1) }
        ctx.beginPDFPage(nil)
        ctx.translateBy(x: margin, y: margin)
        switch rotation {
        case 90: ctx.translateBy(x: height, y: 0); ctx.rotate(by: .pi / 2)
        case 180: ctx.translateBy(x: width, y: height); ctx.rotate(by: .pi)
        case 270: ctx.translateBy(x: 0, y: width); ctx.rotate(by: -.pi / 2)
        default: break
        }
        ctx.setFillColor(CGColor(gray: 0, alpha: 1)); ctx.fill(CGRect(x: 30, y: height - 110, width: 80, height: 80))
        ctx.setFillColor(CGColor(gray: 0.5, alpha: 1)); ctx.fill(CGRect(x: 30, y: 30, width: width - 60, height: 24))
        ctx.setFillColor(CGColor(gray: 0.2, alpha: 1)); ctx.fill(CGRect(x: width - 150, y: 250, width: 110, height: 140))
        ctx.endPDFPage()
        ctx.closePDF()
        let doc = try XCTUnwrap(PDFDocument(url: raw))
        let p = try XCTUnwrap(doc.page(at: 0))
        if margin > 0 { p.setBounds(CGRect(x: margin, y: margin, width: w, height: h), for: .cropBox) }
        p.rotation = rotation
        let url = dir.appendingPathComponent("resa-\(rotation)-\(Int(margin))-\(UUID().uuidString).pdf")
        XCTAssertTrue(doc.write(to: url))
        let d = try XCTUnwrap(PDFDocument(url: url))
        documentiVivi.append(d)
        return (try XCTUnwrap(d.page(at: 0)), url)
    }

    /// La pagina tiene il suo documento solo debolmente: i documenti della prova restano vivi fino alla fine (PDFKit non vuole che una
    /// pagina si disegni dopo che il suo documento è stato rilasciato).
    static var documentiVivi: [PDFDocument] = []

    static let cases: [(rotation: Int, margin: CGFloat)] = [(0, 30), (90, 0), (180, 0), (270, 0), (90, 30), (180, 30), (270, 30)]

    /// LA RESA DI PRIMA (fino a `13d02d9`), copiata al byte: misura del riquadro non ruotato e traslazione sul riquadro.
    static func oldRenderPage(_ page: PDFPage) -> (CGImage, Double, Double)? {
        let box = page.bounds(for: .cropBox)
        let w = Int(box.width.rounded()), h = Int(box.height.rounded())
        guard w > 0, h > 0 else { return nil }
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.scaleBy(x: CGFloat(w) / box.width, y: CGFloat(h) / box.height); ctx.translateBy(x: -box.minX, y: -box.minY)
        page.draw(with: .cropBox, to: ctx)
        guard let img = ctx.makeImage() else { return nil }
        guard let ctx2 = CGContext(data: nil, width: 640, height: 640, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        ctx2.interpolationQuality = .medium
        ctx2.draw(img, in: CGRect(x: 0, y: 0, width: 640, height: 640))
        guard let img640 = ctx2.makeImage() else { return nil }
        return (img640, Double(box.width), Double(box.height))
    }

    /// IL RITAGLIO DI PRIMA (fino a `13d02d9`), copiato al byte: il rettangolo nelle coordinate del riquadro di ritaglio del PDF.
    static func oldPngData(page: PDFPage, region: [Double], dpi: Double = 300, maxPixels: Int = 3000, margin: Double = 4) -> Data? {
        let crop = page.bounds(for: .cropBox)
        guard let rect = RegionCropper.cropRect(region: region, cropBox: crop, margin: margin) else { return nil }
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

    static func bytes(_ i: CGImage) -> Data? { i.dataProvider?.data as Data? }

    /// Differenza media dei pixel (0-255, in grigio) fra due immagini della stessa misura; nil se la misura è diversa.
    static func difference(_ a: CGImage, _ b: CGImage) -> Double? {
        guard a.width == b.width, a.height == b.height else { return nil }
        func gray(_ i: CGImage) -> [UInt8] {
            var px = [UInt8](repeating: 0, count: i.width * i.height)
            let c = CGContext(data: &px, width: i.width, height: i.height, bitsPerComponent: 8, bytesPerRow: i.width,
                              space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
            c.draw(i, in: CGRect(x: 0, y: 0, width: i.width, height: i.height))
            return px
        }
        let x = gray(a), y = gray(b)
        return Double(zip(x, y).reduce(0) { $0 + abs(Int($1.0) - Int($1.1)) }) / Double(x.count)
    }

    static func image(_ png: Data) -> CGImage? {
        guard let s = CGImageSourceCreateWithData(png as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(s, 0, nil)
    }

    // MARK: la resa per il modello

    func test_displayedSize_swapsSidesAt90And270() throws {
        for r in [0, 90, 180, 270] {
            let (p, url) = try Self.page(rotation: r, margin: 30); defer { try? FileManager.default.removeItem(at: url) }
            XCTAssertEqual(HeronPageRenderer.rotation(of: p), r)
            let m = HeronPageRenderer.displayedSize(of: p)
            XCTAssertEqual(m.width, Self.width, accuracy: 0.01, "rotazione \(r)")
            XCTAssertEqual(m.height, Self.height, accuracy: 0.01, "rotazione \(r)")
        }
    }

    /// Sulle pagine diritte col riquadro all'origine (quasi tutto il corpus) la resa è quella di prima, al byte.
    func test_renderPage_straightAtOrigin_identicalToOldRender() throws {
        let (p, url) = try Self.page(rotation: 0); defer { try? FileManager.default.removeItem(at: url) }
        let new = try XCTUnwrap(HeronPageRenderer.renderPage(p)), old = try XCTUnwrap(Self.oldRenderPage(p))
        XCTAssertEqual(Self.bytes(new.0), Self.bytes(old.0), "al byte")
        XCTAssertEqual(new.1, old.1); XCTAssertEqual(new.2, old.2)
    }

    /// Col riquadro spostato e con la pagina ruotata la resa è quella della pagina diritta, con la misura mostrata.
    func test_renderPage_shiftedOrRotated_isTheStraightPage() throws {
        let (d, u0) = try Self.page(rotation: 0); defer { try? FileManager.default.removeItem(at: u0) }
        let ref = try XCTUnwrap(HeronPageRenderer.renderPage(d))
        for c in Self.cases {
            let (p, url) = try Self.page(rotation: c.rotation, margin: c.margin); defer { try? FileManager.default.removeItem(at: url) }
            let r = try XCTUnwrap(HeronPageRenderer.renderPage(p))
            XCTAssertEqual(r.1, Double(Self.width), accuracy: 0.01, "rotazione \(c.rotation), margine \(c.margin): larghezza mostrata")
            XCTAssertEqual(r.2, Double(Self.height), accuracy: 0.01, "rotazione \(c.rotation), margine \(c.margin): altezza mostrata")
            let diff = try XCTUnwrap(Self.difference(r.0, ref.0))
            XCTAssertLessThan(diff, 2.0, "rotazione \(c.rotation), margine \(c.margin): la stessa pagina (differenza media \(diff))")
        }
    }

    /// La prova al contrario, dentro il test: la resa di prima, sulle stesse pagine, non dava la pagina diritta.
    func test_oldRender_shiftedOrRotated_wasWrong() throws {
        let (d, u0) = try Self.page(rotation: 0); defer { try? FileManager.default.removeItem(at: u0) }
        let ref = try XCTUnwrap(HeronPageRenderer.renderPage(d))
        for c in Self.cases where c.rotation != 180 || c.margin > 0 {   // a 180 gradi col riquadro all'origine la tela era già giusta
            let (p, url) = try Self.page(rotation: c.rotation, margin: c.margin); defer { try? FileManager.default.removeItem(at: url) }
            let old = try XCTUnwrap(Self.oldRenderPage(p))
            let diff = try XCTUnwrap(Self.difference(old.0, ref.0))
            let sizeWrong = abs(old.1 - Double(Self.width)) > 0.01
            XCTAssertTrue(sizeWrong || diff > 5.0, "rotazione \(c.rotation), margine \(c.margin): di prima non era la pagina (differenza \(diff))")
        }
    }

    // MARK: il ritaglio delle risorse visive

    /// La regione del riquadro scuro, nello spazio della pagina mostrata (origine in alto a sinistra).
    static let region: [Double] = [Double(width) - 150, Double(height) - 390, Double(width) - 40, Double(height) - 250]

    func test_pngData_straightAtOrigin_identicalToOldCrop() throws {
        let (p, url) = try Self.page(rotation: 0); defer { try? FileManager.default.removeItem(at: url) }
        let new = try XCTUnwrap(RegionCropper.pngData(page: p, region: Self.region))
        let old = try XCTUnwrap(Self.oldPngData(page: p, region: Self.region))
        XCTAssertEqual(new, old, "al byte")
    }

    /// Col riquadro spostato (le pagine dei quattro volumi) il ritaglio è la regione, come sulla pagina col riquadro all'origine; il
    /// ritaglio di prima usciva spostato.
    func test_pngData_shiftedCropBox_cropsTheRegion() throws {
        let (d, u0) = try Self.page(rotation: 0); defer { try? FileManager.default.removeItem(at: u0) }
        let ref = try XCTUnwrap(Self.image(try XCTUnwrap(RegionCropper.pngData(page: d, region: Self.region))))
        let (p, url) = try Self.page(rotation: 0, margin: 30); defer { try? FileManager.default.removeItem(at: url) }
        let new = try XCTUnwrap(Self.image(try XCTUnwrap(RegionCropper.pngData(page: p, region: Self.region))))
        let diff = try XCTUnwrap(Self.difference(new, ref))
        XCTAssertLessThan(diff, 2.0, "la stessa regione (differenza media \(diff))")
        let old = try XCTUnwrap(Self.image(try XCTUnwrap(Self.oldPngData(page: p, region: Self.region))))
        let oldDiff = Self.difference(old, ref) ?? .infinity
        XCTAssertGreaterThan(oldDiff, 5.0, "il ritaglio di prima usciva spostato (differenza media \(oldDiff))")
    }

    // MARK: i riquadri salvati da una lettura di prima (giro «modulo e sommario», 2026-11-21)

    /// Lo spazio della resa di prima è il ritaglio di prima, al byte, su ogni pagina diritta (col riquadro all'origine o spostato).
    func test_pngData_earlierRenderSpace_isTheOldCrop_byteForByte() throws {
        for margin: CGFloat in [0, 30] {
            let (p, url) = try Self.page(rotation: 0, margin: margin); defer { try? FileManager.default.removeItem(at: url) }
            let legacy = try XCTUnwrap(RegionCropper.pngData(page: p, region: Self.region, space: .cropBoxOfTheEarlierRender))
            XCTAssertEqual(legacy, try XCTUnwrap(Self.oldPngData(page: p, region: Self.region)), "margine \(margin): al byte")
        }
    }

    /// Il caso delle risorse già salvate: sulla pagina col riquadro spostato la resa di prima faceva scivolare la pagina di quanto è
    /// spostato il riquadro, e il modello salvava la regione scivolata. Ritagliata nel suo spazio, quella regione dà ancora la parte
    /// giusta della pagina; ritagliata come una regione nuova uscirebbe spostata.
    func test_pngData_regionSavedByEarlierRender_staysRightInItsSpace() throws {
        let m = 30.0
        let (d, u0) = try Self.page(rotation: 0); defer { try? FileManager.default.removeItem(at: u0) }
        let ref = try XCTUnwrap(Self.image(try XCTUnwrap(RegionCropper.pngData(page: d, region: Self.region))))
        let (p, url) = try Self.page(rotation: 0, margin: CGFloat(m)); defer { try? FileManager.default.removeItem(at: url) }
        // La regione come la salvava la resa di prima: a sinistra e in basso di quanto è spostato il riquadro.
        let saved = [Self.region[0] - m, Self.region[1] + m, Self.region[2] - m, Self.region[3] + m]
        let inItsSpace = try XCTUnwrap(Self.image(try XCTUnwrap(
            RegionCropper.pngData(page: p, region: saved, space: .cropBoxOfTheEarlierRender))))
        let diff = try XCTUnwrap(Self.difference(inItsSpace, ref))
        XCTAssertLessThan(diff, 2.0, "nel suo spazio, la parte giusta (differenza media \(diff))")
        let asNew = try XCTUnwrap(Self.image(try XCTUnwrap(RegionCropper.pngData(page: p, region: saved))))
        let wrong = Self.difference(asNew, ref) ?? .infinity
        XCTAssertGreaterThan(wrong, 5.0, "presa come regione nuova uscirebbe spostata (differenza media \(wrong))")
    }
}
