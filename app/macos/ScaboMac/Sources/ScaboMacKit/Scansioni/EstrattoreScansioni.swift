//
//  EstrattoreScansioni.swift
//  ScaboMacKit — l'estrattore del Mac per i PDF con pagine scansionate (giro «modelli e scansioni», 2026-11-18). Avvolge
//  quello di PDFKit (ScaboChain `PdfKitExtractor`, lo stesso dell'iPad): le pagine con testo restano IDENTICHE; solo le pagine
//  senza testo si leggono col lettore scelto (`LetturaScansioni`). Un PDF misto si legge per intero.
//
//  Se GLM-OCR non c'è, non si carica o la memoria non basta, l'estrattore lo dice in prosa (l'errore arriva alla catena come
//  ogni errore d'estrazione) e lascia il motivo in `problema`, così l'importazione non si chiude e propone l'altro lettore.
//  Se GLM-OCR non riesce su una pagina sola, quella pagina tiene la lettura di Apple (contata nel rapporto).
//

import Darwin
import Foundation
import PDFKit
import ScaboChain
import ScaboCore
import ScaboMacOCR
import ScaboPageStructure

public final class EstrattoreScansioni: ProgressReportingPdfExtractor, FonteRisorseScansioni {

    /// Perché la lettura delle scansioni non è partita (il testo è quello che l'importazione mostra).
    public enum Problema: Error, LocalizedError, Equatable, Sendable {
        case memoriaInsufficiente(disponibileGB: Int)
        case modelloNonInstallato
        case modelloNonCaricato
        case pdfNonLeggibile

        public var errorDescription: String? {
            switch self {
            case .memoriaInsufficiente(let gb):
                return "Per leggere le scansioni con GLM lettura pagine servono circa \(EstrattoreScansioni.memoriaGlmGB) gigabyte di memoria libera, "
                    + "e adesso il Mac ne ha circa \(gb). Puoi chiudere altre app e riprovare, oppure leggere le scansioni con la "
                    + "lettura del testo di Apple, che chiede molta meno memoria."
            case .modelloNonInstallato:
                return "GLM lettura pagine non è installato su questo Mac. Puoi scaricarlo dal pannello dei modelli, oppure leggere le "
                    + "scansioni con la lettura del testo di Apple."
            case .modelloNonCaricato:
                return "GLM lettura pagine non si è caricato, forse per la memoria o per un file del modello danneggiato. Puoi leggere le "
                    + "scansioni con la lettura del testo di Apple, oppure verificare il modello nel pannello dei modelli."
            case .pdfNonLeggibile:
                return "Le pagine scansionate di questo PDF non si riescono ad aprire per leggerle."
            }
        }

        /// Vero se l'altro lettore può risolvere (i problemi di GLM-OCR).
        public var propostaAltroLettore: Bool { self != .pdfNonLeggibile }
    }

    /// Ciò che la lettura ha fatto, senza testo (registro, riga della libreria, referto del banco).
    public struct Rapporto: Codable, Sendable, Equatable {
        public var lettore: LettoreScansioni
        public var via: ViaScansioni
        public var pagine: Int
        public var pagineLette: Int
        /// Pagine in cui GLM-OCR non è riuscito e resta la lettura di Apple.
        public var pagineSoloApple: Int
        public var secondi: Double
        public var secondiPrimaPagina: Double?
        public var guardia: [String: Int]
    }

    /// La memoria libera che serve a GLM-OCR (misurata al banco: circa 7,5 GB al massimo, referto del giro § 2).
    public static let memoriaGlmGB = 8

    public let lettore: LettoreScansioni
    public let via: ViaScansioni
    public private(set) var problema: Problema?
    public private(set) var rapporto: Rapporto?
    /// Solo banco: cartella del laboratorio dove scrivere le pagine lette (con il loro testo: mai nel repo).
    public var cartellaBanco: URL?
    /// Solo banco: cartella del laboratorio col testo di GLM-OCR già letto (si riusa se c'è, si scrive se manca).
    public var cacheGlm: URL?
    /// Le migliorie del giro «migliorie del banco nelle app» (2026-11-21), tutte accese di serie (`MiglioriScansioni`); le spegne solo
    /// la riga di comando del laboratorio.
    public var migliorie = MiglioriScansioni()
    /// Le tabelle e le figure viste dal modello d'impaginazione sulle pagine lette e messe nell'estrazione, come candidate delle risorse
    /// visive della catena (miglioria `tabelle`; vuoto se spenta o se non ne ha viste). Si leggono dopo `extract`.
    public private(set) var candidateRisorse: [VisualRegionCandidate] = []
    /// Le pagine (0-based) lette dal lettore e messe nell'estrazione, dopo `extract`.
    public private(set) var pagineLette: [Int] = []
    /// Le candidate di ogni pagina letta (anche di quelle poi lasciate com'erano in un PDF misto), prima della scelta delle pagine.
    private var candidatePerPagina: [Int: [VisualRegionCandidate]] = [:]

