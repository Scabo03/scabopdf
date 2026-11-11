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

    // MARK: - Cure mirate (LAYER2 § 0-ter, giro del 2026-11-06)

    private let targetedSha = "d0272b2123af0ae040045ef2942c9d8414c2a779a3457a0f3087f62de8bca815"
    private func targetedDoc(sha: String?, build: String?, origin: String? = nil, kind: String? = nil) -> ArchivedDocument {
        ArchivedDocument(id: "m", title: "t", sourceFileName: "t.pdf", importedAt: Date(), sourcePageCount: 10,
                         sourceKind: kind, processedSystemVersion: "iPadOS 27.0.1", processedAppBuild: build,
                         sourceSha256: sha, readingOrigin: origin)
    }

    func test_targetedCure_offeredOnlyToTheRegisteredFingerprint() {
        let p = ReprocessingPolicy(validatedSystemMajors: [26, 27], latestCureBuild: 58,
                                   targetedCureBuilds: [targetedSha: 62])
        // Il documento registrato, elaborato prima della build della cura: offerta.
        XCTAssertEqual(p.reason(for: targetedDoc(sha: targetedSha, build: "61"), currentSystemVersion: "iPadOS 27.0.1",
                                currentAppBuild: "62"), .cure)
        XCTAssertEqual(p.pendingTargetedCureBuild(for: targetedDoc(sha: targetedSha, build: "61"), currentAppBuild: "62"), 62)
        // Già elaborato con la cura, o da questa stessa build: niente.
        XCTAssertNil(p.reason(for: targetedDoc(sha: targetedSha, build: "62"), currentSystemVersion: "iPadOS 27.0.1",
                              currentAppBuild: "62"))
        XCTAssertNil(p.reason(for: targetedDoc(sha: targetedSha, build: "63"), currentSystemVersion: "iPadOS 27.0.1",
                              currentAppBuild: "63"))
        // Ogni altro libro elaborato dopo l'ultima cura generale: niente, la cura mirata non si propone agli altri.
        let other = String(repeating: "a", count: 64)
        XCTAssertNil(p.reason(for: targetedDoc(sha: other, build: "61"), currentSystemVersion: "iPadOS 27.0.1",
                              currentAppBuild: "62"))
        XCTAssertNil(p.reason(for: targetedDoc(sha: nil, build: "61"), currentSystemVersion: "iPadOS 27.0.1",
                              currentAppBuild: "62"))
        // Le letture arrivate dal Mac e i testi normativi non la ricevono.
        XCTAssertNil(p.reason(for: targetedDoc(sha: targetedSha, build: "58", origin: ReadingOrigin.mac),
                              currentSystemVersion: "iPadOS 27.0.1", currentAppBuild: "62"))
        XCTAssertNil(p.pendingTargetedCureBuild(for: targetedDoc(sha: targetedSha, build: "58", origin: ReadingOrigin.mac)))
        XCTAssertNil(p.pendingTargetedCureBuild(for: targetedDoc(sha: targetedSha, build: "61", kind: "akn")))
        // Una generazione non validata: nessuna offerta, nemmeno mirata.
        XCTAssertNil(p.reason(for: targetedDoc(sha: targetedSha, build: "61"), currentSystemVersion: "iPadOS 28.0",
                              currentAppBuild: "62"))
    }

    func test_targetedCure_registryAndPolicyAgree() {
        // La politica senza cure mirate (com'era fino alla build 61) non offre nulla al documento registrato elaborato dopo
        // l'ultima cura generale.
        let before = ReprocessingPolicy(validatedSystemMajors: [26, 27], latestCureBuild: 58)
        XCTAssertNil(before.reason(for: targetedDoc(sha: targetedSha, build: "61"), currentSystemVersion: "iPadOS 27.0.1",
                                   currentAppBuild: "62"))
        // Rifiniture del giro «rifiniture e cure per capacità» (build 63): la build della cura sale.
        XCTAssertEqual(TargetedCures.cureBuildByFingerprint[targetedSha], 63)
        // Il documento già elaborato con la cura 62 riceve di nuovo l'offerta; nessun altro libro la riceve.
        let now = ReprocessingPolicy(validatedSystemMajors: [26, 27], latestCureBuild: 58,
                                     targetedCureBuilds: TargetedCures.cureBuildByFingerprint)
        XCTAssertEqual(now.reason(for: targetedDoc(sha: targetedSha, build: "62"), currentSystemVersion: "iPadOS 27.0.1",
                                  currentAppBuild: "63"), .cure)
        XCTAssertNil(now.reason(for: targetedDoc(sha: targetedSha, build: "63"), currentSystemVersion: "iPadOS 27.0.1",
                                currentAppBuild: "63"))
        XCTAssertNil(now.reason(for: targetedDoc(sha: String(repeating: "a", count: 64), build: "62"),
                                currentSystemVersion: "iPadOS 27.0.1", currentAppBuild: "63"))
    }

    // MARK: - Tutti e soli i libri la cui lettura cambia (cura 64, giro «rifiniture e cure per capacità»)

    private func measuredDoc(sha: String?, build: String?, system: String = "iPadOS 27.0.1",
                             origin: String? = nil) -> ArchivedDocument {
        ArchivedDocument(id: "u", title: "t", sourceFileName: "t.pdf", importedAt: Date(), sourcePageCount: 10,
                         sourceKind: nil, processedSystemVersion: system, processedAppBuild: build,
                         sourceSha256: sha, readingOrigin: origin)
    }

    func test_capabilityCure_offeredToAllAndOnlyTheBooksItChanges() {
        let unchanged27 = String(repeating: "b", count: 64), unchangedOnly27 = String(repeating: "c", count: 64)
        let changed = String(repeating: "d", count: 64)
        let p = ReprocessingPolicy(validatedSystemMajors: [26, 27], latestCureBuild: 64,
                                   cureBuilds: [45, 53, 55, 56, 57, 58, 64],
                                   unchangedByCure: [64: [27: [unchanged27, unchangedOnly27], 26: [unchanged27]]])
        func reason(_ sha: String?, _ build: String?, now: String = "iPadOS 27.0.1",
                    system: String = "iPadOS 27.0.1") -> ReprocessingReason? {
            p.reason(for: measuredDoc(sha: sha, build: build, system: system), currentSystemVersion: now, currentAppBuild: "64")
        }
        // Un libro misurato che la cura 64 lascia identico, elaborato dopo l'ultima cura precedente: nessuna offerta.
        XCTAssertNil(reason(unchanged27, "63"))
        XCTAssertNil(reason(unchanged27, "58"))
        // Un libro misurato che la cura cambia, o sconosciuto, o senza impronta: l'offerta c'è.
        XCTAssertEqual(reason(changed, "63"), .cure)
        XCTAssertEqual(reason(String(repeating: "e", count: 64), "63"), .cure, "sconosciuto: senza rielaborare non si sa")
        XCTAssertEqual(reason(nil, "63"), .cure)
        // Gli manca anche una cura più vecchia (non misurata per lui): l'offerta c'è.
        XCTAssertEqual(reason(unchanged27, "57"), .cure)
        XCTAssertEqual(reason(unchanged27, nil), .cure)
        // La misura vale per generazione: un libro identico solo su iOS 27 riceve l'offerta su iOS 26.
        XCTAssertNil(reason(unchangedOnly27, "63"))
        XCTAssertEqual(reason(unchangedOnly27, "63", now: "iPadOS 26.5", system: "iPadOS 26.5"), .cure)
        XCTAssertNil(reason(unchanged27, "63", now: "iPadOS 26.5", system: "iPadOS 26.5"))
        // Elaborato con un'altra generazione: l'aggiornamento del sistema resta un motivo, anche se la cura non lo cambia.
        XCTAssertEqual(reason(unchanged27, "63", system: "iPadOS 26.5"), .systemUpdate)
        // Elaborato da questa stessa build: niente.
        XCTAssertNil(reason(changed, "64"))
        // Le domande una per una.
        XCTAssertTrue(p.cureLeavesUnchanged(64, measuredDoc(sha: unchanged27, build: "63"), currentSystemVersion: "iPadOS 27.0.1"))
        XCTAssertFalse(p.cureLeavesUnchanged(58, measuredDoc(sha: unchanged27, build: "57"), currentSystemVersion: "iPadOS 27.0.1"))
        XCTAssertFalse(p.pendingCuresLeaveUnchanged(measuredDoc(sha: unchanged27, build: "64"), since: 64,
                                                    currentSystemVersion: "iPadOS 27.0.1"), "nessuna cura in sospeso")
    }

    /// Giro «prova 4, segnalibri e sigle» (2026-11-11): dalla cura 66 anche ai testi normativi l'offerta arriva a TUTTI E SOLI
    /// quelli la cui lettura cambia. Un atto misurato che la cura lascia identico non la riceve (senza generazione: la sua
    /// lettura non dipende dal lettore di sistema); uno sconosciuto, uno senza impronta, uno a cui manca anche una cura più
    /// vecchia sì.
    func test_akn_cure66_offeredToAllAndOnlyTheActsItChanges() {
        let same = String(repeating: "a", count: 64), changed = String(repeating: "d", count: 64)
        let p = ReprocessingPolicy(validatedSystemMajors: [26, 27], latestCureBuild: 66, latestCureBuildForAknActs: 66,
                                   aknCureBuilds: [56, 57, 66], unchangedAknActsByCure: [66: [same]])
        func act(_ sha: String?, _ build: String?, system: String = "iPadOS 27.0.1") -> ArchivedDocument {
            ArchivedDocument(id: "a", title: "t", sourceFileName: "t.xml", importedAt: Date(), sourcePageCount: 0,
                             sourceKind: "akn", processedSystemVersion: system, processedAppBuild: build, sourceSha256: sha)
        }
        func reason(_ d: ArchivedDocument, now: String = "iPadOS 27.0.1") -> ReprocessingReason? {
            p.reason(for: d, currentSystemVersion: now, currentAppBuild: "66")
        }
        XCTAssertNil(reason(act(same, "57")), "misurato identico: nessuna offerta")
        XCTAssertNil(reason(act(same, "57"), now: "iPadOS 26.5"), "su ogni generazione")
        XCTAssertNil(reason(act(same, "64", system: "iPadOS 26.5")), "un aggiornamento del sistema non conta per gli atti")
        XCTAssertEqual(reason(act(changed, "57")), .cure)
        XCTAssertEqual(reason(act(String(repeating: "e", count: 64), "57")), .cure, "sconosciuto: senza rielaborare non si sa")
        XCTAssertEqual(reason(act(nil, "57")), .cure)
        XCTAssertEqual(reason(act(same, "56")), .cure, "gli manca anche la 57, non misurata per lui")
        XCTAssertEqual(reason(act(same, nil)), .cure)
        XCTAssertNil(reason(act(changed, "66")), "elaborato con la 66")
        XCTAssertTrue(p.aknCureLeavesUnchanged(66, act(same, "57")))
        XCTAssertFalse(p.aknCureLeavesUnchanged(57, act(same, "56")))
        XCTAssertFalse(p.pendingAknCuresLeaveUnchanged(act(same, "66"), since: 66), "nessuna cura in sospeso")
        // Senza le misure (o senza l'elenco delle cure degli atti) la regola resta quella di prima: si offre.
        let before = ReprocessingPolicy(validatedSystemMajors: [26, 27], latestCureBuild: 66, latestCureBuildForAknActs: 66)
        XCTAssertEqual(before.reason(for: act(same, "57"), currentSystemVersion: "iPadOS 27.0.1", currentAppBuild: "66"), .cure)
        // Le misure dei testi normativi non valgono per i PDF con la stessa impronta, né viceversa.
        let pdf = ArchivedDocument(id: "p", title: "t", sourceFileName: "t.pdf", importedAt: Date(), sourcePageCount: 10,
                                   processedSystemVersion: "iPadOS 27.0.1", processedAppBuild: "64", sourceSha256: same)
        XCTAssertEqual(p.reason(for: pdf, currentSystemVersion: "iPadOS 27.0.1", currentAppBuild: "66"), .cure)
    }

    func test_capabilityCure_withoutMeasurements_behavesAsBefore() {
        let before = ReprocessingPolicy(validatedSystemMajors: [26, 27], latestCureBuild: 64)
        XCTAssertEqual(before.reason(for: measuredDoc(sha: String(repeating: "b", count: 64), build: "63"),
                                     currentSystemVersion: "iPadOS 27.0.1", currentAppBuild: "64"), .cure)
    }
}
