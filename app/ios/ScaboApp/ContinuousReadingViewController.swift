//
//  ContinuousReadingViewController.swift
//  ScaboApp
//
//  Ospita la `ContinuousReadingView` e la fa vivere nel contesto app/Simulator
//  facendo arrivare un PDF reale alla view tramite la catena on-device
//  PdfKitExtractor → ScaboCore (classificazione) → corpo paginato.
//
//  ── PONTE TEMPORANEO (non architettura definitiva) ──────────────────────────────
//
//  Il caricamento del documento qui è un PONTE per dare vita e testabilità alla
//  view in questa fase, NON il design finale. Non c'è ancora libreria né document
//  picker: il ponte cerca un fixture SEEDATO sul Simulator
//  (`Documents/scabo-fixtures/patriarca_benazzo.pdf`, via
//  `app/ios/scripts/seed_fixtures.sh`) e, se assente, RIPIEGA su un campione PDF
//  sintetizzato in-app così la view è sempre dimostrabile su un Simulator pulito.
//  Quando c'è il fixture reale (manuale di centinaia di pagine) il ponte ne
//  campiona le prime pagine: è un cap di RESPONSIVITÀ del demo, non un limite di
//  prodotto, e non intacca la continuità del container (che è continuo su
//  qualunque insieme di segmenti riceva). Tutto questo evapora quando arriva il
//  flusso libreria/import reale.
//
//  La VERA verifica di correttezza non dipende da questo ponte: vive nei test
//  (container/ordine/etichette/continuità su contenuto deterministico, end-to-end
//  da PDF sintetico, ed esercizio del fixture reale patriarca quando presente).
//

import PDFKit
import UIKit
import ScaboCore

final class ContinuousReadingViewController: UIViewController {

    private let readingView = ContinuousReadingView()

    /// Cap di responsività del demo (vedi nota PONTE TEMPORANEO). Non è un limite
    /// di prodotto.
    private static let demoMaxPages = 6

    /// Pagina di partenza del campione demo su patriarca: le prime pagine sono
    /// frontespizio/indice, il corpo monocolonna pulito (confermato dalla
    /// "fotografia" d'esplorazione) vive da ~40 in poi. Patriarca-specifico, vive
    /// solo finché vive il ponte temporaneo.
    private static let demoBodyStartPage = 40

    /// Nome del fixture privato cercato sul Simulator (seedato dallo script).
    private static let seededFixtureName = "patriarca_benazzo.pdf"
    private static let seededSubdir = "scabo-fixtures"

    override func viewDidLoad() {
        super.viewDidLoad()
        title = LAYOUT_DISPLAY_NAMES[.continuous]  // "Lettura Continua"
        view.backgroundColor = .systemBackground
        embedReadingView()

        // Non auto-caricare sotto XCTest: il test host non deve fare lavoro di
        // estrazione al lancio. I test esercitano il ponte esplicitamente.
        if Self.isRunningUnderTests { return }
        loadBodyContentViaBridge()
    }

    private func embedReadingView() {
        readingView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(readingView)
        NSLayoutConstraint.activate([
            readingView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            readingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            readingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            readingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // MARK: - Ponte temporaneo

    private func loadBodyContentViaBridge() {
        DispatchQueue.global(qos: .userInitiated).async {
            let document = Self.loadDemoDocument()
            let content = (try? ContinuousBodyBuilder.bodyPaginatedContent(from: document))
                ?? PaginatedContent(pages: [], totalSegments: 0)
            DispatchQueue.main.async { [weak self] in
                self?.readingView.render(content)
            }
        }
    }

    /// Produce un `ScabopdfDocument` di corpo da mostrare: fixture reale seedato se
    /// raggiungibile, altrimenti campione sintetico. Compute puro, off-main.
    private static func loadDemoDocument() -> ScabopdfDocument {
        let extractor = PdfKitExtractor()
        if let seeded = seededFixtureURL(),
           let sample = sampledPDF(at: seeded, from: demoBodyStartPage, count: demoMaxPages),
           let extraction = try? extractor.extract(fromUri: sample.absoluteString) {
            return buildDocumentFromPdf(extraction, sourceName: seededFixtureName)
        }
        // Fallback: campione sintetico in-app (la view è sempre dimostrabile).
        let synthetic = makeSyntheticSamplePDF()
        if let extraction = try? extractor.extract(fromUri: synthetic.absoluteString) {
            return buildDocumentFromPdf(extraction, sourceName: "campione_sintetico.pdf")
        }
        // Estrema difesa: documento vuoto valido (la view mostra contenuto vuoto,
        // non crasha).
        return emptyDocument()
    }

    // MARK: - Localizzazione / campionamento PDF

    private static func seededFixtureURL() -> URL? {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        guard let base = documents.first else { return nil }
        let url = base.appendingPathComponent(seededSubdir).appendingPathComponent(seededFixtureName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Riserializza una finestra di `count` pagine a partire da `startPage` in un
    /// file temporaneo. Cap di responsività per il demo/test; `startPage` è
    /// clampato all'intervallo valido. Ritorna `nil` se il PDF non apre.
    static func sampledPDF(at source: URL, from startPage: Int = 0, count: Int) -> URL? {
        guard let document = PDFDocument(url: source), document.pageCount > 0 else { return nil }
        let sample = PDFDocument()
        let start = max(0, min(startPage, document.pageCount - 1))
        let end = min(start + count, document.pageCount)
        for index in start..<end {
            guard let page = document.page(at: index)?.copy() as? PDFPage else { continue }
            sample.insert(page, at: sample.pageCount)
        }
        guard sample.pageCount > 0 else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("scabo_demo_sample_\(UUID().uuidString).pdf")
        return sample.write(to: url) ? url : nil
    }

    /// Campione PDF sintetizzato in-app: un titolo, alcuni paragrafi di corpo e una
    /// nota piccola (che il filtro di corpo esclude). Deterministico, ermetico.
    static func makeSyntheticSamplePDF() -> URL {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)  // A4 pt
        let blocks: [(text: String, size: CGFloat, bold: Bool)] = [
            ("Capitolo Primo — Le obbligazioni", 24, true),
            ("Il rapporto obbligatorio lega due soggetti determinati: il creditore e il debitore.", 11, false),
            ("Il creditore ha diritto alla prestazione, che deve essere suscettibile di valutazione economica.", 11, false),
            ("L'inadempimento espone il debitore al risarcimento del danno secondo le regole generali.", 11, false),
            ("Sezione I — La prestazione", 18, true),
            ("La prestazione può consistere in un dare, un fare o un non fare a seconda del titolo.", 11, false),
            ("Cfr. art. 1218 c.c. sulla responsabilità del debitore.", 8, false),
        ]
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("scabo_demo_synthetic_\(UUID().uuidString).pdf")
        try? renderer.writePDF(to: url) { ctx in
            ctx.beginPage()
            var y: CGFloat = 60
            for b in blocks {
                let font: UIFont = b.bold
                    ? UIFont.boldSystemFont(ofSize: b.size)
                    : UIFont.systemFont(ofSize: b.size)
                (b.text as NSString).draw(
                    at: CGPoint(x: 72, y: y),
                    withAttributes: [.font: font, .foregroundColor: UIColor.black])
                y += b.size + 14
            }
        }
        return url
    }

    private static func emptyDocument() -> ScabopdfDocument {
        let extraction = PdfExtraction(version: 2, pageCount: 0, pages: [])
        return buildDocumentFromPdf(extraction, sourceName: "vuoto.pdf")
    }

    // MARK: - Guardia test host

    static var isRunningUnderTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}
