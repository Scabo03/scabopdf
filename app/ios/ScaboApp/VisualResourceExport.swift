//
//  VisualResourceExport.swift
//  ScaboApp
//
//  «ESTRAI COME IMMAGINE» (`LAYER2_PRODUCT_DECISIONS.md` § 7.9 e § 14.2, `docs/RISORSE_VISIVE.md`): il ritaglio della
//  SOLA regione della risorsa visiva (mai la pagina intera) dal PDF d'archivio, a 300 punti per pollice (lato lungo
//  al più 3.000 pixel), salvato come PNG in una cartella temporanea dell'app e offerto al foglio di condivisione di
//  sistema, che comprende «Salva su File», «Copia» e le app che descrivono immagini. La responsabilità dell'uso è
//  dell'utente (§ 14.3). È l'unica esportazione dell'app (§ 12.5): proporzionata, una risorsa alla volta.
//

import Foundation
import PDFKit
import ScaboCore
import ScaboPageStructure

/// Fuori dal main actor per costruzione: il ritaglio si prepara su una coda di fondo.
nonisolated enum VisualResourceExport {

    /// Cartella temporanea dei ritagli (si svuota a ogni nuovo ritaglio: un ritaglio alla volta).
    static var directory: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("RisorseVisive", isDirectory: true)
    }

    /// Il nome del file: tipo e pagina del file originale, mai testo del libro.
    static func fileName(for payload: VisualResourcePayload) -> String {
        "\(payload.kind.word) pagina \(payload.pageIndex + 1).png"
    }

    enum Failure: Error, Equatable {
        case missingSource
        case unreadablePage
        case notCroppable
        case writeFailed

        /// Spiegazione in prosa (§ 12.10), annunciata a VoiceOver.
        var prose: String {
            switch self {
            case .missingSource: return "Il file originale di questo libro non è più sul dispositivo: l'immagine non si può ritagliare."
            case .unreadablePage: return "La pagina della risorsa non si legge nel file originale: l'immagine non si può ritagliare."
            case .notCroppable: return "La regione di questa risorsa copre quasi tutta la pagina: l'app ritaglia solo le risorse, mai pagine intere."
            case .writeFailed: return "Non è stato possibile preparare l'immagine sul dispositivo. Riprova fra poco."
            }
        }
    }

    /// Prepara il PNG del ritaglio (fuori dal thread principale). Ritorna l'URL del file temporaneo.
    static func makePNG(sourcePDF url: URL, payload: VisualResourcePayload) -> Result<URL, Failure> {
        guard FileManager.default.fileExists(atPath: url.path) else { return .failure(.missingSource) }
        guard let doc = PDFDocument(url: url), let page = doc.page(at: payload.pageIndex) else { return .failure(.unreadablePage) }
        guard let png = RegionCropper.pngData(page: page, region: payload.bbox, dpi: 300, maxPixels: 3000) else { return .failure(.notCroppable) }
        let dir = directory
        try? FileManager.default.removeItem(at: dir)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let file = dir.appendingPathComponent(fileName(for: payload))
            try png.write(to: file, options: .atomic)
            return .success(file)
        } catch {
            return .failure(.writeFailed)
        }
    }

    /// Toglie i ritagli temporanei (dopo la condivisione).
    static func cleanUp() {
        try? FileManager.default.removeItem(at: directory)
    }
}
