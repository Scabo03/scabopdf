//
//  BookSearchViewController.swift
//  ScaboApp
//
//  RICERCA DENTRO IL LIBRO APERTO (LAYER2_PRODUCT_DECISIONS § 13.3; giro «ricerca nel libro», 2026-10-19): lo stato
//  della ricerca nel libro (`BookSearchSession`) e la finestra «Cerca nel libro». La logica — testo della lettura
//  normalizzato, occorrenze, contesto, frasi — sta in ScaboCore (`BookSearch.swift`), così la lettura sul Mac la riusa;
//  qui la presentazione.
//
//  ── La finestra ───────────────────────────────────────────────────────────────────────────────────────────────
//
//  Container modale (§ 2.3, § 3.2) a schermo intero: il testo dietro non si raggiunge (né si vede) finché è aperta.
//  «Annulla» (o Esc, o lo scrub a due dita) la chiude e la lettura resta dov'era, col fuoco sull'elemento di prima. Ordine di lettura (principio § 12.1:
//  titolo, comandi, contenuto): il titolo «Cerca nel libro», «Annulla», il campo, «Parola intera», i comandi della ricerca
//  in corso («Torna dove leggevi», «Chiudi la ricerca»), la frase del conteggio, i risultati. Dopo «Cerca» il fuoco va alla
//  frase del conteggio: VoiceOver dice subito quanti risultati (o, se nessuno, perché e che cosa provare), e lo swipe dopo
//  è il primo risultato. Ogni risultato dice il contesto (qualche parola prima e dopo), se sta in una nota, la sezione o
//  il titolo in cui sta e la pagina del file originale; il doppio tap chiude la finestra e porta la lettura lì, in Lettura
//  Continua, col fuoco di VoiceOver sull'elemento che contiene il risultato.
//
//  ── Memoria e tempi ────────────────────────────────────────────────────────────────────────────────────────────
//
//  Il testo normalizzato del libro (`BookSearchCorpus`) si costruisce alla PRIMA ricerca, in sottofondo, dai segmenti che la
//  lettura tiene già in memoria (non rilegge nulla da disco), e resta finché il libro è aperto: le ricerche dopo la prima
//  scorrono solo quel buffer. Su un avviso di memoria si lascia andare se non c'è una ricerca attiva (si ricostruisce alla
//  prossima). Misure nel referto del giro, § 5.
//

import UIKit
import ScaboCore

/// Lo stato della ricerca nel libro aperto: il testo pronto per cercare, l'ultima ricerca, il punto di lettura di prima.
final class BookSearchSession {
    /// I segmenti del flusso di Lettura Continua (gli stessi indici della reading view).
    let segments: [ContentSegment]
    private(set) var corpus: BookSearchCorpus?
    /// L'ultima ricerca eseguita (anche senza risultati), o `nil`.
    private(set) var result: BookSearchResult?
    /// L'ultima ricerca scritta e l'opzione «Parola intera» (la finestra le ripropone).
    private(set) var query = ""
    private(set) var wholeWord = false
    /// Dove si leggeva prima del primo salto a un risultato («Torna dove leggevi»): indice di Lettura Continua.
    var positionBeforeSearch: Int?
    /// Quanto è durata l'ultima ricerca (con la costruzione del testo, se è servita) e la costruzione (se è avvenuta).
    private(set) var lastDuration: TimeInterval = 0
    private(set) var lastBuildDuration: TimeInterval?

    private var generation = 0
    private static let queue = DispatchQueue(label: "com.scabo.scabopdf.ricerca", qos: .userInitiated)

    init(segments: [ContentSegment]) {
        self.segments = segments
    }

    /// Vero se c'è una ricerca con almeno un risultato: c'è il rotore, ci sono le frecce.
    var isActive: Bool { (result?.totalCount ?? 0) > 0 }

