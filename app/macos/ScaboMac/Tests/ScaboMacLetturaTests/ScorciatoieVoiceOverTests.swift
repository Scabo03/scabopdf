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
    /// menu non l'ha presa) non sposta il fuoco di un elemento in silenzio. Prima della cura il fuoco andava avanti di uno. Ogni
    /// freccia si prova da sola, dallo stesso elemento, e la vista sta nella sua vista a scorrimento come nella finestra di lettura:
    /// la freccia con un modificatore prosegue lungo la catena vera dei risponditori (rilievo R9 della revisione del giro).
    func test_frecceConModificatori_nonSonoUnPasso() throws {
        let v = libroConNote(40)
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 400), styleMask: [.titled], backing: .buffered, defer: false)
        let scorrimento = NSScrollView()
        scorrimento.documentView = v
        scorrimento.hasVerticalScroller = true
        w.contentView = scorrimento
        v.frame.size.width = scorrimento.contentSize.width
        XCTAssertTrue(w.makeFirstResponder(v))
        func freccia(_ codice: UInt16, _ m: NSEvent.ModifierFlags) throws -> NSEvent {
            // I caratteri veri delle frecce (NSDownArrowFunctionKey, NSUpArrowFunctionKey), come in un evento della tastiera.
            let c = String(try XCTUnwrap(UnicodeScalar(codice == 125 ? NSDownArrowFunctionKey : NSUpArrowFunctionKey)))
            return try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: m.union([.numericPad, .function]),
                                                  timestamp: 0, windowNumber: w.windowNumber, context: nil, characters: c,
                                                  charactersIgnoringModifiers: c, isARepeat: false, keyCode: codice))
        }
        let partenza = 100
        for m: NSEvent.ModifierFlags in [[.command, .option], [.command], [.option], [.control], [.control, .option]] {
            for codice: UInt16 in [125, 126] {
                v.impostaFuocoIniziale(partenza)
                v.keyDown(with: try freccia(codice, m))
                XCTAssertEqual(v.fuoco, partenza, "\(codice == 125 ? "giù" : "su") con i modificatori \(m.rawValue): nessun passo")
            }
        }
        v.impostaFuocoIniziale(partenza)
        v.keyDown(with: try freccia(125, []))
        XCTAssertEqual(v.fuoco, partenza + 1, "la freccia giù da sola resta il passo")
        v.impostaFuocoIniziale(partenza)
        v.keyDown(with: try freccia(126, [.shift]))
        XCTAssertEqual(v.fuoco, partenza - 1, "con le sole maiuscole è ancora un passo, come prima")
    }

    /// ⌃⌘↓ e ⌃⌘↑ (giro «titoli di VoiceOver: le varianti», 2026-11-12): le scorciatoie alternative dei titoli le prende la vista
    /// di lettura prima del menu; ⌥⌘↓ resta del menu (la vista non la prende), e le altre combinazioni con le frecce non fanno nulla.
    func test_scorciatoieAlternativeDeiTitoli_controlComando() throws {
        let v = VistaLettura(segmenti: (0..<12).map { i in
            ContentSegment(id: "s\(i)", role: i % 4 == 0 ? SemanticCategory.HEADING_1.rawValue : SemanticCategory.BODY.rawValue,
                           text: "Elemento di prova \(i).", lengthCategory: "", acousticIntro: "")
        }, impostazioni: ReadingSpeechSettings())
        func evento(_ codice: UInt16, _ m: NSEvent.ModifierFlags) throws -> NSEvent {
            let c = String(UnicodeScalar(codice == 125 ? NSDownArrowFunctionKey : NSUpArrowFunctionKey)!)
            return try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: m.union([.numericPad, .function]),
                                                  timestamp: 0, windowNumber: 0, context: nil, characters: c,
                                                  charactersIgnoringModifiers: c, isARepeat: false, keyCode: codice))
        }
        v.impostaFuocoIniziale(0)
        XCTAssertTrue(v.performKeyEquivalent(with: try evento(125, [.command, .control])))
        XCTAssertEqual(v.fuoco, 4, "⌃⌘↓: il titolo seguente")
        XCTAssertTrue(v.performKeyEquivalent(with: try evento(125, [.command, .control])))
        XCTAssertEqual(v.fuoco, 8)
        XCTAssertTrue(v.performKeyEquivalent(with: try evento(126, [.command, .control])))
        XCTAssertEqual(v.fuoco, 4, "⌃⌘↑: il titolo precedente")
        for m: NSEvent.ModifierFlags in [[.command, .option], [.command], [.control], [.command, .control, .shift], [.control, .option, .command]] {
            XCTAssertFalse(v.performKeyEquivalent(with: try evento(125, m)), "con i modificatori \(m.rawValue) la vista non la prende")
            XCTAssertEqual(v.fuoco, 4)
        }
    }

    /// Il diario dei tasti delle prove: codici, modificatori, finestra e app; mai il testo digitato. Un tasto di carattere conta
    /// solo con Comando o Control: con la sola Opzione sul Mac scrive un segno (rilievo R11 della revisione del giro).
    func test_diarioDeiTasti_soloCodici_maiTestoDigitato() {
        XCTAssertEqual(Diario.descriviTasto(codice: 38, modificatori: [.command], finestra: "lettura.finestra", appAttiva: true),
                       "tasto:38:cmd:lati=-:finestra=lettura.finestra:app-attiva=sì")
        XCTAssertEqual(Diario.descriviTasto(codice: 125, modificatori: [.command, .option, .numericPad, .function], finestra: nil, appAttiva: false),
                       "tasto:125:opzcmdfn:lati=-:finestra=nessuna:app-attiva=no")
        XCTAssertEqual(Diario.descriviTasto(codice: 38, modificatori: [.control, .option, .command], finestra: nil, appAttiva: true),
                       "tasto:38:ctrlopzcmd:lati=-:finestra=nessuna:app-attiva=sì", "col tasto VO tenuto, se il tasto arriva")
        XCTAssertNil(Diario.descriviTasto(codice: 38, modificatori: [], finestra: "lettura.finestra", appAttiva: true), "una lettera da sola: no")
        XCTAssertNil(Diario.descriviTasto(codice: 38, modificatori: [.shift], finestra: "lettura.finestra", appAttiva: true), "maiuscola: no")
        XCTAssertNil(Diario.descriviTasto(codice: 38, modificatori: [.option], finestra: "lettura.finestra", appAttiva: true), "Opzione e lettera: no")
        XCTAssertNil(Diario.descriviTasto(codice: 18, modificatori: [.option, .shift], finestra: nil, appAttiva: true), "Opzione, maiuscole e cifra: no")
        XCTAssertNotNil(Diario.descriviTasto(codice: 125, modificatori: [.option], finestra: nil, appAttiva: true), "Opzione e freccia: sì")
        XCTAssertNotNil(Diario.descriviTasto(codice: 53, modificatori: [], finestra: nil, appAttiva: true), "Esc sì")
        XCTAssertEqual(Diario.descriviModificatori([.control, .option, .command], finestra: "lettura.finestra", appAttiva: true),
                       "modificatori:ctrlopzcmd:lati=-:finestra=lettura.finestra:app-attiva=sì")
        XCTAssertEqual(Diario.descriviModificatori([], finestra: nil, appAttiva: false), "modificatori:-:lati=-:finestra=nessuna:app-attiva=no")
        // Il lato dei modificatori dai bit dei singoli tasti (IOLLEvent.h): Opzione e Comando di destra, Control di sinistra.
        let destra = NSEvent.ModifierFlags(rawValue: NSEvent.ModifierFlags([.option, .command]).rawValue | 0x40 | 0x10)
        XCTAssertEqual(Diario.descriviModificatori(destra, finestra: nil, appAttiva: true), "modificatori:opzcmd:lati=opz-dx+cmd-dx:finestra=nessuna:app-attiva=sì")
        let sinistra = NSEvent.ModifierFlags(rawValue: NSEvent.ModifierFlags([.control, .command]).rawValue | 0x01 | 0x08)
        XCTAssertEqual(Diario.descriviTasto(codice: 125, modificatori: sinistra, finestra: nil, appAttiva: true), "tasto:125:ctrlcmd:lati=ctrl-sx+cmd-sx:finestra=nessuna:app-attiva=sì")
        XCTAssertEqual(Diario.lati(NSEvent.ModifierFlags(rawValue: 0x2000 | 0x20 | 0x04)), "ctrl-dx+opz-sx+maiusc-dx")
    }
}
