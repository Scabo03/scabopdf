//
//  GenericPluginTests.swift
//  ScaboCoreTests
//
//  PART A — XCTest translation of the TS oracle `app/src/plugins/__tests__/
//  generic.test.ts` (174 LOC), plus an end-to-end seam exercise.
//
//  Deliberately NOT translated: the TS test
//  "buildDocumentFromPdf flows into the rendering pipeline" calls `buildLayout`
//  / `paginate` from `../../rendering`, which is Fase 3 (the rendering layer is
//  not in ScaboCore yet). It is out of this phase's scope and will be covered
//  when Fase 3 lands rendering — not a fidelity gap, a scope boundary.
//
//  FIDELITY over improvement: these assertions pin the Generic's behaviour,
//  collapse included (e.g. the "unique ids" case where the body size estimate
//  lands on the heading size — the test asserts ids, not types, exactly as the
//  TS does).
//

import XCTest
@testable import ScaboCore

final class GenericPluginTests: XCTestCase {

    private func line(_ text: String, size: Double = 12, bold: Bool = false) -> PdfTextLine {
        PdfTextLine(
            spans: [PdfSpan(text: text, fontSize: size, bold: bold, italic: false, color: "#000000",
                            bbox: BBox(x: 0, y: 0, width: 0, height: 0))],
            bbox: BBox(x: 0, y: 0, width: 0, height: 0)
        )
    }

    private func extraction(_ pages: [[PdfTextLine]]) -> PdfExtraction {
        PdfExtraction(
            version: 2,
            pageCount: pages.count,
            pages: pages.enumerated().map { idx, lines in
                PdfPageExtraction(pageIndex: idx, width: 595, height: 842, lines: lines)
            }
        )
    }

    // MARK: genericPlugin.build

    /// TS: "classifies a larger short line as a heading and prose as body".
    func test_build_headingThenMergedBody() {
        let doc = genericPlugin.build(
            extraction([[
                line("Capitolo Primo", size: 20, bold: true),
                line("Questo è il primo paragrafo del corpo del testo."),
                line("e continua sulla riga successiva senza interruzioni."),
                line("Una terza riga di corpo per consolidare la stima."),
                line("Una quarta riga di corpo del testo normale."),
                line("Una quinta riga di corpo del testo normale."),
            ]]),
            sourceName: "manuale.pdf"
        )
        let structure = doc.structure
        XCTAssertEqual(structure.count, 2)
        XCTAssertEqual(structure[0].type, .HEADING_1)
        XCTAssertEqual(structure[0].text, "Capitolo Primo")
        XCTAssertEqual(structure[0].level, 1)
        XCTAssertEqual(structure[1].type, .BODY)
        XCTAssertTrue(structure[1].text?.contains("Questo è il primo paragrafo del corpo del testo.") ?? false)
    }

    /// TS: "assigns heading levels by size ratio".
    func test_build_headingLevelsByRatio() {
        let doc = genericPlugin.build(
            extraction([[
                line("Titolone", size: 18),
                line("Sottotitolo", size: 15),
                line("Minore", size: 13.5),
                line("corpo del documento normale qui presente"),
                line("seconda riga di corpo a dimensione normale"),
                line("terza riga di corpo a dimensione normale"),
                line("quarta riga di corpo a dimensione normale"),
                line("quinta riga di corpo a dimensione normale"),
            ]]),
            sourceName: "x.pdf"
        )
        XCTAssertEqual(doc.structure.map { $0.type }, [.HEADING_1, .HEADING_2, .HEADING_3, .BODY])
    }

    /// TS: "classifies smaller text as a NOTE with a length_category".
    func test_build_smallerTextIsNote() {
        let doc = genericPlugin.build(
            extraction([[
                line("corpo del testo di riferimento a dimensione normale"),
                line("1. Una nota a piè di pagina molto più piccola.", size: 8),
            ]]),
            sourceName: "x.pdf"
        )
        let note = doc.structure.first { $0.type == .NOTE }
        XCTAssertNotNil(note)
        XCTAssertEqual(note?.length_category, .MICRO)
    }

