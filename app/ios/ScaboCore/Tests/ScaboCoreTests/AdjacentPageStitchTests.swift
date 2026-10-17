//
//  AdjacentPageStitchTests.swift
//  ScaboCoreTests
//
//  Ricucitura delle note spezzate fra pagine CONTIGUE fuori dall'Estratto e dai codici (giro «cura delle note»,
//  2026-10-16, `stitchAdjacentPageFootnotes`): estrazioni sintetiche CON GEOMETRIA (corpo in alto, apparato di note
//  in basso) fatte passare per la pipeline reale (`buildDocumentFromPdf` → `bindAndPlaceNotes`), più le guardie che la
//  pipeline sintetica non raggiunge provate direttamente su `stitchAdjacentPageFootnotes`. Ogni guardia ha la sua prova
//  al contrario: successione, nota seguente mancante, richiamo senza nota, testa senza numero, coda fra le righe del
//  corpo, testa fra le righe del corpo, nodo che non è una nota, corpo tipografico diverso, coda col numero della nota
//  seguente, testa chiusa, pagine non contigue, codici, Estratto; e la catena vera su tre pagine. Testi neutri, inventati.
//

import XCTest
@testable import ScaboCore

final class AdjacentPageStitchTests: XCTestCase {

    // MARK: - costruttori sintetici (origine in basso a sinistra: y alta = in cima alla pagina)

    private func line(_ text: String, size: Double, x: Double = 60, y: Double, width: Double = 420,
                      spans: [(String, Double)]? = nil) -> PdfTextLine {
        let parts = spans ?? [(text, size)]
        return PdfTextLine(
            spans: parts.map {
                PdfSpan(text: $0.0, fontSize: $0.1, bold: false, italic: false, color: "#000000",
                        bbox: BBox(x: x, y: y, width: width, height: $0.1))
            },
            bbox: BBox(x: x, y: y, width: width, height: size))
    }
    /// Sei righe di corpo (taglia 10) in cima alla pagina, dalla quota 760 in giù: abbastanza per stimare la colonna.
    private func bodyLines(_ tag: String) -> [PdfTextLine] {
        (0..<6).map { line("Riga di corpo \(tag) numero \($0) che prosegue il discorso", size: 10, y: 760 - Double($0) * 14) }
    }
    /// Righe di nota (taglia 8) in fondo alla pagina, dalla quota 140 in giù.
    private func noteLines(_ texts: [String], size: Double = 8, top: Double = 140) -> [PdfTextLine] {
        texts.enumerated().map { line($0.element, size: size, y: top - Double($0.offset) * 11) }
    }
    private func extraction(_ pages: [[PdfTextLine]], width: Double = 595, height: Double = 842,
                            producer: String? = nil) -> PdfExtraction {
        PdfExtraction(version: 2, pageCount: pages.count,
                      pages: pages.enumerated().map {
                          PdfPageExtraction(pageIndex: $0.offset, width: width, height: height, lines: $0.element)
                      },
                      producer: producer)
    }
    private func placed(_ ex: PdfExtraction) -> (ScabopdfDocument, NotePlacementStats) {
        bindAndPlaceNotes(buildDocumentFromPdf(ex, sourceName: "t.pdf"), ex)
    }
    private func noteTexts(_ doc: ScabopdfDocument) -> [String] {
        doc.structure.filter { $0.type == .NOTE }.map { $0.text ?? "" }
    }

