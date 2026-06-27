//
//  RunningHeaderFurnitureTests.swift
//  ScaboCoreTests
//
//  Il NUOVO canale furniture per le testatine correnti di capitolo (detectFurniture):
//  la riga PIÙ IN ALTO, sostanziale, corta, in banda superiore, ricorrente su >= 3 pagine
//  e ANCORATA alla stessa y, è una testatina — anche sotto il pavimento globale del 15%.
//
//  I test usano documenti da 40 pagine così che il pavimento globale (`minPages` = ceil(
//  0.15·40) = 6) NON copra una testatina su 3–5 pagine: isola il nuovo canale dal vecchio.
//  Le guardie di precisione (riga-più-in-alto + ancoraggio posizionale) sono stressate
//  esplicitamente: nota a piè (in basso), sotto-titolo di sezione (sotto la testatina),
//  posizione non ancorata, conteggio sotto soglia — nessuno dei quali va rimosso.
//

import XCTest
@testable import ScaboCore

final class RunningHeaderFurnitureTests: XCTestCase {

    private let pageH = 700.0

    /// Una riga a `yTop` (banda: yTop/700; top band se >= 0.85·700 = 595).
    private func ln(_ text: String, yTop: Double, x0: Double = 50, w: Double = 220) -> PdfTextLine {
        let h = 12.0
        let bbox = BBox(x: x0, y: yTop - h, width: w, height: h)
        return PdfTextLine(
            spans: [PdfSpan(text: text, fontSize: 10, bold: false, italic: false, color: "#000000", bbox: bbox)],
            bbox: bbox)
    }
    private func page(_ idx: Int, _ lines: [PdfTextLine]) -> PdfPageExtraction {
        PdfPageExtraction(pageIndex: idx, width: 400, height: pageH, lines: lines)
    }
    /// 40-page doc; `special` supplies the lines for pages it covers, else a filler body.
    private func doc(_ special: [Int: [PdfTextLine]]) -> PdfExtraction {
        let pages = (0..<40).map { i in
            page(i, special[i] ?? [ln("Riga di corpo filler unica numero \(i).", yTop: 500)])
        }
        return PdfExtraction(version: 2, pageCount: pages.count, pages: pages)
    }

    // MARK: - La testatina corrente viene rimossa (sotto il pavimento del 15%)

    func test_runningHeader_removed_belowGlobalFloor() {
        // Nota: il canale furniture è stato generalizzato (estensione mattone 1: cattura anche
        // i ricorrenti non-topmost/footer ancorati). La nota a piè qui ha y VARIABILE per pagina
        // (come nella realtà: la sua posizione dipende da quante note ci sono) → σ alta → salva.
        var sp: [Int: [PdfTextLine]] = [:]
        let noteY = [35.0, 52.0, 41.0, 60.0, 33.0]   // varia: nota a piè reale non è ancorata
        for p in 0..<5 {   // 5 pagine < minPages(6): il vecchio canale la mancherebbe
            sp[p] = [ln("Capitolo Primo", yTop: 630),                  // testatina, topmost, y locked
                     ln("Testo del corpo della pagina \(p), unico.", yTop: 500),
                     ln("12. Una nota a piè di pagina.", yTop: noteY[p])]
        }
        let furn = detectFurniture(doc(sp))
        for p in 0..<5 { XCTAssertTrue(furn.contains("\(p):0"), "testatina pagina \(p) rimossa") }
        XCTAssertFalse(furn.contains("0:1"), "il corpo non è furniture")
        XCTAssertFalse(furn.contains("0:2"), "la nota a piè (y variabile) non è furniture")
    }

    // MARK: - Le guardie di precisione (nessun falso positivo)

    /// Sotto-titolo di sezione (non running header): col canale generalizzato la guardia è
    /// l'ANCORAGGIO. Un sotto-titolo vero non è ancorato a σ≈0 (compare a y diverse, ai vari
    /// inizi-sezione); qui ha y VARIABILE → σ alta → non rimosso. (Un sotto-titolo ancorato a
    /// σ≈0 su molte pagine sarebbe un running sub-header = mobilia, ed è giusto toglierlo.)
    func test_sectionSubheading_belowHeader_notRemoved() {
        var sp: [Int: [PdfTextLine]] = [:]
        let subY = [600.0, 585.0, 612.0, 578.0, 620.0]   // varia: inizio-sezione, non ancorato
        for p in 0..<5 {
            sp[p] = [ln("Capitolo Primo", yTop: 630),     // testatina (topmost, ancorata)
                     ln("3.4.1 Definizioni", yTop: subY[p]),  // sotto-titolo in banda, y variabile
                     ln("Corpo unico della pagina \(p).", yTop: 500)]
        }
        let furn = detectFurniture(doc(sp))
        XCTAssertTrue(furn.contains("0:0"), "la testatina sì")
        for p in 0..<5 { XCTAssertFalse(furn.contains("\(p):1"), "il sotto-titolo (non ancorato) NON va rimosso") }
    }

