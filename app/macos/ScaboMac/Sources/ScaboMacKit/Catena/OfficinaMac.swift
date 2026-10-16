//
//  OfficinaMac.swift
//  ScaboMacKit
//
//  LA CATENA DEL MAC (giro «costruzione della linea Mac», 2026-10-16): la stessa catena dell'iPad (`ProcessingChain`
//  di ScaboChain: estrazione con le cure condivise, risorse visive con la guardia deterministica dell'iPad,
//  classificazione, aggancio delle note, corpo, frazionamento delle note lunghe) più una cosa che l'iPad non fa:
//  l'INNESTO dei verdetti del modello d'impaginazione (Heron, `ScaboPageStructure`) con il FUSORE portato in Swift
//  (`ScaboCore/Fusore.swift`), sulle sole pagine che una politica prudente sceglie (sotto). Il FRAZIONAMENTO delle note
//  lunghe (decisione di prodotto del 2026-08-10, il meccanismo degli atti AKN) fino alla build 54 lo faceva solo il Mac;
//  dal 2026-10-16 lo fa anche l'iPad (decisione del maintainer: la lettura è la stessa chiunque l'abbia preparata).
//
//  LA POLITICA (decisione del giro, registrata nel referto e in LAYER2 § 12.12). Il banco ha validato il fusore con
//  Heron su due fenomeni, su pagine scelte a mano; qui le pagine le sceglie l'app, con SEGNALI SUOI GIÀ IN PRODUZIONE,
//  e il modello conferma. Nel dubbio non si tocca: dove i segnali dell'app e il modello non concordano, niente.
//
//  * Indice analitico (banco: indice del Codice penale). Pagine della regione di coda fortemente strutturate a indice
//    che portano il titolo o la testatina «Indice analitico/alfabetico» (`officinaAnalyticalIndexPages`: gli strumenti
//    del back-matter dell'app, ma la testatina conta anche se è mobilia e il titolo anche se porta il richiamo di una
//    nota), con nodi NOTE; il modello gira su quelle pagine; dove non vede alcuna nota, i nodi NOTE senza marcatore
//    diventano corpo (rietichettatura slot-preserving, guardia-marcatore).
//  * Nota che scavalca la pagina (banco: MULTIPAGE di Lineamenti) — SPENTA nella politica del giro (`.giro`), dopo la
//    rete sui 52 volumi. La scelta delle coppie col predicato di ricucitura dell'app (`officinaNoteTailContinuesHead`)
//    seleziona proprio le note che l'app GIÀ ricuce da sé nell'aggancio delle note (`NoteBinding`): lì l'innesto non
//    serve. E il riconoscimento delle righe della coda per contenimento del testo normalizzato (porto fedele del banco,
//    righe di almeno 10 lettere) a quella scala sposta anche righe di CORPO che il testo della nota contiene per caso
//    («dimento amministrativo.» dentro una nota che cita il «provvedimento amministrativo»): giunture sbagliate e cifre
//    perse in 4 volumi su 17. Il codice resta (`multipageStitch: true`) per il banco; la strada per riaccenderla è nel
//    referto del giro: coppie in cui l'app NON ricuce e righe riconosciute per geometria (riquadro del modello).
//
//  Sempre la rete di fedeltà del fusore (multinsieme delle parole identico). I referti non portano testo.
//

import Foundation
import PDFKit
import ScaboChain
import ScaboCore
import ScaboPageStructure

/// Quali fenomeni del fusore l'officina applica. La predefinita è la politica del giro; `spenta` dà la lettura dell'iPad
/// (stessa catena, stesso frazionamento delle note lunghe, nessun innesto).
public struct OfficinaPolicy: Equatable, Sendable {
    public var analyticalIndexRelabel: Bool
    public var multipageStitch: Bool

    /// Senza argomenti è la politica del giro (ricucitura fra pagine SPENTA): la ricucitura si accende solo chiedendola
    /// esplicitamente (`.banco`), mai per dimenticanza (revisione indipendente del giro).
    public init(analyticalIndexRelabel: Bool = true, multipageStitch: Bool = false) {
        self.analyticalIndexRelabel = analyticalIndexRelabel
        self.multipageStitch = multipageStitch
    }

