//
//  VisualResourceTests.swift
//  ScaboAppTests
//
//  Le RISORSE VISIVE nella lettura (giro 2026-10-12, `docs/RISORSE_VISIVE.md`): l'elemento additivo annunciato come
//  tale, le sue azioni, il testo della regione che resta raggiungibile con lo swipe, i rotori «Tabelle» e «Immagini»,
//  la Consultazione Rapida e il ritaglio della SOLA regione. Testi sintetici e neutri; il PDF è generato qui. Il foglio
//  di condivisione è intercettato: nessuna interfaccia di sistema compare durante le prove.
//

import XCTest
import PDFKit
import ScaboCore
@testable import ScaboApp
import ScaboChain

final class VisualResourceTests: XCTestCase {

    // MARK: - Fixture

    private func seg(_ id: String, _ text: String, role: String = "BODY", page: Int = 1) -> ContentSegment {
        ContentSegment(id: id, role: role, text: text, lengthCategory: "", acousticIntro: "", sourcePage: page)
    }

    private func visual(_ kind: VisualResourceKind, id: String, contained: Int, caption: String? = nil,
                        bbox: [Double] = [60, 200, 360, 320]) -> ContentSegment {
        let text = caption.map { "\(kind.word): \($0)" } ?? kind.word
        return ContentSegment(id: id, role: VISUAL_RESOURCE_ROLE, text: text, lengthCategory: "",
                              acousticIntro: acousticIntroFor(VISUAL_RESOURCE_ROLE, ""), memoryRefresh: "", sourcePage: 1,
                              visualResource: VisualResourcePayload(kind: kind, pageIndex: 0, bbox: bbox, containedElements: contained))
    }

    /// Titolo, paragrafo, TABELLA con due elementi di testo, paragrafo, FIGURA senza testo, paragrafo.
    private func flow() -> [ContentSegment] {
        [seg("n0", "Capitolo primo", role: "HEADING_1"),
         seg("n1", "Il paragrafo che precede la tabella del raccolto."),
         visual(.table, id: "vr_p0_0", contained: 2, caption: "Il raccolto per stagione"),
         seg("n2", "Stagione Raccolto Primavera Grano"),
         seg("n3", "Estate Orzo Autunno Uva"),
         seg("n4", "Il paragrafo che segue la tabella."),
         visual(.figure, id: "vr_p0_1", contained: 0),
         seg("n5", "L'ultimo paragrafo dopo la figura.")]
    }

    private func content(_ segs: [ContentSegment]) -> PaginatedContent {
        PaginatedContent(pages: [ContentPage(pageNumber: 1, segments: segs)], totalSegments: segs.count)
    }

