//
//  NoteBinding.swift
//  ScaboCore
//
//  Aggancio richiamo↔nota e piazzamento delle note in Lettura Continua (§ 7.3 del
//  documento di prodotto). È il mattone centrale del capitolo NOTE: prende il
//  documento PIATTO del Generic (BODY/NOTE/HEADING in ordine di lettura fisico,
//  niente gerarchia, niente apparato) + l'estrazione PDFKit, e produce un
//  documento in cui ogni nota è LETTA al punto giusto invece che a fondo pagina.
//
//  ── Il segnale, verificato sulla pipeline PDFKit REALE (Fase 1b) ─────────────────
//
//  Il marcatore di richiamo in-corpo esiste in tre regimi tipografici distinti; su
//  PDFKit solo due sono recuperabili e vengono agganciati qui:
//    • REGIME SMALLER (Mosconi, Marotta, …): il numerino è uno span a dimensione
//      ridotta (≈0.55–0.65× il corpo). PDFKit espone la dimensione → rilevabile.
//    • REGIME PAREN (Mandrioli, DeJure, …): il marcatore è "(N)" a dimensione del
//      corpo dentro il testo. PDFKit dà il testo → rilevabile per regex.
//  Esclusi by design perché PDFKit non li distingue (lo dichiariamo, non lo
//  fingiamo — vedi docs/NOTES_BINDING.md):
//    • REGIME RAISED/FLAT (Marrone, Torrente): numerino a STESSA dimensione del
//      corpo, apice solo geometrico che PDFKit non riporta (yDelta=0). Le cifre
//      nude a dimensione-corpo NON si agganciano MAI (sarebbero anni, quantità,
//      numeri d'articolo): una nota agganciata male è peggio di una non agganciata.
//    • Note marginali senza richiamo numerico in-testo (Torrente): nessun segnale.
//
//  Le note non agganciate NON vengono perse: restano lette nella loro posizione
//  d'origine (fondo pagina), soltanto non spostate. Il metro `fedeltà-lettura` le
//  conta comunque come lette.
//
//  ── Cautele dell'aggancio (la nota sbagliata è peggio di nessuna nota) ───────────
//
//   1. SCOPE: l'abbinamento numero→nota è fatto DENTRO la pagina (la numerazione
//      può ripartire da pagina/capitolo: nel volume esistono molti "1","2"…). Si
//      lega solo se il numero ha UN'unica nota di quel valore nella pagina.
//   2. CROSS-PAGE: se la nota inizia sulla pagina successiva (richiamo a fondo p.5,
//      nota a p.6) si lega SOLO con guardia di successione: la nota deve essere la
//      PRIMA della pagina P+1 e il suo numero == (ultimo numero di P)+1. Senza
//      questo, una numerazione che riparte da 1 produrrebbe falsi.
//   3. AMBIGUITÀ: numero senza nota in scope, o più note dello stesso numero →
//      NON si lega (la nota resta in posizione, il richiamo resta muto).
//
//  ── Piazzamento (§ 7.3, testi discorsivi — l'unico applicabile al Generic) ───────
//
//  Nota BREVE (MICRO/SHORT): letta a fine FRASE del richiamo. Si spezza il nodo
//  BODY al confine di frase subito dopo il marcatore e si inserisce la nota lì.
//  Nota lunga (MEDIUM/LONG/VERY_LONG/MEGA): letta a fine SEZIONE (prima del
//  prossimo HEADING, o a fine documento). Il capitolo NON è luogo di piazzamento.
//  L'intro acustica (`acousticIntroFor`) è già cablata e si aggancia da sé via il
//  ruolo NOTE + length_category del nodo nota.
//
//  Confine onesto: questo modulo garantisce che i NUMERI tornino nell'unità giusta
//  e che nessuna nota sia agganciata fuori scope. La correttezza SEMANTICA ultima
//  ("questa nota letta qui è davvero quella giusta") dove i numeri tornano è quasi
//  sempre corretta, ma il collaudo a campione resta all'orecchio del maintainer.
//

import Foundation

// MARK: - Tipi

/// Regime tipografico del marcatore di richiamo (vedi testata).
enum MarkerRegime: Equatable { case smaller, paren }

/// Un marcatore di richiamo trovato nel testo di un nodo BODY.
struct InlineMarker: Equatable {
    let value: Int
    let regime: MarkerRegime
    /// Offset di CARATTERE (indice in `Array(text)`) nel testo del nodo BODY.
    let offset: Int
    /// Lunghezza in caratteri del token del marcatore nel testo del nodo.
    let length: Int
}

