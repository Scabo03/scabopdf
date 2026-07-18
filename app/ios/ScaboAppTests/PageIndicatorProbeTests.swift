//
//  PageIndicatorProbeTests.swift
//  ScaboAppTests
//
//  SONDA DIAGNOSTICA DELL'INDICATORE DI PAGINA (§ 4.3) — additiva, nessuna modifica di produzione.
//
//  Riproduce ESATTAMENTE la catena che alimenta il contatore in lettura:
//      PdfKitExtractor.extract → buildDocumentFromPdf → bindAndPlaceNotes
//      → ContinuousBodyBuilder.bodySegments → DocumentOpener.buildPageMap
//      → provider id-segmento → pagina (1-based)
//  e la confronta con la VERITÀ DI TERRENO on-device: la pagina del PDF su cui il testo di
//  quel segmento è realmente stampato, ricavata dall'ESTRAZIONE (`PdfExtraction.pages`,
//  `pageIndex` = indice assoluto di pagina PDFKit). Nessun oracolo esterno, nessun Python.
//
//  Misura tre cose, che sono le tre modalità di guasto possibili del contatore:
//    (1) COPERTURA — quanti segmenti risolvono a `nil` (indicatore che scompare);
//    (2) ERRORE — resolved − reale, in pagine, con istogramma e casi peggiori;
//    (3) MONOTONIA — quante volte la pagina RETROCEDE lungo l'ordine di lettura.
//
//  `XCTSkip` senza file di richiesta: verde su un checkout pulito senza corpus.
//

import XCTest
@testable import ScaboApp
@testable import ScaboCore

final class PageIndicatorProbeTests: XCTestCase {

    private struct ProbeRequest: Codable {
        let corpusDir: String
        let outDir: String
        let pdfs: [String]
    }

    /// Riduce a sole lettere minuscole: la firma stabile per cercare un testo dentro una pagina
    /// estratta, immune a spazi, sillabazione, cifre-marcatore e punteggiatura.
    private func letters(_ text: String) -> String {
        var out = String.UnicodeScalarView()
        for ch in text.precomposedStringWithCanonicalMapping.lowercased() where ch.isLetter {
            out.append(contentsOf: String(ch).unicodeScalars)
        }
        return String(out)
    }

    func test_pageIndicatorProbe_fromRequest() throws {
        let reqPath = ProcessInfo.processInfo.environment["SCABO_PAGEPROBE_REQUEST"]
            ?? "/tmp/scabo_pageprobe_request.json"
        guard let data = FileManager.default.contents(atPath: reqPath),
              let req = try? JSONDecoder().decode(ProbeRequest.self, from: data) else {
            throw XCTSkip("nessuna richiesta pageprobe in \(reqPath).")
        }
        let extractor = PdfKitExtractor()

        for name in req.pdfs {
            let path = req.corpusDir + "/" + name
            guard FileManager.default.fileExists(atPath: path) else {
                print("[pagina] assente, salto: \(path)"); continue
            }
            let ex = try extractor.extract(fromUri: URL(fileURLWithPath: path).absoluteString)
            let raw = buildDocumentFromPdf(ex, sourceName: name)
            let placed = bindAndPlaceNotes(raw, ex)
            let segments = ContinuousBodyBuilder.bodySegments(from: placed.document, granularity: .fine)

            // La mappa e il provider REALI dell'app.
            // La mappa REALE dell'app: strato per nodo + strato per segmento sovrapposto.
            let content = try paginate(segments, DEFAULT_SEGMENTS_PER_PAGE)
            let pageMap = DocumentOpener.buildPageMap(placed.document, content: content)
            func resolved(_ segId: String) -> Int? {
                if let exact = pageMap[segId] { return exact }
                let base = segId.split(separator: "#", maxSplits: 1,
                                       omittingEmptySubsequences: false).first.map(String.init) ?? segId
                return pageMap[base]
            }

            // Verità di terreno: testo a-lettere di ciascuna pagina estratta, indicizzato per
            // pagina 1-based (pageIndex 0-based + 1, la stessa convenzione dell'indicatore).
            var pageText: [Int: String] = [:]
            for p in ex.pages {
                let raw = p.lines.map { $0.spans.map(\.text).joined() }.joined(separator: " ")
                pageText[p.pageIndex + 1] = letters(raw)
            }
            let sortedPages = pageText.keys.sorted()

            var nilCount = 0
            var nilByRole: [String: Int] = [:]
            var errors: [Int] = []          // resolved − reale, per i segmenti verificabili
            var unverifiable = 0            // testo troppo corto o non ritrovato
            var worst: [(String, Int, Int, String)] = []   // (segId, resolved, reale, incipit)
            var backwards = 0
            var lastPage: Int? = nil

            for seg in segments {
                guard let r = resolved(seg.id) else {
                    nilCount += 1
                    nilByRole[seg.role, default: 0] += 1
                    continue
                }
                if let lp = lastPage, r < lp { backwards += 1 }
                lastPage = r

                // Firma: 40 lettere prese DOPO le prime 5 (salta il marcatore/numero iniziale).
                let sig = letters(seg.text)
                guard sig.count >= 45 else { unverifiable += 1; continue }
                let needle = String(sig.dropFirst(5).prefix(40))

                // Cerca la pagina che contiene la firma, preferendo la più vicina alla risolta
                // (i testi ripetuti esistono; la vicinanza evita di attribuire un falso errore).
                var best: Int? = nil
                for p in sortedPages where pageText[p]!.contains(needle) {
                    if best == nil || abs(p - r) < abs(best! - r) { best = p }
                }
                guard let truth = best else { unverifiable += 1; continue }
                let err = r - truth
                errors.append(err)
                if err != 0 && worst.count < 12 {
                    worst.append((seg.id, r, truth, String(seg.text.prefix(70))))
                }
            }

            let verified = errors.count
            let exact = errors.filter { $0 == 0 }.count
            let absErrors = errors.map(abs)
            let mean = absErrors.isEmpty ? 0 : Double(absErrors.reduce(0, +)) / Double(absErrors.count)
            let maxErr = absErrors.max() ?? 0
            let sortedAbs = absErrors.sorted()
            let median = sortedAbs.isEmpty ? 0 : sortedAbs[sortedAbs.count / 2]

            print("""
                [pagina] \(name)
                  segmenti=\(segments.count)  pagine PDF=\(ex.pages.count)
                  RISOLUZIONE: nil=\(nilCount) (\(pct(nilCount, segments.count))%) per ruolo=\(nilByRole)
                  VERIFICATI=\(verified) (non verificabili=\(unverifiable))
                  ESATTI=\(exact) (\(pct(exact, max(1, verified)))%)  |errore| medio=\(String(format: "%.2f", mean)) mediano=\(median) max=\(maxErr)
                  MONOTONIA: retrocessioni=\(backwards)
                """)
            for w in worst {
                print("    [scarto] \(w.0): indicatore=\(w.1) reale=\(w.2) — «\(w.3)…»")
            }
        }
    }

    private func pct(_ a: Int, _ b: Int) -> Int { b == 0 ? 0 : Int((Double(a) / Double(b)) * 100.0) }
}