    /// TS: "de-hyphenates a word broken across two lines".
    func test_build_deHyphenates() {
        let doc = genericPlugin.build(
            extraction([[line("responsabi-"), line("lità civile del debitore")]]),
            sourceName: "x.pdf"
        )
        XCTAssertEqual(doc.structure.first?.text, "responsabilità civile del debitore")
    }

    /// TS: "breaks paragraph runs at page boundaries".
    func test_build_breaksAtPageBoundaries() {
        let doc = genericPlugin.build(
            extraction([[line("prima pagina di testo")], [line("seconda pagina")]]),
            sourceName: "x.pdf"
        )
        XCTAssertEqual(doc.structure.count, 2)
        XCTAssertEqual(doc.structure[0].page_index, 0)
        XCTAssertEqual(doc.structure[1].page_index, 1)
    }

    /// TS: "falls back to all-BODY when no font information is present".
    func test_build_allBodyWhenNoFont() {
        let doc = genericPlugin.build(
            extraction([[line("riga uno", size: 0), line("riga due", size: 0)]]),
            sourceName: "x.pdf"
        )
        XCTAssertTrue(doc.structure.allSatisfy { $0.type == .BODY })
        XCTAssertTrue(doc.warnings.contains("plugin:generic:no_font_information_all_body"))
    }

    /// TS: "produces a well-formed empty Document for an empty extraction".
    func test_build_emptyExtraction() {
        let doc = genericPlugin.build(extraction([]), sourceName: "vuoto.pdf")
        XCTAssertEqual(doc.structure, [])
        XCTAssertEqual(doc.metadata.source_pdf_filename, "vuoto.pdf")
        XCTAssertEqual(doc.document_id, "vuoto")
        XCTAssertEqual(doc.schema_version, "0.7.0")
    }

    /// TS: "mints unique sequential node ids". (Asserts ids, not types — the
    /// body-size estimate collapses here, faithfully.)
    func test_build_uniqueSequentialIds() {
        let doc = genericPlugin.build(
            extraction([[line("Titolo", size: 20), line("corpo"), line("altro corpo")]]),
            sourceName: "x.pdf"
        )
        let ids = doc.structure.map { $0.id }
        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertEqual(ids.first, "node_0")
    }

    // MARK: dispatcher

    /// TS: "selects the Generic plugin (only registered plugin this session)".
    func test_dispatcher_selectsGeneric() {
        XCTAssertTrue(selectPlugin(extraction([[line("x")]])) === genericPlugin)
    }

    // MARK: end-to-end seam (PdfExtraction → document model → contract)

    /// Exercises the whole Fase 2 across the § 10 seam: a `PdfExtraction` flows
    /// through the Generic into a `ScabopdfDocument`, which is then re-validated
    /// against the Layer 1 contract via the Fase 1 `parseDocument`.
    func test_seam_extractionToDocument_isContractValid() {
        let ext = extraction([[
            line("Capitolo", size: 20, bold: true),
            line("Testo del corpo del capitolo che scorre."),
            line("Seconda riga di corpo del capitolo."),
            line("Terza riga di corpo del capitolo."),
            line("Quarta riga di corpo del capitolo."),
        ]])
        let doc = buildDocumentFromPdf(ext, sourceName: "manuale.pdf")

        // Produced model: heading first, then a merged body paragraph.
        XCTAssertEqual(doc.structure.first?.type, .HEADING_1)
        XCTAssertEqual(flattenToReadingOrder(doc).count, doc.structure.count)

        // Round-trips through the Fase 1 contract validator.
        let data = try! JSONEncoder().encode(doc)
        guard case .success(let parsed, _) = parseDocument(data) else {
            return XCTFail("Generic-produced document did not validate against the contract")
        }
        XCTAssertEqual(parsed.profile.profile_id, "generic")
        XCTAssertEqual(parsed.metadata.source_pdf_filename, "manuale.pdf")
    }

