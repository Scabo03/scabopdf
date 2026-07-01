//
//  BookmarkTagStoreTests.swift
//  ScaboCoreTests
//
//  Verifica la LOGICA PURA di segnalibri e tag (§ 5) in memoria, senza Simulator: il modello dati,
//  le associazioni, la semina dei predefiniti, il filtraggio additivo (§ 5.5), la vista globale per
//  tag (§ 5.6), l'eliminazione di un tag che scolla ma non uccide i segnalibri (§ 5.3), la
//  retro-compatibilità additiva della decodifica e il round-trip di persistenza.
//
//  Onestà sulla verifica: qui si certifica SOLO il modello dati. La resa VoiceOver (azioni
//  personalizzate, fraseggio degli annunci, focus dopo apposizione/rimozione) e i limiti di memoria
//  sui volumi enormi NON sono riproducibili dal Simulator: restano al collaudo device (TestFlight).
//

import XCTest
@testable import ScaboCore

final class BookmarkTagStoreTests: XCTestCase {

    /// Store deterministico: id sequenziali `id1, id2, …` e tempo che avanza di un secondo per `now()`.
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

    // MARK: - Semina dei predefiniti (§ 5.2)

    func test_tags_seedsSixDefaults_onFirstAccess_inOrder() {
        let store = makeStore()
        let tags = store.tags()
        XCTAssertEqual(tags.map { $0.name },
                       ["Da rileggere", "Dubbio", "Importante", "Citazione", "Per tesi", "Da verificare"])
    }

    func test_tags_seedingIsIdempotent_andPersisted() {
        let persistence = InMemoryLibraryPersistence()
        let store = makeStore(persistence: persistence)
        let first = store.tags()
        let second = store.tags()
        XCTAssertEqual(first, second, "seconda lettura → stessi tag, nessuna riseminazione")
        // La semina è persistita: un nuovo store sullo stesso disco ritrova gli stessi id.
        let reloaded = makeStore(persistence: persistence)
        XCTAssertEqual(reloaded.tags(), first)
    }

    func test_emptyTagList_isRespected_notReseeded() {
        let store = makeStore()
        for tag in store.tags() { store.deleteTag(id: tag.id) }
        XCTAssertEqual(store.tags(), [], "eliminati tutti → lista vuota, MAI riseminata (§ 5.2)")
    }

    // MARK: - CRUD tag (§ 5.6)

    func test_createTag_appendsAndPersists() {
        let store = makeStore()
        let tag = store.createTag(name: "  responsabilità precontrattuale  ")
        XCTAssertEqual(tag?.name, "responsabilità precontrattuale", "nome ripulito dagli spazi")
        XCTAssertTrue(store.tags().contains { $0.id == tag?.id })
    }

    func test_createTag_rejectsBlankName() {
        let store = makeStore()
        XCTAssertNil(store.createTag(name: "   "))
    }

    func test_renameTag_changesName() {
        let store = makeStore()
        let tag = store.tags()[0]
        store.renameTag(id: tag.id, to: "Da ripassare")
        XCTAssertEqual(store.tag(id: tag.id)?.name, "Da ripassare")
    }

    // MARK: - Eliminazione tag: scolla ma non uccide i segnalibri (§ 5.3)

    func test_deleteTag_stripsAssociation_butKeepsBookmarksAlive() {
        let store = makeStore()
        let doc = addDoc(store)
        let importante = store.tags().first { $0.name == "Importante" }!
        let dubbio = store.tags().first { $0.name == "Dubbio" }!
        // Un segnalibro con due tag, un altro con solo quello che sarà eliminato.
        let a = store.addBookmark(documentId: doc.id, anchorSegmentId: "node_1", orderIndexHint: 3,
                                  preview: "Alfa", tagIds: [importante.id, dubbio.id])!
        let b = store.addBookmark(documentId: doc.id, anchorSegmentId: "node_2", orderIndexHint: 5,
                                  preview: "Beta", tagIds: [importante.id])!

        store.deleteTag(id: importante.id)

        XCTAssertNil(store.tag(id: importante.id), "il tag è sparito definitivamente")
        let bookmarks = store.bookmarks(documentId: doc.id)
        XCTAssertEqual(bookmarks.count, 2, "entrambi i segnalibri restano in vita (§ 5.3)")
        XCTAssertEqual(bookmarks.first { $0.id == a.id }?.tagIds, [dubbio.id],
                       "A perde solo l'associazione col tag eliminato")
        XCTAssertEqual(bookmarks.first { $0.id == b.id }?.tagIds, [],
                       "B resta come segnalibro senza tag")
    }

    // MARK: - CRUD segnalibri (§ 5.7)

