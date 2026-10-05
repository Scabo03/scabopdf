//
//  NoteJump.swift
//  ScaboCore
//
//  Salto fra NOTA e TESTO DEL RICHIAMO (LAYER2_PRODUCT_DECISIONS § 7.12: sulla nota «vai al testo
//  del richiamo», sul richiamo «vai al testo della nota»). Specificato e mai costruito fino al
//  2026-10-05 (docs/DIAGNOSI_INTESTAZIONI.md § 7).
//
//  ── Come si trova il legame, senza toccare il modello ────────────────────────────
//
//  Il legame si ricava dal flusso dei segmenti già piazzato da `bindAndPlaceNotes`, senza campi
//  nuovi né cambi di cache:
//   • nota DIFFERITA (lunga, letta a fine sezione): porta il rinfresco di contesto
//     (`memoryRefresh`, la «frase del richiamo» § 7.4/7.5). Il segmento del richiamo è il più
//     vicino ALL'INDIETRO il cui testo contiene la coda di quella frase;
//   • nota letta IN LINEA (breve, a fine frase del richiamo): il segmento del richiamo è il
//     segmento di testo immediatamente precedente il gruppo di note.
//  In entrambi i casi si ESIGE che il segmento trovato contenga il NUMERO della nota come
//  parola (il richiamo stesso). Senza riscontro, nessun legame: un salto sbagliato è peggio di
//  nessun salto (regola d'oro). Le note non agganciate restano lette in posizione e non hanno
//  richiamo da raggiungere.
//

import Foundation

/// Legami nota↔richiamo per indice di segmento.
public struct NoteCallLinks: Equatable, Sendable {
    /// indice di una nota → indice del segmento che contiene il suo richiamo.
    public var callOfNote: [Int: Int] = [:]
    /// indice di un segmento di testo → indici delle note che vi sono richiamate (in ordine).
    public var notesOfCall: [Int: [Int]] = [:]
    public init() {}
}

/// Finestra massima (in segmenti) della ricerca all'indietro del richiamo di una nota differita.
let NOTE_JUMP_MAX_LOOKBACK = 4000
/// Lunghezza (in caratteri normalizzati) della coda della «frase del richiamo» da ritrovare.
let NOTE_JUMP_REFRESH_TAIL = 40

private func isNoteRole(_ role: String) -> Bool {
    role == SemanticCategory.NOTE.rawValue || role == SemanticCategory.EDITORIAL_NOTE.rawValue
        || role == SemanticCategory.NOTE_CONTINUATION.rawValue
}

/// Testo ridotto a lettere e cifre minuscole (per il riscontro della frase del richiamo).
private func jumpNorm(_ s: String) -> String {
    String(s.lowercased().filter { $0.isLetter || $0.isNumber })
}

/// Parole dopo le quali un numero NON è un richiamo di nota ma un riferimento («art. 5», «n. 12»).
private let NOT_A_CALL_BEFORE: Set<String> = [
    "art", "artt", "n", "nn", "comma", "co", "p", "pp", "pag", "cap", "nt", "nota", "par", "lett",
    "sez", "vol", "l", "legge", "d", "dlgs", "anno", "anni", "numero", "punto", "allegato", "tab",
]

/// Vero se `text` (o la sua coda di `tail` caratteri) contiene il numero `n` come RICHIAMO di nota:
/// subito dopo una parola o una chiusura di citazione/parentesi («…aquiliana 50», «…mondo» 2»), mai
/// dopo un'abbreviazione di riferimento («art. 5», «comma 2», «n. 12»).
private func containsCallNumber(_ text: String, _ n: Int, tail: Int? = nil) -> Bool {
    let t = tail.map { String(text.suffix($0)) } ?? text
    let pattern = "([A-Za-zÀ-ÿ»”’\\)\\]]+)\\s?\(n)(?![0-9])"
    guard let re = try? NSRegularExpression(pattern: pattern) else { return false }
    for m in re.matches(in: t, range: NSRange(t.startIndex..<t.endIndex, in: t)) {
        guard let r = Range(m.range(at: 1), in: t) else { continue }
        let word = t[r].lowercased().filter { $0.isLetter }
        if !NOT_A_CALL_BEFORE.contains(word) { return true }
    }
    return false
}

/// Coda (caratteri) del segmento entro cui deve stare il richiamo di una nota letta in linea
/// (il pezzo di corpo finisce alla frase del richiamo).
let NOTE_JUMP_INLINE_TAIL = 400

/// Calcola i legami nota↔richiamo sul flusso di lettura già piazzato.
public func noteCallLinks(_ segments: [ContentSegment]) -> NoteCallLinks {
    var links = NoteCallLinks()
    var normCache: [Int: String] = [:]
    func norm(_ i: Int) -> String {
        if let s = normCache[i] { return s }
        let s = jumpNorm(segments[i].text)
        normCache[i] = s
        return s
    }
    for (i, seg) in segments.enumerated()
    where seg.role == SemanticCategory.NOTE.rawValue || seg.role == SemanticCategory.EDITORIAL_NOTE.rawValue {
        guard let number = noteOpening(seg.text) else { continue }
        var call: Int?
        if !seg.memoryRefresh.isEmpty {
            // Differita: la coda della frase del richiamo, all'indietro.
            let tail = String(jumpNorm(seg.memoryRefresh).suffix(NOTE_JUMP_REFRESH_TAIL))
            guard tail.count >= 12 else { continue }
            var j = i - 1
            let floor = max(0, i - NOTE_JUMP_MAX_LOOKBACK)
            while j >= floor {
                let role = segments[j].role
                // La nota differita è letta a fine della SUA sezione: il richiamo sta dopo
                // l'intestazione che apre la sezione. Oltre, non si cerca (e il costo resta
                // limitato anche sui volumi giganti).
                if role.hasPrefix("HEADING_") || role == SemanticCategory.ARTICLE_HEADER.rawValue { break }
                if !isNoteRole(role), norm(j).contains(tail) { call = j; break }
                j -= 1
            }
        } else {
            // In linea: il segmento di testo subito prima del gruppo di note.
            var j = i - 1
            while j >= 0, isNoteRole(segments[j].role) { j -= 1 }
            if j >= 0 { call = j }
        }
        guard let c = call,
              containsCallNumber(segments[c].text, number,
                                 tail: seg.memoryRefresh.isEmpty ? NOTE_JUMP_INLINE_TAIL : nil)
        else { continue }
        links.callOfNote[i] = c
        links.notesOfCall[c, default: []].append(i)
    }
    return links
}