/// Una nota individuale estratta da un nodo NOTE (eventualmente fuso).
struct Footnote: Equatable {
    let openingNumber: Int?   // nil = continuazione cross-page (nessun marcatore d'apertura)
    let text: String
    let page: Int
    let lengthCategory: LengthCategory
}

/// Diagnostica per-volume del piazzamento, per il referto e i warning.
public struct NotePlacementStats: Codable, Equatable, Sendable {
    public var markersSmaller = 0
    public var markersParen = 0
    public var footnotes = 0
    public var boundSamePage = 0
    public var boundCrossPage = 0
    public var unboundMarkers = 0
    public var unboundNotes = 0
    public var placedShort = 0
    public var placedLong = 0
}

// MARK: - Costanti del segnale (calibrate in Fase 1b su PDFKit reale)

/// Il marcatore SMALLER è sotto questa frazione del corpo (Mosconi ≈0.58, Marotta
/// ≈0.64; PDFKit a volte riporta dimensioni degeneri ~0.06pt — sempre < soglia).
let MARKER_MAX_SIZE_RATIO = 0.75
/// Un numero di nota plausibile sta in 1–3 cifre (≤ 999). Esclude per costruzione
/// gli anni (4 cifre) e i numeri grandi: il pattern stesso fa da guardia.
private let RE_BARE_MARKER = try! NSRegularExpression(pattern: "^[0-9]{1,3}$")
private let RE_PAREN_MARKER = try! NSRegularExpression(pattern: "\\(([0-9]{1,3})\\)")
/// Apertura di una nota nel settore: numero (event. fra parentesi) a inizio riga,
/// seguito da separatore e contenuto (o fine riga, per l'apertura su riga propria).
private let RE_NOTE_OPENING =
    try! NSRegularExpression(pattern: "^[\\(\\[]?\\s?([0-9]{1,3})\\s?[\\)\\]]?[\\.\\)]?(\\s+\\S|$)")

private func fullMatch(_ re: NSRegularExpression, _ s: String) -> Bool {
    re.firstMatch(in: s, range: NSRange(s.startIndex..<s.endIndex, in: s)) != nil
}

// MARK: - Entry point

