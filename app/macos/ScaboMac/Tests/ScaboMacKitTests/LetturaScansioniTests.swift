//
//  LetturaScansioniTests.swift
//  ScaboMacKitTests — il lettore delle scansioni del Mac (giro «modelli e scansioni», 2026-11-18): la guardia sul testo di GLM
//  lettura pagine, i gruppi dei corpi, i richiami di nota con la loro guardia, una scansione sintetica letta davvero dalla
//  lettura del testo di Apple e passata per la catena condivisa, i problemi in prosa, e un PDF con testo che resta identico al
//  byte. Contenuti sintetici: nessun testo dei volumi.
//
import AppKit
import CoreText
import PDFKit
import ScaboChain
import ScaboCore
import XCTest
@testable import ScaboMacKit

final class LetturaScansioniTests: XCTestCase {

    private func riga(_ t: String, x: Double = 50, y: Double = 700, w: Double = 300, h: Double = 12, regione: Int = 0,
                      tipo: String? = nil) -> RigaLetta {
        RigaLetta(testo: t, bbox: BBox(x: x, y: y, width: w, height: h), regione: regione, tipo: tipo)
    }

    // MARK: La guardia

    func test_guardia_laCorrezioneEntra_cioCheGlmAggiungeNo() {
        let righe = [riga("Il gato dormiva"), riga("sul divano rosso", y: 686)]
        let g = LetturaScansioni.guardia(righe: righe, testoGlm: "Il gatto dormiva\nsul divano rosso. Parole aggiunte qui")
        XCTAssertEqual(g.righe.map(\.testo), ["Il gatto dormiva", "sul divano rosso."])
        XCTAssertEqual(g.conti["scartate_glm"], 3, "le tre parole che Apple non ha visto non entrano")
        XCTAssertEqual(g.righe.map(\.bbox), righe.map(\.bbox), "la geometria resta quella di Apple")
    }

    func test_guardia_parolaDiversaENonSomigliante_restaQuellaDiApple() {
        let g = LetturaScansioni.guardia(righe: [riga("la casa rossa")], testoGlm: "la tavola rossa")
        XCTAssertEqual(g.righe.first?.testo, "la casa rossa")
        XCTAssertEqual(g.conti["tenute_apple"], 1)
    }

    func test_guardia_ciòCheGlmNonLegge_restaDiApple() {
        let g = LetturaScansioni.guardia(righe: [riga("prima riga"), riga("seconda riga", y: 686)], testoGlm: "prima riga")
        XCTAssertEqual(g.righe.map(\.testo), ["prima riga", "seconda riga"])
    }

    func test_guardia_formattazioneDiGlmTolta() {
        XCTAssertEqual(LetturaScansioni.paroleGlm("## Titolo\n| a | b |\n**forte**"), ["Titolo", "a", "b", "forte"])
    }

    // MARK: I corpi

    func test_corpi_larghezzaPerCarattere_eGruppiDaiPicchi() {
        // Righe di testo a 10 punti (circa 4,23 punti per carattere) con un po' di rumore, note a 8, un titolo breve alto.
        var righe: [RigaLetta] = []
        for k in 0..<40 { righe.append(riga(String(repeating: "a", count: 60), y: 700 - Double(k) * 12, w: 60 * 4.23 * (k % 2 == 0 ? 1.03 : 0.97), regione: k / 10)) }
        for k in 0..<10 { righe.append(riga(String(repeating: "b", count: 60), y: 150 - Double(k) * 9, w: 60 * 3.38, regione: 9)) }
        let pagina = PaginaLetta(pagina: 0, larghezza: 400, altezza: 800, righe: righe, testoGlm: nil,
                                 secondiApple: 0, secondiGlm: 0, secondiImpaginazione: 0, guardia: nil)
        let p = try! XCTUnwrap(LetturaScansioni.pagineEstratte([pagina])[0])
        let corpi = Set(p.lines.flatMap { $0.spans.map(\.fontSize) })
        XCTAssertEqual(corpi, [10, 8], "due misure soltanto: il testo e le note")
    }

