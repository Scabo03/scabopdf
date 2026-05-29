/* eslint-disable */
/**
 * GENERATED FILE — do not edit by hand.
 * Source of truth: shared/schema.json (the Layer 1 contract).
 * Regenerate with: npm run gen:schema
 */

export type SchemaVersion = '0.7.0';
export type DocumentId = string;
export type PagesPdf = number;
/**
 * @minItems 2
 * @maxItems 2
 */
export type PageSizePt = [unknown, unknown];
export type SourcePdfFilename = string;
export type ProfileId = string;
export type EditorialFamily = string;
export type Genre = string;
export type Confidence = number;
export type Warnings = string[];
export type StepId = string;
export type NodeId = string;
export type PageIndex = number;
/**
 * @minItems 2
 * @maxItems 2
 */
export type Position = [unknown, unknown];
export type Original = string;
export type Normalized = string;
export type SplitInto = string[] | null;
export type MergedFrom = string[] | null;
export type Transformations = TransformationDict[];
export type Id = string;
export type SemanticCategory =
  | 'HEADING_1'
  | 'HEADING_2'
  | 'HEADING_3'
  | 'HEADING_4'
  | 'ARTICLE_HEADER'
  | 'ARTICLE_BODY'
  | 'PROCEDURAL'
  | 'BODY'
  | 'BODY_CONTINUATION'
  | 'NOTE'
  | 'NOTE_CONTINUATION'
  | 'MARGINAL_HEADING'
  | 'MARGINAL_GLOSS'
  | 'EXAMPLE_BOX'
  | 'CHAPTER_SUMMARY'
  | 'TOC_GENERAL'
  | 'INDEX_ENTRY'
  | 'EDITORIAL_NOTE'
  | 'MASSIMA_LABEL'
  | 'REFERRAL'
  | 'TITLE'
  | 'FONTE_LABEL'
  | 'FONTE_VALUE'
  | 'META_LABEL'
  | 'META_VALUE'
  | 'AUTHORS'
  | 'SECTION_LABEL'
  | 'GENRE_BANNER'
  | 'SUBTITLE'
  | 'HEADING_LETTER_INITIAL'
  | 'FONTI'
  | 'LETTERATURA'
  | 'AMENDMENT'
  | 'QUOTED_TEXT_OLD'
  | 'QUOTED_TEXT_NEW'
  | 'UPDATE_BLOCK'
  | 'CROSS_REFERENCE'
  | 'LIST_ITEM'
  | 'BOOK_PAGE_ANCHOR'
  | 'ARTIFACT_RUNNING_HEADER'
  | 'ARTIFACT_FOOTER'
  | 'ARTIFACT_FILIGREE'
  | 'ARTIFACT_STAMP'
  | 'ARTIFACT_PAGE_HEADER'
  | 'EMPTY_PAGE'
  | 'UNCLASSIFIED';
export type PageIndex1 = number;
export type Text = string | null;
export type Level = number | null;
export type Items = ChapterSummaryItem[] | null;
export type Number = string;
export type Title = string;
export type TocItems = TocGeneralItem[] | null;
export type Number1 = string;
export type Title1 = string;
export type PageNumber = number | null;
export type LengthCategory = ('MICRO' | 'SHORT' | 'MEDIUM' | 'LONG' | 'VERY_LONG' | 'MEGA') | null;
export type BlockIndices = number[];
export type Children = NodeDict[];
/**
 * Closed enum of relationships produced by tier 1 apparatus resolution.
 */
export type ApparatusRefKind = 'CROSS_REF_TARGET' | 'BODY_ASSOCIATION' | 'GLOSS_TARGET';
export type TargetNodeId = string;
export type SourceMarker = string | null;
export type ApparatusRefs = ApparatusRefDict[];
export type Structure = NodeDict[];

/**
 * The Layer 1 → Layer 2 JSON document, schema version 0.7.0.
 *
 * The emitted JSON conforms to JSON Schema Draft 2020-12 as serialised
 * by ``ScabopdfDocument.model_json_schema()`` and committed to
 * ``shared/schema.json``.
 *
 * ``warnings`` is a single flat list at the document root. At emission
 * time (§ 9) the converter will merge the Document tier 1 warnings
 * (first) with the DocumentProfile warnings (after) into this single
 * list. The contract therefore does **not** carry a separate warnings
 * field inside ``DocumentProfileDict``.
 *
 * ``transformations`` is the reversible log of post-processing
 * rewrites (§ 7). Empty when the profile declares no post-processing
 * steps; populated entry-per-substitution otherwise. Layer 2 reads
 * this block to support "raw mode" reading.
 *
 * ``structure`` is the top-level sequence of reading-order nodes — the
 * forest of root nodes produced by structural reconstruction (§ 5).
 */
