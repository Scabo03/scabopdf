//
//  LetturaMigliore.swift
//  ScaboMacLettura — LA LETTURA MIGLIORE ARRIVA DA SOLA (giro «modelli e scansioni», 2026-11-18; LAYER2 § 12.16, decisione 20;
//  DISEGNO_LETTURA_MAC § 6.6, via A). All'importazione il Mac dà la lettura dell'iPad; la lettura migliore dei modelli (l'innesto
//  dell'officina, e per le scansioni il lettore scelto) si prepara su un libro della libreria — dal menu del libro, o
//  dall'officina su un PDF che è già in libreria — e, quando è pronta, entra da sola nell'offerta «Lettura migliore disponibile»
//  di quel libro: un annuncio di VoiceOver, un pulsante «Apri ora» nella Home, un segno nella riga del libro.
//
//  Le regole dell'offerta sono quelle dell'iPad (§ 12.13, § 12.14), con le stesse funzioni condivise della libreria (ScaboChain):
//    - si offre solo se la lettura CAMBIA: la lettura pronta si confronta con quella in uso; se è uguale, nessuna offerta, e
//      l'annuncio dice che il libro resta com'è (niente arriva in silenzio);
//    - accettare richiede due gesti, e la conferma ha «Annulla» come pulsante preferito;
//    - la lettura di prima resta sul Mac finché non si conferma la nuova (`stashPreviousReading`); «Torna alla lettura
//      precedente» rimette tutto com'era (`restorePreviousCache` e `restore`);
//    - le annotazioni si riancorano per contenuto (`reanchorAfterProcessing`): nessuna si sposta in silenzio, quelle che non si
//      ritrovano con sicurezza restano «da ricollocare».
//  Le parole sono quelle dell'iPad (ScaboApp `ReadingFromMac`, `ReprocessOffer`), dette per il Mac.
//

import AppKit
import Foundation
import ScaboChain
import ScaboCore

/// Una lettura migliore pronta, in attesa della scelta (nessun testo del libro fuori dalla lettura stessa).
public struct LetturaMiglioreInAttesa: Codable {
    public var creata: Date
    /// Ciò che l'officina ha fatto in più, in righe brevi e senza testo del libro.
    public var righe: [String]
    public var lettura: PackagedReading
    /// Se la lettura è stata preparata con un lettore delle scansioni: da dove viene il testo (va nella riga quando si usa).
    public var provenienza: ProvenienzaScansione?

    public init(creata: Date, righe: [String], lettura: PackagedReading, provenienza: ProvenienzaScansione? = nil) {
        self.creata = creata; self.righe = righe; self.lettura = lettura; self.provenienza = provenienza
    }
}

/// Le letture migliori in attesa: un file per libro nella libreria del Mac (`ScaboMac/Migliori/<id>.json`).
public final class OfferteMigliori {
    private let cartella: URL
    private var indice: Set<String>

    public init(service: LibraryService) {
        let radice = service.archivedPDFURL(forDocumentId: "_").deletingLastPathComponent().deletingLastPathComponent()
        cartella = radice.appendingPathComponent("ScaboMac", isDirectory: true).appendingPathComponent("Migliori", isDirectory: true)
        let nomi = (try? FileManager.default.contentsOfDirectory(atPath: cartella.path)) ?? []
        indice = Set(nomi.filter { $0.hasSuffix(".json") }.map { String($0.dropLast(5)) })
    }

    private func url(_ id: String) -> URL { cartella.appendingPathComponent(id + ".json") }

    public var libri: Set<String> { indice }

    public func inAttesa(_ id: String) -> LetturaMiglioreInAttesa? {
        guard indice.contains(id) else { return nil }
        return try? JSONDecoder().decode(LetturaMiglioreInAttesa.self, from: Data(contentsOf: url(id)))
    }

