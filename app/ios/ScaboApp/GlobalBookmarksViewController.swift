//
//  GlobalBookmarksViewController.swift
//  ScaboApp
//
//  La vista GLOBALE dei segnalibri per tag su tutta la libreria (§ 5.6): si raggiunge dalla
//  schermata Tag globali cliccando un tag. In alto la griglia di tag (§ 5.5) preselezionata col tag
//  scelto, con la stessa logica additiva "o": selezionarne altri allarga la lista. In basso la lista
//  dei segnalibri che portano almeno uno dei tag selezionati, ciascuno con il documento di
//  provenienza e la posizione. Doppio tap su una voce apre il documento al punto del segnalibro.
//

import UIKit
import ScaboCore

final class GlobalBookmarksViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private let store: LibraryStore
    private let initialTagIds: Set<String>

    private let tagGrid = TagGridView()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyLabel = UILabel()

    private var items: [LibraryStore.GlobalBookmark] = []

    init(store: LibraryStore, initialTagIds: Set<String>) {
        self.store = store
        self.initialTagIds = initialTagIds
        super.init(nibName: nil, bundle: nil)
        self.title = "Segnalibri per tag"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) non supportato.") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        tagGrid.translatesAutoresizingMaskIntoConstraints = false
        tagGrid.configure(tags: store.tags(), selected: initialTagIds)
        tagGrid.onSelectionChanged = { [weak self] _ in self?.reloadList() }

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "gbm")

        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.font = .preferredFont(forTextStyle: .body)
        emptyLabel.adjustsFontForContentSizeCategory = true
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0
        emptyLabel.text = "Nessun segnalibro per i tag selezionati."

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

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadList()  // riflette eventuali eliminazioni fatte altrove
    }

    private func reloadList() {
        items = store.bookmarksAcrossLibrary(withAnyTag: tagGrid.selectedTagIds)
        emptyLabel.isHidden = !items.isEmpty
        tableView.reloadData()
    }

    // MARK: - Table

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { items.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "gbm", for: indexPath)
        let item = items[indexPath.row]
        var config = cell.defaultContentConfiguration()
        config.text = item.bookmark.displayTitle
        var sub = item.document.title
        if let page = item.bookmark.originalPage { sub += " · pagina \(page)" }
        config.secondaryText = sub
        cell.contentConfiguration = config
        cell.accessibilityTraits = .button
        var label = "\(item.bookmark.displayTitle), in \(item.document.title)"
        if let page = item.bookmark.originalPage { label += ", pagina \(page)" }
        cell.accessibilityLabel = label
        cell.accessibilityHint = "Doppio tap per aprire il documento al segnalibro"
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        let item = items[indexPath.row]
        DocumentOpener.open(
            documentId: item.document.id, from: self,
            focusAnchor: .init(anchorSegmentId: item.bookmark.anchorSegmentId,
                               orderIndexHint: item.bookmark.orderIndexHint))
    }
}