    // MARK: Solo laboratorio (giro 2 del banco OCR, 2026-11-19): osservazione e varianti, spente di serie

    /// SOLO LABORATORIO: le varianti sperimentali (`VariantiScansioni`), tutte spente di serie; l'app non le tocca mai.
    public var varianti = VariantiScansioni()
    /// SOLO LABORATORIO: la cartella dove l'estrattore scrive, per ogni pagina letta, ciò che vede a ogni passo (righe grezze di
    /// Apple, tabelle della richiesta di Apple, regioni di Heron, righe ordinate, testo di GLM, righe dopo la guardia). Mai impostata
    /// dall'app; contiene il testo delle pagine: solo nel laboratorio.
    public var cartellaOsservazione: URL?
    /// SOLO LABORATORIO (variante D): raccogliere le regioni di tabella e di figura viste sulle pagine lette, per passarle alla catena
    /// come candidate delle risorse visive. Spento di serie.
    public var raccogliTabelle = false
    /// SOLO LABORATORIO: il modello d'impaginazione da usare al posto di Heron (un `.mlmodelc` con le stesse etichette e la stessa
    /// forma d'uscita, per esempio docling-layout-egret convertito con la via di Heron), per misurarlo al banco dentro la via dell'app.
    /// Mai impostato dall'app: di serie il modello incluso, Heron.
    public var modelloImpaginazione: URL?
    /// Le regioni raccolte con `raccogliTabelle`: quelle di Heron (tabella, figura) e le tabelle della richiesta di Apple.
    public private(set) var tabelleHeron: [VisualRegionCandidate] = []
    public private(set) var tabelleApple: [VisualRegionCandidate] = []

    /// Ciò che l'estrattore osserva su una pagina letta (solo laboratorio).
    public struct OsservazionePagina: Codable, Sendable {
        public struct Regione: Codable, Sendable { public var tipo: String; public var bbox: BBox }
        public var pagina: Int
        public var larghezza: Double
        public var altezza: Double
        public var varianti: [String]
        /// P1: le righe della lettura di Apple, nell'ordine della richiesta (prima di ogni ordine di Heron).
        public var righeGrezze: [RigaLetta]
        /// P1: le tabelle che la richiesta dei documenti di Apple vede (vuoto con la richiesta classica).
        public var tabelleApple: [BBox]
        /// P3: le regioni di Heron sull'immagine della pagina, nel loro ordine di lettura.
        public var regioniHeron: [Regione]
        /// P3: le righe con regione e tipo, nell'ordine della pagina (dopo la variante F, se accesa).
        public var righeOrdinate: [RigaLetta]
        /// P1 di GLM: il suo testo grezzo; P2: le righe dopo la guardia (uguali a `righeOrdinate` senza GLM).
        public var testoGlm: String?
        public var righeFinali: [RigaLetta]
        public var guardia: [String: Int]?
        public var sillabateUnite: Int?
    }

    private let pesiGlm: (pesi: URL, proiettore: URL)?

    public init(lettore: LettoreScansioni, via: ViaScansioni? = nil, pesiGlm: (pesi: URL, proiettore: URL)? = nil) {
        self.lettore = lettore
        self.via = via ?? ViaScansioni.predefinita(per: lettore)
        self.pesiGlm = pesiGlm
    }