    /// Esegue la ricerca in sottofondo; `completion` arriva sul thread principale (solo l'ultima chiesta).
    func search(_ text: String, wholeWord: Bool, completion: @escaping (BookSearchResult) -> Void) {
        generation += 1
        let g = generation
        let segs = segments
        let existing = corpus
        Self.queue.async { [weak self] in
            let t0 = Date()
            let built = existing == nil ? BookSearchCorpus(segments: segs) : nil
            let build = built.map { _ in Date().timeIntervalSince(t0) }
            let c = existing ?? built!
            let r = c.search(text, options: BookSearchOptions(wholeWord: wholeWord))
            let dt = Date().timeIntervalSince(t0)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if self.corpus == nil { self.corpus = c }
                guard g == self.generation else { return }
                self.apply(r, wholeWord: wholeWord, duration: dt, build: build)
                completion(r)
            }
        }
    }

    /// La stessa ricerca, sul thread chiamante (per i test e il banco di misura).
    @discardableResult
    func searchNow(_ text: String, wholeWord: Bool) -> BookSearchResult {
        let t0 = Date()
        var build: TimeInterval?
        if corpus == nil {
            corpus = BookSearchCorpus(segments: segments)
            build = Date().timeIntervalSince(t0)
        }
        let r = corpus!.search(text, options: BookSearchOptions(wholeWord: wholeWord))
        apply(r, wholeWord: wholeWord, duration: Date().timeIntervalSince(t0), build: build)
        return r
    }

    private func apply(_ r: BookSearchResult, wholeWord: Bool, duration: TimeInterval, build: TimeInterval?) {
        result = r
        query = r.query
        self.wholeWord = wholeWord
        lastDuration = duration
        lastBuildDuration = build
    }

    /// Chiude la ricerca: niente più rotore, valori, evidenze, frecce; il punto di prima si dimentica.
    func end() {
        result = nil
        positionBeforeSearch = nil
    }

    /// Lascia andare il testo normalizzato se non c'è una ricerca attiva (avviso di memoria).
    func releaseCorpusIfIdle() {
        if !isActive { corpus = nil }
    }

    /// Il riassunto della ricerca attiva per la barra («12 risultati per «x»»), o `nil`.
    var activeSummary: String? {
        guard let r = result, r.totalCount > 0 else { return nil }
        let count = r.totalCount == 1 ? "Un risultato" : "\(BookSearchWording.number(r.totalCount)) risultati"
        return "\(count) per «\(r.query)»"
    }

    // MARK: Le righe dei risultati

    /// Ciò che una riga di risultato mostra e dice.
    struct Row {
        let snippet: String
        let match: NSRange
        let location: String
        let accessibilityLabel: String
    }

    /// La riga del risultato `hit`: contesto, nota, sezione, pagina (se `pageProvider`).
    func row(for hit: BookSearchHit, pageProvider: ((String) -> Int?)?) -> Row {
        guard let corpus, hit.segmentIndex < segments.count else {
            return Row(snippet: "", match: NSRange(location: 0, length: 0), location: "", accessibilityLabel: "")
        }
        let sn = corpus.snippet(for: hit, segments: segments)
        var noteNumber: String?
        if hit.isInNote {
            var k = hit.segmentIndex
            while k > 0, segments[k].role == SemanticCategory.NOTE_CONTINUATION.rawValue
                    || segments[k].role == VISUAL_RESOURCE_ROLE { k -= 1 }
            noteNumber = BookSearchWording.noteNumber(segments[k].text)
        }
        let headingIndex = corpus.headingIndex(for: hit)
        let isHeadingItself = headingIndex == hit.segmentIndex
        let section = headingIndex.map { BookSearchWording.sectionTitle(segments[$0].text) }
        let page = pageProvider?(segments[hit.segmentIndex].id)
        let label = BookSearchWording.rowLabel(snippet: sn.text, inNote: hit.isInNote, noteNumber: noteNumber,
                                               section: section, page: page, isHeadingItself: isHeadingItself)
        // La riga a vista: il contesto sopra, e sotto dove sta (la stessa frase di VoiceOver senza il contesto).
        let location = BookSearchWording.rowLabel(snippet: "", inNote: hit.isInNote, noteNumber: noteNumber,
                                                  section: section, page: page, isHeadingItself: isHeadingItself)
            .trimmingCharacters(in: .whitespaces)
        return Row(snippet: sn.text, match: sn.match, location: location, accessibilityLabel: label)
    }
}

