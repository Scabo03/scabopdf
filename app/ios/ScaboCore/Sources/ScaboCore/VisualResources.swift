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
/// Quante pagine indietro si cerca il segmento che porta una riga: la continuità del corpo fonde un paragrafo (o una
/// tabella) che attraversa più pagine in un solo segmento, attribuito alla pagina dove comincia (misurato: lo schema di
/// calcolo delle pene di CP pp. 2514-2517 è un solo segmento). Le pagine più vicine hanno sempre la precedenza.
let VISUAL_MATCH_LOOKBACK_PAGES = 3
/// Lettere (normalizzate) di fila non coperte dalle righe della regione oltre le quali un segmento non è testo della
/// risorsa per «Salta la risorsa» (circa una decina di parole): il salto non scavalca testo estraneo più lungo.
let VISUAL_SKIP_MAX_FOREIGN_RUN = 60
/// Le righe della regione che contano per la copertura di un segmento: almeno tante lettere (le celle più corte, numeri di
/// una o due cifre, lasciano piccoli buchi, lontani dalla soglia).
let VISUAL_SKIP_COVER_MIN_CHARS = 4

/// La corsa più lunga di caratteri di `text` non coperti da occorrenze di `lines` (testi già normalizzati). In unità UTF-16
/// (il testo normalizzato ha lettere e cifre: una lettera accentata è un'unità).
func longestUncoveredRun(_ text: String, by lines: [String]) -> Int {
    let ns = text as NSString
    let n = ns.length
    guard n > 0 else { return 0 }
    var covered = [Bool](repeating: false, count: n)
    for l in lines where !l.isEmpty {
        var from = 0
        while from < n {
            let r = ns.range(of: l, options: [.literal], range: NSRange(location: from, length: n - from))
            if r.location == NSNotFound { break }
            for k in r.location..<(r.location + r.length) { covered[k] = true }
            from = r.location + max(1, r.length)
        }
    }
    var best = 0, run = 0
    for c in covered { if c { run = 0 } else { run += 1; best = max(best, run) } }
    return best
}
/// Oltre tante righe identiche sulla pagina, una riga è ambigua e non si usa la sua ripetizione per ritrovarla.
let VISUAL_MAX_REPETITIONS = 4
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
/// Una regione con una GRIGLIA disegnata — almeno tanti oggetti dipinti (filetti di righe e colonne, riquadri) la
/// toccano — è una tabella vera: nelle sue righe un numero in apertura è una cella (numero di riga, valore, data), non
/// un marcatore di nota, e un numero fra parentesi di tre cifre è un rinvio (un articolo), non un richiamo. Contano
/// solo i richiami inequivocabili: «(N)» con una o due cifre, «(*)», «[N]», apici a corpo ridotto. Misurato sui 52
/// volumi (giudizio contro la pagina, 2026-10-12): le 29 regioni scartate per «marcatori di nota» erano tutte tabelle
/// vere con almeno 6 disegni (tavole di concordanza, diritti di copia, stupefacenti, calcolo delle pene, statistiche).
let VISUAL_GRID_MIN_GRAPHICS = 6
/// Richiamo inequivocabile dentro una griglia: «(1)», «(12)», «(*)», «(**)», «[3]».
private let RE_GRID_CALLOUT = try! NSRegularExpression(pattern: "\\((?:[0-9]{1,2}|\\*{1,6})\\)|\\[[0-9]{1,2}\\]")

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

/// I ruoli di nota del flusso.
let VISUAL_NOTE_ROLES: Set<String> = [
    SemanticCategory.NOTE.rawValue, SemanticCategory.NOTE_CONTINUATION.rawValue, SemanticCategory.EDITORIAL_NOTE.rawValue,
]

/// Vero se il segmento `i` è una NOTA VERA: una NOTE che si apre con il suo marcatore (la stessa prova del «blocco certo»),
/// o un pezzo di seguito di una tale nota (si guarda il primo pezzo). Una NOTE senza marcatore (le intestazioni di colonna
/// a corpo minore che i codici classificano come note) non lo è.
func isTrueNoteSegment(_ segments: [ContentSegment], _ i: Int) -> Bool {
    var k = i
    while k > 0, segments[k].role == SemanticCategory.NOTE_CONTINUATION.rawValue { k -= 1 }
    return segments[k].role == SemanticCategory.NOTE.rawValue && textOpensWithNoteMarker(segments[k].text)
}