    /// QUANDO SI LEGGE (regola unica, la usano l'importazione, la lettura migliore e l'officina). Un PDF ha scansioni da leggere
    /// se è quasi tutto senza testo (80 per cento), o se almeno un quinto delle pagine (e almeno 3) è senza testo, o se ce ne
    /// sono almeno 10 di seguito. Al banco (campo, 2026-11-18) i 55 PDF
    /// con testo (52 volumi e 3 documenti di studio) hanno al più il 5,7 per cento di pagine senza testo e al più 8 di seguito:
    /// copertine, pagine bianche, figure; su di loro la regola non scatta, e l'importazione resta quella dell'iPad, al byte.
    public static func serveLettura(senzaTesto: [Int], totale: Int) -> Bool {
        guard totale > 0, !senzaTesto.isEmpty else { return false }
        // Un PDF breve con una figura a tutta pagina non è una scansione: un quinto vale solo con almeno 3 pagine senza testo;
        // un PDF quasi tutto senza testo (80 per cento) lo è sempre, anche di una pagina (rilievo della revisione del giro).
        if scansioneIntera(senzaTesto: senzaTesto.count, totale: totale) { return true }
        if senzaTesto.count >= 3, Double(senzaTesto.count) >= 0.2 * Double(totale) { return true }
        var serie = 0, massima = 0, prec = -2
        for i in senzaTesto.sorted() { serie = i == prec + 1 ? serie + 1 : 1; massima = max(massima, serie); prec = i }
        return massima >= 10
    }

    /// Un PDF tutto (o quasi tutto: 80 per cento) scansionato si legge per intero; in un PDF misto una pagina letta entra solo
    /// se è una pagina di testo (almeno 10 righe e 300 caratteri), non una copertina o una figura (guardia sulla lettura).
    public static func scansioneIntera(senzaTesto: Int, totale: Int) -> Bool {
        totale > 0 && Double(senzaTesto) >= 0.8 * Double(totale)
    }

    static func paginaDiTesto(_ righe: [RigaLetta]) -> Bool {
        righe.count >= 10 && righe.reduce(0) { $0 + $1.testo.count } >= 300
    }

    /// Una pagina è «senza testo» se l'estrazione di PDFKit non vi trova nemmeno un carattere visibile.
    public static func senzaTesto(_ p: PdfPageExtraction) -> Bool {
        !p.lines.contains { l in l.spans.contains { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } }
    }

