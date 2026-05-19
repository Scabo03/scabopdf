r"""Corpus plugin for the DeJure Note a Sentenza genre.

Seventh real corpus plugin of the project and **first plugin operating
on the Aspose.PDF for .NET editorial pipeline** (the prior six plugins
target editorial pipelines based on PDFsharp, Adobe InDesign or iLovePDF).
Handles the Giuffrè DeJure "Note e Dottrina" export of academic and
journalistic case notes (the dottrinal commentary attached to a specific
judicial decision), distinct from the sibling genres DeJure Massime
(case-law summaries) and DeJure Dottrina (free-standing academic
articles) that share the same Aspose pipeline. See
``docs/analysis/ANALYSIS_DEJURE_NOTE.md`` for the editorial analysis the
plugin is built against. The plugin is calibrated on two fixtures that
cover the bimodal continuum of the genre:

- ``pipeline/tests/fixtures/private/dejure_ns_recisione_nesso_causale.pdf``
  — 3-page short narrative note from ``Diritto & Giustizia``,
  commenting ``Cassazione penale 18 aprile 2024 n. 22587``. No
  sections, no footnotes, opens with an editorial subtitle
  ``"Quotidiano del 6 giugno 2024"`` between the metadata block and
  the body prose.

- ``pipeline/tests/fixtures/private/dejure_ns_giudizio_universale.pdf``
  — 22-page academic long note from ``Responsabilità Civile e
  Previdenza``, commenting ``Tribunale Roma 6 marzo 2024 n. 3552``.
  Five numbered uppercase sections, opening prose sommario, dense
  inline ``(N)`` cross-references to a closing block of 54 numbered
  bibliographic notes introduced by the ``Note:`` marker.

The plugin extends the ScaboPDF profile vocabulary along three new
dimensions that no prior plugin exercised:

- **First exercise of the Aspose.PDF for .NET editorial pipeline.** The
  PDFs are exported by Aspose.PDF for .NET 18.4 with the Arial family
  (``ArialMT``, ``Arial-BoldMT``, ``Arial-ItalicMT``, ``ArialItalic``)
  in Letter (612 x 792 pt) format. The pipeline shares no font family
  with the prior six plugins (Patriarca uses Times-New-Roman, Tesauro/
  Mosconi use TimesTenLTStd, Mandrioli uses SimonciniGaramondStd,
  Torrente uses MScotchRoman, BIC uses Verdana), so the Arial family
  is itself a strong primary discriminator. Aspose carries a few known
  encoding artefacts the plugin tolerates: the literal ``Responsabilita'``
  (straight apostrophe in place of ``à``) and the literal
  ``Cassazione penale ,`` (extra space before the comma) appear
  verbatim in real metadata strings and are conserved without
  normalisation because Layer 2 must render the exact Aspose output.

- **Bimodal archetype continuum (short narrative vs long academic).**
  The plugin must handle two structurally different documents under
  the same banner ``"NOTE E DOTTRINA"``. The short narrative archetype
  has no sommario, no numbered sections and no closing notes section,
  and instead opens with an editorial ``SUBTITLE`` line ``"Quotidiano
  del <date>"`` between the metadata block and the body. The long
  academic archetype has an opening ``TOC_GENERAL`` block of prose
  sommario with em-dash-separated entries, several uppercase numbered
  ``HEADING_1`` sections, and a closing ``Note:`` ``SECTION_LABEL``
  followed by a single concatenated block of ``(N)`` numbered
  ``NOTE`` Nodes minted in :meth:`refine_reconstruction`. Components
  are detected dynamically: a corpus fixture intermediate between
  the two extremes (numbered sections without notes, or notes
  without sections) is handled without configuration switches.

- **First exercise of the DeJure-specific category vocabulary in
  production.** The schema 0.5.0 ``SemanticCategory`` enum already
  declares the categories ``GENRE_BANNER``, ``TITLE``, ``FONTE_VALUE``,
  ``REFERRAL``, ``AUTHORS``, ``META_VALUE``, ``META_LABEL``,
  ``SUBTITLE``, ``SECTION_LABEL`` and ``TOC_GENERAL``: they were
  added in anticipation of the DeJure family of plugins and have
  been dormant up to now. This plugin lights them up in production
  for the first time, validating both the upstream schema choice
  and the conversion convention at the emission boundary. No schema
  bump is required.

Structural patterns introduced by this plugin (documented in
CLAUDE.md (oo)/(pp)/(qq) with the same numbering convention used by
the prior six plugins):

- **Metadata block decomposition** in :meth:`refine_reconstruction`.
  PyMuPDF emits the three opening metadata lines (``Fonte: ...``,
  ``Nota a: ...``, ``Autori: ...``) as a single ``Block`` with three
  ``line_index`` entries. The plugin classifies the entire block as
  ``META_VALUE`` in tier 2 and decomposes it into three sibling
  Nodes (``FONTE_VALUE``, ``REFERRAL``, ``AUTHORS``) in
  :meth:`refine_reconstruction`. The synthetic Nodes share the
  host's ``block_indices`` and ``page_index`` and carry the per-line
  verbatim text (label + value) so Layer 2 can apply a per-field
  regex at presentation time without losing the raw Aspose output.
  The decomposition is recorded as a ``Transformation`` with
  ``split_into`` populated, per the schema 0.5.0 structural
  reversibility convention; the host ``META_VALUE`` Node is removed
  from its parent's children list after the synthetic siblings are
  inserted in its place. If a metadata block is missing any of the
  three expected lines (a corpus variant that has only Fonte +
  Autori without a Nota a:, or has Authors line broken across two
  lines by Aspose), the plugin emits a per-occurrence
  ``metadata_block_unparseable_block_<idx>_page_<p>`` warning and
  leaves the original ``META_VALUE`` Node intact.

- **TOC_GENERAL parsing from prose with em-dash separators**. The
  sommario block carries a single prose paragraph of the form
  ``"Sommario   1. <title> — 2. <title> — 3. <title> — ..."``. The
  plugin parses the prose into a tuple of ``TocGeneralItem(number,
  title, page_number=None)`` via the regex
  :data:`_SOMMARIO_ENTRY_PATTERN` and attaches it to the
  ``TOC_GENERAL`` Node's ``toc_items`` field. The TOC entries carry
  no page number (DeJure NS does not advertise per-section
  pagination, unlike the Tesauro corpus where ``TOC_GENERAL.items``
  carries the printed book-page numbers). The page_number field is
  always ``None`` for DeJure NS — the converter handles ``None``
  correctly per the schema 0.5.0 contract.

- **Multi-pattern body+notes section splitter** akin to the
  Mandrioli/BIC body+note splitter but adapted to the DeJure
  convention. After the ``Note:`` ``SECTION_LABEL`` Node, the
  following ``BODY``-classified Node(s) carry the entire concatenated
  ``(1) ... (2) ... (3) ...`` notes section as one block of prose.
  The plugin walks the post-``Note:`` ``BODY`` Nodes, splits each
  on the regex ``(?=\(\d+\)\s)`` (positive look-ahead for the next
  marker), mints one synthetic ``NOTE`` Node per match with the
  verbatim ``"(N) ..."`` text, and records a ``Transformation``
  with ``split_into`` populated for each split. The minted Nodes
  inherit the original ``BODY``'s ``block_indices`` and
  ``page_index`` and become siblings of the original ``BODY`` Node
  in the parent's children list; the original ``BODY`` Node is
  removed if all its text was absorbed by the synthetic NOTE Nodes,
  or kept with the residual non-matching prefix if a prefix exists
  before the first ``(1)`` marker.

- **Inline cross-reference minting via textual regex on Node.text**,
  identical in machinery to the Mandrioli plugin and distinct from
  the Mosconi span-based approach. The Aspose pipeline emits each
  ``(N)`` inline marker as part of the surrounding ``ArialMT 12pt``
  body span, with no superscript flag or size difference. The plugin
  walks every body Node, scans ``Node.text`` with
  :data:`_CROSSREF_INLINE_PATTERN` (``(?<=\w)\((\d+)\)``, requiring
  a word character immediately before the open paren to filter out
  citation-style parenthesised numbers like ``"art. 9 (1)"``), and
  mints one synthetic ``CROSS_REFERENCE`` Node per match as a sibling
  immediately after the host body Node. Each minted Node carries the
  verbatim ``"(N)"`` text and is bound in :meth:`refine_apparatus` to
  the homonymous ``NOTE`` minted by the body+notes splitter via a
  global per-document marker → node_id index. The binding is global
  because the DeJure NS numbers its notes continuatively across the
  whole document (1..54 in the long fixture), without any chapter
  scope, mirroring the Torrente global scope pattern but with a
  simpler marker form (pure digits).

The empirical inspection (PyMuPDF 1.27.2.3) of the two real DeJure NS
fixtures reports the following typographic system, with sizes
**confirmed empirically** against the analysis document's
**visually estimated** values which were systematically off by 1-2pt:

- **Banner** ``"NOTE E DOTTRINA"`` at ``Arial-BoldMT`` 9pt (analysis
  estimated 9pt, confirmed). The grey background is a vector graphic
  not exposed through PyMuPDF's text layer, so the plugin discriminates
  via the typographic signature plus the verbatim text predicate.
- **Title** at ``Arial-BoldMT`` 13pt (analysis estimated 14pt, **revised**).
- **Metadata block** at ``Arial-BoldMT`` 9pt for the value spans; the
  label spans (``"Fonte:"``, ``"Nota a:"``, ``"Autori:"``) are sometimes
  emitted at ``ArialMT`` 9pt regular (short fixture) and sometimes at
  ``Arial-BoldMT`` 9pt bold (long fixture). The plugin's predicate is
  font-flag agnostic on the label spans and matches the block as a
  whole on its 9pt size plus the textual presence of the
  ``Fonte:`` / ``Nota a:`` / ``Autori:`` line markers.
- **Subtitle** ``"Quotidiano del <date>"`` at ``ArialMT`` 12pt regular
  in the short narrative archetype. Discriminated from body via the
  textual prefix ``"Quotidiano"``.
- **Sommario block** at ``ArialMT`` 12pt regular with the leading
  prose word ``"Sommario"``. Discriminated from body via the textual
  prefix.
- **Section headings** at ``Arial-BoldMT`` 12pt (analysis estimated
  11pt, **revised**) carrying the pattern ``^\d+\.\s+[A-ZÀÈÌÒÙ]``
  (uppercase title following the number, may include the cited
  French quotes ``«»``).
- **Notes marker** ``"Note:"`` at ``Arial-BoldMT`` 12pt as the
  ``SECTION_LABEL`` that opens the closing notes section.
- **Body prose** at ``ArialMT`` 12pt regular (analysis estimated 11pt,
  **revised**) with inline ``Arial-ItalicMT`` 12pt for Latinisms,
  foreign-language terms and quoted citations in French quotes.
- **Footer** ``"Pagina N di M"`` at ``ArialItalic`` 12pt italic
  (analysis estimated 10pt, **revised**). The font name reported by
  PyMuPDF is ``ArialItalic`` (no Arial- prefix), distinct from the
  body inline italic ``Arial-ItalicMT``. The plugin's footer predicate
  accepts both family fragments.
- **Copyright stamp** ``"SERVIZIO GESTIONE RISORSE DOCUMENTARIE..."``
  at ``ArialMT`` 10.5pt regular (analysis suggested three-column
  layout, **revised** to single-column block on the bottom of the
  last page).
- **Colour palette** is monochrome ``#000000`` for every text span;
  the grey banner background and any other visual decoration is
  rendered as a vector graphic outside PyMuPDF's text layer.

The empirical structural metrics on the two fixtures, post-tier-2:

- ``recisione_nesso_causale`` (3 pp): 1 GENRE_BANNER, 1 TITLE,
  1 META_VALUE umbrella decomposed into 3 sibling Nodes (FONTE_VALUE
  + REFERRAL + AUTHORS), 1 SUBTITLE, 0 TOC_GENERAL, 0 HEADING_1
  numbered sections, 0 SECTION_LABEL, 0 NOTE, 0 CROSS_REFERENCE,
  ~6 BODY Nodes, 3 ARTIFACT_FOOTER, 1 ARTIFACT_STAMP.
- ``giudizio_universale`` (22 pp): 1 GENRE_BANNER, 1 TITLE, 1
  META_VALUE decomposed into 3 siblings, 0 SUBTITLE, 1 TOC_GENERAL
  with 5 parsed toc_items, 5 HEADING_1 numbered sections, 1
  SECTION_LABEL ``Note:``, 54 synthetic NOTE Nodes minted from the
  post-``Note:`` block, ~80 BODY Nodes, dozens of CROSS_REFERENCE
  minted from inline ``(N)`` markers in body text, 22 ARTIFACT_FOOTER,
  1 ARTIFACT_STAMP.

Pipeline integration.

- :meth:`get_post_processing` returns ``["dehyphenate_with_log"]``.
  The Aspose pipeline does not hyphenate at line breaks (line wrap
  happens at word boundaries on Aspose layouts), so the dehyphenator
  is a no-op in practice; declaring it nevertheless keeps the
  contract with the generic step registry uniform across plugins.
- :meth:`get_layouts_disabled` returns ``[]`` (every layout is
  enabled). The DeJure NS is the canonical target genre for Layout 4
  (Dottrina Inline), which renders inline footnote markers anchored
  to the corresponding ``NOTE`` Nodes; the short narrative archetype
  without notes degenerates to a flat L4 reading equivalent to L1
  but the layout remains semantically valid.
- :meth:`refine_apparatus` performs three profile-specific actions:
  (a) build a global ``marker → NOTE node_id`` index over the full
  document tree by scanning every NOTE Node and parsing its leading
  ``(N) `` marker; (b) bind every synthetic CROSS_REFERENCE Node
  minted in :meth:`refine_reconstruction` to its target NOTE via
  this index, populating ``apparatus_refs`` with a
  ``CROSS_REF_TARGET`` ref keyed by the marker; (c) filter the
  Document's warnings tuple to drop tier 1
  ``unresolved_cross_reference_node_<id>_n_<N>`` warnings that the
  tier 1 generic resolver may have emitted on the plugin's
  synthetic Nodes before its own pass narrowed them down by scope.

Instance state.

- ``_pending_warnings``: queued warnings produced during
  :meth:`refine_classification` (which has no Document to attach
  them to) and flushed into ``Document.warnings`` by
  :meth:`refine_reconstruction`.
- ``_minted_crossref_ids``: the set of synthetic CROSS_REFERENCE
  node ids produced in :meth:`refine_reconstruction`. Consumed by
  :meth:`refine_apparatus` to bind them globally and filter tier 1
  warnings.
- ``_minted_note_ids``: the set of synthetic NOTE node ids
  produced in :meth:`refine_reconstruction` from the body+notes
  splitter. Used by :meth:`refine_apparatus` to build the marker
  index without scanning the whole tree twice.

Closed warning vocabulary, prefix ``plugin:dejure_nota_sentenza:``.
See :data:`WARNING_TEMPLATES` for the closed list.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, replace
from typing import ClassVar

from scabopdf_pipeline.apparatus.types import ApparatusRef, ApparatusRefKind
from scabopdf_pipeline.classification.types import ClassifiedBlock
from scabopdf_pipeline.extraction.types import Block, ExtractionResult, Span
from scabopdf_pipeline.postprocessing.types import Transformation
from scabopdf_pipeline.profiling.plugin import ProfilePlugin
from scabopdf_pipeline.profiling.profile import DisabledLayout
from scabopdf_pipeline.profiling.signals import ProfilingSignals
from scabopdf_pipeline.reconstruction.types import (
    Document,
    Node,
    TocGeneralItem,
)
from scabopdf_pipeline.schema.categories import SemanticCategory

WARNING_PREFIX = "plugin:dejure_nota_sentenza"
"""Common prefix for every warning string this plugin may emit.

