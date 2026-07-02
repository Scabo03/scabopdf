//
//  Library.swift
//  ScaboCore
//
//  Il modello dati e la LOGICA della libreria del Layer 2 (§ 12 del documento di prodotto):
//  l'archivio dei documenti elaborati, i contenitori organizzativi (workspace → cartella →
//  sottocartella), le collocazioni, i recenti, e lo stato di lettura per documento (§ 2.5).
//
//  ── Perché vive in ScaboCore (pura logica, nessun UIKit) ─────────────────────────────────────
//
//  Esattamente come `Preferences.swift`, qui non si tocca lo schermo né il filesystem reale: la
//  persistenza concreta è dietro il confine `LibraryPersisting`, così le regole — id stabili,
//  ordine dei recenti, distinzione archivio/collocazione (§ 12.6), eliminazione su due livelli
//  (§ 12.7), riapertura al punto di lettura (§ 2.5) — sono verificabili in memoria su `swift test`,
//  senza Simulator. L'app inietta un `FileLibraryPersistence` (JSON in Application Support); i test
//  iniettano `InMemoryLibraryPersistence`.
//
//  ── Modello archivio / collocazioni (§ 12.6, inderogabile) ───────────────────────────────────
//
//  Il FILE è un'entità unica nell'archivio (`ArchivedDocument`): vi entra all'importazione e vi
//  resta. Segnalibri, sottolineature, posizione di lettura sono dati personali UNICI del file, mai
//  divisi fra collocazioni. I contenitori (workspace/cartelle/sottocartelle) contengono COLLOCAZIONI
//  — semplici riferimenti all'id del documento — non i file. "Aggiungi file" crea una collocazione
//  in più; "Sposta" sposta una collocazione esistente senza duplicarla; eliminare una collocazione
//  non tocca l'archivio (il file resta trovabile dalla Ricerca); l'eliminazione definitiva è solo
//  dall'archivio (§ 12.7) e porta via tutte le collocazioni.
//

import Foundation

// MARK: - Documento d'archivio

/// Un documento elaborato presente nell'archivio. È l'entità UNICA del file (§ 12.6): porta i suoi
/// dati personali (per ora la posizione di lettura; segnalibri e sottolineature arriveranno) e il
/// referto di elaborazione (warning in prosa, § 12.10).
public struct ArchivedDocument: Codable, Equatable, Sendable {
    /// Identità stabile del documento (UUID), indipendente dal nome e dalle collocazioni.
    public var id: String
    /// Nome visualizzato, modificabile dall'utente (default: nome del file senza estensione).
    public var title: String
    /// Nome del file PDF di origine, conservato per il referto e la citazione.
    public var sourceFileName: String
    /// Quando il file è stato importato (per l'ordinamento "data di importazione", § 12.3).
    public var importedAt: Date
    /// Ultima apertura (per i Recenti, § 12.1, e per l'ordinamento "data di modifica"). `nil` finché
    /// non è mai stato aperto.
    public var lastOpenedAt: Date?
    /// Numero di pagine del PDF di origine (informazione di referto/citazione).
    public var sourcePageCount: Int
    /// Posizione di lettura ricordata (§ 2.5): indice 0-based dell'elemento (segmento) nel flusso
    /// continuo del documento. 0 = inizio. È stabile perché la pipeline è deterministica.
    public var readingPosition: Int
    /// Referto di elaborazione permanente (§ 12.10): i warning in prosa accumulati all'importazione.
    public var warnings: [String]

    /// Nascosto dalla sezione Recenti della Home ("Rimuovi dai recenti"): operazione di SOLA LISTA,
    /// non distruttiva. Il file resta nell'archivio e in ogni collocazione, e `readingPosition`
    /// resta intatta. È OPZIONALE di proposito: una libreria salvata da una versione precedente non
    /// ha la chiave, e `nil` (come `false`) significa "visibile nei recenti" — così l'aggiunta del
    /// campo NON rompe la decodifica delle librerie esistenti. Riaprendo il documento il flag si
    /// riazzera (vedi `recordOpened`), perché un documento appena aperto è di nuovo recente.
    public var isHiddenFromRecents: Bool?

    /// I segnalibri del documento (§ 5.1), dati personali UNICI del file (§ 12.6). OPZIONALE per la
    /// stessa ragione di `isHiddenFromRecents`: una libreria di una versione precedente non ha la
    /// chiave, e `nil` significa "nessun segnalibro" senza rompere la decodifica delle librerie
    /// esistenti (retro-compatibilità additiva). I tag associati sono id nello spazio GLOBALE dei
    /// tag (`LibraryState.tags`): il segnalibro porta solo i riferimenti, mai copie del nome.
    public var bookmarks: [Bookmark]?

    /// Le sottolineature del documento (§ 6): strumento SOLO-VISIVO e SOLO-VEDENTI (decisione di
    /// prodotto), dati personali UNICI del file (§ 12.6). OPZIONALE per la stessa ragione di
    /// `bookmarks`: `nil` = nessuna sottolineatura, e l'assenza della chiave non rompe la decodifica
    /// delle librerie di versioni precedenti (retro-compatibilità additiva → nessun reset).
    public var underlines: [Underline]?

    public init(
        id: String,
        title: String,
        sourceFileName: String,
        importedAt: Date,
        lastOpenedAt: Date? = nil,
        sourcePageCount: Int,
        readingPosition: Int = 0,
        warnings: [String] = [],
        isHiddenFromRecents: Bool? = nil,
        bookmarks: [Bookmark]? = nil,
        underlines: [Underline]? = nil
    ) {
        self.id = id
        self.title = title
        self.sourceFileName = sourceFileName
        self.importedAt = importedAt
        self.lastOpenedAt = lastOpenedAt
        self.sourcePageCount = sourcePageCount
        self.readingPosition = readingPosition
        self.warnings = warnings
        self.isHiddenFromRecents = isHiddenFromRecents
        self.bookmarks = bookmarks
        self.underlines = underlines
    }
}

