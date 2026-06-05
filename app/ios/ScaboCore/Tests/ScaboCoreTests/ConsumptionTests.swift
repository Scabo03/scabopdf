//
//  ConsumptionTests.swift
//  ScaboCoreTests
//
//  XCTest translation of the TypeScript oracle
//  `app/src/consumption/__tests__/consumption.test.ts` (157 LOC).
//
//  Golden rule (Piano § 4): the logic is considered translated only when these
//  XCTests reproduce the behaviour the TS test asserts. Each test below names
//  the TS `describe`/`test` it mirrors. The behavioural divergences inherent to
//  the decode-based validator are documented in `DocumentValidation.swift` and
//  in the two tests that exercise the validator (they assert only what the TS
//  asserts: presence of a failure, with a location and a message).
//
//  Input-shape note: the TS `parseDocument(object)` case is reproduced here by
//  encoding the equivalent typed value to JSON `Data` and parsing that — Swift
//  has no untyped "already-parsed object" to pass. The behaviour under test is
//  identical.
//

import XCTest
@testable import ScaboCore

final class ConsumptionTests: XCTestCase {

    // Mirrors `makeValidDoc()` in consumption.test.ts.
    private func makeValidDoc() -> ScabopdfDocument {
        ScabopdfDocument(
            schema_version: "0.7.0",
            document_id: "123e4567-e89b-12d3-a456-426614174000",
            metadata: DocumentMetadata(
                pages_pdf: 2,
                page_size_pt: [595, 842],
                source_pdf_filename: "esempio.pdf"
            ),
            profile: DocumentProfileDict(
                profile_id: "unknown_generic",
                editorial_family: "unknown",
                genre: "unknown",
                confidence: 0.0
            ),
            warnings: ["plugin:test:demo_warning"],
            structure: [
                NodeDict(
                    id: "node_0",
                    type: .HEADING_1,
                    page_index: 0,
                    text: "Titolo",
                    level: 1,
                    children: [
                        NodeDict(id: "node_1", type: .BODY, page_index: 0, text: "Corpo"),
                        NodeDict(
                            id: "node_2",
                            type: .NOTE,
                            page_index: 0,
                            text: "(1) una nota",
                            length_category: .SHORT
                        ),
                    ]
                ),
                NodeDict(id: "node_3", type: .BODY, page_index: 1, text: "Altro corpo"),
            ]
        )
    }

    private func encode(_ document: ScabopdfDocument) -> Data {
        // Force-try is acceptable in a test: a failure here is a test bug, not a
        // production path.
        try! JSONEncoder().encode(document)
    }

    // MARK: - validateAgainstSchema

    /// TS: validateAgainstSchema "accepts a conforming document".
    func test_validate_acceptsConformingDocument() {
        XCTAssertEqual(validateAgainstSchema(encode(makeValidDoc())), [])
    }

    /// TS: validateAgainstSchema "reports failures for a missing required field".
    /// The `metadata` object omits the required `pages_pdf`.
    func test_validate_reportsMissingRequiredField() {
        let broken = """
        {
          "schema_version": "0.7.0",
          "document_id": "123e4567-e89b-12d3-a456-426614174000",
          "metadata": { "page_size_pt": [595, 842], "source_pdf_filename": "x.pdf" },
          "profile": { "profile_id": "unknown_generic", "editorial_family": "unknown", "genre": "unknown", "confidence": 0.0 }
        }
        """
        let errors = validateAgainstSchema(broken)
        XCTAssertGreaterThan(errors.count, 0)
        // TS asserts errors[0] has a `location` and a `message`; assert both present.
        XCTAssertFalse(errors[0].location.isEmpty)
        XCTAssertFalse(errors[0].message.isEmpty)
    }

    /// TS: validateAgainstSchema "reports failures for an out-of-vocabulary node type".
    func test_validate_reportsOutOfVocabularyType() {
        let broken = """
        {
          "schema_version": "0.7.0",
          "document_id": "123e4567-e89b-12d3-a456-426614174000",
          "metadata": { "pages_pdf": 2, "page_size_pt": [595, 842], "source_pdf_filename": "esempio.pdf" },
          "profile": { "profile_id": "unknown_generic", "editorial_family": "unknown", "genre": "unknown", "confidence": 0.0 },
          "structure": [{ "id": "node_0", "type": "NOT_A_CATEGORY", "page_index": 0 }]
        }
        """
        XCTAssertGreaterThan(validateAgainstSchema(broken).count, 0)
    }

