//
//  Layouts.swift
//  ScaboCore
//
//  The three reading layouts and the dispatcher. Faithful translation of
//  `app/src/rendering/layouts/{continuous,quickConsult,doctrineInline}.ts` and
//  the `buildLayout` dispatcher in `app/src/rendering/index.ts`.
//
//  Each builder starts from the layout-agnostic `buildBaseSegments` stream and
//  applies its own filtering or transformation. All three are pure calculation —
//  the on-screen rendering of the resulting segments is the post-Mac view's job
//  (see ContentModel.swift, CONFINE CALCOLO / RENDERING).
//

import Foundation

/// Lettura Continua — linear flow: heading → body → notes after section.
///
/// The Layer 1 tree already places notes as children of their containing
/// structural unit (HEADING_N or ARTICLE_BODY), so the pre-order base traversal
/// produces the right reading order without further work. Per-profile reorderings
/// (DeJure massima title-first, BIC volume dedupe) are deferred to a polish
/// session (docs/LAYER2_EDGE_CASES.md).
public func buildContinuousLayout(_ doc: ScabopdfDocument) -> [ContentSegment] {
    buildBaseSegments(doc)
}

/// Dottrina Inline — doctrinal essays, encyclopedia entries, treatises.
///
/// v1 is identical to the continuous layout: each NOTE segment carries its
/// length_category (MICRO…MEGA) for the acoustic regime; the structural placement
/// of the note is whatever the Layer 1 tree produced. SPECS § 4.5's per-sentence
/// inline insertion is a polish deferred to a later session.
public func buildDoctrineInlineLayout(_ doc: ScabopdfDocument) -> [ContentSegment] {
    buildBaseSegments(doc)
}

/// Roles dropped by the quick-consult layout.
private let quickConsultCollapsedRoles: Set<String> = ["NOTE", "EDITORIAL_NOTE"]

/// Consultazione Rapida — high density, optimized for finding a specific article
/// quickly with the VoiceOver rotor.
///
/// v1 simply drops NOTE and EDITORIAL_NOTE segments so the linear flow shows only
/// the structural body. The note content remains in the source Document and can
/// be re-surfaced later via an "expand notes" action (deferred polish).
public func buildQuickConsultLayout(_ doc: ScabopdfDocument) -> [ContentSegment] {
    buildBaseSegments(doc).filter { !quickConsultCollapsedRoles.contains($0.role) }
}

/// Dispatches a document to the requested layout's builder.
public func buildLayout(_ doc: ScabopdfDocument, _ layout: LayoutId) -> [ContentSegment] {
    switch layout {
    case .continuous:
        return buildContinuousLayout(doc)
    case .quick:
        return buildQuickConsultLayout(doc)
    case .doctrine:
        return buildDoctrineInlineLayout(doc)
    }
}
