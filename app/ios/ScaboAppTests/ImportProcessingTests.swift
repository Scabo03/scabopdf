//
//  ImportProcessingTests.swift
//  ScaboAppTests
//
//  Rete di verifica del flusso import → elaborazione → reading view (sessione import). Gira
//  ON-SIMULATOR (iPhone 16 / iOS 26.5).
//
//  ── Cosa è verificabile QUI (e cosa NO) ─────────────────────────────────────────────────────
//
//  A livello di API/logica, SENZA VoiceOver umano e SENZA il picker di sistema:
//    • la SIGILLATURA dei due container della reading view: il container del TESTO espone solo
//      segmenti, quello dell'INTERFACCIA solo [Indietro, titolo], insiemi DISGIUNTI; la
//      sigillatura modale è impostata (swipe confinato al testo, § 2.2) e l'escape commuta il
//      container attivo;
//    • il REPORTING di progresso: dato M pagine, i callback arrivano con frazione monotòna
//      crescente fino a 1.0 e l'esito è successo con contenuto;
//    • la CANCELLAZIONE: interrompendo, l'elaborazione si ferma e NON produce un documento aperto
//      come valido (esito `.cancelled`, nessun documento);
//    • la reading view RENDE il contenuto elaborato (un elemento per segmento).
//
//  Restano certificabili SOLO sul dispositivo reale (TestFlight): che lo swipe "all'orecchio" non
//  raggiunga mai l'interfaccia, il passaggio fra container con lo scrub, il document picker di
//  sistema, e il comportamento su un PDF reale grande (tempi, memoria). Il Simulator non li
//  riproduce.
//

import UIKit
import XCTest

@testable import ScaboApp
import ScaboCore

// MARK: - Estrattore finto (deterministico, cancellabile a comando)

/// Estrattore progress-aware finto: emette `pages` pagine di corpo, riportando il progresso per
/// pagina, e onora la cancellazione. `onEachPage` è invocato sul thread di lavoro DENTRO il loop
/// (dopo l'emissione della pagina), così un test può chiamare `cancel()` a una pagina precisa e
/// rendere la cancellazione mid-flight DETERMINISTICA.
private final class FakeProgressExtractor: ProgressReportingPdfExtractor {
    let pages: Int
    var onEachPage: ((Int) -> Void)?

    init(pages: Int) { self.pages = pages }

    func extract(
        fromUri uri: String,
        onPageExtracted: (_ done: Int, _ total: Int) -> Void,
        isCancelled: () -> Bool
    ) throws -> PdfExtraction? {
        var built: [PdfPageExtraction] = []
        for i in 0..<pages {
            if isCancelled() { return nil }
            // Testo per-pagina DAVVERO distinto (token alfabetico, non un numero): così le righe
            // non sembrano furniture ricorrente al rilevatore del Generic, che le rimuoverebbe.
            let span = PdfSpan(
                text: "Paragrafo \(Self.pageTag(i)): corpo distinto della pagina, con prosa sufficiente a contare bene.",
                fontSize: 12, bold: false, italic: false, color: "#000000",
                bbox: BBox(x: 0, y: 0, width: 0, height: 0))
            let line = PdfTextLine(spans: [span], bbox: BBox(x: 0, y: 0, width: 0, height: 0))
            built.append(PdfPageExtraction(pageIndex: i, width: 595, height: 842, lines: [line]))
            onPageExtracted(i + 1, pages)
            onEachPage?(i + 1)
        }
        if isCancelled() { return nil }
        return PdfExtraction(version: 2, pageCount: pages, pages: built)
    }

    /// Etichetta alfabetica univoca per pagina, stile colonna foglio ("a","b",…,"z","aa",…). Non
    /// contiene cifre, così `normalizeDigits` del Generic non la collassa fra pagine diverse.
    private static func pageTag(_ i: Int) -> String {
        let letters = Array("abcdefghijklmnopqrstuvwxyz")
        var n = i
        var s = ""
        repeat {
            s = String(letters[n % 26]) + s
            n = n / 26 - 1
        } while n >= 0
        return s
    }
}

// MARK: - Spia del player di segnali (registra le invocazioni, niente audio reale)

/// Spia conforme a `SignalPlaying`: cattura le invocazioni così i test verificano che il
/// player sia chiamato allo stato/punto giusto senza riprodurre audio. Visibile a tutto il
/// target di test (usata anche da `ContinuousReadingViewTests`).
final class SignalPlayerSpy: SignalPlaying {
    private(set) var played: [AudioSignal] = []
    private(set) var looped: [AudioSignal] = []
    private(set) var stopped: [AudioSignal] = []

    func play(_ signal: AudioSignal) { played.append(signal) }
    func playLooping(_ signal: AudioSignal) { looped.append(signal) }
    func stop(_ signal: AudioSignal) { stopped.append(signal) }
}

final class ImportProcessingTests: XCTestCase {

    // MARK: - DocumentProcessor: progresso reale e successo