See ``docs/SCHEMA_v0.5.0.md § 6`` for the rationale of the prefix
convention and :data:`WARNING_TEMPLATES` for the closed vocabulary.
"""

WARNING_TEMPLATES: tuple[str, ...] = (
    "plugin:dejure_nota_sentenza:metadata_block_unparseable_block_<idx>_page_<p>",
    "plugin:dejure_nota_sentenza:metadata_field_minted_node_<id>_field_<name>",
    "plugin:dejure_nota_sentenza:toc_general_parsed_node_<id>_items_<n>",
    "plugin:dejure_nota_sentenza:toc_general_unparseable_node_<id>",
    "plugin:dejure_nota_sentenza:section_heading_pattern_unmatched_block_<idx>_page_<p>",
    "plugin:dejure_nota_sentenza:note_section_split_minted_node_<id>_page_<p>_marker_<n>",
    "plugin:dejure_nota_sentenza:note_section_unparseable_node_<id>",
    "plugin:dejure_nota_sentenza:cross_reference_minted_node_<id>_page_<p>_marker_<n>",
    "plugin:dejure_nota_sentenza:cross_reference_unresolved_node_<id>_marker_<n>",
)
"""Closed vocabulary of warnings the plugin may emit. Placeholders are
replaced with concrete values at emission time. Consumers should match
on the prefix.
"""

# ---------------------------------------------------------------------------
# Typographic family fragments and empirical sizes.

ARIAL_FAMILY_PREFIX = "Arial"
"""Family prefix shared by every Arial variant the plugin recognises.

PyMuPDF emits ``ArialMT`` (regular), ``Arial-BoldMT`` (bold),
``Arial-ItalicMT`` (italic) and ``ArialItalic`` (italic, no Arial-
prefix, used by the footer); the ``startswith("Arial")`` check
admits every one of them.
"""

ARIAL_REGULAR_FAMILY = "ArialMT"
"""Exact family of the regular Arial spans (body, sommario, subtitle,
copyright stamp).
"""

ARIAL_BOLD_FAMILY = "Arial-BoldMT"
"""Exact family of the bold Arial spans (banner, title, metadata
values, section headings, notes marker).
"""

ARIAL_ITALIC_FAMILY_PREFIX = "Arial"
"""Italic family prefix admitted by the italic predicates. PyMuPDF
reports either ``Arial-ItalicMT`` for inline italic body spans or
``ArialItalic`` for the page footer; the prefix admits both.
"""

BANNER_SIZE = 9.0
"""Size in points of the ``"NOTE E DOTTRINA"`` banner and of the
metadata block (label + value spans). Identical to the analysis-
estimated 9pt.
"""

TITLE_SIZE = 13.0
"""Size in points of the nota title. Empirically 13.0 (analysis
estimated 14, revised after PyMuPDF inspection).
"""

BODY_SIZE = 12.0
"""Size in points of the body prose. Identical for the body,
italic inline, footer, sommario, section headings (which share
the body size and are discriminated by bold flag + text pattern),
``Note:`` section label and any other 12pt content.
"""

COPYRIGHT_SIZE = 10.5
"""Size in points of the copyright stamp ``"SERVIZIO GESTIONE
RISORSE DOCUMENTARIE..."`` at the bottom of the last page.
"""

SIZE_TOLERANCE = 0.15
"""Tolerance in points for every size predicate.

