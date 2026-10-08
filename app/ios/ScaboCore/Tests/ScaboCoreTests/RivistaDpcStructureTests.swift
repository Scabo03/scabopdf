//
//  RivistaDpcStructureTests.swift
//  ScaboCoreTests
//
//  Ramo Riviste — porta DPC, foglia STRUTTURA: il testo bianco della fascia verde si legge, il titolo
//  della fascia diventa UN titolo (sezione H1 / articolo H2), le traduzioni grigie sono corpo, il grande
//  numero di paragrafo si appaia per geometria al suo titolo verde (H3/H4), un numero senza titolo resta
//  testo, una riga colorata dentro una nota resta nella nota. Ogni regola ha la sua prova al contrario
//  fuori dalla porta (geometria diversa → comportamento del tronco). Testi di prova.
//
//  Coordinate PDFKit: origine in basso a sinistra, `bbox.y` grande = in alto nella pagina.
//

import XCTest
@testable import ScaboCore

final class RivistaDpcStructureTests: XCTestCase {

    private let white = "#FFFFFF"
    private let grey = "#D1D3D4"
    private let green = "#577E33"

    private func line(_ text: String, size: Double, x0: Double = 154, x1: Double = 520, top: Double,
                      color: String = "#000000") -> PdfTextLine {
        let box = BBox(x: x0, y: top - size * 1.2, width: x1 - x0, height: size * 1.2)
        return PdfTextLine(spans: [PdfSpan(text: text, fontSize: size, bold: false, italic: false, color: color, bbox: box)],
                           bbox: box)
    }
    /// Corpo nero a 10 pt, colonna x0 154 → 520, a partire dalla quota `top` verso il basso.
    private func body(_ n: Int, top: Double, tag: String) -> [PdfTextLine] {
        (0..<n).map { line("Riga di corpo \(tag) numero \($0) abbastanza lunga da riempire la colonna di prova.",
                           size: 10, top: top - Double($0) * 13) }
    }
    private func page(_ idx: Int, _ lines: [PdfTextLine], w: Double = 567, h: Double = 814) -> PdfPageExtraction {
        PdfPageExtraction(pageIndex: idx, width: w, height: h, lines: lines)
    }
    /// Documento di 4 pagine con la pagina di prova in posizione 2 (le altre: corpo e una nota a piè, per la stima
    /// del profilo). La nota a 8 pt su ogni pagina è uno stile secondario: senza, il documento sintetico sarebbe
    /// «monotipografico» e si accenderebbe il canale delle dispense, che nella DPC non c'è.
    private func items(_ special: [PdfTextLine], w: Double = 567, h: Double = 814) -> [GenItem] {
        var pages = (0..<4).map { page($0, body(12, top: 700, tag: "base \($0)")
            + [line("1 Nota di prova a piè della pagina \($0).", size: 8, x0: 77, top: 90)], w: w, h: h) }
        pages[2] = page(2, special + [line("2 Nota di prova a piè della pagina speciale.", size: 8, x0: 77, top: 60)], w: w, h: h)
        let e = PdfExtraction(version: 2, pageCount: pages.count, pages: pages)
        let profile = estimateProfile(e)
        XCTAssertNil(profile.mono, "il documento di prova non deve essere monotipografico")
        return pageItems(pages[2], profile, [], 0, [:])
    }
    private func headings(_ items: [GenItem]) -> [String] {
        items.compactMap { if case let .heading(sm, level) = $0 { return "H\(level) \(sm.text)" } else { return nil } }
    }
    private func runs(_ items: [GenItem]) -> [String] {
        items.compactMap { if case let .run(_, ls) = $0 { return joinLines(ls.map { $0.text }) } else { return nil } }
    }

    // ── Titolo della fascia ────────────────────────────────────────────────────────────────────

    private func articleOpener() -> [PdfTextLine] {
        [line("Titolo di prova di un articolo", size: 18, x0: 43, top: 740, color: white),
         line("che va a capo sulla seconda riga", size: 18, x0: 43, top: 719, color: white),
         line("Traduzione di prova del titolo", size: 18, x0: 43, top: 677, color: grey),
         line("seconda riga della traduzione", size: 18, x0: 43, top: 656, color: grey),
         line("Altra traduzione di prova", size: 18, x0: 43, top: 620, color: grey),
         line("Autore Di Prova", size: 11, x0: 230, top: 543, color: white),
         line("Professore di prova di una università di prova", size: 9, x0: 174, top: 530, color: white)]
            + body(10, top: 480, tag: "abstract")
    }

    func test_articleBand_titleFused_translationsAndAuthorAreBody() {
        let it = items(articleOpener())
        XCTAssertEqual(headings(it), ["H2 Titolo di prova di un articolo che va a capo sulla seconda riga"],
                       "le righe bianche del titolo sono UN titolo d'articolo (H2)")
        let r = runs(it)
        XCTAssertTrue(r.contains("Traduzione di prova del titolo seconda riga della traduzione"), "\(r)")
        XCTAssertTrue(r.contains("Altra traduzione di prova"), "una traduzione per blocco: \(r)")
        XCTAssertTrue(r.contains("Autore Di Prova Professore di prova di una università di prova"),
                      "autore e affiliazione bianchi sono corpo, in un blocco proprio: \(r)")
    }

