//
//  ModelService.swift
//  ScaboMacKit
//
//  Il servizio dei modelli dietro un'INTERFACCIA. L'unica implementazione di questo giro è
//  `SimulatedModelService`, dichiarata simulata anche nell'interfaccia (`isSimulation`), così che nessuno —
//  né una vista, né un test, né chi legge il codice — possa scambiare un avanzamento finto per uno
//  scaricamento vero. La simulazione non tocca la rete e non scrive pesi su disco.
//
//  Sono REALI, perché costano poco e non toccano contenuti: lo spazio libero sul disco (`DiskSpace`) e la
//  disponibilità degli strumenti di sistema Apple (`AppleSystemTools`, in un file a parte).
//
//  Gli stati di una voce sono i cinque del mandato: non scaricato; in scaricamento con avanzamento e
//  annullamento; scaricato; rimozione con conferma e spazio liberato detto in parole; errore spiegato in
//  prosa con la via d'uscita (spazio insufficiente, connessione assente, scaricamento interrotto, file
//  danneggiato, Mac non compatibile, strumento di sistema non disponibile).
//

import Foundation

/// Lo stato di una voce del catalogo sul Mac dell'utente.
public enum ModelState: Equatable, Sendable {
    case nonScaricato
    case inScaricamento(percento: Int)
    case scaricato
    case rimozioneInCorso
    /// Per gli strumenti di sistema Apple: verificati disponibili / non disponibili su questo Mac.
    case sistemaDisponibile
    case sistemaNonDisponibile
    case errore(ModelError)

    /// Lo stato in parole (è ciò che VoiceOver legge nel riassunto della voce).
    public var inParole: String {
        switch self {
        case .nonScaricato: return Testi.statoNonScaricato
        case .inScaricamento(let p): return Testi.statoInScaricamento(p)
        case .scaricato: return Testi.statoScaricato
        case .rimozioneInCorso: return Testi.statoRimozioneInCorso
        case .sistemaDisponibile: return Testi.statoDisponibileSistema
        case .sistemaNonDisponibile: return Testi.statoNonDisponibileSistema
        case .errore(let e): return Testi.statoErrore(e.spiegazione)
        }
    }
}

/// I problemi possibili, ciascuno con spiegazione in prosa e via d'uscita (nel testo stesso).
public enum ModelError: Equatable, Sendable {
    case spazioInsufficiente(servono: Int64, liberi: Int64)
    case connessioneAssente
    case scaricamentoInterrotto
    case fileDanneggiato
    case macNonCompatibile(requisiti: ModelRequirements)
    case strumentoSistemaNonDisponibile
    case sconosciuto

    public var spiegazione: String {
        switch self {
        case .spazioInsufficiente(let s, let l): return Testi.erroreSpazioInsufficiente(ByteWords.describe(s), ByteWords.describe(l))
        case .connessioneAssente: return Testi.erroreConnessioneAssente
        case .scaricamentoInterrotto: return Testi.erroreScaricamentoInterrotto
        case .fileDanneggiato: return Testi.erroreFileDanneggiato
        case .macNonCompatibile(let r): return Testi.erroreMacNonCompatibile(Testi.requisitiInParole(r))
        case .strumentoSistemaNonDisponibile: return Testi.erroreStrumentoSistemaNonDisponibile
        case .sconosciuto: return Testi.erroreSconosciuto
        }
    }

    /// Vero se la via d'uscita è «Riprova».
    public var ammetteRiprova: Bool {
        switch self {
        case .spazioInsufficiente, .connessioneAssente, .scaricamentoInterrotto, .fileDanneggiato, .sconosciuto: return true
        case .macNonCompatibile, .strumentoSistemaNonDisponibile: return false
        }
    }
}

/// L'interfaccia del servizio. Tutte le chiamate avvengono sul main actor: lo stato alimenta direttamente le viste.
@MainActor
public protocol ModelService: AnyObject {
    /// VERO se scaricamento ed esecuzione sono simulati. Le viste lo mostrano all'utente.
    var isSimulation: Bool { get }
    var catalog: ModelCatalog { get }
    func state(of id: String) -> ModelState
    /// Avvia lo scaricamento (o, per gli strumenti di sistema, la verifica di disponibilità).
    func download(_ id: String)
    func cancelDownload(_ id: String)
    /// Rimuove dal disco (dopo la conferma dell'utente, che spetta alla vista).
    func remove(_ id: String)
    /// Riprova dopo un problema.
    func retry(_ id: String)
    /// Chiamata a ogni cambio di stato di una voce (già sul main actor).
    var onStateChange: ((String, ModelState) -> Void)? { get set }
}

/// Spazio libero sul disco: verifica REALE, economica, senza contenuti.
public enum DiskSpace {
    /// Byte disponibili per uso «importante» sul volume della cartella Home (nil se non leggibile).
    public static func freeBytes(at url: URL = FileManager.default.homeDirectoryForCurrentUser) -> Int64? {
        do {
            let values = try url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            return values.volumeAvailableCapacityForImportantUsage
        } catch {
            return nil
        }
    }
}

