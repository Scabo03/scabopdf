//
//  AknParser.swift
//  ScaboCore
//
//  Parser Akoma Ntoso (Normattiva) in Swift — port fedele della specifica
//  eseguibile Python `xml_akn/parser.py`. Dato un file AKN, produce direttamente
//  uno `ScabopdfDocument` valido (schema 0.7.0), confluendo sul modello comune
//  SENZA passare da PdfExtraction né dai plugin di classificazione visiva
//  (secondo pattern (zzz): backend separato che produce il Document diretto).
//
//  L'ordine di minting degli id ("node_N", contatore da 0, pre-order) e il
//  vocabolario chiuso dei warning sono replicati esattamente perché i 13 baseline
//  N-* committati sono l'oracolo di parità (test AknParserParityTests).
//
//  Mapping (BEN_FORMATO): book/part/title→HEADING_1, chapter→HEADING_2,
//  section→HEADING_3 (o note-container→NOTE), article→ARTICLE_HEADER+ARTICLE_BODY,
//  paragraph→ARTICLE_BODY, point→LIST_ITEM, mod→AMENDMENT, quotedText→
//  QUOTED_TEXT_OLD/NEW, textualMod→UPDATE_BLOCK in container HEADING_1,
//  authorialNote→NOTE. FRAGMENTED: attachment/doc→ARTICLE_HEADER+ARTICLE_BODY.
//  Promulgativo: articoli body-direct sotto container HEADING_1 "Decreto di
//  promulgazione".
//

import Foundation

/// Errore di rifiuto del parser su un file AKN non processabile.
public enum AknParseError: Error, Equatable {
    case refused(verdict: AknHealthVerdict, explanation: String)
}

// MARK: - Helpers testo

private let _wsRegex = try! NSRegularExpression(pattern: "\\s+")

/// Collassa gli spazi interni e taglia i bordi (come `_normalise_ws`).
func aknNormaliseWs(_ text: String) -> String {
    let r = NSRange(text.startIndex..<text.endIndex, in: text)
    let collapsed = _wsRegex.stringByReplacingMatches(in: text, range: r, withTemplate: " ")
    return collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
}

private let _noteMarkerStrip = try! NSRegularExpression(pattern: "^\\s*\\(?\\d+\\)\\s*")

/// Regime acustico di una NOTE — port fedele di `compute_note_length_category`:
/// strip del marker numerico iniziale, conteggio in code point (unicodeScalars),
/// `nil` per testo vuoto o vuoto-dopo-strip. Soglie 50/100/500/1000/3000.
func aknNoteLengthCategory(_ text: String?) -> LengthCategory? {
    guard let text else { return nil }
    let r = NSRange(text.startIndex..<text.endIndex, in: text)
    let stripped = _noteMarkerStrip.stringByReplacingMatches(in: text, range: r, withTemplate: "")
    let n = stripped.unicodeScalars.count
    if n == 0 { return nil }
    if n < 50 { return .MICRO }
    if n < 100 { return .SHORT }
    if n < 500 { return .MEDIUM }
    if n < 1000 { return .LONG }
    if n < 3000 { return .VERY_LONG }
    return .MEGA
}

private func itertextNorm(_ elem: AknElement?) -> String {
    guard let elem else { return "" }
    return aknNormaliseWs(elem.itertext())
}

// MARK: - Minter

private final class AknNodeIdMinter {
    private var counter = 0
    func next() -> String { let s = "node_\(counter)"; counter += 1; return s }
    var peek: Int { counter }
}

private func mkNode(
    _ minter: AknNodeIdMinter, _ category: SemanticCategory, _ text: String?,
    level: Int? = nil, children: [NodeDict] = []
) -> NodeDict {
    let lc = category == .NOTE ? aknNoteLengthCategory(text) : nil
    return NodeDict(id: minter.next(), type: category, page_index: 0, text: text,
                    level: level, length_category: lc, children: children)
}

// MARK: - Parser

