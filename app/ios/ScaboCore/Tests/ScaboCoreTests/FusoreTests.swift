//
//  FusoreTests.swift
//  ScaboCoreTests
//
//  Il fusore portato in Swift (Fusore.swift): la semantica di Python per punti di codice (norm, split, marcatore),
//  le guardie del banco (marcatore, primo elemento di nota di B, righe della coda), le operazioni (rietichettatura
//  slot-preserving, ricucitura MULTIPAGE a livello d'estrazione, riordino stabile) e la rete di fedeltà. Documenti ed
//  estrazioni sintetici con parole di prova: nessun testo dei volumi.
//

import XCTest
@testable import ScaboCore

final class FusoreTests: XCTestCase {

    // MARK: Semantica di Python

    func test_norm_minuscolo_soloAlfanumerici_perPuntiDiCodice() {
        XCTAssertEqual(String(String.UnicodeScalarView(Fusore.norm("Prova, «UNO» 12° è"))), "provauno12è")
        // Lettera e accento combinante: Python tiene la lettera e scarta il segno (categoria Mn), come qui.
        XCTAssertEqual(Fusore.norm("e\u{0300}").count, 1)
        // ½ ha un valore numerico: alfanumerico per Python.
        XCTAssertEqual(Fusore.norm("½").count, 1)
        XCTAssertEqual(Fusore.norm(nil), [])
    }

    func test_words_comeStrSplit() {
        XCTAssertEqual(Fusore.words("  una\u{00A0}due\ttre\n quattro "), ["una", "due", "tre", "quattro"])
        XCTAssertEqual(Fusore.words("uno\u{001C}due"), ["uno", "due"])   // separatore d'informazione: spazio per Python
        XCTAssertEqual(Fusore.words("uno\u{200B}due"), ["uno\u{200B}due"]) // spazio a larghezza zero: non è spazio
        XCTAssertEqual(Fusore.words(""), [])
    }

    func test_marcatore_comeLEspressioneDelBanco() {
        for yes in ["12. testo", " (3) testo", "4) testo", "[5] no", "1234. testo", "* nota", "† nota", "‡", "  7.", "(12)"] where !yes.hasPrefix("[") {
            XCTAssertTrue(Fusore.opensWithMarker(yes), yes)
        }
        for no in ["12345. troppe cifre", "testo 1.", "a) lettera", "(a) lettera", "12 senza chiusura", "", "((1)", "§ 3"] {
            XCTAssertFalse(Fusore.opensWithMarker(no), no)
        }
        XCTAssertTrue(Fusore.opensWithMarker("5] chiusa da quadra"))
    }

    // MARK: Livello nodo

    private func doc(_ nodes: [NodeDict]) -> ScabopdfDocument {
        ScabopdfDocument(schema_version: "0.7.0", document_id: "doc_prova",
                         metadata: DocumentMetadata(pages_pdf: 3, page_size_pt: [595, 842], source_pdf_filename: "prova.pdf"),
                         profile: DocumentProfileDict(profile_id: "codici", editorial_family: "codici", genre: "codice", confidence: 1),
                         structure: nodes)
    }

    func test_paginaSenzaNote_rietichettaLeNoteSenzaMarcatore_eProteggeLeAltre() {
        let d = doc([
            NodeDict(id: "node_1", type: .BODY, page_index: 1, text: "voce di prova uno"),
            NodeDict(id: "node_2", type: .NOTE, page_index: 1, text: "sottovoce di prova senza marcatore", length_category: .SHORT),
            NodeDict(id: "node_3", type: .NOTE, page_index: 1, text: "(7) nota vera di prova", length_category: .SHORT),
            NodeDict(id: "node_4", type: .NOTE, page_index: 2, text: "sottovoce della pagina dopo", length_category: .SHORT),
        ])
        let verdicts: FusoreVerdicts = { page in
            page == 2 ? [LayoutVerdictItem(label: "list_item", order: 0, bbox: nil, text: "voce")]
                : [LayoutVerdictItem(label: "footnote", order: 0, bbox: nil, text: "nota")]
        }
        let out = Fusore.fuseDocument(d, phenomena: [.sectorRelabelNoFootnote(pages: [2, 3])], verdicts: verdicts)
        let fused = try! XCTUnwrap(out)
        XCTAssertEqual(fused.value.structure.map { $0.type }, [.BODY, .BODY, .NOTE, .NOTE])
        XCTAssertNil(fused.value.structure[1].length_category)
        XCTAssertEqual(fused.value.structure[2].length_category, .SHORT)
        XCTAssertEqual(fused.operations, [.relabel(node: "node_2", from: "NOTE", to: "BODY", reason: "modello:zero-footnote p.2")])
        // Il testo è intoccato.
        XCTAssertEqual(fused.value.structure.map { $0.text }, d.structure.map { $0.text })
    }

    func test_didascalia_rietichettata_soloSeAncorataESenzaMarcatore() {
        let d = doc([
            NodeDict(id: "node_1", type: .NOTE, page_index: 0, text: "Figura di prova: andamento dei casi negli anni"),
            NodeDict(id: "node_2", type: .NOTE, page_index: 0, text: "15. Una nota vera che il modello scambia per didascalia"),
        ])
        let verdicts: FusoreVerdicts = { _ in [
            LayoutVerdictItem(label: "caption", order: 0, bbox: nil, text: "Figura di prova: andamento dei casi negli anni"),
            LayoutVerdictItem(label: "caption", order: 1, bbox: nil, text: "15. Una nota vera che il modello scambia per didascalia"),
            LayoutVerdictItem(label: "caption", order: 2, bbox: nil, text: "corta"),
        ] }
        let fused = try! XCTUnwrap(Fusore.fuseDocument(d, phenomena: [.captionRelabel(pages: [1])], verdicts: verdicts))
        XCTAssertEqual(fused.value.structure.map { $0.type }, [.BODY, .NOTE])
        XCTAssertTrue(fused.referto.contains { $0.contains("guardia-marcatore protegge il nodo node_2") })
    }

