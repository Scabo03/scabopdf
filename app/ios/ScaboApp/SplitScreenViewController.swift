//
//  SplitScreenViewController.swift
//  ScaboApp
//
//  Lo split screen (§ 11), SOLO iPad. Compone due `ContinuousReadingViewController` EMBEDDED (riuso
//  pieno dell'impianto reading per ciascuna metà), la barra di split in cima e la linea di divisione,
//  e coordina i CINQUE-SEI container di accessibilità autonomi e chiusi (§ 11.2 / § 2.3): testo A,
//  barra A, barra di split, barra B, testo B, linea.
//
//  ── Container e sigillo (§ 2.3 inderogabile + § 11.6 + § 11.8) ───────────────────────────────────
//
//  Si generalizza il sigillo provato del full-screen: UN SOLO container attivo esposto nel radice +
//  `accessibilityViewIsModal`, così lo swipe orizzontale resta ISOLA dentro il container (§ 2.3, mai
//  scavalca). Lo SCRUB a due dita cicla fra i sei container (§ 11.8). La metà il cui container è
//  attivo COMANDA (§ 11.6): il fuoco VoiceOver unico risolve da sé chi guida. (Il tocco diretto
//  sull'altra metà è soggetto al sigillo modale; lo scrub è la via garantita — resta collaudo device
//  come lo fu il sigillo full-screen ai build 3-5.)
//
//  ── Regimi (§ 11.4 / § 11.5) ────────────────────────────────────────────────────────────────────
//
//  Al cambio posizione della metà-guida, se il regime non è autonomo, la metà che segue si ALLINEA
//  VISIVAMENTE (scroll, senza rubare il fuoco alla guida): assoluto = stesso indice; segui-pagina =
//  stessa pagina; segui-livello = stessa unità strutturale. La logica pura è in `ScaboCore.SplitSync`.
//
//  Memoria (cancello misurativo §): ciascuna metà eredita la politica coarse per i volumi enormi
//  (build 23), così due viste vive restano nel budget (vedi la sonda `SplitMemoryProbeTests`).
//
//  ── Tastiera (WCAG 2.1.1 e 2.1.2, giro «accessibilità e completamento», 2026-10-18) ──────────────
//
//  Fino alla build 58 nello split i comandi da tastiera non funzionavano: ciascuna metà è un lettore EMBEDDED, che non
//  diventa primo destinatario dei tasti. Ora il primo destinatario è lo split: i comandi di lettura del catalogo vanno alla
//  metà che COMANDA (§ 11.6: quella del container attivo; dalla barra di split o dalla linea, l'ultima che ha comandato),
//  e due comandi scelgono la metà (⌥⌘← / ⌥⌘→), portando lì anche il fuoco di VoiceOver. Esc chiede se chiudere la metà che
//  comanda (come il suo «Indietro»): nella domanda Esc annulla e A capo chiude — li governa lo split, che resta il
//  destinatario dei tasti — quindi dallo split si esce con la sola tastiera (nessuna trappola del fuoco). Con una schermata
//  sopra lo split che non sia la sua domanda da tastiera, lo split non prende tasti.
//

import UIKit
import ScaboCore

/// La linea verticale di divisione (§ 11.7): elemento di accessibilità percettibile e container
/// autonomo; lo scrub la fa uscire verso il container successivo.
final class SplitDivider: UIView {
    var onEscape: (() -> Void)?
    override func accessibilityPerformEscape() -> Bool {
        guard let onEscape else { return false }
        onEscape(); return true
    }
}

final class SplitScreenViewController: UIViewController {

    private var split: SplitState
    private let leftVC: ContinuousReadingViewController
    private let rightVC: ContinuousReadingViewController
    private let splitBar = SplitBar()
    private let dividerView = SplitDivider()

    /// Chiamato quando si esce dallo split chiudendo una metà (§ 11.1): riceve l'id della metà che
    /// RESTA, che il presentatore riapre a schermo intero. `nil`-safe.
    private let onExitKeeping: (String) -> Void

