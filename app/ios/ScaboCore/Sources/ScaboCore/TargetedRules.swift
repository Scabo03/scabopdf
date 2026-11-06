//
//  TargetedRules.swift
//  ScaboCore
//
//  LE REGOLE DELLE CURE MIRATE (LAYER2_PRODUCT_DECISIONS § 0-ter, registro in TargetedCures.swift, metodo in
//  docs/CURE_MIRATE.md; giro «cure mirate per lo studio», 2026-11-06).
//
//  Si eseguono SOLO dove il profilo porta regole mirate (`profile.targeted`: l'impronta del file nel registro):
//  `pageItems` chiama `applyTargetedPageRules` e `assembleDocument` chiama `applyTargetedDocumentRules` solo in quel caso.
//  I due smistatori chiamano una regola solo se il suo caso è nell'insieme: un documento del registro esegue soltanto le
//  regole della sua voce. Le regole sono `private`: fuori da questo file si raggiungono solo attraverso i due smistatori.
//  Attenzione (revisione indipendente del giro): le regole di pagina vivono in `pageItems`, che usano anche i rami appunti
//  e Cortina, mentre quelle di documento solo nel Generic. I documenti registrati vanno al Generic (verificato, e
//  ricontrollato dalla rete di ogni giro, `docs/CURE_MIRATE.md` § 5): se un giorno finissero in un altro ramo, la voce va
//  rivista.
//
//  Le regole di PAGINA lavorano sugli item della pagina, come le foglie del tronco: la costruzione del documento e
//  l'aggancio delle note (`bindAndPlaceNotes`, che rideriva gli item della pagina e li accoppia uno a uno ai nodi) vedono
//  così la stessa scomposizione. Le regole di DOCUMENTO sono rietichettature in posizione (nessun nodo aggiunto o tolto:
//  l'accoppiamento per pagina resta esatto). Nessuna regola scrive testo: spezzano un blocco di corpo dove comincia un
//  titolo, uniscono righe adiacenti in un titolo o in un sommario, rimettono in ordine di posizione le righe di un sommario
//  che il lettore di sistema emette fuori posto, tolgono da un'etichetta i glifi d'ornamento dell'area d'uso privato (non
//  sono lettere né cifre) e fissano il livello di un titolo. Lettere e cifre del documento restano le stesse.
//
//  Si esprimono con tipografia (taglia rispetto al corpo, grassetto, corsivo), geometria (bordo sinistro della colonna,
//  rientro, stacco verticale, posizione verticale) e forme generali (numerazione «N.», parola-chiave di struttura + numero
//  romano, righe tutte maiuscole, elenco «– N.» di un sommario). Nessuna parola, titolo o frase dei libri.
//

import Foundation

// MARK: - Ingressi

/// Applica, in ordine, le regole mirate di PAGINA accese nel profilo. Chiamata SOLO quando `profile.targeted` non è vuoto.
func applyTargetedPageRules(_ items: [GenItem], _ profile: Profile) -> [GenItem] {
    var out = items
    if profile.targeted.contains(.boldBodySizeTitles) {
        out = targetedBoldBodySizeTitles(out, profile)
    }
    if profile.targeted.contains(.chapterSummaryAfterChapterTitle) {
        out = targetedChapterSummaryAfterChapterTitle(out)
    }
    if profile.targeted.contains(.ornamentedStructureLabels) {
        out = targetedOrnamentedStructureLabels(out)
    }
    if profile.targeted.contains(.labelledChapterSummary) {
        out = targetedLabelledChapterSummary(out)
    }
    if profile.targeted.contains(.sectionLabels) {
        out = targetedSectionLabels(out, profile)
    }
    if profile.targeted.contains(.smallerNumberedParagraphTitles) {
        out = targetedSmallerNumberedParagraphTitles(out, profile)
    }
    return out
}

/// Applica, in posizione, le regole mirate di DOCUMENTO accese nel profilo. Chiamata SOLO quando `profile.targeted` non è
/// vuoto, dopo i livelli dei manuali (`normalizeManualLevels`). Ritorna quanti nodi ha toccato.
@discardableResult
func applyTargetedDocumentRules(_ nodes: inout [NodeDict], _ profile: Profile) -> Int {
    var touched = 0
    if profile.targeted.contains(.boldBodySizeTitles) || profile.targeted.contains(.smallerNumberedParagraphTitles) {
        touched += targetedFlatParagraphLevels(&nodes)
    }
    if profile.targeted.contains(.labelledChapterSummary) {
        touched += targetedChapterSummaryContinuation(&nodes)
    }
    return touched
}

