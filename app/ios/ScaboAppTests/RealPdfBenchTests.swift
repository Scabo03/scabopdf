//
//  RealPdfBenchTests.swift
//  ScaboAppTests
//
//  BANCO CON PDF VERO (sentiero INDICE, primo blocco app — base del banco iPad).
//
//  Obiettivo: caricare un PDF VERO attraverso la PIPELINE REALE di elaborazione
//  on-device dell'app — `PdfKitExtractor.extract` → `buildDocumentFromPdf`
//  (classificazione + rimozione furniture) → `ContinuousBodyBuilder` (granularità
//  §7.6 + paginazione) — ed esaminare la STRUTTURA esposta alla reading view. Non
//  testa la resa vocale di VoiceOver (la certifica il maintainer su dispositivo):
//  testa che la struttura del documento corrisponda al PDF.
//
//  ── Perché questa via, e cosa copre/non copre ───────────────────────────────────
//
//  L'import reale dell'app passa per la finestra di sistema (UIDocumentPicker), che
//  è UI fuori-processo (l'app Files) e NON è automatizzabile in modo affidabile sul
//  Simulator: serve un Mac fisico con UI-automation attiva (axremoted), come
//  annotato in `scripts/seed_fixtures.sh`. Questo banco prende la VIA SOTTO IL
//  PICKER: inietta l'URL del file direttamente nella pipeline che il picker
//  alimenta a valle (`HomeViewController` con `asCopy:true` copia il file e passa
//  l'URL a `ProcessingViewController` → `DocumentProcessor(extractor:
//  PdfKitExtractor())`). Copre: estrazione PDFKit reale, classificazione Generic,
//  rimozione furniture, layout continuo, granularità, paginazione — l'intera
//  pipeline di ELABORAZIONE. NON copre: il tocco sulla finestra di sistema, la
//  copia `asCopy` e la gestione della security-scoped resource del delegate (glue
//  UI/OS sottile), che restano da automatizzare via XCUITest su Mac vero.
//
//  ── File copyright FUORI dal repo ───────────────────────────────────────────────
//
//  I PDF veri (Marotta, Torrente, …) sono materiali protetti e NON entrano mai in
//  git (`.gitignore` esclude `*.pdf` globalmente). Il banco li legge da una cartella
//  LOCALE FUORI dal repo, configurabile via env `SCABO_CORPUS_DIR` (default: il
//  workspace dev-time `scabopdf-triple-take/originals`). Su un checkout pulito senza
//  corpus il test fa `XCTSkip` (verde), come la convenzione fixture della pipeline.
//  Sul Simulator il processo di test gira sull'host e legge il path host
//  direttamente; nessun PDF è mai copiato dentro il repo.
//

import XCTest
@testable import ScaboApp
import ScaboCore

final class RealPdfBenchTests: XCTestCase {

    /// Cartella-corpus locale (fuori repo). Override via env `SCABO_CORPUS_DIR`.
    private var corpusDir: String {
        ProcessInfo.processInfo.environment["SCABO_CORPUS_DIR"]
            ?? "/Users/lucascabini/Developer/scabopdf-triple-take/originals"
    }

    /// Esegue la pipeline REALE su un PDF del corpus e ritorna documento + corpo
    /// paginato. `XCTSkip` se il file non c'è (checkout senza corpus).
    private func runRealPipeline(_ fileName: String) throws
        -> (document: ScabopdfDocument, content: PaginatedContent)
    {
        let path = corpusDir + "/" + fileName
        guard FileManager.default.fileExists(atPath: path) else {
            throw XCTSkip("""
                PDF di prova assente: \(path). Il banco con PDF vero richiede il \
                corpus locale fuori repo (imposta SCABO_CORPUS_DIR). Convenzione \
                fixture: skip su checkout pulito.
                """)
        }
        let url = URL(fileURLWithPath: path)
        let extractor = PdfKitExtractor()
        let extraction = try extractor.extract(fromUri: url.absoluteString)
        let document = buildDocumentFromPdf(extraction, sourceName: fileName)
        let content = try ContinuousBodyBuilder.bodyPaginatedContent(
            from: document, granularity: .fine)
        return (document, content)
    }

