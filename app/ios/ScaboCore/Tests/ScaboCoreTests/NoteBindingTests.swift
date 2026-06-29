//
//  NoteBindingTests.swift
//  ScaboCoreTests
//
//  Meccanica dell'aggancio richiamo↔nota e del piazzamento (§ 7.3), su estrazioni
//  sintetiche fatte passare per la pipeline reale del Generic
//  (`buildDocumentFromPdf` → `bindAndPlaceNotes`). Verifica: rilevamento del
//  marcatore SMALLER e PAREN, spezzettamento delle note fuse, scope di pagina,
//  guardia anti-collisione di numerazione, piazzamento breve (fine frase) e lungo
//  (fine sezione), e non-distruttività (nessuna nota persa).
//

import XCTest
@testable import ScaboCore

final class NoteBindingTests: XCTestCase {

    // MARK: - costruttori sintetici

    private func span(_ text: String, _ size: Double, color: String = "#000000") -> PdfSpan {
        PdfSpan(text: text, fontSize: size, bold: false, italic: false, color: color,
                bbox: BBox(x: 0, y: 0, width: Double(max(1, text.count)), height: size))
    }
    private func line(_ spans: [PdfSpan]) -> PdfTextLine {
        PdfTextLine(spans: spans, bbox: BBox(x: 0, y: 0, width: 100, height: 12))
    }
    /// Una riga di corpo a dimensione `body` con un marcatore SMALLER `mark` (a
    /// dimensione `small`) incastonato dopo `pre` e prima di `post`.
    private func bodyLineWithMarker(_ pre: String, _ mark: String, _ post: String,
                                    body: Double = 10, small: Double = 5) -> PdfTextLine {
        line([span(pre, body), span(mark, small), span(post, body)])
    }
    private func bodyLine(_ text: String, body: Double = 10) -> PdfTextLine {
        line([span(text, body)])
    }
    private func noteLine(_ text: String, small: Double = 8) -> PdfTextLine {
        line([span(text, small)])
    }
    private func extraction(_ pages: [[PdfTextLine]]) -> PdfExtraction {
        PdfExtraction(version: 2, pageCount: pages.count,
                      pages: pages.enumerated().map {
                          PdfPageExtraction(pageIndex: $0.offset, width: 595, height: 842, lines: $0.element)
                      })
    }
    private func placed(_ pages: [[PdfTextLine]]) -> (ScabopdfDocument, NotePlacementStats) {
        let ex = extraction(pages)
        let doc = buildDocumentFromPdf(ex, sourceName: "t.pdf")
        return bindAndPlaceNotes(doc, ex)
    }
    private func placedDoctrine(_ pages: [[PdfTextLine]]) -> (ScabopdfDocument, NotePlacementStats) {
        let ex = extraction(pages)
        let doc = buildDocumentFromPdf(ex, sourceName: "t.pdf")
        return bindAndPlaceNotes(doc, ex, placement: .doctrineInline)
    }
    private func types(_ doc: ScabopdfDocument) -> [SemanticCategory] { doc.structure.map { $0.type } }
    private func texts(_ doc: ScabopdfDocument) -> [String] { doc.structure.map { $0.text ?? "" } }

    // MARK: - rilevamento marcatori (unità)

    func test_detectSmallerMarker_offsetInJoinedText() {
        let l = bodyLineWithMarker("Il corpo del testo", "12", " e prosegue.", body: 10, small: 5)
        let sm = summarizeLine(l)
        let markers = detectInlineMarkers([sm], body: 10)
        XCTAssertEqual(markers.count, 1)
        XCTAssertEqual(markers.first?.value, 12)
        XCTAssertEqual(markers.first?.regime, .smaller)
        // offset deve cadere dove inizia "12" nel testo unito "Il corpo del testo12 e prosegue."
        let text = sm.text
        let off = markers.first!.offset
        let idx = text.index(text.startIndex, offsetBy: off)
        XCTAssertTrue(text[idx...].hasPrefix("12"), "offset punta al marcatore, non altrove")
    }

    func test_bareSameSizeDigit_isNeverAMarker() {
        // una cifra a dimensione del corpo (anno, quantità) NON è un richiamo
        let l = bodyLine("Nel 1995 la legge cambiò radicalmente.", body: 10)
        let markers = detectInlineMarkers([summarizeLine(l)], body: 10)
        XCTAssertEqual(markers.count, 0)
    }

