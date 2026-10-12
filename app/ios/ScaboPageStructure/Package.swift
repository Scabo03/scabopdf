// swift-tools-version: 5.9
//
// ScaboPageStructure — il riconoscimento NATIVO dell'impaginazione delle pagine PDF, condiviso fra
// l'app per iPad/iPhone (ScaboApp) e la futura app Mac (ramo feat/mac-base).
//
// Che cosa fa: dato un `PDFPage`, rende la pagina, la passa al modello d'impaginazione di docling
// («Heron», RT-DETRv2, Apache-2.0) convertito in Core ML, e applica i porti Swift fedeli del
// post-processing (`LayoutPostprocessor`) e dell'ordine di lettura a regole (`ReadingOrderPredictor`)
// di docling. L'uscita è PRIVA DI TESTO: regioni con tipo, riquadro, confidenza e ordine.
// Contiene anche la sonda grafica della pagina (prefiltro economico: immagini e tracciati vettoriali
// del flusso di contenuto) e il ritaglio di una regione come immagine.
//
// Perché un pacchetto a sé, ACCANTO a ScaboCore e non dentro: ScaboCore resta solo Foundation
// (+ CryptoKit per le impronte) e si prova sull'host senza simulatore; questo modulo importa Core ML,
// PDFKit e CoreGraphics. ScaboCore NON lo importa: i verdetti arrivano a ScaboCore come dati semplici
// (`VisualRegionCandidate`), convertiti dall'app.
//
// Piattaforme: il pavimento dichiarato è quello dell'app (iOS 15) per poterlo collegare senza alzare
// il minimo dell'app; il modello Core ML (mlprogram, bersaglio di conversione macOS 14) si carica solo
// da iOS 17 / macOS 14, perciò l'API che lo usa è marcata `@available(iOS 17, macOS 14, *)` e l'app
// degrada senza risorse visive sui sistemi più vecchi.
//
// Licenze: il modello è un'opera derivata di `docling-project/docling-layout-heron` (Apache-2.0); i
// porti Swift derivano da docling e docling-ibm-models (MIT). Testi e attribuzioni in `LICENSES/` e
// in `NOTICE.md`.
import PackageDescription

let package = Package(
    name: "ScaboPageStructure",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
    ],
    products: [
        .library(name: "ScaboPageStructure", targets: ["ScaboPageStructure"]),
        .executable(name: "scabo-page-structure", targets: ["scabo-page-structure"]),
    ],
    targets: [
        .target(
            name: "ScaboPageStructure",
            resources: [
                // Il modello compilato (fp32) e, accanto, licenze e attribuzioni: viaggiano nell'app con il modello.
                .copy("Resources/HeronLayout.mlmodelc"),
                .copy("Resources/LICENSE-Apache-2.0.txt"),
                .copy("Resources/LICENSE-docling-MIT.txt"),
                .copy("Resources/NOTICE-HeronLayout.md"),
            ]),
        .executableTarget(name: "scabo-page-structure", dependencies: ["ScaboPageStructure"]),
        .testTarget(name: "ScaboPageStructureTests", dependencies: ["ScaboPageStructure"]),
    ]
)
