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

    func test_paroleDelLibroGiaPresente() {
        XCTAssertEqual(DuplicateImport.screenTitle, "Libro già presente")
        XCTAssertEqual(DuplicateImport.openExistingTitle, "Apri il libro che hai già")
        XCTAssertEqual(DuplicateImport.importAsCopyTitle, "Importa come copia a parte")
    }
}
