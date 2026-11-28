//
//  InnestoScansioniTests.swift
//  ScaboMacKitTests — l'innesto delle regioni di Heron sulle pagine lette (giro «scansioni, ricerca e build», 2026-11-28): una «glossa»
//  dentro una colonna larga diventa corpo (nota, se le sue righe stanno in regioni «footnote» di Heron), una glossa stretta o fuori dalle
//  regioni resta; una «nota» dentro una tabella ammessa diventa
//  non classificata (si legge al suo posto, non si fonde col corpo), una nota fuori resta; il testo dei nodi non cambia mai; l'innesto successivo riceve il documento rietichettato. Testi inventati.
//
import Foundation
import ScaboChain
import ScaboCore
import XCTest
@testable import ScaboMacKit

final class InnestoScansioniTests: XCTestCase {

    private func riga(_ t: String) -> PdfTextLine {
        PdfTextLine(spans: [PdfSpan(text: t, fontSize: 9, bold: false, italic: false, color: "#000000", bbox: BBox(x: 0, y: 0, width: 10, height: 10))],
                    bbox: BBox(x: 0, y: 0, width: 10, height: 10))
    }

    private func documento(_ nodi: [NodeDict]) -> ScabopdfDocument {
        ScabopdfDocument(schema_version: "0.7.0", document_id: "doc_prova",
                         metadata: DocumentMetadata(pages_pdf: 1, page_size_pt: [400, 600], source_pdf_filename: "prova.pdf"),
                         profile: DocumentProfileDict(profile_id: "generico", editorial_family: "generico", genre: "manuale", confidence: 0.5),
                         structure: nodi)
    }

    /// Una pagina letta con quattro righe: due in una colonna larga, una in una regione stretta, una fuori da ogni regione.
    private let testiDellaPagina = ["prima riga della colonna destra", "seconda riga della colonna destra", "parola a margine",
                                    "riga di una tabella con numeri"]
    private var estrazione: PdfExtraction {
        PdfExtraction(version: 1, pageCount: 1, pages: [PdfPageExtraction(pageIndex: 0, width: 400, height: 600, lines: testiDellaPagina.map(riga))])
    }
    private let regioni: [Int: [RegioneRiga]] = [0: [
        RegioneRiga(tipo: "list_item", dentro: true, frazioneLarghezza: 0.45, tabellaAmmessa: false),
        RegioneRiga(tipo: "text", dentro: true, frazioneLarghezza: 0.45, tabellaAmmessa: false),
        RegioneRiga(tipo: "text", dentro: true, frazioneLarghezza: 0.12, tabellaAmmessa: false),
        RegioneRiga(tipo: "table", dentro: true, frazioneLarghezza: 0.8, tabellaAmmessa: true),
    ]]

    private final class Dopo: ChainGraft {
        var ricevuto: ScabopdfDocument?
        func graft(extraction: PdfExtraction, rawDocument: ScabopdfDocument, pdfURL: URL, sourceName: String,
                   onPage: (Int, Int) -> Void, isCancelled: () -> Bool) -> ChainGraftOutput? {
            ricevuto = rawDocument
            return ChainGraftOutput(extraction: extraction, rawDocument: rawDocument, report: ["riga dell'innesto successivo"])
        }
    }

    private func innesta(_ nodi: [NodeDict], colonne: Bool = true, righeDiTabella: Bool = true, regioni r: [Int: [RegioneRiga]]? = nil,
                         poi: ChainGraft? = nil) -> (ChainGraftOutput, InnestoScansioni) {
        let i = InnestoScansioni(righe: r ?? regioni, colonne: colonne, righeDiTabella: righeDiTabella, poi: poi)
        let out = i.graft(extraction: estrazione, rawDocument: documento(nodi), pdfURL: URL(fileURLWithPath: "/dev/null"), sourceName: "prova.pdf",
                          onPage: { _, _ in }, isCancelled: { false })!
        return (out, i)
    }

    func test_glossaNellaColonnaLarga_diventaCorpo_laStrettaResta() {
        let colonna = NodeDict(id: "node_1", type: .MARGINAL_GLOSS, page_index: 0, text: "prima riga della colonna destra seconda riga della colonna destra")
        let margine = NodeDict(id: "node_2", type: .MARGINAL_GLOSS, page_index: 0, text: "parola a margine")
        let (out, i) = innesta([colonna, margine])
        XCTAssertEqual(out.rawDocument.structure.map(\.type), [.BODY, .MARGINAL_GLOSS])
        XCTAssertEqual(out.rawDocument.structure.map(\.text), [colonna.text, margine.text], "il testo non cambia")
        XCTAssertEqual(i.conti.glosseInColonna, 1)
        XCTAssertEqual(i.conti.glosseLasciate, 1)
    }

