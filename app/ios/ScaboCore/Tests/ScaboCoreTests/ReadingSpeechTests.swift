//
//  ReadingSpeechTests.swift
//  ScaboCoreTests
//
//  La fonte unica del parlato della lettura (`ReadingSpeech`, `ReadingSpeechModel`; giro «fondamenta della lettura per
//  Mac», 2026-11-07): le parole e i segnali che erano nella vista dell'iPad, spostati senza cambiarli, e la descrizione
//  neutra di ogni elemento. Contenuti SINTETICI scritti per la prova: nessun testo dei volumi.
//

import XCTest
@testable import ScaboCore

final class ReadingSpeechTests: XCTestCase {

    private func seg(_ id: String, _ role: String, _ text: String, length: String = "", intro: String? = nil,
                     refresh: String = "", visual: VisualResourcePayload? = nil) -> ContentSegment {
        ContentSegment(id: id, role: role, text: text, lengthCategory: length,
                       acousticIntro: intro ?? acousticIntroFor(role, length), memoryRefresh: refresh, visualResource: visual)
    }

    private func table(page: Int, contained: Int = 0) -> VisualResourcePayload {
        VisualResourcePayload(kind: .table, pageIndex: page, bbox: [10, 10, 100, 100], containedElements: contained)
    }

    private func figure(page: Int) -> VisualResourcePayload {
        VisualResourcePayload(kind: .figure, pageIndex: page, bbox: [10, 10, 100, 100], containedElements: 0)
    }

    // MARK: - Le parole

    func test_spokenText_composesIntroRefreshText_skippingEmptyParts() {
        let n = seg("n1", "NOTE", "  7 Il testo della nota di prova.  ", length: "MEDIUM",
                    refresh: " la frase del richiamo di prova ")
        XCTAssertEqual(ReadingSpeech.spokenText(for: n), "Nota. la frase del richiamo di prova 7 Il testo della nota di prova.")
        let b = seg("b1", "BODY", "Un paragrafo qualunque del corpo.")
        XCTAssertEqual(ReadingSpeech.spokenText(for: b), "Un paragrafo qualunque del corpo.")
        XCTAssertEqual(ReadingSpeech.spoken(intro: "  ", segment: b), "Un paragrafo qualunque del corpo.")
    }

    func test_headingQualifier_perLevel_andArticle() {
        XCTAssertEqual(ReadingSpeech.headingQualifier(for: "HEADING_1"), "Intestazione di livello 1.")
        XCTAssertEqual(ReadingSpeech.headingQualifier(for: "HEADING_2"), "Intestazione di livello 2.")
        XCTAssertEqual(ReadingSpeech.headingQualifier(for: "HEADING_3"), "Intestazione di livello 3.")
        XCTAssertEqual(ReadingSpeech.headingQualifier(for: "HEADING_4"), "Intestazione di livello 4.")
        XCTAssertEqual(ReadingSpeech.headingQualifier(for: "ARTICLE_HEADER"), "Articolo.")
        XCTAssertEqual(ReadingSpeech.headingQualifier(for: "BODY"), "")
        XCTAssertEqual(ReadingSpeech.headingQualifier(for: SECTION_DIVIDER_ROLE), "", "il divisore ha già il suo intro")
        let h = seg("h", "HEADING_2", "Capitolo di prova")
        XCTAssertEqual(ReadingSpeech.intendedAccessibilityLabel(for: h), "Intestazione di livello 2. Capitolo di prova")
        let d = seg("d", SECTION_DIVIDER_ROLE, "Contenitore di prova")
        XCTAssertEqual(ReadingSpeech.intendedAccessibilityLabel(for: d), "Sezione. Contenitore di prova")
    }

