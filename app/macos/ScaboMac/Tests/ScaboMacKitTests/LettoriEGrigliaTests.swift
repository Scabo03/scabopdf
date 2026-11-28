//
//  LettoriEGrigliaTests.swift
//  ScaboMacKitTests — giro «scansioni, ricerca e build» (2026-11-28): il profilo dei lettori generativi (GLM com'era, Xiaomi-OCR-0
//  col profilo del banco), le forme della notazione di Xiaomi portate a quelle di GLM (mai una lettera o una cifra tolta), i filetti
//  contati sull'immagine della pagina dentro una regione «tabella» (la griglia che la guardia delle risorse visive conosce dal PDF col
//  testo). Testi e immagini di prova inventati.
//
import CoreGraphics
import Foundation
import ScaboCore
import ScaboMacOCR
import XCTest
@testable import ScaboMacKit

final class LettoriEGrigliaTests: XCTestCase {

    // MARK: i profili

    func test_profiloGlm_restaQuelloDiPrima() {
        XCTAssertEqual(ProfiloLettore.glm.prompt, "Text Recognition:")
        XCTAssertEqual(ProfiloLettore.glm.maxTokens, 3000)
        XCTAssertEqual(ProfiloLettore.glm.contextTokens, 8192)
        XCTAssertEqual(ProfiloLettore.glm.repeatPenalty, 1.05)
        XCTAssertEqual(ProfiloLettore.glm.formaChat, .modelloDiChat)
        XCTAssertEqual(GlmOcr.prompt, ProfiloLettore.glm.prompt)
        XCTAssertEqual(GlmOcr.maxTokens, ProfiloLettore.glm.maxTokens)
        XCTAssertEqual(GlmOcr.repeatPenalty, ProfiloLettore.glm.repeatPenalty)
        XCTAssertEqual(GlmOcr.contextTokens, ProfiloLettore.glm.contextTokens)
    }

    func test_profiloXiaomi_quelloDelBanco() {
        let p = ProfiloLettore.xiaomi
        XCTAssertTrue(p.prompt.hasPrefix("Extract all information from the main body of the document image"))
        XCTAssertTrue(p.prompt.contains("OTSL") && p.prompt.contains("LATEX") && p.prompt.contains("reading order"))
        XCTAssertEqual(p.maxTokens, 4096)
        XCTAssertEqual(p.contextTokens, 12288)
        XCTAssertEqual(p.repeatPenalty, 1.0, "nessuna penalità di ripetizione, come al banco")
        XCTAssertEqual(p.formaChat, .chatmlSenzaRagionamento)
    }

    func test_lettori_profiloEFile() {
        XCTAssertNil(LettoreScansioni.apple.profilo)
        XCTAssertEqual(LettoreScansioni.glm.profilo, .glm)
        XCTAssertEqual(LettoreScansioni.xiaomi.profilo, .xiaomi)
        XCTAssertEqual(LettoreScansioni.glm.fileDeiPesi?.pesi, "GLM-OCR-Q8_0.gguf")
        XCTAssertEqual(LettoreScansioni.xiaomi.fileDeiPesi?.proiettore, "mmproj-Xiaomi-OCR-0-f16.gguf")
        XCTAssertEqual(ViaScansioni.predefinita(per: .xiaomi), .v2)
        XCTAssertEqual(ViaScansioni.predefinita(per: .glm), .v2)
        XCTAssertEqual(ViaScansioni.predefinita(per: .apple), .v5)
        XCTAssertNil(Gergo.contieneGergo(LettoreScansioni.xiaomi.nome))
    }

    func test_xiaomiNonInstallato_loDiceColSuoNome_GlmComePrima() {
        let x = EstrattoreScansioni.Problema.altroLettoreNonInstallato(.xiaomi).localizedDescription
        XCTAssertTrue(x.hasPrefix("Xiaomi lettura pagine non è installato"))
        XCTAssertNil(Gergo.contieneGergo(x))
        XCTAssertTrue(EstrattoreScansioni.Problema.modelloNonInstallato.localizedDescription.hasPrefix("GLM lettura pagine non è installato"))
        for p in [EstrattoreScansioni.Problema.altroLettoreNonCaricato(.xiaomi), .altroLettoreSenzaMemoria(.xiaomi, disponibileGB: 2)] {
            XCTAssertNil(Gergo.contieneGergo(p.localizedDescription))
            XCTAssertTrue(p.propostaAltroLettore)
        }
    }

    // MARK: la notazione di Xiaomi

    private func lettereECifre(_ s: String) -> String {
        String(s.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.map(Character.init).sorted())
    }

