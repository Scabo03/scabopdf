//
//  ContinuousReadingViewTests.swift
//  ScaboAppTests
//
//  Rete di verifica della reading view "Lettura Continua" (gradino 2, sessione 1).
//  Gira ON-SIMULATOR (iPhone 16 / iOS 26.5): UIKit/PDFKit richiedono il contesto
//  app, non il `swift test` macOS di ScaboCore.
//
//  ── Cosa è verificabile QUI (e cosa NO) ─────────────────────────────────────────
//
//  Il Simulator NON riproduce l'esperienza VoiceOver reale del dispositivo. Questi
//  test verificano ciò che è verificabile a livello di API, SENZA un VoiceOver
//  umano:
//    • il container espone i segmenti di CORPO in ordine di lettura corretto;
//    • numero/ordine degli elementi accessibili = contenuto del documento;
//    • il container è UNICO e CONTINUO: un solo array piatto su tutto il
//      documento, nessun confine artificiale ai bordi di pagina logica (nessun
//      sotto-container per-pagina);
//    • ogni elemento esposto ha una `accessibilityLabel` non vuota.
//  Resta da verificare SUL DISPOSITIVO REALE (TestFlight, con VoiceOver):
//  l'esperienza effettiva — che lo swipe "scorra fluido" e che la lettura "suoni
//  bene". Questi test NON lo dimostrano e non lo affermano.
//
//  Materiale deterministico: `ContentSegment` costruiti a mano e PDF sintetizzati
//  in-test (verdi su clone pulito). Il fixture reale `patriarca_benazzo` è
//  esercitato quando presente, altrimenti il relativo test fa `XCTSkip`.
//

import PDFKit
import UIKit
import XCTest

@testable import ScaboApp
import ScaboCore

final class ContinuousReadingViewTests: XCTestCase {

    // MARK: - Helpers

    private func makeView(width: CGFloat = 393, height: CGFloat = 852) -> ContinuousReadingView {
        // Cornice realistica (iPhone 16 di default) così il layout risolve senza
        // warning. I test sul confine di pagina passano un viewport piccolo per
        // forzare l'impaginazione per misura a produrre più pagine visive.
        ContinuousReadingView(frame: CGRect(x: 0, y: 0, width: width, height: height))
    }

    private func bodySegment(_ id: String, _ text: String, role: String = "BODY") -> ContentSegment {
        ContentSegment(id: id, role: role, text: text, lengthCategory: "", acousticIntro: "")
    }

    /// N segmenti di corpo, ciascuno alto alcune righe nella colonna stretta del
    /// viewport di prova: in un viewport piccolo producono più pagine visive.
    private func manyBodySegments(_ count: Int) -> [ContentSegment] {
        (0..<count).map { i in
            bodySegment(
                "n\(i)",
                "Paragrafo numero \(i), con testo sufficiente a occupare alcune righe "
                    + "nella colonna stretta della pagina logica di prova.")
        }
    }

    /// Tre pagine logiche di dimensioni diverse: il banco di prova della continuità.
    private func multiPageBody() -> (content: PaginatedContent, orderedTexts: [String]) {
        let page1 = [
            bodySegment("n0", "Capitolo Primo", role: "HEADING_1"),
            bodySegment("n1", "Primo paragrafo del corpo."),
            bodySegment("n2", "Secondo paragrafo del corpo."),
        ]
        let page2 = [
            bodySegment("n3", "Terzo paragrafo, apre la pagina due."),
            bodySegment("n4", "Quarto paragrafo del corpo."),
        ]
        let page3 = [
            bodySegment("n5", "Quinto paragrafo, apre la pagina tre."),
            bodySegment("n6", "Sezione Seconda", role: "HEADING_2"),
            bodySegment("n7", "Sesto paragrafo del corpo."),
            bodySegment("n8", "Settimo e ultimo paragrafo."),
        ]
        let pages = [
            ContentPage(pageNumber: 1, segments: page1),
            ContentPage(pageNumber: 2, segments: page2),
            ContentPage(pageNumber: 3, segments: page3),
        ]
        let all = page1 + page2 + page3
        let content = PaginatedContent(pages: pages, totalSegments: all.count)
        let texts = all.map { ContinuousReadingView.spokenText(for: $0) }
        return (content, texts)
    }

    // MARK: - 1. Container unico e continuo, ordine di lettura

