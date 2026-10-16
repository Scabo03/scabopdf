//
//  AknSegments.swift
//  ScaboCore
//
//  Rifinitura AKN-scoped del flusso di segmenti (Parte B — i tre attriti del gate).
//  È un post-passo PURO su `[ContentSegment]`. `refineAknSegments` è invocato solo
//  dall'orchestratore AKN; il suo Passo 2, `fractionLongNoteSegments`, è dal
//  2026-10-16 (build 55) anche il frazionamento delle note lunghe di OGNI lettura
//  preparata dalla catena condivisa (`ScaboChain`: iPad, iPhone e Mac). Chiude:
//
//   1. Note-mostro (§10.6): spezza le note più lunghe del target in celle sotto la
//      soglia del viewport, preservando il regime acustico a livello di NOTA LOGICA
//      — l'earcon suona solo sulla prima cella (ruolo NOTE), le continuazioni sono
//      NOTE_CONTINUATION (nessun re-annuncio: `noteSignal` scatta solo su NOTE con
//      intro non vuoto, e `acousticIntroFor(NOTE_CONTINUATION)` = "").
//   2. Numero di comma isolato: quando un comma è tutto una modifica, `expand`
//      emette il prefisso "1." come segmento ARTICLE_BODY a sé; qui lo si accorpa
//      all'annuncio del segmento successivo (coerente con come i commi normali
//      portano il numero).
//   3. Doppio "Modifica.": il frammento di sola chiusura ("».") dopo il testo nuovo
//      diventa un segmento AMENDMENT ri-annunciato "Modifica."; qui lo si accorpa al
//      segmento precedente (la chiusura appartiene al testo citato).
//
//  Invarianti: nessuna parola persa (il contenuto si sposta/si spezza, mai si
//  scarta); i regimi acustici sono preservati.
//

import Foundation

/// Marker di comma nudo: "1.", "2.", "1-bis.", "2 bis.", "(3)"… (corto).
private let _aknBareCommaMarker = try! NSRegularExpression(
    pattern: "^\\(?\\d+(?:[ -][a-z]+)*\\)?[.)]?$")

/// Vero se `text` (trimmed) è solo un marcatore di comma nudo.
func aknIsBareCommaMarker(_ text: String) -> Bool {
    let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !t.isEmpty, t.count <= 14 else { return false }
    let r = NSRange(t.startIndex..<t.endIndex, in: t)
    return _aknBareCommaMarker.firstMatch(in: t, range: r) != nil
}

/// Vero se `text` (trimmed) non contiene alcun carattere alfanumerico (solo
/// punteggiatura/virgolette): tipico del frammento di chiusura "».".
func aknIsPunctuationOnly(_ text: String) -> Bool {
    let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !t.isEmpty else { return false }
    return !t.unicodeScalars.contains { CharacterSet.alphanumerics.contains($0) }
}

