// Structured PDF text extraction using Apple PDFKit.
//
// Walks every page of a PDF and produces, per page, a list of laid-out lines
// each carrying its text plus a font signal (character-weighted dominant point
// size and a bold flag). The result is serialised to a JSON string consumed by
// the NativePdfExtractor TurboModule and parsed on the JS side, where the
// "Generic" plugin turns it into the ContentSegment reading model.
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
  /// `{ "pageCount": Int, "pages": [{ "pageIndex": Int,
  ///    "lines": [{ "text": String, "fontSize": Double, "bold": Bool }] }] }`.
  ///
  /// Throws an `NSError` carrying a readable Italian message when the file path
  /// is invalid, the PDF cannot be opened, it is password-protected, or the
  /// extracted text cannot be serialised.
  @objc public static func extract(fromUri uri: String) throws -> String {
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
    let pageCount = document.pageCount
    for index in 0..<pageCount {
      guard let page = document.page(at: index) else { continue }
      let pageLines = lines(for: page)
      let lineDicts: [[String: Any]] = pageLines.map { line in
        [
          "text": line.text,
          "fontSize": line.fontSize,
          "bold": line.bold,
        ]
      }
      pages.append([
        "pageIndex": index,
        "lines": lineDicts,
      ])
    }

    let payload: [String: Any] = [
      "pageCount": pageCount,
      "pages": pages,
    ]
    let data = try JSONSerialization.data(withJSONObject: payload, options: [])
    guard let json = String(data: data, encoding: .utf8) else {
      throw makeError("Errore nella serializzazione del testo estratto.")
    }
    return json
  }

  // MARK: - Line extraction

  private struct Line {
    var text: String
    var fontSize: Double
    var bold: Bool
  }

  /// Walks a page's attributed string, grouping runs into laid-out lines and
  /// computing each line's character-weighted dominant font size and bold
  /// ratio. Falls back to the plain page string (no font signal) when no
  /// attributed string is available, e.g. a scanned / image-only PDF.
  private static func lines(for page: PDFPage) -> [Line] {
    guard let attributed = page.attributedString, attributed.length > 0 else {
      return plainLines(for: page)
    }

    var result: [Line] = []
    var buffer = ""
    var weightedSize = 0.0
    var sizeWeight = 0.0
    var boldChars = 0
    var totalChars = 0

    func flush() {
      let trimmed = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
      if !trimmed.isEmpty {
        let size = sizeWeight > 0 ? weightedSize / sizeWeight : 0
        let bold = totalChars > 0 && Double(boldChars) / Double(totalChars) >= 0.6
        result.append(Line(text: trimmed, fontSize: size, bold: bold))
      }
      buffer = ""
      weightedSize = 0
      sizeWeight = 0
      boldChars = 0
      totalChars = 0
    }

    let full = attributed.string as NSString
    attributed.enumerateAttributes(
      in: NSRange(location: 0, length: full.length),
      options: []
    ) { attrs, range, _ in
      let chunk = full.substring(with: range)
      var size = 0.0
      var bold = false
      if let font = attrs[.font] as? UIFont {
        size = Double(font.pointSize)
        bold = font.fontDescriptor.symbolicTraits.contains(.traitBold)
      }
      // A run can span several laid-out lines: PDFKit separates them with "\n".
      let segments = chunk.components(separatedBy: "\n")
      for (i, segment) in segments.enumerated() {
        if i > 0 { flush() }
        buffer += segment
        let count = segment.count
        if size > 0 {
          weightedSize += size * Double(count)
          sizeWeight += Double(count)
        }
        if bold { boldChars += count }
        totalChars += count
      }
    }
    flush()
    return result
  }

  private static func plainLines(for page: PDFPage) -> [Line] {
    guard let string = page.string else { return [] }
    return string.components(separatedBy: "\n").compactMap { raw in
      let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
      return trimmed.isEmpty ? nil : Line(text: trimmed, fontSize: 0, bold: false)
    }
  }

  // MARK: - Helpers

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
