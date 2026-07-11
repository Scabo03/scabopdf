//
//  ReadingAppearance.swift
//  ScaboApp
//
//  Il ponte UI del sistema di accessibilità visiva: hex→`UIColor`, lettura dei trait
//  di sistema onesti (design § 3), applicazione della "Fonte dell'aspetto" alla
//  finestra (`overrideUserInterfaceStyle`), costruzione dello `ResolvedReadingStyle`
//  corrente. La logica pura (palette, resolver, preferenze) vive in ScaboCore; qui
//  c'è solo l'applicazione a UIKit.
//

import UIKit
import ScaboCore

extension UIColor {
    /// `UIColor` da un hex `#RRGGBB` (o `RRGGBB`). Ritorna `nil` su formato non valido.
    /// È l'unico ponte hex→colore dell'app (prima non esisteva: le palette dei
    /// `Tokens` non erano cablate).
    convenience init?(hex: String) {
        let s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(
            red: CGFloat((v >> 16) & 0xFF) / 255.0,
            green: CGFloat((v >> 8) & 0xFF) / 255.0,
            blue: CGFloat(v & 0xFF) / 255.0,
            alpha: 1.0)
    }

    /// Come sopra ma non-opzionale, con fallback a `.label` (per i punti di resa dove
    /// un hex della palette è garantito valido — verificato dai test WCAG).
    static func fromHex(_ hex: String, fallback: UIColor = .label) -> UIColor {
        UIColor(hex: hex) ?? fallback
    }
}

/// I trait di sistema che l'app PUÒ leggere (design § 3). Onestà: NON esiste API per
/// i filtri daltonismo; l'unico filtro rilevabile è la Scala di grigi.
func systemAppearanceTraits(for traitCollection: UITraitCollection) -> SystemAppearanceTraits {
    SystemAppearanceTraits(
        isDark: traitCollection.userInterfaceStyle == .dark,
        increaseContrast: UIAccessibility.isDarkerSystemColorsEnabled,
        differentiateWithoutColor: UIAccessibility.shouldDifferentiateWithoutColor,
        grayscale: UIAccessibility.isGrayscaleEnabled)
}

/// Le notifiche di cambio dei trait che il sistema di accessibilità visiva osserva
/// per ri-risolvere lo stile dal vivo (oltre a Dynamic Type, già osservato altrove).
let readingAppearanceTraitNotifications: [Notification.Name] = [
    UIAccessibility.darkerSystemColorsStatusDidChangeNotification,
    UIAccessibility.differentiateWithoutColorDidChangeNotification,
    UIAccessibility.grayscaleStatusDidChangeNotification,
]

enum ReadingAppearance {

    /// Costruisce lo stile di lettura risolto dai valori memorizzati + i trait di un
    /// `traitCollection` (tipicamente quello della reading view / finestra).
    static func style(prefs: KeyValueStore, traitCollection: UITraitCollection) -> ResolvedReadingStyle {
        resolvedReadingStyle(prefs, traits: systemAppearanceTraits(for: traitCollection))
    }

    /// Applica la "Fonte dell'aspetto" alla finestra (design § 2.1): in `followSystem`
    /// la finestra eredita il sistema (`.unspecified`); in `appTheme` si forza il
    /// chiaro/scuro base del tema scelto — l'UNICA cosa che la posizione B scavalca.
    /// I trait di accessibilità di sistema restano onorati sopra (design § 2.2).
    static func applyToWindow(_ window: UIWindow?, prefs: KeyValueStore) {
        guard let window else { return }
        switch getStoredAppearanceSource(prefs) {
        case .followSystem:
            window.overrideUserInterfaceStyle = .unspecified
        case .appTheme:
            let s = style(prefs: prefs, traitCollection: window.traitCollection)
            window.overrideUserInterfaceStyle = s.isDark ? .dark : .light
        }
    }
}
