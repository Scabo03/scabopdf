//
//  RealModelService.swift
//  ScaboMacKit
//
//  IL SERVIZIO VERO DEI MODELLI (giro «costruzione della linea Mac», 2026-10-16; prende il posto della simulazione
//  nell'app). Le voci con `scaricamento` nel catalogo (oggi GLM-OCR) si scaricano DAVVERO: dall'indirizzo ufficiale con
//  la revisione fissata, attraverso il servizio XPC (l'unico con la rete), nel contenitore dell'app; ogni file resta
//  «parziale» finché dimensione e impronta non coincidono con quelle pubblicate, poi diventa definitivo; alla fine il
//  segno di verifica. Annullare o fallire non lascia nulla di incompleto sul disco. Rimuovere toglie tutto, cache
//  comprese. Heron è già incluso (stato «incluso»); le voci senza `scaricamento` non si scaricano da questa versione
//  (stato «non ancora scaricabile»). Gli strumenti di sistema Apple: verifica reale come prima.
//
//  I tre difetti di OCR Lab che questo servizio evita: (1) niente scritto dentro il pacchetto dell'app (tutto nel
//  contenitore); (2) la rimozione toglie tutto, cache comprese (`ModelStore.remove`); (3) nessun processo resta vivo:
//  il servizio di scaricamento esce alla chiusura della connessione e il lettore gira dentro l'app, solo durante la
//  verifica, liberando tutto alla fine.
//

import Foundation
import ScaboMacOCR
import ScaricatoreProtocollo

/// L'esito della verifica di un lettore scaricato sulla pagina di prova inclusa nell'app.
public enum EsitoVerifica: Equatable, Sendable {
    case riuscita(percento: Int, secondi: Int)
    case debole(percento: Int)
    case fallita

    public var prosa: String {
        switch self {
        case .riuscita(let p, let s): return Testi.esitoVerificaRiuscita(p, s)
        case .debole(let p): return Testi.esitoVerificaDebole(p)
        case .fallita: return Testi.esitoVerificaFallita
        }
    }
}

/// Un servizio che sa verificare un lettore scaricato.
@MainActor
public protocol ModelVerifying: AnyObject {
    func puoVerificare(_ id: String) -> Bool
    func verifica(_ id: String, completion: @escaping (EsitoVerifica) -> Void)
}

@MainActor
public final class RealModelService: ModelService, ModelVerifying {

    public let isSimulation = false
    public let catalog: ModelCatalog
    public var onStateChange: ((String, ModelState) -> Void)?
    public let store: ModelStore
    /// Il trasporto dei byte (in produzione il servizio XPC; nelle prove quello diretto).
    public var makeTransport: () -> DownloadTransport
    public var freeBytesProvider: () -> Int64? = { DiskSpace.freeBytes() }
    public var systemToolProbe: (CatalogEntry) -> Bool = { AppleSystemTools.isAvailable($0) }
    /// Soglia della verifica: accordo minimo delle parole con il testo atteso.
    nonisolated public static let sogliaVerifica = 0.9

    private var states: [String: ModelState] = [:]
    private var transports: [String: DownloadTransport] = [:]
    private var annullati: Set<String> = []

    public init(catalog: ModelCatalog, store: ModelStore = .standard(),
                makeTransport: @escaping () -> DownloadTransport = { XPCDownloadTransport() }) {
        self.catalog = catalog
        self.store = store
        self.makeTransport = makeTransport
        for e in catalog.voci {
            switch e.motore {
            case .sistemaApple: states[e.id] = .sistemaNonDisponibile
            case .inclusoNellApp: states[e.id] = .incluso
            default:
                if e.scaricamento != nil {
                    if store.isInstalled(e) { states[e.id] = .scaricato } else { store.togliParziali(e.id); states[e.id] = .nonScaricato }
                } else {
                    states[e.id] = .nonDisponibileQui
                }
            }
        }
    }

    public func state(of id: String) -> ModelState { states[id] ?? .nonDisponibileQui }

    private func set(_ id: String, _ s: ModelState) {
        states[id] = s
        onStateChange?(id, s)
    }

    private func entry(_ id: String) -> CatalogEntry? { catalog.voci.first { $0.id == id } }

    // MARK: Scaricamento

    public func download(_ id: String) {
        guard let entry = entry(id) else { return }
        if entry.motore == .sistemaApple {
            set(id, systemToolProbe(entry) ? .sistemaDisponibile : .errore(.strumentoSistemaNonDisponibile))
            return
        }
        guard let spec = entry.scaricamento else { return }
        if case .inScaricamento = state(of: id) { return }
        if !MacCompatibility.satisfies(entry.requisiti) {
            set(id, .errore(.macNonCompatibile(requisiti: entry.requisiti))); return
        }
        // Spazio: i pesi più un margine per il sistema (non si riempie il disco fino all'ultimo byte).
        let margine: Int64 = 1_000_000_000
        if let free = freeBytesProvider(), free < entry.dimensioneByte + margine {
            set(id, .errore(.spazioInsufficiente(servono: entry.dimensioneByte + margine, liberi: free))); return
        }
        annullati.remove(id)
        set(id, .inScaricamento(percento: 0))
        let transport = makeTransport()
        transports[id] = transport
        scaricaFile(entry, spec: spec, indice: 0, fatti: 0, transport: transport)
    }

