//
//  LibraryRowCell.swift
//  ScaboApp
//
//  La riga riusabile delle liste della libreria (Home, contenitori, Ricerca). Realizza la
//  convenzione di accessibilità del § 12.4: ogni elemento gestibile espone DUE elementi accessibili
//  consecutivi — prima il riquadro dell'elemento (nome + sommario, doppio tap = apri/entra), poi il
//  suo tasto "Opzioni" (i tre puntini), raggiunto dallo swipe immediatamente successivo. Niente
//  gesti nascosti (triplo tap, tap prolungato): ogni funzione è un elemento esplicito (§ 12.4).
//
//  Bi-modale (§ 2.1): resa VISIVA con icona di tipo + titolo + sommario, e resa ACCESSIBILE con
//  etichetta esplicita e hint. Entrambi gli elementi sono UIButton: VoiceOver li annuncia come
//  pulsanti, il doppio tap attiva l'azione, in ordine logico [apri, opzioni].
//

import UIKit

final class LibraryRowCell: UITableViewCell {

    static let reuseId = "LibraryRowCell"

    /// Pulsante principale che occupa la riga: apre il documento o entra nel contenitore.
    private let openButton = UIButton(type: .system)
    /// Pulsante "Opzioni" (tre puntini), raggiunto dallo swipe dopo il riquadro principale.
    private let optionsButton = UIButton(type: .system)

    /// Azione di apertura/ingresso (doppio tap sul riquadro principale).
    var onOpen: (() -> Void)?
    /// Azione del menù Opzioni (doppio tap sui tre puntini).
    var onOptions: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setUp()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) non supportato: LibraryRowCell è costruita in codice.")
    }

    private func setUp() {
        selectionStyle = .none
        backgroundColor = .clear

        var openConfig = UIButton.Configuration.plain()
        openConfig.titleLineBreakMode = .byTruncatingTail
        openConfig.titleAlignment = .leading
        openConfig.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 8)
        openConfig.imagePadding = 12
        openButton.configuration = openConfig
        openButton.contentHorizontalAlignment = .leading
        openButton.tintColor = .label
        openButton.titleLabel?.adjustsFontForContentSizeCategory = true
        openButton.translatesAutoresizingMaskIntoConstraints = false
        openButton.addTarget(self, action: #selector(openTapped), for: .touchUpInside)

        var optionsConfig = UIButton.Configuration.plain()
        optionsConfig.image = UIImage(systemName: "ellipsis.circle")
        optionsConfig.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 16)
        optionsButton.configuration = optionsConfig
        optionsButton.tintColor = .label
        optionsButton.translatesAutoresizingMaskIntoConstraints = false
        optionsButton.setContentHuggingPriority(.required, for: .horizontal)
        optionsButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        optionsButton.accessibilityLabel = "Opzioni"
        optionsButton.addTarget(self, action: #selector(optionsTapped), for: .touchUpInside)

        contentView.addSubview(openButton)
        contentView.addSubview(optionsButton)
        NSLayoutConstraint.activate([
            openButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            openButton.topAnchor.constraint(equalTo: contentView.topAnchor),
            openButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            openButton.trailingAnchor.constraint(equalTo: optionsButton.leadingAnchor),
            optionsButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            optionsButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])

        // Ordine di lettura esplicito: prima il riquadro, poi le Opzioni (§ 12.4).
        isAccessibilityElement = false
        accessibilityElements = [openButton, optionsButton]
    }

    /// Configura la riga. `title` è il nome visualizzato; `detail` il sommario visivo (riga
    /// secondaria); `accessibilityText` ciò che VoiceOver legge sul riquadro principale (più
    /// ricco del solo titolo); `openHint` l'hint del doppio tap; `symbol` l'icona di tipo;
    /// `optionsHint` l'hint del tasto Opzioni.
    func configure(
        title: String,
        detail: String?,
        accessibilityText: String,
        openHint: String,
        symbolName: String,
        optionsHint: String
    ) {
        var config = openButton.configuration
        let titleFont = UIFont.preferredFont(forTextStyle: .body)
        config?.attributedTitle = AttributedString(title, attributes: AttributeContainer([.font: titleFont]))
        if let detail, !detail.isEmpty {
            let detailFont = UIFont.preferredFont(forTextStyle: .footnote)
            config?.attributedSubtitle = AttributedString(
                detail, attributes: AttributeContainer([.font: detailFont]))
        } else {
            config?.attributedSubtitle = nil
        }
        config?.image = UIImage(systemName: symbolName)
        openButton.configuration = config

        openButton.accessibilityLabel = accessibilityText
        openButton.accessibilityHint = openHint
        optionsButton.accessibilityHint = optionsHint
    }

    @objc private func openTapped() { onOpen?() }
    @objc private func optionsTapped() { onOptions?() }

    override func prepareForReuse() {
        super.prepareForReuse()
        onOpen = nil
        onOptions = nil
    }
}
