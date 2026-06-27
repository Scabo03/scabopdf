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

// ── Ricostruzione del corpo attraverso le pagine (continuità della colonna) ──────
//
// Un paragrafo che scavalca il salto pagina diventa due nodi BODY distinti; in mezzo,
// nell'ordine di lettura per posizione, finisce l'apparato (nota a piè) — letto DENTRO
// la frase. E le due metà restano spezzate, spesso a metà parola col trattino
// ("giu-"/"stizia" sull'Iliade di Delitti). Qui le ricuciamo, in modo deterministico:
//  • la giunzione del run DE-SILLABA (trattino di fine riga assorbito) quando la metà
//    seguente inizia in minuscolo (caso sicuro);
//  • un'APPARATO (NOTE/EDITORIAL_NOTE) incontrato mentre il run di corpo è APERTO (la
//    metà finisce a metà parola o a metà periodo) viene TRATTENUTO e ri-emesso DOPO il
//    paragrafo ricucito — mai dentro il periodo — purché la metà seguente sia una
//    continuazione. Così la nota resta letta (rete A), solo spostata fuori dalla frase.
//
// GUARDIE anti-fusione (zero falsi-fusione, calibrate sul banco reale su 10 volumi):
//  • la metà che "apre" deve finire a metà parola (trattino) o a metà periodo (lettera
//    o virgola, MAI punteggiatura forte . ! ? : » ») — un paragrafo completo finisce col
//    punto e NON si ricuce;
//  • la metà che "apre" NON dev'essere maiuscola (uno SCHEMA/titolo collassato in BODY)
//    né troppo corta (un'etichetta/frammento);
//  • la metà seguente deve iniziare in MINUSCOLO (le frasi/paragrafi nuovi iniziano in
//    maiuscolo; i versi pure) e NON con un marcatore d'elenco ("a)", "i)", "-", "1.").
// Nel dubbio NON si ricuce (stella polare): si perde al più una ricucitura, mai si
// fondono due paragrafi distinti.
//
// ── MATTONE 3: la CODA di una parola spezzata classificata NOTE ──────────────────
//
// Caso emerso dal mattone 2 e documentato lì: una parola spezzata col trattino di
// fine riga ("ecce-") la cui coda è finita INCOLLATA al numero di richiamo di nota
// ("zionali.14") e, per la dimensione ridotta dell'apice, classificata NOTE dal
// classificatore size-only. Risultato a orecchio: "…più ecce-" poi una falsa nota
// "zionali quattordici" poi "Si parla…" — la parola "eccezionali" spezzata in due e
// un numero letto in mezzo. Qui la coda viene RICUCITA nella parola (de-sillabazione)
// e il SOLO numero di richiamo rimosso (la nota vera resta letta a fondo pagina come
// nodo NOTE proprio: il numero in linea era solo il rimando, ridondante una volta che
// la nota è comunque letta). Il frammento-NOTE spurio sparisce.
//
// PALETTO ESPLICITO (deciso dal maintainer): la rimozione del numero di richiamo vale
// SOLO E UNICAMENTE per questa ricucitura di parola spezzata, MAI come regola
// generale. I numeri di richiamo nelle frasi normali restano e vanno letti (servono al
// lettore per sapere che, e quanti, richiami ci sono): vivono nei nodi BODY e li
// gestisce `NoteBinding` a monte — questo ramo, che lavora dopo, su un segmento NOTE
// trattenuto, non li raggiunge MAI. Le guardie (TUTTE necessarie insieme):
//  • il run di corpo aperto finisce in lettera+trattino (parola spezzata davvero);
//  • la coda trattenuta è UNA sola, corta (≤ FRAGMENT_TAIL_MAX_LEN), inizia MINUSCOLA
//    (completa la parola), NON apre con un marcatore di nota (≠ nota vera "14. Autore…");
//  • la coda FINISCE con un numero di richiamo (1–3 cifre) — l'unico token rimosso.
//  • il segmento seguente è una NUOVA frase (non una continuazione: quella la prende
//    già il mattone 2) — la parola si completa DENTRO la coda, non dopo.

