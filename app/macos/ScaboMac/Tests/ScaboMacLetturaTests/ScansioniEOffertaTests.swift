//
//  ScansioniEOffertaTests.swift
//  ScaboMacLetturaTests — le scansioni nell'importazione del Mac e la lettura migliore che arriva da sola (giro «modelli e
//  scansioni», 2026-11-18; LAYER2 § 12.16, decisioni 20 e 21). Il lettore è finto (dà l'estrazione del libro sintetico): qui si
//  prova la logica dell'importazione e dell'offerta, non la lettura delle immagini (che provano i test di ScaboMacKit).
//  Contenuti sintetici: nessun testo dei volumi.
//
import AppKit
import ScaboChain
import ScaboCore
import XCTest
@testable import ScaboMacLettura

/// Un estrattore finto: per qualunque file dà l'estrazione del libro sintetico, o fallisce come un lettore che non parte.
final class EstrattoreFinto: ProgressReportingPdfExtractor {
    let lettore: String
    let testo: URL
    let fallisce: Bool
    private(set) var fallito = false
    init(lettore: String, testo: URL, fallisce: Bool) { self.lettore = lettore; self.testo = testo; self.fallisce = fallisce }
    func extract(fromUri uri: String, onPageExtracted: (Int, Int) -> Void, isCancelled: () -> Bool) throws -> PdfExtraction? {
        if fallisce {
            fallito = true
            throw NSError(domain: "prova", code: 1, userInfo: [NSLocalizedDescriptionKey: "Il lettore di prova non è partito."])
        }
        return try PdfKitExtractor().extract(fromUri: testo.path, onPageExtracted: onPageExtracted, isCancelled: isCancelled)
    }
}

@MainActor
final class ScansioniDiProva: FornitoreScansioni {
    let testo: URL
    var falliscePer: Set<String> = []
    var richiesti: [String] = []
    var pannelloAperto = 0
    init(testo: URL) { self.testo = testo }
    var lettori: [LettoreDisponibile] {
        [LettoreDisponibile(id: "apple", nome: "lettura del testo di Apple", descrizione: "veloce", installato: true),
         LettoreDisponibile(id: "glm", nome: "GLM lettura pagine", descrizione: "più preciso", installato: true)]
    }
    var predefinito: String { "apple" }
    func estrattore(lettore: String) -> ProgressReportingPdfExtractor {
        richiesti.append(lettore)
        return EstrattoreFinto(lettore: lettore, testo: testo, fallisce: falliscePer.contains(lettore))
    }
    func problema(di estrattore: ProgressReportingPdfExtractor) -> (messaggio: String, altroLettore: String?)? {
        guard let e = estrattore as? EstrattoreFinto, e.fallito else { return nil }
        return ("Il lettore di prova non è partito.", e.lettore == "glm" ? "apple" : nil)
    }
    func provenienza(di estrattore: ProgressReportingPdfExtractor) -> ProvenienzaScansione? {
        guard let e = estrattore as? EstrattoreFinto else { return nil }
        return ProvenienzaScansione(lettore: e.lettore == "glm" ? "GLM lettura pagine" : "lettura del testo di Apple",
                                    idLettore: e.lettore, pagineLette: 1, pagine: 1)
    }
    func apriPannelloModelli() { pannelloAperto += 1 }
    /// La regola di prova: scansione se almeno metà delle pagine è senza testo (quella vera sta col lettore, in ScaboMacKit).
    func scansione(_ url: URL) -> (senzaTesto: Int, totale: Int)? {
        let r = RilevaScansione.pagineSenzaTesto(url)
        return r.totale > 0 && r.senzaTesto * 2 >= r.totale ? r : nil
    }
}

@MainActor
final class ScansioniEOffertaTests: XCTestCase {
    private var radice: URL!
    private var libreria: LibreriaMac!
    private var importazione: ImportazioneMac!
    private var presentatore: PresentatoreDiProva!
    private var scansioni: ScansioniDiProva!
    private var pdf: URL!
    private var scansione: URL!

