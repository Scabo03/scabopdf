//
//  CodiciPlugin.swift
//  ScaboCore
//
//  Ramo "Codici" — codici legali tascabili Giuffrè Francis Lefebvre "Codici
//  d'udienza" (campioni: Codice civile + c.p.c. + leggi compl., 2697 pp; Codice
//  penale + c.p.p. + leggi compl., 2640 pp). Pipeline PDFsharp 1.31, font
//  PalatinoLinotype 7.5pt, formato tascabile 357×547, **due colonne**.
//
//  ── Perché un ramo dedicato e cosa attacca (foglia 1: navigabilità per articolo) ──
//
//  Per un codice la funzione primaria è "saltare all'articolo N". Mappatura fresca
//  (banco PdfKit reale): l'ordine di lettura a due colonne è GIÀ corretto on-device
//  (PDFKit `page.attributedString` è column-aware — gli articoli escono in sequenza),
//  ma la **navigabilità per articolo è ASSENTE**: ~18.000 marcatori d'articolo sono
//  sepolti dentro nodi BODY giganti, ZERO classificati come heading → il rotore non
//  ha appigli. Causa: il classificatore size-only usa la media-riga; la riga
//  d'articolo «1321. Nozione. – [I]. Il contratto…» ha il numero a 9.0pt ma il resto
//  a 7.5pt → media ≈8.0 → BODY. Il segnale c'è, ma va letto **a livello di span**.
//
//  Questa foglia riconosce il trigger d'articolo allo span e promuove ogni articolo
//  a **HEADING_4** (navigabile dal rotore, `isHeadingRole`), spaccando il run di
//  corpo: header = «NNNN. Rubrica.», corpo = il resto. Il testo non si perde (era già
//  letto nel BODY): cambia il ruolo del numero+rubrica (→ heading) e nasce il confine.
//
//  ── Il segnale (calibrato sul banco PdfKit REALE, non su PyMuPDF) ────────────────
//
//  On-device PDFKit conserva la **dimensione** dello span (numero d'articolo a 9.0pt
//  contro corpo 7.5pt) ma **perde il flag bold** insieme al nome-font (→ Helvetica) —
//  misurato: 7978 righe-articolo col primo span a 9.0pt, bold=false su tutte. Quindi
//  il trigger NON usa il bold: **primo span ≥ corpo×1.13 + testo del primo span =
//  numero puro (`NNNN`, con suffisso bis/ter/…) + la riga intera matcha il pattern
//  d'articolo**. Precisione ~100% su campione sparso (41/41 articoli veri su tutto il
//  volume; suffissi e marcatori «(N)» inclusi), recall ~99% (range contigui).
//
//  ── La porta (`matches`) ─────────────────────────────────────────────────────────
//
//  Gate sul flag `Profile.isCodici` = geometria 357×547 + producer PDFsharp + corpo
//  ≈7.5pt, firma UNIVOCA nel corpus (nessun altro volume è 357×547 PDFsharp). È la
//  firma tecnica più lontana possibile dall'Estratto (Acrobat/TimesNewRoman/483×684):
//  un ramo Codici gated **non può sfiorare l'Estratto né i manuali per costruzione**.
//  On-device il nome-font è perso → firma geometrica, come Cortina/DPC.
//
//  ── Le reti ──────────────────────────────────────────────────────────────────────
//
//  Rete A (nessuna perdita): l'articolo era già letto nel BODY; ora è HEADING_4
//  (numero+rubrica) + BODY (corpo); nessun token sparisce. Rete B: ogni volume
//  non-codice ha `isCodici == false` → `pageItems` byte-identico (Estratto, manuali,
//  riviste, DeJure invariati per costruzione).
//

import Foundation

// MARK: - Costanti della porta + del trigger

