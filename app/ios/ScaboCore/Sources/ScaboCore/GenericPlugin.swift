//
//  GenericPlugin.swift
//  ScaboCore
//
//  The corpus-agnostic Generic extraction plugin. Faithful translation of
//  `app/src/plugins/generic.ts` (the multi-signal size+colour+geometry rewrite,
//  commit 3a811f8).
//
//  FIDELITY, NOT IMPROVEMENT. Translating the Generic does not fix it. By
//  construction it over-detects headings from generic signals and cannot tell a
//  corpus's specific notes apart — it collapses on several corpora, and that is
//  the documented behaviour the future corpus plugins (out of this phase) will
//  correct. The success criterion here is that the Swift Generic behaves
//  IDENTICALLY to the TS Generic, collapse included. No classification is
//  "fixed" in this translation.
//
//  The closed set it emits — HEADING_1..4, BODY, NOTE — plus the per-category
//  signal and the suppressed/reserved buckets are pinned in `Taxonomy.swift`.
//

import Foundation

// MARK: - Calibrated constants (verbatim from generic.ts)

/// A heading is only accepted on a reasonably short line.
let HEADING_MAX_CHARS = 120
/// Size ratios (line size / body size) that promote a short line to a heading.
let HEADING_1_RATIO = 1.5
let HEADING_2_RATIO = 1.25
let HEADING_3_RATIO = 1.12
/// A short, bold line a touch larger than body reads as a minor heading.
let HEADING_4_BOLD_RATIO = 1.04
/// Below this ratio a line reads as a note (smaller than body).
let NOTE_RATIO = 0.85

// ── Glossa laterale (riconoscimento geometrico bidimensionale) ───────────────────
// Una glossa è una riga PICCOLA (banda nota) che sta FUORI dalla colonna del corpo
// (margine sx/dx), alfabetica, non folio/romano. La colonna è stimata PER-PAGINA
// (i margini si alternano recto/verso). Vedi docs/GLOSSE_LATERALI.md.
/// Tolleranza dimensione per dire "questa riga è alla taglia del corpo".
let BODY_SIZE_TOLERANCE = 0.6
/// Una riga conta come "riga della colonna del corpo" solo se è larga almeno così.
let BODY_COLUMN_MIN_WIDTH_FRACTION = 0.40
/// Servono almeno N righe-corpo per stimare la colonna; sotto, ci si ASTIENE.
let MIN_BODY_LINES_FOR_COLUMN = 3
/// Margine (pt) oltre il bordo colonna perché una riga sia "fuori colonna": più
/// stretto di così → ambigua → si resta in NOTE (astensione, mai scarto nel dubbio).
let GLOSS_MARGIN_TOLERANCE = 5.0

/// RGB distance beyond which a colour counts as "distinct from body".
let COLOR_DISTANCE_MIN = 100.0
/// Min RGB saturation (max−min channel) for a colour to read as structural.
let COLOR_SATURATION_MIN = 40
/// A colour-distinct line must be at least this fraction of the body size.
let COLOR_HEADING_MIN_RATIO = 0.95
/// Page bands (fraction of height) where running furniture lives. `TOP_BAND` è
/// 0.85 (non 0.9) perché molte testatine correnti siedono appena sotto il decile
/// più alto: su "Delitti in prima pagina" il titolo-libro corre a yFrac≈0.883 e su
/// Mosconi la testatina "Il diritto internazionale privato N" è analoga; col 0.9
/// sfuggivano alla banda e finivano lette (annuncio "Nota." + intrusione del titolo
/// in mezzo al primo paragrafo — collaudo d'orecchio, bug 1/2). La discriminazione
/// resta per NORMA RICORRENTE (stesso testo normalizzato su ≥ 15% delle pagine): una
/// riga di corpo, sempre di testo diverso, non ricorre mai per norma e non è toccata
/// — è ciò che rende sicuro abbassare la banda invece di togliere per posizione.
let TOP_BAND = 0.85
let BOTTOM_BAND = 0.1
/// A furniture candidate is short.
let FURNITURE_MAX_CHARS = 60
/// The digit-normalised form of a line whose entire text is one bare number
/// (`normalizeDigits` collapses the single digit run to this). Such lines are
/// routed to folio-by-progression detection instead of the recurring-norm
/// channels — see `detectFurniture`.
let BARE_NUMBER_NORM = "#"

// ── Testatina corrente di CAPITOLO (running header) ──────────────────────────────
// La testatina che ripete il titolo del capitolo (recto) o del libro (verso) ricorre
// solo DENTRO il suo capitolo (9–21 pagine su un volume tipico), quindi resta sotto il
// pavimento globale del 15% (`minPages`) e finisce LETTA — su molti libri accademici è
// la fetta più grossa del rumore (Delitti: 9 testatine, 136 occorrenze). Il canale
// generale per-norma non la prende perché è per-capitolo, non globale.
//
// Il segnale che la distingue da una riga di corpo che si ripete (coda di tabella, voce
// bibliografica, sotto-titolo numerato collassato dalla normalizzazione cifre) è
// GEOMETRICO e verificato sul banco PDFKit reale su 10 volumi: la testatina è (1) la riga
// PIÙ IN ALTO della pagina (sopra di lei non c'è contenuto — i sotto-titoli di sezione
// come "3.4.1 Definizioni" stanno SOTTO la testatina, le note a piè stanno in fondo),
// (2) nella banda superiore, (3) ANCORATA alla stessa y su tutte le sue occorrenze
// (σ ≈ 0; una riga di corpo non si blocca mai a una y fissa). Le tre guardie insieme
// danno ZERO falsi positivi sul corpo nel banco (footnote e sotto-titoli esclusi per
// costruzione). Il titolo di capitolo VERO resta: è un nodo HEADING separato, di norma
// diversa (porta il numero "1." / dimensione maggiore) e occorre una volta sola.
//
/// Una testatina corrente è riconosciuta se la riga-candidata ricorre su almeno così
/// tante pagine (sotto il pavimento globale del 15%, che resta per il canale generale).
let RUNNING_HEADER_MIN_PAGES = 3
/// Deviazione standard massima della frazione-y fra le occorrenze perché valga
/// "ancorata alla stessa posizione" (≈ 4pt su una pagina di 700pt). Una riga di corpo
/// che si ripete non è mai ancorata; la testatina sì.
let RUNNING_HEADER_POSITION_LOCK = 0.006

// ── Furniture front-matter / running-header / folii romani (generalizza il mattone 1) ──
// Il mattone 1 prende SOLO la riga PIÙ IN ALTO della pagina: restano fuori, e finiscono
// letti, i running-header NON-topmost (recto/verso, testatine col § o col titolo-volume),
// i footer ricorrenti (© editore), e i folii ROMANI di front-matter ("PREMESSA VII").
// Questo canale generalizza: QUALUNQUE riga corta sostanziale, in banda alta o bassa,
// RIPETUTA su ≥ pagine e ANCORATA alla stessa y, è furniture — anche sotto il 15% globale
// e anche se non è la più in alto. Due differenze dal mattone 1, entrambe per recall:
//  (a) si normalizzano anche i NUMERI ROMANI (oltre alle cifre) così "PREMESSA VII" e
//      "PREMESSA VIII" diventano una sola norma ricorrente (il folio romano varia);
//  (b) si considera OGNI riga (non solo la più in alto), in banda alta o bassa (footer
//      inclusi).
// Precisione prima del recall: l'ancoraggio σ < LOCK su TUTTE le occorrenze è la guardia che
// il corpo non supera mai (una nota a piè o una riga di corpo hanno y variabile da pagina a
// pagina → σ alta; testatine/folii/footer no). "Mobilia vs contenuto" si scioglie così: se
// un'intestazione vera dello stesso testo comparisse a y diversa (stessa norma), il suo
// outlier alza σ oltre LOCK e l'intera norma NON è rimossa (conservativo, mai si tocca il
// contenuto). In più si richiede la banda alta/bassa (esclude un lock di corpo a metà pagina)
// e si esclude chi APRE una regione d'apparato (come il mattone 1, per non rompere gli indici).
let FURNITURE_RECUR_MIN_PAGES = 3
/// Bande (frazione-dall'alto, convenzione yTop/height) entro cui vive la furniture: testa
/// alta o piè basso. Esclude un lock di corpo nel mezzo della pagina (0.28–0.72).
let FURNITURE_TOP_BAND = 0.72
let FURNITURE_BOTTOM_BAND = 0.28

/// NOTE length → acoustic regime thresholds (mirrors Layer 1).
let LENGTH_THRESHOLDS: [(Int, LengthCategory)] = [
    (50, .MICRO),
    (100, .SHORT),
    (500, .MEDIUM),
    (1000, .LONG),
    (3000, .VERY_LONG),
]

/// The classification verdict for a line.
enum Kind: Equatable {
    case body
    case note
    case heading(level: Int)
}

/// The estimated body profile.
struct Profile {
    let bodySize: Double
    let bodyColor: String
    /// Gate della foglia titoli-Estratto (taglia+struttura): vero SOLO sui volumi che
    /// presentano la firma dell'Estratto — un "CAPITOLO N" seguito da un titolo TUTTO
    /// MAIUSCOLO a taglia DISTINTAMENTE > corpo (≈ corpo×1.04). Confina la foglia a quel
    /// volume/famiglia: dove è falso, `recognizeEstrattoTitles` è un no-op (byte-identico).
    var isEstrattoChrome: Bool = false
}

// MARK: - The plugin

/// The universal fallback: always eligible, always loses to a corpus-specific
/// plugin that recognises the document. A `final class` so the dispatcher's
/// identity check works (`selectPlugin(...) === genericPlugin`).
public final class GenericPlugin: ExtractionPlugin {
    public let id = "generic"
    public let label = "Generico"

    public func matches(_ extraction: PdfExtraction) -> Double { 0.05 }

    public func build(_ extraction: PdfExtraction, sourceName: String) -> ScabopdfDocument {
        let profile = estimateProfile(extraction)
        let furniture = detectFurniture(extraction)
        let fmMax = frontMatterRegionLimit(extraction.pageCount)
        let apparatus = detectApparatus(extraction, furniture)
        var nodes: [NodeDict] = []
        var counter = 0
        func nextId() -> String {
            defer { counter += 1 }
            return "node_\(counter)"
        }

        for page in extraction.pages {
            appendPageNodes(page, profile, furniture, fmMax, apparatus, &nodes, nextId)
        }

        return assembleDocument(
            extraction, sourceName: sourceName, nodes: nodes, profile: profile,
            furnitureCount: furniture.count)
    }

    /// Progress- and cancellation-aware build (ADDITIVO, sessione import). Riproduce
    /// `build(_:sourceName:)` ESATTAMENTE — stessa stima di profilo, stessa rilevazione di
    /// furniture, stesso `nextId` sequenziale, stesso assemblaggio via `assembleDocument` — ma
    /// riporta il progresso reale per pagina e onora la cancellazione cooperativa a ogni tappa
    /// naturale (prima delle due passate globali e prima di ciascuna pagina). Ritorna `nil` se
    /// cancellato, senza emettere un documento parziale. Le pagine sono l'unità di avanzamento
    /// reale: `onPageClassified(i+1, total)` dopo l'emissione dei nodi della pagina i.
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
        func nextId() -> String {
            defer { counter += 1 }
            return "node_\(counter)"
        }

