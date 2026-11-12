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

    /// Le scorciatoie ALTERNATIVE dei titoli (dal giro «titoli di VoiceOver: le varianti», 2026-11-12, DISEGNO § 5.5): ⌃⌘↓ e
    /// ⌃⌘↑, senza Opzione. Con VoiceOver acceso ⌥⌘↓ e ⌥⌘↑ non sono mai arrivate all'app nelle prove 6 e 7, mentre ⌘J sì; il
    /// sistema non le usa e l'app le riceve coi tasti veri dei test: chi le prende sta prima dell'app (VoiceOver, dedotto per
    /// esclusione). Queste sono libere: non sono comandi di VoiceOver senza il tasto VO (che è Control più Opzione), non sono
    /// scorciatoie del sistema (elenco delle scorciatoie registrate su questo Mac) né dell'app. Sono voci ALTERNATIVE di quelle
    /// dei titoli: nel menu si legge una voce sola per
    /// comando (l'alternativa compare al suo posto solo tenendo Control col menu aperto), e la scorciatoia vale sempre. Restano
    /// ⌥⌘↓ e ⌥⌘↑ (decisione 14); se tenerle entrambe lo decide il maintainer dopo la prova 8.
    public static let alternativeLettura: [Voce] = [
        Voce(titolo: Parole.titoloSuccessivo, tasto: frecciaGiu, modificatori: [.command, .control],
             selettore: #selector(FinestraLettura.titoloSuccessivo(_:))),
        Voce(titolo: Parole.titoloPrecedente, tasto: frecciaSu, modificatori: [.command, .control],
             selettore: #selector(FinestraLettura.titoloPrecedente(_:))),
    ]

    public static let vociLibro: [Voce] = [
        Voce(titolo: Parole.apri, tasto: frecciaGiu, modificatori: [.command], selettore: #selector(FinestraHome.apriLibroSelezionato(_:))),
        Voce(titolo: Parole.eliminaConPuntini, tasto: cancella, modificatori: [.command],
             selettore: #selector(FinestraHome.eliminaLibroSelezionato(_:))),
    ]

    /// La barra dei menu completa.
    public static func barra(comandi: ComandiApp) -> NSMenu {
        let barra = NSMenu()
        func menu(_ titolo: String, _ riempi: (NSMenu) -> Void) {
            let voce = NSMenuItem(); barra.addItem(voce)
            let m = NSMenu(title: titolo); riempi(m); voce.submenu = m
        }
        func aggiungi(_ m: NSMenu, _ v: Voce, verso: AnyObject? = nil, alternativa: Bool = false) {
            let item = NSMenuItem(title: v.titolo, action: v.selettore, keyEquivalent: v.tasto)
            item.keyEquivalentModifierMask = v.modificatori
            item.target = verso
            item.isAlternate = alternativa
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
                // L'alternativa subito dopo la sua voce: stesso titolo, stesso comando, stesso tasto, altri modificatori.
                if let alt = alternativeLettura.first(where: { $0.selettore == v.selettore }) { aggiungi(m, alt, alternativa: true) }
            }
        }
        menu(Parole.menuFinestra) { m in
            aggiungi(m, Voce(titolo: Parole.home, tasto: "0", modificatori: [.command],
                             selettore: #selector(ComandiApp.mostraHome(_:))), verso: comandi)
            aggiungi(m, Voce(titolo: Parole.modelliEOfficina, tasto: "m", modificatori: [.command, .shift],
                             selettore: #selector(ComandiApp.mostraModelliEOfficina(_:))), verso: comandi)
            m.addItem(.separator())
            m.addItem(withTitle: Parole.riduci, action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
            NSApp?.windowsMenu = m
        }
        return barra
    }
}
