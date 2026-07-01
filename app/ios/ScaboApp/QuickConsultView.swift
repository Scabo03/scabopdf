//
//  QuickConsultView.swift
//  ScaboApp
//
//  La vista del Layout "Consultazione Rapida" (§ 8 di LAYER2_PRODUCT_DECISIONS): l'albero
//  gerarchico COLLASSABILE che consuma il modello-dati `QuickConsultNode` costruito da
//  ScaboCore (`buildQuickConsultTree`, etichette `quickConsultSummaryLabel`). È il TERZO
//  container di accessibilità della reading view, alternativo al container del testo: la
//  radice del view controller espone, nello scenario blindato, SOLO il container attivo
//  (sigillo strutturale, § 2.2/§ 2.3), e lo scrub a due dita commuta verso l'interfaccia.
//
//  ── Accessibilità VoiceOver (criterio sovrano, § 8 + best practice iOS) ──────────────────
//
//  L'albero è reso con una `UITableView`: ogni RIGA VISIBILE è una cella, elemento di
//  accessibilità a sé. Una riga è una di due specie:
//   • INTESTAZIONE (LIBRO/TITOLO/CAPO/SEZIONE/ARTICOLO): `label` = l'etichetta di summary
//     §8.3 (titolo + range-figli + intervallo-pagine), `value` = "espanso"/"compresso",
//     `traits` = .button, `hint` = come espandere/comprimere (o aprire, per l'articolo);
//   • CONTENUTO (dentro un articolo espanso): testo semplice, nessun tratto pulsante.
//  Al doppio tap su un'intestazione si espande/comprime il ramo: le righe figlie sono
//  inserite/rimosse, il FUOCO RESTA sul pulsante toccato (§ 8.6), il `value` riflette il
//  nuovo stato e un annuncio "espanso"/"nascosto" lo conferma. La profondità è portata dal
//  testo del titolo ("LIBRO QUARTO", "TITOLO II - …") e da un'indentazione visiva.
//  Il livello-foglia (articolo) espanso mostra il contenuto dell'unità (rubrica, commi,
//  note) come righe di testo subito sotto, "come in Lettura Continua" (§ 8.6).
//

import UIKit
import ScaboCore

final class QuickConsultView: UIView {

    /// Una riga visibile dell'albero (intestazione o contenuto-foglia).
    private struct Row {
        enum Kind {
            case heading(node: QuickConsultNode, hasChildren: Bool, isLeaf: Bool)
            case content(text: String)
        }
        let kind: Kind
        let depth: Int
        /// `headingId` dell'intestazione (per lo stato di espansione); vuoto per il contenuto.
        let headingId: String
    }

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let roots: [QuickConsultNode]
    /// Mappa id-nodo → testo, per mostrare il contenuto dell'articolo all'espansione foglia.
    private let nodeText: [String: String]
    /// Titolo del documento, per la catena gerarchica estesa (§ 7).
    private let documentTitle: String

    /// Intestazioni attualmente espanse (per `headingId`). Persistita dal view controller.
    private var expanded: Set<String>
    /// Righe visibili correnti (ricostruite a ogni toggle).
    private var rows: [Row] = []

    /// Escape (scrub a due dita) verso il container dell'interfaccia.
    var onEscape: (() -> Void)?
    /// Notifica al controller che lo stato dell'albero è cambiato (per la persistenza).
    var onExpansionChanged: ((Set<String>) -> Void)?

    private static let cellId = "qc.cell"

