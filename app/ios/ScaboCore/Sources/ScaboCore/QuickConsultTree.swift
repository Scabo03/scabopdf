//
//  QuickConsultTree.swift
//  ScaboCore
//
//  Layer-dati del Layout "Consultazione Rapida" (§ 8 di LAYER2_PRODUCT_DECISIONS):
//  l'albero gerarchico collassabile che la vista nativa consuma. Questo modulo è
//  PURO (nessuna UIKit): costruisce l'albero dai nodi del `ScabopdfDocument` e ne
//  calcola le etichette di summary (range-figli + intervallo-pagine, § 8.3). La vista
//  nativa (UIKit, accessibilità VoiceOver) lo renderà a tendine; qui sta solo la
//  struttura, testabile contro la struttura reale del Layer 1.
//
//  L'albero ha fino a CINQUE livelli annidati e distinti (decisione utente per i
//  codici): LIBRO → TITOLO → CAPO → SEZIONE → ARTICOLO. I livelli derivano dal ruolo
//  del nodo-intestazione: HEADING_1..4 → livelli 1..4, ARTICLE_HEADER → livello 5
//  (la foglia). I livelli intermedi sono OPZIONALI (un articolo può stare diretto
//  sotto un CAPO senza SEZIONE): lo stack di costruzione lo gestisce naturalmente.
//  Lo stesso meccanismo serve ogni documento con gerarchia (manuali Parte→Capitolo→
//  Sezione→Paragrafo, voci EdD, ecc.): il livello-foglia è l'ultimo ruolo presente.
//

import Foundation

/// Un nodo dell'albero di Consultazione Rapida.
public struct QuickConsultNode: Equatable, Sendable {
    /// Ruolo del nodo-intestazione (HEADING_1..4 o ARTICLE_HEADER).
    public let role: String
    /// Profondità nell'albero (1 = livello più alto presente).
    public let depth: Int
    /// Testo dell'intestazione (l'etichetta base; es. «TITOLO II - Dei contratti…»).
    public let title: String
    /// Id del nodo-intestazione nel documento (per il focus e l'espansione).
    public let headingId: String
    /// Intervallo di pagine del FILE (page_index 0-based) coperto dall'unità.
    public let firstPage: Int
    public let lastPage: Int
    /// Figli del livello immediatamente inferiore.
    public var children: [QuickConsultNode]
    /// Id dei nodi-contenuto dell'unità-foglia (corpo/commi/note), da mostrare
    /// all'espansione dell'articolo. Vuoto per i nodi non-foglia.
    public var contentIds: [String]
}

/// Ruolo → profondità d'albero assoluta (LIBRO=1 … ARTICOLO=5); nil se non è un
/// nodo-intestazione dell'albero (corpo, note, artefatti).
func quickConsultLevel(_ role: String) -> Int? {
    switch role {
    case "HEADING_1": return 1
    case "HEADING_2": return 2
    case "HEADING_3": return 3
    case "HEADING_4": return 4
    case "ARTICLE_HEADER": return 5
    default: return nil
    }
}

private final class MutableTreeNode {
    let role: String
    let absLevel: Int
    let title: String
    let headingId: String
    let page: Int
    var children: [MutableTreeNode] = []
    var contentIds: [String] = []
    var minContentPage: Int
    var maxContentPage: Int
    init(role: String, absLevel: Int, title: String, headingId: String, page: Int) {
        self.role = role; self.absLevel = absLevel; self.title = title
        self.headingId = headingId; self.page = page
        self.minContentPage = page; self.maxContentPage = page
    }
}

