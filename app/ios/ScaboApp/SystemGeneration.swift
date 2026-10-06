//
//  SystemGeneration.swift
//  ScaboApp
//
//  La GENERAZIONE del lettore PDF di sistema con cui l'app elabora i documenti (giro «generazioni
//  del lettore», 2026-10-06, docs/GENERAZIONI_LETTORE.md). PDFKit cambia fra versioni di sistema
//  (iOS 26.5 ≠ iOS 27 sul 7 % delle pagine del corpus) e la cache dell'app si invalida solo per
//  numero di formato: un aggiornamento di sistema non rielabora nulla, e la libreria mescola libri
//  letti con generazioni diverse. L'etichetta registrata su `ArchivedDocument` a ogni elaborazione
//  dice con quale. Solo Foundation: lo stesso valore vale per il runner e per il futuro Mac.
//

import Foundation
import ScaboCore
#if os(iOS)
import UIKit
#endif

enum SystemGeneration {
    /// «iOS 27.0.1» (o «iPadOS …»/«macOS …» secondo la piattaforma): nome del sistema e versione
    /// numerica completa. È la stringa che si annota sul documento e si mostra nel referto.
    static var current: String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        let number = v.patchVersion == 0 ? "\(v.majorVersion).\(v.minorVersion)"
            : "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
        return "\(platformName) \(number)"
    }

    private static var platformName: String {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad ? "iPadOS" : "iOS"
        #elseif os(macOS)
        return "macOS"
        #else
        return "sistema"
        #endif
    }

    /// Build dell'app in esecuzione (CFBundleVersion), o `nil` fuori da un bundle.
    static var appBuild: String? {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
    }

    /// Testo per il referto di elaborazione: la generazione (e la build dell'app) con cui il contenuto in
    /// cache è stato letto, o la dichiarazione che non è registrata (elaborato prima dell'etichetta).
    static func describe(_ document: ArchivedDocument) -> String {
        guard let version = document.processedSystemVersion else {
            return "non registrata (elaborato prima che l'app la annotasse; per registrarla, reimporta il file)"
        }
        var text = version
        if let build = document.processedAppBuild { text += ", app build \(build)" }
        if let at = document.processedAt {
            let f = DateFormatter()
            f.locale = Locale(identifier: "it_IT")
            f.dateStyle = .long
            f.timeStyle = .short
            text += ", il \(f.string(from: at))"
        }
        return text
    }
}
