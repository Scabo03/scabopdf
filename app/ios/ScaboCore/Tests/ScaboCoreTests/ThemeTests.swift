//
//  ThemeTests.swift
//  ScaboCoreTests
//
//  XCTest translation of the PURE half of the three TS theme test files:
//   * theme.test.tsx (127)        — THEMES token shape / no-pure-white / WCAG AA,
//                                    and the resolveThemeId-equivalent behaviours
//                                    the ThemeProvider tests drive.
//   * themeAutoHighContrast.test.tsx (53) — auto dark→highContrast promotion.
//   * themeLiveContrast.test.tsx (61)     — the runtime flip, reduced to its pure
//                                    resolution (dark→highContrast when the flag
//                                    turns on).
//
//  CONFINE LOGICA / UI. The React `ThemeProvider` component, the `useTheme` /
//  useThemeSelection hooks, the context, and the live accessibility-settings
//  subscription are banda POST-MAC (they need the UI runtime and the concrete
//  NativeAccessibilitySettings bridge). What is verifiable today is the token data
//  and the pure `resolveThemeId` derivation; those TS tests that only exercise the
//  React plumbing (e.g. "useTheme throws outside a provider") have no pure
//  equivalent and are intentionally not translated.
//
//  The WCAG luminance / contrast helpers below are ports of the pure math in
//  theme.test.tsx.
//

import XCTest
@testable import ScaboCore

final class ThemeTests: XCTestCase {

    // MARK: WCAG helpers (ported from theme.test.tsx)

    private func luminance(_ hex: String) -> Double {
        let c = hex.replacingOccurrences(of: "#", with: "")
        let scalars = Array(c)
        func channel(_ i: Int) -> Double {
            let hexPair = String(scalars[i]) + String(scalars[i + 1])
            let v = Double(UInt8(hexPair, radix: 16) ?? 0) / 255.0
            return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(0) + 0.7152 * channel(2) + 0.0722 * channel(4)
    }

    private func contrastRatio(_ a: String, _ b: String) -> Double {
        let la = luminance(a)
        let lb = luminance(b)
        let hi = Swift.max(la, lb)
        let lo = Swift.min(la, lb)
        return (hi + 0.05) / (lo + 0.05)
    }

    private func matchesHexColor(_ s: String) -> Bool {
        s.range(of: "^#[0-9A-Fa-f]{6}$", options: .regularExpression) != nil
    }

    // MARK: THEMES tokens

    /// TS: "%s theme exposes the full token shape".
    func test_tokens_fullShapePerTheme() {
        for id in ThemeId.allCases {
            let theme = THEMES[id]!
            XCTAssertEqual(theme.id, id)
            XCTAssertTrue(matchesHexColor(theme.palette.background.primary))
            XCTAssertTrue(matchesHexColor(theme.palette.text.primary))
            for accent in [theme.palette.accent.heading, theme.palette.accent.link,
                           theme.palette.accent.warning, theme.palette.accent.procedural,
                           theme.palette.accent.note] {
                XCTAssertTrue(matchesHexColor(accent))
            }
            XCTAssertGreaterThan(theme.typography.documentBody.fontSize, 0)
        }
    }

    /// TS: "never uses pure white (SPECS § A.2)".
    func test_tokens_neverPureWhite() {
        for id in ThemeId.allCases {
            let p = THEMES[id]!.palette
            XCTAssertNotEqual(p.text.primary.uppercased(), "#FFFFFF")
            XCTAssertNotEqual(p.background.primary.uppercased(), "#FFFFFF")
        }
    }

    /// TS: "body text on primary background meets WCAG AA (4.5:1)".
    func test_tokens_bodyTextMeetsWCAGAA() {
        for id in ThemeId.allCases {
            let p = THEMES[id]!.palette
            XCTAssertGreaterThanOrEqual(contrastRatio(p.text.primary, p.background.primary), 4.5)
        }
    }

    // MARK: resolveThemeId — the ThemeProvider behaviours, pure

    /// TS theme.test.tsx: "defaults to the dark theme (SPECS § A.2)".
    func test_resolve_defaultsToDark() {
        XCTAssertEqual(resolveThemeId(DEFAULT_THEME_SELECTION, nil, false), .dark)
    }

    /// TS theme.test.tsx: "honors an explicit initial selection" (highContrast).
    func test_resolve_honorsExplicitHighContrast() {
        XCTAssertEqual(resolveThemeId(.highContrast, nil, false), .highContrast)
    }

    /// TS theme.test.tsx: "switches theme when the selection changes" — the
    /// state switch is UI plumbing; the pure resolution of the new selection.
    func test_resolve_explicitLight() {
        XCTAssertEqual(resolveThemeId(.light, nil, false), .light)
    }

    /// TS themeAutoHighContrast.test.tsx: "promotes the dark default to
    /// highContrast when Increase Contrast is on".
    func test_resolve_autoPromotesDarkToHighContrast() {
        XCTAssertEqual(resolveThemeId(.dark, nil, true), .highContrast)
    }

    /// TS themeAutoHighContrast.test.tsx: "honors an explicit light selection
    /// regardless of Increase Contrast".
    func test_resolve_lightNeverPromoted() {
        XCTAssertEqual(resolveThemeId(.light, nil, true), .light)
    }

    /// TS themeAutoHighContrast.test.tsx: "honors an explicit highContrast selection".
    func test_resolve_explicitHighContrastWithFlag() {
        XCTAssertEqual(resolveThemeId(.highContrast, nil, true), .highContrast)
    }

    /// TS themeLiveContrast.test.tsx: the runtime flip, reduced to its pure
    /// resolution (dark resolves to dark when the flag is off, to highContrast
    /// when it turns on). The subscription/live-update mechanism is POST-MAC.
    func test_resolve_liveFlipIsPureResolution() {
        XCTAssertEqual(resolveThemeId(.dark, nil, false), .dark)
        XCTAssertEqual(resolveThemeId(.dark, nil, true), .highContrast)
    }

    /// system selection follows the OS scheme; only .light yields light, and the
    /// dark base is promoted under the contrast flag (light is never promoted).
    func test_resolve_systemSelection() {
        XCTAssertEqual(resolveThemeId(.system, .light, false), .light)
        XCTAssertEqual(resolveThemeId(.system, .dark, false), .dark)
        XCTAssertEqual(resolveThemeId(.system, nil, false), .dark)
        XCTAssertEqual(resolveThemeId(.system, .dark, true), .highContrast)
        XCTAssertEqual(resolveThemeId(.system, .light, true), .light)
    }
}
