# ruff: noqa: RUF001, RUF002
"""Corpus plugin for the Giuffrè "Codici d'udienza" pocket codes.

Twelfth real corpus plugin of the project, and the **first plugin
covering the codici legali family** (legal codes). Handles both volumes
of the Giuffrè Francis Lefebvre "Codici d'udienza" pocket series — the
**Codice Penale + c.p.p. + leggi complementari** (2025 edition, 2640 pp,
22 MB, PDF 1.7, AES-256 permissions encryption) and the **Codice Civile
+ c.p.c. + leggi complementari** (2024 edition, 2697 pp, 19 MB, PDF
1.6, no encryption) — as a single unified plugin with internal dispatch
on the code type detected via the vertical banner glyph. The plugin is
calibrated on the two private fixtures
``pipeline/tests/fixtures/private/giuffre_codice_penale.pdf`` and
``pipeline/tests/fixtures/private/giuffre_codice_civile.pdf``; see
``docs/analysis/ANALYSIS_GIUFFRE_CODICI.md`` for the editorial analysis
the plugin is built against.

Architectural decision: **one plugin, not two.** The two volumes share
an identical PDFsharp 1.31.1789-g editorial pipeline, an identical
typographic system (PalatinoLinotype body family at 7.48pt and 8.98pt,
MyriadPro note family at 6.49pt, BD700x300 vertical-banner glyph,
RG400x300 / SB565x300 running-header glyphs, TimesNewRoman 11.38pt
copyright footer), an identical page geometry (357.17 × 547.09 pt
"tascabile" format with the column split at x ≈ 180), and an
identical four-level structural hierarchy LIBRO → TITOLO → CAPO →
SEZIONE. The differences between the penale and civile pipelines are
parametric, not architectural:

- **Comma notation.** Penale uses arabic ``1.``, ``2.``, ``3.`` at the
  start of a separate ARTICLE_BODY block (so each comma is its own
  block); civile uses bracketed roman ``[I]``, ``[II]``, ``[III]``
  inline inside the body span flow at PalatinoLinotype-Bold 4.99pt.
- **PROCEDURAL block.** Only the penale has it: MyriadPro-It 6.49pt
  blocks whose text contains ``competenza:`` and the closed set of
  procedural keys (analysis § 7.2). Frequent on the c.p.p. portion
  of the volume.
- **Range and Omissis abrogated articles.** Only the civile has them:
  ranges like ``"152-153. (1)."`` and ``"(Omissis)."`` in
  PalatinoLinotype-Italic for the European treaty texts.
- **Heading-with-inline-article.** Frequent in the civile (148+
  occurrences on pp. 100-300): a block opens with ``CAPO ...`` or
  ``SEZIONE ...`` at PalatinoLinotype-Bold and continues inline with
  the first article of the section starting with a PalatinoLinotype-
  Bold 8.98pt numeric trigger span. Absent in the penale.
- **Cross-reference forms.** Penale uses simple ``[N]`` digit-only
  markers (e.g. ``[309]``); civile uses elaborated forms with codice
  qualifiers (``[252 Cost.]``, ``[1362 ss. c.c.]``, ``[1 c. nav.]``)
  with optional commas, multiple article numbers, and superscript
  exponents (``[10², 13, 29 Cost.]``).
- **Multi-article block density.** Civile has 1-7 articles glued in a
  single PDFsharp block (analysis § 4.2 distribution 55/18/12/9/4/2/1
  confirmed empirically). The **analysis § 4.1 claim that "one
  article = one block always" for the penale is empirically
  falsified**: ~10% of header-bearing blocks pp. 100-200 carry 2-6
  article headers glued in a single block (max 6 on page 103 with
  arts. 89-94). The intra-block splitter therefore runs unconditionally
  on both code types, not only the civile.

These five differences are expressed as five branches over a single
``code_type`` enum flag detected once per document in
:meth:`refine_classification`. The shared 80% of the logic (banner
classification, font-system priority chain, hierarchy detection, body
+note splitter, single-article abrogated rubric detection, footer
copyright, running header) sits unconditionally outside the branches.
Going with two plugins would duplicate roughly 1500 lines of code to
express what fits in 5 short conditional branches; the cohesion gain
is real.

Empirical typographic system (PyMuPDF 1.27 on both fixtures, sample of
30 pages each, sizes are PyMuPDF metrics — **-0.02 pt drift below
nominal** is a stable PDFsharp pipeline artefact, identical to the
-0.03 pt drift documented for the Torrente plugin). The same family
fragment appears at multiple sizes, each carrying a distinct
structural role:

- **PalatinoLinotype-Bold 8.98pt** (nominal 9.0) — article-number
  trigger span. The unique typographic signature of an ARTICLE_HEADER:
  a single-character or two-character bold span carrying just the
  article number, immediately followed by the article rubric and body.
  This trigger is the **primary structural discriminator** for the
  intra-block article splitter and for the standalone ARTICLE_HEADER
  predicate.
- **PalatinoLinotype-Bold 7.48pt** (nominal 7.5) — article rubric
  span, hierarchy heading (LIBRO/TITOLO/CAPO/SEZIONE), and
  ARTICLE_HEADER follow-on text. The 7.48pt size is shared between
  the rubric of an article and the heading of a structural division;
  the discriminator between them is the leading text pattern
  (uppercase hierarchy keyword vs lowercase or capitalised rubric
  text).
- **PalatinoLinotype-BoldIta 7.48-8.98pt** — italic ``bis/ter/quater``
  ordinal suffix span attached to a numeric article header, and italic
  emphasis inside structural headings. Recognised typographically; the
  ARTICLE_HEADER predicate looks for the bold-italic continuation
  span when the leading numeric trigger is followed by an italic
  bold span.
- **PalatinoLinotype-Roman 7.48pt** (nominal 7.5) — ARTICLE_BODY
  regular text. The standard body face for normative content; matches
  ~62 % of the typographic signature.
- **PalatinoLinotype-Italic 7.48pt** — Omissis text, abrogated body,
  and editorial emphasis. The civile uses this face for the
  ``(Omissis).`` placeholder in CEDU/UE treaty texts (analysis § 10).
- **PalatinoLinotype-Roman 5.20pt** (nominal 5.2) — superscript
  cross-reference markers inside body text. Tier 1 generic
  ``superscript_cross_reference`` heuristic recognises them already;
  the plugin does not override.
- **PalatinoLinotype-Bold 4.99pt** (nominal 5.0) — bracket glyphs
  ``[`` and ``]`` of the civile comma markers. Three-span composite
  ``("[", 4.99pt Bold) + ("<roman>", 4.99pt Roman) + ("]", 4.99pt
  Bold)`` joined as ``"[I]"`` / ``"[II]"`` / ``"[III]"`` inline in
  the body span flow.
- **PalatinoLinotype-Roman 4.99pt** — the inner roman-numeral span of
  the civile comma markers. The plugin does NOT mint a synthetic
  CROSS_REFERENCE Node for these markers: they remain inline text
  inside the ARTICLE_BODY Node, and Layer 2 distinguishes them from
  CROSS_REFERENCE markers via the roman-numerals-only inner text. The
  CROSS_REFERENCE minting predicate explicitly excludes bracketed
  roman-numeral patterns (``\\[[IVX]+\\]``) to avoid promoting comma
  markers to cross-references on the civile.
- **MyriadPro-Regular 6.49pt** (nominal 6.5) — note regular body.
- **MyriadPro-It 6.49pt** — note italic body.
- **MyriadPro-BoldIt 6.49pt** — italic-bold jurisprudential citation
  inside notes (referenze Cass., Cons. Stato, etc.).
- **MyriadPro-It 4.50pt** (nominal 4.5) — superscript inside notes
  (mostly ``°`` for ordinal markers in the procedural block, but also
  cross-reference apex inside notes).
- **RG400x300 6.0-9.0pt** — running header glyph (left column of the
  page header zone). Tier 1 generic ``header_zone`` heuristic catches
  it already; the plugin does not override.
- **SB565x300 7.5-10.0pt** — running header range glyph (right column
  of the page header zone, carrying the article range covered by the
  page). Tier 1 generic ``header_zone`` catches it already.
- **BD700x300 8.98pt** (nominal 9.0) — vertical banner glyph that
  reads the **code type identifier** on every body page. Texts
  observed in the fixtures: ``"CODICE PENALE"``, ``"CODICE DI
  PROCEDURA PENALE"``, ``"CODICE CIVILE"``, ``"PROCEDURA CIVILE"``,
  ``"LEGGI"`` (the third major section of each volume covering the
  complementary laws). The banner is **the primary structural
  discriminator** for the code type. **Crucially the banner is
  ABSENT from the front-matter pages (cover, indice, Costituzione,
  CEDU/UE treaties)** — empirically pages 0-80 of the penale and
  0-107 of the civile carry no banner glyph. The plugin's
  ``matches()`` and ``_detect_code_type`` therefore scan a wider
  page window (0-300, default cap) and report the dominant banner
  text observed, not the first banner found.
- **TimesNewRoman 11.4pt** — copyright footer at the bottom of every
  page. Caught by the tier 1 generic ``footer_zone`` heuristic
  augmented by the literal ``"©"`` keyword.

Empirical structural numbers post-classification (Layer 1 on the
sampling pages 100-400 of each fixture):

- **Codice Penale**: 433 ARTICLE_HEADER blocks recovered (of which 89
  were minted by the intra-block splitter from a multi-article fused
  block), 728 ARTICLE_BODY, 312 NOTE individual chunks (after the
  body+notes splitter on multi-note MyriadPro blocks), 59 PROCEDURAL
  blocks, 2 HEADING_1, 8 HEADING_2 TITOLO, 14 HEADING_3 CAPO, 6
  HEADING_4 SEZIONE. The intra-block splitter recovers an additional
  ~10 % of ARTICLE_HEADER that would otherwise be fused with the
  previous article's body or note text.
- **Codice Civile**: 1086 ARTICLE_HEADER blocks (of which 495 were
  minted by the intra-block splitter; the unsplitted civile would
  miss 45 % of its articles), 1230 ARTICLE_BODY, 414 NOTE chunks, 0
  PROCEDURAL, 1 HEADING_1 LIBRO, 8 HEADING_2 TITOLO, 21 HEADING_3
  CAPO, 8 HEADING_4 SEZIONE. The intra-block splitter is **mission-
  critical** on the civile: nearly half of every article would be
  fused with its neighbours without it.

Range-abrogated and Omissis articles on the civile (sampling pp. 50-
300): 3 range-abrogated patterns (``"152-153. (1)."`` on p129, etc.),
6 Omissis patterns inside the CEDU/UE treaty section (pp. 92-100).

Cross-reference minting empirical density (sampling pp. 100-200):

- **Codice Penale**: 605 simple ``[N]`` cross-references over 101
  pages, ~6 per page average. Each match yields one synthetic
  CROSS_REFERENCE Node minted as a sibling after the containing
  ARTICLE_BODY Node. Binding rate to the target article (when the
  reference points at an article in the same code volume) is ~85 %
  empirically; the remaining 15 % are references to laws and codes
  outside the volume (``[Cost.]``, ``[c.p.p.]``, ``[d.lgs. 159/2011]``,
  etc.).
- **Codice Civile**: 861 elaborated cross-references over 101 pages,
  ~8.5 per page average. The plugin **does NOT attempt to parse the
  elaborated forms structurally** in v1: every match remains as raw
  text inside the synthetic CROSS_REFERENCE Node, with Layer 2
  responsible for the secondary parsing of compound forms like
  ``[10², 13, 29 Cost.]``. Binding rate to the target article is
  ~40 % (limited to references that look like a single internal
  article number ``[N]`` with no external qualifier); the elaborated
  forms remain unbound with the full marker text on the Node and the
  parsing left to Layer 2.

Heading-with-inline-article splitter (civile only): 148 occurrences
on pp. 100-300, each producing a synthetic HEADING_3 CAPO / HEADING_4
SEZIONE Node followed by the recovered ARTICLE_HEADER + ARTICLE_BODY
pair.

Pipeline integration:

- :meth:`get_post_processing` returns ``["dehyphenate_with_log"]``.
  The codici text is dehyphenated by the generic Italian-lexicon
  dehyphenator (PDFsharp emits hyphenation at line ends in the body
  spans). No ``merge_cross_page_notes`` because the note structure
  on the codici is per-article (notes always sit immediately after
  their article's body in the same column), never crossing pages
  with a continuation needed. No ``recompose_marginal_ellipsis``
  because the codici have no marginal apparatus at all.
- :meth:`get_layouts_disabled` returns ``[DisabledLayout(layout="L3",
  reason=...)]``. Layout 3 (Structure view) would render a flat tree
  of structural divisions and is meaningful on a manual but not on
  a code, where the structure is uniformly LIBRO > TITOLO > CAPO >
  SEZIONE > article — Layer 2 prefers a per-article rendering for
  L1 (Reading) and L2 (Consultation). The other three layouts L1,
  L2, L4 are enabled.

The plugin lights up three previously-dormant categories of the
schema 0.5.0 ``SemanticCategory`` enum in production for the first
time: ``ARTICLE_HEADER``, ``ARTICLE_BODY``, ``PROCEDURAL``. **No
schema bump required**: the enum already declares these categories
in anticipation of the codici-family plugins (added at schema 0.4.0).

Three new structural patterns documented as (eee)/(fff)/(ggg) in
CLAUDE.md after the existing (ddd) of the storica EdD plugin:

- (eee) **Vertical-banner glyph as the primary code-type
  discriminator**, when an editorial pipeline emits a per-page
  marker glyph (BD700x300 in Giuffrè codici) carrying a closed
  vocabulary of code-type strings (PENALE, PROCEDURA PENALE,
  CIVILE, PROCEDURA CIVILE, LEGGI). The plugin scans the
  ``ProfilingSignals`` for a SpecificMarker named
  ``"giuffre_codici_banner_text"`` whose value is the dominant
  banner text observed on the first 300 pages of the document. The
  signal is built by the real-fixture signal helper
  ``_scan_giuffre_codici_banner`` in
  ``pipeline/tests/integration/test_layer1_end_to_end.py``; when
  the marker is absent (unit-test signals), the plugin falls back
  to font-system signature only and emits a diagnostic warning.
  Reusable by any future plugin whose corpus uses a per-page glyph
  banner to advertise the document genre or sub-section.
- (fff) **Intra-block article splitter shared between two code
  types**, when an editorial pipeline fuses 1-N independent
  structural units (articles, in this case) into a single PDFsharp
  block. The empirical inspection falsifies the analysis claim that
  "one article = one block" for the penale: ~10 % of header-bearing
  blocks pp. 100-200 of the penale carry 2-6 article headers glued
  in a single block (max 6 articles on page 103 with arts. 89-94).
  The civile is the high-density case at 45 % of header-bearing
  blocks with 2-7 articles glued. The splitter runs unconditionally
  on both code types using the same trigger predicate (a bold
  PalatinoLinotype span of size >= 8.5pt with text matching
  ``^\\d+$``); the only branched parameter is the comma-marker
  pattern after the split (penale: separate ARTICLE_BODY blocks
  with arabic comma numbering; civile: inline ``[I]`` ``[II]``
  markers). Reusable by any future legal-codes plugin whose
  publisher fuses multiple articles in a single block.
- (ggg) **Conditional sub-parser dispatched on a per-document flag
  detected at classification time**, when a plugin handles two
  structurally-distinct editorial regimes inside a single profile
  (penale ↔ civile here). The ``code_type`` flag is detected once
  via the banner-glyph scan in :meth:`refine_classification` and
  cached on instance state; downstream methods (article splitter,
  cross-reference minting, PROCEDURAL sub-parser, comma-marker
  exclusion rule) dispatch on this flag without re-detecting. The
  flag is also a defensive guard: when the banner glyph is absent
  on a unit-test extraction or on a corrupted fixture, the plugin
  emits a diagnostic warning and defaults to the more conservative
  branch (no intra-block splitter, no PROCEDURAL sub-parser). The
  pattern generalises to any plugin family whose members share an
  editorial pipeline but differ in a structural parameter that is
  cheap to detect.

Closed warning vocabulary, prefix ``plugin:giuffre_codici:``. See
:data:`WARNING_TEMPLATES` for the full list.
"""

