//
//  ReprocessOffer.swift
//  ScaboApp
//
//  L'OFFERTA DI RIELABORAZIONE (LAYER2_PRODUCT_DECISIONS § 12.13 / § 12.14, docs/ANCORE_ANNOTAZIONI.md § 5).
//
//  Si offre, non si impone mai. Si rivolge a chi usa VoiceOver e non è pratico: dev'essere chiara al
//  primo ascolto e impossibile da accettare per sbaglio. Per questo:
//  - l'offerta vive in una schermata a sé, che si apre solo su scelta dell'utente (riga «Lettura
//    migliore disponibile» nella Home, opzioni del file, referto); il fuoco parte dal titolo e dalla
//    spiegazione, non dal pulsante;
//  - la spiegazione dice in parole semplici cosa cambia, quanto tempo serve e cosa succede alle
//    annotazioni;
//  - accettare richiede DUE gesti distinti: «Rielabora…» e poi la conferma in un avviso il cui
//    pulsante preferito è «Annulla»;
//  - la lettura precedente resta sul dispositivo finché l'utente non conferma la nuova: «Torna alla
//    lettura precedente» rimette tutto com'era (cache, annotazioni, posizione, etichetta).
//

import UIKit
import ScaboCore

// MARK: - Politica e testi

enum ReprocessOffer {

    /// Generazioni validate dalla doppia rete della build in uso, e l'ultima build che porta una cura da
    /// offrire. Da aggiornare nel giro che valida una nuova generazione o introduce una cura.
    static let policy = ReprocessingPolicy(validatedSystemMajors: [26, 27], latestCureBuild: 49)

    /// Le cure portate dalle build, in parole semplici, per dire «cosa cambia».
    static let cures: [(build: Int, text: String)] = [
        (45, "i titoli dei paragrafi numerati si trovano nella navigazione per intestazioni"),
        (46, "le parole che il lettore di sistema incollava insieme vengono separate"),
        (47, "il titolo corrente e il numero di pagina in testa e in fondo alle pagine non vengono più letti come testo"),
        (48, "le annotazioni seguono il testo, e nelle testatine fuse con un elenco non si perde più la lettera dell'elenco"),
        (49, "nelle dispense scritte con Pages, Word o Google Docs i titoli si trovano nella navigazione per intestazioni "
            + "e il testo è diviso nei suoi paragrafi; nei codici i titoli delle leggi complementari sono intestazioni; "
            + "nei manuali si trovano i titoli dei paragrafi col segno di paragrafo e le sezioni; tornano letti i titoli "
            + "e le righe di testo che sparivano insieme a una testatina; gli abstract colorati delle riviste e gli "
            + "indirizzi web non sono più letti come titoli"),
    ]

    private static var service: LibraryService { .shared }

    static func reason(for doc: ArchivedDocument) -> ReprocessingReason? {
        policy.reason(for: doc, currentSystemVersion: SystemGeneration.current, currentAppBuild: SystemGeneration.appBuild)
    }

    static func eligibleDocuments() -> [ArchivedDocument] {
        policy.eligibleDocuments(service.store.allDocuments(), currentSystemVersion: SystemGeneration.current,
                                 currentAppBuild: SystemGeneration.appBuild)
            .filter { service.hasArchivedSource(forDocumentId: $0.id, kind: $0.sourceKind) }
            .sorted { ($0.lastOpenedAt ?? .distantPast) > ($1.lastOpenedAt ?? .distantPast) }
    }

    /// Libri rielaborati in attesa della scelta. Una copia precedente rimasta da un'elaborazione INTERROTTA
    /// (app chiusa prima della fine: l'etichetta è ancora quella della fotografia, la cache non è stata
    /// sostituita) non è una scelta da fare: si cancella qui, il libro è rimasto com'era.
    static func pendingConfirmation() -> [ArchivedDocument] {
        service.store.allDocuments().filter { doc in
            guard service.hasPreviousReading(forDocumentId: doc.id) else { return false }
            if let snap = service.previousReadingSnapshot(forDocumentId: doc.id),
               snap.processedAt == doc.processedAt, snap.processedAppBuild == doc.processedAppBuild {
                service.discardPreviousReading(forDocumentId: doc.id)
                return false
            }
            return true
        }
    }

