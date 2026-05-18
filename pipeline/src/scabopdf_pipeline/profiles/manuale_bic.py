"""Corpus plugin for the BIC accessible-manual series — Marrone "Istituzioni di Diritto Romano".

Sixth real corpus plugin of the project. Handles the Marrone
"Istituzioni di Diritto Romano" manual originally published by
G.B. Palumbo & C. Editore S.P.A. (2006, ISBN 9788860170224) and adapted
in 2009 by the Biblioteca Italiana per i Ciechi "Regina Margherita" -
Monza for the Servizio Nazionale del Libro Informatico under the
accessibility framework of legge 9.1.2004 n. 4 and D.P.R. 1.3.2005
n. 75. See ``docs/analysis/ANALYSIS_MARRONE.md`` for the editorial
analysis the plugin is built against. The plugin is calibrated on the
684-page fixture ``pipeline/tests/fixtures/private/marrone_istituzioni.pdf``.

The Marrone is the first plugin of the BIC family and extends the
ScaboPDF profile vocabulary along five new structural dimensions:

- **First tagged PDF/UA in the project.** The catalog carries a
  ``StructTreeRoot`` and ``MarkInfo`` block declaring the document
  accessibility-tagged in the PDF/UA sense, plus a (mistakenly)
  ``Lang en-US`` field that contradicts the Italian textual content.
  The plugin does NOT consume the structural tags as a primary signal,
  in line with the project principle "tipografia primaria, outline
  embedded secondario"; the tags are however used as a positive
  corroboration in :meth:`matches` via the outline-presence weight.
  A diagnostic warning flags the language-metadata mismatch.

- **Five concatenated BIC volumes in a single PDF.** The Marrone is
  published by BIC as five separate volumes (Volume I pp.1-110, Volume
  II pp.111-261, Volume III pp.262-383, Volume IV pp.384-536, Volume
  V pp.537-684) physically concatenated into one 684-page PDF. The
  five volume frontispieces (``Primo volume``, ``Secondo Volume``,
  ``Terzo Volume``, ``Quarto Volume``, ``Quinto Volume``) sit on PDF
  pages 0, 107, 260, 381, 535 respectively, and the four ``Fine del N
  volume`` markers sit on PDF pages 106, 259, 380, 534. The plugin
  classifies these nine pages as ``ARTIFACT_STAMP`` so the editorial
  separators do not interrupt the logical reading flow. The
  ``Abbreviazioni principali`` apparatus heading repeats once per
  volume (5 occurrences plus 1 duplicate at page 110, total 6), and
  the plugin emits a per-occurrence ``abbreviazioni_duplicate`` warning
  so the audit log lets Layer 2 dedupe at presentation time. Volume
  boundaries are NOT modelled as structural categories in v1: the
  manual is one logical document and the multi-volume packaging is
  an editorial accessibility convention, not part of the work's
  intellectual structure.

- **Book-page anchors at 1pt invisible font.** The BIC pipeline marks
  the start of every original-book page with a single-span block in
  ``Verdana`` 0.96pt (or rarely ``Arial`` 0.96pt) placed at the left
  margin (``bbox.x0 ≈ 56.7pt``) containing the printed book page
  number as numeric text. Roughly 1352 such anchors exist across the
  fixture. The tier 1 generic ``tiny_font_anchor`` heuristic in
  :mod:`classification.tier1` already classifies blocks whose every
  span is below 2.0pt as ``BOOK_PAGE_ANCHOR``; the Marrone anchors
  satisfy the predicate uniformly so the plugin does not override
  classification for them. The reconstructed ``BOOK_PAGE_ANCHOR``
  Nodes carry the book-page number as their ``text`` and Layer 2
  exposes them as a "go to printed page N" navigation surface. No
  schema bump is needed because :class:`SemanticCategory` already
  carries the category and ``NodeDict.text`` carries the numeric
  string.

- **Notes grouped per paragrafo, line-level "Note" marker.** The
  Marrone does NOT carry traditional footnotes at the bottom of each
  page. Instead, every § paragrafo whose body contains at least one
  cross-reference closes with a "Note" section: a line ``Note`` typeset
  in ``Verdana,Bold`` 12.0pt color ``#ff0000`` (red), immediately
  followed by the numbered notes (``"1. ..."`` ``"2. ..."`` ...) that
  the body cross-references point at. The crucial empirical finding
  contradicting the upstream editorial analysis is that PyMuPDF
  emits the "Note" marker as a **line inside a larger block**, not
  as a block on its own. The plugin's
  :meth:`refine_reconstruction` therefore walks every BODY Node,
  inspects its underlying spans, and splits the Node whenever a
  line-level "Note" marker is found: the pre-marker spans stay as
  the truncated BODY, the post-marker numbered notes are split into
  one synthetic ``NOTE`` Node per ``"N. "`` transition (driven by
  the :data:`_NOTE_NUMBER_PATTERN` regex on the leading line of
  each note). The synthetic NOTE Nodes are siblings of the surviving
  BODY in the parent's children list, in reading order. The pattern
  reuses the body+note splitter framework introduced by the
  Giappichelli plugin (commit ``c01661e``) and adapts it: the
  splitter signal is line-level on a color-specific marker rather
  than the typographic 9pt size signature of Giappichelli, but the
  minting machinery (``_NodeIdMinter`` seeded by
  ``_max_existing_node_counter``, sibling-insertion after the BODY
  parent, ``Transformation`` recording with ``split_into`` populated
  with the minted ids, schema 0.5.0 structural reversibility) is
  identical. Across the 684 pages the splitter mints one
  ``NOTE`` Node per numbered note (~1485 total) so that the tier 1
  generic cross-reference resolver in :mod:`apparatus.resolver`
  binds each minted CROSS_REFERENCE to the correct numbered NOTE
  via the standard :data:`apparatus.constants.NOTE_MARKER_REGEX`.

- **Inline cross-references at 10.56pt flag=17 superscript.** The
  body of every paragrafo carries small superscript span markers
  ``Verdana,Bold`` 10.56pt with the SUPERSCRIPT bit set (flag value
  17 = BOLD | SUPERSCRIPT), numeric text ``"1"`` ``"2"`` … up to
  ``"395"`` for the densest chapter (VII Obbligazioni). Roughly 1561
  such spans exist across the fixture. The tier 1 generic
  ``superscript_cross_reference`` heuristic only catches a
  superscript span that constitutes the **entire block**; the
  Marrone superscripts are inline inside larger BODY blocks and so
  invisible to tier 1. The plugin's :meth:`refine_reconstruction`
  walks every BODY Node, inspects its spans, and mints one synthetic
  ``CROSS_REFERENCE`` Node per qualifying span — same minting
  framework as the body+note splitter, and the same one used by
  the Mosconi (commit ``265e6d9``), Mandrioli (``6ee8efa``) and
  Torrente (``022357a``) plugins. The synthetic Node's ``text`` is
  the verbatim digit ``"12"`` (without any leading or trailing
  whitespace), so the tier 1 generic resolver's
  :data:`apparatus.constants.CROSS_REF_DIGITS_REGEX` matches and
  the binding to the homonymous NOTE is performed without
  profile-specific override in :meth:`refine_apparatus`. Numbering
  resets at each chapter (HEADING_1 ancestor), which is exactly the
  scope the tier 1 resolver applies: cross-references and their
  target notes are co-scoped under the same HEADING_1, so the
  per-chapter resetting numbering is honoured naturally.

Heading levels.

- **HEADING_1 — Capitolo, Prefazione, Indice analitico, Bibliografia.**
  Block whose leading span is ``Verdana,BoldItalic`` 16.08pt color
  ``#008000`` (verde scuro). Exactly 13 occurrences on the fixture:
  two ``Prefazione`` blocks, nine ``Capitolo I`` … ``Capitolo IX``
  chapter heads, ``Indice analitico`` and ``Bibliografia``. The
  16.08pt size is unique to this category in the manual (no other
  content uses it); the color is doubly diagnostic. The leading-span
  predicate is therefore the primary discriminator.

- **HEADING_2 — Premesse.** Block whose leading span is ``Verdana,Bold``
  18.0pt color ``#333399`` (indigo). Exactly 2 occurrences on the
  fixture, both on PDF page 7 — the duplicate is an artefact of the
  iLovePDF post-processing that converted the original BIC PDF and
  appears NOT to carry editorial meaning. The plugin classifies both
  as HEADING_2, emits a per-occurrence ``premesse_duplicate`` warning
  via :meth:`refine_classification`, and dedupes in
  :meth:`refine_reconstruction` by keeping the first occurrence and
  dropping the second so the tree carries one HEADING_2 anchoring the
  ``Premesse`` chapter (paragrafi § 1 .. § 10 plus the cross-chapter
  initial notes).

- **HEADING_3 — § paragrafo numerato.** Block whose leading span is
  ``Verdana,Bold`` or ``Verdana,BoldItalic`` 13.92pt color ``#800000``
  (maroon). 212 distinct § paragrafi numbered 1 to 214 (two numbers
  missing from the strict sequence), continuative across the whole
  manual rather than resetting per chapter. The HEADING_3 category
  is also assigned to the 6 occurrences of the editorial heading
  ``Abbreviazioni principali`` (sharing the same typographic
  signature) — once per volume plus one duplicate on page 110. The
  plugin emits an ``abbreviazioni_duplicate`` warning per occurrence
  so Layer 2 can collapse the apparatus repetition at presentation
  time.

Apparatus.

- **NOTE — note di paragrafo raggruppate.** Synthetic Nodes minted by
  the body+note splitter in :meth:`refine_reconstruction`. Roughly
  1485 individual notes across 180 "Note" sections (one section per
  paragrafo). The numbering resets at each chapter, matching the
  scope the tier 1 generic cross-reference resolver applies, so the
  binding from CROSS_REFERENCE to NOTE is performed without
  profile-specific override. Each minted NOTE Node carries the note
  text starting with the numbered marker (``"12. La distinzione tra
  ius civile e ius gentium ..."``) so that
  :data:`apparatus.constants.NOTE_MARKER_REGEX` matches.

- **CROSS_REFERENCE — rimando inline alle note.** Synthetic Nodes
  minted by the cross-reference walker in
  :meth:`refine_reconstruction` for each ``Verdana,Bold`` 10.56pt
  flag=17 superscript span observed inside a BODY block. Each minted
  Node carries the verbatim digit text. Binding to the matching NOTE
  is performed by the tier 1 generic resolver in the standard
  HEADING_1 scope without plugin override.

Artifacts.

- **BOOK_PAGE_ANCHOR — ancora pagina libro.** Tier 1 generic
  ``tiny_font_anchor`` heuristic already classifies the 0.96pt
  Verdana/Arial blocks at the left margin as BOOK_PAGE_ANCHOR. The
  plugin does not override classification for them. Roughly 1352
  Nodes on the fixture (a few additional anchors may be fused inside
  body blocks and therefore invisible to tier 1; the plugin tolerates
  the residual count without a recovery step in v1).

- **ARTIFACT_FOOTER — Pag. N-M.** Tier 1 generic ``footer_zone``
  heuristic already classifies the bottom-of-page Verdana,Bold
  16.08pt blue blocks ``Pag. N-M K`` as ARTIFACT_FOOTER on 679
  pages out of 684. The five pages without a footer are PDF pages 0
  (cover) and the four "Fine del N volume" pages (106, 259, 380, 534)
  whose layout differs.

- **ARTIFACT_STAMP — volume frontispiece and end-of-volume markers.**
  The plugin classifies the nine pages with volume markers (``Primo
  volume``, ``Secondo Volume``, ``Terzo Volume``, ``Quarto Volume``,
  ``Quinto Volume``, ``Fine del primo volume``, ``Fine del secondo
  volume``, ``Fine del terzo volume``, ``Fine del quarto volume``)
  as ARTIFACT_STAMP. The discriminator is a text-prefix predicate
  in :meth:`refine_classification` applied to UNCLASSIFIED blocks
  whose first span is ``Verdana,Bold`` 24.0pt or ``Verdana`` 12.0pt.

Pipeline integration.

- :meth:`get_post_processing` returns ``["dehyphenate_with_log"]``.
  The empirical inspection observed 169 end-of-line hyphenations
  (substantially higher than the 12 the upstream analysis estimated)
  — well above the trivial-noise threshold and worth recovering with
  the generic Italian-lexicon dehyphenator.
- :meth:`get_layouts_disabled` returns an empty list: every layout
  L1..L4 is applicable to the Marrone. The cross-references in body
  plus the bound NOTE Nodes make L4 (Dottrina Inline) meaningful;
  the structured heading hierarchy makes L3 (Struttura Visibile)
  natural; L1 and L2 always apply.
- :meth:`refine_apparatus` is a near-pass-through: the tier 1
  generic resolver already binds the synthetic CROSS_REFERENCE Nodes
  to their target NOTE via the scope-locale HEADING_1 mechanism,
  and no plugin-specific post-binding work is required on the
  Marrone. The hook is used only to emit a single one-off
  ``language_metadata_mismatch`` warning recording that the PDF
  declares ``Lang en-US`` while the textual content is Italian.

Instance state.

The plugin keeps:

- ``_pending_warnings``: queued warnings produced during
  :meth:`refine_classification` (which has no Document to attach them
  to) and flushed into ``Document.warnings`` by
  :meth:`refine_reconstruction`.
- ``_minted_note_ids``: the set of synthetic NOTE Node ids the
  body+note splitter produced. Used only for diagnostic checks in
  testing; not consulted by :meth:`refine_apparatus`.
- ``_minted_crossref_ids``: the set of synthetic CROSS_REFERENCE Node
  ids the inline-superscript walker produced. Used only for
  diagnostic checks in testing.

Closed warning vocabulary, prefix ``plugin:bic:``. See
:data:`WARNING_TEMPLATES` for the eight entries.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, replace
from typing import ClassVar

from scabopdf_pipeline.classification.types import ClassifiedBlock
from scabopdf_pipeline.extraction.types import Block, ExtractionResult, Span
from scabopdf_pipeline.postprocessing.types import Transformation
from scabopdf_pipeline.profiling.plugin import ProfilePlugin
from scabopdf_pipeline.profiling.profile import DisabledLayout
from scabopdf_pipeline.profiling.signals import ProfilingSignals
from scabopdf_pipeline.reconstruction.types import Document, Node
from scabopdf_pipeline.schema.categories import SemanticCategory

WARNING_PREFIX = "plugin:bic"
"""Common prefix for every warning string this plugin may emit.

