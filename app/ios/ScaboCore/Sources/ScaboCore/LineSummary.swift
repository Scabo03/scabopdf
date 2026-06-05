//
//  LineSummary.swift
//  ScaboCore
//
//  The extraction → classification adapter (`summarizeLine`) and its output
//  `LineSummary`. This sits on the CLASSIFIER side of the § 10 seam: it reduces a
//  `PdfTextLine` (the engine-agnostic extraction unit) to the single signal
//  vector the Generic plugin classifies on. No PDFKit; it consumes only the
//  `PdfExtraction` value types.
//
//  PART B of Fase 2 (Piano § 4 + this session's brief): `summarizeLine` is
//  load-bearing but had NO unit test in the TypeScript. The golden rule is
//  therefore applied IN REVERSE — the XCTest net in `LineSummaryTests.swift` was
//  written from the observed behaviour of the TS `summarizeLine`
//  (`app/src/native/pdfExtraction.ts`) BEFORE this translation, and is marked
//  there as a *reconstructed* oracle (not an imported one).
//
//  Faithful-to-JS detail that governs the whole translation: JavaScript's
//  `String.length` counts UTF-16 code units, not grapheme clusters. Every place
//  the TS measures a length (span weighting, bold/italic ratios, the line-length
//  caps in the Generic, the NOTE acoustic regime) is reproduced with
//  `String.utf16.count`, so an accented or astral character is counted exactly
//  as the TS counted it. `jsTrim` mirrors `String.prototype.trim` for the text
//  the pipeline sees (the only divergence is exotic format characters such as
//  U+FEFF, which JS trims and `.whitespacesAndNewlines` does not — not exercised
//  by any input here, documented rather than silenced).
//

import Foundation

/// A line reduced to a single signal vector. Mirrors the TypeScript
/// `LineSummary`: `text`/`fontSize`/`bold` reproduce the char-weighted line
/// aggregate exactly; `italic`/`color`/geometry are the multi-signal additions.
public struct LineSummary: Equatable, Sendable {
    public var text: String
    /// Character-weighted dominant font size (spans with size 0 are excluded
    /// from the weighted average, exactly as the TS does).
    public var fontSize: Double
    /// True when ≥ 60 % of characters are bold (legacy threshold).
    public var bold: Bool
    /// True when ≥ 60 % of characters are italic.
    public var italic: Bool
    /// Dominant fill colour (by character count; ties → first-seen colour).
    public var color: String
    /// Left / right edge of the line bbox (page-local).
    public var x0: Double
    public var x1: Double
    /// Top / bottom y of the line bbox (origin bottom-left, so yTop ≥ yBottom).
    public var yTop: Double
    public var yBottom: Double
    public var width: Double
    public var height: Double
    public var spans: [PdfSpan]

    public init(
        text: String, fontSize: Double, bold: Bool, italic: Bool, color: String,
        x0: Double, x1: Double, yTop: Double, yBottom: Double,
        width: Double, height: Double, spans: [PdfSpan]
    ) {
        self.text = text
        self.fontSize = fontSize
        self.bold = bold
        self.italic = italic
        self.color = color
        self.x0 = x0
        self.x1 = x1
        self.yTop = yTop
        self.yBottom = yBottom
        self.width = width
        self.height = height
        self.spans = spans
    }
}

/// Reduces a line to its signal vector. Faithful translation of `summarizeLine`
/// in `app/src/native/pdfExtraction.ts`:
///
///  * `fontSize` is the char-weighted mean over spans whose size is > 0 (a
///    zero-size span contributes nothing to the average but still counts toward
///    the bold/italic/colour totals);
///  * `bold`/`italic` are true when ≥ 60 % of ALL characters carry the flag;
///  * `color` is the colour covering the most characters, ties resolved to the
///    first colour seen (the TS relies on `Map`/object insertion order, which
///    `colorOrder` reproduces here);
///  * `text` is the raw span concatenation, then trimmed;
///  * the bbox `[x, y, w, h]` derives x0/x1/yTop/yBottom/width/height.
public func summarizeLine(_ line: PdfTextLine) -> LineSummary {
    var weightedSize = 0.0
    var sizeWeight = 0
    var boldChars = 0
    var italicChars = 0
    var total = 0
    var text = ""
    var colorCounts: [String: Int] = [:]
    var colorOrder: [String] = []

    for span in line.spans {
        text += span.text
        let n = span.text.utf16.count
        if span.fontSize > 0 {
            weightedSize += span.fontSize * Double(n)
            sizeWeight += n
        }
        if span.bold { boldChars += n }
        if span.italic { italicChars += n }
        total += n
        if colorCounts[span.color] == nil { colorOrder.append(span.color) }
        colorCounts[span.color, default: 0] += n
    }

    var color = "#000000"
    var bestChars = -1
    for c in colorOrder {
        let n = colorCounts[c]!
        if n > bestChars {
            bestChars = n
            color = c
        }
    }

    let bbox = line.bbox
    return LineSummary(
        text: jsTrim(text),
        fontSize: sizeWeight > 0 ? weightedSize / Double(sizeWeight) : 0,
        bold: total > 0 && Double(boldChars) / Double(total) >= 0.6,
        italic: total > 0 && Double(italicChars) / Double(total) >= 0.6,
        color: color,
        x0: bbox.x,
        x1: bbox.x + bbox.width,
        yTop: bbox.y + bbox.height,
        yBottom: bbox.y,
        width: bbox.width,
        height: bbox.height,
        spans: line.spans
    )
}

// MARK: - JS-string helpers (shared across the classifier)

/// Mirrors `String.prototype.trim` for the inputs the pipeline sees. Divergence
/// limited to exotic format characters (e.g. U+FEFF), not exercised here.
func jsTrim(_ s: String) -> String {
    s.trimmingCharacters(in: .whitespacesAndNewlines)
}