    func test_processor_reportsMonotonicProgressAndSucceedsWithContent() {
        let processor = DocumentProcessor(extractor: FakeProgressExtractor(pages: 6))
        let done = expectation(description: "completion")

        var fractions: [Double] = []
        var outcome: DocumentProcessor.Outcome?

        processor.process(
            fileURL: URL(fileURLWithPath: "/dev/null/finto.pdf"),
            sourceName: "finto.pdf",
            onProgress: { progress in fractions.append(progress.fraction) },
            completion: { result in outcome = result; done.fulfill() }
        )
        wait(for: [done], timeout: 5)

        // Esito: successo con contenuto reso.
        guard case .success(_, let content, _)? = outcome else {
            return XCTFail("atteso successo, ottenuto \(String(describing: outcome))")
        }
        XCTAssertGreaterThan(content.totalSegments, 0, "l'elaborazione deve produrre contenuto di corpo")

        // Progresso monotòno non decrescente fino a 1.0.
        XCTAssertFalse(fractions.isEmpty, "devono arrivare aggiornamenti di progresso")
        for i in 1..<fractions.count {
            XCTAssertGreaterThanOrEqual(fractions[i], fractions[i - 1],
                                        "la frazione non deve mai regredire")
        }
        XCTAssertEqual(fractions.last ?? 0, 1.0, accuracy: 0.0001, "il progresso raggiunge il 100%")
        XCTAssertLessThanOrEqual(fractions.max() ?? 0, 1.0, "il progresso non supera mai il 100%")
    }

    // MARK: - DocumentProcessor: cancellazione pulita (nessun documento parziale)

    func test_processor_cancelMidFlight_stopsAndYieldsCancelledNoDocument() {
        let fake = FakeProgressExtractor(pages: 50)
        let processor = DocumentProcessor(extractor: fake)
        let done = expectation(description: "completion")

        // Cancella deterministicamente alla 3ª pagina, DENTRO il loop di estrazione.
        fake.onEachPage = { page in if page == 3 { processor.cancel() } }

        var outcome: DocumentProcessor.Outcome?
        processor.process(
            fileURL: URL(fileURLWithPath: "/dev/null/finto.pdf"),
            sourceName: "finto.pdf",
            onProgress: { _ in },
            completion: { result in outcome = result; done.fulfill() }
        )
        wait(for: [done], timeout: 5)

        guard case .cancelled? = outcome else {
            return XCTFail("atteso .cancelled, ottenuto \(String(describing: outcome))")
        }
    }

    func test_processor_cancelBeforeStart_yieldsCancelled() {
        let processor = DocumentProcessor(extractor: FakeProgressExtractor(pages: 10))
        processor.cancel()
        let done = expectation(description: "completion")

        var outcome: DocumentProcessor.Outcome?
        processor.process(
            fileURL: URL(fileURLWithPath: "/dev/null/finto.pdf"),
            sourceName: "finto.pdf",
            onProgress: { _ in },
            completion: { result in outcome = result; done.fulfill() }
        )
        wait(for: [done], timeout: 5)

        guard case .cancelled? = outcome else {
            return XCTFail("atteso .cancelled, ottenuto \(String(describing: outcome))")
        }
    }

    // MARK: - DocumentProcessor: errore di apertura → prosa, non solo "errore"

    func test_processor_unreadableFile_failsWithProseMessage() {
        // Estrattore reale su un percorso inesistente: l'apertura PDFKit fallisce con messaggio
        // in prosa italiana, che l'orchestratore propaga come `.failure`.
        let processor = DocumentProcessor()
        let done = expectation(description: "completion")

        var outcome: DocumentProcessor.Outcome?
        processor.process(
            fileURL: URL(fileURLWithPath: "/percorso/inesistente/non_un_pdf.pdf"),
            sourceName: "non_un_pdf.pdf",
            onProgress: { _ in },
            completion: { result in outcome = result; done.fulfill() }
        )
        wait(for: [done], timeout: 5)

        guard case .failure(let message)? = outcome else {
            return XCTFail("atteso .failure, ottenuto \(String(describing: outcome))")
        }
        XCTAssertFalse(message.isEmpty, "il messaggio d'errore deve essere in prosa, non vuoto")
        XCTAssertGreaterThan(message.count, 10, "spiegazione leggibile, non un codice criptico")
    }

    // MARK: - Reading view: due container sigillati e disgiunti

    private func sampleContent(_ count: Int = 5) -> PaginatedContent {
        let segments = (0..<count).map {
            ContentSegment(id: "n\($0)", role: "BODY", text: "Paragrafo \($0) del corpo.",
                           lengthCategory: "", acousticIntro: "")
        }
        return try! paginate(segments)
    }

    private func makeLoadedReader(_ content: PaginatedContent) -> ContinuousReadingViewController {
        let vc = ContinuousReadingViewController(content: content, sourceName: "prova.pdf")
        vc.loadViewIfNeeded()
        vc.view.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        vc.view.layoutIfNeeded()
        return vc
    }

