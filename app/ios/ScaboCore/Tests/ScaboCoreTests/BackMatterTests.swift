//
//  BackMatterTests.swift
//  ScaboCoreTests
//
//  Riconoscimento dell'apparato di BACK-matter (§ docs/BACK_MATTER.md), simmetrico
//  al front-matter: colophon finale → ARTIFACT_STAMP, indice/sommario a leader →
//  TOC_GENERAL, indice dei nomi/fonti/sentenze citate → INDEX_ENTRY; tutti scartati
//  dal flusso letto ma conservati nell'albero. L'INDICE ANALITICO è RECINTATO (resta
//  letto, cantiere INDICE). APPENDICE/POSTFAZIONE (prosa) e BIBLIOGRAFIA → LETTE
//  (protezione/decisione). Scope alla sola regione finale; nel dubbio: letto.
//

import XCTest
@testable import ScaboCore

final class BackMatterTests: XCTestCase {

    private func line(_ text: String, _ size: Double = 10) -> PdfTextLine {
        let b = BBox(x: 100, y: 0, width: Double(max(1, text.count)) * 2, height: size)
        return PdfTextLine(
            spans: [PdfSpan(text: text, fontSize: size, bold: false, italic: false, color: "#000000", bbox: b)],
            bbox: b)
    }
    private func page(_ idx: Int, _ lines: [PdfTextLine]) -> PdfPageExtraction {
        PdfPageExtraction(pageIndex: idx, width: 595, height: 842, lines: lines)
    }
    /// Codice alfabetico unico per intero (le cifre verrebbero normalizzate a `#` da
    /// `detectFurniture`, quindi righe variate solo dal numero di pagina ricorrerebbero
    /// con la STESSA norm e sarebbero tolte come furniture: serve una variazione di
    /// LETTERE per pagina/riga perché il corpo sopravviva su molte pagine).
    private func tag(_ n: Int) -> String {
        let a = Array("abcdefghijklmnopqrstuvwxyz")
        return "\(a[n % 26])\(a[(n / 26) % 26])"
    }
    private func bodyPage(_ idx: Int) -> PdfPageExtraction {
        page(idx, (0..<6).map { i in
            line("Riga di corpo \(tag(idx))\(tag(i)) sufficientemente lunga da formare un paragrafo reale di lettura.", 10)
        })
    }
    /// `n` righe-voce d'indice, ognuna che finisce in un riferimento di pagina (gli
    /// indici reali hanno decine di voci per pagina: la soglia DEBOLE richiede ≥10).
    private func indexEntries(_ n: Int, _ salt: String = "") -> [PdfTextLine] {
        (0..<n).map { line("Voce d’indice \(salt)\(tag($0)), \($0 + 3)", 9) }
    }
    /// `n` voci MULTI-RIGA (corte + citazione + riferimento): solo 1 riga su 3 finisce
    /// nel riferimento → frazione bassa (~0.3) ma ≥`n` righe-voce in assoluto. Riproduce
    /// l'indice cronologico delle sentenze (Mosconi): la struttura forte da sola fallisce,
    /// lo riconosce la testatina + struttura DEBOLE.
    private func citedSentenceEntries(_ n: Int, _ salt: String = "") -> [PdfTextLine] {
        (0..<n).flatMap { i in
            [line("Cass. \(salt)\(tag(i)), \(i + 1) gennaio 1990, n. \(i + 100), parti varie", 8),
             line("(Rivista \(tag(i)) di diritto, anno e pagina iniziale della massima)", 8),
             line("\(["IV", "V", "II", "III", "I", "VI"][i % 6]), \(i + 1).", 8)]
        }
    }
    /// Documento: `body` pagine di corpo (indici 0..<body) seguite dalle `tail` già
    /// indicizzate. Le pagine di tail vanno indicizzate a partire da `body`.
    private func docPages(body: Int, tail: [PdfPageExtraction]) -> ScabopdfDocument {
        var pages = (0..<body).map { bodyPage($0) }
        pages.append(contentsOf: tail)
        return buildDocumentFromPdf(
            PdfExtraction(version: 2, pageCount: pages.count, pages: pages), sourceName: "bm.pdf")
    }
    private func nodes(_ d: ScabopdfDocument, _ c: SemanticCategory) -> [NodeDict] { d.structure.filter { $0.type == c } }
    private func readText(_ d: ScabopdfDocument) -> String { buildBaseSegments(d).map { $0.text }.joined(separator: " ") }

