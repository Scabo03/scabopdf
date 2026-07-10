//
//  ReadingTextSizePreferenceTests.swift
//  ScaboCoreTests
//
//  Fase 0 accessibilità visiva: la preferenza GLOBALE dell'offset di dimensione del testo. Logica
//  pura (default, validazione, clamp, round-trip) verificabile in memoria, come le altre preferenze.
//

import XCTest
@testable import ScaboCore

final class ReadingTextSizePreferenceTests: XCTestCase {

    func test_default_isZero_whenAbsent() {
        let store = InMemoryKeyValueStore()
        XCTAssertEqual(getStoredReadingTextSizeOffset(store), 0)
    }

    func test_default_isZero_whenNonNumeric() {
        let store = InMemoryKeyValueStore([PreferenceKeys.readingTextSizeOffset: "abc"])
        XCTAssertEqual(getStoredReadingTextSizeOffset(store), 0)
    }

    func test_roundTrip_preservesValueInRange() {
        let store = InMemoryKeyValueStore()
        setStoredReadingTextSizeOffset(store, 3)
        XCTAssertEqual(getStoredReadingTextSizeOffset(store), 3)
        setStoredReadingTextSizeOffset(store, -2)
        XCTAssertEqual(getStoredReadingTextSizeOffset(store), -2)
    }

    func test_clampsOnWrite() {
        let store = InMemoryKeyValueStore()
        setStoredReadingTextSizeOffset(store, 999)
        XCTAssertEqual(getStoredReadingTextSizeOffset(store), READING_TEXT_SIZE_OFFSET_MAX)
        setStoredReadingTextSizeOffset(store, -999)
        XCTAssertEqual(getStoredReadingTextSizeOffset(store), READING_TEXT_SIZE_OFFSET_MIN)
    }

    func test_clampsOnRead_forDirtyStoredValue() {
        let dirty = InMemoryKeyValueStore([PreferenceKeys.readingTextSizeOffset: "500"])
        XCTAssertEqual(getStoredReadingTextSizeOffset(dirty), READING_TEXT_SIZE_OFFSET_MAX)
    }
}
