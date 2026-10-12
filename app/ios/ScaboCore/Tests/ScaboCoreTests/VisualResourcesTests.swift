//
//  VisualResourcesTests.swift
//  ScaboCoreTests
//
//  Guardia e inserimento delle risorse visive (`VisualResources.swift`) su dati sintetici: righe e segmenti
//  con parole di prova, mai testo di volumi.
//

import XCTest
@testable import ScaboCore

final class VisualResourcesTests: XCTestCase {

    // Pagina 600×800 pt. Le righe si danno in coordinate ALTO-sinistra per comodità e si convertono.
    private let W = 600.0, H = 800.0

    private func line(_ text: String, l: Double, t: Double, r: Double, b: Double, size: Double = 10, spans: [PdfSpan]? = nil) -> PdfTextLine {
        let box = BBox(x: l, y: H - b, width: r - l, height: b - t)
        return PdfTextLine(spans: spans ?? [PdfSpan(text: text, fontSize: size, bold: false, italic: false, color: "#000000", bbox: box)], bbox: box)
    }

    private func extraction(_ pages: [[PdfTextLine]]) -> PdfExtraction {
        PdfExtraction(version: 2, pageCount: pages.count,
                      pages: pages.enumerated().map { PdfPageExtraction(pageIndex: $0.offset, width: W, height: H, lines: $0.element) })
    }

    private func seg(_ id: String, _ role: String = "BODY", _ text: String, page: Int) -> ContentSegment {
        ContentSegment(id: id, role: role, text: text, lengthCategory: "", acousticIntro: acousticIntroFor(role, ""), sourcePage: page)
    }

    private func candidate(_ label: String, page: Int = 0, _ bbox: [Double], caption: [Double]? = nil,
                           prev: [Double]? = nil, next: [Double]? = nil) -> VisualRegionCandidate {
        VisualRegionCandidate(pageIndex: page, label: label, bbox: bbox, confidence: 0.9, captionBBox: caption,
                              pageWidth: W, pageHeight: H, previousTextBBox: prev, nextTextBBox: next)
    }

    /// Pagina tipo: un capoverso, una tabella di tre righe, un altro capoverso.
    private func paginaConTabella() -> (PdfExtraction, [ContentSegment]) {
        let ex = extraction([[
            line("primo capoverso di prova con parole qualsiasi", l: 50, t: 100, r: 550, b: 112, size: 11),
            line("colonna alfa valore beta riga uno", l: 60, t: 200, r: 540, b: 210),
            line("colonna gamma valore delta riga due", l: 60, t: 212, r: 540, b: 222),
            line("colonna epsilon valore zeta riga tre", l: 60, t: 224, r: 540, b: 234),
            line("secondo capoverso di prova dopo la tabella", l: 50, t: 300, r: 550, b: 312, size: 11),
        ]])
        let segs = [
            seg("n1", "BODY", "primo capoverso di prova con parole qualsiasi", page: 1),
            seg("n2", "NOTE", "colonna alfa valore beta riga uno colonna gamma valore delta riga due colonna epsilon valore zeta riga tre", page: 1),
            seg("n3", "BODY", "secondo capoverso di prova dopo la tabella", page: 1),
        ]
        return (ex, segs)
    }

    func test_tabellaAccettata_elementoInseritoPrimaDelSuoTesto_testoIntatto() {
        let (ex, segs) = paginaConTabella()
        let (out, report) = insertingVisualResources(segs, candidates: [candidate("table", [55, 195, 545, 240])], extraction: ex)
        XCTAssertEqual(out.count, 4)
        XCTAssertEqual(out[1].role, VISUAL_RESOURCE_ROLE)
        XCTAssertEqual(out[1].text, "Tabella")
        XCTAssertEqual(out[1].acousticIntro, "Risorsa visiva.")
        XCTAssertEqual(out[1].sourcePage, 1)
        XCTAssertEqual(out[1].visualResource, VisualResourcePayload(kind: .table, pageIndex: 0, bbox: [55, 195, 545, 240], containedElements: 1))
        // Nessun testo perso, spostato o cambiato: tolto l'elemento nuovo il flusso è identico.
        XCTAssertEqual(out.filter { $0.role != VISUAL_RESOURCE_ROLE }, segs)
        XCTAssertEqual(report.acceptedTables, 1)
        XCTAssertEqual(report.decisions.first?.insertedAt, 1)
    }

