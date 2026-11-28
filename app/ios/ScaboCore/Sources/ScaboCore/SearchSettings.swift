//
//  SearchSettings.swift
//  ScaboCore
//
//  LE IMPOSTAZIONI DELLA RICERCA (giro «scansioni, ricerca e build», 2026-11-28; decisione del maintainer del 26 novembre, al posto
//  dei sei punti da confermare della decisione 29: LAYER2_PRODUCT_DECISIONS § 12.16, decisione 31). Per ogni scelta d'ascolto della
//  ricerca per parole pesate c'è una domanda con almeno due opzioni, ciascuna spiegata con frasi complete, così l'utente sceglie ciò
//  che gli è più comodo e capisce da solo che cosa fa che cosa. I PREDEFINITI sono quelli che cambiano meno le abitudini di chi usava la
//  ricerca prima dei passi (build 67 e precedenti): prima le corrispondenze esatte, al più 20 passi, salto diretto attivo, tutti gli
//  articoli con quel numero, una parola sola com'era, rotore e Comando G sulle sole corrispondenze esatte, annuncio breve, libreria per
//  pertinenza.
//
//  Solo Foundation, come la ricerca: le stesse impostazioni e le stesse parole valgono per l'iPad e, quando avrà la sua finestra di
//  ricerca, per il Mac. Si conservano con le chiavi delle preferenze (`KeyValueStore`): un valore mancante o sconosciuto torna al
//  predefinito, come le altre preferenze.
//

import Foundation

/// Le scelte della ricerca.
public struct SearchSettings: Equatable, Sendable, Codable {
    /// L'ordine fra le corrispondenze esatte e i passi pertinenti (il salto diretto, se c'è, sta sempre in testa).
    public enum Order: String, Equatable, Sendable, Codable, CaseIterable { case exactFirst, passagesFirst }
    /// Libri con più codici, quando la ricerca non dice quale: tutti gli articoli con quel numero, o il codice più ampio.
    public enum CodeChoice: String, Equatable, Sendable, Codable, CaseIterable { case allArticles, mainCode }
    /// L'annuncio di una riga di risultato: subito il testo, o prima il tipo di risultato.
    public enum Announcement: String, Equatable, Sendable, Codable, CaseIterable { case brief, full }
    /// L'ordine dei libri nella ricerca nella libreria.
    public enum LibraryOrder: String, Equatable, Sendable, Codable, CaseIterable { case relevance, exactFirst }

    public var order: Order
    /// Al più quanti passi pertinenti (uno dei valori di `passageLimits`).
    public var passageLimit: Int
    /// Il salto diretto a un articolo o a un paragrafo chiesto per numero.
    public var numberJump: Bool
    public var codeChoice: CodeChoice
    /// Anche i passi pertinenti per una ricerca di una parola sola.
    public var singleWordPassages: Bool
    /// Il rotore «Risultati della ricerca» e Comando G passano anche fra i passi pertinenti, nell'ordine dei risultati.
    public var rotorIncludesPassages: Bool
    public var announcement: Announcement
    public var libraryOrder: LibraryOrder

    /// I tre tetti dei passi pertinenti.
    public static let passageLimits = [10, 20, 50]

    public init(order: Order = .exactFirst, passageLimit: Int = 20, numberJump: Bool = true, codeChoice: CodeChoice = .allArticles,
                singleWordPassages: Bool = false, rotorIncludesPassages: Bool = false, announcement: Announcement = .brief,
                libraryOrder: LibraryOrder = .relevance) {
        self.order = order
        self.passageLimit = Self.passageLimits.contains(passageLimit) ? passageLimit : 20
        self.numberJump = numberJump
        self.codeChoice = codeChoice
        self.singleWordPassages = singleWordPassages
        self.rotorIncludesPassages = rotorIncludesPassages
        self.announcement = announcement
        self.libraryOrder = libraryOrder
    }

    /// Le scelte predefinite.
    public static let standard = SearchSettings()

    /// Le scelte con cui la ricerca si comportava dal giro «la ricerca» (26 novembre 2026, decisione 29) fino a questo giro: prima i
    /// passi, al più 50, «Passo:» in testa alla riga. Per il banco della ricerca e per i test che confrontano col comportamento di prima.
    public static let decision29 = SearchSettings(order: .passagesFirst, passageLimit: 50, announcement: .full)
}

// MARK: - Conservazione

extension PreferenceKeys {
    public static let searchOrder = "@scabopdf/search/order"
    public static let searchPassageLimit = "@scabopdf/search/passageLimit"
    public static let searchNumberJump = "@scabopdf/search/numberJump"
    public static let searchCodeChoice = "@scabopdf/search/codeChoice"
    public static let searchSingleWordPassages = "@scabopdf/search/singleWordPassages"
    public static let searchRotorIncludesPassages = "@scabopdf/search/rotorIncludesPassages"
    public static let searchAnnouncement = "@scabopdf/search/announcement"
    public static let searchLibraryOrder = "@scabopdf/search/libraryOrder"
}

