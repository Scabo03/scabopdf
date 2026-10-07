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

/// Inizio di un header d'articolo (numero), per riclassificare HEADING_4 → ARTICLE_HEADER.
let codiciArticleHeadStartRe = try! NSRegularExpression(pattern: "^\\d{1,4}")

/// Divisore di LIBRO nella forma a PAROLE («LIBRO QUARTO»), che apre la prima pagina di
/// ogni libro col sottotitolo all-caps a capo. È l'UNICA forma-contenuto del LIBRO (la
/// forma romana «LIBRO IV - …» è solo testatina, tolta dalla furniture): on-device finisce
/// INCOLLATO in coda al BODY dell'ultimo paragrafo del libro precedente (è a inizio-pagina
/// dove il corpo prosegue). Lo split lo STACCA → pulisce il corpo E dà la radice dell'albero.
let codiciLibroDividerTailRe = try! NSRegularExpression(
    pattern: "\\s+(LIBRO\\s+(?:PRIMO|SECONDO|TERZO|QUARTO|QUINTO|SESTO|SETTIMO|OTTAVO|NONO|DECIMO))\\s*$")

/// Stacca i divisori-LIBRO a parole incollati in coda ai BODY → HEADING_1 sintetici (radice
/// dell'albero). Conia id `node_N` oltre il massimo esistente. Net-MIGLIORAMENTO: toglie il
/// LIBRO dal flusso di corpo (dov'era letto inline) e lo eleva a intestazione. Ritorna quanti.
func recoverCodiciLibroDividers(_ nodes: inout [NodeDict]) -> Int {
    var maxId = -1
    for node in nodes where node.id.hasPrefix("node_") {
        if let v = Int(node.id.dropFirst(5)) { maxId = max(maxId, v) }
    }
    var out: [NodeDict] = []
    out.reserveCapacity(nodes.count + 16)
    var nextId = maxId + 1
    var recovered = 0
    for node in nodes {
        guard node.type == .BODY, let t = node.text, !t.isEmpty,
              let m = codiciLibroDividerTailRe.firstMatch(
                in: t, range: NSRange(t.startIndex..<t.endIndex, in: t)),
              let libroRange = Range(m.range(at: 1), in: t),
              let fullRange = Range(m.range, in: t) else {
            out.append(node); continue
        }
        let libroText = jsTrim(String(t[libroRange]))
        let bodyText = jsTrim(String(t[t.startIndex..<fullRange.lowerBound]))
        if bodyText.isEmpty {
            var libro = node
            libro.type = .HEADING_1; libro.text = libroText; libro.level = 1; libro.length_category = nil
            out.append(libro)
        } else {
            var body = node; body.text = bodyText
            out.append(body)
            out.append(NodeDict(id: "node_\(nextId)", type: .HEADING_1,
                                page_index: node.page_index, text: libroText, level: 1))
            nextId += 1
        }
        recovered += 1
    }
    nodes = out
    return recovered
}

/// Vero se il nodo è il sottotitolo di un TITOLO (la riga-divisione subito sotto «TITOLO X»,
/// es. «Dei contratti in generale», «Il Parlamento»): BODY corto, iniziale maiuscola, non
/// struttura né articolo. Da fondere nell'etichetta del TITOLO.
private func codiciIsTitoloSubtitleNode(_ node: NodeDict) -> Bool {
    guard node.type == .BODY else { return false }
    let t = jsTrim(node.text ?? "")
    guard !t.isEmpty, t.utf16.count <= 60 else { return false }
    guard let f = t.unicodeScalars.first, CharacterSet.uppercaseLetters.contains(f) else { return false }
    if codiciStructuralLevel(t) != nil { return false }
    if t.hasPrefix("LIBRO") || codiciReMatches(codiciArticleLineRe, t) { return false }
    return true
}

