//
//  Taxonomy.swift
//  ScaboCore
//
//  The Generic plugin category taxonomy contract. Faithful translation of
//  `app/src/plugins/taxonomy.ts`.
//
//  The single, explicit, CLOSED declaration of which Layer 1 SemanticCategory
//  values the Generic plugin produces, detects-and-suppresses, or reserves for
//  corpus plugins / non-PDF backends — and, for each, the discriminating signal.
//  Layer 1 is the source of truth: this taxonomy is a nominal subset of
//  `SemanticCategory`, never a divergent renaming. `TaxonomyTests` pins the same
//  invariants the TS `taxonomy.test.ts` does (the test there reads the enum from
//  the committed schema; the Swift equivalent is `SemanticCategory.allCases`,
//  itself the verbatim mirror of `shared/schema.json` $defs.SemanticCategory).
//

import Foundation

/// The discriminating mechanisms the Generic uses, each tied to concrete code in
/// `GenericPlugin.swift`. A category's `signals` lists which determine it.
public enum GenericSignal: Equatable, Sendable {
    /// Size ratio (line size / estimated body size) — `classify()` ratio buckets.
    case sizeBand
    /// Saturated, body-distinct colour (D4); also near-white anchor suppression.
    case colour
    /// Page geometry — short-line caps and top/bottom page bands.
    case geometry
    /// Bold weight flag on the line — promotes a slightly-larger short line.
    case fontWeight
    /// Cross-page recurrence (`detectFurniture`) — furniture (D2).
    case recurrence
    /// Merged-text length → MICRO…MEGA regime. Annotates NOTE nodes, not classifying.
    case textLength
    /// A self-identifying TEXT pattern that prose cannot produce — the colophon
    /// markers (ISBN/©/"finito di stampare"), the dotted-leader index line, the
    /// back-matter index section heading. Drives the front-/back-matter apparatus
    /// recognisers in `GenericPlugin` (the apparatus is emitted as a node but
    /// excluded from the read flow via `NON_READ_ROLES`).
    case textPattern
}

/// How the Generic relates to a given Layer 1 category.
public enum GenericCoverage: Equatable, Sendable {
    case produced
    case detectedSuppressed
    case reserved
}

/// The per-category contract entry.
public struct GenericCategoryContract: Equatable, Sendable {
    public let category: SemanticCategory
    public let coverage: GenericCoverage
    public let signals: [GenericSignal]
    public let rationale: String

    public init(_ category: SemanticCategory, _ coverage: GenericCoverage, _ signals: [GenericSignal], _ rationale: String) {
        self.category = category
        self.coverage = coverage
        self.signals = signals
        self.rationale = rationale
    }
}

