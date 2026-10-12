//
//  VisualResources.swift
//  ScaboCore
//
//  LE RISORSE VISIVE NELLA LETTURA (`LAYER2_PRODUCT_DECISIONS.md` § 7.9, resa concreta il 2026-10-12, e il
//  vincolo di prodotto dello stesso giro: NESSUN TESTO PUÒ DIVENTARE IRRAGGIUNGIBILE).
//
//  Il modello d'impaginazione (modulo `ScaboPageStructure`, che ScaboCore NON importa) propone regioni
//  «tabella» e «figura» per pagina. Qui, puro e provabile sull'host:
//
//  1. la GUARDIA deterministica sopra il modello (come la guardia-marcatore del banco): una regione che
//     contiene richiami o marcatori di nota, o che coincide con testo che l'app ha già classificato con
//     certezza (titoli, articoli, indici, sommari, note vere, …), NON diventa risorsa visiva; nemmeno una
//     regione che copre quasi tutta la pagina;
//  2. l'INSERIMENTO nel flusso di lettura di UN elemento in più per ogni risorsa accettata, annunciato come
//     tale («Risorsa visiva. Tabella: <didascalia>»), subito prima del testo che la regione contiene (o, per
//     una figura senza testo, al suo posto nell'ordine di lettura della pagina).
//
//  LA FORMA SCELTA PER IL VINCOLO «nessun testo irraggiungibile»: l'elemento è ADDITIVO. Il testo della
//  regione resta nel flusso esattamente dov'era e com'era, raggiungibile con lo swipe come prima; l'elemento
//  porta l'annuncio, l'azione «Estrai come immagine» e, se la regione contiene testo, l'azione «Salta la
//  risorsa» per chi non vuole ascoltarlo. È la forma più coerente con lo swipe integrale (§ 2.2): nulla esce
//  dal container del testo, nessun contenuto si nasconde dietro un'azione, e se il modello sbaglia il costo è
//  un annuncio in più, mai una parola persa. Le lettere e le cifre del flusso, tolti questi elementi, restano
//  identiche: è la rete del giro.
//
//  Il ruolo `VISUAL_RESOURCE` è un ruolo di PRESENTAZIONE del Layer 2 (come `SECTION_DIVIDER`): non è una
//  categoria del contratto del Layer 1 (schema 0.7.0 invariato) e non esiste nei documenti, solo nei segmenti.
//

import Foundation

/// Il ruolo di presentazione dell'elemento «risorsa visiva» nel flusso di lettura.
public let VISUAL_RESOURCE_ROLE = "VISUAL_RESOURCE"

/// Il tipo di risorsa visiva, nelle parole dell'app.
public enum VisualResourceKind: String, Codable, Sendable {
    case table, figure

    /// La parola pronunciata e mostrata.
    public var word: String { self == .table ? "Tabella" : "Figura" }
}

/// Una regione proposta dal modello d'impaginazione, ridotta a dati semplici (nessun testo).
public struct VisualRegionCandidate: Codable, Equatable, Sendable {
    /// Pagina (0-based) del file.
    public var pageIndex: Int
    /// Etichetta di docling: `table` o `picture` (altre etichette vengono scartate dalla guardia).
    public var label: String
    /// `[l, t, r, b]` in punti, origine alto-sinistra, relativa al cropBox.
    public var bbox: [Double]
    public var confidence: Double
    /// Riquadro della didascalia che docling associa alla regione, se c'è.
    public var captionBBox: [Double]?
    /// Dimensioni del cropBox della pagina in punti.
    public var pageWidth: Double
    public var pageHeight: Double
    /// Riquadri delle regioni di testo che il modello legge subito prima e subito dopo questa, nell'ordine di
    /// lettura della pagina: servono a collocare una figura che non contiene testo.
    public var previousTextBBox: [Double]?
    public var nextTextBBox: [Double]?
    /// Quanti oggetti DIPINTI (filetti, rettangoli, tracciati, immagini; esclusi gli sfondi a tutta pagina)
    /// toccano la regione, secondo la sonda grafica della pagina. `nil` = non misurato (la regola che lo usa
    /// allora non si applica).
    public var graphicsInside: Int?

