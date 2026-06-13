//
//  ContinuousReadingViewController.swift
//  ScaboApp
//
//  Ospita il Layout "Lettura Continua" su DUE container di accessibilità separati e CHIUSI
//  (§ 2.3, § 3.1): il container del TESTO (`ContinuousReadingView`, dove vive solo il documento)
//  e il container dell'INTERFACCIA (`ReadingInterfaceBar`, per ora titolo + Indietro, struttura
//  permanente per la futura toolbar). Riceve dall'esterno il contenuto già elaborato dal flusso
//  di import/elaborazione: nessun caricamento autonomo nel percorso utente.
//
//  ── Due container APERTI — entrambe le vie di passaggio (§ 2.3) ──────────────────────────────
//
//  Restano DUE container di accessibilità distinti e ordinati internamente: il container del
//  testo (solo segmenti) e quello dell'interfaccia (solo [Indietro, titolo]). Il § 2.3 prevede
//  TRE vie deliberate per passare da un container all'altro: lo scrub a due dita, l'esplorazione
//  tattile (toccare la zona dell'altro container), e i gesti di sistema. Questa build adotta la
//  versione APERTA: ENTRAMBE le vie disponibili.
//
//  Per questo NON si usa `accessibilityViewIsModal`: la modalità confina la navigazione lineare
//  ma rende il container inattivo irraggiungibile anche al TOCCO, sopprimendo una delle due vie.
//  Senza modalità i due container restano entrambi nell'albero di accessibilità (raggiungibili per
//  tocco) e la struttura a container (`accessibilityElements` disgiunti e ordinati su ciascuna
//  sottoview-container, `accessibilityContainerType` sull'interfaccia) definisce l'ordine di
//  navigazione. Lo scrub a due dita resta una via di passaggio: l'override
//  `accessibilityPerformEscape` (non un gesto ridefinito, § 2.4: solo la risposta all'azione di
//  escape) sposta il focus all'altro container, in entrambe le direzioni.
//
//  ── Conseguenza onesta della versione aperta (da provare all'orecchio) ───────────────────────
//
//  Senza modalità, lo swipe orizzontale LINEARE può attraversare il confine fra i due container
//  quando raggiunge l'estremo dell'ordine di navigazione. L'ordine è scelto perché, SE attraversa,
//  lo faccia in un punto PREVEDIBILE: l'interfaccia PRECEDE il testo
//  (`view.accessibilityElements = [interfaceBar, readingView]`), così l'unica giunzione è
//  [ultimo elemento d'interfaccia ↔ primo segmento del testo]; swipando indietro dall'inizio del
//  testo si arriva all'interfaccia (non a un punto casuale), e swipando avanti dall'ultimo
//  segmento si raggiunge la fine assoluta del documento. QUESTA build serve proprio a provare se,
//  all'orecchio, lo swipe nel testo sconfina sull'interfaccia; se sarà un problema reale lo si
//  scoprirà sul dispositivo e ALLORA si valuterà se blindare (es. reintrodurre la modalità). Qui
//  NON si blinda: l'obiettivo è la versione aperta.
//
//  Onestà sulla verifica: i test (Simulator) certificano la STRUTTURA — due container distinti con
//  `accessibilityElements` DISGIUNTI e ordinati, entrambi presenti nell'albero (nessuna modalità,
//  nessuno nascosto), lo scrub instradato come passaggio. Se lo swipe lineare attraversi o no il
//  confine, e il feel delle due vie di passaggio, sono comportamento VoiceOver RUNTIME che il
//  Simulator non riproduce: li certifica lo sviluppatore su dispositivo reale (TestFlight).
//
//  ── Ponte di sviluppo (NON più nel percorso utente) ─────────────────────────────────────────
//
//  Gli helper statici di demo (fixture seedato / campione sintetico) restano disponibili per i
//  test e per un eventuale avvio di sviluppo, ma il percorso utente reale è import → elaborazione
//  → questa view col contenuto iniettato; non c'è più auto-caricamento al lancio.
//

import PDFKit
import UIKit
import ScaboCore

final class ContinuousReadingViewController: UIViewController {

    // MARK: - Container del testo e dell'interfaccia

    private let readingView = ContinuousReadingView()
    private let interfaceBar = ReadingInterfaceBar()

    /// Contenuto di corpo da rendere (iniettato dal flusso di elaborazione).
    private let content: PaginatedContent

    /// Azione del tasto Indietro: torna alla Home nuda. Impostata dal presentatore.
    var onBack: (() -> Void)?

    private static let interfaceBarHeight: CGFloat = 44

    // MARK: - Init

