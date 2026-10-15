//
//  Fusore.swift
//  ScaboCore
//
//  IL FUSORE dell'officina, portato in Swift dal Python del banco ultrafocus (`ultrafocus_bench/fusore/fusore.py`,
//  agosto 2026) nel giro «costruzione della linea Mac» (2026-10-16). Fonde il verdetto STRUTTURALE del modello
//  d'impaginazione (Heron di docling, in Core ML: `ScaboPageStructure`) con l'elaborazione deterministica dell'app,
//  senza mai toccare il testo. Due innesti, come nel banco:
//
//  * livello ESTRAZIONE (`fuseExtraction`): sposta RIGHE di `PdfExtraction` — ricucitura della nota che scavalca la
//    pagina (MULTIPAGE: le righe della coda orfana in testa al settore note di B vanno in coda alla pagina A) e
//    riordino delle righe di una pagina secondo l'ordine di lettura del modello. Il documento si ricostruisce poi con
//    la stessa classificazione dell'app (`buildDocumentFromPdf`).
//  * livello NODO (`fuseDocument`): rietichettature SLOT-PRESERVING sul documento grezzo (pre-aggancio): didascalia
//    che non è nota, tabella che non è nota, nodi NOTE di una pagina dove il modello non vede alcuna nota (indici
//    analitici). Fusione e scissione di nodi sono portate per fedeltà al banco ma il banco stesso le sconsiglia
//    (inserire o togliere nodi rompe lo zip posizionale nodo↔riga dell'aggancio note): i giri del 2026-08 hanno
//    spostato quei casi al livello d'estrazione.
//
//  REGOLA NON NEGOZIABILE — il testo è intoccabile. Il fusore riordina, rietichetta, aggancia e spezza ai confini di
//  parola; non riscrive, non corregge, non inventa, non perde. A fine fusione la RETE DI FEDELTÀ verifica che il
//  multinsieme delle parole (token separati da spazi, come `str.split()` di Python) sia IDENTICO a quello di partenza;
//  se non lo è, il fusore NON restituisce nulla (`nil`): chi chiama tiene l'originale. Le operazioni portano solo id,
//  pagine, posizioni ed etichette: nessun testo entra dal modello (il testo dei verdetti serve SOLO ad ancorare, in
//  forma normalizzata, e non esce mai dal processo né dai referti).
//
//  GUARDIA-MARCATORE: un nodo NOTE il cui testo apre con un marcatore di nota (`N.`, `N)`, `(N)`, `[`…`]`, `*`, `†`,
//  `‡`) non viene MAI rietichettato o assorbito, qualunque cosa dica il modello.
//
//  FEDELTÀ AL PYTHON (verificata dalla rete del giro: letture identiche byte per byte ai casi del gate fusi dal
//  Python con gli stessi verdetti). Le funzioni d'ancoraggio riproducono la semantica di Python 3, che conta per
//  PUNTI DI CODICE, non per grafemi: `norm` = minuscolo (`str.lower`) e poi solo i punti di codice alfanumerici
//  (`str.isalnum`: lettere delle categorie L* o caratteri con un valore numerico Unicode); `words` = `str.split()`
//  sugli spazi di `str.isspace`; il marcatore = l'espressione `^\s*(?:\(?\d{1,4}[\).\]]|\*|†|‡)`; prefissi e
//  contenimento si calcolano su sequenze di punti di codice. Referti privi di testo.
//

import Foundation

// MARK: - I verdetti del modello

/// Un elemento del verdetto di una pagina (docling / Heron): etichetta, ordine di lettura, riquadro `[l, t, r, b]` in
/// punti con origine in alto a sinistra, e il testo delle righe che il post-processing gli ha assegnato. Il testo serve
/// SOLO all'ancoraggio (normalizzato) e non si scrive mai: resta in memoria.
public struct LayoutVerdictItem: Codable, Equatable, Sendable {
    public var label: String
    public var order: Int
    public var bbox: [Double]?
    public var text: String?

    public init(label: String, order: Int, bbox: [Double]?, text: String?) {
        self.label = label
        self.order = order
        self.bbox = bbox
        self.text = text
    }
}