    /// Le due pagine tipiche: sulla prima la nota 13 resta aperta in fondo all'apparato, sulla seconda l'apparato
    /// comincia con la sua continuazione e prosegue con la nota `nextNumber`.
    private func twoPages(tail: PdfTextLine? = nil, nextNumber: Int? = 14, tailOnTop: Bool = false) -> PdfExtraction {
        let pageA = bodyLines("a") + noteLines(["12 Prima nota completa della pagina.",
                                                 "13 Seconda nota che resta aperta e"])
        let tailLine = tail ?? line("continua sulla pagina seguente fino al punto.", size: 8, y: 140)
        var notesB: [PdfTextLine] = []
        if let n = nextNumber { notesB.append(line("\(n) Nota nuova della seconda pagina.", size: 8, y: 129)) }
        let pageB: [PdfTextLine]
        if tailOnTop {
            // la «coda» sta FRA le righe del corpo (una citazione in corpo minore, una glossa): sopra l'ultima riga
            pageB = [line(tailLine.spans.map { $0.text }.joined(), size: 8, y: 740)] + bodyLines("b") + notesB
        } else {
            pageB = bodyLines("b") + [tailLine] + notesB
        }
        return extraction([pageA, pageB])
    }

    // MARK: - ricucitura

    func test_stitches_whenSuccessionIsConfirmedOnTheNextPage() {
        let (doc, stats) = placed(twoPages())
        XCTAssertEqual(stats.stitchedAdjacentPage, 1)
        let notes = noteTexts(doc)
        XCTAssertTrue(notes.contains("13 Seconda nota che resta aperta e continua sulla pagina seguente fino al punto."),
                      "la coda è fusa nella testa, nell'ordine: \(notes)")
        XCTAssertFalse(notes.contains("continua sulla pagina seguente fino al punto."), "la coda non resta una nota a sé")
        XCTAssertTrue(notes.contains { $0.hasPrefix("14 ") }, "la nota seguente resta distinta")
        XCTAssertEqual(stats.adjacentPageCandidates.count, 1)
        XCTAssertEqual(stats.adjacentPageCandidates.first?.reason, "ricucita")
        XCTAssertEqual(stats.adjacentPageCandidates.first?.succession, "confermata")
    }

    func test_dehyphenates_aWordBrokenAcrossThePages() {
        let pageA = bodyLines("a") + noteLines(["12 Prima nota completa della pagina.", "13 Una parola spez-"])
        let pageB = bodyLines("b") + noteLines(["zata dal salto di pagina.", "14 Nota nuova."])
        let (doc, stats) = placed(extraction([pageA, pageB]))
        XCTAssertEqual(stats.stitchedAdjacentPage, 1)
        XCTAssertTrue(noteTexts(doc).contains("13 Una parola spezzata dal salto di pagina."))
    }

    func test_lengthCategory_isRecomputedOnTheMergedNote() {
        let long = String(repeating: "prosegue ancora con altre parole ", count: 4) + "e si chiude."
        let (doc, _) = placed(twoPages(tail: line(long, size: 8, y: 140)))
        let merged = doc.structure.first { $0.type == .NOTE && ($0.text ?? "").hasPrefix("13 ") }
        XCTAssertNotNil(merged)
        XCTAssertEqual(merged?.length_category, lengthCategoryFor(merged?.text ?? ""))
    }

    // MARK: - le guardie, ciascuna con la sua prova al contrario

    // MARK: - secondo gradino: nessuna nota numerata dopo la coda, o successione rotta da un numero spurio

    func test_secondStep_stitches_whenTheNoteFillsTheNextApparatus() {
        // nessuna nota numerata dopo la coda sulla pagina B (la nota riempie l'apparato) e nessun richiamo «14» senza
        // la sua nota: si ricuce
        let (doc, stats) = placed(twoPages(nextNumber: nil))
        XCTAssertEqual(stats.stitchedAdjacentPage, 1)
        XCTAssertEqual(stats.adjacentPageCandidates.first?.succession, "assente")
        XCTAssertTrue(noteTexts(doc).contains("13 Seconda nota che resta aperta e continua sulla pagina seguente fino al punto."))
    }

