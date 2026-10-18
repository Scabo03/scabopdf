//
//  KeyboardCommandsCatalog.swift
//  ScaboApp
//
//  I comandi da tastiera della reading view (WCAG 2.1.1 Keyboard, Livello A: oggi
//  falliti — zero UIKeyCommand). UNICA FONTE DI VERITÀ: usata sia per costruire gli
//  `UIKeyCommand` nel reading view controller, sia per l'elenco DESCRITTO nel pannello
//  «Comandi da tastiera» delle Impostazioni. I comandi da tastiera sono invisibili:
//  senza un elenco descritto chi arriva nuovo non sa che esistono (HIG Apple; il
//  pannello li rende scopribili e va reso accessibile a VoiceOver).
//
//  Scelte dei tasti: tutti MODIFICATI (⌘ / ⌥) tranne Esc, per non collidere con la
//  navigazione a tasti nudi di Full Keyboard Access (Tab/frecce/Spazio).
//
//  Giro «accessibilità e completamento» (2026-10-18): il salto fra nota e richiamo ha il suo tasto (⌘J), e nello split
//  screen i comandi di lettura valgono per la metà che comanda, con due comandi per scegliere la metà (⌥⌘← / ⌥⌘→).
//

import UIKit

struct KeyboardCommandSpec {
    /// Identità stabile → il reading view controller la mappa al proprio selettore.
    let id: String
    let title: String
    let input: String
    let modifiers: UIKeyModifierFlags
    /// Descrizione in prosa di cosa fa (per il pannello scopribile).
    let description: String
    /// Altri tasti con lo stesso effetto e gli stessi modificatori (per le disposizioni di tastiera in cui il tasto
    /// principale non si batte direttamente: sulla tastiera italiana l'«=» è Maiuscole+0, il «+» è un tasto a sé).
    var alternateInputs: [String] = []

    /// Gli `UIKeyCommand` della voce: il tasto principale (con il nome che il sistema mostra tenendo premuto ⌘) e gli
    /// alternativi, nascosti in quell'elenco per non comparire due volte. Stessa azione, stesso `propertyList`.
    func makeKeyCommands(action: Selector, propertyList: Any? = nil) -> [UIKeyCommand] {
        ([input] + alternateInputs).enumerated().map { k, key in
            let cmd = UIKeyCommand(title: title, action: action, input: key, modifierFlags: modifiers,
                                   propertyList: propertyList)
            cmd.discoverabilityTitle = title
            cmd.wantsPriorityOverSystemBehavior = true
            if k > 0 { cmd.attributes = .hidden }
            return cmd
        }
    }

    /// I tasti in glifi (es. «⌘ ↓», «Esc»), per la resa visiva del pannello.
    var displayKeys: String {
        var parts: [String] = []
        if modifiers.contains(.command) { parts.append("⌘") }
        if modifiers.contains(.alternate) { parts.append("⌥") }
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        parts.append(Self.glyph(for: input))
        return parts.joined(separator: " ")
    }

    /// I tasti a parole, per VoiceOver (es. «Comando più freccia giù»).
    var spokenKeys: String {
        var parts: [String] = []
        if modifiers.contains(.command) { parts.append("Comando") }
        if modifiers.contains(.alternate) { parts.append("Opzione") }
        if modifiers.contains(.control) { parts.append("Controllo") }
        if modifiers.contains(.shift) { parts.append("Maiuscole") }
        parts.append(Self.spokenGlyph(for: input))
        return parts.joined(separator: " più ")
    }

    private static func glyph(for input: String) -> String {
        switch input {
        case UIKeyCommand.inputUpArrow: return "↑"
        case UIKeyCommand.inputDownArrow: return "↓"
        case UIKeyCommand.inputLeftArrow: return "←"
        case UIKeyCommand.inputRightArrow: return "→"
        case UIKeyCommand.inputEscape: return "Esc"
        case " ": return "Spazio"
        case "=": return "+"
        default: return input.uppercased()
        }
    }

