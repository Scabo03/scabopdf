//
//  BookSearchAppTests.swift
//  ScaboAppTests
//
//  La ricerca dentro il libro nell'app (giro «ricerca nel libro», 2026-10-19; LAYER2 § 13.3): tasti, rotore
//  «Risultati della ricerca», valore parlato, evidenza, salto col fuoco, ritorno, chiusura, finestra dei risultati.
//  Testi INVENTATI, mai di un volume. La finestra con VoiceOver vero la provano i test d'interfaccia.
//

import UIKit
import XCTest

@testable import ScaboApp
import ScaboChain
import ScaboCore

/// Nessun suono nelle prove: il segnale del Layout attiverebbe la sessione audio sul thread principale, e Xcode 27 tratta
/// l'avviso «rischio di blocco» raccogliendo per dieci minuti una diagnosi del simulatore (campo, 2026-10-19).
private final class SilentSearchSignals: SignalPlaying {
    func play(_ signal: AudioSignal) {}
    func playLooping(_ signal: AudioSignal) {}
    func stop(_ signal: AudioSignal) {}
}

final class BookSearchAppTests: XCTestCase {

    private func seg(_ id: String, _ role: String, _ text: String) -> ContentSegment {
        ContentSegment(id: id, role: role, text: text, lengthCategory: role == "NOTE" ? "SHORT" : "", acousticIntro: "")
    }

    /// Un libro inventato: due capitoli, una nota, il «faro» in tre elementi (uno nel titolo, uno con due occorrenze).
    private func book() -> [ContentSegment] {
        [
            seg("h1", "HEADING_1", "Capitolo primo. Il porto"),
            seg("b1", "BODY", "Le barche rientrano la sera quando il faro si accende sulla scogliera."),
            seg("b2", "BODY", "Il pescatore conta le reti e guarda il mare calmo."),
            seg("n1", "NOTE", "1 Il faro di cui si parla fu costruito in pietra chiara."),
            seg("h2", "HEADING_1", "Capitolo secondo. Il faro"),
            seg("b3", "BODY", "Di notte il faro gira, e il faro avverte le navi lontane."),
            seg("b4", "BODY", "All'alba la luce si spegne e il porto si sveglia."),
        ]
    }

    private func content(_ segs: [ContentSegment]) -> PaginatedContent {
        PaginatedContent(pages: [ContentPage(pageNumber: 1, segments: segs)], totalSegments: segs.count)
    }

    private func window(with view: UIView) -> UIWindow {
        let w = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        view.frame = w.bounds
        w.addSubview(view)
        w.makeKeyAndVisible()
        view.layoutIfNeeded()
        return w
    }

    // MARK: Tasti (catalogo unico)

    func test_catalog_searchKeys_areCommandF_CommandG_ShiftCommandG_andDescribed() {
        let r = KeyboardCommandsCatalog.reading
        let search = r.first { $0.id == "search" }, next = r.first { $0.id == "nextResult" }, prev = r.first { $0.id == "prevResult" }
        XCTAssertEqual(search?.input, "f"); XCTAssertEqual(search?.modifiers, .command)
        XCTAssertEqual(next?.input, "g"); XCTAssertEqual(next?.modifiers, .command)
        XCTAssertEqual(prev?.input, "g"); XCTAssertEqual(prev?.modifiers, [.command, .shift])
        XCTAssertEqual(prev?.spokenKeys, "Comando più Maiuscole più tasto G")
        for spec in [search, next, prev] {
            XCTAssertFalse(spec?.description.isEmpty ?? true)
            XCTAssertTrue(ContinuousReadingViewController.hasKeyboardAction(forCommandId: spec!.id))
        }
        XCTAssertTrue(search!.description.contains("note"), "dice che trova anche il testo delle note")
    }

    // MARK: Vista di lettura

    func test_readingView_searchRotor_onlyWithResults_andFirst() {
        let view = ContinuousReadingView(frame: .zero)
        view.signalPlayer = SilentSearchSignals()
        let w = window(with: view)
        defer { w.isHidden = true }
        let segs = book()
        view.render(segs)
        XCTAssertFalse(view.customRotorNamesForTesting.contains(ContinuousReadingView.searchRotorName))
        let corpus = BookSearchCorpus(segments: segs)
        view.setSearchResult(corpus.search("faro"), highlighter: nil)
        XCTAssertEqual(view.customRotorNamesForTesting.first, "Risultati della ricerca")
        view.setSearchResult(corpus.search("nessunaparola"), highlighter: nil)
        XCTAssertFalse(view.customRotorNamesForTesting.contains(ContinuousReadingView.searchRotorName), "zero risultati: niente rotore")
        view.setSearchResult(nil, highlighter: nil)
        XCTAssertFalse(view.customRotorNamesForTesting.contains(ContinuousReadingView.searchRotorName))
    }

    func test_readingView_rotorAndKeys_stopOnEveryElementWithResults_inOrder_withoutDeadEnds() {
        let view = ContinuousReadingView(frame: .zero)
        view.signalPlayer = SilentSearchSignals()
        let w = window(with: view)
        defer { w.isHidden = true }
        let segs = book()
        view.render(segs)
        let r = BookSearchCorpus(segments: segs).search("faro")
        XCTAssertEqual(r.totalCount, 5)
        XCTAssertEqual(r.elementIndices, [1, 3, 4, 5])
        view.setSearchResult(r, highlighter: nil)
        // Rotore come VoiceOver: dall'inizio in avanti, poi all'indietro.
        XCTAssertEqual(view.searchRotorStepForTesting(from: nil, forward: true), 1)
        XCTAssertEqual(view.searchRotorStepForTesting(from: 1, forward: true), 3)
        XCTAssertEqual(view.searchRotorStepForTesting(from: 3, forward: true), 4)
        XCTAssertEqual(view.searchRotorStepForTesting(from: 4, forward: true), 5)
        XCTAssertNil(view.searchRotorStepForTesting(from: 5, forward: true), "dopo l'ultimo: fine, come il rotore dei titoli")
        XCTAssertEqual(view.searchRotorStepForTesting(from: 5, forward: false), 4)
        // Tasti: dal punto in lettura.
        view.cellDidBecomeFocused(index: 2, segment: segs[2])
        XCTAssertEqual(view.goToAdjacentSearchResult(forward: true), 3)
        XCTAssertEqual(view.goToAdjacentSearchResult(forward: false), 1)
        XCTAssertNil(view.goToAdjacentSearchResult(forward: false), "prima del primo: niente, la lettura resta")
        XCTAssertEqual(view.currentOrTopIndex, 1)
    }

    func test_readingView_valueSaysWhichResults_andCellsShowThemInverted() {
        let view = ContinuousReadingView(frame: .zero)
        view.signalPlayer = SilentSearchSignals()
        let w = window(with: view)
        defer { w.isHidden = true }
        let segs = book()
        view.render(segs)
        let corpus = BookSearchCorpus(segments: segs)
        let r = corpus.search("faro")
        view.setSearchResult(r) { i, text in corpus.highlightRanges(forSegment: i, text: text, hits: r.hits(touching: i)) }
        XCTAssertEqual(view.searchValue(forIndex: 1), "risultato 1 di 5")
        XCTAssertEqual(view.searchValue(forIndex: 5), "risultati 4 e 5 di 5")
        XCTAssertNil(view.searchValue(forIndex: 2))
        let cell = view.makeConfiguredCellForTesting(at: 5)!
        XCTAssertEqual(cell.accessibilityValue, "risultati 4 e 5 di 5")
        let label = cell.accessibilityLabel ?? ""
        XCTAssertTrue(label.contains("Di notte il faro gira"), "il parlato del testo non cambia")
        let attributed = cell.textLabel.attributedText!
        let ns = segs[5].text as NSString
        let first = ns.range(of: "faro")
        XCTAssertNotNil(attributed.attribute(.backgroundColor, at: first.location, effectiveRange: nil), "evidenza sul risultato")
        XCTAssertNil(attributed.attribute(.backgroundColor, at: 0, effectiveRange: nil), "nessuna evidenza fuori")
        view.setSearchResult(nil, highlighter: nil)
        let plain = view.makeConfiguredCellForTesting(at: 5)!
        XCTAssertNil(plain.accessibilityValue)
        XCTAssertNil(plain.textLabel.attributedText?.attribute(.backgroundColor, at: first.location, effectiveRange: nil))
    }

    func test_readingView_newContent_dropsTheSearch() {
        let view = ContinuousReadingView(frame: .zero)
        view.signalPlayer = SilentSearchSignals()
        let w = window(with: view)
        defer { w.isHidden = true }
        let segs = book()
        view.render(segs)
        view.setSearchResult(BookSearchCorpus(segments: segs).search("faro"), highlighter: nil)
        view.render(Array(segs.prefix(3)))
        XCTAssertNil(view.searchResult, "un altro flusso (per esempio Dottrina Inline): le fermate erano dell'altro")
    }

    // MARK: Lettore

