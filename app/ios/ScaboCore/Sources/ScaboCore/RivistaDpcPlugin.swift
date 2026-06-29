//
//  RivistaDpcPlugin.swift
//  ScaboCore
//
//  Ramo "Riviste" — porta DPC (Diritto Penale Contemporaneo), fascicolo a colonna
//  singola dell'editore Associazione "Progetto giustizia penale" (campioni di
//  calibrazione: fascicoli 2-2018 e 4-2020). Pipeline editoriale Adobe InDesign CC →
//  Adobe PDF Library 15, font ACaslonPro, formato 567×814 pt.
//
//  ── Perché un ramo dedicato e non il Generic ─────────────────────────────────────
//
//  L'apparato di note a piè della DPC SPORGE nel margine sinistro: l'indent della nota
//  (x0 ≈ 77) sta a SINISTRA del bordo del corpo (x0 ≈ 154). Le note CORTE (il cui bordo
//  destro x1 cade a sinistra del corpo) risultano "fuori colonna" al test-glossa
//  size-only del Generic → classificate `MARGINAL_GLOSS` → ESCLUSE dalla lettura
//  (NON_READ_ROLES). È l'unico difetto del ramo che TOGLIE contenuto: la verifica
//  pagina-per-pagina (metro PyMuPDF + lettura) conta ~130 nodi-nota persi sul 2-2018 e
//  ~90 sul 4-2020, non letti da nessuna parte. Invisibile all'orecchio (il cerotto
//  anti-"Nota." zittisce la categoria), ma è perdita reale di apparato.
//
//  La RADICE non è "due colonne" (il corpo della DPC è a colonna SINGOLA: corpo
//  x0≈154→x1≈527; la diagnosi vecchia "due colonne" è stata falsificata dalla misura
//  fresca): è il RIENTRO-NOTA a sinistra. Il recupero è geometrico e a monte — una riga
//  taglia-nota SOTTO il blocco-corpo è apparato-note per costruzione (le glosse genuine
//  della DPC — l'etichetta "Sommario" verticale, i titoli di sezione bilingui — stanno
//  in ALTO) → `pageItems` la classifica `.note` quando `profile.isRivistaDpc`. Vedi il
//  recupero gated in `GenericPlugin.pageItems` e `docs/NOTES_BINDING.md`.
//
//  ── La porta (`matches`) ─────────────────────────────────────────────────────────
//
//  Gate sulla geometria 567×814 (UNIVOCA nel corpus: nessun altro volume la ha; gli
//  altri InDesign sono a 457×684 / 454×694 / 485×703) corroborata dal corpo ≈10pt. È
//  esattamente il flag `Profile.isRivistaDpc` calcolato da `estimateProfile`, così
//  porta e recupero hanno un'UNICA sorgente di verità (impossibile che divergano).
//  Fail-safe come ogni ramo: dove la porta è falsa → Generic, byte-identico, nessuna
//  regressione (l'Estratto — Acrobat/Times — e i manuali non la sfiorano per
//  costruzione). On-device il nome-font non è affidabile (PDFKit→Helvetica): per questo
//  la firma è geometrica, non tipografica — come la porta Cortina.
//
//  ── Il build ─────────────────────────────────────────────────────────────────────
//
//  Identico al Generic (stessi `estimateProfile`/`detectFurniture`/`appendPageNodes`/
//  riclassificazioni), tranne il profile_id "rivista_dpc" e il flag di profilo che
//  attiva il recupero zona-piè dentro `pageItems`. Poiché `bindAndPlaceNotes` ri-stima
//  il profilo via `estimateProfile` (e quindi vede lo stesso flag), le note recuperate
//  sono splittate e agganciate dal binder come qualunque altra nota: niente percorso
//  speciale, niente NoteBinding da toccare.
//
//  ── Le reti ──────────────────────────────────────────────────────────────────────
//
//  Rete A (PROVA REGINA, è una perdita di contenuto): le note prima in `MARGINAL_GLOSS`
//  (non lette) diventano `NOTE` (lette, in posizione o piazzate al richiamo); nessun
//  token sparisce. Rete B: ogni volume non-DPC ha `isRivistaDpc == false` → `pageItems`
//  byte-identico → Generic, Cortina, DeJure, user_notes e l'Estratto invariati per
//  costruzione.
//