/// Costruisce lo `ScabopdfDocument` da un file AKN. Solleva `AknParseError` su
/// NOT_AKN / INVALID_XML; OK e FRAGMENTED producono entrambi un documento.
public func buildAknDocument(_ data: Data, sourceName: String) throws -> ScabopdfDocument {
    let health = detectAknHealth(data)
    switch health.verdict {
    case .invalidXml, .notAkn:
        throw AknParseError.refused(verdict: health.verdict, explanation: health.explanation)
    case .ok, .fragmented:
        break
    }
    guard let root = AknXmlTree.parse(data) else {
        throw AknParseError.refused(verdict: .invalidXml, explanation: health.explanation)
    }

    let minter = AknNodeIdMinter()
    var warnings: [String] = []

    let bodyNodes: [NodeDict]
    if isPromulgativeAct(root) {
        bodyNodes = walkBodyWithPromulgationContainer(root, minter, &warnings)
    } else {
        bodyNodes = walkBody(root, minter, &warnings)
    }

    var allNodes = bodyNodes
    if health.verdict == .fragmented {
        warnings.append("xml_akn:fragmented:editorial_hierarchy_unrecoverable")
        allNodes += walkFragmentedAttachments(root, minter, &warnings)
    }

    allNodes += emitModificationsContainers(root, minter, &warnings)

    let metadata = DocumentMetadata(pages_pdf: 0, page_size_pt: [0.0, 0.0], source_pdf_filename: sourceName)
    let profile = DocumentProfileDict(
        profile_id: "normattiva_xml_akn", editorial_family: "normattiva",
        genre: "legal_text_xml_akn", confidence: 1.0)
    return ScabopdfDocument(
        schema_version: SUPPORTED_SCHEMA_VERSION, document_id: UUID().uuidString,
        metadata: metadata, profile: profile, warnings: warnings,
        transformations: [], structure: allNodes)
}

// MARK: - BEN_FORMATO

private let _headingLevelToCategory: [Int: SemanticCategory] = [
    1: .HEADING_1, 2: .HEADING_2, 3: .HEADING_3, 4: .HEADING_4,
]

private func numPlusContentText(_ elem: AknElement) -> String {
    let numText = itertextNorm(elem.firstChild("num"))
    let content = elem.firstChild("content")
    let bodyText: String
    if let content {
        bodyText = itertextNorm(content)
    } else {
        var parts: [String] = []
        for child in elem.children where !(child.namespaceURI == AKN.ns && (child.localName == "num" || child.localName == "list")) {
            let t = aknNormaliseWs(child.itertext())
            if !t.isEmpty { parts.append(t) }
        }
        bodyText = aknNormaliseWs(parts.joined(separator: " "))
    }
    if !numText.isEmpty {
        return "\(numText) \(bodyText)".trimmingCharacters(in: .whitespacesAndNewlines)
    }
    return bodyText
}

private func emitAmendment(_ modElem: AknElement, _ minter: AknNodeIdMinter, _ warnings: inout [String]) -> NodeDict {
    let amendmentId = minter.next()
    var children: [NodeDict] = []
    for qt in modElem.childrenNamed("quotedText") {
        let eid = qt.attr("eId") ?? ""
        let qtText = itertextNorm(qt)
        let cat: SemanticCategory
        if eid.contains("_old_") {
            cat = .QUOTED_TEXT_OLD
        } else if eid.contains("_new_") {
            cat = .QUOTED_TEXT_NEW
        } else {
            cat = .QUOTED_TEXT_NEW
            warnings.append("xml_akn:amendments:quoted_text_eid_unrecognised_node_node_\(minter.peek)")
        }
        children.append(NodeDict(id: minter.next(), type: cat, page_index: 0, text: qtText))
    }
    if children.isEmpty {
        warnings.append("xml_akn:amendments:mod_without_quoted_text_node_\(amendmentId)")
    }
    return NodeDict(id: amendmentId, type: .AMENDMENT, page_index: 0,
                    text: itertextNorm(modElem), children: children)
}