// MARK: - Segnalibro (§ 5.1) e Tag (§ 5.2)

/// Un segnalibro marca un SINGOLO elemento del documento accessibile via swipe (§ 5.1): un comma,
/// un paragrafo, una nota, qualunque elemento. Porta un nome scelto dall'utente (facoltativo) e
/// zero o più tag dello spazio globale.
public struct Bookmark: Codable, Equatable, Sendable {
    /// Identità stabile del segnalibro (UUID).
    public var id: String
    /// L'ancora: l'id del `ContentSegment` marcato, che è l'id-nodo STABILE del Layer 1 (non un
    /// indice). Robusto alla ripaginazione (Dynamic Type, rotazione) e quasi sempre al cambio di
    /// Layout/granularità, perché il nodo sorgente resta lo stesso. La reading view lo risolve in
    /// una posizione al momento del salto; se il nodo non è nello stream corrente si ripiega su
    /// `orderIndexHint` (degradazione ragionevole, § 2.5).
    public var anchorSegmentId: String
    /// Indice di lettura (0-based) dell'elemento alla creazione: ordina la lista "in ordine di
    /// occorrenza nel documento" (§ 5.4) e fa da fallback di risoluzione dell'ancora.
    public var orderIndexHint: Int
    /// Nome scelto dall'utente, oppure `nil`/vuoto: in tal caso la lista mostra l'anteprima (§ 5.4).
    public var name: String?
    /// Anteprima delle prime parole dell'elemento marcato, catturata alla creazione (§ 5.4).
    public var preview: String
    /// Pagina del file originale (1-based) alla creazione, se disponibile (§ 5.4); `nil` per i
    /// documenti di origine non impaginata (§ 4.1).
    public var originalPage: Int?
    /// Gli id dei tag globali associati (§ 5.1). Un tag eliminato (§ 5.3) viene scollato da qui, ma
    /// il segnalibro resta in vita.
    public var tagIds: [String]
    /// Quando è stato creato (ordinamento secondario e referto).
    public var createdAt: Date

    public init(
        id: String,
        anchorSegmentId: String,
        orderIndexHint: Int,
        name: String? = nil,
        preview: String,
        originalPage: Int? = nil,
        tagIds: [String] = [],
        createdAt: Date
    ) {
        self.id = id
        self.anchorSegmentId = anchorSegmentId
        self.orderIndexHint = orderIndexHint
        self.name = name
        self.preview = preview
        self.originalPage = originalPage
        self.tagIds = tagIds
        self.createdAt = createdAt
    }

    /// Etichetta da mostrare nella lista: il nome se l'utente gliel'ha dato, altrimenti l'anteprima
    /// (§ 5.4). Mai vuota se l'anteprima non lo è.
    public var displayTitle: String {
        if let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return name
        }
        return preview
    }
}

/// Un tag è un'etichetta nominale dello spazio GLOBALE dell'utente (§ 5.2), valida su tutta la
/// libreria. Strutturalmente tutti i tag sono uguali: non esiste un flag "predefinito" — i sei
/// predefiniti sono solo un punto di partenza seminato al primo avvio (`LibraryStore.tags()`) e
/// sono eliminabili come qualunque tag personale.
public struct Tag: Codable, Equatable, Sendable {
    public var id: String
    public var name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

// MARK: - Sottolineatura (§ 6) — solo visiva, solo vedenti

/// La copertura di una sottolineatura DENTRO un singolo elemento di testo: un intervallo di parole
/// (inclusivo) nel segmento indicato. Le parole sono indicizzate come `WordTokenizer.wordRanges`
/// (runs di non-spazio), la stessa tokenizzazione usata dalla resa grafica e dalla finestra di
/// selezione, così l'indice di parola qui e il glifo sottolineato a schermo coincidono sempre.
public struct UnderlineSpan: Codable, Equatable, Sendable {
    /// Id del `ContentSegment` (id-nodo Layer 1) coperto da questo span.
    public var segmentId: String
    /// Indice della prima parola coperta (0-based, inclusivo).
    public var startWord: Int
    /// Indice dell'ultima parola coperta (0-based, inclusivo). `== startWord` per una parola sola.
    public var endWord: Int

    public init(segmentId: String, startWord: Int, endWord: Int) {
        self.segmentId = segmentId
        self.startWord = startWord
        self.endWord = endWord
    }
}

/// Una sottolineatura (§ 6): un'estensione di parole, eventualmente su più blocchi consecutivi. È
/// rappresentata come lista di `UnderlineSpan` per-segmento (uno span per un solo blocco; più span,
/// uno per blocco, per l'estensione multi-blocco). Questa forma rende la non-sovrapposizione (§ 6.3)
/// e la resa grafica PURE e indipendenti dall'ordine di lettura: lo store confronta gli intervalli
/// per-segmento senza dover conoscere la sequenza dei segmenti (che vive nella reading view).
///
/// Niente tag, niente lista/vista globale (§ 6.1): la sottolineatura si ritrova solo visivamente
/// (resa grafica) o apponendovi un segnalibro. È persistente per documento (§ 2.5 / § 6.5).
public struct Underline: Codable, Equatable, Sendable {
    /// Identità stabile (UUID).
    public var id: String
    /// Gli intervalli di parole coperti, uno per blocco (§ 6.2, mono/multi-parola/multi-blocco).
    public var spans: [UnderlineSpan]
    /// Anteprima delle prime parole sottolineate, per la lista di scelta di modifica/eliminazione
    /// quando un elemento ne contiene più d'una (§ 6.3 / § 6.4).
    public var preview: String
    /// Quando è stata creata.
    public var createdAt: Date

