//
//  ContinuousReadingView.swift
//  ScaboApp
//
//  Reading view UIKit per il Layout "Lettura Continua" (gradino 2, sessione 1).
//  Rende il CORPO di un documento classificato (ScaboCore) come contenuto
//  accessibile VoiceOver, navigabile via swipe orizzontale CONTINUO da un capo
//  all'altro del documento.
//
//  ── VINCOLO INVIOLABILE — principio sacro del prodotto (§ 2.2) ──────────────────
//
//  Lo swipe orizzontale dentro il testo NON deve MAI essere ostacolato, bloccato,
//  rallentato o ridirezionato da confini interni al documento (confini di pagina
//  logica o di unità strutturale). Lo swipe scorre fluido da un elemento
//  accessibile al successivo per TUTTA l'estensione del documento; l'unica
//  eccezione è il primo/ultimo elemento assoluto.
//
//  Realizzazione a livello di API. Il container del testo è UN SOLO container di
//  accessibilità — la `documentContainer` — il cui `accessibilityElements` è UN
//  UNICO array piatto e ordinato che copre OGNI segmento di OGNI pagina logica,
//  in ordine di lettura. È la garanzia strutturale del requisito: VoiceOver,
//  attraversando un singolo array piatto, passa da elemento a elemento senza che
//  alcun oggetto-confine si frapponga ai bordi di pagina, perché i bordi di
//  pagina non esistono in quell'array. La paginazione logica (`ContentPage`) è
//  appiattita in ingresso: è presentazione/orientamento e NON spezza il container.
//
//  Perché un array piatto esplicito e NON `UIAccessibilityReadingContent`.
//  `UIAccessibilityReadingContent` modella la LETTURA AUTOMATICA continua (linea
//  per linea, con auto-page-turn), che è lo strumento SECONDARIO del prodotto. La
//  modalità primaria è lo swipe MANUALE elemento-per-elemento, ed è esattamente
//  ciò che un container con `accessibilityElements` piatto serve in modo nativo e
//  verificabile. Un'architettura multi-pagina (UIPageViewController + reading
//  content) reintrodurrebbe proprio il confine di pagina che il vincolo vieta;
//  l'array piatto unico lo rende impossibile per costruzione. ("o equivalente
//  UIKit" del brief: questo È l'equivalente che garantisce la continuità.)
//
//  ── Design bi-modale (principio inderogabile) ───────────────────────────────────
//
//  Ogni segmento ha resa VISIVA (un `UILabel` stilizzato per ruolo, Dynamic Type)
//  ED accessibile (`accessibilityLabel` = testo parlato). Nessuna delle due è
//  sacrificata. Non si ridefinisce alcun gesto standard di VoiceOver: si definisce
//  solo il comportamento dei propri elementi in risposta ai gesti standard.
//
//  ── Confine pulito (seam) ───────────────────────────────────────────────────────
//
//  La view NON importa PDFKit e non conosce l'estrazione: CONSUMA il modello già
//  prodotto (`ContentSegment`/`PaginatedContent` di ScaboCore). La classificazione
//  non viene toccata.
//
//  ── Onestà sulla verifica ───────────────────────────────────────────────────────
//
//  Questa view garantisce, a livello di API, struttura/ordine/etichette/container
//  unico. L'ESPERIENZA VoiceOver effettiva (fluidità reale dello swipe, resa
//  vocale) si verifica solo con VoiceOver sull'iPhone fisico (fase TestFlight): il
//  Simulator non la riproduce.
//

import UIKit
import ScaboCore

/// `UILabel` che porta con sé il `ContentSegment` da cui è stato costruito, così i
/// test possono ispezionare la corrispondenza segmento→elemento accessibile.
final class SegmentLabel: UILabel {
    /// Il segmento sorgente (ordine, ruolo, testo).
    let segment: ContentSegment

    init(segment: ContentSegment) {
        self.segment = segment
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) non supportato: SegmentLabel è costruita in codice.")
    }
}