/// Lunghezza minima della metà che "apre" perché valga come paragrafo in corso (sotto,
/// è un'etichetta/frammento → non si ricuce).
let CROSS_PAGE_MIN_OPEN_LEN = 40
/// Frazione massima di maiuscole della metà che "apre": sopra, è uno SCHEMA/titolo
/// collassato in BODY → non si ricuce.
let CROSS_PAGE_MAX_OPEN_CAPS = 0.7
/// Apparato trattenibile mentre un run di corpo è aperto: solo le note (non le
/// strutture). Glosse/indici/colophon sono già fuori dal flusso (NON_READ_ROLES).
let HOLDABLE_APPARATUS_ROLES: Set<String> = [
    SemanticCategory.NOTE.rawValue, SemanticCategory.EDITORIAL_NOTE.rawValue,
]

/// Vero se `s` termina con lettera + trattino (sillabazione di fine riga).
func endsWithLetterHyphenG(_ s: String) -> Bool {
    let sc = Array(s.unicodeScalars)
    guard sc.count >= 2, sc[sc.count - 1] == "-" else { return false }
    let v = sc[sc.count - 2].value
    return (v >= 0x41 && v <= 0x5A) || (v >= 0x61 && v <= 0x7A) || (v >= 0xC0 && v <= 0xFF)
}

/// Vero se la metà di corpo "apre" (il paragrafo prosegue): finisce a metà parola
/// (trattino) o a metà periodo (lettera/virgola, non punteggiatura forte), ed è prosa
/// in corso (non maiuscola-schema, non troppo corta). Guardia anti-fusione.
func bodyRunOpens(_ text: String) -> Bool {
    let s = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard s.count >= CROSS_PAGE_MIN_OPEN_LEN else { return false }
    if capsRatioCortina(s) >= CROSS_PAGE_MAX_OPEN_CAPS { return false }
    if endsWithLetterHyphenG(s) { return true }
    guard let last = s.last else { return false }
    return last == "," || last.isLetter
}

private let CROSS_PAGE_LIST_MARKER = try! NSRegularExpression(
    pattern: "^\\s*([a-z]\\)|[ivxlcdm]{1,4}\\)|[-–—•∙·*]\\s|\\d{1,2}[.)]\\s)")

/// Vero se la metà seguente è una CONTINUAZIONE: inizia in minuscolo (le frasi/
/// paragrafi/versi nuovi iniziano in maiuscolo) e NON con un marcatore d'elenco.
func bodyContinues(_ text: String) -> Bool {
    let s = text.trimmingCharacters(in: .whitespacesAndNewlines)
    if CROSS_PAGE_LIST_MARKER.firstMatch(in: s, range: NSRange(s.startIndex..<s.endIndex, in: s)) != nil {
        return false
    }
    for ch in s {
        if ch.isLetter { return ch.isLowercase }
        if ch.isWhitespace { continue }
        return false  // inizia con cifra/virgoletta/parentesi → non una continuazione chiara
    }
    return false
}

// ── Mattone 3 — coda di parola spezzata classificata NOTE ────────────────────────

/// Lunghezza massima della "coda spezzata + numero" perché valga come troncone di
/// parola e non come prosa vera. Gli 8 casi reali su Delitti stanno in 7–18 caratteri;
/// il cap a 40 lascia margine ma resta ben sotto la nota vera più corta del corpus che
/// inizierebbe minuscola (≥ ~100 char), così nessuna nota vera vi cade dentro.
let FRAGMENT_TAIL_MAX_LEN = 40

/// Numero di richiamo a fine coda: 1–3 cifre, eventualmente fra ( ) o [ ], con
/// whitespace di contorno. È il SOLO marcatore che il mattone 3 rimuove, e solo dalla
/// coda fusa. Ancorato a fine stringa: non tocca cifre interne (anni, pagine) della coda.
private let FRAGMENT_CALL_MARKER = try! NSRegularExpression(
    pattern: "\\s*[\\(\\[]?\\d{1,3}[\\)\\]]?\\s*$")

