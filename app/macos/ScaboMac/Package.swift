// swift-tools-version: 5.9
//
// ScaboMac — lo scheletro dell'app macOS di ScaboPDF (l'«officina»), primo pezzo del prodotto Mac.
//
// È un PACCHETTO FRATELLO dell'app iOS, non un bersaglio dentro `ScaboPDF.xcodeproj`: così il progetto
// iOS non cambia di una riga (criterio del giro «linea Mac», 2026-10-05/06). Dipende da `ScaboCore` per
// percorso, come già fa il runner dell'officina fuori repo, e ne riusa ciò che ha senso (le preferenze
// `KeyValueStore`). Tutto ciò che è Mac-specifico (SwiftUI, AppKit, l'annunciatore VoiceOver, le verifiche
// sugli strumenti di sistema Apple) vive qui.
//
// Struttura:
//   ScaboMacKit  — libreria testabile: catalogo dei modelli (dato versionato + validazione), servizio dei
//                  modelli, annunciatore, stringhe italiane in un posto solo, viste SwiftUI; dal giro
//                  «costruzione della linea Mac» (2026-10-16) anche la CATENA del Mac (la stessa dell'iPad,
//                  ScaboChain, più l'innesto dei verdetti del modello d'impaginazione col fusore di ScaboCore).
//   ScaboMac     — l'eseguibile dell'app (punto d'ingresso, scene, menu).
//   scabomac-officina — riga di comando per le reti e il banco sul Mac (catena sui volumi, casi del gate del
//                  fusore): non entra nell'app, scrive solo nel laboratorio fuori repo.
//   ScaboMacKitTests — test unitari (catalogo, stati, annunci, anti-gergo, verifiche reali economiche, catena).
//
// Il bundle `.app` con sandbox ed entitlement lo assembla `scripts/build_app.sh` (SwiftPM da solo non
// produce bundle firmati); vedi README.md.
import PackageDescription

let package = Package(
    name: "ScaboMac",
    defaultLocalization: "it",
    platforms: [
        // Sistema minimo: macOS 14 (Sonoma). Motivazione in README.md § «Sistema minimo».
        .macOS(.v14),
    ],
    products: [
        .library(name: "ScaboMacKit", targets: ["ScaboMacKit"]),
        .executable(name: "ScaboMac", targets: ["ScaboMac"]),
        .executable(name: "scabomac-officina", targets: ["scabomac-officina"]),
    ],
    dependencies: [
        .package(path: "../../ios/ScaboCore"),
        // La catena condivisa con l'iPad (estrazione con le cure, risorse visive, corpo): riusata, mai duplicata.
        .package(path: "../../ios/ScaboChain"),
        .package(path: "../../ios/ScaboPageStructure"),
    ],
    targets: [
        .target(
            name: "ScaboMacKit",
            dependencies: [
                .product(name: "ScaboCore", package: "ScaboCore"),
                .product(name: "ScaboChain", package: "ScaboChain"),
                .product(name: "ScaboPageStructure", package: "ScaboPageStructure"),
            ],
            resources: [.copy("Resources/catalogo.json")]
        ),
        .executableTarget(
            name: "ScaboMac",
            dependencies: ["ScaboMacKit"]
        ),
        .executableTarget(
            name: "scabomac-officina",
            dependencies: ["ScaboMacKit"]
        ),
        .testTarget(
            name: "ScaboMacKitTests",
            dependencies: ["ScaboMacKit"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
