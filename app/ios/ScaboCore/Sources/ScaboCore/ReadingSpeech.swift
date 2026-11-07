//
//  ReadingSpeech.swift
//  ScaboCore
//
//  LA FONTE UNICA DEL PARLATO della lettura (giro «fondamenta della lettura per Mac», 2026-11-07). Ciò che VoiceOver dice
//  di ogni elemento della lettura è logica di puro testo: la qualifica dei titoli per livello, l'introduzione delle note e
//  la sua soppressione quando suona il segnale acustico, l'introduzione dei riquadri e degli altri ruoli (portata dal
//  segmento, `acousticIntroFor`), il rinfresco di contesto, la scelta del segnale della nota e di quello della
//  bibliografia, l'appartenenza ai rotori, i nomi delle azioni disponibili sull'elemento, il valore annunciato. Fino alla
//  build 64 questa logica viveva dentro la vista UIKit dell'iPad (`ContinuousReadingView`); qui è spostata così com'era,
//  senza cambiare un byte di ciò che si pronuncia, perché la lettura del Mac la usi per costruzione e dica le stesse
//  parole dell'iPad.
//
//  Importa solo Foundation; ScaboCore non usa né UIKit né AppKit e compila per iOS e per macOS. Le viste restano padrone del
//  QUANDO (il fuoco, lo scorrimento, la materializzazione delle celle, il riproduttore audio, i gestori delle azioni): qui si
//  decide il CHE COSA.
//
//  Perimetro: gli elementi della lettura (Lettura Continua e Dottrina Inline, la stessa vista). Le righe dell'albero della
//  Consultazione Rapida (`QuickConsultView`) hanno ancora le loro etichette: allinearle cambierebbe ciò che si pronuncia (il
//  valore della risorsa visiva lì non dice «2 di 4»), quindi resta a un giro dedicato, su decisione del maintainer.
//
//  Oltre alle funzioni che la vista chiama, il modulo dà per ogni elemento una DESCRIZIONE COMPLETA E NEUTRA
//  (`ReadingElementDescription`): testo pronunciato, valore, ruolo, livello d'intestazione, segnale previsto in lettura
//  lineare, rotori in cui compare, azioni disponibili per nome, contenitore. È la moneta comune della rete sul parlato
//  (stessa lettura, prima e dopo una modifica) e del confronto fra la lettura dell'iPad e quella del Mac
//  (`ReadingDescriptionComparison`): una vista vera si descrive leggendo ciò che espone, il modulo descrive ciò che deve
//  esporre, e le due descrizioni devono coincidere al byte.
//

import Foundation

// MARK: - L'identità dei segnali acustici

/// Un segnale acustico dell'app. L'IDENTITÀ (il nome stabile) vive qui, perché la scelta del segnale di un elemento è
/// logica del parlato condivisa da iPad e Mac; il riproduttore e gli asset (`<rawValue>.mp3` nel bundle dell'app) restano
/// nelle app. Il `rawValue` è il nome del file audio senza estensione, identico ai nomi espliciti forniti dal maintainer.
public enum AudioSignal: String, CaseIterable, Sendable {

    // ── Sei segnali-nota, incisività crescente, sui sei regimi `length_category` (LAYER2 § 10.4) ──
    /// Regime MICRO (nota brevissima).
    case noteMicro = "very-brief"
    /// Regime SHORT.
    case noteShort = "brief"
    /// Regime MEDIUM.
    case noteMedium = "medium"
    /// Regime LONG.
    case noteLong = "long"
    /// Regime VERY_LONG.
    case noteVeryLong = "very-long"
    /// Regime MEGA (mini-saggio).
    case noteMega = "ultra-long"

    // ── Segnale di blocco bibliografico ──
    /// Earcon che PRECEDE un blocco di testo bibliografico (ruolo `LETTERATURA`): non un annuncio parlato, solo l'effetto
    /// sonoro all'ingresso del blocco, una volta sola (vedi `ReadingSpeech.focusSignals`).
    case bibliography = "bibliography"

    // ── Segnali di stato dell'app ──
    /// Import/estrazione/elaborazione in corso (schermata di elaborazione).
    case loading
    /// Elaborazione completata con successo.
    case completion
    /// Errore generale (import/estrazione/elaborazione andati male).
    case error
    /// Annuncio generale (predisposto).
    case announcement

