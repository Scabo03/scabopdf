//
//  RivistaDpcRecoveryTests.swift
//  ScaboCoreTests
//
//  Ramo Riviste — porta DPC: recupero dell'apparato di note che SPORGE nel margine
//  sinistro (riga taglia-nota SOTTO il blocco-corpo → NOTE, non glossa). Verifica le
//  due direzioni della precisione (recupera le note vere; NON risucchia le glosse
//  genuine "Sommario"/bilingui che stanno in alto) e il gating (fuori dalla firma
//  567×814 + corpo≈10pt → nessun cambiamento, decisione storica).
//
//  Convenzione di coordinate (PDFKit on-device, origine in basso-sinistra): `bbox.y`
//  GRANDE = ALTO in pagina; le note a piè stanno in BASSO → `bbox.y` PICCOLO, sotto il
//  corpo. I test costruiscono quindi il corpo a y alta e l'apparato a y bassa.
//

import XCTest
@testable import ScaboCore

final class RivistaDpcRecoveryTests: XCTestCase {

    private func line(_ text: String, size: Double, x0: Double, x1: Double, y: Double) -> PdfTextLine {
        let bbox = BBox(x: x0, y: y, width: x1 - x0, height: size)
        return PdfTextLine(
            spans: [PdfSpan(text: text, fontSize: size, bold: false, italic: false,
                            color: "#000000", bbox: bbox)],
            bbox: bbox)
    }
    /// Pagina della Rivista DPC (567×814) salvo override per il test di gating.
    private func page(_ idx: Int, _ lines: [PdfTextLine], w: Double = 567, h: Double = 814) -> PdfPageExtraction {
        PdfPageExtraction(pageIndex: idx, width: w, height: h, lines: lines)
    }
    /// Corpo a colonna singola DPC: x0≈154, x1≈520 (largo > 0.40 pagina), a y ALTA
    /// (parte alta della pagina), discendente.
    private func bodyLines(_ n: Int, size: Double = 10) -> [PdfTextLine] {
        (0..<n).map { line("Riga di corpo numero \($0) abbastanza lunga da riempire la colonna del fascicolo.",
                           size: size, x0: 154, x1: 520, y: 600 - Double($0) * 14) }
    }
    private func doc(_ pages: [PdfPageExtraction]) -> ScabopdfDocument {
        buildDocumentFromPdf(PdfExtraction(version: 2, pageCount: pages.count, pages: pages), sourceName: "dpc.pdf")
    }
    private func ex(_ pages: [PdfPageExtraction]) -> PdfExtraction {
        PdfExtraction(version: 2, pageCount: pages.count, pages: pages)
    }
    private func texts(_ d: ScabopdfDocument, _ c: SemanticCategory) -> String {
        d.structure.filter { $0.type == c }.map { $0.text ?? "" }.joined(separator: " | ")
    }

    // ── La porta ─────────────────────────────────────────────────────────────────

    func test_gate_matches_onlyOnDpcSignature() {
        let dpc = ex([page(0, bodyLines(6))])
        XCTAssertGreaterThanOrEqual(rivistaDpcPlugin.matches(dpc), DISPATCH_THRESHOLD,
                                    "la porta scatta sulla firma DPC (567×814 + corpo≈10)")
        // geometria diversa → porta chiusa
        let other = ex([page(0, bodyLines(6), w: 595, h: 842)])
        XCTAssertEqual(rivistaDpcPlugin.matches(other), 0.0, "fuori geometria → porta chiusa")
        // geometria DPC ma corpo fuori banda (≈14pt) → porta chiusa
        let bigBody = ex([page(0, bodyLines(6, size: 14))])
        XCTAssertEqual(rivistaDpcPlugin.matches(bigBody), 0.0, "corpo fuori [9,11] → porta chiusa")
    }

    func test_dpcVolume_dispatchesToRivistaDpcPlugin() {
        let d = doc([page(0, bodyLines(6))])
        XCTAssertEqual(d.profile.profile_id, "rivista_dpc")
    }

    // ── Recupero: nota sotto il corpo (sporge a sinistra) → NOTE ──────────────────

    func test_footnoteBelowBody_hangingLeft_recoveredAsNote() {
        var lines = bodyLines(6)                                  // corpo a y 600..530, colonna [154,520]
        // apparato a piè: due note-corte che sporgono nel margine sinistro (x1<154), y BASSA
        lines.append(line("37 Vogel (2002b).", size: 8, x0: 77, x1: 138, y: 90))
        lines.append(line("42 Tripodi (2013).", size: 8, x0: 77, x1: 140, y: 78))
        let d = doc([page(0, lines)])
        XCTAssertTrue(texts(d, .NOTE).contains("Vogel (2002b)"),
                      "la nota a piè che sporge a sinistra è recuperata a NOTE")
        XCTAssertTrue(texts(d, .NOTE).contains("Tripodi (2013)"))
        XCTAssertFalse(texts(d, .MARGINAL_GLOSS).contains("Vogel"),
                       "non resta in glossa (non sarebbe letta)")
    }

    func test_recoveredFootnote_isInReadFlow_reteA() {
        var lines = bodyLines(6)
        lines.append(line("60 Galluccio (2018), nota vera dell'apparato.", size: 8, x0: 77, x1: 150, y: 85))
        let d = doc([page(0, lines)])
        let read = buildBaseSegments(d).map { $0.text }.joined(separator: " ")
        XCTAssertTrue(read.contains("Galluccio (2018)"),
                      "rete A: la nota prima persa ora è LETTA (non più scartata come glossa)")
    }

    // ── Precisione opposta: la glossa genuina (in ALTO) resta glossa ──────────────

    func test_genuineGloss_aboveBody_staysGloss() {
        var lines = bodyLines(6)
        // etichetta "Sommario" verticale nel margine alto-sinistro (y ALTA, sopra il corpo)
        lines.insert(line("Sommario", size: 8, x0: 77, x1: 122, y: 720), at: 0)
        let d = doc([page(0, lines)])
        XCTAssertTrue(texts(d, .MARGINAL_GLOSS).contains("Sommario"),
                      "la glossa genuina in alto NON è risucchiata: resta glossa")
        XCTAssertFalse(texts(d, .NOTE).contains("Sommario"))
    }

    func test_realNote_inColumn_bottom_staysNote() {
        var lines = bodyLines(6)
        // nota lunga DENTRO la colonna a fondo pagina (x in colonna): era già NOTE, resta NOTE
        lines.append(line("44 Nota lunga dentro la colonna del corpo, non sporge nel margine.",
                          size: 8, x0: 154, x1: 500, y: 80))
        let d = doc([page(0, lines)])
        XCTAssertTrue(texts(d, .NOTE).contains("dentro la colonna"))
    }

    // ── Gating: fuori dalla firma DPC, nessun cambiamento (decisione storica) ─────

    func test_nonDpcGeometry_belowBodyMarginLine_staysGloss() {
        // STESSO layout, ma geometria NON-DPC (595×842): isRivistaDpc=false →
        // comportamento storico del Generic: la riga a margine resta glossa.
        var lines = bodyLines(6)
        lines.append(line("37 Vogel (2002b).", size: 8, x0: 77, x1: 138, y: 90))
        let d = doc([page(0, lines, w: 595, h: 842)])
        XCTAssertTrue(texts(d, .MARGINAL_GLOSS).contains("Vogel"),
                      "fuori geometria DPC il recupero è un no-op: resta glossa (byte-identico)")
        XCTAssertNotEqual(d.profile.profile_id, "rivista_dpc")
    }
}
