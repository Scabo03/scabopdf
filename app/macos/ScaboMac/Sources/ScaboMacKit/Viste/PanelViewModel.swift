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
    /// Spiegazione in prosa di un problema del catalogo all'avvio (nil se il catalogo è valido): la vista la mostra in testa.
    @Published public private(set) var problemaCatalogo: String?
    @Published public private(set) var spazioLiberoInParole: String = Testi.spazioLiberoSconosciuto
    /// Voce di cui si sta chiedendo conferma di rimozione (nil = nessuna).
    @Published public var confermaRimozionePer: String?
    /// Voce di cui si sta chiedendo conferma dello scaricamento VERO (nil = nessuna): dimensione e fonte dette prima.
    @Published public var confermaScaricamentoPer: String?
    /// Voci in verifica sulla pagina di prova, e l'ultimo esito in prosa per voce.
    @Published public private(set) var verificheInCorso: Set<String> = []
    @Published public private(set) var esitiVerifica: [String: String] = [:]
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
                prefs: KeyValueStore = UserDefaultsKeyValueStore(), problemaCatalogo: String? = nil) {
        self.problemaCatalogo = problemaCatalogo
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
    /// Lo scaricamento vero si chiede prima, con la dimensione e la fonte in prosa (giro del 2026-10-16).
    public func chiediScaricamento(_ id: String) {
        confermaScaricamentoPer = id
        richiediFocusSullaDomanda(id)
    }
    /// Il fuoco di VoiceOver va sulla domanda appena comparsa (al giro successivo, quando la vista esiste già).
    private func richiediFocusSullaDomanda(_ id: String) {
        DispatchQueue.main.async { [weak self] in
            // Solo se la domanda c'è ancora (annullata nel frattempo: il fuoco resta dov'è).
            guard let self, self.confermaScaricamentoPer == id || self.confermaRimozionePer == id else { return }
            self.focusRichiesto = Self.idDomanda(id)
        }
    }
    /// L'identificativo di fuoco della domanda di conferma di una voce.
    public static func idDomanda(_ id: String) -> String { "conferma.\(id)" }
    public func confermaScaricamento() {
        guard let id = confermaScaricamentoPer else { return }
        confermaScaricamentoPer = nil
        service.download(id)
    }
    public func annullaScaricamentoChiesto() {
        let id = confermaScaricamentoPer
        confermaScaricamentoPer = nil
        focusRichiesto = id
    }
    /// La domanda di conferma dello scaricamento, con dimensione, editore e revisione.
    public func domandaScaricamento(_ entry: CatalogEntry) -> String {
        Testi.azioneScaricaDomanda(entry.nome, entry.dimensioneInParole, entry.provenienza.editore,
                                   String((entry.scaricamento?.revisione ?? "").prefix(8)))
    }
    /// Verifica il lettore scaricato sulla pagina di prova inclusa nell'app; l'esito si dice e si annuncia.
    public func verifica(_ id: String) {
        guard let v = service as? ModelVerifying, v.puoVerificare(id), !verificheInCorso.contains(id),
              let entry = catalog.voci.first(where: { $0.id == id }) else { return }
        verificheInCorso.insert(id)
        esitiVerifica[id] = nil
        // Una domanda di rimozione ancora aperta per questa voce si chiude: i file servono alla verifica.
        if confermaRimozionePer == id { confermaRimozionePer = nil }
        announcer.announce(Testi.annuncioVerificaAvviata(entry.nome), priority: .normale)
        v.verifica(id) { [weak self] esito in
            guard let self else { return }
            self.verificheInCorso.remove(id)
            self.esitiVerifica[id] = esito.prosa
            self.announcer.announce(esito.prosa, priority: .alta)
            self.focusRichiesto = id
        }
    }
    public func annulla(_ id: String) { service.cancelDownload(id) }
    public func riprova(_ id: String) { service.retry(id) }
    public func chiediRimozione(_ id: String) {
        confermaRimozionePer = id
        richiediFocusSullaDomanda(id)
    }
    public func confermaRimozione() {
        guard let id = confermaRimozionePer else { return }
        confermaRimozionePer = nil
        // Mai togliere i file mentre la verifica li sta leggendo (revisione indipendente del giro).
        guard !verificheInCorso.contains(id) else { focusRichiesto = id; return }
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
        case .scaricato:
            if let v = service as? ModelVerifying, v.puoVerificare(entry.id) {
                return verificheInCorso.contains(entry.id) ? [] : [.verificaFunzionamento, .rimuovi]
            }
            return [.rimuovi]
        case .rimozioneInCorso: return []
        case .sistemaDisponibile, .sistemaNonDisponibile: return [.verificaSistema]
        case .errore(let e): return e.ammetteRiprova ? [.riprova] : (entry.motore == .sistemaApple ? [.verificaSistema] : [])
        case .incluso, .nonDisponibileQui: return []
        }
    }

    public enum Azione: Equatable {
        case scarica, annulla, rimuovi, riprova, verificaSistema, verificaFunzionamento
        public var etichetta: String {
            switch self {
            case .verificaFunzionamento: return Testi.azioneVerificaFunzionamento
            case .scarica: return Testi.azioneScarica
            case .annulla: return Testi.azioneAnnulla
            case .rimuovi: return Testi.azioneRimuovi
            case .riprova: return Testi.azioneRiprova
            case .verificaSistema: return Testi.azioneVerificaSistema
            }
        }
    }

    public func esegui(_ azione: Azione, su entry: CatalogEntry) {
        // Il ruolo su cui l'utente lavora viene ricordato fra le sessioni (la vista vi riporta il focus all'apertura).
        if ruoloAperto != entry.ruolo { ruoloAperto = entry.ruolo }
        switch azione {
        case .scarica:
            // Scaricamento vero: prima la conferma con dimensione e fonte; strumenti di sistema e simulazione: subito.
            if !service.isSimulation, entry.scaricamento != nil { chiediScaricamento(entry.id) } else { scarica(entry.id) }
        case .verificaSistema: scarica(entry.id)
        case .verificaFunzionamento: verifica(entry.id)
        case .annulla: annulla(entry.id)
        case .rimuovi: chiediRimozione(entry.id)
        case .riprova: riprova(entry.id)
        }
    }
}
