//
//  SplitStateTests.swift
//  ScaboCoreTests
//
//  Logica pura dello split screen (§ 11): stato, regimi/sotto-regimi, spostamento della linea
//  (§ 11.7), sincronizzazione follower (§ 11.4/§ 11.5), persistenza e retro-compat (§ 11.9), e la
//  pulizia dello split quando un documento referenziato viene eliminato. Il Simulator non certifica
//  VoiceOver, i gesti reali né la memoria: quelli restano collaudo device.
//

import XCTest
@testable import ScaboCore

final class SplitStateTests: XCTestCase {

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

    // MARK: - Stato e default

    func test_defaultState_isAutonomousCentered() {
        let s = SplitState(leftDocumentId: "a", rightDocumentId: "b")
        XCTAssertEqual(s.regime, .autonomous)
        XCTAssertEqual(s.subRegime, .followPage)
        XCTAssertEqual(s.dividerFraction, 0.5, accuracy: 0.0001, "parte dal centro perfetto (§ 11.7)")
        XCTAssertEqual(s.documentId(on: .left), "a")
        XCTAssertEqual(s.documentId(on: .right), "b")
    }

    func test_side_other() {
        XCTAssertEqual(SplitSide.left.other, .right)
        XCTAssertEqual(SplitSide.right.other, .left)
    }

    // MARK: - Linea di divisione (§ 11.7)

    func test_dividerMoves_byStep_andClampsWithinBounds() {
        var s = SplitState(leftDocumentId: "a", rightDocumentId: "b", dividerFraction: 0.5)
        s = s.movingDivider(towards: .right)
        XCTAssertEqual(s.dividerFraction, 0.55, accuracy: 0.0001)
        // Spinge oltre il massimo: si ferma al bound (§ 11.7, nessuna metà sotto il 20%).
        for _ in 0..<20 { s = s.movingDivider(towards: .right) }
        XCTAssertEqual(s.dividerFraction, SplitState.maxFraction, accuracy: 0.0001)
        for _ in 0..<40 { s = s.movingDivider(towards: .left) }
        XCTAssertEqual(s.dividerFraction, SplitState.minFraction, accuracy: 0.0001)
    }

    func test_initClampsFraction() {
        XCTAssertEqual(SplitState(leftDocumentId: "a", rightDocumentId: "b", dividerFraction: 0.99).dividerFraction,
                       SplitState.maxFraction, accuracy: 0.0001)
        XCTAssertEqual(SplitState(leftDocumentId: "a", rightDocumentId: "b", dividerFraction: 0.01).dividerFraction,
                       SplitState.minFraction, accuracy: 0.0001)
    }

    // MARK: - Sincronizzazione follower (§ 11.4 / § 11.5)

    func test_absolute_lockStepIndex_clamped() {
        XCTAssertEqual(SplitSync.followerIndexAbsolute(leaderIndex: 3, followerElementCount: 10), 3)
        XCTAssertEqual(SplitSync.followerIndexAbsolute(leaderIndex: 99, followerElementCount: 10), 9,
                       "clamp all'ultimo elemento del follower")
        XCTAssertEqual(SplitSync.followerIndexAbsolute(leaderIndex: -1, followerElementCount: 10), 0)
        XCTAssertNil(SplitSync.followerIndexAbsolute(leaderIndex: 3, followerElementCount: 0),
                     "follower vuoto → nessuna azione")
    }

    func test_followPage_onlyOnPageChange() {
        XCTAssertNil(SplitSync.followerPageFollowPage(leaderPageBefore: 2, leaderPageAfter: 2, followerPageCount: 5),
                     "stessa pagina → nessuna azione")
        XCTAssertEqual(SplitSync.followerPageFollowPage(leaderPageBefore: 2, leaderPageAfter: 3, followerPageCount: 5), 3)
        XCTAssertEqual(SplitSync.followerPageFollowPage(leaderPageBefore: 0, leaderPageAfter: 9, followerPageCount: 5), 4,
                       "clamp all'ultima pagina del follower")
    }

    func test_followLevel_advancesBySameUnitDelta() {
        // La guida passa dall'unità 2 alla 3 (+1): il follower avanza di 1 dalla sua unità corrente.
        XCTAssertEqual(SplitSync.followerUnitFollowLevel(
            leaderUnitBefore: 2, leaderUnitAfter: 3, followerUnitCurrent: 5, followerUnitCount: 10), 6)
        // Nessun cambio unità → nessuna azione.
        XCTAssertNil(SplitSync.followerUnitFollowLevel(
            leaderUnitBefore: 2, leaderUnitAfter: 2, followerUnitCurrent: 5, followerUnitCount: 10))
        // Arretramento della guida (-2): il follower arretra di 2, clampato a 0.
        XCTAssertEqual(SplitSync.followerUnitFollowLevel(
            leaderUnitBefore: 4, leaderUnitAfter: 2, followerUnitCurrent: 1, followerUnitCount: 10), 0)
    }

    // MARK: - Persistenza (§ 11.9), retro-compat, pulizia su eliminazione

    func test_setAndClearSplitState_persists() {
        let persistence = InMemoryLibraryPersistence()
        do {
            let store = makeStore(persistence: persistence)
            store.setSplitState(SplitState(leftDocumentId: "a", rightDocumentId: "b",
                                           regime: .partial, subRegime: .followLevel, dividerFraction: 0.6))
        }
        let reloaded = makeStore(persistence: persistence)
        XCTAssertEqual(reloaded.splitState?.leftDocumentId, "a")
        XCTAssertEqual(reloaded.splitState?.rightDocumentId, "b")
        XCTAssertEqual(reloaded.splitState?.regime, .partial)
        XCTAssertEqual(reloaded.splitState?.subRegime, .followLevel)
        XCTAssertEqual(reloaded.splitState?.dividerFraction ?? 0, 0.6, accuracy: 0.0001)
        reloaded.setSplitState(nil)
        XCTAssertNil(makeStore(persistence: persistence).splitState, "azzerato e persistito")
    }

    func test_decodingOldLibrary_withoutSplitKey_doesNotReset() {
        let oldJSON = """
        {"documents":[],"workspaces":[]}
        """
        let store = makeStore(persistence: InMemoryLibraryPersistence(Data(oldJSON.utf8)))
        XCTAssertNil(store.splitState, "chiave assente → nessuno split, nessun reset")
        XCTAssertEqual(store.allDocuments().count, 0)
    }

    func test_deletingDocument_clearsSplitReferencingIt() {
        let store = makeStore()
        let a = store.addDocument(title: "A", sourceFileName: "a.pdf", sourcePageCount: 1)
        let b = store.addDocument(title: "B", sourceFileName: "b.pdf", sourcePageCount: 1)
        store.setSplitState(SplitState(leftDocumentId: a.id, rightDocumentId: b.id))
        store.deleteDocumentFromArchive(id: b.id)
        XCTAssertNil(store.splitState, "eliminato un documento dello split → split invalidato (§ 2.5)")
    }

    func test_unknownRegimeRawValue_isRejectedByEnum() {
        XCTAssertNil(ParallelizationRegime(rawValue: "boh"))
        XCTAssertEqual(ParallelizationRegime(rawValue: "absolute"), .absolute)
        XCTAssertNil(LinkSubRegime(rawValue: "boh"))
        XCTAssertEqual(LinkSubRegime(rawValue: "followLevel"), .followLevel)
    }
}
