//
//  ContinuousBodyBuilder.swift
//  ScaboApp
//
//  Confine di cablaggio tra il modello di ScaboCore e la `ContinuousReadingView`.
//  Trasforma un `ScabopdfDocument` già classificato nel flusso paginato di CORPO
//  che la reading view consuma, applicando l'unica scelta di scope di QUESTA
//  sessione (gradino 2, sessione 1): rendere il CORPO, escludere l'apparato note.
//
//  ── Scelta di scope dichiarata: note ESCLUSE in questa sessione ──────────────────
//
//  Il Layout "Lettura Continua" di ScaboCore (`buildContinuousLayout`) emette il
//  corpo CON le note interfogliate dove l'albero Layer-1 le ha collocate. Le note
//  e il loro apparato sono materia della SESSIONE 2. Per questa sessione il corpo
//  deve leggersi pulito, quindi si filtrano i ruoli `NOTE`/`EDITORIAL_NOTE` — lo
//  stesso insieme che `buildQuickConsultLayout` già scarta in ScaboCore. È un
//  filtro di una riga (più pulito che lasciare le note grezze nel flusso) e
//  REVERSIBILE: la sessione 2 lo rimuoverà reintroducendo l'apparato. La
//  classificazione non è toccata: le note restano nel `Document`, solo non
//  vengono rese qui.
//
//  Il filtro vive QUI, al confine di cablaggio, non nella view: la view resta
//  agnostica al layout e rende qualunque sequenza riceva.
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

    /// Ruoli dell'apparato note, esclusi dal rendering di questa sessione
    /// (allineati a `quickConsultCollapsedRoles` di ScaboCore).
    static let noteRoles: Set<String> = ["NOTE", "EDITORIAL_NOTE"]

    /// Flusso di soli segmenti di corpo, granularizzati (§ 7.6) e in ordine di
    /// lettura. `target` è il valore di granularità (default 400, granularità fine).
    static func bodySegments(
        from document: ScabopdfDocument,
        target: Int = DEFAULT_GRANULARITY_TARGET
    ) -> [ContentSegment] {
        let granular = granularizeBody(buildLayout(document, .continuous), target: target)
        return granular.filter { !noteRoles.contains($0.role) }
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
