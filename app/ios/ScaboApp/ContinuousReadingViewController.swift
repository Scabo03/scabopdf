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
//  ── Sigillatura dei due container — il vincolo sacro (§ 2.2/§ 2.3) ───────────────────────────
//
//  Lo swipe orizzontale VoiceOver dentro il container del testo non deve MAI raggiungere gli
//  elementi d'interfaccia in alto; resta nel testo fino al primo/ultimo elemento ASSOLUTO del
//  documento. Il meccanismo UIKit affidabile per CONFINARE la navigazione lineare a una regione è
//  `accessibilityViewIsModal`: il container ATTIVO è modale e VoiceOver ignora il container
//  fratello, perciò lo swipe non può sconfinare. Il passaggio fra i due container NON avviene via
//  swipe ma col solo gesto di sistema di escape (scrub a due dita): l'escape sul testo attiva
//  l'interfaccia, l'escape sull'interfaccia riattiva il testo. È la realizzazione fedele di "si
//  cambia container solo con atti deliberati di sistema" (§ 2.3) e non ridefinisce alcun gesto
//  (§ 2.4): si definisce solo la risposta all'azione di escape.
//
//  Onestà sulla verifica: i test (Simulator) certificano la STRUTTURA — due container distinti
//  con `accessibilityElements` DISGIUNTI (il testo espone solo segmenti, l'interfaccia solo
//  [Indietro, titolo]), la sigillatura modale impostata, l'escape che commuta la modalità. Che lo
//  swipe "all'orecchio" non raggiunga mai l'interfaccia, e il feel del passaggio fra container, li
//  certifica lo sviluppatore su dispositivo reale con VoiceOver (TestFlight); il Simulator non
//  riproduce VoiceOver.
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
        // Stato iniziale: il container del testo è quello attivo (si entra leggendo).
        activateTextContainer(moveFocus: false)
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

        // La radice espone i DUE container nell'ordine di lettura visivo (interfaccia in alto,
        // testo sotto). La sigillatura runtime fra i due è la modalità (vedi `activate…`).
        view.accessibilityElements = [interfaceBar, readingView]
    }

    private func wireContainers() {
        interfaceBar.onBack = { [weak self] in self?.onBack?() }
        // Escape (scrub a due dita) commuta il container attivo, in entrambe le direzioni.
        readingView.onEscape = { [weak self] in self?.activateInterfaceContainer(moveFocus: true) }
        interfaceBar.onEscape = { [weak self] in self?.activateTextContainer(moveFocus: true) }
    }

    // MARK: - Commutazione fra i due container sigillati

    /// Rende ATTIVO il container del testo: il testo è modale (lo swipe vi resta confinato),
    /// l'interfaccia è ignorata da VoiceOver finché non si fa di nuovo escape.
    private func activateTextContainer(moveFocus: Bool) {
        interfaceBar.accessibilityViewIsModal = false
        readingView.accessibilityViewIsModal = true
        if moveFocus {
            UIAccessibility.post(notification: .screenChanged, argument: readingView)
        }
    }

    /// Rende ATTIVO il container dell'interfaccia: l'interfaccia è modale (lo swipe vi resta
    /// confinato fra [Indietro, titolo]), il testo è ignorato finché non si fa escape.
    private func activateInterfaceContainer(moveFocus: Bool) {
        readingView.accessibilityViewIsModal = false
        interfaceBar.accessibilityViewIsModal = true
        if moveFocus {
            UIAccessibility.post(notification: .screenChanged, argument: interfaceBar.backButton)
        }
    }

    // MARK: - Introspezione per i test (sigillatura dei due container)

    /// Il container del testo (sola lettura).
    var textContainerForTesting: ContinuousReadingView { readingView }
    /// Il container dell'interfaccia (sola lettura).
    var interfaceContainerForTesting: ReadingInterfaceBar { interfaceBar }
    /// I due container esposti dalla radice, nell'ordine.
    var rootAccessibilityContainersForTesting: [NSObject] {
        (view.accessibilityElements as? [NSObject]) ?? []
    }
    /// Vero se il container del testo è il modale attivo (swipe confinato al testo, § 2.2).
    var textContainerIsModalForTesting: Bool { readingView.accessibilityViewIsModal }
    /// Vero se il container dell'interfaccia è il modale attivo.
    var interfaceContainerIsModalForTesting: Bool { interfaceBar.accessibilityViewIsModal }
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
