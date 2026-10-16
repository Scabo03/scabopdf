//
//  ContentAnchor.swift
//  ScaboCore
//
//  ANCORE PER CONTENUTO delle annotazioni (giro «ancore», 2026-10-07, docs/ANCORE_ANNOTAZIONI.md).
//
//  Il problema. Segnalibri, sottolineature e posizione di lettura erano agganciati all'id del nodo
//  (`node_N`, un contatore sequenziale del Layer 1) e all'indice del segmento: ogni rielaborazione che
//  cambia la sequenza — una testatina in meno, un titolo in più, un'altra generazione del lettore di
//  sistema — li faceva atterrare su un altro passo in silenzio (provato dalle sonde
//  `AnnotationStabilityProbeTests`, build 45 su 27 volumi, docs/RIELABORAZIONE_PROGETTO.md § 1).
//
//  Il principio di prodotto (LAYER2_PRODUCT_DECISIONS § 12.13 / § 12.14): dopo una rielaborazione
//  un'annotazione o è al suo posto, verificato, oppure l'app lo dice. Mai un salto silenzioso.
//
//  Il disegno. L'ancora guarda al CONTENUTO del segmento, non alla sua posizione, e lo guarda
//  attraverso IMPRONTE (SHA-256 troncato) di un testo NORMALIZZATO, mai attraverso il testo:
//  - normalizzazione: minuscole, solo lettere e cifre Unicode. Spazi, punteggiatura, trattini di
//    sillabazione, segnaposto d'immagine spariscono: così le differenze reali fra le generazioni del
//    lettore (spazi fra parole, sillabazioni ricomposte, U+FFFC) non toccano l'impronta;
//  - tre impronte per segmento: `whole` (tutto il testo normalizzato), `head` (le prime
//    `edgeLength` = 64 lettere) e `tail` (le ultime). Testa e coda reggono ai nodi SPEZZATI o FUSI da
//    una cura: un vecchio segmento inglobato in uno nuovo si ritrova perché testa e coda compaiono nel
//    nuovo alla distanza giusta E all'inizio o alla fine del nuovo (una fusione incolla, non
//    inserisce nel mezzo: un titolo citato dentro un sommario non è una fusione); un vecchio segmento
//    spezzato in due si ritrova dalla testa, purché il nuovo sia PIÙ CORTO del vecchio (è un pezzo di
//    esso), lungo almeno 128 lettere e ne condivida il prefisso verificato sulla SCALA di impronte
//    (128/256/512/1024 lettere): due voci di bibliografia dello stesso autore condividono 64 lettere,
//    non 256. La fusione, a sua volta, deve aggiungere almeno 64 lettere: una testatina corrente che
//    ripete il titolo del paragrafo più il folio non è una fusione del titolo. Sotto le 64 lettere vale
//    solo l'impronta intera: la rete sulle annotazioni (prova «orfana») ha mostrato che con finestre di
//    32 lettere i titoli brevi e le note formulari si «ritrovavano» nei loro simili vicini;
//  - la posizione (pagina del file originale, indice di lettura, rango fra i segmenti identici
//    nella finestra di pagine) è SUGGERIMENTO e disambiguatore, mai prova: due «(Omissis).» a
//    poche pagine si distinguono per rango solo se la finestra ne ha ancora lo stesso numero; se
//    uno dei gemelli è sparito, l'ancora è orfana (il superstite potrebbe essere l'altro).
//  È il modello delle annotazioni web del W3C (TextQuoteSelector: testo esatto + contesto, con un
//  TextPositionSelector come suggerimento) adattato a due vincoli nostri: niente testo dei volumi
//  nell'ancora (per la regola sul diritto d'autore, quando le annotazioni viaggeranno fra iPad e
//  Mac) e tolleranza alle differenze note fra generazioni. Il compromesso: con le sole impronte non
//  si misura una somiglianza «quasi uguale» — o una finestra coincide o no. Lo si compensa con più
//  finestre (tutto, testa, coda, e per le sottolineature la citazione con prefisso e suffisso) e con
//  la scala di confidenza sotto.
//
//  La scala di confidenza, tarata sul DANNO (ricollocare con sicurezza nel posto sbagliato è peggio
//  che dichiarare orfana): `exact` 1,0 (impronta intera uguale) · `contained` 0,95 (testa e coda
//  ritrovate nel nuovo segmento alla distanza giusta: fusione) · `headAndTail` 0,9 (stesso inizio e
//  stessa fine, interno diverso: ordine delle righe) · `headOnly` 0,8 (spezzatura). Sotto la soglia
//  `relocationThreshold` = 0,8 — cioè sola coda, o nessuna impronta, o CANDIDATI AMBIGUI — l'ancora
//  è orfana e resta tale finché l'utente non la ricolloca. L'ambiguità è orfana per costruzione: una
//  testatina ricorrente marcata per sbaglio non si «ricolloca» su un'altra pagina. E OGNI riscontro,
//  anche esatto, vale solo entro una finestra di pagine dalla pagina d'origine (±2; ±1 per i testi
//  corti): un libro non sposta un passo di cento pagine, mentre i codici ripetono alla lettera la
//  stessa nota in cento punti — la rete sulle annotazioni (prova al contrario «orfana») ha mostrato che
//  senza la finestra un passo tolto si «ritrovava», sicuro e sbagliato, nel suo gemello lontano.
//
//  Costo: una passata sui segmenti (normalizzazione + tre SHA-256) all'apertura dell'indice; sui
//  codici (~47.000 segmenti) è dell'ordine delle centinaia di millisecondi, misurato dalla rete.
//

import CryptoKit
import Foundation

// MARK: - Impronte

