# ruff: noqa: RUF001, RUF002
r"""Corpus plugin for the DeJure Dottrina genre.

Ninth real corpus plugin of the project and **third plugin operating
on the Aspose.PDF for .NET editorial pipeline** after the sister
:class:`~scabopdf_pipeline.profiles.dejure_nota_sentenza.DejureNotaSentenzaProfile`
and :class:`~scabopdf_pipeline.profiles.dejure_massime.DejureMassimeProfile`.
Handles the Giuffrè DeJure "Dottrina" export of free-standing academic
articles, distinct from the sibling genres DeJure Note a Sentenza
(academic commentary on a specific judicial decision) and DeJure
Massime (case-law summaries) that share the same Aspose pipeline. See
``docs/analysis/ANALYSIS_DEJURE_DOTTRINA.md`` for the editorial analysis
the plugin is built against; the analysis is explicitly marked as
"PRIMA — basata su due campioni" and the empirical PyMuPDF inspection
performed at the start of this plugin session has revised several of
its visually-estimated values.

The plugin is calibrated on three private fixtures that span the
continuum of the genre, including a **multi-article bundle** archetype
not anticipated by the analysis:

- ``pipeline/tests/fixtures/private/dejure_dt_bundle_procedura_civile.pdf`` —
  56-page export packaging **three** independent articles back-to-back
  in a single PDF (Gabellini, Carosi, Capasso, all from the Rivista
  Trimestrale di Diritto e Procedura Civile fasc. 2/2025, on civil
  procedure reform topics), each delimited by its own ``DOTTRINA``
  banner and ``Note:`` section. The articles are short-to-medium narrative pieces
  whose section headings are typeset **inline at body weight**
  (``ArialMT`` 12pt regular, format ``"N. — text"`` opening
  a body paragraph). This corpus exercises the multi-article bundle
  pattern (pattern (uu)) and the "no separate heading block" style
  (Style B in the plugin's vocabulary).

- ``pipeline/tests/fixtures/private/dejure_dt_concause_causalita.pdf`` —
  59-page single-article export by Rizzo on causality in civil
  liability law, with a dense apparatus of 96 footnotes that includes
  two **mega-notes** (note 15 at ~11,366 chars, note 46 at ~7,955
  chars), a HEADING_2 sub-section level (4.1, 4.2), and an editorial
  note ``(*) Contributo approvato dai Referee...`` fused into the
  ``Note:`` section label block by PyMuPDF. Section headings here are
  separate Arial-BoldMT 12pt UPPERCASE blocks (Style A). Cross-page
  rate on the footnotes is 13.5 % (13 of 96 span more than one page).

- ``pipeline/tests/fixtures/private/dejure_dt_riforma_cartabia.pdf`` —
  184-page massive bundle packaging **seven** independent articles
  on the Cartabia judicial reform. Several articles carry a bilingual
  title (Italian + " - " + English subtitle), several authors per
  article (the multi-author case ``"Francesco Callari,Vittorio
  Coppola"`` etc.), and each article has its own editorial note ``(*)``
  alongside or in place of its numbered notes. Section headings on
  this fixture are uniformly Style A (Arial-BoldMT 12pt UPPERCASE).

The three fixtures combined exercise every Dottrina pattern the
analysis describes plus three patterns the analysis explicitly marked
as "non osservato" or "DA VERIFICARE": multi-author values in the
``Autori:`` field with comma separator, bilingual titles with the
" - " separator, and multi-article bundles per PDF.

The plugin extends the ScaboPDF profile vocabulary along three new
dimensions:

- **Multi-article bundle handling.** Two of the three calibrating
  fixtures are bundles of multiple independent articles in one PDF,
  separated only by the visual ``DOTTRINA`` banner. Each article has
  its own banner → title → meta → sommario → headings → body →
  ``Note:`` → notes sequence. The plugin recognises every banner as
  an article boundary and scopes per-article all the structural
  transformations (notes consolidation, cross-reference binding) so
  that two articles with overlapping marker numbering (both have
  notes (1)..(N), both have headings ``1.``..``N.``) do not
  cross-pollute. See pattern (uu) in :doc:`/CLAUDE.md`.

- **Per-article apparatus scope** in :meth:`refine_apparatus`. Unlike
  the sister NS plugin which binds cross-references globally across
  the whole document, the DT plugin scopes binding to the article
  boundaries established by consecutive ``GENRE_BANNER`` Nodes. This
  is the same intuition behind the Marrone per-chapter scope (pattern
  (ll)) and the Torrente global scope (pattern (dd)), but with a
  different scope unit (article).

- **EDITORIAL_NOTE category in production for the first time.** The
  schema 0.5.0 ``SemanticCategory`` enum declares ``EDITORIAL_NOTE``
  for the academic "(*) Contributo approvato dai Referee..." style
  note that prefixes the numbered notes section in many Dottrina
  articles. The plugin recognises the ``(*)`` chunk in the notes
  section text and mints it as an ``EDITORIAL_NOTE`` Node distinct
  from the ``(N)`` ``NOTE`` Nodes the numbered notes splitter mints.
  No schema bump is required.

Structural patterns introduced by this plugin (numbered after the MM
plugin's (tt) per the CLAUDE.md convention):

- **(uu) Multi-article bundle handling via banner-bounded scope.**
  When a single PDF contains multiple structurally complete articles
  delimited by an editorial banner (DeJure ``DOTTRINA``, plausibly
  other editorial banners in future corpora), the plugin treats each
  banner occurrence as an article boundary and scopes every
  per-article structural transformation (notes consolidation, CR
  binding, editorial note extraction) to the span between consecutive
  banners. The implementation uses a single helper
  :meth:`_compute_article_boundaries` that returns the list of
  ``(banner_node, next_banner_node)`` pairs in pre-order DFS, then
  every transformation consumes those pairs to limit its walk. The
  pattern is reusable by any future plugin whose corpus packages
  multiple independent units inside one PDF (e.g. a journal issue
  delivered as a single PDF, an academic compendium of essays).

- **(vv) Three-way bidirectional matches() symmetry via SpecificMarker.**
  The DT plugin and its two sister plugins (NS, MM) all target the
  Aspose-Arial-Letter pipeline and would mutually clear the 0.6
  dispatcher threshold on each other's fixtures based on typographic
  signature alone. NS and DT in particular share every signal
  (13pt bold title, 9pt bold banner, 12pt regular body, Letter
  geometry, Aspose producer). The discriminator that the analysis
  identifies is **the banner text** itself: ``"DOTTRINA"`` for DT
  documents, ``"NOTE E DOTTRINA"`` for NS documents. The plugin
  encodes this discriminator via a :class:`SpecificMarker` named
  ``"dejure_banner_text"`` carrying the verbatim banner text scanned
  by the signal builder; both NS and DT consume this marker
  symmetrically. When the marker is absent (unit-test signals), the
  plugins fall back to their full positive scores; the symmetry only
  kicks in on real fixtures via the test signal builder. The pattern
  generalises pattern (ss) (two-way symmetry via typographic
  presence/absence) to three plugins where the discriminator is a
  semantic textual signal not captured by any pre-existing dataclass
  field.

- **(ww) EDITORIAL_NOTE minted alongside NOTE splitter via extended
  split regex.** The body+notes splitter framework that NS, Mandrioli
  and BIC introduced is signal-agnostic on the marker shape; the DT
  plugin extends the splitter regex from ``r"(?=\(\d+\)\s)"`` (NS
  numeric-only) to ``r"(?=\(\d+\)\s|\(\*\)\s|\(\*\) )"`` so the
  editorial ``(*)`` chunk is recognised as its own segment. The
  chunk minted from the ``(*)`` segment receives category
  :data:`SemanticCategory.EDITORIAL_NOTE` instead of ``NOTE``; the
  per-Node warning vocabulary distinguishes the two via the
  ``editorial_note_minted_*`` template versus the
  ``note_section_split_minted_*`` template. This is the first plugin
  in the project that lights up the ``EDITORIAL_NOTE`` category in
  production; no schema bump is required because the category was
  already declared in the 0.5.0 ``SemanticCategory`` enum.

The empirical inspection (PyMuPDF 1.27.2.3) of the three DT fixtures
reports the following typographic system, **confirmed empirically**
and revising the visually-estimated values of the analysis:

- **Banner** ``"DOTTRINA"`` at ``Arial-BoldMT`` 9pt, light-blue
  colour ``#98B0E3`` (vector glyphs; the colour is informational and
  the predicate does not depend on it). One or more banner blocks per
  document; subsequent banners may sit at arbitrary y-positions on
  any page, marking sub-article boundaries within a bundle.
- **Title** at ``Arial-BoldMT`` 13pt. Bilingual titles use the literal
  separator ``" - "`` between the Italian and English fragments and
  are emitted as a single ``TITLE`` Node with the full text; Layer 2
  can split at presentation time if needed.
- **Metadata block** at ``ArialMT`` 9pt regular for the ``Fonte:`` and
  ``Autori:`` labels and either ``ArialMT`` 9pt regular or
  ``Arial-BoldMT`` 9pt bold for the values (Aspose alternates between
  the two; the plugin's predicate is font-flag agnostic). Crucially,
  the DT meta block contains exactly **two** label fields (``Fonte:``
  and ``Autori:``), no ``Nota a:`` field — the absence of ``Nota a:``
  is the canonical genre discriminator versus DeJure NS per analysis
  § 4.1.
- **Sommario** at ``ArialMT`` 12pt regular with the leading prose
  ``"Sommario"`` or ``"(*) Sommario"`` (when an editorial note is
  attached). Discriminated from body via the textual prefix.
- **Section heading Style A** at ``Arial-BoldMT`` 12pt with the
  pattern ``^\d+\.\s+[A-ZÀÈÉÌÒÓÙÚ]`` (numbered uppercase) — used by
  the concause and cartabia fixtures.
- **Section heading Style B** is **not classified** by this plugin:
  inline ``"N. — text"`` headings at ``ArialMT`` 12pt regular
  open a body paragraph in the bundle_procedura_civile fixture and have no
  separate block. The plugin leaves them inside BODY Nodes; Layer 2
  may detect the textual pattern at presentation time. Documented as
  a v1 limitation; a future enhancement could split the body Node and
  mint a synthetic HEADING_1 for the prefix.
- **Subsection heading** at ``Arial-BoldMT`` 12pt with the pattern
  ``^\d+\.\d+\.\s+`` (numbered N.M. prefix, mixed case) — used by
  concause's ``4.1.`` and ``4.2.`` and one cartabia heading.
- **Notes section label** ``"Note:"`` at ``Arial-BoldMT`` 12pt. May be
  emitted standalone or fused by Aspose with the immediate-next
  ``(*) editorial note`` and/or ``(1) `` first numbered note inside
  the same block.
- **Body** at ``ArialMT`` 12pt regular with inline ``Arial-ItalicMT``
  12pt italic for Latinisms and quotations.
- **Notes** at ``ArialMT`` 12pt regular — the same size as the body
  (unlike NS where notes are at 9pt). The notes are discriminated by
  their position after the ``Note:`` ``SECTION_LABEL`` marker, not by
  their typography. Inline cross-reference markers ``(N)`` appear in
  body text at ``ArialMT`` 12pt regular too, blending typographically
  with the surrounding body prose.
- **Footer** ``"Pagina N di M"`` at ``ArialItalic`` 12pt italic — same
  font name PyMuPDF emits for the NS and MM footers.
- **Copyright stamp** ``"SERVIZIO GESTIONE RISORSE DOCUMENTARIE..."``
  / ``"© Copyright Giuffrè Francis Lefebvre S.p.A. <year> <date>"`` at
  ``ArialMT`` 10.5pt — shared verbatim with NS and MM.

The empirical structural metrics on the three fixtures, post-tier-2:

- ``dejure_dt_bundle_procedura_civile`` (56 pp, 3-article bundle): 3
  GENRE_BANNER, 3 TITLE, 3 META_VALUE umbrellas decomposed into
  3 × (FONTE_VALUE + AUTHORS) = 6 sibling Nodes (no REFERRAL), 3
  TOC_GENERAL (per-article sommario), 0 HEADING_1 (Style B inline,
  not classified), 3 SECTION_LABEL ``Note:``, ~60+ NOTE (per-article
  sum), ~150+ CROSS_REFERENCE bound per-article, 56 ARTIFACT_FOOTER,
  1-3 ARTIFACT_STAMP.

- ``dejure_dt_concause_causalita`` (59 pp, single article): 1
  GENRE_BANNER, 1 TITLE, 1 META_VALUE umbrella decomposed into 2
  sibling Nodes (FONTE_VALUE + AUTHORS, no REFERRAL), 1 TOC_GENERAL,
  ~8 HEADING_1, ~2 HEADING_2 (4.1, 4.2 mixed-case sub-sections), 1
  SECTION_LABEL ``Note:``, 1 EDITORIAL_NOTE ``(*) Contributo...``,
  ~96 NOTE, ~96 CROSS_REFERENCE bound per-article, ~59 ARTIFACT_FOOTER,
  1-2 ARTIFACT_STAMP.

- ``dejure_dt_riforma_cartabia`` (184 pp, 7-article bundle): 7
  GENRE_BANNER, 7 TITLE, 7 META_VALUE umbrellas decomposed into
  7 × (FONTE_VALUE + AUTHORS) = 14 sibling Nodes, 7 TOC_GENERAL
  (one per article), ~30+ HEADING_1, ~1 HEADING_2, 7 SECTION_LABEL
  ``Note:``, ~5+ EDITORIAL_NOTE (articles 1, 6 and possibly more have
  ``(*)`` notes), ~250+ NOTE (per-article sum, several articles with
  ~50-100 notes), ~250+ CROSS_REFERENCE bound per-article, 184
  ARTIFACT_FOOTER, 1-3 ARTIFACT_STAMP.

Pipeline integration.

- :meth:`get_post_processing` returns ``["dehyphenate_with_log"]``.
  The Aspose pipeline does not hyphenate at line breaks (line wrap
  happens at word boundaries on Aspose layouts), so the dehyphenator
  is a no-op in practice; declaring it nevertheless keeps the contract
  with the generic step registry uniform across plugins. No
  ``merge_cross_page_notes`` because the body+notes splitter in
  :meth:`refine_reconstruction` already recovers each individual
  ``(N) ...`` chunk regardless of cross-page boundaries — the notes
  section is concatenated by Aspose into a single block (or a
  contiguous run of blocks) within each article, so cross-page note
  splitting is solved structurally at split time.

- :meth:`get_layouts_disabled` returns ``[]`` (every layout is enabled).
  Dottrina is the canonical target genre for Layout 4 (Dottrina
  Inline) per the analysis; Layouts 1-3 also apply because the
  document is plain prose with no genre-specific layout constraints.

- :meth:`refine_apparatus` performs three profile-specific actions:
  (a) compute the article boundaries from the pre-order DFS positions
  of every GENRE_BANNER Node; (b) walk every synthetic CROSS_REFERENCE
  Node minted in :meth:`refine_reconstruction` (tracked in
  :attr:`_minted_crossref_ids`), extract the marker, look up in the
  per-article ``marker → NOTE node_id`` index, and attach an
  :class:`ApparatusRef` of kind ``CROSS_REF_TARGET``; (c) filter the
  Document's warnings tuple to drop tier 1 generic resolver warnings
  on the plugin's synthetic Nodes (same convention as NS pattern).

Instance state.

- ``_pending_warnings``: queued warnings produced during
  :meth:`refine_classification` (which has no Document to attach
  them to) and flushed into ``Document.warnings`` by
  :meth:`refine_reconstruction`.
- ``_minted_crossref_ids``: set of synthetic CROSS_REFERENCE node ids
  produced in :meth:`refine_reconstruction`. Consumed by
  :meth:`refine_apparatus` for binding and tier 1 warning filtering.
- ``_minted_note_ids``: set of synthetic NOTE node ids produced in
  :meth:`refine_reconstruction` from the body+notes splitter.
- ``_minted_editorial_note_ids``: set of synthetic EDITORIAL_NOTE
  node ids produced in :meth:`refine_reconstruction` (separate from
  ``_minted_note_ids`` because EDITORIAL_NOTE Nodes are not
  cross-reference targets).

Closed warning vocabulary, prefix ``plugin:dejure_dottrina:``.
See :data:`WARNING_TEMPLATES` for the closed list.
"""

