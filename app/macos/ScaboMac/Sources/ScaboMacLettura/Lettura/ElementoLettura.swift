//
//  ElementoLettura.swift
//  ScaboMacLettura — UN elemento della lettura (giro «app unica per Mac, tappa A», 2026-11-08; dal prototipo del giro «disegno
//  della lettura per Mac», `docs/DISEGNO_LETTURA_MAC.md` § 2-3): un `NSAccessibilityElement` virtuale, senza una NSView dietro,
//  che prende tutto ciò che dice e offre dal modulo del parlato (ScaboCore `ReadingSpeech`) attraverso la vista. La vista non
//  ha parole proprie.
//
//  Mappa degli attributi sul Mac (§ 3.1 del disegno; l'ordine di pronuncia lo dice la prova d'orecchio T2):
//    AXRole        = testo statico (il livello del titolo lo dicono il parlato «Intestazione di livello N.» e i rotori)
//    AXValue       = il testo pronunciato (`intendedAccessibilityLabel`)
//    AXDescription = il valore secondario (`value(forIndex:)`: la pagina della risorsa visiva), se c'è
//    AXFocused     = settabile: il GANCIO DEL FUOCO (§ 4): se VoiceOver lo imposta quando il cursore arriva qui, la vista
//                    calcola i segnali del modulo (`focusSignals`) e porta la riga in vista
//    azioni personalizzate = `actions(forIndex:bookmark:settings:)`
//    AXLinkedUIElements = i bersagli dei salti nota ↔ richiamo del modulo (`noteJumpActions`), per VO+J (dal 2026-11-11)
//  Il genitore è sempre la vista; in un libro lungo la vista espone fra i figli solo una finestra attorno al fuoco (dal giro
//  «prove della tappa A», 2026-11-09): un elemento fuori dalla finestra esiste comunque, e i rotori e i salti lo raggiungono.
//
import AppKit
import ScaboCore

public final class ElementoLettura: NSAccessibilityElement, NSAccessibilityElementProtocol {
    public let indice: Int
    public unowned let vista: VistaLettura

    public init(indice: Int, vista: VistaLettura) {
        self.indice = indice
        self.vista = vista
        super.init()
    }

    @inline(__always) private func nota(_ richiesta: String) { vista.diario.registra(indice, richiesta) }

    override public func isAccessibilityElement() -> Bool { true }
    /// Il livello se l'elemento è un titolo e la variante attiva gli dà il ruolo d'intestazione (`VarianteTitoli`: in tutte e
    /// quattro le varianti; dal giro «ScaboPDF per Mac su TestFlight», 2026-11-12, prima il titolo era testo statico).
    private var livelloTitolo: Int? { VarianteTitoli.ruoloIntestazione ? vista.livelloTitolo(indice) : nil }
    override public func accessibilityRole() -> NSAccessibility.Role? {
        nota("AXRole")
        return livelloTitolo != nil ? NSAccessibility.Role(rawValue: "AXHeading") : .staticText
    }
    override public func accessibilityTitle() -> String? {
        guard livelloTitolo != nil, VarianteTitoli.stileWebKit else { return nil }
        nota("AXTitle"); vista.notaAttenzione(indice)
        return vista.testoSenzaQualifica(indice)
    }
    /// Il livello del titolo nell'attributo di macOS 26 (`NSAccessibilityHeadingLevelAttribute`, 1-based), come SwiftUI.
    override public func accessibilityAttributeValue(_ attribute: NSAccessibility.Attribute) -> Any? {
        if attribute.rawValue == "AXHeadingLevel", let n = livelloTitolo, !VarianteTitoli.stileWebKit {
            nota("AXHeadingLevel"); return NSNumber(value: n)
        }
        return super.accessibilityAttributeValue(attribute)
    }
    /// Il livello anche nell'elenco degli attributi (rilievo R6 della revisione: un client che guarda prima l'elenco lo trova).
    override public func accessibilityAttributeNames() -> [NSAccessibility.Attribute] {
        let n = super.accessibilityAttributeNames()
        return livelloTitolo != nil && !VarianteTitoli.stileWebKit ? n + [NSAccessibility.Attribute(rawValue: "AXHeadingLevel")] : n
    }
    override public func accessibilityParameterizedAttributeNames() -> [NSAccessibility.ParameterizedAttribute] {
        let n = super.accessibilityParameterizedAttributeNames()
        return VarianteTitoli.ricercaGenerica ? n + [NSAccessibility.ParameterizedAttribute(rawValue: "AXUIElementsForSearchPredicate")] : n
    }
    override public func accessibilityAttributeValue(_ attribute: NSAccessibility.ParameterizedAttribute, forParameter parameter: Any?) -> Any? {
        if VarianteTitoli.ricercaGenerica, attribute.rawValue == "AXUIElementsForSearchPredicate" {
            nota("ricerca-generica")
            if let r = vista.ricercaGenerica(parameter, da: indice) { return r }
        }
        return super.accessibilityAttributeValue(attribute, forParameter: parameter)
    }
    override public func accessibilityIdentifier() -> String { "lettura.elemento.\(indice)" }
    override public func accessibilityValue() -> Any? {
        nota("AXValue")
        vista.notaAttenzione(indice)   // fuori dalla finestra: la voce di un rotore che VoiceOver sta per raggiungere
        if let n = livelloTitolo {
            // WebKit: il livello nel valore; SwiftUI: nessun valore (qui il valore secondario, se c'è).
            return VarianteTitoli.stileWebKit ? NSNumber(value: n) : vista.valore(indice)
        }
        return vista.testoPronunciato(indice)
    }
    override public func accessibilityLabel() -> String? {
        nota("AXDescription")
        if livelloTitolo != nil, !VarianteTitoli.stileWebKit {
            vista.notaAttenzione(indice)   // il testo del titolo sta qui: VoiceOver lo legge prima di posarsi
            return vista.testoSenzaQualifica(indice)
        }
        return vista.valore(indice)
    }
    override public func accessibilityParent() -> Any? { vista }
    override public func accessibilityWindow() -> Any? { vista.window }
    override public func accessibilityTopLevelUIElement() -> Any? { vista.window }
    override public func accessibilityFrame() -> NSRect { nota("AXFrame"); return vista.corniceSchermo(indice) }
    override public func accessibilityFrameInParentSpace() -> NSRect { vista.rettangolo(indice) }

