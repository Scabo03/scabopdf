//
//  TargetedCuresTests.swift
//  ScaboCoreTests
//
//  Le CURE MIRATE (LAYER2 § 0-ter, TargetedCures.swift + TargetedRules.swift, docs/CURE_MIRATE.md): il registro è ben
//  formato, il cancello si apre solo sulle impronte registrate, e la PROVA AL CONTRARIO del meccanismo: un documento
//  sintetico con la stessa forma di difetto ma un'impronta diversa (o nessuna) esce IDENTICO a prima; con l'impronta
//  registrata esce curato, con le stesse lettere e cifre. Tutti i testi sono inventati per la prova: nessuna parola dei
//  documenti curati. Le impronte sono quelle del registro (non sono testo).
//

import XCTest
@testable import ScaboCore

final class TargetedCuresTests: XCTestCase {

    // Le impronte del registro (copiate qui di proposito: se il registro cambia, il test lo dice).
    private let studioA = "d0272b2123af0ae040045ef2942c9d8414c2a779a3457a0f3087f62de8bca815"
    private let studioB = "f0a98bcdcd46a5af734f8879a2d10d36de172200896c4e7e1ab9f885cc83a6a4"
    /// Un'impronta ben formata ma non registrata (lo SHA-256 della stringa «impronta di prova»).
    private var unregistered: String { DocumentFingerprint.sha256Hex(of: Data("impronta di prova".utf8)) }

    // MARK: - Costruzione di pagine sintetiche (origine in basso, come PDFKit)

    private func span(_ text: String, _ size: Double, bold: Bool = false, italic: Bool = false,
                      x: Double, y: Double, width: Double, height: Double) -> PdfSpan {
        PdfSpan(text: text, fontSize: size, bold: bold, italic: italic, color: "#000000",
                bbox: BBox(x: x, y: y, width: width, height: height))
    }

    private func line(_ text: String, size: Double, bold: Bool = false, italic: Bool = false,
                      x: Double, y: Double, width: Double, height: Double = 12) -> PdfTextLine {
        PdfTextLine(spans: [span(text, size, bold: bold, italic: italic, x: x, y: y, width: width, height: height)],
                    bbox: BBox(x: x, y: y, width: width, height: height))
    }

    private func extraction(_ pages: [[PdfTextLine]], width: Double, height: Double, sha: String?) -> PdfExtraction {
        PdfExtraction(version: 2, pageCount: pages.count,
                      pages: pages.enumerated().map { PdfPageExtraction(pageIndex: $0.offset, width: width,
                                                                        height: height, lines: $0.element) },
                      sourceSha256: sha)
    }

    /// La forma del difetto dello studio A: titoli di capitolo e di paragrafo in grassetto alla taglia del corpo, e il
    /// sommario del capitolo in prosa subito dopo il titolo.
    private func shapeA(sha: String?) -> PdfExtraction {
        var p0: [PdfTextLine] = []
        var y = 760.0
        for k in 0..<6 {
            p0.append(line("Riga di corpo inventata numero \(k) che occupa la giustezza della colonna di prova.",
                           size: 12, x: 64, y: y, width: 425)); y -= 20
        }
        var p1: [PdfTextLine] = []
        p1.append(line("CAPITOLO I", size: 12, bold: true, x: 248, y: 736, width: 72))
        p1.append(line("UNA PARTE INVENTATA PER LA PROVA", size: 12, bold: true, x: 150, y: 716, width: 270))
        p1.append(line("1. Primo argomento di prova. 2. Secondo argomento di prova. – 3. Terzo argomento",
                       size: 12, x: 78, y: 676, width: 411))
        p1.append(line("di prova. – 4. Quarto argomento di prova.", size: 12, x: 64, y: 660, width: 240))
        p1.append(line("1. Primo argomento di prova.", size: 12, bold: true, x: 78, y: 620, width: 170))
        y = 580
        for k in 0..<5 {
            p1.append(line("Il corpo inventato del primo argomento prosegue alla riga \(k) senza alcun titolo.",
                           size: 12, x: k == 0 ? 78 : 64, y: y, width: 411)); y -= 20
        }
        p1.append(line("2. Secondo argomento di prova, con un titolo che va", size: 12, bold: true,
                       x: 78, y: y - 20, width: 411))
        p1.append(line("a capo sulla riga successiva.", size: 12, bold: true, x: 64, y: y - 40, width: 180))
        y -= 80
        for k in 0..<4 {
            p1.append(line("Il corpo inventato del secondo argomento prosegue alla riga \(k) fino in fondo.",
                           size: 12, x: k == 0 ? 78 : 64, y: y, width: 411)); y -= 20
        }
        return extraction([p0, p1], width: 595, height: 842, sha: sha)
    }

