//
//  TagsScreenViewController.swift
//  ScaboApp
//
//  La schermata Tag globali (§ 5.6): si raggiunge dalla schermata principale (Home). Permette la
//  gestione completa dei tag dell'utente — creazione, rinomina, eliminazione (§ 5.3, con conferma) —
//  di predefiniti e personali indistintamente (§ 5.2). Cliccare su un tag apre la vista globale dei
//  segnalibri marcati con quel tag su tutta la libreria (§ 5.6), dove si possono poi selezionare più
//  tag con la logica additiva (§ 5.5).
//
//  Ogni riga espone le azioni personalizzate VoiceOver "rinomina" ed "elimina" (più le stesse come
//  swipe per l'utente vedente). La creazione è il pulsante "+" in barra di navigazione. È una
//  schermata piena spinta sullo stack della Home (non un modale): un vero luogo dell'app.
//

import UIKit
import ScaboCore

final class TagsScreenViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private let store: LibraryStore
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let emptyLabel = UILabel()
    private var tags: [Tag] = []

    init(store: LibraryStore) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
        self.title = "Tag"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) non supportato.") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add, target: self, action: #selector(createTapped))
        navigationItem.rightBarButtonItem?.accessibilityLabel = "Nuovo tag"

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "tag")
        view.addSubview(tableView)

        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.font = .preferredFont(forTextStyle: .body)
        emptyLabel.adjustsFontForContentSizeCategory = true
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0
        emptyLabel.text = "Nessun tag. Creane uno con il pulsante «Nuovo tag» in alto a destra."
        view.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            emptyLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),
        ])

        reload()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reload()
    }

    private func reload() {
        tags = store.tags()
        emptyLabel.isHidden = !tags.isEmpty
        tableView.reloadData()
    }

    @objc private func createTapped() {
        LibraryDialogs.prompt(
            title: "Nuovo tag", message: "Il tag sarà disponibile in tutta la libreria.",
            placeholder: "Nome del tag", from: self
        ) { [weak self] name in
            self?.store.createTag(name: name)
            self?.reload()
        }
    }

    private func rename(_ tag: Tag) {
        LibraryDialogs.prompt(
            title: "Rinomina tag", message: nil, initialText: tag.name,
            placeholder: "Nome del tag", from: self
        ) { [weak self] name in
            self?.store.renameTag(id: tag.id, to: name)
            self?.reload()
        }
    }

    private func confirmDelete(_ tag: Tag) {
        LibraryDialogs.confirm(
            title: "Elimina tag",
            message: "Il tag «\(tag.name)» sarà eliminato definitivamente da tutta la libreria. "
                   + "I segnalibri che lo portano restano, perdendo solo questa etichetta.",
            confirmTitle: "Elimina", from: self
        ) { [weak self] in
            self?.store.deleteTag(id: tag.id)
            self?.reload()
            UIAccessibility.post(notification: .announcement, argument: "Tag eliminato.")
        }
    }

    private func openBookmarks(for tag: Tag) {
        let vc = GlobalBookmarksViewController(store: store, initialTagIds: [tag.id])
        navigationController?.pushViewController(vc, animated: true)
    }

    // MARK: - Table

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { tags.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "tag", for: indexPath)
        let tag = tags[indexPath.row]
        var config = cell.defaultContentConfiguration()
        config.text = tag.name
        cell.contentConfiguration = config
        cell.accessoryType = .disclosureIndicator
        cell.accessibilityTraits = .button
        cell.accessibilityLabel = tag.name
        cell.accessibilityHint = "Doppio tap per vedere i segnalibri con questo tag"
        cell.accessibilityCustomActions = [
            UIAccessibilityCustomAction(name: "Rinomina") { [weak self] _ in self?.rename(tag); return true },
            UIAccessibilityCustomAction(name: "Elimina") { [weak self] _ in self?.confirmDelete(tag); return true },
        ]
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        openBookmarks(for: tags[indexPath.row])
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath)
        -> UISwipeActionsConfiguration? {
        let tag = tags[indexPath.row]
        let delete = UIContextualAction(style: .destructive, title: "Elimina") { [weak self] _, _, done in
            self?.confirmDelete(tag); done(true)
        }
        let rename = UIContextualAction(style: .normal, title: "Rinomina") { [weak self] _, _, done in
            self?.rename(tag); done(true)
        }
        return UISwipeActionsConfiguration(actions: [delete, rename])
    }
}
