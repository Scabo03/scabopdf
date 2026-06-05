//
//  LineSummaryTests.swift
//  ScaboCoreTests
//
//  PART B — RECONSTRUCTED oracle, not an imported one.
//
//  The TypeScript `summarizeLine` (app/src/native/pdfExtraction.ts) is
//  load-bearing — the whole Generic classifies on its output — but had NO unit
//  test. These XCTests were written from reading the TS behaviour line by line
//  (the golden rule applied in reverse): they capture the char-weighted size,
//  the 60 % bold/italic thresholds, the first-seen dominant-colour tie-break,
//  the raw-concat-then-trim text, the bbox derivation, and the UTF-16 length
//  semantics. They are the safety net the TS never had; the Swift translation
//  is then made to pass them.
//

import XCTest
@testable import ScaboCore

final class LineSummaryTests: XCTestCase {

    private func span(
        _ text: String, size: Double = 12, bold: Bool = false, italic: Bool = false,
        color: String = "#000000", bbox: BBox = BBox(x: 0, y: 0, width: 0, height: 0)
    ) -> PdfSpan {
        PdfSpan(text: text, fontSize: size, bold: bold, italic: italic, color: color, bbox: bbox)
    }

    private func textLine(_ spans: [PdfSpan], bbox: BBox = BBox(x: 0, y: 0, width: 0, height: 0)) -> PdfTextLine {
        PdfTextLine(spans: spans, bbox: bbox)
    }

    /// Single span: every field maps straight through; bbox derives the geometry.
    func test_singleSpan_basics() {
        let sm = summarizeLine(textLine(
            [span("Hello", size: 12, color: "#123456")],
            bbox: BBox(x: 10, y: 20, width: 30, height: 5)
        ))
        XCTAssertEqual(sm.text, "Hello")
        XCTAssertEqual(sm.fontSize, 12, accuracy: 1e-9)
        XCTAssertFalse(sm.bold)
        XCTAssertFalse(sm.italic)
        XCTAssertEqual(sm.color, "#123456")
        XCTAssertEqual(sm.x0, 10, accuracy: 1e-9)
        XCTAssertEqual(sm.x1, 40, accuracy: 1e-9)   // x + w
        XCTAssertEqual(sm.yTop, 25, accuracy: 1e-9) // y + h
        XCTAssertEqual(sm.yBottom, 20, accuracy: 1e-9)
        XCTAssertEqual(sm.width, 30, accuracy: 1e-9)
        XCTAssertEqual(sm.height, 5, accuracy: 1e-9)
        XCTAssertEqual(sm.spans.count, 1)
    }

    /// fontSize is the char-weighted mean: ("aaaa"@10 + "bb"@20) → (40+40)/6.
    func test_fontSize_charWeightedMean() {
        let sm = summarizeLine(textLine([span("aaaa", size: 10), span("bb", size: 20)]))
        XCTAssertEqual(sm.fontSize, 80.0 / 6.0, accuracy: 1e-9)
    }

    /// A zero-size span contributes nothing to the weighted average.
    func test_fontSize_excludesZeroSizeSpans() {
        let sm = summarizeLine(textLine([span("aa", size: 12), span("bbbb", size: 0)]))
        XCTAssertEqual(sm.fontSize, 12, accuracy: 1e-9)
    }

    /// All spans size 0 → fontSize 0.
    func test_fontSize_allZero() {
        let sm = summarizeLine(textLine([span("aa", size: 0), span("bb", size: 0)]))
        XCTAssertEqual(sm.fontSize, 0, accuracy: 1e-9)
    }

    /// bold is true at exactly 60 % of characters, false below.
    func test_bold_sixtyPercentThreshold() {
        let atThreshold = summarizeLine(textLine([span("aaa", bold: true), span("bb", bold: false)]))
        XCTAssertTrue(atThreshold.bold) // 3/5 = 0.6
        let below = summarizeLine(textLine([span("aaa", bold: true), span("bbb", bold: false)]))
        XCTAssertFalse(below.bold) // 3/6 = 0.5
    }

    /// italic uses the same 60 % rule.
    func test_italic_sixtyPercentThreshold() {
        let on = summarizeLine(textLine([span("aaaa", italic: true), span("b", italic: false)]))
        XCTAssertTrue(on.italic) // 4/5 = 0.8
        let off = summarizeLine(textLine([span("ab", italic: true), span("cde", italic: false)]))
        XCTAssertFalse(off.italic) // 2/5 = 0.4
    }

    /// Dominant colour is the one covering most characters; ties → first seen.
    func test_color_dominantWithFirstSeenTie() {
        let tie = summarizeLine(textLine([span("aa", color: "#111111"), span("bb", color: "#222222")]))
        XCTAssertEqual(tie.color, "#111111") // 2 == 2, first seen wins
        let clear = summarizeLine(textLine([span("a", color: "#111111"), span("bbb", color: "#222222")]))
        XCTAssertEqual(clear.color, "#222222") // 3 > 1
    }

    /// text is the raw span concatenation, then trimmed.
    func test_text_concatThenTrim() {
        let sm = summarizeLine(textLine([span("  Hello "), span("World  ")]))
        XCTAssertEqual(sm.text, "Hello World")
    }

    /// Empty spans → empty text, zero size, false flags, default colour, bbox
    /// still derived from the line.
    func test_emptySpans() {
        let sm = summarizeLine(textLine([], bbox: BBox(x: 1, y: 2, width: 3, height: 4)))
        XCTAssertEqual(sm.text, "")
        XCTAssertEqual(sm.fontSize, 0, accuracy: 1e-9)
        XCTAssertFalse(sm.bold)
        XCTAssertFalse(sm.italic)
        XCTAssertEqual(sm.color, "#000000")
        XCTAssertEqual(sm.x0, 1, accuracy: 1e-9)
        XCTAssertEqual(sm.x1, 4, accuracy: 1e-9)
        XCTAssertEqual(sm.yTop, 6, accuracy: 1e-9)
        XCTAssertEqual(sm.yBottom, 2, accuracy: 1e-9)
    }

    /// UTF-16 length semantics: a precomposed "é" weighs as one unit, exactly as
    /// JavaScript's String.length counts it.
    func test_fontSize_utf16Weighting() {
        // "é" (U+00E9) is one UTF-16 unit; ("é"@10 + "xx"@20) → (10+40)/3.
        let sm = summarizeLine(textLine([span("\u{00E9}", size: 10), span("xx", size: 20)]))
        XCTAssertEqual(sm.fontSize, 50.0 / 3.0, accuracy: 1e-9)
    }
}
