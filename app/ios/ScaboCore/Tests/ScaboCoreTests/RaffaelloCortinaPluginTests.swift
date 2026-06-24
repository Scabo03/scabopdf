//
//  RaffaelloCortinaPluginTests.swift
//  ScaboCoreTests
//
//  Tests del plugin Raffaello Cortina (Saggi): la PORTA (`matches`) gated sul formato
//  tascabile, la promozione dei sotto-titoli di sezione a HEADING_4, e le DUE RETI.
//
//  Rete A — nessuna perdita di contenuto: un sotto-titolo promosso resta un nodo letto,
//  cambia solo ruolo (NOTA→HEADING_4) e mantiene il testo verbatim.
//  Rete B — tutto il già-fatto invariato: l'emissione è byte-identica al Generic per ogni
//  item non promosso (stesso conteggio/ordine dei nodi per pagina), così lo zip 1:1 di
//  `bindAndPlaceNotes` resta allineato e la nota lunga scarica al sotto-titolo vicino.
//
//  I builder costruiscono bbox REALI (origine in basso-sinistra, y verso l'alto, come
//  `summarizeLine`): il riconoscitore usa la geometria (fascia di pagina, larghezza),
//  quindi i test non possono usare bbox a zero.
//

import XCTest
@testable import ScaboCore

final class RaffaelloCortinaPluginTests: XCTestCase {

    // MARK: - Builders (geometria reale)

    private let pageW = 453.0
    private let pageH = 694.0
    private let bodyColor = "#231f20"

    /// Una riga a una sola span, con bbox reale. `yTop` è il bordo alto (origine in basso).
    private func ln(_ text: String, size: Double, yTop: Double, x0: Double, x1: Double,
                    color: String = "#231f20", bold: Bool = false) -> PdfTextLine {
        let h = size * 1.2
        let bbox = BBox(x: x0, y: yTop - h, width: x1 - x0, height: h)
        return PdfTextLine(
            spans: [PdfSpan(text: text, fontSize: size, bold: bold, italic: false, color: color, bbox: bbox)],
            bbox: bbox)
    }

    /// Una riga di corpo con un marcatore di richiamo SMALLER in coda (span numerico piccolo).
    private func bodyWithMarker(_ text: String, marker: String, size: Double, yTop: Double,
                                x0: Double, x1: Double) -> PdfTextLine {
        let h = size * 1.2
        let bodySpan = PdfSpan(text: text, fontSize: size, bold: false, italic: false, color: bodyColor,
                               bbox: BBox(x: x0, y: yTop - h, width: x1 - x0 - 6, height: h))
        let mk = PdfSpan(text: marker, fontSize: size * 0.6, bold: false, italic: false, color: bodyColor,
                         bbox: BBox(x: x1 - 6, y: yTop - h, width: 6, height: h))
        return PdfTextLine(spans: [bodySpan, mk], bbox: BBox(x: x0, y: yTop - h, width: x1 - x0, height: h))
    }

    /// Una pagina-saggio Cortina: 5 righe di corpo, un sotto-titolo maiuscolo piccolo a metà
    /// pagina, altre 3 righe di corpo. Geometria 453×694, nero #231f20.
    private func cortinaBodyPage(_ index: Int, head: String = "TERZO E QUARTO POTERE",
                                 headSize: Double = 9.3) -> PdfPageExtraction {
        var lines: [PdfTextLine] = []
        var y = 600.0
        for i in 0..<5 { lines.append(ln("Riga di corpo numero \(i) del saggio, piena fino al margine destro.", size: 11.5, yTop: y, x0: 85, x1: 385)); y -= 14 }
        // sotto-titolo di sezione (maiuscolo, piccolo, corto) a metà pagina
        lines.append(ln(head, size: headSize, yTop: 470, x0: 85, x1: 205))
        y = 450
        for i in 0..<3 { lines.append(ln("Altra riga di corpo \(i) che prosegue la sezione fino al margine.", size: 11.5, yTop: y, x0: 85, x1: 385)); y -= 14 }
        return PdfPageExtraction(pageIndex: index, width: pageW, height: pageH, lines: lines)
    }