/// Formato tascabile dei codici (pt). Univoco nel corpus (con producer PDFsharp).
let CODICI_TRIM_WIDTH = 357.0
let CODICI_TRIM_HEIGHT = 547.0
let CODICI_TRIM_TOLERANCE = 12.0
/// Frammento del producer PDFsharp (auto-dichiarante, esposto da PdfKit via documentAttributes).
let CODICI_PRODUCER_FRAGMENT = "PDFsharp"
/// Il primo span dell'articolo (il numero) è ≥ corpo×questo (corpo 7.5 → soglia 8.47;
/// il numero a 9.0 passa, il corpo a 7.5 no). Bold NON usato (perso col font on-device).
let CODICI_ARTICLE_RATIO = 1.13
/// Livello heading dell'articolo: HEADING_4 (foglia della gerarchia, navigabile dal rotore).
let CODICI_ARTICLE_LEVEL = 4
/// Confidenza assegnata quando la porta codici è soddisfatta.
let CODICI_CONFIDENCE = 0.85

/// Riga d'articolo: numero (con eventuale suffisso bis/ter/… e sotto-indice .N), poi
/// «. » e l'inizio di rubrica/comma (maiuscola, virgoletta, o «[» del comma romano).
let codiciArticleLineRe = try! NSRegularExpression(
    pattern: "^\\d{1,4}([ -](bis|ter|quater|quinquies|sexies|septies|octies|novies|decies))*(\\.\\d+)?\\.\\s*(\\(\\d+\\)\\s*)?[\u{2013}-]?\\s*[«\"\u{201C}A-ZÀ-Ù\\[]")
/// Token-numero puro (il testo del PRIMO span dell'articolo): numero + eventuale suffisso.
let codiciNumberTokenRe = try! NSRegularExpression(
    pattern: "^\\d{1,4}([ -](bis|ter|quater|quinquies|sexies|septies|octies|novies|decies))*$")

private func codiciReMatches(_ re: NSRegularExpression, _ s: String) -> Bool {
    re.firstMatch(in: s, range: NSRange(s.startIndex..<s.endIndex, in: s)) != nil
}

// MARK: - Foglia 2: gerarchia (LIBRO/TITOLO/CAPO/SEZIONE) + furniture testatine
//
// Le testatine e le intestazioni vere condividono il confine: «TITOLO II - …» in cima
// è una testatina ricorrente (forma col trattino+sottotitolo), mentre «TITOLO II» bare
// mid-page è l'intestazione vera. CAPO/SEZIONE sono SEMPRE intestazioni (anche a inizio
// pagina: misurato, le top-band sono UNICHE, non ricorrenti). LIBRO esiste solo come
// testatina (size 10pt, nessuna forma-contenuto) → dedup prima-occorrenza. La furniture
// toglie ARTT-range, banner CODICE e le testatine TITOLO/LIBRO col trattino in cima;
// la gerarchia promuove le intestazioni vere. Precisione nei due sensi (stella polare).

/// Testatina-range d'articolo in cima a ogni pagina: «ARTT. 8-16», «ART. XVIII» (+folio).
let codiciArttHeaderRe = try! NSRegularExpression(pattern: "^ARTT?\\.\\s?(\\d|[IVXLC])")
/// Banner verticale del codice: «CODICE CIVILE», «CODICE PENALE», «CODICE DI PROCEDURA…».
let codiciBannerRe = try! NSRegularExpression(pattern: "^CODICE\\s+[A-ZÀ-Ù]")
/// Testatina corrente di divisione col trattino+sottotitolo (≠ l'intestazione vera, bare
/// per il TITOLO, o assente come forma-contenuto per il LIBRO).
let codiciDivHeaderRe = try! NSRegularExpression(pattern: "^TITOLO\\s+[IVXLC]+\\s*[-\u{2013}]")
/// Intestazione di struttura di un codice: TITOLO/CAPO/SEZIONE + numero romano.
let codiciStructRe = try! NSRegularExpression(pattern: "^(TITOLO|CAPO|SEZIONE)\\s+[IVXLC]+")
/// TITOLO «bare» (solo numero, niente sottotitolo sulla riga) → il sottotitolo è a capo.
let codiciTitoloBareRe = try! NSRegularExpression(pattern: "^TITOLO\\s+[IVXLC]+$")

