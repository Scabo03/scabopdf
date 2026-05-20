"""Corpus plugin for the Giappichelli manual series — Mandrioli-Carratta.

Fourth real corpus plugin of the project, consolidated on the
integral Mandrioli-Carratta series. Handles all four volumes of the
Mandrioli-Carratta "Corso di diritto processuale civile" / "Diritto
processuale civile" (Giappichelli, 30th edition for Vol. IV, 20th
edition for Vol. I/II, Vol. III at the 30th edition for processi
speciali). See ``docs/analysis/ANALYSIS_MANDRIOLI_CARRATTA.md`` for
the editorial analysis on Vol. III; the consolidation pass on the
remaining three volumes is empirically driven (no separate analysis
document).

The plugin exercises:

- the Giappichelli editorial pipeline in two production regimes:
  (a) Adobe InDesign 20.0 / 20.2 + Photoshop Image Conversion
  Plug-in producer (Vol. III, Vol. IV); (b) Adobe Photoshop 26.3 +
  Photoshop Image Conversion Plug-in producer (Vol. I, Vol. II).
  The plugin treats the two regimes as one editorial family thanks
  to the dual creator-fragment match
  (:data:`GIAPPICHELLI_CREATOR_FRAGMENTS`);
- the ``SimonciniGaramondStd`` monocomponent typographic system,
  whose hierarchy is expressed via size + italic + maiuscoletto with
  **no structural bold**. The Sezione header span is italic at
  12.0pt, the paragrafo title span is italic at 11.52pt;
- the ``MARGINAL_GLOSS`` category, filled in production: short
  ``AGaramondPro-BoldItalic`` 8.52pt glosses in the left margin
  annotating the adjacent NOTE. Present on Vol. III (12 glosses) and
  Vol. IV (14 glosses); absent on Vol. I/II (no AGaramondPro spans).
  Tier 1 ``_resolve_marginal_glosses`` binds each gloss to the
  vertically closest NOTE on the same page via
  ``ApparatusRef.kind = GLOSS_TARGET``;
- a four-level heading hierarchy ``PARTE / CAPITOLO / Sezione /
  paragrafo``: the first plugin in the project that emits
  ``HEADING_4`` in production. PARTE divisions appear on Vol. III
  (4 in body) and Vol. IV (2 in body); Vol. I and Vol. II have no
  PARTE divisions (variazione editoriale legittima);
- dense apparatus on Vol. III (~744 notes) and Vol. IV (~744 notes);
  lighter apparatus on Vol. I/II. Cross-page note continuation is
  recovered by the promoted ``merge_cross_page_notes`` post-processing
  step declared in :meth:`get_post_processing` (real as of schema
  0.5.0); the tier 1 generic resolver
  ``_resolve_cross_page_note_merging`` skips its own pass on this
  plugin's documents to avoid double-merging. The combination of
  marker-less NOTE classification (see :meth:`_is_note`), continuation
  recovery inside glued blocks (see :meth:`_find_note_transitions`)
  and the post-processing merge yields ≥ 700 NOTE Nodes on both
  Vol. III and Vol. IV;
- ``CROSS_REFERENCE`` markers ``(N)`` minted from **textual regex**
  rather than typographic superscript flag. The Mandrioli inline
  marker is a parenthesised digit sitting in a normal body span at
  10.98pt, so the plugin scans every BODY node's ``text`` with a
  regex and mints siblings at each match;
- the **small-caps three-span pattern** as a category discriminator
  for SOMMARIO (``CHAPTER_SUMMARY`` label) and the **five-span
  small-caps composite** for ``PARTE`` divisions. The predicates
  read the relevant span indices and verify the size pair
  (leading + middle) jointly with the family check;
- the **body+note glued blocks splitter** (added in the consolidation
  session). PyMuPDF occasionally fuses a body block and the
  immediately following note block into a single block; this
  affects ~95 % of Vol. III blocks and 6.96 % of Vol. IV. The plugin
  emits a diagnostic warning during classification and, in
  ``refine_reconstruction``, mints synthetic NOTE Nodes that recover
  the embedded apparatus content.

Heading levels.

- **HEADING_1 — PARTE.** Five-span small-caps composite block whose
  joined text reads ``"PARTE PRIMA"`` / ``"PARTE SECONDA"`` /
  ``"PARTE TERZA"`` / ``"PARTE QUARTA"``. Span signature:
  ``[("P", 13.98pt), ("ARTE ", 10.98pt), ("P", 13.98pt),
  ("RIMA", 10.98pt), ...]``. Vol. III has 4 PARTE in body (pp. 21,
  275, 341, 369); Vol. IV has 2 (pp. 16, 284). The text pattern is
  case-insensitive on the ordinal. Front-matter Indice variants at
  12.0pt+9.48pt are intentionally NOT classified as HEADING_1.
- **HEADING_2 — CAPITOLO.** Two consecutive blocks fused in
  :meth:`refine_reconstruction`: the ``"CAPITOLO N"`` chapter-number
  block (small-caps three-span ``("C", 13.02pt) + ("APITOLO ",
  10.5pt) + ("I ", 13.02pt)``, joined text ``"CAPITOLO I"``) and
  the immediately-following uppercase title block at 13.02pt.
- **HEADING_3 — Sezione.** Single block ``"Sezione prima"`` (or
  ``seconda``, ``terza``, ...) in ``SimonciniGaramondStd-Italic``
  12.0pt. Uniform across the four volumes for the body-side variant.
  The MAIUSCOLETTO title that may follow a Sezione header is left
  ``UNCLASSIFIED``; a future revision can fuse the pair on the
  model of CAPITOLO.
- **HEADING_4 — paragrafo numerato.** Composite block with a Roman
  ``SimonciniGaramondStd`` 11.52pt span carrying ``"<n>. "``
  followed by an italic ``SimonciniGaramondStd-Italic`` 11.52pt
  span carrying the title (no bold structural marker; italic is
  the emphasis). Hundreds of paragrafi across the four volumes.

Apparatus.

- **NOTE — footnote.** Block whose leading span is
  ``SimonciniGaramondStd`` at one of the two NOTE body sizes:
  9.0pt (Vol. III/IV regime) or 7.98pt (Vol. I/II regime). Text
  opens with the ``(N)`` parenthesised digit marker. The dual-size
  predicate is set as a closed tuple in :data:`NOTE_BODY_SIZES`.
- **CROSS_REFERENCE — inline footnote marker.** A body span at
  10.98pt that contains the substring ``(N)`` somewhere in its
  text. The plugin scans every BODY node's text with the regex
  :data:`_CROSSREF_INLINE_PATTERN` and mints one synthetic
  ``CROSS_REFERENCE`` ``Node`` per match, as a sibling immediately
  after the BODY in its parent's child list. The synthetic node
  IDs follow the tier 1 ``node_NNNN`` convention starting one past
  the maximum counter already assigned by tier 1. The tier 1
  cross-reference resolver then binds each synthetic node to the
  target NOTE within the nearest ``HEADING_2`` ancestor scope.
- **MARGINAL_GLOSS — marginal gloss.** Block whose leading span is
  ``AGaramondPro-BoldItalic`` (or the subset-truncated variants
  ``AGaramondPro-SemiboldIta`` / full ``AGaramondPro-SemiboldItalic``)
  at 8.52pt with ``bbox.x0 < 50`` (left margin). The geometric
  guard excludes the rare 11.5pt AGaramondPro fallback that
  PyMuPDF reports inside the body column (e.g. p.170 of Vol. III).
  Absent on Vol. I/II.
- **CHAPTER_SUMMARY — sommario di apertura capitolo.** Block at
  9.0pt opening with the small-caps three-span pattern
  ``("S", 9.0pt) + ("OMMARIO", 7.02pt) + (": ...", 9.0pt)``.
  Distinguished from a NOTE by the small-caps pattern. Uniform
  across the four volumes.

Artifacts.

- **ARTIFACT_RUNNING_HEADER** — header band at ``y < 70`` carries
  the chapter title in 10.5pt small-caps and the page/paragraph
  number in 7.5pt. Caught by tier 1 by zone; the plugin does not
  override.
- **ARTIFACT_FOOTER** — footer band at ``y > 660``. Caught by
  tier 1 by zone.

Diagnostic warnings (closed vocabulary, prefix ``plugin:giappichelli:``).
See :data:`WARNING_TEMPLATES` for the six entries:

- ``outline_paragraph_mismatch_node_<id>`` — diagnostic for a
  paragraph numerato detected typographically that has no
  corresponding entry in the embedded outline (the analysis
  documents 32 paragraphs missing from the 113-entry outline of
  vol. III). Informational only.
- ``chapter_summary_unparseable_node_<id>`` — the ``CHAPTER_SUMMARY``
  text could not be parsed into ``SummaryItem`` tuples by the
  splitter. Same shape as the Zanichelli / Tesauro plugins.
- ``chapter_title_not_adjacent_block_<idx>_page_<p>`` — a chapter
  number block was registered but the immediately-following
  ``HEADING_2`` title candidate is missing or non-adjacent.
- ``inline_cross_reference_minted_node_<id>_page_<p>`` — one
  synthetic ``CROSS_REFERENCE`` node was minted for each ``(N)``
  marker found inside a BODY node's text. Useful for the audit log.
- ``marginal_gloss_outside_margin_block_<idx>_page_<p>`` — the
  ``AGaramondPro-SemiboldItalic`` 11.5pt fallback observed inside
  the body column (e.g. p.170) is recognised but **not** classified
  as ``MARGINAL_GLOSS`` because the geometric guard fails. The
  warning surfaces the editorial anomaly without committing to a
  category.
- ``body_note_block_glued_block_<idx>_page_<p>`` — PyMuPDF
  occasionally fuses a body block (11.0pt) and the immediately
  following note block (9.0pt) into a single block. The plugin
  detects the pattern ("body 11.0pt block containing ≥ 30 % of
  9.0pt spans") and emits this warning so the loss of a few
  cross-reference targets is traceable in the diagnostic log. The
  block category remains ``BODY`` — no logic splits it
  structurally, since splitting would require touching
  ``ClassifiedBlock``'s 1-to-1 relation with extraction blocks,
  which is outside this plugin's delegated scope.

Pipeline integration.

- :meth:`get_post_processing` returns
  ``["dehyphenate_with_log", "merge_cross_page_notes"]``. The
  ``merge_cross_page_notes`` step was promoted from placeholder to
  real implementation alongside this consolidation (schema 0.5.0)
  and produces a reversible :class:`Transformation` log with
  ``merged_from`` populated. Declaring it here also causes the
  tier 1 ``_resolve_cross_page_note_merging`` resolver to skip its
  own pass to avoid double-merging.
- :meth:`get_layouts_disabled` returns the empty list. Mandrioli
  exercises every Layer 2 layout: linear prose (Layout 1), pinned
  notes (Layout 2), marginal columns via marginal glosses (Layout
  3), and inline footnote markers via the synthetic
  ``CROSS_REFERENCE`` nodes (Layout 4).
- :meth:`refine_apparatus` is pass-through. The four remaining
  tier 1 resolvers (cross-reference binding, marginal position,
  marginal gloss, box association) cover every Mandrioli case after
  cross-page note merging is delegated to the post-processing step.

Instance state.

The plugin keeps a small bag of pending warnings and a pair of
block-index sets between :meth:`refine_classification` and
:meth:`refine_reconstruction`. The warnings flush into
``Document.warnings``; the block-index sets record which blocks were
classified as the ``"CAPITOLO N"`` half and the title half of a
chapter heading pair, so that :meth:`refine_reconstruction` can fuse
the two consecutive ``HEADING_2`` siblings into a single node.

The ``matches()`` discriminator stays below the 0.6 dispatcher
threshold on the three prior plugins' fixtures (Mosconi, Tesauro,
Patriarca) thanks to the symmetric ``SimonciniGaramondStd`` family
penalty: a document whose primary font is not ``SimonciniGaramondStd``
loses 0.30 from its raw score, which suffices to keep Mosconi's
body-dominant + apparatus-heavy signals from clearing the threshold
on this plugin.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import ClassVar

from scabopdf_pipeline.classification.types import ClassifiedBlock
from scabopdf_pipeline.extraction.types import Block, ExtractionResult, Span
from scabopdf_pipeline.postprocessing.types import Transformation
from scabopdf_pipeline.profiling.plugin import ProfilePlugin
from scabopdf_pipeline.profiling.profile import DisabledLayout
from scabopdf_pipeline.profiling.signals import ProfilingSignals
from scabopdf_pipeline.profiling.typography_constants import APPARATUS_PRESENCE_THRESHOLD
from scabopdf_pipeline.reconstruction.minting import NodeIdMinter, max_existing_node_counter
from scabopdf_pipeline.reconstruction.types import (
    Document,
    Node,
    SummaryItem,
    compute_note_length_category,
)
from scabopdf_pipeline.schema.categories import SemanticCategory

SPLITTER_STEP_ID = "giappichelli_body_note_splitter"
"""Identifier carried on every :class:`Transformation` the body+note
splitter records.