    /// Cosa cambia, per questo libro.
    static func whatChanges(_ doc: ArchivedDocument, reason: ReprocessingReason) -> String {
        let since = doc.processedAppBuild.flatMap { Int($0) } ?? 0
        let list = cures.filter { $0.build > since }.map { $0.text }
        var text = ""
        if reason == .systemUpdate, let was = doc.processedSystemVersion {
            text += "Questo libro è stato letto con \(was); ora il lettore di sistema è \(SystemGeneration.current), già verificato per questa versione dell'app. "
        }
        if !list.isEmpty {
            // Le cure valgono per alcuni tipi di libri, non per tutti: l'offerta lo dice, così chi ha un libro che non
            // cambia non si aspetta una lettura diversa (revisione indipendente del giro «titoli e testatine»).
            text += "Da quando il libro è stato aperto la prima volta, l'app ha imparato a leggere meglio alcuni libri: "
                + list.joined(separator: "; ") + ". Se questo libro non è fra quelli, la nuova lettura resta uguale."
        }
        return text
    }

    /// Quanto tempo serve, a voce (stima grossolana dichiarata come tale).
    static func howLong(_ doc: ArchivedDocument) -> String {
        switch doc.sourcePageCount {
        case ..<300: return "Di solito serve meno di un minuto."
        case ..<1500: return "Di solito servono uno o due minuti."
        default: return "È un volume molto grande: di solito servono alcuni minuti."
        }
    }

    /// Cosa succede alle annotazioni, con i numeri del libro.
    static func annotationsText(_ doc: ArchivedDocument) -> String {
        let b = doc.bookmarks?.count ?? 0
        let u = doc.underlines?.count ?? 0
        var parts: [String] = []
        if b > 0 { parts.append(b == 1 ? "un segnalibro" : "\(b) segnalibri") }
        if u > 0 { parts.append(u == 1 ? "una sottolineatura" : "\(u) sottolineature") }
        let head = parts.isEmpty
            ? "Non hai segnalibri né sottolineature in questo libro; il punto in cui eri arrivato viene ritrovato nel testo nuovo."
            : "In questo libro hai " + parts.joined(separator: " e ") + ". L'app li cerca nel testo nuovo: quelli che ritrova con sicurezza restano al loro posto; quelli che non ritrova restano nella lista dei segnalibri come «da ricollocare», e te lo dice. Non si cancella nulla."
        return head + " Finché non confermi, la lettura di adesso resta sul dispositivo e puoi tornarci in qualunque momento."
    }

    // MARK: Ingresso

    /// Apre la schermata dell'offerta per un libro (mai l'elaborazione diretta).
    static func presentOffer(for doc: ArchivedDocument, from presenter: UIViewController, onDone: @escaping () -> Void) {
        guard let reason = reason(for: doc) else { return }
        let vc = ReprocessOfferViewController(document: doc, reason: reason, onDone: onDone)
        presenter.present(UINavigationController(rootViewController: vc), animated: Motion.animated())
    }

