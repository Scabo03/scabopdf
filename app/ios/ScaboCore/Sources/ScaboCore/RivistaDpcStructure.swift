//
//  RivistaDpcStructure.swift
//  ScaboCore
//
//  Ramo "Riviste" — foglia STRUTTURA della porta DPC (giro finale della ripulizia mobile, 2026-10-08).
//
//  ── Il difetto (diagnosi sulla pagina e nel codice, entrambe le generazioni) ─────────────────────
//
//  Nella Rivista DPC il titolo di ogni articolo e di ogni sezione, l'autore, l'affiliazione, la
//  gerenza e alcune intestazioni di tabella sono TESTO BIANCO su una fascia verde (riempimento
//  vettoriale disegnato prima del testo: verità PyMuPDF). PDFKit li estrae, con il colore bianco; il
//  tronco li scartava tutti con la regola delle «ancore invisibili» (`isNearWhite`), nata per le
//  ancore di pagina a 1 pt di Marrone (bianco su bianco). Il censimento sui 52 volumi ha mostrato che
//  la stessa regola, fuori dalla DPC, toglie solo mobilia o copertina (linguette «CODICE …» dei codici,
//  copertine e prezzi, il riquadro promozionale UTET, la testata di Rivisteweb, i cerchietti numerati di
//  Costituzionale) e le ancore invisibili: per questo la regola del tronco resta com'è e la cura vive
//  qui, sotto la porta `isRivistaDpc`.
//
//  Intorno al titolo mancante la gerarchia della DPC era appiattita (la misura dei titoli lo segnala):
//  le traduzioni grigie dei titoli erano intestazioni di livello 1-3 riga per riga, i titoli di
//  paragrafo verdi erano H1 come le traduzioni, e i grandi numeri di paragrafo «1.», «2.» (verdi, a tre
//  volte il corpo) erano tolti dal canale a colore della mobilia, che li vede ricorrere su molte pagine.
//  Inserire il titolo d'articolo senza riordinare i livelli l'avrebbe fatto annidare sotto l'ultimo
//  paragrafo dell'articolo precedente: un errore silenzioso di navigazione. La foglia allinea quindi i
//  livelli al SOMMARIO STAMPATO della rivista (sezione → articolo) e al sommario d'articolo
//  («1. Premessa. – 2. …»): sezione H1, articolo H2, paragrafo H3, sotto-paragrafo H4.
//
//  ── Le regole (solo dove la porta DPC è vera; altrove nessun effetto per costruzione) ────────────
//
//  1. Il testo bianco a taglia ≥ 6 pt si legge (`pageItems` non lo scarta).
//  2. TITOLO: riga bianca a taglia ≥ 1,3 × corpo, con almeno 4 lettere, nella metà alta della pagina. Le
//     righe consecutive del titolo diventano UN titolo. Livello dalla posizione della fascia: la pagina
//     d'apertura di SEZIONE ha il titolo a ~26 % dall'alto (fascia alta), l'articolo a 8-15 %.
//  3. Il resto del testo bianco (autore, affiliazione, sottotitolo, gerenza, intestazioni di tabella) è
//     corpo, in blocchi propri: non si fonde col corpo nero vicino.
//  4. TRADUZIONI dei titoli (grigio chiaro, a taglia ≥ 1,12 × corpo): corpo, un blocco per traduzione.
//  5. PARAGRAFI: il grande numero verde («2.», «2.1.») si appaia per GEOMETRIA al titolo verde che gli sta
//     accanto (la prima riga del titolo comincia dentro l'altezza del numero) e i due formano un titolo
//     solo, di livello 2 + profondità del numero (tetto 4); le righe del titolo che vanno a capo si
//     uniscono. Un numero senza titolo accanto (l'editoriale numera i paragrafi senza titolo) resta
//     testo e si legge in testa al suo paragrafo.
//  6. Il testo colorato a taglia di corpo (voci del sommario stampato, gerenza, abstract fuori guardia) e
//     il testo nero più grande del corpo (una tabella) non sono mai titoli: corpo.
//
//  Il canale a colore della mobilia, sulla DPC, non prende più i numeri di paragrafo (≥ 2 × corpo):
//  vedi `detectFurniture`.
//

