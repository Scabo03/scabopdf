//
//  Choosers.swift
//  ScaboApp
//
//  Due selettori navigabili a VoiceOver usati dalle azioni della libreria:
//
//  • `DestinationChooserViewController` — sceglie un CONTENITORE di destinazione scendendo
//    nell'albero (workspace → cartella → sottocartella), con un pulsante "Colloca qui" a ogni
//    livello. Serve a "Sposta" e ad "Aggiungi a un contenitore" (§ 12.6).
//
//  • `DocumentChooserViewController` — sceglie un DOCUMENTO dall'archivio. Serve a "Aggiungi file"
//    dentro un contenitore (§ 12.6): attinge dall'archivio e colloca.
//
//  Entrambi sono liste standard, pienamente accessibili; il pulsante Annulla chiude senza effetti.
//

import UIKit
import ScaboCore

// MARK: - Scelta del contenitore di destinazione

final class DestinationChooserViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    /// Il livello dell'albero mostrato da questa istanza.
    enum Level {
        case root
        case workspace(String)
        case folder(workspace: String, folder: String)
        case subfolder(workspace: String, folder: String, subfolder: String)
    }

    private let level: Level
    private let store = LibraryService.shared.store
    /// Chiamata quando l'utente conferma un contenitore di destinazione.
    private let onChoose: (ContainerRef) -> Void
    /// Contenitore da ESCLUDERE come destinazione (es. l'origine di uno spostamento).
    private let excluded: ContainerRef?

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    init(level: Level, excluded: ContainerRef?, onChoose: @escaping (ContainerRef) -> Void) {
        self.level = level
        self.excluded = excluded
        self.onChoose = onChoose
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) non supportato.") }

    /// Avvolge un chooser radice in una navigation modale con Annulla. Da presentare così.
    static func present(from presenter: UIViewController, excluded: ContainerRef?, onChoose: @escaping (ContainerRef) -> Void) {
        let root = DestinationChooserViewController(level: .root, excluded: excluded, onChoose: onChoose)
        let nav = UINavigationController(rootViewController: root)
        presenter.present(nav, animated: true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = levelTitle
        if case .root = level {
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))
        }
        if currentRef != nil {
            let collocate = UIBarButtonItem(title: "Colloca qui", style: .done, target: self, action: #selector(collocateHere))
            collocate.accessibilityHint = "Colloca il file in questo contenitore"
            navigationItem.rightBarButtonItem = collocate
        }
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

    /// Il `ContainerRef` di QUESTO livello (nil alla radice, che non è un contenitore).
    private var currentRef: ContainerRef? {
        switch level {
        case .root: return nil
        case .workspace(let w): return .workspace(w)
        case .folder(let w, let f): return .folder(workspace: w, folder: f)
        case .subfolder(let w, let f, let s): return .subfolder(workspace: w, folder: f, subfolder: s)
        }
    }

    private var levelTitle: String {
        switch level {
        case .root: return "Scegli destinazione"
        case .workspace(let w): return store.workspace(id: w)?.name ?? "Workspace"
        case .folder(let w, let f):
            return store.folders(inWorkspace: w).first { $0.id == f }?.name ?? "Cartella"
        case .subfolder(let w, let f, let s):
            return store.subfolders(inWorkspace: w, folderId: f).first { $0.id == s }?.name ?? "Sottocartella"
        }
    }

    /// I figli navigabili del livello corrente (workspace o cartelle o sottocartelle).
    private enum Child { case workspace(Workspace), folder(Folder), subfolder(Subfolder) }
    private var childItems: [Child] {
        switch level {
        case .root: return store.state.workspaces.map { .workspace($0) }
        case .workspace(let w): return store.folders(inWorkspace: w).map { .folder($0) }
        case .folder(let w, let f): return store.subfolders(inWorkspace: w, folderId: f).map { .subfolder($0) }
        case .subfolder: return []
        }
    }

    @objc private func cancelTapped() { dismiss(animated: true) }

    @objc private func collocateHere() {
        guard let ref = currentRef else { return }
        if ref == excluded {
            DocumentOpener.presentError("Il file è già in questo contenitore.", from: self)
            return
        }
        dismiss(animated: true) { [onChoose] in onChoose(ref) }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { childItems.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var config = cell.defaultContentConfiguration()
        switch childItems[indexPath.row] {
        case .workspace(let w):
            config.text = w.name
            config.image = UIImage(systemName: "square.stack.3d.up")
            cell.accessibilityHint = "Doppio tap per aprire il workspace e scegliere dentro"
        case .folder(let f):
            config.text = f.name
            config.image = UIImage(systemName: "folder")
            cell.accessibilityHint = "Doppio tap per aprire la cartella e scegliere dentro"
        case .subfolder(let s):
            config.text = s.name
            config.image = UIImage(systemName: "folder")
            cell.accessibilityHint = "Doppio tap per aprire la sottocartella e scegliere dentro"
        }
        cell.contentConfiguration = config
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let next: DestinationChooserViewController
        switch childItems[indexPath.row] {
        case .workspace(let w):
            next = DestinationChooserViewController(level: .workspace(w.id), excluded: excluded, onChoose: onChoose)
        case .folder(let f):
            guard case .workspace(let w) = level else { return }
            next = DestinationChooserViewController(level: .folder(workspace: w, folder: f.id), excluded: excluded, onChoose: onChoose)
        case .subfolder(let s):
            guard case .folder(let w, let f) = level else { return }
            next = DestinationChooserViewController(
                level: .subfolder(workspace: w, folder: f, subfolder: s.id), excluded: excluded, onChoose: onChoose)
        }
        navigationController?.pushViewController(next, animated: true)
    }
}

// MARK: - Scelta di un documento dall'archivio ("Aggiungi file")

final class DocumentChooserViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private let store = LibraryService.shared.store
    private let onChoose: (String) -> Void
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var documents: [ArchivedDocument] = []

    init(onChoose: @escaping (String) -> Void) {
        self.onChoose = onChoose
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) non supportato.") }

    static func present(from presenter: UIViewController, onChoose: @escaping (String) -> Void) {
        let chooser = DocumentChooserViewController(onChoose: onChoose)
        let nav = UINavigationController(rootViewController: chooser)
        presenter.present(nav, animated: true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Aggiungi un file"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))
        documents = store.sorted(store.allDocuments(), by: .alphabetical)
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

    @objc private func cancelTapped() { dismiss(animated: true) }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        max(documents.count, 1)
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        documents.isEmpty ? "L'archivio è vuoto. Importa un documento con il tasto più." : nil
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var config = cell.defaultContentConfiguration()
        if documents.isEmpty {
            config.text = "Nessun documento in archivio"
            cell.selectionStyle = .none
        } else {
            let doc = documents[indexPath.row]
            config.text = doc.title
            config.secondaryText = LibraryFormatting.fileDetail(doc)
            config.image = UIImage(systemName: "doc.text")
            cell.accessibilityHint = "Doppio tap per aggiungere questo file al contenitore"
        }
        cell.contentConfiguration = config
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !documents.isEmpty else { return }
        let id = documents[indexPath.row].id
        dismiss(animated: true) { [onChoose] in onChoose(id) }
    }
}