    /// Azioni per un libro che ha una lettura precedente in attesa di conferma.
    static func presentPendingChoice(for doc: ArchivedDocument, from presenter: UIViewController, onDone: @escaping () -> Void) {
        let sheet = UIAlertController(
            title: doc.title,
            message: "Questo libro è stato rielaborato e la lettura di prima è ancora sul dispositivo.",
            preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Tieni la nuova lettura", style: .default) { [weak presenter] _ in
            guard let presenter else { return }
            askToKeepNewReading(doc.id, from: presenter, onDone: onDone)
        })
        sheet.addAction(UIAlertAction(title: "Torna alla lettura precedente", style: .default) { _ in
            revertToPrevious(doc.id); onDone()
        })
        sheet.addAction(UIAlertAction(title: "Decidi più tardi", style: .cancel))
        FileOptions.configurePopover(sheet, in: presenter)
        presenter.present(sheet, animated: true)
    }

    // MARK: Esecuzione

    /// «Tieni la nuova lettura» cancella la lettura di prima: si chiede conferma in una schermata dell'app
    /// (testo grande pieno), con «Annulla» per primo e in evidenza.
    static func askToKeepNewReading(_ id: String, from presenter: UIViewController, onDone: @escaping () -> Void) {
        ReprocessConfirmViewController.present(
            from: presenter, identifier: "confirm.keep",
            question: "Tenere la nuova lettura?",
            explanation: "La lettura di prima verrà cancellata dal dispositivo e non potrai più tornarci. Le tue annotazioni restano.",
            actionTitle: "Tieni la nuova lettura") {
                confirmNewReading(id); onDone()
            }
    }

    static func confirmNewReading(_ id: String) {
        service.discardPreviousReading(forDocumentId: id)
        UIAccessibility.post(notification: .announcement, argument: "Nuova lettura confermata. La lettura precedente è stata cancellata.")
    }

    /// Torna alla lettura di prima. Le annotazioni fatte DOPO la rielaborazione non si perdono (§ 12.14): si
    /// riancorano sul contenuto ripristinato, o restano dichiarate «da ricollocare».
    static func revertToPrevious(_ id: String) {
        guard let snapshot = service.restorePreviousCache(forDocumentId: id) else { return }
        let restored = service.loadCache(forDocumentId: id).map { ContentAnchorIndex(segments: $0.content.pages.flatMap { $0.segments }) }
        let r = service.store.restore(snapshot, documentId: id, restoredContent: restored)
        var msg = "Sei tornato alla lettura precedente."
        if r.carried > 0 {
            msg += r.orphaned == 0
                ? " Anche le annotazioni fatte dopo la rielaborazione sono al loro posto."
                : " Delle annotazioni fatte dopo la rielaborazione, \(r.orphaned) sono da ricollocare."
        }
        UIAccessibility.post(notification: .announcement, argument: msg)
    }

    /// Rielabora il libro: conia le ancore mancanti sul contenuto di adesso, mette da parte la lettura
    /// di adesso, elabora nella schermata dedicata (§ 12.9), riancora le annotazioni sul testo nuovo e
    /// mostra l'esito. Su annullamento o errore il libro resta esattamente com'era.
    static func run(documentId id: String, from presenter: UIViewController, onDone: @escaping (ReanchorReport?) -> Void) {
        guard let doc = service.store.document(id: id),
              service.hasArchivedSource(forDocumentId: id, kind: doc.sourceKind) else {
            DocumentOpener.presentError("Il file di origine di questo libro non è più sul dispositivo: non si può rielaborare.", from: presenter)
            onDone(nil); return
        }
        // 1. Ancore mancanti, a contenuto fermo (gli id di adesso sono ancora veri).
        if let cached = service.loadCache(forDocumentId: id) {
            DocumentOpener.mintMissingAnchors(
                documentId: id, in: ContentAnchorIndex(segments: cached.content.pages.flatMap { $0.segments }))
        }
        // 2. La lettura di adesso si mette da parte.
        guard let snapshot = service.store.readingSnapshot(documentId: id) else { onDone(nil); return }
        do { try service.stashPreviousReading(snapshot, forDocumentId: id) } catch {
            DocumentOpener.presentError("Non c'è spazio per conservare la lettura di adesso: la rielaborazione non parte.", from: presenter)
            onDone(nil); return
        }
        // 3. Elaborazione nella schermata dedicata.
        let large = doc.sourcePageCount > DocumentOpener.LARGE_DOCUMENT_PAGE_THRESHOLD
        let target = large ? DocumentOpener.LARGE_DOCUMENT_GRANULARITY : DEFAULT_GRANULARITY_TARGET
        let vc = ProcessingViewController(
            fileURL: service.archivedSourceURL(forDocumentId: id, kind: doc.sourceKind), sourceName: doc.title,
            granularityTarget: target, buildDoctrine: !large, processor: DocumentProcessor())
        vc.onOutcome = { [weak presenter] outcome in
            presenter?.dismiss(animated: true) {
                guard let presenter else { return }
                switch outcome {
                case .success(let document, let content, let doctrine):
                    let pageMap = DocumentOpener.buildPageMap(document, content: content, doctrineContent: doctrine)
                    let tree = large ? nil : DocumentOpener.quickConsultTreeIfAvailable(document)
                    service.writeCache(content, pageMap: pageMap, doctrineContent: large ? nil : doctrine,
                                       quickConsultTree: tree, contentTarget: target, forDocumentId: id)
                    service.store.recordProcessed(id: id, systemVersion: SystemGeneration.current, appBuild: SystemGeneration.appBuild)
                    // 4. Riancoraggio sul testo nuovo (fuori dal thread principale: sui codici l'indice costa).
                    let segments = content.pages.flatMap { $0.segments }
                    let current = service.store.document(id: id) ?? doc
                    DispatchQueue.global(qos: .userInitiated).async {
                        let out = AnnotationReanchoring.reanchor(
                            bookmarks: current.bookmarks ?? [], underlines: current.underlines ?? [],
                            readingPosition: current.readingPosition, readingAnchor: current.readingAnchor,
                            in: ContentAnchorIndex(segments: segments))
                        DispatchQueue.main.async {
                            service.store.applyAnnotationState(
                                documentId: id, bookmarks: out.bookmarks, underlines: out.underlines,
                                readingPosition: out.readingPosition, readingAnchor: out.readingAnchor,
                                readingPositionIsApproximate: out.readingPositionIsApproximate ? true : nil)
                            let result = ReprocessResultViewController(documentId: id, report: out.report,
                                                                       positionApproximate: out.readingPositionIsApproximate) {
                                onDone(out.report)
                            }
                            presenter.present(UINavigationController(rootViewController: result), animated: Motion.animated())
                        }
                    }
                case .cancelled:
                    if let snap = service.restorePreviousCache(forDocumentId: id) { service.store.restore(snap, documentId: id) }
                    UIAccessibility.post(notification: .announcement, argument: "Rielaborazione annullata. Il libro è rimasto com'era.")
                    onDone(nil)
                case .failure(let message):
                    if let snap = service.restorePreviousCache(forDocumentId: id) { service.store.restore(snap, documentId: id) }
                    DocumentOpener.presentError(message + " Il libro è rimasto com'era.", from: presenter)
                    onDone(nil)
                }
            }
        }
        presenter.present(vc, animated: Motion.animated())
    }

    /// Testo dell'esito, in parole semplici.
    static func resultText(_ r: ReanchorReport, positionApproximate: Bool) -> String {
        var lines: [String] = ["Il libro è stato rielaborato."]
        let bTotal = r.bookmarksRelocated + r.bookmarksOrphaned + r.bookmarksWithoutAnchor
        let uTotal = r.underlinesRelocated + r.underlinesOrphaned + r.underlinesWithoutAnchor
        if bTotal > 0 {
            let lost = r.bookmarksOrphaned + r.bookmarksWithoutAnchor
            lines.append(lost == 0
                ? "Tutti i segnalibri sono al loro posto (\(bTotal))."
                : "Segnalibri al loro posto: \(r.bookmarksRelocated) su \(bTotal). Da ricollocare: \(lost); li trovi in fondo alla lista dei segnalibri, e il salto porta all'inizio della pagina da cui venivano.")
        }
        if uTotal > 0 {
            let lost = r.underlinesOrphaned + r.underlinesWithoutAnchor
            lines.append(lost == 0
                ? "Tutte le sottolineature sono al loro posto (\(uTotal))."
                : "Sottolineature al loro posto: \(r.underlinesRelocated) su \(uTotal). \(lost) non sono state ritrovate: restano salvate ma non si vedono; tornando alla lettura precedente riappaiono.")
        }
        lines.append(positionApproximate
            ? "Il punto in cui eri arrivato non è stato ritrovato con sicurezza: riaprendo il libro partirai dall'inizio della stessa pagina."
            : "Il punto in cui eri arrivato è stato ritrovato.")
        lines.append("Puoi tenere la nuova lettura oppure tornare a quella di prima. Se non decidi adesso, la scelta resta disponibile fra le opzioni del libro.")
        return lines.joined(separator: " ")
    }
}

