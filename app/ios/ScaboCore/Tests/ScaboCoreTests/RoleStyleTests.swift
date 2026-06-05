//
//  RoleStyleTests.swift
//  ScaboCoreTests
//
//  XCTest translation of `app/src/rendering/__tests__/roleStyle.test.ts` (156
//  LOC). Q2 role differentiation: the acoustic-intro mapping plus validation
//  against the real Layer 1 baselines proving the modification roles are no
//  longer acoustically undifferentiated from body prose.
//

import XCTest
@testable import ScaboCore

final class RoleStyleTests: XCTestCase {

    // MARK: acousticIntroFor

    /// TS: "maps each modification role to a distinct spoken intro".
    func test_acousticIntro_distinctPerModificationRole() {
        XCTAssertEqual(acousticIntroFor("AMENDMENT", ""), "Modifica.")
        XCTAssertEqual(acousticIntroFor("QUOTED_TEXT_OLD", ""), "Testo previgente.")
        XCTAssertEqual(acousticIntroFor("QUOTED_TEXT_NEW", ""), "Nuovo testo.")
        XCTAssertEqual(acousticIntroFor("UPDATE_BLOCK", ""), "Aggiornamento.")
        XCTAssertEqual(acousticIntroFor("EDITORIAL_NOTE", ""), "Nota editoriale.")
        // The four box roles get four distinct intros.
        let intros = Set(BOXED_ROLES.map { acousticIntroFor($0, "") })
        XCTAssertEqual(intros.count, BOXED_ROLES.count)
    }

    /// TS: "NOTE folds its length regime into the intro".
    func test_acousticIntro_noteFoldsLengthRegime() {
        XCTAssertEqual(acousticIntroFor("NOTE", "SHORT"), "Nota.")
        XCTAssertEqual(acousticIntroFor("NOTE", "LONG"), "Nota lunga.")
        XCTAssertEqual(acousticIntroFor("NOTE", "VERY_LONG"), "Nota lunga.")
        XCTAssertEqual(acousticIntroFor("NOTE", "MEGA"), "Nota molto lunga.")
    }

    /// TS: "body / article / heading / list roles get no acoustic prefix".
    func test_acousticIntro_noPrefixForStructuralRoles() {
        for role in ["BODY", "ARTICLE_BODY", "ARTICLE_HEADER", "HEADING_1", "LIST_ITEM", ""] {
            XCTAssertEqual(acousticIntroFor(role, ""), "")
        }
    }

    // MARK: role distinction on real baselines

    /// TS: "dlgs_cartabia: every modification segment carries an intro".
    func test_baseline_dlgsCartabia_everyModificationHasIntro() throws {
        let segs = buildBaseSegments(
            try loadBaselineDocument("xml_akn_baseline_dlgs_cartabia.json")
        )
        let modRoles: Set<String> = ["AMENDMENT", "QUOTED_TEXT_OLD", "QUOTED_TEXT_NEW", "UPDATE_BLOCK"]
        let modSegs = segs.filter { modRoles.contains($0.role) }
        XCTAssertGreaterThan(modSegs.count, 1000) // the doc is modification-heavy
        XCTAssertTrue(modSegs.allSatisfy { !$0.acousticIntro.isEmpty })

        let stylelessRoles: Set<String> = ["ARTICLE_BODY", "BODY"]
        let undifferentiated = segs.filter { $0.acousticIntro.isEmpty && stylelessRoles.contains($0.role) }
        let intro = segs.filter { !$0.acousticIntro.isEmpty }.count
        XCTAssertGreaterThan(Double(intro), Double(undifferentiated.count) * 0.5)
    }

    /// TS: "legge_capitali: intros line up one-to-one with roles".
    func test_baseline_leggeCapitali_introsLineUpWithRoles() throws {
        let segs = buildBaseSegments(
            try loadBaselineDocument("xml_akn_baseline_legge_capitali.json")
        )
        for s in segs {
            XCTAssertEqual(s.acousticIntro, acousticIntroFor(s.role, s.lengthCategory))
        }
    }

    // MARK: isSyntheticContainer (Punto 2 — rotor divider recognition)

    /// TS: "recognises the minted AKN container titles (HEADING_1 only)".
    func test_isSyntheticContainer_recognisesMintedTitles() {
        XCTAssertTrue(isSyntheticContainer("HEADING_1", "Modificazioni attive a altri atti"))
        XCTAssertTrue(isSyntheticContainer("HEADING_1", "Modificazioni passive di questo atto"))
        XCTAssertTrue(isSyntheticContainer("HEADING_1", "Decreto di promulgazione"))
        XCTAssertTrue(isSyntheticContainer("HEADING_1", "Aggiornamenti dell'atto"))
        XCTAssertTrue(isSyntheticContainer("HEADING_1", "Aggiornamenti all'art. 5"))
    }

    /// TS: "does not match real document headings or non-HEADING_1 roles".
    func test_isSyntheticContainer_rejectsRealHeadingsAndOtherRoles() {
        XCTAssertFalse(isSyntheticContainer("HEADING_1", "LIBRO PRIMO — DELLE PERSONE"))
        XCTAssertFalse(isSyntheticContainer("HEADING_1", "((CAPO II"))
        XCTAssertFalse(isSyntheticContainer("HEADING_1", "Disposizioni generali"))
        XCTAssertFalse(isSyntheticContainer("BODY", "Modificazioni attive a altri atti"))
        XCTAssertFalse(isSyntheticContainer("HEADING_2", "Decreto di promulgazione"))
    }

    /// TS: "acousticIntroFor maps the divider role to a short spoken prefix".
    func test_acousticIntro_dividerRole() {
        XCTAssertEqual(acousticIntroFor(SECTION_DIVIDER_ROLE, ""), "Sezione.")
    }

    // MARK: synthetic dividers on real baselines

    /// TS: "legge_capitali: both synthetic containers become SECTION_DIVIDER".
    func test_baseline_leggeCapitali_syntheticContainersBecomeDividers() throws {
        let segs = buildBaseSegments(
            try loadBaselineDocument("xml_akn_baseline_legge_capitali.json")
        )
        let dividers = segs.filter { $0.role == SECTION_DIVIDER_ROLE }
        XCTAssertEqual(dividers.count, 2)
        XCTAssertTrue(dividers.allSatisfy { $0.acousticIntro == "Sezione." })
        XCTAssertFalse(segs.contains { $0.role == "HEADING_1" })
    }

    /// TS: "EPUB codice_civile: synthetic dividers split from the real
    /// LIBRO/CAPO headings".
    func test_baseline_epubCodiceCivile_realHeadingsAndDividersCoexist() throws {
        let segs = buildBaseSegments(
            try loadBaselineDocument("epub_ipzs_baseline_codice_civile.json")
        )
        let dividers = segs.filter { $0.role == SECTION_DIVIDER_ROLE }
        let realHeadings = segs.filter { $0.role == "HEADING_1" }
        XCTAssertGreaterThan(dividers.count, 0)
        XCTAssertGreaterThan(realHeadings.count, 100) // 142 real LIBRO/CAPO
        XCTAssertTrue(realHeadings.allSatisfy { $0.acousticIntro.isEmpty })
        XCTAssertTrue(dividers.allSatisfy { $0.acousticIntro == "Sezione." })
    }
}