    /// § 10.4: la nota vera con regime perde l'intro verbale (la porta l'earcon); con «note annunciate a voce» la riprende.
    func test_realNote_dropsIntroUnlessSpoken_andCollapsedFalseNoteKeepsText() {
        let note = seg("n", "NOTE", "3 Nota di prova.", length: "LONG")
        XCTAssertEqual(note.acousticIntro, "Nota lunga.")
        XCTAssertEqual(ReadingSpeech.intendedAccessibilityLabel(for: note), "3 Nota di prova.")
        XCTAssertEqual(ReadingSpeech.intendedAccessibilityLabel(for: note, restoreNoteIntro: true), "Nota lunga. 3 Nota di prova.")
        let falseNote = seg("f", "NOTE", "Titolo collassato di prova", length: "SHORT", intro: "")
        XCTAssertNil(ReadingSpeech.noteSignal(for: falseNote), "senza intro non è una nota vera: nessun segnale")
        XCTAssertEqual(ReadingSpeech.intendedAccessibilityLabel(for: falseNote), "Titolo collassato di prova")
        let editorial = seg("e", "EDITORIAL_NOTE", "Nota della redazione di prova.")
        XCTAssertNil(ReadingSpeech.noteSignal(for: editorial))
        XCTAssertEqual(ReadingSpeech.intendedAccessibilityLabel(for: editorial), "Nota editoriale. Nota della redazione di prova.")
        let box = seg("x", "EXAMPLE_BOX", "Un riquadro di prova.")
        XCTAssertEqual(ReadingSpeech.intendedAccessibilityLabel(for: box), "Riquadro. Un riquadro di prova.")
    }

    func test_noteSignal_perRegime() {
        let expected: [(String, AudioSignal)] = [("MICRO", .noteMicro), ("SHORT", .noteShort), ("MEDIUM", .noteMedium),
                                                 ("LONG", .noteLong), ("VERY_LONG", .noteVeryLong), ("MEGA", .noteMega)]
        for (regime, signal) in expected {
            XCTAssertEqual(ReadingSpeech.noteSignal(for: seg("n", "NOTE", "1 Prova.", length: regime)), signal, regime)
            XCTAssertEqual(AudioSignal.noteSignal(forLengthCategory: regime), signal)
        }
        XCTAssertNil(AudioSignal.noteSignal(forLengthCategory: ""))
        XCTAssertNil(ReadingSpeech.noteSignal(for: seg("c", "NOTE_CONTINUATION", "Seguito di prova.", length: "LONG")))
        // I nomi dei segnali sono i nomi dei file audio: stabili.
        XCTAssertEqual(AudioSignal.noteMega.rawValue, "ultra-long")
        XCTAssertEqual(AudioSignal.bibliography.rawValue, "bibliography")
        XCTAssertEqual(AudioSignal.allCases.count, 17)
    }

    func test_focusSignals_noteSuppressedBySpokenLabels_bibliographyOnEntryOnly() {
        let note = seg("n", "NOTE", "1 Prova.", length: "MICRO")
        XCTAssertEqual(ReadingSpeech.focusSignals(for: note, previousFocusedRole: "BODY", noteSpokenLabels: false), [.noteMicro])
        XCTAssertEqual(ReadingSpeech.focusSignals(for: note, previousFocusedRole: "BODY", noteSpokenLabels: true), [])
        let bib = seg("l", "LETTERATURA", "Voce bibliografica di prova.")
        XCTAssertEqual(ReadingSpeech.focusSignals(for: bib, previousFocusedRole: "BODY", noteSpokenLabels: false), [.bibliography])
        XCTAssertEqual(ReadingSpeech.focusSignals(for: bib, previousFocusedRole: nil, noteSpokenLabels: true), [.bibliography],
                       "l'ingresso nella bibliografia suona anche con le note a voce")
        XCTAssertEqual(ReadingSpeech.focusSignals(for: bib, previousFocusedRole: "LETTERATURA", noteSpokenLabels: false), [])
    }

    func test_headingLevel_andHeadingRole() {
        XCTAssertEqual((1...4).map { ReadingSpeech.headingLevel(for: "HEADING_\($0)") }, [1, 2, 3, 4])
        XCTAssertEqual(ReadingSpeech.headingLevel(for: "ARTICLE_HEADER"), 5)
        XCTAssertNil(ReadingSpeech.headingLevel(for: SECTION_DIVIDER_ROLE))
        XCTAssertNil(ReadingSpeech.headingLevel(for: "NOTE"))
        XCTAssertTrue(ReadingSpeech.isHeadingRole("HEADING_3"))
        XCTAssertTrue(ReadingSpeech.isHeadingRole(SECTION_DIVIDER_ROLE))
        XCTAssertTrue(ReadingSpeech.isHeadingRole("ARTICLE_HEADER"))
        XCTAssertFalse(ReadingSpeech.isHeadingRole("BODY"))
    }

