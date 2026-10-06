//
//  PanelViewModel.swift
//  ScaboMacKit
//
//  Il modello della vista del pannello: tiene il catalogo, gli stati per voce, l'ultima verifica dello
//  spazio libero, e traduce i cambi di stato in annunci tramite `Announcing` + `AnnouncementPolicy`.
//  È `ObservableObject` (non `@Observable`) per restare dentro macOS 14 senza macro.
//

import Combine
import Foundation
import ScaboCore

@MainActor
public final class PanelViewModel: ObservableObject {

    public let service: ModelService
    public let announcer: Announcing
    public let policy: AnnouncementPolicy
    /// Preferenze riusate da ScaboCore (stesso confine `KeyValueStore` dell'app iOS).
    public let prefs: KeyValueStore

    @Published public private(set) var states: [String: ModelState] = [:]
    @Published public private(set) var spazioLiberoInParole: String = Testi.spazioLiberoSconosciuto
    /// Voce di cui si sta chiedendo conferma di rimozione (nil = nessuna).
    @Published public var confermaRimozionePer: String?
    /// Voce che deve ricevere il focus dopo un cambio di stato (le viste lo consumano).
    @Published public var focusRichiesto: String?
    /// Ultimo ruolo aperto dall'utente (ricordato fra le sessioni).
    @Published public var ruoloAperto: ModelRole? {
        didSet { prefs.setItem(Self.chiaveRuoloAperto, ruoloAperto?.rawValue ?? "") }
    }

    public static let chiaveRuoloAperto = "@scabopdf/mac/strumenti/ruoloAperto"

    public var catalog: ModelCatalog { service.catalog }
    public var isSimulation: Bool { service.isSimulation }

    public init(service: ModelService, announcer: Announcing, policy: AnnouncementPolicy = AnnouncementPolicy(),
                prefs: KeyValueStore = UserDefaultsKeyValueStore()) {
        self.service = service
        self.announcer = announcer
        self.policy = policy
        self.prefs = prefs
        for e in service.catalog.voci { states[e.id] = service.state(of: e.id) }
        if let raw = prefs.getItem(Self.chiaveRuoloAperto), let r = ModelRole(rawValue: raw) { ruoloAperto = r }
        service.onStateChange = { [weak self] id, new in self?.didChange(id, new) }
        aggiornaSpazioLibero()
    }

    private func didChange(_ id: String, _ new: ModelState) {
        let old = states[id]
        states[id] = new
        if let entry = catalog.voci.first(where: { $0.id == id }),
           let (testo, pr) = policy.annuncio(per: entry, da: old, a: new) {
            announcer.announce(testo, priority: pr)
        }
        // Dopo un cambio di stato il focus resta sulla voce: la vista lo riporta sul suo pulsante principale.
        switch new {
        case .inScaricamento(let p) where p > 0: break
        default: focusRichiesto = id
        }
        if case .scaricato = new { aggiornaSpazioLibero() }
        if old == .rimozioneInCorso { aggiornaSpazioLibero() }
    }

    public func aggiornaSpazioLibero() {
        if let free = DiskSpace.freeBytes() {
            spazioLiberoInParole = Testi.spazioLibero(ByteWords.describe(free))
        } else {
            spazioLiberoInParole = Testi.spazioLiberoSconosciuto
        }
    }

    public func state(of id: String) -> ModelState { states[id] ?? service.state(of: id) }

    // MARK: Azioni dell'utente

    public func scarica(_ id: String) { service.download(id) }
    public func annulla(_ id: String) { service.cancelDownload(id) }
    public func riprova(_ id: String) { service.retry(id) }
    public func chiediRimozione(_ id: String) { confermaRimozionePer = id }
    public func confermaRimozione() {
        guard let id = confermaRimozionePer else { return }
        confermaRimozionePer = nil
        service.remove(id)
    }
    public func annullaRimozione() {
        let id = confermaRimozionePer
        confermaRimozionePer = nil
        focusRichiesto = id
    }

    /// Le azioni disponibili per una voce nel suo stato corrente (la vista le rende come pulsanti; i test le verificano).
    public func azioni(per entry: CatalogEntry) -> [Azione] {
        switch state(of: entry.id) {
        case .nonScaricato:
            return entry.motore == .sistemaApple ? [.verificaSistema] : [.scarica]
        case .inScaricamento: return [.annulla]
        case .scaricato: return [.rimuovi]
        case .rimozioneInCorso: return []
        case .sistemaDisponibile, .sistemaNonDisponibile: return [.verificaSistema]
        case .errore(let e): return e.ammetteRiprova ? [.riprova] : (entry.motore == .sistemaApple ? [.verificaSistema] : [])
        }
    }

    public enum Azione: Equatable {
        case scarica, annulla, rimuovi, riprova, verificaSistema
        public var etichetta: String {
            switch self {
            case .scarica: return Testi.azioneScarica
            case .annulla: return Testi.azioneAnnulla
            case .rimuovi: return Testi.azioneRimuovi
            case .riprova: return Testi.azioneRiprova
            case .verificaSistema: return Testi.azioneVerificaSistema
            }
        }
    }

    public func esegui(_ azione: Azione, su entry: CatalogEntry) {
        switch azione {
        case .scarica, .verificaSistema: scarica(entry.id)
        case .annulla: annulla(entry.id)
        case .rimuovi: chiediRimozione(entry.id)
        case .riprova: riprova(entry.id)
        }
    }
}