public enum TextFingerprint {
    /// Lunghezza delle finestre di testa e coda (lettere normalizzate). 64: sotto, i titoli brevi e le
    /// note formulari dei codici si confondono con i loro simili; sopra, i riscontri parziali reggono.
    public static let edgeLength = 64
    /// Lunghezza del contesto (prefisso/suffisso) delle citazioni delle sottolineature.
    public static let contextLength = 16

    /// Minuscole, solo lettere e cifre (Unicode). Tutto il resto — spazi di ogni tipo, punteggiatura,
    /// trattini, apostrofi, segnaposto — sparisce. Le lettere accentate restano (à ≠ a).
    public static func normalize(_ text: String) -> String {
        var out = ""
        out.reserveCapacity(text.utf8.count)
        for ch in text where ch.isLetter || ch.isNumber {
            out.append(contentsOf: String(ch).lowercased())
        }
        return out
    }

    /// Come `normalize`, ma restituisce i caratteri normalizzati con, per ciascuno, l'indice della
    /// PAROLA d'origine (tokenizzazione `WordTokenizer`: run di non-spazi). Serve alle citazioni delle
    /// sottolineature per tornare da una posizione normalizzata agli indici di parola.
    public static func normalizeWithWordMap(_ text: String) -> (chars: [Character], wordIndex: [Int]) {
        var chars: [Character] = []
        var words: [Int] = []
        for (w, range) in WordTokenizer.wordRanges(text).enumerated() {
            for ch in text[range] where ch.isLetter || ch.isNumber {
                for lower in String(ch).lowercased() {
                    chars.append(lower)
                    words.append(w)
                }
            }
        }
        return (chars, words)
    }

    /// SHA-256 del testo (UTF-8), i primi 16 byte in esadecimale (32 caratteri). Non porta il testo e può
    /// viaggiare; per i testi BREVI (una citazione di poche lettere, un titolo corto) l'impronta si può
    /// indovinare per dizionario: non è una riproduzione del testo, ma non è nemmeno un segreto.
    public static func digest(_ text: String) -> String {
        let hash = SHA256.hash(data: Data(text.utf8))
        return hash.prefix(16).map { String(format: "%02x", $0) }.joined()
    }

    public static func digest<S: Sequence>(_ chars: S) -> String where S.Element == Character {
        digest(String(chars))
    }
}

// MARK: - Ancore

/// L'ancora per contenuto di un SEGMENTO (un elemento del flusso di lettura).
public struct ContentAnchor: Codable, Equatable, Sendable {
    /// Versione del disegno dell'ancora (per riconoscere, un giorno, ancore di una forma precedente).
    public var version: Int
    /// Ruolo del segmento alla creazione (BODY, NOTE, HEADING_2, …): informativo, non discriminante.
    public var role: String
    /// Pagina del file originale (1-based) alla creazione, se nota.
    public var sourcePage: Int?
    /// Lunghezza del testo normalizzato (0 = segmento senza lettere né cifre: ancora inerte).
    public var length: Int
    /// Impronte del testo normalizzato: tutto, prime `edgeLength` lettere, ultime `edgeLength`.
    /// Se `length <= edgeLength`, `head == tail == whole`.
    public var whole: String
    public var head: String
    public var tail: String
    /// Scala di impronte dei prefissi di 128, 256, 512, 1024 lettere (solo quelli che il testo copre):
    /// verifica che un segmento più corto sia davvero un PEZZO iniziale del vecchio (spezzatura).
    public var prefixLadder: [String]
    /// Rango (0-based) fra i segmenti con la STESSA impronta intera nella finestra di pagine attorno
    /// alla pagina d'origine (±`partialMatchPageWindow`, ±`shortTextPageWindow` per i testi corti),
    /// e quanti sono in tutto: disambiguano i testi identici ripetuti a poche pagine (le note ripetute
    /// alla lettera dei codici). Alla risoluzione il rango vale solo se la finestra ne ha ancora lo
    /// stesso numero; altrimenti l'ancora è orfana.
    public var windowRank: Int
    public var windowCount: Int
    /// Indice di lettura alla creazione: suggerimento e fallback dichiarato, mai prova.
    public var orderIndexHint: Int
    /// Il testo stava GIÀ, a un'estremità, dentro un altro segmento della finestra quando l'ancora è stata coniata
    /// (un titolo ripetuto in testa a un blocco più lungo: il titolo d'articolo della DPC e il blocco titolo +
    /// traduzioni della pagina prima). Quel segmento non è una fusione: per questa ancora il riscontro per
    /// contenimento non vale. `nil` nelle ancore coniate prima del 2026-10-08: comportamento invariato.
    public var containedElsewhere: Bool?
    /// Gemelli esatti nella finestra con un'altra FAMIGLIA di ruolo (titolo ↔ testo: il titolo di una massima
    /// DeJure è anche la prima frase del suo corpo): rango e conteggio sono presi nella famiglia dell'ancora, che si
    /// ritrova solo nella sua famiglia. `nil` nelle ancore coniate prima del 2026-10-08: comportamento invariato.
    public var familyTwins: Bool?

    public static let currentVersion = 1

    public init(version: Int = ContentAnchor.currentVersion, role: String, sourcePage: Int?, length: Int,
                whole: String, head: String, tail: String, prefixLadder: [String] = [], windowRank: Int, windowCount: Int,
                orderIndexHint: Int, containedElsewhere: Bool? = nil, familyTwins: Bool? = nil) {
        self.version = version
        self.role = role
        self.sourcePage = sourcePage
        self.length = length
        self.whole = whole
        self.head = head
        self.tail = tail
        self.prefixLadder = prefixLadder
        self.windowRank = windowRank
        self.windowCount = windowCount
        self.orderIndexHint = orderIndexHint
        self.containedElsewhere = containedElsewhere
        self.familyTwins = familyTwins
    }
}