    /// Conta i nodi per categoria nel documento prodotto dalla pipeline reale.
    private func counts(_ doc: ScabopdfDocument) -> [SemanticCategory: Int] {
        var c: [SemanticCategory: Int] = [:]
        for node in doc.structure { c[node.type, default: 0] += 1 }
        return c
    }

    // MARK: - Marotta (folio fuori-banda + indice due-colonne) — il minimo richiesto

    func test_marotta_realPipeline_loadsAndExposesStructure() throws {
        let (doc, content) = try runRealPipeline("Marotta.pdf")
        let cat = counts(doc)
        let bodySegments = content.pages.flatMap { $0.segments }.count
        let furnitureWarning = doc.warnings.first { $0.hasPrefix("plugin:generic:furniture_lines_removed_") } ?? "—"

        // Reperto a terminale: i numeri reali che la pipeline produce su Marotta.
        print("""
            [BANCO Marotta — pipeline reale su simulatore iPad]
              pagine PDF: \(doc.metadata.pages_pdf)
              nodi totali: \(doc.structure.count)  per categoria: \
            \(cat.map { "\($0.key.rawValue)=\($0.value)" }.sorted().joined(separator: " "))
              segmenti di corpo (reading view, granularità fine 400): \(bodySegments)
              furniture: \(furnitureWarning)
            """)

        // Base del banco: la pipeline reale carica il PDF e produce una struttura
        // non banale. Le verifiche specifiche di folio/indice arrivano coi mattoni
        // A e B; qui si pinna che il banco SAPPIA caricare un PDF vero e leggere la
        // reading view risultante.
        XCTAssertEqual(doc.metadata.pages_pdf, 206, "Marotta ha 206 pagine")
        XCTAssertGreaterThan(doc.structure.count, 0, "la classificazione produce nodi")
        XCTAssertGreaterThan(bodySegments, 0, "la reading view espone segmenti di corpo")
    }

    // MARK: - Secondo volume denso (indice analitico) — se presente nel corpus

    func test_torrente_realPipeline_loadsIfPresent() throws {
        let (doc, content) = try runRealPipeline("Torrente.pdf")
        let bodySegments = content.pages.flatMap { $0.segments }.count
        print("""
            [BANCO Torrente — pipeline reale su simulatore iPad]
              pagine PDF: \(doc.metadata.pages_pdf)  nodi: \(doc.structure.count)  \
            segmenti di corpo: \(bodySegments)
            """)
        XCTAssertGreaterThan(doc.metadata.pages_pdf, 0)
        XCTAssertGreaterThan(bodySegments, 0)
    }

    // MARK: - Comando di verifica-fedeltà: dump JSON dell'output (lato Swift)

    /// Richiesta di dump scritta dal driver `scripts/fidelity.sh` a un path host FISSO
    /// (il processo-test sul Simulator NON eredita l'env della shell, ma legge il
    /// filesystem host: il file-richiesta è il canale robusto). Tutti i path sono
    /// FUORI dal repo.
    private struct DumpRequest: Codable {
        let corpusDir: String
        let outDir: String
        let pdfs: [String]
    }

    /// Path fisso della richiesta (concordato col driver). Override via env se mai
    /// servisse, ma il default è il contratto.
    private static let requestPath =
        ProcessInfo.processInfo.environment["SCABO_BENCH_REQUEST"] ?? "/tmp/scabo_bench_request.json"

    // MARK: - Dump diagnostico delle righe reali (Mattone A)

    private struct LineDumpLine: Codable {
        let i: Int; let text: String; let yTop: Double; let color: String
        let x0: Double; let x1: Double  // bordi orizzontali (page-local): per il riconoscitore due-colonne (Mattone B)
    }
    private struct LineDumpPage: Codable {
        let pageIndex: Int; let height: Double; let width: Double; let lines: [LineDumpLine]
    }
    private struct LineDump: Codable { let pageCount: Int; let pages: [LineDumpPage] }

