//
//  CatenaScansioniTests.swift
//  ScaboMacKitTests — le tabelle viste sulle pagine lette arrivano alla catena (giro «migliorie del banco nelle app», 2026-11-21): le
//  candidate si uniscono a quelle del riconoscimento della catena; la guardia condivisa ne fa una risorsa visiva annunciata, col testo
//  al suo posto; senza candidate la catena è quella di prima, elemento per elemento; la miglioria spenta non raccoglie nulla.
//  Pagine sintetiche di `LetturaScansioniTests` (testo di prova, nessun testo di volumi).
//
import Foundation
import PDFKit
import ScaboChain
import ScaboCore
import XCTest
@testable import ScaboMacKit

final class CatenaScansioniTests: XCTestCase {

    final class FonteFinta: FonteRisorseScansioni {
        let candidateRisorse: [VisualRegionCandidate]
        let pagineLette: [Int]
        init(_ c: [VisualRegionCandidate], lette: [Int]) { candidateRisorse = c; pagineLette = lette }
    }

    private let frasi = ["Colonna prima della prova", "riga due della tabella di prova", "riga tre della tabella di prova",
                         "riga quattro della tabella di prova", "una riga di chiusura fuori"]

    private func pdf() throws -> URL {
        try LetturaScansioniTests.pagina(frasi, comeTesto: true,
                                         in: FileManager.default.temporaryDirectory.appendingPathComponent("catena-\(UUID().uuidString).pdf"))
    }

    private func candidata(pagina: Int, bbox: [Double], etichetta: String = "table") -> VisualRegionCandidate {
        VisualRegionCandidate(pageIndex: pagina, label: etichetta, bbox: bbox, confidence: 1, pageWidth: 420, pageHeight: 595)
    }

    private func segmenti(_ esito: ChainOutcome) throws -> [ContentSegment] {
        guard case .success(let r) = esito else { throw NSError(domain: "prova", code: 1, userInfo: [NSLocalizedDescriptionKey: "\(esito)"]) }
        return r.content.pages.flatMap { $0.segments }
    }

    func test_unisci_leRilevateFuoriDallePagineLette_poiQuelleDelleScansioni() {
        let a = candidata(pagina: 0, bbox: [1, 2, 3, 4]), b = candidata(pagina: 1, bbox: [5, 6, 7, 8]), c = candidata(pagina: 1, bbox: [9, 9, 20, 20])
        let u = CatenaScansioni.unisci(rilevate: [a, b], scansioni: [c], pagineLette: [1])
        XCTAssertEqual(u, [a, c], "sulla pagina letta dal lettore valgono le regioni viste sulla sua immagine")
    }

    /// Senza nulla da aggiungere la catena è quella di prima: stessi elementi, stessi testi, stessi ruoli.
    func test_senzaCandidate_comeLaCatenaDiPrima() throws {
        let url = try pdf(); defer { try? FileManager.default.removeItem(at: url) }
        let opzioni = ChainOptions(granularityTarget: 400)
        let prima = try segmenti(ProcessingChain.run(fileURL: url, sourceName: "p.pdf", extractor: PdfKitExtractor(), options: opzioni,
                                                     onProgress: { _ in }, isCancelled: { false }))
        var fasi: [ChainPhase] = []
        let dopo = try segmenti(CatenaScansioni.run(fileURL: url, sourceName: "p.pdf", extractor: PdfKitExtractor(), fonte: FonteFinta([], lette: []),
                                                    options: opzioni, onProgress: { fasi.append($0.phase) }, isCancelled: { false }))
        XCTAssertEqual(dopo.map(\.text), prima.map(\.text))
        XCTAssertEqual(dopo.map(\.role), prima.map(\.role))
        XCTAssertEqual(fasi.first, .opening, "l'avanzamento comincia dall'apertura, una volta sola")
        XCTAssertEqual(fasi.filter { $0 == .opening }.count, 1)
    }