/// Il bordo sinistro della colonna del corpo su tutto il documento: il bordo sinistro più frequente (al mezzo punto) delle
/// righe alla taglia del corpo larghe più di metà pagina. Calcolato solo per i documenti con regole mirate.
func targetedBodyLeftEdge(_ extraction: PdfExtraction, body: Double) -> Double {
    guard body > 0 else { return 0 }
    var counts: [Double: Int] = [:]
    for page in extraction.pages {
        for line in page.lines {
            let sm = summarizeLine(line)
            guard abs(sm.fontSize - body) <= 0.3, sm.width > page.width * 0.5 else { continue }
            counts[(sm.x0 * 2).rounded() / 2, default: 0] += 1
        }
    }
    return counts.max { $0.value < $1.value || ($0.value == $1.value && $0.key > $1.key) }?.key ?? 0
}

// MARK: - Forme generali

/// Etichetta di capitolo o di parte: parola-chiave di struttura + numero romano, da sola sulla riga.
private let TARGETED_UNIT_LABEL_RE = try! NSRegularExpression(
    pattern: "^(?i:(capitolo|parte))\\s+[IVXLCDM]{1,6}\\.?$")
/// Etichetta di sezione: parola-chiave + numero romano, da sola sulla riga.
private let TARGETED_SECTION_LABEL_RE = try! NSRegularExpression(pattern: "^(?i:sezione)\\s+[IVXLCDM]{1,6}\\.?$")
/// Etichetta del sommario di capitolo, da sola sulla riga.
private let TARGETED_SUMMARY_LABEL_RE = try! NSRegularExpression(pattern: "^(?i:sommario)\\s*[.:]?$")
/// Un titolo di paragrafo numerato comincia con un numero (fino a tre cifre) seguito dal punto, da uno spazio o da un
/// trattino.
private let TARGETED_NUMBER_OPENING_RE = try! NSRegularExpression(pattern: "^\\d{1,3}(?:\\.|\\s|-)")
/// Etichetta d'unità che apre un'intestazione già fusa col suo titolo: parte, capitolo o sezione + romano.
private let TARGETED_ANY_UNIT_LABEL_RE = try! NSRegularExpression(
    pattern: "^(?i:(capitolo|parte|sezione))\\s+[IVXLCDM]{1,6}\\.?$")
/// Titolo di paragrafo numerato «N. …» (fino a tre cifre, eventualmente «bis»/«ter»…, punto, spazio, testo).
private let TARGETED_NUMBERED_TITLE_RE = try! NSRegularExpression(
    pattern: "^\\d{1,3}(?:[ -]?(?:bis|ter|quater|quinquies|sexies))?\\.\\s+\\S")
/// Apertura di un sommario in prosa: «1» seguito dal punto o da una lineetta, poi testo.
private let TARGETED_SUMMARY_OPENING_RE = try! NSRegularExpression(pattern: "^\\s*1\\s*[.\u{2013}\u{2014}-]\\s*\\S")
/// Voce successiva di un sommario: dopo una lineetta o un punto, «N.» seguito da testo.
private let TARGETED_SUMMARY_ITEM_RE = try! NSRegularExpression(pattern: "(?:[\u{2013}\u{2014}-]|\\.)\\s+\\d{1,3}\\.\\s+\\S")

private func targetedMatches(_ re: NSRegularExpression, _ text: String) -> Bool {
    re.firstMatch(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text)) != nil
}

private func targetedMatchCount(_ re: NSRegularExpression, _ text: String) -> Int {
    re.numberOfMatches(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text))
}

/// Tutti gli span con lettere sono in grassetto (e ce n'è almeno uno).
private func targetedLettersAllBold(_ sm: LineSummary) -> Bool {
    let letterSpans = sm.spans.filter { $0.text.contains { $0.isLetter } }
    return !letterSpans.isEmpty && letterSpans.allSatisfy { $0.bold }
}

/// Il testo senza i caratteri dell'area d'uso privato (glifi d'ornamento di un carattere decorativo), ripulito ai bordi.
func targetedStrippingPrivateUseOrnaments(_ text: String) -> String {
    let kept = text.unicodeScalars.filter { !(0xE000...0xF8FF).contains($0.value) }
    return jsTrim(String(String.UnicodeScalarView(kept)))
}

/// Vero se la riga ha lettere e sono (quasi) tutte maiuscole.
private func targetedIsUppercaseLine(_ text: String) -> Bool {
    capsRatioCortina(text) >= 0.9 && text.contains { $0.isLetter }
}