        let total = extraction.pages.count
        for (index, page) in extraction.pages.enumerated() {
            if isCancelled() { return nil }
            appendPageNodes(page, profile, furniture, fmMax, apparatus, &nodes, nextId)
            onPageClassified(index + 1, total)
        }
        if isCancelled() { return nil }

        return assembleDocument(
            extraction, sourceName: sourceName, nodes: nodes, profile: profile,
            furnitureCount: furniture.count)
    }

    /// Assembla il `ScabopdfDocument` finale dai nodi emessi. Punto unico di verità per le
    /// warning e i metadati, condiviso dai due `build` (sincrono e progress-aware) così non
    /// possono divergere.
    private func assembleDocument(
        _ extraction: PdfExtraction,
        sourceName: String,
        nodes: [NodeDict],
        profile: Profile,
        furnitureCount: Int
    ) -> ScabopdfDocument {
        // Riclassificazione a monte delle famiglie pulite (SOMMARIO → CHAPTER_SUMMARY,
        // intestazioni di struttura → HEADING_n): così non diventano mai NOTA e non
        // serve zittirle a valle. In posizione (conteggio/ordine invariati).
        var nodes = nodes
        let reclass = reclassifyCleanFamilies(&nodes)
        // Testatina corrente ricorrente (titolo capitolo recto, lunga, ripetuta) sfuggita al
        // cap-caratteri della furniture e finita come NOTE → ARTIFACT_RUNNING_HEADER (non-letta).
        // GATED Estratto: no-op (e nodi invariati) sugli altri volumi.
        let runningHeaders = reclassifyEstrattoRunningHeaders(&nodes, profile)
        var warnings = [
            "plugin:generic:heuristic_extraction_pages_\(extraction.pageCount)_nodes_\(nodes.count)",
        ]
        if reclass.summary + reclass.heading > 0 {
            warnings.append(
                "plugin:generic:reclassified_chapter_summary_\(reclass.summary)_structure_heading_\(reclass.heading)")
        }
        if runningHeaders > 0 {
            warnings.append("plugin:generic:estratto_running_headers_reclassified_\(runningHeaders)")
        }
        if profile.bodySize == 0 {
            warnings.append("plugin:generic:no_font_information_all_body")
        }
        if furnitureCount > 0 {
            warnings.append("plugin:generic:furniture_lines_removed_\(furnitureCount)")
        }
        let glossCount = nodes.reduce(0) { $0 + ($1.type == .MARGINAL_GLOSS ? 1 : 0) }
        if glossCount > 0 {
            warnings.append("plugin:generic:lateral_glosses_\(glossCount)")
        }
        // Apparato di front- e back-matter emesso come nodi ma escluso dal flusso
        // letto (NON_READ_ROLES): colophon (STAMP), indice/sommario a leader (TOC),
        // indice nomi/fonti/sentenze di coda (INDEX_ENTRY). L'indice analitico
        // recintato NON è contato qui (resta letto, non è INDEX_ENTRY).
        let stampCount = nodes.reduce(0) { $0 + ($1.type == .ARTIFACT_STAMP ? 1 : 0) }
        let tocCount = nodes.reduce(0) { $0 + ($1.type == .TOC_GENERAL ? 1 : 0) }
        let indexCount = nodes.reduce(0) { $0 + ($1.type == .INDEX_ENTRY ? 1 : 0) }
        if stampCount + tocCount + indexCount > 0 {
            warnings.append(
                "plugin:generic:apparatus_stamp_\(stampCount)_toc_\(tocCount)_index_\(indexCount)")
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
                profile_id: "generic",
                editorial_family: "generic",
                genre: "unknown",
                confidence: matches(extraction)
            ),
            warnings: warnings,
            transformations: [],
            structure: nodes
        )
    }
}

/// The Generic plugin singleton (identity matters for the dispatcher).
public let genericPlugin = GenericPlugin()

// MARK: - Profile estimation

/// Body size = the LARGEST size bucket that is at least half as frequent (by
/// line count) as the most frequent bucket — robust to note-heavy documents.
/// Body colour = the colour covering the most characters (ties → first-seen).
func estimateProfile(_ extraction: PdfExtraction) -> Profile {
    var linesBySize: [Double: Int] = [:]
    var colorCounts: [String: Int] = [:]
    var colorOrder: [String] = []

    for page in extraction.pages {
        for line in page.lines {
            let sm = summarizeLine(line)
            if sm.fontSize > 0 {
                let key = (sm.fontSize * 2).rounded(.toNearestOrAwayFromZero) / 2 // 0.5pt buckets
                linesBySize[key, default: 0] += 1
            }
            if colorCounts[sm.color] == nil { colorOrder.append(sm.color) }
            colorCounts[sm.color, default: 0] += sm.text.utf16.count
        }
    }

    var topCount = 0
    for count in linesBySize.values { topCount = max(topCount, count) }

    var bodySize = 0.0
    for (size, count) in linesBySize {
        if Double(count) >= Double(topCount) * 0.5 && size > bodySize {
            bodySize = size
        }
    }

    var bodyColor = "#000000"
    var bestChars = -1
    for c in colorOrder {
        let chars = colorCounts[c]!
        if chars > bestChars {
            bestChars = chars
            bodyColor = c
        }
    }

    // Gate foglia titoli-Estratto: firma "CAPITOLO N" seguito (entro poche righe) da un
    // titolo TUTTO MAIUSCOLO a taglia distintamente > corpo (≈ corpo×1.04). È la co-occorrenza
    // specifica dell'Estratto: Mandrioli ha CAPITOLO N ma il titolo è a corpo×1.0 (e già
    // HEADING_3); gli altri non hanno il titolo-maiuscolo-più-grande. Co-occorrenza, non la
    // sola taglia: confina la foglia a quel volume/famiglia.
    var isEstratto = false
    if bodySize > 0 {
        outer: for page in extraction.pages {
            var sinceCapitolo = 99
            for line in page.lines {
                let sm = summarizeLine(line)
                let t = jsTrim(sm.text)
                if t.isEmpty { continue }
                if ESTRATTO_CAPITOLO_RE.firstMatch(
                    in: t, range: NSRange(t.startIndex..<t.endIndex, in: t)) != nil {
                    sinceCapitolo = 0
                } else {
                    if sinceCapitolo <= 3,
                       sm.fontSize >= bodySize * ESTRATTO_CHAPTER_RATIO_LO,
                       sm.fontSize <= bodySize * ESTRATTO_CHAPTER_RATIO_HI,
                       isSubstantial(t), capsRatioCortina(t) >= ESTRATTO_TITLE_CAPS_MIN {
                        isEstratto = true
                        break outer
                    }
                    sinceCapitolo += 1
                }
            }
        }
    }

    return Profile(bodySize: bodySize, bodyColor: bodyColor, isEstrattoChrome: isEstratto)
}

// MARK: - Furniture detection

/// Running headers/footers + per-page colour markers + majority watermarks:
/// short lines (or any-length watermarks) recurring across many pages; plus the
/// page-number folio, removed by PROGRESSION rather than by recurrence (see
/// below). Returns "pageIndex:lineIndex" keys to skip.
///
/// Folio vs content-number (Mattone A). A line whose entire text is one bare
/// number normalises — like every page-number — to the single norm "#". Routing
/// it through the recurring-norm channels collapses every isolated number to
/// that one norm, and because the folio makes "#" recur on most pages it then
/// sweeps away every *content* number that happens to sit on its own line: an
/// index page reference, an article number, a bibliography entry number, a
/// marginal paragraph number. So bare-number lines bypass the recurrence
/// channels entirely and are removed only when they form a folio PROGRESSION —
/// a value tracking v = pageIndex + offset for an offset that recurs across the
/// volume. A number that does not progress (notes restarting from 1, an index
/// reference, a marginal §-number) never matches and is preserved.
/// Vero se la riga APRE una regione d'apparato ESCLUSA dal flusso letto (indice dei nomi/
/// fonti/sentenze → INDEX_ENTRY; sommario/indice generale → TOC_GENERAL): il rilevatore
/// d'apparato (`detectBackMatterApparatus` / `detectFrontMatterNoLeaderIndex`) usa questa
/// riga-testatina per aprire la regione, e le sue pagine sono comunque escluse dalla
/// lettura — quindi NON va rimossa come testatina corrente (la rimozione spezzerebbe il
/// rilevamento e farebbe LEGGERE l'indice). Le regioni LETTE (bibliografia, indice
/// analitico recintato) non sono qui: lì la testatina corrente va rimossa come ovunque.
private func opensExcludedApparatusRegion(_ text: String) -> Bool {
    regexHits(backMatterNameIndexHeadingRegex, text) || regexHits(frontMatterTocHeadingRegex, text)
}