import Foundation

/// Confidenza assegnata quando la porta DPC è soddisfatta (sopra `DISPATCH_THRESHOLD`).
let RIVISTA_DPC_CONFIDENCE = 0.8

public final class RivistaDpcPlugin: ExtractionPlugin {
    public let id = "rivista_dpc"
    public let label = "Rivista (Diritto Penale Contemporaneo)"

    // MARK: matches

    public func matches(_ extraction: PdfExtraction) -> Double {
        // La porta È il flag `isRivistaDpc` (geometria 567×814 + corpo ≈10pt), unica
        // sorgente di verità condivisa con il recupero in `pageItems`.
        estimateProfile(extraction).isRivistaDpc ? RIVISTA_DPC_CONFIDENCE : 0.0
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
        for page in extraction.pages {
            appendPageNodes(page, profile, furniture, fmMax, apparatus, &nodes, nextId)
        }
        return assembleDocument(
            extraction, sourceName: sourceName, nodes: nodes, profile: profile,
            furnitureCount: furniture.count)
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
        let total = extraction.pages.count
        for (index, page) in extraction.pages.enumerated() {
            if isCancelled() { return nil }
            appendPageNodes(page, profile, furniture, fmMax, apparatus, &nodes, nextId)
            onPageClassified(index + 1, total)
        }
        if isCancelled() { return nil }
        return assembleDocument(
            extraction, sourceName: sourceName, nodes: nodes, profile: profile,
            furnitureCount: furniture.count)
    }

    // MARK: - Assemblaggio (gemello del Generic, profile_id "rivista_dpc")

    private func assembleDocument(
        _ extraction: PdfExtraction,
        sourceName: String,
        nodes: [NodeDict],
        profile: Profile,
        furnitureCount: Int
    ) -> ScabopdfDocument {
        var nodes = nodes
        let reclass = reclassifyCleanFamilies(&nodes)
        // No-op sulla DPC (gated isEstrattoChrome=false): incluso per parità col Generic.
        let runningHeaders = reclassifyEstrattoRunningHeaders(&nodes, profile)
        let noteCount = nodes.reduce(0) { $0 + ($1.type == .NOTE ? 1 : 0) }
        let glossCount = nodes.reduce(0) { $0 + ($1.type == .MARGINAL_GLOSS ? 1 : 0) }
        var warnings = [
            "plugin:rivista_dpc:heuristic_extraction_pages_\(extraction.pageCount)_nodes_\(nodes.count)",
            "plugin:rivista_dpc:footnote_apparatus_notes_\(noteCount)_residual_gloss_\(glossCount)",
        ]
        if reclass.summary + reclass.heading > 0 {
            warnings.append(
                "plugin:rivista_dpc:reclassified_chapter_summary_\(reclass.summary)_structure_heading_\(reclass.heading)")
        }
        if runningHeaders > 0 {
            warnings.append("plugin:rivista_dpc:running_headers_reclassified_\(runningHeaders)")
        }
        if profile.bodySize == 0 {
            warnings.append("plugin:rivista_dpc:no_font_information_all_body")
        }
        if furnitureCount > 0 {
            warnings.append("plugin:rivista_dpc:furniture_lines_removed_\(furnitureCount)")
        }
        let stampCount = nodes.reduce(0) { $0 + ($1.type == .ARTIFACT_STAMP ? 1 : 0) }
        let tocCount = nodes.reduce(0) { $0 + ($1.type == .TOC_GENERAL ? 1 : 0) }
        let indexCount = nodes.reduce(0) { $0 + ($1.type == .INDEX_ENTRY ? 1 : 0) }
        if stampCount + tocCount + indexCount > 0 {
            warnings.append(
                "plugin:rivista_dpc:apparatus_stamp_\(stampCount)_toc_\(tocCount)_index_\(indexCount)")
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
                profile_id: "rivista_dpc",
                editorial_family: "rivista_dpc",
                genre: "rivista",
                confidence: matches(extraction)
            ),
            warnings: warnings,
            transformations: [],
            structure: nodes
        )
    }
}

/// Il singleton del plugin (l'identità conta per il dispatcher `===`).
public let rivistaDpcPlugin = RivistaDpcPlugin()
