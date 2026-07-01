//
//  TagGridView.swift
//  ScaboApp
//
//  La GRIGLIA di tag riusabile (§ 5.4 / § 5.7): l'intera griglia globale dell'utente come box
//  cliccabili distinti, ciascuno selezionabile e deselezionabile (§ 5.4). È la superficie condivisa
//  fra la finestra di creazione segnalibro (dove i tag selezionati diventano le associazioni del
//  segnalibro, § 5.7) e le finestre di ritrovamento (dove selezionare tag FILTRA la lista con la
//  logica additiva "o", § 5.5).
//
//  ── VoiceOver (§ 5.5, criterio sovrano) ─────────────────────────────────────────────────────────
//
//  Ogni box è un pulsante accessibile a sé con tratto `.selected` quando attivo (VoiceOver annuncia
//  "selezionato/non selezionato"). A ogni tap — di selezione o di deselezione — si posta un
//  annuncio esplicito con lo stato del tag toccato PIÙ l'elenco completo dei tag attualmente
//  selezionati con nome (§ 5.5). La verbosità non è un problema: l'utente può sempre continuare a
//  swipare interrompendo l'annuncio.
//
//  ── Auto-dimensionamento (niente scroll annidato) ───────────────────────────────────────────────
//
//  La griglia dispone i box a capo entro la propria larghezza (due o tre per riga secondo lo spazio,
//  § 5.4) e riporta la propria altezza via `intrinsicContentSize`, così vive dentro uno stack o uno
//  scroll SENZA scroll proprio: nelle finestre di ritrovamento la lista sottostante prende lo spazio
//  residuo, nella finestra di creazione lo scroll del contenitore la contiene.
//

import UIKit
import ScaboCore

/// Il box cliccabile di un singolo tag: pulsante bi-modale (visivo + accessibile) che riflette lo
/// stato di selezione con lo sfondo e col tratto `.selected`.
final class TagChipButton: UIButton {
    let tagId: String

    init(tag: Tag) {
        self.tagId = tag.id
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        titleLabel?.font = .preferredFont(forTextStyle: .body)
        titleLabel?.adjustsFontForContentSizeCategory = true
        titleLabel?.numberOfLines = 1
        titleLabel?.lineBreakMode = .byTruncatingTail
        contentEdgeInsets = UIEdgeInsets(top: 8, left: 14, bottom: 8, right: 14)
        layer.cornerRadius = 10
        layer.borderWidth = 1
        setTitle(tag.name, for: .normal)
        accessibilityLabel = tag.name
        applySelected(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) non supportato.") }

    /// Aggiorna resa visiva e tratto di accessibilità in base allo stato di selezione.
    func applySelected(_ isOn: Bool) {
        if isOn {
            backgroundColor = tintColor
            setTitleColor(.systemBackground, for: .normal)
            layer.borderColor = UIColor.clear.cgColor
            accessibilityTraits = [.button, .selected]
        } else {
            backgroundColor = .secondarySystemFill
            setTitleColor(.label, for: .normal)
            layer.borderColor = UIColor.separator.cgColor
            accessibilityTraits = .button
        }
    }
}

/// La griglia dei tag, auto-dimensionante, con selezione multipla e annuncio § 5.5.
final class TagGridView: UIView {

    /// Gli id dei tag attualmente selezionati (sola lettura dall'esterno).
    private(set) var selectedTagIds: Set<String> = []

    /// Notifica ogni cambio di selezione (per rifiltrare la lista, § 5.5).
    var onSelectionChanged: ((Set<String>) -> Void)?

    private var tags: [Tag] = []
    private var chips: [TagChipButton] = []
    private var laidOutHeight: CGFloat = 0

    private enum Metric {
        static let hGap: CGFloat = 8
        static let vGap: CGFloat = 8
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = false
        accessibilityContainerType = .semanticGroup
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) non supportato.") }

    /// (Ri)costruisce i box dalla lista di tag globali e dallo stato di selezione iniziale.
    func configure(tags: [Tag], selected: Set<String>) {
        self.tags = tags
        self.selectedTagIds = selected.intersection(Set(tags.map { $0.id }))
        chips.forEach { $0.removeFromSuperview() }
        chips = tags.map { tag in
            let chip = TagChipButton(tag: tag)
            chip.addTarget(self, action: #selector(chipTapped(_:)), for: .touchUpInside)
            chip.applySelected(self.selectedTagIds.contains(tag.id))
            addSubview(chip)
            return chip
        }
        accessibilityElements = chips
        setNeedsLayout()
        invalidateIntrinsicContentSize()
    }

    @objc private func chipTapped(_ sender: TagChipButton) {
        let nowSelected: Bool
        if selectedTagIds.contains(sender.tagId) {
            selectedTagIds.remove(sender.tagId)
            nowSelected = false
        } else {
            selectedTagIds.insert(sender.tagId)
            nowSelected = true
        }
        sender.applySelected(nowSelected)
        announce(toggled: sender, isNowSelected: nowSelected)
        onSelectionChanged?(selectedTagIds)
    }

    /// Annuncio § 5.5: stato del tag toccato + elenco completo dei tag selezionati con nome.
    private func announce(toggled chip: TagChipButton, isNowSelected: Bool) {
        let name = chip.title(for: .normal) ?? ""
        let state = isNowSelected ? "selezionato" : "deselezionato"
        let selectedNames = tags.filter { selectedTagIds.contains($0.id) }.map { $0.name }
        let list = selectedNames.isEmpty
            ? "Nessun tag selezionato."
            : "Tag selezionati: " + selectedNames.joined(separator: ", ") + "."
        UIAccessibility.post(notification: .announcement, argument: "\(name) \(state). \(list)")
    }

    // MARK: - Layout a capo (wrapping) e auto-dimensionamento

    override func layoutSubviews() {
        super.layoutSubviews()
        let maxWidth = bounds.width
        guard maxWidth > 0 else { return }
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for chip in chips {
            let size = chip.systemLayoutSizeFitting(
                CGSize(width: maxWidth, height: UIView.layoutFittingCompressedSize.height))
            let w = min(size.width, maxWidth)
            if x > 0, x + w > maxWidth {
                x = 0
                y += rowHeight + Metric.vGap
                rowHeight = 0
            }
            chip.frame = CGRect(x: x, y: y, width: w, height: size.height)
            x += w + Metric.hGap
            rowHeight = max(rowHeight, size.height)
        }
        let total = chips.isEmpty ? 0 : y + rowHeight
        if abs(total - laidOutHeight) > 0.5 {
            laidOutHeight = total
            invalidateIntrinsicContentSize()
        }
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: laidOutHeight)
    }
}