// MARK: - Schermata a testo con pulsanti (base comune, accessibile)

class ReprocessTextViewController: UIViewController {
    let stack = UIStackView()
    private let scroll = UIScrollView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        scroll.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.readableContentGuide.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.readableContentGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -20),
            stack.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor),
        ])
    }

    @discardableResult
    func addHeading(_ text: String) -> UILabel {
        let l = label(text, style: .title2)
        l.accessibilityTraits.insert(.header)
        stack.addArrangedSubview(l)
        return l
    }

    func addParagraph(_ text: String, identifier: String? = nil) {
        let l = label(text, style: .body)
        l.accessibilityIdentifier = identifier
        stack.addArrangedSubview(l)
    }

    @discardableResult
    func addButton(_ title: String, prominent: Bool, identifier: String, action: @escaping () -> Void) -> UIButton {
        var config: UIButton.Configuration = prominent ? .filled() : .bordered()
        config.title = title
        config.buttonSize = .large
        let b = UIButton(configuration: config, primaryAction: UIAction { _ in action() })
        b.accessibilityIdentifier = identifier
        b.titleLabel?.adjustsFontForContentSizeCategory = true
        b.heightAnchor.constraint(greaterThanOrEqualToConstant: 50).isActive = true
        stack.addArrangedSubview(b)
        return b
    }

    private func label(_ text: String, style: UIFont.TextStyle) -> UILabel {
        let l = UILabel()
        l.text = text
        l.numberOfLines = 0
        l.font = .preferredFont(forTextStyle: style)
        l.adjustsFontForContentSizeCategory = true
        return l
    }
}

