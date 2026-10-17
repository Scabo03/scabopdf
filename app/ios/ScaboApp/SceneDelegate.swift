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
        self.window = window
        let prefs = LibraryService.shared.prefs

        #if DEBUG
        // Affordance SOLO per gli UI-test (guardata `DEBUG` → assente in Release/TestFlight): riporta
        // lo stato di prima apertura, così l'audit di accessibilità parte deterministico dal chooser.
        if CommandLine.arguments.contains("-uiTestFreshStart") {
            setStoredFirstOpenCompleted(prefs, false)
            setStoredAppearanceSource(prefs, .followSystem)
        }
        if CommandLine.arguments.contains("-uiTestSeedReprocess")
            || CommandLine.arguments.contains("-uiTestSeedReprocessKinds")
            || CommandLine.arguments.contains("-uiTestSeedDuplicateImport")
            || CommandLine.arguments.contains("-uiTestSeedVisualResource")
            || CommandLine.arguments.contains("-uiTestSeedVisualResourceControl")
            || UITestSeeding.macReadingSeeds.contains(where: CommandLine.arguments.contains) {
            setStoredFirstOpenCompleted(prefs, true)
            UITestSeeding.applyIfRequested()
        }
        // Consegna di «Apri con» ad APP IN CORSA, per i test d'interfaccia: `XCUIApplication.open` rilancia l'app, quindi
        // non prova l'arrivo con un libro aperto. Dopo i secondi dati si chiama la stessa funzione del sistema.
        if let i = CommandLine.arguments.firstIndex(of: "-uiTestDeliverMacReadingAfter"),
           CommandLine.arguments.indices.contains(i + 1), let seconds = Double(CommandLine.arguments[i + 1]) {
            DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
                self?.receive([URL(fileURLWithPath: UITestSeeding.outsidePackagePath)])
            }
        }
        #endif

        // Prima apertura (design accessibilità visiva): l'utente sceglie il tema con una schermata
        // PIENAMENTE ACCESSIBILE, PRIMA di aver configurato qualsiasi cosa. La si radica come
        // rootViewController (nessun problema di timing di presentazione modale); alla scelta si
        // applica l'aspetto e si passa alla Home. La scelta resta modificabile dalle Impostazioni.
        if getStoredFirstOpenCompleted(prefs) {
            window.rootViewController = RootTabBarController()
        } else {
            let chooser = FirstOpenThemeChooserViewController(prefs: prefs) { [weak window] in
                guard let window else { return }
                ReadingAppearance.applyToWindow(window, prefs: LibraryService.shared.prefs)
                window.rootViewController = RootTabBarController()  // niente animazione vistosa (SPECS § A.4)
            }
            window.rootViewController = UINavigationController(rootViewController: chooser)
        }
        // Il tema memorizzato è applicato alla finestra (posizione B → chiaro/scuro forzato; A → sistema).
        ReadingAppearance.applyToWindow(window, prefs: prefs)
        window.makeKeyAndVisible()

        // Identità del documento (giro «identità», 2026-10-11): i libri già in libreria ricevono
        // l'impronta del contenuto in sottofondo, uno alla volta, senza bloccare la lettura e senza
        // rielaborare nulla. Serve a riconoscere lo stesso libro (importazione, e il frutto del Mac).
        DocumentIdentity.fingerprintMissingDocumentsInBackground()

        // Letture preparate dal Mac (giro «costruzione della linea Mac», 2026-10-16, § 12.12): quelle trascinate col
        // cavo nella cartella dell'app si raccolgono; quella con cui l'app è stata aperta (AirDrop, «Apri con») si propone.
        ReceivedReadings.collectArrivals()
        if !connectionOptions.urlContexts.isEmpty {
            let urls = connectionOptions.urlContexts.map { $0.url }
            DispatchQueue.main.async { [weak self] in self?.receive(urls) }
        }

        // Avvio SEMPRE sulla Home stabile. La riapertura automatica dell'ultimo documento
        // all'avvio è DISABILITATA di proposito: presentare (e far leggere a VoiceOver) un
        // documento pesante durante il collegamento della scena rischia un'espulsione all'avvio
        // (jetsam/watchdog) e lascia l'app in uno stato di presentazione instabile. Il documento
        // si apre SOLO su azione dell'utente dai Recenti. Degradazione ragionevole (§ 2.5: il
        // principio di riapertura non è un vincolo assoluto). L'ultimo-documento resta memorizzato
        // per i Recenti; semplicemente non lo si ripresenta da solo.
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
        // Le letture del Mac trascinate col cavo mentre l'app era in sottofondo: la Home le mostra al ritorno.
        if ReceivedReadings.collectArrivals() > 0 {
            NotificationCenter.default.post(name: ReceivedReadings.didChange, object: nil)
        }
    }

    /// AirDrop, «Apri con», File: iOS consegna il file della lettura (copiato in `Documents/Inbox`).
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        receive(URLContexts.map { $0.url })
    }

    /// Accoglie le letture arrivate. Se l'utente è sulla Home, propone subito la prima (le altre restano nella riga della
    /// Home). Se è aperto qualcosa — un libro in lettura, un'elaborazione in corso, la schermata della prima apertura,
    /// un'altra scheda — NON si chiude nulla: un'elaborazione interrotta andrebbe persa e un libro aperto non si strappa
    /// all'utente (revisione indipendente del giro, 2026-10-16). La lettura aspetta nella Home e l'app lo dice.
    private func receive(_ urls: [URL]) {
        let accepted = urls.filter(ReceivedReadings.isPackage).compactMap(ReceivedReadings.accept)
        NotificationCenter.default.post(name: ReceivedReadings.didChange, object: nil)
        guard let first = accepted.first else { return }
        guard let root = window?.rootViewController as? RootTabBarController, root.presentedViewController == nil else {
            UIAccessibility.post(notification: .announcement, argument: Self.arrivalWhileBusyAnnouncement)
            return
        }
        UIAccessibility.post(notification: .announcement, argument: "È arrivata una lettura preparata dal Mac.")
        let presenter = (root.selectedViewController as? UINavigationController)?.topViewController ?? root
        ReadingFromMac.start(fileURL: first, from: presenter) {
            NotificationCenter.default.post(name: ReceivedReadings.didChange, object: nil)
        }
    }

    static let arrivalWhileBusyAnnouncement =
        "È arrivata una lettura preparata dal Mac. Quello che stai facendo non si interrompe: la trovi nella Home, "
        + "fra le letture arrivate dal Mac."


    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }


}