/// L'ancora di una CITAZIONE dentro un segmento (uno span di sottolineatura): l'ancora del segmento
/// più l'impronta della citazione normalizzata, con prefisso e suffisso di contesto.
public struct QuoteAnchor: Codable, Equatable, Sendable {
    public var segment: ContentAnchor
    /// Impronta delle lettere normalizzate dalla prima all'ultima parola sottolineata, e quante sono.
    public var quote: String
    public var quoteLength: Int
    /// Impronte delle `contextLength` lettere prima e dopo la citazione (nil se non ce ne sono).
    public var prefix: String?
    public var suffix: String?

    public init(segment: ContentAnchor, quote: String, quoteLength: Int, prefix: String?, suffix: String?) {
        self.segment = segment
        self.quote = quote
        self.quoteLength = quoteLength
        self.prefix = prefix
        self.suffix = suffix
    }
}

// MARK: - Esiti

/// Livello di riscontro di un'ancora, in ordine di confidenza decrescente.
public enum AnchorMatchLevel: String, Codable, Sendable {
    case exact, contained, headAndTail, headOnly, orphan

    public var confidence: Double {
        switch self {
        case .exact: return 1.0
        case .contained: return 0.95
        case .headAndTail: return 0.9
        case .headOnly: return 0.8
        case .orphan: return 0.0
        }
    }
}

public struct AnchorResolution: Equatable, Sendable {
    /// Indice del segmento ritrovato nel flusso nuovo; `nil` se orfana.
    public let index: Int?
    public let level: AnchorMatchLevel
    /// Spiegazione tecnica breve (per il referto e la rete; non è il testo per l'utente).
    public let reason: String
    /// Quando il vecchio testo sta DENTRO un segmento più lungo (fusione, pezzi di nota tornati una nota sola): la
    /// posizione, nel testo normalizzato del segmento nuovo, dove il vecchio testo comincia. Le citazioni si cercano
    /// solo in quel tratto, con i suoi bordi (giro «costruzione della linea Mac», 2026-10-16). `nil` altrimenti.
    public var regionStart: Int? = nil

    public var confidence: Double { level.confidence }
    public var isRelocated: Bool { index != nil }

    public static func orphan(_ reason: String) -> AnchorResolution {
        AnchorResolution(index: nil, level: .orphan, reason: reason)
    }
}

public struct QuoteResolution: Equatable, Sendable {
    public let segmentIndex: Int
    public let startWord: Int
    public let endWord: Int
    public let level: AnchorMatchLevel
}

// MARK: - Indice del contenuto: conia e risolve

/// L'indice per contenuto di un flusso di segmenti: conia le ancore (alla creazione delle annotazioni)
/// e le risolve (dopo una rielaborazione). Si costruisce una volta per documento aperto.
public final class ContentAnchorIndex {
    /// Soglia di ricollocazione: sotto, l'ancora è orfana (vedi la scala in testa al file).
    public static let relocationThreshold = 0.8
    /// Finestra di pagine entro cui un riscontro — anche ESATTO — è ammesso quando la pagina d'origine
    /// è nota: oltre, l'ancora è orfana («ritrovato solo lontano dalla pagina»). Le fusioni fra pagine
    /// spostano l'attribuzione di una pagina; un passo non migra mai di cento. Un candidato SENZA
    /// pagina non passa il filtro (prudenza: non si sa dove sia).
    public static let partialMatchPageWindow = 2
    /// Finestra di pagine per i testi CORTI (sotto `edgeLength`): un'impronta corta è debole.
    public static let shortTextPageWindow = 1
    /// Lunghezze della scala di prefissi (`ContentAnchor.prefixLadder`).
    public static let ladderLengths = [128, 256, 512, 1024]
    /// Una fusione deve AGGIUNGERE almeno tante lettere: sotto, è una variante del segmento (testatina
    /// con folio), non un segmento inglobato in un altro.
    public static let containedMinExtraLength = 64

    public let segments: [ContentSegment]
    private let normalized: [String]
    private let wholeDigests: [String]
    private let headDigests: [String]
    private let tailDigests: [String]
    private var byWhole: [String: [Int]] = [:]
    private var byHead: [String: [Int]] = [:]
    private var byTail: [String: [Int]] = [:]
    private let pageOf: [Int?]

    public init(segments: [ContentSegment]) {
        self.segments = segments
        var normalized: [String] = []
        var whole: [String] = []
        var head: [String] = []
        var tail: [String] = []
        normalized.reserveCapacity(segments.count)
        whole.reserveCapacity(segments.count)
        head.reserveCapacity(segments.count)
        tail.reserveCapacity(segments.count)
        for s in segments {
            let n = TextFingerprint.normalize(s.text)
            normalized.append(n)
            let w = TextFingerprint.digest(n)
            whole.append(w)
            if n.count <= TextFingerprint.edgeLength {
                head.append(w)
                tail.append(w)
            } else {
                head.append(TextFingerprint.digest(n.prefix(TextFingerprint.edgeLength)))
                tail.append(TextFingerprint.digest(n.suffix(TextFingerprint.edgeLength)))
            }
        }
        self.normalized = normalized
        self.wholeDigests = whole
        self.headDigests = head
        self.tailDigests = tail
        self.pageOf = segments.map { $0.sourcePage }
        for i in segments.indices {
            byWhole[whole[i], default: []].append(i)
            byHead[head[i], default: []].append(i)
            byTail[tail[i], default: []].append(i)
        }
    }

    public var count: Int { segments.count }

    /// Vero se il segmento con id `segmentId` ha esattamente il contenuto descritto dall'ancora (stessa
    /// impronta intera). È la VERIFICA a contenuto fermo: un'annotazione il cui id punta a un segmento con
    /// un'altra impronta non è al suo posto (rielaborazione interrotta, id riusati) e va riancorata.
    public func anchor(_ anchor: ContentAnchor, matchesSegmentId segmentId: String) -> Bool {
        guard let i = indexById[segmentId] else { return false }
        return wholeDigests[i] == anchor.whole
    }