func detectFurniture(_ extraction: PdfExtraction) -> Set<String> {
    // Dimensione del corpo, per la guardia anti-falso-positivo del canale generalizzato:
    // testatine/folii/footer sono ≤ corpo; le INTESTAZIONI (capitolo/sezione) sono PIÙ GRANDI.
    // Senza questa guardia la norma roman/ordinale collasserebbe "Capitolo II/III/…" in
    // "capitolo #", e quelle intestazioni — tutte alla y d'inizio-capitolo (ancorate) — verrebbero
    // rimosse come mobilia (regressione: si mangia un'intestazione vera).
    let bodySizeForFurniture = estimateProfile(extraction).bodySize
    struct Candidate { let key: String; let norm: String }
    struct FolioCandidate { let key: String; let page: Int; let value: Int }
    var bandCandidates: [Candidate] = []
    var colorCandidates: [Candidate] = []
    var generalCandidates: [Candidate] = []
    var bandPages: [String: Set<Int>] = [:]
    var colorPages: [String: Set<Int>] = [:]
    var generalPages: [String: Set<Int>] = [:]
    // Folio detection runs on bare-number lines only, off to the side.
    var folioCandidates: [FolioCandidate] = []
    var offsetPages: [Int: Set<Int>] = [:]
    // Testatina corrente di capitolo: per ogni pagina UNA sola candidata (la riga più in
    // alto, sostanziale, corta, in banda superiore), raggruppata per norma e risolta dopo
    // il ciclo con la guardia di ANCORAGGIO posizionale (vedi RUNNING_HEADER_*).
    struct HeaderCandidate { let key: String; let yFrac: Double }
    var headerCandidatesByNorm: [String: [HeaderCandidate]] = [:]
    // Furniture ricorrente generalizzata (qualunque riga corta sostanziale in banda
    // alta/bassa, non solo la topmost): chiave + pagina + frazione-y, per norma
    // roman-aware. Risolta dopo il ciclo col cluster di posizione (vedi FURNITURE_*).
    struct RecurLine { let key: String; let page: Int; let yFrac: Double }
    var recurCandidatesByNorm: [String: [RecurLine]] = [:]

    func track(_ map: inout [String: Set<Int>], _ norm: String, _ pageIndex: Int) {
        map[norm, default: []].insert(pageIndex)
    }

    for page in extraction.pages {
        let height = page.height
        // Candidata-testatina della pagina: la riga PIÙ IN ALTO fra le sostanziali corte
        // in banda superiore (i bare-number/folii sono saltati: non sostanziali).
        var topHeaderKey: String?
        var topHeaderNorm = ""
        var topHeaderYFrac = 0.0
        var topHeaderYTop = -Double.greatestFiniteMagnitude
        for (lineIndex, line) in page.lines.enumerated() {
            let sm = summarizeLine(line)
            if sm.text.utf16.count == 0 { continue }
            let norm = jsTrim(normalizeDigits(sm.text).lowercased())
            let key = "\(page.pageIndex):\(lineIndex)"
            // Bare-number line: a folio candidate, NOT a recurring-norm candidate.
            // It never enters the band/colour/general channels (which would key it
            // under the lumped norm "#"); it is judged solely by the progression
            // pass after the loop. An unparseable bare number (overflows Int) is
            // simply preserved — it is not a page-number folio.
            if norm == BARE_NUMBER_NORM {
                if let value = Int(jsTrim(sm.text)) {
                    folioCandidates.append(FolioCandidate(key: key, page: page.pageIndex, value: value))
                    offsetPages[value - page.pageIndex, default: []].insert(page.pageIndex)
                }
                continue
            }
            // General majority-recurrence applies at any length.
            generalCandidates.append(Candidate(key: key, norm: norm))
            track(&generalPages, norm, page.pageIndex)
            // Band / colour furniture are short headers/footers/markers only.
            if sm.text.utf16.count > FURNITURE_MAX_CHARS { continue }
            let yFrac = height > 0 ? sm.yTop / height : 0.5
            if yFrac >= TOP_BAND || yFrac <= BOTTOM_BAND {
                bandCandidates.append(Candidate(key: key, norm: norm))
                track(&bandPages, norm, page.pageIndex)
            }
            if isSaturated(sm.color) {
                colorCandidates.append(Candidate(key: key, norm: norm))
                track(&colorPages, norm, page.pageIndex)
            }
            // Candidata-testatina: riga sostanziale, banda superiore, più in alto vista
            // finora su questa pagina (la testatina sta SOPRA il contenuto: i sotto-titoli
            // di sezione e le note a piè non sono mai la riga più in alto). ESCLUSIONE: una
            // riga che APRE una regione d'apparato esclusa dal flusso (indice nomi/fonti/
            // sentenze, sommario/indice generale) NON è candidata — il rilevatore d'apparato
            // la usa per aprire la regione (le cui pagine sono comunque escluse dalla
            // lettura). Toglierla qui spezzerebbe quel rilevamento (regressione: l'indice
            // verrebbe letto). Le regioni LETTE (bibliografia, indice analitico) non sono qui.
            if isSubstantial(sm.text), yFrac >= TOP_BAND, sm.yTop > topHeaderYTop,
               !opensExcludedApparatusRegion(sm.text) {
                topHeaderYTop = sm.yTop
                topHeaderKey = key
                topHeaderNorm = norm
                topHeaderYFrac = yFrac
            }
            // Furniture ricorrente generalizzata: ogni riga corta sostanziale, ≤ corpo
            // (le intestazioni vere sono PIÙ GRANDI → escluse), in banda ALTA o BASSA (non
            // solo topmost), per norma roman-aware. Esclusa chi apre una regione d'apparato
            // (come il mattone 1). Risolta dopo il ciclo con l'ancoraggio σ.
            if isSubstantial(sm.text),
               bodySizeForFurniture <= 0 || sm.fontSize <= bodySizeForFurniture + 0.3,
               yFrac >= FURNITURE_TOP_BAND || yFrac <= FURNITURE_BOTTOM_BAND,
               !opensExcludedApparatusRegion(sm.text),
               !looksLikeStructureHeading(sm.text) {
                recurCandidatesByNorm[furnitureNorm(sm.text), default: []].append(
                    RecurLine(key: key, page: page.pageIndex, yFrac: yFrac))
            }
        }
        if let key = topHeaderKey {
            headerCandidatesByNorm[topHeaderNorm, default: []].append(
                HeaderCandidate(key: key, yFrac: topHeaderYFrac))
        }
    }

    let minPages = max(5, Int((Double(extraction.pageCount) * 0.15).rounded(.up)))
    let majorityPages = max(5, Int((Double(extraction.pageCount) * 0.5).rounded(.up)))
    var furniture: Set<String> = []
    for c in bandCandidates where (bandPages[c.norm]?.count ?? 0) >= minPages {
        furniture.insert(c.key)
    }
    for c in colorCandidates where (colorPages[c.norm]?.count ?? 0) >= minPages {
        furniture.insert(c.key)
    }
    for c in generalCandidates where (generalPages[c.norm]?.count ?? 0) >= majorityPages {
        furniture.insert(c.key)
    }
    // Folio progression. An offset is a folio slot when a bare number equal to
    // pageIndex + offset recurs on at least `minPages` DISTINCT pages — the same
    // 15 % recurrence floor the band/colour channels use. The global counter does
    // not reset and tolerates blank divider pages (they simply miss the slot; the
    // surrounding folios still satisfy v = p + offset). Several offsets can
    // qualify when unnumbered inserts shift the printed-page/PDF-page delta along
    // the volume — each stable run keeps its own offset.
    let folioOffsets = Set(offsetPages.compactMap { $0.value.count >= minPages ? $0.key : nil })
    for c in folioCandidates where folioOffsets.contains(c.value - c.page) {
        furniture.insert(c.key)
    }
    // Testatine correnti di capitolo (NUOVO canale, indipendente dal pavimento del 15%).
    // Una candidata-testatina ricorrente su >= RUNNING_HEADER_MIN_PAGES pagine e ANCORATA
    // alla stessa frazione-y (σ < RUNNING_HEADER_POSITION_LOCK) è una testatina corrente:
    // additivo (unione col resto). La doppia guardia — riga PIÙ IN ALTO della pagina +
    // posizione ancorata — esclude per costruzione note a piè (in basso) e sotto-titoli di
    // sezione collassati dalla normalizzazione cifre (mai la riga più in alto). Verificato
    // a ZERO falsi positivi su corpo/note su 10 volumi reali (banco PDFKit).
    for (_, candidates) in headerCandidatesByNorm where candidates.count >= RUNNING_HEADER_MIN_PAGES {
        let ys = candidates.map { $0.yFrac }
        let mean = ys.reduce(0, +) / Double(ys.count)
        let variance = ys.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(ys.count)
        if variance.squareRoot() < RUNNING_HEADER_POSITION_LOCK {
            for c in candidates { furniture.insert(c.key) }
        }
    }
    // Furniture ricorrente generalizzata (additivo, unione col resto). Stessa logica del
    // mattone 1 — ricorrenza ≥ FURNITURE_RECUR_MIN_PAGES pagine + ANCORAGGIO σ <
    // RUNNING_HEADER_POSITION_LOCK su TUTTE le occorrenze — ma applicata a QUALUNQUE riga
    // corta sostanziale in banda alta/bassa (non solo la topmost), con norma roman-aware.
    // Il σ su tutte le occorrenze è la guardia di precisione: una riga di corpo o una nota
    // a piè (y variabile da pagina a pagina) non si ancora mai a σ≈0; solo testatine/folii/
    // footer lo fanno. Se un'INTESTAZIONE vera dello stesso testo comparisse a una y diversa
    // (raggruppata nella stessa norma), il suo outlier alza σ oltre LOCK e l'intera norma NON
    // è rimossa (conservativo: si manca la mobilia ma non si tocca mai il contenuto). Sul
    // campione reale i running-header sono a σ=0.0000 (nessun outlier) → presi senza perdita.
    for (_, lines) in recurCandidatesByNorm {
        let pages = Set(lines.map { $0.page })
        guard pages.count >= FURNITURE_RECUR_MIN_PAGES else { continue }
        let ys = lines.map { $0.yFrac }
        let mean = ys.reduce(0, +) / Double(ys.count)
        let variance = ys.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(ys.count)
        if variance.squareRoot() < RUNNING_HEADER_POSITION_LOCK {
            for c in lines { furniture.insert(c.key) }
        }
    }
    return furniture
}

// MARK: - Classification

func classify(_ line: LineSummary, _ profile: Profile) -> Kind {
    let bodySize = profile.bodySize
    let bodyColor = profile.bodyColor
    let short = line.text.utf16.count <= HEADING_MAX_CHARS
    let ratio = (bodySize > 0 && line.fontSize > 0) ? line.fontSize / bodySize : 0.0

    // Colour-distinct, substantial, at-least-body-size short lines are heading
    // candidates regardless of size (D4).
    let colorHeading = short
        && isSubstantial(line.text)
        && isSaturated(line.color)
        && colorDistance(line.color, bodyColor) > COLOR_DISTANCE_MIN
        && (ratio == 0 || ratio >= COLOR_HEADING_MIN_RATIO)

    if colorHeading {
        if ratio >= HEADING_2_RATIO { return .heading(level: 1) }
        if ratio >= HEADING_3_RATIO { return .heading(level: 2) }
        return .heading(level: 3)
    }

    if ratio == 0 { return .body }

    if short {
        if ratio >= HEADING_1_RATIO { return .heading(level: 1) }
        if ratio >= HEADING_2_RATIO { return .heading(level: 2) }
        if ratio >= HEADING_3_RATIO { return .heading(level: 3) }
        if line.bold && ratio >= HEADING_4_BOLD_RATIO { return .heading(level: 4) }
    }
    if ratio <= NOTE_RATIO { return .note }
    return .body
}

// MARK: - Glossa laterale: discriminazione geometrica (posizione, non sola dimensione)

/// Vero se `sm` (già di taglia-nota: piccola) è una GLOSSA LATERALE: sta tutta
/// FUORI dalla colonna del corpo (a sinistra o a destra), è testo alfabetico vero
/// e non è un numero romano di capitolo. `columnKnown` falso → ASTENSIONE (resta
/// nota): nel dubbio non si scarta. La colonna `[colX0, colX1]` è stimata
/// PER-PAGINA dal chiamante (i margini si alternano recto/verso).
func isLateralGloss(_ sm: LineSummary, colX0: Double, colX1: Double, columnKnown: Bool) -> Bool {
    guard columnKnown else { return false }
    let outside = sm.x1 < colX0 - GLOSS_MARGIN_TOLERANCE || sm.x0 > colX1 + GLOSS_MARGIN_TOLERANCE
    guard outside else { return false }
    guard isSubstantial(sm.text) else { return false }   // ≥2 lettere → esclude folii numerici
    if isRomanNumeralOnly(sm.text) { return false }       // romano di capitolo = furniture, non glossa
    return true
}