    private func extraction(_ pages: [PdfPageExtraction]) -> PdfExtraction {
        PdfExtraction(version: 2, pageCount: pages.count, pages: pages)
    }

    // MARK: - matches (la porta)

    func test_matches_firesOnCortinaShape() {
        let pages = (0..<12).map { cortinaBodyPage($0) }
        let score = raffaelloCortinaPlugin.matches(extraction(pages))
        XCTAssertGreaterThanOrEqual(score, DISPATCH_THRESHOLD)
        XCTAssertEqual(selectPlugin(extraction(pages)).id, "raffaello_cortina")
    }

    func test_matches_zeroOnNonCortinaGeometry() {
        // Stessi segnali (sotto-titoli maiuscoli piccoli) ma formato manuale 482×680 → porta chiusa.
        let pages = (0..<12).map { i -> PdfPageExtraction in
            let p = cortinaBodyPage(i)
            return PdfPageExtraction(pageIndex: i, width: 482, height: 680, lines: p.lines)
        }
        XCTAssertEqual(raffaelloCortinaPlugin.matches(extraction(pages)), 0.0)
        XCTAssertTrue(selectPlugin(extraction(pages)) === genericPlugin)
    }

    func test_matches_zeroOnTinyExtraction() {
        let tiny = PdfExtraction(version: 2, pageCount: 1, pages: [
            PdfPageExtraction(pageIndex: 0, width: 595, height: 842, lines: [ln("x", size: 12, yTop: 800, x0: 0, x1: 10)])])
        XCTAssertEqual(raffaelloCortinaPlugin.matches(tiny), 0.0)
    }

    // MARK: - Promozione + Rete A (testo preservato)

    func test_build_promotesCapsSectionToHeading4_textPreserved() {
        let doc = raffaelloCortinaPlugin.build(extraction([cortinaBodyPage(0)]), sourceName: "delitti.pdf")
        let heads = doc.structure.filter { $0.type == .HEADING_4 }
        XCTAssertEqual(heads.count, 1)
        XCTAssertEqual(heads.first?.text, "TERZO E QUARTO POTERE")   // rete A: testo verbatim
        XCTAssertEqual(heads.first?.level, 4)
        XCTAssertFalse(doc.structure.contains { $0.type == .NOTE && $0.text == "TERZO E QUARTO POTERE" })
    }

    func test_build_promotesNumberedCapsSection() {
        // Il maiuscoletto numerato di Pubblico ministero ("6. STRATEGIE…") va promosso.
        let doc = raffaelloCortinaPlugin.build(
            extraction([cortinaBodyPage(0, head: "6. STRATEGIE COMUNICATIVE DELLE PROCURE")]),
            sourceName: "pm.pdf")
        XCTAssertTrue(doc.structure.contains { $0.type == .HEADING_4 && $0.text == "6. STRATEGIE COMUNICATIVE DELLE PROCURE" })
    }

    func test_build_doesNotPromoteMixedCaseShortLine() {
        let doc = raffaelloCortinaPlugin.build(
            extraction([cortinaBodyPage(0, head: "Una riga corta a caso misto")]),
            sourceName: "x.pdf")
        XCTAssertFalse(doc.structure.contains { $0.type == .HEADING_4 })
        XCTAssertTrue(doc.structure.contains { $0.type == .NOTE && ($0.text ?? "").contains("caso misto") })
    }

    func test_build_doesNotPromoteBottomBandCapsNote() {
        // Un apparato-nota maiuscolo nella fascia di piè (yFracTop>0.80) NON è un sotto-titolo.
        var lines: [PdfTextLine] = []
        var y = 600.0
        for i in 0..<6 { lines.append(ln("Riga di corpo \(i) piena fino al margine destro del saggio.", size: 11.5, yTop: y, x0: 85, x1: 385)); y -= 14 }
        lines.append(ln("UNA SIGLA IN FONDO PAGINA", size: 9.3, yTop: 80, x0: 85, x1: 205))  // yFracTop≈0.88
        let page = PdfPageExtraction(pageIndex: 0, width: pageW, height: pageH, lines: lines)
        let doc = raffaelloCortinaPlugin.build(extraction([page]), sourceName: "x.pdf")
        XCTAssertFalse(doc.structure.contains { $0.type == .HEADING_4 })
    }