    /// La forma del difetto dello studio B: etichetta di capitolo fra due ornamenti, sommario etichettato composto a
    /// taglia di nota, titoli di paragrafo più piccoli del corpo, sezione alla taglia del corpo.
    private func shapeB(sha: String?) -> PdfExtraction {
        var p0: [PdfTextLine] = []
        var y = 600.0
        for k in 0..<8 {
            p0.append(line("Riga inventata del corpo di prova numero \(k), lunga quanto la colonna.",
                           size: 11.5, x: 63.8, y: y, width: 355)); y -= 13
        }
        var p1: [PdfTextLine] = []
        p1.append(line("\u{F076} Capitolo I \u{F076}", size: 14, x: 196, y: 520, width: 95, height: 16))
        p1.append(line("TITOLO INVENTATO DEL CAPITOLO", size: 16, x: 130, y: 496, width: 230, height: 18))
        p1.append(line("Sommario", size: 11, bold: true, italic: true, x: 63.8, y: 456, width: 46, height: 13))
        p1.append(line("1. Primo punto di prova. – 2. Secondo punto di prova. – 3. Terzo punto di",
                       size: 9.5, x: 78, y: 434, width: 326, height: 11))
        p1.append(line("prova. – Bibliografia.", size: 9.5, x: 78, y: 423, width: 110, height: 11))
        p1.append(line("1. Primo punto di prova", size: 10.5, x: 63.8, y: 380, width: 150))
        y = 352
        for k in 0..<4 {
            p1.append(line("Il corpo inventato del primo punto prosegue alla riga \(k) per tutta la colonna.",
                           size: 11.5, x: k == 0 ? 78 : 63.8, y: y, width: 355)); y -= 13
        }
        p1.append(line("Sezione I", size: 11.5, x: 63.8, y: y - 26, width: 46, height: 13))
        p1.append(line("UNA SEZIONE INVENTATA", size: 11.5, x: 63.8, y: y - 42, width: 140, height: 13))
        p1.append(line("2. Secondo punto di prova", size: 10.5, x: 63.8, y: y - 80, width: 160))
        y -= 108
        for k in 0..<4 {
            p1.append(line("Il corpo inventato del secondo punto prosegue alla riga \(k) per tutta la colonna.",
                           size: 11.5, x: k == 0 ? 78 : 63.8, y: y, width: 355)); y -= 13
        }
        return extraction([p0, p1], width: 482, height: 680, sha: sha)
    }

    private func json(_ doc: ScabopdfDocument) -> Data {
        let e = JSONEncoder(); e.outputFormatting = [.sortedKeys]
        return try! e.encode(doc)
    }

    private func alnum(_ doc: ScabopdfDocument) -> [Character: Int] {
        var c: [Character: Int] = [:]
        for n in doc.structure { for ch in n.text ?? "" where ch.isLetter || ch.isNumber { c[ch, default: 0] += 1 } }
        return c
    }

    // MARK: - Registro

    func test_registry_isWellFormed() {
        var seen = Set<String>()
        var labels = Set<String>()
        XCTAssertFalse(TargetedCures.registry.isEmpty)
        for entry in TargetedCures.registry {
            XCTAssertTrue(labels.insert(entry.label).inserted, "etichetta ripetuta: \(entry.label)")
            XCTAssertFalse(entry.label.lowercased().hasSuffix(".pdf"), "etichetta neutra, mai il nome del file")
            XCTAssertFalse(entry.fingerprints.isEmpty)
            for f in entry.fingerprints {
                XCTAssertTrue(DocumentFingerprint.isWellFormed(f), "impronta malformata in \(entry.label)")
                XCTAssertTrue(seen.insert(f).inserted, "un'impronta in due voci: \(entry.label)")
            }
            XCTAssertFalse(entry.rules.isEmpty)
            XCTAssertFalse(entry.reason.isEmpty, "ogni voce dichiara il motivo")
            XCTAssertFalse(entry.removalCondition.isEmpty, "ogni voce dichiara quando si toglie")
            XCTAssertGreaterThanOrEqual(entry.cureBuild, 62)
            XCTAssertFalse(entry.whatChanges.hasSuffix("."), "la frase dell'offerta aggiunge il punto da sé")
            XCTAssertTrue(entry.whatChanges.first?.isLowercase ?? false, "la frase segue «una cura dedicata:»")
        }
        // Nessuna regola appartiene a due voci (una regola mirata è di un documento).
        let all = TargetedCures.registry.flatMap { Array($0.rules) }
        XCTAssertEqual(all.count, Set(all).count)
    }