// ── I confini dei pezzi (giro «cura delle note», 2026-10-16; decisione del maintainer, LAYER2 § 10.6) ───────────────
//
// Fino alla build 55 il meccanismo accumulava frasi intere fino alla soglia e, se una frase superava la soglia, la
// tagliava a PAROLA: un confine su tre cadeva dentro una frase, spesso subito dopo un'abbreviazione («n. | 1234»), lo
// spezzatore di frasi chiudeva la frase dopo una sigla di iniziali («X.Y. | Cognome»: 709 confini nel corpus) e restavano
// 1.140 pezzi sotto i 40 caratteri. La regola nuova, misurata sulle 5.246 note frazionate dei 52 volumi:
//   1. le frasi sono quelle dello spezzatore del corpo (`splitIntoSentences`, che resta com'è), con due regole in più che
//      valgono solo qui: una sigla di iniziali multiple («X.Y.») non chiude la frase, e nemmeno le abbreviazioni delle
//      citazioni di `NOTE_EXTRA_ABBREVIATIONS`, trovate nelle note come false fini di frase;
//   2. i pezzi sono di frasi intere fino alla soglia T (la granularità); un pezzo ancora corto (sotto T/2) prende anche la
//      frase seguente se ci sta entro 1,5 T: il pezzo si chiude a una fine frase dentro una finestra attorno alla soglia;
//   3. una frase oltre 1,5 T si taglia nella finestra [T/2, 1,5 T] da ogni inizio: prima dopo un punto e virgola o due
//      punti, poi dopo una virgola, solo in ultima istanza fra due parole; a parità di grado il taglio più vicino a T; MAI
//      subito dopo un'abbreviazione, un'iniziale o una sigla di iniziali (non si separano dalla parola che segue);
//   4. un pezzo sotto i 40 caratteri si unisce al vicino (il precedente, o il seguente se è il primo) se l'unione resta
//      entro 1,5 T.
// Il pezzo è un tratto contiguo del testo della nota: gli spazi interni restano quelli della nota, e fra due pezzi c'è
// solo la corsa di spazi del taglio, così la nota si ricompone esattamente.
// Perché 1,5 T e non la soglia secca: le celle del corpo superano già la soglia quando una frase è lunga, perché la frase
// intera vince sulla soglia (alla granularità 400 il 5 % dei blocchi del corpo supera i 667 caratteri); con 1,5 T i pezzi
// di nota restano sotto quei valori (al più 600 caratteri alla granularità 400) e i confini a fine frase passano dal 58 al
// 77 %, quelli dentro una frase cadono su un punto e virgola, due punti o una virgola, i confini dopo le iniziali e
// dopo un'abbreviazione vanno a zero e i pezzi sotto i 40 caratteri quasi spariscono. Finestre più larghe (1,75 T, 2 T)
// darebbero più fini di frase ma celle più alte di quelle del corpo: la granularità scelta resta il riferimento.

/// La finestra dei pezzi di nota attorno alla soglia T: un pezzo si chiude a fine frase fra `T·min` e `T·max`.
let NOTE_PIECE_WINDOW_MIN = 0.5
let NOTE_PIECE_WINDOW_MAX = 1.5
/// Sotto questa lunghezza (caratteri) un pezzo di nota si unisce al vicino, se l'unione resta nella finestra.
let NOTE_PIECE_SHORT = 40

/// Abbreviazioni delle citazioni che nelle note (non nel corpo) non chiudono la frase: ciascuna trovata almeno due volte
/// come falsa fine di frase davanti alla parola che la segue, nelle note frazionate dei 52 volumi (riviste, enciclopedie,
/// uffici giudiziari, rinvii, citazioni straniere). Forma minuscola senza il punto finale, come `SENTENCE_ABBREVIATIONS`.
let NOTE_EXTRA_ABBREVIATIONS: Set<String> = [
    "riv", "enc", "nss", "dig", "pret", "ass", "lgs", "id", "idem", "it", "part", "diff", "vid", "vs", "no", "ca", "al",
    "agg", "arb", "fall", "civ", "lav", "penit", "impr", "marg", "compl", "fasc", "comm", "quad", "sentt", "eur", "fin",
    "rev", "harv", "wash", "amer", "econ", "supp", "cir", "col", "ct", "ann", "leg", "rep", "pres", "sen", "del", "def",
    "fr", "para", "párr", "núm",
]

/// Lunghezza massima di un pezzo di nota alla soglia `target` (1,5 T).
public func notePieceMaxLength(target: Int) -> Int { Int(Double(target) * NOTE_PIECE_WINDOW_MAX) }