    @discardableResult
    public func salva(_ l: LetturaMiglioreInAttesa, per id: String) -> Bool {
        try? FileManager.default.createDirectory(at: cartella, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(l), (try? data.write(to: url(id), options: .atomic)) != nil else { return false }
        indice.insert(id)
        return true
    }

    public func togli(_ id: String) {
        try? FileManager.default.removeItem(at: url(id))
        indice.remove(id)
    }
}

/// Un ruolo di modello nella schermata «Prepara una lettura migliore» (Parte 3): le scelte e la predefinita.
public struct RuoloModello: Equatable {
    public let ruolo: String
    public let scelte: [(id: String, nome: String)]
    public let predefinito: String
    public let nota: String?

    public init(ruolo: String, scelte: [(id: String, nome: String)], predefinito: String, nota: String? = nil) {
        self.ruolo = ruolo; self.scelte = scelte; self.predefinito = predefinito; self.nota = nota
    }

    public static func == (a: RuoloModello, b: RuoloModello) -> Bool {
        a.ruolo == b.ruolo && a.scelte.map(\.id) == b.scelte.map(\.id) && a.predefinito == b.predefinito && a.nota == b.nota
    }
}

/// Chi prepara la lettura migliore (lo dà l'app: i modelli vivono in ScaboMacKit).
@MainActor
public protocol FornitoreLetturaMigliore: AnyObject {
    /// I modelli per ruolo, col predefinito già scelto, per il libro `pdf` (con o senza pagine scansionate).
    func ruoli(pdf: URL) -> [RuoloModello]
    /// Prepara la lettura migliore fuori dal filo principale; `completion` arriva sul filo principale con la lettura e le righe
    /// dell'officina, o con un errore in prosa.
    func prepara(pdf: URL, scelte: [String: String], granularita: Int,
                 completion: @escaping (Result<(lettura: PackagedReading, righe: [String], provenienza: ProvenienzaScansione?), Error>) -> Void)
}

/// Le parole della lettura migliore sul Mac (quelle dell'iPad, § 12.13).
public enum ParoleLetturaMigliore {
    public static let segnoRiga = "lettura migliore disponibile"
    public static let segnoPreparazione = "lettura migliore in preparazione"
    public static let voceMenuPrepara = "Prepara una lettura migliore…"
    public static let voceMenuOfferta = "Lettura migliore disponibile…"
    public static let voceMenuTorna = "Torna alla lettura precedente…"
    public static let voceMenuTieni = "Tieni la nuova lettura…"
    public static let voceMenuInformazioni = "Informazioni sul libro…"
    public static let preparaTitolo = "Prepara una lettura migliore"
    public static func preparaSpiegazione(_ titolo: String) -> String {
        "Per «\(titolo)» il Mac prepara una lettura con l'aiuto dei modelli scelti qui sotto. Puoi continuare a usare l'app: "
            + "quando la lettura è pronta te lo dice, e la trovi fra le opzioni del libro. Se non cambia nulla, il libro resta com'è."
    }
    public static let prepara = "Prepara"
    public static func arrivata(_ titolo: String) -> String { "È pronta una lettura migliore per «\(titolo)»." }
    public static func nienteDaCambiare(_ titolo: String) -> String {
        "La lettura migliore di «\(titolo)» sarebbe uguale a quella di adesso: il libro resta com'è."
    }
    public static func nienteDiNuovo(_ titolo: String) -> String {
        "Per «\(titolo)» i modelli non hanno trovato nulla da fare in più: il libro resta com'è."
    }
    public static func nonRiuscita(_ titolo: String, _ motivo: String) -> String {
        "La lettura migliore di «\(titolo)» non si è potuta preparare. \(motivo)"
    }
    public static let apriOra = "Apri ora"
    public static func titoloOfferta(_ titolo: String) -> String { "Lettura migliore disponibile per «\(titolo)»" }
    public static func cosaArriva(_ titolo: String, data: Date, righe: [String]) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "it_IT"); f.dateStyle = .long; f.timeStyle = .short
        var t = "Cosa arriva. È pronta la lettura migliore di «\(titolo)», preparata il \(f.string(from: data)) qui sul Mac con l'aiuto "
            + "dei modelli."
        if !righe.isEmpty { t += " In questo libro: " + righe.joined(separator: "; ") + "." }
        t += " Il testo viene dallo stesso file del libro."
        return t
    }
    public static func annotazioni(segnalibri: Int, sottolineature: Int) -> String {
        var parti: [String] = []
        if segnalibri > 0 { parti.append(segnalibri == 1 ? "un segnalibro" : "\(segnalibri) segnalibri") }
        if sottolineature > 0 { parti.append(sottolineature == 1 ? "una sottolineatura" : "\(sottolineature) sottolineature") }
        let base = parti.isEmpty ? "In questo libro non hai segnalibri né sottolineature."
            : "In questo libro hai \(parti.joined(separator: " e ")): l'app li cerca nella lettura nuova; quelli che non ritrova con "
            + "sicurezza restano «da ricollocare»."
        return "Le tue annotazioni. " + base + " Finché non confermi, la lettura di adesso resta sul Mac e puoi tornarci in qualunque momento."
    }
    public static let usa = "Usa la lettura migliore…"
    public static let nonOra = "Non ora"
    public static let togli = "Togli questa lettura…"
    public static let confermaTitolo = "Usare la lettura migliore?"
    public static func confermaTesto(_ titolo: String) -> String {
        "«\(titolo)» userà la lettura migliore. La lettura di adesso resta sul Mac finché non confermi quella nuova."
    }
    public static let confermaAzione = "Usa la lettura migliore"
    public static let annulla = "Annulla"
    public static let togliTitolo = "Togliere questa lettura?"
    public static func togliTesto(_ titolo: String) -> String {
        "La lettura migliore preparata per «\(titolo)» si cancella. Il libro resta com'è, con le sue annotazioni. Se poi la vorrai, "
            + "preparala di nuovo."
    }
    public static let togliAzione = "Togli la lettura"
    public static let esitoTitolo = "Lettura migliore in uso"
    public static let tieni = "Tieni la nuova lettura"
    public static let torna = "Torna alla lettura precedente"
    public static let piuTardi = "Decidi più tardi"
    public static let tieniTitolo = "Tenere la nuova lettura?"
    public static let tieniTesto = "La lettura di prima verrà cancellata dal Mac e non potrai più tornarci. Le tue annotazioni restano."
    public static let confermata = "Nuova lettura confermata. La lettura precedente è stata cancellata."
    public static let tornato = "Sei tornato alla lettura precedente."
    public static let rimandata = "La scelta resta disponibile fra le opzioni del libro."
    public static func esito(_ r: ReanchorReport, segnalibri: Int, sottolineature: Int) -> String {
        var t = "Il libro usa la lettura migliore."
        if segnalibri > 0 {
            let persi = r.bookmarksOrphaned
            t += persi == 0 ? " Tutti i segnalibri sono al loro posto (\(segnalibri))."
                : " Segnalibri al loro posto: \(segnalibri - persi) su \(segnalibri). Da ricollocare: \(persi); li trovi in fondo alla lista dei segnalibri."
        }
        if sottolineature > 0 {
            let perse = r.underlinesOrphaned
            t += perse == 0 ? " Tutte le sottolineature sono al loro posto (\(sottolineature))."
                : " Sottolineature al loro posto: \(sottolineature - perse) su \(sottolineature). \(perse) non sono state ritrovate: restano salvate ma non si vedono; tornando alla lettura precedente riappaiono."
        }
        return t + " Puoi tenere la nuova lettura oppure tornare a quella di prima. Se non decidi adesso, la scelta resta disponibile fra le opzioni del libro."
    }
    public static func informazioni(_ d: ArchivedDocument, provenienza: ProvenienzaScansione?, offerta: Bool, precedente: Bool) -> String {
        var righe: [String] = []
        if d.sourcePageCount > 0 { righe.append(d.sourcePageCount == 1 ? "Una pagina." : "\(d.sourcePageCount) pagine.") }
        if let provenienza {
            let r = ParoleScansioni.riga(provenienza)
            righe.append(r.prefix(1).uppercased() + r.dropFirst() + ".")
        } else {
            righe.append("Testo dal PDF.")
        }
        if offerta { righe.append("C'è una lettura migliore disponibile: la trovi fra le opzioni del libro.") }
        if precedente { righe.append("La lettura di prima è ancora sul Mac: puoi tenerla o tornarci fra le opzioni del libro.") }
        return righe.joined(separator: " ")
    }
}