/// Vero se il primo carattere alfabetico di `s` è minuscolo (la coda completa la parola
/// spezzata; una frase/nota vera inizia in maiuscolo o con la cifra del proprio numero).
func firstAlphaIsLower(_ s: String) -> Bool {
    for ch in s where ch.isLetter { return ch.isLowercase }
    return false
}

/// Vero se il segmento NOTE `seg` è, da solo, una coda-di-parola-spezzata + numero di
/// richiamo (le guardie sul solo frammento; il contesto — corpo-trattino prima — lo
/// verifica il chiamante). Ritorna la coda col SOLO numero rimosso (parola e punto di
/// fine frase conservati), altrimenti nil.
func brokenWordTailCompletion(_ seg: ContentSegment) -> String? {
    guard HOLDABLE_APPARATUS_ROLES.contains(seg.role) else { return nil }
    let t = seg.text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard t.count <= FRAGMENT_TAIL_MAX_LEN,   // troncone corto, non prosa vera
          firstAlphaIsLower(t),               // completa la parola (minuscola)
          noteOpening(t) == nil               // non è una nota vera "14. Autore…"
    else { return nil }
    // Deve FINIRE con un numero di richiamo, che è l'unica cosa rimossa; davanti deve
    // restare la coda della parola (match non all'inizio della stringa).
    let ns = t as NSString
    guard let m = FRAGMENT_CALL_MARKER.firstMatch(in: t, range: NSRange(location: 0, length: ns.length)),
          m.range.location > 0 else { return nil }
    let completion = ns.substring(to: m.range.location)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    return completion.isEmpty ? nil : completion
}

/// Se fra l'apparato trattenuto c'è la CODA DI UNA PAROLA SPEZZATA + numero di richiamo
/// (mattone 3), ritorna `(indice nel vettore, coda ripulita)`; altrimenti nil. Il
/// chiamante fonde la coda e RIMUOVE solo quell'elemento, lasciando trattenute le note
/// VERE (ri-emesse dopo, mattone 2). Si cerca dall'ULTIMO perché `bindAndPlaceNotes` può
/// piazzare una nota lunga FRA il corpo-trattino e il frammento (il frammento, che è la
/// coda fisica della parola, resta l'ultimo trattenuto). Guardia di contesto: il run di
/// corpo aperto DEVE finire in lettera+trattino (parola spezzata davvero). nel dubbio nil.
func wordTailFragmentInHeld(_ held: [ContentSegment], openRunLast: String?)
    -> (index: Int, completion: String)?
{
    guard let last = openRunLast?.trimmingCharacters(in: .whitespacesAndNewlines),
          endsWithLetterHyphenG(last) else { return nil }
    for i in stride(from: held.count - 1, through: 0, by: -1) {
        if let completion = brokenWordTailCompletion(held[i]) { return (i, completion) }
    }
    return nil
}

// ── MATTONE 2/3 esteso al REGIME DELLE NOTE: continuità cross-pagina delle note ───
//
// Una nota spezzata dal salto pagina riaffiora come DUE segmenti NOTE consecutivi: il
// primo finisce a metà citazione (APRE: virgola, lettera, lettera+trattino, o
// un'abbreviazione che ATTENDE un numero — "p."/"n."/"art."/"vol."…), il secondo la
// CONTINUA (minuscola, oppure un numero di pagina/data che NON è un nuovo marcatore di
// nota). Si ricuciono in una sola nota (de-sillabando una parola spezzata
// "media-"|"tica"→"mediatica"), così la nota è letta di seguito e il frammento minuscolo/
// numerico spurio — che il classificatore size-only lascia come falso-"Nota." — sparisce.
//
// REGIME-AWARE (il punto chiave del mandato): nel regime AGGANCIATO una nuova nota apre
// con un marcatore "N " (1–3 cifre + spazio + Maiuscola); la guardia lo riconosce ed
// ESCLUDE, così non si fondono MAI due note distinte ("…493 ss." || "13 Le pronunce…"
// resta separato). Nel regime BIBLIOGRAFIA non agganciato non ci sono marcatori, e le
// continuazioni minuscole/di-pagina ("…Torino 1991, p." | "508 ss.; SORDI…") si ricuciono.
// PRECISIONE PRIMA DEL RECALL: una nota che finisce con punteggiatura forte (completa) NON
// apre; un frammento che inizia Maiuscolo (nuova voce/frase) o con un marcatore è una nuova
// nota → mai fuso. Nel dubbio non si ricuce: si lascia un frammento, mai si fondono due note.
// rete A: il testo è solo concatenato (de-sillabato), nessuna lettera persa.