Not a key in :class:`postprocessing.registry.PostProcessingRegistry`:
the splitter runs in tier 2 ``refine_reconstruction`` rather than as a
post-processing step. The id is recorded on the resulting
:class:`Transformation` so Layer 2 can recognise the producing step
when reading the reversibility log, and so test code can filter the
log to a specific tier-2 source.
"""

WARNING_PREFIX = "plugin:giappichelli"
"""Common prefix for every warning string this plugin may emit.

See ``docs/SCHEMA_v0.4.0.md § 6`` for the rationale of the prefix
convention and :data:`WARNING_TEMPLATES` for the closed vocabulary.
"""

WARNING_TEMPLATES: tuple[str, ...] = (
    "plugin:giappichelli:outline_paragraph_mismatch_node_<id>",
    "plugin:giappichelli:chapter_summary_unparseable_node_<id>",
    "plugin:giappichelli:chapter_title_not_adjacent_block_<idx>_page_<p>",
    "plugin:giappichelli:inline_cross_reference_minted_node_<id>_page_<p>",
    "plugin:giappichelli:marginal_gloss_outside_margin_block_<idx>_page_<p>",
    "plugin:giappichelli:body_note_block_glued_block_<idx>_page_<p>",
    "plugin:giappichelli:body_note_split_minted_node_<id>_page_<p>",
)
"""Closed vocabulary of warnings the plugin may emit on
``Document.warnings``. Placeholders are replaced with concrete values
at emission time. Consumers should match on the prefix.

The ``body_note_block_glued_block_*`` and ``body_note_split_minted_*``
templates document two distinct aspects of the same glued unit:

- ``body_note_block_glued_block_<idx>_page_<p>`` is emitted by
  :meth:`refine_classification` when a BODY 10.98pt block contains
  the diagnostic share of NOTE-sized spans. It documents the upstream
  problem (PyMuPDF fused two structural blocks into one) regardless
  of whether the plugin can later split the fused block.
- ``body_note_split_minted_node_<id>_page_<p>`` is emitted by
  :meth:`refine_reconstruction` when the splitter materialises a
  synthetic NOTE Node from inside a glued BODY block. It documents
  the downstream recovery (the embedded apparatus content is now an
  addressable Node, no longer lost inside a body).

The two warnings coexist by design: the delta between their counts is
the diagnostic for "glued blocks the splitter could not recover".
"""

PARTE_ORDINALS: tuple[str, ...] = ("Prima", "Seconda", "Terza", "Quarta")
"""Closed list of Italian ordinals used for the PARTE headings of the
Mandrioli-Carratta series.

Vol. III splits into four parts (Prima/Seconda/Terza/Quarta), Vol. IV
into two (Prima/Seconda). Vol. I and Vol. II have no PARTE divisions
and the predicate :meth:`_is_parte_signature` returns False on every
block of those volumes via the size check. Future Giappichelli volumes
may extend the ordinals beyond Quarta if needed.
"""

_PARTE_PATTERN = re.compile(
    r"^PARTE\s+(" + "|".join(PARTE_ORDINALS) + r")\s*$",
    re.IGNORECASE,
)
"""Pattern matching the ``"PARTE Prima"`` (or ``Seconda``, ``Terza``,
``Quarta``) block text exactly. Anchored on both ends with optional
trailing whitespace; the case-insensitive flag covers minor casing
drift across editions.
"""

_CHAPTER_NUMBER_PATTERN = re.compile(r"^CAPITOLO\s+([IVX]+)\s*$", re.IGNORECASE)
"""Pattern matching the ``"CAPITOLO N"`` block text exactly.

``N`` is a Roman numeral. The concatenated text comes from the
small-caps three-span block ``("C", 13.02pt) + ("APITOLO ", 10.5pt) +
("I ", 13.02pt)`` whose joined text is ``"CAPITOLO I"``.
"""

_SECTION_HEADER_PATTERN = re.compile(
    r"^Sezione\s+(prima|seconda|terza|quarta|quinta|sesta|settima|ottava|nona|decima|"
    r"undicesima|dodicesima|tredicesima|quattordicesima|quindicesima)\b",
    re.IGNORECASE,
)
"""Pattern matching the ``"Sezione N"`` Section header in italic 12.0pt.

The ordinal whitelist covers the first fifteen Italian feminine
ordinals. The trailing word boundary lets the predicate match a bare
``"Sezione prima"`` and a longer ``"Sezione prima — Cenni"`` without
anchoring on the end.
"""

_PARAGRAPH_HEADING_PATTERN = re.compile(r"^(\d+)\.\s+(.+)$", re.DOTALL)
"""Pattern matching a paragraph heading (HEADING_4): ``<n>. <title>``.

The paragraph heading is a two-span block: a Roman 11.52pt span
carrying the number ``"<n>. "`` and an italic 11.52pt span carrying
the title. ``re.DOTALL`` lets the title span an embedded line break.
"""

_PARAGRAPH_NUMBER_PATTERN = re.compile(r"^\s*\d+\.\s*$")
"""Pattern matching the leading number-only span of a paragraph heading.

The number span carries just ``"<n>. "`` (with optional trailing
whitespace). Anchored on both ends so that a body span opening with a
numeric reference (e.g. ``"2. premessa"`` inside a citation) does not
trip the discriminator.
"""

_NOTE_MARKER_PATTERN = re.compile(r"^\s*\(\d+\)")
"""Pattern matching the leading marker of a footnote text.

The Mandrioli note marker is always parenthesised: ``(N)`` with one or
more digits. The pattern matches the **block text** lstripped — every
NOTE block observed on the fixture starts with this pattern.
"""

_CROSSREF_INLINE_PATTERN = re.compile(r"(?<!p\.\s)(?<!p\.)\((\d+)\)")
"""Pattern matching an inline cross-reference marker inside a BODY node's text.

A pair of parentheses around one or more digits. The negative
look-behinds rule out the citation pattern ``"p. NN"`` (page reference
with the dot-space variant or just the dot variant) — empirical
inspection confirms ``(p. NN)`` never appears in 10.98pt body text,
only inside 9.0pt note text, but the look-behinds remain as a
robustness safety-net. The captured group is the marker number; the
resolver in :mod:`apparatus.resolver` will bind the synthetic
``CROSS_REFERENCE`` node to the NOTE whose marker matches.
"""

_SOMMARIO_HEAD_LETTER = "S"
"""Leading character of the small-caps SOMMARIO label.

The Mandrioli typesetter renders the word as three spans:
``("S", 9.0pt) + ("OMMARIO", 7.02pt) + (": ...", 9.0pt)``. The plugin
checks ``spans[0].text == "S"`` (or starts with ``"S"``) and the small
size of ``spans[1]`` to identify a SOMMARIO block.
"""

_SOMMARIO_TAIL = "OMMARIO"
"""Trailing-letters portion of the small-caps SOMMARIO label.

``spans[1].text`` must start with this string; in the fixture the
exact value is ``"OMMARIO"`` so a ``startswith`` check is sufficient.
"""

BODY_FONT_PREFIX = "SimonciniGaramondStd"
"""Font family prefix of the Mandrioli body, headings and notes.

PyMuPDF reports both ``SimonciniGaramondStd`` (Roman) and
``SimonciniGaramondStd-Ita`` (Italic) for this family. The prefix
check accepts both.
"""

GLOSS_FONT_FRAGMENT = "AGaramondPro"
"""Font family fragment of the marginal gloss spans.

PyMuPDF reports both ``AGaramondPro-BoldItalic`` and the
subset-truncated ``AGaramondPro-SemiboldIta`` (with one or two
trailing characters chopped off the canonical
``AGaramondPro-SemiboldItalic``). The fragment is intentionally
prefix-agnostic so all three name variants admit the gloss.
"""

BODY_FONT_SIZE = 10.98
"""Body and front-matter heading (Indice, Premessa) leading-span size, in points.

PyMuPDF emits the Mandrioli body at 10.98pt across all four volumes
of the Mandrioli-Carratta series — Vol. I/II (Photoshop-derived
pipeline), Vol. III/IV (InDesign-derived pipeline). The nominal
typesetting size is 11pt; the 0.02pt drift is a stable artefact of
the Adobe Photoshop Image Conversion Plug-in producer that emits
every Giappichelli fixture (regardless of the upstream InDesign or
Photoshop creator).
"""

NOTE_BODY_SIZE = 9.0
"""Footnote body primary size, in points.

The Vol. III and Vol. IV typeset notes at 9.0pt. Also the size of
the CHAPTER_SUMMARY body and the SOMMARIO leading span (uniform
across all four volumes). Discrimination between NOTE and SOMMARIO
relies on the small-caps three-span pattern (see
:meth:`_is_chapter_summary`).
"""

NOTE_ALT_BODY_SIZE = 7.98
"""Footnote body alternative size, in points.