The Aspose pipeline emits sizes with no measurable drift below the
analysis-estimated round values (9.0, 12.0, 13.0); the 0.15 cushion
absorbs PyMuPDF measurement noise while staying below the 0.5pt
inter-category gap (12.0 body vs 13.0 title vs 9.0 banner).
"""

PAGE_WIDTH_LETTER = 612.0
"""Letter page width in points. The DeJure Aspose pipeline emits
documents at Letter format; non-Letter documents are not DeJure NS.
"""

PAGE_HEIGHT_LETTER = 792.0
"""Letter page height in points."""

PAGE_GEOMETRY_TOLERANCE = 1.0
"""Tolerance in points for the page geometry match. Aspose sometimes
emits a sub-pixel-precision Letter page (612.0 x 792.0 ± 0.05);
the 1.0-pt tolerance is comfortable.
"""

# ---------------------------------------------------------------------------
# Closed text predicates.

BANNER_TEXT_NOTE_E_DOTTRINA = "NOTE E DOTTRINA"
"""The literal banner text the plugin discriminates as ``GENRE_BANNER``."""

SUBTITLE_TEXT_PREFIX = "Quotidiano"
"""Text-prefix discriminator for the optional editorial subtitle line
``"Quotidiano del <date>"`` in the short narrative archetype.
"""

SOMMARIO_TEXT_PREFIX = "Sommario"
"""Text-prefix discriminator for the opening sommario prose block of
the long academic archetype. The block starts with ``"Sommario   "``
(prose word followed by several spaces) and continues with the
em-dash-separated entries.
"""

NOTES_MARKER_TEXT_VARIANTS: tuple[str, ...] = ("Note:", "Note :")
"""Closed set of accepted ``"Note:"`` marker variants.

Aspose has been observed to emit either ``Note:`` (compact) or
``Note :`` (space before the colon) depending on the editorial
template; both variants are admitted.
"""

METADATA_LABEL_FONTE = "Fonte:"
"""Literal label prefix of the ``FONTE`` metadata line."""

METADATA_LABEL_NOTA_A = "Nota a:"
"""Literal label prefix of the ``REFERRAL`` metadata line."""

METADATA_LABEL_AUTORI = "Autori:"
"""Literal label prefix of the ``AUTHORS`` metadata line."""

ASPOSE_PRODUCER_FRAGMENT = "Aspose.PDF"
"""Producer/creator substring signalling the Aspose.PDF for .NET
editorial pipeline.

