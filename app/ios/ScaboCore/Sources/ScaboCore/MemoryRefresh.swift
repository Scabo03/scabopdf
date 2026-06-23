//
//  MemoryRefresh.swift
//  ScaboCore
//
//  Memory refresh per le note DIFFERITE (§ 7.4/§ 7.5 di LAYER2_PRODUCT_DECISIONS.md).
//  Quando una nota lunga (MEDIUM/LONG/VERY_LONG/MEGA) è letta lontano dal punto in cui
//  era richiamata, VoiceOver antepone un breve rinfresco del contesto: la "frase del
//  richiamo", così la nota non arrivi scollegata da ciò a cui risponde.
//
//  ── Cornice: dentro § 7.5, sui parametri decisi dal maintainer ──────────────────
//
//  La regola resta ancorata alla punteggiatura (§ 7.5). L'indagine empirica
//  (docs/ANALYSIS_MEMORY_REFRESH_NOTE_DIFFERITE.md, commit c920ffa) ha mostrato che
//  § 7.5 applicata alla lettera produce un rinfresco VUOTO/MINUSCOLO nel 51% dei casi
//  (il marcatore cade quasi sempre subito dopo un segno forte). Le correzioni decise
//  dal maintainer (2026-06-23), implementate qui:
//    • Pavimento 60 / Tetto 180 caratteri.
//    • Richiamo subito dopo il punto → si rilegge la frase appena conclusa (è quella
//      che la nota commenta), non il vuoto dopo il punto.
//    • Estensione per il pavimento → frase intera precedente, troncata al tetto.
//    • Troncamento al tetto → pulito (confine di parola), conservando la parte PIÙ
//      VICINA al richiamo (la più rilevante).
//    • Il punto fa da fine-frase solo se VERO fine-frase, non un'abbreviazione
//      (c.d., art., n.…): già garantito da `sentenceBoundaryOffsets` (abbrev-aware),
//      lo stesso confine usato dal piazzamento delle note.
//    • Ricucitura delle sillabazioni di fine riga (sul-la → sulla).
//    • Scarto della testa non-prosa (code di marcatore "19)", parentesi residue).
//
//  Rete A: il rinfresco è testo RIPETUTO in aggiunta, mai sostitutivo: non altera né
//  il contenuto della nota né quello del corpo.
//

import Foundation

/// Parametri di prodotto decisi dal maintainer (2026-06-23).
public let MEMORY_REFRESH_FLOOR = 60
public let MEMORY_REFRESH_CEILING = 180

/// Calcola la "frase del richiamo" da anteporre a una nota differita. `text` è il
/// testo del nodo BODY del richiamo; `markerOffset` è l'indice di CARATTERE (in
/// `Array(text)`) dove INIZIA il marcatore (la stessa convenzione di `InlineMarker`).
/// Ritorna "" se non calcolabile (marcatore a inizio testo assoluto, testo vuoto).
public func memoryRefreshSegment(
    _ text: String,
    markerOffset: Int,
    floor: Int = MEMORY_REFRESH_FLOOR,
    ceiling: Int = MEMORY_REFRESH_CEILING
) -> String {
    let chars = Array(text)
    let n = chars.count
    let mk = min(max(markerOffset, 0), n)
    guard mk > 0 else { return "" }

    // Confini di FINE frase, abbrev-aware (lo stesso helper del piazzamento note).
    let bounds = sentenceBoundaryOffsets(text)

    // Inizio della frase che contiene il marcatore = ultimo confine ≤ mk (o 0).
    var start = bounds.last(where: { $0 <= mk }) ?? 0
    // PAVIMENTO: se il segmento [start, mk) è troppo corto, estendi all'indietro alla
    // frase intera precedente, ripetendo finché ≥ floor o si raggiunge l'inizio. Copre
    // il caso "richiamo subito dopo il punto": il segmento iniziale è ~vuoto → si
    // rilegge la frase appena conclusa.
    while (mk - start) < floor, start > 0 {
        start = bounds.last(where: { $0 < start }) ?? 0
    }

    var seg = Array(chars[start..<mk])

    // TETTO: oltre `ceiling`, conserva la parte PIÙ VICINA al richiamo (la fine), con
    // taglio pulito al confine di parola (mai a metà parola).
    if seg.count > ceiling {
        var cut = seg.count - ceiling
        while cut < seg.count, !isWhitespaceChar(seg[cut]) { cut += 1 }  // chiudi la parola spezzata
        while cut < seg.count, isWhitespaceChar(seg[cut]) { cut += 1 }   // salta lo spazio
        seg = cut < seg.count ? Array(seg[cut...]) : seg
    }

    var s = stripDirtyHead(String(seg))   // code di marcatore / parentesi residue
    s = stitchHyphenation(s)              // sul-la → sulla
    return jsTrim(s)
}

// MARK: - Para-titolo (§ 7.4, VERY_LONG/MEGA) — DORMIENTE (vedi nota)
//
// Il para-titolo è l'aiuto a "decidere se ascoltare o saltare" una nota lunga: le
// prime ~15-20 parole del CONTENUTO, saltando un'eventuale apertura con citazione
// bibliografica (decisione 6 del maintainer). È implementato e testato QUI ma NON
// ancora cablato nel flusso parlato: serve l'interazione di salto (§ 7.4), non ancora
// resa; anteporlo ora duplicherebbe l'incipit della nota letto subito dopo. Pronto
// per quando la funzione di salto arriverà.