    /// Riduce l'estrazione reale al vettore-segnale che `detectFurniture` e il
    /// riconoscitore due-colonne consumano, pagina per pagina: per ogni riga il
    /// `summarizeLine` (testo, yTop, colore, x0/x1) + altezza e larghezza pagina.
    /// Solo ciò che serve a replicare furniture (Mattone A) e gutter/colonne
    /// (Mattone B) fuori-processo.
    private func lineDump(_ extraction: PdfExtraction) -> LineDump {
        var pages: [LineDumpPage] = []
        pages.reserveCapacity(extraction.pages.count)
        for page in extraction.pages {
            var dumped: [LineDumpLine] = []
            dumped.reserveCapacity(page.lines.count)
            for (i, line) in page.lines.enumerated() {
                let sm = summarizeLine(line)
                dumped.append(LineDumpLine(
                    i: i, text: sm.text, yTop: sm.yTop, color: sm.color, x0: sm.x0, x1: sm.x1))
            }
            pages.append(LineDumpPage(
                pageIndex: page.pageIndex, height: page.height, width: page.width, lines: dumped))
        }
        return LineDump(pageCount: extraction.pageCount, pages: pages)
    }

    /// Pezzo Swift del comando di verifica-fedeltà: per ogni PDF della richiesta,
    /// esegue la pipeline REALE e scrive il `ScabopdfDocument` come JSON (Codable →
    /// testo + struttura) in `outDir` (fuori repo). `XCTSkip` se non c'è richiesta
    /// (così le run di test normali non fanno nulla). L'analisi (PyMuPDF/docling) e
    /// il referto sono il pezzo Python, invocato dal driver dopo questo dump.
    func test_fidelityDump_fromRequest() throws {
        guard let data = FileManager.default.contents(atPath: Self.requestPath),
              let req = try? JSONDecoder().decode(DumpRequest.self, from: data) else {
            throw XCTSkip("nessuna richiesta di dump in \(Self.requestPath): comando fidelity non invocato.")
        }
        try? FileManager.default.createDirectory(
            atPath: req.outDir, withIntermediateDirectories: true)
        let extractor = PdfKitExtractor()
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        for name in req.pdfs {
            let path = req.corpusDir + "/" + name
            guard FileManager.default.fileExists(atPath: path) else {
                print("[fidelity-dump] assente, salto: \(path)"); continue
            }
            let extraction = try extractor.extract(fromUri: URL(fileURLWithPath: path).absoluteString)
            let doc = buildDocumentFromPdf(extraction, sourceName: name)
            let stem = (name as NSString).deletingPathExtension
            try enc.encode(doc).write(to: URL(fileURLWithPath: req.outDir + "/\(stem).scabopdf.json"))
            // DIAGNOSTICA Mattone A (additiva, solo banco): dump delle righe REALI
            // come le vede `detectFurniture` — il vettore-segnale `summarizeLine`
            // (testo trimmato, yTop in convenzione PDFKit origin-basso, colore
            // dominante) + altezza pagina. Permette di replicare i tre canali della
            // furniture su estrazione PDFKit VERA e decomporre il "perso numerico"
            // in folio vs contenuto-numero, fuori dal processo del Simulator.
            let lines = try enc.encode(lineDump(extraction))
            try lines.write(to: URL(fileURLWithPath: req.outDir + "/\(stem).lines.json"))
            print("[fidelity-dump] \(name): \(doc.structure.count) nodi, \(doc.metadata.pages_pdf) pagine → \(stem).scabopdf.json (+ .lines.json)")
        }
    }

    // MARK: - Aggancio note sulla pipeline reale: precisione + non-distruttività

    /// Su Marotta (regime SMALLER): l'aggancio produce legami same-page, le note
    /// restano LETTE (presenti) e il piazzamento non perde né duplica testo.
    func test_marotta_noteBinding_boundAndNonDestructive() throws {
        let path = corpusDir + "/Marotta.pdf"
        guard FileManager.default.fileExists(atPath: path) else {
            throw XCTSkip("corpus assente: \(path) (vedi convenzione fixture).")
        }
        let ex = try PdfKitExtractor().extract(fromUri: URL(fileURLWithPath: path).absoluteString)
        let raw = buildDocumentFromPdf(ex, sourceName: "Marotta.pdf")
        let (placed, stats) = bindAndPlaceNotes(raw, ex)

        // Aggancio: qualche legame nella stessa pagina, nessun cross-page sospetto in eccesso.
        XCTAssertGreaterThan(stats.boundSamePage, 0, "su Marotta alcuni richiami si agganciano alla nota della pagina")
        XCTAssertGreaterThan(stats.footnotes, 0, "le note vengono spezzate in voci individuali")
        // Contabilità: ogni nota o è piazzata (breve/lunga) o resta in posizione.
        XCTAssertEqual(stats.placedShort + stats.placedLong + stats.unboundNotes, stats.footnotes,
                       "ogni nota è contabilizzata: piazzata o in-loco")
        // Le note restano LETTE (presenti nella struttura piazzata).
        XCTAssertTrue(placed.structure.contains { $0.type == .NOTE || $0.type == .EDITORIAL_NOTE },
                      "le note sono lette (presenti), non escluse")
        // Non-distruttività: il testo totale non si perde né si duplica (entro tolleranza
        // di separatori/trim del piazzamento).
        func chars(_ d: ScabopdfDocument) -> Int { d.structure.reduce(0) { $0 + ($1.text?.count ?? 0) } }
        let r = Double(chars(raw)), p = Double(chars(placed))
        XCTAssertGreaterThan(p, r * 0.97, "nessuna perdita rilevante di testo nel piazzamento")
        XCTAssertLessThan(p, r * 1.05, "nessuna duplicazione rilevante di testo nel piazzamento")
    }

