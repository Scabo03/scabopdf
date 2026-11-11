//
//  MiddlePieceAnchorTests.swift
//  ScaboCoreTests
//
//  I segnalibri dei PEZZI DI MEZZO al cambio di granularità (giro «prova 4, segnalibri e sigle», 2026-11-11, decisione 1 del
//  giro precedente; LAYER2 § 7.7 e § 12.14). Un blocco del corpo che a una granularità più ampia finisce DENTRO un blocco
//  nuovo, o A CAVALLO di due blocchi nuovi, si ritrova lì per contenuto (impronta intera del tratto, inizio e fine di parola, una
//  posizione sola nella finestra di pagine) e conserva l'ancora d'origine, così al ritorno torna esattamente sul suo pezzo.
//  Resta «da ricollocare» quando il contenuto non si ritrova con certezza: due posizioni, o un testo che stava già dentro un
//  altro segmento quando l'ancora è nata. Lo stesso per la posizione di lettura e per le sottolineature. Testi SINTETICI e neutri.
//

import XCTest
@testable import ScaboCore

final class MiddlePieceAnchorTests: XCTestCase {

    private func seg(_ id: String, _ text: String, role: String = "BODY", page: Int? = 7) -> ContentSegment {
        ContentSegment(id: id, role: role, text: text, lengthCategory: "", acousticIntro: "", sourcePage: page)
    }

    /// Sei frasi inventate e distinte, ciascuna ben sopra le 64 lettere.
    private let s = [
        "Il cartografo traccia sul foglio la costa frastagliata dell'isola e segna con un punto rosso ogni approdo sicuro.",
        "Il suo aiutante misura le distanze col compasso d'ottone e scrive i numeri in colonna sul margine del quaderno.",
        "Al tramonto la lanterna della torretta illumina il tavolo e le carte si coprono di ombre lunghe e tremolanti.",
        "Il vecchio capitano entra senza bussare, appoggia il cappello bagnato sulla sedia e chiede notizie della rotta.",
        "La risposta del cartografo è lenta e precisa, perché ogni errore sulla carta diventa uno scoglio sotto la chiglia.",
        "Prima di mezzanotte la mappa è finita, arrotolata con cura e chiusa nel tubo di cuoio che partirà con la nave.",
    ]

    private func reanchor(_ b: [Bookmark], _ u: [Underline] = [], position: Int = 0, anchor: ContentAnchor? = nil,
                          in f: [ContentSegment]) -> ReanchoredAnnotations {
        AnnotationReanchoring.reanchor(bookmarks: b, underlines: u, readingPosition: position, readingAnchor: anchor,
                                       in: ContentAnchorIndex(segments: f))
    }

    private func bookmark(on i: Int, in f: [ContentSegment]) throws -> Bookmark {
        Bookmark(id: "b\(i)", anchorSegmentId: f[i].id, orderIndexHint: i, preview: "", originalPage: f[i].sourcePage,
                 createdAt: Date(), anchor: try XCTUnwrap(ContentAnchorIndex(segments: f).anchor(forIndex: i)))
    }

    private func inPlace(_ r: ReanchoredAnnotations, in f: [ContentSegment]) -> Bool {
        !AnnotationReanchoring.needsReanchoring(bookmarks: r.bookmarks, underlines: r.underlines, readingPosition: r.readingPosition,
                                                readingAnchor: r.readingAnchor, in: ContentAnchorIndex(segments: f))
    }

    // MARK: - A cavallo di due blocchi

    /// A: [s0 s1] [s2 s3] [s4 s5]; B: [s0 s1 s2] [s3 s4 s5]: il pezzo di mezzo di A comincia in B1 e finisce in B2.
    private var fineFlow: [ContentSegment] {
        [seg("t", "Capitolo della mappa", role: "HEADING_2"),
         seg("a1", s[0] + " " + s[1]), seg("a2", s[2] + " " + s[3]), seg("a3", s[4] + " " + s[5])]
    }
    private var shiftedFlow: [ContentSegment] {
        [seg("t", "Capitolo della mappa", role: "HEADING_2"),
         seg("b1", s[0] + " " + s[1] + " " + s[2]), seg("b2", s[3] + " " + s[4] + " " + s[5])]
    }

