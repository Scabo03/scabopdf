//
//  StructuralComparisonTests.swift
//  ScaboCoreTests
//
//  XCTest translation of `app/src/measurement/__tests__/structuralComparison.test.ts`
//  (335) — the delta math, taxonomy-driven banding, topology metrics, report
//  well-formedness, the missing-fixture skip and the corpusBaselines registry —
//  plus two end-to-end exercises on REAL committed Layer-1 baselines (the OGGI
//  analog of the structuralComparison.integration generator, whose true
//  Generic-vs-Layer1 form needs on-device captures and is banda POST-MAC).
//
//  Migration directive honoured: the framework is translated AS-IS; the
//  validation method is not redesigned.
//

import XCTest
@testable import ScaboCore

final class StructuralComparisonTests: XCTestCase {

    private func makeDoc(_ structure: [NodeDict]) -> ScabopdfDocument {
        ScabopdfDocument(
            schema_version: "0.7.0",
            document_id: "synthetic",
            metadata: DocumentMetadata(pages_pdf: 1, page_size_pt: [0, 0], source_pdf_filename: "s.pdf"),
            profile: DocumentProfileDict(profile_id: "generic", editorial_family: "generic", genre: "unknown", confidence: 0.05),
            structure: structure
        )
    }

    private func node(_ id: String, _ type: SemanticCategory, children: [NodeDict] = [], length: LengthCategory? = nil) -> NodeDict {
        NodeDict(id: id, type: type, page_index: 0, text: id, length_category: length, children: children)
    }

    // MARK: compareCategoryCounts — delta math and taxonomy banding

    private lazy var deltas: [CategoryDelta] = compareCategoryCounts(
        ["HEADING_1": 10, "BODY": 100, "NOTE": 5],
        ["HEADING_1": 10, "BODY": 90, "NOTE": 50, "CROSS_REFERENCE": 200, "ARTIFACT_FOOTER": 30]
    )

    private func by(_ c: SemanticCategory) -> CategoryDelta? {
        deltas.first { $0.category == c }
    }

    /// TS: "EXACT when counts are equal".
    func test_compare_exact() {
        let d = by(.HEADING_1)
        XCTAssertEqual(d?.absDelta, 0)
        XCTAssertEqual(d?.relDelta, 0)
        XCTAssertEqual(d?.band, .EXACT)
    }

    /// TS: "CLOSE within the relative tolerance".
    func test_compare_close() {
        XCTAssertEqual(by(.BODY)?.absDelta, 10)
        XCTAssertEqual(by(.BODY)?.band, .CLOSE)
        XCTAssertEqual(by(.BODY)?.relDelta ?? .nan, 0.1111, accuracy: 0.001)
    }

    /// TS: "DIVERGENT beyond the relative tolerance".
    func test_compare_divergent() {
        XCTAssertEqual(by(.NOTE)?.absDelta, 45)
        XCTAssertEqual(by(.NOTE)?.band, .DIVERGENT)
    }

    /// TS: "reserved categories are NOT_COMPARABLE regardless of delta".
    func test_compare_reservedNotComparable() {
        let d = by(.CROSS_REFERENCE)
        XCTAssertEqual(d?.generic, 0)
        XCTAssertEqual(d?.baseline, 200)
        XCTAssertEqual(d?.band, .NOT_COMPARABLE)
    }

    /// TS: "detected-suppressed categories are NOT_COMPARABLE".
    func test_compare_detectedSuppressedNotComparable() {
        XCTAssertEqual(by(.ARTIFACT_FOOTER)?.band, .NOT_COMPARABLE)
    }

    /// TS: "omits categories absent on both sides".
    func test_compare_omitsAbsent() {
        XCTAssertNil(by(.PROCEDURAL))
        XCTAssertNil(by(.EXAMPLE_BOX))
    }

    /// TS: "produced categories sort before reserved/detected-suppressed".
    func test_compare_producedSortsFirst() {
        let firstNonProduced = deltas.firstIndex { $0.coverage != .produced }!
        let lastProduced = deltas.lastIndex { $0.coverage == .produced }!
        XCTAssertLessThan(lastProduced, firstNonProduced)
    }

    /// TS: "every reported category is a known taxonomy category".
    func test_compare_everyCategoryKnown() {
        for d in deltas {
            XCTAssertNotNil(GENERIC_TAXONOMY[d.category])
            XCTAssertEqual(d.coverage, GENERIC_TAXONOMY[d.category]?.coverage)
        }
    }

    // MARK: compareCategoryCounts — edge cases

    /// TS: "baseline 0 with generic > 0 is DIVERGENT and relDelta null".
    func test_compare_baselineZeroDivergent() {
        let d = compareCategoryCounts(["HEADING_4": 7], [:]).first { $0.category == .HEADING_4 }
        XCTAssertEqual(d?.generic, 7)
        XCTAssertEqual(d?.baseline, 0)
        XCTAssertNil(d?.relDelta ?? nil)
        XCTAssertEqual(d?.band, .DIVERGENT)
    }

