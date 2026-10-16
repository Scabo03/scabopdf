//
//  AnnotationMerge.swift
//  ScaboCore
//
//  LA FUSIONE DELLE ANNOTAZIONI che arrivano con un pacchetto dal Mac (giro «costruzione della linea Mac», 2026-10-16;
//  LAYER2_PRODUCT_DECISIONS § 12.12). Pura: nessun accesso allo store; i tag li mappa per nome chi chiama.
//
//  LA REGOLA (decisione del giro, motivata nel § 12.12). Tutto passa dalle ancore per contenuto, mai dagli id:
//
//  1. Prima si riancora: le annotazioni dell'iPad (fatte sulla lettura di prima) e quelle del pacchetto (fatte sulla
//     lettura del Mac) si risolvono per contenuto nella lettura NUOVA, quella appena adottata (`AnnotationReanchoring`).
//  2. Segnalibri. Un segnalibro del pacchetto è lo STESSO di uno dell'iPad se ha lo stesso id (è già passato di qui), o se
//     marca lo stesso elemento e i nomi non si contraddicono (uguali, o uno dei due senza nome): allora resta uno solo,
//     quello dell'iPad, con l'UNIONE dei tag e il nome del pacchetto solo se l'iPad non ne aveva. Due segnalibri sullo
//     stesso elemento con due nomi diversi NON sono doppioni: restano entrambi (nessun nome dell'utente si perde).
//  3. Sottolineature. La regola di non-sovrapposizione (§ 6.3) vale anche qui: una sottolineatura del pacchetto che copre
//     esattamente le stesse parole di una dell'iPad è un doppione (resta quella dell'iPad); una che le si SOVRAPPONE
//     diventa con lei una sola, l'UNIONE delle due estensioni (nessuna parola sottolineata si perde, nessuna parola sta
//     in due sottolineature); una disgiunta si aggiunge.
//  4. Ciò che non si ritrova con sicurezza (ancora orfana) NON si scarta mai: entra dichiarato «da ricollocare», come
//     dopo una rielaborazione (§ 12.14). Un'orfana non si fonde per posizione: non si sa dove sia.
//  5. La posizione di lettura resta quella dell'iPad (è dove l'utente è arrivato su questo dispositivo).
//
//  Perché questa regola e non «vince il più recente» o «vince il Mac»: le annotazioni non portano un orologio di modifica,
//  e una scelta per provenienza butterebbe via lavoro dell'utente. L'unione per contenuto è l'unica che non perde nulla e
//  non duplica, e si appoggia alle stesse ancore già provate dalla rete sulle annotazioni (zero ricollocazioni sbagliate).
//

import Foundation

public struct AnnotationMergeReport: Codable, Equatable, Sendable {
    /// Segnalibri del pacchetto aggiunti, fusi con uno dell'iPad, entrati «da ricollocare».
    public var bookmarksAdded = 0
    public var bookmarksMerged = 0
    public var bookmarksOrphan = 0
    /// Sottolineature del pacchetto aggiunte, doppioni, unite a una sovrapposta, entrate «da ricollocare».
    public var underlinesAdded = 0
    public var underlinesDuplicate = 0
    public var underlinesUnited = 0
    public var underlinesOrphan = 0
    /// Esiti del riancoraggio delle annotazioni che l'iPad già aveva.
    public var localReport = ReanchorReport()

    public init() {}

    public var incomingTotal: Int {
        bookmarksAdded + bookmarksMerged + bookmarksOrphan + underlinesAdded + underlinesDuplicate + underlinesUnited + underlinesOrphan
    }
}

public struct MergedAnnotations: Equatable, Sendable {
    public var bookmarks: [Bookmark]
    public var underlines: [Underline]
    public var readingPosition: Int
    public var readingAnchor: ContentAnchor?
    public var readingPositionIsApproximate: Bool
    public var report: AnnotationMergeReport
}

public enum AnnotationMerge {

