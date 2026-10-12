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
        XCTAssertEqual(items["n2"]?.map { $0.label }, ["Tabella: Il raccolto per stagione"])
        XCTAssertEqual(items["n5"]?.map { $0.label }, ["Figura"])
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
        XCTAssertEqual(ReprocessOffer.policy.latestCureBuild, 53)
        XCTAssertTrue(ReprocessOffer.cures.contains { $0.build == 53 && $0.text.contains("risorse visive") })
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
