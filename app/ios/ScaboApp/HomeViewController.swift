//
//  HomeViewController.swift
//  ScaboApp
//
//  La Home (§ 12.1): dall'alto verso il basso, i RECENTI (i documenti aperti più di recente,
//  indipendentemente dal contenitore) e i WORKSPACES (i contenitori di primo livello), con il tasto
//  per creare un nuovo workspace allineato all'intestazione "Workspaces". In barra di navigazione,
//  il tasto + di importazione (§ 12.8). Toccando un recente si riapre il documento AL PUNTO DI
//  LETTURA (§ 2.5); toccando un workspace si entra nel contenitore.
//
//  ── Accessibilità (criterio sovrano) ────────────────────────────────────────────────────────
//
//  Lista a sezioni con intestazioni marcate come header (navigabili dal rotore). Ogni riga espone
//  due elementi consecutivi — riquadro + Opzioni (§ 12.4, vedi `LibraryRowCell`). L'intestazione
//  "Workspaces" espone, subito dopo il testo, il tasto "Nuovo workspace" (§ 12.1). Ordine di lettura
//  logico dall'alto in basso; nessun elemento muto.
//

import UIKit
import ScaboCore

final class HomeViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var service: LibraryService { .shared }

    private var recents: [ArchivedDocument] = []
    private var workspaces: [Workspace] = []

    private enum Section: Int, CaseIterable { case recents, workspaces }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "ScaboPDF"
        view.backgroundColor = .systemBackground
        navigationController?.navigationBar.prefersLargeTitles = true

        let importItem = UIBarButtonItem(
            barButtonSystemItem: .add, target: self, action: #selector(importTapped))
        importItem.accessibilityLabel = "Importa un documento"
        importItem.accessibilityHint = "Apre la scelta di un file PDF dal dispositivo"
        navigationItem.rightBarButtonItem = importItem

        // Ingresso alla schermata Tag globali (§ 5.6): gestione dei tag e vista globale dei
        // segnalibri per tag su tutta la libreria.
        let tagsItem = UIBarButtonItem(
            image: UIImage(systemName: "tag"), style: .plain, target: self, action: #selector(tagsTapped))
        tagsItem.accessibilityLabel = "Tag"
        tagsItem.accessibilityHint = "Gestisci i tag e trova i segnalibri per tag"

        // Split screen (§ 11.1): attivabile dalla Home, SOLO su iPad. Su iPhone non si offre.
        if UIDevice.current.userInterfaceIdiom == .pad {
            let splitItem = UIBarButtonItem(
                image: UIImage(systemName: "rectangle.split.2x1"), style: .plain,
                target: self, action: #selector(splitTapped))
            splitItem.accessibilityLabel = "Affianca due documenti"
            splitItem.accessibilityHint = "Apre due documenti in split screen"
            navigationItem.leftBarButtonItems = [tagsItem, splitItem]
        } else {
            navigationItem.leftBarButtonItem = tagsItem
        }

        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(LibraryRowCell.self, forCellReuseIdentifier: LibraryRowCell.reuseId)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "empty")
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
        recents = service.store.recents(limit: 5)
        workspaces = service.store.state.workspaces
        tableView.reloadData()
    }

    // MARK: - Azioni

    @objc private func importTapped() {
        DocumentOpener.startImport(from: self, into: nil) { [weak self] in self?.reload() }
    }

    @objc private func tagsTapped() {
        navigationController?.pushViewController(
            TagsScreenViewController(store: service.store), animated: true)
    }

    /// Attivazione split dalla Home (§ 11.1): si scelgono i due documenti (sinistra, poi destra),
    /// poi si presenta lo split. All'uscita (chiusura di una metà) il documento che resta si apre a
    /// schermo intero.
    @objc private func splitTapped() {
        DocumentChooserViewController.present(from: self) { [weak self] leftId in
            guard let self else { return }
            DocumentChooserViewController.present(from: self) { [weak self] rightId in
                guard let self else { return }
                SplitScreenViewController.present(
                    leftDocumentId: leftId, rightDocumentId: rightId, restoring: nil, from: self
                ) { [weak self] survivorId in
                    self?.dismiss(animated: true) {
                        guard let self else { return }
                        DocumentOpener.open(documentId: survivorId, from: self) { [weak self] in self?.reload() }
                    }
                }
            }
        }
    }

    @objc private func newWorkspaceTapped() {
        LibraryDialogs.prompt(
            title: "Nuovo workspace", message: "Un workspace raggruppa e organizza i tuoi documenti.",
            placeholder: "Nome del workspace", confirmTitle: "Crea", from: self) { [weak self] name in
                self?.service.store.createWorkspace(name: name)
                self?.reload()
            }
    }

    private func openWorkspace(_ ws: Workspace) {
        let vc = ContainerViewController(ref: .workspace(ws.id))
        navigationController?.pushViewController(vc, animated: true)
    }

    private func workspaceOptions(_ ws: Workspace) {
        let sheet = UIAlertController(title: ws.name, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Rinomina", style: .default) { [weak self] _ in
            guard let self else { return }
            LibraryDialogs.prompt(
                title: "Rinomina workspace", message: nil, initialText: ws.name,
                placeholder: "Nome del workspace", from: self) { name in
                    self.service.store.renameWorkspace(id: ws.id, to: name)
                    self.reload()
                }
        })
        sheet.addAction(UIAlertAction(title: "Crea nuova cartella", style: .default) { [weak self] _ in
            guard let self else { return }
            LibraryDialogs.prompt(
                title: "Nuova cartella", message: nil, placeholder: "Nome della cartella",
                confirmTitle: "Crea", from: self) { name in
                    self.service.store.createFolder(inWorkspace: ws.id, name: name)
                    self.reload()
                }
        })
        sheet.addAction(UIAlertAction(title: "Elimina", style: .destructive) { [weak self] _ in
            guard let self else { return }
            LibraryDialogs.confirm(
                title: "Eliminare il workspace?",
                message: "Il workspace «\(ws.name)» e la sua organizzazione vengono rimossi. I file "
                    + "contenuti restano nell'archivio e trovabili dalla Ricerca.",
                confirmTitle: "Elimina", from: self) {
                    self.service.store.deleteWorkspace(id: ws.id)
                    self.reload()
                }
        })
        sheet.addAction(UIAlertAction(title: "Annulla", style: .cancel))
        FileOptions.configurePopover(sheet, in: self)
        present(sheet, animated: true)
    }

    // MARK: - Table data

    func numberOfSections(in tableView: UITableView) -> Int { Section.allCases.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .recents: return recents.count                       // sezione assente se vuota (header nil)
        case .workspaces: return max(workspaces.count, 1)         // almeno la riga "nessun workspace"
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .recents: return recents.isEmpty ? nil : "Recenti"
        case .workspaces: return nil   // header custom (con il tasto Nuovo workspace)
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard Section(rawValue: section) == .workspaces else { return nil }
        return WorkspacesHeaderView(target: self, action: #selector(newWorkspaceTapped))
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        Section(rawValue: section) == .workspaces ? UITableView.automaticDimension : UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .recents:
            return fileCell(recents[indexPath.row], at: indexPath)
        case .workspaces:
            if workspaces.isEmpty {
                let cell = tableView.dequeueReusableCell(withIdentifier: "empty", for: indexPath)
                var config = cell.defaultContentConfiguration()
                config.text = "Nessun workspace"
                config.secondaryText = "Crea un workspace per organizzare i tuoi documenti."
                config.textProperties.numberOfLines = 0
                config.secondaryTextProperties.numberOfLines = 0
                cell.contentConfiguration = config
                cell.selectionStyle = .none
                return cell
            }
            return workspaceCell(workspaces[indexPath.row], at: indexPath)
        }
    }

    private func fileCell(_ doc: ArchivedDocument, at indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: LibraryRowCell.reuseId, for: indexPath) as! LibraryRowCell
        cell.configure(
            title: doc.title,
            detail: LibraryFormatting.fileDetail(doc),
            accessibilityText: LibraryFormatting.fileAccessibility(doc),
            openHint: LibraryFormatting.fileOpenHint,
            symbolName: "doc.text",
            optionsHint: LibraryFormatting.fileOptionsHint)
        cell.onOpen = { [weak self] in
            guard let self else { return }
            DocumentOpener.open(documentId: doc.id, from: self, onClosed: { self.reload() })
        }
        cell.onOptions = { [weak self] in
            guard let self else { return }
            FileOptions.present(document: doc, context: .recents, from: self) { self.reload() }
        }
        return cell
    }

    private func workspaceCell(_ ws: Workspace, at indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: LibraryRowCell.reuseId, for: indexPath) as! LibraryRowCell
        cell.configure(
            title: ws.name,
            detail: LibraryFormatting.workspaceDetail(ws),
            accessibilityText: "\(ws.name), workspace, \(LibraryFormatting.workspaceDetail(ws))",
            openHint: LibraryFormatting.workspaceOpenHint,
            symbolName: "square.stack.3d.up",
            optionsHint: "Rinomina, crea cartella, o elimina il workspace")
        cell.onOpen = { [weak self] in self?.openWorkspace(ws) }
        cell.onOptions = { [weak self] in self?.workspaceOptions(ws) }
        return cell
    }
}

