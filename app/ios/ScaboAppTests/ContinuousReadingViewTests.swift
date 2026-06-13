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

    // MARK: - 7. End-to-end da PDF sintetico: corpo reso, note escluse, in ordine

    func test_endToEnd_syntheticPdf_rendersBodyExcludesNotesInOrder() throws {
        // Catena reale: PDF sintetico → PdfKitExtractor → Generic → corpo paginato.
        let pdfURL = ContinuousReadingViewController.makeSyntheticSamplePDF()
        addTeardownBlock { try? FileManager.default.removeItem(at: pdfURL) }

        let extraction = try PdfKitExtractor().extract(fromUri: pdfURL.absoluteString)
        let document = buildDocumentFromPdf(extraction, sourceName: "campione_sintetico.pdf")
        XCTAssertFalse(document.structure.isEmpty, "la catena deve produrre struttura")

        let content = try ContinuousBodyBuilder.bodyPaginatedContent(from: document)
        let view = makeView()
        view.render(content)
        view.layoutIfNeeded()

        let labels = view.segmentLabels
        XCTAssertFalse(labels.isEmpty, "il corpo deve produrre elementi")
        XCTAssertEqual(view.exposedAccessibilityElements.count, labels.count, "container unico = un elemento per segmento di corpo")

        let texts = labels.map { $0.segment.text }

        // Il titolo emerge come heading (tratto header).
        let headings = labels.filter { $0.accessibilityTraits.contains(.header) }
        XCTAssertTrue(headings.contains { $0.segment.text.contains("Capitolo Primo") },
                      "il titolo grande è reso come intestazione")

        // Il corpo è presente.
        XCTAssertTrue(texts.contains { $0.contains("creditore") }, "il corpo è reso")

        // La NOTA (8pt, 'Cfr. art. 1218') è ESCLUSA in questa sessione.
        XCTAssertFalse(texts.contains { $0.contains("1218") }, "le note sono escluse dal rendering del corpo")
        XCTAssertFalse(labels.contains { $0.segment.role == "NOTE" || $0.segment.role == "EDITORIAL_NOTE" })

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
            ContinuousReadingViewController.sampledPDF(at: fixture, from: 40, count: 6),
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