    private lazy var indexById: [String: Int] = {
        var m: [String: Int] = [:]
        for (i, s) in segments.enumerated() where m[s.id] == nil { m[s.id] = i }
        return m
    }()

    // MARK: Coniare

    /// L'ancora del segmento di indice `index`.
    public func anchor(forIndex index: Int) -> ContentAnchor? {
        guard segments.indices.contains(index) else { return nil }
        let page = pageOf[index]
        let length = normalized[index].count
        let window = Self.pageWindow(forLength: length)
        let world = Self.isVisualWorld(segments[index].role)
        let allTwins = (byWhole[wholeDigests[index]] ?? []).filter {
            Self.inWindow(pageOf[$0], of: page, window) && Self.isVisualWorld(segments[$0].role) == world
        }
        // Gemelli di un'altra famiglia di ruolo: il ruolo li distingue, rango e conteggio si prendono nella famiglia.
        let family = Self.roleFamily(segments[index].role)
        let familyTwins = allTwins.contains { Self.roleFamily(segments[$0].role) != family }
        let twins = familyTwins ? allTwins.filter { Self.roleFamily(segments[$0].role) == family } : allTwins
        let rank = twins.firstIndex(of: index) ?? 0
        // Il testo è già contenuto, a un'estremità, in un altro segmento della finestra: non sarà una fusione.
        let containedElsewhere = length > TextFingerprint.edgeLength
            && !containers(length: length, head: headDigests[index], tail: tailDigests[index], page: page, visualWorld: world).isEmpty
        let n = normalized[index]
        let ladder = Self.ladderLengths.filter { $0 <= length }.map { TextFingerprint.digest(n.prefix($0)) }
        return ContentAnchor(
            role: segments[index].role, sourcePage: page, length: length,
            whole: wholeDigests[index], head: headDigests[index], tail: tailDigests[index], prefixLadder: ladder,
            windowRank: rank, windowCount: max(1, twins.count), orderIndexHint: index,
            containedElsewhere: containedElsewhere ? true : nil, familyTwins: familyTwins ? true : nil)
    }

    /// Il «mondo» di un ruolo per le ancore: l'elemento «risorsa visiva» (additivo, con l'annuncio e la didascalia) da
    /// una parte, il testo del libro dall'altra. Un'ancora nata sul testo non si ricolloca mai su una risorsa visiva e
    /// viceversa: la didascalia ripetuta nell'annuncio non deve attirare una sottolineatura fatta sul testo.
    static func isVisualWorld(_ role: String) -> Bool { role == VISUAL_RESOURCE_ROLE }

    /// Famiglia di ruolo che distingue i gemelli: i titoli (HEADING_n, ARTICLE_HEADER) da tutto il resto. Solo due
    /// famiglie di proposito: le cure cambiano legittimamente il ruolo dentro il testo (nota ↔ corpo) e fra titoli
    /// (i livelli), e la famiglia vale solo per le ancore che avevano un gemello dell'altra.
    static func roleFamily(_ role: String) -> Int { role.hasPrefix("HEADING_") || role == "ARTICLE_HEADER" ? 1 : 0 }

    static func pageWindow(forLength length: Int) -> Int {
        length <= TextFingerprint.edgeLength ? shortTextPageWindow : partialMatchPageWindow
    }

    /// Vero se `candidate` sta entro `window` pagine da `page`. Pagina d'origine ignota: tutto vale;
    /// pagina del candidato ignota (con l'origine nota): non vale (non si sa dove sia).
    static func inWindow(_ candidate: Int?, of page: Int?, _ window: Int) -> Bool {
        guard let page else { return true }
        guard let candidate else { return false }
        return abs(candidate - page) <= window
    }

    /// L'ancora di una citazione: le parole `startWord...endWord` (indici `WordTokenizer`) del segmento.
    /// `nil` se gli indici non cadono nel segmento o la citazione non ha lettere né cifre.
    public func quoteAnchor(forIndex index: Int, startWord: Int, endWord: Int) -> QuoteAnchor? {
        guard let segmentAnchor = anchor(forIndex: index), startWord <= endWord else { return nil }
        let (chars, words) = TextFingerprint.normalizeWithWordMap(segments[index].text)
        guard let start = words.firstIndex(of: startWord), let end = words.lastIndex(of: endWord),
              start <= end else { return nil }
        let quote = chars[start...end]
        let before = chars[max(0, start - TextFingerprint.contextLength)..<start]
        let after = chars[(end + 1)..<min(chars.count, end + 1 + TextFingerprint.contextLength)]
        return QuoteAnchor(
            segment: segmentAnchor, quote: TextFingerprint.digest(quote), quoteLength: quote.count,
            prefix: before.isEmpty ? nil : TextFingerprint.digest(before),
            suffix: after.isEmpty ? nil : TextFingerprint.digest(after))
    }

    // MARK: Risolvere

