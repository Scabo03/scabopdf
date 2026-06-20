//
//  GranularityWiringTests.swift
//  ScaboAppTests
//
//  BANCO DI PROVA (sentiero INDICE, primo blocco app) — Mattone C end-to-end.
//
//  Test OSPITATO nel target app: gira sul Simulator (incluso iPad) via
//  `xcodebuild test`, ed esercita il cablaggio reale `ContinuousBodyBuilder`
//  (ScaboApp) → `granularizeBody` (ScaboCore) ai QUATTRO livelli di granularità
//  (§ 7.7). Verifica la STRUTTURA del corpo paginato esposto alla reading view —
//  non la resa vocale di VoiceOver (quella la certifica lo sviluppatore su
//  dispositivo fisico). Complementare ai test puri di ScaboCore
//  (`GranularityLevelTests`): qui il documento attraversa il builder dell'app.
//
//  Nota di banco: NON serve un PDF copyright né il document-picker (l'import reale
//  via picker resta XCUITest da finalizzare con l'Info.plist di produzione e su
//  Mac vero). Si costruisce un `ScabopdfDocument` di corpo discorsivo lungo e si
//  misura come i quattro livelli lo riassemblano.
//

import XCTest
@testable import ScaboApp
import ScaboCore

final class GranularityWiringTests: XCTestCase {

    /// Un documento con un solo nodo BODY discorsivo lungo (~8000 char di frasi
    /// corte), il caso che il motore §7.6 deve riassemblare a blocchi ~target.
    private func longBodyDocument() -> ScabopdfDocument {
        let sentence = "Questa e una frase di corpo discorsivo."  // ~39 char
        let text = Array(repeating: sentence, count: 200).joined(separator: " ")
        return ScabopdfDocument(
            schema_version: SUPPORTED_SCHEMA_VERSION,
            document_id: "bench_granularity",
            metadata: DocumentMetadata(
                pages_pdf: 1, page_size_pt: [0, 0], source_pdf_filename: "bench.pdf"),
            profile: DocumentProfileDict(
                profile_id: "generic", editorial_family: "generic",
                genre: "unknown", confidence: 0.05),
            warnings: [],
            transformations: [],
            structure: [NodeDict(id: "node_0", type: .BODY, page_index: 0, text: text)]
        )
    }

    /// Ogni livello rispetta il proprio target (frasi corte → nessun blocco lo
    /// supera) e i livelli grossi producono MENO segmenti dei fini: la scelta dei
    /// quattro valori cambia davvero la granularità esposta.
    func test_bodySegments_atFourLevels_respectTargetAndAreMonotone() {
        let doc = longBodyDocument()
        var counts: [GranularityLevel: Int] = [:]
        for level in GranularityLevel.allCases {
            let segs = ContinuousBodyBuilder.bodySegments(from: doc, granularity: level)
            XCTAssertFalse(segs.isEmpty, "livello \(level.rawValue): produce segmenti")
            for s in segs where s.role == SemanticCategory.BODY.rawValue {
                XCTAssertLessThanOrEqual(
                    s.text.count, level.target,
                    "livello \(level.rawValue): nessun blocco di corpo supera il target")
            }
            counts[level] = segs.count
        }
        XCTAssertGreaterThan(
            counts[.fine]!, counts[.veryCoarse]!,
            "fine (400) spezza in più segmenti della molto grossa (1200)")
        XCTAssertGreaterThanOrEqual(counts[.fine]!, counts[.medium]!)
        XCTAssertGreaterThanOrEqual(counts[.medium]!, counts[.coarse]!)
        XCTAssertGreaterThanOrEqual(counts[.coarse]!, counts[.veryCoarse]!)
    }

    /// Il contenuto PAGINATO (ciò che la reading view consuma) si costruisce a ogni
    /// livello senza errori, ed esce non vuoto: il cablaggio fino alla view regge.
    func test_paginatedContent_buildsAtEveryLevel() throws {
        let doc = longBodyDocument()
        for level in GranularityLevel.allCases {
            let content = try ContinuousBodyBuilder.bodyPaginatedContent(
                from: doc, granularity: level)
            XCTAssertGreaterThan(
                content.pages.count, 0, "livello \(level.rawValue): pagine non vuote")
        }
    }

    /// Il default del builder (senza livello esplicito) coincide col livello fine:
    /// chi non sceglie ottiene esattamente il comportamento preesistente (400).
    func test_defaultBuilder_matchesFineLevel() {
        let doc = longBodyDocument()
        let byDefault = ContinuousBodyBuilder.bodySegments(from: doc).map(\.text)
        let byFine = ContinuousBodyBuilder.bodySegments(from: doc, granularity: .fine).map(\.text)
        XCTAssertEqual(byDefault, byFine,
            "il default invariato == livello fine: nessuna regressione per chi non sceglie")
    }
}
