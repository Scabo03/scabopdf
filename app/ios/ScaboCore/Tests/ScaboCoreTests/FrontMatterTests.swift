//
//  FrontMatterTests.swift
//  ScaboCoreTests
//
//  Riconoscimento dell'apparato di front-matter (§ docs/FRONT_MATTER.md):
//  indice/sommario → TOC_GENERAL e colophon/legale → ARTIFACT_STAMP, entrambi
//  scartati dal flusso letto ma conservati nell'albero; PREFAZIONE/INTRODUZIONE
//  (prosa) → letta SEMPRE (protezione assoluta del contenuto, anche con parole
//  legali); scope alla sola regione iniziale (back-matter intatto); astensione.
//

import XCTest
@testable import ScaboCore

final class FrontMatterTests: XCTestCase {

    private func line(_ text: String, size: Double) -> PdfTextLine {
        let bbox = BBox(x: 100, y: 0, width: Double(max(1, text.count)) * 2, height: size)
        return PdfTextLine(
            spans: [PdfSpan(text: text, fontSize: size, bold: false, italic: false, color: "#000000", bbox: bbox)],
            bbox: bbox)
    }
    private func page(_ idx: Int, _ lines: [PdfTextLine]) -> PdfPageExtraction {
        PdfPageExtraction(pageIndex: idx, width: 595, height: 842, lines: lines)
    }
    private func bodyPage(_ idx: Int, _ n: Int = 6) -> PdfPageExtraction {
        page(idx, (0..<n).map { line("Riga di corpo \($0) sufficientemente lunga da formare un paragrafo reale.", size: 10) })
    }
    private func doc(_ pages: [PdfPageExtraction]) -> ScabopdfDocument {
        buildDocumentFromPdf(PdfExtraction(version: 2, pageCount: pages.count, pages: pages), sourceName: "fm.pdf")
    }
    private func nodes(_ d: ScabopdfDocument, _ c: SemanticCategory) -> [NodeDict] { d.structure.filter { $0.type == c } }
    private func readText(_ d: ScabopdfDocument) -> String { buildBaseSegments(d).map { $0.text }.joined(separator: " ") }

    // ── indice/sommario (leader puntinati) → TOC_GENERAL, fuori dal flusso ───────────
    func test_indexPage_becomesTocGeneral_excludedFromFlow() {
        let idx = page(1, [
            line("Capitolo I L’introduzione al diritto ......................... 3", size: 10),
            line("Sezione II Le fonti normative ............................... 12", size: 10),
            line("Capitolo III Conclusioni generali ........................... 45", size: 10),
        ])
        let d = doc([bodyPage(0), idx, bodyPage(2)])
        XCTAssertEqual(nodes(d, .TOC_GENERAL).count, 1, "la pagina d'indice diventa TOC_GENERAL")
        XCTAssertFalse(readText(d).contains("L’introduzione al diritto"), "l'indice è scartato dal flusso letto")
        XCTAssertTrue(readText(d).contains("Riga di corpo"), "il corpo è letto")
    }

    // ── colophon/legale (ISBN, ©) → ARTIFACT_STAMP, fuori dal flusso ─────────────────
    func test_colophonPage_becomesArtifactStamp_excludedFromFlow() {
        let colo = page(1, [
            line("ISBN 9788828829546", size: 9),
            line("© Copyright 2021 Giuffrè Francis Lefebvre S.p.A. Milano", size: 9),
            line("Tutti i diritti sono riservati", size: 9),
        ])
        let d = doc([bodyPage(0), colo, bodyPage(2)])
        XCTAssertEqual(nodes(d, .ARTIFACT_STAMP).count, 1, "la pagina di colophon diventa ARTIFACT_STAMP")
        XCTAssertFalse(readText(d).contains("ISBN"), "il colophon è scartato dal flusso letto")
    }

