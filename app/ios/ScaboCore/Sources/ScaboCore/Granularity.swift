//
//  Granularity.swift
//  ScaboCore
//
//  Motore di granularità di lettura per i TESTI DISCORSIVI (manuali, saggi,
//  dottrina, voci, materiali di studio). Riassembla il corpo discorsivo in blocchi
//  di dimensione controllata secondo le regole di prodotto § 7.6, a target di
//  caratteri parametrico (default 400, granularità fine).
//
//  ── Cosa fa e perché vive QUI ────────────────────────────────────────────────────
//
//  È LOGICA DETERMINISTICA: dato il flusso di segmenti del corpo e il target,
//  produce sempre gli stessi blocchi. Sta in ScaboCore accanto a BuildSegments /
//  Pagination, indipendente dalla presentazione, coperto dai test veloci `swift
//  test`. La view consuma il risultato; non sa nulla di come è stato prodotto.
//
//  ── Discorsivo vs normativo: determinazione per CATEGORIA (non per genere) ──────
//
//  Il prodotto (§ 7.7) prescrive che SOLO i testi discorsivi usino questa
//  modulazione; i testi normativi (codici, leggi, atti) restano alle loro unità
//  native (articoli, commi). Il `genre` del documento NON è un segnale affidabile
//  on-device: il plugin Generic — unico produttore PDF dell'app oggi — emette
//  sempre `genre = "unknown"`. La distinzione affidabile, ed esattamente quella a
//  cui il prodotto lega la regola, è la CATEGORIA del segmento:
//    • `BODY` è il corpo discorsivo (prodotto dal Generic e dai plugin discorsivi)
//      → viene granularizzato;
//    • `ARTICLE_BODY` / `PROCEDURAL` sono le unità native normative (riservate ai
//      backend AKN / EPUB e ai plugin dei codici) → NON vengono toccate;
//    • ogni altra categoria (HEADING_*, NOTE, SECTION_DIVIDER, gli artefatti, ecc.)
//      è un CONFINE di run e passa invariata.
//  Così il motore granularizza il corpo discorsivo ovunque appaia e lascia intatte
//  le strutture normative quando un produttore normative-aware le emette.
//
//  Limite noto e dichiarato: un PDF normativo processato dal SOLO Generic
//  on-device viene collassato a `BODY` (il Generic non possiede categorie
//  normative), e verrebbe quindi granularizzato. È il collasso preesistente del
//  Generic (documentato nella sua taxonomy), non un errore del motore; si risolve
//  quando i produttori normativi (plugin codici, AKN, EPUB), che emettono
//  `ARTICLE_BODY`, sono presenti.
//
//  ── Regole § 7.6, inderogabili ───────────────────────────────────────────────────
//
//  1. Non si attraversa MAI un confine di unità strutturale: il run di `BODY` si
//     chiude su qualunque segmento non-`BODY` (intestazione, paragrafo numerato,
//     sezione = sono segmenti HEADING_*; e così note/strutture). Un blocco può
//     restare sotto il target perché il run finisce al confine di struttura.
//  2. Non si spezza MAI una frase: i blocchi sono composti da frasi INTERE; se una
//     singola frase supera il target, diventa un blocco a sé più lungo del target.
//  3. Ogni blocco inizia all'inizio di una frase e finisce a un punto fermo (salvo
//     inizio/fine assoluti dell'unità: la prima/ultima frase del run può iniziare/
//     finire dove inizia/finisce il run).
//  Note, blocchi procedurali, schede operative NON rientrano nel raggruppamento per
//  caratteri: sono già unità a sé (categorie non-`BODY`) e passano invariate.
//
//  ── Segmentazione di frase: euristica CONSERVATIVA (la scelta-cardine) ──────────
//
//  I confini di frase non sono pre-annotati dalla classificazione: si calcolano dal
//  testo. Un naive "punto + spazio + maiuscola" sbaglierebbe sulle abbreviazioni
//  giuridiche ("art.", "c.c.", "n.", "cfr.") spezzando frasi a metà — degrado di
//  lettura che il prodotto vieta. Il segmentatore qui è deliberatamente
//  CONSERVATIVO: riconosce un confine SOLO ad alta confidenza (`.`/`!`/`?` +
//  eventuali virgolette/parentesi di chiusura + spazio + inizio-frase maiuscolo/
//  numerico/virgoletta-aperta), e per il punto fermo SOPPRIME il confine quando il
//  token che precede è una abbreviazione nota o una singola iniziale. Il modo di
//  fallimento è quindi ASIMMETRICO e SICURO: nel dubbio NON spezza, al più produce
//  un blocco più lungo del target — esito che § 7.6 esplicitamente ammette — e mai
//  spezza una frase a un'abbreviazione. La lista di abbreviazioni è chiusa e
//  documentata; resta un rischio residuo (un'abbreviazione fuori lista seguita da
//  maiuscola) che la validazione su corpus reale potrà ridurre estendendo la lista.
//