    func test_render_exposesOneFlatContainerSpanningAllPagesInOrder() {
        let view = makeView()
        let (content, orderedTexts) = multiPageBody()
        view.render(content)
        view.layoutIfNeeded()

        // Un solo array piatto, ampio quanto la SOMMA dei segmenti di tutte le
        // pagine: le pagine logiche non frammentano il container.
        let elements = view.exposedAccessibilityElements
        XCTAssertEqual(elements.count, content.totalSegments, "9 segmenti su 3 pagine → 9 elementi piatti")
        XCTAssertEqual(elements.count, 9)

        // Ordine di lettura = concatenazione delle pagine in ordine.
        let labels = elements.map { ($0 as? UILabel)?.accessibilityLabel ?? "" }
        XCTAssertEqual(labels, orderedTexts, "l'ordine esposto deve seguire la lettura, pagina dopo pagina")
    }

    func test_logicalPageBoundariesDoNotFragmentContainer() {
        let view = makeView()
        let (content, _) = multiPageBody()
        view.render(content)
        view.layoutIfNeeded()

        // Il container è un CONTAINER, non un elemento foglia.
        XCTAssertFalse(view.isDocumentContainerAnAccessibilityElement)

        // Ogni elemento esposto è una foglia (un SegmentLabel) e NON un
        // sotto-container con propri `accessibilityElements`: non esiste alcun
        // raggruppamento per-pagina che possa frapporre un confine allo swipe.
        for element in view.exposedAccessibilityElements {
            let label = element as? SegmentLabel
            XCTAssertNotNil(label, "ogni elemento deve essere una foglia SegmentLabel")
            XCTAssertTrue(label?.isAccessibilityElement ?? false, "la foglia è un elemento accessibile")
            XCTAssertNil(label?.accessibilityElements, "una foglia non deve esporre sotto-elementi (niente sotto-container)")
        }

        // Continuità al confine: l'ultimo elemento di pagina 1 (indice 2) è
        // immediatamente seguito dal primo di pagina 2 (indice 3) NELLO STESSO
        // array, senza oggetto-confine interposto.
        let elements = view.exposedAccessibilityElements
        let lastOfPage1 = (elements[2] as? SegmentLabel)?.segment.id
        let firstOfPage2 = (elements[3] as? SegmentLabel)?.segment.id
        XCTAssertEqual(lastOfPage1, "n2")
        XCTAssertEqual(firstOfPage2, "n3", "il primo di pagina 2 segue adiacente l'ultimo di pagina 1")
    }

    // MARK: - 2. Ogni elemento ha resa accessibile (etichetta non vuota)

    func test_everyExposedElementHasNonEmptyAccessibilityLabel() {
        let view = makeView()
        let (content, _) = multiPageBody()
        view.render(content)

        XCTAssertFalse(view.exposedAccessibilityElements.isEmpty)
        for element in view.exposedAccessibilityElements {
            let label = element.accessibilityLabel ?? ""
            XCTAssertFalse(label.isEmpty, "un elemento senza resa accessibile è bug critico")
        }
    }

    // MARK: - 3. Conteggio/ordine = contenuto del documento (segmento↔elemento)

    func test_elementCountAndOrderMatchSegments() {
        let view = makeView()
        let segments = (0..<25).map { bodySegment("n\($0)", "Paragrafo numero \($0).") }
        let content = try! paginate(segments, 20)  // 2 pagine logiche (20 + 5)

        view.render(content)

        XCTAssertEqual(content.pages.count, 2, "25 segmenti / 20 → 2 pagine logiche")
        let ids = view.exposedAccessibilityElements.compactMap { ($0 as? SegmentLabel)?.segment.id }
        XCTAssertEqual(ids, segments.map { $0.id }, "un elemento per segmento, nello stesso ordine, attraverso le 2 pagine")
    }

    // MARK: - 4. Tratto header per heading, non per corpo

    func test_headingRolesCarryHeaderTraitBodyDoesNot() {
        let view = makeView()
        let segments = [
            bodySegment("h1", "Titolo", role: "HEADING_1"),
            bodySegment("b1", "Corpo del testo."),
            bodySegment("sd", "Sezione", role: SECTION_DIVIDER_ROLE),
        ]
        view.render(try! paginate(segments))

        let labels = view.segmentLabels
        XCTAssertEqual(labels.count, 3)
        XCTAssertTrue(labels[0].accessibilityTraits.contains(.header), "HEADING_1 è intestazione")
        XCTAssertFalse(labels[1].accessibilityTraits.contains(.header), "il corpo NON è intestazione")
        XCTAssertTrue(labels[2].accessibilityTraits.contains(.header), "SECTION_DIVIDER è intestazione")
    }

