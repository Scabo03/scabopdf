//
//  RegionCropperTests.swift
//  ScaboPageStructureTests
//
//  Il ritaglio: solo la regione (con un margine di pochi punti), mai la pagina intera, alla risoluzione chiesta.
//

import XCTest
import PDFKit
import ImageIO
@testable import ScaboPageStructure

final class RegionCropperTests: XCTestCase {

    private func pixelSize(_ png: Data) -> (Int, Int) {
        let src = CGImageSourceCreateWithData(png as CFData, nil)!
        let img = CGImageSourceCreateImageAtIndex(src, 0, nil)!
        return (img.width, img.height)
    }

    func test_ritaglioDellaSolaRegione_a300dpi() throws {
        let url = SyntheticPDF.make { ctx in ctx.stroke(CGRect(x: 100, y: 300, width: 200, height: 100)) }
        let page = try XCTUnwrap(PDFDocument(url: url)?.page(at: 0))
        // regione alto-sinistra: l=100, t=842-400=442, r=300, b=542; margine 4 pt per lato
        let png = try XCTUnwrap(RegionCropper.pngData(page: page, region: [100, 442, 300, 542], dpi: 300))
        let (w, h) = pixelSize(png)
        XCTAssertEqual(w, Int(((200 + 8) * 300.0 / 72).rounded()))
        XCTAssertEqual(h, Int(((100 + 8) * 300.0 / 72).rounded()))
    }

    func test_latoLungoLimitato() throws {
        let url = SyntheticPDF.make { _ in }
        let page = try XCTUnwrap(PDFDocument(url: url)?.page(at: 0))
        let png = try XCTUnwrap(RegionCropper.pngData(page: page, region: [20, 20, 575, 500], dpi: 300, maxPixels: 1000))
        let (w, h) = pixelSize(png)
        XCTAssertLessThanOrEqual(max(w, h), 1000)
    }

    func test_maiLaPaginaIntera() throws {
        let url = SyntheticPDF.make { _ in }
        let page = try XCTUnwrap(PDFDocument(url: url)?.page(at: 0))
        XCTAssertNil(RegionCropper.pngData(page: page, region: [0, 0, 595, 842]))
        XCTAssertNil(RegionCropper.pngData(page: page, region: [10, 10, 585, 830]))
    }

    func test_regioneVuotaOMalformata() {
        let box = CGRect(x: 0, y: 0, width: 595, height: 842)
        XCTAssertNil(RegionCropper.cropRect(region: [100, 100, 100, 200], cropBox: box))
        XCTAssertNil(RegionCropper.cropRect(region: [1, 2, 3], cropBox: box))
    }

    func test_cropBoxSpostato_coordinateRelative() {
        let box = CGRect(x: 30, y: 40, width: 500, height: 700)
        let r = RegionCropper.cropRect(region: [10, 20, 110, 70], cropBox: box, margin: 0)
        XCTAssertEqual(r, CGRect(x: 40, y: 40 + 700 - 70, width: 100, height: 50))
    }
}
