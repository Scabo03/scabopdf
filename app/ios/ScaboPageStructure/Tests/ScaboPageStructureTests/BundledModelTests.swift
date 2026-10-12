//
//  BundledModelTests.swift
//  ScaboPageStructureTests
//
//  Il modello incorporato si carica e, su una pagina sintetica, l'uscita è priva di testo e coerente
//  (riquadri dentro la pagina, ordini 0…n-1). Licenze e attribuzioni viaggiano nel pacchetto accanto al modello.
//

import XCTest
import PDFKit
@testable import ScaboPageStructure

final class BundledModelTests: XCTestCase {

    func test_licenzeEAttribuzioniNelPacchetto() throws {
        for (name, ext) in [("LICENSE-Apache-2.0", "txt"), ("LICENSE-docling-MIT", "txt"), ("NOTICE-HeronLayout", "md")] {
            let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: ext), "\(name).\(ext) assente")
            let text = try String(contentsOf: url, encoding: .utf8)
            XCTAssertFalse(text.isEmpty)
        }
        let notice = try String(contentsOf: Bundle.module.url(forResource: "NOTICE-HeronLayout", withExtension: "md")!, encoding: .utf8)
        XCTAssertTrue(notice.contains("docling-layout-heron") && notice.contains("Apache") && notice.contains("Modifiche apportate"))
    }

    func test_modelloIncorporato_uscitaPrivaDiTestoECoerente() throws {
        guard #available(iOS 17.0, macOS 14.0, *) else { throw XCTSkip("serve iOS 17 / macOS 14") }
        guard HeronLayoutModel.bundledModelURL != nil else { throw XCTSkip("pesi del modello assenti (clone senza Git LFS)") }
        let model = try HeronLayoutModel.bundled()
        let words = ["Xylofonia", "Quarzomelo", "Brindabella"]
        let url = SyntheticPDF.make { ctx in
            SyntheticPDF.text(ctx, "Titolo di prova \(words[0])", x: 72, y: 780, size: 18)
            for k in 0..<12 { SyntheticPDF.text(ctx, "riga di prova numero \(k) \(words[1]) e altre parole qualsiasi del capoverso", x: 72, y: 740 - CGFloat(k) * 14) }
            ctx.setLineWidth(0.5)
            for k in 0..<5 { ctx.move(to: CGPoint(x: 72, y: 500 - CGFloat(k) * 20)); ctx.addLine(to: CGPoint(x: 472, y: 500 - CGFloat(k) * 20)) }
            ctx.strokePath()
            SyntheticPDF.text(ctx, "cella \(words[2]) 12,00", x: 80, y: 485)
            ctx.draw(SyntheticPDF.image(80, 60), in: CGRect(x: 150, y: 120, width: 300, height: 220))
        }
        let page = try XCTUnwrap(PDFDocument(url: url)?.page(at: 0))
        let (layout, timings) = try PageStructureAnalyzer(model: model).analyze(page: page, pageIndex: 0)
        XCTAssertFalse(layout.regions.isEmpty)
        XCTAssertEqual(layout.regions.map { $0.order }, Array(0..<layout.regions.count))
        for r in layout.regions {
            XCTAssertEqual(r.bbox.count, 4)
            XCTAssertGreaterThanOrEqual(r.bbox[0], -1); XCTAssertLessThanOrEqual(r.bbox[2], 596)
            XCTAssertGreaterThanOrEqual(r.bbox[1], -1); XCTAssertLessThanOrEqual(r.bbox[3], 843)
            XCTAssertTrue(HERON_LABELS.contains(r.label))
        }
        let json = String(decoding: try JSONEncoder().encode(layout), as: UTF8.self)
        for w in words { XCTAssertFalse(json.contains(w), "l'uscita non deve portare testo") }
        XCTAssertGreaterThan(timings.infer, 0)
    }
}
