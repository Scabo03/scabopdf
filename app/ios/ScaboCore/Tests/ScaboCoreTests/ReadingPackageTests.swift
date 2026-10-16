//
//  ReadingPackageTests.swift
//  ScaboCoreTests
//
//  Il pacchetto della lettura (ReadingPackage.swift) e la fusione delle annotazioni (AnnotationMerge.swift): andata e
//  ritorno identici, intestazione leggibile senza il carico, versioni sconosciute dette in prosa, file danneggiati
//  rifiutati, annotazioni fuse per contenuto senza doppioni e senza perdite. Letture sintetiche con frasi di prova:
//  nessun testo dei volumi.
//

import XCTest
@testable import ScaboCore

final class ReadingPackageTests: XCTestCase {

    static func seg(_ id: String, _ text: String, page: Int = 1, role: String = "BODY") -> ContentSegment {
        ContentSegment(id: id, role: role, text: text, lengthCategory: "", acousticIntro: "", sourcePage: page)
    }

    static let frasi = [
        "Il primo paragrafo di prova parla della brezza che scende dalla collina verso il lago al tramonto.",
        "Il secondo paragrafo di prova descrive il faro acceso sulla scogliera e il vento che piega gli ulivi.",
        "Il terzo paragrafo di prova racconta del mulino sul fiume e delle chiuse aperte di notte per il grano.",
        "Il quarto paragrafo di prova chiude con la neve sui tetti e il silenzio della valle sotto la luna.",
    ]

    static func reading(_ texts: [String] = frasi) -> PackagedReading {
        let segs = texts.enumerated().map { seg("node_\($0.offset)", $0.element, page: $0.offset + 1) }
        return PackagedReading(content: PaginatedContent(pages: [ContentPage(pageNumber: 1, segments: segs)], totalSegments: segs.count),
                               pageMap: ["node_0": 1], doctrineContent: nil, quickConsultTree: nil, contentTarget: 400)
    }

    static let producer = ReadingPackageHeader.Producer(app: "ScaboPDF per Mac", version: "0.2", build: "2", system: "macOS 27.0.1", cureLevel: 53)
    static let source = ReadingPackageHeader.Source(sha256: String(repeating: "ab", count: 32), fileName: "prova.pdf", title: "Libro di prova", pageCount: 4)

    func test_andataERitorno_identici_conEsenzaAnnotazioni() throws {
        let r = Self.reading()
        let data = try ReadingPackage.write(producer: Self.producer, source: Self.source, reading: r, cacheFormat: 6,
                                            workshop: ["note ricucite fra due pagine: 0"], annotations: nil)
        let (h, offset) = try ReadingPackage.readHeader(data)
        XCTAssertEqual(h.kind, ReadingPackageFormat.kind)
        XCTAssertEqual(h.formatVersion, 1)
        XCTAssertEqual(h.source, Self.source)
        XCTAssertEqual(h.producer, Self.producer)
        XCTAssertNil(h.annotations)
        XCTAssertEqual(h.reading.segments, 4)
        let body = try ReadingPackage.readBody(data, header: h, payloadOffset: offset)
        XCTAssertEqual(body.reading, r)
        XCTAssertNil(body.annotations)

        let idx = ContentAnchorIndex(segments: r.content.pages[0].segments)
        let bm = Bookmark(id: "b1", anchorSegmentId: "node_1", orderIndexHint: 1, name: "Nome", preview: "anteprima", tagIds: ["t1"],
                          createdAt: Date(timeIntervalSince1970: 1_800_000_000), anchor: idx.anchor(forIndex: 1))
        let ann = PackagedAnnotations(bookmarks: [bm], underlines: [], tags: [Tag(id: "t1", name: "Importante")], readingAnchor: nil)
        let data2 = try ReadingPackage.write(producer: Self.producer, source: Self.source, reading: r, cacheFormat: 6, workshop: [], annotations: ann)
        let (h2, o2) = try ReadingPackage.readHeader(data2)
        XCTAssertEqual(h2.annotations, .init(bookmarks: 1, underlines: 0, hasPosition: false))
        XCTAssertEqual(try ReadingPackage.readBody(data2, header: h2, payloadOffset: o2).annotations, ann)
    }

