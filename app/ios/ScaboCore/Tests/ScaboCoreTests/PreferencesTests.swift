//
//  PreferencesTests.swift
//  ScaboCoreTests
//
//  XCTest translation of `app/src/storage/__tests__/preferences.test.ts` (55).
//  The TS uses the AsyncStorage mock (a Map-backed JS store) so the round-trips
//  are real; here the in-memory `InMemoryKeyValueStore` is the equivalent
//  non-system backing, exercising the same default-and-validate logic. The
//  concrete UserDefaults-backed store is banda POST-MAC.
//

import XCTest
@testable import ScaboCore

final class PreferencesTests: XCTestCase {

    private var store: InMemoryKeyValueStore!

    override func setUp() {
        super.setUp()
        // Mirrors the TS `beforeEach(() => AsyncStorage.clear())`.
        store = InMemoryKeyValueStore()
    }

    // MARK: theme selection persistence

    /// TS: "defaults to dark when nothing is stored".
    func test_theme_defaultsToDark() {
        XCTAssertEqual(getStoredThemeSelection(store), .dark)
    }

    /// TS: "round-trips a valid value".
    func test_theme_roundTripsValidValues() {
        setStoredThemeSelection(store, .light)
        XCTAssertEqual(getStoredThemeSelection(store), .light)
        setStoredThemeSelection(store, .highContrast)
        XCTAssertEqual(getStoredThemeSelection(store), .highContrast)
        setStoredThemeSelection(store, .system)
        XCTAssertEqual(getStoredThemeSelection(store), .system)
    }

    /// TS: "ignores a corrupted/unknown stored value and returns the default".
    func test_theme_ignoresCorruptedValue() {
        store.setItem(PreferenceKeys.themeSelection, "midnight")
        XCTAssertEqual(getStoredThemeSelection(store), .dark)
    }

    // MARK: layout id persistence

    /// TS: "defaults to continuous when nothing is stored".
    func test_layout_defaultsToContinuous() {
        XCTAssertEqual(getStoredLayoutId(store), .continuous)
    }

    /// TS: "round-trips a valid value".
    func test_layout_roundTripsValidValues() {
        setStoredLayoutId(store, .quick)
        XCTAssertEqual(getStoredLayoutId(store), .quick)
        setStoredLayoutId(store, .doctrine)
        XCTAssertEqual(getStoredLayoutId(store), .doctrine)
    }

    /// TS: "ignores a corrupted stored value and returns the default".
    func test_layout_ignoresCorruptedValue() {
        store.setItem(PreferenceKeys.layoutId, "fancy")
        XCTAssertEqual(getStoredLayoutId(store), .continuous)
    }

    // MARK: clear() — mirrors AsyncStorage.clear() round-trip reset

    func test_clear_resetsToDefaults() {
        setStoredThemeSelection(store, .light)
        setStoredLayoutId(store, .quick)
        store.clear()
        XCTAssertEqual(getStoredThemeSelection(store), .dark)
        XCTAssertEqual(getStoredLayoutId(store), .continuous)
    }
}
