//
//  ImportazioneMac.swift
//  ScaboMacLettura — IMPORTAZIONE e APERTURA dei libri sull'app Mac (giro «app unica per Mac, tappa A», 2026-11-08;
//  LAYER2 § 12.8-12.10, decisione 10 di § 12.16). Lo stesso percorso dell'iPad (ScaboApp `DocumentOpener`), con la logica
//  presa dal modulo condiviso ScaboChain e mai riscritta:
//
//    importazione: copia temporanea del file scelto (pannello, trascinamento, «Apri con») → impronta e «Libro già presente»
//    (`DocumentIdentity.existingDocuments`) → elaborazione bloccante (`DocumentProcessor` / `AknDocumentProcessor`, la catena
//    condivisa con le opzioni dell'iPad: l'innesto dell'officina spento) → registrazione (`registerImported`) → la lettura;
//    apertura: la cache se si può usare (`openableCachedReading`), altrimenti la rielaborazione dalla sorgente d'archivio
//    (`storeProcessedReading`, poi il riancoraggio per contenuto).
//
//  Una differenza dichiarata dall'iPad, una sola: la granularità delle Impostazioni si applica (DISEGNO_LETTURA_MAC § 6.7;
//  sull'iPad si salva ma la lettura non la usa). Al valore predefinito le due app fanno la stessa cosa.
//
//  L'interfaccia (schermate, pannelli, finestre) la fa un PRESENTATORE: quello dell'app è AppKit; i test ne usano uno che
//  sceglie da sé, così la stessa logica si prova senza finestre.
//
import Foundation
import ScaboChain
import ScaboCore

/// La scelta davanti a «Libro già presente» (§ 12.8).
public enum SceltaDoppione: Equatable { case apriQuelloCheHai, importaComeCopia, annulla }

/// Chi mostra le schermate dell'importazione e dell'apertura.
@MainActor
public protocol PresentatoreImportazione: AnyObject {
    /// La schermata d'elaborazione bloccante (§ 12.9): avvia `processore` e chiama `esito` una volta sola, con il motivo per
    /// cui il riconoscimento di tabelle e figure è saltato, se è da riprovare.
    func elabora(fileURL: URL, nome: String, granularita: Int, dottrina: Bool, processore: DocumentProcessing,
                 esito: @escaping (DocumentProcessor.Outcome, _ risorseVisiveSaltate: String?) -> Void)
    func chiediLibroGiaPresente(esistente: ArchivedDocument, copie: Int, scelta: @escaping (SceltaDoppione) -> Void)
    func mostraErrore(_ messaggio: String)
    func apriLettura(documento: ArchivedDocument, lettura: LibraryReading)
}

@MainActor
public final class ImportazioneMac {
    public let libreria: LibreriaMac
    public weak var presentatore: PresentatoreImportazione?
    /// Vero dal file scelto alla fine dell'elaborazione: un secondo file in quell'istante non apre un secondo flusso.
    public private(set) var occupato = false {
        didSet { if oldValue && !occupato { DispatchQueue.main.async { [weak self] in self?.prossimoInCoda() } } }
    }
    /// I file arrivati insieme («Apri con» di più file, trascinamento): si importano uno alla volta.
    private var coda: [URL] = []

    public init(libreria: LibreriaMac) { self.libreria = libreria }

    private var service: LibraryService { libreria.service }

    /// I tipi che si importano: PDF e XML (gli atti AKN di Normattiva), come sull'iPad.
    public static func importabile(_ url: URL) -> Bool { ["pdf", "xml"].contains(url.pathExtension.lowercased()) }

    // MARK: Importazione

    /// Importa più file uno dopo l'altro.
    public func importa(_ urls: [URL]) {
        coda += urls.filter(Self.importabile)
        prossimoInCoda()
    }

    private func prossimoInCoda() {
        guard !occupato, !coda.isEmpty else { return }
        importa(coda.removeFirst())
    }

    /// Importa il file `url` (scelto dall'utente: pannello, trascinamento, «Apri con»).
    public func importa(_ url: URL) {
        guard !occupato, let presentatore else { return }
        let isAkn = url.pathExtension.lowercased() == "xml"
        guard Self.importabile(url), let copia = copiaTemporanea(url, ext: isAkn ? "xml" : "pdf") else {
            presentatore.mostraErrore(LibraryWording.unreadablePickedFile)
            return
        }
        occupato = true
        let nome = url.lastPathComponent
        // LIBRO GIÀ PRESENTE (§ 12.8): l'impronta prima di elaborare.
        DocumentIdentity.existingDocuments(matchingFileAt: copia, service: service) { [weak self] sha, trovati in
            guard let self, let presentatore = self.presentatore else {
                try? FileManager.default.removeItem(at: copia); self?.occupato = false; return
            }
            guard let esistente = trovati.first else {
                self.elabora(copia: copia, nome: nome, isAkn: isAkn, sha: sha)
                return
            }
            presentatore.chiediLibroGiaPresente(esistente: esistente, copie: trovati.count) { [weak self] scelta in
                guard let self else { try? FileManager.default.removeItem(at: copia); return }
                switch scelta {
                case .apriQuelloCheHai:
                    try? FileManager.default.removeItem(at: copia)
                    self.occupato = false
                    self.apri(esistente.id)
                case .importaComeCopia:
                    self.elabora(copia: copia, nome: nome, isAkn: isAkn, sha: sha)
                case .annulla:
                    try? FileManager.default.removeItem(at: copia)
                    self.occupato = false
                }
            }
        }
    }

