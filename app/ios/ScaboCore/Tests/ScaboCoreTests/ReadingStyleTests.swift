//
//  ReadingStyleTests.swift
//  ScaboCoreTests
//
//  Il sistema di accessibilità visiva della lettura: conformità WCAG dei colori
//  (SC 1.4.3 / 1.4.6 / 1.4.11), la precedenza del resolver (design § 2.2), e il
//  round-trip delle nuove preferenze. Tutto puro, senza UI.
//

import XCTest
@testable import ScaboCore

final class ReadingStyleTests: XCTestCase {

    // MARK: - Conformità WCAG dei colori (la passata di conformità del design § 7)

    /// Ogni palette base: testo primario sopra la soglia, e OGNI accento ≥ 4.5:1 sul
    /// proprio sfondo (soglia testo, più severa della 3:1 per elementi grandi).
    private func assertPalette(
        _ c: ReadingColors, textMin: Double, file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertGreaterThanOrEqual(
            WCAGContrast.ratio(c.textPrimary, c.background), textMin,
            "testo primario sotto soglia", file: file, line: line)
        for (name, accent) in [
            ("heading", c.accentHeading), ("link", c.accentLink), ("warning", c.accentWarning),
            ("procedural", c.accentProcedural), ("note", c.accentNote),
        ] {
            XCTAssertGreaterThanOrEqual(
                WCAGContrast.ratio(accent, c.background), 4.5,
                "accento \(name) (\(accent)) sotto 4.5:1 su \(c.background)", file: file, line: line)
        }
        // SPECS § A.2: mai bianco puro né sfondo bianco puro.
        XCTAssertNotEqual(c.background.uppercased(), "#FFFFFF")
        XCTAssertNotEqual(c.textPrimary.uppercased(), "#FFFFFF")
    }

    func test_wcag_darkStandard() { assertPalette(ReadingPalettes.darkStandard(), textMin: 4.5) }
    func test_wcag_highContrast_AAA() { assertPalette(ReadingPalettes.highContrast(), textMin: 7.0) }
    func test_wcag_crema() { assertPalette(ReadingPalettes.crema(reinforced: false), textMin: 4.5) }
    func test_wcag_cremaReinforced_AAA() { assertPalette(ReadingPalettes.crema(reinforced: true), textMin: 7.0) }
    func test_wcag_calma() { assertPalette(ReadingPalettes.calma(), textMin: 4.5) }

    /// La collisione rosso-verde corretta (design § 3.1): heading (teal) e warning
    /// (vermiglio) si distinguono per TINTA e — sulle famiglie scure, dove è
    /// fisicamente possibile — anche per LUMINANZA (sopravvivono alla scala di grigi).
    /// Nota onesta: sullo sfondo CHIARO (crema) i due accenti devono entrambi stare
    /// nella stretta banda scura richiesta dai 4,5:1, quindi la separazione di
    /// luminanza è limitata: lì è la TINTA (+ «mai-solo-colore») a portare il segnale,
    /// e la Scala di grigi collassa comunque gli accenti sul testo (test dedicato).
    func test_headingVsWarning_luminanceSeparatedOnDarkFamilies() {
        for c in [ReadingPalettes.darkStandard(), ReadingPalettes.highContrast(), ReadingPalettes.calma()] {
            XCTAssertGreaterThanOrEqual(
                WCAGContrast.ratio(c.accentHeading, c.accentWarning), 1.25,
                "heading e warning troppo vicini in luminanza (\(c.accentHeading) vs \(c.accentWarning))")
        }
    }

    func test_wcagContrast_knownValues() {
        // Nero/bianco ≈ 21:1; identici = 1:1.
        XCTAssertEqual(WCAGContrast.ratio("#000000", "#FFFFFF"), 21, accuracy: 0.1)
        XCTAssertEqual(WCAGContrast.ratio("#123456", "#123456"), 1, accuracy: 0.001)
    }

    // MARK: - Precedenza del resolver (design § 2.2)

    private let dark = SystemAppearanceTraits(isDark: true)
    private let light = SystemAppearanceTraits(isDark: false)