    private var store: LibraryStore { LibraryService.shared.store }

    /// Ciclo di scrub fra i sei container (§ 11.8). Indice del container attivo.
    private var activeIndex = 0
    /// La metà che comanda i tasti quando il container attivo è la barra di split o la linea (§ 11.6).
    private var lastCommandingSide: SplitSide = .left
    private var isSyncing = false
    private var lastLeaderIndex: [SplitSide: Int] = [:]

    /// Ripristino dopo interruzione di sistema (bug 1), PER-CONTAINER: alla ripresa si ripristina il
    /// container ATTIVO (non sempre testo A, § 2.3). La posizione di ciascuna metà è fotografata alla
    /// sospensione (il reset di VoiceOver la azzera nel mezzo). Osservatori rimossi in deinit.
    private var willResignObserver: NSObjectProtocol?
    private var didBecomeActiveObserver: NSObjectProtocol?
    private var snapshotBySide: [SplitSide: Int] = [:]

    private static let barHeight: CGFloat = 44
    private static let dividerWidth: CGFloat = 8

    // MARK: - Costruzione

    /// Carica le due metà (cache o rielaborazione, politica coarse per i volumi enormi) e presenta lo
    /// split a schermo intero. `restoring` ripristina un regime/linea persistiti (§ 11.9), altrimenti
    /// parte in autonomia con la linea al centro.
    static func present(
        leftDocumentId: String, rightDocumentId: String, restoring: SplitState?,
        from presenter: UIViewController, onExitKeeping: @escaping (String) -> Void
    ) {
        guard UIDevice.current.userInterfaceIdiom == .pad else { return }  // § 11.1: solo iPad
        var pendingLeft: ContinuousReadingViewController?
        var pendingRight: ContinuousReadingViewController?

        func compose() {
            guard let left = pendingLeft, let right = pendingRight else {
                DocumentOpener.presentError("Impossibile aprire lo split: un documento non è disponibile.",
                                            from: presenter)
                return
            }
            let state = restoring ?? SplitState(leftDocumentId: leftDocumentId, rightDocumentId: rightDocumentId)
            let vc = SplitScreenViewController(
                split: state, left: left, right: right, onExitKeeping: onExitKeeping)
            vc.modalPresentationStyle = .fullScreen
            DocumentOpener.presentRobustly(vc, from: presenter)
        }

        // Carica prima sinistra, poi destra (una rielaborazione presenta un modale bloccante).
        DocumentOpener.loadEmbeddedHalf(
            documentId: leftDocumentId, from: presenter,
            onPositionChanged: { _ in }  // ricablato dal VC dopo la composizione
        ) { left in
            pendingLeft = left
            DocumentOpener.loadEmbeddedHalf(
                documentId: rightDocumentId, from: presenter,
                onPositionChanged: { _ in }
            ) { right in
                pendingRight = right
                compose()
            }
        }
    }

    private init(
        split: SplitState, left: ContinuousReadingViewController, right: ContinuousReadingViewController,
        onExitKeeping: @escaping (String) -> Void
    ) {
        self.split = split
        self.leftVC = left
        self.rightVC = right
        self.onExitKeeping = onExitKeeping
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) non supportato.") }

    // MARK: - Ciclo di vita

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        addChild(leftVC); view.addSubview(leftVC.view); leftVC.didMove(toParent: self)
        addChild(rightVC); view.addSubview(rightVC.view); rightVC.didMove(toParent: self)
        view.addSubview(splitBar)
        configureDivider()
        view.addSubview(dividerView)

        wireHalf(leftVC, side: .left)
        wireHalf(rightVC, side: .right)
        wireSplitBar()
        splitBar.configure(regime: split.regime, subRegime: split.subRegime)

        // Persistenza (§ 11.9): lo split è attivo → registralo per la riapertura.
        store.setSplitState(split)

