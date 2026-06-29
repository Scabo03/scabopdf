//
//  LibraryStoreTests.swift
//  ScaboCoreTests
//
//  Verifica la LOGICA della libreria (§ 12) in memoria, senza Simulator: archivio vs collocazioni
//  (§ 12.6), eliminazione su due livelli (§ 12.7), recenti (§ 12.1), posizione di lettura e
//  riapertura nello stato di chiusura (§ 2.5), albero workspace/cartella/sottocartella (§ 12.2),
//  ordinamento (§ 12.3), e round-trip di persistenza JSON.
//

import XCTest
@testable import ScaboCore

final class LibraryStoreTests: XCTestCase {

    /// Store deterministico: id sequenziali, tempo che avanza di un secondo a ogni `now()`.
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

    // MARK: - Archivio

    func test_addDocument_entersArchive_withZeroPositionAndNoOpen() {
        let store = makeStore()
        let doc = store.addDocument(title: "Codice civile", sourceFileName: "cc.pdf", sourcePageCount: 100)
        XCTAssertEqual(store.allDocuments().count, 1)
        XCTAssertEqual(doc.readingPosition, 0)
        XCTAssertNil(doc.lastOpenedAt)
        XCTAssertEqual(store.recents().count, 0, "mai aperto → non è fra i recenti")
    }

    func test_renameDocument_changesTitle() {
        let store = makeStore()
        let doc = store.addDocument(title: "Bozza", sourceFileName: "x.pdf", sourcePageCount: 1)
        store.renameDocument(id: doc.id, to: "Definitivo")
        XCTAssertEqual(store.document(id: doc.id)?.title, "Definitivo")
    }

    // MARK: - Recenti (§ 12.1)

    func test_recents_orderedByMostRecentlyOpened_limited() {
        let store = makeStore()
        let a = store.addDocument(title: "A", sourceFileName: "a.pdf", sourcePageCount: 1)
        let b = store.addDocument(title: "B", sourceFileName: "b.pdf", sourcePageCount: 1)
        let c = store.addDocument(title: "C", sourceFileName: "c.pdf", sourcePageCount: 1)
        store.recordOpened(id: a.id)   // t cresce
        store.recordOpened(id: b.id)
        store.recordOpened(id: c.id)
        store.recordOpened(id: a.id)   // A riaperto per ultimo

        let recents = store.recents(limit: 5).map { $0.id }
        XCTAssertEqual(recents, [a.id, c.id, b.id], "il più recente in cima")
    }

    func test_recents_respectsLimit() {
        let store = makeStore()
        for i in 0..<8 {
            let d = store.addDocument(title: "D\(i)", sourceFileName: "d.pdf", sourcePageCount: 1)
            store.recordOpened(id: d.id)
        }
        XCTAssertEqual(store.recents(limit: 5).count, 5)
    }

    // MARK: - Posizione di lettura e riapertura (§ 2.5)

    func test_readingPosition_persistsAndClampsNegative() {
        let store = makeStore()
        let d = store.addDocument(title: "D", sourceFileName: "d.pdf", sourcePageCount: 1)
        store.updateReadingPosition(id: d.id, position: 42)
        XCTAssertEqual(store.document(id: d.id)?.readingPosition, 42)
        store.updateReadingPosition(id: d.id, position: -3)
        XCTAssertEqual(store.document(id: d.id)?.readingPosition, 0, "le posizioni negative collassano a 0")
    }

    func test_recordOpened_marksLastOpenDocument_clearedToHome() {
        let store = makeStore()
        let d = store.addDocument(title: "D", sourceFileName: "d.pdf", sourcePageCount: 1)
        store.recordOpened(id: d.id)
        XCTAssertEqual(store.lastOpenDocumentId, d.id)
        store.setLastOpenDocument(id: nil)   // utente torna alla Home
        XCTAssertNil(store.lastOpenDocumentId)
    }

    // MARK: - Rimuovi dai recenti (sola lista, non distruttivo)

    func test_removeFromRecents_isListOnly_keepsArchiveCollocationsAndPosition() {
        let store = makeStore()
        let d = store.addDocument(title: "D", sourceFileName: "d.pdf", sourcePageCount: 9)
        let ws = store.createWorkspace(name: "W")
        store.addCollocation(documentId: d.id, to: .workspace(ws.id))
        store.updateReadingPosition(id: d.id, position: 33)
        store.recordOpened(id: d.id)
        XCTAssertEqual(store.recents().map { $0.id }, [d.id])

        store.removeFromRecents(id: d.id)
        XCTAssertEqual(store.recents().count, 0, "tolto dalla sezione Recenti")
        XCTAssertNotNil(store.document(id: d.id), "il file resta nell'archivio")
        XCTAssertEqual(store.fileIds(in: .workspace(ws.id)), [d.id], "la collocazione resta intatta")
        XCTAssertEqual(store.document(id: d.id)?.readingPosition, 33, "la posizione di lettura resta")

        // Riaprendolo dall'archivio torna fra i recenti, e la posizione è ancora quella.
        store.recordOpened(id: d.id)
        XCTAssertEqual(store.recents().map { $0.id }, [d.id], "riaperto: di nuovo recente")
        XCTAssertEqual(store.document(id: d.id)?.readingPosition, 33)
    }

