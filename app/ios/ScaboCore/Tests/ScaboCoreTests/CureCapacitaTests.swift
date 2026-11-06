//
//  CureCapacitaTests.swift
//  ScaboCoreTests
//
//  Le CURE PER CAPACITÀ del giro «rifiniture e cure per capacità» (2026-11-06/07, seconda parte): titolo ripetuto dalla
//  testatina (voce 2.1), titoli in grassetto delle dispense Word (2.2), titoli di sezione isolati da stacchi (2.3), note di
//  chiusura e colonna dei richiami (2.4), figure ricorrenti per contenuto (2.5), trattino morbido seguito da uno spazio
//  (2.6). Ogni forma con i suoi casi contrari. Tutti i testi sono inventati per la prova.
//

import XCTest
@testable import ScaboCore

final class CureCapacitaTests: XCTestCase {

    private func span(_ text: String, _ size: Double, bold: Bool = false, x: Double, y: Double, width: Double,
                      height: Double = 12) -> PdfSpan {
        PdfSpan(text: text, fontSize: size, bold: bold, italic: false, color: "#000000",
                bbox: BBox(x: x, y: y, width: width, height: height))
    }
    private func line(_ text: String, size: Double, bold: Bool = false, x: Double, y: Double, width: Double,
                      height: Double = 12) -> PdfTextLine {
        PdfTextLine(spans: [span(text, size, bold: bold, x: x, y: y, width: width, height: height)],
                    bbox: BBox(x: x, y: y, width: width, height: height))
    }
    private func extraction(_ pages: [[PdfTextLine]], producer: String? = nil, width: Double = 400,
                            height: Double = 600) -> PdfExtraction {
        PdfExtraction(version: 2, pageCount: pages.count,
                      pages: pages.enumerated().map { PdfPageExtraction(pageIndex: $0.offset, width: width, height: height,
                                                                        lines: $0.element) },
                      producer: producer)
    }
    private let words = ["alba", "bosco", "cielo", "duna", "eco", "faro", "golfo", "isola", "lago", "monte", "nube", "onda"]

    /// Un capitolo di dieci pagine: sulla prima il titolo grande in cima, sulle altre la testatina piccola che lo ripete.
    private func chapterWithRunningHead(headSizes: [Double]) -> PdfExtraction {
        var pages: [[PdfTextLine]] = []
        for k in 0..<10 {
            var p: [PdfTextLine] = []
            if k == 0 {
                p.append(line("Un titolo inventato", size: 14, x: 60, y: 540, width: 140, height: 15))
            } else {
                p.append(line("Un titolo inventato", size: headSizes[(k - 1) % headSizes.count], x: 120, y: 565, width: 90,
                              height: 9))
            }
            for r in 0..<8 {
                p.append(line("Una riga di corpo inventata sulla parola \(words[k]) numero \(words[r]) di prova.", size: 11,
                              x: 60, y: 500 - Double(r) * 13, width: 280, height: 11))
            }
            pages.append(p)
        }
        return extraction(pages)
    }

    // MARK: - 2.1 Il titolo che la testatina ripete non è mobilia

    func test_titleRepeatedByRunningHead_isNotFurniture_butTheRunningHeadsAre() {
        let ex = chapterWithRunningHead(headSizes: [8.5])
        let furniture = detectFurniture(ex)
        XCTAssertFalse(furniture.contains("0:0"), "il titolo vero della pagina d'apertura resta testo")
        XCTAssertTrue((1..<10).allSatisfy { furniture.contains("\($0):0") }, "le testatine restano mobilia")
        let doc = buildDocumentFromPdf(ex, sourceName: "prova.pdf")
        XCTAssertTrue(doc.structure.contains { $0.type.rawValue.hasPrefix("HEADING") && $0.text == "Un titolo inventato" })
    }

    func test_runningHeadThatChangesSizeHalfTheTime_staysFurniture() {
        // Recto e verso a taglie diverse (metà e metà): la taglia grande non è rara, nessuna esenzione.
        let ex = chapterWithRunningHead(headSizes: [8.5, 14])
        let furniture = detectFurniture(ex)
        XCTAssertTrue((1..<10).allSatisfy { furniture.contains("\($0):0") })
    }

    // MARK: - 2.2 Titoli in grassetto delle dispense Word

