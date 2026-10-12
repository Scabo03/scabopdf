//
//  ReadingOrder.swift
//  ScaboPageStructure
//
//  Porto di `docling_ibm_models.reading_order.reading_order_rb.ReadingOrderPredictor` (docling-ibm-models
//  3.13.3, MIT, © 2024 International Business Machines — vedi LICENSES/docling-MIT.txt), regole senza torch.
//  `predictReadingOrder`, `predictMerges`: porto fedele dal prototipo del laboratorio «struttura nativa»
//  (ordine identico a docling su 35/35 pagine). `predictToCaptions`: porto di `predict_to_captions` /
//  `_find_to_captions`, aggiunto in questo modulo per associare didascalie a tabelle e figure.
//

import Foundation

/// Elemento di pagina per l'ordine di lettura (porto di docling_ibm_models.reading_order.reading_order_rb.PageElement).
struct PageElement {
    let cid: Int
    var label: String
    var text: String
    var pageNo: Int
    var pageW: Double, pageH: Double
    var box: ROBox   // origine basso-sinistra
    /// __lt__ di PageElement
    func lt(_ o: PageElement) -> Bool {
        if pageNo == o.pageNo { return box.overlapsHorizontally(o.box) ? (box.b > o.box.b) : (box.l < o.box.l) }
        return pageNo < o.pageNo
    }
}

/// Porto di ReadingOrderPredictor (regole, senza torch), con la stessa dilatazione orizzontale (soglia 0,15 della larghezza).
struct ReadingOrderPredictor {
    let dilate = true
    let horizontalDilationThresholdNorm = 0.15

    func predictReadingOrder(_ elements: [PageElement]) -> [PageElement] {
        var pageNos = Set<Int>(); for e in elements { pageNos.insert(e.pageNo) }
        var headers: [Int: [PageElement]] = [:], body: [Int: [PageElement]] = [:], footers: [Int: [PageElement]] = [:]
        for p in pageNos { headers[p] = []; body[p] = []; footers[p] = [] }
        for e in elements {
            if e.label == "page_header" { headers[e.pageNo]!.append(e) } else if e.label == "page_footer" { footers[e.pageNo]!.append(e) } else { body[e.pageNo]!.append(e) }
        }
        var out: [PageElement] = []
        for p in pageNos.sorted() {
            out.append(contentsOf: predictPage(headers[p]!)); out.append(contentsOf: predictPage(body[p]!)); out.append(contentsOf: predictPage(footers[p]!))
        }
        return out
    }

    struct State { var up: [[Int]] = []; var dn: [[Int]] = []; var heads: [Int] = []; var l2r: [Int: Int] = [:]; var r2l: [Int: Int] = [:] }

    func predictPage(_ elems: [PageElement]) -> [PageElement] {
        if elems.isEmpty { return [] }
        var state = State()
        initUDMaps(elems, &state)
        if dilate {
            let dil = doHorizontalDilation(elems, state)
            initUDMaps(dil, &state)
        }
        findHeads(elems, &state)
        sortUDMaps(elems, &state)
        let order = findOrder(elems, &state)
        return order.map { elems[$0] }
    }

    func initUDMaps(_ pe: [PageElement], _ s: inout State) {
        s.up = Array(repeating: [], count: pe.count); s.dn = Array(repeating: [], count: pe.count)
        for j in 0..<pe.count {
            if let i = s.r2l[j] { s.dn[i] = [j]; s.up[j] = [i]; continue }
            let bj = pe[j].box
            // candidati dell'R-tree: rettangolo (l-0.1, t, r+0.1, +inf) — poi i controlli esatti
            for i in 0..<pe.count where i != j {
                let bi = pe[i].box
                if !(bi.r >= bj.l - 0.1 && bi.l <= bj.r + 0.1 && bi.t >= bj.t) { continue }
                if !(bi.isStrictlyAbove(bj) && bi.overlapsHorizontally(bj)) { continue }
                if !hasSequenceInterruption(pe, i, j) {
                    var ii = i; while let n = s.l2r[ii] { ii = n }
                    s.dn[ii].append(j); s.up[j].append(ii)
                }
            }
        }
    }

    func hasSequenceInterruption(_ pe: [PageElement], _ i: Int, _ j: Int) -> Bool {
        let bi = pe[i].box, bj = pe[j].box
        let xmin = min(bi.l, bj.l) - 1.0, xmax = max(bi.r, bj.r) + 1.0, ymin = bj.t, ymax = bi.b
        for w in 0..<pe.count where w != i && w != j {
            let bw = pe[w].box
            // candidato dell'R-tree sul rettangolo (xmin, ymin, xmax, ymax)
            if !(bw.r >= xmin && bw.l <= xmax && bw.t >= ymin && bw.b <= ymax) { continue }
            if (bi.overlapsHorizontally(bw) || bj.overlapsHorizontally(bw)) && bi.isStrictlyAbove(bw) && bw.isStrictlyAbove(bj) { return true }
        }
        return false
    }