    func test_titoloDelModello_grassettoSoloSuRigheBreviEIsolate() {
        let breve = riga("Capitolo primo", tipo: "section_header")
        XCTAssertTrue(LetturaScansioni.titoloAmmesso(breve, tra: [breve]))
        let lunga = riga(String(repeating: "x", count: 130), tipo: "section_header")
        XCTAssertFalse(LetturaScansioni.titoloAmmesso(lunga, tra: [lunga]))
        let quattro = (0..<4).map { riga("riga \($0)", y: 700 - Double($0) * 12, regione: 3, tipo: "section_header") }
        XCTAssertFalse(LetturaScansioni.titoloAmmesso(quattro[0], tra: quattro), "una regione di quattro righe non è un titolo")
        XCTAssertFalse(LetturaScansioni.titoloAmmesso(riga("testo", tipo: "text"), tra: []))
    }

    // MARK: I richiami

    func test_richiamo_soloSeLaNotaCominciaSullaPagina() {
        let r = riga("la parola12 e altro")
        let con = LetturaScansioni.spans(r, corpo: 10, grassetto: false, note: ["12"])
        XCTAssertEqual(con.map(\.text), ["la parola", "12", " e altro"])
        XCTAssertLessThan(con[1].fontSize, 10)
        XCTAssertEqual(LetturaScansioni.spans(r, corpo: 10, grassetto: false, note: ["7"]).count, 1, "nessuna nota 12: nessun richiamo")
    }

    func test_richiamo_numeroStaccato_maiDopoArtONumero() {
        XCTAssertEqual(LetturaScansioni.spans(riga("vedi la regola 4 sopra"), corpo: 10, grassetto: false, note: ["4"]).map(\.text),
                       ["vedi la regola", "4", " sopra"])
        XCTAssertEqual(LetturaScansioni.spans(riga("secondo l'art. 4 citato"), corpo: 10, grassetto: false, note: ["4"]).count, 1)
        XCTAssertEqual(LetturaScansioni.spans(riga("al n. 4 del testo"), corpo: 10, grassetto: false, note: ["4"]).count, 1)
    }

    func test_apiciDiGlm_richiamoSoloConLaNota_altrimentiLaCifra() {
        let con = LetturaScansioni.spans(riga("la parola$^{12}$. Poi altro"), corpo: 10, grassetto: false, note: ["12"])
        XCTAssertEqual(con.map(\.text), ["la parola", "12", ". Poi altro"])
        XCTAssertEqual(LetturaScansioni.spans(riga("misura in m$^{2}$ netti"), corpo: 10, grassetto: false, note: ["7"]).map(\.text),
                       ["misura in m2 netti"], "nessuna nota 2: la cifra resta nel testo, senza la notazione")
        XCTAssertEqual(LetturaScansioni.numeroDiNotaInTesta("$^{12}$ Testo della nota"), "12 Testo della nota")
        XCTAssertEqual(LetturaScansioni.numeroDiNotaInTesta("Testo"), "Testo")
    }

    func test_guardia_apiceSoloDiGlm_siAttaccaAllaParolaPrecedente() {
        let g = LetturaScansioni.guardia(righe: [riga("la regola vale sempre")], testoGlm: "la regola $^{3}$ vale sempre")
        XCTAssertEqual(g.righe.first?.testo, "la regola$^{3}$ vale sempre")
        XCTAssertEqual(g.conti["apici_glm"], 1)
        let n = LetturaScansioni.guardia(righe: [riga("la regola vale sempre")], testoGlm: "la regola 3 vale sempre")
        XCTAssertEqual(n.righe.first?.testo, "la regola vale sempre", "un numero che Apple non ha visto non entra")
    }

    // MARK: L'estrattore