/// Livello heading dell'intestazione di struttura. Allineato a `structHeadingLevel`
/// del tronco (TITOLO→1, CAPO→2, SEZIONE→3) così le intestazioni promosse dal mio leaf
/// (.body) e quelle promosse da `reclassifyCleanFamilies` (.note) hanno lo STESSO livello.
/// LIBRO è assente come forma-contenuto (solo testatina); ARTICOLO=4 dalla foglia 1.
/// Gerarchia navigabile risultante: TITOLO(1) > CAPO(2) > SEZIONE(3) > ARTICOLO(4).
func codiciStructuralLevel(_ text: String) -> Int? {
    let t = jsTrim(text)
    guard t.utf16.count <= 70, codiciReMatches(codiciStructRe, t) else { return nil }
    if t.hasPrefix("TITOLO") { return 1 }
    if t.hasPrefix("CAPO") { return 2 }
    return 3  // SEZIONE
}

/// Vero se la riga è un sottotitolo plausibile da fondere nel TITOLO (titolo breve,
/// iniziale maiuscola, non struttura/articolo, senza punto finale di frase).
private func codiciIsSubtitle(_ text: String, _ body: Double) -> Bool {
    let t = jsTrim(text)
    guard !t.isEmpty, t.utf16.count <= 60, !t.hasSuffix(".") else { return false }
    guard let f = t.unicodeScalars.first, CharacterSet.uppercaseLetters.contains(f) else { return false }
    if codiciStructuralLevel(t) != nil { return false }
    if codiciReMatches(codiciArticleLineRe, t) { return false }
    return true
}

/// Righe-testatina dei codici da scartare (furniture): range «ARTT. N-M», banner CODICE
/// in cima, testatina TITOLO col trattino in cima. NON il LIBRO (dedup), NON CAPO/SEZIONE,
/// NON il TITOLO bare. Ritorna le chiavi "page:lineIndex". Gated dal chiamante (isCodici).
func codiciFurnitureLines(_ extraction: PdfExtraction) -> Set<String> {
    var furniture: Set<String> = []
    for page in extraction.pages {
        let h = page.height
        for (lineIndex, line) in page.lines.enumerated() {
            let sm = summarizeLine(line)
            let t = jsTrim(sm.text)
            guard !t.isEmpty else { continue }
            let topBand = h > 0 && sm.yTop / h >= TOP_BAND
            let isFurniture =
                codiciReMatches(codiciArttHeaderRe, t)                       // range articoli (sempre)
                || (topBand && codiciReMatches(codiciBannerRe, t))            // banner (in cima)
                || (topBand && codiciReMatches(codiciDivHeaderRe, t))         // testatina TITOLO col trattino
            if isFurniture { furniture.insert("\(page.pageIndex):\(lineIndex)") }
        }
    }
    return furniture
}

// LIBRO: la mappatura fresca mostra che esiste SOLO come testatina corrente (size 10pt,
// nessuna forma-contenuto, nessun divisore) ed è GIÀ tolto dal canale furniture ricorrente
// (recur a posizione-ancorata) → niente inquinamento del rotore, ma nemmeno un'intestazione
// LIBRO. Recuperarlo come heading (esenzione prima-occorrenza dalla furniture) è un follow-up
// di valore modesto, rinviato; la gerarchia naviga su TITOLO/CAPO/SEZIONE (le divisioni-contenuto).

// MARK: - Riconoscimento + split dell'articolo (livello span)

/// Vero se la riga è un trigger d'articolo: primo span non-vuoto a taglia ≥ corpo×1.13,
/// il cui testo è un numero puro, e la riga intera matcha il pattern d'articolo.
func codiciArticleTrigger(_ sm: LineSummary, _ body: Double) -> Bool {
    guard body > 0,
          let first = sm.spans.first(where: { !jsTrim($0.text).isEmpty }),
          first.fontSize >= body * CODICI_ARTICLE_RATIO,
          codiciReMatches(codiciNumberTokenRe, jsTrim(first.text)) else { return false }
    return codiciReMatches(codiciArticleLineRe, jsTrim(sm.text))
}

