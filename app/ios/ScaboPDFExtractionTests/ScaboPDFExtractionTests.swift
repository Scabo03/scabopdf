// On-device PDF-extraction measurement layer — the bottom of the test pyramid.
//
// A plain XCTest unit target (NOT XCUITest): it does not use the accessibility
// automation backbone, so it runs on the restricted sandbox Simulator where
// XCUITest cannot initialise. It exercises the REAL Swift/PDFKit extractor
// (ScaboPdfExtractor.extract) on the 7 private fixtures seeded into the app
// container by app/ios/scripts/seed_fixtures.sh, and produces the first
// objective on-device measurements of what the extraction layer yields — no
// PyMuPDF proxy, the genuine engine the app ships with.
//
// What it asserts (per fixture): extraction completes without throwing, the
// payload is non-empty, at least one page and one text line come out.
//
// What it captures (for the TypeScript report stage, macro-step C): the REAL
// extraction JSON wrapped with timing + size, written to
// Caches/scabo-extractions/<slug>.capture.json. The deterministic TS plugin /
// layout / paginate then run over this real device extraction to measure
// nodes/roles/length_category — identical to what runs in Hermes on-device,
// because that code has no platform branches.
//
// No fixtures seeded → the test SKIPS (XCTSkip), keeping the suite green on a
// fresh clone with no local PDFs (the project fixture convention).

import XCTest
import ScaboNative

final class ScaboPDFExtractionTests: XCTestCase {

  /// The subdirectory under the app's Documents where seed_fixtures.sh places
  /// the PDFs. Must match the script's default --subdir.
  private static let fixtureSubdir = "scabo-fixtures"
  /// Where the real extraction captures are written for the TS report stage.
  private static let captureSubdir = "scabo-extractions"

  override func setUpWithError() throws {
    // Run every fixture even if one assertion fails, so a single bad PDF does
    // not hide the measurements for the other six.
    continueAfterFailure = true
  }

  func testExtractAllSeededFixtures() throws {
    let fm = FileManager.default
    let fixturesDir = try documentsDirectory()
      .appendingPathComponent(Self.fixtureSubdir, isDirectory: true)

    guard fm.fileExists(atPath: fixturesDir.path) else {
      throw XCTSkip(
        "No seeded fixtures at \(fixturesDir.path). Run "
        + "app/ios/scripts/seed_fixtures.sh against the booted Simulator first "
        + "(the private PDFs are gitignored).")
    }

    let pdfs = try fm.contentsOfDirectory(at: fixturesDir,
                                          includingPropertiesForKeys: [.fileSizeKey])
      .filter { $0.pathExtension.lowercased() == "pdf" }
      .sorted { $0.lastPathComponent < $1.lastPathComponent }

    try XCTSkipIf(pdfs.isEmpty,
                  "Fixtures directory exists but holds no PDFs: \(fixturesDir.path)")

    let captureDir = try cachesDirectory()
      .appendingPathComponent(Self.captureSubdir, isDirectory: true)
    try? fm.createDirectory(at: captureDir, withIntermediateDirectories: true)

    for pdf in pdfs {
      measureOne(pdf, captureDir: captureDir)
    }

    ScaboLog.event(.test, "extraction_suite_complete", ["fixtures": pdfs.count])
  }

  /// Extracts one fixture, asserts the basic invariants, emits content-free
  /// metrics, and writes the capture file the TS report stage consumes.
  private func measureOne(_ pdf: URL, captureDir: URL) {
    let name = pdf.lastPathComponent
    let sizeBytes = (try? pdf.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0

    let start = Date()
    let json: String
    do {
      json = try ScaboPdfExtractor.extract(fromUri: pdf.path)
    } catch {
      XCTFail("Extraction threw for \(name): \(error.localizedDescription)")
      ScaboLog.error("fixture_extract_threw", ["name": name])
      return
    }
    let elapsedMs = Int(Date().timeIntervalSince(start) * 1000)

    XCTAssertFalse(json.isEmpty, "Empty extraction payload for \(name)")

    // Parse the payload to assert structure and count pages/lines.
    guard let data = json.data(using: .utf8),
          let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let pages = root["pages"] as? [[String: Any]] else {
      XCTFail("Extraction payload not parseable for \(name)")
      return
    }
    let pageCount = (root["pageCount"] as? Int) ?? pages.count
    let lineCount = pages.reduce(0) { acc, page in
      acc + ((page["lines"] as? [[String: Any]])?.count ?? 0)
    }

    XCTAssertGreaterThan(pageCount, 0, "No pages extracted from \(name)")
    XCTAssertGreaterThan(lineCount, 0,
                         "No text lines extracted from \(name) (image-only PDF?)")

    // Content-free metrics onto the unified channel.
    ScaboLog.event(.test, "fixture_extracted", [
      "name": name,
      "pages": pageCount,
      "lines": lineCount,
      "bytes": json.utf8.count,
      "pdfBytes": sizeBytes,
      "ms": elapsedMs,
    ])

    writeCapture(name: name, extractMs: elapsedMs, pdfBytes: sizeBytes,
                 extractionRoot: root, captureDir: captureDir)
  }

  /// Writes `{ filename, extractMs, pdfSizeBytes, extraction }` so the TS report
  /// stage can run the real plugin/layout over the real device extraction.
  private func writeCapture(name: String, extractMs: Int, pdfBytes: Int,
                            extractionRoot: [String: Any], captureDir: URL) {
    let wrapper: [String: Any] = [
      "filename": name,
      "extractMs": extractMs,
      "pdfSizeBytes": pdfBytes,
      "extraction": extractionRoot,
    ]
    guard JSONSerialization.isValidJSONObject(wrapper),
          let data = try? JSONSerialization.data(withJSONObject: wrapper,
                                                 options: [.sortedKeys]) else {
      XCTFail("Could not serialise capture for \(name)")
      return
    }
    let url = captureDir.appendingPathComponent("\(slug(name)).capture.json")
    do {
      try data.write(to: url, options: .atomic)
    } catch {
      XCTFail("Could not write capture for \(name): \(error.localizedDescription)")
    }
  }

  // MARK: - Helpers

  private func documentsDirectory() throws -> URL {
    guard let url = FileManager.default.urls(for: .documentDirectory,
                                             in: .userDomainMask).first else {
      throw XCTSkip("No Documents directory available in this process.")
    }
    return url
  }

  private func cachesDirectory() throws -> URL {
    guard let url = FileManager.default.urls(for: .cachesDirectory,
                                             in: .userDomainMask).first else {
      throw XCTSkip("No Caches directory available in this process.")
    }
    return url
  }

  /// Filesystem-safe slug from a PDF filename (drops the extension).
  private func slug(_ name: String) -> String {
    let base = (name as NSString).deletingPathExtension.lowercased()
    let mapped = base.map { ch -> Character in
      ch.isLetter || ch.isNumber ? ch : "_"
    }
    var out = String(mapped)
    while out.contains("__") { out = out.replacingOccurrences(of: "__", with: "_") }
    return out.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
  }
}
