//
//  MonoTitlesTests.swift
//  ScaboCoreTests
//
//  Canale dei titoli e dei paragrafi dei documenti MONOTIPOGRAFICI (MonoTitles.swift): firma di formato,
//  calibrazione per editor (stile Pages, stile Word/Google Docs, riga vuota che separa i paragrafi),
//  titoli e rifiuti, titoli in cima alla pagina, livelli, paragrafi, granularità, codifica invariata.
//  Frasi di prova neutre (nessun testo dei volumi). Ogni caso negativo è un falso titolo visto sul
//  corpus nel giro del 2026-10-07: precisione prima del richiamo.
//

import XCTest
@testable import ScaboCore

final class MonoTitlesTests: XCTestCase {

    // MARK: - Costruttori di estrazioni sintetiche

    /// Parole di prova: ogni riga e ogni pagina hanno testo diverso (la mobilia non le scambia per testatine).
    private let words = ["alfa", "beta", "gamma", "delta", "epsilon", "zeta", "eta", "theta", "iota", "kappa",
                         "lambda", "mu", "nu", "xi", "omicron", "pi", "rho", "sigma", "tau", "upsilon", "phi",
                         "chi", "psi", "omega"]
    private func w(_ i: Int) -> String { words[i % words.count] }

    /// Riga di testo: `y` è la linea di base (origine in basso), larghezza `w` dal margine `x`.
    private func ln(_ text: String, y: Double, x: Double = 57, w: Double = 430, size: Double = 15,
                    bold: Bool = true, color: String = "#00B100") -> PdfTextLine {
        let bb = BBox(x: x, y: y, width: w, height: size * 1.2)
        return PdfTextLine(spans: [PdfSpan(text: text, fontSize: size, bold: bold, italic: false, color: color, bbox: bb)],
                           bbox: bb)
    }
    /// Righe di corpo di prova (la riga `k` di `n` chiude la frase solo se è l'ultima).
    private func bodyRows(_ page: Int, _ n: Int, from: Int = 0) -> [(String, Double, Int)] {
        (0..<n).map { k in
            k == n - 1 ? ("riga \(w(page)) \(w(from + k)) che chiude la frase di prova.", 380.0, 0)
                : (k == 0 ? "Una frase \(w(page)) \(w(from + k)) di prova riempie la riga del corpo e"
                          : "continua \(w(page)) \(w(from + k)) sulla riga seguente del corpo e", 470.0, 0)
        }
    }

    /// Pagina in stile Pages: passo 18, `rows` = (testo, larghezza, righe vuote prima).
    private func pagesPage(_ index: Int, _ rows: [(String, Double, Int)], top: Double = 760) -> PdfPageExtraction {
        var y = top
        var lines: [PdfTextLine] = []
        for (i, r) in rows.enumerated() {
            if i > 0 { y -= 18 * Double(1 + r.2) }
            lines.append(ln(r.0, y: y, w: r.1))
        }
        return PdfPageExtraction(pageIndex: index, width: 595, height: 842, lines: lines)
    }

    /// Una pagina Pages tipica: 10 righe di corpo, una riga vuota, un titolo corto, 10 righe di corpo.
    private func pagesTypical(_ p: Int, title: String? = nil) -> [(String, Double, Int)] {
        var rows = bodyRows(p, 10)
        rows.append((title ?? "Titolo di prova \(w(p))", 180, 1))
        rows += bodyRows(p, 10, from: 10).enumerated().map { k, r in
            k == 0 ? ("Il corpo \(w(p)) riparte in maiuscola sotto il titolo e", 470, 0) : r }
        return rows
    }

    private func pagesDocument(pages n: Int = 6) -> PdfExtraction {
        PdfExtraction(version: 2, pageCount: n, pages: (0..<n).map { pagesPage($0, pagesTypical($0)) })
    }

    /// Pagina in stile Google Docs: passo 16; `rows` = (testo, larghezza, stacco extra prima: 0 riga,
    /// 18 paragrafo, 52 titolo).
    private func gdocsPage(_ index: Int, _ rows: [(String, Double, Double)], top: Double = 770) -> PdfPageExtraction {
        var y = top
        var lines: [PdfTextLine] = []
        for (i, r) in rows.enumerated() {
            if i > 0 { y -= 16 + r.2 }
            lines.append(ln(r.0, y: y, x: 72, w: r.1, size: 12, color: "#000000"))
        }
        return PdfPageExtraction(pageIndex: index, width: 595, height: 842, lines: lines)
    }

