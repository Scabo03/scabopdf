//
//  CodiciArticleTests.swift
//  ScaboCoreTests
//
//  Ramo Codici — foglia 1: riconoscimento dell'articolo come HEADING_4 navigabile.
//  Il trigger è a livello SPAN: primo span (il numero) ≥ corpo×1.13, testo = numero
//  puro, riga che matcha il pattern d'articolo. NIENTE bold (perso col font on-device).
//

import XCTest
@testable import ScaboCore

final class CodiciArticleTests: XCTestCase {

    /// Riga d'articolo: primo span = numero a `numSize` (9.0), il resto a corpo (7.5).
    /// `rest` è il testo dopo il numero (es. ". Nozione. – [I]. Il contratto…").
    private func articleLine(_ number: String, _ rest: String, y: Double,
                             numSize: Double = 9.0, body: Double = 7.5, x0: Double = 31) -> PdfTextLine {
        let numBox = BBox(x: x0, y: y, width: 12, height: numSize)
        let restBox = BBox(x: x0 + 12, y: y, width: 120, height: body)
        let full = BBox(x: x0, y: y, width: 132, height: numSize)
        return PdfTextLine(spans: [
            PdfSpan(text: number, fontSize: numSize, bold: false, italic: false, color: "#000000", bbox: numBox),
            PdfSpan(text: rest, fontSize: body, bold: false, italic: false, color: "#000000", bbox: restBox),
        ], bbox: full)
    }
    /// Riga di corpo semplice (un solo span a corpo).
    private func bodyLine(_ text: String, y: Double, body: Double = 7.5, x0: Double = 31) -> PdfTextLine {
        let box = BBox(x: x0, y: y, width: 130, height: body)
        return PdfTextLine(spans: [PdfSpan(text: text, fontSize: body, bold: false, italic: false, color: "#000000", bbox: box)], bbox: box)
    }
    private func page(_ idx: Int, _ lines: [PdfTextLine], w: Double = 357, h: Double = 547) -> PdfPageExtraction {
        PdfPageExtraction(pageIndex: idx, width: w, height: h, lines: lines)
    }
    private func ex(_ pages: [PdfPageExtraction], producer: String = "PDFsharp 1.31.1789-g (www.pdfsharp.com)") -> PdfExtraction {
        PdfExtraction(version: 2, pageCount: pages.count, pages: pages, producer: producer)
    }
    private func doc(_ pages: [PdfPageExtraction], producer: String = "PDFsharp 1.31.1789-g (www.pdfsharp.com)") -> ScabopdfDocument {
        buildDocumentFromPdf(ex(pages, producer: producer), sourceName: "codice.pdf")
    }
    private func texts(_ d: ScabopdfDocument, _ c: SemanticCategory) -> [String] {
        d.structure.filter { $0.type == c }.map { $0.text ?? "" }
    }
    /// Righe di corpo (taglia 7.5) dominanti, perché `estimateProfile` stimi corpo=7.5
    /// (nel codice reale il corpo domina su migliaia di righe; nel sintetico va riempito).
    private func bodyFill(_ from: Int, _ y0: Double) -> [PdfTextLine] {
        (0..<12).map { bodyLine("riga di corpo \(from + $0) di un comma legale qualunque.", y: y0 - Double($0) * 9) }
    }

    // ── La porta ─────────────────────────────────────────────────────────────────

    func test_gate_matches_onlyOnCodiciSignature() {
        XCTAssertGreaterThanOrEqual(codiciPlugin.matches(ex([page(0, bodyFill(0, 400))])), DISPATCH_THRESHOLD)
        // geometria diversa
        XCTAssertEqual(codiciPlugin.matches(ex([page(0, bodyFill(0, 400), w: 483, h: 684)])), 0.0)
        // producer diverso
        XCTAssertEqual(codiciPlugin.matches(ex([page(0, bodyFill(0, 400))], producer: "Adobe Acrobat Pro 9.0.0")), 0.0)
    }

