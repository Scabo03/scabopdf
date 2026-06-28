//
//  SettingsViewController.swift
//  ScaboApp
//
//  Le impostazioni GLOBALI dell'app (§ 2.5: vivono in un livello separato dal singolo documento):
//  il tema (aspetto), la granularità di lettura predefinita per i testi discorsivi (§ 7.7), e il
//  toggle "Mostra numero pagine file originale" (§ 4.2). Le scelte sono ricordate via il
//  `KeyValueStore` radicato su `UserDefaults`. Il tema viene applicato subito alla finestra.
//
//  Accessibilità: liste standard con righe a spunta (tema, granularità) e un interruttore (pagine
//  originali), tutte pienamente accessibili a VoiceOver; ogni opzione annuncia il proprio stato.
//

import UIKit
import ScaboCore

final class SettingsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private var prefs: KeyValueStore { LibraryService.shared.prefs }
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    private let themes: [(ThemeSelection, String)] = [
        (.system, "Sistema"), (.light, "Chiaro"), (.dark, "Scuro"), (.highContrast, "Alto contrasto"),
    ]
    private let granularities: [(GranularityLevel, String)] = [
        (.fine, "Fine — 400 caratteri"),
        (.medium, "Media — 600 caratteri"),
        (.coarse, "Ampia — 900 caratteri"),
        (.veryCoarse, "Piena — 1200 caratteri"),
    ]

    private enum Section: Int, CaseIterable { case appearance, granularity, pages }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Impostazioni"
        view.backgroundColor = .systemBackground
        navigationController?.navigationBar.prefersLargeTitles = true
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // MARK: - Data

    func numberOfSections(in tableView: UITableView) -> Int { Section.allCases.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .appearance: return themes.count
        case .granularity: return granularities.count
        case .pages: return 1
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .appearance: return "Aspetto"
        case .granularity: return "Granularità di lettura predefinita"
        case .pages: return "Pagine del file originale"
        }
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .granularity:
            return "Quanto testo raggruppare in ogni elemento dei testi discorsivi (manuali, saggi). "
                + "I testi normativi seguono la loro struttura nativa."
        case .pages:
            return "Quando attivo, gli indicatori di pagina mostrano anche la pagina del PDF di "
                + "origine, utile per le citazioni."
        default: return nil
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var config = cell.defaultContentConfiguration()
        config.textProperties.numberOfLines = 0
        cell.accessoryView = nil
        cell.accessoryType = .none
        switch Section(rawValue: indexPath.section)! {
        case .appearance:
            let (selection, label) = themes[indexPath.row]
            config.text = label
            let current = getStoredThemeSelection(prefs)
            cell.accessoryType = (selection == current) ? .checkmark : .none
            cell.accessibilityTraits = (selection == current) ? [.button, .selected] : .button
        case .granularity:
            let (level, label) = granularities[indexPath.row]
            config.text = label
            let current = getStoredGranularityLevel(prefs)
            cell.accessoryType = (level == current) ? .checkmark : .none
            cell.accessibilityTraits = (level == current) ? [.button, .selected] : .button
        case .pages:
            config.text = "Mostra numero pagine file originale"
            let toggle = UISwitch()
            toggle.isOn = getStoredShowOriginalPageNumbers(prefs)
            toggle.addTarget(self, action: #selector(togglePages(_:)), for: .valueChanged)
            toggle.accessibilityLabel = "Mostra numero pagine file originale"
            cell.accessoryView = toggle
            cell.selectionStyle = .none
        }
        cell.contentConfiguration = config
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch Section(rawValue: indexPath.section)! {
        case .appearance:
            let selection = themes[indexPath.row].0
            setStoredThemeSelection(prefs, selection)
            AppTheme.apply(selection, to: view.window)
            tableView.reloadSections(IndexSet(integer: indexPath.section), with: .none)
        case .granularity:
            let level = granularities[indexPath.row].0
            setStoredGranularityLevel(prefs, level)
            tableView.reloadSections(IndexSet(integer: indexPath.section), with: .none)
        case .pages:
            break
        }
    }

    @objc private func togglePages(_ sender: UISwitch) {
        setStoredShowOriginalPageNumbers(prefs, sender.isOn)
    }
}

// MARK: - Applicazione del tema alla finestra

enum AppTheme {
    /// Applica la selezione di tema allo stile dell'interfaccia della finestra. `highContrast`
    /// ricade su scuro (i token ad alto contrasto del testo vivono nel motore di lettura,
    /// `ThemeResolution`, non toccato qui).
    static func apply(_ selection: ThemeSelection, to window: UIWindow?) {
        guard let window else { return }
        switch selection {
        case .light: window.overrideUserInterfaceStyle = .light
        case .dark, .highContrast: window.overrideUserInterfaceStyle = .dark
        case .system: window.overrideUserInterfaceStyle = .unspecified
        }
    }

    /// Applica il tema memorizzato (chiamata all'avvio).
    static func applyStored(to window: UIWindow?) {
        apply(getStoredThemeSelection(LibraryService.shared.prefs), to: window)
    }
}
