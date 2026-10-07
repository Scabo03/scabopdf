//
//  MonoTitles.swift
//  ScaboCore
//
//  Canale dei TITOLI e dei PARAGRAFI per i documenti MONOTIPOGRAFICI — le dispense scritte con
//  Pages, Word o Google Docs (giro «titoli e testatine», 2026-10-07; docs/TITOLI_MONOTIPOGRAFICI.md).
//
//  ── Il difetto ──────────────────────────────────────────────────────────────────────────────
//
//  In una dispensa titolo e corpo hanno la stessa taglia, lo stesso stile, lo stesso colore: il
//  classificatore del tronco (taglia, colore, grassetto) non vede mai un titolo, e la pagina diventa
//  un solo blocco di corpo. Il titolo finisce incollato in testa o in mezzo a un blocco di ~400
//  caratteri: niente annuncio, niente voce nel rotore.
//
//  ── La firma di formato (non un elenco di programmi) ────────────────────────────────────────
//
//  Il canale si accende SOLO dove il documento è monotipografico: lo stile dominante (taglia a mezzo
//  punto, grassetto, corsivo, colore) copre ≥ 99 % dei caratteri delle righe con lettere, e gli stili
//  secondari stanno su al più max(2, 5 %) delle pagine (copertina, un collegamento). Non dipende dal
//  produttore del PDF, che un salvataggio da iPad riscrive: copre qualunque editor. Misurato sui 52
//  volumi di riferimento su iOS 27 e 26.5: le 10 dispense e appunti monotipografici hanno ≤ 2 pagine con
//  uno stile secondario (≤ 1,2 %), il primo volume non monotipografico il 13,8 %, i volumi editoriali dal
//  18 % al 100 % (note, titoli in grassetto, piè di pagina). Sui volumi editoriali il canale è un no-op
//  PER COSTRUZIONE (`profile.mono == nil`).
//
//  ── La calibrazione per documento ───────────────────────────────────────────────────────────
//
//  Ogni editor marca la struttura con lo spazio verticale, ma ognuno a modo suo: Pages solo con una riga
//  vuota prima dei titoli (nessuno stacco di paragrafo); Word con uno stacco di paragrafo di ~8 pt e
//  righe vuote più grandi; Google Docs con ~18-20 pt fra paragrafi e ~52 pt prima dei titoli. Si misura
//  il passo normale fra le righe (moda), le classi di stacco oltre il passo, e la classe più frequente.
//  Questa marca i TITOLI (stile Pages: la riga vuota sta solo prima dei titoli) se è RARA (< 15 % delle
//  coppie di righe) e se dopo di essa arriva per lo più (≥ 50 %) un blocco con forma di titolo; altrimenti
//  è lo stacco di PARAGRAFO (Word, Google Docs, appunti dove la riga vuota separa i paragrafi) e i titoli
//  chiedono uno stacco maggiore (paragrafo + max(2 pt; 25 %)).
//
//  ── Il titolo (precisione prima del richiamo) ───────────────────────────────────────────────
//
//  Un titolo falso è peggio di un titolo mancante: annuncia una struttura che non c'è. Titolo =
//  blocco breve (≤ 160 caratteri), isolato in alto da uno stacco maggiore dello stacco di paragrafo (o
//  in cima alla pagina con le guardie sotto), chiuso in basso, che non finisce con punteggiatura né con
//  «che»/«di»/«e», non è una voce d'elenco né una nota «(46)», non contiene due frasi, non porta la
//  sillabazione dell'OCR. Stile Pages: il titolo cresce sulle righe che lo continuano (minuscola, cifra,
//  o titolo che finisce con «di», «della», una sigla, un trattino) e si chiude sulla prima riga che
//  riparte in MAIUSCOLA (il corpo). Stile Word/Google Docs: il titolo è il paragrafo dell'editor stesso
//  (≤ 3 righe). In cima alla pagina lo stacco non si misura: stile Pages, vale solo se la pagina
//  precedente finisce chiusa e più corta di almeno una riga (la riga vuota prima del titolo); stile
//  Word/Google Docs, vale solo se lo segue lo stacco di paragrafo e poi il corpo — la riga d'autore
//  sotto un titolo di capitolo è seguita da un altro titolo, e resta corpo.
//
//  ── Il paragrafo ────────────────────────────────────────────────────────────────────────────
//
//  Dove l'editor marca lo stacco di paragrafo, il blocco di corpo si spezza anche in paragrafi —
//  SOLO dove il paragrafo chiude una frase e il seguente riparte in maiuscola, così un elemento non
//  spezza mai una frase (§ 7.6) e gli «a capo» dentro un paragrafo restano dentro. Cambiano i confini
//  degli elementi, non le lettere: ogni riga finisce in esattamente un item. La granularità (§ 7.6)
//  rispetta il confine grazie alla famiglia `monotipografico` del documento (`buildBaseSegments`).
//
//  ── Il livello ──────────────────────────────────────────────────────────────────────────────
//
//  Una parola-chiave di struttura dà il suo livello (PARTE/LIBRO/TITOLO 1, CAPITOLO/CAP./CAPO 2,
//  SEZIONE/SEZ. 3), come la foglia degli appunti; altrimenti il titolo sta un livello sotto l'ultima
//  intestazione a parola-chiave, o al livello dell'ultimo titolo (fratello). Senza nulla prima: 2.
//

