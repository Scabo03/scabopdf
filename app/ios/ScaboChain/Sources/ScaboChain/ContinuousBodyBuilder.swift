//
//  ContinuousBodyBuilder.swift
//  ScaboChain (fino al 2026-10-16 nel bersaglio ScaboApp; condiviso con l'app Mac)
//
//  Confine di cablaggio tra il modello di ScaboCore e la `ContinuousReadingView`.
//  Trasforma un `ScabopdfDocument` già classificato nel flusso paginato di CORPO
//  che la reading view consuma, applicando l'unica scelta di scope di QUESTA
//  sessione (gradino 2, sessione 1): rendere il CORPO, escludere l'apparato note.
//
//  ── Note REINTRODOTTE e PIAZZATE (capitolo NOTE, mattone aggancio) ───────────────
//
//  La sessione 1 escludeva l'apparato note dal corpo letto con un filtro di una
//  riga, dichiarato reversibile. Quel filtro è ORA RIMOSSO: le note rientrano nel
//  corpo e vengono LETTE. Non più a fondo pagina grezzo, ma al punto giusto del
//  LAYER2 (§ 7.3): la pipeline a monte (`DocumentProcessor` →
//  `bindAndPlaceNotes`) aggancia ogni richiamo alla sua nota e riposiziona le note
//  nell'albero — brevi a fine frase del richiamo, lunghe a fine sezione. Qui il
//  documento arriva GIÀ PIAZZATO: si granularizza il corpo discorsivo e si rende
//  tutto in ordine, note comprese. La granularità tratta `NOTE` come confine di
//  run (le note passano invariate, non si fondono col corpo).
//
//  Le note non agganciate (segnale assente/ambiguo su PDFKit — vedi
//  `NoteBinding.swift` e docs/NOTES_BINDING.md) restano lette nella loro posizione
//  d'origine: presenti, mai perse, solo non spostate.
//
//  ── Granularità del corpo discorsivo (§ 7.6, motore ScaboCore) ───────────────────
//
//  Il corpo discorsivo (manuali, saggi, dottrina) esce dalla classificazione in
//  paragrafi anche molto lunghi. Prima di renderlo, lo si fa passare per il motore
//  di granularità di ScaboCore (`granularizeBody`), fissato al valore più fine
//  (400 caratteri): riassembla il corpo in blocchi ~400 char senza spezzare frasi
//  né attraversare confini di struttura. Il target è parametrico (default 400):
//  il controllo utente dei quattro livelli (§ 7.7) sarà additivo, non una
//  riscrittura. Solo il corpo discorsivo (`BODY`) è granularizzato; le unità native
//  normative (`ARTICLE_BODY`, `PROCEDURAL`), le note e le strutture passano
//  invariate — la distinzione discorsivo/normativo è fatta per categoria dal motore
//  (vedi `Granularity.swift`), non per `genre` (inaffidabile on-device).
//
//  Ordine: si granularizza il layout continuo COMPLETO (le note presenti fungono da
//  confini di run, così il corpo non si fonde attraverso una nota), POI si filtrano
//  le note. Quando la sessione 2 reintrodurrà le note, il motore già le tratta come
//  confini: il cambio è togliere il filtro, non riscrivere.
//

import Foundation
import ScaboCore

/// I candidati delle risorse visive di un PDF e l'estrazione da cui è nato il documento: quanto serve alla guardia e
/// all'inserimento degli elementi «risorsa visiva» (`ScaboCore/VisualResources.swift`).
public struct VisualInput {
    public let candidates: [VisualRegionCandidate]
    public let extraction: PdfExtraction

    public init(candidates: [VisualRegionCandidate], extraction: PdfExtraction) {
        self.candidates = candidates
        self.extraction = extraction
    }
}

/// Costruisce il contenuto di CORPO (granularizzato, note escluse) dal documento.
public enum ContinuousBodyBuilder {

