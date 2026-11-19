//
//  OsservazioneScansioniTests.swift
//  ScaboMacKitTests — SOLO LABORATORIO (giro 2 del banco OCR, 2026-11-19, docs/BANCO_OCR.md § 17.1): i punti d'osservazione e le
//  varianti sperimentali della lettura delle scansioni. Tutto spento di serie; acceso, non cambia la lettura (l'osservazione) o la
//  cambia solo nel modo dichiarato (le varianti). Contenuti sintetici: nessun testo dei volumi.
//
import PDFKit
import ScaboChain
import ScaboCore
import XCTest
@testable import ScaboMacKit

final class OsservazioneScansioniTests: XCTestCase {

    private func riga(_ t: String, y: Double = 700, regione: Int = 0) -> RigaLetta {
        RigaLetta(testo: t, bbox: BBox(x: 50, y: y, width: 300, height: 12), regione: regione)
    }

    func test_varianti_spenteDiSerie_eNomiDellaRigaDiComando() {
        let v = VariantiScansioni()
        XCTAssertEqual(v, VariantiScansioni(elenco: ""))
        XCTAssertTrue(v.accese.isEmpty, "di serie nessuna variante è accesa")
        XCTAssertFalse(v.richiestaClassica || v.glmSenzaGuardia || v.guardiaLarga || v.ramiCodici || v.sillabateRicomposte)
        XCTAssertEqual(EstrattoreScansioni(lettore: .apple).varianti, v, "l'estrattore nasce con le varianti spente")
        XCTAssertNil(EstrattoreScansioni(lettore: .glm).cartellaOsservazione, "e senza osservazione")
        XCTAssertFalse(EstrattoreScansioni(lettore: .glm).raccogliTabelle)
        XCTAssertNil(EstrattoreScansioni(lettore: .apple).modelloImpaginazione, "di serie il modello incluso, Heron")
        XCTAssertEqual(VariantiScansioni(elenco: "classica,codici")?.accese, ["classica", "codici"])
        XCTAssertNil(VariantiScansioni(elenco: "classica,inventata"), "un nome sconosciuto non passa")
    }

    func test_guardiaLarga_spenta_comeLaGuardiaDiSempre_accesa_entraLaParolaInMezzo() {
        let righe = [riga("Il gatto dormiva"), riga("sul divano", y: 686)]
        let glm = "Il gatto grigio dormiva\nsul divano rosso"
        let stretta = LetturaScansioni.guardia(righe: righe, testoGlm: glm)
        XCTAssertEqual(LetturaScansioni.guardia(righe: righe, testoGlm: glm, larga: false).righe, stretta.righe)
        XCTAssertEqual(stretta.righe.map(\.testo), ["Il gatto dormiva", "sul divano"], "la guardia stretta: le aggiunte non entrano")
        let larga = LetturaScansioni.guardia(righe: righe, testoGlm: glm, larga: true)
        XCTAssertEqual(larga.righe.map(\.testo), ["Il gatto grigio dormiva", "sul divano"],
                       "la larga: entra solo l'aggiunta in mezzo a una riga, non quella in fondo")
        XCTAssertEqual(larga.righe.map(\.bbox), righe.map(\.bbox), "la geometria resta quella di Apple")
    }

    func test_senzaGuardia_ilTestoDiGlmSulleRigheDiApple() {
        let righe = [riga("prima riga"), riga("seconda riga", y: 686), riga("solo di Apple", y: 672)]
        let g = LetturaScansioni.senzaGuardia(righe: righe, testoGlm: "prima riga aggiunta\nseconda <td>riga</td>")
        XCTAssertEqual(g.righe.map(\.testo), ["prima riga aggiunta", "seconda riga"],
                       "le aggiunte di GLM entrano sulla riga precedente; ciò che solo Apple ha visto si toglie; niente etichette HTML")
        XCTAssertEqual(g.conti["aggiunte_glm"], 1)
        XCTAssertEqual(g.conti["tolte_apple"], 3)
        XCTAssertTrue(LetturaScansioni.senzaGuardia(righe: [], testoGlm: "testo").righe.isEmpty, "senza ancore nessuna riga")
    }