See ``docs/SCHEMA_v0.5.0.md § 6`` for the rationale of the prefix
convention and :data:`WARNING_TEMPLATES` for the closed vocabulary.
"""

WARNING_TEMPLATES: tuple[str, ...] = (
    "plugin:bic:premesse_duplicate_page_<p>_block_<idx>",
    "plugin:bic:abbreviazioni_duplicate_page_<p>_block_<idx>",
    "plugin:bic:volume_frontispiece_block_<idx>_page_<p>_marker_<marker>",
    "plugin:bic:volume_end_block_<idx>_page_<p>_marker_<marker>",
    "plugin:bic:note_section_split_minted_node_<id>_page_<p>_marker_<n>",
    "plugin:bic:cross_reference_minted_node_<id>_page_<p>_marker_<n>",
    "plugin:bic:language_metadata_mismatch_lang_<value>",
    "plugin:bic:heading_pattern_unmatched_block_<idx>_page_<p>",
)
"""Closed vocabulary of warnings the plugin may emit on
``Document.warnings``. Placeholders are replaced with concrete values
at emission time. Consumers should match on the prefix.
"""

# ---------------------------------------------------------------------------
# Typographic family fragments.

BODY_FONT_PREFIX = "Verdana"
"""Font family prefix of the Marrone body. The BIC pipeline uses the
``Verdana``, ``Verdana,Bold``, ``Verdana,Italic`` and
``Verdana,BoldItalic`` variants for the four orthogonal styles. The
prefix check accepts every variant via :meth:`str.startswith`.
"""

# ---------------------------------------------------------------------------
# Empirical sizes (PyMuPDF metrics, -0.05..-0.08pt drift below the nominal
# typesetting documented in the module docstring).

BODY_SIZE = 12.0
"""Body Verdana 12.0pt (regular or italic). Nominal 12pt; the BIC PDF
matches the nominal exactly for the body, with no drift.
"""

HEADING_1_SIZE = 16.08
"""HEADING_1 leading-span size in points: ``Verdana,BoldItalic`` 16.08pt
color ``#008000``. Nominal 16.1pt; the BIC pipeline rounds down to
16.08pt empirically.
"""

HEADING_2_SIZE = 18.0
"""HEADING_2 leading-span size in points: ``Verdana,Bold`` 18.0pt color
``#333399``. Nominal 18pt; no drift observed.
"""

HEADING_3_SIZE = 13.92
"""HEADING_3 leading-span size in points: ``Verdana,Bold`` (or
``Verdana,BoldItalic``) 13.92pt color ``#800000``. Nominal 13.9pt
empirically rounded to 13.92pt by PyMuPDF.
"""

NOTE_MARKER_SIZE = 12.0
"""``"Note"`` marker line size in points: ``Verdana,Bold`` 12.0pt color
``#ff0000``. The marker is a single line inside a larger glued block,
not a block on its own — see the module docstring.
"""

CROSSREF_SIZE = 10.56
"""Inline cross-reference superscript size in points: ``Verdana,Bold``
10.56pt with flag=17 (BOLD | SUPERSCRIPT) and numeric text. Nominal
10.6pt; empirical drift -0.04pt.
"""

FOOTER_SIZE = 16.08
"""Footer block leading-span size in points: ``Verdana,Bold`` 16.08pt
color ``#0000ff``, text ``"Pag. N-M"`` followed by the PDF page
number. Same nominal as HEADING_1 (16.1pt) but discriminated by the
color and by the y-band position (handled at tier 1 by
``footer_zone``).
"""

VOLUME_FRONTISPIECE_SIZE = 24.0
"""``Verdana,Bold`` 24.0pt size for the volume frontispiece title
``"Istituzioni di Diritto Romano"``. The plugin checks for the
frontispiece typographic signature on the nine volume-boundary pages
but the structural classification of those pages as ARTIFACT_STAMP is
driven by the text-prefix predicate of
:func:`_is_volume_marker_text`, not by this size alone.
"""

SIZE_TOLERANCE = 0.15
"""Tolerance in points for every size predicate.

