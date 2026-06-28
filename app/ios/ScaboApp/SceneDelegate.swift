//
//  SceneDelegate.swift
//  ScaboApp
//
//  Created by Luca Scabini on 11/06/2026.
//

import UIKit
import ScaboCore

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?


    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Radicamento programmatico della navigazione a tab (Home, Ricerca, Impostazioni, § 12.1).
        // ADDITIVO E REVERSIBILE: sovrascrive la window dello storyboard senza toccare
        // `Main.storyboard`/`ViewController` (che restano dormienti). Il tema memorizzato è applicato
        // alla finestra; se all'ultima chiusura era aperto un documento e il suo contenuto è in cache,
        // lo si riapre al punto di lettura (§ 2.5, riapertura nello stato di chiusura).
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        let tabBar = RootTabBarController()
        window.rootViewController = tabBar
        self.window = window
        AppTheme.applyStored(to: window)
        window.makeKeyAndVisible()

        if let lastId = LibraryService.shared.store.lastOpenDocumentId {
            // Differito dopo che la finestra è visibile, così la presentazione modale è valida.
            DispatchQueue.main.async {
                DocumentOpener.reopenFromCache(documentId: lastId, from: tabBar)
            }
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }


}

