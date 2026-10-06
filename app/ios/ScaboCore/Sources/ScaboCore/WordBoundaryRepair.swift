//
//  WordBoundaryRepair.swift
//  ScaboCore
//
//  Riparazione dei CONFINI DI PAROLA persi dal lettore PDF di sistema (giro «generazioni del lettore»,
//  2026-10-06, docs/GENERAZIONI_LETTORE.md). Funzione PURA, solo Foundation, applicata subito dopo
//  l'estrazione: la stessa per l'app, per il runner dell'officina e per il futuro Mac.
//
//  ── Il difetto (diagnosi riprodotta su PDF sintetici) ───────────────────────────────────────
//
//  Da iOS/macOS 27 PDFKit IGNORA la spaziatura dei caratteri `Tc` quando decide dove cadono gli spazi
//  fra le parole. Nei PDF composti da InDesign con tracking (es. Patriarca-Benazzo, Zanichelli) lo
//  spazio fra due parole è spesso prodotto dal SOLO `Tc` positivo (≈0,2 em dopo ogni glifo), mentre
//  dentro le parole il `Tc` è annullato da rinculi TJ: niente glifo-spazio, niente scarto TJ. Risultato
//  su iOS 27: due, tre o anche otto parole lette come una sola. iOS 26.5 leggeva bene.
//  Gli scarti TJ e `Td` ≥ ~0,13 em restano invece riconosciuti da PDFKit 27 (misurato): la cura si
//  limita ESATTAMENTE agli scarti posseduti da un run con `Tc` > 0.
//
//  ── La cura (solo inserimento di spazi, mai altro) ───────────────────────────────────────────
//
//  L'estrattore legge il flusso di contenuto con CoreGraphics (ScaboApp/PdfContentGlyphRuns.swift) e
//  consegna, per ogni operatore di testo, i glifi decodificati (ToUnicode) e lo scarto in em dopo
//  ciascun glifo: (Tc/Tfs − aggiustamentoTJ/1000)·Tz/100. Qui:
//   1. i run contigui (nessun posizionamento fra loro) formano una CATENA; lo scarto di giunzione è lo
//      scarto finale del run precedente (è lui che lo «possiede»);
//   2. candidato = scarto ≥ `WORD_GAP_MIN_EM` (0,15 em: sopra la soglia ~0,13 di PDFKit) il cui run
//      proprietario ha `Tc` > 0;
//   3. GUARDIA contro il testo spaziato uniformemente (titoli «I N D I C E», che PDFKit legge
//      giustamente «INDICE»): la catena deve contenere almeno una coppia di glifi stretta (≤ 0,05 em);
//      se tutti gli scarti sono larghi, nessun inserimento;
//   4. ALLINEAMENTO ESATTO: i caratteri non-spazio della catena devono comparire UNA SOLA volta in UNA
//      SOLA riga PDFKit della pagina (ago esteso ai vicini sulla stessa riga se ambiguo); altrimenti
//      nulla (fail-safe);
//   5. si inserisce uno spazio solo dove la riga NON ne ha già uno fra i due glifi.
//  Nessuna lettera è aggiunta, tolta o spostata; i riquadri non cambiano. Dove la riga ha già lo spazio
//  al candidato la funzione non fa nulla: su iOS 26.5, che gli spazi li ha, è identità misurata (52/52 letture).
//
//  Misurato (Mac 27 ≡ iOS 27, 26.5 come verità degli spazi): vedi docs/GENERAZIONI_LETTORE.md § 4.
//

import Foundation

