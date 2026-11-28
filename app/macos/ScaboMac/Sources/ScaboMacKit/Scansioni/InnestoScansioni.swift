//
//  InnestoScansioni.swift
//  ScaboMacKit — IL TESTO DELLE SCANSIONI MONTATO SULLE REGIONI DI HERON (giro «scansioni, ricerca e build», 2026-11-28; LAYER2 § 12.16,
//  decisione 30; misure in docs/BANCO_OCR.md § 48).
//
//  Sulle pagine lette il modello d'impaginazione (Heron) vede la pagina; la catena condivisa, invece, classifica le righe con la
//  tipografia, che su una scansione è stimata (il corpo dalla larghezza dei caratteri, nessun carattere vero). Al banco il collante del
//  laboratorio, che tiene le regioni e i tipi di Heron, perde un quinto delle parole che perde la catena, ma lega le note ai richiami peggio
//  (17 contro 35): la catena le lega bene. Qui le due cose insieme, nel punto d'innesto del Mac (`ChainGraft`: dopo la classificazione,
//  prima dell'aggancio delle note), solo dove il banco ha misurato che la catena sbaglia e Heron no, e senza scrivere testo:
//
//  * COLONNE (miglioria `colonne`). Un nodo che la catena chiama glossa a margine (e non legge) ma le cui righe stanno DENTRO regioni di
//    Heron larghe almeno un terzo della pagina è una colonna di testo, non un margine: diventa corpo, o NOTA se la maggior parte di quelle
//    righe sta in regioni che Heron etichetta «footnote» (sulle pagine dei codici a due colonne la nota che comincia in
//    fondo alla prima colonna continua in cima alla seconda; da corpo la si sentirebbe in mezzo al testo, da nota la catena la ricuce alla
//    sua prima parte o la legge dopo il paragrafo, con la sua introduzione). Sulle pagine a due colonne la regola
//    delle glosse del tronco comune vede la seconda colonna «fuori dalla colonna del corpo» (sul PDF col testo dei codici lo evita il loro
//    ramo, che sulle scansioni non scatta): al banco l'82 per cento delle parole fuori dalla lettura della via delle scansioni. Le glosse
//    vere stanno in regioni strette, o fuori da ogni regione, e restano glosse.
//  * RIGHE DI TABELLA (miglioria `righeDiTabella`). Un nodo che la catena chiama nota ma le cui righe stanno dentro una regione «tabella»
//    ammessa fra le candidate delle risorse visive è testo della tabella (le righe che cominciano con un numero sembrano note a corpo
//    ridotto): diventa NON CLASSIFICATO (`UNCLASSIFIED`), il ruolo di ripiego delle tabelle per la guardia delle risorse visive: si legge al
//    suo posto, senza introduzione, dopo l'annuncio della tabella, non va fra le note né si aggancia a un richiamo. Non diventa corpo: la
//    catena unisce i blocchi di corpo vicini anche fra le pagine, e una tabella senza punti fermi non si spezza (misurato sul banco: le
//    tabelle di un documento finivano in un segmento solo, con tutti gli annunci in testa).
//
//  Una riga conta solo se il suo CENTRO sta dentro la regione (non quando la regione le è stata data solo perché la più vicina). Un nodo
//  cambia solo se le sue righe ritrovate (per contenimento del testo normalizzato, sulla stessa pagina) coprono almeno metà del suo testo
//  e almeno metà di quelle sta nelle regioni della regola. Il testo dei nodi non cambia: cambia solo il tipo (`relabel`, come l'indice
//  analitico dell'officina). Il referto per il pacchetto resta quello dell'innesto successivo (nessuna riga nuova verso l'iPad); i conti
//  stanno in `conti`, per il laboratorio.
//

import Foundation
import ScaboChain
import ScaboCore

/// Dove sta una riga letta rispetto alle regioni di Heron della sua pagina (nessun testo).
public struct RegioneRiga: Codable, Equatable, Sendable {
    /// Il tipo della regione (etichetta di docling); nil se la pagina non ha l'ordine delle regioni (meno dell'80 per cento delle righe
    /// dentro le regioni: resta l'ordine di Apple).
    public var tipo: String?
    /// Vero se il centro della riga sta dentro il riquadro della regione.
    public var dentro: Bool
    /// La larghezza della regione divisa la larghezza della pagina.
    public var frazioneLarghezza: Double
    /// Vero se la regione è una «tabella» ammessa fra le candidate delle risorse visive (larga almeno un quarto della pagina, con almeno
    /// due righe lette dentro).
    public var tabellaAmmessa: Bool

    public init(tipo: String?, dentro: Bool, frazioneLarghezza: Double, tabellaAmmessa: Bool) {
        self.tipo = tipo; self.dentro = dentro; self.frazioneLarghezza = frazioneLarghezza; self.tabellaAmmessa = tabellaAmmessa
    }

    /// Nessuna regione di Heron.
    public static let senzaRegione = RegioneRiga(tipo: nil, dentro: false, frazioneLarghezza: 0, tabellaAmmessa: false)
}

public final class InnestoScansioni: ChainGraft {

