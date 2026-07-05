//
//  ContinuousReadingViewTests.swift
//  ScaboAppTests
//
//  Rete di verifica della reading view "Lettura Continua" nel modello VERTICALE NATIVO
//  RICICLANTE (Fase 1 finestra scorrevole). Gira ON-SIMULATOR (iPhone 16 / iOS 26.5).
//
//  ── Cosa è verificabile QUI (e cosa NO) ─────────────────────────────────────────
//
//  Il Simulator NON riproduce l'esperienza VoiceOver reale, e — punto nuovo del modello
//  finestrato — SENZA una finestra visibile la collection non materializza celle, quindi
//  `exposedAccessibilityElements` (le celle VISIBILI) è un SOTTOINSIEME, non tutto il
//  documento. Il "tutto il documento in ordine" si verifica sul MODELLO (`currentSegments`,
//  `renderedSegmentCount`), la RESA per-segmento su una cella configurata a mano
//  (`makeConfiguredCellForTesting`), e gli earcon simulando il fuoco (`cellDidBecomeFocused`).
//  Resta da certificare SUL DISPOSITIVO (TestFlight, con VoiceOver): che lo swipe scorra
//  fluido e la memoria crolli. Questi test NON lo dimostrano.
//

import PDFKit
import UIKit
import XCTest

@testable import ScaboApp
import ScaboCore

final class ContinuousReadingViewTests: XCTestCase {

    // MARK: - Helpers

    private func makeView(width: CGFloat = 393, height: CGFloat = 852) -> ContinuousReadingView {
        ContinuousReadingView(frame: CGRect(x: 0, y: 0, width: width, height: height))
    }

    private func bodySegment(_ id: String, _ text: String, role: String = "BODY") -> ContentSegment {
        ContentSegment(id: id, role: role, text: text, lengthCategory: "", acousticIntro: "")
    }

    private func manyBodySegments(_ count: Int) -> [ContentSegment] {
        (0..<count).map { i in
            bodySegment("n\(i)", "Paragrafo numero \(i), con testo sufficiente a occupare alcune righe.")
        }
    }

    private func multiPageBody() -> (content: PaginatedContent, orderedTexts: [String], ids: [String]) {
        let all = [
            bodySegment("n0", "Capitolo Primo", role: "HEADING_1"),
            bodySegment("n1", "Primo paragrafo del corpo."),
            bodySegment("n2", "Secondo paragrafo del corpo."),
            bodySegment("n3", "Terzo paragrafo."),
            bodySegment("n4", "Quarto paragrafo del corpo."),
            bodySegment("n5", "Quinto paragrafo."),
            bodySegment("n6", "Sezione Seconda", role: "HEADING_2"),
            bodySegment("n7", "Sesto paragrafo del corpo."),
            bodySegment("n8", "Settimo e ultimo paragrafo."),
        ]
        let content = PaginatedContent(
            pages: [ContentPage(pageNumber: 1, segments: all)], totalSegments: all.count)
        return (content, all.map { ContinuousReadingView.spokenText(for: $0) }, all.map { $0.id })
    }

    /// La cella riciclante configurata per l'indice dato: riflette la resa (testo, parlato, tratto).
    private func cell(_ view: ContinuousReadingView, _ index: Int) -> SegmentCell {
        guard let c = view.makeConfiguredCellForTesting(at: index) else {
            fatalError("nessuna cella configurabile all'indice \(index)")
        }
        return c
    }

    // MARK: - 1. Il MODELLO porta tutti i segmenti in ordine di lettura

    func test_render_modelHoldsAllSegmentsInReadingOrder() {
        let view = makeView()
        let (content, _, ids) = multiPageBody()
        view.render(content)
        view.layoutIfNeeded()

        XCTAssertEqual(view.renderedSegmentCount, content.totalSegments, "9 segmenti → 9 nel modello")
        XCTAssertEqual(view.currentSegments.map { $0.id }, ids, "ordine di lettura preservato nel modello")
    }

    // MARK: - 2. Finestra: gli elementi ESPOSTI sono celle in ordine, sottoinsieme del modello