/// Ciò che l'offerta fa (preparazione, arrivo, scelta), sopra la libreria del Mac. Le finestre sono fogli della Home.
@MainActor
public final class OffertaMac {
    let libreria: LibreriaMac
    public weak var fornitore: FornitoreLetturaMigliore?
    /// La finestra su cui si aprono i fogli (la Home).
    public weak var finestra: NSWindow?
    /// Avvisa la Home che c'è una lettura arrivata (mostra «Apri ora» per quel libro); nil = nessuna.
    public var quandoArriva: ((String?) -> Void)?
    /// Solo prove: gli annunci, invece di VoiceOver.
    public var annunciPerProva: ((String) -> Void)?
    /// Solo prove: le scelte dei fogli, invece delle finestre (id del foglio → indice del pulsante).
    public var scelteDiProva: ((String) -> Int)?

    public init(libreria: LibreriaMac) { self.libreria = libreria }

    private var service: LibraryService { libreria.service }

    func annuncia(_ testo: String) {
        if let annunciPerProva { annunciPerProva(testo); return }
        NSAccessibility.post(element: (finestra ?? NSApp.mainWindow) as Any, notification: .announcementRequested,
                             userInfo: [.announcement: testo, .priority: NSAccessibilityPriorityLevel.high.rawValue])
    }

