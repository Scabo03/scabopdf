//
//  NumberedTitles.swift
//  ScaboCore
//
//  Canale dei TITOLI NUMERATI nel tronco (giro di cura 2026-10-05, vedi
//  docs/DIAGNOSI_INTESTAZIONI.md e docs/CURA_INTESTAZIONI.md).
//
//  ── Il difetto ─────────────────────────────────────────────────────────────────
//
//  Il classificatore del tronco (`classify`) promuove un'intestazione solo per TAGLIA
//  (≥ corpo×1.12) o colore, o per grassetto ≥ corpo×1.04 — ma PDFKit on-device perde il
//  grassetto sulle filiere editoriali dei manuali. Sui manuali italiani il titolo di
//  paragrafo sta a +4…+9% del corpo («2. Il reticolo di fatti…» 12,48 su 11,5): resta corpo,
//  inghiottito nel blocco, invisibile alla navigazione, e le note lunghe — differite al
//  prossimo nodo intestazione — scivolano fino al capitolo (Rizzo: mediana 37,5 pagine).
//
//  ── Il canale ──────────────────────────────────────────────────────────────────
//
//  Segnale PRIMARIO: la numerazione puntata in apertura di riga, a profondità arbitraria
//  («N.», «N.M.», «N.M.K.», …, eventualmente preceduta da «§»), col PUNTO FINALE dopo
//  l'ultimo numero, seguita da una maiuscola o da un'apertura di citazione/parentesi.
//  Componenti oltre il primo di 1-2 cifre (esclude importi «1.000» e anni «12.3.2010»).
//
//  Segnale di SUPPORTO, la taglia del NUMERO (primo span, non la media di riga: un titolo
//  in maiuscoletto ha la media più bassa — Costituzionale «1. CHE COS'È…» 11,52 vs media
//  9,63), con soglia bassa:
//   • numero ≥ corpo×1.03 → titolo (qualunque profondità), con le sue righe di
//     continuazione alla stessa taglia;
//   • numero alla taglia del corpo (±3%) → titolo SOLO se la numerazione ha ≥ 2 livelli
//     (una sequenza puntata «4.1.» o «5.3.1.» non si confonde con una cifra isolata) E la
//     riga è CORTA (finita per scelta, non per giustezza: < 85% della colonna) E non chiude
//     con «,» «;» «:» — così un paragrafo di prosa numerato («1.1. Le riflessioni che qui
//     propongo…», a tutta giustezza) resta corpo;
//   • numero alla taglia del corpo, ≥ 2 livelli, titolo su PIÙ righe → solo se preceduto da uno
//     stacco verticale, composto a rientro sporgente (righe successive rientrate rispetto al
//     numero) e chiuso da una riga corta entro 4 righe (Rizzo «2.1.1. Certezze e dubbi…»).
//
//  GUARDIE (ognuna nata da un caso che il canale potrebbe rovinare, verificato sul corpus):
//   • apertura di blocco: la riga precedente del run chiude con punteggiatura forte, o c'è
//     uno stacco verticale, o è la prima del run — un numero a capo dentro una frase no;
//   • voce d'indice: numero di pagina in coda alla taglia della riga, o leader puntinato → no
//     (i richiami di nota in apice, più piccoli, non contano);
//   • lunghezza da titolo (≤ HEADING_MAX_CHARS sulla prima riga, ≤ 300 in totale);
//   • lettere vere (`isSubstantial`);
//   • testo dopo il numero almeno alla taglia del corpo (testatina «folio grande + nome piccolo»);
//   • GATE: spento sui codici (commi «1.», «2.» e articoli sono del ramo codici) e sulla
//     Rivista DPC (abstract e paragrafi numerati di prosa; esclusa come per la fusione titoli).
//  Le righe di corpo con numero alla taglia del corpo e profondità 1 («1. Ai fini…»,
//  enumerazioni, rinvii a capo) restano SEMPRE corpo: nel dubbio non si promuove.
//
//  ── Il livello ──────────────────────────────────────────────────────────────────
//
//  Relativo alla gerarchia GIÀ riconosciuta, calcolato all'emissione dai nodi precedenti in
//  ordine di documento (`numberedTitleLevel`): fratello alla stessa profondità → stesso
//  livello; sotto un titolo numerato meno profondo → +differenza di profondità; altrimenti
//  sotto il capitolo/sezione non numerato più vicino → +profondità. Tetto HEADING_4.
//
//  ── Dove vive ───────────────────────────────────────────────────────────────────
//
//  Dentro `pageItems` (sorgente unica di «quali righe diventano quale nodo»), dopo le foglie
//  gated (Estratto, Giappichelli §, codici) e prima della fusione titoli: build e aggancio
//  note (`bindAndPlaceNotes`, zip nodi↔item per pagina) vedono la stessa scomposizione. Il
//  titolo SPEZZA il run di corpo (corpo-prima | titolo | corpo-dopo): il confine c'è davvero.
//

