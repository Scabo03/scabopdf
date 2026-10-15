//
//  Announcer.swift
//  ScaboMacKit
//
//  Gli annunci VoiceOver dietro un'interfaccia (`Announcing`), così i test verificano TESTO e FREQUENZA
//  senza VoiceOver. La politica (`AnnouncementPolicy`) traduce i cambi di stato del servizio in annunci:
//  i cambi di stato si annunciano UNA volta; l'avanzamento si annuncia solo a soglie (ogni 25 per cento)
//  per non sommergere la sintesi.
//

import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

public enum AnnouncementPriority: Equatable, Sendable { case normale, alta }

public protocol Announcing: AnyObject {
    func announce(_ testo: String, priority: AnnouncementPriority)
}

/// Annunciatore reale: posta l'annuncio di accessibilità di sistema (VoiceOver lo pronuncia).
public final class VoiceOverAnnouncer: Announcing {
    public init() {}
    public func announce(_ testo: String, priority: AnnouncementPriority) {
        #if canImport(SwiftUI)
        var s = AttributedString(testo)
        s.accessibilitySpeechAnnouncementPriority = (priority == .alta) ? .high : .default
        AccessibilityNotification.Announcement(s).post()
        #endif
    }
}

/// Annunciatore che registra (per i test e per il referto dell'ordine degli annunci).
public final class RecordingAnnouncer: Announcing {
    public private(set) var annunci: [(testo: String, priority: AnnouncementPriority)] = []
    public init() {}
    public func announce(_ testo: String, priority: AnnouncementPriority) { annunci.append((testo, priority)) }
    public var testi: [String] { annunci.map { $0.testo } }
}

/// La politica degli annunci: da (voce, stato precedente, stato nuovo) a zero o un annuncio.
public struct AnnouncementPolicy {
    /// Soglie di avanzamento annunciate (per cento).
    public var soglie: [Int] = [25, 50, 75]
    public init() {}

    public func annuncio(per entry: CatalogEntry, da old: ModelState?, a new: ModelState) -> (String, AnnouncementPriority)? {
        switch (old, new) {
        case (_, .inScaricamento(0)):
            return (Testi.annuncioScaricamentoAvviato(entry.nome, entry.dimensioneInParole), .normale)
        case (.inScaricamento(let p0)?, .inScaricamento(let p1)):
            // Annuncia una soglia solo quando la si supera per la prima volta.
            if let s = soglie.first(where: { p0 < $0 && $0 <= p1 }) { return (Testi.annuncioAvanzamento(entry.nome, s), .normale) }
            return nil
        case (.inScaricamento?, .scaricato):
            return (Testi.annuncioScaricamentoCompletato(entry.nome), .alta)
        case (.inScaricamento?, .nonScaricato):
            return (Testi.annuncioScaricamentoAnnullato(entry.nome), .alta)
        case (.rimozioneInCorso?, .nonScaricato):
            return (Testi.annuncioRimosso(entry.nome, entry.dimensioneInParole), .alta)
        case (_, .errore(let e)):
            return (Testi.annuncioErrore(entry.nome, e.spiegazione), .alta)
        case (_, .sistemaDisponibile):
            return (Testi.annuncioVerificaSistema(entry.nome, disponibile: true), .normale)
        case (let o?, .sistemaNonDisponibile) where o != .sistemaNonDisponibile:
            return (Testi.annuncioVerificaSistema(entry.nome, disponibile: false), .normale)
        default:
            return nil
        }
    }
}
