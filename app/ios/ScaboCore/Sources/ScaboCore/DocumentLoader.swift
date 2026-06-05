//
//  DocumentLoader.swift
//  ScaboCore
//
//  Loading and validating a ScaboPDF document (the Layer 1 → Layer 2 JSON).
//  Faithful translation of `app/src/consumption/document.ts`.
//
//  `parseDocument` is the single entry point that turns a file's contents into
//  a validated, typed document. It never throws; every failure is returned as a
//  `DocumentLoadError` carrying an accessible, user-facing Italian message (UI
//  language is Italian in phase 1, SPECS § 0). The Italian message strings are
//  copied verbatim from the TypeScript so VoiceOver reads the same wording.
//
//  Input-shape note (language difference, documented). The TypeScript
//  `parseDocument` accepts either a raw JSON string or an already-parsed object
//  (`string | unknown`); the object branch is a JavaScript convenience that has
//  no typed equivalent in Swift. Here the entry points are a `String` and a
//  `Data` (raw JSON bytes). The `consumption.test.ts` case that passes an object
//  is reproduced by encoding the equivalent value to `Data` and parsing that —
//  the behaviour under test (a conforming document parses and surfaces its
//  warnings) is identical.
//

import Foundation

/// The single contract version this build of the app understands.
public let SUPPORTED_SCHEMA_VERSION = "0.7.0"

/// A typed, accessible load failure. Mirrors the TypeScript `DocumentLoadError`
/// discriminated union.
public enum DocumentLoadError: Error, Equatable, Sendable {
    case invalidJSON(message: String)
    case unsupportedVersion(message: String, foundVersion: String)
    case schemaValidation(message: String, errors: [SchemaValidationError])
}

/// The result of a load attempt. Mirrors the TypeScript `DocumentLoadResult`.
public enum DocumentLoadResult: Sendable {
    case success(document: ScabopdfDocument, warnings: [String])
    case failure(DocumentLoadError)

    /// Convenience for call sites that only branch on success.
    public var isOk: Bool {
        if case .success = self { return true }
        return false
    }
}

/// Parses and validates a document from its raw JSON text.
public func parseDocument(_ jsonText: String) -> DocumentLoadResult {
    guard let data = jsonText.data(using: .utf8) else {
        return .failure(.invalidJSON(message: invalidJSONMessage))
    }
    return parseDocument(data)
}

/// Parses and validates a document from its raw JSON bytes.
public func parseDocument(_ data: Data) -> DocumentLoadResult {
    // Parse once to detect non-JSON input and to peek the schema version
    // before full validation, exactly like the TypeScript: a document from a
    // different schema version gets a clear message instead of a generic
    // "const" mismatch buried in validation errors.
    let parsed: Any
    do {
        parsed = try JSONSerialization.jsonObject(with: data)
    } catch {
        return .failure(.invalidJSON(message: invalidJSONMessage))
    }

    if let foundVersion = peekSchemaVersion(parsed),
       foundVersion != SUPPORTED_SCHEMA_VERSION {
        let message = "Questo documento usa la versione di formato \(foundVersion), "
            + "diversa da quella supportata dall'app (\(SUPPORTED_SCHEMA_VERSION)). "
            + "Aggiorna l'app oppure rigenera il documento."
        return .failure(.unsupportedVersion(message: message, foundVersion: foundVersion))
    }

    switch decodeValidating(data) {
    case .invalid(let errors):
        return .failure(.schemaValidation(
            message: "Il file non rispetta il formato previsto per un documento ScaboPDF.",
            errors: errors
        ))
    case .valid(let document):
        return .success(document: document, warnings: document.warnings)
    }
}

/// Reads the top-level `schema_version` string from already-parsed JSON, or
/// `nil` when absent or non-string (mirrors `peekSchemaVersion` in the TS).
private func peekSchemaVersion(_ parsed: Any) -> String? {
    guard let object = parsed as? [String: Any] else { return nil }
    return object["schema_version"] as? String
}

private let invalidJSONMessage =
    "Il file non è un documento ScaboPDF valido: non contiene dati JSON leggibili."