    // MARK: - Furniture detection (detectFurniture: copertura prima assente)
    //
    // `detectFurniture` ha tre rami — banda alta/bassa, colore per-pagina, watermark
    // a maggioranza — calibrati su soglie di ricorrenza, e nessun test li esercitava
    // (le suite esistenti usano 1-2 pagine, dove il rilevatore ritorna sempre vuoto).
    // Soglie su N pagine: minPages = max(5, ceil(N*0.15)); majorityPages = max(5, ceil(N*0.5)).
    // La geometria (yTop = bbox.y + bbox.height, su altezza pagina 842) decide la banda.

    /// Una riga con colore e posizione esplicite (per i rami furniture/colore).
    private func placedLine(
        _ text: String, size: Double = 12, bold: Bool = false,
        color: String = "#000000", y: Double = 400, height: Double = 12
    ) -> PdfTextLine {
        let bbox = BBox(x: 0, y: y, width: 100, height: height)
        return PdfTextLine(
            spans: [PdfSpan(text: text, fontSize: size, bold: bold, italic: false, color: color, bbox: bbox)],
            bbox: bbox)
    }

    /// Un'intestazione corta nella banda ALTA, identica su tutte e 6 le pagine, è
    /// furniture: rimossa (non emessa) e contata nella warning.
    func test_detectFurniture_runningHeaderInTopBandRemovedAcrossPages() {
        let header = placedLine("Diritto Privato Italiano", size: 9, y: 800) // banda alta, < 60 char
        func body(_ word: String) -> [PdfTextLine] {
            ["primo", "secondo", "terzo", "quarto"].map {
                placedLine("Paragrafo \($0) della sezione \(word) del corpo del documento.", size: 12, y: 400)
            }
        }
        let words = ["alfa", "beta", "gamma", "delta", "epsilon", "zeta"] // 6 pagine
        let doc = genericPlugin.build(extraction(words.map { [header] + body($0) }), sourceName: "x.pdf")

        XCTAssertFalse(
            doc.structure.contains { ($0.text ?? "").contains("Diritto Privato Italiano") },
            "l'header ricorrente nella banda alta è furniture, non deve essere emesso")
        XCTAssertTrue(
            doc.warnings.contains("plugin:generic:furniture_lines_removed_6"),
            "le 6 occorrenze dell'header sono contate come furniture rimossa")
    }

    /// Un footer "Pagina N" nella banda BASSA ricorre dopo `normalizeDigits` ("pagina #")
    /// ed è rimosso anche se il numero varia di pagina in pagina.
    func test_detectFurniture_pageNumberFooterNormalizedAndRemoved() {
        func page(_ n: Int, _ word: String) -> [PdfTextLine] {
            [placedLine("Pagina \(n)", size: 9, y: 0)] // banda bassa (yTop = 12 / 842 ≈ 0.014)
                + ["uno", "due", "tre"].map {
                    placedLine("Frase \($0) di corpo della parte \(word) del testo.", size: 12, y: 400)
                }
        }
        let words = ["alfa", "beta", "gamma", "delta", "epsilon", "zeta"]
        let pages = words.enumerated().map { page($0.offset + 1, $0.element) }
        let doc = genericPlugin.build(extraction(pages), sourceName: "x.pdf")

        XCTAssertFalse(
            doc.structure.contains { ($0.text ?? "").hasPrefix("Pagina") },
            "il footer di pagina, normalizzato a 'pagina #', ricorre ed è rimosso")
        XCTAssertTrue(doc.warnings.contains { $0.hasPrefix("plugin:generic:furniture_lines_removed_") })
    }

