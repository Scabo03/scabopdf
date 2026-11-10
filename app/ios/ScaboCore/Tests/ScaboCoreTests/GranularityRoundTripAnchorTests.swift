//
//  GranularityRoundTripAnchorTests.swift
//  ScaboCoreTests
//
//  Le annotazioni attraverso un'ANDATA E RITORNO di granularità (giro «prove rifatte e granularità», 2026-11-10, rilievo R5
//  della revisione indipendente). Il corpo si raggruppa per caratteri anche attraverso i paragrafi: qui, a 400, un paragrafo
//  di otto frasi e il paragrafo seguente sono tre pezzi (P1, P2, P3); a 900 sono un blocco solo (B). Un segnalibro su P3, che
//  sta in coda a B, va su B; tornando a 400 deve tornare su P3. Prima della cura l'ancora veniva riconiata su B, e al ritorno il
//  passo dei pezzi consecutivi la metteva sul primo pezzo, P1, con esito esatto: spostato in silenzio, contro LAYER2 § 12.14.
//  Ora, quando il testo d'origine sta dentro un blocco più lungo (livello «contenuto»), l'ancora resta quella d'origine, e la
//  verifica a ogni apertura la riconosce al suo posto (nessun riancoraggio a ogni apertura). Il pezzo di mezzo, P2, a 900 non
//  si ritrova a un'estremità di B e resta orfano, cioè «da ricollocare»: dichiarato, mai spostato. Testi SINTETICI e neutri.
//

import XCTest
@testable import ScaboCore

final class GranularityRoundTripAnchorTests: XCTestCase {

    private func seg(_ id: String, _ text: String, role: String = "BODY", page: Int? = 3) -> ContentSegment {
        ContentSegment(id: id, role: role, text: text, lengthCategory: "", acousticIntro: "", sourcePage: page)
    }

    /// Otto frasi distinte di circa 100 caratteri, poi un paragrafo breve.
    private let paragraph = (1...8).map { i in
        "La frase numero \(i) racconta il mulino numero \(i), la chiusa sul fiume e il ponte di pietra del borgo."
    }.joined(separator: " ")

    private var raw: [ContentSegment] {
        [
            seg("node_0", "Capitolo del mulino", role: "HEADING_1"),
            seg("node_1", paragraph),
            seg("node_2", "Il paragrafo seguente parla della sera, dei lumi accesi alle finestre e del silenzio della piazza."),
        ]
    }

    private func flow(_ target: Int) -> [ContentSegment] { granularizeBody(raw, target: target) }

    private func body(_ f: [ContentSegment]) -> [Int] { f.indices.filter { f[$0].role == "BODY" } }

    private func bookmark(on i: Int, in f: [ContentSegment]) throws -> Bookmark {
        Bookmark(id: "b1", anchorSegmentId: f[i].id, orderIndexHint: i, preview: "", originalPage: 3, createdAt: Date(),
                 anchor: try XCTUnwrap(ContentAnchorIndex(segments: f).anchor(forIndex: i)))
    }

    private func reanchor(_ b: [Bookmark], position: Int = 0, anchor: ContentAnchor? = nil,
                          in f: [ContentSegment]) -> ReanchoredAnnotations {
        AnnotationReanchoring.reanchor(bookmarks: b, underlines: [], readingPosition: position, readingAnchor: anchor,
                                       in: ContentAnchorIndex(segments: f))
    }

    private func inPlace(_ r: ReanchoredAnnotations, in f: [ContentSegment]) -> Bool {
        !AnnotationReanchoring.needsReanchoring(bookmarks: r.bookmarks, underlines: [], readingPosition: r.readingPosition,
                                                readingAnchor: r.readingAnchor, in: ContentAnchorIndex(segments: f))
    }

    func test_ilFlusso_a400InTrePezzi_a900InUnBloccoSolo() {
        XCTAssertEqual(body(flow(400)).count, 3)
        XCTAssertEqual(body(flow(900)).count, 1)
    }

