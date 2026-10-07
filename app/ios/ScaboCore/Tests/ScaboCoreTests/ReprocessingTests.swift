import XCTest
@testable import ScaboCore

final class ReprocessingTests: XCTestCase {
    private let policy = ReprocessingPolicy(validatedSystemMajors: [26, 27], latestCureBuild: 48)

    private func doc(_ kind: String? = nil, system: String? = "iPadOS 27.0.1", build: String? = "47") -> ArchivedDocument {
        ArchivedDocument(id: "d", title: "t", sourceFileName: "t.pdf", importedAt: Date(), sourcePageCount: 10,
                         sourceKind: kind, processedSystemVersion: system, processedAppBuild: build)
    }

    func test_major() {
        XCTAssertEqual(ReprocessingPolicy.major(of: "iPadOS 27.0.1"), 27)
        XCTAssertEqual(ReprocessingPolicy.major(of: "iOS 26.5"), 26)
        XCTAssertNil(ReprocessingPolicy.major(of: nil))
    }

    func test_cure_offeredForOlderChainOrUnlabelled() {
        XCTAssertEqual(policy.reason(for: doc(build: "47"), currentSystemVersion: "iPadOS 27.0.1"), .cure)
        XCTAssertEqual(policy.reason(for: doc(system: nil, build: nil), currentSystemVersion: "iPadOS 27.0.1"), .cure)
        XCTAssertNil(policy.reason(for: doc(build: "48"), currentSystemVersion: "iPadOS 27.0.1"))
    }

    func test_systemUpdate_offeredOnlyIfNewGenerationValidated() {
        XCTAssertEqual(policy.reason(for: doc(system: "iPadOS 26.5", build: "48"), currentSystemVersion: "iPadOS 27.0.1"), .systemUpdate)
        // Una generazione non validata dalla build in uso: nessuna offerta, nemmeno per la cura.
        XCTAssertNil(policy.reason(for: doc(system: "iPadOS 27.0", build: "48"), currentSystemVersion: "iPadOS 28.0"))
        XCTAssertNil(policy.reason(for: doc(build: "40"), currentSystemVersion: "iPadOS 28.0"))
    }

    func test_processedByTheBuildInUse_isNotOfferedTheCure() {
        XCTAssertNil(policy.reason(for: doc(build: "1"), currentSystemVersion: "iPadOS 27.0.1", currentAppBuild: "1"))
        XCTAssertEqual(policy.reason(for: doc(build: "1"), currentSystemVersion: "iPadOS 27.0.1", currentAppBuild: "48"), .cure)
    }

    func test_akn_neverOffered() {
        XCTAssertNil(policy.reason(for: doc("akn", build: "40"), currentSystemVersion: "iPadOS 27.0.1"))
    }

    func test_snapshotRestore_bringsBackAnnotationsAndLabel() throws {
        let store = LibraryStore(persistence: InMemoryLibraryPersistence())
        let d = store.addDocument(title: "t", sourceFileName: "t.pdf", sourcePageCount: 3)
        store.addBookmark(documentId: d.id, anchorSegmentId: "node_1", orderIndexHint: 1, preview: "p")
        store.updateReadingPosition(id: d.id, position: 4)
        store.recordProcessed(id: d.id, systemVersion: "iPadOS 27.0.1", appBuild: "47")
        let snap = try XCTUnwrap(store.readingSnapshot(documentId: d.id))
        // Rielaborazione: tutto cambia…
        store.applyAnnotationState(documentId: d.id, bookmarks: [], underlines: [], readingPosition: 0,
                                   readingAnchor: nil, readingPositionIsApproximate: true)
        store.recordProcessed(id: d.id, systemVersion: "iPadOS 27.0.1", appBuild: "48")
        // …e si torna indietro esattamente.
        store.restore(snap, documentId: d.id)
        let back = try XCTUnwrap(store.document(id: d.id))
        XCTAssertEqual(back.bookmarks?.count, 1)
        XCTAssertEqual(back.readingPosition, 4)
        XCTAssertEqual(back.processedAppBuild, "47")
        XCTAssertNil(back.readingPositionIsApproximate)
    }

    func test_revert_neverDropsAnnotationsMadeAfterTheSnapshot() throws {
        let store = LibraryStore(persistence: InMemoryLibraryPersistence())
        let d = store.addDocument(title: "t", sourceFileName: "t.pdf", sourcePageCount: 3)
        store.addBookmark(documentId: d.id, anchorSegmentId: "node_1", orderIndexHint: 1, preview: "vecchio")
        let snap = try XCTUnwrap(store.readingSnapshot(documentId: d.id))
        let seg = ContentSegment(id: "node_9", role: "BODY", text: "Un paragrafo nuovo abbastanza lungo da avere un'impronta di testa e di coda ben distinte fra loro.", lengthCategory: "", acousticIntro: "", sourcePage: 1)
        let newIndex = ContentAnchorIndex(segments: [seg])
        store.addBookmark(documentId: d.id, anchorSegmentId: "node_9", orderIndexHint: 0, preview: "nuovo", originalPage: 1,
                          anchor: newIndex.anchor(forIndex: 0))
        // Contenuto ripristinato che contiene lo stesso paragrafo (con un altro id): il segnalibro nuovo lo segue.
        let oldSeg = ContentSegment(id: "node_3", role: "BODY", text: seg.text, lengthCategory: "", acousticIntro: "", sourcePage: 1)
        let r = store.restore(snap, documentId: d.id, restoredContent: ContentAnchorIndex(segments: [oldSeg]))
        XCTAssertEqual(r.carried, 1); XCTAssertEqual(r.orphaned, 0)
        let bms = store.bookmarks(documentId: d.id)
        XCTAssertEqual(bms.count, 2, "nessuna annotazione persa tornando indietro")
        XCTAssertEqual(bms.first { $0.preview == "nuovo" }?.anchorSegmentId, "node_3")
        // Senza contenuto ripristinato: resta, dichiarata orfana.
        store.addBookmark(documentId: d.id, anchorSegmentId: "node_9", orderIndexHint: 0, preview: "altro")
        let r2 = store.restore(snap, documentId: d.id)
        XCTAssertEqual(store.bookmarks(documentId: d.id).first { $0.preview == "altro" }?.isOrphan, true)
        XCTAssertGreaterThan(r2.carried, 0)
    }
}