import Foundation

/// `editorial_family` dei documenti monotipografici: porta la firma allo strato dei segmenti, dove la
/// granularità rispetta i paragrafi dell'editor (`buildBaseSegments` → `granularizeBody`).
public let MONOTYPOGRAPHIC_FAMILY = "monotipografico"

/// Quota minima dei caratteri (righe con lettere) nello stile dominante.
let MONO_DOMINANT_SHARE = 0.99
/// Pagine con uno stile secondario: al più max(MONO_SECONDARY_PAGES_MIN, frazione delle pagine).
let MONO_SECONDARY_PAGES_MIN = 2
let MONO_SECONDARY_PAGES_FRACTION = 0.05
/// La classe di stacco più frequente può marcare i TITOLI solo se compare su meno di questa frazione delle
/// coppie di righe (dispense Pages ≤ 3,4 %; testo OCR incollato, una riga per paragrafo, 31 %).
let MONO_TITLE_MARKER_MAX_FRACTION = 0.15
/// Lunghezza massima di un titolo.
let MONO_TITLE_MAX = 160
/// Righe massime di un titolo: stile Pages (a 40 pt un titolo va a capo ogni 2-3 parole: il tetto vero è quello
/// dei caratteri, `MONO_TITLE_MAX`) e stile Word/Google Docs (il titolo è il paragrafo dell'editor).
let MONO_TITLE_MAX_ROWS_PAGES = 6
let MONO_TITLE_MAX_ROWS_PARAGRAPH = 3

/// Una riga FISICA: le righe di PDFKit sulla stessa linea di base fuse da sinistra a destra (Pages
/// spezza «CAP. 2», «-», «TITOLO» in tre righe alla stessa quota).
struct MonoRow {
    var lines: [LineSummary]
    var text: String { joinLines(lines.map { $0.text }) }
    var x0: Double { lines.map { $0.x0 }.min() ?? 0 }
    var x1: Double { lines.map { $0.x1 }.max() ?? 0 }
    var yBottom: Double { lines[0].yBottom }
}

/// Finestra dell'aggancio alla linea di base: un pezzo torna nella sua riga solo se PDFKit l'ha emesso al più
/// due righe fisiche dopo di essa (misurato sui 10 documenti monotipografici, entrambe le generazioni: mai
/// oltre 2). In un documento a due colonne la colonna destra arriva dopo l'intera colonna sinistra: resta
/// fuori finestra, e le colonne non si intrecciano mai.
let MONO_ROW_REGROUP_WINDOW = 3

/// Raggruppa le righe alla stessa linea di base (|Δ| ≤ 1 pt) in righe FISICHE, ordinate da sinistra a destra.
/// Un pezzo che PDFKit emette fuori ordine (iOS 26.5: metà di un titolo dopo la riga sotto) torna nella sua riga.
/// Si aggancia solo dentro la finestra e solo un pezzo che non si sovrappone ai pezzi già nella riga (un
/// testo sovrastampato resta com'è emesso).
func monoRows(_ lines: [LineSummary]) -> [MonoRow] {
    var rows: [MonoRow] = []
    for sm in lines {
        let window = max(0, rows.count - MONO_ROW_REGROUP_WINDOW)..<rows.count
        if let r = rows[window].lastIndex(where: { row in
            abs(row.yBottom - sm.yBottom) <= 1.0
                && row.lines.allSatisfy { $0.x1 <= sm.x0 + 1 || sm.x1 <= $0.x0 + 1 }
        }) {
            rows[r].lines.append(sm)
        } else {
            rows.append(MonoRow(lines: [sm]))
        }
    }
    for i in rows.indices where rows[i].lines.count > 1 {
        rows[i].lines.sort { $0.x0 < $1.x0 }   // tutti entro 1 pt dalla stessa linea di base
    }
    return rows
}

/// Le lettere del testo sono tutte maiuscole (titolo in maiuscolo).
private func allCapsLetters(_ text: String) -> Bool {
    let letters = text.filter { $0.isLetter }
    return letters.count >= 2 && letters.allSatisfy { $0.isUppercase }
}

