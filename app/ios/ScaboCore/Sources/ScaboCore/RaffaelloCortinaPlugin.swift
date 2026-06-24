//
//  RaffaelloCortinaPlugin.swift
//  ScaboCore
//
//  Corpus plugin per la collana "Saggi" di Raffaello Cortina Editore (campioni di
//  calibrazione: "Delitti in prima pagina" e "Pubblico ministero" di Bruti Liberati).
//
//  ── Perché un plugin dedicato e non il Generic ───────────────────────────────────
//
//  Questi saggi compongono i SOTTO-TITOLI DI SEZIONE in maiuscoletto PIÙ PICCOLO del
//  corpo (rapporto ≈0.80). Il classificatore generico è puramente dimensionale (una
//  riga < 0.85×corpo è NOTA), quindi li manda tutti in NOTA: non diventano mai un
//  confine di lettura e le note lunghe, che `bindAndPlaceNotes` scarica «prima del
//  prossimo HEADING», finiscono a fine CAPITOLO — decine di pagine dal richiamo.
//
//  L'indagine dati-alla-mano (docs di sessione) ha stabilito, con la rete di
//  non-regressione cross-volume su ~24 volumi, che un riconoscitore di sotto-titoli
//  NON può vivere nel Generic senza cambiare la classificazione di altri volumi: il
//  segnale tipografico (maiuscoletto piccolo) e il pattern di numerazione promuovono
//  a titolo righe legittime di altri corpora — titoli-capitolo maiuscoli (Torrente
//  "CAPITOLO II"), titoli-paragrafo numerati (Costituzionale "1. CHE COS'È IL
//  DIRITTO?"), voci d'elenco/citazioni/sentenze numerate (Tesauro, Nomofanie, Il
//  mercato finanziario). La condizione del maintainer è ZERO regressione altrove;
//  quindi il riconoscitore vive QUI, recintato dalla famiglia editoriale, e il
//  Generic resta intatto byte-per-byte.
//
//  ── La porta (`matches`) ─────────────────────────────────────────────────────────
//
//  La collana "Saggi" ha una firma univoca nel corpus di calibrazione: il formato
//  tascabile ≈453×694 pt (nessun altro volume lo ha — Mosconi 457×684, i manuali
//  482×680, le monografie 595×842), il nero "ricco" #231f20 (non #000000), e la
//  presenza di sotto-titoli in maiuscoletto piccolo nel flusso del corpo. La porta
//  è GATED sul formato (necessario): nessun volume non-Cortina supera la soglia 0.6,
//  con ampio margine (Delitti/PM = 1.00; tutti gli altri = 0.00). Se la geometria
//  on-device differisse oltre la tolleranza, la porta fallisce in sicurezza (→
//  Generic, nessuna regressione, nessun fix — mai un falso positivo altrove).
//
//  ── Il riconoscitore (`build`) ─────────────────────────────────────────────────
//
//  Identico al Generic in tutto, tranne un solo passo: una `run` di righe a taglia-
//  nota nel flusso del corpo (non nelle fasce testatina/piè, non apparato), tutta in
//  MAIUSCOLO (caps ≥ 0.85) e CORTA in larghezza (< 0.85 della colonna), è promossa a
//  HEADING_4. Dentro Cortina la precisione è ~100% (verificata su entrambi i volumi:
//  41 sezioni su Delitti, 15 su Pubblico ministero, zero righe di corpo/nota/
//  citazione promosse per errore). L'ISOLAMENTO verticale NON è richiesto: serviva
//  solo come guardia anti-falso-positivo cross-volume nel Generic; qui la porta
//  editoriale È la guardia, e i sotto-titoli di Pubblico ministero non sono isolati
//  (gap ≈0.8) — richiederlo perderebbe metà delle sezioni. La numerazione iniziale
//  ("6. STRATEGIE…") NON squalifica: il maiuscoletto già esclude le note (che sono a
//  caso misto). I sotto-titoli multi-riga sono già una sola `run` (righe consecutive
//  a taglia-nota) → un solo nodo HEADING_4 col testo unito.
//
//  ── Le reti ────────────────────────────────────────────────────────────────────
//
//  Rete A (nessuna perdita di contenuto): un sotto-titolo promosso resta un nodo
//  letto, cambia solo ruolo (NOTA→HEADING_4) e diventa confine; nessun testo sparisce.
//  Rete B (tutto il già-fatto invariato): l'emissione è byte-identica al Generic per
//  ogni item non promosso; il conteggio e l'ordine dei nodi per pagina coincidono con
//  `pageItems`, quindi lo zip 1:1 di `bindAndPlaceNotes` resta allineato. Una run-nota
//  promossa è vista da NoteBinding come `.run(.note)` ⇄ nodo HEADING_4: la guardia
//  `node.type == .NOTE` la salta (nessun aggancio nota, corretto: non era una nota) e
//  il ramo HEADING fa scattare `flushLong()` — cioè il piazzamento note ora scarica al
//  sotto-titolo vicino. NoteBinding NON va toccato.
//

