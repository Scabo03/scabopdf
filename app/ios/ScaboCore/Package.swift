// swift-tools-version: 5.9
//
// ScaboCore — platform-agnostic Layer 2 logic for ScaboPDF.
//
// This package holds the deterministic, UI-free logic translated from the
// TypeScript app during the React Native → Swift migration (Piano di
// migrazione, banda OGGI, Fase 1). It is deliberately a separate, reusable
// SwiftPM library rather than code inside the app target so that:
//
//   * the same logic serves a future MuPDF-based extractor and a possible
//     macOS build (the extraction/classification seam is documented in
//     `PdfExtraction.swift`, Piano § 10);
//   * it imports ONLY Foundation — no PDFKit, no UIKit, no SwiftUI — so it
//     builds and tests on the macOS host via `swift test` with no Simulator
//     and no accessibility daemon (the sandbox can run it today, exactly like
//     the existing non-UI `ScaboPDFExtractionTests` unit layer).
//
// Deployment floor matches the app's target (iOS 15.0, the real minimum: the
// app and reading view use only APIs available at iOS 15, and ScaboCore is pure
// Foundation). No iOS 17 constructs are used here (Fase 1 is pure logic). macOS
// is declared so the test suite runs on the host.
import PackageDescription

let package = Package(
    name: "ScaboCore",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
    ],
    products: [
        .library(name: "ScaboCore", targets: ["ScaboCore"]),
    ],
    targets: [
        .target(name: "ScaboCore"),
        .testTarget(name: "ScaboCoreTests", dependencies: ["ScaboCore"]),
    ]
)
