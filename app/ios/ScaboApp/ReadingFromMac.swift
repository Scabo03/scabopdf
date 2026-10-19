//
//  ReadingFromMac.swift
//  ScaboApp
//
//  LA RICEZIONE DELLA LETTURA PREPARATA DAL MAC (giro «costruzione della linea Mac», 2026-10-16; LAYER2 § 12.12).
//
//  Il Mac manda un solo file (`.scabolettura`, ScaboCore `ReadingPackage.swift`) con AirDrop, oppure lo si porta col cavo
//  nella cartella dell'app che il Finder del Mac mostra fra i documenti dell'iPad. L'app lo riceve da AirDrop, da «Apri
//  con», da File e da quella cartella; lo tiene in `Documents/Letture dal Mac` finché l'utente non decide, e:
//
//  1. riconosce il libro per IMPRONTA (§ 12.8; le impronte mancanti si completano prima);
//     - nessun libro → lo dice in prosa e propone di importare prima il PDF;
//     - più copie → chiede a quale, proponendo per prima la più recente aperta (§ 12.12, decisione 2);
//  2. una forma del file o un formato di lettura che l'app non conosce → lo dice in prosa, non cambia nulla;
//  3. offre la lettura come «Lettura migliore disponibile» (§ 12.13): spiegazione, due gesti per accettare, la lettura
//     di adesso resta sul dispositivo finché non si conferma la nuova (stessa copia precedente dell'offerta di
//     rielaborazione: `<id>.prev.json` + fotografia dello stato), esito con «Tieni», «Torna alla lettura precedente»,
//     «Decidi più tardi»;
//  4. la lettura si adotta COSÌ COM'È (decisione 3): niente seconda elaborazione;
//  5. le annotazioni del pacchetto, se ci sono, si fondono con quelle dell'iPad per contenuto (ScaboCore
//     `AnnotationMerge.swift`: niente doppioni, niente perdite).
//
//  Tutte le schermate sono dell'app (non avvisi di sistema): testo grande pieno, fuoco sul titolo, audit nei test UI.
//

import UIKit
import ScaboChain
import ScaboCore

// MARK: - La cartella delle letture arrivate

enum ReceivedReadings {

    /// Avviso: la cartella delle letture arrivate è cambiata (la Home si aggiorna).
    static let didChange = Notification.Name("scabopdf.letture-dal-mac.cambiate")

