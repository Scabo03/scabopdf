//
//  UnderlineSelectionViewController.swift
//  ScaboApp
//
//  La finestra di selezione a due fasi per creare/modificare una sottolineatura (§ 6.2). Strumento
//  SOLO-VEDENTI: l'interazione è a TAP diretto sulle parole (non c'è la doppia via VoiceOver, § 6 è
//  stato ridotto a solo-visivo/solo-vedenti). È un container modale (§ 2.3, § 3.2) con i due pulsanti
//  Conferma e Annulla; alla chiusura il focus torna alla reading view.
//
//  ── Le due fasi (§ 6.2) ─────────────────────────────────────────────────────────────────────────
//
//  Fase 1 — scelta della parola d'INIZIO: in cima l'ancoraggio (prime parole del blocco corrente),
//  sotto le parole del blocco come chip tappabili; il tap sceglie l'inizio. Fase 2 — scelta della
//  parola di FINE: compaiono le frecce `<`/`>` per scorrere ai blocchi consecutivi (estensione
//  multi-blocco), il tap sceglie la fine. **Conferma senza scegliere la fine = una sola parola**
//  (§ 6.2, chiusura a metà). Le parole già coperte da altre sottolineature sono **bloccate** (§ 6.3,
//  non selezionabili). Se la selezione finale si sovrappone comunque a una esistente (attraversandola),
//  `onCommit` la rifiuta e la finestra resta aperta con un avviso — rete di sicurezza sulla
//  non-sovrapposizione (§ 6.3).
//
//  La tokenizzazione in parole è `WordTokenizer` (ScaboCore), la STESSA usata dalla resa grafica e
//  dagli indici di span: così la parola toccata qui e il glifo sottolineato a schermo coincidono.
//

import UIKit
import ScaboCore

final class UnderlineSelectionViewController: UIViewController {

    /// Esito del commit: `true` = registrata (chiudi), `false` = rifiutata (resta aperta con avviso).
    typealias CommitHandler = (_ spans: [UnderlineSpan], _ preview: String) -> Bool

    private let segments: [ContentSegment]
    private let startIndex: Int
    private let blockedIntervals: (String) -> [ClosedRange<Int>]
    private let onCommit: CommitHandler

    private enum Phase { case selectingStart, selectingEnd }
    private var phase: Phase = .selectingStart
    private var currentBlock: Int
    private var selectedStart: (block: Int, word: Int)?
    private var selectedEnd: (block: Int, word: Int)?

    private let instructionLabel = UILabel()
    private let anchorLabel = UILabel()
    private let prevButton = UIButton(type: .system)
    private let nextButton = UIButton(type: .system)
    private let chipsScroll = UIScrollView()
    private let chips = WordChipsView()

    static func present(
        from presenter: UIViewController,
        segments: [ContentSegment],
        startIndex: Int,
        blockedIntervals: @escaping (String) -> [ClosedRange<Int>],
        onCommit: @escaping CommitHandler
    ) {
        let vc = UnderlineSelectionViewController(
            segments: segments, startIndex: startIndex,
            blockedIntervals: blockedIntervals, onCommit: onCommit)
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .formSheet
        presenter.present(nav, animated: true)
    }

    private init(
        segments: [ContentSegment], startIndex: Int,
        blockedIntervals: @escaping (String) -> [ClosedRange<Int>], onCommit: @escaping CommitHandler
    ) {
        self.segments = segments
        self.startIndex = startIndex
        self.currentBlock = startIndex
        self.blockedIntervals = blockedIntervals
        self.onCommit = onCommit
        super.init(nibName: nil, bundle: nil)
        self.title = "Sottolinea"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) non supportato.") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Annulla", style: .plain, target: self, action: #selector(cancelTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Conferma", style: .done, target: self, action: #selector(confirmTapped))
        navigationItem.rightBarButtonItem?.isEnabled = false

        instructionLabel.font = .preferredFont(forTextStyle: .subheadline)
        instructionLabel.adjustsFontForContentSizeCategory = true
        instructionLabel.textColor = .secondaryLabel
        instructionLabel.numberOfLines = 0

        anchorLabel.font = .preferredFont(forTextStyle: .headline)
        anchorLabel.adjustsFontForContentSizeCategory = true
        anchorLabel.numberOfLines = 2

        prevButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        prevButton.accessibilityLabel = "Blocco precedente"
        prevButton.addTarget(self, action: #selector(prevBlock), for: .touchUpInside)
        nextButton.setImage(UIImage(systemName: "chevron.right"), for: .normal)
        nextButton.accessibilityLabel = "Blocco successivo"
        nextButton.addTarget(self, action: #selector(nextBlock), for: .touchUpInside)

        let arrows = UIStackView(arrangedSubviews: [prevButton, nextButton])
        arrows.axis = .horizontal
        arrows.spacing = 24
        arrows.isHidden = true  // compaiono in fase 2 (§ 6.2)

        let anchorRow = UIStackView(arrangedSubviews: [anchorLabel, UIView(), arrows])
        anchorRow.axis = .horizontal
        anchorRow.alignment = .center
        anchorRow.spacing = 8

        chips.onTapWord = { [weak self] index in self?.tapWord(index) }
        chips.translatesAutoresizingMaskIntoConstraints = false
        chipsScroll.translatesAutoresizingMaskIntoConstraints = false
        chipsScroll.addSubview(chips)

        let stack = UIStackView(arrangedSubviews: [instructionLabel, anchorRow])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        view.addSubview(chipsScroll)

        self.arrowsStack = arrows

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            chipsScroll.topAnchor.constraint(equalTo: stack.bottomAnchor, constant: 12),
            chipsScroll.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            chipsScroll.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            chipsScroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),

            chips.topAnchor.constraint(equalTo: chipsScroll.contentLayoutGuide.topAnchor),
            chips.leadingAnchor.constraint(equalTo: chipsScroll.contentLayoutGuide.leadingAnchor),
            chips.trailingAnchor.constraint(equalTo: chipsScroll.contentLayoutGuide.trailingAnchor),
            chips.bottomAnchor.constraint(equalTo: chipsScroll.contentLayoutGuide.bottomAnchor),
            chips.widthAnchor.constraint(equalTo: chipsScroll.frameLayoutGuide.widthAnchor),
        ])

        reloadBlock()
    }

    private weak var arrowsStack: UIStackView?

    // MARK: - Fasi e selezione

    private func reloadBlock() {
        guard currentBlock >= 0, currentBlock < segments.count else { return }
        let segment = segments[currentBlock]
        anchorLabel.text = WordTokenizer.preview(segment.text, limit: 10)
        instructionLabel.text = phase == .selectingStart
            ? "Tocca la parola da cui iniziare la sottolineatura."
            : "Tocca la parola di fine, o premi Conferma per sottolineare una sola parola. Usa le frecce per estendere ad altri blocchi."
        arrowsStack?.isHidden = phase == .selectingStart
        prevButton.isEnabled = currentBlock > 0
        nextButton.isEnabled = currentBlock < segments.count - 1

        let words = WordTokenizer.words(segment.text)
        var blocked = Set<Int>()
        for interval in blockedIntervals(segment.id) {
            for i in interval where i >= 0 && i < words.count { blocked.insert(i) }
        }
        chips.configure(
            words: words, blocked: blocked,
            startWord: selectedStart.flatMap { $0.block == currentBlock ? $0.word : nil },
            endWord: selectedEnd.flatMap { $0.block == currentBlock ? $0.word : nil })
    }

    private func tapWord(_ index: Int) {
        switch phase {
        case .selectingStart:
            selectedStart = (currentBlock, index)
            phase = .selectingEnd
            navigationItem.rightBarButtonItem?.isEnabled = true  // Conferma = una parola (§ 6.2)
        case .selectingEnd:
            selectedEnd = (currentBlock, index)
        }
        reloadBlock()
    }

    @objc private func prevBlock() { currentBlock -= 1; reloadBlock() }
    @objc private func nextBlock() { currentBlock += 1; reloadBlock() }

    @objc private func cancelTapped() { dismiss(animated: true) }

    @objc private func confirmTapped() {
        guard let spans = computeSpans() else { return }
        let preview = computePreview(spans)
        if onCommit(spans, preview) {
            dismiss(animated: true)
        } else {
            let alert = UIAlertController(
                title: "Selezione non valida",
                message: "La selezione si sovrappone a una sottolineatura esistente. Scegli parole libere.",
                preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }

    // MARK: - Calcolo degli span

    private func computeSpans() -> [UnderlineSpan]? {
        guard let start = selectedStart else { return nil }
        let end = selectedEnd ?? start
        let lo = earlier(start, end)
        let hi = later(start, end)
        if lo.block == hi.block {
            return [UnderlineSpan(segmentId: segments[lo.block].id, startWord: lo.word, endWord: hi.word)]
        }
        var spans = [UnderlineSpan(
            segmentId: segments[lo.block].id, startWord: lo.word, endWord: lastWord(lo.block))]
        if lo.block + 1 <= hi.block - 1 {
            for b in (lo.block + 1)...(hi.block - 1) {
                spans.append(UnderlineSpan(segmentId: segments[b].id, startWord: 0, endWord: lastWord(b)))
            }
        }
        spans.append(UnderlineSpan(segmentId: segments[hi.block].id, startWord: 0, endWord: hi.word))
        return spans
    }

    private func computePreview(_ spans: [UnderlineSpan]) -> String {
        let byId = Dictionary(segments.map { ($0.id, $0.text) }, uniquingKeysWith: { a, _ in a })
        var pieces: [String] = []
        for span in spans {
            guard let text = byId[span.segmentId] else { continue }
            let words = WordTokenizer.words(text)
            let lo = max(0, span.startWord), hi = min(words.count - 1, span.endWord)
            if lo <= hi { pieces.append(words[lo...hi].joined(separator: " ")) }
        }
        return WordTokenizer.preview(pieces.joined(separator: " "), limit: 10)
    }

    private func lastWord(_ block: Int) -> Int {
        Swift.max(0, WordTokenizer.wordCount(segments[block].text) - 1)
    }

    /// La posizione (blocco, parola) che viene PRIMA nell'ordine di lettura.
    private func earlier(_ a: (block: Int, word: Int), _ b: (block: Int, word: Int)) -> (block: Int, word: Int) {
        (a.block, a.word) <= (b.block, b.word) ? a : b
    }

    /// La posizione (blocco, parola) che viene DOPO nell'ordine di lettura.
    private func later(_ a: (block: Int, word: Int), _ b: (block: Int, word: Int)) -> (block: Int, word: Int) {
        (a.block, a.word) > (b.block, b.word) ? a : b
    }
}

// MARK: - Griglia di parole tappabili (wrapping, auto-dimensionante)

/// Le parole di un blocco come chip tappabili disposte a capo. Le parole bloccate (§ 6.3) sono
/// disabilitate; inizio/fine selezionati sono evidenziati. Auto-dimensionante come `TagGridView`,
/// così vive dentro uno scroll senza scroll proprio.
final class WordChipsView: UIView {

    var onTapWord: ((Int) -> Void)?

    private var buttons: [UIButton] = []
    private var laidOutHeight: CGFloat = 0
    private enum Metric { static let hGap: CGFloat = 6; static let vGap: CGFloat = 6 }

    func configure(words: [String], blocked: Set<Int>, startWord: Int?, endWord: Int?) {
        buttons.forEach { $0.removeFromSuperview() }
        buttons = words.enumerated().map { index, word in
            let button = UIButton(type: .system)
            button.setTitle(word, for: .normal)
            button.titleLabel?.font = .preferredFont(forTextStyle: .body)
            button.titleLabel?.adjustsFontForContentSizeCategory = true
            button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
            button.layer.cornerRadius = 8
            button.tag = index
            let isBlocked = blocked.contains(index)
            let isSelected = index == startWord || index == endWord
            if isBlocked {
                button.isEnabled = false
                button.backgroundColor = .quaternarySystemFill
                button.setTitleColor(.tertiaryLabel, for: .normal)
                button.accessibilityLabel = "\(word), già sottolineata"
            } else if isSelected {
                button.backgroundColor = button.tintColor
                button.setTitleColor(.systemBackground, for: .normal)
            } else {
                button.backgroundColor = .secondarySystemFill
                button.setTitleColor(.label, for: .normal)
            }
            button.addTarget(self, action: #selector(tapped(_:)), for: .touchUpInside)
            addSubview(button)
            return button
        }
        setNeedsLayout()
        invalidateIntrinsicContentSize()
    }

    @objc private func tapped(_ sender: UIButton) { onTapWord?(sender.tag) }

    override func layoutSubviews() {
        super.layoutSubviews()
        let maxWidth = bounds.width
        guard maxWidth > 0 else { return }
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for button in buttons {
            let size = button.systemLayoutSizeFitting(
                CGSize(width: maxWidth, height: UIView.layoutFittingCompressedSize.height))
            let w = Swift.min(size.width, maxWidth)
            if x > 0, x + w > maxWidth { x = 0; y += rowHeight + Metric.vGap; rowHeight = 0 }
            button.frame = CGRect(x: x, y: y, width: w, height: size.height)
            x += w + Metric.hGap
            rowHeight = Swift.max(rowHeight, size.height)
        }
        let total = buttons.isEmpty ? 0 : y + rowHeight
        if abs(total - laidOutHeight) > 0.5 { laidOutHeight = total; invalidateIntrinsicContentSize() }
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: laidOutHeight)
    }
}
