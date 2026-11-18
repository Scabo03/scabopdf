//
//  DiagnosticaTests.swift
//  ScaboMacLetturaTests — il pannello «Diagnostica», il diario e i titoli in una forma sola (giro «ScaboPDF per Mac su TestFlight»,
//  2026-11-12; LAYER2 § 12.16, decisione 17). Che cosa provano: con la diagnostica spenta nessuna sonda è attiva e la lettura
//  risponde a VoiceOver come sempre; accesa, la lettura risponde LO STESSO (il diario ascolta e basta); il diario sta nella sua
//  cartella e contiene solo codici e numeri, mai il testo del libro; spento, non scrive più; i titoli hanno una forma sola;
//  la voce del menu è nascosta di serie; l'eccezione del confronto tocca solo i titoli e solo due campi. Libro sintetico: nessun
//  testo dei volumi.
//
import AppKit
import ScaboChain
import ScaboCore
import XCTest
@testable import ScaboMacLettura

@MainActor
final class DiagnosticaTests: XCTestCase {
    private var radice: URL!
    private var cartella: URL!
    private var libreria: LibreriaMac!
    private var importazione: ImportazioneMac!
    private var presentatore: PresentatoreDiProva!
    private var pdf: URL!

    override func setUp() async throws {
        let base = FileManager.default.temporaryDirectory
        radice = base.appendingPathComponent("diagnostica-libreria-\(UUID().uuidString)", isDirectory: true)
        cartella = base.appendingPathComponent("diagnostica-cartella-\(UUID().uuidString)", isDirectory: true)
        libreria = LibreriaMac(service: LibraryService(rootDirectory: radice, prefs: InMemoryKeyValueStore()))
        importazione = ImportazioneMac(libreria: libreria)
        presentatore = PresentatoreDiProva()
        importazione.presentatore = presentatore
        pdf = try LibroSintetico.scrivi(in: base.appendingPathComponent("Libro di prova \(UUID().uuidString).pdf"))
    }

    override func tearDown() async throws {
        for u in [radice, cartella, pdf] { if let u { try? FileManager.default.removeItem(at: u) } }
    }

    /// Il libro sintetico importato col percorso vero e aperto in una finestra di lettura (non mostrata).
    private func apri() async throws -> FinestraLettura {
        let e = expectation(description: "lettura aperta")
        presentatore.quandoApre = { e.fulfill() }
        importazione.importa(pdf)
        await fulfillment(of: [e], timeout: 120)
        presentatore.quandoApre = nil
        let (doc, lettura) = try XCTUnwrap(presentatore.aperte.first)
        return FinestraLettura(documento: doc, lettura: lettura, libreria: libreria, voiceOver: true)
    }

    /// Ciò che VoiceOver chiede a ogni elemento, come nei diari: ruolo, testo, descrizione, titolo, cornice, azioni, rotori,
    /// elementi collegati, e il fuoco. Ritorna le risposte (per confrontarle fra diagnostica spenta e accesa).
    private func giroDiVoiceOver(_ v: VistaLettura) -> [String] {
        var risposte: [String] = []
        _ = v.accessibilityChildren()
        _ = v.accessibilityCustomRotors()
        for i in 0..<v.conteggio {
            let e = v.elemento(i)
            risposte.append([e.accessibilityRole()?.rawValue ?? "-", String(describing: e.accessibilityValue() ?? "-"),
                             e.accessibilityLabel() ?? "-", e.accessibilityTitle() ?? "-",
                             (e.accessibilityCustomActions() ?? []).map(\.name).joined(separator: "|"),
                             "\(e.accessibilityCustomRotors().count)",
                             "\((e.accessibilityLinkedUIElements() ?? []).count)"].joined(separator: "§"))
            e.setAccessibilityFocused(true)
        }
        return risposte
    }

    // MARK: Le preferenze

