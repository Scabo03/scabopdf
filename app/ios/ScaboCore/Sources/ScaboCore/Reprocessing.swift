//
//  Reprocessing.swift
//  ScaboCore
//
//  L'OFFERTA DI RIELABORAZIONE (LAYER2_PRODUCT_DECISIONS § 12.13 / § 12.14, docs/ANCORE_ANNOTAZIONI.md
//  § 5): quali libri la ricevono, e lo stato che si mette da parte per poter tornare indietro. Pura e
//  testabile: le costanti di prodotto (generazioni validate, build dell'ultima cura) le passa l'app.
//
//  Regola. Si offre, non si impone. Un libro PDF riceve l'offerta se:
//  - la generazione corrente del lettore di sistema è VALIDATA dalla build in uso (doppia rete): dopo un
//    aggiornamento maggiore non ancora giudicato, nessuna offerta, mai;
//  - ed è stato elaborato con una catena precedente all'ultima cura dichiarata «da offrire» (etichetta
//    `processedAppBuild` assente o minore), oppure con un'altra generazione maggiore del sistema.
//  I libri AKN/EPUB non dipendono dal lettore PDF e non la ricevono.
//

import Foundation

public enum ReprocessingReason: String, Codable, Sendable {
    /// Elaborato prima dell'ultima cura dell'estrazione o della classificazione.
    case cure
    /// Elaborato con un'altra versione maggiore del sistema (ora validata).
    case systemUpdate
}

public struct ReprocessingPolicy: Sendable {
    /// Versioni maggiori del sistema che la build in uso ha validato con la doppia rete.
    public let validatedSystemMajors: Set<Int>
    /// L'ultima build dell'app che ha portato una cura da offrire ai libri già elaborati.
    public let latestCureBuild: Int

    public init(validatedSystemMajors: Set<Int>, latestCureBuild: Int) {
        self.validatedSystemMajors = validatedSystemMajors
        self.latestCureBuild = latestCureBuild
    }

    /// Il numero maggiore da una stringa come «iPadOS 27.0.1» / «iOS 26.5».
    public static func major(of systemVersion: String?) -> Int? {
        guard let v = systemVersion?.split(separator: " ").last,
              let m = v.split(separator: ".").first else { return nil }
        return Int(m)
    }

    /// Vero se la generazione corrente è validata (senza, nessuna offerta).
    public func currentGenerationIsValidated(currentSystemVersion: String) -> Bool {
        guard let m = Self.major(of: currentSystemVersion) else { return false }
        return validatedSystemMajors.contains(m)
    }

    /// Perché il documento riceve l'offerta, o `nil` se non la riceve.
    public func reason(for doc: ArchivedDocument, currentSystemVersion: String) -> ReprocessingReason? {
        guard (doc.sourceKind ?? "pdf") == "pdf" else { return nil }
        guard currentGenerationIsValidated(currentSystemVersion: currentSystemVersion) else { return nil }
        let build = doc.processedAppBuild.flatMap { Int($0) }
        if build == nil || build! < latestCureBuild { return .cure }
        if let was = Self.major(of: doc.processedSystemVersion), let now = Self.major(of: currentSystemVersion), was != now {
            return .systemUpdate
        }
        return nil
    }

    public func eligibleDocuments(_ docs: [ArchivedDocument], currentSystemVersion: String) -> [ArchivedDocument] {
        docs.filter { reason(for: $0, currentSystemVersion: currentSystemVersion) != nil }
    }
}

/// Lo stato del documento che si mette da parte PRIMA di una rielaborazione, per poter tornare
/// indietro esattamente com'era (annotazioni, posizione, etichetta di generazione). Si salva accanto
/// alla copia precedente della cache e si cancella solo quando l'utente conferma la nuova lettura.
public struct ReadingSnapshot: Codable, Equatable, Sendable {
    public var bookmarks: [Bookmark]
    public var underlines: [Underline]
    public var readingPosition: Int
    public var readingAnchor: ContentAnchor?
    public var readingPositionIsApproximate: Bool?
    public var processedSystemVersion: String?
    public var processedAppBuild: String?
    public var processedAt: Date?
    public var takenAt: Date

    public init(document d: ArchivedDocument, takenAt: Date) {
        bookmarks = d.bookmarks ?? []
        underlines = d.underlines ?? []
        readingPosition = d.readingPosition
        readingAnchor = d.readingAnchor
        readingPositionIsApproximate = d.readingPositionIsApproximate
        processedSystemVersion = d.processedSystemVersion
        processedAppBuild = d.processedAppBuild
        processedAt = d.processedAt
        self.takenAt = takenAt
    }
}

extension LibraryStore {
    /// Fotografia dello stato da mettere da parte prima della rielaborazione.
    public func readingSnapshot(documentId: String, takenAt: Date = Date()) -> ReadingSnapshot? {
        document(id: documentId).map { ReadingSnapshot(document: $0, takenAt: takenAt) }
    }

    /// Ripristina esattamente lo stato fotografato (torna alla lettura precedente).
    public func restore(_ snapshot: ReadingSnapshot, documentId: String) {
        applyAnnotationState(
            documentId: documentId, bookmarks: snapshot.bookmarks, underlines: snapshot.underlines,
            readingPosition: snapshot.readingPosition, readingAnchor: snapshot.readingAnchor,
            readingPositionIsApproximate: snapshot.readingPositionIsApproximate)
        restoreProcessedLabel(id: documentId, systemVersion: snapshot.processedSystemVersion,
                              appBuild: snapshot.processedAppBuild, at: snapshot.processedAt)
    }
}
