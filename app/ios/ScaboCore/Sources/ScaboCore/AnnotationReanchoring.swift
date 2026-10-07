//
//  AnnotationReanchoring.swift
//  ScaboCore
//
//  Il RIANCORAGGIO delle annotazioni dopo una rielaborazione (docs/ANCORE_ANNOTAZIONI.md): per ogni
//  segnalibro, sottolineatura e per la posizione di lettura risolve l'ancora per contenuto nel flusso
//  nuovo (`ContentAnchorIndex`) e produce lo stato nuovo più un referto con i conteggi. Pura: nessun
//  accesso allo store, così la stessa funzione gira nell'app e nella rete sulle annotazioni del banco.
//
//  Regole (§ 12.14 — mai un salto silenzioso):
//  - RICOLLOCATA: ancora risolta sopra soglia → posizione corrente aggiornata e ancora RICONIATA sul
//    segmento ritrovato (da ora descrive il contenuto verificato);
//  - ORFANA: sotto soglia o ambigua → resta in lista, marcata, con posizione corrente invariata; il
//    salto a un'orfana porta alla pagina d'origine, dichiarandolo;
//  - SENZA ANCORA (creata prima delle ancore e mai riaperta dalla cache): orfana. Ricollocarla per id
//    sarebbe esattamente il salto silenzioso che si vuole escludere;
//  - posizione di lettura: ricollocata per contenuto; se orfana, ripiega sul primo segmento della
//    pagina d'origine (dichiarandolo `approximate`), altrimenti sull'indice tagliato alla lunghezza.
//

import Foundation

public struct ReanchorReport: Codable, Equatable, Sendable {
    public var bookmarksRelocated = 0
    public var bookmarksOrphaned = 0
    public var bookmarksWithoutAnchor = 0
    public var underlinesRelocated = 0
    public var underlinesOrphaned = 0
    public var underlinesWithoutAnchor = 0
    /// Livello di riscontro della posizione di lettura; `nil` se non c'era un'ancora.
    public var positionLevel: AnchorMatchLevel?
    public var positionByPage = false
    /// Una riga tecnica per annotazione (id, livello, ragione): per il referto e la rete, mai testo.
    public var details: [String] = []

    public init() {}

    public var orphanCount: Int { bookmarksOrphaned + bookmarksWithoutAnchor + underlinesOrphaned + underlinesWithoutAnchor }
    public var relocatedCount: Int { bookmarksRelocated + underlinesRelocated }
}

public struct ReanchoredAnnotations: Equatable, Sendable {
    public var bookmarks: [Bookmark]
    public var underlines: [Underline]
    public var readingPosition: Int
    public var readingAnchor: ContentAnchor?
    public var readingPositionIsApproximate: Bool
    public var report: ReanchorReport
}

public enum AnnotationReanchoring {