/// I verdetti per pagina, con la pagina 1-based (come nel banco); `nil` = nessun verdetto per quella pagina.
public typealias FusoreVerdicts = (_ page1Based: Int) -> [LayoutVerdictItem]?

/// Una coppia di pagine (1-based) A → B.
public struct FusorePagePair: Equatable, Hashable, Sendable {
    public var a: Int
    public var b: Int
    public init(_ a: Int, _ b: Int) { self.a = a; self.b = b }
}

/// I fenomeni del banco (`casi.json`), con le loro pagine 1-based.
public enum FusorePhenomenon: Equatable, Sendable {
    /// Livello nodo: `caption` del modello su un nodo NOTE senza marcatore → BODY.
    case captionRelabel(pages: [Int])
    /// Livello nodo: nodo NOTE che ingloba una tabella (il testo di una nota del modello in posizione interna) → BODY.
    case tableNoteRelabel(pages: [Int])
    /// Livello nodo: pagine dove il modello non vede alcuna nota → i nodi NOTE senza marcatore → BODY.
    case sectorRelabelNoFootnote(pages: [Int])
    /// Livello nodo (sconsigliato dal banco): coda MULTIPAGE fusa nell'ultima NOTE di A.
    case multipageMerge(pairs: [FusorePagePair])
    /// Livello nodo (sconsigliato dal banco): tabella scorporata dalla nota-simbolo.
    case tableNoteSplit(pages: [Int])
    /// Livello estrazione: righe della coda MULTIPAGE spostate in coda alla pagina A.
    case multipageStitch(pairs: [FusorePagePair])
    /// Livello estrazione: righe della pagina riordinate secondo l'ordine di lettura del modello.
    case reorderPages(pages: [Int])
    /// Caso di controllo: nessuna operazione.
    case control
}

/// Un'operazione eseguita (priva di testo: id, pagine, posizioni, etichette).
public enum FusoreOperation: Equatable, Sendable {
    case relabel(node: String, from: String, to: String, reason: String)
    case merge(head: String, tail: String, reason: String)
    case split(node: String, atChar: Int, headType: String, tailType: String, minted: String, reason: String)
    case stitchMultipage(pageA: Int, pageB: Int, linesMoved: Int, fromIndex: Int)
    case reorderPage(page: Int, lines: Int, moved: Int)
}

/// L'esito di una fusione riuscita (rete di fedeltà verde).
public struct FusoreOutcome<Value> {
    public var value: Value
    public var operations: [FusoreOperation]
    /// Referto in prosa breve, PRIVO DI TESTO (pagine, id, conteggi).
    public var referto: [String]
    /// Parole del multinsieme controllato (identico prima e dopo).
    public var words: Int
}

public enum Fusore {

    // MARK: Semantica di Python, per punti di codice

    /// `str.isspace()` di Python: categoria Zs o classe bidirezionale WS/B/S (compresi U+001C…U+001F e U+0085).
    static func isPythonSpace(_ u: Unicode.Scalar) -> Bool {
        switch u.value {
        case 0x09...0x0D, 0x1C...0x20, 0x85, 0xA0, 0x1680, 0x2000...0x200A, 0x2028, 0x2029, 0x202F, 0x205F, 0x3000:
            return true
        default:
            return false
        }
    }

    /// `str.isalnum()` di Python su un punto di codice: lettera (Lu, Ll, Lt, Lm, Lo) o carattere con valore numerico.
    static func isPythonAlnum(_ u: Unicode.Scalar) -> Bool {
        switch u.properties.generalCategory {
        case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter:
            return true
        default:
            return u.properties.numericType != nil
        }
    }

    /// `ch.isdigit()` usato da `\d` nelle espressioni di Python: cifre decimali (categoria Nd).
    static func isPythonDecimalDigit(_ u: Unicode.Scalar) -> Bool {
        u.properties.generalCategory == .decimalNumber
    }

    /// `norm` del banco: minuscolo, poi i soli punti di codice alfanumerici. Usato SOLO per ancorare, mai per riscrivere.
    static func norm(_ s: String?) -> [Unicode.Scalar] {
        guard let s, !s.isEmpty else { return [] }
        return s.lowercased().unicodeScalars.filter(isPythonAlnum)
    }

