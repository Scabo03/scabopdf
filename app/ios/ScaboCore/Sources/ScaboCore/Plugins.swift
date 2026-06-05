//
//  Plugins.swift
//  ScaboCore
//
//  The extraction-plugin protocol and the dispatcher. Faithful translation of
//  `app/src/plugins/types.ts` and `app/src/plugins/index.ts`.
//
//  Each plugin recognises a corpus and turns a raw `PdfExtraction` into the
//  reading `ScabopdfDocument` the rest of the app consumes — the PDF path and
//  the .scabopdf.json path converge on the same model. The dispatcher mirrors
//  Layer 1's profiling dispatcher: every registered plugin scores the extraction
//  with `matches()`, the highest scorer above the threshold wins, and the
//  corpus-agnostic Generic is the always-eligible fallback. This session
//  registers only Generic (the registry is empty; Generic is not in it).
//
//  The protocol is class-bound (`AnyObject`) so the dispatcher's identity — the
//  TS `selectPlugin(...) === genericPlugin` — translates to Swift `===`.
//

import Foundation

/// An on-device extraction plugin. Mirrors the Layer 1 `ProfilePlugin` role.
public protocol ExtractionPlugin: AnyObject {
    /// Stable identifier; mirrors a Layer 1 profile_id.
    var id: String { get }
    /// Human-facing Italian label, for diagnostics / warnings.
    var label: String { get }
    /// Confidence in [0, 1] that this plugin should own the extraction.
    func matches(_ extraction: PdfExtraction) -> Double
    /// Builds the reading Document from the extraction.
    func build(_ extraction: PdfExtraction, sourceName: String) -> ScabopdfDocument
}

/// Confidence a corpus plugin must clear to win over the Generic fallback.
public let DISPATCH_THRESHOLD = 0.6

/// Corpus-specific plugins, highest priority first. Generic is NOT here. Empty
/// this session (mirrors the TS `PLUGINS: readonly ExtractionPlugin[] = []`).
let registeredPlugins: [ExtractionPlugin] = []

/// Selects the plugin that should own the extraction.
public func selectPlugin(_ extraction: PdfExtraction) -> ExtractionPlugin {
    var winner: ExtractionPlugin = genericPlugin
    var best = -1.0
    for plugin in registeredPlugins {
        let score = plugin.matches(extraction)
        if score >= DISPATCH_THRESHOLD && score > best {
            best = score
            winner = plugin
        }
    }
    return winner
}

/// Builds the reading Document from a PDF extraction, choosing the plugin.
public func buildDocumentFromPdf(_ extraction: PdfExtraction, sourceName: String) -> ScabopdfDocument {
    selectPlugin(extraction).build(extraction, sourceName: sourceName)
}