    // ── PROTEZIONE: la prefazione (prosa) è letta, anche se cita parole legali ───────
    func test_prefacePage_isReadAndProtected_evenWithLegalWords() {
        let pref = page(1, [
            line("PREFAZIONE ALLA PRIMA EDIZIONE", size: 13),
            line("Questo manuale nasce da molti anni di insegnamento e affronta, ai sensi", size: 10),
            line("dell’art. 342 TFUE e della disciplina sul diritto d’autore, i temi centrali.", size: 10),
            line("La presente edizione aggiorna il testo alle riforme più recenti del settore.", size: 10),
        ])
        let d = doc([bodyPage(0), pref, bodyPage(2)])
        XCTAssertEqual(nodes(d, .ARTIFACT_STAMP).count, 0, "la prefazione NON è colophon")
        XCTAssertEqual(nodes(d, .TOC_GENERAL).count, 0, "la prefazione NON è indice")
        let read = readText(d)
        XCTAssertTrue(read.contains("Questo manuale nasce"), "la prefazione è LETTA (contenuto protetto)")
        XCTAssertTrue(read.contains("art. 342 TFUE"), "le parole legali nella prosa non causano scarto")
    }

    // ── handoff front→back: il colophon di coda è ora gestito dal back-matter ─────────
    // (era "cantiere a parte" prima di docs/BACK_MATTER.md; ora il colophon finale è
    // riconosciuto come ARTIFACT_STAMP e scartato dal flusso, simmetrico al front.)
    func test_backMatterRegion_colophonNowCaughtByBackMatter() {
        // 37 pagine: backMatterRegionStart = max(fmMax=30, 37-max(30,9)=7)=30 → p35 in coda.
        var pages = (0..<35).map { bodyPage($0) }
        pages.append(page(35, [
            line("ISBN 9999999999999", size: 9),
            line("© Copyright 2024 Editore S.p.A.", size: 9),
            line("Indice analitico abrogazione ............ 410", size: 9),
        ]))
        pages.append(bodyPage(36))
        let d = doc(pages)
        XCTAssertEqual(nodes(d, .ARTIFACT_STAMP).count, 1, "il colophon di coda (ISBN/©) è ARTIFACT_STAMP")
        XCTAssertFalse(readText(d).contains("ISBN"), "il colophon di coda è scartato dal flusso letto")
    }

    // ── astensione: pagina iniziale né colophon né indice né prosa-vuota → normale ───
    func test_abstain_ordinaryFrontPage_stillRead() {
        let ordinary = page(1, [
            line("Una pagina iniziale qualsiasi con testo ordinario di corpo, senza segnali.", size: 10),
            line("Nessun ISBN, nessun leader puntinato: deve restare letta come corpo.", size: 10),
        ])
        let d = doc([bodyPage(0), ordinary, bodyPage(2)])
        XCTAssertEqual(nodes(d, .ARTIFACT_STAMP).count, 0)
        XCTAssertEqual(nodes(d, .TOC_GENERAL).count, 0)
        XCTAssertTrue(readText(d).contains("testo ordinario di corpo"), "nel dubbio: letta")
    }

    // ── RECUPERO (rifinitura): indice INIZIALE senza leader → TOC_GENERAL, fuori flusso ─
    // (riusa il riconoscitore-indici del back-matter: titolo INDICE + struttura ≥10 voci.)
    func test_initialIndexWithoutLeaders_recovered_asTocGeneral() {
        var idx = [line("INDICE", size: 12)]
        for i in 0..<14 {
            idx.append(line("Capitolo \(i + 1) Argomento trattato nel capitolo  pag. \(i * 7 + 11)", size: 10))
        }
        let d = doc([bodyPage(0), page(1, idx), bodyPage(2)])
        XCTAssertEqual(nodes(d, .TOC_GENERAL).count, 1, "l'indice iniziale senza leader è recuperato → TOC_GENERAL")
        XCTAssertFalse(readText(d).contains("Argomento trattato"), "indice iniziale scartato dal flusso")
        XCTAssertTrue(readText(d).contains("Riga di corpo"), "il corpo è letto")
    }