    func test_archivedDocument_decodesWithoutHiddenFlag_backwardCompatible() {
        // Una libreria salvata PRIMA dell'aggiunta del flag non ha la chiave: deve decodificare.
        let json = Data("""
        {"id":"x","title":"T","sourceFileName":"x.pdf","importedAt":"2026-01-01T00:00:00Z",\
        "sourcePageCount":3,"readingPosition":7,"warnings":[]}
        """.utf8)
        let doc = try? JSONDecoder.library.decode(ArchivedDocument.self, from: json)
        XCTAssertNotNil(doc, "la decodifica non deve fallire per la chiave mancante")
        XCTAssertEqual(doc?.readingPosition, 7)
        XCTAssertNil(doc?.isHiddenFromRecents, "chiave assente → nil (= visibile nei recenti)")
    }

    // MARK: - Archivio vs collocazioni (§ 12.6)

    func test_addCollocation_doesNotDuplicateInSamePlace() {
        let store = makeStore()
        let d = store.addDocument(title: "D", sourceFileName: "d.pdf", sourcePageCount: 1)
        let ws = store.createWorkspace(name: "Tesi")
        let ref = ContainerRef.workspace(ws.id)
        store.addCollocation(documentId: d.id, to: ref)
        store.addCollocation(documentId: d.id, to: ref)
        XCTAssertEqual(store.fileIds(in: ref), [d.id], "stessa presenza nello stesso posto non duplica")
    }

    func test_addCollocation_inTwoPlaces_isReachableFromBoth() {
        let store = makeStore()
        let d = store.addDocument(title: "D", sourceFileName: "d.pdf", sourcePageCount: 1)
        let ws = store.createWorkspace(name: "Tesi")
        let folder = store.createFolder(inWorkspace: ws.id, name: "Cartella")!
        let r1 = ContainerRef.workspace(ws.id)
        let r2 = ContainerRef.folder(workspace: ws.id, folder: folder.id)
        store.addCollocation(documentId: d.id, to: r1)
        store.addCollocation(documentId: d.id, to: r2)
        XCTAssertEqual(store.fileIds(in: r1), [d.id])
        XCTAssertEqual(store.fileIds(in: r2), [d.id])
    }

    func test_moveCollocation_movesWithoutDuplicating() {
        let store = makeStore()
        let d = store.addDocument(title: "D", sourceFileName: "d.pdf", sourcePageCount: 1)
        let ws = store.createWorkspace(name: "W")
        let folder = store.createFolder(inWorkspace: ws.id, name: "F")!
        let r1 = ContainerRef.workspace(ws.id)
        let r2 = ContainerRef.folder(workspace: ws.id, folder: folder.id)
        store.addCollocation(documentId: d.id, to: r1)
        store.moveCollocation(documentId: d.id, from: r1, to: r2)
        XCTAssertEqual(store.fileIds(in: r1), [], "Sposta rimuove dalla sorgente")
        XCTAssertEqual(store.fileIds(in: r2), [d.id], "Sposta colloca a destinazione")
    }

    func test_uncollocated_listsArchiveDocsWithNoPlacement() {
        let store = makeStore()
        let a = store.addDocument(title: "A", sourceFileName: "a.pdf", sourcePageCount: 1)
        let b = store.addDocument(title: "B", sourceFileName: "b.pdf", sourcePageCount: 1)
        let ws = store.createWorkspace(name: "W")
        store.addCollocation(documentId: a.id, to: .workspace(ws.id))
        let uncollocated = store.uncollocatedDocuments().map { $0.id }
        XCTAssertEqual(uncollocated, [b.id])
    }

    // MARK: - Eliminazione su due livelli (§ 12.7)

    func test_removeCollocation_keepsFileInArchive() {
        let store = makeStore()
        let d = store.addDocument(title: "D", sourceFileName: "d.pdf", sourcePageCount: 1)
        let ws = store.createWorkspace(name: "W")
        let ref = ContainerRef.workspace(ws.id)
        store.addCollocation(documentId: d.id, to: ref)
        store.removeCollocation(documentId: d.id, from: ref)
        XCTAssertEqual(store.fileIds(in: ref), [])
        XCTAssertNotNil(store.document(id: d.id), "il file resta nell'archivio dopo aver tolto la collocazione")
    }

    func test_deleteWorkspace_keepsFilesInArchive() {
        let store = makeStore()
        let d = store.addDocument(title: "D", sourceFileName: "d.pdf", sourcePageCount: 1)
        let ws = store.createWorkspace(name: "W")
        store.addCollocation(documentId: d.id, to: .workspace(ws.id))
        store.deleteWorkspace(id: ws.id)
        XCTAssertEqual(store.state.workspaces.count, 0)
        XCTAssertNotNil(store.document(id: d.id), "eliminare un workspace non distrugge i file")
    }

