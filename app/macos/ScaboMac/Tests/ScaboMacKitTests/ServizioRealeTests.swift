//
//  ServizioRealeTests.swift
//  ScaboMacKitTests
//
//  Il servizio VERO dei modelli (giro «costruzione della linea Mac», 2026-10-16) con file locali al posto della rete
//  (trasporto diretto: lo stesso scaricatore in streaming del servizio XPC): stati, avanzamento annunciato, impronte,
//  annullamento e guasti senza residui, rimozione completa (cache comprese), riavvio, conferma con dimensione e fonte,
//  regole del catalogo vero. Byte sintetici, nessun peso vero, nessuna rete.
//

import CryptoKit
import XCTest
@testable import ScaboMacKit
import ScaboCore
import ScaricatoreProtocollo

@MainActor
final class ServizioRealeTests: XCTestCase {

    private var dirs: [URL] = []

    override func tearDown() async throws {
        for d in dirs { try? FileManager.default.removeItem(at: d) }
        dirs = []
    }

    private func tempDir(_ name: String) -> URL {
        let d = FileManager.default.temporaryDirectory.appendingPathComponent("servizio_\(name)_\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        dirs.append(d)
        return d
    }

    private func sha(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }

    /// Una voce scaricabile con due file locali (pesi e proiettore) di byte deterministici.
    private func voce(sizes: [Int] = [300_000, 200_000], sbagliaImpronta: Bool = false) throws -> (CatalogEntry, URL) {
        let fonte = tempDir("fonte")
        var files: [ModelDownloadFile] = []
        for (i, n) in sizes.enumerated() {
            var bytes = [UInt8](repeating: 0, count: n)
            for k in 0..<n { bytes[k] = UInt8(truncatingIfNeeded: k &* (i + 3) &+ 11) }
            let data = Data(bytes)
            let url = fonte.appendingPathComponent("file\(i).gguf")
            try data.write(to: url)
            files.append(ModelDownloadFile(nome: "file\(i).gguf", indirizzo: url.absoluteString, byte: Int64(n),
                                           sha256: sbagliaImpronta && i == 1 ? String(repeating: "0", count: 64) : sha(data),
                                           ruolo: i == 0 ? "pesi" : "proiettore"))
        }
        let e = CatalogEntry(id: "prova-ocr", nome: "Lettore di prova", ruolo: .lettoreScansioni, descrizione: "Prova.",
                             dimensioneByte: Int64(sizes.reduce(0, +)), licenza: "MIT.", motore: .nativoNellApp,
                             requisiti: ModelRequirements(macOSMinimo: "14.0", richiedeAppleSilicon: false, memoriaConsigliataGB: 0),
                             funzionaSenzaInternet: true, validazione: .nonMisurato,
                             provenienza: ModelProvenance(indirizzo: "https://huggingface.co/prova", versione: "1", editore: "Prova"),
                             provvisoria: false,
                             scaricamento: ModelDownloadSpec(repository: "prova/prova", revisione: "abcdef0123", file: files))
        return (e, fonte)
    }

    private func servizio(_ e: CatalogEntry, store: ModelStore) -> (RealModelService, PanelViewModel, RecordingAnnouncer) {
        let c = ModelCatalog(schemaVersione: 1, aggiornatoIl: "2026-10-16", voci: [e])
        let s = RealModelService(catalog: c, store: store, makeTransport: { DirectDownloadTransport(passoAvviso: 20_000) })
        s.freeBytesProvider = { 1_000_000_000_000 }
        let a = RecordingAnnouncer()
        let m = PanelViewModel(service: s, announcer: a, prefs: InMemoryKeyValueStore())
        return (s, m, a)
    }

    private func attendi(_ m: PanelViewModel, _ id: String, finché condizione: (ModelState) -> Bool) async {
        for _ in 0..<400 where condizione(m.state(of: id)) { try? await Task.sleep(nanoseconds: 25_000_000) }
    }

    func test_scaricamento_vero_avanzamentoAnnunciato_improntaControllata_segnoScritto() async throws {
        let (e, _) = try voce()
        let store = ModelStore(root: tempDir("modelli"))
        let (s, m, a) = servizio(e, store: store)
        XCTAssertFalse(s.isSimulation, "il servizio dell'app non è una simulazione")
        XCTAssertEqual(m.state(of: e.id), .nonScaricato)
        m.scarica(e.id)
        await attendi(m, e.id) { if case .inScaricamento = $0 { return true }; return false }
        XCTAssertEqual(m.state(of: e.id), .scaricato)
        XCTAssertTrue(store.isInstalled(e))
        for f in e.scaricamento!.file {
            XCTAssertEqual(ModelStore.sha256Hex(of: store.file(e.id, f.nome)), f.sha256)
            XCTAssertFalse(FileManager.default.fileExists(atPath: store.parziale(e.id, f.nome).path), "nessun parziale resta")
        }
        XCTAssertEqual(a.testi.first, Testi.annuncioScaricamentoAvviato(e.nome, e.dimensioneInParole))
        XCTAssertTrue(a.testi.contains(Testi.annuncioAvanzamento(e.nome, 25)) || a.testi.contains(Testi.annuncioAvanzamento(e.nome, 50)),
                      "l'avanzamento è annunciato: \(a.testi)")
        XCTAssertEqual(a.testi.last, Testi.annuncioScaricamentoCompletato(e.nome))
        // Riavvio: un servizio nuovo ritrova la voce scaricata.
        let (_, m2, _) = servizio(e, store: store)
        XCTAssertEqual(m2.state(of: e.id), .scaricato)
        XCTAssertEqual(m2.azioni(per: e), [.verificaFunzionamento, .rimuovi])
    }

    func test_improntaSbagliata_fileDanneggiato_nienteRestaSulDisco() async throws {
        let (e, _) = try voce(sbagliaImpronta: true)
        let store = ModelStore(root: tempDir("modelli"))
        let (_, m, a) = servizio(e, store: store)
        m.scarica(e.id)
        await attendi(m, e.id) { if case .inScaricamento = $0 { return true }; return false }
        XCTAssertEqual(m.state(of: e.id), .errore(.fileDanneggiato))
        XCTAssertFalse(store.isInstalled(e))
        let restanti = (try? FileManager.default.contentsOfDirectory(atPath: store.dir(e.id).path)) ?? []
        XCTAssertFalse(restanti.contains { $0.hasSuffix(".parziale") }, "nessun parziale: \(restanti)")
        XCTAssertTrue(a.testi.last?.contains(Testi.erroreFileDanneggiato) ?? false)
    }

    /// Un trasporto comandato dalla prova: registra le chiamate e risponde solo quando la prova lo decide.
    final class TrasportoComandato: DownloadTransport {
        struct Chiamata { let url: URL; let handle: FileHandle; let byte: Int64
                          let avanzamento: (Int64) -> Void; let risposta: (Int64, String?) -> Void }
        var chiamate: [Chiamata] = []
        var annullato = false
        var chiuso = false
        func scarica(_ url: URL, verso handle: FileHandle, byteAttesi: Int64,
                     avanzamento: @escaping (Int64) -> Void, risposta: @escaping (Int64, String?) -> Void) {
            chiamate.append(Chiamata(url: url, handle: handle, byte: byteAttesi, avanzamento: avanzamento, risposta: risposta))
        }
        func annulla() { annullato = true; chiamate.last?.risposta(0, ProblemaScaricamento.annullato) }
        func chiudi() { chiuso = true }
        /// Consegna il file vero (i byte della fonte) e risponde «riuscito».
        func consegna(_ fonte: URL) throws {
            let c = chiamate.last!
            let data = try Data(contentsOf: fonte)
            try c.handle.write(contentsOf: data)
            c.avanzamento(Int64(data.count))
            c.risposta(Int64(data.count), nil)
        }
    }

    private func servizioComandato(_ e: CatalogEntry, store: ModelStore, liberi: Int64 = 1_000_000_000_000)
        -> (RealModelService, PanelViewModel, RecordingAnnouncer, () -> TrasportoComandato?) {
        let c = ModelCatalog(schemaVersione: 1, aggiornatoIl: "2026-10-16", voci: [e])
        var ultimo: TrasportoComandato?
        let s = RealModelService(catalog: c, store: store, makeTransport: { let t = TrasportoComandato(); ultimo = t; return t })
        s.freeBytesProvider = { liberi }
        let a = RecordingAnnouncer()
        let m = PanelViewModel(service: s, announcer: a, prefs: InMemoryKeyValueStore())
        return (s, m, a, { ultimo })
    }

    private func lasciaGirare() async { for _ in 0..<20 { await Task.yield() }; try? await Task.sleep(nanoseconds: 50_000_000) }

    func test_annullamento_deterministico_tornaNonScaricato_senzaResidui_trasportoChiuso() async throws {
        let (e, _) = try voce()
        let store = ModelStore(root: tempDir("modelli"))
        let (_, m, a, trasporto) = servizioComandato(e, store: store)
        m.scarica(e.id)
        let t = try XCTUnwrap(trasporto())
        XCTAssertEqual(t.chiamate.count, 1)
        try t.chiamate[0].handle.write(contentsOf: Data(repeating: 7, count: 100_000))
        t.chiamate[0].avanzamento(100_000)
        await lasciaGirare()
        XCTAssertEqual(m.state(of: e.id), .inScaricamento(percento: 20))
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.parziale(e.id, "file0.gguf").path), "durante: c'è il parziale")
        m.annulla(e.id)
        XCTAssertTrue(t.annullato)
        await lasciaGirare()
        XCTAssertEqual(m.state(of: e.id), .nonScaricato)
        XCTAssertTrue(t.chiuso, "il trasporto si chiude (il servizio XPC esce)")
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.dir(e.id).path), "nulla di incompleto resta sul disco")
        XCTAssertEqual(a.testi.last, Testi.annuncioScaricamentoAnnullato(e.nome))
    }

    func test_dueFile_inSequenza_impronteControllate_poiScaricato() async throws {
        let (e, fonte) = try voce()
        let store = ModelStore(root: tempDir("modelli"))
        let (_, m, _, trasporto) = servizioComandato(e, store: store)
        m.scarica(e.id)
        let t = try XCTUnwrap(trasporto())
        XCTAssertEqual(t.chiamate.map(\.url.lastPathComponent), ["file0.gguf"])
        XCTAssertEqual(t.chiamate[0].byte, 300_000)
        try t.consegna(fonte.appendingPathComponent("file0.gguf"))
        await lasciaGirare()
        XCTAssertEqual(t.chiamate.map(\.url.lastPathComponent), ["file0.gguf", "file1.gguf"], "verificato il primo, parte il secondo")
        XCTAssertFalse(t.chiuso)
        try t.consegna(fonte.appendingPathComponent("file1.gguf"))
        await lasciaGirare()
        XCTAssertEqual(m.state(of: e.id), .scaricato)
        XCTAssertTrue(t.chiuso)
        XCTAssertTrue(store.isInstalled(e))
    }

    func test_annullamentoDuranteIlSecondoFile_tolgeAncheIlPrimo_nullaRestaSulDisco() async throws {
        // Revisione indipendente del giro: annullando durante il secondo file, il primo (già verificato) restava.
        let (e, fonte) = try voce()
        let store = ModelStore(root: tempDir("modelli"))
        let (_, m, a, trasporto) = servizioComandato(e, store: store)
        m.scarica(e.id)
        let t = try XCTUnwrap(trasporto())
        try t.consegna(fonte.appendingPathComponent("file0.gguf"))
        await lasciaGirare()
        XCTAssertEqual(t.chiamate.count, 2, "verificato il primo, parte il secondo")
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.file(e.id, "file0.gguf").path))
        m.annulla(e.id)
        await lasciaGirare()
        XCTAssertEqual(m.state(of: e.id), .nonScaricato)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.dir(e.id).path), "nemmeno il primo file resta")
        XCTAssertEqual(a.testi.last, Testi.annuncioScaricamentoAnnullato(e.nome), "e l'annuncio «nulla è rimasto» è vero")
    }

    func test_fileVerificatoSenzaSegno_diUnaVoltaPrecedente_siTogliAllAvvio() throws {
        // Un'app chiusa a metà scaricamento: un file verificato senza il segno della voce completa non resta.
        let (e, fonte) = try voce()
        let store = ModelStore(root: tempDir("modelli"))
        try FileManager.default.createDirectory(at: store.dir(e.id), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: fonte.appendingPathComponent("file0.gguf"), to: store.file(e.id, "file0.gguf"))
        let (_, m, _, _) = servizioComandato(e, store: store)
        XCTAssertEqual(m.state(of: e.id), .nonScaricato)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.dir(e.id).path))
    }

    func test_guastoDelServizio_nonDiceCheManchiInternet() async throws {
        let (e, _) = try voce()
        let (_, m, _, trasporto) = servizioComandato(e, store: ModelStore(root: tempDir("modelli")))
        m.scarica(e.id)
        try XCTUnwrap(trasporto()).chiamate[0].risposta(0, ProblemaScaricamento.servizio)
        await lasciaGirare()
        XCTAssertEqual(m.state(of: e.id), .errore(.sconosciuto))
        XCTAssertNotEqual(m.state(of: e.id), .errore(.connessioneAssente))
    }

    func test_rimozioneNonParte_mentreLaVerificaUsaIFile() async throws {
        let (e, _) = try voce()
        let store = ModelStore(root: tempDir("modelli"))
        let (s, m, _) = servizio(e, store: store)
        m.scarica(e.id)
        await attendi(m, e.id) { if case .inScaricamento = $0 { return true }; return false }
        XCTAssertTrue(s.puoVerificare(e.id))
        m.chiediRimozione(e.id)
        m.verifica(e.id)
        XCTAssertNil(m.confermaRimozionePer, "la domanda di rimozione si chiude quando parte la verifica")
        m.chiediRimozione(e.id)
        m.confermaRimozione()
        XCTAssertEqual(m.state(of: e.id), .scaricato, "durante la verifica nulla si toglie")
        XCTAssertTrue(store.isInstalled(e))
        for _ in 0..<400 where m.verificheInCorso.contains(e.id) { try await Task.sleep(nanoseconds: 25_000_000) }
    }

    func test_guasti_diRete_inProsa_conRiprova() async throws {
        let casi: [(String, Int64, ModelError)] = [
            (ProblemaScaricamento.rete, 0, .connessioneAssente),
            (ProblemaScaricamento.rete, 5_000, .scaricamentoInterrotto),
            (ProblemaScaricamento.rispostaNonValida, 0, .fonteNonDisponibile),
            (ProblemaScaricamento.troppiByte, 300_001, .fileDanneggiato),
            (ProblemaScaricamento.scrittura, 10, .sconosciuto),
        ]
        for (problema, scritti, atteso) in casi {
            let (e, _) = try voce()
            let store = ModelStore(root: tempDir("modelli"))
            let (_, m, a, trasporto) = servizioComandato(e, store: store)
            m.scarica(e.id)
            let t = try XCTUnwrap(trasporto())
            t.chiamate[0].risposta(scritti, problema)
            await lasciaGirare()
            XCTAssertEqual(m.state(of: e.id), .errore(atteso), problema)
            XCTAssertTrue(t.chiuso)
            XCTAssertFalse(FileManager.default.fileExists(atPath: store.parziale(e.id, "file0.gguf").path))
            XCTAssertEqual(a.testi.last, Testi.annuncioErrore(e.nome, atteso.spiegazione))
            XCTAssertEqual(m.azioni(per: e), [.riprova])
            m.esegui(.riprova, su: e)
            XCTAssertEqual(m.state(of: e.id), .inScaricamento(percento: 0), "Riprova riparte")
            XCTAssertEqual(trasporto()?.chiamate.count, 1, "con un trasporto nuovo")
        }
    }

    func test_spazioInsufficiente_nessunoScaricamento() throws {
        let (e, _) = try voce()
        let (_, m, _, trasporto) = servizioComandato(e, store: ModelStore(root: tempDir("modelli")), liberi: 1_000)
        m.scarica(e.id)
        if case .errore(.spazioInsufficiente) = m.state(of: e.id) {} else { XCTFail("\(m.state(of: e.id))") }
        XCTAssertNil(trasporto(), "nessun byte chiesto alla rete")
    }

    func test_rimozione_tolgeTutto_cacheComprese() async throws {
        let (e, _) = try voce()
        let cache = tempDir("cache_metal")
        try Data("cache".utf8).write(to: cache.appendingPathComponent("shader.bin"))
        let store = ModelStore(root: tempDir("modelli").appendingPathComponent("Modelli"), cacheRoots: [cache])
        let (_, m, a) = servizio(e, store: store)
        m.scarica(e.id)
        await attendi(m, e.id) { if case .inScaricamento = $0 { return true }; return false }
        XCTAssertEqual(m.state(of: e.id), .scaricato)
        m.chiediRimozione(e.id)
        m.confermaRimozione()
        XCTAssertEqual(m.state(of: e.id), .nonScaricato)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.root.path), "cartella dei modelli tolta")
        XCTAssertFalse(FileManager.default.fileExists(atPath: cache.path), "cache del motore tolta")
        XCTAssertEqual(a.testi.last, Testi.annuncioRimosso(e.nome, e.dimensioneInParole))
    }

    func test_parzialiDiUnaVoltaPrecedente_tolti_allAvvio() throws {
        let (e, _) = try voce()
        let store = ModelStore(root: tempDir("modelli"))
        try FileManager.default.createDirectory(at: store.dir(e.id), withIntermediateDirectories: true)
        try Data("mezzo".utf8).write(to: store.parziale(e.id, "file0.gguf"))
        let (_, m, _) = servizio(e, store: store)
        XCTAssertEqual(m.state(of: e.id), .nonScaricato)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.parziale(e.id, "file0.gguf").path))
    }

    func test_conferma_conDimensioneEFonte_primaDelloScaricamento() throws {
        let (e, _) = try voce()
        let (_, m, _) = servizio(e, store: ModelStore(root: tempDir("modelli")))
        m.esegui(.scarica, su: e)
        XCTAssertEqual(m.confermaScaricamentoPer, e.id, "prima la domanda")
        let fuoco = expectation(description: "fuoco sulla domanda")
        DispatchQueue.main.async {
            XCTAssertEqual(m.focusRichiesto, PanelViewModel.idDomanda(e.id), "VoiceOver va sulla domanda")
            fuoco.fulfill()
        }
        wait(for: [fuoco], timeout: 2)
        XCTAssertEqual(m.state(of: e.id), .nonScaricato, "niente parte senza conferma")
        let domanda = m.domandaScaricamento(e)
        XCTAssertTrue(domanda.contains(e.dimensioneInParole))
        XCTAssertTrue(domanda.contains("Prova"))
        XCTAssertTrue(domanda.contains("abcdef01"))
        XCTAssertTrue(domanda.contains("impronta"))
        m.annullaScaricamentoChiesto()
        XCTAssertNil(m.confermaScaricamentoPer)
        XCTAssertEqual(m.state(of: e.id), .nonScaricato)
        m.esegui(.scarica, su: e)
        m.confermaScaricamento()
        if case .inScaricamento = m.state(of: e.id) {} else if m.state(of: e.id) != .scaricato { XCTFail("confermato, parte") }
    }

    func test_verifica_conPesiNonValidi_fallisceInProsa_eLoAnnuncia() async throws {
        let (e, _) = try voce()
        let store = ModelStore(root: tempDir("modelli"))
        let (s, m, a) = servizio(e, store: store)
        m.scarica(e.id)
        await attendi(m, e.id) { if case .inScaricamento = $0 { return true }; return false }
        XCTAssertTrue(s.puoVerificare(e.id))
        m.verifica(e.id)
        XCTAssertTrue(m.verificheInCorso.contains(e.id))
        XCTAssertEqual(m.azioni(per: e), [], "durante la verifica nessuna azione")
        for _ in 0..<400 where m.verificheInCorso.contains(e.id) { try await Task.sleep(nanoseconds: 25_000_000) }
        XCTAssertEqual(m.esitiVerifica[e.id], Testi.esitoVerificaFallita, "byte sintetici: il lettore non parte, detto in prosa")
        XCTAssertEqual(a.testi.last, Testi.esitoVerificaFallita)
    }

    // MARK: Il catalogo vero

    func test_catalogo_GLMOCR_scaricabileDavvero_HeronIncluso() throws {
        let c = try CatalogLoader.loadBundled()
        let glm = try XCTUnwrap(c.voci.first { $0.id == "glm-ocr" })
        let spec = try XCTUnwrap(glm.scaricamento)
        XCTAssertEqual(spec.repository, "ggml-org/GLM-OCR-GGUF")
        XCTAssertEqual(spec.revisione, "65a42de1148dbed2297e922b5dbc7d9b70c36578")
        XCTAssertEqual(spec.file.map { $0.sha256 }, ["45bc244a6446aff850521dc41f18bc8d7105ad5f0c2c8c28af04e7cc4f4d50b1",
                                                      "9c4b58e33e316ed142eb5dcb41abec3844d3e6e5dc361ffb782c3fa9d175141f"])
        XCTAssertEqual(spec.file.reduce(0) { $0 + $1.byte }, glm.dimensioneByte)
        let heron = try XCTUnwrap(c.voci.first { $0.id == "docling-layout-heron" })
        XCTAssertEqual(heron.motore, .inclusoNellApp)
        let s = RealModelService(catalog: c, store: ModelStore(root: tempDir("modelli")))
        XCTAssertEqual(s.state(of: "docling-layout-heron"), .incluso)
        XCTAssertEqual(s.state(of: "surya-2"), .nonDisponibileQui)
    }

    func test_catalogo_scaricamentoNonValido_rifiutatoInProsa() throws {
        let c = try CatalogLoader.loadBundled()
        var guasti: [ModelCatalog] = []
        for modifica in [
            { (f: inout ModelDownloadFile) in f.indirizzo = f.indirizzo.replacingOccurrences(of: "https", with: "http") },
            { (f: inout ModelDownloadFile) in f.indirizzo = f.indirizzo.replacingOccurrences(of: "huggingface.co", with: "esempio.com") },
            { (f: inout ModelDownloadFile) in f.sha256 = "123" },
            { (f: inout ModelDownloadFile) in f.byte += 1 },
            { (f: inout ModelDownloadFile) in f.nome = "../fuori.gguf" },
        ] {
            var cc = c
            let i = cc.voci.firstIndex { $0.id == "glm-ocr" }!
            modifica(&cc.voci[i].scaricamento!.file[0])
            guasti.append(cc)
        }
        for g in guasti {
            XCTAssertThrowsError(try CatalogLoader.validate(g)) { err in
                XCTAssertTrue((err as! CatalogError).spiegazione.contains("non la scarica"))
            }
        }
    }
}