    private func renderedView(_ segs: [ContentSegment]) -> ContinuousReadingView {
        let view = ContinuousReadingView(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        view.render(content(segs))
        return view
    }

    private func actionNames(_ view: ContinuousReadingView, _ index: Int) -> [String] {
        (view.makeConfiguredCellForTesting(at: index)?.accessibilityCustomActions ?? []).map { $0.name }
    }

    /// Un PDF di una pagina 420×595 con una tabella disegnata (filetti e parole neutre) fra due paragrafi.
    private func syntheticPDF() -> Data {
        UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 420, height: 595)).pdfData { ctx in
            ctx.beginPage()
            let font = UIFont.systemFont(ofSize: 12)
            ("Il paragrafo che precede la tabella del raccolto." as NSString).draw(at: CGPoint(x: 60, y: 120), withAttributes: [.font: font])
            let cg = ctx.cgContext
            cg.setStrokeColor(UIColor.black.cgColor); cg.setLineWidth(1)
            for r in 0...3 { cg.move(to: CGPoint(x: 60, y: 200 + r * 40)); cg.addLine(to: CGPoint(x: 360, y: 200 + r * 40)) }
            for c in 0...2 { cg.move(to: CGPoint(x: 60 + c * 150, y: 200)); cg.addLine(to: CGPoint(x: 60 + c * 150, y: 320)) }
            cg.strokePath()
            for (i, w) in ["Stagione", "Raccolto", "Primavera", "Grano", "Estate", "Orzo"].enumerated() {
                (w as NSString).draw(at: CGPoint(x: 70 + (i % 2) * 150, y: 212 + (i / 2) * 40), withAttributes: [.font: font])
            }
            ("Il paragrafo che segue la tabella." as NSString).draw(at: CGPoint(x: 60, y: 360), withAttributes: [.font: font])
        }
    }

    // MARK: - Annuncio e testo raggiungibile

    func test_elementIsAnnounced_asVisualResource_withTypeAndCaption() {
        let view = renderedView(flow())
        XCTAssertEqual(view.makeConfiguredCellForTesting(at: 2)?.accessibilityLabel,
                       "Risorsa visiva. Tabella: Il raccolto per stagione")
        XCTAssertEqual(view.makeConfiguredCellForTesting(at: 6)?.accessibilityLabel, "Risorsa visiva. Figura")
    }

    /// Il vincolo del giro: il testo della regione resta nel flusso, elemento per elemento, subito dopo l'annuncio.
    func test_textOfRegion_staysReachable_asOrdinaryElements() {
        let view = renderedView(flow())
        XCTAssertEqual(view.currentSegments.count, 8)
        XCTAssertEqual(view.makeConfiguredCellForTesting(at: 3)?.accessibilityLabel, "Stagione Raccolto Primavera Grano")
        XCTAssertEqual(view.makeConfiguredCellForTesting(at: 4)?.accessibilityLabel, "Estate Orzo Autunno Uva")
        // Tolti gli elementi «risorsa visiva», il flusso è quello del libro.
        XCTAssertEqual(view.currentSegments.filter { $0.visualResource == nil }.map { $0.id }, ["n0", "n1", "n2", "n3", "n4", "n5"])
    }

    // MARK: - Azioni

    func test_actions_extractAlways_skipOnlyWithText() {
        let view = renderedView(flow())
        XCTAssertEqual(Array(actionNames(view, 2).prefix(2)), ["Estrai come immagine", "Salta la risorsa"])
        let figure = actionNames(view, 6)
        XCTAssertEqual(figure.first, "Estrai come immagine")
        XCTAssertFalse(figure.contains("Salta la risorsa"), "una figura senza testo è un elemento solo: lo swipe la supera")
        XCTAssertFalse(actionNames(view, 3).contains("Estrai come immagine"), "il testo della regione non porta l'estrazione")
    }

    /// Il valore annunciato: la pagina vera della regione e, se la pagina ha più risorse, quale (annunci altrimenti
    /// identici di fila si distinguono: rilievo della revisione indipendente).
    func test_visualValue_saysThePage_andWhichOneOnThePage() {
        let view = renderedView(flow())
        XCTAssertEqual(view.visualResourceValue(forIndex: 2), "pagina 1 del file originale, 1 di 2")
        XCTAssertEqual(view.visualResourceValue(forIndex: 6), "pagina 1 del file originale, 2 di 2")
        XCTAssertNil(view.visualResourceValue(forIndex: 1), "nessun valore sugli altri elementi")
        XCTAssertEqual(view.makeConfiguredCellForTesting(at: 2)?.accessibilityValue, "pagina 1 del file originale, 1 di 2")
        XCTAssertNil(view.makeConfiguredCellForTesting(at: 1)?.accessibilityValue)
    }

    func test_skip_landsOnFirstElementAfterTheContainedText() {
        let view = renderedView(flow())
        XCTAssertEqual(view.indexAfterVisualResource(at: 2), 5)
        // Due risorse di fila sulla stessa regione di testo: si contano solo gli elementi di testo.
        let stacked = [visual(.table, id: "vr_p0_0", contained: 2), visual(.figure, id: "vr_p0_1", contained: 0),
                       seg("a", "uno due tre"), seg("b", "quattro cinque"), seg("c", "dopo")]
        XCTAssertEqual(renderedView(stacked).indexAfterVisualResource(at: 0), 4)
        // L'annuncio di un'altra risorsa DENTRO il testo della prima (il flusso ha fuso il testo di due tabelle): il
        // salto si ferma sull'annuncio, che non va perso.
        let nested = [visual(.table, id: "vr_p0_0", contained: 3), seg("a", "uno due tre"), visual(.table, id: "vr_p0_1", contained: 2),
                      seg("b", "quattro cinque"), seg("c", "sei sette"), seg("d", "dopo")]
        let view2 = renderedView(nested)
        XCTAssertEqual(view2.indexAfterVisualResource(at: 0), 2)
        XCTAssertEqual(view2.indexAfterVisualResource(at: 2), 5)
    }

    // MARK: - Rotori

    func test_tableAndImageRotors_onlyWhenPresent_andNavigate() {
        let view = renderedView(flow())
        let types = view.systemRotorTypesForTesting
        XCTAssertTrue(types.contains(.table))
        XCTAssertTrue(types.contains(.image))
        XCTAssertTrue(types.contains(.heading))
        XCTAssertEqual(view.nextVisualIndex(from: -1, kind: .table, forward: true), 2)
        XCTAssertEqual(view.nextVisualIndex(from: 2, kind: .figure, forward: true), 6)
        XCTAssertNil(view.nextVisualIndex(from: 6, kind: .figure, forward: true))
        XCTAssertEqual(view.nextVisualIndex(from: 7, kind: .table, forward: false), 2)
        let plain = renderedView(flow().filter { $0.visualResource == nil }).systemRotorTypesForTesting
        XCTAssertFalse(plain.contains(.table)); XCTAssertFalse(plain.contains(.image))
    }

    // MARK: - Segnalibri e sottolineature

    func test_bookmarkActions_workOnTheElement() {
        // Un documento con identità (senza, i segnalibri non si agganciano per costruzione) e senza segnalibri salvati.
        let docId = "vr-test-\(UUID().uuidString)"
        let vc = ContinuousReadingViewController(content: content(flow()), documentId: docId, signalPlayer: SilentSignalsForVisual())
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        window.rootViewController = vc; window.makeKeyAndVisible(); vc.loadViewIfNeeded(); vc.view.layoutIfNeeded()
        let names = (vc.textContainerForTesting.makeConfiguredCellForTesting(at: 2)?.accessibilityCustomActions ?? []).map { $0.name }
        XCTAssertTrue(names.contains("Estrai come immagine"))
        XCTAssertTrue(names.contains("Aggiungi segnalibro"), "il segnalibro si posa anche sulla risorsa visiva")
        window.isHidden = true
    }

    // MARK: - Consultazione Rapida

    func test_quickConsult_showsTheResource_beforeTheContentThatCarriesItsText() {
        let leaf = QuickConsultNode(role: "HEADING_1", depth: 1, title: "Capitolo primo", headingId: "n0",
                                    firstPage: 0, lastPage: 0, children: [], contentIds: ["n1", "n2", "n3", "n4", "n5"])
        let vc = ContinuousReadingViewController(content: content(flow()), documentId: "", quickConsultTree: [leaf],
                                                 signalPlayer: SilentSignalsForVisual())
        let items = vc.quickVisualItemsForTesting
        XCTAssertEqual(items.before["n2"]?.map { $0.label }, ["Tabella: Il raccolto per stagione"])
        XCTAssertEqual(items.before["n5"]?.map { $0.label }, ["Figura"])
        XCTAssertEqual(items.placedCount, 2)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        window.rootViewController = vc; window.makeKeyAndVisible(); vc.loadViewIfNeeded(); vc.view.layoutIfNeeded()
        vc.switchLayoutForTesting(to: .quick)
        let tree = try? XCTUnwrap(vc.quickConsultViewForTesting)
        tree?.expandForTesting(headingId: "n0")
        let labels = tree?.rowLabelsForTesting ?? []
        let table = labels.firstIndex(of: "Risorsa visiva. Tabella: Il raccolto per stagione")
        let text = labels.firstIndex(of: "Stagione Raccolto Primavera Grano")
        XCTAssertNotNil(table); XCTAssertNotNil(text)
        if let table, let text { XCTAssertEqual(table + 1, text, "la risorsa sta subito prima del contenuto col suo testo") }
        XCTAssertTrue(labels.contains("Risorsa visiva. Figura"))
        window.isHidden = true
    }

    /// Una risorsa seguita da un'intestazione (le tabelle in fondo a un allegato, prima della legge che segue) compare
    /// nella sua unità, in coda ai contenuti; in un'unità che ha solo risorse, l'unità diventa apribile e le mostra; in
    /// un'unità con sotto-unità, le sue risorse vengono prima dei figli (rilievo della revisione indipendente).
    func test_quickConsult_resourceFollowedByHeading_staysInItsUnit() {
        let segs = [seg("h1", "Allegato primo", role: "HEADING_2"),
                    seg("c1", "Il testo dell'allegato."),
                    visual(.table, id: "vr_p0_0", contained: 0),
                    seg("h2", "Allegato secondo", role: "HEADING_2"),
                    visual(.table, id: "vr_p0_1", contained: 0, bbox: [60, 400, 360, 500]),
                    seg("h3", "Parte terza", role: "HEADING_1"),
                    visual(.figure, id: "vr_p0_2", contained: 0, bbox: [60, 100, 360, 180]),
                    seg("h4", "Capo primo", role: "HEADING_2"),
                    seg("c4", "Il testo del capo.")]
        let leaf1 = QuickConsultNode(role: "HEADING_2", depth: 1, title: "Allegato primo", headingId: "h1",
                                     firstPage: 0, lastPage: 0, children: [], contentIds: ["c1"])
        let leaf2 = QuickConsultNode(role: "HEADING_2", depth: 1, title: "Allegato secondo", headingId: "h2",
                                     firstPage: 0, lastPage: 0, children: [], contentIds: [])
        let leaf4 = QuickConsultNode(role: "HEADING_2", depth: 2, title: "Capo primo", headingId: "h4",
                                     firstPage: 0, lastPage: 0, children: [], contentIds: ["c4"])
        let parte = QuickConsultNode(role: "HEADING_1", depth: 1, title: "Parte terza", headingId: "h3",
                                     firstPage: 0, lastPage: 0, children: [leaf4], contentIds: [])
        let placement = QuickVisualPlacement.build(segments: segs, tree: [leaf1, leaf2, parte])
        XCTAssertEqual(placement.placedCount, 3, "nessuna risorsa persa")
        XCTAssertEqual(placement.inUnit["h1"]?.count, 1)
        XCTAssertEqual(placement.inUnit["h2"]?.count, 1)
        XCTAssertEqual(placement.inUnit["h3"]?.count, 1)
        let tree = QuickConsultView(roots: [leaf1, leaf2, parte], nodeText: ["c1": "Il testo dell'allegato.", "c4": "Il testo del capo."],
                                    documentTitle: "Libro", visual: placement)
        tree.expandForTesting(headingId: "h1")
        tree.expandForTesting(headingId: "h2")
        tree.expandForTesting(headingId: "h3")
        let labels = tree.rowLabelsForTesting
        let a1 = labels.firstIndex(of: "Il testo dell'allegato.")
        XCTAssertNotNil(a1)
        if let a1 { XCTAssertEqual(labels[a1 + 1], "Risorsa visiva. Tabella", "in coda ai contenuti della sua unità") }
        XCTAssertEqual(labels.filter { $0 == "Risorsa visiva. Tabella" }.count, 2, "anche l'unità con sole risorse si apre e la mostra")
        // L'etichetta della «Parte» riassume anche i suoi figli: la riga del figlio è l'ultima che ne porta il titolo.
        let fig = labels.firstIndex(of: "Risorsa visiva. Figura"), capo = labels.lastIndex { $0.contains("Capo primo") }
        XCTAssertNotNil(fig); XCTAssertNotNil(capo)
        if let fig, let capo { XCTAssertLessThan(fig, capo, "prima delle sotto-unità") }
    }

    // MARK: - Estrai come immagine

    func test_crop_isOnlyTheRegion_at300dpi() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("vr_prova_\(UUID().uuidString).pdf")
        try syntheticPDF().write(to: url)
        defer { try? FileManager.default.removeItem(at: url); VisualResourceExport.cleanUp() }
        let payload = VisualResourcePayload(kind: .table, pageIndex: 0, bbox: [60, 200, 360, 320], containedElements: 2)
        guard case .success(let png) = VisualResourceExport.makePNG(sourcePDF: url, payload: payload) else {
            return XCTFail("ritaglio non riuscito")
        }
        XCTAssertEqual(png.lastPathComponent, "Tabella pagina 1.png")
        let image = try XCTUnwrap(UIImage(contentsOfFile: png.path))
        // 300 × 120 pt più 4 pt di margine per lato, a 300 punti per pollice → 1283 × 533 pixel: la regione, non la
        // pagina (420 × 595 pt).
        XCTAssertEqual(image.size.width * image.scale, 1283, accuracy: 2)
        XCTAssertEqual(image.size.height * image.scale, 533, accuracy: 2)
        // Una regione che copre quasi tutta la pagina non si ritaglia mai.
        let whole = VisualResourcePayload(kind: .figure, pageIndex: 0, bbox: [0, 0, 420, 595], containedElements: 0)
        XCTAssertEqual(VisualResourceExport.makePNG(sourcePDF: url, payload: whole).failure, .notCroppable)
        // Il file originale assente si dice in prosa.
        XCTAssertEqual(VisualResourceExport.makePNG(sourcePDF: URL(fileURLWithPath: "/nonesiste.pdf"), payload: payload).failure, .missingSource)
        XCTAssertFalse(VisualResourceExport.Failure.notCroppable.prose.isEmpty)
    }

    /// Due estrazioni ravvicinate non si tolgono il file a vicenda; alla chiusura di una condivisione si toglie solo il suo
    /// ritaglio (rilievo della revisione indipendente).
    func test_twoCrops_doNotRemoveEachOther() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("vr_due_\(UUID().uuidString).pdf")
        try syntheticPDF().write(to: url)
        defer { try? FileManager.default.removeItem(at: url); VisualResourceExport.cleanUp() }
        let payload = VisualResourcePayload(kind: .table, pageIndex: 0, bbox: [60, 200, 360, 320], containedElements: 2)
        guard case .success(let first) = VisualResourceExport.makePNG(sourcePDF: url, payload: payload),
              case .success(let second) = VisualResourceExport.makePNG(sourcePDF: url, payload: payload) else {
            return XCTFail("ritagli non riusciti")
        }
        XCTAssertNotEqual(first, second)
        XCTAssertTrue(FileManager.default.fileExists(atPath: first.path), "il primo ritaglio resta mentre si prepara il secondo")
        VisualResourceExport.cleanUp(first)
        XCTAssertFalse(FileManager.default.fileExists(atPath: first.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: second.path), "chiudere una condivisione non toglie l'altro ritaglio")
    }

    /// Le pagine ruotate non vanno al modello e non si ritagliano (righe, regioni e ritaglio sono nello spazio non
    /// ruotato della pagina; nei volumi della rete le pagine ruotate sono 0): rilievo della revisione indipendente.
    func test_rotatedPage_isExcludedFromTheModel_andNotCropped() throws {
        let doc = try XCTUnwrap(PDFDocument(data: syntheticTwoPagePDF()))
        doc.page(at: 1)?.rotation = 90
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("vr_ruotata_\(UUID().uuidString).pdf")
        XCTAssertTrue(doc.write(to: url))
        defer { try? FileManager.default.removeItem(at: url); VisualResourceExport.cleanUp() }
        let cg = try XCTUnwrap(CGPDFDocument(url as CFURL))
        XCTAssertEqual(cg.page(at: 2)?.rotationAngle, 90)
        XCTAssertEqual(VisualRegionDetector.excludingRotated([0, 1]) { cg.page(at: $0 + 1)?.rotationAngle ?? 0 }, [0])
        XCTAssertEqual(VisualRegionDetector.excludingRotated([0, 1]) { $0 == 1 ? -270 : 360 }, [0])
        let payload = VisualResourcePayload(kind: .table, pageIndex: 1, bbox: [60, 200, 360, 320], containedElements: 1)
        XCTAssertEqual(VisualResourceExport.makePNG(sourcePDF: url, payload: payload).failure, .rotatedPage)
        XCTAssertFalse(VisualResourceExport.Failure.rotatedPage.prose.isEmpty)
        let upright = VisualResourcePayload(kind: .table, pageIndex: 0, bbox: [60, 200, 360, 320], containedElements: 1)
        XCTAssertNil(VisualResourceExport.makePNG(sourcePDF: url, payload: upright).failure, "la pagina diritta si ritaglia")
    }

    private func syntheticTwoPagePDF() -> Data {
        UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 420, height: 595)).pdfData { ctx in
            for k in 0..<2 {
                ctx.beginPage()
                ("Pagina di prova \(k + 1)" as NSString).draw(at: CGPoint(x: 60, y: 70), withAttributes: [.font: UIFont.systemFont(ofSize: 12)])
                let cg = ctx.cgContext
                cg.setStrokeColor(UIColor.black.cgColor); cg.setLineWidth(1)
                cg.stroke(CGRect(x: 60, y: 200, width: 300, height: 120))
            }
        }
    }

    func test_extractAction_handsTheCropToTheShareSheet_fromTheArchive() throws {
        let docId = "vr-test-\(UUID().uuidString)"
        let archived = LibraryService.shared.archivedPDFURL(forDocumentId: docId)
        try FileManager.default.createDirectory(at: archived.deletingLastPathComponent(), withIntermediateDirectories: true)
        try syntheticPDF().write(to: archived)
        defer { try? FileManager.default.removeItem(at: archived); VisualResourceExport.cleanUp() }
        let vc = ContinuousReadingViewController(content: content(flow()), documentId: docId, signalPlayer: SilentSignalsForVisual())
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        window.rootViewController = vc; window.makeKeyAndVisible(); vc.loadViewIfNeeded(); vc.view.layoutIfNeeded()
        let shared = expectation(description: "foglio di condivisione")
        var file: URL?
        vc.shareSheetInterceptorForTesting = { _, url in file = url; shared.fulfill() }
        let action = try XCTUnwrap(vc.textContainerForTesting.makeConfiguredCellForTesting(at: 2)?.accessibilityCustomActions?
            .first { $0.name == "Estrai come immagine" })
        _ = action.actionHandler?(action)
        wait(for: [shared], timeout: 10)
        XCTAssertEqual(file?.pathExtension, "png")
        XCTAssertNotNil(file.flatMap { UIImage(contentsOfFile: $0.path) })
        window.isHidden = true
    }

    // MARK: - Offerta della lettura migliore

    func test_offer_listsTheVisualResourcesCure_onDevicesThatCanRecognise() {
        guard ReprocessOffer.visualResourcesAvailable else { return }
        // L'ultima cura è quella della catena (58 dal 2026-10-18: la ricucitura vicino alle glosse a margine); la cura delle
        // risorse visive (53) resta nell'elenco ed è l'ultima che l'iPad offre a una lettura arrivata dal Mac: la 55 il Mac la
        // fa da sempre, la 56, la 57 e la 58 il Mac le porta con una lettura nuova (rielaborare sull'iPad toglierebbe
        // l'innesto del Mac; decisione 1 del maintainer, 2026-10-17).
        XCTAssertEqual(ReprocessOffer.policy.latestCureBuild, ProcessingChain.cureLevel)
        XCTAssertEqual(ReprocessOffer.policy.latestCureBuildForMacReadings, 53)
        XCTAssertTrue(ProcessingChain.curesFromTheMacOnly.isSuperset(of: [56, 57, 58]), "decisione 1: le cure delle note dal Mac")
        XCTAssertTrue(ReprocessOffer.isNotOfferedToMacReadings(55) && ReprocessOffer.isNotOfferedToMacReadings(56)
                      && ReprocessOffer.isNotOfferedToMacReadings(57) && ReprocessOffer.isNotOfferedToMacReadings(58))
        XCTAssertTrue(ReprocessOffer.cures.contains { $0.build == ProcessingChain.cureLevel },
                      "la cura dell'ultima build ha il suo testo in «Cosa cambia»")
        XCTAssertFalse(ReprocessOffer.isNotOfferedToMacReadings(53))
        XCTAssertTrue(ReprocessOffer.cures.contains { $0.build == 53 && $0.text.contains("risorse visive") })
    }

    /// Decisione 1 del maintainer (giro «pulizia e rifinitura finale del capitolo note», 2026-10-17): un testo normativo già
    /// importato riceve le cure della SUA catena (i pezzi nuovi delle note), con un testo che parla di lui; mai quelle dei
    /// soli PDF, e nessun discorso sul lettore di sistema.
    func test_offer_reachesNormativeTexts_withTheirOwnCures() {
        XCTAssertEqual(ReprocessOffer.latestCureForAknActs, ProcessingChain.curesForAknActs.filter { $0 <= ProcessingChain.cureLevel }.max())
        XCTAssertNotNil(ReprocessOffer.latestCureForAknActs)
        func akn(_ build: String) -> ArchivedDocument {
            ArchivedDocument(id: "a", title: "t", sourceFileName: "t.xml", importedAt: Date(), sourcePageCount: 0,
                             sourceKind: "akn", processedSystemVersion: SystemGeneration.current, processedAppBuild: build)
        }
        let old = akn("55")
        XCTAssertEqual(ReprocessOffer.policy.reason(for: old, currentSystemVersion: SystemGeneration.current, currentAppBuild: "999"), .cure)
        let text = ReprocessOffer.whatChanges(old, reason: .cure)
        XCTAssertTrue(text.contains("testo normativo") && text.contains("pezzi"), text)
        XCTAssertFalse(text.contains("pagina") || text.contains("lettore di sistema"), text)
        // importato con la 56 (i pezzi nuovi già fatti): riceve la cura 57 della sua catena, detta da sola
        let mid = akn("56")
        XCTAssertEqual(ReprocessOffer.latestCureForAknActs, 57)
        XCTAssertEqual(ReprocessOffer.policy.reason(for: mid, currentSystemVersion: SystemGeneration.current, currentAppBuild: "999"), .cure)
        let midText = ReprocessOffer.whatChanges(mid, reason: .cure)
        XCTAssertTrue(midText.contains("elenco") && midText.contains("non ha note di questo tipo"), midText)
        XCTAssertFalse(midText.contains("di solito a fine frase") || midText.contains("pagina"), midText)
        // l'esito senza le pagine del file originale: vicino al punto di prima, mai «inizio della pagina»
        var report = ReanchorReport()
        report.bookmarksRelocated = 2
        report.bookmarksOrphaned = 1
        let result = ReprocessOffer.resultText(report, positionApproximate: true, hasOriginalPages: false)
        XCTAssertTrue(result.contains("vicino al punto da cui venivano") && result.contains("vicino al punto di prima"), result)
        XCTAssertFalse(result.contains("pagina"), result)
        let pdfResult = ReprocessOffer.resultText(report, positionApproximate: true)
        XCTAssertTrue(pdfResult.contains("all'inizio della pagina da cui venivano") && pdfResult.contains("dall'inizio della stessa pagina"),
                      pdfResult)
        let current = akn(String(ReprocessOffer.latestCureForAknActs ?? 0))
        XCTAssertNil(ReprocessOffer.policy.reason(for: current, currentSystemVersion: SystemGeneration.current, currentAppBuild: "999"),
                     "con i pezzi nuovi già fatti, nessuna offerta")
        XCTAssertEqual(ReprocessOffer.whatChanges(current, reason: .cure), "")
    }
}