    private func wordHandout(producer: String?, partialBold: Bool = false, boldEvery: Int = 12) -> PdfExtraction {
        var pages: [[PdfTextLine]] = []
        for k in 0..<4 {
            var p: [PdfTextLine] = []
            var y = 800.0
            for r in 0..<36 {
                if r % boldEvery == 0 {
                    p.append(line("\(r / boldEvery + 1). Un titolo di paragrafo inventato \(words[k])", size: 12, bold: true,
                                  x: 64, y: y, width: 260))
                } else if partialBold && r == 5 {
                    p.append(PdfTextLine(spans: [span("Una frase con ", 12, x: 64, y: y, width: 80),
                                                 span("una parola", 12, bold: true, x: 144, y: y, width: 60),
                                                 span(" in rilievo inventata.", 12, x: 204, y: y, width: 120)],
                                         bbox: BBox(x: 64, y: y, width: 260, height: 12)))
                } else {
                    p.append(line("Una riga di corpo inventata \(words[k]) \(words[r % 12]) che prosegue fino al margine.",
                                  size: 12, x: 64, y: y, width: 300))
                }
                y -= 20
            }
            pages.append(p)
        }
        return extraction(pages, producer: producer, width: 595, height: 842)
    }

    func test_wordBoldTitles_signatureAndRecognition() {
        let ex = wordHandout(producer: "Microsoft® Word per Microsoft 365")
        XCTAssertTrue(wordBoldTitlesSignature(ex, body: 12))
        XCTAssertTrue(estimateProfile(ex).wordBoldTitles)
        let doc = buildDocumentFromPdf(ex, sourceName: "prova.pdf")
        let headings = doc.structure.filter { $0.type.rawValue.hasPrefix("HEADING") }
        XCTAssertEqual(headings.count, 12, "tre titoli per pagina su quattro pagine")
        XCTAssertTrue(headings.allSatisfy { ($0.text ?? "").contains("Un titolo di paragrafo inventato") })
    }

    func test_wordBoldTitles_signatureIsOffWithPartialBold_otherProducers_orTooMuchBold() {
        XCTAssertFalse(wordBoldTitlesSignature(wordHandout(producer: "Microsoft® Word per Microsoft 365", partialBold: true), body: 12),
                       "il grassetto dentro una frase spegne la firma")
        XCTAssertFalse(wordBoldTitlesSignature(wordHandout(producer: "Un altro programma"), body: 12), "solo le dispense Word")
        XCTAssertFalse(wordBoldTitlesSignature(wordHandout(producer: nil), body: 12))
        XCTAssertFalse(wordBoldTitlesSignature(wordHandout(producer: "Microsoft® Word", boldEvery: 2), body: 12),
                       "righe in grassetto troppo frequenti: testo, non titoli")
        let plain = buildDocumentFromPdf(wordHandout(producer: "Un altro programma"), sourceName: "prova.pdf")
        XCTAssertFalse(plain.structure.contains { $0.type.rawValue.hasPrefix("HEADING") })
    }

    // MARK: - 2.3 Titoli di sezione isolati da stacchi

    /// Una pagina di corpo (passo 12,6, colonna 58-313, rientro 17) con, se c'è, una riga corta isolata fra due stacchi,
    /// e una nota più piccola in fondo (il documento non è monotipografico: quelli hanno il loro canale).
    private func sectionPage(_ k: Int, titled: Bool = true, gapAbove: Double = 37.8, gapBelow: Double = 25.2,
                             nextIndented: Bool = true, titleEnding: String = "") -> [PdfTextLine] {
        var p: [PdfTextLine] = []
        var y = 560.0
        let w = words[k % words.count]
        for r in 0..<10 {
            p.append(line("Una riga di corpo inventata \(w) \(words[(r + k) % 12]) che va fino al margine destro", size: 11.3,
                          x: r == 0 ? 75 : 58, y: y, width: r == 0 ? 238 : 255, height: 11))
            y -= 12.6
        }
        if titled {
            y = y + 12.6 - gapAbove
            p.append(line("Titolo inventato della sezione \(w)" + titleEnding, size: 11.3, x: 58, y: y, width: 150,
                          height: 11))
            y -= gapBelow
        }
        for r in 0..<6 {
            p.append(line("Il capoverso inventato \(w) che segue \(words[(r + 2 * k) % 12]) e continua fino in fondo",
                          size: 11.3, x: r == 0 && nextIndented ? 75 : 58, y: y, width: r == 0 ? 238 : 255, height: 11))
            y -= 12.6
        }
        p.append(line("\(k + 1) Una nota inventata a piè di pagina sulla parola \(w).", size: 9, x: 58, y: 70, width: 200,
                      height: 9))
        return p
    }