import Foundation

/// Target di caratteri per blocco, valore più fine del prodotto (§ 7.6). È un
/// parametro: il controllo utente dei quattro livelli (§ 7.7) è esposto da
/// `GranularityLevel`.
public let DEFAULT_GRANULARITY_TARGET = 400

/// I quattro livelli di granularità di lettura del prodotto (§ 7.7), come
/// vocabolario CHIUSO. Il `rawValue` è la stringa persistita, esattamente come
/// `ThemeSelection`/`LayoutId`: un valore mancante o fuori vocabolario collassa al
/// default in `getStoredGranularityLevel`. Ogni livello mappa a un target di
/// caratteri consumato da `granularizeBody(_:target:)` — il motore §7.6 esistente,
/// invariato. `fine` (400) è il default e coincide con `DEFAULT_GRANULARITY_TARGET`,
/// così esporre i livelli NON cambia il comportamento di chi non sceglie.
public enum GranularityLevel: String, CaseIterable, Sendable {
    case fine = "400"        // granularità fine (default, § 7.6)
    case medium = "600"
    case coarse = "900"
    case veryCoarse = "1200"

    /// Target di caratteri per blocco corrispondente al livello.
    public var target: Int {
        switch self {
        case .fine: return 400
        case .medium: return 600
        case .coarse: return 900
        case .veryCoarse: return 1200
        }
    }
}

/// Il livello di default globale (§ 7.6 "granularità fine"). Coincide con
/// `DEFAULT_GRANULARITY_TARGET` per non alterare il comportamento preesistente.
public let DEFAULT_GRANULARITY_LEVEL: GranularityLevel = .fine

/// Le categorie il cui flusso è riassemblato per caratteri: il corpo discorsivo.
/// Tutto il resto è confine di run e passa invariato (vedi docstring di testata).
public let GRANULARIZABLE_ROLES: Set<String> = [SemanticCategory.BODY.rawValue]

/// Riassembla i segmenti del corpo discorsivo in blocchi ~`target` caratteri,
/// secondo § 7.6. I segmenti non-`BODY` sono confini di run e passano invariati,
/// nell'ordine di lettura originale.
public func granularizeBody(
    _ segments: [ContentSegment],
    target: Int = DEFAULT_GRANULARITY_TARGET
) -> [ContentSegment] {
    var out: [ContentSegment] = []
    var runTexts: [String] = []
    var runIdBase: String?

    func flushRun() {
        if let base = runIdBase, !runTexts.isEmpty {
            out.append(contentsOf: granularizeRun(runTexts, idBase: base, target: target))
        }
        runTexts = []
        runIdBase = nil
    }

    for segment in segments {
        if GRANULARIZABLE_ROLES.contains(segment.role) {
            if runIdBase == nil { runIdBase = segment.id }
            runTexts.append(segment.text)
        } else {
            flushRun()
            out.append(segment)  // confine / apparato / struttura: invariato
        }
    }
    flushRun()
    return out
}