    // ── Segnali di attivazione di Layout ──
    /// Attivazione del Layout Lettura Continua.
    case mode1 = "mode-1"
    /// Attivazione del Layout Consultazione Rapida (dormiente).
    case mode2 = "mode-2"
    /// Attivazione del Layout Dottrina Inline.
    case mode3 = "mode-3"
    /// Attivazione/disattivazione dello split screen iPad (dormiente).
    case splitScreen = "split-screen"

    // ── Extra per necessità future (identificati, non cablati) ──
    case extra1 = "extra-1"
    case extra2 = "extra-2"

    /// Il segnale-nota corrispondente a un regime di lunghezza, o `nil` se la categoria non è uno dei sei regimi (stringa
    /// vuota per i non-NOTE, o categorie senza segnale come l'EDITORIAL_NOTE). In ordine di incisività crescente.
    public static func noteSignal(forLengthCategory category: String) -> AudioSignal? {
        switch category {
        case LengthCategory.MICRO.rawValue: return .noteMicro
        case LengthCategory.SHORT.rawValue: return .noteShort
        case LengthCategory.MEDIUM.rawValue: return .noteMedium
        case LengthCategory.LONG.rawValue: return .noteLong
        case LengthCategory.VERY_LONG.rawValue: return .noteVeryLong
        case LengthCategory.MEGA.rawValue: return .noteMega
        default: return nil
        }
    }
}

// MARK: - Ruolo, contenitore, rotori, azioni (vocabolario neutro)

/// Il ruolo di accessibilità di un elemento della lettura, in parole neutre rispetto alla piattaforma. Oggi uno solo: ogni
/// elemento è testo statico. Le celle-titolo NON portano il tratto di intestazione, di proposito: il rotore Intestazioni
/// incorporato di VoiceOver vede solo la finestra di celle vive e salterebbe i titoli fuori finestra; la navigazione per
/// titoli passa interamente ai rotori su misura (`ReadingRotor`), e la qualifica di intestazione è nel parlato.
public enum ReadingElementRole: String, Sendable {
    case staticText = "testo statico"
}

/// Il contenitore di accessibilità a cui un elemento della lettura appartiene (LAYER2 § 2.3): il testo del documento,
/// chiuso e separato da quello dell'interfaccia.
public enum ReadingContainer: String, Sendable {
    case text = "testo"
}

/// Un rotore della lettura. I primi quattro sono tipi di sistema (VoiceOver li nomina da sé); quello della ricerca ha un
/// nome nostro.
public enum ReadingRotor: Hashable, Sendable {
    /// «Risultati della ricerca» (§ 13.3), solo con una ricerca attiva: il primo della lista.
    case searchResults
    /// Intestazioni, tutti i livelli in sequenza (tipo di sistema `.heading`): c'è sempre.
    case headings
    /// Intestazioni di un livello (tipo di sistema `.headingLevelN`), solo per i livelli presenti.
    case headingLevel(Int)
    /// Tabelle (tipo di sistema `.table`), solo se il documento ne ha.
    case tables
    /// Immagini (tipo di sistema `.image`): le figure, solo se il documento ne ha.
    case images

    /// Il codice neutro della descrizione.
    public var code: String {
        switch self {
        case .searchResults: return "risultati-ricerca"
        case .headings: return "titoli"
        case .headingLevel(let n): return "titoli-\(n)"
        case .tables: return "tabelle"
        case .images: return "immagini"
        }
    }
}

/// Un'azione disponibile su un elemento della lettura. Il NOME è ciò che VoiceOver pronuncia; il bersaglio, dove c'è, è
/// l'indice dell'elemento in cui l'azione porta. I gestori vivono nella vista.
public enum ReadingAction: Equatable, Sendable {
    /// «Estrai come immagine» (risorsa visiva, § 7.9).
    case extractVisualResource
    /// «Salta la risorsa»: porta all'elemento dopo il testo della risorsa.
    case skipVisualResource(target: Int)
    /// «Vai al testo del richiamo» (sulla nota, § 7.12).
    case goToCall(target: Int)
    /// «Vai alla nota N» (sul testo che richiama la nota; «Vai alla nota» se il numero non si legge).
    case goToNote(target: Int, number: String)
    /// «Aggiungi segnalibro» (§ 5.1).
    case addBookmark
    /// «Modifica segnalibro».
    case editBookmark
    /// «Rimuovi segnalibro».
    case removeBookmark
    /// «Strumenti elemento»: segnalibro e sottolineatura per le tecnologie assistive diverse da VoiceOver (Controllo
    /// vocale, Controllo interruttori, tastiera completa), che non hanno il tocco prolungato. Mai con VoiceOver acceso.
    case elementTools

