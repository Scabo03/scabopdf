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
//   • nota lunga FRAZIONATA (§ 10.6): i pezzi di seguito prendono il richiamo del primo pezzo
//     dello stesso nodo (giro «uniformità della lettura», 2026-10-16).
//
//  ── Il riscontro ANCORATO (giro «accessibilità e completamento», 2026-10-18, INBOX D.16) ────────────
//
//  Il rinfresco di una nota differita finisce, per costruzione (`memoryRefreshSegment`), esattamente dove
//  comincia il marcatore della nota nel testo del corpo. Quindi nel testo del richiamo le ultime lettere/cifre
//  del rinfresco sono seguite SUBITO dal numero della nota (e poi da una non-cifra). È un riscontro più
//  stretto della regola di parola (`containsCallNumber`): lo stesso numero, nello stesso punto. Serve dove la
//  regola di parola non riconosce il richiamo pur essendoci: dopo un punto o una virgola («…parola.12»), dopo
//  un altro numero («…del 1990¹²», che il lettore di sistema scrive «199012»), dopo una sigla. Tre forme:
//  nello stesso segmento; coda in fondo al segmento e numero in testa al segmento di testo seguente; coda a
//  cavallo di due segmenti di testo consecutivi (il richiamo è il secondo). Misura sui 52 volumi di prova
//  (iOS 27): sulle 7.806 note differite che il salto lo avevano già, il riscontro ancorato ritrova lo stesso
//  richiamo in 7.694 casi e in nessun caso uno diverso; sulle 1.224 che non lo avevano ne lega 1.073, ognuno
//  provato contro la pagina stampata (il numero è scritto come richiamo — in apice, più piccolo o fra
//  parentesi — subito dopo la stessa frase o subito prima delle stesse parole: giudice di laboratorio).
//  Non vale nei TESTI NORMATIVI (flusso con articoli: codici, atti AKN): lì un numero in apice dopo «art. N»
//  è il comma, non un richiamo (provato su due casi dei codici); resta la regola di parola. Un rinfresco
//  troppo corto (meno di 12 lettere) non lega nulla: con sei-undici lettere la stessa frase torna in più
//  punti (provato: 11 legami sbagliati su 38).
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
/// subito dopo una parola o una chiusura di citazione/parentesi («…aquiliana 50», «…mondo» 2»), oppure FRA PARENTESI
/// tonde subito dopo una parola o una chiusura, anche col punto di un'abbreviazione («…del giudice (12)», «…cit. (12)»:
/// giro «pulizia e rifinitura finale del capitolo note», INBOX D.11); mai dopo un'abbreviazione di riferimento
/// («art. 5», «comma 2», «n. 12», «art. (5)»).
func containsCallNumber(_ text: String, _ n: Int, tail: Int? = nil) -> Bool {
    let t = tail.map { String(text.suffix($0)) } ?? text
    let patterns = [
        "([A-Za-zÀ-ÿ»”’\\)\\]]+)\\s?\(n)(?![0-9])",
        "([A-Za-zÀ-ÿ»”’\\)\\]]+)\\.?\\s?\\(\(n)\\)",
    ]
    for (k, pattern) in patterns.enumerated() {
        guard let re = try? NSRegularExpression(pattern: pattern) else { continue }
        for m in re.matches(in: t, range: NSRange(t.startIndex..<t.endIndex, in: t)) {
            guard let r = Range(m.range(at: 1), in: t) else { continue }
            let word = t[r].lowercased().filter { $0.isLetter }
            // fra parentesi conta anche la parola dopo l'ultimo apostrofo («l’art. (5)» è «art»): nel dubbio, nessun salto
            let tail = String(t[r].lowercased().split(whereSeparator: { !$0.isLetter }).last ?? "")
            if NOT_A_CALL_BEFORE.contains(word) || (k == 1 && NOT_A_CALL_BEFORE.contains(tail)) { continue }
            return true
        }
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
    // Testo normativo (codici, atti AKN): niente riscontro ancorato, vedi l'intestazione del file.
    let normative = segments.contains { $0.role == SemanticCategory.ARTICLE_HEADER.rawValue }
    func isText(_ k: Int) -> Bool { !isNoteRole(segments[k].role) && segments[k].role != VISUAL_RESOURCE_ROLE }
    func isHeading(_ k: Int) -> Bool {
        segments[k].role.hasPrefix("HEADING_") || segments[k].role == SemanticCategory.ARTICLE_HEADER.rawValue
    }
    for (i, seg) in segments.enumerated()
    where seg.role == SemanticCategory.NOTE.rawValue || seg.role == SemanticCategory.EDITORIAL_NOTE.rawValue {
        guard let number = noteOpening(seg.text) else { continue }
        var call: Int?
        var anchored: Int?
        if !seg.memoryRefresh.isEmpty {
            // Differita: la coda della frase del richiamo, all'indietro.
            let tail = String(jumpNorm(seg.memoryRefresh).suffix(NOTE_JUMP_REFRESH_TAIL))
            guard tail.count >= 12 else { continue }
            let digits = String(number)
            var j = i - 1
            let floor = max(0, i - NOTE_JUMP_MAX_LOOKBACK)
            while j >= floor {
                // La nota differita è letta a fine della SUA sezione: il richiamo sta dopo
                // l'intestazione che apre la sezione. Oltre, non si cerca (e il costo resta
                // limitato anche sui volumi giganti).
                if isHeading(j) { break }
                if isText(j), norm(j).contains(tail) { call = j; break }
                j -= 1
            }
            if !normative {
                if let c = call, !containsCallNumber(segments[c].text, number) {
                    // nello stesso segmento, o coda in fondo e numero in testa al segmento di testo seguente
                    if anchoredNumber(after: tail, in: norm(c), digits) {
                        anchored = c
                    } else if norm(c).hasSuffix(tail) {
                        var k = c + 1
                        while k < i, !isText(k) { k += 1 }
                        if k < i, numberOpens(norm(k), digits) { anchored = c }
                    }
                } else if call == nil {
                    // coda a cavallo di due segmenti di testo consecutivi: il richiamo è il secondo
                    var k = i - 1
                    while k > floor, !isHeading(k) {
                        if isText(k) {
                            var p = k - 1
                            while p >= floor, !isText(p), !isHeading(p) { p -= 1 }
                            if p >= floor, isText(p), !isHeading(p),
                               anchoredNumber(straddling: norm(p), norm(k), tail, digits) {
                                anchored = k
                                break
                            }
                        }
                        k -= 1
                    }
                }
            }
        } else {
            // In linea: il segmento di testo subito prima del gruppo di note. L'elemento «risorsa visiva» è additivo e
            // trasparente: una figura collocata fra il blocco e le sue note non diventa il richiamo.
            var j = i - 1
            while j >= 0, isNoteRole(segments[j].role) || segments[j].role == VISUAL_RESOURCE_ROLE { j -= 1 }
            if j >= 0 { call = j }
        }
        if let c = anchored {
            links.callOfNote[i] = c
            links.notesOfCall[c, default: []].append(i)
            continue
        }
        guard let c = call,
              containsCallNumber(segments[c].text, number,
                                 tail: seg.memoryRefresh.isEmpty ? NOTE_JUMP_INLINE_TAIL : nil)
        else { continue }
        links.callOfNote[i] = c
        links.notesOfCall[c, default: []].append(i)
    }
    linkNoteContinuations(segments, &links)
    return links
}

/// Vero se in `text` (lettere/cifre minuscole) la coda `tail` è seguita SUBITO dal numero `digits` e poi da una non-cifra
/// (riscontro ancorato, vedi l'intestazione del file).
func anchoredNumber(after tail: String, in text: String, _ digits: String) -> Bool {
    var from = text.startIndex
    while let r = text.range(of: tail, range: from..<text.endIndex) {
        if numberOpens(text[r.upperBound...], digits) { return true }
        from = text.index(after: r.lowerBound)
    }
    return false
}

/// Vero se `text` comincia col numero `digits` seguito da una non-cifra (o dalla fine).
func numberOpens<S: StringProtocol>(_ text: S, _ digits: String) -> Bool {
    guard text.hasPrefix(digits) else { return false }
    let after = text.index(text.startIndex, offsetBy: digits.count)
    return after == text.endIndex || !text[after].isNumber
}

/// Vero se la coda sta a cavallo fra la fine di `first` e l'inizio di `second` (almeno un carattere per parte) ed è
/// seguita subito, dentro `second`, dal numero `digits` e da una non-cifra.
func anchoredNumber(straddling first: String, _ second: String, _ tail: String, _ digits: String) -> Bool {
    let chars = Array(tail)
    for split in stride(from: chars.count - 1, through: 1, by: -1) {
        let head = String(chars[..<split]), rest = String(chars[split...])
        if first.hasSuffix(head), second.hasPrefix(rest), numberOpens(second.dropFirst(rest.count), digits) { return true }
    }
    return false
}

/// L'id-nodo di un pezzo di nota frazionata: l'id senza l'ultimo suffisso `#k` (`fractionLongNoteSegments` chiama i pezzi
/// `<id>#0`, `<id>#1`, …).
private func fractionBaseId(_ id: String) -> Substring {
    guard let hash = id.lastIndex(of: "#") else { return Substring(id) }
    return id[..<hash]
}

/// Note lunghe FRAZIONATE (§ 10.6, `fractionLongNoteSegments`; dal 2026-10-16 anche quando l'iPad elabora da sé un PDF):
/// i pezzi di seguito (`NOTE_CONTINUATION`) hanno lo stesso richiamo del primo pezzo, così «Vai al testo del richiamo» c'è
/// su ogni pezzo come c'era sulla nota intera. Il primo pezzo si cerca all'indietro saltando gli altri pezzi e gli elementi
/// «risorsa visiva» (additivi e trasparenti), e deve venire DALLO STESSO NODO (stesso id prima di `#k`): senza riscontro,
/// nessun legame. Il salto «Vai alla nota N» dal richiamo resta sul primo pezzo (`notesOfCall` non cambia).
private func linkNoteContinuations(_ segments: [ContentSegment], _ links: inout NoteCallLinks) {
    guard !links.callOfNote.isEmpty else { return }
    let continuation = SemanticCategory.NOTE_CONTINUATION.rawValue
    for (i, seg) in segments.enumerated() where seg.role == continuation {
        var j = i - 1
        while j >= 0, segments[j].role == continuation || segments[j].role == VISUAL_RESOURCE_ROLE { j -= 1 }
        guard j >= 0,
              segments[j].role == SemanticCategory.NOTE.rawValue || segments[j].role == SemanticCategory.EDITORIAL_NOTE.rawValue,
              let call = links.callOfNote[j],
              segments[j].id.hasSuffix("#0"),
              fractionBaseId(segments[j].id) == fractionBaseId(seg.id)
        else { continue }
        links.callOfNote[i] = call
    }
}
