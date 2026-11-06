//
//  WordBoldTitles.swift
//  ScaboCore
//
//  I TITOLI IN GRASSETTO ALLA TAGLIA DEL CORPO DELLE DISPENSE SCRITTE CON WORD — cura per capacità del tronco (giro
//  «rifiniture e cure per capacità», 2026-11-06, voce 2.2; decisione del maintainer in LAYER2_PRODUCT_DECISIONS § 0-ter).
//
//  Nata come cura mirata della dispensa di studio (studio-A, build 62), diventa capacità con una FIRMA DI DOCUMENTO che
//  dichiara quando si accende. In una dispensa scritta con Word a carattere unico i titoli di capitolo e di paragrafo sono
//  composti in grassetto alla taglia del corpo: il tronco riconosce un titolo per taglia, colore o grassetto più grande del
//  corpo, e non li vedeva. La firma (`wordBoldTitlesSignature`):
//   • il file viene da Microsoft Word (produttore o creatore): la decisione del maintainer riguarda le dispense Word;
//   • il grassetto alla taglia del corpo sta SOLO su righe intere: nessuna riga di corpo ha un grassetto parziale (chi
//     usa il grassetto per mettere in rilievo parole dentro le frasi non accende la cura);
//   • le righe intere in grassetto sono poche (almeno 5, al più il 10 % delle righe di corpo): titoli, non testo;
//   • il documento non è monotipografico (quelli hanno il loro canale, MonoTitles.swift) e non appartiene a un ramo che ha
//     le sue regole (rivista DPC, codici, DeJure, Estratto, famiglia Giappichelli/Photoshop).
//  Sui 52 volumi del banco la firma non si accende su nessuno (misurato): la lettura di tutti resta identica al byte.
//
//  Il riconoscimento (`recognizeWordBoldTitles`) e i livelli (`flatNumberedParagraphLevels`) sono quelli della cura mirata,
//  spostati qui senza cambiamenti: righe consecutive tutte in grassetto alla taglia del corpo dentro un blocco di corpo sono
//  titoli; l'etichetta «parola-chiave di struttura + numero romano» con le righe che la seguono è il capitolo; ogni riga che
//  apre con un numero apre un titolo di paragrafo, un livello sotto l'unità che lo contiene. Nessun testo scritto.
//

import Foundation

/// Quota massima delle righe di corpo che possono essere intere in grassetto perché la firma regga (titoli, non testo).
let WORD_BOLD_TITLES_MAX_FRACTION = 0.10
/// Numero minimo di righe intere in grassetto alla taglia del corpo.
let WORD_BOLD_TITLES_MIN_LINES = 5

/// La firma delle dispense Word con i titoli in grassetto alla taglia del corpo (vedi l'intestazione del file).
func wordBoldTitlesSignature(_ extraction: PdfExtraction, body: Double) -> Bool {
    guard body > 0 else { return false }
    let origin = ((extraction.producer ?? "") + " " + (extraction.creator ?? "")).lowercased()
    guard origin.contains("microsoft"), origin.contains("word") else { return false }
    var bodyLines = 0, wholeBold = 0
    for page in extraction.pages {
        for line in page.lines {
            let withLetters = line.spans.filter { $0.text.contains { $0.isLetter } }
            guard !withLetters.isEmpty else { continue }
            guard abs(summarizeLine(line).fontSize - body) <= 0.6 else { continue }
            bodyLines += 1
            let bold = withLetters.filter { $0.bold }.count
            if bold == withLetters.count { wholeBold += 1 } else if bold > 0 { return false }
        }
    }
    return wholeBold >= WORD_BOLD_TITLES_MIN_LINES && Double(wholeBold) <= WORD_BOLD_TITLES_MAX_FRACTION * Double(bodyLines)
}

/// Riga di titolo: tutte le lettere in grassetto, alla taglia del corpo (±0,6 pt).
private func isWordBoldTitleLine(_ sm: LineSummary, body: Double) -> Bool {
    abs(sm.fontSize - body) <= 0.6 && targetedLettersAllBold(sm) && sm.text.contains { $0.isLetter }
}

/// Le righe in grassetto a taglia di corpo, consecutive dentro un blocco di corpo, sono titoli: l'etichetta di capitolo
/// (parola-chiave + romano) assorbe le righe successive che non aprono un numero (il titolo del capitolo) e diventa
/// un'intestazione di capitolo; ogni riga che apre con un numero apre un titolo di paragrafo, e le righe che seguono senza
/// numero sono la sua continuazione. Un gruppo che non apre né con l'etichetta né con un numero resta un titolo a sé.
func recognizeWordBoldTitles(_ items: [GenItem], _ profile: Profile) -> [GenItem] {
    guard profile.bodySize > 0 else { return items }
    let body = profile.bodySize
    return targetedSplitBodyRuns(items) { lines, start, _ in
        guard isWordBoldTitleLine(lines[start], body: body) else { return nil }
        var end = start
        while end < lines.count, isWordBoldTitleLine(lines[end], body: body) { end += 1 }
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

/// In posizione: i titoli di paragrafo (che aprono con un numero) stanno tutti un livello sotto l'unità che li contiene
/// (capitolo, o sezione dove c'è). Un titolo il cui numero non porta subito il punto (un refuso della stampa, un «N bis.»)
/// non deve trascinare più in basso i titoli che lo seguono, come farebbe il calcolo relativo dei manuali, che lo prende per
/// un titolo non numerato. Usata dalla capacità dei titoli in grassetto delle dispense Word e dalla cura mirata dei titoli
/// di paragrafo più piccoli del corpo (studio-B).
@discardableResult
func flatNumberedParagraphLevels(_ nodes: inout [NodeDict]) -> Int {
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