/// All entries, in declaration order — the canonical source. `GENERIC_TAXONOMY`
/// (the keyed map) is derived from this so there is one source of truth.
public let GENERIC_TAXONOMY_ENTRIES: [GenericCategoryContract] = [
    // ── Produced by the Generic today ──────────────────────────────────────────
    GenericCategoryContract(.HEADING_1, .produced, [.sizeBand, .geometry, .colour],
        "Short line (≤120 chars) whose size ratio to body is ≥1.5 (HEADING_1_RATIO); or a saturated, body-distinct colour heading (colorDistance>100, saturation>40) sized ≥1.25 of body. classify() → {HEADING, level:1}."),
    GenericCategoryContract(.HEADING_2, .produced, [.sizeBand, .geometry, .colour],
        "Short line with size ratio ≥1.25 (HEADING_2_RATIO); or a colour heading sized ≥1.12 of body. classify() → {HEADING, level:2}."),
    GenericCategoryContract(.HEADING_3, .produced, [.sizeBand, .geometry, .colour],
        "Short line with size ratio ≥1.12 (HEADING_3_RATIO); or the catch-all level for a colour heading that clears COLOR_HEADING_MIN_RATIO but not the larger bands. classify() → {HEADING, level:3}."),
    GenericCategoryContract(.HEADING_4, .produced, [.sizeBand, .geometry, .fontWeight],
        "Short, BOLD line only slightly larger than body, ratio ≥1.04 (HEADING_4_BOLD_RATIO and line.bold). classify() → {HEADING, level:4}."),
    GenericCategoryContract(.BODY, .produced, [.sizeBand],
        "Default class: size ratio between NOTE_RATIO (0.85) and the heading bands, or no font information at all (ratio===0). Consecutive BODY lines are merged into one paragraph node by appendPageNodes."),
    GenericCategoryContract(.NOTE, .produced, [.sizeBand, .textLength],
        "Line clearly smaller than body, size ratio ≤0.85 (NOTE_RATIO). Runs of NOTE lines merge into one node; length_category (MICRO…MEGA) is computed from the merged text length (lengthCategoryFor)."),
    GenericCategoryContract(.MARGINAL_GLOSS, .produced, [.sizeBand, .geometry],
        "Lateral gloss: a note-sized line (ratio ≤0.85) sitting OUTSIDE the per-page body column (left/right margin), alphabetic, not a chapter roman. Emitted as a node but excluded from the read flow (NON_READ_ROLES). See docs/GLOSSE_LATERALI.md / isLateralGloss."),
    GenericCategoryContract(.TOC_GENERAL, .produced, [.textPattern, .geometry],
        "Index / table of contents: a page (front- or back-matter region) carrying ≥3 dotted-leader lines (frontMatterLeaderRegex). Emitted as a node but excluded from the read flow. The analytic index — no leaders — is NOT caught here."),
    GenericCategoryContract(.ARTIFACT_STAMP, .produced, [.textPattern],
        "Colophon / legal page: a sparse page (front- or back-matter region) carrying a self-identifying marker prose cannot produce — ISBN+digit, '© copyright'/'copyright <year>', 'tutti i diritti riservati', 'finito di stampare', SIAE (frontMatterColophonRegex). Emitted as a node but excluded from the read flow."),
    GenericCategoryContract(.INDEX_ENTRY, .produced, [.textPattern, .geometry],
        "Back-matter named index (names / sources / cited cases): a page in the final region under a name-index section heading (INDICE DEI NOMI/DEGLI AUTORI/DELLE FONTI, LE FONTI, INDICE CRONOLOGICO DELLE SENTENZE, …) whose lines are index-structured (entries ending in page references). Emitted as a node but excluded from the read flow. The analytic/alphabetical subject index is deliberately EXCLUDED (left read) via a heading deny-list — see docs/BACK_MATTER.md / detectBackMatterApparatus."),

    // ── Detected by the Generic but emitted as NO node (furniture / anchors) ─────
    GenericCategoryContract(.ARTIFACT_RUNNING_HEADER, .detectedSuppressed, [.recurrence, .geometry],
        "detectFurniture: a short line (≤60 chars) in the TOP page band (yFrac ≥0.9) whose digit-normalised text recurs across ≥15% of pages. Dropped so it cannot read as a false heading (debt D2). Not tagged — the mapping is conceptual."),
    GenericCategoryContract(.ARTIFACT_FOOTER, .detectedSuppressed, [.recurrence, .geometry],
        "detectFurniture: same recurrence in the BOTTOM page band (yFrac ≤0.1). Dropped, not tagged."),
    GenericCategoryContract(.ARTIFACT_FILIGREE, .detectedSuppressed, [.recurrence, .colour],
        "detectFurniture: a normalised line recurring on a MAJORITY (≥50%) of pages anywhere (watermark/copyright), or a saturated per-page colour marker recurring ≥15% of pages. Dropped, not tagged."),
    GenericCategoryContract(.BOOK_PAGE_ANCHOR, .detectedSuppressed, [.colour],
        "Near-white invisible text (every RGB channel >230, isNearWhite) and saturated per-page colour markers are skipped in appendPageNodes. Dropped, never emitted as a node."),

    // ── Reserved for corpus-specific plugins / non-PDF backends ──────────────────
    GenericCategoryContract(.ARTICLE_HEADER, .reserved, [],
        "Legal-codes structure. Requires a giuffre_codici-class plugin (banner-glyph code-type + bold article-number triggers). The Generic has no notion of articles."),
    GenericCategoryContract(.ARTICLE_BODY, .reserved, [],
        "Per-comma body of a legal article; minted alongside ARTICLE_HEADER by the legal-codes / AKN backends only."),
    GenericCategoryContract(.PROCEDURAL, .reserved, [],
        "Procedural sub-block of a code (penale c.p.p.). Corpus-specific sub-parser; the Generic does not recognise it."),
    GenericCategoryContract(.BODY_CONTINUATION, .reserved, [],
        "The Generic merges consecutive body lines into a single BODY node; it has no cross-page paragraph-continuation model to mint a continuation node."),
    GenericCategoryContract(.NOTE_CONTINUATION, .reserved, [],
        "The Generic merges note runs into a single NOTE node; it has no cross-page note-continuation model."),
    GenericCategoryContract(.MARGINAL_HEADING, .reserved, [],
        "Marginal apparatus keyed on corpus-specific font + margin geometry (e.g. Mandrioli Vol. I/II). Outside the Generic signal set."),
    GenericCategoryContract(.EXAMPLE_BOX, .reserved, [],
        "Boxed worked example; needs a corpus-specific layout signal the Generic does not measure."),
    GenericCategoryContract(.CHAPTER_SUMMARY, .reserved, [],
        "Editorial chapter summary with a corpus-specific signature (e.g. small-caps SOMMARIO label). Corpus-specific."),
    GenericCategoryContract(.EDITORIAL_NOTE, .reserved, [],
        "Editorial (*) note; minted by the DeJure-family / AKN backends. The Generic only emits plain NOTE."),
    GenericCategoryContract(.MASSIMA_LABEL, .reserved, [],
        "DeJure Massime label marker; recognised only by dejure_massime."),
    GenericCategoryContract(.REFERRAL, .reserved, [],
        "DeJure referral line, discriminated structurally by reading-order position after a label. DeJure-family only."),
    GenericCategoryContract(.TITLE, .reserved, [],
        "Document/article title in the DeJure & EdD pipelines; the Generic treats a large short line as a HEADING, not a TITLE."),
    GenericCategoryContract(.FONTE_LABEL, .reserved, [],
        "DeJure \"Fonte:\" label marker; DeJure-family only."),
    GenericCategoryContract(.FONTE_VALUE, .reserved, [],
        "DeJure source value (size-discriminated from body after a FONTE_LABEL); DeJure-family only."),
    GenericCategoryContract(.META_LABEL, .reserved, [],
        "DeJure metadata label; DeJure-family only."),
    GenericCategoryContract(.META_VALUE, .reserved, [],
        "DeJure metadata value (umbrella, later decomposed); DeJure-family only."),
    GenericCategoryContract(.AUTHORS, .reserved, [],
        "DeJure \"Autori:\" value (incl. multi-author / bilingual); DeJure-family only."),
    GenericCategoryContract(.SECTION_LABEL, .reserved, [],
        "Structural label such as \"Note:\" that anchors a notes section; minted by the DeJure / EdD plugins."),
    GenericCategoryContract(.GENRE_BANNER, .reserved, [],
        "Editorial banner (\"DOTTRINA\", \"NOTE E DOTTRINA\"); DeJure-family discriminator, not a Generic concept."),
    GenericCategoryContract(.SUBTITLE, .reserved, [],
        "Editorial subtitle line (e.g. DeJure NS \"Quotidiano del …\"); DeJure-family only."),
    GenericCategoryContract(.HEADING_LETTER_INITIAL, .reserved, [],
        "Encyclopedia drop-cap: a single uppercase letter at >30pt opening an alphabetic section. Emitted by the EdD plugins. The Generic would treat a one-letter span as a non-substantial marker and drop it."),
    GenericCategoryContract(.FONTI, .reserved, [],
        "Named \"FONTI.\" bibliographic section; EdD plugins only."),
    GenericCategoryContract(.LETTERATURA, .reserved, [],
        "Named \"LETTERATURA.\" bibliographic section; EdD plugins only."),
    GenericCategoryContract(.AMENDMENT, .reserved, [],
        "AKN legislative modification; produced exclusively by the XML AKN / EPUB IPZS backends, never by the PDF Generic plugin."),
    GenericCategoryContract(.QUOTED_TEXT_OLD, .reserved, [],
        "AKN previgent (old) quoted text; AKN/EPUB backends only."),
    GenericCategoryContract(.QUOTED_TEXT_NEW, .reserved, [],
        "AKN new quoted text; AKN/EPUB backends only."),
    GenericCategoryContract(.UPDATE_BLOCK, .reserved, [],
        "AKN structured modification record (active/passive); AKN/EPUB backends only."),
    GenericCategoryContract(.CROSS_REFERENCE, .reserved, [],
        "Inline reference marker minted as a synthetic node by corpus plugins / the apparatus resolver. The Generic does not mint synthetic reference nodes."),
    GenericCategoryContract(.LIST_ITEM, .reserved, [],
        "List item keyed on geometric indentation / bullet glyph (materiali_studio). The Generic folds such lines into BODY."),
    GenericCategoryContract(.ARTIFACT_PAGE_HEADER, .reserved, [],
        "A distinct page-header artifact category; the Generic only models running-header furniture (ARTIFACT_RUNNING_HEADER)."),
    GenericCategoryContract(.EMPTY_PAGE, .reserved, [],
        "The Generic emits no node for a page with no content; it never tags an EMPTY_PAGE node."),
    GenericCategoryContract(.UNCLASSIFIED, .reserved, [],
        "The Generic always commits a line to BODY / NOTE / HEADING; it never emits the fallback category."),
]