    func test_exposedElementsAreSegmentCells_inReadingOrder_subsetOfModel() {
        let view = makeView(width: 320, height: 480)
        let segs = manyBodySegments(60)
        view.render(segs)
        // Serve una finestra reale perché la collection materializzi celle.
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.addSubview(view)
        window.makeKeyAndVisible()
        view.layoutIfNeeded()

        let exposed = view.exposedAccessibilityElements
        XCTAssertFalse(exposed.isEmpty, "con una finestra visibile alcune celle sono materializzate")
        XCTAssertLessThan(exposed.count, segs.count,
                          "la FINESTRA espone solo un sottoinsieme (celle visibili), non tutto il documento")
        // Ogni elemento esposto è una cella-segmento foglia (nessun sotto-container per-pagina).
        for element in exposed {
            let c = element as? SegmentCell
            XCTAssertNotNil(c, "ogni elemento è una cella-segmento")
            XCTAssertTrue(c?.isAccessibilityElement ?? false)
        }
        // Le celle esposte sono un PREFISSO in ordine di lettura (partiamo da cima).
        let exposedIds = exposed.compactMap { ($0 as? SegmentCell)?.segment?.id }
        XCTAssertEqual(exposedIds, Array(segs.prefix(exposedIds.count)).map { $0.id },
                       "le celle visibili seguono l'ordine di lettura dall'inizio")
    }

    // MARK: - 3. Ogni segmento ha resa accessibile non vuota

    func test_everySegmentHasNonEmptyAccessibilityLabel() {
        let view = makeView()
        let (content, _, _) = multiPageBody()
        view.render(content)
        for i in view.currentSegments.indices {
            XCTAssertFalse((cell(view, i).accessibilityLabel ?? "").isEmpty,
                           "un segmento senza resa accessibile è bug critico")
        }
    }

    // MARK: - 4. La resa parlata per-segmento = testo inteso (rete A)

    func test_perSegmentSpokenLabelMatchesIntended() {
        let view = makeView()
        let (content, texts, _) = multiPageBody()
        view.render(content)
        for (i, expected) in texts.enumerated() {
            XCTAssertEqual(cell(view, i).accessibilityLabel, expected)
        }
    }

    // MARK: - 5. Tratto header per heading, non per corpo

    func test_headingRolesCarryHeaderTraitBodyDoesNot() {
        let view = makeView()
        view.render([
            bodySegment("h1", "Titolo", role: "HEADING_1"),
            bodySegment("b1", "Corpo del testo."),
            bodySegment("sd", "Sezione", role: SECTION_DIVIDER_ROLE),
        ])
        XCTAssertTrue(cell(view, 0).accessibilityTraits.contains(.header), "HEADING_1 è intestazione")
        XCTAssertFalse(cell(view, 1).accessibilityTraits.contains(.header), "il corpo NON è intestazione")
        XCTAssertTrue(cell(view, 2).accessibilityTraits.contains(.header), "SECTION_DIVIDER è intestazione")
    }

    // MARK: - 6. Re-render sostituisce il modello (nessun residuo)

    func test_renderReplacesPreviousContentWithoutLeftovers() {
        let view = makeView()
        view.render([bodySegment("a", "Vecchio uno."), bodySegment("b", "Vecchio due.")])
        XCTAssertEqual(view.renderedSegmentCount, 2)
        view.render([bodySegment("x", "Nuovo uno."), bodySegment("y", "Nuovo due."), bodySegment("z", "Nuovo tre.")])
        XCTAssertEqual(view.renderedSegmentCount, 3, "il re-render sostituisce, non accumula")
        XCTAssertEqual(view.currentSegments.map { $0.id }, ["x", "y", "z"], "nessun residuo del precedente")
    }

    // MARK: - 7. Documento vuoto: zero elementi, nessun crash

    func test_emptyDocumentExposesZeroElements() {
        let view = makeView()
        view.render(PaginatedContent(pages: [ContentPage(pageNumber: 1, segments: [])], totalSegments: 0))
        view.layoutIfNeeded()
        XCTAssertEqual(view.renderedSegmentCount, 0)
        XCTAssertTrue(view.exposedAccessibilityElements.isEmpty)
    }

    // MARK: - 8. Non è un container-foglia; nessun sotto-container per-pagina

    func test_containerIsNotALeaf_noPerPageContainer() {
        let view = makeView()
        view.render(manyBodySegments(12))
        view.layoutIfNeeded()
        XCTAssertFalse(view.isDocumentContainerAnAccessibilityElement, "la view del testo non è una foglia")
        for element in view.exposedAccessibilityElements {
            XCTAssertNil((element as? SegmentCell)?.accessibilityElements, "una cella foglia non espone sotto-elementi")
        }
    }

    // MARK: - 9. End-to-end da PDF sintetico: corpo E note (lette), in ordine