    func test_isolatedSectionTitle_isRecognized_andTheContraryCasesAreNot() {
        func headings(_ make: (Int) -> [PdfTextLine]) -> [String] {
            buildDocumentFromPdf(extraction((0..<6).map(make)), sourceName: "prova.pdf").structure
                .filter { $0.type.rawValue.hasPrefix("HEADING") }.map { $0.text ?? "" }
        }
        XCTAssertEqual(headings { self.sectionPage($0, titled: $0 % 2 == 0) },
                       ["Titolo inventato della sezione alba", "Titolo inventato della sezione cielo",
                        "Titolo inventato della sezione eco"])
        XCTAssertEqual(headings { self.sectionPage($0, nextIndented: false) }, [], "senza il capoverso rientrato dopo")
        XCTAssertEqual(headings { self.sectionPage($0, gapAbove: 12.6) }, [], "senza lo stacco sopra")
        XCTAssertEqual(headings { self.sectionPage($0, gapBelow: 12.6) }, [], "senza lo stacco sotto")
        XCTAssertEqual(headings { self.sectionPage($0, titleEnding: ".") }, [], "finisce col punto: è una frase")
        let doc = buildDocumentFromPdf(extraction((0..<6).map { sectionPage($0) }), sourceName: "prova.pdf")
        let plain = buildDocumentFromPdf(extraction((0..<6).map { sectionPage($0, nextIndented: false) }),
                                         sourceName: "prova.pdf")
        func letters(_ d: ScabopdfDocument) -> String { d.structure.map { $0.text ?? "" }.joined().filter { $0.isLetter } }
        XCTAssertEqual(letters(doc), letters(plain), "nessuna lettera cambia: il titolo era già lì, nel corpo")
    }

    // MARK: - 2.4 Note di chiusura e colonna dei richiami

    private func seg(_ id: String, _ role: String, _ text: String) -> ContentSegment {
        ContentSegment(id: id, role: role, text: text, lengthCategory: role == "NOTE" ? "MICRO" : "",
                       acousticIntro: role == "NOTE" ? "Nota." : "")
    }

    func test_endnotes_areLinkedOnlyByUniqueAttachedCallsInOrder() {
        let segs = [
            seg("h0", "HEADING_1", "Capitolo primo Un titolo inventato"),
            seg("b0", "BODY", "Una frase inventata sulla parola alba1. Poi un'altra con il numero 30 mila uomini."),
            seg("b1", "BODY", "Qui la parola bosco2 e più avanti la parola cielo3; e ancora duna4 nel testo."),
            seg("b2", "BODY", "Una ripetizione di duna4 che rende ambiguo il quarto richiamo."),
            seg("b3", "BODY", "La frase finale del capitolo inventato. Note"),
            seg("n1", "NOTE", "1 Prima nota di chiusura inventata."),
            seg("n2", "NOTE", "2 Seconda nota di chiusura inventata."),
            seg("n3", "NOTE", "3 Terza nota di chiusura inventata."),
            seg("n4", "NOTE", "4 Quarta nota di chiusura inventata."),
        ]
        let links = noteCallLinks(segs)
        XCTAssertEqual(links.callOfNote[5], 1)
        XCTAssertEqual(links.callOfNote[6], 2)
        XCTAssertEqual(links.callOfNote[7], 2)
        XCTAssertNil(links.callOfNote[8], "il richiamo della quarta nota compare due volte: nessun legame")
        XCTAssertEqual(links.notesOfCall[2], [6, 7])
        // Un numero staccato da uno spazio («30 mila») non è un richiamo in apice.
        XCTAssertFalse(containsAttachedCall("con il numero 30 mila uomini", 30))
        XCTAssertFalse(containsAttachedCall("secondo l'art.12 inventato", 12), "mai dopo un'abbreviazione di riferimento")
        // Due note sole non fanno un blocco di chiusura.
        XCTAssertTrue(noteCallLinks(Array(segs[0...6])).callOfNote.isEmpty)
    }