    /// TS: "comparable=false bands everything NOT_COMPARABLE".
    func test_compare_comparableFalse() {
        let ds = compareCategoryCounts(["HEADING_1": 3, "BODY": 9], [:], comparable: false)
        XCTAssertTrue(ds.allSatisfy { $0.band == .NOT_COMPARABLE })
    }

    /// TS: "respects a custom relative tolerance".
    func test_compare_customTolerance() {
        XCTAssertEqual(
            compareCategoryCounts(["BODY": 12], ["BODY": 10], relTolerance: 0.25).first { $0.category == .BODY }?.band,
            .CLOSE
        )
        XCTAssertEqual(
            compareCategoryCounts(["BODY": 12], ["BODY": 10]).first { $0.category == .BODY }?.band,
            .DIVERGENT
        )
    }

    // MARK: documentTopology

    func test_documentTopology() {
        let doc = makeDoc([
            node("n0", .HEADING_1, children: [
                node("n1", .BODY),
                node("n2", .NOTE, children: [node("n3", .NOTE, length: .MICRO)], length: .SHORT),
            ]),
            node("n4", .HEADING_2),
        ])
        let topo = documentTopology(doc)
        XCTAssertEqual(topo.nodeTotal, 5)
        XCTAssertEqual(topo.maxDepth, 3)
        XCTAssertEqual(topo.headingCountsByLevel, ["HEADING_1": 1, "HEADING_2": 1])
        XCTAssertEqual(topo.noteLengthCounts, ["SHORT": 1, "MICRO": 1])
        XCTAssertEqual(topo.roleCounts["NOTE"], 2)
    }

    // MARK: baselineTopology

    func test_baselineTopology() {
        let t = baselineTopology(["HEADING_1": 13, "HEADING_3": 208, "BODY": 2261, "NOTE": 1454])
        XCTAssertEqual(t.nodeTotal, 13 + 208 + 2261 + 1454)
        XCTAssertEqual(t.headingCountsByLevel, ["HEADING_1": 13, "HEADING_3": 208])
        XCTAssertFalse(t.maxDepthKnown)
    }

    // MARK: buildStructuralComparison — well-formedness

    private func wellFormedDoc() -> ScabopdfDocument {
        makeDoc([node("n0", .HEADING_1), node("n1", .BODY), node("n2", .NOTE)])
    }

    /// TS: "produces a well-formed report with a baseline".
    func test_build_withBaseline() {
        let report = buildStructuralComparison(
            document: wellFormedDoc(),
            fixtureSlug: "demo",
            corpusId: "demo_corpus",
            baselineFile: "demo_baseline.json",
            baselineCategoryCounts: ["HEADING_1": 1, "BODY": 1, "NOTE": 1, "CROSS_REFERENCE": 5]
        )
        XCTAssertEqual(report.schemaVersion, STRUCTURAL_COMPARISON_SCHEMA_VERSION)
        XCTAssertTrue(report.baselineAvailable)
        XCTAssertNotNil(report.topologyBaseline)
        XCTAssertEqual(report.producedSummary.withinTolerance, true)
        XCTAssertEqual(report.producedSummary.maxRelDelta, 0)
        XCTAssertEqual(report.producedSummary.relTolerance, STRUCTURAL_REL_TOLERANCE)
    }

    /// TS: "produces a one-sided report without a baseline".
    func test_build_withoutBaseline() {
        let report = buildStructuralComparison(
            document: wellFormedDoc(),
            fixtureSlug: "demo",
            corpusId: "demo_corpus",
            baselineFile: nil,
            baselineCategoryCounts: nil
        )
        XCTAssertFalse(report.baselineAvailable)
        XCTAssertNil(report.topologyBaseline)
        XCTAssertNil(report.producedSummary.withinTolerance)
        XCTAssertTrue(report.categories.allSatisfy { $0.band == .NOT_COMPARABLE })
    }

    /// TS: "flags divergence when the Generic count is far from the baseline".
    func test_build_flagsDivergence() {
        let report = buildStructuralComparison(
            document: wellFormedDoc(),
            fixtureSlug: "demo",
            corpusId: "demo_corpus",
            baselineFile: "demo.json",
            baselineCategoryCounts: ["HEADING_1": 50, "BODY": 1, "NOTE": 1]
        )
        XCTAssertEqual(report.producedSummary.withinTolerance, false)
        XCTAssertEqual(report.categories.first { $0.category == .HEADING_1 }?.band, .DIVERGENT)
    }

    // MARK: comparisonForCapture — skip and run

    /// TS: "skips with an explicit message when the fixture is missing".
    func test_comparison_skipMissing() {
        let outcome = comparisonForCapture(
            fixtureSlug: "missing_fixture",
            corpusId: "x",
            baselineFile: nil,
            capture: nil,
            baselineCategoryCounts: nil
        )
        guard case .skipped(_, let reason) = outcome else {
            return XCTFail("expected skipped")
        }
        XCTAssertNotNil(reason.range(of: "not seeded"))
        XCTAssertNotNil(reason.range(of: "LAYER2_TEST_FRAMEWORK.md"))
    }