    /// Dove porta l'azione (l'indice dell'elemento d'arrivo) per le azioni di navigazione; `nil` per le altre.
    public var target: Int? {
        switch self {
        case .skipVisualResource(let t), .goToCall(let t): return t
        case .goToNote(let t, _): return t
        case .extractVisualResource, .addBookmark, .editBookmark, .removeBookmark, .elementTools: return nil
        }
    }

    /// Il nome pronunciato.
    public var name: String {
        switch self {
        case .extractVisualResource: return "Estrai come immagine"
        case .skipVisualResource: return "Salta la risorsa"
        case .goToCall: return "Vai al testo del richiamo"
        case .goToNote(_, let number): return number.isEmpty ? "Vai alla nota" : "Vai alla nota \(number)"
        case .addBookmark: return "Aggiungi segnalibro"
        case .editBookmark: return "Modifica segnalibro"
        case .removeBookmark: return "Rimuovi segnalibro"
        case .elementTools: return "Strumenti elemento"
        }
    }
}

/// Lo stato dei segnalibri di un elemento, per le azioni che gli si offrono.
public enum ReadingBookmarkState: Sendable {
    /// Nessuno strumento di segnalibro (nessun coordinatore: solo i test): nessuna azione di segnalibro.
    case unavailable
    /// L'elemento non ha segnalibri.
    case absent
    /// L'elemento ha un segnalibro.
    case present
}

/// Le impostazioni che cambiano ciò che VoiceOver dice o offre su un elemento.
public struct ReadingSpeechSettings: Equatable, Sendable {
    /// «Note annunciate a voce» (mai-solo-suono): l'introduzione della nota resta nel parlato e il segnale della nota tace.
    public var noteSpokenLabels: Bool
    /// VoiceOver acceso: l'azione «Strumenti elemento» (per le altre tecnologie assistive) non si offre.
    public var voiceOverRunning: Bool

    public init(noteSpokenLabels: Bool = false, voiceOverRunning: Bool = false) {
        self.noteSpokenLabels = noteSpokenLabels
        self.voiceOverRunning = voiceOverRunning
    }
}

// MARK: - Le funzioni del parlato (spostate dalla vista dell'iPad, invariate)

public enum ReadingSpeech {

    /// Il nome del rotore della ricerca nel libro (VoiceOver lo dice ruotando).
    public static let searchRotorName = "Risultati della ricerca"

    /// L'annuncio del salto fra nota e richiamo da tastiera (⌘J) quando dall'elemento in lettura non c'è nulla da raggiungere.
    public static let noNoteOrCallToReach = "Qui non c'è una nota né un richiamo da raggiungere."

    /// Il ruolo di ogni elemento della lettura (vedi `ReadingElementRole`).
    public static func role(for segment: ContentSegment) -> ReadingElementRole { .staticText }

    /// Il contenitore di ogni elemento della lettura.
    public static func container(for segment: ContentSegment) -> ReadingContainer { .text }

    /// Testo che VoiceOver pronuncia: intro acustica (se presente) + rinfresco di contesto + testo.
    public static func spokenText(for segment: ContentSegment) -> String {
        spoken(intro: segment.acousticIntro, segment: segment)
    }

    /// L'etichetta accessibile INTESA per un segmento — l'unica fonte del parlato (byte-identica con o senza
    /// sottolineature, rete A). Una nota vera col segnale acustico perde solo l'intro verbale (§ 10.4): di default l'intro
    /// la porta l'earcon; con l'opzione «note annunciate a voce» (`restoreNoteIntro`) l'intro «Nota.»/«Nota lunga.» resta
    /// nell'etichetta, così un display braille o chi non sente la riceve come testo.
    public static func intendedAccessibilityLabel(for segment: ContentSegment, restoreNoteIntro: Bool = false) -> String {
        let base = (noteSignal(for: segment) == nil || restoreNoteIntro)
            ? spokenText(for: segment)
            : spoken(intro: "", segment: segment)
        // La qualifica di intestazione NEL PARLATO: le celle non portano il tratto di intestazione (vedi
        // `ReadingElementRole`), quindi l'orecchio in lettura lineare riceve «è un titolo, di livello N» da qui.
        let qualifier = headingQualifier(for: segment.role)
        return qualifier.isEmpty ? base : "\(qualifier) \(base)"
    }

