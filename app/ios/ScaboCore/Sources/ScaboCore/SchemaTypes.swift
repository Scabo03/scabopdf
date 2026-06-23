//
//  SchemaTypes.swift
//  ScaboCore
//
//  The Layer 1 → Layer 2 JSON contract, schema version 0.7.0, expressed as
//  Swift `Codable` value types. This is the faithful translation of
//  `app/src/consumption/schema.generated.ts`, whose single source of truth is
//  `shared/schema.json`. Field names, required/optional status, nullability and
//  the closed enum vocabularies are copied verbatim from that contract — no
//  field is invented or dropped.
//
//  Mapping conventions between the JSON Schema and these structs:
//
//   * Required scalar fields → non-optional stored properties (a missing key
//     surfaces as `DecodingError.keyNotFound`, the structural-validation signal
//     `DocumentValidation` relies on).
//   * Nullable fields (`anyOf: [..., {"type":"null"}]`, default `null`) →
//     Swift `Optional`, decoded with `decodeIfPresent` (absent key → `nil`).
//   * Optional non-nullable array fields (`block_indices`, `children`,
//     `apparatus_refs`, document `warnings` / `transformations` / `structure`)
//     → non-optional arrays defaulting to `[]` when the key is absent, matching
//     the TypeScript `?? []` reading. This requires a hand-written
//     `init(from:)` because Swift's synthesised Codable would otherwise throw
//     `keyNotFound` for a missing non-optional property.
//
//  Tuple-typed JSON fields (`page_size_pt`, `position`) are modelled as fixed
//  arrays (`[Double]` / `[Int]`); the exact-length-2 JSON Schema constraint is
//  not re-enforced here (it is not exercised by the Fase 1 oracles — see
//  `DocumentValidation.swift` for the documented validation scope).
//

import Foundation

// MARK: - Closed enums

/// The closed vocabulary of node categories (`SemanticCategory` in the
/// contract). Case names are the raw values verbatim, so `rawValue` equals the
/// JSON token (e.g. `.BODY` ↔ `"BODY"`). 46 values at schema 0.7.0.
public enum SemanticCategory: String, Codable, CaseIterable, Equatable, Sendable {
    case HEADING_1, HEADING_2, HEADING_3, HEADING_4
    case ARTICLE_HEADER, ARTICLE_BODY, PROCEDURAL
    case BODY, BODY_CONTINUATION
    case NOTE, NOTE_CONTINUATION
    case MARGINAL_HEADING, MARGINAL_GLOSS
    case EXAMPLE_BOX, CHAPTER_SUMMARY, TOC_GENERAL, INDEX_ENTRY, EDITORIAL_NOTE
    case MASSIMA_LABEL, REFERRAL, TITLE
    case FONTE_LABEL, FONTE_VALUE, META_LABEL, META_VALUE, AUTHORS
    case SECTION_LABEL, GENRE_BANNER, SUBTITLE, HEADING_LETTER_INITIAL
    case FONTI, LETTERATURA
    case AMENDMENT, QUOTED_TEXT_OLD, QUOTED_TEXT_NEW, UPDATE_BLOCK
    case CROSS_REFERENCE, LIST_ITEM, BOOK_PAGE_ANCHOR
    case ARTIFACT_RUNNING_HEADER, ARTIFACT_FOOTER, ARTIFACT_FILIGREE
    case ARTIFACT_STAMP, ARTIFACT_PAGE_HEADER
    case EMPTY_PAGE, UNCLASSIFIED
}

/// Closed enum of relationships produced by tier 1 apparatus resolution.
public enum ApparatusRefKind: String, Codable, CaseIterable, Equatable, Sendable {
    case CROSS_REF_TARGET, BODY_ASSOCIATION, GLOSS_TARGET
}

/// The six closed acoustic regimes carried by `NOTE` nodes (schema 0.6.0+).
public enum LengthCategory: String, Codable, CaseIterable, Equatable, Sendable {
    case MICRO, SHORT, MEDIUM, LONG, VERY_LONG, MEGA
}

// MARK: - Leaf objects

/// One entry parsed out of a `CHAPTER_SUMMARY` block. `number` is a string to
/// admit composite numerations (`"1.1"`, `"2-bis"`).
public struct ChapterSummaryItem: Codable, Equatable, Sendable {
    public var number: String
    public var title: String

