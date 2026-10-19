//
//  ReadingPackage.swift
//  ScaboCore
//
//  IL PACCHETTO DELLA LETTURA (giro «costruzione della linea Mac», 2026-10-16; LAYER2_PRODUCT_DECISIONS § 12.12).
//  Ciò che il Mac produce per un libro viaggia verso l'iPad come UN SOLO FILE da aprire (AirDrop, «Apri con», File,
//  o cavo nella cartella dell'app vista dal Finder). Questo file ne fissa il formato, uguale sui due lati.
//
//  Che cosa contiene: la versione del formato e dell'app che l'ha prodotto, l'impronta del PDF d'origine (§ 12.8:
//  SHA-256 dei byte, uguale su ogni dispositivo per lo stesso file), la LETTURA elaborata nella stessa forma della cache
//  dell'app (flusso della Lettura Continua, flusso della Dottrina Inline, albero della Consultazione Rapida, mappa delle
//  pagine, granularità), e le ANNOTAZIONI solo se chi esporta ha spuntato la casella. Non contiene il PDF: il libro di
//  destinazione lo ha già, ed è proprio l'impronta a ritrovarlo.
//
//  Forma del file (versione 1):
//    8 byte   «SCABOPKG» (riconoscimento)
//    4 byte   lunghezza N dell'intestazione, intero senza segno big-endian
//    N byte   intestazione JSON (UTF-8): leggibile SENZA decomprimere il carico — l'iPad sa subito di che libro si tratta,
//             da quale app e versione arriva e se sa leggerlo, prima di toccare il carico (memoria dei dispositivi con 4 GB)
//    resto    il carico: JSON della lettura e delle eventuali annotazioni, compresso (LZFSE) e controllato con SHA-256
//
//  Versioni: `formatVersion` dice la forma del file; `reading.cacheFormat` la forma della lettura (il formato della cache
//  dell'app, oggi 6). Un pacchetto con un formato che l'app non conosce, o con una lettura di un formato che l'app non sa
//  aprire, si dichiara in prosa e non cambia nulla (§ 12.12, decisione 3). Il testo dei volumi sta solo nel carico, che
//  viaggia sul canale locale per decisione del maintainer; l'intestazione porta titolo e nome del file del libro, nessun
//  testo del volume.
//

import CryptoKit
import Foundation

public enum ReadingPackageFormat {
    /// Riconoscimento del file.
    public static let magic: [UInt8] = Array("SCABOPKG".utf8)
    /// La versione del formato scritta da questa app (e la più alta che sa leggere).
    public static let currentVersion = 1
    /// Estensione e tipo uniforme dichiarati da entrambe le app.
    public static let fileExtension = "scabolettura"
    public static let typeIdentifier = "com.scabo.scabopdf.lettura"
    /// Il «genere» dell'intestazione.
    public static let kind = "scabopdf-lettura"
    /// Tetto all'intestazione (byte): oltre, il file non è un pacchetto (protezione da file danneggiati).
    public static let maxHeaderLength = 1_000_000
}

/// L'intestazione del pacchetto: tutto ciò che serve a riconoscerlo e a decidere, senza il carico.
public struct ReadingPackageHeader: Codable, Equatable, Sendable {
    public struct Producer: Codable, Equatable, Sendable {
        /// «ScaboPDF per Mac».
        public var app: String
        /// Versione e build dell'app che ha prodotto il pacchetto.
        public var version: String
        public var build: String
        /// Sistema su cui girava («macOS 27.0.1»): è la generazione del lettore PDF di sistema che ha estratto il testo.
        public var system: String
        /// Il livello di cure della catena: l'ultima build dell'app per iPad le cui cure la catena del Mac contiene
        /// (stessa catena condivisa, ScaboChain). L'iPad lo registra come build d'elaborazione del libro, così
        /// l'offerta «Lettura migliore disponibile» non propone di rifare ciò che il Mac ha già fatto.
        public var cureLevel: Int

        public init(app: String, version: String, build: String, system: String, cureLevel: Int) {
            self.app = app; self.version = version; self.build = build; self.system = system; self.cureLevel = cureLevel
        }
    }

    public struct Source: Codable, Equatable, Sendable {
        /// SHA-256 esadecimale dei byte del PDF d'origine (§ 12.8).
        public var sha256: String
        /// Nome del file e titolo come li ha il Mac (servono alla prosa: «il libro … non è nella libreria»).
        public var fileName: String
        public var title: String
        public var pageCount: Int

        public init(sha256: String, fileName: String, title: String, pageCount: Int) {
            self.sha256 = sha256; self.fileName = fileName; self.title = title; self.pageCount = pageCount
        }
    }

