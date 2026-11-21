//
//  LetturaScansioni.swift
//  ScaboMacKit — LA LETTURA DELLE SCANSIONI SUL MAC (giro «modelli e scansioni», 2026-11-18; LAYER2 § 12.16, decisione 21).
//
//  Una pagina senza testo non fa più fallire il libro: la legge un lettore delle scansioni, e le righe lette entrano nella
//  STESSA catena dell'iPad (classificazione, note, granularità, cure) come se le avesse date PDFKit. Il punto d'innesto è
//  l'estrattore (`ProgressReportingPdfExtractor`, ScaboChain): questo file ne dà uno che avvolge quello di PDFKit e riempie
//  solo le pagine vuote. La catena condivisa, il modulo dell'impaginazione e il controllo dell'iPad non cambiano.
//
//  Il nodo: la catena usa la geometria delle righe e la tipografia, i lettori danno testo. Le vie misurate al banco del
//  laboratorio (`scansioni_costruite`, referto del giro):
//    v1  Apple — le righe della lettura del testo di Apple, con i loro riquadri, nell'ordine dei paragrafi che dà Apple;
//    v5  Apple + impaginazione — le stesse righe, nell'ordine e coi tipi delle regioni del modello d'impaginazione (Heron,
//        il porto Swift già nell'app) sull'immagine della pagina;
//    v2  GLM-OCR + Apple + impaginazione — il testo di GLM-OCR sulla geometria delle righe di Apple, attraverso la GUARDIA:
//        una parola di GLM entra solo se corregge una parola che Apple ha visto nello stesso punto; ciò che GLM aggiunge
//        dove Apple non ha visto nulla non entra (le parole inventate pesano più di tutte).
//  Ogni verdetto di un modello passa da una guardia deterministica: l'ordine delle regioni del modello d'impaginazione vale
//  solo se le regioni contengono almeno l'80 per cento delle righe; il tipo «titolo» diventa grassetto solo su righe brevi e
//  isolate; un numero attaccato a una parola diventa richiamo di nota solo se una nota con quel numero comincia sulla stessa
//  pagina.
//
//  La dimensione del carattere viene dall'altezza delle righe, raggruppata in poche misure per tutto il documento (la catena
//  ragiona per gruppi di dimensioni: rumore di mezzo punto la confonderebbe).
//
//  Nessuna rete: le immagini e i modelli restano sul Mac.
//

import CoreGraphics
import Foundation
import ImageIO
import PDFKit
import ScaboChain
import ScaboCore
import ScaboMacOCR
import ScaboPageStructure
import UniformTypeIdentifiers
import Vision

// MARK: - Le scelte

/// Il lettore delle scansioni (nelle parole dell'app: «lettura delle scansioni», mai la sigla).
public enum LettoreScansioni: String, Codable, CaseIterable, Sendable {
    /// La lettura del testo di Apple (Vision, nel sistema).
    case apple
    /// GLM-OCR (scaricato dal pannello dei modelli), con la geometria e la guardia della lettura di Apple.
    case glm

    /// Il nome nelle parole dell'app: quello della scheda del catalogo (`catalogo.json`), così si ritrova nel pannello.
    public var nome: String {
        switch self {
        case .apple: return "lettura del testo di Apple"
        case .glm: return "GLM lettura pagine"
        }
    }

    /// La voce del catalogo dei modelli.
    public var voceCatalogo: String {
        switch self {
        case .apple: return "apple-vision-testo"
        case .glm: return "glm-ocr"
        }
    }
}

/// La via (solo banco e riga di comando; l'app usa `predefinita(per:)`).
public enum ViaScansioni: String, Codable, CaseIterable, Sendable {
    case v1, v5, v2

    /// La via dell'app per ciascun lettore, scelta con le misure del banco (referto del giro, § 2).
    public static func predefinita(per lettore: LettoreScansioni) -> ViaScansioni {
        lettore == .glm ? .v2 : .v5
    }
}

/// SOLO LABORATORIO (giro 2 del banco OCR, 2026-11-19, docs/BANCO_OCR.md § 17.1): le varianti sperimentali della lettura delle
/// scansioni, per misurare al banco quanto potrebbe cambiare la lettura senza cambiare modello. Tutte SPENTE di serie: l'app non le
/// accende mai e non le mostra; le accende solo la riga di comando del laboratorio (`scabomac-officina catena --variante …`). Con
/// tutte spente l'estrattore fa esattamente ciò che faceva (provato al byte sul banco delle scansioni e dalle reti del giro).
/// La variante D (tabelle passate come tabelle) non sta qui: la fa la riga di comando con le regioni raccolte dall'estrattore.
public struct VariantiScansioni: Codable, Equatable, Sendable {
    /// A: la richiesta classica del testo di Apple (`VNRecognizeTextRequest`, il ripiego che l'app ha già per i sistemi
    /// precedenti) al posto della struttura dei documenti.
    public var richiestaClassica = false
    /// B: GLM senza la guardia stretta: il testo di GLM è l'autorità, le righe di Apple solo ancore di posizione.
    public var glmSenzaGuardia = false
    /// C: la guardia di GLM più larga (parole aggiunte in mezzo a una riga di Apple; corse fra righe diverse se si somigliano).
    public var guardiaLarga = false
    /// E: la porta dei rami dei codici aperta sulle scansioni che hanno la geometria dei codici.
    public var ramiCodici = false
    /// F: le parole sillabate a fine riga ricomposte prima della catena.
    public var sillabateRicomposte = false

    public init() {}

    /// I nomi della riga di comando, nell'ordine.
    public static let nomi = ["classica", "senza-guardia", "guardia-larga", "codici", "sillabate"]

    /// Le varianti da un elenco di nomi della riga di comando (separati da virgole); nil se un nome non è noto.
    public init?(elenco: String) {
        for n in elenco.split(separator: ",").map({ $0.trimmingCharacters(in: .whitespaces) }) where !n.isEmpty {
            switch n {
            case "classica": richiestaClassica = true
            case "senza-guardia": glmSenzaGuardia = true
            case "guardia-larga": guardiaLarga = true
            case "codici": ramiCodici = true
            case "sillabate": sillabateRicomposte = true
            default: return nil
            }
        }
    }

    /// I nomi delle varianti accese (vuoto se tutte spente).
    public var accese: [String] {
        zip(Self.nomi, [richiestaClassica, glmSenzaGuardia, guardiaLarga, ramiCodici, sillabateRicomposte]).filter { $0.1 }.map { $0.0 }
    }
}

// MARK: - Le righe lette

/// Una riga letta su una pagina scansionata: testo, riquadro in punti PDF con origine in basso a sinistra (come `BBox` di
/// ScaboCore), la regione del modello d'impaginazione (ordine di lettura) e il suo tipo.
public struct RigaLetta: Codable, Equatable, Sendable {
    public var testo: String
    public var bbox: BBox
    public var regione: Int
    public var tipo: String?
    /// Quanti caratteri aveva la riga di Apple da cui viene la geometria, quando il testo è di un altro lettore (GLM senza la guardia,
    /// giro «migliorie del banco nelle app»): il corpo si stima dalla larghezza della riga divisa per i caratteri di QUEL testo, non di
    /// quello che lo sostituisce. nil = il testo è quello della riga (la via di sempre: nessun campo in più nei dati).
    public var caratteriApple: Int? = nil

    public init(testo: String, bbox: BBox, regione: Int, tipo: String? = nil) {
        self.testo = testo; self.bbox = bbox; self.regione = regione; self.tipo = tipo
    }
}