/// Aggancia e piazza le note del documento PIATTO del Generic. Ritorna il
/// documento trasformato (note spezzate dai nodi fusi e ricollocate al punto di
/// lettura corretto) + la diagnostica. Idempotente sull'assenza di note.
public func bindAndPlaceNotes(
    _ document: ScabopdfDocument,
    _ extraction: PdfExtraction
) -> (document: ScabopdfDocument, stats: NotePlacementStats) {
    var stats = NotePlacementStats()

    // Niente note → niente da fare (Patriarca, Tesauro, atti puri).
    guard document.structure.contains(where: { $0.type == .NOTE || $0.type == .EDITORIAL_NOTE }) else {
        return (document, stats)
    }

    let profile = estimateProfile(extraction)
    let furniture = detectFurniture(extraction)
    let body = profile.bodySize

    // ── 1. Zip per pagina: ogni nodo del documento ⇄ il suo item del Generic ──────
    // (stesso profilo/furniture/ordine → corrispondenza esatta 1:1 per pagina).
    let fmMax = frontMatterRegionLimit(extraction.pageCount)
    let apparatus = detectApparatus(extraction, furniture)
    var itemsByPage: [Int: [GenItem]] = [:]
    func items(_ page: Int) -> [GenItem] {
        if let cached = itemsByPage[page] { return cached }
        let pageExtraction = extraction.pages.first { $0.pageIndex == page }
        let derived = pageExtraction.map { pageItems($0, profile, furniture, fmMax, apparatus) } ?? []
        itemsByPage[page] = derived
        return derived
    }

    // Per nodo BODY: i marcatori in-corpo. Per nodo NOTE: le note spezzate.
    var markersByBodyId: [String: [InlineMarker]] = [:]
    var footnotesByNoteId: [String: [Footnote]] = [:]
    var cursorByPage: [Int: Int] = [:]
    for node in document.structure {
        let page = node.page_index
        let idx = cursorByPage[page, default: 0]
        cursorByPage[page] = idx + 1
        let pageItems = items(page)
        guard idx < pageItems.count else { continue }
        switch pageItems[idx] {
        case .run(.body, let lines):
            if node.type == .BODY {
                let m = detectInlineMarkers(lines, body: body)
                if !m.isEmpty { markersByBodyId[node.id] = m }
            }
        case .run(.note, let lines):
            if node.type == .NOTE {
                footnotesByNoteId[node.id] = splitFootnotes(lines, page: page)
            }
        case .run(.gloss, _):
            break  // le glosse laterali non sono note: niente aggancio (apparato note ripulito)
        case .apparatus:
            break  // apparato di front-matter: non è né corpo né nota
        case .heading:
            break
        }
    }

    // ── 2. Materializza le note spezzate come nodi sintetici (in posizione) ───────
    var footnoteNodeById: [String: NodeDict] = [:]
    var footnotesInNoteOrder: [String: [String]] = [:]   // noteId → [footnoteId in ordine]
    var footnoteIdsByPageNumber: [Int: [Int: [String]]] = [:]  // page → number → [footnoteId]
    var lastNumberOnPage: [Int: Int] = [:]
    for node in document.structure where node.type == .NOTE || node.type == .EDITORIAL_NOTE {
        let foots = footnotesByNoteId[node.id] ?? [
            // EDITORIAL_NOTE o NOTE senza item (difensivo): una nota sola, testo verbatim.
            Footnote(openingNumber: noteOpening(node.text ?? ""), text: node.text ?? "",
                     page: node.page_index, lengthCategory: node.length_category ?? .MICRO),
        ]
        var ids: [String] = []
        for (k, f) in foots.enumerated() {
            let fid = "\(node.id)_n\(k)"
            ids.append(fid)
            footnoteNodeById[fid] = NodeDict(
                id: fid, type: node.type, page_index: f.page, text: f.text,
                length_category: f.lengthCategory)
            stats.footnotes += 1
            if let num = f.openingNumber {
                footnoteIdsByPageNumber[f.page, default: [:]][num, default: []].append(fid)
                lastNumberOnPage[f.page] = max(lastNumberOnPage[f.page] ?? 0, num)
            }
        }
        footnotesInNoteOrder[node.id] = ids
    }

    // ── 3. Aggancio richiamo↔nota con scope e guardia di successione ──────────────
    var boundFootnoteIds: Set<String> = []
    var shortByBody: [String: [(offset: Int, length: Int, fid: String)]] = [:]
    var longByBody: [String: [String]] = [:]
    func isShort(_ fid: String) -> Bool {
        switch footnoteNodeById[fid]?.length_category {
        case .MICRO, .SHORT: return true
        default: return false
        }
    }
    for node in document.structure where node.type == .BODY {
        guard let markers = markersByBodyId[node.id] else { continue }
        let page = node.page_index
        for m in markers {
            var fid: String?
            // same-page: numero unico nella pagina
            if let ids = footnoteIdsByPageNumber[page]?[m.value], ids.count == 1 {
                fid = ids[0]; stats.boundSamePage += 1
            } else if footnoteIdsByPageNumber[page]?[m.value] == nil,
                      // cross-page guardato da successione: prima nota di P+1, num == ultimo(P)+1
                      let nextIds = footnoteIdsByPageNumber[page + 1]?[m.value], nextIds.count == 1,
                      m.value == (lastNumberOnPage[page] ?? -999) + 1 {
                fid = nextIds[0]; stats.boundCrossPage += 1
            }
            guard let bound = fid, !boundFootnoteIds.contains(bound) else {
                stats.unboundMarkers += 1
                continue
            }
            boundFootnoteIds.insert(bound)
            if isShort(bound) {
                shortByBody[node.id, default: []].append((m.offset, m.length, bound))
                stats.placedShort += 1
            } else {
                longByBody[node.id, default: []].append(bound)
                stats.placedLong += 1
            }
        }
    }

    // ── 4. Trasforma la struttura: spezza i BODY (note brevi), differisci le lunghe,
    //        lascia in posizione le non agganciate ────────────────────────────────
    var out: [NodeDict] = []
    var pendingLong: [NodeDict] = []
    func flushLong() {
        out.append(contentsOf: pendingLong)
        pendingLong = []
    }
    for node in document.structure {
        switch node.type {
        case .HEADING_1, .HEADING_2, .HEADING_3, .HEADING_4:
            flushLong()
            out.append(node)
        case .BODY:
            if let shorts = shortByBody[node.id], !shorts.isEmpty {
                out.append(contentsOf: splitBodyWithShortNotes(node, shorts, footnoteNodeById))
            } else {
                out.append(node)
            }
            if let longs = longByBody[node.id] {
                for fid in longs { if let n = footnoteNodeById[fid] { pendingLong.append(n) } }
            }
        case .NOTE, .EDITORIAL_NOTE:
            // I figli AGGANCIATI sono stati spostati; qui restano solo i NON agganciati,
            // in posizione d'origine (letti, non persi).
            for fid in footnotesInNoteOrder[node.id] ?? [] where !boundFootnoteIds.contains(fid) {
                if let n = footnoteNodeById[fid] {
                    out.append(n)
                    stats.unboundNotes += 1
                }
            }
        default:
            out.append(node)
        }
    }
    flushLong()

    stats.markersSmaller = markersByBodyId.values.flatMap { $0 }.filter { $0.regime == .smaller }.count
    stats.markersParen = markersByBodyId.values.flatMap { $0 }.filter { $0.regime == .paren }.count

    var placed = document
    placed.structure = out
    return (placed, stats)
}