    /// Paragrafo di due righe che chiude la frase.
    private func gpara(_ p: Int, _ k: Int, gap: Double = 18) -> [(String, Double, Double)] {
        [("Il paragrafo \(w(p)) \(w(k)) di prova riempie la riga del corpo", 450, gap),
         ("e si chiude \(w(p)) \(w(k)) con un punto.", 230, 0)]
    }

    private func gdocsTypical(_ p: Int) -> [(String, Double, Double)] {
        var rows: [(String, Double, Double)] = []
        for k in 0..<4 { rows += gpara(p, k, gap: k == 0 ? 0 : 18) }
        rows.append(("Titolo di sezione \(w(p))", 220, 52))
        for k in 4..<8 { rows += gpara(p, k) }
        return rows
    }

    private func gdocsDocument(pages n: Int = 6) -> PdfExtraction {
        PdfExtraction(version: 2, pageCount: n, pages: (0..<n).map { gdocsPage($0, gdocsTypical($0)) })
    }

    private func items(_ e: PdfExtraction, page: Int) -> [GenItem] {
        let profile = estimateProfile(e)
        let furniture = detectFurniture(e)
        return pageItems(e.pages[page], profile, furniture, frontMatterRegionLimit(e.pageCount), detectApparatus(e, furniture))
    }
    private func titles(_ items: [GenItem]) -> [String] {
        items.compactMap { if case let .monoTitle(sm, _) = $0 { return sm.text } else { return nil } }
    }
    private func bodies(_ items: [GenItem]) -> [String] {
        items.compactMap { if case let .run(.body, ls) = $0 { return joinLines(ls.map { $0.text }) } else { return nil } }
    }
    private func letters(_ s: String) -> [Character] { s.filter { $0.isLetter || $0.isNumber }.sorted() }

    // MARK: - Firma di formato

    func test_signature_uniformDispensa_isMonotypographic() {
        XCTAssertNotNil(estimateProfile(pagesDocument()).mono)
        XCTAssertNotNil(estimateProfile(gdocsDocument()).mono)
    }

    func test_signature_secondaryStyleOnEveryPage_isNotMonotypographic() {
        // un volume editoriale: note più piccole in fondo a ogni pagina
        var e = pagesDocument(pages: 6)
        for i in e.pages.indices {
            e.pages[i].lines.append(ln("1 Nota \(w(i)) di prova a piè di pagina.", y: 80, size: 9, bold: false))
        }
        XCTAssertNil(estimateProfile(e).mono)
    }

    func test_signature_offStyleConfinedToCover_isMonotypographic() {
        var e = pagesDocument(pages: 6)
        e.pages[0].lines.insert(ln("Copertina di prova", y: 800, size: 30), at: 0)
        XCTAssertNotNil(estimateProfile(e).mono, "uno stile secondario su una sola pagina (copertina) non spegne la firma")
    }

    func test_signature_boldTitlesOnManyPages_isNotMonotypographic() {
        // titoli in grassetto a taglia di corpo su molte pagine: la tipografia marca la struttura
        var e = pagesDocument(pages: 6)
        for i in e.pages.indices {
            e.pages[i].lines[10] = ln("Titolo di prova \(w(i))", y: e.pages[i].lines[10].bbox.y, w: 180, bold: false)
        }
        XCTAssertNil(estimateProfile(e).mono)
    }

    // MARK: - Calibrazione

    func test_calibration_pagesStyle_blankLineMarksTitles() {
        let m = estimateProfile(pagesDocument()).mono!
        XCTAssertEqual(m.pitch, 18)
        XCTAssertNil(m.paragraphGap)
        XCTAssertTrue(m.blankLineMarksTitles)
    }

