//
//  UltrafocusDevImport.swift
//  ScaboApp
//
//  PORTA D'IMPORT DI SVILUPPO dell'arco ultrafocus — DEBITO TEMPORANEO, da
//  rimuovere a fine arco (registrato in docs/ULTRAFOCUS_INBOX.md § D.7).
//
//  Permette di aprire nella reading view un documento GIÀ ELABORATO fuori
//  dall'app (il "frammento" prodotto dal runner dell'officina macOS), per
//  ascoltare a VoiceOver il prima/dopo della rielaborazione sugli stessi
//  volumi. È interamente racchiusa in `#if DEBUG`: nelle build Release
//  (TestFlight/App Store) questo file non produce alcun simbolo — l'assenza è
//  garantita per costruzione dal compilatore, non da un flag a runtime.
//
//  Confini rispettati per costruzione:
//    * NON tocca il percorso d'import esistente (PDF/AKN), né la libreria, né
//      la persistenza: nessun documento viene registrato in archivio, nessuna
//      cache scritta, nessuna posizione di lettura salvata (onPositionChanged
//      assente).
//    * Il frammento percorre ESATTAMENTE la stessa catena di lettura di un
//      documento normale a valle della classificazione — le stesse chiamate,
//      nello stesso ordine, di `DocumentProcessor.process` (aggancio e
//      piazzamento note → impaginazione del corpo → eventuale flusso Dottrina)
//      — altrimenti il confronto all'orecchio non varrebbe.
//
//  Uso (una riga): metti i file `*.json` (busta: kind/version/label/document/
//  extraction, prodotta dal runner) in Documents/UltrafocusFragments del
//  container dell'app (via `xcrun devicectl device copy`, o AirDrop + "Scegli
//  un file…"), poi Home → bottone "Ultrafocus" → tocca il frammento.
//

#if DEBUG

import UIKit
import ScaboCore
import UniformTypeIdentifiers

/// La busta del frammento prodotta dal runner dell'officina (fuori repo).
/// `document` è il documento GREZZO (pre-aggancio note): l'aggancio avviene
/// qui, nella stessa catena dell'app. `extraction` serve a `bindAndPlaceNotes`
/// (segnali di dimensione/parentesi che la classificazione collassa).
struct UltrafocusFragmentEnvelope: Codable {
    let kind: String        // "scabo-ultrafocus-fragment"
    let version: Int        // 1
    let label: String?      // etichetta annunciata in lista e nel titolo
    let document: ScabopdfDocument
    let extraction: PdfExtraction

    static let expectedKind = "scabo-ultrafocus-fragment"
    static let expectedVersion = 1
}

/// Schermata-lista dei frammenti: i file in Documents/UltrafocusFragments più
/// la voce "Scegli un file…" (per i frammenti arrivati via AirDrop/Files).
final class UltrafocusDevImportViewController: UITableViewController, UIDocumentPickerDelegate {

    private var fragmentURLs: [URL] = []

    static var fragmentsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("UltrafocusFragments", isDirectory: true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Ultrafocus (sviluppo)"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close, target: self, action: #selector(closeTapped))
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reload()
    }

    private func reload() {
        let dir = Self.fragmentsDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let files = (try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil)) ?? []
        fragmentURLs = files.filter { $0.pathExtension.lowercased() == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        tableView.reloadData()
    }

    @objc private func closeTapped() { dismiss(animated: true) }

    // MARK: - Tabella

    override func numberOfSections(in tableView: UITableView) -> Int { 2 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? max(fragmentURLs.count, 1) : 1
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 0 ? "Frammenti in Documents/UltrafocusFragments" : nil
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var config = cell.defaultContentConfiguration()
        if indexPath.section == 0 {
            if fragmentURLs.isEmpty {
                config.text = "Nessun frammento trovato"
                cell.accessibilityTraits = .staticText
            } else {
                config.text = fragmentURLs[indexPath.row].deletingPathExtension().lastPathComponent
                cell.accessibilityTraits = .button
            }
        } else {
            config.text = "Scegli un file…"
            cell.accessibilityTraits = .button
        }
        cell.contentConfiguration = config
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 0 {
            guard !fragmentURLs.isEmpty else { return }
            open(fragmentAt: fragmentURLs[indexPath.row])
        } else {
            let picker = UIDocumentPickerViewController(
                forOpeningContentTypes: [.json], asCopy: true)
            picker.delegate = self
            present(picker, animated: true)
        }
    }

