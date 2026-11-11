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
//  Dalla cura 64 (giro «rifiniture e cure per capacità», 2026-11-07) l'offerta per una cura va a TUTTI E SOLI i libri la
//  cui lettura cambia, nei limiti di quel che si sa senza rielaborare: un libro misurato al banco, la cui lettura la cura
//  lascia identica al byte sulla generazione corrente (`unchangedByCure`), non la riceve; un libro sconosciuto sì.
//  I testi normativi (AKN) non dipendono dal lettore PDF: ricevono l'offerta solo per una cura della LORO catena
//  (`latestCureBuildForAknActs`, giro «pulizia e rifinitura finale del capitolo note», 2026-10-17, decisione 1 del
//  maintainer: i pezzi nuovi delle note), mai per un aggiornamento del sistema; dalla cura 66 (giro «prova 4, segnalibri e
//  sigle», 2026-11-11) con la stessa regola «tutti e soli»: un atto misurato che la cura lascia identico non la riceve
//  (`unchangedAknActsByCure`, senza generazione). I libri EPUB non la ricevono.
//

import Foundation

/// L'origine di una lettura in cache (`ArchivedDocument.readingOrigin`).
public enum ReadingOrigin {
    /// Arrivata pronta dal Mac in un pacchetto (§ 12.12).
    public static let mac = "mac"
}

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
    /// L'ultima cura che una lettura ARRIVATA DAL MAC può non avere (giro del 2026-10-16): il Mac fraziona le note lunghe
    /// da sempre, quindi la cura 55 (il frazionamento sull'iPad) non manca a nessuna delle sue letture. Uguale a
    /// `latestCureBuild` se non indicata.
    public let latestCureBuildForMacReadings: Int
    /// L'ultima cura da offrire ai TESTI NORMATIVI (AKN) già importati: la più recente fra le cure che cambiano anche la
    /// loro lettura (i pezzi delle note lunghe, build 56). `nil`: nessuna offerta ai testi normativi (fino alla build 56).
    public let latestCureBuildForAknActs: Int?
    /// Le CURE MIRATE (LAYER2 § 0-ter, `TargetedCures`): impronta del file → build della cura. Un libro PDF con una di
    /// queste impronte (`sourceSha256`), elaborato sull'iPad prima di quella build e non da questa stessa build, riceve
    /// l'offerta; nessun altro libro la riceve per una cura mirata. Le letture arrivate dal Mac non la ricevono: come per le
    /// cure 56-58, la cura arriva dal Mac con una lettura nuova (rielaborare sull'iPad toglierebbe l'innesto del Mac).
    public let targetedCureBuilds: [String: Int]
    /// La build della cura delle risorse visive (tabelle e figure): un libro il cui riconoscimento è saltato per una
    /// ragione da riprovare (`visualResourcesSkipped`) riceve l'offerta dove il dispositivo sa riconoscere (cura ≥ 53).
    public static let visualResourcesCureBuild = 53
    /// Le build delle cure della catena (quelle della lista «cosa cambia» dell'app), in ordine.
    public let cureBuilds: [Int]
    /// I libri che una cura NON cambia, MISURATI (giro «rifiniture e cure per capacità», 2026-11-07: l'offerta va a tutti
    /// e soli i libri la cui lettura cambia): cura → versione maggiore del sistema → impronte dei PDF la cui lettura resta
    /// identica al byte con la cura, su quella generazione. Un libro che manca solo di cure che lo lasciano com'è non
    /// riceve l'offerta per la cura; un libro sconosciuto (impronta non misurata) la riceve, perché la sua lettura può
    /// cambiare e senza rielaborarlo non si sa.
    public let unchangedByCure: [Int: [Int: Set<String>]]
    /// Le build delle cure dei TESTI NORMATIVI (quelle che cambiano anche la loro lettura), in ordine.
    public let aknCureBuilds: [Int]
    /// Gli atti normativi che una cura NON cambia, misurati (cura 66 in poi): cura → impronte dei file XML la cui lettura resta
    /// identica al byte con la cura. La lettura di un atto non dipende dal lettore di sistema: nessuna generazione.
    public let unchangedAknActsByCure: [Int: Set<String>]

    public init(validatedSystemMajors: Set<Int>, latestCureBuild: Int, latestCureBuildForMacReadings: Int? = nil,
                latestCureBuildForAknActs: Int? = nil, targetedCureBuilds: [String: Int] = [:],
                cureBuilds: [Int] = [], unchangedByCure: [Int: [Int: Set<String>]] = [:],
                aknCureBuilds: [Int] = [], unchangedAknActsByCure: [Int: Set<String>] = [:]) {
        self.validatedSystemMajors = validatedSystemMajors
        self.latestCureBuild = latestCureBuild
        self.latestCureBuildForMacReadings = latestCureBuildForMacReadings ?? latestCureBuild
        self.latestCureBuildForAknActs = latestCureBuildForAknActs
        self.targetedCureBuilds = targetedCureBuilds
        self.cureBuilds = cureBuilds
        self.unchangedByCure = unchangedByCure
        self.aknCureBuilds = aknCureBuilds
        self.unchangedAknActsByCure = unchangedAknActsByCure
    }

    /// Vero se la cura `cure` è stata misurata come cura che lascia identica la lettura di questo testo normativo.
    public func aknCureLeavesUnchanged(_ cure: Int, _ doc: ArchivedDocument) -> Bool {
        guard let sha = doc.sourceSha256 else { return false }
        return unchangedAknActsByCure[cure]?.contains(sha) ?? false
    }

    /// Vero se TUTTE le cure dei testi normativi mancanti all'atto (dopo la build che l'ha elaborato, fino all'ultima) lo
    /// lasciano com'è, misurato. Falso se manca anche una sola cura non misurata per lui, o se l'elenco delle cure non c'è.
    public func pendingAknCuresLeaveUnchanged(_ doc: ArchivedDocument, since: Int?) -> Bool {
        guard let latest = latestCureBuildForAknActs else { return false }
        let pending = aknCureBuilds.filter { $0 > (since ?? 0) && $0 <= latest }
        guard !pending.isEmpty else { return false }
        return pending.allSatisfy { aknCureLeavesUnchanged($0, doc) }
    }

    /// Vero se la cura `cure` è stata misurata come cura che lascia identica la lettura di questo libro sulla generazione
    /// corrente (la sua impronta è nell'elenco della cura per quella versione maggiore del sistema).
    public func cureLeavesUnchanged(_ cure: Int, _ doc: ArchivedDocument, currentSystemVersion: String) -> Bool {
        guard let sha = doc.sourceSha256, let major = Self.major(of: currentSystemVersion) else { return false }
        return unchangedByCure[cure]?[major]?.contains(sha) ?? false
    }

    /// Vero se TUTTE le cure che il libro non ha (dopo la build che l'ha elaborato, fino all'ultima) lo lasciano com'è,
    /// misurato: allora l'offerta per la cura non serve. Falso se manca anche una sola cura non misurata per lui.
    public func pendingCuresLeaveUnchanged(_ doc: ArchivedDocument, since: Int?, currentSystemVersion: String) -> Bool {
        let pending = cureBuilds.filter { $0 > (since ?? 0) && $0 <= latestCureBuild }
        guard !pending.isEmpty else { return false }
        return pending.allSatisfy { cureLeavesUnchanged($0, doc, currentSystemVersion: currentSystemVersion) }
    }

    /// La build della cura mirata da offrire a questo documento, se la sua impronta è nel registro e il libro è stato
    /// elaborato prima (e non da questa stessa build). `nil` per ogni altro libro.
    public func pendingTargetedCureBuild(for doc: ArchivedDocument, currentAppBuild: String? = nil) -> Int? {
        guard (doc.sourceKind ?? "pdf") == "pdf", doc.readingOrigin != ReadingOrigin.mac,
              let sha = doc.sourceSha256, let cureBuild = targetedCureBuilds[sha] else { return nil }
        let build = doc.processedAppBuild.flatMap { Int($0) }
        let sameBuild = currentAppBuild != nil && doc.processedAppBuild == currentAppBuild
        return !sameBuild && (build ?? 0) < cureBuild ? cureBuild : nil
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

    /// Perché il documento riceve l'offerta, o `nil` se non la riceve. Un documento elaborato dalla
    /// STESSA build in uso (`currentAppBuild`) ha già tutte le sue cure: niente offerta per la cura.
    public func reason(for doc: ArchivedDocument, currentSystemVersion: String, currentAppBuild: String? = nil) -> ReprocessingReason? {
        // Un testo normativo: nessun lettore di sistema in gioco (né generazioni da validare, né aggiornamenti), solo le
        // cure della sua catena che non aveva quando è stato elaborato.
        if doc.sourceKind == "akn" {
            guard let latest = latestCureBuildForAknActs else { return nil }
            let build = doc.processedAppBuild.flatMap { Int($0) }
            let sameBuild = currentAppBuild != nil && doc.processedAppBuild == currentAppBuild
            guard !sameBuild, (build ?? 0) < latest else { return nil }
            // Tutti e soli (cura 66 in poi): le cure che gli mancano lo lasciano com'è, misurato? Allora niente offerta.
            return pendingAknCuresLeaveUnchanged(doc, since: build) ? nil : .cure
        }
        guard (doc.sourceKind ?? "pdf") == "pdf" else { return nil }
        guard currentGenerationIsValidated(currentSystemVersion: currentSystemVersion) else { return nil }
        let build = doc.processedAppBuild.flatMap { Int($0) }
        // Riconoscimento di tabelle e figure saltato all'ultima elaborazione (memoria, modello): si propone di riprovare,
        // anche se il libro è stato elaborato da questa stessa build (giro del 2026-10-16, protezione della memoria).
        // Ma se un nuovo tentativo con QUESTA versione dell'app è già fallito, si tace fino alla prossima versione.
        if doc.visualResourcesSkipped != nil, latestCureBuild >= Self.visualResourcesCureBuild,
           currentAppBuild == nil || doc.visualResourcesRetriedBuild != currentAppBuild {
            return .cure
        }
        // Lettura arrivata dal Mac (giro del 2026-10-16): il suo lettore di sistema è quello del Mac, non conta
        // l'aggiornamento dell'iPad; la sua build è il livello di cure della catena del Mac: si offre solo una cura
        // che quella catena non conteneva (non il frazionamento delle note lunghe, che il Mac ha sempre fatto).
        if doc.readingOrigin == ReadingOrigin.mac {
            return (build ?? 0) < latestCureBuildForMacReadings ? .cure : nil
        }
        let sameBuild = currentAppBuild != nil && doc.processedAppBuild == currentAppBuild
        // Cura mirata (LAYER2 § 0-ter): solo il libro la cui impronta è nel registro.
        if pendingTargetedCureBuild(for: doc, currentAppBuild: currentAppBuild) != nil { return .cure }
        // Cura della catena: a meno che le cure che il libro non ha siano tutte misurate come cure che non lo cambiano.
        if !sameBuild, build == nil || build! < latestCureBuild,
           !pendingCuresLeaveUnchanged(doc, since: build, currentSystemVersion: currentSystemVersion) { return .cure }
        if let was = Self.major(of: doc.processedSystemVersion), let now = Self.major(of: currentSystemVersion), was != now {
            return .systemUpdate
        }
        return nil
    }

    public func eligibleDocuments(_ docs: [ArchivedDocument], currentSystemVersion: String, currentAppBuild: String? = nil) -> [ArchivedDocument] {
        docs.filter { reason(for: $0, currentSystemVersion: currentSystemVersion, currentAppBuild: currentAppBuild) != nil }
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
    /// Origine della lettura messa da parte (`nil` = elaborata dal dispositivo; additivo, giro del 2026-10-16).
    public var readingOrigin: String?
    /// Riconoscimento di tabelle e figure saltato nella lettura messa da parte (additivo, giro del 2026-10-16).
    public var visualResourcesSkipped: String?
    public var takenAt: Date

    public init(document d: ArchivedDocument, takenAt: Date) {
        readingOrigin = d.readingOrigin
        visualResourcesSkipped = d.visualResourcesSkipped
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

    /// Ripristina lo stato fotografato (torna alla lettura precedente). Le annotazioni create DOPO la fotografia
    /// non si perdono mai (§ 12.14): se è dato l'indice del contenuto ripristinato, si riancorano lì; altrimenti
    /// restano, dichiarate orfane. Ritorna quante annotazioni nuove erano e quante sono finite orfane.
    @discardableResult
    public func restore(_ snapshot: ReadingSnapshot, documentId: String, restoredContent: ContentAnchorIndex? = nil) -> (carried: Int, orphaned: Int) {
        let current = document(id: documentId)
        let oldB = Set(snapshot.bookmarks.map { $0.id }), oldU = Set(snapshot.underlines.map { $0.id })
        var newerB = (current?.bookmarks ?? []).filter { !oldB.contains($0.id) }
        var newerU = (current?.underlines ?? []).filter { !oldU.contains($0.id) }
        var orphaned = 0
        if !newerB.isEmpty || !newerU.isEmpty {
            if let index = restoredContent {
                let out = AnnotationReanchoring.reanchor(bookmarks: newerB, underlines: newerU, readingPosition: 0,
                                                         readingAnchor: nil, in: index)
                newerB = out.bookmarks; newerU = out.underlines
                orphaned = out.report.orphanCount
            } else {
                newerB = newerB.map { var b = $0; b.isOrphan = true; return b }
                newerU = newerU.map { var u = $0; u.isOrphan = true; return u }
                orphaned = newerB.count + newerU.count
            }
        }
        applyAnnotationState(
            documentId: documentId, bookmarks: snapshot.bookmarks + newerB, underlines: snapshot.underlines + newerU,
            readingPosition: snapshot.readingPosition, readingAnchor: snapshot.readingAnchor,
            readingPositionIsApproximate: snapshot.readingPositionIsApproximate)
        restoreProcessedLabel(id: documentId, systemVersion: snapshot.processedSystemVersion,
                              appBuild: snapshot.processedAppBuild, at: snapshot.processedAt,
                              readingOrigin: snapshot.readingOrigin, visualResourcesSkipped: snapshot.visualResourcesSkipped)
        return (newerB.count + newerU.count, orphaned)
    }
}