    func test_notazioneXiaomi_richiamiETabelle() {
        let x = "La regola di prova \\( ^{12} \\) vale anche qui \\( ^{3} \\).\n<fcel>Colonna<fcel>Valore<nl><fcel>uno<ecel><lcel><nl>"
        let n = LetturaScansioni.notazioneXiaomi(x)
        XCTAssertEqual(n, "La regola di prova $ ^{12} $ vale anche qui $ ^{3} $.\n Colonna Valore\n uno  \n")
        let f = LetturaScansioni.filtraNotazione(x, lettore: .xiaomi)
        XCTAssertTrue(f.contains("prova $^{12}$ vale"), "l'apice del richiamo nella forma che la catena riconosce: \(f)")
        XCTAssertNil(f.range(of: #"<[a-z]+>|\\\(|\\\)"#, options: .regularExpression), "nessun segno OTSL né delimitatore di formula")
        XCTAssertEqual(lettereECifre(f), lettereECifre(x.replacingOccurrences(of: #"</?[a-z]+>"#, with: " ", options: .regularExpression)),
                       "nessuna lettera e nessuna cifra tolta")
    }

    func test_filtroPerGlm_identicoAQuelloDiSempre() {
        let glm = "Il termine$^{12}$ e \\( x \\) <fcel>resta come prima"
        XCTAssertEqual(LetturaScansioni.filtraNotazione(glm, lettore: .glm), LetturaScansioni.filtraNotazione(glm))
        XCTAssertEqual(LetturaScansioni.filtraNotazione(glm, lettore: .apple), LetturaScansioni.filtraNotazione(glm))
    }

    // MARK: i filetti della griglia

    /// Un'immagine in scala di grigi bianca, coi segmenti scuri dati (pixel, origine in alto a sinistra), spessi 2 pixel.
    private func immagine(_ w: Int, _ h: Int, orizzontali: [(y: Int, x0: Int, x1: Int)], verticali: [(x: Int, y0: Int, y1: Int)],
                          trattini: [(y: Int, x0: Int, x1: Int)] = []) -> CGImage {
        var px = [UInt8](repeating: 255, count: w * h)
        for s in orizzontali { for y in s.y..<(s.y + 2) { for x in s.x0..<s.x1 { px[y * w + x] = 0 } } }
        for s in verticali { for x in s.x..<(s.x + 2) { for y in s.y0..<s.y1 { px[y * w + x] = 0 } } }
        // Una «riga di testo»: tratti di 6 pixel separati da 5 di bianco (lo spazio fra le lettere e le parole).
        for s in trattini { for y in s.y..<(s.y + 6) { var x = s.x0; while x < s.x1 { for k in x..<min(x + 6, s.x1) { px[y * w + k] = 0 }; x += 11 } } }
        let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w, space: CGColorSpaceCreateDeviceGray(),
                            bitmapInfo: CGImageAlphaInfo.none.rawValue)!
        return ctx.makeImage()!
    }

    func test_filetti_contaRigheEColonneDellaGriglia() {
        // Pagina di 400 × 300 punti resa a 400 × 300 pixel; regione da (50, 50) a (350, 250) in pixel dall'alto.
        let img = immagine(400, 300, orizzontali: [(50, 50, 350), (100, 50, 350), (150, 50, 350), (248, 50, 350)],
                           verticali: [(50, 50, 250), (200, 50, 250), (348, 50, 250)])
        let regione = BBox(x: 50, y: 300 - 250, width: 300, height: 200)   // origine in basso a sinistra
        XCTAssertEqual(EstrattoreScansioni.filettiDisegnati(img, regione: regione, larghezza: 400, altezza: 300), 7)
    }

    func test_filetti_leRigheDiTestoNonSonoFiletti() {
        let img = immagine(400, 300, orizzontali: [], verticali: [], trattini: [(80, 60, 340), (120, 60, 340), (160, 60, 340)])
        let regione = BBox(x: 50, y: 50, width: 300, height: 200)
        XCTAssertEqual(EstrattoreScansioni.filettiDisegnati(img, regione: regione, larghezza: 400, altezza: 300), 0)
    }

    func test_filetti_unFilettoCortoNonConta_eFuoriRegioneNonConta() {
        // Un filetto lungo il 20 % della regione (sotto la soglia del 30 %) e uno lungo fuori dalla regione.
        let img = immagine(400, 300, orizzontali: [(100, 60, 120), (20, 0, 400)], verticali: [])
        let regione = BBox(x: 50, y: 50, width: 300, height: 200)
        XCTAssertEqual(EstrattoreScansioni.filettiDisegnati(img, regione: regione, larghezza: 400, altezza: 300), 0)
    }

    func test_filetti_regioneVuotaOFuoriPagina() {
        let img = immagine(100, 100, orizzontali: [(50, 0, 100)], verticali: [])
        XCTAssertEqual(EstrattoreScansioni.filettiDisegnati(img, regione: BBox(x: 200, y: 200, width: 10, height: 10), larghezza: 100, altezza: 100), 0)
        XCTAssertEqual(EstrattoreScansioni.filettiDisegnati(img, regione: BBox(x: 0, y: 0, width: 100, height: 100), larghezza: 0, altezza: 100), 0)
    }

    func test_griglia_siSpegneConLeAltreMigliorie() {
        XCTAssertTrue(MiglioriScansioni().griglia)
        XCTAssertFalse(MiglioriScansioni.spente.griglia)
        XCTAssertEqual(MiglioriScansioni(spente: "griglia")?.spenteNomi, ["griglia"])
        XCTAssertEqual(MiglioriScansioni.spente.spenteNomi, ["tabelle", "glm", "paragrafo", "griglia", "colonne", "righetabella"])
    }
}