    func test_reader_rootExposesOnlyActiveContainer_sealedAtAbsoluteExtremes() {
        let content = sampleContent(5)
        let vc = makeLoadedReader(content)

        // Sigillo STRUTTURALE (build 5): la radice espone SOLO il container ATTIVO. All'ingresso il
        // testo è attivo, quindi la radice espone il SOLO testo e NON l'interfaccia. È questa
        // assenza dall'array piatto che chiude la falla ai due estremi assoluti: non esistendo più
        // la giunzione [interfaccia ↔ inizio/fine del testo], lo swipe non può raggiungere la barra
        // a nessun elemento, primo e ultimo assoluti compresi.
        let roots = vc.rootAccessibilityContainersForTesting
        XCTAssertEqual(roots.count, 1, "la radice espone un solo container: quello attivo")
        XCTAssertTrue(roots[0] === vc.textContainerForTesting, "all'ingresso l'attivo è il testo")
        XCTAssertFalse(roots.contains { $0 === vc.interfaceContainerForTesting },
                       "l'interfaccia è ASSENTE dall'array di radice → non raggiungibile via swipe")

        // I due container restano comunque oggetti distinti e disgiunti (verificabili dai testing
        // accessor), ciò che cambia è solo quale dei due la radice espone.
        XCTAssertFalse(vc.textContainerForTesting === vc.interfaceContainerForTesting)
    }

    func test_reader_textContainerExposesOnlySegments_interfaceOnlyTitleAndBack() {
        let content = sampleContent(5)
        let vc = makeLoadedReader(content)

        // Container del TESTO: solo segmenti, uno per ogni segmento del contenuto.
        let textElements = vc.textContainerForTesting.exposedAccessibilityElements
        XCTAssertEqual(textElements.count, content.totalSegments)
        for element in textElements {
            XCTAssertTrue(element is SegmentCell, "il container del testo espone solo segmenti")
        }

        // Container dell'INTERFACCIA: [Indietro, selettore Layout] — Opzione A verticale: caduta la
        // pagina di visualizzazione sintetica, e con l'originale OFF (default qui) nessun box di
        // pagina. Il selettore (§ 3.4) ha sostituito il titolo statico. NESSUN elemento di testo qui.
        vc.viewDidAppear(false)
        let interface = vc.interfaceContainerForTesting
        let interfaceElements = (interface.accessibilityElements as? [NSObject]) ?? []
        XCTAssertEqual(interfaceElements.count, 2, "interfaccia: Indietro, selettore Layout")
        XCTAssertTrue(interfaceElements.contains { ($0 as? UIButton) === interface.backButton })
        XCTAssertTrue(interfaceElements.contains { ($0 as? UIButton) === interface.layoutSelectorButton })
        XCTAssertTrue(interface.visualizationPageLabel.isHidden, "nessun box di visualizzazione nel verticale")
        XCTAssertEqual(interface.layoutSelectorButton.title(for: .normal), "Lettura Continua")
        XCTAssertEqual(interface.backButton.accessibilityLabel, "Indietro")
        for element in interfaceElements {
            XCTAssertFalse(element is SegmentCell, "nessun elemento di testo nell'interfaccia")
        }
    }

    func test_reader_containersHaveDisjointElementSets() {
        let content = sampleContent(6)
        let vc = makeLoadedReader(content)

        // Gli insiemi di elementi dei due container sono DISGIUNTI: nessun elemento è condiviso.
        // (Che lo swipe lineare attraversi o no il confine fra i container è comportamento
        // VoiceOver runtime, non riproducibile sul Simulator: si verifica sul dispositivo.)
        let textIDs = Set(vc.textContainerForTesting.exposedAccessibilityElements.map { ObjectIdentifier($0) })
        let interfaceElements = (vc.interfaceContainerForTesting.accessibilityElements as? [NSObject]) ?? []
        let interfaceIDs = Set(interfaceElements.map { ObjectIdentifier($0) })

        XCTAssertTrue(textIDs.isDisjoint(with: interfaceIDs),
                      "gli insiemi di elementi dei due container non si sovrappongono")
        XCTAssertFalse(textIDs.isEmpty)
        XCTAssertFalse(interfaceIDs.isEmpty)
    }

    func test_reader_textContainerIsModalByDefault_interfaceSealedFromSwipe() {
        // Scenario blindato (§ 2.2): all'ingresso il testo è il container attivo. Sigillo su DUE
        // livelli — la radice espone il SOLO testo (portante) e il flag modale è sul testo
        // (rinforzo). Lo swipe lineare resta confinato al testo e non può sconfinare sull'interfaccia.
        let vc = makeLoadedReader(sampleContent(4))
        XCTAssertEqual(vc.rootAccessibilityContainersForTesting.count, 1, "la radice espone solo l'attivo")
        XCTAssertTrue(vc.rootAccessibilityContainersForTesting.first === vc.textContainerForTesting)
        XCTAssertTrue(vc.textContainerIsModalForTesting, "il testo porta anche il flag modale (rinforzo)")
        XCTAssertFalse(vc.interfaceContainerIsModalForTesting, "l'interfaccia non è il modale attivo")
    }