    func test_didascaliaNelTestoDellElemento() {
        var (ex, segs) = paginaConTabella()
        ex.pages[0].lines.insert(line("prospetto di prova numero uno", l: 60, t: 180, r: 400, b: 190, size: 9), at: 1)
        segs.insert(seg("c1", "NOTE", "prospetto di prova numero uno", page: 1), at: 1)
        let (out, _) = insertingVisualResources(segs, candidates: [candidate("table", [55, 195, 545, 240], caption: [55, 178, 405, 192])], extraction: ex)
        XCTAssertEqual(out.first { $0.role == VISUAL_RESOURCE_ROLE }?.text, "Tabella: prospetto di prova numero uno")
        XCTAssertEqual(out.filter { $0.role != VISUAL_RESOURCE_ROLE }, segs)
    }

    func test_figuraSenzaTesto_collocataPrimaDelTestoCheSegue() {
        let ex = extraction([[
            line("testo prima della figura di prova", l: 50, t: 100, r: 550, b: 112, size: 11),
            line("testo dopo la figura di prova", l: 50, t: 500, r: 550, b: 512, size: 11),
        ]])
        let segs = [seg("a", "BODY", "testo prima della figura di prova", page: 1), seg("b", "BODY", "testo dopo la figura di prova", page: 1)]
        let c = candidate("picture", [100, 150, 500, 450], prev: [50, 100, 550, 112], next: [50, 500, 550, 512])
        let (out, report) = insertingVisualResources(segs, candidates: [c], extraction: ex)
        XCTAssertEqual(out.map { $0.id }, ["a", "vr_p0_0", "b"])
        XCTAssertEqual(out[1].text, "Figura")
        XCTAssertEqual(out[1].visualResource?.containedElements, 0)
        XCTAssertEqual(report.acceptedFigures, 1)
    }

    func test_figuraSenzaAppigli_inizioDellaPagina() {
        let ex = extraction([[line("pagina uno testo di prova", l: 50, t: 100, r: 550, b: 112, size: 11)], []])
        let segs = [seg("a", "BODY", "pagina uno testo di prova", page: 1), seg("b", "BODY", "pagina tre testo di prova", page: 3)]
        let (out, _) = insertingVisualResources(segs, candidates: [candidate("picture", page: 1, [100, 150, 500, 450])], extraction: ex)
        XCTAssertEqual(out.map { $0.id }, ["a", "vr_p1_0", "b"])
    }

    func test_guardia_marcatoreDiNotaNellaRegione() {
        var (ex, segs) = paginaConTabella()
        ex.pages[0].lines[2] = line("1. nota di prova dentro la regione", l: 60, t: 212, r: 540, b: 222)
        segs[1].text = "colonna alfa valore beta riga uno 1. nota di prova dentro la regione colonna epsilon valore zeta riga tre"
        let (out, report) = insertingVisualResources(segs, candidates: [candidate("table", [55, 195, 545, 240])], extraction: ex)
        XCTAssertEqual(out, segs)
        XCTAssertEqual(report.decisions.first?.outcome, .noteMarkers)
    }

    func test_guardia_richiamoInApiceNellaRegione() {
        var (ex, segs) = paginaConTabella()
        let box = BBox(x: 60, y: H - 222, width: 480, height: 10)
        ex.pages[0].lines[2] = PdfTextLine(spans: [
            PdfSpan(text: "colonna gamma valore delta riga due", fontSize: 11, bold: false, italic: false, color: "#000000", bbox: box),
            PdfSpan(text: "12", fontSize: 6, bold: false, italic: false, color: "#000000", bbox: box),
        ], bbox: box)
        segs[1].text = "colonna alfa valore beta riga uno colonna gamma valore delta riga due12 colonna epsilon valore zeta riga tre"
        let (_, report) = insertingVisualResources(segs, candidates: [candidate("table", [55, 195, 545, 240])], extraction: ex)
        XCTAssertEqual(report.decisions.first?.outcome, .noteMarkers)
    }

    func test_guardia_bloccoGiaClassificatoConCertezza() {
        let (ex, base) = paginaConTabella()
        var segs = base
        segs[1].role = "TOC_GENERAL"
        let (out, report) = insertingVisualResources(segs, candidates: [candidate("table", [55, 195, 545, 240])], extraction: ex)
        XCTAssertEqual(out, segs)
        XCTAssertEqual(report.decisions.first?.outcome, .certainBlock)
        // Lo stesso testo come nota vera (apre con un marcatore) è certo; come nota «muta» no.
        segs[1].role = "NOTE"; segs[1].text = "(3) " + segs[1].text
        XCTAssertEqual(insertingVisualResources(segs, candidates: [candidate("table", [55, 195, 545, 240])], extraction: ex).report.decisions.first?.outcome, .certainBlock)
    }