    func test_secondStep_noStitch_whenTheBodyCallsTheNextNoteThatIsMissing() {
        // il corpo della pagina B richiama la nota 14 (numero in apice), ma nessuna nota 14 c'è sulle pagine A, B e B+1:
        // la «coda» potrebbe essere la nota 14 col marcatore perso → mai fusa
        let pageA = bodyLines("a") + noteLines(["12 Prima nota completa della pagina.",
                                                 "13 Seconda nota che resta aperta e"])
        let call = line("", size: 10, y: 690, spans: [("Una frase del corpo con il richiamo", 10), ("14", 5),
                                                      (" che prosegue.", 10)])
        let pageB = bodyLines("b") + [call] + noteLines(["continua sulla pagina seguente fino al punto."])
        let (_, stats) = placed(extraction([pageA, pageB]))
        XCTAssertEqual(stats.stitchedAdjacentPage, 0)
        XCTAssertEqual(stats.adjacentPageCandidates.first?.nextCallUnmatched, true)
        XCTAssertEqual(stats.adjacentPageCandidates.first?.reason, "richiamo della nota seguente senza nota")
    }

    func test_secondStep_noStitch_whenTheNextNumberSkipsANote() {
        // dopo la coda la nota 15: la 14 manca, e la coda potrebbe essere proprio lei → mai fusa
        let (_, stats) = placed(twoPages(nextNumber: 15))
        XCTAssertEqual(stats.stitchedAdjacentPage, 0)
        XCTAssertEqual(stats.adjacentPageCandidates.first?.succession, "non confermata")
        XCTAssertEqual(stats.adjacentPageCandidates.first?.reason, "successione non confermata: nota seguente mancante")
    }

    func test_secondStep_stitches_whenTheSuccessionBreaksOnASpuriousNumber() {
        // dopo la coda una «nota» con un numero lontano (un frammento che comincia con un numero di pagina): la
        // successione non torna, ma la nota seguente non manca e nessun richiamo resta senza nota → si ricuce
        let (_, stats) = placed(twoPages(nextNumber: 480))
        XCTAssertEqual(stats.stitchedAdjacentPage, 1)
        XCTAssertEqual(stats.adjacentPageCandidates.first?.succession, "non confermata")
    }

    func test_noStitch_whenTheHeadHasNoNumberOfItsOwn() {
        // in fondo alla pagina A un blocco a corpo di nota SENZA numero (un riquadro, una bibliografia): non è la testa
        // di una nota spezzata, anche se resta aperto e la pagina B ne porta la continuazione
        let pageA = bodyLines("a") + noteLines(["un blocco senza numero che resta aperto e"])
        let pageB = bodyLines("b") + noteLines(["continua sulla pagina seguente.", "14 Nota nuova."])
        let (_, stats) = placed(extraction([pageA, pageB]))
        XCTAssertEqual(stats.stitchedAdjacentPage, 0)
        XCTAssertEqual(stats.adjacentPageCandidates.first?.reason, "successione testa senza numero")
    }

    func test_noStitch_whenTheTailSitsAmongTheBodyLines() {
        // una riga a corpo di nota FRA le righe del corpo della pagina B (citazione in corpo minore, glossa, riquadro):
        // anche se comincia in minuscolo e la nota seguente è la 14, non è la continuazione a piè di pagina
        let (_, stats) = placed(twoPages(tailOnTop: true))
        XCTAssertEqual(stats.stitchedAdjacentPage, 0)
        XCTAssertEqual(stats.adjacentPageCandidates.first?.reason, "coda non sotto il corpo")
    }

    func test_noStitch_whenTheTailHasADifferentTypeSize() {
        let (_, stats) = placed(twoPages(tail: line("continua in un corpo diverso fino al punto.", size: 7.0, y: 140)))
        XCTAssertEqual(stats.stitchedAdjacentPage, 0)
        XCTAssertEqual(stats.adjacentPageCandidates.first?.reason, "corpo tipografico diverso")
    }