/// Calibrazione di un documento monotipografico (nil = documento non monotipografico: canale spento).
struct MonoCalibration {
    /// Passo normale fra due righe consecutive (linea di base → linea di base, moda).
    let pitch: Double
    let tolerance: Double
    /// Stacco di paragrafo dell'editor (oltre il passo), nil se l'editor non lo marca.
    let paragraphGap: Double?
    /// Stacco oltre il quale un blocco è isolato come titolo.
    let titleGap: Double
    /// Stile Pages: la riga vuota marca i titoli (non i paragrafi).
    let blankLineMarksTitles: Bool
    /// Bordo destro tipico delle righe (90° percentile).
    let rightEdge: Double
    /// Per pagina: l'ultima riga chiude con punteggiatura forte.
    let pageCloses: [Int: Bool]
    /// Per pagina: di quanto l'ultima riga sta sopra il fondo tipico di una pagina piena (pt).
    let pageShortBy: [Int: Double]
    /// Per pagina: la prima riga riparte in maiuscola.
    let pageFirstUpper: [Int: Bool]
}

private let MONO_STRONG_END = try! NSRegularExpression(pattern: "[.!?…:;»”\")\\]]\\s*$")
private let MONO_TERMINAL = try! NSRegularExpression(pattern: "[.;:,!?…]\\s*$")
private let MONO_LIST_MARK = try! NSRegularExpression(
    pattern: "^\\s*(?:[-–—•*▪◦·]\\s|[a-z]\\)\\s|\\(?[ivx]{1,4}\\)\\s|\\d{1,2}\\)\\s|\\(\\d{1,3}\\)\\s)")
private let MONO_DATE_ONLY = try! NSRegularExpression(pattern: "^\\s*\\d{1,2}[./]\\d{1,2}[./]\\d{2,4}\\s*$")
private let MONO_FUNCTION_END = try! NSRegularExpression(
    pattern: "(?:^|\\s)(?:e|ed|o|di|del|della|dello|dei|degli|delle|da|dal|dalla|in|nel|nella|con|per|tra|fra|su|sul|sulla|a|al|alla|il|lo|la|i|gli|le|un|una|uno|che|come)\\s*$",
    options: [.caseInsensitive])
private let MONO_OCR_HYPHEN = try! NSRegularExpression(pattern: "\\p{L}-\\s\\p{Ll}")
/// Due frasi: una parola minuscola di almeno tre lettere, un punto, uno spazio e una maiuscola.
private let MONO_TWO_SENTENCES = try! NSRegularExpression(pattern: "\\p{Ll}{3,}\\.\\s+[-–—]?\\s*\\p{Lu}")
/// Righe di colophon / timbro di banca dati: mai titoli di sezione.
private let MONO_COLOPHON = try! NSRegularExpression(
    pattern: "copyright|©|\\bisbn\\b|https?:|www\\.|@", options: [.caseInsensitive])
/// Parola-chiave di struttura + ordinale (anche senza trattino-titolo, anche in tondo: «Sezione 1»).
private let MONO_KEYWORD_RE = try! NSRegularExpression(
    pattern: "^(PARTE|LIBRO|TITOLO|CAPITOLO|CAP\\.|CAPO|SEZIONE|SEZ\\.)\\s*"
        + "(?:\\d{1,3}|[IVXLCDM]{1,6}|PRIM[OA]|SECOND[OA]|TERZ[OA]|QUART[OA]|QUINT[OA]|SEST[OA]|SETTIM[OA]"
        + "|OTTAV[OA]|NON[OA]|DECIM[OA]|UNIC[OA])\\b\\s*(?:$|[–—\\-:.]\\s*\\S)",
    options: [.caseInsensitive])

private func hits(_ re: NSRegularExpression, _ s: String) -> Bool {
    re.firstMatch(in: s, range: NSRange(s.startIndex..<s.endIndex, in: s)) != nil
}

/// Livello di una parola-chiave di struttura in apertura di titolo, o nil.
func monoKeywordLevel(_ text: String) -> Int? {
    let t = jsTrim(text)
    if let l = userNotesHeadingLevel(t) { return l }
    guard t.utf16.count <= 120, t.first?.isUppercase == true,
          let m = MONO_KEYWORD_RE.firstMatch(in: t, range: NSRange(t.startIndex..<t.endIndex, in: t)),
          let r = Range(m.range(at: 1), in: t) else { return nil }
    switch t[r].uppercased() {
    case "PARTE", "LIBRO", "TITOLO": return 1
    case "SEZIONE", "SEZ.": return 3
    default: return 2
    }
}

