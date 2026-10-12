//
//  LayoutPostprocessor.swift
//  ScaboPageStructure
//
//  Porto di `docling.utils.layout_postprocessor.LayoutPostprocessor` (docling 2.103, MIT,
//  © 2024 International Business Machines — vedi LICENSES/docling-MIT.txt). Porto fedele dal prototipo del
//  laboratorio «struttura nativa» (2026-10-12): stesso algoritmo, stesse soglie, stessi ordinamenti stabili.
//  Unica differenza dal prototipo: il tipo del rettangolo si chiama `LayoutBox` (era `BBox`), per non
//  collidere con `ScaboCore.BBox` nei file dell'app che importano entrambi i moduli.
//

import Foundation

/// Cluster di layout (come docling.datamodel.base_models.Cluster).
final class Cluster {
    let id: Int
    var label: String
    var confidence: Double
    var bbox: LayoutBox
    var cells: [Cell] = []
    var children: [Cluster] = []
    init(id: Int, label: String, confidence: Double, bbox: LayoutBox) { self.id = id; self.label = label; self.confidence = confidence; self.bbox = bbox }
    var minCellIndex: Int { cells.map { $0.index }.min() ?? Int.max }
}

/// Indice spaziale: replica di SpatialClusterIndex (R-tree + alberi di intervalli), costruito sui rettangoli ORIGINALI.
struct SpatialIndex {
    var boxes: [Int: LayoutBox] = [:]
    init(_ clusters: [Cluster]) { for c in clusters { boxes[c.id] = c.bbox } }
    func findCandidates(_ bb: LayoutBox) -> Set<Int> {
        var out = Set<Int>()
        for (id, o) in boxes {
            // intersezione dell'R-tree (rettangoli chiusi: anche il solo contatto)
            if !(o.r < bb.l || bb.r < o.l || o.b < bb.t || bb.b < o.t) { out.insert(id) }
            // intervalli x contenenti l o r; intervalli y contenenti t o b
            if (o.l <= bb.l && bb.l <= o.r) || (o.l <= bb.r && bb.r <= o.r) { out.insert(id) }
            if (o.t <= bb.t && bb.t <= o.b) || (o.t <= bb.b && bb.b <= o.b) { out.insert(id) }
        }
        return out
    }
    static func checkOverlap(_ a: LayoutBox, _ b: LayoutBox, overlap: Double, containment: Double) -> Bool {
        if a.area() <= 0 || b.area() <= 0 { return false }
        return a.iou(b) > overlap || a.intersectionOverSelf(b) > containment || b.intersectionOverSelf(a) > containment
    }
}

struct UnionFind {
    var parent: [Int: Int] = [:]; var rank: [Int: Int] = [:]; var order: [Int] = []
    init(_ ids: [Int]) { for i in ids { parent[i] = i; rank[i] = 0; order.append(i) } }
    mutating func find(_ x: Int) -> Int { if parent[x] != x { parent[x] = find(parent[x]!) }; return parent[x]! }
    mutating func union(_ x: Int, _ y: Int) {
        let rx = find(x), ry = find(y); if rx == ry { return }
        if rank[rx]! > rank[ry]! { parent[ry] = rx } else if rank[rx]! < rank[ry]! { parent[rx] = ry } else { parent[ry] = rx; rank[rx]! += 1 }
    }
    mutating func groups() -> [[Int]] {
        var g: [Int: [Int]] = [:]; var keys: [Int] = []
        for e in order { let r = find(e); if g[r] == nil { g[r] = []; keys.append(r) }; g[r]!.append(e) }
        return keys.map { g[$0]! }
    }
}

/// Porto di docling.utils.layout_postprocessor.LayoutPostprocessor (opzioni predefinite: create_orphan_clusters=true,
/// keep_empty_clusters=false, skip_cell_assignment=false).
struct LayoutPostprocessor {
    let pageW: Double, pageH: Double
    let cells: [Cell]
    let allClusters: [Cluster]
    var regular: [Cluster]; var special: [Cluster]
    let regularIndex: SpatialIndex, pictureIndex: SpatialIndex, wrapperIndex: SpatialIndex
    static let OVERLAP_PARAMS: [String: (area: Double, conf: Double)] = ["regular": (1.3, 0.05), "picture": (2.0, 0.3), "wrapper": (2.0, 0.2)]