    /// Con una tabella vista sulla pagina letta: la lettura la annuncia come risorsa visiva della tabella, e il testo resta al suo posto
    /// (tolti gli elementi della risorsa, la lettura è quella senza).
    func test_conUnaTabellaVista_risorsaAnnunciata_eTestoAlSuoPosto() throws {
        let url = try pdf(); defer { try? FileManager.default.removeItem(at: url) }
        let opzioni = ChainOptions(granularityTarget: 400)
        let senza = try segmenti(ProcessingChain.run(fileURL: url, sourceName: "p.pdf", extractor: PdfKitExtractor(), options: opzioni,
                                                     onProgress: { _ in }, isCancelled: { false }))
        // Le righe 2-4 della pagina (origine in alto: 595 - 540 + 22 * k, corpo 14): il riquadro le contiene, non la prima né l'ultima.
        let tabella = candidata(pagina: 0, bbox: [30, 70, 400, 130])
        let con = try segmenti(CatenaScansioni.run(fileURL: url, sourceName: "p.pdf", extractor: PdfKitExtractor(),
                                                   fonte: FonteFinta([tabella], lette: [0]), options: opzioni,
                                                   onProgress: { _ in }, isCancelled: { false }))
        let risorse = con.filter { $0.visualResource != nil }
        XCTAssertEqual(risorse.count, 1, "la tabella vista diventa una risorsa visiva")
        XCTAssertEqual(risorse.first?.visualResource?.kind, .table)
        let testo = con.filter { $0.visualResource == nil }
        XCTAssertEqual(testo.map(\.text), senza.map(\.text), "il testo della tabella resta nel flusso, al suo posto")
        XCTAssertEqual(testo.map(\.role), senza.map(\.role))
    }

    /// Una regione «tabella» delle scansioni passa alla catena solo se è larga almeno un quarto della pagina e contiene almeno due righe
    /// lette: un'intestazione incorniciata di una riga sola o una colonna stretta di numeri non si annunciano come tabelle.
    func test_tabellaAmmessa_larghezzaEDueRighe() {
        func riga(_ y: Double, x: Double = 60, w: Double = 300) -> RigaLetta {
            RigaLetta(testo: "riga di prova", bbox: BBox(x: x, y: y, width: w, height: 10), regione: 0)
        }
        let righe = [riga(500), riga(480), riga(460), riga(300, x: 400, w: 30), riga(280, x: 400, w: 30), riga(260, x: 400, w: 30)]
        XCTAssertTrue(EstrattoreScansioni.tabellaAmmessa(BBox(x: 50, y: 450, width: 320, height: 70), righe, larghezza: 420), "larga e con tre righe")
        XCTAssertFalse(EstrattoreScansioni.tabellaAmmessa(BBox(x: 50, y: 495, width: 320, height: 20), righe, larghezza: 420), "una riga sola")
        XCTAssertFalse(EstrattoreScansioni.tabellaAmmessa(BBox(x: 395, y: 250, width: 40, height: 70), righe, larghezza: 420), "una colonna stretta")
    }

    /// La miglioria spenta (solo laboratorio) non raccoglie candidate: la via di prima.
    func test_migliorieSpente_nessunaCandidata() throws {
        let url = try LetturaScansioniTests.pagina(frasi, comeTesto: false,
                                                   in: FileManager.default.temporaryDirectory.appendingPathComponent("scan-\(UUID().uuidString).pdf"))
        defer { try? FileManager.default.removeItem(at: url) }
        let e = EstrattoreScansioni(lettore: .apple)
        e.migliorie = .spente
        _ = try e.extract(fromUri: url.path, onPageExtracted: { _, _ in }, isCancelled: { false })
        XCTAssertEqual(e.pagineLette, [0])
        XCTAssertTrue(e.candidateRisorse.isEmpty)
        XCTAssertEqual(MiglioriScansioni.spente.spenteNomi, MiglioriScansioni.nomi)
        XCTAssertEqual(MiglioriScansioni(spente: "tutte"), .spente)
        XCTAssertNil(MiglioriScansioni(spente: "nessuna-cosa"))
    }
}
