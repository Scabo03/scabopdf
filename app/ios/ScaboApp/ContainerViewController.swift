//
//  ContainerViewController.swift
//  ScaboApp
//
//  La schermata di un contenitore — workspace, cartella o sottocartella (§ 12.2/§ 12.3). Mostra i
//  sotto-contenitori (cartelle o sottocartelle) e i file collocati qui, con l'ordinamento automatico
//  (§ 12.3) e i tasti per aggiungere file (dall'archivio) o importarne di nuovi (§ 12.6/§ 12.8). In
//  barra di navigazione: il tasto "indietro" di sistema per risalire e il tasto "Opzioni" del
//  contenitore (rinomina, crea sotto-contenitore, elimina — § 12.4).
//
//  Naviga con un'unica classe parametrizzata sul `ContainerRef`: la sottocartella è il fondo
//  dell'annidamento (nessun sotto-contenitore, § 12.2).
//

import UIKit
import ScaboCore

final class ContainerViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private let ref: ContainerRef
    private var service: LibraryService { .shared }
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let sortControl = UISegmentedControl(items: ["A-Z", "Modifica", "Importazione"])
    private var sortOrder: ScaboCore.SortOrder = .alphabetical

    private var subcontainers: [(id: String, name: String, detail: String)] = []
    private var files: [ArchivedDocument] = []

    private enum Section: Int, CaseIterable { case actions, subcontainers, files }

    init(ref: ContainerRef) {
        self.ref = ref
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) non supportato.") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let options = UIBarButtonItem(
            image: UIImage(systemName: "ellipsis.circle"), style: .plain, target: self, action: #selector(containerOptions))
        options.accessibilityLabel = "Opzioni del contenitore"
        navigationItem.rightBarButtonItem = options

        sortControl.selectedSegmentIndex = 0
        sortControl.addTarget(self, action: #selector(sortChanged), for: .valueChanged)
        sortControl.accessibilityLabel = "Ordina i contenuti"

        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(LibraryRowCell.self, forCellReuseIdentifier: LibraryRowCell.reuseId)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "basic")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reload()
    }

    private func reload() {
        title = containerName
        // Sotto-contenitori (cartelle o sottocartelle), ordinati alfabeticamente.
        switch ref {
        case .workspace(let w):
            subcontainers = service.store.folders(inWorkspace: w)
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                .map { (id: $0.id, name: $0.name, detail: LibraryFormatting.folderDetail($0)) }
        case .folder(let w, let f):
            subcontainers = service.store.subfolders(inWorkspace: w, folderId: f)
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                .map { (id: $0.id, name: $0.name, detail: LibraryFormatting.subfolderDetail($0)) }
        case .subfolder:
            subcontainers = []
        }
        // File collocati qui, ordinati secondo il criterio scelto.
        let docs = service.store.fileIds(in: ref).compactMap { service.store.document(id: $0) }
        files = service.store.sorted(docs, by: sortOrder)
        tableView.reloadData()
    }

    private var containerName: String {
        switch ref {
        case .workspace(let w): return service.store.workspace(id: w)?.name ?? "Workspace"
        case .folder(let w, let f):
            return service.store.folders(inWorkspace: w).first { $0.id == f }?.name ?? "Cartella"
        case .subfolder(let w, let f, let s):
            return service.store.subfolders(inWorkspace: w, folderId: f).first { $0.id == s }?.name ?? "Sottocartella"
        }
    }

    private var canHaveSubcontainers: Bool {
        if case .subfolder = ref { return false }
        return true
    }

    private var subcontainerWord: String {
        if case .workspace = ref { return "cartella" }
        return "sottocartella"
    }

    // MARK: - Azioni

    @objc private func sortChanged() {
        let orders: [ScaboCore.SortOrder] = [.alphabetical, .modifiedDate, .importDate]
        sortOrder = orders[sortControl.selectedSegmentIndex]
        reload()
    }

    private func addFileFromArchive() {
        DocumentChooserViewController.present(from: self) { [weak self] documentId in
            guard let self else { return }
            self.service.store.addCollocation(documentId: documentId, to: self.ref)
            self.reload()
        }
    }

    private func importNewFile() {
        DocumentOpener.startImport(from: self, into: ref) { [weak self] in self?.reload() }
    }

    private func openFile(_ doc: ArchivedDocument) {
        DocumentOpener.open(documentId: doc.id, from: self, onClosed: { [weak self] in self?.reload() })
    }

    private func enterSubcontainer(id: String) {
        let childRef: ContainerRef
        switch ref {
        case .workspace(let w): childRef = .folder(workspace: w, folder: id)
        case .folder(let w, let f): childRef = .subfolder(workspace: w, folder: f, subfolder: id)
        case .subfolder: return
        }
        navigationController?.pushViewController(ContainerViewController(ref: childRef), animated: true)
    }

    @objc private func containerOptions() {
        let sheet = UIAlertController(title: containerName, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Rinomina", style: .default) { [weak self] _ in self?.renameContainer() })
        if canHaveSubcontainers {
            let createTitle = subcontainerWord == "cartella" ? "Crea nuova cartella" : "Crea nuova sottocartella"
            sheet.addAction(UIAlertAction(title: createTitle, style: .default) { [weak self] _ in self?.createSubcontainer() })
        }
        sheet.addAction(UIAlertAction(title: "Elimina", style: .destructive) { [weak self] _ in self?.deleteContainer() })
        sheet.addAction(UIAlertAction(title: "Annulla", style: .cancel))
        FileOptions.configurePopover(sheet, in: self)
        present(sheet, animated: true)
    }

    private func renameContainer() {
        LibraryDialogs.prompt(
            title: "Rinomina", message: nil, initialText: containerName,
            placeholder: "Nuovo nome", from: self) { [weak self] name in
                guard let self else { return }
                switch self.ref {
                case .workspace(let w): self.service.store.renameWorkspace(id: w, to: name)
                case .folder(let w, let f): self.service.store.renameFolder(inWorkspace: w, folderId: f, to: name)
                case .subfolder(let w, let f, let s):
                    self.service.store.renameSubfolder(inWorkspace: w, folderId: f, subfolderId: s, to: name)
                }
                self.reload()
            }
    }

    private func createSubcontainer() {
        let word = subcontainerWord
        LibraryDialogs.prompt(
            title: "Nuova \(word)", message: nil, placeholder: "Nome della \(word)",
            confirmTitle: "Crea", from: self) { [weak self] name in
                guard let self else { return }
                switch self.ref {
                case .workspace(let w): self.service.store.createFolder(inWorkspace: w, name: name)
                case .folder(let w, let f): self.service.store.createSubfolder(inWorkspace: w, folderId: f, name: name)
                case .subfolder: break
                }
                self.reload()
            }
    }

    private func deleteContainer() {
        let confirmTitle: String
        switch ref {
        case .workspace: confirmTitle = "Eliminare il workspace?"
        case .folder: confirmTitle = "Eliminare la cartella?"
        case .subfolder: confirmTitle = "Eliminare la sottocartella?"
        }
        LibraryDialogs.confirm(
            title: confirmTitle,
            message: "«\(containerName)» e la sua organizzazione vengono rimossi. I file contenuti "
                + "restano nell'archivio e trovabili dalla Ricerca.",
            confirmTitle: "Elimina", from: self) { [weak self] in
                guard let self else { return }
                switch self.ref {
                case .workspace(let w): self.service.store.deleteWorkspace(id: w)
                case .folder(let w, let f): self.service.store.deleteFolder(inWorkspace: w, folderId: f)
                case .subfolder(let w, let f, let s): self.service.store.deleteSubfolder(inWorkspace: w, folderId: f, subfolderId: s)
                }
                self.navigationController?.popViewController(animated: true)
            }
    }

    private func fileOptions(_ doc: ArchivedDocument) {
        FileOptions.present(document: doc, context: .container(ref), from: self) { [weak self] in self?.reload() }
    }

    // MARK: - Table

    func numberOfSections(in tableView: UITableView) -> Int { Section.allCases.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .actions: return 2
        case .subcontainers: return subcontainers.count
        case .files: return max(files.count, 1)
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .actions: return nil
        case .subcontainers:
            guard !subcontainers.isEmpty else { return nil }
            return subcontainerWord == "cartella" ? "Cartelle" : "Sottocartelle"
        case .files: return "File"
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        // Il controllo di ordinamento vive sopra la sezione File, ma solo se c'è qualcosa da ordinare.
        guard Section(rawValue: section) == .files, !files.isEmpty else { return nil }
        let container = UIView()
        sortControl.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(sortControl)
        NSLayoutConstraint.activate([
            sortControl.leadingAnchor.constraint(equalTo: container.layoutMarginsGuide.leadingAnchor),
            sortControl.trailingAnchor.constraint(lessThanOrEqualTo: container.layoutMarginsGuide.trailingAnchor),
            sortControl.topAnchor.constraint(equalTo: container.topAnchor, constant: 6),
            sortControl.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -6),
        ])
        return container
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .actions:
            let cell = tableView.dequeueReusableCell(withIdentifier: "basic", for: indexPath)
            var config = cell.defaultContentConfiguration()
            if indexPath.row == 0 {
                config.text = "Aggiungi file dall'archivio"
                config.image = UIImage(systemName: "tray.and.arrow.down")
                cell.accessibilityHint = "Colloca qui un documento già presente nell'archivio"
            } else {
                config.text = "Importa un nuovo file"
                config.image = UIImage(systemName: "plus")
                cell.accessibilityHint = "Importa un PDF dal dispositivo e collocalo qui"
            }
            cell.contentConfiguration = config
            cell.accessibilityTraits.insert(.button)
            return cell
        case .subcontainers:
            let item = subcontainers[indexPath.row]
            let cell = tableView.dequeueReusableCell(withIdentifier: LibraryRowCell.reuseId, for: indexPath) as! LibraryRowCell
            let isFolderLevel = subcontainerWord == "cartella"
            cell.configure(
                title: item.name,
                detail: item.detail,
                accessibilityText: "\(item.name), \(subcontainerWord), \(item.detail)",
                openHint: isFolderLevel ? LibraryFormatting.folderOpenHint : LibraryFormatting.subfolderOpenHint,
                symbolName: "folder",
                optionsHint: "Apri il contenitore per gestirlo")
            cell.onOpen = { [weak self] in self?.enterSubcontainer(id: item.id) }
            // Le opzioni del sotto-contenitore si gestiscono entrandovi (tasto Opzioni in alto).
            cell.onOptions = { [weak self] in self?.enterSubcontainer(id: item.id) }
            return cell
        case .files:
            if files.isEmpty {
                let cell = tableView.dequeueReusableCell(withIdentifier: "basic", for: indexPath)
                var config = cell.defaultContentConfiguration()
                config.text = "Nessun file qui"
                config.secondaryText = "Aggiungi un file dall'archivio o importane uno nuovo."
                config.textProperties.numberOfLines = 0
                config.secondaryTextProperties.numberOfLines = 0
                cell.contentConfiguration = config
                cell.selectionStyle = .none
                return cell
            }
            let doc = files[indexPath.row]
            let cell = tableView.dequeueReusableCell(withIdentifier: LibraryRowCell.reuseId, for: indexPath) as! LibraryRowCell
            cell.configure(
                title: doc.title,
                detail: LibraryFormatting.fileDetail(doc),
                accessibilityText: LibraryFormatting.fileAccessibility(doc),
                openHint: LibraryFormatting.fileOpenHint,
                symbolName: "doc.text",
                optionsHint: LibraryFormatting.fileOptionsHint)
            cell.onOpen = { [weak self] in self?.openFile(doc) }
            cell.onOptions = { [weak self] in self?.fileOptions(doc) }
            return cell
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard Section(rawValue: indexPath.section) == .actions else { return }
        if indexPath.row == 0 { addFileFromArchive() } else { importNewFile() }
    }
}