/// Vero se il token (senza spazi, con eventuali parentesi o virgolette attorno) è un'abbreviazione che nelle note non
/// chiude la frase e non va separata dalla parola che segue: iniziale singola («X.»), sigla di iniziali multiple
/// («X.Y.»), abbreviazione di `SENTENCE_ABBREVIATIONS` o di `NOTE_EXTRA_ABBREVIATIONS`.
func noteTokenIsAbbreviation(_ token: ArraySlice<Character>) -> Bool {
    var t = Array(token)
    while let last = t.last, CLOSING_CHARS.contains(last) { t.removeLast() }
    while let first = t.first, OPENING_CHARS.contains(first) { t.removeFirst() }
    guard t.last == "." else { return false }
    let letters = t.filter { $0.isLetter }
    if letters.isEmpty { return false }
    if letters.count == 1 { return true }
    if isInitialsSigla(t) { return true }
    let dotted = String(t.dropLast()).lowercased()
    let plain = String(letters).lowercased()
    return SENTENCE_ABBREVIATIONS.contains(dotted) || SENTENCE_ABBREVIATIONS.contains(plain)
        || NOTE_EXTRA_ABBREVIATIONS.contains(dotted) || NOTE_EXTRA_ABBREVIATIONS.contains(plain)
}

/// Sigla di iniziali multiple: due o più lettere MAIUSCOLE singole, ciascuna seguita dal punto («X.Y.», «X.Y.Z.»).
func isInitialsSigla(_ t: [Character]) -> Bool {
    guard t.count >= 4, t.count % 2 == 0 else { return false }
    var i = 0
    while i < t.count {
        guard t[i].isLetter, t[i].isUppercase, t[i + 1] == "." else { return false }
        i += 2
    }
    return true
}

/// Le frasi di una nota come intervalli `[start, end)` di caratteri, senza gli spazi ai bordi: le regole dello spezzatore
/// del corpo più le due delle note (punto 1 della testata).
func noteSentenceRanges(_ chars: [Character]) -> [Range<Int>] {
    let count = chars.count
    var ranges: [Range<Int>] = []
    func push(_ a: Int, _ b: Int) {
        var s = a, e = b
        while s < e, chars[s].isWhitespace { s += 1 }
        while e > s, chars[e - 1].isWhitespace { e -= 1 }
        if s < e { ranges.append(s..<e) }
    }
    var start = 0
    var i = 0
    while i < count {
        let ch = chars[i]
        if ch == "." || ch == "!" || ch == "?" {
            var after = i + 1
            while after < count, CLOSING_CHARS.contains(chars[after]) { after += 1 }
            if after < count, chars[after].isWhitespace {
                var next = after
                while next < count, chars[next].isWhitespace { next += 1 }
                if next < count, isSentenceStart(chars[next]) {
                    var isBoundary = true
                    if ch == "." {
                        // il token è la corsa massima di lettere e punti che termina al punto, come nel corpo
                        var begin = i - 1
                        while begin >= 0, chars[begin].isLetter || chars[begin] == "." { begin -= 1 }
                        isBoundary = !noteTokenIsAbbreviation(chars[(begin + 1)...i])
                    }
                    if isBoundary {
                        push(start, after)
                        start = next
                        i = next
                        continue
                    }
                }
            }
        }
        i += 1
    }
    push(start, count)
    return ranges
}

/// Un taglio possibile dentro una frase: il pezzo finisce a `cut` (inizio della corsa di spazi), il seguente comincia a
/// `resume`; `grade` 1 dopo «;» o «:», 2 dopo «,», 3 fra due parole.
private struct NoteCut { let cut: Int; let resume: Int; let grade: Int }

