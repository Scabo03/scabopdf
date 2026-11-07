//
//  ReadingDescriptionComparisonTests.swift
//  ScaboCoreTests
//
//  Il confronto automatico fra due letture dello stesso libro (`ReadingDescriptionComparison`, giro «fondamenta della
//  lettura per Mac», 2026-11-07): coincidono o no, e se no la prima divergenza e il suo tipo. Contenuti SINTETICI scritti per
//  la prova. Le prove al contrario cercano i falsi verdi: ogni alterazione possibile di un campo di un elemento deve essere
//  trovata, al posto giusto e col tipo giusto.
//

import XCTest
@testable import ScaboCore

final class ReadingDescriptionComparisonTests: XCTestCase {

    /// Una descrizione sintetica di un flusso di prova, dal modulo del parlato (così ha la forma vera).
    private func sample() -> ReadingDescription {
        func seg(_ id: String, _ role: String, _ text: String, length: String = "", refresh: String = "",
                 visual: VisualResourcePayload? = nil) -> ContentSegment {
            ContentSegment(id: id, role: role, text: text, lengthCategory: length,
                           acousticIntro: acousticIntroFor(role, length), memoryRefresh: refresh, visualResource: visual)
        }
        let segments = [
            seg("h1", "HEADING_1", "Parte di prova"),
            seg("b1", "BODY", "Frase di prova del corpo con il richiamo alla nota di prova 37, e poi altro testo di prova…"),
            seg("n9#0", "NOTE", "37 Primo pezzo della nota di prova.", length: "MEDIUM",
                refresh: "Frase di prova del corpo con il richiamo alla nota di prova"),
            seg("vr_p0_0", VISUAL_RESOURCE_ROLE, "Tabella: prospetto di prova",
                visual: VisualResourcePayload(kind: .table, pageIndex: 0, bbox: [1, 2, 3, 4], containedElements: 1)),
            seg("b2", "BODY", "Testo della tabella di prova."),
            seg("h2", "HEADING_2", "Capitolo di prova"),
            seg("b3", "BODY", "Un paragrafo qualunque del corpo."),
            seg("l1", "LETTERATURA", "Voce bibliografica di prova."),
        ]
        return ReadingSpeechModel(segments: segments).describe(book: "prova", layout: .continuousReading,
                                                               settings: ReadingSpeechSettings())
    }

    /// Una fonte vera numera i propri elementi: dopo una rimozione gli indici ripartono consecutivi.
    private func renumbered(_ d: ReadingDescription) -> ReadingDescription {
        var d = d
        for k in d.elements.indices { d.elements[k].index = k }
        d.header.elementCount = d.elements.count
        return d
    }

    func test_identical_isIdentical_andSaysSo() {
        let r = ReadingDescriptionComparison.compare(sample(), sample())
        XCTAssertTrue(r.identical)
        XCTAssertNil(r.first)
        XCTAssertEqual(r.alignedElements, 8)
        XCTAssertEqual(ReadingDescriptionComparison.report(r, nameA: "iPad", nameB: "Mac"),
                       "iPad ↔ Mac: IDENTICHE (8 elementi, tutti confrontati)")
    }

    /// Prova al contrario esaustiva sul flusso di prova: per OGNI elemento e OGNI campo (bersagli delle azioni compresi), un'alterazione sola deve dare
    /// una divergenza sola, su quell'elemento, col tipo del campo. Nessun falso verde, nessuna cascata.
    func test_counterProof_everySingleFieldChangeIsFoundWithItsKind() {
        let base = sample()
        let mutations: [(ReadingDivergenceKind, (inout ReadingElementDescription) -> Void)] = [
            (.spokenText, { $0.spokenText += " " }),
            (.value, { $0.value = ($0.value ?? "") + "x" }),
            (.role, { $0.role = "intestazione" }),
            (.headingLevel, { $0.headingLevel = ($0.headingLevel ?? 0) + 1 }),
            (.signal, { $0.signal = $0.signal == nil ? "medium" : nil }),
            (.rotor, { $0.rotors.append("titoli-9") }),
            (.action, { $0.actions = $0.actions.isEmpty ? ["Aggiungi segnalibro"] : Array($0.actions.dropLast()) }),
            (.action, { $0.actionTargets = $0.actionTargets.isEmpty ? [5] : $0.actionTargets.map { ($0 ?? -1) + 1 } }),
            (.container, { $0.container = "interfaccia" }),
        ]
        var checked = 0
        for i in base.elements.indices {
            for (kind, mutate) in mutations {
                var b = base
                mutate(&b.elements[i])
                let r = ReadingDescriptionComparison.compare(base, b)
                XCTAssertFalse(r.identical, "elemento \(i), \(kind.rawValue): falso verde")
                XCTAssertEqual(r.totalDivergences, 1, "elemento \(i), \(kind.rawValue): una sola divergenza")
                XCTAssertEqual(r.first?.kind, kind)
                XCTAssertEqual(r.first?.indexA, i)
                XCTAssertEqual(r.first?.segmentId, base.elements[i].segmentId)
                checked += 1
            }
        }
        XCTAssertEqual(checked, 72)
    }

