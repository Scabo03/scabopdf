//
//  WordBoundaryRepairTests.swift
//  ScaboCoreTests
//
//  Riparazione dei confini di parola persi da PDFKit 27 (`repairWordBoundaries`) e rimozione dei
//  segnaposto d'immagine U+FFFC (`removingObjectReplacementCharacters`). Regola d'oro: solo spazi,
//  mai lettere; nel dubbio (ambiguità, testo spaziato) non si tocca.
//

import XCTest
@testable import ScaboCore

final class WordBoundaryRepairTests: XCTestCase {

    private func span(_ t: String, x: Double = 0, w: Double = 10) -> PdfSpan {
        PdfSpan(text: t, fontSize: 11, bold: false, italic: false, color: "#000000", bbox: BBox(x: x, y: 0, width: w, height: 11))
    }
    private func line(_ texts: String...) -> PdfTextLine {
        PdfTextLine(spans: texts.map { span($0) }, bbox: BBox(x: 0, y: 0, width: 100, height: 11))
    }
    private func text(_ l: PdfTextLine) -> String { l.spans.map { $0.text }.joined() }

    /// Run alla maniera InDesign: Tc 0,23 em dopo ogni glifo, annullato dentro le parole (−0,02), pieno fra le parole.
    private func tracked(_ words: [String], tc: Double = 0.23, owns: Bool = true, continues: Bool = false, sameLine: Bool = false) -> GlyphRun {
        var glyphs: [String] = [], gaps: [Double] = []
        for (wi, w) in words.enumerated() {
            let chars = Array(w).map { String($0) }
            for (ci, ch) in chars.enumerated() {
                glyphs.append(ch)
                let lastOfWord = ci == chars.count - 1
                gaps.append(lastOfWord ? tc : -0.02)   // anche l'ultimo glifo lascia il suo Tc
                _ = wi
            }
        }
        return GlyphRun(glyphs: glyphs, gapsEm: gaps, ownsGaps: owns, continuesPrevious: continues, sameLineAsPrevious: sameLine)
    }

    // MARK: inserimento

    func test_insertsSpacesWhereTcGapAndLineHasNone() {
        let lines = [line("frase di prova senza pretese", ",edinca-")]
        let run = tracked([",", "ed", "in", "ca-"])
        let r = repairWordBoundaries(lines, runs: [run])
        XCTAssertEqual(text(r.lines[0]), "frase di prova senza pretese, ed in ca-")
        XCTAssertEqual(r.inserted, 3)
        XCTAssertEqual(r.lines[0].spans[1].bbox, lines[0].spans[1].bbox, "i riquadri non cambiano")
        XCTAssertEqual(r.lines[0].spans.count, 2)
    }

    func test_identityWhenLineAlreadyHasSpaces() {
        let lines = [line("frase di prova senza pretese", ", ed in ca-")]
        let r = repairWordBoundaries(lines, runs: [tracked([",", "ed", "in", "ca-"])])
        XCTAssertEqual(r.lines, lines)
        XCTAssertEqual(r.inserted, 0)
        XCTAssertEqual(r.alreadySpaced, 3)
    }

    func test_onlySpacesEverChange_lettersIdentical() {
        let lines = [line("inomidellecosevicineenote")]
        let r = repairWordBoundaries(lines, runs: [tracked(["i", "nomi", "delle", "cose", "vicine", "e", "note"])])
        XCTAssertEqual(text(r.lines[0]), "i nomi delle cose vicine e note")
        XCTAssertEqual(text(r.lines[0]).filter { !$0.isWhitespace }, text(lines[0]))
    }

    func test_junctionGapBetweenContiguousRuns_ownedByPreviousRun() {
        // «a un» con Tc positivo, poi (senza Td) «patto» in corsivo con Tc negativo: lo scarto di
        // giunzione è l'ultimo scarto del run precedente, che lo possiede.
        let lines = [line("vale aun", "patto chiaro")]
        let r1 = tracked(["a", "un"])
        let r2 = GlyphRun(glyphs: ["p", "a", "t", "t", "o"], gapsEm: [-0.02, -0.02, -0.02, -0.02, 0.0],
                          ownsGaps: false, continuesPrevious: true, sameLineAsPrevious: true)
        let r = repairWordBoundaries(lines, runs: [r1, r2])
        XCTAssertEqual(text(r.lines[0]), "vale a un patto chiaro")
        XCTAssertEqual(r.inserted, 2)
    }

