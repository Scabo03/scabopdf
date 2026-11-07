//
//  DescrizioneLettura.swift
//  ScaboMacKit
//
//  La DESCRIZIONE della lettura con la fonte unica del parlato (ScaboCore `ReadingSpeech`), condivisa con l'iPad (giro
//  «fondamenta della lettura per Mac», 2026-11-07). Il Mac non ha ancora una vista di lettura: oggi la sua parte nel
//  confronto automatico con l'iPad è la sua catena (con l'innesto spento) passata nel modulo condiviso, cioè ciò che una
//  vista del Mac costruita sul modulo dirà per costruzione. Quando la vista di lettura del Mac esisterà, si descriverà
//  leggendo ciò che espone (XCTest con la modalità automazione), come la vista dell'iPad, e si confronterà con le stesse
//  descrizioni (`ReadingDescriptionComparison`).
//

import Foundation
import ScaboCore

public enum DescrizioneLettura {

    /// Un flusso descritto: il nome breve sul file (`lc.n0`, `lc.n1`, `di.n0`, `di.n1`) e la descrizione.
    public struct Flusso: Sendable {
        public let nome: String
        public let descrizione: ReadingDescription
    }

    /// Le descrizioni di una lettura nella forma della cache dell'iPad: la Lettura Continua (`lc`) e la Dottrina Inline
    /// (`di`) quando il libro la ha, ciascuna con «note annunciate a voce» spenta (`n0`) e accesa (`n1`). Le opzioni dei legami nota ↔
    /// richiamo vengono dall'impronta del libro (cure mirate, LAYER2 § 0-ter), come le imposta il lettore dell'iPad.
    /// Nessun segnalibro; VoiceOver acceso o spento come indicato (cambia solo «Strumenti elemento»).
    public static func flussi(
        lettura: PackagedReading, libro: String, impronta: String?, voiceOverAcceso: Bool = false
    ) -> [Flusso] {
        let opzioni = NoteJumpOptions.forTargeted(TargetedCures.rules(forFingerprint: impronta))
        var sorgenti: [(String, ReadingLayoutCode, [ContentSegment])] =
            [("lc", .continuousReading, lettura.content.pages.flatMap { $0.segments })]
        if let dottrina = lettura.doctrineContent {
            sorgenti.append(("di", .doctrineInline, dottrina.pages.flatMap { $0.segments }))
        }
        var out: [Flusso] = []
        for (breve, layout, segmenti) in sorgenti {
            let modello = ReadingSpeechModel(segments: segmenti, noteJumpOptions: opzioni)
            for voce in [false, true] {
                let impostazioni = ReadingSpeechSettings(noteSpokenLabels: voce, voiceOverRunning: voiceOverAcceso)
                out.append(Flusso(nome: "\(breve).n\(voce ? 1 : 0)",
                                  descrizione: modello.describe(book: libro, layout: layout, settings: impostazioni)))
            }
        }
        return out
    }

    /// Scrive ogni flusso in `<cartella>/<libro>.<nome>.jsonl` (il libro può avere una sottocartella, `originals/…`).
    /// Restituisce i file scritti, nell'ordine dei flussi.
    @discardableResult
    public static func scrivi(_ flussi: [Flusso], libro: String, in cartella: URL) throws -> [URL] {
        var scritti: [URL] = []
        for f in flussi {
            let file = cartella.appendingPathComponent("\(libro).\(f.nome).jsonl")
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try f.descrizione.encoded().write(to: file)
            scritti.append(file)
        }
        return scritti
    }
}
