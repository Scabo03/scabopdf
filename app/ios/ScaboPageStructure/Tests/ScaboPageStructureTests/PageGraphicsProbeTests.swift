//
//  PageGraphicsProbeTests.swift
//  ScaboPageStructureTests
//
//  La sonda grafica (prefiltro) su pagine sintetiche: conta filetti, rettangoli, curve, immagini.
//

import XCTest
import CoreGraphics
@testable import ScaboPageStructure

final class PageGraphicsProbeTests: XCTestCase {

    private func profile(_ url: URL) -> PageGraphicsProfile {
        let doc = CGPDFDocument(url as CFURL)!
        return PageGraphicsProbe.profile(of: doc.page(at: 1)!)
    }

    func test_paginaDiSoloTesto_nessunaGrafica() {
        let url = SyntheticPDF.make { ctx in
            for k in 0..<20 { SyntheticPDF.text(ctx, "riga di prova numero \(k)", x: 72, y: 760 - CGFloat(k) * 14) }
        }
        let p = profile(url)
        XCTAssertEqual(p.images, 0); XCTAssertEqual(p.hRules, 0); XCTAssertEqual(p.vRules, 0)
        XCTAssertEqual(p.rects, 0); XCTAssertEqual(p.curves, 0)
    }

    func test_grigliaDaTabella_filettiOrizzontaliEVerticali() {
        let url = SyntheticPDF.make { ctx in
            ctx.setLineWidth(0.5)
            for k in 0..<4 { ctx.move(to: CGPoint(x: 72, y: 600 - CGFloat(k) * 20)); ctx.addLine(to: CGPoint(x: 472, y: 600 - CGFloat(k) * 20)) }
            for k in 0..<3 { ctx.move(to: CGPoint(x: 72 + CGFloat(k) * 200, y: 600)); ctx.addLine(to: CGPoint(x: 72 + CGFloat(k) * 200, y: 540)) }
            ctx.strokePath()
        }
        let p = profile(url)
        XCTAssertEqual(p.hRules, 4); XCTAssertEqual(p.vRules, 3); XCTAssertEqual(p.diagonals, 0)
    }

    func test_filettoDiSeparazioneDelleNote_unSoloFiletto() {
        let url = SyntheticPDF.make { ctx in
            ctx.setLineWidth(0.5); ctx.move(to: CGPoint(x: 72, y: 150)); ctx.addLine(to: CGPoint(x: 172, y: 150)); ctx.strokePath()
        }
        let p = profile(url)
        XCTAssertEqual(p.hRules, 1); XCTAssertEqual(p.vRules, 0)
    }

    func test_rettangoloECurve() {
        let url = SyntheticPDF.make { ctx in
            ctx.stroke(CGRect(x: 100, y: 300, width: 200, height: 120))
            ctx.addEllipse(in: CGRect(x: 320, y: 300, width: 80, height: 80)); ctx.strokePath()
        }
        let p = profile(url)
        XCTAssertEqual(p.rects, 1)
        XCTAssertGreaterThanOrEqual(p.curves, 4)
    }

    func test_immagine_superficieInFrazioneDiPagina() {
        let url = SyntheticPDF.make { ctx in ctx.draw(SyntheticPDF.image(), in: CGRect(x: 100, y: 400, width: 297.5, height: 210.5)) }
        let p = profile(url)
        XCTAssertEqual(p.images, 1); XCTAssertEqual(p.fullPageImages, 0)
        XCTAssertEqual(p.imageMaxAreaFraction, (297.5 * 210.5) / (595 * 842), accuracy: 1e-3)
    }

    func test_scansioneATuttaPagina() {
        let url = SyntheticPDF.make { ctx in ctx.draw(SyntheticPDF.image(), in: CGRect(x: 0, y: 0, width: 595, height: 842)) }
        let p = profile(url)
        XCTAssertEqual(p.images, 1); XCTAssertEqual(p.fullPageImages, 1)
    }

    func test_sfondoATuttaPaginaNonContaComeRettangolo() {
        let url = SyntheticPDF.make { ctx in ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: 595, height: 842)) }
        XCTAssertEqual(profile(url).rects, 0)
    }
}

extension PageGraphicsProbeTests {
    func test_riquadriDipinti_inCoordinateAltoSinistra() {
        let url = SyntheticPDF.make { ctx in
            ctx.stroke(CGRect(x: 100, y: 300, width: 200, height: 120))          // alto-sinistra: t = 842-420 = 422
            ctx.draw(SyntheticPDF.image(), in: CGRect(x: 50, y: 600, width: 100, height: 80))
            ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: 595, height: 842))
        }
        let doc = CGPDFDocument(url as CFURL)!
        let p = PageGraphicsProbe.profile(of: doc.page(at: 1)!, collectBoxes: true)
        XCTAssertEqual(p.paintedBoxes.count, 2, "il rettangolo e l'immagine; lo sfondo a tutta pagina no")
        let rect = p.paintedBoxes.first { abs($0[0] - 100) < 1 }!
        XCTAssertEqual(rect[1], 422, accuracy: 1); XCTAssertEqual(rect[2], 300, accuracy: 1); XCTAssertEqual(rect[3], 542, accuracy: 1)
        let img = p.paintedBoxes.first { abs($0[0] - 50) < 1 }!
        XCTAssertEqual(img[1], 842 - 680, accuracy: 1); XCTAssertEqual(img[3], 842 - 600, accuracy: 1)
        XCTAssertTrue(PageGraphicsProbe.profile(of: doc.page(at: 1)!).paintedBoxes.isEmpty, "senza richiesta non si raccolgono")
    }
}

extension PageGraphicsProbeTests {
    private func profile(h: Int = 0, v: Int = 0, r: Int = 0, img: Double = 0) -> PageGraphicsProfile {
        var p = PageGraphicsProfile(); p.hRules = h; p.vRules = v; p.rects = r; p.imageMaxAreaFraction = img; p.images = img > 0 ? 1 : 0
        return p
    }

    func test_prefiltro_paginaTipicaDelVolumeEImmagini() {
        // Volume con 2 filetti su ogni pagina (testatina e nota): solo le pagine che ne hanno molti di più, o un'immagine vera.
        var pages = Array(repeating: profile(h: 2), count: 20)
        pages[3] = profile(h: 9)              // tabella filettata: +7 orizzontali
        pages[5] = profile(h: 2, img: 0.20)   // figura
        pages[7] = profile(h: 2, img: 0.02)   // logo: no
        pages[9] = profile(h: 2, img: 0.95)   // scansione a tutta pagina: no
        pages[11] = profile(h: 3, v: 5)       // griglia: +5 verticali
        pages[13] = profile(h: 2, r: 3)       // riquadri: +3
        pages[15] = profile(h: 6)             // +4 orizzontali: sotto soglia
        XCTAssertEqual(PageGraphicsProbe.pagesForModel(pages), [3, 5, 11, 13])
    }

    func test_prefiltro_volumeConArredoPesante_nonVaTuttoAlModello() {
        // Ogni pagina ha 18 filetti disegnati (filigrana): la pagina tipica li assorbe.
        var pages = Array(repeating: profile(h: 10, v: 8), count: 30)
        pages[10] = profile(h: 17, v: 8)
        XCTAssertEqual(PageGraphicsProbe.pagesForModel(pages), [10])
        XCTAssertEqual(PageGraphicsProbe.pagesForModel([]), [])
    }
}