        // Ripristino dopo interruzione di sistema (bug 1), nel container ATTIVO.
        willResignObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.snapshotForInterruption() }
        didBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.reassertAfterInterruption() }

        // All'ingresso comanda la metà sinistra: il suo testo è il container attivo.
        setActive(0)
    }

    deinit {
        for token in [willResignObserver, didBecomeActiveObserver] {
            if let token { NotificationCenter.default.removeObserver(token) }
        }
    }

    /// Fotografa la posizione di lettura di ENTRAMBE le metà prima di un'interruzione.
    private func snapshotForInterruption() {
        guard view.window != nil else { return }
        for side in [SplitSide.left, .right] {
            if let idx = childVC(side).currentReadingIndex, idx > 0 { snapshotBySide[side] = idx }
        }
    }

    /// Alla ripresa: riallinea lo scroll di entrambe le metà (VoiceOver-indipendente) e riporta il
    /// fuoco nel container ATTIVO (§ 2.3: quello giusto, non sempre testo A), col punto fotografato.
    private func reassertAfterInterruption() {
        guard isViewLoaded, view.window != nil else { return }
        for side in [SplitSide.left, .right] {
            if let idx = snapshotBySide[side], idx > 0 {
                childVC(side).textContainer.goToElement(atIndex: idx, focus: false)  // scroll + preset
            }
        }
        setActive(activeIndex)  // fuoco nel container attivo (ora al punto fotografato)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self, self.view.window != nil else { return }
            self.setActive(self.activeIndex)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let w = view.bounds.width, h = view.bounds.height
        let top = view.safeAreaInsets.top
        let barBottom = top + Self.barHeight
        splitBar.frame = CGRect(x: 0, y: top, width: w, height: Self.barHeight)
        let contentH = h - barBottom
        let leftW = (w * CGFloat(split.dividerFraction)).rounded()
        leftVC.view.frame = CGRect(x: 0, y: barBottom, width: leftW - Self.dividerWidth / 2, height: contentH)
        dividerView.frame = CGRect(x: leftW - Self.dividerWidth / 2, y: barBottom, width: Self.dividerWidth, height: contentH)
        rightVC.view.frame = CGRect(x: leftW + Self.dividerWidth / 2, y: barBottom,
                                    width: w - leftW - Self.dividerWidth / 2, height: contentH)
    }

    // MARK: - Container di accessibilità (§ 11.2 / § 2.3)

    /// I sei container nell'ordine di ciclo dello scrub (§ 11.8).
    private func orderedContainers() -> [NSObject] {
        [leftVC.textContainer, leftVC.barContainer, splitBar, rightVC.barContainer, rightVC.textContainer, dividerView]
    }

    /// Rende attivo il container di indice `i`: il radice espone SOLO quello (sigillo § 2.3), con la
    /// modalità come rinforzo, e vi porta il fuoco. Aggiorna l'indicatore della metà comandante.
    private func setActive(_ i: Int) {
        let containers = orderedContainers()
        guard i >= 0, i < containers.count else { return }
        activeIndex = i
        if let side = Self.side(ofContainerAt: i) { lastCommandingSide = side }
        view.accessibilityElements = [containers[i]]
        for (j, c) in containers.enumerated() {
            (c as? UIView)?.accessibilityViewIsModal = (j == i)
        }
        UIAccessibility.post(notification: .screenChanged, argument: focusTarget(for: containers[i]))
    }

    private func focusTarget(for container: NSObject) -> Any {
        if let text = container as? ContinuousReadingView {
            return text.lastFocusedTextElement ?? text.element(atIndex: 0) ?? text
        }
        return container
    }

    private func advanceActive() {
        setActive((activeIndex + 1) % orderedContainers().count)
    }

    /// La metà di un container del ciclo (testo e barra di una metà), o `nil` per la barra di split e la linea.
    static func side(ofContainerAt index: Int) -> SplitSide? {
        switch index {
        case 0, 1: return .left
        case 3, 4: return .right
        default: return nil
        }
    }

    /// La metà che comanda adesso: quella del container attivo, o l'ultima che ha comandato.
    var commandingSide: SplitSide { Self.side(ofContainerAt: activeIndex) ?? lastCommandingSide }

    // MARK: - Tastiera (WCAG 2.1.1 / 2.1.2)

    override var canBecomeFirstResponder: Bool { true }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
    }

    /// La domanda «Chiudi metà …» aperta da tastiera, e la chiusura che A capo conferma.
    private var keyboardQuestion: (alert: UIAlertController, close: () -> Void)?

    override var keyCommands: [UIKeyCommand]? {
        // Con la domanda da tastiera aperta i tasti dello split sono soltanto A capo («Chiudi») ed Esc («Annulla»): li
        // governa lo split, che resta il destinatario dei tasti, perché nel simulatore A capo arrivava alla domanda solo a
        // volte (misurato nel giro: 2 volte su 3 nel caso migliore). Con un'altra schermata sopra, nessun comando
        // (misurato: senza questa guardia Esc rifaceva «Indietro» invece di annullare la domanda).
        if let question = keyboardQuestion, presentedViewController === question.alert {
            let close = UIKeyCommand(input: "\r", modifierFlags: [], action: #selector(keyboardQuestionClose))
            let cancel = UIKeyCommand(input: UIKeyCommand.inputEscape, modifierFlags: [], action: #selector(keyboardQuestionCancel))
            for command in [close, cancel] { command.wantsPriorityOverSystemBehavior = true }
            return [close, cancel]
        }
        guard presentedViewController == nil else { return [] }
        let reading = KeyboardCommandsCatalog.reading.flatMap { spec in
            spec.makeKeyCommands(action: #selector(readingKeyCommand(_:)), propertyList: spec.id)
        }
        let own = KeyboardCommandsCatalog.split.flatMap { spec in
            spec.makeKeyCommands(action: #selector(splitKeyCommand(_:)), propertyList: spec.id)
        }
        return reading + own
    }

    /// Un comando di lettura: alla metà che comanda.
    @objc private func readingKeyCommand(_ command: UIKeyCommand) {
        guard let id = command.propertyList as? String else { return }
        // Esc = «Indietro» della metà che comanda: la domanda, nella forma da tastiera (A capo chiude).
        if id == "back" {
            confirmClose(keeping: commandingSide.other, fromKeyboard: true)
            return
        }
        childVC(commandingSide).performKeyboardCommand(id: id)
    }

    /// La scelta della metà: il suo testo diventa il container attivo (e lì va il fuoco di VoiceOver).
    @objc private func splitKeyCommand(_ command: UIKeyCommand) {
        guard let id = command.propertyList as? String else { return }
        switch id {
        case "splitLeft": selectCommandingSide(.left)
        case "splitRight": selectCommandingSide(.right)
        default: break
        }
    }

    /// A capo nella domanda da tastiera: «Chiudi».
    @objc private func keyboardQuestionClose() {
        guard let question = keyboardQuestion else { return }
        keyboardQuestion = nil
        question.alert.dismiss(animated: true) { question.close() }
    }

    /// Esc nella domanda da tastiera: «Annulla».
    @objc private func keyboardQuestionCancel() {
        guard let question = keyboardQuestion else { return }
        keyboardQuestion = nil
        question.alert.dismiss(animated: true) { [weak self] in self?.becomeFirstResponder() }
    }

    func selectCommandingSide(_ side: SplitSide) {
        setActive(side == .left ? 0 : 4)
        UIAccessibility.post(notification: .announcement, argument: side == .left ? "Metà sinistra" : "Metà destra")
    }

    private func wireHalf(_ vc: ContinuousReadingViewController, side: SplitSide) {
        // Lo scrub da testo/barra della metà passa al container successivo del ciclo (§ 11.8).
        vc.textContainer.onEscape = { [weak self] in self?.advanceActive() }
        vc.barContainer.onEscape = { [weak self] in self?.advanceActive() }
        // "Indietro" della barra della metà = chiudi QUESTA metà (§ 11.1/§ 11.3), come la sua X.
        vc.onBack = { [weak self] in self?.confirmClose(keeping: side.other) }
        // Cambio posizione della metà (quando è la guida): sincronizza l'altra secondo il regime.
        // Si usa l'hook DEDICATO del VC embedded (NON si sovrascrive `textContainer.
        // onReadingPositionChanged`, che il VC usa per la propria persistenza/ancora/indicatore,
        // § 11.9): così la metà continua a SALVARE la propria posizione mentre lo split la sincronizza.
        vc.onEmbeddedReadingPositionChanged = { [weak self] index in
            self?.leaderMoved(side: side, index: index)
        }
    }

    private func wireSplitBar() {
        splitBar.onEscape = { [weak self] in self?.advanceActive() }
        dividerView.onEscape = { [weak self] in self?.advanceActive() }
        splitBar.onCloseLeft = { [weak self] in self?.confirmClose(keeping: .right) }
        splitBar.onCloseRight = { [weak self] in self?.confirmClose(keeping: .left) }
        splitBar.onSelectRegime = { [weak self] r in self?.selectRegime(r) }
        splitBar.onSelectSubRegime = { [weak self] s in self?.selectSubRegime(s) }
        splitBar.onMoveDivider = { [weak self] side in self?.moveDivider(towards: side) }
    }

    // MARK: - Regimi (§ 11.4 / § 11.5)

    private func selectRegime(_ regime: ParallelizationRegime) {
        split.regime = regime
        splitBar.configure(regime: split.regime, subRegime: split.subRegime)
        store.setSplitState(split)
    }

    private func selectSubRegime(_ sub: LinkSubRegime) {
        split.subRegime = sub
        splitBar.configure(regime: split.regime, subRegime: split.subRegime)
        store.setSplitState(split)
    }

    /// La metà-guida si è mossa: allinea la metà che segue (allineamento VISIVO, il fuoco resta sulla
    /// guida — § 11.4). `leaderMoved` fa da `onReadingPositionChanged` della metà attiva.
    private func leaderMoved(side: SplitSide, index: Int) {
        defer { lastLeaderIndex[side] = index }
        guard !isSyncing, split.regime != .autonomous else { return }
        let leader = childVC(side).textContainer
        let follower = childVC(side.other).textContainer
        isSyncing = true
        defer { isSyncing = false }

        switch split.regime {
        case .autonomous:
            break
        case .absolute:
            if let target = SplitSync.followerIndexAbsolute(
                leaderIndex: index, followerElementCount: follower.elementCount) {
                follower.revealElement(atIndex: target)
            }
        case .partial:
            let before = lastLeaderIndex[side] ?? index
            switch split.subRegime {
            case .followPage:
                if let pBefore = leader.visualPageIndex(ofElementAt: before),
                   let pAfter = leader.visualPageIndex(ofElementAt: index),
                   let targetPage = SplitSync.followerPageFollowPage(
                    leaderPageBefore: pBefore, leaderPageAfter: pAfter, followerPageCount: follower.visualPageCount),
                   let fIdx = follower.firstElementIndex(ofVisualPage: targetPage) {
                    follower.revealElement(atIndex: fIdx)
                }
            case .followLevel:
                let uBefore = leader.structuralUnitIndex(ofElementAt: before)
                let uAfter = leader.structuralUnitIndex(ofElementAt: index)
                let fCur = follower.currentReadingElementIndex
                    .map { follower.structuralUnitIndex(ofElementAt: $0) } ?? 0
                if let targetUnit = SplitSync.followerUnitFollowLevel(
                    leaderUnitBefore: uBefore, leaderUnitAfter: uAfter,
                    followerUnitCurrent: fCur, followerUnitCount: follower.structuralUnitCount),
                   let fIdx = follower.firstElementIndex(ofUnit: targetUnit) {
                    follower.revealElement(atIndex: fIdx)
                }
            }
        }
    }

    private func childVC(_ side: SplitSide) -> ContinuousReadingViewController {
        side == .left ? leftVC : rightVC
    }

    // MARK: - Linea di divisione (§ 11.7)

    private func configureDivider() {
        dividerView.backgroundColor = .separator
        dividerView.isAccessibilityElement = true
        dividerView.accessibilityLabel = "Linea di divisione"
        updateDividerValue()
    }

    private func updateDividerValue() {
        let pct = Int((split.dividerFraction * 100).rounded())
        dividerView.accessibilityValue = "sinistra \(pct) per cento"
    }

    private func moveDivider(towards side: SplitSide) {
        split = split.movingDivider(towards: side)
        updateDividerValue()
        view.setNeedsLayout()
        store.setSplitState(split)
    }

    // MARK: - Uscita (§ 11.1): chiudi una metà, l'altra torna a schermo intero

    /// `fromKeyboard`: la domanda nasce da Esc. Allora «Chiudi» è l'azione preferita, in evidenza, e A capo la sceglie
    /// (lo governa lo split: `keyCommands`); ha lo stile normale, perché il sistema non tratta come scelta di A capo
    /// un'azione distruttiva (misurato nel giro). Dalla X o da «Indietro» la domanda resta com'era: «Chiudi» rossa.
    private func confirmClose(keeping keptSide: SplitSide, fromKeyboard: Bool = false) {
        let keptTitle = keptSide == .left ? "sinistra" : "destra"
        let closedTitle = keptSide == .left ? "destra" : "sinistra"
        let alert = UIAlertController(
            title: "Chiudi metà \(closedTitle)",
            message: "La metà \(closedTitle) sarà chiusa; la metà \(keptTitle) tornerà a schermo intero.",
            preferredStyle: .alert)
        let closeHalf: () -> Void = { [weak self] in
            guard let self else { return }
            let survivor = self.split.documentId(on: keptSide)
            self.store.setSplitState(nil)  // § 11.9: niente più split da ripristinare.
            self.onExitKeeping(survivor)
        }
        alert.addAction(UIAlertAction(title: "Annulla", style: .cancel) { [weak self] _ in
            self?.keyboardQuestion = nil
            self?.becomeFirstResponder()   // di nuovo i comandi da tastiera dello split
        })
        let close = UIAlertAction(title: "Chiudi", style: fromKeyboard ? .default : .destructive) { [weak self] _ in
            self?.keyboardQuestion = nil
            closeHalf()
        }
        alert.addAction(close)
        // Da tastiera: Esc annulla, A capo chiude (li governa lo split, `keyCommands`): si esce dallo split senza toccare
        // lo schermo.
        if fromKeyboard {
            alert.preferredAction = close
            keyboardQuestion = (alert, closeHalf)
        }
        present(alert, animated: true)
    }

    // MARK: - Introspezione per i test

    /// Costruttore per i test (senza il caricamento asincrono delle metà).
    static func makeForTesting(
        left: ContinuousReadingViewController, right: ContinuousReadingViewController, split: SplitState
    ) -> SplitScreenViewController {
        SplitScreenViewController(split: split, left: left, right: right, onExitKeeping: { _ in })
    }

    var splitStateForTesting: SplitState { split }
    var activeContainerIndexForTesting: Int { activeIndex }
    var commandingSideForTesting: SplitSide { commandingSide }
    var orderedContainerCountForTesting: Int { orderedContainers().count }
    func advanceActiveForTesting() { advanceActive() }
    func selectRegimeForTesting(_ r: ParallelizationRegime) { selectRegime(r) }
    func moveDividerForTesting(towards side: SplitSide) { moveDivider(towards: side) }
}
