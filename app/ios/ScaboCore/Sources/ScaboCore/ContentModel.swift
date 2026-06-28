//
//  ContentModel.swift
//  ScaboCore
//
//  The data surface the reading view consumes. Faithful translation of
//  `app/src/rendering/contentModel.ts`.
//
//  CONFINE CALCOLO / RENDERING (Piano § 3, Fase 3-logica vs Fase 3-view).
//  ----------------------------------------------------------------------
//  This is exactly where the line between "logic computed today on XCTest" and
//  "view rendered on the physical Mac under XCUITest/VoiceOver" passes. The
//  rendering layer of the TS app is *pure calculation*: layout builders walk the
//  document tree and emit a stream of `ContentSegment`; `paginate` chunks the
//  stream into `ContentPage`s. NOTHING here draws on screen or talks to
//  UIAccessibility — that is the job of `ScaboReadingContentView` (the native
//  `UIView` that adopts `UIAccessibilityReadingContent`, Piano § 1.1), which is
//  banda POST-MAC and is deliberately NOT implemented in this phase.
//
//  So these value types ARE the extracted boundary: ScaboCore *computes* the
//  segments/pages; the post-Mac reading view *renders* them (it will receive a
//  `ContentPage`'s segments via what is `updatePageContent(...)` on the native
//  side). Keeping the surface a plain `Codable`/`Equatable` data type — and NOT
//  a view protocol — is intentional: the actual view-facing API and the spoken
//  reading order are VoiceOver-driven decisions taken on the Mac, and inventing
//  a protocol now would prejudge them. ScaboCore imports only Foundation.
//

import Foundation

/// A single renderable, accessible chunk of text.
public struct ContentSegment: Codable, Equatable, Sendable {
    /// Node id from the source document — stable identity for diffing.
    public var id: String
    /// `SemanticCategory` of the originating node, OR the Layer-2
    /// presentation-only role `SECTION_DIVIDER` (see `RoleStyle`). It is an
    /// opaque string passed verbatim to the native view, so the UIView can pick
    /// the typographic style and acoustic regime per segment.
    public var role: String
    /// Display text.
    public var text: String
    /// Acoustic regime (`MICRO` … `MEGA`) for NOTE segments; the empty string for
    /// any other role, matching the native side which uses "" to mean
    /// "not applicable".
    public var lengthCategory: String
    /// Spoken role intro the native view prepends before reading the text (Q2),
    /// e.g. `Modifica.` for AMENDMENT or `Nuovo testo.` for QUOTED_TEXT_NEW. The
    /// empty string for roles that need no acoustic prefix. Derived from role
    /// (+ lengthCategory for NOTE) by `acousticIntroFor`, with one backend-scoped
    /// refinement: on the heuristic Generic PDF stream a `NOTE` whose text does not
    /// open with a footnote marker is a heading/running-header collapsed into NOTE
    /// by the size-only classifier, so its `Nota.` intro is cleared
    /// (`suppressCollapsedHeadingNoteIntros`). The text is unchanged.
    public var acousticIntro: String
    /// Rinfresco di contesto (§ 7.4/§ 7.5) che la view antepone alla lettura di una
    /// nota DIFFERITA: la "frase del richiamo", così la nota non arrivi scollegata da
    /// ciò a cui risponde. Stringa vuota per ogni segmento che non sia una nota
    /// differita. È testo RIPETUTO in aggiunta (rete A): non sostituisce il contenuto.
    /// Calcolato da `bindAndPlaceNotes` (vedi `MemoryRefresh.swift`).
    public var memoryRefresh: String

    public init(
        id: String,
        role: String,
        text: String,
        lengthCategory: String,
        acousticIntro: String,
        memoryRefresh: String = ""
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.lengthCategory = lengthCategory
        self.acousticIntro = acousticIntro
        self.memoryRefresh = memoryRefresh
    }
}

/// A page of content delivered to the native view.
public struct ContentPage: Codable, Equatable, Sendable {
    /// 1-based logical page number.
    public var pageNumber: Int
    public var segments: [ContentSegment]

    public init(pageNumber: Int, segments: [ContentSegment]) {
        self.pageNumber = pageNumber
        self.segments = segments
    }
}

/// A layout's full output: an ordered list of pages.
public struct PaginatedContent: Codable, Equatable, Sendable {
    public var pages: [ContentPage]
    public var totalSegments: Int

    public init(pages: [ContentPage], totalSegments: Int) {
        self.pages = pages
        self.totalSegments = totalSegments
    }
}
