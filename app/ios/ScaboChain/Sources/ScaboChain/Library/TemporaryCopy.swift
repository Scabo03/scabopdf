//
//  TemporaryCopy.swift
//  ScaboChain
//
//  La copia temporanea del file scelto, prima dell'impronta e dell'elaborazione: la usavano l'iPad (ScaboApp
//  `ImportController`) e il Mac (ScaboMacLettura `ImportazioneMac`) scritta due volte; ora una volta sola (giro «app unica
//  per Mac, tappa A», 2026-11-08, rilievo della revisione). Solo Foundation.
//

import Foundation

extension LibraryService {
    /// Copia `source` in `scabo_import_<uuid>.<ext>` nella cartella temporanea; `nil` se non riesce. L'accesso al file
    /// concesso dal sistema si apre per la durata della copia (serve sul Mac, sotto sandbox, per un file scelto o trascinato;
    /// sull'iPad il file scelto è già una copia locale e l'apertura non cambia nulla).
    public static func copyIntoTemporary(_ source: URL, ext: String = "pdf") -> URL? {
        let access = source.startAccessingSecurityScopedResource()
        defer { if access { source.stopAccessingSecurityScopedResource() } }
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("scabo_import_\(UUID().uuidString).\(ext)")
        do {
            try FileManager.default.copyItem(at: source, to: destination)
            return destination
        } catch {
            return nil
        }
    }
}
