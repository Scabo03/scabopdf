//
//  ScreenReadingOrder.swift
//  ScaboApp
//
//  L'ORDINE DI LETTURA delle schermate con le schede (giro «accessibilità e completamento», 2026-10-18;
//  LAYER2_PRODUCT_DECISIONS § 12.1): VoiceOver legge prima il TITOLO della schermata, subito dopo le SCHEDE (Home,
//  Ricerca, Impostazioni), poi gli altri COMANDI della barra in alto (Indietro, Tag, Affianca, Importa, Cerca…), infine
//  il CONTENUTO (recenti, workspace, elenchi). L'ordine segue l'importanza.
//
//  ── Perché serve un ordine esplicito ─────────────────────────────────────────────────────────────────────────────
//
//  Lasciato al sistema, l'ordine cambia con la generazione e con l'apparecchio (misura del giro, test d'interfaccia):
//  sull'iPad con iPadOS 27 la barra delle schede galleggiante IN ALTO è letta per ULTIMA, dopo tutta la libreria; sull'iPad
//  con iPadOS 26.5 è letta per prima ma il titolo della schermata non c'è; sull'iPhone la barra è in basso e si legge per
//  ultima. Nessuna API pubblica regola l'ordine fra barra delle schede e contenuto: l'unica leva pubblica è l'elenco
//  `accessibilityElements` del contenitore comune, la vista del controller delle schede (nostra).
//
//  ── Perché così (robustezza rispetto ai cambi di sistema) ────────────────────────────────────────────────────────
//
//  L'elenco non duplica né inventa nulla: dispone in ordine pochi BLOCCHI — sottoalberi di viste — e accoda tutto il resto
//  dell'albero nell'ordine delle viste (`elements(root:anchors:)`). Così ogni elemento resta raggiungibile esattamente una
//  volta per costruzione, qualunque cosa il sistema metta nelle barre (pulsanti nuovi, una ricerca integrata, una barra
//  degli strumenti): nessun vicolo cieco, nessun doppione. I blocchi si riconoscono solo con API pubbliche e senza nomi
//  di classi private:
//   • il TITOLO: la fascia nostra di `TabStackNavigationController` (il titolo grande di sistema non si mostra: dentro la
//     barra il sistema lo legge DOPO i pulsanti e quell'ordine interno non si cambia con API pubbliche; elencare i pezzi
//     interni della barra lo fa sparire da VoiceOver, provato nel giro; e sull'iPad con iPadOS 26.5 il sistema non lo mostra);
//   • le SCHEDE: il figlio diretto della vista del controller che NON contiene il contenuto e contiene `tabBar` (iPhone,
//     barra in basso) o una vista col tratto d'accessibilità `.tabBar` (iPad, barra galleggiante);
//   • la BARRA: la barra di navigazione intera (pubblica), coi suoi comandi nell'ordine del sistema;
//   • il CONTENUTO: la vista del controller in cima alla pila (pubblica).
//  Se le schede non si riconoscono l'elenco si toglie e torna l'ordine di sistema (mai peggio di prima); senza la fascia
//  la barra viene prima delle schede (titolo e comandi nell'ordine del sistema). Un cambio futuro del sistema può quindi
//  solo riportare l'ordine indietro, mai togliere o duplicare elementi; i test d'interfaccia `ReadingOrderUITests` lo
//  fissano su iPad e iPhone e diventano rossi alla prima regressione.
//

import UIKit

enum ScreenReadingOrder {

    /// L'ordine dei blocchi di una schermata con le schede, o `nil` (ordine di sistema) se la struttura non si riconosce.
    static func elements(for tabs: UITabBarController) -> [UIView]? {
        guard tabs.isViewLoaded, let root = tabs.view,
              let nav = tabs.selectedViewController as? UINavigationController,
              let screen = nav.topViewController, screen.isViewLoaded,
              screen.view.isDescendant(of: root),
              let tabContainer = tabContainer(in: tabs, content: screen.view)
        else { return nil }
        let bar = nav.navigationBar
        let barShown = bar.isDescendant(of: root) && !bar.isHidden
        var anchors: [UIView] = []
        if let stack = nav as? TabStackNavigationController, !stack.titleBand.isHidden, stack.titleBand.isDescendant(of: root) {
            anchors = [stack.titleBand, tabContainer] + (barShown ? [bar] : []) + [screen.view]
        } else if barShown {
            anchors = [bar, tabContainer, screen.view]   // titolo e comandi nell'ordine del sistema, poi le schede
        } else {
            anchors = [tabContainer, screen.view]
        }
        let list = elements(root: root, anchors: anchors)
        return list.isEmpty ? nil : list   // mai un elenco vuoto: nasconderebbe tutto
    }

    /// Il contenitore della barra delle schede: il figlio diretto di `tabs.view` che non contiene il contenuto e contiene
    /// la `tabBar` (iPhone) o una vista col tratto `.tabBar` (barra galleggiante dell'iPad). `nil` se non ce n'è uno solo.
    static func tabContainer(in tabs: UITabBarController, content: UIView) -> UIView? {
        let candidates = tabs.view.subviews.filter { child in
            !content.isDescendant(of: child)
                && (tabs.tabBar.isDescendant(of: child) || containsTabBarTrait(child))
        }
        return candidates.count == 1 ? candidates[0] : nil
    }

    /// Le `anchors` nell'ordine dato, poi ogni altro sottoalbero di `root` nell'ordine delle viste: ogni vista dell'albero
    /// sta in uno e un solo elemento dell'elenco. Le ancore devono essere discendenti di `root` e disgiunte (nessuna
    /// contiene un'altra): altrimenti si restituisce l'elenco vuoto e chi chiama ripiega sull'ordine di sistema.
    static func elements(root: UIView, anchors: [UIView]) -> [UIView] {
        guard !anchors.isEmpty, anchors.allSatisfy({ $0 !== root && $0.isDescendant(of: root) }) else { return [] }
        for (i, a) in anchors.enumerated() {
            for b in anchors[(i + 1)...] where a.isDescendant(of: b) || b.isDescendant(of: a) { return [] }
        }
        let anchorSet = Set(anchors.map(ObjectIdentifier.init))
        var onPath = Set<ObjectIdentifier>()
        for a in anchors {
            var v = a.superview
            while let x = v, x !== root { onPath.insert(ObjectIdentifier(x)); v = x.superview }
        }
        var rest: [UIView] = []
        func collect(_ node: UIView) {
            for child in node.subviews {
                let id = ObjectIdentifier(child)
                if anchorSet.contains(id) { continue }
                if onPath.contains(id) { collect(child) } else { rest.append(child) }
            }
        }
        collect(root)
        return anchors + rest
    }

    private static func containsTabBarTrait(_ v: UIView) -> Bool {
        if v.accessibilityTraits.contains(.tabBar) { return true }
        return v.subviews.contains(where: containsTabBarTrait)
    }
}