from __future__ import annotations

import re
from dataclasses import replace
from typing import ClassVar

from scabopdf_pipeline.apparatus.constants import (
    INLINE_PARENTHESISED_CROSSREF_REGEX as _CROSSREF_INLINE_PATTERN,
)
from scabopdf_pipeline.apparatus.constants import (
    LEADING_PARENTHESISED_NOTE_MARKER_REGEX as _NOTE_MARKER_PATTERN,
)
from scabopdf_pipeline.apparatus.resolver import filter_tier1_crossref_warnings
from scabopdf_pipeline.apparatus.types import ApparatusRef, ApparatusRefKind
from scabopdf_pipeline.classification.types import ClassifiedBlock
from scabopdf_pipeline.extraction.types import ExtractionResult
from scabopdf_pipeline.postprocessing.types import Transformation
from scabopdf_pipeline.profiles._dejure_shared import (
    ARIAL_BOLD_FAMILY,
    ARIAL_FAMILY_PREFIX,
    ARIAL_REGULAR_FAMILY,
    ASPOSE_PRODUCER_FRAGMENT,
    NOTES_MARKER_TEXT_VARIANTS,
    SPECIFIC_MARKER_BANNER_TEXT_NAME,
    consolidate_notes_section_children,
    match_notes_marker,
    maybe_mint_inline_cross_references,
    retag_notes_region_continuation,
    starts_with_notes_marker,
)
from scabopdf_pipeline.profiles._dejure_shared import (
    BANNER_TEXT_NOTE_E_DOTTRINA as BANNER_TEXT_NS_NOTE_E_DOTTRINA,
)
from scabopdf_pipeline.profiles._dejure_shared import (
    FOOTER_PATTERN as _FOOTER_PATTERN,
)
from scabopdf_pipeline.profiles._dejure_shared import (
    BlockView as _BlockView,
)
from scabopdf_pipeline.profiling.match_helpers import (
    find_specific_marker,
    has_font_signature,
    is_geometry_close,
    producer_or_creator_contains,
)
from scabopdf_pipeline.profiling.plugin import ProfilePlugin
from scabopdf_pipeline.profiling.profile import DisabledLayout
from scabopdf_pipeline.profiling.signals import ProfilingSignals
from scabopdf_pipeline.profiling.typography_constants import (
    APPARATUS_PRESENCE_THRESHOLD,
    SIZE_TOLERANCE,
)
from scabopdf_pipeline.reconstruction.minting import (
    NodeIdMinter,
    iter_nodes_pre_order,
    max_existing_node_counter,
)
from scabopdf_pipeline.reconstruction.types import (
    Document,
    Node,
    TocGeneralItem,
    compute_note_length_category,
)
from scabopdf_pipeline.schema.categories import SemanticCategory