/// Distanza massima (in segmenti) fra due riscontri dello stesso gruppo.
let VISUAL_CLUSTER_GAP = 2
/// Quota minima delle lettere ritrovate perché un gruppo di riscontri appartenga alla regione: sotto, è un'eco.
let VISUAL_CLUSTER_MIN_SHARE = 0.25

/// I segmenti che portano DAVVERO il testo della regione. Si ordinano gli indici dei segmenti trovati, si spezzano in
/// gruppi dove due indici consecutivi distano più di `VISUAL_CLUSTER_GAP`, e si tengono i gruppi che portano almeno
/// `VISUAL_CLUSTER_MIN_SHARE` delle lettere ritrovate. Un gruppo piccolo e staccato è un'eco: la stessa riga in un'altra
/// tabella della pagina o di una pagina vicina (misurato: le tavole di concordanza dei codici ripetono le stesse celle
/// di pagina in pagina; le tabelle statistiche ripetono i nomi dei distretti). Una tabella che il flusso legge in due
/// parti separate da altri segmenti ha due gruppi grandi, e li tiene entrambi per la guardia (CP p. 1604); il testo
/// contenuto, per il salto, è solo la prima sequenza contigua.
func regionMatchClusters(_ matches: [(index: Int, chars: Int)]) -> Set<Int> {
    guard !matches.isEmpty else { return [] }
    var weight: [Int: Int] = [:]
    for m in matches { weight[m.index, default: 0] += m.chars }
    let total = weight.values.reduce(0, +)
    let sorted = weight.keys.sorted()
    var groups: [[Int]] = [[sorted[0]]]
    for i in sorted.dropFirst() {
        if i - groups[groups.count - 1].last! > VISUAL_CLUSTER_GAP { groups.append([i]) } else { groups[groups.count - 1].append(i) }
    }
    var kept = Set<Int>()
    for g in groups where Double(g.reduce(0) { $0 + weight[$1]! }) >= VISUAL_CLUSTER_MIN_SHARE * Double(total) {
        kept.formUnion(g)
    }
    return kept
}

// MARK: - Richiami e marcatori di nota