    // ── colophon finale (ISBN / "finito di stampare") → ARTIFACT_STAMP, fuori flusso ─
    func test_finalColophon_becomesArtifactStamp_excludedFromFlow() {
        let colo = page(34, [
            line("ISBN 9788813382230", 9),
            line("Finito di stampare nel mese di marzo 2025 nella Stampatre s.r.l. di Torino.", 9),
        ])
        let d = docPages(body: 34, tail: [colo, bodyPage(35)])   // N=36, backStart=30
        XCTAssertEqual(nodes(d, .ARTIFACT_STAMP).count, 1, "il colophon finale è ARTIFACT_STAMP")
        XCTAssertFalse(readText(d).contains("Finito di stampare"), "il colophon è scartato dal flusso letto")
        XCTAssertTrue(readText(d).contains("Riga di corpo"), "il corpo resta letto")
    }

    // ── indice/sommario generale ripetuto a leader puntinato → TOC_GENERAL ───────────
    func test_repeatedIndexWithLeaders_becomesTocGeneral_excludedFromFlow() {
        let idx = page(34, [
            line("Premessa all’undicesima edizione .................. 5", 9),
            line("Capitolo I Le fonti normative ..................... 12", 9),
            line("Capitolo II Il procedimento ....................... 45", 9),
            line("Capitolo III Le impugnazioni ...................... 89", 9),
        ])
        let d = docPages(body: 34, tail: [idx, bodyPage(35)])
        XCTAssertEqual(nodes(d, .TOC_GENERAL).count, 1, "l'indice-sommario a leader è TOC_GENERAL")
        XCTAssertFalse(readText(d).contains("Le impugnazioni"), "scartato dal flusso letto")
    }

    // ── indice dei nomi / delle fonti (titolo + voci→pagine, fortemente strutturato) ─
    func test_nameIndex_becomesIndexEntry_excludedFromFlow() {
        let p1 = page(33, [line("LE FONTI", 11), line("FONTI DI TRADIZIONE MANOSCRITTA", 9)] + indexEntries(14))
        let p2 = page(34, indexEntries(12, "x"))   // continuazione senza testatina: struttura forte
        let d = docPages(body: 33, tail: [p1, p2, bodyPage(35)])   // N=36
        XCTAssertEqual(nodes(d, .INDEX_ENTRY).count, 2, "le due pagine d'indice nomi → INDEX_ENTRY")
        XCTAssertFalse(readText(d).contains("Voce d’indice"), "indice nomi scartato (1ª e 2ª pagina, regione propagata)")
        XCTAssertTrue(readText(d).contains("Riga di corpo"), "il corpo resta letto")
    }

    // ── indice cronologico sentenze (voci MULTI-RIGA, frazione bassa) → via testatina ─
    // Riproduce Mosconi: la struttura forte fallisce (~0.3 < 0.35), ma testatina +
    // struttura debole (≥10 righe-voce) lo riconoscono; anche la testatina col FOLIO.
    func test_citedSentencesMultiLine_caughtViaHeadingAndWeak() {
        let p1 = page(34, [line("INDICE CRONOLOGICO DELLE SENTENZE CITATE", 9)] + citedSentenceEntries(12))
        let p2 = page(35, [line("555 Indice cronologico delle sentenze citate", 8)] + citedSentenceEntries(12, "y"))
        let d = docPages(body: 34, tail: [p1, p2, bodyPage(36)])   // N=37
        XCTAssertEqual(nodes(d, .INDEX_ENTRY).count, 2, "indice sentenze multi-riga via testatina (anche col folio)")
        XCTAssertFalse(readText(d).contains("gennaio 1990"), "l'indice sentenze è scartato dal flusso")
    }