    // MARK: - 5. Re-render idempotente (nessun residuo)

    func test_renderReplacesPreviousContentWithoutLeftovers() {
        let view = makeView()
        view.render(try! paginate([bodySegment("a", "Vecchio uno."), bodySegment("b", "Vecchio due.")]))
        XCTAssertEqual(view.exposedAccessibilityElements.count, 2)

        view.render(try! paginate([
            bodySegment("x", "Nuovo uno."), bodySegment("y", "Nuovo due."), bodySegment("z", "Nuovo tre."),
        ]))

        XCTAssertEqual(view.exposedAccessibilityElements.count, 3, "il re-render sostituisce, non accumula")
        let ids = view.exposedAccessibilityElements.compactMap { ($0 as? SegmentLabel)?.segment.id }
        XCTAssertEqual(ids, ["x", "y", "z"], "nessun residuo del contenuto precedente")
    }

    // MARK: - 6. Documento vuoto: zero elementi, nessun crash

    func test_emptyDocumentExposesZeroElements() {
        let view = makeView()
        view.render(PaginatedContent(pages: [ContentPage(pageNumber: 1, segments: [])], totalSegments: 0))
        view.layoutIfNeeded()
        XCTAssertEqual(view.exposedAccessibilityElements.count, 0)
    }

    // MARK: - 7. End-to-end da PDF sintetico: corpo E note (lette), in ordine

    func test_endToEnd_syntheticPdf_rendersBodyIncludingNotesInOrder() throws {
        // Catena reale: PDF sintetico → PdfKitExtractor → Generic → aggancio/piazzamento
        // note → corpo paginato. Le note ora sono LETTE (capitolo NOTE): la nota di
        // questo campione non ha numero d'apertura né richiamo in-corpo, quindi resta
        // NON agganciata → letta in posizione (presente, mai persa).
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

        let labels = view.segmentLabels
        XCTAssertFalse(labels.isEmpty, "il corpo deve produrre elementi")
        XCTAssertEqual(view.exposedAccessibilityElements.count, labels.count, "container unico = un elemento per segmento")

        let texts = labels.map { $0.segment.text }

        // Il titolo emerge come heading (tratto header).
        let headings = labels.filter { $0.accessibilityTraits.contains(.header) }
        XCTAssertTrue(headings.contains { $0.segment.text.contains("Capitolo Primo") },
                      "il titolo grande è reso come intestazione")

        // Il corpo è presente.
        XCTAssertTrue(texts.contains { $0.contains("creditore") }, "il corpo è reso")

        // La NOTA (8pt, 'Cfr. art. 1218') è ora LETTA (inclusa nel corpo).
        XCTAssertTrue(texts.contains { $0.contains("1218") }, "le note sono lette (non più escluse)")
        XCTAssertTrue(labels.contains { $0.segment.role == "NOTE" || $0.segment.role == "EDITORIAL_NOTE" },
                      "esiste almeno un segmento di nota letto")

        // Ordine di lettura: il titolo precede il primo paragrafo di corpo.
        if let titleIdx = texts.firstIndex(where: { $0.contains("Capitolo Primo") }),
           let bodyIdx = texts.firstIndex(where: { $0.contains("creditore") }) {
            XCTAssertLessThan(titleIdx, bodyIdx, "il titolo precede il corpo nell'ordine esposto")
        } else {
            XCTFail("titolo e corpo attesi tra gli elementi resi")
        }
    }

    // MARK: - 8. Fixture reale patriarca_benazzo (skip se assente)