    func test_reader_jumpToAResult_inContinuousReading_atTheRightElement_andBackWhereYouWere() {
        let segs = book()
        let vc = ContinuousReadingViewController(content: content(segs), documentId: "", signalPlayer: SilentSearchSignals())
        let w = window(with: vc.view)
        defer { w.isHidden = true }
        vc.loadViewIfNeeded()
        let view = vc.textContainerForTesting
        view.cellDidBecomeFocused(index: 2, segment: segs[2])      // si leggeva qui
        let session = vc.searchSessionForTesting
        let r = session.searchNow("pietra chiara", wholeWord: false)
        XCTAssertEqual(r.totalCount, 1)
        XCTAssertTrue(r.hits[0].isInNote)
        vc.applySearchForTesting()
        XCTAssertFalse(vc.interfaceContainerForTesting.nextResultButton.isHidden, "frecce dei risultati in barra")
        XCTAssertEqual(vc.interfaceContainerForTesting.searchButton.accessibilityValue, "Un risultato per «pietra chiara»")
        vc.jumpToSearchHitForTesting(r.hits[0])
        XCTAssertEqual(view.currentOrTopIndex, 3, "l'elemento che contiene il risultato (la nota)")
        XCTAssertEqual(session.positionBeforeSearch, 2, "si ricorda dove si leggeva")
        vc.returnToPositionBeforeSearchForTesting()
        XCTAssertEqual(view.currentOrTopIndex, 2, "«Torna dove leggevi»")
        XCTAssertNil(session.positionBeforeSearch)
        XCTAssertTrue(session.isActive, "la ricerca resta")
        vc.endSearchForTesting()
        XCTAssertFalse(session.isActive)
        XCTAssertTrue(vc.interfaceContainerForTesting.nextResultButton.isHidden)
        XCTAssertFalse(view.customRotorNamesForTesting.contains(ContinuousReadingView.searchRotorName))
        XCTAssertEqual(view.currentOrTopIndex, 2, "chiudere la ricerca non sposta la lettura")
    }

    func test_reader_keysWithoutASearch_doNotMove() {
        let segs = book()
        let vc = ContinuousReadingViewController(content: content(segs), documentId: "", signalPlayer: SilentSearchSignals())
        let w = window(with: vc.view)
        defer { w.isHidden = true }
        let view = vc.textContainerForTesting
        view.cellDidBecomeFocused(index: 2, segment: segs[2])
        vc.goToAdjacentSearchResultForTesting(forward: true)
        XCTAssertEqual(view.currentOrTopIndex, 2)
    }

    func test_reader_resultChosenFromDoctrineInline_isShownInContinuousReading() {
        let segs = book()
        let vc = ContinuousReadingViewController(content: content(segs), documentId: "", doctrineContent: content(segs),
                                                 signalPlayer: SilentSearchSignals())
        let w = window(with: vc.view)
        defer { w.isHidden = true }
        vc.switchLayoutForTesting(to: .doctrine)
        XCTAssertEqual(vc.currentLayoutForTesting, .doctrine)
        let r = vc.searchSessionForTesting.searchNow("alba", wholeWord: false)
        vc.applySearchForTesting()
        XCTAssertNil(vc.textContainerForTesting.searchResult, "in Dottrina Inline la vista non ha le fermate")
        vc.jumpToSearchHitForTesting(r.hits[0])
        XCTAssertEqual(vc.currentLayoutForTesting, .continuous, "il risultato si legge in Lettura Continua (§ 13.3)")
        XCTAssertEqual(vc.textContainerForTesting.currentOrTopIndex, 6)
        XCTAssertNotNil(vc.textContainerForTesting.searchResult, "tornati in Lettura Continua: rotore e valori ci sono")
    }

