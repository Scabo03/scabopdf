//
//  ManualLevelsTests.swift
//  ScaboCoreTests
//
//  Livelli dei titoli nei manuali (D.10): fusione dell'unità «etichetta + titolo» dentro `pageItems` e ricalcolo dei
//  livelli in `normalizeManualLevels`. Ogni regola ha la sua prova al contrario. Testi di prova inventati.
//

import XCTest
@testable import ScaboCore

final class ManualLevelsTests: XCTestCase {

    // MARK: - Parte 2: i livelli (sui nodi)

    private func h(_ level: Int, _ text: String, page: Int = 3) -> NodeDict {
        let type: SemanticCategory = [.HEADING_1, .HEADING_2, .HEADING_3, .HEADING_4][level - 1]
        return NodeDict(id: "n", type: type, page_index: page, text: text, level: level)
    }
    private func body(_ text: String = "Testo di prova del corpo.", page: Int = 3) -> NodeDict {
        NodeDict(id: "b", type: .BODY, page_index: page, text: text)
    }
    private func levels(_ nodes: [NodeDict]) -> [Int] { nodes.compactMap { $0.type.rawValue.hasPrefix("HEADING_") ? $0.level : nil } }

    func test_unitIsParent_andNumberedTitlesAreRelative() {
        // l'etichetta del capitolo è diventata titolo DOPO i numerati (livello di emissione 4): la cura li mette sotto
        var nodes = [h(2, "CAPITOLO I Titolo di prova del capitolo"), body(),
                     h(4, "1. Primo paragrafo di prova"), body(), h(4, "1.1. Sotto-paragrafo di prova"), body(),
                     h(4, "2. Secondo paragrafo di prova"), body()]
        normalizeManualLevels(&nodes)
        XCTAssertEqual(levels(nodes), [1, 2, 3, 2], "capitolo, paragrafo, sotto-paragrafo, paragrafo (compattati)")
    }

    func test_unitStaysParent_evenAtTheSameLevelOfTheNumbered() {
        // prova al contrario della regola del fratello: un'UNITÀ allo stesso livello del numerato resta genitore
        var nodes = [h(1, "PARTE I Parte di prova"), h(2, "CAPITOLO I Capitolo di prova"), body(),
                     h(2, "1. Paragrafo di prova"), body()]
        normalizeManualLevels(&nodes)
        XCTAssertEqual(levels(nodes), [1, 2, 3])
    }

    func test_unnumberedSiblingAtSameLevel_isNotAParent() {
        // il lettore di sistema stacca il numero da un titolo di sezione: il titolo senza numero è un fratello
        var nodes = [h(1, "Titolo di prova dell'articolo"), body(),
                     h(2, "1. Prima sezione di prova"), body(), h(2, "seconda sezione di prova senza numero"), body(),
                     h(2, "3. Terza sezione di prova"), body()]
        normalizeManualLevels(&nodes)
        XCTAssertEqual(levels(nodes), [1, 2, 2, 2], "le tre sezioni restano sorelle")
        // prova al contrario: un titolo non numerato di livello SUPERIORE resta genitore del numerato
        var parent = [h(1, "Titolo di prova dell'articolo"), body(), h(2, "Titolo di prova di una parte"), body(),
                      h(3, "1. Sezione di prova"), body()]
        normalizeManualLevels(&parent)
        XCTAssertEqual(levels(parent), [1, 2, 3])
    }

    func test_fragmentOfASplitNumberedTitle_staysAtItsLevel() {
        // «5. Titolo … punto.» + «seguito del titolo» (due nodi): il frammento non è genitore del «6.»
        var nodes = [h(2, "CAPITOLO II Capitolo di prova"), body(),
                     h(4, "5. Titolo di prova con un punto interno."), h(4, "Seguito del titolo di prova"), body(),
                     h(4, "6. Paragrafo seguente di prova"), body()]
        normalizeManualLevels(&nodes)
        XCTAssertEqual(levels(nodes), [1, 2, 2, 2])
    }