    func test_pezzoACavallo_vaNelBloccoDoveComincia_conLaCatena_eTorna() throws {
        let a = fineFlow, b = shiftedFlow
        let start = try bookmark(on: 2, in: a)
        let r = ContentAnchorIndex(segments: b).resolve(try XCTUnwrap(start.anchor))
        XCTAssertEqual(r.level, .contained)
        XCTAssertEqual(r.index, 1, "il testo comincia nel primo dei due blocchi")
        XCTAssertEqual(r.regionChain, [1, 2])
        let there = reanchor([start], in: b)
        XCTAssertNil(there.bookmarks[0].isOrphan)
        XCTAssertEqual(there.bookmarks[0].anchorSegmentId, "b1")
        XCTAssertTrue(inPlace(there, in: b))
        let back = reanchor(there.bookmarks, in: a)
        XCTAssertEqual(back.bookmarks[0].anchorSegmentId, "a2", "tornato esattamente sul suo pezzo")
        XCTAssertTrue(inPlace(back, in: a))
    }

    func test_citazioneNelPezzoACavallo_siRitrovaNellaParteSeguente_eTorna() throws {
        let a = fineFlow, b = shiftedFlow
        // Quattro parole della seconda frase del pezzo, che in B sta nel secondo blocco.
        let words = WordTokenizer.words(a[2].text)
        let w0 = try XCTUnwrap(words.firstIndex(of: "appoggia")), w1 = w0 + 3
        let q = try XCTUnwrap(ContentAnchorIndex(segments: a).quoteAnchor(forIndex: 2, startWord: w0, endWord: w1))
        let u = Underline(id: "u", spans: [UnderlineSpan(segmentId: "a2", startWord: w0, endWord: w1, anchor: q)], preview: "",
                          createdAt: Date())
        let there = reanchor([], [u], in: b)
        XCTAssertNil(there.underlines[0].isOrphan)
        XCTAssertEqual(there.underlines[0].spans.map { $0.segmentId }, ["b2"])
        let bw = WordTokenizer.words(b[2].text)
        let sp = there.underlines[0].spans[0]
        XCTAssertEqual(Array(bw[sp.startWord...sp.endWord]), Array(words[w0...w1]), "le stesse parole")
        let back = reanchor([], there.underlines, in: a)
        XCTAssertEqual(back.underlines[0].spans.map { [$0.segmentId, "\($0.startWord)", "\($0.endWord)"] }, [["a2", "\(w0)", "\(w1)"]])
    }

    // MARK: - Testi corti, segno al conio, ambiguità

    func test_testoCorto_dentroUnBlocco_siRitrova_soloSeUnico() throws {
        let corto = "Vedi la mappa nel tubo."
        let a = [seg("x1", s[0]), seg("x2", corto), seg("x3", s[1])]
        let b = [seg("y1", s[0] + " " + corto + " " + s[1])]
        let start = try bookmark(on: 1, in: a)
        let there = reanchor([start], in: b)
        XCTAssertNil(there.bookmarks[0].isOrphan)
        XCTAssertEqual(there.bookmarks[0].anchorSegmentId, "y1")
        XCTAssertEqual(reanchor(there.bookmarks, in: a).bookmarks[0].anchorSegmentId, "x2")
        // Due volte nel blocco nuovo: ambiguo, da ricollocare.
        let twice = [seg("y1", s[0] + " " + corto + " " + s[1] + " " + corto)]
        XCTAssertEqual(reanchor([start], in: twice).bookmarks[0].isOrphan, true)
    }

    func test_testoGiaDentroUnAltroBlocco_alConio_restaDaRicollocare() throws {
        // Il pezzo era già citato, intero, dentro un altro blocco della finestra quando il segnalibro è nato: il riscontro «dentro»
        // non vale per lui (potrebbe essere la citazione), e tolto il pezzo resta da ricollocare.
        let citazione = "Come racconta il diario di bordo, scritto a lume di candela: " + s[2] + " " + s[3]
            + " Così termina la pagina del diario e comincia il racconto del ritorno."
        let a = [seg("x1", s[2] + " " + s[3]), seg("x2", citazione)]
        let anchor = try XCTUnwrap(ContentAnchorIndex(segments: a).anchor(forIndex: 0))
        XCTAssertEqual(anchor.interiorElsewhere, true)
        let b = [seg("x2", citazione)]
        XCTAssertEqual(ContentAnchorIndex(segments: b).resolve(anchor).level, .orphan)
        // La stessa ancora senza il segno (coniata dalle build di prima) si ritroverebbe: il segno è la prudenza.
        var vecchia = anchor; vecchia.interiorElsewhere = nil
        XCTAssertEqual(ContentAnchorIndex(segments: b).resolve(vecchia).level, .contained)
    }