    func test_codiciVolume_dispatchesToCodiciPlugin() {
        let d = doc([page(0, bodyFill(0, 400))])
        XCTAssertEqual(d.profile.profile_id, "codici")
    }

    // ── Riconoscimento + split ────────────────────────────────────────────────────

    func test_article_promotedToHeading4_headerAndBodySplit() {
        var lines = bodyFill(0, 420)
        lines.append(articleLine("1321", ". Nozione. – [I]. Il contratto è l’accordo di due o più parti.", y: 380))
        lines.append(bodyLine("per costituire un rapporto giuridico patrimoniale.", y: 371))
        let d = doc([page(0, lines)])
        XCTAssertTrue(texts(d, .ARTICLE_HEADER).contains { $0.contains("1321") && $0.contains("Nozione") },
                      "l'articolo è promosso a HEADING_4 navigabile")
        XCTAssertFalse(texts(d, .ARTICLE_HEADER).contains { $0.contains("Il contratto è l’accordo") },
                       "il corpo NON sta nell'header (split header/corpo)")
        XCTAssertTrue(texts(d, .BODY).contains { $0.contains("Il contratto è l’accordo") },
                      "il corpo dell'articolo resta BODY (letto)")
    }

    func test_rubricOnlyLine_wholeLineIsHeader() {
        var lines = bodyFill(0, 420)
        lines.append(articleLine("1323", ". Norme regolatrici dei contratti.", y: 380))
        lines.append(bodyLine("[I]. Tutti i contratti sono sottoposti alle norme.", y: 371))
        let d = doc([page(0, lines)])
        XCTAssertTrue(texts(d, .ARTICLE_HEADER).contains { $0.contains("1323") && $0.contains("Norme regolatrici") })
        XCTAssertTrue(texts(d, .BODY).contains { $0.contains("Tutti i contratti") })
    }

    func test_wrappedRubric_mergedAndDehyphenated() {
        // la rubrica va a capo: prima riga finisce con "ac-", il confine "–" è sulla 2ª.
        var lines = bodyFill(0, 420)
        lines.append(articleLine("942", ". (1) Terreni abbandonati dalle ac-", y: 388))
        lines.append(bodyLine("que correnti.– [I]. I terreni abbandonati che emergono.", y: 379))
        let d = doc([page(0, lines)])
        XCTAssertTrue(texts(d, .ARTICLE_HEADER).contains { $0.contains("942") && $0.contains("acque correnti") && !$0.hasSuffix("-") },
                      "la rubrica multi-riga è unita e de-sillabata nell'header ('acque', non 'ac-')")
        XCTAssertTrue(texts(d, .BODY).contains { $0.contains("I terreni abbandonati che emergono") },
                      "il corpo (dal comma) resta BODY")
    }

    func test_suffixArticle_recognized() {
        var lines = bodyFill(0, 420)
        lines.append(articleLine("624-bis", ". Furto in abitazione. – [I]. Chiunque…", y: 380))
        let d = doc([page(0, lines)])
        XCTAssertTrue(texts(d, .ARTICLE_HEADER).contains { $0.contains("624-bis") && $0.contains("Furto in abitazione") })
    }

    func test_article_isArticleHeader_andRead() {
        var lines = bodyFill(0, 420)
        lines.append(articleLine("5", ". [I] La Repubblica, una e indivisibile, riconosce.", y: 380))
        let d = doc([page(0, lines)])
        XCTAssertNotNil(d.structure.first { $0.type == .ARTICLE_HEADER && ($0.text ?? "").hasPrefix("5") },
                        "l'articolo è ARTICLE_HEADER (categoria propria)")
        // letto nel flusso (non NON_READ); la navigabilità rotore di ARTICLE_HEADER è
        // verificata lato app (ContinuousReadingView.isHeadingRole) dal bench.
        let read = buildBaseSegments(d).map { $0.text }.joined(separator: " ")
        XCTAssertTrue(read.contains("La Repubblica, una e indivisibile"), "l'articolo è letto")
    }

