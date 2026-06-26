//
//  UserNotesPlugin.swift
//  ScaboCore
//
//  Ramo "appunti e dispense" generati dall'utente (campioni di calibrazione: gli
//  export Google Docs "Appunti Teoria generale", "Istituzioni privato II", "Diritto
//  processuale civile vol. 3", "Voce Imprenditore EdD").
//
//  ── Perché un ramo separato e non il tronco ─────────────────────────────────────
//
//  È il primo ramo dell'albero, modello del metodo "ramo separato = pacchetto di foglie
//  attivabili". Il generic (tronco) resta byte-identico per tutti gli altri volumi: questo
//  ramo è un percorso a sé, montato nel dispatcher, che si attiva SOLO sulla firma-producer
//  auto-dichiarante (Google Docs). Sul materiale-utente non servono né la macchina delle
//  note né il cerotto anti-"Nota." — gli appunti non hanno apparato — quindi non si
//  accendono: il `profile_id` è "user_notes", non "generic", così `suppressCollapsedHeading-
//  NoteIntros` (gated su "generic") non scatta per costruzione, e gli appunti non hanno nodi
//  NOTE, quindi `bindAndPlaceNotes` esce subito (guardia no-NOTE) e li lascia intatti.
//
//  ── La porta (`matches`) ─────────────────────────────────────────────────────────
//
//  Firma ROBUSTA, auto-dichiarante: l'esportatore Google Docs si nomina nel `producer`
//  ("Skia/PDF … Google Docs Renderer"). Sul corpus di calibrazione (38 volumi) "Google Docs"
//  compare SOLO nei quattro appunti → zero falsi positivi. Non è un asse geometrico fragile
//  (l'errore Cortina): il gate è la stringa del produttore; la geometria A4 è corroborazione
//  additiva, non necessaria (un export Google Docs di altro formato resterebbe sopra soglia).
//  I documenti Microsoft Word (l'altro membro della famiglia-utente) NON entrano in questo
//  ramo per ora — "Diritto società quotate" porta i commenti di revisione Word, una decisione
//  di prodotto a parte — quindi la porta è volutamente ristretta a "Google Docs".
//
//  ── La foglia delle intestazioni (`userNotesHeadingLevel`, livello RIGA) ─────────
//
//  Gli appunti sono monoculture (Arial corpo piatto): il classificatore size-only li manda
//  tutti in BODY (un nodo per pagina), quindi le intestazioni vere ("PARTE PRIMA – …",
//  "CAP. 2 – …", "Sezione Terza – …") restano SEPOLTE nel BODY-pagina e non c'è navigazione
//  da rotore. Non avendo firma tipografica, la foglia riconosce l'intestazione dal PATTERN
//  TESTUALE a livello riga: keyword Capitalizzata (PARTE/CAPITOLO/CAPO/SEZIONE/TITOLO/LIBRO,
//  o "CAP.") + ordinale (parola/cifra/romano) + " – titolo". È una foglia di FAMIGLIA, non
//  una regola per un volume: riconosce la struttura ovunque comparirà.
//
//  Precisione prima del recall (stella polare): promuovere una riga di corpo a titolo
//  sporca, mancarne uno no. Le guardie danno zero falsi positivi sui quattro appunti, incluse
//  le trappole reali stressate nell'indagine: gli ordinali romani che sono parole italiane
//  ("parte DI debito" → DI romani; "parte IL separato" → IL romani) sono esclusi perché la
//  keyword è minuscola e/o manca il " – titolo"; le citazioni con virgola ("Libro IV, Titolo
//  III, …") perché dopo l'ordinale c'è una virgola, non il trattino; "Parte seconda." perché
//  c'è il punto, non il trattino. Fuori scope per ora (segnale più ambiguo, da discutere):
//  intestazioni senza titolo (keyword+ordinale+fine-riga, oggi assenti) e gli outline decimali
//  / sezioni numerate ("3. I compiti…"), indistinguibili da un elenco col solo pattern.
//
//  ── Le reti ────────────────────────────────────────────────────────────────────
//
//  Rete A: una riga promossa a intestazione resta letta, cambia solo ruolo (BODY→HEADING_n);
//  nessuna lettera persa. Rete B: il tronco non è toccato (il ramo riusa le funzioni pure del
//  Generic — `pageItems`, `detectFurniture`, … — senza modificarle), e i volumi non-utente non
//  entrano nel ramo (porta a 0) → restano byte-identici. Lo split di un run BODY in
//  BODY|HEADING|BODY cambia il conteggio nodi-per-pagina, ma è sicuro QUI perché gli appunti
//  non hanno NOTE: `bindAndPlaceNotes` esce subito (guardia no-NOTE) e non fa mai lo zip.
//

import Foundation

// MARK: - La foglia delle intestazioni (livello riga, di famiglia)