    // MARK: - Il modello di un flusso

    /// Il flusso di prova: 0 Parte, 1 corpo col richiamo 37, 2-3 la nota frazionata, 4 tabella col suo testo (5), 6 figura,
    /// 7 Capitolo, 8 Articolo, 9-10 due voci bibliografiche.
    private func flow() -> [ContentSegment] {
        [
            seg("h1", "HEADING_1", "Parte di prova"),
            seg("b1", "BODY", "Frase di prova del corpo con il richiamo alla nota di prova 37, e poi altro testo di prova…"),
            seg("n9#0", "NOTE", "37 Primo pezzo della nota di prova.", length: "LONG",
                refresh: "Frase di prova del corpo con il richiamo alla nota di prova"),
            seg("n9#1", "NOTE_CONTINUATION", "Secondo pezzo della nota di prova."),
            seg("vr_p2_0", VISUAL_RESOURCE_ROLE, "Tabella: prospetto di prova", visual: table(page: 2, contained: 1)),
            seg("b2", "BODY", "Testo della tabella di prova."),
            seg("vr_p2_1", VISUAL_RESOURCE_ROLE, "Figura: schema di prova", visual: figure(page: 2)),
            seg("h2", "HEADING_2", "Capitolo di prova"),
            seg("a5", "ARTICLE_HEADER", "Art. 5 di prova"),
            seg("l1", "LETTERATURA", "Prima voce bibliografica di prova."),
            seg("l2", "LETTERATURA", "Seconda voce bibliografica di prova."),
        ]
    }

    func test_model_indices_rotors_andMembership() {
        let m = ReadingSpeechModel(segments: flow())
        XCTAssertEqual(m.headingIndex.map(\.index), [0, 7, 8])
        XCTAssertEqual(m.headingIndex.map(\.level), [1, 2, 5])
        XCTAssertEqual(m.headingLevelsPresent, [1, 2, 5])
        XCTAssertEqual(m.visualIndex.map(\.index), [4, 6])
        XCTAssertEqual(m.installedRotors(searchActive: false),
                       [.headings, .headingLevel(1), .headingLevel(2), .headingLevel(5), .tables, .images])
        XCTAssertEqual(m.installedRotors(searchActive: true).first, .searchResults)
        XCTAssertEqual(m.rotors(ofElementAt: 0), [.headings, .headingLevel(1)])
        XCTAssertEqual(m.rotors(ofElementAt: 4), [.tables])
        XCTAssertEqual(m.rotors(ofElementAt: 6), [.images])
        XCTAssertEqual(m.rotors(ofElementAt: 1), [])
        XCTAssertEqual(m.nextHeadingIndex(from: -1, level: nil, forward: true), 0)
        XCTAssertEqual(m.nextHeadingIndex(from: 0, level: 5, forward: true), 8)
        XCTAssertEqual(m.nextHeadingIndex(from: 8, level: nil, forward: false), 7)
        XCTAssertEqual(m.nextVisualIndex(from: 0, kind: .figure, forward: true), 6)
        // Senza titoli, senza risorse: solo il rotore Intestazioni, che c'è sempre.
        XCTAssertEqual(ReadingSpeechModel(segments: [seg("b", "BODY", "Solo corpo di prova.")]).installedRotors(searchActive: false),
                       [.headings])
        XCTAssertEqual(ReadingRotor.headingLevel(3).code, "titoli-3")
    }

    func test_model_values_visualResources() {
        let m = ReadingSpeechModel(segments: flow())
        XCTAssertEqual(m.visualResourceValue(forIndex: 4), "pagina 3 del file originale, 1 di 2")
        XCTAssertEqual(m.visualResourceValue(forIndex: 6), "pagina 3 del file originale, 2 di 2")
        XCTAssertNil(m.visualResourceValue(forIndex: 1))
        XCTAssertNil(m.value(forIndex: 1))
        let single = ReadingSpeechModel(segments: [seg("vr", VISUAL_RESOURCE_ROLE, "Tabella", visual: table(page: 0))])
        XCTAssertEqual(single.value(forIndex: 0), "pagina 1 del file originale")
    }

