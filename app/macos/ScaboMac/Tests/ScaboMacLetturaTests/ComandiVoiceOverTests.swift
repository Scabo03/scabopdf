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

    func test_elementiCollegati_sonoIBersagliDeiSalti_ilPrimoEQuelloDiComandoJ() throws {
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
        let nota = try XCTUnwrap(v.elemento(lontano).accessibilityLinkedUIElements()?.first as? ElementoLettura)
        XCTAssertTrue(nota === v.elemento(lontano + 1))
        nota.setAccessibilityFocused(true)   // come VoiceOver dopo il salto
        XCTAssertEqual(v.fuoco, lontano + 1)
        XCTAssertTrue(v.esposto(lontano + 1), "arrivato il fuoco, la finestra si sposta sul bersaglio")
        XCTAssertEqual((v.accessibilityFocusedUIElement as? ElementoLettura)?.indice, lontano + 1)
    }

    /// Un capoverso che richiama due note (rilievo R6 della revisione del giro): è collegato a tutte e due, nell'ordine; la prima è
    /// il bersaglio di ⌘J; ogni nota è collegata al capoverso.
    func test_elementiCollegati_dueNoteNelloStessoCapoverso() {
        let segmenti = [
            ContentSegment(id: "t", role: SemanticCategory.HEADING_2.rawValue, text: "Sezione di prova", lengthCategory: "", acousticIntro: ""),
            ContentSegment(id: "c", role: SemanticCategory.BODY.rawValue,
                           text: "Capoverso di prova che richiama una prima cosa 1 e poi una seconda cosa 2 nella stessa frase.", lengthCategory: "", acousticIntro: ""),
            ContentSegment(id: "n1", role: SemanticCategory.NOTE.rawValue, text: "1 Prima nota di prova.", lengthCategory: "SHORT", acousticIntro: "Nota."),
            ContentSegment(id: "n2", role: SemanticCategory.NOTE.rawValue, text: "2 Seconda nota di prova.", lengthCategory: "SHORT", acousticIntro: "Nota."),
            ContentSegment(id: "b", role: SemanticCategory.BODY.rawValue, text: "Un altro capoverso di prova.", lengthCategory: "", acousticIntro: ""),
        ]
        let v = VistaLettura(segmenti: segmenti, impostazioni: ReadingSpeechSettings())
        XCTAssertEqual(v.modello.noteJumpActions(forIndex: 1).compactMap(\.target), [2, 3], "precondizione: il modulo lega le due note")
        XCTAssertEqual((v.elemento(1).accessibilityLinkedUIElements() ?? []).compactMap { ($0 as? ElementoLettura)?.indice }, [2, 3])
        XCTAssertEqual(v.indiciCollegati(1).first, v.modello.noteCallJumpTarget(from: 1))
        XCTAssertEqual(v.indiciCollegati(2), [1])
        XCTAssertEqual(v.indiciCollegati(3), [1])
        XCTAssertTrue(v.indiciCollegati(4).isEmpty)
    }

    /// Una nota differita letta lontano dal suo richiamo, fuori dalla finestra dei figli (rilievo R6): il richiamo è collegato alla
    /// nota e la nota al richiamo; dato il fuoco al collegato lontano, come fa VoiceOver dopo VO+J, la finestra si sposta su di lui
    /// e la vista lo dice elemento col fuoco.
    func test_elementiCollegati_notaDifferitaLontana_fuoriDallaFinestra() throws {
        let frase = "Questa frase di prova richiama la nota numero undici"
        var segmenti = [
            ContentSegment(id: "t", role: SemanticCategory.HEADING_2.rawValue, text: "Sezione lunga di prova", lengthCategory: "", acousticIntro: ""),
            ContentSegment(id: "c", role: SemanticCategory.BODY.rawValue, text: "\(frase) 11 alla fine.", lengthCategory: "", acousticIntro: ""),
        ]
        for k in 0..<450 {
            segmenti.append(ContentSegment(id: "b\(k)", role: SemanticCategory.BODY.rawValue, text: "Capoverso di riempimento numero \(k).",
                                           lengthCategory: "", acousticIntro: ""))
        }
        segmenti.append(ContentSegment(id: "n", role: SemanticCategory.NOTE.rawValue, text: "11 Nota differita di prova, letta a fine sezione.",
                                       lengthCategory: "LONG", acousticIntro: "Nota lunga.", memoryRefresh: frase))
        let nota = segmenti.count - 1
        // Dopo la nota un'altra sezione: la nota non è l'ultimo elemento del libro, che i figli espongono sempre (VO+Fine).
        segmenti.append(ContentSegment(id: "t2", role: SemanticCategory.HEADING_2.rawValue, text: "Sezione seguente di prova", lengthCategory: "", acousticIntro: ""))
        for k in 0..<100 {
            segmenti.append(ContentSegment(id: "d\(k)", role: SemanticCategory.BODY.rawValue, text: "Capoverso seguente numero \(k).",
                                           lengthCategory: "", acousticIntro: ""))
        }
        let v = VistaLettura(segmenti: segmenti, impostazioni: ReadingSpeechSettings())
        XCTAssertTrue(v.finestrato)
        XCTAssertEqual(v.modello.noteCallJumpTarget(from: 1), nota, "precondizione: il modulo lega la nota differita al richiamo")
        v.impostaFuocoIniziale(1)
        _ = v.figliEsposti()
        XCTAssertFalse(v.esposto(nota), "la nota sta fuori dalla finestra dei figli")
        let collegata = try XCTUnwrap(v.elemento(1).accessibilityLinkedUIElements()?.first as? ElementoLettura)
        XCTAssertEqual(collegata.indice, nota)
        XCTAssertEqual(v.indiciCollegati(nota), [1])
        collegata.setAccessibilityFocused(true)   // come VoiceOver dopo VO+J
        XCTAssertEqual(v.fuoco, nota)
        XCTAssertTrue(v.esposto(nota), "arrivato il fuoco, la nota è fra i figli")
        XCTAssertEqual((v.accessibilityFocusedUIElement as? ElementoLettura)?.indice, nota)
        let ritorno = try XCTUnwrap(v.elemento(nota).accessibilityLinkedUIElements()?.first as? ElementoLettura)
        ritorno.setAccessibilityFocused(true)
        XCTAssertEqual(v.fuoco, 1, "e VO+J dalla nota riporta al richiamo")
    }
}
