import XCTest
@testable import ScaboCore

/// Guardia della riga del folio (giro «ancore», Parte 5): una riga di banda che porta lettere d'elenco
/// a taglia di corpo fuse da PDFKit con la testatina non si toglie. Testi sintetici.
final class BodyListMarkerGuardTests: XCTestCase {
    private func span(_ t: String, _ size: Double) -> PdfSpan {
        PdfSpan(text: t, fontSize: size, bold: false, italic: false, color: "#000000", bbox: BBox(x: 0, y: 0, width: 10, height: 10))
    }
    private func line(_ spans: [PdfSpan]) -> PdfTextLine { PdfTextLine(spans: spans, bbox: BBox(x: 0, y: 0, width: 100, height: 10)) }

    func test_fusedHeaderWithBodyListLetters_isDetected() {
        XCTAssertTrue(carriesBodyListMarkers(line([span("a) ", 11.3), span("b) c) ", 11.5), span("Titolo corrente", 9.5)]), bodySize: 11.5))
        XCTAssertTrue(carriesBodyListMarkers(line([span("i) ii) iii) ", 11.5), span("Titolo", 9.5)]), bodySize: 11.5))
    }

    func test_ordinaryHeaders_areNotDetected() {
        // Testatina normale (taglia minore), folio, «Pag. N» più grande: nessun marcatore a taglia di corpo.
        XCTAssertFalse(carriesBodyListMarkers(line([span("12 Titolo corrente", 9.5)]), bodySize: 11.5))
        XCTAssertFalse(carriesBodyListMarkers(line([span("Pag. 12", 16.1), span("12", 12)]), bodySize: 12))
        // Uno span a taglia di corpo con testo vero non è un marcatore d'elenco.
        XCTAssertFalse(carriesBodyListMarkers(line([span("§ 10 PRESUPPOSTI", 11.0)]), bodySize: 11.0))
        XCTAssertFalse(carriesBodyListMarkers(line([span("a) ", 11.5)]), bodySize: 0))
    }
}