WARNING_PREFIX = "plugin:dejure_dottrina"
"""Common prefix for every warning string this plugin may emit."""

WARNING_TEMPLATES: tuple[str, ...] = (
    "plugin:dejure_dottrina:metadata_block_unparseable_block_<idx>_page_<p>",
    "plugin:dejure_dottrina:metadata_field_minted_node_<id>_field_<name>",
    "plugin:dejure_dottrina:toc_general_parsed_node_<id>_items_<n>",
    "plugin:dejure_dottrina:toc_general_unparseable_node_<id>",
    "plugin:dejure_dottrina:section_heading_pattern_unmatched_block_<idx>_page_<p>",
    "plugin:dejure_dottrina:note_section_split_minted_node_<id>_page_<p>_marker_<n>",
    "plugin:dejure_dottrina:note_section_unparseable_node_<id>",
    "plugin:dejure_dottrina:editorial_note_minted_node_<id>_page_<p>",
    "plugin:dejure_dottrina:cross_reference_minted_node_<id>_page_<p>_marker_<n>",
    "plugin:dejure_dottrina:cross_reference_unresolved_node_<id>_marker_<n>",
)
"""Closed vocabulary of warnings the plugin may emit. Placeholders
are replaced with concrete values at emission time. Consumers should
match on the prefix.
"""

# ---------------------------------------------------------------------------
# Typographic family fragments and empirical sizes.

# ``ARIAL_FAMILY_PREFIX``, ``ARIAL_REGULAR_FAMILY``, ``ARIAL_BOLD_FAMILY``
# were promoted to :mod:`profiles._dejure_shared` (P-010).

BANNER_SIZE = 9.0
"""Size in points of the ``"DOTTRINA"`` banner and of the meta block
(label + value spans). Identical to the analysis-estimated 9pt.
"""

TITLE_SIZE = 13.0
"""Size in points of the article title. Empirically 13.0pt across
every fixture; the analysis estimated 14pt and is revised.
"""

BODY_SIZE = 12.0
"""Size in points of the body prose. Identical for body, italic inline,
footer, sommario, section headings (which share the body size and are
discriminated by bold flag + text pattern), ``Note:`` section label
and any other 12pt content.
"""

COPYRIGHT_SIZE = 10.5
"""Size in points of the copyright stamp at the bottom of the last page.
Shared verbatim with the NS and MM plugins.
"""

# ``SIZE_TOLERANCE`` was promoted to
# :mod:`scabopdf_pipeline.profiling.typography_constants` (P-036). The
# Aspose pipeline emits no measurable drift below the analysis-estimated
# round values (9.0, 10.5, 12.0, 13.0); the 0.15 cushion absorbs PyMuPDF
# noise while staying below the 0.5pt inter-category gap.

PAGE_WIDTH_LETTER = 612.0
"""Letter page width in points."""

PAGE_HEIGHT_LETTER = 792.0
"""Letter page height in points."""

PAGE_GEOMETRY_TOLERANCE = 1.0
"""Tolerance in points for the page geometry match."""

# ---------------------------------------------------------------------------
# Closed text predicates.

BANNER_TEXT_DOTTRINA = "DOTTRINA"
"""The literal banner text the plugin discriminates as ``GENRE_BANNER``."""

# ``BANNER_TEXT_NS_NOTE_E_DOTTRINA`` was promoted to
# :data:`profiles._dejure_shared.BANNER_TEXT_NOTE_E_DOTTRINA` (P-012);
# DT re-imports it under the legacy alias.

SOMMARIO_TEXT_PREFIX = "Sommario"
"""Text-prefix discriminator for the sommario block. Aspose may emit
either ``"Sommario "`` (bare) or ``"(*) Sommario "`` (with leading
editorial-note marker fused into the same block) depending on the
editorial template; both variants share the prose word ``"Sommario"``
after stripping the optional ``"(*) "`` prefix.
"""

EDITORIAL_NOTE_PREFIX = "(*)"
"""Literal prefix of the editorial note. Always followed by a space
or the U+2003 em-space character.
"""

# ``NOTES_MARKER_TEXT_VARIANTS`` was promoted to
# :mod:`profiles._dejure_shared` (P-016, Promotion Fase 3). Re-imported
# at the top of the module under the public name. The variants are
# shared with the NS sister plugin: Aspose has been observed to emit
# either ``Note:`` (compact) or ``Note :`` (space before the colon).

METADATA_LABEL_FONTE = "Fonte:"
"""Literal label prefix of the ``FONTE`` metadata line."""

METADATA_LABEL_AUTORI = "Autori:"
"""Literal label prefix of the ``AUTHORS`` metadata line."""

METADATA_LABEL_NOTA_A = "Nota a:"
"""Literal label prefix of the NS ``REFERRAL`` metadata line.

Used **only** to detect the absence of the field per analysis § 4.1:
a Dottrina meta block has Fonte: + Autori: but not Nota a:. A meta
block containing Nota a: is a Note a Sentenza and the plugin must
step back; the meta block predicate :meth:`_is_metadata_block`
matches the block as DT only if Nota a: is absent.
"""

# ``ASPOSE_PRODUCER_FRAGMENT`` was promoted to
# :mod:`profiles._dejure_shared` (P-011). Re-imported and re-exported.

COPYRIGHT_STAMP_TEXT_FRAGMENTS: tuple[str, ...] = (
    "SERVIZIO GESTIONE RISORSE",
    "© Copyright Giuffrè",
)
"""Text-fragment discriminators for the copyright stamp on the last
page. Shared verbatim with NS and MM.
"""

PAGE_HEADER_TEXT_FRAGMENT = "Banche dati editoriali GFL"
"""Text-fragment discriminator for the page-1 header tagline that sits
below the DeJure logo. Classified as ``ARTIFACT_PAGE_HEADER``.
"""

