//
//  DejureTitlesTests.swift
//  ScaboCoreTests
//
//  Ramo DeJure, giro finale 2026-10-08 (voce 6): i titoli in grassetto a taglia di corpo diventano titoli navigabili;
//  la pagina finale di un export breve, che porta il timbro, resta letta. Ogni regola ha la sua prova al contrario.
//  Testi di prova; geometria reale (origine in basso).
//

import XCTest
@testable import ScaboCore

final class DejureTitlesTests: XCTestCase {

    private let body = 12.0

    private func line(_ text: String, top: Double, size: Double = 12, bold: Bool = false, boldPrefix: Int = 0) -> PdfTextLine {
        let h = size * 1.2
        let width = Double(text.count) * size * 0.45
        if boldPrefix > 0, boldPrefix < text.count {
            let a = String(text.prefix(boldPrefix)), b = String(text.dropFirst(boldPrefix))
            let wa = width * Double(a.count) / Double(text.count)
            return PdfTextLine(spans: [
                PdfSpan(text: a, fontSize: size, bold: true, italic: false, color: "#000000", bbox: BBox(x: 72, y: top - h, width: wa, height: h)),
                PdfSpan(text: b, fontSize: size, bold: false, italic: false, color: "#000000", bbox: BBox(x: 72 + wa, y: top - h, width: width - wa, height: h)),
            ], bbox: BBox(x: 72, y: top - h, width: width, height: h))
        }
        let box = BBox(x: 72, y: top - h, width: width, height: h)
        return PdfTextLine(spans: [PdfSpan(text: text, fontSize: size, bold: bold, italic: false, color: "#000000", bbox: box)], bbox: box)
    }
    private func bodyLines(_ n: Int, from top: Double) -> [PdfTextLine] {
        (0..<n).map { line("Riga di prova del corpo numero \($0) che riempie la colonna fino al margine destro.", top: top - Double($0) * 16) }
    }
    /// Pagina DeJure: righe date dall'alto, una nota a 8 pt (secondo stile del documento) e il piè «Pagina N di M».
    private func page(_ index: Int, of total: Int, _ lines: [PdfTextLine]) -> PdfPageExtraction {
        PdfPageExtraction(pageIndex: index, width: 612, height: 792, lines: lines + [
            line("(\(index + 1)) Nota di prova a piè di pagina con un rinvio qualunque.", top: 110, size: 8),
            line("Pagina \(index + 1) di \(total)", top: 40, size: 9),
        ])
    }
    /// La firma DeJure guarda producer E creator: la prova al contrario li cambia entrambi.
    private func extraction(_ pages: [PdfPageExtraction], producer: String = "Aspose.PDF for .NET 18.4") -> PdfExtraction {
        PdfExtraction(version: 2, pageCount: pages.count, pages: pages, producer: producer,
                      creator: producer.contains("Aspose") ? "Aspose Ltd." : "Adobe InDesign")
    }
    private func headings(_ d: ScabopdfDocument) -> [(String, Int)] {
        d.structure.compactMap { $0.type.rawValue.hasPrefix("HEADING_") ? ($0.text ?? "", $0.level ?? 0) : nil }
    }
    private func readText(_ d: ScabopdfDocument) -> String { buildBaseSegments(d).map { $0.text }.joined(separator: " ") }

    /// Articolo di dottrina: titolo d'articolo in grassetto appena più grande del corpo, sezioni e sottosezione in
    /// grassetto a taglia di corpo dentro il corpo.
    private func article(producer: String = "Aspose.PDF for .NET 18.4") -> PdfExtraction {
        let p0 = [line("Titolo di prova dell'articolo", top: 740, size: 13, bold: true)]
            + bodyLines(4, from: 710)
            + [line("1. Prima sezione di prova", top: 630, bold: true)]
            + bodyLines(4, from: 610)
            + [line("1.1. Sottosezione di prova", top: 530, bold: true)]
            + bodyLines(4, from: 510)
        let p1 = [line("2. Seconda sezione di prova", top: 740, bold: true)] + bodyLines(8, from: 720)
        let p2 = bodyLines(10, from: 740)
        return extraction([page(0, of: 3, p0), page(1, of: 3, p1), page(2, of: 3, p2)], producer: producer)
    }