/// Stacco verticale fra due righe consecutive della stessa pagina (origine in basso: `yBottom` della prima, `yTop` della
/// seconda) maggiore di mezza riga: una riga vuota dell'impaginato, non l'interlinea.
private func targetedGapBetween(_ upper: LineSummary, _ lower: LineSummary) -> Bool {
    upper.yBottom - lower.yTop > max(upper.height, lower.height) * 0.5
}

/// Livello di un nodo intestazione, o nil.
private func targetedHeadingLevel(_ node: NodeDict) -> Int? {
    switch node.type {
    case .HEADING_1: return 1
    case .HEADING_2: return 2
    case .HEADING_3: return 3
    case .HEADING_4: return 4
    default: return nil
    }
}

private func targetedHeadingCategory(_ level: Int) -> SemanticCategory {
    switch level {
    case 1: return .HEADING_1
    case 2: return .HEADING_2
    case 3: return .HEADING_3
    default: return .HEADING_4
    }
}

/// Spezza i run di corpo dove `group` riconosce l'inizio di un gruppo di righe da sostituire (fine del gruppo e item
/// sostitutivi), lasciando il resto al corpo. Righe e ordine invariati. `previous` è l'item che precede la riga di partenza
/// (il corpo accumulato, o l'ultimo item già emesso).
private func targetedSplitBodyRuns(
    _ items: [GenItem],
    group: (_ lines: [LineSummary], _ start: Int, _ previous: GenItem?) -> (end: Int, items: [GenItem])?
) -> [GenItem] {
    var out: [GenItem] = []
    for item in items {
        guard case .run(.body, let lines) = item else { out.append(item); continue }
        var buf: [LineSummary] = []
        var i = 0
        while i < lines.count {
            let previous: GenItem? = buf.isEmpty ? out.last : .run(.body, buf)
            if let g = group(lines, i, previous), g.end > i {
                if !buf.isEmpty { out.append(.run(.body, buf)); buf = [] }
                out.append(contentsOf: g.items)
                i = g.end
            } else {
                buf.append(lines[i]); i += 1
            }
        }
        if !buf.isEmpty { out.append(.run(.body, buf)) }
    }
    return out
}

// MARK: - Studio A — titoli in grassetto alla taglia del corpo

/// Riga di titolo dello studio A: tutte le lettere in grassetto, alla taglia del corpo (±0,6 pt).
private func targetedIsBoldBodySizeLine(_ sm: LineSummary, body: Double) -> Bool {
    abs(sm.fontSize - body) <= 0.6 && targetedLettersAllBold(sm) && sm.text.contains { $0.isLetter }
}

/// Le righe in grassetto a taglia di corpo, consecutive dentro un blocco di corpo, sono titoli: l'etichetta di capitolo
/// (parola-chiave + romano) assorbe le righe successive che non aprono un numero (il titolo del capitolo) e diventa
/// un'intestazione di capitolo; ogni riga che apre con un numero apre un titolo di paragrafo, e le righe che seguono senza
/// numero sono la sua continuazione. Un gruppo che non apre né con l'etichetta né con un numero resta un titolo a sé.
private func targetedBoldBodySizeTitles(_ items: [GenItem], _ profile: Profile) -> [GenItem] {
    guard profile.bodySize > 0 else { return items }
    let body = profile.bodySize
    return targetedSplitBodyRuns(items) { lines, start, _ in
        guard targetedIsBoldBodySizeLine(lines[start], body: body) else { return nil }
        var end = start
        while end < lines.count, targetedIsBoldBodySizeLine(lines[end], body: body) { end += 1 }
        var units: [(lines: [LineSummary], numbered: Bool)] = []
        for sm in lines[start..<end] {
            let t = jsTrim(sm.text)
            if targetedMatches(TARGETED_UNIT_LABEL_RE, t) {
                units.append(([sm], false))
            } else if targetedMatches(TARGETED_NUMBER_OPENING_RE, t) {
                units.append(([sm], true))
            } else if units.isEmpty {
                units.append(([sm], false))
            } else {
                units[units.count - 1].lines.append(sm)
            }
        }
        let made: [GenItem] = units.map { u in
            let merged = mergedLine(u.lines)
            return u.numbered ? .numberedTitle(merged, depth: 1) : .heading(merged, level: 2)
        }
        return (end, made)
    }
}

/// Vero se il testo di un'intestazione apre con l'etichetta di capitolo o di parte (parola-chiave + romano).
private func targetedOpensWithUnitLabel(_ text: String) -> Bool {
    let words = jsTrim(text).split(separator: " ")
    guard words.count >= 2 else { return false }
    return targetedMatches(TARGETED_UNIT_LABEL_RE, words.prefix(2).joined(separator: " "))
}

