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

    func test_riconoscimentoSaltato_siRipropone_maNonAllInfinitoConLaStessaApp() {
        // Revisione indipendente del giro: un iPad che non ha mai memoria abbastanza non deve ricevere l'offerta per sempre.
        let store = LibraryStore(persistence: InMemoryLibraryPersistence())
        let d = store.addDocument(title: "t", sourceFileName: "t.pdf", sourcePageCount: 3)
        let p = ReprocessingPolicy(validatedSystemMajors: [26, 27], latestCureBuild: 54)
        func reason() -> ReprocessingReason? {
            p.reason(for: store.document(id: d.id)!, currentSystemVersion: "iPadOS 27.0.1", currentAppBuild: "54")
        }
        store.recordProcessed(id: d.id, systemVersion: "iPadOS 27.0.1", appBuild: "54", visualResourcesSkipped: "memoria scarsa")
        XCTAssertEqual(reason(), .cure, "il primo salto: si propone di riprovare")
        store.recordProcessed(id: d.id, systemVersion: "iPadOS 27.0.1", appBuild: "54", visualResourcesSkipped: "memoria scarsa")
        XCTAssertNil(reason(), "riprovato e fallito di nuovo con la stessa app: l'offerta tace")
        XCTAssertEqual(p.reason(for: store.document(id: d.id)!, currentSystemVersion: "iPadOS 27.0.1", currentAppBuild: "55"),
                       .cure, "con una versione nuova dell'app si ripropone")
        store.recordProcessed(id: d.id, systemVersion: "iPadOS 27.0.1", appBuild: "55", visualResourcesSkipped: nil)
        XCTAssertNil(store.document(id: d.id)!.visualResourcesRetriedBuild, "riuscito: nessun segno resta")
        XCTAssertNil(store.document(id: d.id)!.visualResourcesSkipped)
    }

    /// Giro del 2026-10-16: la cura 55 (note lunghe frazionate anche quando l'iPad elabora da sé un PDF) si offre ai libri
    /// elaborati dall'iPad prima della 55, ma NON alle letture arrivate dal Mac, che le frazionano da sempre (rielaborarle
    /// sull'iPad toglierebbe solo l'innesto del Mac); una cura successiva che il Mac non contiene si offre di nuovo.
    func test_curaDelFrazionamento_nonSiOffreAlleLettureDelMac() {
        let store = LibraryStore(persistence: InMemoryLibraryPersistence())
        let mac = store.addDocument(title: "m", sourceFileName: "m.pdf", sourcePageCount: 3)
        store.recordReceivedReading(id: mac.id, systemVersion: "macOS 27.0.1", cureLevel: 53, at: Date())
        let ipad = store.addDocument(title: "i", sourceFileName: "i.pdf", sourcePageCount: 3)
        store.recordProcessed(id: ipad.id, systemVersion: "iPadOS 27.0.1", appBuild: "54")
        let p55 = ReprocessingPolicy(validatedSystemMajors: [26, 27], latestCureBuild: 55, latestCureBuildForMacReadings: 53)
        func reason(_ p: ReprocessingPolicy, _ id: String) -> ReprocessingReason? {
            p.reason(for: store.document(id: id)!, currentSystemVersion: "iPadOS 27.0.1", currentAppBuild: "55")
        }
        XCTAssertNil(reason(p55, mac.id), "la lettura del Mac ha già le note lunghe frazionate")
        XCTAssertEqual(reason(p55, ipad.id), .cure, "il libro elaborato dall'iPad con la build 54 riceve la cura")
        // Prova al contrario: senza il limite a parte la lettura del Mac riceverebbe l'offerta (il caso che la regola evita).
        XCTAssertEqual(reason(ReprocessingPolicy(validatedSystemMajors: [26, 27], latestCureBuild: 55), mac.id), .cure)
        // Una cura nuova, che le letture del Mac non contengono, si offre anche a loro.
        let p56 = ReprocessingPolicy(validatedSystemMajors: [26, 27], latestCureBuild: 56, latestCureBuildForMacReadings: 56)
        XCTAssertEqual(reason(p56, mac.id), .cure)
        // Una lettura del Mac preparata con il livello 55 non riceve la cura 55.
        store.recordReceivedReading(id: mac.id, systemVersion: "macOS 27.0.1", cureLevel: 55, at: Date())
        XCTAssertNil(reason(ReprocessingPolicy(validatedSystemMajors: [26, 27], latestCureBuild: 55), mac.id))
    }

    func test_akn_withoutACureOfItsChain_neverOffered() {
        // la regola fino alla build 56: senza una cura dichiarata per i testi normativi, nessuna offerta
        XCTAssertNil(policy.reason(for: doc("akn", build: "40"), currentSystemVersion: "iPadOS 27.0.1"))
    }

    /// Giro «pulizia e rifinitura finale del capitolo note» (2026-10-17, decisione 1 del maintainer): un testo normativo già
    /// importato riceve l'offerta per una cura della SUA catena che non aveva, mai per un aggiornamento del sistema né per le
    /// cure dei soli PDF. Le cure della catena dei testi normativi sono la 56 (i pezzi nuovi delle note) e la 57 (l'etichetta
    /// di un elenco fra parentesi resta col suo primo elemento): la configurazione in produzione è 57.
    func test_akn_offeredOnlyACureOfItsChain() {
        let p = ReprocessingPolicy(validatedSystemMajors: [26, 27], latestCureBuild: 57, latestCureBuildForAknActs: 57)
        XCTAssertEqual(p.reason(for: doc("akn", build: "55"), currentSystemVersion: "iPadOS 27.0.1"), .cure)
        XCTAssertEqual(p.reason(for: doc("akn", system: nil, build: nil), currentSystemVersion: "iPadOS 27.0.1"), .cure)
        XCTAssertEqual(p.reason(for: doc("akn", build: "56"), currentSystemVersion: "iPadOS 27.0.1", currentAppBuild: "57"), .cure,
                       "importato con la 56: riceve la cura 57 della sua catena")
        XCTAssertNil(p.reason(for: doc("akn", build: "57"), currentSystemVersion: "iPadOS 27.0.1"), "ha già la cura 57")
        XCTAssertNil(p.reason(for: doc("akn", build: "57"), currentSystemVersion: "iPadOS 27.0.1", currentAppBuild: "57"))
        // nessun lettore di sistema in gioco: un aggiornamento non conta, e una generazione non validata non ferma la cura
        XCTAssertNil(p.reason(for: doc("akn", system: "iPadOS 26.5", build: "57"), currentSystemVersion: "iPadOS 27.0.1"))
        XCTAssertEqual(p.reason(for: doc("akn", system: "iPadOS 26.5", build: "56"), currentSystemVersion: "iPadOS 27.0.1"), .cure)
        XCTAssertEqual(p.reason(for: doc("akn", build: "55"), currentSystemVersion: "iPadOS 28.0"), .cure)
        // elaborato dalla build in uso: niente offerta
        XCTAssertNil(p.reason(for: doc("akn", build: "55"), currentSystemVersion: "iPadOS 27.0.1", currentAppBuild: "55"))
        // un libro EPUB: mai
        XCTAssertNil(p.reason(for: doc("epub", build: "40"), currentSystemVersion: "iPadOS 27.0.1"))
        // la regola con una sola cura della catena (la build 56 com'era): chi l'ha già non riceve nulla
        let p56 = ReprocessingPolicy(validatedSystemMajors: [26, 27], latestCureBuild: 56, latestCureBuildForAknActs: 56)
        XCTAssertNil(p56.reason(for: doc("akn", build: "56"), currentSystemVersion: "iPadOS 27.0.1"), "ha già i pezzi nuovi")
        XCTAssertEqual(p56.reason(for: doc("akn", build: "55"), currentSystemVersion: "iPadOS 27.0.1"), .cure)
    }

    /// I tre tipi di libro con le regole della decisione 1, nella configurazione in produzione (cura 57): il PDF elaborato
    /// sull'iPad riceve la cura nuova; la lettura arrivata dal Mac no (si rifà dal Mac aggiornato); il testo normativo
    /// importato prima della 57 sì, anche se aveva già i pezzi nuovi della 56.
    func test_threeKindsOfBook() {
        let store = LibraryStore(persistence: InMemoryLibraryPersistence())
        let pdf = store.addDocument(title: "p", sourceFileName: "p.pdf", sourcePageCount: 3)
        store.recordProcessed(id: pdf.id, systemVersion: "iPadOS 27.0.1", appBuild: "56")
        let mac = store.addDocument(title: "m", sourceFileName: "m.pdf", sourcePageCount: 3)
        store.recordReceivedReading(id: mac.id, systemVersion: "macOS 27.0.1", cureLevel: 56, at: Date())
        let akn = store.addDocument(title: "a", sourceFileName: "a.xml", sourcePageCount: 0, sourceKind: "akn")
        store.recordProcessed(id: akn.id, systemVersion: "iPadOS 27.0.1", appBuild: "55")
        let akn56 = store.addDocument(title: "b", sourceFileName: "b.xml", sourcePageCount: 0, sourceKind: "akn")
        store.recordProcessed(id: akn56.id, systemVersion: "iPadOS 27.0.1", appBuild: "56")
        let akn57 = store.addDocument(title: "c", sourceFileName: "c.xml", sourcePageCount: 0, sourceKind: "akn")
        store.recordProcessed(id: akn57.id, systemVersion: "iPadOS 27.0.1", appBuild: "57")
        // le cure 56 e 57 arrivano alle letture del Mac solo dal Mac: l'ultima che possono ricevere dall'iPad è la 53
        let p = ReprocessingPolicy(validatedSystemMajors: [26, 27], latestCureBuild: 57, latestCureBuildForMacReadings: 53,
                                   latestCureBuildForAknActs: 57)
        func reason(_ id: String) -> ReprocessingReason? {
            p.reason(for: store.document(id: id)!, currentSystemVersion: "iPadOS 27.0.1", currentAppBuild: "57")
        }
        XCTAssertEqual(reason(pdf.id), .cure, "il PDF elaborato sull'iPad con la 56 riceve la cura 57")
        XCTAssertNil(reason(mac.id), "la lettura arrivata dal Mac non riceve la cura delle note: la rifà il Mac")
        XCTAssertEqual(reason(akn.id), .cure, "il testo normativo importato con la 55 riceve i pezzi nuovi")
        XCTAssertEqual(reason(akn56.id), .cure, "importato con la 56: riceve la cura 57 della sua catena")
        XCTAssertNil(reason(akn57.id), "importato con la 57: niente da offrire")
        let eligible = p.eligibleDocuments(store.allDocuments(), currentSystemVersion: "iPadOS 27.0.1", currentAppBuild: "57")
        XCTAssertEqual(Set(eligible.map { $0.id }), [pdf.id, akn.id, akn56.id])
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