/// Implementazione SIMULATA: avanzamento finto a passi regolari, nessuna rete, nessun file di pesi.
/// Gli scenari di guasto si possono forzare per voce (`forcedFailure`) per provare i messaggi e gli annunci.
@MainActor
public final class SimulatedModelService: ModelService {

    public let isSimulation = true
    public let catalog: ModelCatalog
    public var onStateChange: ((String, ModelState) -> Void)?

    /// Guasto forzato alla prossima operazione su una voce (per prove e test).
    public var forcedFailure: [String: ModelError] = [:]
    /// Passo dell'avanzamento simulato (percento) e intervallo fra i passi.
    public var stepPercent = 10
    public var stepInterval: TimeInterval = 0.4
    /// Sorgente dello spazio libero (iniettabile nei test).
    public var freeBytesProvider: () -> Int64? = { DiskSpace.freeBytes() }
    /// Verifica degli strumenti di sistema (iniettabile nei test).
    public var systemToolProbe: (CatalogEntry) -> Bool = { AppleSystemTools.isAvailable($0) }
    /// Spazio simulato già occupato dalle voci scaricate.
    public private(set) var occupiedBytes: Int64 = 0

    private var states: [String: ModelState] = [:]
    private var timers: [String: Timer] = [:]

    public init(catalog: ModelCatalog) {
        self.catalog = catalog
        for e in catalog.voci {
            states[e.id] = e.motore == .sistemaApple ? .sistemaNonDisponibile : .nonScaricato
        }
    }

    deinit { }

    public func state(of id: String) -> ModelState { states[id] ?? .nonScaricato }

    private func set(_ id: String, _ s: ModelState) {
        states[id] = s
        onStateChange?(id, s)
    }

    public func download(_ id: String) {
        guard let entry = catalog.voci.first(where: { $0.id == id }) else { return }
        if entry.motore == .sistemaApple {
            // Verifica REALE, non simulata.
            let ok = systemToolProbe(entry)
            set(id, ok ? .sistemaDisponibile : .errore(.strumentoSistemaNonDisponibile))
            return
        }
        if let forced = forcedFailure.removeValue(forKey: id) {
            set(id, .errore(forced)); return
        }
        // Compatibilità e spazio: verifiche REALI anche nella simulazione.
        if !MacCompatibility.satisfies(entry.requisiti) {
            set(id, .errore(.macNonCompatibile(requisiti: entry.requisiti))); return
        }
        if let free = freeBytesProvider(), free < entry.dimensioneByte {
            set(id, .errore(.spazioInsufficiente(servono: entry.dimensioneByte, liberi: free))); return
        }
        set(id, .inScaricamento(percento: 0))
        let timer = Timer.scheduledTimer(withTimeInterval: stepInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick(id) }
        }
        timers[id] = timer
    }

    private func tick(_ id: String) {
        guard case .inScaricamento(let p) = state(of: id) else { stopTimer(id); return }
        let next = min(100, p + stepPercent)
        if next >= 100 {
            stopTimer(id)
            occupiedBytes += catalog.voci.first(where: { $0.id == id })?.dimensioneByte ?? 0
            set(id, .scaricato)
        } else {
            set(id, .inScaricamento(percento: next))
        }
    }

    /// Avanza la simulazione senza aspettare il timer (per i test).
    public func advanceForTesting(_ id: String, steps: Int = 1) {
        for _ in 0..<steps { tick(id) }
    }

    public func cancelDownload(_ id: String) {
        guard case .inScaricamento = state(of: id) else { return }
        stopTimer(id)
        set(id, .nonScaricato)
    }

    public func remove(_ id: String) {
        guard case .scaricato = state(of: id) else { return }
        set(id, .rimozioneInCorso)
        occupiedBytes -= catalog.voci.first(where: { $0.id == id })?.dimensioneByte ?? 0
        set(id, .nonScaricato)
    }

    public func retry(_ id: String) {
        guard case .errore(let e) = state(of: id) else { return }
        guard e.ammetteRiprova else { return }
        set(id, .nonScaricato)
        download(id)
    }

    private func stopTimer(_ id: String) {
        timers[id]?.invalidate()
        timers[id] = nil
    }
}

/// Compatibilità del Mac con i requisiti dichiarati: verifica REALE (versione di sistema, architettura).
public enum MacCompatibility {
    public static func satisfies(_ r: ModelRequirements) -> Bool {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        let parts = r.macOSMinimo.split(separator: ".").compactMap { Int($0) }
        let min = (parts.first ?? 0, parts.count > 1 ? parts[1] : 0)
        if (v.majorVersion, v.minorVersion) < min { return false }
        if r.richiedeAppleSilicon && !isAppleSilicon { return false }
        return true
    }

    public static var isAppleSilicon: Bool {
        #if arch(arm64)
        return true
        #else
        return false
        #endif
    }
}
