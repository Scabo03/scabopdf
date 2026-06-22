//
//  BuildSegments.swift
//  ScaboCore
//
//  Layout-agnostic base traversal. Faithful translation of
//  `app/src/rendering/buildSegments.ts`.
//
//  Walks the document tree in reading order and emits one `ContentSegment` per
//  node that carries text. Synthetic nodes without text (EMPTY_PAGE, anchor-only
//  nodes) are skipped. NOTE segments preserve `length_category` for the
//  acoustic-regime hook.
//
//  Read-once model (Q1). The Layer 1 AKN topology nests modification nodes whose
//  text is a verbatim substring of their parent: ARTICLE_BODY ⊃ AMENDMENT ⊃
//  QUOTED_TEXT_NEW/OLD. Emitting every text-bearing node naively would read the
//  same legislative text two or three times in a row. Instead, a node's own text
//  is emitted only for the spans its children do NOT already reproduce, and the
//  children are recursed at their position inside the parent text — so every
//  character is voiced exactly once, at the most specific role that covers it.
//  Children whose text is not a contiguous substring of the parent (UPDATE_BLOCK
//  under a synthetic container, EPUB commi, plain prose) are disjoint content and
//  are emitted in full after the parent.
//
//  Like the TS, the walk uses an explicit work-list (not recursion) so a deeply
//  nested but schema-valid document cannot overflow the call stack on the render
//  path. (`expand` itself is non-recursive: it returns the work items a node
//  expands into.)
//
//  Language difference — string indexing (documented per Piano § 4). The TS
//  `text.indexOf(childText)` / `slice` / `length` operate on UTF-16 code units.
//  Here the placement uses opaque `String.Index` values into the *same* string —
//  found with `range(of:options:.literal)`, sliced with `text[start..<end]` — so
//  no integer-unit conversion happens and the resulting substrings are the same
//  characters regardless of UTF-16-vs-grapheme counting. `.literal` mirrors JS
//  indexOf's code-unit-literal (non-canonical) matching: child texts are real
//  slices of the parent carved by Layer 1, so the first-occurrence match agrees
//  with `indexOf`. Trimming uses `.whitespacesAndNewlines` (JS `.trim()`); the
//  only divergence is exotic trim characters such as U+FEFF, which cannot occur
//  at a gap-slice boundary in this corpus.
//

import Foundation

private enum Work {
    case segment(ContentSegment)
    case node(NodeDict)
}

/// Ruoli ESCLUSI dal flusso di lettura (presenti nel documento, ma non vocalizzati).
/// Scartati dalla voce come la furniture, ma CONSERVATI nell'albero (reversibile:
/// un domani potranno servire alla navigazione). Le note vere restano lette/piazzate;
/// il CONTENUTO del front-matter (prefazione/introduzione, prosa) NON è qui dentro.
///  • `MARGINAL_GLOSS` — glosse laterali, ridondanti (docs/GLOSSE_LATERALI.md).
///  • `TOC_GENERAL` — indice/sommario del volume (front- o back-matter): navigazione.
///  • `ARTIFACT_STAMP` — colophon/frontespizio/pagina legale: dati editoriali.
///  • `INDEX_ENTRY` — indice dei nomi/fonti/sentenze in coda (back-matter): apparato
///    di consultazione (docs/BACK_MATTER.md). L'indice ANALITICO recintato NON è qui:
///    non è classificato INDEX_ENTRY dal Generic, resta letto.
private let NON_READ_ROLES: Set<String> = [
    SemanticCategory.MARGINAL_GLOSS.rawValue,
    SemanticCategory.TOC_GENERAL.rawValue,
    SemanticCategory.ARTIFACT_STAMP.rawValue,
    SemanticCategory.INDEX_ENTRY.rawValue,
]

private func segmentFor(_ node: NodeDict, _ text: String) -> ContentSegment {
    let lengthCategory = node.length_category?.rawValue ?? ""
    // Synthetic AKN containers are reclassified to a divider role so they are not
    // read as ordinary chapter headings (Punto 2 / registry 2).
    let role = isSyntheticContainer(node.type.rawValue, node.text)
        ? SECTION_DIVIDER_ROLE
        : node.type.rawValue
    return ContentSegment(
        id: node.id,
        role: role,
        text: text,
        lengthCategory: lengthCategory,
        acousticIntro: acousticIntroFor(role, lengthCategory)
    )
}

// MARK: - Solo le note VERE annunciano "Nota." (passo finale, solo backend Generic)

/// Profilo dei documenti prodotti dal classificatore euristico size-only (il
/// Generic PDF). È l'UNICO backend che può collassare in `NOTE` una testatina o un
/// titolo di sezione in maiuscoletto a taglia inferiore al corpo; i backend
/// strutturati (AKN, EPUB) emettono note semanticamente vere e non vanno toccati.
private let HEURISTIC_NOTE_PROFILE_ID = "generic"

/// Simboli di richiamo di nota ammessi a inizio testo (oltre al numerico).
private let NOTE_SYMBOL_MARKERS: Set<Character> = ["*", "†", "‡", "§", "¶"]