    func test_model_actions_orderAndAvailability() {
        let m = ReadingSpeechModel(segments: flow())
        let off = ReadingSpeechSettings(voiceOverRunning: false), on = ReadingSpeechSettings(voiceOverRunning: true)
        // Risorsa visiva con testo: estrai + salta (al primo elemento dopo il suo testo: qui la figura annunciata dopo).
        XCTAssertEqual(m.actions(forIndex: 4, bookmark: .absent, settings: on),
                       [.extractVisualResource, .skipVisualResource(target: 6), .addBookmark])
        XCTAssertEqual(m.indexAfterVisualResource(at: 4), 6)
        // Figura senza testo: solo estrai.
        XCTAssertEqual(m.visualResourceActions(forIndex: 6), [.extractVisualResource])
        // Il corpo che richiama la nota 37 e la nota che torna al richiamo; i pezzi di seguito tornano anch'essi.
        XCTAssertEqual(m.noteJumpActions(forIndex: 1), [.goToNote(target: 2, number: "37")])
        XCTAssertEqual(m.noteJumpActions(forIndex: 2), [.goToCall(target: 1)])
        XCTAssertEqual(m.noteJumpActions(forIndex: 3), [.goToCall(target: 1)])
        XCTAssertEqual(m.actions(forIndex: 1, bookmark: .present, settings: off).map(\.name),
                       ["Vai alla nota 37", "Modifica segnalibro", "Rimuovi segnalibro", "Strumenti elemento"])
        XCTAssertEqual(m.actions(forIndex: 0, bookmark: .unavailable, settings: on), [])
        XCTAssertEqual(ReadingAction.goToNote(target: 0, number: "").name, "Vai alla nota")
        XCTAssertEqual(ReadingAction.goToCall(target: 0).name, "Vai al testo del richiamo")
        XCTAssertEqual(ReadingAction.extractVisualResource.name, "Estrai come immagine")
        XCTAssertEqual(ReadingAction.skipVisualResource(target: 0).name, "Salta la risorsa")
    }

    // MARK: - La descrizione

    func test_describe_everyField_inLinearReading() throws {
        let m = ReadingSpeechModel(segments: flow())
        let d = m.describe(book: "prova", layout: .continuousReading, settings: ReadingSpeechSettings())
        XCTAssertEqual(d.header.elementCount, 11)
        XCTAssertEqual(d.header.rotors, ["titoli", "titoli-1", "titoli-2", "titoli-5", "tabelle", "immagini"])
        XCTAssertEqual(d.elements.map(\.index), Array(0..<11))
        XCTAssertEqual(d.elements[0].spokenText, "Intestazione di livello 1. Parte di prova")
        XCTAssertEqual(d.elements[0].headingLevel, 1)
        XCTAssertEqual(d.elements[0].rotors, ["titoli", "titoli-1"])
        XCTAssertEqual(d.elements[8].spokenText, "Articolo. Art. 5 di prova")
        XCTAssertEqual(d.elements[8].headingLevel, 5)
        XCTAssertEqual(d.elements[4].value, "pagina 3 del file originale, 1 di 2")
        XCTAssertEqual(d.elements[4].actions, ["Estrai come immagine", "Salta la risorsa", "Aggiungi segnalibro", "Strumenti elemento"])
        XCTAssertEqual(d.elements[2].signal, "long")
        XCTAssertEqual(d.elements[2].spokenText,
                       "Frase di prova del corpo con il richiamo alla nota di prova 37 Primo pezzo della nota di prova.")
        XCTAssertNil(d.elements[3].signal, "il pezzo di seguito è muto")
        XCTAssertEqual(d.elements[9].signal, "bibliography", "ingresso nel blocco bibliografico")
        XCTAssertNil(d.elements[10].signal, "la voce seguente dello stesso blocco non risuona")
        XCTAssertTrue(d.elements.allSatisfy { $0.role == "testo statico" && $0.container == "testo" })
        // Con le note annunciate a voce: l'intro torna nel parlato, l'earcon della nota tace, la bibliografia suona.
        let v = m.describe(book: "prova", layout: .continuousReading, settings: ReadingSpeechSettings(noteSpokenLabels: true))
        XCTAssertTrue(v.header.noteSpokenLabels)
        XCTAssertEqual(v.elements[2].spokenText,
                       "Nota lunga. Frase di prova del corpo con il richiamo alla nota di prova 37 Primo pezzo della nota di prova.")
        XCTAssertNil(v.elements[2].signal)
        XCTAssertEqual(v.elements[9].signal, "bibliography")
        // Un segnalibro e VoiceOver acceso cambiano solo le azioni.
        let w = m.describe(book: "prova", layout: .continuousReading, settings: ReadingSpeechSettings(voiceOverRunning: true),
                           bookmarkedSegmentIds: ["b2"])
        XCTAssertEqual(w.elements[5].actions, ["Modifica segnalibro", "Rimuovi segnalibro"])
        XCTAssertEqual(w.elements[0].actions, ["Aggiungi segnalibro"])
    }