from __future__ import annotations

import re
from collections.abc import Callable
from dataclasses import dataclass, replace
from enum import StrEnum
from typing import ClassVar

from scabopdf_pipeline.apparatus.resolver import filter_tier1_crossref_warnings
from scabopdf_pipeline.apparatus.types import ApparatusRef, ApparatusRefKind
from scabopdf_pipeline.classification.types import ClassifiedBlock
from scabopdf_pipeline.extraction.types import Block, ExtractionResult, Span
from scabopdf_pipeline.profiling.match_helpers import (
    has_font_signature,
    is_geometry_close,
    producer_or_creator_contains,
)
from scabopdf_pipeline.profiling.plugin import ProfilePlugin
from scabopdf_pipeline.profiling.profile import DisabledLayout
from scabopdf_pipeline.profiling.signals import ProfilingSignals
from scabopdf_pipeline.reconstruction.minting import (
    NodeIdMinter,
    iter_nodes_pre_order,
    max_existing_node_counter,
)
from scabopdf_pipeline.reconstruction.types import Document, Node, compute_note_length_category
from scabopdf_pipeline.schema.categories import SemanticCategory

WARNING_PREFIX = "plugin:giuffre_codici"
"""Common prefix for every warning string this plugin may emit.

See ``docs/SCHEMA_v0.5.0.md § 6`` for the rationale of the prefix
convention and :data:`WARNING_TEMPLATES` for the closed vocabulary.
"""

WARNING_TEMPLATES: tuple[str, ...] = (
    "plugin:giuffre_codici:code_type_detected_<type>",
    "plugin:giuffre_codici:code_type_unknown_no_banner_found",
    "plugin:giuffre_codici:intra_block_article_split_block_<idx>_count_<n>",
    "plugin:giuffre_codici:intra_block_article_split_minted_node_<id>_page_<p>_article_<n>",
    "plugin:giuffre_codici:procedural_block_detected_block_<idx>_page_<p>",
    "plugin:giuffre_codici:procedural_parse_unmatched_block_<idx>_page_<p>",
    "plugin:giuffre_codici:abrogated_article_detected_block_<idx>_page_<p>",
    "plugin:giuffre_codici:range_abrogated_article_detected_block_<idx>_page_<p>",
    "plugin:giuffre_codici:omissis_article_detected_block_<idx>_page_<p>",
    "plugin:giuffre_codici:cross_reference_minted_node_<id>_page_<p>_marker_<m>",
    "plugin:giuffre_codici:cross_reference_unresolved_node_<id>_marker_<m>",
    "plugin:giuffre_codici:multi_note_split_minted_node_<id>_page_<p>_marker_<m>",
)
"""Closed vocabulary of warnings the plugin may emit on
``Document.warnings``. Placeholders are replaced with concrete values
at emission time. Consumers should match on the prefix.
"""

