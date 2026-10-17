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
    /// Agganci per SCOPE D'ARTICOLO (solo DeJure dottrina: note d'endnote a numerazione
    /// per-articolo, lontane dal richiamo → lo scope per-pagina non le raggiunge).
    public var boundArticleScope = 0
    public var unboundMarkers = 0
    public var unboundNotes = 0
    public var placedShort = 0
    public var placedLong = 0
    /// Footnote-continuazione cross-pagina ricucite nella testa (GATED Estratto).
    public var stitchedCrossPage = 0
    /// Note ricucite fra pagine CONTIGUE fuori dall'Estratto (giro «cura delle note», 2026-10-16): la prima nota della
    /// pagina B fusa nell'ultima della pagina A. Vedi `stitchAdjacentPageFootnotes`.
    public var stitchedAdjacentPage = 0
    /// Il vaglio di ogni coppia candidata alla ricucitura fra pagine contigue, PRIVO DI TESTO (pagine, identificativi,
    /// misure, verdetto): per le reti e il giudizio contro la pagina stampata. Non viaggia nella lettura.
    public var adjacentPageCandidates: [AdjacentPageStitchCandidate] = []
}

/// Il vaglio di una coppia «ultima nota della pagina A, prima nota della pagina B = A + 1» per la ricucitura fra pagine
/// contigue (`stitchAdjacentPageFootnotes`). Privo di testo: solo pagine, identificativi, misure e verdetto.
public struct AdjacentPageStitchCandidate: Codable, Equatable, Sendable {
    /// Pagina (indice 0) dove sta la testa, cioè la parte della nota sulla pagina A, e pagina della coda (A + 1).
    public var headPage: Int
    public var tailPage: Int
    /// Identificativi della nota-testa (la nota che resta, eventualmente già cresciuta in una catena) e della coda.
    public var headId: String
    public var tailId: String
    /// Il predicato di ricucitura dell'app (`noteTailContinuesHead`): la testa resta aperta, la coda la continua.
    public var predicate: Bool
    /// Successione dei numeri sulla pagina B: «confermata» (la prima nota numerata dopo la coda ha il numero della testa
    /// più uno), «non confermata» (ne ha un altro), «assente» (nessuna nota numerata dopo la coda sulla pagina B),
    /// «testa senza numero».
    public var succession: String
    /// Numero della testa e della prima nota numerata dopo la coda sulla pagina B (nil se assenti).
    public var headNumber: Int?
    public var nextNumber: Int?
    /// Il numero in testa alla coda torna nella successione (testa + 1): la coda è una nota nuova.
    public var tailLeadingIsNext: Bool
    /// Nel corpo della pagina A o B c'è un richiamo col numero della testa più uno, ma nessuna nota con quel numero
    /// sulle pagine A, B e B + 1: la coda potrebbe essere la nota seguente col marcatore perso (secondo gradino).
    public var nextCallUnmatched: Bool = false
    /// Geometria (punti, origine in basso a sinistra): bordo superiore della prima riga della coda e fondo del contenuto
    /// non-nota (corpo, titoli) della pagina B; lo stesso per il nodo dell'ultima nota della pagina A.
    public var tailTop: Double?
    public var tailPageContentBottom: Double?
    public var headTop: Double?
    public var headPageContentBottom: Double?
    /// Corpo (punti) della prima riga della coda e dell'ultima riga della testa: il corpo MASSIMO dei suoi span con testo
    /// (`noteLineMaxSpanSize`), che non risente del maiuscoletto né dei richiami in apice.
    public var tailSize: Double?
    public var headSize: Double?
    /// Bordi sinistro e destro della prima riga della coda e dell'ultima riga della testa.
    public var tailX0: Double?
    public var tailX1: Double?
    public var headX0: Double?
    public var headX1: Double?
    /// Tipo dei due nodi (NOTE o EDITORIAL_NOTE).
    public var headNodeType: String
    public var tailNodeType: String
    /// Verdetto e, se respinta, la prima guardia che l'ha fermata.
    public var stitched: Bool
    public var reason: String
    /// Testa-frammento ricomposta (giro «pulizia delle note», 2026-10-17): l'id del frammento, sovra-spezzato
    /// dall'estrazione a un numero spurio, che è stato riunito alla nota vera che lo precede prima della ricucitura.
    public var recomposedFragmentId: String? = nil
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

// MARK: - Modo di piazzamento (per layout)

/// Come le note AGGANCIATE vengono piazzate nel flusso.
///   • `.continuous` — Lettura Continua (§ 7.3): brevi a fine frase del richiamo, lunghe
///     differite a fine sezione (col rinfresco di contesto § 7.4/§ 7.5). È il default e l'unico
///     comportamento storico: invariato byte-per-byte.
///   • `.doctrineInline` — Dottrina Inline (§ 10.2): OGNI nota, qualunque sia la lunghezza, è
///     letta a fine frase del richiamo. Niente differimento a fine sezione, niente rinfresco
///     (§ 10.5). Riusa l'aggancio e lo split esistenti; cambia solo la scelta inline-vs-differito.
public enum NotePlacement: Equatable, Sendable { case continuous, doctrineInline }

// MARK: - Entry point

/// Aggancia e piazza le note del documento PIATTO del Generic. Ritorna il
/// documento trasformato (note spezzate dai nodi fusi e ricollocate al punto di
/// lettura corretto) + la diagnostica. Idempotente sull'assenza di note.
///
/// `placement` sceglie il layout di piazzamento (default `.continuous`, storico invariato).
public func bindAndPlaceNotes(
    _ document: ScabopdfDocument,
    _ extraction: PdfExtraction,
    placement: NotePlacement = .continuous
) -> (document: ScabopdfDocument, stats: NotePlacementStats) {
    var stats = NotePlacementStats()

    // Niente note → niente da fare (Patriarca, Tesauro, atti puri).
    guard document.structure.contains(where: { $0.type == .NOTE || $0.type == .EDITORIAL_NOTE }) else {
        return (document, stats)
    }

    // DeJure dottrina: le note recuperate sono ENDNOTE a numerazione PER-ARTICOLO (lontane dal
    // richiamo), quindi lo scope per-pagina non le aggancia. Si abilita un fallback di aggancio per
    // SCOPE D'ARTICOLO (delimitato dai banner "DOTTRINA" = ARTIFACT_STAMP), GATED su DeJure: il
    // percorso generico resta byte-identico per ogni altro volume. `articleOf[id]` = indice
    // d'articolo del nodo (numeri unici dentro l'articolo → aggancio sicuro su match unico).
    let dejure = document.warnings.contains { $0.hasPrefix("plugin:dejure:") }
    var articleOf: [String: Int] = [:]
    if dejure {
        var art = 0
        for node in document.structure {
            if node.type == .ARTIFACT_STAMP,
               (node.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines) == "DOTTRINA" {
                art += 1
            }
            articleOf[node.id] = art
        }
    }
    var footnoteIdsByArticle: [Int: [Int: [String]]] = [:]

    let profile = estimateProfile(extraction)
    // De-interfoliazione delle due colonne dei codici: DEVE combaciare con
    // quella applicata da CodiciPlugin.build, così lo zip nodi↔pageItems e
    // l'estrazione delle note (splitFootnotes) vedono lo stesso ordine. Pura,
    // idempotente, gated isCodici → byte-identica ovunque il flag sia falso.
    let extraction = profile.isCodici ? deinterleaveCodiciColumns(extraction) : extraction
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

    // Per nodo BODY: i marcatori in-corpo. Per nodo NOTE: le note spezzate (e le righe, per la geometria della
    // ricucitura fra pagine contigue, sotto).
    var markersByBodyId: [String: [InlineMarker]] = [:]
    var footnotesByNoteId: [String: [Footnote]] = [:]
    var noteLinesById: [String: [LineSummary]] = [:]
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
                noteLinesById[node.id] = lines
            }
        case .run(.gloss, _):
            break  // le glosse laterali non sono note: niente aggancio (apparato note ripulito)
        case .apparatus:
            break  // apparato di front-matter: non è né corpo né nota
        case .heading, .numberedTitle, .monoTitle:
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
                // Indice per articolo (solo DeJure): nota → articolo del NODO-nota di provenienza.
                if dejure, let art = articleOf[node.id] {
                    footnoteIdsByArticle[art, default: [:]][num, default: []].append(fid)
                }
            }
        }
        footnotesInNoteOrder[node.id] = ids
    }

    // L'elenco delle note individuali PRIMA delle ricuciture dell'aggancio: serve all'ordine d'origine (2c).
    let originalFootnotesInNoteOrder = footnotesInNoteOrder

    // ── 2b. RICUCITURA cross-pagina per identità (GATED Estratto) ─────────────────
    // Una nota spezzata dal salto pagina riaffiora come due footnote: la testa (ultima di
    // pag N, col suo numero, finisce "aperta") e la coda (prima di N+1, SENZA numero
    // d'apertura → non agganciabile → falso-"Nota."). Qui, PRIMA del piazzamento, si fonde
    // la coda nella testa quando la testa APRE e la coda CONTINUA (guardie condivise
    // noteOpensForContinuation/noteContinuation: una nota NUOVA apre col suo numero →
    // noteContinuation la ESCLUDE → due note distinte non si fondono MAI). Nel flatten in
    // ordine di lettura testa e coda sono adiacenti (il corpo è saltato), quindi lo zip
    // pageItems↔structure dello step 1 NON è toccato. Confinata: altrove byte-identico.
    if profile.isEstrattoChrome {
        stats.stitchedCrossPage = stitchCrossPageFootnotes(
            document.structure, &footnoteNodeById, &footnotesInNoteOrder)
    } else {
        // ── 2b-bis. Salvataggio SAME-PAGE per tutte le famiglie (2026-08-12) ──────
        // L'over-split di `splitFootnotes` su un numero spurio a inizio riga (un
        // riferimento di pagina «cit., p. | 137 sgg.», il rinvio normativo
        // «…dall'art. | 11 lett. c) l. …» delle note di aggiornamento dei codici)
        // produce una falsa nota numerata annunciata «Nota.». Il rimedio è la
        // stessa ricucitura-per-identità dell'Estratto, RISTRETTA alla stessa
        // pagina (niente cross-pagina: resta materia del capitolo NOTE/ultrafocus)
        // e con la GUARDIA DI SUCCESSIONE in più: una coda il cui numero "torna"
        // nella successione delle note (testa+1, o seguita dal proprio successore)
        // è una nota VERA che apre con numero+minuscola («39 van den Aardweg…» su
        // Rivista DPC) e non si fonde MAI. Il gate storico all'Estratto era
        // confinamento prudenziale senza misura (commit 2bd48b1: «altrove no-op»);
        // la misura è la rete di delta a 40 volumi di questo giro.
        // DUE restrizioni in più rispetto all'Estratto, entrambe nate dalla rete
        // di delta a 40 volumi: (a) si ricuce SOLO DENTRO LO STESSO nodo-run —
        // l'over-split è un artefatto di `splitFootnotes` dentro un run, e il
        // flatten cross-nodo accoppia colonne interfogliate fabbricando frasi
        // (LETTERATURA a due colonne dell'EdD); (b) i CODICI restano esclusi —
        // il loro apparato note a due colonne interfoglia le righe già dentro
        // l'estrazione e ogni ricucitura per identità vi fabbrica parole
        // («magdificato»): la causa vera è l'interfoliazione, materia del
        // plugin codici/officina (ULTRAFOCUS_INBOX), non di una pezza qui.
        if !profile.isCodici {
            stats.stitchedCrossPage = stitchCrossPageFootnotes(
                document.structure, &footnoteNodeById, &footnotesInNoteOrder,
                allowCrossPage: false, withinNodeOnly: true)
            // ── 2b-ter. Ricucitura fra pagine CONTIGUE (giro «cura delle note», 2026-10-16) ───────────────
            // Dopo il salvataggio same-page, che resta identico: l'ultima nota della pagina A e la prima della
            // pagina A + 1, con le guardie di `stitchAdjacentPageFootnotes`. Codici esclusi (sopra), Estratto col
            // suo percorso storico (sopra, invariato).
            var contentBottomByPage: [Int: Double] = [:]
            var bodyLeftByPage: [Int: Double] = [:]
            for page in Set(document.structure.filter { $0.type == .NOTE }.map { $0.page_index }) {
                contentBottomByPage[page] = nonNoteContentBottom(items(page))
                bodyLeftByPage[page] = bodyLeftMargin(items(page))
            }
            // Richiami nel corpo, per pagina (secondo gradino: un richiamo «testa + 1» senza la sua nota).
            var callValuesByPage: [Int: Set<Int>] = [:]
            for node in document.structure where node.type == .BODY {
                for m in markersByBodyId[node.id] ?? [] { callValuesByPage[node.page_index, default: []].insert(m.value) }
            }
            let noteNumbersByPage = footnoteIdsByPageNumber.mapValues { Set($0.keys) }
            let adjacent = stitchAdjacentPageFootnotes(
                document.structure, &footnoteNodeById, &footnotesInNoteOrder,
                noteLinesById: noteLinesById, contentBottomByPage: contentBottomByPage,
                callValuesByPage: callValuesByPage, noteNumbersByPage: noteNumbersByPage, bodyLeftByPage: bodyLeftByPage)
            stats.stitchedAdjacentPage = adjacent.count
            stats.adjacentPageCandidates = adjacent.candidates
        }
    }

    // ── 2c. Ordine d'origine delle note individuali (giro «pulizia delle note», 2026-10-17) ─────────────────────────
    // Ogni nota individuale porta l'id della nota che la precede SUBITO nel documento d'origine (o il vuoto, se subito
    // prima c'è altro): la ricucitura nel flusso, dopo il piazzamento, unisce due pezzi di nota solo se l'uno segue così
    // l'altro (`mergeNoteContinuations`). Non cambia né i testi né l'ordine: è un'annotazione interna.
    annotateNoteOriginPrevious(document.structure, original: originalFootnotesInNoteOrder,
                               surviving: footnotesInNoteOrder, &footnoteNodeById)

    // ── 3. Aggancio richiamo↔nota con scope e guardia di successione ──────────────
    var boundFootnoteIds: Set<String> = []
    var shortByBody: [String: [(offset: Int, length: Int, fid: String)]] = [:]
    var longByBody: [String: [String]] = [:]
    // Rinfresco di contesto (§ 7.4/§ 7.5) per le note DIFFERITE (lunghe): la "frase
    // del richiamo" calcolata dal testo del BODY attorno al marcatore. Le brevi
    // (MICRO/SHORT, lette a fine frase) non hanno rinfresco (§ 7.4).
    var refreshByFootnoteId: [String: String] = [:]
    func isShort(_ fid: String) -> Bool {
        switch footnoteNodeById[fid]?.length_category {
        case .MICRO, .SHORT: return true
        default: return false
        }
    }
    // La testa di una parola spezzata alla fine del BODY precedente, per il BODY che si apre con la sua coda (lo stesso
    // paragrafo oltre il salto pagina; in mezzo solo apparato): serve al rinfresco, perché cominci a inizio parola (giro
    // «pulizia e rifinitura finale del capitolo note», 2026-10-17: 217 rinfreschi su 9.025 cominciavano a metà parola).
    var brokenWordHeadByBodyId: [String: String] = [:]
    var previousBodyText: String?
    for node in document.structure {
        switch node.type {
        case .BODY:
            let text = node.text ?? ""
            if let prev = previousBodyText.map(jsTrim), endsWithLetterHyphenG(prev),
               let first = jsTrim(text).first, first.isLowercase {
                let head = String(prev.dropLast().reversed().prefix(while: { $0.isLetter }).reversed())
                if !head.isEmpty { brokenWordHeadByBodyId[node.id] = head }
            }
            previousBodyText = text
        case .NOTE, .EDITORIAL_NOTE, .MARGINAL_GLOSS, .MARGINAL_HEADING:
            break   // l'apparato e le glosse a margine fra le due metà del paragrafo (il flusso le ricongiunge)
        default:
            previousBodyText = nil
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
            } else if dejure, let art = articleOf[node.id],
                      // SCOPE D'ARTICOLO (solo DeJure): endnote a numerazione per-articolo. Si
                      // aggancia SOLO su match UNICO nello stesso articolo del richiamo (i numeri
                      // sono unici dentro l'articolo → niente cross-bind, precisione mantenuta).
                      let ids = footnoteIdsByArticle[art]?[m.value], ids.count == 1 {
                fid = ids[0]; stats.boundArticleScope += 1
            }
            guard let bound = fid, !boundFootnoteIds.contains(bound) else {
                stats.unboundMarkers += 1
                continue
            }
            boundFootnoteIds.insert(bound)
            // Dottrina Inline (§ 10.2): TUTTE le note inline a fine frase, a prescindere dalla
            // lunghezza. Lettura Continua: solo le brevi inline, le lunghe differite (§ 7.3).
            let inline = isShort(bound) || placement == .doctrineInline
            if inline {
                shortByBody[node.id, default: []].append((m.offset, m.length, bound))
                stats.placedShort += 1
            } else {
                longByBody[node.id, default: []].append(bound)
                stats.placedLong += 1
                // Nota differita: calcola QUI il rinfresco (servono testo del BODY del
                // richiamo + offset del marcatore, entrambi disponibili solo ora). In Dottrina
                // Inline questo ramo non è MAI raggiunto → nessun rinfresco (§ 10.5).
                let refresh = memoryRefreshSegment(node.text ?? "", markerOffset: m.offset,
                                                   brokenWordHead: brokenWordHeadByBodyId[node.id] ?? "")
                if !refresh.isEmpty { refreshByFootnoteId[bound] = refresh }
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
        case .HEADING_1, .HEADING_2, .HEADING_3, .HEADING_4, .ARTICLE_HEADER:
            // ARTICLE_HEADER è l'intestazione d'articolo dei codici (ex HEADING_4): resta un
            // CONFINE di sezione per il piazzamento delle note lunghe, identico a prima del
            // cambio di categoria → Lettura Continua invariata. Altrove non esiste (no-op).
            flushLong()
            out.append(node)
        case .BODY:
            if let shorts = shortByBody[node.id], !shorts.isEmpty {
                out.append(contentsOf: splitBodyWithShortNotes(node, shorts, footnoteNodeById))
            } else {
                out.append(node)
            }
            if let longs = longByBody[node.id] {
                for fid in longs {
                    if var n = footnoteNodeById[fid] {
                        // Annota il rinfresco (§ 7.4/§ 7.5) sul nodo nota differito.
                        n.memoryRefresh = refreshByFootnoteId[fid]
                        pendingLong.append(n)
                    }
                }
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

/// L'ORDINE D'ORIGINE delle note individuali, per la ricucitura nel flusso (giro «pulizia e rifinitura finale del capitolo
/// note», 2026-10-17; decisione 3 del maintainer, LAYER2 § 12.12). La ricucitura nel flusso (`mergeNoteContinuations`)
/// lavora DOPO il piazzamento: una nota agganciata è stata spostata al suo richiamo, e la nota che la seguiva nella pagina
/// può trovarsi accanto a un'ALTRA nota (o a un frammento) e venirvi incollata. Misurato sui 52 volumi (build 56): 21
/// fusioni così in Lettura Continua e 3 in Dottrina Inline (frammenti dei codici incollati a note di altre colonne,
/// righe di tabella, note che si aprono con una citazione incollate a titoli), più 27 unioni nei codici che saltavano
/// una riga dell'apparato letta come corpo (due parole fabbricate) e 5 glosse a margine incollate a una nota.
/// Qui ogni nota individuale sopravvissuta alle ricuciture dell'aggancio riceve l'id della nota che la precede SUBITO
/// nella sequenza d'origine — i nodi della struttura in ordine, ogni nodo di note esploso nelle sue note individuali
/// d'origine —, oppure il vuoto se subito prima c'è altro (corpo, titolo, glossa, una nota senza testo) o niente. Una
/// nota assorbita da una ricucitura dell'aggancio conta come la nota che l'ha assorbita: le tre ricuciture dell'aggancio
/// uniscono sempre una nota alla nota sopravvissuta che la precede nel loro ordine, che è questo.
func annotateNoteOriginPrevious(
    _ structure: [NodeDict],
    original: [String: [String]],
    surviving: [String: [String]],
    _ footnoteNodeById: inout [String: NodeDict]
) {
    let alive = Set(surviving.values.flatMap { $0 })
    var owner: [String: String] = [:]
    var lastAlive: String?
    for node in structure where node.type == .NOTE || node.type == .EDITORIAL_NOTE {
        for fid in original[node.id] ?? [] {
            if alive.contains(fid) { lastAlive = fid } else if let o = lastAlive { owner[fid] = o }
        }
    }
    var previous = ""
    for node in structure {
        guard node.type == .NOTE || node.type == .EDITORIAL_NOTE else { previous = ""; continue }
        let fids = original[node.id] ?? []
        if fids.isEmpty { previous = ""; continue }
        for fid in fids {
            if alive.contains(fid) {
                footnoteNodeById[fid]?.noteOriginPrevious = previous
                previous = fid
            } else {
                previous = owner[fid] ?? ""
            }
        }
    }
}

/// Ricucitura-per-identità delle note spezzate dal salto pagina, a livello FOOTNOTE e
/// PRIMA del piazzamento (chiamata gated da `bindAndPlaceNotes` solo per l'Estratto).
/// Appiattisce le footnote in ordine di lettura (le NOTE di `structure` saltano il corpo,
/// quindi la testa di pag N e la coda di pag N+1 sono ADIACENTI nel flatten) e fonde la
/// coda nella testa quando: pagine consecutive (N → N+1), la testa APRE
/// (`noteOpensForContinuation`) e la coda CONTINUA (`noteContinuation` — esclude i marcatori
/// di nota, così due note distinte non si fondono MAI). De-sillaba la parola spezzata
/// ("pub-"|"blicistica" → "pubblicistica") e ricomputa `length_category` (la testa cresce).
/// Gestisce catene (nota su 3+ pagine) tramite `tailPage`. Ritorna il numero di code fuse.
/// Primo numero intero (max 4 cifre) all'inizio del testo, o nil. Per la
/// guardia di successione del salvataggio same-page.
private func leadingInt(_ s: String) -> Int? {
    var digits = ""
    for ch in jsTrim(s) {
        if ch.isNumber, digits.count < 4 { digits.append(ch) } else { break }
    }
    return digits.isEmpty ? nil : Int(digits)
}

func stitchCrossPageFootnotes(
    _ structure: [NodeDict],
    _ footnoteNodeById: inout [String: NodeDict],
    _ footnotesInNoteOrder: inout [String: [String]],
    allowCrossPage: Bool = true,
    withinNodeOnly: Bool = false
) -> Int {
    // `withinNodeOnly` (salvataggio same-page non-Estratto): la catena di
    // fusione non attraversa mai il confine fra nodi-run — un marcatore vuoto
    // separa i gruppi nel flatten, così testa e coda di nodi diversi non sono
    // mai adiacenti. L'Estratto (false) conserva il flatten storico integrale.
    var flat: [String] = []
    for node in structure where node.type == .NOTE || node.type == .EDITORIAL_NOTE {
        let ids = footnotesInNoteOrder[node.id] ?? []
        if withinNodeOnly, !flat.isEmpty, !ids.isEmpty { flat.append("") }
        flat.append(contentsOf: ids)
    }
    guard flat.count >= 2 else { return 0 }

    var removed = Set<String>()
    var headFid = flat[0]
    var tailPage = footnoteNodeById[headFid]?.page_index ?? Int.min
    var count = 0
    for i in 1..<flat.count {
        let fid = flat[i]
        if fid.isEmpty {
            // Confine di nodo-run (withinNodeOnly): la testa corrente non può
            // assorbire nulla oltre il confine.
            headFid = ""
            continue
        }
        guard !headFid.isEmpty else {
            headFid = fid
            tailPage = footnoteNodeById[fid]?.page_index ?? Int.min
            continue
        }
        guard let cur = footnoteNodeById[fid], let head = footnoteNodeById[headFid] else { continue }
        let a = (head.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let b = (cur.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        // Cross-pagina (N → N+1) e SAME-PAGE (over-split di `splitFootnotes` su un numero
        // spurio nel testo della nota, es. "…cordi 69" | "le norme…"): in entrambi i casi la
        // testa deve APRIRE e la coda CONTINUARE (guardie invariate, anti-fusione: una nota
        // NUOVA apre col suo numero → `noteContinuation` la esclude → mai fuse due note distinte).
        let pageOk = cur.page_index == tailPage
            || (allowCrossPage && cur.page_index == tailPage + 1)
        // Guardia di successione (solo percorso non-Estratto, `allowCrossPage`
        // false): se il numero in testa alla coda combacia con testa+1, o il
        // footnote SEGUENTE combacia con coda+1, la coda è una nota vera in
        // successione → mai fusa. (L'Estratto conserva il comportamento
        // calibrato e verificato del commit 2bd48b1, byte-identico.)
        var successionSaysNewNote = false
        if !allowCrossPage, let codaN = leadingInt(b) {
            if let headN = noteOpening(a), codaN == headN + 1 {
                successionSaysNewNote = true
            }
            if i + 1 < flat.count, let nxt = footnoteNodeById[flat[i + 1]],
               let nextN = leadingInt(nxt.text ?? ""), nextN == codaN + 1 {
                successionSaysNewNote = true
            }
        }
        if pageOk, !successionSaysNewNote,
           noteTailContinuesHead(head: a, tail: b) {
            let merged: String
            if endsWithLetterHyphenG(a), let f = b.first, f.isLowercase {
                merged = String(a.dropLast()) + b           // de-sillabazione
            } else {
                merged = a + " " + b
            }
            var h = head
            h.text = merged
            h.length_category = lengthCategoryFor(merged)
            footnoteNodeById[headFid] = h
            removed.insert(fid)
            tailPage = cur.page_index                        // catena: la testa copre fino a qui
            count += 1
        } else {
            headFid = fid
            tailPage = cur.page_index
        }
    }
    if !removed.isEmpty {
        for (k, v) in footnotesInNoteOrder {
            footnotesInNoteOrder[k] = v.filter { !removed.contains($0) }
        }
    }
    return count
}

// MARK: - Ricucitura fra pagine contigue (giro «cura delle note», 2026-10-16)

/// Fondo (y minima, origine in basso a sinistra) del contenuto che nota non è — corpo e titoli — fra gli elementi di una
/// pagina; nil se la pagina non ne ha. Le glosse laterali e l'apparato di pagina intera non contano.
func nonNoteContentBottom(_ items: [GenItem]) -> Double? {
    var bottom: Double?
    func take(_ sm: LineSummary) {
        guard !sm.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        bottom = min(bottom ?? sm.yBottom, sm.yBottom)
    }
    for item in items {
        switch item {
        case .run(.body, let lines): lines.forEach(take)
        case .heading(let sm, _), .numberedTitle(let sm, _), .monoTitle(let sm, _): take(sm)
        case .run(.note, _), .run(.gloss, _), .apparatus: break
        }
    }
    return bottom
}

/// Corpo tipografico MASSIMO fra gli span con testo di una riga (0 se nessuno): il corpo della riga che non risente del
/// maiuscoletto (cognomi a corpo minore) né dei richiami in apice.
func noteLineMaxSpanSize(_ line: LineSummary) -> Double {
    // solo gli span con lettere o cifre: una virgola o un trattino composti al corpo del testo dentro una riga di nota
    // non sono il corpo della riga (giro «pulizia delle note», 2026-10-17: una continuazione vera di Magnani era respinta)
    line.spans.filter { $0.fontSize > 0 && $0.text.contains(where: { $0.isLetter || $0.isNumber }) }
        .map { $0.fontSize }.max() ?? 0
}

/// Ricucitura delle note spezzate fra pagine CONTIGUE, fuori dall'Estratto e fuori dai codici (decisione del
/// maintainer del 2026-10-16, LAYER2 § 12.12). Lavora come la ricucitura per identità dell'Estratto — livello FOOTNOTE,
/// PRIMA del piazzamento, sul flatten delle note in ordine di lettura (il corpo è saltato: lo zip nodi↔pageItems dello
/// step 1 non è toccato) — ma solo sull'ULTIMA nota della pagina A e sulla PRIMA della pagina A + 1, e con guardie in
/// più, ciascuna contro una famiglia di falsi misurata dal conteggio del giro precedente
/// (`docs/CONTEGGIO_NOTE_SPEZZATE.md`):
///   • il predicato dell'app (`noteTailContinuesHead`): la testa resta aperta, la coda la continua (non apre con il
///     marcatore di una nota nuova);
///   • la SUCCESSIONE dei numeri: la testa porta il SUO numero (un riquadro, una bibliografia, una nota editoriale senza
///     numero non sono la testa di una nota spezzata: era l'unico falso del giudizio del conteggio), e
///     – primo gradino: la prima nota numerata dopo la coda, sulla pagina B, porta il numero della testa più uno — fra
///       testa e coda non può nascondersi un'altra nota;
///     – secondo gradino (nessuna nota numerata dopo la coda, cioè la nota riempie l'apparato della pagina B, oppure
///       successione rotta da un frammento con un numero spurio): la nota seguente non manca (il numero dopo la coda
///       non è quello della testa più due) e nel corpo delle pagine A e B non c'è un richiamo col numero della testa
///       più uno rimasto senza nota sulle pagine A, B e B + 1 — altrimenti la coda potrebbe essere quella nota, col
///       marcatore perso;
///   • il numero in testa alla coda, se c'è, non è quello della testa più uno (la coda non è la nota seguente);
///   • la coda COMINCIA SOTTO il corpo e i titoli della pagina B, e il nodo della testa sta sotto quelli della pagina
///     A: è l'apparato a piè di pagina, non una glossa, una citazione in corpo minore, un riquadro, una tabella o una
///     testatina che stanno fra le righe del corpo; una pagina senza corpo né titoli non si ricuce;
///   • lo stesso corpo tipografico (entro `BODY_SIZE_TOLERANCE`) fra l'ultima riga della testa e la prima della coda:
///     note dello stesso apparato, non una citazione in corpo minore che chiude il corpo della pagina B. Il corpo di
///     una riga è quello MASSIMO dei suoi span (`noteLineMaxSpanSize`): la media pesata dei caratteri scende con il maiuscoletto
///     dei cognomi e farebbe respingere una continuazione vera;
///   • entrambi i nodi sono NOTE (non le note editoriali).
/// Nel dubbio non si ricuce: si lascia una nota aperta, mai si fondono due note. De-sillaba la parola spezzata e
/// ricomputa `length_category`; catene su più pagine solo se ogni passo supera le guardie (la testa, ricucita, porta
/// il suo numero). Ritorna il numero di code fuse e il vaglio di ogni coppia candidata (coda senza marcatore d'apertura),
/// privo di testo.
func stitchAdjacentPageFootnotes(
    _ structure: [NodeDict],
    _ footnoteNodeById: inout [String: NodeDict],
    _ footnotesInNoteOrder: inout [String: [String]],
    noteLinesById: [String: [LineSummary]],
    contentBottomByPage: [Int: Double],
    callValuesByPage: [Int: Set<Int>] = [:],
    noteNumbersByPage: [Int: Set<Int>] = [:],
    bodyLeftByPage: [Int: Double] = [:]
) -> (count: Int, candidates: [AdjacentPageStitchCandidate]) {
    var flat: [String] = []
    var nodeOfFootnote: [String: NodeDict] = [:]
    var noteNodeIdsByPage: [Int: [String]] = [:]
    for node in structure where node.type == .NOTE || node.type == .EDITORIAL_NOTE {
        for fid in footnotesInNoteOrder[node.id] ?? [] {
            flat.append(fid)
            nodeOfFootnote[fid] = node
        }
        if node.type == .NOTE { noteNodeIdsByPage[node.page_index, default: []].append(node.id) }
    }
    guard flat.count >= 2 else { return (0, []) }

    var candidates: [AdjacentPageStitchCandidate] = []
    var removed = Set<String>()
    var headFid = flat[0]
    var tailPage = footnoteNodeById[headFid]?.page_index ?? Int.min
    // Il nodo dell'ULTIMA nota fisica della pagina della testa (per la geometria del lato A): per una catena è il nodo
    // della coda già fusa, che sta sulla pagina A.
    var lastNodeOnHeadSide = nodeOfFootnote[headFid]
    var count = 0
    for i in 1..<flat.count {
        let fid = flat[i]
        guard let cur = footnoteNodeById[fid], let head = footnoteNodeById[headFid],
              let curNode = nodeOfFootnote[fid] else { continue }
        let advance = {
            headFid = fid
            tailPage = cur.page_index
            lastNodeOnHeadSide = curNode
        }
        // Solo la prima nota della pagina che segue subito quella della testa.
        guard cur.page_index == tailPage + 1 else { advance(); continue }
        let a = (head.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let b = (cur.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        // Candidata solo una coda SENZA marcatore d'apertura (le regole di `splitFootnotes`).
        guard noteOpening(b) == nil, !noteSymbolOpening(b) else { advance(); continue }

        var headNumber = noteOpening(a)
        var nextNumber: Int?
        var j = i + 1
        var nextOpensLikeNote = true
        while j < flat.count, let f = footnoteNodeById[flat[j]], f.page_index == cur.page_index {
            if let n = noteOpening(f.text ?? "") {
                nextNumber = n
                nextOpensLikeNote = !noteNumberFollowedByLowercase(f.text ?? "")
                break
            }
            j += 1
        }
        // Testa-frammento (giro «pulizia delle note», 2026-10-17): la «testa» è un frammento che l'estrazione ha staccato
        // dalla nota vera a un numero spurio a inizio riga (un numero d'articolo o di pagina, una data). Se la successione
        // oltre la pagina lo prova — la nota che lo precede sulla pagina A porta il numero N, e la prima nota numerata dopo
        // la coda sulla pagina B porta N + 1 — e se la riga del frammento sta al margine delle righe di seguito e non al
        // rientro delle aperture, il frammento è la continuazione di quella nota: si riunisce a lei, e la coda le si ricuce.
        var recomposition: (fid: String, trueText: String)?
        if let nF = headNumber, nextNumber != nil, nextNumber != nF + 1,
           let fragment = headFragmentRecomposition(fragmentId: headFid, flat: flat, removed: removed,
                                                     footnoteNodeById: footnoteNodeById, nodeOfFootnote: nodeOfFootnote,
                                                     noteLinesById: noteLinesById, fragmentNumber: nF, nextNumber: nextNumber!) {
            recomposition = fragment
            headNumber = noteOpening(fragment.trueText)
        }
        let succession: String
        if headNumber == nil { succession = "testa senza numero" }
        else if nextNumber == nil { succession = "assente" }
        else if nextNumber == headNumber! + 1 { succession = "confermata" }
        else { succession = "non confermata" }
        let tailLeadingIsNext = headNumber.map { h in leadingInt(b) == h + 1 } ?? false
        let predicate = noteTailContinuesHead(head: a, tail: b)
        var nextCallUnmatched = false
        if let h = headNumber {
            let calls = callValuesByPage[tailPage, default: []].union(callValuesByPage[cur.page_index, default: []])
            let numbers = [tailPage, cur.page_index, cur.page_index + 1].reduce(into: Set<Int>()) {
                $0.formUnion(noteNumbersByPage[$1] ?? [])
            }
            nextCallUnmatched = calls.contains(h + 1) && !numbers.contains(h + 1)
        }

        let tailLines = noteLinesById[curNode.id] ?? []
        let headLines = lastNodeOnHeadSide.flatMap { noteLinesById[$0.id] } ?? []
        let tailFirst = tailLines.first
        let headFirst = headLines.first
        let headLast = headLines.last
        let tailBottom = contentBottomByPage[cur.page_index]
        let headBottom = lastNodeOnHeadSide.flatMap { contentBottomByPage[$0.page_index] }

        var candidate = AdjacentPageStitchCandidate(
            headPage: tailPage, tailPage: cur.page_index, headId: headFid, tailId: fid,
            predicate: predicate, succession: succession, headNumber: headNumber, nextNumber: nextNumber,
            tailLeadingIsNext: tailLeadingIsNext, nextCallUnmatched: nextCallUnmatched,
            tailTop: tailFirst?.yTop, tailPageContentBottom: tailBottom,
            headTop: headFirst?.yTop, headPageContentBottom: headBottom,
            tailSize: tailFirst.map(noteLineMaxSpanSize), headSize: headLast.map(noteLineMaxSpanSize),
            tailX0: tailFirst?.x0, tailX1: tailFirst?.x1, headX0: headLast?.x0, headX1: headLast?.x1,
            headNodeType: lastNodeOnHeadSide?.type.rawValue ?? "", tailNodeType: curNode.type.rawValue,
            stitched: false, reason: "")

        var reason = ""
        if curNode.type != .NOTE || lastNodeOnHeadSide?.type != .NOTE { reason = "nodo non NOTE" }
        // Giro «pulizia delle note» (2026-10-17, decisione 2 del maintainer): con la successione CONFERMATA (la prima nota
        // numerata dopo la coda porta il numero della testa più uno) il predicato non serve più: fra testa e coda non può
        // esserci un'altra nota numerata, e le guardie che seguono (geometria, corpo tipografico) fermano ciò che nota non è.
        // La conferma deve venire da una nota che si APRE come una nota: un numero seguito da una minuscola è un numero
        // spurio o il marcatore staccato e spostato dal testo della coda stessa (Compendio p. 1170), non la nota seguente.
        else if !predicate, !(succession == "confermata" && nextOpensLikeNote) { reason = "predicato" }
        else if succession == "testa senza numero" { reason = "successione testa senza numero" }
        else if succession == "non confermata", let h = headNumber, nextNumber == h + 2 {
            reason = "successione non confermata: nota seguente mancante"
        }
        else if succession != "confermata", nextCallUnmatched { reason = "richiamo della nota seguente senza nota" }
        else if tailLeadingIsNext { reason = "coda numerata come la nota seguente" }
        else if tailFirst == nil || headFirst == nil || headLast == nil { reason = "geometria assente" }
        // Una pagina senza corpo né titoli (una nota che la riempie tutta) non ha un corpo sotto cui stare: la si ricuce
        // solo se vale anche il predicato (testa aperta, coda che continua), oltre al corpo tipografico uguale.
        else if tailBottom == nil || headBottom == nil, !predicate { reason = "pagina senza corpo né titoli" }
        else if let bottom = tailBottom, !(tailFirst!.yTop < bottom) { reason = "coda non sotto il corpo" }
        else if let bottom = headBottom, !(headFirst!.yTop < bottom) { reason = "testa non sotto il corpo" }
        else if abs(noteLineMaxSpanSize(tailFirst!) - noteLineMaxSpanSize(headLast!)) > BODY_SIZE_TOLERANCE { reason = "corpo tipografico diverso" }
        // La coda è aperta da una glossa a margine, o è la glossa da sola (Mandrioli: la glossa stampata nel margine accanto
        // alle note, che l'estrazione mette in testa al nodo o legge come un nodo di note a sé). Ricucirla porterebbe la
        // glossa dentro la nota: la nota resta aperta.
        else if tailStartsWithMarginGloss(
            tailLines, bodyLeft: bodyLeftByPage[cur.page_index],
            noteColumnLeft: noteColumnLeft((noteNodeIdsByPage[cur.page_index] ?? []).filter { $0 != curNode.id }
                .compactMap { noteLinesById[$0] })) {
            reason = "coda aperta da una glossa a margine"
        }

        if reason.isEmpty {
            let merged: String
            if endsWithLetterHyphenG(a), let f = b.first, f.isLowercase {
                merged = String(a.dropLast()) + b           // de-sillabazione
            } else {
                merged = a + " " + b
            }
            if let r = recomposition {
                // la testa-frammento torna nella sua nota, e la nota vera diventa la testa della ricucitura
                let whole = joinFootnoteTexts(r.trueText, merged)
                removed.insert(headFid)
                candidate.recomposedFragmentId = headFid
                headFid = r.fid
                var t = footnoteNodeById[headFid]!
                t.text = whole
                t.length_category = lengthCategoryFor(whole)
                footnoteNodeById[headFid] = t
                removed.insert(fid)
                tailPage = cur.page_index
                lastNodeOnHeadSide = curNode
                count += 1
                candidate.stitched = true
                candidate.reason = "ricucita"
                candidates.append(candidate)
                continue
            }
            var h = head
            h.text = merged
            h.length_category = lengthCategoryFor(merged)
            footnoteNodeById[headFid] = h
            removed.insert(fid)
            tailPage = cur.page_index                        // catena: la testa copre fino a qui
            lastNodeOnHeadSide = curNode
            count += 1
            candidate.stitched = true
            candidate.reason = "ricucita"
        } else {
            candidate.reason = reason
            advance()
        }
        candidates.append(candidate)
    }
    if !removed.isEmpty {
        for (k, v) in footnotesInNoteOrder {
            footnotesInNoteOrder[k] = v.filter { !removed.contains($0) }
        }
    }
    return (count, candidates)
}

/// Vero se il numero d'apertura di una nota individuale è seguito da una parola in minuscolo («27 dell'esito…»): il
/// numero spurio a inizio riga di un frammento, o il marcatore che l'estrazione ha staccato dal testo della sua nota e
/// messo davanti al seguito. Non è la forma di una nota che si apre (maiuscola, citazione, parentesi, o il numero da solo).
func noteNumberFollowedByLowercase(_ text: String) -> Bool {
    let t = jsTrim(text)
    var rest = Substring(t)
    while let c = rest.first, c == "(" || c == "[" || c.isWhitespace { rest = rest.dropFirst() }
    guard rest.first?.isNumber == true else { return false }
    while let c = rest.first, c.isNumber { rest = rest.dropFirst() }
    while let c = rest.first, c == ")" || c == "]" || c == "." || c.isWhitespace { rest = rest.dropFirst() }
    guard let c = rest.first, c.isLetter else { return false }
    return c.isLowercase
}

/// Unione di due testi di nota come nelle ricuciture: de-sillabazione se il primo finisce con lettera e trattino e il
/// secondo comincia in minuscolo, altrimenti uno spazio.
func joinFootnoteTexts(_ a: String, _ b: String) -> String {
    let x = a.trimmingCharacters(in: .whitespacesAndNewlines)
    let y = b.trimmingCharacters(in: .whitespacesAndNewlines)
    if endsWithLetterHyphenG(x), let f = y.first, f.isLowercase { return String(x.dropLast()) + y }
    return x + " " + y
}

/// Le righe di ciascuna nota individuale di un nodo di note, con la STESSA regola di `splitFootnotes` (apertura per
/// numero o per simbolo; le note di testo vuoto non contano): l'intervallo di righe della nota `k` è `result[k]`.
func footnoteLineRanges(_ lines: [LineSummary]) -> [Range<Int>] {
    var result: [Range<Int>] = []
    var start: Int?
    func flush(_ end: Int) {
        guard let s = start, s < end else { return }
        if !joinLines(lines[s..<end].map { $0.text }).isEmpty { result.append(s..<end) }
        start = nil
    }
    for (i, line) in lines.enumerated() {
        if noteOpening(line.text) != nil || noteSymbolOpening(line.text) {
            flush(i)
            start = i
        } else if start == nil {
            start = i
        }
    }
    flush(lines.count)
    return result
}

/// Distanza minima (punti) fra il rientro delle aperture di nota e il margine delle righe di seguito perché la
/// geometria distingua le une dalle altre; e scarto ammesso fra la riga di un frammento e quel margine.
let NOTE_OPENING_INDENT_MIN = 3.0
let NOTE_CONTINUATION_MARGIN_TOLERANCE = 1.0

/// Di quanto (punti) la prima riga di un nodo di note può stare a sinistra della colonna senza essere nel margine.
let NOTE_COLUMN_OUTSIDE_TOLERANCE = 3.0
/// Due righe stanno alla stessa ascissa entro questa distanza (punti).
let NOTE_MARGIN_SAME_X = 1.5

/// Il margine sinistro della colonna del CORPO di una pagina: la più piccola fra le ascisse (al mezzo punto) che almeno
/// due righe di corpo condividono (una riga isolata non lo sposta; il corpo può avere due margini, il testo e le citazioni
/// in corpo minore rientrate), con almeno tre righe di corpo sulla pagina; nil altrimenti.
func bodyLeftMargin(_ items: [GenItem]) -> Double? {
    var counts: [Double: Int] = [:]
    var total = 0
    for item in items {
        if case .run(.body, let lines) = item {
            for line in lines where !line.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                counts[(line.x0 * 2).rounded() / 2, default: 0] += 1
                total += 1
            }
        }
    }
    guard total >= 3 else { return nil }
    return counts.filter { $0.value >= 2 }.keys.min()
}

/// Il margine sinistro della colonna delle note di una pagina, misurato sulle righe di seguito (non le aperture) dei nodi
/// di note dati: l'ascissa più frequente (al mezzo punto), condivisa da almeno due righe; nil se non misurabile.
func noteColumnLeft(_ nodes: [[LineSummary]]) -> Double? {
    var counts: [Double: Int] = [:]
    for lines in nodes {
        let starts = Set(footnoteLineRanges(lines).map { $0.lowerBound })
        for (i, line) in lines.enumerated() where !starts.contains(i) { counts[(line.x0 * 2).rounded() / 2, default: 0] += 1 }
    }
    guard let modal = counts.max(by: { $0.value != $1.value ? $0.value < $1.value : $0.key > $1.key }), modal.value >= 2
    else { return nil }
    return modal.key
}

/// Vero se il nodo di note comincia con una GLOSSA A MARGINE, o è fatto della sola glossa (giro «pulizia delle note»,
/// 2026-10-17; misurato sui Mandrioli: 25 code così, con la glossa stampata nel margine sinistro accanto alle note, che
/// l'estrazione mette in testa al nodo o legge come un nodo di note a sé). La firma: le righe in testa al nodo stanno a una
/// stessa ascissa, a sinistra della colonna del corpo della pagina (`bodyLeft`) di più di `NOTE_COLUMN_OUTSIDE_TOLERANCE`
/// (nel margine), e poi
///   • la riga che segue sta più a destra, nella colonna, e quell'ascissa non torna più nel resto del nodo (le note di un
///     apparato più largo del corpo, o su due colonne come nell'EdD, tornano al loro margine nelle righe che seguono; una
///     glossa no); oppure
///   • il nodo finisce lì (la glossa da sola) e le altre note della pagina hanno la loro colonna (`noteColumnLeft`, misurata
///     fuori dal nodo) più a destra di quell'ascissa, oltre la tolleranza. Senza quella misura non si ferma nulla: la coda
///     di una nota che sporge a sinistra del corpo (Rivista DPC) sta alla stessa ascissa delle altre note della pagina.
func tailStartsWithMarginGloss(_ lines: [LineSummary], bodyLeft: Double?, noteColumnLeft: Double?) -> Bool {
    guard let first = lines.first, let left = bodyLeft, first.x0 < left - NOTE_COLUMN_OUTSIDE_TOLERANCE else { return false }
    let x = first.x0
    guard let end = lines.firstIndex(where: { abs($0.x0 - x) > NOTE_MARGIN_SAME_X }) else {
        guard let column = noteColumnLeft else { return false }
        return x < column - NOTE_COLUMN_OUTSIDE_TOLERANCE
    }
    guard lines[end].x0 > x + NOTE_COLUMN_OUTSIDE_TOLERANCE else { return false }
    return !lines[end...].contains(where: { abs($0.x0 - x) <= NOTE_MARGIN_SAME_X })
}

/// Se la testa candidata `fragmentId` (l'ultima nota della pagina A, aperta da un numero `fragmentNumber`) è un
/// FRAMMENTO della nota che la precede, ritorna id e testo della nota vera (a cui il chiamante riunisce il frammento e la
/// coda); altrimenti nil.
/// Tutte le condizioni, ciascuna contro un modo di sbagliare:
///   • la nota vera T è la nota sopravvissuta che precede il frammento, nello STESSO nodo di note e sulla stessa pagina
///     (righe contigue dell'apparato), e porta il suo numero N;
///   • la successione oltre la pagina prova che il frammento non è una nota: la prima nota numerata dopo la coda, sulla
///     pagina B, porta N + 1 (`nextNumber`), e il numero del frammento non è N + 1;
///   • la geometria: la prima riga del frammento sta al MARGINE delle righe di seguito del nodo e non al RIENTRO delle
///     aperture (che dev'essere misurabile: almeno `NOTE_OPENING_INDENT_MIN` punti), cioè è una riga che continua una nota,
///     non una riga che ne apre una. Senza geometria misurabile non si ricompone (nel dubbio non si tocca).
func headFragmentRecomposition(
    fragmentId: String, flat: [String], removed: Set<String>,
    footnoteNodeById: [String: NodeDict], nodeOfFootnote: [String: NodeDict],
    noteLinesById: [String: [LineSummary]], fragmentNumber: Int, nextNumber: Int
) -> (fid: String, trueText: String)? {
    guard let fi = flat.firstIndex(of: fragmentId), let fragment = footnoteNodeById[fragmentId],
          let node = nodeOfFootnote[fragmentId] else { return nil }
    var ti = fi - 1
    while ti >= 0, removed.contains(flat[ti]) { ti -= 1 }
    guard ti >= 0 else { return nil }
    let trueId = flat[ti]
    guard let truth = footnoteNodeById[trueId], nodeOfFootnote[trueId]?.id == node.id,
          truth.page_index == fragment.page_index,
          let n = noteOpening(truth.text ?? ""), nextNumber == n + 1, fragmentNumber != n + 1 else { return nil }
    // geometria: la prima riga del frammento contro il margine di seguito e il rientro delle aperture del nodo
    guard let lines = noteLinesById[node.id], let k = Int(fragmentId.components(separatedBy: "_n").last ?? ""),
          case let ranges = footnoteLineRanges(lines), k < ranges.count else { return nil }
    guard let kt = Int(trueId.components(separatedBy: "_n").last ?? ""), kt < ranges.count else { return nil }
    let fragmentLine = lines[ranges[k].lowerBound]
    // il rientro delle aperture: la riga che apre la nota vera stessa (le righe che cominciano con un numero spurio non
    // contano); il margine delle righe di seguito: l'ascissa più frequente (al mezzo punto) delle righe che non aprono
    // una nota (una glossa o un capoverso rientrato non lo spostano), misurabile solo se almeno due righe la condividono
    let indent = lines[ranges[kt].lowerBound].x0
    let openingStarts = Set(ranges.map { $0.lowerBound })
    var margins: [Double: Int] = [:]
    for (i, line) in lines.enumerated() where !openingStarts.contains(i) {
        margins[(line.x0 * 2).rounded() / 2, default: 0] += 1
    }
    guard let modal = margins.max(by: { $0.value != $1.value ? $0.value < $1.value : $0.key > $1.key }),
          modal.value >= 2, case let m = modal.key, indent - m >= NOTE_OPENING_INDENT_MIN,
          abs(fragmentLine.x0 - m) <= NOTE_CONTINUATION_MARGIN_TOLERANCE else { return nil }
    return (trueId, truth.text ?? "")
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
        // La riga deve portare CONTENUTO di corpo perché vi si cerchi un richiamo.
        // Guardia allargata dalla taglia-corpo stretta (`== corpo ± 0.6`) a "almeno
        // uno span ≥ NOTE_RATIO·corpo": include le CITAZIONI A BLOCCO (Delitti: Genesi
        // a 10.3pt contro corpo 11.5pt), il cui span resta sopra la soglia-nota ma
        // sotto la taglia-corpo stretta. Senza questo, il richiamo posto in coda a una
        // citazione (il "2" apice della Genesi) non veniva mai trovato e la nota breve
        // restava non agganciata, finendo a fine paragrafo. Le righe di sola taglia-nota
        // (apparato a piè di pagina) restano escluse: sono nodi NOTE, non scanditi qui.
        let hasBody = line.spans.contains {
            $0.fontSize >= NOTE_RATIO * body
                && !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

/// Marcatori-SIMBOLO d'apertura di nota: la regola adottata al capitolo NOTE
/// (decisione 19-06-2026, verdetto § C.2) come riconoscitore GENERALE di
/// apertura-nota: «un blocco che apre con `*`/`†`/`‡` è nota distinta, non
/// continuazione». Set deliberatamente ristretto ai tre simboli della regola:
/// NIENTE `§`/`¶`, che nei testi giuridici aprono rinvii a paragrafi, non note
/// (quelli restano nel set largo di `textOpensWithNoteMarker`, che serve solo
/// a NON sopprimere l'innesco, mai a spezzare).
private let NOTE_OPENING_SYMBOLS: Set<Character> = ["*", "†", "‡"]

/// Vero se la riga apre una nota con marcatore-simbolo: `*`/`†`/`‡` seguito da
/// whitespace E da TESTO sulla stessa riga («* Dati presentati…»). Due guardie,
/// entrambe necessarie (calibrate sulla rete di delta a 40 volumi):
///  • lo spazio dopo il simbolo evita i falsi inneschi su token che iniziano
///    col simbolo senza esserne il marcatore ("**", "*testo");
///  • il TESTO dopo il simbolo esclude il simbolo NUDO su riga propria, che
///    non è un'apertura ma un segno ambiguo (nelle tabelle delle sostanze del
///    Codice penale ogni voce chiude con un "*" di colonna su riga propria:
///    senza questa guardia diventavano decine di finte note «Nota.» da un
///    carattere — regressione intercettata dalla rete). Nel dubbio, non si
///    spezza: il simbolo nudo resta assorbito dove stava.
func noteSymbolOpening(_ text: String) -> Bool {
    let t = jsTrim(text)
    guard t.count >= 3, let first = t.first, NOTE_OPENING_SYMBOLS.contains(first) else {
        return false
    }
    let afterSymbol = t.dropFirst()
    guard let second = afterSymbol.first, second.isWhitespace else { return false }
    return !afterSymbol.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
}

/// Spezza un run NOTE (più note a piè di pagina fuse dal Generic) nelle singole
/// note, riconoscendo l'apertura per il numero a inizio riga O per il
/// marcatore-simbolo (`noteSymbolOpening`, regola del capitolo NOTE). Una testa
/// senza marcatore è una continuazione cross-page (openingNumber nil); una
/// nota-simbolo ha anch'essa openingNumber nil (nessun numero da agganciare:
/// resta non-agganciata e viene letta in posizione col suo innesco), ma apre
/// una nota NUOVA — non viene mai assorbita in ciò che precede.
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
        } else if noteSymbolOpening(line.text) {
            // Apertura a marcatore-simbolo: nota NUOVA senza numero (regola
            // del capitolo NOTE). openingNumber resta nil: niente aggancio
            // numerico, lettura in posizione con l'innesco suo.
            flush()
            current = [line]
            currentOpening = nil
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
