//
//  EstrattoreScansioni.swift
//  ScaboMacKit — l'estrattore del Mac per i PDF con pagine scansionate (giro «modelli e scansioni», 2026-11-18). Avvolge
//  quello di PDFKit (ScaboChain `PdfKitExtractor`, lo stesso dell'iPad): le pagine con testo restano IDENTICHE; solo le pagine
//  senza testo si leggono col lettore scelto (`LetturaScansioni`). Un PDF misto si legge per intero.
//
//  Se GLM-OCR non c'è, non si carica o la memoria non basta, l'estrattore lo dice in prosa (l'errore arriva alla catena come
//  ogni errore d'estrazione) e lascia il motivo in `problema`, così l'importazione non si chiude e propone l'altro lettore.
//  Se GLM-OCR non riesce su una pagina sola, quella pagina tiene la lettura di Apple (contata nel rapporto).
//

import Darwin
import Foundation
import PDFKit
import ScaboChain
import ScaboCore
import ScaboMacOCR
import ScaboPageStructure

public final class EstrattoreScansioni: ProgressReportingPdfExtractor {

    /// Perché la lettura delle scansioni non è partita (il testo è quello che l'importazione mostra).
    public enum Problema: Error, LocalizedError, Equatable, Sendable {
        case memoriaInsufficiente(disponibileGB: Int)
        case modelloNonInstallato
        case modelloNonCaricato
        case pdfNonLeggibile

        public var errorDescription: String? {
            switch self {
            case .memoriaInsufficiente(let gb):
                return "Per leggere le scansioni con GLM lettura pagine servono circa \(EstrattoreScansioni.memoriaGlmGB) GB di memoria libera, "
                    + "e adesso il Mac ne ha circa \(gb). Puoi chiudere altre app e riprovare, oppure leggere le scansioni con la "
                    + "lettura del testo di Apple, che chiede molta meno memoria."
            case .modelloNonInstallato:
                return "GLM lettura pagine non è installato su questo Mac. Puoi scaricarlo dal pannello dei modelli, oppure leggere le "
                    + "scansioni con la lettura del testo di Apple."
            case .modelloNonCaricato:
                return "GLM lettura pagine non si è caricato, forse per la memoria o per un file del modello danneggiato. Puoi leggere le "
                    + "scansioni con la lettura del testo di Apple, oppure verificare il modello nel pannello dei modelli."
            case .pdfNonLeggibile:
                return "Le pagine scansionate di questo PDF non si riescono ad aprire per leggerle."
            }
        }

        /// Vero se l'altro lettore può risolvere (i problemi di GLM-OCR).
        public var propostaAltroLettore: Bool { self != .pdfNonLeggibile }
    }

    /// Ciò che la lettura ha fatto, senza testo (registro, riga della libreria, referto del banco).
    public struct Rapporto: Codable, Sendable, Equatable {
        public var lettore: LettoreScansioni
        public var via: ViaScansioni
        public var pagine: Int
        public var pagineLette: Int
        /// Pagine in cui GLM-OCR non è riuscito e resta la lettura di Apple.
        public var pagineSoloApple: Int
        public var secondi: Double
        public var secondiPrimaPagina: Double?
        public var guardia: [String: Int]
    }

    /// La memoria libera che serve a GLM-OCR (misurata al banco: circa 7,5 GB al massimo, referto del giro § 2).
    public static let memoriaGlmGB = 8

    public let lettore: LettoreScansioni
    public let via: ViaScansioni
    public private(set) var problema: Problema?
    public private(set) var rapporto: Rapporto?
    /// Solo banco: cartella del laboratorio dove scrivere le pagine lette (con il loro testo: mai nel repo).
    public var cartellaBanco: URL?
    /// Solo banco: cartella del laboratorio col testo di GLM-OCR già letto (si riusa se c'è, si scrive se manca).
    public var cacheGlm: URL?

    private let pesiGlm: (pesi: URL, proiettore: URL)?

    public init(lettore: LettoreScansioni, via: ViaScansioni? = nil, pesiGlm: (pesi: URL, proiettore: URL)? = nil) {
        self.lettore = lettore
        self.via = via ?? ViaScansioni.predefinita(per: lettore)
        self.pesiGlm = pesiGlm
    }

    /// Una pagina è «senza testo» se l'estrazione di PDFKit non vi trova nemmeno un carattere visibile.
    public static func senzaTesto(_ p: PdfPageExtraction) -> Bool {
        !p.lines.contains { l in l.spans.contains { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } }
    }