    func test_realFixture_patriarca_rendersBodyContinuousContainer() throws {
        // Il fixture privato è gitignored: leggibile dal filesystem host via
        // #filePath (Simulator). Su clone pulito è assente → skip, non fallimento.
        let fixture = Self.privateFixtureURL("patriarca_benazzo")
        try XCTSkipUnless(
            FileManager.default.fileExists(atPath: fixture.path),
            "Fixture privato assente: \(fixture.path) — vedi pipeline/tests/fixtures/README.md")

        // Campione limitato del manuale reale: finestra di pagine di CORPO
        // (le prime sono frontespizio/indice; il corpo monocolonna pulito vive
        // da ~40 in poi, come confermato dalla fotografia d'esplorazione).
        let sample = try XCTUnwrap(
            Self.sampledPDF(at: fixture, from: 40, count: 6),
            "campionamento del PDF reale fallito")
        addTeardownBlock { try? FileManager.default.removeItem(at: sample) }

        let extraction = try PdfKitExtractor().extract(fromUri: sample.absoluteString)
        let document = buildDocumentFromPdf(extraction, sourceName: "patriarca_benazzo.pdf")

        let bodySegments = ContinuousBodyBuilder.bodySegments(from: document)
        let content = try ContinuousBodyBuilder.bodyPaginatedContent(from: document)

        let view = makeView()
        view.render(content)
        view.layoutIfNeeded()

        // Container unico = un elemento per segmento di corpo, nello stesso ordine.
        let elements = view.exposedAccessibilityElements
        XCTAssertGreaterThan(elements.count, 0, "patriarca (monocolonna) deve produrre corpo")
        XCTAssertEqual(elements.count, bodySegments.count)
        let renderedIds = elements.compactMap { ($0 as? SegmentLabel)?.segment.id }
        XCTAssertEqual(renderedIds, bodySegments.map { $0.id }, "ordine di lettura preservato dal modello alla view")

        // Ogni elemento ha resa accessibile.
        for element in elements {
            XCTAssertFalse((element.accessibilityLabel ?? "").isEmpty)
        }
    }

    // ════════════════════════════════════════════════════════════════════════════
    // PAGINATO-MA-CONTINUO — il punto critico: continuità dell'accessibilità
    // ATTRAVERSO i confini di pagina logica (presentazione paginata, container unico).
    // ════════════════════════════════════════════════════════════════════════════

    // MARK: - 9. La presentazione produce più pagine VISIVE (paging, non scroll)

    func test_viewportPagination_producesMultipleVisualPages() {
        let view = makeView(width: 320, height: 220)
        view.render(manyBodySegments(12))
        view.layoutIfNeeded()

        XCTAssertTrue(view.isHorizontallyPaged, "la presentazione è a paging orizzontale, non scroll continuo")
        XCTAssertGreaterThanOrEqual(view.visualPageCount, 2, "12 paragrafi in un viewport piccolo → più pagine logiche")
        XCTAssertTrue(view.contentSpansMultiplePages, "il contenuto si estende oltre un singolo viewport")
    }

    // MARK: - 10. UN solo array piatto attraverso le pagine, ordine preservato

    func test_singleFlatContainerSpansVisualPages_readingOrderPreserved() {
        let view = makeView(width: 320, height: 220)
        let segs = manyBodySegments(12)
        view.render(segs)
        view.layoutIfNeeded()

        XCTAssertGreaterThanOrEqual(view.visualPageCount, 2, "servono più pagine per esercitare il confine")
        let elements = view.exposedAccessibilityElements
        XCTAssertEqual(elements.count, segs.count,
                       "un solo array piatto = un elemento per segmento, ATTRAVERSO le pagine")
        let ids = elements.compactMap { ($0 as? SegmentLabel)?.segment.id }
        XCTAssertEqual(ids, segs.map { $0.id },
                       "ordine di lettura globale preservato attraverso la paginazione")
    }

    // MARK: - 11. Al confine di pagina: il primo della pagina seguente è ADIACENTE
    //             all'ultimo della precedente nell'array piatto, niente in mezzo

    func test_pageBoundary_nextElementIsFirstOfNextPage_noIntermediateContainer() {
        let view = makeView(width: 320, height: 220)
        let segs = manyBodySegments(12)
        view.render(segs)
        view.layoutIfNeeded()
        XCTAssertGreaterThanOrEqual(view.visualPageCount, 2, "serve almeno un confine di pagina")

        let elements = view.exposedAccessibilityElements
        // Per OGNI confine di pagina visiva:
        for page in 1..<view.visualPageCount {
            let firstOfPage = view.pageStartElementIndices[page]
            let lastOfPrev = firstOfPage - 1
            XCTAssertGreaterThanOrEqual(lastOfPrev, 0)

            // L'elemento accessibile successivo all'ultimo della pagina k-1 è il
            // primo della pagina k: indici CONSECUTIVI nello stesso array piatto,
            // nessun oggetto-confine interposto.
            XCTAssertEqual(view.visualPageIndex(ofElementAt: lastOfPrev), page - 1)
            XCTAssertEqual(view.visualPageIndex(ofElementAt: firstOfPage), page)

            // Entrambi sono foglie, non sotto-container: nessun raggruppamento
            // per-pagina che possa frapporre una barriera allo swipe.
            let last = elements[lastOfPrev] as? SegmentLabel
            let first = elements[firstOfPage] as? SegmentLabel
            XCTAssertNotNil(last)
            XCTAssertNotNil(first)
            XCTAssertNil(last?.accessibilityElements, "l'ultimo di pagina è una foglia")
            XCTAssertNil(first?.accessibilityElements, "il primo della pagina seguente è una foglia")
        }
    }

