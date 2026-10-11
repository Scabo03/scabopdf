//
//  DocumentIdentityTests.swift
//  ScaboAppTests
//
//  L'identità del documento ricavata dal contenuto, lato app (giro «identità», 2026-10-11): la METÀ
//  SIMULATORE della prova fra piattaforme (stesso file del repo → stessa impronta dell'host macOS e
//  dell'oracolo esterno), la migrazione di una libreria con documenti esistenti (annotazioni comprese,
//  senza perdite; file d'archivio mancante → libro usabile senza impronta; documento AKN), il controllo
//  del libro già presente all'importazione, la schermata «Libro già presente» nell'albero di
//  accessibilità, e la misura del tempo sui file più grandi del corpus (XCTSkip senza corpus).
//  Nessun testo dei volumi: i file di prova sono byte sintetici o atti pubblici di Normattiva.
//

import XCTest
@testable import ScaboApp
import ScaboCore

final class DocumentIdentityTests: XCTestCase {

    /// `shasum -a 256` della fixture pubblica del repo (stessa costante del test host in ScaboCore).
    private static let repoFixtureSha256 = "d33282e4cc5b3c48cd0c214703d3d92c2229abfc37d2684672028743b33d3487"
    private static var repoFixtureURL: URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 { url.deleteLastPathComponent() }  // ScaboAppTests/<file> → ios → app → repo
        return url.appendingPathComponent("pipeline/tests/fixtures/normattiva_calibration/legge_56_2007/legge_56_2007.xml")
    }

    private var service: LibraryService { .shared }
    private var created: [String] = []

    override func tearDown() {
        for id in created {
            service.deleteFiles(forDocumentId: id)
            service.store.deleteDocumentFromArchive(id: id)
        }
        created = []
        super.tearDown()
    }

    /// Byte deterministici (nessun testo): `(i * seed + 7) mod 256`.
    private func pattern(count: Int, seed: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        for i in 0..<count { bytes[i] = UInt8(truncatingIfNeeded: i &* seed &+ 7) }
        return Data(bytes)
    }

    private func tempFile(_ data: Data, ext: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("scabo-id-\(UUID().uuidString).\(ext)")
        try data.write(to: url)
        return url
    }

    /// Un documento d'archivio con la sua sorgente (PDF o XML) scritta nell'archivio, senza impronta.
    @discardableResult
    private func addArchived(title: String, bytes: Data, kind: String? = nil) throws -> ArchivedDocument {
        let doc = service.store.addDocument(title: title, sourceFileName: "\(title).\(kind == "akn" ? "xml" : "pdf")",
                                            sourcePageCount: kind == "akn" ? 0 : 3, sourceKind: kind)
        created.append(doc.id)
        let tmp = try tempFile(bytes, ext: kind == "akn" ? "xml" : "pdf")
        defer { try? FileManager.default.removeItem(at: tmp) }
        try service.storeSource(from: tmp, forDocumentId: doc.id, kind: kind)
        return doc
    }

    // MARK: - Metà simulatore della prova fra piattaforme

    func test_repoFixture_fingerprint_inSimulator_matchesTheHostAndTheExternalOracle() throws {
        let url = Self.repoFixtureURL
        guard FileManager.default.fileExists(atPath: url.path) else { throw XCTSkip("fixture del repo non trovata in \(url.path)") }
        XCTAssertEqual(try DocumentFingerprint.sha256Hex(ofFileAt: url), Self.repoFixtureSha256,
                       "nel simulatore iOS l'impronta deve essere la stessa dell'host macOS (`DocumentFingerprintTests`) e di `shasum -a 256`")
    }

    // MARK: - Migrazione: libreria esistente, annotazioni comprese, senza perdite

    func test_migration_fingerprintsExistingDocuments_keepsAnnotations_skipsMissingFile_coversAkn() throws {
        let pdfBytes = pattern(count: 120_000, seed: 3)
        let xmlBytes = Data("<?xml version=\"1.0\"?><akomaNtoso><act><body><article eId=\"art_1\"><num>Art. 1</num></article></body></act></akomaNtoso>".utf8)
        let book = try addArchived(title: "libro", bytes: pdfBytes)
        let akn = try addArchived(title: "atto", bytes: xmlBytes, kind: "akn")
        let missing = service.store.addDocument(title: "senza-file", sourceFileName: "senza.pdf", sourcePageCount: 2)
        created.append(missing.id)
        // Annotazioni e stato sul libro: devono restare identici.
        let tag = service.store.tags().first ?? service.store.createTag(name: "Prova")!
        service.store.addBookmark(documentId: book.id, anchorSegmentId: "node_2", orderIndexHint: 2, name: "Qui",
                                  preview: "faro sulla scogliera", originalPage: 1, tagIds: [tag.id])
        service.store.addUnderline(documentId: book.id, spans: [UnderlineSpan(segmentId: "node_2", startWord: 1, endWord: 3)], preview: "sulla scogliera")
        service.store.updateReadingPosition(id: book.id, position: 7)
        service.store.recordProcessed(id: book.id, systemVersion: "iOS 27.0", appBuild: "50")
        let before = try XCTUnwrap(service.store.document(id: book.id))
        XCTAssertNil(before.sourceSha256)

        let done = expectation(description: "migrazione")
        var report = DocumentIdentity.MigrationReport()
        DocumentIdentity.fingerprintMissingDocumentsInBackground { r in report = r; done.fulfill() }
        wait(for: [done], timeout: 20)

        XCTAssertEqual(report.skipped, 1, "il libro senza file d'archivio è saltato, non rotto")
        XCTAssertGreaterThanOrEqual(report.computed, 2)
        // Le scritture sul main sono state accodate prima del completamento: le si lascia atterrare.
        let settled = expectation(description: "scritture")
        DispatchQueue.main.async { settled.fulfill() }
        wait(for: [settled], timeout: 5)

        let after = try XCTUnwrap(service.store.document(id: book.id))
        XCTAssertEqual(after.sourceSha256, DocumentFingerprint.sha256Hex(of: pdfBytes), "impronta = SHA-256 dei byte archiviati")
        XCTAssertEqual(service.store.document(id: akn.id)?.sourceSha256, DocumentFingerprint.sha256Hex(of: xmlBytes), "anche l'AKN (XML)")
        XCTAssertNil(service.store.document(id: missing.id)?.sourceSha256, "file mancante → resta senza impronta")
        XCTAssertNotNil(service.store.document(id: missing.id), "…ma il libro c'è ancora")
        // Nulla di perso: il documento è uguale a prima, a parte l'impronta.
        var expected = before
        expected.sourceSha256 = after.sourceSha256
        XCTAssertEqual(after, expected)
        XCTAssertEqual(after.bookmarks?.count, 1)
        XCTAssertEqual(after.underlines?.count, 1)
        XCTAssertEqual(after.readingPosition, 7)
        XCTAssertEqual(after.processedAppBuild, "50")
        // Un secondo giro non calcola nulla di nuovo; il libro senza file viene riprovato (e saltato di nuovo), mai rotto.
        let again = expectation(description: "secondo giro")
        DocumentIdentity.fingerprintMissingDocumentsInBackground { r in
            XCTAssertEqual(r.computed, 0); XCTAssertEqual(r.skipped, 1); again.fulfill()
        }
        wait(for: [again], timeout: 20)
        XCTAssertNotNil(service.store.document(id: missing.id))
    }

    // MARK: - Importazione doppia: riconoscimento, copia a parte

    func test_existingDocuments_recognisesTheSameFile_completesMissingFingerprints_andIgnoresDifferentBytes() throws {
        let bytes = pattern(count: 90_000, seed: 11)
        let book = try addArchived(title: "libro", bytes: bytes)   // senza impronta: la riceve qui
        let same = try tempFile(bytes, ext: "pdf")
        let other = try tempFile(pattern(count: 90_000, seed: 13), ext: "pdf")
        defer { try? FileManager.default.removeItem(at: same); try? FileManager.default.removeItem(at: other) }

        let found = expectation(description: "stesso file")
        DocumentIdentity.existingDocuments(matchingFileAt: same) { sha, matches in
            XCTAssertEqual(sha, DocumentFingerprint.sha256Hex(of: bytes))
            XCTAssertEqual(matches.map { $0.id }, [book.id], "il libro è riconosciuto anche se non aveva ancora l'impronta")
            found.fulfill()
        }
        wait(for: [found], timeout: 20)
        XCTAssertEqual(service.store.document(id: book.id)?.sourceSha256, DocumentFingerprint.sha256Hex(of: bytes))

        let none = expectation(description: "file diverso")
        DocumentIdentity.existingDocuments(matchingFileAt: other) { sha, matches in
            XCTAssertNotNil(sha); XCTAssertTrue(matches.isEmpty); none.fulfill()
        }
        wait(for: [none], timeout: 20)

        // Copia a parte: stessa impronta, id diverso, annotazioni separate; poi il riconoscimento trova due copie.
        let copy = service.store.addDocument(title: "libro (copia)", sourceFileName: "libro.pdf", sourcePageCount: 3,
                                             sourceSha256: DocumentFingerprint.sha256Hex(of: bytes))
        created.append(copy.id)
        service.store.recordOpened(id: copy.id)
        let two = expectation(description: "due copie")
        DocumentIdentity.existingDocuments(matchingFileAt: same) { _, matches in
            XCTAssertEqual(matches.count, 2)
            XCTAssertEqual(matches.first?.id, copy.id, "la copia aperta più di recente viene proposta per prima")
            two.fulfill()
        }
        wait(for: [two], timeout: 20)

        let unreadable = expectation(description: "file illeggibile")
        DocumentIdentity.existingDocuments(matchingFileAt: FileManager.default.temporaryDirectory.appendingPathComponent("non-esiste.pdf")) { sha, matches in
            XCTAssertNil(sha); XCTAssertTrue(matches.isEmpty); unreadable.fulfill()
        }
        wait(for: [unreadable], timeout: 20)
    }

    func test_fingerprintOfArchivedSource_isNil_whenTheFileIsMissing_andNeverThrows() {
        let doc = service.store.addDocument(title: "senza", sourceFileName: "s.pdf", sourcePageCount: 1)
        created.append(doc.id)
        XCTAssertNil(DocumentIdentity.fingerprintOfArchivedSource(doc))
    }

    // MARK: - «Libro già presente»: prosa e albero di accessibilità

    func test_duplicateExplanation_isPlainProse_withDateAndCounts_noCodes() {
        var doc = ArchivedDocument(id: "x", title: "Manuale di prova", sourceFileName: "m.pdf",
                                   importedAt: Date(timeIntervalSince1970: 1_800_000_000), sourcePageCount: 10, sourceSha256: String(repeating: "ab", count: 32))
        let none = DuplicateImport.explanation(existing: doc, copies: 1)
        XCTAssertTrue(none.contains("«Manuale di prova»"))
        XCTAssertTrue(none.contains("non ha ancora segnalibri né sottolineature"))
        XCTAssertTrue(none.contains("copia a parte"))
        XCTAssertFalse(none.contains("abab"), "nessun codice: l'impronta non compare mai")
        XCTAssertFalse(none.lowercased().contains("sha"))
        doc.bookmarks = [Bookmark(id: "b", anchorSegmentId: "n", orderIndexHint: 0, preview: "p", createdAt: Date())]
        doc.underlines = [Underline(id: "u", spans: [], preview: "p", createdAt: Date()),
                          Underline(id: "u2", spans: [], preview: "p", createdAt: Date())]
        let some = DuplicateImport.explanation(existing: doc, copies: 2)
        XCTAssertTrue(some.contains("un segnalibro e 2 sottolineature"))
        XCTAssertTrue(some.contains("2 copie"))
    }

    func test_duplicateScreen_exposesHeadingParagraphAndThreeChoices_defaultIsOpenExisting() {
        let doc = ArchivedDocument(id: "x", title: "Manuale di prova", sourceFileName: "m.pdf", importedAt: Date(), sourcePageCount: 10)
        var chosen: DuplicateImportViewController.Choice?
        let vc = DuplicateImportViewController.makeForTesting(existing: doc, copies: 1) { chosen = $0 }
        vc.loadViewIfNeeded()
        XCTAssertEqual(vc.title, "Libro già presente")
        let labels = vc.stack.arrangedSubviews.compactMap { $0 as? UILabel }
        let buttons = vc.stack.arrangedSubviews.compactMap { $0 as? UIButton }
        XCTAssertEqual(labels.first?.text, "Questo libro è già nella tua libreria")
        XCTAssertTrue(labels.first?.accessibilityTraits.contains(.header) ?? false, "il titolo è un'intestazione")
        XCTAssertEqual(labels.dropFirst().first?.accessibilityIdentifier, "duplicate.text")
        XCTAssertEqual(buttons.map { $0.accessibilityIdentifier }, ["duplicate.open", "duplicate.copy", "duplicate.cancel"])
        XCTAssertEqual(buttons.map { $0.configuration?.title }, ["Apri il libro che hai già", "Importa come copia a parte", "Annulla"])
        XCTAssertEqual(vc.stack.arrangedSubviews.firstIndex(of: buttons[0]).map { $0 > 1 }, true, "prima la spiegazione, poi le scelte")
        for b in buttons {
            XCTAssertTrue(b.constraints.contains { $0.firstAttribute == .height && $0.constant >= 44 }, "bersaglio ≥ 44 pt")
        }
        XCTAssertNil(chosen)
    }

    // MARK: - Tempo sui file più grandi del corpus (XCTSkip senza corpus)

    func test_fingerprintTiming_onTheLargestCorpusVolumes() throws {
        // Il corpus sta FUORI dal repo, nella cartella sorella `scabopdf-triple-take` (mai nel repo); nel simulatore
        // la tilde non è la home del Mac, quindi il percorso si deriva da quello del repo (`#filePath`).
        var repo = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 { repo.deleteLastPathComponent() }
        let corpus = repo.deletingLastPathComponent().appendingPathComponent("scabopdf-triple-take/originals").path
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: corpus) else {
            throw XCTSkip("corpus assente in \(corpus): il tempo si misura solo sul Mac del maintainer")
        }
        let candidates = names.filter { $0.hasPrefix("Codice ") || $0.hasPrefix("EdD") }.filter { $0.hasSuffix(".pdf") }
        guard !candidates.isEmpty else { throw XCTSkip("nessun codice nel corpus") }
        for name in candidates.sorted() {
            let url = URL(fileURLWithPath: corpus).appendingPathComponent(name)
            let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
            let t0 = Date()
            let sha = try DocumentFingerprint.sha256Hex(ofFileAt: url)
            let ms = Date().timeIntervalSince(t0) * 1000
            XCTAssertTrue(DocumentFingerprint.isWellFormed(sha))
            XCTAssertLessThan(ms, 2000, "\(name): \(Int(ms)) ms")
            print("IMPRONTA_TEMPO \(String(format: "%.1f", Double(size) / 1e6)) MB \(String(format: "%.1f", ms)) ms \(name.prefix(24))")
        }
    }
}