    // ── PROTEZIONE: prefazione/introduzione (prosa) → LETTA, anche se nomina "indice" ─
    func test_initialPrefaceProse_isReadAndProtected_evenNamingIndex() {
        let pref = page(1, [
            line("INTRODUZIONE", size: 13),
            line("Questo lavoro nasce da una lunga ricerca e, come si vedrà nell’indice, affronta", size: 10),
            line("molti temi del diritto romano con attenzione alle fonti e alla loro tradizione.", size: 10),
            line("L’introduzione espone il metodo e i risultati principali della monografia.", size: 10),
        ])
        let d = doc([bodyPage(0), pref, bodyPage(2)])
        XCTAssertEqual(nodes(d, .TOC_GENERAL).count, 0, "la prefazione/introduzione (prosa) NON è indice")
        XCTAssertTrue(readText(d).contains("Questo lavoro nasce"), "la prosa è LETTA (contenuto protetto)")
    }

    // ── sommario col NUMERO DI PAGINA IN TESTA (Patriarca): decisione 3 del manutentore, giro finale 2026-10-08 ─
    // Prima la forma era lasciata letta per astensione; ora numeri in testa crescenti dopo il titolo «Sommario» fanno
    // della pagina un sommario non letto. L'astensione resta per la pagina con un blocco di prosa
    // (LeadingPageNumberTocTests).
    func test_initialTocWithLeadingPageNumbers_isContents_notRead() {
        var lines = [line("Sommario", size: 12)]
        for i in 0..<12 {
            lines.append(line("\(i * 10 + 5) Capitolo dedicato a un argomento di diritto commerciale", size: 10))
        }
        let d = doc([bodyPage(0), page(1, lines), bodyPage(2)])
        XCTAssertEqual(nodes(d, .TOC_GENERAL).count, 1, "numeri di pagina in testa, crescenti, dopo il titolo → sommario")
        XCTAssertFalse(readText(d).contains("argomento di diritto commerciale"), "il sommario non si legge")
    }

    // ── PAGINE DI QUESITI: le lacune a puntini fra parentesi non sono leader (giro «modulo e sommario», 2026-11-21) ─────────
    // Le righe sono inventate. Prima della cura le quattro lacune «[.....]» bastavano a fare della pagina un sommario, e la pagina
    // intera usciva dalla lettura (docs/BANCO_OCR.md § 44.4).
    func test_quizPage_bracketedGaps_isNotToc_andIsRead() {
        let quiz = page(1, [
            line("1. Il modulo azzurro si consegna entro [.....] giorni dalla convocazione del comitato.", size: 10),
            line("2. Per la tessera serve il versamento di [.....] gettoni al banco delle iscrizioni.", size: 10),
            line("3. Il turno di guardia dura [.....] ore nei mesi di vendemmia e raccolta.", size: 10),
            line("4. La seconda riunione cade [.....] settimane dopo la prima convocazione.", size: 10),
        ])
        let d = doc([bodyPage(0), quiz, bodyPage(2)])
        XCTAssertEqual(nodes(d, .TOC_GENERAL).count, 0, "le lacune fra parentesi non fanno della pagina un sommario")
        let read = readText(d)
        XCTAssertTrue(read.contains("modulo azzurro") && read.contains("seconda riunione"), "la pagina di quesiti si legge")
    }

    func test_quizPage_roundBracketsAndInnerSpaces_isNotToc() {
        let quiz = page(1, [
            line("a) La lanterna verde si accende ( .... ) minuti prima del segnale di partenza.", size: 10),
            line("b) Il carro dei bagagli parte dopo [ ..... ] fermate del percorso lungo.", size: 10),
            line("c) Le ceste di vimini pesano (.....) libbre ciascuna, coperchio escluso.", size: 10),
        ])
        let d = doc([bodyPage(0), quiz, bodyPage(2)])
        XCTAssertEqual(nodes(d, .TOC_GENERAL).count, 0)
        XCTAssertTrue(readText(d).contains("lanterna verde"))
    }

