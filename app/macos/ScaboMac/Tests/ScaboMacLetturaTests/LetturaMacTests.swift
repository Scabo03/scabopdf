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
    /// Trattiene l'elaborazione finché non si chiama `rilascia()`: l'app resta occupata (prove della coda).
    var trattieni = false
    private var trattenuta: (() -> Void)?

    func elabora(fileURL: URL, nome: String, granularita: Int, dottrina: Bool, processore: DocumentProcessing,
                 esito: @escaping (DocumentProcessor.Outcome, String?) -> Void) {
        elaborazioni.append((nome, granularita))
        let esegui = { [weak self] in
            processore.process(fileURL: fileURL, sourceName: nome, granularityTarget: granularita, buildDoctrine: dottrina,
                               onProgress: { p in if self?.fasi.last != p.phaseLabel { self?.fasi.append(p.phaseLabel) } },
                               completion: { o in esito(o, (processore as? DocumentProcessor)?.visualResourcesMissingReason) })
        }
        if trattieni { trattenuta = esegui } else { esegui() }
    }
    func rilascia() { let t = trattenuta; trattenuta = nil; t?() }
    func chiediLibroGiaPresente(esistente: ArchivedDocument, copie: Int, scelta: @escaping (SceltaDoppione) -> Void) {
        doppioniChiesti += 1
        scelta(sceltaDoppione)
    }
    func mostraErrore(_ messaggio: String) { errori.append(messaggio); quandoApre?() }
    func apriLettura(documento: ArchivedDocument, lettura: LibraryReading) { aperte.append((documento, lettura)); quandoApre?() }
}

/// Un trascinamento finto: solo la tavola degli appunti conta per la Home.
final class TrascinamentoDiProva: NSObject, NSDraggingInfo {
    let tavola: NSPasteboard
    init(_ tavola: NSPasteboard) { self.tavola = tavola }
    var draggingDestinationWindow: NSWindow? { nil }
    var draggingSourceOperationMask: NSDragOperation { .copy }
    var draggingLocation: NSPoint { .zero }
    var draggedImageLocation: NSPoint { .zero }
    var draggedImage: NSImage? { nil }
    var draggingPasteboard: NSPasteboard { tavola }
    var draggingSource: Any? { nil }
    var draggingSequenceNumber: Int { 1 }
    func slideDraggedImage(to screenPoint: NSPoint) {}
    var draggingFormation: NSDraggingFormation = .default
    var animatesToDestination = false
    var numberOfValidItemsForDrop = 0
    func enumerateDraggingItems(options enumOpts: NSDraggingItemEnumerationOptions = [], for view: NSView?, classes classArray: [AnyClass],
                                searchOptions: [NSPasteboard.ReadingOptionKey: Any] = [:],
                                using block: (NSDraggingItem, Int, UnsafeMutablePointer<ObjCBool>) -> Void) {}
    var springLoadingHighlight: NSSpringLoadingHighlight { .none }
    func resetSpringLoading() {}
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

