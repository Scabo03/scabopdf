//
//  LibraryIdentityTests.swift
//  ScaboCoreTests
//
//  L'impronta del contenuto nella libreria (giro «identità», 2026-10-11): campo additivo e opzionale di
//  `ArchivedDocument` (una libreria di una versione precedente si legge com'è e nulla si perde), le copie
//  volute dello stesso file (stessa impronta, id diversi), il ritorno alla lettura precedente che non
//  tocca l'impronta, e il JSON su disco identico a prima finché l'impronta non c'è.
//

import XCTest
@testable import ScaboCore

final class LibraryIdentityTests: XCTestCase {

    private let shaA = String(repeating: "a1", count: 32)
    private let shaB = String(repeating: "b2", count: 32)

    private func makeStore(persistence: LibraryPersisting = InMemoryLibraryPersistence()) -> LibraryStore {
        var counter = 0
        var seconds: TimeInterval = 0
        return LibraryStore(
            persistence: persistence,
            makeId: { counter += 1; return "id\(counter)" },
            now: { seconds += 1; return Date(timeIntervalSince1970: seconds) })
    }

    // MARK: - Campo additivo: una libreria senza la chiave si legge, l'impronta è nil

    func test_legacyLibraryWithoutFingerprint_decodes_withNilFingerprint_andKeepsAnnotations() throws {
        let legacy = """
        {"documents":[{"bookmarks":[{"anchorSegmentId":"node_3","createdAt":"2026-10-01T10:00:00Z","id":"b1",
        "orderIndexHint":3,"preview":"brezza sulla collina","tagIds":[]}],"id":"doc-vecchio","importedAt":"2026-09-01T10:00:00Z",
        "readingPosition":42,"sourceFileName":"libro.pdf","sourcePageCount":12,"title":"Libro","warnings":[]}],
        "lastOpenDocumentId":null,"workspaces":[]}
        """
        let store = LibraryStore(persistence: InMemoryLibraryPersistence(Data(legacy.utf8)))
        let doc = try XCTUnwrap(store.document(id: "doc-vecchio"))
        XCTAssertNil(doc.sourceSha256, "nessuna impronta finché la migrazione non la calcola")
        XCTAssertEqual(doc.readingPosition, 42)
        XCTAssertEqual(doc.bookmarks?.count, 1)
        XCTAssertEqual(store.documentsWithoutSourceSha256().map { $0.id }, ["doc-vecchio"])
    }

    // MARK: - Registrazione

    func test_setSourceSha256_persists_andIsFoundByFingerprint() {
        let persistence = InMemoryLibraryPersistence()
        let store = makeStore(persistence: persistence)
        let d = store.addDocument(title: "Libro", sourceFileName: "l.pdf", sourcePageCount: 3)
        XCTAssertNil(d.sourceSha256)
        store.setSourceSha256(id: d.id, shaA)
        XCTAssertEqual(store.document(id: d.id)?.sourceSha256, shaA)
        XCTAssertEqual(store.documents(withSourceSha256: shaA).map { $0.id }, [d.id])
        XCTAssertTrue(store.documents(withSourceSha256: shaB).isEmpty)
        XCTAssertTrue(store.documentsWithoutSourceSha256().isEmpty)
        // Round-trip su disco.
        let reloaded = LibraryStore(persistence: persistence)
        XCTAssertEqual(reloaded.document(id: d.id)?.sourceSha256, shaA)
    }

    func test_setSourceSha256_rejectsMalformed_andIgnoresUnknownDocument() {
        let store = makeStore()
        let d = store.addDocument(title: "Libro", sourceFileName: "l.pdf", sourcePageCount: 3)
        store.setSourceSha256(id: d.id, "non-una-impronta")
        XCTAssertNil(store.document(id: d.id)?.sourceSha256)
        store.setSourceSha256(id: "inesistente", shaA)
        XCTAssertTrue(store.documents(withSourceSha256: shaA).isEmpty)
    }