    public init(id: String, spans: [UnderlineSpan], preview: String, createdAt: Date) {
        self.id = id
        self.spans = spans
        self.preview = preview
        self.createdAt = createdAt
    }

    /// Gli id dei segmenti toccati da questa sottolineatura.
    public var segmentIds: [String] { spans.map { $0.segmentId } }
}

// MARK: - Contenitori organizzativi (tre livelli, § 12.2)

/// Terzo e ultimo livello di annidamento: contiene SOLO collocazioni di file (§ 12.2).
public struct Subfolder: Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    /// Id dei documenti collocati qui (collocazioni, non i file).
    public var fileIds: [String]

    public init(id: String, name: String, fileIds: [String] = []) {
        self.id = id
        self.name = name
        self.fileIds = fileIds
    }
}

/// Secondo livello: può contenere sottocartelle e/o collocazioni di file (§ 12.2).
public struct Folder: Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var subfolders: [Subfolder]
    public var fileIds: [String]

    public init(id: String, name: String, subfolders: [Subfolder] = [], fileIds: [String] = []) {
        self.id = id
        self.name = name
        self.subfolders = subfolders
        self.fileIds = fileIds
    }
}

/// Primo livello: puro contenitore organizzativo, senza impostazioni proprie (§ 12.2). Può
/// contenere cartelle e/o collocazioni di file.
public struct Workspace: Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var folders: [Folder]
    public var fileIds: [String]

    public init(id: String, name: String, folders: [Folder] = [], fileIds: [String] = []) {
        self.id = id
        self.name = name
        self.folders = folders
        self.fileIds = fileIds
    }
}

/// Lo stato persistente completo della libreria.
public struct LibraryState: Codable, Equatable, Sendable {
    public var documents: [ArchivedDocument]
    public var workspaces: [Workspace]
    /// L'ultimo documento aperto quando l'app è stata chiusa, per la riapertura nello stato di
    /// chiusura (§ 2.5). `nil` se l'ultima schermata attiva non era un documento.
    public var lastOpenDocumentId: String?

    /// Lo spazio GLOBALE dei tag dell'utente (§ 5.2), comune a tutta la libreria. OPZIONALE per la
    /// retro-compatibilità additiva (come `ArchivedDocument.isHiddenFromRecents`): `nil` significa
    /// "mai inizializzato" e distingue il primo avvio (→ si seminano i sei predefiniti, § 5.2) dallo
    /// stato in cui l'utente ha eliminato tutti i tag (`[]`, che si rispetta). La semina avviene
    /// pigramente in `LibraryStore.tags()`, così le librerie esistenti non vengono riscritte finché
    /// i tag non servono davvero.
    public var tags: [Tag]?

    /// Lo stato dello split screen (§ 11.9), o `nil` se nessuno split è attivo. OPZIONALE/additivo
    /// per la retro-compatibilità (una libreria di una versione precedente non ha la chiave → nessun
    /// reset). Alla riapertura, se presente, l'app ripristina lo split (§ 2.5 / § 11.9).
    public var splitState: SplitState?

    public init(
        documents: [ArchivedDocument] = [],
        workspaces: [Workspace] = [],
        lastOpenDocumentId: String? = nil,
        tags: [Tag]? = nil,
        splitState: SplitState? = nil
    ) {
        self.documents = documents
        self.workspaces = workspaces
        self.lastOpenDocumentId = lastOpenDocumentId
        self.tags = tags
        self.splitState = splitState
    }
}

// MARK: - Riferimento a un contenitore e ordinamento

/// Identifica un contenitore per percorso di id (workspace → cartella → sottocartella). È il modo
/// in cui le viste indicano allo store DOVE collocare/spostare/leggere.
public enum ContainerRef: Equatable, Hashable, Sendable {
    case workspace(String)
    case folder(workspace: String, folder: String)
    case subfolder(workspace: String, folder: String, subfolder: String)

    /// L'id del workspace radice, comune a ogni livello.
    public var workspaceId: String {
        switch self {
        case .workspace(let w): return w
        case .folder(let w, _): return w
        case .subfolder(let w, _, _): return w
        }
    }
}

/// I criteri di ordinamento automatico dei contenuti (§ 12.3). Niente riordino manuale.
public enum SortOrder: String, CaseIterable, Sendable {
    case alphabetical
    case modifiedDate
    case importDate
}

// MARK: - Confine di persistenza

/// Il confine minimo di persistenza dello stato della libreria. Mirror di `KeyValueStore`, ma per
/// un blob unico (lo stato è un grafo, non chiavi sparse).
public protocol LibraryPersisting: AnyObject {
    /// I dati salvati, o `nil` se assenti/illeggibili (mai lancia: un fallimento collassa a `nil`).
    func load() -> Data?
    /// Salva i dati.
    func save(_ data: Data)
}

/// Persistenza in memoria — l'implementazione non-di-sistema usata da logica e test.
public final class InMemoryLibraryPersistence: LibraryPersisting {
    private var data: Data?
    public init(_ initial: Data? = nil) { self.data = initial }
    public func load() -> Data? { data }
    public func save(_ data: Data) { self.data = data }
}