    /// Un watermark LUNGO (> 60 char) è invisibile al ramo di banda (che salta le righe
    /// lunghe) ma viene preso dal ramo a maggioranza, e rimosso.
    func test_detectFurniture_longWatermarkRemovedByMajorityNotBand() {
        let watermark = "Copia riservata esclusivamente all'uso personale del titolare della licenza dell'opera"
        XCTAssertGreaterThan(watermark.utf16.count, FURNITURE_MAX_CHARS, "il watermark supera il cap di banda")
        func page(_ word: String) -> [PdfTextLine] {
            [placedLine(watermark, size: 8, y: 400)] // banda media: solo il ramo a maggioranza può prenderlo
                + ["a", "b", "c"].map {
                    placedLine("Contenuto \($0) della sezione \(word) del documento.", size: 12, y: 400)
                }
        }
        let words = ["alfa", "beta", "gamma", "delta", "epsilon"] // 5 pagine → majorityPages = 5
        let doc = genericPlugin.build(extraction(words.map { page($0) }), sourceName: "x.pdf")

        XCTAssertFalse(
            doc.structure.contains { ($0.text ?? "").contains("Copia riservata esclusivamente") },
            "il watermark a maggioranza è rimosso anche se troppo lungo per il ramo di banda")
        XCTAssertTrue(doc.warnings.contains { $0.hasPrefix("plugin:generic:furniture_lines_removed_") })
    }

    /// Una riga corta saturata e distinta dal corpo, ricorrente su abbastanza pagine da
    /// superare minPages (5) ma non majorityPages (10), è presa SOLO dal ramo colore.
    func test_detectFurniture_perPageColourMarkerRemovedByColourBranch() {
        let marker = placedLine("MarkerRosso", size: 12, color: "#cc0000", y: 400) // saturo, banda media
        func body(_ word: String) -> [PdfTextLine] {
            [placedLine("Testo di corpo nero della parte \(word) del documento.", size: 12, y: 400)]
        }
        // 20 pagine: minPages = max(5, 3) = 5; majorityPages = max(5, 10) = 10.
        // Il marker compare su 6 pagine: ≥ 5 (colore) ma < 10 (maggioranza) → solo il ramo colore.
        // Parole-pagina SENZA cifre ("a".."t"): altrimenti normalizeDigits le collasserebbe
        // a un'unica forma ricorrente e il corpo verrebbe preso dal ramo a maggioranza.
        let words = (0..<20).map { String(UnicodeScalar(UInt8(97 + $0))) }
        let pages = words.enumerated().map { idx, w -> [PdfTextLine] in
            idx < 6 ? [marker] + body(w) : body(w)
        }
        let doc = genericPlugin.build(extraction(pages), sourceName: "x.pdf")

        XCTAssertFalse(
            doc.structure.contains { ($0.text ?? "").contains("MarkerRosso") },
            "il marker colorato per-pagina è furniture per il ramo colore")
        XCTAssertTrue(doc.warnings.contains("plugin:generic:furniture_lines_removed_6"))
    }