    /// Risolve un'ancora di segmento nel flusso di questo indice. Mai un salto silenzioso: sotto la
    /// soglia, o con più candidati equivalenti, l'esito è `orphan` con la ragione.
    public func resolve(_ anchor: ContentAnchor) -> AnchorResolution {
        guard anchor.length > 0 else { return .orphan("ancora inerte: il segmento non aveva lettere") }
        let world = Self.isVisualWorld(anchor.role)
        let sameWorld: (Int) -> Bool = { Self.isVisualWorld(self.segments[$0].role) == world }

        // 1. Impronta intera uguale. Con gemelli di un'altra famiglia di ruolo alla creazione, si cerca nella famiglia
        //    dell'ancora: se l'impronta resta solo nell'altra famiglia, è il gemello, non l'elemento annotato.
        let exactAll = (byWhole[anchor.whole] ?? []).filter(sameWorld)
        var exact = exactAll
        if anchor.familyTwins == true {
            let family = Self.roleFamily(anchor.role)
            exact = exactAll.filter { Self.roleFamily(segments[$0].role) == family }
            if exact.isEmpty, !exactAll.isEmpty {
                return .orphan("exact: resta solo il gemello di un'altra famiglia di ruolo")
            }
        }
        if !exact.isEmpty {
            return pick(exact, anchor: anchor, level: .exact, pageWindow: Self.pageWindow(forLength: anchor.length))
        }
        // 1-bis. Lo stesso testo, intero, DIVISO IN PEZZI CONSECUTIVI (giro «costruzione della linea Mac», 2026-10-16,
        //    revisione indipendente): la lettura del Mac fraziona le note lunghe, una granularità diversa divide il corpo.
        //    I pezzi ricompongono il testo dell'ancora esattamente (stessa lunghezza normalizzata e stessa impronta
        //    intera), quindi il riscontro vale quanto l'impronta intera; l'ancora va sul primo pezzo, dove il testo comincia.
        //    I gemelli (testi identici nella finestra) si distinguono per rango come al passo 1.
        let chainStarts = splitChainStarts(anchor)
        if !chainStarts.isEmpty {
            return pick(chainStarts, anchor: anchor, level: .exact, pageWindow: Self.pageWindow(forLength: anchor.length))
        }
        // Un testo corto senza riscontro esatto non ha testa/coda distinte: orfano.
        guard anchor.length > TextFingerprint.edgeLength else {
            return .orphan("testo corto non ritrovato")
        }
        // 2. Testa e coda alle estremità dello stesso segmento (interno diverso).
        let heads = Set((byHead[anchor.head] ?? []).filter(sameWorld))
        let tails = Set((byTail[anchor.tail] ?? []).filter(sameWorld))
        let both = heads.intersection(tails)
        if !both.isEmpty {
            return pick(Array(both).sorted(), anchor: anchor, level: .headAndTail,
                        pageWindow: Self.partialMatchPageWindow)
        }
        // 3. Testa e coda DENTRO un segmento più lungo, alla distanza giusta e a un'estremità (fusione). Non se il testo
        //    stava già dentro un altro segmento quando l'ancora è nata: quel segmento non è una fusione (giro finale
        //    2026-10-08, prova al contrario della rete: tolto il titolo, l'ancora finiva nel blocco che lo ripeteva).
        if anchor.containedElsewhere != true {
            let contained = containingCandidates(anchor)
            if !contained.isEmpty {
                return withRegion(pick(contained.map { $0.index }, anchor: anchor, level: .contained,
                                       pageWindow: Self.partialMatchPageWindow), contained)
            }
        }
        // 3-bis. Un PEZZO DI NOTA (continuazione: la parte di una nota lunga divisa in più segmenti, o il seguito di una
        //    nota sulla pagina dopo) dentro una nota più lunga, in QUALUNQUE punto e non solo a un'estremità: quando le
        //    parti tornano una nota sola, quelle di mezzo stanno nel mezzo (giro «costruzione della linea Mac»,
        //    2026-10-16: le letture del Mac frazionano le note lunghe; dalla build 55 anche l'iPad, e il ritorno a note
        //    intere resta quello verso una lettura precedente). Solo fra note e con testa
        //    e coda alla distanza giusta, all'inizio di una parola; più posizioni o più note → ambiguo, orfana.
        if anchor.role == Self.noteContinuationRole, anchor.containedElsewhere != true,
           anchor.length > TextFingerprint.edgeLength {
            let inside = noteInteriorCandidates(anchor)
            if !inside.isEmpty {
                return withRegion(pick(inside.map { $0.index }, anchor: anchor, level: .contained,
                                       pageWindow: Self.partialMatchPageWindow), inside)
            }
        }
        // 4. Sola testa all'inizio di un segmento PIÙ CORTO del vecchio (spezzatura: il segnalibro marca
        //    l'inizio e il nuovo segmento è un pezzo del vecchio), verificato sulla scala dei prefissi.
        //    Solo se la testa è UNICA nella finestra di pagine: un passo ripetuto quasi alla lettera a poche pagine
        //    (un comma e la sua ristampa nel testo previgente) ha la stessa testa e la sola testa non dice quale
        //    dei due era. Visto nella prova al contrario della rete (giro finale 2026-10-08): tolto il testo
        //    originale, la sua ristampa due pagine dopo veniva presa per il primo pezzo di una spezzatura.
        let headsInWindow = heads.filter { Self.inWindow(pageOf[$0], of: anchor.sourcePage, Self.partialMatchPageWindow) }
        if headsInWindow.count > 1 {
            return .orphan("headOnly: la testa compare in \(headsInWindow.count) segmenti della finestra")
        }
        let splitHeads = heads.filter { isInitialPiece(normalized[$0], of: anchor) }
        if !splitHeads.isEmpty {
            return pick(Array(splitHeads).sorted(), anchor: anchor, level: .headOnly,
                        pageWindow: Self.partialMatchPageWindow)
        }
        if !tails.isEmpty { return .orphan("ritrovata solo la coda: sotto soglia") }
        return .orphan("nessuna impronta ritrovata")
    }

    /// Risolve la citazione di una sottolineatura: prima il segmento, poi la citazione dentro il
    /// segmento ritrovato (o, se spezzato, nei suoi vicini della stessa pagina). Orfana se la
    /// citazione non c'è o compare più volte senza che prefisso/suffisso la distinguano.
    public func resolve(_ quote: QuoteAnchor) -> QuoteResolution? {
        guard let spans = resolveSpans(quote), spans.count == 1 else { return nil }
        return spans[0]
    }