    /// Con un'altra finestra sopra il lettore, nessun comando del lettore (Esc non chiude la lettura nascosta); con la
    /// finestra della ricerca, solo Esc, che la chiude come «Annulla».
    func test_reader_keyCommands_withAWindowOnTop() {
        let segs = book()
        let vc = ContinuousReadingViewController(content: content(segs), documentId: "", signalPlayer: SilentSearchSignals())
        let w = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        w.rootViewController = vc
        w.makeKeyAndVisible()
        defer { w.isHidden = true }
        XCTAssertTrue((vc.keyCommands ?? []).contains { $0.input == "f" && $0.modifierFlags == .command }, "⌘F nel lettore")
        let other = UIViewController()
        vc.present(other, animated: false)
        XCTAssertEqual(vc.keyCommands?.count, 0, "con una finestra sopra, nessun comando del lettore")
        other.dismiss(animated: false)
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))   // la chiusura si completa prima di aprirne un'altra
        XCTAssertNil(vc.presentedViewController)
        vc.openSearch()
        RunLoop.main.run(until: Date().addingTimeInterval(1.0))
        XCTAssertNotNil(vc.presentedViewController, "la finestra della ricerca è aperta")
        let commands = vc.keyCommands ?? []
        XCTAssertEqual(commands.count, 1)
        XCTAssertEqual(commands.first?.input, UIKeyCommand.inputEscape, "con la ricerca aperta, solo Esc (Annulla)")
        vc.presentedViewController?.dismiss(animated: false)
    }

    func test_bar_searchControls_order() {
        let bar = ReadingInterfaceBar()
        bar.setSearchControls(available: true, activeSummary: nil)
        var labels = (bar.accessibilityElements as? [NSObject])?.compactMap { $0.accessibilityLabel } ?? []
        XCTAssertEqual(Array(labels.prefix(3)), ["Indietro", "Layout di lettura, Lettura Continua", "Cerca nel libro"])
        bar.setSearchControls(available: true, activeSummary: "2 risultati per «x»")
        labels = (bar.accessibilityElements as? [NSObject])?.compactMap { $0.accessibilityLabel } ?? []
        XCTAssertEqual(Array(labels.prefix(5)), ["Indietro", "Layout di lettura, Lettura Continua", "Cerca nel libro",
                                                 "Risultato precedente", "Risultato successivo"])
        XCTAssertEqual(bar.searchButton.accessibilityValue, "2 risultati per «x»")
    }

    /// Con il pulsante della ricerca e le due frecce la barra non tronca mai il selettore, a ogni larghezza e dimensione del
    /// testo, e nessun pulsante si sovrappone a un altro (la barra va su più righe quando serve); ogni pulsante della
    /// ricerca è ≥ 44×44.
    func test_bar_withTheSearchControls_neverTruncates_andKeepsTargetsAt44() throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("traitOverrides richiede iOS 17") }
        for width in [320.0, 375.0, 393.0, 440.0, 744.0, 834.0, 1024.0] {
            for category in [UIContentSizeCategory.large, .extraExtraExtraLarge, .accessibilityExtraExtraExtraLarge] {
                let host = UIView(frame: CGRect(x: 0, y: 0, width: width, height: 700))
                let bar = ReadingInterfaceBar()
                bar.translatesAutoresizingMaskIntoConstraints = false
                host.traitOverrides.preferredContentSizeCategory = category
                host.addSubview(bar)
                NSLayoutConstraint.activate([
                    bar.topAnchor.constraint(equalTo: host.topAnchor),
                    bar.leadingAnchor.constraint(equalTo: host.leadingAnchor),
                    bar.trailingAnchor.constraint(equalTo: host.trailingAnchor),
                    bar.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
                ])
                bar.setTextSizeControls(available: true)
                bar.setBookmarksAvailable(true)
                bar.setSearchControls(available: true, activeSummary: "12 risultati per «x»")
                // Anche con i comandi della Consultazione Rapida accesi (revisione del giro: non era provato).
                bar.setQuickControls(visible: true, canNavigate: true)
                bar.setPageIndicator(visualizationCurrent: 0, visualizationTotal: 0, originalCurrent: 412, originalTotal: 1559,
                                     showOriginal: true)
                let window = UIWindow(frame: host.frame)
                window.addSubview(host)
                window.isHidden = false
                for _ in 0..<3 { host.setNeedsLayout(); host.layoutIfNeeded() }
                let label = "larghezza \(Int(width)), \(category.rawValue)"
                let title = try XCTUnwrap(bar.layoutSelectorButton.titleLabel)
                XCTAssertGreaterThan(title.bounds.width, 0, label)
                let needed = title.sizeThatFits(CGSize(width: title.bounds.width, height: .greatestFiniteMagnitude))
                XCTAssertLessThanOrEqual(needed.height, title.bounds.height + 1, "il titolo sta tutto: \(label)")
                let buttons: [UIView] = [bar.backButton, bar.layoutSelectorButton, bar.searchButton, bar.prevResultButton,
                                         bar.nextResultButton, bar.bookmarksButton, bar.decreaseTextSizeButton,
                                         bar.increaseTextSizeButton, bar.resetStructureButton, bar.prevExpandedButton,
                                         bar.nextExpandedButton]
                let frames = buttons.map { $0.convert($0.bounds, to: bar) }
                for i in frames.indices { for j in frames.indices where j > i {
                    XCTAssertFalse(frames[i].insetBy(dx: 0.5, dy: 0.5).intersects(frames[j].insetBy(dx: 0.5, dy: 0.5)),
                                   "\(buttons[i].accessibilityLabel ?? "?") e \(buttons[j].accessibilityLabel ?? "?"): \(label)")
                } }
                for b in [bar.searchButton, bar.prevResultButton, bar.nextResultButton] {
                    XCTAssertGreaterThanOrEqual(b.frame.width, 44, label)
                    XCTAssertGreaterThanOrEqual(b.frame.height, 44, label)
                }
                window.isHidden = true
            }
        }
    }

    // MARK: Finestra dei risultati

    func test_window_countIsSaidFirst_andRowsSayContextNoteSectionPage() {
        let segs = book()
        let session = BookSearchSession(segments: segs)
        let pages: [String: Int] = ["b1": 3, "n1": 3, "h2": 4, "b3": 4]
        let vc = BookSearchViewController.makeForTesting(session: session, pageProvider: { pages[$0] })
        vc.loadViewIfNeeded()
        XCTAssertTrue(vc.countSentence.hasPrefix("Scrivi una parola o una frase"), "prima di cercare: che cosa fare")
        vc.searchField.text = "faro"
        let done = expectation(description: "ricerca")
        vc.runSearch(moveFocusToCount: true) { done.fulfill() }
        wait(for: [done], timeout: 5)
        XCTAssertEqual(vc.countSentence, "5 risultati per «faro».")
        XCTAssertEqual(vc.resultRowCountForTesting, 5)
        XCTAssertEqual(vc.rowLabelForTesting(0), "Le barche rientrano la sera quando il faro si accende sulla scogliera. "
                       + "Capitolo primo. Il porto, pagina 3.")
        let noteRow = vc.rowLabelForTesting(1) ?? ""
        XCTAssertTrue(noteRow.contains("Nella nota 1, Capitolo primo. Il porto, pagina 3."), noteRow)
        XCTAssertTrue(vc.rowLabelForTesting(2)?.hasSuffix("Nel titolo, pagina 4.") ?? false, vc.rowLabelForTesting(2) ?? "")
    }

    func test_window_zeroResults_sayWhyAndWhatToTry() {
        let session = BookSearchSession(segments: book())
        let vc = BookSearchViewController.makeForTesting(session: session)
        vc.loadViewIfNeeded()
        vc.searchField.text = "far"
        vc.wholeWordSwitch.isOn = true
        let done = expectation(description: "ricerca")
        vc.runSearch(moveFocusToCount: true) { done.fulfill() }
        wait(for: [done], timeout: 5)
        XCTAssertTrue(vc.countSentence.hasPrefix("Nessun risultato per «far»."), vc.countSentence)
        XCTAssertTrue(vc.countSentence.contains("togliere «Parola intera»"), vc.countSentence)
    }

    func test_window_choosingAResult_hasOneExit_withThatResult() {
        let session = BookSearchSession(segments: book())
        var chosen: [BookSearchHit] = []
        let vc = BookSearchViewController.makeForTesting(session: session) { chosen.append($0) }
        vc.loadViewIfNeeded()
        vc.searchField.text = "alba"
        let done = expectation(description: "ricerca")
        vc.runSearch(moveFocusToCount: true) { done.fulfill() }
        wait(for: [done], timeout: 5)
        vc.chooseResultForTesting(0)
        vc.chooseResultForTesting(0)   // una sola uscita per apertura
        XCTAssertEqual(chosen.map(\.segmentIndex), [6])
    }

    /// Lo scrub a due dita di VoiceOver (`accessibilityPerformEscape`) è «Annulla»: chiude la finestra senza scegliere
    /// nulla, una volta sola.
    func test_window_voiceOverScrub_isCancel_once() {
        let session = BookSearchSession(segments: book())
        var cancelled = 0
        let vc = BookSearchViewController.makeForTestingObservingCancel(session: session) { cancelled += 1 }
        vc.loadViewIfNeeded()
        XCTAssertTrue(vc.accessibilityPerformEscape())
        XCTAssertEqual(cancelled, 1)
        XCTAssertTrue(vc.accessibilityPerformEscape())
        XCTAssertEqual(cancelled, 1, "una sola uscita per apertura")
    }

    /// Riaperta su una ricerca in corso, la finestra riceve i tasti (Esc = Annulla, ⌘F = il campo), come dopo «Cerca»: nello
    /// split, se no, Esc non la chiudeva (revisione del giro).
    func test_window_reopenedOnASearch_receivesTheKeys() {
        let session = BookSearchSession(segments: book())
        session.searchNow("faro", wholeWord: false)
        let vc = BookSearchViewController.makeForTesting(session: session)
        let w = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        w.rootViewController = vc
        w.makeKeyAndVisible()
        defer { w.isHidden = true }
        vc.viewDidAppear(false)
        XCTAssertTrue(vc.isFirstResponder, "la finestra è destinataria dei tasti")
        XCTAssertTrue(vc.keyCommands?.contains { $0.input == UIKeyCommand.inputEscape } ?? false)
    }

    /// «Torna dove leggevi» vale per una ricerca: una ricerca diversa lo azzera, la stessa rifatta no.
    func test_session_positionBeforeSearch_isPerSearch() {
        let session = BookSearchSession(segments: book())
        session.searchNow("faro", wholeWord: false)
        session.positionBeforeSearch = 2
        session.searchNow("faro", wholeWord: false)
        XCTAssertEqual(session.positionBeforeSearch, 2, "la stessa ricerca rifatta lo tiene")
        session.searchNow("FARO", wholeWord: false)
        XCTAssertEqual(session.positionBeforeSearch, 2, "le stesse parole, maiuscole indifferenti")
        session.searchNow("faro", wholeWord: true)
        XCTAssertNil(session.positionBeforeSearch, "l'altra «Parola intera» è una ricerca diversa")
        session.positionBeforeSearch = 3
        session.searchNow("porto", wholeWord: true)
        XCTAssertNil(session.positionBeforeSearch, "altre parole: una ricerca diversa")
    }

    /// Senza VoiceOver un salto al primo elemento è una posizione di lettura: ⌘G riparte da lì (revisione del giro).
    func test_readingView_jumpToTheFirstElement_isAReadingPosition() {
        let view = ContinuousReadingView(frame: .zero)
        view.signalPlayer = SilentSearchSignals()
        let w = window(with: view)
        defer { w.isHidden = true }
        let segs = book()
        view.render(segs)
        let r = BookSearchCorpus(segments: segs).search("porto")
        XCTAssertEqual(r.elementIndices, [0, 6])
        view.setSearchResult(r, highlighter: nil)
        view.goToElement(atIndex: 6, focus: false)
        view.goToElement(atIndex: 0, focus: false)
        XCTAssertEqual(view.currentReadingElementIndex, 0)
        XCTAssertEqual(view.goToAdjacentSearchResult(forward: true), 6, "dal primo elemento, il risultato dopo")
    }

    /// In Consultazione Rapida «Annulla» riporta il fuoco alla riga di prima: l'albero dà l'elemento di ogni riga, anche
    /// fuori dallo schermo (la porta in vista), e niente per una riga che non c'è.
    func test_quickTree_rowElement_isTheCellOfThatRow() {
        let leaves = (0..<60).map { i in
            QuickConsultNode(role: "HEADING_2", depth: 2, title: "Capo \(i + 1)", headingId: "h\(i)",
                             firstPage: 0, lastPage: 0, children: [], contentIds: [])
        }
        let tree = QuickConsultView(roots: leaves, nodeText: [:], documentTitle: "Libro")
        let w = window(with: tree)
        defer { w.isHidden = true }
        let first = tree.rowElement(0) as? UITableViewCell
        XCTAssertNotNil(first)
        let far = tree.rowElement(55) as? UITableViewCell
        XCTAssertNotNil(far, "una riga lontana si porta in vista")
        XCTAssertTrue(far?.accessibilityLabel?.contains("Capo 56") ?? false, far?.accessibilityLabel ?? "")
        XCTAssertNil(tree.rowElement(60))
        XCTAssertNil(tree.rowElement(-1))
    }

    func test_session_buildsTheTextOnce_andReleasesItOnlyWhenIdle() {
        let session = BookSearchSession(segments: book())
        session.searchNow("faro", wholeWord: false)
        XCTAssertNotNil(session.lastBuildDuration, "la prima ricerca costruisce il testo")
        session.searchNow("porto", wholeWord: false)
        XCTAssertNil(session.lastBuildDuration, "le altre lo riusano")
        session.releaseCorpusIfIdle()
        XCTAssertNotNil(session.corpus, "ricerca attiva: il testo resta")
        session.end()
        session.releaseCorpusIfIdle()
        XCTAssertNil(session.corpus)
    }
}