// MARK: - Intestazione "Workspaces" con il tasto Nuovo workspace (§ 12.1)

private final class WorkspacesHeaderView: UITableViewHeaderFooterView {
    init(target: Any, action: Selector) {
        super.init(reuseIdentifier: nil)
        let title = UILabel()
        title.text = "Workspaces"
        title.font = UIFont.preferredFont(forTextStyle: .headline)
        title.adjustsFontForContentSizeCategory = true
        title.translatesAutoresizingMaskIntoConstraints = false
        title.accessibilityTraits.insert(.header)

        let button = UIButton(type: .system)
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "plus.circle")
        config.title = "Nuovo workspace"
        config.imagePadding = 6
        button.configuration = config
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.translatesAutoresizingMaskIntoConstraints = false
        button.accessibilityLabel = "Nuovo workspace"
        button.accessibilityHint = "Crea un nuovo workspace"
        button.addTarget(target, action: action, for: .touchUpInside)

        contentView.addSubview(title)
        contentView.addSubview(button)
        NSLayoutConstraint.activate([
            title.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            title.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            title.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            button.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            button.centerYAnchor.constraint(equalTo: title.centerYAnchor),
            button.leadingAnchor.constraint(greaterThanOrEqualTo: title.trailingAnchor, constant: 8),
        ])
        // Ordine di lettura: prima il testo "Workspaces", poi il tasto (§ 12.1).
        accessibilityElements = [title, button]
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) non supportato.") }
}