    init(pageW: Double, pageH: Double, cells: [Cell], clusters: [Cluster]) {
        self.pageW = pageW; self.pageH = pageH; self.cells = cells; self.allClusters = clusters
        regular = clusters.filter { !SPECIAL_TYPES.contains($0.label) }
        special = clusters.filter { SPECIAL_TYPES.contains($0.label) }
        regularIndex = SpatialIndex(regular)
        pictureIndex = SpatialIndex(special.filter { $0.label == "picture" })
        wrapperIndex = SpatialIndex(special.filter { WRAPPER_TYPES.contains($0.label) })
    }

    mutating func postprocess() -> [Cluster] {
        regular = processRegular()
        special = processSpecial()
        var contained = Set<Int>()
        for w in special where SPECIAL_TYPES.contains(w.label) { for ch in w.children { contained.insert(ch.id) } }
        regular = regular.filter { !contained.contains($0.id) }
        let final = sortClusters(regular + special)
        for c in final { c.cells = sortCells(c.cells); for ch in c.children { ch.cells = sortCells(ch.cells) } }
        return final
    }

    func sortCells(_ cs: [Cell]) -> [Cell] { stableSorted(cs) { $0.index < $1.index } }
    func sortClusters(_ cs: [Cluster]) -> [Cluster] {
        stableSorted(cs) { a, b in
            let ka = (a.minCellIndex, a.bbox.t, a.bbox.l), kb = (b.minCellIndex, b.bbox.t, b.bbox.l)
            return ka < kb
        }
    }

    mutating func processRegular() -> [Cluster] {
        var clusters = regular.filter { $0.confidence >= (CONFIDENCE_THRESHOLDS[$0.label] ?? 0.5) }
        for c in clusters { if let m = LABEL_REMAPPING[c.label] { c.label = m } }
        clusters = assignCells(clusters)
        clusters = clusters.filter { !$0.cells.isEmpty || $0.label == "formula" }
        let unassigned = findUnassigned(clusters)
        if !unassigned.isEmpty {
            let nextId = (allClusters.map { $0.id }.max() ?? 0) + 1
            for (i, cell) in unassigned.enumerated() {
                let c = Cluster(id: nextId + i, label: "text", confidence: cell.confidence, bbox: cell.rect); c.cells = [cell]
                clusters.append(c)
            }
        }
        var prev = clusters.count + 1
        for _ in 0..<3 {
            if prev == clusters.count { break }
            prev = clusters.count
            clusters = adjustBBoxes(clusters)
            clusters = removeOverlapping(clusters, kind: "regular")
        }
        return clusters
    }

    mutating func processSpecial() -> [Cluster] {
        var sp = special.filter { $0.confidence >= (CONFIDENCE_THRESHOLDS[$0.label] ?? 0.5) }
        sp = handleCrossTypeOverlaps(sp)
        let pageArea = pageW * pageH
        if pageArea > 0 { sp = sp.filter { !($0.label == "picture" && $0.bbox.area() / pageArea > 0.90) } }
        for s in sp {
            var contained: [Cluster] = []
            for r in regular where r.bbox.intersectionOverSelf(s.bbox) > 0.8 { contained.append(r) }
            if !contained.isEmpty {
                contained = sortClusters(contained)
                s.children = contained
                if s.label == "form" || s.label == "key_value_region" {
                    s.bbox = LayoutBox(l: contained.map { $0.bbox.l }.min()!, t: contained.map { $0.bbox.t }.min()!, r: contained.map { $0.bbox.r }.max()!, b: contained.map { $0.bbox.b }.max()!)
                }
                var all: [Cell] = []; for ch in contained { all.append(contentsOf: ch.cells) }
                s.cells = sortCells(dedupe(all))
            }
        }
        let pictures = removeOverlapping(sp.filter { $0.label == "picture" }, kind: "picture")
        let wrappers = removeOverlapping(sp.filter { WRAPPER_TYPES.contains($0.label) }, kind: "wrapper")
        return pictures + wrappers
    }

    func handleCrossTypeOverlaps(_ sp: [Cluster]) -> [Cluster] {
        var toRemove = Set<Int>()
        for w in sp where WRAPPER_TYPES.contains(w.label) {
            for r in regular where r.label == "table" {
                let overlap = w.bbox.intersectionOverSelf(r.bbox); let confDiff = w.confidence - r.confidence
                if overlap > 0.9 && confDiff < 0.1 { toRemove.insert(w.id); break }
            }
        }
        let tables = sp.filter { $0.label == "table" }
        for p in sp where p.label == "picture" {
            for t in tables where p.bbox.iou(t.bbox) > 0.8 { toRemove.insert(p.id); break }
        }
        return sp.filter { !toRemove.contains($0.id) }
    }

