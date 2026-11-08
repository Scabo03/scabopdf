//
//  ReadingSettingsWording.swift
//  ScaboChain
//
//  Le PAROLE delle impostazioni di lettura che l'iPad e il Mac hanno in comune (giro «app unica per Mac, tappa A»,
//  2026-11-08): la granularità di lettura con i suoi quattro livelli (LAYER2 § 7.6-7.7) e l'interruttore delle note
//  annunciate a voce. Fino a quel giro stavano letterali in ScaboApp `SettingsViewController`, che ora le prende da qui.
//

import Foundation
import ScaboCore

public enum ReadingSettingsWording {
    /// La sezione della granularità e la sua spiegazione.
    public static let granularityTitle = "Granularità di lettura predefinita"
    public static let granularityFooter = "Quanto testo raggruppare in ogni elemento dei testi discorsivi (manuali, saggi). "
        + "I testi normativi seguono la loro struttura nativa."
    /// I quattro livelli, nell'ordine, con le loro parole.
    public static let granularityLevels: [(GranularityLevel, String)] = [
        (.fine, "Fine — 400 caratteri"),
        (.medium, "Media — 600 caratteri"),
        (.coarse, "Ampia — 900 caratteri"),
        (.veryCoarse, "Piena — 1200 caratteri"),
    ]
    /// L'interruttore delle note annunciate a voce.
    public static let noteSpokenSwitch = "Annuncia le note a voce"
}