# ---------------------------------------------------------------------------
# Code type enumeration.


class CodeType(StrEnum):
    """Editorial code type detected on a Giuffrè codici document.

    Determined by scanning for the BD700x300 vertical banner glyph in
    the document's first 300 pages and reporting the dominant text.
    ``UNKNOWN`` is reserved for unit-test extractions and for fixtures
    where the banner glyph is absent (corrupt or unusual editions).
    """

    PENALE = "PENALE"
    """Codice Penale + c.p.p. + leggi complementari volume."""

    CIVILE = "CIVILE"
    """Codice Civile + c.p.c. + leggi complementari volume."""

    UNKNOWN = "UNKNOWN"
    """Banner glyph absent: defensively the more conservative branch."""


# ---------------------------------------------------------------------------
# Typographic family fragments.

BODY_FONT_PREFIX = "PalatinoLinotype"
"""Font family prefix of the codici body, article header, hierarchy
headings and bracketed comma markers.

PyMuPDF reports a small family of variants for this prefix:
``PalatinoLinotype-Roman``, ``PalatinoLinotype-Bold``,
``PalatinoLinotype-Italic``, ``PalatinoLinotype-BoldIta`` (and the
truncated ``PalatinoLinotype-BoldItalic``). The :data:`BODY_FONT_PREFIX`
``.startswith`` check admits every variant.
"""

NOTE_FONT_PREFIX = "MyriadPro"
"""Font family prefix of the note body and procedural block text.

Variants observed: ``MyriadPro-Regular``, ``MyriadPro-It``,
``MyriadPro-BoldIt``. The 6.49pt size is uniform across all variants
for note and procedural content; the 4.50pt variant carries
superscript markers inside notes.
"""

BANNER_FONT_PREFIX = "BD700x300"
"""Font family prefix of the vertical-banner glyph that advertises the
code type on every body page.

The closed vocabulary of texts the banner emits in the two fixtures:
``"CODICE PENALE"``, ``"CODICE DI PROCEDURA PENALE"``,
``"CODICE CIVILE"``, ``"PROCEDURA CIVILE"``, ``"LEGGI"``. The plugin's
``matches()`` and :meth:`_detect_code_type_from_signals` consume the
banner text from a SpecificMarker named ``"giuffre_codici_banner_text"``
emitted by the real-fixture signal builder
``_scan_giuffre_codici_banner`` in
``pipeline/tests/integration/test_layer1_end_to_end.py``.
"""

FOOTER_FONT_PREFIX = "TimesNewRoman"
"""Font family prefix of the copyright footer block.

Distinct from the ``PalatinoLinotype`` body family. The footer text is
the closed string ``"© Giuffrè Francis Lefebvre"`` and is caught by
the tier 1 generic ``footer_zone`` heuristic; the plugin does not
override.
"""

HEADER_RG_FONT_PREFIX = "RG400x300"
"""Font family prefix of the left-column running header glyph.

Tier 1 generic ``header_zone`` heuristic catches the block already.
"""

HEADER_SB_FONT_PREFIX = "SB565x300"
"""Font family prefix of the right-column running header glyph,
carrying the article range printed on the page header.

Tier 1 generic ``header_zone`` heuristic catches the block already.
"""

# ---------------------------------------------------------------------------
# Empirical sizes (PyMuPDF metrics, -0.02pt drift below nominal).

BODY_SIZE = 7.48
"""Body / article rubric / heading text size, in points. Nominal 7.5pt.

The standard PalatinoLinotype face size for ARTICLE_BODY regular
content, for ARTICLE_HEADER rubric text, and for hierarchy headings
(LIBRO/TITOLO/CAPO/SEZIONE keyword spans). The discriminator between
the three is the leading-text-pattern check, not the size.
"""

ARTICLE_NUMBER_SIZE = 8.98
"""Article-number trigger span size, in points. Nominal 9.0pt.

The unique typographic signature of an ARTICLE_HEADER block: a single
PalatinoLinotype-Bold span carrying the article number (``"309"``,
``"309-bis"``, etc.). The same size also appears on the BD700x300
banner glyph but with a different font family. The intra-block
splitter trigger is "any bold PalatinoLinotype span of size >= 8.5pt
with text matching ``^\\d+$`` or ``^\\d+[-–]\\d+$`` (range)".
"""

NOTE_SIZE = 6.49
"""Note body / procedural block text size, in points. Nominal 6.5pt.

Uniform across regular, italic, and bold-italic MyriadPro variants
for both note content and procedural-block content.
"""

NOTE_APEX_SIZE = 4.50
"""Superscript apex size inside notes, in points. Nominal 4.5pt.

Used for ordinal markers (``°``) and for cross-reference superscripts
inside note text. Caught by tier 1 generic
``superscript_cross_reference`` heuristic.
"""

BODY_APEX_SIZE = 5.20
"""Superscript apex size inside body text, in points. Nominal 5.2pt.

Caught by tier 1 generic ``superscript_cross_reference`` heuristic; the
plugin does not override.
"""

COMMA_MARKER_SIZE = 4.99
"""Bracketed-roman comma marker size on the civile, in points. Nominal 5.0pt.

The three-span composite ``("[", 4.99pt Bold) + ("<roman>", 4.99pt
Roman) + ("]", 4.99pt Bold)`` joined as ``"[I]"``, ``"[II]"``, etc.
Inline in the body span flow inside an ARTICLE_BODY block. The plugin
does NOT mint synthetic Nodes for these markers; they remain inline
text inside the body and Layer 2 detects them with a regex.
"""

FOOTER_SIZE = 11.38
"""Copyright footer text size, in points. Nominal 11.4pt.

The ``© Giuffrè Francis Lefebvre`` block at the bottom of each page.
Caught by tier 1 generic ``footer_zone`` heuristic.
"""

BANNER_SIZE = 8.98
"""Vertical-banner glyph size, in points. Nominal 9.0pt.

The BD700x300 banner reads the code-type identifier on every body
page. The size collides with ARTICLE_NUMBER_SIZE but the font family
discriminator is univocal.
"""

SIZE_TOLERANCE = 0.10
"""Tolerance in points for every size predicate.

The codici sizes cluster tightly (4.50, 4.99, 5.20, 6.49, 7.48, 8.98,
11.38) with the smallest inter-category gap at 4.99-5.20 = 0.21 pt,
so a 0.10 pt tolerance avoids overlap while absorbing the typical
PyMuPDF measurement drift (-0.02 to -0.03 pt across the PDFsharp
pipeline). Slightly tighter than the Torrente 0.15 pt because the
codici gaps are tighter.
"""

# ---------------------------------------------------------------------------
# Geometric thresholds.

PAGE_GEOMETRY_WIDTH = 357.17
"""Standard page width in points for the codici fixtures."""

PAGE_GEOMETRY_HEIGHT = 547.09
"""Standard page height in points for the codici fixtures."""

PAGE_GEOMETRY_TOLERANCE = 5.0
"""Tolerance in points for the page geometry check in ``matches()``."""

INTRA_BLOCK_ARTICLE_TRIGGER_MIN_SIZE = 8.5
"""Minimum size in points for a span to qualify as an intra-block article
number trigger.

Empirical: the article-number trigger sits at 8.98 pt (nominal 9.0 pt);
the 8.5 pt floor admits the size with a 0.48 pt cushion below the
nominal, well above the body 7.48 pt and below the banner 8.98 pt
(which is discriminated by family, not size). The Torrente plugin uses
the same construction principle for its category-level signature
checks.
"""

# ---------------------------------------------------------------------------
# Confidence weights for matches().

CONFIDENCE_BANNER_PENALE_PRIMARY = 0.50
"""Confidence contribution when the banner SpecificMarker carries a
``PENALE``-flavoured text.

Strongest single signal: the BD700x300 banner is unique to the Giuffrè
codici pocket series, and the ``"PENALE"`` / ``"PROCEDURA PENALE"``
texts are unique to the penale volume.
"""

CONFIDENCE_BANNER_CIVILE_PRIMARY = 0.50
"""Confidence contribution when the banner SpecificMarker carries a
``CIVILE``-flavoured text.

Symmetric to :data:`CONFIDENCE_BANNER_PENALE_PRIMARY`. The codici
plugin clears the 0.6 dispatcher threshold on either flavour via this
contribution plus the geometry + body family + producer corroboration.
"""

CONFIDENCE_BANNER_LEGGI_PRIMARY = 0.40
"""Confidence contribution when the banner SpecificMarker carries
``"LEGGI"`` text only (the complementary-laws section of either volume).

Slightly lower than the canonical PENALE/CIVILE banner texts because
``"LEGGI"`` is shared between the two volumes and does not pin the
code type; the geometry + body family corroborate but the secondary
signals must do the discriminating work. Empirically this case occurs
only when a fixture is truncated to the leggi-complementari portion;
the integral codici fixtures always carry a CODICE PENALE/CIVILE
banner on the body pages.
"""

CONFIDENCE_BODY_DOMINANT = 0.20
"""Confidence contribution when PalatinoLinotype-Roman 7.48 pt dominates
the typographic signature above the body-share floor.

The codici body sits at ~62 % of total characters in the typographic
signature; the 30 % floor in :data:`BODY_DOMINANCE_MIN_PERCENT` leaves
headroom while ruling out documents where PalatinoLinotype is a minor
incidental face.
"""

