// Structured PDF text extraction using Apple PDFKit.
//
// Walks every page of a PDF and produces, per page, a list of laid-out lines,
// each a sequence of SPANS (maximal runs of uniform typographic attributes).
// Every span carries text + font size + bold + italic + resolved colour + a
// page-local bounding box. This per-span richness matches what Layer 1 gets
// from pdfplumber/PyMuPDF on the Python side and is the structural prerequisite
// for a multi-signal Generic plugin (and future corpus plugins) on-device:
// size-only was physically unable to see colour-coded headings (e.g. BIC),
// running-furniture geometry, or inline emphasis/superscript markers.
//
// Coordinate convention: page-local, origin bottom-left, y increasing upward
// (PDF user space relative to the cropBox). Each page reports its width/height
// so the consumer can normalise (e.g. "top 8% of the page" = y > 0.92*height).
//
// The result is serialised to a JSON string (shape documented below) consumed
// by the NativePdfExtractor TurboModule and parsed on the JS side.
//
// Pure compute: no UIKit main-thread requirement, safe to call off the main
// thread (the ObjC++ shim dispatches it to a background queue).

import Foundation
import PDFKit
import UIKit

@objc(ScaboPdfExtractor)
public final class ScaboPdfExtractor: NSObject {

  /// Extracts the PDF at `uri` (a local file:// URI from the document picker)
  /// to a JSON string of the shape
  /// `{ "version": 2, "pageCount": Int, "pages": [{ "pageIndex": Int,
  ///    "width": Double, "height": Double, "lines": [{ "bbox": [x,y,w,h],
  ///    "spans": [{ "text": String, "fontSize": Double, "bold": Bool,
  ///    "italic": Bool, "color": "#rrggbb", "bbox": [x,y,w,h] }] }] }] }`.
  ///
  /// Throws an `NSError` carrying a readable Italian message when the file path
  /// is invalid, the PDF cannot be opened, it is password-protected, or the
  /// extracted text cannot be serialised.
  @objc public static func extract(fromUri uri: String) throws -> String {
    let start = Date()
    do {
      let (json, pageCount, lineCount, spanCount, colours) = try buildJSON(fromUri: uri)
      let elapsedMs = Int(Date().timeIntervalSince(start) * 1000)
      // Content-free metrics: counts + duration + an AGGREGATE colour count
      // (never specific colour values). No text.
      ScaboLog.event(.pdfExtraction, "extract_complete", [
        "pages": pageCount,
        "lines": lineCount,
        "spans": spanCount,
        "colors": colours,
        "bytes": json.utf8.count,
        "ms": elapsedMs,
      ])
      ScaboLog.snapshot(categoryName: ScaboLogCategory.pdfExtraction.rawName,
                        name: "extraction_raw",
                        json: json)
      return json
    } catch let error as NSError {
      ScaboLog.error("extract_failed", [
        "domain": error.domain,
        "code": error.code,
      ])
      throw error
    }
  }

  // MARK: - Model

  private struct Span {
    var text: String
    var fontSize: Double
    var bold: Bool
    var italic: Bool
    var color: String
    var bbox: [Double]
  }

  private struct Line {
    var spans: [Span]
    var bbox: [Double]
  }

  // MARK: - JSON building

  /// Builds the extraction JSON and returns it with content-free counts.
  private static func buildJSON(fromUri uri: String) throws
    -> (json: String, pageCount: Int, lineCount: Int, spanCount: Int, colours: Int) {
    guard let url = fileURL(from: uri) else {
      throw makeError("Percorso del file PDF non valido.")
    }
    guard let document = PDFDocument(url: url) else {
      throw makeError("Impossibile aprire il PDF. Potrebbe essere danneggiato.")
    }
    if document.isLocked {
      throw makeError("Il PDF è protetto da password e non può essere letto.")
    }

    var pages: [[String: Any]] = []
    var lineCount = 0
    var spanCount = 0
    var colourSet = Set<String>()
    let pageCount = document.pageCount
    for index in 0..<pageCount {
      guard let page = document.page(at: index) else { continue }
      let cropBox = page.bounds(for: .cropBox)
      let pageLines = lines(for: page, cropBox: cropBox)
      lineCount += pageLines.count
      let lineDicts: [[String: Any]] = pageLines.map { line in
        spanCount += line.spans.count
        let spanDicts: [[String: Any]] = line.spans.map { span in
          colourSet.insert(span.color)
          return [
            "text": span.text,
            "fontSize": span.fontSize,
            "bold": span.bold,
            "italic": span.italic,
            "color": span.color,
            "bbox": span.bbox,
          ]
        }
        return ["bbox": line.bbox, "spans": spanDicts]
      }
      pages.append([
        "pageIndex": index,
        "width": Double(cropBox.width),
        "height": Double(cropBox.height),
        "lines": lineDicts,
      ])
    }

    let payload: [String: Any] = [
      "version": 2,
      "pageCount": pageCount,
      "pages": pages,
    ]
    let data = try JSONSerialization.data(withJSONObject: payload, options: [])
    guard let json = String(data: data, encoding: .utf8) else {
      throw makeError("Errore nella serializzazione del testo estratto.")
    }
    return (json, pageCount, lineCount, spanCount, colourSet.count)
  }

  // MARK: - Line / span extraction