    /// Come `resolve(_:)`, ma la citazione può tornare in PIÙ span quando il suo segmento è stato diviso in pezzi
    /// consecutivi e la citazione attraversa il confine fra due pezzi (una sottolineatura su più blocchi, § 6.2):
    /// uno span per pezzo toccato, in ordine. `nil` se la citazione non c'è o è ambigua.
    public func resolveSpans(_ quote: QuoteAnchor) -> [QuoteResolution]? {
        let seg = resolve(quote.segment)
        guard let idx = seg.index else { return nil }
        // Il segmento è stato diviso in pezzi consecutivi che lo ricompongono esattamente: la citazione si cerca nel
        // testo ricomposto, con le stesse regole (confini di parola, contesto) che valevano nel segmento intero.
        if let chain = splitChain(from: idx, for: quote.segment) {
            return locate(quote, inChain: chain, level: seg.level)
        }
        // Il vecchio testo sta dentro un segmento più lungo: la citazione si cerca solo nel suo tratto, con i bordi del
        // tratto (una citazione che stava sul bordo del vecchio segmento non deve finire sul bordo del nuovo).
        if let start = seg.regionStart {
            guard let r = locate(quote, in: idx, region: start..<(start + quote.segment.length)) else { return nil }
            return [QuoteResolution(segmentIndex: idx, startWord: r.0, endWord: r.1, level: seg.level)]
        }
        if let r = locate(quote, in: idx) {
            return [QuoteResolution(segmentIndex: idx, startWord: r.0, endWord: r.1, level: seg.level)]
        }
        // Spezzatura: la citazione può stare nel segmento seguente o precedente della stessa pagina (dello stesso mondo:
        // un elemento «risorsa visiva» frapposto si scavalca, non si guarda).
        let world = Self.isVisualWorld(segments[idx].role)
        func neighbour(_ step: Int) -> Int? {
            var j = idx + step
            while segments.indices.contains(j), Self.isVisualWorld(segments[j].role) != world { j += step }
            return segments.indices.contains(j) ? j : nil
        }
        for neighbour in [neighbour(1), neighbour(-1)].compactMap({ $0 }) where pageOf[neighbour] == pageOf[idx] {
            if let r = locate(quote, in: neighbour) {
                return [QuoteResolution(segmentIndex: neighbour, startWord: r.0, endWord: r.1, level: .headOnly)]
            }
        }
        return nil
    }

    // MARK: Interni

    private func pick(_ candidates: [Int], anchor: ContentAnchor, level: AnchorMatchLevel,
                      pageWindow: Int?) -> AnchorResolution {
        var pool = candidates
        if let window = pageWindow {
            pool = pool.filter { Self.inWindow(pageOf[$0], of: anchor.sourcePage, window) }
            if pool.isEmpty { return .orphan("\(level.rawValue): ritrovato solo lontano dalla pagina") }
        }
        if level == .exact {
            // Testi identici nella finestra: il rango vale solo se la finestra ne ha ancora lo stesso numero.
            // Se un gemello è sparito (o ne è comparso uno), il superstite potrebbe essere l'altro: orfana.
            if anchor.sourcePage != nil, anchor.windowCount > 1 || pool.count > 1 {
                guard pool.count == anchor.windowCount, pool.indices.contains(anchor.windowRank) else {
                    return .orphan("exact: \(pool.count) gemelli nella finestra, erano \(anchor.windowCount)")
                }
                return AnchorResolution(index: pool[anchor.windowRank], level: level,
                                        reason: "exact: rango \(anchor.windowRank + 1) di \(pool.count) nella finestra")
            }
            if pool.count == 1 { return AnchorResolution(index: pool[0], level: level, reason: "exact: unico") }
            return .orphan("exact: \(pool.count) candidati equivalenti")
        }
        if pool.count == 1 { return AnchorResolution(index: pool[0], level: level, reason: "\(level.rawValue): unico") }
        return .orphan("\(level.rawValue): \(pool.count) candidati equivalenti")
    }

    /// I segmenti che CONTENGONO il vecchio testo a un'ESTREMITÀ: finestra di testa e finestra di coda
    /// alla distanza `length - edgeLength`, con il vecchio testo all'inizio o alla fine del nuovo (una
    /// fusione incolla due segmenti, non ne inserisce uno nel mezzo di un altro). Si cercano solo nei
    /// segmenti più lunghi del vecchio, nella finestra di pagine (se nota).
    private func containingCandidates(_ anchor: ContentAnchor) -> [(index: Int, start: Int)] {
        containerPositions(length: anchor.length, head: anchor.head, tail: anchor.tail, page: anchor.sourcePage,
                           visualWorld: Self.isVisualWorld(anchor.role))
    }

    /// La risoluzione con la posizione del vecchio testo nel segmento scelto (vedi `AnchorResolution.regionStart`).
    private func withRegion(_ r: AnchorResolution, _ candidates: [(index: Int, start: Int)]) -> AnchorResolution {
        guard let i = r.index else { return r }
        var out = r
        out.regionStart = candidates.first { $0.index == i }?.start
        return out
    }

    /// I segmenti che contengono a un'estremità il testo di lunghezza `length` con impronte di testa e coda date
    /// (vedi `containingCandidates`). `length` deve superare `edgeLength`.
    private func containers(length: Int, head: String, tail: String, page sourcePage: Int?, visualWorld: Bool) -> [Int] {
        containerPositions(length: length, head: head, tail: tail, page: sourcePage, visualWorld: visualWorld).map { $0.index }
    }

    /// Come `containers`, con la posizione (0 o in coda) dove il vecchio testo comincia nel segmento.
    private func containerPositions(length: Int, head: String, tail: String, page sourcePage: Int?,
                                    visualWorld: Bool) -> [(index: Int, start: Int)] {
        let edge = TextFingerprint.edgeLength
        var out: [(index: Int, start: Int)] = []
        let range: [Int]
        if let page = sourcePage {
            range = segments.indices.filter { i in
                guard let q = pageOf[i] else { return false }
                return abs(q - page) <= Self.partialMatchPageWindow
            }
        } else {
            range = Array(segments.indices)
        }
        for i in range where normalized[i].count >= length + Self.containedMinExtraLength
            && Self.isVisualWorld(segments[i].role) == visualWorld {
            let chars = Array(normalized[i])
            let last = chars.count - length
            for p in [0, last] where TextFingerprint.digest(chars[p..<(p + edge)]) == head
                && TextFingerprint.digest(chars[(p + length - edge)..<(p + length)]) == tail {
                out.append((i, p))
                break
            }
        }
        return out
    }