/// Indice del primo confine rubrica↔corpo: «–» (en-dash, separatore) o «[» (comma
/// romano). NON l'«-» ASCII di fine-riga (sillabazione di parola spezzata, ≠ confine).
private func codiciBoundaryIndex(_ t: String) -> String.Index? {
    for idx in t.indices where t[idx] == "\u{2013}" || t[idx] == "[" { return idx }
    return nil
}
/// Vero se la riga finisce con un trattino di sillabazione (la rubrica continua a capo).
private func codiciWrapsToNextLine(_ t: String) -> Bool {
    guard let last = jsTrim(t).last else { return false }
    return last == "-" || last == "\u{2010}"
}
/// Unisce due frammenti di rubrica de-sillabando: se `a` finisce con «-», lo toglie e
/// concatena senza spazio (parola spezzata); altrimenti concatena con uno spazio.
private func codiciDehyphJoin(_ a: String, _ b: String) -> String {
    if a.isEmpty { return b }
    if a.hasSuffix("-") { return String(a.dropLast()) + b }
    if a.hasSuffix("\u{2010}") { return String(a.dropLast()) + b }
    return a + " " + b
}
/// Numero massimo di righe consumate per la rubrica di un articolo (rubrica corta;
/// backstop anti-over-consume se manca il confine).
private let CODICI_RUBRIC_MAX_LINES = 4

/// Spacca un run di corpo ai trigger d'articolo. L'header (numero + rubrica) può
/// estendersi su più righe quando la rubrica va a capo (de-sillabata): si accumula
/// finché si trova il confine «–»/«[» (→ il resto è corpo) oppure una riga che NON
/// finisce con trattino (rubrica completa). Emette `.heading(level:4)` per ogni header
/// e `.run(.body)` per il corpo fra un articolo e il successivo.
func splitCodiciArticleRun(_ lines: [LineSummary], _ body: Double, role: RunRole = .body) -> [GenItem] {
    var out: [GenItem] = []
    var buf: [LineSummary] = []
    func flush() { if !buf.isEmpty { out.append(.run(role, buf)); buf = [] } }
    var i = 0
    while i < lines.count {
        // Foglia 2 — intestazione di struttura (TITOLO/CAPO/SEZIONE): promossa a heading.
        // Vale su qualunque run (body o note): on-device il bare «TITOLO X» è spesso a
        // taglia-nota, quindi va riconosciuto anche nei run di note.
        if let lvl = codiciStructuralLevel(lines[i].text) {
            flush()
            var headerText = jsTrim(lines[i].text)
            var j = i + 1
            // TITOLO «bare» (numero solo) → fonde il sottotitolo a capo, se plausibile.
            if codiciReMatches(codiciTitoloBareRe, headerText),
               j < lines.count, codiciIsSubtitle(lines[j].text, body) {
                headerText += " - " + jsTrim(lines[j].text)
                j += 1
            }
            var h = lines[i]; h.text = headerText
            out.append(.heading(h, level: lvl))
            i = j
            continue
        }
        // Il trigger d'articolo vale solo nel corpo (le note non aprono articoli).
        guard role == .body, codiciArticleTrigger(lines[i], body) else {
            buf.append(lines[i]); i += 1; continue
        }
        flush()
        var headerText = ""
        var bodyStart: LineSummary?
        var j = i
        let cap = min(lines.count, i + CODICI_RUBRIC_MAX_LINES)
        while j < cap {
            let cur = lines[j].text
            if let b = codiciBoundaryIndex(cur) {                 // confine sulla riga
                headerText = codiciDehyphJoin(headerText, jsTrim(String(cur[cur.startIndex..<b])))
                var bt = String(cur[b...])
                while let f = bt.first, f == "\u{2013}" || f == "-" || f == " " { bt.removeFirst() }
                bt = jsTrim(bt)
                if !bt.isEmpty { var bl = lines[j]; bl.text = bt; bodyStart = bl }
                j += 1
                break
            }
            headerText = codiciDehyphJoin(headerText, jsTrim(cur))  // niente confine: la riga è tutta rubrica
            j += 1
            if !codiciWrapsToNextLine(cur) { break }              // rubrica completa (non finisce a trattino)
        }
        // pulizia di un eventuale «–» o spazio finale residuo dell'header
        headerText = jsTrim(headerText)
        while let last = headerText.last, last == "\u{2013}" || last == " " { headerText.removeLast() }
        var header = lines[i]
        header.text = jsTrim(headerText).isEmpty ? jsTrim(lines[i].text) : jsTrim(headerText)
        out.append(.heading(header, level: CODICI_ARTICLE_LEVEL))
        if let bs = bodyStart { buf.append(bs) }
        i = j
    }
    flush()
    return out
}

