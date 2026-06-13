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
        guard case .success(_, let content)? = outcome else {
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

    func test_reader_exposesTwoDistinctOrderedContainers() {
        let content = sampleContent(5)
        let vc = makeLoadedReader(content)

        // La radice espone ESATTAMENTE due container, nell'ordine [interfaccia, testo]: l'ordine
        // è voluto perché l'unica giunzione possibile dello swipe lineare sia [interfaccia ↔
        // inizio del testo] (vedi nota di testata del VC).
        let roots = vc.rootAccessibilityContainersForTesting
        XCTAssertEqual(roots.count, 2, "due container principali")
        XCTAssertTrue(roots[0] === vc.interfaceContainerForTesting, "l'interfaccia precede il testo")
        XCTAssertTrue(roots[1] === vc.textContainerForTesting)
        XCTAssertFalse(roots[0] === roots[1], "i due container sono oggetti distinti")
    }

    func test_reader_textContainerExposesOnlySegments_interfaceOnlyTitleAndBack() {
        let content = sampleContent(5)
        let vc = makeLoadedReader(content)

        // Container del TESTO: solo segmenti, uno per ogni segmento del contenuto.
        let textElements = vc.textContainerForTesting.exposedAccessibilityElements
        XCTAssertEqual(textElements.count, content.totalSegments)
        for element in textElements {
            XCTAssertTrue(element is SegmentLabel, "il container del testo espone solo segmenti")
        }

        // Container dell'INTERFACCIA: solo [Indietro, titolo].
        let interface = vc.interfaceContainerForTesting
        let interfaceElements = (interface.accessibilityElements as? [NSObject]) ?? []
        XCTAssertEqual(interfaceElements.count, 2, "interfaccia: solo titolo + Indietro")
        XCTAssertTrue(interfaceElements.contains { ($0 as? UIButton) === interface.backButton })
        XCTAssertTrue(interfaceElements.contains { ($0 as? UILabel) === interface.titleLabel })
        XCTAssertEqual(interface.titleLabel.text, "Lettura Continua")
        XCTAssertEqual(interface.backButton.accessibilityLabel, "Indietro")
        for element in interfaceElements {
            XCTAssertFalse(element is SegmentLabel, "nessun elemento di testo nell'interfaccia")
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
        // Scenario blindato (§ 2.2): all'ingresso il container del testo è il modale attivo → lo
        // swipe lineare vi resta confinato e non può sconfinare sull'interfaccia.
        let vc = makeLoadedReader(sampleContent(4))
        XCTAssertTrue(vc.textContainerIsModalForTesting, "il testo è il container modale attivo")
        XCTAssertFalse(vc.interfaceContainerIsModalForTesting, "l'interfaccia non è il modale attivo")
    }

    func test_reader_scrubTogglesActiveModalContainer_bothDirections() {
        let vc = makeLoadedReader(sampleContent(4))

        // Lo scrub a due dita (escape) è l'unica via di passaggio: commuta quale container è
        // modale, in entrambe le direzioni. (Lo spostamento effettivo del fuoco è runtime
        // VoiceOver, certificato sul dispositivo.)
        XCTAssertTrue(vc.textContainerIsModalForTesting, "stato iniziale: testo modale")

        XCTAssertTrue(vc.textContainerForTesting.accessibilityPerformEscape(), "scrub gestito")
        XCTAssertFalse(vc.textContainerIsModalForTesting)
        XCTAssertTrue(vc.interfaceContainerIsModalForTesting, "scrub dal testo → interfaccia modale")

        XCTAssertTrue(vc.interfaceContainerForTesting.accessibilityPerformEscape(), "scrub gestito")
        XCTAssertTrue(vc.textContainerIsModalForTesting, "scrub dall'interfaccia → di nuovo testo modale")
        XCTAssertFalse(vc.interfaceContainerIsModalForTesting)
    }

    func test_reader_returningToText_preservesReadingPosition() {
        // Correzione del reset di posizione: il rientro nel testo dall'interfaccia torna DOVE
        // l'utente era, non al primissimo elemento.
        let content = sampleContent(6)
        let vc = makeLoadedReader(content)
        let labels = vc.textContainerForTesting.segmentLabels
        XCTAssertGreaterThan(labels.count, 3)

        // L'utente legge fino a un elemento centrale: VoiceOver lo mette a fuoco.
        let middle = labels[3]
        middle.accessibilityElementDidBecomeFocused()
        XCTAssertTrue(vc.textFocusRestoreTargetForTesting === middle, "la posizione di lettura è ricordata")

        // Va all'interfaccia (scrub) e torna al testo (scrub).
        XCTAssertTrue(vc.textContainerForTesting.accessibilityPerformEscape())      // testo → interfaccia
        XCTAssertTrue(vc.interfaceContainerForTesting.accessibilityPerformEscape()) // interfaccia → testo

        // Il rientro NON resetta: il bersaglio di ripristino è ancora l'elemento centrale.
        XCTAssertTrue(vc.textFocusRestoreTargetForTesting === middle,
                      "il rientro nel testo riporta dove l'utente era, non al primissimo elemento")
        XCTAssertFalse(vc.textFocusRestoreTargetForTesting === labels[0],
                       "non si torna al primo elemento")
    }

    func test_reader_backButtonInvokesOnBack() {
        let vc = makeLoadedReader(sampleContent(3))
        var backCalled = false
        vc.onBack = { backCalled = true }
        vc.interfaceContainerForTesting.backButton.sendActions(for: .touchUpInside)
        XCTAssertTrue(backCalled, "il tasto Indietro instrada all'azione di ritorno alla Home")
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
