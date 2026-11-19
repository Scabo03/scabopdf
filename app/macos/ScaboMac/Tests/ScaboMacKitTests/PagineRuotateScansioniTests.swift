//
//  PagineRuotateScansioniTests.swift
//  ScaboMacKitTests — LE PAGINE RUOTATE nella lettura delle scansioni (giro globale del banco OCR, 2026-11-19; docs/BANCO_OCR.md § 21 e
//  § 25). Molti scanner salvano la pagina in orizzontale e dichiarano la rotazione (`/Rotate`): la pagina si mostra diritta, ma il suo
//  riquadro non ruotato è orizzontale. Questi test costruiscono la STESSA pagina sintetica diritta, ruotata di 90, 180 e 270 gradi e col
//  riquadro di ritaglio spostato dall'origine, e chiedono che la lettura sia la stessa: l'immagine data ai lettori, le righe che legge
//  Apple (anche quella in alto) e la geometria della pagina dell'estrazione, nello spazio della pagina come si mostra.
//
//  Usano solo l'interfaccia che c'era anche prima della correzione (`LetturaScansioni.immagine(della:)`, `regioni(pagina:modello:)`,
//  `EstrattoreScansioni`): per la prova al contrario girano anche sul codice di prima, dove devono fallire. Contenuti sintetici: nessun
//  testo dei volumi.
//
import AppKit
import CoreText
import PDFKit
import ScaboChain
import ScaboCore
import ScaboPageStructure
import XCTest
@testable import ScaboMacKit

final class PagineRuotateScansioniTests: XCTestCase {

    /// La pagina diritta, in punti (come si mostra).
    static let larghezza: CGFloat = 420, altezza: CGFloat = 595
    static let frasi = ["Riga in alto della pagina ruotata", "una seconda riga con altre parole", "una terza riga del primo blocco"]
    static let fondo = "Ultima riga in basso della prova"

    /// L'immagine diritta della pagina a 300 punti per pollice: tre righe in alto (la prima nel primo sesto della pagina), una in fondo.
    static func immagineDiritta() throws -> CGImage {
        let s: CGFloat = 300.0 / 72.0
        guard let bmp = CGContext(data: nil, width: Int(larghezza * s), height: Int(altezza * s), bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else {
            throw NSError(domain: "prova", code: 2)
        }
        bmp.setFillColor(gray: 1, alpha: 1)
        bmp.fill(CGRect(x: 0, y: 0, width: larghezza * s, height: altezza * s))
        bmp.scaleBy(x: s, y: s)
        let font = CTFontCreateWithName("Helvetica" as CFString, 14, nil)
        func scrivi(_ f: String, _ y: CGFloat) {
            let a = NSAttributedString(string: f, attributes: [.font: font, .foregroundColor: NSColor.black])
            bmp.textPosition = CGPoint(x: 40, y: y)
            CTLineDraw(CTLineCreateWithAttributedString(a), bmp)
        }
        for (k, f) in frasi.enumerated() { scrivi(f, 555 - CGFloat(k) * 22) }
        scrivi(fondo, 40)
        return try XCTUnwrap(bmp.makeImage())
    }

    /// Una scansione di una pagina «come la salvano gli scanner»: l'immagine sta nel riquadro non ruotato girata in senso antiorario di
    /// `rotazione` gradi, e la pagina dichiara `/Rotate rotazione` (così si mostra diritta). `margine` > 0: MediaBox più grande di
    /// `margine` per lato e CropBox spostato sull'immagine.
    static func scansione(rotazione: Int, margine: CGFloat = 0, in url: URL) throws -> URL {
        let img = try immagineDiritta()
        let (w, h) = rotazione == 90 || rotazione == 270 ? (altezza, larghezza) : (larghezza, altezza)
        var box = CGRect(x: 0, y: 0, width: w + 2 * margine, height: h + 2 * margine)
        let grezzo = url.deletingLastPathComponent().appendingPathComponent(".grezzo-\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: grezzo) }
        guard let ctx = CGContext(grezzo as CFURL, mediaBox: &box, nil) else { throw NSError(domain: "prova", code: 1) }
        ctx.beginPDFPage(nil)
        ctx.translateBy(x: margine, y: margine)
        switch rotazione {   // l'immagine diritta (larghezza × altezza) girata in senso antiorario di `rotazione` gradi
        case 90: ctx.translateBy(x: altezza, y: 0); ctx.rotate(by: .pi / 2)
        case 180: ctx.translateBy(x: larghezza, y: altezza); ctx.rotate(by: .pi)
        case 270: ctx.translateBy(x: 0, y: larghezza); ctx.rotate(by: -.pi / 2)
        default: break
        }
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: larghezza, height: altezza))
        ctx.endPDFPage()
        ctx.closePDF()
        let doc = try XCTUnwrap(PDFDocument(url: grezzo))
        let p = try XCTUnwrap(doc.page(at: 0))
        if margine > 0 { p.setBounds(CGRect(x: margine, y: margine, width: w, height: h), for: .cropBox) }
        p.rotation = rotazione
        XCTAssertTrue(doc.write(to: url))
        return url
    }