    func test_guardia_paginaInteraEtichetteNonVisive() {
        let (ex, segs) = paginaConTabella()
        let r1 = insertingVisualResources(segs, candidates: [candidate("picture", [0, 0, 600, 790])], extraction: ex).report
        XCTAssertEqual(r1.decisions.first?.outcome, .wholePage)
        let r2 = insertingVisualResources(segs, candidates: [candidate("document_index", [55, 195, 545, 240])], extraction: ex).report
        XCTAssertEqual(r2.decisions.first?.outcome, .notVisualLabel)
    }

    func test_duplicatoSovrappostoScartato() {
        let (ex, segs) = paginaConTabella()
        let (out, report) = insertingVisualResources(segs, candidates: [candidate("table", [55, 150, 545, 420]), candidate("picture", [56, 151, 544, 419])], extraction: ex)
        XCTAssertEqual(out.filter { $0.role == VISUAL_RESOURCE_ROLE }.count, 1)
        XCTAssertEqual(report.decisions.map { $0.outcome }, [.accepted, .duplicate])
    }

    func test_figuraPiccola_eArredo() {
        let (ex, segs) = paginaConTabella()
        // 40×40 pt su 600×800: 0,3 % della pagina (un logo)
        let r = insertingVisualResources(segs, candidates: [candidate("picture", [400, 500, 440, 540])], extraction: ex).report
        XCTAssertEqual(r.decisions.first?.outcome, .ornament)
    }

    func test_copertinaEUltimePagine_soloNeiVolumiLunghi() {
        let pages: [[PdfTextLine]] = (0..<30).map { _ in [] }
        let ex = extraction(pages)
        let segs = [seg("a", "BODY", "testo di prova della prima pagina", page: 1)]
        // riquadri diversi pagina per pagina, perché la regola della ricorrenza non entri in gioco
        let fig = { (p: Int) in self.candidate("picture", page: p, [100 + Double(p), 150 + 5 * Double(p), 500, 600]) }
        let r = insertingVisualResources(segs, candidates: [fig(0), fig(28), fig(29), fig(10)], extraction: ex).report
        XCTAssertEqual(r.decisions.map { $0.outcome }, [.cover, .accepted, .cover, .cover])
        // In un documento breve la prima e l'ultima pagina sono contenuto.
        let corto = extraction((0..<3).map { _ in [] })
        XCTAssertEqual(insertingVisualResources(segs, candidates: [fig(0)], extraction: corto).report.decisions.first?.outcome, .accepted)
    }

    func test_figuraAttraversataDalTesto() {
        // Un riquadro disegnato su parole del corpo: la riga esce dal riquadro a sinistra e a destra.
        let ex = extraction([[line("riga di corpo con alcune parole evidenziate in mezzo alla frase", l: 50, t: 300, r: 550, b: 312, size: 11)]])
        let segs = [seg("a", "BODY", "riga di corpo con alcune parole evidenziate in mezzo alla frase", page: 1)]
        let r = insertingVisualResources(segs, candidates: [candidate("picture", [200, 200, 400, 420])], extraction: ex).report
        XCTAssertEqual(r.decisions.first?.outcome, .insideText)
    }

    func test_testoNonLetto_apparatoGiaRiconosciuto() {
        // Le righe della regione non sono nel flusso (indice, sommario, glosse tolti dall'app per scelta).
        let (ex, _) = paginaConTabella()
        let segs = [seg("n1", "BODY", "primo capoverso di prova con parole qualsiasi", page: 1),
                    seg("n3", "BODY", "secondo capoverso di prova dopo la tabella", page: 1)]
        let r = insertingVisualResources(segs, candidates: [candidate("table", [55, 195, 545, 240])], extraction: ex).report
        XCTAssertEqual(r.decisions.first?.outcome, .unreadText)
    }

    func test_tabellaDiSoloTesto_senzaDisegni() {
        let (ex, segs) = paginaConTabella()
        var c = candidate("table", [55, 195, 545, 240]); c.graphicsInside = 0
        XCTAssertEqual(insertingVisualResources(segs, candidates: [c], extraction: ex).report.decisions.first?.outcome, .plainText)
        c.graphicsInside = 4
        XCTAssertEqual(insertingVisualResources(segs, candidates: [c], extraction: ex).report.decisions.first?.outcome, .accepted)
        c.graphicsInside = nil   // non misurato: la regola non si applica
        XCTAssertEqual(insertingVisualResources(segs, candidates: [c], extraction: ex).report.decisions.first?.outcome, .accepted)
    }