/// The complete map from every Layer 1 category to its Generic coverage.
public let GENERIC_TAXONOMY: [SemanticCategory: GenericCategoryContract] = {
    var map: [SemanticCategory: GenericCategoryContract] = [:]
    for entry in GENERIC_TAXONOMY_ENTRIES { map[entry.category] = entry }
    return map
}()

private func categoriesWithCoverage(_ coverage: GenericCoverage) -> Set<SemanticCategory> {
    Set(GENERIC_TAXONOMY_ENTRIES.filter { $0.coverage == coverage }.map { $0.category })
}

/// Categories the Generic plugin emits as nodes today.
public let GENERIC_PRODUCED_CATEGORIES: Set<SemanticCategory> = categoriesWithCoverage(.produced)

/// Categories the Generic recognises as a signal but drops (emits no node).
public let GENERIC_DETECTED_SUPPRESSED_CATEGORIES: Set<SemanticCategory> = categoriesWithCoverage(.detectedSuppressed)

/// Categories reserved for corpus-specific plugins / non-PDF backends.
public let GENERIC_RESERVED_CATEGORIES: Set<SemanticCategory> = categoriesWithCoverage(.reserved)

/// True iff the Generic plugin can emit a node of this category.
public func isGenericProduced(_ category: SemanticCategory) -> Bool {
    GENERIC_PRODUCED_CATEGORIES.contains(category)
}

/// Layer-2 presentation roles that are NOT Layer 1 SemanticCategory values.
/// `SECTION_DIVIDER` is minted in the rendering layer (a later phase) for
/// synthetic HEADING_1 containers; the Generic never emits it.
public let LAYER2_PRESENTATION_ONLY_ROLES: [String] = ["SECTION_DIVIDER"]