    /// `words` del banco: `str.split()` (spazi di `str.isspace`, sequenze vuote scartate).
    static func words(_ s: String?) -> [Substring] {
        guard let s, !s.isEmpty else { return [] }
        var out: [Substring] = []
        var start: String.UnicodeScalarView.Index?
        let scalars = s.unicodeScalars
        var i = scalars.startIndex
        while i < scalars.endIndex {
            if isPythonSpace(scalars[i]) {
                if let st = start { out.append(Substring(scalars[st..<i])); start = nil }
            } else if start == nil {
                start = i
            }
            i = scalars.index(after: i)
        }
        if let st = start { out.append(Substring(scalars[st..<scalars.endIndex])) }
        return out
    }

    /// `str.strip()` di Python (spazi di `str.isspace`) restituisce stringa vuota?
    static func isBlank(_ s: String?) -> Bool {
        guard let s else { return true }
        return s.unicodeScalars.allSatisfy(isPythonSpace)
    }

    /// `MARKER_RE.match`: `^\s*(?:\(?\d{1,4}[\).\]]|\*|†|‡)`.
    static func opensWithMarker(_ s: String?) -> Bool {
        guard let s else { return false }
        let u = Array(s.unicodeScalars)
        var i = 0
        while i < u.count, isPythonSpace(u[i]) { i += 1 }
        guard i < u.count else { return false }
        if u[i] == "*" || u[i] == "†" || u[i] == "‡" { return true }
        if u[i] == "(", digitsThenCloser(u, from: i + 1) { return true }
        return digitsThenCloser(u, from: i)
    }

    /// Da `from`: 1-4 cifre decimali seguite da `)`, `.` o `]` (le cifre non sono nell'insieme dei chiusi: vale solo la
    /// corsa intera, come il ritorno all'indietro dell'espressione).
    private static func digitsThenCloser(_ u: [Unicode.Scalar], from start: Int) -> Bool {
        var j = start
        while j < u.count, isPythonDecimalDigit(u[j]) { j += 1 }
        let n = j - start
        guard n >= 1, n <= 4, j < u.count else { return false }
        return u[j] == ")" || u[j] == "." || u[j] == "]"
    }

    /// `needle in haystack` per sequenze di punti di codice (sottosequenza contigua; vuota = sempre vera).
    static func contains(_ haystack: [Unicode.Scalar], _ needle: ArraySlice<Unicode.Scalar>) -> Bool {
        if needle.isEmpty { return true }
        guard needle.count <= haystack.count else { return false }
        let first = needle.first!
        var i = 0
        let last = haystack.count - needle.count
        while i <= last {
            if haystack[i] == first, haystack[i..<(i + needle.count)].elementsEqual(needle) { return true }
            i += 1
        }
        return false
    }

    /// Indice della prima occorrenza (o `nil`).
    static func firstIndex(_ haystack: [Unicode.Scalar], _ needle: ArraySlice<Unicode.Scalar>) -> Int? {
        if needle.isEmpty { return 0 }
        guard needle.count <= haystack.count else { return nil }
        var i = 0
        let last = haystack.count - needle.count
        while i <= last {
            if haystack[i..<(i + needle.count)].elementsEqual(needle) { return i }
            i += 1
        }
        return nil
    }

    // MARK: Albero del documento (pre-ordine, come `iter_nodes`)

    /// I percorsi (indici) di ogni nodo, in pre-ordine.
    static func preorderPaths(_ structure: [NodeDict]) -> [[Int]] {
        var out: [[Int]] = []
        func walk(_ nodes: [NodeDict], _ prefix: [Int]) {
            for (i, n) in nodes.enumerated() {
                let p = prefix + [i]
                out.append(p)
                if !n.children.isEmpty { walk(n.children, p) }
            }
        }
        walk(structure, [])
        return out
    }

    static func node(at path: [Int], in structure: [NodeDict]) -> NodeDict {
        var nodes = structure
        var n = nodes[path[0]]
        for k in path.dropFirst() { nodes = n.children; n = nodes[k] }
        return n
    }

    static func modify(at path: [Int], in structure: inout [NodeDict], _ body: (inout NodeDict) -> Void) {
        if path.count == 1 { body(&structure[path[0]]); return }
        modify(at: Array(path.dropFirst()), in: &structure[path[0]].children, body)
    }

