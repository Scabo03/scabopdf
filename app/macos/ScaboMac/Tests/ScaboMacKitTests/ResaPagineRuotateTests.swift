//
//  ResaPagineRuotateTests.swift
//  ScaboMacKitTests — la resa delle pagine ruotate (giro globale del banco OCR, 2026-11-19): la misura mostrata, l'identità al byte con
//  la resa di prima sulle pagine diritte (quelle di tutto il banco del giro 1), la resa per il modello d'impaginazione identica a quella
//  del modulo condiviso sulle pagine diritte e corretta sulle altre; e la resa di prima, copiata qui, che sulle pagine ruotate taglia il
//  terzo alto (il difetto, tenuto come riferimento). Pagine sintetiche di `PagineRuotateScansioniTests`.
//
import CoreGraphics
import PDFKit
import ScaboPageStructure
import XCTest
@testable import ScaboMacKit

final class ResaPagineRuotateTests: XCTestCase {

    private typealias P = PagineRuotateScansioniTests

    private func file(_ nome: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("\(nome)-\(UUID().uuidString).pdf")
    }

    private func pagina(_ rotazione: Int, _ margine: CGFloat = 0) throws -> (PDFPage, URL) {
        let url = try P.scansione(rotazione: rotazione, margine: margine, in: file("p\(rotazione)"))
        return (try XCTUnwrap(PDFDocument(url: url)?.page(at: 0)), url)
    }

    /// LA RESA DI PRIMA (fino a `214a07f`), copiata al byte: misura non ruotata e traslazione sul riquadro.
    static func resaDiPrima(_ pagina: PDFPage, latoLungo: CGFloat = LetturaScansioni.latoLungoPixel) -> CGImage? {
        let box = pagina.bounds(for: .cropBox)
        guard box.width > 0, box.height > 0 else { return nil }
        let scala = min(300.0 / 72.0, latoLungo / max(box.width, box.height))
        let w = Int((box.width * scala).rounded()), h = Int((box.height * scala).rounded())
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        ctx.setFillColor(gray: 1, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.scaleBy(x: scala, y: scala)
        ctx.translateBy(x: -box.minX, y: -box.minY)
        pagina.draw(with: .cropBox, to: ctx)
        return ctx.makeImage()
    }

    private static func byte(_ i: CGImage) -> Data? { i.dataProvider?.data as Data? }

    func test_misuraMostrata_scambiaILatiA90E270() throws {
        for r in [0, 90, 180, 270] {
            let (p, url) = try pagina(r); defer { try? FileManager.default.removeItem(at: url) }
            XCTAssertEqual(LetturaScansioni.rotazione(della: p), r)
            let m = LetturaScansioni.misuraMostrata(della: p)
            XCTAssertEqual(m.width, P.larghezza, accuracy: 0.01, "rotazione \(r)")
            XCTAssertEqual(m.height, P.altezza, accuracy: 0.01, "rotazione \(r)")
        }
    }

    /// Sulle pagine diritte col riquadro all'origine (tutte quelle del banco del giro 1) la resa nuova è la vecchia, al byte.
    func test_immagine_paginaDiritta_identicaAlByteAllaResaDiPrima() throws {
        let (p, url) = try pagina(0); defer { try? FileManager.default.removeItem(at: url) }
        let nuova = try XCTUnwrap(LetturaScansioni.immagine(della: p)), vecchia = try XCTUnwrap(Self.resaDiPrima(p))
        XCTAssertEqual(nuova.width, vecchia.width); XCTAssertEqual(nuova.height, vecchia.height)
        XCTAssertEqual(Self.byte(nuova), Self.byte(vecchia), "al byte")
        // anche col lato lungo dell'impaginazione e di GLM
        for lato in [CGFloat(640), 1000, 2000] {
            XCTAssertEqual(Self.byte(try XCTUnwrap(LetturaScansioni.immagine(della: p, latoLungo: lato))),
                           Self.byte(try XCTUnwrap(Self.resaDiPrima(p, latoLungo: lato))), "lato lungo \(lato)")
        }
    }

    /// La prova al contrario, dentro il test: la resa di prima, sulla pagina ruotata di 270 gradi, ha la tela orizzontale e perde la
    /// pagina (non è la pagina diritta); la nuova sì.
    func test_resaDiPrima_sullaPaginaRuotata_tagliava() throws {
        let (d, u0) = try pagina(0); defer { try? FileManager.default.removeItem(at: u0) }
        let rif = try XCTUnwrap(LetturaScansioni.immagine(della: d))
        for r in [90, 270] {
            let (p, url) = try pagina(r); defer { try? FileManager.default.removeItem(at: url) }
            let vecchia = try XCTUnwrap(Self.resaDiPrima(p))
            XCTAssertGreaterThan(vecchia.width, vecchia.height, "rotazione \(r): la tela di prima era orizzontale")
            XCTAssertNil(P.differenza(vecchia, rif), "rotazione \(r): di prima non era la pagina mostrata")
            XCTAssertLessThan(try XCTUnwrap(P.differenza(try XCTUnwrap(LetturaScansioni.immagine(della: p)), rif)), 2.0)
        }
        let (s, us) = try pagina(0, 30); defer { try? FileManager.default.removeItem(at: us) }
        let scivolata = try XCTUnwrap(P.differenza(try XCTUnwrap(Self.resaDiPrima(s)), rif))
        XCTAssertGreaterThan(scivolata, 5.0, "col riquadro spostato la resa di prima scivolava (differenza media \(scivolata))")
    }

    /// La resa per l'impaginazione: sulle pagine diritte è quella del modulo condiviso, al byte; sulle altre è la pagina diritta.
    func test_resaPerImpaginazione_dirittaComeIlModulo_ruotataComeLaDiritta() throws {
        let (d, u0) = try pagina(0); defer { try? FileManager.default.removeItem(at: u0) }
        let a = try XCTUnwrap(LetturaScansioni.resaPerImpaginazione(d)), b = try XCTUnwrap(HeronPageRenderer.renderPage(d))
        XCTAssertEqual(Self.byte(a.0), Self.byte(b.0), "la resa del modulo, al byte")
        XCTAssertEqual(a.1, b.1); XCTAssertEqual(a.2, b.2)
        for c in P.casi {
            let (p, url) = try pagina(c.rotazione, c.margine); defer { try? FileManager.default.removeItem(at: url) }
            let r = try XCTUnwrap(LetturaScansioni.resaPerImpaginazione(p))
            XCTAssertEqual(r.0.width, 640); XCTAssertEqual(r.0.height, 640)
            XCTAssertEqual(r.1, Double(P.larghezza), accuracy: 0.01, "rotazione \(c.rotazione), margine \(c.margine)")
            XCTAssertEqual(r.2, Double(P.altezza), accuracy: 0.01, "rotazione \(c.rotazione), margine \(c.margine)")
            let diff = try XCTUnwrap(P.differenza(r.0, a.0))
            XCTAssertLessThan(diff, 3.0, "rotazione \(c.rotazione), margine \(c.margine): la stessa pagina (differenza \(diff))")
        }
    }
}