/// Persistenza su file (JSON), Foundation puro. L'app la radica in Application Support; i test
/// continuano a usare la versione in memoria.
public final class FileLibraryPersistence: LibraryPersisting {
    private let url: URL
    public init(url: URL) { self.url = url }
    public func load() -> Data? { try? Data(contentsOf: url) }
    public func save(_ data: Data) {
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }
}

// MARK: - LibraryStore

/// La logica della libreria. Tiene lo stato in memoria e lo persiste a ogni mutazione attraverso il
/// confine `LibraryPersisting`. Da usare sul main (le viste lo chiamano dal main).
public final class LibraryStore {

    /// Lo stato corrente (sola lettura dall'esterno; le mutazioni passano dai metodi).
    public private(set) var state: LibraryState

    private let persistence: LibraryPersisting
    private let makeId: () -> String
    private let now: () -> Date

    /// `makeId`/`now` sono iniettabili per test deterministici; in produzione sono UUID e `Date()`.
    public init(
        persistence: LibraryPersisting,
        makeId: @escaping () -> String = { UUID().uuidString },
        now: @escaping () -> Date = { Date() }
    ) {
        self.persistence = persistence
        self.makeId = makeId
        self.now = now
        if let data = persistence.load(),
           let decoded = try? JSONDecoder.library.decode(LibraryState.self, from: data) {
            self.state = decoded
        } else {
            self.state = LibraryState()
        }
    }

    private func persist() {
        if let data = try? JSONEncoder.library.encode(state) {
            persistence.save(data)
        }
    }

    // MARK: Query — archivio e recenti

    public func document(id: String) -> ArchivedDocument? {
        state.documents.first { $0.id == id }
    }

    /// Tutti i documenti dell'archivio (per la Ricerca, § 13.2).
    public func allDocuments() -> [ArchivedDocument] { state.documents }

    /// I documenti aperti più di recente, dal più recente (§ 12.1). Esclude quelli mai aperti e
    /// quelli rimossi dai recenti ("Rimuovi dai recenti", operazione di sola lista). `limit` di
    /// default 5.
    public func recents(limit: Int = 5) -> [ArchivedDocument] {
        state.documents
            .filter { $0.lastOpenedAt != nil && ($0.isHiddenFromRecents ?? false) == false }
            .sorted { ($0.lastOpenedAt ?? .distantPast) > ($1.lastOpenedAt ?? .distantPast) }
            .prefix(limit)
            .map { $0 }
    }

    /// I documenti non collocati in alcun contenitore (atterraggio "non collocato" dell'import,
    /// § 12.8): restano trovabili dalla Ricerca e collocabili in seguito.
    public func uncollocatedDocuments() -> [ArchivedDocument] {
        let collocated = collocatedDocumentIds()
        return state.documents.filter { !collocated.contains($0.id) }
    }

    private func collocatedDocumentIds() -> Set<String> {
        var ids = Set<String>()
        for w in state.workspaces {
            ids.formUnion(w.fileIds)
            for f in w.folders {
                ids.formUnion(f.fileIds)
                for s in f.subfolders { ids.formUnion(s.fileIds) }
            }
        }
        return ids
    }

    // MARK: Mutazioni — archivio

    /// Inserisce un nuovo documento nell'archivio e ne restituisce il record (con id minted).
    @discardableResult
    public func addDocument(
        title: String,
        sourceFileName: String,
        sourcePageCount: Int,
        warnings: [String] = []
    ) -> ArchivedDocument {
        let doc = ArchivedDocument(
            id: makeId(),
            title: title,
            sourceFileName: sourceFileName,
            importedAt: now(),
            lastOpenedAt: nil,
            sourcePageCount: sourcePageCount,
            readingPosition: 0,
            warnings: warnings)
        state.documents.append(doc)
        persist()
        return doc
    }

    public func renameDocument(id: String, to title: String) {
        guard let i = state.documents.firstIndex(where: { $0.id == id }) else { return }
        state.documents[i].title = title
        persist()
    }

    /// Eliminazione DEFINITIVA dall'archivio (§ 12.7): rimuove il documento e ogni sua collocazione,
    /// e lo deseleziona da `lastOpenDocumentId`. È l'unica eliminazione irreversibile.
    public func deleteDocumentFromArchive(id: String) {
        state.documents.removeAll { $0.id == id }
        removeAllCollocations(of: id)
        if state.lastOpenDocumentId == id { state.lastOpenDocumentId = nil }
        // Uno split che referenzia il documento eliminato non è più valido (§ 2.5, degradazione).
        if let split = state.splitState, split.leftDocumentId == id || split.rightDocumentId == id {
            state.splitState = nil
        }
        persist()
    }

    /// Registra un'apertura: aggiorna `lastOpenedAt` (→ Recenti) e marca il documento come ultimo
    /// aperto (→ riapertura nello stato di chiusura, § 2.5).
    public func recordOpened(id: String) {
        guard let i = state.documents.firstIndex(where: { $0.id == id }) else { return }
        state.documents[i].lastOpenedAt = now()
        // Riaprire un documento lo riporta fra i recenti: un documento appena aperto è recente.
        state.documents[i].isHiddenFromRecents = false
        state.lastOpenDocumentId = id
        persist()
    }

    /// Rimuove il documento dalla sola sezione Recenti (operazione di SOLA LISTA): non tocca
    /// l'archivio, le collocazioni, né la posizione di lettura. Riaprendolo, tornerà fra i recenti.
    public func removeFromRecents(id: String) {
        guard let i = state.documents.firstIndex(where: { $0.id == id }) else { return }
        guard state.documents[i].isHiddenFromRecents != true else { return }
        state.documents[i].isHiddenFromRecents = true
        persist()
    }