    /// Le liste di fratelli in cui sta `path` (per inserire o togliere).
    static func modifySiblings(of path: [Int], in structure: inout [NodeDict], _ body: (inout [NodeDict], Int) -> Void) {
        if path.count == 1 { body(&structure, path[0]); return }
        modifySiblings(of: Array(path.dropFirst()), in: &structure[path[0]].children, body)
    }

    /// `find_node`: il primo nodo con quell'id, in pre-ordine (visita in profondità che si ferma al primo).
    static func findPath(_ id: String, in structure: [NodeDict]) -> [Int]? {
        func walk(_ nodes: [NodeDict], _ prefix: [Int]) -> [Int]? {
            for (i, n) in nodes.enumerated() {
                if n.id == id { return prefix + [i] }
                if !n.children.isEmpty, let p = walk(n.children, prefix + [i]) { return p }
            }
            return nil
        }
        return walk(structure, [])
    }

    /// `nodes_on_page`: id dei nodi della pagina (1-based) dei tipi dati, in pre-ordine.
    static func nodeIdsOnPage(_ structure: [NodeDict], page: Int, types: Set<SemanticCategory>?) -> [String] {
        var out: [String] = []
        func walk(_ nodes: [NodeDict]) {
            for n in nodes {
                if n.page_index == page - 1, types.map({ $0.contains(n.type) }) ?? true { out.append(n.id) }
                if !n.children.isEmpty { walk(n.children) }
            }
        }
        walk(structure)
        return out
    }

    static func text(of id: String, in structure: [NodeDict]) -> String? {
        findPath(id, in: structure).flatMap { node(at: $0, in: structure).text }
    }

    /// `match_node_for_item`: il primo nodo il cui testo normalizzato contiene i primi 80 punti dell'item, o i cui
    /// primi 80 stanno nel testo dell'item (se lungo almeno `minLen`). Ancoraggio, mai copia.
    static func matchNode(_ candidateIds: [String], itemText: String?, in structure: [NodeDict], minLen: Int = 12) -> String? {
        let itemNorm = norm(itemText)
        let key = itemNorm.prefix(80)
        guard key.count >= minLen else { return nil }
        for id in candidateIds {
            let nt = norm(text(of: id, in: structure))
            if contains(nt, key) || (nt.count >= minLen && contains(itemNorm, nt.prefix(80))) {
                return id
            }
        }
        return nil
    }

    /// `find_norm_position`: posizione (in punti di codice del testo minuscolo, usata sul testo originale come nel banco)
    /// dove comincia il materiale il cui normalizzato apre con `key`.
    static func findNormPosition(_ text: String, _ key: ArraySlice<Unicode.Scalar>) -> Int? {
        guard !key.isEmpty else { return nil }
        let lowered = Array(text.lowercased().unicodeScalars)
        var compact: [Unicode.Scalar] = []
        var mapping: [Int] = []
        for (i, ch) in lowered.enumerated() where isPythonAlnum(ch) {
            compact.append(ch)
            mapping.append(i)
        }
        guard let j = firstIndex(compact, key) else { return nil }
        return mapping[j]
    }

    // MARK: Multinsieme delle parole (rete di fedeltà)

    static func documentWords(_ doc: ScabopdfDocument) -> [Substring: Int] {
        var c: [Substring: Int] = [:]
        for p in preorderPaths(doc.structure) {
            for w in words(node(at: p, in: doc.structure).text) { c[w, default: 0] += 1 }
        }
        return c
    }

    static func extractionWords(_ ex: PdfExtraction) -> [Substring: Int] {
        var c: [Substring: Int] = [:]
        for page in ex.pages { for line in page.lines { for span in line.spans { for w in words(span.text) { c[w, default: 0] += 1 } } } }
        return c
    }

    static func fidelity(_ before: [Substring: Int], _ after: [Substring: Int], _ referto: inout [String]) -> Bool {
        let total = before.values.reduce(0, +)
        if before == after {
            referto.append("rete di fedeltà: verde — \(total) parole, multinsieme identico (nessuna persa, nessuna fabbricata)")
            return true
        }
        var lost = 0, made = 0
        for (k, v) in before { lost += max(0, v - (after[k] ?? 0)) }
        for (k, v) in after { made += max(0, v - (before[k] ?? 0)) }
        referto.append("rete di fedeltà: ROTTA — \(lost) parole perse, \(made) fabbricate: la fusione non si applica")
        return false
    }