    func test_sizeGuard_usesTheLargestSpan_soSmallCapsDoNotReject() {
        // la prima riga della coda con un cognome in maiuscoletto (span più piccolo): la media dei caratteri scende, il
        // corpo massimo resta quello della nota → si ricuce
        let tail = line("", size: 8, y: 140, spans: [("1999, p. 12; ", 8), ("ROSSIBIANCHI VERDI NERI", 6.4),
                                                      (" e altri ancora fino al punto.", 8)])
        let (_, stats) = placed(twoPages(tail: tail))
        XCTAssertEqual(stats.stitchedAdjacentPage, 1)
    }

    func test_noStitch_whenTheTailOpensWithTheNextNumberAsADigitRun() {
        // «14, p. 3…» in testa alla coda: non è un marcatore d'apertura per `splitFootnotes` (virgola dopo il numero) e
        // per il predicato è una continuazione (comincia con una cifra), ma il numero è quello della testa più uno →
        // può essere la nota seguente col marcatore guastato: mai fusa, anche con la successione «confermata»
        let (_, stats) = placed(twoPages(tail: line("14, p. 3 e altre righe fino al punto.", size: 8, y: 140)))
        XCTAssertEqual(stats.stitchedAdjacentPage, 0)
        XCTAssertEqual(stats.adjacentPageCandidates.first?.succession, "confermata")
        XCTAssertEqual(stats.adjacentPageCandidates.first?.reason, "coda numerata come la nota seguente")
    }

    func test_noStitch_whenTheHeadIsClosed_andTheSuccessionIsNotConfirmed() {
        // testa chiusa (il predicato respinge) e nessuna nota numerata dopo la coda: nessuna conferma, non si ricuce
        let pageA = bodyLines("a") + noteLines(["12 Prima nota completa della pagina.", "13 Seconda nota chiusa."])
        let pageB = bodyLines("b") + noteLines(["continua sulla pagina seguente."])
        let (_, stats) = placed(extraction([pageA, pageB]))
        XCTAssertEqual(stats.stitchedAdjacentPage, 0)
        XCTAssertEqual(stats.adjacentPageCandidates.first?.reason, "predicato")
    }

    func test_closedHead_withConfirmedSuccession_isStitched() {
        // dal giro «pulizia delle note» (decisione 2 del maintainer): con la successione confermata il predicato non serve
        // più (le prove della regola nuova sono in `AdjacentPageSuccessionTests`)
        let pageA = bodyLines("a") + noteLines(["12 Prima nota completa della pagina.", "13 Seconda nota chiusa."])
        let pageB = bodyLines("b") + noteLines(["continua sulla pagina seguente.", "14 Nota nuova."])
        let (_, stats) = placed(extraction([pageA, pageB]))
        XCTAssertEqual(stats.stitchedAdjacentPage, 1)
        XCTAssertEqual(stats.adjacentPageCandidates.first?.predicate, false)
    }

    func test_noStitch_acrossANonContiguousPage() {
        // pagina in mezzo senza note: la coda due pagine dopo non è candidata (salto di più di una pagina)
        let pageA = bodyLines("a") + noteLines(["12 Prima nota completa della pagina.", "13 Seconda nota aperta e"])
        let pageMid = bodyLines("m")
        let pageC = bodyLines("c") + noteLines(["continua due pagine dopo.", "14 Nota nuova."])
        let (_, stats) = placed(extraction([pageA, pageMid, pageC]))
        XCTAssertEqual(stats.stitchedAdjacentPage, 0)
        XCTAssertTrue(stats.adjacentPageCandidates.isEmpty)
    }

    /// Due ricuciture su due coppie di pagine consecutive, di due note DIVERSE (la 13 fra A e B, la 14 fra B e C).
    func test_twoStitches_onConsecutivePagePairs_joinTwoDifferentNotes() {
        let pageA = bodyLines("a") + noteLines(["12 Prima nota completa della pagina.", "13 Una nota lunga che"])
        let pageB = bodyLines("b") + noteLines(["prosegue sulla seconda pagina e", "14 Nota breve della seconda pagina e"])
        let pageC = bodyLines("c") + noteLines(["chiusa sulla terza.", "15 Nota della terza pagina."])
        let (doc, stats) = placed(extraction([pageA, pageB, pageC]))
        XCTAssertEqual(stats.stitchedAdjacentPage, 2)
        let notes = noteTexts(doc)
        XCTAssertTrue(notes.contains("13 Una nota lunga che prosegue sulla seconda pagina e"))
        XCTAssertTrue(notes.contains("14 Nota breve della seconda pagina e chiusa sulla terza."))
    }