    /// Aggiorna la posizione di lettura ricordata (§ 2.5). No-op se invariata (evita scritture).
    public func updateReadingPosition(id: String, position: Int) {
        guard let i = state.documents.firstIndex(where: { $0.id == id }) else { return }
        let clamped = max(0, position)
        guard state.documents[i].readingPosition != clamped else { return }
        state.documents[i].readingPosition = clamped
        persist()
    }

    /// Imposta (o azzera) il documento da riaprire al prossimo avvio (§ 2.5). Si azzera quando
    /// l'utente torna alla Home, così un avvio a freddo dalla Home non riapre un lettore.
    public func setLastOpenDocument(id: String?) {
        guard state.lastOpenDocumentId != id else { return }
        state.lastOpenDocumentId = id
        persist()
    }

    public var lastOpenDocumentId: String? { state.lastOpenDocumentId }

    // MARK: Split screen (§ 11.9)

    /// Lo stato dello split screen persistito, o `nil` se nessuno split è attivo.
    public var splitState: SplitState? { state.splitState }

    /// Imposta (o azzera con `nil`) lo stato dello split (§ 11.9). No-op se invariato.
    public func setSplitState(_ split: SplitState?) {
        guard state.splitState != split else { return }
        state.splitState = split
        persist()
    }

    // MARK: Mutazioni — contenitori

    @discardableResult
    public func createWorkspace(name: String) -> Workspace {
        let ws = Workspace(id: makeId(), name: name)
        state.workspaces.append(ws)
        persist()
        return ws
    }

    public func renameWorkspace(id: String, to name: String) {
        guard let i = state.workspaces.firstIndex(where: { $0.id == id }) else { return }
        state.workspaces[i].name = name
        persist()
    }

    /// Elimina un workspace e tutto il suo contenuto ORGANIZZATIVO (§ 12.7): i file restano
    /// nell'archivio, solo le loro collocazioni qui spariscono.
    public func deleteWorkspace(id: String) {
        state.workspaces.removeAll { $0.id == id }
        persist()
    }

    @discardableResult
    public func createFolder(inWorkspace workspaceId: String, name: String) -> Folder? {
        guard let wi = state.workspaces.firstIndex(where: { $0.id == workspaceId }) else { return nil }
        let folder = Folder(id: makeId(), name: name)
        state.workspaces[wi].folders.append(folder)
        persist()
        return folder
    }

    public func renameFolder(inWorkspace workspaceId: String, folderId: String, to name: String) {
        guard let wi = state.workspaces.firstIndex(where: { $0.id == workspaceId }),
              let fi = state.workspaces[wi].folders.firstIndex(where: { $0.id == folderId }) else { return }
        state.workspaces[wi].folders[fi].name = name
        persist()
    }

    public func deleteFolder(inWorkspace workspaceId: String, folderId: String) {
        guard let wi = state.workspaces.firstIndex(where: { $0.id == workspaceId }) else { return }
        state.workspaces[wi].folders.removeAll { $0.id == folderId }
        persist()
    }

    @discardableResult
    public func createSubfolder(
        inWorkspace workspaceId: String, folderId: String, name: String
    ) -> Subfolder? {
        guard let wi = state.workspaces.firstIndex(where: { $0.id == workspaceId }),
              let fi = state.workspaces[wi].folders.firstIndex(where: { $0.id == folderId }) else {
            return nil
        }
        let sub = Subfolder(id: makeId(), name: name)
        state.workspaces[wi].folders[fi].subfolders.append(sub)
        persist()
        return sub
    }

    public func renameSubfolder(
        inWorkspace workspaceId: String, folderId: String, subfolderId: String, to name: String
    ) {
        guard let wi = state.workspaces.firstIndex(where: { $0.id == workspaceId }),
              let fi = state.workspaces[wi].folders.firstIndex(where: { $0.id == folderId }),
              let si = state.workspaces[wi].folders[fi].subfolders.firstIndex(where: { $0.id == subfolderId })
        else { return }
        state.workspaces[wi].folders[fi].subfolders[si].name = name
        persist()
    }

    public func deleteSubfolder(inWorkspace workspaceId: String, folderId: String, subfolderId: String) {
        guard let wi = state.workspaces.firstIndex(where: { $0.id == workspaceId }),
              let fi = state.workspaces[wi].folders.firstIndex(where: { $0.id == folderId }) else { return }
        state.workspaces[wi].folders[fi].subfolders.removeAll { $0.id == subfolderId }
        persist()
    }

    // MARK: Mutazioni — collocazioni

    /// Aggiunge una collocazione del documento nel contenitore (§ 12.6, "Aggiungi file"). Idempotente
    /// dentro lo stesso contenitore (non duplica la stessa presenza nello stesso posto).
    public func addCollocation(documentId: String, to ref: ContainerRef) {
        mutateContainer(ref) { ids in
            if !ids.contains(documentId) { ids.append(documentId) }
        }
    }

    /// Sposta una collocazione esistente da un contenitore a un altro (§ 12.6, "Sposta"): non
    /// attinge dall'archivio, opera su una presenza già esistente.
    public func moveCollocation(documentId: String, from source: ContainerRef, to destination: ContainerRef) {
        guard source != destination else { return }
        mutateContainer(source) { ids in ids.removeAll { $0 == documentId } }
        addCollocation(documentId: documentId, to: destination)
    }

    /// Rimuove una collocazione (§ 12.7): il file resta nell'archivio.
    public func removeCollocation(documentId: String, from ref: ContainerRef) {
        mutateContainer(ref) { ids in ids.removeAll { $0 == documentId } }
    }