    // MARK: Preparazione

    /// «Prepara una lettura migliore…»: i modelli per ruolo, col predefinito già scelto, poi la preparazione in sottofondo.
    public func chiediPreparazione(_ d: ArchivedDocument) {
        guard let fornitore, service.hasArchivedPDF(forDocumentId: d.id) else { return }
        let pdf = service.archivedPDFURL(forDocumentId: d.id)
        let ruoli = fornitore.ruoli(pdf: pdf)
        let a = NSAlert()
        a.messageText = ParoleLetturaMigliore.preparaTitolo
        a.informativeText = ParoleLetturaMigliore.preparaSpiegazione(d.title)
        a.addButton(withTitle: ParoleLetturaMigliore.prepara)
        let annulla = a.addButton(withTitle: ParoleLetturaMigliore.annulla)
        annulla.keyEquivalent = "\u{1b}"
        var menu: [(String, NSPopUpButton)] = []
        let pila = NSStackView()
        pila.orientation = .vertical
        pila.alignment = .leading
        for r in ruoli {
            let etichetta = NSTextField(labelWithString: r.ruolo)
            etichetta.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
            let p = NSPopUpButton(frame: .zero, pullsDown: false)
            for s in r.scelte { p.addItem(withTitle: s.nome); p.lastItem?.representedObject = s.id }
            if let k = r.scelte.firstIndex(where: { $0.id == r.predefinito }) { p.selectItem(at: k) }
            p.setAccessibilityLabel(r.ruolo)
            p.isEnabled = r.scelte.count > 1
            pila.addArrangedSubview(etichetta)
            pila.addArrangedSubview(p)
            if let nota = r.nota { pila.addArrangedSubview(NSTextField(wrappingLabelWithString: nota)) }
            menu.append((r.ruolo, p))
        }
        pila.frame = NSRect(x: 0, y: 0, width: 360, height: max(40, CGFloat(ruoli.count) * 64))
        a.accessoryView = pila
        a.window.setAccessibilityIdentifier("prepara.finestra")
        mostra(a, id: "prepara") { [weak self] k in
            guard let self, k == 0 else { return }
            var scelte: [String: String] = [:]
            for (ruolo, p) in menu { scelte[ruolo] = p.selectedItem?.representedObject as? String }
            self.prepara(d, scelte: scelte)
        }
    }