    func test_reader_scrubTogglesActiveContainer_bothDirections_rootArrayAndModalSwap() {
        let vc = makeLoadedReader(sampleContent(4))

        // Lo scrub a due dita (escape) è l'unica via di passaggio: commuta quale container è
        // ESPOSTO dalla radice (sigillo portante) e modale (rinforzo), in entrambe le direzioni.
        // (Lo spostamento effettivo del fuoco è runtime VoiceOver, certificato sul dispositivo.)
        XCTAssertTrue(vc.rootAccessibilityContainersForTesting.first === vc.textContainerForTesting,
                      "stato iniziale: la radice espone il testo")
        XCTAssertTrue(vc.textContainerIsModalForTesting, "stato iniziale: testo modale")

        XCTAssertTrue(vc.textContainerForTesting.accessibilityPerformEscape(), "scrub gestito")
        XCTAssertEqual(vc.rootAccessibilityContainersForTesting.count, 1)
        XCTAssertTrue(vc.rootAccessibilityContainersForTesting.first === vc.interfaceContainerForTesting,
                      "scrub dal testo → la radice espone l'interfaccia, il testo sparisce dallo swipe")
        XCTAssertFalse(vc.textContainerIsModalForTesting)
        XCTAssertTrue(vc.interfaceContainerIsModalForTesting, "scrub dal testo → interfaccia modale")

        XCTAssertTrue(vc.interfaceContainerForTesting.accessibilityPerformEscape(), "scrub gestito")
        XCTAssertEqual(vc.rootAccessibilityContainersForTesting.count, 1)
        XCTAssertTrue(vc.rootAccessibilityContainersForTesting.first === vc.textContainerForTesting,
                      "scrub dall'interfaccia → la radice torna a esporre il testo")
        XCTAssertTrue(vc.textContainerIsModalForTesting, "scrub dall'interfaccia → di nuovo testo modale")
        XCTAssertFalse(vc.interfaceContainerIsModalForTesting)
    }

    func test_reader_returningToText_preservesReadingPosition() {
        // Correzione del reset di posizione: il rientro nel testo dall'interfaccia torna DOVE
        // l'utente era, non al primissimo elemento.
        let content = sampleContent(6)
        let vc = makeLoadedReader(content)
        let rv = vc.textContainerForTesting
        XCTAssertGreaterThan(rv.currentSegments.count, 3)

        // L'utente legge fino a un elemento centrale: VoiceOver lo mette a fuoco (per INDICE nel
        // modello riciclante — niente più etichetta persistente da confrontare per identità).
        rv.cellDidBecomeFocused(index: 3, segment: rv.currentSegments[3])
        XCTAssertEqual(vc.currentReadingPositionForTesting, 3, "la posizione di lettura è ricordata")

        // Va all'interfaccia (scrub) e torna al testo (scrub).
        XCTAssertTrue(rv.accessibilityPerformEscape())                              // testo → interfaccia
        XCTAssertTrue(vc.interfaceContainerForTesting.accessibilityPerformEscape()) // interfaccia → testo

        // Il rientro NON resetta: la posizione ripristinata è ancora l'elemento centrale.
        XCTAssertEqual(vc.currentReadingPositionForTesting, 3,
                       "il rientro nel testo riporta dove l'utente era, non al primissimo elemento")
        XCTAssertNotEqual(vc.currentReadingPositionForTesting, 0,
                          "non si torna al primo elemento")
    }

    // MARK: - Posizione di lettura: ripristino all'apertura e notifica del cambio (§ 2.5)

    func test_reader_restoresInitialReadingPosition_andReportsChanges() {
        let content = sampleContent(8)
        var reported: [Int] = []
        let vc = ContinuousReadingViewController(
            content: content, sourceName: "x.pdf", documentId: "doc1",
            initialReadingPosition: 4,
            onPositionChanged: { reported.append($0) })
        vc.loadViewIfNeeded()
        vc.view.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        vc.view.layoutIfNeeded()

        // All'apertura la posizione si ripristina all'indice 4 (la posizione ricordata).
        let rv = vc.textContainerForTesting
        XCTAssertEqual(vc.currentReadingPositionForTesting, 4,
                       "all'apertura la posizione si ripristina all'elemento ricordato")

        // Mettendo a fuoco un altro elemento, la posizione viene notificata per la persistenza.
        rv.cellDidBecomeFocused(index: 6, segment: rv.currentSegments[6])
        XCTAssertEqual(reported.last, 6, "il cambio di fuoco notifica l'indice della nuova posizione")
        XCTAssertEqual(vc.currentReadingPositionForTesting, 6)
    }

    // MARK: - Riaccensione di VoiceOver: protezione e ripristino della posizione (non più inizio file)

    func test_reader_voiceOverReactivation_protectsPosition_andSuppressesSpuriousZeroSave() {
        // L'ancora fissa al tasto Indietro (vecchia scelta) NON risolveva il caso: alla riaccensione
        // VoiceOver rispedisce il fuoco a inizio file e il salvataggio a 0 sovrascriveva la posizione.
        // Ora si protegge la posizione reale e si sopprime lo 0 spurio.
        let content = sampleContent(6)
        var persisted: [Int] = []
        let vc = ContinuousReadingViewController(
            content: content, documentId: "", initialReadingPosition: 0,
            onPositionChanged: { persisted.append($0) }, signalPlayer: SignalPlayerSpy())
        vc.loadViewIfNeeded()
        vc.view.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        vc.view.layoutIfNeeded()
        vc.viewDidAppear(false)
        let rv = vc.textContainerForTesting

        // L'utente legge fino a un elemento centrale (fuoco reale).
        rv.cellDidBecomeFocused(index: 3, segment: rv.currentSegments[3])
        XCTAssertEqual(persisted.last, 3, "la lettura reale persiste la posizione 3")
        persisted.removeAll()

        // Riaccensione di VoiceOver: si apre la protezione sulla posizione reale.
        vc.beginVoiceOverProtectionForTesting()
        XCTAssertTrue(vc.isProtectingReadingPositionForTesting)

        // VoiceOver rispedisce il fuoco a inizio file (reset): NON deve persistere 0, e deve
        // ri-portare alla posizione reale.
        rv.cellDidBecomeFocused(index: 0, segment: rv.currentSegments[0])

        XCTAssertFalse(persisted.contains(0), "lo 0 spurio del reset NON viene mai salvato")
        XCTAssertEqual(vc.textContainerForTesting.currentReadingElementIndex, 3,
                       "la posizione reale è ripristinata, non inizio file")
    }