/// Abbreviazioni che ATTENDONO un numero a seguire (la nota continua: "p." → "508").
/// Le abbreviazioni COMPLETE ("ss.", "cit.", "op.", "ecc.", "cfr.") NON aprono: un range
/// "64 ss." è finito, e un eventuale numero a seguire sarebbe un NUOVO marcatore di nota.
let NOTE_CONT_NUMBER_ABBR: Set<String> = [
    "p", "pp", "pag", "pagg", "n", "nn", "art", "artt",
    "vol", "voll", "cap", "capp", "par", "parr", "sez", "lett",
]
/// Marcatore di nota in testa al frammento: "5." "5)" "(5)" — è una NUOVA nota, mai fusa.
private let NOTE_NEW_MARKER_PUNCT = try! NSRegularExpression(pattern: "^\\s*[\\(\\[]?\\d{1,3}[\\.\\)]")
/// Marcatore del regime AGGANCIATO: "5 Sembra" / "39 F." (1–3 cifre + spazio + Maiuscola).
/// È il discriminante che impedisce di fondere due note distinte sotto questo regime.
private let NOTE_NEW_MARKER_BOUND = try! NSRegularExpression(pattern: "^\\s*\\d{1,3}\\s+[A-ZÀ-Ý]")

/// Vero se la nota `s` "apre" (attende una continuazione): finisce a metà — lettera,
/// virgola, lettera+trattino, o un'abbreviazione-che-attende-numero. Una nota completa
/// (punto forte, o abbreviazione completa tipo "ss.") NON apre.
func noteOpensForContinuation(_ s: String) -> Bool {
    let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let last = t.last else { return false }
    if last == "," { return true }
    if endsWithLetterHyphenG(t) { return true }
    if last.isLetter { return true }
    if last == "." {
        var word = ""
        for ch in t.dropLast().reversed() {
            if ch.isLetter { word.append(ch) } else { break }
        }
        return NOTE_CONT_NUMBER_ABBR.contains(String(word.reversed()).lowercased())
    }
    return false
}

/// Vero se la nota `s` è una CONTINUAZIONE (non una nuova nota): non un marcatore (né
/// "5."/"5)" né "5 Maiuscola"), e inizia in minuscolo o con una cifra (pagina/data);
/// mai Maiuscola (nuova voce/frase) né virgoletta/parentesi (avvio ambiguo).
func noteContinuation(_ s: String) -> Bool {
    let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
    let ns = t as NSString
    let r = NSRange(location: 0, length: ns.length)
    if NOTE_NEW_MARKER_PUNCT.firstMatch(in: t, range: r) != nil { return false }
    if NOTE_NEW_MARKER_BOUND.firstMatch(in: t, range: r) != nil { return false }
    for ch in t {
        if ch.isLetter { return ch.isLowercase }
        if ch.isNumber { return true }
        if ch.isWhitespace { continue }
        return false
    }
    return false
}