/// BANCO DELLA RICERCA sui volumi veri (giro «ricerca nel libro», 2026-10-19): per ogni PDF della richiesta
/// (`/tmp/scabo_search_bench_request.json`, o `SCABO_SEARCH_BENCH_REQUEST`) l'elaborazione vera dell'iPad (granularità
/// dell'app: 1200 per i volumi grandi), il lettore vero in una finestra, poi la ricerca come la fa l'app: memoria prima e
/// dopo il testo normalizzato (picco campionato), tempo della prima ricerca (costruzione compresa) e delle altre, tempo
/// della ricerca «al volo» (testo ricostruito ogni volta), il tempo delle prime righe dei risultati, e per un campione di
/// risultati il SALTO del lettore: l'elemento raggiunto deve contenere davvero il testo cercato (rete di posizione). Le
/// domande si prendono dal flusso stesso con un seme fisso; l'uscita ha SOLO numeri (nessun testo dei volumi).
/// `XCTSkip` senza richiesta.
final class BookSearchBenchTests: XCTestCase {

    private struct Request: Decodable {
        let corpusDir: String
        let outDir: String
        let pdfs: [String]
        var positionsPerVolume: Int? = nil
    }

    private final class Silent: SignalPlaying {
        func play(_ signal: AudioSignal) {}
        func playLooping(_ signal: AudioSignal) {}
        func stop(_ signal: AudioSignal) {}
    }

    private struct Rng { var s: UInt64; mutating func next() -> UInt64 { s = s &* 6364136223846793005 &+ 1442695040888963407; return s >> 11 } }

    func test_bookSearchBench_fromRequest() throws {
        let reqPath = ProcessInfo.processInfo.environment["SCABO_SEARCH_BENCH_REQUEST"] ?? "/tmp/scabo_search_bench_request.json"
        guard let data = FileManager.default.contents(atPath: reqPath),
              let req = try? JSONDecoder().decode(Request.self, from: data) else {
            throw XCTSkip("nessuna richiesta del banco della ricerca in \(reqPath).")
        }
        try? FileManager.default.createDirectory(atPath: req.outDir, withIntermediateDirectories: true)
        var report: [[String: Any]] = []
        for name in req.pdfs {
            let path = req.corpusDir + "/" + name
            guard FileManager.default.fileExists(atPath: path) else { print("[ricerca-banco] assente: \(name)"); continue }
            let url = URL(fileURLWithPath: path)
            let pageCount = CGPDFDocument(url as CFURL)?.numberOfPages ?? 0
            let large = ReadingAssembly.isLarge(pageCount: pageCount)
            let target = large ? ReadingAssembly.largeDocumentGranularity : DEFAULT_GRANULARITY_TARGET
            let processor = DocumentProcessor()
            let done = expectation(description: "elaborazione \(name)")
            var outcome: DocumentProcessor.Outcome?
            processor.process(fileURL: url, sourceName: url.lastPathComponent, granularityTarget: target,
                              buildDoctrine: !large, onProgress: { _ in }, completion: { outcome = $0; done.fulfill() })
            wait(for: [done], timeout: 3600)
            guard case .success(let document, let content, let doctrine)? = outcome else {
                XCTFail("[ricerca-banco] \(name): elaborazione non riuscita"); continue
            }
            let pageMap = ReadingAssembly.buildPageMap(document, content: content, doctrineContent: doctrine)
            let segs = content.pages.flatMap { $0.segments }
            autoreleasepool {
                let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 820, height: 1180))
                let vc = ContinuousReadingViewController(content: content, sourceName: name, documentId: "",
                                                         sourcePageCount: pageCount, showOriginalPages: true,
                                                         sourcePage: { pageMap[$0] }, doctrineContent: doctrine,
                                                         signalPlayer: Silent())
                window.rootViewController = vc
                window.makeKeyAndVisible()
                vc.view.layoutIfNeeded()
                RunLoop.main.run(until: Date().addingTimeInterval(1.0))
                let mem0 = physFootprintMB()
                // Domande dal flusso, seme fisso per volume.
                var rng = Rng(s: UInt64(truncatingIfNeeded: name.utf8.reduce(5381) { ($0 << 5) &+ $0 &+ UInt64($1) }))
                let texted = segs.indices.filter { segs[$0].role != VISUAL_RESOURCE_ROLE && segs[$0].text.count > 40 }
                func words(_ i: Int) -> [Substring] { segs[i].text.split(whereSeparator: { $0.isWhitespace }) }
                var queries: [(kind: String, q: String, whole: Bool)] = []
                for _ in 0..<6 where !texted.isEmpty {
                    let w = words(texted[Int(rng.next() % UInt64(texted.count))]).filter { $0.count >= 5 }
                    if let x = w.first { queries.append(("parola", String(x), false)) }
                }
                for _ in 0..<4 where !texted.isEmpty {
                    let w = words(texted[Int(rng.next() % UInt64(texted.count))])
                    if w.count >= 4 { queries.append(("frase", w[1...3].joined(separator: " "), false)) }
                }
                let bodyPairs = segs.indices.dropLast().filter { segs[$0].role == "BODY" && segs[$0 + 1].role == "BODY" }
                for _ in 0..<3 where !bodyPairs.isEmpty {
                    let i = bodyPairs[Int(rng.next() % UInt64(bodyPairs.count))]
                    let a = words(i), b = words(i + 1)
                    if let x = a.last, let y = b.first { queries.append(("cavallo", "\(x) \(y)", false)) }
                }
                queries += [("frequente", "di", true), ("frequente", "e", true), ("frequente", "la", false)]
                let session = vc.searchSessionForTesting
                let peak = PeakBox(mem0)
                let sampler = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
                sampler.schedule(deadline: .now(), repeating: .milliseconds(5))
                sampler.setEventHandler { peak.update(physFootprintMB()) }
                sampler.resume()
                var perQuery: [[String: Any]] = []
                var firstTotal = 0.0, build = 0.0
                for (k, item) in queries.enumerated() {
                    let t0 = Date()
                    let r = session.searchNow(item.q, wholeWord: item.whole)
                    let dt = Date().timeIntervalSince(t0)
                    if k == 0 { firstTotal = dt; build = session.lastBuildDuration ?? 0 }
                    // Le prime 10 righe dei risultati (contesto, sezione, pagina): ciò che serve per mostrare la finestra.
                    let t1 = Date()
                    for h in r.hits.prefix(10) { _ = session.row(for: h, pageProvider: { pageMap[$0] }) }
                    let rows = Date().timeIntervalSince(t1)
                    perQuery.append(["tipo": item.kind, "intera": item.whole, "risultati": r.totalCount,
                                     "ms": (dt * 1000 * 10).rounded() / 10, "righe10_ms": (rows * 1000 * 10).rounded() / 10])
                }
                sampler.cancel()
                let mem1 = physFootprintMB()
                // Al volo: il testo ricostruito a ogni ricerca (mediana di tre).
                var fly: [Double] = []
                for _ in 0..<3 {
                    let t0 = Date()
                    let c = BookSearchCorpus(segments: segs)
                    _ = c.search(queries.first?.q ?? "di")
                    fly.append(Date().timeIntervalSince(t0))
                }
                fly.sort()
                // Rete di posizione: un campione di risultati delle domande prese dal flusso.
                var ok = 0, ko = 0, valueOk = 0
                let reading = vc.textContainerForTesting
                var sample: [(BookSearchHit, String)] = []
                for item in queries where item.kind != "frequente" {
                    let r = session.searchNow(item.q, wholeWord: item.whole)
                    for h in r.hits.prefix(3) { sample.append((h, item.q)) }
                }
                let wanted = min(req.positionsPerVolume ?? 30, sample.count)
                for (h, q) in sample.prefix(wanted) {
                    let r = session.searchNow(q, wholeWord: false)
                    vc.applySearchForTesting()
                    vc.jumpToSearchHitForTesting(h)
                    reading.layoutIfNeeded()
                    let normalizedQuery = SearchNormalizer.normalize(q)
                    let span = (h.segmentIndex...max(h.segmentIndex, h.endSegmentIndex)).filter {
                        segs[$0].role != VISUAL_RESOURCE_ROLE && (segs[$0].role.hasPrefix("NOTE") == segs[h.segmentIndex].role.hasPrefix("NOTE")) }
                    let joined = SearchNormalizer.normalize(span.map { segs[$0].text }.joined(separator: " "))
                    let cell = reading.element(atIndex: h.segmentIndex) as? SegmentCell
                    let reached = reading.currentOrTopIndex == h.segmentIndex && cell?.segment?.id == segs[h.segmentIndex].id
                    let first = SearchNormalizer.normalize(segs[h.segmentIndex].text)
                    let contains = joined.contains(normalizedQuery)
                        && (h.segmentIndex == h.endSegmentIndex ? first.contains(normalizedQuery)
                            : normalizedQuery.split(separator: " ").first.map { first.contains($0) } ?? false)
                    if reached && contains { ok += 1 } else { ko += 1 }
                    if cell?.accessibilityValue?.hasPrefix("risultat") == true { valueOk += 1 }
                    _ = r
                }
                let normalized = session.corpus?.normalizedByteCount ?? 0
                let times = perQuery.compactMap { $0["ms"] as? Double }.sorted()
                report.append([
                    "pdf": name, "pagine": pageCount, "grande": large, "segmenti": segs.count,
                    "caratteri": segs.reduce(0) { $0 + $1.text.count }, "byte_normalizzati": normalized,
                    "mem_prima_MB": (mem0 * 10).rounded() / 10, "mem_dopo_MB": (mem1 * 10).rounded() / 10,
                    "mem_picco_MB": (peak.value * 10).rounded() / 10,
                    "costruzione_ms": (build * 1000 * 10).rounded() / 10, "prima_ricerca_ms": (firstTotal * 1000 * 10).rounded() / 10,
                    "ricerca_mediana_ms": times.isEmpty ? 0 : times[times.count / 2], "ricerca_max_ms": times.last ?? 0,
                    "al_volo_mediana_ms": (fly[1] * 1000 * 10).rounded() / 10,
                    "posizioni_ok": ok, "posizioni_ko": ko, "valore_parlato_ok": valueOk, "domande": perQuery,
                ])
                window.isHidden = true
                print("[ricerca-banco] \(name): segmenti \(segs.count), costruzione \(Int(build * 1000)) ms, "
                      + "prima \(Int(firstTotal * 1000)) ms, memoria +\(Int(mem1 - mem0)) MB, posizioni \(ok)/\(ok + ko)")
            }
        }
        let out = (req.outDir as NSString).appendingPathComponent("banco_ricerca.json")
        let json = try JSONSerialization.data(withJSONObject: ["volumi": report], options: [.prettyPrinted, .sortedKeys])
        try json.write(to: URL(fileURLWithPath: out))
    }
}