    // ── FALSO POSITIVO da evitare: 'Le fonti' come TITOLO di paragrafo nel corpo ──────
    // (prosa piena, poche righe→numero → struttura DEBOLE fallisce → regione NON aperta)
    func test_bodySectionTitledLeFonti_notDiscarded() {
        var lines = [line("Le fonti", 12)]
        for i in 0..<12 {
            lines.append(line("La disciplina delle fonti \(tag(i)) si articola in una pluralità di atti normativi.", 10))
        }
        let d = docPages(body: 34, tail: [page(34, lines), bodyPage(35)])
        XCTAssertEqual(nodes(d, .INDEX_ENTRY).count, 0, "il titolo di corpo 'Le fonti' (prosa) NON apre la regione indice")
        XCTAssertTrue(readText(d).contains("disciplina delle fonti"), "il corpo è LETTO")
    }

    // ── INDICE ANALITICO recintato → LETTO (non INDEX_ENTRY, non TOC) ────────────────
    func test_analyticalIndex_isFenced_leftRead() {
        let p1 = page(34, [line("INDICE ANALITICO-ALFABETICO", 9)] + indexEntries(14))
        let d = docPages(body: 34, tail: [p1, bodyPage(35)])
        XCTAssertEqual(nodes(d, .INDEX_ENTRY).count, 0, "l'indice analitico è recintato (non INDEX_ENTRY)")
        XCTAssertEqual(nodes(d, .TOC_GENERAL).count, 0, "niente leader → niente TOC")
        XCTAssertTrue(readText(d).contains("Voce d’indice"), "l'indice analitico resta LETTO (fence)")
    }

    // ── codici: analitico (recinto) seguito dal cronologico-leggi a leader → TOC ─────
    // (regressione sull'ordine: il leader è valutato PRIMA del fence analitico, così
    // un indice cronologico a leader è scartato anche se la regione analitica è aperta.)
    func test_analyticalThenLeaderChronological_chronologicalIsToc() {
        let analytical = page(33, [line("INDICE ANALITICO", 9)] + indexEntries(12))
        let chrono = page(34, [
            line("INDICE CRONOLOGICO", 9),
            line("1913 L. 16 febbraio 1913, n. 89 ............... 45", 8),
            line("1996 L. 23 dicembre 1996, n. 662 ............. 88", 8),
            line("2017 D.lgs. 19 gennaio 2017, n. 3 ............ 120", 8),
        ])
        let d = docPages(body: 33, tail: [analytical, chrono, bodyPage(35)])
        XCTAssertEqual(nodes(d, .INDEX_ENTRY).count, 0, "l'analitico resta letto")
        XCTAssertTrue(readText(d).contains("Voce d’indice"), "analitico letto (fence)")
        XCTAssertEqual(nodes(d, .TOC_GENERAL).count, 1, "il cronologico a leader → TOC scartato")
        XCTAssertFalse(readText(d).contains("16 febbraio 1913"), "il cronologico è scartato dal flusso")
    }

    // ── APPENDICE (prosa) nella regione finale → LETTA, protetta; indice che segue scartato
    func test_appendixProse_inBackRegion_isReadAndProtected() {
        let appendix = page(33, [
            line("APPENDICE", 13),
            line("La Compagnia delle Indie: un archetipo del dominio angloamericano sul mondo.", 10),
            line("Nel Capitolo VIII si è fatto cenno al ruolo della Compagnia delle Indie nella", 10),
            line("espansione coloniale della Gran Bretagna in estremo Oriente e in altre aree.", 10),
            line("L’East India Company affascinò le menti di tanti protagonisti della rivoluzione.", 10),
        ])
        let nameIdx = page(34, [line("LE FONTI", 11)] + indexEntries(12))
        let d = docPages(body: 33, tail: [appendix, nameIdx, bodyPage(35)])
        XCTAssertTrue(readText(d).contains("La Compagnia delle Indie"), "l'appendice (prosa) è LETTA, protetta")
        XCTAssertEqual(nodes(d, .INDEX_ENTRY).count, 1, "l'indice nomi che segue è scartato")
        XCTAssertFalse(readText(d).contains("Voce d’indice"), "indice nomi scartato")
    }

