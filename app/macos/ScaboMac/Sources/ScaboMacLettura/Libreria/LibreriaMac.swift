//
//  LibreriaMac.swift
//  ScaboMacLettura — la libreria dell'app Mac (giro «app unica per Mac, tappa A», 2026-11-08): la STESSA libreria dell'iPad,
//  `LibraryService` di ScaboChain, nella stessa forma (`Application Support/ScaboPDF/` dentro il contenitore della sandbox:
//  `library.json`, `Archive/`, `Cache/` nel formato 6). Qui solo ciò che è del Mac: le preferenze come il Mac le legge (la
//  granularità delle Impostazioni, con la regola condivisa con l'iPad dal 2026-11-10; le note annunciate a voce accese per
//  impostazione predefinita, DISEGNO_LETTURA_MAC § 4.2) e l'elenco dei libri della Home.
//
import Foundation
import ScaboChain
import ScaboCore

/// Le preferenze di lettura del Mac, sulle stesse chiavi dell'iPad (ScaboCore `PreferenceKeys`).
public enum PreferenzeLettura {
    /// Note annunciate a voce: sul Mac acceso se l'utente non ha scelto (sull'iPad spento): il gancio del fuoco per i segnali
    /// è pronto, ma i segnali si accendono solo dopo la prova d'orecchio T2.
    public static func noteAVoce(_ prefs: KeyValueStore) -> Bool {
        prefs.getItem(PreferenceKeys.noteSpokenLabels) == nil ? true : getStoredNoteSpokenLabels(prefs)
    }
    public static func impostaNoteAVoce(_ prefs: KeyValueStore, _ acceso: Bool) { setStoredNoteSpokenLabels(prefs, acceso) }

    /// I segnali acustici al gancio del fuoco: spenti finché la prova d'orecchio T2 non dice che VoiceOver dà il fuoco agli
    /// elementi. Si accendono con l'argomento di lancio `--segnali-acustici` (prove d'orecchio) o con questa chiave.
    public static let chiaveSegnali = "@scabopdf/mac/reading/earconsOnFocus"
    public static func segnaliAcustici(_ prefs: KeyValueStore) -> Bool {
        prefs.getItem(chiaveSegnali) == "1" || ProcessInfo.processInfo.arguments.contains("--segnali-acustici")
    }

    /// La granularità con cui il Mac elabora un libro: la regola condivisa con l'iPad (ScaboChain
    /// `ReadingAssembly.processingGranularity`, dal giro «prove rifatte e granularità», 2026-11-10): quella delle Impostazioni
    /// per i PDF; per gli atti AKN quella predefinita (§ 7.7); per i volumi enormi la granularità leggera.
    public static func granularita(_ prefs: KeyValueStore, isAkn: Bool, large: Bool) -> Int {
        ReadingAssembly.processingGranularity(chosen: getStoredGranularityLevel(prefs).target, isAkn: isAkn, large: large)
    }
}

@MainActor
public final class LibreriaMac {
    public let service: LibraryService
    public var prefs: KeyValueStore { service.prefs }
    /// Avvisa chi mostra l'elenco (la Home) che la libreria è cambiata.
    public var quandoCambia: [() -> Void] = []
    /// Avvisa, prima di toglierlo, che un libro sta per essere eliminato (chi tiene la sua finestra di lettura la chiude).
    public var quandoElimina: [(String) -> Void] = []

    public init(service: LibraryService) {
        self.service = service
    }

    /// I libri dal più recentemente aperto (poi dal più recentemente importato): l'elenco della Home nella tappa A.
    public func libri() -> [ArchivedDocument] {
        service.store.allDocuments().sorted { a, b in
            let da = a.lastOpenedAt ?? a.importedAt, db = b.lastOpenedAt ?? b.importedAt
            return da != db ? da > db : a.title.localizedStandardCompare(b.title) == .orderedAscending
        }
    }

    /// L'eliminazione definitiva (§ 12.7): dall'archivio, con la cache e il testo di ricerca, come sull'iPad.
    public func eliminaDefinitivamente(_ id: String) {
        for f in quandoElimina { f(id) }
        service.store.deleteDocumentFromArchive(id: id)
        service.deleteFiles(forDocumentId: id)
        avvisa()
    }

    public func avvisa() { for f in quandoCambia { f() } }
}