    func test_ricorrenza_soloPerLeFigure() {
        let ex = extraction((0..<6).map { _ in [] })
        let segs = (0..<6).map { seg("s\($0)", "BODY", "pagina \($0) testo di prova", page: $0 + 1) }
        let figure = (1...3).map { candidate("picture", page: $0, [100, 100, 500, 300]) }
        let tabelle = (1...3).map { candidate("table", page: $0, [100, 400, 500, 600]) }
        let r = insertingVisualResources(segs, candidates: figure + tabelle, extraction: ex).report
        XCTAssertEqual(r.decisions.filter { $0.candidate.label == "picture" }.map { $0.outcome }, [.recurring, .recurring, .recurring])
        XCTAssertEqual(r.decisions.filter { $0.candidate.label == "table" }.map { $0.outcome }, [.accepted, .accepted, .accepted])
    }

    func test_nessunCandidato_flussoIdentico() {
        let (ex, segs) = paginaConTabella()
        XCTAssertEqual(insertingVisualResources(segs, candidates: [], extraction: ex).segments, segs)
    }

    func test_segmentoConRisorsa_codificaAdditiva_cacheVecchiaLeggibile() throws {
        let old = #"{"id":"n1","role":"BODY","text":"parole di prova","lengthCategory":"","acousticIntro":"","memoryRefresh":"","sourcePage":3}"#
        let decoded = try JSONDecoder().decode(ContentSegment.self, from: Data(old.utf8))
        XCTAssertNil(decoded.visualResource)
        // Senza risorsa, la codifica non porta la chiave nuova: le cache restano identiche.
        let reencoded = String(decoding: try JSONEncoder().encode(decoded), as: UTF8.self)
        XCTAssertFalse(reencoded.contains("visualResource"))
        let (ex, segs) = paginaConTabella()
        let vr = insertingVisualResources(segs, candidates: [candidate("table", [55, 195, 545, 240])], extraction: ex).segments[1]
        let back = try JSONDecoder().decode(ContentSegment.self, from: try JSONEncoder().encode(vr))
        XCTAssertEqual(back, vr)
    }

    func test_ruoloDiPresentazioneNonECategoriaDelLayer1() {
        XCTAssertNil(SemanticCategory(rawValue: VISUAL_RESOURCE_ROLE))
        XCTAssertTrue(LAYER2_PRESENTATION_ONLY_ROLES.contains(VISUAL_RESOURCE_ROLE))
        XCTAssertEqual(acousticIntroFor(VISUAL_RESOURCE_ROLE, ""), "Risorsa visiva.")
    }

    // MARK: - Griglie, pagine fuse, eco (taratura del 2026-10-12 sulle 52 regioni «tabella» scartate)

    /// Una tabella con righe numerate: i numeri d'apertura sono celle, non marcatori di nota — se la regione ha una
    /// griglia disegnata. Senza griglia la regola prudente resta (potrebbe essere un apparato di note).
    private func tabellaNumerata() -> (PdfExtraction, [ContentSegment]) {
        let rows = ["12 sostanza alfa composto beta 25 3 75", "13 sostanza gamma composto delta 40 5 200",
                    "14 sostanza epsilon composto zeta 10 2 20"]
        let ex = extraction([[line("testo prima della tabella numerata di prova", l: 50, t: 100, r: 550, b: 112, size: 11)]
            + rows.enumerated().map { line($0.element, l: 60, t: 200 + Double($0.offset) * 12, r: 540, b: 210 + Double($0.offset) * 12) }])
        let segs = [seg("n1", "BODY", "testo prima della tabella numerata di prova", page: 1),
                    seg("n2", "BODY", rows.joined(separator: " "), page: 1)]
        return (ex, segs)
    }

    func test_righeNumerate_inUnaGriglia_nonSonoMarcatori() {
        let (ex, segs) = tabellaNumerata()
        var c = candidate("table", [55, 195, 545, 240]); c.graphicsInside = VISUAL_GRID_MIN_GRAPHICS
        XCTAssertEqual(insertingVisualResources(segs, candidates: [c], extraction: ex).report.decisions.first?.outcome, .accepted)
        c.graphicsInside = VISUAL_GRID_MIN_GRAPHICS - 1
        XCTAssertEqual(insertingVisualResources(segs, candidates: [c], extraction: ex).report.decisions.first?.outcome, .noteMarkers)
    }