import Foundation

// MARK: - Costanti calibrate (campioni Delitti + Pubblico ministero)

/// Formato tascabile della collana "Saggi" (pt). Univoco nel corpus di calibrazione.
let CORTINA_TRIM_WIDTH = 453.0
let CORTINA_TRIM_HEIGHT = 694.0
/// Tolleranza sul formato (pt). Stretta abbastanza da escludere 457×684 (Mosconi/
/// Tesauro) via l'altezza, generosa abbastanza per la deriva dell'estrattore.
let CORTINA_TRIM_TOLERANCE = 8.0
/// Il nero "ricco" della collana (non #000000): conferma, non discrimina da solo.
let CORTINA_BODY_COLOR = "#231f20"
/// Densità minima di righe-sezione maiuscole per pagina (scan) per confermare la collana.
let CORTINA_CAPS_DENSITY_MIN = 0.05
/// Una riga di sezione è in maiuscolo se almeno questa frazione di lettere è maiuscola.
let CORTINA_SUBTITLE_CAPS_MIN = 0.85
/// Un sotto-titolo è una riga CORTA: la sua larghezza massima sta sotto questa frazione
/// della colonna del corpo (non è una riga giustificata piena).
let CORTINA_SUBTITLE_MAX_WIDTH_FRACTION = 0.85
/// Flusso del corpo: frazione-dall-alto entro cui un sotto-titolo può stare (esclude
/// la fascia testatina in alto e l'apparato di piè in basso).
let CORTINA_BODY_FLOW_TOP = 0.12
let CORTINA_BODY_FLOW_BOTTOM = 0.80

// MARK: - Il plugin

public final class RaffaelloCortinaPlugin: ExtractionPlugin {
    public let id = "raffaello_cortina"
    public let label = "Raffaello Cortina (Saggi)"

    // MARK: matches

    public func matches(_ extraction: PdfExtraction) -> Double {
        let (width, height) = Self.dominantPageSize(extraction)
        // Porta: formato tascabile "Saggi" (necessario). Nessun volume non-Cortina lo
        // ha → score 0 e dispatch al Generic, invariato.
        guard abs(width - CORTINA_TRIM_WIDTH) <= CORTINA_TRIM_TOLERANCE,
              abs(height - CORTINA_TRIM_HEIGHT) <= CORTINA_TRIM_TOLERANCE else { return 0.0 }
        var score = 0.5
        let (capsDensity, dominantColor) = Self.scanSignals(extraction)
        if capsDensity >= CORTINA_CAPS_DENSITY_MIN { score += 0.4 }
        if dominantColor == CORTINA_BODY_COLOR { score += 0.1 }
        return score
    }

    // MARK: build

    public func build(_ extraction: PdfExtraction, sourceName: String) -> ScabopdfDocument {
        let profile = estimateProfile(extraction)
        let furniture = detectFurniture(extraction)
        let fmMax = frontMatterRegionLimit(extraction.pageCount)
        let apparatus = detectApparatus(extraction, furniture)
        var nodes: [NodeDict] = []
        var counter = 0
        func nextId() -> String { defer { counter += 1 }; return "node_\(counter)" }
        var promoted = 0
        for page in extraction.pages {
            promoted += emitPageNodes(page, profile, furniture, fmMax, apparatus, &nodes, nextId)
        }
        return assembleDocument(
            extraction, sourceName: sourceName, nodes: nodes, profile: profile,
            furnitureCount: furniture.count, promotedSubtitles: promoted)
    }