    // MARK: - Indicatore di pagina in toolbar: due box separati (§ 4.3)

    func test_pageIndicator_noBoxes_whenOriginalPagesOff_verticalOptionA() {
        let vc = makeLoadedReader(sampleContent(3))   // sourcePageCount 0, toggle off
        vc.viewDidAppear(false)
        let bar = vc.interfaceContainerForTesting
        // Opzione A verticale: caduta la pagina di visualizzazione sintetica; con l'originale off,
        // nessun indicatore di pagina.
        XCTAssertTrue(bar.visualizationPageLabel.isHidden, "nessun box di visualizzazione nel verticale")
        XCTAssertTrue(bar.originalPageLabel.isHidden, "originale off → nessun box del file originale")
    }

    func test_pageIndicator_originalOnly_whenOn_verticalOptionA() {
        let vc = ContinuousReadingViewController(
            content: sampleContent(3), sourceName: "x.pdf", documentId: "d",
            initialReadingPosition: 0, onPositionChanged: nil,
            sourcePageCount: 1985, showOriginalPages: true, sourcePage: { _ in 100 })
        vc.loadViewIfNeeded()
        vc.view.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        vc.view.layoutIfNeeded()
        vc.viewDidAppear(false)
        let bar = vc.interfaceContainerForTesting

        // Opzione A verticale: UN solo box, quello del file originale; nessun box di visualizzazione.
        XCTAssertFalse(bar.originalPageLabel.isHidden, "il box del file originale è visibile")
        XCTAssertTrue(bar.visualizationPageLabel.isHidden, "nessun box di visualizzazione nel verticale")
        XCTAssertEqual(bar.originalPageLabel.text, "100 di 1985")
        XCTAssertEqual(bar.originalPageLabel.accessibilityLabel, "pagina 100 di 1985 del file originale")

        let elements = (bar.accessibilityElements as? [NSObject]) ?? []
        XCTAssertTrue(elements.contains { $0 === bar.originalPageLabel }, "il box originale è accessibile")
    }

    func test_buildPageMap_mapsNodeIdsToOneBasedPages() {
        let doc = ScabopdfDocument(
            schema_version: "0.7.0", document_id: "d",
            metadata: DocumentMetadata(pages_pdf: 5, page_size_pt: [595, 842], source_pdf_filename: "x.pdf"),
            profile: DocumentProfileDict(
                profile_id: "generic", editorial_family: "generic", genre: "unknown", confidence: 0.05),
            structure: [
                NodeDict(id: "node_0", type: .HEADING_1, page_index: 2, text: "T", children: [
                    NodeDict(id: "node_1", type: .BODY, page_index: 4, text: "b"),
                ]),
            ])
        let map = DocumentOpener.buildPageMap(doc)
        XCTAssertEqual(map["node_0"], 3, "page_index 2 (0-based) → pagina 3 (1-based)")
        XCTAssertEqual(map["node_1"], 5, "i figli sono mappati ricorsivamente")
    }

    // MARK: - Selettore di Layout (§ 3.4 / § 10): Continua ⇄ Dottrina Inline

    private func makeReader(continuous: PaginatedContent, doctrine: PaginatedContent?) -> ContinuousReadingViewController {
        let vc = ContinuousReadingViewController(
            content: continuous, sourceName: "x.pdf", documentId: "d",
            doctrineContent: doctrine, signalPlayer: SignalPlayerSpy())
        vc.loadViewIfNeeded()
        vc.view.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        vc.view.layoutIfNeeded()
        return vc
    }

    func test_layoutSelector_defaultsToContinuous_doctrineAvailableWhenProvided() {
        let vc = makeReader(continuous: sampleContent(3), doctrine: sampleContent(7))
        XCTAssertEqual(vc.currentLayoutForTesting, .continuous, "default sempre Lettura Continua (§ 3.4)")
        XCTAssertTrue(vc.doctrineAvailableForTesting, "Dottrina Inline disponibile: il documento ha il flusso")
        XCTAssertEqual(vc.renderedSegmentCountForTesting, 3, "rende il flusso continua all'apertura")
        XCTAssertEqual(vc.interfaceContainerForTesting.layoutSelectorButton.title(for: .normal), "Lettura Continua")
    }