/// La reading view del Layout "Lettura Continua". Renderizza una sequenza di
/// `ContentSegment` (il corpo) come container di accessibilità unico e continuo.
final class ContinuousReadingView: UIView {

    // MARK: - Sottoviste

    /// Scroll verticale: porta on-screen l'elemento che VoiceOver mette a fuoco
    /// (auto-scroll nativo, perché gli elementi sono `UIView` reali nel contenuto).
    private let scrollView = UIScrollView()

    /// IL container di accessibilità unico per l'INTERO documento. Il suo
    /// `accessibilityElements` è l'array piatto e ordinato di tutti i segmenti.
    private let documentContainer = UIView()

    // MARK: - Stato

    /// Le etichette per-segmento, in ordine di lettura. Sola lettura per i test.
    private(set) var segmentLabels: [SegmentLabel] = []

    /// Vincoli del layout verticale corrente (azzerati a ogni `render`).
    private var contentConstraints: [NSLayoutConstraint] = []

    // MARK: - Metrica di lettura

    private enum Metrics {
        static let horizontalInset: CGFloat = 20
        static let verticalInset: CGFloat = 16
        static let interSegmentSpacing: CGFloat = 16
    }

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) non supportato: ContinuousReadingView è costruita in codice.")
    }

    private func setUp() {
        backgroundColor = .systemBackground

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        addSubview(scrollView)

        documentContainer.translatesAutoresizingMaskIntoConstraints = false
        // È un CONTAINER, non un elemento foglia: VoiceOver non lo mette a fuoco,
        // ne attraversa gli `accessibilityElements`.
        documentContainer.isAccessibilityElement = false
        scrollView.addSubview(documentContainer)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            // Container ancorato al contenuto scrollabile; larghezza vincolata alla
            // cornice → scroll solo verticale, testo che va a capo.
            documentContainer.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            documentContainer.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            documentContainer.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            documentContainer.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            documentContainer.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
        ])
    }

    // MARK: - Rendering (API pubblica della view)

    /// Renderizza un layout PAGINATO. Le pagine logiche vengono APPIATTITE in un
    /// unico flusso continuo: la paginazione è solo presentazione/orientamento e
    /// non frammenta né il flusso visivo né — soprattutto — il container di
    /// accessibilità. Far passare di qui un `PaginatedContent` multi-pagina è il
    /// modo più diretto per dimostrare il vincolo: N pagine → 1 container piatto.
    func render(_ content: PaginatedContent) {
        render(content.pages.flatMap { $0.segments })
    }

    /// Renderizza una sequenza piatta di segmenti in ordine di lettura.
    func render(_ segments: [ContentSegment]) {
        // Smonta il rendering precedente.
        NSLayoutConstraint.deactivate(contentConstraints)
        contentConstraints.removeAll()
        segmentLabels.forEach { $0.removeFromSuperview() }
        segmentLabels.removeAll()

        // Costruisce un'etichetta per segmento, in ordine.
        var previousBottom = documentContainer.topAnchor
        var newConstraints: [NSLayoutConstraint] = []

        for (index, segment) in segments.enumerated() {
            let label = makeLabel(for: segment)
            documentContainer.addSubview(label)
            segmentLabels.append(label)

            let topSpacing = index == 0 ? Metrics.verticalInset : Metrics.interSegmentSpacing
            newConstraints.append(contentsOf: [
                label.topAnchor.constraint(equalTo: previousBottom, constant: topSpacing),
                label.leadingAnchor.constraint(
                    equalTo: documentContainer.leadingAnchor, constant: Metrics.horizontalInset),
                label.trailingAnchor.constraint(
                    equalTo: documentContainer.trailingAnchor, constant: -Metrics.horizontalInset),
            ])
            previousBottom = label.bottomAnchor
        }

        // Chiude il contenuto: l'ultimo elemento determina l'altezza scrollabile.
        // Se il documento è vuoto il container collassa a un'altezza nulla.
        if let last = segmentLabels.last {
            newConstraints.append(
                last.bottomAnchor.constraint(
                    equalTo: documentContainer.bottomAnchor, constant: -Metrics.verticalInset))
        } else {
            newConstraints.append(documentContainer.heightAnchor.constraint(equalToConstant: 0))
        }

        NSLayoutConstraint.activate(newConstraints)
        contentConstraints = newConstraints

        // ── Il cuore del vincolo sacro ──────────────────────────────────────────
        // UN solo container, UN solo array piatto e ordinato su TUTTO il documento.
        // Esplicito (non derivato dalla geometria) così l'ordine di lettura è
        // deterministico e il container resta unico per costruzione.
        documentContainer.accessibilityElements = segmentLabels
    }

    // MARK: - Introspezione per i test (il container è privato)

    /// Gli elementi accessibili ESPOSTI dal container, nell'ordine che VoiceOver
    /// attraversa. È la superficie su cui i test verificano il vincolo sacro:
    /// unicità del container, conteggio, ordine, continuità ai confini di pagina.
    var exposedAccessibilityElements: [NSObject] {
        (documentContainer.accessibilityElements as? [NSObject]) ?? []
    }

    /// Vero se il container si espone come elemento foglia. DEVE essere falso: è un
    /// container che si attraversa, non un elemento da mettere a fuoco.
    var isDocumentContainerAnAccessibilityElement: Bool {
        documentContainer.isAccessibilityElement
    }

    // MARK: - Costruzione dell'elemento accessibile + visivo (bi-modale)

    private func makeLabel(for segment: ContentSegment) -> SegmentLabel {
        let label = SegmentLabel(segment: segment)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping

        // Resa VISIVA: stile tipografico per ruolo, con Dynamic Type (rispetta la
        // dimensione testo scelta dall'utente — requisito di accessibilità).
        let textStyle = Self.textStyle(for: segment.role)
        label.font = UIFont.preferredFont(forTextStyle: textStyle)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .label
        label.text = segment.text

        // Resa ACCESSIBILE: ogni elemento DEVE avere un'etichetta non vuota (un
        // elemento senza resa accessibile è bug critico). Il testo parlato include
        // l'intro acustica del ruolo quando presente (vuota per corpo/heading,
        // che si distinguono tipograficamente — RoleStyle del prodotto).
        label.isAccessibilityElement = true
        label.accessibilityLabel = Self.spokenText(for: segment)

        // Tratto header per heading e divisori: abilita la navigazione per
        // intestazioni nel rotore VoiceOver SENZA introdurre alcun confine allo
        // swipe (lo swipe resta elemento-per-elemento; il rotore è navigazione
        // aggiuntiva, non un blocco).
        if Self.isHeadingRole(segment.role) {
            label.accessibilityTraits.insert(.header)
        }

        return label
    }

    // MARK: - Mappature ruolo → stile / semantica

    /// Testo che VoiceOver pronuncia: intro acustica (se presente) + testo.
    static func spokenText(for segment: ContentSegment) -> String {
        let intro = segment.acousticIntro.trimmingCharacters(in: .whitespacesAndNewlines)
        if intro.isEmpty {
            return segment.text
        }
        return "\(intro) \(segment.text)"
    }

    /// Vero per i ruoli da trattare come intestazione (tratto `.header`).
    static func isHeadingRole(_ role: String) -> Bool {
        role.hasPrefix("HEADING_") || role == SECTION_DIVIDER_ROLE
    }

    /// Stile tipografico (Dynamic Type) per ruolo. Heading via taglie titolo
    /// decrescenti; corpo via `.body`. Differenziazione VISIVA dei ruoli.
    private static func textStyle(for role: String) -> UIFont.TextStyle {
        switch role {
        case "HEADING_1": return .title1
        case "HEADING_2": return .title2
        case "HEADING_3": return .title3
        case "HEADING_4": return .headline
        case SECTION_DIVIDER_ROLE: return .headline
        default: return .body
        }
    }
}
