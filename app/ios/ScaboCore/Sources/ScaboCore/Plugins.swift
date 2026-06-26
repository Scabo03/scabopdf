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

    /// Progress- and cancellation-aware build (ADDITIVO, sessione import).
    ///
    /// Reports real per-page progress while the document is built — `onPageClassified(done, total)`
    /// fires once per page actually processed, `done` monotòno crescente da 1 a `total` — e
    /// onora una cancellazione COOPERATIVA: se `isCancelled()` diventa vero a una tappa naturale
    /// (prima di una pagina), il build si interrompe pulito e ritorna `nil`, senza produrre un
    /// documento parziale. La firma è un REQUISITO del protocollo (non solo un metodo d'extension)
    /// così il dispatch è dinamico e il plugin concreto può sovrascriverlo; l'implementazione di
    /// default in extension delega a `build(_:sourceName:)` ignorando il progresso, onorando la
    /// cancellazione solo ai bordi. Additivo: i conformanti esistenti non si rompono (la default
    /// soddisfa il requisito).
    func build(
        _ extraction: PdfExtraction,
        sourceName: String,
        onPageClassified: (_ done: Int, _ total: Int) -> Void,
        isCancelled: () -> Bool
    ) -> ScabopdfDocument?
}

public extension ExtractionPlugin {
    /// Default: ignora il progresso, delega al build sincrono, onora la cancellazione ai bordi.
    func build(
        _ extraction: PdfExtraction,
        sourceName: String,
        onPageClassified: (_ done: Int, _ total: Int) -> Void,
        isCancelled: () -> Bool
    ) -> ScabopdfDocument? {
        if isCancelled() { return nil }
        let document = build(extraction, sourceName: sourceName)
        return isCancelled() ? nil : document
    }
}

/// Confidence a corpus plugin must clear to win over the Generic fallback.
public let DISPATCH_THRESHOLD = 0.6

/// Corpus-specific plugins, highest priority first. Generic is NOT here. Each
/// must clear `DISPATCH_THRESHOLD` on its own corpus and stay below it on every
/// other (the cross-volume non-regression gate). `raffaelloCortinaPlugin`
/// recognises the Cortina "Saggi" trim and promotes its small-caps section
/// sub-titles to HEADING_4 (note-placement boundary); it is gated so tightly on
/// the 453×694 trim that no other corpus volume reaches the threshold — the
/// Generic stays untouched for everything else.
let registeredPlugins: [ExtractionPlugin] = [raffaelloCortinaPlugin, userNotesPlugin]

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

/// Progress- and cancellation-aware variant (ADDITIVO, sessione import). Sceglie il plugin e ne
/// invoca il build con reporting di progresso per-pagina e cancellazione cooperativa; ritorna
/// `nil` se la cancellazione scatta prima del completamento (nessun documento parziale).
public func buildDocumentFromPdf(
    _ extraction: PdfExtraction,
    sourceName: String,
    onPageClassified: (_ done: Int, _ total: Int) -> Void,
    isCancelled: () -> Bool
) -> ScabopdfDocument? {
    selectPlugin(extraction).build(
        extraction,
        sourceName: sourceName,
        onPageClassified: onPageClassified,
        isCancelled: isCancelled
    )
}
