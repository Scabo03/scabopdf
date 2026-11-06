//
//  IsolatedSectionTitles.swift
//  ScaboCore
//
//  I TITOLI DI SEZIONE ISOLATI DA STACCHI — canale del tronco (giro «rifiniture e cure per capacità», 2026-11-06, voce
//  2.3). In molti libri il titolo di una sezione è composto alla taglia del corpo, distinto solo dal corsivo (che sul
//  dispositivo il lettore di sistema perde) e dallo spazio bianco: sul dispositivo restava corpo, incollato al capoverso
//  che segue. La forma che lo distingue, senza tipografia: una riga
//   • alla taglia del corpo, che comincia al bordo sinistro della colonna (±1,5 pt) ed è corta (al più 3/4 della colonna,
//     al più 80 caratteri), comincia in maiuscola, cifra o virgolette e non finisce con un punto, una virgola, un punto e
//     virgola, i due punti o un trattino;
//   • staccata dalla riga che la precede sulla stessa pagina da almeno 2,2 passi di riga del corpo, e da quella che la segue
//     da almeno 1,6 passi;
//   • seguita da una riga che apre un capoverso: comincia esattamente al rientro di prima riga del documento (±1,5 pt).
//  Il passo di riga, i bordi della colonna e il rientro si misurano sul documento (le mode delle righe di corpo). Dove la
//  calibrazione non regge (nessun rientro di capoverso, colonna incerta) il canale non si applica. Nessun testo scritto: la
//  riga diventa un'intestazione, il resto del blocco resta corpo.
//

import Foundation

/// Calibrazione del canale sul documento.
public struct IsolatedTitleCalibration: Equatable, Sendable {
    let step: Double
    let left: Double
    let right: Double
    let indent: Double
}

let ISOLATED_TITLE_GAP_ABOVE = 2.2
let ISOLATED_TITLE_GAP_BELOW = 1.6
let ISOLATED_TITLE_MAX_CHARS = 80
let ISOLATED_TITLE_MAX_WIDTH_FRACTION = 0.75

/// Le mode del documento: passo fra righe di corpo consecutive, bordi sinistro e destro delle righe di corpo larghe,
/// rientro di prima riga (scarto più frequente fra 8 e 24 pt). `nil` se manca una di queste misure.
func isolatedTitleCalibration(_ extraction: PdfExtraction, body: Double) -> IsolatedTitleCalibration? {
    guard body > 0 else { return nil }
    var steps: [Double: Int] = [:], lefts: [Double: Int] = [:], rights: [Double: Int] = [:]
    for page in extraction.pages {
        let lines = page.lines.map(summarizeLine)
        for (a, b) in zip(lines, lines.dropFirst()) where abs(a.fontSize - body) <= 0.4 && abs(b.fontSize - body) <= 0.4 {
            let d = a.yBottom - b.yBottom
            if d > 0, d < 3 * body { steps[(d * 2).rounded() / 2, default: 0] += 1 }
        }
        for sm in lines where abs(sm.fontSize - body) <= 0.4 && sm.width > page.width * 0.4 {
            lefts[(sm.x0 * 2).rounded() / 2, default: 0] += 1
            rights[(sm.x1 * 2).rounded() / 2, default: 0] += 1
        }
    }
    func mode(_ c: [Double: Int]) -> Double? { c.max { $0.value < $1.value || ($0.value == $1.value && $0.key > $1.key) }?.key }
    guard let step = mode(steps), let left = mode(lefts), let right = mode(rights), right > left else { return nil }
    var indents: [Double: Int] = [:]
    for page in extraction.pages {
        for line in page.lines {
            let sm = summarizeLine(line)
            let ind = ((sm.x0 - left) * 2).rounded() / 2
            if abs(sm.fontSize - body) <= 0.4, ind >= 8, ind <= 24 { indents[ind, default: 0] += 1 }
        }
    }
    guard let indent = mode(indents) else { return nil }
    return IsolatedTitleCalibration(step: step, left: left, right: right, indent: indent)
}

private let ISOLATED_TITLE_BAD_ENDINGS: Set<Character> = [".", ",", ";", ":", "-", "\u{2013}", "\u{2014}"]

/// Il canale: spezza i blocchi di corpo dove una riga ha la forma del titolo di sezione isolato (vedi l'intestazione).
func recognizeIsolatedSectionTitles(_ items: [GenItem], _ profile: Profile) -> [GenItem] {
    guard let cal = profile.isolatedTitles, profile.bodySize > 0 else { return items }
    let body = profile.bodySize
    func isTitleShaped(_ sm: LineSummary) -> Bool {
        let t = jsTrim(sm.text)
        guard let first = t.first, let last = t.last, t.count <= ISOLATED_TITLE_MAX_CHARS else { return false }
        return abs(sm.fontSize - body) <= 0.6 && abs(sm.x0 - cal.left) <= 1.5
            && sm.x1 - sm.x0 <= ISOLATED_TITLE_MAX_WIDTH_FRACTION * (cal.right - cal.left)
            && (first.isUppercase || first.isNumber || "«“\"".contains(first)) && !ISOLATED_TITLE_BAD_ENDINGS.contains(last)
    }
    var out: [GenItem] = []
    // L'ultima riga emessa sulla pagina (di qualunque item), per lo stacco sopra.
    func lastLine(_ item: GenItem) -> LineSummary? {
        switch item {
        case .heading(let sm, _), .numberedTitle(let sm, _), .monoTitle(let sm, _): return sm
        case .run(_, let lines), .apparatus(_, let lines): return lines.last
        }
    }
    for item in items {
        guard case .run(.body, let lines) = item, lines.count >= 2 else { out.append(item); continue }
        var buf: [LineSummary] = []
        var prev: LineSummary? = out.last.flatMap(lastLine)
        var k = 0
        while k < lines.count {
            let sm = lines[k]
            if k + 1 < lines.count, isTitleShaped(sm), let above = prev,
               above.yBottom - sm.yBottom >= ISOLATED_TITLE_GAP_ABOVE * cal.step,
               sm.yBottom - lines[k + 1].yBottom >= ISOLATED_TITLE_GAP_BELOW * cal.step,
               abs(lines[k + 1].x0 - (cal.left + cal.indent)) <= 1.5, abs(lines[k + 1].fontSize - body) <= 0.6 {
                if !buf.isEmpty { out.append(.run(.body, buf)); buf = [] }
                out.append(.heading(sm, level: 3))
            } else {
                buf.append(sm)
            }
            prev = sm
            k += 1
        }
        if !buf.isEmpty { out.append(.run(.body, buf)) }
    }
    return out
}
