//
//  ReadingModelTests.swift
//  ScaboCoreTests
//
//  XCTest translation of `app/src/rendering/__tests__/readingModel.test.ts` (117
//  LOC). The Q1 read-once model, validated against the REAL Layer 1 baselines.
//  The AKN topology nests AMENDMENT/QUOTED_TEXT children whose text is a verbatim
//  substring of the parent; the model must voice every character exactly once (no
//  2-3x re-reading) while skipping nothing.
//
//  Length note (language difference, Piano § 4). The TS measures `.length` in
//  UTF-16 code units; here `.count` is grapheme clusters. Both sides of every
//  comparison are counted the same way, so the ratios match; the one exact-
//  equality test (codice_civile) holds because the flat document's partition
//  emits each node's text verbatim with no trimming or subtraction, making
//  emitted == naive in any consistent unit.
//

import XCTest
@testable import ScaboCore

final class ReadingModelTests: XCTestCase {

    /// The naive pre-Q1 behaviour: one segment per text-bearing node, verbatim.
    private func naiveCharCount(_ doc: ScabopdfDocument) -> Int {
        var chars = 0
        walkTree(doc.structure) { node, _, _ in
            if let t = node.text { chars += t.count }
        }
        return chars
    }

    private func leafTexts(_ doc: ScabopdfDocument) -> [String] {
        var leaves: [String] = []
        walkTree(doc.structure) { node, _, _ in
            if node.children.isEmpty, let t = node.text {
                let trimmed = t.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { leaves.append(trimmed) }
            }
        }
        return leaves
    }

    private func findNode(_ nodes: [NodeDict], _ pred: (NodeDict) -> Bool) -> NodeDict? {
        for n in nodes {
            if pred(n) { return n }
            if let inChild = findNode(n.children, pred) { return inChild }
        }
        return nil
    }

    /// TS: "dlgs_cartabia: verbatim duplication is removed (worst-case doc)".
    func test_dlgsCartabia_duplicationRemoved() throws {
        let doc = try loadBaselineDocument("xml_akn_baseline_dlgs_cartabia.json")
        let segs = buildBaseSegments(doc)
        let emitted = segs.reduce(0) { $0 + $1.text.count }
        let naive = naiveCharCount(doc)
        // Measured ~39% reduction; assert a substantial drop so a regression that
        // reintroduces parent/child re-reading fails here.
        XCTAssertLessThan(Double(emitted), Double(naive) * 0.75)
    }

    /// TS: "legge_capitali: a nested QUOTED_TEXT_NEW is never re-read inside a parent".
    func test_leggeCapitali_quotedTextReadOnce() throws {
        let doc = try loadBaselineDocument("xml_akn_baseline_legge_capitali.json")
        let quoted = findNode(doc.structure) {
            $0.type == .QUOTED_TEXT_NEW && ($0.text?.count ?? 0) > 200
        }
        XCTAssertNotNil(quoted)
        let qText = quoted!.text!
        let segs = buildBaseSegments(doc)

        // The quoted text is emitted exactly once as its own segment...
        XCTAssertEqual(segs.filter { $0.text == qText }.count, 1)
        // ...and never embedded inside its parent chain (ARTICLE_BODY / AMENDMENT).
        let embeddedInParentChain = segs.filter {
            ($0.role == "ARTICLE_BODY" || $0.role == "AMENDMENT")
                && $0.text.count > qText.count
                && $0.text.range(of: qText) != nil
        }
        XCTAssertEqual(embeddedInParentChain, [])
    }

    /// TS: "nothing is skipped: every leaf text still appears in the stream".
    func test_leggeCapitali_nothingSkipped() throws {
        let doc = try loadBaselineDocument("xml_akn_baseline_legge_capitali.json")
        let segs = buildBaseSegments(doc)
        let haystack = segs.map { $0.text }.joined(separator: "\n")
        for leaf in leafTexts(doc) {
            XCTAssertNotNil(haystack.range(of: leaf), "missing leaf: \(leaf.prefix(60))")
        }
    }

    /// TS: "modification roles survive to the segment stream (distinct from body)".
    func test_leggeCapitali_modificationRolesSurvive() throws {
        let doc = try loadBaselineDocument("xml_akn_baseline_legge_capitali.json")
        let roles = Set(buildBaseSegments(doc).map { $0.role })
        for r in ["ARTICLE_BODY", "AMENDMENT", "QUOTED_TEXT_NEW", "QUOTED_TEXT_OLD", "UPDATE_BLOCK"] {
            XCTAssertTrue(roles.contains(r), r)
        }
    }

    /// TS: "flat document (codice_civile) is unchanged — no over-subtraction".
    func test_codiceCivile_flatUnchanged() throws {
        let doc = try loadBaselineDocument("xml_akn_baseline_codice_civile.json")
        let emitted = buildBaseSegments(doc).reduce(0) { $0 + $1.text.count }
        XCTAssertEqual(emitted, naiveCharCount(doc))
    }
}
