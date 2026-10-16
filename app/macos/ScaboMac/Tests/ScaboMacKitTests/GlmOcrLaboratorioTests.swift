//
//  GlmOcrLaboratorioTests.swift
//  ScaboMacKitTests
//
//  Il lettore GLM-OCR dentro l'app (giro «costruzione della linea Mac», 2026-10-16). Sempre: la pagina di prova inclusa
//  (testo scritto per il progetto, libero da diritti) e la misura d'accordo. Solo in laboratorio (variabile
//  `SCABO_GLM_PESI` = cartella con i due file): la lettura vera, DOPO aver verificato che i pesi abbiano esattamente
//  l'impronta pubblicata scritta nel catalogo (regola del progetto: nessun peso si usa prima di questa verifica).
//

import XCTest
@testable import ScaboMacKit
@testable import ScaboMacOCR

final class GlmOcrLaboratorioTests: XCTestCase {

    func test_paginaDiProva_inclusa_eLeggibile() throws {
        let p = try XCTUnwrap(GlmOcr.paginaDiProva)
        XCTAssertGreaterThan(p.png.count, 10_000)
        XCTAssertEqual(Array(p.png.prefix(4)), [0x89, 0x50, 0x4E, 0x47], "è un PNG")
        XCTAssertGreaterThan(GlmOcr.parole(p.testo).count, 60)
    }

    func test_accordo_fraParole() {
        XCTAssertEqual(GlmOcr.accordo(letto: "Il gatto, sul tetto.", atteso: "il gatto sul tetto"), 1)
        XCTAssertEqual(GlmOcr.accordo(letto: "nulla", atteso: "tutt'altro testo"), 0)
        XCTAssertEqual(GlmOcr.accordo(letto: "", atteso: "testo"), 0)
        XCTAssertEqual(GlmOcr.accordo(letto: "a b c d", atteso: "a b c e"), 0.75, accuracy: 1e-9)
    }

    func test_ripulisci_togleIContrassegniDelModello() {
        XCTAssertEqual(GlmOcr.ripulisci("<|begin_of_box|>Testo<|end_of_box|>\n"), "Testo")
    }

    func test_letturaVera_conIPesiVerificati() throws {
        guard let dir = ProcessInfo.processInfo.environment["SCABO_GLM_PESI"] else {
            throw XCTSkip("prova di laboratorio: serve SCABO_GLM_PESI con i pesi di GLM-OCR")
        }
        let c = try CatalogLoader.loadBundled()
        let spec = try XCTUnwrap(c.voci.first { $0.id == "glm-ocr" }?.scaricamento)
        var url: [String: URL] = [:]
        for f in spec.file {
            let u = URL(fileURLWithPath: dir).appendingPathComponent(f.nome)
            XCTAssertEqual(ModelStore.sha256Hex(of: u), f.sha256, "impronta pubblicata di \(f.nome)")
            url[f.ruolo] = u
        }
        let prova = try XCTUnwrap(GlmOcr.paginaDiProva)
        let r = try GlmOcr.leggi(png: prova.png, pesi: try XCTUnwrap(url["pesi"]), proiettore: try XCTUnwrap(url["proiettore"]))
        let a = GlmOcr.accordo(letto: r.testo, atteso: prova.testo)
        print("LETTURA_GLM caricamento=\(r.secondiCaricamento) lettura=\(r.secondiLettura) token=\(r.tokenGenerati) accordo=\(a)")
        print("LETTURA_GLM_TESTO_INIZIO\n\(r.testo)\nLETTURA_GLM_TESTO_FINE")
        XCTAssertGreaterThanOrEqual(a, RealModelService.sogliaVerifica)
    }
}
