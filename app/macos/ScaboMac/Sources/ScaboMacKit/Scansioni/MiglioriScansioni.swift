//
//  MiglioriScansioni.swift
//  ScaboMacKit — LE MIGLIORIE DELLA VIA DELLE SCANSIONI (giro «migliorie del banco nelle app», 2026-11-21; LAYER2 § 12.16, decisioni
//  23 e 24; misure in docs/BANCO_OCR.md, § 44).
//
//  Ciò che i tre giri del banco OCR hanno dimostrato, portato nella lettura delle scansioni dell'app. Tutte ACCESE di serie: l'app
//  le usa sempre e non le mostra. Le spegne solo la riga di comando del laboratorio (`scabomac-officina catena --senza …`), per la
//  rete del banco: con tutte spente la via delle scansioni fa esattamente ciò che faceva prima del giro, al byte (prova del giro sulle
//  185 pagine del banco, sul livello B con l'estensione, sulle 72 ruotate e sulle 75 scansioni vere).
//

import Foundation

public struct MiglioriScansioni: Codable, Equatable, Sendable {
    /// Le tabelle e le figure che il modello d'impaginazione vede sulle pagine lette arrivano alla catena come candidate delle
    /// risorse visive: la guardia condivisa con l'iPad decide, e la lettura le annuncia con le stesse parole (variante D del giro 2
    /// del banco). Il testo della tabella resta nel flusso.
    public var tabelle = true
    /// GLM lettura pagine senza la guardia che, nel dubbio, rimetteva le righe di Apple al posto del suo testo (sulle scansioni vere la via
    /// GLM perdeva così il 19,8 per cento delle parole, contro il 2,8 senza): il testo di GLM è l'autorità, le righe di Apple solo la
    /// geometria (variante B del giro 2), dopo un FILTRO DELLA NOTAZIONE che toglie i segni del rumore udibile (notazione matematica e di
    /// formattazione, classi R1 e R2 del banco) senza togliere testo, e con una protezione contro il testo inventato in un'altra forma: la
    /// riga che GLM riscrive di fila, incantato (classe R4), si dice una volta sola; le righe ripetute sparse nella pagina restano.
    public var glm = true
    /// Il segno di paragrafo: il lettore di Apple scrive «$» al posto di «§», e VoiceOver tace il dollaro. «$» diventa «§» solo dove il
    /// corpus mostra un segno di paragrafo: davanti a un numero (non un importo con le migliaia o i decimali), staccato da uno spazio
    /// («$ 12») o raddoppiato («$$ 3»), mai dopo una sigla («US$») né dopo un numero, mai il «$» che chiude un apice, mai il dollaro
    /// singolo attaccato al numero (Apple legge così i richiami e le edizioni in apice). Misura del giro: nei 55 documenti del corpus
    /// 14.826 «§», 12.148 davanti a un numero e 758 doppi; 2 «$» veri, nessuno in quei contesti.
    ///
    /// (I numeri di nota letti come asterisco: provata e RITIRATA nello stesso giro. Il numero ricavato dalla sequenza delle note o
    /// dall'unico richiamo senza nota era sbagliato in 4 casi su 4 sul banco, perché gli elenchi dentro le note e le cifre lette male
    /// sembrano numeri di nota; e togliere l'asterisco quando il numero non è certo fonde la nota con quella sopra. L'asterisco resta.)
    public var paragrafo = true
    /// LA GRIGLIA DELLE TABELLE (giro «scansioni, ricerca e build», 2026-11-28). Sul PDF col testo la guardia delle risorse visive sa se
    /// una tabella ha una griglia disegnata (la sonda grafica conta filetti e riquadri: `VisualRegionCandidate.graphicsInside`), e dentro
    /// una griglia un numero in testa alla riga è una cella, non un marcatore di nota. Su una scansione quei disegni non esistono come
    /// oggetti: sono pixel dell'immagine. Qui si contano i FILETTI dell'immagine della pagina letta dentro la regione «tabella» e si danno
    /// alla guardia condivisa come quei disegni (solo se ce n'è almeno uno: lo zero non si dice, così la regola delle colonne di testo
    /// senza disegni resta fuori dalle scansioni come prima). La guardia non cambia. Misura del giro sugli estratti delle tabelle: delle
    /// 63 tabelle che il modello vede, 34 scartate per «marcatori di nota» con la lettura di Apple (38 con GLM), e 28 di quelle 34 hanno
    /// almeno 6 filetti (docs/BANCO_OCR.md § 48).
    public var griglia = true
    /// LE COLONNE (giro «scansioni, ricerca e build»): le «glosse» dentro regioni di Heron larghe almeno un terzo della pagina tornano
    /// corpo (`InnestoScansioni`): sono la seconda colonna delle pagine a due colonne, non glosse a margine.
    public var colonne = true
    /// LE RIGHE DI TABELLA (giro «scansioni, ricerca e build»): le «note» dentro una regione «tabella» ammessa fra le candidate delle
    /// risorse visive tornano corpo (`InnestoScansioni`): sono righe della tabella che cominciano con un numero.
    public var righeDiTabella = true

    public init() {}

    /// Tutte spente: la via delle scansioni di prima del giro (solo laboratorio).
    public static let spente: MiglioriScansioni = {
        var m = MiglioriScansioni()
        m.tabelle = false
        m.glm = false
        m.paragrafo = false
        m.griglia = false
        m.colonne = false
        m.righeDiTabella = false
        return m
    }()

    /// I nomi della riga di comando, nell'ordine.
    public static let nomi = ["tabelle", "glm", "paragrafo", "griglia", "colonne", "righetabella"]

    /// Le migliorie con quelle dell'elenco spente (nomi separati da virgole, «tutte» per tutte); nil se un nome non è noto.
    public init?(spente elenco: String) {
        for n in elenco.split(separator: ",").map({ $0.trimmingCharacters(in: .whitespaces) }) where !n.isEmpty {
            switch n {
            case "tutte": self = .spente
            case "tabelle": tabelle = false
            case "glm": glm = false
            case "paragrafo": paragrafo = false
            case "griglia": griglia = false
            case "colonne": colonne = false
            case "righetabella": righeDiTabella = false
            default: return nil
            }
        }
    }

    /// I nomi delle migliorie spente (vuoto se tutte accese).
    public var spenteNomi: [String] {
        zip(Self.nomi, [tabelle, glm, paragrafo, griglia, colonne, righeDiTabella]).filter { !$0.1 }.map { $0.0 }
    }
}