    public struct Reading: Codable, Equatable, Sendable {
        /// Formato della lettura = formato della cache dell'app (oggi 6).
        public var cacheFormat: Int
        /// Granularità del flusso (400; 1.200 per i volumi enormi, come l'iPad).
        public var contentTarget: Int
        /// Conteggi per la prosa, privi di testo.
        public var segments: Int
        public var visualResources: Int
        public var hasDoctrine: Bool
        public var hasQuickConsult: Bool
        /// Che cosa l'officina ha fatto in più (righe brevi, prive di testo: note ricucite, voci d'indice…).
        public var workshop: [String]
        /// Gli stessi fatti in numeri, per la prosa dell'iPad (assenti = non detti): note spezzate fra due pagine e
        /// ricucite; righe dell'indice analitico che l'app leggeva come note e il Mac legge come testo dell'indice.
        public var stitchedNotes: Int?
        public var relabeledIndexLines: Int?
        /// Il riconoscimento di tabelle e figure sul Mac non è avvenuto (o non del tutto) per una ragione da riprovare
        /// (il modello non si è caricato): l'iPad che adotta la lettura segna il libro e propone di riprovare, invece di
        /// perdere in silenzio le tabelle e figure che aveva (revisione indipendente del giro). Assente = riconoscimento fatto.
        public var visualResourcesSkipped: String?

        public init(cacheFormat: Int, contentTarget: Int, segments: Int, visualResources: Int, hasDoctrine: Bool,
                    hasQuickConsult: Bool, workshop: [String], stitchedNotes: Int? = nil, relabeledIndexLines: Int? = nil,
                    visualResourcesSkipped: String? = nil) {
            self.cacheFormat = cacheFormat; self.contentTarget = contentTarget; self.segments = segments
            self.visualResources = visualResources; self.hasDoctrine = hasDoctrine; self.hasQuickConsult = hasQuickConsult
            self.workshop = workshop; self.stitchedNotes = stitchedNotes; self.relabeledIndexLines = relabeledIndexLines
            self.visualResourcesSkipped = visualResourcesSkipped
        }
    }

    public struct Annotations: Codable, Equatable, Sendable {
        public var bookmarks: Int
        public var underlines: Int
        public var hasPosition: Bool

        public init(bookmarks: Int, underlines: Int, hasPosition: Bool) {
            self.bookmarks = bookmarks; self.underlines = underlines; self.hasPosition = hasPosition
        }
    }

    public struct Payload: Codable, Equatable, Sendable {
        /// «lzfse» (unico valore scritto oggi).
        public var encoding: String
        /// Lunghezza del carico compresso e SHA-256 esadecimale dei suoi byte.
        public var length: Int
        public var sha256: String
    }

    public var kind: String
    public var formatVersion: Int
    public var producer: Producer
    public var createdAt: Date
    public var source: Source
    public var reading: Reading
    /// `nil` = annotazioni non incluse (casella non spuntata).
    public var annotations: Annotations?
    public var payload: Payload
}

/// La lettura: la stessa forma della cache dell'app (`LibraryService.CachedContent`).
public struct PackagedReading: Codable, Equatable, Sendable {
    public var content: PaginatedContent
    public var pageMap: [String: Int]
    public var doctrineContent: PaginatedContent?
    public var quickConsultTree: [QuickConsultNode]?
    public var contentTarget: Int

    public init(content: PaginatedContent, pageMap: [String: Int], doctrineContent: PaginatedContent?,
                quickConsultTree: [QuickConsultNode]?, contentTarget: Int) {
        self.content = content; self.pageMap = pageMap; self.doctrineContent = doctrineContent
        self.quickConsultTree = quickConsultTree; self.contentTarget = contentTarget
    }
}

/// Le annotazioni (solo con la casella spuntata): segnalibri, sottolineature, posizione, e i nomi dei tag usati (i tag
/// sono globali per dispositivo: viaggiano per nome e l'iPad li ritrova o li crea).
public struct PackagedAnnotations: Codable, Equatable, Sendable {
    public var bookmarks: [Bookmark]
    public var underlines: [Underline]
    public var tags: [Tag]
    public var readingAnchor: ContentAnchor?

    public init(bookmarks: [Bookmark], underlines: [Underline], tags: [Tag], readingAnchor: ContentAnchor?) {
        self.bookmarks = bookmarks; self.underlines = underlines; self.tags = tags; self.readingAnchor = readingAnchor
    }

    public var isEmpty: Bool { bookmarks.isEmpty && underlines.isEmpty && readingAnchor == nil }
}

struct ReadingPackageBody: Codable {
    var reading: PackagedReading
    var annotations: PackagedAnnotations?
}