    func test_richiamoVero_inUnaGriglia_escludeLaRegione_ilRinvioATreCifreNo() {
        var (ex, segs) = tabellaNumerata()
        var c = candidate("table", [55, 195, 545, 240]); c.graphicsInside = 20
        // «(318)» è un rinvio a un articolo: non esclude.
        ex.pages[0].lines[2] = line("13 sostanza gamma composto (318) delta 40 5 200", l: 60, t: 212, r: 540, b: 222)
        segs[1].text = segs[1].text.replacingOccurrences(of: "composto delta", with: "composto (318) delta")
        XCTAssertEqual(insertingVisualResources(segs, candidates: [c], extraction: ex).report.decisions.first?.outcome, .accepted)
        // «(1)», «(*)» sono richiami: escludono anche dentro una griglia.
        for callout in ["(1)", "(*)", "[2]"] {
            ex.pages[0].lines[3] = line("14 sostanza epsilon \(callout) composto zeta 10 2 20", l: 60, t: 224, r: 540, b: 234)
            XCTAssertEqual(insertingVisualResources(segs, candidates: [c], extraction: ex).report.decisions.first?.outcome, .noteMarkers, callout)
        }
    }

    /// Una tabella che la continuità del corpo ha fuso con le pagine prima: il suo testo sta in un segmento che comincia
    /// due pagine prima, e va ritrovato lì (non è «testo non letto»).
    func test_testoFusoConLePaginePrima_ritrovato() {
        let rows = ["riga di prova uno della tabella fusa", "riga di prova due della tabella fusa"]
        let pages: [[PdfTextLine]] = [[], [], rows.enumerated().map { line($0.element, l: 60, t: 200 + Double($0.offset) * 12, r: 540, b: 210 + Double($0.offset) * 12) }]
        let segs = [seg("n1", "BODY", "testo della prima pagina e poi " + rows.joined(separator: " "), page: 1),
                    seg("n2", "BODY", "un capoverso dopo la tabella", page: 3)]
        let r = insertingVisualResources(segs, candidates: [candidate("table", page: 2, [55, 195, 545, 230])], extraction: extraction(pages))
        XCTAssertEqual(r.report.decisions.first?.outcome, .accepted)
        XCTAssertEqual(r.report.decisions.first?.insertedAt, 0)
    }

    /// Un'eco — la stessa riga in un segmento lontano — non sposta la risorsa: conta il gruppo che porta il testo.
    func test_ecoLontana_nonSpostaLaRisorsa() {
        // Cinque righe, una sola ripetuta altrove (nei volumi: una riga su venti-sessanta).
        let rows = ["voce ripetuta alfa beta gamma", "seconda voce di prova delta", "terza voce di prova epsilon",
                    "quarta voce di prova zeta eta", "quinta voce di prova theta iota"]
        let ex = extraction([rows.enumerated().map { line($0.element, l: 60, t: 200 + Double($0.offset) * 8, r: 540, b: 207 + Double($0.offset) * 8) }])
        var segs = [seg("e1", "BODY", "un capoverso che cita la voce ripetuta alfa beta gamma per caso", page: 1)]
        segs += (2...6).map { seg("x\($0)", "BODY", "capoverso intermedio numero \($0) senza relazione", page: 1) }
        segs.append(seg("t1", "BODY", rows.joined(separator: " "), page: 1))
        let d = insertingVisualResources(segs, candidates: [candidate("table", [55, 195, 545, 240])], extraction: ex).report.decisions.first
        XCTAssertEqual(d?.outcome, .accepted)
        XCTAssertEqual(d?.insertedAt, segs.count - 1, "prima del segmento che porta la tabella, non prima dell'eco")
        XCTAssertEqual(d?.containedElements, 1)
    }

    // MARK: - Collocazione: ripetizioni, didascalie, geometria (controllo a vista del 2026-10-12)

    /// Due tabelle sulla stessa pagina con la stessa riga d'intestazione: ciascuna risorsa precede il SUO testo, non
    /// quello della prima tabella (caso misurato su una pagina di un codice: la stessa intestazione in tre tabelle).
    func test_rigaRipetuta_ciascunaTabellaPrecedeIlSuoTesto() {
        let head = "voce di prova del raccolto in quintali"
        let ex = extraction([[
            line(head, l: 60, t: 100, r: 540, b: 110), line("prima tabella valori alfa beta", l: 60, t: 112, r: 540, b: 122),
            line("un capoverso di prova fra le due tabelle", l: 50, t: 200, r: 550, b: 212, size: 11),
            line(head, l: 60, t: 300, r: 540, b: 310), line("seconda tabella valori gamma delta", l: 60, t: 312, r: 540, b: 322),
        ]])
        let segs = [seg("t1", "BODY", head + " prima tabella valori alfa beta", page: 1),
                    seg("b1", "BODY", "un capoverso di prova fra le due tabelle", page: 1),
                    seg("t2", "BODY", head + " seconda tabella valori gamma delta", page: 1)]
        let r = insertingVisualResources(segs, candidates: [candidate("table", [55, 95, 545, 125]), candidate("table", [55, 295, 545, 325])], extraction: ex)
        XCTAssertEqual(r.segments.map { $0.id }, ["vr_p0_0", "t1", "b1", "vr_p0_1", "t2"])
    }

