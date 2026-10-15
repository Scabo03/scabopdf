// swift-tools-version: 5.9
//
// ScaboChain — la CATENA DI ELABORAZIONE di un PDF, condivisa fra l'app per iPad/iPhone (ScaboApp) e l'app Mac
// (app/macos/ScaboMac). Nasce nel giro «costruzione della linea Mac» (2026-10-16) spostando qui, senza cambiarne la
// logica, i pezzi che vivevano nel bersaglio dell'app iOS e che il Mac deve RIUSARE, mai duplicare:
//
//   * l'estrazione PDFKit con le sue cure (`PdfKitExtractor`, `PdfContentGlyphRuns`: confini di parola persi da
//     PDFKit 27, segnaposto U+FFFC, righe fuse di banda — le ultime due pure, in ScaboCore);
//   * il riconoscimento delle risorse visive (`VisualRegionDetector`: sonda, prefiltro, modello Heron di
//     ScaboPageStructure sulle sole pagine scelte);
//   * il corpo della Lettura Continua (`ContinuousBodyBuilder`);
//   * l'orchestrazione estrazione → risorse visive → classificazione → aggancio delle note → corpo
//     (`ProcessingChain`), di cui `DocumentProcessor` dell'app è ora solo l'involucro (coda, avanzamento sul main).
//
// Perché un pacchetto a sé e non dentro ScaboCore: ScaboCore resta SOLO Foundation (più CryptoKit per le impronte) e
// si prova sull'host senza simulatore; qui si importano PDFKit e CoreGraphics. Perché non dentro ScaboPageStructure:
// quel modulo non conosce ScaboCore (i verdetti escono come dati semplici), e la catena ne ha bisogno.
//
// Piattaforme: quelle dell'app (iOS 15) e del Mac (macOS 14, il minimo dello scheletro ScaboMac). L'estrattore usa
// UIFont/UIColor su iOS e NSFont/NSColor su macOS (stessa lettura dei tratti e dei colori: provato dalla rete di
// parità del primo giro Mac e da quella di questo giro).
import PackageDescription

let package = Package(
    name: "ScaboChain",
    platforms: [
        .iOS(.v15),
        .macOS(.v14),
    ],
    products: [
        .library(name: "ScaboChain", targets: ["ScaboChain"]),
    ],
    dependencies: [
        .package(path: "../ScaboCore"),
        .package(path: "../ScaboPageStructure"),
    ],
    targets: [
        .target(
            name: "ScaboChain",
            dependencies: [
                .product(name: "ScaboCore", package: "ScaboCore"),
                .product(name: "ScaboPageStructure", package: "ScaboPageStructure"),
            ]),
        .testTarget(name: "ScaboChainTests", dependencies: ["ScaboChain"]),
    ]
)
