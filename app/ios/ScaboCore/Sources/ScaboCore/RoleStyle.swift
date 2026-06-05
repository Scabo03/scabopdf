//
//  RoleStyle.swift
//  ScaboCore
//
//  Role differentiation (Q2). Faithful translation of
//  `app/src/rendering/roleStyle.ts`.
//
//  A blind jurist must be able to tell, at least as well as on Normattiva,
//  whether what is being read is the article text, an amendment instruction, the
//  previgent (old) text, the new text, or an update note. That distinction is
//  carried acoustically through a spoken intro phrase prepended to the segment by
//  the native view; this module computes it so it is pure and testable against
//  the real Layer 1 baselines.
//
//  Visual differentiation (tinted blocks / indentation / a visible label) is the
//  native view's job (ScaboReadingContentView, banda POST-MAC) keyed off the same
//  `role` string; this module owns only the spoken dimension.
//

import Foundation

/// Roles framed as distinct blocks (Normattiva "box" style) on the native side.
public let BOXED_ROLES: Set<String> = [
    "AMENDMENT",
    "QUOTED_TEXT_OLD",
    "QUOTED_TEXT_NEW",
    "UPDATE_BLOCK",
]

/// Layer-2 presentation role for the synthetic HEADING_1 containers the XML AKN
/// backend mints (their text is a fixed editorial string, not document text).
/// They must not read as ordinary chapter headings — reclassifying them keeps
/// them out of any future Headings rotor and lets the native side render them as
/// a labelled section divider with a distinct spoken prefix.
public let SECTION_DIVIDER_ROLE = "SECTION_DIVIDER"

// The fixed titles Layer 1 mints for the synthetic containers (patterns bbbb /
// cccc / ffff). Anchored at the start; none of the thousands of real document
// headings in the baseline corpus begin with any of these, so the match is
// unambiguous. Recognition is text-only (no Layer 1 field exists for it).
//
// Translated verbatim from the TS RegExp literals, including the `\b` word
// boundary after "Aggiornamenti". NSRegularExpression is used rather than
// `hasPrefix` precisely to preserve that `\b` (so "Aggiornamentix" would NOT
// match), and rather than Swift's `Regex` literal because the deployment floor
// is iOS 15 / macOS 12 (Swift `Regex` requires iOS 16 / macOS 13).
private let syntheticContainerPatterns: [NSRegularExpression] = {
    [
        "^Decreto di promulgazione",
        "^Modificazioni attive",
        "^Modificazioni passive",
        "^Aggiornamenti\\b",
    ].map { try! NSRegularExpression(pattern: $0) }
}()

/// True for a HEADING_1 node whose text is one of the synthetic editorial
/// container titles minted by the XML AKN backend (e.g. "Modificazioni attive a
/// altri atti", "Decreto di promulgazione", "Aggiornamenti dell'atto").
public func isSyntheticContainer(_ role: String, _ text: String?) -> Bool {
    if role != "HEADING_1" {
        return false
    }
    let t = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    let range = NSRange(t.startIndex..<t.endIndex, in: t)
    return syntheticContainerPatterns.contains { $0.firstMatch(in: t, range: range) != nil }
}

/// The spoken intro VoiceOver reads before a segment's text, or "" when the role
/// needs no acoustic prefix (body/article prose, headings, list items — which are
/// differentiated typographically, not acoustically).
public func acousticIntroFor(_ role: String, _ lengthCategory: String) -> String {
    switch role {
    case "AMENDMENT":
        return "Modifica."
    case "QUOTED_TEXT_OLD":
        return "Testo previgente."
    case "QUOTED_TEXT_NEW":
        return "Nuovo testo."
    case "UPDATE_BLOCK":
        return "Aggiornamento."
    case SECTION_DIVIDER_ROLE:
        return "Sezione."
    case "EDITORIAL_NOTE":
        return "Nota editoriale."
    case "NOTE":
        if lengthCategory == "MEGA" {
            return "Nota molto lunga."
        }
        if lengthCategory == "VERY_LONG" || lengthCategory == "LONG" {
            return "Nota lunga."
        }
        return "Nota."
    default:
        return ""
    }
}