    static let noteContinuationRole = "NOTE_CONTINUATION"
    static func isNoteFamily(_ role: String) -> Bool { role == "NOTE" || role == noteContinuationRole }

    /// Per i segmenti di nota: l'impronta delle `edgeLength` lettere che cominciano a ogni INIZIO DI PAROLA, con le
    /// posizioni (nel testo normalizzato). Calcolata alla prima richiesta per quel segmento e tenuta.
    private var interiorHeadsCache: [Int: [String: [Int]]] = [:]
    private func interiorHeads(_ i: Int) -> [String: [Int]] {
        if let cached = interiorHeadsCache[i] { return cached }
        let (chars, words) = TextFingerprint.normalizeWithWordMap(segments[i].text)
        let edge = TextFingerprint.edgeLength
        var map: [String: [Int]] = [:]
        if chars.count >= edge {
            for p in 0...(chars.count - edge) where p == 0 || words[p - 1] != words[p] {
                map[TextFingerprint.digest(chars[p..<(p + edge)]), default: []].append(p)
            }
        }
        interiorHeadsCache[i] = map
        return map
    }

    /// Le note (della finestra di pagine) che contengono il testo dell'ancora in un punto qualunque, cominciando a un
    /// inizio di parola: testa trovata lì e coda alla distanza giusta. Un segmento compare una volta per ogni posizione
    /// (due posizioni nella stessa nota sono ambiguità, come due note).
    private func noteInteriorCandidates(_ anchor: ContentAnchor) -> [(index: Int, start: Int)] {
        let edge = TextFingerprint.edgeLength, L = anchor.length
        var out: [(index: Int, start: Int)] = []
        for i in segments.indices where Self.isNoteFamily(segments[i].role) && normalized[i].count > L
            && Self.inWindow(pageOf[i], of: anchor.sourcePage, Self.partialMatchPageWindow) {
            guard let positions = interiorHeads(i)[anchor.head] else { continue }
            let chars = Array(normalized[i])
            for p in positions where p + L <= chars.count
                && TextFingerprint.digest(chars[(p + L - edge)..<(p + L)]) == anchor.tail {
                out.append((i, p))
            }
        }
        return out
    }

    /// I pezzi CONSECUTIVI che, a partire da `start`, ricompongono ESATTAMENTE il testo dell'ancora: almeno due, dello
    /// stesso mondo (gli elementi dell'altro mondo frapposti, le risorse visive, si scavalcano), con la somma delle
    /// lunghezze normalizzate uguale a quella dell'ancora e l'impronta del testo ricomposto uguale alla sua impronta
    /// intera. `nil` altrimenti. Un segmento senza lettere fra i pezzi non conta (non ha testo da ricomporre).
    func splitChain(from start: Int, for anchor: ContentAnchor) -> [Int]? {
        guard anchor.length > TextFingerprint.edgeLength, segments.indices.contains(start),
              normalized[start].count < anchor.length else { return nil }
        let world = Self.isVisualWorld(segments[start].role)
        var chain: [Int] = []
        var total = 0
        var j = start
        while segments.indices.contains(j), total < anchor.length {
            if Self.isVisualWorld(segments[j].role) == world {
                let n = normalized[j].count
                if n > 0 { chain.append(j); total += n }
            }
            j += 1
        }
        guard chain.count >= 2, total == anchor.length,
              TextFingerprint.digest(chain.map { normalized[$0] }.joined()) == anchor.whole else { return nil }
        return chain
    }

    /// Gli inizi delle catene di pezzi che ricompongono il testo dell'ancora (vedi `splitChain`). Si provano i segmenti
    /// della finestra di pagine più corti dell'ancora: dove le prime `edgeLength` lettere dei pezzi consecutivi, a
    /// partire da lì, hanno l'impronta della testa dell'ancora, la catena si verifica per intero. Così si ritrovano anche
    /// le catene il cui primo pezzo è più corto della finestra di testa (una frase breve prima di una lunghissima).
    /// Pagina d'origine ignota: solo i segmenti che cominciano con la testa o finiscono con la coda.
    private func splitChainStarts(_ anchor: ContentAnchor) -> [Int] {
        guard anchor.length > TextFingerprint.edgeLength else { return [] }
        let world = Self.isVisualWorld(anchor.role)
        let edge = TextFingerprint.edgeLength
        var starts = Set<Int>()
        let candidates: [Int]
        if let page = anchor.sourcePage {
            candidates = (page - Self.partialMatchPageWindow...page + Self.partialMatchPageWindow).flatMap { segmentsByPage[$0] ?? [] }
        } else {
            candidates = (byHead[anchor.head] ?? []) + (byTail[anchor.tail] ?? []).compactMap { last in
                var total = 0, j = last
                var first: Int?
                while j >= 0, total < anchor.length {
                    if Self.isVisualWorld(segments[j].role) == world, !normalized[j].isEmpty { total += normalized[j].count; first = j }
                    j -= 1
                }
                return total == anchor.length ? first : nil
            }
        }
        for i in candidates where Self.isVisualWorld(segments[i].role) == world
            && !normalized[i].isEmpty && normalized[i].count < anchor.length {
            // Le prime `edge` lettere dei pezzi da qui in avanti.
            var prefix = ""
            var j = i
            while segments.indices.contains(j), prefix.count < edge {
                if Self.isVisualWorld(segments[j].role) == world { prefix += normalized[j] }
                j += 1
            }
            guard prefix.count >= edge, TextFingerprint.digest(prefix.prefix(edge)) == anchor.head else { continue }
            if splitChain(from: i, for: anchor) != nil { starts.insert(i) }
        }
        return starts.sorted()
    }