    func test_dueBlocchiNuoviContengonoIlPezzo_restaDaRicollocare() throws {
        let a = fineFlow
        let start = try bookmark(on: 2, in: a)
        let b = [seg("b1", s[0] + " " + s[2] + " " + s[3] + " " + s[1]), seg("b2", s[4] + " " + s[2] + " " + s[3] + " " + s[5])]
        XCTAssertEqual(reanchor([start], in: b).bookmarks[0].isOrphan, true, "due posizioni: mai una scelta a caso")
    }

    func test_dentroUnTitolo_nonSiCerca() throws {
        // Il riscontro «dentro» vale per il corpo (e per i pezzi delle note): un segnalibro di corpo non va dentro un titolo.
        let a = [seg("x1", s[0]), seg("x2", s[1])]
        let b = [seg("y1", s[0]), seg("h", "Titolo: " + s[1] + " e altro ancora", role: "HEADING_3")]
        XCTAssertEqual(reanchor([try bookmark(on: 1, in: a)], in: b).bookmarks[0].isOrphan, true)
    }

    // MARK: - La finestra di pagine sulle pagine coperte

    func test_bloccoLargoCominciatoPagineIndietro_siRitrova() throws {
        // Un libro con poche righe per pagina: a 400 il pezzo sta a pagina 12, a 1.200 il blocco che lo contiene comincia a
        // pagina 8 e copre fino a 12 (il segmento seguente comincia a 13).
        let a = [seg("h", "Capitolo", role: "HEADING_1", page: 8), seg("p1", s[0], page: 8), seg("p2", s[1], page: 10),
                 seg("p3", s[2], page: 12), seg("h2", "Capitolo seguente", role: "HEADING_1", page: 13)]
        let b = [seg("h", "Capitolo", role: "HEADING_1", page: 8), seg("q", s[0] + " " + s[1] + " " + s[2], page: 8),
                 seg("h2", "Capitolo seguente", role: "HEADING_1", page: 13)]
        let there = reanchor([try bookmark(on: 3, in: a)], in: b)
        XCTAssertNil(there.bookmarks[0].isOrphan)
        XCTAssertEqual(there.bookmarks[0].anchorSegmentId, "q")
        XCTAssertEqual(reanchor(there.bookmarks, in: a).bookmarks[0].anchorSegmentId, "p3")
    }

    func test_bloccoLontanoDallaPagina_nonSiCerca() throws {
        // Lo stesso testo dentro un blocco che non tocca la finestra di pagine: da ricollocare.
        let a = [seg("p1", s[0], page: 12), seg("p2", s[1], page: 12)]
        let b = [seg("q", s[0] + " " + s[1], page: 30), seg("r", s[2], page: 31)]
        XCTAssertEqual(reanchor([try bookmark(on: 1, in: a)], in: b).bookmarks[0].isOrphan, true)
    }

    // MARK: - Le citazioni: il ripiego dei vicini e le parole senza lettere

    func test_citazioneAmbiguaNelSuoBlocco_nonVaNelBloccoVicino() throws {
        // Quattro parole ripetute due volte nel blocco con lo stesso contesto: la citazione lì è ambigua e resta da ricollocare;
        // il blocco vicino della stessa pagina, che le contiene una volta sola, NON è il suo posto.
        let frase = "Ogni sera il mozzo grida terra in vista dalla coffa dell'albero maestro e tutti corrono a prua."
        let x = seg("x", s[0] + " " + frase + " " + s[1] + " " + frase + " " + s[2])
        let y = seg("y", s[3] + " " + frase + " " + s[4])
        let a = [x, y]
        let words = WordTokenizer.words(x.text)
        let w0 = try XCTUnwrap(words.firstIndex(of: "terra")), w1 = w0 + 3
        let q = try XCTUnwrap(ContentAnchorIndex(segments: a).quoteAnchor(forIndex: 0, startWord: w0, endWord: w1))
        let u = Underline(id: "u", spans: [UnderlineSpan(segmentId: "x", startWord: w0, endWord: w1, anchor: q)], preview: "",
                          createdAt: Date())
        let r = reanchor([], [u], in: a)
        XCTAssertEqual(r.underlines[0].isOrphan, true, "ambigua: dichiarata, mai spostata sul gemello del vicino")
    }

