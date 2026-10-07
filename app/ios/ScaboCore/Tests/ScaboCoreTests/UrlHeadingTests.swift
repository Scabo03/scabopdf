import XCTest
@testable import ScaboCore

/// Un indirizzo web o di posta da solo su una riga non è mai un titolo, anche se grande o colorato; una riga di
/// nota che porta un indirizzo resta nota. Testi di prova.
final class UrlHeadingTests: XCTestCase {
    private func sm(_ text: String, size: Double, color: String = "#000000") -> LineSummary {
        LineSummary(text: text, fontSize: size, bold: false, italic: false, color: color,
                    x0: 60, x1: 300, yTop: 500, yBottom: 488, width: 240, height: 12, spans: [])
    }
    private let profile = Profile(bodySize: 10, bodyColor: "#000000")

    func test_loneUrlOrMail_atHeadingSize_isBody() {
        XCTAssertEqual(classify(sm("www.esempio-di-prova.it", size: 16), profile), .body)
        XCTAssertEqual(classify(sm("http://rivista.esempio.eu", size: 13, color: "#2E7D32"), profile), .body)
        XCTAssertEqual(classify(sm("redazione@esempio.it", size: 16), profile), .body)
    }

    func test_realTitle_andNoteWithUrl_unchanged() {
        XCTAssertEqual(classify(sm("Titolo di prova", size: 16), profile), .heading(level: 1))
        XCTAssertEqual(classify(sm("www.esempio-di-prova.it", size: 7), profile), .note, "un indirizzo in nota resta nota")
        XCTAssertEqual(classify(sm("Il sito www.esempio.it di prova", size: 16), profile), .heading(level: 1),
                       "solo la riga che è soltanto un indirizzo")
    }
}
