//
//  PdfExtraction.swift
//  ScaboCore
//
//  The extraction ⇄ classification seam (Piano di migrazione § 10).
//
//  Fase 1 does NOT implement an extractor. This file only *predisposes* the
//  boundary so that adding one later — PDFKit first (the distributable base),
//  MuPDF later (the private quality ceiling) — costs nothing structurally:
//
//    * `PdfExtraction` (and its `PdfPageExtraction` / `PdfTextLine` / `PdfSpan`
//      / `BBox` leaves) is the single data contract an extractor produces and a
//      classifier consumes. It mirrors the TypeScript `PdfExtraction` shape in
//      `app/src/native/pdfExtraction.ts` (payload `version`, `pageCount`, and
//      per-page per-span text/size/bold/italic/colour/bbox + page geometry).
//    * `PdfExtracting` is the protocol the extractor conforms to. A future
//      `PdfKitExtractor` and a future `MuPdfExtractor` both produce the *same*
//      `PdfExtraction`; the classifier depends only on this type, never on a
//      concrete engine.
//
//  Hard rule preserved here: ScaboCore imports ONLY Foundation. No PDFKit, no
//  engine type, leaks across this boundary — that is what keeps the extractor
//  swappable. The signal-reduction adapter (`summarizeLine` / `LineSummary`)
//  and the classifier belong on the consumer side and arrive in Fase 2; they
//  are intentionally absent now.
//

import Foundation

/// A page-local bounding box, origin bottom-left, y up. Mirrors the TS
/// `[x, y, w, h]` tuple.
///
/// `Codable` decodes/encodes the JSON **array** form `[x, y, w, h]` (the shape a
/// captured device extraction uses), not a keyed object — added in Fase 4 so the
/// measurement layer can parse a `Capture` with the production decode (the Swift
/// analog of the TS `normalizeExtraction`). The conformance is additive: existing
/// `Equatable`/`Sendable` behaviour is unchanged, and no PDFKit type leaks across
/// the seam.
public struct BBox: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public init(from decoder: Decoder) throws {
        var c = try decoder.unkeyedContainer()
        let x = try c.decode(Double.self)
        let y = try c.decode(Double.self)
        let w = try c.decode(Double.self)
        let h = try c.decode(Double.self)
        self.init(x: x, y: y, width: w, height: h)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.unkeyedContainer()
        try c.encode(x)
        try c.encode(y)
        try c.encode(width)
        try c.encode(height)
    }
}

/// One maximal run of uniform typographic attributes within a laid-out line.
public struct PdfSpan: Codable, Equatable, Sendable {
    public var text: String
    /// Font point size (0 if the engine reported none, e.g. a scanned PDF).
    public var fontSize: Double
    public var bold: Bool
    public var italic: Bool
    /// Resolved fill colour as "#rrggbb" (PDF default → "#000000").
    public var color: String
    public var bbox: BBox

    public init(text: String, fontSize: Double, bold: Bool, italic: Bool, color: String, bbox: BBox) {
        self.text = text
        self.fontSize = fontSize
        self.bold = bold
        self.italic = italic
        self.color = color
        self.bbox = bbox
    }
}

/// One laid-out line of text: its spans plus the union bbox.
public struct PdfTextLine: Codable, Equatable, Sendable {
    public var spans: [PdfSpan]
    public var bbox: BBox

    public init(spans: [PdfSpan], bbox: BBox) {
        self.spans = spans
        self.bbox = bbox
    }
}

/// The lines extracted from a single PDF page, in reading order.
public struct PdfPageExtraction: Codable, Equatable, Sendable {
    /// 0-based page index (the Layer 1 `PageIndex` convention).
    public var pageIndex: Int
    /// Page (cropBox) width/height in points, for normalising bbox positions.
    public var width: Double
    public var height: Double
    public var lines: [PdfTextLine]

    public init(pageIndex: Int, width: Double, height: Double, lines: [PdfTextLine]) {
        self.pageIndex = pageIndex
        self.width = width
        self.height = height
        self.lines = lines
    }
}

/// The full structured extraction of a PDF — the boundary value type.
public struct PdfExtraction: Codable, Equatable, Sendable {
    /// Payload shape version (2 = per-span).
    public var version: Int
    public var pageCount: Int
    public var pages: [PdfPageExtraction]
    /// Document `Producer` metadata (the exporter that wrote the PDF, e.g.
    /// "Skia/PDF … Google Docs Renderer", "Aspose.PDF for .NET", "PDFsharp …"),
    /// or `nil` if the engine reported none. A self-declaring family signal used by
    /// corpus branches (the user-generated branch keys on Google Docs / Word); the
    /// trunk Generic never reads it. Optional + default `nil` keeps the field purely
    /// additive — existing constructions and captured JSON without it are unchanged
    /// (synthesised `Codable` omits a `nil` optional on encode, and decodes a missing
    /// key to `nil`).
    public var producer: String?
    /// Document `Creator` metadata (the authoring app), or `nil`. Same role as
    /// `producer`; some pipelines stamp the family signal here instead.
    public var creator: String?

    public init(
        version: Int,
        pageCount: Int,
        pages: [PdfPageExtraction],
        producer: String? = nil,
        creator: String? = nil
    ) {
        self.version = version
        self.pageCount = pageCount
        self.pages = pages
        self.producer = producer
        self.creator = creator
    }
}

/// The protocol an extractor conforms to. A `PdfKitExtractor` (base) and a
/// `MuPdfExtractor` (ceiling) are interchangeable behind this single seam; the
/// classifier consumes only the returned `PdfExtraction`.
public protocol PdfExtracting {
    func extract(fromUri uri: String) throws -> PdfExtraction
}