    init(roots: [QuickConsultNode], nodeText: [String: String],
         documentTitle: String, expanded: Set<String> = []) {
        self.roots = roots
        self.nodeText = nodeText
        self.documentTitle = documentTitle
        self.expanded = expanded
        super.init(frame: .zero)
        setUp()
        rebuildRows()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) non supportato: QuickConsultView è costruita in codice.")
    }

    private func setUp() {
        backgroundColor = .systemBackground
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Self.cellId)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 56
        tableView.separatorStyle = .none
        addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: topAnchor),
            tableView.leadingAnchor.constraint(equalTo: leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        // Container: la table view è l'unico elemento; VoiceOver vi discende e attraversa le celle.
        accessibilityContainerType = .semanticGroup
    }

    // MARK: - Costruzione delle righe visibili (flatten dell'albero per stato di espansione)

    private func rebuildRows() {
        var out: [Row] = []
        func appendNode(_ node: QuickConsultNode) {
            let hasChildren = !node.children.isEmpty
            let isLeaf = !hasChildren  // foglia = nessun figlio-intestazione (tipicamente l'articolo)
            out.append(Row(kind: .heading(node: node, hasChildren: hasChildren, isLeaf: isLeaf),
                           depth: node.depth, headingId: node.headingId))
            guard expanded.contains(node.headingId) else { return }
            if hasChildren {
                for child in node.children { appendNode(child) }
            } else {
                // Foglia espansa → mostra il contenuto dell'unità (rubrica, commi, note).
                for cid in node.contentIds {
                    if let text = nodeText[cid], !text.isEmpty {
                        out.append(Row(kind: .content(text: text), depth: node.depth + 1, headingId: ""))
                    }
                }
            }
        }
        for root in roots { appendNode(root) }
        rows = out
    }

    // MARK: - Toggle (espandi/comprimi) col fuoco che resta sul pulsante (§ 8.6)

    private func toggle(at index: Int) {
        guard index < rows.count, case let .heading(node, _, _) = rows[index].kind else { return }
        let willExpand = !expanded.contains(node.headingId)
        if willExpand { expanded.insert(node.headingId) } else { expanded.remove(node.headingId) }
        rebuildRows()
        tableView.reloadData()
        onExpansionChanged?(expanded)
        // Il fuoco resta sul pulsante toccato; VoiceOver rilegge la cella col nuovo `value`.
        if let cell = tableView.cellForRow(at: IndexPath(row: index, section: 0)) {
            UIAccessibility.post(notification: .layoutChanged, argument: cell)
        }
        UIAccessibility.post(notification: .announcement, argument: willExpand ? "espanso" : "nascosto")
    }

    // MARK: - Toolbar specifica (§ 8.5): Reset struttura + frecce fra foglie espanse

    /// Comprime tutto l'albero (Reset struttura, § 8.5). Riporta il fuoco alla prima voce.
    func collapseAll() {
        expanded.removeAll()
        rebuildRows()
        tableView.reloadData()
        onExpansionChanged?(expanded)
        if let cell = tableView.cellForRow(at: IndexPath(row: 0, section: 0)) {
            UIAccessibility.post(notification: .screenChanged, argument: cell)
        }
    }

    /// Indici di riga delle FOGLIE (articoli) attualmente espanse, in ordine di documento.
    private func expandedLeafRowIndices() -> [Int] {
        rows.indices.filter { i in
            if case let .heading(_, hasChildren, isLeaf) = rows[i].kind, isLeaf, !hasChildren {
                return expanded.contains(rows[i].headingId)
            }
            return false
        }
    }

    /// Vero se ci sono ≥ 2 foglie espanse (le frecce sono attive solo allora, § 8.5).
    var canNavigateExpandedLeaves: Bool { expandedLeafRowIndices().count >= 2 }

    /// Salta alla prossima/precedente foglia espansa rispetto al fuoco corrente (§ 8.5).
    func navigateExpandedLeaf(forward: Bool) {
        let leaves = expandedLeafRowIndices()
        guard leaves.count >= 2, let firstLeaf = leaves.first, let lastLeaf = leaves.last else { return }
        let current = focusedRowIndex() ?? -1
        let target: Int
        if forward {
            target = leaves.first(where: { $0 > current }) ?? firstLeaf
        } else {
            target = leaves.last(where: { $0 < current }) ?? lastLeaf
        }
        if let cell = tableView.cellForRow(at: IndexPath(row: target, section: 0)) {
            UIAccessibility.post(notification: .screenChanged, argument: cell)
        } else {
            tableView.scrollToRow(at: IndexPath(row: target, section: 0), at: .middle, animated: false)
            DispatchQueue.main.async { [weak self] in
                guard let self,
                      let cell = self.tableView.cellForRow(at: IndexPath(row: target, section: 0)) else { return }
                UIAccessibility.post(notification: .screenChanged, argument: cell)
            }
        }
    }

    /// Indice di riga della cella che ha attualmente il fuoco VoiceOver (best-effort).
    private func focusedRowIndex() -> Int? {
        for ip in tableView.indexPathsForVisibleRows ?? [] {
            if let cell = tableView.cellForRow(at: ip), cell.accessibilityElementIsFocused() {
                return ip.row
            }
        }
        return nil
    }

    // MARK: - Etichette di accessibilità

    /// Etichetta della cella d'intestazione: l'etichetta di summary §8.3 (titolo + range-figli +
    /// intervallo-pagine). Per la foglia (articolo) il range-figli è assente per costruzione.
    private func headingLabel(_ node: QuickConsultNode) -> String {
        quickConsultSummaryLabel(node)
    }

    /// Il primo elemento di accessibilità dell'albero (la prima cella), su cui posare il fuoco
    /// all'ingresso nel Layout. La table view, se non ancora layoutata, può non avere celle: in tal
    /// caso si ritorna la table view stessa (VoiceOver vi discende e si posa sul primo elemento).
    var firstRowElement: NSObject? {
        guard !rows.isEmpty else { return tableView }
        tableView.layoutIfNeeded()
        return tableView.cellForRow(at: IndexPath(row: 0, section: 0)) ?? tableView
    }

    override func accessibilityPerformEscape() -> Bool {
        guard let onEscape else { return false }
        onEscape()
        return true
    }
}