    // MARK: Livello estrazione

    private func line(_ text: String, y: Double, size: Double = 8) -> PdfTextLine {
        let bb = BBox(x: 50, y: y, width: 400, height: size + 2)
        return PdfTextLine(spans: [PdfSpan(text: text, fontSize: size, bold: false, italic: false, color: "#000000", bbox: bb)], bbox: bb)
    }

    func test_multipage_righeDellaCodaInCodaAllaPaginaA() {
        let a = PdfPageExtraction(pageIndex: 45, width: 595, height: 842, lines: [
            line("corpo di prova della pagina a", y: 700, size: 11), line("12. testa della nota che continua", y: 120)])
        let b = PdfPageExtraction(pageIndex: 46, width: 595, height: 842, lines: [
            line("corpo di prova della pagina b", y: 700, size: 11),
            line("prima riga della coda della nota", y: 140), line("seconda riga della coda della nota", y: 128),
            line("13. nota nuova della pagina b", y: 110)])
        let ex = PdfExtraction(version: 2, pageCount: 47, pages: [a, b])
        let verdicts: FusoreVerdicts = { page in
            page == 47 ? [LayoutVerdictItem(label: "text", order: 0, bbox: nil, text: "corpo di prova della pagina b"),
                          LayoutVerdictItem(label: "footnote", order: 1, bbox: nil,
                                            text: "prima riga della coda della nota seconda riga della coda della nota"),
                          LayoutVerdictItem(label: "footnote", order: 2, bbox: nil, text: "13. nota nuova della pagina b")] : []
        }
        let fused = try! XCTUnwrap(Fusore.fuseExtraction(ex, phenomena: [.multipageStitch(pairs: [FusorePagePair(46, 47)])], verdicts: verdicts))
        XCTAssertEqual(fused.operations, [.stitchMultipage(pageA: 46, pageB: 47, linesMoved: 2, fromIndex: 1)])
        XCTAssertEqual(fused.value.pages[0].lines.count, 4)
        XCTAssertEqual(fused.value.pages[1].lines.count, 2)
        XCTAssertEqual(fused.value.pages[0].lines.last?.spans.first?.text, "seconda riga della coda della nota")
    }

    func test_multipage_primaNotaDiBConMarcatore_nessunaOperazione() {
        let a = PdfPageExtraction(pageIndex: 0, width: 595, height: 842, lines: [line("1. nota della pagina uno", y: 100)])
        let b = PdfPageExtraction(pageIndex: 1, width: 595, height: 842, lines: [line("2. nota della pagina due", y: 100)])
        let ex = PdfExtraction(version: 2, pageCount: 2, pages: [a, b])
        let verdicts: FusoreVerdicts = { _ in [LayoutVerdictItem(label: "footnote", order: 0, bbox: nil, text: "2. nota della pagina due")] }
        let fused = try! XCTUnwrap(Fusore.fuseExtraction(ex, phenomena: [.multipageStitch(pairs: [FusorePagePair(1, 2)])], verdicts: verdicts))
        XCTAssertTrue(fused.operations.isEmpty)
        XCTAssertEqual(fused.value, ex)
    }

    func test_riordino_stabile_secondoLOrdineDelModello() {
        let p = PdfPageExtraction(pageIndex: 0, width: 595, height: 842, lines: [
            line("colonna destra in alto", y: 700), line("colonna sinistra in alto", y: 700), line("colonna sinistra in basso", y: 600)])
        var lines = p.lines
        lines[0].bbox = BBox(x: 320, y: 700, width: 200, height: 10)
        lines[1].bbox = BBox(x: 50, y: 700, width: 200, height: 10)
        lines[2].bbox = BBox(x: 50, y: 600, width: 200, height: 10)
        let ex = PdfExtraction(version: 2, pageCount: 1, pages: [PdfPageExtraction(pageIndex: 0, width: 595, height: 842, lines: lines)])
        // Riquadri del modello in alto a sinistra: colonna sinistra (ordine 0) poi destra (ordine 1).
        let verdicts: FusoreVerdicts = { _ in [
            LayoutVerdictItem(label: "text", order: 0, bbox: [40, 100, 260, 260], text: nil),
            LayoutVerdictItem(label: "text", order: 1, bbox: [310, 100, 530, 260], text: nil)] }
        let fused = try! XCTUnwrap(Fusore.fuseExtraction(ex, phenomena: [.reorderPages(pages: [1])], verdicts: verdicts))
        XCTAssertEqual(fused.value.pages[0].lines.map { $0.spans[0].text },
                       ["colonna sinistra in alto", "colonna sinistra in basso", "colonna destra in alto"])
        XCTAssertEqual(fused.operations, [.reorderPage(page: 1, lines: 3, moved: 3)])
    }

    // MARK: Rete di fedeltà

    func test_reteDiFedelta_multinsiemeIdentico() {
        var r: [String] = []
        XCTAssertTrue(Fusore.fidelity(["a": 2, "b": 1], ["b": 1, "a": 2], &r))
        XCTAssertFalse(Fusore.fidelity(["a": 2], ["a": 1, "c": 1], &r))
        // Il referto della rete rotta non porta parole (conteggi soli).
        XCTAssertEqual(r.last, "rete di fedeltà: ROTTA — 1 parole perse, 1 fabbricate: la fusione non si applica")
    }
}