The Vol. I and Vol. II (Photoshop-derived pipeline) typeset notes at
7.98pt rather than 9.0pt — a real editorial difference, not a
PyMuPDF rounding artefact. The NOTE predicate admits both regimes.
"""

NOTE_BODY_SIZES: tuple[float, ...] = (NOTE_ALT_BODY_SIZE, NOTE_BODY_SIZE)
"""Closed tuple of the two NOTE body sizes the Giappichelli pipeline emits.

Order is irrelevant; predicate iterates the tuple.
"""

PARAGRAPH_HEADING_SIZE = 11.52
"""Paragraph heading (HEADING_4) number-span and italic title-span size, in points.

PyMuPDF emits the Mandrioli paragrafo numerato at 11.52pt across
all four volumes (nominal 11.5pt with the same +0.02pt Photoshop
drift as the body).
"""

CHAPTER_HEADING_SIZE = 13.02
"""Chapter heading (HEADING_2) leading-span size, in points.

The CAPITOLO small-caps three-span composite leading span is at
13.02pt (nominal 13.0pt with the +0.02pt Photoshop drift).
Uniform across Vol. III and Vol. IV; Vol. I/II at the same size.
"""

SECTION_HEADER_SIZE = 12.0
"""Sezione header italic body-span size, in points.

The Sezione single-span header in the BODY (e.g. "Sezione prima")
is SimonciniGaramondStd-Italic at 12.0pt — uniform across Vol. III
and Vol. IV (the Vol. I/II body-side Sezione also matches). The
front-matter Indice variant of Sezione is at 10.02pt roman and is
intentionally NOT classified as HEADING_3 to keep Indice paratext
out of the heading hierarchy.
"""

PARTE_LEADING_SIZE = 13.98
"""PARTE body small-caps composite leading-span size, in points.

The five-span small-caps composite `[("P", 13.98pt), ("ARTE ",
10.98pt), ("P", 13.98pt), ("RIMA", 10.98pt), ...]` whose joined
text reads "PARTE PRIMA" (or SECONDA/TERZA/QUARTA). Vol. III has
four PARTE divisions in the body; Vol. IV has two; Vol. I and Vol.
II have none. The 13.98pt nominal is what PyMuPDF reports — there
is no separate "13pt PARTE" path: every real PARTE on Vol. III/IV
is the five-span small-caps composite at this size.
"""

PARTE_MIDDLE_SIZE = 10.98
"""PARTE body small-caps composite middle-span size, in points.

Coincidentally equal to :data:`BODY_FONT_SIZE` but conceptually
distinct (it is the small-caps "ARTE" tail of the composite, not a
body span). Kept as its own constant for documentary clarity.
"""

GLOSS_SIZE = 8.52
"""Marginal gloss size, in points.

PyMuPDF emits AGaramondPro-BoldItalic / AGaramondPro-SemiboldIta
glosses at 8.52pt across Vol. III and Vol. IV (nominal 8.5pt with
the same +0.02pt drift). Vol. I and Vol. II have no AGaramondPro
spans at all — no marginal-gloss apparatus in those volumes.
"""

SOMMARIO_TAIL_SIZE = 7.02
"""Size of the small-caps trailing letters of the SOMMARIO label, in points.

The ``spans[1].text == "OMMARIO"`` portion is typeset at 7.02pt
while the rest of the block is at 9.0pt. The two-tier small-caps
pattern is the SOMMARIO discriminator (see
:meth:`_is_chapter_summary`). Uniform across all four volumes.
"""

MARGIN_X_THRESHOLD = 50.0
"""``bbox.x0`` upper bound for the left-margin marginal gloss column.

A block whose ``x0`` is below this threshold sits in the left margin
column where the AGaramondPro 8.5pt glosses live. Empirical inspection
of the fixture reports gloss x0 values in the range 37.7-43.1 pt; the
50 pt threshold leaves a 6.9 pt cushion. The body column starts at
``x ≈ 60``; the threshold leaves a 10 pt gap so a body span with x0
just under 60 cannot pass the predicate.
"""

MARGINAL_HEADING_LEFT_X1_MAX = 110.0
"""``bbox.x1`` upper bound for a Vol. I/II **left-margin**
MARGINAL_HEADING block, in points.

Vol. I and Vol. II of the Mandrioli series (Photoshop-derived
pipeline) typeset their marginal headings in SimonciniGaramondStd at
7.98pt within both the left and the right margin columns.
Empirical inspection of Vol. I reports left-margin marginal-heading
bbox.x1 values up to 101pt. The body column starts at x ≈ 107pt;
the 110pt threshold therefore admits every left-margin heading while
keeping the body column outside the predicate.
"""

MARGINAL_HEADING_RIGHT_X0_MIN = 370.0
"""``bbox.x0`` lower bound for a Vol. I/II **right-margin**
MARGINAL_HEADING block, in points.

Empirical inspection of Vol. I reports right-margin marginal-heading
bbox.x0 values starting at 382pt. The body column ends near x = 380pt;
the 370pt threshold leaves a 10pt cushion and admits every
right-margin heading observed in the fixture.
"""

PARTE_HEADING_TEXT_LIMIT = 60
"""Max text length for a candidate PARTE heading.

``PARTE QUARTA`` joined from the five-span small-caps composite is
12 characters; the cap leaves substantial margin while still
rejecting 13.98pt composite blocks that carry much more text.
"""

PARTE_MIN_SPANS = 4
"""Minimum span count for the PARTE five-span small-caps composite.

The Mandrioli typesetter emits PARTE divisions as a composite of
five spans alternating between :data:`PARTE_LEADING_SIZE` (13.98pt,
the bracketing capitals) and :data:`PARTE_MIDDLE_SIZE` (10.98pt, the
small-caps tail). The minimum is set at 4 to admit edge cases where
PyMuPDF fuses adjacent spans of the same signature.
"""

CHAPTER_HEADING_TEXT_LIMIT = 30
"""Max text length for a candidate CAPITOLO chapter-number block.

``CAPITOLO XVIII`` is 14 characters; the cap leaves margin while
rejecting 13.02pt blocks with significantly more text.
"""

CHAPTER_TITLE_TEXT_LIMIT = 200
"""Max text length for a candidate chapter-title block.

Chapter titles are short uppercase phrases (e.g.
``"I PROCESSI O PROCEDIMENTI SPECIALI IN GENERALE"``, 47 characters).
The cap discriminates against 13.02pt blocks that carry more text.
"""

SECTION_HEADING_TEXT_LIMIT = 200
"""Max text length for a candidate Sezione header block (italic 12.0pt)."""

PARAGRAPH_HEADING_TEXT_LIMIT = 300
"""Max text length for a paragraph heading (HEADING_4)."""

MARGINAL_GLOSS_MIN_TEXT_LENGTH = 4
"""Min text length for a candidate marginal gloss block."""

MARGINAL_GLOSS_MAX_TEXT_LENGTH = 200
"""Max text length for a candidate marginal gloss block.

Empirical range observed is 5-115 characters; the 200-char cap leaves
generous margin.
"""

BODY_NOTE_GLUED_RATIO_THRESHOLD = 0.30
"""Minimum fraction of note-sized spans inside a body 10.98pt block
to flag the block as a body+note glued artefact.

PyMuPDF occasionally fuses a body block (10.98pt) and the
immediately following note block (9.0pt on Vol. III/IV, 7.98pt on
Vol. I/II) into a single block. The plugin diagnoses the pattern
with this ratio. The Vol. III exhibits the pathology on ~95 % of
its blocks, Vol. IV on 6.96 %, Vol. I and II on 0 %.
"""

NOTE_CONTINUATION_MIN_TEXT_LENGTH = 30
"""Minimum text length of a marker-less NOTE continuation candidate.

The marker-less branch of :meth:`ManualeGiappichelliProfile._is_note`
is permissive enough that, without a length guard, it absorbs short
all-uppercase fragments from the front matter (CAPITOLO drop-cap
tails like ``"APITOLO I"``, author-name fragments like
``"NTONIO CARRATTA"``) that PyMuPDF emits as separate blocks. A
real continuation note carries running prose with substantially more
than 30 characters; the threshold filters the false positives
without affecting any genuine continuation observed in the corpus.
"""

NOTE_CONTINUATION_MAX_UPPER_RATIO = 0.7
"""Maximum uppercase-letter ratio of a marker-less NOTE continuation.

Real note continuations are running prose in mixed case (lowercase
dominant, with occasional uppercase for proper names and
abbreviations). Front-matter CAPITOLO and author-name fragments are
predominantly uppercase (small-caps tails after a drop cap). The
threshold rejects blocks whose letters are more than 70% uppercase,
keeping the genuine continuations and excluding the front-matter
artefacts.
"""

CONFIDENCE_BODY_DOMINANT = 0.30
"""Confidence contribution when SimonciniGaramondStd 10.98pt is present
as a dominant signature.

The body dominance threshold is permissive: in apparatus-heavy
documents like Mandrioli vol. III (where note bucket exceeds body
bucket) the body share drops well below the 70 % typical of
compendia, so a 25 % floor applies here too.
"""

CONFIDENCE_GIAPPICHELLI_FAMILY = 0.20
"""Confidence contribution when SimonciniGaramondStd appears among the
primary fonts. The single most specific positive signal of the
Giappichelli editorial pipeline.
"""

CONFIDENCE_NOTE_APPARATUS = 0.20
"""Confidence contribution when ``footnote_markers`` clears the
apparatus presence threshold. Mandrioli vol. III has 744 markers.
"""

CONFIDENCE_INDESIGN_20 = 0.10
"""Confidence contribution when the creator string matches one of
:data:`GIAPPICHELLI_CREATOR_FRAGMENTS` (currently ``"InDesign 20"``
for Vol. III/IV and ``"Adobe Photoshop"`` for Vol. I/II).

Mosconi uses InDesign CS6, the two UTET plugins use older InDesign
versions, none of which contain either fragment. The Mandrioli
fixtures contain at least one fragment in their creator field.
"""

CONFIDENCE_PAGE_SIZE = 0.05
"""Confidence contribution when the page geometry matches 482x680 pt.

Mandrioli pages are 482.0 x 680.0 pt. The bonus is small to leave room
for other Giappichelli volumes that may use slightly different
formats.
"""

CONFIDENCE_OUTLINE_PRESENT = 0.05
"""Confidence contribution when the PDF outline has at least 100 entries.

Mandrioli has 113 outline entries; smaller documents in the corpus
(compendia, single-genre encyclopedia volumes) tend to have fewer.
"""

CONFIDENCE_FAMILY_PENALTY = -0.30
"""Penalty when ``SimonciniGaramondStd`` is absent from the primary fonts.