    func test_markerColumnEmittedBeforeTheTexts_isPutBackInPositionOrder() {
        func sm(_ t: String, _ size: Double, x: Double, y: Double) -> LineSummary {
            summarizeLine(line(t, size: size, x: x, y: y, width: t.count > 3 ? 200 : 3, height: size))
        }
        let run: [LineSummary] = [
            sm("1", 5.2, x: 75, y: 215.7), sm("2", 5.2, x: 75, y: 193.7), sm("e chiude la seconda.", 9, x: 58, y: 180.2),
            sm("La prima nota inventata comincia qui", 9, x: 82.5, y: 211.9), sm("e finisce qui.", 9, x: 58, y: 202.2),
            sm("La seconda nota inventata comincia", 9, x: 82.2, y: 189.9),
        ]
        guard case .run(.note, let out) = reorderMarkerColumnNoteRuns([.run(.note, run)])[0] else { return XCTFail() }
        XCTAssertEqual(out.map { $0.text }, ["1", "La prima nota inventata comincia qui", "e finisce qui.", "2",
                                             "La seconda nota inventata comincia", "e chiude la seconda."])
        XCTAssertEqual(splitFootnotes(out, page: 0).map { $0.openingNumber }, [1, 2])
        // Già in ordine, o una sola riga-numero: nessun cambiamento.
        let ordered = [sm("1", 5.2, x: 75, y: 215.7), sm("La prima nota inventata", 9, x: 82, y: 211.9),
                       sm("2", 5.2, x: 75, y: 193.7), sm("La seconda", 9, x: 82, y: 189.9)]
        guard case .run(.note, let same) = reorderMarkerColumnNoteRuns([.run(.note, ordered)])[0] else { return XCTFail() }
        XCTAssertEqual(same.map { $0.text }, ordered.map { $0.text })
    }

    // MARK: - 2.5 Figure ricorrenti: diverse solo se è diverso tutto quello che se ne misura

    func test_recurringFigures_differOnlyIfBothLettersAndDrawingsDiffer() {
        func cand(_ page: Int, _ g: Int?) -> VisualRegionCandidate {
            VisualRegionCandidate(pageIndex: page, label: "picture", bbox: [40, 60, 310, 545], confidence: 0.98,
                                  pageWidth: 371, pageHeight: 598, graphicsInside: g)
        }
        let names = ["un fiume e una citta", "due campi inventati", "una schiera inventata"]
        let maps = [cand(69, 261), cand(125, 258), cand(130, 2928)]
        XCTAssertEqual(recurringCandidateIndices(maps), [0, 1, 2], "senza le lettere: stessa posizione, ricorrono (come prima)")
        XCTAssertEqual(recurringCandidateIndices(maps) { names[$0] }, [], "tre carte diverse in tutto: non sono arredo")
        let watermark = [cand(3, 12), cand(4, 12), cand(5, 12)]
        XCTAssertEqual(recurringCandidateIndices(watermark) { names[$0] }, [0, 1, 2],
                       "lo stesso disegno sopra testi diversi (una filigrana): resta arredo")
        let logo = [cand(3, 12), cand(4, 40), cand(5, 7)]
        XCTAssertEqual(recurringCandidateIndices(logo) { _ in "marchio" }, [0, 1, 2], "le stesse lettere: resta arredo")
        let unmeasured = [cand(3, nil), cand(4, nil), cand(5, nil)]
        XCTAssertEqual(recurringCandidateIndices(unmeasured) { names[$0] }, [0, 1, 2], "senza la misura dei disegni: resta arredo")
        XCTAssertEqual(recurringCandidateIndices(maps) { _ in nil }, [0, 1, 2], "senza la pagina: resta arredo")
    }

    // MARK: - 2.6 Trattino morbido seguito da uno spazio

    func test_softHyphenFollowedBySpace_isRepaired() {
        let shy = "\u{00AD}"
        XCTAssertEqual(repairingSoftHyphenSpaces("una parola inven\(shy) tata qui"), "una parola inven\(shy)tata qui")
        XCTAssertEqual(repairingSoftHyphenSpaces("dalla \(shy) Parola inventata"), "dalla \(shy)Parola inventata")
        XCTAssertEqual(repairingSoftHyphenSpaces("niente da riparare - qui"), "niente da riparare - qui")
        XCTAssertEqual(repairingSoftHyphenSpaces("un trattino morbido\(shy) 12 prima di una cifra"),
                       "un trattino morbido\(shy) 12 prima di una cifra", "solo davanti a una lettera")
        let l = line("una parola inven\(shy) tata", size: 11, x: 0, y: 0, width: 100)
        XCTAssertEqual(summarizeLine(l).text, "una parola inven\(shy)tata")
    }
}
