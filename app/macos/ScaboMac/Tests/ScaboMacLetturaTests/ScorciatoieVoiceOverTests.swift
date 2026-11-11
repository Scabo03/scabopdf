//
//  ScorciatoieVoiceOverTests.swift
//  ScaboMacLetturaTests — le scorciatoie dell'app con VoiceOver acceso (giro «comandi da tastiera e VoiceOver sul Mac»,
//  2026-11-11, DISEGNO_LETTURA_MAC § 5.5), dentro il processo:
//  - le FRECCE con Comando, Opzione o Control non sono un passo di un elemento (prima ogni freccia lo era: ⌥⌘↓ caduto alla vista
//    spostava il fuoco di uno, in silenzio);
//  - il DIARIO dei tasti delle prove: solo codici, mai lettere digitate.
//  Il menu «Lettura» con qualunque primo risponditore e sull'elemento del cursore è in `LetturaMacTests`; i tasti veri in
//  `ScaboPDFUITests`. Contenuti sintetici: nessun testo dei volumi.
//
import AppKit
import ScaboCore
import XCTest
@testable import ScaboMacLettura

@MainActor
final class ScorciatoieVoiceOverTests: XCTestCase {

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

    /// Le frecce con un modificatore non sono passi: ⌥⌘↓ è «Intestazione successiva» del menu «Lettura». Se cade alla vista (il
    /// menu non l'ha presa) non sposta il fuoco di un elemento in silenzio. Prima della cura il fuoco andava avanti di uno.
    func test_frecceConModificatori_nonSonoUnPasso() {
        let v = libroConNote(3)
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 400), styleMask: [.titled], backing: .buffered, defer: false)
        w.contentView = v
        v.impostaFuocoIniziale(1)
        func freccia(_ codice: UInt16, _ m: NSEvent.ModifierFlags) -> NSEvent {
            // I caratteri veri delle frecce (NSDownArrowFunctionKey, NSUpArrowFunctionKey), come in un evento della tastiera.
            let c = String(UnicodeScalar(codice == 125 ? NSDownArrowFunctionKey : NSUpArrowFunctionKey)!)
            return NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: m.union([.numericPad, .function]), timestamp: 0,
                                    windowNumber: w.windowNumber, context: nil, characters: c, charactersIgnoringModifiers: c,
                                    isARepeat: false, keyCode: codice)!
        }
        for m: NSEvent.ModifierFlags in [[.command, .option], [.command], [.option], [.control]] {
            v.keyDown(with: freccia(125, m))
            XCTAssertEqual(v.fuoco, 1, "giù con \(m.rawValue): nessun passo")
            v.keyDown(with: freccia(126, m))
            XCTAssertEqual(v.fuoco, 1, "su con \(m.rawValue): nessun passo")
        }
        v.keyDown(with: freccia(125, []))
        XCTAssertEqual(v.fuoco, 2, "la freccia giù da sola resta il passo")
        v.keyDown(with: freccia(126, [.shift]))
        XCTAssertEqual(v.fuoco, 1, "con le sole maiuscole è ancora un passo, come prima")
    }

    /// Il diario dei tasti delle prove: codici, modificatori, finestra e app; mai le lettere digitate.
    func test_diarioDeiTasti_soloCodici_maiTestoDigitato() {
        XCTAssertEqual(Diario.descriviTasto(codice: 38, modificatori: [.command], finestra: "lettura.finestra", appAttiva: true),
                       "tasto:38:cmd:finestra=lettura.finestra:app-attiva=sì")
        XCTAssertEqual(Diario.descriviTasto(codice: 125, modificatori: [.command, .option, .numericPad, .function], finestra: nil, appAttiva: false),
                       "tasto:125:opzcmdfn:finestra=nessuna:app-attiva=no")
        XCTAssertNil(Diario.descriviTasto(codice: 38, modificatori: [], finestra: "lettura.finestra", appAttiva: true), "una lettera da sola: no")
        XCTAssertNil(Diario.descriviTasto(codice: 38, modificatori: [.shift], finestra: "lettura.finestra", appAttiva: true), "maiuscola: no")
        XCTAssertNotNil(Diario.descriviTasto(codice: 53, modificatori: [], finestra: nil, appAttiva: true), "Esc sì")
    }
}