    func test_layoutSelector_disabledWhenNoDoctrineContent() {
        let vc = makeReader(continuous: sampleContent(4), doctrine: nil)
        XCTAssertFalse(vc.doctrineAvailableForTesting, "nessun flusso dottrina → selettore disabilitato (§ 10.3)")
        vc.switchLayoutForTesting(to: .doctrine)
        XCTAssertEqual(vc.currentLayoutForTesting, .continuous, "switch a dottrina senza flusso è no-op")
        XCTAssertEqual(vc.renderedSegmentCountForTesting, 4)
    }

    func test_layoutSelector_switchSwapsRenderedFlow_andBack() {
        let vc = makeReader(continuous: sampleContent(3), doctrine: sampleContent(7))
        vc.switchLayoutForTesting(to: .doctrine)
        XCTAssertEqual(vc.currentLayoutForTesting, .doctrine)
        XCTAssertEqual(vc.renderedSegmentCountForTesting, 7, "passa al flusso Dottrina Inline")
        XCTAssertEqual(vc.interfaceContainerForTesting.layoutSelectorButton.title(for: .normal), "Dottrina Inline")
        vc.switchLayoutForTesting(to: .continuous)
        XCTAssertEqual(vc.currentLayoutForTesting, .continuous)
        XCTAssertEqual(vc.renderedSegmentCountForTesting, 3, "torna al flusso Lettura Continua")
    }

    private func sampleTree() -> [QuickConsultNode] {
        let art = QuickConsultNode(role: "ARTICLE_HEADER", depth: 2, title: "1173. Fonti",
                                   headingId: "node_5", firstPage: 0, lastPage: 0, children: [],
                                   contentIds: ["node_6"])
        let libro = QuickConsultNode(role: "HEADING_1", depth: 1, title: "LIBRO QUARTO",
                                     headingId: "node_4", firstPage: 0, lastPage: 0, children: [art],
                                     contentIds: [])
        return [libro]
    }

    func test_quickLayout_availableWhenTreeProvided() {
        let vc = ContinuousReadingViewController(
            content: sampleContent(3), sourceName: "codice.pdf", documentId: "dq",
            quickConsultTree: sampleTree(), signalPlayer: SignalPlayerSpy())
        vc.loadViewIfNeeded(); vc.view.frame = CGRect(x: 0, y: 0, width: 768, height: 1024); vc.view.layoutIfNeeded()
        XCTAssertTrue(vc.quickAvailableForTesting, "albero presente → Consultazione Rapida disponibile")
        XCTAssertEqual(vc.currentLayoutForTesting, .continuous, "default sempre Lettura Continua")
    }

    func test_quickLayout_disabledWhenNoTree_isNoOp() {
        let vc = makeReader(continuous: sampleContent(4), doctrine: nil)
        XCTAssertFalse(vc.quickAvailableForTesting, "nessun albero → disabilitato")
        vc.switchLayoutForTesting(to: .quick)
        XCTAssertEqual(vc.currentLayoutForTesting, .continuous, "switch a quick senza albero è no-op")
    }

    func test_quickLayout_switchShowsTreeContainer_andBack() {
        let vc = ContinuousReadingViewController(
            content: sampleContent(3), sourceName: "codice.pdf", documentId: "dq",
            quickConsultTree: sampleTree(), signalPlayer: SignalPlayerSpy())
        vc.loadViewIfNeeded(); vc.view.frame = CGRect(x: 0, y: 0, width: 768, height: 1024); vc.view.layoutIfNeeded()
        vc.switchLayoutForTesting(to: .quick)
        XCTAssertEqual(vc.currentLayoutForTesting, .quick)
        XCTAssertNotNil(vc.quickConsultViewForTesting, "la vista ad albero è creata")
        // La radice espone SOLO il container-albero (sigillo strutturale, § 2.2).
        let exposed = vc.rootAccessibilityContainersForTesting
        XCTAssertTrue(exposed.contains { $0 === vc.quickConsultViewForTesting }, "albero è il container attivo")
        vc.switchLayoutForTesting(to: .continuous)
        XCTAssertEqual(vc.currentLayoutForTesting, .continuous, "torna a Lettura Continua")
        XCTAssertEqual(vc.renderedSegmentCountForTesting, 3)
    }

    func test_layoutSelector_doctrinePositionDoesNotCorruptContinuousSaved() {
        var saved: [Int] = []
        let vc = ContinuousReadingViewController(
            content: sampleContent(3), sourceName: "x.pdf", documentId: "d",
            onPositionChanged: { saved.append($0) },
            doctrineContent: sampleContent(7), signalPlayer: SignalPlayerSpy())
        vc.loadViewIfNeeded()
        vc.view.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        vc.view.layoutIfNeeded()
        // In dottrina, mettere a fuoco un segmento NON deve persistere la posizione (§ 2.5).
        vc.switchLayoutForTesting(to: .doctrine)
        saved.removeAll()
        do { let rv = vc.textContainerForTesting; rv.cellDidBecomeFocused(index: 5, segment: rv.currentSegments[5]) }
        XCTAssertTrue(saved.isEmpty, "in Dottrina Inline la posizione non è persistita (non corrompe il punto continua)")
        // In continua invece sì.
        vc.switchLayoutForTesting(to: .continuous)
        do { let rv = vc.textContainerForTesting; rv.cellDidBecomeFocused(index: 2, segment: rv.currentSegments[2]) }
        XCTAssertEqual(saved.last, 2, "in Lettura Continua la posizione è persistita")
    }

