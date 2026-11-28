//
//  SearchSettingsViewController.swift
//  ScaboApp
//
//  LA SEZIONE «RICERCA» DELLE IMPOSTAZIONI (giro «scansioni, ricerca e build», 2026-11-28; LAYER2_PRODUCT_DECISIONS § 12.16, decisione
//  31). In cima la frase che spiega i due modi in cui ScaboPDF cerca; poi una domanda per sezione (il titolo della sezione è la domanda),
//  e ogni opzione è una riga a spunta col suo nome e la sua spiegazione, che VoiceOver dice insieme («Nome. Spiegazione.»), con lo
//  stato «selezionato» sulla scelta in uso. Le parole e i valori stanno in ScaboCore (`SearchSettingsWording`, `SearchSettings`), così
//  il Mac userà le stesse quando avrà la sua finestra di ricerca. La scelta vale dalla ricerca successiva.
//

import UIKit
import ScaboChain
import ScaboCore

final class SearchSettingsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private let store: KeyValueStore
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let questions = SearchSettingsWording.questions

    init(store: KeyValueStore = LibraryService.shared.prefs) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
        title = SearchSettingsWording.title
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) non supportato.") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "riga")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // MARK: Struttura: la frase in cima (sezione 0), poi una sezione per domanda.

    func numberOfSections(in tableView: UITableView) -> Int { 1 + questions.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? 1 : questions[section - 1].options.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 0 ? nil : questions[section - 1].title
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        section == 0 ? nil : questions[section - 1].footer
    }

    /// Una riga ripresa dal riuso riportata com'è una riga nuova (come nelle Impostazioni).
    private func freshCell(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "riga", for: indexPath)
        cell.accessoryView = nil
        cell.accessoryType = .none
        cell.selectionStyle = .default
        cell.accessibilityTraits = UITableViewCell().accessibilityTraits
        cell.accessibilityLabel = nil
        cell.accessibilityHint = nil
        cell.accessibilityValue = nil
        cell.accessibilityIdentifier = nil
        return cell
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = freshCell(indexPath)
        if indexPath.section == 0 {
            var config = UIListContentConfiguration.cell()
            config.text = SearchSettingsWording.introduction
            config.textProperties.numberOfLines = 0
            cell.contentConfiguration = config
            cell.selectionStyle = .none
            cell.accessibilityLabel = SearchSettingsWording.introduction
            cell.accessibilityTraits = .staticText
            cell.accessibilityIdentifier = "ricerca.impostazioni.introduzione"
            return cell
        }
        let q = questions[indexPath.section - 1]
        let option = q.options[indexPath.row]
        var config = UIListContentConfiguration.subtitleCell()
        config.text = option.name
        config.secondaryText = option.explanation
        config.textProperties.numberOfLines = 0
        config.secondaryTextProperties.numberOfLines = 0
        config.secondaryTextProperties.color = .secondaryLabel
        cell.contentConfiguration = config
        let selected = q.selectedIndex(in: getStoredSearchSettings(store)) == indexPath.row
        cell.accessoryType = selected ? .checkmark : .none
        cell.accessibilityTraits = selected ? [.button, .selected] : .button
        // Il nome e la spiegazione insieme: chi ascolta capisce che cosa fa la scelta senza vedere la riga sotto.
        cell.accessibilityLabel = option.spoken
        cell.accessibilityIdentifier = "ricerca.impostazioni.\(q.id.rawValue).\(indexPath.row)"
        return cell
    }

    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool { indexPath.section > 0 }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.section > 0 else { return }
        choose(question: indexPath.section - 1, option: indexPath.row)
    }

    /// Sceglie l'opzione della domanda e aggiorna le spunte della sua sezione.
    func choose(question: Int, option: Int) {
        let q = questions[question]
        setStoredSearchSettings(store, q.choosing(option, in: getStoredSearchSettings(store)))
        tableView.reloadSections(IndexSet(integer: question + 1), with: .none)
    }

    // MARK: Per i test

    var questionCountForTesting: Int { questions.count }
    func spokenLabelForTesting(question: Int, option: Int) -> String? {
        guard question < questions.count else { return nil }
        loadViewIfNeeded()
        let cell = tableView(tableView, cellForRowAt: IndexPath(row: option, section: question + 1))
        return cell.accessibilityLabel
    }
    func isSelectedForTesting(question: Int, option: Int) -> Bool {
        loadViewIfNeeded()
        return tableView(tableView, cellForRowAt: IndexPath(row: option, section: question + 1)).accessibilityTraits.contains(.selected)
    }
}