    func test_classesInStrictOrder() {
        // PARTE e CAPITOLO arrivati entrambi a livello 2: PARTE sale a 1, CAPITOLO resta 2, SEZIONE va a 3
        var nodes = [h(2, "PARTE I Parte di prova"), h(2, "CAPITOLO I Capitolo di prova"), h(2, "Sezione prima Sezione di prova"),
                     body(), h(4, "1. Paragrafo di prova"), body()]
        normalizeManualLevels(&nodes)
        XCTAssertEqual(levels(nodes), [1, 2, 3, 4])
    }

    func test_ordinalIsAnUppercaseRomanOrAWord_notAnItalianWord() {
        // «Titolo di …» e «TITOLO DI …» non sono etichette (le lettere di «di» sono romane, ma non è un ordinale)
        XCTAssertFalse(isUnitWithTitle("Titolo di prova del paragrafo"))
        XCTAssertFalse(isUnitWithTitle("TITOLO DI PROVA DEL CAPITOLO"))
        XCTAssertNil(manualUnitLabelKeyword("Capo di"))
        // prova al contrario: le etichette vere
        XCTAssertTrue(isUnitWithTitle("TITOLO II Titolo di prova"))
        XCTAssertTrue(isUnitWithTitle("Sezione prima – Titolo di prova"))
        XCTAssertEqual(manualUnitLabelKeyword("CAPITOLO LXXXII"), "CAPITOLO")
        XCTAssertEqual(manualUnitLabelKeyword("Parte generale"), "Parte")
        XCTAssertEqual(manualUnitLabelKeyword("CaPItolo VENtiquattresimo"), "CaPItolo", "ordinale composto in lettere")
        XCTAssertNil(manualUnitLabelKeyword("Capitolo Vento"), "il romano deve occupare tutta la parola")
    }

    func test_titleAloneOnADividerPage_beforeAUnit_isAPart() {
        // la parte stampata senza la parola «PARTE»: solo il suo titolo su una pagina, poi il capitolo
        var nodes = [h(3, "TITOLO DI PROVA DELLA PARTE", page: 20),
                     h(2, "CAPITOLO I Capitolo di prova", page: 22), body(page: 22), h(4, "§ 1. Paragrafo di prova.", page: 22), body(page: 22)]
        normalizeManualLevels(&nodes)
        XCTAssertEqual(levels(nodes), [1, 2, 3], "parte, capitolo, paragrafo")
        // prova al contrario: lo stesso titolo con altro testo sulla pagina non è una pagina divisoria
        var notDivider = [h(3, "TITOLO DI PROVA DELLA PARTE", page: 20), body(page: 20),
                          h(2, "CAPITOLO I Capitolo di prova", page: 22), body(page: 22), h(4, "§ 1. Paragrafo di prova.", page: 22), body(page: 22)]
        normalizeManualLevels(&notDivider)
        XCTAssertEqual(levels(notDivider), [2, 1, 2])
    }

    func test_noUnitsNoNumbered_levelsUnchanged() {
        // nessuna unità, nessun numerato: niente struttura da manuale, i livelli tipografici restano com'erano
        var nodes = [h(2, "Titolo di prova"), body(), h(3, "Sottotitolo di prova"), body()]
        XCTAssertEqual(normalizeManualLevels(&nodes), 0)
        XCTAssertEqual(levels(nodes), [2, 3])
        // prova al contrario: con un titolo numerato la compattazione agisce
        var numbered = [h(2, "Titolo di prova"), body(), h(3, "1. Sottotitolo numerato di prova"), body()]
        normalizeManualLevels(&numbered)
        XCTAssertEqual(levels(numbered), [1, 2])
    }

    // MARK: - Parte 1: la fusione dell'unità (dentro pageItems)

