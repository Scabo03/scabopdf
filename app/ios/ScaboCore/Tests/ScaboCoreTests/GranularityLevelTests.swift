//
//  GranularityLevelTests.swift
//  ScaboCoreTests
//
//  Mattone C (sentiero INDICE, primo blocco app): esposizione dei quattro livelli
//  di granularità di lettura (§ 7.7) come vocabolario chiuso + persistenza globale
//  e override per-documento. Logica pura ScaboCore: gira nel `swift test` macOS.
//
//  Pinano: i quattro target (400/600/900/1200); il default = fine/400 (NON cambia
//  il comportamento preesistente); la persistenza con collasso al default su valore
//  mancante/invalido; l'override per-documento con fallback a globale poi a default;
//  e che `granularizeBody` rispetti il target di ciascun livello (blocchi più grossi
//  ai livelli grossi, mai a cavallo di una frase).
//

import XCTest
@testable import ScaboCore

final class GranularityLevelTests: XCTestCase {

    // MARK: - Vocabolario chiuso e target

    func test_fourLevels_mapToTheFourTargets() {
        XCTAssertEqual(GranularityLevel.fine.target, 400)
        XCTAssertEqual(GranularityLevel.medium.target, 600)
        XCTAssertEqual(GranularityLevel.coarse.target, 900)
        XCTAssertEqual(GranularityLevel.veryCoarse.target, 1200)
    }

    func test_closedVocabulary_hasExactlyFourCases() {
        XCTAssertEqual(GranularityLevel.allCases.count, 4)
        XCTAssertEqual(Set(GranularityLevel.allCases.map { $0.rawValue }),
                       ["400", "600", "900", "1200"])
    }

    func test_default_isFine_andMatchesLegacyTarget() {
        XCTAssertEqual(DEFAULT_GRANULARITY_LEVEL, .fine)
        XCTAssertEqual(DEFAULT_GRANULARITY_LEVEL.target, DEFAULT_GRANULARITY_TARGET)
        XCTAssertEqual(DEFAULT_GRANULARITY_TARGET, 400)
    }

    func test_rawValue_roundTrips() {
        for level in GranularityLevel.allCases {
            XCTAssertEqual(GranularityLevel(rawValue: level.rawValue), level)
        }
        XCTAssertNil(GranularityLevel(rawValue: "777"))
        XCTAssertNil(GranularityLevel(rawValue: ""))
    }

    // MARK: - Persistenza globale

    func test_globalGranularity_absentOrInvalid_collapsesToDefault() {
        let store = InMemoryKeyValueStore()
        XCTAssertEqual(getStoredGranularityLevel(store), DEFAULT_GRANULARITY_LEVEL)
        store.setItem(PreferenceKeys.granularityLevel, "999")
        XCTAssertEqual(getStoredGranularityLevel(store), DEFAULT_GRANULARITY_LEVEL,
                       "un valore fuori vocabolario collassa al default")
    }

    func test_globalGranularity_setThenGet_roundTrips() {
        let store = InMemoryKeyValueStore()
        for level in GranularityLevel.allCases {
            setStoredGranularityLevel(store, level)
            XCTAssertEqual(getStoredGranularityLevel(store), level)
        }
    }

    // MARK: - Override per-documento (§ 7.7)

    func test_perDocument_overridesGlobal_andFallsBack() {
        let store = InMemoryKeyValueStore()
        // niente impostato → default
        XCTAssertEqual(getDocumentGranularityLevel(store, documentId: "marotta"),
                       DEFAULT_GRANULARITY_LEVEL)
        // globale impostato, doc no → eredita il globale
        setStoredGranularityLevel(store, .medium)
        XCTAssertEqual(getDocumentGranularityLevel(store, documentId: "marotta"), .medium)
        // override per-doc → vince sul globale, ma solo per quel documento
        setDocumentGranularityLevel(store, documentId: "marotta", .veryCoarse)
        XCTAssertEqual(getDocumentGranularityLevel(store, documentId: "marotta"), .veryCoarse)
        XCTAssertEqual(getDocumentGranularityLevel(store, documentId: "torrente"), .medium,
                       "l'override è scoped al documento, gli altri ereditano il globale")
    }

    func test_perDocument_invalidValue_fallsBackToGlobal() {
        let store = InMemoryKeyValueStore()
        setStoredGranularityLevel(store, .coarse)
        store.setItem(PreferenceKeys.documentGranularityLevel("x"), "abc")
        XCTAssertEqual(getDocumentGranularityLevel(store, documentId: "x"), .coarse)
    }

    // MARK: - Il motore §7.6 rispetta il target di ogni livello

    /// Corpo discorsivo lungo, fatto di frasi corte (~30 char), così il packing è
    /// libero di riempire fino al target a ogni livello senza incontrare una frase
    /// più lunga del target.
    private func longBody() -> [ContentSegment] {
        let sentence = "Questa e una frase di corpo discorsivo." // ~39 char, < 400
        let text = Array(repeating: sentence, count: 120).joined(separator: " ")
        return [ContentSegment(id: "n0", role: SemanticCategory.BODY.rawValue,
                               text: text, lengthCategory: "", acousticIntro: "")]
    }

    func test_eachLevel_blocksRespectItsTarget() {
        let body = longBody()
        for level in GranularityLevel.allCases {
            let blocks = granularizeBody(body, target: level.target)
            XCTAssertFalse(blocks.isEmpty, "livello \(level.rawValue): produce blocchi")
            for b in blocks {
                XCTAssertLessThanOrEqual(
                    b.text.count, level.target,
                    "livello \(level.rawValue): nessun blocco supera il target (frasi corte)")
            }
        }
    }

    func test_coarserLevel_yieldsFewerBlocks() {
        let body = longBody()
        let fine = granularizeBody(body, target: GranularityLevel.fine.target).count
        let coarse = granularizeBody(body, target: GranularityLevel.veryCoarse.target).count
        XCTAssertGreaterThan(fine, coarse,
            "granularità fine (400) spezza in più blocchi della molto grossa (1200)")
    }
}