    /// Fonde le annotazioni dell'iPad (`local…`) e quelle del pacchetto (`incoming…`, con i tag già mappati sugli id
    /// dell'iPad) nella lettura `index` appena adottata.
    public static func merge(
        localBookmarks: [Bookmark], localUnderlines: [Underline], readingPosition: Int, readingAnchor: ContentAnchor?,
        incomingBookmarks: [Bookmark], incomingUnderlines: [Underline], in index: ContentAnchorIndex
    ) -> MergedAnnotations {
        var report = AnnotationMergeReport()
        let local = AnnotationReanchoring.reanchor(
            bookmarks: localBookmarks, underlines: localUnderlines, readingPosition: readingPosition,
            readingAnchor: readingAnchor, in: index)
        report.localReport = local.report
        let incoming = AnnotationReanchoring.reanchor(
            bookmarks: incomingBookmarks, underlines: incomingUnderlines, readingPosition: 0, readingAnchor: nil, in: index)

        // ── Segnalibri ────────────────────────────────────────────────────────────────────────────────────────────
        var bookmarks = local.bookmarks
        for b in incoming.bookmarks {
            if let i = bookmarks.firstIndex(where: { $0.id == b.id }) ?? sameBookmark(b, in: bookmarks) {
                var keep = bookmarks[i]
                for t in b.tagIds where !keep.tagIds.contains(t) { keep.tagIds.append(t) }
                if isBlank(keep.name), !isBlank(b.name) { keep.name = b.name }
                bookmarks[i] = keep
                report.bookmarksMerged += 1
            } else {
                bookmarks.append(b)
                if b.isOrphan == true { report.bookmarksOrphan += 1 } else { report.bookmarksAdded += 1 }
            }
        }

        // ── Sottolineature ────────────────────────────────────────────────────────────────────────────────────────
        let order = Dictionary(index.segments.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { a, _ in a })
        var underlines = local.underlines
        for u in incoming.underlines {
            if u.isOrphan == true || !isPlaced(u, order) {
                if underlines.contains(where: { $0.id == u.id }) { report.underlinesDuplicate += 1; continue }
                var o = u
                o.isOrphan = true
                underlines.append(o)
                report.underlinesOrphan += 1
                continue
            }
            if underlines.contains(where: { $0.isOrphan != true && sameCoverage($0, u) }) {
                report.underlinesDuplicate += 1
                continue
            }
            let overlapping = underlines.indices.filter { underlines[$0].isOrphan != true && isPlaced(underlines[$0], order)
                && overlaps(underlines[$0], u, order) }
            if overlapping.isEmpty {
                underlines.append(u)
                report.underlinesAdded += 1
                continue
            }
            // Unione: dalla prima parola più in alto all'ultima più in basso, fra la nuova e tutte quelle che tocca.
            let group = overlapping.map { underlines[$0] } + [u]
            guard let united = union(group, order: order, index: index, keepId: underlines[overlapping[0]].id,
                                     createdAt: underlines[overlapping[0]].createdAt)
            else {
                // Non ricomponibile (un'ancora di citazione non si conia): si tiene la nuova come «da ricollocare».
                var o = u
                o.isOrphan = true
                underlines.append(o)
                report.underlinesOrphan += 1
                continue
            }
            for k in overlapping.reversed() { underlines.remove(at: k) }
            underlines.insert(united, at: min(overlapping[0], underlines.count))
            report.underlinesUnited += 1
        }

        return MergedAnnotations(bookmarks: bookmarks, underlines: underlines, readingPosition: local.readingPosition,
                                 readingAnchor: local.readingAnchor, readingPositionIsApproximate: local.readingPositionIsApproximate,
                                 report: report)
    }

    // MARK: Segnalibri

