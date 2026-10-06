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
//                  modelli (interfaccia + implementazione DICHIARATAMENTE simulata), annunciatore,
//                  stringhe italiane in un posto solo, viste SwiftUI.
//   ScaboMac     — l'eseguibile dell'app (punto d'ingresso, scene, menu).
//   ScaboMacKitTests — test unitari (catalogo, stati, annunci, anti-gergo, verifiche reali economiche).
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
    ],
    dependencies: [
        .package(path: "../../ios/ScaboCore"),
    ],
    targets: [
        .target(
            name: "ScaboMacKit",
            dependencies: [.product(name: "ScaboCore", package: "ScaboCore")],
            resources: [.copy("Resources/catalogo.json")]
        ),
        .executableTarget(
            name: "ScaboMac",
            dependencies: ["ScaboMacKit"]
        ),
        .testTarget(
            name: "ScaboMacKitTests",
            dependencies: ["ScaboMacKit"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
