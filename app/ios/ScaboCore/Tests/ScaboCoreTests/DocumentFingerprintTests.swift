//
//  DocumentFingerprintTests.swift
//  ScaboCoreTests
//
//  L'impronta del documento (giro «identità», 2026-10-11): stessi byte → stessa impronta, byte diversi
//  → impronta diversa; lettura a flusso identica alla lettura intera; vettori pubblici di SHA-256; e la
//  METÀ HOST della prova fra piattaforme: l'impronta di un file del repo calcolata qui (macOS, `swift
//  test`) deve essere la stessa che il test gemello `DocumentIdentityTests` calcola nel simulatore
//  iOS sullo stesso file, e quella dell'oracolo esterno `shasum -a 256` (costante qui sotto).
//  Nessun testo dei volumi: il file del repo è un atto di Normattiva (fixture pubblica).
//

import XCTest
@testable import ScaboCore

final class DocumentFingerprintTests: XCTestCase {

    /// Fixture pubblica del repo (atto di Normattiva), 10 251 byte: `pipeline/tests/fixtures/...`.
    /// Il percorso è derivato da `#filePath` (host filesystem), come `BaselineFixtures`.
    static var repoFixtureURL: URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<6 { url.deleteLastPathComponent() }  // Tests/ScaboCoreTests/<file> → ScaboCore → ios → app → repo
        return url.appendingPathComponent("pipeline/tests/fixtures/normattiva_calibration/legge_56_2007/legge_56_2007.xml")
    }
    /// `shasum -a 256` del file (oracolo esterno, 2026-10-11).
    static let repoFixtureSha256 = "d33282e4cc5b3c48cd0c214703d3d92c2229abfc37d2684672028743b33d3487"

    /// Byte deterministici (nessun testo): `(i * seed + 7) mod 256`.
    static func pattern(count: Int, seed: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        for i in 0..<count { bytes[i] = UInt8(truncatingIfNeeded: i &* seed &+ 7) }
        return Data(bytes)
    }

    // MARK: - Vettori pubblici

    func test_knownVectors_abc_andEmpty() {
        XCTAssertEqual(DocumentFingerprint.sha256Hex(of: Data("abc".utf8)),
                       "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        XCTAssertEqual(DocumentFingerprint.sha256Hex(of: Data()),
                       "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
    }

    // MARK: - Stessi byte, byte diversi

    func test_sameBytes_sameFingerprint_differentBytes_differentFingerprint() throws {
        let a = Self.pattern(count: 10_000, seed: 1)
        var b = a
        b[4_321] ^= 0x01   // un bit diverso
        let fa = DocumentFingerprint.sha256Hex(of: a)
        XCTAssertEqual(fa, DocumentFingerprint.sha256Hex(of: Data(a)), "stessi byte → stessa impronta")
        XCTAssertNotEqual(fa, DocumentFingerprint.sha256Hex(of: b), "un bit diverso → impronta diversa")
        XCTAssertTrue(DocumentFingerprint.isWellFormed(fa))
        XCTAssertEqual(fa.count, DocumentFingerprint.hexLength)
    }

    func test_twoCopiesOfTheSameFile_haveTheSameFingerprint() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("scabo-fp-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let bytes = Self.pattern(count: 300_000, seed: 7)
        let one = dir.appendingPathComponent("uno.pdf"), two = dir.appendingPathComponent("due.pdf")
        try bytes.write(to: one)
        try FileManager.default.copyItem(at: one, to: two)   // come l'archivio: copia byte-identica
        XCTAssertEqual(try DocumentFingerprint.sha256Hex(ofFileAt: one), try DocumentFingerprint.sha256Hex(ofFileAt: two))
        XCTAssertEqual(try DocumentFingerprint.sha256Hex(ofFileAt: one), DocumentFingerprint.sha256Hex(of: bytes))
    }

    // MARK: - Flusso = intero (anche a cavallo dei blocchi)

    func test_streaming_equalsWhole_acrossChunkBoundaries() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("scabo-fp-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        // 3 MiB + 17 byte: più blocchi interi da 1 MiB e una coda spuria.
        let bytes = Self.pattern(count: 3 * (1 << 20) + 17, seed: 31)
        let url = dir.appendingPathComponent("grande.bin")
        try bytes.write(to: url)
        let whole = DocumentFingerprint.sha256Hex(of: bytes)
        XCTAssertEqual(try DocumentFingerprint.sha256Hex(ofFileAt: url), whole)
        XCTAssertEqual(try DocumentFingerprint.sha256Hex(ofFileAt: url, chunkSize: 1000), whole, "blocchi non allineati")
        XCTAssertEqual(try DocumentFingerprint.sha256Hex(ofFileAt: url, chunkSize: 1), whole, "un byte alla volta")
        XCTAssertEqual(try DocumentFingerprint.sha256Hex(ofFileAt: url, chunkSize: 0), whole, "blocco degenere → minimo 1")
    }

    func test_emptyFile_hasTheEmptyFingerprint() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("scabo-fp-vuoto-\(UUID().uuidString).pdf")
        try Data().write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertEqual(try DocumentFingerprint.sha256Hex(ofFileAt: url), DocumentFingerprint.sha256Hex(of: Data()))
    }

    // MARK: - File mancante: lancia, mai crash

    func test_missingFile_throws() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("scabo-fp-manca-\(UUID().uuidString).pdf")
        XCTAssertThrowsError(try DocumentFingerprint.sha256Hex(ofFileAt: url))
    }

    // MARK: - Forma

    func test_isWellFormed() {
        XCTAssertTrue(DocumentFingerprint.isWellFormed(Self.repoFixtureSha256))
        XCTAssertFalse(DocumentFingerprint.isWellFormed(""))
        XCTAssertFalse(DocumentFingerprint.isWellFormed(String(repeating: "a", count: 63)))
        XCTAssertFalse(DocumentFingerprint.isWellFormed(String(repeating: "A", count: 64)), "solo minuscole")
        XCTAssertFalse(DocumentFingerprint.isWellFormed(String(repeating: "g", count: 64)), "solo cifre esadecimali")
    }

    // MARK: - Metà host della prova fra piattaforme

    func test_repoFixture_fingerprint_onHost_matchesTheExternalOracle() throws {
        let url = Self.repoFixtureURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("fixture del repo non trovata in \(url.path)")
        }
        XCTAssertEqual(try DocumentFingerprint.sha256Hex(ofFileAt: url), Self.repoFixtureSha256,
                       "l'impronta sull'host (macOS) deve coincidere con `shasum -a 256` e con il simulatore iOS")
    }
}