    public func build(
        _ extraction: PdfExtraction,
        sourceName: String,
        onPageClassified: (_ done: Int, _ total: Int) -> Void,
        isCancelled: () -> Bool
    ) -> ScabopdfDocument? {
        if isCancelled() { return nil }
        let profile = estimateProfile(extraction)
        if isCancelled() { return nil }
        let furniture = detectFurniture(extraction)
        if isCancelled() { return nil }
        let apparatus = detectApparatus(extraction, furniture)
        if isCancelled() { return nil }
        let fmMax = frontMatterRegionLimit(extraction.pageCount)
        var nodes: [NodeDict] = []
        var counter = 0
        func nextId() -> String { defer { counter += 1 }; return "node_\(counter)" }
        var promoted = 0
        let total = extraction.pages.count
        for (index, page) in extraction.pages.enumerated() {
            if isCancelled() { return nil }
            promoted += emitPageNodes(page, profile, furniture, fmMax, apparatus, &nodes, nextId)
            onPageClassified(index + 1, total)
        }
        if isCancelled() { return nil }
        return assembleDocument(
            extraction, sourceName: sourceName, nodes: nodes, profile: profile,
            furnitureCount: furniture.count, promotedSubtitles: promoted)
    }

    // MARK: - Emissione dei nodi di una pagina (Generic + promozione sotto-titoli)

    /// Emette i nodi di una pagina da `pageItems` (la STESSA itemizzazione del Generic,
    /// stesso profilo/furniture/apparato → zip 1:1 con NoteBinding preservato). L'unica
    /// differenza dal Generic: una run a taglia-nota riconosciuta come sotto-titolo di
    /// sezione (`isSectionSubtitle`) è emessa come HEADING_4 invece che NOTE. Ritorna il
    /// numero di sotto-titoli promossi (per il warning diagnostico).
    private func emitPageNodes(
        _ page: PdfPageExtraction,
        _ profile: Profile,
        _ furniture: Set<String>,
        _ frontMatterMaxPage: Int,
        _ apparatus: [Int: SemanticCategory],
        _ out: inout [NodeDict],
        _ nextId: () -> String
    ) -> Int {
        let items = pageItems(page, profile, furniture, frontMatterMaxPage, apparatus)
        let colWidth = Self.bodyColumnWidth(page, bodySize: profile.bodySize)
        var promoted = 0
        for item in items {
            switch item {
            case .heading(let sm, let level):
                out.append(NodeDict(
                    id: nextId(), type: headingCategory(level),
                    page_index: page.pageIndex, text: sm.text, level: level))
            case .run(let role, let lines):
                if role == .note,
                   isSectionSubtitle(lines, pageHeight: page.height, columnWidth: colWidth) {
                    out.append(NodeDict(
                        id: nextId(), type: .HEADING_4, page_index: page.pageIndex,
                        text: joinLines(lines.map { $0.text }), level: 4))
                    promoted += 1
                } else {
                    let text = joinLines(lines.map { $0.text })
                    let category: SemanticCategory
                    switch role {
                    case .body: category = .BODY
                    case .note: category = .NOTE
                    case .gloss: category = .MARGINAL_GLOSS
                    }
                    var node = NodeDict(
                        id: nextId(), type: category, page_index: page.pageIndex, text: text)
                    if role == .note { node.length_category = lengthCategoryFor(text) }
                    out.append(node)
                }
            case .apparatus(let category, let lines):
                out.append(NodeDict(
                    id: nextId(), type: category, page_index: page.pageIndex,
                    text: joinLines(lines.map { $0.text })))
            }
        }
        return promoted
    }

