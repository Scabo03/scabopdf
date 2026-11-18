//
//  Fornitori.swift
//  ScaboMac — ciò che l'app dà alla lettura del Mac (ScaboMacLettura) dai modelli (ScaboMacKit), che il modulo della lettura non
//  vede (giro «modelli e scansioni», 2026-11-18): il lettore delle scansioni per l'importazione e la preparazione della lettura
//  migliore per i libri della libreria (LAYER2 § 12.16, decisioni 20 e 21).
//

import AppKit
import ScaboChain
import ScaboCore
import ScaboMacKit
import ScaboMacLettura

/// Le parole dei lettori nella schermata della scansione, con i numeri del banco delle scansioni (238 pagine, referto del giro
/// «modelli e scansioni», § 2 e § 9): la lettura di Apple circa 0,3 secondi a pagina; GLM lettura pagine circa 11, con meno della
/// metà delle lettere sbagliate (0,21 contro 0,45 per cento), un terzo delle cifre sbagliate e meno parole inventate.
enum MisureLettori {
    static let descrizioneApple = "veloce, meno di un secondo a pagina; già nel sistema"
    static let descrizioneGlm = "più preciso, sbaglia meno della metà delle lettere; circa undici secondi a pagina; chiede circa 8 gigabyte di memoria libera"
    /// Il lettore preimpostato: il migliore per qualità secondo il banco, se è installato (altrimenti la lettura di Apple).
    static let predefinito = LettoreScansioni.glm
}

@MainActor
final class FornitoreScansioniApp: FornitoreScansioni {
    private let catalogo: ModelCatalog
    private let store = ModelStore.standard()
    weak var comandi: ComandiApp?

    init(catalogo: ModelCatalog) { self.catalogo = catalogo }

    /// I due file di GLM lettura pagine nel contenitore, se la voce è installata e verificata.
    var pesiGlm: (pesi: URL, proiettore: URL)? {
        guard let voce = catalogo.voci.first(where: { $0.id == LettoreScansioni.glm.voceCatalogo }), store.isInstalled(voce),
              let file = voce.scaricamento?.file,
              let pesi = file.first(where: { $0.ruolo == "pesi" }), let proj = file.first(where: { $0.ruolo != "pesi" }) else { return nil }
        return (store.file(voce.id, pesi.nome), store.file(voce.id, proj.nome))
    }

    var lettori: [LettoreDisponibile] {
        [LettoreDisponibile(id: LettoreScansioni.apple.rawValue, nome: LettoreScansioni.apple.nome,
                            descrizione: MisureLettori.descrizioneApple, installato: true),
         LettoreDisponibile(id: LettoreScansioni.glm.rawValue, nome: LettoreScansioni.glm.nome,
                            descrizione: MisureLettori.descrizioneGlm, installato: pesiGlm != nil)]
    }

    var predefinito: String {
        MisureLettori.predefinito == .glm && pesiGlm == nil ? LettoreScansioni.apple.rawValue : MisureLettori.predefinito.rawValue
    }

    func estrattore(lettore: String) -> ProgressReportingPdfExtractor {
        let l = LettoreScansioni(rawValue: lettore) ?? .apple
        return EstrattoreScansioni(lettore: l, pesiGlm: l == .glm ? pesiGlm : nil)
    }

    func problema(di estrattore: ProgressReportingPdfExtractor) -> (messaggio: String, altroLettore: String?)? {
        guard let e = estrattore as? EstrattoreScansioni, let p = e.problema else { return nil }
        let altro = p.propostaAltroLettore ? (e.lettore == .glm ? LettoreScansioni.apple.rawValue : nil) : nil
        return (p.localizedDescription, altro)
    }

    func provenienza(di estrattore: ProgressReportingPdfExtractor) -> ProvenienzaScansione? {
        guard let e = estrattore as? EstrattoreScansioni, let r = e.rapporto, r.pagineLette > 0 else { return nil }
        return ProvenienzaScansione(lettore: r.lettore.nome, idLettore: r.lettore.rawValue, pagineLette: r.pagineLette, pagine: r.pagine)
    }

    func apriPannelloModelli() { comandi?.mostraModelliEOfficina(nil) }

    func scansione(_ url: URL) -> (senzaTesto: Int, totale: Int)? {
        let r = RilevaScansione.indiciSenzaTesto(url)
        return EstrattoreScansioni.serveLettura(senzaTesto: r.indici, totale: r.totale) ? (r.indici.count, r.totale) : nil
    }
}

@MainActor
final class FornitoreLetturaMiglioreApp: FornitoreLetturaMigliore {
    private let scansioni: FornitoreScansioniApp
    static let ruoloStruttura = "Struttura della pagina"
    static let ruoloScansioni = "Lettura delle scansioni"

    init(scansioni: FornitoreScansioniApp) { self.scansioni = scansioni }

    func ruoli(pdf: URL) -> [RuoloModello] {
        var r = [RuoloModello(ruolo: Self.ruoloStruttura, scelte: [("docling-layout-heron", "Struttura di pagina di docling (Heron)")],
                              predefinito: "docling-layout-heron",
                              nota: "Inclusa nell'app: riconosce le zone della pagina, come l'indice analitico, le tabelle e le figure.")]
        if scansioni.scansione(pdf) != nil {
            let installati = scansioni.lettori.filter(\.installato)
            let mancante = scansioni.lettori.first { !$0.installato }
            r.append(RuoloModello(ruolo: Self.ruoloScansioni, scelte: installati.map { ($0.id, $0.nome.prefix(1).uppercased() + $0.nome.dropFirst()) },
                                  predefinito: scansioni.predefinito,
                                  nota: mancante.map { ParoleScansioni.nonInstallato($0.nome.prefix(1).uppercased() + $0.nome.dropFirst()) }))
        }
        return r
    }

    func prepara(pdf: URL, scelte: [String: String], granularita: Int,
                 completion: @escaping (Result<(lettura: PackagedReading, righe: [String]), Error>) -> Void) {
        let estrattore: ProgressReportingPdfExtractor = scelte[Self.ruoloScansioni].map { scansioni.estrattore(lettore: $0) } ?? PdfKitExtractor()
        DispatchQueue.global(qos: .utility).async {
            let out = MacProcessor.process(pdfURL: pdf, policy: .giro, granularityTarget: granularita, extractor: estrattore)
            DispatchQueue.main.async {
                switch out {
                case .ready(let r): completion(.success((r.reading, Self.righe(r.report))))
                case .cancelled: completion(.failure(Errore("La preparazione è stata annullata.")))
                case .failure(let m): completion(.failure(Errore(m)))
                }
            }
        }
    }

    /// Ciò che l'officina ha fatto in più, nelle parole dell'iPad (ScaboApp `ReadingFromMac.whatArrives`).
    nonisolated static func righe(_ r: OfficinaReport) -> [String] {
        var righe: [String] = []
        let n = r.stitches.count
        if n > 0 { righe.append(n == 1 ? "ha ricucito una nota spezzata fra due pagine" : "ha ricucito \(n) note spezzate fra due pagine") }
        if r.relabels > 0 {
            righe.append(r.relabels == 1 ? "legge come testo dell'indice una voce che prima era letta come nota"
                         : "legge come testo dell'indice \(r.relabels) voci che prima erano lette come note")
        }
        return righe
    }

    struct Errore: LocalizedError {
        let messaggio: String
        init(_ m: String) { messaggio = m }
        var errorDescription: String? { messaggio }
    }
}