    public init(pageIndex: Int, label: String, bbox: [Double], confidence: Double, captionBBox: [Double]? = nil,
                pageWidth: Double, pageHeight: Double, previousTextBBox: [Double]? = nil, nextTextBBox: [Double]? = nil,
                graphicsInside: Int? = nil) {
        self.pageIndex = pageIndex; self.label = label; self.bbox = bbox; self.confidence = confidence
        self.captionBBox = captionBBox; self.pageWidth = pageWidth; self.pageHeight = pageHeight
        self.previousTextBBox = previousTextBBox; self.nextTextBBox = nextTextBBox; self.graphicsInside = graphicsInside
    }
}

/// Ciò che il segmento di una risorsa visiva porta con sé (in cache, campo additivo): quanto basta per il
/// ritaglio e per «Salta la risorsa». Nessun testo.
public struct VisualResourcePayload: Codable, Equatable, Sendable {
    public var kind: VisualResourceKind
    /// Pagina (0-based) e riquadro `[l, t, r, b]` (punti, alto-sinistra, cropBox) da ritagliare.
    public var pageIndex: Int
    public var bbox: [Double]
    /// Quanti elementi, subito dopo questo, portano il testo della regione (0 per una figura senza testo).
    public var containedElements: Int

    public init(kind: VisualResourceKind, pageIndex: Int, bbox: [Double], containedElements: Int) {
        self.kind = kind; self.pageIndex = pageIndex; self.bbox = bbox; self.containedElements = containedElements
    }
}

/// Esito della guardia per una regione.
public enum VisualGuardOutcome: String, Codable, Sendable {
    /// Diventa risorsa visiva.
    case accepted
    /// Etichetta diversa da tabella o figura.
    case notVisualLabel
    /// Copre quasi tutta la pagina: non è una risorsa ma la pagina (e non si ritaglierebbe mai).
    case wholePage
    /// Contiene richiami o marcatori di nota.
    case noteMarkers
    /// Coincide con testo che l'app ha già classificato con certezza.
    case certainBlock
    /// Duplicato: si sovrappone a una regione già accettata sulla stessa pagina.
    case duplicate
    /// Ricorre nella stessa posizione su più pagine del documento (logo, fregio, testata grafica): arredo.
    case recurring
    /// Figura piccola (sotto il 5 % della pagina): logo, marchio, bollo, fregio, icona.
    case ornament
    /// Figura sulla copertina o sulle ultime due pagine di un volume (quarta, pubblicità dell'editore).
    case cover
    /// Figura attraversata da righe di testo che escono dal suo riquadro: è testo, non un'immagine.
    case insideText
    /// La regione contiene testo che l'app non legge per scelta (indice, sommario, glosse, colophon, testatine):
    /// è apparato già riconosciuto, non una risorsa.
    case unreadText
    /// «Tabella» fatta di sole colonne di testo, senza alcun disegno (né filetti, né riquadri, né immagini):
    /// è un elenco disposto in colonne (abbreviazioni, indice), che si legge bene in linea.
    case plainText
}

/// Decisione su una regione (per il referto e per le reti; nessun testo).
public struct VisualResourceDecision: Codable, Equatable, Sendable {
    public var candidate: VisualRegionCandidate
    public var outcome: VisualGuardOutcome
    /// Righe dell'estrazione contenute nella regione, e quante di queste ritrovate nel flusso.
    public var containedLines: Int
    public var matchedLines: Int
    /// Indice dell'elemento inserito nel flusso finale, se accettata.
    public var insertedAt: Int?
    public var containedElements: Int
    /// Ruoli dei segmenti che portano il testo della regione (solo diagnostica).
    public var coveredRoles: [String: Int]
}

/// Il riepilogo di un documento.
public struct VisualResourcesReport: Codable, Equatable, Sendable {
    public var decisions: [VisualResourceDecision]
    public var acceptedTables: Int { decisions.filter { $0.outcome == .accepted && $0.candidate.label == "table" }.count }
    public var acceptedFigures: Int { decisions.filter { $0.outcome == .accepted && $0.candidate.label == "picture" }.count }
    public init(decisions: [VisualResourceDecision] = []) { self.decisions = decisions }
}

// MARK: - Costanti della guardia

