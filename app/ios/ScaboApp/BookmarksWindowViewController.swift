//
//  BookmarksWindowViewController.swift
//  ScaboApp
//
//  La FINESTRA dei Segnalibri del documento corrente (§ 5.4 / § 5.5): finestra contenuta,
//  strutturata in due zone verticali. In alto la GRIGLIA di tag globali (§ 5.4); selezionandone uno
//  o più, la lista sottostante si FILTRA con la logica additiva "o" (§ 5.5). In basso la LISTA dei
//  segnalibri del documento in ordine di occorrenza (§ 5.4): ogni voce mostra il nome (o l'anteprima)
//  e la posizione (pagina del file originale se disponibile).
//
//  Doppio tap su una voce chiude la finestra e porta al punto del segnalibro (`onJump`). Ogni voce
//  espone le azioni personalizzate "modifica" ed "elimina" (VoiceOver), con conferma per l'elimina.
//  È un container modale temporaneo (§ 2.3, § 3.2): il testo dietro non è raggiungibile finché è
//  aperta; alla chiusura il focus torna all'origine (lo cura il chiamante).
//

import UIKit
import ScaboCore

final class BookmarksWindowViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private let store: LibraryStore
    private let documentId: String
    /// Salto al punto del segnalibro: `(ancora, indice-di-fallback)`. Eseguito dopo la chiusura.
    private let onJump: (_ anchorSegmentId: String, _ orderIndexHint: Int) -> Void

    private let tagGrid = TagGridView()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyLabel = UILabel()

    private var filtered: [Bookmark] = []

    static func present(
        from presenter: UIViewController,
        store: LibraryStore,
        documentId: String,
        onJump: @escaping (_ anchorSegmentId: String, _ orderIndexHint: Int) -> Void
    ) {
        let vc = BookmarksWindowViewController(store: store, documentId: documentId, onJump: onJump)
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .formSheet
        presenter.present(nav, animated: true)
    }

    private init(
        store: LibraryStore, documentId: String,
        onJump: @escaping (_ anchorSegmentId: String, _ orderIndexHint: Int) -> Void
    ) {
        self.store = store
        self.documentId = documentId
        self.onJump = onJump
        super.init(nibName: nil, bundle: nil)
        self.title = "Segnalibri"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) non supportato.") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Chiudi", style: .done, target: self, action: #selector(closeTapped))

        tagGrid.translatesAutoresizingMaskIntoConstraints = false
        tagGrid.configure(tags: store.tags(), selected: [])
        tagGrid.onSelectionChanged = { [weak self] _ in self?.reloadList() }

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "bm")

        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.font = .preferredFont(forTextStyle: .body)
        emptyLabel.adjustsFontForContentSizeCategory = true
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0
        emptyLabel.isHidden = true

        let gridHeader = UILabel()
        gridHeader.font = .preferredFont(forTextStyle: .headline)
        gridHeader.adjustsFontForContentSizeCategory = true
        gridHeader.text = "Filtra per tag"
        gridHeader.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(gridHeader)
        view.addSubview(tagGrid)
        view.addSubview(tableView)
        view.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            gridHeader.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            gridHeader.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            gridHeader.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            tagGrid.topAnchor.constraint(equalTo: gridHeader.bottomAnchor, constant: 8),
            tagGrid.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            tagGrid.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            tableView.topAnchor.constraint(equalTo: tagGrid.bottomAnchor, constant: 12),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: tableView.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            emptyLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),
        ])

        reloadList()
    }

    private func reloadList() {
        filtered = store.bookmarks(documentId: documentId, filteredByAnyTag: tagGrid.selectedTagIds)
        let hasAny = !store.bookmarks(documentId: documentId).isEmpty
        emptyLabel.isHidden = !filtered.isEmpty
        emptyLabel.text = hasAny
            ? "Nessun segnalibro per i tag selezionati."
            : "Nessun segnalibro in questo documento. Aggiungine uno con l'azione «aggiungi segnalibro» su un elemento del testo."
        tableView.reloadData()
    }

    @objc private func closeTapped() { dismiss(animated: true) }

    // MARK: - UITableViewDataSource / Delegate

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { filtered.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "bm", for: indexPath)
        let bm = filtered[indexPath.row]
        var config = cell.defaultContentConfiguration()
        config.text = bm.displayTitle
        config.secondaryText = subtitle(for: bm)
        cell.contentConfiguration = config
        cell.accessibilityTraits = .button
        cell.accessibilityLabel = accessibleLabel(for: bm)
        cell.accessibilityHint = "Doppio tap per andare al segnalibro"
        cell.accessibilityCustomActions = [
            UIAccessibilityCustomAction(name: "Modifica") { [weak self] _ in
                self?.editBookmark(bm); return true
            },
            UIAccessibilityCustomAction(name: "Elimina") { [weak self] _ in
                self?.confirmDelete(bm); return true
            },
        ]
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        let bm = filtered[indexPath.row]
        dismiss(animated: true) { [onJump] in onJump(bm.anchorSegmentId, bm.orderIndexHint) }
    }

    // Azioni di swipe per l'utente vedente (parallele alle azioni VoiceOver).
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath)
        -> UISwipeActionsConfiguration? {
        let bm = filtered[indexPath.row]
        let delete = UIContextualAction(style: .destructive, title: "Elimina") { [weak self] _, _, done in
            self?.confirmDelete(bm); done(true)
        }
        let edit = UIContextualAction(style: .normal, title: "Modifica") { [weak self] _, _, done in
            self?.editBookmark(bm); done(true)
        }
        return UISwipeActionsConfiguration(actions: [delete, edit])
    }

    // MARK: - Modifica / elimina

    private func editBookmark(_ bm: Bookmark) {
        BookmarkEditorViewController.present(
            from: self, title: "Modifica segnalibro", preview: bm.preview,
            tags: store.tags(), initialName: bm.name, initialTagIds: Set(bm.tagIds)
        ) { [weak self] name, tagIds in
            guard let self else { return }
            self.store.updateBookmark(documentId: self.documentId, bookmarkId: bm.id, name: name, tagIds: tagIds)
            self.reloadList()
            UIAccessibility.post(notification: .announcement, argument: "Segnalibro aggiornato.")
        }
    }

    private func confirmDelete(_ bm: Bookmark) {
        let alert = UIAlertController(
            title: "Elimina segnalibro",
            message: "Il segnalibro «\(bm.displayTitle)» sarà eliminato definitivamente.",
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Annulla", style: .cancel))
        alert.addAction(UIAlertAction(title: "Elimina", style: .destructive) { [weak self] _ in
            guard let self else { return }
            self.store.deleteBookmark(documentId: self.documentId, bookmarkId: bm.id)
            self.reloadList()
            UIAccessibility.post(notification: .announcement, argument: "Segnalibro eliminato.")
        })
        present(alert, animated: true)
    }

    // MARK: - Formattazione voci

    private func subtitle(for bm: Bookmark) -> String? {
        var parts: [String] = []
        if bm.name != nil, !bm.preview.isEmpty { parts.append(bm.preview) }
        if let page = bm.originalPage { parts.append("pagina \(page)") }
        let tagNames = tagNames(for: bm)
        if !tagNames.isEmpty { parts.append(tagNames.joined(separator: ", ")) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func accessibleLabel(for bm: Bookmark) -> String {
        var parts: [String] = [bm.displayTitle]
        if let page = bm.originalPage { parts.append("pagina \(page) del file originale") }
        let tagNames = tagNames(for: bm)
        if !tagNames.isEmpty { parts.append("tag: " + tagNames.joined(separator: ", ")) }
        return parts.joined(separator: ", ")
    }

    private func tagNames(for bm: Bookmark) -> [String] {
        let byId = Dictionary(uniqueKeysWithValues: store.tags().map { ($0.id, $0.name) })
        return bm.tagIds.compactMap { byId[$0] }
    }
}
