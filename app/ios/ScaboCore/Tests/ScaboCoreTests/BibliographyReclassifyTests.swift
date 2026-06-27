//
//  BibliographyReclassifyTests.swift
//  ScaboCoreTests
//
//  Bibliografia in corpo-piccolo: riconoscimento alla radice (NOTE → LETTERATURA).
//  Una voce "AUTORE, opera, in Riv., …, p. N ss." è riconosciuta per ciò che è e
//  riclassificata LETTERATURA (letta, non annunciata "Nota."), MAI una nota con richiamo.
//  Precisione: il rischio è l'altra direzione (nota vera scambiata per bibliografia) →
//  guardia "solo NOTE senza marcatore" + pattern autore-maiuscoletto + stilema.
//

import XCTest
@testable import ScaboCore

final class BibliographyReclassifyTests: XCTestCase {

    private func note(_ t: String, intro: String = "") -> ContentSegment {
        ContentSegment(id: "n", role: SemanticCategory.NOTE.rawValue, text: t,
                       lengthCategory: "SHORT", acousticIntro: intro)
    }
    private func body(_ t: String) -> ContentSegment {
        ContentSegment(id: "b", role: SemanticCategory.BODY.rawValue, text: t,
                       lengthCategory: "", acousticIntro: "")
    }

    // MARK: - predicato (positivi)

    func test_biblio_positives() {
        XCTAssertTrue(looksLikeBibliographyEntry("BENVENUTI, Giustizia amministrativa, in Enc. dir., vol. XIX, Milano 1970, p. 589 ss."))
        XCTAssertTrue(looksLikeBibliographyEntry("AA.VV., Amministrare e giudicare, a cura di Cerbo, Napoli 2019"))
        XCTAssertTrue(looksLikeBibliographyEntry("FALCON, Lezioni di diritto amministrativo, cit., 59"))
        XCTAssertTrue(looksLikeBibliographyEntry("E. VULLO, Sub artt. 409-421, in AA.VV., Commentario del c.p.c., p. 281"))
        XCTAssertTrue(looksLikeBibliographyEntry("P. VIRGA, Diritto amministrativo, Milano 2003, p. 6"))
        XCTAssertTrue(looksLikeBibliographyEntry("HUUSSEN, Le droit de mariage, in «Tijdschrift», 1976, 7 ss."))
    }

    // MARK: - predicato (negativi: l'altra direzione, nota vera / non-bibliografia)

    func test_biblio_negatives() {
        // nota VERA con marcatore di richiamo → MAI bibliografia (preserva richiamo + "Nota.")
        XCTAssertFalse(looksLikeBibliographyEntry("14 ANTOLISEI, Manuale di diritto penale, in Enc. dir., Milano 1990, p. 5"))
        XCTAssertFalse(looksLikeBibliographyEntry("(7) Cfr. GIANNINI, Diritto amministrativo, cit., 12"))
        XCTAssertFalse(looksLikeBibliographyEntry("5. BENVENUTI, op. cit., p. 3"))
        // testatine / struttura / front-matter
        XCTAssertFalse(looksLikeBibliographyEntry("§ 2. Gli istituti della giustizia amministrativa 3"))
        XCTAssertFalse(looksLikeBibliographyEntry("PREMESSA IX"))
        XCTAssertFalse(looksLikeBibliographyEntry("Avvertenza XV"))
        // citazione inline / frontespizio / prosa
        XCTAssertFalse(looksLikeBibliographyEntry("come ANTOLISEI, I o II)"))      // inizia minuscolo
        XCTAssertFalse(looksLikeBibliographyEntry("UGO DRAETTA, FRANCESCO BESTAGNO, ANDREA SANTINI"))  // niente stilema
        XCTAssertFalse(looksLikeBibliographyEntry("VENEZIANI, 2019)"))            // niente stilema
        XCTAssertFalse(looksLikeBibliographyEntry("Il giudice ha deciso a Milano, in via definitiva, la causa"))  // Title-case, non maiuscoletto
        XCTAssertFalse(looksLikeBibliographyEntry("508 ss.; SORDI, Giustizia"))  // inizia con cifra (continuazione)
    }

    // MARK: - riclassificazione

    func test_reclassify_noteToLetteratura() {
        let out = reclassifyBibliographyEntries([
            note("BENVENUTI, Giustizia amministrativa, in Enc. dir., Milano 1970, p. 589 ss.", intro: "")
        ])
        XCTAssertEqual(out[0].role, SemanticCategory.LETTERATURA.rawValue)
        XCTAssertEqual(out[0].acousticIntro, "")   // letta, NON "Nota."
    }
    func test_reclassify_text_unchanged_reteA() {
        let t = "FALCON, Lezioni, cit., 59; sul punto cfr. D. SORACE, Promemoria, cit., 753"
        let out = reclassifyBibliographyEntries([note(t)])
        XCTAssertEqual(out[0].text, t)   // testo invariato: nessuna lettera persa
    }
    func test_reclassify_markedNote_stays() {
        let out = reclassifyBibliographyEntries([note("14 ANTOLISEI, Manuale, in Enc. dir., p. 5", intro: "Nota.")])
        XCTAssertEqual(out[0].role, SemanticCategory.NOTE.rawValue)
        XCTAssertEqual(out[0].acousticIntro, "Nota.")   // richiamo + annuncio preservati
    }
    func test_reclassify_body_untouched() {
        // una riga di CORPO che nomina un'opera non è toccata (si tocca solo NOTE).
        let out = reclassifyBibliographyEntries([body("BENVENUTI, in Enc. dir., p. 5 — citato nel testo")])
        XCTAssertEqual(out[0].role, SemanticCategory.BODY.rawValue)
    }

    // MARK: - integrazione con granularizeBody (dopo la continuità-note)

    func test_granularize_reclassifiesBibliography() {
        let segs = [
            ContentSegment(id: "h", role: SemanticCategory.HEADING_2.rawValue, text: "Bibliografia",
                           lengthCategory: "", acousticIntro: ""),
            note("BENVENUTI, Giustizia amministrativa, in Enc. dir., Milano 1970, p. 589 ss."),
            note("14 ANTOLISEI, Manuale, p. 5", intro: "Nota."),
        ]
        let out = granularizeBody(segs)
        let biblio = out.first { $0.text.hasPrefix("BENVENUTI") }
        let realnote = out.first { $0.text.hasPrefix("14 ANTOLISEI") }
        XCTAssertEqual(biblio?.role, SemanticCategory.LETTERATURA.rawValue)
        XCTAssertEqual(realnote?.role, SemanticCategory.NOTE.rawValue)  // la nota vera resta
    }
}