export interface ScabopdfDocument {
  schema_version: SchemaVersion;
  document_id: DocumentId;
  metadata: DocumentMetadata;
  profile: DocumentProfileDict;
  warnings?: Warnings;
  transformations?: Transformations;
  structure?: Structure;
}
/**
 * Editorial metadata extracted from the source PDF.
 *
 * The current :data:`SCHEMA_VERSION` carries only the fields the pipeline
 * actually populates today: page count, physical page size, and the
 * source filename. Title, authors, ISBN, year, language, edition,
 * publisher and ``pages_with_content`` are deferred to a later version
 * when a metadata-extraction step is built.
 *
 * ``page_size_pt`` is the size of the **first** PDF page expressed in
 * PostScript points ``(width, height)``. Documents with heterogeneous
 * page sizes are out of scope at this schema version.
 */
export interface DocumentMetadata {
  pages_pdf: PagesPdf;
  page_size_pt: PageSizePt;
  source_pdf_filename: SourcePdfFilename;
}
/**
 * Output of the profiling phase, as it appears in the emitted JSON.
 *
 * A strict subset of
 * :class:`scabopdf_pipeline.profiling.profile.DocumentProfile`: only the
 * fields that uniquely identify the profile and its confidence are
 * emitted today. ``detection_signals``, ``layouts_available``,
 * ``layouts_disabled``, ``categories_emitted`` and ``post_processing``
 * are deferred to later additive versions.
 *
 * The profile's own ``warnings`` (DocumentProfile.warnings) are **not**
 * represented here: at emission time (§ 9) they are merged into the
 * top-level ``ScabopdfDocument.warnings`` list.
 */
export interface DocumentProfileDict {
  profile_id: ProfileId;
  editorial_family: EditorialFamily;
  genre: Genre;
  confidence: Confidence;
}
/**
 * A reversible operation recorded by a post-processing or tier 2 step.
 *
 * Mirrors :class:`scabopdf_pipeline.postprocessing.types.Transformation`
 * in its JSON form. Layer 2 reads the ``transformations`` list to
 * support "raw mode" reading: walking the list in **reverse** order
 * and replacing ``text[position[0] : position[0] + len(normalized)]``
 * with ``original`` on the named node restores the pre-post-processing
 * text byte-for-byte.
 *
 * ``position`` is the half-open ``(start, end)`` offset into the node
 * text **as it was immediately before** this transformation was
 * applied. When a single step records several transformations on the
 * same node, the step applies the substitutions right-to-left so the
 * recorded offsets remain valid slices of that pre-step text.
 *
 * ``original`` is the **literal slice** of the pre-transformation
 * text (newlines and soft hyphens included), not a cleaned-up form;
 * this is what makes the log reversible without ambiguity.
 *
 * The post-step node text satisfies ``post[position[0] :
 * position[0] + len(normalized)] == normalized``.
 *
 * ``split_into`` and ``merged_from`` (both added in schema 0.5.0,
 * both optional and ``None`` by default) extend the model from
 * purely-textual reversibility to structural reversibility:
 *
 * - ``split_into`` lists the ids of synthetic sibling Nodes a step
 *   minted from the host Node (the Giappichelli body+note splitter
 *   decomposes a glued BODY into BODY + N synthetic NOTE siblings,
 *   each id appears here on the surviving BODY's transformation).
 * - ``merged_from`` lists the ids of sibling Nodes a step absorbed
 *   into the host Node (the Mosconi marginal-ellipsis merger fuses
 *   a chain of fragments into one head; the Giappichelli
 *   cross-page note merger fuses a continuation NOTE into its
 *   head NOTE; each absorbed id appears here on the surviving
 *   head's transformation).
 *
 * Both fields stay ``None`` for purely textual transformations
 * (``dehyphenate_with_log``). Layer 2 can walk the 0.5.0 log in
 * reverse and rematerialise either the consumed siblings (by
 * reading ``merged_from``) or drop the produced siblings (by
 * reading ``split_into``) in addition to the existing textual
 * reversal.
 */