// MARK: - Ricerca nel testo di tutti i libri (tab Ricerca) e Esc nelle finestre (giro «ricerca nella libreria», 2026-10-20)

/// Il testo di ricerca accanto alla cache (scritto, rimesso con la lettura precedente, cancellato col libro, riscritto in
/// sottofondo quando non vale), la ricerca su tutti i libri, il tab Ricerca, l'apertura di un libro sulla sua lista, e Esc
/// come «Annulla»/«Chiudi» della finestra più in alto. Libri e testi INVENTATI, mai di un volume.
final class LibrarySearchAppTests: XCTestCase {

    private var service: LibraryService { .shared }
    private var created: [String] = []

    override func tearDown() {
        for id in created {
            service.store.deleteDocumentFromArchive(id: id)
            service.deleteFiles(forDocumentId: id)
        }
        created = []
        super.tearDown()
    }

    private func seg(_ id: String, _ role: String, _ text: String) -> ContentSegment {
        ContentSegment(id: id, role: role, text: text, lengthCategory: role == "NOTE" ? "SHORT" : "", acousticIntro: "")
    }

    private func content(_ segs: [ContentSegment]) -> PaginatedContent {
        PaginatedContent(pages: [ContentPage(pageNumber: 1, segments: segs)], totalSegments: segs.count)
    }

    /// Un libro nell'archivio con la cache (e quindi il testo di ricerca, in sottofondo).
    @discardableResult
    private func addBook(_ title: String, _ segs: [ContentSegment]) -> String {
        let doc = service.store.addDocument(title: title, sourceFileName: "prova-libreria.pdf", sourcePageCount: 1)
        created.append(doc.id)
        XCTAssertTrue(service.writeCache(content(segs), pageMap: [:], doctrineContent: nil, quickConsultTree: nil,
                                         contentTarget: DEFAULT_GRANULARITY_TARGET, forDocumentId: doc.id))
        LibrarySearchIndex.shared.waitForPendingWrites()
        return doc.id
    }

    private func countIn(_ id: String, _ q: String, whole: Bool = false) -> Int? {
        LibrarySearchIndex.shared.searchNow(q, wholeWord: whole).books.first { $0.documentId == id }?.count
    }

    private let lantern = "zxlanterna"   // parola inventata, che nessun altro libro di prova contiene

    func test_searchText_isWrittenWithTheCache_andCountsLikeTheBookSearch() {
        let segs = [seg("b1", "BODY", "Il \(lantern)12 resta acceso tutta la notte, \(lantern) dopo \(lantern)."),
                    seg("n12", "NOTE", "12 Nota inventata sul \(lantern).")]
        let id = addBook("Libro della lanterna", segs)
        XCTAssertNotNil(service.validSearchText(forDocumentId: id), "scritto con la cache")
        XCTAssertFalse(service.needsSearchText(forDocumentId: id))
        let corpus = BookSearchCorpus(segments: segs)
        for whole in [false, true] {
            XCTAssertEqual(countIn(id, lantern, whole: whole), corpus.search(lantern, options: BookSearchOptions(wholeWord: whole)).totalCount)
        }
        XCTAssertEqual(countIn(id, lantern, whole: true), 4, "anche quello col richiamo 12 attaccato")
    }

    func test_searchText_followsTheReprocessing_andTheReturnToThePreviousReading() throws {
        let id = addBook("Libro che cambia", [seg("b", "BODY", "Prima lettura: il zxfaro sulla scogliera.")])
        XCTAssertEqual(countIn(id, "zxfaro"), 1)
        try service.stashPreviousReading(XCTUnwrap(service.store.readingSnapshot(documentId: id)), forDocumentId: id)
        XCTAssertTrue(service.writeCache(content([seg("b", "BODY", "Seconda lettura: la zxneve sui tetti.")]), pageMap: [:],
                                         doctrineContent: nil, quickConsultTree: nil, contentTarget: DEFAULT_GRANULARITY_TARGET,
                                         forDocumentId: id))
        LibrarySearchIndex.shared.waitForPendingWrites()
        XCTAssertNil(countIn(id, "zxfaro"), "la lettura nuova non ha più il faro")
        XCTAssertEqual(countIn(id, "zxneve"), 1, "aggiornato alla rielaborazione")
        XCTAssertNotNil(service.restorePreviousCache(forDocumentId: id))
        // Il testo di ricerca della lettura precedente torna con lei; se il timbro non coincidesse, la messa in pari lo
        // riscrive (mai un risultato da una lettura che non c'è più).
        let immediate = service.validSearchText(forDocumentId: id) != nil
        if !immediate { runCatchUp() }
        XCTAssertEqual(countIn(id, "zxfaro"), 1, "torna con la lettura precedente")
        XCTAssertNil(countIn(id, "zxneve"))
        print("[libreria] testo di ricerca valido subito dopo il ritorno alla lettura precedente: \(immediate)")
        service.discardPreviousReading(forDocumentId: id)
    }