    /// Prova al contrario: ogni ingresso che conta per VoiceOver cambia la descrizione, e la cambia nel campo giusto.
    /// Una descrizione insensibile a uno di questi ingressi darebbe una rete sul parlato verde per errore.
    func test_counterProof_everyRelevantInputChangesTheDescription() {
        let base = flow()
        let settings = ReadingSpeechSettings()
        func describe(_ s: [ContentSegment], _ st: ReadingSpeechSettings = ReadingSpeechSettings()) -> [ReadingElementDescription] {
            ReadingSpeechModel(segments: s).describe(book: "p", layout: .continuousReading, settings: st).elements
        }
        let ref = describe(base)
        var s = base; s[7].role = "HEADING_3"
        XCTAssertNotEqual(describe(s)[7].spokenText, ref[7].spokenText, "il livello cambia la qualifica")
        XCTAssertNotEqual(describe(s)[7].rotors, ref[7].rotors)
        s = base; s[2].lengthCategory = "MEGA"
        XCTAssertNotEqual(describe(s)[2].signal, ref[2].signal, "il regime cambia il segnale")
        s = base; s[2].memoryRefresh = "un altro richiamo di prova"
        XCTAssertNotEqual(describe(s)[2].spokenText, ref[2].spokenText, "il rinfresco è nel parlato")
        s = base; s[1].acousticIntro = "Riquadro."
        XCTAssertNotEqual(describe(s)[1].spokenText, ref[1].spokenText, "l'intro del ruolo è nel parlato")
        s = base; s[4].visualResource?.containedElements = 0
        XCTAssertNotEqual(describe(s)[4].actions, ref[4].actions, "«Salta la risorsa» dipende dal testo della risorsa")
        s = base; s[1].text = "Frase di prova del corpo senza alcun richiamo."
        XCTAssertNotEqual(describe(s)[1].actions, ref[1].actions, "il legame nota ↔ richiamo dà l'azione")
        XCTAssertNotEqual(describe(base, ReadingSpeechSettings(voiceOverRunning: true))[1].actions, ref[1].actions)
        XCTAssertEqual(describe(base, settings), ref, "stessi ingressi, stessa descrizione")
    }

    func test_encoding_isLinePerElement_sortedKeys_andRoundTrips() throws {
        let d = ReadingSpeechModel(segments: flow()).describe(
            book: "prova/libro", layout: .doctrineInline, settings: ReadingSpeechSettings())
        let data = try d.encoded()
        let text = String(decoding: data, as: UTF8.self)
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        XCTAssertEqual(lines.count, 13, "testata + 11 elementi + la riga vuota dopo l'ultimo a capo")
        XCTAssertTrue(lines[0].hasPrefix("{\"elementi\":11,\"formato\":\"descrizione-lettura-scabopdf\""))
        XCTAssertTrue(lines[0].contains("\"libro\":\"prova/libro\""), "barre non protette")
        XCTAssertTrue(lines[1].hasPrefix("{\"azioni\":["), "chiavi ordinate")
        XCTAssertFalse(lines[1].contains("\"valore\""), "un valore assente non si scrive")
        XCTAssertEqual(try ReadingDescription.decode(data), d)
        XCTAssertEqual(try d.encoded(), data, "stessa descrizione, stessi byte")
        XCTAssertThrowsError(try ReadingDescription.decode(Data()))
        XCTAssertThrowsError(try ReadingDescription.decode(Data("{\"formato\":\"altro\"}\n".utf8)))
    }
}
