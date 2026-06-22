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

    // ── astensione: titolo di sommario SENZA struttura forte (numero in testa, Patriarca) ─
    func test_initialTocTitleWithoutStructure_abstains_leftRead() {
        var lines = [line("Sommario", size: 12)]
        for i in 0..<12 {
            lines.append(line("\(i * 10 + 5) Capitolo dedicato a un argomento di diritto commerciale", size: 10))
        }
        let d = doc([bodyPage(0), page(1, lines), bodyPage(2)])
        XCTAssertEqual(nodes(d, .TOC_GENERAL).count, 0, "titolo senza struttura (numero in testa) → astensione")
        XCTAssertTrue(readText(d).contains("argomento di diritto commerciale"), "nel dubbio: letto")
    }
}