    // MARK: - 12. Un solo container di accessibilità, NON uno per pagina

    func test_exactlyOneAccessibilityContainer_noPerPageContainer() {
        let view = makeView(width: 320, height: 220)
        view.render(manyBodySegments(12))
        view.layoutIfNeeded()
        XCTAssertGreaterThanOrEqual(view.visualPageCount, 2)

        XCTAssertFalse(view.isDocumentContainerAnAccessibilityElement, "il container è un container, non una foglia")
        XCTAssertTrue(view.scrollViewHasNoAccessibilityElements, "lo scroll non è un container di accessibilità")
        XCTAssertEqual(view.exposedAccessibilityElements.count, 12, "tutti gli elementi in UN solo array")
        for element in view.exposedAccessibilityElements {
            XCTAssertNil((element as? SegmentLabel)?.accessibilityElements, "nessun container per-pagina")
        }
    }

    // MARK: - 13. Pagine disposte sinistra→destra, assegnazione monotòna in lettura

    func test_visualPagesLeftToRight_andPageAssignmentMonotonic() {
        let view = makeView(width: 320, height: 220)
        let segs = manyBodySegments(12)
        view.render(segs)
        view.layoutIfNeeded()
        XCTAssertGreaterThanOrEqual(view.visualPageCount, 2)

        // L'assegnazione di pagina non torna mai indietro nell'ordine di lettura.
        for i in 0..<(segs.count - 1) {
            let p0 = try! XCTUnwrap(view.visualPageIndex(ofElementAt: i))
            let p1 = try! XCTUnwrap(view.visualPageIndex(ofElementAt: i + 1))
            XCTAssertLessThanOrEqual(p0, p1, "la pagina non regredisce lungo la lettura")
        }

        // Le pagine successive stanno più a destra (paging orizzontale visivo).
        let firstOfPage1 = view.pageStartElementIndices[1]
        let xPage0 = try! XCTUnwrap(view.elementFrameInContent(at: 0)).minX
        let xPage1 = try! XCTUnwrap(view.elementFrameInContent(at: firstOfPage1)).minX
        XCTAssertGreaterThan(xPage1, xPage0, "la seconda pagina è a destra della prima")
    }

    // MARK: - 14. Elemento più alto di una pagina: pagina propria, testo integro

    func test_overTallElement_getsOwnPage_fullTextStaysAccessible() throws {
        let view = makeView(width: 300, height: 80)  // pagina deliberatamente molto bassa
        let tall = bodySegment("tall", String(repeating: "frase lunga che occupa molte righe. ", count: 20))
        let segs = [bodySegment("a", "Corto prima."), tall, bodySegment("b", "Corto dopo.")]
        view.render(segs)
        view.layoutIfNeeded()

        // L'elemento alto sta da solo sulla sua pagina (i vicini sono su altre pagine).
        let tallPage = try XCTUnwrap(view.visualPageIndex(ofElementAt: 1))
        let onTallPage = (0..<segs.count).filter { view.visualPageIndex(ofElementAt: $0) == tallPage }
        XCTAssertEqual(onTallPage, [1], "un elemento più alto di una pagina occupa una pagina propria")

        // Il testo resta INTEGRO nell'etichetta accessibile (l'eventuale eccedenza è
        // solo clip VISIVO; la lettura VoiceOver è completa).
        let label = view.exposedAccessibilityElements[1] as? SegmentLabel
        XCTAssertEqual(label?.accessibilityLabel, ContinuousReadingView.spokenText(for: tall),
                       "il testo completo resta accessibile nonostante il clip visivo")
    }

    // MARK: - 15. Ri-impaginazione al cambio di viewport: container e ordine invariati