    /// Replica fedele, compreso il comportamento reale del codice docling (la dilatazione viene applicata sull'elemento
    /// prima del controllo di sovrapposizione, che quindi non la annulla).
    func doHorizontalDilation(_ pe: [PageElement], _ s: State) -> [PageElement] {
        var dil = pe
        let th = pe.isEmpty ? 0.0 : horizontalDilationThresholdNorm * pe[0].pageW
        for i in 0..<dil.count {
            var x0 = dil[i].box.l, x1 = dil[i].box.r
            if let u = s.up[i].first {
                let up = pe[u].box
                let x0d = min(x0, up.l), x1d = max(x1, up.r)
                if (x0 - x0d) > th || (x1d - x1) > th { continue }
                x0 = x0d; x1 = x1d
            }
            if let d = s.dn[i].first {
                let dn = pe[d].box
                let x0d = min(x0, dn.l), x1d = max(x1, dn.r)
                if (x0 - x0d) > th || (x1d - x1) > th { continue }
                x0 = x0d; x1 = x1d
            }
            dil[i].box.l = x0; dil[i].box.r = x1
        }
        return dil
    }

    func findHeads(_ pe: [PageElement], _ s: inout State) {
        var heads: [PageElement] = []
        for (k, v) in s.up.enumerated() where v.isEmpty { heads.append(pe[k]) }
        heads = stableSorted(heads) { $0.lt($1) }
        var idx: [Int: Int] = [:]; for (k, e) in pe.enumerated() { idx[e.cid] = k }
        s.heads = heads.map { idx[$0.cid]! }
    }

    func sortUDMaps(_ pe: [PageElement], _ s: inout State) {
        var idx: [Int: Int] = [:]; for (k, e) in pe.enumerated() { idx[e.cid] = k }
        for i in 0..<s.dn.count {
            let children = stableSorted(s.dn[i].map { pe[$0] }) { $0.lt($1) }
            s.dn[i] = children.map { idx[$0.cid]! }
        }
    }

    func findOrder(_ pe: [PageElement], _ s: inout State) -> [Int] {
        var order: [Int] = []; var visited = Array(repeating: false, count: pe.count)
        for j in s.heads where !visited[j] {
            order.append(j); visited[j] = true
            dfsDown(j, &order, &visited, s)
        }
        if order.count != pe.count {
            FileHandle.standardError.write("ordine: visitati \(order.count) su \(pe.count)\n".data(using: .utf8)!)
            for k in 0..<pe.count where !visited[k] { order.append(k) }
        }
        return order
    }
    func dfsUp(_ j: Int, _ visited: [Bool], _ s: State) -> Int {
        var k = j
        while true {
            var found = false
            for ind in s.up[k] where !visited[ind] { k = ind; found = true; break }
            if !found { return k }
        }
    }
    func dfsDown(_ j: Int, _ order: inout [Int], _ visited: inout [Bool], _ s: State) {
        var stack: [([Int], Int)] = [(s.dn[j], 0)]
        while let (inds, offset) = stack.last {
            var found = false
            if offset < inds.count {
                for (newOffset, i) in inds[offset...].enumerated() {
                    let k = dfsUp(i, visited, s)
                    if !visited[k] {
                        order.append(k); visited[k] = true
                        stack[stack.count - 1] = (inds, newOffset + 1)
                        stack.append((s.dn[k], 0)); found = true; break
                    }
                }
            }
            if !found { stack.removeLast() }
        }
    }

    /// predict_merges: fusione di TEXT consecutivi spezzati fra colonne/pagine (regex sul testo).
    func predictMerges(_ sorted: [PageElement]) -> [Int: [Int]] {
        var merges: [Int: [Int]] = [:]
        let skip: Set<String> = ["page_header", "page_footer", "table", "picture", "caption", "footnote"]
        let re1 = try! NSRegularExpression(pattern: "^.+([a-z,\\-\\u00AD])(\\s*)$", options: [.dotMatchesLineSeparators])
        let re2 = try! NSRegularExpression(pattern: "^(\\s*[a-zA-Z\\u00C0-\\u024F])(.+)$", options: [.dotMatchesLineSeparators])
        func full(_ re: NSRegularExpression, _ s: String) -> Bool { re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil }
        var curr = -1
        for (ind, elem) in sorted.enumerated() {
            if ind <= curr { continue }
            if elem.label == "text" {
                var list: [Int] = []; var check = ind
                while true {
                    var p1 = check + 1
                    while p1 < sorted.count && skip.contains(sorted[p1].label) { p1 += 1 }
                    if p1 < sorted.count && sorted[p1].label == elem.label && (elem.pageNo != sorted[p1].pageNo || elem.box.isStrictlyLeftOf(sorted[p1].box)) {
                        if full(re1, sorted[check].text) && full(re2, sorted[p1].text) { list.append(sorted[p1].cid); curr = p1; check = p1 } else { break }
                    } else { break }
                }
                if !list.isEmpty { merges[elem.cid] = list }
            }
        }
        return merges
    }
}

