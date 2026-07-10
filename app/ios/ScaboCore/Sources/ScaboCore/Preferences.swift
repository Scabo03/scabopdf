//
//  Preferences.swift
//  ScaboCore
//
//  Persistent app-preferences LOGIC (theme selection + reading layout). Faithful
//  translation of `app/src/storage/preferences.ts`.
//
//  CONFINE LOGICA / PERSISTENZA. The TS reads/writes `@react-native-async-storage`
//  directly. Here the concrete persistence is abstracted behind `KeyValueStore`,
//  so the *logic* — the keys, the defaults, the validation of a stored value
//  against the closed vocabulary, the round-trip — is verifiable in memory today.
//  The real system-backed store (`UserDefaults`, the plan's replacement for
//  AsyncStorage) is a banda-successiva (POST-MAC) implementation of this same
//  protocol; it is intentionally absent here. `InMemoryKeyValueStore` is the
//  non-system implementation the logic and the tests run against.
//
//  Language difference (documented). The TS getters/setters are `async`
//  (AsyncStorage is promise-based) and the getters wrap the read in try/catch,
//  falling through to the default on any failure. The behaviour under test is the
//  default-and-validate logic, which is synchronous; the `KeyValueStore` boundary
//  is therefore synchronous and a missing/unknown value collapses to the default
//  exactly as the TS does. A concrete async store (UserDefaults is itself sync; a
//  future file/iCloud store could be async) is free to adapt at its own layer —
//  that is precisely what the boundary buys. A store that fails to read MUST
//  return `nil` (never throw), preserving "the getter never throws".
//

import Foundation

/// The minimal key/value persistence boundary the preferences logic depends on.
/// Mirrors the slice of AsyncStorage the TS uses (`getItem` / `setItem`).
public protocol KeyValueStore: AnyObject {
    /// Returns the stored string for `key`, or `nil` when absent or unreadable.
    func getItem(_ key: String) -> String?
    /// Stores `value` for `key`.
    func setItem(_ key: String, _ value: String)
}

/// An in-memory `KeyValueStore` — the non-system implementation used by the logic
/// and the tests. The concrete `UserDefaults`-backed store is banda POST-MAC.
public final class InMemoryKeyValueStore: KeyValueStore {
    private var storage: [String: String]

    public init(_ initial: [String: String] = [:]) {
        self.storage = initial
    }

    public func getItem(_ key: String) -> String? {
        storage[key]
    }

    public func setItem(_ key: String, _ value: String) {
        storage[key] = value
    }

    /// Mirrors `AsyncStorage.clear()` used by the TS test `beforeEach`.
    public func clear() {
        storage.removeAll()
    }
}

/// A `UserDefaults`-backed `KeyValueStore` — the real, system persistence for app preferences.
/// `UserDefaults` is Foundation-only (no UIKit), synchronous, and never throws on read, so it
/// satisfies the boundary contract exactly: a missing value returns `nil`. This is the concrete
/// store the app injects; the in-memory store stays for tests.
public final class UserDefaultsKeyValueStore: KeyValueStore {
    private let defaults: UserDefaults
    public init(_ defaults: UserDefaults = .standard) { self.defaults = defaults }
    public func getItem(_ key: String) -> String? { defaults.string(forKey: key) }
    public func setItem(_ key: String, _ value: String) { defaults.set(value, forKey: key) }
}

/// Storage keys, verbatim from the TS.
public enum PreferenceKeys {
    public static let themeSelection = "@scabopdf/theme/selection"
    public static let layoutId = "@scabopdf/reading/layout"
    /// Livello di granularità di lettura GLOBALE di default (§ 7.7).
    public static let granularityLevel = "@scabopdf/reading/granularity"
    /// Prefisso della chiave PER-DOCUMENTO della granularità (§ 7.7, additivo).
    /// La chiave effettiva è `granularityLevelPrefix + documentId`.
    public static let granularityLevelPrefix = "@scabopdf/reading/granularity/"

    /// Toggle globale "Mostra numero pagine file originale" (§ 4.2).
    public static let showOriginalPageNumbers = "@scabopdf/reading/showOriginalPages"

    /// Offset GLOBALE della dimensione del testo di lettura (Fase 0 accessibilità visiva): passi sulla
    /// scala Dynamic Type a partire dalla dimensione di sistema (0 = come il sistema, >0 più grande).
    public static let readingTextSizeOffset = "@scabopdf/reading/textSizeOffset"

    /// Chiave per-documento della granularità, derivata dall'id del documento.
    public static func documentGranularityLevel(_ documentId: String) -> String {
        granularityLevelPrefix + documentId
    }
}

// MARK: - Toggle pagine del file originale (§ 4.2)

