//
//  ProvaPannello.swift
//  ScaboMacKit
//
//  PROVA DI LABORATORIO DEL PANNELLO VERO (giro «costruzione della linea Mac», 2026-10-16). Parte SOLO se l'app è
//  avviata con l'argomento `-ScaboMacProvaPannello` (mai da sola, mai per l'utente): senza la modalità di automazione
//  dell'interfaccia (richiede la password di amministratore, che in questo giro non si chiede) è il modo di provare il
//  percorso reale nell'app firmata e con la sandbox: scaricamento di GLM-OCR attraverso il servizio XPC nel contenitore,
//  avanzamento annunciato, controllo delle impronte, «Verifica» sulla pagina di prova, rimozione con le cache. Usa gli
//  stessi oggetti del pannello (PanelViewModel, RealModelService); scrive un referto PRIVO DI TESTO nel contenitore
//  (`Application Support/ScaboPDF per Mac/prova_pannello.json`) e chiude l'app.
//

import AppKit
import Foundation
import ScaboCore

@MainActor
public enum ProvaPannello {

    public static let argomento = "-ScaboMacProvaPannello"
    public static var richiesta: Bool { CommandLine.arguments.contains(argomento) }

    struct Referto: Codable {
        var inizio: Date
        var voce: String
        var statoIniziale: String
        var annunci: [String] = []
        var statoDopoScaricamento = ""
        var secondiScaricamento = 0.0
        var file: [[String: String]] = []
        var esitoVerifica = ""
        var statoDopoRimozione = ""
        var cartellaModelliDopoRimozione = true
        /// Cache del motore (cartelle note) con i loro byte, dopo la verifica e dopo la rimozione.
        var cacheMotorePrimaDellaRimozione: [String: Int64] = [:]
        var cacheMotoreDopoLaRimozione: [String: Int64] = [:]
        var fine: Date?
    }

    /// Le cartelle di cache del motore che esistono, con i byte che contengono (nomi abbreviati, nessun testo).
    static func cacheMotore(_ store: ModelStore) -> [String: Int64] {
        var out: [String: Int64] = [:]
        for c in store.cacheRoots where FileManager.default.fileExists(atPath: c.path) {
            var tot: Int64 = 0
            if let e = FileManager.default.enumerator(at: c, includingPropertiesForKeys: [.fileSizeKey]) {
                for case let u as URL in e { tot += Int64((try? u.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
            }
            out[c.deletingLastPathComponent().lastPathComponent + "/" + c.lastPathComponent] = tot
        }
        return out
    }

    /// Esegue la prova sulla voce `id` e chiude l'app.
    public static func esegui(catalog: ModelCatalog, id: String = "glm-ocr") {
        let annunci = RecordingAnnouncer()
        let service = RealModelService(catalog: catalog)
        let model = PanelViewModel(service: service, announcer: annunci, prefs: InMemoryKeyValueStore())
        var r = Referto(inizio: Date(), voce: id, statoIniziale: model.state(of: id).inParole)
        let refertoURL = service.store.root.deletingLastPathComponent().appendingPathComponent("prova_pannello.json")
        func scrivi() {
            r.annunci = annunci.testi
            try? FileManager.default.createDirectory(at: refertoURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]; enc.dateEncodingStrategy = .iso8601
            try? enc.encode(r).write(to: refertoURL, options: .atomic)
        }
        Task { @MainActor in
            // 1. Scaricamento vero (la conferma della vista qui è già data: è la prova del laboratorio).
            let t0 = Date()
            if model.state(of: id) != .scaricato { model.scarica(id) }
            while true {
                try? await Task.sleep(nanoseconds: 500_000_000)
                switch model.state(of: id) {
                case .inScaricamento: continue
                default: break
                }
                break
            }
            r.secondiScaricamento = Date().timeIntervalSince(t0)
            r.statoDopoScaricamento = model.state(of: id).inParole
            if let spec = catalog.voci.first(where: { $0.id == id })?.scaricamento {
                for f in spec.file {
                    let u = service.store.file(id, f.nome)
                    let size = ((try? FileManager.default.attributesOfItem(atPath: u.path))?[.size] as? NSNumber)?.int64Value ?? -1
                    r.file.append(["nome": f.nome, "byte": String(size), "impronta coincide": String(ModelStore.sha256Hex(of: u) == f.sha256)])
                }
            }
            scrivi()
            // 2. Verifica sulla pagina di prova.
            if model.state(of: id) == .scaricato {
                model.verifica(id)
                while model.verificheInCorso.contains(id) { try? await Task.sleep(nanoseconds: 500_000_000) }
                r.esitoVerifica = model.esitiVerifica[id] ?? ""
                r.cacheMotorePrimaDellaRimozione = cacheMotore(service.store)
                scrivi()
                // 3. Rimozione, come dal pannello (richiesta e conferma).
                model.chiediRimozione(id)
                model.confermaRimozione()
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
            r.statoDopoRimozione = model.state(of: id).inParole
            r.cartellaModelliDopoRimozione = FileManager.default.fileExists(atPath: service.store.root.path)
            r.cacheMotoreDopoLaRimozione = cacheMotore(service.store)
            r.fine = Date()
            scrivi()
            NSApp.terminate(nil)
        }
    }
}