    func test_preferenze_predefinite_nascostaSpento() {
        let p = InMemoryKeyValueStore()
        XCTAssertFalse(PreferenzeDiagnostica.mostrata(p))
        XCTAssertFalse(PreferenzeDiagnostica.diarioAcceso(p))
        PreferenzeDiagnostica.impostaMostrata(p, true); PreferenzeDiagnostica.impostaDiario(p, true)
        XCTAssertTrue(PreferenzeDiagnostica.mostrata(p)); XCTAssertTrue(PreferenzeDiagnostica.diarioAcceso(p))
        XCTAssertTrue(Diagnostica.cartellaStandard().path.hasSuffix("Application Support/ScaboPDF per Mac/Diagnostica"),
                      "il diario sta nel contenitore dell'app, nella cartella dei dati dell'app")
    }

    // MARK: Spenta, nulla cambia; accesa, la lettura risponde lo stesso

    func test_diagnosticaSpenta_nessunaSonda_eLaLetturaRispondeComeSempre() async throws {
        let f = try await apri()
        let v = f.vista
        let d = Diagnostica(prefs: libreria.prefs, cartella: cartella)
        d.visteAperte = { [v] }
        d.collega(v)
        XCTAssertFalse(d.acceso)
        XCTAssertFalse(v.diario.attivo, "spenta: la vista ha il diario spento")
        let descrizioneSpenta = try v.descrizioneDallaVista(libro: "prova", layout: .continuousReading).encoded()
        let risposteSpenta = giroDiVoiceOver(v)
        XCTAssertTrue(v.diario.voci.isEmpty && v.diario.fatti.isEmpty, "spenta: nessuna richiesta annotata")
        XCTAssertFalse(FileManager.default.fileExists(atPath: cartella.path), "spenta: nessun file")
        // Mostrare il menu non cambia nulla della lettura.
        PreferenzeDiagnostica.impostaMostrata(libreria.prefs, true)
        XCTAssertEqual(try v.descrizioneDallaVista(libro: "prova", layout: .continuousReading).encoded(), descrizioneSpenta)
        // Accesa: il diario ascolta, la lettura risponde con le stesse parole, gli stessi ruoli, le stesse azioni.
        d.accendi()
        XCTAssertTrue(v.diario === d.diario)
        let risposteAccesa = giroDiVoiceOver(v)
        XCTAssertEqual(risposteAccesa, risposteSpenta, "le sonde non cambiano ciò che VoiceOver riceve")
        XCTAssertEqual(try v.descrizioneDallaVista(libro: "prova", layout: .continuousReading).encoded(), descrizioneSpenta)
        XCTAssertFalse(v.diario.voci.isEmpty, "accesa: le richieste ci sono")
        d.spegni()
        XCTAssertFalse(v.diario.attivo, "spenta di nuovo: la vista torna a un diario spento")
        XCTAssertEqual(giroDiVoiceOver(v), risposteSpenta)
        f.close()
    }

    // MARK: Il diario: dove sta, che cosa contiene

    func test_diario_nellaSuaCartella_soloCodiciENumeri_maiTestoDelLibro() async throws {
        let f = try await apri()
        let v = f.vista
        let d = Diagnostica(prefs: libreria.prefs, cartella: cartella, info: ["CFBundleShortVersionString": "1.0", "CFBundleVersion": "3"])
        d.visteAperte = { [v] }
        d.accendi()
        _ = giroDiVoiceOver(v)
        v.saltaNotaRichiamo()
        v.titolo(avanti: true)
        d.annota("prova:fatto")
        d.scriviAdesso()
        let file = try XCTUnwrap(d.file)
        XCTAssertEqual(file.deletingLastPathComponent().standardizedFileURL, cartella.standardizedFileURL)
        XCTAssertTrue(file.lastPathComponent.hasPrefix("diario_") && file.pathExtension == "txt")
        let testo = try String(contentsOf: file, encoding: .utf8)
        let righe = testo.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        XCTAssertEqual(righe.first.map { $0 + "\n" }, Diario.testata)
        XCTAssertTrue(righe.dropFirst().first?.hasPrefix("# versione 1.0, build 3, macOS ") == true)
        let forma = try NSRegularExpression(pattern: "^[0-9]+\\.[0-9]{3}\t-?[0-9]+\t[^\t]+$")
        let corpo = righe.filter { !$0.hasPrefix("#") }
        XCTAssertGreaterThan(corpo.count, v.conteggio, "le richieste di un giro intero")
        for r in corpo {
            XCTAssertNotNil(forma.firstMatch(in: r, range: NSRange(r.startIndex..., in: r)), "riga fuori forma: \(r)")
        }
        XCTAssertTrue(testo.contains("diagnostica:diario:acceso"))
        XCTAssertFalse(testo.contains("variante-titoli"), "nessuna variante dei titoli: la forma è una sola")
        XCTAssertTrue(testo.contains("fuoco:") && testo.contains("AXRole"))
        // Nessuna parola del libro: le parole lunghe del testo dei segmenti non compaiono nel diario.
        let parole = Set(v.modello.segments.flatMap { $0.text.split(whereSeparator: { !$0.isLetter }).map(String.init) }
            .filter { $0.count >= 7 })
        XCTAssertGreaterThan(parole.count, 10)
        for p in parole { XCTAssertFalse(testo.localizedCaseInsensitiveContains(p), "«\(p)» del libro è finita nel diario") }
        f.close()
    }

