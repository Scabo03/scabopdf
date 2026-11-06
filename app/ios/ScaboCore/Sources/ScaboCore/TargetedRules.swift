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
    if profile.targeted.contains(.bibliographyLabels) {
        out = targetedBibliographyLabels(out, profile)
    }
    if profile.targeted.contains(.framedAsideBoxes) {
        out = targetedFramedAsideBoxes(out, profile)
    }
    if profile.targeted.contains(.fullSizeNumberContinuesNote) {
        out = targetedFullSizeNumberContinuesNote(out)
    }
    if profile.targeted.contains(.indentedParagraphs) {
        out = targetedIndentedParagraphs(out, profile)
    }
    return out
}

/// Applica, prima della classificazione, le regole mirate sulle RIGHE della pagina (già tolte mobilia e ancore
/// invisibili). Chiamata SOLO quando `profile.targeted` non è vuoto. Righe e testo restano gli stessi: si riattacca a una
/// riga l'interpunzione che il lettore di sistema ne aveva staccato.
func applyTargetedLineRules(_ lines: [LineSummary], _ profile: Profile) -> [LineSummary] {
    guard profile.targeted.contains(.detachedCallPunctuation) else { return lines }
    return targetedReattachCallPunctuation(lines, profile)
}

/// Applica, in posizione, le regole mirate di DOCUMENTO accese nel profilo. Chiamata SOLO quando `profile.targeted` non è
/// vuoto, dopo i livelli dei manuali (`normalizeManualLevels`). Ritorna quanti nodi ha toccato.
@discardableResult
func applyTargetedDocumentRules(_ nodes: inout [NodeDict], _ profile: Profile) -> Int {
    var touched = 0
    if profile.targeted.contains(.smallerNumberedParagraphTitles) {
        touched += flatNumberedParagraphLevels(&nodes)
    }
    if profile.targeted.contains(.bibliographyLabels) {
        touched += targetedBibliographyLevels(&nodes)
        touched += targetedBibliographyContinuation(&nodes)
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

/// Il bordo destro della colonna del corpo su tutto il documento: il bordo destro più frequente (al mezzo punto) delle
/// righe alla taglia del corpo larghe più di metà pagina. Calcolato solo per le regole mirate che lo usano (riquadri).
func targetedBodyRightEdge(_ extraction: PdfExtraction, body: Double) -> Double {
    guard body > 0 else { return 0 }
    var counts: [Double: Int] = [:]
    for page in extraction.pages {
        for line in page.lines {
            let sm = summarizeLine(line)
            guard abs(sm.fontSize - body) <= 0.3, sm.width > page.width * 0.5 else { continue }
            counts[(sm.x1 * 2).rounded() / 2, default: 0] += 1
        }
    }
    return counts.max { $0.value < $1.value || ($0.value == $1.value && $0.key < $1.key) }?.key ?? 0
}

// MARK: - Interpunzione staccata dopo un richiamo (studi A e B)

/// L'interpunzione che segue un richiamo e che il lettore di sistema emette come riga a sé: da uno a tre caratteri, tutti
/// punteggiatura di fine frase o di chiusura, nessuna lettera né cifra.
private let TARGETED_DETACHED_PUNCTUATION: Set<Character> = [".", ",", ";", ":", "!", "?", ")", "]", "»", "\u{201D}", "\u{2019}"]

private func targetedIsPunctuationOnly(_ text: String) -> Bool {
    let t = jsTrim(text)
    return !t.isEmpty && t.count <= 3 && t.allSatisfy { TARGETED_DETACHED_PUNCTUATION.contains($0) }
}

/// Vero se l'ultimo span con testo della riga è un richiamo in apice: sole cifre (al più tre-quattro), composte più
/// piccole (≤ 0,8) del testo più grande della riga.
private func targetedEndsWithSuperscriptCall(_ spans: [PdfSpan]) -> Bool {
    let withText = spans.filter { !jsTrim($0.text).isEmpty }
    guard let last = withText.last, withText.count >= 2 else { return false }
    let digits = jsTrim(last.text)
    guard !digits.isEmpty, digits.count <= 4, digits.allSatisfy({ $0.isASCII && $0.isNumber }) else { return false }
    let biggest = withText.map { $0.fontSize }.max() ?? 0
    return biggest > 0 && last.fontSize <= biggest * 0.8
}

/// Vero se la riga `index` della pagina è interpunzione staccata dopo un richiamo in apice: una delle tre righe che la
/// precedono nell'ordine del lettore di sistema finisce con un richiamo in apice, sta sulla stessa linea di base (±1,5 pt)
/// e finisce dove l'interpunzione comincia (±2 pt).
func targetedIsDetachedCallPunctuation(_ index: Int, in lines: [PdfTextLine]) -> Bool {
    guard index > 0, index < lines.count else { return false }
    let line = lines[index]
    guard targetedIsPunctuationOnly(line.spans.map { $0.text }.joined()) else { return false }
    for k in stride(from: index - 1, through: max(0, index - 3), by: -1) {
        let prev = lines[k]
        guard targetedEndsWithSuperscriptCall(prev.spans) else { continue }
        if abs(prev.bbox.y - line.bbox.y) <= 1.5, abs(prev.bbox.x + prev.bbox.width - line.bbox.x) <= 2 { return true }
    }
    return false
}

/// Vero se il testo comincia con un segno d'interpunzione di fine frase o di chiusura seguito da uno spazio (o è solo
/// quello): il resto della stessa riga fisica, che il lettore di sistema ha separato dal richiamo in apice («. Ne derivano…»).
private func targetedStartsWithDetachedPunctuation(_ text: String) -> Bool {
    let t = jsTrim(text)
    guard let first = t.first, TARGETED_DETACHED_PUNCTUATION.contains(first) else { return false }
    let rest = t.dropFirst()
    return rest.isEmpty || rest.first == " " || targetedIsPunctuationOnly(t)
}

/// Riattacca l'interpunzione staccata alla riga che finisce col richiamo (stessa linea di base, contigua), senza spazio:
/// «parola¹⁴» + «.» → «parola¹⁴.». Vale anche quando la riga staccata porta, dopo l'interpunzione, il resto della stessa
/// riga fisica («parola¹⁴» + «. Ne derivano…» → «parola¹⁴. Ne derivano…»). E una riga di corpo spezzata che finisce con un
/// richiamo in apice prende la taglia del suo testo (la media col richiamo la faceva sembrare una nota). Testo invariato
/// salvo lo spazio che non c'è sulla pagina.
private func targetedReattachCallPunctuation(_ lines: [LineSummary], _ profile: Profile) -> [LineSummary] {
    var out: [LineSummary] = []
    for sm in lines {
        if targetedStartsWithDetachedPunctuation(sm.text), let prev = out.last, targetedEndsWithSuperscriptCall(prev.spans),
           abs(prev.yBottom - sm.yBottom) <= 1.5, abs(prev.x1 - sm.x0) <= 2 {
            out[out.count - 1] = LineSummary(
                text: prev.text + jsTrim(sm.text), fontSize: prev.fontSize, bold: prev.bold, italic: prev.italic,
                color: prev.color, x0: prev.x0, x1: max(prev.x1, sm.x1), yTop: prev.yTop, yBottom: prev.yBottom,
                width: max(prev.x1, sm.x1) - prev.x0, height: prev.height, spans: prev.spans + sm.spans)
            continue
        }
        out.append(targetedBodyLineWithCallSize(sm, profile))
    }
    return out
}

/// La riga di corpo spezzata che comincia alla taglia del corpo e finisce con un richiamo in apice: la sua taglia è
/// quella del testo senza il richiamo (con pochi caratteri di corpo, la media col richiamo scendeva sotto la soglia delle
/// note). Ogni altra riga resta com'è.
private func targetedBodyLineWithCallSize(_ sm: LineSummary, _ profile: Profile) -> LineSummary {
    let body = profile.bodySize
    guard body > 0, sm.fontSize < body * 0.85 else { return sm }
    let withText = sm.spans.filter { !jsTrim($0.text).isEmpty }
    guard let first = withText.first, abs(first.fontSize - body) <= 0.6 else { return sm }
    var callStart = withText.count
    while callStart > 0 {
        let s = withText[callStart - 1]
        let t = jsTrim(s.text)
        guard s.fontSize <= body * 0.8, !t.isEmpty,
              t.allSatisfy({ ($0.isASCII && $0.isNumber) || TARGETED_DETACHED_PUNCTUATION.contains($0) }) else { break }
        callStart -= 1
    }
    guard callStart > 0, callStart < withText.count else { return sm }
    let text = withText[..<callStart]
    let chars = text.reduce(0) { $0 + $1.text.utf16.count }
    guard chars > 0 else { return sm }
    let size = text.reduce(0.0) { $0 + $1.fontSize * Double($1.text.utf16.count) } / Double(chars)
    return LineSummary(text: sm.text, fontSize: size, bold: sm.bold, italic: sm.italic, color: sm.color, x0: sm.x0,
                       x1: sm.x1, yTop: sm.yTop, yBottom: sm.yBottom, width: sm.width, height: sm.height, spans: sm.spans)
}

// MARK: - Forme generali

/// Etichetta di capitolo o di parte: parola-chiave di struttura + numero romano, da sola sulla riga.
let TARGETED_UNIT_LABEL_RE = try! NSRegularExpression(
    pattern: "^(?i:(capitolo|parte))\\s+[IVXLCDM]{1,6}\\.?$")
/// Etichetta di sezione: parola-chiave + numero romano, da sola sulla riga.
private let TARGETED_SECTION_LABEL_RE = try! NSRegularExpression(pattern: "^(?i:sezione)\\s+[IVXLCDM]{1,6}\\.?$")
/// Etichetta del sommario di capitolo, da sola sulla riga.
private let TARGETED_SUMMARY_LABEL_RE = try! NSRegularExpression(pattern: "^(?i:sommario)\\s*[.:]?$")
/// Un titolo di paragrafo numerato comincia con un numero (fino a tre cifre) seguito dal punto, da uno spazio o da un
/// trattino.
let TARGETED_NUMBER_OPENING_RE = try! NSRegularExpression(pattern: "^\\d{1,3}(?:\\.|\\s|-)")
/// Etichetta d'unità che apre un'intestazione già fusa col suo titolo: parte, capitolo o sezione + romano.
let TARGETED_ANY_UNIT_LABEL_RE = try! NSRegularExpression(
    pattern: "^(?i:(capitolo|parte|sezione))\\s+[IVXLCDM]{1,6}\\.?$")
/// Titolo di paragrafo numerato «N. …» (fino a tre cifre, eventualmente «bis»/«ter»…, punto, spazio, testo).
private let TARGETED_NUMBERED_TITLE_RE = try! NSRegularExpression(
    pattern: "^\\d{1,3}(?:[ -]?(?:bis|ter|quater|quinquies|sexies))?\\.\\s+\\S")
/// Apertura di un sommario in prosa: «1» seguito dal punto o da una lineetta, poi testo.
private let TARGETED_SUMMARY_OPENING_RE = try! NSRegularExpression(pattern: "^\\s*1\\s*[.\u{2013}\u{2014}-]\\s*\\S")
/// Voce successiva di un sommario: dopo una lineetta o un punto, «N.» seguito da testo.
private let TARGETED_SUMMARY_ITEM_RE = try! NSRegularExpression(pattern: "(?:[\u{2013}\u{2014}-]|\\.)\\s+\\d{1,3}\\.\\s+\\S")

func targetedMatches(_ re: NSRegularExpression, _ text: String) -> Bool {
    re.firstMatch(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text)) != nil
}

private func targetedMatchCount(_ re: NSRegularExpression, _ text: String) -> Int {
    re.numberOfMatches(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text))
}