    func test_followSystem_darkPicksDarkPalette() {
        let s = resolveReadingStyle(source: .followSystem, preset: .standard, spacing: .standard,
                                    accent: .standard, readingGuide: false, traits: dark)
        XCTAssertEqual(s.colors.background, "#0A0A0A")
        XCTAssertTrue(s.isDark)
    }

    func test_followSystem_lightPicksCrema() {
        let s = resolveReadingStyle(source: .followSystem, preset: .standard, spacing: .standard,
                                    accent: .standard, readingGuide: false, traits: light)
        XCTAssertEqual(s.colors.background, "#F5F2EB")
        XCTAssertFalse(s.isDark)
    }

    /// Aumenta contrasto onorato in posizione A: scuro → rinforzato (nero).
    func test_followSystem_darkPlusIncreaseContrast_reinforces() {
        let t = SystemAppearanceTraits(isDark: true, increaseContrast: true)
        let s = resolveReadingStyle(source: .followSystem, preset: .standard, spacing: .standard,
                                    accent: .standard, readingGuide: false, traits: t)
        XCTAssertEqual(s.colors.background, "#000000")
    }

    /// Comfort → crema, chiaro.
    func test_appTheme_comfort_isCrema() {
        let s = resolveReadingStyle(source: .appTheme, preset: .comfort, spacing: .comfortable,
                                    accent: .standard, readingGuide: false, traits: dark)
        XCTAssertEqual(s.colors.background, "#F5F2EB")
        XCTAssertFalse(s.isDark)
        XCTAssertEqual(s.maxContentWidth, 640)  // riga cappata (design § 4.3)
        XCTAssertEqual(s.differentiation, .sober)
    }

    /// PUNTO FERMO (design § 2.3): Comfort + Aumenta contrasto = sfondo crema
    /// MANTENUTO, testo al massimo contrasto sulla crema.
    func test_appTheme_comfortPlusIncreaseContrast_keepsCremaMaxesText() {
        let t = SystemAppearanceTraits(isDark: false, increaseContrast: true)
        let s = resolveReadingStyle(source: .appTheme, preset: .comfort, spacing: .comfortable,
                                    accent: .standard, readingGuide: false, traits: t)
        XCTAssertEqual(s.colors.background, "#F5F2EB", "lo sfondo crema si mantiene")
        XCTAssertEqual(s.colors.textPrimary, "#000000", "il testo va al massimo contrasto")
    }

    func test_appTheme_ipovisione_isMaxContrast() {
        let s = resolveReadingStyle(source: .appTheme, preset: .ipovisione, spacing: .comfortable,
                                    accent: .standard, readingGuide: false, traits: light)
        XCTAssertEqual(s.colors.background, "#000000")
        XCTAssertEqual(s.differentiation, .strong)
    }

    func test_appTheme_calma_isCalmaPaletteMuted() {
        let s = resolveReadingStyle(source: .appTheme, preset: .calma, spacing: .standard,
                                    accent: .standard, readingGuide: false, traits: dark)
        XCTAssertEqual(s.colors.background, "#121210")
        XCTAssertTrue(s.mutedAccents)
        XCTAssertEqual(s.differentiation, .sober)
    }

    /// Scala di grigi di sistema → accenti collassati sul testo (nessuna dipendenza
    /// dal colore).
    func test_grayscale_collapsesAccentsToText() {
        let t = SystemAppearanceTraits(isDark: true, grayscale: true)
        let s = resolveReadingStyle(source: .appTheme, preset: .standard, spacing: .standard,
                                    accent: .standard, readingGuide: false, traits: t)
        XCTAssertEqual(s.colors.accentHeading, s.colors.textPrimary)
        XCTAssertEqual(s.colors.accentWarning, s.colors.textPrimary)
    }

    func test_monochromeAccent_collapsesToText() {
        let s = resolveReadingStyle(source: .appTheme, preset: .standard, spacing: .standard,
                                    accent: .monochrome, readingGuide: false, traits: dark)
        XCTAssertEqual(s.colors.accentLink, s.colors.textPrimary)
    }