/// Un operatore di testo del flusso di contenuto (Tj/TJ/'/"), già decodificato.
public struct GlyphRun: Equatable, Sendable {
    /// Testo di ciascun glifo (un glifo può dare più caratteri, es. legatura «fi»).
    public var glyphs: [String]
    /// Scarto orizzontale DOPO ciascun glifo, in em del font del run: (Tc/Tfs − adjTJ/1000)·Tz/100.
    /// `gapsEm.count == glyphs.count`; l'ultimo è lo scarto che il run lascia dopo il suo ultimo glifo.
    public var gapsEm: [Double]
    /// Vero se il run è stato mostrato con `Tc` > 0: solo i suoi scarti sono candidati.
    public var ownsGaps: Bool
    /// Vero se nessun operatore di posizionamento (Td/TD/Tm/T*/BT…) separa questo run dal precedente:
    /// i due sono contigui e lo scarto di giunzione è `gapsEm.last` del precedente.
    public var continuesPrevious: Bool
    /// Vero se il run sta sulla stessa riga del precedente (contiguo, oppure Td con spostamento
    /// verticale nullo): serve a estendere l'ago dell'allineamento quando è ambiguo.
    public var sameLineAsPrevious: Bool

    public init(glyphs: [String], gapsEm: [Double], ownsGaps: Bool, continuesPrevious: Bool, sameLineAsPrevious: Bool) {
        self.glyphs = glyphs
        self.gapsEm = gapsEm
        self.ownsGaps = ownsGaps
        self.continuesPrevious = continuesPrevious
        self.sameLineAsPrevious = sameLineAsPrevious
    }
}

/// Scarto minimo (em) perché un vuoto fra due glifi sia uno spazio fra parole. PDFKit 27 riconosce da
/// solo gli scarti geometrici ≥ ~0,13 em (misurato su PDF sintetici); 0,15 lascia margine.
public let WORD_GAP_MIN_EM = 0.15
/// Scarto massimo (em) di una coppia «stretta»: devono essere almeno quante i candidati della catena,
/// altrimenti il testo è spaziato uniformemente (tracking di titolo) e non si tocca.
public let WORD_GAP_TIGHT_EM = 0.05
/// Lunghezza minima (caratteri non-spazio) dell'ago di allineamento.
let WORD_GAP_MIN_NEEDLE = 4
/// Catene vicine (per lato) con cui estendere l'ago ambiguo.
let WORD_GAP_MAX_NEIGHBOURS = 3

/// Esito della riparazione: righe curate e conteggi content-free per l'audit.
public struct WordBoundaryRepairResult: Equatable, Sendable {
    public var lines: [PdfTextLine]
    /// Spazi inseriti.
    public var inserted: Int
    /// Candidati dove la riga aveva già lo spazio (accordo con il lettore: nessun intervento).
    public var alreadySpaced: Int
    /// Candidati lasciati stare perché la catena non si allinea in modo univoco a una riga.
    public var skippedAlignment: Int
    public init(lines: [PdfTextLine], inserted: Int, alreadySpaced: Int, skippedAlignment: Int) {
        self.lines = lines
        self.inserted = inserted
        self.alreadySpaced = alreadySpaced
        self.skippedAlignment = skippedAlignment
    }
}

/// Indice content-free di una riga: caratteri non-spazio e, per ciascuno, (span, offset) nel testo.
private struct LineIndex {
    var chars: [Character]
    var map: [(span: Int, offset: Int)]
    init(_ line: PdfTextLine) {
        chars = []; map = []
        for (si, s) in line.spans.enumerated() {
            for (ci, ch) in Array(s.text).enumerated() where !ch.isWhitespace {
                chars.append(ch); map.append((si, ci))
            }
        }
    }
}

/// Posizioni di `needle` in `hay` (si ferma alla seconda: basta sapere se è univoco).
private func occurrences(_ needle: [Character], in hay: [Character]) -> [Int] {
    guard !needle.isEmpty, needle.count <= hay.count else { return [] }
    var out: [Int] = []
    var i = 0
    while i + needle.count <= hay.count {
        var k = 0
        while k < needle.count && hay[i + k] == needle[k] { k += 1 }
        if k == needle.count { out.append(i); if out.count > 1 { return out } }
        i += 1
    }
    return out
}

