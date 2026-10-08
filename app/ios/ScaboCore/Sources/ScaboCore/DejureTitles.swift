//
//  DejureTitles.swift
//  ScaboCore
//
//  Ramo DeJure — titoli in grassetto a taglia di corpo (giro finale 2026-10-08, voce 6). Negli export DeJure i titoli
//  di sezione delle dottrine e i titoli delle massime sono righe in GRASSETTO alla taglia del corpo, dentro i run di
//  corpo: il tronco riconosce i titoli dallo scarto di taglia e questi si leggevano come corpo (nessun punto di
//  navigazione). Il grassetto c'è nelle estrazioni di entrambe le generazioni. La foglia lavora sulle righe, dentro
//  `pageItems` (dopo i titoli numerati e monotipografici, prima della fusione dei titoli spezzati): `appendPageNodes` e
//  `bindAndPlaceNotes` vedono gli stessi item, lo zip 1:1 resta allineato. Porta: `Profile.isDejure` (la stessa firma
//  a tre segnali di `DeJurePlugin.matches`); fuori da DeJure è un no-op.
//
//  Regola: in un run di corpo, un blocco di righe consecutive a taglia di corpo, la prima almeno all'80 % in grassetto
//  (al 60 % se apre con un numero di sezione: una locuzione latina in tondo dentro il titolo), le seguenti almeno al
//  60 %; al più 3 righe e 260 caratteri; mai l'etichetta «Note:». Numerato → titolo numerato (livello relativo del
//  canale dei titoli numerati); non numerato → primo livello (titolo di massima). Il titolo d'articolo delle dottrine
//  (grassetto appena più grande del corpo, che il tronco mette al quarto livello) sale al primo: così l'articolo
//  contiene le sue sezioni (2) e sottosezioni (3). Scartate: un passaggio sui nodi dopo l'assemblaggio (nei nodi non
//  restano né il grassetto né i confini di riga); soglia di 200 caratteri (perde tre titoli di massima lunghi).
//

import Foundation

let DEJURE_TITLE_FIRST_BOLD_MIN = 0.8
let DEJURE_TITLE_NUMBERED_FIRST_BOLD_MIN = 0.6
let DEJURE_TITLE_CONTINUATION_BOLD_MIN = 0.6
let DEJURE_TITLE_MAX_LINES = 3
let DEJURE_TITLE_MAX_CHARS = 260

/// La riga che è SOLO l'etichetta della sezione delle note («Note:»): resta nel corpo, dove `recoverDejureNotes` la cerca.
private let DEJURE_NOTES_LABEL_LINE_REGEX = try! NSRegularExpression(pattern: "^\\s*Note\\s?:\\s*$")

/// Frazione dei caratteri non-spazio della riga che sono in grassetto.
func boldFraction(_ sm: LineSummary) -> Double {
    var bold = 0, total = 0
    for sp in sm.spans {
        let n = sp.text.unicodeScalars.filter { !CharacterSet.whitespaces.contains($0) }.count
        total += n
        if sp.bold { bold += n }
    }
    return total > 0 ? Double(bold) / Double(total) : 0
}

func recognizeDejureBoldTitles(_ items: [GenItem], _ profile: Profile) -> [GenItem] {
    guard profile.isDejure, profile.bodySize > 0 else { return items }
    let body = profile.bodySize
    func bodySized(_ sm: LineSummary) -> Bool { abs(sm.fontSize - body) <= BODY_SIZE_TOLERANCE }
    func isNoteLabel(_ sm: LineSummary) -> Bool {
        DEJURE_NOTES_LABEL_LINE_REGEX.firstMatch(in: sm.text, range: NSRange(sm.text.startIndex..<sm.text.endIndex, in: sm.text)) != nil
    }
    func opensTitle(_ sm: LineSummary) -> Bool {
        let f = boldFraction(sm)
        return bodySized(sm) && !isNoteLabel(sm)
            && (f >= DEJURE_TITLE_FIRST_BOLD_MIN || (f >= DEJURE_TITLE_NUMBERED_FIRST_BOLD_MIN && numberedTitleDepth(sm.text) != nil))
    }
    func continuesTitle(_ sm: LineSummary) -> Bool {
        bodySized(sm) && !isNoteLabel(sm) && boldFraction(sm) >= DEJURE_TITLE_CONTINUATION_BOLD_MIN
    }
    var out: [GenItem] = []
    for item in items {
        switch item {
        case .heading(let sm, let level) where level == 4 && sm.bold
            && sm.fontSize / body >= HEADING_4_BOLD_RATIO && sm.fontSize / body < HEADING_3_RATIO:
            out.append(.heading(sm, level: 1))
        case .run(.body, let lines):
            var pending: [LineSummary] = []
            var i = 0
            while i < lines.count {
                guard opensTitle(lines[i]) else { pending.append(lines[i]); i += 1; continue }
                var j = i + 1
                while j < lines.count, continuesTitle(lines[j]) { j += 1 }
                let group = Array(lines[i..<j])
                if group.count <= DEJURE_TITLE_MAX_LINES, group.reduce(0, { $0 + $1.text.count }) <= DEJURE_TITLE_MAX_CHARS {
                    if !pending.isEmpty { out.append(.run(.body, pending)); pending = [] }
                    let merged = mergedLine(group)
                    if let depth = numberedTitleDepth(merged.text) {
                        out.append(.numberedTitle(merged, depth: depth))
                    } else {
                        out.append(.heading(merged, level: 1))
                    }
                } else {
                    pending.append(contentsOf: group)
                }
                i = j
            }
            if !pending.isEmpty { out.append(.run(.body, pending)) }
        default:
            out.append(item)
        }
    }
    return out
}