    /// `Documents/Letture dal Mac`: dove restano le letture arrivate finché l'utente non decide. È dentro la cartella
    /// dell'app che il Finder del Mac mostra col cavo (`UIFileSharingEnabled`), così vi si possono anche trascinare.
    static var folder: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("Letture dal Mac", isDirectory: true)
    }

    static func isPackage(_ url: URL) -> Bool {
        url.pathExtension.lowercased() == ReadingPackageFormat.fileExtension
    }

    /// Raccoglie nella cartella le letture lasciate altrove nei documenti dell'app: in cima (trascinate col cavo) e
    /// in `Inbox` (dove iOS copia i file aperti con «Apri con» o arrivati con AirDrop). Ritorna quante ne ha spostate.
    @discardableResult
    static func collectArrivals() -> Int {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        var moved = 0
        for dir in [docs, docs.appendingPathComponent("Inbox", isDirectory: true)] {
            let items = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
            for url in items where isPackage(url) {
                if (try? fm.moveItem(at: url, to: uniqueDestination(for: url.lastPathComponent))) != nil { moved += 1 }
            }
        }
        return moved
    }

    /// Accoglie un file arrivato da fuori (AirDrop, «Apri con», File): lo copia o lo sposta nella cartella e ritorna
    /// la sua posizione lì. `nil` se non si legge.
    static func accept(_ url: URL) -> URL? {
        let fm = FileManager.default
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        if url.deletingLastPathComponent().standardizedFileURL == folder.standardizedFileURL { return url }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let dest = uniqueDestination(for: url.lastPathComponent)
        let inInbox = url.path.contains("/Documents/Inbox/")
        do {
            if inInbox { try fm.moveItem(at: url, to: dest) } else { try fm.copyItem(at: url, to: dest) }
            return dest
        } catch {
            return nil
        }
    }

    /// Le letture in attesa, dalla più recente.
    static func pending() -> [URL] {
        let fm = FileManager.default
        let items = (try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        return items.filter(isPackage).sorted {
            let a = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let b = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return a > b
        }
    }

    static func remove(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    private static func uniqueDestination(for name: String) -> URL {
        var dest = folder.appendingPathComponent(name)
        var k = 2
        let base = (name as NSString).deletingPathExtension, ext = (name as NSString).pathExtension
        while FileManager.default.fileExists(atPath: dest.path) {
            dest = folder.appendingPathComponent("\(base) \(k).\(ext)")
            k += 1
        }
        return dest
    }
}

// MARK: - Il flusso

enum ReadingFromMac {

    private static var service: LibraryService { .shared }

    /// Le versioni della lettura che questa app sa aprire (quelle della sua cache).
    static var readableCacheFormats: ClosedRange<Int> {
        ReadingAssembly.minReadableCacheFormatVersion...ReadingAssembly.cacheFormatVersion
    }

    /// Avvia il flusso per un file nella cartella delle letture: intestazione, libro, copie, offerta.
    static func start(fileURL: URL, from presenter: UIViewController, onDone: @escaping () -> Void) {
        let header: ReadingPackageHeader
        do {
            header = try ReadingPackage.readHeader(at: fileURL).header
            try ReadingPackage.checkCompatibility(header, readableCacheFormats: readableCacheFormats)
            try checkLargeVolumeGranularity(header)
        } catch let problem as ReadingPackageProblem {
            ReceivedProblemViewController.present(problem: problem, fileURL: fileURL, from: presenter, onDone: onDone)
            return
        } catch {
            ReceivedProblemViewController.present(problem: .notAPackage, fileURL: fileURL, from: presenter, onDone: onDone)
            return
        }
        DocumentIdentity.documents(withFingerprint: header.source.sha256) { matches in
            if matches.isEmpty {
                MissingBookViewController.present(header: header, fileURL: fileURL, from: presenter, onDone: onDone)
            } else if matches.count == 1 {
                ReceiveOfferViewController.present(header: header, fileURL: fileURL, document: matches[0], copies: 1,
                                                   from: presenter, onDone: onDone)
            } else {
                ChooseCopyViewController.present(header: header, copies: matches, from: presenter) { chosen in
                    guard let chosen else { onDone(); return }
                    ReceiveOfferViewController.present(header: header, fileURL: fileURL, document: chosen,
                                                       copies: matches.count, from: presenter, onDone: onDone)
                }
            }
        }
    }

    /// I volumi enormi (oltre 1.500 pagine) l'iPad li apre solo da una lettura a granularità 1.200: una lettura a
    /// un'altra granularità la scarterebbe alla prima apertura, rielaborando il PDF. Meglio dirlo subito che perderla
    /// in silenzio. (La finestra del Mac usa sempre la regola dell'iPad; il caso nasce solo da strumenti di sviluppo o da
    /// versioni diverse delle due app.)
    static func checkLargeVolumeGranularity(_ h: ReadingPackageHeader) throws {
        guard ReadingAssembly.isLarge(pageCount: h.source.pageCount),
              h.reading.contentTarget != ReadingAssembly.largeDocumentGranularity else { return }
        throw ReadingPackageProblem.largeVolumeGranularity(
            found: h.reading.contentTarget, expected: ReadingAssembly.largeDocumentGranularity,
            producer: ReadingPackage.producerName(h.producer.app, h.producer.version))
    }

    // MARK: Testi

    static func dateText(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.dateStyle = .long
        f.timeStyle = .short
        return f.string(from: d)
    }

    /// Cosa arriva, in parole semplici (conteggi, mai testo del libro).
    static func whatArrives(_ h: ReadingPackageHeader, document: ArchivedDocument) -> String {
        var t = "È arrivata da \(h.producer.app) la lettura di «\(document.title)», preparata il \(dateText(h.createdAt)) "
            + "sul Mac con l'aiuto del modello che riconosce l'impaginazione delle pagine."
        var fixes: [String] = []
        if let n = h.reading.stitchedNotes, n > 0 {
            fixes.append(n == 1 ? "ha ricucito una nota spezzata fra due pagine" : "ha ricucito \(n) note spezzate fra due pagine")
        }
        if let n = h.reading.relabeledIndexLines, n > 0 {
            fixes.append(n == 1 ? "legge come testo dell'indice una voce che prima era letta come nota"
                         : "legge come testo dell'indice \(n) voci che prima erano lette come note")
        }
        if !fixes.isEmpty { t += " In questo libro il Mac " + fixes.joined(separator: " e ") + "." }
        if h.reading.visualResources > 0 {
            t += h.reading.visualResources == 1 ? " Porta una tabella o figura riconosciuta."
                : " Porta \(h.reading.visualResources) tabelle e figure riconosciute."
        }
        if h.reading.visualResourcesSkipped != nil {
            t += " Sul Mac il riconoscimento di tabelle e figure non è stato possibile: dopo, l'\(SystemGeneration.deviceName) proporrà di riprovarlo."
        }
        t += " Se il libro ha note molto lunghe, sono divise in parti, da ascoltare una alla volta, come fa ora anche l'\(SystemGeneration.deviceName). "
            + "Il resto del testo è quello che l'\(SystemGeneration.deviceName) ricava dallo stesso PDF: se il libro non aveva nulla da correggere, la "
            + "lettura resta molto simile a quella di adesso."
        if ReadingAssembly.isLarge(pageCount: h.source.pageCount) {
            t += " È un volume molto grande: come sull'\(SystemGeneration.deviceName), la lettura è a blocchi più ampi e senza Consultazione Rapida."
        }
        return t
    }

    /// Cosa succede alle annotazioni.
    static func annotationsText(_ h: ReadingPackageHeader, document: ArchivedDocument) -> String {
        let local = ReprocessOffer.annotationsCountText(document)
        var t = local.isEmpty
            ? "In questo libro non hai segnalibri né sottolineature."
            : "In questo libro hai \(local): l'app li cerca nella lettura nuova; quelli che non ritrova con sicurezza restano «da ricollocare»."
        if let a = h.annotations, a.bookmarks + a.underlines > 0 {
            var parts: [String] = []
            if a.bookmarks > 0 { parts.append(a.bookmarks == 1 ? "un segnalibro" : "\(a.bookmarks) segnalibri") }
            if a.underlines > 0 { parts.append(a.underlines == 1 ? "una sottolineatura" : "\(a.underlines) sottolineature") }
            t += " Dal Mac arrivano anche " + parts.joined(separator: " e ")
                + ": si uniscono ai tuoi senza doppioni; quelli che segnano lo stesso punto diventano uno solo, con tutti i tag."
        } else {
            t += " Dal Mac non arrivano annotazioni."
        }
        t += " Finché non confermi, la lettura di adesso resta sul dispositivo e puoi tornarci in qualunque momento."
        return t
    }

    // MARK: Applicazione

    /// Perché l'adozione non è avvenuta (il libro resta com'era).
    enum AdoptionFailure: Error, Equatable {
        case bookMissing
        case noSpaceForPrevious
        case cacheWriteFailed

        var prose: String {
            switch self {
            case .bookMissing:
                return "Il libro non è più nella libreria: la lettura dal Mac non è stata applicata."
            case .noSpaceForPrevious:
                return "Non c'è spazio per conservare la lettura di adesso: la lettura dal Mac non è stata applicata."
            case .cacheWriteFailed:
                return "Non è stato possibile salvare la lettura arrivata dal Mac, probabilmente per lo spazio sul dispositivo. "
                    + "Il libro è rimasto com'era e la lettura resta fra quelle arrivate."
            }
        }
    }

    /// PASSO 1 (sul main): ancore mancanti a contenuto fermo, la lettura di adesso messa da parte (copia precedente +
    /// fotografia dello stato, come l'offerta di rielaborazione), la lettura del Mac scritta come cache COSÌ COM'È, e
    /// l'etichetta della lettura (origine Mac, sistema del Mac, livello di cure). Su errore il libro resta com'era.
    static func adopt(reading r: PackagedReading, header: ReadingPackageHeader, documentId id: String,
                      at date: Date = Date()) -> AdoptionFailure? {
        dispatchPrecondition(condition: .onQueue(.main))
        guard service.store.document(id: id) != nil else { return .bookMissing }
        if let cached = service.loadCache(forDocumentId: id) {
            DocumentOpener.mintMissingAnchors(documentId: id, in: ContentAnchorIndex(segments: cached.content.pages.flatMap { $0.segments }))
        }
        let hadPrevious = service.hasPreviousReading(forDocumentId: id)
        guard let snapshot = service.store.readingSnapshot(documentId: id),
              (try? service.stashPreviousReading(snapshot, forDocumentId: id)) != nil else { return .noSpaceForPrevious }
        // Scrittura atomica: se non riesce, la lettura di adesso resta intatta e la copia appena messa da parte si toglie.
        guard service.writeCache(r.content, pageMap: r.pageMap, doctrineContent: r.doctrineContent,
                                 quickConsultTree: r.quickConsultTree, contentTarget: r.contentTarget, forDocumentId: id)
        else {
            if !hadPrevious { service.discardPreviousReading(forDocumentId: id) }
            return .cacheWriteFailed
        }
        service.store.recordReceivedReading(id: id, systemVersion: header.producer.system,
                                            cureLevel: header.producer.cureLevel, at: date,
                                            visualResourcesSkipped: header.reading.visualResourcesSkipped)
        return nil
    }

    /// PASSO 2 (qualunque coda, puro): la fusione per contenuto delle annotazioni dell'iPad e di quelle del pacchetto
    /// (tag già mappati) nella lettura adottata.
    static func merge(current: ArchivedDocument, incoming: (bookmarks: [Bookmark], underlines: [Underline]),
                      segments: [ContentSegment]) -> MergedAnnotations {
        AnnotationMerge.merge(
            localBookmarks: current.bookmarks ?? [], localUnderlines: current.underlines ?? [],
            readingPosition: current.readingPosition, readingAnchor: current.readingAnchor,
            incomingBookmarks: incoming.bookmarks, incomingUnderlines: incoming.underlines,
            in: ContentAnchorIndex(segments: segments))
    }

    /// PASSO 3 (sul main): le annotazioni fuse e la posizione nello store.
    static func commit(_ merged: MergedAnnotations, documentId id: String) {
        dispatchPrecondition(condition: .onQueue(.main))
        service.store.applyAnnotationState(
            documentId: id, bookmarks: merged.bookmarks, underlines: merged.underlines,
            readingPosition: merged.readingPosition, readingAnchor: merged.readingAnchor,
            readingPositionIsApproximate: merged.readingPositionIsApproximate ? true : nil)
    }

    /// Adotta la lettura del pacchetto per `documentId` con i tre passi sopra (il carico si legge e la fusione si
    /// calcola fuori dal thread principale), poi l'esito. Su errore il libro resta com'era.
    static func apply(fileURL: URL, header: ReadingPackageHeader, documentId id: String, from presenter: UIViewController,
                      onDone: @escaping () -> Void) {
        let waiting = ReceivingViewController()
        presenter.present(waiting, animated: Motion.animated())
        DispatchQueue.global(qos: .userInitiated).async {
            let body: (reading: PackagedReading, annotations: PackagedAnnotations?)?
            if let data = try? Data(contentsOf: fileURL), let (h, offset) = try? ReadingPackage.readHeader(data), h == header {
                body = try? ReadingPackage.readBody(data, header: h, payloadOffset: offset)
            } else {
                body = nil
            }
            DispatchQueue.main.async {
                guard let body else {
                    waiting.dismiss(animated: true) {
                        ReceivedProblemViewController.present(problem: .damaged, fileURL: fileURL, from: presenter, onDone: onDone)
                    }
                    return
                }
                if let failure = adopt(reading: body.reading, header: header, documentId: id) {
                    waiting.dismiss(animated: true) {
                        DocumentOpener.presentError(failure.prose, from: presenter)
                        onDone()
                    }
                    return
                }
                guard let current = service.store.document(id: id) else {
                    waiting.dismiss(animated: true) { onDone() }
                    return
                }
                let incoming = mapTags(body.annotations)
                let segments = body.reading.content.pages.flatMap { $0.segments }
                DispatchQueue.global(qos: .userInitiated).async {
                    let merged = merge(current: current, incoming: incoming, segments: segments)
                    DispatchQueue.main.async {
                        commit(merged, documentId: id)
                        ReceivedReadings.remove(fileURL)
                        waiting.dismiss(animated: true) {
                            ReceiveResultViewController.present(documentId: id, report: merged.report,
                                                                positionApproximate: merged.readingPositionIsApproximate,
                                                                from: presenter, onDone: onDone)
                        }
                    }
                }
            }
        }
    }

    /// I tag del pacchetto ritrovati per nome nello spazio dei tag dell'iPad (creati se mancano).
    static func mapTags(_ a: PackagedAnnotations?) -> (bookmarks: [Bookmark], underlines: [Underline]) {
        guard let a else { return ([], []) }
        var map: [String: String] = [:]
        for t in a.tags {
            let name = t.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if let local = service.store.tags().first(where: { $0.name.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }) {
                map[t.id] = local.id
            } else if let created = service.store.createTag(name: name) {
                map[t.id] = created.id
            }
        }
        let bookmarks = a.bookmarks.map { b -> Bookmark in
            var x = b
            x.tagIds = b.tagIds.compactMap { map[$0] }
            return x
        }
        return (bookmarks, a.underlines)
    }

    /// Esito in parole semplici.
    static func resultText(_ r: AnnotationMergeReport, positionApproximate: Bool) -> String {
        var lines = ["La lettura arrivata dal Mac è in uso."]
        let l = r.localReport
        let lb = l.bookmarksRelocated + l.bookmarksOrphaned + l.bookmarksWithoutAnchor
        let lu = l.underlinesRelocated + l.underlinesOrphaned + l.underlinesWithoutAnchor
        if lb > 0 {
            let lost = l.bookmarksOrphaned + l.bookmarksWithoutAnchor
            lines.append(lost == 0 ? "I tuoi segnalibri sono al loro posto (\(lb))."
                         : "Dei tuoi segnalibri \(l.bookmarksRelocated) su \(lb) sono al loro posto; \(lost) sono da ricollocare, in fondo alla lista dei segnalibri.")
        }
        if lu > 0 {
            let lost = l.underlinesOrphaned + l.underlinesWithoutAnchor
            lines.append(lost == 0 ? "Le tue sottolineature sono al loro posto (\(lu))."
                         : "Delle tue sottolineature \(l.underlinesRelocated) su \(lu) sono al loro posto; \(lost) non sono state ritrovate: restano salvate e riappaiono tornando alla lettura precedente.")
        }
        if r.incomingTotal > 0 {
            var parts: [String] = []
            if r.bookmarksAdded > 0 { parts.append("\(r.bookmarksAdded) segnalibri aggiunti") }
            if r.bookmarksMerged > 0 { parts.append("\(r.bookmarksMerged) segnalibri uniti ai tuoi") }
            if r.underlinesAdded > 0 { parts.append("\(r.underlinesAdded) sottolineature aggiunte") }
            if r.underlinesUnited > 0 { parts.append("\(r.underlinesUnited) sottolineature unite a una tua") }
            if r.underlinesDuplicate > 0 { parts.append("\(r.underlinesDuplicate) sottolineature che avevi già") }
            let orphan = r.bookmarksOrphan + r.underlinesOrphan
            if orphan > 0 { parts.append("\(orphan) da ricollocare") }
            lines.append("Dal Mac: " + parts.joined(separator: ", ") + ".")
        }
        lines.append(positionApproximate
            ? "Il punto in cui eri arrivato non è stato ritrovato con sicurezza: riaprendo il libro partirai dall'inizio della stessa pagina."
            : "Il punto in cui eri arrivato è stato ritrovato.")
        lines.append("Puoi tenere la nuova lettura oppure tornare a quella di prima. Se non decidi adesso, la scelta resta fra le opzioni del libro.")
        lines.append("Se torni a quella di prima, la lettura del Mac non resta sull'\(SystemGeneration.deviceName): per riaverla, rimandala dal Mac.")
        return lines.joined(separator: " ")
    }
}

// MARK: - Le schermate

/// Un problema del file, in prosa, con «Chiudi» e la possibilità di toglierlo dalla cartella.
final class ReceivedProblemViewController: ReprocessTextViewController {
    private let problem: ReadingPackageProblem
    private let fileURL: URL
    private let onDone: () -> Void
    private var heading: UILabel?

    static func present(problem: ReadingPackageProblem, fileURL: URL, from presenter: UIViewController, onDone: @escaping () -> Void) {
        let vc = ReceivedProblemViewController(problem: problem, fileURL: fileURL, onDone: onDone)
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .formSheet
        presenter.present(nav, animated: Motion.animated())
    }

    private init(problem: ReadingPackageProblem, fileURL: URL, onDone: @escaping () -> Void) {
        self.problem = problem; self.fileURL = fileURL; self.onDone = onDone
        super.init(nibName: nil, bundle: nil)
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) non supportato.") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Lettura dal Mac"
        heading = addHeading("Questa lettura non si può usare")
        addParagraph(problem.prose, identifier: "received.problem")
        addButton("Chiudi", prominent: true, identifier: "received.close") { [weak self] in self?.close() }
        addButton("Togli il file dalle letture arrivate", prominent: false, identifier: "received.remove") { [weak self] in
            guard let self else { return }
            ReceivedReadings.remove(self.fileURL)
            UIAccessibility.post(notification: .announcement, argument: "File tolto dalle letture arrivate.")
            self.close()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIAccessibility.post(notification: .screenChanged, argument: heading)
    }

    private func close() { let d = onDone; dismiss(animated: true) { d() } }
}

/// Il libro non è in libreria: lo dice e propone di importare prima il PDF.
final class MissingBookViewController: ReprocessTextViewController {
    private let header: ReadingPackageHeader
    private let fileURL: URL
    private let onDone: () -> Void
    private var heading: UILabel?

    static func present(header: ReadingPackageHeader, fileURL: URL, from presenter: UIViewController, onDone: @escaping () -> Void) {
        let vc = MissingBookViewController(header: header, fileURL: fileURL, onDone: onDone)
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .formSheet
        presenter.present(nav, animated: Motion.animated())
    }

    private init(header: ReadingPackageHeader, fileURL: URL, onDone: @escaping () -> Void) {
        self.header = header; self.fileURL = fileURL; self.onDone = onDone
        super.init(nibName: nil, bundle: nil)
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) non supportato.") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Lettura dal Mac"
        heading = addHeading("Il libro non è in libreria")
        addParagraph("È arrivata dal Mac la lettura di «\(header.source.title)» (file «\(header.source.fileName)», \(header.source.pageCount) pagine), "
            + "ma questo libro non è nella libreria di questo dispositivo, oppure non è lo stesso file byte per byte. "
            + "Importa prima il PDF con il tasto più della Home; poi riapri la lettura dalla riga delle letture arrivate dal Mac. "
            + "La lettura resta in attesa finché non decidi.", identifier: "missing.text")
        addButton("Importa il PDF adesso…", prominent: true, identifier: "missing.import") { [weak self] in
            guard let self, let presenter = self.presentingViewController else { return }
            let d = self.onDone
            self.dismiss(animated: true) { DocumentOpener.startImport(from: presenter, onImported: d) }
        }
        addButton("Chiudi", prominent: false, identifier: "missing.close") { [weak self] in
            guard let self else { return }
            let d = self.onDone
            self.dismiss(animated: true) { d() }
        }
        addButton("Togli questa lettura dall'\(SystemGeneration.deviceName)…", prominent: false, identifier: "missing.discard") { [weak self] in
            guard let self, let nav = self.navigationController else { return }
            ReprocessConfirmViewController.push(
                on: nav, identifier: "confirm.discard",
                question: "Togliere questa lettura dall'\(SystemGeneration.deviceName)?",
                explanation: "La lettura arrivata dal Mac per «\(self.header.source.title)» si cancella dall'\(SystemGeneration.deviceName). Se poi la vorrai, "
                    + "rimandala dal Mac.",
                actionTitle: "Togli la lettura") { [weak self] in
                    guard let self else { return }
                    ReceivedReadings.remove(self.fileURL)
                    let d = self.onDone
                    UIAccessibility.post(notification: .announcement, argument: "Lettura dal Mac tolta dall'\(SystemGeneration.deviceName).")
                    self.dismiss(animated: true) { d() }
                }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIAccessibility.post(notification: .screenChanged, argument: heading)
    }
}

/// Più copie dello stesso libro: a quale applicare la lettura (la più recente aperta per prima).
final class ChooseCopyViewController: ReprocessTextViewController {
    private let header: ReadingPackageHeader
    private let copies: [ArchivedDocument]
    private let onChoice: (ArchivedDocument?) -> Void
    private var heading: UILabel?
    private var decided = false

    static func present(header: ReadingPackageHeader, copies: [ArchivedDocument], from presenter: UIViewController,
                        onChoice: @escaping (ArchivedDocument?) -> Void) {
        let vc = ChooseCopyViewController(header: header, copies: copies, onChoice: onChoice)
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .formSheet
        presenter.present(nav, animated: Motion.animated())
    }

    private init(header: ReadingPackageHeader, copies: [ArchivedDocument], onChoice: @escaping (ArchivedDocument?) -> Void) {
        self.header = header; self.copies = copies; self.onChoice = onChoice
        super.init(nibName: nil, bundle: nil)
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) non supportato.") }

    static func copyLabel(_ d: ArchivedDocument, index: Int) -> String {
        let opened = d.lastOpenedAt.map { "aperta il \(ReadingFromMac.dateText($0))" } ?? "mai aperta"
        let annotations = ReprocessOffer.annotationsCountText(d)
        var s = "«\(d.title)», \(opened)"
        if !annotations.isEmpty { s += ", con \(annotations)" }
        return index == 0 ? s + " (la più recente)" : s
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Lettura dal Mac"
        heading = addHeading("A quale copia applicarla?")
        addParagraph("È arrivata dal Mac la lettura di «\(header.source.title)». In libreria ci sono \(copies.count) copie di questo libro: "
            + "scegli a quale applicarla. La prima è quella che hai aperto più di recente. Le altre copie restano come sono.",
            identifier: "copies.text")
        for (i, d) in copies.enumerated() {
            addButton(Self.copyLabel(d, index: i), prominent: i == 0, identifier: "copies.\(i)") { [weak self] in self?.choose(d) }
        }
        addButton("Annulla", prominent: false, identifier: "copies.cancel") { [weak self] in self?.choose(nil) }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIAccessibility.post(notification: .screenChanged, argument: heading)
    }

    private func choose(_ d: ArchivedDocument?) {
        guard !decided else { return }
        decided = true
        let c = onChoice
        dismiss(animated: true) { c(d) }
    }
}

/// L'offerta: «Lettura migliore disponibile» con la lettura del Mac. Due gesti per accettare.
final class ReceiveOfferViewController: ReprocessTextViewController {
    private let header: ReadingPackageHeader
    private let fileURL: URL
    private let document: ArchivedDocument
    private let copies: Int
    private let onDone: () -> Void
    private var heading: UILabel?

    static func present(header: ReadingPackageHeader, fileURL: URL, document: ArchivedDocument, copies: Int,
                        from presenter: UIViewController, onDone: @escaping () -> Void) {
        let vc = ReceiveOfferViewController(header: header, fileURL: fileURL, document: document, copies: copies, onDone: onDone)
        presenter.present(UINavigationController(rootViewController: vc), animated: Motion.animated())
    }

    private init(header: ReadingPackageHeader, fileURL: URL, document: ArchivedDocument, copies: Int, onDone: @escaping () -> Void) {
        self.header = header; self.fileURL = fileURL; self.document = document; self.copies = copies; self.onDone = onDone
        super.init(nibName: nil, bundle: nil)
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) non supportato.") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Lettura migliore"
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Chiudi", primaryAction: UIAction { [weak self] _ in self?.later() })
        heading = addHeading("Lettura migliore disponibile per «\(document.title)»")
        addParagraph("Cosa arriva. " + ReadingFromMac.whatArrives(header, document: document), identifier: "receive.what")
        addParagraph("Da dove. Preparata con \(ReadingPackage.producerName(header.producer.app, header.producer.version)) "
            + "su \(header.producer.system).", identifier: "receive.from")
        addParagraph("Le tue annotazioni. " + ReadingFromMac.annotationsText(header, document: document), identifier: "receive.annotations")
        addButton("Usa la lettura del Mac…", prominent: true, identifier: "receive.accept") { [weak self] in self?.askConfirmation() }
        addButton("Non ora", prominent: false, identifier: "receive.later") { [weak self] in self?.later() }
        addButton("Togli questa lettura dall'\(SystemGeneration.deviceName)…", prominent: false, identifier: "receive.discard") { [weak self] in self?.askDiscard() }
    }

    /// Una lettura che non si vuole si può togliere (nessun vicolo cieco: senza, la riga della Home restava per sempre).
    private func askDiscard() {
        guard let nav = navigationController else { return }
        ReprocessConfirmViewController.push(
            on: nav, identifier: "confirm.discard",
            question: "Togliere questa lettura dall'\(SystemGeneration.deviceName)?",
            explanation: "La lettura arrivata dal Mac per «\(document.title)» si cancella dall'\(SystemGeneration.deviceName). Il libro resta com'è, con le "
                + "sue annotazioni. Se poi la vorrai, rimandala dal Mac.",
            actionTitle: "Togli la lettura") { [weak self] in self?.discard() }
    }

    private func discard() {
        ReceivedReadings.remove(fileURL)
        let d = onDone
        UIAccessibility.post(notification: .announcement, argument: "Lettura dal Mac tolta dall'\(SystemGeneration.deviceName).")
        dismiss(animated: true) { d() }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIAccessibility.post(notification: .screenChanged, argument: heading)
    }

    private func later() {
        let d = onDone
        UIAccessibility.post(notification: .announcement, argument: "La lettura dal Mac resta in attesa nella Home.")
        dismiss(animated: true) { d() }
    }

    private func askConfirmation() {
        guard let nav = navigationController else { return }
        ReprocessConfirmViewController.push(
            on: nav, identifier: "confirm.receive",
            question: "Usare la lettura del Mac?",
            explanation: "«\(document.title)» userà la lettura arrivata dal Mac. La lettura di adesso resta sul dispositivo finché non confermi quella nuova.",
            actionTitle: "Usa la lettura del Mac") { [weak self] in self?.start() }
    }

    private func start() {
        guard let presenter = presentingViewController else { return }
        let (url, h, id, d) = (fileURL, header, document.id, onDone)
        dismiss(animated: true) {
            ReadingFromMac.apply(fileURL: url, header: h, documentId: id, from: presenter, onDone: d)
        }
    }
}

