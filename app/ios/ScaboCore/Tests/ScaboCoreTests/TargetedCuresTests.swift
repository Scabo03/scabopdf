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
        // Ogni regola del catalogo è usata da almeno una voce (una regola rimasta senza voce si toglie, CURE_MIRATE § 6).
        // Dal giro «rifiniture» (build 63) una regola descritta per FORMA può servire a più voci: i due documenti di
        // studio hanno lo stesso difetto del lettore di sistema sull'interpunzione dopo i richiami.
        let used = Set(TargetedCures.registry.flatMap { Array($0.rules) })
        XCTAssertEqual(used, Set(TargetedRule.allCases), "regole senza voce: \(Set(TargetedRule.allCases).subtracting(used))")
    }

    func test_gate_opensOnlyOnRegisteredFingerprints() {
        XCTAssertEqual(TargetedCures.rules(forFingerprint: nil), [])
        XCTAssertEqual(TargetedCures.rules(forFingerprint: unregistered), [])
        XCTAssertEqual(TargetedCures.rules(forFingerprint: "non è un'impronta"), [])
        XCTAssertEqual(TargetedCures.rules(forFingerprint: studioA.uppercased()), [], "solo la forma minuscola canonica")
        XCTAssertEqual(TargetedCures.entry(forFingerprint: studioA)?.label, "studio-A")
        XCTAssertEqual(TargetedCures.entry(forFingerprint: studioB)?.label, "studio-B")
        XCTAssertEqual(TargetedCures.cureBuildByFingerprint[studioA], 63, "rifiniture del giro: di nuovo l'offerta")
        XCTAssertEqual(TargetedCures.cureBuildByFingerprint[studioB], 63, "rifiniture del giro: di nuovo l'offerta")
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

    // MARK: - Rifiniture del giro «rifiniture e cure per capacità» (build 63)

    /// Una riga che finisce con un richiamo in apice (il numero composto più piccolo, attaccato alla parola).
    private func callLine(_ text: String, call: String, x: Double, y: Double, width: Double) -> PdfTextLine {
        PdfTextLine(spans: [span(text, 12, x: x, y: y, width: width, height: 13),
                            span(call, 8, x: x + width, y: y, width: 8, height: 13)],
                    bbox: BBox(x: x, y: y, width: width + 8, height: 14))
    }

    /// Dodici pagine: su ognuna una frase che finisce col richiamo in apice e il punto che il lettore di sistema emette
    /// come riga a sé, attaccata all'apice sulla stessa linea di base; in fondo la nota. Il punto ricorre su ogni pagina:
    /// senza la cura il canale della mobilia per maggioranza lo toglie.
    private func shapeDetachedPunctuation(sha: String?) -> PdfExtraction {
        // Parole diverse su ogni pagina (le cifre non bastano: la mobilia le normalizza), così solo il punto ricorre.
        let words = ["alba", "bosco", "cielo", "duna", "eco", "faro", "golfo", "isola", "lago", "monte", "nube", "onda"]
        var pages: [[PdfTextLine]] = []
        for k in 0..<12 {
            let w = words[k]
            var p: [PdfTextLine] = []
            p.append(line("Una frase inventata sulla parola \(w) che corre lungo la riga di prova \(w)", size: 12,
                          x: 64, y: 720, width: 425))
            p.append(callLine("e finisce col richiamo \(w)", call: "\(k + 1)", x: 64, y: 700, width: 150))
            p.append(line(".", size: 12, x: 222, y: 700, width: 3, height: 13))
            p.append(line("Un'altra frase inventata sulla parola \(w) comincia con la maiuscola e prosegue", size: 12,
                          x: 78, y: 680, width: 411))
            p.append(line("fino al margine della colonna di prova, \(w).", size: 12, x: 64, y: 660, width: 250))
            p.append(PdfTextLine(spans: [span("\(k + 1)", 6.6, x: 64, y: 90, width: 6, height: 8),
                                         span(" Nota inventata sulla parola \(w).", 10, x: 70, y: 90, width: 160, height: 11)],
                                 bbox: BBox(x: 64, y: 90, width: 166, height: 11)))
            pages.append(p)
        }
        return extraction(pages, width: 595, height: 842, sha: sha)
    }

    private func allText(_ doc: ScabopdfDocument) -> String { doc.structure.map { $0.text ?? "" }.joined(separator: "|") }

    func test_detachedCallPunctuation_isTextNotFurniture_andReattaches() {
        let plain = buildDocumentFromPdf(shapeDetachedPunctuation(sha: nil), sourceName: "prova.pdf")
        let other = buildDocumentFromPdf(shapeDetachedPunctuation(sha: unregistered), sourceName: "prova.pdf")
        let cured = buildDocumentFromPdf(shapeDetachedPunctuation(sha: studioA), sourceName: "prova.pdf")
        XCTAssertEqual(json(plain), json(other), "prova al contrario: impronta non registrata, documento identico")
        XCTAssertTrue(allText(plain).contains("richiamo alba1"), "il corpo c'è anche senza la cura")
        XCTAssertFalse(allText(plain).contains("richiamo alba1."), "il difetto c'è: senza la cura il punto si perde")
        // Il punto torna attaccato al richiamo; la riga rientrata dopo la frase chiusa apre un capoverso (regola dei capoversi).
        XCTAssertTrue(allText(cured).contains("e finisce col richiamo alba1.|Un'altra frase"), allText(cured))
        XCTAssertEqual(alnum(cured), alnum(plain), "lettere e cifre identiche")
        // Il punto staccato è riconosciuto come tale solo sulla stessa linea di base e attaccato all'apice.
        let lines = shapeDetachedPunctuation(sha: nil).pages[0].lines
        XCTAssertTrue(targetedIsDetachedCallPunctuation(2, in: lines))
        var moved = lines
        moved[2].bbox.y = 640
        XCTAssertFalse(targetedIsDetachedCallPunctuation(2, in: moved), "un punto su un'altra riga non è staccato")
        XCTAssertFalse(targetedIsDetachedCallPunctuation(0, in: lines))
        // La riga staccata può portare, dopo il punto, il resto della stessa riga fisica: si riattacca anche lei.
        let call = summarizeLine(callLine("una frase che finisce col richiamo", call: "7", x: 64, y: 425, width: 300))
        let rest = summarizeLine(line(". Ne segue un'altra frase inventata.", size: 12, x: 372, y: 425, width: 117))
        let p = Profile(bodySize: 12, bodyColor: "#000000", targeted: [.detachedCallPunctuation])
        let out = applyTargetedLineRules([call, rest], p)
        XCTAssertEqual(out.count, 1)
        XCTAssertEqual(out.first?.text, "una frase che finisce col richiamo7. Ne segue un'altra frase inventata.")
        let far = summarizeLine(line(". Ne segue un'altra frase inventata.", size: 12, x: 400, y: 425, width: 117))
        XCTAssertEqual(applyTargetedLineRules([call, far], p).count, 2, "non contigua: resta com'è")
    }

    func test_bodyLineEndingWithCall_takesTheSizeOfItsText() {
        // «1945» alla taglia del corpo + «731.» in apice: la media scendeva sotto la soglia delle note.
        let l = PdfTextLine(spans: [span("1945", 12, x: 64, y: 400, width: 24, height: 13),
                                    span("731.", 8, x: 88, y: 400, width: 14, height: 13)],
                            bbox: BBox(x: 64, y: 400, width: 38, height: 14))
        let sm = summarizeLine(l)
        XCTAssertLessThan(sm.fontSize, 12 * 0.85, "il difetto: la riga sembra una nota")
        let p = Profile(bodySize: 12, bodyColor: "#000000", targeted: [.detachedCallPunctuation])
        XCTAssertEqual(applyTargetedLineRules([sm], p)[0].fontSize, 12, accuracy: 0.001)
        XCTAssertEqual(applyTargetedLineRules([sm], p)[0].text, sm.text, "testo invariato")
    }

    func test_fullSizeNumberContinuesNote() {
        let opening = summarizeLine(PdfTextLine(
            spans: [span("79", 6.6, x: 64, y: 140, width: 8, height: 8),
                    span(" Un autore inventato, Un titolo di prova, Torino, 2007, pp.", 10, x: 72, y: 140, width: 300, height: 11)],
            bbox: BBox(x: 64, y: 140, width: 308, height: 11)))
        let pageNumber = summarizeLine(line("11.", size: 10, x: 64, y: 128, width: 12, height: 11))
        let next = summarizeLine(PdfTextLine(
            spans: [span("80", 6.6, x: 64, y: 116, width: 8, height: 8),
                    span(" Una seconda nota inventata.", 10, x: 72, y: 116, width: 150, height: 11)],
            bbox: BBox(x: 64, y: 116, width: 158, height: 11)))
        let p = Profile(bodySize: 12, bodyColor: "#000000", targeted: [.fullSizeNumberContinuesNote])
        let out = applyTargetedPageRules([.run(.note, [opening, pageNumber, next])], p)
        guard case .run(.note, let lines) = out[0] else { return XCTFail("resta un blocco di note") }
        XCTAssertEqual(lines.count, 2, "il numero di pagina andato a capo continua la nota, la nota vera si apre")
        XCTAssertTrue(lines[0].text.hasSuffix("pp. 11."), lines[0].text)
        XCTAssertEqual(splitFootnotes(lines, page: 0).count, 2)
        XCTAssertEqual(splitFootnotes([opening, pageNumber, next], page: 0).count, 3, "il difetto: una nota finta «11.»")
    }

    func test_citationAbbreviationsAndSplitDates_onlyInsideTheTargetedScope() {
        let text = "Vale il D. lgs. 123/2099 per la prova. Cfr. la pronuncia inventata del 7.3. 2041, n. 4321. Fine."
        let plain = splitIntoSentences(text)
        XCTAssertEqual(plain.count, 5, "il difetto: la citazione e la data si spezzano")
        let cured = TargetedSentenceRules.with([.citationAbbreviations]) { splitIntoSentences(text) }
        XCTAssertEqual(cured, ["Vale il D. lgs. 123/2099 per la prova.",
                               "Cfr. la pronuncia inventata del 7.3. 2041, n. 4321.", "Fine."])
        XCTAssertEqual(splitIntoSentences(text), plain, "fuori dall'ambito le regole tornano quelle di sempre")
        XCTAssertEqual(TargetedSentenceRules.with([.boldBodySizeTitles]) { splitIntoSentences(text) }, plain,
                       "le regole di frase si accendono solo con la loro regola")
        XCTAssertEqual(TargetedSentenceRules.with([.citationAbbreviations]) { splitIntoSentences("Il 18.2. Poi altro.") },
                       ["Il 18.2.", "Poi altro."], "senza l'anno dopo, la data non trattiene la frase")
        let allegato = "Il testo inventato dell'all. B riguarda la prova."
        XCTAssertEqual(splitIntoSentences(allegato).count, 2, "il difetto: «all.» chiudeva la frase")
        XCTAssertEqual(TargetedSentenceRules.with([.citationAbbreviations]) { splitIntoSentences(allegato) }, [allegato],
                       "«all.» (allegato) non chiude la frase")
    }

    func test_framedAsideBox_andNotesAroundIt() {
        let body = 11.5, left = 63.8, right = 418.0
        var lines: [LineSummary] = []
        lines.append(summarizeLine(line("Una prima riga inventata del riquadro, rientrata e giustificata come le altre.", size: 9,
                                        x: left + 10.3, y: 400, width: 333.5, height: 10)))
        lines.append(summarizeLine(line("Una seconda riga inventata del riquadro, rientrata e giustificata come la prima.", size: 9,
                                        x: left + 10.3, y: 389, width: 333.5, height: 10)))
        lines.append(summarizeLine(line("Ultima riga corta.", size: 9, x: left + 10.3, y: 378, width: 90, height: 10)))
        let note = summarizeLine(PdfTextLine(
            spans: [span("3", 5.5, x: 78, y: 120, width: 4, height: 7),
                    span(" Una nota inventata col suo numero.", 9, x: 82, y: 120, width: 180, height: 10)],
            bbox: BBox(x: 78, y: 120, width: 184, height: 10)))
        let p = Profile(bodySize: body, bodyColor: "#000000", targeted: [.framedAsideBoxes],
                        targetedLeftEdge: left, targetedRightEdge: right)
        let out = applyTargetedPageRules([.run(.note, lines + [note])], p)
        XCTAssertEqual(out.count, 2)
        guard case .apparatus(.EXAMPLE_BOX, let box) = out[0], case .run(.note, let rest) = out[1] else {
            return XCTFail("riquadro e poi la nota: \(out)")
        }
        XCTAssertEqual(box.count, 3)
        XCTAssertEqual(rest.count, 1)
        // Le note vere (numero in testa, a capo al bordo della colonna) non sono riquadri.
        let footnote = [summarizeLine(line("12 Una nota inventata che va a capo al bordo della colonna di prova.", size: 9,
                                           x: 78, y: 200, width: 340, height: 10)),
                        summarizeLine(line("e continua qui a filo della colonna fino al margine destro.", size: 9,
                                           x: left, y: 189, width: 354, height: 10))]
        XCTAssertEqual(applyTargetedPageRules([.run(.note, footnote)], p).count, 1)
        if case .apparatus = applyTargetedPageRules([.run(.note, footnote)], p)[0] { XCTFail("una nota non è un riquadro") }
        // Senza la regola nulla cambia.
        let none = Profile(bodySize: body, bodyColor: "#000000", targeted: [.sectionLabels], targetedLeftEdge: left)
        XCTAssertEqual(applyTargetedPageRules([.run(.note, lines + [note])], none).count, 1)
    }

    func test_framedAsideBoxes_joinAcrossPagesAndFractionLikeLongNotes() {
        let first = ContentSegment(id: "node_5", role: "EXAMPLE_BOX",
                                   text: String(repeating: "Una frase inventata del riquadro di prova. ", count: 12) + "Una parola spez-",
                                   lengthCategory: "", acousticIntro: "Riquadro.", sourcePage: 46)
        let second = ContentSegment(id: "node_9", role: "EXAMPLE_BOX",
                                    text: "zata riprende sulla pagina dopo. " + String(repeating: "Altra frase inventata. ", count: 60),
                                    lengthCategory: "", acousticIntro: "Riquadro.", sourcePage: 47)
        let out = applyTargetedSegmentRules([first, second], [.framedAsideBoxes], target: 400)
        XCTAssertGreaterThan(out.count, 1, "un riquadro lungo si divide in pezzi")
        XCTAssertEqual(out.filter { !$0.acousticIntro.isEmpty }.count, 1, "un annuncio solo per riquadro")
        XCTAssertEqual(out[0].acousticIntro, "Riquadro.")
        XCTAssertTrue(out.allSatisfy { $0.role == "EXAMPLE_BOX" })
        XCTAssertTrue(out.map { $0.text }.joined(separator: " ").contains("spezzata riprende"), "parola ricomposta")
        XCTAssertEqual(out.first?.sourcePage, 46)
        XCTAssertEqual(out.last?.sourcePage, 47, "il pezzo che comincia sulla pagina dopo porta quella pagina")
        XCTAssertEqual(out.compactMap { $0.sourcePage }, out.compactMap { $0.sourcePage }.sorted(), "pagine monotone")
        XCTAssertEqual(applyTargetedSegmentRules([first, second], [], target: 400), [first, second], "senza regola invariato")
        XCTAssertEqual(acousticIntroFor("EXAMPLE_BOX", ""), "Riquadro.")
    }

    func test_bibliographyLabel_headingAndBlock_thenLevelAndContinuation() {
        let body = 11.5, left = 63.8
        let lastBody = summarizeLine(line("re inventate di prova.", size: 11.5, x: left, y: 561, width: 57, height: 11.5))
        let label = summarizeLine(line("Bibliografia", size: 10.5, x: left, y: 523, width: 54, height: 12))
        let e1 = summarizeLine(line("AUTORE, Un titolo inventato, in Rivista di prova, 2016, pp. 1-18; ALTRO,", size: 10.5,
                                    x: left, y: 498, width: 354, height: 10.5))
        let e2 = summarizeLine(line("Un secondo titolo inventato, Milano, 2010.", size: 10.5, x: 78, y: 486, width: 240, height: 10.5))
        let p = Profile(bodySize: body, bodyColor: "#000000", targeted: [.bibliographyLabels], targetedLeftEdge: left)
        let out = applyTargetedPageRules([.run(.body, [lastBody, label, e1, e2])], p)
        XCTAssertEqual(out.count, 3)
        guard case .run(.body, let b) = out[0], case .heading(let h, _) = out[1], case .apparatus(.LETTERATURA, let entries) = out[2]
        else { return XCTFail("\(out)") }
        XCTAssertEqual(b.count, 1); XCTAssertEqual(h.text, "Bibliografia"); XCTAssertEqual(entries.count, 2)
        // Livello: un livello sotto il capitolo anche dentro le sezioni; continuazione sulla pagina dopo.
        var nodes = [
            NodeDict(id: "node_0", type: .HEADING_2, page_index: 1, text: "Capitolo I TITOLO INVENTATO", level: 2),
            NodeDict(id: "node_1", type: .HEADING_3, page_index: 2, text: "Sezione I UNA SEZIONE", level: 3),
            NodeDict(id: "node_2", type: .HEADING_4, page_index: 3, text: "Bibliografia", level: 4),
            NodeDict(id: "node_3", type: .LETTERATURA, page_index: 3, text: "AUTORE, Opera inventata, Torino, 2014;"),
            NodeDict(id: "node_4", type: .NOTE, page_index: 3, text: "4 Una nota inventata.", length_category: .MICRO),
            NodeDict(id: "node_5", type: .BODY, page_index: 4, text: "Un'opera inventata che continua, Roma, 2012."),
            NodeDict(id: "node_6", type: .HEADING_2, page_index: 5, text: "Capitolo II ALTRO TITOLO", level: 2),
        ]
        XCTAssertEqual(applyTargetedDocumentRules(&nodes, p), 2)
        XCTAssertEqual(nodes[2].type, .HEADING_3, "la bibliografia è del capitolo, non della sezione")
        XCTAssertEqual(nodes[5].type, .LETTERATURA, "il blocco continua in cima alla pagina dopo")
        XCTAssertEqual(nodes[4].type, .NOTE)
    }

    func test_indentedParagraphs_splitRunsAndGranularityRespectsThem() {
        let body = 12.0, left = 64.0, right = 489.0
        func bl(_ t: String, _ x: Double, _ y: Double, _ w: Double) -> LineSummary {
            summarizeLine(line(t, size: body, x: x, y: y, width: w))
        }
        let run: [LineSummary] = [
            bl("Un capoverso inventato comincia rientrato e va avanti lungo la riga di prova", 78, 700, 411),
            bl("fino a chiudere la sua frase.", left, 680, 160),
            bl("Un secondo capoverso inventato comincia rientrato e va avanti lungo la riga", 78, 660, 411),
            bl("e la frase continua a filo della colonna fino al margine destro di questa prova", left, 640, 425),
            bl("senza chiudersi, quindi la riga dopo rientrata non apre nulla", left, 620, 360),
        ]
        let p = Profile(bodySize: body, bodyColor: "#000000", targeted: [.indentedParagraphs], targetedLeftEdge: left,
                        targetedRightEdge: right, targetedParagraphIndent: 14)
        let out = applyTargetedPageRules([.run(.body, run)], p)
        XCTAssertEqual(out.count, 2, "due capoversi")
        // La famiglia porta il segno alla granularità: i corpi consecutivi della stessa pagina aprono un capoverso.
        let doc = ScabopdfDocument(
            schema_version: SUPPORTED_SCHEMA_VERSION, document_id: "prova",
            metadata: DocumentMetadata(pages_pdf: 1, page_size_pt: [0, 0], source_pdf_filename: "prova.pdf"),
            profile: DocumentProfileDict(profile_id: "generic", editorial_family: TARGETED_PARAGRAPHS_FAMILY,
                                         genre: "unknown", confidence: 0.05),
            structure: [NodeDict(id: "node_0", type: .BODY, page_index: 0, text: "Primo capoverso inventato."),
                        NodeDict(id: "node_1", type: .BODY, page_index: 0, text: "Secondo capoverso inventato.")])
        let segs = buildBaseSegments(doc)
        XCTAssertEqual(segs.map { $0.opensParagraph }, [false, true])
        XCTAssertEqual(granularizeBody(segs).count, 2, "il blocco non scavalca l'a capo")
        var generic = doc
        generic.profile.editorial_family = "generic"
        XCTAssertEqual(granularizeBody(buildBaseSegments(generic)).count, 1, "senza la famiglia, come sempre")
    }

    func test_noteJump_targetedInlineWindow_onlyWithTheOption() {
        let longSentence = "Una frase inventata col richiamo173; " + String(repeating: "poi un elenco di prova che continua; ", count: 14)
            + "e finisce qui."
        let segs = [
            ContentSegment(id: "b0", role: "BODY", text: longSentence, lengthCategory: "", acousticIntro: ""),
            ContentSegment(id: "n0", role: "NOTE", text: "173 Una nota inventata.", lengthCategory: "MICRO", acousticIntro: "Nota."),
            ContentSegment(id: "b1", role: "BODY", text: "Vale l’articolo inventato 9999 c.c.6.", lengthCategory: "", acousticIntro: ""),
            ContentSegment(id: "n1", role: "NOTE", text: "6 Altra nota inventata.", lengthCategory: "MICRO", acousticIntro: "Nota."),
            ContentSegment(id: "b2", role: "BODY", text: "Un d.lgs. 5 marzo 2099 inventato.", lengthCategory: "", acousticIntro: ""),
            ContentSegment(id: "n2", role: "NOTE", text: "5 Nota inventata senza richiamo qui.", lengthCategory: "MICRO", acousticIntro: "Nota."),
        ]
        let plain = noteCallLinks(segs)
        XCTAssertNil(plain.callOfNote[1], "il difetto: richiamo oltre la coda di 400 caratteri")
        XCTAssertNil(plain.callOfNote[3], "il difetto: richiamo attaccato alla sigla col punto")
        let cured = noteCallLinks(segs, options: NoteJumpOptions(targetedInline: true))
        XCTAssertEqual(cured.callOfNote[1], 0)
        XCTAssertEqual(cured.callOfNote[3], 2)
        XCTAssertNil(cured.callOfNote[5], "dopo la sigla di un atto il numero è il giorno, non un richiamo")
        XCTAssertEqual(NoteJumpOptions.forTargeted(TargetedCures.rules(forFingerprint: unregistered)), NoteJumpOptions())
        XCTAssertEqual(NoteJumpOptions.forTargeted(TargetedCures.rules(forFingerprint: studioA)).targetedInline, true)
        XCTAssertEqual(NoteJumpOptions.forTargeted([.detachedCallPunctuation]), NoteJumpOptions(),
                       "il salto ampliato ha la sua regola: non dipende da un'altra")
    }
}