    func test_calibration_gdocsStyle_paragraphClassAndTitleGap() {
        let m = estimateProfile(gdocsDocument()).mono!
        XCTAssertEqual(m.pitch, 16)
        XCTAssertEqual(m.paragraphGap ?? 0, 18, accuracy: 0.5)
        XCTAssertGreaterThan(m.titleGap, 18)
        XCTAssertLessThan(m.titleGap, 52)
        XCTAssertFalse(m.blankLineMarksTitles)
    }

    func test_calibration_blankLineSeparatesParagraphs_notTitles() {
        // appunti dove la riga vuota separa paragrafi di corpo (testa lunga che continua in minuscola)
        var pages: [PdfPageExtraction] = []
        for p in 0..<6 {
            var rows: [(String, Double, Int)] = []
            for k in 0..<5 {
                rows += [("Un paragrafo \(w(p)) \(w(k)) comincia dopo la riga vuota e", 470, k == 0 ? 0 : 1),
                         ("continua \(w(p)) \(w(k)) sulla riga seguente fino al punto.", 420, 0)]
            }
            pages.append(pagesPage(p, rows))
        }
        let m = estimateProfile(PdfExtraction(version: 2, pageCount: 6, pages: pages)).mono!
        XCTAssertFalse(m.blankLineMarksTitles)
        XCTAssertNotNil(m.paragraphGap)
    }

    // MARK: - Titoli, stile Pages

    func test_pages_titleAfterBlankLine_isTitle_andLettersConserved() {
        let e = pagesDocument()
        let its = items(e, page: 1)
        XCTAssertEqual(titles(its), ["Titolo di prova \(w(1))"])
        let inText = e.pages[1].lines.map { $0.spans.map { $0.text }.joined() }.joined()
        let outText = its.flatMap { genItemLines($0) }.map { $0.text }.joined()
        XCTAssertEqual(letters(inText), letters(outText), "rete A: nessuna lettera persa o aggiunta")
    }

    func test_pages_wrappedTitle_continuesOnLowercaseRow() {
        var e = pagesDocument()
        var rows = bodyRows(2, 10)
        rows += [("Titolo di prova che va a capo e", 300, 1), ("continua sulla seconda riga", 260, 0),
                 ("Il corpo riparte in maiuscola sotto il titolo e", 470, 0)]
        rows += bodyRows(2, 8, from: 12).dropFirst().map { $0 }
        e.pages[2] = pagesPage(2, rows)
        XCTAssertEqual(titles(items(e, page: 2)), ["Titolo di prova che va a capo e continua sulla seconda riga"])
    }

    func test_pages_allCapsTitle_continuesOnAllCapsRow_andRowRegrouped() {
        var e = pagesDocument()
        var rows = bodyRows(2, 10)
        rows += [("CAP. 5 - LA PROVA", 300, 1), ("FINALE", 120, 0), ("Il corpo riparte in maiuscola sotto il titolo e", 470, 0)]
        rows += bodyRows(2, 8, from: 12).dropFirst().map { $0 }
        e.pages[2] = pagesPage(2, rows)
        XCTAssertEqual(titles(items(e, page: 2)), ["CAP. 5 - LA PROVA FINALE"])
        // PDFKit (iOS 26.5) può emettere un pezzo della riga dopo la riga sotto: la linea di base lo riporta al suo posto
        let a = LineSummary(text: "CAP. 5", fontSize: 15, bold: true, italic: false, color: "#00B100",
                            x0: 57, x1: 100, yTop: 755, yBottom: 737, width: 43, height: 18, spans: [])
        var b = a; b.text = "FINALE"; b.yTop = 706; b.yBottom = 688
        var c = a; c.text = "LA PROVA"; c.x0 = 110; c.x1 = 200
        let r = monoRows([a, b, c])
        XCTAssertEqual(r.map { $0.text }, ["CAP. 5 LA PROVA", "FINALE"])
    }

