//
//  MiglioriScansioniTests.swift
//  ScaboMacKitTests — le migliorie della via delle scansioni (giro «migliorie del banco nelle app», 2026-11-21): il filtro della
//  notazione di GLM (toglie i segni, mai il testo), la protezione contro le righe ripetute, il segno di paragrafo (solo davanti a un
//  numero che non è un importo, o raddoppiato) e i numeri di nota letti come asterisco (dalla sequenza o dall'unico richiamo, altrimenti
//  senza numero: mai un numero inventato). Testi di prova inventati.
//
import Foundation
import ScaboCore
import XCTest
@testable import ScaboMacKit

final class MiglioriScansioniTests: XCTestCase {

    /// Le lettere e le cifre di un testo, senza i nomi dei comandi, le etichette e le entità (ciò che il filtro può togliere).
    private func lettereECifre(_ s: String, sorgente: Bool) -> String {
        var t = s
        if sorgente {
            t = t.replacingOccurrences(of: #"\\[A-Za-z]+"#, with: " ", options: .regularExpression)
            t = t.replacingOccurrences(of: #"<[^<>]{1,200}>"#, with: " ", options: .regularExpression)
            t = t.replacingOccurrences(of: #"&[A-Za-z]{2,8};"#, with: " ", options: .regularExpression)
        }
        return String(t.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.map(Character.init).sorted())
    }

    // MARK: il filtro della notazione

    func test_filtro_toglieLaNotazione_tieneLeLettereELeCifre() {
        let glm = "Il termine$^{12}$ scade nel $1990^{2}$ e vale $\\rightarrow$ sempre **molto** <b>bene</b> &amp; | a | b | e $x$ a 20$^\\circ$\n# Titolo di prova"
        let f = LetturaScansioni.filtraNotazione(glm)
        XCTAssertEqual(f, "Il termine$^{12}$ scade nel 1990$^{2}$ e vale → sempre molto bene & a b e x a 20°\nTitolo di prova")
        XCTAssertEqual(lettereECifre(f, sorgente: false), lettereECifre(glm, sorgente: true), "nessuna lettera e nessuna cifra tolta")
        let senzaApici = f.replacingOccurrences(of: #"\$\^\{[0-9]{1,3}\}\$"#, with: "", options: .regularExpression)
        XCTAssertNil(senzaApici.range(of: #"[{}\\|$^]|\*\*"#, options: .regularExpression),
                     "fuori dagli apici dei richiami (che la catena riconosce) nessun segno di notazione o di formattazione")
    }

    func test_filtro_dollaroDavantiAUnNumero_resta_glialtriSiTolgono() {
        XCTAssertEqual(LetturaScansioni.filtraNotazione("il $ 5 e il conto in US$ e un $ solo"), "il $ 5 e il conto in US$ e un solo")
        XCTAssertEqual(LetturaScansioni.filtraNotazione("vedi $ 3 e $ 4"), "vedi $ 3 e $ 4", "due dollari senza notazione fra loro non sono una formula")
        XCTAssertEqual(LetturaScansioni.filtraNotazione("la parola$^{7}$ chiude"), "la parola$^{7}$ chiude", "l'apice del richiamo resta per la catena")
        XCTAssertEqual(LetturaScansioni.filtraNotazione("una prova ^{4} staccata"), "una prova $^{4}$ staccata")
    }

    func test_senzaRipetizioni_unaRigaRipetutaDaGlm_unaVolta_seAppleLaVedeDueVolteResta() {
        func riga(_ t: String) -> RigaLetta { RigaLetta(testo: t, bbox: BBox(x: 0, y: 0, width: 100, height: 10), regione: 0) }
        let glm = "una riga di prova abbastanza lunga\naltra cosa qui\nuna riga di prova abbastanza lunga"
        let a = LetturaScansioni.senzaRipetizioni(glm, righeApple: [riga("una riga di prova abbastanza lunga"), riga("altra cosa qui")])
        XCTAssertEqual(a.tolte, 1)
        XCTAssertEqual(a.testo, "una riga di prova abbastanza lunga\naltra cosa qui")
        let b = LetturaScansioni.senzaRipetizioni(glm, righeApple: [riga("una riga di prova abbastanza lunga"), riga("altra cosa qui"),
                                                                    riga("una riga di prova abbastanza lunga")])
        XCTAssertEqual(b.tolte, 0, "ripetuta davvero sulla pagina: Apple la vede due volte")
        XCTAssertEqual(LetturaScansioni.senzaRipetizioni("corta\ncorta", righeApple: []).tolte, 0, "le righe brevi non si toccano")
    }

    // MARK: il segno di paragrafo

    func test_paragrafo_soloDavantiAUnNumero_oRaddoppiato() {
        let P = LetturaScansioni.segnoDiParagrafo
        XCTAssertEqual(P("come al $ 12 del capitolo"), "come al § 12 del capitolo")
        XCTAssertEqual(P("nei $$ 3-5 e al $4.2"), "nei §§ 3-5 e al §4.2")
        XCTAssertEqual(P("(cfr. $ 7)"), "(cfr. § 7)")
        for t in ["costa US$ 100", "un importo di $ 1.000", "pari a $ 5,50 al mese", "100$ in tutto", "la parola$^{12}$", "il $x e il $", "il valore $5$"] {
            XCTAssertEqual(P(t), t, "«\(t)»: denaro o notazione, resta")
        }
        // L'edizione in apice davanti all'anno: il «$» che chiude l'apice (GLM) e il «$» attaccato all'anno (Apple) non diventano «§»;
        // un «§» vero davanti a un numero di quattro cifre ha lo spazio, e resta convertito.
        for t in ["Milano, $^{3}$1998; trad.", "una nota.$^{169}$ 5. e poi", "Roma, $1998; trad.", "al $$1962 e"] {
            XCTAssertEqual(P(t), t, "«\(t)»: un apice o un anno, resta")
        }
        XCTAssertEqual(P("il $ 1922 del codice"), "il § 1922 del codice")
        // Come nella via GLM: prima il filtro della notazione, poi il segno di paragrafo.
        for grezzo in ["Milano, $^{3}$1998; trad.", "Milano, $^3$1977. Roma", "una nota.$^{169}$ 5. e poi"] {
            XCTAssertFalse(P(LetturaScansioni.filtraNotazione(grezzo)).contains("§"), "«\(grezzo)»: nessun «§» inventato")
        }
    }

    // MARK: i numeri di nota letti come asterisco

    /// Una pagina: due righe di corpo in alto (corpo 10), le righe di nota in basso (corpo 8).
    private func pagina(corpo: [String], note: [String]) -> (righe: [RigaLetta], corpi: [Double]) {
        var r: [RigaLetta] = [], c: [Double] = []
        for (k, t) in corpo.enumerated() { r.append(RigaLetta(testo: t, bbox: BBox(x: 50, y: 700 - Double(k) * 14, width: 300, height: 12), regione: 0)); c.append(10) }
        for (k, t) in note.enumerated() { r.append(RigaLetta(testo: t, bbox: BBox(x: 50, y: 200 - Double(k) * 11, width: 300, height: 9), regione: 1)); c.append(8) }
        return (r, c)
    }

    func test_numeriDiNota_dallaSequenzaDelleNote() {
        let p = pagina(corpo: ["un testo con un richiamo11 e un altro12", "e il terzo13 per chiudere"],
                       note: ["11 Prima nota di prova.", "* Seconda nota di prova.", "13 Terza nota di prova."])
        let r = LetturaScansioni.numeriDiNotaDagliAsterischi(p.righe, corpi: p.corpi, corpoTesto: 10)
        XCTAssertEqual(r.map(\.testo).suffix(3), ["11 Prima nota di prova.", "12 Seconda nota di prova.", "13 Terza nota di prova."])
    }

    func test_numeriDiNota_dallUnicoRichiamoSenzaNota() {
        let p = pagina(corpo: ["un testo con un richiamo4 soltanto", "e una riga senza richiami"], note: ["* Unica nota della pagina."])
        let r = LetturaScansioni.numeriDiNotaDagliAsterischi(p.righe, corpi: p.corpi, corpoTesto: 10)
        XCTAssertEqual(r.last?.testo, "4 Unica nota della pagina.")
    }

    /// Senza certezza la riga resta com'è, con l'asterisco: è il segno d'inizio della nota (toglierlo fonde la nota con quella sopra).
    func test_numeriDiNota_senzaCertezza_nessunNumero_maiInventato_lAsteriscoResta() {
        // Due asterischi senza sequenza che li fissi, nessun richiamo.
        let p = pagina(corpo: ["un testo senza richiami", "e un altro"], note: ["* Prima nota.", "* Seconda nota."])
        let r = LetturaScansioni.numeriDiNotaDagliAsterischi(p.righe, corpi: p.corpi, corpoTesto: 10)
        XCTAssertEqual(r.map(\.testo).suffix(2), ["* Prima nota.", "* Seconda nota."])
        // Due richiami senza nota e un asterisco: non si sceglie.
        let q = pagina(corpo: ["con due richiami7 e richiami9 nel testo", "fine"], note: ["* Una nota."])
        XCTAssertEqual(LetturaScansioni.numeriDiNotaDagliAsterischi(q.righe, corpi: q.corpi, corpoTesto: 10).last?.testo, "* Una nota.")
        // Il richiamo che contraddice la sequenza (la nota sopra è la 5, il richiamo il 9): nessun numero.
        let s = pagina(corpo: ["con un richiamo9 nel testo", "fine"], note: ["5 Nota cinque.", "* Nota dopo."])
        XCTAssertEqual(LetturaScansioni.numeriDiNotaDagliAsterischi(s.righe, corpi: s.corpi, corpoTesto: 10).last?.testo, "* Nota dopo.")
    }

    func test_numeriDiNota_asteriscoVeroNelTesto_resta() {
        let p = pagina(corpo: ["un titolo col segno*", "e il testo"], note: ["* La nota dell'asterisco."])
        let r = LetturaScansioni.numeriDiNotaDagliAsterischi(p.righe, corpi: p.corpi, corpoTesto: 10)
        XCTAssertEqual(r.last?.testo, "* La nota dell'asterisco.")
    }

    /// Con le migliorie spente le pagine estratte sono quelle di prima; accese, una pagina senza «$» né asterischi non cambia.
    func test_pagineEstratte_senzaSegniNonCambia_eSpenteComePrima() {
        let p = pagina(corpo: ["un testo qualunque di prova abbastanza lungo", "una seconda riga di corpo anch'essa lunga"], note: ["3 Una nota."])
        let letta = PaginaLetta(pagina: 0, larghezza: 420, altezza: 595, righe: p.righe, testoGlm: nil, secondiApple: 0, secondiGlm: 0,
                                secondiImpaginazione: 0, guardia: nil)
        XCTAssertEqual(LetturaScansioni.pagineEstratte([letta], migliorie: MiglioriScansioni()), LetturaScansioni.pagineEstratte([letta], migliorie: .spente))
        XCTAssertEqual(LetturaScansioni.pagineEstratte([letta]), LetturaScansioni.pagineEstratte([letta], migliorie: .spente))
    }
}