    // MARK: Fusione a livello di nodo

    /// Applica i fenomeni di livello nodo al documento grezzo (pre-aggancio). `nil` se la rete di fedeltà è rotta.
    public static func fuseDocument(_ doc: ScabopdfDocument, phenomena: [FusorePhenomenon],
                                    verdicts: FusoreVerdicts) -> FusoreOutcome<ScabopdfDocument>? {
        var d = doc
        var ops: [FusoreOperation] = []
        var referto: [String] = []
        let before = documentWords(doc)
        for phen in phenomena {
            switch phen {
            case .captionRelabel(let pages): deriveCaptionRelabels(&d, pages, verdicts, &ops, &referto)
            case .tableNoteRelabel(let pages): deriveTableNoteRelabels(&d, pages, verdicts, &ops, &referto)
            case .sectorRelabelNoFootnote(let pages): deriveSectorRelabels(&d, pages, verdicts, &ops, &referto)
            case .multipageMerge(let pairs): deriveMultipageMerges(&d, pairs, verdicts, &ops, &referto)
            case .tableNoteSplit(let pages): deriveTableNoteSplits(&d, pages, verdicts, &ops, &referto)
            case .control: referto.append("caso di controllo: nessuna operazione")
            case .multipageStitch, .reorderPages:
                referto.append("fenomeno di livello estrazione ignorato nell'innesto di livello nodo")
            }
        }
        guard fidelity(before, documentWords(d), &referto) else { return nil }
        return FusoreOutcome(value: d, operations: ops, referto: referto, words: before.values.reduce(0, +))
    }

    static func relabel(_ d: inout ScabopdfDocument, _ id: String, to: SemanticCategory, reason: String, _ ops: inout [FusoreOperation]) {
        guard let p = findPath(id, in: d.structure) else { return }
        var from = ""
        modify(at: p, in: &d.structure) { n in
            from = n.type.rawValue
            n.type = to
            if to != .NOTE { n.length_category = nil }
        }
        ops.append(.relabel(node: id, from: from, to: to.rawValue, reason: reason))
    }

    static func deriveCaptionRelabels(_ d: inout ScabopdfDocument, _ pages: [Int], _ verdicts: FusoreVerdicts,
                                      _ ops: inout [FusoreOperation], _ referto: inout [String]) {
        var n = 0
        for page in pages {
            guard let items = verdicts(page) else { referto.append("pagina \(page): nessun verdetto, salto"); continue }
            let noteIds = nodeIdsOnPage(d.structure, page: page, types: [.NOTE])
            for it in items where it.label == "caption" {
                guard let id = matchNode(noteIds, itemText: it.text ?? "", in: d.structure) else { continue }
                if opensWithMarker(text(of: id, in: d.structure)) {
                    referto.append("pagina \(page): guardia-marcatore protegge il nodo \(id) (il modello lo dice didascalia, ma apre con un marcatore di nota)")
                    continue
                }
                relabel(&d, id, to: .BODY, reason: "modello:caption p.\(page)", &ops)
                n += 1
            }
        }
        referto.append("didascalie rietichettate NOTE→BODY: \(n)")
    }

    static func deriveSectorRelabels(_ d: inout ScabopdfDocument, _ pages: [Int], _ verdicts: FusoreVerdicts,
                                     _ ops: inout [FusoreOperation], _ referto: inout [String]) {
        var n = 0, skipped = 0
        for page in pages {
            guard let items = verdicts(page) else { skipped += 1; continue }
            if items.contains(where: { $0.label == "footnote" }) { continue }   // la pagina ha note vere: non si tocca
            for id in nodeIdsOnPage(d.structure, page: page, types: [.NOTE]) {
                if opensWithMarker(text(of: id, in: d.structure)) {
                    referto.append("pagina \(page): guardia-marcatore protegge \(id)")
                    continue
                }
                relabel(&d, id, to: .BODY, reason: "modello:zero-footnote p.\(page)", &ops)
                n += 1
            }
        }
        if skipped > 0 { referto.append("pagine senza verdetto (saltate): \(skipped)") }
        referto.append("nodi NOTE rietichettati BODY su pagine senza note: \(n)")
    }

