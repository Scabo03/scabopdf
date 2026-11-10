//
//  LibraryReadingsTests.swift
//  ScaboChainTests
//
//  La logica di libreria condivisa da iPad e Mac (giro «app unica per Mac, tappa A», 2026-11-08): la registrazione dopo
//  un'importazione, la regola della cache all'apertura (volumi enormi; granularità richiesta dal Mac), la scrittura dopo una
//  rielaborazione, le parole e gli annunci della schermata d'elaborazione. Libreria in una cartella temporanea propria,
//  contenuti sintetici: nessun testo dei volumi.
//

import Foundation
import ScaboCore
import XCTest
@testable import ScaboChain

final class LibraryReadingsTests: XCTestCase {

    private var root: URL!
    private var service: LibraryService!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("libreria-prova-\(UUID().uuidString)", isDirectory: true)
        service = LibraryService(rootDirectory: root, prefs: InMemoryKeyValueStore())
    }

    override func tearDownWithError() throws {
        if let root { try? FileManager.default.removeItem(at: root) }
    }

    private func document(pages: Int) -> ScabopdfDocument {
        ScabopdfDocument(
            schema_version: "0.7.0", document_id: "doc_prova",
            metadata: DocumentMetadata(pages_pdf: pages, page_size_pt: [595, 842], source_pdf_filename: "prova.pdf"),
            profile: DocumentProfileDict(profile_id: "generic", editorial_family: "generic", genre: "manuale", confidence: 1),
            structure: [NodeDict(id: "node_1", type: .BODY, page_index: 0, text: "Una frase di prova.")])
    }

    private func content(_ texts: [String]) -> PaginatedContent {
        let segs = texts.enumerated().map { i, t in
            ContentSegment(id: "node_\(i + 1)", role: "BODY", text: t, lengthCategory: "", acousticIntro: "", sourcePage: 1)
        }
        return PaginatedContent(pages: [ContentPage(pageNumber: 1, segments: segs)], totalSegments: segs.count)
    }

    private func sourceFile(_ bytes: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("sorgente-\(UUID().uuidString).pdf")
        try Data(bytes.utf8).write(to: url)
        return url
    }

    func test_registrazione_archivioImprontaCacheGenerazione() throws {
        let src = try sourceFile("contenuto di prova")
        defer { try? FileManager.default.removeItem(at: src) }
        let sha = try DocumentFingerprint.sha256Hex(ofFileAt: src)
        let r = service.registerImported(
            document: document(pages: 3), content: content(["Uno.", "Due."]), doctrineContent: nil,
            sourceName: "Libro di prova.pdf", localCopy: src, isAkn: false, sha256: sha,
            visualResourcesSkipped: nil, destination: nil)
        XCTAssertEqual(r.document.title, "Libro di prova")
        XCTAssertEqual(r.document.sourcePageCount, 3)
        XCTAssertFalse(r.isLarge)
        let stored = try XCTUnwrap(service.store.document(id: r.document.id))
        XCTAssertEqual(stored.sourceSha256, sha)
        XCTAssertNotNil(stored.processedSystemVersion)
        XCTAssertTrue(service.hasArchivedSource(forDocumentId: r.document.id, kind: nil))
        let cached = try XCTUnwrap(service.loadCache(forDocumentId: r.document.id))
        XCTAssertEqual(cached.content.pages.flatMap { $0.segments }.map(\.text), ["Uno.", "Due."])
        XCTAssertEqual(cached.contentTarget, DEFAULT_GRANULARITY_TARGET)
        XCTAssertEqual(service.store.recents().first?.id, r.document.id)
    }

    func test_registrazione_volumeEnorme_nienteCache() throws {
        let src = try sourceFile("volume enorme di prova")
        defer { try? FileManager.default.removeItem(at: src) }
        let r = service.registerImported(
            document: document(pages: ReadingAssembly.largeDocumentPageThreshold + 1), content: content(["Uno."]),
            doctrineContent: nil, sourceName: "Grande.pdf", localCopy: src, isAkn: false, sha256: nil,
            visualResourcesSkipped: nil, destination: nil)
        XCTAssertTrue(r.isLarge)
        XCTAssertNil(r.quickConsultTree)
        XCTAssertFalse(service.hasCache(forDocumentId: r.document.id))
        // Senza impronta data, si calcola sulla copia d'archivio.
        XCTAssertNotNil(service.store.document(id: r.document.id)?.sourceSha256)
    }

    func test_registrazione_akn_senzaPagine() throws {
        let src = try sourceFile("<akomaNtoso/>")
        defer { try? FileManager.default.removeItem(at: src) }
        let r = service.registerImported(
            document: document(pages: 9), content: content(["Art. 1."]), doctrineContent: nil,
            sourceName: "atto.xml", localCopy: src, isAkn: true, sha256: nil, visualResourcesSkipped: nil, destination: nil)
        XCTAssertEqual(r.document.sourcePageCount, 0)
        XCTAssertEqual(r.document.sourceKind, "akn")
        XCTAssertTrue(service.hasArchivedSource(forDocumentId: r.document.id, kind: "akn"))
    }

    func test_cacheApribile_regolaDellIPad_eGranularitaRichiesta() throws {
        let src = try sourceFile("granularità")
        defer { try? FileManager.default.removeItem(at: src) }
        let r = service.registerImported(
            document: document(pages: 2), content: content(["Uno."]), doctrineContent: nil, sourceName: "g.pdf",
            localCopy: src, isAkn: false, sha256: nil, visualResourcesSkipped: nil, destination: nil, contentTarget: 600)
        let doc = try XCTUnwrap(service.store.document(id: r.document.id))
        // La regola dell'iPad (nessuna granularità richiesta): qualunque cache leggibile.
        XCTAssertNotNil(service.openableCachedReading(for: doc))
        // Il Mac chiede la granularità delle Impostazioni: solo la cache costruita a quella.
        XCTAssertNotNil(service.openableCachedReading(for: doc, requiredTarget: 600))
        XCTAssertNil(service.openableCachedReading(for: doc, requiredTarget: 400))
    }

    func test_cacheApribile_volumeEnorme_soloLaLeggera() throws {
        let src = try sourceFile("enorme")
        defer { try? FileManager.default.removeItem(at: src) }
        let big = document(pages: ReadingAssembly.largeDocumentPageThreshold + 10)
        let r = service.registerImported(
            document: big, content: content(["Uno."]), doctrineContent: nil, sourceName: "e.pdf",
            localCopy: src, isAkn: false, sha256: nil, visualResourcesSkipped: nil, destination: nil)
        let doc = try XCTUnwrap(service.store.document(id: r.document.id))
        XCTAssertNil(service.openableCachedReading(for: doc), "all'importazione un volume enorme non va in cache")
        // Una cache pesante (granularità fine) non si usa; quella leggera sì, senza Dottrina né albero.
        service.writeCache(content(["Uno."]), pageMap: [:], doctrineContent: content(["Nota."]), quickConsultTree: nil,
                           contentTarget: DEFAULT_GRANULARITY_TARGET, forDocumentId: doc.id)
        XCTAssertNil(service.openableCachedReading(for: doc))
        let reading = service.storeProcessedReading(
            documentId: doc.id, document: big, content: content(["Uno grande."]), doctrineContent: content(["Nota."]),
            large: true, target: ReadingAssembly.largeDocumentGranularity, visualResourcesSkipped: nil)
        XCTAssertNil(reading.doctrineContent)
        let opened = try XCTUnwrap(service.openableCachedReading(for: doc))
        XCTAssertNil(opened.doctrineContent)
        XCTAssertNil(opened.quickConsultTree)
        XCTAssertEqual(opened.content.pages.flatMap { $0.segments }.map(\.text), ["Uno grande."])
    }

    func test_annunciModerati_faseEDecili() {
        var a = ProcessingAnnouncements()
        XCTAssertEqual(a.announcements(phaseLabel: "Estrazione del testo", percent: 0, fraction: 0), ["Estrazione del testo"])
        XCTAssertEqual(a.announcements(phaseLabel: "Estrazione del testo", percent: 4, fraction: 0.04), ["4 per cento"])
        XCTAssertEqual(a.announcements(phaseLabel: "Estrazione del testo", percent: 7, fraction: 0.07), [])
        XCTAssertEqual(a.announcements(phaseLabel: "Riconoscimento della struttura", percent: 12, fraction: 0.12),
                       ["Riconoscimento della struttura", "12 per cento"])
        XCTAssertEqual(ProcessingWording.statusText(phaseLabel: "Impaginazione", percent: 100), "Impaginazione — 100%")
        XCTAssertEqual(ProcessingWording.percent(ofClampedFraction: ProcessingWording.clampedFraction(1.4)), 100)
    }

    func test_copiaTemporanea_eParoleCondiviseDiApertura() throws {
        let src = try sourceFile("contenuto di prova")
        defer { try? FileManager.default.removeItem(at: src) }
        let copia = try XCTUnwrap(LibraryService.copyIntoTemporary(src, ext: "xml"))
        defer { try? FileManager.default.removeItem(at: copia) }
        XCTAssertTrue(copia.lastPathComponent.hasPrefix("scabo_import_"))
        XCTAssertEqual(copia.pathExtension, "xml")
        XCTAssertEqual(try Data(contentsOf: copia), try Data(contentsOf: src))
        XCTAssertNil(LibraryService.copyIntoTemporary(src.appendingPathExtension("assente")))
        // Le frasi che l'iPad diceva letterali e il Mac ora prende da qui: identiche.
        XCTAssertEqual(LibraryWording.documentNoLongerAvailable, "Il documento non è più disponibile.")
        XCTAssertEqual(LibraryWording.approximatePositionAnnouncement(isAkn: false),
                       "Dopo la rielaborazione il punto in cui eri arrivato non è stato ritrovato con sicurezza: riparti dall'inizio della stessa pagina.")
        XCTAssertEqual(LibraryWording.approximatePositionAnnouncement(isAkn: true),
                       "Dopo la rielaborazione il punto in cui eri arrivato non è stato ritrovato con sicurezza: riparti vicino al punto di prima.")
        XCTAssertEqual([ReadingCommandsWording.noteJump, ReadingCommandsWording.nextHeading, ReadingCommandsWording.previousHeading],
                       ["Nota e richiamo", "Intestazione successiva", "Intestazione precedente"])
    }

    // MARK: La granularità scelta nelle Impostazioni (giro «prove rifatte e granularità», 2026-11-10: una regola sola)

    /// La regola: la scelta per i testi discorsivi, la struttura (il predefinito) per gli atti AKN, la leggera per gli enormi.
    func test_granularitaDiElaborazione_regolaCondivisa() {
        for livello in GranularityLevel.allCases {
            XCTAssertEqual(ReadingAssembly.processingGranularity(chosen: livello.target, isAkn: false, large: false), livello.target)
            XCTAssertEqual(ReadingAssembly.processingGranularity(chosen: livello.target, isAkn: true, large: false),
                           DEFAULT_GRANULARITY_TARGET, "gli atti normativi seguono la loro struttura")
            XCTAssertEqual(ReadingAssembly.processingGranularity(chosen: livello.target, isAkn: false, large: true),
                           ReadingAssembly.largeDocumentGranularity, "i volumi enormi restano leggeri")
            setStoredGranularityLevel(service.prefs, livello)
            XCTAssertEqual(service.processingGranularity(isAkn: false, large: false), livello.target, "dalle Impostazioni")
        }
        XCTAssertEqual(ReadingAssembly.processingGranularity(chosen: 400, isAkn: false, large: false), 400, "il predefinito")
    }

    /// La granularità che la cache deve avere: quella scelta per un PDF; nessuna per un volume enorme e per una lettura
    /// arrivata dal Mac (si adotta così com'è); la struttura per un atto AKN.
    func test_granularitaRichiestaAllaCache() throws {
        setStoredGranularityLevel(service.prefs, .coarse)
        let src = try sourceFile("granularità richiesta")
        defer { try? FileManager.default.removeItem(at: src) }
        let pdf = service.registerImported(
            document: document(pages: 3), content: content(["Uno."]), doctrineContent: nil, sourceName: "A.pdf", localCopy: src,
            isAkn: false, sha256: nil, visualResourcesSkipped: nil, destination: nil, contentTarget: 900).document
        XCTAssertEqual(service.requiredCacheGranularity(for: pdf), GranularityLevel.coarse.target)
        let enorme = service.registerImported(
            document: document(pages: ReadingAssembly.largeDocumentPageThreshold + 1), content: content(["Uno."]),
            doctrineContent: nil, sourceName: "B.pdf", localCopy: src, isAkn: false, sha256: nil,
            visualResourcesSkipped: nil, destination: nil).document
        XCTAssertNil(service.requiredCacheGranularity(for: enorme))
        let akn = service.registerImported(
            document: document(pages: 0), content: content(["Art. 1."]), doctrineContent: nil, sourceName: "C.xml",
            localCopy: src, isAkn: true, sha256: nil, visualResourcesSkipped: nil, destination: nil).document
        XCTAssertEqual(service.requiredCacheGranularity(for: akn), DEFAULT_GRANULARITY_TARGET)
        service.store.recordReceivedReading(id: pdf.id, systemVersion: "27.0", cureLevel: 64, at: Date())
        XCTAssertNil(service.requiredCacheGranularity(for: try XCTUnwrap(service.store.document(id: pdf.id))),
                     "una lettura arrivata dal Mac non si rielabora mai da sé")
    }

    /// Un libro letto a 400 non si apre dalla cache se la scelta è 900 (si rielabora una volta); letto a 900, sì; al
    /// predefinito una cache vecchia senza granularità marcata vale 400 e si apre: nessuna rielaborazione proposta.
    func test_cacheAUnAltraGranularita_siRielaboraUnaVolta() throws {
        let src = try sourceFile("cambio di granularità")
        defer { try? FileManager.default.removeItem(at: src) }
        let doc = service.registerImported(
            document: document(pages: 3), content: content(["Uno.", "Due."]), doctrineContent: nil, sourceName: "D.pdf",
            localCopy: src, isAkn: false, sha256: nil, visualResourcesSkipped: nil, destination: nil).document
        XCTAssertNotNil(service.openableCachedReading(for: doc, requiredTarget: service.requiredCacheGranularity(for: doc)),
                        "al predefinito la cache si apre")
        setStoredGranularityLevel(service.prefs, .coarse)
        XCTAssertNil(service.openableCachedReading(for: doc, requiredTarget: service.requiredCacheGranularity(for: doc)),
                     "a un'altra granularità la cache non basta: si rielabora")
        XCTAssertNotNil(service.openableCachedReading(for: doc, requiredTarget: nil), "ma si legge com'è se manca la sorgente")
        service.storeProcessedReading(documentId: doc.id, document: document(pages: 3), content: content(["Uno. Due."]),
                                      doctrineContent: nil, large: false, target: 900, visualResourcesSkipped: nil)
        XCTAssertNotNil(service.openableCachedReading(for: doc, requiredTarget: service.requiredCacheGranularity(for: doc)),
                        "rielaborato una volta, dalla volta dopo si apre dalla cache")
        setStoredGranularityLevel(service.prefs, .fine)
        XCTAssertNil(service.openableCachedReading(for: doc, requiredTarget: service.requiredCacheGranularity(for: doc)))
        XCTAssertTrue(ReadingSettingsWording.granularityWhenItApplies.contains("prossima apertura"))
    }

    func test_paroleDelLibroGiaPresente() {
        XCTAssertEqual(DuplicateImport.screenTitle, "Libro già presente")
        XCTAssertEqual(DuplicateImport.openExistingTitle, "Apri il libro che hai già")
        XCTAssertEqual(DuplicateImport.importAsCopyTitle, "Importa come copia a parte")
    }
}
