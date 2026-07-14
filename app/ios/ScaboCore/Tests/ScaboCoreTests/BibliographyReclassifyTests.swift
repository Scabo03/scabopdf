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

    // MARK: - predicato (positivi con PARTICELLA staccata — i 3 casi reali di Lezioni)

    func test_biblio_positives_particleSurnames() {
        // "DE"/"DI"/"DELLA"… + cognome: la particella corta (2 lettere) faceva fallire il
        // token-cognome ≥3; ora è recuperata. Restano subordinati allo STILEMA + niente marcatore.
        XCTAssertTrue(looksLikeBibliographyEntry(
            "DE NICTOLIS, Riti speciali di cognizione, Bologna 2012; MENCHINI, Processo, in Dir. proc. amm., 1999, p. 921 ss."))
        XCTAssertTrue(looksLikeBibliographyEntry(
            "DE GIORGI CEZZI, Sulla «inesauribilità» del potere amministrativo, in Urb. e appalti, 2002, p. 955 ss."))
        XCTAssertTrue(looksLikeBibliographyEntry(
            "DE LEONARDIS, L’ottemperanza nell’amministrazione – Tra imparzialità e commissario ad acta, Torino 1995"))
        XCTAssertTrue(looksLikeBibliographyEntry("DI MAJO, La tutela civile dei diritti, Milano 2003, p. 12"))
        XCTAssertTrue(looksLikeBibliographyEntry("DELLA CANANEA, Il diritto amministrativo, in Enc. dir., Milano 2010, p. 3 ss."))
    }

    // MARK: - predicato (negativi con particella: precisione preservata)

    func test_biblio_negatives_particleGuards() {
        // particella + cognome MA con marcatore di richiamo in testa → nota vera, MAI bibliografia
        XCTAssertFalse(looksLikeBibliographyEntry("14 DE NICTOLIS, Riti speciali, cit., 12"))
        XCTAssertFalse(looksLikeBibliographyEntry("(3) DI MAJO, op. cit., p. 9"))
        // "LA"/"LO"/"LE"/"LI" sono ESCLUSE dal set: "LA CORTE, in …" (prosa) non diventa bibliografia
        XCTAssertFalse(looksLikeBibliographyEntry("LA CORTE, in una recente pronuncia, ha dichiarato inammissibile il ricorso."))
        // frontespizio: autore del libro + titolo, SENZA stilema bibliografico → non è una voce
        XCTAssertFalse(looksLikeBibliographyEntry("A. TRAVI, Lezioni di giustizia amministrativa, 2026, ISBN 9791221118551"))
        // particella + cognome ma NESSUNO stilema → non basta l'autore
        XCTAssertFalse(looksLikeBibliographyEntry("DE NICTOLIS, DE GIORGI CEZZI, DE LEONARDIS"))
    }

    // MARK: - GUARDIA DI CONTENUTO: blocco di note incollate che porta contenuto ≠ bibliografia

    func test_biblio_contentGuard_gluedMultiNote_notBibliography() {
        // Caso reale Mandrioli vol. 3: incipit-citazione d'autore ("DE SANTIS, …, in Giusto
        // proc. civ., 2013, p. 55; …") MA il blocco prosegue con note numerate che portano
        // contenuto ("… (59) Ciò implica … (60) Che potrebbe …"): NON è bibliografia.
        let glued = "DE SANTIS, Profili attuali delle tutele, in Giusto proc. civ., 2013, p. 55; "
            + "A. IACOBONI, I provvedimenti cautelari, cit., p. 1305. Un’identica disposizione si "
            + "rinveniva nell’art. 8 L. div. (59) Ciò implica un’estensione dell’efficacia di titolo "
            + "esecutivo. (60) Che potrebbe essere anche la P.A. (Cass. 2006 n. 23668)."
        XCTAssertFalse(looksLikeBibliographyEntry(glued), "blocco che porta contenuto: mai bibliografia")
        // stesso incipit senza note-in-linea (voce pura, più autori con ';') → bibliografia
        let pure = "DE SANTIS, Profili attuali delle tutele, in Giusto proc. civ., 2013, p. 55; "
            + "A. IACOBONI, I provvedimenti cautelari, cit., p. 1305."
        XCTAssertTrue(looksLikeBibliographyEntry(pure), "voce pura multi-autore: bibliografia")
    }

    func test_biblio_contentGuard_yearInParensStillBibliography() {
        // ramo particella + anno fra parentesi "(2019)" (4 cifre, non un marcatore di nota) →
        // la guardia di contenuto NON scatta → resta bibliografia.
        XCTAssertTrue(looksLikeBibliographyEntry(
            "DI MAJO, La tutela civile (2019), in Enc. dir., Milano 2003, p. 12 ss."))
    }

    func test_biblio_contentGuard_splitFootnoteWithProse_notBibliography() {
        // Caso reale Mandrioli vol. 3 nota 58 COME LA VEDE LA LETTURA: il blocco incollato
        // (58…63) è spezzato dal salto-pagina, così la coda "(59)…(63)" non è più in questo
        // segmento (niente marcatore in linea) MA resta prosa discorsiva. La guardia di prosa
        // ("… p. 1305. Un'identica disposizione si rinveniva …") lo esclude.
        let split = "DE SANTIS, Profili attuali delle tutele speciali dei crediti di mantenimento, "
            + "in Giusto proc. civ., 2013, p. 55; A. IACOBONI, I provvedimenti cautelari, cit., "
            + "p. 1305. Un’identica disposizione si rinveniva, con riferimento al divorzio, "
            + "nell’art. 8, 3° comma, L. div., anch’esso abrogato dal D.Lgs. 149/2022. Anche in "
            + "questo caso si prevedeva che il coniuge potesse notificare il provvedimento."
        XCTAssertFalse(looksLikeBibliographyEntry(split), "nota di piè discorsiva: mai bibliografia")
        // la guardia di prosa NON scatta su una lista di citazioni (dopo '.'/';' viene un
        // cognome MAIUSCOLETTO, non una parola Title-case): la voce-lista resta bibliografia.
        XCTAssertTrue(looksLikeBibliographyEntry(
            "DE NICTOLIS, Riti speciali di cognizione, Bologna 2012. MENCHINI, Processo, in Dir. proc. amm., 1999, p. 921 ss."))
    }

    func test_biblio_historicBranch_unaffectedByInlineAndProseGuards() {
        // Il ramo STORICO NON è soggetto alle guardie di marcatore-in-linea né di prosa-discorsiva
        // (quelle sono confinate al ramo particella). Una voce storica con incipit-citazione resta
        // accettata anche se contenesse un marcatore in linea o un sottotitolo.
        XCTAssertTrue(looksLikeBibliographyEntry(
            "BENVENUTI, Giustizia amministrativa, in Enc. dir., Milano 1970, p. 589 ss. (5) anche Corte cost."))
        // sottotitolo del libro (prosa-discorsiva-like) su ramo storico → resta bibliografia
        XCTAssertTrue(looksLikeBibliographyEntry(
            "SCOCA, L’interesse legittimo. Storia e teoria, Torino 2017, p. 405 ss."))
    }

    // MARK: - GUARDIA DI CONTENUTO UNIVERSALE: rinvio interno a un'altra nota/paragrafo ≠ bibliografia

    func test_biblio_internalXref_contentNote_notBibliography() {
        // Casi reali Mandrioli vol. 3: note discorsive che iniziano con una citazione ma rinviano
        // all'apparato interno del volume ("v. oltre, la nota N", "In proposito v. … alla nota N").
        // Una voce di bibliografia non rinvia MAI a "la nota N" del proprio volume. → mai biblio.
        XCTAssertFalse(looksLikeBibliographyEntry(
            "BAGNATI, Il procedimento, cit., p. 83). In proposito v. anche C. Cost. 3 novembre 2005 n. 410, cit., già richiamata retro, alla nota 28. Di regola, il rigetto della domanda non potrà fondarsi sul rilievo della litispendenza."))
        XCTAssertFalse(looksLikeBibliographyEntry(
            "MANCALEONI e, ancora, Trib. Verona 24 novembre 2023, già cit. retro, alla nota 22. In caso di parte incapace, alla procedura di mediazione dovrebbe partecipare il tutore."))
        XCTAssertFalse(looksLikeBibliographyEntry(
            "GABELLINI, op. cit., p. 41; su ciò v. oltre, la nota 208 nel § 71, dove si chiarisce il punto."))
    }

    func test_biblio_internalXref_pureLists_stillBibliography() {
        // Una LISTA di bibliografia pura, anche lunga e con sottotitoli, NON rinvia mai a "la nota N"
        // interna → resta bibliografia (le 97 voci di Lezioni non sono toccate dalla guardia xref).
        XCTAssertTrue(looksLikeBibliographyEntry(
            "AA.VV., Amministrare e giudicare. Trasformazioni ordinamentali, a cura di Cerbo, Napoli 2022; BENVENUTI, Autotutela, in Enc. dir., vol. IV, Milano 1959, p. 537 ss."))
        XCTAssertTrue(looksLikeBibliographyEntry(
            "SANDULLI, Manuale di diritto amministrativo, 15a ediz., Napoli 1989, pp. 105 ss. e 134 ss.; SCOCA, L’interesse legittimo. Storia e teoria, Torino 2017, p. 405 ss."))
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