    /// Flusso dei segmenti di lettura — CORPO E NOTE PIAZZATE — granularizzati
    /// (§ 7.6) e in ordine di lettura. `target` è il valore di granularità (default
    /// 400). Le note sono già al punto giusto nell'albero (vedi `bindAndPlaceNotes`,
    /// applicato a monte da `DocumentProcessor`); qui non si filtra più nulla.
    public static func bodySegments(
        from document: ScabopdfDocument,
        target: Int = DEFAULT_GRANULARITY_TARGET
    ) -> [ContentSegment] {
        // Trattenimento della bibliografia di sezione fino a fine sezione: abilitato solo per la
        // famiglia Giappichelli/Photoshop (via `editorial_family`), e internamente ristretto a
        // Lezioni dalla presenza dei titoli § (no-op sui volumi-famiglia a note numerate).
        granularizeBody(
            buildLayout(document, .continuous),
            target: target,
            holdSectionBibliography: document.profile.editorial_family == GIAPPICHELLI_PHOTOSHOP_FAMILY)
    }

    /// Corpo paginato pronto per `ContinuousReadingView.render(_:)`. La
    /// paginazione è solo presentazione/orientamento: la view la appiattisce in un
    /// container di accessibilità unico e continuo.
    public static func bodyPaginatedContent(
        from document: ScabopdfDocument,
        target: Int = DEFAULT_GRANULARITY_TARGET,
        segmentsPerPage: Int = DEFAULT_SEGMENTS_PER_PAGE
    ) throws -> PaginatedContent {
        try paginate(bodySegments(from: document, target: target), segmentsPerPage)
    }

    /// Come `bodyPaginatedContent`, con le RISORSE VISIVE: ultimo passo prima dell'impaginazione, la guardia di
    /// ScaboCore decide quali regioni del modello diventano risorse e ne inserisce l'elemento nel flusso (additivo:
    /// il testo resta dov'era). `visual == nil` → identico a `bodyPaginatedContent`.
    ///
    /// `fractionLongNotes` (solo l'officina Mac, giro del 2026-10-16; l'iPad lo lascia spento): il frazionamento
    /// delle note lunghe ricucite (decisione di prodotto del 2026-08-10, `fractionLongNoteSegments`), applicato come
    /// nella porta d'import di sviluppo e nel runner della rete, PRIMA delle risorse visive; la soglia è la
    /// granularità del corpo (§ 10.6: corpo e note seguono lo stesso parametro).
    public static func bodyPaginatedContentWithVisual(
        from document: ScabopdfDocument,
        target: Int = DEFAULT_GRANULARITY_TARGET,
        segmentsPerPage: Int = DEFAULT_SEGMENTS_PER_PAGE,
        visual: VisualInput?,
        fractionLongNotes: Bool = false
    ) throws -> (content: PaginatedContent, report: VisualResourcesReport?) {
        var segments = bodySegments(from: document, target: target)
        if fractionLongNotes {
            segments = fractionLongNoteSegments(segments, target: target)
        }
        var report: VisualResourcesReport?
        if let visual {
            let out = insertingVisualResources(segments, candidates: visual.candidates, extraction: visual.extraction)
            segments = out.segments
            report = out.report
        }
        return (try paginate(segments, segmentsPerPage), report)
    }

    // ── Controllo dei quattro livelli (§ 7.7) ───────────────────────────────────────
    // Overload ADDITIVI che accettano un `GranularityLevel` (vocabolario chiuso
    // 400/600/900/1200) invece del target grezzo: il chiamato usa `level.target`.
    // Permettono al flusso di import/elaborazione di passare il livello scelto
    // dall'utente (default `.fine`), senza riscrivere le firme a target esistenti.
    // La persistenza dello stesso livello è banda successiva (manca lo store
    // concreto in app — vedi Preferences.swift, banda POST-MAC).

    public static func bodySegments(
        from document: ScabopdfDocument,
        granularity level: GranularityLevel
    ) -> [ContentSegment] {
        bodySegments(from: document, target: level.target)
    }

    public static func bodyPaginatedContent(
        from document: ScabopdfDocument,
        granularity level: GranularityLevel,
        segmentsPerPage: Int = DEFAULT_SEGMENTS_PER_PAGE
    ) throws -> PaginatedContent {
        try bodyPaginatedContent(from: document, target: level.target, segmentsPerPage: segmentsPerPage)
    }
}