    func test_reader_backButtonInvokesOnBack() {
        let vc = makeLoadedReader(sampleContent(3))
        var backCalled = false
        vc.onBack = { backCalled = true }
        vc.interfaceContainerForTesting.backButton.sendActions(for: .touchUpInside)
        XCTAssertTrue(backCalled, "il tasto Indietro instrada all'azione di ritorno alla Home")
    }

    // MARK: - Segnali acustici di stato e di Layout (cablaggio agli stati reali)

    private func minimalDocument() -> ScabopdfDocument {
        ScabopdfDocument(
            schema_version: "0.7.0", document_id: "d",
            metadata: DocumentMetadata(pages_pdf: 1, page_size_pt: [595, 842], source_pdf_filename: "x.pdf"),
            profile: DocumentProfileDict(
                profile_id: "generic", editorial_family: "generic", genre: "unknown", confidence: 0.05),
            structure: [])
    }

    func test_processing_playsLoadingOnStart_thenCompletionOnSuccess() {
        let spy = SignalPlayerSpy()
        let vc = ProcessingViewController(
            fileURL: URL(fileURLWithPath: "/x.pdf"), sourceName: "x.pdf",
            processor: DocumentProcessor(extractor: FakeProgressExtractor(pages: 1)),
            signalPlayer: spy)
        vc.loadViewIfNeeded()

        vc.startSignalForTesting()
        XCTAssertEqual(spy.looped, [.loading], "all'avvio dell'elaborazione suona 'loading' in loop")

        vc.finishForTesting(.success(document: minimalDocument(), content: sampleContent(2), doctrineContent: nil))
        XCTAssertEqual(spy.stopped, [.loading], "all'esito si ferma 'loading'")
        XCTAssertEqual(spy.played, [.completion], "successo → 'completion'")
    }

    func test_processing_playsErrorOnFailure() {
        let spy = SignalPlayerSpy()
        let vc = ProcessingViewController(
            fileURL: URL(fileURLWithPath: "/x.pdf"), sourceName: "x.pdf", signalPlayer: spy)
        vc.loadViewIfNeeded()

        vc.finishForTesting(.failure(message: "PDF non leggibile"))
        XCTAssertEqual(spy.stopped, [.loading], "anche su errore si ferma 'loading'")
        XCTAssertEqual(spy.played, [.error], "fallimento → 'error'")
    }

    func test_processing_cancel_playsNeitherCompletionNorError_stopsLoading() {
        let spy = SignalPlayerSpy()
        let vc = ProcessingViewController(
            fileURL: URL(fileURLWithPath: "/x.pdf"), sourceName: "x.pdf", signalPlayer: spy)
        vc.loadViewIfNeeded()

        vc.cancelForTesting()
        XCTAssertEqual(spy.stopped, [.loading], "su annullamento si ferma 'loading'")
        XCTAssertTrue(spy.played.isEmpty, "annullamento: nessun segnale di esito (Home nuda, in silenzio)")
    }

    func test_reader_playsMode1OnAppear_onlyOnce() {
        let spy = SignalPlayerSpy()
        let vc = ContinuousReadingViewController(
            content: sampleContent(3), sourceName: "x.pdf", signalPlayer: spy)
        vc.loadViewIfNeeded()
        vc.view.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        vc.view.layoutIfNeeded()

        XCTAssertTrue(spy.played.isEmpty, "nessun segnale di Layout prima della comparsa")
        vc.viewDidAppear(false)
        XCTAssertEqual(spy.played, [.mode1], "alla comparsa di Lettura Continua suona 'mode-1'")
        vc.viewDidAppear(false)
        XCTAssertEqual(spy.played, [.mode1], "il segnale di Layout suona una sola volta")
    }

    // MARK: - Finestra di elaborazione: sigillatura modale, avanzamento, annulla idempotente

    func test_processingWindow_isModallySealed_andRendersProgress() {
        let vc = ProcessingViewController(fileURL: URL(fileURLWithPath: "/x.pdf"), sourceName: "x.pdf")
        vc.loadViewIfNeeded()   // viewDidLoad senza avviare l'elaborazione (no viewDidAppear)

        XCTAssertTrue(vc.isModalSealedForTesting, "la finestra di elaborazione è un container modale")

        vc.applyForTesting(DocumentProcessor.Progress(
            phase: .classification, unitsDone: 5, unitsTotal: 10, fraction: 0.5))
        XCTAssertEqual(vc.statusValueForTesting, "50 per cento",
                       "la percentuale puntuale è interrogabile come accessibilityValue")
        XCTAssertEqual(vc.progressFractionForTesting, 0.5, accuracy: 0.01, "la barra riflette la frazione reale")
    }

    func test_processingWindow_cancelDeliversCancelledExactlyOnce() {
        let vc = ProcessingViewController(fileURL: URL(fileURLWithPath: "/x.pdf"), sourceName: "x.pdf")
        vc.loadViewIfNeeded()

        var outcomes: [DocumentProcessor.Outcome] = []
        vc.onOutcome = { outcomes.append($0) }

        vc.cancelForTesting()
        vc.cancelForTesting()   // un secondo annullo non deve consegnare un secondo esito

        XCTAssertEqual(outcomes.count, 1, "l'esito è consegnato una sola volta (idempotente)")
        guard case .cancelled = outcomes.first else {
            return XCTFail("atteso .cancelled")
        }
    }
}

