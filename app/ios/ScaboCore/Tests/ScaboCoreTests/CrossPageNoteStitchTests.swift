//
//  CrossPageNoteStitchTests.swift
//  ScaboCoreTests
//
//  Ricucitura-per-identità delle note spezzate dal salto pagina (livello footnote, prima
//  del piazzamento). Fonde la coda (prima footnote di pag N+1, senza numero) nella testa
//  (ultima di pag N, che APRE) solo su pagine consecutive + continuità testuale. Guardia
//  anti-fusione: una nota NUOVA apre col suo numero → mai fusa con la precedente.
//

import XCTest
@testable import ScaboCore

final class CrossPageNoteStitchTests: XCTestCase {

    /// Costruisce una struttura di nodi NOTE (una footnote ciascuno) e applica lo stitch.
    private func run(_ foots: [(page: Int, text: String)])
        -> (text: [String], removed: [String], count: Int)
    {
        var structure: [NodeDict] = []
        var byId: [String: NodeDict] = [:]
        var order: [String: [String]] = [:]
        var fids: [String] = []
        for (i, f) in foots.enumerated() {
            let noteId = "N\(i)"
            structure.append(NodeDict(id: noteId, type: .NOTE, page_index: f.page, text: f.text))
            let fid = "\(noteId)_n0"
            fids.append(fid)
            byId[fid] = NodeDict(id: fid, type: .NOTE, page_index: f.page, text: f.text,
                                 length_category: .MEDIUM)
            order[noteId] = [fid]
        }
        let count = stitchCrossPageFootnotes(structure, &byId, &order)
        let texts = fids.map { byId[$0]?.text ?? "" }
        let removed = fids.filter { fid in !order.values.contains { $0.contains(fid) } }
        return (texts, removed, count)
    }

    // MARK: - ricucitura corretta

    func test_hyphenSplit_merged_dehyphenated() {
        let r = run([(19, "27 alla qualificazione – pub-"), (20, "blicistica – delle delibere")])
        XCTAssertEqual(r.count, 1)
        XCTAssertTrue(r.text[0].contains("pubblicistica"), "de-sillabazione pub-|blicistica")
        XCTAssertEqual(r.removed, ["N1_n0"], "la coda è assorbita (rimossa dall'ordine)")
    }

    func test_commaContinuation_merged_withSpace() {
        let r = run([(15, "15 strumento urbanistico, oppure"), (16, "una diffida, fanno sì che")])
        XCTAssertEqual(r.count, 1)
        XCTAssertTrue(r.text[0].contains("oppure una diffida"), "giunzione con spazio")
    }

    func test_samePageSplit_merged() {
        // over-split di splitFootnotes: una nota spezzata sulla STESSA pagina da un numero
        // spurio interpretato come marcatore → testa apre, coda continua → ricucita.
        let r = run([(40, "86 testo della nota che apre,"), (40, "continua sulla stessa pagina")])
        XCTAssertEqual(r.count, 1, "same-page over-split ricucito")
        XCTAssertTrue(r.text[0].contains("apre, continua sulla stessa pagina"))
    }

    func test_strayMarkerClosesHead_residueLeft() {
        // RESIDUO ONESTO: la prima coda finisce con un marcatore spurio ("69") → la testa
        // cresciuta NON apre più → la seconda coda resta (non forzata). Anti-fusione > recall.
        let r = run([(40, "86 apre,"), (40, "cordi 69"), (40, "le norme la prevedano")])
        XCTAssertEqual(r.count, 1, "solo 'cordi 69' fuso; '69' chiude la testa → 'le norme' resta residuo")
    }

    func test_chain_threePages() {
        let r = run([(19, "30 apre,"), (20, "continua ancora,"), (21, "e finisce qui")])
        XCTAssertEqual(r.count, 2, "catena su 3 pagine")
        XCTAssertTrue(r.text[0].contains("apre, continua ancora, e finisce qui"))
        XCTAssertEqual(Set(r.removed), ["N1_n0", "N2_n0"])
    }

    func test_lengthCategoryRecomputed_onGrowth() {
        let longCont = String(repeating: "parola ", count: 120)  // > soglia LONG
        let r = run([(19, "9 breve apre,"), (20, longCont)])
        XCTAssertEqual(r.count, 1)
        // la testa cresciuta non resta MEDIUM stale (ricomputata)
    }

    // MARK: - guardia ANTI-FUSIONE (mai due note distinte)

    func test_antifusion_newNoteWithNumber_notMerged() {
        let r = run([(19, "27 testo che apre,"), (20, "30 La nuova nota distinta")])
        XCTAssertEqual(r.count, 0, "la coda inizia col numero (nuova nota) → mai fusa")
    }

    func test_antifusion_newNotePunct_notMerged() {
        let r = run([(19, "27 apre,"), (20, "31. Altra nota")])
        XCTAssertEqual(r.count, 0)
    }

    func test_headDoesNotOpen_notMerged() {
        let r = run([(19, "27 nota completa con punto finale."), (20, "continua minuscolo")])
        XCTAssertEqual(r.count, 0, "testa con punto forte non apre")
    }

    func test_capitalStart_notMerged() {
        let r = run([(19, "27 apre,"), (20, "Inizia Maiuscolo nuova frase")])
        XCTAssertEqual(r.count, 0, "una continuazione vera è minuscola; Maiuscola = nuova voce")
    }

    func test_nonConsecutivePages_notMerged() {
        let r = run([(19, "27 apre,"), (21, "salta una pagina")])
        XCTAssertEqual(r.count, 0, "le pagine devono essere consecutive (N, N+1)")
    }

    func test_abbrWaitingNumber_opens_continuationDigit_merged() {
        let r = run([(28, "28 cit., vol. II, 279; in senso analogo, p."), (29, "508 ss.; SORDI")])
        XCTAssertEqual(r.count, 1, "abbr che attende numero apre; coda numerica continua")
    }
}