    private func file(_ nome: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("\(nome)-\(UUID().uuidString).pdf")
    }

    /// Differenza media dei pixel (0-255) fra due immagini in scala di grigi della stessa misura; nil se la misura è diversa.
    static func differenza(_ a: CGImage, _ b: CGImage) -> Double? {
        guard a.width == b.width, a.height == b.height else { return nil }
        func grigi(_ i: CGImage) -> [UInt8] {
            var px = [UInt8](repeating: 0, count: i.width * i.height)
            let c = CGContext(data: &px, width: i.width, height: i.height, bitsPerComponent: 8, bytesPerRow: i.width,
                              space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
            c.draw(i, in: CGRect(x: 0, y: 0, width: i.width, height: i.height))
            return px
        }
        let x = grigi(a), y = grigi(b)
        return Double(zip(x, y).reduce(0) { $0 + abs(Int($1.0) - Int($1.1)) }) / Double(x.count)
    }

    static let casi: [(rotazione: Int, margine: CGFloat)] = [(90, 0), (180, 0), (270, 0), (0, 30), (90, 30), (180, 30), (270, 30)]

    /// L'immagine data ai lettori è quella della pagina diritta, con qualunque rotazione e col riquadro spostato.
    func test_immagine_paginaRuotataOSpostata_comeLaPaginaDiritta() throws {
        let diritta = try Self.scansione(rotazione: 0, in: file("diritta"))
        defer { try? FileManager.default.removeItem(at: diritta) }
        let rif = try XCTUnwrap(LetturaScansioni.immagine(della: try XCTUnwrap(PDFDocument(url: diritta)?.page(at: 0))))
        XCTAssertLessThan(rif.width, rif.height, "la pagina diritta è verticale")
        for c in Self.casi {
            let url = try Self.scansione(rotazione: c.rotazione, margine: c.margine, in: file("r\(c.rotazione)"))
            defer { try? FileManager.default.removeItem(at: url) }
            let img = try XCTUnwrap(LetturaScansioni.immagine(della: try XCTUnwrap(PDFDocument(url: url)?.page(at: 0))))
            XCTAssertEqual(img.width, rif.width, "rotazione \(c.rotazione), margine \(c.margine): la tela è quella della pagina mostrata")
            XCTAssertEqual(img.height, rif.height, "rotazione \(c.rotazione), margine \(c.margine)")
            let d = try XCTUnwrap(Self.differenza(img, rif), "rotazione \(c.rotazione), margine \(c.margine): misure diverse")
            XCTAssertLessThan(d, 2.0, "rotazione \(c.rotazione), margine \(c.margine): la stessa pagina (differenza media \(d))")
        }
    }

    /// La lettura di Apple, attraverso l'estrattore dell'app, legge anche la riga in alto e quella in fondo, e le mette nello spazio
    /// della pagina come si mostra: la riga in alto nel sesto alto, la pagina dell'estrazione verticale.
    func test_estrattore_paginaRuotataOSpostata_leggeIlTerzoAlto_eLaGeometriaEDiritta() throws {
        for c in [(0, CGFloat(0))] + Self.casi {
            let url = try Self.scansione(rotazione: c.0, margine: c.1, in: file("e\(c.0)"))
            defer { try? FileManager.default.removeItem(at: url) }
            let e = EstrattoreScansioni(lettore: .apple, via: .v1)
            let ex = try XCTUnwrap(try e.extract(fromUri: url.path, onPageExtracted: { _, _ in }, isCancelled: { false }))
            let p = try XCTUnwrap(ex.pages.first)
            let righe = p.lines.map { l in (testo: l.spans.map(\.text).joined(separator: " "), bbox: l.bbox) }
            let tutto = righe.map(\.testo).joined(separator: " ")
            XCTAssertTrue(tutto.contains("Riga in alto"), "rotazione \(c.0), margine \(c.1): la riga in alto si legge: \(righe.map(\.testo))")
            XCTAssertTrue(tutto.contains("Ultima riga"), "rotazione \(c.0), margine \(c.1): la riga in fondo si legge")
            XCTAssertEqual(p.width, Double(Self.larghezza), accuracy: 0.5, "rotazione \(c.0), margine \(c.1): la pagina come si mostra")
            XCTAssertEqual(p.height, Double(Self.altezza), accuracy: 0.5, "rotazione \(c.0), margine \(c.1)")
            if let alta = righe.first(where: { $0.testo.contains("Riga in alto") }) {
                XCTAssertGreaterThan(alta.bbox.y, 0.8 * p.height, "rotazione \(c.0), margine \(c.1): la riga in alto sta in alto")
            }
            if let bassa = righe.first(where: { $0.testo.contains("Ultima riga") }) {
                XCTAssertLessThan(bassa.bbox.y, 0.2 * p.height, "rotazione \(c.0), margine \(c.1): la riga in fondo sta in fondo")
            }
        }
    }

    /// Le regioni del modello d'impaginazione sulla pagina ruotata sono quelle della pagina diritta (stesso numero, stessi tipi,
    /// riquadri entro pochi punti), nello spazio della pagina come si mostra.
    func test_regioni_paginaRuotataOSpostata_comeSullaPaginaDiritta() throws {
        guard HeronLayoutModel.bundledModelURL != nil else { throw XCTSkip("modello d'impaginazione assente (clone senza Git LFS)") }
        let modello = try HeronLayoutModel.bundled()
        let diritta = try Self.scansione(rotazione: 0, in: file("hd"))
        defer { try? FileManager.default.removeItem(at: diritta) }
        let rif = try LetturaScansioni.regioni(pagina: try XCTUnwrap(PDFDocument(url: diritta)?.page(at: 0)), modello: modello)
        XCTAssertFalse(rif.isEmpty, "il modello vede le righe della pagina diritta")
        for c in Self.casi {
            let url = try Self.scansione(rotazione: c.rotazione, margine: c.margine, in: file("h\(c.rotazione)"))
            defer { try? FileManager.default.removeItem(at: url) }
            let reg = try LetturaScansioni.regioni(pagina: try XCTUnwrap(PDFDocument(url: url)?.page(at: 0)), modello: modello)
            XCTAssertEqual(reg.map(\.tipo).sorted(), rif.map(\.tipo).sorted(), "rotazione \(c.rotazione), margine \(c.margine): stessi tipi")
            for r in rif {
                let vicina = reg.contains { abs($0.bbox.x - r.bbox.x) < 6 && abs($0.bbox.y - r.bbox.y) < 6
                    && abs($0.bbox.width - r.bbox.width) < 8 && abs($0.bbox.height - r.bbox.height) < 8 }
                XCTAssertTrue(vicina, "rotazione \(c.rotazione), margine \(c.margine): la regione \(r.tipo) \(r.bbox) c'è anche qui: \(reg)")
            }
        }
    }
}