    func test_articleBand_outsideGate_whiteIsDropped() {
        // prova al contrario: stessa pagina fuori dalla geometria DPC → il tronco scarta il bianco (ancore invisibili)
        let it = items(articleOpener(), w: 595, h: 842)
        let all = (headings(it) + runs(it)).joined(separator: " ")
        XCTAssertFalse(all.contains("Titolo di prova di un articolo"), "fuori dalla porta il bianco non si legge")
        XCTAssertFalse(all.contains("Autore Di Prova"))
    }

    func test_sectionOpener_isLevelOne() {
        // fascia alta della pagina d'apertura di sezione: titolo a ~26 % dall'alto
        let lines = [line("Sezione di prova della rivista", size: 18, x0: 43, top: 600, color: white),
                     line("Traducción de prueba", size: 14, x0: 43, top: 578, color: grey),
                     line("Test translation", size: 14, x0: 43, top: 557, color: grey)]
        XCTAssertEqual(headings(items(lines)), ["H1 Sezione di prova della rivista"])
    }

    func test_coverNumberAndIssn_areNotTitles() {
        // in copertina il numero del fascicolo (senza lettere) e l'ISSN (in fondo alla pagina) non sono titoli
        let lines = [line("9/2031", size: 26, x0: 430, top: 60, color: white),
                     line("ISSN 0000-0000", size: 14, x0: 60, top: 75, color: white)] + body(6, top: 700, tag: "copertina")
        XCTAssertEqual(headings(items(lines)), [])
    }

    // ── Paragrafi ──────────────────────────────────────────────────────────────────────────────

    func test_paragraphNumber_pairsWithTitle_evenWithInternalPeriod() {
        // numero a 30 pt a sinistra, titolo verde a 14 pt su due righe accanto; la prima riga finisce con «c.d.»
        let lines = body(4, top: 760, tag: "prima") + [
            line("5.", size: 30, x0: 77, x1: 100, top: 690, color: green),
            line("Quarzo blu della prova numero cinque fino al c.d.", size: 14, top: 680, color: green),
            line("vertice verde.", size: 14, top: 663, color: green)] + body(4, top: 630, tag: "dopo")
        XCTAssertEqual(headings(items(lines)), ["H3 5. Quarzo blu della prova numero cinque fino al c.d. vertice verde."],
                       "numero e titolo affiancati sono un titolo solo; il punto interno non lo spezza")
    }

    func test_stackedNumbers_pairByGeometry_andDepthGivesLevel() {
        // «4.» e «4.1.» impilati arrivano prima dei due titoli: l'appaiamento è per geometria, non per ordine
        let lines = body(3, top: 760, tag: "prima") + [
            line("4.", size: 30, x0: 77, x1: 100, top: 690, color: green),
            line("4.1.", size: 30, x0: 77, x1: 120, top: 640, color: green),
            line("Titolo di prova del paragrafo quattro.", size: 14, top: 680, color: green),
            line("Titolo di prova del sottoparagrafo.", size: 14, top: 630, color: green)] + body(3, top: 600, tag: "dopo")
        XCTAssertEqual(headings(items(lines)), ["H3 4. Titolo di prova del paragrafo quattro.",
                                                "H4 4.1. Titolo di prova del sottoparagrafo."])
    }

    func test_numberListedFirstOnPage_titleStaysInItsPlace() {
        // regressione trovata in rete: PDFKit elenca il grande numero in testa alle righe della pagina; il titolo
        // si emette dove comincia il titolo, dopo la continuazione del paragrafo della pagina precedente
        let lines = [line("4.", size: 30, x0: 77, x1: 100, top: 690, color: green)]
            + [line("continuazione minuscola del paragrafo precedente che arriva dalla pagina prima.", size: 10, top: 760)]
            + body(3, top: 745, tag: "prima") + [line("Titolo di prova del paragrafo quattro.", size: 14, top: 680, color: green)]
            + body(4, top: 650, tag: "dopo")
        let it = items(lines)
        guard case let .run(.body, first)? = it.first else { return XCTFail("prima il corpo: \(it)") }
        XCTAssertTrue(first[0].text.hasPrefix("continuazione minuscola"), "\(first.map { $0.text })")
        XCTAssertEqual(headings(it), ["H3 4. Titolo di prova del paragrafo quattro."])
    }