/// Attesa breve mentre la lettura si applica (decompressione, cache, annotazioni).
final class ReceivingViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let label = UILabel()
        label.text = "Applicazione della lettura arrivata dal Mac in corso…"
        label.font = .preferredFont(forTextStyle: .title3)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        label.textAlignment = .center
        label.accessibilityTraits.insert(.header)
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.startAnimating()
        spinner.isAccessibilityElement = false
        waitingLabel = label
        let stack = UIStackView(arrangedSubviews: [spinner, label])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: view.readableContentGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.readableContentGuide.trailingAnchor),
        ])
        isModalInPresentation = true
    }

    private weak var waitingLabel: UILabel?

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIAccessibility.post(notification: .screenChanged, argument: waitingLabel)
    }
}

/// L'esito, con le tre scelte dell'offerta di rielaborazione.
final class ReceiveResultViewController: ReprocessTextViewController {
    private let documentId: String
    private let report: AnnotationMergeReport
    private let positionApproximate: Bool
    private let onDone: () -> Void
    private var heading: UILabel?

    static func present(documentId: String, report: AnnotationMergeReport, positionApproximate: Bool,
                        from presenter: UIViewController, onDone: @escaping () -> Void) {
        let vc = ReceiveResultViewController(documentId: documentId, report: report, positionApproximate: positionApproximate, onDone: onDone)
        presenter.present(UINavigationController(rootViewController: vc), animated: Motion.animated())
    }

