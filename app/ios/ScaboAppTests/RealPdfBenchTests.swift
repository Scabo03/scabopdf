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
}