private func collectAmendmentsIn(_ host: AknElement, _ minter: AknNodeIdMinter, _ warnings: inout [String]) -> [NodeDict] {
    guard let content = host.firstChild("content") else { return [] }
    var out: [NodeDict] = []
    for p in content.childrenNamed("p") {
        for mod in p.childrenNamed("mod") {
            out.append(emitAmendment(mod, minter, &warnings))
        }
    }
    return out
}

private func emitParagraph(_ elem: AknElement, _ minter: AknNodeIdMinter, _ warnings: inout [String]) -> [NodeDict] {
    var out: [NodeDict] = []
    let bodyId = minter.next()
    let bodyText = numPlusContentText(elem)
    let bodyAmendments = collectAmendmentsIn(elem, minter, &warnings)
    out.append(NodeDict(id: bodyId, type: .ARTICLE_BODY, page_index: 0, text: bodyText, children: bodyAmendments))

    for point in elem.descendants("point") {
        let itemText = numPlusContentText(point)
        if itemText.isEmpty { continue }
        let itemId = minter.next()
        let itemAmendments = collectAmendmentsIn(point, minter, &warnings)
        out.append(NodeDict(id: itemId, type: .LIST_ITEM, page_index: 0, text: itemText, children: itemAmendments))
    }
    return out
}

private func isNotesContainerSection(_ section: AknElement) -> Bool {
    let hasNote = section.firstDescendant("authorialNote") != nil
    let hasStructural = section.firstChild("article") != nil
        || section.firstChild("paragraph") != nil
        || section.firstChild("chapter") != nil
    return hasNote && !hasStructural
}

private func emitAuthorialNotes(_ parent: AknElement, _ minter: AknNodeIdMinter) -> [NodeDict] {
    var out: [NodeDict] = []
    for note in parent.descendants("authorialNote") {
        let text = itertextNorm(note)
        if text.isEmpty { continue }
        out.append(mkNode(minter, .NOTE, text))
    }
    return out
}

private func emitArticle(_ elem: AknElement, _ minter: AknNodeIdMinter, _ warnings: inout [String]) -> [NodeDict] {
    var out: [NodeDict] = []
    let numText = itertextNorm(elem.firstChild("num"))
    var headText = itertextNorm(elem.firstChild("heading"))
    var paragraphs = elem.childrenNamed("paragraph")
    if let first = paragraphs.first, first.firstChild("num") == nil, headText.isEmpty {
        let complement = itertextNorm(first)
        if !complement.isEmpty { headText = complement }
        paragraphs = Array(paragraphs.dropFirst())
    }
    let headerText = [numText, headText].filter { !$0.isEmpty }.joined(separator: " ")
    out.append(mkNode(minter, .ARTICLE_HEADER, headerText))
    for paragraph in paragraphs {
        out += emitParagraph(paragraph, minter, &warnings)
    }
    out += emitAuthorialNotes(elem, minter)
    return out
}

private func emitHeading(_ elem: AknElement, _ minter: AknNodeIdMinter, _ level: Int, _ warnings: inout [String]) -> [NodeDict] {
    let numText = itertextNorm(elem.firstChild("num"))
    let headText = itertextNorm(elem.firstChild("heading"))
    let headingText = [numText, headText].filter { !$0.isEmpty }.joined(separator: " ")
    var out: [NodeDict] = [mkNode(minter, _headingLevelToCategory[level]!, headingText, level: level)]
    for child in elem.children {
        out += dispatch(child, minter, parentLevel: level, &warnings)
    }
    return out
}

private func dispatch(_ elem: AknElement, _ minter: AknNodeIdMinter, parentLevel: Int, _ warnings: inout [String]) -> [NodeDict] {
    guard elem.namespaceURI == AKN.ns else { return [] }
    switch elem.localName {
    case "book", "part", "title":
        return emitHeading(elem, minter, 1, &warnings)
    case "chapter":
        return emitHeading(elem, minter, 2, &warnings)
    case "section":
        return isNotesContainerSection(elem)
            ? emitAuthorialNotes(elem, minter)
            : emitHeading(elem, minter, 3, &warnings)
    case "article":
        return emitArticle(elem, minter, &warnings)
    case "paragraph":
        return emitParagraph(elem, minter, &warnings)
    default:
        return []
    }
}