    /// Vero se una run a taglia-nota è un sotto-titolo di sezione Cortina: tutto in
    /// maiuscolo (≥ CORTINA_SUBTITLE_CAPS_MIN), nel flusso del corpo (fuori dalle fasce
    /// testatina/piè), corto in larghezza (< CORTINA_SUBTITLE_MAX_WIDTH_FRACTION della
    /// colonna), con lettere vere. Nessun requisito di isolamento (vedi testata).
    func isSectionSubtitle(_ lines: [LineSummary], pageHeight: Double, columnWidth: Double) -> Bool {
        guard let first = lines.first else { return false }
        let text = joinLines(lines.map { $0.text })
        guard isSubstantial(text), capsRatioCortina(text) >= CORTINA_SUBTITLE_CAPS_MIN else { return false }
        // Fascia di flusso del corpo (origine in basso-sinistra: yTop grande = alto in pagina).
        let yFracTop = pageHeight > 0 ? (pageHeight - first.yTop) / pageHeight : 0.5
        guard yFracTop > CORTINA_BODY_FLOW_TOP, yFracTop < CORTINA_BODY_FLOW_BOTTOM else { return false }
        let maxWidth = lines.map { $0.width }.max() ?? 0
        guard columnWidth > 0, maxWidth < CORTINA_SUBTITLE_MAX_WIDTH_FRACTION * columnWidth else { return false }
        return true
    }

    // MARK: - Assemblaggio documento

    private func assembleDocument(
        _ extraction: PdfExtraction,
        sourceName: String,
        nodes: [NodeDict],
        profile: Profile,
        furnitureCount: Int,
        promotedSubtitles: Int
    ) -> ScabopdfDocument {
        var warnings = [
            "plugin:raffaello_cortina:heuristic_extraction_pages_\(extraction.pageCount)_nodes_\(nodes.count)",
        ]
        if profile.bodySize == 0 {
            warnings.append("plugin:raffaello_cortina:no_font_information_all_body")
        }
        if furnitureCount > 0 {
            warnings.append("plugin:raffaello_cortina:furniture_lines_removed_\(furnitureCount)")
        }
        if promotedSubtitles > 0 {
            warnings.append("plugin:raffaello_cortina:section_subtitles_promoted_\(promotedSubtitles)")
        }
        let glossCount = nodes.reduce(0) { $0 + ($1.type == .MARGINAL_GLOSS ? 1 : 0) }
        if glossCount > 0 {
            warnings.append("plugin:raffaello_cortina:lateral_glosses_\(glossCount)")
        }
        let stampCount = nodes.reduce(0) { $0 + ($1.type == .ARTIFACT_STAMP ? 1 : 0) }
        let tocCount = nodes.reduce(0) { $0 + ($1.type == .TOC_GENERAL ? 1 : 0) }
        let indexCount = nodes.reduce(0) { $0 + ($1.type == .INDEX_ENTRY ? 1 : 0) }
        if stampCount + tocCount + indexCount > 0 {
            warnings.append(
                "plugin:raffaello_cortina:apparatus_stamp_\(stampCount)_toc_\(tocCount)_index_\(indexCount)")
        }
        return ScabopdfDocument(
            schema_version: SUPPORTED_SCHEMA_VERSION,
            document_id: slug(sourceName),
            metadata: DocumentMetadata(
                pages_pdf: extraction.pageCount,
                page_size_pt: [0, 0],
                source_pdf_filename: sourceName
            ),
            profile: DocumentProfileDict(
                profile_id: "raffaello_cortina",
                editorial_family: "raffaello_cortina",
                genre: "saggio",
                confidence: matches(extraction)
            ),
            warnings: warnings,
            transformations: [],
            structure: nodes
        )
    }

    // MARK: - Helper di firma (matches)

    /// Il formato di pagina più frequente nel documento (pt), arrotondato.
    static func dominantPageSize(_ extraction: PdfExtraction) -> (Double, Double) {
        var counts: [String: (count: Int, w: Double, h: Double)] = [:]
        for page in extraction.pages {
            let key = "\(Int(page.width.rounded()))x\(Int(page.height.rounded()))"
            let cur = counts[key] ?? (0, page.width, page.height)
            counts[key] = (cur.count + 1, page.width, page.height)
        }
        var best = (count: 0, w: 0.0, h: 0.0)
        for (_, v) in counts where v.count > best.count { best = v }
        return (best.w, best.h)
    }