    func test_intestazioneDaFile_senzaToccareIlCarico() throws {
        let data = try ReadingPackage.write(producer: Self.producer, source: Self.source, reading: Self.reading(), cacheFormat: 6, workshop: [], annotations: nil)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("prova-\(UUID().uuidString).scabolettura")
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let (h, offset) = try ReadingPackage.readHeader(at: url)
        XCTAssertEqual(h.source.title, "Libro di prova")
        XCTAssertEqual(offset + h.payload.length, data.count)
    }

    func test_nonUnPacchetto_eDanneggiato_inProsa() throws {
        XCTAssertThrowsError(try ReadingPackage.readHeader(Data("un file qualunque, non un pacchetto".utf8))) {
            XCTAssertEqual($0 as? ReadingPackageProblem, .notAPackage)
        }
        var data = try ReadingPackage.write(producer: Self.producer, source: Self.source, reading: Self.reading(), cacheFormat: 6, workshop: [], annotations: nil)
        let (h, offset) = try ReadingPackage.readHeader(data)
        data[data.count - 5] ^= 0xFF   // un byte del carico cambiato
        XCTAssertThrowsError(try ReadingPackage.readBody(data, header: h, payloadOffset: offset)) {
            XCTAssertEqual($0 as? ReadingPackageProblem, .damaged)
        }
        XCTAssertThrowsError(try ReadingPackage.readBody(data.dropLast(10), header: h, payloadOffset: offset))
        XCTAssertFalse(ReadingPackageProblem.damaged.prose.lowercased().hasPrefix("errore"))
    }

    func test_versioneSconosciuta_eLetturaNonLeggibile_detteInProsa() throws {
        // Un'intestazione di una forma futura: si dice tale, con l'app che l'ha prodotta.
        let future = #"{"kind":"scabopdf-lettura","formatVersion":7,"producer":{"app":"ScaboPDF per Mac","version":"3.1"}}"#
        var data = Data(ReadingPackageFormat.magic)
        var n = UInt32(future.utf8.count).bigEndian
        withUnsafeBytes(of: &n) { data.append(contentsOf: $0) }
        data.append(Data(future.utf8))
        XCTAssertThrowsError(try ReadingPackage.readHeader(data)) { e in
            guard case .newerFormat(let v, let p)? = e as? ReadingPackageProblem else { return XCTFail("\(e)") }
            XCTAssertEqual(v, 7)
            XCTAssertTrue(p.contains("3.1"))
            XCTAssertTrue((e as! ReadingPackageProblem).prose.contains("Aggiorna ScaboPDF"))
        }
        let ok = try ReadingPackage.write(producer: Self.producer, source: Self.source, reading: Self.reading(), cacheFormat: 9, workshop: [], annotations: nil)
        let (h, _) = try ReadingPackage.readHeader(ok)
        XCTAssertThrowsError(try ReadingPackage.checkCompatibility(h, readableCacheFormats: 6...6)) {
            guard case .unsupportedReading(9, _)? = $0 as? ReadingPackageProblem else { return XCTFail("\($0)") }
        }
        XCTAssertNoThrow(try ReadingPackage.checkCompatibility(h, readableCacheFormats: 6...9))
    }

    func test_nomeDelFile_ripulito() {
        XCTAssertEqual(ReadingPackage.suggestedFileName(title: "Manuale: parte 1/2"), "Manuale  parte 1 2.scabolettura")
        XCTAssertEqual(ReadingPackage.suggestedFileName(title: "   "), "Lettura.scabolettura")
    }
}

final class AnnotationMergeTests: XCTestCase {

    private func index(_ texts: [String] = ReadingPackageTests.frasi) -> ContentAnchorIndex {
        ContentAnchorIndex(segments: ReadingPackageTests.reading(texts).content.pages[0].segments)
    }

    private func bookmark(_ id: String, at i: Int, name: String? = nil, tags: [String] = [], in idx: ContentAnchorIndex) -> Bookmark {
        Bookmark(id: id, anchorSegmentId: idx.segments[i].id, orderIndexHint: i, name: name, preview: "anteprima",
                 tagIds: tags, createdAt: Date(timeIntervalSince1970: 1_800_000_000), anchor: idx.anchor(forIndex: i))
    }

    private func underline(_ id: String, seg i: Int, _ s: Int, _ e: Int, in idx: ContentAnchorIndex) -> Underline {
        Underline(id: id, spans: [UnderlineSpan(segmentId: idx.segments[i].id, startWord: s, endWord: e,
                                                anchor: idx.quoteAnchor(forIndex: i, startWord: s, endWord: e))],
                  preview: "anteprima", createdAt: Date(timeIntervalSince1970: 1_800_000_000))
    }

