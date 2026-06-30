//
//  QuickConsultTreeTests.swift
//  ScaboCoreTests
//
//  Modello dell'albero di Consultazione Rapida (Layout 2): 5 livelli annidati,
//  intervalli-pagina, etichette di summary (§ 8.3). Test puri (nessuna UIKit).
//

import XCTest
@testable import ScaboCore

final class QuickConsultTreeTests: XCTestCase {

    private func n(_ id: String, _ type: SemanticCategory, _ text: String, page: Int, level: Int? = nil) -> NodeDict {
        NodeDict(id: id, type: type, page_index: page, text: text, level: level)
    }
    private func docOf(_ nodes: [NodeDict]) -> ScabopdfDocument {
        ScabopdfDocument(
            schema_version: "0.7.0",
            document_id: "doc_test",
            metadata: DocumentMetadata(pages_pdf: 1, page_size_pt: [357, 547], source_pdf_filename: "c.pdf"),
            profile: DocumentProfileDict(profile_id: "codici", editorial_family: "codici", genre: "codice", confidence: 0.85),
            structure: nodes)
    }

    func test_fiveLevelNesting_distinctDepths() {
        let d = docOf([
            n("node_1", .HEADING_1, "LIBRO IV - DELLE OBBLIGAZIONI", page: 240, level: 1),
            n("node_2", .HEADING_2, "TITOLO II - Dei contratti in generale", page: 241, level: 2),
            n("node_3", .HEADING_3, "CAPO I - Disposizioni preliminari", page: 241, level: 3),
            n("node_4", .HEADING_4, "SEZIONE I - Dell’accordo", page: 242, level: 4),
            n("node_5", .ARTICLE_HEADER, "1321. Nozione", page: 242),
            n("node_6", .BODY, "Il contratto è l’accordo…", page: 242),
        ])
        let tree = buildQuickConsultTree(d)
        XCTAssertEqual(tree.count, 1)
        let libro = tree[0]
        XCTAssertEqual(libro.depth, 1); XCTAssertEqual(libro.role, "HEADING_1")
        let titolo = libro.children[0]; XCTAssertEqual(titolo.depth, 2)
        let capo = titolo.children[0]; XCTAssertEqual(capo.depth, 3)
        let sez = capo.children[0]; XCTAssertEqual(sez.depth, 4)
        let art = sez.children[0]
        XCTAssertEqual(art.depth, 5); XCTAssertEqual(art.role, "ARTICLE_HEADER")
        XCTAssertEqual(art.contentIds, ["node_6"], "il corpo è contenuto-foglia dell'articolo")
    }

    func test_optionalIntermediateLevel_articleDirectlyUnderCapo() {
        // un articolo senza SEZIONE intermedia: resta figlio diretto del CAPO (annidamento robusto)
        let d = docOf([
            n("node_1", .HEADING_3, "CAPO III - Dell’inadempimento", page: 287, level: 3),
            n("node_2", .ARTICLE_HEADER, "1218. Responsabilità del debitore", page: 287),
            n("node_3", .ARTICLE_HEADER, "1219. Costituzione in mora", page: 288),
        ])
        let tree = buildQuickConsultTree(d)
        XCTAssertEqual(tree[0].children.count, 2, "due articoli diretti sotto il CAPO")
        XCTAssertEqual(tree[0].children[0].depth, 2, "profondità compattata (CAPO=1, articoli=2)")
    }

    func test_pageRange_spansDescendants() {
        let d = docOf([
            n("node_1", .HEADING_1, "LIBRO IV", page: 240, level: 1),
            n("node_2", .ARTICLE_HEADER, "1173", page: 245),
            n("node_3", .BODY, "…", page: 560),
        ])
        let libro = buildQuickConsultTree(d)[0]
        XCTAssertEqual(libro.firstPage, 240)
        XCTAssertEqual(libro.lastPage, 560, "l'intervallo copre tutti i discendenti")
    }

    func test_summaryLabel_childRangeAndPages() {
        let d = docOf([
            n("node_1", .HEADING_3, "CAPO III - dell’inadempimento", page: 286, level: 3),
            n("node_2", .ARTICLE_HEADER, "1218. Responsabilità", page: 286),
            n("node_3", .ARTICLE_HEADER, "1229. Clausole", page: 294),
        ])
        let capo = buildQuickConsultTree(d)[0]
        let label = quickConsultSummaryLabel(capo)
        XCTAssertEqual(label, "CAPO III - dell’inadempimento, articoli da 1218 a 1229, pagine da 287 a 295",
                       "§ 8.3: titolo + range-articoli + intervallo-pagine (file, 1-based)")
    }

    func test_summaryLabel_leafHasNoChildRange() {
        let d = docOf([
            n("node_1", .ARTICLE_HEADER, "2043. Risarcimento", page: 510),
            n("node_2", .BODY, "Qualunque fatto…", page: 510),
        ])
        let art = buildQuickConsultTree(d)[0]
        XCTAssertEqual(quickConsultSummaryLabel(art), "2043. Risarcimento, pagina 511",
                       "foglia: nessun range-figli, pagina singola")
    }

    func test_ordinal_romanAndArabic() {
        XCTAssertEqual(quickConsultOrdinal("TITOLO IX - Dei fatti illeciti"), "IX")
        XCTAssertEqual(quickConsultOrdinal("1218. Responsabilità"), "1218")
        XCTAssertEqual(quickConsultOrdinal("624-bis. Furto"), "624-bis")
    }

    func test_frontMatterBeforeFirstHeading_notInTree() {
        let d = docOf([
            n("node_1", .BODY, "frontespizio", page: 0),
            n("node_2", .HEADING_1, "LIBRO I", page: 5, level: 1),
        ])
        let tree = buildQuickConsultTree(d)
        XCTAssertEqual(tree.count, 1, "il front-matter prima della prima intestazione non entra")
        XCTAssertEqual(tree[0].title, "LIBRO I")
    }
}