    func test_endToEnd_syntheticPdf_rendersBodyIncludingNotesInOrder() throws {
        let pdfURL = Self.makeSyntheticSamplePDF()
        addTeardownBlock { try? FileManager.default.removeItem(at: pdfURL) }

        let extraction = try PdfKitExtractor().extract(fromUri: pdfURL.absoluteString)
        let raw = buildDocumentFromPdf(extraction, sourceName: "campione_sintetico.pdf")
        XCTAssertFalse(raw.structure.isEmpty, "la catena deve produrre struttura")
        let document = bindAndPlaceNotes(raw, extraction).document

        let content = try ContinuousBodyBuilder.bodyPaginatedContent(from: document)
        let view = makeView()
        view.render(content)
        view.layoutIfNeeded()

        let segs = view.currentSegments
        XCTAssertFalse(segs.isEmpty, "il corpo deve produrre elementi")
        let texts = segs.map { $0.text }

        // Il titolo emerge come heading (tratto header) tra i segmenti.
        let headingIdx = segs.firstIndex { ContinuousReadingView.isHeadingRole($0.role) && $0.text.contains("Capitolo Primo") }
        XCTAssertNotNil(headingIdx, "il titolo grande è reso come intestazione")
        XCTAssertTrue(texts.contains { $0.contains("creditore") }, "il corpo è reso")
        XCTAssertTrue(texts.contains { $0.contains("1218") }, "le note sono lette (non più escluse)")
        XCTAssertTrue(segs.contains { $0.role == "NOTE" || $0.role == "EDITORIAL_NOTE" }, "esiste una nota letta")

        if let titleIdx = texts.firstIndex(where: { $0.contains("Capitolo Primo") }),
           let bodyIdx = texts.firstIndex(where: { $0.contains("creditore") }) {
            XCTAssertLessThan(titleIdx, bodyIdx, "il titolo precede il corpo nell'ordine")
        } else {
            XCTFail("titolo e corpo attesi tra gli elementi resi")
        }
    }

    // MARK: - 10. Fixture reale patriarca_benazzo (skip se assente)

    func test_realFixture_patriarca_rendersBodyInReadingOrder() throws {
        let fixture = Self.privateFixtureURL("patriarca_benazzo")
        try XCTSkipUnless(
            FileManager.default.fileExists(atPath: fixture.path),
            "Fixture privato assente: \(fixture.path) — vedi pipeline/tests/fixtures/README.md")
        let sample = try XCTUnwrap(Self.sampledPDF(at: fixture, from: 40, count: 6), "campionamento fallito")
        addTeardownBlock { try? FileManager.default.removeItem(at: sample) }

        let extraction = try PdfKitExtractor().extract(fromUri: sample.absoluteString)
        let document = buildDocumentFromPdf(extraction, sourceName: "patriarca_benazzo.pdf")
        let bodySegments = ContinuousBodyBuilder.bodySegments(from: document)
        let content = try ContinuousBodyBuilder.bodyPaginatedContent(from: document)

        let view = makeView()
        view.render(content)
        view.layoutIfNeeded()

        XCTAssertGreaterThan(view.renderedSegmentCount, 0, "patriarca (monocolonna) deve produrre corpo")
        XCTAssertEqual(view.currentSegments.map { $0.id }, bodySegments.map { $0.id },
                       "ordine di lettura preservato dal modello alla view")
        for i in view.currentSegments.indices {
            XCTAssertFalse((cell(view, i).accessibilityLabel ?? "").isEmpty)
        }
    }

    // MARK: - 11. Granularità del corpo → alimenta il modello continuo

    func test_discursiveBodyIsGranularized_feedsModel() throws {
        let longBody = (1...30).map { "Questa e la frase numero \($0) del corpo discorsivo di prova." }
            .joined(separator: " ")
        let doc = discursiveDoc(longBody: longBody)
        let segs = ContinuousBodyBuilder.bodySegments(from: doc)  // target default 400
        let headings = segs.filter { $0.role == "HEADING_1" }
        let bodies = segs.filter { $0.role == "BODY" }
        XCTAssertEqual(headings.count, 1, "il titolo resta un'unica intestazione")
        XCTAssertGreaterThan(bodies.count, 1, "il corpo lungo è granularizzato in più blocchi")

        let content = try ContinuousBodyBuilder.bodyPaginatedContent(from: doc)
        let view = makeView(width: 320, height: 240)
        view.render(content)
        view.layoutIfNeeded()
        XCTAssertEqual(view.renderedSegmentCount, segs.count, "un elemento per blocco granularizzato")
        XCTAssertEqual(view.currentSegments.map { $0.id }, segs.map { $0.id }, "ordine preservato")
    }

