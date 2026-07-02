//
//  SplitBar.swift
//  ScaboApp
//
//  La barra di split screen (§ 11.3): una striscia orizzontale in cima, a tutta larghezza, ed è un
//  container di accessibilità AUTONOMO e CHIUSO (§ 2.3). Da sinistra a destra: X di chiusura sinistra,
//  al centro la tripletta di parallelizzazione (§ 11.4) più — solo nel regime intermedio — i due
//  tasti di sotto-regime (§ 11.5) e le due frecce di spostamento della linea (§ 11.7), infine a
//  destra la X di chiusura destra.
//
//  I tasti mutuamente esclusivi mostrano lo stato con evidenza visiva e col tratto `.selected` (§ 11.4:
//  VoiceOver annuncia "selezionato"). La barra non decide nulla: instrada ai callback che il
//  `SplitScreenViewController` collega.
//

import UIKit
import ScaboCore

final class SplitBar: UIView {

    // Callback (impostati dal controller).
    var onCloseLeft: (() -> Void)?
    var onCloseRight: (() -> Void)?
    var onSelectRegime: ((ParallelizationRegime) -> Void)?
    var onSelectSubRegime: ((LinkSubRegime) -> Void)?
    var onMoveDivider: ((SplitSide) -> Void)?
    /// Scrub (uscita dal container): passa al container successivo del ciclo (§ 11.8).
    var onEscape: (() -> Void)?

    private let closeLeftButton = SplitBar.iconButton("xmark.circle", "Chiudi documento di sinistra")
    private let closeRightButton = SplitBar.iconButton("xmark.circle", "Chiudi documento di destra")

    private let autonomousButton = SplitBar.textButton("Autonome")
    private let partialButton = SplitBar.textButton("Collegate")
    private let absoluteButton = SplitBar.textButton("Parallele")

    private let followPageButton = SplitBar.textButton("Segui pagina")
    private let followLevelButton = SplitBar.textButton("Segui livello")

    private let dividerLeftButton = SplitBar.iconButton("arrow.left", "Sposta la linea a sinistra")
    private let dividerRightButton = SplitBar.iconButton("arrow.right", "Sposta la linea a destra")

    private lazy var subRegimeStack = UIStackView(arrangedSubviews: [followPageButton, followLevelButton])
    private lazy var centerStack = UIStackView(arrangedSubviews: [
        autonomousButton, partialButton, absoluteButton, subRegimeStack, dividerLeftButton, dividerRightButton,
    ])

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) non supportato.") }

    private func setUp() {
        backgroundColor = .secondarySystemBackground
        isAccessibilityElement = false
        accessibilityContainerType = .semanticGroup

        closeLeftButton.addTarget(self, action: #selector(closeLeftTapped), for: .touchUpInside)
        closeRightButton.addTarget(self, action: #selector(closeRightTapped), for: .touchUpInside)
        autonomousButton.addTarget(self, action: #selector(autonomousTapped), for: .touchUpInside)
        partialButton.addTarget(self, action: #selector(partialTapped), for: .touchUpInside)
        absoluteButton.addTarget(self, action: #selector(absoluteTapped), for: .touchUpInside)
        followPageButton.addTarget(self, action: #selector(followPageTapped), for: .touchUpInside)
        followLevelButton.addTarget(self, action: #selector(followLevelTapped), for: .touchUpInside)
        dividerLeftButton.addTarget(self, action: #selector(dividerLeftTapped), for: .touchUpInside)
        dividerRightButton.addTarget(self, action: #selector(dividerRightTapped), for: .touchUpInside)

        centerStack.axis = .horizontal
        centerStack.spacing = 10
        centerStack.alignment = .center
        subRegimeStack.axis = .horizontal
        subRegimeStack.spacing = 8

        closeLeftButton.translatesAutoresizingMaskIntoConstraints = false
        closeRightButton.translatesAutoresizingMaskIntoConstraints = false
        centerStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(closeLeftButton)
        addSubview(closeRightButton)
        addSubview(centerStack)

        NSLayoutConstraint.activate([
            closeLeftButton.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            closeLeftButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            closeRightButton.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
            closeRightButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            centerStack.centerXAnchor.constraint(equalTo: centerXAnchor),
            centerStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            centerStack.leadingAnchor.constraint(greaterThanOrEqualTo: closeLeftButton.trailingAnchor, constant: 8),
            centerStack.trailingAnchor.constraint(lessThanOrEqualTo: closeRightButton.leadingAnchor, constant: -8),
        ])
    }

    /// Aggiorna lo stato dei tasti mutuamente esclusivi e la visibilità del sotto-regime (§ 11.5:
    /// i due tasti compaiono solo nel regime intermedio) e ricostruisce l'ordine di lettura del
    /// container.
    func configure(regime: ParallelizationRegime, subRegime: LinkSubRegime) {
        applySelected(autonomousButton, regime == .autonomous)
        applySelected(partialButton, regime == .partial)
        applySelected(absoluteButton, regime == .absolute)
        subRegimeStack.isHidden = regime != .partial
        applySelected(followPageButton, subRegime == .followPage)
        applySelected(followLevelButton, subRegime == .followLevel)
        refreshAccessibilityElements()
    }

    private func refreshAccessibilityElements() {
        var elements: [NSObject] = [closeLeftButton, autonomousButton, partialButton, absoluteButton]
        if !subRegimeStack.isHidden {
            elements.append(followPageButton)
            elements.append(followLevelButton)
        }
        elements.append(dividerLeftButton)
        elements.append(dividerRightButton)
        elements.append(closeRightButton)
        accessibilityElements = elements
    }

    private func applySelected(_ button: UIButton, _ isOn: Bool) {
        button.backgroundColor = isOn ? button.tintColor : .tertiarySystemFill
        button.setTitleColor(isOn ? .systemBackground : .label, for: .normal)
        if isOn { button.accessibilityTraits.insert(.selected) }
        else { button.accessibilityTraits.remove(.selected) }
    }

    @objc private func closeLeftTapped() { onCloseLeft?() }
    @objc private func closeRightTapped() { onCloseRight?() }
    @objc private func autonomousTapped() { onSelectRegime?(.autonomous) }
    @objc private func partialTapped() { onSelectRegime?(.partial) }
    @objc private func absoluteTapped() { onSelectRegime?(.absolute) }
    @objc private func followPageTapped() { onSelectSubRegime?(.followPage) }
    @objc private func followLevelTapped() { onSelectSubRegime?(.followLevel) }
    @objc private func dividerLeftTapped() { onMoveDivider?(.left) }
    @objc private func dividerRightTapped() { onMoveDivider?(.right) }

    override func accessibilityPerformEscape() -> Bool {
        guard let onEscape else { return false }
        onEscape()
        return true
    }

    // MARK: - Factory tasti

    private static func iconButton(_ symbol: String, _ label: String) -> UIButton {
        let b = UIButton(type: .system)
        b.setImage(UIImage(systemName: symbol), for: .normal)
        b.accessibilityLabel = label
        return b
    }

    private static func textButton(_ title: String) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(title, for: .normal)
        b.titleLabel?.font = .preferredFont(forTextStyle: .footnote)
        b.titleLabel?.adjustsFontForContentSizeCategory = true
        b.contentEdgeInsets = UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)
        b.layer.cornerRadius = 8
        b.tintColor = .label
        b.accessibilityLabel = title
        return b
    }
}