    // MARK: - parseDocument

    /// TS: parseDocument "parses a valid object and surfaces warnings".
    /// (Object input reproduced as encoded Data — see file header.)
    func test_parse_validValueSurfacesWarnings() {
        let result = parseDocument(encode(makeValidDoc()))
        guard case .success(let document, let warnings) = result else {
            return XCTFail("expected success")
        }
        XCTAssertEqual(document.profile.profile_id, "unknown_generic")
        XCTAssertEqual(warnings, ["plugin:test:demo_warning"])
    }

    /// TS: parseDocument "parses a valid JSON string".
    func test_parse_validJSONString() {
        let json = String(data: encode(makeValidDoc()), encoding: .utf8)!
        XCTAssertTrue(parseDocument(json).isOk)
    }

    /// TS: parseDocument "rejects non-JSON input with an accessible message".
    func test_parse_rejectsNonJSON() {
        let result = parseDocument("{ this is not json")
        guard case .failure(.invalidJSON(let message)) = result else {
            return XCTFail("expected invalidJSON")
        }
        XCTAssertTrue(message.contains("ScaboPDF"))
    }

    /// TS: parseDocument "rejects an unsupported schema version with a clear message".
    func test_parse_rejectsUnsupportedVersion() {
        var doc = makeValidDoc()
        doc.schema_version = "0.8.0"
        let result = parseDocument(encode(doc))
        guard case .failure(.unsupportedVersion(let message, let foundVersion)) = result else {
            return XCTFail("expected unsupportedVersion error")
        }
        XCTAssertEqual(foundVersion, "0.8.0")
        XCTAssertTrue(message.contains("0.8.0"))
    }

    /// TS: parseDocument "rejects a structurally invalid document".
    /// (`metadata` omits the required `pages_pdf`; version is supported so the
    /// failure is structural, not a version mismatch.)
    func test_parse_rejectsStructurallyInvalid() {
        let broken = """
        {
          "schema_version": "0.7.0",
          "document_id": "123e4567-e89b-12d3-a456-426614174000",
          "metadata": { "page_size_pt": [1, 2], "source_pdf_filename": "x.pdf" },
          "profile": { "profile_id": "unknown_generic", "editorial_family": "unknown", "genre": "unknown", "confidence": 0.0 }
        }
        """
        let result = parseDocument(broken)
        guard case .failure(.schemaValidation(_, let errors)) = result else {
            return XCTFail("expected schemaValidation error")
        }
        XCTAssertGreaterThan(errors.count, 0)
    }

    // MARK: - traversal

    /// TS: traversal "flattenToReadingOrder yields pre-order sequence".
    func test_flatten_preOrderSequence() {
        let ids = flattenToReadingOrder(makeValidDoc()).map { $0.id }
        XCTAssertEqual(ids, ["node_0", "node_1", "node_2", "node_3"])
    }

    /// TS: traversal "walkTree reports correct depth and parent".
    func test_walkTree_depthAndParent() {
        struct Visit: Equatable { let id: String; let depth: Int; let parent: String? }
        var seen: [Visit] = []
        walkTree(makeValidDoc().structure) { node, depth, parent in
            seen.append(Visit(id: node.id, depth: depth, parent: parent?.id))
        }
        XCTAssertEqual(seen, [
            Visit(id: "node_0", depth: 0, parent: nil),
            Visit(id: "node_1", depth: 1, parent: "node_0"),
            Visit(id: "node_2", depth: 1, parent: "node_0"),
            Visit(id: "node_3", depth: 0, parent: nil),
        ])
    }

    /// TS: traversal "handles a document with no structure".
    func test_flatten_noStructure() {
        var doc = makeValidDoc()
        doc.structure = []
        XCTAssertEqual(flattenToReadingOrder(doc), [])
    }

    /// TS: traversal "exposes NodeDict typing for consumers".
    func test_nodeDict_typing() {
        let node = NodeDict(id: "node_9", type: .BODY, page_index: 0)
        XCTAssertEqual(node.type, .BODY)
    }
}
