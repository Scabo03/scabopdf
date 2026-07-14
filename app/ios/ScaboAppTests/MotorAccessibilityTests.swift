//
//  MotorAccessibilityTests.swift
//  ScaboAppTests
//
//  Verifiche OGGETTIVE del giro «aree scoperte» (motorio/uditivo): senza un utente
//  reale, ogni funzione è agganciata a una prova. Comandi da tastiera (catalogo),
//  dimensione dei bersagli, opzioni note (etichetta parlata + box), Riduci movimento.
//

import XCTest
import UIKit
@testable import ScaboApp
import ScaboCore

final class MotorAccessibilityTests: XCTestCase {

    // MARK: - Comandi da tastiera (WCAG 2.1.1)

    func test_keyboardCatalog_isCompleteAndDescribed() {
        let cmds = KeyboardCommandsCatalog.reading
        XCTAssertEqual(cmds.count, 9, "i comandi di lettura previsti")
        // Ogni comando ha titolo, descrizione e tasti resi in glifi e a parole (per VoiceOver).
        for c in cmds {
            XCTAssertFalse(c.title.isEmpty)
            XCTAssertFalse(c.description.isEmpty, "descrizione scopribile per «\(c.title)»")
            XCTAssertFalse(c.displayKeys.isEmpty)
            XCTAssertFalse(c.spokenKeys.isEmpty)
            XCTAssertFalse(c.id.isEmpty)
        }
        // Gli id sono univoci (mappano 1:1 ai selettori del reading view controller).
        XCTAssertEqual(Set(cmds.map(\.id)).count, cmds.count)
        // Verifica puntuale di un paio: segnalibro = ⌘B, strumenti = ⌘E.
        let bookmark = cmds.first { $0.id == "bookmark" }
        XCTAssertEqual(bookmark?.input, "b")
        XCTAssertTrue(bookmark?.modifiers.contains(.command) ?? false)
        XCTAssertEqual(bookmark?.displayKeys, "⌘ B")
        let back = cmds.first { $0.id == "back" }
        XCTAssertEqual(back?.displayKeys, "Esc")
        XCTAssertEqual(back?.spokenKeys, "tasto Esc")
    }

    // MARK: - Bersagli di tocco ≥ 44pt (WCAG 2.5.8 [2.2] / HIG)

    func test_interfaceBarButtons_meetMinimumTouchTarget() {
        let bar = ReadingInterfaceBar()
        bar.setTextSizeControls(available: true)
        bar.frame = CGRect(x: 0, y: 0, width: 390, height: 44)
        bar.layoutIfNeeded()
        // Pulsanti a icona: ≥ 44×44.
        for b in [bar.decreaseTextSizeButton, bar.increaseTextSizeButton] {
            XCTAssertGreaterThanOrEqual(b.frame.width, 44, "larghezza del bersaglio")
            XCTAssertGreaterThanOrEqual(b.frame.height, 44, "altezza del bersaglio")
        }
        // Il pulsante Indietro (testo) riempie l'altezza della barra.
        XCTAssertGreaterThanOrEqual(bar.backButton.frame.height, 44)
    }

    // MARK: - Opzione «note annunciate a voce» (mai-solo-suono, WCAG 1.4.1/1.3.3 per analogia)

    private func noteSegment() -> ContentSegment {
        ContentSegment(id: "n1", role: "NOTE", text: "Testo della nota", lengthCategory: "SHORT",
                       acousticIntro: "Nota.")
    }

    func test_noteLabel_stripsIntroByDefault_restoresWhenOptionOn() {
        let seg = noteSegment()
        let stripped = ContinuousReadingView.intendedAccessibilityLabel(for: seg, restoreNoteIntro: false)
        XCTAssertFalse(stripped.contains("Nota."), "di default l'intro è portata dall'earcon, non dal parlato")
        let restored = ContinuousReadingView.intendedAccessibilityLabel(for: seg, restoreNoteIntro: true)
        XCTAssertTrue(restored.contains("Nota."), "con l'opzione, l'identità della nota torna nel testo")
    }

    // MARK: - Opzione «riquadro visivo per le note»

    func test_noteVisualBox_showsBarOnlyWhenOptionOn() {
        let seg = noteSegment()
        let bar = UIView(); let content = UIView(); let label = UILabel()
        let traits = SystemAppearanceTraits(isDark: true)

        let styleOff = resolveReadingStyle(source: .appTheme, preset: .standard, spacing: .standard,
            accent: .standard, readingGuide: false, noteVisualBox: false, traits: traits)
        ContinuousReadingView.applyRoleBoxAndGuide(bar: bar, contentView: content, textLabel: label,
            segment: seg, style: styleOff, isReadingFocus: false)
        XCTAssertTrue(bar.isHidden, "senza l'opzione, la nota NON ha box")

        let styleOn = resolveReadingStyle(source: .appTheme, preset: .standard, spacing: .standard,
            accent: .standard, readingGuide: false, noteVisualBox: true, traits: traits)
        ContinuousReadingView.applyRoleBoxAndGuide(bar: bar, contentView: content, textLabel: label,
            segment: seg, style: styleOn, isReadingFocus: false)
        XCTAssertFalse(bar.isHidden, "con l'opzione, la nota ha il box visivo")
    }

    // MARK: - Riduci movimento (WCAG 2.3.3 / HIG)

    func test_motion_respectsReduceMotion() {
        XCTAssertTrue(Motion.animated(true, reduceMotion: false), "animato normalmente")
        XCTAssertFalse(Motion.animated(true, reduceMotion: true), "Riduci movimento → nessuna animazione")
        XCTAssertFalse(Motion.animated(false, reduceMotion: false))
    }
}