    /// La memoria che il Mac può dare adesso (libera, inattiva, eliminabile), in byte.
    public static func memoriaDisponibile() -> UInt64? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let r = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count) }
        }
        guard r == KERN_SUCCESS else { return nil }
        let pagine = UInt64(stats.free_count) + UInt64(stats.inactive_count) + UInt64(stats.purgeable_count) + UInt64(stats.speculative_count)
        return pagine * UInt64(vm_kernel_page_size)
    }

    /// Solo prove: la memoria disponibile simulata (byte).
    nonisolated(unsafe) public static var memoriaSimulata: UInt64?

    public func extract(fromUri uri: String, onPageExtracted: (Int, Int) -> Void, isCancelled: () -> Bool) throws -> PdfExtraction? {
        problema = nil
        rapporto = nil
        let t0 = Date()
        guard var ex = try PdfKitExtractor().extract(fromUri: uri, onPageExtracted: { _, _ in }, isCancelled: isCancelled) else {
            return nil
        }
        let vuote = ex.pages.filter(Self.senzaTesto).map { $0.pageIndex }
        let totale = ex.pageCount
        var fatte = totale - vuote.count
        onPageExtracted(fatte, totale)
        var conti: [String: Int] = [:]
        var soloApple = 0
        var primaPagina: Double?
        defer {
            rapporto = Rapporto(lettore: lettore, via: via, pagine: totale, pagineLette: vuote.count, pagineSoloApple: soloApple,
                                secondi: Date().timeIntervalSince(t0), secondiPrimaPagina: primaPagina, guardia: conti)
        }
        guard !vuote.isEmpty else { return ex }
        if lettore == .glm {
            guard let pesiGlm, FileManager.default.fileExists(atPath: pesiGlm.pesi.path),
                  FileManager.default.fileExists(atPath: pesiGlm.proiettore.path) else {
                problema = .modelloNonInstallato; throw Problema.modelloNonInstallato
            }
            if cacheGlm == nil, let libera = Self.memoriaSimulata ?? Self.memoriaDisponibile(),
               libera < UInt64(Self.memoriaGlmGB) << 30 {
                let p = Problema.memoriaInsufficiente(disponibileGB: Int(libera >> 30))
                problema = p; throw p
            }
        }
        let url = uri.hasPrefix("file:") ? (URL(string: uri) ?? URL(fileURLWithPath: uri)) : URL(fileURLWithPath: uri)
        guard let doc = PDFDocument(url: url) else { problema = .pdfNonLeggibile; throw Problema.pdfNonLeggibile }
        let heron: HeronLayoutModel? = via == .v1 ? nil : (try? HeronLayoutModel.bundled())
        var lette: [PaginaLetta] = []
        for indice in vuote {
            if isCancelled() { return nil }
            let tp = Date()
            var errore: Error?
            let letta: PaginaLetta? = autoreleasepool {
                do { return try leggi(doc: doc, indice: indice, heron: heron, isCancelled: isCancelled, soloApple: &soloApple) }
                catch { errore = error; return nil }
            }
            if let errore {
                if case GlmOcr.Problema.annullata = errore { return nil }
                if let p = errore as? Problema { problema = p }
                throw errore
            }
            if let letta {
                lette.append(letta)
                for (k, v) in letta.guardia ?? [:] { conti[k, default: 0] += v }
            }
            if primaPagina == nil { primaPagina = Date().timeIntervalSince(tp) }
            fatte += 1
            onPageExtracted(fatte, totale)
        }
        for (indice, pagina) in LetturaScansioni.pagineEstratte(lette) where indice < ex.pages.count {
            ex.pages[indice] = pagina
        }
        return ex
    }

    private func leggi(doc: PDFDocument, indice: Int, heron: HeronLayoutModel?, isCancelled: () -> Bool,
                       soloApple: inout Int) throws -> PaginaLetta? {
        guard let page = doc.page(at: indice), let img = LetturaScansioni.immagine(della: page) else { return nil }
        let box = page.bounds(for: .cropBox)
        let W = Double(box.width), H = Double(box.height)
        let ta = Date()
        let apple = try LetturaScansioni.righeApple(img, larghezza: W, altezza: H)
        let secondiApple = Date().timeIntervalSince(ta)
        let th = Date()
        var righe = apple
        if let heron, let regioni = try? LetturaScansioni.regioni(pagina: page, modello: heron) {
            righe = LetturaScansioni.ordina(apple, regioni: regioni)
        } else {
            righe = LetturaScansioni.ordinaDallAlto(apple)
        }
        let secondiImpaginazione = Date().timeIntervalSince(th)
        var letta = PaginaLetta(pagina: indice, larghezza: W, altezza: H, righe: righe, testoGlm: nil,
                                secondiApple: secondiApple, secondiGlm: 0, secondiImpaginazione: secondiImpaginazione, guardia: nil)
        if lettore == .glm, let pesiGlm {
            let fileGlm = cacheGlm?.appendingPathComponent("p\(indice).json")
            let salvata = fileGlm.flatMap { try? JSONDecoder().decode(PaginaLetta.self, from: Data(contentsOf: $0)) }
            var testo = salvata?.testoGlm
            letta.secondiGlm = salvata?.secondiGlm ?? 0
            if testo == nil {
                guard let png = LetturaScansioni.png(img) else { return letta }
                do {
                    let l = try GlmOcr.leggi(png: png, pesi: pesiGlm.pesi, proiettore: pesiGlm.proiettore, annullata: isCancelled)
                    testo = l.testo
                    letta.secondiGlm = l.secondiCaricamento + l.secondiLettura
                    if let fileGlm {
                        try? FileManager.default.createDirectory(at: fileGlm.deletingLastPathComponent(), withIntermediateDirectories: true)
                        var c = letta; c.testoGlm = l.testo
                        try? JSONEncoder().encode(c).write(to: fileGlm)
                    }
                } catch GlmOcr.Problema.annullata {
                    throw GlmOcr.Problema.annullata
                } catch GlmOcr.Problema.pesiNonCaricati, GlmOcr.Problema.proiettoreNonCaricato, GlmOcr.Problema.contestoNonCreato {
                    problema = .modelloNonCaricato
                    throw Problema.modelloNonCaricato
                } catch {
                    soloApple += 1   // questa pagina tiene la lettura di Apple
                }
            }
            if let testo {
                letta.testoGlm = testo
                let g = LetturaScansioni.guardia(righe: righe, testoGlm: testo)
                letta.righe = g.righe
                letta.guardia = g.conti
            }
        }
        if let dir = cartellaBanco {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try? JSONEncoder().encode(letta).write(to: dir.appendingPathComponent("p\(indice).json"))
        }
        return letta
    }
}