    // MARK: - Recon marcatore di richiamo sulla pipeline PDFKit REALE (Fase 1b note)

    // Verdetto make-or-break del capitolo NOTE: con cosa PDFKit espone DAVVERO
    // (dimensione span, bbox, testo), il marcatore di richiamo in-corpo è
    // distinguibile? Quattro regimi misurati sulla sorgente (PyMuPDF) e qui
    // VERIFICATI su PDFKit, perché gli strumenti dev-time spezzano/ordinano
    // diversamente (cautela di metodo, Mattone A/B): SMALLER (dim minore),
    // RAISED (stessa dim, apice solo geometria), PAREN (testo "(N)" a dim body),
    // FLAT (cifra incollata stessa dim, indistinguibile = PDFKit cieco).
    // Tutto FUORI repo; il JSON dumpato porta SOLO il marcatore corto + geometria,
    // nessun testo di corpo.

    private struct MarkerSample: Codable {
        let page: Int; let marker: String; let kind: String
        let size: Double; let bodySize: Double; let yDelta: Double
    }
    private struct MarkerRecon: Codable {
        let pdf: String; let pages: Int; let bodySize: Double
        let sizeHistogram: [String: Int]
        let smaller: Int; let raisedSameSize: Int; let flatSameSize: Int; let parenInline: Int
        let noteLines: Int; let adjSame: Int; let adjNext: Int; let adjNone: Int
        let samples: [MarkerSample]
    }

    private static let reNum = try! NSRegularExpression(pattern: "^[0-9]{1,3}$")
    private static let reParNum = try! NSRegularExpression(pattern: "^[\\(\\[]\\s?[0-9]{1,3}\\s?[\\)\\]]$")
    private static let reParInline = try! NSRegularExpression(pattern: "\\(([0-9]{1,3})\\)")
    private static let symMarkers: Set<String> = ["*", "†", "‡", "§", "¶"]

    private func matches(_ re: NSRegularExpression, _ s: String) -> Bool {
        re.firstMatch(in: s, range: NSRange(s.startIndex..<s.endIndex, in: s)) != nil
    }
    /// (kind, numeric-or-symbol value) for a marker-shaped trimmed token, else nil.
    private func markerKind(_ raw: String) -> (String, String)? {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty || t.utf16.count > 5 { return nil }
        if matches(Self.reNum, t) { return ("num", t) }
        if matches(Self.reParNum, t) { return ("paren", t.filter { $0.isNumber }) }
        if Self.symMarkers.contains(t) { return ("sym", t) }
        return nil
    }

    /// Body font size by the Generic's rule (largest 0.5pt bucket with line-count
    /// ≥ half the most frequent — robust to note-heavy volumes).
    private func bodySize(_ ex: PdfExtraction) -> Double {
        var cnt: [Double: Int] = [:]
        for page in ex.pages {
            for line in page.lines {
                let sm = summarizeLine(line)
                if sm.fontSize > 0 {
                    let k = (sm.fontSize * 2).rounded() / 2
                    cnt[k, default: 0] += 1
                }
            }
        }
        let top = cnt.values.max() ?? 0
        var body = 0.0
        for (s, c) in cnt where Double(c) >= Double(top) * 0.5 && s > body { body = s }
        return body
    }

