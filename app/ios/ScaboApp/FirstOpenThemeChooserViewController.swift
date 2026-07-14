//
//  FirstOpenThemeChooserViewController.swift
//  ScaboApp
//
//  La scelta del tema alla PRIMA apertura (design DESIGN_ACCESSIBILITA_VISIVA_LETTURA.md:
//  decisione del maintainer che sostituisce il default imposto). REQUISITO CRITICO: la
//  compie una persona cieca o ipovedente PRIMA di aver configurato qualsiasi cosa, quindi
//  dev'essere pienamente accessibile a VoiceOver e comprensibile SENZA vedere i colori —
//  ogni opzione ha una descrizione PARLATA del suo effetto, non solo un campione visivo.
//
//  È una lista esclusiva delle stesse opzioni delle Impostazioni (`AppearanceOptions`):
//  «Segui il sistema» oppure uno dei temi dell'app. La scelta resta modificabile dalle
//  Impostazioni in ogni momento (lo dice il footer). Niente menù numerati, niente
//  «salta»: «Segui il sistema» È la scelta a basso sforzo per chi non vuole decidere.
//

import UIKit
import ScaboCore

final class FirstOpenThemeChooserViewController: UIViewController,
    UITableViewDataSource, UITableViewDelegate {

    private let prefs: KeyValueStore
    private let onComplete: () -> Void
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    init(prefs: KeyValueStore, onComplete: @escaping () -> Void) {
        self.prefs = prefs
        self.onComplete = onComplete
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Come vuoi leggere?"
        view.backgroundColor = .systemBackground
        navigationController?.navigationBar.prefersLargeTitles = true
        // Nessun pulsante di chiusura: la scelta è obbligatoria (una qualsiasi va bene).
        navigationItem.hidesBackButton = true
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "opt")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Assicura che VoiceOver annunci lo scopo della schermata e porti il fuoco nella lista:
        // è la prima cosa che sente un utente cieco, prima di aver configurato nulla.
        UIAccessibility.post(notification: .screenChanged, argument: tableView)
    }

    // MARK: - Tabella

    func numberOfSections(in tableView: UITableView) -> Int { 1 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        AppearanceOptions.all.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        "Scegli come preferisci leggere. Ogni opzione è descritta: scegli quella che ti somiglia."
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        "Potrai cambiare in ogni momento dalle Impostazioni, alla voce «Aspetto della lettura». "
            + "L'app non affida mai un'informazione al solo colore."
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "opt", for: indexPath)
        var config = UIListContentConfiguration.subtitleCell()
        let option = AppearanceOptions.all[indexPath.row]
        config.text = option.title
        config.secondaryText = option.subtitle
        config.textProperties.numberOfLines = 0
        config.textProperties.font = .preferredFont(forTextStyle: .headline)
        config.secondaryTextProperties.numberOfLines = 0
        config.secondaryTextProperties.color = .secondaryLabel
        cell.contentConfiguration = config
        cell.accessoryType = .disclosureIndicator
        cell.accessibilityTraits = .button
        // Etichetta parlata = titolo + descrizione: comprensibile senza vedere i colori.
        cell.accessibilityLabel = "\(option.title). \(option.subtitle)"
        cell.accessibilityHint = "Tocca due volte per scegliere questo tema"
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        AppearanceOptions.apply(AppearanceOptions.all[indexPath.row], to: prefs)
        setStoredFirstOpenCompleted(prefs, true)
        onComplete()
    }
}