    /// Gli id dei documenti collocati direttamente nel contenitore indicato (in ordine di
    /// inserimento; la vista applica l'ordinamento scelto).
    public func fileIds(in ref: ContainerRef) -> [String] {
        switch ref {
        case .workspace(let w):
            return state.workspaces.first { $0.id == w }?.fileIds ?? []
        case .folder(let w, let f):
            return state.workspaces.first { $0.id == w }?.folders.first { $0.id == f }?.fileIds ?? []
        case .subfolder(let w, let f, let s):
            return state.workspaces.first { $0.id == w }?
                .folders.first { $0.id == f }?
                .subfolders.first { $0.id == s }?.fileIds ?? []
        }
    }

    /// Le cartelle di un workspace (per la navigazione).
    public func folders(inWorkspace workspaceId: String) -> [Folder] {
        state.workspaces.first { $0.id == workspaceId }?.folders ?? []
    }

    /// Le sottocartelle di una cartella (per la navigazione).
    public func subfolders(inWorkspace workspaceId: String, folderId: String) -> [Subfolder] {
        state.workspaces.first { $0.id == workspaceId }?
            .folders.first { $0.id == folderId }?.subfolders ?? []
    }

    public func workspace(id: String) -> Workspace? { state.workspaces.first { $0.id == id } }

    // MARK: Helpers privati

    private func mutateContainer(_ ref: ContainerRef, _ body: (inout [String]) -> Void) {
        switch ref {
        case .workspace(let w):
            guard let wi = state.workspaces.firstIndex(where: { $0.id == w }) else { return }
            body(&state.workspaces[wi].fileIds)
        case .folder(let w, let f):
            guard let wi = state.workspaces.firstIndex(where: { $0.id == w }),
                  let fi = state.workspaces[wi].folders.firstIndex(where: { $0.id == f }) else { return }
            body(&state.workspaces[wi].folders[fi].fileIds)
        case .subfolder(let w, let f, let s):
            guard let wi = state.workspaces.firstIndex(where: { $0.id == w }),
                  let fi = state.workspaces[wi].folders.firstIndex(where: { $0.id == f }),
                  let si = state.workspaces[wi].folders[fi].subfolders.firstIndex(where: { $0.id == s })
            else { return }
            body(&state.workspaces[wi].folders[fi].subfolders[si].fileIds)
        }
        persist()
    }

    private func removeAllCollocations(of documentId: String) {
        for wi in state.workspaces.indices {
            state.workspaces[wi].fileIds.removeAll { $0 == documentId }
            for fi in state.workspaces[wi].folders.indices {
                state.workspaces[wi].folders[fi].fileIds.removeAll { $0 == documentId }
                for si in state.workspaces[wi].folders[fi].subfolders.indices {
                    state.workspaces[wi].folders[fi].subfolders[si].fileIds.removeAll { $0 == documentId }
                }
            }
        }
    }
}

// MARK: - Ordinamento documenti (logica condivisa, § 12.3)

extension LibraryStore {
    /// Ordina una lista di documenti secondo il criterio scelto. L'alfabetico è case-insensitive e
    /// localizzato; gli altri due sono cronologici decrescenti (il più recente in cima).
    public func sorted(_ docs: [ArchivedDocument], by order: SortOrder) -> [ArchivedDocument] {
        switch order {
        case .alphabetical:
            return docs.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .modifiedDate:
            return docs.sorted { ($0.lastOpenedAt ?? $0.importedAt) > ($1.lastOpenedAt ?? $1.importedAt) }
        case .importDate:
            return docs.sorted { $0.importedAt > $1.importedAt }
        }
    }
}

// MARK: - Tag globali (§ 5.2 / § 5.3)

extension LibraryStore {

    /// I sei tag predefiniti seminati al primo avvio (§ 5.2), nell'ordine del documento di prodotto.
    /// Sono un punto di partenza: strutturalmente uguali a qualunque tag personale ed eliminabili.
    public static let defaultTagNames: [String] = [
        "Da rileggere", "Dubbio", "Importante", "Citazione", "Per tesi", "Da verificare",
    ]

    /// Lo spazio globale dei tag (§ 5.2). Alla PRIMA lettura, se lo stato non è mai stato
    /// inizializzato (`state.tags == nil`, tipico di una libreria di build precedente o di
    /// un'installazione nuova), semina i sei predefiniti e persiste. Una lista VUOTA (`[]`) — cioè
    /// l'utente che ha eliminato tutti i tag — è rispettata e NON riseminata.
    @discardableResult
    public func tags() -> [Tag] {
        if let existing = state.tags { return existing }
        let seeded = Self.defaultTagNames.map { Tag(id: makeId(), name: $0) }
        state.tags = seeded
        persist()
        return seeded
    }

    public func tag(id: String) -> Tag? { tags().first { $0.id == id } }

