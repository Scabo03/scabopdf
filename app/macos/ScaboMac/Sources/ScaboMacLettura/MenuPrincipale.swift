//
//  MenuPrincipale.swift
//  ScaboMacLettura — la barra dei menu dell'app Mac (giro «app unica per Mac, tappa A», 2026-11-08). Sul Mac molti utenti di
//  VoiceOver cercano i comandi nella barra dei menu più che nel menu delle azioni (DISEGNO_LETTURA_MAC § 5.2): ogni azione
//  della lettura ha qui il suo duplicato, con le scorciatoie dell'iPad dove esistono. Nessuna voce usa Control+Opzione, il tasto
//  di VoiceOver. Le voci della Home e della lettura vanno al primo risponditore (la finestra in primo piano); quelle dell'app
//  al delegato.
//
import AppKit

/// I comandi dell'app (li esegue il delegato dell'app).
@objc public protocol ComandiApp {
    func importaDocumento(_ sender: Any?)
    func mostraHome(_ sender: Any?)
    func mostraModelliEOfficina(_ sender: Any?)
    func mostraImpostazioni(_ sender: Any?)
    /// Il pannello «Diagnostica» (giro «ScaboPDF per Mac su TestFlight», 2026-11-12): la voce si vede solo se le Impostazioni lo
    /// chiedono (`PreferenzeDiagnostica.mostrata`).
    func mostraDiagnostica(_ sender: Any?)
}

public enum MenuPrincipale {

    public struct Voce: Equatable {
        public let titolo: String
        public let tasto: String
        public let modificatori: NSEvent.ModifierFlags
        public let selettore: Selector
    }

    static let frecciaGiu = String(UnicodeScalar(NSDownArrowFunctionKey)!)
    static let frecciaSu = String(UnicodeScalar(NSUpArrowFunctionKey)!)
    static let cancella = String(UnicodeScalar(NSBackspaceCharacter)!)

    /// Le voci del menu «Lettura» della tappa A, nell'ordine. Segnalibro (⌘B), ricerca (⌘F, ⌘G, ⇧⌘G), «Strumenti elemento»
    /// (⌘E) ed «Estrai come immagine» arrivano con le loro tappe (DISEGNO § 9).
    public static let vociLettura: [Voce] = [
        Voce(titolo: Parole.vaiNotaRichiamo, tasto: "j", modificatori: [.command],
             selettore: #selector(FinestraLettura.saltaNotaRichiamo(_:))),
        Voce(titolo: Parole.titoloSuccessivo, tasto: frecciaGiu, modificatori: [.command, .option],
             selettore: #selector(FinestraLettura.titoloSuccessivo(_:))),
        Voce(titolo: Parole.titoloPrecedente, tasto: frecciaSu, modificatori: [.command, .option],
             selettore: #selector(FinestraLettura.titoloPrecedente(_:))),
        Voce(titolo: Parole.saltaRisorsa, tasto: "", modificatori: [],
             selettore: #selector(FinestraLettura.saltaRisorsa(_:))),
    ]

    public static let vociLibro: [Voce] = [
        Voce(titolo: Parole.apri, tasto: frecciaGiu, modificatori: [.command], selettore: #selector(FinestraHome.apriLibroSelezionato(_:))),
        Voce(titolo: Parole.eliminaConPuntini, tasto: cancella, modificatori: [.command],
             selettore: #selector(FinestraHome.eliminaLibroSelezionato(_:))),
    ]

    /// L'etichetta della voce «Diagnostica…» nel menu «Finestra»: l'app la mostra o la nasconde (`voceDiagnostica`). Nascosta,
    /// la voce non c'è per VoiceOver né per i test da fuori.
    public static let identificatoreDiagnostica = NSUserInterfaceItemIdentifier("menu.diagnostica")

    /// La voce «Diagnostica…» della barra (nel menu «Finestra»), se c'è.
    public static func voceDiagnostica(in barra: NSMenu?) -> NSMenuItem? {
        for v in barra?.items ?? [] {
            if let x = v.submenu?.items.first(where: { $0.identifier == identificatoreDiagnostica }) { return x }
        }
        return nil
    }

    /// La barra dei menu completa. `diagnostica`: se la voce «Diagnostica…» si vede.
    public static func barra(comandi: ComandiApp, diagnostica: Bool = false) -> NSMenu {
        let barra = NSMenu()
        func menu(_ titolo: String, _ riempi: (NSMenu) -> Void) {
            let voce = NSMenuItem(); barra.addItem(voce)
            let m = NSMenu(title: titolo); riempi(m); voce.submenu = m
        }
        func aggiungi(_ m: NSMenu, _ v: Voce, verso: AnyObject? = nil) {
            let item = NSMenuItem(title: v.titolo, action: v.selettore, keyEquivalent: v.tasto)
            item.keyEquivalentModifierMask = v.modificatori
            item.target = verso
            m.addItem(item)
        }
        menu(Parole.nomeApp) { m in
            m.addItem(withTitle: Parole.informazioni, action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
            m.addItem(.separator())
            aggiungi(m, Voce(titolo: Parole.impostazioniConPuntini, tasto: ",", modificatori: [.command],
                             selettore: #selector(ComandiApp.mostraImpostazioni(_:))), verso: comandi)
            m.addItem(.separator())
            m.addItem(withTitle: Parole.esci, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        }
        menu(Parole.menuArchivio) { m in
            aggiungi(m, Voce(titolo: Parole.importaConPuntini, tasto: "o", modificatori: [.command],
                             selettore: #selector(ComandiApp.importaDocumento(_:))), verso: comandi)
            m.addItem(.separator())
            m.addItem(withTitle: Parole.chiudiFinestra, action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        }
        menu(Parole.menuLibro) { m in for v in vociLibro { aggiungi(m, v) } }
        menu(Parole.menuLettura) { m in
            for (k, v) in vociLettura.enumerated() {
                if k == 3 { m.addItem(.separator()) }
                aggiungi(m, v)
            }
        }
        menu(Parole.menuFinestra) { m in
            aggiungi(m, Voce(titolo: Parole.home, tasto: "0", modificatori: [.command],
                             selettore: #selector(ComandiApp.mostraHome(_:))), verso: comandi)
            aggiungi(m, Voce(titolo: Parole.modelliEOfficina, tasto: "m", modificatori: [.command, .shift],
                             selettore: #selector(ComandiApp.mostraModelliEOfficina(_:))), verso: comandi)
            let d = NSMenuItem(title: Parole.diagnosticaConPuntini, action: #selector(ComandiApp.mostraDiagnostica(_:)), keyEquivalent: "")
            d.target = comandi
            d.identifier = identificatoreDiagnostica
            d.isHidden = !diagnostica
            m.addItem(d)
            m.addItem(.separator())
            m.addItem(withTitle: Parole.riduci, action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
            NSApp?.windowsMenu = m
        }
        return barra
    }
}
