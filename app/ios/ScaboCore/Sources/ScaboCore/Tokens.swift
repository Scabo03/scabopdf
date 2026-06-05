//
//  Tokens.swift
//  ScaboCore
//
//  Design tokens for ScaboPDF (SPECS § A). Faithful translation of the data half
//  of `app/src/theme/tokens.ts`.
//
//  CONFINE LOGICA / UI. These are the token *values* and the token *data types* —
//  the surface the post-Mac UI consumes to style its components. NOTHING here
//  applies a style to a view: no `ThemeProvider` React component, no SwiftUI /
//  UIKit import. The reactive provider, the hooks and the on-screen application of
//  the palette are banda POST-MAC. The pure theme-derivation logic (resolving a
//  selection to a concrete theme id, incl. the auto high-contrast promotion) lives
//  in `ThemeResolution.swift`. ScaboCore imports only Foundation.
//
//  Three themes are offered (SPECS § A.6): dark high-contrast (default and
//  mandatory for the reading view, § A.2), light academic, and a higher-contrast
//  variant. Pure white (#FFFFFF) and yellow are categorically excluded (§ A.2).
//
//  `fontWeight` is kept as the verbatim CSS-style string ("400", "600", …) the TS
//  used (`TextStyle['fontWeight']`); mapping it to a platform font weight is the
//  post-Mac view's job. `fontSize` is `Double` (the TS `number`).
//

import Foundation

/// The three theme identifiers (SPECS § A.6).
public enum ThemeId: String, CaseIterable, Equatable, Sendable {
    case dark
    case light
    case highContrast
}

/// A palette's background colours.
public struct PaletteBackground: Equatable, Sendable {
    public var primary: String
    public var secondary: String
    public var tertiary: String
    public var border: String

    public init(primary: String, secondary: String, tertiary: String, border: String) {
        self.primary = primary
        self.secondary = secondary
        self.tertiary = tertiary
        self.border = border
    }
}

/// A palette's text colours.
public struct PaletteText: Equatable, Sendable {
    public var primary: String
    public var secondary: String
    public var disabled: String

    public init(primary: String, secondary: String, disabled: String) {
        self.primary = primary
        self.secondary = secondary
        self.disabled = disabled
    }
}

/// Accent roles (SPECS § A.2). Saturated and deep, never pastel.
public struct PaletteAccent: Equatable, Sendable {
    public var heading: String
    public var link: String
    public var warning: String
    public var procedural: String
    public var note: String

    public init(heading: String, link: String, warning: String, procedural: String, note: String) {
        self.heading = heading
        self.link = link
        self.warning = warning
        self.procedural = procedural
        self.note = note
    }
}

public struct Palette: Equatable, Sendable {
    public var background: PaletteBackground
    public var text: PaletteText
    public var accent: PaletteAccent

    public init(background: PaletteBackground, text: PaletteText, accent: PaletteAccent) {
        self.background = background
        self.text = text
        self.accent = accent
    }
}

public struct TypographyToken: Equatable, Sendable {
    public var fontSize: Double
    /// CSS-style weight string, verbatim from the TS ("400", "500", "600", "700").
    public var fontWeight: String

    public init(fontSize: Double, fontWeight: String) {
        self.fontSize = fontSize
        self.fontWeight = fontWeight
    }
}

public struct Typography: Equatable, Sendable {
    public var documentBody: TypographyToken
    public var documentHeading: TypographyToken
    public var articleNumber: TypographyToken
    public var note: TypographyToken
    public var uiLabel: TypographyToken
    public var screenTitle: TypographyToken

    public init(
        documentBody: TypographyToken,
        documentHeading: TypographyToken,
        articleNumber: TypographyToken,
        note: TypographyToken,
        uiLabel: TypographyToken,
        screenTitle: TypographyToken
    ) {
        self.documentBody = documentBody
        self.documentHeading = documentHeading
        self.articleNumber = articleNumber
        self.note = note
        self.uiLabel = uiLabel
        self.screenTitle = screenTitle
    }
}

public struct Theme: Equatable, Sendable {
    public var id: ThemeId
    public var isDark: Bool
    public var palette: Palette
    public var typography: Typography

    public init(id: ThemeId, isDark: Bool, palette: Palette, typography: Typography) {
        self.id = id
        self.isDark = isDark
        self.palette = palette
        self.typography = typography
    }
}

// SPECS § A.2 accent roles. Shared across themes (the light theme reuses the same
// accents "con contrasto verificato"). Verbatim from tokens.ts.
private let ACCENT = PaletteAccent(
    heading: "#1DB87A", // emerald — article/section headings
    link: "#1A7FE8", // electric blue — links, interactive controls
    warning: "#C0392B", // ruby — critical/significant notes
    procedural: "#B8922A", // antique gold — procedural blocks, keys
    note: "#4A8FA8" // steel blue — short note text
)

private let DARK_PALETTE = Palette(
    background: PaletteBackground(primary: "#0A0A0A", secondary: "#141414", tertiary: "#1E1E1E", border: "#2A2A2A"),
    text: PaletteText(primary: "#E0E0D8", secondary: "#8A8A82", disabled: "#4A4A44"),
    accent: ACCENT
)

private let LIGHT_PALETTE = Palette(
    background: PaletteBackground(primary: "#F5F2EB", secondary: "#ECE8DE", tertiary: "#E3DED2", border: "#D8D2C4"),
    text: PaletteText(primary: "#1A1A1A", secondary: "#5A5A52", disabled: "#9A9A90"),
    accent: ACCENT
)

// (derived) Higher-contrast variant of the dark theme, within SPECS § A.2
// (no pure white, no yellow).
private let HIGH_CONTRAST_PALETTE = Palette(
    background: PaletteBackground(primary: "#000000", secondary: "#0A0A0A", tertiary: "#141414", border: "#4A4A44"),
    text: PaletteText(primary: "#F2F2EC", secondary: "#C8C8C0", disabled: "#6A6A62"),
    accent: ACCENT
)

// SPECS § A.3. Sizes pick a value inside each SPECS range; weights verbatim.
private let TYPOGRAPHY = Typography(
    documentBody: TypographyToken(fontSize: 18, fontWeight: "400"),
    documentHeading: TypographyToken(fontSize: 24, fontWeight: "600"),
    articleNumber: TypographyToken(fontSize: 18, fontWeight: "700"),
    note: TypographyToken(fontSize: 15, fontWeight: "400"),
    uiLabel: TypographyToken(fontSize: 14, fontWeight: "500"),
    screenTitle: TypographyToken(fontSize: 22, fontWeight: "700")
)

/// The three themes, keyed by id (mirrors the TS `THEMES` record).
public let THEMES: [ThemeId: Theme] = [
    .dark: Theme(id: .dark, isDark: true, palette: DARK_PALETTE, typography: TYPOGRAPHY),
    .light: Theme(id: .light, isDark: false, palette: LIGHT_PALETTE, typography: TYPOGRAPHY),
    .highContrast: Theme(id: .highContrast, isDark: true, palette: HIGH_CONTRAST_PALETTE, typography: TYPOGRAPHY),
]

/// App default: dark, per SPECS § A.2 (mandatory for the reading view).
public let DEFAULT_THEME_ID: ThemeId = .dark