/// Mediana di un vettore (robusta agli outlier). 0 su vettore vuoto. Per pari
/// restituisce l'elemento superiore-mediano (sufficiente per la stima di colonna).
func median(_ xs: [Double]) -> Double {
    guard !xs.isEmpty else { return 0 }
    return xs.sorted()[xs.count / 2]
}

/// Vero se il testo (a meno di un punto finale) è composto SOLO da lettere romane
/// `[IVXLCDM]` (numero romano di capitolo/sezione a margine, da non scambiare per
/// glossa). Cap di lunghezza per evitare falsi su parole maiuscole lunghe.
func isRomanNumeralOnly(_ text: String) -> Bool {
    var t = jsTrim(text)
    if t.hasSuffix(".") { t.removeLast() }
    t = jsTrim(t)
    guard !t.isEmpty, t.utf16.count <= 8 else { return false }
    let roman: Set<Character> = ["I", "V", "X", "L", "C", "D", "M"]
    return t.allSatisfy { roman.contains($0) }
}

// MARK: - Front-matter: apparato (scartabile) vs contenuto (protetto)

// L'apparato iniziale del volume — frontespizio/colophon e indice/sommario — è
// navigazione visiva e dati editoriali: tedio per chi ascolta. Si riconosce SOLO
// nella regione iniziale (per non toccare il back-matter, cantiere a parte) e con
// segnali AUTO-IDENTIFICANTI che NON compaiono nella prosa: così la PREFAZIONE /
// INTRODUZIONE / PREMESSA (contenuto vero, prosa) non li matcha mai e resta letta —
// protezione assoluta del contenuto. Nel dubbio: NON apparato (letto).
let FRONT_MATTER_REGION_FRACTION = 0.25
let FRONT_MATTER_REGION_FLOOR = 30
/// Una pagina è indice/sommario se ha almeno così tante righe con leader puntinato.
let INDEX_MIN_LEADER_LINES = 3

/// Pagine [0, limite) in cui si cerca l'apparato di front-matter. Generoso quanto
/// basta a coprire indici lunghi (codici), ma sempre lontano dal back-matter.
func frontMatterRegionLimit(_ pageCount: Int) -> Int {
    max(FRONT_MATTER_REGION_FLOOR, Int(Double(pageCount) * FRONT_MATTER_REGION_FRACTION))
}

/// Pattern di COLOPHON/pagina legale, auto-identificanti (mai in prosa di
/// prefazione): ISBN, "tutti i diritti riservati", "finito di stampare",
/// "© copyright"/"copyright <anno>", SIAE. NON si usano parole legali generiche
/// (copyright/diritti/legge) perché una prefazione può citarle.
private let frontMatterColophonRegex = try! NSRegularExpression(
    pattern: "\\bISBN[\\s:]*\\d|tutti i diritti(\\s+sono)?\\s+riservati|finito di stampare"
        + "|©\\s*copyright|copyright\\s*©|copyright\\s*\\d{4}|©\\s*\\d{4}|\\bS\\.I\\.A\\.E",
    options: [.caseInsensitive])
/// Voce d'indice: leader puntinato (≥4 caratteri-punto, anche spaziati di un
/// soffio). La prosa non ha leader; richiedere ≥3 righe per pagina è la guardia.
private let frontMatterLeaderRegex =
    try! NSRegularExpression(pattern: "[.\u{2026}\u{00B7}](\\s?[.\u{2026}\u{00B7}]){3,}")

private func regexHits(_ re: NSRegularExpression, _ s: String) -> Bool {
    re.firstMatch(in: s, range: NSRange(s.startIndex..<s.endIndex, in: s)) != nil
}
/// Vero se la pagina (sue righe di contenuto) è una pagina di colophon/legale.
func isFrontMatterColophon(_ content: [LineSummary]) -> Bool {
    content.contains { regexHits(frontMatterColophonRegex, $0.text) }
}
/// Vero se la pagina è un indice/sommario (≥ `INDEX_MIN_LEADER_LINES` voci a leader).
func isFrontMatterIndex(_ content: [LineSummary]) -> Bool {
    content.reduce(0) { regexHits(frontMatterLeaderRegex, $1.text) ? $0 + 1 : $0 } >= INDEX_MIN_LEADER_LINES
}

// MARK: - Back-matter: apparato finale (scartabile) vs contenuto (protetto)

// Simmetrico al front-matter (§ docs/BACK_MATTER.md). L'apparato di coda — colophon
// finale, indice/sommario generale ripetuto, indice dei nomi/fonti/sentenze citate —
// è navigazione/dati editoriali: tedio per chi ascolta. Si riconosce SOLO nella
// regione FINALE e con segnali AUTO-IDENTIFICANTI (gli stessi del front-matter: regex
// colophon, leader puntinato) più, per l'indice dei nomi, il TITOLO di sezione.
//
// L'INDICE ANALITICO (per argomento/alfabetico) è RECINTATO: il suo titolo è in
// deny-list, resta LETTO (cantiere INDICE, non toccato — vedi
// docs/ANALYSIS_INDICE_DUE_COLONNE_ORDINE.md). Empiricamente l'analitico è SENZA
// leader (voci con riferimenti inline), quindi il segnale-leader non lo prende mai.
//
// La doppia natura vale anche qui: una APPENDICE/POSTFAZIONE è prosa → non matcha
// nessun segnale → resta LETTA (protezione per costruzione, come la prefazione nel
// front-matter). Nel dubbio: NON apparato (letto).
let BACK_MATTER_REGION_FRACTION = 0.25
let BACK_MATTER_REGION_FLOOR = 30
/// Una pagina di colophon è SPARSA: poche righe di contenuto. La guardia evita di
/// scartare un'intera pagina di corpo (densa) che citasse un marcatore di colophon.
let COLOPHON_MAX_CONTENT_LINES = 20
/// Frazione minima di righe-voce (che finiscono in un riferimento di pagina) perché
/// una pagina conti come "FORTEMENTE strutturata a indice": indice fonti Marotta
/// ~0.5, corpo Marotta ≤0.28. È la soglia per la continuazione di regione senza
/// testatina (le pagine successive dell'indice fonti, senza titolo).
let INDEX_PAGE_MIN_ENTRY_FRACTION = 0.35
/// "DEBOLMENTE strutturata a indice": frazione bassa MA con un numero assoluto alto
/// di righe-voce — le voci multi-riga (Mosconi sentenze: frac ~0.27, ma ~30 righe-voce
/// per pagina). Distingue una pagina d'indice da una pagina di corpo con un titolo
/// ambiguo ("Le fonti" di un capitolo: frac 0.04, 2 righe-voce). Serve a CONFERMARE
/// la testatina/titolo prima di aprire la regione o scartare: un titolo da solo non basta.
let INDEX_PAGE_WEAK_ENTRY_FRACTION = 0.20
let INDEX_PAGE_WEAK_MIN_ENTRIES = 10
/// Servono almeno così tante righe di contenuto perché valga la pena valutare la
/// struttura a indice (sotto: troppo sparsa → astensione, letta).
let INDEX_PAGE_MIN_LINES = 6

/// Pagine [inizio, fine) in cui si cerca l'apparato di coda. Sempre OLTRE la regione
/// di front-matter (niente sovrapposizione) e generosa quanto basta a coprire il
/// colophon dopo un indice analitico lungo. I segnali auto-identificanti danno la
/// precisione; lo scope dà solo il confine.
func backMatterRegionStart(_ pageCount: Int) -> Int {
    let span = max(BACK_MATTER_REGION_FLOOR, Int(Double(pageCount) * BACK_MATTER_REGION_FRACTION))
    return max(frontMatterRegionLimit(pageCount), pageCount - span)
}

/// Natura della regione indice di coda propagata in avanti.
enum BackMatterIndexKind { case nameIndex, analytical }
/// Natura del titolo di sezione riconosciuto su una pagina.
enum BackMatterHeading { case nameIndex, analytical, bibliography }

// `(?:\d{1,4}\s+)?` tollera il FOLIO incollato a inizio testatina ("554 Indice
// cronologico delle sentenze citate"): la testatina RIPETUTA sulle pagine d'indice è
// il segnale più robusto quando le voci sono multi-riga (Mosconi sentenze: ogni voce
// si avvolge su 3-6 righe, solo l'ultima finisce nel riferimento → frazione di
// righe-voce bassa, ~0.27, sotto la soglia di struttura; la testatina la riconosce).
/// Titolo di un indice DEI NOMI / DELLE FONTI / DELLE SENTENZE (apparato, scartabile).
/// Auto-identificante: queste frasi non compaiono come prosa di contenuto. `LE FONTI`
/// è ancorato a fine riga per non matchare "le fonti del diritto" (prosa/heading).
private let backMatterNameIndexHeadingRegex = try! NSRegularExpression(
    pattern: "^\\s*(?:\\d{1,4}\\s+)?("
        + "indice\\s+(dei\\s+nomi|onomastico|degli\\s+autori|delle\\s+fonti"
        + "|(cronologico\\s+)?delle\\s+sentenze|della\\s+giurisprudenza|delle\\s+opere)"
        + "|le\\s+fonti\\s*$|fonti\\s+di\\s+tradizione|giurisprudenza\\s+citata"
        + ")",
    options: [.caseInsensitive])
/// Titolo dell'indice ANALITICO/alfabetico per argomento — RECINTATO: resta letto
/// (sentiero INDICE, non toccato). La deny-list protegge il fence per costruzione.
private let backMatterAnalyticalHeadingRegex = try! NSRegularExpression(
    pattern: "^\\s*(?:\\d{1,4}\\s+)?indice\\s+(analitico|alfabetico)",
    options: [.caseInsensitive])
/// Titolo di BIBLIOGRAFIA / LETTERATURA / RIFERIMENTI: per decisione di prodotto la
/// bibliografia resta LETTA (è prevalentemente per-capitolo, contenuto curato — vedi
/// docs/BACK_MATTER.md). Un titolo di bibliografia CHIUDE ogni regione indice aperta,
/// così una bibliografia che segue un indice nomi non viene mai scartata.
private let backMatterBibliographyHeadingRegex = try! NSRegularExpression(
    pattern: "^\\s*(?:\\d{1,4}\\s+)?(bibliografia|letteratura|riferimenti\\s+bibliografici"
        + "|opere\\s+citate|fonti(\\s|,|\\.|$))",
    options: [.caseInsensitive])
/// Una riga-voce d'indice finisce in un riferimento di pagina: una cifra (con
/// eventuale `s./ss./nt./n.` e punteggiatura di chiusura) a fine riga.
private let indexEntryPageRefRegex = try! NSRegularExpression(
    pattern: "[0-9]\\s*(s{1,2}\\.|n(t)?\\.)?\\s*[.)\\]]?\\s*$")

