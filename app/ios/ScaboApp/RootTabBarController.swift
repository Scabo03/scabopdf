//
//  RootTabBarController.swift
//  ScaboApp
//
//  La navigazione principale a tab in basso (§ 12.1): Home, Ricerca, Impostazioni. È il radicamento
//  dell'app dopo l'introduzione della libreria. Ogni tab è una navigation stack propria, così la
//  Home può entrare nei contenitori risalendo con "indietro" (§ 12.3). La barra a tab di sistema è
//  pienamente accessibile a VoiceOver (ogni tab annuncia nome e stato selezionato).
//

import UIKit

final class RootTabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()

        let home = UINavigationController(rootViewController: HomeViewController())
        home.tabBarItem = UITabBarItem(title: "Home", image: UIImage(systemName: "house"), selectedImage: UIImage(systemName: "house.fill"))
        home.tabBarItem.accessibilityHint = "Recenti e workspaces"

        let search = UINavigationController(rootViewController: SearchViewController())
        search.tabBarItem = UITabBarItem(title: "Ricerca", image: UIImage(systemName: "magnifyingglass"), selectedImage: UIImage(systemName: "magnifyingglass"))
        search.tabBarItem.accessibilityHint = "Cerca ed elimina documenti dall'archivio"

        let settings = UINavigationController(rootViewController: SettingsViewController())
        settings.tabBarItem = UITabBarItem(title: "Impostazioni", image: UIImage(systemName: "gearshape"), selectedImage: UIImage(systemName: "gearshape.fill"))
        settings.tabBarItem.accessibilityHint = "Tema, granularità di lettura e pagine"

        viewControllers = [home, search, settings]
    }

    /// La navigation stack della Home, dove presentare il lettore in riapertura all'avvio (§ 2.5).
    var homeNavigationController: UINavigationController? {
        viewControllers?.first as? UINavigationController
    }
}