    func test_repaginationOnViewportChange_preservesContainerAndOrder() {
        let view = makeView(width: 393, height: 4000)  // viewport alto: una sola pagina
        let segs = manyBodySegments(12)
        view.render(segs)
        view.layoutIfNeeded()
        let pagesLarge = view.visualPageCount
        let idsLarge = view.exposedAccessibilityElements.compactMap { ($0 as? SegmentLabel)?.segment.id }

        // Riduce il viewport (come una rotazione o uno schermo piccolo): si ricalcola.
        view.frame = CGRect(x: 0, y: 0, width: 320, height: 220)
        view.layoutIfNeeded()
        let pagesSmall = view.visualPageCount
        let idsSmall = view.exposedAccessibilityElements.compactMap { ($0 as? SegmentLabel)?.segment.id }

        XCTAssertEqual(pagesLarge, 1, "in un viewport molto alto i 12 paragrafi stanno su una pagina")
        XCTAssertGreaterThan(pagesSmall, pagesLarge, "viewport più piccolo → più pagine (impaginazione per misura)")
        XCTAssertEqual(idsSmall, idsLarge, "il container e l'ordine di lettura non cambiano con la ri-impaginazione")
        XCTAssertEqual(idsSmall, segs.map { $0.id })
    }

    // ════════════════════════════════════════════════════════════════════════════
    // GRANULARITÀ DEL CORPO (§ 7.6) → CABLAGGIO ALLA READING VIEW
    // ════════════════════════════════════════════════════════════════════════════

    /// Documento discorsivo sintetico: un titolo + un corpo lungo (molte frasi).
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

    // MARK: - 16. Il corpo discorsivo è granularizzato e alimenta il container continuo

    func test_discursiveBodyIsGranularized_feedsContinuousContainer_stress() throws {
        let longBody = (1...30)
            .map { "Questa e la frase numero \($0) del corpo discorsivo di prova." }
            .joined(separator: " ")
        let doc = discursiveDoc(longBody: longBody)

        let segs = ContinuousBodyBuilder.bodySegments(from: doc)  // target default 400

        // Il corpo lungo è stato spezzato in più blocchi BODY (granularizzazione),
        // oltre al titolo (un solo HEADING_1, non granularizzato).
        let headings = segs.filter { $0.role == "HEADING_1" }
        let bodies = segs.filter { $0.role == "BODY" }
        XCTAssertEqual(headings.count, 1, "il titolo resta un'unica intestazione")
        XCTAssertGreaterThan(bodies.count, 1, "il corpo lungo è granularizzato in più blocchi")
        // Ogni blocco di corpo rispetta il target (le frasi qui sono tutte corte).
        for b in bodies {
            XCTAssertLessThanOrEqual(b.text.count, DEFAULT_GRANULARITY_TARGET)
            XCTAssertEqual(b.text.last, ".", "ogni blocco finisce a un punto fermo")
        }

        // Stress dell'impaginazione paginata-ma-continua col massimo di elementi:
        // viewport piccolo → più pagine visive, ma UN solo container continuo.
        let content = try ContinuousBodyBuilder.bodyPaginatedContent(from: doc)
        let view = makeView(width: 320, height: 240)
        view.render(content)
        view.layoutIfNeeded()

        XCTAssertGreaterThanOrEqual(view.visualPageCount, 2, "molti blocchi in viewport piccolo → più pagine")
        let elements = view.exposedAccessibilityElements
        XCTAssertEqual(elements.count, segs.count, "un solo array piatto = un elemento per blocco granularizzato")
        let ids = elements.compactMap { ($0 as? SegmentLabel)?.segment.id }
        XCTAssertEqual(ids, segs.map { $0.id }, "ordine di lettura preservato attraverso la paginazione")
    }

    // ════════════════════════════════════════════════════════════════════════════
    // SEGNALI ACUSTICI DELLE NOTE (§ 10.4/§ 10.5) → CABLAGGIO ALLA READING VIEW
    // Cosa è verificabile QUI: la MAPPATURA regime→segnale, che il player sia invocato
    // al PUNTO giusto (fuoco sulla nota vera), che il segnale SOSTITUISCA l'intro verbale
    // lasciando il contenuto integro (rete A). Che il suono "suoni bene" e non sia
    // troncato/in conflitto con VoiceOver si certifica solo all'orecchio sul dispositivo.
    // ════════════════════════════════════════════════════════════════════════════

    private func noteSegment(
        _ id: String, _ text: String, length: String, intro: String = "Nota."
    ) -> ContentSegment {
        ContentSegment(id: id, role: "NOTE", text: text, lengthCategory: length, acousticIntro: intro)
    }

    // MARK: - 17. Mappatura dei sei regimi sui sei segnali, incisività crescente

