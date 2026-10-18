//
//  UserNotesPluginTests.swift
//  ScaboCoreTests
//
//  Ramo utente (appunti/dispense Google Docs): la porta `matches` sulla firma-producer
//  e la foglia delle intestazioni a livello riga (keyword + ordinale + " – titolo"), con
//  le trappole reali (romane-che-sono-parole, citazioni con virgola, "X seconda." col punto).
//  Precisione prima del recall: nel dubbio non si promuove.
//

import XCTest
@testable import ScaboCore

final class UserNotesPluginTests: XCTestCase {

    // MARK: - Foglia intestazioni: promozioni vere (forme reali di Proc.civ vol.3, testo inventato)

    func test_heading_parte_uppercase_level1() {
        XCTAssertEqual(userNotesHeadingLevel("PARTE PRIMA – CONSORZI SPECIALI A GESTIONE PIENA"), 1)
        XCTAssertEqual(userNotesHeadingLevel("PARTE SECONDA – I CONSORZI SPECIALI A GESTIONE"), 1)
    }
    func test_heading_cap_abbrev_digit_level2() {
        XCTAssertEqual(userNotesHeadingLevel("CAP. 1 – CONSORZI O ENTI SPECIALI IN"), 2)
        XCTAssertEqual(userNotesHeadingLevel("CAP. 10 – PROCEDURA DI SPARTIZIONE DELLE ACQUE DAGLI"), 2)
    }
    func test_heading_cap_with_comma_in_title_kept() {
        // la virgola è NEL titolo, dopo il trattino → resta intestazione (regola trattino-titolo)
        XCTAssertEqual(userNotesHeadingLevel("CAP. 2 – IL CONSORZIO DEL GRANO, COOPERATIVO,"), 2)
    }
    func test_heading_sezione_mixedcase_level3() {
        XCTAssertEqual(userNotesHeadingLevel("Sezione prima – Generalità dei consorzi del grano"), 3)
        XCTAssertEqual(userNotesHeadingLevel("Sezione Terza – Le liti sull’irrigazione dei campi"), 3)
    }
    func test_heading_capitolo_full_and_others() {
        XCTAssertEqual(userNotesHeadingLevel("CAPITOLO 2 – Le impugnazioni"), 2)
        XCTAssertEqual(userNotesHeadingLevel("LIBRO PRIMO – Delle persone"), 1)
        XCTAssertEqual(userNotesHeadingLevel("TITOLO II – Dei contratti"), 1)
        XCTAssertEqual(userNotesHeadingLevel("CAPO I – Disposizioni generali"), 2)
    }

    // MARK: - Foglia intestazioni: TRAPPOLE (devono restare BODY → nil)

    func test_trap_romanLettersAreItalianWords() {
        // "di" = D,I romani; "il" = I,L romani — ma keyword minuscola + niente "– titolo"
        XCTAssertNil(userNotesHeadingLevel("parte di debito."))
        XCTAssertNil(userNotesHeadingLevel("parte il vecchio raccolto di"))
        XCTAssertNil(userNotesHeadingLevel("titolo di affitto, anche se poi"))
    }
    func test_trap_citationWithComma() {
        // dopo l'ordinale romano "IV" c'è una virgola, non il trattino → non è un'intestazione
        XCTAssertNil(userNotesHeadingLevel("Libro IV, Titolo III, Consorzi tipici o"))
    }
    func test_trap_titleWithPeriodNotDash() {
        XCTAssertNil(userNotesHeadingLevel("Parte seconda."))
    }
    func test_trap_bodySentenceStartingWithKeyword() {
        XCTAssertNil(userNotesHeadingLevel("Il capitolo terzo affronta la questione centrale."))
        XCTAssertNil(userNotesHeadingLevel("Parte della gente crede nell’estensione del consorzio"))
    }
    func test_trap_keywordOrdinalWithoutDashTitle() {
        // niente " – titolo" → fuori scope (ramo EOL escluso per ora) → nil
        XCTAssertNil(userNotesHeadingLevel("PARTE PRIMA"))
        XCTAssertNil(userNotesHeadingLevel("CAPITOLO 2"))
    }
    func test_trap_tooLong() {
        let long = "PARTE PRIMA – " + String(repeating: "a", count: 90)
        XCTAssertNil(userNotesHeadingLevel(long))
    }
    func test_trap_lowercaseKeyword() {
        XCTAssertNil(userNotesHeadingLevel("capitolo 2 – qualcosa"))  // keyword minuscola
    }

    // MARK: - Porta del ramo (matches): firma-producer robusta

    private func extraction(producer: String?, creator: String? = nil,
                            w: Double = 596, h: Double = 842) -> PdfExtraction {
        PdfExtraction(version: 2, pageCount: 1,
                      pages: [PdfPageExtraction(pageIndex: 0, width: w, height: h, lines: [])],
                      producer: producer, creator: creator)
    }

    func test_matches_googleDocs_a4_high() {
        let s = userNotesPlugin.matches(extraction(producer: "Skia/PDF m116 Google Docs Renderer"))
        XCTAssertEqual(s, 1.0, accuracy: 0.001)  // gate 0.7 + A4 0.3
    }
    func test_matches_googleDocs_nonA4_stillAboveThreshold() {
        let s = userNotesPlugin.matches(extraction(producer: "Skia/PDF Google Docs Renderer", w: 612, h: 792))
        XCTAssertGreaterThanOrEqual(s, DISPATCH_THRESHOLD)  // gate solo: 0.7 ≥ 0.6
    }
    func test_matches_nonGoogleDocs_zero() {
        XCTAssertEqual(userNotesPlugin.matches(extraction(producer: "Aspose.PDF for .NET 18.4")), 0.0)
        XCTAssertEqual(userNotesPlugin.matches(extraction(producer: "PDFsharp 1.31.1789-g")), 0.0)
        XCTAssertEqual(userNotesPlugin.matches(extraction(producer: nil)), 0.0)
    }
    func test_matches_microsoftWord_excludedThisRound() {
        // MS Word (Società quotate) è famiglia-utente ma fuori da questo ramo (commenti Word)
        XCTAssertEqual(userNotesPlugin.matches(extraction(producer: "Microsoft® Word per Microsoft 365")), 0.0)
    }
}
