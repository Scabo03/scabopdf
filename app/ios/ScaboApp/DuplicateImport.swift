//
//  DuplicateImport.swift
//  ScaboApp
//
//  «LIBRO GIÀ PRESENTE» (giro «identità», 2026-10-11, LAYER2_PRODUCT_DECISIONS § 12.8, decisione del
//  maintainer): se il file scelto per l'importazione è identico a un libro già in libreria (stessa
//  impronta del contenuto, DocumentIdentity.swift), l'app lo dice in prosa piana e propone come scelta
//  PREDEFINITA di aprire il libro che c'è già, con le sue annotazioni; lascia la possibilità di
//  importare il file come copia a parte; e si può sempre annullare. Nessun messaggio tecnico, nessun
//  codice. Schermata dell'app (non un avviso di sistema), come le conferme dell'offerta di
//  rielaborazione: testo grande pieno, fuoco sul titolo, audit di accessibilità nei test UI.
//

import UIKit
import ScaboCore

enum DuplicateImport {

    /// La spiegazione in parole semplici: quale libro è, quando è stato importato, cosa ha dentro, e le
    /// due vie. `copies` = quante copie dello stesso file ci sono già (la prima è `existing`).
    static func explanation(existing: ArchivedDocument, copies: Int) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.dateStyle = .long
        f.timeStyle = .none
        var text = "Il file che hai scelto è identico a «\(existing.title)», che hai importato il \(f.string(from: existing.importedAt))."
        if copies > 1 {
            text += " Di questo libro hai già \(copies) copie in libreria: «\(existing.title)» è quella che hai usato più di recente."
        }
        let b = existing.bookmarks?.count ?? 0
        let u = existing.underlines?.count ?? 0
        var parts: [String] = []
        if b > 0 { parts.append(b == 1 ? "un segnalibro" : "\(b) segnalibri") }
        if u > 0 { parts.append(u == 1 ? "una sottolineatura" : "\(u) sottolineature") }
        text += parts.isEmpty
            ? " Quel libro non ha ancora segnalibri né sottolineature."
            : " In quel libro hai " + parts.joined(separator: " e ") + "."
        text += " Puoi aprire il libro che hai già, con le sue annotazioni e il punto in cui eri arrivato, "
            + "oppure importare il file come una copia a parte: la copia parte senza annotazioni."
        return text
    }
}

/// La schermata: titolo, spiegazione, tre scelte. Predefinita (in evidenza): aprire il libro che c'è già.
final class DuplicateImportViewController: ReprocessTextViewController {

    enum Choice {
        case openExisting
        case importAsCopy
        case cancel
    }

    private let existing: ArchivedDocument
    private let copies: Int
    private let onChoice: (Choice) -> Void
    private var heading: UILabel?
    private var decided = false

    static func present(
        existing: ArchivedDocument, copies: Int, from presenter: UIViewController,
        onChoice: @escaping (Choice) -> Void
    ) {
        let vc = DuplicateImportViewController(existing: existing, copies: copies, onChoice: onChoice)
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .formSheet
        nav.presentationController?.delegate = vc
        presenter.present(nav, animated: Motion.animated())
    }

    private init(existing: ArchivedDocument, copies: Int, onChoice: @escaping (Choice) -> Void) {
        self.existing = existing
        self.copies = copies
        self.onChoice = onChoice
        super.init(nibName: nil, bundle: nil)
    }

    /// Costruttore per i test (verifica dell'albero di accessibilità senza presentazione).
    static func makeForTesting(existing: ArchivedDocument, copies: Int, onChoice: @escaping (Choice) -> Void) -> DuplicateImportViewController {
        DuplicateImportViewController(existing: existing, copies: copies, onChoice: onChoice)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) non supportato.") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Libro già presente"
        heading = addHeading("Questo libro è già nella tua libreria")
        addParagraph(DuplicateImport.explanation(existing: existing, copies: copies), identifier: "duplicate.text")
        addButton("Apri il libro che hai già", prominent: true, identifier: "duplicate.open") { [weak self] in self?.decide(.openExisting) }
        addButton("Importa come copia a parte", prominent: false, identifier: "duplicate.copy") { [weak self] in self?.decide(.importAsCopy) }
        addButton("Annulla", prominent: false, identifier: "duplicate.cancel") { [weak self] in self?.decide(.cancel) }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Il fuoco parte dal titolo: si ascolta prima la notizia, mai il pulsante.
        UIAccessibility.post(notification: .screenChanged, argument: heading)
    }

    private func decide(_ choice: Choice) {
        guard !decided else { return }
        decided = true
        let onChoice = self.onChoice
        dismiss(animated: Motion.animated()) { onChoice(choice) }
    }
}

extension DuplicateImportViewController: UIAdaptivePresentationControllerDelegate {
    /// Chiusa con lo swipe (o il gesto di VoiceOver «indietro»): vale come «Annulla», mai un vicolo cieco.
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        guard !decided else { return }
        decided = true
        onChoice(.cancel)
    }
}
