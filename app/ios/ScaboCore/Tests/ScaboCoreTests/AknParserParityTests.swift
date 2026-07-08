//
//  AknParserParityTests.swift
//  ScaboCoreTests
//
//  Parità del parser AKN Swift contro i 13 baseline N-* committati (prodotti dal
//  backend Python xml_akn, l'oracolo). Per ogni atto: parse dell'XML sorgente →
//  ScabopdfDocument, confronto strutturale con la baseline (Equatable, ignorando
//  document_id). Su mismatch stampa la prima differenza per iterare.
//

import XCTest
@testable import ScaboCore

final class AknParserParityTests: XCTestCase {

    private var fixturesDir: URL {
        SNAPSHOTS_DIR.deletingLastPathComponent().appendingPathComponent("fixtures")
    }

    private let cases: [(group: String, name: String)] = [
        ("normattiva_calibration", "legge_56_2007"),
        ("normattiva_calibration", "legge_gelli_bianco"),
        ("normattiva_calibration", "dlgs_231_2001"),
        ("normattiva_calibration", "legge_bilancio_2023"),
        ("normattiva_calibration", "codice_strada"),
        ("normattiva_calibration", "codice_procedura_penale"),
        ("normattiva_calibration", "tuf_dlgs_58_1998"),
        ("normattiva_calibration", "codice_civile"),
        ("normattiva_exploration", "codice_penale"),
        ("normattiva_exploration", "legge_capitali"),
        ("normattiva_exploration", "dl_rilancio"),
        ("normattiva_exploration", "dlgs_cartabia"),
        ("normattiva_exploration", "dlgs_correttivo_appalti"),
    ]

    /// Prima differenza tra due foreste di NodeDict, in pre-order, o nil se uguali.
    private func firstDiff(_ a: [NodeDict], _ b: [NodeDict], path: String = "") -> String? {
        if a.count != b.count {
            return "\(path): conteggio figli \(a.count) (mio) vs \(b.count) (baseline) — "
                + "miei=[\(a.prefix(6).map { $0.type.rawValue }.joined(separator: ","))] "
                + "base=[\(b.prefix(6).map { $0.type.rawValue }.joined(separator: ","))]"
        }
        for (i, (x, y)) in zip(a, b).enumerated() {
            let p = "\(path)[\(i)]"
            if x.id != y.id { return "\(p).id: '\(x.id)' vs '\(y.id)'" }
            if x.type != y.type { return "\(p).type: \(x.type.rawValue) vs \(y.type.rawValue)" }
            if x.level != y.level { return "\(p).level: \(String(describing: x.level)) vs \(String(describing: y.level))" }
            if x.length_category != y.length_category {
                return "\(p).length_category: \(String(describing: x.length_category)) vs \(String(describing: y.length_category)) (id \(x.id))"
            }
            if x.text != y.text {
                let xt = x.text ?? "nil", yt = y.text ?? "nil"
                return "\(p).text (id \(x.id) \(x.type.rawValue)):\n   mio=  '\(String(xt.prefix(120)))'\n   base= '\(String(yt.prefix(120)))'"
            }
            if let d = firstDiff(x.children, y.children, path: "\(p).children") { return d }
        }
        return nil
    }

    func test_parity_on_13_baselines() throws {
        var failures: [String] = []
        var passed = 0
        for c in cases {
            let xmlURL = fixturesDir.appendingPathComponent("\(c.group)/\(c.name)/\(c.name).xml")
            let baseName = "xml_akn_baseline_\(c.name).json"
            guard let data = try? Data(contentsOf: xmlURL) else {
                print("SKIP \(c.name): xml assente"); continue
            }
            let mine: ScabopdfDocument
            do { mine = try buildAknDocument(data, sourceName: "\(c.name).xml") }
            catch { failures.append("\(c.name): parser ha lanciato \(error)"); continue }
            let base: ScabopdfDocument
            do { base = try loadBaselineDocument(baseName) }
            catch { print("SKIP \(c.name): baseline assente (\(error))"); continue }

            var reasons: [String] = []
            if mine.schema_version != base.schema_version { reasons.append("schema_version \(mine.schema_version) vs \(base.schema_version)") }
            if mine.metadata != base.metadata { reasons.append("metadata \(mine.metadata) vs \(base.metadata)") }
            if mine.profile != base.profile { reasons.append("profile") }
            if mine.warnings != base.warnings {
                let extra = Set(mine.warnings).subtracting(base.warnings)
                let missing = Set(base.warnings).subtracting(mine.warnings)
                reasons.append("warnings: #mie=\(mine.warnings.count) #base=\(base.warnings.count) | in più=\(Array(extra).prefix(3)) | mancanti=\(Array(missing).prefix(3))")
            }
            if let d = firstDiff(mine.structure, base.structure, path: "structure") { reasons.append("STRUCT \(d)") }

            if reasons.isEmpty {
                passed += 1
                print("OK  \(c.name)  (\(mine.structure.count) root, \(countAll(mine.structure)) nodi)")
            } else {
                failures.append("FAIL \(c.name):\n   " + reasons.joined(separator: "\n   "))
            }
        }
        print("\n=== PARITÀ: \(passed)/\(cases.count) verdi ===")
        if !failures.isEmpty {
            XCTFail("\n" + failures.joined(separator: "\n"))
        }
    }

    private func countAll(_ nodes: [NodeDict]) -> Int {
        nodes.reduce(0) { $0 + 1 + countAll($1.children) }
    }
}