    func test_searchText_isDeletedWithTheBook() throws {
        let id = addBook("Libro da eliminare", [seg("b", "BODY", "Il zxmulino gira.")])
        try service.stashPreviousReading(XCTUnwrap(service.store.readingSnapshot(documentId: id)), forDocumentId: id)
        let url = service.searchTextURL(forDocumentId: id)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        service.store.deleteDocumentFromArchive(id: id)
        service.deleteFiles(forDocumentId: id)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path), "cancellato col libro")
        let dir = url.deletingLastPathComponent()
        let left = (try? FileManager.default.contentsOfDirectory(atPath: dir.path))?.filter { $0.hasPrefix(id) } ?? []
        XCTAssertEqual(left, [], "nessun file del libro resta nella cache (né quello della lettura precedente)")
        XCTAssertNil(LibrarySearchIndex.shared.searchNow("zxmulino", wholeWord: false).books.first { $0.documentId == id })
    }

    private func runCatchUp() {
        let done = expectation(description: "messa in pari")
        LibrarySearchIndex.shared.catchUp(isIdle: { true }) { done.fulfill() }
        wait(for: [done], timeout: 60)
    }

    func test_staleText_isNotReady_neverSearched_andTheCatchUpRewritesIt() throws {
        let id = addBook("Libro aggiornato altrove", [seg("b", "BODY", "Il zxpozzo è profondo.")])
        // La cache riscritta da un'altra versione dell'app, senza il testo di ricerca: il timbro non coincide più.
        Thread.sleep(forTimeInterval: 0.01)
        let url = service.cacheURLForTesting(forDocumentId: id)
        let data = try Data(contentsOf: url)
        let replaced = try XCTUnwrap(String(data: data, encoding: .utf8)?.replacingOccurrences(of: "zxpozzo", with: "zxcanale"))
        try Data(replaced.utf8).write(to: url, options: .atomic)
        XCTAssertNil(service.validSearchText(forDocumentId: id), "un testo nato da un'altra cache non vale")
        XCTAssertTrue(service.needsSearchText(forDocumentId: id))
        let r = LibrarySearchIndex.shared.searchNow("zxpozzo", wholeWord: false)
        XCTAssertNil(r.books.first { $0.documentId == id }, "mai un risultato dalla lettura vecchia")
        XCTAssertGreaterThanOrEqual(r.notReady, 1)
        runCatchUp()
        XCTAssertFalse(service.needsSearchText(forDocumentId: id))
        XCTAssertEqual(countIn(id, "zxcanale"), 1, "riscritto dalla cache di adesso")
        XCTAssertNil(countIn(id, "zxpozzo"))
    }

    func test_catchUp_stopsWhenTheAppIsNotIdle() {
        let id = addBook("Libro in attesa", [seg("b", "BODY", "Il zxtorrente scorre.")])
        try? FileManager.default.removeItem(at: service.searchTextURL(forDocumentId: id))
        let done = expectation(description: "messa in pari ferma")
        LibrarySearchIndex.shared.catchUp(isIdle: { false }) { done.fulfill() }
        wait(for: [done], timeout: 10)
        XCTAssertTrue(service.needsSearchText(forDocumentId: id), "con un libro aperto non si scrive nulla")
        runCatchUp()
        XCTAssertFalse(service.needsSearchText(forDocumentId: id))
    }

    /// La ricerca nel libro aperto riusa i legami fra note e richiami della lettura: gli stessi confini, gli stessi
    /// conteggi del testo di ricerca della libreria (che li calcola da sé, dagli stessi segmenti).
    func test_bookSearch_inTheReader_usesTheReadingLinks_andCountsLikeTheLibrary() {
        let segs = [seg("b1", "BODY", "Il \(lantern)12 resta acceso, e un altro \(lantern) dopo."), seg("n12", "NOTE", "12 Nota inventata.")]
        let id = addBook("Libro coerente", segs)
        let vc = ContinuousReadingViewController(content: content(segs), documentId: "", signalPlayer: SilentLibrarySignals())
        vc.loadViewIfNeeded()
        let inBook = vc.searchSessionForTesting.searchNow(lantern, wholeWord: true)
        XCTAssertEqual(inBook.totalCount, 2, "anche quello col richiamo 12 attaccato")
        XCTAssertEqual(countIn(id, lantern, whole: true), inBook.totalCount, "lo stesso numero nella libreria")
        XCTAssertEqual(vc.searchSessionForTesting.corpus?.callBoundaryCount, BookSearchCorpus(segments: segs).callBoundaryCount)
    }

    // MARK: Il tab Ricerca

    private func hostedSearch() -> (SearchViewController, UIWindow) {
        let vc = SearchViewController()
        let nav = UINavigationController(rootViewController: vc)
        let w = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        w.rootViewController = nav
        w.makeKeyAndVisible()
        vc.loadViewIfNeeded()
        vc.view.layoutIfNeeded()
        return (vc, w)
    }

    private func labels(_ vc: SearchViewController) -> [String] {
        guard let table = vc.view.subviews.compactMap({ $0 as? UITableView }).first else { return [] }
        table.reloadData()
        table.layoutIfNeeded()
        var out: [String] = []
        for s in 0..<table.numberOfSections {
            for r in 0..<table.numberOfRows(inSection: s) {
                guard let cell = table.dataSource?.tableView(table, cellForRowAt: IndexPath(row: r, section: s)) else { continue }
                if let l = cell.accessibilityLabel, !l.isEmpty { out.append(l) }
                else if let c = cell.contentConfiguration as? UIListContentConfiguration, let t = c.text { out.append(t) }
                else if let row = cell as? LibraryRowCell { out.append("titolo:" + (row.accessibilityElements?.compactMap { ($0 as? UIView)?.accessibilityLabel }.joined(separator: "|") ?? "")) }
            }
        }
        return out
    }

    func test_searchTab_textOfAllBooks_summaryFirst_thenOneRowPerBook_andTitlesAsBefore() {
        addBook("Zx primo libro", [seg("b", "BODY", "Il zxgabbiano vola. Un altro zxgabbiano.")])
        addBook("Zx secondo libro", [seg("b", "BODY", "Nessun uccello qui."), seg("n", "NOTE", "1 Un zxgabbiano in nota.")])
        addBook("Zxgabbiano nel titolo", [seg("b", "BODY", "Testo senza la parola.")])
        let (vc, w) = hostedSearch()
        defer { w.isHidden = true }
        vc.searchBar.text = "zxgabbiano"
        vc.searchBar(vc.searchBar, textDidChange: "zxgabbiano")
        var before = labels(vc)
        XCTAssertTrue(before.contains("Cerca «zxgabbiano» nel testo dei libri"), "prima di «Cerca» la riga che lo fa: \(before)")
        let done = expectation(description: "ricerca nel testo")
        vc.runTextSearch(announce: true) { done.fulfill() }
        wait(for: [done], timeout: 30)
        before = labels(vc)
        let summary = "2 libri, 3 risultati in tutto per «zxgabbiano»."
        let iSummary = before.firstIndex(of: summary)
        XCTAssertNotNil(iSummary, "il riassunto: \(before)")
        let iFirst = before.firstIndex(of: "Zx primo libro, 2 risultati")
        let iSecond = before.firstIndex(of: "Zx secondo libro, un risultato")
        XCTAssertNotNil(iFirst); XCTAssertNotNil(iSecond)
        if let a = iSummary, let b = iFirst, let c = iSecond { XCTAssertTrue(a < b && b < c, "riassunto, poi i libri in ordine") }
        XCTAssertTrue(before.contains { $0.contains("Zxgabbiano nel titolo") }, "il titolo resta trovabile come prima: \(before)")
        XCTAssertFalse(before.contains("Zxgabbiano nel titolo, un risultato"), "un libro col nome nel titolo ma non nel testo non è fra i risultati del testo")
        // «Parola intera» vale come nel libro.
        vc.wholeWordSwitch.isOn = true
        let again = expectation(description: "parola intera")
        vc.runTextSearch(announce: true, moveFocus: false) { again.fulfill() }
        wait(for: [again], timeout: 30)
        XCTAssertEqual(vc.textResult?.totalCount, 3)
        XCTAssertEqual(vc.textResult?.options.wholeWord, true)
        // Una ricerca scritta diversa: il testo va cercato di nuovo.
        vc.searchBar.text = "zxgabbian"
        vc.searchBar(vc.searchBar, textDidChange: "zxgabbian")
        XCTAssertNil(vc.textResult)
    }

    func test_searchTab_zeroResults_areSaidWithASuggestion_andNoDeadEnd() {
        addBook("Zx libro qualsiasi", [seg("b", "BODY", "Il fiume scorre.")])
        let (vc, w) = hostedSearch()
        defer { w.isHidden = true }
        vc.wholeWordSwitch.isOn = true
        vc.searchBar.text = "zxnonesiste"
        vc.searchBar(vc.searchBar, textDidChange: "zxnonesiste")
        let done = expectation(description: "ricerca nel testo")
        vc.runTextSearch(announce: true) { done.fulfill() }
        wait(for: [done], timeout: 30)
        XCTAssertTrue(vc.textStatusSentence.hasPrefix("Nel testo dei libri nessun risultato per «zxnonesiste»."), vc.textStatusSentence)
        XCTAssertTrue(vc.textStatusSentence.contains("togliere «Parola intera»"), vc.textStatusSentence)
    }

    /// Aprendo un libro dalla lista si arriva alla sua lista dei risultati: «Cerca nel libro» con la stessa ricerca già fatta.
    func test_reader_openedFromTheLibrary_opensItsListWithTheSameSearch() {
        let segs = [seg("h", "HEADING_1", "Capitolo"), seg("b1", "BODY", "Il zxcorvo nero."), seg("b2", "BODY", "Un altro ZXCORVO.")]
        let vc = ContinuousReadingViewController(content: content(segs), documentId: "", signalPlayer: SilentLibrarySignals())
        vc.pendingLibrarySearch = (query: "zxcorvo", wholeWord: true)
        // Senza animazioni: nelle prove d'unità la transizione a schermo intero non si conclude da sola.
        UIView.setAnimationsEnabled(false)
        defer { UIView.setAnimationsEnabled(true) }
        // Una finestra della scena dell'app: senza scena la presentazione non mette la finestra a schermo.
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let w = scene.map { UIWindow(windowScene: $0) } ?? UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        w.rootViewController = vc
        w.makeKeyAndVisible()
        defer { w.isHidden = true }
        let deadline = Date().addingTimeInterval(8)
        var window: BookSearchViewController?
        while Date() < deadline, window == nil {
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
            window = (vc.presentedViewController as? UINavigationController)?.topViewController as? BookSearchViewController
        }
        XCTAssertNotNil(window, "la lista dei risultati del libro si apre da sola")
        let session = vc.searchSessionForTesting
        let until = Date().addingTimeInterval(8)
        while Date() < until, session.result == nil { RunLoop.main.run(until: Date().addingTimeInterval(0.1)) }
        XCTAssertEqual(session.result?.totalCount, 2, "la ricerca è già fatta")
        XCTAssertEqual(session.result?.options.wholeWord, true, "con la stessa «Parola intera»")
        XCTAssertEqual(window?.searchField.text, "zxcorvo")
        XCTAssertNil(vc.pendingLibrarySearch, "una volta sola")
        window?.chooseResultForTesting(1)
        let back = Date().addingTimeInterval(5)
        while Date() < back, vc.presentedViewController != nil { RunLoop.main.run(until: Date().addingTimeInterval(0.1)) }
        RunLoop.main.run(until: Date().addingTimeInterval(0.6))
        XCTAssertTrue(session.isActive, "nella lettura la ricerca è attiva")
        XCTAssertTrue(vc.textContainerForTesting.customRotorNamesForTesting.contains(ContinuousReadingView.searchRotorName),
                      "il rotore «Risultati della ricerca» c'è già")
        XCTAssertEqual(vc.textContainerForTesting.currentOrTopIndex, 2, "la lettura è sul risultato scelto")
    }

    // MARK: Esc come «Annulla» o «Chiudi»

    func test_escape_goesToTheTopmostWindowWithCancelOrClose_neverBelow() {
        let root = UIViewController()
        let w = ScaboWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        w.rootViewController = root
        w.makeKeyAndVisible()
        defer { w.isHidden = true }
        XCTAssertNil(ScaboWindow.escapeTarget(from: root), "nessuna finestra: Esc non fa nulla")
        XCTAssertFalse((w.keyCommands ?? []).contains { $0.input == UIKeyCommand.inputEscape })
        let doc = service.store.addDocument(title: "Zx referto", sourceFileName: "x.pdf", sourcePageCount: 1)
        created.append(doc.id)
        let report = ReportViewController(document: doc)
        let nav = UINavigationController(rootViewController: report)
        root.present(nav, animated: false)
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        XCTAssertTrue(ScaboWindow.escapeTarget(from: root) === report)
        let esc = (w.keyCommands ?? []).first { $0.input == UIKeyCommand.inputEscape }
        XCTAssertNotNil(esc, "con una finestra con «Chiudi», la finestra della scena tiene Esc")
        // Un avviso sopra la finestra: Esc lo gestisce il sistema; mai «Chiudi» della finestra sotto.
        let alert = UIAlertController(title: "Prova", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Annulla", style: .cancel))
        nav.present(alert, animated: false)
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        XCTAssertTrue(ScaboWindow.topmostPresented(from: root) === alert)
        XCTAssertNil(ScaboWindow.escapeTarget(from: root), "con un avviso in cima, niente a chi sta sotto")
        alert.dismiss(animated: false)
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))
        XCTAssertTrue(ScaboWindow.escapeTarget(from: root) === report)
        if let action = esc?.action { w.perform(action) }
        let until = Date().addingTimeInterval(3)
        while Date() < until, root.presentedViewController != nil { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }
        XCTAssertNil(root.presentedViewController, "Esc ha fatto «Chiudi»")
    }

    func test_escape_destinationChooser_onlyAtTheFirstLevel() {
        let first = DestinationChooserViewController(level: .root, excluded: nil) { _ in }
        XCTAssertTrue(first.hasEscapeAction, "al primo livello c'è «Annulla»")
        let ws = service.store.createWorkspace(name: "Zx spazio")
        defer { service.store.deleteWorkspace(id: ws.id) }
        let inner = DestinationChooserViewController(level: .workspace(ws.id), excluded: nil) { _ in }
        XCTAssertFalse(inner.hasEscapeAction, "ai livelli interni c'è «Indietro», non «Annulla»")
    }

    /// Il censimento: ogni finestra dell'app con «Annulla» o «Chiudi» dichiara l'azione a Esc. Le finestre che arrivano
    /// dal Mac (lettura offerta, libro assente, quale copia) le prova il test d'interfaccia delle letture dal Mac.
    func test_escape_census_everyWindowWithCancelOrClose() throws {
        let doc = service.store.addDocument(title: "Zx censimento", sourceFileName: "x.pdf", sourcePageCount: 1)
        created.append(doc.id)
        let root = UIViewController()
        let w = ScaboWindow(frame: CGRect(x: 0, y: 0, width: 820, height: 1180))
        w.rootViewController = root
        w.makeKeyAndVisible()
        defer { w.isHidden = true }
        let segs = [seg("b", "BODY", "Una riga di prova per le sottolineature.")]
        let presenters: [(String, () -> Void)] = [
            ("Segnalibri", { root.present(UINavigationController(rootViewController: BookmarksWindowViewController.makeForTesting(
                store: self.service.store, documentId: doc.id)), animated: false) }),
            ("Nuovo segnalibro", { BookmarkEditorViewController.present(from: root, title: "Nuovo segnalibro", preview: "Prova",
                                                                         tags: [], initialName: nil, initialTagIds: [], onConfirm: { _, _ in }) }),
            ("Sottolinea", { UnderlineSelectionViewController.present(from: root, segments: segs, startIndex: 0,
                                                                      blockedIntervals: { _ in [] }, onCommit: { _, _ in true }) }),
            ("Referto", { root.present(UINavigationController(rootViewController: ReportViewController(document: doc)), animated: false) }),
            ("Aggiungi un file", { DocumentChooserViewController.present(from: root) { _ in } }),
            ("Scegli dove collocare", { DestinationChooserViewController.present(from: root, excluded: nil) { _ in } }),
            ("Lettura migliore", { root.present(UINavigationController(rootViewController: ReprocessOfferViewController(
                document: doc, reason: .cure, onDone: {})), animated: false) }),
            ("Conferma", { ReprocessConfirmViewController.present(from: root, identifier: "zx", question: "Prova?", explanation: "Prova.",
                                                                  actionTitle: "Fai", onConfirm: {}) }),
            ("Libro già presente", { DuplicateImportViewController.present(existing: doc, copies: 1, from: root) { _ in } }),
            ("Lettura non usabile", { ReceivedProblemViewController.present(problem: .notAPackage,
                                                                            fileURL: URL(fileURLWithPath: "/dev/null"), from: root, onDone: {}) }),
            ("Elaborazione", {
                let p = ProcessingViewController(fileURL: URL(fileURLWithPath: "/dev/null"), sourceName: "Zx",
                                                 processor: NeverEndingProcessor(), signalPlayer: SilentLibrarySignals())
                // Come fa chi la apre (DocumentOpener): l'esito, anche «Annulla», chiude la finestra.
                p.onOutcome = { _ in root.dismiss(animated: false) }
                root.present(p, animated: false)
            }),
            ("Cerca nel libro", { BookSearchViewController.present(from: root, session: BookSearchSession(segments: segs), pageProvider: nil,
                                                                    onChoose: { _ in }, onReturnToStart: { _ in }, onEnd: {}, onCancel: {},
                                                                    onResultsChanged: {}) }),
        ]
        for (name, present) in presenters {
            present()
            let until = Date().addingTimeInterval(3)
            while Date() < until, ScaboWindow.escapeTarget(from: root) == nil { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }
            XCTAssertNotNil(ScaboWindow.escapeTarget(from: root), "\(name): Esc fa «Annulla» o «Chiudi»")
            let esc = (w.keyCommands ?? []).first { $0.input == UIKeyCommand.inputEscape }
            XCTAssertNotNil(esc, "\(name): la finestra della scena tiene Esc")
            if let action = esc?.action { w.perform(action) }
            let gone = Date().addingTimeInterval(4)
            while Date() < gone, root.presentedViewController != nil { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }
            XCTAssertNil(root.presentedViewController, "\(name): Esc ha chiuso la finestra")
            if root.presentedViewController != nil {
                root.dismiss(animated: false)
                RunLoop.main.run(until: Date().addingTimeInterval(0.5))
            }
        }
    }
}

