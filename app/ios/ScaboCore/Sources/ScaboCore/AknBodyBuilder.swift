//
//  AknBodyBuilder.swift
//  ScaboCore
//
//  Confine di cablaggio ScabopdfDocument (AKN) → PaginatedContent per la reading
//  view, analogo di `ContinuousBodyBuilder` ma per il percorso normativo. Applica
//  la rifinitura AKN (Parte B) e NON usa `bindAndPlaceNotes` (le note normative
//  restano in posizione strutturale, §7.2) né `granularizeBody` (l'AKN non emette
//  `BODY` discorsivo; `ARTICLE_BODY` è unità normativa che passa invariata). Puro
//  ScaboCore, testabile offline; il percorso PDF non è toccato.
//

import Foundation

public enum AknBodyBuilder {

    /// Flusso paginato di CORPO per un documento AKN: layout continuo → rifinitura
    /// dei tre attriti (note frazionate, comma-marker accorpato, doppio "Modifica."
    /// eliminato) → paginazione (solo dispositivo di presentazione; la view appiattisce
    /// in un container di accessibilità unico e continuo).
    public static func bodyPaginatedContent(
        from document: ScabopdfDocument,
        target: Int = DEFAULT_GRANULARITY_TARGET,
        segmentsPerPage: Int = DEFAULT_SEGMENTS_PER_PAGE
    ) throws -> PaginatedContent {
        let base = buildLayout(document, .continuous)
        let refined = refineAknSegments(base, noteTarget: target)
        return try paginate(refined, segmentsPerPage)
    }
}
