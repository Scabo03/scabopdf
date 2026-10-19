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

/// Una risorsa visiva fra il contenuto di un articolo (§ 7.9): l'annuncio e quanto serve all'estrazione.
struct QuickVisualItem {
    /// «Tabella» o «Figura», con la didascalia se c'è (il testo dell'elemento nel flusso).
    let label: String
    let payload: VisualResourcePayload
}

/// Dove la Consultazione Rapida mostra le risorse visive del flusso (§ 7.9). Ogni risorsa appartiene all'unità aperta nel
/// flusso, cioè all'ultima intestazione dell'albero che la precede, come i contenuti (`buildQuickConsultTree`). Dentro
/// l'unità sta prima del contenuto che la segue nel flusso; se dopo di lei viene un'intestazione (le tabelle in fondo a un
/// allegato, prima della legge che segue) o se l'unità ha sotto-unità, sta nell'unità stessa: in coda ai contenuti di una
/// foglia, prima dei figli di un'unità con sotto-unità (rilievo della revisione indipendente: una risorsa seguita da
/// un'intestazione non compariva). Prima della prima intestazione resta fuori dall'albero, come il front-matter.
struct QuickVisualPlacement {
    /// Risorse da mostrare prima del contenuto (per id del nodo-contenuto, solo nelle foglie).
    var before: [String: [QuickVisualItem]] = [:]
    /// Risorse dell'unità senza un contenuto che le segua (per id dell'intestazione).
    var inUnit: [String: [QuickVisualItem]] = [:]
    /// Risorse prima della prima intestazione: fuori dall'albero.
    var outside = 0

    var placedCount: Int { before.values.reduce(0) { $0 + $1.count } + inUnit.values.reduce(0) { $0 + $1.count } }

    static func build(segments: [ContentSegment], tree: [QuickConsultNode]) -> QuickVisualPlacement {
        func baseId(_ id: String) -> String {
            id.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? id
        }
        var isLeaf: [String: Bool] = [:], owner: [String: String] = [:]
        func walk(_ n: QuickConsultNode) {
            isLeaf[n.headingId] = n.children.isEmpty
            for c in n.contentIds { owner[c] = n.headingId }
            n.children.forEach(walk)
        }
        tree.forEach(walk)
        var out = QuickVisualPlacement()
        var unit: String?
        for (i, seg) in segments.enumerated() {
            guard let payload = seg.visualResource else {
                let b = baseId(seg.id)
                if isLeaf[b] != nil { unit = b }
                continue
            }
            guard let unit else { out.outside += 1; continue }
            let item = QuickVisualItem(label: seg.text, payload: payload)
            let next = segments[(i + 1)...].first { $0.visualResource == nil }.map { baseId($0.id) }
            if let next, owner[next] == unit, isLeaf[unit] == true {
                out.before[next, default: []].append(item)
            } else {
                out.inUnit[unit, default: []].append(item)
            }
        }
        return out
    }
}

final class QuickConsultView: UIView {

    /// Una riga visibile dell'albero (intestazione o contenuto-foglia).
    private struct Row {
        enum Kind {
            case heading(node: QuickConsultNode, hasChildren: Bool, isLeaf: Bool)
            case content(text: String)
            /// Una risorsa visiva, subito prima del contenuto che porta il suo testo (come nel flusso).
            case visual(item: QuickVisualItem)
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
    /// «Estrai come immagine» su una risorsa visiva: il controller ritaglia e offre il foglio di condivisione.
    /// Il riquadro è nel sistema di coordinate dell'albero (popover iPad).
    var onExtractVisual: ((QuickVisualItem, CGRect) -> Void)?
    /// Dove mostrare le risorse visive (prima di un contenuto, o nell'unità).
    private let visual: QuickVisualPlacement

    private static let cellId = "qc.cell"

