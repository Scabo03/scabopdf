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
//  La granularità delle Impostazioni si applica (DISEGNO_LETTURA_MAC § 6.7) con la regola condivisa con l'iPad: fino al
//  2026-11-10 era la sola differenza dichiarata dall'iPad, che salvava la scelta senza usarla; da quel giro la usano tutte e due.
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
    /// `scansione`: il testo lo legge un lettore delle scansioni (la fase d'estrazione si chiama «Lettura delle scansioni»).
    func elabora(fileURL: URL, nome: String, granularita: Int, dottrina: Bool, processore: DocumentProcessing, scansione: Bool,
                 esito: @escaping (DocumentProcessor.Outcome, _ risorseVisiveSaltate: String?) -> Void)
    /// LA SCELTA DEL LETTORE per una scansione (§ 12.16, decisione 21): la schermata dice che è una scansione, mostra i lettori
    /// col predefinito già scelto e un pulsante per avviare. `scelta(nil)` = annullato.
    func scegliLettoreScansioni(nome: String, senzaTesto: Int, totale: Int, lettori: [LettoreDisponibile], predefinito: String,
                                apriPannello: @escaping () -> Void, scelta: @escaping (String?) -> Void)
    /// Il lettore scelto non è partito (non installato, non caricato, memoria): il motivo in prosa e la proposta dell'altro
    /// lettore. `risposta(true)` = leggi con l'altro; l'importazione non si chiude da sé.
    func proponiAltroLettore(messaggio: String, altro: LettoreDisponibile, risposta: @escaping (Bool) -> Void)
    func chiediLibroGiaPresente(esistente: ArchivedDocument, copie: Int, scelta: @escaping (SceltaDoppione) -> Void)
    func mostraErrore(_ messaggio: String)
    func apriLettura(documento: ArchivedDocument, lettura: LibraryReading)
}

public extension PresentatoreImportazione {
    func scegliLettoreScansioni(nome: String, senzaTesto: Int, totale: Int, lettori: [LettoreDisponibile], predefinito: String,
                                apriPannello: @escaping () -> Void, scelta: @escaping (String?) -> Void) { scelta(predefinito) }
    func proponiAltroLettore(messaggio: String, altro: LettoreDisponibile, risposta: @escaping (Bool) -> Void) { risposta(false) }
}