    override public func isAccessibilityFocused() -> Bool { nota("AXFocused?"); return vista.fuoco == indice }
    /// IL GANCIO DEL FUOCO: ridefinire il setter rende AXFocused settabile; se VoiceOver lo imposta quando il cursore arriva
    /// sull'elemento, da qui partono i segnali e lo scorrimento (e la posizione di lettura si registra).
    override public func setAccessibilityFocused(_ flag: Bool) {
        nota("AXFocused=\(flag)")
        if flag { vista.riceviFuoco(indice, origine: .accessibilita) }
    }

    override public func accessibilityCustomActions() -> [NSAccessibilityCustomAction]? {
        nota("AXCustomActions")
        // VoiceOver chiede le azioni dell'elemento su cui si posa (diari T1 e T3): se era il bersaglio di un salto, è arrivato.
        vista.notaArrivo(indice)
        return vista.azioniPersonalizzate(indice)
    }

    /// I ROTORI ANCHE SULL'ELEMENTO (giro «titoli con il comando di VoiceOver sul Mac», 2026-11-12, DISEGNO § 5.4): gli stessi
    /// rotori del gruppo, gli stessi oggetti, col delegato della vista che cerca nel modulo su tutto il libro. Nella prova 6, in
    /// sei delle sette pressioni di VO+Comando+H chieste, VoiceOver ha chiesto due volte i rotori del gruppo e non ha mai
    /// interrogato il rotore (diario); da fuori la stessa traccia la danno due ricerche per chiave (`AXResultsForSearchPredicate`)
    /// rivolte all'elemento sotto il cursore, a cui AppKit risponde «nessun valore» perché i rotori stanno sul genitore (sul
    /// gruppo la stessa ricerca arriva al rotore); è una delle due vie compatibili col diario (DISEGNO § 5.4). Con i rotori anche
    /// qui, la ricerca rivolta all'elemento arriva al rotore del tipo che corrisponde alla chiave: titoli, livelli, tabelle,
    /// immagini, risultati della ricerca, anche fuori dalla finestra dei figli.
    override public func accessibilityCustomRotors() -> [NSAccessibilityCustomRotor] {
        nota("AXCustomRotors")
        return vista.rotori()
    }

    /// GLI ELEMENTI COLLEGATI (dal giro «comandi da tastiera e VoiceOver sul Mac», 2026-11-11): la nota è collegata al testo
    /// del suo richiamo, il testo che richiama note alle sue note, nell'ordine dei salti del modulo (il primo è il bersaglio di
    /// ⌘J). È l'attributo che VoiceOver usa per il suo comando «vai all'elemento collegato», VO+J (DISEGNO § 5.4): così il salto
    /// fra nota e richiamo c'è anche con un comando di VoiceOver, che l'utente conosce già. Senza legame, nessun collegamento.
    override public func accessibilityLinkedUIElements() -> [Any]? {
        nota("AXLinkedUIElements")
        let collegati = vista.collegati(indice)
        return collegati.isEmpty ? nil : collegati
    }
}
