//
//  ContinuousBodyBuilder.swift
//  ScaboApp
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

/// Costruisce il contenuto di CORPO (granularizzato, note escluse) dal documento.
enum ContinuousBodyBuilder {

    /// Flusso dei segmenti di lettura — CORPO E NOTE PIAZZATE — granularizzati
    /// (§ 7.6) e in ordine di lettura. `target` è il valore di granularità (default
    /// 400). Le note sono già al punto giusto nell'albero (vedi `bindAndPlaceNotes`,
    /// applicato a monte da `DocumentProcessor`); qui non si filtra più nulla.
    static func bodySegments(
        from document: ScabopdfDocument,
        target: Int = DEFAULT_GRANULARITY_TARGET
    ) -> [ContentSegment] {
        granularizeBody(buildLayout(document, .continuous), target: target)
    }

    /// Corpo paginato pronto per `ContinuousReadingView.render(_:)`. La
    /// paginazione è solo presentazione/orientamento: la view la appiattisce in un
    /// container di accessibilità unico e continuo.
    static func bodyPaginatedContent(
        from document: ScabopdfDocument,
        target: Int = DEFAULT_GRANULARITY_TARGET,
        segmentsPerPage: Int = DEFAULT_SEGMENTS_PER_PAGE
    ) throws -> PaginatedContent {
        try paginate(bodySegments(from: document, target: target), segmentsPerPage)
    }

    // ── Controllo dei quattro livelli (§ 7.7) ───────────────────────────────────────
    // Overload ADDITIVI che accettano un `GranularityLevel` (vocabolario chiuso
    // 400/600/900/1200) invece del target grezzo: il chiamato usa `level.target`.
    // Permettono al flusso di import/elaborazione di passare il livello scelto
    // dall'utente (default `.fine`), senza riscrivere le firme a target esistenti.
    // La persistenza dello stesso livello è banda successiva (manca lo store
    // concreto in app — vedi Preferences.swift, banda POST-MAC).

    static func bodySegments(
        from document: ScabopdfDocument,
        granularity level: GranularityLevel
    ) -> [ContentSegment] {
        bodySegments(from: document, target: level.target)
    }

    static func bodyPaginatedContent(
        from document: ScabopdfDocument,
        granularity level: GranularityLevel,
        segmentsPerPage: Int = DEFAULT_SEGMENTS_PER_PAGE
    ) throws -> PaginatedContent {
        try bodyPaginatedContent(from: document, target: level.target, segmentsPerPage: segmentsPerPage)
    }
}
