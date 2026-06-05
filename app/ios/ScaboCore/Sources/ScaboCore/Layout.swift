//
//  Layout.swift
//  ScaboCore
//
//  The reading layouts ScaboPDF offers. Faithful translation of
//  `app/src/consumption/layout.ts`.
//
//  There are exactly THREE layouts (a stale fourth was dropped; the binding
//  source is LAYER2_PRODUCT_DECISIONS.md). This module only fixes the canonical
//  identifiers and their Italian display names; layout-specific rendering lives
//  in the rendering layer (a later phase). Fase 1 needs only these identifiers
//  as part of the consumption public surface.
//

import Foundation

/// The canonical layout identifiers.
public enum LayoutId: String, CaseIterable, Equatable, Sendable {
    case continuous
    case quick
    case doctrine
}

/// The three layouts, in canonical order.
public let LAYOUT_IDS: [LayoutId] = [.continuous, .quick, .doctrine]

/// Italian display names (UI language is Italian in phase 1).
public let LAYOUT_DISPLAY_NAMES: [LayoutId: String] = [
    .continuous: "Lettura Continua",
    .quick: "Consultazione Rapida",
    .doctrine: "Dottrina Inline",
]