    func test_lineEndHyphen_isKeptInTitlesAndTranslations() {
        // nei titoli e nelle traduzioni della fascia il trattino a fine riga è lessicale (composti): si conserva
        let lines = body(3, top: 760, tag: "prima") + [
            line("4.", size: 30, x0: 77, x1: 100, top: 690, color: green),
            line("Titolo di prova del concetto alfa-", size: 14, top: 680, color: green),
            line("beta di prova.", size: 14, top: 663, color: green)] + body(3, top: 630, tag: "dopo")
        XCTAssertEqual(headings(items(lines)), ["H3 4. Titolo di prova del concetto alfa-beta di prova."])
        let band = [line("Titolo bianco di prova", size: 18, x0: 43, top: 740, color: white),
                    line("Traduzione grigia di prova Gamma-", size: 18, x0: 43, top: 700, color: grey),
                    line("Delta della traduzione", size: 18, x0: 43, top: 679, color: grey)] + body(6, top: 600, tag: "abstract")
        XCTAssertTrue(runs(items(band)).contains("Traduzione grigia di prova Gamma-Delta della traduzione"), "\(runs(items(band)))")
    }

    func test_numberWithoutTitle_staysTextOfItsParagraph() {
        let lines = body(3, top: 760, tag: "prima") + [line("1.", size: 30, x0: 77, x1: 100, top: 700, color: green)]
            + body(3, top: 690, tag: "paragrafo")
        let it = items(lines)
        XCTAssertEqual(headings(it), [], "un numero senza titolo accanto non è un titolo")
        XCTAssertTrue(runs(it).contains { $0.contains("1. Riga di corpo paragrafo numero 0") },
                      "il numero si legge in testa al suo paragrafo: \(runs(it))")
    }

    func test_paragraphTitle_outsideGate_isColorHeadingOfTrunk() {
        // prova al contrario: fuori dalla porta il titolo verde resta al canale a colore del tronco (livello 1)
        let lines = body(4, top: 760, tag: "prima") + [
            line("Titolo verde di prova.", size: 14, top: 680, color: green)] + body(4, top: 650, tag: "dopo")
        XCTAssertEqual(headings(items(lines, w: 595, h: 842)), ["H1 Titolo verde di prova."])
        XCTAssertEqual(headings(items(lines)), ["H3 Titolo verde di prova."], "dentro la porta: paragrafo senza numero, H3")
    }

    // ── Righe che non devono cambiare ruolo ────────────────────────────────────────────────────

    func test_coloredLinkInsideNote_staysInTheNote() {
        // regressione trovata in rete: una riga di nota con un collegamento colorato (taglia di nota) usciva
        // dalla nota e la nota finiva incollata nel corpo. Resta nota.
        let lines = body(10, top: 760, tag: "corpo") + [
            line("12 Nota di prova che va a capo sulla riga seguente", size: 8, x0: 77, top: 120),
            line("con un collegamento colorato di prova", size: 8, x0: 77, top: 110, color: "#1F4E9E"),
            line("e la chiusura della nota.", size: 8, x0: 77, top: 100)]
        let it = items(lines)
        let noteRuns = it.compactMap { if case let .run(.note, ls) = $0 { return ls.map { $0.text } } else { return nil } }
        XCTAssertEqual(noteRuns.filter { $0.contains("con un collegamento colorato di prova") }.first?.prefix(3),
                       ["12 Nota di prova che va a capo sulla riga seguente", "con un collegamento colorato di prova",
                        "e la chiusura della nota."], "la riga colorata resta nello stesso nodo della sua nota: \(noteRuns)")
    }

    func test_coloredBodySizeLine_isNotHeadingInsideGate() {
        // voce di sommario verde a taglia di corpo: fuori dalla porta è un titolo a colore (H3), dentro è corpo
        let lines = body(4, top: 760, tag: "prima") + [line("Voce verde di prova", size: 10, top: 690, color: green)]
            + body(4, top: 660, tag: "dopo")
        XCTAssertEqual(headings(items(lines, w: 595, h: 842)), ["H3 Voce verde di prova"])
        XCTAssertEqual(headings(items(lines)), [])
    }

    // ── Mobilia: i numeri di paragrafo non sono marcatori di pagina ─────────────────────────────

    func test_paragraphNumbers_areNotColourFurniture_onDpc() {
        // 20 pagine, il numero «1.» su 6 (30 %): sopra la soglia del canale a colore (15 %, almeno 5 pagine),
        // sotto quella del canale di maggioranza (50 %) — come nei fascicoli veri
        func ex(w: Double, h: Double) -> PdfExtraction {
            let pages = (0..<20).map { i -> PdfPageExtraction in
                let number = i < 6 ? [line("1.", size: 30, x0: 77, x1: 100, top: 600 - Double(i) * 20, color: green)] : []
                return page(i, body(8, top: 760, tag: "p\(i)") + number + body(4, top: 560 - Double(i) * 20, tag: "q\(i)"), w: w, h: h)
            }
            return PdfExtraction(version: 2, pageCount: pages.count, pages: pages)
        }
        let dpc = ex(w: 567, h: 814)
        let numberKeys = Set((0..<6).map { "\($0):8" })
        XCTAssertTrue(detectFurniture(dpc).isDisjoint(with: numberKeys), "sulla DPC il numero di paragrafo resta contenuto")
        let other = ex(w: 595, h: 842)
        XCTAssertTrue(numberKeys.isSubset(of: detectFurniture(other)), "prova al contrario: fuori dalla porta il canale a colore lo toglie")
    }
}
