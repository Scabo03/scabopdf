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
/// Page bands (fraction of height) where running furniture lives.
let TOP_BAND = 0.9
let BOTTOM_BAND = 0.1
/// A furniture candidate is short.
let FURNITURE_MAX_CHARS = 60
/// The digit-normalised form of a line whose entire text is one bare number
/// (`normalizeDigits` collapses the single digit run to this). Such lines are
/// routed to folio-by-progression detection instead of the recurring-norm
/// channels — see `detectFurniture`.
let BARE_NUMBER_NORM = "#"

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
        var nodes: [NodeDict] = []
        var counter = 0
        func nextId() -> String {
            defer { counter += 1 }
            return "node_\(counter)"
        }

        for page in extraction.pages {
            appendPageNodes(page, profile, furniture, &nodes, nextId)
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

        var nodes: [NodeDict] = []
        var counter = 0
        func nextId() -> String {
            defer { counter += 1 }
            return "node_\(counter)"
        }

        let total = extraction.pages.count
        for (index, page) in extraction.pages.enumerated() {
            if isCancelled() { return nil }
            appendPageNodes(page, profile, furniture, &nodes, nextId)
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
        var warnings = [
            "plugin:generic:heuristic_extraction_pages_\(extraction.pageCount)_nodes_\(nodes.count)",
        ]
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

    return Profile(bodySize: bodySize, bodyColor: bodyColor)
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
func detectFurniture(_ extraction: PdfExtraction) -> Set<String> {
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

    func track(_ map: inout [String: Set<Int>], _ norm: String, _ pageIndex: Int) {
        map[norm, default: []].insert(pageIndex)
    }

    for page in extraction.pages {
        let height = page.height
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
}

/// Derives the ordered emit-items for one page: furniture + invisible-anchor
/// lines skipped, headings standalone, runs of consecutive BODY (or NOTE) lines
/// grouped. One item ⇄ one emitted node, in order — so a per-page zip of items
/// with `document.structure` (filtered by page_index) is exact.
func pageItems(
    _ page: PdfPageExtraction,
    _ profile: Profile,
    _ furniture: Set<String>
) -> [GenItem] {
    let summaries = page.lines.map { summarizeLine($0) }

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

    for (lineIndex, sm) in summaries.enumerated() {
        if furniture.contains("\(page.pageIndex):\(lineIndex)") { continue }
        if isNearWhite(sm.color) { continue } // invisible white text (page anchors)
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
    return items
}

/// Emits the nodes for one page from `pageItems`: headings as standalone nodes,
/// runs of consecutive BODY (or NOTE) lines merged into one paragraph node.
func appendPageNodes(
    _ page: PdfPageExtraction,
    _ profile: Profile,
    _ furniture: Set<String>,
    _ out: inout [NodeDict],
    _ nextId: () -> String
) {
    for item in pageItems(page, profile, furniture) {
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
