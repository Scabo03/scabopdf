//
//  ReadingFromMacTests.swift
//  ScaboAppTests
//
//  La RICEZIONE della lettura preparata dal Mac (giro «costruzione della linea Mac», 2026-10-16; LAYER2 § 12.12), lato
//  app, senza interfaccia: la cartella delle letture arrivate (cavo, «Apri con», AirDrop), il rifiuto in prosa delle
//  letture che l'iPad scarterebbe, i tre passi dell'adozione (adotta, fondi, registra) con la lettura di prima messa da
//  parte, il ritorno alla lettura precedente, e la prova d'ANDATA E RITORNO delle annotazioni (annotate «sul Mac», fuse
//  sull'iPad, rimandate al Mac nel pacchetto, di nuovo fuse: nessun doppione, nessuna perdita). Testo sintetico.
//

import XCTest
@testable import ScaboApp
import ScaboChain
import ScaboCore

final class ReadingFromMacTests: XCTestCase {

    private var service: LibraryService { .shared }
    private var created: [String] = []
    private var files: [URL] = []

    override func tearDown() {
        for id in created {
            service.deleteFiles(forDocumentId: id)
            service.store.deleteDocumentFromArchive(id: id)
        }
        created = []
        for f in files { try? FileManager.default.removeItem(at: f) }
        files = []
        super.tearDown()
    }

    static let paragraphs = [
        "Il primo paragrafo di prova parla della brezza che scende dalla collina verso il lago al tramonto.",
        "Il secondo paragrafo di prova descrive il faro acceso sulla scogliera e il vento che piega gli ulivi.",
        "Il terzo paragrafo di prova racconta del mulino sul fiume e delle chiuse aperte di notte per il grano.",
        "Il quarto paragrafo di prova chiude con la neve sui tetti e il silenzio della valle sotto la luna.",
    ]

    private func content(_ texts: [String], prefix: String = "node_") -> PaginatedContent {
        let segs = texts.enumerated().map { i, t in
            ContentSegment(id: "\(prefix)\(i)", role: "BODY", text: t, lengthCategory: "", acousticIntro: "", sourcePage: i + 1)
        }
        return PaginatedContent(pages: [ContentPage(pageNumber: 1, segments: segs)], totalSegments: segs.count)
    }

    /// Un libro in libreria con la sua cache (la lettura «di adesso»), elaborato da questa build.
    private func addBook(pages: Int = 4) -> ArchivedDocument {
        let doc = service.store.addDocument(title: "Libro di prova", sourceFileName: "prova.pdf", sourcePageCount: pages)
        created.append(doc.id)
        service.store.setSourceSha256(id: doc.id, String(repeating: "ab", count: 32))
        service.writeCache(content(Self.paragraphs), pageMap: [:], doctrineContent: nil, quickConsultTree: nil,
                           contentTarget: DEFAULT_GRANULARITY_TARGET, forDocumentId: doc.id)
        service.store.recordProcessed(id: doc.id, systemVersion: "iOS 27.0", appBuild: "53")
        return service.store.document(id: doc.id)!
    }

    private func header(pages: Int = 4, target: Int = DEFAULT_GRANULARITY_TARGET, cacheFormat: Int = ReadingAssembly.cacheFormatVersion) -> ReadingPackageHeader {
        let data = try! ReadingPackage.write(
            producer: .init(app: "ScaboPDF per Mac", version: "0.2", build: "2", system: "macOS 27.0.1", cureLevel: ProcessingChain.cureLevel),
            source: .init(sha256: String(repeating: "ab", count: 32), fileName: "prova.pdf", title: "Libro di prova", pageCount: pages),
            reading: PackagedReading(content: content(Self.paragraphs), pageMap: [:], doctrineContent: nil, quickConsultTree: nil, contentTarget: target),
            cacheFormat: cacheFormat, workshop: [], annotations: nil)
        return try! ReadingPackage.readHeader(data).header
    }

    // MARK: - La cartella delle letture arrivate