/// Granularizza un singolo run di corpo (testi di `BODY` consecutivi della stessa
/// unità strutturale). Concatena, segmenta in frasi, raggruppa in blocchi ~target
/// senza mai spezzare una frase. Gli id dei blocchi sono deterministici e stabili
/// (`<idBase>#<k>`), così lo stesso input produce sempre lo stesso output.
private func granularizeRun(_ texts: [String], idBase: String, target: Int) -> [ContentSegment] {
    let joined = texts
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: " ")
    let sentences = splitIntoSentences(joined)
    if sentences.isEmpty { return [] }

    var blocks: [String] = []
    var current = ""
    for sentence in sentences {
        if current.isEmpty {
            current = sentence
        } else if current.count + 1 + sentence.count <= target {
            current += " " + sentence
        } else {
            blocks.append(current)
            current = sentence  // una frase più lunga del target resta intera (blocco a sé)
        }
    }
    if !current.isEmpty { blocks.append(current) }

    return blocks.enumerated().map { index, text in
        ContentSegment(
            id: "\(idBase)#\(index)",
            role: SemanticCategory.BODY.rawValue,
            text: text,
            lengthCategory: "",
            acousticIntro: acousticIntroFor(SemanticCategory.BODY.rawValue, "")
        )
    }
}

/// Offset di carattere (indici in `Array(text)`) a cui termina un confine di
/// frase ad alta confidenza (subito dopo il terminatore + eventuali virgolette di
/// chiusura). Stessa euristica CONSERVATIVA di `splitIntoSentences`. Lo usa il
/// piazzamento delle note (§ 7.3) per trovare la fine della frase che contiene il
/// richiamo: una nota breve si legge subito dopo quel confine.
public func sentenceBoundaryOffsets(_ text: String) -> [Int] {
    let chars = Array(text)
    let count = chars.count
    var bounds: [Int] = []
    var i = 0
    while i < count {
        let ch = chars[i]
        if ch == "." || ch == "!" || ch == "?" {
            var afterClosings = i + 1
            while afterClosings < count, CLOSING_CHARS.contains(chars[afterClosings]) {
                afterClosings += 1
            }
            if afterClosings < count, chars[afterClosings].isWhitespace {
                var nextStart = afterClosings
                while nextStart < count, chars[nextStart].isWhitespace { nextStart += 1 }
                if nextStart < count, isSentenceStart(chars[nextStart]) {
                    let isBoundary = (ch == ".") ? !isAbbreviationBefore(chars, periodIndex: i) : true
                    if isBoundary {
                        bounds.append(afterClosings)
                        i = nextStart
                        continue
                    }
                }
            }
        }
        i += 1
    }
    return bounds
}

// MARK: - Segmentazione di frase (euristica conservativa)

/// Abbreviazioni italiane/giuridiche note (forma minuscola, senza punto finale,
/// punti interni conservati). Un punto fermo preceduto da una di queste NON è un
/// confine di frase. Lista chiusa; estendibile su evidenza di corpus reale.
let SENTENCE_ABBREVIATIONS: Set<String> = [
    // riferimenti normativi
    "art", "artt", "n", "nn", "nr", "co", "comma", "cost",
    "c.c", "c.p", "c.p.c", "c.p.p", "cc", "cpc", "cpp",
    "d.lgs", "dlgs", "d.l", "dl", "r.d", "rd", "t.u", "tu", "l", "lett",
    // riferimenti bibliografici / editoriali
    "cfr", "ss", "seg", "segg", "sg", "sgg", "es", "cap", "capp", "par", "parr",
    "p", "pp", "pag", "pagg", "vol", "voll", "fig", "tab", "ecc", "etc",
    "op", "cit", "vd", "ibid", "sub", "tit", "ed", "rist", "trad", "nota",
    // organi / soggetti
    "trib", "cass", "sez", "rel", "ord", "decr", "dott", "prof", "avv", "sig",
    "spa", "srl", "s.p.a", "s.r.l", "sec", "secc",
]

