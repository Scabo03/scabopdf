//
//  FurnitureFrontMatterTests.swift
//  ScaboCoreTests
//
//  Estensione del mattone 1: il canale furniture GENERALIZZATO in detectFurniture —
//  qualunque riga corta sostanziale, in banda alta/bassa, ripetuta su >=3 pagine e
//  ANCORATA alla stessa y, è furniture (anche NON topmost, anche footer, con folii
//  romani normalizzati). Rimozione per-occorrenza al cluster di posizione: l'intestazione
//  vera dello stesso testo a y diversa NON è rimossa. Precisione prima del recall.
//

import XCTest
@testable import ScaboCore

final class FurnitureFrontMatterTests: XCTestCase {

    private let pageH = 700.0
    private func ln(_ text: String, yTop: Double, x0: Double = 50, w: Double = 220, size: Double = 10) -> PdfTextLine {
        let h = 12.0
        let bbox = BBox(x: x0, y: yTop - h, width: w, height: h)
        return PdfTextLine(
            spans: [PdfSpan(text: text, fontSize: size, bold: false, italic: false, color: "#000000", bbox: bbox)],
            bbox: bbox)
    }
    private func page(_ idx: Int, _ lines: [PdfTextLine]) -> PdfPageExtraction {
        PdfPageExtraction(pageIndex: idx, width: 400, height: pageH, lines: lines)
    }
    private func doc(_ special: [Int: [PdfTextLine]]) -> PdfExtraction {
        let pages = (0..<40).map { i in
            page(i, special[i] ?? [ln("Riga di corpo filler unica numero \(i).", yTop: 450)])
        }
        return PdfExtraction(version: 2, pageCount: pages.count, pages: pages)
    }

    // MARK: - helper puri

    func test_isRomanNumeralToken() {
        XCTAssertTrue(isRomanNumeralToken("II"))
        XCTAssertTrue(isRomanNumeralToken("XIII"))
        XCTAssertTrue(isRomanNumeralToken("IV."))
        XCTAssertTrue(isRomanNumeralToken("V"))
        XCTAssertFalse(isRomanNumeralToken("I"))     // articolo italiano: escluso
        XCTAssertFalse(isRomanNumeralToken("La"))
        XCTAssertFalse(isRomanNumeralToken("Capitolo"))
        XCTAssertFalse(isRomanNumeralToken(""))
    }
    func test_furnitureNorm_romanAndDigits() {
        XCTAssertEqual(furnitureNorm("PREMESSA VII"), "premessa #")
        XCTAssertEqual(furnitureNorm("PREMESSA VIII"), "premessa #")  // stesso norm → ricorrente
        XCTAssertEqual(furnitureNorm("316 XIII. La sentenza"), "# # la sentenza")  // "XIII." token→#
        XCTAssertEqual(furnitureNorm("I diritti di credito"), "i diritti di credito")  // "I" non normalizzato
        XCTAssertEqual(furnitureNorm("© Wolters Kluwer Italia"), "© wolters kluwer italia")
    }

    // MARK: - rimozione (le nuove capacità)

    func test_nonTopmost_runningHeader_removed() {
        // due righe in banda alta: la 630 (topmost) e la 600 (NON topmost) ricorrono ancorate.
        var sp: [Int: [PdfTextLine]] = [:]
        for p in 0..<5 {
            sp[p] = [ln("Capitolo Primo", yTop: 630),
                     ln("La giurisdizione 77", yTop: 600),  // running header NON-topmost
                     ln("Corpo unico della pagina \(p).", yTop: 450)]
        }
        let furn = detectFurniture(doc(sp))
        for p in 0..<5 { XCTAssertTrue(furn.contains("\(p):1"), "il running-header non-topmost p\(p) è furniture") }
        XCTAssertFalse(furn.contains("0:2"), "il corpo no")
    }

    func test_romanFolioHeader_grouped_removed() {
        // "PREMESSA VII/VIII/IX/X" su 4 pagine front-matter → un'unica norma → rimossa.
        var sp: [Int: [PdfTextLine]] = [:]
        let romans = ["VII", "VIII", "IX", "X"]
        for (p, r) in romans.enumerated() {
            sp[p] = [ln("PREMESSA \(r)", yTop: 640), ln("Prosa della premessa \(p).", yTop: 450)]
        }
        let furn = detectFurniture(doc(sp))
        for p in 0..<4 { XCTAssertTrue(furn.contains("\(p):0"), "PREMESSA <romano> p\(p) rimossa") }
    }

    func test_recurringFooter_removed() {
        var sp: [Int: [PdfTextLine]] = [:]
        for p in 0..<5 {
            sp[p] = [ln("Corpo unico \(p).", yTop: 450), ln("© Wolters Kluwer Italia", yTop: 30)]  // footer bottom band
        }
        let furn = detectFurniture(doc(sp))
        for p in 0..<5 { XCTAssertTrue(furn.contains("\(p):1"), "il footer ricorrente p\(p) è furniture") }
    }

    // MARK: - PROTEZIONE titolo-corrente (mobilia ripetuta vs intestazione singola)

