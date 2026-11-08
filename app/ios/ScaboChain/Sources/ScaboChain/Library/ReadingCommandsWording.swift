//
//  ReadingCommandsWording.swift
//  ScaboChain
//
//  I NOMI dei comandi della lettura che l'iPad dà ai comandi da tastiera (ScaboApp `KeyboardCommandsCatalog`) e il Mac alle
//  voci del menu «Lettura» (giro «app unica per Mac, tappa A», 2026-11-08, rilievo della revisione: le stesse parole sui
//  due prodotti). Le scorciatoie restano di ciascuna piattaforma. Solo Foundation.
//

import Foundation

public enum ReadingCommandsWording {
    /// ⌘J: sulla nota va al testo del richiamo, sul testo che richiama una nota va alla nota.
    public static let noteJump = "Nota e richiamo"
    /// Il titolo (intestazione) successivo e il precedente.
    public static let nextHeading = "Intestazione successiva"
    public static let previousHeading = "Intestazione precedente"
}