    private func discursiveDoc(longBody: String) -> ScabopdfDocument {
        ScabopdfDocument(
            schema_version: "0.7.0",
            document_id: "discorsivo",
            metadata: DocumentMetadata(pages_pdf: 1, page_size_pt: [595, 842], source_pdf_filename: "x.pdf"),
            profile: DocumentProfileDict(
                profile_id: "generic", editorial_family: "generic", genre: "unknown", confidence: 0.05),
            structure: [
                NodeDict(id: "node_0", type: .HEADING_1, page_index: 0, text: "Capitolo Primo", level: 1),
                NodeDict(id: "node_1", type: .BODY, page_index: 0, text: longBody),
            ])
    }

    // ════════════════════════════════════════════════════════════════════════════
    // SEGNALI ACUSTICI DELLE NOTE (§ 10.4/§ 10.5) — MAPPATURA + FUOCO
    // ════════════════════════════════════════════════════════════════════════════

    private func noteSegment(_ id: String, _ text: String, length: String, intro: String = "Nota.") -> ContentSegment {
        ContentSegment(id: id, role: "NOTE", text: text, lengthCategory: length, acousticIntro: intro)
    }

    func test_noteSignal_mapsSixRegimesInOrder() {
        XCTAssertEqual(AudioSignal.noteSignal(forLengthCategory: "MICRO"), .noteMicro)
        XCTAssertEqual(AudioSignal.noteSignal(forLengthCategory: "SHORT"), .noteShort)
        XCTAssertEqual(AudioSignal.noteSignal(forLengthCategory: "MEDIUM"), .noteMedium)
        XCTAssertEqual(AudioSignal.noteSignal(forLengthCategory: "LONG"), .noteLong)
        XCTAssertEqual(AudioSignal.noteSignal(forLengthCategory: "VERY_LONG"), .noteVeryLong)
        XCTAssertEqual(AudioSignal.noteSignal(forLengthCategory: "MEGA"), .noteMega)
        XCTAssertNil(AudioSignal.noteSignal(forLengthCategory: ""))
        XCTAssertNil(AudioSignal.noteSignal(forLengthCategory: "BOGUS"))
    }

    func test_everyAudioSignalAssetIsBundled() {
        let bundle = Bundle(for: SignalPlayer.self)
        for signal in AudioSignal.allCases {
            XCTAssertNotNil(bundle.url(forResource: signal.resourceName, withExtension: "mp3"),
                            "asset mancante dal bundle: \(signal.resourceName).mp3")
        }
    }

    func test_realNoteWithRegime_playsRegimeSignalOnFocus_replacesVerbalIntro() {
        let view = makeView()
        let spy = SignalPlayerSpy()
        view.signalPlayer = spy
        view.render([noteSegment("nt", "12. Cfr. art. 1218 c.c.", length: "MEDIUM")])
        // Il segnale SOSTITUISCE "Nota.": l'etichetta parlata è il solo testo.
        XCTAssertEqual(cell(view, 0).accessibilityLabel, "12. Cfr. art. 1218 c.c.")
        XCTAssertFalse((cell(view, 0).accessibilityLabel ?? "").hasPrefix("Nota"))
        XCTAssertTrue((cell(view, 0).accessibilityLabel ?? "").contains("1218"))

        XCTAssertTrue(spy.played.isEmpty, "nessun segnale prima del fuoco")
        view.cellDidBecomeFocused(index: 0, segment: view.currentSegments[0])
        XCTAssertEqual(spy.played, [.noteMedium], "all'ingresso suona il segnale del regime MEDIUM")
    }

    func test_realNotes_eachRegimeMapsToItsSignal() {
        for (regime, expected): (String, AudioSignal) in [("MICRO", .noteMicro), ("SHORT", .noteShort), ("MEGA", .noteMega)] {
            let view = makeView()
            let spy = SignalPlayerSpy()
            view.signalPlayer = spy
            view.render([noteSegment("n", "Testo nota.", length: regime)])
            view.cellDidBecomeFocused(index: 0, segment: view.currentSegments[0])
            XCTAssertEqual(spy.played, [expected], "regime \(regime) → \(expected)")
        }
    }

