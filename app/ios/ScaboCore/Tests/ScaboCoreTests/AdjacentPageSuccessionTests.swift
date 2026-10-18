//
//  AdjacentPageSuccessionTests.swift
//  ScaboCoreTests
//
//  Le note spezzate fra pagine contigue che il PREDICATO dell'app respinge (giro «pulizia e rifinitura finale del capitolo
//  note», 2026-10-17, decisione 2 del maintainer): la coda comincia con una maiuscola, o la testa finisce con un punto, e il
//  predicato le scambiava per una nota nuova. Con la successione CONFERMATA sulla pagina seguente (la prima nota numerata
//  dopo la coda porta il numero della testa più uno) il predicato non serve più; restano tutte le guardie geometriche e del
//  corpo tipografico. In più: una pagina fatta di sole note (una nota che la riempie) si ricuce se vale il predicato, e il
//  corpo di una riga si misura sui soli span con lettere o cifre. Due guardie per le categorie false trovate giudicando
//  contro la pagina: la conferma deve venire da una nota che si apre come una nota (non da un numero seguito da una
//  minuscola: il marcatore staccato e spostato dall'estrazione), e una coda aperta da una glossa a margine, o fatta della
//  sola glossa, non si ricuce (dal giro «chiusura del capitolo note», 2026-10-18, la glossa resta al suo posto e si
//  ricuce il seguito vero: `MarginGlossStitchTests`). Estrazioni sintetiche con geometria, pipeline reale, e prove dirette
//  delle guardie; ogni regola ha la sua prova al contrario. Testi neutri, inventati.
//

import XCTest
@testable import ScaboCore

final class AdjacentPageSuccessionTests: XCTestCase {

    private func line(_ text: String, size: Double, x: Double = 60, y: Double,
                      spans: [(String, Double)]? = nil) -> PdfTextLine {
        let parts = spans ?? [(text, size)]
        return PdfTextLine(
            spans: parts.map {
                PdfSpan(text: $0.0, fontSize: $0.1, bold: false, italic: false, color: "#000000",
                        bbox: BBox(x: x, y: y, width: 420, height: $0.1))
            },
            bbox: BBox(x: x, y: y, width: 420, height: size))
    }
    private func bodyLines(_ tag: String) -> [PdfTextLine] {
        (0..<6).map { line("Riga di corpo \(tag) numero \($0) che prosegue il discorso", size: 10, y: 760 - Double($0) * 14) }
    }
    private func extraction(_ pages: [[PdfTextLine]]) -> PdfExtraction {
        PdfExtraction(version: 2, pageCount: pages.count,
                      pages: pages.enumerated().map {
                          PdfPageExtraction(pageIndex: $0.offset, width: 595, height: 842, lines: $0.element)
                      },
                      producer: nil)
    }
    private func placed(_ ex: PdfExtraction) -> (ScabopdfDocument, NotePlacementStats) {
        bindAndPlaceNotes(buildDocumentFromPdf(ex, sourceName: "t.pdf"), ex)
    }
    private func noteTexts(_ doc: ScabopdfDocument) -> [String] {
        doc.structure.filter { $0.type == .NOTE }.map { $0.text ?? "" }
    }

    /// Pagina A: la nota 13 si chiude a fine pagina con un punto; pagina B: la coda comincia con una maiuscola (frase nuova
    /// della stessa nota), poi la nota `next`.
    private func pages(next: Int? = 14, nextText: String = "Nota nuova della seconda pagina.", tail: PdfTextLine? = nil,
                       tailBetweenBody: Bool = false, gloss: PdfTextLine? = nil) -> PdfExtraction {
        let a = bodyLines("a") + [line("12 Prima nota completa.", size: 8, y: 140),
                                  line("13 Seconda nota la cui prima frase finisce qui.", size: 8, y: 129)]
        let t = tail ?? line("Una frase nuova della stessa nota prosegue sulla pagina seguente.", size: 8, y: 140)
        var b: [PdfTextLine]
        if tailBetweenBody {
            b = [line(t.spans.map { $0.text }.joined(), size: 8, y: 740)] + bodyLines("b")
        } else {
            b = bodyLines("b") + (gloss.map { [$0] } ?? []) + [t]
        }
        if let n = next { b.append(line("\(n) \(nextText)", size: 8, y: 118)) }
        return extraction([a, b])
    }