    /// I conti dell'innesto, senza testo.
    public struct Conti: Codable, Equatable, Sendable {
        public var glosseInColonna = 0
        public var glosseInNote = 0
        public var noteInTabella = 0
        public var glosseLasciate = 0
        public var noteLasciateSullePagineConTabelle = 0
        public init() {}
    }

    /// Una colonna di testo è larga almeno questa frazione della pagina (le glosse vere del banco stanno sotto un quinto; una colonna di
    /// un codice a due colonne sta sopra i due quinti).
    public static let frazioneColonnaMinima = 1.0 / 3.0
    /// Tipi di regione che non sono testo da leggere nel corpo.
    static let tipiNonDiTesto: Set<String> = ["page_header", "page_footer", "picture"]
    /// L'etichetta di docling delle regioni di nota («footnote»).
    static let tipoNota = "footnote"
    /// Lunghezza minima (lettere e cifre) di una riga perché la si cerchi nel testo di un nodo.
    static let caratteriMinimi = 4

    let righe: [Int: [RegioneRiga]]
    let colonne: Bool
    let righeDiTabella: Bool
    let poi: ChainGraft?
    public private(set) var conti = Conti()

    /// `righe`: per ogni pagina letta (0-based), la regione di ogni riga, nell'ordine delle righe della pagina dell'estrazione.
    public init(righe: [Int: [RegioneRiga]], colonne: Bool, righeDiTabella: Bool, poi: ChainGraft?) {
        self.righe = righe; self.colonne = colonne; self.righeDiTabella = righeDiTabella; self.poi = poi
    }

    public func graft(extraction: PdfExtraction, rawDocument: ScabopdfDocument, pdfURL: URL, sourceName: String,
                      onPage: (Int, Int) -> Void, isCancelled: () -> Bool) -> ChainGraftOutput? {
        conti = Conti()
        var doc = rawDocument
        if colonne || righeDiTabella {
            var testiDellePagine: [Int: [String]] = [:]
            for p in extraction.pages where righe[p.pageIndex] != nil {
                testiDellePagine[p.pageIndex] = p.lines.map { l in TextFingerprint.normalize(l.spans.map(\.text).joined(separator: " ")) }
            }
            doc.structure = trasforma(doc.structure, testi: testiDellePagine)
        }
        if isCancelled() { return nil }
        guard let poi else { return ChainGraftOutput(extraction: extraction, rawDocument: doc, report: []) }
        return poi.graft(extraction: extraction, rawDocument: doc, pdfURL: pdfURL, sourceName: sourceName, onPage: onPage,
                         isCancelled: isCancelled)
    }

    private func trasforma(_ nodi: [NodeDict], testi: [Int: [String]]) -> [NodeDict] {
        nodi.map { n in
            var c = n
            if !c.children.isEmpty { c.children = trasforma(c.children, testi: testi) }
            switch c.type {
            case .MARGINAL_GLOSS where colonne:
                let colonna: (RegioneRiga) -> Bool = { r in
                    r.dentro && r.frazioneLarghezza >= Self.frazioneColonnaMinima && !(r.tipo.map(Self.tipiNonDiTesto.contains) ?? true)
                }
                if regolaVale(c, testi: testi, condizione: colonna) {
                    if regolaVale(c, testi: testi, condizione: { colonna($0) && $0.tipo == Self.tipoNota }, soloFra: colonna) {
                        c.type = .NOTE
                        c.length_category = lengthCategoryFor(c.text ?? "")
                        conti.glosseInNote += 1
                    } else {
                        c.type = .BODY
                        conti.glosseInColonna += 1
                    }
                } else { conti.glosseLasciate += 1 }
            case .NOTE where righeDiTabella:
                if regolaVale(c, testi: testi, condizione: { $0.dentro && $0.tabellaAmmessa }) {
                    c.type = .UNCLASSIFIED
                    c.length_category = nil
                    conti.noteInTabella += 1
                } else if (righe[c.page_index] ?? []).contains(where: \.tabellaAmmessa) {
                    conti.noteLasciateSullePagineConTabelle += 1
                }
            default: break
            }
            return c
        }
    }

    /// Vero se le righe della pagina ritrovate nel testo del nodo coprono almeno metà del testo e almeno metà di quelle soddisfa la
    /// condizione. Con `soloFra`, la seconda metà si conta solo fra le righe ritrovate che soddisfano `soloFra` (per scegliere il tipo fra
    /// le righe che già soddisfano la regola).
    private func regolaVale(_ n: NodeDict, testi: [Int: [String]], condizione: (RegioneRiga) -> Bool,
                            soloFra: ((RegioneRiga) -> Bool)? = nil) -> Bool {
        guard let regioni = righe[n.page_index], let linee = testi[n.page_index], regioni.count == linee.count else { return false }
        let t = TextFingerprint.normalize(n.text ?? "")
        guard !t.isEmpty else { return false }
        var ritrovati = 0, fra = 0, nellaRegola = 0
        for (r, l) in zip(regioni, linee) where l.count >= Self.caratteriMinimi && t.contains(l) {
            ritrovati += l.count
            if soloFra?(r) ?? true { fra += l.count }
            if condizione(r) { nellaRegola += l.count }
        }
        return 2 * ritrovati >= t.count && fra > 0 && 2 * nellaRegola >= fra
    }
}