    func test_chapterTitle_runningHeaderRemoved_realHeadingKept() {
        // Caso realistico: il running header porta il FOLIO ("… 51", norma "… #") e ricorre
        // ancorato (mobilia); l'intestazione VERA è senza folio (norma DIVERSA) → non
        // raggruppata → resta. 4 pagine < pavimento-banda(6): isola il nuovo canale.
        var sp: [Int: [PdfTextLine]] = [:]
        for p in 0..<4 {
            sp[p] = [ln("Il codice civile francese 51", yTop: 630), ln("Corpo \(p).", yTop: 450)]
        }
        sp[6] = [ln("Il codice civile francese", yTop: 600),   // intestazione vera, norma diversa
                 ln("Inizio del capitolo sul code civil, prosa.", yTop: 450)]
        let furn = detectFurniture(doc(sp))
        for p in 0..<4 { XCTAssertTrue(furn.contains("\(p):0"), "running header (col folio) p\(p) rimosso") }
        XCTAssertFalse(furn.contains("6:0"), "l'intestazione VERA (senza folio, norma diversa) resta")
    }

    func test_chapterTitle_sameTextHeading_conservativelyKept() {
        // Caso limite: l'intestazione vera ha lo STESSO testo del running header (stessa norma)
        // ma a y diversa → il suo outlier alza σ oltre LOCK → full-set-strict NON rimuove nulla
        // (conservativo: l'intestazione è salva; si manca la mobilia, mai si tocca il contenuto).
        var sp: [Int: [PdfTextLine]] = [:]
        for p in 0..<4 { sp[p] = [ln("Capitolo Primo", yTop: 630), ln("Corpo \(p).", yTop: 450)] }
        sp[6] = [ln("Capitolo Primo", yTop: 600), ln("Prosa.", yTop: 450)]
        let furn = detectFurniture(doc(sp))
        XCTAssertFalse(furn.contains("6:0"), "l'intestazione VERA stesso-testo NON è rimossa (σ>LOCK)")
    }

    func test_bigHeading_recurringLocked_notRemoved() {
        // intestazioni-capitolo "CAPITOLO II/III/IV" (norma roman → "capitolo #") tutte alla
        // stessa y d'inizio-capitolo (ancorate) ma PIÙ GRANDI del corpo → la guardia-dimensione
        // le esclude → NON rimosse. È il FP che ci avrebbe mangiato le intestazioni vere.
        var sp: [Int: [PdfTextLine]] = [:]
        let romans = ["II", "III", "IV", "V"]
        for (p, r) in romans.enumerated() {
            sp[p] = [ln("CAPITOLO \(r)", yTop: 630, size: 15),   // intestazione, 15pt > corpo 10
                     ln("Corpo unico della pagina \(p).", yTop: 450)]
        }
        let furn = detectFurniture(doc(sp))
        for p in 0..<4 { XCTAssertFalse(furn.contains("\(p):0"), "intestazione grande (>corpo) NON rimossa") }
    }

    func test_structureHeading_bodySized_recurringLocked_notRemoved() {
        // intestazioni a TAGLIA-CORPO (maiuscoletto, non più grandi) che ricorrono identiche in
        // più parti ("CAPITOLO QUINTO" / "SEZIONE SECONDA") e ancorate → la guardia struttura
        // del NUOVO canale (si auto-dichiarano intestazioni) le esclude → NON rimosse. (size
        // guard non basta: sono a corpo). È il FP residuo di Estratto/Lineamenti. Sono NON-topmost
        // (una riga unica sopra), così il test isola il nuovo canale dal mattone 1 (topmost).
        var sp: [Int: [PdfTextLine]] = [:]
        for p in 0..<3 { sp[p] = [ln("Pag. \(p) testatina unica del volume", yTop: 660),
                                  ln("CAPITOLO QUINTO", yTop: 630), ln("Corpo \(p).", yTop: 450)] }
        for p in 3..<6 { sp[p] = [ln("Pag. \(p) testatina unica del volume", yTop: 660),
                                  ln("SEZIONE SECONDA", yTop: 630), ln("Corpo \(p).", yTop: 450)] }
        let furn = detectFurniture(doc(sp))
        for p in 0..<6 { XCTAssertFalse(furn.contains("\(p):1"), "intestazione struttura a corpo (non-topmost) NON rimossa") }
    }

    // MARK: - PRECISIONE (nessun falso positivo)

    func test_midPage_recurringLine_notRemoved() {
        // riga ricorrente ANCORATA ma a metà pagina (fuori banda): NON è furniture.
        var sp: [Int: [PdfTextLine]] = [:]
        for p in 0..<6 {
            sp[p] = [ln("Capitolo Primo", yTop: 630), ln("Massima ricorrente a metà pagina.", yTop: 350)]
        }
        let furn = detectFurniture(doc(sp))
        for p in 0..<6 { XCTAssertFalse(furn.contains("\(p):1"), "la riga a metà pagina NON è furniture (banda)") }
    }
    func test_notPositionLocked_notRemoved() {
        // stessa norma ma a y VARIABILI in banda → non ancorata → non furniture.
        var sp: [Int: [PdfTextLine]] = [:]
        let ys = [640.0, 560.0, 600.0, 520.0, 660.0]
        for (p, y) in ys.enumerated() {
            sp[p] = [ln("La giurisdizione 77", yTop: y), ln("Corpo \(p).", yTop: 450)]
        }
        let furn = detectFurniture(doc(sp))
        for p in 0..<5 { XCTAssertFalse(furn.contains("\(p):0"), "non ancorata → non furniture") }
    }
    func test_belowThreshold_notRemoved() {
        var sp: [Int: [PdfTextLine]] = [:]
        for p in 0..<2 {   // solo 2 pagine < 3
            sp[p] = [ln("Testatina rara", yTop: 630), ln("Corpo \(p).", yTop: 450)]
        }
        let furn = detectFurniture(doc(sp))
        for p in 0..<2 { XCTAssertFalse(furn.contains("\(p):0"), "sotto soglia → non furniture") }
    }
}