/// Un'elaborazione che non finisce da sola (la finestra «Elaborazione» resta aperta finché non si annulla).
private final class NeverEndingProcessor: DocumentProcessing {
    func process(fileURL: URL, sourceName: String, granularityTarget: Int, buildDoctrine: Bool,
                 onProgress: @escaping (DocumentProcessor.Progress) -> Void,
                 completion: @escaping (DocumentProcessor.Outcome) -> Void) {}
    func cancel() {}
}

private final class SilentLibrarySignals: SignalPlaying {
    func play(_ signal: AudioSignal) {}
    func playLooping(_ signal: AudioSignal) {}
    func stop(_ signal: AudioSignal) {}
}

/// BANCO DELLA RICERCA NELLA LIBRERIA (giro «ricerca nella libreria», 2026-10-20). La richiesta
/// (`/tmp/scabo_library_bench_request.json`, o `SCABO_LIBRARY_BENCH_REQUEST`) porta SOLO percorsi: le letture intere del
/// banco (`.lettura.json`, la forma della cache dell'iPad), il file delle domande (nel laboratorio) e la cartella d'uscita
/// (nel laboratorio). Ogni lettura entra nella libreria dell'app come un libro vero (`writeCache`, che scrive anche il testo di
/// ricerca come all'elaborazione); poi la messa in pari da zero (testi di ricerca tolti); poi ogni domanda cercata nel testo
/// di TUTTI i libri, come il tab Ricerca. Esce: per domanda e per libro il numero di risultati (per la rete di correttezza,
/// nel laboratorio), i confini dei richiami per libro, e tempi e memoria (solo numeri). Alla fine i libri si tolgono.
/// `XCTSkip` senza richiesta.
final class LibrarySearchBenchTests: XCTestCase {

