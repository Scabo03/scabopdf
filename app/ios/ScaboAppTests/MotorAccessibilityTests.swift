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

    // MARK: - Selettore del layout mai troncato (giro «costruzione della linea Mac», 2026-10-16)

    /// La barra ospitata come nel lettore (in alto, larghezza piena, altezza MINIMA 44) e disposta.
    private func hostedBar(width: CGFloat, category: UIContentSizeCategory) -> ReadingInterfaceBar {
        let host = UIView(frame: CGRect(x: 0, y: 0, width: width, height: 600))
        let bar = ReadingInterfaceBar()
        bar.translatesAutoresizingMaskIntoConstraints = false
        if #available(iOS 17.0, *) { host.traitOverrides.preferredContentSizeCategory = category }
        host.addSubview(bar)
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: host.topAnchor),
            bar.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            bar.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
        ])
        bar.setTextSizeControls(available: true)
        bar.setBookmarksAvailable(true)
        bar.setPageIndicator(visualizationCurrent: 0, visualizationTotal: 0, originalCurrent: 412, originalTotal: 1559, showOriginal: true)
        let window = UIWindow(frame: host.frame)
        window.addSubview(host)
        window.isHidden = false
        for _ in 0..<3 { host.setNeedsLayout(); host.layoutIfNeeded() }
        return bar
    }

    /// «Lettura Continua» si leggeva «L…» sull'iPhone (al selettore restavano 0 punti) e, con il testo più grande, anche
    /// sull'iPad: ora la barra va su due righe quando serve e il titolo va a capo. Mai troncato, a ogni larghezza e
    /// dimensione del testo; sull'iPad 11 col testo normale la barra resta su una riga alta 44.
    func test_selettoreDelLayout_maiTroncato_aOgniLarghezzaEDimensioneDelTesto() throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("traitOverrides richiede iOS 17") }
        for width in [320.0, 375.0, 393.0, 440.0, 744.0, 834.0, 1024.0] {
            for category in [UIContentSizeCategory.large, .extraExtraExtraLarge, .accessibilityExtraExtraExtraLarge] {
                let bar = hostedBar(width: width, category: category)
                let title = try XCTUnwrap(bar.layoutSelectorButton.titleLabel)
                let label = "larghezza \(Int(width)), \(category.rawValue)"
                XCTAssertGreaterThan(title.bounds.width, 0, label)
                let needed = title.sizeThatFits(CGSize(width: title.bounds.width, height: .greatestFiniteMagnitude))
                XCTAssertLessThanOrEqual(needed.height, title.bounds.height + 1, "il titolo sta tutto: \(label)")
                XCTAssertEqual(title.text, "Lettura Continua", label)
                // Nessuna sovrapposizione fra il selettore, Indietro e i tasti.
                XCTAssertFalse(bar.layoutSelectorButton.frame.intersects(bar.backButton.frame), label)
                XCTAssertFalse(bar.layoutSelectorButton.frame.intersects(bar.decreaseTextSizeButton.convert(bar.decreaseTextSizeButton.bounds, to: bar)), label)
                XCTAssertGreaterThanOrEqual(bar.backButton.frame.height, 44, label)
                XCTAssertGreaterThanOrEqual(bar.backButton.frame.width + 0.5, bar.backButton.intrinsicContentSize.width, "Indietro mai compresso: \(label)")
            }
        }
        let pad = hostedBar(width: 834, category: .large)
        XCTAssertEqual(pad.rows, .one, "iPad 11, testo normale: una riga")
        XCTAssertEqual(pad.bounds.height, 44, accuracy: 0.5)
        let phone = hostedBar(width: 393, category: .large)
        XCTAssertEqual(phone.rows, .two, "iPhone, testo normale: due righe")
        XCTAssertEqual(phone.bounds.height, 88, accuracy: 0.5)
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