    /// Qualifica parlata anteposta a un titolo, per LIVELLO reale (dal ruolo prodotto dalla classificazione).
    /// `ARTICLE_HEADER` → «Articolo.» (l'articolo dei codici); HEADING_1…4 → «Intestazione di livello N.». Vuota per i
    /// non-titoli e per `SECTION_DIVIDER`, che ha già il suo intro «Sezione.» e resta fuori dal rotore.
    public static func headingQualifier(for role: String) -> String {
        switch role {
        case "ARTICLE_HEADER": return "Articolo."
        case "HEADING_1": return "Intestazione di livello 1."
        case "HEADING_2": return "Intestazione di livello 2."
        case "HEADING_3": return "Intestazione di livello 3."
        case "HEADING_4": return "Intestazione di livello 4."
        default: return ""
        }
    }

    /// Compone `[intro] [rinfresco] [testo]`, scartando le parti vuote. Il testo è sempre presente.
    public static func spoken(intro: String, segment: ContentSegment) -> String {
        [intro, segment.memoryRefresh, segment.text]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// Il segnale-nota per il segmento, o `nil` se non è una nota vera con regime (una NOTE con l'intro acustica; le
    /// false note dei titoli collassati hanno l'intro tolta e nessun segnale).
    public static func noteSignal(for segment: ContentSegment) -> AudioSignal? {
        guard segment.role == SemanticCategory.NOTE.rawValue,
              !segment.acousticIntro.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return nil }
        return AudioSignal.noteSignal(forLengthCategory: segment.lengthCategory)
    }

    /// I segnali da suonare quando il fuoco arriva su un elemento, nell'ordine: il segnale della nota (taciuto con «note
    /// annunciate a voce»: l'identità della nota è già nel parlato, niente doppio segnale) e quello della bibliografia, una
    /// volta all'INGRESSO di un blocco `LETTERATURA` (non a ogni voce adiacente). `previousFocusedRole` è il ruolo
    /// dell'elemento che aveva il fuoco prima (`nil` se nessuno).
    public static func focusSignals(
        for segment: ContentSegment, previousFocusedRole: String?, noteSpokenLabels: Bool
    ) -> [AudioSignal] {
        var signals: [AudioSignal] = []
        if !noteSpokenLabels, let note = noteSignal(for: segment) { signals.append(note) }
        if segment.role == SemanticCategory.LETTERATURA.rawValue, previousFocusedRole != segment.role {
            signals.append(.bibliography)
        }
        return signals
    }

    /// Vero per i ruoli da trattare come intestazione nella struttura (unità strutturali, colore dei titoli).
    public static func isHeadingRole(_ role: String) -> Bool {
        role.hasPrefix("HEADING_") || role == SECTION_DIVIDER_ROLE || role == "ARTICLE_HEADER"
    }

    /// Livello (1…5) del ruolo se è un'intestazione navigabile dai rotori, o `nil`. HEADING_1…4 → 1…4; ARTICLE_HEADER
    /// (l'articolo dei codici, sotto le quattro divisioni) → 5. `SECTION_DIVIDER` (contenitore editoriale sintetico del
    /// backend AKN) è escluso di proposito dai rotori.
    public static func headingLevel(for role: String) -> Int? {
        switch role {
        case "HEADING_1": return 1
        case "HEADING_2": return 2
        case "HEADING_3": return 3
        case "HEADING_4": return 4
        case "ARTICLE_HEADER": return 5
        default: return nil
        }
    }
}

// MARK: - Il modello del parlato di un libro

/// Una voce dell'indice leggero dei titoli: indice di lettura e livello.
public struct ReadingHeadingEntry: Equatable, Sendable {
    public let index: Int
    public let level: Int
}

/// Una voce dell'indice leggero delle risorse visive: indice di lettura e tipo.
public struct ReadingVisualEntry: Equatable, Sendable {
    public let index: Int
    public let kind: VisualResourceKind
}

/// Il parlato di un flusso di lettura (Lettura Continua o Dottrina Inline): gli indici leggeri dei titoli e delle risorse
/// visive, i legami nota↔richiamo, e per ogni elemento valore, rotori e azioni. Lo costruisce la vista a ogni resa (e lo
/// costruirà la vista del Mac); costa una passata sui segmenti più il calcolo dei legami, come prima nella vista.
public struct ReadingSpeechModel: Sendable {
    public let segments: [ContentSegment]
    /// Legami nota ↔ segmento del richiamo (§ 7.12), con le opzioni del libro (le cure mirate per impronta, § 0-ter).
    public let noteLinks: NoteCallLinks
    /// I titoli in ordine di lettura (anche fuori dalla finestra di celle vive): ciò che i rotori dei titoli percorrono.
    public let headingIndex: [ReadingHeadingEntry]
    /// Le risorse visive in ordine di lettura: ciò che i rotori Tabelle e Immagini percorrono.
    public let visualIndex: [ReadingVisualEntry]

