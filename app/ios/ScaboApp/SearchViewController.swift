//
//  SearchViewController.swift
//  ScaboApp
//
//  Il tab Ricerca (§ 13.2): cerca fra TUTTI i file dell'archivio — anche quelli senza collocazione —
//  ed è l'unico punto da cui si compie l'eliminazione DEFINITIVA di un file dall'archivio (§ 12.7,
//  via il menù Opzioni con contesto `.search`). A campo vuoto mostra l'intero archivio.
//
//  Che cosa cerca. Mentre si scrive, i TITOLI e i NOMI DEI FILE (come prima). Con «Cerca» (A capo, o la riga «Cerca nel
//  testo dei libri») anche il TESTO DI TUTTI I LIBRI (giro «ricerca nella libreria», 2026-10-20; LibrarySearchIndex.swift,
//  ScaboCore LibrarySearch.swift), con le stesse regole della ricerca nel libro (§ 13.3) e la stessa «Parola intera». I
//  filtri del § 13.2 restano per un giro futuro.
//
//  Ordine di lettura (§ 12.1: titolo, schede, comandi, contenuto): il campo di ricerca, poi la sezione «Nel testo dei
//  libri» — «Parola intera», la frase del riassunto (dopo «Cerca» il fuoco va qui: VoiceOver dice subito quanti libri e
//  quanti risultati in tutto), un libro per riga con il titolo e il numero di risultati — poi la sezione «Titoli e nomi
//  dei file», come prima. Scegliendo un libro si apre il libro con la sua lista dei risultati («Cerca nel libro» con la
//  ricerca già fatta); scegliendo un risultato la lettura va lì con il rotore «Risultati della ricerca» attivo. «Annulla»
//  in quella lista lascia la lettura dov'era; «Indietro» dalla lettura torna qui, con i risultati di prima.
//
//  Accessibilità: barra di ricerca standard di sistema + lista; ogni riga di titolo espone riquadro + Opzioni (§ 12.4).
//  Dal giro «accessibilità e completamento» (2026-10-18) la barra di ricerca sta sopra la lista, sotto il titolo della
//  schermata, e non più nella barra in alto: su iPhone il titolo nella fascia (TabStackNavigationController) sarebbe finito
//  SOTTO il campo di ricerca. Sta FUORI dalla tabella: come intestazione della tabella era esposta due volte (la tabella
//  ripete in coda le viste accessibili delle sue intestazioni).
//

import UIKit
import ScaboCore

final class SearchViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate {

    private var service: LibraryService { .shared }
    private var index: LibrarySearchIndex { .shared }
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    let searchBar = UISearchBar()
    let wholeWordSwitch = UISwitch()
    /// I documenti il cui titolo o nome di file contiene la ricerca (a campo vuoto: tutto l'archivio).
    private var results: [ArchivedDocument] = []
    /// La ricerca nel testo dei libri per la ricerca scritta adesso; `nil` finché non la si chiede.
    private(set) var textResult: LibrarySearchResult?
    private var textSearching = false
    /// Cresce a ogni cambio della ricerca scritta: un risultato arrivato per una ricerca di prima si scarta.
    private var textToken = 0

    private enum Section { case archive, text, titles }
    private enum TextRow { case wholeWord, status, book(Int) }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Ricerca"
        view.backgroundColor = .systemBackground
        navigationController?.navigationBar.prefersLargeTitles = true