// MARK: - Protezione della memoria (giro «costruzione della linea Mac», 2026-10-16)

/// Il riconoscimento di tabelle e figure quando il modello d'impaginazione non si carica o la memoria scarseggia:
/// l'elaborazione prosegue senza risorse visive, l'esito lo dice con una ragione da riprovare, il libro si segna e
/// l'offerta di rielaborazione glielo propone. Il fallimento si SIMULA con `VisualRegionDetector.testing`.
final class VisualResourcesMemoryTests: XCTestCase {

    private var service: LibraryService { .shared }
    private var created: [String] = []
    private var files: [URL] = []

    override func tearDown() {
        VisualRegionDetector.testing = .init()
        for id in created { service.deleteFiles(forDocumentId: id); service.store.deleteDocumentFromArchive(id: id) }
        for f in files { try? FileManager.default.removeItem(at: f) }
        created = []; files = []
        super.tearDown()
    }

    /// Dieci pagine di testo neutro; la decima ha una tabella a filetti: il prefiltro manda al modello solo quella.
    private func tenPagesOneTable() throws -> URL {
        let data = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 420, height: 595)).pdfData { ctx in
            let font = UIFont.systemFont(ofSize: 12)
            for p in 0..<10 {
                ctx.beginPage()
                for k in 0..<12 {
                    ("Riga \(k + 1) della pagina \(p + 1): il mulino sul fiume e le chiuse aperte di notte." as NSString)
                        .draw(at: CGPoint(x: 40, y: 40 + k * 18), withAttributes: [.font: font])
                }
                if p == 9 {
                    let cg = ctx.cgContext
                    cg.setStrokeColor(UIColor.black.cgColor); cg.setLineWidth(1)
                    for r in 0...5 { cg.move(to: CGPoint(x: 40, y: 300 + r * 40)); cg.addLine(to: CGPoint(x: 380, y: 300 + r * 40)) }
                    for c in 0...3 { cg.move(to: CGPoint(x: 40 + c * 113, y: 300)); cg.addLine(to: CGPoint(x: 40 + c * 113, y: 500)) }
                    cg.strokePath()
                    for (i, w) in ["Stagione", "Raccolto", "Resa", "Primavera", "Grano", "Alta", "Estate", "Orzo", "Media"].enumerated() {
                        (w as NSString).draw(at: CGPoint(x: 50 + (i % 3) * 113, y: 312 + (i / 3) * 40), withAttributes: [.font: font])
                    }
                }
            }
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("memoria_\(UUID().uuidString).pdf")
        try data.write(to: url)
        files.append(url)
        return url
    }

    func test_modelloNonCaricato_eMemoriaScarsa_ilRiconoscimentoSalta_eLoDice() throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("il modello d'impaginazione richiede iOS 17") }
        let url = try tenPagesOneTable()
        let normal = VisualRegionDetector.detect(pdfURL: url)
        XCTAssertEqual(normal.modelPages, [9], "il prefiltro manda al modello solo la pagina con la tabella")
        XCTAssertNil(normal.skippedReason)
        XCTAssertEqual(normal.analyzedPages, 1)

        VisualRegionDetector.testing = .init(failModelLoad: true)
        let failed = VisualRegionDetector.detect(pdfURL: url)
        XCTAssertEqual(failed.skippedReason, VisualRegionDetector.modelUnavailableReason)
        XCTAssertEqual(failed.analyzedPages, 0); XCTAssertTrue(failed.candidates.isEmpty)
        XCTAssertTrue(VisualRegionDetector.retryableSkipReasons.contains(failed.skippedReason!))

        VisualRegionDetector.testing = .init(availableMemoryBytes: 200 * 1024 * 1024)
        let low = VisualRegionDetector.detect(pdfURL: url)
        XCTAssertEqual(low.skippedReason, VisualRegionDetector.memoryBeforeLoadReason, "sotto la soglia il modello non si carica")
        XCTAssertEqual(low.analyzedPages, 0)

        VisualRegionDetector.testing = .init(availableMemoryBytes: 2_000 * 1024 * 1024, availableMemoryDuringModelBytes: 100 * 1024 * 1024)
        let during = VisualRegionDetector.detect(pdfURL: url)
        XCTAssertEqual(during.skippedReason, VisualRegionDetector.memoryDuringModelReason, "fra una pagina e l'altra il modello si ferma")
        XCTAssertEqual(during.analyzedPages, 0)

        VisualRegionDetector.testing = .init(availableMemoryBytes: 2_000 * 1024 * 1024)
        XCTAssertNil(VisualRegionDetector.detect(pdfURL: url).skippedReason, "con memoria sufficiente il modello gira")
    }

    /// Il percorso dell'app: l'elaborazione senza modello PROSEGUE (nessuna chiusura, lettura completa), il libro si
    /// segna, l'offerta di rielaborazione glielo propone con la spiegazione; una rielaborazione riuscita toglie il segno.
    func test_elaborazioneSenzaModello_prosegue_segnaIlLibro_eLOffertaRiprova() throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("il modello d'impaginazione richiede iOS 17") }
        let url = try tenPagesOneTable()
        func process() throws -> (outcome: DocumentProcessor.Outcome, missing: String?) {
            let processor = DocumentProcessor()
            let done = expectation(description: "elaborazione")
            var out: DocumentProcessor.Outcome?
            processor.process(fileURL: url, sourceName: "prova.pdf", onProgress: { _ in }) { out = $0; done.fulfill() }
            wait(for: [done], timeout: 120)
            return (try XCTUnwrap(out), processor.visualResourcesMissingReason)
        }
        VisualRegionDetector.testing = .init(failModelLoad: true)
        let first = try process()
        guard case .success(_, let content, _) = first.outcome else { return XCTFail("l'elaborazione deve proseguire") }
        XCTAssertFalse(content.pages.flatMap { $0.segments }.isEmpty, "la lettura c'è, intera, senza risorse visive")
        XCTAssertEqual(first.missing, VisualRegionDetector.modelUnavailableReason)

        let doc = service.store.addDocument(title: "Prova memoria", sourceFileName: "prova.pdf", sourcePageCount: 10)
        created.append(doc.id)
        service.store.recordProcessed(id: doc.id, systemVersion: SystemGeneration.current, appBuild: SystemGeneration.appBuild,
                                      visualResourcesSkipped: first.missing)
        let marked = try XCTUnwrap(service.store.document(id: doc.id))
        XCTAssertEqual(marked.visualResourcesSkipped, VisualRegionDetector.modelUnavailableReason)
        if ReprocessOffer.visualResourcesAvailable {
            XCTAssertEqual(ReprocessOffer.policy.reason(for: marked, currentSystemVersion: SystemGeneration.current,
                                                        currentAppBuild: SystemGeneration.appBuild), .cure,
                           "anche elaborato da questa build, il libro riceve l'offerta di riprovare")
            XCTAssertTrue(ReprocessOffer.whatChanges(marked, reason: .cure).contains("tabelle e figure"))
        }

        VisualRegionDetector.testing = .init()
        let second = try process()
        XCTAssertNil(second.missing)
        service.store.recordProcessed(id: doc.id, systemVersion: SystemGeneration.current, appBuild: SystemGeneration.appBuild,
                                      visualResourcesSkipped: second.missing)
        let cleared = try XCTUnwrap(service.store.document(id: doc.id))
        XCTAssertNil(cleared.visualResourcesSkipped)
        XCTAssertNil(ReprocessOffer.policy.reason(for: cleared, currentSystemVersion: SystemGeneration.current,
                                                  currentAppBuild: SystemGeneration.appBuild), "riuscito il riconoscimento, nessuna offerta")
    }
}

private extension Result {
    var failure: Failure? { if case .failure(let f) = self { return f }; return nil }
}

/// Segnali muti per i test (nessun suono).
private final class SilentSignalsForVisual: SignalPlaying {
    func play(_ signal: AudioSignal) {}
    func playLooping(_ signal: AudioSignal) {}
    func stop(_ signal: AudioSignal) {}
}