    /// La politica del giro: solo l'indice analitico (la ricucitura fra pagine è spenta: vedi la testata del file).
    public static let giro = OfficinaPolicy(analyticalIndexRelabel: true, multipageStitch: false)
    public static let spenta = OfficinaPolicy(analyticalIndexRelabel: false, multipageStitch: false)
    /// Banco: anche la ricucitura fra pagine (non usata dall'app).
    public static let banco = OfficinaPolicy(analyticalIndexRelabel: true, multipageStitch: true)

    public var isOff: Bool { !analyticalIndexRelabel && !multipageStitch }
}

/// Il referto dell'innesto, PRIVO DI TESTO: candidati, pagine mandate al modello, operazioni.
public struct OfficinaReport: Codable, Equatable, Sendable {
    public var indexPages: [Int] = []
    public var multipageCandidates: [[Int]] = []
    public var modelPages: [Int] = []
    public var stitches: [[Int]] = []
    public var relabels = 0
    public var relabelPages: [Int] = []
    /// Gli id dei nodi rietichettati (nessun testo): per il confronto con le operazioni del banco.
    public var relabelNodes: [String] = []
    public var fidelityBroken = false
    public var modelUnavailable = false
    public var notes: [String] = []
}

/// I verdetti del modello per le pagine chieste, con il testo delle righe solo in memoria (ancoraggio del fusore).
@available(macOS 14.0, *)
final class HeronVerdictSource {
    private let analyzer: PageStructureAnalyzer
    private let pdf: PDFDocument
    private var cache: [Int: [LayoutVerdictItem]] = [:]

    init(analyzer: PageStructureAnalyzer, pdf: PDFDocument) {
        self.analyzer = analyzer
        self.pdf = pdf
    }

    /// Gli elementi della pagina 1-based (nil se la pagina non esiste o il modello fallisce su quella pagina).
    func items(page: Int) -> [LayoutVerdictItem]? {
        if let hit = cache[page] { return hit }
        guard page >= 1, let p = pdf.page(at: page - 1) else { return nil }
        guard let (layout, texts, _) = try? autoreleasepool(invoking: { try analyzer.analyzeWithRegionTexts(page: p, pageIndex: page - 1) })
        else { return nil }
        let items = zip(layout.regions, texts).map { r, t in
            LayoutVerdictItem(label: r.label, order: r.order, bbox: r.bbox, text: t)
        }
        cache[page] = items
        return items
    }
}

/// L'innesto dell'officina: segnali dell'app → modello sulle pagine scelte → fusore.
public final class OfficinaGraft: ChainGraft {
    public let policy: OfficinaPolicy
    public private(set) var report = OfficinaReport()
    /// Unità di calcolo del modello (predefinita: tutte).
    let computeUnits: LayoutComputeUnits

    public init(policy: OfficinaPolicy = .giro, computeUnits: LayoutComputeUnits = .all) {
        self.policy = policy
        self.computeUnits = computeUnits
    }

    // MARK: Segnali dell'app

    /// I nodi NOTE del documento grezzo per pagina (1-based), in pre-ordine, con il testo.
    static func notesByPage(_ doc: ScabopdfDocument) -> [Int: [String]] {
        var out: [Int: [String]] = [:]
        func walk(_ nodes: [NodeDict]) {
            for n in nodes {
                if n.type == .NOTE { out[n.page_index + 1, default: []].append(n.text ?? "") }
                if !n.children.isEmpty { walk(n.children) }
            }
        }
        walk(doc.structure)
        return out
    }

    /// Coppie A→B candidate alla ricucitura: la prima nota di B continua l'ultima nota di A (predicato dell'app).
    static func multipageCandidates(_ doc: ScabopdfDocument) -> [FusorePagePair] {
        let notes = notesByPage(doc)
        var out: [FusorePagePair] = []
        for b in notes.keys.sorted() {
            guard let tail = notes[b]?.first, let head = notes[b - 1]?.last else { continue }
            if officinaNoteTailContinuesHead(head: head, tail: tail) { out.append(FusorePagePair(b - 1, b)) }
        }
        return out
    }

    // MARK: L'innesto

