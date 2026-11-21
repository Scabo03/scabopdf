//
//  MiglioriScansioniTests.swift
//  ScaboMacKitTests — le migliorie della via delle scansioni (giro «migliorie del banco nelle app», 2026-11-21): il filtro della
//  notazione di GLM (toglie i segni, mai il testo), la protezione contro le righe ripetute, il segno di paragrafo (solo davanti a un
//  numero che non è un importo, o raddoppiato; mai sulla chiusura di un apice né attaccato a quattro cifre). Testi di prova inventati.
//
import Foundation
import ScaboCore
import XCTest
@testable import ScaboMacKit

final class MiglioriScansioniTests: XCTestCase {

    /// Le lettere e le cifre di un testo, senza i nomi dei comandi, le etichette HTML dell'elenco chiuso e le entità (ciò che il
    /// filtro può togliere); il testo fra parentesi angolari che non è un'etichetta resta e si conta.
    private func lettereECifre(_ s: String, sorgente: Bool) -> String {
        var t = s
        if sorgente {
            t = t.replacingOccurrences(of: #"\\[A-Za-z]+"#, with: " ", options: .regularExpression)
            t = t.replacingOccurrences(of: LetturaScansioni.etichetteHTML, with: " ", options: [.regularExpression, .caseInsensitive])
            t = t.replacingOccurrences(of: #"&[A-Za-z]{2,8};"#, with: " ", options: .regularExpression)
        }
        return String(t.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.map(Character.init).sorted())
    }

    // MARK: il filtro della notazione

    func test_filtro_toglieLaNotazione_tieneLeLettereELeCifre() {
        let glm = "Il termine$^{12}$ scade nel $1990^{2}$ e vale $\\rightarrow$ sempre **molto** <td>bene</td> &amp; | a | b | e $x$ a 20$^\\circ$ <si> fatto\n# Titolo di prova"
        let f = LetturaScansioni.filtraNotazione(glm)
        XCTAssertEqual(f, "Il termine$^{12}$ scade nel 1990$^{2}$ e vale → sempre molto bene & a b e x a 20° <si> fatto\nTitolo di prova")
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
        // L'apice già scritto dalla formula non si riavvolge una seconda volta («$$^{3}$$»: restava un dollaro davanti all'anno).
        XCTAssertEqual(LetturaScansioni.filtraNotazione("Milano, $^{3}$1998; trad."), "Milano, $^{3}$1998; trad.")
        XCTAssertEqual(LetturaScansioni.filtraNotazione("Milano, $^3$1977. Roma"), "Milano, $^{3}$1977. Roma")
    }

    /// Il testo fra parentesi angolari delle edizioni critiche resta; si tolgono solo le etichette HTML dell'elenco chiuso.
    func test_filtro_parentesiAngolari_restano_soloLeEtichetteSiTolgono() {
        for t in ["il testo <si> integrato", "una lacuna <...> qui", "la forma <è> resta", "un <a> solo"] {
            XCTAssertEqual(LetturaScansioni.filtraNotazione(t), t, "«\(t)»: testo, resta")
        }
        XCTAssertEqual(LetturaScansioni.filtraNotazione("<table><tr><td>uno</td><td colspan=\"2\">due</td></tr></table>"), " uno due ")
        XCTAssertEqual(LetturaScansioni.filtraNotazione("riga<br/>dopo"), "riga dopo")
    }

    func test_senzaRipetizioni_soloLaRigaRipetutaDiFila_unaVolta() {
        func riga(_ t: String) -> RigaLetta { RigaLetta(testo: t, bbox: BBox(x: 0, y: 0, width: 100, height: 10), regione: 0) }
        let L = "una riga di prova abbastanza lunga"
        let apple = [riga(L), riga("altra cosa qui")]
        let a = LetturaScansioni.senzaRipetizioni("\(L)\n\(L)\n\(L)\naltra cosa qui", righeApple: apple)
        XCTAssertEqual(a.tolte, 2, "GLM che si incanta: la riga di fila si dice una volta sola")
        XCTAssertEqual(a.testo, "\(L)\naltra cosa qui")
        let b = LetturaScansioni.senzaRipetizioni("\(L)\naltra cosa qui\n\(L)", righeApple: apple)
        XCTAssertEqual(b.tolte, 0, "ripetuta sparsa nella pagina (anche se Apple ne vede una sola copia uguale): resta")
        let c = LetturaScansioni.senzaRipetizioni("\(L)\n\(L)", righeApple: [riga(L), riga(L)])
        XCTAssertEqual(c.tolte, 0, "di fila anche per Apple: ripetuta davvero")
        XCTAssertEqual(LetturaScansioni.senzaRipetizioni("corta\ncorta", righeApple: []).tolte, 0, "le righe brevi non si toccano")
    }

    /// La via GLM dell'app (miglioria `glm`): ciò che solo Apple ha letto si toglie, come nella variante B; le righe d'uscita sono quelle
    /// di Apple col testo di GLM.
    func test_senzaGuardia_soloAppleSiToglie() {
        func riga(_ t: String, _ y: Double) -> RigaLetta { RigaLetta(testo: t, bbox: BBox(x: 0, y: y, width: 300, height: 10), regione: 0) }
        let righe = [riga("Titolo letto solo da Apple", 500), riga("il testo della pagina di prova", 480), riga("§ 12 e altro", 460)]
        let g = LetturaScansioni.senzaGuardia(righe: righe, testoGlm: "il testo della pagina di prova\n§ 12 e altro")
        XCTAssertEqual(g.righe.map(\.testo), ["il testo della pagina di prova", "§ 12 e altro"])
        XCTAssertEqual(g.righe.map(\.bbox.y), [480, 460], "la geometria resta quella delle righe di Apple")
        XCTAssertEqual(g.conti["tolte_apple"], 5)
    }

    // MARK: il segno di paragrafo

    func test_paragrafo_soloDavantiAUnNumero_oRaddoppiato() {
        let P = LetturaScansioni.segnoDiParagrafo
        XCTAssertEqual(P("come al $ 12 del capitolo"), "come al § 12 del capitolo")
        XCTAssertEqual(P("nei $$ 3-5 e al $ 4.2"), "nei §§ 3-5 e al § 4.2")
        XCTAssertEqual(P("nei $$12 e $$ 13"), "nei §§12 e §§ 13")
        XCTAssertEqual(P("(cfr. $ 7)"), "(cfr. § 7)")
        for t in ["costa US$ 100", "un importo di $ 1.000", "pari a $ 5,50 al mese", "100$ in tutto", "la parola$^{12}$", "il $x e il $", "il valore $5$"] {
            XCTAssertEqual(P(t), t, "«\(t)»: denaro o notazione, resta")
        }
        // L'edizione in apice davanti all'anno e il richiamo in apice: il «$» che chiude l'apice (GLM) e il dollaro singolo attaccato al
        // numero (Apple) non diventano «§»;
        // un «§» vero davanti a un numero di quattro cifre ha lo spazio, e resta convertito.
        for t in ["Milano, $^{3}$1998; trad.", "una nota.$^{169}$ 5. e poi", "Roma, $1998; trad.", "al $$1962 e", "la causa prima $8. Poi", "al $4.2 del testo"] {
            XCTAssertEqual(P(t), t, "«\(t)»: un apice o un anno, resta")
        }
        XCTAssertEqual(P("il $ 1922 del codice"), "il § 1922 del codice")
        // Come nella via GLM: prima il filtro della notazione, poi il segno di paragrafo.
        for grezzo in ["Milano, $^{3}$1998; trad.", "Milano, $^3$1977. Roma", "una nota.$^{169}$ 5. e poi"] {
            XCTAssertFalse(P(LetturaScansioni.filtraNotazione(grezzo)).contains("§"), "«\(grezzo)»: nessun «§» inventato")
        }
    }

    // MARK: una pagina di prova (righe di corpo e righe di nota)

    /// Una pagina: due righe di corpo in alto (corpo 10), le righe di nota in basso (corpo 8).
    private func pagina(corpo: [String], note: [String]) -> (righe: [RigaLetta], corpi: [Double]) {
        var r: [RigaLetta] = [], c: [Double] = []
        for (k, t) in corpo.enumerated() { r.append(RigaLetta(testo: t, bbox: BBox(x: 50, y: 700 - Double(k) * 14, width: 300, height: 12), regione: 0)); c.append(10) }
        for (k, t) in note.enumerated() { r.append(RigaLetta(testo: t, bbox: BBox(x: 50, y: 200 - Double(k) * 11, width: 300, height: 9), regione: 1)); c.append(8) }
        return (r, c)
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