    /// Riancora tutto nel flusso descritto da `index`.
    public static func reanchor(
        bookmarks: [Bookmark], underlines: [Underline], readingPosition: Int, readingAnchor: ContentAnchor?,
        in index: ContentAnchorIndex
    ) -> ReanchoredAnnotations {
        var report = ReanchorReport()
        let segments = index.segments

        var newBookmarks: [Bookmark] = []
        for var b in bookmarks {
            guard let anchor = b.anchor else {
                report.bookmarksWithoutAnchor += 1
                report.details.append("bookmark \(b.id): senza ancora → orfano")
                b.isOrphan = true
                newBookmarks.append(b)
                continue
            }
            let r = index.resolve(anchor)
            if let i = r.index, r.confidence >= ContentAnchorIndex.relocationThreshold {
                b.anchorSegmentId = segments[i].id
                b.orderIndexHint = i
                b.originalPage = segments[i].sourcePage ?? b.originalPage
                b.anchor = index.anchor(forIndex: i) ?? anchor
                b.isOrphan = nil
                report.bookmarksRelocated += 1
                report.details.append("bookmark \(b.id): \(r.level.rawValue) → \(segments[i].id) (\(r.reason))")
            } else {
                b.isOrphan = true
                report.bookmarksOrphaned += 1
                report.details.append("bookmark \(b.id): orfano (\(r.reason))")
            }
            newBookmarks.append(b)
        }

        var newUnderlines: [Underline] = []
        for var u in underlines {
            if u.spans.contains(where: { $0.anchor == nil }) {
                report.underlinesWithoutAnchor += 1
                report.details.append("underline \(u.id): span senza ancora → orfana")
                u.isOrphan = true
                newUnderlines.append(u)
                continue
            }
            var spans: [UnderlineSpan] = []
            var failed: String?
            for span in u.spans {
                guard let q = span.anchor, let r = index.resolve(q) else {
                    failed = "citazione non ritrovata o ambigua"; break
                }
                let newAnchor = index.quoteAnchor(forIndex: r.segmentIndex, startWord: r.startWord, endWord: r.endWord)
                spans.append(UnderlineSpan(segmentId: segments[r.segmentIndex].id, startWord: r.startWord,
                                           endWord: r.endWord, anchor: newAnchor ?? q))
            }
            if let failed {
                u.isOrphan = true
                report.underlinesOrphaned += 1
                report.details.append("underline \(u.id): orfana (\(failed))")
            } else {
                u.spans = spans
                u.isOrphan = nil
                report.underlinesRelocated += 1
                report.details.append("underline \(u.id): ricollocata su \(spans.map { $0.segmentId }.joined(separator: ","))")
            }
            newUnderlines.append(u)
        }

        var position = min(max(0, readingPosition), max(0, segments.count - 1))
        var newReadingAnchor = readingAnchor
        var approximate = false
        if let anchor = readingAnchor {
            let r = index.resolve(anchor)
            report.positionLevel = r.level
            if let i = r.index, r.confidence >= ContentAnchorIndex.relocationThreshold {
                position = i
                newReadingAnchor = index.anchor(forIndex: i) ?? anchor
            } else if let page = anchor.sourcePage, let i = segments.firstIndex(where: { $0.sourcePage == page }) {
                position = i
                approximate = true
                report.positionByPage = true
                newReadingAnchor = index.anchor(forIndex: i) ?? anchor
            } else {
                approximate = true
                newReadingAnchor = index.anchor(forIndex: position) ?? anchor
            }
            report.details.append("posizione: \(r.level.rawValue) → \(position)\(approximate ? " (per pagina)" : "") (\(r.reason))")
        } else if segments.indices.contains(position) {
            // Nessuna ancora (posizione mai salvata dopo le ancore): l'indice tagliato è dichiarato approssimato.
            approximate = readingPosition > 0
            newReadingAnchor = index.anchor(forIndex: position)
            report.details.append("posizione: senza ancora → indice \(position)\(approximate ? " (approssimata)" : "")")
        }

        return ReanchoredAnnotations(
            bookmarks: newBookmarks, underlines: newUnderlines, readingPosition: position,
            readingAnchor: newReadingAnchor, readingPositionIsApproximate: approximate, report: report)
    }

    /// Conia le ancore MANCANTI a contenuto fermo (apertura dalla cache o subito dopo l'elaborazione
    /// che ha prodotto questi stessi segmenti): gli id correnti sono ancora veri, quindi l'ancora si
    /// prende dal segmento a cui l'annotazione punta. È la migrazione, gratuita, delle annotazioni
    /// create prima delle ancore. Ritorna lo stato (eventualmente) aggiornato e quante ancore ha coniato.
    public static func mintMissingAnchors(
        bookmarks: [Bookmark], underlines: [Underline], readingPosition: Int, readingAnchor: ContentAnchor?,
        in index: ContentAnchorIndex
    ) -> (bookmarks: [Bookmark], underlines: [Underline], readingAnchor: ContentAnchor?, minted: Int) {
        var idToIndex: [String: Int] = [:]
        for (i, s) in index.segments.enumerated() where idToIndex[s.id] == nil { idToIndex[s.id] = i }
        var minted = 0
        let newBookmarks = bookmarks.map { b -> Bookmark in
            guard b.anchor == nil, let i = idToIndex[b.anchorSegmentId], let a = index.anchor(forIndex: i) else { return b }
            var c = b; c.anchor = a; minted += 1; return c
        }
        let newUnderlines = underlines.map { u -> Underline in
            var c = u
            c.spans = u.spans.map { span in
                guard span.anchor == nil, let i = idToIndex[span.segmentId],
                      let q = index.quoteAnchor(forIndex: i, startWord: span.startWord, endWord: span.endWord)
                else { return span }
                var s = span; s.anchor = q; minted += 1; return s
            }
            return c
        }
        var position = readingAnchor
        if position == nil, index.segments.indices.contains(readingPosition) {
            position = index.anchor(forIndex: readingPosition); minted += 1
        }
        return (newBookmarks, newUnderlines, position, minted)
    }
}