    func test_glossaNellaColonnaLarga_inUnaRegioneDiNota_diventaNota() {
        var r = regioni
        r[0]![0].tipo = "footnote"
        r[0]![1].tipo = "footnote"
        let colonna = NodeDict(id: "node_1", type: .MARGINAL_GLOSS, page_index: 0, text: "prima riga della colonna destra seconda riga della colonna destra")
        let (out, i) = innesta([colonna], regioni: r)
        XCTAssertEqual(out.rawDocument.structure.map(\.type), [.NOTE])
        XCTAssertEqual(out.rawDocument.structure[0].text, colonna.text, "il testo non cambia")
        XCTAssertEqual(out.rawDocument.structure[0].length_category, .SHORT, "la lunghezza della nota come la calcola la catena")
        XCTAssertEqual(i.conti.glosseInNote, 1)
        XCTAssertEqual(i.conti.glosseInColonna, 0)
        // La riga più lunga in una regione di testo: meno di metà del testo ritrovato sta nelle note, e il nodo diventa corpo.
        r[0]![1].tipo = "text"
        let mista = NodeDict(id: "node_2", type: .MARGINAL_GLOSS, page_index: 0, text: "prima riga della colonna destra seconda riga della colonna destra")
        XCTAssertEqual(innesta([mista], regioni: r).0.rawDocument.structure.map(\.type), [.BODY])
    }

    func test_glossaDentroUnaTabellaAmmessa_diventaNonClassificata() {
        let tabella = NodeDict(id: "node_1", type: .MARGINAL_GLOSS, page_index: 0, text: "riga di una tabella con numeri")
        let (out, i) = innesta([tabella])
        XCTAssertEqual(out.rawDocument.structure.map(\.type), [.UNCLASSIFIED], "testo della tabella: letto al suo posto, non fuso col corpo")
        XCTAssertNil(out.rawDocument.structure[0].length_category)
        XCTAssertEqual(i.conti.glosseInTabella, 1)
        XCTAssertEqual(i.conti.glosseInColonna, 0)
        XCTAssertEqual(innesta([tabella], colonne: false).0.rawDocument.structure.map(\.type), [.MARGINAL_GLOSS], "regola delle colonne spenta: resta")
    }

    func test_rigaFuoriDallaRegione_nonConta() {
        var r = regioni
        r[0]![0].dentro = false   // la riga ha la regione solo perché la più vicina
        r[0]![1].dentro = false
        let colonna = NodeDict(id: "node_1", type: .MARGINAL_GLOSS, page_index: 0, text: "prima riga della colonna destra seconda riga della colonna destra")
        XCTAssertEqual(innesta([colonna], regioni: r).0.rawDocument.structure.map(\.type), [.MARGINAL_GLOSS])
    }

    func test_notaDentroUnaTabella_diventaNonClassificata_laNotaFuoriResta() {
        let tabella = NodeDict(id: "node_1", type: .NOTE, page_index: 0, text: "riga di una tabella con numeri", length_category: .MICRO)
        let nota = NodeDict(id: "node_2", type: .NOTE, page_index: 0, text: "una nota vera che non sta nella tabella", length_category: .SHORT)
        let (out, i) = innesta([tabella, nota])
        XCTAssertEqual(out.rawDocument.structure.map(\.type), [.UNCLASSIFIED, .NOTE])
        XCTAssertNil(out.rawDocument.structure[0].length_category)
        XCTAssertEqual(out.rawDocument.structure[1].length_category, .SHORT)
        XCTAssertEqual(i.conti.noteInTabella, 1)
    }

    func test_regoleSpente_nienteCambia_eSullePagineNonLette_niente() {
        let colonna = NodeDict(id: "node_1", type: .MARGINAL_GLOSS, page_index: 0, text: "prima riga della colonna destra seconda riga della colonna destra")
        let tabella = NodeDict(id: "node_2", type: .NOTE, page_index: 0, text: "riga di una tabella con numeri")
        XCTAssertEqual(innesta([colonna, tabella], colonne: false, righeDiTabella: false).0.rawDocument.structure.map(\.type), [.MARGINAL_GLOSS, .NOTE])
        let altraPagina = NodeDict(id: "node_3", type: .MARGINAL_GLOSS, page_index: 5, text: "prima riga della colonna destra")
        XCTAssertEqual(innesta([altraPagina]).0.rawDocument.structure.map(\.type), [.MARGINAL_GLOSS])
    }

    func test_dentroAiFigli_eIlSuccessivoRiceveIlDocumentoRietichettato() {
        let colonna = NodeDict(id: "node_2", type: .MARGINAL_GLOSS, page_index: 0, text: "prima riga della colonna destra seconda riga della colonna destra")
        let titolo = NodeDict(id: "node_1", type: .HEADING_2, page_index: 0, text: "Titolo di prova", level: 2, children: [colonna])
        let dopo = Dopo()
        let (out, _) = innesta([titolo], poi: dopo)
        XCTAssertEqual(dopo.ricevuto?.structure.first?.children.first?.type, .BODY)
        XCTAssertEqual(out.report, ["riga dell'innesto successivo"], "il referto è quello dell'innesto successivo: nessuna riga nuova verso l'iPad")
    }

    func test_testoRitrovatoTroppoPoco_nienteCambia() {
        // Solo una riga corta del nodo ritrovata fra le righe della pagina: meno di metà del testo.
        let lunga = NodeDict(id: "node_1", type: .MARGINAL_GLOSS, page_index: 0,
                             text: "prima riga della colonna destra e molto altro testo che non si ritrova fra le righe della pagina letta")
        XCTAssertEqual(innesta([lunga]).0.rawDocument.structure.map(\.type), [.MARGINAL_GLOSS])
    }

    func test_migliorie_nomiDelleRegole() {
        XCTAssertTrue(MiglioriScansioni().colonne && MiglioriScansioni().righeDiTabella)
        XCTAssertEqual(MiglioriScansioni(spente: "colonne,righetabella")?.spenteNomi, ["colonne", "righetabella"])
    }
}
