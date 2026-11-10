//
//  FinestraEFuocoTests.swift
//  ScaboMacLetturaTests — le due cure del giro «prove della tappa A» (2026-11-09), dentro il processo: i FIGLI FINESTRATI di un
//  libro lungo (DISEGNO_LETTURA_MAC § 2.3-2.4: il gruppo espone il primo elemento, una finestra attorno al fuoco e l'ultimo;
//  il percorso passo per passo, fatto come lo fa VoiceOver — i figli del gruppo, il seguente dell'elemento corrente, il fuoco
//  su di lui — arriva dall'inizio alla fine senza vicoli ciechi; VO+Fine e VO+Inizio; i rotori e i salti lontani) e
//  l'ELEMENTO COL FUOCO detto dalla vista dopo un salto, che è ciò che VoiceOver chiede per spostare il cursore. La prova da
//  fuori, sull'app vera, è in `FuocoDaFuoriTests`. Contenuti sintetici: nessun testo dei volumi.
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
        // VO+Inizio: il primo figlio è il primo elemento del libro; posato lì, i passi avanti proseguono dall'inizio.
        let primo = try! XCTUnwrap(esposti(v).first)
        XCTAssertEqual(primo.indice, 0)
        primo.setAccessibilityFocused(true)
        c = primo
        for atteso in [1, 2, 3] {
            let figli = esposti(v)
            let k = try! XCTUnwrap(figli.firstIndex { $0 === c })
            c = figli[k + 1]
            XCTAssertEqual(c.indice, atteso)
            c.setAccessibilityFocused(true)
        }
    }

    /// Chi scorre col trackpad o con la barra lontano dal fuoco trova fra i figli, e fra i figli visibili, le righe che vede;
    /// la finestra resta quella del fuoco, così il cursore di VoiceOver prosegue di dov'era.
    func test_scorrimentoLontanoDalFuoco_righeInVistaFraIFigli() throws {
        let n = 3_000
        let v = libroLungo(n)
        let scorrimento = NSScrollView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        scorrimento.documentView = v
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 400), styleMask: [.titled], backing: .buffered, defer: false)
        w.contentView = scorrimento
        v.frame.size.width = 600
        v.spostaFuoco(a: 100)
        v.scrollToVisible(v.rettangolo(2_000))   // la vista scorre lontano, il fuoco resta a 100
        let righe = v.righeVisibili
        XCTAssertTrue(righe.contains(2_000), "le righe in vista sono quelle scorse: \(righe)")
        let figli = esposti(v).map(\.indice)
        XCTAssertTrue(Set(righe).isSubset(of: Set(figli)), "le righe in vista sono figli")
        XCTAssertTrue(figli.contains(100) && figli.contains(101), "la finestra del fuoco resta")
        let visibili = (v.accessibilityVisibleChildren() ?? []).compactMap { ($0 as? ElementoLettura)?.indice }
        XCTAssertEqual(visibili, Array(righe))
        XCTAssertNil(v.attenzione)
        for e in esposti(v) { _ = e.accessibilityValue() }
        XCTAssertNil(v.attenzione, "leggere le righe in vista non accende l'attenzione")
    }

    /// Dopo un salto VoiceOver si posa sul bersaglio e gli ridà il fuoco: è la conferma dello stesso arrivo, e il segnale
    /// della nota non suona due volte né la posizione si registra due volte.
    func test_salto_poiConfermaDiVoiceOver_unSegnaleSolo() {
        let segmenti = (0..<600).map { i -> ContentSegment in
            ContentSegment(id: "s\(i)", role: i == 300 ? SemanticCategory.NOTE.rawValue : SemanticCategory.BODY.rawValue,
                           text: i == 300 ? "1 Nota sintetica di prova." : "Capoverso di prova numero \(i).",
                           lengthCategory: i == 300 ? "SHORT" : "", acousticIntro: i == 300 ? "Nota." : "")
        }
        let v = VistaLettura(segmenti: segmenti, impostazioni: ReadingSpeechSettings())
        var suonati: [[AudioSignal]] = []
        var posizioni: [Int] = []
        v.suonatore = { suonati.append($0) }
        v.quandoCambiaIlFuoco = { posizioni.append($0) }
        let attesi = ReadingSpeech.focusSignals(for: v.segmento(300), previousFocusedRole: nil,
                                                noteSpokenLabels: v.impostazioni.noteSpokenLabels)
        XCTAssertFalse(attesi.isEmpty, "la nota sintetica ha il suo segnale")
        v.spostaFuoco(a: 300)                       // il salto
        v.elemento(300).setAccessibilityFocused(true)   // VoiceOver si posa e conferma
        XCTAssertEqual(posizioni, [300])
        XCTAssertEqual(suonati, [attesi], "un segnale solo per l'arrivo")
        v.elemento(301).setAccessibilityFocused(true)   // un passo vero, dopo
        v.elemento(300).setAccessibilityFocused(true)   // e il ritorno sulla nota: arrivo nuovo
        XCTAssertEqual(posizioni, [300, 301, 300])
    }

    /// L'argomento di prova `--raggio-finestra`: una finestra piccola espone i figli finestrati anche sul libro sintetico.
    func test_finestraPiccolaDelleProve() {
        let r0 = VistaLettura.raggioFinestra, m0 = VistaLettura.margineFinestra
        defer { VistaLettura.raggioFinestra = r0; VistaLettura.margineFinestra = m0 }
        VistaLettura.raggioFinestra = 4
        VistaLettura.margineFinestra = 1
        let v = libroLungo(24)
        XCTAssertTrue(v.finestrato)
        XCTAssertEqual(esposti(v).map(\.indice), Array(0...8) + [23])
        var c = esposti(v)[0]
        c.setAccessibilityFocused(true)
        while let k = esposti(v).firstIndex(where: { $0 === c }), k + 1 < esposti(v).count {
            let s = esposti(v)[k + 1]
            XCTAssertEqual(s.indice, c.indice + 1)
            s.setAccessibilityFocused(true)
            c = s
        }
        XCTAssertEqual(c.indice, 23)
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

    /// Un client che legge il testo di tutti i figli esposti — VoiceOver all'ingresso, il runner dei test — non li cambia:
    /// né gli elementi 0 e n−1 né i vicini dell'elemento in attenzione la spostano.
    func test_leggereIFigliEsposti_nonLiCambia() {
        let n = 3_000
        let v = libroLungo(n)
        v.spostaFuoco(a: 1_500)
        let prima = esposti(v).map(\.indice)
        for e in esposti(v) { _ = e.accessibilityValue() }
        XCTAssertNil(v.attenzione)
        XCTAssertEqual(esposti(v).map(\.indice), prima, "gli stessi figli dopo una lettura completa")
        _ = v.elemento(2_500).accessibilityValue()   // la voce di un rotore, lontana
        XCTAssertEqual(v.attenzione, 2_500)
        let conVoce = esposti(v).map(\.indice)
        XCTAssertEqual(conVoce.count, prima.count + 5)
        for e in esposti(v) { _ = e.accessibilityValue() }
        XCTAssertEqual(v.attenzione, 2_500, "leggere i vicini non sposta l'attenzione")
        XCTAssertEqual(esposti(v).map(\.indice), conVoce)
    }

    /// Dopo un salto per programma la vista dice come elemento col fuoco il bersaglio (VoiceOver lo chiede dall'alto della
    /// finestra e sposta il cursore solo se è cambiato), e il bersaglio è fra i figli.
    func test_salto_elementoColFuocoDellaVista_eDellaFinestra() {
        let v = libroLungo(2_000)
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 400), styleMask: [.titled], backing: .buffered, defer: false)
        w.contentView = v
        XCTAssertTrue(w.makeFirstResponder(v))
        XCTAssertFalse(v.accessibilityFocusedUIElement is ElementoLettura, "senza fuoco: nessun elemento")
        v.impostaFuocoIniziale(5)
        XCTAssertEqual((v.accessibilityFocusedUIElement as? ElementoLettura)?.indice, 5)
        XCTAssertTrue(v.titolo(avanti: true))
        XCTAssertEqual((v.accessibilityFocusedUIElement as? ElementoLettura)?.indice, 50)
        v.spostaFuoco(a: 1_700)
        XCTAssertEqual((v.accessibilityFocusedUIElement as? ElementoLettura)?.indice, 1_700)
        XCTAssertTrue(esposti(v).contains { $0.indice == 1_700 })
        XCTAssertEqual((w.accessibilityFocusedUIElement as? ElementoLettura)?.indice, 1_700, "la finestra risponde con l'elemento")
        // Le frecce della tastiera passano dallo stesso salto.
        let giù = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: w.windowNumber,
                                   context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: 125)!
        v.keyDown(with: giù)
        XCTAssertEqual((v.accessibilityFocusedUIElement as? ElementoLettura)?.indice, 1_701)
        XCTAssertEqual(v.segnaliEmessi.last?.origine, .tastiera)
    }

    // MARK: L'arrivo di un salto (giro «prove rifatte», 2026-11-10: tre salti su sette, partiti dal menu delle azioni di
    // VoiceOver, non hanno spostato il cursore; la cura ripete l'avviso finché un client non si posa sul bersaglio)

    /// Fa girare il ciclo del filo principale per `secondi` (le ripetizioni dell'avviso sono blocchi in coda a tempo).
    private func gira(_ secondi: TimeInterval) {
        let fine = Date().addingTimeInterval(secondi)
        while Date() < fine { RunLoop.current.run(until: Date().addingTimeInterval(0.01)) }
    }

    /// Ritardi brevi per i test, ripristinati alla fine.
    private func conRitardiBrevi(_ corpo: () throws -> Void) rethrows {
        let prima = VistaLettura.ritardiRipetizione
        VistaLettura.ritardiRipetizione = [0.05, 0.12]
        defer { VistaLettura.ritardiRipetizione = prima }
        try corpo()
    }

    /// Nessun client si posa sul bersaglio (VoiceOver, chiudendo il suo menu delle azioni, rilegge la partenza): l'avviso del
    /// fuoco si ripete due volte, e il diario lo registra; il fuoco resta il bersaglio.
    func test_salto_senzaArrivo_ripeteLAvviso() {
        conRitardiBrevi {
            let v = libroLungo(30)
            v.diario.attivo = true
            XCTAssertTrue(v.esegui(.goToCall(target: 12), da: 11))   // un'azione personalizzata, come dal menu di VoiceOver
            _ = v.elemento(11).accessibilityValue()   // la rilettura della partenza
            gira(0.3)
            XCTAssertEqual(v.ripetizioniAvviso, 2)
            XCTAssertEqual(v.fuoco, 12)
            XCTAssertEqual(v.diario.voci.filter { $0.richiesta == "fuoco:ripeti-avviso" }.map(\.indice), [12, 12])
        }
    }

    /// Il client si posa sul bersaglio chiedendone le azioni (VoiceOver lo fa a ogni arrivo): nessuna ripetizione, nessun
    /// bersaglio detto due volte.
    func test_salto_conArrivo_nessunaRipetizione() {
        conRitardiBrevi {
            let v = libroLungo(30)
            v.spostaFuoco(a: 12)
            _ = v.elemento(12).accessibilityCustomActions()
            gira(0.3)
            XCTAssertEqual(v.ripetizioniAvviso, 0)
        }
    }

    /// Il client dà il fuoco al bersaglio (la conferma di VoiceOver): nessuna ripetizione.
    func test_salto_confermaColFuoco_nessunaRipetizione() {
        conRitardiBrevi {
            let v = libroLungo(30)
            v.spostaFuoco(a: 12)
            v.elemento(12).setAccessibilityFocused(true)
            gira(0.3)
            XCTAssertEqual(v.ripetizioniAvviso, 0)
            XCTAssertEqual(v.segnaliEmessi.count, 1, "la conferma non è un arrivo nuovo")
        }
    }

    /// Dopo il salto il fuoco va altrove (l'utente si è mosso): l'avviso del salto vecchio non si ripete.
    func test_salto_poiFuocoAltrove_nessunaRipetizione() {
        conRitardiBrevi {
            let v = libroLungo(30)
            v.spostaFuoco(a: 12)
            v.elemento(14).setAccessibilityFocused(true)
            gira(0.3)
            XCTAssertEqual(v.ripetizioniAvviso, 0)
            XCTAssertEqual(v.fuoco, 14)
        }
    }

    /// Un salto nuovo prima delle ripetizioni del vecchio: si ripete solo l'avviso del nuovo; e la prova a secco della
    /// descrizione non ripete mai nulla.
    func test_salto_nuovoSalto_ripeteSoloIlNuovo_provaASeccoMai() {
        conRitardiBrevi {
            let v = libroLungo(30)
            v.spostaFuoco(a: 12)
            v.spostaFuoco(a: 20)
            gira(0.3)
            XCTAssertEqual(v.ripetizioniAvviso, 2)
            v.provaASecco = true
            v.spostaFuoco(a: 25)
            v.provaASecco = false
            gira(0.3)
            XCTAssertEqual(v.ripetizioniAvviso, 2, "a secco nessuna ripetizione")
        }
    }

    /// Il diario registra l'azione eseguita (col suo codice, senza testo) e l'annuncio senza bersaglio.
    func test_diario_azioneEAnnuncio() {
        let v = libroLungo(30)
        v.diario.attivo = true
        XCTAssertTrue(v.esegui(.goToCall(target: 3), da: 7))
        v.impostaFuocoIniziale(4)
        XCTAssertFalse(v.saltaNotaRichiamo())
        let r = v.diario.voci.map(\.richiesta)
        XCTAssertTrue(r.contains("azione:vai-al-richiamo"))
        XCTAssertTrue(r.contains("annuncio"))
        XCTAssertFalse(r.contains { $0.contains("Capoverso") }, "nessun testo nel diario")
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
