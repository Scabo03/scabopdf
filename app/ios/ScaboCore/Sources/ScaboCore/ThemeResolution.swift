//
//  ThemeResolution.swift
//  ScaboCore
//
//  The pure theme-selection → theme-id derivation. Faithful translation of the
//  `resolveThemeId` function and the `ThemeSelection` type from
//  `app/src/theme/ThemeProvider.tsx`.
//
//  CONFINE LOGICA / UI. The TS `ThemeProvider` is a React component: it holds the
//  selection in `useState`, reads/subscribes to the native accessibility settings
//  through `useEffect`, and memoises the resolved theme with `useMemo`. ALL of
//  that — the component, the hooks, the context, the live subscription wiring — is
//  banda POST-MAC (it depends on the concrete NativeAccessibilitySettings bridge
//  and on the UI runtime). What is pure and verifiable today is the derivation
//  `resolveThemeId(selection, systemScheme, systemHighContrast) -> ThemeId`, which
//  this file isolates. The post-Mac UI will call it with live inputs; here it is
//  exercised directly by XCTest with synthetic inputs (the same values the three
//  TS theme tests drive through the provider).
//

import Foundation

/// The user's theme choice: one of the three theme ids, or follow the OS scheme.
/// Mirrors the TS `ThemeSelection = ThemeId | 'system'`.
public enum ThemeSelection: String, CaseIterable, Equatable, Sendable {
    case dark
    case light
    case highContrast
    case system
}

/// The OS light/dark setting. Mirrors React Native's `useColorScheme()` return,
/// whose value is `'light' | 'dark' | null`; here `nil` is the null case (and,
/// like the TS, anything that is not `.light` resolves to the dark base).
public enum SystemColorScheme: String, Equatable, Sendable {
    case light
    case dark
}

/// App default theme *selection*. Mirrors the TS `initialSelection = DEFAULT_THEME_ID`
/// (`DEFAULT_THEME_ID` is a `ThemeId`, widened to a `ThemeSelection`).
public let DEFAULT_THEME_SELECTION: ThemeSelection = .dark

/// Resolves a selection to the concrete theme id to render.
///
/// - Explicit `light` / `highContrast` are honoured verbatim.
/// - `system` follows `systemScheme` (only `.light` yields light; `.dark`/`nil`
///   yield the dark base).
/// - When the resolved base is `dark` and the OS "Increase Contrast" flag is on,
///   it is auto-promoted to `highContrast`. The light theme is never auto-promoted
///   (no light high-contrast palette exists).
public func resolveThemeId(
    _ selection: ThemeSelection,
    _ systemScheme: SystemColorScheme?,
    _ systemHighContrast: Bool
) -> ThemeId {
    // Explicit non-dark choices are honored verbatim.
    if selection == .light { return .light }
    if selection == .highContrast { return .highContrast }

    // Here selection is .dark or .system.
    let baseId: ThemeId = (selection == .system)
        ? (systemScheme == .light ? .light : .dark)
        : .dark

    // Promote the regular dark theme to high contrast when the system flag is on.
    if baseId == .dark && systemHighContrast {
        return .highContrast
    }
    return baseId
}