    func documentPicker(_ controller: UIDocumentPickerViewController,
                        didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        open(fragmentAt: url)
    }

    // MARK: - Apertura del frammento (stessa catena di DocumentProcessor)

    private func open(fragmentAt url: URL) {
        UIAccessibility.post(notification: .announcement,
                             argument: "Elaborazione del frammento in corso")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let outcome = Self.processFragment(at: url)
            DispatchQueue.main.async {
                guard let self else { return }
                switch outcome {
                case .failure(let message):
                    let alert = UIAlertController(
                        title: "Frammento non apribile", message: message, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                case .success(let reader):
                    reader.modalPresentationStyle = .fullScreen
                    self.present(reader, animated: true)
                }
            }
        }
    }

    private enum FragmentOutcome {
        case success(UIViewController)
        case failure(String)
    }

    /// Decodifica la busta e percorre la STESSA catena di `DocumentProcessor`
    /// a valle della classificazione: bindAndPlaceNotes → bodyPaginatedContent
    /// (+ Dottrina se ci sono note), poi la reading view con la stessa mappa
    /// pagine. Nessuna scrittura in libreria/cache/posizioni.
    private static func processFragment(at url: URL) -> FragmentOutcome {
        let envelope: UltrafocusFragmentEnvelope
        do {
            let data = try Data(contentsOf: url)
            envelope = try JSONDecoder().decode(UltrafocusFragmentEnvelope.self, from: data)
        } catch {
            return .failure("Il file non è una busta di frammento valida: "
                + (error as NSError).localizedDescription)
        }
        guard envelope.kind == UltrafocusFragmentEnvelope.expectedKind,
              envelope.version == UltrafocusFragmentEnvelope.expectedVersion else {
            return .failure("Busta di tipo o versione inattesa "
                + "(\(envelope.kind) v\(envelope.version)).")
        }

        let raw = envelope.document
        let extraction = envelope.extraction

        // ── Identica alla coda di DocumentProcessor.process ──
        let document = bindAndPlaceNotes(raw, extraction).document
        let hasNotes = raw.structure.contains { $0.type == .NOTE || $0.type == .EDITORIAL_NOTE }
        let content: PaginatedContent
        var doctrineContent: PaginatedContent?
        do {
            // Decisione di prodotto (2026-08-10): le note lunghe ricucite
            // dall'ultrafocus seguono il regime delle note normative lunghe —
            // stesso meccanismo (`fractionLongNoteSegments`, soglia = granularità
            // corpo, prima cella con innesco e regime, continuazioni mute).
            content = try paginate(
                fractionLongNoteSegments(
                    ContinuousBodyBuilder.bodySegments(from: document)),
                DEFAULT_SEGMENTS_PER_PAGE)
            if hasNotes {
                let doctrineDoc = bindAndPlaceNotes(
                    raw, extraction, placement: .doctrineInline).document
                doctrineContent = try paginate(
                    fractionLongNoteSegments(
                        ContinuousBodyBuilder.bodySegments(from: doctrineDoc)),
                    DEFAULT_SEGMENTS_PER_PAGE)
            }
        } catch {
            return .failure("Impaginazione fallita: " + (error as NSError).localizedDescription)
        }

        let pageMap = DocumentOpener.buildPageMap(
            document, content: content, doctrineContent: doctrineContent)
        let title = envelope.label ?? url.deletingPathExtension().lastPathComponent
        let reader = ContinuousReadingViewController(
            content: content,
            sourceName: title,
            documentId: "dev-fragment:" + url.lastPathComponent,
            sourcePageCount: envelope.document.metadata.pages_pdf,
            showOriginalPages: getStoredShowOriginalPageNumbers(LibraryService.shared.prefs),
            sourcePage: { segmentId in
                if let exact = pageMap[segmentId] { return exact }
                let base = segmentId.split(separator: "#", maxSplits: 1,
                                           omittingEmptySubsequences: false)
                    .first.map(String.init) ?? segmentId
                return pageMap[base]
            },
            doctrineContent: doctrineContent,
            quickConsultTree: DocumentOpener.quickConsultTreeIfAvailable(document))
        reader.onBack = { [weak reader] in reader?.dismiss(animated: true) }
        return .success(reader)
    }
}

#endif
