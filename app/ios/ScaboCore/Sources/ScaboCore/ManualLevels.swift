//
//  ManualLevels.swift
//  ScaboCore
//
//  Livelli dei titoli nei manuali (INBOX D.10, giro finale della ripulizia mobile, 2026-10-08; decisione del
//  manutentore: sì all'unione di etichetta e titolo, con il livello relativo giusto nella gerarchia).
//
//  ── Il difetto ───────────────────────────────────────────────────────────────────────────────────
//
//  Il livello di un titolo numerato si fissava all'emissione guardando i nodi già emessi, mentre le etichette in
//  maiuscoletto («CAPITOLO I», «Sezione prima») diventavano titolo solo dopo (famiglie pulite) e il titolo del
//  capitolo che le segue prendeva un livello per taglia. L'unità «etichetta + titolo» occupava così due livelli, il
//  paragrafo scendeva al quarto e il sotto-paragrafo restava al quarto per il tetto: livelli schiacciati, fratelli
//  sbagliati nella Consultazione Rapida e nel rotore. Verità: l'indice stampato di ciascun manuale.
//
//  ── La cura, in due parti ──────────────────────────────────────────────────────────────────────────
//
//  Parte 1 — `fuseStructureUnits`, dentro `pageItems` (in coda alla fusione dei titoli spezzati): l'etichetta sola
//  (parola-chiave + ordinale) e il titolo che la segue sulla stessa pagina — centrato sull'etichetta, oppure tutto
//  maiuscolo, oppure allineato a bandiera sotto di lei, mai numerato — diventano UN titolo. Se dopo l'etichetta
//  viene il corpo, le sue prime righe maiuscole e centrate sono il titolo (titolo «perso» in testa al corpo). Sta in
//  `pageItems` perché l'aggancio delle note accoppia per pagina, uno a uno, i nodi con gli item: togliere un nodo
//  dopo sfaserebbe l'accoppiamento. Lettere e ordine invariati: si uniscono item adiacenti.
//
//  Parte 2 — `normalizeManualLevels`, in `assembleDocument`, in posizione (nessun nodo aggiunto o tolto):
//  1. ogni classe d'unità (PARTE/LIBRO/TITOLO, CAPITOLO/CAPO, SEZIONE) prende nel volume il livello più frequente
//     fra min(livello della parola-chiave, livello attuale), in ordine stretto PARTE < CAPITOLO < SEZIONE; il titolo
//     solo su una pagina divisoria seguito da un'unità è della classe PARTE;
//  2. i titoli numerati (già intestazioni, livello ≥ 2) si ricalcolano con la pila delle intestazioni aperte: il
//     primo sotto un titolo non numerato va un livello sotto (relativo), i fratelli restano fratelli, il sotto-
//     paragrafo va sotto il paragrafo; un frammento di titolo spezzato resta al livello del suo titolo;
//  3. se dalla prima unità in poi nessuna intestazione sta al primo livello, tutti i livelli salgono (compattazione);
//  4. tetto a quattro livelli (schema). Il quinto livello vero è raro nel corpus: decisione del manutentore, schema
//     invariato (misura in `docs/TITOLI_MONOTIPOGRAFICI.md`).
//
//  Gate: non nei codici, nella DPC, nei documenti monotipografici, nell'Estratto (struttura blindata dalla sua
//  foglia), né nei DeJure (la parte 2 si chiama solo dove il chiamante lo decide).
//

import Foundation

/// Ordinali in lettere: i primi dieci, «unico», e i composti in «-esimo/-esima» («undicesimo», «ventiquattresimo»…).
private let MANUAL_ORDINAL_WORDS = "primo|prima|secondo|seconda|terzo|terza|quarto|quarta|quinto|quinta|sesto|sesta|settimo|"
    + "settima|ottavo|ottava|nono|nona|decimo|decima|unico|unica|[a-zà-ù]{2,}esim[oa]"