/// Chiave di stile di una riga (taglia a mezzo punto, grassetto, corsivo, colore) per la firma di formato.
struct MonoStyleKey: Hashable { let size: Double; let bold: Bool; let italic: Bool; let color: String }

/// Censimento degli stili delle righe con lettere (raccolto nello stesso passaggio di `estimateProfile`).
struct MonoStyleCensus {
    var chars: [MonoStyleKey: Int] = [:]
    var pages: [MonoStyleKey: Set<Int>] = [:]
    mutating func add(_ sm: LineSummary, page: Int) {
        guard !sm.text.isEmpty, !isNearWhite(sm.color), isSubstantial(sm.text) else { return }
        let k = MonoStyleKey(size: (sm.fontSize * 2).rounded() / 2, bold: sm.bold, italic: sm.italic, color: sm.color)
        chars[k, default: 0] += sm.text.utf16.count
        pages[k, default: []].insert(page)
    }
}

/// Firma di formato (vedi testata): stile dominante ≥ 99 % dei caratteri e stili secondari su al più
/// max(2, 5 %) delle pagine.
func isMonotypographic(_ census: MonoStyleCensus, pageCount: Int) -> Bool {
    let total = census.chars.values.reduce(0, +)
    // Stile dominante deterministico (a parità di caratteri vince la taglia più grande, poi il colore).
    guard pageCount >= 2, total > 0, let top = census.chars.max(by: { a, b in
        a.value != b.value ? a.value < b.value
            : (a.key.size != b.key.size ? a.key.size < b.key.size : a.key.color < b.key.color)
    })?.key else { return false }
    guard Double(census.chars[top]!) / Double(total) >= MONO_DOMINANT_SHARE else { return false }
    var secondary = Set<Int>()
    for (k, ps) in census.pages where k != top { secondary.formUnion(ps) }
    let maxSecondary = max(MONO_SECONDARY_PAGES_MIN, Int((Double(pageCount) * MONO_SECONDARY_PAGES_FRACTION).rounded(.up)))
    return secondary.count <= maxSecondary
}

