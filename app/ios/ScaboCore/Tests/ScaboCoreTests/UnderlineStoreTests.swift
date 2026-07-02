//
//  UnderlineStoreTests.swift
//  ScaboCoreTests
//
//  Verifica la LOGICA PURA delle sottolineature (§ 6) in memoria, senza Simulator: modello a span
//  per-segmento, mono/multi-parola/multi-blocco (§ 6.2), non-sovrapposizione anche parziale e
//  cross-segmento (§ 6.3), sostituzione in modifica (§ 6.3), eliminazione (§ 6.4), round-trip di
//  persistenza, e retro-compatibilità additiva (una libreria senza la chiave `underlines` non si
//  resetta). La sottolineatura è solo-visiva/solo-vedenti: qui si certifica solo il modello dati.
//

import XCTest
@testable import ScaboCore

final class UnderlineStoreTests: XCTestCase {

    private func makeStore(
        persistence: LibraryPersisting = InMemoryLibraryPersistence()
    ) -> LibraryStore {
        var counter = 0
        var seconds: TimeInterval = 0
        return LibraryStore(
            persistence: persistence,
            makeId: { counter += 1; return "id\(counter)" },
            now: { seconds += 1; return Date(timeIntervalSince1970: seconds) })
    }

    private func addDoc(_ store: LibraryStore, _ title: String = "Doc") -> ArchivedDocument {
        store.addDocument(title: title, sourceFileName: "\(title).pdf", sourcePageCount: 10)
    }

    private func span(_ seg: String, _ a: Int, _ b: Int) -> UnderlineSpan {
        UnderlineSpan(segmentId: seg, startWord: a, endWord: b)
    }

    // MARK: - Creazione: mono / multi-parola / multi-blocco (§ 6.2)

    func test_addUnderline_singleWord() {
        let store = makeStore()
        let doc = addDoc(store)
        let u = store.addUnderline(documentId: doc.id, spans: [span("n1", 3, 3)], preview: "parola")
        XCTAssertNotNil(u)
        XCTAssertEqual(u?.spans, [span("n1", 3, 3)], "una parola sola: intervallo start==end")
    }

    func test_addUnderline_multiWord_andMultiBlock() {
        let store = makeStore()
        let doc = addDoc(store)
        let multi = store.addUnderline(documentId: doc.id, spans: [span("n1", 2, 5)], preview: "x")
        XCTAssertEqual(multi?.spans.count, 1)
        let block = store.addUnderline(
            documentId: doc.id,
            spans: [span("n2", 4, 9), span("n3", 0, 12), span("n4", 0, 1)], preview: "y")
        XCTAssertEqual(block?.segmentIds, ["n2", "n3", "n4"], "estensione su blocchi consecutivi")
    }

    func test_addUnderline_normalizesReversedIndices_andRejectsDegenerate() {
        let store = makeStore()
        let doc = addDoc(store)
        let u = store.addUnderline(documentId: doc.id, spans: [span("n1", 7, 2)], preview: "x")
        XCTAssertEqual(u?.spans, [span("n1", 2, 7)], "indici invertiti → normalizzati")
        XCTAssertNil(store.addUnderline(documentId: doc.id, spans: [], preview: "x"), "span vuoti → nil")
        XCTAssertNil(store.addUnderline(documentId: "ignoto", spans: [span("n1", 0, 0)], preview: "x"))
    }

    // MARK: - Non-sovrapposizione (§ 6.3)

    func test_addUnderline_rejectsOverlap_sameSegment_evenPartial() {
        let store = makeStore()
        let doc = addDoc(store)
        XCTAssertNotNil(store.addUnderline(documentId: doc.id, spans: [span("n1", 2, 5)], preview: "a"))
        // Sovrapposizione parziale (4..7 interseca 2..5 sulla parola 4-5) → rifiutata.
        XCTAssertNil(store.addUnderline(documentId: doc.id, spans: [span("n1", 4, 7)], preview: "b"))
        // Contatto esatto sul bordo (5..8 interseca su 5) → rifiutata (nessuna parola condivisa, § 6.3).
        XCTAssertNil(store.addUnderline(documentId: doc.id, spans: [span("n1", 5, 8)], preview: "c"))
    }

    func test_addUnderline_allowsAdjacentAndDisjoint_inSameSegment() {
        let store = makeStore()
        let doc = addDoc(store)
        XCTAssertNotNil(store.addUnderline(documentId: doc.id, spans: [span("n1", 2, 5)], preview: "a"))
        // 6..9 è adiacente ma non condivide parole → ammessa (§ 6.3: più sottolineature nello
        // stesso blocco purché nessuna parola in comune).
        XCTAssertNotNil(store.addUnderline(documentId: doc.id, spans: [span("n1", 6, 9)], preview: "b"))
        XCTAssertEqual(store.underlines(documentId: doc.id).count, 2)
    }

    func test_addUnderline_rejectsOverlap_onSharedSegment_ofMultiBlock() {
        let store = makeStore()
        let doc = addDoc(store)
        XCTAssertNotNil(store.addUnderline(
            documentId: doc.id, spans: [span("n1", 0, 3), span("n2", 0, 2)], preview: "a"))
        // Nuova su n3 (libero) + n2 (0..1 interseca 0..2) → rifiutata per il segmento condiviso n2.
        XCTAssertNil(store.addUnderline(
            documentId: doc.id, spans: [span("n2", 0, 1), span("n3", 0, 5)], preview: "b"))
        // Nuova su n3 soltanto → ammessa.
        XCTAssertNotNil(store.addUnderline(documentId: doc.id, spans: [span("n3", 0, 5)], preview: "c"))
    }