    func test_monoRows_twoColumnsEmittedColumnWise_neverInterleave() {
        // due colonne alle stesse linee di base, emesse colonna per colonna: la colonna destra arriva fuori
        // dalla finestra dell'aggancio e resta una sequenza di righe sue, mai intrecciata con la sinistra
        func row(_ text: String, x: Double, y: Double) -> LineSummary {
            LineSummary(text: text, fontSize: 11, bold: false, italic: false, color: "#000000",
                        x0: x, x1: x + 200, yTop: y + 13, yBottom: y, width: 200, height: 13, spans: [])
        }
        let left = (0..<6).map { row("sinistra \(w($0))", x: 72, y: 700 - 15 * Double($0)) }
        let right = (0..<6).map { row("destra \(w($0))", x: 300, y: 700 - 15 * Double($0)) }
        let r = monoRows(left + right)
        XCTAssertEqual(r.map { $0.text }, left.map { $0.text } + right.map { $0.text })
        // un pezzo sovrastampato sulla stessa linea di base non si fonde
        let over = monoRows([row("primo", x: 72, y: 500), row("primo", x: 73, y: 500)])
        XCTAssertEqual(over.count, 2)
    }

    func test_pages_bodySentenceAfterBlankLine_isNotTitle() {
        var e = pagesDocument()
        var rows = bodyRows(2, 10)
        rows += [("Questo paragrafo di corpo comincia dopo una riga", 470, 1),
                 ("vuota e si chiude con il suo punto finale.", 420, 0),
                 ("La frase seguente comincia in maiuscola.", 380, 0)]
        e.pages[2] = pagesPage(2, rows)
        XCTAssertEqual(titles(items(e, page: 2)), [], "una frase di corpo che finisce col punto non è un titolo")
    }

    func test_pages_titleAtPageTop_needsShortClosedPreviousPage() {
        var e = pagesDocument(pages: 6)
        // pagina 3: in cima un titolo, poi il corpo
        var top: [(String, Double, Int)] = [("Titolo in cima", 160, 0),
                                              ("Il corpo comincia in maiuscola dopo il titolo e", 470, 0)]
        top += bodyRows(3, 18, from: 2).dropFirst().map { $0 }
        e.pages[3] = pagesPage(3, top)
        // pagina 2 piena e chiusa dal punto: in cima alla pagina 3 non si promuove
        XCTAssertEqual(titles(items(e, page: 3)), [], "pagina precedente piena: in cima alla pagina non si promuove")
        // pagina 2 più corta di una riga (la riga vuota prima del titolo è rimasta in fondo) e chiusa dal punto
        e.pages[2].lines.removeLast()
        let last = e.pages[2].lines.count - 1
        e.pages[2].lines[last] = ln("e la pagina \(w(2)) si chiude un rigo più su.", y: e.pages[2].lines[last].bbox.y, w: 300)
        XCTAssertEqual(titles(items(e, page: 3)), ["Titolo in cima"])
    }

    func test_pages_headReachingRightMargin_withIndirectEvidence_isParagraphStart_notTitle() {
        // Dove la riga vuota sopra o la chiusura sotto sono DEDOTTE (cima o fondo della pagina), una testa piena
        // fino al margine è l'inizio di un paragrafo che va a capo: la riga dopo ne continua la frase anche se
        // comincia in maiuscola (nome proprio, sigla) → nessun titolo. (A metà pagina le due prove sono misurate
        // e basta la forma: sulle 8 dispense con albero di struttura nessun inizio di paragrafo è promosso.)
        var e = pagesDocument(pages: 6)
        // in cima alla pagina 3, dopo una pagina 2 corta e chiusa dal punto
        var top: [(String, Double, Int)] = [("Un paragrafo di prova \(w(3)) comincia in cima alla pagina", 470, 0),
                                              ("e la sua seconda riga arriva fino al margine destro", 470, 0),
                                              ("Nomeproprio che continua la frase della riga sopra e", 470, 0)]
        top += bodyRows(3, 16, from: 3)
        e.pages[3] = pagesPage(3, top)
        e.pages[2].lines.removeLast()
        let last = e.pages[2].lines.count - 1
        e.pages[2].lines[last] = ln("e la pagina \(w(2)) si chiude un rigo più su.", y: e.pages[2].lines[last].bbox.y, w: 300)
        XCTAssertEqual(titles(items(e, page: 3)), [], "in cima alla pagina la testa piena fino al margine non è un titolo")
        // la stessa riga corta in cima alla pagina resta un titolo (controprova della guardia)
        e.pages[3].lines[0] = ln("Titolo in cima", y: e.pages[3].lines[0].bbox.y, w: 160)
        e.pages[3].lines.remove(at: 1)
        XCTAssertEqual(titles(items(e, page: 3)), ["Titolo in cima"])
        // in fondo alla pagina 4, dopo la riga vuota, con la pagina 5 che riparte in maiuscola
        var tail = bodyRows(4, 18)
        tail += [("Un paragrafo di prova \(w(4)) comincia in fondo alla pagina", 470, 1),
                 ("e la sua seconda riga arriva fino al margine destro", 470, 0)]
        e.pages[4] = pagesPage(4, tail)
        XCTAssertEqual(titles(items(e, page: 4)), [], "in fondo alla pagina la testa piena fino al margine non è un titolo")
    }