import Foundation

/// Soglia di supporto della taglia del NUMERO rispetto al corpo (titolo «piccolo»).
let NUMBERED_TITLE_SIZE_RATIO = 1.03
/// Banda «taglia del corpo» per i titoli a numerazione multipla senza delta di taglia.
let NUMBERED_TITLE_BODY_BAND = 0.97
/// Una riga è «corta» (finita per scelta) se lascia libero più del 15% della colonna a destra.
let NUMBERED_TITLE_SHORT_LINE_FRACTION = 0.85
/// Tolleranza (pt) di taglia per le righe di continuazione di un titolo.
let NUMBERED_TITLE_CONT_TOLERANCE = 0.35
/// Lunghezza massima del titolo intero (righe di continuazione comprese).
let NUMBERED_TITLE_MAX_TOTAL = 300
/// Righe massime di un titolo multiplo a taglia-corpo (rientro sporgente).
let NUMBERED_TITLE_MAX_LINES = 4
/// Rientro sporgente minimo (pt) delle righe di continuazione rispetto alla riga del numero.
let NUMBERED_TITLE_HANGING_MIN = 5.0

/// Numerazione puntata in apertura: «§»? + N(.M)* + «.» + spazio + incipit maiuscolo/citazione.
private let NUMBERED_TITLE_RE = try! NSRegularExpression(
    pattern: "^\\s*(?:§\\s*)?(\\d{1,3}(?:\\.\\d{1,2})*)\\.\\s+[A-ZÀ-Ý«“\"‘'(]")
/// Numero di pagina in coda (voce d'indice) e leader puntinato.
private let NUMBERED_TITLE_TRAILING_PAGE_RE = try! NSRegularExpression(pattern: "\\s\\d{1,4}\\s*$")
private let NUMBERED_TITLE_LEADER_RE = try! NSRegularExpression(
    pattern: "[.\u{2026}\u{00B7}](\\s?[.\u{2026}\u{00B7}]){3,}")
/// Punteggiatura forte che chiude un blocco (la riga dopo può aprire un titolo).
private let BLOCK_END_RE = try! NSRegularExpression(pattern: "[.!?:;»”)\\]]\\s*$")

/// Profondità della numerazione puntata in apertura (`"5.3.1. Titolo"` → 3), o nil.
func numberedTitleDepth(_ text: String) -> Int? {
    let t = jsTrim(text)
    let range = NSRange(t.startIndex..<t.endIndex, in: t)
    guard let m = NUMBERED_TITLE_RE.firstMatch(in: t, range: range),
          let r = Range(m.range(at: 1), in: t) else { return nil }
    return t[r].split(separator: ".").count
}

private func matches(_ re: NSRegularExpression, _ s: String) -> Bool {
    re.firstMatch(in: s, range: NSRange(s.startIndex..<s.endIndex, in: s)) != nil
}