    func test_sillabate_ricomposteSoloNellaStessaRegioneEPrimaDiUnaMinuscola() {
        let r = LetturaScansioni.ricomponiSillabate([riga("la paro-"), riga("la seguente", y: 686)])
        XCTAssertEqual(r.righe.map(\.testo), ["la parola", "seguente"])
        XCTAssertEqual(r.unite, 1)
        let solo = LetturaScansioni.ricomponiSillabate([riga("una paro-"), riga("la", y: 686)])
        XCTAssertEqual(solo.righe.map(\.testo), ["una parola"], "la riga rimasta vuota si toglie")
        XCTAssertEqual(LetturaScansioni.ricomponiSillabate([riga("altra-"), riga("regione", y: 686, regione: 1)]).righe.map(\.testo),
                       ["altra-", "regione"], "regioni diverse: niente")
        XCTAssertEqual(LetturaScansioni.ricomponiSillabate([riga("nord-"), riga("Est", y: 686)]).righe.map(\.testo), ["nord-", "Est"],
                       "una maiuscola dopo il trattino: niente")
        XCTAssertEqual(LetturaScansioni.ricomponiSillabate([riga("anni 1990-"), riga("2000", y: 686)]).unite, 0, "cifre: niente")
    }

    func test_candidata_coordinateDallAltoASinistra() {
        let c = EstrattoreScansioni.candidata(BBox(x: 10, y: 20, width: 30, height: 40), etichetta: "table", pagina: 3, W: 200, H: 100)
        XCTAssertEqual(c.bbox, [10, 40, 40, 80])
        XCTAssertEqual(c.pageIndex, 3)
        XCTAssertEqual(c.label, "table")
    }

    func test_portaDeiCodici_soloConLaGeometriaDeiCodici() {
        func ex(_ w: Double, _ h: Double) -> PdfExtraction {
            PdfExtraction(version: 1, pageCount: 1, pages: [PdfPageExtraction(pageIndex: 0, width: w, height: h, lines: [])])
        }
        XCTAssertEqual(EstrattoreScansioni.portaCodiciAperta(ex(357, 547)).producer, "PDFsharp")
        XCTAssertEqual(EstrattoreScansioni.portaCodiciAperta(ex(420, 595)), ex(420, 595), "altra geometria: identica")
    }

    /// L'osservazione accesa scrive i passi e non cambia l'estrazione (la lettura del testo di Apple su una scansione sintetica).
    func test_osservazione_scriveIPassi_eNonCambiaLEstrazione() throws {
        let url = try LetturaScansioniTests.pagina(["Prima frase della pagina di prova", "una seconda riga con altre parole"],
                                                   comeTesto: false,
                                                   in: FileManager.default.temporaryDirectory.appendingPathComponent("oss-\(UUID().uuidString).pdf"))
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("oss-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: url); try? FileManager.default.removeItem(at: dir) }
        let a = try XCTUnwrap(try EstrattoreScansioni(lettore: .apple, via: .v1).extract(fromUri: url.path, onPageExtracted: { _, _ in },
                                                                                         isCancelled: { false }))
        let e = EstrattoreScansioni(lettore: .apple, via: .v1)
        e.cartellaOsservazione = dir
        let b = try XCTUnwrap(try e.extract(fromUri: url.path, onPageExtracted: { _, _ in }, isCancelled: { false }))
        XCTAssertEqual(a, b, "osservare non cambia ciò che la catena riceve")
        let o = try JSONDecoder().decode(EstrattoreScansioni.OsservazionePagina.self,
                                         from: Data(contentsOf: dir.appendingPathComponent("o0.json")))
        XCTAssertFalse(o.righeGrezze.isEmpty)
        XCTAssertEqual(o.righeFinali.map(\.testo).joined(separator: " ").contains("seconda riga"), true)
        XCTAssertTrue(o.varianti.isEmpty)
    }
}