/// Una pagina letta (in memoria; la riga di comando del banco la può salvare nel laboratorio).
public struct PaginaLetta: Codable, Sendable {
    public var pagina: Int
    public var larghezza: Double
    public var altezza: Double
    public var righe: [RigaLetta]
    /// Il testo grezzo di GLM-OCR, se l'ha letta GLM (banco: misura del lettore prima della guardia).
    public var testoGlm: String?
    public var secondiApple: Double
    public var secondiGlm: Double
    public var secondiImpaginazione: Double
    /// Parole di GLM tenute, corrette (diverse da Apple) e scartate dalla guardia.
    public var guardia: [String: Int]?
}

// MARK: - Il motore della lettura

public enum LetturaScansioni {

    /// Il lato lungo dell'immagine della pagina data ai lettori (punti → pixel): circa 300 punti per pollice sulle pagine
    /// piccole, meno sulle grandi, così l'immagine resta nei limiti di GLM-OCR.
    public static let latoLungoPixel: CGFloat = 2000

    /// La rotazione della pagina, ricondotta a 0, 90, 180 o 270 gradi.
    public static func rotazione(della pagina: PDFPage) -> Int {
        ((pagina.rotation % 360) + 360) % 360
    }

    /// La misura della pagina COME SI MOSTRA, in punti: il riquadro di ritaglio, coi lati scambiati se la pagina è ruotata di 90 o di
    /// 270 gradi. È lo spazio in cui stanno l'immagine data ai lettori, le righe lette e la pagina dell'estrazione.
    public static func misuraMostrata(della pagina: PDFPage) -> CGSize {
        let box = pagina.bounds(for: .cropBox)
        let r = rotazione(della: pagina)
        return r == 90 || r == 270 ? CGSize(width: box.height, height: box.width) : box.size
    }

    /// L'immagine in scala di grigi della pagina come si mostra, al lato lungo dato.
    ///
    /// LE PAGINE RUOTATE (giro globale del banco OCR, 2026-11-19, docs/BANCO_OCR.md § 21 e § 25). `PDFPage.draw(with:to:)` disegna già
    /// la pagina ruotata e riportata all'origine del suo riquadro di ritaglio (applica da sé `transform(for:)`: misurato al banco su pagine
    /// costruite con contrassegni noti, a 0, 90, 180 e 270 gradi, con e senza riquadro spostato). La tela deve quindi avere la misura
    /// mostrata e nessuna traslazione nostra. Prima la tela aveva la misura non ruotata e si traslava di nuovo sul riquadro: sulle pagine
    /// con `/Rotate` 90 o 270 (molti scanner salvano così) la pagina verticale finiva in una tela orizzontale e il terzo alto usciva;
    /// con un riquadro di ritaglio spostato dall'origine la pagina scivolava di quanto è spostato il riquadro. Sulle pagine diritte col
    /// riquadro all'origine (tutte quelle del banco del giro 1) la resa è identica al byte a prima: stessa misura, stessa scala, e la
    /// traslazione tolta era nulla.
    public static func immagine(della pagina: PDFPage, latoLungo: CGFloat = latoLungoPixel) -> CGImage? {
        let m = misuraMostrata(della: pagina)
        guard m.width > 0, m.height > 0 else { return nil }
        let scala = min(300.0 / 72.0, latoLungo / max(m.width, m.height))
        let w = Int((m.width * scala).rounded()), h = Int((m.height * scala).rounded())
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        ctx.setFillColor(gray: 1, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.scaleBy(x: scala, y: scala)
        pagina.draw(with: .cropBox, to: ctx)
        return ctx.makeImage()
    }

    /// La resa della pagina per il modello d'impaginazione: 640 × 640 e la misura della pagina in punti, come
    /// `HeronPageRenderer.renderPage` del modulo condiviso. Sulle pagine diritte col riquadro di ritaglio all'origine È quella del
    /// modulo (identica al byte); sulle pagine ruotate o col riquadro spostato si fa qui, sulla pagina come si mostra, con gli stessi
    /// passi del modulo (pagina a 72 punti per pollice, poi 640 × 640 con l'interpolazione media): il modulo, condiviso con l'iPad e non
    /// toccato in questo giro, ha la stessa costruzione della resa di prima (misura non ruotata, traslazione in più).
    static func resaPerImpaginazione(_ pagina: PDFPage) -> (CGImage, Double, Double)? {
        let box = pagina.bounds(for: .cropBox)
        guard rotazione(della: pagina) != 0 || box.origin != .zero else { return HeronPageRenderer.renderPage(pagina) }
        let m = misuraMostrata(della: pagina)
        let w = Int(m.width.rounded()), h = Int(m.height.rounded())
        guard w > 0, h > 0,
              let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.scaleBy(x: CGFloat(w) / m.width, y: CGFloat(h) / m.height)
        pagina.draw(with: .cropBox, to: ctx)
        guard let img = ctx.makeImage(),
              let ctx2 = CGContext(data: nil, width: 640, height: 640, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                   bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        ctx2.interpolationQuality = .medium
        ctx2.draw(img, in: CGRect(x: 0, y: 0, width: 640, height: 640))
        guard let img640 = ctx2.makeImage() else { return nil }
        return (img640, Double(m.width), Double(m.height))
    }

    public static func png(_ img: CGImage) -> Data? {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data as CFMutableData, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, img, nil)
        return CGImageDestinationFinalize(dest) ? data as Data : nil
    }

    // MARK: Apple

    /// Le righe della lettura del testo di Apple: testo, riquadro (punti, origine in basso a sinistra) e indice del paragrafo
    /// nell'ordine di Apple. Sul thread chiamante (mai il principale: l'attesa è bloccante).
    public static func righeApple(_ img: CGImage, larghezza W: Double, altezza H: Double) throws -> [RigaLetta] {
        try letturaApple(img, larghezza: W, altezza: H).righe
    }

    /// La lettura di Apple con le tabelle che la richiesta dei documenti vede (la catena oggi non le usa: le guarda solo il
    /// laboratorio). `classica` è la variante A del laboratorio (spenta nell'app): la richiesta classica anche sui sistemi nuovi.
    static func letturaApple(_ img: CGImage, larghezza W: Double, altezza H: Double,
                             classica: Bool = false) throws -> (righe: [RigaLetta], tabelle: [BBox]) {
        if !classica, #available(macOS 26.0, *) {
            return try attendi { try await righeDocumento(img, W: W, H: H) }
        }
        return (try righeTestoClassico(img, W: W, H: H), [])
    }

    @available(macOS 26.0, *)
    private static func righeDocumento(_ img: CGImage, W: Double, H: Double) async throws -> (righe: [RigaLetta], tabelle: [BBox]) {
        let req = RecognizeDocumentsRequest()
        let osservazioni = try await req.perform(on: img)
        var paragrafi: [BBox] = []
        var righe: [(String, BBox)] = []
        var tabelle: [BBox] = []
        for o in osservazioni {
            let d = o.document
            for p in d.paragraphs { paragrafi.append(bbox(p.boundingRegion.boundingBox.origin.x, p.boundingRegion.boundingBox.origin.y,
                                                          p.boundingRegion.boundingBox.width, p.boundingRegion.boundingBox.height, W, H)) }
            for l in d.text.lines {
                let r = l.boundingRegion.boundingBox
                let t = l.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                if !t.isEmpty { righe.append((t, bbox(r.origin.x, r.origin.y, r.width, r.height, W, H))) }
            }
            for t in d.tables {
                let r = t.boundingRegion.boundingBox
                tabelle.append(bbox(r.origin.x, r.origin.y, r.width, r.height, W, H))
            }
        }
        // Ogni riga nel paragrafo che ne contiene il centro (l'ordine dei paragrafi è quello di Apple); le righe fuori da ogni
        // paragrafo (tabelle) vanno col paragrafo più vicino.
        let lette = righe.map { t, b in
            let cx = b.x + b.width / 2, cy = b.y + b.height / 2
            let k = paragrafi.firstIndex { cx >= $0.x && cx <= $0.x + $0.width && cy >= $0.y && cy <= $0.y + $0.height }
                ?? paragrafi.indices.min { distanza(paragrafi[$0], cx, cy) < distanza(paragrafi[$1], cx, cy) } ?? 0
            return RigaLetta(testo: t, bbox: b, regione: k)
        }
        return (lette, tabelle)
    }