    func test_collapsedHeadingNote_emptyIntro_playsNoSignal_keepsText() {
        let view = makeView()
        let spy = SignalPlayerSpy()
        view.signalPlayer = spy
        view.render([noteSegment("ch", "TITOLO DI SEZIONE", length: "SHORT", intro: "")])
        view.cellDidBecomeFocused(index: 0, segment: view.currentSegments[0])
        XCTAssertTrue(spy.played.isEmpty, "una falsa nota (testatina collassata) non ha segnale")
        XCTAssertEqual(cell(view, 0).accessibilityLabel, "TITOLO DI SEZIONE")
    }

    func test_bodyAndHeading_playNoSignalOnFocus() {
        let view = makeView()
        let spy = SignalPlayerSpy()
        view.signalPlayer = spy
        view.render([bodySegment("h", "Titolo", role: "HEADING_1"), bodySegment("b", "Corpo del testo.")])
        for i in view.currentSegments.indices { view.cellDidBecomeFocused(index: i, segment: view.currentSegments[i]) }
        XCTAssertTrue(spy.played.isEmpty, "corpo e intestazioni non hanno segnale-nota")
    }

    func test_editorialNote_keepsVerbalIntro_noSignal() {
        let view = makeView()
        let spy = SignalPlayerSpy()
        view.signalPlayer = spy
        view.render([ContentSegment(id: "e", role: "EDITORIAL_NOTE", text: "Avvertenza redazionale.",
                                    lengthCategory: "", acousticIntro: "Nota editoriale.")])
        view.cellDidBecomeFocused(index: 0, segment: view.currentSegments[0])
        XCTAssertTrue(spy.played.isEmpty, "la nota editoriale non ha segnale di regime")
        XCTAssertEqual(cell(view, 0).accessibilityLabel, "Nota editoriale. Avvertenza redazionale.")
    }

    // MARK: - Earcon di blocco bibliografico (ruolo LETTERATURA)

    private func letteratura(_ id: String, _ text: String) -> ContentSegment {
        ContentSegment(id: id, role: SemanticCategory.LETTERATURA.rawValue, text: text, lengthCategory: "", acousticIntro: "")
    }

    private func focusAll(_ view: ContinuousReadingView) {
        for i in view.currentSegments.indices { view.cellDidBecomeFocused(index: i, segment: view.currentSegments[i]) }
    }

    func test_bibliography_earconAtBlockEntry_notPerVoice() {
        let view = makeView()
        let spy = SignalPlayerSpy()
        view.signalPlayer = spy
        view.render([
            bodySegment("b0", "Corpo prima della bibliografia."),
            letteratura("l1", "BENVENUTI, Giustizia amministrativa, 1970."),
            letteratura("l2", "GIANNINI, Diritto amministrativo, 1993."),
            letteratura("l3", "SORDI, Giustizia e amministrazione, 1985."),
            bodySegment("b1", "Corpo dopo la bibliografia."),
            letteratura("l4", "FALCON, Lezioni, cit., 59."),
        ])
        focusAll(view)
        XCTAssertEqual(spy.played, [.bibliography, .bibliography], "un earcon per blocco (ingresso), non per voce")
    }

    func test_bibliography_noEarconWithinBlock_reentryReplays() {
        let view = makeView()
        let spy = SignalPlayerSpy()
        view.signalPlayer = spy
        view.render([letteratura("l1", "BENVENUTI, 1970."), letteratura("l2", "GIANNINI, 1993."), bodySegment("b", "Corpo.")])
        let segs = view.currentSegments
        view.cellDidBecomeFocused(index: 0, segment: segs[0])   // ingresso → suona
        view.cellDidBecomeFocused(index: 1, segment: segs[1])   // voce adiacente → NO
        XCTAssertEqual(spy.played, [.bibliography])
        view.cellDidBecomeFocused(index: 2, segment: segs[2])   // esce
        view.cellDidBecomeFocused(index: 1, segment: segs[1])   // rientra → risuona
        XCTAssertEqual(spy.played, [.bibliography, .bibliography], "rientro nel blocco → earcon di nuovo")
    }

    func test_bibliography_spokenIsTextOnly_noVerbalAnnounce() {
        let view = makeView()
        view.render([letteratura("l1", "BENVENUTI, Giustizia amministrativa, 1970.")])
        XCTAssertEqual(cell(view, 0).accessibilityLabel, "BENVENUTI, Giustizia amministrativa, 1970.")
    }