    func test_pages_keywordOrAllCapsHead_reachingRightMargin_staysTitle() {
        // un titolo di capitolo tutto maiuscolo composto grande arriva al margine: la guardia della riga corta
        // non lo tocca (il corpo non comincia con «CAP. 7 –» né tutto in maiuscolo)
        var e = pagesDocument(pages: 6)
        var rows = bodyRows(2, 10)
        rows += [("CAP. 7 - UN TITOLO DI PROVA COMPOSTO", 470, 1), ("GRANDE FINO AL MARGINE", 470, 0),
                 ("Il corpo riparte in maiuscola sotto il titolo e", 470, 0)]
        rows += bodyRows(2, 6, from: 13)
        e.pages[2] = pagesPage(2, rows)
        XCTAssertEqual(titles(items(e, page: 2)), ["CAP. 7 - UN TITOLO DI PROVA COMPOSTO GRANDE FINO AL MARGINE"])
        // in fondo alla pagina, con la pagina dopo che riparte in maiuscola
        var tail = bodyRows(4, 18)
        tail += [("CAP. 8 - UN ALTRO TITOLO DI PROVA", 470, 1), ("IN FONDO ALLA PAGINA FINO AL MARGINE", 470, 0)]
        e.pages[4] = pagesPage(4, tail)
        XCTAssertEqual(titles(items(e, page: 4)), ["CAP. 8 - UN ALTRO TITOLO DI PROVA IN FONDO ALLA PAGINA FINO AL MARGINE"])
    }

    // MARK: - Titoli, stile Google Docs / Word

    func test_gdocs_titleBetweenTitleGapAndParagraphGap_isTitle() {
        XCTAssertEqual(titles(items(gdocsDocument(), page: 1)), ["Titolo di sezione \(w(1))"])
    }

    func test_gdocs_bylineAfterParagraphGap_isNotTitle() {
        var e = gdocsDocument()
        var rows = gpara(2, 0, gap: 0) + gpara(2, 1)
        rows += [("CAP. 3 – Capitolo di prova", 260, 52), ("Mario Rossi", 120, 18), ("Titolo di sezione tre", 220, 52)]
        rows += gpara(2, 2) + gpara(2, 3)
        e.pages[2] = gdocsPage(2, rows)
        let its = items(e, page: 2)
        XCTAssertEqual(titles(its), ["CAP. 3 – Capitolo di prova", "Titolo di sezione tre"],
                       "la riga d'autore segue il capitolo con il solo stacco di paragrafo: resta corpo")
        XCTAssertTrue(bodies(its).contains("Mario Rossi"))
    }

    func test_gdocs_topOfPage_titleNeedsBodyAfter() {
        var e = gdocsDocument()
        e.pages[2] = gdocsPage(2, [("Titolo in cima alla pagina", 220, 0)] + gpara(2, 0) + gpara(2, 1) + gpara(2, 2))
        XCTAssertEqual(titles(items(e, page: 2)), ["Titolo in cima alla pagina"])
        e.pages[3] = gdocsPage(3, [("Mario Rossi", 120, 0), ("Titolo di sezione quattro", 220, 52)] + gpara(3, 0) + gpara(3, 1))
        XCTAssertEqual(titles(items(e, page: 3)), ["Titolo di sezione quattro"],
                       "in cima alla pagina una riga seguita da un altro titolo (riga d'autore) resta corpo")
        e.pages[4] = gdocsPage(4, [("PARTE SECONDA – PARTE DI PROVA SU", 420, 0), ("DUE RIGHE", 120, 0),
                                   ("CAP. 4 – Capitolo di prova", 260, 52)] + gpara(4, 0) + gpara(4, 1))
        XCTAssertEqual(titles(items(e, page: 4)), ["PARTE SECONDA – PARTE DI PROVA SU DUE RIGHE", "CAP. 4 – Capitolo di prova"],
                       "parte e capitolo impilati in cima alla pagina: la parola-chiave basta")
    }

