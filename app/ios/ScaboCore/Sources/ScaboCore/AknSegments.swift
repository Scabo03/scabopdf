//
//  AknSegments.swift
//  ScaboCore
//
//  Rifinitura AKN-scoped del flusso di segmenti (Parte B — i tre attriti del gate).
//  È un post-passo PURO su `[ContentSegment]`, invocato SOLO dall'orchestratore
//  AKN: non tocca `buildBaseSegments`/`expand` né il percorso PDF, quindi l'Estratto
//  resta byte-identico per costruzione. Chiude:
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

/// Spezza per confini di PAROLA un testo più lungo di `target` (fallback quando una
/// singola frase supera il target: garantisce che nessuna cella sfori il viewport).
private func aknWordWrap(_ text: String, target: Int) -> [String] {
    let words = text.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
    guard !words.isEmpty else { return [text] }
    var out: [String] = []
    var current = ""
    for w in words {
        if current.isEmpty { current = w }
        else if current.count + 1 + w.count <= target { current += " " + w }
        else { out.append(current); current = w }
    }
    if !current.isEmpty { out.append(current) }
    return out
}

/// Frazione di una singola NOTE lunga in celle ≤ target, a confini di frase (con
/// fallback a parola per frasi troppo lunghe). Prima cella: ruolo NOTE con l'intro
/// (earcon una volta); continuazioni: NOTE_CONTINUATION senza intro.
private func aknFractionNote(_ seg: ContentSegment, target: Int) -> [ContentSegment] {
    let sentences = splitIntoSentences(seg.text)
    guard !sentences.isEmpty else { return [seg] }
    var blocks: [String] = []
    var current = ""
    for sentence in sentences {
        if current.isEmpty {
            current = sentence
        } else if current.count + 1 + sentence.count <= target {
            current += " " + sentence
        } else {
            blocks.append(current)
            current = sentence
        }
    }
    if !current.isEmpty { blocks.append(current) }

    // Fallback a parola per ogni blocco che sfora ancora il target (frase gigante).
    var finalBlocks: [String] = []
    for b in blocks {
        if b.count <= target { finalBlocks.append(b) } else { finalBlocks += aknWordWrap(b, target: target) }
    }
    if finalBlocks.count <= 1 { return [seg] }

    return finalBlocks.enumerated().map { i, text in
        if i == 0 {
            return ContentSegment(
                id: "\(seg.id)#0", role: seg.role, text: text,
                lengthCategory: seg.lengthCategory, acousticIntro: seg.acousticIntro,
                memoryRefresh: seg.memoryRefresh)
        }
        return ContentSegment(
            id: "\(seg.id)#\(i)", role: SemanticCategory.NOTE_CONTINUATION.rawValue,
            text: text, lengthCategory: "", acousticIntro: "")
    }
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

    // Passo 2 — frazionamento delle note lunghe.
    var out: [ContentSegment] = []
    for seg in merged {
        if seg.role == SemanticCategory.NOTE.rawValue, seg.text.count > noteTarget {
            out += aknFractionNote(seg, target: noteTarget)
        } else {
            out.append(seg)
        }
    }
    return out
}