    private init(documentId: String, report: AnnotationMergeReport, positionApproximate: Bool, onDone: @escaping () -> Void) {
        self.documentId = documentId; self.report = report; self.positionApproximate = positionApproximate; self.onDone = onDone
        super.init(nibName: nil, bundle: nil)
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) non supportato.") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Lettura dal Mac"
        heading = addHeading("Lettura dal Mac applicata")
        addParagraph(ReadingFromMac.resultText(report, positionApproximate: positionApproximate), identifier: "received.result")
        addButton("Tieni la nuova lettura", prominent: true, identifier: "received.keep") { [weak self] in
            guard let self, let nav = self.navigationController else { return }
            // Seconda conferma nella stessa scheda (niente schede sovrapposte), con le parole dell'offerta di rielaborazione.
            let id = self.documentId
            ReprocessConfirmViewController.push(
                on: nav, identifier: "confirm.keep",
                question: "Tenere la nuova lettura?",
                explanation: "La lettura di prima verrà cancellata dal dispositivo e non potrai più tornarci. Le tue annotazioni restano.",
                actionTitle: "Tieni la nuova lettura") { [weak self] in
                    ReprocessOffer.confirmNewReading(id)
                    self?.close()
                }
        }
        addButton("Torna alla lettura precedente", prominent: false, identifier: "received.revert") { [weak self] in
            guard let self else { return }
            ReprocessOffer.revertToPrevious(self.documentId); self.close()
        }
        addButton("Decidi più tardi", prominent: false, identifier: "received.later") { [weak self] in self?.close() }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIAccessibility.post(notification: .screenChanged, argument: heading)
    }

    private func close() { let d = onDone; dismiss(animated: true) { d() } }
}

