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

// MARK: - Le righe lette

/// Una riga letta su una pagina scansionata: testo, riquadro in punti PDF con origine in basso a sinistra (come `BBox` di
/// ScaboCore), la regione del modello d'impaginazione (ordine di lettura) e il suo tipo.
public struct RigaLetta: Codable, Equatable, Sendable {
    public var testo: String
    public var bbox: BBox
    public var regione: Int
    public var tipo: String?

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

    /// L'immagine in scala di grigi della pagina, al lato lungo dato.
    public static func immagine(della pagina: PDFPage, latoLungo: CGFloat = latoLungoPixel) -> CGImage? {
        let box = pagina.bounds(for: .cropBox)
        guard box.width > 0, box.height > 0 else { return nil }
        let scala = min(300.0 / 72.0, latoLungo / max(box.width, box.height))
        let w = Int((box.width * scala).rounded()), h = Int((box.height * scala).rounded())
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        ctx.setFillColor(gray: 1, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.scaleBy(x: scala, y: scala)
        ctx.translateBy(x: -box.minX, y: -box.minY)
        pagina.draw(with: .cropBox, to: ctx)
        return ctx.makeImage()
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
        if #available(macOS 26.0, *) {
            return try attendi { try await righeDocumento(img, W: W, H: H) }
        }
        return try righeTestoClassico(img, W: W, H: H)
    }

    @available(macOS 26.0, *)
    private static func righeDocumento(_ img: CGImage, W: Double, H: Double) async throws -> [RigaLetta] {
        let req = RecognizeDocumentsRequest()
        let osservazioni = try await req.perform(on: img)
        var paragrafi: [BBox] = []
        var righe: [(String, BBox)] = []
        for o in osservazioni {
            let d = o.document
            for p in d.paragraphs { paragrafi.append(bbox(p.boundingRegion.boundingBox.origin.x, p.boundingRegion.boundingBox.origin.y,
                                                          p.boundingRegion.boundingBox.width, p.boundingRegion.boundingBox.height, W, H)) }
            for l in d.text.lines {
                let r = l.boundingRegion.boundingBox
                let t = l.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                if !t.isEmpty { righe.append((t, bbox(r.origin.x, r.origin.y, r.width, r.height, W, H))) }
            }
        }
        // Ogni riga nel paragrafo che ne contiene il centro (l'ordine dei paragrafi è quello di Apple); le righe fuori da ogni
        // paragrafo (tabelle) vanno col paragrafo più vicino.
        return righe.map { t, b in
            let cx = b.x + b.width / 2, cy = b.y + b.height / 2
            let k = paragrafi.firstIndex { cx >= $0.x && cx <= $0.x + $0.width && cy >= $0.y && cy <= $0.y + $0.height }
                ?? paragrafi.indices.min { distanza(paragrafi[$0], cx, cy) < distanza(paragrafi[$1], cx, cy) } ?? 0
            return RigaLetta(testo: t, bbox: b, regione: k)
        }
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
        guard let (img, W, H) = HeronPageRenderer.renderPage(pagina) else { return [] }
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
    public static func guardia(righe: [RigaLetta], testoGlm: String) -> (righe: [RigaLetta], conti: [String: Int]) {
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
            if stessaRiga && somiglianza(unitoV, unitoG) >= 0.75 {
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
    public static func pagineEstratte(_ lette: [PaginaLetta]) -> [Int: PdfPageExtraction] {
        let stime = lette.map { stimeDiPagina($0.righe) }
        let quantizza = picchi(zip(lette, stime).flatMap { p, st in zip(p.righe, st).map { ($0.1, Double($0.0.testo.count)) } })
        var uscita: [Int: PdfPageExtraction] = [:]
        for (pagina, st) in zip(lette, stime) {
            var p = pagina
            for k in p.righe.indices { p.righe[k].testo = numeroDiNotaInTesta(p.righe[k].testo) }
            let corpi = st.map(quantizza)
            let corpoTesto = corpoPrevalente(zip(p.righe, corpi).flatMap { r, c in Array(repeating: c, count: max(1, r.testo.count / 10)) })
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

    /// La stima del corpo di ogni riga della pagina (prima dei gruppi).
    static func stimeDiPagina(_ righe: [RigaLetta]) -> [Double] {
        let proprie = righe.map { r -> Double in
            r.testo.count >= caratteriMinimi ? rapportoLarghezza * r.bbox.width / Double(r.testo.count) : r.bbox.height * rapportoAltezza
        }
        var perRegione: [Int: [Double]] = [:]
        for (r, e) in zip(righe, proprie) where r.testo.count >= caratteriMinimi { perRegione[r.regione, default: []].append(e) }
        return zip(righe, proprie).map { r, e in
            guard r.testo.count >= caratteriMinimi, let v = perRegione[r.regione], v.count >= 2 else { return e }
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