    /// TS: "runs the real Generic pipeline over a present capture".
    func test_comparison_runsOverCapture() throws {
        let outcome = comparisonForCapture(
            fixtureSlug: "synthetic",
            corpusId: "synthetic_corpus",
            baselineFile: "synthetic.json",
            capture: try exampleCapture(),
            baselineCategoryCounts: ["HEADING_1": 1, "BODY": 1, "NOTE": 1]
        )
        guard case .compared(let report) = outcome else {
            return XCTFail("expected compared")
        }
        XCTAssertEqual(report.topologyGeneric.nodeTotal, 3)
        XCTAssertEqual(report.producedSummary.withinTolerance, true)
    }

    // MARK: corpusBaselines registry

    /// TS: "covers the seven seeded fixtures with unique slugs".
    func test_registry_sevenUniqueSlugs() {
        let slugs = CORPUS_BASELINES.map { $0.captureSlug }
        XCTAssertEqual(slugs.count, 7)
        XCTAssertEqual(Set(slugs).count, 7)
    }

    /// TS: "every entry either points to a baseline file or documents its absence".
    func test_registry_baselineOrNote() {
        for e in CORPUS_BASELINES {
            if e.baselineFile == nil {
                XCTAssertNotEqual(e.note ?? "", "")
            } else {
                XCTAssertNotNil(e.baselineFile?.range(of: "\\.json$", options: .regularExpression))
            }
        }
    }

    /// TS: "resolves a known slug and rejects an unknown one".
    func test_registry_resolveSlug() {
        XCTAssertEqual(corpusEntryForSlug("manuale_del_marrone_pdf")?.corpusId, "marrone")
        XCTAssertNil(corpusEntryForSlug("nope"))
    }

    /// TS: "extractCategoryCounts reads category_counts and ignores digest-only baselines".
    func test_registry_extractCategoryCounts() {
        XCTAssertEqual(
            extractCategoryCounts(["category_counts": ["BODY": 3, "NOTE": 2]]),
            ["BODY": 3, "NOTE": 2]
        )
        XCTAssertNil(extractCategoryCounts(["matches_score_digest": "abc"]))
        XCTAssertNil(extractCategoryCounts(nil as Any?))
    }

    // MARK: end-to-end on REAL committed Layer-1 baselines (OGGI analog of the
    // integration generator; the true Generic-vs-Layer1 form needs on-device
    // captures and is banda POST-MAC).

    /// Exercises documentTopology + buildStructuralComparison on a real baseline
    /// tree (self-comparison: the framework walks a real deep tree, every produced
    /// category is EXACT against its own counts → within tolerance).
    func test_endToEnd_realBaseline_selfConsistent() throws {
        let doc = try loadBaselineDocument("xml_akn_baseline_legge_capitali.json")
        let topo = documentTopology(doc)
        XCTAssertGreaterThan(topo.nodeTotal, 0)
        let report = buildStructuralComparison(
            document: doc,
            fixtureSlug: "legge_capitali",
            corpusId: "xml_akn",
            baselineFile: "xml_akn_baseline_legge_capitali.json",
            baselineCategoryCounts: topo.roleCounts
        )
        XCTAssertTrue(report.baselineAvailable)
        XCTAssertEqual(report.producedSummary.withinTolerance, true)
        XCTAssertEqual(report.producedSummary.maxRelDelta, 0)
        for c in report.categories {
            XCTAssertEqual(c.absDelta, abs(c.generic - c.baseline))
        }
    }

    /// Exercises extractCategoryCounts on a real committed p014 baseline (the
    /// NSNumber JSONSerialization path) and feeds it into a well-formed comparison
    /// against a real Layer-1 document (the on-device-capture side is POST-MAC).
    func test_endToEnd_realCategoryCounts_extractAndCompare() throws {
        let url = SNAPSHOTS_DIR.appendingPathComponent("p014_baseline_marrone.json")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("p014_baseline_marrone.json not present under pipeline/tests/snapshots/")
        }
        let data = try Data(contentsOf: url)
        let parsed = try JSONSerialization.jsonObject(with: data)
        let counts = extractCategoryCounts(parsed)
        XCTAssertNotNil(counts)
        XCTAssertGreaterThan(counts?.count ?? 0, 0)

        let doc = try loadBaselineDocument("xml_akn_baseline_legge_capitali.json")
        let report = buildStructuralComparison(
            document: doc,
            fixtureSlug: "marrone",
            corpusId: "marrone",
            baselineFile: "p014_baseline_marrone.json",
            baselineCategoryCounts: counts
        )
        XCTAssertTrue(report.baselineAvailable)
        XCTAssertGreaterThan(report.topologyGeneric.nodeTotal, 0)
        for c in report.categories {
            XCTAssertEqual(c.absDelta, abs(c.generic - c.baseline))
        }
    }
}