    /// Una figura senza testo con la didascalia SOTTO: la risorsa precede la didascalia (anche se il modello legge
    /// prima un altro capoverso); con la didascalia SOPRA, la segue.
    func test_figuraSenzaTesto_ancorataAllaDidascalia() {
        let ex = extraction([[
            line("capoverso sopra la figura di prova", l: 50, t: 100, r: 550, b: 112, size: 11),
            line("figura uno didascalia di prova", l: 60, t: 420, r: 400, b: 430, size: 9),
            line("capoverso dopo la didascalia", l: 50, t: 500, r: 550, b: 512, size: 11),
        ]])
        let segs = [seg("a", "BODY", "capoverso sopra la figura di prova", page: 1), seg("c", "BODY", "figura uno didascalia di prova", page: 1),
                    seg("d", "BODY", "capoverso dopo la didascalia", page: 1)]
        // Il modello direbbe «prima del capoverso sopra»: vince la didascalia.
        var c = candidate("picture", [100, 150, 500, 410], caption: [55, 415, 405, 432], next: [45, 95, 555, 115])
        XCTAssertEqual(insertingVisualResources(segs, candidates: [c], extraction: ex).segments.map { $0.id }, ["a", "vr_p0_0", "c", "d"])
        // Didascalia sopra la figura: la risorsa la segue.
        let ex2 = extraction([[
            line("figura due didascalia sopra di prova", l: 60, t: 100, r: 400, b: 110, size: 9),
            line("capoverso dopo la figura di prova", l: 50, t: 500, r: 550, b: 512, size: 11),
        ]])
        let segs2 = [seg("c", "BODY", "figura due didascalia sopra di prova", page: 1), seg("d", "BODY", "capoverso dopo la figura di prova", page: 1)]
        c = candidate("picture", [100, 120, 500, 480], caption: [55, 95, 405, 112])
        XCTAssertEqual(insertingVisualResources(segs2, candidates: [c], extraction: ex2).segments.map { $0.id }, ["c", "vr_p0_0", "d"])
    }

    /// Una tabella che il flusso legge in due parti con altro testo in mezzo (una colonna di articoli accanto alla
    /// tabella): il testo contenuto è solo la prima sequenza contigua, così «Salta la risorsa» non scavalca il testo che non
    /// è della risorsa; la seconda parte resta testo ordinario (rilievo della revisione indipendente).
    func test_tabellaInDueParti_contenutoSoloLaPrimaSequenza() {
        let ex = extraction([[
            line("colonna alfa valore beta riga uno", l: 60, t: 200, r: 300, b: 210),
            line("colonna gamma valore delta riga due", l: 60, t: 212, r: 300, b: 222),
            line("colonna epsilon valore zeta riga tre", l: 60, t: 224, r: 300, b: 234),
            line("colonna eta valore theta riga quattro", l: 60, t: 236, r: 300, b: 246),
            line("articolo di prova accanto alla tabella", l: 320, t: 200, r: 550, b: 212, size: 11),
        ]])
        let segs = [seg("t1", "BODY", "colonna alfa valore beta riga uno colonna gamma valore delta riga due", page: 1),
                    seg("x", "BODY", "articolo di prova accanto alla tabella", page: 1),
                    seg("t2", "BODY", "colonna epsilon valore zeta riga tre colonna eta valore theta riga quattro", page: 1)]
        let r = insertingVisualResources(segs, candidates: [candidate("table", [55, 195, 305, 250])], extraction: ex)
        XCTAssertEqual(r.segments.map { $0.id }, ["vr_p0_0", "t1", "x", "t2"])
        XCTAssertEqual(r.segments[0].visualResource?.containedElements, 1)
        XCTAssertEqual(r.segments.filter { $0.role != VISUAL_RESOURCE_ROLE }, segs)
    }