/// Normalizza la struttura dei codici sui 5 livelli pieni e annidati (decisione utente):
/// LIBRO=HEADING_1, TITOLO=HEADING_2 (col sottotitolo fuso), CAPO=HEADING_3, SEZIONE=HEADING_4,
/// ARTICOLO=ARTICLE_HEADER (categoria propria, navigabile dal rotore via app). Punto UNICO di
/// verità sui livelli: riallinea qualunque intestazione struttura, comunque promossa
/// (mio leaf .body/.note o `reclassifyCleanFamilies` .note), allo stesso schema → annidamento
/// distinto CAPO > SEZIONE > ARTICOLO. Ritorna i conteggi per il warning diagnostico.
func normalizeCodiciStructure(_ nodes: inout [NodeDict])
    -> (libro: Int, titolo: Int, capo: Int, sezione: Int, article: Int) {
    var n = (libro: 0, titolo: 0, capo: 0, sezione: 0, article: 0)
    // 1. Rilivellamento per testo (struttura) + categoria propria per gli articoli. Il LIBRO
    //    è già HEADING_1 dallo splitter del divisore a parole (recoverCodiciLibroDividers);
    //    qui lo si CONTA per il warning, senza ri-toccarlo.
    for i in nodes.indices {
        let t = jsTrim(nodes[i].text ?? "")
        if nodes[i].type == .HEADING_1, t.hasPrefix("LIBRO") {
            n.libro += 1
        } else if t.utf16.count <= 70, t.hasPrefix("TITOLO"), codiciReMatches(codiciStructRe, t) {
            nodes[i].type = .HEADING_2; nodes[i].level = 2; nodes[i].length_category = nil; n.titolo += 1
        } else if t.utf16.count <= 70, t.hasPrefix("CAPO"), codiciReMatches(codiciStructRe, t) {
            nodes[i].type = .HEADING_3; nodes[i].level = 3; nodes[i].length_category = nil; n.capo += 1
        } else if t.utf16.count <= 70, t.hasPrefix("SEZIONE"), codiciReMatches(codiciStructRe, t) {
            nodes[i].type = .HEADING_4; nodes[i].level = 4; nodes[i].length_category = nil; n.sezione += 1
        } else if nodes[i].type == .HEADING_4, codiciReMatches(codiciArticleHeadStartRe, t) {
            nodes[i].type = .ARTICLE_HEADER; nodes[i].level = nil; nodes[i].length_category = nil; n.article += 1
        } else if nodes[i].type.rawValue.hasPrefix("HEADING_"), t.hasPrefix("TITOLO "),
                  !codiciReMatches(codiciStructRe, t) {
            // «TITOLO» seguito da una parola, non da un numero romano, non è una divisione del codice: è una
            // materia della sezione LEGGI che comincia con la parola «titolo» (es. il titolo esecutivo), che la
            // foglia delle famiglie pulite promuove a H1 quando resta sola. Resta corpo, letta.
            nodes[i].type = .BODY; nodes[i].level = nil; nodes[i].length_category = nil
        }
    }
    // 2. Fusione del sottotitolo nel TITOLO (etichetta unica e informativa per l'albero).
    var fused: [NodeDict] = []
    fused.reserveCapacity(nodes.count)
    var i = 0
    while i < nodes.count {
        var node = nodes[i]
        if node.type == .HEADING_2, codiciReMatches(codiciTitoloBareRe, jsTrim(node.text ?? "")),
           i + 1 < nodes.count, codiciIsTitoloSubtitleNode(nodes[i + 1]) {
            node.text = jsTrim(node.text ?? "") + " - " + jsTrim(nodes[i + 1].text ?? "")
            fused.append(node)
            i += 2
            continue
        }
        fused.append(node)
        i += 1
    }
    nodes = fused
    // 3. Pulizia front-matter: i frammenti di copertina ("CODICE", "CIVILE", gli editori) che il
    //    generico classifica HEADING_1/2 PRIMA del primo nodo strutturale reale sono radici
    //    spurie dell'albero → BODY (testo preservato e letto; via dal rotore e dall'albero).
    if let firstStructural = nodes.firstIndex(where: isCodiciStructuralHeading) {
        for i in 0..<firstStructural where nodes[i].type.rawValue.hasPrefix("HEADING_") {
            nodes[i].type = .BODY; nodes[i].level = nil; nodes[i].length_category = nil
        }
    }
    return n
}