// MARK: - Rilevamento marcatori in-corpo

/// Trova i marcatori di richiamo nelle righe di un run BODY, con offset di
/// CARATTERE nel testo del nodo (lo stesso che `joinLines` produrrebbe).
func detectInlineMarkers(_ lines: [LineSummary], body: Double) -> [InlineMarker] {
    guard body > 0 else { return [] }
    let lineStarts = joinedLineStarts(lines)
    var markers: [InlineMarker] = []
    for (li, line) in lines.enumerated() {
        let start = lineStarts[li]
        if start < 0 { continue }
        let hasBody = line.spans.contains {
            abs($0.fontSize - body) <= 0.6 && !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard hasBody else { continue }
        let spanStarts = spanCharStarts(line)
        for (si, span) in line.spans.enumerated() {
            guard let spanStart = spanStarts[si] else { continue }
            // REGIME SMALLER: span a dimensione ridotta, testo = numero nudo 1–3 cifre.
            let t = span.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if span.fontSize > 0, span.fontSize < MARKER_MAX_SIZE_RATIO * body,
               fullMatch(RE_BARE_MARKER, t), let v = Int(t) {
                // offset del token: lo span inizia a spanStart; il numero è il testo
                // trimmato → salta la sola whitespace iniziale dello span.
                let lead = span.text.prefix { $0.isWhitespace }.count
                markers.append(InlineMarker(
                    value: v, regime: .smaller, offset: start + spanStart + lead, length: t.count))
            }
            // REGIME PAREN: "(N)" dentro uno span a dimensione del corpo.
            if abs(span.fontSize - body) <= 0.6 {
                let nsText = span.text as NSString
                for match in RE_PAREN_MARKER.matches(
                    in: span.text, range: NSRange(location: 0, length: nsText.length)) {
                    let parenStr = nsText.substring(with: match.range)        // "(N)"
                    let numStr = nsText.substring(with: match.range(at: 1))   // "N"
                    guard let v = Int(numStr) else { continue }
                    // offset di carattere del "(" entro lo span (NSRange è UTF-16):
                    let utf16Pre = match.range.location
                    let charPre = charCount(ofUTF16Prefix: utf16Pre, in: span.text)
                    markers.append(InlineMarker(
                        value: v, regime: .paren, offset: start + spanStart + charPre,
                        length: parenStr.count))
                }
            }
        }
    }
    return markers
}

/// Numero di CARATTERI corrispondenti ai primi `utf16Prefix` code unit UTF-16.
private func charCount(ofUTF16Prefix utf16Prefix: Int, in s: String) -> Int {
    guard utf16Prefix > 0 else { return 0 }
    let idx = s.utf16.index(s.utf16.startIndex, offsetBy: utf16Prefix, limitedBy: s.utf16.endIndex)
        ?? s.utf16.endIndex
    return s.distance(from: s.startIndex, to: idx.samePosition(in: s) ?? s.endIndex)
}

// MARK: - Geometria del testo unito (offset coerenti con joinLines)

/// Offset di carattere a cui inizia, nel testo unito (`joinLines`), il testo di
/// ciascuna riga; -1 per le righe vuote (saltate da joinLines). Replica la logica
/// di `joinLines` (trim per riga, de-sillabazione col trattino, " " fra righe) in
/// spazio CARATTERE per allinearsi a `sentenceBoundaryOffsets`.
func joinedLineStarts(_ lines: [LineSummary]) -> [Int] {
    var out: [Character] = []
    var starts: [Int] = []
    for line in lines {
        let trimmed = jsTrim(line.text)
        if trimmed.isEmpty { starts.append(-1); continue }
        let lineChars = Array(trimmed)
        if out.isEmpty {
            starts.append(0)
            out = lineChars
        } else if endsWithLetterHyphenChars(out) {
            out.removeLast()
            starts.append(out.count)
            out += lineChars
        } else {
            out.append(" ")
            starts.append(out.count)
            out += lineChars
        }
    }
    return starts
}

/// Offset di carattere d'inizio di ciascuno span nel testo (trimmato) della riga;
/// nil per uno span interamente dentro la whitespace iniziale. `summarizeLine`
/// pone `text = jsTrim(concat degli span)`, quindi si sottrae la sola whitespace
/// iniziale del concatenamento.
func spanCharStarts(_ line: LineSummary) -> [Int?] {
    var startsInConcat: [Int] = []
    var acc = 0
    for span in line.spans {
        startsInConcat.append(acc)
        acc += span.text.count
    }
    let concat = line.spans.map { $0.text }.joined()
    let leading = concat.prefix { $0.isWhitespace }.count
    return startsInConcat.map { $0 - leading >= 0 ? $0 - leading : nil }
}

/// Come `endsWithLetterHyphen` ma su un array di Character (per joinedLineStarts).
private func endsWithLetterHyphenChars(_ chars: [Character]) -> Bool {
    guard chars.count >= 2, chars[chars.count - 1] == "-" else { return false }
    let prev = chars[chars.count - 2]
    for scalar in prev.unicodeScalars {
        let v = scalar.value
        if (v >= 0x41 && v <= 0x5A) || (v >= 0x61 && v <= 0x7A) || (v >= 0xC0 && v <= 0xFF) {
            return true
        }
    }
    return false
}

// MARK: - Spezzettamento delle note fuse

/// Spezza un run NOTE (più note a piè di pagina fuse dal Generic) nelle singole
/// note, riconoscendo l'apertura per il numero a inizio riga. Una testa senza
/// marcatore è una continuazione cross-page (openingNumber nil).
func splitFootnotes(_ lines: [LineSummary], page: Int) -> [Footnote] {
    var result: [Footnote] = []
    var current: [LineSummary] = []
    var currentOpening: Int?

    func flush() {
        guard !current.isEmpty else { return }
        let text = joinLines(current.map { $0.text })
        if !text.isEmpty {
            result.append(Footnote(
                openingNumber: currentOpening, text: text, page: page,
                lengthCategory: lengthCategoryFor(text)))
        }
        current = []
        currentOpening = nil
    }

    for line in lines {
        if let n = noteOpening(line.text) {
            flush()
            current = [line]
            currentOpening = n
        } else {
            current.append(line)
        }
    }
    flush()
    return result
}

/// Numero d'apertura di una nota se la riga inizia con un marcatore, else nil.
func noteOpening(_ text: String) -> Int? {
    let t = jsTrim(text)
    let ns = t as NSString
    guard let m = RE_NOTE_OPENING.firstMatch(in: t, range: NSRange(location: 0, length: ns.length)),
          m.range(at: 1).location != NSNotFound else { return nil }
    return Int(ns.substring(with: m.range(at: 1)))
}

// MARK: - Piazzamento delle note brevi (split del BODY a fine frase)

/// Spezza il nodo BODY ai confini di frase subito dopo ciascun marcatore breve e
/// interleava le note. I pezzi di corpo ereditano un id sintetico stabile; le note
/// sono i nodi sintetici già materializzati. Restituisce la sequenza in ordine.
func splitBodyWithShortNotes(
    _ node: NodeDict,
    _ shorts: [(offset: Int, length: Int, fid: String)],
    _ footnoteNodeById: [String: NodeDict]
) -> [NodeDict] {
    let text = node.text ?? ""
    let chars = Array(text)
    let bounds = sentenceBoundaryOffsets(text)
    let ordered = shorts.sorted { $0.offset < $1.offset }
    var pieces: [NodeDict] = []
    var cursor = 0
    var pieceIndex = 0
    func emitPiece(_ end: Int) {
        guard end > cursor else { return }
        let slice = String(chars[cursor..<min(end, chars.count)])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !slice.isEmpty {
            pieces.append(NodeDict(
                id: "\(node.id)_b\(pieceIndex)", type: .BODY,
                page_index: node.page_index, text: slice))
            pieceIndex += 1
        }
        cursor = min(end, chars.count)
    }
    for s in ordered {
        let markerEnd = min(s.offset + s.length, chars.count)
        // fine della frase che contiene il richiamo = primo confine ≥ fine marcatore.
        let end = bounds.first { $0 >= markerEnd } ?? chars.count
        emitPiece(end)
        if let note = footnoteNodeById[s.fid] { pieces.append(note) }
    }
    emitPiece(chars.count)
    // Se per qualunque ragione non si è prodotto nulla, conserva il nodo originale.
    return pieces.isEmpty ? [node] : pieces
}
