//
//  ScaboMacKitTests.swift
//  ScaboMacKitTests
//
//  Test unitari dello scheletro: catalogo (carico, validazione, cataloghi malformati), stati del servizio
//  simulato, annunci (testo e frequenza), anti-gergo sulle stringhe per l'utente E sul catalogo, verifiche
//  reali economiche (spazio libero, strumenti di sistema), accessibilità strutturale delle viste.
//

import ScaboCore
import XCTest
@testable import ScaboMacKit

final class CatalogoTests: XCTestCase {

    func test_catalogoIncluso_siCaricaEValida() throws {
        let c = try CatalogLoader.loadBundled()
        XCTAssertEqual(c.schemaVersione, ModelCatalog.schemaVersioneCorrente)
        XCTAssertGreaterThanOrEqual(c.voci.count, 9)
        for ruolo in ModelRole.allCases {
            XCTAssertFalse(c.voci(per: ruolo).isEmpty, "ogni ruolo ha almeno una voce: \(ruolo.nome)")
        }
    }

    func test_ogniVoce_portaLeUndiciInformazioni() throws {
        let c = try CatalogLoader.loadBundled()
        for v in c.voci {
            XCTAssertFalse(v.nome.isEmpty); XCTAssertFalse(v.descrizione.isEmpty); XCTAssertFalse(v.licenza.isEmpty)
            XCTAssertFalse(v.dimensioneInParole.isEmpty)
            XCTAssertFalse(v.requisiti.macOSMinimo.isEmpty)
            XCTAssertFalse(v.validazione.descrizione.isEmpty)
            XCTAssertTrue(v.provenienza.indirizzo.hasPrefix("https://"))
            XCTAssertFalse(v.provenienza.versione.isEmpty)
            if v.motore == .sistemaApple { XCTAssertEqual(v.dimensioneByte, 0) } else { XCTAssertGreaterThan(v.dimensioneByte, 0) }
        }
    }

    private func fixture(_ name: String) throws -> URL {
        try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
    }

    func test_catalogoRotto_fallisceInProsa() throws {
        XCTAssertThrowsError(try CatalogLoader.load(from: fixture("catalogo_rotto"))) { e in
            XCTAssertEqual((e as? CatalogError)?.spiegazione, Testi.catalogoMalformato)
        }
    }

    func test_identificativoDoppio_spiegato() throws {
        XCTAssertThrowsError(try CatalogLoader.load(from: fixture("catalogo_id_doppio"))) { e in
            XCTAssertTrue((e as? CatalogError)?.spiegazione.contains("compare due volte") == true)
        }
    }

    func test_provenienzaNonSicura_rifiutata() throws {
        XCTAssertThrowsError(try CatalogLoader.load(from: fixture("catalogo_provenienza"))) { e in
            XCTAssertTrue((e as? CatalogError)?.spiegazione.contains("pagina ufficiale valida") == true)
        }
    }

    func test_versioneSconosciuta_rifiutata() throws {
        XCTAssertThrowsError(try CatalogLoader.load(from: fixture("catalogo_versione"))) { e in
            XCTAssertEqual((e as? CatalogError)?.spiegazione, Testi.catalogoVersioneSconosciuta(99))
        }
    }

    func test_catalogoVuoto_rifiutato() {
        let vuoto = ModelCatalog(schemaVersione: 1, aggiornatoIl: "2026-10-06", voci: [])
        XCTAssertThrowsError(try CatalogLoader.validate(vuoto))
    }

    func test_dimensioniInParole() {
        XCTAssertEqual(ByteWords.describe(0), Testi.dimensioneNessunoSpazio)
        XCTAssertEqual(ByteWords.describe(171_000_000), "circa 171 megabyte")
        XCTAssertEqual(ByteWords.describe(1_471_000_000), "circa 1,5 gigabyte")
        XCTAssertEqual(ByteWords.describe(2_000_000_000), "circa 2 gigabyte")
    }
}

@MainActor
final class StatiServizioTests: XCTestCase {

    private func make() throws -> (SimulatedModelService, CatalogEntry) {
        let c = try CatalogLoader.loadBundled()
        let s = SimulatedModelService(catalog: c)
        s.freeBytesProvider = { 1_000_000_000_000 }  // un terabyte libero
        let e = try XCTUnwrap(c.voci.first { $0.motore == .nativoNellApp })
        return (s, e)
    }

    func test_ilServizioSiDichiaraSimulato() throws {
        let (s, _) = try make()
        XCTAssertTrue(s.isSimulation)
    }