    private struct Request: Decodable {
        let letture: [String]
        let domande: String
        let outDir: String
    }
    private struct Domanda: Decodable { let id: String; let q: String; let intera: Bool }
    private struct Lettura: Decodable {
        let content: PaginatedContent
        let pageMap: [String: Int]
        let doctrineContent: PaginatedContent?
        let quickConsultTree: [QuickConsultNode]?
        let contentTarget: Int?
    }

    private func ms(_ t: TimeInterval) -> Double { (t * 1000 * 10).rounded() / 10 }

    func test_librarySearchBench_fromRequest() throws {
        let reqPath = ProcessInfo.processInfo.environment["SCABO_LIBRARY_BENCH_REQUEST"] ?? "/tmp/scabo_library_bench_request.json"
        guard let data = FileManager.default.contents(atPath: reqPath),
              let req = try? JSONDecoder().decode(Request.self, from: data) else {
            throw XCTSkip("nessuna richiesta del banco della libreria in \(reqPath).")
        }
        let service = LibraryService.shared
        let index = LibrarySearchIndex.shared
        try? FileManager.default.createDirectory(atPath: req.outDir, withIntermediateDirectories: true)
        let domande = try JSONDecoder().decode([Domanda].self, from: Data(contentsOf: URL(fileURLWithPath: req.domande)))
        // Le altre prove possono aver lasciato libri: il banco cerca solo nei suoi (titoli col prefisso), ma la libreria
        // intera conta per i tempi; si annota quanti libri c'erano già.
        let before = service.store.allDocuments().count
        var ids: [String: String] = [:]      // id → nome della lettura
        var books: [[String: Any]] = []
        var boundaries: [String: [[Int]]] = [:]
        let mem0 = physFootprintMB()
        let seedPeak = PeakBox(mem0)
        let sampler = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        sampler.schedule(deadline: .now(), repeating: .milliseconds(5))
        sampler.setEventHandler { seedPeak.update(physFootprintMB()) }
        sampler.resume()
        for path in req.letture {
            let stem = ((path as NSString).lastPathComponent as NSString).deletingPathExtension
                .replacingOccurrences(of: ".lettura", with: "")
            let rel = path.components(separatedBy: "/").suffix(2).joined(separator: "/").replacingOccurrences(of: ".lettura.json", with: "")
            try autoreleasepool {
                let l = try JSONDecoder().decode(Lettura.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
                let doc = service.store.addDocument(title: "banco-libreria: \(rel)", sourceFileName: "\(stem).pdf", sourcePageCount: 0)
                ids[doc.id] = rel
                let t0 = Date()
                XCTAssertTrue(service.writeCache(l.content, pageMap: l.pageMap, doctrineContent: l.doctrineContent,
                                                 quickConsultTree: l.quickConsultTree,
                                                 contentTarget: l.contentTarget ?? DEFAULT_GRANULARITY_TARGET, forDocumentId: doc.id))
                let t1 = Date()
                index.waitForPendingWrites()
                let t2 = Date()
                let segs = l.content.pages.flatMap { $0.segments }
                let corpus = BookSearchCorpus(segments: segs)
                boundaries[rel] = corpus.callBoundariesBySegment.map { [$0.segment, $0.offset] }
                let size = { (u: URL) in ((try? FileManager.default.attributesOfItem(atPath: u.path)[.size]) as? NSNumber)?.intValue ?? 0 }
                books.append(["lettura": rel, "segmenti": segs.count, "byte_normalizzati": corpus.normalizedByteCount,
                              "confini_richiami": corpus.callBoundaryCount, "scrittura_cache_ms": ms(t1.timeIntervalSince(t0)),
                              "scrittura_testo_ricerca_ms": ms(t2.timeIntervalSince(t1)),
                              "file_cache_byte": size(service.cacheURLForTesting(forDocumentId: doc.id)),
                              "file_testo_ricerca_byte": size(service.searchTextURL(forDocumentId: doc.id))])
            }
        }
        sampler.cancel()
        defer {
            for id in ids.keys { service.store.deleteDocumentFromArchive(id: id); service.deleteFiles(forDocumentId: id) }
        }
        let mem1 = physFootprintMB()

        // Messa in pari da zero: prima libro per libro (i tempi di ciascuno), poi la messa in pari vera, di nuovo da zero.
        for id in ids.keys { try? FileManager.default.removeItem(at: service.searchTextURL(forDocumentId: id)) }
        var perBook: [Double] = []
        for id in ids.keys {
            let t = Date()
            autoreleasepool {
                if let c = service.cachedContentForSearchText(forDocumentId: id) {
                    try? LibrarySearchText.encode(segments: c.segments, stamp: c.stamp).write(to: service.searchTextURL(forDocumentId: id))
                }
            }
            perBook.append(Date().timeIntervalSince(t))
        }
        for id in ids.keys { try? FileManager.default.removeItem(at: service.searchTextURL(forDocumentId: id)) }
        let catchPeak = PeakBox(physFootprintMB())
        let memCatch0 = physFootprintMB()
        let s2 = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        s2.schedule(deadline: .now(), repeating: .milliseconds(5))
        s2.setEventHandler { catchPeak.update(physFootprintMB()) }
        s2.resume()
        let tc = Date()
        let done = expectation(description: "messa in pari")
        index.catchUp(isIdle: { true }) { done.fulfill() }
        wait(for: [done], timeout: 3600)
        let catchUp = Date().timeIntervalSince(tc)
        s2.cancel()
        XCTAssertEqual(ids.keys.filter { service.needsSearchText(forDocumentId: $0) }, [], "tutto in pari")

        // Le ricerche su tutta la libreria.
        let memS0 = physFootprintMB()
        let searchPeak = PeakBox(memS0)
        let s3 = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        s3.schedule(deadline: .now(), repeating: .milliseconds(5))
        s3.setEventHandler { searchPeak.update(physFootprintMB()) }
        s3.resume()
        var risultati: [String: [String: Int]] = [:]
        var tempi: [Double] = []
        var notReady = 0
        for d in domande {
            let t = Date()
            let r = index.searchNow(d.q, wholeWord: d.intera)
            tempi.append(Date().timeIntervalSince(t))
            notReady = max(notReady, r.notReady)
            var perVol: [String: Int] = [:]
            for b in r.books { if let rel = ids[b.documentId] { perVol[rel] = b.count } }
            risultati[d.id] = perVol
        }
        s3.cancel()
        let memS1 = physFootprintMB()
        let sorted = tempi.sorted()
        perBook.sort()
        let numeri: [String: Any] = [
            "libri_del_banco": ids.count, "libri_gia_presenti": before, "domande": domande.count,
            "mem_prima_MB": (mem0 * 10).rounded() / 10, "mem_dopo_libri_MB": (mem1 * 10).rounded() / 10,
            "mem_picco_inserimento_MB": (seedPeak.value * 10).rounded() / 10,
            "messa_in_pari_s": (catchUp * 10).rounded() / 10, "messa_in_pari_mem_prima_MB": (memCatch0 * 10).rounded() / 10,
            "messa_in_pari_mem_picco_MB": (catchPeak.value * 10).rounded() / 10,
            "messa_in_pari_per_libro_mediana_ms": ms(perBook[perBook.count / 2]), "messa_in_pari_per_libro_max_ms": ms(perBook.last ?? 0),
            "ricerca_mediana_ms": ms(sorted[sorted.count / 2]), "ricerca_p90_ms": ms(sorted[sorted.count * 9 / 10]),
            "ricerca_max_ms": ms(sorted.last ?? 0), "ricerca_mem_prima_MB": (memS0 * 10).rounded() / 10,
            "ricerca_mem_picco_MB": (searchPeak.value * 10).rounded() / 10, "ricerca_mem_dopo_MB": (memS1 * 10).rounded() / 10,
            "non_pronti_max": notReady, "libri": books,
        ]
        let out = URL(fileURLWithPath: req.outDir)
        try JSONSerialization.data(withJSONObject: numeri, options: [.prettyPrinted, .sortedKeys])
            .write(to: out.appendingPathComponent("banco_libreria.json"))
        try JSONSerialization.data(withJSONObject: ["risultati": risultati], options: [.sortedKeys])
            .write(to: out.appendingPathComponent("motore_libreria.json"))
        try JSONSerialization.data(withJSONObject: ["confini": boundaries], options: [.sortedKeys])
            .write(to: out.appendingPathComponent("confini_libreria.json"))
        print("[libreria-banco] libri \(ids.count), domande \(domande.count), ricerca mediana \(ms(sorted[sorted.count / 2])) ms, "
              + "massimo \(ms(sorted.last ?? 0)) ms, messa in pari \(Int(catchUp)) s, picco ricerca +\(Int(searchPeak.value - memS0)) MB")
    }
}