    func test_detectParenMarker() {
        let l = bodyLine("La dottrina prevalente (12) esclude la tesi.", body: 10)
        let markers = detectInlineMarkers([summarizeLine(l)], body: 10)
        XCTAssertEqual(markers.map { $0.value }, [12])
        XCTAssertEqual(markers.first?.regime, .paren)
    }

    // MARK: - spezzettamento note fuse

    func test_splitFootnotes_separatesMergedNotes() {
        let lines = [noteLine("12 Prima nota breve."), noteLine("13 Seconda nota breve.")]
            .map { summarizeLine($0) }
        let foots = splitFootnotes(lines, page: 3)
        XCTAssertEqual(foots.count, 2)
        XCTAssertEqual(foots.map { $0.openingNumber }, [12, 13])
    }

    func test_splitFootnotes_leadingContinuationHasNilOpening() {
        let lines = [noteLine("continuazione dalla pagina precedente."), noteLine("14 Nota nuova.")]
            .map { summarizeLine($0) }
        let foots = splitFootnotes(lines, page: 5)
        XCTAssertEqual(foots.count, 2)
        XCTAssertNil(foots[0].openingNumber)
        XCTAssertEqual(foots[1].openingNumber, 14)
    }

    // MARK: - piazzamento breve (fine frase)

    func test_shortNote_placedAfterSentenceOfMarker() {
        let pages = [[
            bodyLineWithMarker("Prima frase con richiamo", "12", " a metà periodo qui. Seconda frase pulita."),
            noteLine("12 Nota breve."),
        ]]
        let (doc, stats) = placed(pages)
        XCTAssertEqual(stats.boundSamePage, 1)
        XCTAssertEqual(stats.placedShort, 1)
        // atteso: [BODY "…qui."], [NOTE "12 Nota breve."], [BODY "Seconda frase pulita."]
        XCTAssertEqual(types(doc), [.BODY, .NOTE, .BODY])
        XCTAssertTrue(texts(doc)[0].hasSuffix("qui."), "primo pezzo finisce alla frase del richiamo")
        XCTAssertTrue(texts(doc)[1].contains("Nota breve"))
        XCTAssertEqual(texts(doc)[2], "Seconda frase pulita.")
    }

    // MARK: - piazzamento lungo (fine sezione)

    func test_longNote_deferredToSectionEnd() {
        let longText = "13 " + String(repeating: "parola ", count: 60) + "fine."  // > 100 char → MEDIUM+
        // Abbastanza righe di corpo (10pt) perché la stima del corpo non collassi
        // sulla dimensione dei titoli (collasso noto del Generic su pochi campioni).
        let pages = [[
            line([span("TITOLO DI SEZIONE", 18)]),                       // HEADING_1
            bodyLine("Prima riga di corpo della sezione uno."),
            bodyLineWithMarker("Corpo con richiamo lungo", "13", " e altro testo qui."),
            bodyLine("Terza riga di corpo della sezione uno."),
            bodyLine("Quarta riga di corpo della sezione uno."),
            noteLine(longText),
            line([span("PROSSIMA SEZIONE", 18)]),                        // HEADING_1
            bodyLine("Corpo della seconda sezione."),
            bodyLine("Altra riga della seconda sezione."),
        ]]
        let (doc, stats) = placed(pages)
        XCTAssertEqual(stats.placedLong, 1)
        XCTAssertEqual(stats.placedShort, 0)
        // la nota lunga è letta PRIMA del prossimo HEADING, non a fondo pagina
        let t = types(doc)
        let firstHeadingAfterBody = t.firstIndex(of: .HEADING_1)!  // sezione 1
        let secondHeadingIdx = t[(firstHeadingAfterBody + 1)...].firstIndex(of: .HEADING_1)!
        XCTAssertEqual(t[secondHeadingIdx - 1], .NOTE, "la nota lunga precede immediatamente il prossimo titolo")
    }

    // MARK: - Dottrina Inline (§ 10.2/§ 10.5): ogni nota inline al richiamo, niente differimento