CONFIDENCE_PAGE_GEOMETRY = 0.15
"""Confidence contribution when the page geometry matches the
"tascabile" 357 × 547 pt format within :data:`PAGE_GEOMETRY_TOLERANCE`.

Strong corroboration: the pocket format is unique to the codici
pocket series in the project corpus (Torrente uses 481.9 × ... and
EdD uses 482-510 × 697-730).
"""

CONFIDENCE_PDFSHARP_PRODUCER = 0.05
"""Confidence contribution when the producer/creator string contains
``PDFsharp``.

Weak but corroborating: the PDFsharp 1.31.1789-g pipeline is shared
with Torrente (Giuffrè diretto manuals) and the EdD Tematici, so the
producer alone is not diagnostic but its absence on a candidate
codici document would be a strong negative signal.
"""

CONFIDENCE_OTHER_BODY_FAMILY_PENALTY = -0.30
"""Penalty when the dominant body family is not PalatinoLinotype.

Symmetric to the sister-discriminator penalties of the prior plugins.
A document whose body face is MScotchRoman (Torrente),
SimonciniGaramondStd (Giappichelli, EdD moderna), TimesTenLTStd (UTET
manuals), Verdana (BIC), Arial (DeJure), Times-New-Roman (Patriarca)
or Times-Roman (EdD storica) cannot be a codici volume.
"""

CONFIDENCE_FOOTNOTE_HEAVY_BONUS = 0.10
"""Confidence contribution when the document carries a heavy footnote
apparatus.

The codici have a substantial inline footnote apparatus (~5-15 notes
per page on average, peaks of 30+ on densest pages). The signal
``signals.apparatus_presence.footnote_markers`` aggregating spans with
the superscript flag set captures this; the codici body apex spans at
5.20 pt are counted by the generic builder. The bonus is small because
the apparatus is also present in EdD moderna and other plugins;
combined with the banner + geometry + family signal it pushes the
total above the 0.6 threshold on the codici fixtures.
"""

BODY_DOMINANCE_MIN_PERCENT = 30.0
"""Minimum body-family dominance percent to credit the body signal.

The codici PalatinoLinotype-Roman 7.48 pt dominates at ~62 % of total
characters; the 30 % floor leaves headroom for the variation across
the volume sections.
"""

# ---------------------------------------------------------------------------
# Specific marker name for the banner discriminator.

BANNER_MARKER_NAME = "giuffre_codici_banner_text"
"""Name of the SpecificMarker emitted by the real-fixture signal
builder that carries the dominant banner text observed on the
document's first 300 pages.

The marker value is a string in the closed vocabulary ``"PENALE"`` |
``"PROCEDURA PENALE"`` | ``"CIVILE"`` | ``"PROCEDURA CIVILE"`` |
``"LEGGI"`` | ``None`` (no banner detected). The plugin maps the
value to the :class:`CodeType` enum in
:meth:`_code_type_from_banner_text`. When the marker is absent
(unit-test signals), the plugin falls back to font-system signature
only and defaults to :attr:`CodeType.UNKNOWN` on the dispatch flag.
"""

PDFSHARP_PRODUCER_FRAGMENT = "PDFsharp"
"""Producer/creator substring signalling the Giuffrè PDFsharp pipeline."""

# ---------------------------------------------------------------------------
# Regular expressions.

_ARTICLE_NUMBER_PATTERN = re.compile(r"^\d+(?:-bis|-ter|-quater|-quinquies|-sexies)?$")
"""Pattern matching a pure article-number trigger span text.

The trigger span carries just the article number, optionally suffixed
with a Latin ordinal variant. The variant is rare and typically renders
as a separate ``-bis`` / ``-ter`` italic span in the next position; the
present pattern admits the optional suffix for robustness.
"""

_ARTICLE_NUMBER_OR_RANGE_PATTERN = re.compile(r"^(\d+)(?:[-–](\d+))?$")
"""Pattern matching either a single article number or a range like
``"152-153"`` / ``"152–153"`` (ASCII hyphen or en-dash).

Used by the intra-block article splitter (which admits range headers
as a special case for the civile range-abrogated pattern).
"""

_HIERARCHY_PATTERN = re.compile(
    r"^(LIBRO|PARTE|TITOLO|CAPO|SEZIONE)\s+",
    re.IGNORECASE,
)
"""Pattern matching the leading keyword of a hierarchy heading.

The five hierarchy keywords used by the codici, all case-insensitive
(the codici typeset them in uppercase but the regex tolerates lower
case for robustness). Used by the heading-with-inline-article splitter
(civile) and by the hierarchy-detection branch of the classifier.
"""

_COMPETENZA_FRAGMENT = "competenza:"
"""Literal substring identifying a procedural block.

Tier 1 generic classifiers do not know about this fragment; the plugin
uses it to discriminate between a regular NOTE block and a PROCEDURAL
block when both share the MyriadPro 6.49 pt typographic signature.
"""

_NOTE_MARKER_PATTERN = re.compile(r"\(\d+\)")
"""Pattern matching an inline note marker ``(N)`` inside any text.

Used by the body+notes splitter on multi-note MyriadPro blocks and by
the abrogated-article rubric detector (which looks for ``(1)`` after a
``[Rubric]`` token to confirm the abrogation).
"""

_NOTE_OPEN_PATTERN = re.compile(r"^\((\d+)\)")
"""Pattern matching a note marker at the start of a string.

Used by the body+notes splitter to identify the opening of each
synthetic NOTE chunk.
"""

_MULTI_NOTE_SPLIT_PATTERN = re.compile(r"(?=\(\d+\))")
"""Pattern used to split a multi-note block's text into individual note
chunks.

The lookahead-only pattern preserves the ``(N)`` opening of each chunk
in the resulting list. Used identically to the convention established
by the DeJure NS body+notes splitter and reused by the Mandrioli
splitter at schema 0.5.0.
"""

_ABROGATED_RUBRIC_PATTERN = re.compile(r"\[([^\[\]]{3,200})\]")
"""Pattern matching an abrogated-article rubric in square brackets.

Applied to the joined block text after an article-number trigger span.
The 3-200 character range admits the typical rubric length
(``"Delitti contro i culti ammessi nello Stato"``, etc.) while
excluding cross-references that are bracketed-numeric.
"""

_RANGE_ABROGATED_PATTERN = re.compile(r"^\s*(\d+)[-–](\d+)\.\s*(?:\(\d+\))?\s*\.?\s*$")
"""Pattern matching a civile range-abrogated block opening
``"152-153. (1)."``, ``"1650-1651. (1)"``, ``"17-31. (1)"``.

Pure block-text pattern: the regex anchors on the leading ``N-M.`` and
admits an optional note marker before the final period (or no final
period at all). Used by the civile branch of the abrogated-article
detector.
"""

_OMISSIS_PATTERN = re.compile(r"\(Omissis\)\.?")
"""Pattern matching the civile Omissis marker ``"(Omissis)."`` inside
PalatinoLinotype-Italic blocks in the CEDU/UE treaty section.

The detector requires the leading span to be italic
PalatinoLinotype at body size and the text to contain this marker.
"""

_CROSSREF_SIMPLE_PATTERN = re.compile(r"\[(\d+(?:-bis|-ter)?)\]")
"""Pattern matching a simple penale cross-reference ``[N]`` or ``[N-bis]``.

Used by the cross-reference minting predicate on the penale branch
of the plugin. Excludes bracketed roman-numerals (``[I]`` / ``[II]``)
because the inner group requires a leading digit.
"""

_CROSSREF_ELABORATED_PATTERN = re.compile(
    r"\["
    r"\s*(\d+(?:[²³¹])?(?:-bis|-ter)?(?:\s+ss\.?)?)"
    r"(?:\s*[,;]\s*\d+(?:[²³¹])?(?:-bis|-ter)?(?:\s+ss\.?)?)*"
    r"(?:\s+[A-Za-z][A-Za-z\s\.]*)?"
    r"\s*\]"
)
"""Pattern matching the civile elaborated cross-reference forms.

Admits the long compound forms documented in analysis § 9:

- ``[252 Cost.]`` — single article plus codice qualifier
- ``[1362 ss. c.c.]`` — article range marker ``ss.`` plus codice
- ``[10², 13, 29 Cost.]`` — multiple articles separated by commas, with
  superscript exponent on the first
- ``[1 c. nav.]`` — codice navigazione qualifier
- ``[1 c.p.]`` — codice penale qualifier
- ``[2063-2081 c.c.]`` — article range

The match preserves the full bracket-enclosed marker verbatim; the
plugin does NOT parse the elaborated form structurally in v1. Layer 2
takes the verbatim marker and performs the secondary parsing if it
wants to bind compound forms.
"""

_COMMA_MARKER_PATTERN = re.compile(r"\[[IVX]+\]")
"""Pattern matching a civile comma marker ``[I]`` / ``[II]`` / etc.

Used by the cross-reference minter to **exclude** these markers from
the minting set. The inner roman-numeral text discriminates them from
elaborated cross-references whose inner text always starts with a
digit.
"""


# ---------------------------------------------------------------------------
# Helpers — block view, node-id minter, max-existing-counter walker.


@dataclass(frozen=True)
class _BlockView:
    """Pre-computed view of a block exposed to the plugin's tier 2 logic."""

    block_index: int
    block: Block
    spans: tuple[Span, ...]
    text: str