    static func deriveTableNoteRelabels(_ d: inout ScabopdfDocument, _ pages: [Int], _ verdicts: FusoreVerdicts,
                                        _ ops: inout [FusoreOperation], _ referto: inout [String]) {
        var n = 0
        for page in pages {
            guard let items = verdicts(page), items.contains(where: { $0.label == "table" }) else { continue }
            let footTexts = items.filter { $0.label == "footnote" && !isBlank($0.text) }.map { $0.text ?? "" }
            for id in nodeIdsOnPage(d.structure, page: page, types: [.NOTE]) {
                let t = text(of: id, in: d.structure) ?? ""
                if opensWithMarker(t) { continue }
                var inner = false
                for ft in footTexts {
                    if let pos = findNormPosition(t, norm(ft).prefix(40)), pos > 0 { inner = true; break }
                }
                if inner {
                    relabel(&d, id, to: .BODY, reason: "modello:table+footnote p.\(page)", &ops)
                    n += 1
                }
            }
        }
        referto.append("nodi tabellari rietichettati BODY: \(n)")
    }

    static func deriveTableNoteSplits(_ d: inout ScabopdfDocument, _ pages: [Int], _ verdicts: FusoreVerdicts,
                                      _ ops: inout [FusoreOperation], _ referto: inout [String]) {
        var n = 0
        for page in pages {
            guard let items = verdicts(page), items.contains(where: { $0.label == "table" }) else { continue }
            let noteIds = nodeIdsOnPage(d.structure, page: page, types: [.NOTE])
            for it in items where it.label == "footnote" && !isBlank(it.text) {
                guard let id = matchNode(noteIds, itemText: it.text, in: d.structure) else { continue }
                let t = text(of: id, in: d.structure) ?? ""
                let scal = Array(t.unicodeScalars)
                guard let pos = findNormPosition(t, norm(it.text).prefix(40)), pos != 0 else { continue }
                var b = pos
                while b > 0, !isPythonSpace(scal[b - 1]) { b -= 1 }
                // testa fino a b senza spazi finali (`rstrip`)
                var headEnd = b
                while headEnd > 0, isPythonSpace(scal[headEnd - 1]) { headEnd -= 1 }
                let headSoFar = scal[0..<headEnd]
                for sym in ["*", "†", "‡"] as [Unicode.Scalar] where headSoFar.last == sym {
                    b = headSoFar.count - 1
                    break
                }
                if b == 0 { continue }
                split(&d, id, atScalar: b, head: .BODY, tail: .NOTE, reason: "modello:table+footnote p.\(page)", &ops)
                n += 1
            }
        }
        referto.append("tabelle scorporate dalle note (scissione): \(n)")
    }

    static func split(_ d: inout ScabopdfDocument, _ id: String, atScalar at: Int, head: SemanticCategory, tail: SemanticCategory,
                      reason: String, _ ops: inout [FusoreOperation]) {
        guard let p = findPath(id, in: d.structure) else { return }
        let n = node(at: p, in: d.structure)
        let scal = Array((n.text ?? "").unicodeScalars)
        guard at > 0, at < scal.count, isPythonSpace(scal[at - 1]) || isPythonSpace(scal[at]) else { return }
        var he = at
        while he > 0, isPythonSpace(scal[he - 1]) { he -= 1 }
        var ts = at
        while ts < scal.count, isPythonSpace(scal[ts]) { ts += 1 }
        let headText = String(String.UnicodeScalarView(scal[0..<he]))
        let tailText = String(String.UnicodeScalarView(scal[ts...]))
        var tailNode = n
        tailNode.id = n.id + "_uf1"
        tailNode.text = tailText
        tailNode.type = tail
        tailNode.children = []
        if tail != .NOTE { tailNode.length_category = nil }
        modify(at: p, in: &d.structure) { x in
            x.text = headText
            x.type = head
            if head != .NOTE { x.length_category = nil }
        }
        modifySiblings(of: p, in: &d.structure) { sib, i in sib.insert(tailNode, at: i + 1) }
        ops.append(.split(node: id, atChar: at, headType: head.rawValue, tailType: tail.rawValue, minted: tailNode.id, reason: reason))
    }

