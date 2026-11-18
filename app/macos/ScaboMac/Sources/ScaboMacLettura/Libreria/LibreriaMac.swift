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
    /// Avvisa, prima di cambiarla, che la lettura di un libro sta per cambiare (lettura migliore usata, ritorno a quella di prima):
    /// chi tiene la sua finestra di lettura la chiude, così la posizione salvata è della lettura giusta.
    public var quandoCambiaLettura: [(String) -> Void] = []

    /// Da dove viene il testo dei libri letti da scansioni (giro «modelli e scansioni», 2026-11-18).
    public let provenienze: ProvenienzeScansioni
    /// Le letture migliori pronte e in attesa della scelta (LAYER2 § 12.16, decisione 20).
    public let offerte: OfferteMigliori
    /// I libri per cui una lettura migliore si sta preparando.
    public internal(set) var inPreparazione: Set<String> = []

    public init(service: LibraryService) {
        self.service = service
        provenienze = ProvenienzeScansioni(service: service)
        offerte = OfferteMigliori(service: service)
    }

    /// Ciò che la riga del libro dice: le parole della riga dell'iPad, più la provenienza della scansione e il segno
    /// dell'offerta (o della preparazione in corso).
    public func rigaDelLibro(_ d: ArchivedDocument) -> String {
        var parti = [LibraryFormatting.fileAccessibility(d)]
        if let p = provenienze.provenienza(d.id) { parti.append(ParoleScansioni.riga(p)) }
        if offerte.libri.contains(d.id) { parti.append(ParoleLetturaMigliore.segnoRiga) }
        else if inPreparazione.contains(d.id) { parti.append(ParoleLetturaMigliore.segnoPreparazione) }
        return parti.joined(separator: ", ")
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
        provenienze.togli(id)
        offerte.togli(id)
        avvisa()
    }

    public func avvisa() { for f in quandoCambia { f() } }
}
