//
//  Report.swift
//  ScaboCore
//
//  Content-free test-report model for the on-device extraction pipeline. Faithful
//  translation of `app/src/measurement/report.ts` — preserved AS-IS (the task's
//  measurement directive: this is migration, not a redesign of the validation
//  method, which is a separate strategic decision).
//
//  A `Capture` is the real device extraction the Swift XCTest layer writes
//  (Caches/scabo-extractions/<slug>.capture.json). `buildReport` runs the REAL
//  production pipeline over it — `buildDocumentFromPdf` (Generic plugin),
//  `buildLayout`, `paginate` — and reduces the result to a content-free report:
//  only counts, distributions, timings and (content-free) plugin warnings. No
//  segment text, so the report is safe to commit. The full text-bearing tree is
//  returned separately as `dump`.
//
//  Language differences (documented):
//   * The TS `extraction` field is `unknown`, normalised by `normalizeExtraction`.
//     Here `Capture.extraction` is the typed `PdfExtraction` (decoded by
//     `JSONDecoder`, which IS the defensive boundary — Piano § 1.6: the JSON.parse
//     defense evaporates once Swift returns typed structs), so no separate
//     normalise step is needed.
//   * Lengths use UTF-16 counts (`utf16.count`), matching JS `String.length`
//     (consistent with Fase 1-3).
//   * Timings use the monotonic `ProcessInfo.systemUptime` (Foundation-only),
//     never wall-clock, so deltas are always ≥ 0 — the only property any oracle
//     asserts. The exact millisecond values are not asserted.
//   * `paginate` is `throws` (Fase 3); `buildReport` is therefore `throws`, but
//     with the default page size (> 0) it never actually throws.
//

import Foundation

/// Bump when the report shape changes (independent of the Layer-1 schema).
public let TEST_REPORT_SCHEMA_VERSION = "1.0"

/// The Swift-captured device extraction (Caches/scabo-extractions/*.json).
public struct Capture: Codable, Equatable, Sendable {
    public var filename: String
    public var extractMs: Double
    public var pdfSizeBytes: Int
    /// Typed PDFKit extraction; the decode IS the normalisation boundary.
    public var extraction: PdfExtraction

    public init(filename: String, extractMs: Double, pdfSizeBytes: Int, extraction: PdfExtraction) {
        self.filename = filename
        self.extractMs = extractMs
        self.pdfSizeBytes = pdfSizeBytes
        self.extraction = extraction
    }
}

public struct ExtractionStats: Codable, Equatable, Sendable {
    public var pages: Int
    public var lines: Int
    /// Line count per dominant font size (rounded to 0.5pt). Content-free.
    public var fontSizeHistogram: [String: Int]
    /// Fraction of lines that are predominantly bold, in [0, 1].
    public var boldLineRatio: Double
    public var payloadBytes: Int
}

public struct DocumentStats: Codable, Equatable, Sendable {
    public var profileId: String
    public var nodeTotal: Int
    public var roleCounts: [String: Int]
    public var noteLengthCounts: [String: Int]
    public var warnings: [String]
}

public struct LayoutStats: Codable, Equatable, Sendable {
    public var layoutId: String
    public var segmentTotal: Int
    public var pagesProduced: Int
}

public struct Timings: Codable, Equatable, Sendable {
    public var extractMs: Double
    public var pluginMs: Double
    public var layoutMs: Double
    public var paginateMs: Double
}

public struct ContentFreeReport: Codable, Equatable, Sendable {
    public var reportSchemaVersion: String
    public var pdfFilename: String
    public var pdfSizeBytes: Int
    public var extraction: ExtractionStats
    public var document: DocumentStats
    public var layout: LayoutStats
    public var timings: Timings
}

/// The text-bearing artefacts; NEVER committed (gitignored output tree).
public struct ReportDump: Equatable, Sendable {
    public var document: ScabopdfDocument
    public var segmentRoles: [String]
}

public struct BuildReportResult: Equatable, Sendable {
    public var report: ContentFreeReport
    public var dump: ReportDump
}

private let REPORT_LAYOUT_ID: LayoutId = .continuous

