//
//  LibraryFormatting.swift
//  ScaboChain (fino al 2026-11-08 in ScaboApp; le stesse parole delle righe della libreria sull'iPad e sul Mac)
//
//  Le stringhe di sommario e le etichette di accessibilità delle liste della libreria, in un solo
//  posto: copy in italiano, plurali corretti, e una resa VoiceOver più esplicita del solo testo
//  visivo (§ 2.1, bi-modale). Niente UIKit oltre alle stringhe; nessuna decisione di layout qui.
//

import Foundation
import ScaboCore

public enum LibraryFormatting {

    /// "1 file" / "N file" (invariabile) — qui pluralizziamo solo i contenitori italiani.
    public static func count(_ n: Int, singular: String, plural: String) -> String {
        "\(n) \(n == 1 ? singular : plural)"
    }

    // MARK: - File

    /// Sommario visivo breve di un documento (riga secondaria).
    public static func fileDetail(_ doc: ArchivedDocument) -> String {
        var parts = [count(doc.sourcePageCount, singular: "pagina", plural: "pagine")]
        if doc.readingPosition > 0 { parts.append("in lettura") }
        return parts.joined(separator: " · ")
    }

    /// Etichetta VoiceOver ricca del documento.
    public static func fileAccessibility(_ doc: ArchivedDocument) -> String {
        var parts = ["\(doc.title), documento",
                     count(doc.sourcePageCount, singular: "pagina", plural: "pagine")]
        if doc.readingPosition > 0 { parts.append("ripresa dal punto di lettura") }
        if !doc.warnings.isEmpty {
            parts.append(count(doc.warnings.count, singular: "avviso di elaborazione",
                               plural: "avvisi di elaborazione"))
        }
        return parts.joined(separator: ", ")
    }

    public static let fileOpenHint = "Doppio tap per aprire il documento al punto di lettura"
    public static let fileOptionsHint = "Sposta, rinomina, elimina la collocazione, o apri il referto di elaborazione"

    // MARK: - Contenitori

    public static func workspaceDetail(_ ws: Workspace) -> String {
        let folders = ws.folders.count
        let files = ws.fileIds.count
        if folders == 0 && files == 0 { return "vuoto" }
        var parts: [String] = []
        if folders > 0 { parts.append(count(folders, singular: "cartella", plural: "cartelle")) }
        if files > 0 { parts.append(count(files, singular: "file", plural: "file")) }
        return parts.joined(separator: ", ")
    }

    public static func folderDetail(_ folder: Folder) -> String {
        let subs = folder.subfolders.count
        let files = folder.fileIds.count
        if subs == 0 && files == 0 { return "vuota" }
        var parts: [String] = []
        if subs > 0 { parts.append(count(subs, singular: "sottocartella", plural: "sottocartelle")) }
        if files > 0 { parts.append(count(files, singular: "file", plural: "file")) }
        return parts.joined(separator: ", ")
    }

    public static func subfolderDetail(_ sub: Subfolder) -> String {
        sub.fileIds.isEmpty ? "vuota" : count(sub.fileIds.count, singular: "file", plural: "file")
    }

    public static let workspaceOpenHint = "Doppio tap per aprire il workspace"
    public static let folderOpenHint = "Doppio tap per aprire la cartella"
    public static let subfolderOpenHint = "Doppio tap per aprire la sottocartella"
}