/// Foglia 1 dei codici (gated `isCodici`): converte i trigger d'articolo nascosti nei
/// run di corpo in heading navigabili. No-op (byte-identico) ovunque la porta sia falsa.
func recognizeCodiciArticles(_ items: [GenItem], _ profile: Profile) -> [GenItem] {
    guard profile.isCodici, profile.bodySize > 0 else { return items }
    var out: [GenItem] = []
    for item in items {
        if case let .run(.body, lines) = item {
            out.append(contentsOf: splitCodiciArticleRun(lines, profile.bodySize, role: .body))
        } else if case let .run(.note, lines) = item {
            out.append(contentsOf: splitCodiciArticleRun(lines, profile.bodySize, role: .note))
        } else {
            out.append(item)
        }
    }
    return out
}

// MARK: - Il plugin

public final class CodiciPlugin: ExtractionPlugin {
    public let id = "codici"
    public let label = "Codici (Giuffrè tascabili)"

    public func matches(_ extraction: PdfExtraction) -> Double {
        estimateProfile(extraction).isCodici ? CODICI_CONFIDENCE : 0.0
    }

    public func build(_ extraction: PdfExtraction, sourceName: String) -> ScabopdfDocument {
        let profile = estimateProfile(extraction)
        let furniture = detectFurniture(extraction)
        let fmMax = frontMatterRegionLimit(extraction.pageCount)
        let apparatus = detectApparatus(extraction, furniture)
        var nodes: [NodeDict] = []
        var counter = 0
        func nextId() -> String { defer { counter += 1 }; return "node_\(counter)" }
        for page in extraction.pages {
            appendPageNodes(page, profile, furniture, fmMax, apparatus, &nodes, nextId)
        }
        return assembleDocument(extraction, sourceName: sourceName, nodes: nodes,
                                profile: profile, furnitureCount: furniture.count)
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
        let total = extraction.pages.count
        for (index, page) in extraction.pages.enumerated() {
            if isCancelled() { return nil }
            appendPageNodes(page, profile, furniture, fmMax, apparatus, &nodes, nextId)
            onPageClassified(index + 1, total)
        }
        if isCancelled() { return nil }
        return assembleDocument(extraction, sourceName: sourceName, nodes: nodes,
                                profile: profile, furnitureCount: furniture.count)
    }

    private func assembleDocument(
        _ extraction: PdfExtraction, sourceName: String, nodes: [NodeDict],
        profile: Profile, furnitureCount: Int
    ) -> ScabopdfDocument {
        var nodes = nodes
        let reclass = reclassifyCleanFamilies(&nodes)
        _ = reclassifyEstrattoRunningHeaders(&nodes, profile)   // no-op sui codici (gated Estratto)
        let articleCount = nodes.reduce(0) { $0 + ($1.type == .HEADING_4 ? 1 : 0) }
        let titoloCount = nodes.reduce(0) { $0 + ($1.type == .HEADING_2 ? 1 : 0) }
        let capoSezCount = nodes.reduce(0) { $0 + ($1.type == .HEADING_3 ? 1 : 0) }
        var warnings = [
            "plugin:codici:heuristic_extraction_pages_\(extraction.pageCount)_nodes_\(nodes.count)",
            "plugin:codici:article_headings_recognized_\(articleCount)",
            "plugin:codici:structure_titolo_\(titoloCount)_capo_sezione_\(capoSezCount)",
        ]
        if reclass.summary + reclass.heading > 0 {
            warnings.append(
                "plugin:codici:reclassified_chapter_summary_\(reclass.summary)_structure_heading_\(reclass.heading)")
        }
        if furnitureCount > 0 {
            warnings.append("plugin:codici:furniture_lines_removed_\(furnitureCount)")
        }
        return ScabopdfDocument(
            schema_version: SUPPORTED_SCHEMA_VERSION,
            document_id: slug(sourceName),
            metadata: DocumentMetadata(
                pages_pdf: extraction.pageCount, page_size_pt: [0, 0],
                source_pdf_filename: sourceName),
            profile: DocumentProfileDict(
                profile_id: "codici", editorial_family: "giuffre_codici",
                genre: "codice", confidence: matches(extraction)),
            warnings: warnings, transformations: [], structure: nodes)
    }
}

/// Il singleton del plugin (l'identità conta per il dispatcher `===`).
public let codiciPlugin = CodiciPlugin()
