//
//  LetturaMacTests.swift
//  ScaboMacLetturaTests — la libreria e la lettura dell'app Mac (giro «app unica per Mac, tappa A», 2026-11-08): l'importazione
//  del libro sintetico col percorso vero (impronta, elaborazione con la catena condivisa, registrazione) in una libreria
//  temporanea, «Libro già presente», l'apertura dalla cache e la rielaborazione quando la granularità cambia, l'identità della
//  vista col modulo, le azioni della tappa A, i rotori, il menu, le parole. Contenuti sintetici: nessun testo dei volumi.
//
import AppKit
import ScaboChain
import ScaboCore
import XCTest
@testable import ScaboMacLettura

/// Un presentatore che sceglie da sé e annota (nessuna finestra).
@MainActor
final class PresentatoreDiProva: PresentatoreImportazione {
    var sceltaDoppione: SceltaDoppione = .apriQuelloCheHai
    var doppioniChiesti = 0
    var errori: [String] = []
    var aperte: [(ArchivedDocument, LibraryReading)] = []
    var elaborazioni: [(nome: String, granularita: Int)] = []
    var fasi: [String] = []
    var quandoApre: (() -> Void)?

    func elabora(fileURL: URL, nome: String, granularita: Int, dottrina: Bool, processore: DocumentProcessing,
                 esito: @escaping (DocumentProcessor.Outcome, String?) -> Void) {
        elaborazioni.append((nome, granularita))
        processore.process(fileURL: fileURL, sourceName: nome, granularityTarget: granularita, buildDoctrine: dottrina,
                           onProgress: { [weak self] p in if self?.fasi.last != p.phaseLabel { self?.fasi.append(p.phaseLabel) } },
                           completion: { o in esito(o, (processore as? DocumentProcessor)?.visualResourcesMissingReason) })
    }
    func chiediLibroGiaPresente(esistente: ArchivedDocument, copie: Int, scelta: @escaping (SceltaDoppione) -> Void) {
        doppioniChiesti += 1
        scelta(sceltaDoppione)
    }
    func mostraErrore(_ messaggio: String) { errori.append(messaggio); quandoApre?() }
    func apriLettura(documento: ArchivedDocument, lettura: LibraryReading) { aperte.append((documento, lettura)); quandoApre?() }
}

@MainActor
final class LetturaMacTests: XCTestCase {
    private var radice: URL!
    private var libreria: LibreriaMac!
    private var importazione: ImportazioneMac!
    private var presentatore: PresentatoreDiProva!
    private var pdf: URL!