/// Oltre questa frazione della pagina una regione è la pagina (stessa soglia del ritaglio).
let VISUAL_MAX_PAGE_FRACTION = 0.85
/// Lunghezza minima (lettere e cifre) di una riga perché la si cerchi nel flusso: sotto, i riscontri sono
/// ambigui (numeri di cella, sigle).
let VISUAL_MIN_MATCH_CHARS = 6
/// Ruoli che l'app assegna con CERTEZZA (segnali forti, deterministici): se il testo della regione è per la
/// maggior parte in questi ruoli, la regione «coincide con un blocco già classificato» e non diventa risorsa.
/// BODY e UNCLASSIFIED no (sono il ruolo di ripiego, dove finiscono proprio tabelle e figure); NOTE no a
/// meno che il segmento non apra con un marcatore (la nota «muta» di una tabella a corpo ridotto non è certa).
let VISUAL_CERTAIN_ROLES: Set<String> = [
    "HEADING_1", "HEADING_2", "HEADING_3", "HEADING_4", "ARTICLE_HEADER", "ARTICLE_BODY", "PROCEDURAL",
    "TOC_GENERAL", "INDEX_ENTRY", "CHAPTER_SUMMARY", "LETTERATURA", "FONTI", "MARGINAL_GLOSS", "MARGINAL_HEADING",
    "EDITORIAL_NOTE", "MASSIMA_LABEL", "REFERRAL", "TITLE", "FONTE_LABEL", "FONTE_VALUE", "META_LABEL", "META_VALUE",
    "AUTHORS", "SECTION_LABEL", "GENRE_BANNER", "SUBTITLE", "AMENDMENT", "QUOTED_TEXT_OLD", "QUOTED_TEXT_NEW",
    "UPDATE_BLOCK", "SECTION_DIVIDER", "LIST_ITEM",
]
/// Sotto questa frazione della pagina una FIGURA è un logo, un bollo o un fregio. Misurata sul corpus del giro
/// (52 volumi, giudizio contro la pagina): fra le figure accettate dalle altre regole, nessuna figura vera sotto il
/// 5 %, e sotto il 5 % solo marchi editoriali, bolli della carta, fregi, riquadri su parole e su zone bianche.
/// Le TABELLE non hanno soglia: una tabella vera può essere una riga sola.
let VISUAL_MIN_FIGURE_FRACTION = 0.05
/// Nei volumi da almeno tante pagine, la prima pagina e le ultime due sono copertina, quarta e pubblicità.
let VISUAL_COVER_MIN_PAGES = 20
/// Una regione che ricorre nella stessa posizione (IoU ≥ 0,8) su almeno tante pagine del documento è arredo
/// della pagina (logo, testata grafica, fregio), non una risorsa.
let VISUAL_RECURRENCE_PAGES = 3
/// Simboli di richiamo usati come apici.
private let CALLOUT_SYMBOLS: Set<Character> = ["*", "†", "‡", "§", "¶"]

// MARK: - Geometria

/// Riquadro `[l, t, r, b]` (alto-sinistra) di una riga dell'estrazione (basso-sinistra, cropBox).
func topLeftBox(_ b: BBox, pageHeight H: Double) -> [Double] {
    [b.x, H - (b.y + b.height), b.x + b.width, H - b.y]
}

/// Vero se il centro della riga cade nella regione (con una tolleranza di un punto).
func lineCenterInside(_ line: [Double], _ region: [Double], tolerance: Double = 1) -> Bool {
    let cx = (line[0] + line[2]) / 2, cy = (line[1] + line[3]) / 2
    return cx >= region[0] - tolerance && cx <= region[2] + tolerance && cy >= region[1] - tolerance && cy <= region[3] + tolerance
}

private func area(_ b: [Double]) -> Double { max(0, b[2] - b[0]) * max(0, b[3] - b[1]) }

/// Vero se una riga di testo ATTRAVERSA la regione: le si sovrappone per almeno metà della propria altezza e
/// per almeno un terzo della larghezza della regione, ed esce dal suo riquadro di oltre 10 punti a destra o a
/// sinistra. È il segno di un riquadro disegnato su parole del corpo, non di un'immagine.
func lineCrossesRegion(_ line: [Double], _ region: [Double]) -> Bool {
    let h = line[3] - line[1]
    guard h > 0 else { return false }
    let ov = min(line[3], region[3]) - max(line[1], region[1])
    let ow = min(line[2], region[2]) - max(line[0], region[0])
    guard ov >= 0.5 * h, ow >= (region[2] - region[0]) / 3 else { return false }
    return line[0] < region[0] - 10 || line[2] > region[2] + 10
}
private func iou(_ a: [Double], _ b: [Double]) -> Double {
    let i = intersection(a, b); let u = area(a) + area(b) - i
    return u > 0 ? i / u : 0
}