    /// La memoria che il Mac può dare adesso (libera, inattiva, eliminabile), in byte.
    public static func memoriaDisponibile() -> UInt64? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let r = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count) }
        }
        guard r == KERN_SUCCESS else { return nil }
        let pagine = UInt64(stats.free_count) + UInt64(stats.inactive_count) + UInt64(stats.purgeable_count) + UInt64(stats.speculative_count)
        return pagine * UInt64(vm_kernel_page_size)
    }

    /// Solo prove: la memoria disponibile simulata (byte).
    nonisolated(unsafe) public static var memoriaSimulata: UInt64?

    /// GLM lettura pagine una pagina alla volta in tutta l'app (importazione, lettura migliore e officina possono partire
    /// insieme; il motore ha uno stato globale e la memoria basta per una lettura sola).
    static let filaGlm = NSLock()

    /// Vero dopo che GLM non si è caricato a libro iniziato: le pagine che restano le legge Apple, invece di ricominciare.
    private var glmFermo = false
    /// Vero dopo la prima pagina letta in questa estrazione.
    private var primaPaginaLetta = false

    public func extract(fromUri uri: String, onPageExtracted: (Int, Int) -> Void, isCancelled: () -> Bool) throws -> PdfExtraction? {
        problema = nil
        rapporto = nil
        glmFermo = false
        primaPaginaLetta = false
        tabelleHeron = []
        tabelleApple = []
        candidateRisorse = []
        pagineLette = []
        candidatePerPagina = [:]
        let t0 = Date()
        guard var ex = try PdfKitExtractor().extract(fromUri: uri, onPageExtracted: { _, _ in }, isCancelled: isCancelled) else {
            return nil
        }
        let vuote = ex.pages.filter(Self.senzaTesto).map { $0.pageIndex }
        let totale = ex.pageCount
        var fatte = totale - vuote.count
        onPageExtracted(fatte, totale)
        var conti: [String: Int] = [:]
        var soloApple = 0
        var primaPagina: Double?
        var lette: [PaginaLetta] = []
        defer {
            rapporto = Rapporto(lettore: lettore, via: via, pagine: totale, pagineLette: lette.count, pagineSoloApple: soloApple,
                                secondi: Date().timeIntervalSince(t0), secondiPrimaPagina: primaPagina, guardia: conti)
        }
        // Un PDF con testo (anche con copertine, pagine bianche o figure) resta quello dell'iPad, al byte.
        guard Self.serveLettura(senzaTesto: vuote, totale: totale) else { onPageExtracted(totale, totale); return ex }
        let intera = Self.scansioneIntera(senzaTesto: vuote.count, totale: totale)
        if lettore == .glm {
            guard let pesiGlm, FileManager.default.fileExists(atPath: pesiGlm.pesi.path),
                  FileManager.default.fileExists(atPath: pesiGlm.proiettore.path) else {
                problema = .modelloNonInstallato; throw Problema.modelloNonInstallato
            }
            if cacheGlm == nil, let libera = Self.memoriaSimulata ?? Self.memoriaDisponibile(),
               libera < UInt64(Self.memoriaGlmGB) << 30 {
                let p = Problema.memoriaInsufficiente(disponibileGB: Int(libera >> 30))
                problema = p; throw p
            }
        }
        let url = uri.hasPrefix("file:") ? (URL(string: uri) ?? URL(fileURLWithPath: uri)) : URL(fileURLWithPath: uri)
        guard let doc = PDFDocument(url: url) else { problema = .pdfNonLeggibile; throw Problema.pdfNonLeggibile }
        let heron: HeronLayoutModel?
        if via == .v1 { heron = nil }
        else if let altro = modelloImpaginazione { heron = try? HeronLayoutModel(modelURL: altro) }   // solo laboratorio
        else { heron = try? HeronLayoutModel.bundled() }
        for indice in vuote {
            if isCancelled() { return nil }
            let tp = Date()
            var errore: Error?
            let letta: PaginaLetta? = autoreleasepool {
                do { return try leggi(doc: doc, indice: indice, heron: heron, isCancelled: isCancelled, soloApple: &soloApple) }
                catch { errore = error; return nil }
            }
            if let errore {
                if case GlmOcr.Problema.annullata = errore { return nil }
                if let p = errore as? Problema { problema = p }
                throw errore
            }
            if let letta {
                if intera || Self.paginaDiTesto(letta.righe) {
                    lette.append(letta)
                    for (k, v) in letta.guardia ?? [:] { conti[k, default: 0] += v }
                } else {
                    conti["pagine_non_di_testo", default: 0] += 1   // copertina o figura in un PDF misto: resta com'è
                }
            }
            if primaPagina == nil { primaPagina = Date().timeIntervalSince(tp) }
            primaPaginaLetta = true
            fatte += 1
            onPageExtracted(fatte, totale)
        }
        for (indice, pagina) in LetturaScansioni.pagineEstratte(lette, migliorie: migliorie) where indice < ex.pages.count {
            ex.pages[indice] = pagina
        }
        pagineLette = lette.map { $0.pagina }.filter { $0 < ex.pages.count }
        candidateRisorse = pagineLette.flatMap { candidatePerPagina[$0] ?? [] }
        // Variante E (solo laboratorio, spenta nell'app): la porta dei rami dei codici (formato tascabile 357 × 547 punti con 12 di
        // tolleranza, produttore PDFsharp, corpo fra 6,5 e 8,5: ScaboCore `GenericPlugin`) su una scansione non scatta, perché il file
        // non porta il produttore; la variante lo dichiara quando la geometria della prima pagina è quella dei codici.
        if varianti.ramiCodici { ex = Self.portaCodiciAperta(ex) }
        return ex
    }

    /// Variante E (solo laboratorio): l'estrazione con il produttore dei codici dichiarato, se la prima pagina ha la geometria dei
    /// codici; altrimenti identica.
    static func portaCodiciAperta(_ ex: PdfExtraction) -> PdfExtraction {
        guard let p = ex.pages.first, abs(p.width - 357) <= 12, abs(p.height - 547) <= 12 else { return ex }
        var e = ex
        e.producer = (ex.producer.map { $0 + " " } ?? "") + "PDFsharp"
        return e
    }

    /// Una regione «tabella» delle scansioni va alla catena solo se è larga almeno un quarto della pagina e contiene almeno due righe.
    static func tabellaAmmessa(_ b: BBox, _ righe: [RigaLetta], larghezza W: Double) -> Bool {
        b.width >= 0.25 * W && righeDentro(b, righe) >= 2
    }

    /// Quante righe lette hanno il centro dentro la regione (stesso spazio: origine in basso a sinistra).
    static func righeDentro(_ b: BBox, _ righe: [RigaLetta]) -> Int {
        righe.filter { r in
            let cx = r.bbox.x + r.bbox.width / 2, cy = r.bbox.y + r.bbox.height / 2
            return cx >= b.x && cx <= b.x + b.width && cy >= b.y && cy <= b.y + b.height
        }.count
    }

    /// Una regione (riquadro con origine in basso a sinistra) come candidata delle risorse visive della catena (origine in alto a
    /// sinistra, `[l, t, r, b]`). Solo laboratorio, variante D: il punteggio del modello non arriva fin qui (la guardia non lo usa).
    static func candidata(_ b: BBox, etichetta: String, pagina: Int, W: Double, H: Double) -> VisualRegionCandidate {
        VisualRegionCandidate(pageIndex: pagina, label: etichetta, bbox: [b.x, H - (b.y + b.height), b.x + b.width, H - b.y],
                              confidence: 1, pageWidth: W, pageHeight: H)
    }

    private func leggi(doc: PDFDocument, indice: Int, heron: HeronLayoutModel?, isCancelled: () -> Bool,
                       soloApple: inout Int) throws -> PaginaLetta? {
        guard let page = doc.page(at: indice), let img = LetturaScansioni.immagine(della: page) else { return nil }
        // La pagina come si mostra (ruotata, sul suo riquadro di ritaglio): lo spazio dell'immagine letta, quindi delle righe, delle
        // regioni e della pagina dell'estrazione (giro globale del banco OCR, 2026-11-19; uguale a prima sulle pagine diritte).
        let mostrata = LetturaScansioni.misuraMostrata(della: page)
        let W = Double(mostrata.width), H = Double(mostrata.height)
        let ta = Date()
        let letturaApple = try LetturaScansioni.letturaApple(img, larghezza: W, altezza: H, classica: varianti.richiestaClassica)
        let apple = letturaApple.righe
        let secondiApple = Date().timeIntervalSince(ta)
        let th = Date()
        var righe = apple
        var regioniViste: [(tipo: String, bbox: BBox)] = []
        if let heron, let regioni = try? LetturaScansioni.regioni(pagina: page, modello: heron) {
            regioniViste = regioni
            righe = LetturaScansioni.ordina(apple, regioni: regioni)
        } else {
            righe = LetturaScansioni.ordinaDallAlto(apple)
        }
        // Variante F (solo laboratorio, spenta nell'app): le sillabate a fine riga ricomposte prima della catena.
        var sillabateUnite: Int?
        if varianti.sillabateRicomposte {
            let r = LetturaScansioni.ricomponiSillabate(righe)
            righe = r.righe
            sillabateUnite = r.unite
        }
        // Variante D (solo laboratorio, spenta nell'app): le regioni di tabella e di figura raccolte per la catena.
        if raccogliTabelle {
            for r in regioniViste where r.tipo == "table" || r.tipo == "picture" {
                tabelleHeron.append(Self.candidata(r.bbox, etichetta: r.tipo, pagina: indice, W: W, H: H))
            }
            for t in letturaApple.tabelle { tabelleApple.append(Self.candidata(t, etichetta: "table", pagina: indice, W: W, H: H)) }
        }
        // Miglioria `tabelle` (giro «migliorie del banco nelle app»): le stesse regioni della variante D, per la catena dell'app; una
        // regione «tabella» solo se è larga almeno un quarto della pagina e contiene almeno due righe lette (misurato sul banco: il
        // modello chiama tabella anche un'intestazione incorniciata di una riga sola e una colonna stretta di numeri di un indice, e la
        // lettura le annunciava come tabelle; le tabelle vere del banco sono larghe dal 57 per cento della pagina in su).
        if migliorie.tabelle {
            candidatePerPagina[indice] = regioniViste.filter { $0.tipo == "picture" || ($0.tipo == "table" && Self.tabellaAmmessa($0.bbox, righe, larghezza: W)) }
                .map { Self.candidata($0.bbox, etichetta: $0.tipo, pagina: indice, W: W, H: H) }
        }
        let righeOrdinate = righe
        let secondiImpaginazione = Date().timeIntervalSince(th)
        var letta = PaginaLetta(pagina: indice, larghezza: W, altezza: H, righe: righe, testoGlm: nil,
                                secondiApple: secondiApple, secondiGlm: 0, secondiImpaginazione: secondiImpaginazione, guardia: nil)
        if lettore == .glm, let pesiGlm, !glmFermo {
            let fileGlm = cacheGlm?.appendingPathComponent("p\(indice).json")
            let salvata = fileGlm.flatMap { try? JSONDecoder().decode(PaginaLetta.self, from: Data(contentsOf: $0)) }
            var testo = salvata?.testoGlm
            letta.secondiGlm = salvata?.secondiGlm ?? 0
            // La memoria si guarda a ogni pagina: se a libro iniziato non basta più, questa pagina la legge Apple.
            let pocaMemoria = cacheGlm == nil && (Self.memoriaSimulata ?? Self.memoriaDisponibile()).map { $0 < UInt64(Self.memoriaGlmGB) << 30 } == true
            if testo == nil, pocaMemoria, primaPaginaLetta { soloApple += 1 }
            if testo == nil, !(pocaMemoria && primaPaginaLetta) {
                guard let png = LetturaScansioni.png(img) else { return letta }
                do {
                    Self.filaGlm.lock()
                    defer { Self.filaGlm.unlock() }
                    let l = try GlmOcr.leggi(png: png, pesi: pesiGlm.pesi, proiettore: pesiGlm.proiettore, annullata: isCancelled)
                    testo = l.testo
                    letta.secondiGlm = l.secondiCaricamento + l.secondiLettura
                    if let fileGlm {
                        try? FileManager.default.createDirectory(at: fileGlm.deletingLastPathComponent(), withIntermediateDirectories: true)
                        var c = letta; c.testoGlm = l.testo
                        try? JSONEncoder().encode(c).write(to: fileGlm)
                    }
                } catch GlmOcr.Problema.annullata {
                    throw GlmOcr.Problema.annullata
                } catch GlmOcr.Problema.pesiNonCaricati, GlmOcr.Problema.proiettoreNonCaricato, GlmOcr.Problema.contestoNonCreato {
                    // Alla prima pagina: l'importazione lo dice e propone Apple. A libro iniziato: Apple per le pagine che restano.
                    guard primaPaginaLetta else { problema = .modelloNonCaricato; throw Problema.modelloNonCaricato }
                    glmFermo = true
                    soloApple += 1
                } catch {
                    soloApple += 1   // questa pagina tiene la lettura di Apple
                }
            }
            if let testo {
                letta.testoGlm = testo
                // Variante B o C (solo laboratorio, spente nell'app); di serie (miglioria `glm`, giro «migliorie del banco nelle app») il
                // testo di GLM filtrato dalla notazione, senza la guardia stretta; con la miglioria spenta la guardia stretta di prima.
                var g: (righe: [RigaLetta], conti: [String: Int])
                if varianti.glmSenzaGuardia || varianti.guardiaLarga || !migliorie.glm {
                    g = varianti.glmSenzaGuardia ? LetturaScansioni.senzaGuardia(righe: righe, testoGlm: testo)
                        : LetturaScansioni.guardia(righe: righe, testoGlm: testo, larga: varianti.guardiaLarga)
                } else {
                    let filtrato = LetturaScansioni.senzaRipetizioni(LetturaScansioni.filtraNotazione(testo), righeApple: righe)
                    g = LetturaScansioni.senzaGuardia(righe: righe, testoGlm: filtrato.testo)
                    var c = g.conti
                    c["righe_ripetute_tolte"] = filtrato.tolte
                    g = (g.righe, c)
                }
                letta.righe = g.righe
                letta.guardia = g.conti
            }
        }
        if let dir = cartellaBanco {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try? JSONEncoder().encode(letta).write(to: dir.appendingPathComponent("p\(indice).json"))
        }
        if let dir = cartellaOsservazione {
            let o = OsservazionePagina(pagina: indice, larghezza: W, altezza: H, varianti: varianti.accese, righeGrezze: apple,
                                       tabelleApple: letturaApple.tabelle,
                                       regioniHeron: regioniViste.map { .init(tipo: $0.tipo, bbox: $0.bbox) },
                                       righeOrdinate: righeOrdinate, testoGlm: letta.testoGlm, righeFinali: letta.righe,
                                       guardia: letta.guardia, sillabateUnite: sillabateUnite)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try? JSONEncoder().encode(o).write(to: dir.appendingPathComponent("o\(indice).json"))
        }
        return letta
    }
}
