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
/// `MARGINAL_GLOSS` (glosse laterali) sono parole-chiave/titoletti a margine:
/// ridondanti col corpo (indagine docs/GLOSSE_LATERALI.md, perdita ≤0.07%) e, in un
/// flusso lineare, interruzioni a metà discorso. Si scartano dalla voce come la
/// furniture, ma restano CATEGORIZZATI nell'albero (scelta reversibile: un domani
/// potranno servire alla navigazione). Le note vere restano lette/piazzate.
private let NON_READ_ROLES: Set<String> = [SemanticCategory.MARGINAL_GLOSS.rawValue]

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
    return out
}