    /// Una catena VERA: la nota 13 riempie tutto l'apparato della pagina B e si chiude sulla C. Il secondo passo vale
    /// solo perché la testa, dopo la prima ricucitura, copre fino alla pagina B (revisione indipendente del giro).
    func test_chain_overThreePages_whenTheMiddleApparatusIsOnlyTheContinuation() {
        let pageA = bodyLines("a") + noteLines(["12 Prima nota completa della pagina.", "13 Una nota lunga che"])
        let pageB = bodyLines("b") + noteLines(["prosegue per tutta la seconda pagina e"])
        let pageC = bodyLines("c") + noteLines(["si chiude sulla terza.", "14 Nota nuova della terza pagina."])
        let (doc, stats) = placed(extraction([pageA, pageB, pageC]))
        XCTAssertEqual(stats.stitchedAdjacentPage, 2)
        let notes = noteTexts(doc)
        XCTAssertTrue(notes.contains("13 Una nota lunga che prosegue per tutta la seconda pagina e si chiude sulla terza."),
                      "la nota intera, nell'ordine: \(notes)")
        XCTAssertTrue(notes.contains { $0.hasPrefix("14 ") })
    }

    // MARK: - guardie provate direttamente su `stitchAdjacentPageFootnotes` (strutture sintetiche)

    /// Una riga di nota alla quota `y` (il fondo della riga), come la vede l'aggancio.
    private func noteSummary(_ text: String, y: Double, size: Double = 8) -> LineSummary {
        summarizeLine(line(text, size: size, y: y))
    }

    /// La testa 13 aperta sulla pagina 0, la sua coda in cima all'apparato della pagina 1, poi la nota 14. Il corpo di
    /// entrambe le pagine finisce alla quota 690; `headY` e `tailY` sono le quote delle righe di nota.
    private func direct(headType: SemanticCategory = .NOTE, tailType: SemanticCategory = .NOTE,
                        headY: Double = 140, tailY: Double = 140) -> (count: Int, candidates: [AdjacentPageStitchCandidate]) {
        let structure = [
            NodeDict(id: "nA", type: headType, page_index: 0, text: "13 Seconda nota che resta aperta e"),
            NodeDict(id: "nB", type: tailType, page_index: 1, text: "continua sulla pagina seguente fino al punto."),
            NodeDict(id: "nC", type: .NOTE, page_index: 1, text: "14 Nota nuova della seconda pagina."),
        ]
        var byId: [String: NodeDict] = [:]
        var order: [String: [String]] = [:]
        for n in structure { byId["f_" + n.id] = n; order[n.id] = ["f_" + n.id] }
        let lines: [String: [LineSummary]] = [
            "nA": [noteSummary("13 Seconda nota che resta aperta e", y: headY)],
            "nB": [noteSummary("continua sulla pagina seguente fino al punto.", y: tailY)],
            "nC": [noteSummary("14 Nota nuova della seconda pagina.", y: tailY - 11)],
        ]
        return stitchAdjacentPageFootnotes(structure, &byId, &order, noteLinesById: lines,
                                           contentBottomByPage: [0: 690, 1: 690])
    }

    func test_direct_stitches_whenEveryGuardPasses() {
        let r = direct()
        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(r.candidates.first?.reason, "ricucita")
    }

    func test_direct_noStitch_whenANodeIsNotANote() {
        for r in [direct(tailType: .EDITORIAL_NOTE), direct(headType: .EDITORIAL_NOTE)] {
            XCTAssertEqual(r.count, 0)
            XCTAssertEqual(r.candidates.first?.reason, "nodo non NOTE")
        }
    }