    func test_cartella_accoglie_daFuori_eRaccoglieDaDocumentiEInbox() throws {
        for u in ReceivedReadings.pending() { ReceivedReadings.remove(u) }
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let ext = ReadingPackageFormat.fileExtension
        // «Apri con» / File: un file fuori dalla cartella si copia dentro.
        let outside = fm.temporaryDirectory.appendingPathComponent("arrivo-\(UUID().uuidString).\(ext)")
        try Data("prova".utf8).write(to: outside); files.append(outside)
        let accepted = try XCTUnwrap(ReceivedReadings.accept(outside))
        files.append(accepted)
        XCTAssertEqual(accepted.deletingLastPathComponent().standardizedFileURL, ReceivedReadings.folder.standardizedFileURL)
        XCTAssertTrue(fm.fileExists(atPath: outside.path), "da File si copia, l'originale resta")
        // Cavo: un file trascinato nella cartella dei documenti; AirDrop: un file in Inbox.
        let cable = docs.appendingPathComponent("cavo-\(UUID().uuidString).\(ext)")
        try Data("cavo".utf8).write(to: cable)
        let inbox = docs.appendingPathComponent("Inbox", isDirectory: true)
        try fm.createDirectory(at: inbox, withIntermediateDirectories: true)
        let air = inbox.appendingPathComponent("airdrop-\(UUID().uuidString).\(ext)")
        try Data("airdrop".utf8).write(to: air)
        let other = docs.appendingPathComponent("non-pacchetto-\(UUID().uuidString).txt")
        try Data("altro".utf8).write(to: other); files.append(other)
        XCTAssertEqual(ReceivedReadings.collectArrivals(), 2, "cavo e AirDrop raccolti, il file d'altro tipo no")
        XCTAssertFalse(fm.fileExists(atPath: cable.path)); XCTAssertFalse(fm.fileExists(atPath: air.path))
        XCTAssertTrue(fm.fileExists(atPath: other.path))
        let pending = ReceivedReadings.pending()
        XCTAssertEqual(pending.count, 3)
        files += pending
        // Stesso nome due volte: il secondo non sovrascrive il primo.
        let again = try XCTUnwrap(ReceivedReadings.accept(outside)); files.append(again)
        XCTAssertNotEqual(again.lastPathComponent, accepted.lastPathComponent)
        for u in ReceivedReadings.pending() { ReceivedReadings.remove(u) }
        XCTAssertTrue(ReceivedReadings.pending().isEmpty)
    }

    // MARK: - Rifiuti in prosa

    func test_volumeEnorme_aGranularitaDiversa_rifiutatoInProsa() {
        XCTAssertNoThrow(try ReadingFromMac.checkLargeVolumeGranularity(header(pages: 4, target: 400)))
        XCTAssertNoThrow(try ReadingFromMac.checkLargeVolumeGranularity(header(pages: 2640, target: ReadingAssembly.largeDocumentGranularity)))
        XCTAssertThrowsError(try ReadingFromMac.checkLargeVolumeGranularity(header(pages: 2640, target: 400))) { e in
            guard case ReadingPackageProblem.largeVolumeGranularity(let f, let x, _) = e else { return XCTFail("\(e)") }
            XCTAssertEqual([f, x], [400, 1200])
            XCTAssertTrue((e as! ReadingPackageProblem).prose.contains("Nella libreria non è stato cambiato nulla"))
        }
    }

    func test_formatoDellaLetturaNonLeggibile_rifiutato() {
        XCTAssertThrowsError(try ReadingPackage.checkCompatibility(header(cacheFormat: 99), readableCacheFormats: ReadingFromMac.readableCacheFormats))
        XCTAssertNoThrow(try ReadingPackage.checkCompatibility(header(), readableCacheFormats: ReadingFromMac.readableCacheFormats))
    }

    // MARK: - Adozione, fusione, ritorno

