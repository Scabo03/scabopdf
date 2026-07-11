//
//  AppearanceWiringTests.swift
//  ScaboAppTests
//
//  Il ponte UI del sistema di accessibilità visiva: opzioni di aspetto (prima apertura
//  + Impostazioni), parsing hex→UIColor, flag di prima apertura.
//

import XCTest
import UIKit
@testable import ScaboApp
import ScaboCore

final class AppearanceWiringTests: XCTestCase {

    func test_appearanceOptions_coverFollowSystemPlusFourPresets() {
        let opts = AppearanceOptions.all
        XCTAssertEqual(opts.count, 5)
        XCTAssertNil(opts.first?.preset, "la prima opzione è «Segui il sistema»")
        let presets = opts.compactMap { $0.preset }
        XCTAssertEqual(Set(presets), Set([.standard, .comfort, .ipovisione, .calma]))
        for o in opts {
            XCTAssertFalse(o.title.isEmpty)
            XCTAssertFalse(o.subtitle.isEmpty, "ogni opzione ha una descrizione parlata")
        }
    }

    func test_apply_followSystemOption() {
        let store = InMemoryKeyValueStore()
        let followSystem = AppearanceOptions.all.first { $0.preset == nil }!
        AppearanceOptions.apply(followSystem, to: store)
        XCTAssertEqual(getStoredAppearanceSource(store), .followSystem)
        XCTAssertTrue(AppearanceOptions.isSelected(followSystem, prefs: store))
    }

    func test_apply_presetOption_setsAppThemeAndPreset() {
        let store = InMemoryKeyValueStore()
        let comfort = AppearanceOptions.all.first { $0.preset == .comfort }!
        AppearanceOptions.apply(comfort, to: store)
        XCTAssertEqual(getStoredAppearanceSource(store), .appTheme)
        XCTAssertEqual(getStoredReadingPreset(store), .comfort)
        XCTAssertEqual(getStoredSpacingProfile(store), .comfortable, "il preset porta la spaziatura di partenza")
        XCTAssertTrue(AppearanceOptions.isSelected(comfort, prefs: store))
        // Non è selezionato «Segui il sistema».
        XCTAssertFalse(AppearanceOptions.isSelected(AppearanceOptions.all[0], prefs: store))
    }

    func test_uiColorFromHex() {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        let c = UIColor(hex: "#0A0A0A")
        XCTAssertNotNil(c)
        XCTAssertTrue(c!.getRed(&r, green: &g, blue: &b, alpha: &a))
        XCTAssertEqual(Double(r), 10.0 / 255.0, accuracy: 0.001)
        XCTAssertEqual(Double(a), 1.0, accuracy: 0.001)
        XCTAssertNil(UIColor(hex: "nope"))
        XCTAssertNil(UIColor(hex: "#12345"), "lunghezza errata → nil")
    }

    func test_firstOpenFlag_defaultFalse_setTrue() {
        let store = InMemoryKeyValueStore()
        XCTAssertFalse(getStoredFirstOpenCompleted(store))
        setStoredFirstOpenCompleted(store, true)
        XCTAssertTrue(getStoredFirstOpenCompleted(store))
    }
}
