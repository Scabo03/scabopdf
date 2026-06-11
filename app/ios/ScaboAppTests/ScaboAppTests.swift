//
//  ScaboAppTests.swift
//  ScaboAppTests
//
//  In-project XCTest harness "agganciato al target app" (Piano di migrazione,
//  banda POST-MAC punto 1 / W1). COMPLEMENTARE, non sostitutivo, del veloce
//  `swift test` su ScaboCore (host macOS, 126 test): questo gira sul Simulator
//  nel processo del target ScaboApp e dimostra che la libreria SwiftPM locale
//  `ScaboCore` è linkata e usabile dal contesto app.
//
//  NON duplica la logica dei test di ScaboCore: si limita a importare il modulo
//  ed esercitare un simbolo pubblico già coperto dalla suite ScaboCore
//  (la superficie `Layout`), così un fallimento qui segnala un problema di
//  cablaggio/linking, non di logica.
//

import XCTest
import ScaboCore

final class ScaboAppTests: XCTestCase {

    /// Prova che il modulo ScaboCore è importabile e linkato nel target app:
    /// la superficie pubblica `Layout` risponde con i tre layout attesi.
    func testScaboCoreIsLinkedAndUsable() throws {
        XCTAssertEqual(LAYOUT_IDS.count, 3)
        XCTAssertEqual(LAYOUT_IDS, [.continuous, .quick, .doctrine])

        // Ogni layout pubblico ha un nome visualizzabile non vuoto.
        for id in LAYOUT_IDS {
            let displayName = LAYOUT_DISPLAY_NAMES[id]
            XCTAssertNotNil(displayName, "manca il display name per \(id)")
            XCTAssertFalse(displayName?.isEmpty ?? true)
        }
    }
}