    /// Il primo elemento `footnote` non vuoto della pagina decide: se NON apre con un marcatore è la coda orfana.
    static func multipageTail(_ items: [LayoutVerdictItem]) -> LayoutVerdictItem? {
        for it in items where it.label == "footnote" && !isBlank(it.text) {
            return opensWithMarker(it.text) ? nil : it
        }
        return nil
    }

    static func deriveMultipageMerges(_ d: inout ScabopdfDocument, _ pairs: [FusorePagePair], _ verdicts: FusoreVerdicts,
                                      _ ops: inout [FusoreOperation], _ referto: inout [String]) {
        var n = 0
        for pair in pairs {
            guard let itemsB = verdicts(pair.b) else { referto.append("pagine \(pair.a)-\(pair.b): nessun verdetto"); continue }
            guard let tailItem = multipageTail(itemsB) else {
                referto.append("pagine \(pair.a)-\(pair.b): il primo elemento di nota di B apre con un marcatore o manca → nessuna coda da ricucire")
                continue
            }
            guard let tailId = matchNode(nodeIdsOnPage(d.structure, page: pair.b, types: [.NOTE]), itemText: tailItem.text, in: d.structure),
                  !opensWithMarker(text(of: tailId, in: d.structure)) else {
                referto.append("pagine \(pair.a)-\(pair.b): coda non trovata nel documento o protetta dalla guardia-marcatore")
                continue
            }
            let heads = nodeIdsOnPage(d.structure, page: pair.a, types: [.NOTE])
            guard let headId = heads.last else { referto.append("pagine \(pair.a)-\(pair.b): nessuna NOTE su A"); continue }
            guard let hp = findPath(headId, in: d.structure), let tp = findPath(tailId, in: d.structure),
                  node(at: tp, in: d.structure).children.isEmpty else {
                referto.append("pagine \(pair.a)-\(pair.b): la coda ha figli, rifiuto")
                continue
            }
            let tailText = node(at: tp, in: d.structure).text ?? ""
            modify(at: hp, in: &d.structure) { h in h.text = (h.text ?? "") + " " + tailText }
            if let tp2 = findPath(tailId, in: d.structure) {
                modifySiblings(of: tp2, in: &d.structure) { sib, i in sib.remove(at: i) }
            }
            ops.append(.merge(head: headId, tail: tailId, reason: "modello:multipage p.\(pair.a)->\(pair.b)"))
            n += 1
            referto.append("pagine \(pair.a)-\(pair.b): coda ricucita in \(headId)")
        }
        referto.append("note MULTIPAGE ricucite: \(n)")
    }

    // MARK: Fusione a livello d'estrazione

    /// Applica i fenomeni di livello estrazione. `nil` se la rete di fedeltà è rotta.
    public static func fuseExtraction(_ ex: PdfExtraction, phenomena: [FusorePhenomenon],
                                      verdicts: FusoreVerdicts) -> FusoreOutcome<PdfExtraction>? {
        var e = ex
        var ops: [FusoreOperation] = []
        var referto: [String] = []
        let before = extractionWords(ex)
        for phen in phenomena {
            switch phen {
            case .multipageStitch(let pairs): stitchMultipage(&e, pairs, verdicts, &ops, &referto)
            case .reorderPages(let pages): reorderPages(&e, pages, verdicts, &ops, &referto)
            case .control: referto.append("caso di controllo: nessuna operazione")
            default: referto.append("fenomeno di livello nodo ignorato nell'innesto di livello estrazione")
            }
        }
        guard fidelity(before, extractionWords(e), &referto) else { return nil }
        return FusoreOutcome(value: e, operations: ops, referto: referto, words: before.values.reduce(0, +))
    }

    static func lineNorm(_ line: PdfTextLine) -> [Unicode.Scalar] {
        norm(line.spans.map { $0.text }.joined(separator: " "))
    }