/// Caratteri di chiusura ammessi dopo il terminatore e prima dello spazio.
private let CLOSING_CHARS: Set<Character> = ["»", "\u{201D}", "\u{2019}", "\"", "'", ")", "]"]

/// Caratteri di apertura ammessi come inizio di una nuova frase.
private let OPENING_CHARS: Set<Character> = ["«", "\u{201C}", "\u{2018}", "\"", "'", "(", "["]

/// Spezza un testo in frasi (in ordine, contenuto preservato), riconoscendo un
/// confine SOLO ad alta confidenza. Conservativo per costruzione: nel dubbio non
/// spezza. Un testo senza punteggiatura forte resta un'unica "frase".
public func splitIntoSentences(_ text: String) -> [String] {
    let chars = Array(text)
    let count = chars.count
    var sentences: [String] = []
    var start = 0
    var i = 0

    while i < count {
        let ch = chars[i]
        if ch == "." || ch == "!" || ch == "?" {
            // Consuma eventuali virgolette/parentesi di chiusura subito dopo.
            var afterClosings = i + 1
            while afterClosings < count, CLOSING_CHARS.contains(chars[afterClosings]) {
                afterClosings += 1
            }
            // Serve almeno uno spazio, poi un inizio-frase ad alta confidenza.
            if afterClosings < count, chars[afterClosings].isWhitespace {
                var nextStart = afterClosings
                while nextStart < count, chars[nextStart].isWhitespace { nextStart += 1 }
                if nextStart < count, isSentenceStart(chars[nextStart]) {
                    let isBoundary = (ch == ".") ? !isAbbreviationBefore(chars, periodIndex: i) : true
                    if isBoundary {
                        let sentence = String(chars[start..<afterClosings])
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        if !sentence.isEmpty { sentences.append(sentence) }
                        start = nextStart
                        i = nextStart
                        continue
                    }
                }
            }
        }
        i += 1
    }

    if start < count {
        let tail = String(chars[start..<count]).trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty { sentences.append(tail) }
    }
    return sentences
}

/// Un carattere che può aprire una nuova frase: maiuscola, cifra, o virgoletta/
/// parentesi di apertura. Una minuscola NON apre una frase (guardia conservativa
/// contro i falsi confini, es. continuazioni di abbreviazione).
private func isSentenceStart(_ c: Character) -> Bool {
    c.isUppercase || c.isNumber || OPENING_CHARS.contains(c)
}

/// Vero se il punto in `periodIndex` segue un'abbreviazione nota o una singola
/// iniziale → NON è un confine di frase. Un punto preceduto da sole cifre (es.
/// "1218.") NON è abbreviazione e può essere confine.
private func isAbbreviationBefore(_ chars: [Character], periodIndex: Int) -> Bool {
    // Token = run massima di lettere e punti che termina al punto corrente.
    var begin = periodIndex - 1
    while begin >= 0, chars[begin].isLetter || chars[begin] == "." {
        begin -= 1
    }
    let token = chars[(begin + 1)...periodIndex]
    let letters = token.filter { $0.isLetter }
    if letters.isEmpty { return false }     // punto dopo cifre → non abbreviazione
    if letters.count == 1 { return true }   // singola iniziale (es. "L.", "F.") → abbreviazione

    let dotted = String(token).lowercased()
    let dottedNoTrailingDot = dotted.hasSuffix(".") ? String(dotted.dropLast()) : dotted
    let plain = String(letters).lowercased()
    return SENTENCE_ABBREVIATIONS.contains(dottedNoTrailingDot)
        || SENTENCE_ABBREVIATIONS.contains(plain)
}