    private static func spokenGlyph(for input: String) -> String {
        switch input {
        case UIKeyCommand.inputUpArrow: return "freccia su"
        case UIKeyCommand.inputDownArrow: return "freccia giù"
        case UIKeyCommand.inputLeftArrow: return "freccia sinistra"
        case UIKeyCommand.inputRightArrow: return "freccia destra"
        case UIKeyCommand.inputEscape: return "tasto Esc"
        case " ": return "barra spaziatrice"
        case "=": return "tasto più"
        case "-": return "tasto meno"
        default: return "tasto \(input.uppercased())"
        }
    }
}

enum KeyboardCommandsCatalog {
    /// I comandi della reading view, in ordine di presentazione nel pannello.
    static let reading: [KeyboardCommandSpec] = [
        KeyboardCommandSpec(id: "scrollForward", title: "Scorri avanti",
            input: UIKeyCommand.inputDownArrow, modifiers: .command,
            description: "Avanza di una schermata nella lettura."),
        KeyboardCommandSpec(id: "scrollBack", title: "Scorri indietro",
            input: UIKeyCommand.inputUpArrow, modifiers: .command,
            description: "Torna indietro di una schermata."),
        KeyboardCommandSpec(id: "nextHeading", title: "Intestazione successiva",
            input: UIKeyCommand.inputDownArrow, modifiers: .alternate,
            description: "Salta al titolo (intestazione) successivo, come il rotore Intestazioni di VoiceOver."),
        KeyboardCommandSpec(id: "prevHeading", title: "Intestazione precedente",
            input: UIKeyCommand.inputUpArrow, modifiers: .alternate,
            description: "Salta al titolo precedente."),
        KeyboardCommandSpec(id: "textLarger", title: "Testo più grande",
            input: "=", modifiers: .command,
            description: "Ingrandisce il testo di lettura di un passo. Sulla tastiera italiana: Comando e il tasto più.",
            alternateInputs: ["+"]),
        KeyboardCommandSpec(id: "textSmaller", title: "Testo più piccolo",
            input: "-", modifiers: .command,
            description: "Rimpicciolisce il testo di lettura di un passo."),
        KeyboardCommandSpec(id: "bookmark", title: "Segnalibro",
            input: "b", modifiers: .command,
            description: "Aggiunge o toglie un segnalibro sull'elemento in lettura."),
        KeyboardCommandSpec(id: "elementTools", title: "Strumenti elemento",
            input: "e", modifiers: .command,
            description: "Apre il menu con segnalibro e sottolineatura per l'elemento in lettura; Esc lo chiude."),
        KeyboardCommandSpec(id: "noteJump", title: "Nota e richiamo",
            input: "j", modifiers: .command,
            description: "Sulla nota va al testo del richiamo; sul testo che richiama una nota va alla nota. Come le azioni «Vai al testo del richiamo» e «Vai alla nota»."),
        KeyboardCommandSpec(id: "back", title: "Indietro",
            input: UIKeyCommand.inputEscape, modifiers: [],
            description: "Chiude la lettura e torna alla schermata precedente. Nello split screen chiede se chiudere la metà che comanda."),
    ]

    /// I comandi dello split screen (§ 11, solo iPad). I comandi di lettura qui sopra valgono per la metà che COMANDA
    /// (§ 11.6); questi scelgono la metà, e portano lì anche il fuoco di VoiceOver.
    static let split: [KeyboardCommandSpec] = [
        KeyboardCommandSpec(id: "splitLeft", title: "Metà sinistra",
            input: UIKeyCommand.inputLeftArrow, modifiers: [.command, .alternate],
            description: "Nello split screen: comanda la metà sinistra (i comandi di lettura valgono per lei)."),
        KeyboardCommandSpec(id: "splitRight", title: "Metà destra",
            input: UIKeyCommand.inputRightArrow, modifiers: [.command, .alternate],
            description: "Nello split screen: comanda la metà destra (i comandi di lettura valgono per lei)."),
    ]
}