private let MANUAL_KEYWORD = "((?i:parte|libro|titolo|capitolo|capo|sezione|sez\\.))"
/// Ordinale: numerale romano MAIUSCOLO da 1 a 99 che occupa tutta la parola (anche -bis/-ter), cifre, o ordinale in
/// lettere. Il romano maiuscolo e limitato esclude le parole che ne hanno le lettere: «di», «DI», «mi», «ci» (un «Titolo
/// di …» non è un'etichetta).
private let MANUAL_ORDINAL = "((?=[IVXL]+\\b)(?:XC|XL|L?X{0,3})(?:IX|IV|V?I{0,3})(?:-(?i:bis|ter))?|\\d+|(?i:\(MANUAL_ORDINAL_WORDS)))"
/// Etichetta sola: parola-chiave + ordinale («CAPITOLO I», «Sezione prima», «PARTE II.»).
private let UNIT_LABEL_RE = try! NSRegularExpression(
    pattern: "^\(MANUAL_KEYWORD)\\s+\(MANUAL_ORDINAL)\\.?$")
/// «Parte generale/speciale».
private let UNIT_LABEL_GS_RE = try! NSRegularExpression(
    pattern: "^(parte|libro)\\s+(generale|speciale)\\.?$", options: [.caseInsensitive])
/// «Sezione A» (lettera maiuscola).
private let UNIT_LABEL_LETTER_RE = try! NSRegularExpression(pattern: "^((?i:sezione|sez\\.))\\s+([A-Z])\\.?$")
/// Unità già in un nodo: parola-chiave + ordinale (o lettera) + titolo («Sezione prima – TITOLO», «SEZ. I: …»).
private let UNIT_LABEL_TITLE_RE = try! NSRegularExpression(
    pattern: "^\(MANUAL_KEYWORD)\\s+(?:\(MANUAL_ORDINAL)|[A-Z](?=\\s))\\b\\s*[.:–—-]?\\s*\\S")
/// Titolo numerato in senso stretto (numero, punto, iniziale maiuscola o virgolette) — per il confine del front-matter.
private let MANUAL_NUMBERED_STRICT_RE = try! NSRegularExpression(
    pattern: "^\\s*(?:§\\s*)?(\\d{1,3}(?:\\.\\d{1,2})*)\\.\\s+[A-ZÀ-Ý«“\"‘'(]")
/// Titolo numerato in senso largo: solo su nodi che sono già intestazioni.
private let MANUAL_NUMBERED_ANY_RE = try! NSRegularExpression(pattern: "^\\s*(?:§\\s*)?(\\d{1,3}(?:\\.\\d{1,2})*)\\.\\s+\\S")
/// «§ N.» in grassetto (Torrente), anche «-bis/-ter».
private let MANUAL_BOLD_PARAGRAPH_RE = try! NSRegularExpression(
    pattern: "^\\s*§\\s*\\d{1,4}(?:\\s?[-–]\\s?(?:bis|ter|quater|quinquies|sexies|septies|octies|novies|decies))?\\.\\s+\\S")
/// Voce d'enumerazione: «A) …», «IV. …», «3) …».
private let MANUAL_ENUM_RE = try! NSRegularExpression(pattern: "^\\s*(?:[A-Z]\\)|[IVXLC]+\\.|\\d+[.)])\\s")

private func manualMatch(_ re: NSRegularExpression, _ text: String) -> NSTextCheckingResult? {
    re.firstMatch(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text))
}

/// Livello della parola-chiave: PARTE/LIBRO/TITOLO 1, CAPITOLO/CAPO 2, SEZIONE 3.
func manualKeywordLevel(_ keyword: String) -> Int {
    let k = keyword.lowercased()
    if k == "parte" || k == "libro" || k == "titolo" { return 1 }
    if k.hasPrefix("sez") { return 3 }
    return 2
}

/// La parola-chiave di un'etichetta sola, o nil.
func manualUnitLabelKeyword(_ text: String) -> String? {
    let t = jsTrim(text)
    for re in [UNIT_LABEL_RE, UNIT_LABEL_GS_RE, UNIT_LABEL_LETTER_RE] {
        if let m = manualMatch(re, t), let r = Range(m.range(at: 1), in: t) { return String(t[r]) }
    }
    return nil
}

/// Profondità di un titolo numerato in senso stretto (nil se non numerato).
func manualNumberedDepthStrict(_ text: String) -> Int? {
    let t = jsTrim(text)
    if manualMatch(MANUAL_BOLD_PARAGRAPH_RE, t) != nil { return 1 }
    guard let m = manualMatch(MANUAL_NUMBERED_STRICT_RE, t), let r = Range(m.range(at: 1), in: t) else { return nil }
    return t[r].split(separator: ".").count
}

