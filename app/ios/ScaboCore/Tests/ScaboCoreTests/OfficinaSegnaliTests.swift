//
//  OfficinaSegnaliTests.swift
//  ScaboCoreTests
//
//  I segnali dell'app con cui l'officina Mac sceglie le pagine da mandare al modello d'impaginazione (giro «costruzione
//  della linea Mac», 2026-10-16): l'indice analitico anche quando il titolo porta il richiamo di una nota e la testatina
//  è mobilia (`officinaAnalyticalIndexPages`), e il predicato di ricucitura delle note esposto senza cambiarlo
//  (`officinaNoteTailContinuesHead`). Il back-matter dell'iPad non cambia: lo si verifica sullo stesso documento.
//  Testo sintetico, nessun volume.
//

import XCTest
@testable import ScaboCore

final class OfficinaSegnaliTests: XCTestCase {

    private func line(_ text: String, _ size: Double = 10, y: Double = 100) -> PdfTextLine {
        let b = BBox(x: 100, y: y, width: Double(max(1, text.count)) * 2, height: size)
        return PdfTextLine(spans: [PdfSpan(text: text, fontSize: size, bold: false, italic: false, color: "#000000", bbox: b)], bbox: b)
    }
    private func tag(_ n: Int) -> String {
        let a = Array("abcdefghijklmnopqrstuvwxyz")
        return "\(a[n % 26])\(a[(n / 26) % 26])"
    }
    private func bodyPage(_ idx: Int) -> PdfPageExtraction {
        PdfPageExtraction(pageIndex: idx, width: 595, height: 842, lines: (0..<6).map { i in
            line("Riga di corpo \(tag(idx))\(tag(i)) abbastanza lunga da formare un paragrafo vero di lettura.", 10, y: 100 + Double(i) * 14)
        })
    }
    private func entries(_ n: Int, _ salt: String) -> [PdfTextLine] {
        (0..<n).map { line("Voce d’indice \(salt)\(tag($0)), \($0 + 3)", 9, y: 120 + Double($0) * 12) }
    }
    /// 34 pagine di corpo, poi la prima pagina dell'indice con il titolo che porta il richiamo «(*)», poi quattro
    /// pagine d'indice con la sola testatina ripetuta (mobilia), poi una pagina di corpo.
    private func extraction(title: String = "(*) INDICE ANALITICO-ALFABETICO (*)", header: String = "INDICE ANALITICO-ALFABETICO",
                            indexLike: Bool = true) -> PdfExtraction {
        var pages = (0..<34).map { bodyPage($0) }
        let first = [line(title, 12, y: 60)] + (indexLike ? entries(20, "a") : bodyPage(34).lines)
        pages.append(PdfPageExtraction(pageIndex: 34, width: 595, height: 842, lines: first))
        for k in 0..<4 {
            let lines = [line(header, 9, y: 30)] + (indexLike ? entries(20, "b\(k)") : bodyPage(35 + k).lines)
            pages.append(PdfPageExtraction(pageIndex: 35 + k, width: 595, height: 842, lines: lines))
        }
        pages.append(bodyPage(39))
        return PdfExtraction(version: 2, pageCount: pages.count, pages: pages)
    }

    func test_indiceAnalitico_titoloConRichiamo_testatinaMobilia_paginateScelte() {
        let ex = extraction()
        XCTAssertEqual(officinaAnalyticalIndexPages(ex), [34, 35, 36, 37, 38])
        // La testatina è davvero mobilia per il back-matter dell'iPad: il segnale la guarda lo stesso.
        let furniture = detectFurniture(ex)
        XCTAssertTrue(furniture.contains("35:0") && furniture.contains("38:0"), "testatina ripetuta = mobilia")
    }

    func test_backMatterDellIPad_invariato_suLoStessoDocumento() {
        // Il richiamo in testa al titolo e la testatina-mobilia fanno sì che il back-matter dell'iPad non apra la
        // regione analitica: le voci restano LETTE (nessuna mappa), esattamente come prima del giro.
        let ex = extraction()
        XCTAssertTrue(detectBackMatterApparatus(ex, detectFurniture(ex)).isEmpty)
        let doc = buildDocumentFromPdf(ex, sourceName: "prova.pdf")
        XCTAssertTrue(buildBaseSegments(doc).map { $0.text }.joined(separator: " ").contains("Voce d’indice"))
    }

    func test_senzaTitolo_oProsaConTitolo_nessunaPagina() {
        XCTAssertEqual(officinaAnalyticalIndexPages(extraction(title: "Tabelle riassuntive", header: "Tabelle riassuntive")), [])
        XCTAssertEqual(officinaAnalyticalIndexPages(extraction(indexLike: false)), [], "titolo d'indice su prosa: nessuna pagina")
    }

    func test_tantiTitoli_varianti_riconosciuti() {
        for t in ["INDICE ANALITICO", "Indice alfabetico", "(*) INDICE ANALITICO-ALFABETICO (*)", "* Indice analitico", "2488 INDICE ANALITICO-ALFABETICO"] {
            XCTAssertFalse(officinaAnalyticalIndexPages(extraction(title: t, header: t)).isEmpty, t)
        }
        for t in ["Indice dei nomi", "Sommario", "Bibliografia"] {
            XCTAssertTrue(officinaAnalyticalIndexPages(extraction(title: t, header: t)).isEmpty, t)
        }
    }

    func test_ricucitura_predicatoEsposto_ugualeAQuelloDellApp() {
        let casi: [(String, String)] = [
            ("La nota prosegue con la virgola,", "e qui continua in minuscolo."),
            ("La nota si chiude.", "Una frase nuova comincia."),
            ("Rinvio all'art.", "12 della legge."),
            ("Testa aperta", "2. Una nota nuova con il suo numero."),
        ]
        for (h, t) in casi {
            XCTAssertEqual(officinaNoteTailContinuesHead(head: h, tail: t), noteTailContinuesHead(head: h, tail: t), "\(h) | \(t)")
        }
    }
}
