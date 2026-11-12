//
//  BancoIdentitaTests.swift
//  ScaboMacLetturaTests — LA RETE D'IDENTITÀ DELLA VISTA DEL MAC CON LA VISTA DELL'IPAD (giro «app unica per Mac, tappa A»,
//  2026-11-08; DISEGNO_LETTURA_MAC § 3.4, passo 1). Gira solo a richiesta: `SCABO_BANCO_MAC_RICHIESTA=<file.json>` (senza, si
//  salta). I libri, le letture congelate e i riferimenti stanno nel laboratorio, fuori dal repo, e contengono testo dei volumi:
//  le uscite vanno solo lì.
//
//  Per ogni libro, due misure separate, perché si sappia DA DOVE viene una differenza:
//   (V) LA VISTA. La vista vera del Mac (`FinestraLettura`, finestra non mostrata) sulla lettura CONGELATA dell'iPad (la stessa
//       che ha prodotto i riferimenti), descritta da sé, contro la vista dell'iPad (`riferimento/`, VoiceOver spento, e
//       `riferimento_vo/`, VoiceOver acceso), «note a voce» spenta e accesa. Il riferimento si confronta senza le azioni che la
//       tappa A non ha ancora (segnalibro, «Strumenti elemento», «Estrai come immagine»); che il filtro tolga esattamente quelle
//       e nient'altro lo prova il terzo confronto: il modulo con le impostazioni del Mac contro il riferimento filtrato.
//   (A) L'APP. Il PDF importato dall'app Mac col percorso vero (`ImportazioneMac`: impronta, elaborazione con l'estrattore del
//       Mac, registrazione, cache), riaperto come l'app lo riapre (per i volumi enormi: rielaborato a 1.200), descritto dalla
//       vista e confrontato con lo stesso riferimento; e la lettura del Mac contro quella congelata dell'iPad, segmento per
//       segmento (quanti, dove: è la quota dell'ESTRATTORE).
//  Dal giro «ScaboPDF per Mac su TestFlight» (2026-11-12): i titoli del Mac hanno il ruolo d'intestazione (`VarianteTitoli`, la
//  variante attiva, predefinita la C) e ogni confronto della vista passa dall'ECCEZIONE DICHIARATA dei titoli (`EccezioneTitoli`,
//  LAYER2 § 12.16 decisione 12): solo gli elementi che il modulo dice titoli, solo ruolo e testo detto, tutti e soli i titoli. Il
//  numero degli elementi riportati è nell'esito (`eccezioneTitoli`); se non torna, il confronto è «diverso».
//  Richiesta: {"libri": <libri.json della rete sul parlato>, "riferimento": <dir>, "riferimentoVO": <dir>, "corpus": {"originals":
//  <dir>, ...}, "uscite": <dir>, "solo": <fine del nome, facoltativo>, "misure": <stem del volume da misurare, facoltativo>}.
//
import AppKit
import ScaboChain
import ScaboCore
import XCTest
@testable import ScaboMacLettura

@MainActor
final class BancoIdentitaTests: XCTestCase {

    struct Richiesta: Decodable {
        var libri: String
        var riferimento: String
        var riferimentoVO: String
        var corpus: [String: String]
        var uscite: String
        var solo: String?
        var misure: String?
    }
    struct Libro: Decodable { var libro: String; var lettura: String; var impronta: String }
    struct Libri: Decodable { var letture: [Libro] }
    /// La lettura congelata (la forma della cache dell'iPad).
    struct LetturaCongelata: Decodable { var content: PaginatedContent; var contentTarget: Int? }

    static let azioniDelleTappeDopo: Set<String> = ["Aggiungi segnalibro", "Modifica segnalibro", "Rimuovi segnalibro",
                                                    "Strumenti elemento", "Estrai come immagine"]

    /// Il riferimento dell'iPad senza le azioni che la tappa A non ha (con i loro bersagli, posizione per posizione).
    static func filtra(_ d: ReadingDescription) -> ReadingDescription {
        var out = d
        out.elements = d.elements.map { e in
            var f = e
            let tieni = e.actions.indices.filter { !azioniDelleTappeDopo.contains(e.actions[$0]) }
            f.actions = tieni.map { e.actions[$0] }
            f.actionTargets = tieni.map { e.actionTargets[$0] }
            return f
        }
        return out
    }