    func shouldPrefer(_ cand: Cluster, over other: Cluster, params: (area: Double, conf: Double)) -> Bool {
        if cand.label == "list_item" && other.label == "text" {
            let ratio = cand.bbox.area() / other.bbox.area()
            if abs(1 - ratio) < 0.2 { return true }
        }
        if cand.label == "code" {
            if other.bbox.intersectionOverSelf(cand.bbox) > 0.8 { return true }
        }
        let ratio = cand.bbox.area() / other.bbox.area(); let confDiff = other.confidence - cand.confidence
        if ratio <= params.area && confDiff > params.conf { return false }
        return true
    }

    func selectBest(_ group: [Cluster], params: (area: Double, conf: Double)) -> Cluster {
        var best: Cluster? = nil
        for cand in group {
            var ok = true
            for other in group where other !== cand { if !shouldPrefer(cand, over: other, params: params) { ok = false; break } }
            if ok {
                if best == nil { best = cand }
                else if cand.bbox.area() > best!.bbox.area() && best!.confidence - cand.confidence <= params.conf { best = cand }
            }
        }
        return best ?? group[0]
    }

    func removeOverlapping(_ clusters: [Cluster], kind: String, overlap: Double = 0.8, containment: Double = 0.8) -> [Cluster] {
        if clusters.isEmpty { return [] }
        let index = kind == "regular" ? regularIndex : (kind == "picture" ? pictureIndex : wrapperIndex)
        var valid: [Int: Cluster] = [:]; for c in clusters { valid[c.id] = c }
        var uf = UnionFind(clusters.map { $0.id })
        let params = LayoutPostprocessor.OVERLAP_PARAMS[kind]!
        for c in clusters {
            var cands = index.findCandidates(c.bbox); cands = cands.intersection(Set(valid.keys)); cands.remove(c.id)
            for oid in cands.sorted() {
                if SpatialIndex.checkOverlap(c.bbox, valid[oid]!.bbox, overlap: overlap, containment: containment) { uf.union(c.id, oid) }
            }
        }
        var result: [Cluster] = []
        for group in uf.groups() {
            if group.count == 1 { result.append(valid[group[0]]!); continue }
            let gc = group.map { valid[$0]! }
            let best = selectBest(gc, params: params)
            for c in gc where c !== best { best.cells.append(contentsOf: c.cells) }
            best.cells = sortCells(dedupe(best.cells))
            result.append(best)
        }
        return result
    }

    func dedupe(_ cs: [Cell]) -> [Cell] { var seen = Set<Int>(); var out: [Cell] = []; for c in cs where !seen.contains(c.index) { seen.insert(c.index); out.append(c) }; return out }

    func assignCells(_ clusters: [Cluster], minOverlap: Double = 0.2) -> [Cluster] {
        for c in clusters { c.cells = [] }
        for cell in cells {
            if cell.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { continue }
            var bestOverlap = minOverlap; var best: Cluster? = nil
            for c in clusters {
                if cell.rect.area() <= 0 { continue }
                let o = cell.rect.intersectionOverSelf(c.bbox)
                if o > bestOverlap { bestOverlap = o; best = c }
            }
            best?.cells.append(cell)
        }
        for c in clusters { c.cells = dedupe(c.cells) }
        return clusters
    }
    func findUnassigned(_ clusters: [Cluster]) -> [Cell] {
        var assigned = Set<Int>(); for c in clusters { for cell in c.cells { assigned.insert(cell.index) } }
        return cells.filter { !assigned.contains($0.index) && !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
    func adjustBBoxes(_ clusters: [Cluster]) -> [Cluster] {
        for c in clusters {
            if c.cells.isEmpty { continue }
            let cb = LayoutBox(l: c.cells.map { $0.rect.l }.min()!, t: c.cells.map { $0.rect.t }.min()!, r: c.cells.map { $0.rect.r }.max()!, b: c.cells.map { $0.rect.b }.max()!)
            c.bbox = c.label == "table" ? c.bbox.union(cb) : cb
        }
        return clusters
    }
}

/// Ordinamento stabile (come sorted() di Python) con un comparatore "minore di".
func stableSorted<T>(_ xs: [T], by lt: (T, T) -> Bool) -> [T] {
    // merge sort stabile
    if xs.count <= 1 { return xs }
    let mid = xs.count / 2
    let a = stableSorted(Array(xs[0..<mid]), by: lt), b = stableSorted(Array(xs[mid...]), by: lt)
    var out: [T] = []; out.reserveCapacity(xs.count); var i = 0, j = 0
    while i < a.count && j < b.count { if lt(b[j], a[i]) { out.append(b[j]); j += 1 } else { out.append(a[i]); i += 1 } }
    out.append(contentsOf: a[i...]); out.append(contentsOf: b[j...]); return out
}