    /// AGGIORNATO 2026-06-24 (nuovo canale "testatine correnti di capitolo"). Sotto il
    /// pavimento globale del 15% (header su 4 pagine su 6, minPages = 5) una TESTATINA
    /// CORRENTE è ORA furniture: è la riga più in alto, in banda superiore, ancorata alla
    /// stessa y. Una ricorrenza sotto soglia che NON è una testatina (riga di corpo a metà
    /// pagina) resta invece letta — la guardia "riga più in alto + posizione ancorata"
    /// separa i due casi. Vedi RUNNING_HEADER_* in GenericPlugin.
    func test_detectFurniture_runningHeaderBelowFloorRemoved_nonHeaderKept() {
        let header = placedLine("Intestazione Corrente", size: 9, y: 800) // topmost, banda, ancorata
        // Frase di corpo che si ripete a metà pagina sulle STESSE 4 pagine della testatina
        // (sotto sia minPages=5 sia majorityPages=5): non topmost, non in banda → deve restare.
        let midRepeat = placedLine("Frase di corpo a metà pagina, ripetuta.", size: 12, y: 400)
        let words = ["alfa", "beta", "gamma", "delta", "epsilon", "zeta"]
        let pages = words.enumerated().map { idx, w -> [PdfTextLine] in
            idx < 4
                ? [header, midRepeat, placedLine("Riga \(w) variabile del corpo.", size: 12, y: 360)]
                : [placedLine("Riga \(w) variabile del corpo.", size: 12, y: 360)]
        }
        let doc = genericPlugin.build(extraction(pages), sourceName: "x.pdf")

        // La testatina corrente (topmost+ancorata) sotto il pavimento del 15% ora è furniture.
        XCTAssertFalse(
            doc.structure.contains { ($0.text ?? "").contains("Intestazione Corrente") },
            "testatina corrente sotto soglia: ora rimossa dal nuovo canale")
        XCTAssertTrue(
            doc.warnings.contains { $0.hasPrefix("plugin:generic:furniture_lines_removed_") },
            "rimozione testatina → warning furniture")
        // La frase di corpo ricorrente a metà pagina (non topmost, non in banda) resta letta.
        XCTAssertTrue(
            doc.structure.contains { ($0.text ?? "").contains("Frase di corpo a metà pagina") },
            "ricorrenza non-testatina sotto soglia: resta letta (precisione)")
    }

    /// Una testatina appena SOTTO il decile più alto (yFrac≈0.87, fra `TOP_BAND` 0.85
    /// e 0.9) è furniture: col vecchio 0.9 sfuggiva alla banda e veniva letta (annuncio
    /// "Nota." + intrusione nel primo paragrafo — bug 1/2 di "Delitti in prima pagina").
    func test_detectFurniture_runningHeaderJustBelowTopDecileRemoved() {
        // yTop = 720 + 12 = 732 su pagina 842 → yFrac ≈ 0.869 (fra 0.85 e 0.9).
        let header = placedLine("Delitti in prima pagina", size: 7, y: 720)
        func body(_ w: String) -> [PdfTextLine] {
            ["uno", "due", "tre"].map { placedLine("Riga \($0) di corpo della sezione \(w).", size: 12, y: 400) }
        }
        let words = ["alfa", "beta", "gamma", "delta", "epsilon", "zeta"] // 6 pagine ≥ minPages
        let doc = genericPlugin.build(extraction(words.map { [header] + body($0) }), sourceName: "x.pdf")

        XCTAssertFalse(
            doc.structure.contains { ($0.text ?? "").contains("Delitti in prima pagina") },
            "la testatina a yFrac 0.87 ora cade nella banda alta ed è furniture")
        XCTAssertTrue(doc.warnings.contains { $0.hasPrefix("plugin:generic:furniture_lines_removed_") })
    }

    /// Discriminazione per NORMA, non per posizione: una riga corta nella stessa banda
    /// alta ma di TESTO DIVERSO ogni pagina (tipica prima-riga-di-corpo sotto la
    /// testatina) NON ricorre per norma e NON è furniture — la garanzia che abbassare
    /// la banda non tolga contenuto (rete A su Mosconi: prime righe di corpo salve).
    func test_detectFurniture_topBandUniqueTextLinesAreKept() {
        let words = ["alfa", "beta", "gamma", "delta", "epsilon", "zeta"]
        let pages = words.map { w -> [PdfTextLine] in
            [placedLine("Apertura unica del paragrafo \(w) del capitolo.", size: 12, y: 720)] // banda alta, testo diverso
                + ["x", "y"].map { placedLine("Riga \($0) del corpo \(w).", size: 12, y: 400) }
        }
        let doc = genericPlugin.build(extraction(pages), sourceName: "x.pdf")
        XCTAssertTrue(
            doc.structure.contains { ($0.text ?? "").contains("Apertura unica del paragrafo alfa") },
            "righe in banda alta con testo distinto per pagina non ricorrono per norma → restano lette")
    }