    // ── Precisione: NON promuovere ciò che non è un articolo ─────────────────────

    func test_doesNotPromote_crossRefOrComma_orBodySize() {
        var lines = bodyFill(0, 420)
        // rimando inline "[1321]" come riga (primo span NON è un numero puro: parte con "[")
        lines.append(bodyLine("[1321] e [1174] sono richiamati nel comma.", y: 388))
        // comma romano "[I]" da solo
        lines.append(bodyLine("[II]. La medesima disposizione si applica.", y: 379))
        // numero a TAGLIA CORPO (7.5, non 9.0): non è un trigger d'articolo
        lines.append(bodyLine("1. accordo delle parti, secondo il numero.", y: 370))
        let d = doc([page(0, lines)])
        XCTAssertEqual(texts(d, .ARTICLE_HEADER).count, 0, "nessuna riga non-articolo è promossa ad articolo")
        XCTAssertEqual(texts(d, .HEADING_4).count, 0, "né a heading di sezione")
    }

    func test_structuralHeading_notArticle() {
        // "TITOLO II" a 9.0 (primo span NON numero) → non promosso da questa foglia
        var lines = bodyFill(0, 420)
        let box = BBox(x: 80, y: 388, width: 60, height: 9.0)
        lines.append(PdfTextLine(spans: [PdfSpan(text: "TITOLO II", fontSize: 9.0, bold: false, italic: false, color: "#000000", bbox: box)], bbox: box))
        let d = doc([page(0, lines)])
        XCTAssertFalse(texts(d, .HEADING_4).contains { $0.contains("TITOLO") },
                       "una intestazione di struttura NON è un articolo (foglia 1)")
    }

    // ── Gating: fuori dai codici nessun cambiamento (byte-identico) ───────────────

    // ── Foglia 2: gerarchia (TITOLO/CAPO/SEZIONE/LIBRO) ──────────────────────────

    /// riga a banda-alta (testatina): h=547 → top-band ≥ 465.
    private func topLine(_ text: String, y: Double = 520, size: Double = 9, x0: Double = 31) -> PdfTextLine {
        bodyLine(text, y: y, body: size, x0: x0)
    }

    // Gerarchia: TITOLO=H1, CAPO=H2, SEZIONE=H3 (allineata a structHeadingLevel), articoli=H4.
    func test_titolo_bareWithSubtitle_promotedToHeading1Fused() {
        var lines = bodyFill(0, 420)
        lines.append(bodyLine("TITOLO II", y: 388))
        lines.append(bodyLine("Dei contratti in generale", y: 379))
        lines.append(articleLine("1321", ". Nozione. – [I]. Il contratto.", y: 360))
        let d = doc([page(0, lines)])
        XCTAssertTrue(texts(d, .HEADING_2).contains { $0.contains("TITOLO II") && $0.contains("Dei contratti in generale") },
                      "il TITOLO bare + sottotitolo a capo → HEADING_1 fuso")
    }

    func test_capo_and_sezione_promotedToHeadings() {
        var lines = bodyFill(0, 420)
        lines.append(bodyLine("CAPO I– Disposizioni preliminari", y: 388))
        lines.append(bodyLine("SEZIONE I– Dell’accordo delle parti", y: 379))
        let d = doc([page(0, lines)])
        XCTAssertTrue(texts(d, .HEADING_3).contains { $0.contains("CAPO I") }, "CAPO → HEADING_3")
        XCTAssertTrue(texts(d, .HEADING_4).contains { $0.contains("SEZIONE I") }, "SEZIONE → HEADING_4")
    }

    func test_capo_atPageTop_isStillHeading_notFurniture() {
        // un CAPO a inizio pagina (banda alta) è un'intestazione VERA (non testatina): NON va tolto.
        var lines: [PdfTextLine] = [bodyLine("CAPO III– Del matrimonio", y: 520)]
        lines += bodyFill(0, 400)
        let d = doc([page(0, lines)])
        XCTAssertTrue(texts(d, .HEADING_3).contains { $0.contains("CAPO III") },
                      "CAPO a inizio pagina resta intestazione (precisione: non furniture)")
    }

