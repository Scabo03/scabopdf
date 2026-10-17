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
        XCTAssertTrue(looksLikeBibliographyEntry("ROVERETI, Giustizia dei consorzi, in Enc. dir., vol. XII, Milano 1968, p. 413 ss."))
        XCTAssertTrue(looksLikeBibliographyEntry("AA.VV., Coltivare e custodire, a cura di Galbiati, Napoli 2018"))
        XCTAssertTrue(looksLikeBibliographyEntry("TORNAGHI, Lezioni di diritto rurale, cit., 61"))
        XCTAssertTrue(looksLikeBibliographyEntry("E. MORLACCHI, Sub artt. 120-131, in AA.VV., Commentario delle acque, p. 233"))
        XCTAssertTrue(looksLikeBibliographyEntry("P. CALVANESE, Diritto dei boschi, Milano 2004, p. 8"))
        XCTAssertTrue(looksLikeBibliographyEntry("VERHOEVEN, Le droit des digues, in «Tijdschrift», 1979, 9 ss."))
    }

    // MARK: - predicato (positivi con PARTICELLA staccata — i 3 casi reali di Lezioni)

    func test_biblio_positives_particleSurnames() {
        // "DE"/"DI"/"DELLA"… + cognome: la particella corta (2 lettere) faceva fallire il
        // token-cognome ≥3; ora è recuperata. Restano subordinati allo STILEMA + niente marcatore.
        XCTAssertTrue(looksLikeBibliographyEntry(
            "DE ROSSANO, Riti speciali dei mercati, Bologna 2011; PELLACANI, Mercato, in Dir. proc. amm., 1997, p. 715 ss."))
        XCTAssertTrue(looksLikeBibliographyEntry(
            "DE MARTINI BALDO, Sulla «perennità» del diritto delle acque, in Urb. e appalti, 2001, p. 845 ss."))
        XCTAssertTrue(looksLikeBibliographyEntry(
            "DE FALCONIERI, L’irrigazione nei consorzi – Tra equità e turni d’acqua, Torino 1996"))
        XCTAssertTrue(looksLikeBibliographyEntry("DI MAURO, La tutela dei pascoli, Milano 2005, p. 14"))
        XCTAssertTrue(looksLikeBibliographyEntry("DELLA ROVERE, Il diritto forestale, in Enc. dir., Milano 2009, p. 5 ss."))
    }

    // MARK: - predicato (negativi con particella: precisione preservata)

    func test_biblio_negatives_particleGuards() {
        // particella + cognome MA con marcatore di richiamo in testa → nota vera, MAI bibliografia
        XCTAssertFalse(looksLikeBibliographyEntry("14 DE ROSSANO, Riti speciali, cit., 12"))
        XCTAssertFalse(looksLikeBibliographyEntry("(3) DI MAURO, op. cit., p. 9"))
        // "LA"/"LO"/"LE"/"LI" sono ESCLUSE dal set: "LA CORTE, in …" (prosa) non diventa bibliografia
        XCTAssertFalse(looksLikeBibliographyEntry("LA CORTE, in una recente pronuncia, ha dichiarato inammissibile il ricorso."))
        // frontespizio: autore del libro + titolo, SENZA stilema bibliografico → non è una voce
        XCTAssertFalse(looksLikeBibliographyEntry("A. ROVERETI, Lezioni di diritto dei consorzi, 2026, ISBN 9791200000007"))
        // particella + cognome ma NESSUNO stilema → non basta l'autore
        XCTAssertFalse(looksLikeBibliographyEntry("DE ROSSANO, DE MARTINI BALDO, DE FALCONIERI"))
    }

    // MARK: - GUARDIA DI CONTENUTO: blocco di note incollate che porta contenuto ≠ bibliografia

    func test_biblio_contentGuard_gluedMultiNote_notBibliography() {
        // Forma di un caso reale (Mandrioli vol. 3), testo inventato: incipit-citazione d'autore
        // ("DE VALLE, …, in Giusto proc. civ., 2014, p. 61; …") MA il blocco prosegue con note
        // numerate che portano contenuto ("… (59) … (60) …"): NON è bibliografia.
        let glued = "DE VALLE, Profili attuali dei consorzi, in Giusto proc. civ., 2014, p. 61; "
            + "A. PELLEGRI, I turni d’acqua, cit., p. 1203. Una regola simile valeva "
            + "nell’art. 4 del regolamento. (59) Ciò comporta un’estensione dell’obbligo di "
            + "manutenzione. (60) Che potrebbe gravare anche sul comune (Cass. 2007 n. 11811)."
        XCTAssertFalse(looksLikeBibliographyEntry(glued), "blocco che porta contenuto: mai bibliografia")
        // stesso incipit senza note-in-linea (voce pura, più autori con ';') → bibliografia
        let pure = "DE VALLE, Profili attuali dei consorzi, in Giusto proc. civ., 2014, p. 61; "
            + "A. PELLEGRI, I turni d’acqua, cit., p. 1203."
        XCTAssertTrue(looksLikeBibliographyEntry(pure), "voce pura multi-autore: bibliografia")
    }

    func test_biblio_contentGuard_yearInParensStillBibliography() {
        // ramo particella + anno fra parentesi "(2019)" (4 cifre, non un marcatore di nota) →
        // la guardia di contenuto NON scatta → resta bibliografia.
        XCTAssertTrue(looksLikeBibliographyEntry(
            "DI MAURO, La tutela dei pascoli (2019), in Enc. dir., Milano 2005, p. 14 ss."))
    }

    func test_biblio_contentGuard_splitFootnoteWithProse_notBibliography() {
        // Forma di un caso reale (Mandrioli vol. 3, una nota COME LA VEDE LA LETTURA), testo
        // inventato: il blocco incollato è spezzato dal salto-pagina, così la coda "(59)…(63)"
        // non è più in questo segmento (niente marcatore in linea) MA resta prosa discorsiva.
        // La guardia di prosa ("… p. 1203. Una regola simile valeva …") lo esclude.
        let split = "DE VALLE, Profili attuali dei consorzi di bonifica e delle loro opere, "
            + "in Giusto proc. civ., 2014, p. 61; A. PELLEGRI, I turni d’acqua, cit., "
            + "p. 1203. Una regola simile valeva, con riferimento ai mulini, "
            + "nell’art. 4, 2° comma, del regolamento, anch’esso abrogato nel 2021. Anche in "
            + "quel caso era previsto che il mugnaio potesse chiudere le chiuse."
        XCTAssertFalse(looksLikeBibliographyEntry(split), "nota di piè discorsiva: mai bibliografia")
        // la guardia di prosa NON scatta su una lista di citazioni (dopo '.'/';' viene un
        // cognome MAIUSCOLETTO, non una parola Title-case): la voce-lista resta bibliografia.
        XCTAssertTrue(looksLikeBibliographyEntry(
            "DE ROSSANO, Riti speciali dei mercati, Bologna 2011. PELLACANI, Mercato, in Dir. proc. amm., 1997, p. 715 ss."))
    }

    func test_biblio_historicBranch_unaffectedByInlineAndProseGuards() {
        // Il ramo STORICO NON è soggetto alle guardie di marcatore-in-linea né di prosa-discorsiva
        // (quelle sono confinate al ramo particella). Una voce storica con incipit-citazione resta
        // accettata anche se contenesse un marcatore in linea o un sottotitolo.
        XCTAssertTrue(looksLikeBibliographyEntry(
            "ROVERETI, Giustizia dei consorzi, in Enc. dir., Milano 1968, p. 413 ss. (5) anche Corte cost."))
        // sottotitolo del libro (prosa-discorsiva-like) su ramo storico → resta bibliografia
        XCTAssertTrue(looksLikeBibliographyEntry(
            "BARALDI, L’acqua pubblica. Storia e teoria, Torino 2016, p. 377 ss."))
    }

    // MARK: - GUARDIA DI CONTENUTO UNIVERSALE: rinvio interno a un'altra nota/paragrafo ≠ bibliografia

    func test_biblio_internalXref_contentNote_notBibliography() {
        // Forma dei casi reali di Mandrioli vol. 3 (testo inventato): note discorsive che iniziano con una citazione ma rinviano
        // all'apparato interno del volume ("v. oltre, la nota N", "In proposito v. … alla nota N").
        // Una voce di bibliografia non rinvia MAI a "la nota N" del proprio volume. → mai biblio.
        XCTAssertFalse(looksLikeBibliographyEntry(
            "SPADONI, Il raccolto, cit., p. 91). In proposito v. anche Trib. Lecco 5 marzo 2004 n. 212, cit., già richiamata retro, alla nota 31. Di regola, la consegna del grano non potrà fondarsi sul solo peso dei sacchi."))
        XCTAssertFalse(looksLikeBibliographyEntry(
            "GALBIATI e, ancora, Trib. Lecco 12 ottobre 2022, già cit. retro, alla nota 19. In caso di socio assente, alla riunione del consorzio dovrebbe partecipare il delegato."))
        XCTAssertFalse(looksLikeBibliographyEntry(
            "TESTONI, op. cit., p. 43; su ciò v. oltre, la nota 205 nel § 64, dove si chiarisce il punto."))
    }

    func test_biblio_internalXref_pureLists_stillBibliography() {
        // Una LISTA di bibliografia pura, anche lunga e con sottotitoli, NON rinvia mai a "la nota N"
        // interna → resta bibliografia (le 97 voci di Lezioni non sono toccate dalla guardia xref).
        XCTAssertTrue(looksLikeBibliographyEntry(
            "AA.VV., Coltivare e custodire. Trasformazioni dei paesaggi, a cura di Galbiati, Napoli 2021; ROVERETI, Consorzi, in Enc. dir., vol. IV, Milano 1961, p. 529 ss."))
        XCTAssertTrue(looksLikeBibliographyEntry(
            "PIRANDI, Manuale di diritto delle acque, 12a ediz., Napoli 1987, pp. 103 ss. e 131 ss.; BARALDI, L’acqua pubblica. Storia e teoria, Torino 2016, p. 377 ss."))
    }

    // MARK: - predicato (negativi: l'altra direzione, nota vera / non-bibliografia)

    func test_biblio_negatives() {
        // nota VERA con marcatore di richiamo → MAI bibliografia (preserva richiamo + "Nota.")
        XCTAssertFalse(looksLikeBibliographyEntry("14 CORRADINI, Manuale di diritto forestale, in Enc. dir., Milano 1991, p. 5"))
        XCTAssertFalse(looksLikeBibliographyEntry("(7) Cfr. MORANDI, Diritto dei boschi, cit., 12"))
        XCTAssertFalse(looksLikeBibliographyEntry("5. ROVERETI, op. cit., p. 3"))
        // testatine / struttura / front-matter
        XCTAssertFalse(looksLikeBibliographyEntry("§ 2. Gli istituti della bonifica idraulica 3"))
        XCTAssertFalse(looksLikeBibliographyEntry("PREMESSA IX"))
        XCTAssertFalse(looksLikeBibliographyEntry("Avvertenza XV"))
        // citazione inline / frontespizio / prosa
        XCTAssertFalse(looksLikeBibliographyEntry("come CORRADINI, I o II)"))      // inizia minuscolo
        XCTAssertFalse(looksLikeBibliographyEntry("UGO ROVERETI, FRANCESCO PIRANDI, ANDREA MORLACCHI"))  // niente stilema
        XCTAssertFalse(looksLikeBibliographyEntry("SPADONI, 2019)"))            // niente stilema
        XCTAssertFalse(looksLikeBibliographyEntry("Il giudice ha deciso a Milano, in via definitiva, la causa"))  // Title-case, non maiuscoletto
        XCTAssertFalse(looksLikeBibliographyEntry("612 ss.; MARRI, Consorzi"))  // inizia con cifra (continuazione)
    }

    // MARK: - riclassificazione

    func test_reclassify_noteToLetteratura() {
        let out = reclassifyBibliographyEntries([
            note("ROVERETI, Giustizia dei consorzi, in Enc. dir., Milano 1968, p. 413 ss.", intro: "")
        ])
        XCTAssertEqual(out[0].role, SemanticCategory.LETTERATURA.rawValue)
        XCTAssertEqual(out[0].acousticIntro, "")   // letta, NON "Nota."
    }
    func test_reclassify_text_unchanged_reteA() {
        let t = "TORNAGHI, Lezioni, cit., 61; sul punto cfr. D. MARRI, Promemoria, cit., 717"
        let out = reclassifyBibliographyEntries([note(t)])
        XCTAssertEqual(out[0].text, t)   // testo invariato: nessuna lettera persa
    }
    func test_reclassify_markedNote_stays() {
        let out = reclassifyBibliographyEntries([note("14 CORRADINI, Manuale, in Enc. dir., p. 5", intro: "Nota.")])
        XCTAssertEqual(out[0].role, SemanticCategory.NOTE.rawValue)
        XCTAssertEqual(out[0].acousticIntro, "Nota.")   // richiamo + annuncio preservati
    }
    func test_reclassify_body_untouched() {
        // una riga di CORPO che nomina un'opera non è toccata (si tocca solo NOTE).
        let out = reclassifyBibliographyEntries([body("ROVERETI, in Enc. dir., p. 5 — citato nel testo")])
        XCTAssertEqual(out[0].role, SemanticCategory.BODY.rawValue)
    }

    // MARK: - integrazione con granularizeBody (dopo la continuità-note)

    func test_granularize_reclassifiesBibliography() {
        let segs = [
            ContentSegment(id: "h", role: SemanticCategory.HEADING_2.rawValue, text: "Bibliografia",
                           lengthCategory: "", acousticIntro: ""),
            note("ROVERETI, Giustizia dei consorzi, in Enc. dir., Milano 1968, p. 413 ss."),
            note("14 CORRADINI, Manuale, p. 5", intro: "Nota."),
        ]
        let out = granularizeBody(segs)
        let biblio = out.first { $0.text.hasPrefix("ROVERETI") }
        let realnote = out.first { $0.text.hasPrefix("14 CORRADINI") }
        XCTAssertEqual(biblio?.role, SemanticCategory.LETTERATURA.rawValue)
        XCTAssertEqual(realnote?.role, SemanticCategory.NOTE.rawValue)  // la nota vera resta
    }
}
