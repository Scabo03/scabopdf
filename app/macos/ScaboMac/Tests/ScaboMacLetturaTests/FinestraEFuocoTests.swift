//
//  FinestraEFuocoTests.swift
//  ScaboMacLetturaTests — la cura della prova T1 del giro «prove della tappa A» (2026-11-09), dentro il processo: i FIGLI FINESTRATI di un
//  libro lungo (DISEGNO_LETTURA_MAC § 2.3-2.4: il gruppo espone il primo elemento, una finestra attorno al fuoco e l'ultimo;
//  il percorso passo per passo, fatto come lo fa VoiceOver — i figli del gruppo, il seguente dell'elemento corrente, il fuoco
//  su di lui — arriva dall'inizio alla fine senza vicoli ciechi; VO+Fine e VO+Inizio; i rotori e i salti lontani) e il
//  diario delle prove (fatti del processo, sentinella del filo principale). Contenuti sintetici: nessun testo dei volumi.
//
import AppKit
import ScaboChain
import ScaboCore
import XCTest
@testable import ScaboMacLettura

@MainActor
final class FinestraEFuocoTests: XCTestCase {

    /// Un libro lungo sintetico: un titolo ogni cinquanta elementi, il resto capoversi con frasi neutre numerate.
    private func libroLungo(_ n: Int) -> VistaLettura {
        let segmenti = (0..<n).map { i -> ContentSegment in
            let titolo = i % 50 == 0
            return ContentSegment(id: "s\(i)", role: titolo ? SemanticCategory.HEADING_2.rawValue : SemanticCategory.BODY.rawValue,
                                  text: titolo ? "Sezione \(i / 50 + 1)" : "Capoverso di prova numero \(i).",
                                  lengthCategory: "", acousticIntro: "")
        }
        return VistaLettura(segmenti: segmenti, impostazioni: ReadingSpeechSettings())
    }

    private func esposti(_ v: VistaLettura) -> [ElementoLettura] { (v.accessibilityChildren() ?? []).compactMap { $0 as? ElementoLettura } }

    func test_libroCorto_tuttiIFigli_comePrima() {
        let v = libroLungo(VistaLettura.finestraMassima)
        XCTAssertFalse(v.finestrato)
        XCTAssertEqual(esposti(v).map(\.indice), Array(0..<VistaLettura.finestraMassima))
        XCTAssertEqual((v.accessibilityChildrenInNavigationOrder() ?? []).count, VistaLettura.finestraMassima)
    }

    func test_libroLungo_primoFinestraUltimo_inOrdine() {
        let n = 2_000
        let v = libroLungo(n)
        XCTAssertTrue(v.finestrato)
        let figli = esposti(v).map(\.indice)
        XCTAssertEqual(figli, Array(0...(2 * VistaLettura.raggioFinestra)) + [n - 1], "dall'inizio: la finestra parte da 0, più l'ultimo")
        XCTAssertEqual((v.accessibilityChildrenInNavigationOrder() ?? []).compactMap { ($0 as? ElementoLettura)?.indice }, figli)
        // Il fuoco a metà: primo, finestra attorno al fuoco, ultimo; i figli visibili sono figli esposti.
        v.spostaFuoco(a: 1_000)
        let attorno = esposti(v).map(\.indice)
        XCTAssertEqual(attorno.first, 0)
        XCTAssertEqual(attorno.last, n - 1)
        XCTAssertEqual(Array(attorno.dropFirst().dropLast()), Array((1_000 - 200)...(1_000 + 200)))
        XCTAssertEqual(attorno, attorno.sorted(), "in ordine di lettura")
        let visibili = (v.accessibilityVisibleChildren() ?? []).compactMap { ($0 as? ElementoLettura)?.indice }
        XCTAssertTrue(Set(visibili).isSubset(of: Set(attorno)))
    }

    /// La finestra resta ferma finché il fuoco sta a più di `margineFinestra` dai bordi: i figli cambiano di rado.
    func test_finestra_siSpostaSoloVicinoAlBordo() {
        let v = libroLungo(3_000)
        v.spostaFuoco(a: 1_000)
        let f0 = v.finestra
        XCTAssertEqual(f0, 800..<1_201)
        v.riceviFuoco(1_100, origine: .accessibilita); v.aggiornaFinestra()
        XCTAssertEqual(v.finestra, f0, "a cento dal bordo la finestra non si muove")
        v.riceviFuoco(1_151, origine: .accessibilita); v.aggiornaFinestra()
        XCTAssertEqual(v.finestra, 951..<1_352, "a cinquanta dal bordo si ricentra sul fuoco")
        v.riceviFuoco(2_990, origine: .accessibilita); v.aggiornaFinestra()
        XCTAssertEqual(v.finestra, 2_599..<3_000, "alla fine del libro la finestra tocca l'ultimo elemento")
    }

