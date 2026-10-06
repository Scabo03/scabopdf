//
//  ModelCatalog.swift
//  ScaboMacKit
//
//  Il catalogo dei modelli dell'officina: DATO VERSIONATO nel pacchetto (`Resources/catalogo.json`),
//  letto e VALIDATO all'avvio. Ogni voce porta le undici informazioni che il pannello mostra in prosa
//  (`docs/ANALYSIS_ULTRAFOCUS_MACOS.md` Parte III e mandato del giro «linea Mac»): nome per l'utente, ruolo,
//  descrizione del problema che risolve, dimensione, licenza, motore, requisiti, funzionamento senza
//  internet, stato di validazione sul banco, provenienza ufficiale con versione, marchio di voce provvisoria.
//
//  I RUOLI usano le stesse parole dei sospetti della diagnostica (Parte III.4): «Lettore di scansioni»,
//  «Ricostruttore di struttura e ordine», «Ricucitore del senso» — così l'abbinamento fra referto e
//  pannello è ovvio senza consigli.
//
//  La validazione rifiuta un catalogo malformato con una spiegazione in prosa (mai un «errore» secco,
//  § 12.10 del documento di prodotto): è ciò che il test sul catalogo malformato esercita.
//

import Foundation

/// Il ruolo di un modello, con le parole della diagnostica.
public enum ModelRole: String, Codable, CaseIterable, Sendable, Identifiable {
    case lettoreScansioni = "lettore_scansioni"
    case ricostruttoreStruttura = "ricostruttore_struttura_ordine"
    case ricucitoreSenso = "ricucitore_senso"

    public var id: String { rawValue }

    /// Nome del ruolo per l'utente (identico al vocabolario dei sospetti).
    public var nome: String {
        switch self {
        case .lettoreScansioni: return Testi.ruoloLettoreScansioni
        case .ricostruttoreStruttura: return Testi.ruoloRicostruttore
        case .ricucitoreSenso: return Testi.ruoloRicucitore
        }
    }

    /// Una frase che spiega a che cosa serve il ruolo.
    public var spiegazione: String {
        switch self {
        case .lettoreScansioni: return Testi.ruoloLettoreScansioniSpiegazione
        case .ricostruttoreStruttura: return Testi.ruoloRicostruttoreSpiegazione
        case .ricucitoreSenso: return Testi.ruoloRicucitoreSpiegazione
        }
    }
}

/// Dove gira il modello.
public enum ModelEngine: String, Codable, CaseIterable, Sendable {
    /// Eseguito dentro l'app (pesi scaricati, motore nel pacchetto).
    case nativoNellApp = "nativo_nell_app"
    /// Strumento di sistema Apple: niente da scaricare, dipende dalla versione di macOS.
    case sistemaApple = "sistema_apple"
    /// Programma separato accanto all'app.
    case accantoAllApp = "accanto_all_app"

    public var nome: String {
        switch self {
        case .nativoNellApp: return Testi.motoreNativo
        case .sistemaApple: return Testi.motoreSistemaApple
        case .accantoAllApp: return Testi.motoreAccanto
        }
    }
}

/// Stato di validazione sul banco del progetto.
public enum ValidationStatus: Codable, Equatable, Sendable {
    /// Validato sul banco, con i numeri (una frase in prosa che li riporta).
    case validato(numeri: String)
    /// Non misurato sul banco.
    case nonMisurato
    /// Prova prevista ma non eseguita in questo giro (con il motivo).
    case provaNonEseguita(motivo: String)

    public var descrizione: String {
        switch self {
        case .validato(let numeri): return Testi.validatoPrefisso + numeri
        case .nonMisurato: return Testi.nonMisurato
        case .provaNonEseguita(let motivo): return Testi.provaNonEseguitaPrefisso + motivo
        }
    }
}

/// Requisiti di macchina e sistema, in prosa.
public struct ModelRequirements: Codable, Equatable, Sendable {
    /// Versione minima di macOS (es. "14.0").
    public var macOSMinimo: String
    /// Serve Apple Silicon?
    public var richiedeAppleSilicon: Bool
    /// Memoria consigliata in gigabyte (0 = non rilevante).
    public var memoriaConsigliataGB: Int
    /// Frase aggiuntiva (es. «Apple Intelligence attiva»), può essere vuota.
    public var nota: String

    public init(macOSMinimo: String, richiedeAppleSilicon: Bool, memoriaConsigliataGB: Int, nota: String = "") {
        self.macOSMinimo = macOSMinimo
        self.richiedeAppleSilicon = richiedeAppleSilicon
        self.memoriaConsigliataGB = memoriaConsigliataGB
        self.nota = nota
    }
}

/// Provenienza ufficiale di un modello.
public struct ModelProvenance: Codable, Equatable, Sendable {
    /// Indirizzo della pagina ufficiale (solo https).
    public var indirizzo: String
    /// Versione o data della pubblicazione.
    public var versione: String
    /// Chi lo pubblica (organizzazione).
    public var editore: String

    public init(indirizzo: String, versione: String, editore: String) {
        self.indirizzo = indirizzo
        self.versione = versione
        self.editore = editore
    }
}