private func walkBody(_ root: AknElement, _ minter: AknNodeIdMinter, _ warnings: inout [String]) -> [NodeDict] {
    guard let body = root.firstDescendant("body") else { return [] }
    var out: [NodeDict] = []
    for child in body.children {
        out += dispatch(child, minter, parentLevel: 0, &warnings)
    }
    return out
}

// MARK: - Modifiche (schema 0.7.0)

private func extractTextualModPayload(_ elem: AknElement?, role: String) -> String {
    guard let elem else { return "" }
    let text = itertextNorm(elem)
    if !text.isEmpty { return text }
    let href = elem.attr("href") ?? ""
    if !href.isEmpty { return "[\(role)→\(href)]" }
    return ""
}

private func emitTextualMod(_ tm: AknElement, _ minter: AknNodeIdMinter, _ position: Int, _ direction: String, _ warnings: inout [String]) -> NodeDict {
    let tmId = minter.next()
    let typeAttr = (tm.attr("type").flatMap { $0.isEmpty ? nil : $0 }) ?? "(unknown)"
    let srcHref = tm.firstChild("source")?.attr("href") ?? ""
    let dstHref = tm.firstChild("destination")?.attr("href") ?? ""
    if srcHref.isEmpty || dstHref.isEmpty {
        warnings.append("xml_akn:amendments:textual_mod_missing_source_or_destination_\(direction)_position_\(position)")
    }
    let newText = extractTextualModPayload(tm.firstChild("new"), role: "new")
    let oldText = extractTextualModPayload(tm.firstChild("old"), role: "old")
    let prose: String
    if !newText.isEmpty && !oldText.isEmpty {
        prose = "vecchio: \(oldText) | nuovo: \(newText)"
    } else if !newText.isEmpty {
        prose = newText
    } else if !oldText.isEmpty {
        prose = oldText
    } else {
        prose = ""
        warnings.append("xml_akn:amendments:textual_mod_without_text_\(direction)_position_\(position)")
    }
    var coordsParts: [String] = []
    if !srcHref.isEmpty { coordsParts.append("source \(srcHref)") }
    if !dstHref.isEmpty { coordsParts.append("destination \(dstHref)") }
    let coords = coordsParts.joined(separator: ", ")
    let text: String
    if !prose.isEmpty && !coords.isEmpty {
        text = "\(typeAttr): \(prose) (\(coords))"
    } else if !prose.isEmpty {
        text = "\(typeAttr): \(prose)"
    } else if !coords.isEmpty {
        text = "\(typeAttr): (\(coords))"
    } else {
        text = "\(typeAttr):"
    }
    return NodeDict(id: tmId, type: .UPDATE_BLOCK, page_index: 0, text: text)
}

private func emitModificationsContainers(_ root: AknElement, _ minter: AknNodeIdMinter, _ warnings: inout [String]) -> [NodeDict] {
    var out: [NodeDict] = []
    let directions: [(tag: String, dir: String, text: String)] = [
        ("activeModifications", "active", "Modificazioni attive a altri atti"),
        ("passiveModifications", "passive", "Modificazioni passive di questo atto"),
    ]
    for d in directions {
        guard let container = root.firstDescendant(d.tag) else { continue }
        let textualMods = container.childrenNamed("textualMod")
        if textualMods.isEmpty { continue }
        let containerId = minter.next()
        var children: [NodeDict] = []
        for (position, tm) in textualMods.enumerated() {
            children.append(emitTextualMod(tm, minter, position, d.dir, &warnings))
        }
        out.append(NodeDict(id: containerId, type: .HEADING_1, page_index: 0, text: d.text, level: 1, children: children))
        warnings.append("xml_akn:amendments:\(d.dir)_modifications_minted_\(children.count)")
    }
    return out
}