    public init(segments: [ContentSegment], noteJumpOptions: NoteJumpOptions = NoteJumpOptions()) {
        self.segments = segments
        self.noteLinks = noteCallLinks(segments, options: noteJumpOptions)
        self.headingIndex = segments.enumerated().compactMap { i, s in
            ReadingSpeech.headingLevel(for: s.role).map { ReadingHeadingEntry(index: i, level: $0) }
        }
        self.visualIndex = segments.enumerated().compactMap { i, s in
            s.visualResource.map { ReadingVisualEntry(index: i, kind: $0.kind) }
        }
    }

    /// Il modello vuoto (nessun segmento).
    public static let empty = ReadingSpeechModel(segments: [])

    // MARK: Rotori

    /// I livelli di intestazione presenti, in ordine: un rotore per livello solo per i livelli che esistono.
    public var headingLevelsPresent: [Int] { Array(Set(headingIndex.map { $0.level })).sorted() }

    /// I rotori installati sul contenitore del testo, nell'ordine in cui VoiceOver li offre: la ricerca (se attiva) per
    /// prima, le Intestazioni sempre, un rotore per livello presente, Tabelle e Immagini se il documento ne ha.
    public func installedRotors(searchActive: Bool) -> [ReadingRotor] {
        var rotors: [ReadingRotor] = [.headings]
        for level in headingLevelsPresent { rotors.append(.headingLevel(level)) }
        if visualIndex.contains(where: { $0.kind == .table }) { rotors.append(.tables) }
        if visualIndex.contains(where: { $0.kind == .figure }) { rotors.append(.images) }
        if searchActive { rotors.insert(.searchResults, at: 0) }
        return rotors
    }

    /// I rotori in cui compare l'elemento all'indice dato, nell'ordine dei rotori installati.
    public func rotors(ofElementAt index: Int, search: BookSearchResult? = nil) -> [ReadingRotor] {
        guard index >= 0, index < segments.count else { return [] }
        let active = Self.activeSearch(search)
        var out: [ReadingRotor] = []
        if let active, active.elementIndices.contains(index) { out.append(.searchResults) }
        if let level = ReadingSpeech.headingLevel(for: segments[index].role) {
            out.append(.headings)
            out.append(.headingLevel(level))
        }
        if let kind = segments[index].visualResource?.kind { out.append(kind == .table ? .tables : .images) }
        return out
    }

    /// La ricerca da considerare attiva: una con almeno un elemento, altrimenti nessuna (niente rotore né valori).
    public static func activeSearch(_ search: BookSearchResult?) -> BookSearchResult? {
        (search?.elementIndices.isEmpty == false) ? search : nil
    }

    /// Indice del titolo successivo (`forward`) o precedente rispetto a `current`, filtrato per `level` (nil = qualsiasi).
    public func nextHeadingIndex(from current: Int, level: Int?, forward: Bool) -> Int? {
        let candidates = level == nil ? headingIndex : headingIndex.filter { $0.level == level }
        return forward
            ? candidates.first(where: { $0.index > current })?.index
            : candidates.last(where: { $0.index < current })?.index
    }

    /// Indice della risorsa visiva del tipo dato successiva (o precedente) a `current`.
    public func nextVisualIndex(from current: Int, kind: VisualResourceKind, forward: Bool) -> Int? {
        let candidates = visualIndex.filter { $0.kind == kind }
        return forward ? candidates.first(where: { $0.index > current })?.index : candidates.last(where: { $0.index < current })?.index
    }

    // MARK: Valore

    /// Il valore annunciato sull'elemento «risorsa visiva»: «pagina N del file originale» (la pagina vera della regione) e,
    /// se la pagina ha più risorse, quale («2 di 4», nell'ordine del flusso). `nil` per ogni altro elemento.
    public func visualResourceValue(forIndex index: Int) -> String? {
        guard index >= 0, index < segments.count, let payload = segments[index].visualResource else { return nil }
        let samePage = visualIndex.filter { segments[$0.index].visualResource?.pageIndex == payload.pageIndex }
        var value = "pagina \(payload.pageIndex + 1) del file originale"
        if samePage.count > 1, let k = samePage.firstIndex(where: { $0.index == index }) {
            value += ", \(k + 1) di \(samePage.count)"
        }
        return value
    }