    func test_segnalibri_stessoPunto_unoSolo_unioneDeiTag_nomiDiversiRestanoDue() {
        let idx = index()
        let local = [bookmark("L1", at: 0, name: "Mio", tags: ["a"], in: idx), bookmark("L2", at: 1, name: "Uno", in: idx)]
        let incoming = [bookmark("M1", at: 0, tags: ["b"], in: idx),          // stesso punto, senza nome → fuso
                        bookmark("M2", at: 1, name: "Altro", in: idx),         // stesso punto, nome diverso → resta
                        bookmark("M3", at: 2, name: "Nuovo", in: idx),         // punto nuovo → aggiunto
                        bookmark("L2", at: 3, name: "Uno", in: idx)]           // stesso id → fuso (già passato di qui)
        let out = AnnotationMerge.merge(localBookmarks: local, localUnderlines: [], readingPosition: 0, readingAnchor: nil,
                                        incomingBookmarks: incoming, incomingUnderlines: [], in: idx)
        XCTAssertEqual(out.bookmarks.map { $0.id }, ["L1", "L2", "M2", "M3"])
        XCTAssertEqual(out.bookmarks[0].tagIds, ["a", "b"])
        XCTAssertEqual(out.bookmarks[0].name, "Mio")
        XCTAssertEqual(out.report.bookmarksMerged, 2)
        XCTAssertEqual(out.report.bookmarksAdded, 2)
        XCTAssertEqual(out.report.bookmarksOrphan, 0)
    }

    func test_sottolineature_doppione_unione_disgiunta_orfana() {
        let idx = index()
        let local = [underline("U1", seg: 0, 2, 5, in: idx)]
        let other = index(["Una frase che non c'è nella lettura nuova e serve solo alla prova dell'orfana di oggi."])
        let incoming = [underline("D", seg: 0, 2, 5, in: idx),        // identica → doppione
                        underline("O", seg: 0, 4, 8, in: idx),        // sovrapposta → unione 2…8
                        underline("N", seg: 2, 0, 3, in: idx),        // disgiunta → aggiunta
                        underline("X", seg: 0, 0, 3, in: other)]      // non si ritrova → orfana dichiarata
        let out = AnnotationMerge.merge(localBookmarks: [], localUnderlines: local, readingPosition: 0, readingAnchor: nil,
                                        incomingBookmarks: [], incomingUnderlines: incoming, in: idx)
        XCTAssertEqual(out.report.underlinesDuplicate, 1)
        XCTAssertEqual(out.report.underlinesUnited, 1)
        XCTAssertEqual(out.report.underlinesAdded, 1)
        XCTAssertEqual(out.report.underlinesOrphan, 1)
        let united = out.underlines.first { $0.id == "U1" }!
        XCTAssertEqual(united.spans.map { [$0.startWord, $0.endWord] }, [[2, 8]])
        XCTAssertNotNil(united.spans[0].anchor)
        XCTAssertTrue(out.underlines.contains { $0.id == "X" && $0.isOrphan == true })
        // Nessuna parola in due sottolineature (§ 6.3).
        let placed = out.underlines.filter { $0.isOrphan != true }
        for (i, a) in placed.enumerated() { for b in placed[(i + 1)...] { XCTAssertFalse(AnnotationMerge.overlaps(a, b, [:].merging(idx.segments.enumerated().map { ($1.id, $0) }) { a, _ in a })) } }
    }

    func test_nienteDaFondere_annotazioniLocaliRiancorateSoltanto() {
        let old = index(["Una riga di testatina che sparisce.", ] + ReadingPackageTests.frasi)
        let new = index()
        let local = [bookmark("L", at: 2, name: "Segno", in: old)]
        let out = AnnotationMerge.merge(localBookmarks: local, localUnderlines: [], readingPosition: 0, readingAnchor: nil,
                                        incomingBookmarks: [], incomingUnderlines: [], in: new)
        XCTAssertEqual(out.bookmarks.count, 1)
        XCTAssertEqual(out.bookmarks[0].anchorSegmentId, "node_1")   // ritrovato per contenuto
        XCTAssertEqual(out.report.localReport.bookmarksRelocated, 1)
        XCTAssertEqual(out.report.incomingTotal, 0)
    }
}