/// Calibrazione di un documento GIÀ riconosciuto monotipografico (vedi testata). Nil se mancano righe.
func monotypographicCalibration(_ extraction: PdfExtraction) -> MonoCalibration? {
    // ── calibrazione sulle righe fisiche (niente numeri nudi: i folii non sono testo) ──
    var rowsByPage: [Int: [MonoRow]] = [:]
    for page in extraction.pages {
        var lines: [LineSummary] = []
        for line in page.lines {
            let sm = summarizeLine(line)
            if sm.text.isEmpty || isNearWhite(sm.color) { continue }
            if jsTrim(normalizeDigits(sm.text)) == BARE_NUMBER_NORM { continue }
            lines.append(sm)
        }
        rowsByPage[page.pageIndex] = monoRows(lines)
    }
    var pitchCount: [Int: Int] = [:]
    var pairs = 0
    for page in extraction.pages {
        let rows = rowsByPage[page.pageIndex] ?? []
        for i in rows.indices.dropFirst() {
            let d = rows[i - 1].yBottom - rows[i].yBottom
            if d > 0.5 { pitchCount[Int(d.rounded()), default: 0] += 1; pairs += 1 }
        }
    }
    guard let pitchKey = pitchCount.max(by: { $0.value != $1.value ? $0.value < $1.value : $0.key > $1.key })?.key
    else { return nil }
    let pitch = Double(pitchKey)
    let tolerance = max(1.5, 0.08 * pitch)
    // classi di stacco oltre il passo (valori vicini fusi: ±max(2, 10 %))
    var gapValues: [Double] = []
    for page in extraction.pages {
        let rows = rowsByPage[page.pageIndex] ?? []
        for i in rows.indices.dropFirst() {
            let d = rows[i - 1].yBottom - rows[i].yBottom
            if d > pitch + tolerance { gapValues.append(d - pitch) }
        }
    }
    gapValues.sort()
    var classes: [(center: Double, count: Int)] = []
    var cur: [Double] = []
    for g in gapValues {
        if let last = cur.last, g - last > max(2.0, 0.1 * last) {
            classes.append((cur.reduce(0, +) / Double(cur.count), cur.count)); cur = []
        }
        cur.append(g)
    }
    if !cur.isEmpty { classes.append((cur.reduce(0, +) / Double(cur.count), cur.count)) }
    let mostFrequent = classes.max(by: { $0.count != $1.count ? $0.count < $1.count : $0.center > $1.center })
    // La classe di stacco più frequente marca i TITOLI (stile Pages: la riga vuota sta solo prima dei titoli)
    // se ciò che la segue ha per lo più forma di titolo E se è rara (< 15 % delle coppie di righe: nelle
    // dispense Pages ≤ 3,4 %); altrimenti è lo STACCO DI PARAGRAFO dell'editor (Word ~8 pt, Google Docs
    // ~18 pt, appunti dove la riga vuota separa i paragrafi, testo OCR incollato con una riga per paragrafo)
    // e i titoli chiedono uno stacco maggiore.
    var paragraphGap: Double? = nil
    var titleGap = 0.6 * pitch
    var blankLineMarksTitles = false
    if let m = mostFrequent {
        let near = max(2.0, 0.1 * m.center)
        var post = 0, shaped = 0
        for page in extraction.pages {
            let rows = rowsByPage[page.pageIndex] ?? []
            for i in rows.indices.dropFirst() where abs(rows[i - 1].yBottom - rows[i].yBottom - pitch - m.center) <= near {
                post += 1
                var block: [MonoRow] = []
                var j = i
                while j < rows.count, j == i || rows[j - 1].yBottom - rows[j].yBottom - pitch <= tolerance {
                    block.append(rows[j]); j += 1
                }
                let (head, used) = pagesHead(block)
                let closed = used < block.count ? startsWithUppercaseLetter(block[used].text) : j < rows.count
                if closed, head.utf16.count <= MONO_TITLE_MAX, !hits(MONO_TERMINAL, head) { shaped += 1 }
            }
        }
        let rare = Double(m.count) < MONO_TITLE_MARKER_MAX_FRACTION * Double(max(1, pairs))
        if rare, post > 0, Double(shaped) >= 0.5 * Double(post) {
            blankLineMarksTitles = true
        } else {
            paragraphGap = m.center
            titleGap = m.center + max(2.0, 0.25 * m.center)
        }
    }

    // fondo tipico di una pagina piena, bordo destro tipico, fatti di pagina per i titoli in cima
    var lastCount: [Int: Int] = [:]
    var x1s: [Double] = []
    var pageCloses: [Int: Bool] = [:]
    var lastBottom: [Int: Double] = [:]
    var pageFirstUpper: [Int: Bool] = [:]
    for page in extraction.pages {
        let rows = rowsByPage[page.pageIndex] ?? []
        guard let first = rows.first, let last = rows.last else { continue }
        lastCount[Int(last.yBottom.rounded()), default: 0] += 1
        lastBottom[page.pageIndex] = last.yBottom
        pageCloses[page.pageIndex] = hits(MONO_STRONG_END, jsTrim(last.text))
        pageFirstUpper[page.pageIndex] = jsTrim(first.text).first.map { $0.isLetter && $0.isUppercase } ?? false
        for r in rows { x1s.append(r.x1) }
    }
    let fullBottom = Double(lastCount.max(by: { $0.value != $1.value ? $0.value < $1.value : $0.key > $1.key })?.key ?? 0)
    var pageShortBy: [Int: Double] = [:]
    for (p, b) in lastBottom { pageShortBy[p] = b - fullBottom }
    x1s.sort()
    let rightEdge = x1s.isEmpty ? 0 : x1s[Int(0.9 * Double(x1s.count - 1))]

    return MonoCalibration(
        pitch: pitch, tolerance: tolerance, paragraphGap: paragraphGap, titleGap: titleGap,
        blankLineMarksTitles: blankLineMarksTitles, rightEdge: rightEdge, pageCloses: pageCloses,
        pageShortBy: pageShortBy, pageFirstUpper: pageFirstUpper)
}

/// L'ultima riga di un titolo è CORTA: finisce prima del margine destro della colonna (meno un decimo
/// della sua larghezza). Una riga che arriva al margine è una riga di paragrafo che va a capo: la riga dopo
/// ne continua la frase anche se comincia in maiuscola (un nome proprio, una sigla).
func monoRowIsShort(_ row: MonoRow, _ mono: MonoCalibration) -> Bool {
    row.x1 < mono.rightEdge - 0.10 * max(0, mono.rightEdge - row.x0)
}

private func startsWithUppercaseLetter(_ text: String) -> Bool {
    guard let c = jsTrim(text).first else { return false }
    return c.isLetter && c.isUppercase
}

/// Testa di un blocco alla Pages: le righe che continuano il titolo (riga seguente in minuscola o
/// cifra, o titolo che finisce con «di»/«della», una sigla, un trattino). Ritorna il testo e il numero
/// di righe usate.
func pagesHead(_ rows: [MonoRow]) -> (String, Int) {
    guard !rows.isEmpty else { return ("", 0) }
    var used = 1
    var text = jsTrim(rows[0].text)
    while used < rows.count, used < MONO_TITLE_MAX_ROWS_PAGES, text.utf16.count <= MONO_TITLE_MAX {
        let next = jsTrim(rows[used].text)
        guard let n0 = next.first else { break }
        // un titolo tutto maiuscolo continua su una riga tutta maiuscola (il corpo non lo è mai)
        let continues = n0.isLowercase || n0.isNumber || hits(MONO_FUNCTION_END, text)
            || monoEndsWithAbbreviation(text) || text.hasSuffix("-")
            || (allCapsLetters(text) && allCapsLetters(next))
        guard continues else { break }
        text = joinLines([text, next])
        used += 1
    }
    return (text, used)
}