    /// Il valore della ricerca attiva sull'elemento che contiene risultati («risultato 4 di 12»), o `nil`.
    public func searchValue(forIndex index: Int, search: BookSearchResult?) -> String? {
        guard let r = Self.activeSearch(search), let ordinals = r.ordinals(inElement: index) else { return nil }
        return BookSearchWording.positionValue(ordinals: ordinals, total: r.totalCount)
    }

    /// Il valore annunciato dall'elemento: quello della ricerca, altrimenti quello della risorsa visiva (le risorse visive
    /// non si cercano, quindi i due non si incontrano), altrimenti nessuno.
    public func value(forIndex index: Int, search: BookSearchResult? = nil) -> String? {
        searchValue(forIndex: index, search: search) ?? visualResourceValue(forIndex: index)
    }

    // MARK: Azioni

    /// L'elemento subito dopo il testo della risorsa all'indice dato: si contano `containedElements` elementi di testo
    /// dopo di lei, poi il primo che segue. Un'altra risorsa annunciata subito dopo di lei si scavalca; ma se l'annuncio di
    /// un'altra risorsa cade DENTRO il suo testo, il salto si ferma su quell'annuncio.
    public func indexAfterVisualResource(at index: Int) -> Int {
        guard index >= 0, index < segments.count, let payload = segments[index].visualResource else { return index }
        var i = index + 1, counted = 0
        while i < segments.count && counted < payload.containedElements {
            if segments[i].visualResource == nil { counted += 1 } else if counted > 0 { return i }
            i += 1
        }
        return min(i, max(0, segments.count - 1))
    }

    /// Le azioni della risorsa visiva (§ 7.9): «Estrai come immagine» sempre; «Salta la risorsa» solo se la regione
    /// contiene testo, che resta comunque nel flusso subito dopo (saltarlo è una scelta, non un obbligo).
    public func visualResourceActions(forIndex index: Int) -> [ReadingAction] {
        guard index >= 0, index < segments.count, let payload = segments[index].visualResource else { return [] }
        var actions: [ReadingAction] = [.extractVisualResource]
        if payload.containedElements > 0 { actions.append(.skipVisualResource(target: indexAfterVisualResource(at: index))) }
        return actions
    }

    /// Le azioni di salto nota ↔ testo (§ 7.12): sulla nota «Vai al testo del richiamo»; sul blocco che richiama note
    /// «Vai alla nota N» (una per nota). Nessun legame riscontrato → nessuna azione.
    public func noteJumpActions(forIndex index: Int) -> [ReadingAction] {
        var actions: [ReadingAction] = []
        if let call = noteLinks.callOfNote[index] { actions.append(.goToCall(target: call)) }
        for note in noteLinks.notesOfCall[index] ?? [] where note < segments.count {
            let number = segments[note].text.prefix(while: { $0.isNumber || $0 == "(" || $0 == ")" })
                .filter { $0.isNumber }
            actions.append(.goToNote(target: note, number: number))
        }
        return actions
    }

    /// Il bersaglio del salto fra nota e richiamo da tastiera (⌘J) dall'elemento all'indice dato: sulla nota, il testo del
    /// richiamo; sul testo che richiama, la prima delle sue note; altrimenti nessuno. È ciò che fanno le azioni «Vai al testo
    /// del richiamo» e «Vai alla nota N» (la prima).
    public func noteCallJumpTarget(from index: Int) -> Int? {
        if let call = noteLinks.callOfNote[index] { return call }
        if let note = noteLinks.notesOfCall[index]?.first, note < segments.count { return note }
        return nil
    }

    /// Le azioni di segnalibro (§ 5.1) secondo lo stato.
    public static func bookmarkActions(_ state: ReadingBookmarkState) -> [ReadingAction] {
        switch state {
        case .unavailable: return []
        case .absent: return [.addBookmark]
        case .present: return [.editBookmark, .removeBookmark]
        }
    }

    /// Tutte le azioni dell'elemento, nell'ordine in cui VoiceOver le offre: risorsa visiva, salti nota↔richiamo,
    /// segnalibro, e «Strumenti elemento» solo a VoiceOver spento. La sottolineatura è dichiarata solo-vedenti (§ 6):
    /// VoiceOver non la offre fra le sue azioni.
    public func actions(
        forIndex index: Int, bookmark: ReadingBookmarkState, settings: ReadingSpeechSettings
    ) -> [ReadingAction] {
        // Nessun controllo dell'indice qui, come nella vista di prima: le azioni di segnalibro e «Strumenti elemento» non
        // dipendono dall'indice; quelle della risorsa visiva e dei salti si controllano da sé.
        var actions = visualResourceActions(forIndex: index)
        actions += noteJumpActions(forIndex: index)
        actions += Self.bookmarkActions(bookmark)
        if !settings.voiceOverRunning { actions.append(.elementTools) }
        return actions
    }