    func test_gate_opensOnlyOnRegisteredFingerprints() {
        XCTAssertEqual(TargetedCures.rules(forFingerprint: nil), [])
        XCTAssertEqual(TargetedCures.rules(forFingerprint: unregistered), [])
        XCTAssertEqual(TargetedCures.rules(forFingerprint: "non è un'impronta"), [])
        XCTAssertEqual(TargetedCures.rules(forFingerprint: studioA.uppercased()), [], "solo la forma minuscola canonica")
        XCTAssertEqual(TargetedCures.entry(forFingerprint: studioA)?.label, "studio-A")
        XCTAssertEqual(TargetedCures.entry(forFingerprint: studioB)?.label, "studio-B")
        XCTAssertEqual(TargetedCures.cureBuildByFingerprint[studioA], 62)
        XCTAssertEqual(TargetedCures.cureBuildByFingerprint[studioB], 62)
        XCTAssertNil(TargetedCures.cureBuildByFingerprint[unregistered])
    }

    func test_profile_carriesRulesOnlyForRegisteredFingerprints() {
        XCTAssertTrue(estimateProfile(shapeA(sha: nil)).targeted.isEmpty)
        XCTAssertTrue(estimateProfile(shapeA(sha: unregistered)).targeted.isEmpty)
        XCTAssertEqual(estimateProfile(shapeA(sha: studioA)).targeted, TargetedCures.rules(forFingerprint: studioA))
        XCTAssertEqual(estimateProfile(shapeA(sha: unregistered)).targetedLeftEdge, 0, "nessun calcolo senza regole")
    }

    // MARK: - Prova al contrario del meccanismo

    func test_counterProof_studioAShape_otherFingerprintIsIdenticalToNone() {
        let none = buildDocumentFromPdf(shapeA(sha: nil), sourceName: "prova.pdf")
        let other = buildDocumentFromPdf(shapeA(sha: unregistered), sourceName: "prova.pdf")
        XCTAssertEqual(json(none), json(other), "impronta diversa: documento identico a prima")
        XCTAssertFalse(none.structure.contains { $0.type.rawValue.hasPrefix("HEADING") },
                       "il difetto c'è: senza la cura i titoli in grassetto restano corpo")
        XCTAssertNotEqual(json(none), json(buildDocumentFromPdf(shapeA(sha: studioA), sourceName: "prova.pdf")),
                          "con l'impronta registrata la cura si accende")
        // E la lettura (aggancio delle note + corpo) resta identica.
        let segA = buildBaseSegments(bindAndPlaceNotes(none, shapeA(sha: nil)).document)
        let segB = buildBaseSegments(bindAndPlaceNotes(other, shapeA(sha: unregistered)).document)
        XCTAssertEqual(segA, segB)
    }

    func test_counterProof_studioBShape_otherFingerprintIsIdenticalToNone() {
        let none = buildDocumentFromPdf(shapeB(sha: nil), sourceName: "prova.pdf")
        let other = buildDocumentFromPdf(shapeB(sha: unregistered), sourceName: "prova.pdf")
        XCTAssertEqual(json(none), json(other), "impronta diversa: documento identico a prima")
        let segA = buildBaseSegments(bindAndPlaceNotes(none, shapeB(sha: nil)).document)
        let segB = buildBaseSegments(bindAndPlaceNotes(other, shapeB(sha: unregistered)).document)
        XCTAssertEqual(segA, segB)
        XCTAssertFalse(none.structure.contains { $0.type == .CHAPTER_SUMMARY }, "il difetto c'è: il sommario è nota")
        XCTAssertTrue(none.structure.contains { $0.type == .NOTE })
    }

    // MARK: - Le cure, con l'impronta registrata

    func test_studioA_titlesSummaryAndLevels() {
        let cured = buildDocumentFromPdf(shapeA(sha: studioA), sourceName: "prova.pdf")
        let plain = buildDocumentFromPdf(shapeA(sha: nil), sourceName: "prova.pdf")
        let headings = cured.structure.filter { $0.type.rawValue.hasPrefix("HEADING") }
        XCTAssertEqual(headings.map { $0.text ?? "" }, [
            "CAPITOLO I UNA PARTE INVENTATA PER LA PROVA",
            "1. Primo argomento di prova.",
            "2. Secondo argomento di prova, con un titolo che va a capo sulla riga successiva.",
        ])
        XCTAssertEqual(headings[0].type, .HEADING_1, "il capitolo è il primo livello (compattazione dei manuali)")
        XCTAssertEqual(headings[1].type, .HEADING_2)
        XCTAssertEqual(headings[2].type, .HEADING_2, "i paragrafi sono fratelli, un livello sotto il capitolo")
        let summaries = cured.structure.filter { $0.type == .CHAPTER_SUMMARY }
        XCTAssertEqual(summaries.count, 1)
        XCTAssertTrue((summaries[0].text ?? "").hasPrefix("1. Primo argomento di prova. 2."))
        XCTAssertEqual(alnum(cured), alnum(plain), "lettere e cifre identiche: la cura non scrive testo")
    }