    override func setUp() async throws {
        radice = FileManager.default.temporaryDirectory.appendingPathComponent("libreria-scan-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: radice, withIntermediateDirectories: true)
        libreria = LibreriaMac(service: LibraryService(rootDirectory: radice.appendingPathComponent("lib"), prefs: InMemoryKeyValueStore()))
        importazione = ImportazioneMac(libreria: libreria)
        presentatore = PresentatoreDiProva()
        importazione.presentatore = presentatore
        pdf = try LibroSintetico.scrivi(in: radice.appendingPathComponent("Libro di prova.pdf"))
        scansione = try Self.scansioneSintetica(in: radice.appendingPathComponent("Scansione di prova.pdf"))
        scansioni = ScansioniDiProva(testo: pdf)
        importazione.scansioni = scansioni
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: radice)
    }

    /// Un PDF di una pagina con una sola immagine (nessun font): una scansione.
    static func scansioneSintetica(in url: URL) throws -> URL {
        var box = CGRect(x: 0, y: 0, width: 300, height: 400)
        guard let ctx = CGContext(url as CFURL, mediaBox: &box, nil),
              let bmp = CGContext(data: nil, width: 60, height: 80, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else {
            throw NSError(domain: "prova", code: 2)
        }
        bmp.setFillColor(gray: 0.9, alpha: 1); bmp.fill(CGRect(x: 0, y: 0, width: 60, height: 80))
        bmp.setFillColor(gray: 0.1, alpha: 1); bmp.fill(CGRect(x: 10, y: 40, width: 40, height: 4))
        let img = bmp.makeImage()!
        ctx.beginPDFPage(nil)
        ctx.draw(img, in: box)
        ctx.endPDFPage()
        ctx.closePDF()
        return url
    }

    private func aspetta(_ azione: () -> Void) async {
        let e = expectation(description: "fine")
        presentatore.quandoApre = { e.fulfill() }
        azione()
        await fulfillment(of: [e], timeout: 120)
        presentatore.quandoApre = nil
    }

    // MARK: Scansioni (decisione 21)

    func test_rilevaScansione_immagineSenzaFont_eTestoConFont() {
        XCTAssertEqual(RilevaScansione.pagineSenzaTesto(scansione).senzaTesto, 1)
        XCTAssertEqual(RilevaScansione.pagineSenzaTesto(scansione).totale, 1)
        XCTAssertEqual(RilevaScansione.pagineSenzaTesto(pdf).senzaTesto, 0, "il libro sintetico ha testo su ogni pagina")
    }

    func test_scansione_laSchermataChiedeIlLettore_poiLeggeERegistraLaProvenienza() async throws {
        await aspetta { importazione.importa(scansione) }
        XCTAssertEqual(presentatore.errori, [])
        XCTAssertEqual(presentatore.sceltePerScansioni.count, 1)
        XCTAssertEqual(presentatore.sceltePerScansioni.first?.senzaTesto, 1)
        XCTAssertEqual(presentatore.sceltePerScansioni.first?.predefinito, "apple", "il predefinito del banco")
        XCTAssertEqual(scansioni.richiesti, ["apple"])
        XCTAssertEqual(presentatore.elaborazioniDiScansioni, 1, "la fase d'estrazione si chiama «Lettura delle scansioni»")
        let doc = try XCTUnwrap(presentatore.aperte.first?.0)
        XCTAssertEqual(libreria.provenienze.provenienza(doc.id)?.idLettore, "apple")
        XCTAssertTrue(libreria.rigaDelLibro(doc).hasSuffix("testo da una scansione, letto con la lettura del testo di Apple"))
        XCTAssertFalse(importazione.occupato)
        // La provenienza resta dopo un nuovo avvio (file della libreria del Mac) e se ne va con il libro.
        XCTAssertNotNil(ProvenienzeScansioni(service: libreria.service).provenienza(doc.id))
        libreria.eliminaDefinitivamente(doc.id)
        XCTAssertNil(ProvenienzeScansioni(service: libreria.service).provenienza(doc.id))
    }

    func test_scansione_ilLettoreNonParte_lImportazioneNonSiChiudeEProponeLAltro() async throws {
        scansioni.falliscePer = ["glm"]
        presentatore.sceltaLettore = "glm"
        await aspetta { importazione.importa(scansione) }
        XCTAssertEqual(presentatore.altriProposti, ["apple"], "dice perché e propone la lettura di Apple")
        XCTAssertEqual(scansioni.richiesti, ["glm", "apple"])
        XCTAssertEqual(presentatore.errori, [], "nessun errore che chiude l'importazione")
        let doc = try XCTUnwrap(presentatore.aperte.first?.0)
        XCTAssertEqual(libreria.provenienze.provenienza(doc.id)?.idLettore, "apple")
        XCTAssertFalse(importazione.occupato)
    }

    func test_scansione_rifiutoDellAltroLettore_nienteSiApreENienteResta() async throws {
        scansioni.falliscePer = ["glm"]
        presentatore.sceltaLettore = "glm"
        presentatore.accettaAltro = false
        await aspetta { importazione.importa(scansione) }
        XCTAssertTrue(presentatore.aperte.isEmpty)
        XCTAssertEqual(libreria.libri().count, 0)
        XCTAssertFalse(importazione.occupato)
    }

    func test_scansione_annullataNellaSchermata_nienteSiApre() async throws {
        presentatore.sceltaLettore = .some(nil)
        await aspetta { importazione.importa(scansione) }
        XCTAssertTrue(presentatore.aperte.isEmpty)
        XCTAssertEqual(scansioni.richiesti, [])
        XCTAssertFalse(importazione.occupato)
    }

    func test_pdfConTesto_nessunaDomanda_comeSulliPad() async throws {
        await aspetta { importazione.importa(pdf) }
        XCTAssertTrue(presentatore.sceltePerScansioni.isEmpty)
        XCTAssertEqual(presentatore.elaborazioniDiScansioni, 0)
        XCTAssertEqual(scansioni.richiesti, [])
        let doc = try XCTUnwrap(presentatore.aperte.first?.0)
        XCTAssertNil(libreria.provenienze.provenienza(doc.id))
        XCTAssertEqual(libreria.rigaDelLibro(doc), LibraryFormatting.fileAccessibility(doc), "la riga dell'iPad, identica")
    }

    func test_senzaLettore_laScansioneSegueLaStradaDelliPad() async throws {
        importazione.scansioni = nil
        await aspetta { importazione.importa(scansione) }
        XCTAssertEqual(presentatore.errori.count, 1)
        XCTAssertTrue(presentatore.errori.first?.contains("non contiene testo leggibile") == true, "il controllo e le parole dell'iPad")
    }

    // MARK: La lettura migliore (decisione 20)

    private func libroImportato() async throws -> ArchivedDocument {
        await aspetta { importazione.importa(pdf) }
        return try XCTUnwrap(presentatore.aperte.first?.0)
    }

    private func letturaInUso(_ id: String) throws -> PackagedReading {
        let c = try XCTUnwrap(libreria.service.loadCache(forDocumentId: id))
        return PackagedReading(content: c.content, pageMap: c.pageMap, doctrineContent: c.doctrineContent,
                               quickConsultTree: c.quickConsultTree, contentTarget: c.contentTarget ?? 400)
    }

    func test_offerta_letturaUguale_nessunaOffertaELoDice() async throws {
        let doc = try await libroImportato()
        let offerta = OffertaMac(libreria: libreria)
        var annunci: [String] = [], arrivi: [String?] = []
        offerta.annunciPerProva = { annunci.append($0) }
        offerta.quandoArriva = { arrivi.append($0) }
        XCTAssertFalse(offerta.arriva(try letturaInUso(doc.id), righe: [], per: doc.id))
        XCTAssertNil(libreria.offerte.inAttesa(doc.id))
        XCTAssertEqual(arrivi.count, 0)
        XCTAssertEqual(annunci, [ParoleLetturaMigliore.nienteDaCambiare(doc.title)], "niente arriva in silenzio")
        XCTAssertFalse(libreria.rigaDelLibro(doc).contains(ParoleLetturaMigliore.segnoRiga))
    }

    func test_offerta_letturaDiversa_arrivaDaSolaConAnnuncioPulsanteESegno_poiUsaETorna() async throws {
        let doc = try await libroImportato()
        let prima = try letturaInUso(doc.id)
        // Un segnalibro sul primo blocco: si riancora per contenuto, mai spostato in silenzio.
        let primo = try XCTUnwrap(prima.content.pages.first?.segments.first)
        XCTAssertNotNil(libreria.service.store.addBookmark(documentId: doc.id, anchorSegmentId: primo.id, orderIndexHint: 0,
                                                           preview: String(primo.text.prefix(20))))
        var nuova = prima
        var pagine = nuova.content.pages
        pagine[pagine.count - 1].segments[pagine[pagine.count - 1].segments.count - 1].role = "INDEX_ENTRY"
        nuova.content.pages = pagine
        let offerta = OffertaMac(libreria: libreria)
        var annunci: [String] = [], arrivi: [String?] = []
        offerta.annunciPerProva = { annunci.append($0) }
        offerta.quandoArriva = { arrivi.append($0) }
        XCTAssertTrue(offerta.arriva(nuova, righe: ["legge come testo dell'indice una voce che prima era letta come nota"], per: doc.id))
        XCTAssertEqual(arrivi, [doc.id], "il pulsante «Apri ora» per quel libro")
        XCTAssertEqual(annunci.last, ParoleLetturaMigliore.arrivata(doc.title))
        XCTAssertTrue(libreria.rigaDelLibro(libreria.service.store.document(id: doc.id)!).hasSuffix(ParoleLetturaMigliore.segnoRiga))
        // L'offerta resta finché non si sceglie (anche dopo un nuovo avvio).
        XCTAssertNotNil(OfferteMigliori(service: libreria.service).inAttesa(doc.id))
        // Due gesti: «Usa la lettura migliore…» e poi la conferma (qui le scelte di prova).
        offerta.scelteDiProva = { id in id == "offerta.conferma" ? 1 : (id == "offerta" ? 0 : 2) }
        offerta.apriOfferta(doc.id)
        XCTAssertEqual(try letturaInUso(doc.id).content, nuova.content, "la lettura migliore in uso")
        XCTAssertTrue(libreria.service.hasPreviousReading(forDocumentId: doc.id), "la lettura di prima resta finché non si conferma")
        XCTAssertNil(libreria.offerte.inAttesa(doc.id))
        let segnalibro = try XCTUnwrap(libreria.service.store.document(id: doc.id)?.bookmarks?.first)
        XCTAssertEqual(segnalibro.anchorSegmentId, primo.id, "ritrovato per contenuto, al suo posto")
        // «Torna alla lettura precedente».
        offerta.torna(doc.id)
        XCTAssertEqual(try letturaInUso(doc.id).content, prima.content)
        XCTAssertFalse(libreria.service.hasPreviousReading(forDocumentId: doc.id))
        XCTAssertEqual(annunci.last, ParoleLetturaMigliore.tornato)
    }

    func test_offerta_confermaConAnnullaPreferito_nienteCambia() async throws {
        let doc = try await libroImportato()
        var nuova = try letturaInUso(doc.id)
        nuova.content.pages[0].segments[0].role = "INDEX_ENTRY"
        let offerta = OffertaMac(libreria: libreria)
        offerta.annunciPerProva = { _ in }
        XCTAssertTrue(offerta.arriva(nuova, righe: [], per: doc.id))
        offerta.scelteDiProva = { id in id == "offerta" ? 0 : 0 }   // «Usa…», poi Annulla (il preferito)
        offerta.apriOfferta(doc.id)
        XCTAssertNotEqual(try letturaInUso(doc.id).content, nuova.content, "un gesto solo non basta")
        XCTAssertNotNil(libreria.offerte.inAttesa(doc.id), "l'offerta resta")
    }
}
