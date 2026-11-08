// swift-tools-version: 5.9
//
// ScaboMac — il pacchetto di ScaboPDF per Mac, l'APP UNICA del Mac (dal giro «app unica per Mac, tappa A», 2026-11-08,
// LAYER2 § 12.16 decisioni 8-10): l'app dell'iPad — Home, importazione, libreria, lettura — più la finestra dei modelli,
// dove vive l'officina (prima un'app a sé: «lo scheletro dell'app macOS di ScaboPDF», giro «linea Mac»).
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
//   ScaboMacLettura — ciò che l'app Mac ha in comune con l'iPad: la Home con la libreria, l'importazione, le
//                  impostazioni di lettura e la vista di lettura (AppKit, elementi d'accessibilità virtuali in un gruppo
//                  solo, parlato tutto da ScaboCore `ReadingSpeech`; DISEGNO_LETTURA_MAC). La logica condivisa con l'iPad
//                  sta in ScaboChain e ScaboCore, mai copiata qui. Non dipende da llama né dal catalogo.
//   ScaboMac     — l'eseguibile dell'app (punto d'ingresso AppKit, menu, finestre; l'officina in una finestra).
//   scabomac-officina — riga di comando per le reti e il banco sul Mac (catena sui volumi, casi del gate del
//                  fusore): non entra nell'app, scrive solo nel laboratorio fuori repo.
//   ScaboMacOCR  — il motore di GLM-OCR dentro l'app (llama.cpp, release ufficiale b11429 verificata: la prepara
//                  `scripts/prepara_llama.sh` in Vendor/, fuori dal repo) e la pagina di prova libera da diritti.
//   ScaricatoreProtocollo — il protocollo fra l'app e il servizio di scaricamento, e lo scaricatore in streaming.
//   ScaboMacScaricatore — il SERVIZIO DI SCARICAMENTO (bundle XPC dentro l'app, assemblato da build_app.sh): l'unico
//                  pezzo con il permesso di rete; scrive i pesi nel file che l'app gli passa ed esce quando ha finito.
//   ScaboMacKitTests — test unitari (catalogo, stati, annunci, anti-gergo, verifiche reali economiche, catena).
//   ScaboMacLetturaTests — test della lettura e della libreria del Mac (identità della vista col modulo, importazione,
//                  Home, menu) e la rete d'identità con la vista dell'iPad sui volumi del banco (a richiesta).
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
        .library(name: "ScaboMacLettura", targets: ["ScaboMacLettura"]),
        .executable(name: "ScaboMac", targets: ["ScaboMac"]),
        .executable(name: "scabomac-officina", targets: ["scabomac-officina"]),
        .executable(name: "ScaboMacScaricatore", targets: ["ScaboMacScaricatore"]),
    ],
    dependencies: [
        .package(path: "../../ios/ScaboCore"),
        // La catena condivisa con l'iPad (estrazione con le cure, risorse visive, corpo): riusata, mai duplicata.
        .package(path: "../../ios/ScaboChain"),
        .package(path: "../../ios/ScaboPageStructure"),
    ],
    targets: [
        // llama.cpp, release ufficiale b11429 (ggml-org), impronta verificata contro quella pubblicata da
        // `scripts/prepara_llama.sh`, che la mette in Vendor/ (non versionata).
        .binaryTarget(name: "llama", path: "Vendor/llama.xcframework"),
        .target(
            name: "ScaboMacOCR",
            dependencies: ["llama"],
            resources: [.copy("Resources/pagina_prova.png"), .copy("Resources/pagina_prova.txt")]
        ),
        .target(name: "ScaricatoreProtocollo"),
        .executableTarget(
            name: "ScaboMacScaricatore",
            dependencies: ["ScaricatoreProtocollo"]
        ),
        .target(
            name: "ScaboMacKit",
            dependencies: [
                .product(name: "ScaboCore", package: "ScaboCore"),
                .product(name: "ScaboChain", package: "ScaboChain"),
                .product(name: "ScaboPageStructure", package: "ScaboPageStructure"),
                "ScaboMacOCR",
                "ScaricatoreProtocollo",
            ],
            resources: [.copy("Resources/catalogo.json")]
        ),
        .target(
            name: "ScaboMacLettura",
            dependencies: [
                .product(name: "ScaboCore", package: "ScaboCore"),
                .product(name: "ScaboChain", package: "ScaboChain"),
            ]
        ),
        .executableTarget(
            name: "ScaboMac",
            dependencies: ["ScaboMacKit", "ScaboMacLettura"]
        ),
        .executableTarget(
            name: "scabomac-officina",
            dependencies: ["ScaboMacKit"]
        ),
        .testTarget(
            name: "ScaboMacLetturaTests",
            dependencies: [
                "ScaboMacLettura",
                .product(name: "ScaboCore", package: "ScaboCore"),
                .product(name: "ScaboChain", package: "ScaboChain"),
            ]
        ),
        .testTarget(
            name: "ScaboMacKitTests",
            dependencies: ["ScaboMacKit", "ScaricatoreProtocollo", "ScaboMacOCR"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
