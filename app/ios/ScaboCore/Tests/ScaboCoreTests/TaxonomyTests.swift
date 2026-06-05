//
//  TaxonomyTests.swift
//  ScaboCoreTests
//
//  PART A — XCTest translation of the TS oracle `app/src/plugins/__tests__/
//  taxonomy.test.ts` (228 LOC). One-to-one with each TS test.
//
//  The TS reads the Layer 1 enum from the committed schema at runtime; the Swift
//  equivalent is `SemanticCategory.allCases`, itself the verbatim mirror of
//  `shared/schema.json` $defs.SemanticCategory (translated in Fase 1). Pinning
//  the taxonomy against it gives the same guarantee: a future enum change not
//  mirrored in the taxonomy fails this suite.
//

import XCTest
@testable import ScaboCore

final class TaxonomyTests: XCTestCase {

    private let layer1 = Set(SemanticCategory.allCases)

    // MARK: alignment with Layer 1

    /// TS: "taxonomy keys are exactly the Layer 1 SemanticCategory enum".
    func test_keys_areExactlyLayer1Enum() {
        XCTAssertEqual(Set(GENERIC_TAXONOMY.keys), layer1)
        XCTAssertEqual(GENERIC_TAXONOMY_ENTRIES.count, SemanticCategory.allCases.count)
    }

    /// TS: "every entry.category equals its map key".
    func test_everyEntryCategory_equalsItsKey() {
        for (key, entry) in GENERIC_TAXONOMY {
            XCTAssertEqual(entry.category, key)
        }
    }

    // MARK: coverage well-formedness

    /// TS: "produced and detected-suppressed entries document at least one signal".
    func test_producedAndSuppressed_haveAtLeastOneSignal() {
        for entry in GENERIC_TAXONOMY_ENTRIES where entry.coverage == .produced || entry.coverage == .detectedSuppressed {
            XCTAssertGreaterThan(entry.signals.count, 0)
        }
    }

    /// TS: "reserved entries carry no signal".
    func test_reserved_haveNoSignal() {
        for entry in GENERIC_TAXONOMY_ENTRIES where entry.coverage == .reserved {
            XCTAssertEqual(entry.signals.count, 0)
        }
    }

    /// TS: "every entry has a non-empty rationale".
    func test_everyEntry_hasNonEmptyRationale() {
        for entry in GENERIC_TAXONOMY_ENTRIES {
            XCTAssertGreaterThan(entry.rationale.trimmingCharacters(in: .whitespacesAndNewlines).count, 0)
        }
    }

    // MARK: the produced closed set

    /// TS: "produced is exactly the six categories the Generic emits".
    func test_producedSet_isTheSixCategories() {
        XCTAssertEqual(
            GENERIC_PRODUCED_CATEGORIES,
            [.HEADING_1, .HEADING_2, .HEADING_3, .HEADING_4, .BODY, .NOTE]
        )
    }

    /// TS: "isGenericProduced agrees with the produced set".
    func test_isGenericProduced_agreesWithSet() {
        for category in SemanticCategory.allCases {
            XCTAssertEqual(isGenericProduced(category), GENERIC_PRODUCED_CATEGORIES.contains(category))
        }
    }

    // MARK: the three buckets partition the enum

    /// TS: "disjoint and exhaustive".
    func test_threeBuckets_partitionTheEnum() {
        let produced = GENERIC_PRODUCED_CATEGORIES
        let detected = GENERIC_DETECTED_SUPPRESSED_CATEGORIES
        let reserved = GENERIC_RESERVED_CATEGORIES

        // Disjoint.
        XCTAssertTrue(produced.isDisjoint(with: detected))
        XCTAssertTrue(produced.isDisjoint(with: reserved))
        XCTAssertTrue(detected.isDisjoint(with: reserved))

        // Exhaustive.
        let union = produced.union(detected).union(reserved)
        XCTAssertEqual(union, layer1)
        XCTAssertEqual(union.count, SemanticCategory.allCases.count)
    }

    // MARK: Layer-2 presentation-only roles

    /// TS: "SECTION_DIVIDER is not a Layer 1 SemanticCategory".
    func test_presentationOnlyRoles_areNotLayer1Categories() {
        for role in LAYER2_PRESENTATION_ONLY_ROLES {
            XCTAssertNil(SemanticCategory(rawValue: role))
        }
    }

    // MARK: behaviour — the Generic only ever emits `produced` categories

    private func line(_ text: String, size: Double = 12, bold: Bool = false, color: String = "#000000") -> PdfTextLine {
        PdfTextLine(
            spans: [PdfSpan(text: text, fontSize: size, bold: bold, italic: false, color: color,
                            bbox: BBox(x: 0, y: 0, width: 0, height: 0))],
            bbox: BBox(x: 0, y: 0, width: 0, height: 0)
        )
    }

    private func extraction(_ pages: [[PdfTextLine]]) -> PdfExtraction {
        PdfExtraction(
            version: 2,
            pageCount: pages.count,
            pages: pages.enumerated().map { idx, lines in
                PdfPageExtraction(pageIndex: idx, width: 595, height: 842, lines: lines)
            }
        )
    }

    private func everyNodeType(_ nodes: [NodeDict], _ acc: inout Set<SemanticCategory>) {
        for node in nodes {
            acc.insert(node.type)
            everyNodeType(node.children, &acc)
        }
    }

    /// TS: "a mixed document … stays in the closed set".
    func test_mixedDocument_staysInProducedSet() {
        let doc = buildDocumentFromPdf(
            extraction([[
                line("Titolo Grande", size: 24, bold: true),
                line("Sottotitolo medio", size: 16, bold: true),
                line("Sezione minore", size: 14, bold: true),
                line("Intestazione colorata", size: 12, bold: false, color: "#1a7f37"),
                line("Questo è il corpo del testo che domina per conteggio righe."),
                line("Seconda riga di corpo per consolidare la stima di body size."),
                line("Terza riga di corpo del testo normale a dodici punti."),
                line("Quarta riga di corpo del testo normale a dodici punti."),
                line("1 una nota a piè di pagina molto più piccola del corpo.", size: 8),
            ]]),
            sourceName: "misto.pdf"
        )
        var types: Set<SemanticCategory> = []
        everyNodeType(doc.structure, &types)
        XCTAssertGreaterThan(types.count, 0)
        for type in types {
            XCTAssertTrue(GENERIC_PRODUCED_CATEGORIES.contains(type))
        }
    }

    /// TS: "a body-only document never emits a reserved or suppressed category".
    func test_bodyOnlyDocument_noReservedOrSuppressed() {
        let doc = buildDocumentFromPdf(
            extraction([(1...8).map { line("Riga \($0) di puro corpo del testo, dodici punti, nera.") }]),
            sourceName: "corpo.pdf"
        )
        var types: Set<SemanticCategory> = []
        everyNodeType(doc.structure, &types)
        for type in types {
            XCTAssertFalse(GENERIC_RESERVED_CATEGORIES.contains(type))
            XCTAssertFalse(GENERIC_DETECTED_SUPPRESSED_CATEGORIES.contains(type))
        }
    }
}