    /// Il flusso spezza una riga d'intestazione in due segmenti (un numero sotto la sua etichetta, troppo corto per essere
    /// ritrovato da solo): il segmento che porta solo testo della regione resta nel testo contenuto, e il salto supera
    /// tutta la tabella, fino al capoverso che segue.
    func test_segmentoConSoloTestoDellaRegione_restaNelContenuto() {
        let ex = extraction([[
            line("intestazione di prova", l: 60, t: 200, r: 300, b: 210),
            line("2001", l: 60, t: 212, r: 120, b: 222),
            line("riga uno valore alfa beta", l: 60, t: 224, r: 540, b: 234),
            line("riga due valore gamma delta", l: 60, t: 236, r: 540, b: 246),
            line("capoverso di prova dopo la tabella", l: 50, t: 300, r: 550, b: 312, size: 11),
        ]])
        let segs = [seg("h1", "BODY", "intestazione di prova", page: 1), seg("h2", "BODY", "2001", page: 1),
                    seg("d", "BODY", "riga uno valore alfa beta riga due valore gamma delta", page: 1),
                    seg("c", "BODY", "capoverso di prova dopo la tabella", page: 1)]
        let r = insertingVisualResources(segs, candidates: [candidate("table", [55, 195, 545, 250])], extraction: ex)
        XCTAssertEqual(r.segments.map { $0.id }, ["vr_p0_0", "h1", "h2", "d", "c"])
        XCTAssertEqual(r.segments[0].visualResource?.containedElements, 3)
    }

    /// L'ultimo segmento del testo contenuto prosegue, dopo la tabella, con altro testo (un segmento grosso che unisce la
    /// tabella al capoverso seguente): il salto non lo include, perché non scavalchi quel testo; la didascalia invece è
    /// testo della risorsa (è già nell'annuncio) e non conta come estranea.
    func test_codaEstranea_ilSaltoNonLaScavalca_laDidascaliaSi() {
        let table = [line("colonna alfa valore beta riga uno", l: 60, t: 200, r: 540, b: 210),
                     line("colonna gamma valore delta riga due", l: 60, t: 212, r: 540, b: 222)]
        let prose = "un capoverso di prova dopo la tabella che continua a lungo con parole qualsiasi e ancora altre parole"
        let ex = extraction([table + [line(prose, l: 50, t: 300, r: 550, b: 312, size: 11)]])
        let segs = [seg("t", "BODY", "colonna alfa valore beta riga uno colonna gamma valore delta riga due " + prose, page: 1)]
        let r = insertingVisualResources(segs, candidates: [candidate("table", [55, 195, 545, 230])], extraction: ex)
        XCTAssertEqual(r.segments.map { $0.id }, ["vr_p0_0", "t"])
        XCTAssertEqual(r.segments[0].visualResource?.containedElements, 0, "il salto non scavalca il capoverso")
        // La stessa coda, ma è la didascalia della tabella: resta nel testo della risorsa.
        let caption = "prospetto di prova del raccolto per stagione e per podere con valori in quintali"
        let ex2 = extraction([table + [line(caption, l: 60, t: 232, r: 540, b: 242, size: 9)]])
        let segs2 = [seg("t", "BODY", "colonna alfa valore beta riga uno colonna gamma valore delta riga due " + caption, page: 1)]
        let r2 = insertingVisualResources(segs2, candidates: [candidate("table", [55, 195, 545, 230], caption: [55, 230, 545, 245])],
                                          extraction: ex2)
        XCTAssertEqual(r2.segments[0].visualResource?.containedElements, 1)
    }

    /// Un elemento inserito prima di un segmento fuso che comincia pagine prima (il testo della tabella di pagina 3 sta in
    /// un segmento che parte da pagina 1): nel flusso prende la pagina di quel segmento, così le pagine restano monotone;
    /// la pagina vera della regione resta nel payload. Un candidato malformato non fa cadere l'ordinamento.
    func test_paginaNelFlusso_monotona_eCandidatoMalformato() {
        var pages: [[PdfTextLine]] = [[], [], []]
        pages[2] = [line("colonna alfa valore beta riga uno", l: 60, t: 200, r: 540, b: 210),
                    line("colonna gamma valore delta riga due", l: 60, t: 212, r: 540, b: 222)]
        let ex = extraction(pages)
        let segs = [seg("p0", "BODY", "un capoverso di prova della prima pagina", page: 1),
                    seg("m", "BODY", "testo fuso fra le pagine colonna alfa valore beta riga uno colonna gamma valore delta riga due", page: 1)]
        let ok = candidate("table", page: 2, [55, 195, 545, 230])
        let bad = VisualRegionCandidate(pageIndex: 2, label: "table", bbox: [10, 20], confidence: 0.9, captionBBox: nil,
                                        pageWidth: W, pageHeight: H, previousTextBBox: nil, nextTextBBox: nil)
        let r = insertingVisualResources(segs, candidates: [bad, ok], extraction: ex)
        let vr = r.segments.first { $0.role == VISUAL_RESOURCE_ROLE }
        XCTAssertEqual(r.segments.map { $0.id }, ["p0", "vr_p2_0", "m"])
        XCTAssertEqual(vr?.sourcePage, 1, "la pagina nel flusso non torna indietro")
        XCTAssertEqual(vr?.visualResource?.pageIndex, 2, "la pagina vera della regione resta nel payload")
        XCTAssertEqual(r.report.decisions.filter { $0.outcome == .notVisualLabel }.count, 1)
    }

