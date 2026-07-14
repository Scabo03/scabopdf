//
//  SettingsViewController.swift
//  ScaboApp
//
//  Le impostazioni GLOBALI dell'app (§ 2.5). Il blocco «Aspetto della lettura» è il
//  pannello del sistema di accessibilità visiva (design DESIGN_ACCESSIBILITA_VISIVA_LETTURA.md
//  § 6): un'unica scelta esclusiva di tema (Fonte dell'aspetto + preset fusi in una
//  lista), più gli assi (spaziatura, colore/segnali, guida di lettura), e una riga
//  onesta sui filtri colore di sistema che l'app NON può rilevare. Seguono le voci
//  storiche (granularità, pagine originali). Tutto pienamente accessibile a VoiceOver:
//  ogni riga annuncia il proprio stato; niente menù numerati; l'anello descrizione→
//  scelta è portato dai footer in prosa.
//

import UIKit
import ScaboCore

final class SettingsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private var prefs: KeyValueStore { LibraryService.shared.prefs }
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    /// La lista ESCLUSIVA di tema (Fonte dell'aspetto + preset fusi), condivisa col chooser
    /// di prima apertura: `AppearanceOptions.all`.

    private let spacingRows: [(SpacingProfile, String)] = [
        (.compact, "Compatta"),
        (.standard, "Standard"),
        (.comfortable, "Comoda — più spazio fra righe e parole"),
        (.generous, "Generosa — massimo spazio"),
    ]

    private let accentRows: [(AccentMode, String)] = [
        (.standard, "Colori distinti (consigliato)"),
        (.monochrome, "Senza colore — solo forma e contrasto"),
    ]

    private let granularities: [(GranularityLevel, String)] = [
        (.fine, "Fine — 400 caratteri"),
        (.medium, "Media — 600 caratteri"),
        (.coarse, "Ampia — 900 caratteri"),
        (.veryCoarse, "Piena — 1200 caratteri"),
    ]

    private enum Section: Int, CaseIterable {
        case appearance, spacing, colorSignals, readingGuide, notes, systemFilters, keyboard, granularity, pages
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Impostazioni"
        view.backgroundColor = .systemBackground
        navigationController?.navigationBar.prefersLargeTitles = true
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "subtitle")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // MARK: - Struttura

    func numberOfSections(in tableView: UITableView) -> Int { Section.allCases.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .appearance: return AppearanceOptions.all.count
        case .spacing: return spacingRows.count
        case .colorSignals: return accentRows.count
        case .readingGuide: return 1
        case .notes: return 2
        case .systemFilters: return 1
        case .keyboard: return 1
        case .granularity: return granularities.count
        case .pages: return 1
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .appearance: return "Aspetto della lettura"
        case .spacing: return "Spaziatura del testo"
        case .colorSignals: return "Colore e segnali"
        case .readingGuide: return "Guida di lettura"
        case .notes: return "Note (per chi non sente)"
        case .systemFilters: return "Filtri colore di sistema"
        case .keyboard: return "Tastiera"
        case .granularity: return "Granularità di lettura predefinita"
        case .pages: return "Pagine del file originale"
        }
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .appearance:
            return "Scegli come vuoi leggere. Un preset sposta in blocco sfondo, contrasto e spaziatura; "
                + "puoi poi affinare qui sotto. La scelta è sempre modificabile."
        case .spacing:
            return "Più spazio fra righe e parole aiuta chi fatica a leggere; meno spazio mostra più testo a schermata."
        case .colorSignals:
            return "L'app non affida mai un'informazione al solo colore: sottolineature, box delle modifiche e "
                + "indicatori hanno sempre anche una forma o un'etichetta. «Senza colore» rinuncia del tutto alla tinta."
        case .readingGuide:
            return "Evidenzia l'elemento in lettura e attenua gli altri. È un aiuto alla concentrazione, non una cura."
        case .notes:
            return "Di norma l'identità di una nota è affidata a un suono (earcon). Chi non sente può "
                + "farla annunciare a voce (torna l'intro «Nota.», utile anche col display braille) e/o "
                + "darle un riquadro visivo. Chi preferisce i suoni può lasciare tutto spento: nulla cambia."
        case .keyboard:
            return "Con una tastiera esterna puoi leggere e navigare senza gesti. L'elenco dei comandi "
                + "è qui perché i tasti sono altrimenti invisibili."
        case .systemFilters:
            return "I filtri per il daltonismo (rosso/verde, verde/rosso, blu/giallo) si impostano da Impostazioni "
                + "iOS. L'app non può rilevarli né controllarli, ma garantisce che nulla dipenda dal solo colore. "
                + "Tocca qui per aprire le impostazioni di iOS."
        case .granularity:
            return "Quanto testo raggruppare in ogni elemento dei testi discorsivi (manuali, saggi). "
                + "I testi normativi seguono la loro struttura nativa."
        case .pages:
            return "Quando attivo, gli indicatori di pagina mostrano anche la pagina del PDF di origine."
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .appearance:
            let cell = tableView.dequeueReusableCell(withIdentifier: "subtitle", for: indexPath)
            var config = UIListContentConfiguration.subtitleCell()
            let row = AppearanceOptions.all[indexPath.row]
            config.text = row.title
            config.secondaryText = row.subtitle
            config.textProperties.numberOfLines = 0
            config.secondaryTextProperties.numberOfLines = 0
            config.secondaryTextProperties.color = .secondaryLabel
            cell.contentConfiguration = config
            let selected = isAppearanceRowSelected(indexPath.row)
            cell.accessoryType = selected ? .checkmark : .none
            cell.accessibilityTraits = selected ? [.button, .selected] : .button
            // L'etichetta VoiceOver è titolo + descrizione: comprensibile senza vedere i colori.
            cell.accessibilityLabel = "\(row.title). \(row.subtitle)"
            return cell

        case .spacing:
            let (level, label) = spacingRows[indexPath.row]
            return checkmarkCell(label, selected: getStoredSpacingProfile(prefs) == level)

        case .colorSignals:
            let (mode, label) = accentRows[indexPath.row]
            return checkmarkCell(label, selected: getStoredAccentMode(prefs) == mode)

        case .readingGuide:
            return switchCell(
                "Guida di lettura", isOn: getStoredReadingGuide(prefs),
                action: #selector(toggleReadingGuide(_:)))

        case .notes:
            if indexPath.row == 0 {
                return switchCell(
                    "Annuncia le note a voce", isOn: getStoredNoteSpokenLabels(prefs),
                    action: #selector(toggleNoteSpoken(_:)))
            }
            return switchCell(
                "Riquadro visivo per le note", isOn: getStoredNoteVisualBox(prefs),
                action: #selector(toggleNoteBox(_:)))

        case .systemFilters:
            let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
            var config = cell.defaultContentConfiguration()
            config.text = "Apri le impostazioni di iOS"
            config.textProperties.color = .link
            cell.contentConfiguration = config
            cell.accessoryType = .none
            cell.accessibilityTraits = .button
            cell.accessibilityHint = "Apre Impostazioni iOS per i filtri colore"
            return cell

        case .keyboard:
            let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
            var config = cell.defaultContentConfiguration()
            config.text = "Comandi da tastiera"
            cell.contentConfiguration = config
            cell.accessoryType = .disclosureIndicator
            cell.accessibilityTraits = .button
            cell.accessibilityHint = "Apre l'elenco dei comandi da tastiera"
            return cell

        case .granularity:
            let (level, label) = granularities[indexPath.row]
            return checkmarkCell(label, selected: getStoredGranularityLevel(prefs) == level)

        case .pages:
            return switchCell(
                "Mostra numero pagine file originale", isOn: getStoredShowOriginalPageNumbers(prefs),
                action: #selector(togglePages(_:)))
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch Section(rawValue: indexPath.section)! {
        case .appearance:
            AppearanceOptions.apply(AppearanceOptions.all[indexPath.row], to: prefs)
            ReadingAppearance.applyToWindow(view.window, prefs: prefs)
            tableView.reloadData()  // aggiorna spunte di aspetto E spaziatura (il preset la muove)
        case .spacing:
            setStoredSpacingProfile(prefs, spacingRows[indexPath.row].0)
            tableView.reloadSections(IndexSet(integer: indexPath.section), with: .none)
        case .colorSignals:
            setStoredAccentMode(prefs, accentRows[indexPath.row].0)
            tableView.reloadSections(IndexSet(integer: indexPath.section), with: .none)
        case .systemFilters:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        case .keyboard:
            navigationController?.pushViewController(KeyboardCommandsViewController(), animated: true)
        case .granularity:
            setStoredGranularityLevel(prefs, granularities[indexPath.row].0)
            tableView.reloadSections(IndexSet(integer: indexPath.section), with: .none)
        case .readingGuide, .notes, .pages:
            break
        }
    }

    // MARK: - Helper di cella

    private func isAppearanceRowSelected(_ row: Int) -> Bool {
        AppearanceOptions.isSelected(AppearanceOptions.all[row], prefs: prefs)
    }

    private func checkmarkCell(_ text: String, selected: Bool) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell")!
        var config = cell.defaultContentConfiguration()
        config.text = text
        config.textProperties.numberOfLines = 0
        cell.contentConfiguration = config
        cell.accessoryView = nil
        cell.accessoryType = selected ? .checkmark : .none
        cell.accessibilityTraits = selected ? [.button, .selected] : .button
        return cell
    }

    private func switchCell(_ text: String, isOn: Bool, action: Selector) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell")!
        var config = cell.defaultContentConfiguration()
        config.text = text
        config.textProperties.numberOfLines = 0
        cell.contentConfiguration = config
        let toggle = UISwitch()
        toggle.isOn = isOn
        toggle.addTarget(self, action: action, for: .valueChanged)
        toggle.accessibilityLabel = text
        cell.accessoryView = toggle
        cell.accessoryType = .none
        cell.selectionStyle = .none
        return cell
    }

    @objc private func toggleReadingGuide(_ sender: UISwitch) {
        setStoredReadingGuide(prefs, sender.isOn)
    }

    @objc private func toggleNoteSpoken(_ sender: UISwitch) {
        setStoredNoteSpokenLabels(prefs, sender.isOn)
    }

    @objc private func toggleNoteBox(_ sender: UISwitch) {
        setStoredNoteVisualBox(prefs, sender.isOn)
    }

    @objc private func togglePages(_ sender: UISwitch) {
        setStoredShowOriginalPageNumbers(prefs, sender.isOn)
    }
}