    override func setUp() async throws {
        radice = FileManager.default.temporaryDirectory.appendingPathComponent("libreria-mac-\(UUID().uuidString)", isDirectory: true)
        libreria = LibreriaMac(service: LibraryService(rootDirectory: radice, prefs: InMemoryKeyValueStore()))
        importazione = ImportazioneMac(libreria: libreria)
        presentatore = PresentatoreDiProva()
        importazione.presentatore = presentatore
        pdf = try LibroSintetico.scrivi(in: radice.deletingLastPathComponent().appendingPathComponent("Libro di prova \(UUID().uuidString).pdf"))
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: radice)
        try? FileManager.default.removeItem(at: pdf)
    }

    /// Importa (o apre) e aspetta la lettura o l'errore.
    private func aspetta(_ azione: () -> Void) async {
        let e = expectation(description: "lettura aperta")
        presentatore.quandoApre = { e.fulfill() }
        azione()
        await fulfillment(of: [e], timeout: 120)
        presentatore.quandoApre = nil
    }

    func test_importazione_percorsoVero_registrazioneECache() async throws {
        await aspetta { importazione.importa(pdf) }
        XCTAssertEqual(presentatore.errori, [])
        let (doc, lettura) = try XCTUnwrap(presentatore.aperte.first)
        XCTAssertTrue(doc.title.hasPrefix("Libro di prova"))
        XCTAssertEqual(presentatore.elaborazioni.first?.granularita, 400)
        XCTAssertEqual(presentatore.fasi.first, ProcessingWording.openingPhaseLabel)
        XCTAssertTrue(presentatore.fasi.contains("Estrazione del testo"))
        let segmenti = lettura.content.pages.flatMap { $0.segments }
        XCTAssertGreaterThanOrEqual(segmenti.count, 12, "titoli, capoversi e note del libro sintetico")
        XCTAssertTrue(segmenti.contains { $0.role == "HEADING_1" })
        let s = libreria.service
        XCTAssertTrue(s.hasArchivedSource(forDocumentId: doc.id, kind: nil))
        XCTAssertNotNil(s.store.document(id: doc.id)?.sourceSha256)
        XCTAssertNotNil(s.loadCache(forDocumentId: doc.id), "la cache nella forma dell'iPad")
        XCTAssertEqual(s.store.document(id: doc.id)?.processedSystemVersion?.hasPrefix("macOS"), true)
        XCTAssertFalse(importazione.occupato)
    }

    func test_libroGiaPresente_apreQuelloCheCe() async throws {
        await aspetta { importazione.importa(pdf) }
        let primo = try XCTUnwrap(presentatore.aperte.first?.0)
        presentatore.sceltaDoppione = .apriQuelloCheHai
        await aspetta { importazione.importa(pdf) }
        XCTAssertEqual(presentatore.doppioniChiesti, 1)
        XCTAssertEqual(presentatore.aperte.last?.0.id, primo.id, "si apre il libro che c'è già")
        XCTAssertEqual(presentatore.elaborazioni.count, 1, "nessuna seconda elaborazione")
        XCTAssertEqual(libreria.libri().count, 1)
        // «Importa come copia a parte»: un secondo libro, stessa impronta.
        presentatore.sceltaDoppione = .importaComeCopia
        await aspetta { importazione.importa(pdf) }
        XCTAssertEqual(libreria.libri().count, 2)
        XCTAssertEqual(Set(libreria.libri().compactMap(\.sourceSha256)).count, 1)
    }

    func test_apertura_dallaCache_eRielaborazioneSeCambiaLaGranularita() async throws {
        await aspetta { importazione.importa(pdf) }
        let doc = try XCTUnwrap(presentatore.aperte.first?.0)
        await aspetta { importazione.apri(doc.id) }
        XCTAssertEqual(presentatore.elaborazioni.count, 1, "riaperto dalla cache, senza elaborare")
        setStoredGranularityLevel(libreria.prefs, .coarse)
        await aspetta { importazione.apri(doc.id) }
        XCTAssertEqual(presentatore.elaborazioni.count, 2, "un'altra granularità: si prepara di nuovo")
        XCTAssertEqual(presentatore.elaborazioni.last?.granularita, 900)
        XCTAssertEqual(libreria.service.loadCache(forDocumentId: doc.id)?.contentTarget, 900)
        await aspetta { importazione.apri(doc.id) }
        XCTAssertEqual(presentatore.elaborazioni.count, 2, "alla granularità nuova si riapre dalla cache")
    }

    func test_fileNonImportabile_prosa() async {
        let altro = radice.deletingLastPathComponent().appendingPathComponent("nota-\(UUID().uuidString).txt")
        try? Data("prova".utf8).write(to: altro)
        defer { try? FileManager.default.removeItem(at: altro) }
        await aspetta { importazione.importa(altro) }
        XCTAssertEqual(presentatore.errori, [LibraryWording.unreadablePickedFile])
    }

    func test_eliminazioneDefinitiva() async throws {
        await aspetta { importazione.importa(pdf) }
        let doc = try XCTUnwrap(presentatore.aperte.first?.0)
        libreria.eliminaDefinitivamente(doc.id)
        XCTAssertTrue(libreria.libri().isEmpty)
        XCTAssertFalse(libreria.service.hasCache(forDocumentId: doc.id))
        XCTAssertFalse(libreria.service.hasArchivedSource(forDocumentId: doc.id, kind: nil))
    }

    func test_finestraDiLettura_vistaUgualeAlModulo_azioniDellaTappaA_posizione() async throws {
        await aspetta { importazione.importa(pdf) }
        let (doc, lettura) = try XCTUnwrap(presentatore.aperte.first)
        let f = FinestraLettura(documento: doc, lettura: lettura, libreria: libreria, voiceOver: false)
        let v = f.vista
        // Note a voce accese per impostazione predefinita sul Mac (DISEGNO § 4.2).
        XCTAssertTrue(v.impostazioni.noteSpokenLabels)
        XCTAssertFalse(v.impostazioni.elementToolsAvailable)
        let dallaVista = v.descrizioneDallaVista(libro: "prova", layout: .continuousReading)
        let delModulo = v.descrizioneDelModulo(libro: "prova", layout: .continuousReading)
        XCTAssertTrue(ReadingDescriptionComparison.compare(delModulo, dallaVista).identical)
        XCTAssertEqual(try dallaVista.encoded(), try delModulo.encoded(), "stessi byte")
        // Nessuna azione delle tappe successive.
        let nomi = Set(dallaVista.elements.flatMap(\.actions))
        XCTAssertTrue(nomi.isDisjoint(with: ["Strumenti elemento", "Aggiungi segnalibro", "Estrai come immagine"]), "\(nomi)")
        // La posizione: il fuoco su un elemento si registra con la sua ancora.
        v.riceviFuoco(3, origine: .tastiera)
        XCTAssertEqual(libreria.service.store.document(id: doc.id)?.readingPosition, 3)
        XCTAssertNotNil(libreria.service.store.document(id: doc.id)?.readingAnchor)
        // Riaperta, la finestra parte da lì.
        let g = FinestraLettura(documento: try XCTUnwrap(libreria.service.store.document(id: doc.id)), lettura: lettura,
                                libreria: libreria, voiceOver: false)
        XCTAssertEqual(g.vista.fuoco, 3)
        // Descrivendosi, la vista non sposta la posizione.
        _ = g.vista.descrizioneDallaVista(libro: "prova", layout: .continuousReading)
        XCTAssertEqual(libreria.service.store.document(id: doc.id)?.readingPosition, 3)
        XCTAssertEqual(g.vista.fuoco, 3)
    }

    func test_comandi_saltoNotaTitoliRotori() async throws {
        await aspetta { importazione.importa(pdf) }
        let (doc, lettura) = try XCTUnwrap(presentatore.aperte.first)
        let v = FinestraLettura(documento: doc, lettura: lettura, libreria: libreria, voiceOver: false).vista
        let rotori = v.rotori().compactMap { v.rotoreDelModulo($0)?.code }
        XCTAssertEqual(rotori, v.modello.installedRotors(searchActive: false).map(\.code))
        XCTAssertTrue(rotori.contains("titoli"))
        v.impostaFuocoIniziale(0)
        XCTAssertTrue(v.titolo(avanti: true))
        let t = try XCTUnwrap(v.fuoco)
        XCTAssertTrue(ReadingSpeech.isHeadingRole(v.segmento(t).role))
        // ⌘J sul titolo, dove non c'è nulla da raggiungere: la frase del modulo, e la lettura non si muove.
        XCTAssertNil(v.modello.noteCallJumpTarget(from: t))
        XCTAssertFalse(v.saltaNotaRichiamo())
        XCTAssertEqual(v.annunci.last, ReadingSpeech.noNoteOrCallToReach)
        XCTAssertEqual(v.fuoco, t)
        // Il capoverso che richiama una nota (il libro sintetico ha un apice vero): ⌘J va alla nota e torna al richiamo.
        let richiamo = try XCTUnwrap((0..<v.conteggio).first { i in v.azioni(i).contains { if case .goToNote = $0 { return true }; return false } })
        v.impostaFuocoIniziale(richiamo)
        XCTAssertTrue(v.saltaNotaRichiamo())
        let nota = try XCTUnwrap(v.fuoco)
        XCTAssertEqual(v.segmento(nota).role, "NOTE")
        XCTAssertTrue(v.azioni(nota).contains(.goToCall(target: richiamo)))
        XCTAssertTrue(v.saltaNotaRichiamo())
        XCTAssertEqual(v.fuoco, richiamo)
    }

    func test_menu_vociEScorciatoie_senzaTastoVO() {
        let barra = MenuPrincipale.barra(comandi: ComandiFinti())
        let titoli = barra.items.compactMap { $0.submenu?.title }
        XCTAssertEqual(titoli, [Parole.nomeApp, Parole.menuArchivio, Parole.menuLibro, Parole.menuLettura, Parole.menuFinestra])
        let lettura = try! XCTUnwrap(barra.items.first { $0.submenu?.title == Parole.menuLettura }?.submenu)
        let voci = lettura.items.filter { !$0.isSeparatorItem }
        XCTAssertEqual(voci.map(\.title), MenuPrincipale.vociLettura.map(\.titolo))
        XCTAssertEqual(voci.first?.keyEquivalent, "j")
        for m in barra.items.compactMap(\.submenu) {
            for i in m.items where !i.isSeparatorItem {
                XCTAssertFalse(i.keyEquivalentModifierMask.contains([.control, .option]), "nessun tasto VO: \(i.title)")
            }
        }
    }

    func test_parole_senzaGergo() {
        let gergo = ["xpc", "json", "cache", "sandbox", "token", "debug", "pipeline", "plugin", "rotor", "segment"]
        for f in Parole.tutteLeFrasiFisse + ReadingSettingsWording.granularityLevels.map(\.1) {
            for g in gergo { XCTAssertFalse(f.lowercased().contains(g), "«\(f)» contiene «\(g)»") }
        }
    }
}

final class ComandiFinti: NSObject, ComandiApp {
    func importaDocumento(_ sender: Any?) {}
    func mostraHome(_ sender: Any?) {}
    func mostraModelliEOfficina(_ sender: Any?) {}
    func mostraImpostazioni(_ sender: Any?) {}
}
