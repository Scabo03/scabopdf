//
//  ComandiVoiceOverTests.swift
//  ScaboMacLetturaTests — i comandi standard di VoiceOver del Mac (giro «comandi da tastiera e VoiceOver sul Mac», 2026-11-11,
//  DISEGNO_LETTURA_MAC § 5.4), dentro il processo: gli ELEMENTI COLLEGATI (VO+J, «vai all'elemento collegato») sono i bersagli
//  dei salti nota ↔ richiamo del modulo, il primo è quello di ⌘J, anche quando il bersaglio è fuori dalla finestra dei figli;
//  senza legame nessun collegamento.
//  La prova da fuori, sull'app vera e come la fa VoiceOver, è in `FuocoDaFuoriTests`. Contenuti sintetici: nessun testo dei volumi.
//
import AppKit
import ScaboCore
import XCTest
@testable import ScaboMacLettura

@MainActor
final class ComandiVoiceOverTests: XCTestCase {

    /// Un libro lungo sintetico con note lette in linea: ogni dieci elementi un titolo, un capoverso che richiama la nota col suo
    /// numero, la nota, poi capoversi. Il legame nota ↔ richiamo lo trova il modulo (il numero della nota nel capoverso prima).
    private func libroConNote(_ sezioni: Int) -> VistaLettura {
        var segmenti: [ContentSegment] = []
        for k in 0..<sezioni {
            let n = k + 1
            segmenti.append(ContentSegment(id: "t\(k)", role: SemanticCategory.HEADING_2.rawValue, text: "Sezione di prova \(n)",
                                           lengthCategory: "", acousticIntro: ""))
            segmenti.append(ContentSegment(id: "c\(k)", role: SemanticCategory.BODY.rawValue,
                                           text: "Capoverso di prova con il richiamo \(n) in fondo alla frase.", lengthCategory: "", acousticIntro: ""))
            segmenti.append(ContentSegment(id: "n\(k)", role: SemanticCategory.NOTE.rawValue, text: "\(n) Nota di prova numero \(n).",
                                           lengthCategory: "SHORT", acousticIntro: "Nota."))
            for j in 0..<7 {
                segmenti.append(ContentSegment(id: "b\(k)_\(j)", role: SemanticCategory.BODY.rawValue,
                                               text: "Altro capoverso di prova \(j) della sezione \(n).", lengthCategory: "", acousticIntro: ""))
            }
        }
        return VistaLettura(segmenti: segmenti, impostazioni: ReadingSpeechSettings())
    }

    func test_elementiCollegati_sonoIBersagliDeiSalti_ilPrimoEQuelloDiComandoJ() {
        let v = libroConNote(60)   // 600 elementi: finestrato
        XCTAssertTrue(v.finestrato)
        var legati = 0
        for i in 0..<v.conteggio {
            let attesi = v.modello.noteJumpActions(forIndex: i).compactMap(\.target)
            XCTAssertEqual(v.indiciCollegati(i), attesi, "elemento \(i)")
            let dallElemento = (v.elemento(i).accessibilityLinkedUIElements() ?? []).compactMap { ($0 as? ElementoLettura)?.indice }
            XCTAssertEqual(dallElemento, attesi, "attributo dell'elemento \(i)")
            XCTAssertEqual(dallElemento.first, v.modello.noteCallJumpTarget(from: i), "il primo collegato è il bersaglio di ⌘J (\(i))")
            if !attesi.isEmpty { legati += 1 }
        }
        XCTAssertEqual(legati, 120, "sessanta note e sessanta richiami collegati")
        XCTAssertNil(v.elemento(0).accessibilityLinkedUIElements(), "il titolo non ha collegamenti")
        // Il bersaglio lontano, fuori dalla finestra dei figli, è lo stesso oggetto che la vista espone quando ci arriva.
        let lontano = 550 + 1
        XCTAssertFalse(v.esposto(lontano))
        let nota = try! XCTUnwrap(v.elemento(lontano).accessibilityLinkedUIElements()?.first as? ElementoLettura)
        XCTAssertTrue(nota === v.elemento(lontano + 1))
        nota.setAccessibilityFocused(true)   // come VoiceOver dopo il salto
        XCTAssertEqual(v.fuoco, lontano + 1)
        XCTAssertTrue(v.esposto(lontano + 1), "arrivato il fuoco, la finestra si sposta sul bersaglio")
        XCTAssertEqual((v.accessibilityFocusedUIElement as? ElementoLettura)?.indice, lontano + 1)
    }
}