/// Profondità di un titolo numerato in senso largo (solo per nodi che sono già intestazioni).
func manualNumberedDepthAny(_ text: String) -> Int? {
    let t = jsTrim(text)
    if manualMatch(MANUAL_BOLD_PARAGRAPH_RE, t) != nil { return 1 }
    guard let m = manualMatch(MANUAL_NUMBERED_ANY_RE, t), let r = Range(m.range(at: 1), in: t) else { return nil }
    return t[r].split(separator: ".").count
}

/// Unità già in un nodo: parola-chiave + ordinale (o lettera) + titolo, non numerata, al più 160 caratteri.
func isUnitWithTitle(_ text: String) -> Bool {
    let t = jsTrim(text)
    return t.utf16.count <= 160 && manualNumberedDepthAny(t) == nil && manualUnitLabelKeyword(t) == nil
        && manualMatch(UNIT_LABEL_TITLE_RE, t) != nil
}

private func manualCapsRatio(_ text: String) -> Double {
    var letters = 0, upper = 0
    for ch in text where ch.isLetter {
        letters += 1
        if ch.isUppercase { upper += 1 }
    }
    return letters > 0 ? Double(upper) / Double(letters) : 0
}

private func manualMidX(_ lines: [LineSummary]) -> Double {
    let x0 = lines.map { $0.x0 }.min() ?? 0
    let x1 = lines.map { $0.x1 }.max() ?? 0
    return (x0 + x1) / 2
}

// MARK: - Parte 1: fusione dell'unità (dentro pageItems)

/// Fonde l'etichetta sola e il titolo che la segue sulla stessa pagina in un titolo unico (vedi la testata).
func fuseStructureUnits(_ items: [GenItem], pageWidth: Double, _ profile: Profile) -> [GenItem] {
    guard !profile.isCodici, !profile.isRivistaDpc, profile.mono == nil, !profile.isEstrattoChrome else { return items }
    let tolerance = max(8.0, 0.03 * pageWidth)
    var out: [GenItem] = []
    var i = 0
    while i < items.count {
        // L'etichetta: un titolo, o un run di corpo o di nota, fatto SOLO di parola-chiave + ordinale.
        // Unità già in un titolo («Sezione B Titolo …») che va a capo in un secondo titolo dello stesso livello che
        // riparte in minuscola: si uniscono (al più due continuazioni).
        if case let .heading(sm, level) = items[i], isUnitWithTitle(sm.text) {
            var parts = [sm]
            var j = i + 1
            while j < items.count, j <= i + 2, case let .heading(next, nextLevel) = items[j], nextLevel == level,
                  jsTrim(next.text).first?.isLowercase == true {
                parts.append(next); j += 1
            }
            out.append(parts.count > 1 ? .heading(mergedLine(parts), level: level) : items[i])
            i = j
            continue
        }
        var labelLines: [LineSummary] = []
        var labelLevel: Int?
        var keyword: String?
        switch items[i] {
        case .heading(let sm, let level):
            if let k = manualUnitLabelKeyword(sm.text) { labelLines = [sm]; labelLevel = level; keyword = k }
        case .run(let role, let lines) where role == .body || role == .note:
            if let k = manualUnitLabelKeyword(joinLines(lines.map { $0.text })) { labelLines = lines; keyword = k }
        default:
            break
        }
        guard let kw = keyword, !labelLines.isEmpty else { out.append(items[i]); i += 1; continue }
        let labelMid = manualMidX(labelLines)
        let labelFirst = labelLines[0], labelLast = labelLines[labelLines.count - 1]
        var titleLines: [LineSummary] = []
        var titleLevels: [Int] = []
        var remainder: GenItem?
        var j = i + 1
        collect: while j < items.count, titleLevels.count < 3 {
            switch items[j] {
            case .heading(let sm, let level):
                let t = jsTrim(sm.text)
                // mai un titolo numerato, un'altra etichetta, un'unità col suo titolo («Sezione A …») o un'enumerazione
                if manualNumberedDepthStrict(t) != nil || manualUnitLabelKeyword(t) != nil || isUnitWithTitle(t)
                    || manualMatch(MANUAL_ENUM_RE, t) != nil { break collect }
                let centered = abs(manualMidX([sm]) - labelMid) <= tolerance
                let drop = labelLast.yBottom - sm.yBottom
                let aligned = abs(sm.x0 - labelFirst.x0) <= 3 && abs(sm.fontSize - labelFirst.fontSize) <= 0.6
                    && drop > 0 && drop <= 3.0 * labelFirst.fontSize
                guard centered || aligned || manualCapsRatio(t) >= 0.8 else { break collect }
                titleLines.append(sm); titleLevels.append(level); j += 1
            case .run(.body, let lines) where titleLevels.isEmpty:
                // Titolo «perso» in testa al corpo: le prime righe maiuscole e centrate sull'etichetta.
                var head: [LineSummary] = []
                for l in lines {
                    let lt = jsTrim(l.text)
                    if manualMatch(MANUAL_ENUM_RE, lt) != nil { break }
                    guard head.count < 3, manualCapsRatio(lt) >= 0.9, abs(manualMidX([l]) - labelMid) <= tolerance else { break }
                    head.append(l)
                }
                if !head.isEmpty {
                    titleLines = head
                    titleLevels = [labelLevel ?? manualKeywordLevel(kw)]
                    let rest = Array(lines.dropFirst(head.count))
                    if !rest.isEmpty { remainder = .run(.body, rest) }
                    j += 1
                }
                break collect
            default:
                break collect
            }
        }
        guard !titleLines.isEmpty else { out.append(items[i]); i += 1; continue }
        let level = ([manualKeywordLevel(kw)] + titleLevels + (labelLevel.map { [$0] } ?? [])).min()!
        out.append(.heading(mergedLine(labelLines + titleLines), level: level))
        if let r = remainder { out.append(r) }
        i = j
    }
    return out
}