        searchBar.delegate = self
        searchBar.searchBarStyle = .minimal
        searchBar.placeholder = "Cerca nei documenti"
        searchBar.accessibilityLabel = "Cerca nei documenti dell'archivio"
        searchBar.accessibilityHint = "Mentre scrivi trova i titoli; con Cerca anche il testo di tutti i libri"
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchBar)

        wholeWordSwitch.accessibilityLabel = "Parola intera"
        wholeWordSwitch.accessibilityIdentifier = "libreria.parolaIntera"
        wholeWordSwitch.addTarget(self, action: #selector(wholeWordChanged), for: .valueChanged)

        tableView.dataSource = self
        tableView.delegate = self
        tableView.keyboardDismissMode = .onDrag
        tableView.register(LibraryRowCell.self, forCellReuseIdentifier: LibraryRowCell.reuseId)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "empty")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "text")
        tableView.accessibilityIdentifier = "libreria.lista"
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refresh()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startCatchUp()
    }

    /// I testi di ricerca che mancano si rimettono in pari mentre il tab è aperto; a lavoro finito, se una ricerca nel testo
    /// aveva libri «non ancora pronti», la si rifà in silenzio.
    private func startCatchUp() {
        index.catchUp(isIdle: { [weak self] in
            guard let self, let window = self.view.window else { return false }
            return window.rootViewController?.presentedViewController == nil
        }, completion: { [weak self] in
            guard let self, let r = self.textResult, r.notReady > 0, self.index.lastCatchUpWritten > 0 else { return }
            self.runTextSearch(announce: false)
        })
    }

    private var trimmedQuery: String {
        (searchBar.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var sections: [Section] { trimmedQuery.isEmpty ? [.archive] : [.text, .titles] }

    /// I titoli si ricalcolano; una ricerca nel testo già fatta si rifà in silenzio (un libro eliminato o rielaborato nel
    /// frattempo cambia i risultati), e la lista si ricarica solo se qualcosa è cambiato.
    private func refresh() {
        applyTitles(announce: false)
        tableView.reloadData()
        if textResult != nil { runTextSearch(announce: false) }
    }

    private func applyTitles(announce: Bool) {
        let all = service.store.sorted(service.store.allDocuments(), by: .alphabetical)
        let trimmed = trimmedQuery.lowercased()
        if trimmed.isEmpty {
            results = all
        } else {
            results = all.filter {
                $0.title.lowercased().contains(trimmed) || $0.sourceFileName.lowercased().contains(trimmed)
            }
        }
        // Messaggio di stato (WCAG 4.1.3): mentre si scrive, quanti titoli; silenzioso a campo vuoto (mostra tutto
        // l'archivio, non è una ricerca).
        if announce, !trimmed.isEmpty {
            let msg = results.isEmpty ? "Nessun titolo" : (results.count == 1 ? "Un titolo" : "\(results.count) titoli")
            UIAccessibility.post(notification: .announcement, argument: msg)
        }
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        // Una ricerca scritta diversa: il testo dei libri va cercato di nuovo («Cerca»).
        textToken += 1
        textResult = nil
        textSearching = false
        applyTitles(announce: true)
        tableView.reloadData()
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        runTextSearch(announce: true)
    }

    @objc private func wholeWordChanged() {
        guard !trimmedQuery.isEmpty, textResult != nil || textSearching else { return }
        runTextSearch(announce: true, moveFocus: false)
    }

    /// Cerca la ricerca scritta nel testo di tutti i libri. `announce`: alla fine VoiceOver dice il riassunto (con
    /// `moveFocus` il fuoco va sulla frase del riassunto, come dopo «Cerca» nel libro); senza, la lista si aggiorna in
    /// silenzio e solo se è cambiata.
    func runTextSearch(announce: Bool, moveFocus: Bool = true, completion: (() -> Void)? = nil) {
        let query = trimmedQuery
        guard !query.isEmpty else { completion?(); return }
        let token = textToken
        let previous = textResult
        if announce {
            textSearching = true
            tableView.reloadData()
        }
        index.search(query, wholeWord: wholeWordSwitch.isOn) { [weak self] r in
            guard let self, token == self.textToken else { return }
            self.textSearching = false
            self.textResult = r
            if announce || previous != r { self.tableView.reloadData() }
            if announce {
                if moveFocus { self.focusSummaryRow() } else {
                    UIAccessibility.post(notification: .announcement, argument: BookSearchWording.librarySummary(r))
                }
            }
            completion?()
        }
    }

    private func focusSummaryRow() {
        guard let s = sections.firstIndex(of: .text) else { return }
        let ip = IndexPath(row: 1, section: s)
        tableView.layoutIfNeeded()
        tableView.scrollToRow(at: ip, at: .top, animated: false)
        tableView.layoutIfNeeded()
        if let cell = tableView.cellForRow(at: ip) {
            UIAccessibility.post(notification: .layoutChanged, argument: cell)
        }
    }

    /// La frase della riga di stato della sezione «Nel testo dei libri».
    var textStatusSentence: String {
        if textSearching { return "Sto cercando nel testo dei libri…" }
        if let r = textResult { return BookSearchWording.librarySummary(r) }
        return "Cerca «\(trimmedQuery)» nel testo dei libri"
    }

    // MARK: - Data

    private var textRows: [TextRow] {
        var rows: [TextRow] = [.wholeWord, .status]
        if !textSearching, let r = textResult { rows += r.books.indices.map { TextRow.book($0) } }
        return rows
    }

    func numberOfSections(in tableView: UITableView) -> Int { sections.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch sections[section] {
        case .archive, .titles: return max(results.count, 1)
        case .text: return textRows.count
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch sections[section] {
        case .archive: return nil
        case .text: return "Nel testo dei libri"
        case .titles: return "Titoli e nomi dei file"
        }
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch sections[section] {
        case .archive: return results.isEmpty ? nil : "\(results.count) documenti in archivio"
        case .text, .titles: return nil
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch sections[indexPath.section] {
        case .text:
            return textCell(indexPath)
        case .archive, .titles:
            break
        }
        if results.isEmpty {
            let cell = tableView.dequeueReusableCell(withIdentifier: "empty", for: indexPath)
            var config = cell.defaultContentConfiguration()
            if service.store.allDocuments().isEmpty {
                config.text = "L'archivio è vuoto"
                config.secondaryText = "Importa un documento dalla Home."
            } else if sections[indexPath.section] == .titles {
                config.text = "Nessun titolo o nome di file con «\(trimmedQuery)»"
                config.secondaryText = nil
            } else {
                config.text = "Nessun risultato"
                config.secondaryText = "Prova con un'altra parola."
            }
            config.textProperties.numberOfLines = 0
            config.secondaryTextProperties.numberOfLines = 0
            cell.contentConfiguration = config
            cell.selectionStyle = .none
            return cell
        }
        let doc = results[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: LibraryRowCell.reuseId, for: indexPath) as! LibraryRowCell
        cell.configure(
            title: doc.title,
            detail: LibraryFormatting.fileDetail(doc),
            accessibilityText: LibraryFormatting.fileAccessibility(doc),
            openHint: LibraryFormatting.fileOpenHint,
            symbolName: "doc.text",
            optionsHint: "Apri, aggiungi a un contenitore, rinomina, referto, o elimina definitivamente")
        cell.onOpen = { [weak self] in
            guard let self else { return }
            DocumentOpener.open(documentId: doc.id, from: self, onClosed: { self.refresh() })
        }
        cell.onOptions = { [weak self] in
            guard let self else { return }
            FileOptions.present(document: doc, context: .search, from: self) {
                self.refresh()
            }
        }
        return cell
    }

    /// Una riga ripresa dal riuso e riportata com'è una riga nuova (niente resta della riga di prima).
    private func freshTextCell(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "text", for: indexPath)
        cell.accessoryView = nil
        cell.accessoryType = .none
        cell.selectionStyle = .default
        cell.accessibilityTraits = UITableViewCell().accessibilityTraits
        cell.accessibilityLabel = nil
        cell.accessibilityHint = nil
        cell.accessibilityValue = nil
        cell.accessibilityIdentifier = nil
        cell.isAccessibilityElement = true
        cell.contentConfiguration = nil
        return cell
    }

    private func textCell(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = freshTextCell(indexPath)
        var config = cell.defaultContentConfiguration()
        config.textProperties.numberOfLines = 0
        config.secondaryTextProperties.numberOfLines = 0
        switch textRows[indexPath.row] {
        case .wholeWord:
            config.text = "Parola intera"
            config.secondaryText = "Trova la parola da sola, non dentro parole più lunghe"
            config.secondaryTextProperties.color = .secondaryLabel
            // Interruttore come accessorio della riga, come nelle Impostazioni e in «Cerca nel libro».
            cell.accessoryView = wholeWordSwitch
            cell.selectionStyle = .none
            cell.contentConfiguration = config
        case .status:
            config.text = textStatusSentence
            if textResult == nil, !textSearching {
                // Prima di «Cerca»: la riga è il comando (senza tastiera, o per chi non trova A capo).
                config.textProperties.color = .link
                cell.contentConfiguration = config
                cell.accessibilityLabel = textStatusSentence
                cell.accessibilityTraits = .button
                cell.accessibilityHint = "Cerca nel testo di tutti i libri; lo stesso fa il tasto Cerca della tastiera"
                cell.accessibilityIdentifier = "libreria.cercaNelTesto"
            } else {
                config.textProperties.font = .preferredFont(forTextStyle: .headline)
                cell.contentConfiguration = config
                cell.selectionStyle = .none
                cell.accessibilityLabel = textStatusSentence
                cell.accessibilityTraits = .staticText
                cell.accessibilityIdentifier = "libreria.riassunto"
            }
        case .book(let k):
            guard let r = textResult, k < r.books.count else { break }
            let book = r.books[k]
            config.text = book.title
            config.secondaryText = book.count == 1 ? "un risultato" : "\(BookSearchWording.number(book.count)) risultati"
            config.secondaryTextProperties.color = .secondaryLabel
            cell.contentConfiguration = config
            cell.accessoryType = .disclosureIndicator
            cell.accessibilityLabel = BookSearchWording.libraryBookRow(title: book.title, count: book.count)
            cell.accessibilityTraits = .button
            cell.accessibilityHint = "Apre il libro con l'elenco dei suoi risultati"
            cell.accessibilityIdentifier = "libreria.libro.\(k)"
        }
        return cell
    }

    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        guard sections[indexPath.section] == .text else { return false }
        switch textRows[indexPath.row] {
        case .wholeWord: return false
        case .status: return textResult == nil && !textSearching
        case .book: return true
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        guard sections[indexPath.section] == .text else { return }
        switch textRows[indexPath.row] {
        case .wholeWord:
            return
        case .status:
            guard textResult == nil, !textSearching else { return }
            searchBar.resignFirstResponder()
            runTextSearch(announce: true)
        case .book(let k):
            openBook(k)
        }
    }

    /// Apre il libro `k` dei risultati con la sua lista («Cerca nel libro» con la stessa ricerca e la stessa «Parola intera»).
    func openBook(_ k: Int) {
        guard let r = textResult, k < r.books.count else { return }
        DocumentOpener.open(documentId: r.books[k].documentId, from: self,
                            librarySearch: (query: r.query, wholeWord: r.options.wholeWord),
                            onClosed: { [weak self] in self?.refresh() })
    }
}