    static func stitchMultipage(_ e: inout PdfExtraction, _ pairs: [FusorePagePair], _ verdicts: FusoreVerdicts,
                                _ ops: inout [FusoreOperation], _ referto: inout [String]) {
        var n = 0
        for pair in pairs {
            guard let itemsB = verdicts(pair.b) else { referto.append("pagine \(pair.a)-\(pair.b): nessun verdetto"); continue }
            guard let tailItem = multipageTail(itemsB) else {
                referto.append("pagine \(pair.a)-\(pair.b): primo elemento di nota di B con marcatore o assente → niente da ricucire")
                continue
            }
            // `by_index`: l'ultima pagina con quell'indice (come il dizionario del banco).
            guard let ia = e.pages.lastIndex(where: { $0.pageIndex == pair.a - 1 }),
                  let ib = e.pages.lastIndex(where: { $0.pageIndex == pair.b - 1 }) else { continue }
            let itemNorm = norm(tailItem.text)
            var start: Int?, end: Int?
            for (i, line) in e.pages[ib].lines.enumerated() {
                let lt = lineNorm(line)
                if lt.count >= 10 && contains(itemNorm, lt[...]) {
                    if start == nil { start = i }
                    end = i
                } else if start != nil {
                    break
                }
            }
            guard let s = start, let en = end else {
                referto.append("pagine \(pair.a)-\(pair.b): righe della coda non trovate nell'estrazione")
                continue
            }
            let moved = Array(e.pages[ib].lines[s...en])
            e.pages[ib].lines.removeSubrange(s...en)
            e.pages[ia].lines.append(contentsOf: moved)
            n += 1
            ops.append(.stitchMultipage(pageA: pair.a, pageB: pair.b, linesMoved: moved.count, fromIndex: s))
            referto.append("pagine \(pair.a)-\(pair.b): \(moved.count) righe della coda spostate in coda alla pagina \(pair.a)")
        }
        referto.append("ricuciture MULTIPAGE (estrazione): \(n)")
    }

    static func reorderPages(_ e: inout PdfExtraction, _ pages: [Int], _ verdicts: FusoreVerdicts,
                             _ ops: inout [FusoreOperation], _ referto: inout [String]) {
        var totalMoved = 0
        for page in pages {
            guard let ip = e.pages.lastIndex(where: { $0.pageIndex == page - 1 }) else { continue }
            guard let items = verdicts(page), !items.isEmpty else {
                referto.append("pagina \(page): nessun verdetto, non riordino")
                continue
            }
            let boxes = items.compactMap { it -> (Int, [Double])? in
                guard let b = it.bbox, b.count == 4 else { return nil }
                return (it.order, b)
            }
            if boxes.isEmpty { continue }
            let H = e.pages[ip].height
            func key(_ line: PdfTextLine) -> (Int, Double, Double) {
                let x = line.bbox.x, y = line.bbox.y, w = line.bbox.width, h = line.bbox.height
                let cx = x + w / 2
                let top = H - (y + h)
                let cy = top + h / 2
                var best: Int?, bestd: Double?
                for (order, b) in boxes {
                    let (l, t, r, bo) = (b[0], b[1], b[2], b[3])
                    if l <= cx, cx <= r, t <= cy, cy <= bo { return (order, top, x) }
                    let dx = max(l - cx, 0, cx - r)
                    let dy = max(t - cy, 0, cy - bo)
                    let dd = dx * dx + dy * dy
                    if bestd == nil || dd < bestd! { best = order; bestd = dd }
                }
                return (best ?? 0, top, x)
            }
            let original = e.pages[ip].lines
            let keyed = original.enumerated().map { (i: $0.offset, k: key($0.element)) }
            // Ordinamento STABILE come `sorted` di Python: a parità di chiave conta l'ordine originale.
            let order = keyed.sorted { a, b in
                if a.k.0 != b.k.0 { return a.k.0 < b.k.0 }
                if a.k.1 != b.k.1 { return a.k.1 < b.k.1 }
                if a.k.2 != b.k.2 { return a.k.2 < b.k.2 }
                return a.i < b.i
            }.map { $0.i }
            e.pages[ip].lines = order.map { original[$0] }
            let moved = order.enumerated().filter { $0.offset != $0.element }.count
            if moved > 0 {
                totalMoved += moved
                ops.append(.reorderPage(page: page, lines: original.count, moved: moved))
            }
        }
        referto.append("righe ricollocate dal riordino: \(totalMoved)")
    }
}
