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

/// Storage keys, verbatim from the TS.
public enum PreferenceKeys {
    public static let themeSelection = "@scabopdf/theme/selection"
    public static let layoutId = "@scabopdf/reading/layout"
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