    // ── BIBLIOGRAFIA → LETTA (decisione di prodotto, docs/BACK_MATTER.md) ────────────
    func test_bibliography_isLeftRead() {
        let biblio = page(34, [
            line("BIBLIOGRAFIA", 12),
            line("Ascarelli, Appunti di diritto commerciale, Roma, 1936.", 9),
            line("Auletta, Impresa e azienda, Napoli, 1958.", 9),
            line("Ferrara, Teoria giuridica dell’azienda, Firenze, 1949.", 9),
            line("Ghiron, Azienda in Nuovo dig. it., Torino, 1937.", 9),
        ])
        let d = docPages(body: 34, tail: [biblio, bodyPage(35)])
        XCTAssertEqual(nodes(d, .INDEX_ENTRY).count, 0, "la bibliografia NON è scartata")
        XCTAssertEqual(nodes(d, .ARTIFACT_STAMP).count, 0)
        XCTAssertTrue(readText(d).contains("Appunti di diritto commerciale"), "la bibliografia è LETTA")
    }

    // ── BIBLIOGRAFIA dopo un indice nomi: il titolo bibliografia CHIUDE la regione ───
    func test_bibliographyAfterNameIndex_closesRegion_leftRead() {
        let nameIdx = page(33, [line("INDICE DEI NOMI", 11)] + indexEntries(12))
        let biblio = page(34, [
            line("BIBLIOGRAFIA", 12),
            line("Bryce, The Holy Roman Empire, Oxford, 1864.", 9),
            line("Brague, Il futuro dell’Occidente, Milano, 1998.", 9),
            line("Veyne, L’Empire romain, Paris, 1980.", 9),
            line("Machiavelli, Discorsi sopra la prima deca, Torino, 1997.", 9),
        ])
        let d = docPages(body: 33, tail: [nameIdx, biblio, bodyPage(35)])
        XCTAssertEqual(nodes(d, .INDEX_ENTRY).count, 1, "solo l'indice nomi è scartato")
        XCTAssertTrue(readText(d).contains("The Holy Roman Empire"), "la bibliografia che segue è LETTA (regione chiusa)")
        XCTAssertFalse(readText(d).contains("Voce d’indice"), "l'indice nomi è scartato")
    }

    // ── astensione: pagina indice-like senza titolo riconosciuto → LETTA (nel dubbio) ─
    func test_indexLikePageWithoutHeading_isLeftRead() {
        let ambiguous = page(34, indexEntries(14))   // 14 voci→pagine ma NESSUN titolo d'indice
        let d = docPages(body: 34, tail: [ambiguous, bodyPage(35)])
        XCTAssertEqual(nodes(d, .INDEX_ENTRY).count, 0, "senza titolo d'indice riconosciuto: NON scartata")
        XCTAssertTrue(readText(d).contains("Voce d’indice"), "nel dubbio: letta")
    }

    // ── scope: una pagina colophon-like NEL MEZZO (gap front/back) → LETTA ───────────
    func test_midDocumentColophonLike_notInBackRegion_isRead() {
        // N=100: fmMax=30, backStart=max(30, 100-25)=75 → p50 è nel gap (non trattato).
        var pages = (0..<100).map { bodyPage($0) }
        pages[50] = page(50, [line("ISBN 9788828829546", 9), line("© Copyright 2021 Editore S.p.A.", 9)])
        let d = buildDocumentFromPdf(PdfExtraction(version: 2, pageCount: 100, pages: pages), sourceName: "bm.pdf")
        XCTAssertEqual(nodes(d, .ARTIFACT_STAMP).count, 0, "a metà (gap) il colophon-like NON è trattato")
    }

    // ── back-matter detection: lo stesso item per pagina nel build e in NoteBinding ──
    // (lo zip 1:1 deve restare esatto: detectBackMatterApparatus è passato a entrambi.)
    func test_backApparatusMap_isStable() {
        let colo = page(34, [line("ISBN 9788813382230", 9), line("Tutti i diritti sono riservati.", 9)])
        let ex = PdfExtraction(version: 2, pageCount: 36,
                               pages: (0..<34).map { bodyPage($0) } + [colo, bodyPage(35)])
        let furniture = detectFurniture(ex)
        let map = detectBackMatterApparatus(ex, furniture)
        XCTAssertEqual(map[34], .ARTIFACT_STAMP, "la pagina 34 (colophon) è mappata ad ARTIFACT_STAMP")
        XCTAssertNil(map[35], "il corpo finale non è apparato")
        XCTAssertNil(map[10], "le pagine di corpo iniziali non sono in mappa")
    }
}