/// Indici delle FIGURE che ricorrono nella stessa posizione su almeno `VISUAL_RECURRENCE_PAGES` pagine. Le tabelle
/// no: una tabella che continua per più pagine, o una serie di tabelle impaginate allo stesso modo, ricorre di
/// proposito (misurato: le tabelle dei parametri forensi dei codici, l'appendice della Rivista DPC).
func recurringCandidateIndices(_ candidates: [VisualRegionCandidate]) -> Set<Int> {
    var out = Set<Int>()
    for (i, a) in candidates.enumerated() where a.bbox.count == 4 && a.label == "picture" {
        var pages = Set([a.pageIndex])
        for b in candidates where b.label == "picture" && b.pageIndex != a.pageIndex && b.bbox.count == 4 && iou(a.bbox, b.bbox) >= 0.8 {
            pages.insert(b.pageIndex)
            if pages.count >= VISUAL_RECURRENCE_PAGES { break }
        }
        if pages.count >= VISUAL_RECURRENCE_PAGES { out.insert(i) }
    }
    return out
}
private func intersection(_ a: [Double], _ b: [Double]) -> Double {
    let w = min(a[2], b[2]) - max(a[0], b[0]), h = min(a[3], b[3]) - max(a[1], b[1])
    return w > 0 && h > 0 ? w * h : 0
}

// MARK: - Richiami e marcatori di nota

/// Vero se la riga porta un richiamo o un marcatore di nota: apre con un marcatore (numero, «(N)», simbolo),
/// oppure contiene un apice numerico o un simbolo di richiamo a corpo ridotto, oppure «(N)» a corpo di testo.
func lineCarriesNoteMarker(_ line: PdfTextLine, bodySize: Double) -> Bool {
    let sm = summarizeLine(line)
    if textOpensWithNoteMarker(sm.text) { return true }
    if bodySize > 0 {
        if !detectInlineMarkers([sm], body: bodySize).isEmpty { return true }
        for span in line.spans {
            let t = span.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty, t.count <= 3, t.allSatisfy({ CALLOUT_SYMBOLS.contains($0) }),
               span.fontSize > 0, span.fontSize < MARKER_MAX_SIZE_RATIO * bodySize { return true }
        }
    }
    return false
}

// MARK: - Indice del flusso

/// Indice di ricerca sul flusso: testo normalizzato (lettere e cifre minuscole) e pagina d'origine.
struct FlowIndex {
    let normalized: [String]
    let byPage: [Int: [Int]]

    init(_ segments: [ContentSegment]) {
        normalized = segments.map { TextFingerprint.normalize($0.text) }
        var bp: [Int: [Int]] = [:]
        for (i, s) in segments.enumerated() { if let p = s.sourcePage { bp[p, default: []].append(i) } }
        byPage = bp
    }

    /// L'indice del primo segmento, fra quelli che cominciano sulla pagina `page1` (1-based) o su quella prima,
    /// il cui testo contiene la riga. `nil` se la riga è troppo corta o non si ritrova.
    func segmentContaining(_ lineText: String, page1: Int) -> Int? {
        let n = TextFingerprint.normalize(lineText)
        guard n.count >= VISUAL_MIN_MATCH_CHARS else { return nil }
        for p in [page1, page1 - 1] {
            for i in byPage[p] ?? [] where normalized[i].contains(n) { return i }
        }
        return nil
    }

    /// Il primo segmento che comincia su questa pagina o dopo (per collocare una figura senza testo).
    func firstSegment(onOrAfter page1: Int, count: Int) -> Int? {
        let pages = byPage.keys.filter { $0 >= page1 }.sorted()
        return pages.first.flatMap { byPage[$0]?.first }
    }
}

// MARK: - Guardia + inserimento