    func test_addBookmark_mintsRecord_andReturnsNilForUnknownDocument() {
        let store = makeStore()
        let doc = addDoc(store)
        let tag = store.tags()[0]
        let bm = store.addBookmark(documentId: doc.id, anchorSegmentId: "node_7", orderIndexHint: 2,
                                   name: "  Punto chiave  ", preview: "Prime parole",
                                   originalPage: 42, tagIds: [tag.id])
        XCTAssertEqual(bm?.name, "Punto chiave", "nome ripulito")
        XCTAssertEqual(bm?.originalPage, 42)
        XCTAssertEqual(bm?.tagIds, [tag.id])
        XCTAssertNil(store.addBookmark(documentId: "ignoto", anchorSegmentId: "x", orderIndexHint: 0,
                                       preview: "y"), "documento inesistente → nil")
    }

    func test_addBookmark_dropsUnknownAndDuplicateTagIds() {
        let store = makeStore()
        let doc = addDoc(store)
        let tag = store.tags()[0]
        let bm = store.addBookmark(documentId: doc.id, anchorSegmentId: "node_1", orderIndexHint: 0,
                                   preview: "x", tagIds: [tag.id, "inesistente", tag.id])!
        XCTAssertEqual(bm.tagIds, [tag.id], "tag ignoti scartati, duplicati rimossi")
    }

    func test_bookmark_displayTitle_fallsBackToPreviewWhenNoName() {
        let store = makeStore()
        let doc = addDoc(store)
        let named = store.addBookmark(documentId: doc.id, anchorSegmentId: "a", orderIndexHint: 0,
                                      name: "Titolo", preview: "anteprima")!
        let unnamed = store.addBookmark(documentId: doc.id, anchorSegmentId: "b", orderIndexHint: 1,
                                        preview: "solo anteprima")!
        XCTAssertEqual(named.displayTitle, "Titolo")
        XCTAssertEqual(unnamed.displayTitle, "solo anteprima")
    }

    func test_bookmarks_orderedByOccurrenceInDocument() {
        let store = makeStore()
        let doc = addDoc(store)
        store.addBookmark(documentId: doc.id, anchorSegmentId: "c", orderIndexHint: 9, preview: "ultimo")
        store.addBookmark(documentId: doc.id, anchorSegmentId: "a", orderIndexHint: 1, preview: "primo")
        store.addBookmark(documentId: doc.id, anchorSegmentId: "b", orderIndexHint: 4, preview: "medio")
        XCTAssertEqual(store.bookmarks(documentId: doc.id).map { $0.preview },
                       ["primo", "medio", "ultimo"], "ordinati per posizione nel documento (§ 5.4)")
    }

    func test_updateBookmark_changesNameAndTags() {
        let store = makeStore()
        let doc = addDoc(store)
        let t0 = store.tags()[0], t1 = store.tags()[1]
        let bm = store.addBookmark(documentId: doc.id, anchorSegmentId: "a", orderIndexHint: 0,
                                   preview: "x", tagIds: [t0.id])!
        store.updateBookmark(documentId: doc.id, bookmarkId: bm.id, name: "Nuovo", tagIds: [t1.id])
        let updated = store.bookmarks(documentId: doc.id).first!
        XCTAssertEqual(updated.name, "Nuovo")
        XCTAssertEqual(updated.tagIds, [t1.id])
    }

    func test_deleteBookmark_removesIt() {
        let store = makeStore()
        let doc = addDoc(store)
        let bm = store.addBookmark(documentId: doc.id, anchorSegmentId: "a", orderIndexHint: 0, preview: "x")!
        store.deleteBookmark(documentId: doc.id, bookmarkId: bm.id)
        XCTAssertTrue(store.bookmarks(documentId: doc.id).isEmpty)
    }

    // MARK: - Filtraggio additivo per tag (§ 5.5)

    func test_filterByAnyTag_isLogicalOr_emptySetIsAll() {
        let store = makeStore()
        let doc = addDoc(store)
        let t0 = store.tags()[0], t1 = store.tags()[1], t2 = store.tags()[2]
        store.addBookmark(documentId: doc.id, anchorSegmentId: "a", orderIndexHint: 0, preview: "A", tagIds: [t0.id])
        store.addBookmark(documentId: doc.id, anchorSegmentId: "b", orderIndexHint: 1, preview: "B", tagIds: [t1.id])
        store.addBookmark(documentId: doc.id, anchorSegmentId: "c", orderIndexHint: 2, preview: "C", tagIds: [t2.id])
        store.addBookmark(documentId: doc.id, anchorSegmentId: "d", orderIndexHint: 3, preview: "D", tagIds: [])

        let both = store.bookmarks(documentId: doc.id, filteredByAnyTag: [t0.id, t1.id]).map { $0.preview }
        XCTAssertEqual(both, ["A", "B"], "almeno uno dei tag selezionati (§ 5.5)")

        let none = store.bookmarks(documentId: doc.id, filteredByAnyTag: []).map { $0.preview }
        XCTAssertEqual(none, ["A", "B", "C", "D"], "nessun tag selezionato → lista completa")
    }