    /// Nota a piè ricorrente (collisione di norma): è in basso, mai topmost.
    func test_footnoteLike_recurring_notRemoved() {
        var sp: [Int: [PdfTextLine]] = [:]
        let ys = [40.0, 60.0, 45.0, 38.0]   // varie, in fondo
        for p in 0..<4 {
            sp[p] = [ln("Corpo unico in alto pagina \(p).", yTop: 650),
                     ln("Cass., 17 gennaio 2020, n. 99.", yTop: ys[p])]
        }
        let furn = detectFurniture(doc(sp))
        for p in 0..<4 { XCTAssertFalse(furn.contains("\(p):1"), "la nota a piè NON va rimossa") }
    }

    /// Riga topmost ricorrente ma a posizione NON ancorata (σ alta) → non è testatina.
    func test_topmost_butNotPositionLocked_notRemoved() {
        var sp: [Int: [PdfTextLine]] = [:]
        let ys = [630.0, 620.0, 610.0, 600.0]   // yfrac 0.900..0.857 → σ ≈ 0.016 > 0.006
        for p in 0..<4 { sp[p] = [ln("Riga in alto variabile", yTop: ys[p]), ln("Corpo \(p).", yTop: 500)] }
        let furn = detectFurniture(doc(sp))
        for p in 0..<4 { XCTAssertFalse(furn.contains("\(p):0"), "posizione non ancorata → non rimossa") }
    }

    /// Sotto la soglia di ricorrenza (2 pagine) → non rimossa.
    func test_belowMinPages_notRemoved() {
        var sp: [Int: [PdfTextLine]] = [:]
        for p in 0..<2 { sp[p] = [ln("Testatina Rara", yTop: 630), ln("Corpo \(p).", yTop: 500)] }
        let furn = detectFurniture(doc(sp))
        XCTAssertFalse(furn.contains("0:0"))
        XCTAssertFalse(furn.contains("1:0"))
    }

    /// Riga ricorrente nel MEZZO della pagina (fuori dalle bande furniture 0.28–0.72) → non
    /// candidata, nemmeno col canale generalizzato (la banda esclude un lock di corpo centrale).
    func test_topmost_belowTopBand_notRemoved() {
        var sp: [Int: [PdfTextLine]] = [:]
        for p in 0..<5 { sp[p] = [ln("Riga nel mezzo", yTop: 400), ln("Corpo \(p).", yTop: 300)] }  // 400/700=0.57, fuori banda
        let furn = detectFurniture(doc(sp))
        for p in 0..<5 { XCTAssertFalse(furn.contains("\(p):0")) }
    }

    /// Una testatina che APRE una regione d'apparato esclusa (indice dei nomi/sentenze) NON
    /// va rimossa: il rilevatore d'apparato la usa per aprire la regione (pagine escluse dal
    /// flusso). Toglierla farebbe LEGGERE l'indice (regressione Mosconi INDEX_ENTRY 26→1).
    func test_excludedApparatusRegionHeader_notRemovedAsFurniture() {
        var sp: [Int: [PdfTextLine]] = [:]
        for p in 0..<4 {  // 4 pagine < minPages(6): solo il nuovo canale potrebbe prenderla,
            // ma è topmost+ancorata che APRE l'indice → guardia la protegge.
            sp[p] = [ln("554 Indice cronologico delle sentenze citate", yTop: 660),
                     ln("Cass., \(10 + p) gennaio 2020, n. \(p).", yTop: 400)]
        }
        let furn = detectFurniture(doc(sp))
        for p in 0..<4 {
            XCTAssertFalse(furn.contains("\(p):0"),
                "la testatina dell'indice NON va rimossa (apre la regione esclusa)")
        }
    }

    /// Folio (numero nudo) sopra la testatina: salta il bare-number, prende la testatina sotto.
    func test_bareNumberAboveHeader_headerStillCandidate() {
        var sp: [Int: [PdfTextLine]] = [:]
        for p in 0..<5 {
            sp[p] = [ln("\(100 + p)", yTop: 660),          // folio nudo (non sostanziale)
                     ln("Capitolo Primo", yTop: 630),       // testatina: topmost SOSTANZIALE
                     ln("Corpo \(p).", yTop: 500)]
        }
        let furn = detectFurniture(doc(sp))
        for p in 0..<5 { XCTAssertTrue(furn.contains("\(p):1"), "testatina sotto il folio nudo rimossa") }
    }
}