    func test_studioA_summaryOpeningWithDashTypoIsStillASummary() {
        var ex = shapeA(sha: studioA)
        var spans = ex.pages[1].lines[2].spans
        spans[0].text = "1– Primo argomento di prova. – 2. Secondo argomento di prova. – 3. Terzo argomento"
        ex.pages[1].lines[2].spans = spans
        let cured = buildDocumentFromPdf(ex, sourceName: "prova.pdf")
        XCTAssertEqual(cured.structure.filter { $0.type == .CHAPTER_SUMMARY }.count, 1)
    }

    func test_studioB_unitsSummarySectionAndParagraphTitles() {
        let cured = buildDocumentFromPdf(shapeB(sha: studioB), sourceName: "prova.pdf")
        let plain = buildDocumentFromPdf(shapeB(sha: nil), sourceName: "prova.pdf")
        let headings = cured.structure.filter { $0.type.rawValue.hasPrefix("HEADING") }
        XCTAssertEqual(headings.map { $0.text ?? "" }, [
            "Capitolo I TITOLO INVENTATO DEL CAPITOLO",
            "1. Primo punto di prova",
            "Sezione I UNA SEZIONE INVENTATA",
            "2. Secondo punto di prova",
        ])
        XCTAssertFalse(headings.contains { ($0.text ?? "").unicodeScalars.contains { (0xE000...0xF8FF).contains($0.value) } },
                       "gli ornamenti dell'etichetta non si leggono")
        let level = Dictionary(uniqueKeysWithValues: headings.map { ($0.text ?? "", $0.level ?? 0) })
        XCTAssertEqual(level["1. Primo punto di prova"], (level["Capitolo I TITOLO INVENTATO DEL CAPITOLO"] ?? 0) + 1)
        XCTAssertEqual(level["2. Secondo punto di prova"], (level["Sezione I UNA SEZIONE INVENTATA"] ?? 0) + 1)
        let summaries = cured.structure.filter { $0.type == .CHAPTER_SUMMARY }
        XCTAssertEqual(summaries.count, 1)
        XCTAssertTrue((summaries[0].text ?? "").hasPrefix("Sommario 1. Primo punto di prova."))
        XCTAssertFalse(cured.structure.contains { $0.type == .NOTE }, "il sommario non è più nota")
        XCTAssertEqual(alnum(cured), alnum(plain), "lettere e cifre identiche: la cura non scrive testo")
    }

    func test_studioB_summaryLinesAreReorderedByPosition() {
        var ex = shapeB(sha: studioB)
        // Il lettore di sistema emette l'ultima riga del sommario prima della penultima (come in un caso reale).
        ex.pages[1].lines.swapAt(3, 4)
        let cured = buildDocumentFromPdf(ex, sourceName: "prova.pdf")
        let summary = cured.structure.first { $0.type == .CHAPTER_SUMMARY }?.text ?? ""
        XCTAssertTrue(summary.hasSuffix("3. Terzo punto di prova. – Bibliografia."), summary)
    }

    func test_studioB_summaryContinuingOnNextPageStaysSummary() {
        var nodes = [
            NodeDict(id: "node_0", type: .CHAPTER_SUMMARY, page_index: 3,
                     text: "Sommario 1. Primo punto. – 2. Secondo punto. – 3. Terzo"),
            NodeDict(id: "node_1", type: .NOTE, page_index: 4, text: "punto. – 4. Quarto punto. – 5. Quinto punto.",
                     length_category: .SHORT),
            NodeDict(id: "node_2", type: .NOTE, page_index: 4, text: "7 Una nota vera inventata per la prova.",
                     length_category: .SHORT),
        ]
        let p = Profile(bodySize: 11.5, bodyColor: "#000000", targeted: [.labelledChapterSummary])
        XCTAssertEqual(applyTargetedDocumentRules(&nodes, p), 1)
        XCTAssertEqual(nodes[1].type, .CHAPTER_SUMMARY)
        XCTAssertNil(nodes[1].length_category)
        XCTAssertEqual(nodes[2].type, .NOTE, "una nota vera dopo il sommario resta nota")
    }

    func test_stripPrivateUseOrnaments_keepsLettersAndDigits() {
        XCTAssertEqual(targetedStrippingPrivateUseOrnaments("\u{F076} Capitolo IV \u{F076}"), "Capitolo IV")
        XCTAssertEqual(targetedStrippingPrivateUseOrnaments("Capitolo 12"), "Capitolo 12")
    }
}
