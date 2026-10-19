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