export interface TransformationDict {
  step_id: StepId;
  node_id: NodeId;
  page_index: PageIndex;
  position: Position;
  original: Original;
  normalized: Normalized;
  split_into?: SplitInto;
  merged_from?: MergedFrom;
}
/**
 * A node in the reading-order tree.
 *
 * Mirrors :class:`scabopdf_pipeline.reconstruction.types.Node` in its
 * JSON form. The Python ``category`` field is renamed to ``type`` here
 * to match ``ARCHITECTURE.md § 8.7`` and what Layer 2 expects to read.
 *
 * ``children`` is recursive and produces an arbitrarily deep tree.
 * ``text`` is ``None`` only for synthetic nodes without an originating
 * block (currently only ``EMPTY_PAGE``). ``level`` is non-null only for
 * ``HEADING_*`` categories. ``items`` is non-null only for
 * ``CHAPTER_SUMMARY`` nodes whose textual content a corpus plugin
 * could parse into structured entries; it is ``null`` for every other
 * node type and for ``CHAPTER_SUMMARY`` nodes the plugin chose not to
 * parse or could not parse. ``toc_items`` follows the symmetric
 * convention for ``TOC_GENERAL`` nodes: non-null only when the plugin
 * parsed the entries successfully, ``null`` for every other node type
 * and for unparseable TOCs. ``length_category`` is non-null only for
 * ``NOTE`` Nodes (added in 0.6.0): the six closed acoustic regimes
 * (``MICRO`` / ``SHORT`` / ``MEDIUM`` / ``LONG`` / ``VERY_LONG`` /
 * ``MEGA``) that Layer 2 consumes to choose the verbal intro before
 * reading the note aloud; ``None`` for every other category, including
 * the sibling ``EDITORIAL_NOTE`` (whose acoustic regime is deferred to
 * a future version). These semantic cross-field invariants are not
 * enforced by the contract at the current :data:`SCHEMA_VERSION` to
 * keep the schema additive; they may become validated constraints in
 * a later version.
 */
export interface NodeDict {
  id: Id;
  type: SemanticCategory;
  page_index: PageIndex1;
  text?: Text;
  level?: Level;
  items?: Items;
  toc_items?: TocItems;
  length_category?: LengthCategory;
  block_indices?: BlockIndices;
  children?: Children;
  apparatus_refs?: ApparatusRefs;
}
/**
 * One entry parsed out of a ``CHAPTER_SUMMARY`` block.
 *
 * Mirrors :class:`scabopdf_pipeline.reconstruction.types.SummaryItem`
 * in its JSON form. Populated by a corpus plugin's
 * ``refine_reconstruction`` when it recognises a chapter summary
 * structure (today only ``manuale_zanichelli_giuridica`` does so).
 *
 * ``number`` is a **string**, not an integer. The Patriarca-Benazzo
 * fixture uses only flat integers (``"1"``, ``"2"``, ...) for which
 * ``int`` would have been adequate, but other corpora are expected to
 * use composite numerations (``"1.1"``, ``"2-bis"``, ...) that an
 * ``int`` cannot represent. Keeping the field a string at v0.3.0
 * avoids a later breaking bump when those corpora arrive; Layer 2 can
 * always parse the string back to whatever structure it needs.
 *
 * ``title`` is the textual title of the chapter section, with internal
 * whitespace already normalised by the plugin (single spaces, no
 * leading or trailing whitespace, no line breaks).
 */
export interface ChapterSummaryItem {
  number: Number;
  title: Title;
}
/**
 * One entry parsed out of a ``TOC_GENERAL`` block.
 *
 * Mirrors :class:`scabopdf_pipeline.reconstruction.types.TocGeneralItem`
 * in its JSON form. Populated by a corpus plugin's
 * ``refine_reconstruction`` when it recognises a document-level table
 * of contents (today only ``compendio_utet`` does so).
 *
 * ``number`` and ``title`` follow the same convention as the matching
 * fields on :class:`ChapterSummaryItem`: strings to admit composite
 * numerations, with internal whitespace already normalised by the
 * plugin.
 *
 * ``page_number`` is the **1-based book page number** printed on the
 * TOC line. It is deliberately distinct from the 0-based ``PageIndex``
 * used everywhere else in the schema: ``PageIndex`` is the offset
 * PyMuPDF uses for ``Block.page`` and ``NodeDict.page_index``, while
 * ``page_number`` is what the manual advertises to the reader on the
 * physical printed page (and only there). The two coincide
 * accidentally for some manuals and diverge by a constant offset for
 * those with significant front matter; the plugin is responsible for
 * preserving the distinction. ``None`` when the plugin could not parse
 * a page reference from the entry — for instance when the printed
 * pagination is a non-numeric token like ``"III"`` that the plugin
 * elects to leave unparsed rather than encode fragile assumptions.
 */
export interface TocGeneralItem {
  number: Number1;
  title: Title1;
  page_number?: PageNumber;
}
/**
 * A directed apparatus reference attached to a node.
 *
 * Mirrors :class:`scabopdf_pipeline.apparatus.types.ApparatusRef` in its
 * JSON form. ``target_node_id`` must match the ``NodeDict.id`` pattern;
 * ``source_marker`` carries the textual marker for ``CROSS_REF_TARGET``
 * (e.g. ``"(1)"``) and is ``None`` for the other kinds, which are
 * resolved purely from spatial proximity.
 */
export interface ApparatusRefDict {
  kind: ApparatusRefKind;
  target_node_id: TargetNodeId;
  source_marker?: SourceMarker;
}