    // MARK: Descrizione

    /// La descrizione completa e neutra di ogni elemento del flusso, in ordine di lettura, con le impostazioni date. Il
    /// segnale è quello previsto in LETTURA LINEARE IN AVANTI (il fuoco arriva su ogni elemento dal precedente, il primo
    /// senza precedente). `bookmarkedSegmentIds`: gli elementi con un segnalibro; `bookmarksAvailable` falso = nessuno
    /// strumento di segnalibro.
    public func describe(
        book: String, layout: ReadingLayoutCode, settings: ReadingSpeechSettings,
        bookmarkedSegmentIds: Set<String> = [], bookmarksAvailable: Bool = true, search: BookSearchResult? = nil
    ) -> ReadingDescription {
        let active = Self.activeSearch(search)
        let header = ReadingDescriptionHeader(
            book: book, layout: layout.rawValue, noteSpokenLabels: settings.noteSpokenLabels,
            voiceOverRunning: settings.voiceOverRunning, elementCount: segments.count,
            rotors: installedRotors(searchActive: active != nil).map(\.code))
        var elements: [ReadingElementDescription] = []
        elements.reserveCapacity(segments.count)
        var previousRole: String? = nil
        for (i, s) in segments.enumerated() {
            let bookmark: ReadingBookmarkState = !bookmarksAvailable ? .unavailable
                : (bookmarkedSegmentIds.contains(s.id) ? .present : .absent)
            let signals = ReadingSpeech.focusSignals(
                for: s, previousFocusedRole: previousRole, noteSpokenLabels: settings.noteSpokenLabels)
            let acts = actions(forIndex: i, bookmark: bookmark, settings: settings)
            elements.append(ReadingElementDescription(
                index: i, segmentId: s.id,
                spokenText: ReadingSpeech.intendedAccessibilityLabel(for: s, restoreNoteIntro: settings.noteSpokenLabels),
                value: value(forIndex: i, search: active),
                role: ReadingSpeech.role(for: s).rawValue,
                headingLevel: ReadingSpeech.headingLevel(for: s.role),
                signal: ReadingElementDescription.signalCode(signals),
                rotors: rotors(ofElementAt: i, search: active).map(\.code),
                actions: acts.map(\.name), actionTargets: acts.map(\.target),
                container: ReadingSpeech.container(for: s).rawValue))
            previousRole = s.role
        }
        return ReadingDescription(header: header, elements: elements)
    }
}

// MARK: - La descrizione neutra (rete sul parlato, confronto iPad-Mac)

/// Il layout di cui è descritto il flusso.
public enum ReadingLayoutCode: String, Sendable {
    case continuousReading = "lettura-continua"
    case doctrineInline = "dottrina-inline"
}

/// La testata di una descrizione: di che libro, quale flusso, con quali impostazioni, quanti elementi e quali rotori.
public struct ReadingDescriptionHeader: Codable, Equatable, Sendable {
    public var format: String
    public var version: Int
    public var book: String
    public var layout: String
    public var noteSpokenLabels: Bool
    public var voiceOverRunning: Bool
    public var elementCount: Int
    public var rotors: [String]

    public static let formatName = "descrizione-lettura-scabopdf"
    /// Versione 2 (giro «fondamenta della lettura per Mac», dopo la revisione indipendente): le azioni portano anche il loro
    /// bersaglio (`bersagli`), così un salto che cambia destinazione non passa inosservato.
    public static let currentVersion = 2

    public init(book: String, layout: String, noteSpokenLabels: Bool, voiceOverRunning: Bool, elementCount: Int,
                rotors: [String]) {
        self.format = Self.formatName; self.version = Self.currentVersion
        self.book = book; self.layout = layout; self.noteSpokenLabels = noteSpokenLabels
        self.voiceOverRunning = voiceOverRunning; self.elementCount = elementCount; self.rotors = rotors
    }

    enum CodingKeys: String, CodingKey {
        case format = "formato", version = "versione", book = "libro", layout, noteSpokenLabels = "noteAVoce",
             voiceOverRunning = "voiceOverAcceso", elementCount = "elementi", rotors = "rotori"
    }
}