    /// Costruisce la reading view sul contenuto già elaborato. `sourceName` è conservato per usi
    /// futuri (referto, persistenza); il titolo del container d'interfaccia è fisso
    /// "Lettura Continua".
    init(content: PaginatedContent, sourceName: String = "") {
        self.content = content
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) non supportato: ContinuousReadingViewController è costruito in codice.")
    }

    // MARK: - Ciclo di vita

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        embedContainers()
        wireContainers()
        readingView.render(content)
    }

    private func embedContainers() {
        interfaceBar.translatesAutoresizingMaskIntoConstraints = false
        readingView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(interfaceBar)
        view.addSubview(readingView)

        NSLayoutConstraint.activate([
            interfaceBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            interfaceBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            interfaceBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            interfaceBar.heightAnchor.constraint(equalToConstant: Self.interfaceBarHeight),

            readingView.topAnchor.constraint(equalTo: interfaceBar.bottomAnchor),
            readingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            readingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            readingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        // La radice espone i DUE container; l'INTERFACCIA precede il TESTO, così l'unica giunzione
        // possibile dello swipe lineare è [interfaccia ↔ inizio del testo] (vedi nota di testata).
        // Versione APERTA: nessuna modalità, entrambi raggiungibili anche per tocco.
        readingView.accessibilityViewIsModal = false
        interfaceBar.accessibilityViewIsModal = false
        view.accessibilityElements = [interfaceBar, readingView]
    }

    private func wireContainers() {
        interfaceBar.onBack = { [weak self] in self?.onBack?() }
        // Scrub a due dita (escape): una delle vie di passaggio fra container — sposta il focus
        // all'altro container, in entrambe le direzioni. L'altra via, l'esplorazione tattile,
        // funziona da sé perché nessuno dei due container è nascosto da una modalità.
        readingView.onEscape = { [weak self] in self?.focusInterfaceContainer() }
        interfaceBar.onEscape = { [weak self] in self?.focusTextContainer() }
    }

    // MARK: - Passaggio fra i due container (scrub → spostamento di focus, niente modalità)

    /// Sposta il focus VoiceOver al container dell'interfaccia (sul tasto Indietro).
    private func focusInterfaceContainer() {
        UIAccessibility.post(notification: .screenChanged, argument: interfaceBar.backButton)
    }

    /// Sposta il focus VoiceOver al container del testo (sul suo primo elemento).
    private func focusTextContainer() {
        UIAccessibility.post(notification: .screenChanged, argument: readingView)
    }

    // MARK: - Introspezione per i test (struttura dei due container)

    /// Il container del testo (sola lettura).
    var textContainerForTesting: ContinuousReadingView { readingView }
    /// Il container dell'interfaccia (sola lettura).
    var interfaceContainerForTesting: ReadingInterfaceBar { interfaceBar }
    /// I due container esposti dalla radice, nell'ordine.
    var rootAccessibilityContainersForTesting: [NSObject] {
        (view.accessibilityElements as? [NSObject]) ?? []
    }
    /// Vero se il container del testo è modale (DEVE essere falso: versione aperta).
    var textContainerIsModalForTesting: Bool { readingView.accessibilityViewIsModal }
    /// Vero se il container dell'interfaccia è modale (DEVE essere falso: versione aperta).
    var interfaceContainerIsModalForTesting: Bool { interfaceBar.accessibilityViewIsModal }
    /// Vero se il container del testo è nascosto all'accessibilità (DEVE essere falso: raggiungibile).
    var textContainerIsHiddenForTesting: Bool { readingView.accessibilityElementsHidden }
    /// Vero se il container dell'interfaccia è nascosto (DEVE essere falso: raggiungibile per tocco).
    var interfaceContainerIsHiddenForTesting: Bool { interfaceBar.accessibilityElementsHidden }
}

// MARK: - Ponte di sviluppo / helper per i test (fuori dal percorso utente)

extension ContinuousReadingViewController {

    /// Cap di responsività del demo (vedi nota PONTE). Non è un limite di prodotto.
    static let demoMaxPages = 6
    /// Pagina di partenza del campione demo su patriarca (le prime sono frontespizio/indice).
    static let demoBodyStartPage = 40
    static let seededFixtureName = "patriarca_benazzo.pdf"
    static let seededSubdir = "scabo-fixtures"

    /// Contenuto di corpo di demo (fixture seedato se presente, altrimenti campione sintetico).
    /// Per un eventuale avvio di sviluppo: il percorso utente reale passa per l'import.
    static func demoContent() -> PaginatedContent {
        let document = loadDemoDocument()
        return (try? ContinuousBodyBuilder.bodyPaginatedContent(from: document))
            ?? PaginatedContent(pages: [], totalSegments: 0)
    }

    /// Produce un `ScabopdfDocument` di corpo: fixture reale seedato se raggiungibile, altrimenti
    /// campione sintetico. Compute puro, off-main.
    static func loadDemoDocument() -> ScabopdfDocument {
        let extractor = PdfKitExtractor()
        if let seeded = seededFixtureURL(),
           let sample = sampledPDF(at: seeded, from: demoBodyStartPage, count: demoMaxPages),
           let extraction = try? extractor.extract(fromUri: sample.absoluteString) {
            return buildDocumentFromPdf(extraction, sourceName: seededFixtureName)
        }
        let synthetic = makeSyntheticSamplePDF()
        if let extraction = try? extractor.extract(fromUri: synthetic.absoluteString) {
            return buildDocumentFromPdf(extraction, sourceName: "campione_sintetico.pdf")
        }
        let extraction = PdfExtraction(version: 2, pageCount: 0, pages: [])
        return buildDocumentFromPdf(extraction, sourceName: "vuoto.pdf")
    }

    static func seededFixtureURL() -> URL? {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        guard let base = documents.first else { return nil }
        let url = base.appendingPathComponent(seededSubdir).appendingPathComponent(seededFixtureName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Riserializza una finestra di `count` pagine a partire da `startPage` in un file temporaneo.
    /// Cap di responsività per il demo/test; `startPage` è clampato. `nil` se il PDF non apre.
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

    /// Campione PDF sintetizzato in-app: un titolo, alcuni paragrafi di corpo e una nota piccola
    /// (che il filtro di corpo esclude). Deterministico, ermetico.
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

    /// Guardia test host (conservata per simmetria con eventuali avvii di sviluppo).
    static var isRunningUnderTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}