    func test_ciclo_nonScaricato_inScaricamento_scaricato() throws {
        let (s, e) = try make()
        XCTAssertEqual(s.state(of: e.id), .nonScaricato)
        s.download(e.id)
        XCTAssertEqual(s.state(of: e.id), .inScaricamento(percento: 0))
        s.advanceForTesting(e.id, steps: 5)
        XCTAssertEqual(s.state(of: e.id), .inScaricamento(percento: 50))
        s.advanceForTesting(e.id, steps: 5)
        XCTAssertEqual(s.state(of: e.id), .scaricato)
        XCTAssertEqual(s.occupiedBytes, e.dimensioneByte)
    }

    func test_annullamento_torna_a_nonScaricato() throws {
        let (s, e) = try make()
        s.download(e.id); s.advanceForTesting(e.id, steps: 3)
        s.cancelDownload(e.id)
        XCTAssertEqual(s.state(of: e.id), .nonScaricato)
        XCTAssertEqual(s.occupiedBytes, 0)
    }

    func test_rimozione_liberaSpazio() throws {
        let (s, e) = try make()
        s.download(e.id); s.advanceForTesting(e.id, steps: 10)
        s.remove(e.id)
        XCTAssertEqual(s.state(of: e.id), .nonScaricato)
        XCTAssertEqual(s.occupiedBytes, 0)
    }

    func test_spazioInsufficiente_eVerificaReale_conViaDiUscita() throws {
        let (s, e) = try make()
        s.freeBytesProvider = { 10 }
        s.download(e.id)
        guard case .errore(let err) = s.state(of: e.id) else { return XCTFail("atteso errore") }
        XCTAssertTrue(err.spiegazione.contains("Riprova"))
        XCTAssertTrue(err.ammetteRiprova)
        s.freeBytesProvider = { 1_000_000_000_000 }
        s.retry(e.id)
        XCTAssertEqual(s.state(of: e.id), .inScaricamento(percento: 0))
    }

    func test_iSeiGuasti_hannoSpiegazioneInProsa() throws {
        let (_, e) = try make()
        let guasti: [ModelError] = [.spazioInsufficiente(servono: 2_000_000_000, liberi: 500_000_000), .connessioneAssente,
                                    .scaricamentoInterrotto, .fileDanneggiato, .macNonCompatibile(requisiti: e.requisiti),
                                    .strumentoSistemaNonDisponibile]
        for g in guasti {
            XCTAssertGreaterThan(g.spiegazione.count, 40, "spiegazione troppo corta per \(g)")
            XCTAssertNil(Gergo.contieneGergo(g.spiegazione), "gergo in \(g.spiegazione)")
        }
    }

    func test_guastoForzato_eMacNonCompatibile_nonAmmetteRiprova() throws {
        let (s, e) = try make()
        s.forcedFailure[e.id] = .macNonCompatibile(requisiti: e.requisiti)
        s.download(e.id)
        guard case .errore(let err) = s.state(of: e.id) else { return XCTFail("atteso errore") }
        XCTAssertFalse(err.ammetteRiprova)
        s.retry(e.id)
        XCTAssertEqual(s.state(of: e.id), .errore(err), "senza via «Riprova» lo stato non cambia")
    }

    func test_strumentoSistema_verificaRealeIniettabile() throws {
        let c = try CatalogLoader.loadBundled()
        let s = SimulatedModelService(catalog: c)
        let sys = try XCTUnwrap(c.voci.first { $0.motore == .sistemaApple })
        s.systemToolProbe = { _ in false }
        s.download(sys.id)
        XCTAssertEqual(s.state(of: sys.id), .errore(.strumentoSistemaNonDisponibile))
        s.systemToolProbe = { _ in true }
        s.download(sys.id)
        XCTAssertEqual(s.state(of: sys.id), .sistemaDisponibile)
    }
}

@MainActor
final class AnnunciTests: XCTestCase {

    private func make() throws -> (PanelViewModel, SimulatedModelService, RecordingAnnouncer, CatalogEntry) {
        let c = try CatalogLoader.loadBundled()
        let s = SimulatedModelService(catalog: c)
        s.freeBytesProvider = { 1_000_000_000_000 }
        let a = RecordingAnnouncer()
        let m = PanelViewModel(service: s, announcer: a, prefs: InMemoryKeyValueStore())
        let e = try XCTUnwrap(c.voci.first { $0.motore == .nativoNellApp })
        return (m, s, a, e)
    }

    func test_scaricamento_annunciaAvvioSoglieECompletamento_unaVoltaCiascuno() throws {
        let (m, s, a, e) = try make()
        m.scarica(e.id)
        s.advanceForTesting(e.id, steps: 10)
        XCTAssertEqual(a.testi, [
            Testi.annuncioScaricamentoAvviato(e.nome, e.dimensioneInParole),
            Testi.annuncioAvanzamento(e.nome, 25), Testi.annuncioAvanzamento(e.nome, 50), Testi.annuncioAvanzamento(e.nome, 75),
            Testi.annuncioScaricamentoCompletato(e.nome),
        ])
        XCTAssertEqual(a.annunci.last?.priority, .alta)
    }

