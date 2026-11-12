//
//  LibreriaMac.swift
//  ScaboMacLettura — la libreria dell'app Mac (giro «app unica per Mac, tappa A», 2026-11-08): la STESSA libreria dell'iPad,
//  `LibraryService` di ScaboChain, nella stessa forma (`Application Support/ScaboPDF/` dentro il contenitore della sandbox:
//  `library.json`, `Archive/`, `Cache/` nel formato 6). Qui solo ciò che è del Mac: le preferenze come il Mac le legge (la
//  granularità delle Impostazioni, con la regola condivisa con l'iPad dal 2026-11-10; le note annunciate a voce, spente per
//  impostazione predefinita come sull'iPad dal 12 novembre 2026, DISEGNO_LETTURA_MAC § 4.2) e l'elenco dei libri della Home.
//
import Foundation
import ScaboChain
import ScaboCore

/// Le preferenze di lettura del Mac, sulle stesse chiavi dell'iPad (ScaboCore `PreferenceKeys`).
public enum PreferenzeLettura {
    /// Note annunciate a voce: dal 12 novembre 2026 (LAYER2 § 12.16, decisione 13) spente se l'utente non ha scelto, come
    /// sull'iPad: sulle note suona il segnale del loro regime. La scelta già fatta resta: la chiave è quella dell'iPad, e c'è solo
    /// se l'utente ha toccato «Annuncia le note a voce» nelle Impostazioni (fino all'11 novembre, senza scelta, era accesa).
    public static func noteAVoce(_ prefs: KeyValueStore) -> Bool { getStoredNoteSpokenLabels(prefs) }
    public static func impostaNoteAVoce(_ prefs: KeyValueStore, _ acceso: Bool) { setStoredNoteSpokenLabels(prefs, acceso) }

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
