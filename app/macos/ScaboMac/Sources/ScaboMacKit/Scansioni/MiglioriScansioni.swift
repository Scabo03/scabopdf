//
//  MiglioriScansioni.swift
//  ScaboMacKit — LE MIGLIORIE DELLA VIA DELLE SCANSIONI (giro «migliorie del banco nelle app», 2026-11-21; LAYER2 § 12.16, decisioni
//  23 e 24; misure in docs/BANCO_OCR.md, sezione «Le migliorie del banco portate nell'app»).
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

    public init() {}

    /// Tutte spente: la via delle scansioni di prima del giro (solo laboratorio).
    public static let spente: MiglioriScansioni = {
        var m = MiglioriScansioni()
        m.tabelle = false
        return m
    }()

    /// I nomi della riga di comando, nell'ordine.
    public static let nomi = ["tabelle"]

    /// Le migliorie con quelle dell'elenco spente (nomi separati da virgole, «tutte» per tutte); nil se un nome non è noto.
    public init?(spente elenco: String) {
        for n in elenco.split(separator: ",").map({ $0.trimmingCharacters(in: .whitespaces) }) where !n.isEmpty {
            switch n {
            case "tutte": self = .spente
            case "tabelle": tabelle = false
            default: return nil
            }
        }
    }

    /// I nomi delle migliorie spente (vuoto se tutte accese).
    public var spenteNomi: [String] {
        zip(Self.nomi, [tabelle]).filter { !$0.1 }.map { $0.0 }
    }
}