    func test_gdocs_paragraphSplit_onlyAtClosedSentences() {
        let its = items(gdocsDocument(), page: 0)
        XCTAssertEqual(bodies(its).count, 8, "quattro paragrafi prima del titolo, quattro dopo")
        var e = gdocsDocument()
        e.pages[0] = gdocsPage(0, [("Un paragrafo che non chiude la frase alla fine", 450, 0),
                                   ("della riga", 120, 18), ("continua dopo lo stacco fino al punto.", 400, 0)]
                                   + gpara(0, 5) + gpara(0, 6))
        XCTAssertEqual(bodies(items(e, page: 0)).count, 3, "mai spezzare una frase: lo stacco a metà frase non divide")
        // uno stacco casuale dopo un'abbreviazione («art.», «cfr.», una sigla puntata) non chiude la frase
        for abbreviation in ["fittizia, l'art.", "fittizia, cfr.", "fittizia d.P.R."] {
            var f = gdocsDocument()
            f.pages[0] = gdocsPage(0, [("Un paragrafo di prova che cita una norma \(abbreviation)", 450, 0),
                                       ("12 e poi prosegue fino al punto finale.", 400, 18)] + gpara(0, 5) + gpara(0, 6))
            XCTAssertEqual(bodies(items(f, page: 0)).count, 3, "dopo «\(abbreviation)» la frase continua")
        }
    }

    func test_titleShape_rejections() {
        XCTAssertTrue(monoTitleShape("Titolo di prova"))
        XCTAssertTrue(monoTitleShape("01.01.2030"), "una data isolata apre una lezione")
        XCTAssertTrue(monoTitleShape("Norma di prova: art."), "punto di una sigla, non di fine frase")
        XCTAssertTrue(monoTitleShape("Disciplina di prova della x.y.z.w."), "sigla puntata lettera per lettera")
        XCTAssertFalse(monoTitleShape("- voce di elenco"))
        XCTAssertFalse(monoTitleShape("(12) nota di prova"))
        XCTAssertFalse(monoTitleShape("a) lettera di elenco"))
        XCTAssertFalse(monoTitleShape("Una frase che finisce col punto."))
        XCTAssertFalse(monoTitleShape("Una frase che finisce con che"))
        XCTAssertFalse(monoTitleShape("Prima frase chiusa. Seconda frase"))
        XCTAssertFalse(monoTitleShape("Capp. 1, 2, 3, 5, 7"), "elenco di numeri di copertina")
        XCTAssertFalse(monoTitleShape("4, 5 e 6"), "elenco di numeri")
        XCTAssertTrue(monoTitleShape("Artt. 100-101"), "un intervallo di articoli resta un titolo possibile")
        XCTAssertTrue(monoTitleShape("Artt. 10, 11-quater e 12-bis"), "articoli con suffisso: non un elenco nudo")
        XCTAssertFalse(monoTitleShape("Parola spez- zata dall'ocr"))
        XCTAssertFalse(monoTitleShape("minuscola in apertura"))
        XCTAssertFalse(monoTitleShape("VC"), "meno di tre lettere")
        XCTAssertFalse(monoTitleShape("Banca dati di prova - Copyright Editore di prova"), "timbro di banca dati")
        XCTAssertFalse(monoTitleShape("Titolo di prova. - Il corpo comincia"), "titolo e corpo nella stessa riga")
    }