    // MARK: - Vista globale per tag su tutta la libreria (§ 5.6)

    func test_bookmarksAcrossLibrary_spansDocuments_filteredByTag() {
        let store = makeStore()
        let saggio = addDoc(store, "Saggio")
        let manuale = addDoc(store, "Manuale")
        let citazione = store.tags().first { $0.name == "Citazione" }!
        let importante = store.tags().first { $0.name == "Importante" }!
        store.addBookmark(documentId: saggio.id, anchorSegmentId: "a", orderIndexHint: 0,
                          preview: "cit nel saggio", tagIds: [citazione.id])
        store.addBookmark(documentId: manuale.id, anchorSegmentId: "b", orderIndexHint: 0,
                          preview: "cit nel manuale", tagIds: [citazione.id])
        store.addBookmark(documentId: manuale.id, anchorSegmentId: "c", orderIndexHint: 1,
                          preview: "solo importante", tagIds: [importante.id])

        let byCitazione = store.bookmarksAcrossLibrary(withAnyTag: [citazione.id])
        XCTAssertEqual(byCitazione.count, 2)
        XCTAssertEqual(byCitazione.map { $0.document.title }, ["Manuale", "Saggio"],
                       "ordinati per titolo documento")
        XCTAssertEqual(store.bookmarksAcrossLibrary(withAnyTag: []).count, 3, "vuoto → tutti")
    }

    // MARK: - Eliminazione documento porta via i suoi segnalibri; i tag globali restano

    func test_deleteDocument_removesItsBookmarks_keepsGlobalTags() {
        let store = makeStore()
        let doc = addDoc(store)
        let tag = store.tags()[0]
        store.addBookmark(documentId: doc.id, anchorSegmentId: "a", orderIndexHint: 0, preview: "x", tagIds: [tag.id])
        store.deleteDocumentFromArchive(id: doc.id)
        XCTAssertTrue(store.bookmarksAcrossLibrary(withAnyTag: []).isEmpty, "segnalibri via col documento")
        XCTAssertTrue(store.tags().contains { $0.id == tag.id }, "i tag globali sopravvivono")
    }

    // MARK: - Retro-compatibilità additiva + round-trip

    func test_decodingOldLibrary_withoutTagsOrBookmarks_doesNotReset() throws {
        // Una libreria di build precedente: un documento SENZA le chiavi `tags`/`bookmarks`.
        let oldJSON = """
        {"documents":[{"id":"doc1","title":"Vecchio","sourceFileName":"v.pdf",\
        "importedAt":"2024-01-01T00:00:00Z","sourcePageCount":5,"readingPosition":7,"warnings":[]}],\
        "workspaces":[]}
        """
        let persistence = InMemoryLibraryPersistence(Data(oldJSON.utf8))
        let store = makeStore(persistence: persistence)
        XCTAssertEqual(store.allDocuments().count, 1, "la libreria vecchia NON è azzerata")
        XCTAssertEqual(store.document(id: "doc1")?.readingPosition, 7, "campi esistenti intatti")
        XCTAssertTrue(store.bookmarks(documentId: "doc1").isEmpty, "nessun segnalibro (chiave assente)")
        XCTAssertEqual(store.tags().count, 6, "i tag si seminano al primo accesso, senza reset")
    }

    func test_persistenceRoundTrip_preservesBookmarksAndTags() {
        let persistence = InMemoryLibraryPersistence()
        let doc: ArchivedDocument
        let bmId: String
        do {
            let store = makeStore(persistence: persistence)
            doc = addDoc(store)
            let personale = store.createTag(name: "Per tesi mia")!
            bmId = store.addBookmark(documentId: doc.id, anchorSegmentId: "node_9", orderIndexHint: 4,
                                     name: "Chiave", preview: "prime parole", originalPage: 3,
                                     tagIds: [personale.id])!.id
        }
        // Nuovo store sullo stesso disco: tutto deve tornare identico.
        let reloaded = makeStore(persistence: persistence)
        let bm = reloaded.bookmarks(documentId: doc.id).first
        XCTAssertEqual(bm?.id, bmId)
        XCTAssertEqual(bm?.name, "Chiave")
        XCTAssertEqual(bm?.anchorSegmentId, "node_9")
        XCTAssertEqual(bm?.originalPage, 3)
        XCTAssertTrue(reloaded.tags().contains { $0.name == "Per tesi mia" })
    }
}