    public func graft(extraction: PdfExtraction, rawDocument: ScabopdfDocument, pdfURL: URL, sourceName: String,
                      onPage: (Int, Int) -> Void, isCancelled: () -> Bool) -> ChainGraftOutput? {
        report = OfficinaReport()
        let unchanged = ChainGraftOutput(extraction: extraction, rawDocument: rawDocument, report: [])
        guard !policy.isOff else { return unchanged }

        // 1. Candidati dai segnali dell'app.
        let notes = Self.notesByPage(rawDocument)
        let indexPages = policy.analyticalIndexRelabel
            ? officinaAnalyticalIndexPages(extraction).map { $0 + 1 }.filter { notes[$0] != nil } : []
        let pairs = policy.multipageStitch ? Self.multipageCandidates(rawDocument) : []
        report.indexPages = indexPages
        report.multipageCandidates = pairs.map { [$0.a, $0.b] }
        let modelPages = Array(Set(indexPages + pairs.map { $0.b })).sorted()
        report.modelPages = modelPages
        guard !modelPages.isEmpty else { report.notes.append("nessuna pagina candidata"); return unchanged }

        // 2. Il modello sulle sole pagine candidate (testo delle righe solo in memoria).
        guard #available(macOS 14.0, *), let pdf = PDFDocument(url: pdfURL),
              let model = try? HeronLayoutModel.bundled(computeUnits: computeUnits) else {
            report.modelUnavailable = true
            report.notes.append("modello d'impaginazione non disponibile: nessun innesto")
            return unchanged
        }
        let source = HeronVerdictSource(analyzer: PageStructureAnalyzer(model: model), pdf: pdf)
        for (k, p) in modelPages.enumerated() {
            if isCancelled() { return nil }
            _ = source.items(page: p)
            onPage(k + 1, modelPages.count)
        }
        let verdicts: FusoreVerdicts = { source.items(page: $0) }

        // 3. Livello d'estrazione: ricucitura delle note che scavalcano la pagina, poi ricostruzione del documento.
        var ex = extraction
        var doc = rawDocument
        if !pairs.isEmpty {
            guard let out = Fusore.fuseExtraction(ex, phenomena: [.multipageStitch(pairs: pairs)], verdicts: verdicts) else {
                report.fidelityBroken = true
                report.notes.append("rete di fedeltà rotta sulla ricucitura: nessun innesto")
                return unchanged
            }
            let stitches = out.operations.compactMap { op -> [Int]? in
                if case .stitchMultipage(let a, let b, _, _) = op { return [a, b] }
                return nil
            }
            report.stitches = stitches
            if !stitches.isEmpty {
                ex = out.value
                guard let rebuilt = buildDocumentFromPdf(ex, sourceName: sourceName, onPageClassified: { _, _ in },
                                                         isCancelled: isCancelled) else { return nil }
                doc = rebuilt
            }
        }

        // 4. Livello di nodo: indice analitico senza note per il modello → corpo.
        if !indexPages.isEmpty {
            guard let out = Fusore.fuseDocument(doc, phenomena: [.sectorRelabelNoFootnote(pages: indexPages)], verdicts: verdicts) else {
                report.fidelityBroken = true
                report.notes.append("rete di fedeltà rotta sulla rietichettatura: nessuna rietichettatura")
                return ChainGraftOutput(extraction: ex, rawDocument: doc, report: summary())
            }
            doc = out.value
            report.relabels = out.operations.count
            var pages = Set<Int>()
            for op in out.operations {
                if case .relabel(let node, _, _, let reason) = op {
                    report.relabelNodes.append(node)
                    if let n = Int(reason.split(separator: ".").last ?? "") { pages.insert(n) }
                }
            }
            report.relabelPages = pages.sorted()
        }
        return ChainGraftOutput(extraction: ex, rawDocument: doc, report: summary())
    }

    /// Il referto in righe brevi, prive di testo.
    func summary() -> [String] {
        var out = [
            "pagine dell'indice analitico con note: \(report.indexPages.count)",
            "coppie candidate alla ricucitura: \(report.multipageCandidates.count)",
            "pagine mandate al modello: \(report.modelPages.count)",
            "note ricucite fra due pagine: \(report.stitches.count)",
            "nodi dell'indice rietichettati come corpo: \(report.relabels) su \(report.relabelPages.count) pagine",
        ]
        out += report.notes
        return out
    }
}