    func test_gdocs_blockFollowedByLowercase_isNotTitle() {
        // dopo lo stacco la frase continua in minuscola: il blocco isolato non è un titolo
        var e = gdocsDocument()
        var rows = gpara(2, 0, gap: 0) + gpara(2, 1)
        rows += [("Un blocco isolato di prova senza punto finale", 300, 52), ("continua in minuscola dopo lo stacco.", 300, 18)]
        rows += gpara(2, 2)
        e.pages[2] = gdocsPage(2, rows)
        XCTAssertEqual(titles(items(e, page: 2)), [])
        XCTAssertTrue(paragraphRestarts("t.u.i.f. di prova, modificato"), "sigla minuscola col punto: apertura legittima")
        XCTAssertTrue(paragraphRestarts("(…)"))
        XCTAssertFalse(paragraphRestarts("prosegue la frase di prova"))
    }

    func test_noteRunWithStructureKeyword_becomesTitle() {
        // etichetta di capitolo composta più piccola del corpo (classificata NOTA) in un documento monotipografico
        let small = LineSummary(text: "CAP. 4 - Capitolo di prova", fontSize: 20, bold: false, italic: false, color: "#00B100",
                                x0: 57, x1: 400, yTop: 780, yBottom: 762, width: 343, height: 18, spans: [])
        let cover = LineSummary(text: "Copertina di prova", fontSize: 20, bold: false, italic: false, color: "#00B100",
                                x0: 57, x1: 300, yTop: 780, yBottom: 762, width: 243, height: 18, spans: [])
        let profile = estimateProfile(pagesDocument())
        let page = PdfPageExtraction(pageIndex: 2, width: 595, height: 842, lines: [])
        XCTAssertEqual(titles(recognizeMonoTitles([.run(.note, [small])], page: page, profile)), ["CAP. 4 - Capitolo di prova"])
        guard case .run(.note, _) = recognizeMonoTitles([.run(.note, [cover])], page: page, profile)[0] else {
            return XCTFail("una riga di copertina senza parola-chiave resta com'è")
        }
    }

    // MARK: - Mobilia nei documenti monotipografici

    func test_furniture_monotypographic_keepsRecurringTopWordAndChapterLabel() {
        // tre pagine aperte dalla stessa parola di corpo alla stessa quota, e un'etichetta «CAP. N» a riga a sé
        var e = pagesDocument(pages: 6)
        for p in 1...3 {
            var lines = e.pages[p].lines
            lines.insert(ln("parolaprova", y: 778, w: 140), at: 0)
            e.pages[p].lines = lines
        }
        let furniture = detectFurniture(e)
        XCTAssertNotNil(estimateProfile(e).mono)
        for p in 1...3 { XCTAssertFalse(furniture.contains("\(p):0"), "la parola di corpo in cima alla pagina \(p) resta") }
    }

    // MARK: - Livelli

    func test_levels_keywordAndRelative() {
        XCTAssertEqual(monoKeywordLevel("CAP. 2 - Capitolo di prova"), 2)
        XCTAssertEqual(monoKeywordLevel("PARTE 1 – Parte di prova"), 1)
        XCTAssertEqual(monoKeywordLevel("Sezione 1"), 3)
        XCTAssertEqual(monoKeywordLevel("Sezione seconda – Sezione di prova"), 3)
        XCTAssertNil(monoKeywordLevel("Parte di un titolo qualunque"))
        let cap = NodeDict(id: "n0", type: .HEADING_2, page_index: 0, text: "CAP. 2 - Capitolo di prova", level: 2)
        XCTAssertEqual(monoTitleLevel(keywordLevel: nil, preceding: [cap]), 3, "sotto un capitolo")
        let sib = NodeDict(id: "n1", type: .HEADING_3, page_index: 0, text: "Titolo di prova", level: 3)
        XCTAssertEqual(monoTitleLevel(keywordLevel: nil, preceding: [cap, sib]), 3, "fratello del titolo precedente")
        XCTAssertEqual(monoTitleLevel(keywordLevel: nil, preceding: []), 2)
        XCTAssertEqual(monoTitleLevel(keywordLevel: 1, preceding: [cap, sib]), 1)
    }

    func test_documentNodes_levelsAndFamily() {
        let doc = genericPlugin.build(gdocsDocument(), sourceName: "prova.pdf")
        XCTAssertEqual(doc.profile.editorial_family, MONOTYPOGRAPHIC_FAMILY)
        let heads = doc.structure.filter { $0.type == .HEADING_2 }
        XCTAssertEqual(heads.count, 6, "un titolo per pagina, tutti fratelli a livello 2")
    }