    // MARK: - Folio per progressione vs contenuto-numero (Mattone A)
    //
    // Una riga il cui testo è un solo numero nudo normalizza a "#" come ogni
    // numero-pagina. Il vecchio canale a maggioranza, vedendo "#" ricorrere su
    // quasi tutte le pagine (per via del folio), spazzava via OGNI numero isolato,
    // folio E contenuto. Ora i numeri nudi bypassano i canali di ricorrenza e sono
    // rimossi solo se formano una progressione v = pageIndex + offset.

    /// Il folio (numero nudo = pageIndex + offset costante) è rimosso anche quando
    /// sta a metà pagina — dove il canale di banda non lo prenderebbe — perché la
    /// progressione, non la posizione, lo identifica.
    func test_detectFurniture_folioByProgressionRemovedMidPage() {
        func page(_ idx: Int) -> [PdfTextLine] {
            [placedLine("\(idx + 100)", size: 12, y: 400)] // numero nudo a metà pagina
                + ["uno", "due"].map { placedLine("Frase \($0) di corpo della pagina numero \(idx).", y: 400) }
        }
        let doc = genericPlugin.build(extraction((0..<12).map { page($0) }), sourceName: "x.pdf")

        XCTAssertFalse(
            doc.structure.contains { ($0.text ?? "") == "105" || ($0.text ?? "") == "111" },
            "il folio per progressione (offset 100) è rimosso pur stando a metà pagina")
        XCTAssertTrue(doc.warnings.contains { $0.hasPrefix("plugin:generic:furniture_lines_removed_") })
    }

    /// Un contenuto-numero isolato (un rimando d'indice, un numero d'articolo) che
    /// NON progredisce è preservato anche quando un folio fa ricorrere "#" su tutte
    /// le pagine — il caso che il vecchio canale "#" mangiava.
    func test_detectFurniture_isolatedContentNumberPreservedDespiteFolio() {
        func page(_ idx: Int) -> [PdfTextLine] {
            var lines = [placedLine("\(idx + 200)", size: 9, y: 0)] // folio in banda bassa
            if idx == 5 { lines.append(placedLine("777", size: 12, y: 400)) } // rimando isolato, una sola pagina
            lines += ["alfa", "beta"].map { placedLine("Riga \($0) del corpo della pagina \(idx).", y: 400) }
            return lines
        }
        let doc = genericPlugin.build(extraction((0..<12).map { page($0) }), sourceName: "x.pdf")

        XCTAssertTrue(
            doc.structure.contains { ($0.text ?? "").contains("777") },
            "il contenuto-numero isolato (777) è preservato: non forma progressione")
        XCTAssertFalse(
            doc.structure.contains { ($0.text ?? "") == "205" },
            "il folio (offset 200) resta rimosso per progressione")
    }

    /// Numeri-nota che ripartono da 1 a ogni pagina non formano progressione e sono
    /// preservati, anche col folio che fa ricorrere "#".
    func test_detectFurniture_restartingNoteNumbersPreserved() {
        func page(_ idx: Int) -> [PdfTextLine] {
            [placedLine("\(idx + 300)", size: 9, y: 0)] // folio
                + [placedLine("1", size: 8, y: 200), placedLine("2", size: 8, y: 150)] // note che ripartono
                + ["x", "y"].map { placedLine("Contenuto \($0) della pagina \(idx).", y: 400) }
        }
        let doc = genericPlugin.build(extraction((0..<10).map { page($0) }), sourceName: "x.pdf")

        // i marcatori di nota "1"/"2" ricorrono su ogni pagina ma il loro valore non
        // progredisce (offset diverso ad ogni pagina) → preservati.
        XCTAssertTrue(
            doc.structure.contains { ($0.text ?? "").contains("1") && ($0.text ?? "").contains("2") },
            "i numeri-nota che ripartono da 1 sono preservati")
        XCTAssertFalse(
            doc.structure.contains { ($0.text ?? "") == "305" },
            "il folio resta rimosso")
    }