/// Valuta le regioni proposte dal modello e inserisce nel flusso un elemento per ciascuna risorsa accettata.
/// `segments` è il flusso finale (granularizzato) della Lettura Continua o della Dottrina Inline; `extraction`
/// è l'estrazione da cui è nato. Puro: stesso ingresso, stessa uscita.
public func insertingVisualResources(
    _ segments: [ContentSegment],
    candidates: [VisualRegionCandidate],
    extraction: PdfExtraction
) -> (segments: [ContentSegment], report: VisualResourcesReport) {
    guard !candidates.isEmpty, !segments.isEmpty else { return (segments, VisualResourcesReport()) }
    let bodySize = estimateProfile(extraction).bodySize
    let flow = FlowIndex(segments)
    var pages: [Int: PdfPageExtraction] = [:]
    for p in extraction.pages { pages[p.pageIndex] = p }

    struct Pending { var at: Int; var order: Int; var segment: ContentSegment }
    var pending: [Pending] = []
    var decisions: [VisualResourceDecision] = []
    var acceptedBoxes: [Int: [[Double]]] = [:]
    var perPageCount: [Int: Int] = [:]

    let recurring = recurringCandidateIndices(candidates)
    let ordered = candidates.enumerated().sorted { a, b in
        a.element.pageIndex != b.element.pageIndex ? a.element.pageIndex < b.element.pageIndex
            : (a.element.bbox[1], a.element.bbox[0], a.offset) < (b.element.bbox[1], b.element.bbox[0], b.offset)
    }
    for (ci, c) in ordered {
        var d = VisualResourceDecision(candidate: c, outcome: .accepted, containedLines: 0, matchedLines: 0,
                                       insertedAt: nil, containedElements: 0, coveredRoles: [:])
        func reject(_ o: VisualGuardOutcome) { d.outcome = o; decisions.append(d) }
        guard c.bbox.count == 4, c.label == "table" || c.label == "picture" else { reject(.notVisualLabel); continue }
        if recurring.contains(ci) { reject(.recurring); continue }
        let kind: VisualResourceKind = c.label == "table" ? .table : .figure
        let pageArea = c.pageWidth * c.pageHeight
        guard pageArea > 0, area(c.bbox) < VISUAL_MAX_PAGE_FRACTION * pageArea else { reject(.wholePage); continue }
        if kind == .figure {
            if area(c.bbox) < VISUAL_MIN_FIGURE_FRACTION * pageArea { reject(.ornament); continue }
            let n = extraction.pageCount
            if n >= VISUAL_COVER_MIN_PAGES && (c.pageIndex == 0 || c.pageIndex >= n - 2) { reject(.cover); continue }
        }
        if let prev = acceptedBoxes[c.pageIndex], prev.contains(where: { intersection($0, c.bbox) > 0.5 * min(area($0), area(c.bbox)) }) {
            reject(.duplicate); continue
        }
        let page = pages[c.pageIndex]
        let H = page?.height ?? c.pageHeight
        let lines = (page?.lines ?? []).filter { lineCenterInside(topLeftBox($0.bbox, pageHeight: H), c.bbox) }
        d.containedLines = lines.count
        if kind == .table, lines.count >= 2, c.graphicsInside == 0 { reject(.plainText); continue }
        if kind == .figure, (page?.lines ?? []).contains(where: { lineCrossesRegion(topLeftBox($0.bbox, pageHeight: H), c.bbox) }) {
            reject(.insideText); continue
        }
        if lines.contains(where: { lineCarriesNoteMarker($0, bodySize: bodySize) }) { reject(.noteMarkers); continue }
        // Righe contenute → segmenti del flusso che le portano.
        let page1 = c.pageIndex + 1
        var covered: [Int] = []
        var roleChars: [String: Int] = [:]
        var certainChars = 0, totalChars = 0
        for line in lines {
            let text = summarizeLine(line).text
            guard let i = flow.segmentContaining(text, page1: page1) else { continue }
            covered.append(i)
            let n = TextFingerprint.normalize(text).count
            let s = segments[i]
            roleChars[s.role, default: 0] += n
            totalChars += n
            let certainNote = s.role == SemanticCategory.NOTE.rawValue && textOpensWithNoteMarker(s.text)
            if VISUAL_CERTAIN_ROLES.contains(s.role) || certainNote { certainChars += n }
        }
        d.matchedLines = covered.count
        d.coveredRoles = roleChars
        // Testo presente ma non letto (per la maggior parte): apparato che l'app ha già riconosciuto e tolto dal flusso.
        let significant = lines.map { TextFingerprint.normalize(summarizeLine($0).text).count }.filter { $0 >= VISUAL_MIN_MATCH_CHARS }
        let significantChars = significant.reduce(0, +)
        if significantChars > 0, Double(totalChars) < 0.5 * Double(significantChars) { reject(.unreadText); continue }
        if totalChars > 0, Double(certainChars) >= 0.5 * Double(totalChars) { reject(.certainBlock); continue }
        // Collocazione.
        var at: Int?
        var contained = 0
        if let first = covered.min(), let last = covered.max() {
            at = first
            contained = last - first + 1
        } else {
            // Figura senza testo (o testo non ritrovato): subito prima del testo che il modello legge dopo,
            // altrimenti subito dopo quello che legge prima, altrimenti all'inizio della pagina.
            func anchorLines(_ box: [Double]?) -> [Int] {
                guard let box, box.count == 4 else { return [] }
                return (page?.lines ?? []).filter { lineCenterInside(topLeftBox($0.bbox, pageHeight: H), box) }
                    .compactMap { flow.segmentContaining(summarizeLine($0).text, page1: page1) }
            }
            if let next = anchorLines(c.nextTextBBox).min() { at = next }
            else if let prev = anchorLines(c.previousTextBBox).max() { at = prev + 1 }
            else { at = flow.firstSegment(onOrAfter: page1, count: segments.count) ?? segments.count }
        }
        let k = perPageCount[c.pageIndex, default: 0]
        perPageCount[c.pageIndex] = k + 1
        acceptedBoxes[c.pageIndex, default: []].append(c.bbox)
        var caption = ""
        if let cap = c.captionBBox, cap.count == 4 {
            caption = (page?.lines ?? []).filter { lineCenterInside(topLeftBox($0.bbox, pageHeight: H), cap) }
                .map { summarizeLine($0).text }.joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if caption.count > 400 { caption = String(caption.prefix(400)) + "…" }
        }
        let text = caption.isEmpty ? kind.word : "\(kind.word): \(caption)"
        let segment = ContentSegment(
            id: "vr_p\(c.pageIndex)_\(k)", role: VISUAL_RESOURCE_ROLE, text: text, lengthCategory: "",
            acousticIntro: acousticIntroFor(VISUAL_RESOURCE_ROLE, ""), memoryRefresh: "", sourcePage: page1,
            visualResource: VisualResourcePayload(kind: kind, pageIndex: c.pageIndex, bbox: c.bbox, containedElements: contained))
        pending.append(Pending(at: at!, order: pending.count, segment: segment))
        d.containedElements = contained
        decisions.append(d)
    }
    guard !pending.isEmpty else { return (segments, VisualResourcesReport(decisions: decisions)) }
    // Inserimento stabile: a parità di posizione, nell'ordine (pagina, alto) delle regioni.
    let sortedPending = pending.sorted { ($0.at, $0.order) < ($1.at, $1.order) }
    var out: [ContentSegment] = []
    out.reserveCapacity(segments.count + pending.count)
    var k = 0
    var insertedIndex: [String: Int] = [:]
    for (i, s) in segments.enumerated() {
        while k < sortedPending.count && sortedPending[k].at == i {
            insertedIndex[sortedPending[k].segment.id] = out.count
            out.append(sortedPending[k].segment); k += 1
        }
        out.append(s)
    }
    while k < sortedPending.count { insertedIndex[sortedPending[k].segment.id] = out.count; out.append(sortedPending[k].segment); k += 1 }
    // Indici finali nelle decisioni (per il referto).
    var acceptedSeen: [Int: Int] = [:]
    for j in decisions.indices where decisions[j].outcome == .accepted {
        let p = decisions[j].candidate.pageIndex
        let kk = acceptedSeen[p, default: 0]; acceptedSeen[p] = kk + 1
        decisions[j].insertedAt = insertedIndex["vr_p\(p)_\(kk)"]
    }
    return (out, VisualResourcesReport(decisions: decisions))
}