    func test_deleteFromArchive_removesDocAndAllCollocations() {
        let store = makeStore()
        let d = store.addDocument(title: "D", sourceFileName: "d.pdf", sourcePageCount: 1)
        let ws = store.createWorkspace(name: "W")
        let folder = store.createFolder(inWorkspace: ws.id, name: "F")!
        store.addCollocation(documentId: d.id, to: .workspace(ws.id))
        store.addCollocation(documentId: d.id, to: .folder(workspace: ws.id, folder: folder.id))
        store.recordOpened(id: d.id)
        store.deleteDocumentFromArchive(id: d.id)
        XCTAssertNil(store.document(id: d.id))
        XCTAssertEqual(store.fileIds(in: .workspace(ws.id)), [])
        XCTAssertEqual(store.fileIds(in: .folder(workspace: ws.id, folder: folder.id)), [])
        XCTAssertNil(store.lastOpenDocumentId, "eliminato dall'archivio: non è più l'ultimo aperto")
    }

    // MARK: - Albero a tre livelli (§ 12.2)

    func test_threeLevelTree_navigation() {
        let store = makeStore()
        let ws = store.createWorkspace(name: "W")
        let folder = store.createFolder(inWorkspace: ws.id, name: "F")!
        let sub = store.createSubfolder(inWorkspace: ws.id, folderId: folder.id, name: "S")!
        XCTAssertEqual(store.folders(inWorkspace: ws.id).map { $0.id }, [folder.id])
        XCTAssertEqual(store.subfolders(inWorkspace: ws.id, folderId: folder.id).map { $0.id }, [sub.id])

        let d = store.addDocument(title: "D", sourceFileName: "d.pdf", sourcePageCount: 1)
        let ref = ContainerRef.subfolder(workspace: ws.id, folder: folder.id, subfolder: sub.id)
        store.addCollocation(documentId: d.id, to: ref)
        XCTAssertEqual(store.fileIds(in: ref), [d.id])
    }

    func test_renameAndDeleteContainers() {
        let store = makeStore()
        let ws = store.createWorkspace(name: "W")
        let folder = store.createFolder(inWorkspace: ws.id, name: "F")!
        let sub = store.createSubfolder(inWorkspace: ws.id, folderId: folder.id, name: "S")!
        store.renameWorkspace(id: ws.id, to: "W2")
        store.renameFolder(inWorkspace: ws.id, folderId: folder.id, to: "F2")
        store.renameSubfolder(inWorkspace: ws.id, folderId: folder.id, subfolderId: sub.id, to: "S2")
        XCTAssertEqual(store.workspace(id: ws.id)?.name, "W2")
        XCTAssertEqual(store.folders(inWorkspace: ws.id).first?.name, "F2")
        XCTAssertEqual(store.subfolders(inWorkspace: ws.id, folderId: folder.id).first?.name, "S2")
        store.deleteSubfolder(inWorkspace: ws.id, folderId: folder.id, subfolderId: sub.id)
        XCTAssertEqual(store.subfolders(inWorkspace: ws.id, folderId: folder.id).count, 0)
        store.deleteFolder(inWorkspace: ws.id, folderId: folder.id)
        XCTAssertEqual(store.folders(inWorkspace: ws.id).count, 0)
    }

    // MARK: - Ordinamento (§ 12.3)

    func test_sorting_alphabeticalAndImportDate() {
        let store = makeStore()
        let c = store.addDocument(title: "Gamma", sourceFileName: "g.pdf", sourcePageCount: 1)
        let a = store.addDocument(title: "alfa", sourceFileName: "a.pdf", sourcePageCount: 1)
        let b = store.addDocument(title: "Beta", sourceFileName: "b.pdf", sourcePageCount: 1)
        let docs = [c, a, b]
        XCTAssertEqual(store.sorted(docs, by: .alphabetical).map { $0.title }, ["alfa", "Beta", "Gamma"])
        // import date decrescente: l'ultimo importato (b) per primo.
        XCTAssertEqual(store.sorted(docs, by: .importDate).map { $0.id }, [b.id, a.id, c.id])
    }

    // MARK: - Persistenza (round-trip)

    func test_persistence_roundTripsThroughBoundary() {
        let persistence = InMemoryLibraryPersistence()
        let store1 = makeStore(persistence: persistence)
        let d = store1.addDocument(title: "Persistito", sourceFileName: "p.pdf", sourcePageCount: 7)
        let ws = store1.createWorkspace(name: "W")
        store1.addCollocation(documentId: d.id, to: .workspace(ws.id))
        store1.updateReadingPosition(id: d.id, position: 13)
        store1.recordOpened(id: d.id)

        // Un nuovo store sullo STESSO blob ricostruisce lo stato.
        let store2 = LibraryStore(persistence: persistence)
        XCTAssertEqual(store2.document(id: d.id)?.title, "Persistito")
        XCTAssertEqual(store2.document(id: d.id)?.readingPosition, 13)
        XCTAssertEqual(store2.fileIds(in: .workspace(ws.id)), [d.id])
        XCTAssertEqual(store2.lastOpenDocumentId, d.id)
    }
}