/// I problemi di un file che non si può usare, ciascuno in prosa per l'utente (§ 12.10: mai il solo «errore»).
public enum ReadingPackageProblem: Error, Equatable, CustomStringConvertible {
    /// Il file non è un pacchetto di ScaboPDF (o non si legge).
    case notAPackage
    /// Il pacchetto è danneggiato (intestazione illeggibile, carico incompleto o non corrispondente all'impronta).
    case damaged
    /// Il pacchetto usa una forma del file più recente di quella che l'app conosce.
    case newerFormat(found: Int, producer: String)
    /// La lettura è in un formato che l'app non sa aprire.
    case unsupportedReading(found: Int, producer: String)
    /// Volume molto grande preparato a una granularità che l'app per quei volumi non usa (la scarterebbe all'apertura).
    case largeVolumeGranularity(found: Int, expected: Int, producer: String)

    public var description: String { prose }

    /// La spiegazione per l'utente, in prosa, con la via d'uscita.
    public var prose: String {
        switch self {
        case .notAPackage:
            return "Questo file non è una lettura preparata da ScaboPDF per Mac, oppure non si riesce a leggere. "
                + "Nella libreria non è stato cambiato nulla."
        case .damaged:
            return "Questo file di lettura è danneggiato: probabilmente il trasferimento non è andato a buon fine. "
                + "Nella libreria non è stato cambiato nulla. Prova a mandarlo di nuovo dal Mac."
        case .newerFormat(let found, let producer):
            return "Questa lettura arriva da \(producer) e usa una forma del file (versione \(found)) più recente di quella "
                + "che questa versione di ScaboPDF sa aprire. Nella libreria non è stato cambiato nulla. "
                + "Aggiorna ScaboPDF su questo dispositivo e riapri il file."
        case .unsupportedReading(let found, let producer):
            return "Questa lettura arriva da \(producer), che l'ha preparata in un formato (\(found)) diverso da quello che "
                + "questa versione di ScaboPDF sa aprire. Nella libreria non è stato cambiato nulla. "
                + "Aggiorna l'app che non è all'ultima versione, sul Mac o qui, poi prepara e manda di nuovo la lettura."
        case .largeVolumeGranularity(let found, let expected, let producer):
            return "Questa lettura arriva da \(producer) ed è di un volume molto grande, preparato a blocchi di \(found) "
                + "caratteri: per i volumi così grandi questo dispositivo usa blocchi di \(expected) e, aprendo il libro, la "
                + "sostituirebbe rielaborando il PDF. Nella libreria non è stato cambiato nulla. Prepara di nuovo la lettura "
                + "con la finestra di ScaboPDF per Mac, che usa la stessa regola di questo dispositivo."
        }
    }
}

public enum ReadingPackage {

    /// Scrive il pacchetto. `annotations == nil` (o vuote) → non incluse.
    public static func write(producer: ReadingPackageHeader.Producer, source: ReadingPackageHeader.Source,
                             reading: PackagedReading, cacheFormat: Int, workshop: [String],
                             stitchedNotes: Int? = nil, relabeledIndexLines: Int? = nil, visualResourcesSkipped: String? = nil,
                             annotations: PackagedAnnotations?, createdAt: Date = Date()) throws -> Data {
        let included = (annotations?.isEmpty == false) ? annotations : nil
        let body = ReadingPackageBody(reading: reading, annotations: included)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let raw = try encoder.encode(body)
        let compressed = try (raw as NSData).compressed(using: .lzfse) as Data
        let segments = reading.content.pages.reduce(0) { $0 + $1.segments.count }
        let visual = reading.content.pages.reduce(0) { $0 + $1.segments.filter { $0.visualResource != nil }.count }
        let header = ReadingPackageHeader(
            kind: ReadingPackageFormat.kind, formatVersion: ReadingPackageFormat.currentVersion,
            producer: producer, createdAt: createdAt, source: source,
            reading: .init(cacheFormat: cacheFormat, contentTarget: reading.contentTarget, segments: segments,
                           visualResources: visual, hasDoctrine: reading.doctrineContent != nil,
                           hasQuickConsult: reading.quickConsultTree != nil, workshop: workshop,
                           stitchedNotes: stitchedNotes, relabeledIndexLines: relabeledIndexLines,
                           visualResourcesSkipped: visualResourcesSkipped),
            annotations: included.map { .init(bookmarks: $0.bookmarks.count, underlines: $0.underlines.count,
                                              hasPosition: $0.readingAnchor != nil) },
            payload: .init(encoding: "lzfse", length: compressed.count, sha256: sha256Hex(compressed)))
        let headerEncoder = JSONEncoder()
        headerEncoder.dateEncodingStrategy = .iso8601
        headerEncoder.outputFormatting = [.sortedKeys]
        let headerData = try headerEncoder.encode(header)
        var out = Data(ReadingPackageFormat.magic)
        var n = UInt32(headerData.count).bigEndian
        withUnsafeBytes(of: &n) { out.append(contentsOf: $0) }
        out.append(headerData)
        out.append(compressed)
        return out
    }

