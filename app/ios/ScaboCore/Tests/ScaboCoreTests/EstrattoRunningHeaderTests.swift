//
//  EstrattoRunningHeaderTests.swift
//  ScaboCoreTests
//
//  Reclassify gated-Estratto delle testatine correnti ricorrenti (titolo capitolo recto,
//  lungo, ripetuto) sfuggite al cap-caratteri della furniture e finite in NOTE → falso-"Nota.".
//  Le porta a ARTIFACT_RUNNING_HEADER (non-letto). Conserva il nodo (solo cambio tipo).
//

import XCTest
@testable import ScaboCore

final class EstrattoRunningHeaderTests: XCTestCase {

    private let HEADER = "Il contenuto delle scelte provvedimentali tra diritto sostanziale e processo"

    private func note(_ text: String, _ id: String = "n", page: Int = 10) -> NodeDict {
        NodeDict(id: id, type: .NOTE, page_index: page, text: text, length_category: .MEDIUM)
    }
    private func run(_ nodes: [NodeDict], estratto: Bool = true) -> ([NodeDict], Int) {
        var n = nodes
        let c = reclassifyEstrattoRunningHeaders(
            &n, Profile(bodySize: 12, bodyColor: "#000000", isEstrattoChrome: estratto))
        return (n, c)
    }

    func test_recurringLongHeader_reclassified_pageNumbersIgnored() {
        // la stessa testatina con numeri di pagina diversi in coda → normalizzata → ricorre
        let nodes = (0..<6).map { note("\(HEADER) \(50 + $0)", "h\($0)", page: 10 + $0) }
        let (out, c) = run(nodes)
        XCTAssertEqual(c, 6)
        XCTAssertTrue(out.allSatisfy { $0.type == .ARTIFACT_RUNNING_HEADER })
        XCTAssertTrue(out.allSatisfy { $0.length_category == nil }, "non è una nota: niente regime")
    }

    func test_realNote_notTouched_evenIfLong() {
        // una nota vera (lunga ma UNICA) in mezzo alle testatine resta NOTE
        var nodes = (0..<6).map { note("\(HEADER) \(50 + $0)", "h\($0)", page: 10 + $0) }
        let realNote = note(
            "27 G. CORSO, L’attività amministrativa, Torino, 1999, p. 120, secondo cui la nozione",
            "real", page: 12)
        nodes.insert(realNote, at: 3)
        let (out, _) = run(nodes)
        XCTAssertEqual(out.first { $0.id == "real" }?.type, .NOTE, "la nota vera unica resta NOTE")
        XCTAssertEqual(out.filter { $0.type == .ARTIFACT_RUNNING_HEADER }.count, 6)
    }

    func test_shortRecurring_notTouched() {
        // una NOTE corta ripetuta (sotto il cap furniture) NON è testatina (es. "Ivi.")
        let nodes = (0..<8).map { note("Ivi, p. \(10 + $0).", "s\($0)") }
        let (out, c) = run(nodes)
        XCTAssertEqual(c, 0)
        XCTAssertTrue(out.allSatisfy { $0.type == .NOTE })
    }

    func test_belowThreshold_notTouched() {
        // la stessa testatina lunga ma solo 4 volte (< soglia 5) → non toccata (prudenza)
        let nodes = (0..<4).map { note("\(HEADER) \(50 + $0)", "h\($0)", page: 10 + $0) }
        let (out, c) = run(nodes)
        XCTAssertEqual(c, 0)
        XCTAssertTrue(out.allSatisfy { $0.type == .NOTE })
    }

    func test_gatedOff_noOp() {
        let nodes = (0..<6).map { note("\(HEADER) \(50 + $0)", "h\($0)", page: 10 + $0) }
        let (out, c) = run(nodes, estratto: false)
        XCTAssertEqual(c, 0)
        XCTAssertTrue(out.allSatisfy { $0.type == .NOTE }, "non-Estratto: invariato")
    }
}