/// Tutti gli span con lettere sono in grassetto (e ce n'è almeno uno).
func targetedLettersAllBold(_ sm: LineSummary) -> Bool {
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
func targetedHeadingLevel(_ node: NodeDict) -> Int? {
    switch node.type {
    case .HEADING_1: return 1
    case .HEADING_2: return 2
    case .HEADING_3: return 3
    case .HEADING_4: return 4
    default: return nil
    }
}

func targetedHeadingCategory(_ level: Int) -> SemanticCategory {
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
func targetedSplitBodyRuns(
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

// MARK: - Studio A — sommario di capitolo in prosa

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

// MARK: - Rifiniture del giro «rifiniture e cure per capacità» (build 63)

/// Etichetta di bibliografia: la parola-chiave da sola sulla riga (eventualmente col punto).
private let TARGETED_BIBLIOGRAPHY_LABEL_RE = try! NSRegularExpression(pattern: "^(?i:bibliografia)\\s*\\.?$")
/// Una riga che apre una nota col suo numero di richiamo («12 Cass. …», «12. …»), come la forma di `noteOpening`.
private let TARGETED_NOTE_NUMBER_OPENING_RE = try! NSRegularExpression(pattern: "^[\\(\\[]?\\s?\\d{1,3}\\s?[\\)\\]]?[\\.\\)]?(\\s+\\S|$)")

/// Studio B. L'etichetta di bibliografia di fine capitolo (parola-chiave sola, composta come i titoli di paragrafo: fra
/// corpo − 1,3 e corpo − 0,7 pt, non in grassetto, al bordo sinistro della colonna), dentro un blocco di corpo, staccata
/// dalla riga di sopra, diventa un titolo; le righe che la seguono nel blocco, più piccole del corpo (le voci, con le
/// loro righe rientrate), diventano il blocco bibliografico (`LETTERATURA`: si legge al suo posto, col segnale della
/// bibliografia). Il blocco finisce alla prima riga alla taglia del corpo.
private func targetedBibliographyLabels(_ items: [GenItem], _ profile: Profile) -> [GenItem] {
    guard profile.bodySize > 0, profile.targetedLeftEdge > 0 else { return items }
    let body = profile.bodySize, left = profile.targetedLeftEdge
    func labelSized(_ sm: LineSummary) -> Bool { sm.fontSize >= body - 1.3 && sm.fontSize <= body - 0.7 && !sm.bold }
    return targetedSplitBodyRuns(items) { lines, start, previous in
        let label = lines[start]
        guard labelSized(label), abs(label.x0 - left) <= 3,
              targetedMatches(TARGETED_BIBLIOGRAPHY_LABEL_RE, jsTrim(label.text)) else { return nil }
        if case .run(.body, let prevLines)? = previous, let p = prevLines.last {
            guard targetedGapBetween(p, label) else { return nil }
        }
        var end = start + 1
        while end < lines.count, lines[end].fontSize <= body - 0.5, !lines[end].bold { end += 1 }
        var made: [GenItem] = [.heading(label, level: 3)]
        if end > start + 1 { made.append(.apparatus(.LETTERATURA, Array(lines[(start + 1)..<end]))) }
        return (end, made)
    }
}

/// Una riga che apre una nota col numero seguito da uno spazio («12 Cass. …»): esclude le note dai riquadri (un elenco
/// «1) …» dentro un riquadro resta del riquadro).
private let TARGETED_BOX_NOTE_OPENING_RE = try! NSRegularExpression(pattern: "^\\d{1,3}\\s")

/// Studio B. Il riquadro di approfondimento dentro l'apparato a taglia di nota: le righe consecutive alla taglia delle note
/// (≤ 0,85 del corpo) con lo stesso bordo sinistro (±1 pt) rientrato di 6-16 pt rispetto alla colonna, mai oltre il bordo
/// destro della colonna meno 6 pt, che non aprono con un numero di nota; almeno due righe, almeno metà arrivano a 16 pt
/// dal bordo destro (righe giustificate del riquadro) e nessuna porta una voce di sommario «– N. …». Le note vere
/// cominciano col numero di richiamo e vanno a capo al bordo della colonna; i sommari elencano «– N.».
private func targetedFramedAsideBoxes(_ items: [GenItem], _ profile: Profile) -> [GenItem] {
    guard profile.bodySize > 0, profile.targetedLeftEdge > 0, profile.targetedRightEdge > profile.targetedLeftEdge else {
        return items
    }
    let body = profile.bodySize, left = profile.targetedLeftEdge, right = profile.targetedRightEdge
    func candidate(_ sm: LineSummary) -> Bool {
        let inset = sm.x0 - left
        return !jsTrim(sm.text).isEmpty && sm.fontSize <= body * 0.85 && inset >= 6 && inset <= 16
            && right - sm.x1 >= 6 && !targetedMatches(TARGETED_BOX_NOTE_OPENING_RE, jsTrim(sm.text))
    }
    var out: [GenItem] = []
    for item in items {
        guard case .run(.note, let lines) = item else { out.append(item); continue }
        var buf: [LineSummary] = []
        var i = 0
        while i < lines.count {
            if candidate(lines[i]) {
                var j = i + 1
                while j < lines.count, candidate(lines[j]), abs(lines[j].x0 - lines[i].x0) <= 1 { j += 1 }
                let run = Array(lines[i..<j])
                let justified = run.filter { right - $0.x1 <= 16 }.count
                let summary = run.contains { targetedMatchCount(TARGETED_SUMMARY_ITEM_RE, $0.text) > 0 }
                if run.count >= 2, Double(justified) >= max(1, 0.5 * Double(run.count)), !summary {
                    if !buf.isEmpty { out.append(.run(.note, buf)); buf = [] }
                    out.append(.apparatus(.EXAMPLE_BOX, run))
                    i = j
                    continue
                }
            }
            buf.append(lines[i]); i += 1
        }
        if !buf.isEmpty { out.append(.run(.note, buf)) }
    }
    return out
}

/// Studi A e B. Nell'apparato di note, una riga (non la prima del blocco) che comincia con un numero nella forma
/// dell'apertura di nota ma composto alla taglia del testo, non più piccolo come il richiamo in apice, continua la riga di
/// prima: è il numero di pagina di una citazione andato a capo, non una nota nuova. Si unisce alla riga precedente con
/// lo stesso spazio con cui il testo della nota la univa: lettere e cifre invariate.
private func targetedFullSizeNumberContinuesNote(_ items: [GenItem]) -> [GenItem] {
    items.map { item in
        guard case .run(.note, let lines) = item, lines.count > 1 else { return item }
        var out: [LineSummary] = [lines[0]]
        for sm in lines.dropFirst() {
            if targetedMatches(TARGETED_NOTE_NUMBER_OPENING_RE, jsTrim(sm.text)), !targetedOpensWithSmallerNumber(sm) {
                let prev = out[out.count - 1]
                out[out.count - 1] = LineSummary(
                    text: joinLines([prev.text, sm.text]), fontSize: prev.fontSize, bold: prev.bold, italic: prev.italic,
                    color: prev.color, x0: prev.x0, x1: prev.x1, yTop: prev.yTop, yBottom: prev.yBottom, width: prev.width,
                    height: prev.height, spans: prev.spans + sm.spans)
            } else {
                out.append(sm)
            }
        }
        return .run(.note, out)
    }
}

/// Vero se la riga comincia con un numero composto più piccolo (≤ 0,8) del testo più grande della riga: il richiamo in
/// apice con cui una nota si apre.
private func targetedOpensWithSmallerNumber(_ sm: LineSummary) -> Bool {
    let withText = sm.spans.filter { !jsTrim($0.text).isEmpty }
    guard let first = withText.first, jsTrim(first.text).first.map({ $0.isNumber || $0 == "(" || $0 == "[" }) == true else {
        return false
    }
    let biggest = withText.map { $0.fontSize }.max() ?? 0
    return withText.count >= 2 && biggest > 0 && first.fontSize <= biggest * 0.8
}

/// Studio B, in posizione: il titolo di bibliografia sta un livello sotto il CAPITOLO (o la parte) che lo contiene, anche
/// dentro un capitolo diviso in sezioni: la bibliografia è del capitolo, non dell'ultima sezione.
private func targetedBibliographyLevels(_ nodes: inout [NodeDict]) -> Int {
    var unitLevel: Int?
    var touched = 0
    for i in nodes.indices {
        guard let level = targetedHeadingLevel(nodes[i]) else { continue }
        let text = jsTrim(nodes[i].text ?? "")
        let words = text.split(separator: " ")
        if words.count >= 2, targetedMatches(TARGETED_UNIT_LABEL_RE, words.prefix(2).joined(separator: " ")) {
            unitLevel = level
            continue
        }
        guard let unit = unitLevel, targetedMatches(TARGETED_BIBLIOGRAPHY_LABEL_RE, text) else { continue }
        let want = min(4, unit + 1)
        if level != want {
            nodes[i].type = targetedHeadingCategory(want)
            nodes[i].level = want
            touched += 1
        }
    }
    return touched
}

// MARK: - Regole sui segmenti di lettura (dopo l'impaginazione del corpo)

/// Applica le regole mirate sul flusso dei segmenti (dopo la granularità e il frazionamento delle note, prima delle risorse
/// visive). Chiamata da `ContinuousBodyBuilder` con le regole dell'impronta del file: per ogni documento non registrato
/// l'insieme è vuoto e il flusso torna invariato senza eseguire nulla.
public func applyTargetedSegmentRules(
    _ segments: [ContentSegment], _ rules: Set<TargetedRule>, target: Int
) -> [ContentSegment] {
    guard rules.contains(.framedAsideBoxes) else { return segments }
    return targetedJoinAndFractionAsideBoxes(segments, target: target)
}

/// Studio B. I riquadri (`EXAMPLE_BOX`): il pezzo in fondo a una pagina e la sua continuazione in cima alla pagina dopo,
/// consecutivi nel flusso, diventano un riquadro solo (la parola spezzata a fine pagina si ricompone come nelle note);
/// poi un riquadro più lungo della soglia si divide in pezzi con la regola delle note lunghe (§ 10.6): il primo pezzo
/// porta l'annuncio «Riquadro.», gli altri seguono senza annuncio. Lettere e cifre invariate.
private func targetedJoinAndFractionAsideBoxes(_ segments: [ContentSegment], target: Int) -> [ContentSegment] {
    let box = SemanticCategory.EXAMPLE_BOX.rawValue
    // 1. unione dei pezzi consecutivi su pagine contigue (con la pagina d'inizio di ciascuna parte)
    var joined: [(segment: ContentSegment, parts: [(offset: Int, page: Int?)])] = []
    for seg in segments {
        if seg.role == box, let last = joined.last, last.segment.role == box,
           let p = last.parts.last?.page, let q = seg.sourcePage, q == p + 1 {
            var merged = last.segment
            let text = joinFootnoteTexts(merged.text, seg.text)
            let offset = text.count - jsTrim(seg.text).count
            merged.text = text
            joined[joined.count - 1] = (merged, last.parts + [(offset, seg.sourcePage)])
            continue
        }
        joined.append((seg, [(0, seg.sourcePage)]))
    }
    // 2. pezzi alla soglia, con la pagina su cui ogni pezzo comincia
    var out: [ContentSegment] = []
    for (seg, parts) in joined {
        guard seg.role == box, seg.text.count > target else { out.append(seg); continue }
        let pieces = notePieces(seg.text, target: target)
        guard pieces.count > 1 else { out.append(seg); continue }
        var cursor = 0
        for (i, text) in pieces.enumerated() {
            let page = parts.last(where: { $0.offset <= cursor })?.page ?? seg.sourcePage
            out.append(ContentSegment(
                id: "\(seg.id)#\(i)", role: box, text: text, lengthCategory: "",
                acousticIntro: i == 0 ? seg.acousticIntro : "", sourcePage: page))
            cursor += text.count
            // gli spazi fra un pezzo e l'altro non sono nei pezzi: si riallinea il cursore al testo intero
            let all = Array(seg.text)
            while cursor < all.count, all[cursor].isWhitespace { cursor += 1 }
        }
    }
    return out
}

// MARK: - Capoversi rientrati (studi A e B)

/// La famiglia del documento con la cura mirata dei capoversi rientrati: come per i documenti monotipografici, la
/// granularità chiude il blocco dove comincia un capoverso (`buildBaseSegments` → `ContentSegment.opensParagraph`).
public let TARGETED_PARAGRAPHS_FAMILY = "capoversi_rientrati"

/// Il rientro di prima riga del documento: lo scarto dal bordo sinistro (al mezzo punto) più frequente fra 8 e 24 pt sulle
/// righe alla taglia del corpo. 0 se non c'è.
func targetedBodyParagraphIndent(_ extraction: PdfExtraction, body: Double, left: Double) -> Double {
    guard body > 0, left > 0 else { return 0 }
    var counts: [Double: Int] = [:]
    for page in extraction.pages {
        for line in page.lines {
            let sm = summarizeLine(line)
            let indent = ((sm.x0 - left) * 2).rounded() / 2
            guard abs(sm.fontSize - body) <= 0.3, indent >= 8, indent <= 24 else { continue }
            counts[indent, default: 0] += 1
        }
    }
    return counts.max { $0.value < $1.value || ($0.value == $1.value && $0.key > $1.key) }?.key ?? 0
}

/// Caratteri che chiudono una frase (anche dopo una chiusura di citazione o di parentesi).
private let TARGETED_SENTENCE_CLOSERS: Set<Character> = [".", ":", ";", "!", "?", "»", "\u{201D}", ")", "\""]

/// Dentro un blocco di corpo, la riga rientrata del rientro di prima riga (±1,5 pt) apre un capoverso nuovo se la riga
/// di prima chiude la frase o finisce corta (oltre 10 pt prima del bordo destro della colonna) e se essa stessa comincia
/// come un inizio di frase (maiuscola, cifra, virgolette, parentesi). Il blocco si spezza lì: righe e testo invariati.
private func targetedIndentedParagraphs(_ items: [GenItem], _ profile: Profile) -> [GenItem] {
    let left = profile.targetedLeftEdge, right = profile.targetedRightEdge, indent = profile.targetedParagraphIndent
    guard profile.bodySize > 0, left > 0, right > left, indent > 0 else { return items }
    let body = profile.bodySize
    func opensParagraph(_ prev: LineSummary, _ sm: LineSummary) -> Bool {
        guard abs(sm.x0 - (left + indent)) <= 1.5, abs(sm.fontSize - body) <= 0.6, abs(prev.fontSize - body) <= 0.6,
              let first = jsTrim(sm.text).first, first.isUppercase || first.isNumber || "«“\"(".contains(first) else {
            return false
        }
        let closes = jsTrim(prev.text).last.map { TARGETED_SENTENCE_CLOSERS.contains($0) } ?? false
        return closes || prev.x1 < right - 10
    }
    var out: [GenItem] = []
    for item in items {
        guard case .run(.body, let lines) = item, lines.count > 1 else { out.append(item); continue }
        var current: [LineSummary] = [lines[0]]
        for sm in lines.dropFirst() {
            if opensParagraph(current[current.count - 1], sm) {
                out.append(.run(.body, current))
                current = [sm]
            } else {
                current.append(sm)
            }
        }
        out.append(.run(.body, current))
    }
    return out
}

/// Studio B, in posizione: il blocco bibliografico che continua in cima alla pagina dopo. Il primo nodo che segue il blocco
/// (saltate le note della stessa pagina), se è corpo sulla pagina successiva, ne è la continuazione: un capitolo finisce
/// con la sua bibliografia e il capitolo dopo comincia sempre con un titolo, quindi nessun corpo vero sta lì.
private func targetedBibliographyContinuation(_ nodes: inout [NodeDict]) -> Int {
    var touched = 0
    for i in nodes.indices where nodes[i].type == .LETTERATURA {
        var j = i + 1
        while j < nodes.count, nodes[j].type == .NOTE, nodes[j].page_index == nodes[i].page_index { j += 1 }
        guard j < nodes.count, nodes[j].type == .BODY, nodes[j].page_index == nodes[i].page_index + 1 else { continue }
        nodes[j].type = .LETTERATURA
        touched += 1
    }
    return touched
}