/// Le prime `maxWords` parole del contenuto vero della nota, saltando una citazione
/// bibliografica iniziale (Cfr./V./Così/AUTORE, Titolo, in Rivista, anno, p. N).
public func noteParaTitolo(_ noteText: String, maxWords: Int = 18) -> String {
    var t = jsTrim(noteText)
    // Togli il marcatore d'apertura della nota: "(17) ", "17. ", "17) ".
    t = replacingPrefixRegex(t, NOTE_MARKER_PREFIX_RE)
    // Se apre con una citazione bibliografica, salta alla prima frase successiva.
    if looksLikeOpeningCitation(t) {
        let bounds = sentenceBoundaryOffsets(t)
        if let b = bounds.first {
            let chars = Array(t)
            t = jsTrim(String(chars[min(b, chars.count)...]))
        }
    }
    let words = t.split(separator: " ").prefix(maxWords)
    return words.joined(separator: " ")
}

// MARK: - Correzioni tecniche

private let NOTE_MARKER_PREFIX_RE = try! NSRegularExpression(
    pattern: "^\\s*\\(?\\d{1,3}\\)?[\\.\\)]?\\s*")
private let DIRTY_HEAD_PATTERNS: [NSRegularExpression] = [
    try! NSRegularExpression(pattern: "^\\(?\\d{1,3}\\)"),   // coda di marcatore "19)" / "(19)"
    try! NSRegularExpression(pattern: "^[)\\]»”’]"),          // parentesi/virgoletta di chiusura
    try! NSRegularExpression(pattern: "^[;:,]"),              // punteggiatura iniziale
]

/// Scarta dalla testa del segmento i frammenti non-prosa (code di marcatore, parentesi
/// di chiusura residue, punteggiatura iniziale). Conserva le congiunzioni iniziali
/// (parole come "e", "ma", "però"): sono il legame logico richiesto da § 7.5.
func stripDirtyHead(_ s: String) -> String {
    var t = jsTrim(s)
    var changed = true
    while changed {
        changed = false
        for re in DIRTY_HEAD_PATTERNS {
            let ns = t as NSString
            if let m = re.firstMatch(in: t, range: NSRange(location: 0, length: ns.length)),
               m.range.location == 0, m.range.length > 0 {
                t = jsTrim(ns.substring(from: m.range.length))
                changed = true
            }
        }
    }
    return t
}

/// Prefissi di composti reali da NON ricucire (ex-articolo resta "ex-articolo").
private let HYPHEN_COMPOUND_PREFIXES: Set<String> = [
    "ex", "post", "pre", "anti", "neo", "sub", "vice", "semi", "auto", "co",
    "contro", "sopra", "sotto", "extra", "intra", "inter", "pro", "re", "iper", "ipo",
]

/// Ricuce le sillabazioni di fine riga ("sul-la" → "sulla"): un trattino fra due
/// lettere minuscole è quasi sempre un a-capo tipografico. Conserva i composti reali
/// il cui token a sinistra è un prefisso noto (ex-, post-, …).
func stitchHyphenation(_ s: String) -> String {
    let chars = Array(s)
    var out: [Character] = []
    var i = 0
    while i < chars.count {
        let c = chars[i]
        if c == "-", i > 0, i + 1 < chars.count,
           isLowerLetterChar(chars[i - 1]), isLowerLetterChar(chars[i + 1]) {
            var j = out.count - 1
            var left = ""
            while j >= 0, isLetterChar(out[j]) { left = String(out[j]) + left; j -= 1 }
            if HYPHEN_COMPOUND_PREFIXES.contains(left.lowercased()) {
                out.append(c)   // composto reale: conserva il trattino
            }
            // altrimenti: salta il trattino (ricuci la parola spezzata)
            i += 1
            continue
        }
        out.append(c)
        i += 1
    }
    return String(out)
}

// MARK: - Heuristics & helpers

private let CITATION_CUES: [String] = [
    "Cfr.", "Cfr ", "V. ", "Vedi ", "Vd. ", "Così ", "Contra", "Adde", "Conf.",
    "Si veda", "Sul punto", "Per tutti", "In senso", "In tal senso", " In arg",
]

/// Vero se il testo apre con una citazione bibliografica (cue iniziale, oppure
/// iniziale-puntata di autore "A. ROSSI," seguita più avanti da ", in " o ", p.").
private func looksLikeOpeningCitation(_ t: String) -> Bool {
    for cue in CITATION_CUES where t.hasPrefix(cue) { return true }
    // "A. COGNOME" o "A.A. COGNOME" all'inizio + segnali bibliografici nel seguito
    let ns = t as NSString
    let head = ns.length > 0 ? ns.substring(to: min(ns.length, 40)) : t
    let initialAuthor = (try? NSRegularExpression(pattern: "^[A-Z]\\.( ?[A-Z]\\.)* [A-Z]"))?
        .firstMatch(in: head, range: NSRange(location: 0, length: (head as NSString).length)) != nil
    if initialAuthor, t.contains(", in ") || t.contains(", p. ") || t.contains(", pp. ") {
        return true
    }
    return false
}

private func replacingPrefixRegex(_ s: String, _ re: NSRegularExpression) -> String {
    let ns = s as NSString
    if let m = re.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)),
       m.range.location == 0, m.range.length > 0 {
        return ns.substring(from: m.range.length)
    }
    return s
}

private func isWhitespaceChar(_ c: Character) -> Bool { c.isWhitespace }

private func isLetterChar(_ c: Character) -> Bool {
    c.isLetter
}

private func isLowerLetterChar(_ c: Character) -> Bool {
    c.isLetter && c.isLowercase
}