    func test_tocLines_withBracketedGapAndRealLeader_stayToc() {
        let idx = page(1, [
            line("Esercizio primo [.....] sul calendario delle maree ...................... 12", size: 10),
            line("Esercizio secondo (....) sulle rotte dei velieri ........................ 19", size: 10),
            line("Esercizio terzo sulle carte dei fondali ................................. 27", size: 10),
        ])
        let d = doc([bodyPage(0), idx, bodyPage(2)])
        XCTAssertEqual(nodes(d, .TOC_GENERAL).count, 1, "un leader vero fuori dalle parentesi conta come prima")
    }

    func test_mismatchedBrackets_stillCountAsLeaders() {
        // Nel dubbio non si tocca: solo le coppie dello stesso tipo sono lacune.
        let idx = page(1, [
            line("Voce del registro delle botteghe [.....) 4", size: 10),
            line("Voce del registro dei mulini (.....] 9", size: 10),
            line("Voce del registro delle fornaci [..... 15", size: 10),
        ])
        let d = doc([bodyPage(0), idx, bodyPage(2)])
        XCTAssertEqual(nodes(d, .TOC_GENERAL).count, 1)
    }

    /// La stessa regola vale nella regione di coda (`detectBackMatterApparatus`): una pagina di quesiti in fondo a un documento lungo
    /// si legge; un indice a leader vero in coda resta un sommario (rilievo della revisione del ramo: la coda non era provata).
    func test_quizPage_inBackMatterRegion_isRead_realTocInTail_staysToc() {
        // 37 pagine: la coda comincia a pagina 30 (come in test_backMatterRegion_colophonNowCaughtByBackMatter).
        var pages = (0..<35).map { bodyPage($0) }
        pages.append(page(35, [
            line("1. La campana del borgo suona [.....] volte al tramonto della domenica.", size: 10),
            line("2. Il mercato del pesce apre alle [.....] del mattino nei giorni pari.", size: 10),
            line("3. La barca del faro attracca al molo [.....] ogni stagione di pesca.", size: 10),
        ]))
        pages.append(bodyPage(36))
        let d = doc(pages)
        XCTAssertEqual(nodes(d, .TOC_GENERAL).count, 0, "le lacune fra parentesi non fanno della pagina di coda un sommario")
        XCTAssertTrue(readText(d).contains("campana del borgo"), "la pagina di quesiti in coda si legge")

        var withToc = (0..<35).map { bodyPage($0) }
        withToc.append(page(35, [
            line("Il molo e le sue barche ............................ 3", size: 10),
            line("Il faro e le sue luci .............................. 9", size: 10),
            line("Il borgo e le sue campane ......................... 17", size: 10),
        ]))
        withToc.append(bodyPage(36))
        XCTAssertEqual(nodes(doc(withToc), .TOC_GENERAL).count, 1, "un indice a leader vero in coda resta un sommario")
    }

    func test_hasIndexLeader_bracketedGapsVersusLeaders() {
        XCTAssertFalse(hasIndexLeader("Il valore è [.....] unità."))
        XCTAssertFalse(hasIndexLeader("Il valore è ( . . . . ) unità."))
        XCTAssertFalse(hasIndexLeader("Prima [....] e poi (.....) ancora."))
        XCTAssertTrue(hasIndexLeader("Capitolo nono ................ 41"))
        XCTAssertTrue(hasIndexLeader("Capitolo nono (Appendice) ......... 41"))
        XCTAssertTrue(hasIndexLeader("Voce [.....] e guida ........ 7"))
        XCTAssertTrue(hasIndexLeader("Voce [.....) storta"))
        XCTAssertFalse(hasIndexLeader("Tre punti soli... e basta."))
    }
}