    // MARK: - Volume non monotipografico: identità

    func test_nonMonotypographic_isIdentity() {
        let lines = [LineSummary(text: "Riga", fontSize: 11, bold: false, italic: false, color: "#000000",
                                 x0: 0, x1: 100, yTop: 500, yBottom: 488, width: 100, height: 12, spans: [])]
        let profile = Profile(bodySize: 11, bodyColor: "#000000")
        let page = PdfPageExtraction(pageIndex: 3, width: 500, height: 700, lines: [])
        let out = recognizeMonoTitles([.run(.body, lines)], page: page, profile)
        guard out.count == 1, case .run(.body, let ls) = out[0] else { return XCTFail("identità attesa") }
        XCTAssertEqual(ls, lines)
    }

    // MARK: - Granularità e segmenti

    func test_granularity_respectsParagraphFlag() {
        var a = ContentSegment(id: "a", role: "BODY", text: "Prima frase di prova.", lengthCategory: "", acousticIntro: "", sourcePage: 1)
        var b = ContentSegment(id: "b", role: "BODY", text: "Seconda frase di prova.", lengthCategory: "", acousticIntro: "", sourcePage: 1)
        XCTAssertEqual(granularizeBody([a, b]).count, 1, "senza il flag il corpo adiacente si ricuce (comportamento invariato)")
        b.opensParagraph = true
        let out = granularizeBody([a, b])
        XCTAssertEqual(out.map { $0.text }, ["Prima frase di prova.", "Seconda frase di prova."])
        XCTAssertFalse(out.contains { $0.opensParagraph }, "i blocchi prodotti non portano il flag")
        a.opensParagraph = true
        XCTAssertEqual(granularizeBody([a]).count, 1)
    }

    func test_buildBaseSegments_marksOnlyMonotypographicSamePageBody() {
        func doc(_ family: String) -> ScabopdfDocument {
            ScabopdfDocument(
                schema_version: SUPPORTED_SCHEMA_VERSION, document_id: "prova",
                metadata: DocumentMetadata(pages_pdf: 2, page_size_pt: [0, 0], source_pdf_filename: "prova.pdf"),
                profile: DocumentProfileDict(profile_id: "generic", editorial_family: family, genre: "unknown", confidence: 0.05),
                warnings: [], transformations: [],
                structure: [
                    NodeDict(id: "n0", type: .BODY, page_index: 0, text: "Primo paragrafo."),
                    NodeDict(id: "n1", type: .BODY, page_index: 0, text: "Secondo paragrafo."),
                    NodeDict(id: "n2", type: .BODY, page_index: 1, text: "continua nella pagina dopo."),
                ])
        }
        let mono = buildBaseSegments(doc(MONOTYPOGRAPHIC_FAMILY)).map { $0.opensParagraph }
        XCTAssertEqual(mono, [false, true, false], "solo il confine corpo|corpo sulla stessa pagina")
        XCTAssertEqual(buildBaseSegments(doc("generic")).map { $0.opensParagraph }, [false, false, false])
    }

    func test_contentSegment_flagIsNotEncodedNorCompared() throws {
        var s = ContentSegment(id: "a", role: "BODY", text: "Testo di prova.", lengthCategory: "", acousticIntro: "", sourcePage: 1)
        let enc = JSONEncoder()
        enc.outputFormatting = .sortedKeys   // l'ordine delle chiavi dell'encoder non è garantito
        let plain = try enc.encode(s)
        s.opensParagraph = true
        XCTAssertEqual(try enc.encode(s), plain, "la cache non cambia formato")
        let keys = try JSONSerialization.jsonObject(with: plain) as? [String: Any]
        XCTAssertEqual(Set(keys?.keys ?? [:].keys), ["id", "role", "text", "lengthCategory", "acousticIntro", "memoryRefresh", "sourcePage"])
        let t = ContentSegment(id: "a", role: "BODY", text: "Testo di prova.", lengthCategory: "", acousticIntro: "", sourcePage: 1)
        XCTAssertEqual(s, t, "il flag transitorio non entra nell'uguaglianza")
        XCTAssertFalse(try JSONDecoder().decode(ContentSegment.self, from: plain).opensParagraph)
    }
}
