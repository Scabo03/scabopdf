//
//  DocumentValidation.swift
//  ScaboCore
//
//  Structural validation of a candidate document against the Layer 1 contract.
//
//  Translation note (legitimate language/library difference, documented rather
//  than silenced — Piano § 4 / golden rule). The TypeScript `validate.ts` runs
//  a full JSON-Schema Draft 2020-12 validator (`@cfworker/json-schema`) over the
//  untyped parsed JSON and returns the *complete* list of failures with JSON
//  Pointer locations. ScaboCore instead validates by *decoding* the JSON into
//  the strict `Codable` model in `SchemaTypes.swift`. The two agree on every
//  behaviour the Fase 1 oracles assert:
//
//    * a conforming document yields `[]` (decode succeeds);
//    * a missing required field yields at least one error carrying a
//      `location` and a `message` (decode throws `keyNotFound`);
//    * an out-of-vocabulary enum value yields at least one error (decode throws
//      `dataCorrupted` on the closed `SemanticCategory` enum).
//
//  They differ only on behaviour the oracles do NOT exercise, and the
//  difference is inherent to the approach:
//
//    * the decoder reports the FIRST structural error, not the exhaustive list
//      (Codable aborts at the first failure);
//    * `additionalProperties: false`, the `format: uuid` annotation, numeric
//      ranges (`confidence` 0…1) and string patterns (`^node_\d+$`) are NOT
//      re-enforced — Codable ignores unknown keys and does not range-check.
//
//  The exhaustive-list / pointer-format / extra-constraint behaviours are not
//  asserted by `consumption.test.ts`; reproducing them would require shipping a
//  second JSON-Schema engine in Swift, which is out of scope for Fase 1. If a
//  later phase needs full-schema validation (e.g. to reject extra properties),
//  it can add a bundled-schema validator without changing this surface.
//

import Foundation

/// A single, presentation-ready validation failure. Mirrors the TypeScript
/// `SchemaValidationError`: a location and a human-readable message.
public struct SchemaValidationError: Equatable, Sendable {
    /// Pointer-ish path to the offending location, e.g. `#/metadata/pages_pdf`.
    public let location: String
    /// Human-readable description of what failed.
    public let message: String

    public init(location: String, message: String) {
        self.location = location
        self.message = message
    }
}

/// The outcome of a decode-validation pass: the decoded document, or the
/// structural error(s). (A dedicated enum rather than `Result`, whose `Failure`
/// must be a single `Error` type, not an array of errors.)
enum DecodeOutcome {
    case valid(ScabopdfDocument)
    case invalid([SchemaValidationError])
}

/// Decodes `data` into the contract model, returning either the document or the
/// structural errors. Shared by `validateAgainstSchema` and `parseDocument` so
/// validation and loading agree by construction.
func decodeValidating(_ data: Data) -> DecodeOutcome {
    do {
        let document = try JSONDecoder().decode(ScabopdfDocument.self, from: data)
        return .valid(document)
    } catch let error as DecodingError {
        return .invalid([schemaError(from: error)])
    } catch {
        return .invalid([SchemaValidationError(location: "#", message: String(describing: error))])
    }
}

/// Validates raw JSON against the contract. Returns `[]` when the data conforms,
/// otherwise the structural failure(s). Never throws.
public func validateAgainstSchema(_ data: Data) -> [SchemaValidationError] {
    switch decodeValidating(data) {
    case .valid:
        return []
    case .invalid(let errors):
        return errors
    }
}

/// Convenience overload for a JSON string.
public func validateAgainstSchema(_ json: String) -> [SchemaValidationError] {
    guard let data = json.data(using: .utf8) else {
        return [SchemaValidationError(location: "#", message: "Il testo non è codificabile in UTF-8.")]
    }
    return validateAgainstSchema(data)
}

/// Maps a `DecodingError` to a presentation-ready `SchemaValidationError`,
/// deriving the location from the coding path so the first failure carries a
/// non-empty `location` and `message` (what the oracle asserts is present).
func schemaError(from error: DecodingError) -> SchemaValidationError {
    switch error {
    case .keyNotFound(let key, let context):
        let path = context.codingPath + [key]
        return SchemaValidationError(
            location: pointer(path),
            message: "Campo richiesto mancante: '\(key.stringValue)'."
        )
    case .typeMismatch(_, let context):
        return SchemaValidationError(
            location: pointer(context.codingPath),
            message: context.debugDescription
        )
    case .valueNotFound(_, let context):
        return SchemaValidationError(
            location: pointer(context.codingPath),
            message: context.debugDescription
        )
    case .dataCorrupted(let context):
        return SchemaValidationError(
            location: pointer(context.codingPath),
            message: context.debugDescription
        )
    @unknown default:
        return SchemaValidationError(location: "#", message: "Errore di validazione sconosciuto.")
    }
}

/// Builds a JSON-Pointer-like string from a coding path, e.g.
/// `#/structure/0/type`. Array indices use their integer value.
private func pointer(_ path: [CodingKey]) -> String {
    if path.isEmpty { return "#" }
    let parts = path.map { key -> String in
        if let index = key.intValue { return String(index) }
        return key.stringValue
    }
    return "#/" + parts.joined(separator: "/")
}