    /// Il percorso integrale come lo fa VoiceOver (diario T2: a ogni passo i figli del gruppo, poi il fuoco sul seguente):
    /// dall'inizio alla fine senza vicoli ciechi né salti; poi VO+Fine, tre passi indietro, VO+Inizio.
    func test_percorsoIntegrale_senzaVicoliCiechi_VOFine_VOInizio() {
        let n = 1_234
        let v = libroLungo(n)
        var corrente = esposti(v)[0]
        corrente.setAccessibilityFocused(true)
        var passi = 0, massimoFigli = 0
        while true {
            let figli = esposti(v)
            massimoFigli = max(massimoFigli, figli.count)
            guard let k = figli.firstIndex(where: { $0 === corrente }) else { return XCTFail("vicolo cieco a \(corrente.indice)") }
            guard k + 1 < figli.count else { break }
            let seguente = figli[k + 1]
            XCTAssertEqual(seguente.indice, corrente.indice + 1, "nessun salto")
            seguente.setAccessibilityFocused(true)
            corrente = seguente
            passi += 1
        }
        XCTAssertEqual(corrente.indice, n - 1, "arriva all'ultimo elemento del libro")
        XCTAssertEqual(passi, n - 1)
        XCTAssertLessThanOrEqual(massimoFigli, VistaLettura.finestraMassima + 2)
        // VO+Fine dal mezzo del libro: l'ultimo figlio è l'ultimo elemento; poi indietro di tre, uno alla volta.
        v.spostaFuoco(a: 600)
        let ultimo = try! XCTUnwrap(esposti(v).last)
        XCTAssertEqual(ultimo.indice, n - 1)
        ultimo.setAccessibilityFocused(true)
        var c = ultimo
        for atteso in [n - 2, n - 3, n - 4] {
            let figli = esposti(v)
            let k = try! XCTUnwrap(figli.firstIndex { $0 === c })
            c = figli[k - 1]
            XCTAssertEqual(c.indice, atteso)
            c.setAccessibilityFocused(true)
        }
        // VO+Inizio: il primo figlio è il primo elemento del libro.
        XCTAssertEqual(esposti(v).first?.indice, 0)
    }

    /// Un rotore porta lontano: il delegato restituisce un elemento fuori dalla finestra; VoiceOver ne chiede il testo e poi
    /// i figli del gruppo prima di posarsi (diario T3): il bersaglio è fra i figli, e quando arriva il fuoco la finestra si
    /// ricentra su di lui.
    func test_rotoreLontano_bersaglioFraIFigli_poiFinestraSuDiLui() throws {
        let v = libroLungo(5_000)
        v.impostaFuocoIniziale(10)
        let rotore = try XCTUnwrap(v.rotori().first { v.rotoreDelModulo($0) == .headings })
        var corrente: NSAccessibilityCustomRotor.ItemResult? = NSAccessibilityCustomRotor.ItemResult(targetElement: v.elemento(10))
        var bersaglio: ElementoLettura?
        for _ in 0..<60 {   // sessanta titoli avanti: al titolo dell'elemento 3.050
            let p = NSAccessibilityCustomRotor.SearchParameters()
            p.currentItem = corrente
            p.searchDirection = .next
            let r = try XCTUnwrap(v.rotor(rotore, resultFor: p))
            corrente = r
            bersaglio = r.targetElement as? ElementoLettura
        }
        let b = try XCTUnwrap(bersaglio)
        XCTAssertEqual(b.indice, 3_000)
        XCTAssertFalse(esposti(v).contains { $0 === b }, "lontano dalla finestra")
        _ = b.accessibilityValue()   // VoiceOver dice la voce del rotore
        XCTAssertTrue(esposti(v).contains { $0 === b }, "il bersaglio detto è fra i figli")
        b.setAccessibilityFocused(true)   // VoiceOver si posa
        XCTAssertEqual(v.fuoco, 3_000)
        XCTAssertNil(v.attenzione)
        XCTAssertTrue(v.finestra.contains(3_000) && v.finestra.contains(2_800) && v.finestra.contains(3_200))
    }

    /// Il diario: i fatti (fasi, fermi del filo principale) si annotano anche a diario sospeso e si scrivono in ordine di tempo
    /// con le richieste; la sentinella annota un fermo vero del filo principale.
    func test_diario_fattiESentinella() throws {
        let d = Diario()
        d.registra(3, "AXValue")
        d.sospeso = true
        d.registra(4, "AXValue")
        d.registraFatto(-3, "apertura:finestra:12ms")
        d.sospeso = false
        XCTAssertEqual(d.voci.map(\.indice), [3])
        XCTAssertEqual(d.fatti.map(\.richiesta), ["apertura:finestra:12ms"])
        d.avviaSentinella()
        let fine = Date().addingTimeInterval(1)
        while Date() < fine { RunLoop.current.run(until: Date().addingTimeInterval(0.05)) }
        Thread.sleep(forTimeInterval: 0.6)   // il filo principale fermo per sei decimi di secondo
        let dopo = Date().addingTimeInterval(1)
        while Date() < dopo { RunLoop.current.run(until: Date().addingTimeInterval(0.05)) }
        d.attivo = false
        let fermi = d.fatti.filter { $0.richiesta.hasPrefix("filo-principale-fermo:") }
        XCTAssertFalse(fermi.isEmpty, "la sentinella ha visto il fermo")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("diario-\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: url) }
        try d.scrivi(su: url)
        let righe = try String(contentsOf: url, encoding: .utf8).split(separator: "\n").dropFirst()
        let tempi = righe.compactMap { Double($0.split(separator: "\t").first ?? "") }
        XCTAssertEqual(tempi, tempi.sorted(), "in ordine di tempo")
        XCTAssertTrue(righe.contains { $0.contains("\t-3\tapertura:finestra:12ms") })
    }
}