    private static func righeTestoClassico(_ img: CGImage, W: Double, H: Double) throws -> [RigaLetta] {
        let req = VNRecognizeTextRequest()
        req.recognitionLevel = .accurate
        req.usesLanguageCorrection = true
        req.recognitionLanguages = ["it-IT", "en-US"]
        try VNImageRequestHandler(cgImage: img, options: [:]).perform([req])
        return (req.results ?? []).enumerated().compactMap { k, o in
            guard let t = o.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return nil }
            let r = o.boundingBox
            return RigaLetta(testo: t, bbox: bbox(r.origin.x, r.origin.y, r.width, r.height, W, H), regione: k)
        }
    }

    private static func bbox(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ W: Double, _ H: Double) -> BBox {
        BBox(x: x * W, y: y * H, width: w * W, height: h * H)
    }

    private static func distanza(_ b: BBox, _ x: Double, _ y: Double) -> Double {
        let dx = max(b.x - x, 0, x - (b.x + b.width)), dy = max(b.y - y, 0, y - (b.y + b.height))
        return dx * dx + dy * dy
    }

    /// Esegue un lavoro asincrono e ne attende l'esito sul thread chiamante.
    static func attendi<T>(_ lavoro: @escaping @Sendable () async throws -> T) throws -> T {
        let s = ScatolaEsito<T>(), sem = DispatchSemaphore(value: 0)
        Task.detached {
            do { s.esito = .success(try await lavoro()) } catch { s.esito = .failure(error) }
            sem.signal()
        }
        sem.wait()
        return try s.esito!.get()
    }

    final class ScatolaEsito<T>: @unchecked Sendable { var esito: Result<T, Error>?; init() {} }

    // MARK: Impaginazione (Heron sull'immagine della pagina)

    /// Le regioni del modello d'impaginazione sulla pagina: tipo e riquadro (punti, origine in basso a sinistra), già
    /// nell'ordine di lettura del porto di docling. Sulle scansioni il post-processing del modulo (che lega le regioni alle
    /// righe di PDFKit) non ha righe: qui si usano le rilevazioni grezze sopra soglia, senza doppioni, e l'ordine del modulo.
    public static func regioni(pagina: PDFPage, modello: HeronLayoutModel) throws -> [(tipo: String, bbox: BBox)] {
        guard let (img, W, H) = resaPerImpaginazione(pagina) else { return [] }
        let grezze = try modello._detectionsForCheck(image: img)
            .filter { $0.1 >= sogliaRegione($0.0) }
            .sorted { $0.1 > $1.1 }
        var tenute: [(String, Double, [Double])] = []
        for d in grezze where !tenute.contains(where: { sovrapposte($0.2, d.2) }) { tenute.append(d) }
        let elementi = tenute.enumerated().map { k, d in
            (cid: k, label: d.0, pageNo: 1, l: d.2[0] * W / 1000, t: d.2[1] * H / 1000, r: d.2[2] * W / 1000, b: d.2[3] * H / 1000)
        }
        let ordine = _readingOrderCheck(elements: elementi, pageWidth: W, pageHeight: H)
        return ordine.compactMap { cid in
            guard let e = elementi.first(where: { $0.cid == cid }) else { return nil }
            return (e.label, BBox(x: e.l, y: H - e.b, width: e.r - e.l, height: e.b - e.t))
        }
    }

    static func sogliaRegione(_ tipo: String) -> Double { ["picture", "table"].contains(tipo) ? 0.5 : 0.45 }

    /// Due rilevazioni sono la stessa regione se si coprono per più di metà dell'unione, o se una sta quasi tutta nell'altra.
    static func sovrapposte(_ a: [Double], _ b: [Double]) -> Bool {
        let iw = max(0, min(a[2], b[2]) - max(a[0], b[0])), ih = max(0, min(a[3], b[3]) - max(a[1], b[1]))
        let inter = iw * ih
        let aa = (a[2] - a[0]) * (a[3] - a[1]), ab = (b[2] - b[0]) * (b[3] - b[1])
        guard inter > 0, aa > 0, ab > 0 else { return false }
        return inter / (aa + ab - inter) > 0.5 || inter / min(aa, ab) > 0.8
    }

    /// Le righe nell'ordine delle regioni: ogni riga va nella regione che ne contiene il centro (o nella più vicina), le
    /// regioni nell'ordine del modello, le righe di una regione dall'alto in basso e da sinistra a destra.
    public static func ordina(_ righe: [RigaLetta], regioni: [(tipo: String, bbox: BBox)]) -> [RigaLetta] {
        guard !regioni.isEmpty else { return ordinaDallAlto(righe) }
        // Guardia dell'ordine: l'ordine delle regioni vale solo se le regioni contengono il centro di almeno l'80 per cento delle
        // righe; se no (pagina rovinata, regioni mancate) resta l'ordine dei paragrafi di Apple.
        let dentro = righe.filter { r in
            let cx = r.bbox.x + r.bbox.width / 2, cy = r.bbox.y + r.bbox.height / 2
            return regioni.contains { cx >= $0.bbox.x && cx <= $0.bbox.x + $0.bbox.width && cy >= $0.bbox.y && cy <= $0.bbox.y + $0.bbox.height }
        }.count
        guard Double(dentro) >= 0.8 * Double(max(1, righe.count)) else { return ordinaDallAlto(righe) }
        let assegnate = righe.map { r -> RigaLetta in
            let cx = r.bbox.x + r.bbox.width / 2, cy = r.bbox.y + r.bbox.height / 2
            let k = regioni.indices.first { i in
                let b = regioni[i].bbox
                return cx >= b.x && cx <= b.x + b.width && cy >= b.y && cy <= b.y + b.height
            } ?? regioni.indices.min { distanza(regioni[$0].bbox, cx, cy) < distanza(regioni[$1].bbox, cx, cy) }!
            var c = r; c.regione = k; c.tipo = regioni[k].tipo
            return c
        }
        return assegnate.enumerated().sorted { a, b in
            if a.element.regione != b.element.regione { return a.element.regione < b.element.regione }
            return prima(a.element, b.element)
        }.map { $0.element }
    }

    /// Le righe dall'alto in basso, nell'ordine dei paragrafi di Apple.
    public static func ordinaDallAlto(_ righe: [RigaLetta]) -> [RigaLetta] {
        righe.sorted { a, b in a.regione != b.regione ? a.regione < b.regione : prima(a, b) }
    }

    /// Dall'alto in basso; sulla stessa riga (centri entro metà altezza), da sinistra a destra.
    static func prima(_ a: RigaLetta, _ b: RigaLetta) -> Bool {
        let ca = a.bbox.y + a.bbox.height / 2, cb = b.bbox.y + b.bbox.height / 2
        if abs(ca - cb) > min(a.bbox.height, b.bbox.height) / 2 { return ca > cb }
        return a.bbox.x < b.bbox.x
    }

    // MARK: GLM-OCR attraverso la guardia

    /// Il testo di GLM-OCR sulle righe di Apple, parola per parola. Le parole uguali (a meno di maiuscole, accenti e
    /// punteggiatura) prendono la forma di GLM; dove Apple e GLM dicono parole diverse nello stesso punto, una contro una,
    /// vince GLM se le due si somigliano (una correzione), altrimenti resta Apple; ciò che GLM legge in più dove Apple non
    /// ha visto nulla NON entra; ciò che Apple legge e GLM no, resta. Ritorna le righe e i conteggi della guardia.
    /// `larga` è la variante C del laboratorio (spenta nell'app): entrano anche le parole che GLM aggiunge in mezzo a una riga di
    /// Apple (fra due parole allineate della stessa riga), e le corse di lunghezza diversa anche fra righe diverse se si somigliano
    /// almeno 0,6.
    public static func guardia(righe: [RigaLetta], testoGlm: String, larga: Bool = false) -> (righe: [RigaLetta], conti: [String: Int]) {
        var parole: [(riga: Int, testo: String)] = []
        for (i, r) in righe.enumerated() {
            for p in r.testo.split(whereSeparator: { $0 == " " || $0 == "\t" }) { parole.append((i, String(p))) }
        }
        let glm = paroleGlm(testoGlm)
        let nv = parole.map { normalizza($0.testo) }, ng = glm.map(normalizza)
        let diff = ng.difference(from: nv)
        var tolte = Set<Int>(), messe = Set<Int>()
        for c in diff {
            switch c {
            case .remove(let o, _, _): tolte.insert(o)
            case .insert(let o, _, _): messe.insert(o)
            }
        }
        var scelte = parole.map { $0.testo }
        var conti = ["uguali": 0, "corrette": 0, "tenute_apple": 0, "scartate_glm": 0, "apici_glm": 0]
        var i = 0, j = 0
        var ultimaV = -1
        var corsaV: [Int] = [], corsaG: [Int] = []
        func chiudiCorsa() {
            defer { if let u = corsaV.last { ultimaV = u }; corsaV.removeAll(); corsaG.removeAll() }
            if corsaV.isEmpty {
                // Variante C (solo laboratorio): ciò che GLM aggiunge in mezzo a una riga di Apple entra, attaccato alla parola
                // allineata precedente.
                if larga, !corsaG.isEmpty, ultimaV >= 0, i < parole.count, parole[i].riga == parole[ultimaV].riga {
                    scelte[ultimaV] += " " + corsaG.map { glm[$0] }.joined(separator: " ")
                    conti["aggiunte_larga", default: 0] += corsaG.count
                    return
                }
                // Ciò che GLM aggiunge non entra; solo un apice di richiamo («$^{12}$») si attacca alla parola precedente di
                // Apple: diventa richiamo più avanti solo se sulla pagina comincia una nota con quel numero (`spans`).
                for g in corsaG {
                    if ultimaV >= 0, Self.apice(in: glm[g]) != nil, glm[g].hasPrefix("$") || glm[g].hasPrefix("^") {
                        scelte[ultimaV] += glm[g]; conti["apici_glm", default: 0] += 1
                    } else { conti["scartate_glm", default: 0] += 1 }
                }
                return
            }
            if corsaG.isEmpty { conti["tenute_apple", default: 0] += corsaV.count; return }
            if corsaV.count == corsaG.count {
                for (v, g) in zip(corsaV, corsaG) {
                    if somiglianza(nv[v], ng[g]) >= 0.5 { scelte[v] = glm[g]; conti["corrette", default: 0] += 1 }
                    else { conti["tenute_apple", default: 0] += 1; conti["scartate_glm", default: 0] += 1 }
                }
                return
            }
            // Numeri diversi di parole: GLM entra solo dentro una riga sola e se l'insieme si somiglia molto.
            let stessaRiga = Set(corsaV.map { parole[$0].riga }).count == 1
            let unitoV = corsaV.map { nv[$0] }.joined(), unitoG = corsaG.map { ng[$0] }.joined()
            // (Le due somiglianze si calcolano solo se servono: con la variante spenta il costo è quello di sempre.)
            if stessaRiga && somiglianza(unitoV, unitoG) >= 0.75 || larga && somiglianza(unitoV, unitoG) >= 0.6 {
                scelte[corsaV[0]] = corsaG.map { glm[$0] }.joined(separator: " ")
                for v in corsaV.dropFirst() { scelte[v] = "" }
                conti["corrette", default: 0] += corsaV.count
            } else {
                conti["tenute_apple", default: 0] += corsaV.count
                conti["scartate_glm", default: 0] += corsaG.count
            }
        }
        while i < nv.count || j < ng.count {
            if i < nv.count, tolte.contains(i) { corsaV.append(i); i += 1; continue }
            if j < ng.count, messe.contains(j) { corsaG.append(j); j += 1; continue }
            chiudiCorsa()
            if i < nv.count, j < ng.count {
                // Due pezzi fatti di soli segni (normalizzati, vuoti) non sono «uguali»: resta quello di Apple.
                if !nv[i].isEmpty { scelte[i] = glm[j] }
                conti["uguali", default: 0] += 1; ultimaV = i
            }
            i += 1; j += 1
        }
        chiudiCorsa()
        var uscita = righe
        for k in uscita.indices { uscita[k].testo = "" }
        for (k, p) in parole.enumerated() where !scelte[k].isEmpty {
            let r = p.riga
            uscita[r].testo = uscita[r].testo.isEmpty ? scelte[k] : uscita[r].testo + " " + scelte[k]
        }
        return (uscita.filter { !$0.testo.isEmpty }, conti)
    }

    /// SOLO LABORATORIO (variante B, spenta nell'app): GLM senza la guardia stretta. Il testo di GLM è l'autorità: ogni sua parola
    /// prende la riga della parola di Apple a cui si allinea (quindi la regione e l'ordine di Heron); ciò che GLM aggiunge prende la
    /// riga della parola allineata precedente (la prima riga, all'inizio); ciò che solo Apple ha visto si toglie. Le etichette HTML
    /// delle tabelle di GLM si tolgono. La geometria resta quella delle righe di Apple.
    ///
    /// Con `migliorata` (miglioria `glm`, giro «migliorie del banco nelle app», 2026-11-21) tre differenze, misurate sul banco: i pezzi
    /// fatti di soli segni (senza lettere né cifre: «§», «*») si allineano per quello che sono e non si appaiano fra loro; ciò che solo
    /// Apple ha letto, dove GLM non scrive nulla, resta (GLM salta a volte il titolo di capitolo in cima alla pagina, come se fosse
    /// un'intestazione); il corpo delle righe si stima sui caratteri della riga di Apple (`caratteriApple`). Dove leggono tutti e due,
    /// vince GLM (sulle scansioni vere la guardia stretta rimetteva lì le righe sbagliate di Apple).
    /// Ciò che solo Apple ha letto resta solo se non sta già nel testo di GLM (un allineamento sfasato lo ripeterebbe) e se non sta nelle
    /// fasce alta e bassa della pagina (l'8 per cento: testatine e numeri di pagina, che GLM tralascia di proposito); `altezzaPagina` 0 =
    /// nessuna fascia.
    public static func senzaGuardia(righe: [RigaLetta], testoGlm: String, migliorata: Bool = false,
                                    altezzaPagina: Double = 0) -> (righe: [RigaLetta], conti: [String: Int]) {
        var conti = ["allineate": 0, "aggiunte_glm": 0, "tolte_apple": 0]
        guard !righe.isEmpty else { return ([], ["senza_ancore": paroleGlm(testoGlm).count]) }
        var parole: [Int] = []   // la riga di ogni parola di Apple
        var testiV: [String] = []
        for (i, r) in righe.enumerated() {
            for p in r.testo.split(whereSeparator: { $0 == " " || $0 == "\t" }) { parole.append(i); testiV.append(String(p)) }
        }
        let pulito = testoGlm.replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
        let glm = paroleGlm(pulito)
        let allinea: (String) -> String = { s in let n = normalizza(s); return migliorata && n.isEmpty ? "\u{1}" + s : n }
        let nv = testiV.map(allinea), ng = glm.map(allinea)
        let paroleDiGlm = Set(ng)
        let diff = ng.difference(from: nv)
        var tolte = Set<Int>(), messe = Set<Int>()
        for c in diff {
            switch c {
            case .remove(let o, _, _): tolte.insert(o)
            case .insert(let o, _, _): messe.insert(o)
            }
        }
        var perRiga = [[String]](repeating: [], count: righe.count)
        var ultimaRiga = parole.first ?? 0
        var corsaV: [Int] = [], corsaG: [Int] = []
        // Una corsa di parole diverse: le parole di GLM vanno, una per una, sulle righe delle parole di Apple che sostituiscono
        // (le eccedenti sull'ultima); senza parole di Apple, sulla riga della parola allineata precedente.
        func chiudi() {
            if migliorata, corsaG.isEmpty, !corsaV.isEmpty {
                // Ciò che solo Apple ha letto resta, sulle sue righe e al suo posto, salvo che GLM l'abbia già scritto altrove o che stia
                // nelle fasce della testatina e del piè.
                let w = corsaV.map { nv[$0] }.filter { !$0.isEmpty }
                // Già nel testo di GLM: per una corsa con almeno tre parole piene (quattro lettere o più), se almeno il 60 per cento di
                // esse sta nel testo di GLM della pagina (Apple può averne sbagliata qualcuna, e il confronto esatto non la riconoscerebbe);
                // per una corsa più breve, se una sua parola sta nel testo di GLM vicino al punto dell'allineamento.
                let gia: Bool = {
                    guard !w.isEmpty else { return true }
                    let piene = w.filter { $0.count >= 4 && !$0.hasPrefix("\u{1}") }
                    if piene.count >= 3 { return Double(piene.filter { paroleDiGlm.contains($0) }.count) >= 0.6 * Double(piene.count) }
                    return w.contains { ng[max(0, j - 6)..<min(ng.count, j + 6)].contains($0) }
                }()
                let inFascia: (Int) -> Bool = { v in
                    guard altezzaPagina > 0 else { return false }
                    let b = righe[parole[v]].bbox
                    return b.y > 0.92 * altezzaPagina || b.y + b.height < 0.08 * altezzaPagina
                }
                // Una parola sola che solo Apple legge è più spesso una lettura sbagliata che testo saltato da GLM: resta solo una corsa
                // di almeno due parole (un titolo, una riga, una colonna).
                if !gia, w.count >= 2 {
                    for v in corsaV where !inFascia(v) { perRiga[parole[v]].append(testiV[v]); conti["tenute_apple", default: 0] += 1 }
                }
                if let u = corsaV.last { ultimaRiga = parole[u] }
                corsaV.removeAll()
                return
            }
            for (k, g) in corsaG.enumerated() {
                perRiga[corsaV.isEmpty ? ultimaRiga : parole[corsaV[min(k, corsaV.count - 1)]]].append(glm[g])
            }
            conti["sostituite", default: 0] += min(corsaV.count, corsaG.count)
            conti["aggiunte_glm", default: 0] += max(0, corsaG.count - corsaV.count)
            conti["tolte_apple", default: 0] += max(0, corsaV.count - corsaG.count)
            if let u = corsaV.last { ultimaRiga = parole[u] }
            corsaV.removeAll(); corsaG.removeAll()
        }
        var i = 0, j = 0
        while i < nv.count || j < ng.count {
            if i < nv.count, tolte.contains(i) { corsaV.append(i); i += 1; continue }
            if j < ng.count, messe.contains(j) { corsaG.append(j); j += 1; continue }
            chiudi()
            if i < nv.count, j < ng.count {
                ultimaRiga = parole[i]; perRiga[ultimaRiga].append(glm[j]); conti["allineate", default: 0] += 1
            }
            i += 1; j += 1
        }
        chiudi()
        var uscita: [RigaLetta] = []
        for (k, r) in righe.enumerated() where !perRiga[k].isEmpty {
            var c = r; c.testo = perRiga[k].joined(separator: " ")
            if migliorata { c.caratteriApple = r.testo.count }   // la geometria resta quella di Apple, e così il corpo
            uscita.append(c)
        }
        return (uscita, conti)
    }

    // MARK: Il filtro della notazione di GLM (giro «migliorie del banco nelle app», 2026-11-21)

    /// I comandi di LaTeX che GLM scrive e il segno che rappresentano (misurati sulla cache del banco: frecce, gradi, testo); gli altri
    /// comandi si tolgono, il loro argomento resta.
    static let comandiLatex: [String: String] = [
        "rightarrow": "→", "leftarrow": "←", "Rightarrow": "⇒", "Leftarrow": "⇐", "leftrightarrow": "↔", "to": "→",
        "circ": "°", "degree": "°", "cdot": "·", "times": "×", "S": "§", "P": "¶", "ldots": "…", "dots": "…",
        "leq": "≤", "geq": "≥", "neq": "≠", "pm": "±", "approx": "≈", "%": "%", "&": "&", "$": "$", "_": "_", "#": "#",
        ",": " ", ";": " ", ":": " ", "!": "", " ": " ", "quad": " ", "qquad": " ",
    ]
    static let comandiConArgomento: Set<String> = ["text", "mathrm", "textit", "textbf", "mathit", "mathbf", "emph", "textrm", "operatorname",
                                                    "underline", "overline", "textsuperscript", "textsubscript", "mathsf", "mathtt", "texttt"]

    /// IL FILTRO DELLA NOTAZIONE. Toglie dal testo di GLM i segni che VoiceOver direbbe ma che sulla pagina non ci sono: la notazione
    /// matematica (dollari, comandi, graffe, apici e pedici: classe R1 del rumore udibile del banco, § 25.3 di docs/BANCO_OCR.md) e la
    /// formattazione (etichette HTML, entità, grassetti, cancelletti dei titoli, barre e righe delle tabelle: classe R2), SENZA TOGLIERE
    /// TESTO: lettere e cifre restano tutte (salvo i nomi dei comandi), e un comando che rappresenta un segno vero diventa quel segno
    /// («\rightarrow» → «→», «^\circ» → «°», «\S» → «§»). Gli apici dei richiami («$^{12}$») restano nella forma che la catena riconosce
    /// (diventano richiami solo se la nota con quel numero comincia sulla pagina, altrimenti la cifra: `spans`); un numero con l'apice
    /// («$1990^{2}$») diventa il numero seguito dall'apice. Un «$» solo davanti a un numero resta (lo decide la regola del paragrafo).
    public static func filtraNotazione(_ testo: String) -> String {
        var t = testo
        // Etichette HTML (le tabelle di GLM) ed entità.
        t = t.replacingOccurrences(of: #"<[^<>]{1,200}>"#, with: " ", options: .regularExpression)
        for (e, v) in [("&nbsp;", " "), ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&apos;", "'"), ("&#39;", "'")] {
            t = t.replacingOccurrences(of: e, with: v)
        }
        // La notazione fra dollari, una formula per volta (anche fra doppi dollari). Due dollari senza alcun segno di notazione fra loro
        // («$ 5 e $ 7») non sono una formula: restano, e li giudicano i passi dopo (il dollaro davanti a un numero resta per la regola
        // del paragrafo, gli altri si tolgono).
        t = sostituisci(#"\$\$?([^$\n]{1,120}?)\$\$?"#, in: t) { g in
            g[1].range(of: #"[\^_\\{}]"#, options: .regularExpression) == nil ? g[0] : formula(g[1])
        }
        // Fuori dai dollari: gli apici scritti senza dollari, poi i comandi.
        t = sostituisci(#"\^\s*\{\s*([0-9]{1,3})\s*\}"#, in: t) { g in "$^{\(g[1])}$" }
        t = comandi(t)
        // La formattazione: grassetti e sottolineature, cancelletti dei titoli, righe e barre delle tabelle.
        t = t.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "__", with: "")
        t = t.replacingOccurrences(of: #"(?m)^[ \t]*#{1,6}[ \t]+"#, with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: #"(?m)^[ \t]*\|?[ \t]*:?-{3,}:?[ \t]*(\|[ \t]*:?-{3,}:?[ \t]*)*\|?[ \t]*$"#, with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: "|", with: " ")
        // Le graffe rimaste fuori dagli apici; un dollaro solo (non davanti a un numero, non dopo una sigla come «US»).
        t = sostituisci(#"\$\^\{([0-9]{1,3})\}\$|[{}]"#, in: t) { g in g[1].isEmpty ? " " : "$^{\(g[1])}$" }
        t = sostituisci(#"\$\^\{([0-9]{1,3})\}\$|(?<![A-Z])\$(?!\s?[0-9])"#, in: t) { g in g[1].isEmpty ? "" : "$^{\(g[1])}$" }
        // Spazi doppi lasciati dai segni tolti (gli a capo restano).
        t = t.replacingOccurrences(of: #"[ \t]{2,}"#, with: " ", options: .regularExpression)
        return t
    }

    /// Una formula fra dollari, resa come testo: l'apice di un richiamo resta nella forma della catena; un numero o una parola con
    /// l'apice diventa la base seguita dall'apice; i gradi diventano «°»; il resto perde comandi, graffe, apici e pedici.
    static func formula(_ f: String) -> String {
        let x = f.trimmingCharacters(in: .whitespaces)
        if let g = gruppi(#"^\^\s*\{?\s*([0-9]{1,3})\s*\}?$"#, x) { return "$^{\(g[1])}$" }
        if let g = gruppi(#"^([0-9A-Za-zÀ-ÿ.,'’]+?)\s*\^\s*\{?\s*([0-9]{1,3})\s*\}?$"#, x) { return g[1] + "$^{\(g[2])}$" }
        if let g = gruppi(#"^([0-9.,]*)\s*\^\s*\{?\s*\\circ\s*\}?$"#, x) { return g[1] + "°" }
        var t = comandi(x)
        t = t.replacingOccurrences(of: #"[\^_{}]"#, with: " ", options: .regularExpression)
        return t.replacingOccurrences(of: #"[ \t]{2,}"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
    }

    /// I comandi di LaTeX: quelli con argomento lasciano l'argomento, quelli di un segno diventano il segno, gli altri si tolgono.
    static func comandi(_ testo: String) -> String {
        var t = testo
        for _ in 0..<3 {   // argomenti annidati (pochi livelli)
            t = sostituisci(#"\\([A-Za-z]+)\s*\{([^{}]*)\}"#, in: t) { g in comandiConArgomento.contains(g[1]) ? g[2] : (comandiLatex[g[1]].map { $0 + g[2] } ?? g[2]) }
        }
        t = sostituisci(#"\\([A-Za-z]+|[^A-Za-z\s])"#, in: t) { g in comandiLatex[g[1]] ?? "" }
        return t
    }

    /// I gruppi di un'espressione regolare sull'intera stringa (0 = tutto), o nil.
    static func gruppi(_ rx: String, _ s: String) -> [String]? {
        guard let r = try? NSRegularExpression(pattern: rx), let m = r.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) else { return nil }
        return (0..<m.numberOfRanges).map { m.range(at: $0).location == NSNotFound ? "" : String(s[Range(m.range(at: $0), in: s)!]) }
    }

    /// Ogni occorrenza dell'espressione sostituita da ciò che dà `con` sui suoi gruppi (0 = tutto; un gruppo mancante è vuoto).
    static func sostituisci(_ rx: String, in s: String, con: ([String]) -> String) -> String {
        guard let r = try? NSRegularExpression(pattern: rx) else { return s }
        var out = "", ultimo = s.startIndex
        for m in r.matches(in: s, range: NSRange(s.startIndex..., in: s)) {
            guard let tutta = Range(m.range, in: s) else { continue }
            out += s[ultimo..<tutta.lowerBound]
            out += con((0..<m.numberOfRanges).map { m.range(at: $0).location == NSNotFound ? "" : String(s[Range(m.range(at: $0), in: s)!]) })
            ultimo = tutta.upperBound
        }
        return out + s[ultimo...]
    }

    /// LA PROTEZIONE CONTRO LE RIPETIZIONI. Una riga di GLM di almeno quattro parole che GLM scrive più volte di quante la sequenza delle
    /// sue parole compaia nelle righe di Apple della stessa pagina si dice una volta sola (le altre si tolgono, la prima resta): GLM a volte
    /// ripete una riga (classe R4 del rumore udibile del banco); le righe ripetute davvero sulla pagina le vede anche Apple e restano.
    public static func senzaRipetizioni(_ testo: String, righeApple: [RigaLetta]) -> (testo: String, tolte: Int) {
        let apple = " " + righeApple.flatMap { $0.testo.split(whereSeparator: \.isWhitespace).map { normalizza(String($0)) } }.filter { !$0.isEmpty }
            .joined(separator: " ") + " "
        func occorrenze(_ ago: String) -> Int {
            var n = 0, da = apple.startIndex
            while let r = apple.range(of: " " + ago + " ", range: da..<apple.endIndex) { n += 1; da = apple.index(before: r.upperBound) }
            return n
        }
        var viste: [String: Int] = [:], tolte = 0, righe: [Substring] = []
        for riga in testo.split(separator: "\n", omittingEmptySubsequences: false) {
            let parole = riga.split(whereSeparator: \.isWhitespace).map { normalizza(String($0)) }.filter { !$0.isEmpty }
            guard parole.count >= 4 else { righe.append(riga); continue }
            let k = parole.joined(separator: " ")
            viste[k, default: 0] += 1
            if viste[k]! > max(1, occorrenze(k)) { tolte += 1; continue }
            righe.append(riga)
        }
        return (righe.joined(separator: "\n"), tolte)
    }

    /// SOLO LABORATORIO (variante F, spenta nell'app): le parole sillabate a fine riga ricomposte prima della catena. Una riga che
    /// finisce con un trattino dopo una lettera, seguita nella stessa regione da una riga che comincia con una minuscola, prende la
    /// prima parola della riga dopo, senza il trattino; la riga dopo, se resta vuota, si toglie. I riquadri non cambiano.
    public static func ricomponiSillabate(_ righe: [RigaLetta]) -> (righe: [RigaLetta], unite: Int) {
        var r = righe
        var unite = 0
        var k = 0
        while k + 1 < r.count {
            let a = r[k].testo, b = r[k + 1].testo
            if r[k].regione == r[k + 1].regione, let ultimo = a.last, "-\u{2010}\u{2011}\u{00AC}".contains(ultimo),
               a.dropLast().last?.isLetter == true, let primo = b.first, primo.isLetter, primo.isLowercase {
                let parti = b.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
                r[k].testo = String(a.dropLast()) + String(parti[0])
                r[k + 1].testo = parti.count > 1 ? String(parti[1]) : ""
                unite += 1
                if r[k + 1].testo.isEmpty { r.remove(at: k + 1); continue }
            }
            k += 1
        }
        return (r, unite)
    }

    /// Le parole del testo di GLM, senza i segni di formattazione che a volte aggiunge (cancelletti dei titoli, barre delle
    /// tabelle, asterischi del grassetto).
    static func paroleGlm(_ testo: String) -> [String] {
        testo.split(whereSeparator: { $0.isWhitespace }).map { p -> String in
            var s = String(p)
            while let f = s.first, "#*|".contains(f) { s.removeFirst() }
            while let l = s.last, "*|".contains(l) { s.removeLast() }
            return s
        }.filter { !$0.isEmpty && $0 != "---" }
    }

    /// Il numero di un apice di richiamo come lo scrive GLM lettura pagine («$^{12}$», «^{12}», «^12»), se il pezzo ne ha uno.
    static func apice(in pezzo: String) -> (prima: String, numero: String, dopo: String)? {
        guard let r = pezzo.range(of: #"\$?\^\{?([0-9]{1,3})\}?\$?"#, options: .regularExpression) else { return nil }
        let numero = pezzo[r].filter(\.isNumber)
        return (String(pezzo[..<r.lowerBound]), String(numero), String(pezzo[r.upperBound...]))
    }

    /// Un apice all'inizio della riga è il numero della nota che comincia lì («$^{12}$ Testo» → «12 Testo»).
    static func numeroDiNotaInTesta(_ t: String) -> String {
        guard t.hasPrefix("$^") || t.hasPrefix("^"),
              let r = t.range(of: #"^\$?\^\{?([0-9]{1,3})\}?\$?"#, options: .regularExpression) else { return t }
        let resto = t[r.upperBound...]
        return String(t[r].filter(\.isNumber)) + (resto.hasPrefix(" ") ? "" : " ") + resto
    }

    /// Minuscole, senza accenti, solo lettere e cifre.
    static func normalizza(_ s: String) -> String {
        String(s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "it_IT"))
            .unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.map(Character.init))
    }

    /// 1 − distanza di modifica / lunghezza della più lunga.
    static func somiglianza(_ a: String, _ b: String) -> Double {
        let x = Array(a), y = Array(b)
        if x.isEmpty && y.isEmpty { return 1 }
        if x.isEmpty || y.isEmpty { return 0 }
        var prec = Array(0...y.count), cur = [Int](repeating: 0, count: y.count + 1)
        for i in 1...x.count {
            cur[0] = i
            for j in 1...y.count { cur[j] = min(prec[j] + 1, cur[j - 1] + 1, prec[j - 1] + (x[i - 1] == y[j - 1] ? 0 : 1)) }
            swap(&prec, &cur)
        }
        return 1 - Double(prec[y.count]) / Double(max(x.count, y.count))
    }

    // MARK: Dalle righe lette all'estrazione della catena

    /// Il corpo del carattere si stima dalla LARGHEZZA MEDIA DI UN CARATTERE della riga (larghezza del riquadro diviso il
    /// numero dei caratteri, spazi compresi), moltiplicata per `rapportoLarghezza`: al banco (circa 4.900 righe di cinque
    /// campioni, contro i corpi veri dell'estratto) l'errore mediano è del 4 per cento, uguale sulle scansioni pulite e su
    /// quelle storte; l'altezza del riquadro sbaglia del 7-11 per cento e cresce con la rotazione. Le righe brevi (meno di
    /// 12 caratteri) usano l'altezza (`rapportoAltezza`). Referto del giro, § 2.
    public static let rapportoLarghezza = 2.364
    public static let rapportoAltezza = 0.90
    static let caratteriMinimi = 12

    /// Le pagine dell'estrazione per le pagine lette: una riga di testo per riga letta, uno span (o più, coi richiami di
    /// nota) per riga. Il corpo: la stima della riga, poi la mediana della regione (le righe di un paragrafo hanno lo stesso
    /// corpo), poi i picchi dell'istogramma su tutto il documento (poche misure: la catena ragiona per gruppi di dimensioni).
    public static func pagineEstratte(_ lette: [PaginaLetta], migliorie: MiglioriScansioni = .spente) -> [Int: PdfPageExtraction] {
        let stime = lette.map { stimeDiPagina($0.righe) }
        let quantizza = picchi(zip(lette, stime).flatMap { p, st in zip(p.righe, st).map { ($0.1, Double(caratteri($0.0))) } })
        var uscita: [Int: PdfPageExtraction] = [:]
        for (pagina, st) in zip(lette, stime) {
            var p = pagina
            for k in p.righe.indices {
                p.righe[k].testo = numeroDiNotaInTesta(p.righe[k].testo)
                if migliorie.paragrafo { p.righe[k].testo = segnoDiParagrafo(p.righe[k].testo) }
            }
            let corpi = st.map(quantizza)
            let corpoTesto = corpoPrevalente(zip(p.righe, corpi).flatMap { r, c in Array(repeating: c, count: max(1, caratteri(r) / 10)) })
            let note = numeriDiNota(p.righe, corpi: corpi, corpoTesto: corpoTesto)
            let linee = zip(p.righe, corpi).map { r, corpo -> PdfTextLine in
                PdfTextLine(spans: spans(r, corpo: corpo, grassetto: titoloAmmesso(r, tra: p.righe),
                                         note: corpo >= corpoTesto ? note : []),
                            bbox: r.bbox)
            }
            uscita[p.pagina] = PdfPageExtraction(pageIndex: p.pagina, width: p.larghezza, height: p.altezza, lines: linee)
        }
        return uscita
    }

    /// I caratteri su cui si stima il corpo della riga: quelli della riga di Apple da cui viene la geometria (`caratteriApple`), se il testo
    /// è di un altro lettore; altrimenti quelli del testo.
    static func caratteri(_ r: RigaLetta) -> Int { r.caratteriApple ?? r.testo.count }

    /// La stima del corpo di ogni riga della pagina (prima dei gruppi).
    static func stimeDiPagina(_ righe: [RigaLetta]) -> [Double] {
        let proprie = righe.map { r -> Double in
            caratteri(r) >= caratteriMinimi ? rapportoLarghezza * r.bbox.width / Double(caratteri(r)) : r.bbox.height * rapportoAltezza
        }
        var perRegione: [Int: [Double]] = [:]
        for (r, e) in zip(righe, proprie) where caratteri(r) >= caratteriMinimi { perRegione[r.regione, default: []].append(e) }
        return zip(righe, proprie).map { r, e in
            guard caratteri(r) >= caratteriMinimi, let v = perRegione[r.regione], v.count >= 2 else { return e }
            let o = v.sorted()
            return (o[(o.count - 1) / 2] + o[o.count / 2]) / 2
        }
    }

    /// I gruppi dei corpi: istogramma a quarti di punto pesato coi caratteri, lisciato; i picchi (almeno l'1 per cento dei
    /// caratteri) sono le misure del documento; ogni stima va al picco più vicino entro l'8 per cento, se no al mezzo punto.
    static func picchi(_ stime: [(Double, Double)]) -> (Double) -> Double {
        let mezzo: (Double) -> Double = { ($0 * 2).rounded() / 2 }
        let n = 160   // da 0 a 40 punti
        var h = [Double](repeating: 0, count: n)
        for (v, peso) in stime where v > 0 && v < 40 { h[min(n - 1, Int(v * 4))] += peso }
        let totale = h.reduce(0, +)
        guard totale > 0 else { return mezzo }
        let kern = [1.0, 2, 3, 2, 1]
        let liscio = (0..<n).map { i in (0..<5).reduce(0.0) { acc, k in
            let j = i + k - 2; return acc + (j >= 0 && j < n ? h[j] * kern[k] : 0) } }
        var centri: [Double] = []
        for i in 0..<n where liscio[i] >= 0.01 * totale * 9 {
            let finestra = max(0, i - 2)...min(n - 1, i + 2)
            if finestra.allSatisfy({ liscio[$0] <= liscio[i] }) && !centri.contains(where: { abs($0 - (Double(i) + 0.5) / 4) < 0.5 }) {
                centri.append((Double(i) + 0.5) / 4)
            }
        }
        guard !centri.isEmpty else { return mezzo }
        return { v in
            let c = centri.min { abs($0 - v) < abs($1 - v) }!
            return abs(c - v) / max(c, 0.1) <= 0.08 ? mezzo(c) : mezzo(v)
        }
    }

    static func corpoPrevalente(_ corpi: [Double]) -> Double {
        var conti: [Double: Int] = [:]
        for c in corpi { conti[c, default: 0] += 1 }
        return conti.max { $0.value != $1.value ? $0.value < $1.value : $0.key > $1.key }?.key ?? 0
    }

    /// Guardia del tipo «titolo» del modello d'impaginazione: grassetto solo su una riga breve (al più 120 caratteri) di una
    /// regione di titolo con al più tre righe.
    static func titoloAmmesso(_ r: RigaLetta, tra righe: [RigaLetta]) -> Bool {
        guard let t = r.tipo, t == "section_header" || t == "title", r.testo.count <= 120 else { return false }
        return righe.filter { $0.regione == r.regione }.count <= 3
    }

    // MARK: Il segno di paragrafo (giro «migliorie del banco nelle app», 2026-11-21)

    /// IL SEGNO DI PARAGRAFO. «$ N» → «§ N» (il dollaro singolo SOLO se seguito da uno spazio) e «$$ N» o «$$N» → «§§», davanti a un
    /// numero che non è un importo (né migliaia né decimali con la virgola), mai dopo una lettera o una cifra («US$», «100$») né davanti
    /// all'apice di un richiamo («$^{12}$»). Mai il «$» che chiude un apice o una formula («$^{3}$1998»: l'edizione in apice davanti
    /// all'anno, come la scrive GLM), mai davanti a quattro o più cifre attaccate («$$1962»), e mai il dollaro singolo attaccato al numero
    /// («$8»): così Apple legge anche i richiami e le edizioni in apice («eziologica $8.», «$1998»). Misure: nel corpus (letture dell'iPad
    /// dei 55 libri) i «§» veri attaccati al numero sono 59 su più di 8.300, tutti da una a tre cifre; sul banco, conversioni del dollaro
    /// singolo con lo spazio confermate dalla verità della pagina 332 su 332 (Apple), attaccate 10 su 16. Il resto della misura nel
    /// commento di `MiglioriScansioni.paragrafo`.
    public static func segnoDiParagrafo(_ t: String) -> String {
        guard t.contains("$") else { return t }
        return sostituisci(#"(?<![\p{L}\p{N}$}])(\$\$(?=\s?\p{N})|\$(?=\s\p{N}))(?!\$)(?!\d{4})(?!\s?\d{1,3}(?:[.,]\d{3})+)(?!\s?\d+,\d{2}\b)(?!\s?\d+\$)"#, in: t) { g in
            g[1] == "$$" ? "§§" : "§"
        }
    }

    /// I numeri con cui cominciano le righe di nota della pagina (corpo minore del testo, nella metà bassa, «12 » o «12.»).
    static func numeriDiNota(_ righe: [RigaLetta], corpi: [Double], corpoTesto: Double) -> Set<String> {
        guard let alto = righe.map({ $0.bbox.y + $0.bbox.height }).max(), alto > 0 else { return [] }
        var numeri = Set<String>()
        for (r, c) in zip(righe, corpi) where c < corpoTesto && r.bbox.y < alto / 2 {
            let cifre = r.testo.prefix { $0.isNumber }
            guard (1...3).contains(cifre.count) else { continue }
            let dopo = r.testo.dropFirst(cifre.count).first
            if dopo == nil || dopo == " " || dopo == "." || dopo == ")" { numeri.insert(String(Int(cifre) ?? -1)) }
        }
        return numeri
    }

    /// Le parole dopo cui un numero è un riferimento e non un richiamo di nota («art. 12», «n. 3», «p. 45»…).
    static let primaDiNumero: Set<String> = ["art", "artt", "n", "nn", "p", "pp", "c", "cc", "comma", "commi", "cap", "capo", "l",
                                              "d", "lgs", "dlgs", "cfr", "vol", "sez", "tit", "lett", "par", "§", "anno", "nota",
                                              "note", "fig", "tab", "pag", "pagg", "cass", "sent", "ord", "r", "dpr", "dl"]

    /// Lo span della riga; con la guardia dei richiami: un numero (1-3 cifre) attaccato alla fine di una parola diventa uno
    /// span a parte, più piccolo e un po' più in alto, solo se una nota con quel numero comincia sulla stessa pagina.
    static func spans(_ r: RigaLetta, corpo: Double, grassetto: Bool, note: Set<String>) -> [PdfSpan] {
        func span(_ t: String, _ b: BBox, _ c: Double) -> PdfSpan {
            PdfSpan(text: t, fontSize: c, bold: grassetto, italic: false, color: "#000000", bbox: b)
        }
        // Gli apici di GLM: richiamo solo con la nota sulla pagina; altrimenti resta la cifra, attaccata (per esempio «m2»).
        let parole = r.testo.split(separator: " ").map(String.init)
        if parole.contains(where: { apice(in: $0) != nil }) {
            var pezzi: [(String, Bool)] = []
            var corrente = ""
            for (k, p) in parole.enumerated() {
                let sep = k == 0 || corrente.isEmpty && pezzi.isEmpty ? "" : " "
                if let a = apice(in: p), note.contains(String(Int(a.numero) ?? -1)) {
                    pezzi.append((corrente + sep + a.prima, false)); pezzi.append((a.numero, true)); corrente = a.dopo
                } else if let a = apice(in: p) {
                    corrente += sep + a.prima + a.numero + a.dopo
                } else {
                    corrente += sep + p
                }
            }
            if !corrente.isEmpty { pezzi.append((corrente, false)) }
            pezzi = pezzi.filter { !$0.0.isEmpty }
            if pezzi.contains(where: { $0.1 }) { return riquadri(pezzi, r, corpo, span) }
            return [span(pezzi.map(\.0).joined(), r.bbox, corpo)]
        }
        guard !note.isEmpty else { return [span(r.testo, r.bbox, corpo)] }
        var pezzi: [(String, Bool)] = []
        var corrente = ""
        for (k, p) in parole.enumerated() {
            let sep = k == 0 ? "" : " "
            let cifre = String(p.reversed().prefix { $0.isNumber }.reversed())
            let base = String(p.dropLast(cifre.count))
            let numero = String(Int(cifre) ?? -1)
            if (1...3).contains(cifre.count), base.count >= 2, base.last.map({ $0.isLetter || ".,;:»)".contains($0) }) == true,
               note.contains(numero) {
                // Numero attaccato alla parola: «parola12».
                pezzi.append((corrente + sep + base, false)); pezzi.append((cifre, true)); corrente = ""
            } else if k > 0, base.isEmpty, (1...3).contains(cifre.count), note.contains(numero),
                      let prima = parole[k - 1].last, prima.isLetter || ".,;:»)".contains(prima),
                      !primaDiNumero.contains(normalizza(String(parole[k - 1].split(whereSeparator: { "'’".contains($0) }).last ?? ""))) {
                // Numero staccato dopo una parola che non lo regge («parola 12»): richiamo solo con la nota sulla pagina.
                if !corrente.isEmpty { pezzi.append((corrente, false)) }
                pezzi.append((cifre, true)); corrente = ""
            } else {
                corrente += (corrente.isEmpty && pezzi.isEmpty ? "" : sep) + p
            }
        }
        if !corrente.isEmpty { pezzi.append((corrente, false)) }
        guard pezzi.contains(where: { $0.1 }) else { return [span(r.testo, r.bbox, corpo)] }
        return riquadri(pezzi, r, corpo, span)
    }

    /// I riquadri dei pezzi in proporzione ai caratteri (la lettura dà la riga intera); il richiamo più piccolo e più in alto.
    static func riquadri(_ pezzi: [(String, Bool)], _ r: RigaLetta, _ corpo: Double,
                         _ span: (String, BBox, Double) -> PdfSpan) -> [PdfSpan] {
        let totale = Double(max(1, pezzi.reduce(0) { $0 + $1.0.count }))
        var x = r.bbox.x
        return pezzi.map { t, richiamo in
            let w = r.bbox.width * Double(t.count) / totale
            defer { x += w }
            if richiamo {
                let h = r.bbox.height * 0.6
                return span(t, BBox(x: x, y: r.bbox.y + r.bbox.height - h, width: w, height: h), (corpo * 0.6 * 2).rounded() / 2)
            }
            return span(t, BBox(x: x, y: r.bbox.y, width: w, height: r.bbox.height), corpo)
        }
    }
}