    func test_noteSignal_mapsSixRegimesInOrder() {
        XCTAssertEqual(AudioSignal.noteSignal(forLengthCategory: "MICRO"), .noteMicro)
        XCTAssertEqual(AudioSignal.noteSignal(forLengthCategory: "SHORT"), .noteShort)
        XCTAssertEqual(AudioSignal.noteSignal(forLengthCategory: "MEDIUM"), .noteMedium)
        XCTAssertEqual(AudioSignal.noteSignal(forLengthCategory: "LONG"), .noteLong)
        XCTAssertEqual(AudioSignal.noteSignal(forLengthCategory: "VERY_LONG"), .noteVeryLong)
        XCTAssertEqual(AudioSignal.noteSignal(forLengthCategory: "MEGA"), .noteMega)
        XCTAssertNil(AudioSignal.noteSignal(forLengthCategory: ""), "categoria vuota → nessun segnale")
        XCTAssertNil(AudioSignal.noteSignal(forLengthCategory: "BOGUS"))
    }

    func test_audioSignal_resourceNamesMatchInventory() {
        XCTAssertEqual(AudioSignal.noteMicro.resourceName, "very-brief")
        XCTAssertEqual(AudioSignal.noteShort.resourceName, "brief")
        XCTAssertEqual(AudioSignal.noteMedium.resourceName, "medium")
        XCTAssertEqual(AudioSignal.noteLong.resourceName, "long")
        XCTAssertEqual(AudioSignal.noteVeryLong.resourceName, "very-long")
        XCTAssertEqual(AudioSignal.noteMega.resourceName, "ultra-long")
        XCTAssertEqual(AudioSignal.loading.resourceName, "loading")
        XCTAssertEqual(AudioSignal.completion.resourceName, "completion")
        XCTAssertEqual(AudioSignal.error.resourceName, "error")
        XCTAssertEqual(AudioSignal.announcement.resourceName, "announcement")
        XCTAssertEqual(AudioSignal.mode1.resourceName, "mode-1")
        XCTAssertEqual(AudioSignal.mode2.resourceName, "mode-2")
        XCTAssertEqual(AudioSignal.mode3.resourceName, "mode-3")
        XCTAssertEqual(AudioSignal.splitScreen.resourceName, "split-screen")
        XCTAssertEqual(AudioSignal.extra1.resourceName, "extra-1")
        XCTAssertEqual(AudioSignal.extra2.resourceName, "extra-2")
    }

    // MARK: - 18. Ogni asset .mp3 dichiarato è presente nel bundle dell'app

    func test_everyAudioSignalAssetIsBundled() {
        let bundle = Bundle(for: SignalPlayer.self)
        for signal in AudioSignal.allCases {
            XCTAssertNotNil(
                bundle.url(forResource: signal.resourceName, withExtension: "mp3"),
                "asset mancante dal bundle: \(signal.resourceName).mp3")
        }
    }

    // MARK: - 19. Nota vera con regime: segnale al fuoco, intro verbale sostituita

    func test_realNoteWithRegime_playsRegimeSignalOnFocus_replacesVerbalIntro() {
        let view = makeView()
        let spy = SignalPlayerSpy()
        view.signalPlayer = spy
        view.render([noteSegment("nt", "12. Cfr. art. 1218 c.c.", length: "MEDIUM")])
        view.layoutIfNeeded()

        let label = view.segmentLabels[0]
        // Il segnale SOSTITUISCE "Nota.": l'etichetta parlata è il solo testo della nota.
        XCTAssertEqual(label.accessibilityLabel, "12. Cfr. art. 1218 c.c.")
        XCTAssertFalse((label.accessibilityLabel ?? "").hasPrefix("Nota"))
        // Rete A: il contenuto della nota resta integro nell'etichetta.
        XCTAssertTrue((label.accessibilityLabel ?? "").contains("1218"))

        // Nessun segnale finché il fuoco non entra nella nota; uno solo all'ingresso.
        XCTAssertTrue(spy.played.isEmpty, "nessun segnale prima del fuoco")
        label.accessibilityElementDidBecomeFocused()
        XCTAssertEqual(spy.played, [.noteMedium], "all'ingresso suona il segnale del regime MEDIUM")
    }

    func test_realNotes_eachRegimeMapsToItsSignal() {
        let cases: [(String, AudioSignal)] = [
            ("MICRO", .noteMicro), ("SHORT", .noteShort), ("MEGA", .noteMega),
        ]
        for (regime, expected) in cases {
            let view = makeView()
            let spy = SignalPlayerSpy()
            view.signalPlayer = spy
            view.render([noteSegment("n", "Testo nota.", length: regime)])
            view.layoutIfNeeded()
            view.segmentLabels[0].accessibilityElementDidBecomeFocused()
            XCTAssertEqual(spy.played, [expected], "regime \(regime) → \(expected)")
        }
    }