    static func isBlank(_ s: String?) -> Bool { (s ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// Lo stesso elemento (entrambi al loro posto) e nomi che non si contraddicono.
    static func sameBookmark(_ b: Bookmark, in list: [Bookmark]) -> Int? {
        guard b.isOrphan != true else { return nil }
        let name = (b.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return list.firstIndex { x in
            guard x.isOrphan != true, x.anchorSegmentId == b.anchorSegmentId else { return false }
            let xn = (x.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return xn.isEmpty || name.isEmpty || xn == name
        }
    }

    // MARK: Sottolineature

    /// Vero se tutti gli span della sottolineatura stanno su segmenti presenti nella lettura.
    static func isPlaced(_ u: Underline, _ order: [String: Int]) -> Bool {
        !u.spans.isEmpty && u.spans.allSatisfy { order[$0.segmentId] != nil }
    }

    /// Gli estremi (segmento, parola) di una sottolineatura, nell'ordine di lettura.
    static func bounds(_ u: Underline, _ order: [String: Int]) -> (start: (Int, Int), end: (Int, Int))? {
        let pos = u.spans.compactMap { s -> (Int, Int, Int)? in order[s.segmentId].map { ($0, s.startWord, s.endWord) } }
        guard let first = pos.min(by: { ($0.0, $0.1) < ($1.0, $1.1) }), let last = pos.max(by: { ($0.0, $0.2) < ($1.0, $1.2) })
        else { return nil }
        return ((first.0, first.1), (last.0, last.2))
    }

    static func sameCoverage(_ a: Underline, _ b: Underline) -> Bool {
        let key: (Underline) -> [String] = { $0.spans.map { "\($0.segmentId):\($0.startWord)-\($0.endWord)" }.sorted() }
        return key(a) == key(b)
    }

    /// Sovrapposizione: almeno una parola in comune (stesso segmento, intervalli che si toccano).
    static func overlaps(_ a: Underline, _ b: Underline, _ order: [String: Int]) -> Bool {
        for x in a.spans {
            for y in b.spans where x.segmentId == y.segmentId {
                if max(x.startWord, y.startWord) <= min(x.endWord, y.endWord) { return true }
            }
        }
        return false
    }

    /// L'unione di più sottolineature sovrapposte: un'estensione contigua dalla prima parola all'ultima, con le ancore di
    /// citazione coniate sulla lettura (span per segmento come la finestra di selezione: primo segmento dalla parola
    /// d'inizio alla fine, segmenti di mezzo interi, ultimo dall'inizio alla parola di fine). L'anteprima si ricalcola
    /// sull'estensione unita, come la calcola la finestra di selezione (prime dieci parole sottolineate).
    static func union(_ group: [Underline], order: [String: Int], index: ContentAnchorIndex, keepId: String,
                      createdAt: Date) -> Underline? {
        let b = group.compactMap { bounds($0, order) }
        guard b.count == group.count, let start = b.map({ $0.start }).min(by: { $0 < $1 }),
              let end = b.map({ $0.end }).max(by: { $0 < $1 }) else { return nil }
        var spans: [UnderlineSpan] = []
        for seg in start.0...end.0 {
            let words = WordTokenizer.wordRanges(index.segments[seg].text).count
            guard words > 0 else { continue }
            let s = seg == start.0 ? start.1 : 0
            let e = seg == end.0 ? min(end.1, words - 1) : words - 1
            guard s <= e, let q = index.quoteAnchor(forIndex: seg, startWord: s, endWord: e) else { return nil }
            spans.append(UnderlineSpan(segmentId: index.segments[seg].id, startWord: s, endWord: e, anchor: q))
        }
        guard !spans.isEmpty else { return nil }
        return Underline(id: keepId, spans: spans, preview: preview(of: spans, in: index), createdAt: createdAt)
    }

    /// L'anteprima di una sottolineatura: le parole coperte, nell'ordine, ridotte alle prime dieci (la stessa regola della
    /// finestra di selezione dell'app, `UnderlineSelectionViewController.computePreview`).
    static func preview(of spans: [UnderlineSpan], in index: ContentAnchorIndex) -> String {
        let byId = Dictionary(index.segments.map { ($0.id, $0.text) }, uniquingKeysWith: { a, _ in a })
        var pieces: [String] = []
        for span in spans {
            guard let text = byId[span.segmentId] else { continue }
            let words = WordTokenizer.words(text)
            let lo = max(0, span.startWord), hi = min(words.count - 1, span.endWord)
            if lo <= hi { pieces.append(words[lo...hi].joined(separator: " ")) }
        }
        return WordTokenizer.preview(pieces.joined(separator: " "), limit: 10)
    }
}