    /// Differentiate Without Color rafforza un preset sobrio.
    func test_differentiateWithoutColor_bumpsSoberToFull() {
        let t = SystemAppearanceTraits(isDark: false, differentiateWithoutColor: true)
        let s = resolveReadingStyle(source: .appTheme, preset: .comfort, spacing: .comfortable,
                                    accent: .standard, readingGuide: false, traits: t)
        XCTAssertEqual(s.differentiation, .full)
    }

    func test_spacingProfile_appliesValues() {
        let s = resolveReadingStyle(source: .appTheme, preset: .comfort, spacing: .comfortable,
                                    accent: .standard, readingGuide: false, traits: dark)
        XCTAssertEqual(s.lineHeightMultiple, 1.5, accuracy: 0.001)  // BDA
        XCTAssertGreaterThan(s.wordSpacingEm, s.letterSpacingEm * 3)  // BDA: parole ≥3,5× lettere
    }

    func test_showRoleBoxes_alwaysTrue() {
        // Il box è un segnale di correttezza «mai-solo-colore», mai spento.
        for preset in ReadingPreset.allCases {
            let s = resolveReadingStyle(source: .appTheme, preset: preset, spacing: .standard,
                                        accent: .standard, readingGuide: false, traits: dark)
            XCTAssertTrue(s.showRoleBoxes)
        }
    }

    // MARK: - Preferenze (round-trip + default + applyReadingPreset)

    func test_prefs_defaults() {
        let store = InMemoryKeyValueStore()
        XCTAssertEqual(getStoredAppearanceSource(store), .followSystem)
        XCTAssertEqual(getStoredReadingPreset(store), .standard)
        XCTAssertEqual(getStoredSpacingProfile(store), .standard)
        XCTAssertEqual(getStoredAccentMode(store), .standard)
        XCTAssertFalse(getStoredReadingGuide(store))
        XCTAssertFalse(getStoredFirstOpenCompleted(store))
    }

    func test_prefs_roundTrip() {
        let store = InMemoryKeyValueStore()
        setStoredAppearanceSource(store, .appTheme)
        setStoredReadingPreset(store, .ipovisione)
        setStoredSpacingProfile(store, .generous)
        setStoredAccentMode(store, .monochrome)
        setStoredReadingGuide(store, true)
        setStoredFirstOpenCompleted(store, true)
        XCTAssertEqual(getStoredAppearanceSource(store), .appTheme)
        XCTAssertEqual(getStoredReadingPreset(store), .ipovisione)
        XCTAssertEqual(getStoredSpacingProfile(store), .generous)
        XCTAssertEqual(getStoredAccentMode(store), .monochrome)
        XCTAssertTrue(getStoredReadingGuide(store))
        XCTAssertTrue(getStoredFirstOpenCompleted(store))
    }

    func test_prefs_invalidValueCollapsesToDefault() {
        let store = InMemoryKeyValueStore([PreferenceKeys.readingPreset: "bogus"])
        XCTAssertEqual(getStoredReadingPreset(store), .standard)
    }

    /// Applicare un preset scrive appTheme + preset + spaziatura di partenza; Calma
    /// accende la guida di lettura.
    func test_applyReadingPreset_writesBundle() {
        let store = InMemoryKeyValueStore()
        applyReadingPreset(store, .comfort)
        XCTAssertEqual(getStoredAppearanceSource(store), .appTheme)
        XCTAssertEqual(getStoredReadingPreset(store), .comfort)
        XCTAssertEqual(getStoredSpacingProfile(store), .comfortable)
        XCTAssertFalse(getStoredReadingGuide(store))

        applyReadingPreset(store, .calma)
        XCTAssertEqual(getStoredReadingPreset(store), .calma)
        XCTAssertTrue(getStoredReadingGuide(store), "Calma suggerisce la guida di lettura")
    }

    func test_resolvedReadingStyle_fromStore() {
        let store = InMemoryKeyValueStore()
        applyReadingPreset(store, .ipovisione)
        let s = resolvedReadingStyle(store, traits: SystemAppearanceTraits(isDark: false))
        XCTAssertEqual(s.colors.background, "#000000")
        XCTAssertEqual(s.differentiation, .strong)
    }
}
