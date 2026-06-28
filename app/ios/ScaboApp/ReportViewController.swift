//
//  ReportViewController.swift
//  ScaboApp
//
//  Il referto di elaborazione permanente di un documento (§ 12.10): una schermata consultabile sempre
//  che raccoglie in prosa gli avvisi accumulati durante l'importazione (warning del Layer 1), così
//  l'utente capisce — anche a distanza di tempo — cosa è successo e a quali parti del documento.
//  Niente messaggi criptici: ogni voce è un'etichetta accessibile a sé.
//

import UIKit
import ScaboCore

final class ReportViewController: UIViewController, UITableViewDataSource {

    private let document: ArchivedDocument
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    init(document: ArchivedDocument) {
        self.document = document
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) non supportato.") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Referto di elaborazione"
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done, target: self, action: #selector(closeTapped))
        navigationItem.rightBarButtonItem?.accessibilityLabel = "Chiudi"

        tableView.dataSource = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    @objc private func closeTapped() { dismiss(animated: true) }

    // MARK: - Data

    func numberOfSections(in tableView: UITableView) -> Int { 2 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 2                                   // riepilogo (nome file, pagine)
        default: return max(document.warnings.count, 1)    // avvisi (o "nessun avviso")
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 0 ? "Documento" : "Avvisi di elaborazione"
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        section == 1 && document.warnings.isEmpty
            ? "L'elaborazione è andata a buon fine senza avvisi."
            : nil
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var config = cell.defaultContentConfiguration()
        config.textProperties.numberOfLines = 0
        if indexPath.section == 0 {
            if indexPath.row == 0 {
                config.text = "File di origine"
                config.secondaryText = document.sourceFileName
            } else {
                config.text = "Pagine del file originale"
                config.secondaryText = "\(document.sourcePageCount)"
            }
        } else if document.warnings.isEmpty {
            config.text = "Nessun avviso."
        } else {
            config.text = document.warnings[indexPath.row]
        }
        cell.contentConfiguration = config
        cell.selectionStyle = .none
        return cell
    }
}