    /// Legge la sola intestazione da un file (i primi byte; il carico non si tocca).
    public static func readHeader(at url: URL) throws -> (header: ReadingPackageHeader, payloadOffset: Int) {
        guard let handle = try? FileHandle(forReadingFrom: url) else { throw ReadingPackageProblem.notAPackage }
        defer { try? handle.close() }
        guard let first = try? handle.read(upToCount: 12), first.count == 12 else { throw ReadingPackageProblem.notAPackage }
        let n = try headerLength(first)
        guard let headerData = try? handle.read(upToCount: n), headerData.count == n else { throw ReadingPackageProblem.damaged }
        return (try decodeHeader(headerData), 12 + n)
    }

    /// Legge l'intestazione da dati già in memoria.
    public static func readHeader(_ data: Data) throws -> (header: ReadingPackageHeader, payloadOffset: Int) {
        guard data.count >= 12 else { throw ReadingPackageProblem.notAPackage }
        let n = try headerLength(data.prefix(12))
        guard data.count >= 12 + n else { throw ReadingPackageProblem.damaged }
        return (try decodeHeader(data.subdata(in: (data.startIndex + 12)..<(data.startIndex + 12 + n))), 12 + n)
    }

    private static func headerLength(_ first: Data) throws -> Int {
        let bytes = [UInt8](first)
        guard Array(bytes[0..<8]) == ReadingPackageFormat.magic else { throw ReadingPackageProblem.notAPackage }
        let n = Int(UInt32(bytes[8]) << 24 | UInt32(bytes[9]) << 16 | UInt32(bytes[10]) << 8 | UInt32(bytes[11]))
        guard n > 0, n <= ReadingPackageFormat.maxHeaderLength else { throw ReadingPackageProblem.damaged }
        return n
    }

    private static func decodeHeader(_ data: Data) throws -> ReadingPackageHeader {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        // Prima il genere e la versione, così una forma più recente si dice tale anche se i campi sono cambiati.
        struct Peek: Decodable { let kind: String?; let formatVersion: Int?; let producer: Peek2? }
        struct Peek2: Decodable { let app: String?; let version: String? }
        guard let peek = try? decoder.decode(Peek.self, from: data), peek.kind == ReadingPackageFormat.kind,
              let v = peek.formatVersion else { throw ReadingPackageProblem.notAPackage }
        if v > ReadingPackageFormat.currentVersion {
            throw ReadingPackageProblem.newerFormat(found: v, producer: producerName(peek.producer?.app, peek.producer?.version))
        }
        guard let header = try? decoder.decode(ReadingPackageHeader.self, from: data) else { throw ReadingPackageProblem.damaged }
        return header
    }

    /// «ScaboPDF per Mac (versione 0.2)»: l'app che ha prodotto il pacchetto, per la prosa.
    public static func producerName(_ app: String?, _ version: String?) -> String {
        let a = app ?? "un'altra versione di ScaboPDF"
        if let version, !version.isEmpty { return "\(a) (versione \(version))" }
        return a
    }

    /// Controlla che la lettura sia in un formato che l'app sa aprire (`readableCacheFormats`).
    public static func checkCompatibility(_ header: ReadingPackageHeader, readableCacheFormats: ClosedRange<Int>) throws {
        guard readableCacheFormats.contains(header.reading.cacheFormat) else {
            throw ReadingPackageProblem.unsupportedReading(
                found: header.reading.cacheFormat, producer: producerName(header.producer.app, header.producer.version))
        }
    }

    /// Legge e verifica il carico (impronta, decompressione, decodifica).
    public static func readBody(_ data: Data, header: ReadingPackageHeader, payloadOffset: Int)
        throws -> (reading: PackagedReading, annotations: PackagedAnnotations?) {
        guard header.payload.encoding == "lzfse", data.count == payloadOffset + header.payload.length else {
            throw ReadingPackageProblem.damaged
        }
        let compressed = data.subdata(in: (data.startIndex + payloadOffset)..<data.endIndex)
        guard sha256Hex(compressed) == header.payload.sha256,
              let raw = try? (compressed as NSData).decompressed(using: .lzfse) as Data else {
            throw ReadingPackageProblem.damaged
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let body = try? decoder.decode(ReadingPackageBody.self, from: raw) else { throw ReadingPackageProblem.damaged }
        return (body.reading, body.annotations)
    }

    /// Nome di file proposto: il titolo del libro, ripulito, con l'estensione del pacchetto.
    public static func suggestedFileName(title: String) -> String {
        let bad = CharacterSet(charactersIn: "/\\:?*\"<>|").union(.controlCharacters)
        let clean = title.components(separatedBy: bad).joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (clean.isEmpty ? "Lettura" : clean) + "." + ReadingPackageFormat.fileExtension
    }

    static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