    private func markerRecon(_ ex: PdfExtraction, name: String, pageCap: Int = 400) -> MarkerRecon {
        let body = bodySize(ex)
        let smallTh = 0.80 * body
        var sizeHist: [String: Int] = [:]
        var smaller = 0, raised = 0, flat = 0, paren = 0, noteLines = 0
        var inbodyByPage: [Int: [Int]] = [:]
        var openByPage: [Int: [Int]] = [:]
        var samples: [MarkerSample] = []
        let pages = min(ex.pages.count, pageCap)
        for pi in 0..<pages {
            let page = ex.pages[pi]
            let h = page.height
            for line in page.lines {
                let spans = line.spans.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                if spans.isEmpty { continue }
                for s in spans where s.fontSize > 0 {
                    let k = (s.fontSize * 2).rounded() / 2
                    sizeHist[String(format: "%.1f", k), default: 0] += 1
                }
                let bodySpans = spans.filter { abs($0.fontSize - body) <= 0.6 }
                let hasBody = !bodySpans.isEmpty
                // bottom edge (origin bottom-left) of body spans = baseline reference
                let bodyBottom = bodySpans.map { $0.bbox.y }.min() ?? 0
                // ---- in-body markers (line carries body text) ----
                if hasBody {
                    for s in spans {
                        // regime 3: parenthesised (N) inside a body-size span's text
                        if abs(s.fontSize - body) <= 0.6 {
                            let t = s.text
                            let ns = t as NSString
                            for m in Self.reParInline.matches(in: t, range: NSRange(location: 0, length: ns.length)) {
                                paren += 1
                                if let v = Int(ns.substring(with: m.range(at: 1))) {
                                    inbodyByPage[pi, default: []].append(v)
                                }
                            }
                        }
                        guard let mk = markerKind(s.text) else { continue }
                        let yDelta = s.bbox.y - bodyBottom
                        let kind: String
                        if s.fontSize > 0 && s.fontSize <= smallTh {
                            kind = "smaller"; smaller += 1
                        } else if yDelta > 1.0 {
                            kind = "raised"; raised += 1
                        } else {
                            kind = "flat"; flat += 1
                        }
                        if (kind == "smaller" || kind == "raised"), let v = Int(mk.1) {
                            inbodyByPage[pi, default: []].append(v)
                        }
                        if samples.count < 40 {
                            samples.append(MarkerSample(
                                page: pi, marker: mk.1, kind: kind,
                                size: s.fontSize, bodySize: body, yDelta: (yDelta * 100).rounded() / 100))
                        }
                    }
                }
                // ---- note-open markers: small line in the bottom band ----
                let sm = summarizeLine(line)
                if sm.fontSize > 0 && sm.fontSize <= 0.85 * body && sm.yTop < 0.40 * h {
                    noteLines += 1
                    let lead = sm.text.trimmingCharacters(in: .whitespacesAndNewlines)
                    let digits = lead.prefix { $0.isNumber }
                    if let v = Int(digits) { openByPage[pi, default: []].append(v) }
                }
            }
        }
        var adjSame = 0, adjNext = 0, adjNone = 0
        for (pi, vals) in inbodyByPage {
            let here = Set(openByPage[pi] ?? [])
            let next = Set(openByPage[pi + 1] ?? [])
            for v in vals {
                if here.contains(v) { adjSame += 1 }
                else if next.contains(v) { adjNext += 1 }
                else { adjNone += 1 }
            }
        }
        return MarkerRecon(
            pdf: name, pages: pages, bodySize: body, sizeHistogram: sizeHist,
            smaller: smaller, raisedSameSize: raised, flatSameSize: flat, parenInline: paren,
            noteLines: noteLines, adjSame: adjSame, adjNext: adjNext, adjNone: adjNone,
            samples: samples)
    }

    // MARK: - Fedeltà-lettura DOPO il piazzamento note + meccanica dell'aggancio (Fase 3)

    private struct ReadingSegmentDump: Codable {
        let role: String; let lengthCategory: String; let acousticIntro: String; let text: String
    }
    private struct ReadingDump: Codable {
        let pdf: String
        let stats: NotePlacementStats
        let segments: [ReadingSegmentDump]
    }