    func test_furniture_arttRange_codiceBanner_titoloRunHeader_removed() {
        var lines: [PdfTextLine] = [
            topLine("ARTT. 1320-1329 273", y: 524),                  // range articoli + folio
            topLine("TITOLO II - Dei contratti in generale", y: 524),// testatina TITOLO col trattino
            topLine("CODICE CIVILE", y: 520, x0: 342),               // banner
        ]
        lines += bodyFill(0, 400)
        let d = doc([page(0, lines)])
        let all = d.structure.map { $0.text ?? "" }.joined(separator: " | ")
        XCTAssertFalse(all.contains("ARTT. 1320-1329"), "il range-testatina è furniture (rimosso)")
        XCTAssertFalse(all.contains("TITOLO II - Dei contratti"), "la testatina TITOLO col trattino è furniture")
        XCTAssertFalse(all.contains("CODICE CIVILE"), "il banner è furniture")
    }

    func test_libro_spelledDivider_recoveredAsHeading1() {
        // il divisore-LIBRO a parole «LIBRO QUARTO» finisce incollato in coda al BODY del
        // libro precedente (è a inizio-pagina dove il corpo prosegue): lo split lo stacca → H1.
        var lines = bodyFill(0, 420)
        lines.append(bodyLine("previa dichiarazione al creditore. LIBRO QUARTO", y: 300))
        lines.append(articleLine("1173", ". Fonti delle obbligazioni. – [I]. Le obbligazioni.", y: 282))
        let d = doc([page(0, lines)])
        XCTAssertTrue(texts(d, .HEADING_1).contains { $0 == "LIBRO QUARTO" },
                      "il divisore LIBRO a parole è staccato come radice HEADING_1")
        XCTAssertFalse(texts(d, .HEADING_1).contains { $0.contains("previa dichiarazione") },
                       "il corpo precedente NON entra nell'intestazione (split pulito)")
    }

    func test_fiveLevels_distinct_titoloFused_articleOwnCategory() {
        var lines = bodyFill(0, 480)
        lines.append(bodyLine("conclusione del precedente libro. LIBRO QUARTO", y: 372))
        lines.append(bodyLine("TITOLO II", y: 360))
        lines.append(bodyLine("Dei contratti in generale", y: 351))
        lines.append(bodyLine("CAPO I– Disposizioni preliminari", y: 342))
        lines.append(bodyLine("SEZIONE I– Dell’accordo", y: 333))
        lines.append(articleLine("1321", ". Nozione. – [I]. Il contratto.", y: 324))
        let d = doc([page(0, lines)])
        XCTAssertTrue(texts(d, .HEADING_1).contains { $0 == "LIBRO QUARTO" }, "LIBRO=H1")
        XCTAssertTrue(texts(d, .HEADING_2).contains { $0 == "TITOLO II - Dei contratti in generale" }, "TITOLO=H2 fuso")
        XCTAssertTrue(texts(d, .HEADING_3).contains { $0.contains("CAPO I") }, "CAPO=H3")
        XCTAssertTrue(texts(d, .HEADING_4).contains { $0.contains("SEZIONE I") }, "SEZIONE=H4")
        XCTAssertTrue(texts(d, .ARTICLE_HEADER).contains { $0.contains("1321") }, "ARTICOLO=ARTICLE_HEADER")
    }

    func test_nonCodiciGeometry_articleLineStaysBody() {
        var lines = bodyFill(0, 420)
        lines.append(articleLine("1321", ". Nozione. – [I]. Il contratto è l’accordo.", y: 380))
        // geometria NON-codici (483×684) → isCodici=false → nessuna promozione
        let d = doc([page(0, lines, w: 483, h: 684)])
        XCTAssertEqual(texts(d, .HEADING_4).count, 0, "fuori codici: nessuna promozione (byte-identico)")
        XCTAssertNotEqual(d.profile.profile_id, "codici")
    }
}