    func test_predicateRejects_butConfirmedSuccession_stitches() {
        let (doc, stats) = placed(pages())
        XCTAssertEqual(stats.adjacentPageCandidates.first?.predicate, false, "il predicato respinge")
        XCTAssertEqual(stats.adjacentPageCandidates.first?.succession, "confermata")
        XCTAssertEqual(stats.stitchedAdjacentPage, 1)
        XCTAssertTrue(noteTexts(doc).contains(
            "13 Seconda nota la cui prima frase finisce qui. Una frase nuova della stessa nota prosegue sulla pagina seguente."))
        XCTAssertTrue(noteTexts(doc).contains("14 Nota nuova della seconda pagina."))
    }

    func test_predicateRejects_withoutConfirmedSuccession_noStitch() {
        // nessuna nota numerata dopo la coda: senza la conferma della successione il predicato resta la guardia
        let (doc, stats) = placed(pages(next: nil))
        XCTAssertEqual(stats.stitchedAdjacentPage, 0)
        XCTAssertEqual(stats.adjacentPageCandidates.first?.reason, "predicato")
        XCTAssertTrue(noteTexts(doc).contains("13 Seconda nota la cui prima frase finisce qui."))
    }

    func test_predicateRejects_successionBroken_noStitch() {
        // la nota dopo la coda porta 15: la successione non conferma, la coda potrebbe essere la nota 14 senza numero
        let (_, stats) = placed(pages(next: 15))
        XCTAssertEqual(stats.stitchedAdjacentPage, 0)
        XCTAssertEqual(stats.adjacentPageCandidates.first?.reason, "predicato")
    }

    func test_predicateRejects_confirmed_butTailBetweenTheBodyLines_noStitch() {
        // la «coda» sta in cima alla pagina, fra le righe del corpo: una citazione, una glossa, un riquadro
        let (_, stats) = placed(pages(tailBetweenBody: true))
        XCTAssertEqual(stats.stitchedAdjacentPage, 0)
        XCTAssertEqual(stats.adjacentPageCandidates.first?.reason, "coda non sotto il corpo")
    }

    func test_predicateRejects_confirmed_butDifferentTypeSize_noStitch() {
        let t = line("Una riga a un corpo diverso da quello delle note.", size: 7, y: 140)
        let (_, stats) = placed(pages(tail: t))
        XCTAssertEqual(stats.stitchedAdjacentPage, 0)
        XCTAssertEqual(stats.adjacentPageCandidates.first?.reason, "corpo tipografico diverso")
    }

    func test_typeSize_ignoresPunctuationAtBodySize() {
        // la prima riga della coda porta una virgola composta al corpo del testo: il corpo della riga resta quello della nota
        let t = line("", size: 8, y: 140, spans: [("continua la nota", 8), (", ", 10), ("e si chiude qui.", 8)])
        let (_, stats) = placed(pages(tail: t))
        XCTAssertEqual(stats.adjacentPageCandidates.first?.tailSize, 8)
        XCTAssertEqual(stats.stitchedAdjacentPage, 1)
    }

    func test_confirmationFromANumberFollowedByLowercase_isNotANote_noStitch() {
        // dopo la coda, «14» seguito da una minuscola: il marcatore che l'estrazione ha staccato e spostato dal testo, o un
        // numero spurio a inizio riga; non è la nota seguente che si apre, e non conferma la successione
        let (doc, stats) = placed(pages(nextText: "della nota precedente, riga che prosegue."))
        XCTAssertEqual(stats.adjacentPageCandidates.first?.succession, "confermata")
        XCTAssertEqual(stats.adjacentPageCandidates.first?.reason, "predicato")
        XCTAssertEqual(stats.stitchedAdjacentPage, 0)
        XCTAssertTrue(noteTexts(doc).contains("13 Seconda nota la cui prima frase finisce qui."))
    }