    func test_andataERitorno_segnalibroSullUltimoPezzo_tornaSulSuoPezzo() throws {
        let f400 = flow(400), f900 = flow(900)
        let p3 = body(f400)[2], b = body(f900)[0]
        let start = try bookmark(on: p3, in: f400)
        let at900 = reanchor([start], in: f900)
        XCTAssertEqual(at900.bookmarks[0].anchorSegmentId, f900[b].id, "il suo testo sta in coda al blocco")
        XCTAssertNil(at900.bookmarks[0].isOrphan)
        XCTAssertTrue(inPlace(at900, in: f900), "a contenuto fermo è al suo posto: nessun riancoraggio a ogni apertura")
        let back = reanchor(at900.bookmarks, in: f400)
        XCTAssertEqual(back.bookmarks[0].anchorSegmentId, f400[p3].id, "tornato sul suo pezzo, non sul primo")
        XCTAssertNil(back.bookmarks[0].isOrphan)
        XCTAssertEqual(back.bookmarks[0].anchor, start.anchor)
        XCTAssertTrue(inPlace(back, in: f400))
    }

    func test_andataERitorno_segnalibroSulPrimoPezzo_tornaSulSuoPezzo() throws {
        let f400 = flow(400), f900 = flow(900)
        let p1 = body(f400)[0], b = body(f900)[0]
        let at900 = reanchor([try bookmark(on: p1, in: f400)], in: f900)
        XCTAssertEqual(at900.bookmarks[0].anchorSegmentId, f900[b].id)
        XCTAssertTrue(inPlace(at900, in: f900))
        XCTAssertEqual(reanchor(at900.bookmarks, in: f400).bookmarks[0].anchorSegmentId, f400[p1].id)
    }

    func test_pezzoDiMezzo_a900ResaDaRicollocare_eAlRitornoSiRitrova() throws {
        let f400 = flow(400), f900 = flow(900)
        let p2 = body(f400)[1]
        let at900 = reanchor([try bookmark(on: p2, in: f400)], in: f900)
        XCTAssertEqual(at900.bookmarks[0].isOrphan, true, "dichiarato da ricollocare, mai spostato")
        let back = reanchor(at900.bookmarks, in: f400)
        XCTAssertEqual(back.bookmarks[0].anchorSegmentId, f400[p2].id)
        XCTAssertNil(back.bookmarks[0].isOrphan)
    }

    func test_andataERitorno_posizioneSullUltimoPezzo_tornaSulSuoPezzo() throws {
        let f400 = flow(400), f900 = flow(900)
        let p3 = body(f400)[2], b = body(f900)[0]
        let anchor = try XCTUnwrap(ContentAnchorIndex(segments: f400).anchor(forIndex: p3))
        let at900 = reanchor([], position: p3, anchor: anchor, in: f900)
        XCTAssertEqual(at900.readingPosition, b)
        XCTAssertFalse(at900.readingPositionIsApproximate)
        XCTAssertTrue(inPlace(at900, in: f900))
        let back = reanchor([], position: at900.readingPosition, anchor: at900.readingAnchor, in: f400)
        XCTAssertEqual(back.readingPosition, p3, "la posizione torna sul suo pezzo")
        XCTAssertFalse(back.readingPositionIsApproximate)
    }

    func test_segnalibroNatoSulBloccoGrande_vaSulPrimoPezzo_eTorna() throws {
        let f400 = flow(400), f900 = flow(900)
        let p1 = body(f400)[0], b = body(f900)[0]
        let at400 = reanchor([try bookmark(on: b, in: f900)], in: f400)
        XCTAssertEqual(at400.bookmarks[0].anchorSegmentId, f400[p1].id, "il testo del blocco comincia nel primo pezzo")
        XCTAssertTrue(inPlace(at400, in: f400))
        let back = reanchor(at400.bookmarks, in: f900)
        XCTAssertEqual(back.bookmarks[0].anchorSegmentId, f900[b].id)
        XCTAssertNil(back.bookmarks[0].isOrphan)
    }

    func test_alContrario_ancoraConservata_suUnAltroSegmento_vaRiancorata() throws {
        let f400 = flow(400), f900 = flow(900)
        let at900 = reanchor([try bookmark(on: body(f400)[2], in: f400)], in: f900)
        var moved = at900.bookmarks[0]
        moved.anchorSegmentId = f900[0].id   // l'id non porta più il suo testo (il titolo)
        XCTAssertTrue(AnnotationReanchoring.needsReanchoring(
            bookmarks: [moved], underlines: [], readingPosition: 0, readingAnchor: nil, in: ContentAnchorIndex(segments: f900)))
    }
}