/// Il testo finisce con «<sigla>.» della lista chiusa (un punto che non chiude: «art.»).
func monoEndsWithAbbreviation(_ t: String) -> Bool {
    guard t.hasSuffix(".") else { return false }
    let chars = Array(t.dropLast())
    var i = chars.count - 1
    while i >= 0, chars[i].isLetter || chars[i] == "." { i -= 1 }
    let token = String(chars[(i + 1)...]).lowercased()
    let letters = token.filter { $0.isLetter }
    if letters.isEmpty { return false }
    if letters.count == 1 { return true }
    // sigla puntata lettera per lettera («s.c.i.a.», «c.p.c.»): il punto finale è della sigla
    // (il punto finale è già tolto: «s.c.i.a» ha 2n−1 caratteri, lettere e punti alternati)
    if letters.count >= 2, token.count == 2 * letters.count - 1,
       token.enumerated().allSatisfy({ i, c in i % 2 == 0 ? c.isLetter : c == "." }) {
        return true
    }
    return SENTENCE_ABBREVIATIONS.contains(token) || SENTENCE_ABBREVIATIONS.contains(String(letters))
}

/// Forma di un titolo (vedi testata): lunghezza, lettere vere o data, apertura, niente elenco/nota,
/// niente punteggiatura finale (salvo una sigla), niente parola funzionale finale, una sola frase,
/// niente sillabazione OCR.
func monoTitleShape(_ text: String) -> Bool {
    let t = jsTrim(text)
    guard !t.isEmpty, t.utf16.count <= MONO_TITLE_MAX else { return false }
    let letters = t.filter { $0.isLetter }.count
    guard letters >= 3 || hits(MONO_DATE_ONLY, t) else { return false }
    guard let c = t.first, (c.isLetter && c.isUppercase) || c.isNumber || "«\"“(".contains(c) else { return false }
    if hits(MONO_LIST_MARK, t) { return false }
    if hits(MONO_TERMINAL, t) && !monoEndsWithAbbreviation(t) { return false }
    if hits(MONO_FUNCTION_END, t) { return false }
    if hits(MONO_TWO_SENTENCES, t) { return false }
    if hits(MONO_OCR_HYPHEN, t) { return false }
    if hits(MONO_COLOPHON, t) { return false }
    if hits(MONO_NUMBER_ENUMERATION, t) { return false }
    return true
}

/// Un elenco di numeri dopo al più una parola («Capp. 1, 2, 3, 5»): un sommario di copertina, non un titolo.
private let MONO_NUMBER_ENUMERATION = try! NSRegularExpression(
    pattern: "^(?:\\S+\\s+)?\\d+(?:\\s*(?:[,;]|\\be\\b)\\s*\\d+){2,}\\s*$")

/// Sigla minuscola col punto in apertura di paragrafo («d.lgs.», «t.u.»): un'apertura legittima.
private let MONO_LOWER_ABBREVIATION_START = try! NSRegularExpression(pattern: "^\\p{Ll}{1,6}\\.(?:\\p{Ll}{1,6}\\.)*(?:\\s|$)")

/// Il paragrafo seguente RIPARTE: maiuscola, cifra, parentesi, virgolette, segno d'elenco, o una sigla
/// minuscola col punto. Una parola minuscola qualunque è la frase che continua dopo lo stacco.
func paragraphRestarts(_ text: String) -> Bool {
    let t = jsTrim(text)
    guard let c = t.first else { return false }
    if (c.isLetter && c.isUppercase) || c.isNumber || "(«\"“'-–—•".contains(c) { return true }
    return hits(MONO_LOWER_ABBREVIATION_START, t)
}

/// Il paragrafo precedente chiude una frase e il seguente apre (maiuscola, cifra, virgolette, elenco).
/// Un punto dopo un'abbreviazione («art.», «cfr.», «d.P.R.», un'iniziale) non chiude la frase: la stessa regola
/// della granularità (`SENTENCE_ABBREVIATIONS`), così uno stacco casuale fra «art.» e il suo numero non spezza mai il
/// paragrafo (testo OCR incollato: interlinea irregolare).
private func paragraphBoundary(previous: String, next: String) -> Bool {
    let p = jsTrim(previous)
    guard hits(MONO_STRONG_END, p), !monoEndsWithAbbreviation(p), let c = jsTrim(next).first else { return false }
    return (c.isLetter && c.isUppercase) || c.isNumber || "«\"“(-–—•".contains(c)
}