    func test_adotta_scriveLaLettura_etichetta_mettedaParte_eTornaIndietro() throws {
        let doc = addBook()
        let idx = ContentAnchorIndex(segments: content(Self.paragraphs).pages[0].segments)
        _ = service.store.addBookmark(documentId: doc.id, anchorSegmentId: "node_1", orderIndexHint: 1, name: "Mio", preview: "p",
                                      anchor: idx.anchor(forIndex: 1))
        // La lettura del Mac: un paragrafo in più in testa (gli id dei segmenti cambiano: le ancore ritrovano il punto).
        let macTexts = ["Una premessa che il Mac legge prima del primo paragrafo, scritta per la prova."] + Self.paragraphs
        let reading = PackagedReading(content: content(macTexts, prefix: "m_"), pageMap: ["m_0": 1], doctrineContent: nil,
                                      quickConsultTree: nil, contentTarget: DEFAULT_GRANULARITY_TARGET)
        let when = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertNil(ReadingFromMac.adopt(reading: reading, header: header(), documentId: doc.id, at: when))

        // La cache è la lettura del Mac, così com'è.
        let cached = try XCTUnwrap(service.loadCache(forDocumentId: doc.id))
        XCTAssertEqual(cached.content, reading.content)
        XCTAssertEqual(cached.pageMap, reading.pageMap)
        XCTAssertEqual(cached.contentTarget, reading.contentTarget)
        // L'etichetta: origine Mac, sistema del Mac, livello di cure della catena.
        let after = try XCTUnwrap(service.store.document(id: doc.id))
        XCTAssertEqual(after.readingOrigin, ReadingOrigin.mac)
        XCTAssertEqual(after.processedSystemVersion, "macOS 27.0.1")
        XCTAssertEqual(after.processedAppBuild, String(ProcessingChain.cureLevel))
        XCTAssertEqual(after.processedAt, when)
        XCTAssertTrue(service.hasPreviousReading(forDocumentId: doc.id), "la lettura di prima resta finché non si conferma")
        // Nessuna offerta di cura per una lettura del Mac al livello di cure attuale, neppure su un altro sistema.
        let policy = ReprocessingPolicy(validatedSystemMajors: [26, 27], latestCureBuild: ProcessingChain.cureLevel)
        XCTAssertNil(policy.reason(for: after, currentSystemVersion: "iOS 26.5"))

        // Fusione (niente in arrivo): il segnalibro è ritrovato per contenuto sul segmento giusto della lettura nuova.
        let merged = ReadingFromMac.merge(current: after, incoming: ([], []), segments: reading.content.pages[0].segments)
        ReadingFromMac.commit(merged, documentId: doc.id)
        XCTAssertEqual(service.store.document(id: doc.id)?.bookmarks?.first?.anchorSegmentId, "m_2")

        // Torna alla lettura precedente: cache, etichetta e origine come prima; il segnalibro torna al suo segmento.
        ReprocessOffer.revertToPrevious(doc.id)
        let back = try XCTUnwrap(service.store.document(id: doc.id))
        XCTAssertEqual(try XCTUnwrap(service.loadCache(forDocumentId: doc.id)).content, content(Self.paragraphs))
        XCTAssertNil(back.readingOrigin)
        XCTAssertEqual(back.processedAppBuild, "53")
        XCTAssertEqual(back.processedSystemVersion, "iOS 27.0")
        XCTAssertEqual(back.bookmarks?.first?.anchorSegmentId, "node_1")
        XCTAssertFalse(service.hasPreviousReading(forDocumentId: doc.id))
    }

    func test_libroScomparso_nienteCambia() {
        XCTAssertEqual(ReadingFromMac.adopt(reading: PackagedReading(content: content(["x"]), pageMap: [:], doctrineContent: nil,
                                                                      quickConsultTree: nil, contentTarget: 400),
                                            header: header(), documentId: "non-esiste"), .bookMissing)
    }