    func test_article_titleSectionsAndSubsection_nestAsOneTwoThree() {
        let d = buildDocumentFromPdf(article(), sourceName: "dt.pdf")
        XCTAssertEqual(headings(d).map { $0.1 }, [1, 2, 3, 2])
        XCTAssertEqual(headings(d).map { $0.0 }, ["Titolo di prova dell'articolo", "1. Prima sezione di prova",
                                                  "1.1. Sottosezione di prova", "2. Seconda sezione di prova"])
        XCTAssertTrue(readText(d).contains("Riga di prova del corpo numero 3"), "il corpo resta letto")
    }

    private func massima(producer: String = "Aspose.PDF for .NET 18.4") -> PdfExtraction {
        // a metà pagina, al passo del corpo, come i titoli delle massime che seguono la precedente
        let p0 = bodyLines(5, from: 740)
            + [line("Titolo di prova della massima che va a capo", top: 660, bold: true),
               line("su una seconda riga in grassetto", top: 644, bold: true)]
            + bodyLines(6, from: 628)
        return extraction([page(0, of: 2, p0), page(1, of: 2, bodyLines(10, from: 740))], producer: producer)
    }

    func test_massimaTitle_unnumbered_isLevelOne_upToThreeLines() {
        let d = buildDocumentFromPdf(massima(), sourceName: "mm.pdf")
        XCTAssertEqual(headings(d).map { $0.1 }, [1])
        XCTAssertEqual(headings(d).first?.0, "Titolo di prova della massima che va a capo su una seconda riga in grassetto")
    }

    func test_counterProof_withoutTheDejureSignature_boldLinesStayBody() {
        let d = buildDocumentFromPdf(massima(producer: "Adobe PDF Library 15.0"), sourceName: "x.pdf")
        XCTAssertEqual(headings(d).count, 0, "fuori da DeJure la foglia tace: \(headings(d))")
    }

    func test_counterProofs_partialBold_tooLong_noteLabel_stayBody() {
        // grassetto in linea nel corpo (meno dell'80 %)
        let mixed = line("Una riga di prova con poche parole in grassetto all'inizio e il resto in tondo.", top: 640, boldPrefix: 20)
        // quattro righe in grassetto di fila: non è un titolo
        let four = (0..<4).map { line("Blocco di prova in grassetto, riga \($0)", top: 560 - Double($0) * 16, bold: true) }
        let note = line("Note:", top: 460, bold: true)
        let p0 = bodyLines(4, from: 740) + [mixed] + bodyLines(2, from: 620) + four + [note] + bodyLines(3, from: 440)
        let d = buildDocumentFromPdf(extraction([page(0, of: 2, p0), page(1, of: 2, bodyLines(10, from: 740))]), sourceName: "x.pdf")
        XCTAssertEqual(headings(d).count, 0, "\(headings(d))")
    }

    func test_noteLabel_neverOpensATitle_atTheLineLevel() {
        let profile = estimateProfile(article())
        XCTAssertTrue(profile.isDejure)
        let lines = [summarizeLine(line("Note:", top: 500, bold: true)), summarizeLine(line("Riga di prova del corpo.", top: 484))]
        let out = recognizeDejureBoldTitles([.run(.body, lines)], profile)
        XCTAssertEqual(out.count, 1, "l'etichetta della sezione delle note resta nel corpo")
        if case .run(.body, let kept) = out.first { XCTAssertEqual(kept.count, 2) } else { XCTFail("atteso un run di corpo") }
    }

    func test_shortExport_lastPageWithTheStamp_isRead() {
        let p0 = [line("Titolo di prova della massima", top: 740, bold: true)] + bodyLines(8, from: 720)
        let p1 = bodyLines(3, from: 740) + [line("Ultima frase di prova della seconda pagina.", top: 690),
                                           line("SERVIZIO GESTIONE RISORSE DOCUMENTARIE © Copyright Giuffrè Francis Lefebvre S.p.A. 2031", top: 600, size: 9)]
        let d = buildDocumentFromPdf(extraction([page(0, of: 2, p0), page(1, of: 2, p1)]), sourceName: "breve.pdf")
        XCTAssertTrue(readText(d).contains("Ultima frase di prova della seconda pagina."), "la pagina finale si legge")
        XCTAssertFalse(readText(d).contains("SERVIZIO GESTIONE RISORSE"), "il timbro resta non letto")
    }
}