@MainActor
public final class ImportazioneMac {
    public let libreria: LibreriaMac
    public weak var presentatore: PresentatoreImportazione?
    /// Il lettore delle scansioni (lo dà l'app); senza, una scansione segue la strada dell'iPad (il suo controllo e le sue parole).
    public weak var scansioni: FornitoreScansioni?
    /// Vero dal file scelto alla fine dell'elaborazione: un secondo file in quell'istante non apre un secondo flusso.
    /// Il libro che si sta rielaborando per aprirlo (`apri`), finché la riapertura non è finita: cache scritta, annotazioni
    /// riancorate, finestra chiesta.
    private var libroInLavorazione: String?
    public private(set) var occupato = false {
        didSet { if oldValue && !occupato { DispatchQueue.main.async { [weak self] in self?.prossimoInCoda() } } }
    }
    /// I file arrivati insieme («Apri con» di più file, trascinamento): si importano uno alla volta.
    private var coda: [URL] = []
    /// Un libro da rielaborare chiesto mentre un'altra elaborazione era in corso: si apre appena quella finisce, invece di
    /// non fare nulla in silenzio (rilievo della revisione del giro della tappa A).
    private var aperturaInAttesa: String?

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
        guard !occupato else { return }
        if let id = aperturaInAttesa { aperturaInAttesa = nil; apri(id); if occupato { return } }
        guard !occupato, !coda.isEmpty else { return }
        importa(coda.removeFirst())
    }

    /// Importa il file `url` (scelto dall'utente: pannello, trascinamento, «Apri con»).
    public func importa(_ url: URL) {
        guard let presentatore else { return }
        // Mentre un'altra elaborazione è in corso il file entra in coda (come più file da «Apri con»), non cade nel vuoto.
        guard !occupato else { coda.append(url); return }
        let isAkn = url.pathExtension.lowercased() == "xml"
        guard Self.importabile(url), let copia = LibraryService.copyIntoTemporary(url, ext: isAkn ? "xml" : "pdf") else {
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
        // UNA SCANSIONE (§ 12.16, decisione 21): prima di elaborare, la scelta del lettore. I PDF con testo: nessuna domanda.
        if !isAkn, let scansioni {
            let (senza, totale) = RilevaScansione.pagineSenzaTesto(copia)
            if senza > 0 {
                presentatore.scegliLettoreScansioni(
                    nome: nome, senzaTesto: senza, totale: totale, lettori: scansioni.lettori, predefinito: scansioni.predefinito,
                    apriPannello: { [weak scansioni] in scansioni?.apriPannelloModelli() }
                ) { [weak self] scelta in
                    guard let self, let scelta else { try? FileManager.default.removeItem(at: copia); self?.occupato = false; return }
                    self.elabora(copia: copia, nome: nome, isAkn: false, sha: sha, lettore: scelta)
                }
                return
            }
        }
        elabora(copia: copia, nome: nome, isAkn: isAkn, sha: sha, lettore: nil)
    }

    private func elabora(copia: URL, nome: String, isAkn: Bool, sha: String?, lettore: String?) {
        guard let presentatore else { try? FileManager.default.removeItem(at: copia); occupato = false; return }
        // Prima dell'elaborazione le pagine non si conoscono: la granularità delle Impostazioni (un volume enorme non va in
        // cache all'importazione, e alla prima apertura si prepara leggero: la regola dell'iPad, in `registerImported`).
        let granularita = PreferenzeLettura.granularita(libreria.prefs, isAkn: isAkn, large: false)
        let estrattore = lettore.flatMap { scansioni?.estrattore(lettore: $0) }
        let processore: DocumentProcessing = isAkn ? AknDocumentProcessor()
            : (estrattore.map { DocumentProcessor(extractor: $0) } ?? DocumentProcessor())
        presentatore.elabora(fileURL: copia, nome: nome, granularita: granularita, dottrina: true, processore: processore,
                             scansione: estrattore != nil) {
            [weak self] esito, saltate in
            guard let self else { try? FileManager.default.removeItem(at: copia); return }
            guard case .success(let documento, let contenuto, let dottrina) = esito else {
                // Il lettore non è partito: l'importazione non si chiude, dice perché e propone l'altro lettore.
                if case .failure = esito, let estrattore, let scansioni = self.scansioni,
                   let problema = scansioni.problema(di: estrattore), let altroId = problema.altroLettore,
                   let altro = scansioni.lettori.first(where: { $0.id == altroId && $0.installato }) {
                    self.presentatore?.proponiAltroLettore(messaggio: problema.messaggio, altro: altro) { [weak self] si in
                        guard let self, si else { try? FileManager.default.removeItem(at: copia); self?.occupato = false; return }
                        self.elabora(copia: copia, nome: nome, isAkn: false, sha: sha, lettore: altroId)
                    }
                    return
                }
                try? FileManager.default.removeItem(at: copia)
                self.occupato = false
                if case .failure(let messaggio) = esito { self.presentatore?.mostraErrore(messaggio) }
                return
            }
            let provenienza = estrattore.flatMap { self.scansioni?.provenienza(di: $0) }
            // La registrazione coi passi pesanti fuori dal filo principale (giro «prove rifatte e granularità», 2026-11-10), lo
            // stesso risultato; l'importazione resta «occupata» finché non è finita.
            self.service.registerImportedOffMain(
                document: documento, content: contenuto, doctrineContent: dottrina, sourceName: nome, localCopy: copia,
                isAkn: isAkn, sha256: sha, visualResourcesSkipped: saltate, destination: nil, contentTarget: granularita) { [weak self] r in
                try? FileManager.default.removeItem(at: copia)
                guard let self else { return }
                if let provenienza, provenienza.pagineLette > 0 { self.libreria.provenienze.registra(provenienza, per: r.document.id) }
                self.libreria.avvisa()
                self.presentatore?.apriLettura(
                    documento: r.document,
                    lettura: LibraryReading(content: contenuto, pageMap: r.pageMap,
                                            doctrineContent: r.isLarge ? nil : dottrina, quickConsultTree: r.quickConsultTree))
                self.occupato = false
            }
        }
    }

    // MARK: Apertura (§ 2.5)

    /// La riapertura all'avvio (§ 2.5): l'ultimo libro lasciato aperto, solo dalla cache e senza mai rielaborare, come la
    /// regola dell'iPad («un avvio a freddo non scatena una rielaborazione lunga»); se la granularità è cambiata si legge la
    /// cache com'è, e la prossima apertura esplicita la prepara di nuovo. `false` se non c'è una lettura da aprire.
    @discardableResult
    public func riapriAllAvvio(_ id: String) -> Bool {
        guard let presentatore, let doc = service.store.document(id: id),
              let pronta = service.openableCachedReading(for: doc, requiredTarget: nil) else { return false }
        service.store.recordOpened(id: id)
        libreria.avvisa()
        presentatore.apriLettura(documento: service.store.document(id: id) ?? doc, lettura: pronta)
        return true
    }

    /// Apre il libro al suo punto di lettura: dalla cache se si può usare, altrimenti rielaborandolo dalla sorgente
    /// d'archivio nella schermata d'elaborazione, con il riancoraggio delle annotazioni per contenuto.
    public func apri(_ id: String) {
        guard let presentatore else { return }
        // Lo stesso libro mentre lo si rielabora (doppio clic o Invio dalla Home, che restano attivi): l'apertura in corso lo
        // aprirà; aprirlo adesso dalla cache appena scritta vorrebbe dire leggerlo prima che le annotazioni siano riancorate
        // (giro «prove rifatte e granularità», 2026-11-10, rilievo R8 della revisione indipendente).
        if occupato, libroInLavorazione == id { return }
        guard let doc = service.store.document(id: id) else {
            presentatore.mostraErrore(LibraryWording.documentNoLongerAvailable)
            return
        }
        let isAkn = doc.sourceKind == "akn"
        let large = service.isLarge(doc)
        let granularita = PreferenzeLettura.granularita(libreria.prefs, isAkn: isAkn, large: large)
        // La granularità che la cache deve avere: la regola condivisa con l'iPad (nessuna per i volumi enormi e per le letture
        // arrivate dal Mac, che si adottano così come sono).
        if let pronta = service.openableCachedReading(for: doc, requiredTarget: service.requiredCacheGranularity(for: doc)) {
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
            // Senza la sorgente non si rielabora: se c'è una lettura in cache che si apre (a un'altra granularità), si legge
            // quella, come farebbe l'iPad, invece di dire che il libro non si riapre.
            if let esistente = service.openableCachedReading(for: doc, requiredTarget: nil) {
                service.store.recordOpened(id: id)
                libreria.avvisa()
                presentatore.apriLettura(documento: service.store.document(id: id) ?? doc, lettura: esistente)
            } else {
                presentatore.mostraErrore(LibraryWording.sourceMissing)
            }
            return
        }
        guard !occupato else { aperturaInAttesa = id; return }
        occupato = true
        libroInLavorazione = id
        // Un libro letto da una scansione si rielabora con lo stesso lettore (o con quello di Apple, se l'altro non c'è più).
        var estrattore: ProgressReportingPdfExtractor?
        if !isAkn, let p = libreria.provenienze.provenienza(id), let scansioni {
            let scelto = scansioni.lettori.first { $0.id == p.idLettore && $0.installato } ?? scansioni.lettori.first { $0.installato }
            estrattore = scelto.map { scansioni.estrattore(lettore: $0.id) }
        }
        let processore: DocumentProcessing = isAkn ? AknDocumentProcessor()
            : (estrattore.map { DocumentProcessor(extractor: $0) } ?? DocumentProcessor())
        presentatore.elabora(fileURL: service.archivedSourceURL(forDocumentId: id, kind: doc.sourceKind), nome: doc.title,
                             granularita: granularita, dottrina: !large, processore: processore,
                             scansione: estrattore != nil) { [weak self] esito, saltate in
            guard let self else { return }
            guard case .success(let documento, let contenuto, let dottrina) = esito else {
                self.libroInLavorazione = nil
                self.occupato = false
                if case .failure(let messaggio) = esito { self.presentatore?.mostraErrore(messaggio) }
                return
            }
            // La lettura in cache, l'apertura registrata e il riancoraggio, coi passi pesanti fuori dal filo principale
            // (ScaboChain `completeReprocessedOpening`, la stessa sequenza dell'iPad: sul volume più grande già letto 1,2 s di
            // fermo); il controllore resta «occupato» finché non è finita.
            self.service.completeReprocessedOpening(
                documentId: id, document: documento, content: contenuto, doctrineContent: dottrina,
                large: large, target: granularita, visualResourcesSkipped: saltate) { [weak self] aggiornato, lettura in
                guard let self else { return }
                self.libreria.avvisa()
                self.presentatore?.apriLettura(documento: aggiornato ?? doc, lettura: lettura)
                self.libroInLavorazione = nil
                self.occupato = false
            }
        }
    }
}