    func test_addDocument_withFingerprint_atImport() {
        let store = makeStore()
        let d = store.addDocument(title: "Libro", sourceFileName: "l.pdf", sourcePageCount: 3, sourceSha256: shaA)
        XCTAssertEqual(d.sourceSha256, shaA)
        XCTAssertEqual(store.documents(withSourceSha256: shaA).count, 1)
    }

    // MARK: - Copie volute: stessa impronta, id diversi, annotazioni separate

    func test_deliberateCopy_sharesFingerprint_keepsSeparateIdsAndAnnotations() {
        let store = makeStore()
        let first = store.addDocument(title: "Libro", sourceFileName: "l.pdf", sourcePageCount: 3, sourceSha256: shaA)
        store.addBookmark(documentId: first.id, anchorSegmentId: "node_1", orderIndexHint: 1, preview: "faro")
        let copy = store.addDocument(title: "Libro", sourceFileName: "l.pdf", sourcePageCount: 3, sourceSha256: shaA)
        XCTAssertNotEqual(first.id, copy.id)
        XCTAssertEqual(store.documents(withSourceSha256: shaA).count, 2)
        XCTAssertEqual(store.bookmarks(documentId: first.id).count, 1)
        XCTAssertEqual(store.bookmarks(documentId: copy.id).count, 0, "la copia parte senza annotazioni")
    }

    func test_documentsWithFingerprint_mostRecentlyOpenedFirst_thenMostRecentlyImported() {
        let store = makeStore()
        let a = store.addDocument(title: "A", sourceFileName: "l.pdf", sourcePageCount: 3, sourceSha256: shaA)
        let b = store.addDocument(title: "B", sourceFileName: "l.pdf", sourcePageCount: 3, sourceSha256: shaA)
        let c = store.addDocument(title: "C", sourceFileName: "l.pdf", sourcePageCount: 3, sourceSha256: shaA)
        XCTAssertEqual(store.documents(withSourceSha256: shaA).map { $0.id }, [c.id, b.id, a.id], "mai aperti → importazione più recente prima")
        store.recordOpened(id: a.id)
        XCTAssertEqual(store.documents(withSourceSha256: shaA).first?.id, a.id, "il più recentemente aperto per primo")
    }

    // MARK: - Il ritorno alla lettura precedente non tocca l'impronta; l'eliminazione la porta via

    func test_restoreSnapshot_keepsFingerprint() throws {
        let store = makeStore()
        let d = store.addDocument(title: "Libro", sourceFileName: "l.pdf", sourcePageCount: 3)
        let snapshot = try XCTUnwrap(store.readingSnapshot(documentId: d.id))
        store.setSourceSha256(id: d.id, shaA)
        store.restore(snapshot, documentId: d.id)
        XCTAssertEqual(store.document(id: d.id)?.sourceSha256, shaA)
    }

    func test_deleteFromArchive_removesTheFingerprintWithTheDocument() {
        let store = makeStore()
        let d = store.addDocument(title: "Libro", sourceFileName: "l.pdf", sourcePageCount: 3, sourceSha256: shaA)
        store.deleteDocumentFromArchive(id: d.id)
        XCTAssertTrue(store.documents(withSourceSha256: shaA).isEmpty)
    }

    // MARK: - JSON su disco: nessuna chiave finché l'impronta non c'è (nessuna riscrittura delle librerie)

    func test_json_hasNoKey_untilFingerprintIsSet() throws {
        let persistence = InMemoryLibraryPersistence()
        let store = makeStore(persistence: persistence)
        let d = store.addDocument(title: "Libro", sourceFileName: "l.pdf", sourcePageCount: 3)
        let before = try XCTUnwrap(persistence.load().flatMap { String(data: $0, encoding: .utf8) })
        XCTAssertFalse(before.contains("sourceSha256"))
        store.setSourceSha256(id: d.id, shaA)
        let after = try XCTUnwrap(persistence.load().flatMap { String(data: $0, encoding: .utf8) })
        XCTAssertTrue(after.contains("\"sourceSha256\":\"\(shaA)\""))
    }
}