/// La finestra «Cerca nel libro».
final class BookSearchViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate,
                                      UIAdaptivePresentationControllerDelegate {

    private let session: BookSearchSession
    private let pageProvider: ((String) -> Int?)?
    /// Scelta di un risultato (dopo la chiusura della finestra).
    private let onChoose: (BookSearchHit) -> Void
    /// «Torna dove leggevi» (dopo la chiusura).
    private let onReturnToStart: (Int) -> Void
    /// «Chiudi la ricerca» (dopo la chiusura).
    private let onEnd: () -> Void
    /// «Annulla», Esc, scrub o trascinamento in giù: la lettura resta dov'era.
    private let onCancel: () -> Void
    /// Una ricerca nuova è finita (la lettura aggiorna rotore, valori ed evidenze anche se poi si annulla).
    private let onResultsChanged: () -> Void

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    let searchField = UISearchTextField()
    let wholeWordSwitch = UISwitch()
    private var isSearching = false
    private var rowCache: [Int: BookSearchSession.Row] = [:]
    /// Vero dopo una chiusura già instradata (una sola uscita per apertura).
    private var finished = false

    private enum Section { case controls, ongoing, results }
    private enum Ongoing { case returnToStart, end }

    @discardableResult
    static func present(
        from presenter: UIViewController,
        session: BookSearchSession,
        pageProvider: ((String) -> Int?)?,
        onChoose: @escaping (BookSearchHit) -> Void,
        onReturnToStart: @escaping (Int) -> Void,
        onEnd: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        onResultsChanged: @escaping () -> Void
    ) -> BookSearchViewController {
        let vc = BookSearchViewController(session: session, pageProvider: pageProvider, onChoose: onChoose,
                                          onReturnToStart: onReturnToStart, onEnd: onEnd, onCancel: onCancel,
                                          onResultsChanged: onResultsChanged)
        let nav = UINavigationController(rootViewController: vc)
        // A schermo intero, anche sull'iPad: attorno a un foglio resterebbe visibile il testo del libro, fuori da
        // VoiceOver finché la finestra è aperta (l'audit d'accessibilità dell'iPad ne contava sei righe, campo); e alla
        // chiusura il lettore torna a comparire, quindi riprende i comandi da tastiera (⌘G subito dopo).
        nav.modalPresentationStyle = .fullScreen
        nav.presentationController?.delegate = vc
        presenter.present(nav, animated: Motion.animated())
        return vc
    }

    /// Per i test: la finestra senza presentarla.
    static func makeForTesting(session: BookSearchSession, pageProvider: ((String) -> Int?)? = nil,
                               onChoose: @escaping (BookSearchHit) -> Void = { _ in }) -> BookSearchViewController {
        BookSearchViewController(session: session, pageProvider: pageProvider, onChoose: onChoose, onReturnToStart: { _ in },
                                 onEnd: {}, onCancel: {}, onResultsChanged: {})
    }

    /// Per le prove: la finestra con «Annulla» osservabile.
    static func makeForTestingObservingCancel(session: BookSearchSession,
                                              onCancel: @escaping () -> Void) -> BookSearchViewController {
        BookSearchViewController(session: session, pageProvider: nil, onChoose: { _ in }, onReturnToStart: { _ in },
                                 onEnd: {}, onCancel: onCancel, onResultsChanged: {})
    }

    private init(session: BookSearchSession, pageProvider: ((String) -> Int?)?,
                 onChoose: @escaping (BookSearchHit) -> Void, onReturnToStart: @escaping (Int) -> Void,
                 onEnd: @escaping () -> Void, onCancel: @escaping () -> Void, onResultsChanged: @escaping () -> Void) {
        self.session = session
        self.pageProvider = pageProvider
        self.onChoose = onChoose
        self.onReturnToStart = onReturnToStart
        self.onEnd = onEnd
        self.onCancel = onCancel
        self.onResultsChanged = onResultsChanged
        super.init(nibName: nil, bundle: nil)
        title = "Cerca nel libro"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) non supportato.") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        // «Annulla» a destra: il titolo si legge per primo (§ 12.1), come «Chiudi» nella finestra dei Segnalibri.
        let cancel = UIBarButtonItem(title: "Annulla", style: .plain, target: self, action: #selector(cancelTapped))
        cancel.accessibilityIdentifier = "ricerca.annulla"
        navigationItem.rightBarButtonItem = cancel

        searchField.placeholder = "Parola o frase"
        searchField.accessibilityLabel = "Cerca nel libro"
        searchField.accessibilityHint = "Scrivi una parola o una frase, poi Cerca"
        searchField.accessibilityIdentifier = "ricerca.campo"
        searchField.returnKeyType = .search
        searchField.enablesReturnKeyAutomatically = true
        searchField.autocorrectionType = .no
        searchField.autocapitalizationType = .none
        searchField.clearButtonMode = .whileEditing
        searchField.font = .preferredFont(forTextStyle: .body)
        searchField.adjustsFontForContentSizeCategory = true
        searchField.delegate = self
        searchField.text = session.query
        searchField.translatesAutoresizingMaskIntoConstraints = false

        wholeWordSwitch.isOn = session.wholeWord
        wholeWordSwitch.accessibilityLabel = "Parola intera"
        wholeWordSwitch.accessibilityIdentifier = "ricerca.parolaIntera"
        wholeWordSwitch.addTarget(self, action: #selector(wholeWordChanged), for: .valueChanged)

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.keyboardDismissMode = .onDrag
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.accessibilityIdentifier = "ricerca.risultati"
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if session.result != nil {
            // Si riapre su una ricerca in corso: VoiceOver comincia dalla frase del conteggio, i risultati subito dopo.
            focusCountRow()
        } else {
            searchField.becomeFirstResponder()
            UIAccessibility.post(notification: .screenChanged, argument: searchField)
        }
    }

    // MARK: Tasti

    override var keyCommands: [UIKeyCommand]? {
        let esc = UIKeyCommand(title: "Annulla", action: #selector(cancelTapped), input: UIKeyCommand.inputEscape, modifierFlags: [])
        esc.wantsPriorityOverSystemBehavior = true
        let find = UIKeyCommand(title: "Cerca nel libro", action: #selector(focusField), input: "f", modifierFlags: .command)
        return [esc, find]
    }

    override func accessibilityPerformEscape() -> Bool {
        cancelTapped()
        return true
    }

    @objc private func focusField() {
        searchField.becomeFirstResponder()
        searchField.selectAll(nil)
        UIAccessibility.post(notification: .layoutChanged, argument: searchField)
    }

    // MARK: Ricerca

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        runSearch(moveFocusToCount: true)
        return true
    }

    @objc private func wholeWordChanged() {
        guard !(searchField.text ?? "").trimmingCharacters(in: .whitespaces).isEmpty else { return }
        runSearch(moveFocusToCount: false)
    }

    /// Esegue la ricerca del campo; alla fine aggiorna l'elenco e dice il conteggio (spostando il fuoco sulla frase del
    /// conteggio dopo «Cerca», con un annuncio se si è cambiata «Parola intera»).
    func runSearch(moveFocusToCount: Bool, completion: (() -> Void)? = nil) {
        let text = searchField.text ?? ""
        isSearching = true
        rowCache = [:]
        tableView.reloadData()
        searchField.resignFirstResponder()
        becomeFirstResponder()   // i tasti restano alla finestra (Esc «Annulla», ⌘F il campo), non al lettore sotto
        session.search(text, wholeWord: wholeWordSwitch.isOn) { [weak self] result in
            guard let self else { return }
            self.isSearching = false
            self.rowCache = [:]
            self.tableView.reloadData()
            self.onResultsChanged()
            if moveFocusToCount {
                self.focusCountRow()
            } else {
                UIAccessibility.post(notification: .announcement, argument: BookSearchWording.countSentence(result))
            }
            completion?()
        }
    }

    private func focusCountRow() {
        tableView.layoutIfNeeded()
        let ip = IndexPath(row: 0, section: sectionIndex(.results)!)
        tableView.scrollToRow(at: ip, at: .top, animated: false)
        tableView.layoutIfNeeded()
        if let cell = tableView.cellForRow(at: ip) {
            UIAccessibility.post(notification: .layoutChanged, argument: cell)
        }
    }

    /// La frase della riga del conteggio (per i test).
    var countSentence: String {
        if isSearching { return "Sto cercando…" }
        guard let r = session.result else {
            return "Scrivi una parola o una frase e premi Cerca. Maiuscole, accenti e apostrofi non contano; "
                + "si cerca anche nel testo delle note."
        }
        return BookSearchWording.countSentence(r)
    }

    // MARK: Uscite (una sola per apertura)

    @objc private func cancelTapped() {
        finish { [onCancel] in onCancel() }
    }

    /// Esc arrivato al lettore sotto la finestra (vedi `ContinuousReadingViewController.keyCommands`): come «Annulla».
    func cancelFromKeyboard() { cancelTapped() }

    /// La finestra riceve i tasti anche quando il campo non li ha (dopo «Cerca»): Esc è «Annulla», ⌘F torna al campo.
    override var canBecomeFirstResponder: Bool { true }

    private func finish(_ action: @escaping () -> Void) {
        guard !finished else { return }
        finished = true
        searchField.resignFirstResponder()
        let presenter = navigationController?.presentingViewController ?? presentingViewController
        if let presenter {
            presenter.dismiss(animated: Motion.animated()) { action() }
        } else {
            action()
        }
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        // Trascinata in giù: come «Annulla».
        guard !finished else { return }
        finished = true
        onCancel()
    }

    // MARK: Elenco

    private var ongoingRows: [Ongoing] {
        var rows: [Ongoing] = []
        if session.positionBeforeSearch != nil { rows.append(.returnToStart) }
        if session.result != nil { rows.append(.end) }
        return rows
    }

    private var sections: [Section] {
        ongoingRows.isEmpty ? [.controls, .results] : [.controls, .ongoing, .results]
    }

    private func sectionIndex(_ s: Section) -> Int? { sections.firstIndex(of: s) }

    func numberOfSections(in tableView: UITableView) -> Int { sections.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch sections[section] {
        case .controls: return 2
        case .ongoing: return ongoingRows.count
        case .results: return 1 + (isSearching ? 0 : (session.result?.hits.count ?? 0))
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch sections[section] {
        case .controls: return nil
        case .ongoing: return "Ricerca in corso"
        case .results: return "Risultati"
        }
    }

    /// Una riga ripresa dal riuso e riportata com'è una riga nuova (come nelle Impostazioni: niente resta della riga di prima).
    private func freshCell(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.accessoryView = nil
        cell.accessoryType = .none
        cell.selectionStyle = .default
        cell.accessibilityTraits = UITableViewCell().accessibilityTraits
        cell.accessibilityLabel = nil
        cell.accessibilityHint = nil
        cell.accessibilityValue = nil
        cell.accessibilityIdentifier = nil
        cell.isAccessibilityElement = true
        cell.contentView.subviews.filter { $0 === searchField }.forEach { $0.removeFromSuperview() }
        cell.contentConfiguration = nil
        return cell
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = freshCell(indexPath)
        switch sections[indexPath.section] {
        case .controls:
            if indexPath.row == 0 {
                // Il campo: è lui l'elemento (la riga no), come un campo di ricerca di sistema.
                cell.isAccessibilityElement = false
                cell.selectionStyle = .none
                cell.contentView.addSubview(searchField)
                NSLayoutConstraint.activate([
                    searchField.topAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.topAnchor),
                    searchField.bottomAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.bottomAnchor),
                    searchField.leadingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.leadingAnchor),
                    searchField.trailingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.trailingAnchor),
                    searchField.heightAnchor.constraint(greaterThanOrEqualToConstant: 36),
                ])
            } else {
                var config = cell.defaultContentConfiguration()
                config.text = "Parola intera"
                config.secondaryText = "Trova la parola da sola, non dentro parole più lunghe"
                config.textProperties.numberOfLines = 0
                config.secondaryTextProperties.numberOfLines = 0
                config.secondaryTextProperties.color = .secondaryLabel
                cell.contentConfiguration = config
                // Interruttore come accessorio della riga, come nelle Impostazioni: VoiceOver legge la riga intera
                // (nome e spiegazione) come un interruttore, e il doppio tap lo cambia.
                cell.accessoryView = wholeWordSwitch
                cell.selectionStyle = .none
            }
        case .ongoing:
            var config = cell.defaultContentConfiguration()
            switch ongoingRows[indexPath.row] {
            case .returnToStart:
                config.text = "Torna dove leggevi"
                cell.accessibilityHint = "Riporta la lettura al punto in cui eri prima di andare ai risultati"
                cell.accessibilityIdentifier = "ricerca.tornaDoveLeggevi"
            case .end:
                config.text = "Chiudi la ricerca"
                cell.accessibilityHint = "Toglie il rotore Risultati della ricerca, le frecce e le evidenze dalla lettura"
                cell.accessibilityIdentifier = "ricerca.chiudi"
            }
            config.textProperties.color = .link
            config.textProperties.numberOfLines = 0
            cell.contentConfiguration = config
            cell.accessibilityLabel = config.text
            cell.accessibilityTraits = .button
        case .results:
            if indexPath.row == 0 {
                var config = cell.defaultContentConfiguration()
                config.text = countSentence
                config.textProperties.font = .preferredFont(forTextStyle: .headline)
                config.textProperties.numberOfLines = 0
                cell.contentConfiguration = config
                cell.selectionStyle = .none
                cell.accessibilityLabel = countSentence
                cell.accessibilityTraits = .staticText
                cell.accessibilityIdentifier = "ricerca.conteggio"
            } else {
                let k = indexPath.row - 1
                guard let r = session.result, k < r.hits.count else { break }
                let row = rowCache[k] ?? session.row(for: r.hits[k], pageProvider: pageProvider)
                rowCache[k] = row
                var config = cell.defaultContentConfiguration()
                let attributed = NSMutableAttributedString(string: row.snippet, attributes: [
                    .font: UIFont.preferredFont(forTextStyle: .body), .foregroundColor: UIColor.label])
                if row.match.length > 0, NSMaxRange(row.match) <= attributed.length {
                    let bold = UIFont.preferredFont(forTextStyle: .body).fontDescriptor.withSymbolicTraits(.traitBold)
                        .map { UIFont(descriptor: $0, size: 0) } ?? UIFont.boldSystemFont(ofSize: 17)
                    attributed.addAttribute(.font, value: bold, range: row.match)
                }
                config.attributedText = attributed
                config.secondaryText = row.location
                config.textProperties.numberOfLines = 0
                config.secondaryTextProperties.numberOfLines = 0
                config.secondaryTextProperties.color = .secondaryLabel
                cell.contentConfiguration = config
                cell.accessibilityLabel = row.accessibilityLabel
                cell.accessibilityTraits = .button
                cell.accessibilityHint = "Porta la lettura qui"
                cell.accessibilityIdentifier = "ricerca.risultato.\(k)"
            }
        }
        return cell
    }

    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        switch sections[indexPath.section] {
        case .controls: return false
        case .ongoing: return true
        case .results: return indexPath.row > 0
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        switch sections[indexPath.section] {
        case .controls:
            return
        case .ongoing:
            switch ongoingRows[indexPath.row] {
            case .returnToStart:
                guard let position = session.positionBeforeSearch else { return }
                finish { [onReturnToStart] in onReturnToStart(position) }
            case .end:
                finish { [onEnd] in onEnd() }
            }
        case .results:
            let k = indexPath.row - 1
            guard k >= 0, let r = session.result, k < r.hits.count else { return }
            let hit = r.hits[k]
            finish { [onChoose] in onChoose(hit) }
        }
    }

    // MARK: Per i test

    var resultRowCountForTesting: Int { (session.result?.hits.count ?? 0) }
    func rowLabelForTesting(_ k: Int) -> String? {
        guard let r = session.result, k < r.hits.count else { return nil }
        return session.row(for: r.hits[k], pageProvider: pageProvider).accessibilityLabel
    }
    func chooseResultForTesting(_ k: Int) {
        guard let s = sectionIndex(.results) else { return }
        tableView(tableView, didSelectRowAt: IndexPath(row: k + 1, section: s))
    }
}