    /// Crea un nuovo tag globale (§ 5.6) e restituisce il record con id minted. Nome ripulito dagli
    /// spazi; un nome vuoto è rifiutato (`nil`).
    @discardableResult
    public func createTag(name: String) -> Tag? {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }
        var current = tags()
        let tag = Tag(id: makeId(), name: clean)
        current.append(tag)
        state.tags = current
        persist()
        return tag
    }

    /// Rinomina un tag esistente (§ 5.6). Nome vuoto ignorato.
    public func renameTag(id: String, to name: String) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        var current = tags()
        guard let i = current.firstIndex(where: { $0.id == id }) else { return }
        current[i].name = clean
        state.tags = current
        persist()
    }

    /// Elimina un tag (§ 5.3), predefinito o personale. Il tag scompare definitivamente; i
    /// segnalibri che lo portavano RESTANO IN VITA e perdono solo l'associazione — se non hanno
    /// altri tag restano come segnalibri senza tag. Una sola scrittura per l'intera operazione.
    public func deleteTag(id: String) {
        var current = tags()
        guard current.contains(where: { $0.id == id }) else { return }
        current.removeAll { $0.id == id }
        state.tags = current
        // Scolla l'id da ogni segnalibro di ogni documento, senza toccarne l'esistenza.
        for di in state.documents.indices {
            guard var bms = state.documents[di].bookmarks else { continue }
            var changed = false
            for bi in bms.indices where bms[bi].tagIds.contains(id) {
                bms[bi].tagIds.removeAll { $0 == id }
                changed = true
            }
            if changed { state.documents[di].bookmarks = bms }
        }
        persist()
    }
}

// MARK: - Segnalibri (§ 5.1 / § 5.4 / § 5.5 / § 5.6)

extension LibraryStore {

    /// I segnalibri di un documento in ordine di occorrenza nel documento (§ 5.4), a parità di
    /// posizione per data di creazione. Lista vuota se il documento non esiste o non ha segnalibri.
    public func bookmarks(documentId: String) -> [Bookmark] {
        let raw = document(id: documentId)?.bookmarks ?? []
        return raw.sorted {
            $0.orderIndexHint != $1.orderIndexHint
                ? $0.orderIndexHint < $1.orderIndexHint
                : $0.createdAt < $1.createdAt
        }
    }

    /// I segnalibri di un documento filtrati con la logica ADDITIVA "o" (§ 5.5): quelli che portano
    /// ALMENO UNO dei tag selezionati. Un insieme di tag vuoto → lista completa (nessun filtro).
    public func bookmarks(documentId: String, filteredByAnyTag tagIds: Set<String>) -> [Bookmark] {
        let all = bookmarks(documentId: documentId)
        guard !tagIds.isEmpty else { return all }
        return all.filter { !Set($0.tagIds).isDisjoint(with: tagIds) }
    }

    /// Aggiunge un segnalibro al documento (§ 5.7) e restituisce il record con id minted, o `nil` se
    /// il documento non esiste. `tagIds` è filtrato ai soli tag esistenti (un tag eliminato nel
    /// frattempo non viene associato).
    @discardableResult
    public func addBookmark(
        documentId: String,
        anchorSegmentId: String,
        orderIndexHint: Int,
        name: String? = nil,
        preview: String,
        originalPage: Int? = nil,
        tagIds: [String] = []
    ) -> Bookmark? {
        guard let di = state.documents.firstIndex(where: { $0.id == documentId }) else { return nil }
        let validTagIds = existingTagIds(from: tagIds)
        let cleanName = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let bookmark = Bookmark(
            id: makeId(),
            anchorSegmentId: anchorSegmentId,
            orderIndexHint: max(0, orderIndexHint),
            name: (cleanName?.isEmpty ?? true) ? nil : cleanName,
            preview: preview,
            originalPage: originalPage,
            tagIds: validTagIds,
            createdAt: now())
        var bms = state.documents[di].bookmarks ?? []
        bms.append(bookmark)
        state.documents[di].bookmarks = bms
        persist()
        return bookmark
    }

    /// Aggiorna nome e/o tag di un segnalibro esistente (§ 5.7, finestra di modifica). `tagIds` è
    /// filtrato ai soli tag esistenti.
    public func updateBookmark(
        documentId: String, bookmarkId: String, name: String?, tagIds: [String]
    ) {
        guard let di = state.documents.firstIndex(where: { $0.id == documentId }),
              var bms = state.documents[di].bookmarks,
              let bi = bms.firstIndex(where: { $0.id == bookmarkId }) else { return }
        let cleanName = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        bms[bi].name = (cleanName?.isEmpty ?? true) ? nil : cleanName
        bms[bi].tagIds = existingTagIds(from: tagIds)
        state.documents[di].bookmarks = bms
        persist()
    }

    /// Elimina un segnalibro dal documento.
    public func deleteBookmark(documentId: String, bookmarkId: String) {
        guard let di = state.documents.firstIndex(where: { $0.id == documentId }),
              var bms = state.documents[di].bookmarks else { return }
        let before = bms.count
        bms.removeAll { $0.id == bookmarkId }
        guard bms.count != before else { return }
        state.documents[di].bookmarks = bms
        persist()
    }

    /// Un segnalibro con il suo documento di provenienza, per la vista globale per tag (§ 5.6).
    public struct GlobalBookmark: Equatable, Sendable {
        public let document: ArchivedDocument
        public let bookmark: Bookmark
    }

    /// La vista globale dei segnalibri per tag su TUTTA la libreria (§ 5.6), con la stessa logica
    /// additiva "o" della § 5.5: quelli che portano almeno uno dei tag selezionati. Un insieme
    /// vuoto → tutti i segnalibri della libreria. Ordinati per titolo del documento, poi per
    /// occorrenza nel documento.
    public func bookmarksAcrossLibrary(withAnyTag tagIds: Set<String>) -> [GlobalBookmark] {
        var result: [GlobalBookmark] = []
        for doc in state.documents {
            let matches = tagIds.isEmpty
                ? bookmarks(documentId: doc.id)
                : bookmarks(documentId: doc.id, filteredByAnyTag: tagIds)
            result.append(contentsOf: matches.map { GlobalBookmark(document: doc, bookmark: $0) })
        }
        return result.sorted {
            let byTitle = $0.document.title.localizedCaseInsensitiveCompare($1.document.title)
            if byTitle != .orderedSame { return byTitle == .orderedAscending }
            return $0.bookmark.orderIndexHint < $1.bookmark.orderIndexHint
        }
    }