    /// Prepara in sottofondo e, quando è pronta, la fa arrivare (o dice che il libro non cambierebbe).
    public func prepara(_ d: ArchivedDocument, scelte: [String: String]) {
        guard let fornitore, !libreria.inPreparazione.contains(d.id) else { return }
        let pdf = service.archivedPDFURL(forDocumentId: d.id)
        let granularita = service.requiredCacheGranularity(for: d)
            ?? PreferenzeLettura.granularita(libreria.prefs, isAkn: d.sourceKind == "akn", large: service.isLarge(d))
        libreria.inPreparazione.insert(d.id)
        libreria.avvisa()
        fornitore.prepara(pdf: pdf, scelte: scelte, granularita: granularita) { [weak self] esito in
            guard let self else { return }
            self.libreria.inPreparazione.remove(d.id)
            switch esito {
            case .success(let pronta): self.arriva(pronta.lettura, righe: pronta.righe, per: d.id, provenienza: pronta.provenienza)
            case .failure(let e): self.annuncia(ParoleLetturaMigliore.nonRiuscita(d.title, e.localizedDescription)); self.libreria.avvisa()
            }
        }
    }

    // MARK: Arrivo

    /// Una lettura migliore è pronta per il libro `id` (dal menu del libro o dall'officina). Se cambia la lettura, entra
    /// nell'offerta: annuncio, «Apri ora», segno nella riga. Se non cambia nulla, lo dice e non offre niente.
    @discardableResult
    public func arriva(_ lettura: PackagedReading, righe: [String], per id: String, il data: Date = Date(),
                       provenienza: ProvenienzaScansione? = nil) -> Bool {
        guard let d = service.store.document(id: id) else { return false }
        let attuale = service.loadCache(forDocumentId: id)
        guard cambierebbe(lettura, attuale: attuale, righe: righe) else {
            // Uguale a quella in uso: un'offerta vecchia per questo libro non vale più.
            libreria.offerte.togli(id)
            annuncia(attuale == nil ? ParoleLetturaMigliore.nienteDiNuovo(d.title) : ParoleLetturaMigliore.nienteDaCambiare(d.title))
            libreria.avvisa()
            return false
        }
        guard libreria.offerte.salva(LetturaMiglioreInAttesa(creata: data, righe: righe, lettura: lettura, provenienza: provenienza),
                                     per: id) else { return false }
        libreria.avvisa()
        quandoArriva?(id)
        annuncia(ParoleLetturaMigliore.arrivata(d.title))
        return true
    }

    /// Vero se i blocchi della lettura pronta (quelli che VoiceOver legge) non coincidono coi blocchi della cache del libro.
    /// Senza cache da confrontare (volume enorme) decide ciò che l'officina ha fatto in più.
    public func cambierebbe(_ lettura: PackagedReading, id: String, righe: [String]) -> Bool {
        cambierebbe(lettura, attuale: service.loadCache(forDocumentId: id), righe: righe)
    }

    func cambierebbe(_ lettura: PackagedReading,
                     attuale: (content: PaginatedContent, pageMap: [String: Int], doctrineContent: PaginatedContent?,
                               quickConsultTree: [QuickConsultNode]?, contentTarget: Int?)?,
                     righe: [String]) -> Bool {
        guard let attuale else { return !righe.isEmpty }
        return attuale.content.pages.flatMap { $0.segments } != lettura.content.pages.flatMap { $0.segments }
            || attuale.doctrineContent?.pages.flatMap { $0.segments } != lettura.doctrineContent?.pages.flatMap { $0.segments }
    }

    // MARK: L'offerta

    /// La schermata dell'offerta: cosa arriva, le annotazioni, due gesti per accettare.
    public func apriOfferta(_ id: String) {
        guard let d = service.store.document(id: id), let l = libreria.offerte.inAttesa(id) else { return }
        quandoArriva?(nil)
        let a = NSAlert()
        a.messageText = ParoleLetturaMigliore.titoloOfferta(d.title)
        a.informativeText = ParoleLetturaMigliore.cosaArriva(d.title, data: l.creata, righe: l.righe) + "\n\n"
            + ParoleLetturaMigliore.annotazioni(segnalibri: d.bookmarks?.count ?? 0, sottolineature: d.underlines?.count ?? 0)
        a.addButton(withTitle: ParoleLetturaMigliore.usa)
        a.addButton(withTitle: ParoleLetturaMigliore.nonOra).keyEquivalent = "\u{1b}"
        a.addButton(withTitle: ParoleLetturaMigliore.togli)
        a.window.setAccessibilityIdentifier("offerta.finestra")
        mostra(a, id: "offerta") { [weak self] k in
            guard let self else { return }
            switch k {
            case 0: self.confermaUso(id)
            case 2: self.confermaTogli(id)
            default: break
            }
        }
    }