// MARK: - Parità dell'estrazione a flusso (byte-identica al caricamento tutto-insieme)
//
// L'ESTRAZIONE A FLUSSO (chunk piccolo → `PDFDocument` riaperto per chunk + `autoreleasepool` per
// pagina) produce un `PdfExtraction` BYTE-IDENTICO al caricamento storico "tutto insieme" (chunk
// enorme, un solo documento). Il chunking è SOLO gestione della memoria: la logica per-pagina è
// invariata e ogni pagina è estratta una volta, in ordine. Entrambe le estrazioni leggono lo STESSO
// file → l'eventuale non-determinismo della generazione del PDF è irrilevante. (Classe qui e non in
// un file a sé perché il target di test usa referenze esplicite.)

final class PdfExtractionParityTests: XCTestCase {

    static func makeMultiPagePDF(pages: Int) -> URL {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("scabo_parity_\(pages)_\(UUID().uuidString).pdf")
        try? renderer.writePDF(to: url) { ctx in
            for p in 0..<pages {
                ctx.beginPage()
                var y: CGFloat = 60
                let blocks: [(String, CGFloat, Bool)] = [
                    ("Capitolo \(p + 1) — Titolo della pagina \(p + 1).", 18, true),
                    ("Primo paragrafo della pagina \(p + 1): testo deterministico con parole sufficienti a occupare più righe nella colonna stretta.", 11, false),
                    ("Secondo paragrafo: \(p * 7 % 13) casi e \(p) riferimenti nella pagina \(p + 1).", 11, false),
                    ("\(p + 1). Cfr. art. \(100 + p) c.c. sulla questione della pagina.", 8, false),
                ]
                for (text, size, bold) in blocks {
                    let font: UIFont = bold ? .boldSystemFont(ofSize: size) : .systemFont(ofSize: size)
                    (text as NSString).draw(at: CGPoint(x: 72, y: y),
                                            withAttributes: [.font: font, .foregroundColor: UIColor.black])
                    y += size + 14
                }
            }
        }
        return url
    }

    private func extract(_ url: URL, chunk: Int) throws -> PdfExtraction? {
        try PdfKitExtractor().extract(
            fromUri: url.absoluteString, onPageExtracted: { _, _ in }, isCancelled: { false },
            chunkPages: chunk)
    }

    func test_streaming_producesIdenticalExtraction_asLoadAll_syntheticMultiPage() throws {
        let url = Self.makeMultiPagePDF(pages: 120)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        let streamed = try extract(url, chunk: 4)          // 30 chunk, molti riaprimenti
        let loadAll = try extract(url, chunk: 1_000_000)   // 1 chunk = caricamento tutto insieme
        XCTAssertNotNil(streamed)
        XCTAssertEqual(streamed, loadAll, "estrazione a flusso byte-identica al caricamento tutto-insieme")
        XCTAssertEqual(streamed?.pages.count, 120)
        XCTAssertEqual(streamed?.pageCount, 120)
    }

    func test_defaultProductionChunk_isIdentical_toLoadAll() throws {
        let url = Self.makeMultiPagePDF(pages: 130)  // > STREAM_CHUNK_PAGES → esercita il chunking reale
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        let production = try PdfKitExtractor().extract(fromUri: url.absoluteString)  // default chunk
        let loadAll = try extract(url, chunk: 1_000_000)
        XCTAssertEqual(production, loadAll, "il chunk di produzione (default) è identico al tutto-insieme")
    }

    func test_progressCallback_firesOncePerPage_monotonic_acrossChunks() throws {
        let url = Self.makeMultiPagePDF(pages: 45)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        var done: [Int] = []
        _ = try PdfKitExtractor().extract(
            fromUri: url.absoluteString,
            onPageExtracted: { d, t in done.append(d); XCTAssertEqual(t, 45) },
            isCancelled: { false }, chunkPages: 8)
        XCTAssertEqual(done, Array(1...45), "un tick per pagina, monotòno, attraverso i confini di chunk")
    }

    func test_cancellation_midStream_yieldsNilNoPartial() throws {
        let url = Self.makeMultiPagePDF(pages: 40)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        var seen = 0
        let out = try PdfKitExtractor().extract(
            fromUri: url.absoluteString,
            onPageExtracted: { _, _ in seen += 1 },
            isCancelled: { seen >= 10 }, chunkPages: 8)
        XCTAssertNil(out, "cancellazione a metà flusso → nil, nessuna estrazione parziale spacciata per completa")
    }

    func test_streamingParity_onRealFixture_patriarca() throws {
        let fixture = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("pipeline/tests/fixtures/private/patriarca_benazzo.pdf")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: fixture.path),
                          "Fixture privato assente: \(fixture.path)")
        let streamed = try extract(fixture, chunk: 10)
        let loadAll = try extract(fixture, chunk: 1_000_000)
        XCTAssertEqual(streamed, loadAll, "estrazione a flusso byte-identica sul PDF reale")
    }
}