    /// Filtra una lista di id-tag ai soli tag GLOBALI esistenti, preservando l'ordine e togliendo i
    /// duplicati. Impedisce che un segnalibro trattenga un tag già eliminato.
    private func existingTagIds(from ids: [String]) -> [String] {
        let known = Set(tags().map { $0.id })
        var seen = Set<String>()
        return ids.filter { known.contains($0) && seen.insert($0).inserted }
    }
}

// MARK: - Sottolineature (§ 6.2 / § 6.3 / § 6.4)

extension LibraryStore {

    /// Tutte le sottolineature di un documento, in ordine di creazione. Vuoto se il documento non
    /// esiste o non ne ha.
    public func underlines(documentId: String) -> [Underline] {
        document(id: documentId)?.underlines ?? []
    }

    /// Le sottolineature che toccano un dato segmento (per il menù di stato, le liste di scelta di
    /// modifica/eliminazione, e il blocco delle parole già coperte nella finestra di selezione).
    public func underlinesTouching(documentId: String, segmentId: String) -> [Underline] {
        underlines(documentId: documentId).filter { $0.segmentIds.contains(segmentId) }
    }

    /// Aggiunge una sottolineatura (§ 6.2) e restituisce il record con id minted, oppure `nil` se il
    /// documento non esiste, gli span sono vuoti/degeneri, o si **sovrappone** a una esistente
    /// (§ 6.3, neanche parzialmente). La finestra di selezione previene già la sovrapposizione
    /// bloccando le parole coperte; questa guardia è la rete di sicurezza del modello.
    @discardableResult
    public func addUnderline(documentId: String, spans: [UnderlineSpan], preview: String) -> Underline? {
        guard let di = state.documents.firstIndex(where: { $0.id == documentId }) else { return nil }
        let normalized = Self.normalizedSpans(spans)
        guard !normalized.isEmpty else { return nil }
        let existing = state.documents[di].underlines ?? []
        guard !Self.spansOverlapAny(normalized, existing) else { return nil }
        let underline = Underline(id: makeId(), spans: normalized, preview: preview, createdAt: now())
        var all = existing
        all.append(underline)
        state.documents[di].underlines = all
        persist()
        return underline
    }

    /// Sostituisce gli span di una sottolineatura esistente (§ 6.3, "Modifica": la nuova rimpiazza
    /// la precedente). La sovrapposizione è controllata ESCLUDENDO la sottolineatura stessa (che sta
    /// per essere sostituita). Ritorna `false` se il documento/sottolineatura non esistono, gli span
    /// sono degeneri, o si sovrappongono ad ALTRE.
    @discardableResult
    public func replaceUnderline(documentId: String, underlineId: String, spans: [UnderlineSpan]) -> Bool {
        guard let di = state.documents.firstIndex(where: { $0.id == documentId }),
              var all = state.documents[di].underlines,
              let ui = all.firstIndex(where: { $0.id == underlineId }) else { return false }
        let normalized = Self.normalizedSpans(spans)
        guard !normalized.isEmpty else { return false }
        let others = all.enumerated().filter { $0.offset != ui }.map { $0.element }
        guard !Self.spansOverlapAny(normalized, others) else { return false }
        all[ui].spans = normalized
        state.documents[di].underlines = all
        persist()
        return true
    }

    /// Elimina una sottolineatura (§ 6.4).
    public func deleteUnderline(documentId: String, underlineId: String) {
        guard let di = state.documents.firstIndex(where: { $0.id == documentId }),
              var all = state.documents[di].underlines else { return }
        let before = all.count
        all.removeAll { $0.id == underlineId }
        guard all.count != before else { return }
        state.documents[di].underlines = all
        persist()
    }

    /// Vero se gli `spans` candidati si sovrappongono a una qualunque sottolineatura data (§ 6.3):
    /// due span si sovrappongono se condividono un segmento e i loro intervalli di parole
    /// (inclusivi) si intersecano.
    public func underlinesOverlap(
        _ spans: [UnderlineSpan], with underlines: [Underline]
    ) -> Bool {
        Self.spansOverlapAny(Self.normalizedSpans(spans), underlines)
    }

    // MARK: Helpers puri sull'overlap (testabili)

    /// Normalizza gli span: scarta i degeneri (indici negativi o `end < start`), ordina start/end.
    static func normalizedSpans(_ spans: [UnderlineSpan]) -> [UnderlineSpan] {
        spans.compactMap { span in
            let lo = min(span.startWord, span.endWord)
            let hi = max(span.startWord, span.endWord)
            guard lo >= 0 else { return nil }
            return UnderlineSpan(segmentId: span.segmentId, startWord: lo, endWord: hi)
        }
    }

    static func spansOverlapAny(_ spans: [UnderlineSpan], _ underlines: [Underline]) -> Bool {
        for underline in underlines {
            for candidate in spans {
                for existing in underline.spans where existing.segmentId == candidate.segmentId {
                    // Intervalli inclusivi che si intersecano.
                    if candidate.startWord <= existing.endWord, existing.startWord <= candidate.endWord {
                        return true
                    }
                }
            }
        }
        return false
    }
}

// MARK: - Coder condivisi

extension JSONEncoder {
    /// Encoder stabile per la libreria: date ISO-8601, chiavi ordinate (diff leggibili su disco).
    static var library: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

extension JSONDecoder {
    static var library: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