    func test_citazioneDopoUnaSpezzatura_siCercaAncoraNelPezzoSeguente() throws {
        // Il ripiego dei vicini resta per la spezzatura: il blocco è diviso (il primo pezzo è un suo pezzo iniziale, il seguente
        // ha anche altro testo) e la citazione è finita nel pezzo seguente.
        let a = [seg("x", s[0] + " " + s[1] + " " + s[2])]
        let b = [seg("x1", s[0] + " " + s[1]), seg("x2", s[2] + " " + s[3])]
        let words = WordTokenizer.words(a[0].text)
        let w0 = try XCTUnwrap(words.firstIndex(of: "lanterna")), w1 = w0 + 3
        let q = try XCTUnwrap(ContentAnchorIndex(segments: a).quoteAnchor(forIndex: 0, startWord: w0, endWord: w1))
        let u = Underline(id: "u", spans: [UnderlineSpan(segmentId: "x", startWord: w0, endWord: w1, anchor: q)], preview: "",
                          createdAt: Date())
        let r = reanchor([], [u], in: b)
        XCTAssertNil(r.underlines[0].isOrphan)
        XCTAssertEqual(r.underlines[0].spans.map { $0.segmentId }, ["x2"])
    }

    func test_pezzoInCodaCheRipeteLInizioDelBlocco_laCitazioneTornaNelSuoTratto() throws {
        // A: due pezzi che cominciano con lo stesso titolo lungo (una bibliografia che ripete un titolo); B: un blocco solo, che
        // ha la testa del pezzo di coda (il titolo ripetuto) e la sua coda. Non è un interno ritoccato: il pezzo sta intero in
        // coda al blocco, e la sottolineatura sulle sue prime parole deve tornare lì, non sulla ripetizione all'inizio.
        let titolo = "Il registro dei mulini e dei ponti di pietra della valle dei pastori, con le carte delle chiuse e dei canali"
        let primo = titolo + ", prima edizione, stampata dal tipografo del borgo con le tavole incise in rame, pagine dieci-venti."
        let secondo = titolo + ", seconda edizione, riveduta dal curatore con un indice dei nomi e delle località, pagine trenta-quaranta."
        let a = [seg("p1", primo), seg("p2", secondo)]
        let b = [seg("q", primo + " " + secondo)]
        let q = try XCTUnwrap(ContentAnchorIndex(segments: a).quoteAnchor(forIndex: 1, startWord: 0, endWord: 3))
        let r = ContentAnchorIndex(segments: b).resolve(q.segment)
        XCTAssertEqual(r.level, .contained, "fusione col pezzo intero in coda, non testa e coda di un interno ritoccato")
        XCTAssertEqual(r.regionStart, TextFingerprint.normalize(primo).count)
        let u = Underline(id: "u", spans: [UnderlineSpan(segmentId: "p2", startWord: 0, endWord: 3, anchor: q)], preview: "",
                          createdAt: Date())
        let there = reanchor([], [u], in: b)
        let offset = WordTokenizer.wordCount(primo)
        XCTAssertEqual(there.underlines[0].spans.map { [$0.segmentId, "\($0.startWord)", "\($0.endWord)"] },
                       [["q", "\(offset)", "\(offset + 3)"]], "nel tratto del pezzo, non sul titolo ripetuto all'inizio")
        let back = reanchor([], there.underlines, in: a)
        XCTAssertEqual(back.underlines[0].spans.map { [$0.segmentId, "\($0.startWord)", "\($0.endWord)"] }, [["p2", "0", "3"]])
    }

