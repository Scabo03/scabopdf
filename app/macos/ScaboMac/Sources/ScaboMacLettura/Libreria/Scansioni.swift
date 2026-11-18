//
//  Scansioni.swift
//  ScaboMacLettura — LE SCANSIONI NELL'IMPORTAZIONE DEL MAC (giro «modelli e scansioni», 2026-11-18; LAYER2 § 12.16, decisione
//  21). Sul Mac una scansione senza testo non si rifiuta più: la schermata dell'elaborazione dice che è una scansione e fa
//  scegliere il lettore («lettura delle scansioni»), preimpostato sul migliore secondo le misure del banco; poi la catena è
//  quella di sempre. L'iPad resta com'è, con il suo controllo e le sue parole.
//
//  Il lettore lo fornisce l'app (`FornitoreScansioni`): questo modulo non dipende da ScaboMacKit, dove vivono i modelli. Qui
//  stanno il riconoscimento rapido della scansione, la provenienza del testo per la riga della libreria e le parole.
//

import CoreGraphics
import Foundation
import PDFKit
import ScaboChain
import ScaboCore

/// Un lettore delle scansioni come lo vede l'importazione.
public struct LettoreDisponibile: Equatable, Sendable {
    public let id: String
    /// Il nome nelle parole dell'app (per esempio «lettura del testo di Apple», «GLM-OCR»).
    public let nome: String
    /// Una riga sul lettore, coi numeri delle misure (velocità e precisione).
    public let descrizione: String
    public let installato: Bool

    public init(id: String, nome: String, descrizione: String, installato: Bool) {
        self.id = id; self.nome = nome; self.descrizione = descrizione; self.installato = installato
    }
}

/// Da dove viene il testo di un libro letto da una scansione (senza testo del libro).
public struct ProvenienzaScansione: Codable, Equatable, Sendable {
    /// Il nome del lettore nelle parole dell'app.
    public var lettore: String
    /// L'id del lettore (per rielaborare con lo stesso).
    public var idLettore: String?
    public var pagineLette: Int
    public var pagine: Int

    public init(lettore: String, idLettore: String? = nil, pagineLette: Int, pagine: Int) {
        self.lettore = lettore; self.idLettore = idLettore; self.pagineLette = pagineLette; self.pagine = pagine
    }
}

/// Ciò che l'app dà all'importazione per leggere le scansioni.
@MainActor
public protocol FornitoreScansioni: AnyObject {
    /// I lettori, nell'ordine in cui la schermata li propone.
    var lettori: [LettoreDisponibile] { get }
    /// L'id del lettore preimpostato (il migliore fra quelli installati, secondo le misure del banco).
    var predefinito: String { get }
    /// Un estrattore nuovo per il lettore scelto (l'estrattore di PDFKit con le pagine senza testo lette dal lettore).
    func estrattore(lettore: String) -> ProgressReportingPdfExtractor
    /// Se l'estrattore non è partito per un motivo del lettore: il motivo in prosa e l'id dell'altro lettore da proporre.
    func problema(di estrattore: ProgressReportingPdfExtractor) -> (messaggio: String, altroLettore: String?)?
    /// Ciò che l'estrattore ha letto, per la riga della libreria e le informazioni sul libro.
    func provenienza(di estrattore: ProgressReportingPdfExtractor) -> ProvenienzaScansione?
    /// Apre il pannello dei modelli (per scaricare GLM-OCR).
    func apriPannelloModelli()
    /// Se il PDF ha scansioni da leggere (la regola sta col lettore): quante pagine senza testo su quante; nil = un PDF con testo,
    /// che si importa come sull'iPad, senza domande.
    func scansione(_ url: URL) -> (senzaTesto: Int, totale: Int)?
}

/// Il riconoscimento rapido di una scansione, prima di elaborare: le pagine senza alcun carattere nelle risorse (nessun
/// font, nemmeno nei moduli annidati). È solo la domanda della schermata: chi decide pagina per pagina è l'estrattore.
public enum RilevaScansione {

    public static func pagineSenzaTesto(_ url: URL) -> (senzaTesto: Int, totale: Int) {
        let r = indiciSenzaTesto(url)
        return (r.indici.count, r.totale)
    }