/// Taglia del NUMERO: primo span non vuoto (fallback la media di riga).
private func leadingSpanSize(_ sm: LineSummary) -> Double {
    for span in sm.spans where !span.text.trimmingCharacters(in: .whitespaces).isEmpty
        && span.fontSize > 0 {
        return span.fontSize
    }
    return sm.fontSize
}

/// Taglia dello span più grande con testo (riga di continuazione di un titolo).
private func maxSpanSize(_ sm: LineSummary) -> Double {
    sm.spans.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
        .map { $0.fontSize }.max() ?? sm.fontSize
}

/// Vero se, dopo il numero, almeno uno span di testo arriva alla taglia del corpo (−3%).
private func textReachesBody(_ sm: LineSummary, body: Double) -> Bool {
    let letterSpans = sm.spans.filter { $0.text.contains { $0.isLetter } }
    guard let maxSize = letterSpans.map({ $0.fontSize }).max() else { return false }
    return maxSize >= body * NUMBERED_TITLE_BODY_BAND
}

/// Vero se la riga porta lettere in uno span alla taglia del corpo (± 0,25 pt).
private func hasBodySizedText(_ sm: LineSummary, body: Double) -> Bool {
    sm.spans.contains { span in
        abs(span.fontSize - body) <= 0.25 && span.text.contains { $0.isLetter }
    }
}

/// Vero se la riga finisce con un numero di pagina alla taglia del testo (voce d'indice), non
/// con un richiamo di nota in apice (più piccolo del testo).
private func endsWithIndexPageNumber(_ sm: LineSummary) -> Bool {
    let t = jsTrim(sm.text)
    guard matches(NUMBERED_TITLE_TRAILING_PAGE_RE, t) else { return false }
    guard let last = sm.spans.last(where: { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty })
    else { return true }
    let ref = leadingSpanSize(sm)
    return last.fontSize >= ref * 0.9
}

/// Vero se `sm` apre un blocco rispetto alla riga precedente del run (o non ce n'è).
private func opensBlock(_ sm: LineSummary, after prev: LineSummary?) -> Bool {
    guard let prev else { return true }
    // Stacco verticale: interlinea della riga precedente ben superata (origine in basso).
    let gap = prev.yBottom - sm.yTop
    if gap > max(prev.height, sm.height) * 0.5 { return true }
    let p = jsTrim(prev.text)
    // Un punto dopo un'abbreviazione di citazione («art.», «n.», «cfr.») NON chiude: la riga
    // numerata che segue è la continuazione della citazione («…dall'art. | 12. Il giudice…»).
    if endsWithCitationAbbreviation(p) { return false }
    return matches(BLOCK_END_RE, p)
}

/// Vero se il testo finisce con «<abbreviazione>.» della lista chiusa delle citazioni (o con
/// una singola iniziale), cioè con un punto che non chiude la frase.
private func endsWithCitationAbbreviation(_ t: String) -> Bool {
    guard t.hasSuffix(".") else { return false }
    let chars = Array(t.dropLast())
    var i = chars.count - 1
    while i >= 0, chars[i].isLetter || chars[i] == "." { i -= 1 }
    let token = String(chars[(i + 1)...]).lowercased()
    let letters = token.filter { $0.isLetter }
    if letters.isEmpty { return false }
    if letters.count == 1 { return true }
    return SENTENCE_ABBREVIATIONS.contains(token) || SENTENCE_ABBREVIATIONS.contains(String(letters))
}