/// Pre-passo (mattone 2/3 esteso al regime note): ricuce le note spezzate dal salto
/// pagina. Fonde un segmento NOTE nel NOTE immediatamente precedente quando il primo APRE
/// e il secondo lo CONTINUA (vedi guardie). De-sillaba se la prima metà finisce in
/// lettera+trattino. Ricomputa lengthCategory/acousticIntro della nota fusa (cresciuta);
/// se l'intro della testa era già azzerata dal band-aid (nota senza marcatore, regime
/// bibliografia) resta azzerata. Conserva id/memoryRefresh della nota-testa.
func mergeNoteContinuations(_ segments: [ContentSegment]) -> [ContentSegment] {
    let NOTE = SemanticCategory.NOTE.rawValue
    var out: [ContentSegment] = []
    for seg in segments {
        if seg.role == NOTE, let prev = out.last, prev.role == NOTE,
           noteOpensForContinuation(prev.text), noteContinuation(seg.text) {
            let a = prev.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let b = seg.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let merged: String
            if endsWithLetterHyphenG(a), let f = b.first, f.isLowercase {
                merged = String(a.dropLast()) + b           // de-sillabazione
            } else {
                merged = a + " " + b
            }
            let lc = lengthCategoryFor(merged).rawValue
            var m = prev
            m.text = merged
            m.lengthCategory = lc
            m.acousticIntro = prev.acousticIntro.isEmpty ? "" : acousticIntroFor(NOTE, lc)
            out[out.count - 1] = m
        } else {
            out.append(seg)
        }
    }
    return out
}

// ── BIBLIOGRAFIA in corpo-piccolo: riconoscimento alla RADICE (NOTE → LETTERATURA) ─
//
// Una voce di bibliografia ("AUTORE, opera, in Riv., …, p. N ss.") è una riga corpo-piccolo
// classificata NOTE dal classificatore size-only, ma NON è una nota d'apparato con richiamo.
// Oggi resta letta come falso-"Nota." (zittita dal band-aid sui volumi generic). Qui la si
// RICONOSCE per ciò che è e la si riclassifica `LETTERATURA` — categoria già esistente
// (apparato bibliografico EdD), letta in loco, NON granularizzata, NON trattenuta, con intro
// acustica derivata dal ruolo (`acousticIntroFor(LETTERATURA)` = "", non un annuncio "Nota.").
// È riclassificazione alla radice, NON soppressione: cambia il RUOLO (riconoscimento) e ne
// deriva l'intro, non azzera l'annuncio di una NOTE lasciandola NOTE. Così la voce non diventa
// MAI un falso-"Nota." e il band-aid si ritira (resta corretta anche quando sarà rimosso).
//
// REGIME-AWARE + PRECISIONE (il rischio è l'altra direzione: una NOTA VERA scambiata per
// bibliografia). Guardia cardine: si tocca SOLO una NOTE SENZA marcatore di richiamo. Nel
// regime AGGANCIATO una nota vera apre col marcatore ("14 ANTOLISEI…") → esclusa → il suo
// "Nota." e il suo richiamo restano intatti. Una NOTE senza marcatore è già zittita dal
// band-aid (stessa lettura prima/dopo): riclassificarla non perde alcun richiamo (il richiamo
// in-corpo lo gestisce NoteBinding, qui non si tocca). Riconoscimento per PATTERN: cognome in
// MAIUSCOLETTO (o AA.VV./ID. o iniziali+cognome) + virgola in testa, E uno stilema bibliografico
// (", in ", "cit.", "a cura di", "p. N", "N ss.", rivista/enciclopedia, luogo di pubblicazione).
// Stress su 0 falsi-positivi: Cortina (Delitti/PM), codici, DeJure, box Costituzionale,
// Patriarca, Mosconi, Marotta → ZERO match (verificato sul campione). Gira DOPO
// `granularizeBody` (e quindi dopo `mergeNoteContinuations`): le bibliografie spezzate dal
// salto pagina sono già ricucite in un'unica NOTE, che qui viene riconosciuta intera — le due
// foglie non si pestano i piedi.