private func nonSpaceChars(_ runs: [GlyphRun]) -> [Character] {
    runs.flatMap { $0.glyphs }.flatMap { Array($0) }.filter { !$0.isWhitespace }
}

/// Ripara i confini di parola delle `lines` di una pagina usando i `runs` del flusso di contenuto.
/// Pura: non muta gli argomenti; inserisce SOLO caratteri spazio, mai altro.
public func repairWordBoundaries(
    _ lines: [PdfTextLine],
    runs: [GlyphRun],
    minGapEm: Double = WORD_GAP_MIN_EM
) -> WordBoundaryRepairResult {
    var out = lines
    var inserted = 0, alreadySpaced = 0, skipped = 0
    guard !runs.isEmpty, !lines.isEmpty else {
        return WordBoundaryRepairResult(lines: out, inserted: 0, alreadySpaced: 0, skippedAlignment: 0)
    }
    var idx = out.map(LineIndex.init)

    // Catene di run contigui.
    var chains: [[GlyphRun]] = []
    for r in runs where !r.glyphs.isEmpty && r.glyphs.count == r.gapsEm.count {
        if r.continuesPrevious, !chains.isEmpty { chains[chains.count - 1].append(r) } else { chains.append([r]) }
    }

    func findUnique(_ needle: [Character]) -> [(line: Int, pos: Int)] {
        var hits: [(line: Int, pos: Int)] = []
        for (li, ix) in idx.enumerated() {
            for p in occurrences(needle, in: ix.chars) { hits.append((li, p)); if hits.count > 1 { return hits } }
        }
        return hits
    }

    for (ci, chain) in chains.enumerated() {
        // Glifi e scarti della catena; lo scarto finale dell'ultimo run non ha vicino.
        var glyphs: [String] = [], gaps: [Double] = [], owned: [Bool] = []
        for (ri, r) in chain.enumerated() {
            for (gi, g) in r.glyphs.enumerated() {
                glyphs.append(g)
                if ri == chain.count - 1 && gi == r.glyphs.count - 1 { break }
                gaps.append(r.gapsEm[gi]); owned.append(r.ownsGaps)
            }
        }
        guard !gaps.isEmpty else { continue }
        var candidates: [Int] = []
        for (i, g) in gaps.enumerated() where owned[i] && g >= minGapEm { candidates.append(i) }
        guard !candidates.isEmpty else { continue }
        // Guardia contro il testo spaziato uniformemente (titoli «I N D I C E», anche con una coppia
        // crenata): le coppie strette devono essere almeno quante i candidati — in una riga di parole
        // vere le lettere dentro le parole sono più degli spazi fra le parole.
        let tight = gaps.filter { $0 <= WORD_GAP_TIGHT_EM }.count
        guard tight >= candidates.count else { continue }
        // Solo catene con almeno una lettera: righe di soli puntini di conduzione o numeri non si toccano
        // (la forma dei leader governa il riconoscimento degli indici).
        guard glyphs.contains(where: { $0.contains(where: { $0.isLetter }) }) else { continue }

        // Ago: caratteri non-spazio della catena; endIdx[i] = indice dell'ultimo carattere del glifo i.
        var needle: [Character] = [], endIdx: [Int] = []
        for g in glyphs {
            for ch in g where !ch.isWhitespace { needle.append(ch) }
            endIdx.append(needle.count - 1)
        }
        guard needle.count >= WORD_GAP_MIN_NEEDLE else { skipped += candidates.count; continue }

        var hits = findUnique(needle)
        var offset = 0
        if hits.count > 1 {
            // Ambiguo: estendi l'ago con le catene vicine sulla stessa riga.
            var lo = ci, hi = ci, ext = needle
            for _ in 0..<WORD_GAP_MAX_NEIGHBOURS where hits.count > 1 {
                var grew = false
                if lo > 0, chains[lo].first?.sameLineAsPrevious == true {
                    lo -= 1
                    let pre = nonSpaceChars(chains[lo])
                    ext = pre + ext; offset += pre.count; grew = true
                    hits = findUnique(ext)
                    if hits.count <= 1 { break }
                }
                if hi + 1 < chains.count, chains[hi + 1].first?.sameLineAsPrevious == true {
                    hi += 1
                    ext += nonSpaceChars(chains[hi]); grew = true
                    hits = findUnique(ext)
                }
                if !grew { break }
            }
        }
        guard hits.count == 1 else { skipped += candidates.count; continue }
        let li = hits[0].line
        let pos = hits[0].pos + offset

        var insertions: [(span: Int, offset: Int)] = []
        for i in candidates {
            let e = endIdx[i]
            guard e >= 0, pos + e + 1 < idx[li].map.count, e + 1 < needle.count else { continue }
            let a = idx[li].map[pos + e], b = idx[li].map[pos + e + 1]
            let spans = out[li].spans
            // C'è già uno spazio fra i due glifi nella riga?
            var between = ""
            if a.span == b.span {
                let arr = Array(spans[a.span].text)
                between = String(arr[(a.offset + 1)..<b.offset])
            } else {
                between = String(Array(spans[a.span].text)[(a.offset + 1)...])
                for k in (a.span + 1)..<b.span { between += spans[k].text }
                between += String(Array(spans[b.span].text)[..<b.offset])
            }
            if between.contains(where: { $0.isWhitespace }) { alreadySpaced += 1; continue }
            if insertions.contains(where: { $0.span == a.span && $0.offset == a.offset }) { continue }
            insertions.append((a.span, a.offset))
        }
        // Dal fondo, per non spostare gli offset.
        for ins in insertions.sorted(by: { ($0.span, $0.offset) > ($1.span, $1.offset) }) {
            var arr = Array(out[li].spans[ins.span].text)
            arr.insert(" ", at: ins.offset + 1)
            out[li].spans[ins.span].text = String(arr)
            inserted += 1
        }
        if !insertions.isEmpty { idx[li] = LineIndex(out[li]) }
    }
    return WordBoundaryRepairResult(lines: out, inserted: inserted, alreadySpaced: alreadySpaced, skippedAlignment: skipped)
}