/// Il canale (vedi testata): spezza i run di corpo di una pagina monotipografica in paragrafi e titoli.
/// No-op dove il documento non è monotipografico. Ogni riga finisce in esattamente un item.
func recognizeMonoTitles(_ items: [GenItem], page: PdfPageExtraction, _ profile: Profile) -> [GenItem] {
    guard let mono = profile.mono else { return items }
    let pageIndex = page.pageIndex
    var out: [GenItem] = []
    // Linea di base dell'ultima riga dell'unità precedente sulla pagina. Dopo un item che non è corpo
    // (titolo, nota) resta IGNOTA: un titolo su più righe porta la geometria della prima riga, e uno
    // stacco misurato da lì sarebbe gonfiato. Ignoto = mai titolo, mai paragrafo (prudenza).
    var prevBottom: Double? = nil
    var unitBefore = false           // c'è già un'unità sulla pagina (non siamo in cima)
    for (itemIndex, item) in items.enumerated() {
        // Una riga fuori dallo stile dominante classificata NOTA (in un documento monotipografico non ci sono
        // note vere: è una riga di copertina o un'etichetta più piccola) che dichiara una struttura
        // («CAP. 4 – Titolo», composta a taglia minore del corpo) si promuove a titolo del capitolo.
        if case let .run(.note, lines) = item, !lines.isEmpty {
            let text = joinLines(lines.map { $0.text })
            if let level = monoKeywordLevel(text), monoTitleShape(text) {
                out.append(.monoTitle(lines.count == 1 ? lines[0] : mergedLine(lines), keywordLevel: level))
                prevBottom = nil      // geometria fusa: stacco dopo il titolo ignoto
                unitBefore = true
                continue
            }
        }
        guard case let .run(.body, lines) = item, !lines.isEmpty else {
            out.append(item)
            // Dopo un run di righe vere (nota, glossa, apparato) la geometria regge; dopo un titolo fuso no.
            switch item {
            case .run(_, let ls), .apparatus(_, let ls): prevBottom = ls.last?.yBottom
            default: prevBottom = nil
            }
            unitBefore = true
            continue
        }
        let rows = monoRows(lines)
        // blocchi: righe a passo normale; un nuovo blocco a ogni stacco oltre la tolleranza
        var blocks: [(rows: [MonoRow], gapBefore: Double?)] = []
        for (i, r) in rows.enumerated() {
            let gap: Double?
            if i > 0 { gap = rows[i - 1].yBottom - r.yBottom - mono.pitch }
            else { gap = prevBottom.map { $0 - r.yBottom - mono.pitch } }
            if i == 0 || (gap ?? 0) > mono.tolerance {
                blocks.append(([r], gap))
            } else {
                blocks[blocks.count - 1].rows.append(r)
            }
        }
        let laterUnitOnPage = itemIndex + 1 < items.count
        var pending: [LineSummary] = []
        func flushBody() { if !pending.isEmpty { out.append(.run(.body, pending)); pending = [] } }
        func emitTitle(_ titleRows: [MonoRow]) {
            flushBody()
            let ls = titleRows.flatMap { $0.lines }
            out.append(.monoTitle(ls.count == 1 ? ls[0] : mergedLine(ls), keywordLevel: monoKeywordLevel(
                joinLines(ls.map { $0.text }))))
        }
        for (k, b) in blocks.enumerated() {
            let atTop = k == 0 && !unitBefore
            let nextBlockGap: Double? = k + 1 < blocks.count ? blocks[k + 1].gapBefore : nil
            let lastOnPage = k == blocks.count - 1 && !laterUnitOnPage
            // ── candidato titolo: isolato in alto ──
            var isolated = false
            if let g = b.gapBefore {
                isolated = g > mono.titleGap
            } else if atTop, pageIndex > 0, mono.pageCloses[pageIndex - 1] == true {
                if mono.blankLineMarksTitles {
                    isolated = (mono.pageShortBy[pageIndex - 1] ?? 0) >= 0.8 * mono.pitch
                } else {
                    // in cima alla pagina vale solo se lo segue il corpo (stacco di paragrafo), non un altro titolo
                    // (la riga d'autore sotto un capitolo); un blocco che DICHIARA una struttura (PARTE, CAP.,
                    // Sezione) vale anche se lo segue un altro titolo (parte e capitolo impilati)
                    isolated = (nextBlockGap.map { $0 <= mono.titleGap } ?? false)
                        || (b.rows.count <= MONO_TITLE_MAX_ROWS_PARAGRAPH
                            && monoKeywordLevel(joinLines(b.rows.map { $0.text })) != nil)
                }
            }
            if isolated {
                if mono.blankLineMarksTitles {
                    let (head, used) = pagesHead(b.rows)
                    // Dove una delle due prove è INDIRETTA — in cima alla pagina (la riga vuota non si misura: la si
                    // deduce dalla pagina prima più corta) o in fondo (la chiusura la dà la pagina dopo) — la testa
                    // deve anche finire CORTA: una testa che arriva al margine destro è l'inizio di un paragrafo che
                    // va a capo (la riga dopo ne continua la frase anche in maiuscola). Fa eccezione la testa che
                    // DICHIARA una struttura (CAP., PARTE, Sezione) o è tutta maiuscola: il corpo non comincia così.
                    // A metà pagina riga vuota sopra e riga che riparte sotto sono entrambe misurate: basta la forma.
                    let headEndsLikeTitle = monoRowIsShort(b.rows[used - 1], mono)
                        || monoKeywordLevel(head) != nil || allCapsLetters(head)
                    let closed: Bool
                    if used < b.rows.count {
                        // chiuso dalla riga seguente senza stacco
                        closed = startsWithUppercaseLetter(b.rows[used].text) && (!atTop || headEndsLikeTitle)
                    } else if k + 1 < blocks.count || laterUnitOnPage {
                        closed = true                                   // chiuso da uno stacco sulla pagina
                    } else {
                        // a fine pagina: la pagina dopo riparte in maiuscola
                        closed = (mono.pageFirstUpper[pageIndex + 1] ?? false) && headEndsLikeTitle
                    }
                    if closed, monoTitleShape(head) {
                        emitTitle(Array(b.rows[0..<used]))
                        pending.append(contentsOf: b.rows[used...].flatMap { $0.lines })
                        continue
                    }
                } else if b.rows.count <= MONO_TITLE_MAX_ROWS_PARAGRAPH {
                    let text = joinLines(b.rows.map { $0.text })
                    // chiuso in basso da un paragrafo che RIPARTE (maiuscola o cifra): se la frase continua
                    // in minuscola dopo lo stacco, il blocco non è un titolo (testo OCR incollato)
                    var closed = !lastOnPage
                    if k + 1 < blocks.count {
                        closed = paragraphRestarts(blocks[k + 1].rows[0].text)
                    }
                    if lastOnPage, let lastRow = b.rows.last {
                        // a fine pagina il paragrafo potrebbe continuare: chiuso solo se l'ultima riga è corta
                        // e la pagina dopo riparte in maiuscola
                        closed = monoRowIsShort(lastRow, mono) && (mono.pageFirstUpper[pageIndex + 1] ?? false)
                    }
                    if closed, monoTitleShape(text) {
                        emitTitle(b.rows)
                        continue
                    }
                }
            }
            // ── corpo: nuovo paragrafo dove l'editor marca lo stacco e la frase è chiusa ──
            if !pending.isEmpty, let g = b.gapBefore, g > mono.tolerance,
               paragraphBoundary(previous: joinLines(pending.map { $0.text }), next: b.rows[0].text) {
                flushBody()
            }
            pending.append(contentsOf: b.rows.flatMap { $0.lines })
        }
        flushBody()
        prevBottom = lines.last?.yBottom
        unitBefore = true
    }
    return out
}

/// Livello di un titolo monotipografico (vedi testata), risolto sui nodi già emessi.
func monoTitleLevel(keywordLevel: Int?, preceding: [NodeDict]) -> Int {
    if let k = keywordLevel { return k }
    for node in preceding.reversed() {
        let level: Int
        switch node.type {
        case .HEADING_1: level = 1
        case .HEADING_2: level = 2
        case .HEADING_3: level = 3
        case .HEADING_4: level = 4
        default: continue
        }
        if monoKeywordLevel(node.text ?? "") != nil { return min(4, level + 1) }
        return level
    }
    return 2
}

/// Il nodo HEADING di un titolo monotipografico, al livello risolto sui nodi già emessi.
func monoTitleNode(_ sm: LineSummary, keywordLevel: Int?, page: Int, preceding: [NodeDict], id: String) -> NodeDict {
    let level = monoTitleLevel(keywordLevel: keywordLevel, preceding: preceding)
    let type: SemanticCategory
    switch level {
    case 1: type = .HEADING_1
    case 2: type = .HEADING_2
    case 3: type = .HEADING_3
    default: type = .HEADING_4
    }
    return NodeDict(id: id, type: type, page_index: page, text: sm.text, level: level)
}