/// Keyword di struttura Capitalizzata + ordinale + " – titolo". Case-insensitive nel
/// pattern, ma il chiamante impone la Capitalizzazione della keyword (prima lettera
/// maiuscola) per escludere la prosa di corpo ("parte di…", "titolo di…"). Il requisito
/// del trattino-titolo dopo l'ordinale esclude citazioni con virgola e "X seconda." col punto.
private let USER_HEADING_REGEX = try! NSRegularExpression(
    pattern: "^(PARTE|CAPITOLO|CAPO|SEZIONE|TITOLO|LIBRO|CAP\\.)\\s+"
        + "(?:PRIMO|PRIMA|SECONDO|SECONDA|TERZO|TERZA|QUARTO|QUARTA|QUINTO|QUINTA|SESTO|SESTA"
        + "|SETTIMO|SETTIMA|OTTAVO|OTTAVA|NONO|NONA|DECIMO|DECIMA|UNDICESIMO|UNDICESIMA"
        + "|DODICESIMO|DODICESIMA|UNICO|UNICA|[IVXLCDM]{1,5}|\\d{1,3})"
        + "\\s+[–—-]\\s+\\S",
    options: [.caseInsensitive])

/// Lunghezza massima di una riga-intestazione (le intestazioni sono corte; oltre, è prosa).
let USER_HEADING_MAX_LEN = 80

/// Livello HEADING se `text` è un'intestazione di struttura da appunto (keyword Capitalizzata
/// + ordinale + " – titolo"), altrimenti nil. LIBRO/PARTE/TITOLO → 1, CAPITOLO/CAPO/CAP. → 2,
/// SEZIONE → 3. Deterministica; precisione prima del recall.
func userNotesHeadingLevel(_ text: String) -> Int? {
    let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard t.count <= USER_HEADING_MAX_LEN, t.first?.isUppercase == true else { return nil }
    let ns = t as NSString
    guard let m = USER_HEADING_REGEX.firstMatch(in: t, range: NSRange(location: 0, length: ns.length))
    else { return nil }
    switch ns.substring(with: m.range(at: 1)).uppercased() {
    case "PARTE", "LIBRO", "TITOLO": return 1
    case "SEZIONE": return 3
    default: return 2  // CAPITOLO, CAPO, CAP.
    }
}

// MARK: - Il plugin (ramo)

public final class UserNotesPlugin: ExtractionPlugin {
    public let id = "user_notes"
    public let label = "Appunti e dispense (utente)"

    // MARK: matches

    public func matches(_ extraction: PdfExtraction) -> Double {
        // Gate auto-dichiarante: l'esportatore Google Docs si nomina nel producer/creator.
        let meta = ((extraction.producer ?? "") + " " + (extraction.creator ?? "")).lowercased()
        guard meta.contains("google docs") else { return 0.0 }
        var score = 0.7
        // Corroborazione A4 (additiva, non gate): alza la confidenza dove c'è.
        if let p = extraction.pages.first,
           abs(p.width - 595.5) <= 6.0, abs(p.height - 841.5) <= 6.0 {
            score += 0.3
        }
        return score
    }

    // MARK: build

    public func build(_ extraction: PdfExtraction, sourceName: String) -> ScabopdfDocument {
        let profile = estimateProfile(extraction)
        let furniture = detectFurniture(extraction)
        let fmMax = frontMatterRegionLimit(extraction.pageCount)
        let apparatus = detectApparatus(extraction, furniture)
        var nodes: [NodeDict] = []
        var counter = 0
        func nextId() -> String { defer { counter += 1 }; return "node_\(counter)" }
        var promoted = 0
        for page in extraction.pages {
            promoted += emitPageNodes(page, profile, furniture, fmMax, apparatus, &nodes, nextId)
        }
        return assembleDocument(
            extraction, sourceName: sourceName, nodes: nodes, profile: profile,
            furnitureCount: furniture.count, promotedHeadings: promoted)
    }

    public func build(
        _ extraction: PdfExtraction,
        sourceName: String,
        onPageClassified: (_ done: Int, _ total: Int) -> Void,
        isCancelled: () -> Bool
    ) -> ScabopdfDocument? {
        if isCancelled() { return nil }
        let profile = estimateProfile(extraction)
        if isCancelled() { return nil }
        let furniture = detectFurniture(extraction)
        if isCancelled() { return nil }
        let apparatus = detectApparatus(extraction, furniture)
        if isCancelled() { return nil }
        let fmMax = frontMatterRegionLimit(extraction.pageCount)
        var nodes: [NodeDict] = []
        var counter = 0
        func nextId() -> String { defer { counter += 1 }; return "node_\(counter)" }
        var promoted = 0
        let total = extraction.pages.count
        for (index, page) in extraction.pages.enumerated() {
            if isCancelled() { return nil }
            promoted += emitPageNodes(page, profile, furniture, fmMax, apparatus, &nodes, nextId)
            onPageClassified(index + 1, total)
        }
        if isCancelled() { return nil }
        return assembleDocument(
            extraction, sourceName: sourceName, nodes: nodes, profile: profile,
            furnitureCount: furniture.count, promotedHeadings: promoted)
    }