    func test_noteNumberFollowedByLowercase() {
        XCTAssertTrue(noteNumberFollowedByLowercase("27 della nota precedente"))
        XCTAssertTrue(noteNumberFollowedByLowercase("(27) della nota precedente"))
        XCTAssertTrue(noteNumberFollowedByLowercase("27. sul tema"))
        XCTAssertFalse(noteNumberFollowedByLowercase("27 Nota che si apre"))
        XCTAssertFalse(noteNumberFollowedByLowercase("(27) Nota che si apre"))
        XCTAssertFalse(noteNumberFollowedByLowercase("27 «Citazione che apre la nota»"))
        XCTAssertFalse(noteNumberFollowedByLowercase("27"))
        XCTAssertFalse(noteNumberFollowedByLowercase("una riga senza numero"))
    }

    // MARK: - glossa a margine in testa alla coda

    func test_tailOpenedByAMarginGloss_glossStays_continuationStitches() {
        // sulla pagina B l'estrazione mette in testa al nodo delle note una glossa stampata nel margine sinistro (a
        // sinistra del corpo, che sta a 60). Fino alla build 57 la coppia restava aperta (ricucire tutto avrebbe portato la
        // glossa dentro la nota); dal giro «chiusura del capitolo note» (2026-10-18) la glossa resta dov'era, nota a sé, e
        // il seguito dopo la glossa si ricuce alla testa (le prove complete in `MarginGlossStitchTests`)
        let gloss = line("Titoletto a margine", size: 8, x: 40, y: 150)
        let (doc, stats) = placed(pages(gloss: gloss))
        XCTAssertEqual(stats.adjacentPageCandidates.first?.marginGloss, "glossa in testa alla coda")
        XCTAssertEqual(stats.adjacentPageCandidates.first?.reason, "ricucita")
        XCTAssertEqual(stats.stitchedAdjacentPage, 1)
        let notes = noteTexts(doc)
        XCTAssertTrue(notes.contains(
            "13 Seconda nota la cui prima frase finisce qui. Una frase nuova della stessa nota prosegue sulla pagina seguente."),
                      "\(notes)")
        XCTAssertTrue(notes.contains("Titoletto a margine"), "la glossa resta, da sola: \(notes)")
        XCTAssertFalse(notes.contains { $0.hasPrefix("Titoletto a margine ") }, "la glossa non porta più il seguito")
    }

    func test_tailOpenedByALineInTheColumn_stitches() {
        // prova al contrario: la stessa riga, ma nella colonna delle note: è la coda, e si ricuce
        let first = line("Una riga della stessa nota", size: 8, x: 60, y: 150)
        let (_, stats) = placed(pages(gloss: first))
        XCTAssertEqual(stats.stitchedAdjacentPage, 1)
    }

    private func lines(_ xs: [(Double, String)]) -> [LineSummary] {
        xs.enumerated().map { summarizeLine(line($0.element.1, size: 8, x: $0.element.0, y: 300 - Double($0.offset) * 11)) }
    }

    func test_tailStartsWithMarginGloss_glossThenColumn() {
        let node = lines([(40, "Titoletto"), (40, "a margine"), (60, "continua la nota della pagina prima."),
                          (74, "14 Nota nuova che si apre"), (60, "e prosegue su due righe.")])
        XCTAssertTrue(tailStartsWithMarginGloss(node, bodyLeft: 60, noteColumnLeft: nil))
        // senza la misura del corpo non si ferma nulla; e una prima riga a 58 (entro la tolleranza) sta nella colonna
        XCTAssertFalse(tailStartsWithMarginGloss(node, bodyLeft: nil, noteColumnLeft: nil))
        XCTAssertFalse(tailStartsWithMarginGloss(lines([(58, "continua"), (74, "14 Nota"), (60, "e prosegue.")]),
                                                 bodyLeft: 60, noteColumnLeft: nil))
    }