// MARK: - Parte 2: i livelli (in assembleDocument)

private func headingLevel(_ node: NodeDict) -> Int? {
    switch node.type {
    case .HEADING_1: return 1
    case .HEADING_2: return 2
    case .HEADING_3: return 3
    case .HEADING_4: return 4
    default: return nil
    }
}

private func headingType(_ level: Int) -> SemanticCategory {
    switch level {
    case 1: return .HEADING_1
    case 2: return .HEADING_2
    case 3: return .HEADING_3
    default: return .HEADING_4
    }
}

/// Ricalcola in posizione i livelli delle intestazioni di un manuale (vedi la testata). Ritorna quante intestazioni
/// hanno cambiato livello.
@discardableResult
func normalizeManualLevels(_ nodes: inout [NodeDict]) -> Int {
    let headingIdx = nodes.indices.filter { headingLevel(nodes[$0]) != nil }
    guard !headingIdx.isEmpty else { return 0 }
    var level: [Int: Int] = [:]
    for i in headingIdx { level[i] = headingLevel(nodes[i])! }

    // 1. Unità e loro classe; livello per classe nel volume.
    var unitClass: [Int: Int] = [:]
    var candidates: [Int: [Int]] = [:]
    for i in headingIdx {
        let t = jsTrim(nodes[i].text ?? "")
        guard t.utf16.count <= 160, manualNumberedDepthAny(t) == nil else { continue }
        var kw = manualUnitLabelKeyword(t)
        if kw == nil, let m = manualMatch(UNIT_LABEL_TITLE_RE, t), let r = Range(m.range(at: 1), in: t) { kw = String(t[r]) }
        guard let k = kw else { continue }
        let cls = manualKeywordLevel(k)
        unitClass[i] = cls
        candidates[cls, default: []].append(min(cls, level[i]!))
    }
    // Pagina divisoria: un titolo non numerato che è l'UNICO nodo della sua pagina e a cui segue un'unità è la divisione
    // sopra quell'unità (le Parti di un manuale stampate senza la parola «PARTE», solo col titolo della parte). Sul corpus
    // scatta esattamente sulle 13 Parti di un manuale; prima finivano sotto i capitoli.
    var nodesOnPage: [Int: Int] = [:]
    for n in nodes { nodesOnPage[n.page_index, default: 0] += 1 }
    for (k, i) in headingIdx.enumerated() where unitClass[i] == nil && nodesOnPage[nodes[i].page_index] == 1 {
        let t = jsTrim(nodes[i].text ?? "")
        guard manualNumberedDepthAny(t) == nil, k + 1 < headingIdx.count, unitClass[headingIdx[k + 1]] != nil else { continue }
        unitClass[i] = 1
        candidates[1, default: []].append(1)
    }
    var classLevel: [Int: Int] = [:]
    for (cls, values) in candidates {
        var counts: [Int: Int] = [:]
        for v in values { counts[v, default: 0] += 1 }
        let top = counts.values.max()!
        classLevel[cls] = counts.filter { $0.value == top }.keys.min()!
    }
    var previous = 0
    for cls in classLevel.keys.sorted() {
        classLevel[cls] = max(classLevel[cls]!, previous + 1)
        previous = classLevel[cls]!
    }
    for (i, cls) in unitClass { level[i] = min(4, classLevel[cls]!) }

    // 2. Titoli numerati: pila delle intestazioni aperte, livelli logici senza tetto.
    var logical: [Int: Int] = [:]
    var stack: [(level: Int, depth: Int?, unit: Bool)] = []
    var previousNode: Int?
    for i in nodes.indices {
        guard let current = level[i] else { previousNode = i; continue }
        let t = jsTrim(nodes[i].text ?? "")
        let depth = manualNumberedDepthAny(t)
        if let d = depth, current >= 2 {
            var assigned: Int?
            while let top = stack.last {
                if top.depth == nil {
                    // un titolo non numerato che non è un'unità e non sta sopra il numerato (stesso livello tipografico)
                    // è un suo FRATELLO, non il genitore: è il titolo numerato a cui il lettore di sistema ha staccato il
                    // numero (iOS 26.5, visto in rete). Le unità (CAPITOLO, SEZIONE…) restano sempre genitori.
                    if !top.unit, top.level >= current { assigned = top.level; stack.removeLast(); break }
                    // un'intestazione non numerata più profonda di un numerato aperto che la precede (sottotitolo dentro
                    // il paragrafo) non è genitore del numerato seguente
                    if stack.dropLast().contains(where: { $0.depth != nil && $0.depth! <= d && $0.level < top.level }) {
                        stack.removeLast(); continue
                    }
                    assigned = top.level + 1; break
                }
                if top.depth! > d { stack.removeLast(); continue }
                if top.depth! == d { assigned = top.level; stack.removeLast(); break }
                assigned = top.level + (d - top.depth!); break
            }
            let l = assigned ?? d
            logical[i] = l
            stack.append((l, d, false))
        } else {
            // frammento di un titolo numerato spezzato su due nodi: stesso livello del titolo, non genitore
            if let p = previousNode, let pl = level[p], nodes[p].page_index == nodes[i].page_index,
               manualNumberedDepthAny(nodes[p].text ?? "") != nil, pl == current, unitClass[i] == nil,
               let pLogical = logical[p] {
                logical[i] = pLogical
                previousNode = i
                continue
            }
            logical[i] = current
            while let top = stack.last, top.level >= current { stack.removeLast() }
            stack.append((current, depth, unitClass[i] != nil))
        }
        previousNode = i
    }

    // 3. Compattazione: dalla prima unità o dal primo titolo numerato in poi, se il primo livello resta vuoto.
    let structured = headingIdx.filter { unitClass[$0] != nil || manualNumberedDepthStrict(nodes[$0].text ?? "") != nil }
    // Nessuna unità, nessun numerato: niente struttura da manuale, i livelli tipografici restano com'erano.
    guard !structured.isEmpty else { return 0 }
    let firstBody = structured.map { nodes[$0].page_index }.min() ?? 0
    let after = headingIdx.filter { i in
        nodes[i].page_index >= firstBody && (nodes[i].text ?? "").filter({ $0.isLetter }).count >= 2
    }.compactMap { logical[$0] }
    let shift = (after.min() ?? 1) > 1 ? after.min()! - 1 : 0

    // 4. Tetto a quattro livelli.
    var changed = 0
    for i in headingIdx {
        let l = min(4, max(1, logical[i]! - shift))
        if l != headingLevel(nodes[i])! { changed += 1 }
        nodes[i].type = headingType(l)
        nodes[i].level = l
    }
    return changed
}
