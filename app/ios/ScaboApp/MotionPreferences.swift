//
//  MotionPreferences.swift
//  ScaboApp
//
//  Rispetto di «Riduci movimento» (WCAG 2.3.3 Animation from Interactions; HIG Apple
//  Reduce Motion). L'app è già austera (SPECS § A.4: niente parallax/zoom/spring/flash),
//  quindi il rischio vestibolare è basso; qui si disattivano comunque le animazioni
//  richieste dalle transizioni dell'app quando l'utente ha attivato Riduci movimento.
//  Il parametro `reduceMotion` è iniettabile per la verifica a unit test.
//

import UIKit

enum Motion {
    /// `true` se l'animazione richiesta va eseguita: disattivata quando Riduci movimento è attivo.
    static func animated(
        _ base: Bool = true,
        reduceMotion: Bool = UIAccessibility.isReduceMotionEnabled
    ) -> Bool {
        base && !reduceMotion
    }
}
