//
//  DuplicateImportWording.swift
//  ScaboChain
//
//  Le PAROLE della schermata «Libro già presente» (LAYER2 § 12.8, giro «identità» del 2026-10-11): la spiegazione in prosa
//  piana, il titolo, l'intestazione e le tre scelte. Fino al 2026-11-08 stavano in ScaboApp `DuplicateImport.swift`, insieme
//  alla schermata UIKit; spostate qui, identiche, perché l'app Mac (ScaboPDF per Mac, giro «app unica per Mac, tappa A»)
//  dica le stesse cose dell'iPad. Solo Foundation e ScaboCore.
//

import Foundation
import ScaboCore

public enum DuplicateImport {

    /// La spiegazione in parole semplici: quale libro è, quando è stato importato, cosa ha dentro, e le
    /// due vie. `copies` = quante copie dello stesso file ci sono già (la prima è `existing`).
    public static func explanation(existing: ArchivedDocument, copies: Int) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.dateStyle = .long
        f.timeStyle = .none
        var text = "Il file che hai scelto è identico a «\(existing.title)», che hai importato il \(f.string(from: existing.importedAt))."
        if copies > 1 {
            text += " Di questo libro hai già \(copies) copie in libreria: «\(existing.title)» è quella che hai usato più di recente."
        }
        let b = existing.bookmarks?.count ?? 0
        let u = existing.underlines?.count ?? 0
        var parts: [String] = []
        if b > 0 { parts.append(b == 1 ? "un segnalibro" : "\(b) segnalibri") }
        if u > 0 { parts.append(u == 1 ? "una sottolineatura" : "\(u) sottolineature") }
        text += parts.isEmpty
            ? " Quel libro non ha ancora segnalibri né sottolineature."
            : " In quel libro hai " + parts.joined(separator: " e ") + "."
        text += " Puoi aprire il libro che hai già, con le sue annotazioni e il punto in cui eri arrivato, "
            + "oppure importare il file come una copia a parte: la copia parte senza annotazioni."
        return text
    }

    /// Il titolo della schermata.
    public static let screenTitle = "Libro già presente"
    /// L'intestazione, la prima cosa che si ascolta.
    public static let heading = "Questo libro è già nella tua libreria"
    /// Le tre scelte, nell'ordine: la predefinita è aprire il libro che c'è già.
    public static let openExistingTitle = "Apri il libro che hai già"
    public static let importAsCopyTitle = "Importa come copia a parte"
    public static let cancelTitle = "Annulla"
}