    private func elabora(copia: URL, nome: String, isAkn: Bool, sha: String?) {
        guard let presentatore else { try? FileManager.default.removeItem(at: copia); occupato = false; return }
        let granularita = PreferenzeLettura.granularita(libreria.prefs, per: nil, isAkn: isAkn)
        let processore: DocumentProcessing = isAkn ? AknDocumentProcessor() : DocumentProcessor()
        presentatore.elabora(fileURL: copia, nome: nome, granularita: granularita, dottrina: true, processore: processore) {
            [weak self] esito, saltate in
            defer { try? FileManager.default.removeItem(at: copia); self?.occupato = false }
            guard let self else { return }
            switch esito {
            case .success(let documento, let contenuto, let dottrina):
                let r = self.service.registerImported(
                    document: documento, content: contenuto, doctrineContent: dottrina, sourceName: nome, localCopy: copia,
                    isAkn: isAkn, sha256: sha, visualResourcesSkipped: saltate, destination: nil, contentTarget: granularita)
                self.libreria.avvisa()
                self.presentatore?.apriLettura(
                    documento: r.document,
                    lettura: LibraryReading(content: contenuto, pageMap: r.pageMap,
                                            doctrineContent: r.isLarge ? nil : dottrina, quickConsultTree: r.quickConsultTree))
            case .cancelled:
                break
            case .failure(let messaggio):
                self.presentatore?.mostraErrore(messaggio)
            }
        }
    }

    private func copiaTemporanea(_ sorgente: URL, ext: String) -> URL? {
        let accesso = sorgente.startAccessingSecurityScopedResource()
        defer { if accesso { sorgente.stopAccessingSecurityScopedResource() } }
        let destinazione = FileManager.default.temporaryDirectory.appendingPathComponent("scabo_import_\(UUID().uuidString).\(ext)")
        do {
            try FileManager.default.copyItem(at: sorgente, to: destinazione)
            return destinazione
        } catch {
            return nil
        }
    }

    // MARK: Apertura (§ 2.5)

    /// Apre il libro al suo punto di lettura: dalla cache se si può usare, altrimenti rielaborandolo dalla sorgente
    /// d'archivio nella schermata d'elaborazione, con il riancoraggio delle annotazioni per contenuto.
    public func apri(_ id: String) {
        guard let presentatore else { return }
        guard let doc = service.store.document(id: id) else {
            presentatore.mostraErrore(LibraryWording.sourceMissing)
            return
        }
        let isAkn = doc.sourceKind == "akn"
        let large = service.isLarge(doc)
        let granularita = PreferenzeLettura.granularita(libreria.prefs, per: doc, isAkn: isAkn)
        if let pronta = service.openableCachedReading(for: doc, requiredTarget: large ? nil : granularita) {
            service.store.recordOpened(id: id)
            libreria.avvisa()
            presentatore.apriLettura(documento: service.store.document(id: id) ?? doc, lettura: pronta)
            return
        }
        // Una cache c'è ma non si usa: le annotazioni ricevono l'ancora su quel contenuto prima di rielaborare.
        if let vecchia = service.loadCache(forDocumentId: id) {
            service.mintMissingAnchors(documentId: id, in: ContentAnchorIndex(segments: vecchia.content.pages.flatMap { $0.segments }))
        }
        guard service.hasArchivedSource(forDocumentId: id, kind: doc.sourceKind) else {
            presentatore.mostraErrore(LibraryWording.sourceMissing)
            return
        }
        guard !occupato else { return }
        occupato = true
        let processore: DocumentProcessing = isAkn ? AknDocumentProcessor() : DocumentProcessor()
        presentatore.elabora(fileURL: service.archivedSourceURL(forDocumentId: id, kind: doc.sourceKind), nome: doc.title,
                             granularita: granularita, dottrina: !large, processore: processore) { [weak self] esito, saltate in
            guard let self else { return }
            self.occupato = false
            switch esito {
            case .success(let documento, let contenuto, let dottrina):
                let lettura = self.service.storeProcessedReading(
                    documentId: id, document: documento, content: contenuto, doctrineContent: dottrina,
                    large: large, target: granularita, visualResourcesSkipped: saltate)
                self.service.store.recordOpened(id: id)
                let aggiornato = self.service.reanchorAfterProcessing(documentId: id, content: contenuto) ?? doc
                self.libreria.avvisa()
                self.presentatore?.apriLettura(documento: aggiornato, lettura: lettura)
            case .cancelled:
                break
            case .failure(let messaggio):
                self.presentatore?.mostraErrore(messaggio)
            }
        }
    }
}