    func test_avanzamento_nonSommergeLaSintesi() throws {
        let (m, s, a, e) = try make()
        s.stepPercent = 1
        m.scarica(e.id)
        s.advanceForTesting(e.id, steps: 100)
        // 100 passi di avanzamento → solo 5 annunci (avvio, 3 soglie, fine).
        XCTAssertEqual(a.testi.count, 5)
    }

    func test_annullamento_eRimozione_annunciati() throws {
        let (m, s, a, e) = try make()
        m.scarica(e.id); s.advanceForTesting(e.id, steps: 2); m.annulla(e.id)
        XCTAssertEqual(a.testi.last, Testi.annuncioScaricamentoAnnullato(e.nome))
        m.scarica(e.id); s.advanceForTesting(e.id, steps: 10)
        m.chiediRimozione(e.id)
        XCTAssertEqual(m.confermaRimozionePer, e.id)
        m.confermaRimozione()
        XCTAssertEqual(a.testi.last, Testi.annuncioRimosso(e.nome, e.dimensioneInParole))
        XCTAssertEqual(m.state(of: e.id), .nonScaricato)
    }

    func test_problema_annunciatoUnaVolta_conSpiegazione() throws {
        let (m, s, a, e) = try make()
        s.forcedFailure[e.id] = .connessioneAssente
        m.scarica(e.id)
        XCTAssertEqual(a.testi, [Testi.annuncioErrore(e.nome, Testi.erroreConnessioneAssente)])
    }

    func test_focus_restaSullaVoce_dopoOgniCambioDiStato() throws {
        let (m, s, _, e) = try make()
        m.scarica(e.id)
        XCTAssertEqual(m.focusRichiesto, e.id)
        m.focusRichiesto = nil
        s.advanceForTesting(e.id, steps: 10)
        XCTAssertEqual(m.focusRichiesto, e.id)
        m.focusRichiesto = nil
        m.chiediRimozione(e.id); m.annullaRimozione()
        XCTAssertEqual(m.focusRichiesto, e.id)
    }

    func test_azioniPerStato() throws {
        let (m, s, _, e) = try make()
        XCTAssertEqual(m.azioni(per: e), [.scarica])
        m.scarica(e.id); XCTAssertEqual(m.azioni(per: e), [.annulla])
        s.advanceForTesting(e.id, steps: 10); XCTAssertEqual(m.azioni(per: e), [.rimuovi])
        let sys = try XCTUnwrap(m.catalog.voci.first { $0.motore == .sistemaApple })
        XCTAssertEqual(m.azioni(per: sys), [.verificaSistema])
    }

    func test_problemaDiCatalogo_arrivaAlPannello_inProsa() throws {
        let vuoto = ModelCatalog(schemaVersione: 1, aggiornatoIl: "", voci: [])
        let m = PanelViewModel(service: SimulatedModelService(catalog: vuoto), announcer: RecordingAnnouncer(),
                               prefs: InMemoryKeyValueStore(), problemaCatalogo: Testi.catalogoMalformato)
        XCTAssertEqual(m.problemaCatalogo, Testi.catalogoMalformato)
        XCTAssertNil(Gergo.contieneGergo(Testi.catalogoProblemaAvvio(Testi.catalogoMalformato)))
    }

    func test_ruoloAperto_siAggiorna_quandoLUtenteAgisce() throws {
        let (m, _, _, e) = try make()
        XCTAssertNil(m.ruoloAperto)
        m.esegui(.scarica, su: e)
        XCTAssertEqual(m.ruoloAperto, e.ruolo)
    }

    func test_ruoloAperto_ricordatoNellePreferenze() throws {
        let prefs = InMemoryKeyValueStore()
        let c = try CatalogLoader.loadBundled()
        let m = PanelViewModel(service: SimulatedModelService(catalog: c), announcer: RecordingAnnouncer(), prefs: prefs)
        m.ruoloAperto = .ricucitoreSenso
        XCTAssertEqual(prefs.getItem(PanelViewModel.chiaveRuoloAperto), ModelRole.ricucitoreSenso.rawValue)
        let m2 = PanelViewModel(service: SimulatedModelService(catalog: c), announcer: RecordingAnnouncer(), prefs: prefs)
        XCTAssertEqual(m2.ruoloAperto, .ricucitoreSenso)
    }
}

final class GergoTests: XCTestCase {