    /// LA PROVA NUOVA D'ANDATA E RITORNO DELLE ANNOTAZIONI: annotazioni fatte «sul Mac» arrivano con il pacchetto e si
    /// fondono con quelle dell'iPad; il risultato riparte verso il Mac in un pacchetto nuovo e torna di nuovo sull'iPad.
    /// Alla fine: ogni annotazione d'origine c'è una volta sola (o dentro un'unione, per le sottolineature sovrapposte),
    /// nessuna parola sottolineata si perde, nessuna sta in due sottolineature, i tag arrivano per nome.
    func test_annotazioni_andataERitorno_nessunDoppione_nessunaPerdita() throws {
        let doc = addBook()
        let idx = ContentAnchorIndex(segments: content(Self.paragraphs).pages[0].segments)
        let tagLocal = try XCTUnwrap(service.store.tags().first { $0.name == "Importante" } ?? service.store.createTag(name: "Importante"))
        _ = service.store.addBookmark(documentId: doc.id, anchorSegmentId: "node_1", orderIndexHint: 1, name: "Mio", preview: "p",
                                      tagIds: [tagLocal.id], anchor: idx.anchor(forIndex: 1))
        _ = service.store.addUnderline(documentId: doc.id, spans: [UnderlineSpan(segmentId: "node_2", startWord: 2, endWord: 5,
            anchor: idx.quoteAnchor(forIndex: 2, startWord: 2, endWord: 5))], preview: "p")

        // Andata: dal Mac arrivano un segnalibro sullo stesso punto senza nome (con un tag nuovo), uno nuovo, e una
        // sottolineatura che si sovrappone a quella dell'iPad.
        let macTag = Tag(id: "mac-tag", name: "Dal Mac")
        let incoming = PackagedAnnotations(
            bookmarks: [Bookmark(id: "mb1", anchorSegmentId: "node_1", orderIndexHint: 1, name: nil, preview: "p", tagIds: [macTag.id],
                                 createdAt: Date(), anchor: idx.anchor(forIndex: 1)),
                        Bookmark(id: "mb2", anchorSegmentId: "node_3", orderIndexHint: 3, name: "Sul Mac", preview: "p", tagIds: [],
                                 createdAt: Date(), anchor: idx.anchor(forIndex: 3))],
            underlines: [Underline(id: "mu1", spans: [UnderlineSpan(segmentId: "node_2", startWord: 4, endWord: 9,
                                   anchor: idx.quoteAnchor(forIndex: 2, startWord: 4, endWord: 9))], preview: "p", createdAt: Date())],
            tags: [macTag], readingAnchor: nil)
        func receive(_ ann: PackagedAnnotations) throws -> AnnotationMergeReport {
            let reading = PackagedReading(content: content(Self.paragraphs), pageMap: [:], doctrineContent: nil, quickConsultTree: nil,
                                          contentTarget: DEFAULT_GRANULARITY_TARGET)
            // Il pacchetto passa davvero dal formato (scrittura e lettura), annotazioni comprese.
            let data = try ReadingPackage.write(producer: .init(app: "ScaboPDF per Mac", version: "0.2", build: "2", system: "macOS 27.0.1",
                                                                cureLevel: ProcessingChain.cureLevel),
                                                source: .init(sha256: String(repeating: "ab", count: 32), fileName: "prova.pdf",
                                                              title: "Libro di prova", pageCount: 4),
                                                reading: reading, cacheFormat: ReadingAssembly.cacheFormatVersion, workshop: [], annotations: ann)
            let (h, off) = try ReadingPackage.readHeader(data)
            let body = try ReadingPackage.readBody(data, header: h, payloadOffset: off)
            XCTAssertNil(ReadingFromMac.adopt(reading: body.reading, header: h, documentId: doc.id))
            let current = try XCTUnwrap(service.store.document(id: doc.id))
            let merged = ReadingFromMac.merge(current: current, incoming: ReadingFromMac.mapTags(body.annotations),
                                              segments: body.reading.content.pages[0].segments)
            ReadingFromMac.commit(merged, documentId: doc.id)
            ReprocessOffer.confirmNewReading(doc.id)
            return merged.report
        }
        let first = try receive(incoming)
        XCTAssertEqual(first.bookmarksMerged, 1); XCTAssertEqual(first.bookmarksAdded, 1); XCTAssertEqual(first.underlinesUnited, 1)

        // Ritorno: le annotazioni dell'iPad (già fuse) ripartono verso il Mac e ritornano (come se il Mac le avesse
        // tenute e rimandate): nulla si duplica.
        let now = try XCTUnwrap(service.store.document(id: doc.id))
        let back = PackagedAnnotations(bookmarks: now.bookmarks ?? [], underlines: now.underlines ?? [],
                                       tags: service.store.tags().filter { t in (now.bookmarks ?? []).contains { $0.tagIds.contains(t.id) } },
                                       readingAnchor: nil)
        let second = try receive(back)
        XCTAssertEqual(second.bookmarksAdded + second.underlinesAdded + second.bookmarksOrphan + second.underlinesOrphan, 0, "nessun doppione al ritorno")

        let final = try XCTUnwrap(service.store.document(id: doc.id))
        XCTAssertEqual(final.bookmarks?.count, 2, "il segnalibro dell'iPad (con il tag del Mac) e quello nuovo del Mac")
        let mine = try XCTUnwrap(final.bookmarks?.first { $0.name == "Mio" })
        XCTAssertEqual(Set(mine.tagIds.compactMap { id in service.store.tags().first { $0.id == id }?.name }), ["Importante", "Dal Mac"])
        XCTAssertEqual(final.underlines?.count, 1, "le due sottolineature sovrapposte sono una sola")
        XCTAssertEqual(final.underlines?.first?.spans.map { [$0.startWord, $0.endWord] }, [[2, 9]], "nessuna parola persa: 2…9")
        if let created = service.store.tags().first(where: { $0.name == "Dal Mac" }) { service.store.deleteTag(id: created.id) }
    }
}