    /// Esegue la pipeline REALE + aggancio/piazzamento note e dumpa i segmenti di
    /// lettura effettivi (CORPO + note piazzate) + la diagnostica di aggancio, per
    /// misurare la fedeltà-lettura prima/dopo e ispezionare i piazzamenti. Path di
    /// richiesta dedicato; tutto fuori repo. `XCTSkip` senza richiesta.
    func test_readingFidelityDump_fromRequest() throws {
        let reqPath = ProcessInfo.processInfo.environment["SCABO_READING_REQUEST"]
            ?? "/tmp/scabo_reading_request.json"
        guard let data = FileManager.default.contents(atPath: reqPath),
              let req = try? JSONDecoder().decode(DumpRequest.self, from: data) else {
            throw XCTSkip("nessuna richiesta reading in \(reqPath).")
        }
        try? FileManager.default.createDirectory(atPath: req.outDir, withIntermediateDirectories: true)
        let extractor = PdfKitExtractor()
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted]
        for name in req.pdfs {
            let path = req.corpusDir + "/" + name
            guard FileManager.default.fileExists(atPath: path) else {
                print("[reading] assente, salto: \(path)"); continue
            }
            let ex = try extractor.extract(fromUri: URL(fileURLWithPath: path).absoluteString)
            let raw = buildDocumentFromPdf(ex, sourceName: name)
            let placedResult = bindAndPlaceNotes(raw, ex)
            let segments = ContinuousBodyBuilder.bodySegments(from: placedResult.document, granularity: .fine)
            let dump = ReadingDump(
                pdf: name, stats: placedResult.stats,
                segments: segments.map {
                    ReadingSegmentDump(role: $0.role, lengthCategory: $0.lengthCategory,
                                       acousticIntro: $0.acousticIntro, text: $0.text)
                })
            let stem = (name as NSString).deletingPathExtension
            try enc.encode(dump).write(to: URL(fileURLWithPath: req.outDir + "/\(stem).reading.json"))
            let s = placedResult.stats
            print("""
                [reading] \(name): segmenti=\(segments.count)  note(footnotes)=\(s.footnotes)
                  aggancio: same-page=\(s.boundSamePage) cross-page=\(s.boundCrossPage) non-agganciati(marker)=\(s.unboundMarkers)
                  piazzate: brevi(fine-frase)=\(s.placedShort) lunghe(fine-sezione)=\(s.placedLong) non-agganciate(in-loco)=\(s.unboundNotes)
                  marker: smaller=\(s.markersSmaller) paren=\(s.markersParen)
                """)
        }
    }

    /// Esegue il recon marcatore sulla pipeline PDFKit reale per i PDF della
    /// richiesta (path fisso, fuori repo) e scrive un JSON compatto per volume.
    /// `XCTSkip` se non c'è richiesta (le run normali non fanno nulla).
    func test_markerReconDump_fromRequest() throws {
        let reqPath = ProcessInfo.processInfo.environment["SCABO_MARKER_REQUEST"]
            ?? "/tmp/scabo_marker_request.json"
        guard let data = FileManager.default.contents(atPath: reqPath),
              let req = try? JSONDecoder().decode(DumpRequest.self, from: data) else {
            throw XCTSkip("nessuna richiesta marker in \(reqPath): recon non invocato.")
        }
        try? FileManager.default.createDirectory(atPath: req.outDir, withIntermediateDirectories: true)
        let extractor = PdfKitExtractor()
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        for name in req.pdfs {
            let path = req.corpusDir + "/" + name
            guard FileManager.default.fileExists(atPath: path) else {
                print("[marker] assente, salto: \(path)"); continue
            }
            let ex = try extractor.extract(fromUri: URL(fileURLWithPath: path).absoluteString)
            let recon = markerRecon(ex, name: name)
            let stem = (name as NSString).deletingPathExtension
            try enc.encode(recon).write(to: URL(fileURLWithPath: req.outDir + "/\(stem).markers.json"))
            let total = recon.smaller + recon.raisedSameSize + recon.flatSameSize + recon.parenInline
            print("""
                [marker] \(name): body≈\(recon.bodySize)pt pagine=\(recon.pages)
                  in-corpo: SMALLER=\(recon.smaller) RAISED=\(recon.raisedSameSize) FLAT=\(recon.flatSameSize) PAREN=\(recon.parenInline) (tot \(total))
                  note-lines(settore)=\(recon.noteLines)  ADIACENZA same=\(recon.adjSame) next=\(recon.adjNext) none=\(recon.adjNone)
                """)
        }
    }
}