/// Marcatore di richiamo in testa (1–3 cifre + punto/paren, o "N Maiuscola" del regime
/// agganciato): se presente è una NOTA VERA con richiamo → MAI riclassificata.
private let BIBLIO_CALL_MARKER = try! NSRegularExpression(
    pattern: "^\\s*[\\(\\[]?\\d{1,3}[\\.\\)]|^\\s*\\d{1,3}\\s+[A-ZÀ-Ý]")
/// Autore in testa: AA.VV. / ID. / (iniziali) + cognome in MAIUSCOLETTO (≥3, accenti/'/-),
/// seguito da virgola o spazio. Il maiuscoletto (tutte maiuscole) distingue la voce
/// bibliografica dalla prosa Title-case.
private let BIBLIO_AUTHOR = try! NSRegularExpression(
    pattern: "^\\s*(AA\\.?\\s?VV\\.?|ID\\.|(?:[A-ZÀ-Ý]\\.\\s*){0,3}[A-ZÀ-Ý][A-ZÀ-Ý’'\\-]{2,})[,\\s]")
/// Stilema bibliografico: strutturali (in/cit/a cura di/p./ss./trad), riviste/enciclopedie,
/// e luogo di pubblicazione dopo virgola. Uno qualunque, in presenza dell'autore in testa.
private let BIBLIO_STYLEME = try! NSRegularExpression(
    pattern: ",\\s+in\\s+|[\\s(]cit\\.|op\\.\\s*cit|a\\s+cura\\s+di|,\\s+pp?\\.\\s*\\d|\\b\\d+\\s+ss\\.|,\\s+trad\\.|in\\s+Enc\\.|in\\s+Dig\\.|in\\s+Riv\\.|in\\s+Foro\\b|in\\s+Giur\\.|in\\s+Giust\\.|,\\s+(?:Milano|Torino|Bologna|Padova|Roma|Napoli|Firenze|Genova|Venezia|Pisa|Bari|Giuffrè)\\b")

/// Vero se `text` è una VOCE DI BIBLIOGRAFIA (autore-maiuscoletto in testa + stilema), e NON
/// una nota con richiamo (marcatore in testa → esclusa).
func looksLikeBibliographyEntry(_ text: String) -> Bool {
    let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
    let ns = t as NSString
    let r = NSRange(location: 0, length: ns.length)
    if BIBLIO_CALL_MARKER.firstMatch(in: t, range: r) != nil { return false }
    return BIBLIO_AUTHOR.firstMatch(in: t, range: r) != nil
        && BIBLIO_STYLEME.firstMatch(in: t, range: r) != nil
}

/// Post-passo: riclassifica le voci di bibliografia (NOTE senza richiamo + pattern) in
/// `LETTERATURA`, ricalcolando l'intro acustica dal nuovo ruolo (= "", non "Nota."). Testo
/// invariato (rete A: nessuna lettera tocca). Le NOTE con richiamo e ogni altra categoria
/// passano invariate.
func reclassifyBibliographyEntries(_ segments: [ContentSegment]) -> [ContentSegment] {
    let LETTERATURA = SemanticCategory.LETTERATURA.rawValue
    return segments.map { seg in
        guard seg.role == SemanticCategory.NOTE.rawValue,
              looksLikeBibliographyEntry(seg.text) else { return seg }
        var s = seg
        s.role = LETTERATURA
        s.acousticIntro = acousticIntroFor(LETTERATURA, s.lengthCategory)
        return s
    }
}