    func test_doctrineInline_longNotePlacedInlineNotDeferred() {
        let longText = "13 " + String(repeating: "parola ", count: 60) + "fine."  // > 100 char → MEDIUM+
        let pages = [[
            line([span("TITOLO DI SEZIONE", 18)]),
            bodyLine("Prima riga di corpo della sezione uno."),
            bodyLineWithMarker("Corpo con richiamo lungo", "13", " e altro testo qui."),
            bodyLine("Terza riga di corpo della sezione uno."),
            bodyLine("Quarta riga di corpo della sezione uno."),
            noteLine(longText),
            line([span("PROSSIMA SEZIONE", 18)]),
            bodyLine("Corpo della seconda sezione."),
        ]]
        // Lettura Continua: la nota lunga è DIFFERITA a fine sezione (verificato altrove).
        let (cont, contStats) = placed(pages)
        XCTAssertEqual(contStats.placedLong, 1, "continua: nota lunga differita")

        // Dottrina Inline: la stessa nota lunga è INLINE al richiamo, niente differimento.
        let (doc, stats) = placedDoctrine(pages)
        XCTAssertEqual(stats.placedShort, 1, "dottrina: ogni nota inline (conteggiata come 'short')")
        XCTAssertEqual(stats.placedLong, 0, "dottrina: nessun differimento a fine sezione (§ 10.2)")

        let t = types(doc)
        let noteIdx = t.firstIndex(of: .NOTE)!
        let lastHeadingIdx = t.lastIndex(of: .HEADING_1)!
        // La nota è inline al richiamo → fra la nota e il titolo della sezione successiva restano
        // ancora righe di corpo della sezione uno (in continua la nota le seguiva, a ridosso del titolo).
        XCTAssertTrue(t[(noteIdx + 1)..<lastHeadingIdx].contains(.BODY),
                      "dottrina: la nota precede il resto del corpo, non è a fine sezione")
        XCTAssertGreaterThan(lastHeadingIdx, cont.structure.firstIndex { $0.type == .NOTE }!,
                             "le due disposizioni differiscono")

        // § 10.5: nessun rinfresco di contesto sulle note di Dottrina Inline.
        let noteNode = doc.structure.first { $0.type == .NOTE }!
        XCTAssertTrue((noteNode.memoryRefresh ?? "").isEmpty, "dottrina: niente memory refresh (§ 10.5)")
    }

    func test_doctrineInline_shortNote_sameAsContinuous() {
        // Le note brevi sono inline in entrambi i layout: stesso risultato.
        let pages = [[
            bodyLineWithMarker("Prima frase con richiamo", "12", " a metà periodo qui. Seconda frase."),
            noteLine("12 Nota breve."),
        ]]
        let (cont, _) = placed(pages)
        let (doc, _) = placedDoctrine(pages)
        XCTAssertEqual(types(cont), types(doc), "le note brevi sono inline in entrambi → identico")
        XCTAssertEqual(texts(cont), texts(doc))
    }

    // MARK: - sicurezza: numerazione che riparte tra pagine

    func test_perPageNumberingRestart_doesNotCrossBind() {
        // pagina 0: richiamo "1" + nota "1" (breve). pagina 1: richiamo "1" + nota "1" (breve).
        // Ogni "1" deve legare alla nota della PROPRIA pagina, mai a quella dell'altra.
        let pages = [
            [bodyLineWithMarker("Pagina uno richiamo", "1", " qui."), noteLine("1 Nota della pagina uno.")],
            [bodyLineWithMarker("Pagina due richiamo", "1", " qui."), noteLine("1 Nota della pagina due.")],
        ]
        let (doc, stats) = placed(pages)
        XCTAssertEqual(stats.boundSamePage, 2)
        XCTAssertEqual(stats.boundCrossPage, 0)
        // ogni nota appare nella sua pagina
        let noteTexts = doc.structure.filter { $0.type == .NOTE }.map { $0.text ?? "" }
        XCTAssertTrue(noteTexts.contains { $0.contains("pagina uno") })
        XCTAssertTrue(noteTexts.contains { $0.contains("pagina due") })
        let p0 = doc.structure.filter { $0.page_index == 0 && $0.type == .NOTE }
        XCTAssertTrue(p0.allSatisfy { ($0.text ?? "").contains("pagina uno") }, "nessun cross-bind alla pagina sbagliata")
    }

    // MARK: - non-distruttività

