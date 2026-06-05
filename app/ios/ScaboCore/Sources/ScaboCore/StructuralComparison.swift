//
//  StructuralComparison.swift
//  ScaboCore
//
//  Structural comparison framework — Generic (Layer 2) vs Layer 1 baseline.
//  Faithful translation of `app/src/measurement/structuralComparison.ts`,
//  preserved AS-IS.
//
//  MIGRATION DIRECTIVE (this task). The validation *method* (comparison against
//  Layer 1 JSON baselines) is known to be slated for a future rethink toward
//  validation against an external analysis — but that is a separate strategic
//  decision the developer takes, NOT here. This translation reproduces the current
//  behaviour exactly and keeps the test net that proves equivalence; it does not
//  redesign, anticipate or improve the method.
//
//  WHY IT IS NOT BYTE-FOR-BYTE. The Generic runs over an on-device PDFKit
//  extraction; the Layer 1 baselines come from PyMuPDF + the Python corpus
//  profiles. The two extractors do not see identical spans, so a byte-for-byte
//  comparison is impossible by construction. For each category of the closed
//  Generic taxonomy it counts the Generic nodes vs the Layer 1 baseline nodes and
//  reports absolute/relative deltas plus a few tree-topology metrics. CONTENT-FREE:
//  only category names, counts and numeric deltas — never document text.
//
//  Language difference (documented): the sort tie-break uses ordinal `rawValue`
//  comparison rather than JS `localeCompare`; for the all-uppercase ASCII category
//  vocabulary the two orderings coincide, and no oracle asserts the within-bucket
//  order (only that produced sorts before the other buckets). Rounding mirrors
//  `Math.round` (half away from zero) on the non-negative ratios used here.
//

import Foundation

/// Bump when the comparison report shape changes (independent of Layer 1).
public let STRUCTURAL_COMPARISON_SCHEMA_VERSION = "1.0"

/// Default RELATIVE-delta tolerance for `produced` categories: within ±15 % → CLOSE.
public let STRUCTURAL_REL_TOLERANCE = 0.15

/// The verdict for one category's count delta.
public enum DeltaBand: String, Equatable, Sendable {
    case EXACT
    case CLOSE
    case DIVERGENT
    case NOT_COMPARABLE
}

/// One per-category line of the comparison.
public struct CategoryDelta: Equatable, Sendable {
    public var category: SemanticCategory
    public var coverage: GenericCoverage
    public var generic: Int
    public var baseline: Int
    public var absDelta: Int
    /// absDelta / baseline (rounded to 4dp), or nil when baseline is 0.
    public var relDelta: Double?
    public var band: DeltaBand
}

/// Topology of the Generic tree (the real, full tree is available).
public struct GenericTopology: Equatable, Sendable {
    public var nodeTotal: Int
    /// Deepest nesting level (root nodes are depth 1).
    public var maxDepth: Int
    public var headingCountsByLevel: [String: Int]
    public var roleCounts: [String: Int]
    public var noteLengthCounts: [String: Int]
}

/// Topology derivable from a Layer 1 baseline (counts only — no tree).
public struct BaselineTopology: Equatable, Sendable {
    public var nodeTotal: Int
    public var headingCountsByLevel: [String: Int]
    /// Always false: the baseline has no tree, so depth cannot be measured.
    public let maxDepthKnown: Bool = false

    public init(nodeTotal: Int, headingCountsByLevel: [String: Int]) {
        self.nodeTotal = nodeTotal
        self.headingCountsByLevel = headingCountsByLevel
    }
}

/// Focused summary over the `produced` categories — the Generic's remit.
public struct ProducedSummary: Equatable, Sendable {
    public var categories: [String]
    public var maxRelDelta: Double?
    public var meanRelDelta: Double?
    /// True iff every produced category is EXACT or CLOSE. nil when no baseline.
    public var withinTolerance: Bool?
    public var relTolerance: Double
}

public struct StructuralComparisonReport: Equatable, Sendable {
    public var schemaVersion: String
    public var fixtureSlug: String
    public var corpusId: String
    public var baselineFile: String?
    public var baselineAvailable: Bool
    public var categories: [CategoryDelta]
    public var producedSummary: ProducedSummary
    public var topologyGeneric: GenericTopology
    public var topologyBaseline: BaselineTopology?
}

