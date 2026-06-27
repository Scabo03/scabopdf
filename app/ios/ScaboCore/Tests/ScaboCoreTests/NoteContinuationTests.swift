//
//  NoteContinuationTests.swift
//  ScaboCoreTests
//
//  Mattone 2/3 esteso al REGIME DELLE NOTE: continuità cross-pagina delle note
//  (`mergeNoteContinuations`). Una nota spezzata dal salto pagina (due segmenti NOTE
//  consecutivi: il primo APRE, il secondo CONTINUA) viene ricucita. Regime-aware:
//  un nuovo marcatore "N Maiuscola" (regime agganciato) è escluso → mai si fondono due
//  note distinte. Precisione prima del recall: completa/Maiuscola/marcatore → non si fonde.
//

import XCTest
@testable import ScaboCore

final class NoteContinuationTests: XCTestCase {

    private func note(_ text: String, intro: String = "Nota.") -> ContentSegment {
        ContentSegment(id: "n", role: SemanticCategory.NOTE.rawValue, text: text,
                       lengthCategory: "SHORT", acousticIntro: intro)
    }
    private func body(_ text: String) -> ContentSegment {
        ContentSegment(id: "b", role: SemanticCategory.BODY.rawValue, text: text,
                       lengthCategory: "", acousticIntro: "")
    }
    private func merged(_ segs: [ContentSegment]) -> [ContentSegment] { mergeNoteContinuations(segs) }

    // MARK: - predicati

    func test_noteOpens() {
        XCTAssertTrue(noteOpensForContinuation("A. ROMANO, Lezioni, Torino 1991, p."))   // p. attende numero
        XCTAssertTrue(noteOpensForContinuation("V. da ultimo Reato colposo, 2021,"))     // virgola
        XCTAssertTrue(noteOpensForContinuation("come previsto dall’art."))               // art. attende numero
        XCTAssertTrue(noteOpensForContinuation("promozione media-"))                     // lettera+trattino
        XCTAssertTrue(noteOpensForContinuation("cfr. la sentenza pubblicata in"))        // finisce in lettera
        XCTAssertFalse(noteOpensForContinuation("in Riv. it. dir. proc. pen., 2007, 493 ss."))  // ss. completa
        XCTAssertFalse(noteOpensForContinuation("la Corte ha deciso nel 1994."))         // punto forte (completa)
        XCTAssertFalse(noteOpensForContinuation("op. cit."))                             // cit. completa
    }
    func test_noteContinuation() {
        XCTAssertTrue(noteContinuation("508 ss.; SORDI, Giustizia"))   // cifra-pagina
        XCTAssertTrue(noteContinuation("tica, 2010; PECCIOLI"))        // minuscola (coda parola)
        XCTAssertTrue(noteContinuation("25 ottobre 2001, n. 13196)"))  // cifra+minuscola (data)
        XCTAssertTrue(noteContinuation("572 risulta ispirata"))        // cifra+minuscola
        XCTAssertFalse(noteContinuation("13 Le pronunce di riferimento"))  // marcatore "N Maiuscola"
        XCTAssertFalse(noteContinuation("39 F. CAMMEO, Corso"))            // marcatore "N Maiuscola"
        XCTAssertFalse(noteContinuation("5. Sembra utile"))               // marcatore "N."
        XCTAssertFalse(noteContinuation("(7) Cass."))                     // marcatore "(N)"
        XCTAssertFalse(noteContinuation("Foro it., 1994, II"))            // Maiuscola (nuova voce)
    }

    // MARK: - merge (le ricuciture)

    func test_merge_bibliography_pageContinuation() {
        let r = merged([note("A. ROMANO, Lezioni, Torino 1991, p."), note("508 ss.; SORDI, Giustizia")])
        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(r[0].text, "A. ROMANO, Lezioni, Torino 1991, p. 508 ss.; SORDI, Giustizia")
    }
    func test_merge_deHyphenation_brokenWordAcrossPages() {
        let r = merged([note("studio della promozione media-"), note("tica, 2010; PECCIOLI")])
        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(r[0].text, "studio della promozione mediatica, 2010; PECCIOLI")
    }
    func test_merge_commaThenDate() {
        let r = merged([note("Ass. Firenze,"), note("23 marzo 1993, in Foro it.")])
        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(r[0].text, "Ass. Firenze, 23 marzo 1993, in Foro it.")
    }

    // MARK: - esclusioni (mai fondere due note distinte)

    func test_noMerge_newNoteMarker_bound() {
        // prev APRE (ss. no… qui virgola) ma il frammento è una NUOVA nota "13 Le…".
        let r = merged([note("in Riv. it. dir. proc. pen., 2007,"), note("13 Le pronunce di riferimento")])
        XCTAssertEqual(r.count, 2)   // NON fuse
    }
    func test_noMerge_uppercaseStart() {
        let r = merged([note("la sentenza pubblicata in"), note("Foro it., 1994, II, 146")])
        XCTAssertEqual(r.count, 2)
    }
    func test_noMerge_prevComplete_strongPeriod() {
        let r = merged([note("la Corte ha deciso nel 1994."), note("altra osservazione minore qui")])
        XCTAssertEqual(r.count, 2)
    }
    func test_noMerge_prevCompleteAbbrev_ss() {
        // "64 ss." è un range completo → non apre; il "12 marzo" seguente resta separato.
        let r = merged([note("in Dir. pen. proc., 2016, 64 ss."), note("12 marzo 2020 osservazioni")])
        XCTAssertEqual(r.count, 2)
    }
    func test_noMerge_prevIsBody() {
        // una NOTE dopo un BODY non è una continuazione-di-nota (la gestisce semmai il mattone 2 corpo).
        let r = merged([body("Il corpo del paragrafo prosegue regolarmente fino a qui"), note("508 ss.")])
        XCTAssertEqual(r.count, 2)
        XCTAssertEqual(r[1].role, SemanticCategory.NOTE.rawValue)
    }

    // MARK: - rete A + acustica

    func test_reteA_noLettersLost_onMerge() {
        let a = "A. ROMANO, Lezioni, Torino 1991, p."; let b = "508 ss.; SORDI, Giustizia"
        let r = merged([note(a), note(b)])
        func letters(_ s: String) -> Int { s.filter { $0.isLetter }.count }
        XCTAssertEqual(letters(r[0].text), letters(a) + letters(b))   // nessuna lettera persa
    }
    func test_clearedIntro_staysCleared_unboundRegime() {
        // regime bibliografia: la testa apre senza marcatore → band-aid azzera l'intro;
        // dopo il merge resta azzerata (la nota fusa apre comunque senza marcatore).
        let r = merged([note("A. ROMANO, Lezioni, Torino 1991, p.", intro: ""), note("508 ss.")])
        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(r[0].acousticIntro, "")
    }
    func test_lengthCategoryRecomputed_onMerge() {
        let long = String(repeating: "a parola di nota ", count: 80)   // > soglie → LONG/oltre
        let r = merged([note("inizio nota che apre la citazione p."), note("508 " + long)])
        XCTAssertEqual(r.count, 1)
        XCTAssertNotEqual(r[0].lengthCategory, "SHORT")   // ricomputata sulla nota cresciuta
        XCTAssertTrue(r[0].acousticIntro.hasPrefix("Nota"))
    }
}