    func test_diario_spento_nonScrivePiu_eSiEsportaLUltimo() async throws {
        let f = try await apri()
        let v = f.vista
        let d = Diagnostica(prefs: libreria.prefs, cartella: cartella)
        d.visteAperte = { [v] }
        d.accendi()
        _ = giroDiVoiceOver(v)
        let file = try XCTUnwrap(d.file)
        d.spegni()
        XCTAssertNil(d.diario)
        let dimensione = try XCTUnwrap(try FileManager.default.attributesOfItem(atPath: file.path)[.size] as? Int)
        _ = giroDiVoiceOver(v)
        d.scriviAdesso()
        XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: file.path)[.size] as? Int, dimensione, "spento non scrive")
        XCTAssertEqual(d.fileDaEsportare?.lastPathComponent, file.lastPathComponent, "spento, si esporta il più recente")
        let destinazione = cartella.appendingPathComponent("esportato.txt")
        try d.esporta(verso: destinazione)
        XCTAssertEqual(try Data(contentsOf: destinazione), try Data(contentsOf: file))
        f.close()
    }

    func test_diario_tieneGliUltimiVentiFile() throws {
        try FileManager.default.createDirectory(at: cartella, withIntermediateDirectories: true)
        for k in 0..<25 { try Data().write(to: cartella.appendingPathComponent(String(format: "diario_20260101_0000%02d.txt", k))) }
        let d = Diagnostica(prefs: InMemoryKeyValueStore(), cartella: cartella)
        d.accendi()
        d.spegni()
        XCTAssertEqual(d.fileDelDiario().count, Diagnostica.fileTenuti, "i più vecchi si tolgono all'accensione")
        XCTAssertEqual(d.fileDelDiario().first?.lastPathComponent, d.file?.lastPathComponent, "il più recente è quello appena scritto")
    }

    // MARK: I titoli, una forma sola (giro «titoli definitivi», 2026-11-18: la variante C del giro delle varianti)

    /// L'intestazione come SwiftUI: ruolo `AXHeading`, il testo senza la qualifica nella descrizione, nessun titolo, il livello in
    /// `AXHeadingLevel` (anche nell'elenco degli attributi); un capoverso resta testo statico col testo pronunciato nel valore.
    /// Con la finestra piccola i titoli lontani NON sono fra i figli (la variante B, che li esponeva tutti, è tolta).
    func test_titoli_intestazioneComeSwiftUI_unaFormaSola() async throws {
        let f = try await apri()
        let v = f.vista
        let titolo = try XCTUnwrap(v.modello.nextHeadingIndex(from: -1, level: nil, forward: true))
        let e = v.elemento(titolo)
        let senza = v.testoSenzaQualifica(titolo)
        XCTAssertNotEqual(senza, v.testoPronunciato(titolo), "la qualifica del modulo esce dal testo")
        XCTAssertEqual(e.accessibilityRole()?.rawValue, "AXHeading")
        XCTAssertEqual(e.accessibilityLabel(), senza)
        XCTAssertNil(e.accessibilityTitle())
        XCTAssertEqual((e.accessibilityAttributeValue(NSAccessibility.Attribute(rawValue: "AXHeadingLevel")) as? NSNumber)?.intValue, 1)
        XCTAssertTrue(e.accessibilityAttributeNames().map(\.rawValue).contains("AXHeadingLevel"))
        XCTAssertFalse(e.accessibilityValue() is NSNumber, "il livello non sta nel valore")
        let capoverso = try XCTUnwrap((0..<v.conteggio).first { v.livelloTitolo($0) == nil })
        XCTAssertEqual(v.elemento(capoverso).accessibilityRole(), .staticText)
        XCTAssertEqual(v.elemento(capoverso).accessibilityValue() as? String, v.testoPronunciato(capoverso))
        XCTAssertFalse(v.elemento(capoverso).accessibilityAttributeNames().map(\.rawValue).contains("AXHeadingLevel"))
        v.impostaFinestra(raggio: 1)
        let esposti = Set((v.accessibilityChildren() ?? []).compactMap { ($0 as? ElementoLettura)?.indice })
        let titoli = v.modello.headingIndex.map(\.index)
        XCTAssertGreaterThanOrEqual(titoli.count, 6)
        XCTAssertFalse(Set(titoli).isSubset(of: esposti), "i titoli lontani non sono fra i figli esposti")
        f.close()
    }

    /// VO+Comando+H, VO+Comando+Maiuscole+H e VO+Comando+M COME NEL DIARIO DELLA PROVA SULL'APP DI TESTFLIGHT (2026-11-18): una
    /// ricerca generica (`AXUIElementsForSearchPredicate`) rivolta all'elemento sotto il cursore, SENZA l'elemento di partenza,
    /// col limite uno. La risposta parte dal cursore, avanti e indietro, anche verso titoli fuori dai figli esposti; oltre gli
    /// estremi nulla; lo stesso livello per VO+Comando+M; la stessa ricerca rivolta al gruppo parte dal fuoco; una chiave che non
    /// è dei titoli la lascia ad AppKit.
    func test_titoli_ricercaGenerica_dalCursore_avantiEIndietro_comeNelDiario() async throws {
        let f = try await apri()
        let v = f.vista
        v.impostaFinestra(raggio: 1)
        let titoli = v.modello.headingIndex.map(\.index)
        let attr = NSAccessibility.ParameterizedAttribute(rawValue: "AXUIElementsForSearchPredicate")
        func cerca(da i: Int, _ chiave: String, avanti: Bool, sulGruppo: Bool = false) -> [Int]? {
            let p: [String: Any] = ["AXSearchKey": chiave, "AXDirection": avanti ? "AXDirectionNext" : "AXDirectionPrevious",
                                    "AXResultsLimit": 1]
            let r = sulGruppo ? v.accessibilityAttributeValue(attr, forParameter: p)
                              : v.elemento(i).accessibilityAttributeValue(attr, forParameter: p)
            return (r as? [ElementoLettura])?.map(\.indice)
        }
        XCTAssertTrue(v.elemento(0).accessibilityParameterizedAttributeNames().contains(attr))
        XCTAssertTrue(v.accessibilityParameterizedAttributeNames().contains(attr))
        // Avanti, dal primo titolo fino all'ultimo, poi nulla.
        var cursore = titoli[0], avanti: [Int] = []
        while let t = cerca(da: cursore, "AXHeadingSearchKey", avanti: true)?.first { avanti.append(t); cursore = t }
        XCTAssertEqual(avanti, Array(titoli.dropFirst()))
        // Indietro, dall'ultimo titolo fino al primo, poi nulla.
        var indietro: [Int] = []
        while let t = cerca(da: cursore, "AXHeadingSearchKey", avanti: false)?.first { indietro.append(t); cursore = t }
        XCTAssertEqual(indietro, Array(titoli.dropLast().reversed()))
        // Dal mezzo di un capoverso: il titolo seguente e il precedente, non l'inizio del libro.
        let mezzo = titoli[2] + 1
        XCTAssertEqual(cerca(da: mezzo, "AXHeadingSearchKey", avanti: true), [titoli[3]])
        XCTAssertEqual(cerca(da: mezzo, "AXHeadingSearchKey", avanti: false), [titoli[2]])
        // Lo stesso livello (VO+Comando+M): nel libro di prova tutti i titoli sono di livello 1.
        XCTAssertEqual(cerca(da: titoli[1], "AXHeadingSameLevelSearchKey", avanti: true), [titoli[2]])
        XCTAssertEqual(cerca(da: titoli[1], "AXHeadingSameLevelSearchKey", avanti: false), [titoli[0]])
        // Rivolta al gruppo: dal fuoco.
        v.riceviFuoco(titoli[3], origine: .programma)
        XCTAssertEqual(cerca(da: -1, "AXHeadingSearchKey", avanti: true, sulGruppo: true), [titoli[4]])
        XCTAssertEqual(cerca(da: -1, "AXHeadingSearchKey", avanti: false, sulGruppo: true), [titoli[2]])
        // Un'altra chiave (VO+Comando+J, i controlli): la risposta non è nostra.
        XCTAssertNil(v.ricercaGenerica(["AXSearchKey": "AXControlSearchKey"], da: titoli[0]))
        f.close()
    }

    func test_finestraPiccola_soloPerQuestaVista() {
        let segmenti = (0..<40).map { i in
            ContentSegment(id: "s\(i)", role: SemanticCategory.BODY.rawValue, text: "Capoverso di prova numero \(i).",
                           lengthCategory: "", acousticIntro: "")
        }
        let a = VistaLettura(segmenti: segmenti, impostazioni: ReadingSpeechSettings())
        let b = VistaLettura(segmenti: segmenti, impostazioni: ReadingSpeechSettings())
        a.impostaFinestra(raggio: 1)
        XCTAssertTrue(a.finestrato)
        XCTAssertEqual((a.accessibilityChildren() ?? []).count, 3 + 1, "la finestra di tre elementi più l'ultimo del libro")
        XCTAssertFalse(b.finestrato, "l'altra vista non cambia")
        XCTAssertEqual(VistaLettura.raggioFinestra, 200)
    }

    // MARK: Il menu e le Impostazioni

    func test_menuDiagnostica_nascostoDiSerie_visibileSeScelto() {
        let nascosto = MenuPrincipale.barra(comandi: ComandiFinti())
        let voce = MenuPrincipale.voceDiagnostica(in: nascosto)
        XCTAssertEqual(voce?.isHidden, true)
        XCTAssertEqual(voce?.title, Parole.diagnosticaConPuntini)
        XCTAssertEqual(voce?.action, #selector(ComandiApp.mostraDiagnostica(_:)))
        XCTAssertEqual(voce?.keyEquivalent, "", "nessuna scorciatoia")
        XCTAssertEqual(MenuPrincipale.voceDiagnostica(in: MenuPrincipale.barra(comandi: ComandiFinti(), diagnostica: true))?.isHidden, false)
    }

    func test_impostazioni_sceltaDellaDiagnostica_salvaEAvvisa() {
        let p = InMemoryKeyValueStore()
        let w = FinestraImpostazioni(prefs: p)
        XCTAssertEqual(w.diagnostica.state, .off)
        XCTAssertEqual(w.diagnostica.title, Parole.impostazioniMostraDiagnostica)
        var avvisi: [Bool] = []
        w.quandoCambiaLaDiagnostica = { avvisi.append($0) }
        w.diagnostica.performClick(nil)
        XCTAssertTrue(PreferenzeDiagnostica.mostrata(p))
        XCTAssertEqual(avvisi, [true])
        w.close()
    }

    // MARK: Il pannello

    func test_pannello_versioneInChiaro_diario_prova_nessunaVariante() {
        let d = Diagnostica(prefs: InMemoryKeyValueStore(), cartella: cartella)
        let w = FinestraDiagnostica(diagnostica: d, info: ["CFBundleShortVersionString": "1.0", "CFBundleVersion": "7"])
        let testi = (w.window?.contentView?.subviews ?? []).compactMap { ($0 as? NSTextField)?.stringValue }
        XCTAssertTrue(testi.contains("ScaboPDF per Mac, versione 1.0, build 7"), "\(testi)")
        XCTAssertEqual(w.interruttoreDiario.state, .off)
        XCTAssertEqual(w.statoDiario.stringValue, Parole.diagnosticaDiarioSpento)
        let identificatori = (w.window?.contentView?.subviews ?? []).map { $0.accessibilityIdentifier() }
        XCTAssertFalse(identificatori.contains { $0.hasPrefix("diagnostica.variante") }, "la scelta dei titoli è tolta")
        XCTAssertFalse(testi.contains("I titoli"), "nemmeno il suo titolo")
        var diario: [Bool] = []
        w.quandoCambiaIlDiario = { diario.append($0) }
        w.interruttoreDiario.performClick(nil)
        XCTAssertTrue(d.acceso)
        XCTAssertEqual(diario, [true])
        XCTAssertTrue(w.statoDiario.stringValue.contains(d.file?.lastPathComponent ?? "?"))
        var prove: [Bool] = []
        w.quandoApreIlLibroDiProva = { prove.append($0) }
        w.apriLibro.performClick(nil)
        XCTAssertEqual(prove, [true], "di partenza con la finestra piccola")
        // Ogni controllo ha il suo nome per VoiceOver e il suo identificatore.
        for b in [w.interruttoreDiario, w.mostraCartella, w.esporta, w.finestraPiccola, w.apriLibro] {
            XCTAssertFalse(b.title.isEmpty)
            XCTAssertFalse(b.accessibilityIdentifier().isEmpty)
        }
        d.spegni()
        w.close()
    }

    // MARK: L'eccezione del confronto: solo i titoli, solo due campi

    func test_eccezioneTitoli_soloTitoli_soloRuoloETestoDetto() async throws {
        let f = try await apri()
        let v = f.vista
        let grezza = v.descrizioneDallaVista(libro: "prova", layout: .continuousReading)
        let modulo = v.descrizioneDelModulo(libro: "prova", layout: .continuousReading)
        let (ok, esito) = EccezioneTitoli.applica(grezza, segmenti: v.modello.segments)
        XCTAssertTrue(esito.tuttiESoliITitoli)
        XCTAssertTrue(ReadingDescriptionComparison.compare(modulo, ok).identical)
        let titolo = try XCTUnwrap(v.modello.nextHeadingIndex(from: -1, level: nil, forward: true))
        let capoverso = try XCTUnwrap((0..<v.conteggio).first { v.livelloTitolo($0) == nil })
        // Un capoverso diverso resta diverso.
        var guasta = grezza
        guasta.elements[capoverso].spokenText += " in più"
        XCTAssertFalse(ReadingDescriptionComparison.compare(modulo, EccezioneTitoli.applica(guasta, segmenti: v.modello.segments).0).identical)
        // Un titolo col testo diverso da quello dell'iPad senza la qualifica resta diverso.
        var titoloGuasto = grezza
        titoloGuasto.elements[titolo].spokenText = "Altro titolo"
        XCTAssertFalse(ReadingDescriptionComparison.compare(modulo, EccezioneTitoli.applica(titoloGuasto, segmenti: v.modello.segments).0).identical)
        // Un titolo con un altro campo cambiato (un rotore in meno) resta diverso.
        var rotoreGuasto = grezza
        rotoreGuasto.elements[titolo].rotors = []
        XCTAssertFalse(ReadingDescriptionComparison.compare(modulo, EccezioneTitoli.applica(rotoreGuasto, segmenti: v.modello.segments).0).identical)
        // Un titolo rimasto testo statico: l'eccezione non lo conta, e il conto non torna.
        var senzaRuolo = grezza
        senzaRuolo.elements[titolo].role = ReadingElementRole.staticText.rawValue
        XCTAssertFalse(EccezioneTitoli.applica(senzaRuolo, segmenti: v.modello.segments).1.tuttiESoliITitoli)
        f.close()
    }
}