/// La descrizione completa e neutra di UN elemento della lettura: ciò che VoiceOver ne dice e ciò che ne offre.
public struct ReadingElementDescription: Codable, Equatable, Sendable {
    /// Indice nell'ordine di lettura.
    public var index: Int
    /// Identità del segmento (per allineare due descrizioni; non è pronunciata).
    public var segmentId: String
    /// L'etichetta pronunciata.
    public var spokenText: String
    /// Il valore pronunciato dopo l'etichetta, se c'è.
    public var value: String?
    /// Il ruolo di accessibilità (`ReadingElementRole`).
    public var role: String
    /// Il livello d'intestazione (1…5) se l'elemento è un titolo dei rotori, altrimenti nessuno.
    public var headingLevel: Int?
    /// Il segnale acustico previsto al fuoco in lettura lineare in avanti (nomi di `AudioSignal`, uniti da «+» se più
    /// d'uno), o nessuno.
    public var signal: String?
    /// I rotori in cui l'elemento compare (codici di `ReadingRotor`).
    public var rotors: [String]
    /// Le azioni disponibili, per nome, nell'ordine offerto.
    public var actions: [String]
    /// Per ogni azione, nello stesso ordine, l'indice dell'elemento in cui porta (le azioni di navigazione: salti nota ↔
    /// richiamo, «Salta la risorsa»), o nessuno.
    public var actionTargets: [Int?]
    /// Il contenitore di accessibilità (`ReadingContainer`).
    public var container: String

    public init(index: Int, segmentId: String, spokenText: String, value: String?, role: String, headingLevel: Int?,
                signal: String?, rotors: [String], actions: [String], actionTargets: [Int?], container: String) {
        self.index = index; self.segmentId = segmentId; self.spokenText = spokenText; self.value = value
        self.role = role; self.headingLevel = headingLevel; self.signal = signal; self.rotors = rotors
        self.actions = actions; self.actionTargets = actionTargets; self.container = container
    }

    /// Il codice del segnale per una lista di segnali (nessuno → `nil`).
    public static func signalCode(_ signals: [AudioSignal]) -> String? {
        signals.isEmpty ? nil : signals.map(\.rawValue).joined(separator: "+")
    }

    enum CodingKeys: String, CodingKey {
        case index = "i", segmentId = "id", spokenText = "testo", value = "valore", role = "ruolo",
             headingLevel = "livello", signal = "segnale", rotors = "rotori", actions = "azioni",
             actionTargets = "bersagli", container = "contenitore"
    }
}

/// Una descrizione intera: la testata e gli elementi in ordine.
public struct ReadingDescription: Equatable, Sendable {
    public var header: ReadingDescriptionHeader
    public var elements: [ReadingElementDescription]

    public init(header: ReadingDescriptionHeader, elements: [ReadingElementDescription]) {
        self.header = header; self.elements = elements
    }

    /// La forma su file: JSON a righe (la testata, poi un elemento per riga), chiavi ordinate, barre non protette, una
    /// riga vuota mai. Due descrizioni uguali danno gli stessi byte su iOS e su macOS.
    public func encoded() throws -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        var out = Data()
        out.append(try enc.encode(header)); out.append(0x0A)
        for e in elements { out.append(try enc.encode(e)); out.append(0x0A) }
        return out
    }

    /// Legge la forma su file. Errore se la testata manca o non è del formato atteso, o se una riga non si legge.
    public static func decode(_ data: Data) throws -> ReadingDescription {
        let dec = JSONDecoder()
        var lines = data.split(separator: 0x0A, omittingEmptySubsequences: true)
        guard !lines.isEmpty else { throw ReadingDescriptionError.missingHeader }
        let header = try dec.decode(ReadingDescriptionHeader.self, from: Data(lines.removeFirst()))
        guard header.format == ReadingDescriptionHeader.formatName else { throw ReadingDescriptionError.wrongFormat(header.format) }
        var elements: [ReadingElementDescription] = []
        elements.reserveCapacity(lines.count)
        for (k, line) in lines.enumerated() {
            do { elements.append(try dec.decode(ReadingElementDescription.self, from: Data(line))) }
            catch { throw ReadingDescriptionError.unreadableLine(k + 2) }
        }
        return ReadingDescription(header: header, elements: elements)
    }
}

/// Gli errori di lettura di una descrizione su file.
public enum ReadingDescriptionError: Error, Equatable {
    case missingHeader
    case wrongFormat(String)
    case unreadableLine(Int)
}