    // MARK: - Emissione dei nodi di una pagina (Generic + foglia intestazioni line-level)

    /// Emette i nodi di una pagina da `pageItems` (la STESSA itemizzazione del Generic).
    /// L'unica differenza: un run di CORPO viene SPEZZATO alle righe-intestazione
    /// (`userNotesHeadingLevel`) → BODY | HEADING_n | BODY, così l'intestazione, oggi sepolta
    /// nel BODY-pagina degli appunti monoculture, diventa un confine navigabile. Ritorna il
    /// numero di intestazioni promosse (per il warning diagnostico).
    private func emitPageNodes(
        _ page: PdfPageExtraction,
        _ profile: Profile,
        _ furniture: Set<String>,
        _ frontMatterMaxPage: Int,
        _ apparatus: [Int: SemanticCategory],
        _ out: inout [NodeDict],
        _ nextId: () -> String
    ) -> Int {
        let items = pageItems(page, profile, furniture, frontMatterMaxPage, apparatus)
        var promoted = 0
        for item in items {
            switch item {
            case .heading(let sm, let level):
                out.append(NodeDict(
                    id: nextId(), type: userHeadingCategory(level),
                    page_index: page.pageIndex, text: sm.text, level: level))
            case .run(.body, let lines):
                var bodyAcc: [String] = []
                func flushBody() {
                    guard !bodyAcc.isEmpty else { return }
                    out.append(NodeDict(
                        id: nextId(), type: .BODY, page_index: page.pageIndex,
                        text: joinLines(bodyAcc)))
                    bodyAcc = []
                }
                for line in lines {
                    if let level = userNotesHeadingLevel(line.text) {
                        flushBody()
                        out.append(NodeDict(
                            id: nextId(), type: userHeadingCategory(level),
                            page_index: page.pageIndex,
                            text: line.text.trimmingCharacters(in: .whitespacesAndNewlines),
                            level: level))
                        promoted += 1
                    } else {
                        bodyAcc.append(line.text)
                    }
                }
                flushBody()
            case .run(.note, let lines):
                // Difensivo: gli appunti non hanno note; se comparissero, emesse come il Generic.
                let text = joinLines(lines.map { $0.text })
                var node = NodeDict(id: nextId(), type: .NOTE, page_index: page.pageIndex, text: text)
                node.length_category = lengthCategoryFor(text)
                out.append(node)
            case .run(.gloss, let lines):
                out.append(NodeDict(
                    id: nextId(), type: .MARGINAL_GLOSS, page_index: page.pageIndex,
                    text: joinLines(lines.map { $0.text })))
            case .apparatus(let category, let lines):
                out.append(NodeDict(
                    id: nextId(), type: category, page_index: page.pageIndex,
                    text: joinLines(lines.map { $0.text })))
            }
        }
        return promoted
    }

    // MARK: - Assemblaggio documento

    private func assembleDocument(
        _ extraction: PdfExtraction,
        sourceName: String,
        nodes: [NodeDict],
        profile: Profile,
        furnitureCount: Int,
        promotedHeadings: Int
    ) -> ScabopdfDocument {
        var warnings = [
            "plugin:user_notes:heuristic_extraction_pages_\(extraction.pageCount)_nodes_\(nodes.count)",
        ]
        if profile.bodySize == 0 {
            warnings.append("plugin:user_notes:no_font_information_all_body")
        }
        if furnitureCount > 0 {
            warnings.append("plugin:user_notes:furniture_lines_removed_\(furnitureCount)")
        }
        if promotedHeadings > 0 {
            warnings.append("plugin:user_notes:headings_promoted_\(promotedHeadings)")
        }
        return ScabopdfDocument(
            schema_version: SUPPORTED_SCHEMA_VERSION,
            document_id: slug(sourceName),
            metadata: DocumentMetadata(
                pages_pdf: extraction.pageCount,
                page_size_pt: [0, 0],
                source_pdf_filename: sourceName
            ),
            profile: DocumentProfileDict(
                profile_id: "user_notes",
                editorial_family: "user_generated",
                genre: "appunti",
                confidence: matches(extraction)
            ),
            warnings: warnings,
            transformations: [],
            structure: nodes
        )
    }
}

/// Il singleton del plugin (l'identità conta per il dispatcher `===`).
public let userNotesPlugin = UserNotesPlugin()

/// Categoria HEADING per livello (file-scope private, gemello di quelli di Generic/Cortina).
private func userHeadingCategory(_ level: Int) -> SemanticCategory {
    switch level {
    case 1: return .HEADING_1
    case 2: return .HEADING_2
    case 3: return .HEADING_3
    default: return .HEADING_4
    }
}
