//
//  CaptionAssociationTests.swift
//  ScaboPageStructureTests
//
//  Il porto di `predict_to_captions` di docling-ibm-models 3.13.3. I risultati attesi NON sono scritti a mano:
//  sono quelli che la funzione Python di docling restituisce sulle stesse sequenze d'etichette (registrati nel
//  laboratorio del giro «risorse visive», 2026-10-12, `tmp/didascalie`).
//

import XCTest
@testable import ScaboPageStructure

final class CaptionAssociationTests: XCTestCase {

    private func elements(_ labels: [String]) -> [PageElement] {
        labels.enumerated().map { i, lab in
            PageElement(cid: i, label: lab, text: "", pageNo: 1, pageW: 600, pageH: 800,
                        box: ROBox(l: 0, b: 0, r: 10, t: 10))
        }
    }

    private func captions(_ labels: [String]) -> [Int: [Int]] {
        ReadingOrderPredictor().predictToCaptions(elements(labels))
    }

    func test_casiDiDocling() {
        XCTAssertEqual(captions(["picture", "caption"]), [0: [1]])
        XCTAssertEqual(captions(["caption", "table"]), [1: [0]])
        XCTAssertEqual(captions(["table", "caption", "table"]), [:])
        XCTAssertEqual(captions(["picture", "caption", "picture", "caption"]), [0: [1], 2: [3]])
        XCTAssertEqual(captions(["picture", "text", "caption"]), [:])
        XCTAssertEqual(captions(["text", "caption", "text"]), [:])
        XCTAssertEqual(captions(["picture", "picture", "caption"]), [0: [2]])
        XCTAssertEqual(captions(["code", "caption", "picture", "caption"]), [0: [1], 2: [3]])
    }
}