    func test_stringheFisse_senzaGergo() {
        for s in Testi.tutteLeStringheFisse {
            XCTAssertNil(Gergo.contieneGergo(s), "gergo «\(Gergo.contieneGergo(s) ?? "")» in: \(s)")
        }
    }

    func test_stringheComposte_senzaGergo() {
        let r = ModelRequirements(macOSMinimo: "26.0", richiedeAppleSilicon: true, memoriaConsigliataGB: 16, nota: "Apple Intelligence attiva")
        let p = ModelProvenance(indirizzo: "https://esempio.it", versione: "1", editore: "Esempio")
        let campioni = [
            Testi.statoInScaricamento(50), Testi.statoErrore("x"), Testi.azioneScaricaAiuto("circa 2 gigabyte"),
            Testi.azioneRimuoviDomanda("Nome", "circa 2 gigabyte"), Testi.riassuntoVoce(nome: "N", ruolo: "R", stato: "S", dimensione: "D", provvisoria: true),
            Testi.requisitiInParole(r), Testi.provenienzaInParole(p), Testi.dimensioneGigabyte(1.5), Testi.dimensioneMegabyte(171),
            Testi.spazioLibero("circa 700 gigabyte"), Testi.erroreSpazioInsufficiente("2 gigabyte", "1 gigabyte"), Testi.erroreMacNonCompatibile("macOS 26"),
            Testi.annuncioScaricamentoAvviato("N", "D"), Testi.annuncioAvanzamento("N", 25), Testi.annuncioScaricamentoCompletato("N"),
            Testi.annuncioScaricamentoAnnullato("N"), Testi.annuncioRimosso("N", "D"), Testi.annuncioErrore("N", "S"),
            Testi.annuncioVerificaSistema("N", disponibile: false), Testi.catalogoVersioneSconosciuta(2), Testi.catalogoVoceSenzaIdentificativo("N"),
            Testi.catalogoIdentificativoDoppio("x"), Testi.catalogoVoceSenzaNome("x"), Testi.catalogoVoceSenzaDescrizione("N"), Testi.catalogoVoceSenzaLicenza("N"),
            Testi.catalogoVoceDimensioneNonValida("N"), Testi.catalogoVoceProvenienzaNonValida("N"), Testi.catalogoVoceSenzaVersione("N"), Testi.catalogoProblemaAvvio("S"),
        ]
        for s in campioni { XCTAssertNil(Gergo.contieneGergo(s), "gergo in: \(s)") }
    }

    func test_catalogoIncluso_senzaGergo() throws {
        let c = try CatalogLoader.loadBundled()
        for v in c.voci {
            for s in [v.nome, v.descrizione, v.licenza, v.validazione.descrizione, v.requisiti.nota, v.provenienza.versione, v.provenienza.editore] {
                XCTAssertNil(Gergo.contieneGergo(s), "gergo «\(Gergo.contieneGergo(s) ?? "")» nella voce \(v.id): \(s)")
            }
        }
    }

    func test_ilRilevatore_trovaIlGergo() {
        XCTAssertEqual(Gergo.contieneGergo("Servono 4096 token di contesto"), "token")
        XCTAssertEqual(Gergo.contieneGergo("Modello quantizzato a 4 bit"), "quantizzato")
        XCTAssertEqual(Gergo.contieneGergo("Si è verificato un errore"), "errore")
        XCTAssertNil(Gergo.contieneGergo("Il gigabyte è un'unità; l'abitudine è un'altra cosa"))
    }
}

final class VerificheRealiTests: XCTestCase {

    func test_spazioLibero_leggibileEPositivo() {
        let free = DiskSpace.freeBytes()
        XCTAssertNotNil(free)
        XCTAssertGreaterThan(free ?? 0, 0)
    }

    func test_compatibilitaMac_conIRequisitiDelCatalogo() throws {
        XCTAssertTrue(MacCompatibility.satisfies(ModelRequirements(macOSMinimo: "14.0", richiedeAppleSilicon: false, memoriaConsigliataGB: 0)))
        XCTAssertFalse(MacCompatibility.satisfies(ModelRequirements(macOSMinimo: "99.0", richiedeAppleSilicon: false, memoriaConsigliataGB: 0)))
    }

    func test_strumentiDiSistema_rispondonoSenzaScaricare() {
        // Non si afferma che siano disponibili (dipende dal sistema): si afferma che la verifica risponde.
        _ = AppleSystemTools.visionTextAvailable()
        _ = AppleSystemTools.visionDocumentsAvailable()
        _ = AppleSystemTools.systemLanguageModelAvailable()
        if #available(macOS 26.0, *) {
            XCTAssertTrue(AppleSystemTools.visionDocumentsAvailable(), "su macOS 26+ la struttura dei documenti di Vision c'è")
        }
    }
}
