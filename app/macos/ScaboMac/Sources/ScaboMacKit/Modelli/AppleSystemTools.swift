//
//  AppleSystemTools.swift
//  ScaboMacKit
//
//  Verifica REALE della disponibilità degli strumenti di sistema Apple che il catalogo elenca con motore
//  «strumento di sistema Apple». Non scarica nulla e non invia contenuti: interroga solo la disponibilità.
//
//  - Riconoscimento del testo e della struttura dei documenti (Vision): da macOS 26.
//  - Modello di linguaggio di sistema (Foundation Models, solo locale): da macOS 26, se Apple Intelligence
//    è attiva e la lingua è supportata. Non si usa mai la variante in cloud (`PrivateCloudComputeLanguageModel`):
//    non viene nominata né linkata.
//
//  L'identificazione avviene sull'`id` della voce di catalogo, che per questi strumenti è fisso.
//

import Foundation
#if canImport(Vision)
import Vision
#endif
#if canImport(FoundationModels)
import FoundationModels
#endif

public enum AppleSystemTools {

    /// Identificativi riservati alle voci di sistema del catalogo.
    public static let idVisionDocumenti = "apple-vision-documenti"
    public static let idVisionTesto = "apple-vision-testo"
    public static let idModelloSistema = "apple-modello-di-sistema"

    public static func isAvailable(_ entry: CatalogEntry) -> Bool {
        switch entry.id {
        case idVisionDocumenti: return visionDocumentsAvailable()
        case idVisionTesto: return visionTextAvailable()
        case idModelloSistema: return systemLanguageModelAvailable()
        default: return false
        }
    }

    public static func visionDocumentsAvailable() -> Bool {
        #if canImport(Vision)
        if #available(macOS 26.0, *) {
            // La richiesta esiste e dichiara le lingue: basta per dire «disponibile».
            return !RecognizeDocumentsRequest().supportedRecognitionLanguages.isEmpty
        }
        #endif
        return false
    }

    public static func visionTextAvailable() -> Bool {
        #if canImport(Vision)
        if #available(macOS 15.0, *) {
            return !RecognizeTextRequest().supportedRecognitionLanguages.isEmpty
        }
        #endif
        return false
    }

    public static func systemLanguageModelAvailable() -> Bool {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            return SystemLanguageModel.default.isAvailable
        }
        #endif
        return false
    }
}
