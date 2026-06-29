//
//  DeJurePluginTests.swift
//  ScaboCoreTests
//
//  Verifica la prima foglia del ramo DeJure: la porta a tre segnali (Aspose + Letter + piè
//  "Pagina N di M") e la soppressione della furniture editoriale (timbro colophon + banner
//  "DOTTRINA") via ri-etichettatura a `ARTIFACT_STAMP` (ruolo non letto). Logica pura, in memoria.
//

import XCTest
@testable import ScaboCore

final class DeJurePluginTests: XCTestCase {

    // MARK: - Helpers

    private func line(_ text: String, size: Double = 12.0) -> PdfTextLine {
        PdfTextLine(
            spans: [PdfSpan(text: text, fontSize: size, bold: false, italic: false,
                            color: "#000000", bbox: BBox(x: 70, y: 700, width: 400, height: 14))],
            bbox: BBox(x: 70, y: 700, width: 400, height: 14))
    }

    /// Estrazione sintetica DeJure: Aspose + Letter + piè "Pagina N di M" + furniture + corpo.
    private func dejureExtraction(
        producer: String = "Aspose.PDF for .NET 18.4",
        creator: String = "Aspose Ltd.",
        width: Double = 612.0, height: Double = 792.0,
        footer: Bool = true
    ) -> PdfExtraction {
        var lines = [
            line("DOTTRINA"),
            line("Il problema delle concause dell'evento dannoso nella costruzione del modello."),
            line("SERVIZIO GESTIONE RISORSE DOCUMENTARIE © Copyright Giuffrè Francis Lefebvre S.p.A. 2024"),
        ]
        if footer { lines.append(line("Pagina 1 di 59")) }
        let page = PdfPageExtraction(pageIndex: 0, width: width, height: height, lines: lines)
        return PdfExtraction(version: 2, pageCount: 1, pages: [page],
                             producer: producer, creator: creator)
    }

    // MARK: - Furniture predicate

    func test_furniturePredicate_matchesStampAndBanner_notContent() {
        XCTAssertTrue(isDejureFurnitureText("DOTTRINA"))
        XCTAssertTrue(isDejureFurnitureText("  DOTTRINA  "))
        XCTAssertTrue(isDejureFurnitureText(
            "SERVIZIO GESTIONE RISORSE DOCUMENTARIE © Copyright Giuffrè Francis Lefebvre S.p.A. 2025 09/09/2025"))
        // Contenuto reale: mai furniture.
        XCTAssertFalse(isDejureFurnitureText("La dottrina prevalente esclude la responsabilità."))
        XCTAssertFalse(isDejureFurnitureText("DOTTRINA E GIURISPRUDENZA"))  // non esatto
        XCTAssertFalse(isDejureFurnitureText("Quando un ordinamento giuridico si dà delle regole."))
    }

    // MARK: - matches(): gate congiunto a tre segnali

    func test_matches_positive_onDejureSignature() {
        XCTAssertGreaterThanOrEqual(dejurePlugin.matches(dejureExtraction()), DISPATCH_THRESHOLD)
    }

    func test_matches_zero_withoutAspose() {
        let e = dejureExtraction(producer: "Adobe PDF Library 15.0", creator: "Adobe InDesign CC")
        XCTAssertEqual(dejurePlugin.matches(e), 0.0, "senza Aspose la porta è chiusa")
    }

    func test_matches_zero_withoutLetterGeometry() {
        let e = dejureExtraction(width: 595.3, height: 841.9)   // A4, non Letter
        XCTAssertEqual(dejurePlugin.matches(e), 0.0, "senza geometria Letter la porta è chiusa")
    }

    func test_matches_zero_withoutFooter() {
        let e = dejureExtraction(footer: false)
        XCTAssertEqual(dejurePlugin.matches(e), 0.0, "senza piè 'Pagina N di M' la porta è chiusa")
    }

    // MARK: - Dispatch: vince sul ramo, perde altrove

    func test_dispatch_dejureWinsOnDejure() {
        XCTAssertTrue(selectPlugin(dejureExtraction()) === dejurePlugin)
    }

    func test_dispatch_dejureLosesOnNonDejure() {
        // Estrazione tipo-Estratto (Acrobat, geometria diversa): NON deve scegliere DeJure.
        let page = PdfPageExtraction(pageIndex: 0, width: 482.6, height: 684.2,
                                     lines: [line("CAPITOLO IV", size: 13)])
        let e = PdfExtraction(version: 2, pageCount: 1, pages: [page],
                              producer: "Adobe Acrobat Pro 9.0.0", creator: "Adobe Acrobat Pro 9.0.0")
        XCTAssertFalse(selectPlugin(e) === dejurePlugin, "un non-DeJure non entra mai nel ramo DeJure")
    }

    // MARK: - Retag della furniture (effetto della foglia)

    func test_retag_furnitureBecomesArtifactStamp_contentUntouched() {
        var nodes = [
            NodeDict(id: "node_0", type: .NOTE, page_index: 0, text: "DOTTRINA"),
            NodeDict(id: "node_1", type: .BODY, page_index: 0, text: "Il problema delle concause."),
            NodeDict(id: "node_2", type: .BODY, page_index: 0,
                     text: "SERVIZIO GESTIONE RISORSE DOCUMENTARIE © Copyright Giuffrè Francis Lefebvre S.p.A. 2024"),
        ]
        let n = retagDejureFurniture(&nodes)
        XCTAssertEqual(n, 2, "timbro + banner ri-etichettati")
        XCTAssertEqual(nodes[0].type, .ARTIFACT_STAMP, "il banner DOTTRINA diventa furniture non letta")
        XCTAssertEqual(nodes[1].type, .BODY, "il contenuto resta BODY")
        XCTAssertEqual(nodes[2].type, .ARTIFACT_STAMP, "il timbro diventa furniture non letta")
    }

    func test_retag_recursesIntoChildren() {
        var nodes = [
            NodeDict(id: "node_0", type: .HEADING_1, page_index: 0, text: "Titolo", children: [
                NodeDict(id: "node_1", type: .NOTE, page_index: 0, text: "DOTTRINA"),
            ]),
        ]
        let n = retagDejureFurniture(&nodes)
        XCTAssertEqual(n, 1)
        XCTAssertEqual(nodes[0].children[0].type, .ARTIFACT_STAMP)
    }

    // MARK: - Build: profilo invariato (cerotto anti-'Nota.' del tronco intatto) + diagnostica

    func test_build_keepsGenericProfile_andAnnotatesBranch() {
        // Documento con furniture esplicita come nodi standalone (effetto retag verificato a parte).
        let doc = dejurePlugin.build(dejureExtraction(), sourceName: "DeJure DT - test.pdf")
        // Profilo "generic" di proposito: riusa l'euristica size-only del tronco e il suo cerotto
        // anti-'Nota.' (gated su "generic"), così i NOTE legittimi del ramo non riacquistano "Nota.".
        XCTAssertEqual(doc.profile.profile_id, "generic")
        XCTAssertTrue(doc.warnings.contains("plugin:dejure:branch_active"))
    }
}
