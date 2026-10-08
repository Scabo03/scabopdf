//
//  RowSplit.swift
//  ScaboCore
//
//  Righe fuse (giro finale 2026-10-08, voce 5; A.5 di ULTRAFOCUS_INBOX). PDFKit a volte fonde in una sola riga due
//  righe fisiche della pagina: la testatina o il piè e la prima o l'ultima riga di contenuto. La riga fusa sfugge al
//  riconoscimento della mobilia (il suo testo non ricorre da una pagina all'altra) e la testatina si legge dentro il
//  contenuto. Qui la riga si riporta alle sue righe fisiche. Funzione pura, solo Foundation, agganciata in
//  `PdfKitExtractor.lines` dopo la riparazione dei confini di parola (che allinea i run a una e una sola riga di PDFKit:
//  farla sulla riga ancora fusa ne lascia invariato l'esito): app, banco, runner e Mac partono così dalla stessa
//  estrazione. Lettere mai aggiunte né tolte: cambia solo il confine fra le righe.
//
//  Scartate: spezzare ogni riga su fasce disgiunte, anche a metà pagina (tocca righe di contenuto che oggi si leggono
//  bene, senza guadagno sulla mobilia); spezzare nel riconoscimento della mobilia invece che nell'estrazione (la riga
//  fusa resterebbe un pezzo unico fino in fondo alla catena, e la testatina tornerebbe dentro il contenuto letto).
//  `lineJoinsDisjointRows` in `detectFurniture` resta: protegge le righe che qui non si spezzano.
//

import Foundation

