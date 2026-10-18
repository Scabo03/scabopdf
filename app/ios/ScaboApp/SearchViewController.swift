//
//  SearchViewController.swift
//  ScaboApp
//
//  Il tab Ricerca (§ 13.2): cerca fra TUTTI i file dell'archivio — anche quelli senza collocazione —
//  ed è l'unico punto da cui si compie l'eliminazione DEFINITIVA di un file dall'archivio (§ 12.7,
//  via il menù Opzioni con contesto `.search`). A campo vuoto mostra l'intero archivio.
//
//  Stato v1 e delega a Code (§ 13.2): la ricerca opera su titolo e nome del file. La ricerca a
//  CONTENUTO PIENO e i FILTRI sono esplicitamente demandati dal documento di prodotto alla fase di
//  sviluppo con Code; qui si fornisce la spina dorsale accessibile e l'eliminazione definitiva, e si
//  lascia il gancio per estendere il match al contenuto in cache.
//
//  Accessibilità: barra di ricerca standard di sistema + lista di documenti; ogni riga espone
//  riquadro + Opzioni (§ 12.4). La barra di ricerca è pienamente gestita da VoiceOver.
//  Dal giro «accessibilità e completamento» (2026-10-18) la barra di ricerca sta sopra la lista, sotto il titolo della
//  schermata, e non più nella barra in alto: su iPhone il titolo nella fascia (TabStackNavigationController) sarebbe finito
//  SOTTO il campo di ricerca. Sta FUORI dalla tabella: come intestazione della tabella era esposta due volte (la tabella
//  ripete in coda le viste accessibili delle sue intestazioni). L'ordine di lettura resta titolo, schede, campo di
//  ricerca, risultati.
//

import UIKit
import ScaboCore

final class SearchViewController: UIViewController, UITableViewDataSource, UISearchBarDelegate {

    private var service: LibraryService { .shared }
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let searchBar = UISearchBar()
    private var results: [ArchivedDocument] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Ricerca"
        view.backgroundColor = .systemBackground
        navigationController?.navigationBar.prefersLargeTitles = true

        searchBar.delegate = self
        searchBar.searchBarStyle = .minimal
        searchBar.placeholder = "Cerca nei documenti"
        searchBar.accessibilityLabel = "Cerca nei documenti dell'archivio"
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchBar)

        tableView.dataSource = self
        tableView.keyboardDismissMode = .onDrag
        tableView.register(LibraryRowCell.self, forCellReuseIdentifier: LibraryRowCell.reuseId)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "empty")
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
        applyQuery(searchBar.text)
    }

    private func applyQuery(_ query: String?) {
        let all = service.store.sorted(service.store.allDocuments(), by: .alphabetical)
        let trimmed = (query ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmed.isEmpty {
            results = all
        } else {
            results = all.filter {
                $0.title.lowercased().contains(trimmed) || $0.sourceFileName.lowercased().contains(trimmed)
            }
        }
        tableView.reloadData()
        // Messaggio di stato (WCAG 4.1.3): quando si sta cercando, annuncia il numero di risultati
        // senza rubare il fuoco. Silenzioso a query vuota (mostra tutto l'archivio, non è una ricerca).
        if !trimmed.isEmpty {
            let msg = results.isEmpty ? "Nessun risultato" : "\(results.count) risultati"
            UIAccessibility.post(notification: .announcement, argument: msg)
        }
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        applyQuery(searchText)
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }

    // MARK: - Data

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        max(results.count, 1)
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        results.isEmpty ? nil : "\(results.count) documenti in archivio"
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if results.isEmpty {
            let cell = tableView.dequeueReusableCell(withIdentifier: "empty", for: indexPath)
            var config = cell.defaultContentConfiguration()
            config.text = service.store.allDocuments().isEmpty ? "L'archivio è vuoto" : "Nessun risultato"
            config.secondaryText = service.store.allDocuments().isEmpty
                ? "Importa un documento dalla Home."
                : "Prova con un'altra parola."
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
            DocumentOpener.open(documentId: doc.id, from: self, onClosed: { self.applyQuery(self.searchBar.text) })
        }
        cell.onOptions = { [weak self] in
            guard let self else { return }
            FileOptions.present(document: doc, context: .search, from: self) {
                self.applyQuery(self.searchBar.text)
            }
        }
        return cell
    }
}
