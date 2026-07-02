//
//  UnderlineRenderingTests.swift
//  ScaboAppTests
//
//  Resa grafica delle sottolineature (§ 6.5) nella reading view: l'underline è un ATTRIBUTO del
//  testo (`.underlineStyle`) sull'intervallo di parole giusto, e — punto critico (rete A) — la
//  `accessibilityLabel` (il parlato) NON cambia con o senza sottolineatura. Verifica anche che la
//  resa sopravviva a un re-render e che rimuovere gli intervalli ripristini il testo puro.
//
//  Il Simulator non riproduce Dynamic Type reale sotto le dita: l'allineamento a corpo molto grande
//  è garantito PER COSTRUZIONE (l'underline è un attributo posato dal renderer sotto i glifi esatti,
//  non una riga disegnata a coordinate) e va comunque verificato all'occhio su device.
//

import UIKit
import XCTest

@testable import ScaboApp
import ScaboCore

final class UnderlineRenderingTests: XCTestCase {

    private func makeRenderedView() -> ContinuousReadingView {
        let view = ContinuousReadingView(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        view.render([
            ContentSegment(id: "n0", role: "BODY", text: "alfa beta gamma", lengthCategory: "", acousticIntro: ""),
            ContentSegment(id: "n1", role: "BODY", text: "uno due tre quattro", lengthCategory: "", acousticIntro: ""),
        ])
        view.layoutIfNeeded()
        return view
    }

    /// Vero se l'attributed string ha `.underlineStyle` sull'indice di carattere dato.
    private func hasUnderline(_ attributed: NSAttributedString?, atCharacter index: Int) -> Bool {
        guard let attributed, index < attributed.length else { return false }
        let value = attributed.attribute(.underlineStyle, at: index, effectiveRange: nil) as? Int
        return (value ?? 0) != 0
    }

    /// Vero se in NESSUN punto dell'attributed string c'è l'attributo di sottolineatura. Nota:
    /// `UILabel.attributedText` non è mai `nil` una volta impostato `text` (ne sintetizza uno dal
    /// testo), quindi la prova di "non sottolineato" è l'ASSENZA dell'attributo, non `nil`.
    private func hasNoUnderline(_ label: UILabel) -> Bool {
        guard let attributed = label.attributedText, attributed.length > 0 else { return true }
        for i in 0..<attributed.length where hasUnderline(attributed, atCharacter: i) { return false }
        return true
    }

    func test_setUnderlineRanges_underlinesTheRightWords_only() {
        let view = makeRenderedView()
        // "uno due tre quattro": parole 1..2 = "due tre".
        view.setUnderlineRanges(["n1": [1...2]])
        let label = view.segmentLabels[1]
        let attributed = label.attributedText
        XCTAssertNotNil(attributed, "il segmento sottolineato riceve un attributedText")
        // "uno " = 0..3, "due" inizia a 4, "tre" finisce a 10; "quattro" (11..) NON sottolineato.
        XCTAssertFalse(hasUnderline(attributed, atCharacter: 0), "«uno» non è sottolineato")
        XCTAssertTrue(hasUnderline(attributed, atCharacter: 4), "«due» è sottolineato")
        XCTAssertTrue(hasUnderline(attributed, atCharacter: 8), "«tre» è sottolineato")
        XCTAssertFalse(hasUnderline(attributed, atCharacter: 12), "«quattro» non è sottolineato")
    }

    func test_underline_doesNotChangeSpokenLabel_reteA() {
        let view = makeRenderedView()
        let before = view.segmentLabels[1].accessibilityLabel
        view.setUnderlineRanges(["n1": [1...2]])
        XCTAssertEqual(view.segmentLabels[1].accessibilityLabel, before,
                       "il parlato è invariato: l'underline è puramente visivo (rete A)")
        XCTAssertEqual(view.segmentLabels[1].accessibilityLabel, "uno due tre quattro",
                       "resta esattamente il testo del segmento")
    }

    func test_nonUnderlinedSegment_staysPlainText() {
        let view = makeRenderedView()
        view.setUnderlineRanges(["n1": [0...0]])
        XCTAssertTrue(hasNoUnderline(view.segmentLabels[0]), "n0 non è sottolineato")
        XCTAssertEqual(view.segmentLabels[0].text, "alfa beta gamma")
    }

    func test_removingRanges_revertsToPlainText() {
        let view = makeRenderedView()
        view.setUnderlineRanges(["n1": [1...2]])
        XCTAssertTrue(hasUnderline(view.segmentLabels[1].attributedText, atCharacter: 4))
        view.setUnderlineRanges([:])
        XCTAssertTrue(hasNoUnderline(view.segmentLabels[1]), "rimosso l'intervallo → niente sottolineatura")
        XCTAssertEqual(view.segmentLabels[1].text, "uno due tre quattro")
        XCTAssertEqual(view.segmentLabels[1].accessibilityLabel, "uno due tre quattro")
    }

    func test_underline_survivesReRender() {
        let view = makeRenderedView()
        view.setUnderlineRanges(["n1": [1...2]])
        // Re-render (es. cambio Layout) con gli stessi id: la resa deve riapplicarsi alle nuove label.
        view.render([
            ContentSegment(id: "n0", role: "BODY", text: "alfa beta gamma", lengthCategory: "", acousticIntro: ""),
            ContentSegment(id: "n1", role: "BODY", text: "uno due tre quattro", lengthCategory: "", acousticIntro: ""),
        ])
        view.layoutIfNeeded()
        XCTAssertTrue(hasUnderline(view.segmentLabels[1].attributedText, atCharacter: 4),
                      "dopo il re-render la sottolineatura è riapplicata alla nuova etichetta")
    }
}