// MARK: - FRAGMENTED

private let _fragmentedArticleNumberPattern = try! NSRegularExpression(
    pattern: "-art\\.\\s*(\\d+(?:[\\s\\-][a-z]+(?:\\.\\d+)?|/\\d+)?)\\s*$")

private func extractFragmentedArticleToken(_ docName: String?) -> String? {
    guard let docName else { return nil }
    let r = NSRange(docName.startIndex..<docName.endIndex, in: docName)
    guard let m = _fragmentedArticleNumberPattern.firstMatch(in: docName, range: r),
          let g = Range(m.range(at: 1), in: docName) else { return nil }
    return aknNormaliseWs(String(docName[g]))
}

private func emitFragmentedDoc(_ doc: AknElement, _ position: Int, _ minter: AknNodeIdMinter, _ warnings: inout [String]) -> [NodeDict] {
    var out: [NodeDict] = []
    let token = extractFragmentedArticleToken(doc.attr("name"))
    let headerText: String
    if let token {
        headerText = "Art. \(token)"
    } else {
        warnings.append("xml_akn:fragmented:doc_name_unparseable_position_\(position)")
        headerText = "Art. (sconosciuto)"
    }
    out.append(mkNode(minter, .ARTICLE_HEADER, headerText))
    guard let mainBody = doc.firstChild("mainBody") else {
        warnings.append("xml_akn:fragmented:doc_without_mainbody_position_\(position)")
        return out
    }
    let paragraphs = mainBody.childrenNamed("paragraph")
    if paragraphs.isEmpty {
        warnings.append("xml_akn:fragmented:doc_without_paragraphs_position_\(position)")
        return out
    }
    for paragraph in paragraphs {
        out += emitParagraph(paragraph, minter, &warnings)
    }
    return out
}

private func walkFragmentedAttachments(_ root: AknElement, _ minter: AknNodeIdMinter, _ warnings: inout [String]) -> [NodeDict] {
    var out: [NodeDict] = []
    for (position, att) in root.descendants("attachment").enumerated() {
        guard let doc = att.firstChild("doc") else {
            warnings.append("xml_akn:fragmented:attachment_without_doc_position_\(position)")
            continue
        }
        out += emitFragmentedDoc(doc, position, minter, &warnings)
    }
    return out
}

// MARK: - Front-matter promulgativo

private func isPromulgativeAct(_ root: AknElement) -> Bool {
    guard let body = root.firstDescendant("body") else { return false }
    let hasBodyArticle = body.children.contains { $0.namespaceURI == AKN.ns && $0.localName == "article" }
    if !hasBodyArticle { return false }
    let hasBodyChapter = body.children.contains { $0.namespaceURI == AKN.ns && $0.localName == "chapter" }
    if hasBodyChapter { return true }
    for att in root.descendants("attachment") {
        guard let doc = att.firstChild("doc") else { continue }
        if extractFragmentedArticleToken(doc.attr("name")) != nil { return true }
    }
    return false
}

private func walkBodyWithPromulgationContainer(_ root: AknElement, _ minter: AknNodeIdMinter, _ warnings: inout [String]) -> [NodeDict] {
    guard let body = root.firstDescendant("body") else { return [] }
    let containerId = minter.next()
    var promulgationChildren: [NodeDict] = []
    var rest: [NodeDict] = []
    var articleCount = 0
    for child in body.children {
        let emitted = dispatch(child, minter, parentLevel: 0, &warnings)
        if child.namespaceURI == AKN.ns && child.localName == "article" {
            promulgationChildren += emitted
            articleCount += 1
        } else {
            rest += emitted
        }
    }
    let container = NodeDict(id: containerId, type: .HEADING_1, page_index: 0,
                             text: "Decreto di promulgazione", level: 1, children: promulgationChildren)
    warnings.append("xml_akn:promulgation:front_matter_articles_\(articleCount)")
    return [container] + rest
}