    func test_direct_noStitch_whenTheHeadSitsAmongTheBodyLines() {
        let r = direct(headY: 740)   // la testa sta sopra il fondo del corpo della sua pagina
        XCTAssertEqual(r.count, 0)
        XCTAssertEqual(r.candidates.first?.reason, "testa non sotto il corpo")
    }

    func test_direct_noStitch_whenTheTailSitsAmongTheBodyLines() {
        let r = direct(tailY: 740)
        XCTAssertEqual(r.count, 0)
        XCTAssertEqual(r.candidates.first?.reason, "coda non sotto il corpo")
    }

    // MARK: - dove la ricucitura nuova non vale

    func test_codici_areExcluded() {
        // firma dei codici: pagina tascabile 357×547, produttore PDFsharp, corpo 7,5
        func bodyC(_ tag: String) -> [PdfTextLine] {
            (0..<6).map { line("Riga di corpo \(tag) numero \($0) del testo", size: 7.5, x: 30, y: 500 - Double($0) * 10,
                               width: 300) }
        }
        func notesC(_ texts: [String]) -> [PdfTextLine] {
            texts.enumerated().map { line($0.element, size: 6, x: 30, y: 90 - Double($0.offset) * 8, width: 300) }
        }
        let pageA = bodyC("a") + notesC(["12 Prima nota completa.", "13 Seconda nota aperta e"])
        let pageB = bodyC("b") + notesC(["continua sulla pagina seguente.", "14 Nota nuova."])
        let ex = extraction([pageA, pageB], width: 357, height: 547, producer: "PDFsharp 1.31")
        XCTAssertTrue(estimateProfile(ex).isCodici, "la fixture ha la firma dei codici")
        let (_, stats) = bindAndPlaceNotes(buildDocumentFromPdf(ex, sourceName: "c.pdf"), ex)
        XCTAssertEqual(stats.stitchedAdjacentPage, 0)
        XCTAssertTrue(stats.adjacentPageCandidates.isEmpty)
    }

    func test_estratto_keepsItsOwnPath() {
        // firma dell'Estratto: «CAPITOLO I» seguito da un titolo tutto maiuscolo a taglia ≈ corpo × 1,04
        let opening = [line("CAPITOLO I", size: 10, y: 800), line("TITOLO DEL CAPITOLO IN MAIUSCOLO", size: 10.4, y: 785)]
        let pageA = opening + bodyLines("a") + noteLines(["12 Prima nota completa della pagina.",
                                                          "13 Seconda nota che resta aperta e"])
        let pageB = bodyLines("b") + noteLines(["continua sulla pagina seguente.", "14 Nota nuova."])
        let ex = extraction([pageA, pageB])
        XCTAssertTrue(estimateProfile(ex).isEstrattoChrome, "la fixture ha la firma dell'Estratto")
        let (doc, stats) = placed(ex)
        XCTAssertEqual(stats.stitchedAdjacentPage, 0, "nell'Estratto la ricucitura nuova non gira")
        XCTAssertTrue(stats.adjacentPageCandidates.isEmpty)
        XCTAssertEqual(stats.stitchedCrossPage, 1, "ricuce il percorso storico dell'Estratto, invariato")
        XCTAssertTrue(noteTexts(doc).contains("13 Seconda nota che resta aperta e continua sulla pagina seguente."))
    }

    // MARK: - il testo non cambia: si sposta soltanto

    func test_lettersAndDigits_arePreserved() {
        let ex = twoPages()
        let before = buildDocumentFromPdf(ex, sourceName: "t.pdf")
        let (after, _) = bindAndPlaceNotes(before, ex)
        func letters(_ d: ScabopdfDocument) -> [Character] {
            d.structure.flatMap { Array(($0.text ?? "").filter { $0.isLetter || $0.isNumber }) }.sorted()
        }
        XCTAssertEqual(letters(before), letters(after))
    }
}