private let HEADING_LEVELS = ["HEADING_1", "HEADING_2", "HEADING_3", "HEADING_4"]

private func coverageOrder(_ coverage: GenericCoverage) -> Int {
    switch coverage {
    case .produced: return 0
    case .detectedSuppressed: return 1
    case .reserved: return 2
    }
}

/// `Math.round`-style rounding to `decimals` places (half away from zero).
private func roundTo(_ value: Double, _ decimals: Int = 4) -> Double {
    let f = pow(10.0, Double(decimals))
    return (value * f).rounded() / f
}

/// Walks a document tree computing the full Generic topology.
///
/// Depth-convention note: `walkTree` reports root nodes at depth 0, whereas the TS
/// `documentTopology` counts roots at depth 1. The observed maximum is therefore
/// shifted by +1 (and stays 0 for an empty tree), reproducing the TS value.
public func documentTopology(_ doc: ScabopdfDocument) -> GenericTopology {
    var roleCounts: [String: Int] = [:]
    var noteLengthCounts: [String: Int] = [:]
    var nodeTotal = 0
    var maxObservedDepth = -1
    walkTree(doc.structure) { node, depth, _ in
        nodeTotal += 1
        maxObservedDepth = Swift.max(maxObservedDepth, depth)
        roleCounts[node.type.rawValue, default: 0] += 1
        if node.type == .NOTE, let lc = node.length_category {
            noteLengthCounts[lc.rawValue, default: 0] += 1
        }
    }
    let maxDepth = maxObservedDepth >= 0 ? maxObservedDepth + 1 : 0
    var headingCountsByLevel: [String: Int] = [:]
    for level in HEADING_LEVELS {
        if let n = roleCounts[level], n > 0 {
            headingCountsByLevel[level] = n
        }
    }
    return GenericTopology(
        nodeTotal: nodeTotal,
        maxDepth: maxDepth,
        headingCountsByLevel: headingCountsByLevel,
        roleCounts: roleCounts,
        noteLengthCounts: noteLengthCounts
    )
}

/// Derives the (counts-only) topology of a Layer 1 baseline.
public func baselineTopology(_ counts: [String: Int]) -> BaselineTopology {
    var nodeTotal = 0
    var headingCountsByLevel: [String: Int] = [:]
    for (category, n) in counts {
        nodeTotal += n
        if HEADING_LEVELS.contains(category), n > 0 {
            headingCountsByLevel[category] = n
        }
    }
    return BaselineTopology(nodeTotal: nodeTotal, headingCountsByLevel: headingCountsByLevel)
}

/// Compares two per-category count maps, banding each category by the taxonomy.
/// Emits a line only when at least one side is non-zero. When `comparable` is
/// false, every band is NOT_COMPARABLE.
public func compareCategoryCounts(
    _ generic: [String: Int],
    _ baseline: [String: Int],
    relTolerance: Double = STRUCTURAL_REL_TOLERANCE,
    comparable: Bool = true
) -> [CategoryDelta] {
    var out: [CategoryDelta] = []
    for category in SemanticCategory.allCases {
        guard let contract = GENERIC_TAXONOMY[category] else { continue }
        let g = generic[category.rawValue] ?? 0
        let b = baseline[category.rawValue] ?? 0
        if g == 0 && b == 0 { continue }
        let coverage = contract.coverage
        let absDelta = abs(g - b)
        let relDelta: Double? = b > 0 ? roundTo(Double(absDelta) / Double(b)) : nil
        let band: DeltaBand
        if !comparable || coverage != .produced {
            band = .NOT_COMPARABLE
        } else if absDelta == 0 {
            band = .EXACT
        } else if b == 0 {
            // Generic produced something the baseline has none of: a real divergence.
            band = .DIVERGENT
        } else {
            band = (relDelta ?? .infinity) <= relTolerance ? .CLOSE : .DIVERGENT
        }
        out.append(CategoryDelta(
            category: category,
            coverage: coverage,
            generic: g,
            baseline: b,
            absDelta: absDelta,
            relDelta: relDelta,
            band: band
        ))
    }
    out.sort { a, b in
        let oa = coverageOrder(a.coverage)
        let ob = coverageOrder(b.coverage)
        if oa != ob { return oa < ob }
        return a.category.rawValue < b.category.rawValue
    }
    return out
}