    public init(number: String, title: String) {
        self.number = number
        self.title = title
    }
}

/// One entry parsed out of a `TOC_GENERAL` block. `page_number` is the 1-based
/// printed book page number, distinct from the 0-based `PageIndex`; `nil` when
/// the plugin could not parse a numeric page reference.
public struct TocGeneralItem: Codable, Equatable, Sendable {
    public var number: String
    public var title: String
    public var page_number: Int?

    public init(number: String, title: String, page_number: Int? = nil) {
        self.number = number
        self.title = title
        self.page_number = page_number
    }
}

/// A directed apparatus reference attached to a node.
public struct ApparatusRefDict: Codable, Equatable, Sendable {
    public var kind: ApparatusRefKind
    public var target_node_id: String
    public var source_marker: String?

    public init(kind: ApparatusRefKind, target_node_id: String, source_marker: String? = nil) {
        self.kind = kind
        self.target_node_id = target_node_id
        self.source_marker = source_marker
    }
}

/// A reversible operation recorded by a post-processing or tier 2 step.
public struct TransformationDict: Codable, Equatable, Sendable {
    public var step_id: String
    public var node_id: String
    public var page_index: Int
    /// Half-open `(start, end)` offset into the pre-step node text.
    public var position: [Int]
    public var original: String
    public var normalized: String
    public var split_into: [String]?
    public var merged_from: [String]?

    public init(
        step_id: String,
        node_id: String,
        page_index: Int,
        position: [Int],
        original: String,
        normalized: String,
        split_into: [String]? = nil,
        merged_from: [String]? = nil
    ) {
        self.step_id = step_id
        self.node_id = node_id
        self.page_index = page_index
        self.position = position
        self.original = original
        self.normalized = normalized
        self.split_into = split_into
        self.merged_from = merged_from
    }
}

/// Editorial metadata extracted from the source PDF. `page_size_pt` is the
/// `(width, height)` of the first page in PostScript points.
public struct DocumentMetadata: Codable, Equatable, Sendable {
    public var pages_pdf: Int
    public var page_size_pt: [Double]
    public var source_pdf_filename: String

    public init(pages_pdf: Int, page_size_pt: [Double], source_pdf_filename: String) {
        self.pages_pdf = pages_pdf
        self.page_size_pt = page_size_pt
        self.source_pdf_filename = source_pdf_filename
    }
}

/// Output of the profiling phase, as it appears in the emitted JSON.
public struct DocumentProfileDict: Codable, Equatable, Sendable {
    public var profile_id: String
    public var editorial_family: String
    public var genre: String
    public var confidence: Double

    public init(profile_id: String, editorial_family: String, genre: String, confidence: Double) {
        self.profile_id = profile_id
        self.editorial_family = editorial_family
        self.genre = genre
        self.confidence = confidence
    }
}

// MARK: - Recursive node

/// A node in the reading-order tree. `children` is recursive and produces an
/// arbitrarily deep forest. The non-optional array fields default to `[]` when
/// absent, mirroring the TypeScript `?? []` reading.
public struct NodeDict: Codable, Equatable, Sendable {
    public var id: String
    public var type: SemanticCategory
    public var page_index: Int
    public var text: String?
    public var level: Int?
    public var items: [ChapterSummaryItem]?
    public var toc_items: [TocGeneralItem]?
    public var length_category: LengthCategory?
    public var block_indices: [Int]
    public var children: [NodeDict]
    public var apparatus_refs: [ApparatusRefDict]
    /// Rinfresco di contesto (§ 7.4/§ 7.5) da anteporre alla lettura di QUESTA nota
    /// quando è differita lontano dal richiamo. Campo INTERNO di Layer 2: NON fa parte
    /// del contratto schema (assente da `CodingKeys` → mai serializzato/deserializzato),
    /// è annotato in memoria da `bindAndPlaceNotes` sui soli nodi nota differiti.
    /// `nil` per ogni altro nodo. Vedi `MemoryRefresh.swift`.
    public var memoryRefresh: String? = nil