/// Il blocco di corpo che segue l'intestazione di capitolo sulla stessa pagina, se ha la forma di un sommario in prosa
/// («1. … – 2. … – 3. …», almeno due voci dopo la prima), è il sommario del capitolo: un'unità sola, letta come tale.
private func targetedChapterSummaryAfterChapterTitle(_ items: [GenItem]) -> [GenItem] {
    var out: [GenItem] = []
    for item in items {
        if case .run(.body, let lines) = item, let last = out.last, case .heading(let h, _) = last,
           targetedOpensWithUnitLabel(h.text) {
            let text = joinLines(lines.map { $0.text })
            if targetedMatches(TARGETED_SUMMARY_OPENING_RE, text), targetedMatchCount(TARGETED_SUMMARY_ITEM_RE, text) >= 2 {
                out.append(.apparatus(.CHAPTER_SUMMARY, lines))
                continue
            }
        }
        out.append(item)
    }
    return out
}

/// Studi A e B, in posizione: i titoli di paragrafo (che aprono con un numero) stanno tutti un livello sotto l'unità che li
/// contiene (capitolo, o sezione dove c'è). Un titolo il cui numero non porta subito il punto (un refuso della stampa, un
/// «N bis.») non deve trascinare più in basso i titoli che lo seguono, come farebbe il calcolo relativo dei manuali, che
/// lo prende per un titolo non numerato.
private func targetedFlatParagraphLevels(_ nodes: inout [NodeDict]) -> Int {
    var chapterLevel: Int?
    var touched = 0
    for i in nodes.indices {
        guard let level = targetedHeadingLevel(nodes[i]) else { continue }
        let text = jsTrim(nodes[i].text ?? "")
        let words = text.split(separator: " ")
        if words.count >= 2, targetedMatches(TARGETED_ANY_UNIT_LABEL_RE, words.prefix(2).joined(separator: " ")) {
            chapterLevel = level
            continue
        }
        guard let chapter = chapterLevel, targetedMatches(TARGETED_NUMBER_OPENING_RE, text) else { continue }
        let want = min(4, chapter + 1)
        if level != want {
            nodes[i].type = targetedHeadingCategory(want)
            nodes[i].level = want
            touched += 1
        }
    }
    return touched
}

// MARK: - Studio B — etichette con ornamenti, sommari etichettati, sezioni, titoli di paragrafo sotto la taglia del corpo

/// L'etichetta di Parte o di Capitolo composta fra due glifi d'ornamento (area d'uso privato), seguita dal suo titolo:
/// un'intestazione sola, senza gli ornamenti, al livello del titolo (lo normalizza poi `normalizeManualLevels` per classe).
private func targetedOrnamentedStructureLabels(_ items: [GenItem]) -> [GenItem] {
    var out: [GenItem] = []
    var i = 0
    while i < items.count {
        if case .heading(let label, _) = items[i], i + 1 < items.count, case .heading(let title, let level) = items[i + 1] {
            let clean = targetedStrippingPrivateUseOrnaments(label.text)
            if clean != jsTrim(label.text), targetedMatches(TARGETED_UNIT_LABEL_RE, clean) {
                var cleaned = label
                cleaned.text = clean
                out.append(.heading(mergedLine([cleaned, title]), level: level))
                i += 2
                continue
            }
        }
        out.append(items[i])
        i += 1
    }
    return out
}

/// L'etichetta del sommario di capitolo, sola in un blocco di corpo, seguita dall'elenco composto alla taglia delle note
/// sulla stessa pagina: un sommario di capitolo solo (etichetta + elenco), non corpo e note. Le righe dell'elenco si
/// rimettono in ordine di posizione (dall'alto in basso): il lettore di sistema può emetterne una fuori posto.
private func targetedLabelledChapterSummary(_ items: [GenItem]) -> [GenItem] {
    var out: [GenItem] = []
    var i = 0
    while i < items.count {
        if case .run(.body, let labelLines) = items[i], labelLines.count == 1,
           targetedMatches(TARGETED_SUMMARY_LABEL_RE, jsTrim(labelLines[0].text)),
           i + 1 < items.count, case .run(.note, let list) = items[i + 1] {
            let ordered = list.enumerated().sorted {
                $0.element.yTop != $1.element.yTop ? $0.element.yTop > $1.element.yTop : $0.offset < $1.offset
            }.map { $0.element }
            out.append(.apparatus(.CHAPTER_SUMMARY, labelLines + ordered))
            i += 2
            continue
        }
        out.append(items[i])
        i += 1
    }
    return out
}