private func summarizeProduced(
    _ categories: [CategoryDelta],
    baselineAvailable: Bool,
    relTolerance: Double
) -> ProducedSummary {
    let produced = categories.filter { $0.coverage == .produced }
    let names = produced.map { $0.category.rawValue }
    if !baselineAvailable {
        return ProducedSummary(
            categories: names,
            maxRelDelta: nil,
            meanRelDelta: nil,
            withinTolerance: nil,
            relTolerance: relTolerance
        )
    }
    let rels = produced.filter { $0.baseline > 0 && $0.relDelta != nil }.map { $0.relDelta! }
    let maxRelDelta = rels.max()
    let meanRelDelta = rels.isEmpty ? nil : roundTo(rels.reduce(0, +) / Double(rels.count))
    let withinTolerance = produced.allSatisfy { $0.band == .EXACT || $0.band == .CLOSE }
    return ProducedSummary(
        categories: names,
        maxRelDelta: maxRelDelta,
        meanRelDelta: meanRelDelta,
        withinTolerance: withinTolerance,
        relTolerance: relTolerance
    )
}

/// Builds the full comparison report from a Generic document and a baseline.
public func buildStructuralComparison(
    document: ScabopdfDocument,
    fixtureSlug: String,
    corpusId: String,
    baselineFile: String?,
    baselineCategoryCounts: [String: Int]?,
    relTolerance: Double = STRUCTURAL_REL_TOLERANCE
) -> StructuralComparisonReport {
    let baselineAvailable = baselineCategoryCounts != nil
    let genericTopology = documentTopology(document)
    let categories = compareCategoryCounts(
        genericTopology.roleCounts,
        baselineCategoryCounts ?? [:],
        relTolerance: relTolerance,
        comparable: baselineAvailable
    )
    return StructuralComparisonReport(
        schemaVersion: STRUCTURAL_COMPARISON_SCHEMA_VERSION,
        fixtureSlug: fixtureSlug,
        corpusId: corpusId,
        baselineFile: baselineFile,
        baselineAvailable: baselineAvailable,
        categories: categories,
        producedSummary: summarizeProduced(categories, baselineAvailable: baselineAvailable, relTolerance: relTolerance),
        topologyGeneric: genericTopology,
        topologyBaseline: baselineCategoryCounts.map { baselineTopology($0) }
    )
}

/// The result of attempting a comparison for one fixture.
public enum ComparisonOutcome: Equatable, Sendable {
    case compared(StructuralComparisonReport)
    case skipped(fixtureSlug: String, reason: String)
}

/// Orchestrates one fixture: builds the Generic document from the capture (when
/// present) and compares it to the baseline (when present).
///
/// - capture == nil → skipped (the fixture PDF was not seeded on this clone).
/// - baselineCategoryCounts == nil → a one-sided report (baselineAvailable false).
public func comparisonForCapture(
    fixtureSlug: String,
    corpusId: String,
    baselineFile: String?,
    capture: Capture?,
    baselineCategoryCounts: [String: Int]?,
    relTolerance: Double = STRUCTURAL_REL_TOLERANCE
) -> ComparisonOutcome {
    guard let capture else {
        return .skipped(
            fixtureSlug: fixtureSlug,
            reason: "fixture \"\(fixtureSlug)\" not seeded; seed the private PDFs and "
                + "capture them on a Simulator (see docs/LAYER2_TEST_FRAMEWORK.md §3: "
                + "seed_fixtures.sh + the ScaboPDFExtractionTests run + pull_captures.sh)."
        )
    }
    let document = buildDocumentFromPdf(capture.extraction, sourceName: capture.filename)
    return .compared(buildStructuralComparison(
        document: document,
        fixtureSlug: fixtureSlug,
        corpusId: corpusId,
        baselineFile: baselineFile,
        baselineCategoryCounts: baselineCategoryCounts,
        relTolerance: relTolerance
    ))
}