    // MARK: - 20. Note NON vere e altri ruoli: nessun segnale, intro invariata

    func test_collapsedHeadingNote_emptyIntro_playsNoSignal_keepsText() {
        // Testatina collassata in NOTE dal classificatore size-only: intro già svuotata
        // (`suppressCollapsedHeadingNoteIntros`) → NON è una nota → nessun segnale.
        let view = makeView()
        let spy = SignalPlayerSpy()
        view.signalPlayer = spy
        view.render([noteSegment("ch", "TITOLO DI SEZIONE", length: "SHORT", intro: "")])
        view.layoutIfNeeded()

        view.segmentLabels[0].accessibilityElementDidBecomeFocused()
        XCTAssertTrue(spy.played.isEmpty, "una falsa nota (testatina collassata) non ha segnale")
        XCTAssertEqual(view.segmentLabels[0].accessibilityLabel, "TITOLO DI SEZIONE")
    }

    func test_bodyAndHeading_playNoSignalOnFocus() {
        let view = makeView()
        let spy = SignalPlayerSpy()
        view.signalPlayer = spy
        view.render([
            bodySegment("h", "Titolo", role: "HEADING_1"),
            bodySegment("b", "Corpo del testo."),
        ])
        view.layoutIfNeeded()
        view.segmentLabels.forEach { $0.accessibilityElementDidBecomeFocused() }
        XCTAssertTrue(spy.played.isEmpty, "corpo e intestazioni non hanno segnale-nota")
    }

    func test_editorialNote_keepsVerbalIntro_noSignal() {
        // EDITORIAL_NOTE non porta `length_category` → nessun segnale → mantiene il suo
        // intro verbale "Nota editoriale." (nessun asset di regime per le note editoriali).
        let view = makeView()
        let spy = SignalPlayerSpy()
        view.signalPlayer = spy
        let seg = ContentSegment(
            id: "e", role: "EDITORIAL_NOTE", text: "Avvertenza redazionale.",
            lengthCategory: "", acousticIntro: "Nota editoriale.")
        view.render([seg])
        view.layoutIfNeeded()

        view.segmentLabels[0].accessibilityElementDidBecomeFocused()
        XCTAssertTrue(spy.played.isEmpty, "la nota editoriale non ha segnale di regime")
        XCTAssertEqual(view.segmentLabels[0].accessibilityLabel, "Nota editoriale. Avvertenza redazionale.")
    }

    // MARK: - Helper PDF sintetici (ex "ponte di sviluppo", ora nel target di test)
    //
    // Questi due helper esercitano la catena reale (PDF → PdfKitExtractor → Generic)
    // SOLO dai test; vivevano nel codice di produzione (ContinuousReadingViewController)
    // pur non avendo chiamanti nel percorso utente. La pulizia li ha spostati qui.

    /// Campione PDF sintetizzato in-test: un titolo, alcuni paragrafi di corpo e una nota piccola
    /// (che il filtro di corpo esclude). Deterministico, ermetico.
    static func makeSyntheticSamplePDF() -> URL {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)  // A4 pt
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
                let font: UIFont = b.bold
                    ? UIFont.boldSystemFont(ofSize: b.size)
                    : UIFont.systemFont(ofSize: b.size)
                (b.text as NSString).draw(
                    at: CGPoint(x: 72, y: y),
                    withAttributes: [.font: font, .foregroundColor: UIColor.black])
                y += b.size + 14
            }
        }
        return url
    }

    /// Riserializza una finestra di `count` pagine a partire da `startPage` in un file temporaneo.
    /// Cap di responsività per il test; `startPage` è clampato. `nil` se il PDF non apre.
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

    // MARK: - Localizzazione fixture privato (filesystem host via #filePath)

    private static func privateFixtureURL(_ slug: String) -> URL {
        // .../app/ios/ScaboAppTests/ContinuousReadingViewTests.swift → 4 su = repo
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // ScaboAppTests
            .deletingLastPathComponent()  // ios
            .deletingLastPathComponent()  // app
            .deletingLastPathComponent()  // repo root
            .appendingPathComponent("pipeline/tests/fixtures/private/\(slug).pdf")
    }
}