    private func line(_ text: String, size: Double, x0: Double, x1: Double, top: Double, color: String = "#000000") -> PdfTextLine {
        let box = BBox(x: x0, y: top - size * 1.2, width: x1 - x0, height: size * 1.2)
        return PdfTextLine(spans: [PdfSpan(text: text, fontSize: size, bold: false, italic: false, color: color, bbox: box)], bbox: box)
    }
    private func bodyLines(_ n: Int, top: Double, tag: String) -> [PdfTextLine] {
        (0..<n).map { line("Riga di corpo \(tag) \($0) abbastanza lunga da riempire la colonna del volume di prova.", size: 10,
                           x0: 60, x1: 420, top: top - Double($0) * 13) }
    }
    /// Documento di 4 pagine: corpo + nota a 8 pt (stile secondario, il documento non è monotipografico).
    private func items(_ special: [PdfTextLine]) -> [GenItem] {
        var pages = (0..<4).map { i in
            PdfPageExtraction(pageIndex: i, width: 480, height: 680,
                              lines: bodyLines(10, top: 600, tag: "base \(i)") + [line("1 Nota di prova a piè di pagina \(i).", size: 8, x0: 60, x1: 300, top: 80)])
        }
        pages[2] = PdfPageExtraction(pageIndex: 2, width: 480, height: 680,
                                     lines: special + [line("2 Nota di prova a piè della pagina speciale.", size: 8, x0: 60, x1: 300, top: 60)])
        let e = PdfExtraction(version: 2, pageCount: 4, pages: pages)
        let profile = estimateProfile(e)
        XCTAssertNil(profile.mono)
        return pageItems(pages[2], profile, [], 0, [:])
    }
    private func headings(_ it: [GenItem]) -> [String] {
        it.compactMap { if case let .heading(sm, _) = $0 { return sm.text } else { return nil } }
    }

    func test_labelAndCenteredTitle_becomeOneHeading() {
        let lines = [line("CAPITOLO II", size: 12, x0: 200, x1: 280, top: 620),
                     line("IL TITOLO DI PROVA DEL CAPITOLO", size: 14, x0: 140, x1: 340, top: 595)] + bodyLines(8, top: 560, tag: "c")
        XCTAssertEqual(headings(items(lines)), ["CAPITOLO II IL TITOLO DI PROVA DEL CAPITOLO"])
    }

    func test_numberedTitleAfterLabel_isNeverAbsorbed() {
        // prova al contrario: dopo l'etichetta un titolo NUMERATO resta a sé
        let lines = [line("CAPITOLO II", size: 12, x0: 200, x1: 280, top: 620),
                     line("1. Paragrafo di prova numerato", size: 14, x0: 140, x1: 340, top: 595)] + bodyLines(8, top: 560, tag: "c")
        XCTAssertFalse(headings(items(lines)).contains { $0.hasPrefix("CAPITOLO II 1.") })
    }

    func test_sectionUnitAfterChapterTitle_isNotAbsorbed() {
        // «Sezione A Titolo» è un'unità a sé: non entra nel titolo del capitolo che la precede
        let lines = [line("Capitolo III", size: 12, x0: 60, x1: 140, top: 620),
                     line("TITOLO DI PROVA DEL CAPITOLO", size: 14, x0: 60, x1: 300, top: 600),
                     line("Sezione A Titolo di prova della sezione", size: 14, x0: 60, x1: 330, top: 580)] + bodyLines(8, top: 550, tag: "s")
        let hs = headings(items(lines))
        XCTAssertTrue(hs.contains("Capitolo III TITOLO DI PROVA DEL CAPITOLO"), "\(hs)")
        XCTAssertTrue(hs.contains("Sezione A Titolo di prova della sezione"), "\(hs)")
    }

    func test_unitTitleWrappedInLowercaseContinuation_isJoined() {
        let lines = [line("Sezione B Titolo di prova della sezione che va", size: 14, x0: 60, x1: 380, top: 620),
                     line("a capo sulla riga seguente", size: 14, x0: 150, x1: 290, top: 560)] + bodyLines(8, top: 530, tag: "w")
        XCTAssertEqual(headings(items(lines)), ["Sezione B Titolo di prova della sezione che va a capo sulla riga seguente"])
    }

    func test_titleLostAtTheHeadOfTheBody_isRecovered() {
        // dopo l'etichetta viene il corpo: le sue prime righe maiuscole e centrate sono il titolo
        let lines = [line("CAPITOLO IV", size: 12, x0: 205, x1: 275, top: 620),
                     line("TITOLO DI PROVA IN TESTA AL CORPO", size: 10, x0: 140, x1: 340, top: 600)] + bodyLines(8, top: 580, tag: "t")
        let it = items(lines)
        XCTAssertTrue(headings(it).contains("CAPITOLO IV TITOLO DI PROVA IN TESTA AL CORPO"), "\(headings(it))")
    }
}