    private func confermaUso(_ id: String) {
        guard let d = service.store.document(id: id) else { return }
        let a = NSAlert()
        a.messageText = ParoleLetturaMigliore.confermaTitolo
        a.informativeText = ParoleLetturaMigliore.confermaTesto(d.title)
        let annulla = a.addButton(withTitle: ParoleLetturaMigliore.annulla)    // preferito: Invio annulla
        annulla.keyEquivalent = "\r"
        let usa = a.addButton(withTitle: ParoleLetturaMigliore.confermaAzione)
        usa.keyEquivalent = ""
        a.window.setAccessibilityIdentifier("offerta.conferma")
        mostra(a, id: "offerta.conferma") { [weak self] k in
            guard let self, k == 1 else { return }
            self.usa(id)
        }
    }

    private func confermaTogli(_ id: String) {
        guard let d = service.store.document(id: id) else { return }
        let a = NSAlert()
        a.messageText = ParoleLetturaMigliore.togliTitolo
        a.informativeText = ParoleLetturaMigliore.togliTesto(d.title)
        let annulla = a.addButton(withTitle: ParoleLetturaMigliore.annulla)
        annulla.keyEquivalent = "\r"
        let togli = a.addButton(withTitle: ParoleLetturaMigliore.togliAzione)
        togli.keyEquivalent = ""
        mostra(a, id: "offerta.togli") { [weak self] k in
            guard let self, k == 1 else { return }
            self.libreria.offerte.togli(id)
            self.libreria.avvisa()
        }
    }

    /// Usa la lettura migliore: la lettura di adesso si mette da parte, la nuova si scrive, le annotazioni si riancorano per
    /// contenuto; poi l'esito con «Tieni», «Torna alla lettura precedente», «Decidi più tardi». Ritorna il rapporto del
    /// riancoraggio, o nil se il libro è rimasto com'era.
    @discardableResult
    public func usa(_ id: String, mostraEsito: Bool = true) -> ReanchorReport? {
        guard let prima = service.store.document(id: id), let l = libreria.offerte.inAttesa(id) else { return nil }
        if let cached = service.loadCache(forDocumentId: id) {
            service.mintMissingAnchors(documentId: id, in: ContentAnchorIndex(segments: cached.content.pages.flatMap { $0.segments }))
        }
        // Una finestra di lettura aperta su questo libro si chiude prima (salva la sua posizione sulla lettura di adesso): così
        // la posizione si riancora insieme alle annotazioni, sulla lettura nuova (§ 12.14).
        for f in libreria.quandoCambiaLettura { f(id) }
        let hadPrevious = service.hasPreviousReading(forDocumentId: id)
        guard let snapshot = service.store.readingSnapshot(documentId: id),
              (try? service.stashPreviousReading(snapshot, forDocumentId: id)) != nil else { return nil }
        let r = l.lettura
        guard service.writeCache(r.content, pageMap: r.pageMap, doctrineContent: r.doctrineContent,
                                 quickConsultTree: r.quickConsultTree, contentTarget: r.contentTarget, forDocumentId: id) else {
            if !hadPrevious { service.discardPreviousReading(forDocumentId: id) }
            return nil
        }
        // L'origine «lettura del Mac», come una lettura arrivata dal Mac sull'iPad (§ 12.12, decisione 3): un cambio di
        // granularità non la fa rielaborare in silenzio con la catena senza modelli (`requiredCacheGranularity`).
        service.store.recordReceivedReading(id: id, systemVersion: SystemGeneration.current, cureLevel: ProcessingChain.cureLevel,
                                            at: Date(), visualResourcesSkipped: nil)
        if let p = l.provenienza { libreria.provenienze.registra(p, per: id) }
        let corrente = service.store.document(id: id) ?? prima
        let rapporto = AnnotationReanchoring.reanchor(
            bookmarks: corrente.bookmarks ?? [], underlines: corrente.underlines ?? [], readingPosition: corrente.readingPosition,
            readingAnchor: corrente.readingAnchor, in: ContentAnchorIndex(segments: r.content.pages.flatMap { $0.segments })).report
        service.reanchorAfterProcessing(documentId: id, content: r.content)
        libreria.offerte.togli(id)
        libreria.avvisa()
        if mostraEsito {
            let a = NSAlert()
            a.messageText = ParoleLetturaMigliore.esitoTitolo
            a.informativeText = ParoleLetturaMigliore.esito(rapporto, segnalibri: corrente.bookmarks?.count ?? 0,
                                                            sottolineature: corrente.underlines?.count ?? 0)
            a.addButton(withTitle: ParoleLetturaMigliore.tieni)
            a.addButton(withTitle: ParoleLetturaMigliore.torna)
            a.addButton(withTitle: ParoleLetturaMigliore.piuTardi).keyEquivalent = "\u{1b}"
            a.window.setAccessibilityIdentifier("offerta.esito")
            mostra(a, id: "offerta.esito") { [weak self] k in
                switch k {
                case 0: self?.chiediTieni(id)
                case 1: self?.torna(id)
                default: self?.annuncia(ParoleLetturaMigliore.rimandata)
                }
            }
        }
        return rapporto
    }