    func test_testoRipetutoNelBloccoFuso_laCitazioneNonVaSulGemello() throws {
        // A: [c1: frase, gemello, frase] [c2: il gemello da solo]; B: un blocco solo, c1 + c2. Il pezzo c2 sta intero in coda al
        // blocco, ma lo stesso testo compare anche nel mezzo: il blocco è giusto (segnalibro e posizione vanno lì), il tratto no,
        // e una sottolineatura con le stesse parole nei due gemelli resta da ricollocare, mai sul gemello.
        let gemello = "Il pedaggio del ponte si paga al casello della torre secondo la tariffa che il consiglio del borgo fissa ogni anno."
        let a = [seg("c1", s[0] + " " + gemello + " " + s[1]), seg("c2", gemello)]
        let b = [seg("q", s[0] + " " + gemello + " " + s[1] + " " + gemello)]
        let there = reanchor([try bookmark(on: 1, in: a)], in: b)
        XCTAssertEqual(there.bookmarks[0].anchorSegmentId, "q")
        XCTAssertNil(there.bookmarks[0].isOrphan)
        let q = try XCTUnwrap(ContentAnchorIndex(segments: a).quoteAnchor(forIndex: 1, startWord: 3, endWord: 6))
        let r = ContentAnchorIndex(segments: b).resolve(q.segment)
        XCTAssertEqual(r.level, .contained)
        XCTAssertEqual(r.ambiguousRegionStarts?.count, 2, "il vecchio testo compare due volte nel blocco")
        let u = Underline(id: "u", spans: [UnderlineSpan(segmentId: "c2", startWord: 3, endWord: 6, anchor: q)], preview: "",
                          createdAt: Date())
        XCTAssertEqual(reanchor([], [u], in: b).underlines[0].isOrphan, true, "tratto ambiguo: dichiarata, mai sul gemello")
        // Il controllo: senza la ripetizione il tratto è uno e la citazione va al suo posto, in coda.
        let a2 = [seg("c1", s[0] + " " + s[1]), seg("c2", gemello)]
        let b2 = [seg("q", s[0] + " " + s[1] + " " + gemello)]
        let q2 = try XCTUnwrap(ContentAnchorIndex(segments: a2).quoteAnchor(forIndex: 1, startWord: 3, endWord: 6))
        XCTAssertNil(ContentAnchorIndex(segments: b2).resolve(q2.segment).ambiguousRegionStarts)
        let u2 = Underline(id: "u", spans: [UnderlineSpan(segmentId: "c2", startWord: 3, endWord: 6, anchor: q2)], preview: "",
                           createdAt: Date())
        let offset = WordTokenizer.wordCount(s[0] + " " + s[1])
        XCTAssertEqual(reanchor([], [u2], in: b2).underlines[0].spans.map { [$0.segmentId, "\($0.startWord)", "\($0.endWord)"] },
                       [["q", "\(offset + 3)", "\(offset + 6)"]])
    }

    func test_spanSeparatiSoloDaUnaLineetta_tornanoUnoSolo() throws {
        // A: un blocco «… alfa beta — gamma delta …»; B: due blocchi, il secondo comincia con la lineetta. La sottolineatura su
        // «beta — gamma delta» in B sono due span; tornando ad A torna uno span solo, con la lineetta dentro.
        let uno = "Il nostromo conta le casse sulla banchina del porto e annota il peso di ognuna sul registro di bordo."
        let due = "— Le ultime casse arrivano col carro del mattino insieme alle botti di acqua dolce per il lungo viaggio."
        let a = [seg("x", uno + " " + due)]
        let b = [seg("x1", uno), seg("x2", due)]
        let words = WordTokenizer.words(a[0].text)
        let w0 = try XCTUnwrap(words.firstIndex(of: "bordo.")), w1 = w0 + 3   // «bordo.» «—» «Le» «ultime»
        XCTAssertEqual(words[w0 + 1], "—")
        let q = try XCTUnwrap(ContentAnchorIndex(segments: a).quoteAnchor(forIndex: 0, startWord: w0, endWord: w1))
        let u = Underline(id: "u", spans: [UnderlineSpan(segmentId: "x", startWord: w0, endWord: w1, anchor: q)], preview: "",
                          createdAt: Date())
        let there = reanchor([], [u], in: b)
        XCTAssertEqual(there.underlines[0].spans.map { $0.segmentId }, ["x1", "x2"])
        let back = reanchor([], there.underlines, in: a)
        XCTAssertEqual(back.underlines[0].spans.map { [$0.segmentId, "\($0.startWord)", "\($0.endWord)"] }, [["x", "\(w0)", "\(w1)"]],
                       "uno span solo, come prima")
    }
}