Symmetric to the Tesauro plugin's apparatus-presence penalty and the
Mosconi plugin's no-apparatus penalty: when the discriminating
typographic family is absent the plugin steps back. The penalty
suffices to keep Mosconi (body-dominant TimesTenLTStd + apparatus
heavy) and other competing plugins below the 0.6 threshold on the
Mandrioli signals.
"""

BODY_DOMINANCE_MIN_PERCENT = 25.0
"""Minimum body dominance required to credit the SimonciniGaramondStd
body signal. Apparatus-heavy documents distribute their spans across
many signatures; the threshold leaves room while still excluding
documents where SimonciniGaramondStd is a minor incidental face.
"""

# ``APPARATUS_PRESENCE_THRESHOLD`` was promoted to
# :mod:`scabopdf_pipeline.profiling.typography_constants` (P-035).
# Mandrioli carries 744 footnote markers; the 50 floor leaves headroom
# to discriminate the Giappichelli manual from a compendium.

GIAPPICHELLI_CREATOR_FRAGMENT = "InDesign 20"
"""Creator-field substring that signals the InDesign-derived
Giappichelli editorial pipeline (Vol. III/IV, InDesign 20.0 / 20.2).

Kept as a single string for backward compatibility with imports and
tests that referenced it before the Photoshop variant was added.
The actual matching logic in :meth:`matches` iterates
:data:`GIAPPICHELLI_CREATOR_FRAGMENTS`.
"""

GIAPPICHELLI_CREATOR_FRAGMENTS: tuple[str, ...] = (
    GIAPPICHELLI_CREATOR_FRAGMENT,
    "Adobe Photoshop",
)
"""Closed tuple of creator-field substrings that signal a Giappichelli
editorial pipeline.

- ``"InDesign 20"`` — Vol. III (InDesign 20.2) and Vol. IV (InDesign 20.0)
- ``"Adobe Photoshop"`` — Vol. I and Vol. II (Photoshop 26.3, Photoshop
  Image Conversion Plug-in producer)