/// Taglia un intervallo più lungo di 1,5 T (una frase lunghissima) nella finestra [T/2, 1,5 T] da ogni inizio (punto 3
/// della testata). Se nella finestra non c'è un taglio ammesso si prende il migliore prima della finestra, poi il primo
/// dopo; se non ce n'è nessuno (un'unica parola, o solo abbreviazioni) il resto resta intero.
private func cutLongRange(_ chars: [Character], _ range: Range<Int>, target: Int, minLen: Int, maxLen: Int) -> [Range<Int>] {
    var out: [Range<Int>] = []
    var start = range.lowerBound
    while range.upperBound - start > maxLen {
        var inWindow: (NoteCut, Int)?
        var before: (NoteCut, Int)?
        var after: NoteCut?
        var k = start + 1
        while k < range.upperBound {
            guard chars[k].isWhitespace, !chars[k - 1].isWhitespace else { k += 1; continue }
            var resume = k
            while resume < range.upperBound, chars[resume].isWhitespace { resume += 1 }
            var tokenStart = k - 1
            while tokenStart > start, !chars[tokenStart - 1].isWhitespace { tokenStart -= 1 }
            let length = k - start
            if !noteTokenIsAbbreviation(chars[tokenStart..<k]) {
                let last = chars[k - 1]
                let cut = NoteCut(cut: k, resume: resume, grade: (last == ";" || last == ":") ? 1 : (last == "," ? 2 : 3))
                let distance = abs(length - target)
                if length > maxLen { after = cut; break }
                if length >= minLen {
                    if inWindow.map({ (cut.grade, distance) < ($0.0.grade, $0.1) }) ?? true { inWindow = (cut, distance) }
                } else if before.map({ (cut.grade, distance) < ($0.0.grade, $0.1) }) ?? true {
                    before = (cut, distance)
                }
            } else if length > maxLen, inWindow != nil || before != nil {
                break
            }
            k = resume
        }
        guard let chosen = inWindow?.0 ?? before?.0 ?? after else { break }
        out.append(start..<chosen.cut)
        start = chosen.resume
    }
    if start < range.upperBound { out.append(start..<range.upperBound) }
    return out
}

/// I pezzi di una nota lunga alla soglia `target`, secondo la regola della testata: tratti contigui del testo.
func notePieces(_ text: String, target: Int) -> [String] {
    let chars = Array(text)
    let minLen = Int(Double(target) * NOTE_PIECE_WINDOW_MIN)
    let maxLen = notePieceMaxLength(target: target)
    let sentences = noteSentenceRanges(chars)
    guard !sentences.isEmpty else { return [text] }
    // 2. frasi intere fino a T; un pezzo ancora corto prende la frase seguente se ci sta entro 1,5 T
    var blocks: [Range<Int>] = []
    var current: Range<Int>?
    for s in sentences {
        guard let c = current else { current = s; continue }
        let joined = s.upperBound - c.lowerBound
        if joined <= target || (c.count < minLen && joined <= maxLen) {
            current = c.lowerBound..<s.upperBound
        } else {
            blocks.append(c)
            current = s
        }
    }
    if let c = current { blocks.append(c) }
    // 3. una frase oltre 1,5 T si taglia alle pause
    var pieces: [Range<Int>] = []
    for b in blocks {
        if b.count <= maxLen { pieces.append(b) } else { pieces += cutLongRange(chars, b, target: target, minLen: minLen, maxLen: maxLen) }
    }
    // 4. i pezzi troppo corti si uniscono al vicino, se l'unione resta entro 1,5 T
    if pieces.count > 1 {
        var merged: [Range<Int>] = []
        for p in pieces {
            if let last = merged.last, p.count < NOTE_PIECE_SHORT, p.upperBound - last.lowerBound <= maxLen {
                merged[merged.count - 1] = last.lowerBound..<p.upperBound
            } else {
                merged.append(p)
            }
        }
        if merged.count > 1, merged[0].count < NOTE_PIECE_SHORT, merged[1].upperBound - merged[0].lowerBound <= maxLen {
            merged[1] = merged[0].lowerBound..<merged[1].upperBound
            merged.removeFirst()
        }
        pieces = merged
    }
    return pieces.map { String(chars[$0]) }
}