/// Riassembla i segmenti del corpo discorsivo in blocchi ~`target` caratteri (§ 7.6),
/// ricostruendo la continuità del corpo attraverso le pagine (vedi sopra). I segmenti
/// non-`BODY` sono confini di run; le note possono essere TRATTENUTE oltre un run aperto
/// e ri-emesse dopo il paragrafo ricucito. Prima si ricuciono le note spezzate dal salto
/// pagina (`mergeNoteContinuations`, mattone 2/3 esteso al regime note).
public func granularizeBody(
    _ rawSegments: [ContentSegment],
    target: Int = DEFAULT_GRANULARITY_TARGET
) -> [ContentSegment] {
    let segments = mergeNoteContinuations(rawSegments)
    var out: [ContentSegment] = []
    var runTexts: [String] = []
    var runIdBase: String?
    var heldApparatus: [ContentSegment] = []   // note trattenute mentre il run è aperto

    func flushRun() {
        if let base = runIdBase, !runTexts.isEmpty {
            out.append(contentsOf: granularizeRun(runTexts, idBase: base, target: target))
        }
        out.append(contentsOf: heldApparatus)   // l'apparato trattenuto va DOPO il paragrafo
        runTexts = []
        runIdBase = nil
        heldApparatus = []
    }

    for segment in segments {
        if GRANULARIZABLE_ROLES.contains(segment.role) {
            if runTexts.isEmpty {
                runIdBase = segment.id
                runTexts = [segment.text]
            } else if heldApparatus.isEmpty {
                runTexts.append(segment.text)   // corpo adiacente: comportamento invariato
            } else if bodyContinues(segment.text) {
                runTexts.append(segment.text)   // continuazione OLTRE l'apparato trattenuto
            } else if let frag = wordTailFragmentInHeld(
                        heldApparatus, openRunLast: runTexts.last) {
                // MATTONE 3: fra l'apparato trattenuto c'è la CODA DELLA PAROLA SPEZZATA +
                // il numero di richiamo. Si de-sillaba la coda nel run (assorbendo il
                // trattino), si rimuove il SOLO numero di richiamo (la nota vera resta
                // letta a fondo pagina), si CONSUMA il solo frammento-NOTE spurio (le note
                // vere eventualmente trattenute restano, ri-emesse dopo) e la frase
                // prosegue nello stesso run. Vedi PALETTO nella testata.
                let last = runTexts[runTexts.count - 1]
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                runTexts[runTexts.count - 1] = String(last.dropLast()) + frag.completion
                heldApparatus.remove(at: frag.index)
                runTexts.append(segment.text)   // stessa unità: la frase prosegue
            } else {
                flushRun()                       // metà seguente NON è continuazione: chiudi
                runIdBase = segment.id
                runTexts = [segment.text]
            }
        } else if HOLDABLE_APPARATUS_ROLES.contains(segment.role),
                  let last = runTexts.last, bodyRunOpens(last) {
            heldApparatus.append(segment)        // nota dentro un paragrafo aperto: trattieni
        } else {
            flushRun()
            out.append(segment)  // confine di struttura / apparato non trattenibile: invariato
        }
    }
    flushRun()
    // Post-passo: le voci di bibliografia in corpo-piccolo (NOTE senza richiamo + pattern
    // autore-maiuscoletto) sono riconosciute alla radice come LETTERATURA — dopo la ricucitura
    // delle note spezzate, così una bibliografia cross-pagina già unita è riconosciuta intera.
    return reclassifyBibliographyEntries(out)
}

/// Granularizza un singolo run di corpo (testi di `BODY` consecutivi della stessa
/// unità strutturale). Concatena, segmenta in frasi, raggruppa in blocchi ~target
/// senza mai spezzare una frase. Gli id dei blocchi sono deterministici e stabili
/// (`<idBase>#<k>`), così lo stesso input produce sempre lo stesso output.
private func granularizeRun(_ texts: [String], idBase: String, target: Int) -> [ContentSegment] {
    // Giunzione DE-SILLABANTE: se una metà finisce con lettera+trattino e la successiva
    // inizia in minuscolo, è sillabazione di fine riga → si assorbe il trattino e si
    // concatena senza spazio ("giu-" + "stizia" → "giustizia"); altrimenti spazio
    // (comportamento invariato: il trattino+uppercase resta com'era, niente distorsioni).
    var joined = ""
    for raw in texts {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { continue }
        if joined.isEmpty {
            joined = t
        } else if endsWithLetterHyphenG(joined), let first = t.first, first.isLowercase {
            joined = String(joined.dropLast()) + t
        } else {
            joined += " " + t
        }
    }
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