// MARK: - UITableViewDataSource / Delegate

extension QuickConsultView: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { rows.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Self.cellId, for: indexPath)
        let row = rows[indexPath.row]
        var config = cell.defaultContentConfiguration()
        // Indentazione visiva per la profondità (l'utente vedente percepisce l'annidamento).
        config.directionalLayoutMargins.leading = 16 + CGFloat(row.depth - 1) * 16
        cell.selectionStyle = .none
        cell.isAccessibilityElement = true

        switch row.kind {
        case let .heading(node, hasChildren, isLeaf):
            let isExpandable = hasChildren || (isLeaf && !node.contentIds.isEmpty)
            config.text = node.title
            config.textProperties.font = headingFont(forDepth: row.depth)
            cell.contentConfiguration = config
            cell.accessibilityLabel = headingLabel(node)
            cell.accessibilityTraits = .button
            if isExpandable {
                let isOpen = expanded.contains(node.headingId)
                cell.accessibilityValue = isOpen ? "espanso" : "compresso"
                if isLeaf {
                    cell.accessibilityHint = isOpen
                        ? "doppio tap per chiudere l'articolo"
                        : "doppio tap per aprire l'articolo"
                } else {
                    cell.accessibilityHint = isOpen
                        ? "doppio tap per comprimere"
                        : "doppio tap per espandere"
                }
            } else {
                cell.accessibilityValue = nil
                cell.accessibilityHint = nil
            }
        case let .content(text):
            config.text = text
            config.textProperties.font = UIFont.preferredFont(forTextStyle: .body)
            config.textProperties.color = .secondaryLabel
            cell.contentConfiguration = config
            cell.accessibilityLabel = text
            cell.accessibilityTraits = .staticText
            cell.accessibilityValue = nil
            cell.accessibilityHint = nil
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        toggle(at: indexPath.row)
    }

    /// Font del titolo per profondità: livelli alti più grandi (gerarchia visiva + Dynamic Type).
    private func headingFont(forDepth depth: Int) -> UIFont {
        switch depth {
        case 1: return UIFont.preferredFont(forTextStyle: .title2)
        case 2: return UIFont.preferredFont(forTextStyle: .title3)
        case 3: return UIFont.preferredFont(forTextStyle: .headline)
        default: return UIFont.preferredFont(forTextStyle: .body)
        }
    }
}