extension ReadingOrderPredictor {
    /// Porto di `predict_to_captions` + `_find_to_captions` (docling-ibm-models 3.13.3): sugli elementi di UNA
    /// pagina già in ordine di lettura, associa a ogni tabella/figura/codice al più una didascalia adiacente
    /// nell'ordine. Ritorna `cid dell'elemento → [cid della didascalia]`. Stesse regole del Python: prima le
    /// didascalie con un solo lato occupato, poi la rimozione dei già assegnati, poi il secondo giro, infine
    /// `_remove_overlapping_indexes` (per chiave crescente, la didascalia più vicina per cid non ancora usata).
    func predictToCaptions(_ pageElements: [PageElement]) -> [Int: [Int]] {
        let targetLabels: Set<String> = ["table", "picture", "code"]
        var fromCaptions: [Int: ([Int], [Int])] = [:]
        var captionOrder: [Int] = []   // ordine d'inserimento del dict Python
        for e in pageElements where e.label == "caption" {
            fromCaptions[e.cid] = ([], []); captionOrder.append(e.cid)
        }
        for (ind, e) in pageElements.enumerated() where e.label == "caption" {
            var m1 = ind - 1
            while m1 >= 0 && targetLabels.contains(pageElements[m1].label) { fromCaptions[e.cid]!.0.append(pageElements[m1].cid); m1 -= 1 }
            var p1 = ind + 1
            while p1 < pageElements.count && targetLabels.contains(pageElements[p1].label) { fromCaptions[e.cid]!.1.append(pageElements[p1].cid); p1 += 1 }
        }
        var toCaptions: [Int: [Int]] = [:]
        var toCaptionsOrder: [Int] = []
        func put(_ j: Int, _ i: Int, overwrite: Bool) {
            if toCaptions[j] == nil { toCaptions[j] = [i]; toCaptionsOrder.append(j) }
            else if overwrite { toCaptions[j] = [i] }
            else if !toCaptions[j]!.contains(i) { toCaptions[j]!.append(i) }
        }
        var assigned = Set<Int>()
        for ci in captionOrder {
            let (pre, post) = fromCaptions[ci]!
            if pre.isEmpty && !post.isEmpty { for cj in post { put(cj, ci, overwrite: false); assigned.insert(cj) } }
            if !pre.isEmpty && post.isEmpty { for cj in pre { put(cj, ci, overwrite: false); assigned.insert(cj) } }
        }
        for ci in captionOrder {
            fromCaptions[ci]!.0.removeAll { assigned.contains($0) }
            fromCaptions[ci]!.1.removeAll { assigned.contains($0) }
        }
        for ci in captionOrder {
            let (pre, post) = fromCaptions[ci]!
            if pre.isEmpty && !post.isEmpty { for cj in post { put(cj, ci, overwrite: true); assigned.insert(cj) } }
            if !pre.isEmpty && post.isEmpty { for cj in pre { put(cj, ci, overwrite: true); assigned.insert(cj) } }
        }
        // _remove_overlapping_indexes: chiavi in ordine crescente; per ognuna la didascalia più vicina
        // (|v − chiave|, a parità l'ordine stabile della lista) non ancora usata.
        var used = Set<Int>(); var result: [Int: [Int]] = [:]
        for key in toCaptions.keys.sorted() {
            let values = stableSorted(toCaptions[key]!) { abs($0 - key) < abs($1 - key) }
            if let v = values.first(where: { !used.contains($0) }) { result[key] = [v]; used.insert(v) }
        }
        _ = toCaptionsOrder
        return result
    }
}

/// Solo per le reti: ordine del porto Swift su elementi pre-ordine dati dall'esterno (gli `elements_pre_ro`
/// che docling stesso produce), per verificare che il porto resti identico a docling. Rettangoli in punti,
/// origine alto-sinistra. Ritorna i `cid` nell'ordine di lettura.
public func _readingOrderCheck(elements: [(cid: Int, label: String, pageNo: Int, l: Double, t: Double, r: Double, b: Double)], pageWidth W: Double, pageHeight H: Double) -> [Int] {
    let elems = elements.map { e in
        PageElement(cid: e.cid, label: e.label, text: "", pageNo: e.pageNo, pageW: W, pageH: H,
                    box: ROBox(topLeft: LayoutBox(l: e.l, t: e.t, r: e.r, b: e.b), pageHeight: H))
    }
    return ReadingOrderPredictor().predictReadingOrder(elems).map { $0.cid }
}