A document credits the bonus if its creator contains any of the
fragments. Mosconi (InDesign CS6), Tesauro (InDesign older), Patriarca
(Acrobat Distiller), Marotta (Acrobat Pro 9.4.5) contain none.
"""

GIAPPICHELLI_PAGE_WIDTH = 482.0
"""Mandrioli vol. III page width, in points."""

GIAPPICHELLI_PAGE_HEIGHT = 680.0
"""Mandrioli vol. III page height, in points."""

GIAPPICHELLI_PAGE_SIZE_TOLERANCE = 2.0
"""Tolerance on page geometry, in points. The Mandrioli fixture has 6
pages at 481.9 x 680.3 pt and 2 cover pages at 485.0 x 702.7 pt; the
dominant geometry is 482.0 x 680.0 pt.
"""

OUTLINE_ENTRIES_MIN = 100
"""Minimum outline entries to credit the outline-present signal."""

EN_DASH = "\u2013"
"""En-dash character (U+2013). Used as the separator inside CHAPTER_SUMMARY
text on the Tesauro / Giappichelli compendium pattern. Kept as an
explicit escape so ruff's ``RUF001`` does not flag the character as
ambiguous.
"""

_SUMMARY_SPLITTER = re.compile(rf"\s*{re.escape(EN_DASH)}\s*")
"""Regex that splits a CHAPTER_SUMMARY text on its en-dash separators."""

_SUMMARY_ITEM_PATTERN = re.compile(
    r"^\s*(?P<num>\d+(?:\.\d+)*)\.\s*(?P<title>\S.+?)\s*$", re.DOTALL
)
"""Regex that parses one CHAPTER_SUMMARY entry into ``(number, title)``."""

_INTERNAL_WHITESPACE = re.compile(r"\s+")
"""Regex used to collapse runs of whitespace inside parsed titles."""


@dataclass(frozen=True)
class _BlockView:
    """Pre-computed view of a block exposed to the plugin's tier 2 logic.

    Predicates inspect the full ``spans`` tuple directly: for blocks
    where the discriminating signal is on a later span (notably the
    SOMMARIO label whose small-caps middle span sits at index 1) the
    plugin reads the relevant indices explicitly, and for blocks
    where the leading span is representative it accesses ``spans[0]``
    directly. No leading-span helper properties are exposed to keep
    the discriminator code locally explicit.
    """

    block_index: int
    block: Block
    spans: tuple[Span, ...]
    text: str


class ManualeGiappichelliProfile(ProfilePlugin):
    """Corpus plugin for the Giappichelli manual series — Mandrioli-Carratta vol. III."""

    profile_id: ClassVar[str] = "manuale_giappichelli"
    editorial_family: ClassVar[str] = "giappichelli"
    genre: ClassVar[str] = "manuale"

    def __init__(self) -> None:
        self._pending_warnings: list[str] = []
        self._chapter_number_blocks: set[int] = set()
        self._chapter_title_blocks: set[int] = set()

    # ------------------------------------------------------------------
    # ProfilePlugin declarative methods

    @classmethod
    def matches(cls, signals: ProfilingSignals) -> float:
        """Score the document against the Mandrioli-Carratta fingerprint.

        Six positive contributions and one typographic-family penalty,
        deliberately symmetric to the prior plugins' competing
        discriminators. See the module docstring for the editorial
        rationale.
        """
        score = 0.0

        body_dominant = any(
            font.family.startswith(BODY_FONT_PREFIX)
            and abs(font.size - BODY_FONT_SIZE) < 0.1
            and font.dominance_percent >= BODY_DOMINANCE_MIN_PERCENT
            for font in signals.typographic_signature.fonts
        )
        if body_dominant:
            score += CONFIDENCE_BODY_DOMINANT

        family_present = any(
            font.family.startswith(BODY_FONT_PREFIX) for font in signals.typographic_signature.fonts
        )
        if family_present:
            score += CONFIDENCE_GIAPPICHELLI_FAMILY
        else:
            score += CONFIDENCE_FAMILY_PENALTY

        apparatus = signals.apparatus_presence
        if apparatus.footnote_markers >= APPARATUS_PRESENCE_THRESHOLD:
            score += CONFIDENCE_NOTE_APPARATUS

        creator = (signals.producer_creator.creator or "").strip()
        if any(fragment in creator for fragment in GIAPPICHELLI_CREATOR_FRAGMENTS):
            score += CONFIDENCE_INDESIGN_20

        geometry = signals.page_geometry
        if (
            abs(geometry.width_pt - GIAPPICHELLI_PAGE_WIDTH) <= GIAPPICHELLI_PAGE_SIZE_TOLERANCE
            and abs(geometry.height_pt - GIAPPICHELLI_PAGE_HEIGHT)
            <= GIAPPICHELLI_PAGE_SIZE_TOLERANCE
        ):
            score += CONFIDENCE_PAGE_SIZE

        if signals.outline_structure.entries_count >= OUTLINE_ENTRIES_MIN:
            score += CONFIDENCE_OUTLINE_PRESENT

        return max(0.0, score)

    def get_categories(self) -> set[SemanticCategory]:
        """Closed set of categories the plugin may emit on Mandrioli-Carratta."""
        return {
            SemanticCategory.HEADING_1,
            SemanticCategory.HEADING_2,
            SemanticCategory.HEADING_3,
            SemanticCategory.HEADING_4,
            SemanticCategory.BODY,
            SemanticCategory.NOTE,
            SemanticCategory.MARGINAL_GLOSS,
            SemanticCategory.MARGINAL_HEADING,
            SemanticCategory.CHAPTER_SUMMARY,
            SemanticCategory.CROSS_REFERENCE,
            SemanticCategory.ARTIFACT_FOOTER,
            SemanticCategory.ARTIFACT_RUNNING_HEADER,
            SemanticCategory.ARTIFACT_FILIGREE,
            SemanticCategory.BOOK_PAGE_ANCHOR,
            SemanticCategory.UNCLASSIFIED,
            SemanticCategory.EMPTY_PAGE,
        }

    def get_post_processing(self) -> list[str]:
        """Return the ordered list of post-processing step IDs for Mandrioli.

        Two steps are declared, in this order:

        1. ``dehyphenate_with_log`` — the generic end-of-line
           de-hyphenator. Effectively a no-op on the Mandrioli
           digitally-typeset PDFs (no hyphenated line breaks in the
           extracted text layer) but kept for symmetry with the other
           plugins and as defence against future fixtures with hard
           hyphens.
        2. ``merge_cross_page_notes`` — promoted from placeholder to
           real implementation alongside this consolidation. Walks
           NOTE Nodes in DFS pre-order; for each marker-less NOTE
           that is the first NOTE of its page and sits exactly one
           page after the preceding NOTE, fuses the continuation
           text into the head NOTE and records the merge as a
           :class:`Transformation` with ``merged_from`` populated.
           Operates on the post-splitter NOTE set materialised by
           :meth:`refine_reconstruction` (so synthetic NOTEs minted
           by the body+note splitter are available for merging on
           the same equal footing as the marker-bearing NOTEs of
           the tier 1 path).

        Declaring ``merge_cross_page_notes`` here also causes the
        tier 1 ``_resolve_cross_page_note_merging`` resolver in
        :mod:`scabopdf_pipeline.apparatus.resolver` to skip its own
        pass on this plugin's documents, avoiding double-merging.
        Patriarca, Tesauro and Mosconi do not declare the step and
        therefore keep their cross-page merging at tier 1 (which has
        no Transformation log but produces the same final tree
        shape).
        """
        return ["dehyphenate_with_log", "merge_cross_page_notes"]

    def get_layouts_disabled(self) -> list[DisabledLayout]:
        """No layout is disabled: Mandrioli exercises every Layer 2 layout.

        Linear prose body (Layout 1), pinned-note rendering of the
        744-note apparatus (Layout 2), marginal glosses columns
        (Layout 3) and inline cross-reference markers binding body to
        notes (Layout 4 / Dottrina).
        """
        return []

    # ------------------------------------------------------------------
    # Tier 2 refinement hooks

    def refine_classification(
        self,
        extraction: ExtractionResult,
        tier1_results: list[ClassifiedBlock],
    ) -> list[ClassifiedBlock]:
        """Promote UNCLASSIFIED blocks to the plugin's category vocabulary.

        Two-pass sweep on the model of the Mosconi plugin: a first
        pass classifies each block in isolation, a second pass walks
        the refined verdicts to register chapter-number/title pairs
        so :meth:`refine_reconstruction` can fuse them.
        """
        self._pending_warnings = []
        self._chapter_number_blocks = set()
        self._chapter_title_blocks = set()

        refined: list[ClassifiedBlock] = []
        for verdict in tier1_results:
            if verdict.block_index < 0:
                refined.append(verdict)
                continue
            view = self._view(extraction, verdict.block_index)
            if view is None:
                refined.append(verdict)
                continue
            if verdict.category is SemanticCategory.UNCLASSIFIED:
                refined.append(self._reclassify(verdict, view))
                continue
            refined.append(verdict)

        self._register_chapter_pairs(refined)
        return refined

    def refine_reconstruction(
        self,
        document: Document,
        extraction: ExtractionResult,
        classified_blocks: list[ClassifiedBlock],
    ) -> Document:
        """Fuse chapter pairs, split glued body+note blocks, mint inline cross-references.

        Four responsibilities, applied in order at each sibling level:

        1. Fuse adjacent ``HEADING_2`` siblings registered as a chapter
           number / title pair into a single node carrying the
           concatenated text and both ``block_indices`` (same pattern
           as the Mosconi and Tesauro plugins).
        2. **Split glued body+note BODY nodes** into a truncated BODY
           plus one or more synthetic NOTE siblings, each carrying the
           note text segmented at the ``(N)`` markers in the spans of
           the original block. See :meth:`_split_body_note_glued` for
           the splitter detail; schema 0.5.0 records each split as a
           :class:`Transformation` with ``split_into`` populated, so
           the structural decomposition is fully reversible from the
           log.
        3. Mint synthetic ``CROSS_REFERENCE`` nodes as siblings after
           every (now-truncated) BODY node whose ``text`` carries one
           or more inline ``(N)`` markers. The synthetic node IDs
           follow the tier 1 ``node_NNNN`` convention starting one past
           the maximum counter already assigned by tier 1 (and one past
           the highest counter minted by the body+note splitter above).
        4. Parse every ``CHAPTER_SUMMARY`` node's text into
           ``SummaryItem`` tuples using the en-dash splitter and the
           ``<num>. <title>`` regex.

        Pending warnings queued by :meth:`refine_classification` flush
        into ``Document.warnings`` here. Transformations recorded by
        the body+note splitter are appended to
        ``Document.transformations`` so the downstream apparatus
        resolver and the post-processing orchestrator carry them
        forward into the emitted JSON.
        """
        del classified_blocks

        new_warnings = list(self._pending_warnings)
        self._pending_warnings = []
        new_transformations: list[Transformation] = []

        next_id = NodeIdMinter(start=max_existing_node_counter(document.root) + 1)
        new_roots = self._fuse_and_refine(
            document.root, extraction, new_warnings, new_transformations, next_id
        )

        return Document(
            root=new_roots,
            warnings=tuple(document.warnings) + tuple(new_warnings),
            transformations=tuple(document.transformations) + tuple(new_transformations),
        )

    def refine_apparatus(
        self,
        document: Document,
        extraction: ExtractionResult,
        classified_blocks: list[ClassifiedBlock],
    ) -> Document:
        """Pass-through: the five tier 1 resolvers cover every Mandrioli case.

        - ``_resolve_cross_page_note_merging`` merges cross-page note
          continuations using the parentheses-optional
          ``NOTE_MARKER_REGEX``;
        - ``_resolve_cross_references`` binds each synthetic
          ``CROSS_REFERENCE`` minted by :meth:`refine_reconstruction`
          to the target NOTE within the ``HEADING_2`` chapter scope;
        - ``_resolve_marginal_glosses`` binds each ``MARGINAL_GLOSS``
          to the closest NOTE on the same page via the y-centre
          proximity rule.

        The plugin has no profile-specific apparatus refinement to add.
        """
        del extraction, classified_blocks
        return document

    # ------------------------------------------------------------------
    # Per-block classification

    def _reclassify(self, verdict: ClassifiedBlock, view: _BlockView) -> ClassifiedBlock:
        if self._is_marginal_gloss(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.MARGINAL_GLOSS,
                reason="giappichelli_marginal_gloss",
            )

        if self._is_marginal_gloss_outside_margin(view):
            self._pending_warnings.append(
                f"{WARNING_PREFIX}:marginal_gloss_outside_margin_block_"
                f"{verdict.block_index}_page_{view.block.page}"
            )
            return verdict

        if self._is_marginal_heading(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.MARGINAL_HEADING,
                reason="giappichelli_marginal_heading",
            )

        if self._is_chapter_summary(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.CHAPTER_SUMMARY,
                reason="giappichelli_chapter_summary",
            )

        if self._is_note(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.NOTE,
                reason="giappichelli_note",
            )

        if self._is_parte_signature(view):
            text = view.text.strip()
            if _PARTE_PATTERN.match(text) and len(text) <= PARTE_HEADING_TEXT_LIMIT:
                return ClassifiedBlock(
                    block_index=verdict.block_index,
                    category=SemanticCategory.HEADING_1,
                    reason="giappichelli_part",
                )

        if self._is_chapter_heading_signature(view):
            text = view.text.strip()
            if _CHAPTER_NUMBER_PATTERN.match(text) and len(text) <= CHAPTER_HEADING_TEXT_LIMIT:
                self._chapter_number_blocks.add(verdict.block_index)
                return ClassifiedBlock(
                    block_index=verdict.block_index,
                    category=SemanticCategory.HEADING_2,
                    reason="giappichelli_chapter_number",
                )
            if self._looks_like_chapter_title(text):
                # Provisional HEADING_2 chapter-title candidate; the
                # second pass in :meth:`_register_chapter_pairs` keeps
                # it only when it follows a chapter-number block,
                # otherwise demotes it back to UNCLASSIFIED.
                return ClassifiedBlock(
                    block_index=verdict.block_index,
                    category=SemanticCategory.HEADING_2,
                    reason="giappichelli_chapter_title_candidate",
                )

        if self._is_section_header(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.HEADING_3,
                reason="giappichelli_section_header",
            )

        if self._is_paragraph_heading(view):
            text = view.text.strip()
            if _PARAGRAPH_HEADING_PATTERN.match(text) and len(text) <= PARAGRAPH_HEADING_TEXT_LIMIT:
                return ClassifiedBlock(
                    block_index=verdict.block_index,
                    category=SemanticCategory.HEADING_4,
                    reason="giappichelli_paragraph_heading",
                )

        if self._is_body_signature(view):
            if self._is_body_note_glued(view):
                self._pending_warnings.append(
                    f"{WARNING_PREFIX}:body_note_block_glued_block_"
                    f"{verdict.block_index}_page_{view.block.page}"
                )
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.BODY,
                reason="giappichelli_body",
            )

        return verdict

    # ------------------------------------------------------------------
    # Signature predicates

    @staticmethod
    def _is_body_signature(view: _BlockView) -> bool:
        """A body block opens with SimonciniGaramondStd at 10.98pt."""
        if not view.spans:
            return False
        leading = view.spans[0]
        family_ok = leading.font.startswith(BODY_FONT_PREFIX)
        size_ok = abs(leading.size - BODY_FONT_SIZE) < 0.1
        return family_ok and size_ok

    @staticmethod
    def _is_chapter_heading_signature(view: _BlockView) -> bool:
        """A 13.02pt block in the SimonciniGaramondStd family.

        The signature covers CAPITOLO number and CAPITOLO title only;
        PARTE divisions are typeset as a five-span small-caps composite
        at :data:`PARTE_LEADING_SIZE` (13.98pt) and are matched
        upstream by :meth:`_is_parte_signature` before this predicate
        runs. Discrimination between chapter-number and chapter-title
        candidates is by text pattern.
        """
        if not view.spans:
            return False
        leading = view.spans[0]
        family_ok = leading.font.startswith(BODY_FONT_PREFIX)
        size_ok = abs(leading.size - CHAPTER_HEADING_SIZE) < 0.1
        return family_ok and size_ok

    @staticmethod
    def _is_parte_signature(view: _BlockView) -> bool:
        """A PARTE block opens with the five-span small-caps composite at 13.98pt.

        The Mandrioli typesetter renders PARTE divisions as a composite
        of at least four spans alternating between
        :data:`PARTE_LEADING_SIZE` (13.98pt, the bracketing capitals
        of "PARTE PRIMA/SECONDA/...") and :data:`PARTE_MIDDLE_SIZE`
        (10.98pt, the small-caps tail). The predicate checks the
        family on the first two spans and verifies the size pair
        ``(13.98pt, 10.98pt)``. Text-pattern discrimination is done
        downstream against :data:`_PARTE_PATTERN`.

        Vol. III has four PARTE in the body; Vol. IV has two. Vol. I
        and Vol. II have none, and the predicate returns False on
        every block of those volumes by virtue of the size check.
        """
        if len(view.spans) < PARTE_MIN_SPANS:
            return False
        s0 = view.spans[0]
        s1 = view.spans[1]
        if not s0.font.startswith(BODY_FONT_PREFIX):
            return False
        if not s1.font.startswith(BODY_FONT_PREFIX):
            return False
        if abs(s0.size - PARTE_LEADING_SIZE) > 0.1:
            return False
        return abs(s1.size - PARTE_MIDDLE_SIZE) < 0.1

    @staticmethod
    def _looks_like_chapter_title(text: str) -> bool:
        """Heuristic: short uppercase phrase, not matching CAPITOLO pattern."""
        if not text:
            return False
        if len(text) > CHAPTER_TITLE_TEXT_LIMIT:
            return False
        if _CHAPTER_NUMBER_PATTERN.match(text):
            return False
        if _PARTE_PATTERN.match(text):
            return False
        # The bulk of the alphabetical characters must be uppercase.
        letters = [c for c in text if c.isalpha()]
        if not letters:
            return False
        upper_ratio = sum(1 for c in letters if c.isupper()) / len(letters)
        return upper_ratio >= 0.8

    @staticmethod
    def _is_section_header(view: _BlockView) -> bool:
        """A Sezione header is SimonciniGaramondStd-Italic 12.0pt opening with "Sezione N".

        The body-side Sezione header is uniformly typeset at 12.0pt
        italic across Vol. III and Vol. IV (the prior plugin
        generation looked for 11.0pt italic and missed every match).
        Vol. I and Vol. II also use 12.0pt italic for body Sezione.
        The front-matter Indice variant at 10.02pt roman is NOT
        classified as HEADING_3 — paratext stays UNCLASSIFIED.
        """
        if not view.spans:
            return False
        leading = view.spans[0]
        family_ok = leading.font.startswith(BODY_FONT_PREFIX)
        size_ok = abs(leading.size - SECTION_HEADER_SIZE) < 0.1
        italic_ok = leading.is_italic
        if not (family_ok and size_ok and italic_ok):
            return False
        if len(view.text) > SECTION_HEADING_TEXT_LIMIT:
            return False
        return bool(_SECTION_HEADER_PATTERN.match(view.text.strip()))

    @staticmethod
    def _is_paragraph_heading(view: _BlockView) -> bool:
        """A paragraph heading is a 11.5pt two-span composite ``<n>. <title>``.

        The number span is Roman at 11.5pt; the title span is Italic at
        11.5pt. The predicate checks the leading span's signature
        (Roman 11.5pt, number-only text) AND the presence of at least
        one Italic 11.5pt span among the following spans.
        """
        if len(view.spans) < 2:
            return False
        first = view.spans[0]
        family_ok = first.font.startswith(BODY_FONT_PREFIX)
        size_ok = abs(first.size - PARAGRAPH_HEADING_SIZE) < 0.1
        if not (family_ok and size_ok):
            return False
        if first.is_italic:
            return False
        if not _PARAGRAPH_NUMBER_PATTERN.match(first.text):
            return False
        return any(
            span.font.startswith(BODY_FONT_PREFIX)
            and abs(span.size - PARAGRAPH_HEADING_SIZE) < 0.1
            and span.is_italic
            for span in view.spans[1:]
        )

    @staticmethod
    def _is_chapter_summary(view: _BlockView) -> bool:
        """A SOMMARIO block opens with the small-caps three-span ``S + OMMARIO + :``.

        The discriminator is:

        - ``spans[0]`` is SimonciniGaramondStd at 9.0pt with text
          starting with the letter ``S``;
        - ``spans[1]`` is SimonciniGaramondStd at 7.0pt with text
          starting with ``OMMARIO``;
        - ``spans[2]`` (when present) is at 9.0pt and starts with
          ``:``.

        The pattern is strict: the three spans must appear in order and
        with the documented sizes. Without this discrimination a naive
        classifier would label the SOMMARIO as a NOTE because both
        share the 9.0pt body size.
        """
        if len(view.spans) < 2:
            return False
        s0 = view.spans[0]
        s1 = view.spans[1]
        if not s0.font.startswith(BODY_FONT_PREFIX):
            return False
        if abs(s0.size - NOTE_BODY_SIZE) > 0.3:
            return False
        if not s0.text.startswith(_SOMMARIO_HEAD_LETTER):
            return False
        if not s1.font.startswith(BODY_FONT_PREFIX):
            return False
        if abs(s1.size - SOMMARIO_TAIL_SIZE) > 0.3:
            return False
        return s1.text.startswith(_SOMMARIO_TAIL)

    @staticmethod
    def _is_note(view: _BlockView) -> bool:
        """A note block opens with SimonciniGaramondStd at one of the two NOTE
        body sizes (9.0pt Vol. III/IV regime, 7.98pt Vol. I/II regime) and
        text matching the ``(N)`` marker.

        The typographic check inspects the **effective leading span**
        (the first span whose text is not pure whitespace, returned by
        :meth:`_effective_leading_span`) rather than the raw first
        span. PyMuPDF emits ~300 footnote blocks on Vol. III whose
        first span is a one- or two-character whitespace fallback
        (Courier, Mangal, Cambria) at 7.98pt before the actual note
        text starts in SimonciniGaramondStd 9pt; using the effective
        leading absorbs that artefact without false positives.

        Marker-less continuations are deliberately **not** classified
        here. Two alternative recovery paths cover them without the
        false-positive risk a purely-geometric guard would introduce
        on Vol. I/II bibliography sections (which share the 7.98pt
        SimonciniGaramondStd signature):

        1. **Glued body+note blocks** whose first 9pt run is a
           marker-less continuation are handled by
           :meth:`_split_body_note_glued` via the marker-less
           first-transition rule in :meth:`_find_note_transitions`.
           The splitter's prose-check guard (see
           :meth:`_looks_like_note_continuation`) discriminates
           genuine continuations from front-matter small-caps
           fragments at the structural level.
        2. **Standalone marker-less continuations** that PyMuPDF
           emits as separate blocks (rare on Vol. III: empirical
           gain would be ~6 Nodes) are not recovered, accepting a
           small under-count on the densest fixture rather than the
           Vol. I/II false-positive rate that a purely-geometric
           guard would produce.
        """
        leading = ManualeGiappichelliProfile._effective_leading_span(view.spans)
        if leading is None:
            return False
        family_ok = leading.font.startswith(BODY_FONT_PREFIX)
        size_ok = any(abs(leading.size - s) < 0.3 for s in NOTE_BODY_SIZES)
        if not (family_ok and size_ok):
            return False
        return bool(_NOTE_MARKER_PATTERN.match(view.text.lstrip()))

    @staticmethod
    def _looks_like_note_continuation(text: str) -> bool:
        """Reject obvious non-continuation fragments by length and case.

        A real marker-less NOTE continuation carries running prose:
        substantial text (>= :data:`NOTE_CONTINUATION_MIN_TEXT_LENGTH`)
        with the bulk of letters in lowercase (upper-ratio
        <= :data:`NOTE_CONTINUATION_MAX_UPPER_RATIO`). Front-matter
        small-caps fragments (CAPITOLO drop-cap tails, author-name
        small caps) fail one of the two guards: they are either too
        short or predominantly uppercase. The check is consulted in
        two places: by :meth:`_is_note` on the marker-less branch of
        classification, and by :meth:`_split_body_note_glued` when
        minting the first synthetic NOTE from a marker-less
        transition.
        """
        stripped = text.strip()
        if len(stripped) < NOTE_CONTINUATION_MIN_TEXT_LENGTH:
            return False
        letters = [c for c in stripped if c.isalpha()]
        if not letters:
            return False
        upper_ratio = sum(1 for c in letters if c.isupper()) / len(letters)
        return upper_ratio <= NOTE_CONTINUATION_MAX_UPPER_RATIO

    @staticmethod
    def _effective_leading_span(spans: tuple[Span, ...]) -> Span | None:
        """Return the first non-whitespace span, or the first span if all empty.

        PyMuPDF sometimes emits a leading whitespace span at the start
        of a footnote block in a fallback font (Courier, Mangal,
        Cambria) at 7.98pt, carrying just one or two spaces of
        indentation before the actual note text begins in
        SimonciniGaramondStd at 9.0pt. The plugin predicates that key
        on the leading span's typography (``_is_note``, the splitter's
        ``_is_glued_spans``) would miss those blocks if they peeked at
        the raw first span. Looking at the first **non-whitespace**
        span absorbs the typesetting artefact and lets the
        substantive content drive classification.

        Returns ``None`` if the span tuple is empty; returns the very
        first span if every span has whitespace-only text (no
        non-whitespace span found). The latter case is defensive and
        does not occur in the fixture.
        """
        for span in spans:
            if span.text.strip():
                return span
        return spans[0] if spans else None

    @staticmethod
    def _is_marginal_gloss(view: _BlockView) -> bool:
        """A marginal gloss is AGaramondPro* 8.5pt with ``bbox.x0 < 50``."""
        if not view.spans:
            return False
        leading = view.spans[0]
        family_ok = GLOSS_FONT_FRAGMENT in leading.font
        size_ok = abs(leading.size - GLOSS_SIZE) < 0.3
        if not (family_ok and size_ok):
            return False
        x0 = view.block.bbox[0]
        if x0 >= MARGIN_X_THRESHOLD:
            return False
        text_len = len(view.text.strip())
        return MARGINAL_GLOSS_MIN_TEXT_LENGTH <= text_len <= MARGINAL_GLOSS_MAX_TEXT_LENGTH

    @staticmethod
    def _is_marginal_heading(view: _BlockView) -> bool:
        """A SimonciniGaramondStd 7.98pt block in the left margin column.

        Vol. I and Vol. II of the Mandrioli series typeset their
        marginal headings in SimonciniGaramondStd at
        :data:`NOTE_ALT_BODY_SIZE` (7.98pt) sitting in the left margin
        column (``bbox.x0 < MARGINAL_HEADING_X_THRESHOLD``). The
        predicate intercepts these blocks **before** :meth:`_is_note`
        so the 7.98pt-leading note signature does not absorb them.

        Vol. III and Vol. IV typeset their marginal annotations in
        AGaramondPro at 8.52pt (caught upstream by
        :meth:`_is_marginal_gloss`) and their notes at 9.0pt; neither
        path satisfies this predicate, so the rule is editorial-
        family-correct on every Mandrioli volume.

        The predicate inspects the **effective leading span** (skipping
        leading whitespace fallback spans) per
        :meth:`_effective_leading_span`, mirroring the convention used
        by :meth:`_is_note`.
        """
        leading = ManualeGiappichelliProfile._effective_leading_span(view.spans)
        if leading is None:
            return False
        if not leading.font.startswith(BODY_FONT_PREFIX):
            return False
        if abs(leading.size - NOTE_ALT_BODY_SIZE) > 0.1:
            return False
        x0 = view.block.bbox[0]
        x1 = view.block.bbox[2]
        in_left_margin = x1 <= MARGINAL_HEADING_LEFT_X1_MAX
        in_right_margin = x0 >= MARGINAL_HEADING_RIGHT_X0_MIN
        return in_left_margin or in_right_margin

    @staticmethod
    def _is_marginal_gloss_outside_margin(view: _BlockView) -> bool:
        """An AGaramondPro* block whose ``bbox.x0`` sits inside the body column.

        The Mandrioli typesetter occasionally substitutes a few glyphs
        with AGaramondPro-SemiboldItalic at 11.5pt INSIDE the body
        column (e.g. p.170 "cu-/ratore del minore"). This is NOT a
        marginal gloss but a typographic anomaly; the plugin surfaces
        it via a diagnostic warning without committing to a category.
        """
        if not view.spans:
            return False
        leading = view.spans[0]
        if GLOSS_FONT_FRAGMENT not in leading.font:
            return False
        x0 = view.block.bbox[0]
        return x0 >= MARGIN_X_THRESHOLD

    @staticmethod
    def _is_body_note_glued(view: _BlockView) -> bool:
        """A body 10.98pt block whose internal note-sized-span share exceeds the threshold.

        PyMuPDF occasionally fuses a body block and the immediately
        following note block into a single block. The discriminator
        is: leading span at 10.98pt body signature AND the fraction of
        subsequent spans at one of :data:`NOTE_BODY_SIZES` exceeds
        :data:`BODY_NOTE_GLUED_RATIO_THRESHOLD`. The dual-regime size
        check is required because Vol. I/II use 7.98pt notes and
        Vol. III/IV use 9.0pt notes — both pipelines can in principle
        produce glued blocks (in practice Vol. I/II have ~0 % glued
        rate; the dual check is for robustness).
        """
        if len(view.spans) < 2:
            return False
        leading = view.spans[0]
        if not leading.font.startswith(BODY_FONT_PREFIX):
            return False
        if abs(leading.size - BODY_FONT_SIZE) > 0.1:
            return False
        note_spans = sum(
            1
            for span in view.spans
            if span.font.startswith(BODY_FONT_PREFIX)
            and any(abs(span.size - s) < 0.3 for s in NOTE_BODY_SIZES)
        )
        return (note_spans / len(view.spans)) >= BODY_NOTE_GLUED_RATIO_THRESHOLD

    # ------------------------------------------------------------------
    # Chapter pair detection

    def _register_chapter_pairs(self, refined: list[ClassifiedBlock]) -> None:
        """Promote provisional chapter-title candidates after each chapter number.

        Two-pass design: :meth:`_reclassify` classifies every 13.02pt
        non-CAPITOLO uppercase block as
        ``HEADING_2 / giappichelli_chapter_title_candidate`` provisional
        (PARTE divisions are intercepted upstream by
        :meth:`_is_parte_signature` at 13.98pt and never reach this
        pass). This pass walks the refined verdicts in extraction order
        and, for each chapter-number verdict, promotes the next
        non-stamp chapter-title candidate to a confirmed
        ``giappichelli_chapter_title`` and registers its block_index in
        :attr:`_chapter_title_blocks`. Unmatched candidates are demoted
        back to ``UNCLASSIFIED`` so a stray uppercase 13.02pt block
        does not pollute the H2 level.
        """
        n = len(refined)
        confirmed_title_indices: set[int] = set()
        for i, verdict in enumerate(refined):
            if verdict.block_index not in self._chapter_number_blocks:
                continue
            for j in range(i + 1, n):
                candidate = refined[j]
                if candidate.block_index < 0:
                    continue
                if candidate.category is SemanticCategory.ARTIFACT_STAMP:
                    continue
                if (
                    candidate.category is SemanticCategory.HEADING_2
                    and candidate.reason == "giappichelli_chapter_title_candidate"
                ):
                    refined[j] = ClassifiedBlock(
                        block_index=candidate.block_index,
                        category=SemanticCategory.HEADING_2,
                        reason="giappichelli_chapter_title",
                    )
                    self._chapter_title_blocks.add(candidate.block_index)
                    confirmed_title_indices.add(candidate.block_index)
                    break
                break

        # Demote any leftover chapter-title candidates to UNCLASSIFIED.
        for i, verdict in enumerate(refined):
            if (
                verdict.category is SemanticCategory.HEADING_2
                and verdict.reason == "giappichelli_chapter_title_candidate"
                and verdict.block_index not in confirmed_title_indices
            ):
                refined[i] = ClassifiedBlock(
                    block_index=verdict.block_index,
                    category=SemanticCategory.UNCLASSIFIED,
                    reason="giappichelli_chapter_title_orphan",
                )

    # ------------------------------------------------------------------
    # Tree refinement

    def _fuse_and_refine(
        self,
        roots: tuple[Node, ...],
        extraction: ExtractionResult,
        warnings: list[str],
        transformations: list[Transformation],
        next_id: NodeIdMinter,
    ) -> tuple[Node, ...]:
        """Return a new forest with chapter pairs fused, glued body+note
        blocks split, cross-refs minted, chapter summaries parsed and
        the descendants recursively refined.
        """
        # Step 1: fuse chapter pairs at this sibling level and recurse into descendants.
        fused = self._fuse_chapters_recursive(roots, extraction, warnings, transformations, next_id)
        # Step 2: split body+note glued blocks at this sibling level
        # (must precede cross-reference minting so the truncated BODY
        # carries only body-side text when scanned for (N) markers).
        with_notes = self._split_body_note_glued(
            list(fused), extraction, warnings, transformations, next_id
        )
        # Step 3: mint cross-refs from BODY nodes (now post-split).
        with_crossrefs = self._mint_cross_references(list(with_notes), warnings, next_id)
        return tuple(with_crossrefs)

    def _fuse_chapters_recursive(
        self,
        roots: tuple[Node, ...],
        extraction: ExtractionResult,
        warnings: list[str],
        transformations: list[Transformation],
        next_id: NodeIdMinter,
    ) -> tuple[Node, ...]:
        new_nodes: list[Node] = []
        i = 0
        while i < len(roots):
            node = roots[i]
            partner: Node | None = None
            if self._is_chapter_number_node(node) and i + 1 < len(roots):
                candidate = roots[i + 1]
                if self._is_chapter_title_node(candidate):
                    partner = candidate
            if partner is not None:
                fused = self._fuse_chapter_pair(
                    node, partner, extraction, warnings, transformations, next_id
                )
                new_nodes.append(fused)
                i += 2
                continue
            if self._is_chapter_number_node(node):
                warnings.append(
                    f"{WARNING_PREFIX}:chapter_title_not_adjacent_block_"
                    f"{node.block_indices[0] if node.block_indices else -1}_"
                    f"page_{node.page_index}"
                )
            refined = self._refine_node(node, extraction, warnings, transformations, next_id)
            new_nodes.append(refined)
            i += 1
        return tuple(new_nodes)

    def _is_chapter_number_node(self, node: Node) -> bool:
        return (
            node.category is SemanticCategory.HEADING_2
            and len(node.block_indices) == 1
            and node.block_indices[0] in self._chapter_number_blocks
        )

    def _is_chapter_title_node(self, node: Node) -> bool:
        return (
            node.category is SemanticCategory.HEADING_2
            and len(node.block_indices) == 1
            and node.block_indices[0] in self._chapter_title_blocks
        )

    def _fuse_chapter_pair(
        self,
        number_node: Node,
        title_node: Node,
        extraction: ExtractionResult,
        warnings: list[str],
        transformations: list[Transformation],
        next_id: NodeIdMinter,
    ) -> Node:
        """Merge two ``HEADING_2`` siblings into a single chapter heading node."""
        number_text = (number_node.text or "").strip()
        title_text = (title_node.text or "").strip()
        if number_text and title_text:
            merged_text: str | None = f"{number_text}. {title_text}"
        elif number_text:
            merged_text = number_text
        else:
            merged_text = title_text or None
        merged_children = self._fuse_chapters_recursive(
            tuple((*number_node.children, *title_node.children)),
            extraction,
            warnings,
            transformations,
            next_id,
        )
        return Node(
            id=number_node.id,
            category=SemanticCategory.HEADING_2,
            children=merged_children,
            page_index=number_node.page_index,
            block_indices=number_node.block_indices + title_node.block_indices,
            text=merged_text,
            level=2,
            summary_items=None,
            toc_items=None,
            apparatus_refs=number_node.apparatus_refs,
        )

    def _refine_node(
        self,
        node: Node,
        extraction: ExtractionResult,
        warnings: list[str],
        transformations: list[Transformation],
        next_id: NodeIdMinter,
    ) -> Node:
        """Recursively refine a node and its descendants.

        ``CHAPTER_SUMMARY`` nodes get their ``summary_items`` populated
        by parsing the text with the en-dash splitter; all other nodes
        get their descendants recursively refined.
        """
        new_children = self._fuse_and_refine(
            node.children, extraction, warnings, transformations, next_id
        )
        if node.category is SemanticCategory.CHAPTER_SUMMARY:
            items = self._parse_chapter_summary(node.text)
            if items is None:
                warnings.append(f"{WARNING_PREFIX}:chapter_summary_unparseable_node_{node.id}")
            return Node(
                id=node.id,
                category=node.category,
                children=new_children,
                page_index=node.page_index,
                block_indices=node.block_indices,
                text=node.text,
                level=node.level,
                summary_items=items,
                toc_items=None,
                apparatus_refs=node.apparatus_refs,
            )
        if new_children == node.children:
            return node
        return Node(
            id=node.id,
            category=node.category,
            children=new_children,
            page_index=node.page_index,
            block_indices=node.block_indices,
            text=node.text,
            level=node.level,
            summary_items=node.summary_items,
            toc_items=node.toc_items,
            apparatus_refs=node.apparatus_refs,
        )

    def _split_body_note_glued(
        self,
        nodes: list[Node],
        extraction: ExtractionResult,
        warnings: list[str],
        transformations: list[Transformation],
        next_id: NodeIdMinter,
    ) -> list[Node]:
        """Split BODY or NOTE nodes that contain multiple footnotes into
        independent NOTE siblings.

        Two structurally distinct cases handled in one pass:

        - **BODY+NOTE glued**: PyMuPDF emits a body block and the
          immediately following note block as a single block whose
          spans alternate between :data:`BODY_FONT_SIZE` (10.98pt,
          body) and one of :data:`NOTE_BODY_SIZES` (9.0pt on
          Vol. III/IV, 7.98pt on Vol. I/II). Tier 1 reconstruction
          materialises such a fused block as a single BODY ``Node``
          whose ``text`` concatenates body and note span text
          indiscriminately. The Vol. III is especially affected:
          ~95 % of all text blocks present the glued pattern.
        - **Multi-note NOTE**: PyMuPDF emits multiple consecutive
          footnotes (e.g. ``(13) ... (14) ... (15) ...``) as a single
          NOTE block whose spans include the marker spans of each
          contained note. Without splitting, every such block becomes
          a single NOTE Node carrying the text of N notes, losing the
          per-note granularity that Layer 2 needs to render apparatus
          references correctly.

        Algorithm. For every BODY or NOTE Node with exactly one
        block_index:

        - Recover the original spans via
          ``extraction.spans[block.span_range[0]:block.span_range[1]]``.
        - For BODY: verify the glued predicate (effective leading at
          BODY_FONT_SIZE plus a NOTE-share ratio above
          :data:`BODY_NOTE_GLUED_RATIO_THRESHOLD`); skip if not glued.
        - For NOTE: skip the glued predicate; rely on the transition
          count alone.
        - Identify transitions via :meth:`_find_note_transitions`: a
          new line-leading ``(N)`` marker opens a new NOTE chunk, and
          the first marker-less 9pt span (if any) opens a continuation
          chunk.
        - **For BODY blocks**: the surviving BODY keeps the spans
          before the first transition (body text, possibly empty);
          one synthetic NOTE is minted per transition.
        - **For NOTE blocks**: the surviving NOTE keeps the spans
          from the first transition up to the second; one synthetic
          NOTE is minted per additional transition. If there is only
          one transition, no split happens (single-note block).
        - Synthetic NOTE Nodes are inserted as siblings immediately
          after the surviving Node in the result list, using the same
          ``NodeIdMinter`` that the cross-reference minting later
          consumes; their ``block_indices`` reuse the source
          block_index (the NOTE conceptually originates from the same
          block).
        - Each minted NOTE emits a
          ``body_note_split_minted_node_<id>_page_<p>`` warning.
        - One :class:`Transformation` per split is recorded on the
          surviving Node. Its textual fields encode the text
          truncation (the part removed corresponds to the moved span
          text); its ``split_into`` field (added in schema 0.5.0)
          lists the synthetic NOTE ids. Layer 2 reverts the split by
          reattaching the removed text and dropping the synthetic
          siblings.

        The :class:`Transformation` reversibility convention is
        satisfied on the textual side
        (``pre[position[0]:position[1]] == original`` and
        ``post[position[0]:position[0]+len(normalized)] == normalized``,
        the latter trivially with ``normalized == ""``) and on the
        structural side via ``split_into``. When the pre-step or
        post-step text is ``None``, the Transformation textual fields
        collapse to empty strings; ``split_into`` remains
        authoritative for the structural side.
        """
        result: list[Node] = []
        for node in nodes:
            if node.category not in (SemanticCategory.BODY, SemanticCategory.NOTE):
                result.append(node)
                continue
            if len(node.block_indices) != 1:
                result.append(node)
                continue
            block_index = node.block_indices[0]
            if block_index < 0 or block_index >= len(extraction.blocks):
                result.append(node)
                continue
            block = extraction.blocks[block_index]
            start, end = block.span_range
            spans = tuple(extraction.spans[start:end])
            is_body = node.category is SemanticCategory.BODY
            if is_body and not self._is_glued_spans(spans):
                result.append(node)
                continue
            transitions = self._find_note_transitions(spans)
            if is_body:
                if not transitions:
                    # Glued but no recoverable marker or continuation
                    # signal — leave BODY as is. The upstream
                    # ``body_note_block_glued`` warning still tracks
                    # the lost apparatus.
                    result.append(node)
                    continue
                # Surviving BODY = spans before the first transition.
                surviving_start = 0
                surviving_end = transitions[0]
                synthetic_transitions = transitions
                surviving_category = SemanticCategory.BODY
            else:
                # NOTE block: split only if there are 2+ transitions
                # (single-transition NOTE is just a regular single-note
                # block — leave untouched).
                if len(transitions) <= 1:
                    result.append(node)
                    continue
                # Surviving NOTE = spans from transitions[0] up to
                # transitions[1]; synthetic NOTEs for transitions[1:].
                surviving_start = transitions[0]
                surviving_end = transitions[1]
                synthetic_transitions = transitions[1:]
                surviving_category = SemanticCategory.NOTE
            surviving_spans = spans[surviving_start:surviving_end]
            surviving_text_raw = "".join(s.text for s in surviving_spans)
            surviving_text_stripped = (
                surviving_text_raw.strip() if not is_body else surviving_text_raw.rstrip()
            )
            surviving_text: str | None = surviving_text_stripped or None
            surviving_length_category = (
                compute_note_length_category(surviving_text)
                if surviving_category is SemanticCategory.NOTE
                else None
            )
            surviving_node = Node(
                id=node.id,
                category=surviving_category,
                children=node.children,
                page_index=node.page_index,
                block_indices=node.block_indices,
                text=surviving_text,
                level=node.level,
                summary_items=node.summary_items,
                toc_items=node.toc_items,
                length_category=surviving_length_category,
                apparatus_refs=node.apparatus_refs,
            )
            synthetic_ids: list[str] = []
            synthetic_nodes: list[Node] = []
            for k, t_start in enumerate(synthetic_transitions):
                t_end = (
                    synthetic_transitions[k + 1]
                    if k + 1 < len(synthetic_transitions)
                    else len(spans)
                )
                note_text = "".join(s.text for s in spans[t_start:t_end]).strip()
                if not note_text:
                    continue
                # Marker-less first synthetic chunk is only minted if
                # the text looks like running prose; otherwise it is a
                # front-matter small-caps fragment (Vol. I/II have
                # several such blocks) that should not be elevated to
                # a synthetic NOTE. Marker-bearing chunks bypass the
                # prose check because the leading ``(N)`` is enough
                # signal that a real note starts here.
                if (
                    k == 0
                    and not _NOTE_MARKER_PATTERN.match(note_text.lstrip())
                    and not ManualeGiappichelliProfile._looks_like_note_continuation(note_text)
                ):
                    continue
                synthetic_id = next_id.mint()
                synthetic_ids.append(synthetic_id)
                synthetic_nodes.append(
                    Node(
                        id=synthetic_id,
                        category=SemanticCategory.NOTE,
                        page_index=node.page_index,
                        block_indices=(block_index,),
                        text=note_text,
                        length_category=compute_note_length_category(note_text),
                    )
                )
                warnings.append(
                    f"{WARNING_PREFIX}:body_note_split_minted_node_"
                    f"{synthetic_id}_page_{node.page_index}"
                )
            if not synthetic_ids:
                # Every transition yielded empty text — leave the
                # original Node unchanged and skip the Transformation.
                result.append(node)
                continue
            result.append(surviving_node)
            result.extend(synthetic_nodes)
            # Record the split as a Transformation. The textual fields
            # encode the pre-step text loss; ``split_into`` carries the
            # structural side.
            pre_text = node.text
            if pre_text is not None:
                post_len = len(surviving_text) if surviving_text is not None else 0
                position = (post_len, len(pre_text))
                original = pre_text[post_len:]
                transformations.append(
                    Transformation(
                        step_id=SPLITTER_STEP_ID,
                        node_id=node.id,
                        page_index=node.page_index,
                        position=position,
                        original=original,
                        normalized="",
                        split_into=tuple(synthetic_ids),
                    )
                )
        return result

    @staticmethod
    def _is_glued_spans(spans: tuple[Span, ...]) -> bool:
        """Re-evaluate the glued predicate on the original block spans.

        Mirror of :meth:`_is_body_note_glued` but operates on the
        ``ExtractionResult.spans`` slice rather than on a ``_BlockView``,
        and on the **effective leading span** (skipping any leading
        whitespace fallback span) per :meth:`_effective_leading_span`.
        Used by :meth:`_split_body_note_glued` to confirm the structural
        condition on the source spans before splitting.
        """
        if len(spans) < 2:
            return False
        leading = ManualeGiappichelliProfile._effective_leading_span(spans)
        if leading is None:
            return False
        if not leading.font.startswith(BODY_FONT_PREFIX):
            return False
        if abs(leading.size - BODY_FONT_SIZE) > 0.1:
            return False
        note_spans = sum(
            1
            for span in spans
            if span.font.startswith(BODY_FONT_PREFIX)
            and any(abs(span.size - s) < 0.3 for s in NOTE_BODY_SIZES)
        )
        return (note_spans / len(spans)) >= BODY_NOTE_GLUED_RATIO_THRESHOLD

    @staticmethod
    def _find_note_transitions(spans: tuple[Span, ...]) -> list[int]:
        """Indices of spans that mark a new NOTE chunk inside a glued or
        multi-note block.

        A transition is one of:

        - a 9.0pt / 7.98pt SimonciniGaramondStd span whose lstripped
          text opens with the parenthesised ``(N)`` marker **and**
          which starts a new typographic line (``span.line_index``
          differs from the preceding 9pt span's line_index) — the
          regular start-of-new-note case. The line-index guard
          disambiguates this case from inline cross-reference markers
          that happen to land at the start of a wrapped line inside a
          previous note's text;
        - the first 9.0pt / 7.98pt SimonciniGaramondStd span of the
          block (in iteration order) when it lacks the ``(N)``
          marker — the marker-less continuation case where the first
          embedded note is the continuation of a footnote opened on
          the previous page. The post-processing step
          :func:`postprocessing.steps.merge_cross_page_notes.
          merge_cross_page_notes` then fuses the synthetic NOTE with
          the head NOTE on the previous page.

        Subsequent marker-less 9pt spans (occurring AFTER the first
        transition has been registered) are absorbed into the current
        NOTE chunk's text rather than treated as fresh transitions —
        they are mid-stream span breaks within a single footnote, not
        new notes. The "first 9pt run" rule therefore admits at most
        one marker-less transition per block, which mirrors the
        editorial reality (a single continuation per page).
        """
        transitions: list[int] = []
        prev_note_line_index = -1
        for i, span in enumerate(spans):
            if not any(abs(span.size - s) < 0.3 for s in NOTE_BODY_SIZES):
                continue
            if not span.font.startswith(BODY_FONT_PREFIX):
                continue
            if _NOTE_MARKER_PATTERN.match(span.text.lstrip()):
                # Two conjunctive guards prevent false positives from
                # inline cross-references that happen to be at the
                # start of a wrapped line:
                # (a) the span sits on a different line than the
                #     preceding 9pt span (``line_index`` differs);
                # (b) the span is the first of its line
                #     (``span_index == 0``), i.e. left-aligned with
                #     the note column's leftmost position rather than
                #     preceded by other text on the same line.
                if span.line_index != prev_note_line_index and span.span_index == 0:
                    transitions.append(i)
            elif not transitions:
                transitions.append(i)
            prev_note_line_index = span.line_index
        return transitions

    def _mint_cross_references(
        self,
        nodes: list[Node],
        warnings: list[str],
        next_id: NodeIdMinter,
    ) -> list[Node]:
        """Insert synthetic CROSS_REFERENCE nodes after BODY nodes with inline ``(N)``.

        For every BODY node, scan its text with
        :data:`_CROSSREF_INLINE_PATTERN` and mint one
        ``CROSS_REFERENCE`` ``Node`` per match as a sibling immediately
        after the BODY in the result list. The synthetic node's text is
        the digit substring (no parentheses), matching the convention
        the tier 1 cross-reference resolver expects when it parses
        ``CROSS_REF_DIGITS_REGEX``.
        """
        result: list[Node] = []
        for node in nodes:
            result.append(node)
            if node.category is not SemanticCategory.BODY:
                continue
            if node.text is None:
                continue
            for match in _CROSSREF_INLINE_PATTERN.finditer(node.text):
                digit = match.group(1)
                block_index = node.block_indices[0] if node.block_indices else -1
                crossref = Node(
                    id=next_id.mint(),
                    category=SemanticCategory.CROSS_REFERENCE,
                    page_index=node.page_index,
                    block_indices=(block_index,) if block_index >= 0 else (),
                    text=digit,
                )
                result.append(crossref)
                warnings.append(
                    f"{WARNING_PREFIX}:inline_cross_reference_minted_node_"
                    f"{crossref.id}_page_{crossref.page_index}"
                )
        return result

    # ------------------------------------------------------------------
    # Text parsing helpers

    @staticmethod
    def _parse_chapter_summary(text: str | None) -> tuple[SummaryItem, ...] | None:
        """Parse a CHAPTER_SUMMARY text into structured entries, or None.

        Strips the leading ``SOMMARIO:`` label (case-insensitive),
        splits on the en-dash separator, parses each segment with
        :data:`_SUMMARY_ITEM_PATTERN`. Returns ``None`` on any
        structural failure (empty text, unparseable segment, blank
        title after normalisation).
        """
        if text is None:
            return None
        stripped = text.strip()
        # The small-caps "SOMMARIO" label may be lower-cased or
        # upper-cased depending on whether the typesetter renders it
        # before or after typographic small-caps expansion. Accept any
        # case and the optional trailing colon.
        if stripped.lower().startswith("sommario"):
            stripped = stripped[len("sommario") :].lstrip()
            if stripped.startswith(":"):
                stripped = stripped[1:].lstrip()
        if not stripped:
            return None
        segments = _SUMMARY_SPLITTER.split(stripped)
        items: list[SummaryItem] = []
        for segment in segments:
            seg = segment.strip()
            if not seg:
                return None
            match = _SUMMARY_ITEM_PATTERN.match(seg)
            if match is None:
                return None
            title = _INTERNAL_WHITESPACE.sub(" ", match.group("title")).strip()
            # Mandrioli summary entries are written as
            # ``1. Alpha. <en-dash> 2. Beta.`` with a trailing dot at
            # the end of each entry; strip it so the parsed title is
            # uniform with the Tesauro convention (no trailing dot).
            title = title.rstrip(".").strip()
            if not title:
                return None
            items.append(SummaryItem(number=match.group("num"), title=title))
        if not items:
            return None
        return tuple(items)

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