    /// Le pagine senza testo (0-based) e il numero delle pagine.
    public static func indiciSenzaTesto(_ url: URL) -> (indici: [Int], totale: Int) {
        guard let doc = CGPDFDocument(url as CFURL) else { return ([], 0) }
        let n = doc.numberOfPages
        var sospette: [Int] = []
        for i in 1...max(n, 1) where n > 0 {
            guard let page = doc.page(at: i), let dict = page.dictionary else { continue }
            if !haCaratteri(risorse(di: dict), profondita: 0) { sospette.append(i - 1) }
        }
        guard !sospette.isEmpty else { return ([], n) }
        // Le pagine sospette si confermano col testo di PDFKit (una pagina senza font nelle risorse ma col testo, per esempio
        // in una forma che il controllo rapido non vede, non è una scansione): niente domanda su un PDF con testo.
        guard let pdf = PDFDocument(url: url) else { return (sospette, n) }
        let senza = sospette.filter { k in
            (pdf.page(at: k)?.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return (senza, n)
    }

    /// Le risorse della pagina, anche ereditate dai nodi dell'albero delle pagine (`/Parent`), come vuole il formato PDF.
    static func risorse(di pagina: CGPDFDictionaryRef) -> CGPDFDictionaryRef? {
        var nodo: CGPDFDictionaryRef? = pagina
        for _ in 0..<32 {
            guard let d = nodo else { return nil }
            var r: CGPDFDictionaryRef?
            if CGPDFDictionaryGetDictionary(d, "Resources", &r) { return r }
            var genitore: CGPDFDictionaryRef?
            nodo = CGPDFDictionaryGetDictionary(d, "Parent", &genitore) ? genitore : nil
        }
        return nil
    }

    /// Vero se le risorse hanno almeno un font, direttamente o in un modulo (`Form`) annidato fino a tre livelli.
    static func haCaratteri(_ risorse: CGPDFDictionaryRef?, profondita: Int) -> Bool {
        guard let risorse else { return false }
        var fonts: CGPDFDictionaryRef?
        if CGPDFDictionaryGetDictionary(risorse, "Font", &fonts), let fonts, CGPDFDictionaryGetCount(fonts) > 0 { return true }
        guard profondita < 3 else { return false }
        var xobj: CGPDFDictionaryRef?
        guard CGPDFDictionaryGetDictionary(risorse, "XObject", &xobj), let xobj else { return false }
        final class Esito { var trovato = false; let profondita: Int; init(_ p: Int) { profondita = p } }
        let esito = Esito(profondita)
        CGPDFDictionaryApplyBlock(xobj, { _, valore, info in
            let e = Unmanaged<Esito>.fromOpaque(info!).takeUnretainedValue()
            var stream: CGPDFStreamRef?
            guard CGPDFObjectGetValue(valore, .stream, &stream), let stream, let d = CGPDFStreamGetDictionary(stream) else { return true }
            var tipo: UnsafePointer<Int8>?
            guard CGPDFDictionaryGetName(d, "Subtype", &tipo), let tipo, String(cString: tipo) == "Form" else { return true }
            var r: CGPDFDictionaryRef?
            if CGPDFDictionaryGetDictionary(d, "Resources", &r), RilevaScansione.haCaratteri(r, profondita: e.profondita + 1) {
                e.trovato = true; return false
            }
            return true
        }, Unmanaged.passUnretained(esito).toOpaque())
        return esito.trovato
    }
}

/// Le provenienze dei libri letti da scansioni, in un file della libreria del Mac (`ScaboMac/scansioni.json`), fuori dal
/// formato della libreria condiviso con l'iPad.
public final class ProvenienzeScansioni {
    private let url: URL
    private(set) var voci: [String: ProvenienzaScansione]

    public init(service: LibraryService) {
        let radice = service.archivedPDFURL(forDocumentId: "_").deletingLastPathComponent().deletingLastPathComponent()
        url = radice.appendingPathComponent("ScaboMac", isDirectory: true).appendingPathComponent("scansioni.json")
        voci = (try? JSONDecoder().decode([String: ProvenienzaScansione].self, from: Data(contentsOf: url))) ?? [:]
    }

    public func provenienza(_ id: String) -> ProvenienzaScansione? { voci[id] }

    public func registra(_ p: ProvenienzaScansione, per id: String) {
        voci[id] = p
        salva()
    }

    public func togli(_ id: String) {
        guard voci.removeValue(forKey: id) != nil else { return }
        salva()
    }

    private func salva() {
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        try? enc.encode(voci).write(to: url, options: .atomic)
    }
}

/// Le parole delle scansioni (VoiceOver prima di tutto; «lettura delle scansioni», mai la sigla).
public enum ParoleScansioni {
    public static let titolo = "È una scansione"
    public static func spiegazione(nome: String, senzaTesto: Int, totale: Int) -> String {
        let quante = senzaTesto == totale
            ? (totale == 1 ? "La sua pagina non ha testo" : "Nessuna delle sue \(totale) pagine ha testo")
            : (senzaTesto == 1 ? "Una pagina su \(totale) non ha testo" : "\(senzaTesto) pagine su \(totale) non hanno testo")
        return "«\(nome)» è una scansione. \(quante): le legge la lettura delle scansioni, qui sul Mac, senza mandare nulla in "
            + "rete. Poi il libro si prepara come ogni altro."
    }
    public static let sceltaLettore = "Leggi le scansioni con"
    public static let avvia = "Avvia"
    public static let annulla = "Annulla"
    public static let apriPannello = "Apri il pannello dei modelli…"
    public static func nonInstallato(_ nome: String) -> String {
        "\(nome) non è installato: puoi scaricarlo dal pannello dei modelli."
    }
    /// L'etichetta della fase d'estrazione quando la si fa con un lettore.
    public static let faseLettura = "Lettura delle scansioni"
    /// L'etichetta della fase d'estrazione della catena condivisa (quella che, per una scansione, diventa `faseLettura`).
    public static var faseEstrazioneCatena: String {
        DocumentProcessor.Progress(phase: .extraction, unitsDone: 0, unitsTotal: 0, fraction: 0).phaseLabel
    }
    public static let altroLettoreTitolo = "La lettura delle scansioni non è partita"
    public static func leggiCon(_ nome: String) -> String { "Leggi con la \(nome)" }
    public static func leggiConNome(_ nome: String) -> String { nome.hasPrefix("lettura") ? leggiCon(nome) : "Leggi con \(nome)" }
    /// Ciò che la riga della libreria e le informazioni sul libro aggiungono.
    public static func riga(_ p: ProvenienzaScansione) -> String {
        p.pagineLette >= p.pagine
            ? "testo da una scansione, letto con \(articolato(p.lettore))"
            : "\(p.pagineLette == 1 ? "una pagina" : "\(p.pagineLette) pagine") da una scansione, lette con \(articolato(p.lettore))"
    }
    static func articolato(_ nome: String) -> String { nome.hasPrefix("lettura") ? "la \(nome)" : nome }
}