/// Legge il toggle globale "Mostra numero pagine file originale" (§ 4.2). Default `false`
/// (disattivato): finché l'utente non lo chiede, l'app mostra solo la pagina di visualizzazione.
public func getStoredShowOriginalPageNumbers(_ store: KeyValueStore) -> Bool {
    store.getItem(PreferenceKeys.showOriginalPageNumbers) == "1"
}

public func setStoredShowOriginalPageNumbers(_ store: KeyValueStore, _ enabled: Bool) {
    store.setItem(PreferenceKeys.showOriginalPageNumbers, enabled ? "1" : "0")
}

// MARK: - Dimensione del testo di lettura (Fase 0 accessibilità visiva)

/// Limiti di sicurezza dell'offset globale della dimensione del testo (validazione dello store; il
/// clamp fine alla scala Dynamic Type avviene nella reading view, che conosce la scala delle
/// `UIContentSizeCategory`).
public let READING_TEXT_SIZE_OFFSET_MIN = -11
public let READING_TEXT_SIZE_OFFSET_MAX = 11

/// Legge l'offset globale della dimensione del testo, validato e clampato. Un valore mancante o non
/// numerico collassa a 0 (come il sistema), esattamente come gli altri default preferenze.
public func getStoredReadingTextSizeOffset(_ store: KeyValueStore) -> Int {
    guard let raw = store.getItem(PreferenceKeys.readingTextSizeOffset), let value = Int(raw) else {
        return 0
    }
    return min(max(READING_TEXT_SIZE_OFFSET_MIN, value), READING_TEXT_SIZE_OFFSET_MAX)
}

public func setStoredReadingTextSizeOffset(_ store: KeyValueStore, _ offset: Int) {
    let clamped = min(max(READING_TEXT_SIZE_OFFSET_MIN, offset), READING_TEXT_SIZE_OFFSET_MAX)
    store.setItem(PreferenceKeys.readingTextSizeOffset, String(clamped))
}

/// Reads the stored theme selection, validating it against the closed vocabulary.
/// A missing or unknown value yields `DEFAULT_THEME_SELECTION` (dark), exactly as
/// the TS returns `DEFAULT_THEME_ID`. (Validation is `ThemeSelection(rawValue:)`,
/// the Swift analog of the TS `VALID_THEME_SELECTIONS` set membership.)
public func getStoredThemeSelection(_ store: KeyValueStore) -> ThemeSelection {
    if let raw = store.getItem(PreferenceKeys.themeSelection),
       let selection = ThemeSelection(rawValue: raw) {
        return selection
    }
    return DEFAULT_THEME_SELECTION
}

public func setStoredThemeSelection(_ store: KeyValueStore, _ selection: ThemeSelection) {
    store.setItem(PreferenceKeys.themeSelection, selection.rawValue)
}

/// Reads the stored layout id, validating it against the closed vocabulary. A
/// missing or unknown value yields `.continuous`, the TS default.
public func getStoredLayoutId(_ store: KeyValueStore) -> LayoutId {
    if let raw = store.getItem(PreferenceKeys.layoutId),
       let layout = LayoutId(rawValue: raw) {
        return layout
    }
    return .continuous
}

public func setStoredLayoutId(_ store: KeyValueStore, _ layout: LayoutId) {
    store.setItem(PreferenceKeys.layoutId, layout.rawValue)
}

// MARK: - Granularità di lettura (§ 7.7) — default globale + override per-documento

/// Legge il livello di granularità GLOBALE, validandolo contro il vocabolario
/// chiuso `GranularityLevel`. Un valore mancante o fuori vocabolario collassa a
/// `DEFAULT_GRANULARITY_LEVEL` (fine/400), esattamente come tema e layout.
public func getStoredGranularityLevel(_ store: KeyValueStore) -> GranularityLevel {
    if let raw = store.getItem(PreferenceKeys.granularityLevel),
       let level = GranularityLevel(rawValue: raw) {
        return level
    }
    return DEFAULT_GRANULARITY_LEVEL
}

public func setStoredGranularityLevel(_ store: KeyValueStore, _ level: GranularityLevel) {
    store.setItem(PreferenceKeys.granularityLevel, level.rawValue)
}

/// Livello di granularità EFFETTIVO per un documento: l'override per-documento se
/// presente e valido (§ 7.7), altrimenti il default globale. Risoluzione a due
/// livelli che non spezza chi non ha mai scelto: documento → globale → default.
public func getDocumentGranularityLevel(_ store: KeyValueStore, documentId: String) -> GranularityLevel {
    if let raw = store.getItem(PreferenceKeys.documentGranularityLevel(documentId)),
       let level = GranularityLevel(rawValue: raw) {
        return level
    }
    return getStoredGranularityLevel(store)
}

public func setDocumentGranularityLevel(
    _ store: KeyValueStore, documentId: String, _ level: GranularityLevel
) {
    store.setItem(PreferenceKeys.documentGranularityLevel(documentId), level.rawValue)
}