# ---------------------------------------------------------------------------
# SpecificMarker conventions for matches() discrimination.

# ``SPECIFIC_MARKER_BANNER_TEXT_NAME`` was promoted to
# :mod:`profiles._dejure_shared` (P-012).

# ---------------------------------------------------------------------------
# Regular expressions.

# ``_FOOTER_PATTERN`` was promoted to :data:`profiles._dejure_shared.FOOTER_PATTERN`
# (P-009).

_SECTION_HEADING_STYLE_A_PATTERN = re.compile(r"^(\d+)\.\s+[A-ZÀÈÉÌÒÓÙÚ«»]")
"""Pattern matching a Style-A numbered section heading at body weight.

Style A: ``"N. UPPERCASE TEXT"`` on its own Arial-BoldMT 12pt block.
Used by the concause and cartabia fixtures.
"""

_SUBSECTION_HEADING_PATTERN = re.compile(r"^(\d+)\.(\d+)\.\s+")
"""Pattern matching a sub-section heading ``"N.M. text"``.

Capture groups: outer section number and inner sub-section number.
Used to discriminate HEADING_2 from HEADING_1 within the same
Arial-BoldMT 12pt typographic signature.
"""

_SOMMARIO_TRIM_PATTERN = re.compile(r"^\s*(?:\(\*\)\s+)?Sommario\s*")
"""Pattern that strips the leading ``"Sommario"`` (or ``"(*) Sommario"``)
prefix from the sommario block before TOC parsing. Tolerates the
optional editorial-note marker that Aspose may fuse into the same
block.
"""

# ``_NOTE_MARKER_PATTERN`` was promoted to
# :data:`apparatus.constants.LEADING_PARENTHESISED_NOTE_MARKER_REGEX`
# (P-014).

_NOTE_SPLIT_PATTERN = re.compile(r"(?=\(\d+\)\s|\(\*\)\s|\(\*\) )")
"""Pattern used to split a concatenated notes block into individual
note pieces (numbered or editorial).

The positive look-ahead matches **before** a ``(N) ``, ``(*) `` or
``(*) `` chunk without consuming it. Extends the NS plugin's
numeric-only pattern (pattern (qq)) to recognise the editorial note
``(*)`` as a separate chunk, which the plugin then classifies as
``EDITORIAL_NOTE`` instead of ``NOTE`` (pattern (ww)).
"""

_EDITORIAL_NOTE_PREFIX_PATTERN = re.compile(r"^\(\*\)[\s ]+")
"""Pattern that recognises the editorial-note prefix at the start of
a chunk produced by :data:`_NOTE_SPLIT_PATTERN`.

Capture-less because the chunk text is preserved verbatim on the
minted Node.
"""

# ``_CROSSREF_INLINE_PATTERN`` was promoted to
# :data:`apparatus.constants.INLINE_PARENTHESISED_CROSSREF_REGEX` (P-014).
# Same shape as the NS plugin: any ``(N)`` not preceded by an open paren
# or by a digit. Magnitude cap remains plugin-local via
# :data:`_CROSSREF_MAX_MARKER_VALUE`.

_CROSSREF_MAX_MARKER_VALUE = 500
"""Magnitude cap on inline cross-reference markers.

Larger than the NS cap (99) because cartabia's longest article carries
~250 notes and the cap must accommodate every legitimate marker while
filtering out year references like ``(2024)``.
"""

# ---------------------------------------------------------------------------
# Match() confidence weights and thresholds.

CONFIDENCE_ARIAL_BODY_DOMINANT = 0.30
"""Confidence contribution when ``ArialMT`` 12pt dominates the
typographic signature above the body-share floor.

Same magnitude and rationale as the sister NS and MM plugins.
"""

CONFIDENCE_ASPOSE_PRODUCER = 0.20
"""Confidence contribution when the producer/creator string carries
the ``"Aspose.PDF"`` fragment.
"""

CONFIDENCE_LETTER_GEOMETRY = 0.10
"""Confidence contribution when the page geometry matches Letter."""

CONFIDENCE_TITLE_BOLD_PRESENT = 0.10
"""Confidence contribution when an ``Arial-BoldMT`` 13pt size is
present in the typographic signature.

The 13pt bold Arial is the DT title size, shared with NS. A DeJure
Aspose-Arial-Letter document with a 13pt bold span is a DT or NS
candidate (not MM); the discriminator versus NS is the banner text
encoded in the :data:`SPECIFIC_MARKER_BANNER_TEXT_NAME` SpecificMarker.
"""

CONFIDENCE_TITLE_BOLD_ABSENT_PENALTY = -0.20
"""Penalty when ``Arial-BoldMT`` 13pt is absent from the typographic
signature.

Symmetric counterpart to the homonymous penalty in the sister NS
plugin (which calls it ``CONFIDENCE_TITLE_BOLD_ABSENT_PENALTY``).
Without this penalty, an Aspose-Arial-Letter document with only
9pt and 12pt bold sizes (a DeJure Massime export) would clear the
0.6 dispatcher threshold on DT at score 0.70 and mis-route every
Massime fixture to the DT plugin. The penalty drops the score to
0.50 on Massime, comfortably below threshold, while leaving genuine
DT fixtures (which carry the 13pt bold title) at their 0.80 baseline.
This is symmetric pattern (vv) between DT and MM, paralleling the
(ss) pattern that NS and MM established for the same MM
discrimination.
"""

CONFIDENCE_BANNER_BOLD_PRESENT = 0.10
"""Confidence contribution when an ``Arial-BoldMT`` 9pt size is present
in the typographic signature.

The 9pt bold Arial is the DT banner and metadata-value size.
"""

CONFIDENCE_OTHER_BODY_FAMILY_PENALTY = -0.40
"""Penalty when the dominant body family is not Arial."""

CONFIDENCE_MARGINAL_APPARATUS_PENALTY = -0.20
"""Penalty when the document carries a substantial marginal-heading
apparatus (Torrente, Mosconi, Mandrioli manuals).
"""

CONFIDENCE_NS_BANNER_PRESENT_PENALTY = -0.25
"""Penalty when the :data:`SPECIFIC_MARKER_BANNER_TEXT_NAME`
SpecificMarker carries the value ``"NOTE E DOTTRINA"``.

The discriminator versus the sister NS plugin (pattern (vv)). NS
documents have a different banner text than DT; when the signal
builder reports the NS banner on a document, the DT plugin must step
back. The symmetric penalty applies on the NS side when the marker
reports ``"DOTTRINA"``.
"""

BODY_DOMINANCE_MIN_PERCENT = 40.0
"""Minimum body-family dominance percent to credit the body signal."""

# ``APPARATUS_PRESENCE_THRESHOLD`` was promoted to
# :mod:`scabopdf_pipeline.profiling.typography_constants` (P-035).

# ``_NOTES_SECTION_BOUNDARY_CATEGORIES`` and
# ``_NOTES_SECTION_PASSTHROUGH_CATEGORIES`` were promoted to
# :mod:`profiles._dejure_shared` (P-017, Promotion Fase 3) as
# ``NOTES_SECTION_BOUNDARY_CATEGORIES`` and
# ``NOTES_SECTION_PASSTHROUGH_CATEGORIES`` respectively. The DT
# convention is identical to NS: GENRE_BANNER closes the absorption
# at the next article boundary inside a multi-article bundle.

# ---------------------------------------------------------------------------
# Helpers — block view, node-id minter, max-existing-counter walker.


# ``_BlockView`` was promoted to :class:`profiles._dejure_shared.BlockView`
# (P-013).


# ---------------------------------------------------------------------------
# Main class.