/// L'elenco delle letture arrivate (dalla Home).
final class ReceivedListViewController: UITableViewController {
    private var files: [(url: URL, header: ReadingPackageHeader?)] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Letture dal Mac"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.estimatedSectionFooterHeight = 60
        reload()
    }

    private func reload() {
        ReceivedReadings.collectArrivals()
        files = ReceivedReadings.pending().map { ($0, try? ReadingPackage.readHeader(at: $0).header) }
        tableView.reloadData()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { max(files.count, 1) }

    /// Il piè dell'elenco con un'etichetta che segue la dimensione del testo scelta dall'utente (l'etichetta di sistema dei
    /// piè di sezione, sull'iPad, non la segue: l'audit d'accessibilità lo segnala).
    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let footer = UITableViewHeaderFooterView(reuseIdentifier: nil)
        let label = UILabel()
        label.text = "Le letture preparate sul Mac arrivano con AirDrop o col cavo. Tocca una lettura per sapere a quale libro va e cosa cambia: niente si applica senza la tua conferma."
        label.font = .preferredFont(forTextStyle: .footnote)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        label.accessibilityIdentifier = "fromMac.footer"
        footer.contentView.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: footer.contentView.layoutMarginsGuide.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: footer.contentView.layoutMarginsGuide.trailingAnchor),
            label.topAnchor.constraint(equalTo: footer.contentView.topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: footer.contentView.bottomAnchor, constant: -8),
        ])
        return footer
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        UITableView.automaticDimension
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var config = cell.defaultContentConfiguration()
        config.textProperties.numberOfLines = 0
        config.secondaryTextProperties.numberOfLines = 0
        if files.isEmpty {
            config.text = "Nessuna lettura arrivata dal Mac."
            cell.accessoryType = .none
            cell.selectionStyle = .none
            cell.accessibilityHint = nil
        } else {
            let f = files[indexPath.row]
            if let h = f.header {
                config.text = h.source.title
                config.secondaryText = "Preparata il \(ReadingFromMac.dateText(h.createdAt)), \(h.source.pageCount) pagine"
            } else {
                config.text = f.url.deletingPathExtension().lastPathComponent
                config.secondaryText = "File da controllare"
            }
            cell.accessoryType = .disclosureIndicator
            cell.accessibilityHint = "Apre la spiegazione: niente si applica senza la tua conferma."
        }
        cell.contentConfiguration = config
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        guard !files.isEmpty else { return }
        ReadingFromMac.start(fileURL: files[indexPath.row].url, from: self) { [weak self] in self?.reload() }
    }
}