import Foundation

/// Taglia minima del testo bianco che la DPC legge (le ancore invisibili di Marrone sono a 1 pt).
let DPC_WHITE_MIN_SIZE = 6.0
/// Titolo della fascia: taglia ≥ 1,3 × corpo (18 pt di norma, 14 pt per i titoli lunghi; corpo 10).
let DPC_TITLE_MIN_RATIO = 1.3
/// Lettere minime di un titolo (esclude il numero del fascicolo in copertina).
let DPC_TITLE_MIN_LETTERS = 4
/// Il titolo sta nella metà alta della pagina (esclude l'ISSN in fondo alla copertina).
let DPC_TITLE_MAX_TOP_FRACTION = 0.40
/// Titolo di SEZIONE (fascia alta della pagina d'apertura, ~26 % dall'alto) vs titolo d'ARTICOLO (8-15 %).
let DPC_SECTION_TITLE_MIN_TOP_FRACTION = 0.20
/// Traduzione dei titoli: grigio chiaro, non saturo, a taglia ≥ 1,12 × corpo.
let DPC_TRANSLATION_MIN_RATIO = 1.12
/// Due righe di traduzione appartengono alla stessa traduzione se il passo è ≤ 1,35 × la taglia.
let DPC_TRANSLATION_MAX_PITCH_RATIO = 1.35
/// Numero di paragrafo: colorato, ≥ 2 × corpo, solo cifre e punti.
let DPC_PARAGRAPH_NUMBER_MIN_RATIO = 2.0
/// Titolo di paragrafo: colorato, ≥ 1,25 × corpo.
let DPC_PARAGRAPH_TITLE_MIN_RATIO = 1.25
/// Testo colorato «a taglia di corpo»: sotto questa soglia non è mai un titolo.
let DPC_COLORED_BODY_MAX_RATIO = 1.12

private let DPC_NUMBER_RE = try! NSRegularExpression(pattern: "^\\d{1,2}(?:\\.\\d{1,2}){0,3}\\.?$")

/// Grigio chiaro non saturo delle traduzioni dei titoli (#D1D3D4, #BCBEC0, #C6C6C6 nei due fascicoli).
func dpcIsTranslationGrey(_ color: String) -> Bool {
    if isNearWhite(color) { return false }
    let (r, g, b) = rgb(color)
    return min(r, g, b) >= 160 && max(r, g, b) - min(r, g, b) <= 40
}

/// Esito per riga della foglia (indici in `lines`, le righe di contenuto della pagina). Le righe senza
/// esito seguono la classificazione del tronco.
enum DpcLineDecision: Equatable {
    /// Primo indice di un titolo fuso: le righe `lines`, nell'ordine (il numero prima del titolo).
    case heading(level: Int, lines: [Int])
    /// Riga assorbita da un titolo fuso (emessa con il titolo).
    case absorbed
    /// Corpo, con una chiave di blocco: due righe con chiavi diverse non si fondono nello stesso nodo.
    /// `keepHyphens`: le righe del blocco si uniscono conservando il trattino a fine riga (traduzioni dei titoli).
    case body(block: Int, keepHyphens: Bool = false)
}

/// Unisce le righe di un titolo o di una traduzione della fascia CONSERVANDO il trattino a fine riga: nei
/// titoli della DPC un trattino a fine riga è lessicale (i quattro casi dei due fascicoli sono parole composte,
/// verificate col lessico: unite senza trattino non sono parole), mentre `joinLines` lo toglie come una
/// sillabazione e creava parole inesistenti.
func dpcJoinKeepingHyphens(_ lines: [String]) -> String {
    var out = ""
    for raw in lines {
        let line = jsTrim(raw)
        if line.isEmpty { continue }
        if out.isEmpty { out = line; continue }
        out += out.hasSuffix("-") ? line : " \(line)"
    }
    return out
}

