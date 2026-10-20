//
//  EscapeKey.swift
//  ScaboApp
//
//  ESC COME «ANNULLA» O «CHIUDI» (giro «ricerca nella libreria», 2026-10-20; decisione 2 del referto della ricerca nel
//  libro). In ogni finestra dell'app aperta sopra il lettore o sopra la Home che ha un pulsante «Annulla» o «Chiudi», il
//  tasto Esc fa la stessa cosa di quel pulsante, e mai qualcosa di nascosto sotto la finestra.
//
//  ── Come ──────────────────────────────────────────────────────────────────────────────────────────────────────
//
//  Ogni finestra con quel pulsante dichiara la sua azione (`EscapeClosable`: la stessa funzione del pulsante). La
//  FINESTRA DELLA SCENA (`ScaboWindow`) chiude la catena dei destinatari dei tasti: chiunque abbia i tasti — un campo
//  della finestra, la finestra stessa, o il lettore rimasto sotto (che con una finestra sopra non tiene più nessun comando:
//  `ContinuousReadingViewController.keyCommands`) — un Esc che nessuno prende prima arriva qui, e qui si fa l'azione della
//  finestra PIÙ IN ALTO, se ne ha una. Se la finestra più in alto non ne ha (un avviso di sistema, che Esc lo gestisce da
//  sé; una finestra senza «Annulla»/«Chiudi»), Esc non fa nulla: mai l'azione di una finestra più sotto, mai il lettore.
//  La finestra della ricerca nel libro tiene il suo Esc (lo stesso «Annulla»), che arriva prima.
//
//  Lo stesso vale per il gesto di uscita di VoiceOver (lo scrub a due dita) quando nessun elemento lo prende prima.
//

import UIKit

/// Una finestra dell'app con un pulsante «Annulla» o «Chiudi»: Esc fa la stessa cosa.
protocol EscapeClosable: AnyObject {
    /// Vero se in questo momento la finestra mostra il pulsante (per esempio no ai livelli interni di una scelta, dove c'è
    /// «Indietro»).
    var hasEscapeAction: Bool { get }
    /// L'azione del pulsante, la stessa.
    func performEscapeAction()
}

extension EscapeClosable {
    var hasEscapeAction: Bool { true }
}

/// La finestra della scena: instrada Esc all'azione «Annulla»/«Chiudi» della finestra più in alto (vedi l'intestazione).
final class ScaboWindow: UIWindow {

    /// La schermata presentata più in alto, o `nil` se non ce n'è.
    static func topmostPresented(from root: UIViewController?) -> UIViewController? {
        var top = root?.presentedViewController
        while let next = top?.presentedViewController { top = next }
        return top
    }

    /// La finestra a cui va Esc, se la più in alto ne ha l'azione in questo momento.
    static func escapeTarget(from root: UIViewController?) -> EscapeClosable? {
        guard let top = topmostPresented(from: root), !(top is UIAlertController) else { return nil }
        let shown = (top as? UINavigationController)?.topViewController ?? top
        guard let target = shown as? EscapeClosable, target.hasEscapeAction else { return nil }
        // Una schermata che se ne sta già andando non riceve più nulla.
        guard !top.isBeingDismissed, !shown.isBeingDismissed else { return nil }
        return target
    }

    override var keyCommands: [UIKeyCommand]? {
        guard Self.escapeTarget(from: rootViewController) != nil else { return super.keyCommands }
        let esc = UIKeyCommand(input: UIKeyCommand.inputEscape, modifierFlags: [], action: #selector(escapePressed))
        esc.wantsPriorityOverSystemBehavior = true
        return (super.keyCommands ?? []) + [esc]
    }

    @objc private func escapePressed() {
        Self.escapeTarget(from: rootViewController)?.performEscapeAction()
    }

    override func accessibilityPerformEscape() -> Bool {
        if let target = Self.escapeTarget(from: rootViewController) {
            target.performEscapeAction()
            return true
        }
        return super.accessibilityPerformEscape()
    }
}
