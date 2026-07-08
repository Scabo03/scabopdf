//
//  AknDetector.swift
//  ScaboCore
//
//  Health-check detector per gli export Akoma Ntoso di Normattiva. Port fedele di
//  `xml_akn/detector.py`: soglie calibrate empiricamente sui 13 fixture, quattro
//  verdetti chiusi con spiegazione in prosa per VoiceOver. Individua l'export-bug
//  FRAGMENTED (Codice Civile/Penale: corpo svuotato, contenuto disperso in
//  migliaia di `<attachment>/<doc>`).
//

import Foundation

/// I quattro verdetti chiusi del detector.
public enum AknHealthVerdict: String, Equatable, Sendable {
    case ok = "OK"
    case fragmented = "FRAGMENTED"
    case notAkn = "NOT_AKN"
    case invalidXml = "INVALID_XML"
}

/// Inventario strutturale dell'albero AKN (una sola passata).
public struct AknStructuralSummary: Equatable, Sendable {
    public var rootLocalName: String
    public var rootNamespace: String
    public var bodyArticleCount: Int
    public var bodyParagraphCount: Int
    public var bodyChapterCount: Int
    public var attachmentCount: Int
    public var attachmentDocCount: Int
    public var attachmentParagraphCount: Int
}

/// Esito del detector, con spiegazione accessibile e suggerimento di fallback.
public struct AknHealthReport: Equatable, Sendable {
    public var verdict: AknHealthVerdict
    public var explanation: String
    public var suggestedAlternative: String?
    public var summary: AknStructuralSummary?
}

// Soglie calibrate (xml_akn/constants.py).
private let BODY_ARTICLE_OK_MIN = 5
private let BODY_ARTICLE_STUB_MAX = 4
private let ATTACHMENT_DOC_FRAGMENTED_MIN = 50
private let ATTACHMENT_PARAGRAPH_FRAGMENTED_MIN = 100

private func buildSummary(_ root: AknElement) -> AknStructuralSummary {
    var bodyArticles = 0, bodyParagraphs = 0, bodyChapters = 0
    for body in root.descendants("body") {
        bodyArticles += body.descendants("article").count
        bodyParagraphs += body.descendants("paragraph").count
        bodyChapters += body.descendants("chapter").count
    }
    let attachments = root.descendants("attachment")
    var docCount = 0, paraCount = 0
    for att in attachments {
        docCount += att.descendants("doc").count
        paraCount += att.descendants("paragraph").count
    }
    return AknStructuralSummary(
        rootLocalName: root.localName, rootNamespace: root.namespaceURI,
        bodyArticleCount: bodyArticles, bodyParagraphCount: bodyParagraphs,
        bodyChapterCount: bodyChapters, attachmentCount: attachments.count,
        attachmentDocCount: docCount, attachmentParagraphCount: paraCount)
}

private func classify(_ s: AknStructuralSummary) -> AknHealthVerdict {
    if s.rootLocalName != AKN.rootLocalName || s.rootNamespace != AKN.ns {
        return .notAkn
    }
    if s.bodyArticleCount >= BODY_ARTICLE_OK_MIN { return .ok }
    if s.bodyArticleCount <= BODY_ARTICLE_STUB_MAX
        && s.attachmentDocCount >= ATTACHMENT_DOC_FRAGMENTED_MIN
        && s.attachmentParagraphCount >= ATTACHMENT_PARAGRAPH_FRAGMENTED_MIN {
        return .fragmented
    }
    return .ok
}

private func explanation(_ verdict: AknHealthVerdict, _ s: AknStructuralSummary?)
    -> (String, String?) {
    switch verdict {
    case .invalidXml:
        return ("Il file non è XML ben formato e non può essere analizzato.", nil)
    case .notAkn:
        let found = s.map { "'\($0.rootLocalName)' nel namespace '\($0.rootNamespace)'" }
            ?? "un elemento diverso"
        return ("Il file è XML ma non è un documento Akoma Ntoso. L'elemento radice atteso è "
            + "'\(AKN.rootLocalName)' nel namespace OASIS LegalDocML 1.0 ma è stato trovato \(found).", nil)
    case .fragmented:
        let a = s?.bodyArticleCount ?? 0, d = s?.attachmentDocCount ?? 0, p = s?.attachmentParagraphCount ?? 0
        return ("Il file è un export Normattiva strutturalmente patologico. Il corpo del documento "
            + "contiene solo \(a) articoli formali, ma il contenuto sostanziale è frammentato in "
            + "\(d) sotto-documenti allegati con un totale di \(p) commi. La gerarchia editoriale "
            + "(Libro, Titolo, Capo, Sezione) è andata persa nell'export. Il parser può comunque "
            + "ricostruire una lista lineare di articoli, ma la struttura editoriale di partenza non "
            + "è recuperabile da questo XML. Si consiglia di provare il formato EPUB dello stesso atto, "
            + "che spesso preserva meglio la struttura.", "EPUB")
    case .ok:
        let a = s?.bodyArticleCount ?? 0, c = s?.bodyParagraphCount ?? 0
        let at = s?.attachmentCount ?? 0, ap = s?.attachmentParagraphCount ?? 0
        return ("Il file è un export Akoma Ntoso ben formato. Il corpo del documento contiene \(a) "
            + "articoli e \(c) commi nel body. Gli allegati sono \(at) con un totale di \(ap) commi. "
            + "Il parser può produrre un documento completo da questo file.", nil)
    }
}

/// Classifica la salute di un export AKN Normattiva a partire dai byte del file.
public func detectAknHealth(_ data: Data) -> AknHealthReport {
    guard let root = AknXmlTree.parse(data) else {
        let (e, _) = explanation(.invalidXml, nil)
        return AknHealthReport(verdict: .invalidXml, explanation: e, suggestedAlternative: nil, summary: nil)
    }
    let summary = buildSummary(root)
    let verdict = classify(summary)
    let (e, alt) = explanation(verdict, summary)
    return AknHealthReport(verdict: verdict, explanation: e, suggestedAlternative: alt, summary: summary)
}
