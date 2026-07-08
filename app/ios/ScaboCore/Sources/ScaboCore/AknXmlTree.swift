//
//  AknXmlTree.swift
//  ScaboCore
//
//  Modello albero XML minimale + costruttore SAX (`XMLParser`) per il backend
//  Akoma Ntoso. Su iOS `XMLDocument`/XPath non esiste (è solo-macOS): l'albero va
//  costruito dagli eventi SAX. Questo modello replica le due primitive di
//  ElementTree su cui si appoggia la specifica Python `xml_akn`:
//    • `itertext()` — concatenazione del testo visibile in ordine di lettura,
//      interlacciando `text` dell'elemento e `tail` di ogni figlio;
//    • `find`/`findall` per local-name nel namespace AKN (figlio diretto e
//      discendente).
//  Puro Foundation, nessuna dipendenza UI. Confluisce sul modello comune
//  (`ScabopdfDocument`) tramite `AknParser`, senza toccare il percorso PDF.
//

import Foundation

/// Un elemento dell'albero AKN. `text` è il testo che precede il primo figlio;
/// `tail` è il testo che segue la chiusura di QUESTO elemento fino al prossimo
/// fratello (convenzione ElementTree, necessaria per `itertext`).
public final class AknElement {
    public let namespaceURI: String
    public let localName: String
    public let attributes: [String: String]
    public var text: String = ""
    public var tail: String = ""
    public var children: [AknElement] = []

    init(namespaceURI: String, localName: String, attributes: [String: String]) {
        self.namespaceURI = namespaceURI
        self.localName = localName
        self.attributes = attributes
    }

    /// Testo visibile completo sotto questo elemento, in ordine di lettura
    /// (equivalente a `"".join(elem.itertext())` di ElementTree).
    public func itertext() -> String {
        var s = text
        for c in children {
            s += c.itertext()
            s += c.tail
        }
        return s
    }

    /// Primo figlio DIRETTO con il local-name dato nel namespace AKN
    /// (equivalente a `find("./akn:<local>")`).
    public func firstChild(_ local: String) -> AknElement? {
        for c in children where c.localName == local && c.namespaceURI == AKN.ns {
            return c
        }
        return nil
    }

    /// Tutti i figli DIRETTI con il local-name dato nel namespace AKN
    /// (equivalente a `findall("./akn:<local>")`).
    public func childrenNamed(_ local: String) -> [AknElement] {
        children.filter { $0.localName == local && $0.namespaceURI == AKN.ns }
    }

    /// Primo DISCENDENTE (qualsiasi profondità) con il local-name dato nel
    /// namespace AKN (equivalente a `find(".//akn:<local>")`).
    public func firstDescendant(_ local: String) -> AknElement? {
        for c in children {
            if c.localName == local && c.namespaceURI == AKN.ns { return c }
            if let d = c.firstDescendant(local) { return d }
        }
        return nil
    }

    /// Tutti i DISCENDENTI con il local-name dato nel namespace AKN, in ordine
    /// di documento (equivalente a `findall(".//akn:<local>")`).
    public func descendants(_ local: String) -> [AknElement] {
        var out: [AknElement] = []
        appendDescendants(local, into: &out)
        return out
    }

    private func appendDescendants(_ local: String, into out: inout [AknElement]) {
        for c in children {
            if c.localName == local && c.namespaceURI == AKN.ns { out.append(c) }
            c.appendDescendants(local, into: &out)
        }
    }

    /// Valore di un attributo (senza prefisso), o `nil` se assente.
    public func attr(_ name: String) -> String? { attributes[name] }
}

/// Costanti di namespace AKN (sottoinsieme di `xml_akn/constants.py` usato dal
/// parser e dal detector Swift).
public enum AKN {
    public static let ns = "http://docs.oasis-open.org/legaldocml/ns/akn/3.0"
    public static let rootLocalName = "akomaNtoso"
}

/// Costruisce l'albero AKN dagli eventi SAX di `XMLParser`. Ritorna la radice, o
/// `nil` se l'XML non è ben formato (verdetto INVALID_XML a valle).
public enum AknXmlTree {

    public static func parse(_ data: Data) -> AknElement? {
        let parser = XMLParser(data: data)
        let builder = _Builder()
        parser.shouldProcessNamespaces = true
        parser.delegate = builder
        guard parser.parse(), let root = builder.root else { return nil }
        return root
    }

    private final class _Builder: NSObject, XMLParserDelegate {
        var root: AknElement?
        private var stack: [AknElement] = []
        private var pending = ""

        /// Assegna il testo accumulato allo slot giusto del top: `text`
        /// dell'elemento se non ha ancora figli, altrimenti `tail` dell'ultimo
        /// figlio.
        private func flushPending() {
            guard !pending.isEmpty, let top = stack.last else { pending = ""; return }
            if let last = top.children.last {
                last.tail += pending
            } else {
                top.text += pending
            }
            pending = ""
        }

        func parser(
            _ parser: XMLParser, didStartElement elementName: String,
            namespaceURI: String?, qualifiedName qName: String?,
            attributes attributeDict: [String: String]
        ) {
            flushPending()
            let elem = AknElement(
                namespaceURI: namespaceURI ?? "", localName: elementName,
                attributes: attributeDict)
            stack.last?.children.append(elem)
            if root == nil { root = elem }
            stack.append(elem)
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            pending += string
        }

        func parser(
            _ parser: XMLParser, didEndElement elementName: String,
            namespaceURI: String?, qualifiedName qName: String?
        ) {
            flushPending()
            if !stack.isEmpty { stack.removeLast() }
        }
    }
}