    func test_gapNotOwnedByTcRun_isNeverTouched() {
        // Stesso vuoto, ma il run non ha Tc > 0: lo scarto viene da TJ/Td, che PDFKit gestisce da sé.
        let lines = [line("alfabeta")]
        let run = GlyphRun(glyphs: ["a", "l", "f", "a", "b", "e", "t", "a"], gapsEm: [0, 0, 0, 0.3, 0, 0, 0, 0],
                           ownsGaps: false, continuesPrevious: false, sameLineAsPrevious: false)
        XCTAssertEqual(repairWordBoundaries(lines, runs: [run]).lines, lines)
    }

    // MARK: guardie

    func test_uniformlyTrackedTitle_isLeftAlone() {
        // «I N D I C E»: tutti gli scarti larghi, nessuna coppia stretta → non è un confine di parola.
        let lines = [line("INDICE")]
        let run = GlyphRun(glyphs: ["I", "N", "D", "I", "C", "E"], gapsEm: [0.23, 0.23, 0.23, 0.23, 0.23, 0.23],
                           ownsGaps: true, continuesPrevious: false, sameLineAsPrevious: false)
        let r = repairWordBoundaries(lines, runs: [run])
        XCTAssertEqual(r.lines, lines)
        XCTAssertEqual(r.inserted, 0)
    }

    func test_trackedTitleWithOneKernedPair_isLeftAlone() {
        // «AVVERTENZA» spaziato con una sola coppia crenata (A|V): una coppia stretta non basta a sbloccare
        // otto candidati — le strette devono essere almeno quante i candidati.
        let lines = [line("AVVERTENZA")]
        let run = GlyphRun(glyphs: ["A", "V", "V", "E", "R", "T", "E", "N", "Z", "A"],
                           gapsEm: [-0.15, 0.23, 0.23, 0.23, 0.23, 0.23, 0.23, 0.23, 0.23, 0.23],
                           ownsGaps: true, continuesPrevious: false, sameLineAsPrevious: false)
        XCTAssertEqual(repairWordBoundaries(lines, runs: [run]).lines, lines)
    }

    func test_leaderDotsWithoutLetters_areLeftAlone() {
        // Riga di soli puntini di conduzione con Tc: la forma dei leader governa il riconoscimento degli
        // indici e non è una parola → nessun inserimento.
        let lines = [line("........")]
        let run = GlyphRun(glyphs: Array(repeating: ".", count: 8), gapsEm: [0.3, -0.02, 0.3, -0.02, 0.3, -0.02, 0.3, 0],
                           ownsGaps: true, continuesPrevious: false, sameLineAsPrevious: false)
        XCTAssertEqual(repairWordBoundaries(lines, runs: [run]).lines, lines)
    }

    func test_belowThreshold_noInsertion() {
        let lines = [line("alfabeta")]
        let run = GlyphRun(glyphs: ["a", "l", "f", "a", "b", "e", "t", "a"], gapsEm: [-0.02, -0.02, -0.02, 0.12, -0.02, -0.02, -0.02, 0],
                           ownsGaps: true, continuesPrevious: false, sameLineAsPrevious: false)
        XCTAssertEqual(repairWordBoundaries(lines, runs: [run]).lines, lines)
    }