    // MARK: - Modifica / eliminazione (§ 6.3 / § 6.4)

    func test_replaceUnderline_replacesSpans_allowingSelfOverlap() {
        let store = makeStore()
        let doc = addDoc(store)
        let u = store.addUnderline(documentId: doc.id, spans: [span("n1", 2, 5)], preview: "a")!
        // La nuova selezione si sovrappone alla PROPRIA vecchia posizione: consentito (sostituisce).
        XCTAssertTrue(store.replaceUnderline(documentId: doc.id, underlineId: u.id, spans: [span("n1", 3, 8)]))
        XCTAssertEqual(store.underlines(documentId: doc.id).first?.spans, [span("n1", 3, 8)])
    }

    func test_replaceUnderline_rejectsOverlapWithOthers() {
        let store = makeStore()
        let doc = addDoc(store)
        let a = store.addUnderline(documentId: doc.id, spans: [span("n1", 0, 2)], preview: "a")!
        _ = store.addUnderline(documentId: doc.id, spans: [span("n1", 5, 7)], preview: "b")!
        // Modificare 'a' fino a invadere 'b' (0..6 interseca 5..7) → rifiutata.
        XCTAssertFalse(store.replaceUnderline(documentId: doc.id, underlineId: a.id, spans: [span("n1", 0, 6)]))
        XCTAssertEqual(store.underlines(documentId: doc.id).first(where: { $0.id == a.id })?.spans,
                       [span("n1", 0, 2)], "invariata dopo un replace rifiutato")
    }

    func test_deleteUnderline_removesIt() {
        let store = makeStore()
        let doc = addDoc(store)
        let u = store.addUnderline(documentId: doc.id, spans: [span("n1", 0, 1)], preview: "a")!
        store.deleteUnderline(documentId: doc.id, underlineId: u.id)
        XCTAssertTrue(store.underlines(documentId: doc.id).isEmpty)
    }

    func test_underlinesTouching_filtersBySegment() {
        let store = makeStore()
        let doc = addDoc(store)
        _ = store.addUnderline(documentId: doc.id, spans: [span("n1", 0, 1), span("n2", 0, 3)], preview: "a")
        _ = store.addUnderline(documentId: doc.id, spans: [span("n5", 0, 1)], preview: "b")
        XCTAssertEqual(store.underlinesTouching(documentId: doc.id, segmentId: "n2").count, 1)
        XCTAssertEqual(store.underlinesTouching(documentId: doc.id, segmentId: "n9").count, 0)
    }

    // MARK: - Eliminazione documento porta via le sottolineature

    func test_deleteDocument_removesItsUnderlines() {
        let store = makeStore()
        let doc = addDoc(store)
        _ = store.addUnderline(documentId: doc.id, spans: [span("n1", 0, 1)], preview: "a")
        store.deleteDocumentFromArchive(id: doc.id)
        XCTAssertTrue(store.underlines(documentId: doc.id).isEmpty)
    }

    // MARK: - Retro-compatibilità + round-trip

    func test_decodingOldLibrary_withoutUnderlinesKey_doesNotReset() throws {
        let oldJSON = """
        {"documents":[{"id":"doc1","title":"Vecchio","sourceFileName":"v.pdf",\
        "importedAt":"2024-01-01T00:00:00Z","sourcePageCount":5,"readingPosition":3,"warnings":[]}],\
        "workspaces":[]}
        """
        let persistence = InMemoryLibraryPersistence(Data(oldJSON.utf8))
        let store = makeStore(persistence: persistence)
        XCTAssertEqual(store.allDocuments().count, 1, "la libreria vecchia NON è azzerata")
        XCTAssertEqual(store.document(id: "doc1")?.readingPosition, 3)
        XCTAssertTrue(store.underlines(documentId: "doc1").isEmpty, "chiave assente → nessuna sottolineatura")
    }

    func test_persistenceRoundTrip_preservesUnderlines() {
        let persistence = InMemoryLibraryPersistence()
        let docId: String
        let spans = [span("n2", 1, 4), span("n3", 0, 6)]
        do {
            let store = makeStore(persistence: persistence)
            let doc = addDoc(store)
            docId = doc.id
            _ = store.addUnderline(documentId: doc.id, spans: spans, preview: "estensione multi-blocco")
        }
        let reloaded = makeStore(persistence: persistence)
        let u = reloaded.underlines(documentId: docId).first
        XCTAssertEqual(u?.spans, spans)
        XCTAssertEqual(u?.preview, "estensione multi-blocco")
    }

    // MARK: - Overlap helper puro

    func test_overlapHelper_isSymmetricOnSharedSegment() {
        let store = makeStore()
        let existing = [Underline(id: "u", spans: [span("n1", 3, 6)], preview: "x", createdAt: Date())]
        XCTAssertTrue(store.underlinesOverlap([span("n1", 6, 9)], with: existing), "toccano parola 6")
        XCTAssertFalse(store.underlinesOverlap([span("n1", 7, 9)], with: existing), "7..9 disgiunto da 3..6")
        XCTAssertFalse(store.underlinesOverlap([span("n2", 3, 6)], with: existing), "segmento diverso")
    }
}