    // MARK: - Rete B (allineamento Generic / zip NoteBinding)

    /// L'emissione Cortina coincide col Generic per ogni item NON promosso: stesso conteggio
    /// e ordine dei nodi, e i soli nodi divergenti sono NOTE (Generic) ↔ HEADING_4 (Cortina)
    /// col MEDESIMO testo. È la prova strutturale che lo zip 1:1 non si rompe.
    func test_reteB_structuralAlignmentWithGeneric() {
        let ext = extraction([cortinaBodyPage(0), cortinaBodyPage(1)])
        let g = genericPlugin.build(ext, sourceName: "x.pdf").structure
        let c = raffaelloCortinaPlugin.build(ext, sourceName: "x.pdf").structure
        XCTAssertEqual(g.count, c.count, "conteggio nodi per documento identico")
        for (gn, cn) in zip(g, c) {
            XCTAssertEqual(gn.page_index, cn.page_index)
            XCTAssertEqual(gn.text, cn.text, "testo verbatim invariato (rete A)")
            if gn.type == cn.type {
                continue
            } else {
                // unica divergenza ammessa: il Generic dice NOTE, Cortina dice HEADING_4
                XCTAssertEqual(gn.type, .NOTE)
                XCTAssertEqual(cn.type, .HEADING_4)
            }
        }
    }

    /// Una nota lunga richiamata nel corpo viene scaricata al sotto-titolo di sezione vicino
    /// (promosso a HEADING_4) invece che a fine documento. Prova end-to-end di build→bind.
    func test_reteB_longNoteFlushesAtPromotedSubtitle() {
        var lines: [PdfTextLine] = []
        // corpo con marcatore "1" (richiamo) in coda
        lines.append(bodyWithMarker("Nel processo si pone il tema della pubblicità del dibattimento.",
                                    marker: "1", size: 11.5, yTop: 600, x0: 85, x1: 385))
        for i in 0..<4 { lines.append(ln("Riga di corpo \(i) che riempie la colonna fino al margine destro.", size: 11.5, yTop: 586 - Double(i) * 14, x0: 85, x1: 385)) }
        // sotto-titolo di sezione (prossimo HEADING dopo il richiamo)
        lines.append(ln("TERZO E QUARTO POTERE", size: 9.3, yTop: 470, x0: 85, x1: 205))
        lines.append(ln("Inizio della sezione successiva, riga di corpo piena.", size: 11.5, yTop: 452, x0: 85, x1: 385))
        // nota lunga a piè di pagina (MEDIUM/LONG → differita)
        let longNote = "1. Una nota lunga che discute a fondo la questione, con riferimenti dottrinali e giurisprudenziali estesi che superano la soglia delle note brevi lette a fine frase."
        lines.append(ln(longNote, size: 8.0, yTop: 110, x0: 85, x1: 385))
        let page = PdfPageExtraction(pageIndex: 0, width: pageW, height: pageH, lines: lines)
        let ext = extraction([page])

        let raw = raffaelloCortinaPlugin.build(ext, sourceName: "delitti.pdf")
        let (placed, stats) = bindAndPlaceNotes(raw, ext)

        // la nota è stata agganciata e differita (non breve)
        XCTAssertEqual(stats.placedLong, 1)
        let s = placed.structure
        guard let headIdx = s.firstIndex(where: { $0.type == .HEADING_4 }),
              let noteIdx = s.firstIndex(where: { $0.type == .NOTE && ($0.text ?? "").contains("nota lunga") }) else {
            return XCTFail("attesi un HEADING_4 e la nota lunga piazzata")
        }
        XCTAssertLessThan(noteIdx, headIdx, "la nota lunga è letta PRIMA del sotto-titolo vicino")
        // memory refresh (§7.4/7.5) calcolato sulla distanza piccola
        XCTAssertNotNil(placed.structure[noteIdx].memoryRefresh)
        XCTAssertFalse((placed.structure[noteIdx].memoryRefresh ?? "").isEmpty)
    }
}