    func test_tailStartsWithMarginGloss_noteWiderThanTheBody_isNotAGloss() {
        // le note sporgono a sinistra del corpo e tornano al loro margine nelle righe che seguono: non è una glossa
        let node = lines([(40, "continua la nota"), (54, "14 Nota nuova"), (40, "che prosegue al margine delle note.")])
        XCTAssertFalse(tailStartsWithMarginGloss(node, bodyLeft: 60, noteColumnLeft: 40))
    }

    func test_tailStartsWithMarginGloss_glossAlone() {
        // il nodo è fatto della sola glossa, e le altre note della pagina stanno nella loro colonna più a destra
        let node = lines([(40, "Titoletto"), (40, "a margine")])
        XCTAssertTrue(tailStartsWithMarginGloss(node, bodyLeft: 60, noteColumnLeft: 60))
        // prove al contrario: le altre note stanno alla stessa ascissa (note che sporgono a sinistra del corpo), o la
        // colonna delle altre note non è misurabile
        XCTAssertFalse(tailStartsWithMarginGloss(node, bodyLeft: 60, noteColumnLeft: 41))
        XCTAssertFalse(tailStartsWithMarginGloss(node, bodyLeft: 60, noteColumnLeft: nil))
    }

    func test_noteColumnLeft_isMeasuredOnContinuationLines() {
        let a = lines([(74, "12 Una nota"), (60, "che prosegue"), (60, "su tre righe.")])
        let b = lines([(74, "13 Un'altra nota"), (60, "su due righe.")])
        XCTAssertEqual(noteColumnLeft([a, b]), 60)
        XCTAssertNil(noteColumnLeft([lines([(74, "12 Una nota di una riga.")])]))
    }

    func test_bodyLeftMargin_leftmostSharedAbscissa() {
        let body = lines([(60, "riga"), (60, "riga"), (72, "citazione rientrata"), (72, "citazione"), (72, "citazione"),
                          (30, "riga isolata")])
        XCTAssertEqual(bodyLeftMargin([.run(.body, body)]), 60)
        XCTAssertNil(bodyLeftMargin([.run(.body, Array(body.prefix(2)))]))
        XCTAssertNil(bodyLeftMargin([.run(.note, body)]))
    }

    // MARK: - pagine fatte di sole note

    private func bodilessPages(tail: String, headEnd: String = "13 Una nota lunga che resta aperta e") -> PdfExtraction {
        let a = bodyLines("a") + [line("12 Prima nota completa.", size: 8, y: 140), line(headEnd, size: 8, y: 129)]
        // la pagina B non ha corpo: solo la continuazione della nota, dall'alto
        let b = (0..<8).map { line($0 == 0 ? tail : "riga \($0) della nota che riempie la pagina", size: 8, y: 760 - Double($0) * 11) }
        return extraction([a, b])
    }

    func test_bodilessNextPage_stitches_whenThePredicateHolds() {
        let (doc, stats) = placed(bodilessPages(tail: "continua sulla pagina che riempie da sola"))
        XCTAssertEqual(stats.stitchedAdjacentPage, 1)
        XCTAssertTrue(noteTexts(doc).contains { $0.hasPrefix("13 Una nota lunga che resta aperta e continua sulla pagina") })
    }

    func test_bodilessNextPage_noStitch_whenThePredicateFails() {
        // la coda comincia con una maiuscola: senza corpo sulla pagina, il predicato resta necessario
        let (_, stats) = placed(bodilessPages(tail: "Una frase nuova in cima alla pagina", headEnd: "13 Una nota che si chiude."))
        XCTAssertEqual(stats.stitchedAdjacentPage, 0)
        XCTAssertEqual(stats.adjacentPageCandidates.first?.reason, "predicato")
    }
}