    init(roots: [QuickConsultNode], nodeText: [String: String],
         documentTitle: String, expanded: Set<String> = [], visual: QuickVisualPlacement = QuickVisualPlacement()) {
        self.roots = roots
        self.nodeText = nodeText
        self.visual = visual
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
            let unitVisual = (visual.inUnit[node.headingId] ?? []).map {
                Row(kind: .visual(item: $0), depth: node.depth + 1, headingId: "")
            }
            if hasChildren {
                // Le risorse dell'unità (prima delle sue sotto-unità nel flusso) vengono prima dei figli.
                out.append(contentsOf: unitVisual)
                for child in node.children { appendNode(child) }
            } else {
                // Foglia espansa → mostra il contenuto dell'unità (rubrica, commi, note), con le risorse visive al loro posto.
                for cid in node.contentIds {
                    for item in visual.before[cid] ?? [] {
                        out.append(Row(kind: .visual(item: item), depth: node.depth + 1, headingId: ""))
                    }
                    if let text = nodeText[cid], !text.isEmpty {
                        out.append(Row(kind: .content(text: text), depth: node.depth + 1, headingId: ""))
                    }
                }
                out.append(contentsOf: unitVisual)
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

    /// La riga che ha il fuoco di VoiceOver (best-effort), per riportarlo lì dopo una finestra (la ricerca nel libro).
    var focusedRowForRestore: Int? { focusedRowIndex() }

    /// L'elemento di accessibilità della riga `row` (la cella; se non è materializzata la si porta in vista), o `nil`.
    func rowElement(_ row: Int) -> NSObject? {
        guard row >= 0, row < rows.count else { return nil }
        let ip = IndexPath(row: row, section: 0)
        if tableView.cellForRow(at: ip) == nil {
            tableView.scrollToRow(at: ip, at: .middle, animated: false)
            tableView.layoutIfNeeded()
        }
        return tableView.cellForRow(at: ip)
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

    /// Etichette di accessibilità delle righe visibili, in ordine (per i test).
    var rowLabelsForTesting: [String] {
        rows.map { row in
            switch row.kind {
            case let .heading(node, _, _): return headingLabel(node)
            case let .content(text): return text
            case let .visual(item): return "Risorsa visiva. \(item.label)"
            }
        }
    }

    /// Espande l'intestazione con l'id dato (per i test, senza tocchi).
    func expandForTesting(headingId: String) {
        expanded.insert(headingId)
        rebuildRows()
        tableView.reloadData()
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
            let isExpandable = hasChildren || (isLeaf && (!node.contentIds.isEmpty || visual.inUnit[node.headingId] != nil))
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
        case let .visual(item):
            // Come nel flusso: annunciata come risorsa visiva, con l'estrazione come azione (§ 7.9). Il testo che la
            // regione contiene segue nella riga di contenuto, invariato.
            config.text = "Risorsa visiva. \(item.label)"
            config.image = UIImage(systemName: item.payload.kind == .table ? "tablecells" : "photo")
            config.textProperties.font = UIFont.preferredFont(forTextStyle: .body)
            cell.contentConfiguration = config
            cell.accessibilityLabel = "Risorsa visiva. \(item.label)"
            cell.accessibilityTraits = .staticText
            cell.accessibilityValue = "pagina \(item.payload.pageIndex + 1) del file originale"
            cell.accessibilityHint = nil
            cell.accessibilityCustomActions = [
                UIAccessibilityCustomAction(name: "Estrai come immagine") { [weak self, weak cell] _ in
                    guard let self, let cell else { return false }
                    self.onExtractVisual?(item, cell.convert(cell.bounds, to: self))
                    return self.onExtractVisual != nil
                },
            ]
            return cell
        }
        cell.accessibilityCustomActions = nil
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Tocco su una risorsa visiva: per chi non usa VoiceOver, la stessa estrazione dell'azione. Con VoiceOver la riga
        // è testo (il doppio tocco non apre nulla di inatteso): l'estrazione è l'azione dichiarata «Estrai come immagine».
        if indexPath.row < rows.count, case let .visual(item) = rows[indexPath.row].kind {
            if !UIAccessibility.isVoiceOverRunning, let cell = tableView.cellForRow(at: indexPath) {
                onExtractVisual?(item, cell.convert(cell.bounds, to: self))
            }
            return
        }
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