/// Le righe fisiche di una riga di PDFKit. Gli span con testo che stanno su fasce verticali disgiunte (sovrapposizione
/// sotto 0,5 pt, la regola di `lineJoinsDisjointRows`) appartengono a righe fisiche diverse. Una fascia che è solo un
/// richiamo («(1)», «*», cifre più piccole del resto), un capolettera (una lettera sola) o un numero nudo a metà pagina
/// (il numero di un titolo che PDFKit ha incollato alla testatina) non fa riga da sola: va con la fascia più vicina e
/// resta dov'era. Gli span senza testo o col riquadro nullo non fondano una fascia: seguono lo span precedente (il
/// successivo, se in testa). Le righe escono dall'alto in basso; la riga resta una sola se le fasce sostanziali sono
/// meno di due.
func physicalRows(_ line: PdfTextLine, pageHeight: Double) -> [PdfTextLine] {
    let n = line.spans.count
    guard n >= 2 else { return [line] }
    typealias Band = (low: Double, high: Double, members: [Int])
    func founds(_ s: PdfSpan) -> Bool { !jsTrim(s.text).isEmpty && (s.bbox.width > 0 || s.bbox.height > 0) }
    var intervals: [(low: Double, high: Double, idx: Int)] = []
    for (i, s) in line.spans.enumerated() where founds(s) {
        intervals.append((s.bbox.y, s.bbox.y + s.bbox.height, i))
    }
    intervals.sort { $0.low < $1.low || ($0.low == $1.low && $0.idx < $1.idx) }
    var bands: [Band] = []
    for t in intervals {
        if var last = bands.last, t.low < last.high - 0.5 {
            last.high = max(last.high, t.high); last.members.append(t.idx)
            bands[bands.count - 1] = last
        } else {
            bands.append((t.low, t.high, [t.idx]))
        }
    }
    guard bands.count >= 2 else { return [line] }
    func bandText(_ b: Band) -> String { b.members.sorted().map { line.spans[$0].text }.joined().filter { !$0.isWhitespace } }
    func bandSize(_ b: Band) -> Double { b.members.map { line.spans[$0].fontSize }.max() ?? 0 }
    let maxSize = bands.map { bandSize($0) }.max() ?? 0
    let isMarker = bands.map { b -> Bool in
        let t = bandText(b)
        if t.count == 1, t.unicodeScalars.allSatisfy({ CharacterSet.letters.contains($0) }) { return true }
        if t.range(of: "^\\([0-9*†‡]{1,4}\\)$", options: .regularExpression) != nil { return true }
        if t.range(of: "^[*†‡]{1,3}$", options: .regularExpression) != nil { return true }
        if t.range(of: "^[0-9]{1,3}$", options: .regularExpression) != nil, bandSize(b) < 0.8 * maxSize { return true }
        if t.range(of: "^[0-9.]{1,6}$", options: .regularExpression) != nil, pageHeight > 0 {
            let top = b.high / pageHeight
            if !(top >= TOP_BAND || top <= BOTTOM_BAND) { return true }
        }
        return false
    }
    let kept = bands.indices.filter { !isMarker[$0] }
    guard kept.count >= 2 else { return [line] }
    var merged = kept.map { bands[$0] }
    for b in bands.indices where isMarker[b] {
        func gap(_ x: Band) -> Double { max(0, max(x.low - bands[b].high, bands[b].low - x.high)) }
        var best = 0
        for k in merged.indices where gap(merged[k]) < gap(merged[best]) { best = k }
        merged[best].members.append(contentsOf: bands[b].members)
        merged[best].low = min(merged[best].low, bands[b].low)
        merged[best].high = max(merged[best].high, bands[b].high)
    }
    var bandOf = [Int?](repeating: nil, count: n)
    for (b, band) in merged.enumerated() { for i in band.members { bandOf[i] = b } }
    var previous: Int? = nil
    for i in 0..<n {
        if let b = bandOf[i] { previous = b } else if let b = previous { bandOf[i] = b }
    }
    var following: Int? = nil
    for i in stride(from: n - 1, through: 0, by: -1) {
        if let b = bandOf[i] { following = b } else if let b = following { bandOf[i] = b }
    }
    // dall'alto in basso: l'asse y del PDF sale, la fascia più alta ha `high` maggiore
    var rows: [PdfTextLine] = []
    for b in merged.indices.sorted(by: { merged[$0].high > merged[$1].high }) {
        let spans = line.spans.indices.filter { bandOf[$0] == b }.map { line.spans[$0] }
        if jsTrim(spans.map { $0.text }.joined()).isEmpty { continue }
        let boxes = spans.map { $0.bbox }.filter { $0.width > 0 || $0.height > 0 }
        guard let minX = boxes.map({ $0.x }).min(), let minY = boxes.map({ $0.y }).min(),
              let maxX = boxes.map({ $0.x + $0.width }).max(), let maxY = boxes.map({ $0.y + $0.height }).max() else {
            rows.append(PdfTextLine(spans: spans, bbox: BBox(x: 0, y: 0, width: 0, height: 0))); continue
        }
        rows.append(PdfTextLine(spans: spans, bbox: BBox(x: minX, y: minY, width: maxX - minX, height: maxY - minY)))
    }
    return rows.isEmpty ? [line] : rows
}

/// Le righe di una pagina con le fusioni di BANDA spezzate. Una riga si spezza solo se (1) le sue righe fisiche sono
/// almeno due; (2) almeno una sta nella banda alta o bassa della pagina (TOP_BAND / BOTTOM_BAND sulla sommità, come la
/// mobilia): una fusione a metà pagina resta com'è; (3) se la riga intera non è quasi bianca, nessuna riga fisica lo
/// diventa (`pageItems` la scarterebbe: testo che oggi si legge andrebbe perso).
public func splittingFusedBandRows(_ lines: [PdfTextLine], pageHeight: Double) -> [PdfTextLine] {
    var out: [PdfTextLine] = []
    out.reserveCapacity(lines.count)
    for line in lines {
        let rows = physicalRows(line, pageHeight: pageHeight)
        if rows.count < 2 { out.append(line); continue }
        if !isNearWhite(summarizeLine(line).color), rows.contains(where: { isNearWhite(summarizeLine($0).color) }) {
            out.append(line); continue
        }
        let inBand = rows.contains { r in
            let top = pageHeight > 0 ? (r.bbox.y + r.bbox.height) / pageHeight : 0.5
            return top >= TOP_BAND || top <= BOTTOM_BAND
        }
        if inBand { out.append(contentsOf: rows) } else { out.append(line) }
    }
    return out
}