/// Il titolo di sezione (se presente) tra le righe di contenuto: una riga BREVE che
/// matcha il vocabolario analitico (→ recinto), nomi (→ apre regione scartabile) o
/// bibliografia (→ chiude la regione, resta letta). L'ordine conta: `nomi` PRIMA di
/// `bibliografia` così "LE FONTI"/"FONTI DI TRADIZIONE" (indice fonti) vincono su un
/// titolo generico di bibliografia, mentre "FONTI." isolato (EdD) resta bibliografia.
func backMatterHeadingKind(_ content: [LineSummary]) -> BackMatterHeading? {
    for sm in content {
        let t = jsTrim(sm.text)
        guard t.utf16.count <= 50 else { continue }   // un titolo è corto, non prosa
        if regexHits(backMatterAnalyticalHeadingRegex, t) { return .analytical }
        if regexHits(backMatterNameIndexHeadingRegex, t) { return .nameIndex }
        if regexHits(backMatterBibliographyHeadingRegex, t) { return .bibliography }
    }
    return nil
}

/// Vero se la pagina è strutturata a indice: abbastanza righe, e una frazione
/// significativa finisce in un riferimento di pagina (voce → numero/locus). Distingue
/// una pagina d'indice da una pagina di prosa (appendice) che NON la matcha.
func isBackMatterIndexStructured(_ content: [LineSummary]) -> Bool {
    guard content.count >= INDEX_PAGE_MIN_LINES else { return false }
    let entries = content.reduce(0) { regexHits(indexEntryPageRefRegex, $1.text) ? $0 + 1 : $0 }
    return Double(entries) / Double(content.count) >= INDEX_PAGE_MIN_ENTRY_FRACTION
}

/// DEBOLE: frazione bassa ma molte righe-voce in assoluto (voci multi-riga, Mosconi
/// sentenze). CONFERMA che una pagina col titolo/testatina di indice è davvero un
/// indice, non un capitolo che si apre con un titolo ambiguo ("Le fonti": frac 0.04,
/// 2 righe-voce → fallisce → NON è apparato, resta letto).
func isWeaklyBackMatterIndexStructured(_ content: [LineSummary]) -> Bool {
    guard content.count >= INDEX_PAGE_MIN_LINES else { return false }
    let entries = content.reduce(0) { regexHits(indexEntryPageRefRegex, $1.text) ? $0 + 1 : $0 }
    return entries >= INDEX_PAGE_WEAK_MIN_ENTRIES
        && Double(entries) / Double(content.count) >= INDEX_PAGE_WEAK_ENTRY_FRACTION
}

/// Mappa pagina → categoria d'apparato di coda da scartare: ARTIFACT_STAMP (colophon
/// finale), TOC_GENERAL (indice/sommario a leader), INDEX_ENTRY (indice nomi/fonti/
/// sentenze, ancorato al titolo). Le pagine NON in mappa restano processate
/// normalmente (LETTE): l'indice analitico recintato, ogni prosa (appendice/
/// postfazione), e ogni pagina indice-like senza titolo riconosciuto (astensione).
/// Calcolata una volta come `detectFurniture` e passata a `pageItems` (così il build
/// e `NoteBinding` vedono lo STESSO item per pagina — zip 1:1 invariato).
func detectBackMatterApparatus(
    _ extraction: PdfExtraction, _ furniture: Set<String>
) -> [Int: SemanticCategory] {
    let n = extraction.pageCount
    let start = backMatterRegionStart(n)
    guard start < n else { return [:] }
    var result: [Int: SemanticCategory] = [:]
    // Stato di regione: il titolo dell'indice (nomi vs analitico) è solo sulla prima
    // pagina della sezione; lo si propaga in avanti finché una pagina di prosa
    // (non-indice) chiude la regione, così non si entra mai in una appendice/corpo.
    var region: BackMatterIndexKind?
    for pageIndex in start..<n {
        let page = extraction.pages[pageIndex]
        var content: [LineSummary] = []
        for (lineIndex, line) in page.lines.enumerated() {
            if furniture.contains("\(page.pageIndex):\(lineIndex)") { continue }
            let sm = summarizeLine(line)
            if isNearWhite(sm.color) { continue }
            content.append(sm)
        }
        if content.isEmpty { continue }   // pagina vuota: nessun nodo, regione invariata

        let headingThisPage = backMatterHeadingKind(content)
        let weak = isWeaklyBackMatterIndexStructured(content)
        let strong = isBackMatterIndexStructured(content)
        // Aggiorna la regione dal titolo/testatina di sezione. CRUCIALE: la regione
        // indice-nomi si apre SOLO se la pagina del titolo è ANCHE debolmente strutturata
        // a indice — un titolo ambiguo ("Le fonti" che apre un capitolo, prosa) NON apre
        // la regione e non scarta nulla. L'analitico (recinto) non scarta mai → nessuna
        // guardia; la bibliografia chiude la regione (letta, per decisione).
        switch headingThisPage {
        case .nameIndex where weak: region = .nameIndex
        case .analytical: region = .analytical
        case .bibliography: region = nil
        default: break
        }

        // 1) Colophon finale (sparso) → ARTIFACT_STAMP.
        if content.count <= COLOPHON_MAX_CONTENT_LINES, isFrontMatterColophon(content) {
            result[pageIndex] = .ARTIFACT_STAMP
            continue
        }
        // 2) Regione indice-nomi → INDEX_ENTRY se la pagina è CONFERMATA indice: titolo/
        //    testatina + debolmente strutturata (voci multi-riga, Mosconi sentenze ~0.27
        //    ma ~30 righe-voce), OPPURE fortemente strutturata (indice fonti Marotta ~0.5,
        //    pagine di continuazione senza testatina). La struttura da sola NON distingue
        //    l'indice dal corpo fitto di note (Mosconi corpo ~0.45 > indice ~0.27): è la
        //    regione (titolo esplicito + conferma per-pagina) il discriminatore.
        if region == .nameIndex, (headingThisPage == .nameIndex && weak) || strong {
            result[pageIndex] = .INDEX_ENTRY
            continue
        }
        // 3) Indice/sommario a leader puntinato → TOC_GENERAL. Prima del fence: gli
        //    indici analitici sono SENZA leader, quindi non passano mai di qui (è
        //    invece l'indice cronologico delle leggi a leader → giustamente scartato).
        if isFrontMatterIndex(content) {
            result[pageIndex] = .TOC_GENERAL
            continue
        }
        // 4) Indice analitico RECINTATO → LETTO (mai in mappa). La regione resta aperta.
        if region == .analytical, strong {
            continue
        }
        // 5) Pagina di prosa / non-indice: chiude ogni regione indice aperta, così una
        //    appendice/postfazione che segue un indice NON viene mai scartata.
        if !strong {
            region = nil
        }
    }
    return result
}

// MARK: - Front-matter: recupero degli indici INIZIALI senza leader

// Rifinitura trasversale (riusa il riconoscitore-indici del back-matter sullo scope
// iniziale). Il front-matter già scarta gli indici a leader puntinato (TOC_GENERAL) e
// il colophon; restavano LETTI per astensione gli indici/sommari iniziali SENZA leader
// ("Titolo … pag. NN": Mandrioli, Marotta). Li si recupera con lo STESSO principio del
// back-matter: ancoraggio al TITOLO di sezione (INDICE/SOMMARIO) + guardia di struttura
// (≥ righe-voce: `isWeaklyBackMatterIndexStructured`). Un titolo da solo NON apre la
// regione (lezione "Le fonti"): la PREFAZIONE/INTRODUZIONE/PREMESSA è prosa piena,
// struttura debole fallisce → resta LETTA, protetta per costruzione.

/// Titolo del SOMMARIO/INDICE generale iniziale. `(?:\d{1,4}\s+)?` tollera il folio
/// incollato; ancorato a fine riga così non matcha una frase di prosa che cita "indice".
private let frontMatterTocHeadingRegex = try! NSRegularExpression(
    pattern: "^\\s*(?:\\d{1,4}\\s+)?(indice([\\s-]+(generale|sommario|del\\s+volume))?|sommario)\\s*$",
    options: [.caseInsensitive])

/// Vero se tra le righe di contenuto c'è un titolo BREVE di sommario/indice generale.
func frontMatterTocHeadingPresent(_ content: [LineSummary]) -> Bool {
    content.contains { sm in
        let t = jsTrim(sm.text)
        return t.utf16.count <= 50 && regexHits(frontMatterTocHeadingRegex, t)
    }
}

/// Pagine [0, fmMax) che sono un indice/sommario iniziale SENZA leader (il segnale a
/// leader le manca). Regione aperta da un TITOLO di sommario CONFERMATO dalla struttura
/// (≥ 10 righe-voce, riusa `isWeaklyBackMatterIndexStructured`), propagata finché la
/// struttura tiene. Una pagina di prosa (prefazione/introduzione: struttura debole
/// fallisce) NON apre né continua la regione → resta LETTA. Astensione su tutto il resto.
func detectFrontMatterNoLeaderIndex(
    _ extraction: PdfExtraction, _ furniture: Set<String>, _ fmMax: Int
) -> Set<Int> {
    var result: Set<Int> = []
    var inRegion = false
    for pageIndex in 0..<min(fmMax, extraction.pageCount) {
        let page = extraction.pages[pageIndex]
        var content: [LineSummary] = []
        for (lineIndex, line) in page.lines.enumerated() {
            if furniture.contains("\(page.pageIndex):\(lineIndex)") { continue }
            let sm = summarizeLine(line)
            if isNearWhite(sm.color) { continue }
            content.append(sm)
        }
        if content.isEmpty { continue }   // pagina vuota: regione invariata
        let weak = isWeaklyBackMatterIndexStructured(content)
        // Apre su titolo+struttura; continua su struttura; chiude su prosa (non-struttura).
        if (frontMatterTocHeadingPresent(content) && weak) || (inRegion && weak) {
            inRegion = true
            result.insert(pageIndex)
        } else if !weak {
            inRegion = false
        }
    }
    return result
}

/// Mappa pagina → categoria d'apparato escluso dal flusso: back-matter (colophon/TOC/
/// indice nomi) UNITO al recupero degli indici iniziali senza leader (→ TOC_GENERAL).
/// Calcolata una volta e passata a `pageItems` (build e NoteBinding vedono lo stesso
/// item per pagina). Il colophon/indice-a-leader iniziali restano gestiti per-pagina in
/// `pageItems` (auto-identificanti); qui si aggiunge solo ciò che richiede la regione.
func detectApparatus(_ extraction: PdfExtraction, _ furniture: Set<String>) -> [Int: SemanticCategory] {
    var apparatus = detectBackMatterApparatus(extraction, furniture)
    let fmMax = frontMatterRegionLimit(extraction.pageCount)
    for pageIndex in detectFrontMatterNoLeaderIndex(extraction, furniture, fmMax) {
        apparatus[pageIndex] = .TOC_GENERAL
    }
    return apparatus
}

// MARK: - Node emission