    func test_missingAndExtraElements_areFoundWithoutCascade() {
        let base = sample()
        var less = base; less.elements.remove(at: 3); less = renumbered(less)
        var r = ReadingDescriptionComparison.compare(base, less)
        XCTAssertEqual(r.totalDivergences, 1)
        XCTAssertEqual(r.first?.kind, .missingElement)
        XCTAssertEqual(r.first?.indexA, 3)
        XCTAssertEqual(r.first?.segmentId, "vr_p0_0")
        XCTAssertEqual(r.alignedElements, 7, "tutto ciò che segue resta allineato")
        r = ReadingDescriptionComparison.compare(less, base)
        XCTAssertEqual(r.totalDivergences, 1)
        XCTAssertEqual(r.first?.kind, .extraElement)
        XCTAssertEqual(r.first?.indexB, 3)
        // Due elementi mancanti di fila, e un elemento sostituito da un altro.
        var two = base; two.elements.removeSubrange(1...2); two = renumbered(two)
        r = ReadingDescriptionComparison.compare(base, two)
        XCTAssertEqual(r.counts[.missingElement], 2)
        XCTAssertEqual(r.totalDivergences, 2)
        var swapped = base; swapped.elements[5].segmentId = "altro"
        r = ReadingDescriptionComparison.compare(base, swapped)
        XCTAssertEqual(r.counts[.missingElement], 1)
        XCTAssertEqual(r.counts[.extraElement], 1)
        XCTAssertEqual(r.first?.kind, .missingElement)
        // Coda: la seconda finisce prima, o continua oltre.
        var short = base; short.elements.removeLast(); short = renumbered(short)
        r = ReadingDescriptionComparison.compare(base, short)
        XCTAssertEqual(r.first?.kind, .missingElement); XCTAssertEqual(r.first?.indexA, 7)
        var empty = base; empty.elements = []; empty = renumbered(empty)
        r = ReadingDescriptionComparison.compare(base, empty)
        XCTAssertEqual(r.counts[.missingElement], 8)
        XCTAssertEqual(r.alignedElements, 0)
    }

    func test_repeatedIdentities_alignOnTheNearestOccurrence() {
        var a = sample()
        a.elements[6].segmentId = "b2"   // la stessa identità due volte nel flusso
        var b = a
        b.elements.remove(at: 4); b = renumbered(b)
        let r = ReadingDescriptionComparison.compare(a, b)
        XCTAssertEqual(r.totalDivergences, 1)
        XCTAssertEqual(r.first?.kind, .missingElement)
    }

    func test_header_settingsRotorsAndDeclaredCount() {
        let base = sample()
        var b = base; b.header.noteSpokenLabels = true
        var r = ReadingDescriptionComparison.compare(base, b)
        XCTAssertEqual(r.first?.kind, .header); XCTAssertEqual(r.first?.field, "noteAVoce")
        b = base; b.header.layout = "dottrina-inline"
        XCTAssertEqual(ReadingDescriptionComparison.compare(base, b).first?.field, "layout")
        b = base; b.header.rotors.removeLast()
        r = ReadingDescriptionComparison.compare(base, b)
        XCTAssertEqual(r.first?.kind, .rotor); XCTAssertEqual(r.first?.field, "rotori installati")
        b = base; b.header.elementCount += 1
        XCTAssertEqual(ReadingDescriptionComparison.compare(base, b).first?.field, "elementi dichiarati nella seconda")
        b = base; b.header.book = "altro libro"
        XCTAssertEqual(ReadingDescriptionComparison.compare(base, b).first?.field, "libro")
        // Un indice fuori posto: la descrizione è rotta, e lo si dice una volta sola (nessuna cascata).
        b = base; b.elements[3].index = 99
        r = ReadingDescriptionComparison.compare(base, b)
        XCTAssertEqual(r.totalDivergences, 1)
        XCTAssertEqual(r.first?.kind, .header); XCTAssertEqual(r.first?.field, "indici della seconda")
    }

    func test_report_withoutText_carriesNoTextOfTheLabels() {
        let base = sample()
        var b = base; b.elements[6].spokenText = "Un altro paragrafo di prova, diverso."
        let r = ReadingDescriptionComparison.compare(base, b)
        let quiet = ReadingDescriptionComparison.report(r, nameA: "iPad", nameB: "Mac")
        XCTAssertTrue(quiet.contains("testo pronunciato — elemento 6, id b3, campo «testo»"))
        XCTAssertTrue(quiet.contains("impronta"))
        XCTAssertFalse(quiet.contains("paragrafo"), "senza testo: solo lunghezze e impronte")
        let loud = ReadingDescriptionComparison.report(r, nameA: "iPad", nameB: "Mac", showText: true)
        XCTAssertTrue(loud.contains("«Un altro paragrafo di prova, diverso.»"))
        var m = base; m.elements.remove(at: 2); m = renumbered(m)
        let missingQuiet = ReadingDescriptionComparison.report(ReadingDescriptionComparison.compare(base, m), nameA: "a", nameB: "b")
        XCTAssertFalse(missingQuiet.contains("nota di prova"), "anche l'elemento mancante si dice senza testo")
    }

    func test_limit_keepsCountsComplete() {
        let base = sample()
        var b = base
        for i in b.elements.indices { b.elements[i].container = "altro" }
        let r = ReadingDescriptionComparison.compare(base, b, limit: 3)
        XCTAssertEqual(r.divergences.count, 3)
        XCTAssertEqual(r.totalDivergences, 8)
        XCTAssertEqual(r.counts[.container], 8)
    }

    /// Due descrizioni che passano dal file: la forma su file non perde nulla che il confronto guardi.
    func test_fileRoundTrip_thenCompare() throws {
        let base = sample()
        let back = try ReadingDescription.decode(base.encoded())
        XCTAssertTrue(ReadingDescriptionComparison.compare(base, back).identical)
        var b = base; b.elements[2].signal = nil
        let back2 = try ReadingDescription.decode(b.encoded())
        XCTAssertEqual(ReadingDescriptionComparison.compare(base, back2).first?.kind, .signal)
    }
}