    public init(
        id: String,
        type: SemanticCategory,
        page_index: Int,
        text: String? = nil,
        level: Int? = nil,
        items: [ChapterSummaryItem]? = nil,
        toc_items: [TocGeneralItem]? = nil,
        length_category: LengthCategory? = nil,
        block_indices: [Int] = [],
        children: [NodeDict] = [],
        apparatus_refs: [ApparatusRefDict] = [],
        memoryRefresh: String? = nil
    ) {
        self.id = id
        self.type = type
        self.page_index = page_index
        self.text = text
        self.level = level
        self.items = items
        self.toc_items = toc_items
        self.length_category = length_category
        self.block_indices = block_indices
        self.children = children
        self.apparatus_refs = apparatus_refs
        self.memoryRefresh = memoryRefresh
    }

    private enum CodingKeys: String, CodingKey {
        case id, type, page_index, text, level, items, toc_items
        case length_category, block_indices, children, apparatus_refs
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        type = try c.decode(SemanticCategory.self, forKey: .type)
        page_index = try c.decode(Int.self, forKey: .page_index)
        text = try c.decodeIfPresent(String.self, forKey: .text)
        level = try c.decodeIfPresent(Int.self, forKey: .level)
        items = try c.decodeIfPresent([ChapterSummaryItem].self, forKey: .items)
        toc_items = try c.decodeIfPresent([TocGeneralItem].self, forKey: .toc_items)
        length_category = try c.decodeIfPresent(LengthCategory.self, forKey: .length_category)
        block_indices = try c.decodeIfPresent([Int].self, forKey: .block_indices) ?? []
        children = try c.decodeIfPresent([NodeDict].self, forKey: .children) ?? []
        apparatus_refs = try c.decodeIfPresent([ApparatusRefDict].self, forKey: .apparatus_refs) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(type, forKey: .type)
        try c.encode(page_index, forKey: .page_index)
        try c.encodeIfPresent(text, forKey: .text)
        try c.encodeIfPresent(level, forKey: .level)
        try c.encodeIfPresent(items, forKey: .items)
        try c.encodeIfPresent(toc_items, forKey: .toc_items)
        try c.encodeIfPresent(length_category, forKey: .length_category)
        if !block_indices.isEmpty { try c.encode(block_indices, forKey: .block_indices) }
        if !children.isEmpty { try c.encode(children, forKey: .children) }
        if !apparatus_refs.isEmpty { try c.encode(apparatus_refs, forKey: .apparatus_refs) }
    }
}

// MARK: - Root document

/// The Layer 1 → Layer 2 JSON document. `schema_version` is decoded as a plain
/// string here (the supported-version gate lives in `parseDocument`, which
/// peeks it before validation, mirroring the TypeScript flow). The non-optional
/// array fields default to `[]` when absent.
public struct ScabopdfDocument: Codable, Equatable, Sendable {
    public var schema_version: String
    public var document_id: String
    public var metadata: DocumentMetadata
    public var profile: DocumentProfileDict
    public var warnings: [String]
    public var transformations: [TransformationDict]
    public var structure: [NodeDict]

    public init(
        schema_version: String,
        document_id: String,
        metadata: DocumentMetadata,
        profile: DocumentProfileDict,
        warnings: [String] = [],
        transformations: [TransformationDict] = [],
        structure: [NodeDict] = []
    ) {
        self.schema_version = schema_version
        self.document_id = document_id
        self.metadata = metadata
        self.profile = profile
        self.warnings = warnings
        self.transformations = transformations
        self.structure = structure
    }

    private enum CodingKeys: String, CodingKey {
        case schema_version, document_id, metadata, profile
        case warnings, transformations, structure
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schema_version = try c.decode(String.self, forKey: .schema_version)
        document_id = try c.decode(String.self, forKey: .document_id)
        metadata = try c.decode(DocumentMetadata.self, forKey: .metadata)
        profile = try c.decode(DocumentProfileDict.self, forKey: .profile)
        warnings = try c.decodeIfPresent([String].self, forKey: .warnings) ?? []
        transformations = try c.decodeIfPresent([TransformationDict].self, forKey: .transformations) ?? []
        structure = try c.decodeIfPresent([NodeDict].self, forKey: .structure) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(schema_version, forKey: .schema_version)
        try c.encode(document_id, forKey: .document_id)
        try c.encode(metadata, forKey: .metadata)
        try c.encode(profile, forKey: .profile)
        if !warnings.isEmpty { try c.encode(warnings, forKey: .warnings) }
        if !transformations.isEmpty { try c.encode(transformations, forKey: .transformations) }
        if !structure.isEmpty { try c.encode(structure, forKey: .structure) }
    }
}