// MARK: - L'offerta

final class ReprocessOfferViewController: ReprocessTextViewController {
    private let document: ArchivedDocument
    private let reason: ReprocessingReason
    private let onDone: () -> Void
    private var heading: UILabel?

    init(document: ArchivedDocument, reason: ReprocessingReason, onDone: @escaping () -> Void) {
        self.document = document
        self.reason = reason
        self.onDone = onDone
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) non supportato.") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Lettura migliore"
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Chiudi", primaryAction: UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        })
        heading = addHeading("Rielaborare «\(document.title)»?")
        addParagraph("Cosa cambia. " + ReprocessOffer.whatChanges(document, reason: reason), identifier: "offer.what")
        addParagraph("Quanto tempo serve. " + ReprocessOffer.howLong(document), identifier: "offer.time")
        addParagraph("Le tue annotazioni. " + ReprocessOffer.annotationsText(document), identifier: "offer.annotations")
        addButton("Rielabora…", prominent: true, identifier: "offer.accept") { [weak self] in self?.askConfirmation() }
        addButton("Non ora", prominent: false, identifier: "offer.decline") { [weak self] in self?.dismiss(animated: true) }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Il fuoco parte dal titolo: si ascolta prima la domanda, mai il pulsante.
        UIAccessibility.post(notification: .screenChanged, argument: heading)
    }

    /// Secondo gesto, distinto: una schermata di conferma con «Annulla» per primo e in evidenza.
    private func askConfirmation() {
        ReprocessConfirmViewController.present(
            from: self, identifier: "confirm.reprocess",
            question: "Confermi la rielaborazione?",
            explanation: "«\(document.title)» verrà letto di nuovo. La lettura di adesso resta sul dispositivo finché non confermi quella nuova.",
            actionTitle: "Rielabora") { [weak self] in self?.start() }
    }

    private func start() {
        guard let presenter = presentingViewController else { return }
        let id = document.id
        let onDone = self.onDone
        dismiss(animated: true) {
            ReprocessOffer.run(documentId: id, from: presenter) { _ in onDone() }
        }
    }
}

// MARK: - La conferma (secondo gesto)

/// Conferma d'una scelta che conta: domanda, spiegazione, «Annulla» per primo e in evidenza, poi l'azione.
/// Schermata dell'app (non un avviso di sistema) per avere il testo grande pieno e l'audit d'accessibilità.
final class ReprocessConfirmViewController: ReprocessTextViewController {
    private let question: String
    private let explanation: String
    private let actionTitle: String
    private let identifier: String
    private let onConfirm: () -> Void
    private var heading: UILabel?

    static func present(from presenter: UIViewController, identifier: String, question: String, explanation: String,
                        actionTitle: String, onConfirm: @escaping () -> Void) {
        let vc = ReprocessConfirmViewController(identifier: identifier, question: question, explanation: explanation,
                                                actionTitle: actionTitle, onConfirm: onConfirm)
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .formSheet
        presenter.present(nav, animated: Motion.animated())
    }

