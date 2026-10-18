//
//  RootTabBarController.swift
//  ScaboApp
//
//  La navigazione principale a tab (§ 12.1): Home, Ricerca, Impostazioni. È il radicamento
//  dell'app dopo l'introduzione della libreria. Ogni tab è una navigation stack propria, così la
//  Home può entrare nei contenitori risalendo con "indietro" (§ 12.3). La barra a tab di sistema è
//  pienamente accessibile a VoiceOver (ogni tab annuncia nome e stato selezionato).
//
//  Ordine di lettura (giro «accessibilità e completamento», 2026-10-18, § 12.1): in ogni schermata con le schede
//  VoiceOver legge il titolo, poi le schede, poi gli altri comandi, poi il contenuto (`ScreenReadingOrder`). Le pile sono
//  `TabStackNavigationController` (il titolo della schermata in una fascia nostra); l'elenco si ricalcola a ogni
//  impaginazione, cambio di scheda, cambio di schermata e cambio di titolo.
//

import UIKit

final class RootTabBarController: UITabBarController, UITabBarControllerDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self

        let home = TabStackNavigationController(rootViewController: HomeViewController())
        home.tabBarItem = UITabBarItem(title: "Home", image: UIImage(systemName: "house"), selectedImage: UIImage(systemName: "house.fill"))
        home.tabBarItem.accessibilityHint = "Recenti e workspaces"

        let search = TabStackNavigationController(rootViewController: SearchViewController())
        search.tabBarItem = UITabBarItem(title: "Ricerca", image: UIImage(systemName: "magnifyingglass"), selectedImage: UIImage(systemName: "magnifyingglass"))
        search.tabBarItem.accessibilityHint = "Cerca ed elimina documenti dall'archivio"

        let settings = TabStackNavigationController(rootViewController: SettingsViewController())
        settings.tabBarItem = UITabBarItem(title: "Impostazioni", image: UIImage(systemName: "gearshape"), selectedImage: UIImage(systemName: "gearshape.fill"))
        settings.tabBarItem.accessibilityHint = "Tema, granularità di lettura e pagine"

        for stack in [home, search, settings] {
            stack.onScreenChanged = { [weak self] in self?.refreshReadingOrder() }
        }
        viewControllers = [home, search, settings]
    }

    /// La navigation stack della Home, dove presentare il lettore in riapertura all'avvio (§ 2.5).
    var homeNavigationController: UINavigationController? {
        viewControllers?.first as? UINavigationController
    }

    // MARK: - Ordine di lettura (titolo, schede, comandi, contenuto)

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        refreshReadingOrder()
    }

    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        refreshReadingOrder()
    }

    /// Ricalcola l'elenco dei blocchi; `nil` (struttura non riconosciuta) lascia l'ordine di sistema.
    func refreshReadingOrder() {
        view.accessibilityElements = ScreenReadingOrder.elements(for: self)
    }
}
