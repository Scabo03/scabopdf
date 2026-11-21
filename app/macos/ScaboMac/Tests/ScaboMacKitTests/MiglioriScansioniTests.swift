//
//  MiglioriScansioniTests.swift
//  ScaboMacKitTests — le migliorie della via delle scansioni (giro «migliorie del banco nelle app», 2026-11-21): il filtro della
//  notazione di GLM (toglie i segni, mai il testo) e la protezione contro le righe ripetute. Testi di prova inventati.
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


}
}