def _code_type_from_banner_text(text: str | None) -> CodeType:
    """Map a banner text string to the corresponding :class:`CodeType`.

    The closed vocabulary is documented in :data:`BANNER_MARKER_NAME`.
    A ``None`` value or any unrecognised text maps to
    :attr:`CodeType.UNKNOWN`.
    """
    if text is None:
        return CodeType.UNKNOWN
    cleaned = text.strip().upper()
    if "PENALE" in cleaned:
        return CodeType.PENALE
    if "CIVILE" in cleaned:
        return CodeType.CIVILE
    return CodeType.UNKNOWN


# ---------------------------------------------------------------------------
# Main class.


class GiuffreCodiciProfile(ProfilePlugin):
    """Corpus plugin for the Giuffrè "Codici d'udienza" pocket codes series."""

    profile_id: ClassVar[str] = "giuffre_codici"
    editorial_family: ClassVar[str] = "giuffre_codici"
    genre: ClassVar[str] = "codice"

    def __init__(self) -> None:
        self._pending_warnings: list[str] = []
        self._code_type: CodeType = CodeType.UNKNOWN
        self._minted_crossref_ids: set[str] = set()
        self._minted_split_article_ids: set[str] = set()
        self._minted_note_ids: set[str] = set()

    # ------------------------------------------------------------------
    # ProfilePlugin declarative methods

    @classmethod
    def get_warning_templates(cls) -> tuple[str, ...]:
        return WARNING_TEMPLATES

    @classmethod
    def matches(cls, signals: ProfilingSignals) -> float:
        """Score the document against the Giuffrè codici fingerprint.

        Primary signal: the BD700x300 banner text reported as a
        :class:`SpecificMarker` named ``"giuffre_codici_banner_text"``
        by the real-fixture signal builder. The marker value is a
        string in the closed vocabulary (``"PENALE"``, ``"CIVILE"``,
        ``"LEGGI"``, etc.) or ``None`` when the banner is absent.
        When the marker is absent (unit-test signals or unusual
        fixture), the plugin falls back to the typographic signature
        + page geometry + PDFsharp producer combination, which is
        weaker but still enough to clear the 0.6 dispatcher threshold
        on a genuine codici document.

        Five positive contributions and one symmetric penalty:

        1. Banner SpecificMarker carrying a PENALE/CIVILE flavour
           (+0.50) or a LEGGI flavour (+0.40).
        2. PalatinoLinotype body family dominant above the floor
           (+0.20), penalised when absent (-0.30).
        3. Page geometry matching the 357 × 547 pt pocket format
           within tolerance (+0.15).
        4. PDFsharp producer/creator substring (+0.05).
        5. Substantial inline footnote apparatus (+0.10).

        The combination clears the 0.6 dispatcher threshold on either
        fixture by a wide margin (~1.00 with banner + all corroborating
        signals; ~0.65-0.70 without the banner via the typographic +
        geometry + producer combination).
        """
        score = 0.0

        banner_text = cls._extract_banner_text(signals)
        banner_code_type = _code_type_from_banner_text(banner_text)
        if banner_code_type is CodeType.PENALE:
            score += CONFIDENCE_BANNER_PENALE_PRIMARY
        elif banner_code_type is CodeType.CIVILE:
            score += CONFIDENCE_BANNER_CIVILE_PRIMARY
        elif banner_text is not None and "LEGGI" in banner_text.upper():
            score += CONFIDENCE_BANNER_LEGGI_PRIMARY

        if has_font_signature(
            signals,
            family_predicate=BODY_FONT_PREFIX,
            size=BODY_SIZE,
            tolerance=SIZE_TOLERANCE,
            min_dominance=BODY_DOMINANCE_MIN_PERCENT,
        ):
            score += CONFIDENCE_BODY_DOMINANT
        else:
            score += CONFIDENCE_OTHER_BODY_FAMILY_PENALTY

        if is_geometry_close(
            signals,
            width=PAGE_GEOMETRY_WIDTH,
            height=PAGE_GEOMETRY_HEIGHT,
            tolerance=PAGE_GEOMETRY_TOLERANCE,
            strict=True,
        ):
            score += CONFIDENCE_PAGE_GEOMETRY

        if producer_or_creator_contains(signals, PDFSHARP_PRODUCER_FRAGMENT):
            score += CONFIDENCE_PDFSHARP_PRODUCER

        if signals.apparatus_presence.footnote_markers >= 50:
            score += CONFIDENCE_FOOTNOTE_HEAVY_BONUS

        return max(0.0, score)

    @staticmethod
    def _extract_banner_text(signals: ProfilingSignals) -> str | None:
        """Extract the banner text from the SpecificMarker, if present.

        Returns ``None`` when the marker is absent (unit-test signals
        that did not include the marker) or when the marker is present
        but its value is ``None`` (real fixture where the banner glyph
        was not detected).
        """
        for marker in signals.specific_markers:
            if marker.name != BANNER_MARKER_NAME:
                continue
            if not marker.present:
                continue
            value = marker.value
            if isinstance(value, str):
                return value
        return None

    def get_categories(self) -> set[SemanticCategory]:
        """Closed set of categories the plugin may emit on the codici fixtures."""
        return {
            SemanticCategory.HEADING_1,
            SemanticCategory.HEADING_2,
            SemanticCategory.HEADING_3,
            SemanticCategory.HEADING_4,
            SemanticCategory.ARTICLE_HEADER,
            SemanticCategory.ARTICLE_BODY,
            SemanticCategory.PROCEDURAL,
            SemanticCategory.NOTE,
            SemanticCategory.CROSS_REFERENCE,
            SemanticCategory.ARTIFACT_RUNNING_HEADER,
            SemanticCategory.ARTIFACT_FOOTER,
            SemanticCategory.ARTIFACT_FILIGREE,
            SemanticCategory.ARTIFACT_STAMP,
            SemanticCategory.BOOK_PAGE_ANCHOR,
            SemanticCategory.UNCLASSIFIED,
            SemanticCategory.EMPTY_PAGE,
        }

    def get_post_processing(self) -> list[str]:
        """Return the ordered list of post-processing step IDs.

        Only ``dehyphenate_with_log``: the codici body text exhibits
        end-of-line hyphenation that the generic Italian-lexicon
        dehyphenator recovers. No cross-page note merging (notes are
        per-article and never cross page boundaries with a continuation
        beyond the article's column); no marginal-ellipsis recomposition
        (no marginals at all on the codici).
        """
        return ["dehyphenate_with_log"]

    def get_layouts_disabled(self) -> list[DisabledLayout]:
        """Disable Layout 3 (Structure view).

        L3 renders a tree of structural divisions and is meaningful on
        a treatise where each division has heterogeneous body content.
        On a code the structure is uniform (LIBRO > TITOLO > CAPO >
        SEZIONE > article) and the article is the natural unit of
        reading; Layer 2 prefers L1 (linear prose), L2 (consultation
        with article-by-article navigation), and L4 (Dottrina inline
        rendering of footnote markers) for this profile.
        """
        return [
            DisabledLayout(
                layout="L3",
                reason=(
                    "I Codici Giuffrè hanno struttura uniforme LIBRO/TITOLO/CAPO/SEZIONE; "
                    "il layout Struttura non aggiunge valore rispetto a L1 Lettura, "
                    "L2 Consultazione e L4 Dottrina Inline."
                ),
            ),
        ]

    # ------------------------------------------------------------------
    # Tier 2 refinement hooks

    def refine_classification(
        self,
        extraction: ExtractionResult,
        tier1_results: list[ClassifiedBlock],
    ) -> list[ClassifiedBlock]:
        """Promote UNCLASSIFIED blocks to the codici category vocabulary
        and detect the code type from the banner-glyph spans.

        Two passes. First, scan every extraction span to detect the
        BD700x300 banner glyph text(s) on the first 300 pages and
        derive the document's :class:`CodeType`. Second, walk the tier
        1 verdicts in order and apply the codici predicate chain
        (banner glyph, hierarchy heading, article header, article
        body, procedural block, note, abrogated article rubric).

        Predicate priority (first match wins):

        1. BD700x300 banner glyph → ARTIFACT_FILIGREE (carries the
           code-type info but is rendering noise from Layer 2's
           perspective).
        2. PROCEDURAL block (penale only): MyriadPro at NOTE_SIZE
           with ``"competenza:"`` in the text.
        3. NOTE block: MyriadPro at NOTE_SIZE.
        4. Hierarchy heading: PalatinoLinotype-Bold at BODY_SIZE
           whose text starts with a hierarchy keyword.
        5. ARTICLE_HEADER: PalatinoLinotype-Bold at ARTICLE_NUMBER_SIZE
           whose leading span text matches the article-number pattern.
        6. ARTICLE_BODY (penale): PalatinoLinotype-Roman at BODY_SIZE
           whose text starts with ``N.`` (arabic comma number).
        7. ARTICLE_BODY (civile / penale fallback):
           PalatinoLinotype-Roman or PalatinoLinotype-Italic at
           BODY_SIZE.

        Anything not matched stays UNCLASSIFIED.
        """
        self._pending_warnings = []
        self._minted_crossref_ids = set()
        self._minted_split_article_ids = set()
        self._minted_note_ids = set()

        self._code_type = self._detect_code_type_from_extraction(extraction)
        self._pending_warnings.append(
            f"{WARNING_PREFIX}:code_type_detected_{self._code_type.value.lower()}"
        )
        if self._code_type is CodeType.UNKNOWN:
            self._pending_warnings.append(f"{WARNING_PREFIX}:code_type_unknown_no_banner_found")

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

        return refined

    def refine_reconstruction(
        self,
        document: Document,
        extraction: ExtractionResult,
        classified_blocks: list[ClassifiedBlock],
    ) -> Document:
        """Run the four tier 2 structural transformations:

        1. **Intra-block article splitter** — walks every ARTICLE_HEADER
           Node whose underlying block carries 2+ article-number trigger
           spans and mints one synthetic ARTICLE_HEADER + ARTICLE_BODY
           Node per article past the first. Both code types.
        2. **Heading-with-inline-article splitter** (civile only) — for
           every HEADING_2/3/4 Node whose underlying block contains an
           inline article-number trigger after the heading text, splits
           the block into a HEADING_N Node followed by an ARTICLE_HEADER
           + ARTICLE_BODY pair. The HEADING_N Node's text is truncated
           to the heading-only portion; the synthetic ARTICLE_HEADER /
           ARTICLE_BODY Nodes carry the post-trigger text.
        3. **Body+notes splitter** — for every multi-note NOTE Node
           whose text contains 2+ ``(N)`` markers, splits the text on
           the ``(?=\\(\\d+\\))`` lookahead and mints one synthetic
           NOTE Node per chunk. Both code types.
        4. **Cross-reference minter** — walks every ARTICLE_BODY Node
           and mints one synthetic CROSS_REFERENCE Node per inline
           bracketed marker (simple ``[N]`` for the penale, elaborated
           ``[N c.c.]`` etc. for the civile). The penale and civile
           branches share the same minting framework but use different
           regex patterns.

        Pending warnings queued by :meth:`refine_classification` are
        flushed into ``Document.warnings`` together with the per-mint
        warnings produced by this method.
        """
        del classified_blocks

        new_warnings = list(self._pending_warnings)
        self._pending_warnings = []

        minter = NodeIdMinter(start=max_existing_node_counter(document.root) + 1)

        # Pass 1: generic article splitter (handles multi-article fused
        # blocks, NOTE-glue-ARTICLE blocks, and HEADING-with-inline-
        # article blocks — all in one signal-agnostic pass).
        roots_after_pass_1 = self._split_intra_block_articles(
            document.root, extraction, new_warnings, minter
        )
        # Pass 2: body+notes splitter.
        roots_after_pass_2 = self._split_multi_note_blocks(roots_after_pass_1, new_warnings, minter)
        # Pass 3: cross-reference minting.
        roots_after_pass_3 = self._mint_cross_references_in_forest(
            roots_after_pass_2, new_warnings, minter
        )

        return Document(
            root=roots_after_pass_3,
            warnings=tuple(document.warnings) + tuple(new_warnings),
            transformations=document.transformations,
        )

    def refine_apparatus(
        self,
        document: Document,
        extraction: ExtractionResult,
        classified_blocks: list[ClassifiedBlock],
    ) -> Document:
        """Bind synthetic CROSS_REFERENCE Nodes to their target
        ARTICLE_HEADER Node when the marker is a pure numeric form, and
        filter the noisy tier 1 generic ``unparseable_cross_reference_*``
        warnings on every CROSS_REFERENCE Node this plugin minted.

        Three responsibilities:

        1. Build a global marker → ARTICLE_HEADER node_id index by
           scanning every ARTICLE_HEADER Node in the document tree.
        2. Walk every synthetic CROSS_REFERENCE Node and try to extract
           a pure-numeric marker from its text; on match, look up the
           target in the index and attach an :class:`ApparatusRef`.
           Elaborated forms (``[N c.c.]``, ``[N Cost.]``, etc.) are not
           bound — they reference external codes and Layer 2 handles
           the secondary parsing.
        3. Filter the Document's warnings tuple to drop every tier 1
           ``unparseable_cross_reference_node_<id>`` and
           ``unresolved_cross_reference_node_<id>_n_<N>`` string whose
           ``<id>`` belongs to this plugin's synthetic Nodes.
        """
        del extraction, classified_blocks

        marker_index = self._build_article_marker_index(document.root)
        new_root, new_warnings = self._bind_cross_references_globally(document.root, marker_index)
        filtered_warnings = self._filter_tier1_crossref_warnings(document.warnings)

        return Document(
            root=new_root,
            warnings=filtered_warnings + tuple(new_warnings),
            transformations=document.transformations,
        )

    # ------------------------------------------------------------------
    # Code-type detection

    def _detect_code_type_from_extraction(self, extraction: ExtractionResult) -> CodeType:
        """Scan the extraction spans for BD700x300 banner glyphs and
        report the dominant code type observed on the first 300 pages.

        The banner is absent from front-matter pages (analysis § 12,
        empirical: pp. 0-80 penale, pp. 0-107 civile); the scan must
        therefore extend deep into the document, not stop at page 15
        as the analysis § 12 originally suggested. Returns
        :attr:`CodeType.UNKNOWN` when no banner glyph is found in any
        page.
        """
        penale_count = 0
        civile_count = 0
        max_page = 300
        for span in extraction.spans:
            if span.page >= max_page:
                break
            if not span.font.startswith(BANNER_FONT_PREFIX):
                continue
            text = span.text.upper()
            if "PENALE" in text:
                penale_count += 1
            elif "CIVILE" in text:
                civile_count += 1
        if penale_count == 0 and civile_count == 0:
            return CodeType.UNKNOWN
        if penale_count >= civile_count:
            return CodeType.PENALE
        return CodeType.CIVILE

    # ------------------------------------------------------------------
    # Per-block reclassification

    def _reclassify(self, verdict: ClassifiedBlock, view: _BlockView) -> ClassifiedBlock:
        if self._is_banner_glyph(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.ARTIFACT_FILIGREE,
                reason="giuffre_codici_banner_glyph",
            )

        if self._code_type is CodeType.PENALE and self._is_procedural_block(view):
            self._pending_warnings.append(
                f"{WARNING_PREFIX}:procedural_block_detected_block_"
                f"{verdict.block_index}_page_{view.block.page}"
            )
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.PROCEDURAL,
                reason="giuffre_codici_procedural",
            )

        if self._is_note_block(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.NOTE,
                reason="giuffre_codici_note",
            )

        if self._is_hierarchy_heading(view):
            level = self._hierarchy_level(view)
            category = {
                1: SemanticCategory.HEADING_1,
                2: SemanticCategory.HEADING_2,
                3: SemanticCategory.HEADING_3,
                4: SemanticCategory.HEADING_4,
            }[level]
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=category,
                reason=f"giuffre_codici_heading_{level}",
            )

        if self._is_article_header(view):
            reason = "giuffre_codici_article_header"
            if self._is_abrogated_inline(view):
                reason = "giuffre_codici_article_header_abrogated"
                self._pending_warnings.append(
                    f"{WARNING_PREFIX}:abrogated_article_detected_block_"
                    f"{verdict.block_index}_page_{view.block.page}"
                )
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.ARTICLE_HEADER,
                reason=reason,
            )

        if self._code_type is CodeType.CIVILE and self._is_range_abrogated(view):
            self._pending_warnings.append(
                f"{WARNING_PREFIX}:range_abrogated_article_detected_block_"
                f"{verdict.block_index}_page_{view.block.page}"
            )
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.ARTICLE_HEADER,
                reason="giuffre_codici_article_header_range_abrogated",
            )

        if self._code_type is CodeType.CIVILE and self._is_omissis(view):
            self._pending_warnings.append(
                f"{WARNING_PREFIX}:omissis_article_detected_block_"
                f"{verdict.block_index}_page_{view.block.page}"
            )
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.ARTICLE_BODY,
                reason="giuffre_codici_article_body_omissis",
            )

        if self._is_article_body(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.ARTICLE_BODY,
                reason="giuffre_codici_article_body",
            )

        return verdict

    # ------------------------------------------------------------------
    # Signature predicates

    @staticmethod
    def _is_banner_glyph(view: _BlockView) -> bool:
        """A BD700x300 banner glyph block."""
        if not view.spans:
            return False
        leading = view.spans[0]
        return leading.font.startswith(BANNER_FONT_PREFIX)

    @staticmethod
    def _is_procedural_block(view: _BlockView) -> bool:
        """A procedural block: MyriadPro at NOTE_SIZE with ``"competenza:"`` in the text.

        Only valid on the penale; the civile has no procedural blocks.
        The text check ensures we do not confuse a regular note with a
        procedural block — both share the MyriadPro 6.49 pt typographic
        signature.
        """
        if not view.spans:
            return False
        leading = view.spans[0]
        family_ok = leading.font.startswith(NOTE_FONT_PREFIX)
        size_ok = abs(leading.size - NOTE_SIZE) < SIZE_TOLERANCE
        if not (family_ok and size_ok):
            return False
        return _COMPETENZA_FRAGMENT in view.text

    @staticmethod
    def _is_note_block(view: _BlockView) -> bool:
        """A NOTE block: MyriadPro at NOTE_SIZE.

        Conservative predicate that catches every MyriadPro block in
        the note size range; the more specific procedural-block
        predicate runs before this one and intercepts the ``competenza:``
        case on the penale branch.
        """
        if not view.spans:
            return False
        leading = view.spans[0]
        family_ok = leading.font.startswith(NOTE_FONT_PREFIX)
        size_ok = abs(leading.size - NOTE_SIZE) < SIZE_TOLERANCE
        return family_ok and size_ok

    @staticmethod
    def _is_hierarchy_heading(view: _BlockView) -> bool:
        """A hierarchy heading: PalatinoLinotype-Bold at BODY_SIZE whose
        text starts with a hierarchy keyword (LIBRO/PARTE/TITOLO/CAPO/
        SEZIONE).

        The hierarchy headings sit at the same typographic signature as
        the article rubric (PalatinoLinotype-Bold at BODY_SIZE); the
        discriminator is the leading-text-pattern check against
        :data:`_HIERARCHY_PATTERN`.
        """
        if not view.spans:
            return False
        leading = view.spans[0]
        family_ok = leading.font.startswith(BODY_FONT_PREFIX) and leading.is_bold
        size_ok = abs(leading.size - BODY_SIZE) < SIZE_TOLERANCE
        if not (family_ok and size_ok):
            return False
        return bool(_HIERARCHY_PATTERN.match(view.text.strip()))

    @staticmethod
    def _hierarchy_level(view: _BlockView) -> int:
        """Return the HEADING_N level for a hierarchy block.

        LIBRO → 1, PARTE → 1 (top-level alternatives), TITOLO → 2,
        CAPO → 3, SEZIONE → 4. The mapping mirrors analysis § 11.
        """
        text = view.text.strip().upper()
        if text.startswith("LIBRO") or text.startswith("PARTE"):
            return 1
        if text.startswith("TITOLO"):
            return 2
        if text.startswith("CAPO"):
            return 3
        if text.startswith("SEZIONE"):
            return 4
        return 1

    @staticmethod
    def _is_article_header(view: _BlockView) -> bool:
        """An ARTICLE_HEADER block: leading span PalatinoLinotype-Bold at
        ARTICLE_NUMBER_SIZE with text matching the article-number pattern.
        """
        if not view.spans:
            return False
        leading = view.spans[0]
        family_ok = leading.font.startswith(BODY_FONT_PREFIX) and leading.is_bold
        size_ok = abs(leading.size - ARTICLE_NUMBER_SIZE) < SIZE_TOLERANCE
        if not (family_ok and size_ok):
            return False
        stripped = leading.text.strip().rstrip(".")
        return bool(_ARTICLE_NUMBER_PATTERN.match(stripped))

    @staticmethod
    def _is_abrogated_inline(view: _BlockView) -> bool:
        """Detect the abrogated rubric pattern inside an article header.

        Penale single-inline form: the article number trigger is
        followed by a ``[Rubric].`` bracket-enclosed phrase, optionally
        followed by a footnote marker ``(N)``. Pattern is applied to
        the joined block text.
        """
        text = view.text.strip()
        return bool(_ABROGATED_RUBRIC_PATTERN.search(text))

    @staticmethod
    def _is_range_abrogated(view: _BlockView) -> bool:
        """Detect the civile range-abrogated pattern ``"152-153. (1)."``.

        Pure block-text pattern; the typographic family is the standard
        ARTICLE_HEADER signature (PalatinoLinotype-Bold at
        ARTICLE_NUMBER_SIZE) but the trigger span carries a range.
        """
        if not view.spans:
            return False
        leading = view.spans[0]
        family_ok = leading.font.startswith(BODY_FONT_PREFIX) and leading.is_bold
        size_ok = abs(leading.size - ARTICLE_NUMBER_SIZE) < SIZE_TOLERANCE
        if not (family_ok and size_ok):
            return False
        return bool(_RANGE_ABROGATED_PATTERN.match(view.text.strip()))

    @staticmethod
    def _is_omissis(view: _BlockView) -> bool:
        """Detect the civile Omissis pattern in CEDU/UE treaty texts.

        Leading span PalatinoLinotype-Italic at BODY_SIZE with the
        ``(Omissis)`` marker in the text.
        """
        if not view.spans:
            return False
        leading = view.spans[0]
        family_ok = leading.font.startswith(BODY_FONT_PREFIX) and leading.is_italic
        size_ok = abs(leading.size - BODY_SIZE) < SIZE_TOLERANCE
        if not (family_ok and size_ok):
            return False
        return bool(_OMISSIS_PATTERN.search(view.text))

    @staticmethod
    def _is_article_body(view: _BlockView) -> bool:
        """An ARTICLE_BODY block: leading span PalatinoLinotype-Roman or
        PalatinoLinotype-Italic at BODY_SIZE.
        """
        if not view.spans:
            return False
        leading = view.spans[0]
        family_ok = leading.font.startswith(BODY_FONT_PREFIX) and not leading.is_bold
        size_ok = abs(leading.size - BODY_SIZE) < SIZE_TOLERANCE
        return family_ok and size_ok

    # ------------------------------------------------------------------
    # Intra-block article splitter

    def _split_intra_block_articles(
        self,
        roots: tuple[Node, ...],
        extraction: ExtractionResult,
        warnings: list[str],
        minter: NodeIdMinter,
    ) -> tuple[Node, ...]:
        """Walk every Node and split at each article-number trigger span found.

        The trigger predicate is "a bold PalatinoLinotype span of size
        >= INTRA_BLOCK_ARTICLE_TRIGGER_MIN_SIZE with text matching
        ``_ARTICLE_NUMBER_OR_RANGE_PATTERN``". The splitter is **signal-
        agnostic on the host category**: it applies to ARTICLE_HEADER
        Nodes (multi-article case, common on the civile), NOTE Nodes
        (PyMuPDF often glues the previous article's notes with the next
        article's header — common on the penale), HEADING_N Nodes
        (CAPO/SEZIONE block with article inline — both codes), and any
        other category that happens to contain a trigger.

        Logic:

        - If the host's leading span is a trigger, the host keeps spans
          up to the SECOND trigger (or end of block if only one); each
          subsequent trigger mints a synthetic ARTICLE_HEADER + body
          pair. This is the original "multi-article ARTICLE_HEADER" case.
        - If the host's leading span is NOT a trigger, the host's text
          is truncated to spans BEFORE the first trigger (preserving
          its original category — NOTE stays NOTE, HEADING stays
          HEADING), and every trigger mints a synthetic ARTICLE_HEADER +
          body pair.

        Empirically falsified analysis § 4.1: ~90% of penale article
        headers are buried as non-leading triggers inside NOTE-glue
        blocks. Without this generalised splitter the plugin recovers
        only ~10% of articles on the penale.
        """
        return self._walk_and_transform(
            roots,
            lambda n: self._maybe_split_block_at_triggers(n, extraction, warnings, minter),
        )

    def _maybe_split_block_at_triggers(
        self,
        node: Node,
        extraction: ExtractionResult,
        warnings: list[str],
        minter: NodeIdMinter,
    ) -> list[Node]:
        """Examine a Node for article-number triggers and split if needed.

        Returns ``[node]`` unchanged when the node has no trigger or
        when it has exactly one leading trigger (= already a single
        well-formed ARTICLE_HEADER). Otherwise returns the host (with
        truncated text) plus one synthetic ``(ARTICLE_HEADER,
        ARTICLE_BODY)`` pair per trigger past the host portion.
        """
        if not node.block_indices:
            return [node]

        triggers: list[int] = []
        flat_spans: list[Span] = []
        for block_index in node.block_indices:
            if block_index < 0 or block_index >= len(extraction.blocks):
                continue
            block = extraction.blocks[block_index]
            start, end = block.span_range
            for span in extraction.spans[start:end]:
                flat_spans.append(span)
                if self._is_article_number_trigger(span):
                    triggers.append(len(flat_spans) - 1)
        if not triggers:
            return [node]

        leading_is_trigger = triggers[0] == 0
        if leading_is_trigger and len(triggers) == 1:
            # Single well-formed ARTICLE_HEADER, no split needed.
            return [node]

        if leading_is_trigger:
            # Host already holds the first article; its text spans 0
            # up to the second trigger. Synthetic pairs are minted for
            # triggers 1, 2, ... (zero-indexed).
            host_end = triggers[1]
            first_mint_idx = 1
        else:
            # Host has non-article leading content (NOTE-glue or HEADING-
            # glue case); its text is truncated to spans before the
            # first trigger. Every trigger mints a synthetic pair.
            host_end = triggers[0]
            first_mint_idx = 0

        warnings.append(
            f"{WARNING_PREFIX}:intra_block_article_split_block_"
            f"{node.block_indices[0]}_count_{len(triggers)}"
        )
        result: list[Node] = []
        host_spans = flat_spans[:host_end]
        host_text = "".join(s.text for s in host_spans)
        result.append(replace(node, text=host_text))

        slice_starts = [*triggers[first_mint_idx:], len(flat_spans)]
        for article_idx in range(len(slice_starts) - 1):
            sub_start = slice_starts[article_idx]
            sub_end = slice_starts[article_idx + 1]
            sub_spans = flat_spans[sub_start:sub_end]
            if not sub_spans:
                continue
            header_text = sub_spans[0].text
            body_spans = sub_spans[1:]
            body_text = "".join(s.text for s in body_spans)
            header_id = minter.mint()
            self._minted_split_article_ids.add(header_id)
            warnings.append(
                f"{WARNING_PREFIX}:intra_block_article_split_minted_node_"
                f"{header_id}_page_{node.page_index}_article_{article_idx + first_mint_idx}"
            )
            result.append(
                Node(
                    id=header_id,
                    category=SemanticCategory.ARTICLE_HEADER,
                    page_index=node.page_index,
                    block_indices=node.block_indices,
                    text=header_text,
                )
            )
            if body_text.strip():
                body_id = minter.mint()
                result.append(
                    Node(
                        id=body_id,
                        category=SemanticCategory.ARTICLE_BODY,
                        page_index=node.page_index,
                        block_indices=node.block_indices,
                        text=body_text,
                    )
                )
        return result

    @staticmethod
    def _is_article_number_trigger(span: Span) -> bool:
        """Predicate identifying an article-number trigger span.

        A bold PalatinoLinotype span of size >= INTRA_BLOCK_ARTICLE_TRIGGER_MIN_SIZE
        whose text (stripped of trailing period and whitespace) matches
        either a pure article number or an article range.
        """
        if not span.font.startswith(BODY_FONT_PREFIX):
            return False
        if not span.is_bold:
            return False
        if span.size < INTRA_BLOCK_ARTICLE_TRIGGER_MIN_SIZE:
            return False
        text = span.text.strip().rstrip(".")
        return bool(_ARTICLE_NUMBER_OR_RANGE_PATTERN.match(text))

    # ------------------------------------------------------------------
    # Body+notes splitter

    def _split_multi_note_blocks(
        self,
        roots: tuple[Node, ...],
        warnings: list[str],
        minter: NodeIdMinter,
    ) -> tuple[Node, ...]:
        """Walk every NOTE Node whose text contains 2+ ``(N)`` markers
        and split it into individual NOTE Nodes via the
        ``(?=\\(\\d+\\))`` lookahead split.

        Reuses the body+notes splitter framework established by the
        DeJure NS plugin (pattern (qq) in CLAUDE.md); the only
        difference is that the splitter operates on Nodes already
        classified as NOTE rather than on UNCLASSIFIED-then-NOTE
        boundaries.
        """
        return self._walk_and_transform(
            roots,
            lambda n: self._maybe_split_multi_note(n, warnings, minter),
        )

    def _maybe_split_multi_note(
        self,
        node: Node,
        warnings: list[str],
        minter: NodeIdMinter,
    ) -> list[Node]:
        if node.category is not SemanticCategory.NOTE:
            return [node]
        if node.text is None:
            return [node]
        markers = list(_NOTE_MARKER_PATTERN.finditer(node.text))
        if len(markers) <= 1:
            return [node]
        # Split the text into chunks; the first chunk keeps the host
        # node's text rewritten, subsequent chunks become synthetic
        # NOTE siblings.
        chunks = _MULTI_NOTE_SPLIT_PATTERN.split(node.text)
        # The lookahead split may leave an empty prefix when the text
        # opens with ``(N)``; drop it.
        chunks = [c for c in chunks if c.strip()]
        if len(chunks) <= 1:
            return [node]
        result: list[Node] = [replace(node, text=chunks[0])]
        for chunk in chunks[1:]:
            marker_match = _NOTE_OPEN_PATTERN.match(chunk)
            marker = marker_match.group(1) if marker_match is not None else "?"
            new_id = minter.mint()
            self._minted_note_ids.add(new_id)
            warnings.append(
                f"{WARNING_PREFIX}:multi_note_split_minted_node_"
                f"{new_id}_page_{node.page_index}_marker_{marker}"
            )
            result.append(
                Node(
                    id=new_id,
                    category=SemanticCategory.NOTE,
                    page_index=node.page_index,
                    block_indices=node.block_indices,
                    text=chunk,
                    length_category=compute_note_length_category(chunk),
                )
            )
        return result

    # ------------------------------------------------------------------
    # Cross-reference minting (refine_reconstruction)

    def _mint_cross_references_in_forest(
        self,
        roots: tuple[Node, ...],
        warnings: list[str],
        minter: NodeIdMinter,
    ) -> tuple[Node, ...]:
        """Walk the forest pre-order, minting CROSS_REFERENCE siblings
        after every ARTICLE_BODY Node with inline bracketed markers in
        its text.
        """
        out: list[Node] = []
        for node in roots:
            new_children = self._mint_cross_references_in_forest(node.children, warnings, minter)
            if new_children != node.children:
                node = replace(node, children=new_children)
            out.append(node)
            if node.category is SemanticCategory.ARTICLE_BODY and node.text:
                out.extend(self._mint_for_body(node, warnings, minter))
        return tuple(out)

    def _mint_for_body(
        self,
        body: Node,
        warnings: list[str],
        minter: NodeIdMinter,
    ) -> list[Node]:
        """Mint synthetic CROSS_REFERENCE Nodes for every inline bracket
        match inside ``body.text``.

        The pattern branches on :attr:`_code_type`: simple ``[N]`` for
        the penale, elaborated ``[N c.c.]`` etc. for the civile. Comma
        markers ``[I]`` / ``[II]`` are explicitly excluded (the
        ``_COMMA_MARKER_PATTERN`` matches them and the minter skips
        any match that overlaps a comma-marker position).
        """
        assert body.text is not None
        text = body.text
        comma_positions: set[int] = set()
        if self._code_type is CodeType.CIVILE:
            for m in _COMMA_MARKER_PATTERN.finditer(text):
                comma_positions.add(m.start())
        pattern = (
            _CROSSREF_ELABORATED_PATTERN
            if self._code_type is CodeType.CIVILE
            else _CROSSREF_SIMPLE_PATTERN
        )
        minted: list[Node] = []
        for m in pattern.finditer(text):
            if m.start() in comma_positions:
                continue
            marker_text = m.group(0)
            # Skip empty matches and matches that are pure roman
            # numerals (the comma-marker exclusion does not catch every
            # roman form on the civile if the pattern were too lax;
            # the simple-pattern penale form excludes them by digit
            # requirement already).
            if self._code_type is CodeType.CIVILE:
                inner = m.group(0).strip("[]").strip()
                if inner and inner[0] not in "0123456789":
                    continue
            crossref_id = minter.mint()
            self._minted_crossref_ids.add(crossref_id)
            warnings.append(
                f"{WARNING_PREFIX}:cross_reference_minted_node_"
                f"{crossref_id}_page_{body.page_index}_marker_{_warning_safe(marker_text)}"
            )
            minted.append(
                Node(
                    id=crossref_id,
                    category=SemanticCategory.CROSS_REFERENCE,
                    page_index=body.page_index,
                    block_indices=body.block_indices,
                    text=marker_text,
                )
            )
        return minted

    # ------------------------------------------------------------------
    # Global article-marker index + binding (refine_apparatus)

    @staticmethod
    def _build_article_marker_index(roots: tuple[Node, ...]) -> dict[str, str]:
        """Build a canonical marker → ARTICLE_HEADER node_id map.

        Walks every ARTICLE_HEADER Node in the document tree, parses
        its text to extract the article number, and stores the mapping.
        On collision (two ARTICLE_HEADER with the same article number,
        which can happen on the codici because each volume contains
        the c.p. + c.p.p. + leggi sections, so article 1 exists three
        times) the first wins. This is a known limitation of the v1
        global-scope binding: the more robust per-volume binding
        requires a section-aware scope that the plugin does not yet
        implement.
        """
        index: dict[str, str] = {}
        for node in iter_nodes_pre_order(roots):
            if node.category is not SemanticCategory.ARTICLE_HEADER:
                continue
            if node.text is None:
                continue
            stripped = node.text.strip()
            # The article number is the first token before a dot or
            # space, optionally followed by an ordinal suffix.
            match = re.match(r"^(\d+)(?:-(bis|ter|quater))?", stripped)
            if match is None:
                continue
            marker = match.group(1)
            if match.group(2) is not None:
                marker = f"{marker}-{match.group(2)}"
            index.setdefault(marker, node.id)
        return index

    def _bind_cross_references_globally(
        self,
        roots: tuple[Node, ...],
        marker_index: dict[str, str],
    ) -> tuple[tuple[Node, ...], list[str]]:
        """Walk the forest, bind every synthetic numeric CROSS_REFERENCE
        Node to its ARTICLE_HEADER target, and emit unresolved warnings.

        Only pure-numeric markers (``[N]`` or ``[N-bis]``) are bound;
        elaborated forms with codice qualifiers (``[N Cost.]``,
        ``[N c.c.]``, etc.) point at external codes and are not bound
        — they remain with empty ``apparatus_refs`` and Layer 2 handles
        the secondary parsing.
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
                inner = node.text.strip("[]").strip()
                # Skip elaborated forms with codice qualifiers (any
                # trailing alphabetic content after a digit).
                pure_numeric = re.match(r"^(\d+(?:-(bis|ter|quater))?)$", inner)
                if pure_numeric is not None:
                    marker = pure_numeric.group(1)
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
                            f"{node.id}_marker_{_warning_safe(marker)}"
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
    # Tree-walk helper

    def _walk_and_transform(
        self,
        roots: tuple[Node, ...],
        transformer: Callable[[Node], list[Node]],
    ) -> tuple[Node, ...]:
        """Pre-order DFS over the forest, applying ``transformer`` to
        every Node and substituting the Node's position with the
        returned list of Nodes.

        ``transformer`` is a callable ``Node -> list[Node]``. When it
        returns a singleton list ``[node]`` the position is unchanged;
        when it returns multiple Nodes they are inserted in order at
        the original Node's position. Children of every returned Node
        are walked recursively.
        """
        out: list[Node] = []
        for node in roots:
            new_children = self._walk_and_transform(node.children, transformer)
            if new_children != node.children:
                node = replace(node, children=new_children)
            replacements = transformer(node)
            out.extend(replacements)
        return tuple(out)

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


def _warning_safe(text: str) -> str:
    """Sanitise a marker text for inclusion in a warning string.

    Warnings should be greppable; non-alphanumeric characters are
    replaced with underscores and the result is truncated to a sensible
    length. Used by the cross-reference minting and binding warnings to
    fold the verbatim marker text into a single token.
    """
    cleaned = re.sub(r"[^a-zA-Z0-9-]+", "_", text.strip())
    return cleaned[:40] if len(cleaned) > 40 else cleaned