/// Ruolo di un run di righe consecutive. `.gloss` = glossa laterale, categoria
/// propria `MARGINAL_GLOSS` (≠ NOTE): separarla ripulisce l'apparato note dalla
/// conflazione size-only del classificatore.
enum RunRole { case body, note, gloss }

/// One emitted unit of a page, carrying its SOURCE line summaries so a consumer
/// (the note binder) can re-derive span-level signal (marker sizes, note opening
/// numbers) that `summarizeLine` collapses. A `.heading` carries its single line;
/// a `.run` carries the consecutive BODY (or NOTE) lines merged into one node.
/// `pageItems` is the single point of truth for "which lines become which node",
/// shared verbatim by `appendPageNodes` (the build path) and `NoteBinding`.
enum GenItem {
    case heading(LineSummary, level: Int)
    case run(RunRole, [LineSummary])
    /// Apparato di front-matter (colophon → ARTIFACT_STAMP, indice → TOC_GENERAL):
    /// una pagina intera, scartata dal flusso letto ma conservata nell'albero.
    case apparatus(SemanticCategory, [LineSummary])
}

// ── Foglia titoli-Estratto: taglia + struttura, GATED su isEstrattoChrome ─────────
//
// Sui PDF dove PDFKit non risolve i font (Estratto: tutto "Helvetica", niente bold/italic —
// vedi [[debt-lowlevel-font-extraction]]), il discriminatore dei titoli NON può essere il
// font. Resta taglia+struttura, e SOLO in combinazione (la taglia da sola è vicina al corpo).
// Due livelli, robustezza diversa:
//  • CAPITOLO (solido, struttura): un run di corpo TUTTO MAIUSCOLO a taglia distintamente
//    > corpo (≈ corpo×1.04) è il titolo di capitolo → heading di capitolo (le righe del run,
//    già consecutive, sono unite). NON dipende dal numero esatto, è la combinazione caps+taglia.
//  • PARAGRAFO (più debole, taglia+struttura): una riga a taglia-paragrafo (≈ corpo×0.96,
//    banda STRETTA: il corpo-con-richiamo varia 11.4–11.8, il titolo è esattamente ~11.52) che
//    INIZIA con numero-sequenziale + Maiuscola (o "Segue") è il titolo di paragrafo → heading;
//    le righe-continuazione (stessa taglia-stretta, senza nuovo numero) si uniscono. La banda
//    stretta + il prefisso-numero+Maiuscola è il discriminatore (taglia sola NON basta).
// GATED: opera solo se `profile.isEstrattoChrome` (firma CAPITOLO+titolo-maiuscolo->corpo).
// Dove falso → no-op → volumi non-Estratto byte-identici. Gira in `pageItems` (sorgente
// condivisa con NoteBinding e build) così la struttura è coerente per entrambi.

// Banda capitolo STRETTA attorno alla firma esatta dell'Estratto (12.48/12.0 = 1.040). Stretta
// per ESCLUDERE i Giappichelli con CAPITOLO N ma titolo ad altra taglia: Mandrioli ha i titoli a
// 13.02/10.98 = 1.186 e sotto-titoli a 1.093 — entrambi fuori da [1.03, 1.06]. La co-occorrenza
// CAPITOLO + titolo-maiuscolo-IN-QUESTA-BANDA è la firma confinante (gate isEstrattoChrome).
let ESTRATTO_CHAPTER_RATIO_LO = 1.03
let ESTRATTO_CHAPTER_RATIO_HI = 1.06
let ESTRATTO_PARA_RATIO_LO = 0.957
let ESTRATTO_PARA_RATIO_HI = 0.963
let ESTRATTO_TITLE_CAPS_MIN = 0.9
private let ESTRATTO_CAPITOLO_RE = try! NSRegularExpression(pattern: "^CAPITOLO\\s+[IVXLCDM]+$")
/// Titolo di paragrafo: numero sequenziale (1–2 cifre) + spazio + MAIUSCOLA (titolo, o
/// "Segue"). Esclude i numeri-citazione lunghi (3 cifre) e gli inizi minuscoli (date "1 gennaio").
private let ESTRATTO_PARA_NUM_RE = try! NSRegularExpression(pattern: "^\\s*\\d{1,2}\\s+[A-ZÀ-Ý]")

func estrattoIsChapterTitleLine(_ sm: LineSummary, _ body: Double) -> Bool {
    body > 0 && sm.fontSize >= body * ESTRATTO_CHAPTER_RATIO_LO
        && sm.fontSize <= body * ESTRATTO_CHAPTER_RATIO_HI
        && isSubstantial(sm.text) && capsRatioCortina(jsTrim(sm.text)) >= ESTRATTO_TITLE_CAPS_MIN
}
func estrattoIsParaSizeLine(_ sm: LineSummary, _ body: Double) -> Bool {
    body > 0 && sm.fontSize >= body * ESTRATTO_PARA_RATIO_LO
        && sm.fontSize <= body * ESTRATTO_PARA_RATIO_HI
}
func estrattoParaTitleStarts(_ text: String) -> Bool {
    let t = jsTrim(text)
    guard t.utf16.count <= HEADING_MAX_CHARS else { return false }
    return ESTRATTO_PARA_NUM_RE.firstMatch(
        in: t, range: NSRange(t.startIndex..<t.endIndex, in: t)) != nil
}
/// Fonde più righe in una LineSummary sintetica (testo unito, attributi della prima):
/// per emettere un titolo multi-riga come UN heading.
func mergedLine(_ lines: [LineSummary]) -> LineSummary {
    let f = lines[0]
    return LineSummary(
        text: joinLines(lines.map { $0.text }), fontSize: f.fontSize, bold: f.bold,
        italic: f.italic, color: f.color, x0: f.x0, x1: f.x1, yTop: f.yTop, yBottom: f.yBottom,
        width: f.width, height: f.height, spans: f.spans)
}

/// Testo unito di un GenItem (per riconoscere il marcatore "CAPITOLO N").
func estrattoItemText(_ item: GenItem) -> String {
    switch item {
    case .heading(let sm, _): return sm.text
    case .run(_, let lines): return joinLines(lines.map { $0.text })
    case .apparatus(_, let lines): return joinLines(lines.map { $0.text })
    }
}
func estrattoIsCapitoloMarker(_ text: String) -> Bool {
    let t = jsTrim(text)
    return ESTRATTO_CAPITOLO_RE.firstMatch(
        in: t, range: NSRange(t.startIndex..<t.endIndex, in: t)) != nil
}

/// Pre-passo GATED (foglia titoli-Estratto): converte i titoli di capitolo/paragrafo
/// nascosti nei run di corpo in `.heading`. No-op se non è un volume Estratto.
/// Il titolo di capitolo è promosso SOLO se il blocco precedente è "CAPITOLO N" (spec:
/// "il blocco MAIUSCOLO subito dopo il nodo CAPITOLO N"): esclude mezzotitoli/occhielli di
/// front-matter (es. il titolo del libro in copertina) che non seguono un CAPITOLO.
func recognizeEstrattoTitles(_ items: [GenItem], _ profile: Profile) -> [GenItem] {
    guard profile.isEstrattoChrome, profile.bodySize > 0 else { return items }
    let body = profile.bodySize
    var out: [GenItem] = []
    var afterCapitolo = false
    for item in items {
        if estrattoIsCapitoloMarker(estrattoItemText(item)) {   // "CAPITOLO N" → arma la promozione
            out.append(item); afterCapitolo = true; continue
        }
        if case let .run(.body, lines) = item {
            out.append(contentsOf: splitEstrattoBodyRun(lines, body, afterCapitolo: afterCapitolo))
        } else {
            out.append(item)
        }
        afterCapitolo = false
    }
    return out
}

/// Spezza un run di corpo dell'Estratto nei suoi titoli (capitolo / paragrafo) + corpo.
/// La promozione a titolo di CAPITOLO richiede `afterCapitolo` (blocco precedente = "CAPITOLO N");
/// i titoli di PARAGRAFO (taglia-stretta + prefisso-numero) non hanno tale vincolo.
func splitEstrattoBodyRun(_ lines: [LineSummary], _ body: Double, afterCapitolo: Bool) -> [GenItem] {
    var out: [GenItem] = []
    var buf: [LineSummary] = []
    func flush() { if !buf.isEmpty { out.append(.run(.body, buf)); buf = [] } }
    var canChapter = afterCapitolo
    var i = 0
    while i < lines.count {
        let sm = lines[i]
        if canChapter, estrattoIsChapterTitleLine(sm, body) {  // titolo capitolo (caps + >corpo, dopo CAPITOLO)
            flush()
            var j = i
            var title: [LineSummary] = []
            while j < lines.count, estrattoIsChapterTitleLine(lines[j], body) {
                title.append(lines[j]); j += 1
            }
            out.append(.heading(mergedLine(title), level: 2))
            canChapter = false
            i = j; continue
        }
        if estrattoIsParaSizeLine(sm, body), estrattoParaTitleStarts(sm.text) {  // titolo paragrafo
            flush()
            var j = i + 1
            var title: [LineSummary] = [sm]
            // righe-continuazione del titolo: stessa taglia-stretta, senza un NUOVO numero,
            // e non una riga-corpo che finisce con un marcatore di richiamo.
            while j < lines.count, estrattoIsParaSizeLine(lines[j], body),
                  !estrattoParaTitleStarts(lines[j].text),
                  !lineEndsWithCallMarker(lines[j].text) {
                title.append(lines[j]); j += 1
            }
            out.append(.heading(mergedLine(title), level: 3))
            i = j; continue
        }
        buf.append(sm); i += 1
    }
    flush()
    return out
}

private let ESTRATTO_CALL_MARKER_END = try! NSRegularExpression(pattern: "\\s\\d{1,3}$")
/// Vero se la riga finisce con un numero di richiamo isolato (corpo-con-richiamo): NON è
/// continuazione di titolo (i titoli non finiscono con un marcatore di nota).
func lineEndsWithCallMarker(_ text: String) -> Bool {
    let t = jsTrim(text)
    return ESTRATTO_CALL_MARKER_END.firstMatch(
        in: t, range: NSRange(t.startIndex..<t.endIndex, in: t)) != nil
}