    private init(identifier: String, question: String, explanation: String, actionTitle: String, onConfirm: @escaping () -> Void) {
        self.identifier = identifier
        self.question = question
        self.explanation = explanation
        self.actionTitle = actionTitle
        self.onConfirm = onConfirm
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) non supportato.") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Conferma"
        heading = addHeading(question)
        addParagraph(explanation, identifier: "\(identifier).text")
        addButton("Annulla", prominent: true, identifier: "\(identifier).cancel") { [weak self] in self?.dismiss(animated: true) }
        addButton(actionTitle, prominent: false, identifier: "\(identifier).ok") { [weak self] in
            guard let self else { return }
            let onConfirm = self.onConfirm
            self.dismiss(animated: true) { onConfirm() }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIAccessibility.post(notification: .screenChanged, argument: heading)
    }
}

// MARK: - L'esito

final class ReprocessResultViewController: ReprocessTextViewController {
    private let documentId: String
    private let report: ReanchorReport
    private let positionApproximate: Bool
    private let onDone: () -> Void
    private var heading: UILabel?

    init(documentId: String, report: ReanchorReport, positionApproximate: Bool, onDone: @escaping () -> Void) {
        self.documentId = documentId
        self.report = report
        self.positionApproximate = positionApproximate
        self.onDone = onDone
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) non supportato.") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Rielaborazione"
        heading = addHeading("Rielaborazione conclusa")
        addParagraph(ReprocessOffer.resultText(report, positionApproximate: positionApproximate), identifier: "result.text")
        addButton("Tieni la nuova lettura", prominent: true, identifier: "result.keep") { [weak self] in
            guard let self else { return }
            ReprocessOffer.askToKeepNewReading(self.documentId, from: self) { [weak self] in self?.close() }
        }
        addButton("Torna alla lettura precedente", prominent: false, identifier: "result.revert") { [weak self] in
            guard let self else { return }
            ReprocessOffer.revertToPrevious(self.documentId); self.close()
        }
        addButton("Decidi più tardi", prominent: false, identifier: "result.later") { [weak self] in self?.close() }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIAccessibility.post(notification: .screenChanged, argument: heading)
    }

    private func close() {
        let onDone = self.onDone
        dismiss(animated: true) { onDone() }
    }
}

// MARK: - L'elenco dei libri (dalla Home)

final class ReprocessListViewController: UITableViewController {
    private var eligible: [ArchivedDocument] = []
    private var pending: [ArchivedDocument] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Lettura migliore"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        reload()
    }

    private func reload() {
        pending = ReprocessOffer.pendingConfirmation()
        let pendingIds = Set(pending.map { $0.id })
        eligible = ReprocessOffer.eligibleDocuments().filter { !pendingIds.contains($0.id) }
        tableView.reloadData()
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 2 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? max(eligible.count, 1) : pending.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 0 ? "Libri che si possono rielaborare" : (pending.isEmpty ? nil : "Rielaborati, in attesa di conferma")
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        section == 0
            ? "Ogni libro si rielabora solo se lo scegli tu, uno alla volta. Tocca un libro per sapere cosa cambia."
            : nil
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var config = cell.defaultContentConfiguration()
        config.textProperties.numberOfLines = 0
        config.secondaryTextProperties.numberOfLines = 0
        if indexPath.section == 0 {
            if eligible.isEmpty {
                config.text = "Nessun libro da rielaborare."
                cell.accessoryType = .none
                cell.selectionStyle = .none
            } else {
                let d = eligible[indexPath.row]
                config.text = d.title
                config.secondaryText = "\(d.sourcePageCount) pagine"
                cell.accessoryType = .disclosureIndicator
                cell.accessibilityHint = "Apre la spiegazione: niente parte senza la tua conferma."
            }
        } else {
            let d = pending[indexPath.row]
            config.text = d.title
            config.secondaryText = "Da confermare: tieni la nuova lettura o torna a quella di prima."
            cell.accessoryType = .disclosureIndicator
        }
        cell.contentConfiguration = config
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        if indexPath.section == 0 {
            guard !eligible.isEmpty else { return }
            ReprocessOffer.presentOffer(for: eligible[indexPath.row], from: self) { [weak self] in self?.reload() }
        } else {
            ReprocessOffer.presentPendingChoice(for: pending[indexPath.row], from: self) { [weak self] in self?.reload() }
        }
    }
}