/// Vero se il testo si apre con un marcatore di nota: un numero d'apertura
/// (riusa `noteOpening`, che copre "12.", "(3)", "[4]") o un simbolo di richiamo.
/// È il discriminatore fra una nota vera (apparato) e un'intestazione collassata
/// in `NOTE` dal classificatore size-only.
func textOpensWithNoteMarker(_ text: String) -> Bool {
    if noteOpening(text) != nil { return true }
    if let first = jsTrim(text).first, NOTE_SYMBOL_MARKERS.contains(first) { return true }
    return false
}

/// Toglie l'intro "Nota." dai segmenti `NOTE` il cui testo NON si apre con un
/// marcatore di nota — sul solo flusso del backend euristico (Generic). Sono le
/// testatine/titoli di sezione che il classificatore size-only ha collassato in
/// `NOTE`: senza questo passo si sentirebbe "Nota." prima di un'intestazione (il
/// difetto a orecchio). Il TESTO resta invariato e letto in posizione (nessun
/// contenuto perso, rete A); cambia solo il prefisso parlato. `EDITORIAL_NOTE`
/// (solo AKN) e ogni altro ruolo non sono toccati. Idempotente.
func suppressCollapsedHeadingNoteIntros(_ segments: [ContentSegment]) -> [ContentSegment] {
    segments.map { seg in
        guard seg.role == SemanticCategory.NOTE.rawValue,
              !seg.acousticIntro.isEmpty,
              !textOpensWithNoteMarker(seg.text) else { return seg }
        var fixed = seg
        fixed.acousticIntro = ""
        return fixed
    }
}

/// Pushes the parent's own text for `[start, end)` as a segment, trimmed.
private func pushSlice(
    _ items: inout [Work],
    _ node: NodeDict,
    _ text: String,
    _ start: String.Index,
    _ end: String.Index
) {
    // Guards an empty or inverted span (the TS `if (end <= start) return`). It
    // must run before forming the Swift range, which would trap on start > end.
    if end <= start {
        return
    }
    let slice = text[start..<end].trimmingCharacters(in: .whitespacesAndNewlines)
    if slice.isEmpty {
        return
    }
    items.append(.segment(segmentFor(node, slice)))
}

/// Builds the ordered work-items a node expands into (children + own text).
private func expand(_ node: NodeDict) -> [Work] {
    // Glosse laterali (e altri ruoli non-letti): scartate dal flusso vocale, ma
    // restano nell'albero del documento. Sono foglie senza figli nel Generic.
    if NON_READ_ROLES.contains(node.type.rawValue) {
        return []
    }
    let text = node.text ?? ""
    let children = node.children

    if children.isEmpty {
        return text.isEmpty ? [] : [.segment(segmentFor(node, text))]
    }

    // Place each child at its first occurrence as a contiguous substring of the
    // parent text. Children whose text is not found are disjoint content, emitted
    // in tree order after the parent's own text. `order` records the original
    // index so ties (rare — identical child texts) keep the TS stable-sort order.
    struct Placed {
        let child: NodeDict
        let start: String.Index
        let end: String.Index
        let order: Int
    }
    var placed: [Placed] = []
    var disjoint: [NodeDict] = []
    for (index, child) in children.enumerated() {
        let childText = child.text ?? ""
        if !childText.isEmpty,
           let range = text.range(of: childText, options: .literal) {
            placed.append(Placed(child: child, start: range.lowerBound, end: range.upperBound, order: index))
        } else {
            disjoint.append(child)
        }
    }

    var items: [Work] = []

    if placed.isEmpty {
        // No child reproduces the parent text: emit the parent in full, then the
        // children in pre-order. (Synthetic containers, EPUB commi, plain prose.)
        if !text.isEmpty {
            items.append(.segment(segmentFor(node, text)))
        }
        for child in children {
            items.append(.node(child))
        }
        return items
    }

    // Interleave the parent's uncovered spans with the substring children, in
    // textual order (the physical reading order). Overlapping matches are clamped
    // via `cursor` so a span is never re-emitted.
    placed.sort { a, b in
        if a.start != b.start { return a.start < b.start }
        if a.end != b.end { return a.end < b.end }
        return a.order < b.order
    }
    var cursor = text.startIndex
    for entry in placed {
        pushSlice(&items, node, text, cursor, entry.start)
        items.append(.node(entry.child))
        cursor = Swift.max(cursor, entry.end)
    }
    pushSlice(&items, node, text, cursor, text.endIndex)
    for child in disjoint {
        items.append(.node(child))
    }
    return items
}

/// Walks the document and emits the base segment stream every layout starts from.
public func buildBaseSegments(_ doc: ScabopdfDocument) -> [ContentSegment] {
    var out: [ContentSegment] = []
    var stack: [Work] = []

    func pushReversed(_ items: [Work]) {
        var i = items.count - 1
        while i >= 0 {
            stack.append(items[i])
            i -= 1
        }
    }

    pushReversed(doc.structure.map { Work.node($0) })

    while let work = stack.popLast() {
        switch work {
        case .segment(let segment):
            out.append(segment)
        case .node(let node):
            pushReversed(expand(node))
        }
    }
    // Passo finale, solo per il backend euristico (Generic): le testatine / titoli
    // di sezione collassati in NOTE dal classificatore size-only non devono
    // annunciare "Nota.". Vedi `suppressCollapsedHeadingNoteIntros`.
    return doc.profile.profile_id == HEURISTIC_NOTE_PROFILE_ID
        ? suppressCollapsedHeadingNoteIntros(out)
        : out
}