/// Derives the ordered emit-items for one page: furniture + invisible-anchor
/// lines skipped, headings standalone, runs of consecutive BODY (or NOTE) lines
/// grouped. One item ⇄ one emitted node, in order — so a per-page zip of items
/// with `document.structure` (filtered by page_index) is exact.
func pageItems(
    _ page: PdfPageExtraction,
    _ profile: Profile,
    _ furniture: Set<String>,
    _ frontMatterMaxPage: Int,
    _ apparatus: [Int: SemanticCategory] = [:]
) -> [GenItem] {
    // Righe di CONTENUTO della pagina: furniture e anchor invisibili tolti subito.
    var content: [LineSummary] = []
    for (lineIndex, line) in page.lines.enumerated() {
        if furniture.contains("\(page.pageIndex):\(lineIndex)") { continue }
        let sm = summarizeLine(line)
        if isNearWhite(sm.color) { continue } // invisible white text (page anchors)
        content.append(sm)
    }

    // FRONT-MATTER APPARATO (solo regione iniziale): una pagina di colophon/legale
    // → ARTIFACT_STAMP; una pagina d'indice/sommario → TOC_GENERAL. Entrambe
    // scartate dal flusso (vedi BuildSegments) ma conservate. La prefazione è prosa:
    // non è colophon (nessun ISBN/©) né indice (niente leader) → resta letta.
    if page.pageIndex < frontMatterMaxPage, !content.isEmpty {
        if isFrontMatterColophon(content) { return [.apparatus(.ARTIFACT_STAMP, content)] }
        if isFrontMatterIndex(content) { return [.apparatus(.TOC_GENERAL, content)] }
    }

    // BACK-MATTER APPARATO (regione finale): la disposizione di pagina è precalcolata
    // in detectBackMatterApparatus (colophon → ARTIFACT_STAMP, indice/sommario a leader
    // → TOC_GENERAL, indice nomi/fonti/sentenze → INDEX_ENTRY). Scartata dal flusso ma
    // conservata. L'indice analitico recintato e ogni prosa NON sono in mappa → lette.
    if let category = apparatus[page.pageIndex], !content.isEmpty {
        return [.apparatus(category, content)]
    }

    let summaries = content

    // Stima della colonna del corpo PER-PAGINA (i margini si alternano recto/verso):
    // bordi sx/dx delle righe alla taglia del corpo e abbastanza larghe. Sotto
    // `MIN_BODY_LINES_FOR_COLUMN` la colonna è incerta → ci si astiene dal glossare.
    //
    // I bordi si stimano per MEDIANA, non per min/max: PDFKit emette su alcune
    // pagine una riga corpo-larga con x0 anomalo (≈9pt, bordo pagina) che, presa col
    // `min`, collassava il bordo-colonna sinistro e faceva SFUGGIRE le glosse vere
    // (es. "Eguaglianza", "Servitù" — colonna stimata a 9 invece di ~85). La mediana
    // ignora l'outlier. È sicuro per costruzione: il bordo destro di una riga di
    // corpo è sempre ≥ colX0, quindi il test glossa `x1 < colX0` non scatta MAI su
    // una riga di corpo, qualunque sia il valore stimato di colX0.
    let body = profile.bodySize
    var bodyX0s: [Double] = []
    var bodyX1s: [Double] = []
    if body > 0 {
        for sm in summaries
        where abs(sm.fontSize - body) <= BODY_SIZE_TOLERANCE
            && sm.width > BODY_COLUMN_MIN_WIDTH_FRACTION * page.width {
            bodyX0s.append(sm.x0)
            bodyX1s.append(sm.x1)
        }
    }
    let columnKnown = bodyX0s.count >= MIN_BODY_LINES_FOR_COLUMN
    let colX0 = median(bodyX0s)
    let colX1 = median(bodyX1s)

    var items: [GenItem] = []
    var runRole: RunRole?
    var runLines: [LineSummary] = []

    func flushRun() {
        if let role = runRole, !runLines.isEmpty {
            items.append(.run(role, runLines))
        }
        runRole = nil
        runLines = []
    }
    func appendToRun(_ role: RunRole, _ sm: LineSummary) {
        if let r = runRole, r != role { flushRun() }
        runRole = role
        runLines.append(sm)
    }

    for sm in summaries {  // già filtrate: niente furniture, niente anchor invisibili
        switch classify(sm, profile) {
        case .heading(let level):
            flushRun()
            items.append(.heading(sm, level: level))
        case .body:
            appendToRun(.body, sm)
        case .note:
            // Una riga di taglia-nota fuori dalla colonna del corpo è una GLOSSA
            // laterale (categoria propria), non una nota; le note vere (in colonna)
            // restano `.note`. Nel dubbio (colonna incerta o riga al confine) →
            // resta `.note` (astensione).
            let role: RunRole =
                isLateralGloss(sm, colX0: colX0, colX1: colX1, columnKnown: columnKnown)
                ? .gloss : .note
            appendToRun(role, sm)
        }
    }
    flushRun()
    // Foglia titoli-Estratto (gated): converte i titoli capitolo/paragrafo nascosti nei run
    // di corpo in heading. No-op (byte-identico) sui volumi non-Estratto.
    return recognizeEstrattoTitles(items, profile)
}

/// Emits the nodes for one page from `pageItems`: headings as standalone nodes,
/// runs of consecutive BODY (or NOTE) lines merged into one paragraph node.
func appendPageNodes(
    _ page: PdfPageExtraction,
    _ profile: Profile,
    _ furniture: Set<String>,
    _ frontMatterMaxPage: Int,
    _ apparatus: [Int: SemanticCategory],
    _ out: inout [NodeDict],
    _ nextId: () -> String
) {
    for item in pageItems(page, profile, furniture, frontMatterMaxPage, apparatus) {
        switch item {
        case .heading(let sm, let level):
            out.append(NodeDict(
                id: nextId(),
                type: headingCategory(level),
                page_index: page.pageIndex,
                text: sm.text,
                level: level
            ))
        case .run(let role, let lines):
            let text = joinLines(lines.map { $0.text })
            let category: SemanticCategory
            switch role {
            case .body: category = .BODY
            case .note: category = .NOTE
            case .gloss: category = .MARGINAL_GLOSS
            }
            var node = NodeDict(
                id: nextId(),
                type: category,
                page_index: page.pageIndex,
                text: text
            )
            if role == .note { node.length_category = lengthCategoryFor(text) }
            out.append(node)
        case .apparatus(let category, let lines):
            out.append(NodeDict(
                id: nextId(),
                type: category,
                page_index: page.pageIndex,
                text: joinLines(lines.map { $0.text })
            ))
        }
    }
}

private func headingCategory(_ level: Int) -> SemanticCategory {
    switch level {
    case 1: return .HEADING_1
    case 2: return .HEADING_2
    case 3: return .HEADING_3
    default: return .HEADING_4
    }
}

// MARK: - Riclassificazione delle famiglie pulite (mai più NOTA: si riclassifica)

// Il classificatore size-only collassa in NOTE alcune unità che DICHIARANO
// meccanicamente il proprio ruolo (maiuscoletto/taglia sotto il corpo). Qui ricevono
// il ruolo giusto a monte, così non producono MAI un "Nota." da zittire a valle —
// è riclassificazione, NON soppressione (≠ `suppressCollapsedHeadingNoteIntros`, il
// cerotto che resta acceso per il nucleo ambiguo). Due famiglie a segnale inequivocabile,
// verificate a ZERO falsi positivi su 26 volumi reali (banco PdfKit, ispezione di OGNI match):
//  • SOMMARIO di capitolo ("SOMMARIO: 1. … – 2. …") → CHAPTER_SUMMARY (letto, senza intro);
//  • intestazione di struttura ("CAPITOLO TERZO", "SEZIONE PRIMA", "CAPITOLO I") → HEADING_n
//    (bonus: navigabile da rotore).
// Il retag è IN POSIZIONE: stesso id/pagina/testo, nessun nodo aggiunto o tolto (così
// l'allineamento per-pagina che `NoteBinding` ricostruisce resta esatto, e il binding
// delle note vere non regredisce — un SOMMARIO/heading non era una nota), testo invariato
// (rete A). I volumi senza queste famiglie restano identici al byte.

// SOMMARIO di capitolo, tre forme della stessa autodichiarazione:
//  • col due punti  → "SOMMARIO:" (eventualmente + elenco inline) — rischio quasi nullo;
//  • secco isolato  → il nodo è ESATTAMENTE "SOMMARIO" (apre l'elenco in nodi fratelli);
//  • elenco inline SENZA due punti → "SOMMARIO 1. Premessa. – 2. …" (il caso dell'Estratto:
//    l'etichetta e l'elenco numerato stanno nello stesso nodo, separati da spazio, non da ":").
// La variante senza colon alza il rischio (la parola potrebbe comparire in corpo/riferimenti),
// perciò la guardia è strutturale: dopo "SOMMARIO" deve esserci due punti, fine-stringa, o uno
// SPAZIO seguito da una CIFRA (l'apertura dell'elenco numerato). Così "SOMMARIO VII" (testatina
// d'indice, romano), "Sommario." (etichetta col punto), "a un sommario esame…" (corpo) e
// "sommario delle decisioni" NON matchano. Il ramo `:` resta identico a prima (no regressione).
private let SOMMARIO_HEADING_RE = try! NSRegularExpression(
    pattern: "^\\s*sommario(?:\\s*:|\\s*$|\\s+\\d)", options: [.caseInsensitive])
/// Keyword in MAIUSCOLO (le intestazioni sono "TITOLO"; il corpo dice "titolo") seguita
/// da un ordinale (romano, cifra, o parola maiuscola tipo "TERZO"/"PRIMA"). La guardia di
/// lunghezza tiene fuori la prosa di corpo che cita "titolo secondo della parte quarta…".
private let STRUCT_HEADING_RE = try! NSRegularExpression(
    pattern: "^(CAPITOLO|CAPO|SEZIONE|PARTE|TITOLO|LIBRO)\\s+([IVXLCDM]+|\\d+|[A-ZÀ-Ý][A-ZÀ-Ý]+)\\b")
let STRUCT_HEADING_MAX_LEN = 70

/// Vero se la riga DICHIARA di essere un'intestazione di struttura (keyword MAIUSCOLA +
/// ordinale, ≤ STRUCT_HEADING_MAX_LEN): è la stessa firma della foglia famiglie-pulite. Usata
/// dal canale furniture come ESCLUSIONE: un'intestazione che si auto-dichiara (es. "CAPITOLO
/// QUINTO", "SEZIONE SECONDA") NON è mai mobilia, anche se ricorre identica in più parti del
/// volume ed è ancorata. Un running-header col folio ("76 Capitolo Secondo") NON inizia con la
/// keyword → non è escluso → resta mobilia.
func looksLikeStructureHeading(_ text: String) -> Bool {
    let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard t.utf16.count <= STRUCT_HEADING_MAX_LEN else { return false }
    return STRUCT_HEADING_RE.firstMatch(in: t, range: NSRange(t.startIndex..<t.endIndex, in: t)) != nil
}

private func structHeadingLevel(_ keyword: String) -> Int {
    switch keyword {
    case "LIBRO", "PARTE", "TITOLO": return 1
    case "SEZIONE": return 3
    default: return 2  // CAPITOLO, CAPO
    }
}

