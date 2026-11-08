//
//  ProcessingWording.swift
//  ScaboChain
//
//  Le PAROLE e gli ANNUNCI della schermata d'elaborazione bloccante (LAYER2 § 12.9), una fonte sola per l'iPad e per il Mac
//  (giro «app unica per Mac, tappa A», 2026-11-08). Fino a quel giro vivevano dentro ScaboApp `ProcessingViewController`;
//  spostati qui identici perché l'app Mac annunci l'avanzamento come l'iPad. Le fasi hanno le parole di
//  `DocumentProcessor.Progress.phaseLabel`.
//
//  Annunci MODERATI (mai il mitragliamento): si annuncia il cambio di FASE e ogni nuovo DECILE di avanzamento; la
//  percentuale puntuale resta interrogabile come valore dell'elemento di stato.
//

import Foundation

public enum ProcessingWording {
    /// Il titolo della schermata.
    public static let title = "Elaborazione del documento"
    /// Il pulsante che interrompe l'elaborazione.
    public static let cancelTitle = "Annulla"
    /// L'aiuto del pulsante (sull'iPad).
    public static let cancelHint = "Interrompe l'elaborazione e torna alla schermata iniziale"
    /// La fase prima del primo avanzamento.
    public static let openingPhaseLabel = "Apertura del documento"

    /// La frazione portata in [0, 1].
    public static func clampedFraction(_ fraction: Double) -> Double { max(0, min(1, fraction)) }

    /// La percentuale intera di una frazione già portata in [0, 1].
    public static func percent(ofClampedFraction fraction: Double) -> Int { Int((fraction * 100).rounded()) }

    /// Il testo visivo dell'elemento di stato: «Fase — NN%».
    public static func statusText(phaseLabel: String, percent: Int) -> String { "\(phaseLabel) — \(percent)%" }

    /// La percentuale detta: «NN per cento» (il valore dell'elemento di stato, e l'annuncio di un decile).
    public static func spokenPercent(_ percent: Int) -> String { "\(percent) per cento" }
}

/// Chi decide che cosa annunciare a ogni avanzamento: il cambio di fase e ogni nuovo decile, mai ogni singolo passo.
public struct ProcessingAnnouncements {
    private var lastAnnouncedDecile = -1
    private var lastAnnouncedPhase = ""

    public init() {}

    /// Gli annunci da fare, nell'ordine (prima la fase, poi il decile), per l'avanzamento dato.
    public mutating func announcements(phaseLabel: String, percent: Int, fraction: Double) -> [String] {
        var out: [String] = []
        if phaseLabel != lastAnnouncedPhase {
            lastAnnouncedPhase = phaseLabel
            out.append(phaseLabel)
        }
        let decile = Int(fraction * 10)
        if decile != lastAnnouncedDecile, percent > 0 {
            lastAnnouncedDecile = decile
            out.append(ProcessingWording.spokenPercent(percent))
        }
        return out
    }
}