    private func scaricaFile(_ entry: CatalogEntry, spec: ModelDownloadSpec, indice: Int, fatti: Int64, transport: DownloadTransport) {
        let id = entry.id
        guard indice < spec.file.count else { concludi(entry, transport: transport); return }
        let f = spec.file[indice]
        // Già verificato da un tentativo precedente: non si riscarica.
        if let sha = ModelStore.sha256Hex(of: store.file(id, f.nome)), sha == f.sha256 {
            scaricaFile(entry, spec: spec, indice: indice + 1, fatti: fatti + f.byte, transport: transport)
            return
        }
        guard let url = URL(string: f.indirizzo), let handle = try? store.apriParziale(id, f.nome) else {
            fallisci(id, .sconosciuto, transport: transport); return
        }
        let totale = entry.dimensioneByte
        transport.scarica(url, verso: handle, byteAttesi: f.byte, avanzamento: { [weak self] scritti in
            let p = Int(Double(fatti + scritti) * 100 / Double(max(1, totale)))
            Task { @MainActor [weak self] in self?.avanza(id, min(99, p)) }
        }, risposta: { [weak self] scritti, problema in
            try? handle.close()
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let problema {
                    if problema == ProblemaScaricamento.annullato || self.annullati.contains(id) {
                        self.store.togliParziali(id)
                        transport.chiudi()
                        self.transports[id] = nil
                        self.set(id, .nonScaricato)
                    } else {
                        let e: ModelError
                        switch problema {
                        case ProblemaScaricamento.rete: e = scritti > 0 ? .scaricamentoInterrotto : .connessioneAssente
                        case ProblemaScaricamento.troppiByte: e = .fileDanneggiato
                        case ProblemaScaricamento.rispostaNonValida: e = .fonteNonDisponibile
                        default: e = .sconosciuto
                        }
                        self.fallisci(id, e, transport: transport)
                    }
                    return
                }
                // Dimensione e impronta fuori dal thread principale (centinaia di megabyte).
                let store = self.store
                DispatchQueue.global(qos: .userInitiated).async {
                    let ok = store.confermaParziale(id, f)
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        if self.annullati.contains(id) {
                            self.store.togliParziali(id); transport.chiudi(); self.transports[id] = nil; self.set(id, .nonScaricato); return
                        }
                        if ok {
                            self.scaricaFile(entry, spec: spec, indice: indice + 1, fatti: fatti + f.byte, transport: transport)
                        } else {
                            self.fallisci(id, .fileDanneggiato, transport: transport)
                        }
                    }
                }
            }
        })
    }

    private func avanza(_ id: String, _ p: Int) {
        guard case .inScaricamento(let old) = state(of: id), p > old else { return }
        set(id, .inScaricamento(percento: p))
    }

    private func concludi(_ entry: CatalogEntry, transport: DownloadTransport) {
        transport.chiudi()
        transports[entry.id] = nil
        do {
            try store.scriviSegno(entry)
            set(entry.id, .scaricato)
        } catch {
            fallisci(entry.id, .sconosciuto, transport: transport)
        }
    }

    private func fallisci(_ id: String, _ e: ModelError, transport: DownloadTransport) {
        store.togliParziali(id)
        transport.chiudi()
        transports[id] = nil
        set(id, .errore(e))
    }

    public func cancelDownload(_ id: String) {
        guard case .inScaricamento = state(of: id) else { return }
        annullati.insert(id)
        transports[id]?.annulla()
    }

    public func remove(_ id: String) {
        guard case .scaricato = state(of: id) else { return }
        set(id, .rimozioneInCorso)
        store.remove(id)
        set(id, .nonScaricato)
    }

    public func retry(_ id: String) {
        guard case .errore(let e) = state(of: id), e.ammetteRiprova else { return }
        set(id, .nonScaricato)
        download(id)
    }

    // MARK: Verifica

    public func puoVerificare(_ id: String) -> Bool {
        guard let spec = entry(id)?.scaricamento, case .scaricato = state(of: id) else { return false }
        return spec.file.contains { $0.ruolo == "pesi" } && spec.file.contains { $0.ruolo == "proiettore" }
    }

    /// Legge la pagina di prova inclusa nell'app con il lettore scaricato e la confronta con il testo atteso.
    public func verifica(_ id: String, completion: @escaping (EsitoVerifica) -> Void) {
        guard puoVerificare(id), let spec = entry(id)?.scaricamento,
              let pesi = spec.file.first(where: { $0.ruolo == "pesi" }),
              let proiettore = spec.file.first(where: { $0.ruolo == "proiettore" }),
              let prova = GlmOcr.paginaDiProva else { completion(.fallita); return }
        let p = store.file(id, pesi.nome), m = store.file(id, proiettore.nome)
        let soglia = Self.sogliaVerifica
        DispatchQueue.global(qos: .userInitiated).async {
            let t0 = Date()
            let esito: EsitoVerifica
            if let lettura = try? GlmOcr.leggi(png: prova.png, pesi: p, proiettore: m) {
                let a = GlmOcr.accordo(letto: lettura.testo, atteso: prova.testo)
                let percento = Int((a * 100).rounded())
                esito = a >= soglia
                    ? .riuscita(percento: percento, secondi: max(1, Int(Date().timeIntervalSince(t0).rounded())))
                    : .debole(percento: percento)
            } else {
                esito = .fallita
            }
            Task { @MainActor in completion(esito) }
        }
    }
}