/// Le scelte della ricerca conservate (ogni valore mancante o sconosciuto torna al predefinito).
public func getStoredSearchSettings(_ store: KeyValueStore) -> SearchSettings {
    let d = SearchSettings.standard
    func bool(_ key: String, _ fallback: Bool) -> Bool {
        switch store.getItem(key) { case "true": return true; case "false": return false; default: return fallback }
    }
    return SearchSettings(
        order: store.getItem(PreferenceKeys.searchOrder).flatMap(SearchSettings.Order.init(rawValue:)) ?? d.order,
        passageLimit: store.getItem(PreferenceKeys.searchPassageLimit).flatMap(Int.init) ?? d.passageLimit,
        numberJump: bool(PreferenceKeys.searchNumberJump, d.numberJump),
        codeChoice: store.getItem(PreferenceKeys.searchCodeChoice).flatMap(SearchSettings.CodeChoice.init(rawValue:)) ?? d.codeChoice,
        singleWordPassages: bool(PreferenceKeys.searchSingleWordPassages, d.singleWordPassages),
        rotorIncludesPassages: bool(PreferenceKeys.searchRotorIncludesPassages, d.rotorIncludesPassages),
        announcement: store.getItem(PreferenceKeys.searchAnnouncement).flatMap(SearchSettings.Announcement.init(rawValue:)) ?? d.announcement,
        libraryOrder: store.getItem(PreferenceKeys.searchLibraryOrder).flatMap(SearchSettings.LibraryOrder.init(rawValue:)) ?? d.libraryOrder)
}

/// Conserva le scelte della ricerca.
public func setStoredSearchSettings(_ store: KeyValueStore, _ s: SearchSettings) {
    store.setItem(PreferenceKeys.searchOrder, s.order.rawValue)
    store.setItem(PreferenceKeys.searchPassageLimit, String(s.passageLimit))
    store.setItem(PreferenceKeys.searchNumberJump, s.numberJump ? "true" : "false")
    store.setItem(PreferenceKeys.searchCodeChoice, s.codeChoice.rawValue)
    store.setItem(PreferenceKeys.searchSingleWordPassages, s.singleWordPassages ? "true" : "false")
    store.setItem(PreferenceKeys.searchRotorIncludesPassages, s.rotorIncludesPassages ? "true" : "false")
    store.setItem(PreferenceKeys.searchAnnouncement, s.announcement.rawValue)
    store.setItem(PreferenceKeys.searchLibraryOrder, s.libraryOrder.rawValue)
}

// MARK: - Le parole della sezione «Ricerca»

/// Una domanda della sezione «Ricerca» delle impostazioni: il titolo, una frase sotto (se serve) e le opzioni, ciascuna col suo
/// nome e la sua spiegazione, dette insieme da VoiceOver.
public struct SearchSettingsQuestion: Equatable, Sendable {
    public enum Id: String, CaseIterable, Sendable {
        case order, passageLimit, numberJump, codeChoice, singleWord, rotor, announcement, library
    }
    public struct Option: Equatable, Sendable {
        public let name: String
        public let explanation: String
        /// Ciò che VoiceOver dice della riga: il nome, poi la spiegazione.
        public var spoken: String { name + ". " + explanation }
    }
    public let id: Id
    public let title: String
    public let footer: String?
    public let options: [Option]

    /// L'opzione scelta in `s` (indice in `options`).
    public func selectedIndex(in s: SearchSettings) -> Int {
        switch id {
        case .order: return s.order == .exactFirst ? 0 : 1
        case .passageLimit: return SearchSettings.passageLimits.firstIndex(of: s.passageLimit) ?? 1
        case .numberJump: return s.numberJump ? 0 : 1
        case .codeChoice: return s.codeChoice == .allArticles ? 0 : 1
        case .singleWord: return s.singleWordPassages ? 1 : 0
        case .rotor: return s.rotorIncludesPassages ? 1 : 0
        case .announcement: return s.announcement == .brief ? 0 : 1
        case .library: return s.libraryOrder == .relevance ? 0 : 1
        }
    }

    /// `s` con l'opzione `index` scelta.
    public func choosing(_ index: Int, in s: SearchSettings) -> SearchSettings {
        var c = s
        switch id {
        case .order: c.order = index == 0 ? .exactFirst : .passagesFirst
        case .passageLimit: c.passageLimit = SearchSettings.passageLimits[max(0, min(index, SearchSettings.passageLimits.count - 1))]
        case .numberJump: c.numberJump = index == 0
        case .codeChoice: c.codeChoice = index == 0 ? .allArticles : .mainCode
        case .singleWord: c.singleWordPassages = index == 1
        case .rotor: c.rotorIncludesPassages = index == 1
        case .announcement: c.announcement = index == 0 ? .brief : .full
        case .library: c.libraryOrder = index == 0 ? .relevance : .exactFirst
        }
        return c
    }
}