/// Vero se la riga porta un richiamo o un marcatore di nota: apre con un marcatore (numero, «(N)», simbolo),
/// oppure contiene un apice numerico o un simbolo di richiamo a corpo ridotto, oppure «(N)» a corpo di testo.
/// Dentro una GRIGLIA (`inGrid`, vedi `VISUAL_GRID_MIN_GRAPHICS`) contano solo i richiami inequivocabili.
func lineCarriesNoteMarker(_ line: PdfTextLine, bodySize: Double, inGrid: Bool = false) -> Bool {
    let sm = summarizeLine(line)
    if inGrid {
        let ns = sm.text as NSString
        if RE_GRID_CALLOUT.firstMatch(in: sm.text, range: NSRange(location: 0, length: ns.length)) != nil { return true }
    } else if textOpensWithNoteMarker(sm.text) { return true }
    if bodySize > 0 {
        let inline = detectInlineMarkers([sm], body: bodySize)
        if inGrid ? inline.contains(where: { $0.regime != .paren || $0.value < 100 }) : !inline.isEmpty { return true }
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
/// Il testo normalizzato si calcola PIGRAMENTE, solo per i segmenti delle pagine interrogate: un codice ha decine di migliaia
/// di segmenti e le regioni stanno su poche pagine (misurato: normalizzare tutto il flusso del codice penale costava
/// quasi un secondo a flusso).
final class FlowIndex {
    private let segments: [ContentSegment]
    let byPage: [Int: [Int]]
    private var cache: [Int: String] = [:]

    init(_ segments: [ContentSegment]) {
        self.segments = segments
        var bp: [Int: [Int]] = [:]
        for (i, s) in segments.enumerated() { if let p = s.sourcePage { bp[p, default: []].append(i) } }
        byPage = bp
    }

    /// Il testo normalizzato (lettere e cifre minuscole) del segmento `i`.
    func normalized(_ i: Int) -> String {
        if let n = cache[i] { return n }
        let n = TextFingerprint.normalize(segments[i].text)
        cache[i] = n
        return n
    }

    /// L'indice del primo segmento, fra quelli che cominciano sulla pagina `page1` (1-based) o su una delle
    /// `VISUAL_MATCH_LOOKBACK_PAGES` prima (le più vicine per prime), il cui testo contiene la riga. `nil` se la riga è
    /// troppo corta o non si ritrova.
    func segmentContaining(_ lineText: String, page1: Int) -> Int? {
        let n = TextFingerprint.normalize(lineText)
        guard n.count >= VISUAL_MIN_MATCH_CHARS else { return nil }
        for p in stride(from: page1, through: page1 - VISUAL_MATCH_LOOKBACK_PAGES, by: -1) {
            for i in byPage[p] ?? [] where normalized(i).contains(n) { return i }
        }
        return nil
    }

    /// Le occorrenze della riga fra i segmenti che cominciano sulla pagina `page1`, nell'ordine del flusso: per ciascuna
    /// occorrenza l'indice del segmento che la porta (un segmento può portarne più d'una).
    func occurrencesOnPage(_ lineText: String, page1: Int) -> [Int] {
        let n = TextFingerprint.normalize(lineText)
        guard n.count >= VISUAL_MIN_MATCH_CHARS else { return [] }
        var out: [Int] = []
        for i in byPage[page1] ?? [] {
            let t = normalized(i)
            var from = t.startIndex
            while let r = t.range(of: n, range: from..<t.endIndex) {
                out.append(i)
                from = r.upperBound
            }
        }
        return out
    }

    /// Tutti i segmenti che portano la riga, fra quelli che cominciano sulla pagina `page1` o su una delle
    /// `VISUAL_MATCH_LOOKBACK_PAGES` prima, nell'ordine del flusso.
    func segmentsContaining(_ lineText: String, page1: Int) -> [Int] {
        let n = TextFingerprint.normalize(lineText)
        guard n.count >= VISUAL_MIN_MATCH_CHARS else { return [] }
        var out: [Int] = []
        for p in stride(from: page1 - VISUAL_MATCH_LOOKBACK_PAGES, through: page1, by: 1) {
            for i in byPage[p] ?? [] where normalized(i).contains(n) { out.append(i) }
        }
        return out.sorted()
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
    // La taglia del corpo serve solo alla guardia-marcatore: si stima alla prima regione che ne ha bisogno.
    var bodySizeCache: Double?
    func bodySize() -> Double {
        if let b = bodySizeCache { return b }
        let b = estimateProfile(extraction).bodySize
        bodySizeCache = b
        return b
    }
    let flow = FlowIndex(segments)
    // Le righe normalizzate di ogni pagina dell'estrazione, calcolate a richiesta: per contare quante volte una riga
    // compare prima di sé nella finestra di pagine (la sua ripetizione), e ritrovare nel flusso la ripetizione giusta.
    var normalizedLines: [Int: [String]] = [:]
    func linesOf(_ pageIndex: Int) -> [String] {
        if let l = normalizedLines[pageIndex] { return l }
        let l = (pages[pageIndex]?.lines ?? []).map { TextFingerprint.normalize(summarizeLine($0).text) }
        normalizedLines[pageIndex] = l
        return l
    }
    /// La ripetizione della riga `n` SULLA SUA PAGINA: quante righe identiche la precedono e quante sono in tutto.
    func repetition(_ n: String, pageIndex: Int, lineIndex: Int) -> (before: Int, total: Int) {
        guard n.count >= VISUAL_MIN_MATCH_CHARS else { return (0, 1) }
        var before = 0, total = 0
        for (k, t) in linesOf(pageIndex).enumerated() where t == n {
            total += 1
            if k < lineIndex { before += 1 }
        }
        return (before, max(total, 1))
    }
    /// Il segmento della riga per RIPETIZIONE, quando vale: la pagina ripete la riga identica poche volte (da 2 a
    /// `VISUAL_MAX_REPETITIONS`: intestazioni di colonna di più tabelle, la stessa fonte sotto due grafici) e il flusso,
    /// fra i segmenti che cominciano sulla pagina, la porta lo STESSO numero di volte: allora la k-esima ripetizione
    /// dell'estrazione è la k-esima del flusso. Se i conti non tornano (una parola d'intestazione che compare anche
    /// nella prosa, le celle uguali di una tavola di concordanza) la ripetizione è ambigua: `nil`, e vale la vicinanza.
    func segmentByRepetition(pageIndex: Int, lineIndex: Int, text: String) -> Int? {
        let rep = repetition(TextFingerprint.normalize(text), pageIndex: pageIndex, lineIndex: lineIndex)
        guard rep.total >= 2, rep.total <= VISUAL_MAX_REPETITIONS else { return nil }
        let occ = flow.occurrencesOnPage(text, page1: pageIndex + 1)
        return occ.count == rep.total ? occ[rep.before] : nil
    }
    /// Il segmento che porta la riga di indice `lineIndex` della pagina: per ripetizione quando vale, altrimenti il primo
    /// che la porta cercando dalla pagina della regione all'indietro.
    func segmentFor(pageIndex: Int, lineIndex: Int, text: String) -> Int? {
        segmentByRepetition(pageIndex: pageIndex, lineIndex: lineIndex, text: text)
            ?? flow.segmentContaining(text, page1: pageIndex + 1)
    }
    var pages: [Int: PdfPageExtraction] = [:]
    for p in extraction.pages { pages[p.pageIndex] = p }

    struct Pending { var at: Int; var order: Int; var segment: ContentSegment }
    var pending: [Pending] = []
    var decisions: [VisualResourceDecision] = []
    var acceptedBoxes: [Int: [[Double]]] = [:]
    var perPageCount: [Int: Int] = [:]

    let recurring = recurringCandidateIndices(candidates)
    // Ordine (pagina, alto, sinistra); un candidato malformato (riquadro senza quattro valori) non fa cadere l'ordinamento:
    // la guardia lo scarta subito dopo.
    func topLeft(_ c: VisualRegionCandidate) -> (Double, Double) { c.bbox.count == 4 ? (c.bbox[1], c.bbox[0]) : (0, 0) }
    let ordered = candidates.enumerated().sorted { a, b in
        a.element.pageIndex != b.element.pageIndex ? a.element.pageIndex < b.element.pageIndex
            : (topLeft(a.element).0, topLeft(a.element).1, a.offset) < (topLeft(b.element).0, topLeft(b.element).1, b.offset)
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
        let indexedLines = (page?.lines ?? []).enumerated().filter { lineCenterInside(topLeftBox($0.element.bbox, pageHeight: H), c.bbox) }
        let lines = indexedLines.map { $0.element }
        d.containedLines = lines.count
        if kind == .table, lines.count >= 2, c.graphicsInside == 0 { reject(.plainText); continue }
        if kind == .figure, (page?.lines ?? []).contains(where: { lineCrossesRegion(topLeftBox($0.bbox, pageHeight: H), c.bbox) }) {
            reject(.insideText); continue
        }
        let inGrid = (c.graphicsInside ?? 0) >= VISUAL_GRID_MIN_GRAPHICS
        if !lines.isEmpty, lines.contains(where: { lineCarriesNoteMarker($0, bodySize: bodySize(), inGrid: inGrid) }) { reject(.noteMarkers); continue }
        // Righe contenute → segmenti del flusso che le portano. Primo passo: per ripetizione quando vale, altrimenti il
        // primo segmento che porta la riga cercando dalla pagina all'indietro.
        let page1 = c.pageIndex + 1
        var firstPass: [(text: String, chars: Int, byRepetition: Bool, index: Int)] = []
        for (k, line) in indexedLines {
            let text = summarizeLine(line).text
            let chars = TextFingerprint.normalize(text).count
            if let i = segmentByRepetition(pageIndex: c.pageIndex, lineIndex: k, text: text) {
                firstPass.append((text, chars, true, i))
            } else if let i = flow.segmentContaining(text, page1: page1) {
                firstPass.append((text, chars, false, i))
            }
        }
        // Secondo passo: una riga che il flusso porta in più segmenti (e che la ripetizione non risolve) va a quello più
        // vicino al grosso del testo della regione (il segmento che ne porta più lettere), non al primo della pagina: la
        // stessa frase può stare anche nella didascalia di un'altra tabella, in un segmento prima (misurato su una rivista:
        // l'intestazione di una tabella ripetuta nella didascalia della tabella precedente spostava l'annuncio prima dei dati
        // di quella), e una parola d'intestazione può stare anche nella prosa che precede. Una riga che il primo passo ha
        // trovato FUORI dalle note non passa a una NOTA VERA (`isTrueNoteSegment`) solo perché questa sta più vicina al
        // grosso: la prosa di una nota che usa le stesse parole di un'intestazione è un'eco, non la tabella (giro «cura delle
        // note», 2026-10-16: sulla rivista, p. 117, la nota accanto alla tabella ripete le parole della prima colonna, e
        // bastava che cambiasse il numero dei suoi pezzi per portare l'annuncio prima della fonte della tabella precedente).
        // Tutto il resto come prima: una riga che il primo passo trova già in una nota (i numeri d'articolo fra parentesi
        // di una tabella statistica), e le intestazioni a corpo minore che il flusso porta come note senza numero (le
        // tavole di concordanza dei codici).
        var weightOf: [Int: Int] = [:]
        for m in firstPass { weightOf[m.index, default: 0] += m.chars }
        let bulk = weightOf.max { a, b in a.value != b.value ? a.value < b.value : a.key > b.key }?.key
        var matches: [(index: Int, chars: Int)] = []
        for m in firstPass {
            var i = m.index
            if !m.byRepetition, let bulk {
                let candidates = flow.segmentsContaining(m.text, page1: page1)
                if candidates.count > 1 {
                    let firstInNote = VISUAL_NOTE_ROLES.contains(segments[m.index].role)
                    let notNotes = firstInNote ? [] : candidates.filter { !isTrueNoteSegment(segments, $0) }
                    let pool = notNotes.isEmpty ? candidates : notNotes
                    if let best = pool.min(by: { (abs($0 - bulk), $0) < (abs($1 - bulk), $1) }) { i = best }
                }
            }
            matches.append((i, m.chars))
        }
        // I segmenti che portano davvero il testo della regione (le eco escluse): per la collocazione e per il «blocco
        // certo». Il «testo non letto» si giudica invece su tutti i riscontri: se la riga c'è, nel flusso c'è.
        let kept = regionMatchClusters(matches)
        let foundChars = matches.reduce(0) { $0 + $1.chars }
        var covered: [Int] = []
        var roleChars: [String: Int] = [:]
        var certainChars = 0, totalChars = 0
        for (i, n) in matches where kept.contains(i) {
            covered.append(i)
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
        if significantChars > 0, Double(foundChars) < 0.5 * Double(significantChars) { reject(.unreadText); continue }
        if totalChars > 0, Double(certainChars) >= 0.5 * Double(totalChars) { reject(.certainBlock); continue }
        // Collocazione.
        var at: Int?
        var contained = 0
        if let first = covered.min(), let last = covered.max() {
            at = first
            // Il testo contenuto (quello che «Salta la risorsa» supera): i segmenti dal primo all'ultimo della regione, finché
            // sono CONTIGUI e sono testo della risorsa. Un segmento conta se tutto il suo testo sta nel testo della regione (il
            // flusso spezza a volte una riga della tabella in due segmenti, come un numero d'intestazione sotto la sua
            // etichetta), oppure se porta righe della regione e non contiene, in nessun punto, una corsa di testo estraneo di
            // `VISUAL_SKIP_MAX_FOREIGN_RUN` lettere o più (circa dieci parole): la prosa di un riquadro prima della tabella, una
            // nota d'articolo che ne ripete una frase, il capoverso che segue nello stesso segmento grosso. Il primo segmento
            // che non conta ferma il conteggio; la parte che segue resta testo ordinario, nello swipe come sempre (rilievi
            // della revisione indipendente: codice penale p. 1604, rivista p. 117, manuale p. 250).
            let carrying = Set(covered)
            // Il testo della risorsa: le righe della regione e quelle della sua didascalia (già detta nell'annuncio).
            let captionLines = c.captionBBox.flatMap { cap in
                cap.count == 4 ? (page?.lines ?? []).filter { lineCenterInside(topLeftBox($0.bbox, pageHeight: H), cap) } : nil
            } ?? []
            let regionLines = (lines + captionLines).map { TextFingerprint.normalize(summarizeLine($0).text) }
            let regionText = regionLines.joined()
            let coverLines = regionLines.filter { $0.count >= VISUAL_SKIP_COVER_MIN_CHARS }
            func isResourceText(_ i: Int) -> Bool {
                let t = flow.normalized(i)
                if regionText.contains(t) { return true }
                return carrying.contains(i) && longestUncoveredRun(t, by: coverLines) < VISUAL_SKIP_MAX_FOREIGN_RUN
            }
            var end = first
            while end <= last, isResourceText(end) { end += 1 }
            contained = end - first
        } else {
            // Senza testo nel flusso (figura, tabella che è un'immagine). In ordine: 1. la DIDASCALIA, se il flusso la porta:
            // la risorsa la precede se la didascalia sta sotto, la segue se sta sopra; 2. il testo che il modello legge
            // dopo e poi quello che legge prima, CORRETTI dalla geometria (un blocco tutto sopra la regione la precede
            // sulla pagina, uno tutto sotto la segue, qualunque cosa dica l'ordine del modello); 3. l'inizio della pagina.
            // I segmenti che portano il testo di un blocco d'àncora, senza le eco (stesso filtro della regione): una frase
            // ricorrente in coda alla didascalia (la stessa fonte dei dati sotto ogni grafico) non deve spostare la risorsa.
            func anchorSegments(_ box: [Double]) -> [Int] {
                let found: [(index: Int, chars: Int)] = (page?.lines ?? []).enumerated()
                    .filter { lineCenterInside(topLeftBox($0.element.bbox, pageHeight: H), box) }
                    .compactMap { pair in
                        let text = summarizeLine(pair.element).text
                        return segmentFor(pageIndex: c.pageIndex, lineIndex: pair.offset, text: text)
                            .map { (index: $0, chars: TextFingerprint.normalize(text).count) }
                    }
                let kept = regionMatchClusters(found)
                return found.map { $0.index }.filter { kept.contains($0) }
            }
            func isAbove(_ b: [Double]) -> Bool { b[3] <= c.bbox[1] + 1 }
            func isBelow(_ b: [Double]) -> Bool { b[1] >= c.bbox[3] - 1 }
            var follow: [Int] = []    // segmenti che la risorsa segue
            var precede: [Int] = []   // segmenti che la risorsa precede
            if let cap = c.captionBBox, cap.count == 4 {
                let found = anchorSegments(cap)
                if isAbove(cap) { follow = found } else { precede = found }
            }
            if follow.isEmpty && precede.isEmpty, let nb = c.nextTextBBox, nb.count == 4 {
                let found = anchorSegments(nb)
                if isAbove(nb) { follow = found } else { precede = found }
            }
            if follow.isEmpty && precede.isEmpty, let pb = c.previousTextBBox, pb.count == 4 {
                let found = anchorSegments(pb)
                if isBelow(pb) { precede = found } else { follow = found }
            }
            if let b = precede.min() { at = b }
            else if let a = follow.max() { at = a + 1 }
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
        // La pagina dell'elemento NEL FLUSSO: quella della regione, ma chiusa fra le pagine dei segmenti vicini, così le
        // pagine restano monotone (un elemento inserito prima di un segmento fuso che comincia pagine prima non riporta
        // indietro l'indicatore né gli stacchi; rilievo della revisione indipendente). La pagina vera della regione resta
        // nel payload (ritaglio, valore annunciato).
        var flowPage = page1
        if let a = at, a < segments.count, let next = segments[a].sourcePage { flowPage = min(flowPage, next) }
        if let a = at, a > 0, let prev = segments[a - 1].sourcePage { flowPage = max(flowPage, prev) }
        let segment = ContentSegment(
            id: "vr_p\(c.pageIndex)_\(k)", role: VISUAL_RESOURCE_ROLE, text: text, lengthCategory: "",
            acousticIntro: acousticIntroFor(VISUAL_RESOURCE_ROLE, ""), memoryRefresh: "", sourcePage: flowPage,
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