    static func riassunto(_ r: ReadingComparisonResult, eccezione: EccezioneTitoli.Esito? = nil) -> [String: Any] {
        var out: [String: Any] = ["identiche": r.identical && (eccezione?.tuttiESoliITitoli ?? true), "divergenze": r.totalDivergences,
                                  "elementiA": r.elementsA, "elementiB": r.elementsB]
        if let e = eccezione {
            out["eccezioneTitoli"] = ["riportati": e.riportati, "titoliDelModulo": e.titoliDelModulo, "variante": VarianteTitoli.lettera]
        }
        out["perTipo"] = Dictionary(uniqueKeysWithValues: r.counts.map { ($0.key.rawValue, $0.value) })
        if let f = r.first { out["prima"] = ["tipo": f.kind.rawValue, "campo": f.field, "indiceA": f.indexA as Any, "indiceB": f.indexB as Any] }
        return out
    }

    /// La memoria residente del processo, in megabyte.
    static func memoriaMB() -> Double {
        var info = mach_task_basic_info()
        var n = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
        let kr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(n)) { task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &n) }
        }
        return kr == KERN_SUCCESS ? Double(info.resident_size) / 1_048_576 : -1
    }

    func test_reteIdentita_vistaDelMac_controLaVistaDellIPad() async throws {
        guard let path = ProcessInfo.processInfo.environment["SCABO_BANCO_MAC_RICHIESTA"] else {
            throw XCTSkip("banco a richiesta: SCABO_BANCO_MAC_RICHIESTA=<file.json> (vedi la testata del file)")
        }
        let req = try JSONDecoder().decode(Richiesta.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
        let libri = try JSONDecoder().decode(Libri.self, from: Data(contentsOf: URL(fileURLWithPath: req.libri))).letture
            .filter { req.solo == nil || $0.libro.hasSuffix(req.solo!) }
        let uscite = URL(fileURLWithPath: req.uscite)
        try FileManager.default.createDirectory(at: uscite.appendingPathComponent("letture_mac"), withIntermediateDirectories: true)
        var esiti: [[String: Any]] = []
        let enc = JSONEncoder(); enc.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]

        for b in libri {
            let t0 = Date()
            var esito: [String: Any] = ["libro": b.libro]
            let parti = b.libro.split(separator: "/", maxSplits: 1).map(String.init)
            let dir = parti[0], stem = parti[1]
            func riferimento(_ base: String, _ n: Int) throws -> ReadingDescription {
                try ReadingDescription.decode(Data(contentsOf: URL(fileURLWithPath: "\(base)/\(b.libro).lc.n\(n).jsonl")))
            }
            func descrivi(_ lettura: LibraryReading, _ doc: ArchivedDocument, libreria: LibreriaMac, n: Int,
                          vo: Bool) -> (ReadingDescription, ReadingDescription, EccezioneTitoli.Esito) {
                PreferenzeLettura.impostaNoteAVoce(libreria.prefs, n == 1)
                let f = FinestraLettura(documento: doc, lettura: lettura, libreria: libreria, voiceOver: vo)
                let (v, eccezione) = EccezioneTitoli.applica(f.vista.descrizioneDallaVista(libro: b.libro, layout: .continuousReading),
                                                             segmenti: f.vista.modello.segments)
                let m = f.vista.descrizioneDelModulo(libro: b.libro, layout: .continuousReading)
                f.close()
                return (v, m, eccezione)
            }

            // ── (V) la vista del Mac sulla lettura congelata dell'iPad ─────────────────────────────────────────────
            let radiceV = FileManager.default.temporaryDirectory.appendingPathComponent("banco-v-\(UUID().uuidString)")
            let libV = LibreriaMac(service: LibraryService(rootDirectory: radiceV, prefs: InMemoryKeyValueStore()))
            let congelata = try JSONDecoder().decode(LetturaCongelata.self, from: Data(contentsOf: URL(fileURLWithPath: b.lettura)))
            // Con l'impronta del libro: la vista ne ricava le opzioni dei legami nota ↔ richiamo (cure mirate), come l'iPad.
            let finto = ArchivedDocument(id: "banco", title: stem, sourceFileName: stem + ".pdf", importedAt: Date(),
                                         sourcePageCount: 1, readingPosition: 0, warnings: [], sourceSha256: b.impronta)
            let letturaIPad = LibraryReading(content: congelata.content, pageMap: [:], doctrineContent: nil, quickConsultTree: nil)
            var vista: [String: Any] = [:]
            for n in [0, 1] {
                let rif = Self.filtra(try riferimento(req.riferimento, n))
                let (v, m, ecc) = descrivi(letturaIPad, finto, libreria: libV, n: n, vo: false)
                vista["n\(n)"] = Self.riassunto(ReadingDescriptionComparison.compare(rif, v), eccezione: ecc)
                vista["n\(n)_moduloMac_rifFiltrato"] = ReadingDescriptionComparison.compare(rif, m).identical
                vista["n\(n)_vistaUgualeModulo_byte"] = (try? v.encoded()) == (try? m.encoded()) && ecc.tuttiESoliITitoli
                let rifVO = Self.filtra(try riferimento(req.riferimentoVO, n))
                let (vvo, _, eccvo) = descrivi(letturaIPad, finto, libreria: libV, n: n, vo: true)
                vista["n\(n)_vo"] = Self.riassunto(ReadingDescriptionComparison.compare(rifVO, vvo), eccezione: eccvo)
            }
            esito["vista"] = vista
            try? FileManager.default.removeItem(at: radiceV)

            // ── (A) l'app Mac importa il PDF da sé ─────────────────────────────────────────────────────────────────
            // Un esito che non è un confronto porta «non misurato»: la rete lo conta come rosso, mai come quota dell'estrattore.
            guard let radiceCorpus = req.corpus[dir] else { esito["app"] = "non misurato: corpus assente"; esiti.append(esito); continue }
            let pdf = URL(fileURLWithPath: radiceCorpus).appendingPathComponent(stem + ".pdf")
            guard FileManager.default.fileExists(atPath: pdf.path) else {
                esito["app"] = "non misurato: PDF assente nel corpus"; esiti.append(esito); continue
            }
            let impronta = try? DocumentFingerprint.sha256Hex(ofFileAt: pdf)
            guard impronta == b.impronta else {
                esito["app"] = "non misurato: impronta del PDF diversa da quella della lettura"; esiti.append(esito); continue
            }
            let radiceA = FileManager.default.temporaryDirectory.appendingPathComponent("banco-a-\(UUID().uuidString)")
            let libA = LibreriaMac(service: LibraryService(rootDirectory: radiceA, prefs: InMemoryKeyValueStore()))
            let imp = ImportazioneMac(libreria: libA)
            let pres = PresentatoreDiProva()
            imp.presentatore = pres
            let misura = req.misure.map { stem.hasSuffix($0) } ?? false
            var tempi: [String: Double] = [:]
            let mem0 = Self.memoriaMB()
            let tImp = Date()
            let e1 = expectation(description: "importato")
            pres.quandoApre = { e1.fulfill() }
            imp.importa(pdf)
            await fulfillment(of: [e1], timeout: 1800)
            tempi["importazione_s"] = Date().timeIntervalSince(tImp)
            guard pres.errori.isEmpty, let importato = pres.aperte.last?.0 else {
                esito["app"] = ["non misurato": "errore d'importazione", "errori": pres.errori]; esiti.append(esito); continue
            }
            // Riaperta come la riapre l'app (per i volumi enormi: rielaborata leggera a 1.200 e messa in cache).
            let tApr = Date()
            let e2 = expectation(description: "riaperto")
            pres.quandoApre = { e2.fulfill() }
            imp.apri(importato.id)
            await fulfillment(of: [e2], timeout: 1800)
            tempi["riapertura_s"] = Date().timeIntervalSince(tApr)
            let (docMac, letturaMac) = pres.aperte.last!
            var app: [String: Any] = [:]
            for n in [0, 1] {
                let rif = Self.filtra(try riferimento(req.riferimento, n))
                let (v, _, ecc) = descrivi(letturaMac, docMac, libreria: libA, n: n, vo: false)
                app["n\(n)"] = Self.riassunto(ReadingDescriptionComparison.compare(rif, v), eccezione: ecc)
            }
            // La lettura del Mac contro quella congelata dell'iPad, segmento per segmento.
            let sMac = letturaMac.content.pages.flatMap { $0.segments }, sIPad = congelata.content.pages.flatMap { $0.segments }
            app["segmentiMac"] = sMac.count; app["segmentiIPad"] = sIPad.count
            app["segmentiIdentici"] = sMac == sIPad
            if sMac != sIPad {
                let k = (0..<min(sMac.count, sIPad.count)).first { sMac[$0] != sIPad[$0] } ?? min(sMac.count, sIPad.count)
                app["primoSegmentoDiverso"] = k
                app["paginaDelPrimoDiverso"] = (k < sIPad.count ? sIPad[k].sourcePage : nil) as Any
                app["pagineToccate"] = Array(Set(zip(sMac, sIPad).filter { $0 != $1 }.compactMap { $0.1.sourcePage })).sorted()
            }
            app["granularitaCache"] = libA.service.loadCache(forDocumentId: docMac.id)?.contentTarget as Any
            esito["app"] = app
            // La lettura del Mac nel laboratorio (forma della cache, chiavi ordinate) per il confronto con le due generazioni.
            struct Uscita: Encodable { var content: PaginatedContent; var contentTarget: Int? }
            let out = uscite.appendingPathComponent("letture_mac/\(b.libro).lettura.json")
            try FileManager.default.createDirectory(at: out.deletingLastPathComponent(), withIntermediateDirectories: true)
            try enc.encode(Uscita(content: letturaMac.content, contentTarget: libA.service.loadCache(forDocumentId: docMac.id)?.contentTarget)).write(to: out)

            if misura {
                // Tempi e memoria sul volume più grande: apertura dalla cache, primo elemento, scorrimento su tutto il libro.
                let mem1 = Self.memoriaMB()
                let tOpen = Date()
                let doc2 = libA.service.store.document(id: docMac.id)!
                let pronta = libA.service.openableCachedReading(for: doc2)!
                let tCache = Date().timeIntervalSince(tOpen)
                let f = FinestraLettura(documento: doc2, lettura: pronta, libreria: libA, voiceOver: false)
                f.window?.setFrame(NSRect(x: 0, y: 0, width: 900, height: 700), display: false)
                let tVista = Date().timeIntervalSince(tOpen)
                let figli = f.vista.accessibilityChildren() ?? []
                let primo = (figli.first as? ElementoLettura)?.accessibilityValue() as? String
                tempi["apertura_dallaCache_s"] = tCache
                tempi["apertura_finestra_s"] = tVista
                tempi["primoElemento_s"] = Date().timeIntervalSince(tOpen)
                tempi["primoElemento_letto"] = primo == nil ? 0 : 1
                let memAperto = Self.memoriaMB()
                let tScorr = Date()
                for i in stride(from: 0, to: f.vista.conteggio, by: 1) { f.vista.riceviFuoco(i, origine: .tastiera) }
                tempi["scorrimento_tutti_s"] = Date().timeIntervalSince(tScorr)
                tempi["elementi"] = Double(f.vista.conteggio)
                tempi["memoria_inizio_MB"] = mem0; tempi["memoria_dopoImportazione_MB"] = mem1
                tempi["memoria_libroAperto_MB"] = memAperto; tempi["memoria_dopoScorrimento_MB"] = Self.memoriaMB()
                f.close()
            }
            esito["tempi"] = tempi
            esito["secondi"] = Date().timeIntervalSince(t0)
            try? FileManager.default.removeItem(at: radiceA)
            esiti.append(esito)
            print("BANCO \(b.libro) vista=\(((vista["n0"] as? [String: Any])?["identiche"] as? Bool) ?? false)/\(((vista["n1"] as? [String: Any])?["identiche"] as? Bool) ?? false) app=\(((app["n0"] as? [String: Any])?["identiche"] as? Bool) ?? false)/\(((app["n1"] as? [String: Any])?["identiche"] as? Bool) ?? false) segmenti=\(app["segmentiIdentici"] ?? false)")
        }
        let dati = try JSONSerialization.data(withJSONObject: ["libri": esiti], options: [.prettyPrinted, .sortedKeys])
        try dati.write(to: uscite.appendingPathComponent("esiti.json"))
    }
}