class DejureDottrinaProfile(ProfilePlugin):
    """Corpus plugin for the Giuffrè DeJure Dottrina genre.

    Ninth real corpus plugin of the project; see the module docstring
    for the full editorial and structural rationale.
    """

    profile_id: ClassVar[str] = "dejure_dottrina"
    editorial_family: ClassVar[str] = "dejure"
    genre: ClassVar[str] = "dottrina"

    def __init__(self) -> None:
        self._pending_warnings: list[str] = []
        self._minted_crossref_ids: set[str] = set()
        self._minted_note_ids: set[str] = set()
        self._minted_editorial_note_ids: set[str] = set()

    # ------------------------------------------------------------------
    # ProfilePlugin declarative methods

    @classmethod
    def get_warning_templates(cls) -> tuple[str, ...]:
        return WARNING_TEMPLATES

    @classmethod
    def matches(cls, signals: ProfilingSignals) -> float:
        """Score the document against the DeJure Dottrina fingerprint.

        Five positive contributions (Arial body dominance, Aspose
        producer, Letter geometry, 13pt bold title family, 9pt bold
        banner family) and three penalties (non-Arial body family,
        NS banner present on the fixture, substantial marginal-heading
        apparatus). The bidirectional discrimination versus the sister
        NS plugin uses the :data:`SPECIFIC_MARKER_BANNER_TEXT_NAME`
        SpecificMarker emitted by the real-fixture signal builder
        (pattern (vv) in the module docstring); unit-test signals built
        by hand without the marker fall back to the full positive score.
        """
        score = 0.0

        if has_font_signature(
            signals,
            family_predicate=ARIAL_REGULAR_FAMILY,
            size=BODY_SIZE,
            tolerance=SIZE_TOLERANCE,
            min_dominance=BODY_DOMINANCE_MIN_PERCENT,
        ):
            score += CONFIDENCE_ARIAL_BODY_DOMINANT
        else:
            arial_family_dominant = any(
                font.family.startswith(ARIAL_FAMILY_PREFIX)
                and font.dominance_percent >= BODY_DOMINANCE_MIN_PERCENT
                for font in signals.typographic_signature.fonts
            )
            if not arial_family_dominant:
                score += CONFIDENCE_OTHER_BODY_FAMILY_PENALTY

        if producer_or_creator_contains(signals, ASPOSE_PRODUCER_FRAGMENT):
            score += CONFIDENCE_ASPOSE_PRODUCER

        if is_geometry_close(
            signals,
            width=PAGE_WIDTH_LETTER,
            height=PAGE_HEIGHT_LETTER,
            tolerance=PAGE_GEOMETRY_TOLERANCE,
            strict=True,
        ):
            score += CONFIDENCE_LETTER_GEOMETRY

        title_bold_present = has_font_signature(
            signals,
            family_predicate=ARIAL_BOLD_FAMILY,
            size=TITLE_SIZE,
            tolerance=SIZE_TOLERANCE,
        )
        if title_bold_present:
            score += CONFIDENCE_TITLE_BOLD_PRESENT
        else:
            score += CONFIDENCE_TITLE_BOLD_ABSENT_PENALTY

        if has_font_signature(
            signals,
            family_predicate=ARIAL_BOLD_FAMILY,
            size=BANNER_SIZE,
            tolerance=SIZE_TOLERANCE,
        ):
            score += CONFIDENCE_BANNER_BOLD_PRESENT

        if signals.apparatus_presence.marginal_headings >= APPARATUS_PRESENCE_THRESHOLD:
            score += CONFIDENCE_MARGINAL_APPARATUS_PENALTY

        # Pattern (vv) — discriminator vs sister NS plugin via banner text.
        marker = find_specific_marker(signals, SPECIFIC_MARKER_BANNER_TEXT_NAME)
        if marker is not None and marker.value == BANNER_TEXT_NS_NOTE_E_DOTTRINA:
            score += CONFIDENCE_NS_BANNER_PRESENT_PENALTY

        return max(0.0, score)

    def get_categories(self) -> set[SemanticCategory]:
        """Closed set of categories the plugin may emit.

        Includes the DT-specific structural set and the artifact
        carriers inherited from tier 1.
        """
        return {
            SemanticCategory.HEADING_1,
            SemanticCategory.HEADING_2,
            SemanticCategory.BODY,
            SemanticCategory.NOTE,
            SemanticCategory.EDITORIAL_NOTE,
            SemanticCategory.CROSS_REFERENCE,
            SemanticCategory.TITLE,
            SemanticCategory.GENRE_BANNER,
            SemanticCategory.META_VALUE,
            SemanticCategory.FONTE_VALUE,
            SemanticCategory.AUTHORS,
            SemanticCategory.SECTION_LABEL,
            SemanticCategory.TOC_GENERAL,
            SemanticCategory.ARTIFACT_PAGE_HEADER,
            SemanticCategory.ARTIFACT_RUNNING_HEADER,
            SemanticCategory.ARTIFACT_FOOTER,
            SemanticCategory.ARTIFACT_STAMP,
            SemanticCategory.UNCLASSIFIED,
            SemanticCategory.EMPTY_PAGE,
        }

    def get_post_processing(self) -> list[str]:
        """Return ``["dehyphenate_with_log"]``.

        See module docstring for the rationale.
        """
        return ["dehyphenate_with_log"]

    def get_layouts_disabled(self) -> list[DisabledLayout]:
        """Return the empty list — every layout is enabled."""
        return []

    # ------------------------------------------------------------------
    # Tier 2 refinement hooks

    def refine_classification(
        self,
        extraction: ExtractionResult,
        tier1_results: list[ClassifiedBlock],
    ) -> list[ClassifiedBlock]:
        """Promote tier 1 verdicts to the plugin's DT-specific vocabulary.

        Single-pass predicate cascade over every tier 1 verdict (rescue
        from ARTIFACT_RUNNING_HEADER for the banner, pattern (ii)-style),
        followed by a second pass that retags BODY blocks inside any
        notes region as NOTE (pattern (pp)-style adapted to multi-article
        bundles: each ``Note:`` SECTION_LABEL opens a notes region that
        closes at the next ``GENRE_BANNER`` or any other structural
        boundary).
        """
        self._pending_warnings = []
        self._minted_crossref_ids = set()
        self._minted_note_ids = set()
        self._minted_editorial_note_ids = set()

        # Pass 1: predicate cascade.
        refined: list[ClassifiedBlock] = []
        for verdict in tier1_results:
            if verdict.block_index < 0:
                refined.append(verdict)
                continue
            view = self._view(extraction, verdict.block_index)
            if view is None:
                refined.append(verdict)
                continue
            refined.append(self._reclassify(verdict, view))

        # Pass 2: stateful retagging — every BODY inside a notes region
        # becomes NOTE so the tier 1 cross-page paragraph merger does
        # not fuse it with the body paragraphs of the enclosing section.
        # The notes region opens at each ``"Note:"`` SECTION_LABEL and
        # closes at the next ``GENRE_BANNER`` (article boundary), to
        # scope the region per-article inside a multi-article bundle —
        # this is the only structural difference vs the NS sister plugin,
        # which carries a single notes region per document.
        return retag_notes_region_continuation(
            refined,
            is_notes_section_label=lambda v: self._is_notes_section_label(extraction, v),
            reason="dejure_dottrina_notes_region_continuation",
            article_boundary_categories=frozenset({SemanticCategory.GENRE_BANNER}),
        )

    def _is_notes_section_label(
        self, extraction: ExtractionResult, verdict: ClassifiedBlock
    ) -> bool:
        """Predicate consumed by :func:`retag_notes_region_continuation`.

        Returns ``True`` when ``verdict`` (already known to be a
        ``SECTION_LABEL``) carries one of the closed-set notes marker
        variants.
        """
        view = self._view(extraction, verdict.block_index)
        return view is not None and starts_with_notes_marker(view.text)

    def refine_reconstruction(
        self,
        document: Document,
        extraction: ExtractionResult,
        classified_blocks: list[ClassifiedBlock],
    ) -> Document:
        """Decompose META_VALUE, parse TOC_GENERAL, split notes block, mint inline CR.

        Four structural transformations on the tier 1 tree, scoped
        per-article (each article delimited by consecutive
        ``GENRE_BANNER`` Nodes). See module docstring patterns (uu),
        (ww) for the multi-article and editorial-note design.
        """
        del classified_blocks

        new_warnings = list(self._pending_warnings)
        self._pending_warnings = []
        new_transformations: list[Transformation] = []

        minter = NodeIdMinter(start=max_existing_node_counter(document.root) + 1)

        new_roots = self._refine_forest(document.root, new_warnings, new_transformations, minter)

        return Document(
            root=new_roots,
            warnings=tuple(document.warnings) + tuple(new_warnings),
            transformations=document.transformations + tuple(new_transformations),
        )

    def refine_apparatus(
        self,
        document: Document,
        extraction: ExtractionResult,
        classified_blocks: list[ClassifiedBlock],
    ) -> Document:
        """Bind synthetic CROSS_REFERENCE Nodes per-article (pattern (vv)).

        Three responsibilities, scoped per-article:

        1. Compute article boundaries from the pre-order DFS positions
           of every ``GENRE_BANNER`` Node.
        2. For each article, build a local ``marker → NOTE node_id``
           index over the NOTE Nodes (tracked in
           :attr:`_minted_note_ids`) falling within the article scope,
           and bind every CROSS_REFERENCE Node within the same article
           via the index.
        3. Filter the tier 1 generic resolver warnings on the plugin's
           synthetic Nodes (same convention as NS pattern).
        """
        del extraction, classified_blocks

        all_nodes = iter_nodes_pre_order(document.root)
        article_boundaries = self._compute_article_boundaries(all_nodes)
        new_root, new_warnings = self._bind_cross_references_per_article(
            document.root, all_nodes, article_boundaries
        )
        filtered_warnings = self._filter_tier1_crossref_warnings(document.warnings)

        return Document(
            root=new_root,
            warnings=filtered_warnings + tuple(new_warnings),
            transformations=document.transformations,
        )

    # ------------------------------------------------------------------
    # Per-block reclassification

    def _reclassify(self, verdict: ClassifiedBlock, view: _BlockView) -> ClassifiedBlock:
        # Pattern (ii)-style rescue from ARTIFACT_RUNNING_HEADER for the
        # banner and page-1 tagline: tier 1 absorbs both into the running
        # header zone heuristic; the plugin must override.
        if self._is_genre_banner(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.GENRE_BANNER,
                reason="dejure_dottrina_banner",
            )
        if self._is_page_header_tagline(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.ARTIFACT_PAGE_HEADER,
                reason="dejure_dottrina_page_header_tagline",
            )
        if self._is_title(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.TITLE,
                reason="dejure_dottrina_title",
            )
        if self._is_metadata_block(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.META_VALUE,
                reason="dejure_dottrina_metadata_block",
            )
        if self._is_sommario_block(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.TOC_GENERAL,
                reason="dejure_dottrina_sommario",
            )
        if self._is_subsection_heading(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.HEADING_2,
                reason="dejure_dottrina_subsection_heading",
            )
        if self._is_section_heading(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.HEADING_1,
                reason="dejure_dottrina_section_heading",
            )
        if self._is_notes_section(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.SECTION_LABEL,
                reason="dejure_dottrina_notes_section",
            )
        if self._is_footer(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.ARTIFACT_FOOTER,
                reason="dejure_dottrina_footer",
            )
        if self._is_copyright_stamp(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.ARTIFACT_STAMP,
                reason="dejure_dottrina_copyright_stamp",
            )
        if self._is_body(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.BODY,
                reason="dejure_dottrina_body",
            )
        return verdict

    # ------------------------------------------------------------------
    # Predicates

    @staticmethod
    def _is_genre_banner(view: _BlockView) -> bool:
        """Banner ``"DOTTRINA"`` at Arial-BoldMT 9pt."""
        if not view.spans:
            return False
        leading = view.spans[0]
        family_ok = leading.font.startswith(ARIAL_BOLD_FAMILY)
        size_ok = abs(leading.size - BANNER_SIZE) < SIZE_TOLERANCE
        if not (family_ok and size_ok):
            return False
        return view.text.strip() == BANNER_TEXT_DOTTRINA

    @staticmethod
    def _is_page_header_tagline(view: _BlockView) -> bool:
        """Page-1 header tagline ``"Banche dati editoriali GFL"``."""
        return PAGE_HEADER_TEXT_FRAGMENT in view.text

    @staticmethod
    def _is_title(view: _BlockView) -> bool:
        """Title block at Arial-BoldMT 13pt.

        Bilingual titles (with " - " separator between Italian and
        English fragments) and Italian-only titles share the same
        typographic signature and are emitted as a single TITLE Node;
        Layer 2 splits at presentation time if needed.
        """
        if not view.spans:
            return False
        leading = view.spans[0]
        family_ok = leading.font.startswith(ARIAL_BOLD_FAMILY)
        size_ok = abs(leading.size - TITLE_SIZE) < SIZE_TOLERANCE
        return family_ok and size_ok

    @staticmethod
    def _is_metadata_block(view: _BlockView) -> bool:
        """Metadata block at 9pt Arial containing Fonte: and/or Autori:
        but NOT Nota a: (the canonical discriminator vs NS per
        analysis § 4.1).

        The plugin's predicate is font-flag agnostic on the leading
        span (admits either Arial-BoldMT or ArialMT) and matches the
        block as a whole on its 9pt size plus the textual presence of
        at least one DT-specific label and the absence of the NS
        ``Nota a:`` label. A block containing Nota a: is a DeJure NS
        meta block and the plugin must step back to let the sister NS
        plugin classify it.
        """
        if not view.spans:
            return False
        leading = view.spans[0]
        family_ok = leading.font.startswith(ARIAL_FAMILY_PREFIX)
        size_ok = abs(leading.size - BANNER_SIZE) < SIZE_TOLERANCE
        if not (family_ok and size_ok):
            return False
        text = view.text
        if METADATA_LABEL_NOTA_A in text:
            return False
        return METADATA_LABEL_FONTE in text or METADATA_LABEL_AUTORI in text

    @staticmethod
    def _is_sommario_block(view: _BlockView) -> bool:
        """Sommario block at ArialMT 12pt starting with ``"Sommario"`` or
        ``"(*) Sommario"``.
        """
        if not view.spans:
            return False
        leading = view.spans[0]
        family_ok = leading.font.startswith(ARIAL_REGULAR_FAMILY) or leading.font.startswith(
            ARIAL_BOLD_FAMILY
        )
        size_ok = abs(leading.size - BODY_SIZE) < SIZE_TOLERANCE
        if not (family_ok and size_ok):
            return False
        return bool(_SOMMARIO_TRIM_PATTERN.match(view.text))

    @staticmethod
    def _is_subsection_heading(view: _BlockView) -> bool:
        """Subsection heading at Arial-BoldMT 12pt with ``"N.M. text"`` pattern."""
        if not view.spans:
            return False
        leading = view.spans[0]
        family_ok = leading.font.startswith(ARIAL_BOLD_FAMILY)
        size_ok = abs(leading.size - BODY_SIZE) < SIZE_TOLERANCE
        if not (family_ok and size_ok):
            return False
        return bool(_SUBSECTION_HEADING_PATTERN.match(view.text.strip()))

    @staticmethod
    def _is_section_heading(view: _BlockView) -> bool:
        """Section heading Style A at Arial-BoldMT 12pt with ``"N. UPPERCASE"`` pattern.

        Style B inline headings (ArialMT 12pt regular with format
        ``"N. — text"``) are NOT classified here; they remain
        inside BODY Nodes. Layer 2 may detect them at presentation time.
        """
        if not view.spans:
            return False
        leading = view.spans[0]
        family_ok = leading.font.startswith(ARIAL_BOLD_FAMILY)
        size_ok = abs(leading.size - BODY_SIZE) < SIZE_TOLERANCE
        if not (family_ok and size_ok):
            return False
        return bool(_SECTION_HEADING_STYLE_A_PATTERN.match(view.text.strip()))

    @staticmethod
    def _is_notes_section(view: _BlockView) -> bool:
        """``"Note:"`` opening marker — standalone or glued with editorial-
        and-numbered notes content.

        Aspose may emit ``Note:`` standalone or fuse it with the
        immediately-following ``(*)`` editorial note and/or ``(1) ``
        first numbered note inside the same block. The predicate
        accepts both cases; the body+notes splitter in
        :meth:`refine_reconstruction` peels off the chunks.
        """
        if not view.spans:
            return False
        leading = view.spans[0]
        family_ok = leading.font.startswith(ARIAL_BOLD_FAMILY)
        size_ok = abs(leading.size - BODY_SIZE) < SIZE_TOLERANCE
        if not (family_ok and size_ok):
            return False
        stripped = view.text.strip()
        return any(
            stripped == marker or stripped.startswith(marker)
            for marker in NOTES_MARKER_TEXT_VARIANTS
        )

    @staticmethod
    def _is_footer(view: _BlockView) -> bool:
        """Footer ``"Pagina N di M"`` at Arial italic 12pt."""
        if not view.spans:
            return False
        leading = view.spans[0]
        family_ok = leading.font.startswith(ARIAL_FAMILY_PREFIX)
        size_ok = abs(leading.size - BODY_SIZE) < SIZE_TOLERANCE
        italic_ok = leading.is_italic
        if not (family_ok and size_ok and italic_ok):
            return False
        return bool(_FOOTER_PATTERN.match(view.text.strip()))

    @staticmethod
    def _is_copyright_stamp(view: _BlockView) -> bool:
        """Copyright stamp at ArialMT 10.5pt with one of the closed fragments."""
        if not view.spans:
            return False
        leading = view.spans[0]
        family_ok = leading.font.startswith(ARIAL_REGULAR_FAMILY)
        size_ok = abs(leading.size - COPYRIGHT_SIZE) < SIZE_TOLERANCE
        if not (family_ok and size_ok):
            return False
        return any(fragment in view.text for fragment in COPYRIGHT_STAMP_TEXT_FRAGMENTS)

    @staticmethod
    def _is_body(view: _BlockView) -> bool:
        """Body prose at Arial 12pt non-bold."""
        if not view.spans:
            return False
        leading = view.spans[0]
        family_ok = leading.font.startswith(ARIAL_FAMILY_PREFIX)
        size_ok = abs(leading.size - BODY_SIZE) < SIZE_TOLERANCE
        not_bold = not leading.is_bold
        return family_ok and size_ok and not_bold

    # ------------------------------------------------------------------
    # Refine reconstruction: META decomposition + TOC + notes split + CR mint

    def _refine_forest(
        self,
        roots: tuple[Node, ...],
        warnings: list[str],
        transformations: list[Transformation],
        minter: NodeIdMinter,
    ) -> tuple[Node, ...]:
        """Walk the forest level by level, refining descendants first,
        then applying sibling-aware transformations to each children list.
        """
        refined_roots: list[Node] = []
        for root in roots:
            new_children = self._refine_forest(root.children, warnings, transformations, minter)
            if new_children != root.children:
                root = replace(root, children=new_children)
            refined_roots.append(root)
        return self._refine_children_list(tuple(refined_roots), warnings, transformations, minter)

    def _refine_children_list(
        self,
        children: tuple[Node, ...],
        warnings: list[str],
        transformations: list[Transformation],
        minter: NodeIdMinter,
    ) -> tuple[Node, ...]:
        """Apply the three refinement passes to a parent's children list."""
        # PASS 1: per-Node refinement (META + TOC).
        pass1: list[Node] = []
        for child in children:
            if child.category is SemanticCategory.META_VALUE and child.text is not None:
                pass1.extend(self._decompose_metadata(child, warnings, transformations, minter))
            elif child.category is SemanticCategory.TOC_GENERAL and child.text is not None:
                pass1.extend(self._parse_toc_general(child, warnings))
            else:
                pass1.append(child)

        # PASS 2: notes consolidation across siblings.
        pass2 = self._consolidate_notes_sections(tuple(pass1), warnings, transformations, minter)

        # PASS 3: CR minting on body Nodes only.
        pass3: list[Node] = []
        for child in pass2:
            if (
                child.text is not None
                and child.category in {SemanticCategory.BODY, SemanticCategory.HEADING_1}
                and child.id not in self._minted_note_ids
                and child.id not in self._minted_editorial_note_ids
            ):
                pass3.extend(
                    maybe_mint_inline_cross_references(
                        child,
                        pattern=_CROSSREF_INLINE_PATTERN,
                        max_marker_value=_CROSSREF_MAX_MARKER_VALUE,
                        warning_prefix=WARNING_PREFIX,
                        minter=minter,
                        warnings=warnings,
                        minted_crossref_ids=self._minted_crossref_ids,
                    )
                )
            else:
                pass3.append(child)
        return tuple(pass3)

    # ------------------------------------------------------------------
    # Metadata decomposition

    def _decompose_metadata(
        self,
        host: Node,
        warnings: list[str],
        transformations: list[Transformation],
        minter: NodeIdMinter,
    ) -> list[Node]:
        """Split a META_VALUE Node into FONTE_VALUE + AUTHORS siblings.

        The DT meta block has exactly two label fields (no Nota a:).
        The decomposition uses a positive-look-ahead regex split on the
        two label markers; multi-author values are preserved verbatim
        in the AUTHORS Node text (comma-separated).
        """
        assert host.text is not None
        chunks = re.split(r"(?=Fonte:|Autori:)", host.text)

        fonte_line: str | None = None
        autori_line: str | None = None
        for chunk in chunks:
            stripped = chunk.strip()
            if stripped.startswith(METADATA_LABEL_FONTE):
                fonte_line = stripped
            elif stripped.startswith(METADATA_LABEL_AUTORI):
                autori_line = stripped

        if not (fonte_line and autori_line):
            block_idx = host.block_indices[0] if host.block_indices else -1
            warnings.append(
                f"{WARNING_PREFIX}:metadata_block_unparseable_block_"
                f"{block_idx}_page_{host.page_index}"
            )
            return [host]

        minted: list[Node] = []
        minted_ids: list[str] = []
        for line, category, field_name in (
            (fonte_line, SemanticCategory.FONTE_VALUE, "fonte"),
            (autori_line, SemanticCategory.AUTHORS, "authors"),
        ):
            new_id = minter.mint()
            minted.append(
                Node(
                    id=new_id,
                    category=category,
                    page_index=host.page_index,
                    block_indices=host.block_indices,
                    text=line,
                )
            )
            minted_ids.append(new_id)
            warnings.append(
                f"{WARNING_PREFIX}:metadata_field_minted_node_{new_id}_field_{field_name}"
            )

        transformations.append(
            Transformation(
                step_id="dejure_dottrina_metadata_decompose",
                node_id=host.id,
                page_index=host.page_index,
                position=(0, len(host.text)),
                original=host.text,
                normalized="",
                split_into=tuple(minted_ids),
            )
        )
        return minted

    # ------------------------------------------------------------------
    # TOC_GENERAL parsing

    def _parse_toc_general(
        self,
        node: Node,
        warnings: list[str],
    ) -> list[Node]:
        """Parse a TOC_GENERAL Node into ``toc_items`` by stripping the
        ``Sommario`` (or ``(*) Sommario``) prefix and splitting on em-dash.

        Differently from NS: the DT plugin does NOT split off a trailing
        section heading from the sommario, because in DT the sommario
        and the first section heading sit in separate blocks (the
        empirical inspection of all three fixtures confirms this).
        """
        assert node.text is not None
        stripped = _SOMMARIO_TRIM_PATTERN.sub("", node.text.strip())

        # Split on em-dash separators.
        segments = re.split(r"\s*[—–]\s*", stripped)
        items: list[TocGeneralItem] = []
        for seg in segments:
            seg = seg.strip()
            match = re.match(r"^(\d+(?:\.\d+)?)\.\s+(.+?)\.?\s*$", seg)
            if match:
                number = match.group(1)
                title = match.group(2).strip()
                if title:
                    items.append(TocGeneralItem(number=number, title=title, page_number=None))

        if not items:
            warnings.append(f"{WARNING_PREFIX}:toc_general_unparseable_node_{node.id}")
            return [node]

        warnings.append(f"{WARNING_PREFIX}:toc_general_parsed_node_{node.id}_items_{len(items)}")
        toc_node = replace(node, toc_items=tuple(items))
        return [toc_node]

    # ------------------------------------------------------------------
    # Body+notes section consolidation (per-article)

    def _consolidate_notes_sections(
        self,
        children: tuple[Node, ...],
        warnings: list[str],
        transformations: list[Transformation],
        minter: NodeIdMinter,
    ) -> tuple[Node, ...]:
        """Find every SECTION_LABEL ``"Note:"`` and consolidate the following siblings.

        Delegates the walker to the shared
        :func:`consolidate_notes_section_children` helper (P-017,
        Promotion Fase 3). The plugin-specific split logic that mints
        ``NOTE`` and ``EDITORIAL_NOTE`` Nodes (pattern (ww)) lives in
        :meth:`_split_notes_text` and is passed as a closure.

        Returns the rebuilt children tuple. If no ``"Note:"``
        SECTION_LABEL is present in the list, the original tuple is
        returned unchanged.
        """

        def split_fn(text: str, page_index: int, block_indices: tuple[int, ...]) -> list[Node]:
            return self._split_notes_text(
                text,
                page_index=page_index,
                block_indices=block_indices,
                warnings=warnings,
                minter=minter,
            )

        return consolidate_notes_section_children(
            children,
            split_notes_text_fn=split_fn,
            transformation_step_id="dejure_dottrina_notes_section_consolidate",
            unparseable_warning=lambda node_id: (
                f"{WARNING_PREFIX}:note_section_unparseable_node_{node_id}"
            ),
            warnings=warnings,
            transformations=transformations,
        )

    # Thin delegations to the shared helpers (P-016, Promotion Fase 3).
    # Existing unit tests address these via ``DejureDottrinaProfile.
    # _starts_with_notes_marker`` / ``_match_notes_marker``; keeping
    # the static method aliases preserves the test surface without
    # touching the test files.
    _starts_with_notes_marker = staticmethod(starts_with_notes_marker)
    _match_notes_marker = staticmethod(match_notes_marker)

    def _split_notes_text(
        self,
        notes_text: str,
        *,
        page_index: int,
        block_indices: tuple[int, ...],
        warnings: list[str],
        minter: NodeIdMinter,
    ) -> list[Node]:
        """Split notes text into NOTE and EDITORIAL_NOTE chunks.

        The split regex :data:`_NOTE_SPLIT_PATTERN` matches before
        ``(N) ``, ``(*) `` or ``(*)\\u2003`` chunks. Each chunk is
        classified as ``EDITORIAL_NOTE`` if its leading marker is
        ``(*)``, ``NOTE`` if its leading marker is ``(N)``.
        """
        # Require at least one numeric or editorial marker in the text.
        has_marker = bool(re.search(r"\(\d+\)\s|\(\*\)\s|\(\*\) ", notes_text))
        if not has_marker:
            return []

        chunks = _NOTE_SPLIT_PATTERN.split(notes_text)
        minted: list[Node] = []
        for chunk in chunks:
            chunk = chunk.strip()
            if not chunk:
                continue
            # Editorial note (*)
            if _EDITORIAL_NOTE_PREFIX_PATTERN.match(chunk):
                new_id = minter.mint()
                minted.append(
                    Node(
                        id=new_id,
                        category=SemanticCategory.EDITORIAL_NOTE,
                        page_index=page_index,
                        block_indices=block_indices,
                        text=chunk,
                    )
                )
                self._minted_editorial_note_ids.add(new_id)
                warnings.append(
                    f"{WARNING_PREFIX}:editorial_note_minted_node_{new_id}_page_{page_index}"
                )
                continue
            # Numeric note (N)
            chunk_marker = _NOTE_MARKER_PATTERN.match(chunk)
            if chunk_marker is None:
                continue
            marker_value = chunk_marker.group(1)
            new_id = minter.mint()
            minted.append(
                Node(
                    id=new_id,
                    category=SemanticCategory.NOTE,
                    page_index=page_index,
                    block_indices=block_indices,
                    text=chunk,
                    length_category=compute_note_length_category(chunk),
                )
            )
            self._minted_note_ids.add(new_id)
            warnings.append(
                f"{WARNING_PREFIX}:note_section_split_minted_node_"
                f"{new_id}_page_{page_index}_marker_{marker_value}"
            )
        return minted

    # ------------------------------------------------------------------
    # Inline cross-reference minting
    #
    # The legacy ``_maybe_mint_cross_references`` method (P-019, Fase 5)
    # was promoted to :func:`_dejure_shared.maybe_mint_inline_cross_references`
    # together with the byte-equivalent NS counterpart. Plugin-specific
    # ``_CROSSREF_MAX_MARKER_VALUE`` and ``WARNING_PREFIX`` are passed
    # explicitly at the call site in :meth:`_refine_children_list`.

    # ------------------------------------------------------------------
    # Apparatus: per-article binding + warning filtering

    @staticmethod
    def _compute_article_boundaries(all_nodes: list[Node]) -> list[tuple[int, int]]:
        """Return article boundaries as ``[(start_idx, end_idx_exclusive), ...]``.

        Each boundary covers the pre-order DFS index range between one
        ``GENRE_BANNER`` Node and the next (or end of forest). If no
        banner Nodes exist, returns a single boundary covering the
        whole list.
        """
        banner_indices = [
            i for i, n in enumerate(all_nodes) if n.category is SemanticCategory.GENRE_BANNER
        ]
        if not banner_indices:
            return [(0, len(all_nodes))]
        boundaries: list[tuple[int, int]] = []
        # A leading prefix without banner becomes its own scope.
        if banner_indices[0] > 0:
            boundaries.append((0, banner_indices[0]))
        for i, start in enumerate(banner_indices):
            end = banner_indices[i + 1] if i + 1 < len(banner_indices) else len(all_nodes)
            boundaries.append((start, end))
        return boundaries

    def _bind_cross_references_per_article(
        self,
        roots: tuple[Node, ...],
        all_nodes: list[Node],
        article_boundaries: list[tuple[int, int]],
    ) -> tuple[tuple[Node, ...], list[str]]:
        """Per-article scoped CR binding (pattern (vv))."""
        warnings: list[str] = []
        # Build per-article marker → NOTE node_id index.
        index_per_article: list[dict[str, str]] = []
        for start, end in article_boundaries:
            local_index: dict[str, str] = {}
            for k in range(start, end):
                node = all_nodes[k]
                if node.id not in self._minted_note_ids:
                    continue
                if node.text is None:
                    continue
                match = _NOTE_MARKER_PATTERN.match(node.text)
                if match is None:
                    continue
                marker = match.group(1)
                local_index.setdefault(marker, node.id)
            index_per_article.append(local_index)
        # Map each minted CR node id to its article index.
        cr_article_index: dict[str, int] = {}
        for k, node in enumerate(all_nodes):
            if node.id not in self._minted_crossref_ids:
                continue
            for art_idx, (start, end) in enumerate(article_boundaries):
                if start <= k < end:
                    cr_article_index[node.id] = art_idx
                    break

        def _walk(node: Node) -> Node:
            new_children = tuple(_walk(c) for c in node.children)
            new_apparatus_refs: tuple[ApparatusRef, ...] = node.apparatus_refs
            if (
                node.category is SemanticCategory.CROSS_REFERENCE
                and node.id in self._minted_crossref_ids
                and node.text is not None
            ):
                match = _NOTE_MARKER_PATTERN.match(node.text)
                if match is not None:
                    marker = match.group(1)
                    art_idx = cr_article_index.get(node.id)
                    target_id: str | None = None
                    if art_idx is not None and 0 <= art_idx < len(index_per_article):
                        target_id = index_per_article[art_idx].get(marker)
                    if target_id is not None:
                        new_apparatus_refs = (
                            *node.apparatus_refs,
                            ApparatusRef(
                                kind=ApparatusRefKind.CROSS_REF_TARGET,
                                target_node_id=target_id,
                                source_marker=node.text.strip(),
                            ),
                        )
                    else:
                        warnings.append(
                            f"{WARNING_PREFIX}:cross_reference_unresolved_node_"
                            f"{node.id}_marker_{marker}"
                        )
            if new_children != node.children or new_apparatus_refs != node.apparatus_refs:
                return replace(
                    node,
                    children=new_children,
                    apparatus_refs=new_apparatus_refs,
                )
            return node

        return tuple(_walk(r) for r in roots), warnings

    def _filter_tier1_crossref_warnings(self, warnings: tuple[str, ...]) -> tuple[str, ...]:
        """Drop tier 1 cross-reference warnings on plugin synthetic Nodes.

        Thin wrapper over
        :func:`apparatus.resolver.filter_tier1_crossref_warnings` (P-020).
        """
        return filter_tier1_crossref_warnings(warnings, set(self._minted_crossref_ids))

    # ------------------------------------------------------------------
    # Block view helper

    @staticmethod
    def _view(extraction: ExtractionResult, block_index: int) -> _BlockView | None:
        block = extraction.blocks[block_index]
        start, end = block.span_range
        spans = tuple(extraction.spans[start:end])
        if not spans:
            return None
        text = "".join(s.text for s in spans)
        return _BlockView(block_index=block_index, block=block, spans=spans, text=text)