    /// Scansiona una fetta centrale del documento e ritorna la densità di righe-sezione
    /// maiuscole (per pagina) e il colore dominante (per caratteri).
    static func scanSignals(_ extraction: PdfExtraction) -> (capsDensity: Double, dominantColor: String) {
        let body = estimateProfile(extraction).bodySize
        let n = extraction.pages.count
        let lo = max(8, Int(Double(n) * 0.10))
        let hi = min(n, lo + 80)
        guard lo < hi else { return (0, "#000000") }
        var capsLines = 0
        var pagesScanned = 0
        var colorChars: [String: Int] = [:]
        var colorOrder: [String] = []
        for index in lo..<hi {
            let page = extraction.pages[index]
            pagesScanned += 1
            let ph = page.height
            for line in page.lines {
                let sm = summarizeLine(line)
                if colorChars[sm.color] == nil { colorOrder.append(sm.color) }
                colorChars[sm.color, default: 0] += sm.text.utf16.count
                guard body > 0, sm.fontSize > 0 else { continue }
                let ratio = sm.fontSize / body
                let yFracTop = ph > 0 ? (ph - sm.yTop) / ph : 0.5
                if ratio > 0.55, ratio <= 0.86,
                   capsRatioCortina(sm.text) >= CORTINA_SUBTITLE_CAPS_MIN, isSubstantial(sm.text),
                   yFracTop > CORTINA_BODY_FLOW_TOP, yFracTop < CORTINA_BODY_FLOW_BOTTOM {
                    capsLines += 1
                }
            }
        }
        var color = "#000000"
        var bestChars = -1
        for c in colorOrder where colorChars[c]! > bestChars {
            bestChars = colorChars[c]!
            color = c
        }
        let density = pagesScanned > 0 ? Double(capsLines) / Double(pagesScanned) : 0
        return (density, color)
    }

    /// Larghezza della colonna del corpo di una pagina: 80° percentile delle larghezze
    /// delle righe alla taglia del corpo (fallback 0.6×pagina se non stimabile).
    static func bodyColumnWidth(_ page: PdfPageExtraction, bodySize: Double) -> Double {
        var widths: [Double] = []
        for line in page.lines {
            let sm = summarizeLine(line)
            if bodySize > 0, abs(sm.fontSize - bodySize) <= 0.7 { widths.append(sm.width) }
        }
        guard !widths.isEmpty else { return page.width * 0.6 }
        widths.sort()
        return widths[min(widths.count - 1, Int(Double(widths.count) * 0.8))]
    }
}

/// Il singleton del plugin (l'identità conta per il dispatcher `===`).
public let raffaelloCortinaPlugin = RaffaelloCortinaPlugin()

// MARK: - Helper liberi

/// Categoria HEADING per livello (gemello del privato `headingCategory` del Generic).
private func headingCategory(_ level: Int) -> SemanticCategory {
    switch level {
    case 1: return .HEADING_1
    case 2: return .HEADING_2
    case 3: return .HEADING_3
    default: return .HEADING_4
    }
}

/// Frazione di lettere maiuscole nel testo (ASCII A–Z più maiuscole Latin-1 U+00C0…U+00DE
/// escluso U+00D7 ×). Mirror della misura `caps` usata nell'indagine.
func capsRatioCortina(_ text: String) -> Double {
    var letters = 0
    var upper = 0
    for scalar in text.unicodeScalars {
        let v = scalar.value
        let isLetter = (v >= 0x41 && v <= 0x5A) || (v >= 0x61 && v <= 0x7A) || (v >= 0xC0 && v <= 0xFF)
        guard isLetter else { continue }
        letters += 1
        if (v >= 0x41 && v <= 0x5A) || (v >= 0xC0 && v <= 0xDE && v != 0xD7) { upper += 1 }
    }
    return letters > 0 ? Double(upper) / Double(letters) : 0
}