/// Riclassifica in posizione i nodi NOTE che il classificatore size-only ha collassato
/// ma che dichiarano il proprio ruolo: SOMMARIO → CHAPTER_SUMMARY, intestazione di
/// struttura → HEADING_n. Conta i retag per le warning. Deterministica, additiva.
func reclassifyCleanFamilies(_ nodes: inout [NodeDict]) -> (summary: Int, heading: Int) {
    var summaryCount = 0
    var headingCount = 0
    for i in nodes.indices where nodes[i].type == .NOTE {
        let t = (nodes[i].text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let range = NSRange(t.startIndex..<t.endIndex, in: t)
        if SOMMARIO_HEADING_RE.firstMatch(in: t, range: range) != nil {
            nodes[i].type = .CHAPTER_SUMMARY
            nodes[i].length_category = nil  // non è una nota: niente regime acustico
            summaryCount += 1
            continue
        }
        if t.utf16.count <= STRUCT_HEADING_MAX_LEN,
           let m = STRUCT_HEADING_RE.firstMatch(in: t, range: range) {
            let keyword = (t as NSString).substring(with: m.range(at: 1))
            let level = structHeadingLevel(keyword)
            nodes[i].type = headingCategory(level)
            nodes[i].level = level
            nodes[i].length_category = nil
            headingCount += 1
        }
    }
    return (summaryCount, headingCount)
}

/// Numero minimo di ricorrenze (testo normalizzato) perché una NOTE lunga sia una testatina
/// corrente. L'Estratto ha 83 ricorrenze della testatina cap. II, niente fra 2 e 82, e nessuna
/// nota vera ricorre identica → la soglia 5 isola le testatine con ampio margine.
let ESTRATTO_RUNNING_HEADER_MIN_RECUR = 5
/// Numero di pagina del libro in coda alla testatina ("… e processo 55") da ignorare nel
/// confronto di ricorrenza (cambia pagina per pagina; il resto della testatina è identico).
private let ESTRATTO_TRAILING_PAGENO_RE = try! NSRegularExpression(pattern: "\\s+\\d+$")
func estrattoHeaderNormalize(_ text: String) -> String {
    let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return ESTRATTO_TRAILING_PAGENO_RE.stringByReplacingMatches(
        in: t, range: NSRange(t.startIndex..<t.endIndex, in: t), withTemplate: "")
}

/// Reclassifica le testatine correnti ricorrenti (titolo di capitolo recto, lungo, ripetuto su
/// molte pagine) che il cap-caratteri della furniture (`FURNITURE_MAX_CHARS`) lascia passare e
/// che il classificatore size-only colloca in NOTE → falso-"Nota.". Le porta a
/// `ARTIFACT_RUNNING_HEADER` (non-letto, vedi `NON_READ_ROLES`). GATED Estratto: altrove no-op,
/// nodi invariati. Conserva il nodo (cambia solo il TIPO → conteggio invariato → zip
/// `NoteBinding`↔`pageItems` intatto). Guardia anti-perdita-contenuto: solo NOTE LUNGHE (oltre il
/// cap furniture) che ricorrono IDENTICHE (numero pagina a parte) ≥ soglia; una nota vera non
/// ricorre mai identica, quindi nessun contenuto reale è rimosso.
func reclassifyEstrattoRunningHeaders(_ nodes: inout [NodeDict], _ profile: Profile) -> Int {
    guard profile.isEstrattoChrome else { return 0 }
    var counts: [String: Int] = [:]
    for n in nodes where n.type == .NOTE {
        let t = estrattoHeaderNormalize(n.text ?? "")
        if t.utf16.count > FURNITURE_MAX_CHARS { counts[t, default: 0] += 1 }
    }
    let headers = Set(counts.filter { $0.value >= ESTRATTO_RUNNING_HEADER_MIN_RECUR }.map { $0.key })
    guard !headers.isEmpty else { return 0 }
    var reclassified = 0
    for i in nodes.indices where nodes[i].type == .NOTE {
        if headers.contains(estrattoHeaderNormalize(nodes[i].text ?? "")) {
            nodes[i].type = .ARTIFACT_RUNNING_HEADER
            nodes[i].length_category = nil
            reclassified += 1
        }
    }
    return reclassified
}

// MARK: - Text helpers

/// Joins lines into one paragraph, de-hyphenating a word broken at line end.
func joinLines(_ lines: [String]) -> String {
    var out = ""
    for raw in lines {
        let line = jsTrim(raw)
        if line.isEmpty { continue }
        if out.isEmpty {
            out = line
            continue
        }
        if endsWithLetterHyphen(out) {
            out = String(String.UnicodeScalarView(out.unicodeScalars.dropLast())) + stripLeadingWhitespace(line)
        } else {
            out = "\(out) \(line)"
        }
    }
    return out
}

/// True when `s` ends with a `[A-Za-zÀ-ÿ]` letter immediately followed by `-`
/// (the TS regex `/[A-Za-zÀ-ÿ]-$/`).
private func endsWithLetterHyphen(_ s: String) -> Bool {
    let scalars = Array(s.unicodeScalars)
    guard scalars.count >= 2, scalars[scalars.count - 1] == "-" else { return false }
    return isLetterScalar(scalars[scalars.count - 2])
}

/// Removes leading whitespace (the TS `replace(/^\s+/, '')`). `line` is already
/// trimmed here, so this is a no-op kept for fidelity.
private func stripLeadingWhitespace(_ s: String) -> String {
    var view = Substring(s)
    while let first = view.first, first.isWhitespace { view = view.dropFirst() }
    return String(view)
}

/// A heading must carry actual letters, not be a bare marker (≥ 2 letters in the
/// literal range `[A-Za-zÀ-ÿ]`, the TS regex including U+00C0…U+00FF verbatim).
func isSubstantial(_ text: String) -> Bool {
    var count = 0
    for scalar in text.unicodeScalars where isLetterScalar(scalar) {
        count += 1
        if count >= 2 { return true }
    }
    return false
}

/// Matches the literal regex class `[A-Za-zÀ-ÿ]` (ASCII letters plus the
/// Latin-1 supplement range U+00C0…U+00FF, which includes × and ÷ exactly as the
/// TS regex does).
private func isLetterScalar(_ scalar: Unicode.Scalar) -> Bool {
    let v = scalar.value
    return (v >= 0x41 && v <= 0x5A) || (v >= 0x61 && v <= 0x7A) || (v >= 0xC0 && v <= 0xFF)
}

/// Replaces each maximal run of ASCII digits `[0-9]+` with a single `#`
/// (the TS `replace(/\d+/g, '#')`).
func normalizeDigits(_ s: String) -> String {
    var out = ""
    var inDigits = false
    for ch in s {
        if ch.isASCII, ch.isNumber {
            if !inDigits {
                out.append("#")
                inDigits = true
            }
        } else {
            out.append(ch)
            inDigits = false
        }
    }
    return out
}

/// Vero se `t` è un token di numero romano (eventuale punto finale): II, III, IV, XIII…
/// e i singoli V/X/L/C/D/M. Il singolo "I" è ESCLUSO: è una parola italiana comune
/// (articolo) e normalizzarlo confonderebbe norme di corpo. Per la sola furniture-norm.
func isRomanNumeralToken(_ t: String) -> Bool {
    var s = t
    if s.hasSuffix(".") { s.removeLast() }
    guard !s.isEmpty else { return false }
    let roman: Set<Character> = ["I", "V", "X", "L", "C", "D", "M"]
    guard s.allSatisfy({ roman.contains($0) }) else { return false }
    return s.count >= 2 || s != "I"
}

/// Norma per il riconoscimento della furniture ricorrente (testatine/folii): come
/// `normalizeDigits` (cifre → "#") ma normalizza ANCHE i token-numero romani → "#", così
/// "PREMESSA VII"/"PREMESSA VIII" e i folii romani collassano in una norma ricorrente.
/// Locale a questo canale: NON tocca `normalizeDigits` (usato dagli altri canali, invariati).
func furnitureNorm(_ s: String) -> String {
    let withDigits = normalizeDigits(s)
    let tokens = withDigits.split(separator: " ", omittingEmptySubsequences: true).map {
        isRomanNumeralToken(String($0)) ? "#" : String($0)
    }
    return jsTrim(tokens.joined(separator: " ")).lowercased()
}

// MARK: - Colour helpers

func isNearWhite(_ color: String) -> Bool {
    let (r, g, b) = rgb(color)
    return r > 230 && g > 230 && b > 230
}

/// A saturated colour (clearly not a grey/near-grey) reads as structural.
func isSaturated(_ color: String) -> Bool {
    let (r, g, b) = rgb(color)
    return max(r, g, b) - min(r, g, b) > COLOR_SATURATION_MIN
}

func colorDistance(_ a: String, _ b: String) -> Double {
    let (ar, ag, ab) = rgb(a)
    let (br, bg, bb) = rgb(b)
    let dr = Double(ar - br), dg = Double(ag - bg), db = Double(ab - bb)
    return (dr * dr + dg * dg + db * db).squareRoot()
}

/// Parses `#rrggbb` strictly (exactly `#` + 6 ASCII hex); anything else → (0,0,0).
func rgb(_ color: String) -> (Int, Int, Int) {
    guard color.count == 7 else { return (0, 0, 0) }
    let chars = Array(color)
    guard chars[0] == "#" else { return (0, 0, 0) }
    let hex = chars[1...6]
    guard hex.allSatisfy(isAsciiHex) else { return (0, 0, 0) }
    let h = Array(hex)
    let r = Int(String(h[0...1]), radix: 16)!
    let g = Int(String(h[2...3]), radix: 16)!
    let b = Int(String(h[4...5]), radix: 16)!
    return (r, g, b)
}

private func isAsciiHex(_ c: Character) -> Bool {
    ("0"..."9").contains(c) || ("a"..."f").contains(c) || ("A"..."F").contains(c)
}

// MARK: - NOTE acoustic regime + slug

func lengthCategoryFor(_ text: String) -> LengthCategory {
    let length = jsTrim(text).utf16.count
    for (threshold, category) in LENGTH_THRESHOLDS where length < threshold {
        return category
    }
    return .MEGA
}

/// A stable, filesystem-ish id derived from the source file name. Faithful to
/// the TS `slug`: strip the last extension, lowercase, collapse runs of
/// non-`[a-z0-9]` into `_`, strip leading/trailing `_`, fall back to `documento`.
func slug(_ name: String) -> String {
    let base = stripLastExtension(name)
    var out = ""
    var lastWasUnderscore = false
    for ch in base.lowercased() {
        if isAsciiAlphanumeric(ch) {
            out.append(ch)
            lastWasUnderscore = false
        } else if !out.isEmpty, !lastWasUnderscore {
            out.append("_")
            lastWasUnderscore = true
        }
    }
    while out.hasSuffix("_") { out.removeLast() }
    return out.isEmpty ? "documento" : out
}

/// Removes a trailing `.<ext>` (the TS regex `\.[^.]+$`): the last `.` plus the
/// non-dot run to the end, only when that run is non-empty.
private func stripLastExtension(_ name: String) -> String {
    guard let dot = name.lastIndex(of: "."), dot != name.index(before: name.endIndex) else {
        return name
    }
    return String(name[name.startIndex..<dot])
}

private func isAsciiAlphanumeric(_ c: Character) -> Bool {
    ("a"..."z").contains(c) || ("0"..."9").contains(c)
}