    public func chiediTieni(_ id: String) {
        let a = NSAlert()
        a.messageText = ParoleLetturaMigliore.tieniTitolo
        a.informativeText = ParoleLetturaMigliore.tieniTesto
        let annulla = a.addButton(withTitle: ParoleLetturaMigliore.annulla)
        annulla.keyEquivalent = "\r"
        let tieni = a.addButton(withTitle: ParoleLetturaMigliore.tieni)
        tieni.keyEquivalent = ""
        mostra(a, id: "offerta.tieni") { [weak self] k in
            guard let self, k == 1 else { return }
            self.service.discardPreviousReading(forDocumentId: id)
            self.annuncia(ParoleLetturaMigliore.confermata)
            self.libreria.avvisa()
        }
    }

    /// Torna alla lettura di prima: le annotazioni fatte dopo non si perdono (§ 12.14).
    public func torna(_ id: String) {
        for f in libreria.quandoCambiaLettura { f(id) }
        guard let snapshot = service.restorePreviousCache(forDocumentId: id) else { return }
        let restored = service.loadCache(forDocumentId: id).map { ContentAnchorIndex(segments: $0.content.pages.flatMap { $0.segments }) }
        let r = service.store.restore(snapshot, documentId: id, restoredContent: restored)
        var msg = ParoleLetturaMigliore.tornato
        if r.carried > 0 {
            msg += r.orphaned == 0 ? " Anche le annotazioni fatte dopo il cambio di lettura sono al loro posto."
                : " Delle annotazioni fatte dopo il cambio di lettura, \(r.orphaned) sono da ricollocare."
        }
        annuncia(msg)
        libreria.avvisa()
    }

    public func informazioni(_ d: ArchivedDocument) {
        let a = NSAlert()
        a.messageText = d.title
        a.informativeText = ParoleLetturaMigliore.informazioni(
            d, provenienza: libreria.provenienze.provenienza(d.id), offerta: libreria.offerte.libri.contains(d.id),
            precedente: service.hasPreviousReading(forDocumentId: d.id))
        a.addButton(withTitle: LibraryWording.errorDismiss)
        a.window.setAccessibilityIdentifier("informazioni.finestra")
        mostra(a, id: "informazioni") { _ in }
    }

    /// Un foglio sulla Home (o la scelta di prova).
    private func mostra(_ a: NSAlert, id: String, _ esito: @escaping (Int) -> Void) {
        if let scelteDiProva { esito(scelteDiProva(id)); return }
        let rispondi: (NSApplication.ModalResponse) -> Void = { r in esito(r.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue) }
        if let finestra { a.beginSheetModal(for: finestra, completionHandler: rispondi) } else { rispondi(a.runModal()) }
    }
}