    func test_bibliography_bodyAndNoteDoNotPlayBibliographyEarcon() {
        let view = makeView()
        let spy = SignalPlayerSpy()
        view.signalPlayer = spy
        view.render([bodySegment("b", "Corpo."), noteSegment("n", "12. Cfr. art. 1.", length: "SHORT")])
        focusAll(view)
        XCTAssertFalse(spy.played.contains(.bibliography), "corpo e note non innescano l'earcon bibliografia")
    }

    // MARK: - Memory refresh (§ 7.4/§ 7.5): rinfresco anteposto, contenuto integro

    func test_spokenComposition_includesMemoryRefresh() {
        let seg = ContentSegment(id: "n", role: "NOTE", text: "contenuto della nota.", lengthCategory: "LONG",
                                 acousticIntro: "Nota lunga.", memoryRefresh: "il contesto del richiamo")
        XCTAssertEqual(ContinuousReadingView.spokenText(for: seg),
                       "Nota lunga. il contesto del richiamo contenuto della nota.")
        XCTAssertEqual(ContinuousReadingView.spoken(intro: "", segment: seg),
                       "il contesto del richiamo contenuto della nota.")
    }

    func test_deferredNote_label_prependsRefresh_keepsContent_replacesVerbalIntro() {
        let view = makeView()
        view.render([ContentSegment(id: "nt", role: "NOTE", text: "Cfr. art. 1218 c.c. sulla responsabilità del debitore.",
                                    lengthCategory: "LONG", acousticIntro: "Nota lunga.",
                                    memoryRefresh: "la rivalutazione del credito del lavoratore")])
        let label = cell(view, 0).accessibilityLabel ?? ""
        XCTAssertTrue(label.hasPrefix("la rivalutazione del credito del lavoratore"), "il rinfresco è anteposto: \(label)")
        XCTAssertTrue(label.contains("Cfr. art. 1218 c.c. sulla responsabilità del debitore."), "contenuto integro: \(label)")
        XCTAssertFalse(label.contains("Nota lunga."), "il segnale-nota sostituisce l'intro verbale")
    }

    func test_bodySegment_withoutRefresh_spokenUnchanged() {
        let body = bodySegment("b", "Un paragrafo qualunque del corpo.")
        XCTAssertEqual(ContinuousReadingView.spokenText(for: body), "Un paragrafo qualunque del corpo.")
    }

    // MARK: - Helper PDF sintetici

    static func makeSyntheticSamplePDF() -> URL {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
        let blocks: [(text: String, size: CGFloat, bold: Bool)] = [
            ("Capitolo Primo — Le obbligazioni", 24, true),
            ("Il rapporto obbligatorio lega due soggetti determinati: il creditore e il debitore.", 11, false),
            ("Il creditore ha diritto alla prestazione, che deve essere suscettibile di valutazione economica.", 11, false),
            ("L'inadempimento espone il debitore al risarcimento del danno secondo le regole generali.", 11, false),
            ("Sezione I — La prestazione", 18, true),
            ("La prestazione può consistere in un dare, un fare o un non fare a seconda del titolo.", 11, false),
            ("Cfr. art. 1218 c.c. sulla responsabilità del debitore.", 8, false),
        ]
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("scabo_demo_synthetic_\(UUID().uuidString).pdf")
        try? renderer.writePDF(to: url) { ctx in
            ctx.beginPage()
            var y: CGFloat = 60
            for b in blocks {
                let font: UIFont = b.bold ? UIFont.boldSystemFont(ofSize: b.size) : UIFont.systemFont(ofSize: b.size)
                (b.text as NSString).draw(at: CGPoint(x: 72, y: y),
                                          withAttributes: [.font: font, .foregroundColor: UIColor.black])
                y += b.size + 14
            }
        }
        return url
    }

    static func sampledPDF(at source: URL, from startPage: Int = 0, count: Int) -> URL? {
        guard let document = PDFDocument(url: source), document.pageCount > 0 else { return nil }
        let sample = PDFDocument()
        let start = max(0, min(startPage, document.pageCount - 1))
        let end = min(start + count, document.pageCount)
        for index in start..<end {
            guard let page = document.page(at: index)?.copy() as? PDFPage else { continue }
            sample.insert(page, at: sample.pageCount)
        }
        guard sample.pageCount > 0 else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("scabo_demo_sample_\(UUID().uuidString).pdf")
        return sample.write(to: url) ? url : nil
    }

    private static func privateFixtureURL(_ slug: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("pipeline/tests/fixtures/private/\(slug).pdf")
    }
}
