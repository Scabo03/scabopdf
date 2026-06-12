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

import Foundation
import ScaboCore

/// Costruisce il contenuto di CORPO (note escluse) dal documento classificato.
enum ContinuousBodyBuilder {

    /// Ruoli dell'apparato note, esclusi dal rendering di questa sessione
    /// (allineati a `quickConsultCollapsedRoles` di ScaboCore).
    static let noteRoles: Set<String> = ["NOTE", "EDITORIAL_NOTE"]

    /// Flusso di soli segmenti di corpo, in ordine di lettura.
    static func bodySegments(from document: ScabopdfDocument) -> [ContentSegment] {
        buildLayout(document, .continuous).filter { !noteRoles.contains($0.role) }
    }

    /// Corpo paginato pronto per `ContinuousReadingView.render(_:)`. La
    /// paginazione è solo presentazione/orientamento: la view la appiattisce in un
    /// container di accessibilità unico e continuo.
    static func bodyPaginatedContent(
        from document: ScabopdfDocument,
        segmentsPerPage: Int = DEFAULT_SEGMENTS_PER_PAGE
    ) throws -> PaginatedContent {
        try paginate(bodySegments(from: document), segmentsPerPage)
    }
}