/// Pre-passo del tronco: promuove i titoli numerati nascosti nei run di corpo. `colWidth` è la
/// giustezza stimata della colonna del corpo della pagina (0 se ignota → niente titoli a
/// taglia-corpo, che ne hanno bisogno).
func recognizeNumberedTitles(
    _ items: [GenItem], _ profile: Profile, colWidth: Double, colX1: Double
) -> [GenItem] {
    /// Riga CORTA = finita per scelta: il suo bordo destro resta lontano dal bordo destro della
    /// colonna (misurato sul margine destro, non sulla larghezza: le righe a rientro sporgente
    /// sono più strette anche quando sono piene — Elementi UE «34.2. …», rientro 35 pt).
    func endsBeforeMargin(_ l: LineSummary) -> Bool {
        colX1 - l.x1 > (1 - NUMBERED_TITLE_SHORT_LINE_FRACTION) * colWidth
    }
    /// Titolo su una riga: corta per larghezza O per margine destro (un titolo rientrato
    /// all'inizio può arrivare vicino al margine pur essendo una riga finita per scelta).
    func isShortSingle(_ l: LineSummary) -> Bool {
        l.width < NUMBERED_TITLE_SHORT_LINE_FRACTION * colWidth || endsBeforeMargin(l)
    }
    let body = profile.bodySize
    guard body > 0, !profile.isCodici, !profile.isRivistaDpc else { return items }
    var out: [GenItem] = []
    for item in items {
        guard case let .run(.body, lines) = item else { out.append(item); continue }
        var buf: [LineSummary] = []
        func flush() { if !buf.isEmpty { out.append(.run(.body, buf)); buf = [] } }
        var i = 0
        while i < lines.count {
            let sm = lines[i]
            let prev: LineSummary? = i > 0 ? lines[i - 1] : nil
            guard let depth = numberedTitleDepth(sm.text),
                  sm.text.utf16.count <= HEADING_MAX_CHARS,
                  isSubstantial(sm.text),
                  !endsWithIndexPageNumber(sm),
                  !matches(NUMBERED_TITLE_LEADER_RE, sm.text),
                  opensBlock(sm, after: prev),
                  // Il TESTO dopo il numero arriva almeno alla taglia del corpo (in maiuscoletto,
                  // le maiuscole): una testatina con folio grande e nome piccolo («2. Roberto
                  // Sacchi», numero 14 pt, nome 9 su corpo 11 — rivista 1720-951X) non è titolo.
                  textReachesBody(sm, body: body)
            else { buf.append(sm); i += 1; continue }
            let size = leadingSpanSize(sm)
            if size >= body * NUMBERED_TITLE_SIZE_RATIO {
                // Titolo con supporto di taglia: + righe di continuazione alla stessa taglia.
                var parts = [sm]
                var j = i + 1
                var total = sm.text.utf16.count
                while j < lines.count {
                    let n = lines[j]
                    // Confronto sullo span PIÙ GRANDE: in maiuscoletto la media di riga varia da
                    // riga a riga (12,48/9,96) e una continuazione a metà parola apre con una
                    // minuscola maiuscoletta («NAPO-|LEONICO», Storia codificazione p.110).
                    let nSize = maxSpanSize(n)
                    // …ma una riga che porta testo alla taglia del CORPO è corpo, non titolo.
                    guard numberedTitleDepth(n.text) == nil,
                          !hasBodySizedText(n, body: body),
                          abs(nSize - size) <= NUMBERED_TITLE_CONT_TOLERANCE,
                          nSize >= body * NUMBERED_TITLE_SIZE_RATIO,
                          total + n.text.utf16.count <= NUMBERED_TITLE_MAX_TOTAL
                    else { break }
                    parts.append(n); total += n.text.utf16.count; j += 1
                }
                flush()
                out.append(.numberedTitle(parts.count == 1 ? sm : mergedLine(parts), depth: depth))
                i = j
                continue
            }
            let t = jsTrim(sm.text)
            if depth >= 2,
               size >= body * NUMBERED_TITLE_BODY_BAND,
               colWidth > 0, isShortSingle(sm),
               !(t.hasSuffix(",") || t.hasSuffix(";") || t.hasSuffix(":")) {
                flush()
                out.append(.numberedTitle(sm, depth: depth))
                i += 1
                continue
            }
            // Titolo a numerazione multipla, taglia-corpo, su PIÙ righe (Rizzo «2.1.1. Certezze e
            // dubbi ragionevoli: …», 4 righe): preceduto da uno STACCO verticale e composto a
            // RIENTRO SPORGENTE (le righe dopo la prima rientrano rispetto al numero), chiuso da una
            // riga corta entro NUMBERED_TITLE_MAX_LINES righe. Un paragrafo di prosa numerato fa il
            // contrario (rientra la prima riga, le altre tornano al margine) → resta corpo.
            if depth >= 2, size >= body * NUMBERED_TITLE_BODY_BAND, colWidth > 0,
               let p = prev, p.yBottom - sm.yTop > max(p.height, sm.height) * 0.5 {
                var parts = [sm]
                var j = i + 1
                var closed = false
                while j < lines.count, parts.count < NUMBERED_TITLE_MAX_LINES {
                    let n = lines[j]
                    guard n.x0 >= sm.x0 + NUMBERED_TITLE_HANGING_MIN,
                          numberedTitleDepth(n.text) == nil,
                          abs(leadingSpanSize(n) - size) <= NUMBERED_TITLE_CONT_TOLERANCE
                    else {
                        // Il rientro sporgente FINISCE: la riga dopo torna all'allineamento del
                        // numero (inizio del paragrafo) → il titolo si chiude qui (Elementi 55.1).
                        if parts.count >= 2, n.x0 < sm.x0 + NUMBERED_TITLE_HANGING_MIN { closed = true }
                        break
                    }
                    parts.append(n); j += 1
                    // …oppure una riga che lascia libero il margine destro chiude il titolo.
                    if endsBeforeMargin(n) { closed = true; break }
                }
                let last = jsTrim(parts.last?.text ?? "")
                // Il blocco-titolo è staccato anche DOPO (o chiude il run): una riga d'apertura di
                // paragrafo rientrata come una continuazione non viene inghiottita (Mercato unico
                // «2.3. Sentenza CG … | Nell'ambito di una controversia…»). E mai una parola spezzata.
                let gapAfter: Bool = {
                    guard j < lines.count, let lastPart = parts.last else { return true }
                    return lastPart.yBottom - lines[j].yTop > max(lastPart.height, lines[j].height) * 0.5
                }()
                if closed, parts.count >= 2, gapAfter, !last.hasSuffix("-"),
                   !(last.hasSuffix(",") || last.hasSuffix(";") || last.hasSuffix(":")) {
                    flush()
                    out.append(.numberedTitle(mergedLine(parts), depth: depth))
                    i = j
                    continue
                }
            }
            buf.append(sm); i += 1
        }
        flush()
    }
    return out
}