  /// Walks a page's attributed string, grouping uniform-attribute runs into
  /// spans and breaking spans into lines at laid-out "\n" boundaries. Falls back
  /// to the plain page string (one span, no font/colour/bbox) for scanned /
  /// image-only PDFs.
  private static func lines(for page: PDFPage, cropBox: CGRect) -> [Line] {
    guard let attributed = page.attributedString, attributed.length > 0 else {
      return plainLines(for: page)
    }

    let full = attributed.string as NSString
    var result: [Line] = []
    var currentSpans: [Span] = []

    func flush() {
      let kept = currentSpans.filter {
        !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      }
      if !kept.isEmpty {
        result.append(Line(spans: kept, bbox: unionBBox(kept.map { $0.bbox })))
      }
      currentSpans = []
    }

    attributed.enumerateAttributes(
      in: NSRange(location: 0, length: full.length),
      options: []
    ) { attrs, range, _ in
      var size = 0.0
      var bold = false
      var italic = false
      if let font = attrs[.font] as? UIFont {
        size = Double(font.pointSize)
        let traits = font.fontDescriptor.symbolicTraits
        bold = traits.contains(.traitBold)
        italic = traits.contains(.traitItalic)
      }
      let colour = hexString(from: attrs[.foregroundColor] as? UIColor)

      // A run can span several laid-out lines: PDFKit separates them with "\n".
      let runText = full.substring(with: range)
      let segments = runText.components(separatedBy: "\n")
      var offset = 0
      for (i, segment) in segments.enumerated() {
        if i > 0 {
          flush()
          offset += 1 // the "\n" itself
        }
        let segLen = (segment as NSString).length
        if segLen > 0 {
          let spanRange = NSRange(location: range.location + offset, length: segLen)
          let bbox = spanBBox(page: page, range: spanRange, cropBox: cropBox)
          currentSpans.append(Span(text: segment, fontSize: size, bold: bold,
                                   italic: italic, color: colour, bbox: bbox))
        }
        offset += segLen
      }
    }
    flush()
    return result
  }

  /// Image / scanned fallback: page text as lines of one bare span (no font,
  /// colour or geometry) so the reader still degrades gracefully.
  private static func plainLines(for page: PDFPage) -> [Line] {
    guard let string = page.string else { return [] }
    return string.components(separatedBy: "\n").compactMap { raw in
      let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
      if trimmed.isEmpty { return nil }
      let span = Span(text: trimmed, fontSize: 0, bold: false, italic: false,
                      color: "#000000", bbox: [0, 0, 0, 0])
      return Line(spans: [span], bbox: [0, 0, 0, 0])
    }
  }

  // MARK: - Geometry / colour helpers

  /// Page-local bbox of a character range via a PDFKit selection. Returns
  /// `[x, y, w, h]` (origin bottom-left, cropBox-relative), or zeros when the
  /// range has no resolvable geometry.
  private static func spanBBox(page: PDFPage, range: NSRange, cropBox: CGRect) -> [Double] {
    guard range.length > 0, let selection = page.selection(for: range) else {
      return [0, 0, 0, 0]
    }
    let rect = selection.bounds(for: page)
    if rect.isNull || rect.isInfinite || rect.isEmpty {
      return [0, 0, 0, 0]
    }
    return [
      round2(Double(rect.minX - cropBox.minX)),
      round2(Double(rect.minY - cropBox.minY)),
      round2(Double(rect.width)),
      round2(Double(rect.height)),
    ]
  }

  /// Union of bboxes (already page-local), as `[x, y, w, h]`.
  private static func unionBBox(_ boxes: [[Double]]) -> [Double] {
    let valid = boxes.filter { $0.count == 4 && ($0[2] > 0 || $0[3] > 0) }
    guard let first = valid.first else { return [0, 0, 0, 0] }
    var minX = first[0], minY = first[1]
    var maxX = first[0] + first[2], maxY = first[1] + first[3]
    for b in valid.dropFirst() {
      minX = min(minX, b[0]); minY = min(minY, b[1])
      maxX = max(maxX, b[0] + b[2]); maxY = max(maxY, b[1] + b[3])
    }
    return [round2(minX), round2(minY), round2(maxX - minX), round2(maxY - minY)]
  }

  /// Resolves a colour to "#rrggbb". Absent colour (PDF default) → black.
  private static func hexString(from color: UIColor?) -> String {
    guard let color = color else { return "#000000" }
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    if color.getRed(&r, green: &g, blue: &b, alpha: &a) {
      return hex(r, g, b)
    }
    var w: CGFloat = 0
    if color.getWhite(&w, alpha: &a) {
      return hex(w, w, w)
    }
    return "#000000"
  }

  private static func hex(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> String {
    func c(_ v: CGFloat) -> Int { max(0, min(255, Int((v * 255).rounded()))) }
    return String(format: "#%02X%02X%02X", c(r), c(g), c(b))
  }

  private static func round2(_ v: Double) -> Double {
    (v * 100).rounded() / 100
  }

  // MARK: - Misc helpers

  private static func fileURL(from uri: String) -> URL? {
    if let url = URL(string: uri), url.isFileURL {
      return url
    }
    return URL(fileURLWithPath: uri)
  }

  private static func makeError(_ message: String) -> NSError {
    NSError(
      domain: "ScaboPdfExtractor",
      code: 1,
      userInfo: [NSLocalizedDescriptionKey: message]
    )
  }
}
