//
//  AknSegmentRefineTests.swift
//  ScaboCoreTests
//
//  Parte B — i tre attriti del gate, verificati offline sui documenti AKN reali:
//  gli attriti ESISTONO nel flusso grezzo e SPARISCONO dopo refineAknSegments,
//  preservando contenuto (nessuna parola persa) e regime acustico (earcon una volta
//  per nota logica).
//

import XCTest
@testable import ScaboCore

final class AknSegmentRefineTests: XCTestCase {

    private var fixturesDir: URL {
        SNAPSHOTS_DIR.deletingLastPathComponent().appendingPathComponent("fixtures")
    }

    private func rawSegments(_ group: String, _ name: String) throws -> [ContentSegment] {
        let url = fixturesDir.appendingPathComponent("\(group)/\(name)/\(name).xml")
        let data = try XCTUnwrap(try? Data(contentsOf: url), "fixture assente: \(name)")
        let doc = try buildAknDocument(data, sourceName: "\(name).xml")
        return buildLayout(doc, .continuous)
    }

    private func stripWS(_ segs: [ContentSegment]) -> String {
        segs.map(\.text).joined().replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "").replacingOccurrences(of: "\t", with: "")
    }

    private let target = DEFAULT_GRANULARITY_TARGET

    /// legge_capitali esercita tutti e tre gli attriti (modifiche + note).
    func test_capitali_all_three_frictions_closed() throws {
        let raw = try rawSegments("normattiva_exploration", "legge_capitali")
        // Gli attriti ESISTONO nel grezzo:
        let rawBareMarkers = raw.filter { $0.role == "ARTICLE_BODY" && aknIsBareCommaMarker($0.text) }
        let rawPunctAmend = raw.filter { $0.role == "AMENDMENT" && aknIsPunctuationOnly($0.text) }
        let rawLongNotes = raw.filter { $0.role == "NOTE" && $0.text.count > target }
        XCTAssertGreaterThan(rawBareMarkers.count, 0, "atteso ≥1 comma-marker isolato nel grezzo")
        XCTAssertGreaterThan(rawPunctAmend.count, 0, "atteso ≥1 frammento AMENDMENT di sola chiusura nel grezzo")
        XCTAssertGreaterThan(rawLongNotes.count, 0, "attesa ≥1 nota più lunga del target nel grezzo")

        let refined = refineAknSegments(raw, noteTarget: target)

        // 1. Nessun marker di comma isolato residuo.
        XCTAssertEqual(refined.filter { $0.role == "ARTICLE_BODY" && aknIsBareCommaMarker($0.text) }.count, 0)
        // 2. Nessun frammento AMENDMENT di sola punteggiatura residuo.
        XCTAssertEqual(refined.filter { $0.role == "AMENDMENT" && aknIsPunctuationOnly($0.text) }.count, 0)
        // 3. Nessuna cella-nota supera il viewport (target).
        for s in refined where s.role == "NOTE" || s.role == "NOTE_CONTINUATION" {
            XCTAssertLessThanOrEqual(s.text.count, target, "cella nota troppo alta: \(s.id) len=\(s.text.count)")
        }
        // Contenuto preservato (nessuna parola persa).
        XCTAssertEqual(stripWS(refined), stripWS(raw), "contenuto non preservato")
    }

    /// Regime acustico a livello di nota logica: per ogni gruppo di frazioni #k,
    /// esattamente UNA cella ha ruolo NOTE con intro non vuoto (earcon), le altre
    /// sono NOTE_CONTINUATION con intro vuoto (nessun re-annuncio).
    func test_note_earcon_once_per_logical_note() throws {
        let raw = try rawSegments("normattiva_exploration", "legge_capitali")
        let refined = refineAknSegments(raw, noteTarget: target)
        var groups: [String: [ContentSegment]] = [:]
        for s in refined where s.role == "NOTE" || s.role == "NOTE_CONTINUATION" {
            let base = s.id.contains("#") ? String(s.id.prefix { $0 != "#" }) : s.id
            groups[base, default: []].append(s)
        }
        var fractioned = 0
        for (base, segs) in groups where segs.count > 1 {
            fractioned += 1
            let noteCells = segs.filter { $0.role == "NOTE" }
            XCTAssertEqual(noteCells.count, 1, "gruppo \(base): attesa 1 cella NOTE, trovate \(noteCells.count)")
            XCTAssertFalse(noteCells.first?.acousticIntro.isEmpty ?? true, "gruppo \(base): la prima cella deve annunciare")
            for cont in segs where cont.role == "NOTE_CONTINUATION" {
                XCTAssertTrue(cont.acousticIntro.isEmpty, "\(cont.id): continuazione non deve ri-annunciare")
                XCTAssertNil(noteSignalIntroFor(cont), "\(cont.id): continuazione non deve fare earcon")
            }
        }
        XCTAssertGreaterThan(fractioned, 0, "attesa ≥1 nota frazionata")
    }

    /// noteSignal scatta solo su role NOTE con intro non vuoto → helper di prova.
    private func noteSignalIntroFor(_ s: ContentSegment) -> String? {
        (s.role == "NOTE" && !s.acousticIntro.isEmpty) ? s.acousticIntro : nil
    }

    /// Contenuto preservato su più atti (BEN_FORMATO puro, modifiche, FRAGMENTED).
    func test_content_preserved_across_acts() throws {
        let acts: [(String, String)] = [
            ("normattiva_calibration", "legge_gelli_bianco"),
            ("normattiva_calibration", "codice_strada"),
            ("normattiva_exploration", "dlgs_cartabia"),
            ("normattiva_exploration", "codice_penale"),
        ]
        for (g, n) in acts {
            let raw = try rawSegments(g, n)
            let refined = refineAknSegments(raw, noteTarget: target)
            XCTAssertEqual(stripWS(refined), stripWS(raw), "\(n): contenuto non preservato")
            for s in refined where s.role == "NOTE" || s.role == "NOTE_CONTINUATION" {
                XCTAssertLessThanOrEqual(s.text.count, target, "\(n): cella nota troppo alta \(s.id)")
            }
            XCTAssertEqual(refined.filter { $0.role == "ARTICLE_BODY" && aknIsBareCommaMarker($0.text) }.count, 0, "\(n): marker residuo")
            XCTAssertEqual(refined.filter { $0.role == "AMENDMENT" && aknIsPunctuationOnly($0.text) }.count, 0, "\(n): frammento residuo")
        }
    }
}