/// Livello di navigazione di un titolo numerato di profondità `depth`, relativo alla
/// gerarchia già emessa (`preceding`, in ordine di documento). Vedi testata.
func numberedTitleLevel(depth: Int, preceding: [NodeDict]) -> Int {
    for node in preceding.reversed() {
        let level: Int
        switch node.type {
        case .HEADING_1: level = 1
        case .HEADING_2: level = 2
        case .HEADING_3: level = 3
        case .HEADING_4: level = 4
        default: continue
        }
        if let d = numberedTitleDepth(node.text ?? "") {
            if d == depth { return level }
            if d < depth { return min(4, level + depth - d) }
            continue
        }
        return min(4, level + depth)
    }
    return min(4, 2 + depth)
}

/// Il nodo HEADING di un titolo numerato, al livello risolto sui nodi già emessi.
func numberedTitleNode(_ sm: LineSummary, depth: Int, page: Int, preceding: [NodeDict], id: String)
    -> NodeDict
{
    let level = numberedTitleLevel(depth: depth, preceding: preceding)
    let type: SemanticCategory
    switch level {
    case 1: type = .HEADING_1
    case 2: type = .HEADING_2
    case 3: type = .HEADING_3
    default: type = .HEADING_4
    }
    return NodeDict(id: id, type: type, page_index: page, text: sm.text, level: level)
}