/// Vero se il nodo è una VERA intestazione di struttura dei codici (per testo + livello),
/// non un'intestazione spuria del front-matter (copertina, editori).
func isCodiciStructuralHeading(_ node: NodeDict) -> Bool {
    let t = jsTrim(node.text ?? "")
    switch node.type {
    case .HEADING_1: return t.hasPrefix("LIBRO")
    case .HEADING_2: return t.hasPrefix("TITOLO")
    case .HEADING_3: return t.hasPrefix("CAPO")
    case .HEADING_4: return t.hasPrefix("SEZIONE")
    case .ARTICLE_HEADER: return true
    default: return false
    }
}

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
        // Foglia 5 — il titolo d'apertura di un atto ristampato (solo nel corpo): HEADING_3.
        if role == .body, let end = codiciLawTitleEnd(lines, from: i, body) {
            flush()
            out.append(.heading(mergedLine(Array(lines[i..<end])), level: CODICI_LAW_TITLE_LEVEL))
            i = end
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

// MARK: - Foglia 5 dei codici: il titolo d'apertura delle leggi complementari ristampate
//
// Ogni atto ristampato (nella sezione LEGGI, e le poche ristampe prima di essa: il decreto di coordinamento,
// la legge delega, le disposizioni di attuazione) si apre col suo titolo: la citazione dell'atto (sigla +
// data + numero, o atto dell'Unione «Reg. (UE) n. …»), il trattino, il titolo, il rinvio «(G.U. …)». Sulla
// pagina è alla taglia del corpo, in grassetto (perso sul dispositivo), al margine sinistro della PAGINA
// (x0 ≈ 31, contro 39,7 degli articoli e ≥ 72 delle materie centrate) e largo quanto la pagina: è l'unica
// riga dei codici che attraversa il canalino fra le colonne. Finiva in testa o in coda a un BODY, mai nel
// rotore. Decisione del manutentore (giro «titoli e testatine», 2026-10-07): titolo di TERZO livello.
// Simulato sulle due generazioni prima di scriverlo: penale 213 titoli, civile 93, nessun falso; mancano
// i 3 titoli del penale che PDFKit scombina (A.5).

let CODICI_LAW_TITLE_LEVEL = 3
/// La prima riga sta al margine della pagina (titoli a 31, articoli a 39,7, materie da 72).
let CODICI_LAW_TITLE_MAX_X0 = 36.0
/// …e attraversa il canalino (nessuna riga di colonna arriva oltre il gutter + 5).
let CODICI_LAW_TITLE_MIN_X1 = CODICI_COLUMN_GUTTER_X + 5
/// Una riga «piena» arriva al margine destro della pagina: il titolo continua sotto.
let CODICI_LAW_TITLE_FULL_X1 = 322.0
/// Taglia del corpo: il sommario e l'indice cronologico ripetono le stesse citazioni a 6 pt.
let CODICI_LAW_TITLE_SIZE_TOLERANCE = 0.25
let CODICI_LAW_TITLE_MAX_ROWS = 12

private let codiciLawMonths = "gennaio|febbraio|marzo|aprile|maggio|giugno|luglio|agosto|settembre|ottobre|novembre|dicembre"
private let codiciLawSigla = "(?:L\\.(?:\\s?cost\\.)?|Legge(?:\\s+costituzionale)?|D\\.\\s?lgs\\.|D\\.\\s?l\\.|D\\.\\s?m\\.|"
    + "D\\.\\s?P\\.\\s?R\\.|D\\.\\s?P\\.\\s?C\\.\\s?M\\.|R\\.\\s?d\\.(?:\\s?l\\.)?|Regio\\s+decreto(?:-legge)?|"
    + "Decreto(?:-legge|\\s+legislativo|\\s+del\\s+Presidente\\s+della\\s+Repubblica)?)"
/// Atto nazionale: sigla, giorno (anche «1°»/«1o»), mese, anno, numero facoltativo, poi il trattino del titolo
/// o «, conv.» (decreto-legge convertito).
let codiciLawNationalRe = try! NSRegularExpression(
    pattern: "^\(codiciLawSigla)\\s+\\d{1,2}(?:°|o)?\\s+(?:\(codiciLawMonths))\\s+\\d{4}(?:,\\s+n\\.\\s*\\d+(?:/\\d+)?)?"
        + "(?:\\.\\s*[\u{2013}\u{2014}\u{2012}\u{2015}-]|,\\s*conv\\.)")
/// Atto dell'Unione: «Reg.», «Dir.», «Dec.», «Regolamento», «Direttiva», «Decisione» (anche «quadro»),
/// «(UE)»/«(CE)»/«(CEE)»/«(Euratom)», «n. NNNN/NN».
let codiciLawEuRe = try! NSRegularExpression(
    pattern: "^(?:Reg\\.|Dec\\.|Dir\\.|Regolamento|Direttiva|Decisione)\\s+(?:quadro\\s+)?"
        + "(?:\\((?:UE|CE|CEE|Euratom)\\)\\s+)?(?:n\\.\\s*)?\\d{2,4}/\\d+")

/// Vero se la riga apre citando un atto (nazionale o dell'Unione).
func codiciOpensLawCitation(_ text: String) -> Bool {
    let t = jsTrim(text)
    return codiciReMatches(codiciLawNationalRe, t) || codiciReMatches(codiciLawEuRe, t)
}

/// Taglia del primo span con testo (il grassetto è perso: si guarda la taglia).
private func codiciFirstSpanSize(_ sm: LineSummary) -> Double {
    sm.spans.first(where: { !jsTrim($0.text).isEmpty })?.fontSize ?? sm.fontSize
}

/// Riga FISICA da `i`: PDFKit può spezzare la prima riga in due pezzi sulla stessa linea di base (la
/// citazione e il resto dal trattino), a pochi punti l'uno dall'altro. Ritorna l'indice dopo l'ultimo pezzo,
/// il testo unito e il margine destro.
private func codiciPhysicalRow(_ lines: [LineSummary], from i: Int) -> (end: Int, text: String, x1: Double) {
    var j = i + 1
    var x1 = lines[i].x1
    var parts = [jsTrim(lines[i].text)]
    while j < lines.count, abs(lines[j].yBottom - lines[j - 1].yBottom) <= 1.0,
          lines[j].x0 - lines[j - 1].x1 >= 0, lines[j].x0 - lines[j - 1].x1 <= 8 {
        parts.append(jsTrim(lines[j].text)); x1 = max(x1, lines[j].x1); j += 1
    }
    return (j, parts.joined(separator: " "), x1)
}

/// Se a `i` si apre il titolo di un atto ristampato, ritorna l'indice dopo la sua ultima riga.
func codiciLawTitleEnd(_ lines: [LineSummary], from i: Int, _ body: Double) -> Int? {
    let first = lines[i]
    guard body > 0, first.x0 < CODICI_LAW_TITLE_MAX_X0,
          abs(codiciFirstSpanSize(first) - body) <= CODICI_LAW_TITLE_SIZE_TOLERANCE else { return nil }
    let opening = codiciPhysicalRow(lines, from: i)
    guard opening.x1 > CODICI_LAW_TITLE_MIN_X1, codiciOpensLawCitation(opening.text) else { return nil }
    var text = opening.text
    var lastX1 = opening.x1
    var j = opening.end
    var rows = 1
    while j < lines.count, rows < CODICI_LAW_TITLE_MAX_ROWS {
        let q = lines[j]
        guard abs(q.x0 - first.x0) <= 2,
              abs(codiciFirstSpanSize(q) - body) <= CODICI_LAW_TITLE_SIZE_TOLERANCE,
              !codiciArticleTrigger(q, body), codiciStructuralLevel(q.text) == nil else { break }
        // continua solo dopo una riga piena, o finché la parentesi «(G.U. …» resta aperta
        let open = text.filter { $0 == "(" }.count > text.filter { $0 == ")" }.count
        guard lastX1 >= CODICI_LAW_TITLE_FULL_X1 || open else { break }
        let row = codiciPhysicalRow(lines, from: j)
        text += " " + row.text
        lastX1 = row.x1
        j = row.end
        rows += 1
    }
    return j
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

// MARK: - Foglia 4 dei codici: de-interfoliazione delle due colonne (gated isCodici)
//
// PROBLEMA. Su ~4% delle pagine dei due codici l'estrazione PDFKit consegna le
// righe delle DUE colonne ALTERNATE (riga sinistra, riga destra, riga sinistra,
// …). La ricomposizione delle parole sillabate incolla allora frammenti di
// colonne diverse e FABBRICA parole inesistenti («pree» = «pre-»+«e)»,
// «prolisente» = «proli-»+«sente») — violazione della rete di fedeltà C. Sul
// ~92% delle pagine l'estrazione è già colonna-corretta (colonna sinistra
// intera per y, poi destra).
//
// CURA. Partizione STABILE per colonna: [righe della colonna sinistra nel loro
// ordine] + [righe della colonna destra nel loro ordine]. I codici sono a
// lettura colonna-maggiore, quindi questa partizione ricostruisce l'ordine di
// stampa; ed è IDENTITÀ sulle pagine già colonna-corrette (la colonna destra è
// già un blocco contiguo → la partizione non la muove). NON un ordinamento per
// y, che riordinerebbe testatine e folii rompendo la byte-identità.
//
// GUTTER calibrato dall'istogramma x0 dei due codici (357pt di larghezza): la
// colonna destra del CORPO inizia a x0 = 184; la banda [181,183] è vuota; tutto
// ciò che sta sotto 182 (colonna sinistra a 31, testatine centrate, capilettera,
// la testatina di destra «CEDU» a 170, e la colonna destra della TABELLA dei
// ministeri a 180.2) resta «non-destra». Il gutter a 182 separa quindi la
// colonna-destra-di-CORPO da tutto il resto, ed esclude per costruzione la
// tabella-ministeri (impaginato speciale, non interfoliazione).
//
// RILEVATORE. Una pagina è interfogliata quando ha ≥3 GIUNZIONI DI SILLABA FRA
// COLONNE DIVERSE (riga che finisce con «-» seguita da una riga dell'altra
// colonna): è il segnale DIRETTO della fabbricazione, esclude le tabelle (le
// celle non sillabano fra colonne), le pagine pulite (≤2: i confini di flusso
// legittimi corpo/note) e le testatine-folio (non hanno «-»). Calibrato sui due
// codici: flagga 61 pagine del penale e 24 del civile, tutte zipper veri
// (colonna destra in ≥3 blocchi); zero pagine pulite. La banda «2 giunzioni»
// (pagine pulite corpo+note) è lasciata come residuo dichiarato, non toccata.

let CODICI_COLUMN_GUTTER_X = 182.0
let CODICI_INTERLEAVE_MIN_COUPLINGS = 3

/// 0 = colonna sinistra (e tutto ciò che non è colonna-destra-di-corpo),
/// 1 = colonna destra del corpo (x0 ≥ gutter).
func codiciLineColumn(_ line: PdfTextLine) -> Int {
    line.bbox.x >= CODICI_COLUMN_GUTTER_X ? 1 : 0
}

/// Vero se la pagina è interfogliata (≥ soglia di giunzioni di sillaba fra
/// colonne diverse). Conta sulle righe con contenuto.
func codiciPageIsInterleaved(_ page: PdfPageExtraction) -> Bool {
    let lines = page.lines.filter { !$0.spans.isEmpty }
    guard lines.count >= 4 else { return false }
    var couplings = 0
    for i in 0..<(lines.count - 1) {
        let text = lines[i].spans.map { $0.text }.joined()
            .trimmingCharacters(in: .whitespaces)
        if text.hasSuffix("-"), codiciLineColumn(lines[i]) != codiciLineColumn(lines[i + 1]) {
            couplings += 1
            if couplings >= CODICI_INTERLEAVE_MIN_COUPLINGS { return true }
        }
    }
    return false
}

/// GUARDIA ANTI-DESYNC (residuo dichiarato). Una riga di PROSA (nota/corpo, fs in
/// [6.0, 8.2]) il cui x0 cade nella terra di nessuno fra le colonne [90, gutter)
/// è quasi sempre vittima del desync geometrico di PDFKit (INBOX A.5: bbox errato
/// che sposta la coda di una colonna): il gutter la misclassifica come colonna
/// sbagliata, e il riordino accoppierebbe male le sillabe fabbricando parole
/// (es. «prostitu-»|«munire» → «prostitumunire» su p.1810 del penale, dove la
/// coda «zione» della colonna destra è estratta a x0=157.8). Una pagina con anche
/// una sola riga di prosa così NON si riordina: la sicurezza dei codici (materiale
/// quotidiano) viene prima della copertura totale. Le intestazioni centrate
/// (fs ≥ 8.5) e i numeri d'articolo (fs 9) non sono prosa → non attivano la
/// guardia. Misura: esclude 16 pagine del penale e 8 del civile (residuo),
/// azzerando le fabbricazioni sulle pagine curate.
func codiciPageHasStrandedProse(_ page: PdfPageExtraction) -> Bool {
    for line in page.lines where !line.spans.isEmpty {
        let fontSize = line.spans[0].fontSize
        let x0 = line.bbox.x
        if fontSize >= 6.0, fontSize <= 8.2, x0 >= 90.0, x0 < CODICI_COLUMN_GUTTER_X {
            return true
        }
    }
    return false
}

/// De-interfoglia le sole pagine interfogliate E prive di prosa desincronizzata,
/// con una partizione stabile per colonna. Le altre pagine (non interfogliate, o
/// con una riga di prosa nella terra di nessuno) sono ritornate INVARIATE
/// (identità). Idempotente: una pagina già partizionata ha la colonna destra
/// contigua → non è più interfogliata → invariata. Nessuna riga persa (la
/// partizione include tutte le righe, anche quelle con spans vuoti). Gated dal
/// chiamante (invocata solo in contesto isCodici).
func deinterleaveCodiciColumns(_ extraction: PdfExtraction) -> PdfExtraction {
    var out = extraction
    for i in out.pages.indices
    where codiciPageIsInterleaved(out.pages[i]) && !codiciPageHasStrandedProse(out.pages[i]) {
        let lines = out.pages[i].lines
        out.pages[i].lines = lines.filter { codiciLineColumn($0) == 0 }
            + lines.filter { codiciLineColumn($0) == 1 }
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

    public func build(_ rawExtraction: PdfExtraction, sourceName: String) -> ScabopdfDocument {
        let profile = estimateProfile(rawExtraction)
        // De-interfoliazione delle due colonne PRIMA di ogni consumo (furniture,
        // pageItems, assemble): l'intera catena vede l'ordine colonna-maggiore.
        let extraction = deinterleaveCodiciColumns(rawExtraction)
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
        _ rawExtraction: PdfExtraction,
        sourceName: String,
        onPageClassified: (_ done: Int, _ total: Int) -> Void,
        isCancelled: () -> Bool
    ) -> ScabopdfDocument? {
        if isCancelled() { return nil }
        let profile = estimateProfile(rawExtraction)
        let extraction = deinterleaveCodiciColumns(rawExtraction)
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
        // Radice dell'albero: stacca i divisori-LIBRO a parole incollati in coda ai BODY → H1.
        let libroRecovered = recoverCodiciLibroDividers(&nodes)
        // Normalizza i 5 livelli pieni: LIBRO=H1, TITOLO=H2 (sottotitolo fuso), CAPO=H3,
        // SEZIONE=H4, ARTICOLO=ARTICLE_HEADER (categoria propria, navigabile dal rotore via app).
        let s = normalizeCodiciStructure(&nodes)
        _ = libroRecovered
        var warnings = [
            "plugin:codici:heuristic_extraction_pages_\(extraction.pageCount)_nodes_\(nodes.count)",
            "plugin:codici:articles_\(s.article)",
            "plugin:codici:structure_libro_\(s.libro)_titolo_\(s.titolo)_capo_\(s.capo)_sezione_\(s.sezione)",
        ]
        if reclass.summary + reclass.heading > 0 {
            warnings.append(
                "plugin:codici:reclassified_chapter_summary_\(reclass.summary)_structure_heading_\(reclass.heading)")
        }
        if furnitureCount > 0 {
            warnings.append("plugin:codici:furniture_lines_removed_\(furnitureCount)")
        }
        let lawTitles = nodes.filter { $0.type == .HEADING_3 && codiciOpensLawCitation($0.text ?? "") }.count
        if lawTitles > 0 { warnings.append("plugin:codici:law_titles_\(lawTitles)") }
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
