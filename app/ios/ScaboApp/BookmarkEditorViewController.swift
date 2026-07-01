//
//  BookmarkEditorViewController.swift
//  ScaboApp
//
//  La FINESTRA di creazione (e modifica) di un segnalibro (§ 5.7): finestra contenuta, non a
//  schermo intero, con un campo di testo libero per il nome e la griglia dei tag globali a selezione
//  multipla. Porta i due pulsanti standard Conferma e Annulla (§ 3.2). È un container modale
//  temporaneo (§ 2.3): mentre è aperta, il testo dietro non è raggiungibile via swipe, e alla
//  chiusura il focus torna al punto d'origine (lo cura il chiamante).
//
//  Non tocca lo store: raccoglie nome + tag scelti e li restituisce al chiamante via `onConfirm`,
//  che esegue la mutazione (`addBookmark`/`updateBookmark`) e l'annuncio. Così questa vista resta
//  una pura raccolta d'input, riusata identica per creazione e modifica.
//

import UIKit
import ScaboCore

final class BookmarkEditorViewController: UIViewController {

    private let allTags: [Tag]
    private let initialName: String?
    private let initialTagIds: Set<String>
    private let previewText: String
    private let onConfirm: (_ name: String?, _ tagIds: [String]) -> Void

    private let nameField = UITextField()
    private let tagGrid = TagGridView()

    /// Presenta l'editor come finestra contenuta (`.formSheet`) sopra `presenter`. `screenTitle`
    /// distingue creazione ("Nuovo segnalibro") da modifica ("Modifica segnalibro"). `preview` è
    /// mostrato in cima come ancoraggio dell'elemento marcato.
    static func present(
        from presenter: UIViewController,
        title screenTitle: String,
        preview: String,
        tags: [Tag],
        initialName: String?,
        initialTagIds: Set<String>,
        onConfirm: @escaping (_ name: String?, _ tagIds: [String]) -> Void
    ) {
        let editor = BookmarkEditorViewController(
            title: screenTitle, preview: preview, tags: tags,
            initialName: initialName, initialTagIds: initialTagIds, onConfirm: onConfirm)
        let nav = UINavigationController(rootViewController: editor)
        nav.modalPresentationStyle = .formSheet
        presenter.present(nav, animated: true)
    }

    private init(
        title screenTitle: String,
        preview: String,
        tags: [Tag],
        initialName: String?,
        initialTagIds: Set<String>,
        onConfirm: @escaping (_ name: String?, _ tagIds: [String]) -> Void
    ) {
        self.allTags = tags
        self.previewText = preview
        self.initialName = initialName
        self.initialTagIds = initialTagIds
        self.onConfirm = onConfirm
        super.init(nibName: nil, bundle: nil)
        self.title = screenTitle
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) non supportato.") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Annulla", style: .plain, target: self, action: #selector(cancelTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Conferma", style: .done, target: self, action: #selector(confirmTapped))

        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.alwaysBounceVertical = true
        view.addSubview(scroll)

        let content = UIStackView()
        content.axis = .vertical
        content.spacing = 16
        content.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(content)

        // Ancoraggio: l'elemento che si sta marcando (prime parole).
        let previewLabel = UILabel()
        previewLabel.font = .preferredFont(forTextStyle: .subheadline)
        previewLabel.adjustsFontForContentSizeCategory = true
        previewLabel.textColor = .secondaryLabel
        previewLabel.numberOfLines = 3
        previewLabel.text = previewText
        previewLabel.accessibilityLabel = "Elemento: " + previewText

        // Campo nome libero.
        let nameHeader = sectionLabel("Nome del segnalibro (facoltativo)")
        nameField.borderStyle = .roundedRect
        nameField.font = .preferredFont(forTextStyle: .body)
        nameField.adjustsFontForContentSizeCategory = true
        nameField.placeholder = "Nome"
        nameField.text = initialName
        nameField.clearButtonMode = .whileEditing
        nameField.returnKeyType = .done
        nameField.delegate = self
        nameField.accessibilityLabel = "Nome del segnalibro"
        nameField.accessibilityHint = "Facoltativo. Se vuoto, si usa l'anteprima dell'elemento."

        // Griglia dei tag globali (selezione multipla).
        let tagsHeader = sectionLabel("Tag")
        tagGrid.translatesAutoresizingMaskIntoConstraints = false
        tagGrid.configure(tags: allTags, selected: initialTagIds)

        content.addArrangedSubview(previewLabel)
        content.addArrangedSubview(nameHeader)
        content.addArrangedSubview(nameField)
        content.addArrangedSubview(tagsHeader)
        content.addArrangedSubview(tagGrid)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),

            content.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 16),
            content.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -16),
            content.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -16),
            content.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -32),
        ])
    }

    private func sectionLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .headline)
        label.adjustsFontForContentSizeCategory = true
        label.text = text
        return label
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func confirmTapped() {
        let name = nameField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let result: (String?, [String]) = ((name?.isEmpty ?? true) ? nil : name,
                                           Array(tagGrid.selectedTagIds))
        dismiss(animated: true) { [onConfirm] in onConfirm(result.0, result.1) }
    }
}

extension BookmarkEditorViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