    /// Una riga della tabella che il flusso porta anche in un segmento PRIMA (la didascalia della tabella precedente la
    /// contiene): la riga va al segmento vicino al grosso del testo della tabella, e la risorsa precede l'intestazione,
    /// non i dati della tabella precedente (caso misurato su una rivista, riprodotto con parole di prova).
    func test_rigaInPiuSegmenti_vaAlSegmentoVicinoAlGrossoDellaRegione() {
        let ex = extraction([[
            line("tabella prima didascalia sul raccolto per podere di prova", l: 60, t: 100, r: 540, b: 110),
            line("podere di prova", l: 60, t: 300, r: 200, b: 310),
            line("quintali raccolti nel podere alfa uno", l: 60, t: 312, r: 540, b: 322),
            line("quintali raccolti nel podere beta due", l: 60, t: 324, r: 540, b: 334),
            line("quintali raccolti nel podere gamma tre", l: 60, t: 336, r: 540, b: 346),
        ]])
        let segs = [seg("a", "BODY", "dati della prima tabella tabella prima didascalia sul raccolto per podere di prova", page: 1),
                    seg("h", "BODY", "fonte di prova podere di prova", page: 1),
                    seg("d", "BODY", "quintali raccolti nel podere alfa uno quintali raccolti nel podere beta due quintali raccolti nel podere gamma tre", page: 1)]
        let r = insertingVisualResources(segs, candidates: [candidate("table", [55, 295, 545, 350])], extraction: ex)
        XCTAssertEqual(r.segments.map { $0.id }, ["a", "vr_p0_0", "h", "d"])
        XCTAssertEqual(r.segments[1].visualResource?.containedElements, 2)
    }

    /// Una parola d'intestazione ripetuta nella tabella (due colonne «raccolto») che compare anche nella prosa prima:
    /// i conti delle ripetizioni non tornano (il flusso la porta più volte dell'estrazione), quindi la ripetizione non
    /// decide e vale la vicinanza al grosso del testo: la risorsa precede l'intestazione, non la prosa.
    func test_ripetizioneAmbigua_nonTrascinaLaRisorsaNellaProsa() {
        let ex = extraction([[
            line("il raccolto di prova del podere e un altro raccolto di prova", l: 50, t: 100, r: 550, b: 112, size: 11),
            line("raccolto", l: 60, t: 300, r: 150, b: 310), line("raccolto", l: 300, t: 300, r: 390, b: 310),
            line("grano duro quintali venti", l: 60, t: 312, r: 540, b: 322),
            line("orzo nudo quintali trenta", l: 60, t: 324, r: 540, b: 334),
        ]])
        let segs = [seg("p", "BODY", "il raccolto di prova del podere e un altro raccolto di prova", page: 1),
                    seg("h", "BODY", "raccolto raccolto", page: 1),
                    seg("d", "BODY", "grano duro quintali venti orzo nudo quintali trenta", page: 1)]
        let r = insertingVisualResources(segs, candidates: [candidate("table", [55, 295, 545, 340])], extraction: ex)
        XCTAssertEqual(r.segments.map { $0.id }, ["p", "vr_p0_0", "h", "d"])
        XCTAssertEqual(r.segments[1].visualResource?.containedElements, 2)
    }

    /// L'ordine del modello mette dopo la tabella un'intestazione che sulla pagina sta tutta sopra: la risorsa segue
    /// l'intestazione (CP p. 2179, l'allegato delle tabelle dei parametri forensi).
    func test_anchoraDelModelloSopraLaRegione_laRisorsaLaSegue() {
        let ex = extraction([[line("allegato unico tabelle di prova", l: 300, t: 40, r: 500, b: 60, size: 12),
                              line("capoverso della pagina dopo", l: 50, t: 700, r: 550, b: 712, size: 11)]])
        let segs = [seg("h", "HEADING_2", "allegato unico tabelle di prova", page: 1), seg("d", "BODY", "capoverso della pagina dopo", page: 1)]
        let c = candidate("table", [60, 100, 500, 400], next: [295, 35, 505, 65])
        XCTAssertEqual(insertingVisualResources(segs, candidates: [c], extraction: ex).segments.map { $0.id }, ["h", "vr_p0_0", "d"])
    }
}