/// Total number of lines across every page. Port of `totalLines` (pdfExtraction.ts).
public func totalLines(_ extraction: PdfExtraction) -> Int {
    extraction.pages.reduce(0) { $0 + $1.lines.count }
}

/// Runs the real pipeline over a capture and returns the content-free report.
public func buildReport(_ capture: Capture) throws -> BuildReportResult {
    let extraction = capture.extraction

    let t0 = nowMs()
    let document = buildDocumentFromPdf(extraction, sourceName: capture.filename)
    let t1 = nowMs()
    let segments = buildLayout(document, REPORT_LAYOUT_ID)
    let t2 = nowMs()
    let paginated = try paginate(segments)
    let t3 = nowMs()

    let walked = walkDocument(document)

    let report = ContentFreeReport(
        reportSchemaVersion: TEST_REPORT_SCHEMA_VERSION,
        pdfFilename: capture.filename,
        pdfSizeBytes: capture.pdfSizeBytes,
        extraction: ExtractionStats(
            pages: extraction.pageCount,
            lines: totalLines(extraction),
            fontSizeHistogram: fontSizeHistogram(extraction),
            boldLineRatio: boldLineRatio(extraction),
            payloadBytes: byteLength(extraction)
        ),
        document: DocumentStats(
            profileId: document.profile.profile_id,
            nodeTotal: walked.nodeTotal,
            roleCounts: walked.roleCounts,
            noteLengthCounts: walked.noteLengthCounts,
            warnings: document.warnings
        ),
        layout: LayoutStats(
            layoutId: REPORT_LAYOUT_ID.rawValue,
            segmentTotal: paginated.totalSegments,
            pagesProduced: paginated.pages.count
        ),
        timings: Timings(
            extractMs: capture.extractMs,
            pluginMs: round2(t1 - t0),
            layoutMs: round2(t2 - t1),
            paginateMs: round2(t3 - t2)
        )
    )

    return BuildReportResult(
        report: report,
        dump: ReportDump(document: document, segmentRoles: segments.map { $0.role })
    )
}

/// Walks the node tree counting roles, NOTE length categories and total nodes.
private func walkDocument(
    _ doc: ScabopdfDocument
) -> (roleCounts: [String: Int], noteLengthCounts: [String: Int], nodeTotal: Int) {
    var roleCounts: [String: Int] = [:]
    var noteLengthCounts: [String: Int] = [:]
    var nodeTotal = 0
    walkTree(doc.structure) { node, _, _ in
        nodeTotal += 1
        roleCounts[node.type.rawValue, default: 0] += 1
        if node.type == .NOTE, let lc = node.length_category {
            noteLengthCounts[lc.rawValue, default: 0] += 1
        }
    }
    return (roleCounts, noteLengthCounts, nodeTotal)
}

private func fontSizeHistogram(_ extraction: PdfExtraction) -> [String: Int] {
    var hist: [String: Int] = [:]
    for page in extraction.pages {
        for line in page.lines {
            let rounded = (summarizeLine(line).fontSize * 2).rounded() / 2
            let key = String(format: "%.1f", rounded)
            hist[key, default: 0] += 1
        }
    }
    return hist
}

private func boldLineRatio(_ extraction: PdfExtraction) -> Double {
    var total = 0
    var bold = 0
    for page in extraction.pages {
        for line in page.lines {
            total += 1
            if summarizeLine(line).bold { bold += 1 }
        }
    }
    return total == 0 ? 0 : round4(Double(bold) / Double(total))
}

/// UTF-16 length of the JSON serialisation of the extraction (content-free size
/// proxy; the TS uses `JSON.stringify(extraction).length`). Not asserted by any
/// oracle; the exact value differs from JS by serialisation formatting.
private func byteLength(_ extraction: PdfExtraction) -> Int {
    guard let data = try? JSONEncoder().encode(extraction),
          let text = String(data: data, encoding: .utf8) else {
        return 0
    }
    return text.utf16.count
}

/// Monotonic milliseconds (Foundation-only; never goes backwards).
private func nowMs() -> Double {
    ProcessInfo.processInfo.systemUptime * 1000
}

private func round2(_ value: Double) -> Double {
    (value * 100).rounded() / 100
}

private func round4(_ value: Double) -> Double {
    (value * 10000).rounded() / 10000
}