    /// Un atto AKN col percorso vero: granularità predefinita anche se le Impostazioni dicono altro (DISEGNO § 6.7), sorgente
    /// archiviata come atto, impronta, riapertura dalla cache, «Libro già presente» al secondo arrivo.
    func test_importazione_attoAkn_granularitaPredefinita_libroGiaPresente() async throws {
        // Un atto pubblico già nel repo (le fixture Normattiva della pipeline): nessun testo dei volumi.
        var repo = URL(fileURLWithPath: #filePath)
        for _ in 0..<6 { repo.deleteLastPathComponent() }
        let atto = repo.appendingPathComponent("pipeline/tests/fixtures/normattiva_calibration/legge_56_2007/legge_56_2007.xml")
        guard FileManager.default.fileExists(atPath: atto.path) else { throw XCTSkip("atto di prova assente: \(atto.path)") }
        setStoredGranularityLevel(libreria.prefs, .coarse)
        await aspetta { importazione.importa(atto) }
        XCTAssertEqual(presentatore.errori, [])
        let (doc, lettura) = try XCTUnwrap(presentatore.aperte.first)
        XCTAssertEqual(doc.sourceKind, "akn")
        XCTAssertEqual(presentatore.elaborazioni.first?.granularita, DEFAULT_GRANULARITY_TARGET, "gli atti seguono la loro struttura")
        XCTAssertFalse(lettura.content.pages.flatMap { $0.segments }.isEmpty)
        let s = libreria.service
        XCTAssertTrue(s.hasArchivedSource(forDocumentId: doc.id, kind: "akn"))
        XCTAssertNotNil(s.store.document(id: doc.id)?.sourceSha256)
        XCTAssertEqual(s.loadCache(forDocumentId: doc.id)?.contentTarget ?? DEFAULT_GRANULARITY_TARGET, DEFAULT_GRANULARITY_TARGET)
        await aspetta { importazione.apri(doc.id) }
        XCTAssertEqual(presentatore.elaborazioni.count, 1, "riaperto dalla cache, senza elaborare")
        presentatore.sceltaDoppione = .apriQuelloCheHai
        await aspetta { importazione.importa(atto) }
        XCTAssertEqual(presentatore.doppioniChiesti, 1, "lo stesso atto: «Libro già presente»")
        XCTAssertEqual(libreria.libri().count, 1)
    }

    /// «Annuncia le note a voce» cambiato nelle Impostazioni vale subito nella finestra di lettura aperta. Dal 12 novembre 2026
    /// (LAYER2 § 12.16, decisione 13) senza una scelta le note hanno il segnale, come sull'iPad: la casella è spenta, la parola
    /// d'apertura della nota non c'è e la finestra suona i segnali; accesa, la parola torna.
    func test_impostazioni_noteAVoce_valgonoSubitoNellaFinestraAperta() async throws {
        await aspetta { importazione.importa(pdf) }
        let (doc, lettura) = try XCTUnwrap(presentatore.aperte.first)
        XCTAssertNil(libreria.prefs.getItem(PreferenceKeys.noteSpokenLabels), "precondizione: nessuna scelta fatta")
        let f = FinestraLettura(documento: doc, lettura: lettura, libreria: libreria, voiceOver: false)
        let v = f.vista
        let nota = try XCTUnwrap((0..<v.conteggio).first { v.segmento($0).role == "NOTE" })
        XCTAssertFalse(v.impostazioni.noteSpokenLabels, "senza scelta i segnali delle note, come sull'iPad")
        XCTAssertNotNil(v.suonatore, "la finestra collega sempre i segnali (prima solo con l'interruttore di prova)")
        XCTAssertEqual(v.testoPronunciato(nota),
                       ReadingSpeech.intendedAccessibilityLabel(for: v.segmento(nota), restoreNoteIntro: false))
        // Il cursore arriva sulla nota: il suonatore della finestra riceve il segnale del suo regime.
        let segnaleNota = try XCTUnwrap(ReadingSpeech.noteSignal(for: v.segmento(nota)), "precondizione: una nota col regime")
        var suonati: [[AudioSignal]] = []
        let suonatoreDellaFinestra = v.suonatore
        v.suonatore = { suonati.append($0); suonatoreDellaFinestra?($0) }
        v.elemento(nota).setAccessibilityFocused(true)
        XCTAssertEqual(suonati.last?.first, segnaleNota, "sulla nota il suo segnale")
        let conSegnale = v.testoPronunciato(nota)
        let impostazioni = FinestraImpostazioni(prefs: libreria.prefs)
        XCTAssertNil(libreria.prefs.getItem(PreferenceKeys.noteSpokenLabels), "aprire le Impostazioni non scrive la scelta")
        XCTAssertEqual(impostazioni.note.state, .off, "la casella spenta")
        impostazioni.quandoCambianoLeNote = { f.aggiornaImpostazioni(voiceOver: false) }
        impostazioni.note.state = .on
        impostazioni.cambiaNote(impostazioni.note)
        XCTAssertTrue(PreferenzeLettura.noteAVoce(libreria.prefs))
        XCTAssertTrue(v.impostazioni.noteSpokenLabels)
        XCTAssertEqual(v.testoPronunciato(nota),
                       ReadingSpeech.intendedAccessibilityLabel(for: v.segmento(nota), restoreNoteIntro: true))
        XCTAssertNotEqual(v.testoPronunciato(nota), conSegnale, "con la parola d'apertura della nota")
        f.close()
    }

    /// Chi aveva già scelto non se la vede cambiare (decisione 13): la scelta sta nella chiave dell'iPad e resta com'è, accesa o
    /// spenta; solo l'assenza di una scelta vale ora «spenta».
    func test_noteAVoce_predefinitoSpento_laSceltaFattaResta() {
        let prefs = libreria.prefs
        XCTAssertNil(prefs.getItem(PreferenceKeys.noteSpokenLabels), "precondizione: nessuna scelta fatta")
        XCTAssertFalse(PreferenzeLettura.noteAVoce(prefs), "nessuna scelta: spenta, come sull'iPad")
        PreferenzeLettura.impostaNoteAVoce(prefs, true)
        XCTAssertEqual(prefs.getItem(PreferenceKeys.noteSpokenLabels), "1")
        XCTAssertTrue(PreferenzeLettura.noteAVoce(prefs), "accesa da chi l'aveva scelta: resta accesa")
        PreferenzeLettura.impostaNoteAVoce(prefs, false)
        XCTAssertFalse(PreferenzeLettura.noteAVoce(prefs), "spenta da chi l'aveva scelta: resta spenta")
        XCTAssertEqual(PreferenzeLettura.noteAVoce(prefs), getStoredNoteSpokenLabels(prefs), "la stessa lettura dell'iPad")
    }

    /// Il trascinamento nella Home: accetta solo PDF e atti, e li passa tutti (la coda li importa uno dopo l'altro).
    func test_trascinamento_soloFileImportabili_tutti() throws {
        let tavola = NSPasteboard(name: NSPasteboard.Name("scabo-prova-\(UUID().uuidString)"))
        defer { tavola.releaseGlobally() }
        let cartella = radice.deletingLastPathComponent()
        let a = cartella.appendingPathComponent("a.pdf"), b = cartella.appendingPathComponent("b.xml"), c = cartella.appendingPathComponent("c.txt")
        tavola.clearContents()
        XCTAssertTrue(tavola.writeObjects([a as NSURL, b as NSURL, c as NSURL]))
        let pila = PilaConArrivo()
        var arrivati: [URL] = []
        pila.quandoArrivano = { arrivati = $0 }
        XCTAssertEqual(pila.draggingEntered(TrascinamentoDiProva(tavola)), .copy)
        XCTAssertTrue(pila.performDragOperation(TrascinamentoDiProva(tavola)))
        XCTAssertEqual(arrivati.map(\.lastPathComponent), ["a.pdf", "b.xml"])
        tavola.clearContents()
        XCTAssertTrue(tavola.writeObjects([c as NSURL]))
        XCTAssertEqual(pila.draggingEntered(TrascinamentoDiProva(tavola)), [])
        XCTAssertFalse(pila.performDragOperation(TrascinamentoDiProva(tavola)))
    }

    /// La riapertura all'avvio: dalla cache com'è, anche a un'altra granularità, senza mai rielaborare (regola dell'iPad);
    /// senza una lettura in cache resta sulla Home.
    func test_riaperturaAllAvvio_soloDallaCache_maiRielaborare() async throws {
        await aspetta { importazione.importa(pdf) }
        let doc = try XCTUnwrap(presentatore.aperte.first?.0)
        setStoredGranularityLevel(libreria.prefs, .coarse)
        XCTAssertTrue(importazione.riapriAllAvvio(doc.id))
        XCTAssertEqual(presentatore.aperte.count, 2)
        XCTAssertEqual(presentatore.elaborazioni.count, 1, "nessuna rielaborazione all'avvio")
        try FileManager.default.removeItem(at: libreria.service.cacheURLForTesting(forDocumentId: doc.id))
        XCTAssertFalse(importazione.riapriAllAvvio(doc.id))
        XCTAssertFalse(importazione.riapriAllAvvio("libro-che-non-esiste"))
        XCTAssertEqual(presentatore.elaborazioni.count, 1)
    }

    /// Senza la sorgente d'archivio, una lettura in cache a un'altra granularità si apre (come l'iPad), invece dell'errore.
    func test_senzaSorgente_cacheDiUnAltraGranularita_siApre() async throws {
        await aspetta { importazione.importa(pdf) }
        let doc = try XCTUnwrap(presentatore.aperte.first?.0)
        try FileManager.default.removeItem(at: libreria.service.archivedSourceURL(forDocumentId: doc.id, kind: doc.sourceKind))
        setStoredGranularityLevel(libreria.prefs, .coarse)
        await aspetta { importazione.apri(doc.id) }
        XCTAssertEqual(presentatore.errori, [])
        XCTAssertEqual(presentatore.elaborazioni.count, 1, "senza sorgente non si rielabora")
        XCTAssertEqual(presentatore.aperte.count, 2)
        // Senza sorgente e senza cache: la frase dell'iPad.
        try FileManager.default.removeItem(at: libreria.service.cacheURLForTesting(forDocumentId: doc.id))
        await aspetta { importazione.apri(doc.id) }
        XCTAssertEqual(presentatore.errori, [LibraryWording.sourceMissing])
        await aspetta { importazione.apri("libro-che-non-esiste") }
        XCTAssertEqual(presentatore.errori.last, LibraryWording.documentNoLongerAvailable)
    }

    /// Chiudere una finestra non cancella la riapertura all'avvio di un altro libro; la finestra sostituita dallo stesso
    /// libro riaperto non la tocca; la finestra in primo piano è il libro da riaprire.
    func test_chiusura_riaperturaAllAvvio_soloDelLibroChiuso() async throws {
        await aspetta { importazione.importa(pdf) }
        let (docA, letturaA) = try XCTUnwrap(presentatore.aperte.first)
        presentatore.sceltaDoppione = .importaComeCopia
        await aspetta { importazione.importa(pdf) }
        let (docB, letturaB) = try XCTUnwrap(presentatore.aperte.last)
        XCTAssertNotEqual(docA.id, docB.id)
        let store = libreria.service.store
        let fA = FinestraLettura(documento: docA, lettura: letturaA, libreria: libreria, voiceOver: false)
        let fB = FinestraLettura(documento: docB, lettura: letturaB, libreria: libreria, voiceOver: false)
        let chiude = { (f: FinestraLettura) in f.windowWillClose(Notification(name: NSWindow.willCloseNotification, object: f.window)) }
        fA.windowDidBecomeKey(Notification(name: NSWindow.didBecomeKeyNotification, object: fA.window))
        XCTAssertEqual(store.lastOpenDocumentId, docA.id)
        fB.windowDidBecomeKey(Notification(name: NSWindow.didBecomeKeyNotification, object: fB.window))
        XCTAssertEqual(store.lastOpenDocumentId, docB.id)
        chiude(fA)
        XCTAssertEqual(store.lastOpenDocumentId, docB.id, "chiudere A non tocca B")
        fB.chiusaPerSostituzione = true
        chiude(fB)
        XCTAssertEqual(store.lastOpenDocumentId, docB.id, "la finestra sostituita non cancella la riapertura")
        let fB2 = FinestraLettura(documento: docB, lettura: letturaB, libreria: libreria, voiceOver: false)
        chiude(fB2)
        XCTAssertNil(store.lastOpenDocumentId, "chiudere il libro da riaprire torna alla Home")
    }

    /// Eliminare un libro avvisa prima chi tiene la sua finestra di lettura (l'app la chiude), poi lo toglie.
    func test_eliminazione_avvisaPrimaDiTogliere() async throws {
        await aspetta { importazione.importa(pdf) }
        let doc = try XCTUnwrap(presentatore.aperte.first?.0)
        var avvisati: [String] = []
        var cerano: [Bool] = []
        libreria.quandoElimina.append { [unowned self] id in
            avvisati.append(id)
            cerano.append(self.libreria.service.store.document(id: id) != nil)
        }
        libreria.eliminaDefinitivamente(doc.id)
        XCTAssertEqual(avvisati, [doc.id])
        XCTAssertEqual(cerano, [true], "l'avviso arriva prima che il libro sparisca")
        XCTAssertNil(libreria.service.store.document(id: doc.id))
    }

    /// Mentre un'elaborazione è in corso: un altro file entra in coda e un libro da rielaborare si apre dopo, invece di
    /// cadere nel vuoto.
    func test_occupato_aperturaEImportazioneInCoda() async throws {
        await aspetta { importazione.importa(pdf) }
        let doc = try XCTUnwrap(presentatore.aperte.first?.0)
        setStoredGranularityLevel(libreria.prefs, .coarse)   // la prossima apertura di `doc` rielabora
        presentatore.sceltaDoppione = .importaComeCopia
        presentatore.trattieni = true
        importazione.importa(pdf)                              // una copia a parte, trattenuta: l'app è occupata
        let attesaImpronta = expectation(description: "elaborazione trattenuta")
        for _ in 0..<200 where presentatore.elaborazioni.count < 2 { try await Task.sleep(nanoseconds: 50_000_000) }
        if presentatore.elaborazioni.count == 2 { attesaImpronta.fulfill() }
        await fulfillment(of: [attesaImpronta], timeout: 1)
        XCTAssertTrue(importazione.occupato)
        importazione.apri(doc.id)                              // da rielaborare: aspetta
        importazione.importa(pdf)                              // un altro file: in coda
        XCTAssertEqual(presentatore.elaborazioni.count, 2, "niente parte finché l'elaborazione in corso non finisce")
        let e = expectation(description: "le tre letture")
        e.expectedFulfillmentCount = 3
        presentatore.quandoApre = { e.fulfill() }
        presentatore.trattieni = false
        presentatore.rilascia()
        await fulfillment(of: [e], timeout: 180)
        presentatore.quandoApre = nil
        XCTAssertEqual(presentatore.errori, [])
        XCTAssertEqual(presentatore.elaborazioni.count, 4, "la copia, il libro riaperto a 900, l'altro file")
        XCTAssertTrue(presentatore.aperte.contains { $0.0.id == doc.id && $0.1.content.pages.count > 0 })
        XCTAssertTrue(presentatore.elaborazioni.contains { $0.granularita == 900 })
    }

    /// Il diario delle richieste è spento finché non lo si accende (solo per le prove: `--diario`, i banchi).
    func test_diario_spentoSenzaRichiesta() {
        let v = VistaLettura(segmenti: [], impostazioni: ReadingSpeechSettings())
        XCTAssertFalse(v.diario.attivo)
        v.diario.registra(0, "prova")
        XCTAssertTrue(v.diario.voci.isEmpty)
    }

    /// Dopo una rielaborazione con la posizione ritrovata solo per pagina la finestra lo dice, con le parole dell'iPad.
    func test_posizioneApprossimata_annuncioConLeParoleDelliPad() async throws {
        await aspetta { importazione.importa(pdf) }
        var (doc, lettura) = try XCTUnwrap(presentatore.aperte.first)
        XCTAssertNil(FinestraLettura(documento: doc, lettura: lettura, libreria: libreria, voiceOver: false).annuncioPosizione)
        doc.readingPositionIsApproximate = true
        let f = FinestraLettura(documento: doc, lettura: lettura, libreria: libreria, voiceOver: false)
        XCTAssertEqual(f.annuncioPosizione, LibraryWording.approximatePositionAnnouncement(isAkn: false))
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
        // Dal 12 novembre 2026 (decisione 13) i segnali delle note per impostazione predefinita, come sull'iPad (DISEGNO § 4.2).
        XCTAssertFalse(v.impostazioni.noteSpokenLabels)
        XCTAssertFalse(v.impostazioni.elementToolsAvailable)
        let dallaVista = v.descrizioneDallaVista(libro: "prova", layout: .continuousReading)
        let delModulo = v.descrizioneDelModulo(libro: "prova", layout: .continuousReading)
        XCTAssertTrue(ReadingDescriptionComparison.compare(delModulo, dallaVista).identical)
        XCTAssertEqual(try dallaVista.encoded(), try delModulo.encoded(), "stessi byte")
        // E con «Annuncia le note a voce» accesa (prima del 12 novembre era il predefinito): la vista resta uguale al modulo.
        PreferenzeLettura.impostaNoteAVoce(libreria.prefs, true)
        f.aggiornaImpostazioni(voiceOver: false)
        XCTAssertTrue(v.impostazioni.noteSpokenLabels)
        let dallaVistaVoce = v.descrizioneDallaVista(libro: "prova", layout: .continuousReading)
        let delModuloVoce = v.descrizioneDelModulo(libro: "prova", layout: .continuousReading)
        XCTAssertEqual(try dallaVistaVoce.encoded(), try delModuloVoce.encoded(), "stessi byte anche con le note a voce")
        XCTAssertNotEqual(try dallaVistaVoce.encoded(), try dallaVista.encoded(), "le due impostazioni sono due letture diverse")
        PreferenzeLettura.impostaNoteAVoce(libreria.prefs, false)
        f.aggiornaImpostazioni(voiceOver: false)
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

    /// Le scorciatoie del menu «Lettura» nello stato di VoiceOver acceso (giro «comandi da tastiera e VoiceOver sul Mac»,
    /// 2026-11-11): la voce non ha bersaglio fisso e va al controllore della finestra in primo piano qualunque sia il primo
    /// risponditore (la vista, la vista a scorrimento, la finestra: VoiceOver sposta il fuoco della tastiera col suo cursore), è
    /// sempre attiva, e agisce sull'elemento dove il cursore di VoiceOver è arrivato (VoiceOver gli dà il fuoco a ogni passo,
    /// diario T2). Smentisce l'ipotesi «con VoiceOver la vista non è il primo risponditore e la validazione spegne i comandi».
    func test_menuLettura_qualunquePrimoRisponditore_agisceSullElementoDelCursore() async throws {
        await aspetta { importazione.importa(pdf) }
        let (doc, lettura) = try XCTUnwrap(presentatore.aperte.first)
        let f = FinestraLettura(documento: doc, lettura: lettura, libreria: libreria, voiceOver: true)
        let v = f.vista, w = try XCTUnwrap(f.window)
        let barra = MenuPrincipale.barra(comandi: ComandiFinti())
        let menu = try XCTUnwrap(barra.items.first { $0.submenu?.title == Parole.menuLettura }?.submenu)
        let conScorciatoia = menu.items.filter { !$0.isSeparatorItem && !$0.keyEquivalent.isEmpty }
        XCTAssertEqual(conScorciatoia.count, 3, "⌘J, ⌥⌘↓, ⌥⌘↑")
        for primo in [v as NSResponder, f.scorrimento as NSResponder, nil] {
            w.makeFirstResponder(primo)
            var catena: [NSResponder] = []
            var r: NSResponder? = w.firstResponder
            while let x = r { catena.append(x); r = x.nextResponder }
            XCTAssertTrue(catena.contains(w), "la finestra è nella catena d'azione")
            XCTAssertTrue(w.delegate === f, "dopo la finestra, il suo delegato: il controllore che esegue i comandi")
            for voce in conScorciatoia { XCTAssertNil(voce.target); XCTAssertTrue(f.validateMenuItem(voce), "\(voce.title) attiva") }
        }
        // Il cursore di VoiceOver arriva sul capoverso che richiama una nota e gli dà il fuoco: ⌘J va alla sua nota.
        let richiamo = try XCTUnwrap((0..<v.conteggio).first { v.segmento($0).role != "NOTE" && !v.indiciCollegati($0).isEmpty })
        v.elemento(richiamo).setAccessibilityFocused(true)
        f.saltaNotaRichiamo(nil)
        XCTAssertEqual(v.fuoco, v.indiciCollegati(richiamo).first)
        // Sul primo titolo: ⌥⌘↓ va al titolo seguente di quello dove sta il cursore.
        let titolo = try XCTUnwrap(v.modello.nextHeadingIndex(from: -1, level: nil, forward: true))
        v.elemento(titolo).setAccessibilityFocused(true)
        f.titoloSuccessivo(nil)
        XCTAssertEqual(v.fuoco, v.modello.nextHeadingIndex(from: titolo, level: nil, forward: true))
    }

    func test_menu_vociEScorciatoie_senzaTastoVO() {
        let barra = MenuPrincipale.barra(comandi: ComandiFinti())
        let titoli = barra.items.compactMap { $0.submenu?.title }
        XCTAssertEqual(titoli, [Parole.nomeApp, Parole.menuArchivio, Parole.menuLibro, Parole.menuLettura, Parole.menuFinestra])
        let lettura = try! XCTUnwrap(barra.items.first { $0.submenu?.title == Parole.menuLettura }?.submenu)
        let voci = lettura.items.filter { !$0.isSeparatorItem }
        XCTAssertEqual(voci.map(\.title), MenuPrincipale.vociLettura.map(\.titolo))
        XCTAssertEqual(voci.first?.keyEquivalent, "j")
        // I nomi dei comandi dell'iPad e dell'azione del modulo: le stesse parole sui due prodotti.
        XCTAssertEqual(voci.map(\.title), [ReadingCommandsWording.noteJump, ReadingCommandsWording.nextHeading,
                                            ReadingCommandsWording.previousHeading, ReadingAction.skipVisualResource(target: 0).name])
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