    func test_ambiguousChain_isSkipped_unlessNeighbourDisambiguates() {
        // «,che» compare due volte nella pagina: da solo è ambiguo → nulla.
        let lines = [line("prima parola,che segue"), line("altra cosa,che resta")]
        let amb = tracked([",", "che"])
        let r = repairWordBoundaries(lines, runs: [amb])
        XCTAssertEqual(r.lines, lines)
        XCTAssertEqual(r.skippedAlignment, 1)
        // Con il vicino sulla stessa riga («parola») l'ago diventa univoco → spazio inserito nella riga giusta.
        let prev = GlyphRun(glyphs: ["p", "a", "r", "o", "l", "a"], gapsEm: [-0.02, -0.02, -0.02, -0.02, -0.02, 0],
                            ownsGaps: false, continuesPrevious: false, sameLineAsPrevious: false)
        var amb2 = amb; amb2.sameLineAsPrevious = true
        let r2 = repairWordBoundaries(lines, runs: [prev, amb2])
        XCTAssertEqual(text(r2.lines[0]), "prima parola, che segue")
        XCTAssertEqual(text(r2.lines[1]), "altra cosa,che resta")
    }

    func test_chainNotFoundInAnyLine_isSkipped() {
        let lines = [line("tutt'altro testo")]
        let r = repairWordBoundaries(lines, runs: [tracked([",", "ed", "in", "ca-"])])
        XCTAssertEqual(r.lines, lines)
        XCTAssertEqual(r.skippedAlignment, 3)
    }

    func test_ligatureGlyphWithTwoCharacters() {
        // «fi» è un glifo solo: il confine cade dopo il suo ULTIMO carattere.
        let lines = [line("laﬁne")]  // PDFKit può dare la legatura o le due lettere: qui le due lettere
        let lines2 = [line("lafine")]
        let run = GlyphRun(glyphs: ["l", "a", "fi", "n", "e"], gapsEm: [-0.02, 0.23, -0.02, -0.02, 0],
                           ownsGaps: true, continuesPrevious: false, sameLineAsPrevious: false)
        XCTAssertEqual(text(repairWordBoundaries(lines2, runs: [run]).lines[0]), "la fine")
        // con la legatura nella riga l'ago non combacia → nulla (fail-safe)
        XCTAssertEqual(repairWordBoundaries(lines, runs: [run]).lines, lines)
    }

    func test_insertionAcrossSpanBoundary_goesAtEndOfFirstSpan() {
        let lines = [line("certa", "misura")]
        let run = tracked(["certa", "misura"])
        let r = repairWordBoundaries(lines, runs: [run])
        XCTAssertEqual(r.lines[0].spans.map { $0.text }, ["certa ", "misura"])
    }

    func test_emptyInputs() {
        XCTAssertEqual(repairWordBoundaries([], runs: [tracked(["a", "b"])]).lines, [])
        let lines = [line("abc")]
        XCTAssertEqual(repairWordBoundaries(lines, runs: []).lines, lines)
        let bad = GlyphRun(glyphs: ["a", "b"], gapsEm: [0.3], ownsGaps: true, continuesPrevious: false, sameLineAsPrevious: false)
        XCTAssertEqual(repairWordBoundaries(lines, runs: [bad]).lines, lines, "run malformato ignorato")
    }

    // MARK: U+FFFC

    func test_objectReplacement_lineOnlyPlaceholder_isDropped() {
        let lines = [line("\u{FFFC}"), line("testo vero")]
        XCTAssertEqual(removingObjectReplacementCharacters(lines), [lines[1]])
    }

    func test_objectReplacement_insideText_isRemoved_bboxKept() {
        let lines = [line("17\u{FFFC}"), line("\u{FFFC} IL PROVVEDIMENTO")]
        let r = removingObjectReplacementCharacters(lines)
        XCTAssertEqual(r.map(text), ["17", " IL PROVVEDIMENTO"])
        XCTAssertEqual(r[0].bbox, lines[0].bbox)
    }

    func test_objectReplacement_identityWhenAbsent() {
        let lines = [line("nulla da togliere", "qui")]
        XCTAssertEqual(removingObjectReplacementCharacters(lines), lines)
    }

    func test_objectReplacement_spanOnlyPlaceholder_isDroppedButLineKept() {
        let lines = [PdfTextLine(spans: [span("\u{FFFC}"), span("Titolo")], bbox: BBox(x: 0, y: 0, width: 50, height: 11))]
        let r = removingObjectReplacementCharacters(lines)
        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(r[0].spans.map { $0.text }, ["Titolo"])
    }
}