/// Riga unica di un titolo o di una traduzione della fascia (geometria della prima riga, testo unito col trattino).
func dpcMergedLine(_ lines: [LineSummary]) -> LineSummary {
    var merged = mergedLine(lines)
    merged.text = dpcJoinKeepingHyphens(lines.map { $0.text })
    return merged
}

private func dpcLetters(_ text: String) -> Int {
    text.unicodeScalars.reduce(0) { $0 + (CharacterSet.letters.contains($1) ? 1 : 0) }
}

private func dpcMatches(_ re: NSRegularExpression, _ text: String) -> Bool {
    re.firstMatch(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text)) != nil
}

/// Profondità di un numero di paragrafo («2.» → 1, «2.1.» → 2).
func dpcNumberDepth(_ text: String) -> Int {
    jsTrim(text).split(separator: ".", omittingEmptySubsequences: true).count
}

/// Le decisioni della foglia struttura DPC per le righe di contenuto di una pagina. Vuoto fuori dalla DPC.
func dpcStructureDecisions(_ lines: [LineSummary], _ profile: Profile, pageHeight: Double) -> [Int: DpcLineDecision] {
    let body = profile.bodySize
    guard profile.isRivistaDpc, body > 0, pageHeight > 0, !lines.isEmpty else { return [:] }

    enum Kind { case title, bandText, translation, number, paragraphTitle, coloredBody, largeBlack }
    func topFraction(_ sm: LineSummary) -> Double { (pageHeight - sm.yTop) / pageHeight }
    func kind(_ sm: LineSummary) -> Kind? {
        guard sm.fontSize > 0 else { return nil }
        let ratio = sm.fontSize / body
        let text = jsTrim(sm.text)
        if isNearWhite(sm.color) {
            if ratio >= DPC_TITLE_MIN_RATIO, dpcLetters(text) >= DPC_TITLE_MIN_LETTERS,
               topFraction(sm) <= DPC_TITLE_MAX_TOP_FRACTION { return .title }
            return .bandText
        }
        if dpcIsTranslationGrey(sm.color) { return ratio >= DPC_TRANSLATION_MIN_RATIO ? .translation : nil }
        if isSaturated(sm.color) {
            if isUrlOrMailLine(text) { return nil }   // al tronco: un indirizzo non è mai un titolo (`classify`)
            if ratio >= DPC_PARAGRAPH_NUMBER_MIN_RATIO, dpcMatches(DPC_NUMBER_RE, text) { return .number }
            if ratio >= DPC_PARAGRAPH_TITLE_MIN_RATIO { return .paragraphTitle }
            // Solo dove il tronco ne farebbe un titolo a colore (taglia ≈ corpo): le righe colorate a taglia
            // di nota (un collegamento dentro una nota) restano al tronco, cioè nella loro nota.
            if ratio < DPC_COLORED_BODY_MAX_RATIO, isColorHeadingCandidate(sm, profile) { return .coloredBody }
            return nil
        }
        if ratio >= DPC_COLORED_BODY_MAX_RATIO, dpcLetters(text) > 0 { return .largeBlack }
        return nil
    }
    let kinds = lines.map(kind)
    var out: [Int: DpcLineDecision] = [:]
    var nextBlock = 1   // 0 = il corpo ordinario del tronco

    var i = 0
    while i < lines.count {
        guard let k = kinds[i] else { i += 1; continue }
        switch k {
        case .title:
            var group = [i]
            var j = i + 1
            while j < lines.count, kinds[j] == .title { group.append(j); j += 1 }
            let level = topFraction(lines[i]) >= DPC_SECTION_TITLE_MIN_TOP_FRACTION ? 1 : 2
            out[i] = .heading(level: level, lines: group)
            for g in group.dropFirst() { out[g] = .absorbed }
            i = j
        case .bandText, .coloredBody:
            let block = nextBlock; nextBlock += 1
            var j = i
            while j < lines.count, kinds[j] == k { out[j] = .body(block: block); j += 1 }
            i = j
        case .translation:
            var block = nextBlock; nextBlock += 1
            out[i] = .body(block: block, keepHyphens: true)
            var j = i + 1
            while j < lines.count, kinds[j] == .translation {
                let prev = lines[j - 1], cur = lines[j]
                let pitch = prev.yBottom - cur.yBottom
                let sameChunk = abs(prev.fontSize - cur.fontSize) < 0.5 && pitch > 0
                    && pitch <= DPC_TRANSLATION_MAX_PITCH_RATIO * prev.fontSize
                if !sameChunk { block = nextBlock; nextBlock += 1 }
                out[j] = .body(block: block, keepHyphens: true)
                j += 1
            }
            i = j
        case .largeBlack:
            out[i] = .body(block: 0)
            i += 1
        case .number, .paragraphTitle:
            i += 1   // appaiati sotto
        }
    }

    // Titoli di paragrafo. Il grande numero e il titolo stanno affiancati: una riga di titolo appartiene al
    // numero che la contiene nella propria altezza (la riga comincia fra il piede e la testa del numero).
    // Le righe successive dello stesso titolo seguono a passo di riga (≤ 1,35 × la taglia); un titolo può
    // contenere un punto (due frasi, «c.d.»): non si chiude sul punto ma sulla geometria.
    let numbers = lines.indices.filter { kinds[$0] == .number }
    func owner(_ t: Int) -> Int? {
        var best: (index: Int, distance: Double)?
        for n in numbers {
            let num = lines[n]
            guard lines[t].yTop <= num.yTop + 2, lines[t].yTop >= num.yBottom - 2 else { continue }
            let d = abs(num.yTop - lines[t].yTop)
            if best == nil || d < best!.distance { best = (n, d) }
        }
        return best?.index
    }
    var titleBlocks: [(owner: Int?, lines: [Int])] = []
    var current: (owner: Int?, lines: [Int])?
    for idx in lines.indices {
        guard kinds[idx] == .paragraphTitle else {
            if kinds[idx] != .number, let c = current { titleBlocks.append(c); current = nil }
            continue
        }
        let own = owner(idx)
        if var c = current, let last = c.lines.last {
            let pitch = lines[last].yBottom - lines[idx].yBottom
            let continuous = pitch > 0 && pitch <= DPC_TRANSLATION_MAX_PITCH_RATIO * lines[last].fontSize
            let sameOwner = own == nil ? continuous : own == c.owner
            if sameOwner {
                c.lines.append(idx); current = c; continue
            }
            titleBlocks.append(c)
        }
        current = (own, [idx])
    }
    if let c = current { titleBlocks.append(c) }

    var usedNumbers: Set<Int> = []
    for block in titleBlocks {
        var group = block.lines
        var level = 3
        if let n = block.owner, !usedNumbers.contains(n) {
            usedNumbers.insert(n)
            group.insert(n, at: 0)
            level = min(4, 2 + dpcNumberDepth(lines[n].text))
        }
        // Il titolo si emette dove comincia il TITOLO, non dove PDFKit mette il numero: su alcune pagine il
        // grande numero arriva in testa all'elenco delle righe (fra testatina e piè) e il titolo, emesso lì,
        // spezzava la frase che continua dalla pagina precedente (visto in rete: due pagine del 2020).
        let first = block.lines[0]
        out[first] = .heading(level: level, lines: group)
        for g in group where g != first { out[g] = .absorbed }
    }
    // Numero senza titolo accanto: testo, letto in testa al suo paragrafo (corpo ordinario).
    for n in lines.indices where kinds[n] == .number && !usedNumbers.contains(n) {
        out[n] = .body(block: 0)
    }
    return out
}