    /// Gli indici dei segmenti per pagina d'origine (calcolati alla prima richiesta).
    private lazy var segmentsByPage: [Int: [Int]] = {
        var m: [Int: [Int]] = [:]
        for (i, p) in pageOf.enumerated() { if let p { m[p, default: []].append(i) } }
        return m
    }()

    /// Cerca la citazione nel testo RICOMPOSTO dei pezzi `chain` (vedi `splitChain`) con le regole di `locate(_:in:)`:
    /// confini di parola (il confine fra due pezzi è un confine di parola), più posizioni → decide il contesto, ancora
    /// più d'una → `nil`. Torna uno span per pezzo toccato.
    private func locate(_ quote: QuoteAnchor, inChain chain: [Int], level: AnchorMatchLevel) -> [QuoteResolution]? {
        var chars: [Character] = []
        var piece: [Int] = []      // posizione nella catena del pezzo di ogni carattere
        var word: [Int] = []       // parola (indice WordTokenizer) nel suo pezzo
        for (k, i) in chain.enumerated() {
            let (c, w) = TextFingerprint.normalizeWithWordMap(segments[i].text)
            chars += c
            word += w
            piece += Array(repeating: k, count: c.count)
        }
        let L = quote.quoteLength
        guard L > 0, chars.count >= L else { return nil }
        func sameWord(_ a: Int, _ b: Int) -> Bool { piece[a] == piece[b] && word[a] == word[b] }
        var hits: [Int] = []
        for p in 0...(chars.count - L) {
            let startsWord = p == 0 || !sameWord(p - 1, p)
            let endsWord = p + L == chars.count || !sameWord(p + L - 1, p + L)
            guard startsWord, endsWord else { continue }
            if TextFingerprint.digest(chars[p..<(p + L)]) == quote.quote { hits.append(p) }
        }
        if hits.count > 1 {
            let ctx = TextFingerprint.contextLength
            hits = hits.filter { p in
                let before = chars[max(0, p - ctx)..<p]
                let after = chars[(p + L)..<min(chars.count, p + L + ctx)]
                let pre = before.isEmpty ? nil : TextFingerprint.digest(before)
                let suf = after.isEmpty ? nil : TextFingerprint.digest(after)
                return pre == quote.prefix && suf == quote.suffix
            }
        }
        guard hits.count == 1 else { return nil }
        let p = hits[0], q = p + L - 1
        var out: [QuoteResolution] = []
        for k in piece[p]...piece[q] {
            let first = k == piece[p] ? word[p] : (piece.firstIndex(of: k).map { word[$0] } ?? 0)
            let last = k == piece[q] ? word[q] : (piece.lastIndex(of: k).map { word[$0] } ?? 0)
            out.append(QuoteResolution(segmentIndex: chain[k], startWord: first, endWord: last, level: level))
        }
        return out
    }

    /// Vero se `text` è un PEZZO INIZIALE del vecchio segmento: più corto, lungo almeno la prima tacca
    /// della scala (128) e con il prefisso alla tacca più grande che copre uguale a quello del vecchio.
    private func isInitialPiece(_ text: String, of anchor: ContentAnchor) -> Bool {
        let n = text.count
        guard n < anchor.length, let first = Self.ladderLengths.first, n >= first else { return false }
        let k = Self.ladderLengths.lastIndex { $0 <= n } ?? 0
        guard anchor.prefixLadder.indices.contains(k) else { return false }
        return TextFingerprint.digest(text.prefix(Self.ladderLengths[k])) == anchor.prefixLadder[k]
    }

    /// Cerca la citazione nel segmento `index`: tutte le posizioni la cui finestra ha l'impronta della
    /// citazione; se più d'una, prefisso e suffisso decidono; se ancora più d'una, `nil`. Con `region`, solo nel tratto
    /// del segmento dove sta il vecchio testo, i cui bordi valgono come bordi del segmento (contesto e parole).
    private func locate(_ quote: QuoteAnchor, in index: Int, region: Range<Int>? = nil) -> (Int, Int)? {
        let (chars, words) = TextFingerprint.normalizeWithWordMap(segments[index].text)
        let L = quote.quoteLength
        let lo = max(0, region?.lowerBound ?? 0), hi = min(chars.count, region?.upperBound ?? chars.count)
        guard L > 0, hi - lo >= L else { return nil }
        var hits: [Int] = []
        // Solo a CONFINI DI PAROLA: la citazione comincia all'inizio di una parola e finisce alla fine di una
        // parola. Le stesse lettere dentro una parola più lunga non sono la citazione (revisione indipendente).
        for p in lo...(hi - L) {
            let startsWord = p == lo || words[p - 1] != words[p]
            let endsWord = p + L == hi || words[p + L - 1] != words[p + L]
            guard startsWord, endsWord else { continue }
            if TextFingerprint.digest(chars[p..<(p + L)]) == quote.quote { hits.append(p) }
        }
        if hits.count > 1 {
            let ctx = TextFingerprint.contextLength
            hits = hits.filter { p in
                let before = chars[max(lo, p - ctx)..<p]
                let after = chars[(p + L)..<min(hi, p + L + ctx)]
                let pre = before.isEmpty ? nil : TextFingerprint.digest(before)
                let suf = after.isEmpty ? nil : TextFingerprint.digest(after)
                return pre == quote.prefix && suf == quote.suffix
            }
        }
        guard hits.count == 1 else { return nil }
        let p = hits[0]
        return (words[p], words[p + L - 1])
    }
}