/// Frazione di una singola NOTE lunga in celle, con la regola dei confini della testata (fine frase in una finestra
/// attorno alla soglia, poi le pause, mai un'abbreviazione o un'iniziale separata dalla parola che segue, nessun pezzo
/// minuscolo). Prima cella: ruolo NOTE con l'intro (earcon una volta); continuazioni: NOTE_CONTINUATION senza intro.
/// `sourcePage` è propagato su ogni cella (nil sul percorso AKN: identico a prima).
///
/// Nato AKN-scoped (§10.6, "note-mostro"); dal 2026-08-10 è il meccanismo UNICO
/// di frazionamento delle note lunghe, riusato dall'arco ultrafocus per le note
/// ricucite (decisione di prodotto: stesso regime delle note normative lunghe —
/// stessa soglia, stesso spezzamento, regime acustico a livello di NOTA LOGICA).
private func aknFractionNote(_ seg: ContentSegment, target: Int) -> [ContentSegment] {
    let finalBlocks = notePieces(seg.text, target: target)
    if finalBlocks.count <= 1 { return [seg] }

    return finalBlocks.enumerated().map { i, text in
        if i == 0 {
            return ContentSegment(
                id: "\(seg.id)#0", role: seg.role, text: text,
                lengthCategory: seg.lengthCategory, acousticIntro: seg.acousticIntro,
                memoryRefresh: seg.memoryRefresh, sourcePage: seg.sourcePage)
        }
        return ContentSegment(
            id: "\(seg.id)#\(i)", role: SemanticCategory.NOTE_CONTINUATION.rawValue,
            text: text, lengthCategory: "", acousticIntro: "", sourcePage: seg.sourcePage)
    }
}

/// Frazionamento delle note lunghe di un flusso di segmenti: ogni segmento NOTE
/// più lungo di `target` diventa celle ≤ target (prima cella NOTE con intro e
/// regime; continuazioni NOTE_CONTINUATION mute). È il Passo 2 di
/// `refineAknSegments`, esposto da solo perché l'arco ultrafocus lo applica
/// anche al flusso continuo dei frammenti ricuciti (porta d'import + runner
/// d'officina) — stesso criterio, nessuna variante. Dal 2026-10-16 (build 55) lo
/// invoca anche il percorso PDF normale (`ContinuousBodyBuilder`, frazionamento
/// acceso per difetto): la lettura è la stessa chiunque l'abbia preparata.
public func fractionLongNoteSegments(
    _ segments: [ContentSegment], target: Int = DEFAULT_GRANULARITY_TARGET
) -> [ContentSegment] {
    var out: [ContentSegment] = []
    for seg in segments {
        if seg.role == SemanticCategory.NOTE.rawValue, seg.text.count > target {
            out += aknFractionNote(seg, target: target)
        } else {
            out.append(seg)
        }
    }
    return out
}

/// Post-passo di rifinitura del flusso di segmenti per il percorso AKN. Vedi la
/// testata per i tre attriti chiusi. `noteTarget` regola sia la soglia di
/// frazionamento sia la dimensione delle celle-nota (default = granularità corpo).
public func refineAknSegments(
    _ segments: [ContentSegment], noteTarget: Int = DEFAULT_GRANULARITY_TARGET
) -> [ContentSegment] {
    // Passo 1 — accorpamenti: marker di comma nudo → prepend al successivo;
    // frammento AMENDMENT di sola punteggiatura → append al precedente.
    var merged: [ContentSegment] = []
    var pendingMarker: String? = nil
    for seg in segments {
        if seg.role == SemanticCategory.AMENDMENT.rawValue, aknIsPunctuationOnly(seg.text),
           pendingMarker == nil, !merged.isEmpty {
            let tail = seg.text.trimmingCharacters(in: .whitespacesAndNewlines)
            merged[merged.count - 1].text += " " + tail
            continue
        }
        if seg.role == SemanticCategory.ARTICLE_BODY.rawValue, aknIsBareCommaMarker(seg.text) {
            let marker = seg.text.trimmingCharacters(in: .whitespacesAndNewlines)
            pendingMarker = pendingMarker.map { "\($0) \(marker)" } ?? marker
            continue
        }
        var s = seg
        if let m = pendingMarker {
            s.text = "\(m) \(s.text)"
            pendingMarker = nil
        }
        merged.append(s)
    }
    if let m = pendingMarker {
        merged.append(ContentSegment(
            id: "akn_marker_tail", role: SemanticCategory.ARTICLE_BODY.rawValue,
            text: m, lengthCategory: "", acousticIntro: ""))
    }

    // Passo 2 — frazionamento delle note lunghe (meccanismo condiviso).
    return fractionLongNoteSegments(merged, target: noteTarget)
}