    /// Un PDF di una pagina: testo vero (`comeTesto`) o la stessa pagina come immagine (una scansione sintetica).
    static func pagina(_ frasi: [String], comeTesto: Bool, in url: URL) throws -> URL {
        var box = CGRect(x: 0, y: 0, width: 420, height: 595)
        let font = CTFontCreateWithName("Helvetica" as CFString, 14, nil)
        func disegna(_ ctx: CGContext, scala: CGFloat) {
            ctx.saveGState()
            ctx.scaleBy(x: scala, y: scala)
            for (k, f) in frasi.enumerated() {
                let s = NSAttributedString(string: f, attributes: [.font: font, .foregroundColor: NSColor.black])
                ctx.textPosition = CGPoint(x: 40, y: 540 - CGFloat(k) * 22)
                CTLineDraw(CTLineCreateWithAttributedString(s), ctx)
            }
            ctx.restoreGState()
        }
        guard let ctx = CGContext(url as CFURL, mediaBox: &box, nil) else { throw NSError(domain: "prova", code: 1) }
        ctx.beginPDFPage(nil)
        if comeTesto {
            disegna(ctx, scala: 1)
        } else {
            let s: CGFloat = 300.0 / 72.0
            guard let bmp = CGContext(data: nil, width: Int(420 * s), height: Int(595 * s), bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else {
                throw NSError(domain: "prova", code: 2)
            }
            bmp.setFillColor(gray: 1, alpha: 1); bmp.fill(CGRect(x: 0, y: 0, width: 420 * s, height: 595 * s))
            disegna(bmp, scala: s)
            ctx.draw(bmp.makeImage()!, in: box)
        }
        ctx.endPDFPage()
        ctx.closePDF()
        return url
    }

    private let frasi = ["Prima frase della pagina di prova", "una seconda riga con altre parole", "e una terza riga per chiudere"]

    func test_scansioneSintetica_laLeggeApple_eLaCatenaNonLaRifiuta() throws {
        let url = try Self.pagina(frasi, comeTesto: false,
                                  in: FileManager.default.temporaryDirectory.appendingPathComponent("scan-\(UUID().uuidString).pdf"))
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertTrue(EstrattoreScansioni.senzaTesto(try XCTUnwrap(PdfKitExtractor().extract(fromUri: url.path).pages.first)))
        let e = EstrattoreScansioni(lettore: .apple, via: .v1)
        let ex = try XCTUnwrap(try e.extract(fromUri: url.path, onPageExtracted: { _, _ in }, isCancelled: { false }))
        let testo = ex.pages[0].lines.flatMap { $0.spans.map(\.text) }.joined(separator: " ")
        XCTAssertTrue(testo.contains("seconda riga"), "la lettura del testo di Apple legge la pagina")
        XCTAssertEqual(e.rapporto?.pagineLette, 1)
        XCTAssertEqual(e.rapporto?.lettore, .apple)
        let esito = ProcessingChain.run(fileURL: url, sourceName: "scan.pdf", extractor: EstrattoreScansioni(lettore: .apple, via: .v1),
                                        options: ChainOptions(granularityTarget: 400), onProgress: { _ in }, isCancelled: { false })
        guard case .success(let r) = esito else { return XCTFail("la catena condivisa la deve leggere: \(esito)") }
        XCTAssertFalse(r.document.structure.isEmpty)
    }

    func test_pdfConTesto_estrazioneIdenticaAQuellaDiPdfKit() throws {
        let url = try Self.pagina(frasi, comeTesto: true,
                                  in: FileManager.default.temporaryDirectory.appendingPathComponent("testo-\(UUID().uuidString).pdf"))
        defer { try? FileManager.default.removeItem(at: url) }
        let a = try XCTUnwrap(try PdfKitExtractor().extract(fromUri: url.path, onPageExtracted: { _, _ in }, isCancelled: { false }))
        let e = EstrattoreScansioni(lettore: .glm)
        let b = try XCTUnwrap(try e.extract(fromUri: url.path, onPageExtracted: { _, _ in }, isCancelled: { false }))
        XCTAssertEqual(a, b, "le pagine con testo restano identiche")
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        XCTAssertEqual(try enc.encode(a), try enc.encode(b), "al byte")
        XCTAssertEqual(e.rapporto?.pagineLette, 0)
        XCTAssertNil(e.problema, "nessun lettore serve: GLM nemmeno si cerca")
    }

    func test_messaggiDelLettore_senzaGergo() {
        for p in [EstrattoreScansioni.Problema.memoriaInsufficiente(disponibileGB: 3), .modelloNonInstallato, .modelloNonCaricato, .pdfNonLeggibile] {
            let t = p.localizedDescription
            XCTAssertNil(Gergo.contieneGergo(t), "gergo «\(Gergo.contieneGergo(t) ?? "")» in: \(t)")
        }
        for l in LettoreScansioni.allCases { XCTAssertNil(Gergo.contieneGergo(l.nome)) }
    }

    func test_glmNonInstallato_eMemoriaInsufficiente_loDiconoInProsa() throws {
        let url = try Self.pagina(frasi, comeTesto: false,
                                  in: FileManager.default.temporaryDirectory.appendingPathComponent("scan2-\(UUID().uuidString).pdf"))
        defer { try? FileManager.default.removeItem(at: url) }
        let senza = EstrattoreScansioni(lettore: .glm, pesiGlm: nil)
        XCTAssertThrowsError(try senza.extract(fromUri: url.path, onPageExtracted: { _, _ in }, isCancelled: { false }))
        XCTAssertEqual(senza.problema, .modelloNonInstallato)
        XCTAssertTrue(senza.problema?.localizedDescription.contains("pannello dei modelli") == true)
        XCTAssertTrue(senza.problema?.propostaAltroLettore == true)
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("pesi-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let pesi = dir.appendingPathComponent("p.gguf"), proj = dir.appendingPathComponent("m.gguf")
        try Data([0]).write(to: pesi); try Data([0]).write(to: proj)
        EstrattoreScansioni.memoriaSimulata = 1 << 30
        defer { EstrattoreScansioni.memoriaSimulata = nil }
        let poca = EstrattoreScansioni(lettore: .glm, pesiGlm: (pesi, proj))
        XCTAssertThrowsError(try poca.extract(fromUri: url.path, onPageExtracted: { _, _ in }, isCancelled: { false }))
        XCTAssertEqual(poca.problema, .memoriaInsufficiente(disponibileGB: 1))
        XCTAssertTrue(poca.problema?.localizedDescription.contains("lettura del testo di Apple") == true, "propone l'altro lettore")
    }
}

/// Solo laboratorio (`SCABO_BANCO_PDF`: un file JSON con l'elenco dei percorsi dei PDF con testo del banco): su nessuno la
/// regola della lettura scatta, quindi l'estrattore del Mac dà l'estrazione di PDFKit al byte e l'importazione resta
/// quella dell'iPad, senza domande (nemmeno sui libri con copertine, pagine bianche o figure).
final class RegolaScansioniBancoTests: XCTestCase {
    func test_nessunPdfConTestoDelBanco_vieneLettoDaUnLettore() throws {
        guard let elenco = ProcessInfo.processInfo.environment["SCABO_BANCO_PDF"] else { throw XCTSkip("a richiesta: SCABO_BANCO_PDF") }
        let percorsi = try JSONDecoder().decode([String].self, from: Data(contentsOf: URL(fileURLWithPath: elenco)))
        var letti: [Int] = [], conPagineVuote = 0
        for (k, p) in percorsi.enumerated() {
            try autoreleasepool {
                let e = EstrattoreScansioni(lettore: .apple)
                let ex = try XCTUnwrap(try e.extract(fromUri: p, onPageExtracted: { _, _ in }, isCancelled: { false }))
                if ex.pages.contains(where: EstrattoreScansioni.senzaTesto) { conPagineVuote += 1 }
                if (e.rapporto?.pagineLette ?? 0) > 0 { letti.append(k) }
            }
        }
        print("RISULTATO banco_regola_scansioni {\"pdf\": \(percorsi.count), \"con_pagine_senza_testo\": \(conPagineVuote), \"letti_da_un_lettore\": \(letti)}")
        XCTAssertEqual(letti, [])
    }

    func test_regola_scansioneIntera_mista_eLibroConCopertina() {
        XCTAssertTrue(EstrattoreScansioni.serveLettura(senzaTesto: Array(0..<20), totale: 20), "una scansione")
        XCTAssertTrue(EstrattoreScansioni.serveLettura(senzaTesto: Array(100..<112), totale: 400), "un capitolo scansionato")
        XCTAssertFalse(EstrattoreScansioni.serveLettura(senzaTesto: [0, 2, 3, 151], totale: 153), "copertina e pagine bianche")
        XCTAssertFalse(EstrattoreScansioni.serveLettura(senzaTesto: [0, 30, 31, 32, 33, 34, 35, 36, 37], totale: 384), "8 di seguito")
        XCTAssertTrue(EstrattoreScansioni.scansioneIntera(senzaTesto: 18, totale: 20))
        XCTAssertFalse(EstrattoreScansioni.scansioneIntera(senzaTesto: 12, totale: 400))
    }
}