Both the recisione (3 pp) and giudizio_universale (22 pp) fixtures
carry the literal ``"Aspose.PDF for .NET 18.4"`` producer.
"""

COPYRIGHT_STAMP_TEXT_FRAGMENTS: tuple[str, ...] = (
    "SERVIZIO GESTIONE RISORSE",
    "© Copyright Giuffrè",
)
"""Text-fragment discriminators for the copyright stamp on the last
page. PyMuPDF splits the stamp into two adjacent blocks (left column
with the ``"SERVIZIO GESTIONE RISORSE DOCUMENTARIE"`` label and
right column with the ``"© Copyright Giuffrè Francis Lefebvre S.p.A.
<year> <date>"`` body); both blocks are classified as
``ARTIFACT_STAMP`` so the audit log records them uniformly.
"""

PAGE_HEADER_TEXT_FRAGMENT = "Banche dati editoriali GFL"
"""Text-fragment discriminator for the page-1 header tagline that
sits below the DeJure logo. Classified as ARTIFACT_PAGE_HEADER.
"""

# ---------------------------------------------------------------------------
# Regular expressions.

_FOOTER_PATTERN = re.compile(r"^Pagina\s+\d+\s+di\s+\d+\s*$")
"""Pattern matching the page footer text ``"Pagina N di M"`` with
flexible whitespace. The footer text predicate is applied jointly
with the italic typographic signature.
"""

_SECTION_HEADING_PATTERN = re.compile(r"^(\d+)\.\s+[A-ZÀÈÉÌÒÓÙÚ]")
"""Pattern matching a numbered section heading. Capture group 1 is
the section number. The trailing character after the dot must be an
uppercase letter (with optional accents) so this regex does not match
a body paragraph that happens to open with a numeric ordinal followed
by a lowercase word.
"""

_SECTION_HEADING_NUMBER_PATTERN = re.compile(r"^(\d+)\.\s+")
"""Pattern that extracts the section number from a HEADING_1 text
for the cross-reference target index. Less strict than
:data:`_SECTION_HEADING_PATTERN` (it accepts lowercase-starting
text), to keep the parser robust across editorial variants of the
section heading typesetting.
"""

_SOMMARIO_ENTRY_PATTERN = re.compile(r"(?:^|\s—\s|\s—\s)(\d+)\.\s+([^——]+?)(?=\s—|\s—|$)")
"""Pattern matching one ``N. <title>`` entry inside the sommario
prose. Used to parse the sommario into a tuple of
``TocGeneralItem(number, title, page_number=None)``.

The regex handles both the ASCII ``—`` (em-dash, U+2014 alone) and
the literal ASCII triple-hyphen variant that Aspose may emit
depending on the font. The look-ahead at the end terminates each
entry before the next ``—`` separator or the end of string.
"""

_NOTE_MARKER_PATTERN = re.compile(r"^\((\d+)\)")
"""Pattern matching the leading ``(N)`` marker of a NOTE Node text.

Used in :meth:`refine_apparatus` to build the marker → NOTE node_id
index. The capture group is the marker digit sequence.
"""

_NOTE_SPLIT_PATTERN = re.compile(r"(?=\(\d+\)\s)")
"""Pattern used to split a concatenated notes block into individual
note pieces. The positive look-ahead matches **before** a ``(N) ``
marker without consuming it, so ``re.split`` returns chunks each
starting with its own ``(N) `` marker.
"""

_CROSSREF_INLINE_PATTERN = re.compile(r"(?<![(\d])\((\d+)\)")
"""Pattern matching every inline ``(N)`` cross-reference inside a
body Node's text.

The empirical inspection of the long-academic fixture reports 53
inline ``(N)`` markers in body text, mostly preceded by a single
space rather than a word character (Aspose typesets the marker after
a space gap: ``"come ha notato la dottrina (4),"``). A strict
look-behind on ``\\w`` would miss ~80% of them. The current pattern
admits any ``(N)`` not preceded by an open paren (filters out
nested parenthetical expressions) or by a digit (filters out
trailing-digit run-ons like ``"(123)"`` inside larger numeric
expressions). The magnitude check on the captured marker value
(``<= _CROSSREF_MAX_MARKER_VALUE``) filters out year references
``(2024)`` and similar.
"""

_CROSSREF_MAX_MARKER_VALUE = 99
"""Magnitude cap on inline cross-reference markers.

The DeJure NS corpus has at most 54 notes per document in the
fixtures inspected; the 99 cap leaves a comfortable buffer while
filtering out year references (``(2024)``, ``(1962)``), sentence
numbers (``(3552)``) and large-integer citations the corpus does not
use for inline note markers.
"""

# ---------------------------------------------------------------------------
# Match() confidence weights and thresholds.

CONFIDENCE_ARIAL_BODY_DOMINANT = 0.30
"""Confidence contribution when ``ArialMT`` 12pt dominates the
typographic signature above the body-share floor.

The single strongest discriminator of the DeJure Aspose pipeline:
no other corpus in the project uses Arial as its body family
(Patriarca → Times-New-Roman, Tesauro/Mosconi → TimesTenLTStd,
Mandrioli → SimonciniGaramondStd, Torrente → MScotchRoman, BIC →
Verdana). A document whose body is Arial is a DeJure candidate.
"""

CONFIDENCE_ASPOSE_PRODUCER = 0.20
"""Confidence contribution when the producer/creator string carries
the ``"Aspose.PDF"`` fragment.

The Aspose pipeline is shared across DeJure Massime, DeJure Note a
Sentenza and DeJure Dottrina; the producer signal is necessary but
not sufficient to identify the Note a Sentenza genre — the body
family and the page geometry corroborate.
"""

CONFIDENCE_LETTER_GEOMETRY = 0.10
"""Confidence contribution when the page geometry matches Letter
(612 x 792 pt). Aspose-DeJure documents are always Letter; non-Letter
documents are not DeJure regardless of font.
"""

CONFIDENCE_TITLE_BOLD_PRESENT = 0.10
"""Confidence contribution when an ``Arial-BoldMT`` 13pt size is
present in the typographic signature.

The 13pt bold Arial is unique to the title of a DeJure NS document
(no other content in the corpus uses this size). A document with a
13pt bold Arial span is unambiguously a DeJure NS or Dottrina;
absent it, the document may still be a DeJure Massime or another
short Aspose-Arial document.
"""

CONFIDENCE_TITLE_BOLD_ABSENT_PENALTY = -0.20
"""Penalty when ``Arial-BoldMT`` 13pt is absent from the typographic
signature.

Symmetric counterpart of :data:`CONFIDENCE_TITLE_BOLD_PRESENT`.
Without this penalty an Aspose-Arial-Letter document with only the
9pt and 12pt bold sizes (a DeJure Massime export) would clear the
0.6 dispatcher threshold on the sister NS plugin at score 0.70 and
mis-route every Massime fixture to the NS plugin. The penalty drops
the score to 0.50 on Massime, comfortably below threshold, while
leaving the genuine NS fixtures (which carry the 13pt bold title
size) at their 0.80 baseline. The :class:`DejureMassimeProfile`
sister plugin applies a symmetric ``-0.30`` penalty when the 13pt
bold is **present** to keep Massime below threshold on NS fixtures.
"""

CONFIDENCE_BANNER_BOLD_PRESENT = 0.10
"""Confidence contribution when an ``Arial-BoldMT`` 9pt size is
present in the typographic signature.

The 9pt bold Arial is shared with the metadata values; it is a
necessary but not sufficient signal of the DeJure NS banner.
"""

CONFIDENCE_OTHER_BODY_FAMILY_PENALTY = -0.40
"""Penalty when the dominant body family is not Arial.

Strong penalty: a document whose body is OpenSans, Verdana,
TimesTenLTStd, SimonciniGaramondStd or any other family is not a
DeJure Aspose export and the plugin must step back. The Stella
fixture (OpenSans body from Skia/PDF, A4 geometry) is the
canonical negative example.
"""

CONFIDENCE_MARGINAL_APPARATUS_PENALTY = -0.20
"""Penalty when the document carries a substantial marginal-
heading apparatus.

DeJure NS documents have zero marginal headings (they are short
documents with inline-only apparatus). A document with hundreds of
marginal headings is a Torrente, Mosconi or Mandrioli manual and
the plugin must step back.
"""

BODY_DOMINANCE_MIN_PERCENT = 40.0
"""Minimum body-family dominance percent to credit the body signal.

The DeJure NS body is typically 60-80 % of total spans on the fixture;
the 40 % floor leaves headroom for short fixtures where italic spans
and headings take a larger share without disqualifying the document.
"""

APPARATUS_PRESENCE_THRESHOLD = 50
"""Threshold above which marginal-heading or footnote-marker counts
are considered "present", triggering the corresponding penalty.
"""

# ---------------------------------------------------------------------------
# Notes-section boundary tables.

_NOTES_SECTION_BOUNDARY_CATEGORIES: frozenset[SemanticCategory] = frozenset(
    {
        SemanticCategory.HEADING_1,
        SemanticCategory.HEADING_2,
        SemanticCategory.HEADING_3,
        SemanticCategory.HEADING_4,
        SemanticCategory.SECTION_LABEL,
        SemanticCategory.TITLE,
        SemanticCategory.GENRE_BANNER,
        SemanticCategory.META_VALUE,
        SemanticCategory.FONTE_VALUE,
        SemanticCategory.REFERRAL,
        SemanticCategory.AUTHORS,
        SemanticCategory.SUBTITLE,
        SemanticCategory.TOC_GENERAL,
    }
)
"""Categories that terminate the notes-section absorption walker.

When the consolidator scans siblings after a ``SECTION_LABEL`` ``Note:``
marker and encounters one of these categories, the walker stops and
the absorbed body Nodes are split into synthetic ``NOTE`` Nodes. The
boundary is conservative on purpose: anything structurally significant
(another heading, label, metadata block) ends the notes section.
"""

_NOTES_SECTION_PASSTHROUGH_CATEGORIES: frozenset[SemanticCategory] = frozenset(
    {
        SemanticCategory.ARTIFACT_FOOTER,
        SemanticCategory.ARTIFACT_RUNNING_HEADER,
        SemanticCategory.ARTIFACT_PAGE_HEADER,
        SemanticCategory.ARTIFACT_STAMP,
        SemanticCategory.ARTIFACT_FILIGREE,
        SemanticCategory.BOOK_PAGE_ANCHOR,
        SemanticCategory.EMPTY_PAGE,
        SemanticCategory.UNCLASSIFIED,
    }
)
"""Categories that the notes-section absorption walker passes through.

These are non-structural categories that may interleave with BODY
Nodes in the original tree (e.g. ARTIFACT_FOOTER blocks between body
paragraphs on consecutive pages). The walker keeps them in reading
order after the synthetic ``NOTE`` Nodes have been emitted.
"""

# ---------------------------------------------------------------------------
# Helpers — block view, node-id minter, max-existing-counter walker.


@dataclass(frozen=True)
class _BlockView:
    """Pre-computed view of a block exposed to the plugin's tier 2 logic.

    Same convention as the prior plugins: ``block_index`` + ``block``
    + ``spans`` + joined ``text``. The plugin's predicates inspect the
    leading span via ``view.spans[0]`` and the joined block text via
    ``view.text``.
    """

    block_index: int
    block: Block
    spans: tuple[Span, ...]
    text: str


_NODE_ID_PATTERN = re.compile(r"^node_(\d+)$")
"""Pattern that decodes a tier 1 node id into its numeric counter.

Same convention as in the Mosconi, Mandrioli, Torrente and BIC plugins;
the schema's ``NodeDict.id`` validator enforces ``^node_\\d+$``.
"""


class _NodeIdMinter:
    """Stateful node-id minter that follows the tier 1 ``node_NNNN``
    convention.

    Synthetic nodes minted by the plugin respect the JSON schema's
    pattern on ``NodeDict.id``. The minter starts one past the maximum
    counter already used by tier 1 and emits monotonically increasing
    ids zero-padded to four digits.
    """

    def __init__(self, *, start: int) -> None:
        self._counter = start

    def mint(self) -> str:
        node_id = f"node_{self._counter:04d}"
        self._counter += 1
        return node_id


def _max_existing_node_counter(roots: tuple[Node, ...]) -> int:
    """Return the highest numeric counter already used by a tier 1 node id."""
    best = -1

    def _visit(node: Node) -> None:
        nonlocal best
        match = _NODE_ID_PATTERN.match(node.id)
        if match is not None:
            value = int(match.group(1))
            if value > best:
                best = value
        for child in node.children:
            _visit(child)

    for root in roots:
        _visit(root)
    return best


def _iter_nodes(roots: tuple[Node, ...]) -> list[Node]:
    """Pre-order DFS walk over the forest, returning every Node."""
    out: list[Node] = []

    def _visit(node: Node) -> None:
        out.append(node)
        for child in node.children:
            _visit(child)

    for root in roots:
        _visit(root)
    return out


def _strip_label(text: str, label: str) -> str:
    """Strip a leading label from a metadata line, normalising whitespace."""
    stripped = text.strip()
    if stripped.startswith(label):
        stripped = stripped[len(label) :].lstrip()
    return stripped


# ---------------------------------------------------------------------------
# Main class.


class DejureNotaSentenzaProfile(ProfilePlugin):
    """Corpus plugin for the Giuffrè DeJure Note a Sentenza genre.

    Seventh real corpus plugin of the project; see the module docstring
    for the full editorial and structural rationale.
    """

    profile_id: ClassVar[str] = "dejure_nota_sentenza"
    editorial_family: ClassVar[str] = "dejure"
    genre: ClassVar[str] = "nota_sentenza"

    def __init__(self) -> None:
        self._pending_warnings: list[str] = []
        self._minted_crossref_ids: set[str] = set()
        self._minted_note_ids: set[str] = set()

    # ------------------------------------------------------------------
    # ProfilePlugin declarative methods

    @classmethod
    def matches(cls, signals: ProfilingSignals) -> float:
        """Score the document against the DeJure NS fingerprint.

        Five positive contributions (Arial body dominance, Aspose
        producer, Letter geometry, 13pt bold title family, 9pt bold
        banner family) and two penalties (non-Arial body family,
        substantial marginal-heading apparatus). The Stella
        ``raccolta`` fixture (Skia/PDF + OpenSans + A4 + zero
        DeJure-specific signals) clamps to 0.0 and falls below the
        dispatcher threshold, mirroring the precedent of the Marotta
        control sample for the Giappichelli plugin.
        """
        score = 0.0

        body_present = any(
            font.family.startswith(ARIAL_REGULAR_FAMILY)
            and abs(font.size - BODY_SIZE) < SIZE_TOLERANCE
            and font.dominance_percent >= BODY_DOMINANCE_MIN_PERCENT
            for font in signals.typographic_signature.fonts
        )
        if body_present:
            score += CONFIDENCE_ARIAL_BODY_DOMINANT
        else:
            # No Arial body family present: this is not a DeJure
            # Aspose document.
            arial_family_dominant = any(
                font.family.startswith(ARIAL_FAMILY_PREFIX)
                and font.dominance_percent >= BODY_DOMINANCE_MIN_PERCENT
                for font in signals.typographic_signature.fonts
            )
            if not arial_family_dominant:
                score += CONFIDENCE_OTHER_BODY_FAMILY_PENALTY

        producer = (signals.producer_creator.producer or "").strip()
        creator = (signals.producer_creator.creator or "").strip()
        if ASPOSE_PRODUCER_FRAGMENT in producer or ASPOSE_PRODUCER_FRAGMENT in creator:
            score += CONFIDENCE_ASPOSE_PRODUCER

        width = signals.page_geometry.width_pt
        height = signals.page_geometry.height_pt
        if (
            abs(width - PAGE_WIDTH_LETTER) < PAGE_GEOMETRY_TOLERANCE
            and abs(height - PAGE_HEIGHT_LETTER) < PAGE_GEOMETRY_TOLERANCE
        ):
            score += CONFIDENCE_LETTER_GEOMETRY

        title_bold_present = any(
            font.family.startswith(ARIAL_BOLD_FAMILY)
            and abs(font.size - TITLE_SIZE) < SIZE_TOLERANCE
            for font in signals.typographic_signature.fonts
        )
        if title_bold_present:
            score += CONFIDENCE_TITLE_BOLD_PRESENT
        else:
            score += CONFIDENCE_TITLE_BOLD_ABSENT_PENALTY

        banner_bold_present = any(
            font.family.startswith(ARIAL_BOLD_FAMILY)
            and abs(font.size - BANNER_SIZE) < SIZE_TOLERANCE
            for font in signals.typographic_signature.fonts
        )
        if banner_bold_present:
            score += CONFIDENCE_BANNER_BOLD_PRESENT

        if signals.apparatus_presence.marginal_headings >= APPARATUS_PRESENCE_THRESHOLD:
            score += CONFIDENCE_MARGINAL_APPARATUS_PENALTY

        return max(0.0, score)

    def get_categories(self) -> set[SemanticCategory]:
        """Closed set of categories the plugin may emit on a DeJure NS document.

        Covers the bimodal continuum: short narrative documents emit
        the metadata umbrella + subtitle + body, long academic ones add
        sommario + numbered headings + section label + synthetic NOTE
        and CROSS_REFERENCE nodes.
        """
        return {
            SemanticCategory.HEADING_1,
            SemanticCategory.BODY,
            SemanticCategory.NOTE,
            SemanticCategory.CROSS_REFERENCE,
            SemanticCategory.TITLE,
            SemanticCategory.GENRE_BANNER,
            SemanticCategory.META_VALUE,
            SemanticCategory.FONTE_VALUE,
            SemanticCategory.REFERRAL,
            SemanticCategory.AUTHORS,
            SemanticCategory.SUBTITLE,
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
        """Return the ordered list of post-processing step IDs.

        Only ``dehyphenate_with_log``: the Aspose pipeline does not
        hyphenate at line breaks (line wrap on Aspose layouts happens
        at word boundaries), so the dehyphenator is a no-op in practice;
        declaring it nevertheless keeps the contract with the generic
        step registry uniform across plugins. No cross-page note
        merging is needed because DeJure NS notes do not split across
        pages structurally — when they do, the body+notes splitter in
        :meth:`refine_reconstruction` already recovers each individual
        ``(N) ...`` chunk from the concatenated post-``Note:`` block.
        """
        return ["dehyphenate_with_log"]

    def get_layouts_disabled(self) -> list[DisabledLayout]:
        """Return the empty list — every layout is enabled.

        The DeJure NS is the canonical target genre for Layout 4
        (Dottrina Inline), which renders inline footnote markers
        anchored to the corresponding NOTE Nodes. The short narrative
        archetype without notes degenerates to a flat L4 reading
        equivalent to L1 but the layout remains semantically valid;
        Layer 2 is responsible for the rendering decision.
        """
        return []

    # ------------------------------------------------------------------
    # Tier 2 refinement hooks

    def refine_classification(
        self,
        extraction: ExtractionResult,
        tier1_results: list[ClassifiedBlock],
    ) -> list[ClassifiedBlock]:
        """Promote tier 1 verdicts to the plugin's DeJure-specific vocabulary.

        Single-pass sweep over the tier 1 verdicts with a closed predicate
        cascade. The plugin re-examines **every** tier 1 verdict (not
        just ``UNCLASSIFIED``) because the tier 1 page-header zone heuristic
        may absorb the banner ``"NOTE E DOTTRINA"`` and the page-1 tagline
        ``"Banche dati editoriali GFL"`` as ``ARTIFACT_RUNNING_HEADER``,
        while the footer-zone heuristic correctly catches the
        ``"Pagina N di M"`` lines. The plugin's predicates run on every
        verdict; a positive match overrides the tier 1 category, a negative
        match leaves the tier 1 verdict intact.

        Predicate order (first match wins, conservatively narrow to wide):

        1. Genre banner ``"NOTE E DOTTRINA"`` (Arial-BoldMT 9pt + literal
           text) → GENRE_BANNER. Rescue from tier 1 ARTIFACT_RUNNING_HEADER.
        2. Page header tagline ``"Banche dati editoriali GFL"`` → ARTIFACT_PAGE_HEADER.
        3. Title (Arial-BoldMT 13pt) → TITLE.
        4. Metadata block (Arial-BoldMT 9pt, text contains Fonte: / Nota a: /
           Autori:) → META_VALUE umbrella. The decomposition into per-field
           sibling Nodes happens later in refine_reconstruction.
        5. Sommario (ArialMT 12pt, text starts with ``"Sommario"``) → TOC_GENERAL.
        6. Subtitle (ArialMT 12pt, text starts with ``"Quotidiano"``) → SUBTITLE.
        7. Section heading (Arial-BoldMT 12pt, text matches numbered
           uppercase pattern) → HEADING_1.
        8. Notes marker (Arial-BoldMT 12pt, text strip ∈ ``Note:`` /
           ``Note :``) → SECTION_LABEL.
        9. Footer (Arial italic 12pt, text matches Pagina N di M) →
           ARTIFACT_FOOTER. Pass-through if tier 1 already classified.
        10. Copyright stamp (ArialMT 10.5pt, text contains SERVIZIO GESTIONE
           RISORSE) → ARTIFACT_STAMP.
        11. Body (ArialMT 12pt regular) → BODY (catch-all near the end).
        12. Anything not matched stays at its tier 1 category.
        """
        self._pending_warnings = []
        self._minted_crossref_ids = set()
        self._minted_note_ids = set()

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

        # Stateful second pass: once a ``SECTION_LABEL`` ``Note:``
        # marker has been emitted, every subsequent ``BODY`` block in
        # reading order belongs to the notes-prose continuation and
        # must be reclassified as ``NOTE`` so that the tier 1
        # cross-page paragraph merger does not fuse it with the body
        # paragraphs of the enclosing section. The reading order is
        # block_index order on the assumption that tier 1 emits blocks
        # in document reading order (page, y0, x0) — the convention
        # of every prior plugin.
        in_notes_region = False
        retagged: list[ClassifiedBlock] = []
        for verdict in refined:
            if verdict.block_index < 0:
                retagged.append(verdict)
                continue
            if verdict.category is SemanticCategory.SECTION_LABEL:
                view = self._view(extraction, verdict.block_index)
                if view is not None and self._starts_with_notes_marker(view.text):
                    in_notes_region = True
                retagged.append(verdict)
                continue
            if in_notes_region and verdict.category is SemanticCategory.BODY:
                retagged.append(
                    ClassifiedBlock(
                        block_index=verdict.block_index,
                        category=SemanticCategory.NOTE,
                        reason="dejure_nota_sentenza_notes_region_continuation",
                    )
                )
                continue
            retagged.append(verdict)
        return retagged

    def refine_reconstruction(
        self,
        document: Document,
        extraction: ExtractionResult,
        classified_blocks: list[ClassifiedBlock],
    ) -> Document:
        """Decompose META_VALUE, parse TOC_GENERAL, split notes block, mint inline CR.

        Four structural transformations on the tier 1 tree:

        1. **META_VALUE decomposition**: every ``META_VALUE`` Node whose
           text contains all three label markers (``Fonte:``, ``Nota a:``,
           ``Autori:``) is decomposed into three sibling Nodes
           (``FONTE_VALUE``, ``REFERRAL``, ``AUTHORS``) carrying the
           per-line verbatim text. The host ``META_VALUE`` Node is
           removed and a ``Transformation`` is recorded with
           ``split_into`` populated with the three minted ids.
        2. **TOC_GENERAL parsing**: every ``TOC_GENERAL`` Node has its
           text scanned with the sommario regex; each ``N. <title>``
           match becomes a ``TocGeneralItem(number, title, page_number=None)``
           in ``toc_items``. The Node text is left unchanged.
        3. **Body+notes section splitting**: every ``BODY`` Node whose
           text contains the ``(1) `` marker (the leading marker of the
           notes section) is walked; the prefix before the first
           ``(1) `` stays as the host BODY text, then each ``(N) ...``
           chunk becomes a synthetic ``NOTE`` Node minted as a sibling
           after the host. A ``Transformation`` with ``split_into`` is
           recorded for each split.
        4. **Inline cross-reference minting**: every body Node (BODY,
           HEADING_1, etc.) whose text contains an inline ``\\w+(N)``
           match has a synthetic ``CROSS_REFERENCE`` Node minted as a
           sibling immediately after it. The synthetic Node's text is
           the verbatim ``"(N)"`` marker.

        The four transformations share a single ``_NodeIdMinter`` that
        seeds at one past the maximum tier 1 counter. Pending warnings
        from :meth:`refine_classification` are flushed into
        ``Document.warnings`` here together with the per-transformation
        warnings produced by this method.
        """
        del classified_blocks

        new_warnings = list(self._pending_warnings)
        self._pending_warnings = []
        new_transformations: list[Transformation] = []

        minter = _NodeIdMinter(start=_max_existing_node_counter(document.root) + 1)

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
        """Bind synthetic CROSS_REFERENCE Nodes to their target NOTE Nodes globally.

        Three responsibilities:

        1. Build a global ``marker → NOTE node_id`` index over the
           full document tree by scanning every NOTE Node minted in
           :meth:`refine_reconstruction` (tracked in
           :attr:`_minted_note_ids`) and parsing its leading ``(N) ``
           marker with :data:`_NOTE_MARKER_PATTERN`.
        2. Walk every synthetic CROSS_REFERENCE Node minted in
           :meth:`refine_reconstruction` (tracked in
           :attr:`_minted_crossref_ids`), extract the marker via
           :data:`_NOTE_MARKER_PATTERN`, look up in the index, and
           attach an :class:`ApparatusRef` with kind
           ``CROSS_REF_TARGET``. Unresolved cross-references emit a
           ``cross_reference_unresolved_node_<id>_marker_<n>`` warning.
        3. Filter the Document's warnings tuple to drop tier 1
           generic resolver warnings (``unparseable_cross_reference_*``,
           ``unresolved_cross_reference_*``) that target this plugin's
           synthetic Nodes — the tier 1 generic resolver runs before
           the plugin's apparatus pass and may emit spurious warnings
           on synthetic Nodes whose binding the plugin then resolves.
        """
        del extraction, classified_blocks

        marker_index = self._build_note_marker_index(document.root)
        new_root, new_warnings = self._bind_cross_references_globally(document.root, marker_index)
        filtered_warnings = self._filter_tier1_crossref_warnings(document.warnings)

        return Document(
            root=new_root,
            warnings=filtered_warnings + tuple(new_warnings),
            transformations=document.transformations,
        )

    # ------------------------------------------------------------------
    # Per-block reclassification

    def _reclassify(self, verdict: ClassifiedBlock, view: _BlockView) -> ClassifiedBlock:
        if self._is_genre_banner(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.GENRE_BANNER,
                reason="dejure_nota_sentenza_banner",
            )
        if self._is_page_header_tagline(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.ARTIFACT_PAGE_HEADER,
                reason="dejure_nota_sentenza_page_header_tagline",
            )
        if self._is_title(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.TITLE,
                reason="dejure_nota_sentenza_title",
            )
        if self._is_metadata_block(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.META_VALUE,
                reason="dejure_nota_sentenza_metadata_block",
            )
        if self._is_sommario_block(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.TOC_GENERAL,
                reason="dejure_nota_sentenza_sommario",
            )
        if self._is_subtitle(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.SUBTITLE,
                reason="dejure_nota_sentenza_subtitle",
            )
        if self._is_section_heading(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.HEADING_1,
                reason="dejure_nota_sentenza_section_heading",
            )
        if self._is_notes_section(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.SECTION_LABEL,
                reason="dejure_nota_sentenza_notes_section",
            )
        if self._is_footer(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.ARTIFACT_FOOTER,
                reason="dejure_nota_sentenza_footer",
            )
        if self._is_copyright_stamp(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.ARTIFACT_STAMP,
                reason="dejure_nota_sentenza_copyright_stamp",
            )
        if self._is_body(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.BODY,
                reason="dejure_nota_sentenza_body",
            )
        return verdict

    # ------------------------------------------------------------------
    # Predicates

    @staticmethod
    def _is_genre_banner(view: _BlockView) -> bool:
        """Banner ``"NOTE E DOTTRINA"`` at Arial-BoldMT 9pt."""
        if not view.spans:
            return False
        leading = view.spans[0]
        family_ok = leading.font.startswith(ARIAL_BOLD_FAMILY)
        size_ok = abs(leading.size - BANNER_SIZE) < SIZE_TOLERANCE
        if not (family_ok and size_ok):
            return False
        return view.text.strip() == BANNER_TEXT_NOTE_E_DOTTRINA

    @staticmethod
    def _is_page_header_tagline(view: _BlockView) -> bool:
        """Page-1 header tagline ``"Banche dati editoriali GFL"``."""
        return PAGE_HEADER_TEXT_FRAGMENT in view.text

    @staticmethod
    def _is_title(view: _BlockView) -> bool:
        """Title block at Arial-BoldMT 13pt.

        The 13pt bold Arial size is unique to the title in a DeJure NS
        document; the predicate is therefore a pure typographic check
        on the leading span and tolerates multi-line titles whose
        subsequent spans share the same family and size.
        """
        if not view.spans:
            return False
        leading = view.spans[0]
        family_ok = leading.font.startswith(ARIAL_BOLD_FAMILY)
        size_ok = abs(leading.size - TITLE_SIZE) < SIZE_TOLERANCE
        return family_ok and size_ok

    @staticmethod
    def _is_metadata_block(view: _BlockView) -> bool:
        """Metadata block at 9pt Arial containing at least one of the
        three expected labels.

        The empirical inspection shows two variants of the label spans:
        in the short narrative fixture (3 pp) the labels ``Fonte:``,
        ``Nota a:``, ``Autori:`` are emitted at ``ArialMT`` 9pt
        regular while the values are at ``Arial-BoldMT`` 9pt bold;
        in the long academic fixture (22 pp) both labels and values
        are at ``Arial-BoldMT`` 9pt. The predicate is therefore
        font-flag agnostic on the leading span (admits either Arial-
        BoldMT or ArialMT) and matches the block as a whole on its
        9pt size plus the textual presence of at least one of the
        three label markers in the joined block text.
        """
        if not view.spans:
            return False
        leading = view.spans[0]
        family_ok = leading.font.startswith(ARIAL_FAMILY_PREFIX)
        size_ok = abs(leading.size - BANNER_SIZE) < SIZE_TOLERANCE
        if not (family_ok and size_ok):
            return False
        text = view.text
        return any(
            label in text
            for label in (METADATA_LABEL_FONTE, METADATA_LABEL_NOTA_A, METADATA_LABEL_AUTORI)
        )

    @staticmethod
    def _is_sommario_block(view: _BlockView) -> bool:
        """Sommario block at ArialMT 12pt starting with the literal ``"Sommario"``."""
        if not view.spans:
            return False
        leading = view.spans[0]
        family_ok = leading.font.startswith(ARIAL_REGULAR_FAMILY) or leading.font.startswith(
            ARIAL_BOLD_FAMILY
        )
        size_ok = abs(leading.size - BODY_SIZE) < SIZE_TOLERANCE
        if not (family_ok and size_ok):
            return False
        return view.text.lstrip().startswith(SOMMARIO_TEXT_PREFIX)

    @staticmethod
    def _is_subtitle(view: _BlockView) -> bool:
        """Subtitle ``"Quotidiano del <date>"`` at ArialMT 12pt regular.

        Discriminated from body via the textual prefix. The bold
        section headings and the sommario are intercepted before the
        body and subtitle predicates, so this predicate cannot
        absorb them by accident.
        """
        if not view.spans:
            return False
        leading = view.spans[0]
        family_ok = leading.font.startswith(ARIAL_REGULAR_FAMILY)
        size_ok = abs(leading.size - BODY_SIZE) < SIZE_TOLERANCE
        if not (family_ok and size_ok):
            return False
        return view.text.lstrip().startswith(SUBTITLE_TEXT_PREFIX)

    @staticmethod
    def _is_section_heading(view: _BlockView) -> bool:
        """Section heading at Arial-BoldMT 12pt with numbered uppercase pattern.

        The 12pt size is shared with the body; the bold flag and the
        text pattern are the discriminators. The pattern requires the
        text to open with ``N.`` followed by whitespace and an
        uppercase letter; a body paragraph that happens to open with
        a lower-case ordinal is ignored.
        """
        if not view.spans:
            return False
        leading = view.spans[0]
        family_ok = leading.font.startswith(ARIAL_BOLD_FAMILY)
        size_ok = abs(leading.size - BODY_SIZE) < SIZE_TOLERANCE
        if not (family_ok and size_ok):
            return False
        return bool(_SECTION_HEADING_PATTERN.match(view.text.strip()))

    @staticmethod
    def _is_notes_section(view: _BlockView) -> bool:
        """``"Note:"`` opening marker — standalone or glued with notes content.

        The empirical inspection of the long-academic fixture shows
        that PyMuPDF fuses the ``Note:`` marker and the subsequent
        concatenated ``(1) ... (2) ...`` notes into a single block.
        The predicate therefore accepts both the standalone ``Note:``
        case (block whose stripped text is exactly the marker) and
        the glued case (block whose stripped text starts with the
        marker and continues with the notes prose). In either case
        the block is classified as ``SECTION_LABEL`` and the body+notes
        splitter in :meth:`refine_reconstruction` peels off the
        bibliographic notes into synthetic ``NOTE`` sibling Nodes.
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
        # PyMuPDF reports either ``ArialItalic`` (page footer) or
        # ``Arial-ItalicMT`` (inline body italic); both start with
        # ``Arial`` so the family check accepts both, and the size
        # + italic-flag check narrows down.
        family_ok = leading.font.startswith(ARIAL_FAMILY_PREFIX)
        size_ok = abs(leading.size - BODY_SIZE) < SIZE_TOLERANCE
        italic_ok = leading.is_italic
        if not (family_ok and size_ok and italic_ok):
            return False
        return bool(_FOOTER_PATTERN.match(view.text.strip()))

    @staticmethod
    def _is_copyright_stamp(view: _BlockView) -> bool:
        """Copyright stamp at ArialMT 10.5pt containing one of the closed fragments."""
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
        """Body prose at Arial 12pt non-bold.

        Catch-all body predicate dispatched near the end of the
        predicate cascade. A body block may open with either
        ``ArialMT`` regular or ``Arial-ItalicMT`` italic (a body
        paragraph that opens with a French-quoted citation typeset in
        italic). Bold Arial 12pt blocks are intercepted earlier
        (section heading, notes section) and never reach this predicate.
        """
        if not view.spans:
            return False
        leading = view.spans[0]
        family_ok = leading.font.startswith(ARIAL_FAMILY_PREFIX)
        size_ok = abs(leading.size - BODY_SIZE) < SIZE_TOLERANCE
        not_bold = not leading.is_bold
        return family_ok and size_ok and not_bold

    # ------------------------------------------------------------------
    # Refine reconstruction: META decomposition + TOC parsing + notes split + CR mint

    def _refine_forest(
        self,
        roots: tuple[Node, ...],
        warnings: list[str],
        transformations: list[Transformation],
        minter: _NodeIdMinter,
    ) -> tuple[Node, ...]:
        """Walk the forest level by level, refining descendants first then
        applying sibling-aware transformations to each children list.

        At each parent the children list is processed in three passes:

        1. **Per-Node pass**: every ``META_VALUE`` is decomposed into
           ``FONTE_VALUE`` + ``REFERRAL`` + ``AUTHORS`` siblings; every
           ``TOC_GENERAL`` has its ``toc_items`` populated and a trailing
           section heading is split off as a sibling ``HEADING_1`` if
           present.
        2. **Notes consolidation pass**: a ``SECTION_LABEL`` Node whose
           text starts with the ``"Note:"`` marker triggers a
           multi-sibling absorption of the BODY Nodes that follow it in
           the list (up to the next ``HEADING_N`` or ``SECTION_LABEL`` or
           end of the list). The absorbed text is split on the regex
           :data:`_NOTE_SPLIT_PATTERN` and one synthetic ``NOTE`` Node is
           minted per ``(N) ...`` chunk; the original BODY siblings are
           removed.
        3. **Cross-reference minting pass**: every body-category Node
           (``BODY`` or ``HEADING_1``) is scanned for inline ``\\w+(N)``
           markers and a synthetic ``CROSS_REFERENCE`` sibling is minted
           per match. The synthetic ``NOTE`` Nodes minted in pass 2 are
           **not** scanned (a ``(N)`` marker at the start of a NOTE
           text is the note's own number, not a cross-reference).
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
        minter: _NodeIdMinter,
    ) -> tuple[Node, ...]:
        """Apply the three refinement passes to a parent's children list."""
        # PASS 1: per-Node refinement (META + TOC).
        pass1: list[Node] = []
        for child in children:
            if child.category is SemanticCategory.META_VALUE and child.text is not None:
                pass1.extend(self._decompose_metadata(child, warnings, transformations, minter))
            elif child.category is SemanticCategory.TOC_GENERAL and child.text is not None:
                pass1.extend(self._parse_toc_general(child, warnings, minter))
            else:
                pass1.append(child)

        # PASS 2: notes consolidation across siblings.
        pass2 = self._consolidate_notes_section(tuple(pass1), warnings, transformations, minter)

        # PASS 3: CR minting on body Nodes only, skipping any Node minted
        # in pass 2 (synthetic NOTE Nodes) or carrying the notes-section
        # marker.
        pass3: list[Node] = []
        for child in pass2:
            if (
                child.text is not None
                and child.category in {SemanticCategory.BODY, SemanticCategory.HEADING_1}
                and child.id not in self._minted_note_ids
            ):
                pass3.extend(self._maybe_mint_cross_references(child, warnings, minter))
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
        minter: _NodeIdMinter,
    ) -> list[Node]:
        """Split a META_VALUE Node into FONTE_VALUE + REFERRAL + AUTHORS siblings.

        The Aspose pipeline joins spans without newline separators, so
        ``host.text`` is the three metadata lines concatenated into a
        single string (``"Fonte: ...Nota a: ...Autori: ..."``). The
        decomposition uses a positive-look-ahead regex split on the
        three label markers so each segment starts with its own label;
        a straight ``str.splitlines()`` would yield a single line.

        If any of the three expected labels is missing, the host is
        kept intact and a per-occurrence
        ``metadata_block_unparseable_*`` warning is emitted.
        """
        assert host.text is not None
        chunks = re.split(
            r"(?=Fonte:|Nota a:|Autori:)",
            host.text,
        )

        fonte_line: str | None = None
        nota_a_line: str | None = None
        autori_line: str | None = None
        for chunk in chunks:
            stripped = chunk.strip()
            if stripped.startswith(METADATA_LABEL_FONTE):
                fonte_line = stripped
            elif stripped.startswith(METADATA_LABEL_NOTA_A):
                nota_a_line = stripped
            elif stripped.startswith(METADATA_LABEL_AUTORI):
                autori_line = stripped

        if not (fonte_line and nota_a_line and autori_line):
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
            (nota_a_line, SemanticCategory.REFERRAL, "nota_a"),
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
                step_id="dejure_nota_sentenza_metadata_decompose",
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
        minter: _NodeIdMinter,
    ) -> list[Node]:
        """Parse a TOC_GENERAL Node into ``toc_items`` + (optionally) a trailing HEADING_1.

        The empirical inspection of the long-academic fixture shows
        that PyMuPDF sometimes fuses the sommario prose with the
        first numbered section heading typeset on the next line:
        the block text reads ``"Sommario 1. ... — 2. ... — ... — 5. ...
        . 1. INQUADRAMENTO ..."`` where the trailing ``"1. INQUADRAMENTO ..."``
        is the actual section 1 heading in MAIUSCOLO. The parser
        therefore:

        1. Strips the leading ``"Sommario"`` prefix and any
           non-breaking whitespace that follows it.
        2. Splits the body on ``" — "`` separators and parses each
           segment as ``"<n>. <title>"``.
        3. Detects whether the last sommario segment contains a
           trailing ``". <n>. <UPPERCASE>"`` pattern: if so, the
           UPPERCASE portion is split off as a synthetic ``HEADING_1``
           sibling Node and the sommario segment is truncated.

        Returns the list of Nodes that replace the original
        TOC_GENERAL: at minimum the TOC_GENERAL with parsed
        ``toc_items``, possibly followed by a synthetic HEADING_1
        sibling if a trailing section heading was detected.
        """
        assert node.text is not None
        text = node.text
        # Strip the leading "Sommario" prefix and any whitespace.
        stripped = re.sub(r"^Sommario\s*", "", text.strip())

        # Look for a trailing section heading fused to the last
        # sommario entry. Pattern: "...title. <n>. <UPPERCASE>..."
        # where <n> is one or two digits and the UPPERCASE letters
        # continue for several characters.
        trailing_heading_match = re.search(
            r"\.\s+(\d+)\.\s+([A-ZÀÈÉÌÒÓÙÚ«»][A-ZÀÈÉÌÒÓÙÚ«»\s\-:,'’.]{5,}?)\s*$",  # noqa: RUF001
            stripped,
        )
        trailing_heading_text: str | None = None
        if trailing_heading_match is not None:
            heading_number = trailing_heading_match.group(1)
            heading_title = trailing_heading_match.group(2).strip()
            trailing_heading_text = f"{heading_number}. {heading_title}"
            # Truncate the sommario text to just before the trailing
            # heading.
            stripped = stripped[: trailing_heading_match.start()].rstrip() + "."

        # Split on em-dash separators.
        segments = re.split(r"\s*[—–]\s*", stripped)  # noqa: RUF001
        items: list[TocGeneralItem] = []
        for seg in segments:
            seg = seg.strip()
            match = re.match(r"^(\d+)\.\s+(.+?)\.?\s*$", seg)
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

        if trailing_heading_text is None:
            return [toc_node]

        heading_id = minter.mint()
        heading_node = Node(
            id=heading_id,
            category=SemanticCategory.HEADING_1,
            page_index=node.page_index,
            block_indices=node.block_indices,
            text=trailing_heading_text,
            level=1,
        )
        return [toc_node, heading_node]

    # ------------------------------------------------------------------
    # Body+notes splitter

    def _consolidate_notes_section(
        self,
        children: tuple[Node, ...],
        warnings: list[str],
        transformations: list[Transformation],
        minter: _NodeIdMinter,
    ) -> tuple[Node, ...]:
        """Find the SECTION_LABEL ``"Note:"`` and consolidate the following siblings.

        Walks the children list looking for a ``SECTION_LABEL`` Node
        whose text starts with the ``"Note:"`` marker. When found, the
        Node itself (which may already carry the concatenated
        ``(1) ... (2) ...`` notes prose glued by Aspose) and every
        subsequent ``BODY`` sibling up to the next ``HEADING_N`` /
        ``SECTION_LABEL`` / end-of-list boundary are absorbed into a
        single notes-section text. The concatenated text is split on
        the regex :data:`_NOTE_SPLIT_PATTERN` and one synthetic
        ``NOTE`` Node is minted per ``(N) ...`` chunk. The original
        SECTION_LABEL Node is kept as the surviving marker (with its
        text reduced to just ``"Note:"``); the absorbed BODY siblings
        are removed and the synthetic NOTE Nodes are inserted in
        their place.

        Returns the rebuilt children tuple. If no ``"Note:"``
        SECTION_LABEL is present in the list, the original tuple is
        returned unchanged.
        """
        out: list[Node] = []
        i = 0
        n = len(children)
        while i < n:
            child = children[i]
            if not (
                child.category is SemanticCategory.SECTION_LABEL
                and child.text is not None
                and self._starts_with_notes_marker(child.text)
            ):
                out.append(child)
                i += 1
                continue

            # Found the SECTION_LABEL marker. Determine the post-marker
            # body of this Node and the contiguous BODY siblings that
            # follow it in the list.
            marker_match = self._match_notes_marker(child.text)
            assert marker_match is not None
            marker_end = marker_match.end()
            host_post_text = child.text[marker_end:].strip()

            absorbed_block_indices: list[int] = list(child.block_indices)
            absorbed_text_parts: list[str] = []
            if host_post_text:
                absorbed_text_parts.append(host_post_text)

            # Walk subsequent siblings. ARTIFACT_FOOTER and similar
            # interleaving artifacts are kept aside (passed through in
            # order after the synthetic NOTE Nodes); BODY Nodes are
            # absorbed into the consolidated notes text; HEADING /
            # SECTION_LABEL / other structural categories end the
            # absorption.
            j = i + 1
            absorbed_ids: list[str] = []
            passthrough: list[Node] = []
            while j < n:
                sibling = children[j]
                if sibling.category in _NOTES_SECTION_BOUNDARY_CATEGORIES:
                    break
                if (
                    sibling.category in {SemanticCategory.BODY, SemanticCategory.NOTE}
                    and sibling.text is not None
                ):
                    absorbed_text_parts.append(sibling.text)
                    absorbed_block_indices.extend(sibling.block_indices)
                    absorbed_ids.append(sibling.id)
                    j += 1
                    continue
                if sibling.category in _NOTES_SECTION_PASSTHROUGH_CATEGORIES:
                    passthrough.append(sibling)
                    j += 1
                    continue
                # Unknown category — stop absorption to be safe.
                break

            if not absorbed_text_parts:
                # Standalone "Note:" marker with no glued notes and no
                # following BODY siblings — nothing to consolidate.
                out.append(child)
                i += 1
                continue

            joined_notes_text = " ".join(absorbed_text_parts)
            split_result = self._split_notes_text(
                joined_notes_text,
                page_index=child.page_index,
                block_indices=tuple(absorbed_block_indices),
                warnings=warnings,
                minter=minter,
            )
            if not split_result:
                # Could not parse the notes text — leave the children
                # list intact and emit a diagnostic warning.
                warnings.append(f"{WARNING_PREFIX}:note_section_unparseable_node_{child.id}")
                out.append(child)
                i += 1
                continue

            # Surviving SECTION_LABEL keeps just the "Note:" marker text.
            marker_literal = child.text[:marker_end].strip() or "Note:"
            survivor = replace(child, text=marker_literal)

            # Record a single Transformation that documents the
            # multi-sibling absorption.
            transformations.append(
                Transformation(
                    step_id="dejure_nota_sentenza_notes_section_consolidate",
                    node_id=child.id,
                    page_index=child.page_index,
                    position=(marker_end, len(child.text)),
                    original=child.text[marker_end:],
                    normalized="",
                    split_into=tuple(n.id for n in split_result),
                    merged_from=tuple(absorbed_ids) or None,
                )
            )

            out.append(survivor)
            out.extend(split_result)
            out.extend(passthrough)
            i = j
        return tuple(out)

    @staticmethod
    def _starts_with_notes_marker(text: str) -> bool:
        stripped = text.lstrip()
        return any(stripped.startswith(marker) for marker in NOTES_MARKER_TEXT_VARIANTS)

    @staticmethod
    def _match_notes_marker(text: str) -> re.Match[str] | None:
        stripped = text.lstrip()
        prefix_skip = len(text) - len(stripped)
        for marker in NOTES_MARKER_TEXT_VARIANTS:
            if stripped.startswith(marker):
                pattern = re.compile(re.escape(marker))
                return pattern.match(text, prefix_skip)
        return None

    def _split_notes_text(
        self,
        notes_text: str,
        *,
        page_index: int,
        block_indices: tuple[int, ...],
        warnings: list[str],
        minter: _NodeIdMinter,
    ) -> list[Node]:
        """Split a notes-section text into one synthetic NOTE Node per ``(N) ...`` chunk."""
        # Confirm the text contains at least the ``(1)`` opening marker.
        if not re.match(r"\s*\(1\)", notes_text):
            return []

        chunks = _NOTE_SPLIT_PATTERN.split(notes_text)
        minted: list[Node] = []
        for chunk in chunks:
            chunk = chunk.strip()
            if not chunk:
                continue
            chunk_marker = _NOTE_MARKER_PATTERN.match(chunk)
            if chunk_marker is None:
                continue
            marker_value = chunk_marker.group(1)
            new_id = minter.mint()
            note_node = Node(
                id=new_id,
                category=SemanticCategory.NOTE,
                page_index=page_index,
                block_indices=block_indices,
                text=chunk,
            )
            minted.append(note_node)
            self._minted_note_ids.add(new_id)
            warnings.append(
                f"{WARNING_PREFIX}:note_section_split_minted_node_"
                f"{new_id}_page_{page_index}_marker_{marker_value}"
            )
        return minted

    # ------------------------------------------------------------------
    # Inline cross-reference minting

    def _maybe_mint_cross_references(
        self,
        node: Node,
        warnings: list[str],
        minter: _NodeIdMinter,
    ) -> list[Node]:
        """Mint synthetic CROSS_REFERENCE siblings for inline ``\\w+(N)`` matches.

        Returns ``[node, *minted_crossrefs]``. If no inline matches are
        found, returns ``[node]`` unchanged.

        The host Node's text is NOT modified — the inline ``(N)``
        markers stay embedded in the body prose, exactly as Aspose
        emitted them. Layer 2 will use the synthetic CROSS_REFERENCE
        Nodes to render the inline anchors (Layout 4) and the body
        prose verbatim (Layouts 1-3).
        """
        if node.text is None:
            return [node]
        matches = list(_CROSSREF_INLINE_PATTERN.finditer(node.text))
        if not matches:
            return [node]

        out: list[Node] = [node]
        for match in matches:
            marker_value = match.group(1)
            if int(marker_value) > _CROSSREF_MAX_MARKER_VALUE:
                continue
            marker_text = match.group(0)  # ``(N)`` verbatim
            new_id = minter.mint()
            crossref = Node(
                id=new_id,
                category=SemanticCategory.CROSS_REFERENCE,
                page_index=node.page_index,
                block_indices=node.block_indices,
                text=marker_text,
            )
            out.append(crossref)
            self._minted_crossref_ids.add(new_id)
            warnings.append(
                f"{WARNING_PREFIX}:cross_reference_minted_node_"
                f"{new_id}_page_{node.page_index}_marker_{marker_value}"
            )
        return out

    # ------------------------------------------------------------------
    # Apparatus: binding + warning filtering

    def _build_note_marker_index(self, roots: tuple[Node, ...]) -> dict[str, str]:
        """Build a global ``marker → NOTE node_id`` index.

        Walks every Node minted in :meth:`refine_reconstruction` as a
        NOTE (tracked in :attr:`_minted_note_ids`) and parses its
        leading ``(N) `` marker. On collision (two notes with the same
        marker, which the DeJure NS corpus does not exhibit) the first
        wins.
        """
        index: dict[str, str] = {}
        for node in _iter_nodes(roots):
            if node.id not in self._minted_note_ids:
                continue
            if node.text is None:
                continue
            match = _NOTE_MARKER_PATTERN.match(node.text)
            if match is None:
                continue
            marker = match.group(1)
            index.setdefault(marker, node.id)
        return index

    def _bind_cross_references_globally(
        self,
        roots: tuple[Node, ...],
        marker_index: dict[str, str],
    ) -> tuple[tuple[Node, ...], list[str]]:
        """Walk the forest, bind every synthetic CROSS_REFERENCE Node to
        its target NOTE, and emit unresolved warnings.

        Returns the rebuilt forest and the list of new warnings.
        """
        warnings: list[str] = []

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
                    target_id = marker_index.get(marker)
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
        """Drop tier 1 ``unparseable_cross_reference_*`` and
        ``unresolved_cross_reference_*`` strings that belong to this
        plugin's synthetic CROSS_REFERENCE Nodes.

        The tier 1 generic resolver scans every CROSS_REFERENCE Node
        in the tree and emits a warning if it cannot bind it to a NOTE
        within the HEADING ancestor scope. The plugin owns its
        synthetic Nodes and resolves them globally in
        :meth:`_bind_cross_references_globally`; the tier 1 warnings
        are uninformative noise for those Nodes and are filtered out
        here.
        """
        kept: list[str] = []
        for warning in warnings:
            drop = False
            for node_id in self._minted_crossref_ids:
                if warning == f"unparseable_cross_reference_node_{node_id}" or warning.startswith(
                    f"unresolved_cross_reference_node_{node_id}_"
                ):
                    drop = True
                    break
            if not drop:
                kept.append(warning)
        return tuple(kept)

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
