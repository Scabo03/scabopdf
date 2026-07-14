//
//  KeyboardCommandsViewController.swift
//  ScaboApp
//
//  Il pannello «Comandi da tastiera» (aggiunta del maintainer). I comandi da tastiera
//  sono INVISIBILI: chi arriva nuovo non ha modo di sapere che esistono. Questo elenco
//  DESCRITTO li rende scopribili (HIG Apple) ed è pienamente accessibile a VoiceOver:
//  ogni riga annuncia titolo, tasti (a parole) e cosa fa. Legge dalla stessa fonte di
//  verità che costruisce gli `UIKeyCommand` (`KeyboardCommandsCatalog`).
//
//  Personalizzazione dei tasti: iOS/iPadOS NON offre alle app un'API pubblica per
//  riassegnare le combinazioni `UIKeyCommand` (il sistema riserva molte combinazioni e
//  non c'è un meccanismo standard di remapping per-app). Perciò i comandi sono FISSI e
//  lo si dice con onestà nel footer — l'elenco descritto resta comunque il valore
//  principale. Gli stessi strumenti sono raggiungibili anche con VoiceOver, Controllo
//  Vocale, Controllo Interruttori e Full Keyboard Access (azioni personalizzate).
//

import UIKit

final class KeyboardCommandsViewController: UIViewController, UITableViewDataSource {

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let commands = KeyboardCommandsCatalog.reading

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Comandi da tastiera"
        view.backgroundColor = .systemBackground
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cmd")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    func numberOfSections(in tableView: UITableView) -> Int { 1 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        commands.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        "Durante la lettura, con una tastiera esterna"
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        "I comandi sono fissi: iOS non consente alle app di riassegnare le combinazioni di tasti. "
            + "Sono elencati qui perché altrimenti sarebbero invisibili. Gli stessi strumenti sono "
            + "raggiungibili anche con VoiceOver, Controllo Vocale, Controllo Interruttori e Accesso "
            + "completo da tastiera, tramite le azioni personalizzate sull'elemento."
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cmd", for: indexPath)
        let spec = commands[indexPath.row]
        var config = UIListContentConfiguration.subtitleCell()
        config.text = "\(spec.title)    \(spec.displayKeys)"
        config.secondaryText = spec.description
        config.textProperties.numberOfLines = 0
        config.secondaryTextProperties.numberOfLines = 0
        config.secondaryTextProperties.color = .secondaryLabel
        cell.contentConfiguration = config
        cell.selectionStyle = .none
        // Etichetta parlata: titolo, tasti a PAROLE (i glifi ⌘/↓ VoiceOver li leggerebbe male), descrizione.
        cell.accessibilityLabel = "\(spec.title). Tasti: \(spec.spokenKeys). \(spec.description)"
        cell.accessibilityTraits = .staticText
        return cell
    }
}