/// Costruisce l'albero di Consultazione Rapida dai nodi del documento (in ordine di
/// lettura). I nodi-intestazione (per ruolo) formano la gerarchia tramite uno stack
/// per livello ASSOLUTO (così i livelli intermedi mancanti non rompono l'annidamento);
/// i nodi-contenuto si attaccano all'unità-foglia aperta. I nodi-contenuto prima della
/// prima intestazione (front-matter) non entrano nell'albero. Le profondità emesse sono
/// COMPATTATE (1 = livello più alto effettivamente presente) per non lasciare buchi.
public func buildQuickConsultTree(_ document: ScabopdfDocument) -> [QuickConsultNode] {
    var roots: [MutableTreeNode] = []
    var stack: [MutableTreeNode] = []
    for node in document.structure {
        let role = node.type.rawValue
        if let absLevel = quickConsultLevel(role) {
            // Risali lo stack fino al primo genitore di livello assoluto inferiore.
            while let top = stack.last, top.absLevel >= absLevel { stack.removeLast() }
            let new = MutableTreeNode(
                role: role, absLevel: absLevel,
                title: (node.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                headingId: node.id, page: node.page_index)
            if let parent = stack.last { parent.children.append(new) } else { roots.append(new) }
            stack.append(new)
        } else if let leaf = stack.last {
            leaf.contentIds.append(node.id)   // contenuto dell'unità aperta (per l'espansione)
            leaf.minContentPage = min(leaf.minContentPage, node.page_index)
            leaf.maxContentPage = max(leaf.maxContentPage, node.page_index)
        }
    }
    return roots.map { freeze($0, depth: 1) }
}

/// Congela il sotto-albero in `QuickConsultNode` immutabili, calcolando in post-ordine
/// l'intervallo-pagine (min/max su sé + discendenti) e compattando la profondità.
private func freeze(_ n: MutableTreeNode, depth: Int) -> QuickConsultNode {
    let kids = n.children.map { freeze($0, depth: depth + 1) }
    var first = min(n.page, n.minContentPage), last = max(n.page, n.maxContentPage)
    for k in kids { first = min(first, k.firstPage); last = max(last, k.lastPage) }
    return QuickConsultNode(
        role: n.role, depth: depth, title: n.title, headingId: n.headingId,
        firstPage: first, lastPage: last, children: kids, contentIds: n.contentIds)
}

// MARK: - Etichetta di summary (§ 8.3): titolo + range-figli + intervallo-pagine

/// Nome del livello-figlio al plurale per l'etichetta di range (§ 8.3), dal ruolo dei figli.
private func childUnitPluralName(_ childRole: String) -> String {
    switch childRole {
    case "HEADING_1": return "libri"
    case "HEADING_2": return "titoli"
    case "HEADING_3": return "capi"
    case "HEADING_4": return "sezioni"
    case "ARTICLE_HEADER": return "articoli"
    default: return "voci"
    }
}

/// Estrae l'ordinale dall'etichetta di un figlio per il range «da X a Y»: il numero
/// d'articolo (es. «1218») o il romano della divisione (es. «IX» da «TITOLO IX - …»).
func quickConsultOrdinal(_ title: String) -> String {
    let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
    // Divisione: «PAROLA <romano>» → il romano.
    let romano = try! NSRegularExpression(pattern: "^(?:LIBRO|TITOLO|CAPO|SEZIONE)\\s+([IVXLCDM]+)")
    if let m = romano.firstMatch(in: t, range: NSRange(t.startIndex..<t.endIndex, in: t)),
       let r = Range(m.range(at: 1), in: t) {
        return String(t[r])
    }
    // Articolo: numero iniziale (con eventuale suffisso «-bis»).
    let num = try! NSRegularExpression(pattern: "^(\\d{1,4}(?:[ -][a-z]+)?)")
    if let m = num.firstMatch(in: t, range: NSRange(t.startIndex..<t.endIndex, in: t)),
       let r = Range(m.range(at: 1), in: t) {
        return String(t[r])
    }
    return t
}

/// Etichetta di summary di una voce dell'albero (§ 8.3): «<titolo>, <plurale-figli> da
/// <X> a <Y>, pagine da <P> a <Q>». Il range-figli è omesso se non ci sono figli (foglia);
/// le pagine sono SEMPRE quelle del file (1-based: page_index+1). VoiceOver legge questa
/// stringa per intero quando l'utente swipa sulla voce.
public func quickConsultSummaryLabel(_ node: QuickConsultNode, includePages: Bool = true) -> String {
    var parts = [node.title]
    if let first = node.children.first, let last = node.children.last {
        let unit = childUnitPluralName(first.role)
        let lo = quickConsultOrdinal(first.title)
        let hi = quickConsultOrdinal(last.title)
        parts.append(lo == hi ? "\(unit) \(lo)" : "\(unit) da \(lo) a \(hi)")
    }
    if includePages {
        let p = node.firstPage + 1, q = node.lastPage + 1
        parts.append(p == q ? "pagina \(p)" : "pagine da \(p) a \(q)")
    }
    return parts.joined(separator: ", ")
}