/// Studio B, in posizione: il primo blocco di una pagina composto alla taglia delle note che continua l'elenco del
/// sommario rimasto aperto in fondo alla pagina precedente («… – N. …», almeno due voci) è ancora il sommario.
private func targetedChapterSummaryContinuation(_ nodes: inout [NodeDict]) -> Int {
    var touched = 0
    for i in nodes.indices where i > 0 && nodes[i].type == .NOTE {
        let prev = nodes[i - 1]
        guard prev.type == .CHAPTER_SUMMARY, nodes[i].page_index == prev.page_index + 1 else { continue }
        let text = nodes[i].text ?? ""
        let prevText = jsTrim(prev.text ?? "")
        // Il sommario precedente è rimasto aperto: non chiude con la voce finale col punto.
        guard !prevText.hasSuffix("."), targetedMatchCount(TARGETED_SUMMARY_ITEM_RE, text) >= 2 else { continue }
        nodes[i].type = .CHAPTER_SUMMARY
        nodes[i].length_category = nil
        touched += 1
    }
    return touched
}

/// L'etichetta di sezione (parola-chiave + romano) alla taglia del corpo, al bordo sinistro della colonna, seguita da una a
/// tre righe tutte maiuscole alla stessa taglia (il titolo della sezione): un'intestazione di sezione.
private func targetedSectionLabels(_ items: [GenItem], _ profile: Profile) -> [GenItem] {
    guard profile.bodySize > 0, profile.targetedLeftEdge > 0 else { return items }
    let body = profile.bodySize, left = profile.targetedLeftEdge
    func atLeftEdge(_ sm: LineSummary) -> Bool { abs(sm.x0 - left) <= 3 }
    func bodySized(_ sm: LineSummary) -> Bool { abs(sm.fontSize - body) <= 0.6 && !sm.bold }
    return targetedSplitBodyRuns(items) { lines, start, _ in
        let label = lines[start]
        guard bodySized(label), atLeftEdge(label),
              targetedMatches(TARGETED_SECTION_LABEL_RE, jsTrim(label.text)) else { return nil }
        var end = start + 1
        while end < lines.count, end - start <= 3, bodySized(lines[end]), atLeftEdge(lines[end]),
              targetedIsUppercaseLine(jsTrim(lines[end].text)) {
            end += 1
        }
        guard end > start + 1 else { return nil }
        return (end, [.heading(mergedLine(Array(lines[start..<end])), level: 3)])
    }
}

/// Il titolo di paragrafo numerato composto in un carattere più piccolo del corpo (≈ 0,9 del corpo: fra corpo − 1,3 e
/// corpo − 0,7 pt), non in grassetto né in corsivo, al bordo sinistro della colonna, staccato dalla riga di sopra e da
/// quella di sotto; le sue righe di continuazione (fino a due) sono alla stessa taglia e rientrate rispetto al numero.
private func targetedSmallerNumberedParagraphTitles(_ items: [GenItem], _ profile: Profile) -> [GenItem] {
    guard profile.bodySize > 0, profile.targetedLeftEdge > 0 else { return items }
    let body = profile.bodySize, left = profile.targetedLeftEdge
    func titleSized(_ sm: LineSummary) -> Bool {
        sm.fontSize >= body - 1.3 && sm.fontSize <= body - 0.7 && !sm.bold && !sm.italic
    }
    return targetedSplitBodyRuns(items) { lines, start, previous in
        let first = lines[start]
        guard titleSized(first), abs(first.x0 - left) <= 3,
              targetedMatches(TARGETED_NUMBERED_TITLE_RE, jsTrim(first.text)) else { return nil }
        // Staccato dalla riga di sopra: se prima c'è corpo, con uno stacco verticale; se prima c'è altro (un titolo appena
        // riconosciuto, un sommario, una nota) o niente, la riga apre comunque un blocco.
        if case .run(.body, let prevLines)? = previous, let p = prevLines.last {
            guard targetedGapBetween(p, first) else { return nil }
        }
        var end = start + 1
        while end < lines.count, end - start < 3, titleSized(lines[end]), lines[end].x0 >= left + 5,
              !targetedMatches(TARGETED_NUMBERED_TITLE_RE, jsTrim(lines[end].text)),
              !targetedGapBetween(lines[end - 1], lines[end]) {
            end += 1
        }
        // Staccato anche dalla riga di sotto (o in coda al blocco).
        if end < lines.count {
            guard targetedGapBetween(lines[end - 1], lines[end]) else { return nil }
        }
        return (end, [.numberedTitle(mergedLine(Array(lines[start..<end])), depth: 1)])
    }
}