/// Una voce del catalogo: le undici informazioni richieste.
public struct CatalogEntry: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var nome: String
    public var ruolo: ModelRole
    public var descrizione: String
    public var dimensioneByte: Int64
    public var licenza: String
    public var motore: ModelEngine
    public var requisiti: ModelRequirements
    public var funzionaSenzaInternet: Bool
    public var validazione: ValidationStatus
    public var provenienza: ModelProvenance
    public var provvisoria: Bool

    public init(
        id: String, nome: String, ruolo: ModelRole, descrizione: String, dimensioneByte: Int64,
        licenza: String, motore: ModelEngine, requisiti: ModelRequirements, funzionaSenzaInternet: Bool,
        validazione: ValidationStatus, provenienza: ModelProvenance, provvisoria: Bool
    ) {
        self.id = id; self.nome = nome; self.ruolo = ruolo; self.descrizione = descrizione
        self.dimensioneByte = dimensioneByte; self.licenza = licenza; self.motore = motore
        self.requisiti = requisiti; self.funzionaSenzaInternet = funzionaSenzaInternet
        self.validazione = validazione; self.provenienza = provenienza; self.provvisoria = provvisoria
    }

    /// La dimensione «resa in parole» (es. «circa 1,3 gigabyte»).
    public var dimensioneInParole: String { ByteWords.describe(dimensioneByte) }
}

/// Il catalogo intero, con la sua versione di schema.
public struct ModelCatalog: Codable, Equatable, Sendable {
    /// Versione dello schema del catalogo (intero, additivo).
    public var schemaVersione: Int
    /// Data dell'ultima revisione del contenuto (AAAA-MM-GG).
    public var aggiornatoIl: String
    public var voci: [CatalogEntry]

    public static let schemaVersioneCorrente = 1

    public init(schemaVersione: Int, aggiornatoIl: String, voci: [CatalogEntry]) {
        self.schemaVersione = schemaVersione
        self.aggiornatoIl = aggiornatoIl
        self.voci = voci
    }

    /// Le voci di un ruolo, nell'ordine del catalogo.
    public func voci(per ruolo: ModelRole) -> [CatalogEntry] { voci.filter { $0.ruolo == ruolo } }
}

/// Errore di catalogo: SEMPRE con una spiegazione in prosa e una via d'uscita.
public struct CatalogError: Error, Equatable, CustomStringConvertible {
    public let spiegazione: String
    public init(_ spiegazione: String) { self.spiegazione = spiegazione }
    public var description: String { spiegazione }
}

public enum CatalogLoader {

    /// Carica e valida il catalogo incluso nel pacchetto.
    public static func loadBundled() throws -> ModelCatalog {
        guard let url = Bundle.module.url(forResource: "catalogo", withExtension: "json") else {
            throw CatalogError(Testi.catalogoAssente)
        }
        return try load(from: url)
    }

    /// Carica e valida un catalogo da un file.
    public static func load(from url: URL) throws -> ModelCatalog {
        let data: Data
        do { data = try Data(contentsOf: url) } catch {
            throw CatalogError(Testi.catalogoIllegibile)
        }
        return try load(from: data)
    }

    /// Decodifica e valida un catalogo dai byte.
    public static func load(from data: Data) throws -> ModelCatalog {
        let catalog: ModelCatalog
        do {
            catalog = try JSONDecoder().decode(ModelCatalog.self, from: data)
        } catch {
            throw CatalogError(Testi.catalogoMalformato)
        }
        try validate(catalog)
        return catalog
    }

    /// Le regole di validazione, ciascuna con la sua spiegazione.
    public static func validate(_ catalog: ModelCatalog) throws {
        guard catalog.schemaVersione == ModelCatalog.schemaVersioneCorrente else {
            throw CatalogError(Testi.catalogoVersioneSconosciuta(catalog.schemaVersione))
        }
        guard !catalog.voci.isEmpty else { throw CatalogError(Testi.catalogoVuoto) }
        var seen = Set<String>()
        for entry in catalog.voci {
            if entry.id.trimmingCharacters(in: .whitespaces).isEmpty {
                throw CatalogError(Testi.catalogoVoceSenzaIdentificativo(entry.nome))
            }
            if !seen.insert(entry.id).inserted {
                throw CatalogError(Testi.catalogoIdentificativoDoppio(entry.id))
            }
            if entry.nome.trimmingCharacters(in: .whitespaces).isEmpty {
                throw CatalogError(Testi.catalogoVoceSenzaNome(entry.id))
            }
            if entry.descrizione.trimmingCharacters(in: .whitespaces).isEmpty {
                throw CatalogError(Testi.catalogoVoceSenzaDescrizione(entry.nome))
            }
            if entry.licenza.trimmingCharacters(in: .whitespaces).isEmpty {
                throw CatalogError(Testi.catalogoVoceSenzaLicenza(entry.nome))
            }
            // Gli strumenti di sistema Apple non occupano spazio nostro: dimensione zero ammessa solo per loro.
            if entry.dimensioneByte < 0 || (entry.dimensioneByte == 0 && entry.motore != .sistemaApple) {
                throw CatalogError(Testi.catalogoVoceDimensioneNonValida(entry.nome))
            }
            guard let url = URL(string: entry.provenienza.indirizzo), url.scheme == "https", url.host != nil else {
                throw CatalogError(Testi.catalogoVoceProvenienzaNonValida(entry.nome))
            }
            if entry.provenienza.versione.trimmingCharacters(in: .whitespaces).isEmpty {
                throw CatalogError(Testi.catalogoVoceSenzaVersione(entry.nome))
            }
        }
    }
}

/// Dimensioni in parole, con l'unità per esteso (mai sigle).
public enum ByteWords {
    public static func describe(_ bytes: Int64) -> String {
        if bytes <= 0 { return Testi.dimensioneNessunoSpazio }
        let gb = Double(bytes) / 1_000_000_000
        if gb >= 1 { return Testi.dimensioneGigabyte(gb) }
        let mb = Double(bytes) / 1_000_000
        return Testi.dimensioneMegabyte(max(1, mb.rounded()))
    }
}