    func test_unboundMarkerLeavesNoteInPlace() {
        // richiamo "99" senza nota corrispondente: la nota presente (numero 5) resta letta in posizione
        let pages = [[
            bodyLineWithMarker("Corpo con richiamo orfano", "99", " qui."),
            noteLine("5 Una nota che non c'entra."),
        ]]
        let (doc, stats) = placed(pages)
        XCTAssertEqual(stats.boundSamePage, 0)
        XCTAssertEqual(stats.unboundMarkers, 1)
        XCTAssertTrue(types(doc).contains(.NOTE), "la nota non agganciata resta presente (letta in posizione)")
    }

    func test_noNotes_documentUnchanged() {
        // Tutte righe a dimensione del corpo → nessun nodo NOTE → guardia di no-op.
        let pages = [[bodyLine("Prima riga."), bodyLine("Seconda riga."), bodyLine("Terza riga.")]]
        let ex = extraction(pages)
        let doc = buildDocumentFromPdf(ex, sourceName: "t.pdf")
        let (out, stats) = bindAndPlaceNotes(doc, ex)
        XCTAssertEqual(out, doc, "documento senza note invariato")
        XCTAssertEqual(stats.footnotes, 0)
    }

    // MARK: - richiamo su una CITAZIONE A BLOCCO (collaudo d'orecchio — bug 3)
    //
    // Su "Delitti in prima pagina" il richiamo della nota breve sedeva in coda alla
    // citazione della Genesi (10.3pt), sotto il corpo (11.5pt) ma sopra la soglia-nota.
    // La guardia stretta "riga a taglia-corpo ± 0.6" saltava la riga e il richiamo non
    // si trovava: la nota breve restava non agganciata, finendo a fine paragrafo.

    func test_detectSmallerMarker_onBlockQuoteSizedLine() {
        // Citazione a blocco a 8.7pt (corpo 10) con il richiamo "12" (5pt) in coda.
        // 8.7 ≥ NOTE_RATIO·10 = 8.5 → la riga è contenuto di corpo → si scandisce.
        let quote = line([span("e così l’episodio biblico si conclude.", 8.7), span("12", 5)])
        let markers = detectInlineMarkers([summarizeLine(quote)], body: 10)
        XCTAssertEqual(markers.map { $0.value }, [12], "il richiamo sulla citazione a blocco viene trovato")
        XCTAssertEqual(markers.first?.regime, .smaller)
    }

    func test_noteSizedLine_isNotScannedForMarkers() {
        // Una riga interamente a taglia-NOTA (8.0 < NOTE_RATIO·10 = 8.5): è apparato a
        // piè di pagina, non corpo → NON vi si cercano richiami (nessun falso marcatore).
        let noteish = line([span("testo della nota a piè di pagina ", 8.0), span("5", 4)])
        let markers = detectInlineMarkers([summarizeLine(noteish)], body: 10)
        XCTAssertEqual(markers.count, 0, "le righe a taglia-nota restano fuori dal rilevamento richiami")
    }

    func test_shortNote_onBlockQuote_bindsAndPlacesInline() {
        // End-to-end: corpo a 11pt per fissare il profilo, una citazione a blocco a 9.6pt
        // col richiamo "12" in coda, e la nota breve "12 …". La nota si aggancia e si piazza
        // INLINE (subito dopo la frase del richiamo), non a fine paragrafo.
        let pages = [[
            bodyLine("Prima riga di corpo a piena dimensione del documento per il profilo.", body: 11),
            bodyLine("Seconda riga di corpo che conferma la dimensione dominante del testo.", body: 11),
            line([span("La citazione a blocco si chiude qui.", 9.6), span("12", 5),
                  span(" E il corpo riprende normale.", 11)]),
            noteLine("12 Fonte della citazione.", small: 8),
        ]]
        let (doc, stats) = placed(pages)
        XCTAssertEqual(stats.boundSamePage, 1, "il richiamo sulla citazione si aggancia alla nota di pagina")
        XCTAssertEqual(stats.placedShort, 1, "la nota breve è piazzata (non lasciata in fondo)")
        let t = types(doc)
        let noteIdx = t.firstIndex(of: .NOTE)
        XCTAssertNotNil(noteIdx)
        XCTAssertEqual(t[noteIdx! - 1], .BODY, "la nota è interleavata subito dopo un pezzo di corpo")
        XCTAssertTrue(texts(doc).contains { $0.contains("Fonte della citazione") }, "la nota resta letta")
    }
}