public enum SearchSettingsWording {
    /// Il titolo della sezione e della sua schermata.
    public static let title = "Ricerca"
    /// La riga delle Impostazioni che apre la schermata.
    public static let openRow = "Come cerca ScaboPDF"
    public static let openRowHint = "Apre le scelte della ricerca nel libro e nella libreria"
    /// La frase in cima alla sezione.
    public static let introduction = "ScaboPDF cerca in due modi. Le corrispondenze esatte sono i punti in cui compare proprio la frase "
        + "che hai scritto. I passi pertinenti sono i punti in cui compaiono molte delle parole che hai scritto, soprattutto le meno "
        + "comuni, anche se non tutte insieme e non nello stesso ordine."

    public typealias Q = SearchSettingsQuestion
    public typealias O = SearchSettingsQuestion.Option

    /// Le domande, nell'ordine della schermata.
    public static let questions: [Q] = [
        Q(id: .order, title: "Ordine dei risultati", footer: nil, options: [
            O(name: "Prima le corrispondenze esatte",
              explanation: "Trovi prima i punti in cui compare esattamente la frase che hai scritto, poi i passi pertinenti. Va bene se "
                + "ricordi le parole precise del libro."),
            O(name: "Prima i passi pertinenti",
              explanation: "Trovi prima i passi che contengono più parole della tua ricerca, anche se la frase esatta non c'è, poi le "
                + "corrispondenze esatte. Va bene se cerchi un argomento con parole tue."),
        ]),
        Q(id: .passageLimit, title: "Quanti passi pertinenti", footer: nil, options: [
            O(name: "Pochi, fino a 10", explanation: "Scorri meno risultati, ma il passo giusto può restare fuori."),
            O(name: "Medi, fino a 20", explanation: "Una via di mezzo."),
            O(name: "Molti, fino a 50", explanation: "È più facile che il passo giusto ci sia, ma hai più risultati da scorrere."),
        ]),
        Q(id: .numberJump, title: "Salto agli articoli", footer: nil, options: [
            O(name: "Salto diretto attivo",
              explanation: "Se scrivi il numero di un articolo o di un paragrafo, per esempio «art. 2043» o «paragrafo 12», il primo "
                + "risultato ti porta direttamente lì."),
            O(name: "Salto diretto spento", explanation: "Il numero si cerca come una parola qualsiasi, insieme alle altre."),
        ]),
        Q(id: .codeChoice, title: "Libri con più codici", footer: "Vale quando nella ricerca non scrivi quale codice intendi.", options: [
            O(name: "Mostra tutti gli articoli con quel numero",
              explanation: "Senti uno dopo l'altro tutti gli articoli con quel numero, ciascuno con il nome del suo codice, e scegli tu."),
            O(name: "Vai al codice principale",
              explanation: "Ti porta all'articolo del codice più ampio del libro; gli altri restano subito sotto."),
        ]),
        Q(id: .singleWord, title: "Una parola sola", footer: nil, options: [
            O(name: "Solo le corrispondenze esatte", explanation: "Trovi tutti i punti dove compare la parola, nell'ordine del libro."),
            O(name: "Anche i passi pertinenti",
              explanation: "Trovi anche i passi in cui quella parola pesa di più, oltre a tutti i punti in cui compare. Quale dei due "
                + "viene prima lo decide l'ordine dei risultati."),
        ]),
        Q(id: .rotor, title: "Rotore e Comando G", footer: nil, options: [
            O(name: "Solo sulle corrispondenze esatte",
              explanation: "Con il rotore e con Comando G passi da un punto all'altro in cui compare la frase esatta."),
            O(name: "Anche sui passi pertinenti",
              explanation: "Con il rotore e con Comando G passi anche fra i passi pertinenti, nell'ordine dei risultati."),
        ]),
        Q(id: .announcement, title: "Annuncio dei risultati", footer: nil, options: [
            O(name: "Annuncio breve", explanation: "Senti subito il testo del risultato."),
            O(name: "Annuncio completo",
              explanation: "Prima del testo senti che tipo di risultato è: articolo, corrispondenza esatta o passo pertinente."),
        ]),
        Q(id: .library, title: "Ricerca nella libreria", footer: nil, options: [
            O(name: "Per pertinenza",
              explanation: "Vengono prima i libri in cui le parole che hai scritto contano di più, anche se la frase esatta non c'è."),
            O(name: "Prima la frase esatta",
              explanation: "Vengono prima i libri che contengono esattamente la frase che hai scritto, poi gli altri per pertinenza."),
        ]),
    ]
}
