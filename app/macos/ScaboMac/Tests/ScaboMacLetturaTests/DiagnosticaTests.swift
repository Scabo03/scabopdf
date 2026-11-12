//
//  DiagnosticaTests.swift
//  ScaboMacLetturaTests — il pannello «Diagnostica», il diario e le varianti dei titoli (giro «ScaboPDF per Mac su TestFlight»,
//  2026-11-12; LAYER2 § 12.16, decisione 17). Che cosa provano: con la diagnostica spenta nessuna sonda è attiva e la lettura
//  risponde a VoiceOver come sempre; accesa, la lettura risponde LO STESSO (il diario ascolta e basta); il diario sta nella sua
//  cartella e contiene solo codici e numeri, mai il testo del libro; spento, non scrive più; la variante dei titoli vale subito;
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
        VarianteTitoli.attiva = VarianteTitoli.predefinita
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
        VarianteTitoli.attiva = VarianteTitoli.predefinita
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

    func test_preferenze_predefinite_nascostaSpentoVarianteC() {
        let p = InMemoryKeyValueStore()
        XCTAssertFalse(PreferenzeDiagnostica.mostrata(p))
        XCTAssertFalse(PreferenzeDiagnostica.diarioAcceso(p))
        XCTAssertEqual(PreferenzeDiagnostica.variante(p), .C)
        p.setItem(PreferenzeDiagnostica.chiaveVariante, "Z")
        XCTAssertEqual(PreferenzeDiagnostica.variante(p), .C, "una chiave guasta torna alla predefinita")
        PreferenzeDiagnostica.impostaMostrata(p, true); PreferenzeDiagnostica.impostaDiario(p, true)
        PreferenzeDiagnostica.impostaVariante(p, .B)
        XCTAssertTrue(PreferenzeDiagnostica.mostrata(p)); XCTAssertTrue(PreferenzeDiagnostica.diarioAcceso(p))
        XCTAssertEqual(PreferenzeDiagnostica.variante(p), .B)
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
        XCTAssertTrue(testo.contains("diagnostica:diario:acceso") && testo.contains("diagnostica:variante-titoli:C"))
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

    // MARK: La variante dei titoli vale subito

    func test_varianteTitoli_valeSubito_ancheNelLibroAperto() async throws {
        let f = try await apri()
        let v = f.vista
        let titolo = try XCTUnwrap(v.modello.nextHeadingIndex(from: -1, level: nil, forward: true))
        let e = v.elemento(titolo)
        let senza = v.testoSenzaQualifica(titolo)
        XCTAssertNotEqual(senza, v.testoPronunciato(titolo), "la qualifica del modulo esce dal testo")
        // C (predefinita): intestazione, testo nella descrizione, nessun titolo, livello nell'attributo.
        XCTAssertEqual(e.accessibilityRole()?.rawValue, "AXHeading")
        XCTAssertEqual(e.accessibilityLabel(), senza)
        XCTAssertNil(e.accessibilityTitle())
        XCTAssertEqual((e.accessibilityAttributeValue(NSAccessibility.Attribute(rawValue: "AXHeadingLevel")) as? NSNumber)?.intValue, 1)
        // D: il testo nel titolo, il livello nel valore.
        VarianteTitoli.attiva = .D
        v.titoliCambiati()
        XCTAssertEqual(e.accessibilityTitle(), senza)
        XCTAssertEqual((e.accessibilityValue() as? NSNumber)?.intValue, 1)
        // Un capoverso non cambia in nessuna variante.
        let capoverso = try XCTUnwrap((0..<v.conteggio).first { v.livelloTitolo($0) == nil })
        XCTAssertEqual(v.elemento(capoverso).accessibilityRole(), .staticText)
        XCTAssertEqual(v.elemento(capoverso).accessibilityValue() as? String, v.testoPronunciato(capoverso))
        // B: con la finestra piccola, tutti i titoli fra i figli esposti.
        VarianteTitoli.attiva = .B
        v.impostaFinestra(raggio: 1)
        let esposti = Set((v.accessibilityChildren() ?? []).compactMap { ($0 as? ElementoLettura)?.indice })
        XCTAssertTrue(Set(v.modello.headingIndex.map(\.index)).isSubset(of: esposti))
        VarianteTitoli.attiva = .C
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

    func test_pannello_versioneInChiaro_diario_varianti_prova() {
        let d = Diagnostica(prefs: InMemoryKeyValueStore(), cartella: cartella)
        let w = FinestraDiagnostica(diagnostica: d, info: ["CFBundleShortVersionString": "1.0", "CFBundleVersion": "7"])
        let testi = (w.window?.contentView?.subviews ?? []).compactMap { ($0 as? NSTextField)?.stringValue }
        XCTAssertTrue(testi.contains("ScaboPDF per Mac, versione 1.0, build 7"), "\(testi)")
        XCTAssertEqual(w.interruttoreDiario.state, .off)
        XCTAssertEqual(w.statoDiario.stringValue, Parole.diagnosticaDiarioSpento)
        XCTAssertEqual(w.varianti.filter { $0.state == .on }.map { $0.identifier?.rawValue }, ["C"])
        var scelte: [VarianteTitoli.Lettera] = []
        w.quandoCambiaLaVariante = { scelte.append($0) }
        w.varianti.first { $0.identifier?.rawValue == "D" }?.performClick(nil)
        XCTAssertEqual(scelte, [.D])
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
        for b in [w.interruttoreDiario, w.mostraCartella, w.esporta, w.finestraPiccola, w.apriLibro] + w.varianti {
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