    /// Una pagina-divisoria bianca (senza folio) non spezza la progressione: i folii
    /// attorno restano coerenti con v = pageIndex + offset e sono rimossi.
    func test_detectFurniture_blankDividerToleratedByProgression() {
        func page(_ idx: Int) -> [PdfTextLine] {
            let body = ["a", "b"].map { placedLine("Testo \($0) di corpo della pagina \(idx).", y: 400) }
            if idx == 6 { return body } // pagina-divisoria: nessun folio
            return [placedLine("\(idx + 10)", size: 9, y: 0)] + body
        }
        let doc = genericPlugin.build(extraction((0..<14).map { page($0) }), sourceName: "x.pdf")

        XCTAssertFalse(
            doc.structure.contains { ($0.text ?? "") == "13" || ($0.text ?? "") == "23" },
            "i folii attorno alla pagina-divisoria restano rimossi: la progressione regge")
    }

    // MARK: - Colour heading (D4) — il ramo `colorHeading` di classify()
    //
    // Tutti i test esistenti usano testo nero (#000000), quindi il ramo che promuove
    // una riga corta, saturata e distinta dal corpo a HEADING — a prescindere dalla
    // dimensione — non era mai esercitato. Anche la soppressione del testo quasi-bianco
    // (anchor invisibili) era scoperta.

    private func blackBody(_ count: Int) -> [PdfTextLine] {
        (0..<count).map { placedLine("Riga \($0) di corpo nero a dimensione normale del documento.", size: 12) }
    }

    /// Riga rossa alla STESSA dimensione del corpo: il ramo D4 la promuove comunque a
    /// heading; livello 3 perché il ratio (1.0) non raggiunge le fasce superiori.
    func test_build_colorHeadingAtBodySizeBecomesHeading3() {
        let doc = genericPlugin.build(
            extraction([[placedLine("Titolo In Rosso", size: 12, color: "#cc0000")] + blackBody(5)]),
            sourceName: "x.pdf")
        XCTAssertEqual(doc.structure.first?.type, .HEADING_3)
        XCTAssertEqual(doc.structure.first?.text, "Titolo In Rosso")
    }

    /// Il livello del colour-heading segue le fasce di ratio: 1.25 → H1, 1.125 → H2.
    func test_build_colorHeadingLevelsByRatio() {
        func headType(_ size: Double) -> SemanticCategory? {
            genericPlugin.build(
                extraction([[placedLine("Titolo Colorato", size: size, color: "#cc0000")] + blackBody(5)]),
                sourceName: "x.pdf").structure.first?.type
        }
        XCTAssertEqual(headType(15), .HEADING_1, "ratio 15/12 = 1.25 ≥ HEADING_2_RATIO → livello 1")
        XCTAssertEqual(headType(13.5), .HEADING_2, "ratio 13.5/12 = 1.125 ∈ [1.12, 1.25) → livello 2")
    }

    /// Una riga non satura (grigia) e distante in colore NON è un colour-heading: alla
    /// dimensione del corpo resta corpo (il ramo richiede saturazione > 40).
    func test_build_nonSaturatedColourIsNotAHeading() {
        let doc = genericPlugin.build(
            extraction([[placedLine("Riga Grigia Non Satura", size: 12, color: "#888888")] + blackBody(5)]),
            sourceName: "x.pdf")
        XCTAssertEqual(doc.structure.first?.type, .BODY, "grigio (max−min = 0) non è saturo → non è heading")
    }

    /// Testo quasi-bianco (anchor invisibile): soppresso prima della classificazione.
    func test_build_nearWhiteTextIsSuppressed() {
        let doc = genericPlugin.build(
            extraction([[placedLine("ancora invisibile di pagina", size: 12, color: "#fefefe")] + blackBody(3)]),
            sourceName: "x.pdf")
        XCTAssertFalse(
            doc.structure.contains { ($0.text ?? "").contains("invisibile") },
            "il testo quasi-bianco è soppresso, non emesso")
    }
}