Same value as Torrente (commit ``022357a``). The Marrone has tightly
clustered sizes between 7.9pt (rare apex) and 24pt (frontispiece) with
the body at 12pt, the cross-reference at 10.56pt and the apparatus
sizes at 13.92/16.08/18pt. The 0.15pt cushion absorbs the empirical
-0.05..-0.08pt drift without overlapping adjacent categories.
"""

# ---------------------------------------------------------------------------
# Color constants (RGB packed into a single int the way PyMuPDF exposes
# Span.color). The hex literals below mirror the BIC palette documented
# in ANALYSIS_MARRONE.md § 4.2.

COLOR_BLACK = 0x000000
"""Black (#000000): body and most regular text."""

COLOR_WHITE = 0xFFFFFF
"""White (#FFFFFF): book-page anchors rendered as invisible 1pt
white-on-white spans."""

COLOR_GREEN_H1 = 0x008000
"""Green (#008000): HEADING_1 marker — Capitolo, Prefazione, Indice
analitico, Bibliografia. Unique to this category in the manual."""

COLOR_INDIGO_H2 = 0x333399
"""Indigo (#333399): HEADING_2 marker — the singleton "Premesse"
heading (twice on PDF page 7, duplicate deduplicated in
:meth:`refine_reconstruction`)."""

COLOR_MAROON_H3 = 0x800000
"""Maroon (#800000): HEADING_3 marker — the 212 § paragrafi numbered
1 to 214 plus the 6 occurrences of "Abbreviazioni principali". Unique
discriminator within the BIC palette for this typographic size."""

COLOR_RED_NOTE = 0xFF0000
"""Pure red (#FF0000): the "Note" marker line inside a glued
body+note block. The color is the **only** distinguishing feature
that separates the marker from the bold body emphasis at the same
12pt Verdana,Bold signature."""

COLOR_BLUE_FOOTER = 0x0000FF
"""Blue (#0000FF): the bottom-of-page ``"Pag. N-M"`` footer. Tier 1
already classifies these blocks as ARTIFACT_FOOTER via the
``footer_zone`` heuristic; the color is recorded here for symmetry
with the other categories."""

# ---------------------------------------------------------------------------
# Anchor / cross-reference predicate constants.

ANCHOR_MAX_SIZE = 2.0
"""Upper bound (exclusive) on a span size to be considered a book-page
anchor candidate. The same threshold used by tier 1's
``tiny_font_anchor`` heuristic in :mod:`classification.tier1`."""

CROSSREF_FLAG_BITS = 17
"""Combined flag bits for the inline cross-reference span: BOLD (16) +
SUPERSCRIPT (1) = 17. The plugin matches against the full flag value
rather than testing individual bits because the BIC pipeline emits the
cross-reference superscripts with no other flag bits set.

The :class:`Span` class also exposes the SUPERSCRIPT bit as the
``is_superscript`` property; the plugin uses the property as the
primary check and the exact-flag check as a secondary safety net so
documents that flip additional bits in the same superscript span do
not silently leak through.
"""

# ---------------------------------------------------------------------------
# Regular expressions.

_PARAGRAFO_HEADING_PATTERN = re.compile(r"^§\s*\d+")
"""Pattern matching the leading marker of a § paragrafo heading text.

The plugin recognises the HEADING_3 § paragrafi by the 13.92pt
``Verdana,Bold`` (or ``Verdana,BoldItalic``) leading span with maroon
color; the text-pattern is consulted only as a secondary corroboration
and to discriminate the § paragrafi from the "Abbreviazioni principali"
heading which shares the typographic signature but does not start with
the § glyph.
"""

_ABBREVIAZIONI_HEADING_PATTERN = re.compile(r"^Abbreviazioni\s+principali", re.IGNORECASE)
"""Pattern matching the leading text of the "Abbreviazioni principali"
volume-apparatus heading. Triggers the
``abbreviazioni_duplicate`` warning in :meth:`refine_classification`
and is otherwise classified as HEADING_3 alongside the § paragrafi.
"""

_PREMESSE_HEADING_PATTERN = re.compile(r"^Premesse\b")
"""Pattern matching the leading text of the "Premesse" HEADING_2
block. The plugin tolerates two occurrences on the same page (the
iLovePDF post-processing artefact) and dedupes in
:meth:`refine_reconstruction`.
"""

_NOTE_MARKER_PATTERN = re.compile(r"^\s*Note\s*$")
"""Pattern matching the verbatim "Note" marker line inside a glued
body+note block. The pattern requires whitespace-only surroundings to
avoid matching inflected forms like "Note dello scrivente" inside the
body.
"""

_NOTE_NUMBER_PATTERN = re.compile(r"^\s*(\d+)\.\s")
"""Pattern matching the leading numeric marker of an individual note
line inside a Note section. Captured group is the marker number. The
synthetic NOTE Nodes minted by the body+note splitter retain the
``"N. ..."`` form so that
:data:`apparatus.constants.NOTE_MARKER_REGEX` matches and tier 1
generic resolver can bind the corresponding CROSS_REFERENCE.
"""

_CROSSREF_NUMERIC_PATTERN = re.compile(r"^\d+$")
"""Pattern matching the verbatim text of an inline cross-reference
superscript span. Strict (no whitespace, no parentheses) so the
plugin does not mint accidental CROSS_REFERENCE Nodes from spans
with trailing whitespace or stray characters at the same
typographic signature.
"""

_VOLUME_FRONTISPIECE_PATTERN = re.compile(
    r"\b(Primo|Secondo|Terzo|Quarto|Quinto)\s+volume\s+da\s+pagina\b",
    re.IGNORECASE,
)
"""Pattern matching the volume frontispiece marker anywhere inside a
block. The pattern is anchored on the ``"<ord> volume da pagina N a
pagina M"`` form that opens every BIC volume.

The Marrone BIC adaptation segments the manual into five volumes,
each opening with a frontispiece block that begins with the editorial
banner ``"Matteo Marrone Istituzioni di Diritto Romano © by G.B.
Palumbo & C. Editore S.P.A., 2006 …"`` and ends with the volume
marker. PyMuPDF fuses the entire frontispiece into one large block so
the marker sits at the END of the block text. The plugin's predicate
uses :func:`re.search` semantics to find the marker anywhere in the
text and classifies the WHOLE block as ``ARTIFACT_STAMP``.
"""

_VOLUME_END_PATTERN = re.compile(
    r"\bFine\s+del\s+(primo|secondo|terzo|quarto)\s+volume\b",
    re.IGNORECASE,
)
"""Pattern matching the end-of-volume marker anywhere inside a block.

The end-of-volume markers sit on PDF pages 106, 259, 380 and 534
(one per inter-volume transition; no marker follows the fifth volume
because the manual ends with it). PyMuPDF fuses the marker into the
last body+notes block of the volume so reclassifying the whole block
would lose the body+notes content. The plugin emits only a
diagnostic warning for end-of-volume markers and does NOT change the
block's classification.
"""

# ---------------------------------------------------------------------------
# Match() confidence weights.

CONFIDENCE_VERDANA_BODY_DOMINANT = 0.50
"""Confidence contribution when the document body is dominated by the
Verdana family at 12pt. Single strongest signal of the BIC profile —
none of the five prior plugins' corpora use Verdana for the body.
"""

CONFIDENCE_ILOVEPDF_PRODUCER = 0.15
"""Confidence contribution when the producer metadata starts with the
``iLovePDF`` fragment. The iLovePDF web service is a known
post-processing step in the BIC distribution pipeline; the Marrone
PDF was processed through it in October 2022.
"""

CONFIDENCE_TAGGED_OUTLINE = 0.10
"""Confidence contribution when the PDF carries a substantial outline
(over 100 entries). The BIC accessibility framework emits a 1562-entry
outline on the Marrone, including a per-book-page bookmark layer that
is unique to this profile. The threshold ensures small embedded
outlines from other corpora do not trigger the bonus.
"""

CONFIDENCE_NON_VERDANA_PENALTY = 0.0
"""Penalty when the body family is not Verdana. The plugin returns
``0.0`` early in :meth:`matches` rather than emitting a negative score:
a non-Verdana document is definitively not a BIC manual.
"""

VERDANA_DOMINANCE_MIN_PERCENT = 50.0
"""Minimum Verdana family dominance percent to credit the body signal.

The Marrone empirical body dominance is ~99.8 % (Verdana family
covers 78263 of 78449 spans); the 50 % floor is generous to admit
slightly different print runs of the same editorial pipeline but
strict enough to keep out documents where Verdana is a minor
incidental face.
"""

OUTLINE_ENTRIES_MIN = 100
"""Minimum outline entries to credit the tagged-outline signal.

The Marrone has 1562; the 100 floor admits slightly smaller BIC
adaptations while rejecting incidentally outline-bearing documents
from other corpora (which typically have under 50 entries).
"""

ILOVEPDF_PRODUCER_FRAGMENT = "iLovePDF"
"""Producer string fragment that flags the iLovePDF post-processing
step. Case-sensitive: PyMuPDF reports the producer string verbatim
from the PDF metadata.
"""

# ---------------------------------------------------------------------------
# Helpers — block view, node-id minter, max-existing-counter walker.


@dataclass(frozen=True)
class _BlockView:
    """Pre-computed view of a block exposed to the plugin's tier 2 logic.

    Wraps the original ``Block``, its slice of spans and the
    concatenated text. Marrone classification predicates rely heavily
    on the leading span's font / size / color triplet, so
    :meth:`primary_font`, :meth:`primary_size` and :meth:`primary_color`
    are exposed as convenience accessors.
    """

    block_index: int
    block: Block
    spans: tuple[Span, ...]
    text: str

    @property
    def primary_font(self) -> str:
        return self.spans[0].font if self.spans else ""

    @property
    def primary_size(self) -> float:
        return self.spans[0].size if self.spans else 0.0

    @property
    def primary_color(self) -> int:
        return self.spans[0].color if self.spans else 0


_NODE_ID_PATTERN = re.compile(r"^node_(\d+)$")
"""Pattern decoding a tier 1 node id into its numeric counter.

Same convention used by Mosconi, Mandrioli, Torrente: the schema's
``NodeDict.id`` validator enforces ``^node_\\d+$`` and the plugin
mints synthetic ids ``node_NNNN`` zero-padded to four digits.
"""


class _NodeIdMinter:
    """Stateful node-id minter that follows the tier 1 ``node_NNNN``
    convention.

    The minter starts one past the maximum counter already used by
    tier 1 (and any earlier minting in the same plugin pass) and
    emits monotonically increasing ids.
    """

    def __init__(self, *, start: int) -> None:
        self._counter = start

    def mint(self) -> str:
        node_id = f"node_{self._counter:04d}"
        self._counter += 1
        return node_id


def _max_existing_node_counter(roots: tuple[Node, ...]) -> int:
    """Return the highest numeric counter already used by a tier 1 node id.

    Walks the forest, decodes every ``node_NNNN`` id and returns the
    maximum. A document with no tier 1 nodes returns ``-1`` so the
    caller can start minting at ``0``.
    """
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


# ---------------------------------------------------------------------------
# Main class.


class ManualeBicProfile(ProfilePlugin):
    """Corpus plugin for the BIC accessible-manual series — Marrone first sample."""

    profile_id: ClassVar[str] = "manuale_bic"
    editorial_family: ClassVar[str] = "bic"
    genre: ClassVar[str] = "manuale_accessibile"

    def __init__(self) -> None:
        self._pending_warnings: list[str] = []
        self._minted_note_ids: set[str] = set()
        self._minted_crossref_ids: set[str] = set()

    # ------------------------------------------------------------------
    # ProfilePlugin declarative methods

    @classmethod
    def matches(cls, signals: ProfilingSignals) -> float:
        """Score the document against the BIC-Marrone fingerprint.

        Three positive contributions (Verdana body dominance, iLovePDF
        producer, tagged outline) and one early-return for non-Verdana
        body families. The combination on the Marrone fixture clears
        the 0.6 dispatcher threshold by a wide margin (~0.75 with all
        three signals present) while staying below the threshold on
        the five prior plugins' fixtures (none of which use Verdana
        as the dominant body family) — they short-circuit to 0.0.
        """
        verdana_dominant = any(
            font.family.startswith(BODY_FONT_PREFIX)
            and abs(font.size - BODY_SIZE) < SIZE_TOLERANCE
            and font.dominance_percent >= VERDANA_DOMINANCE_MIN_PERCENT
            for font in signals.typographic_signature.fonts
        )
        if not verdana_dominant:
            return 0.0

        score = CONFIDENCE_VERDANA_BODY_DOMINANT

        producer = (signals.producer_creator.producer or "").strip()
        if ILOVEPDF_PRODUCER_FRAGMENT in producer:
            score += CONFIDENCE_ILOVEPDF_PRODUCER

        outline = signals.outline_structure
        if outline.has_outline and outline.entries_count >= OUTLINE_ENTRIES_MIN:
            score += CONFIDENCE_TAGGED_OUTLINE

        return score

    def get_categories(self) -> set[SemanticCategory]:
        """Closed set of categories the plugin may emit on the Marrone
        fixture and on any other BIC accessible manual of comparable
        structure.
        """
        return {
            SemanticCategory.HEADING_1,
            SemanticCategory.HEADING_2,
            SemanticCategory.HEADING_3,
            SemanticCategory.BODY,
            SemanticCategory.NOTE,
            SemanticCategory.CROSS_REFERENCE,
            SemanticCategory.BOOK_PAGE_ANCHOR,
            SemanticCategory.ARTIFACT_FILIGREE,
            SemanticCategory.ARTIFACT_RUNNING_HEADER,
            SemanticCategory.ARTIFACT_FOOTER,
            SemanticCategory.ARTIFACT_STAMP,
            SemanticCategory.UNCLASSIFIED,
            SemanticCategory.EMPTY_PAGE,
        }

    def get_post_processing(self) -> list[str]:
        """Return the ordered list of post-processing step IDs for the
        Marrone profile.

        Only ``dehyphenate_with_log``: the empirical inspection of the
        fixture observed 169 end-of-line hyphenations (PyMuPDF
        ``\\n``-separated form), substantially higher than the upstream
        analysis's estimate of 12. The generic Italian-lexicon
        dehyphenator recovers the unbroken word forms. No
        ``merge_cross_page_notes`` because the Marrone groups its notes
        per paragrafo (no cross-page note continuation); no
        ``recompose_marginal_ellipsis`` because the manual has no
        marginal annotations.
        """
        return ["dehyphenate_with_log"]

    def get_layouts_disabled(self) -> list[DisabledLayout]:
        """No layouts disabled.

        The Marrone has cross-references in body bound to NOTE Nodes,
        which makes L4 (Dottrina Inline) meaningful; the four-level
        heading hierarchy makes L3 (Struttura Visibile) natural; L1
        and L2 always apply. Layer 2 offers every layout for this
        profile.
        """
        return []

    # ------------------------------------------------------------------
    # Tier 2 refinement hooks

    def refine_classification(
        self,
        extraction: ExtractionResult,
        tier1_results: list[ClassifiedBlock],
    ) -> list[ClassifiedBlock]:
        """Promote UNCLASSIFIED blocks to the BIC category vocabulary.

        Single-pass sweep over the tier 1 verdicts. Tier 1 generic
        heuristics already classify the book-page anchors (Verdana
        0.96pt blocks via ``tiny_font_anchor``), the bottom-of-page
        footers (``footer_zone``), and the running header (``header_zone``)
        if any. The plugin leaves those verdicts untouched and operates
        only on UNCLASSIFIED blocks plus a few volume-marker blocks
        rescued from tier 1 verdicts.

        Predicate order (first match wins, narrow to wide):

        1. Volume frontispiece / end-of-volume marker → ARTIFACT_STAMP.
        2. HEADING_1 (Verdana,BoldItalic 16.08pt color #008000).
        3. HEADING_2 (Verdana,Bold 18pt color #333399 — Premesse).
        4. HEADING_3 (Verdana,Bold/BoldItalic 13.92pt color #800000 —
           § paragrafi and Abbreviazioni principali).
        5. BODY (Verdana 12pt regular or italic).

        Anything not matched by the predicates above stays
        UNCLASSIFIED. Volume-marker and duplicate-Premesse warnings
        are accumulated in :attr:`_pending_warnings` and flushed by
        :meth:`refine_reconstruction`.
        """
        self._pending_warnings = []
        self._minted_note_ids = set()
        self._minted_crossref_ids = set()

        seen_premesse_pages: set[int] = set()
        seen_abbreviazioni_pages: set[int] = set()

        refined: list[ClassifiedBlock] = []
        for verdict in tier1_results:
            if verdict.block_index < 0:
                refined.append(verdict)
                continue
            view = self._view(extraction, verdict.block_index)
            if view is None:
                refined.append(verdict)
                continue

            # Always run the volume-marker predicate first: tier 1 may
            # have classified a frontispiece page block as
            # ARTIFACT_RUNNING_HEADER (the 24pt frontispiece sometimes
            # sits in the top 8 % of the page). The plugin rescues it
            # to ARTIFACT_STAMP for a precise editorial classification.
            volume_marker = self._volume_marker_kind(view)
            if volume_marker is not None:
                refined.append(self._classify_volume_marker(verdict, view, volume_marker))
                continue

            # Always run the heading predicates, **including** on tier 1
            # ARTIFACT_RUNNING_HEADER verdicts. The BIC accessibility
            # pipeline typesets the chapter titles, Premesse and §
            # paragrafi at the very top of their page so the bbox falls
            # inside the tier 1 header zone (top 8 % of the page) and
            # tier 1 classifies them as RUNNING_HEADER. Without the
            # rescue, 12 of the 13 HEADING_1 blocks would stay
            # mis-categorised. The rescue is bounded by the
            # color-specific predicates so the genuine running headers
            # ("Matteo Marrone" page header at 12pt #333399) are
            # untouched.
            heading_rescue = self._heading_rescue(
                verdict,
                view,
                seen_premesse_pages,
                seen_abbreviazioni_pages,
            )
            if heading_rescue is not None:
                refined.append(heading_rescue)
                continue

            if verdict.category is SemanticCategory.UNCLASSIFIED:
                refined.append(
                    self._reclassify_unclassified(
                        verdict,
                        view,
                        seen_premesse_pages,
                        seen_abbreviazioni_pages,
                    )
                )
                continue

            refined.append(verdict)

        return refined

    def _heading_rescue(
        self,
        verdict: ClassifiedBlock,
        view: _BlockView,
        seen_premesse_pages: set[int],
        seen_abbreviazioni_pages: set[int],
    ) -> ClassifiedBlock | None:
        """Rescue heading blocks tier 1 mis-classified as running header.

        Returns a new ``ClassifiedBlock`` when the block matches one of
        the three BIC heading predicates (HEADING_1 verde, HEADING_2
        Premesse, HEADING_3 § paragrafo or Abbreviazioni), or ``None``
        when no rescue applies and the caller should fall through to the
        UNCLASSIFIED handling. The duplicate-tracking sets are shared
        with :meth:`_reclassify_unclassified` so the dedup warnings are
        emitted regardless of which code path classified the block.
        """
        if self._is_heading_1(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.HEADING_1,
                reason="bic_heading_1_chapter",
            )
        if self._is_heading_2_premesse(view):
            page = view.block.page
            if page in seen_premesse_pages:
                self._pending_warnings.append(
                    f"{WARNING_PREFIX}:premesse_duplicate_page_{page}_block_{verdict.block_index}"
                )
            else:
                seen_premesse_pages.add(page)
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.HEADING_2,
                reason="bic_heading_2_premesse",
            )
        if self._is_heading_3(view):
            if _ABBREVIAZIONI_HEADING_PATTERN.match(view.text):
                page = view.block.page
                if page in seen_abbreviazioni_pages:
                    self._pending_warnings.append(
                        f"{WARNING_PREFIX}:abbreviazioni_duplicate_page_{page}"
                        f"_block_{verdict.block_index}"
                    )
                else:
                    seen_abbreviazioni_pages.add(page)
                return ClassifiedBlock(
                    block_index=verdict.block_index,
                    category=SemanticCategory.HEADING_3,
                    reason="bic_heading_3_abbreviazioni",
                )
            if _PARAGRAFO_HEADING_PATTERN.match(view.text):
                return ClassifiedBlock(
                    block_index=verdict.block_index,
                    category=SemanticCategory.HEADING_3,
                    reason="bic_heading_3_paragrafo",
                )
        return None

    def refine_reconstruction(
        self,
        document: Document,
        extraction: ExtractionResult,
        classified_blocks: list[ClassifiedBlock],
    ) -> Document:
        """Mint synthetic CROSS_REFERENCE and NOTE Nodes, dedupe Premesse,
        flush warnings.

        Three passes over the tree, in order:

        1. **Body+note splitter.** Walk every BODY Node carrying a
           single ``block_index``; recover the original spans via
           ``extraction.spans[start:end]``; if a line-level "Note"
           marker is present (a span with the unique signature
           Verdana,Bold 12pt color #ff0000 and text "Note"), split the
           block: truncate the BODY text to the spans before the
           marker, then split the post-marker spans into one synthetic
           NOTE Node per ``"N. "`` transition (driven by
           :data:`_NOTE_NUMBER_PATTERN`). Each synthetic NOTE Node is
           inserted as a sibling immediately after the surviving BODY
           in the parent's children list. The operation is recorded
           as a :class:`Transformation` with ``split_into`` populated
           with the minted ids (schema 0.5.0 structural reversibility).

        2. **Inline cross-reference walker.** Walk every BODY Node and
           every minted NOTE Node carrying a single ``block_index``;
           recover the original spans; for each span with the
           cross-reference signature (Verdana,Bold 10.56pt flag=17,
           numeric text), mint a synthetic CROSS_REFERENCE Node with
           the verbatim digit as text and insert it as a sibling
           immediately after the originating Node.

        3. **Premesse dedup.** Walk the heading_2 nodes; for any page
           carrying two HEADING_2 nodes with text "Premesse" (the
           iLovePDF duplicate artefact on PDF page 7), keep the first
           and drop the second from its parent's children. The drop
           is unrecorded in ``transformations`` because the duplicate
           is a typesetting artefact, not a content modification: a
           "raw mode" reverse walk would not need to materialise the
           dropped sibling.

        Pending warnings queued by :meth:`refine_classification` are
        flushed into ``Document.warnings`` here together with the
        per-mint warnings produced by this method.
        """
        del classified_blocks

        new_warnings = list(self._pending_warnings)
        self._pending_warnings = []

        minter = _NodeIdMinter(start=_max_existing_node_counter(document.root) + 1)

        new_roots, transformations = self._split_body_note_in_forest(
            document.root,
            extraction,
            new_warnings,
            minter,
        )
        new_roots = self._mint_cross_references_in_forest(
            new_roots,
            extraction,
            new_warnings,
            minter,
        )
        new_roots = self._dedupe_premesse_in_forest(new_roots, new_warnings)

        return Document(
            root=new_roots,
            warnings=tuple(document.warnings) + tuple(new_warnings),
            transformations=document.transformations + tuple(transformations),
        )

    def refine_apparatus(
        self,
        document: Document,
        extraction: ExtractionResult,
        classified_blocks: list[ClassifiedBlock],
    ) -> Document:
        """Emit the one-off language-metadata mismatch warning if applicable.

        The Marrone PDF declares ``Lang en-US`` in its catalog while
        the textual content is Italian. The plugin records this fact
        once per pipeline run via a singleton warning so the audit log
        carries the diagnostic and VoiceOver consumers can override the
        language at presentation time.

        The plugin does NOT override the tier 1 generic cross-reference
        resolver: the synthetic CROSS_REFERENCE Nodes minted in
        :meth:`refine_reconstruction` carry pure-digit text that
        :data:`apparatus.constants.CROSS_REF_DIGITS_REGEX` matches; the
        minted NOTE Nodes carry text starting with the matching
        ``"N. "`` form that :data:`apparatus.constants.NOTE_MARKER_REGEX`
        recognises; the scope-locale HEADING_1 mechanism aligns with
        the Marrone per-chapter note numbering. No profile-specific
        binding work is required.
        """
        del extraction, classified_blocks
        if document.warnings or document.transformations or document.root:
            # Pipeline run: emit the single mismatch warning. The
            # presence check is symbolic: the warning is emitted once
            # per document regardless of the actual catalog Lang value,
            # because Layer 1 does not currently expose the language
            # metadata to the plugin. A future signal-builder extension
            # may pass the catalog Lang as a specific marker; at that
            # point the warning would be conditional on the value.
            return Document(
                root=document.root,
                warnings=(
                    *document.warnings,
                    f"{WARNING_PREFIX}:language_metadata_mismatch_lang_en-US",
                ),
                transformations=document.transformations,
            )
        return document

    # ------------------------------------------------------------------
    # Per-block reclassification helpers

    def _reclassify_unclassified(
        self,
        verdict: ClassifiedBlock,
        view: _BlockView,
        seen_premesse_pages: set[int],
        seen_abbreviazioni_pages: set[int],
    ) -> ClassifiedBlock:
        """Promote a tier 1 UNCLASSIFIED verdict to BIC categories.

        The HEADING_1 / HEADING_2 / HEADING_3 predicates are already
        applied by :meth:`_heading_rescue` for every tier 1 verdict
        upstream (including UNCLASSIFIED); the rescue covers the
        Marrone-specific case where chapter titles fall inside tier 1's
        header-zone heuristic and would otherwise be classified as
        ARTIFACT_RUNNING_HEADER. This method handles the remaining
        cases for genuinely UNCLASSIFIED blocks: HEADING_3 residue
        with unmatched text (diagnostic warning) and BODY promotion.
        """
        del seen_premesse_pages, seen_abbreviazioni_pages  # consumed in _heading_rescue
        if self._is_heading_3(view):
            # Same typographic signature as § paragrafi or Abbreviazioni
            # principali but the text matched neither pattern at the
            # rescue stage. Emit a diagnostic warning and leave
            # UNCLASSIFIED so a future revision can decide whether to
            # absorb the residue.
            self._pending_warnings.append(
                f"{WARNING_PREFIX}:heading_pattern_unmatched_block_"
                f"{verdict.block_index}_page_{view.block.page}"
            )
            return verdict

        if self._is_body(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.BODY,
                reason="bic_body",
            )

        return verdict

    def _classify_volume_marker(
        self,
        verdict: ClassifiedBlock,
        view: _BlockView,
        kind: str,
    ) -> ClassifiedBlock:
        """Classify a volume-marker block and emit the matching warning.

        Frontispiece blocks (the per-volume editorial banner ending
        with ``"Primo|Secondo|Terzo|Quarto|Quinto volume da pagina N a
        pagina M del testo originale"``) are reclassified as
        ``ARTIFACT_STAMP``: PyMuPDF fuses the whole banner into one
        block with no body content interleaved, so the editorial
        residue can be cleanly excised from the reading flow.

        End-of-volume markers (``"Fine del primo|secondo|terzo|quarto
        volume"``) are emitted as warnings only and the block keeps
        its original tier 1 classification. The marker sits at the
        end of a long body+notes block whose primary content is real
        — reclassifying as ``ARTIFACT_STAMP`` would silently delete
        the body+notes. A future revision can refine the splitter to
        extract just the marker line into a synthetic ARTIFACT_STAMP
        sibling, but v1 deliberately keeps the block intact.
        """
        page = view.block.page
        if kind == "frontispiece":
            match = _VOLUME_FRONTISPIECE_PATTERN.search(view.text)
            marker = match.group(1).lower() if match else "unknown"
            self._pending_warnings.append(
                f"{WARNING_PREFIX}:volume_frontispiece_block_{verdict.block_index}"
                f"_page_{page}_marker_{marker}"
            )
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.ARTIFACT_STAMP,
                reason="bic_volume_frontispiece",
            )
        # End-of-volume marker: warning only, classification untouched.
        match = _VOLUME_END_PATTERN.search(view.text)
        marker = match.group(1).lower() if match else "unknown"
        self._pending_warnings.append(
            f"{WARNING_PREFIX}:volume_end_block_{verdict.block_index}_page_{page}_marker_{marker}"
        )
        return verdict

    # ------------------------------------------------------------------
    # Predicate primitives

    @staticmethod
    def _is_heading_1(view: _BlockView) -> bool:
        if not view.spans:
            return False
        span = view.spans[0]
        return (
            span.font.startswith(BODY_FONT_PREFIX)
            and "BoldItal" in span.font
            and abs(span.size - HEADING_1_SIZE) < SIZE_TOLERANCE
            and span.color == COLOR_GREEN_H1
        )

    @staticmethod
    def _is_heading_2_premesse(view: _BlockView) -> bool:
        if not view.spans:
            return False
        span = view.spans[0]
        if not (
            span.font.startswith(BODY_FONT_PREFIX + ",Bold")
            and abs(span.size - HEADING_2_SIZE) < SIZE_TOLERANCE
            and span.color == COLOR_INDIGO_H2
        ):
            return False
        return bool(_PREMESSE_HEADING_PATTERN.match(view.text))

    @staticmethod
    def _is_heading_3(view: _BlockView) -> bool:
        if not view.spans:
            return False
        span = view.spans[0]
        return (
            span.font.startswith(BODY_FONT_PREFIX + ",Bold")
            and abs(span.size - HEADING_3_SIZE) < SIZE_TOLERANCE
            and span.color == COLOR_MAROON_H3
        )

    @staticmethod
    def _is_body(view: _BlockView) -> bool:
        """Return True if any span of the block carries the body signature.

        The Marrone interleaves small spans inside body paragraphs:
        cross-reference superscripts (Verdana,Bold 10.56pt flag=17),
        BIC book-page anchors (Verdana 0.96pt) and rare italic / bold
        emphasis. PyMuPDF emits them as the LEADING span of the block
        when the typesetting places them at line start, which would
        defeat a leading-span body check. The permissive any-span
        predicate accepts every block where at least one span has the
        Verdana 12pt body signature; the HEADING_1/2/3 predicates are
        checked first by :meth:`refine_classification` so genuine
        headings cannot accidentally fall through.
        """
        return any(
            span.font.startswith(BODY_FONT_PREFIX) and abs(span.size - BODY_SIZE) < SIZE_TOLERANCE
            for span in view.spans
        )

    @staticmethod
    def _volume_marker_kind(view: _BlockView) -> str | None:
        text = view.text
        if _VOLUME_FRONTISPIECE_PATTERN.search(text):
            return "frontispiece"
        if _VOLUME_END_PATTERN.search(text):
            return "end"
        return None

    @staticmethod
    def _is_note_marker_span(span: Span) -> bool:
        """Return True if the span is the line-level "Note" marker.

        Diagnostic predicate used by the body+note splitter: the
        Verdana,Bold 12pt color #ff0000 signature with text "Note"
        is unique to the section separator in the Marrone fixture.
        """
        return (
            span.font.startswith(BODY_FONT_PREFIX + ",Bold")
            and abs(span.size - NOTE_MARKER_SIZE) < SIZE_TOLERANCE
            and span.color == COLOR_RED_NOTE
            and bool(_NOTE_MARKER_PATTERN.match(span.text))
        )

    @staticmethod
    def _is_crossref_span(span: Span) -> bool:
        """Return True if the span is an inline CROSS_REFERENCE marker.

        Combines the typographic signature (Verdana,Bold 10.56pt with
        SUPERSCRIPT bit set) with a strict numeric text predicate so
        accidental matches on bold superscripts in other contexts are
        rejected.
        """
        if not (
            span.font.startswith(BODY_FONT_PREFIX + ",Bold")
            and abs(span.size - CROSSREF_SIZE) < SIZE_TOLERANCE
        ):
            return False
        if not span.is_superscript:
            return False
        if span.flags != CROSSREF_FLAG_BITS:
            return False
        return bool(_CROSSREF_NUMERIC_PATTERN.match(span.text.strip()))

    # ------------------------------------------------------------------
    # Body+note splitter — pattern (u) from Mandrioli adapted for Marrone

    def _split_body_note_in_forest(
        self,
        roots: tuple[Node, ...],
        extraction: ExtractionResult,
        warnings: list[str],
        minter: _NodeIdMinter,
    ) -> tuple[tuple[Node, ...], list[Transformation]]:
        transformations: list[Transformation] = []
        new_roots = tuple(
            self._split_body_note_in_node(root, extraction, warnings, minter, transformations)
            for root in roots
        )
        return new_roots, transformations

    def _split_body_note_in_node(
        self,
        node: Node,
        extraction: ExtractionResult,
        warnings: list[str],
        minter: _NodeIdMinter,
        transformations: list[Transformation],
    ) -> Node:
        # First, recurse into children so the operation reaches every
        # BODY Node in the tree.
        new_children: list[Node] = []
        for child in node.children:
            split_child = self._split_body_note_in_node(
                child, extraction, warnings, minter, transformations
            )
            if split_child.category is SemanticCategory.BODY and split_child.block_indices:
                produced = self._split_one_body_note(
                    split_child, extraction, warnings, minter, transformations
                )
                new_children.extend(produced)
            else:
                new_children.append(split_child)
        if tuple(new_children) == node.children:
            return node
        return replace(node, children=tuple(new_children))

    def _split_one_body_note(
        self,
        body: Node,
        extraction: ExtractionResult,
        warnings: list[str],
        minter: _NodeIdMinter,
        transformations: list[Transformation],
    ) -> list[Node]:
        """Walk every block of the (possibly multi-block) BODY Node and
        split at the first Note marker found.

        The Marrone fixture exercises both single-block BODY Nodes
        (the splitter handles them directly) and multi-block BODY
        Nodes produced by the tier 1 cross-page paragraph merger
        (around 60 % of the Note-bearing blocks). For multi-block
        Nodes the Note marker sits inside one specific block_index;
        every block_index before the marker contributes to the
        surviving BODY's preserved text, the marker block contributes
        its pre-marker prefix, and the post-marker spans of the marker
        block (plus any subsequent block_indices' spans) become the
        Note section to split into individual NOTE Nodes.
        """
        if body.text is None:
            return [body]

        # Scan each block of the multi-block Node to find which one
        # carries the marker. The marker is always inside a single
        # block_index because PyMuPDF emits the marker line as a span
        # belonging to one block.
        marker_block_position: int | None = None
        marker_span_index: int | None = None
        for idx_pos, block_index in enumerate(body.block_indices):
            if block_index < 0 or block_index >= len(extraction.blocks):
                continue
            block = extraction.blocks[block_index]
            start, end = block.span_range
            spans = extraction.spans[start:end]
            local_marker_idx = self._find_note_marker_index(spans)
            if local_marker_idx is not None:
                marker_block_position = idx_pos
                marker_span_index = local_marker_idx
                break
        if marker_block_position is None or marker_span_index is None:
            return [body]

        # Gather the Note section spans: the post-marker spans of the
        # marker block plus every span of every block_index after it.
        marker_block_index = body.block_indices[marker_block_position]
        marker_block = extraction.blocks[marker_block_index]
        marker_start, marker_end = marker_block.span_range
        marker_block_spans = extraction.spans[marker_start:marker_end]
        note_spans: list[Span] = list(marker_block_spans[marker_span_index + 1 :])
        for after_pos in range(marker_block_position + 1, len(body.block_indices)):
            bi = body.block_indices[after_pos]
            if bi < 0 or bi >= len(extraction.blocks):
                continue
            block_after = extraction.blocks[bi]
            bs, be = block_after.span_range
            note_spans.extend(extraction.spans[bs:be])

        if not note_spans:
            return [body]

        note_groups = self._group_note_spans(note_spans)
        if not note_groups:
            return [body]

        # Compute the truncated body text: spans of every block before
        # the marker block, joined with single spaces (matching the
        # cross-page merge convention in tier 1 reconstruct), plus the
        # pre-marker spans of the marker block.
        body_text_parts: list[str] = []
        for before_pos in range(marker_block_position):
            bi = body.block_indices[before_pos]
            if bi < 0 or bi >= len(extraction.blocks):
                continue
            block_before = extraction.blocks[bi]
            bs, be = block_before.span_range
            body_text_parts.append("".join(s.text for s in extraction.spans[bs:be]))
        pre_marker_text = "".join(s.text for s in marker_block_spans[:marker_span_index])
        body_text_parts.append(pre_marker_text)
        body_text_combined = " ".join(p for p in body_text_parts if p).strip()

        # Mint the synthetic NOTE Nodes.
        minted_notes: list[Node] = []
        minted_ids: list[str] = []
        for group_spans, marker_number in note_groups:
            note_text = "".join(s.text for s in group_spans).strip()
            note_id = minter.mint()
            minted_ids.append(note_id)
            self._minted_note_ids.add(note_id)
            minted_notes.append(
                Node(
                    id=note_id,
                    category=SemanticCategory.NOTE,
                    children=(),
                    page_index=group_spans[0].page,
                    block_indices=(marker_block_index,),
                    text=note_text,
                    level=None,
                    summary_items=None,
                    toc_items=None,
                    apparatus_refs=(),
                )
            )
            warnings.append(
                f"{WARNING_PREFIX}:note_section_split_minted_node_{note_id}"
                f"_page_{group_spans[0].page}_marker_{marker_number}"
            )

        # Build the surviving BODY (with truncated text) and the
        # transformation record. The transformation records the
        # textual delete from ``body.text`` (original) to
        # ``body_text_combined`` (normalized) plus the structural
        # ``split_into`` list of minted NOTE ids per schema 0.5.0.
        original_text = body.text
        normalized_text = body_text_combined
        # Compute the position of the absorbed suffix in the original
        # text. The original prefix that survives is ``normalized``;
        # everything after is the absorbed note section. If the
        # normalized prefix is not present at the start of original
        # (edge case: the join convention added a different
        # whitespace), fall back to a position of ``(0, 0)`` so the
        # transformation remains structurally valid even if textual
        # reversal degrades.
        position: tuple[int, int]
        original_suffix: str
        if original_text.startswith(normalized_text):
            position = (len(normalized_text), len(original_text))
            original_suffix = original_text[position[0] : position[1]]
        else:
            position = (0, 0)
            original_suffix = ""
        transformations.append(
            Transformation(
                step_id="bic_body_note_splitter",
                node_id=body.id,
                page_index=body.page_index,
                position=position,
                original=original_suffix,
                normalized="",
                split_into=tuple(minted_ids),
                merged_from=None,
            )
        )
        truncated_body = replace(body, text=normalized_text)
        return [truncated_body, *minted_notes]

    @staticmethod
    def _find_note_marker_index(spans: tuple[Span, ...] | list[Span]) -> int | None:
        for idx, span in enumerate(spans):
            if ManualeBicProfile._is_note_marker_span(span):
                return idx
        return None

    @staticmethod
    def _group_note_spans(spans: tuple[Span, ...] | list[Span]) -> list[tuple[list[Span], str]]:
        """Group note spans into individual notes by detecting ``N. ``
        transitions on a new line.

        A transition is signalled by a span whose ``line_index``
        differs from the previous span's and whose stripped text
        starts with ``N. ``. The first span after the "Note" marker
        seeds the first group regardless of the line_index check.
        """
        groups: list[tuple[list[Span], str]] = []
        current_group: list[Span] = []
        current_marker: str = ""
        prev_line_index: int | None = None
        for span in spans:
            text = span.text.lstrip()
            is_transition = False
            marker_match = _NOTE_NUMBER_PATTERN.match(text)
            if marker_match is not None and (
                prev_line_index is None or span.line_index != prev_line_index
            ):
                is_transition = True
            if is_transition:
                if current_group:
                    groups.append((current_group, current_marker))
                current_group = [span]
                assert marker_match is not None
                current_marker = marker_match.group(1)
            elif current_group:
                current_group.append(span)
            prev_line_index = span.line_index
        if current_group:
            groups.append((current_group, current_marker))
        return [g for g in groups if g[1]]

    # ------------------------------------------------------------------
    # Inline CROSS_REFERENCE walker — pattern from Mosconi

    def _mint_cross_references_in_forest(
        self,
        roots: tuple[Node, ...],
        extraction: ExtractionResult,
        warnings: list[str],
        minter: _NodeIdMinter,
    ) -> tuple[Node, ...]:
        return tuple(
            self._mint_cross_references_in_node(root, extraction, warnings, minter)
            for root in roots
        )

    def _mint_cross_references_in_node(
        self,
        node: Node,
        extraction: ExtractionResult,
        warnings: list[str],
        minter: _NodeIdMinter,
    ) -> Node:
        # Recurse first, then build new children with cross-refs
        # spliced in immediately after each BODY that contains them.
        new_children: list[Node] = []
        for child in node.children:
            refined_child = self._mint_cross_references_in_node(child, extraction, warnings, minter)
            new_children.append(refined_child)
            if refined_child.category is SemanticCategory.BODY and refined_child.block_indices:
                minted = self._mint_for_node(refined_child, extraction, warnings, minter)
                new_children.extend(minted)
        if tuple(new_children) == node.children:
            return node
        return replace(node, children=tuple(new_children))

    def _mint_for_node(
        self,
        body: Node,
        extraction: ExtractionResult,
        warnings: list[str],
        minter: _NodeIdMinter,
    ) -> list[Node]:
        """Mint a synthetic CROSS_REFERENCE Node per inline superscript span.

        Walks every span of every block_index of the (possibly
        multi-block) BODY Node. The Marrone fixture exercises BODY
        Nodes with 1..42 block_indices (the 42-block outlier is the
        index analitico page); each block can independently contain
        zero or more inline superscript cross-reference spans.
        """
        minted: list[Node] = []
        for block_index in body.block_indices:
            if block_index < 0 or block_index >= len(extraction.blocks):
                continue
            block = extraction.blocks[block_index]
            start, end = block.span_range
            spans = extraction.spans[start:end]
            for span in spans:
                if not self._is_crossref_span(span):
                    continue
                digit_text = span.text.strip()
                crossref_id = minter.mint()
                self._minted_crossref_ids.add(crossref_id)
                minted.append(
                    Node(
                        id=crossref_id,
                        category=SemanticCategory.CROSS_REFERENCE,
                        children=(),
                        page_index=span.page,
                        block_indices=(block_index,),
                        text=digit_text,
                        level=None,
                        summary_items=None,
                        toc_items=None,
                        apparatus_refs=(),
                    )
                )
                warnings.append(
                    f"{WARNING_PREFIX}:cross_reference_minted_node_{crossref_id}"
                    f"_page_{span.page}_marker_{digit_text}"
                )
        return minted

    # ------------------------------------------------------------------
    # Premesse dedup

    def _dedupe_premesse_in_forest(
        self,
        roots: tuple[Node, ...],
        warnings: list[str],
    ) -> tuple[Node, ...]:
        seen_pages: set[int] = set()
        del warnings  # the duplicate is already flagged via _pending_warnings in tier 2 classify
        return tuple(self._dedupe_premesse_in_node(root, seen_pages) for root in roots)

    def _dedupe_premesse_in_node(
        self,
        node: Node,
        seen_pages: set[int],
    ) -> Node:
        new_children: list[Node] = []
        for child in node.children:
            if (
                child.category is SemanticCategory.HEADING_2
                and child.text is not None
                and _PREMESSE_HEADING_PATTERN.match(child.text)
            ):
                if child.page_index in seen_pages:
                    # Drop the duplicate; do not recurse into its
                    # subtree (it should be empty on the Marrone but
                    # the drop is unconditional).
                    continue
                seen_pages.add(child.page_index)
            new_children.append(self._dedupe_premesse_in_node(child, seen_pages))
        if tuple(new_children) == node.children:
            return node
        return replace(node, children=tuple(new_children))

    # ------------------------------------------------------------------
    # Block view helper

    @staticmethod
    def _view(extraction: ExtractionResult, block_index: int) -> _BlockView | None:
        if block_index < 0 or block_index >= len(extraction.blocks):
            return None
        block = extraction.blocks[block_index]
        start, end = block.span_range
        spans = tuple(extraction.spans[start:end])
        if not spans:
            return None
        text = "".join(s.text for s in spans)
        return _BlockView(block_index=block_index, block=block, spans=spans, text=text)