/// U+FFFC OBJECT REPLACEMENT CHARACTER: da iOS/macOS 27 PDFKit ne emette uno per ogni IMMAGINE della
/// pagina (13 occorrenze su 10 pagine di 8 volumi del corpus; iOS 26.5: zero). Non è testo: in lettura
/// diventava un'«Intestazione di livello 1» vuota (Marotta p.3, Mandrioli 3/4 colophon, Breve storia
/// p.7) o un titolo con segnaposto («17￼»). Si toglie; le righe che restano vuote cadono.
public let OBJECT_REPLACEMENT_CHARACTER: Character = "\u{FFFC}"

/// Rimuove U+FFFC dagli span; scarta gli span rimasti vuoti e le righe rimaste bianche. Identità dove
/// il carattere non c'è. I riquadri non cambiano.
public func removingObjectReplacementCharacters(_ lines: [PdfTextLine]) -> [PdfTextLine] {
    var out: [PdfTextLine] = []
    out.reserveCapacity(lines.count)
    for line in lines {
        guard line.spans.contains(where: { $0.text.contains(OBJECT_REPLACEMENT_CHARACTER) }) else {
            out.append(line); continue
        }
        var spans: [PdfSpan] = []
        for var s in line.spans {
            s.text.removeAll { $0 == OBJECT_REPLACEMENT_CHARACTER }
            if !s.text.isEmpty { spans.append(s) }
        }
        let joined = spans.map { $0.text }.joined()
        if !joined.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            out.append(PdfTextLine(spans: spans, bbox: line.bbox))
        }
    }
    return out
}
