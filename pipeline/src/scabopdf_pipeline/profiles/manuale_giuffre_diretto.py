"""Corpus plugin for the Giuffrè diretto manual series — Torrente-Schlesinger.

Fifth real corpus plugin of the project. Handles the Torrente-Schlesinger
"Manuale di diritto privato" 25th edition (Giuffrè Francis Lefebvre,
2021, ISBN 9788828829546) — see ``docs/analysis/ANALYSIS_TORRENTE_SCHLESINGER.md``
for the editorial analysis the plugin is built against. The plugin is
calibrated on the integrale 1559-page fixture
``pipeline/tests/fixtures/private/torrente_schlesinger.pdf``.

The manual is structurally the most complex in the project to date and
extends the ScaboPDF profile vocabulary along eight new dimensions:

- **MScotchRoman + TimesNewRomanPS-BoldMT typographic system**, a family
  pair never seen in the four prior plugins (Patriarca uses Times-New-Roman
  with a Zanichelli outline, Tesauro/Mosconi use TimesTenLTStd from the
  UTET/Wolters Kluwer pipeline, Mandrioli uses SimonciniGaramondStd from
  Giappichelli);
- **a four-level heading hierarchy** PARTE TEMATICA → CAPITOLO →
  SOTTO-SEZIONE → § PARAGRAFO, the first profile in the project that
  uses every available HEADING_N rank. Mandrioli emits HEADING_1..4
  too but with sparser coverage across volumes;
- **CAPITOLO recognised via the same small-caps three-span pattern
  that the Giappichelli plugin established** — ``("C", 11.47pt) +
  ("APITOLO ", 7.73pt) + ("<roman>", 11.47pt)`` — but with a
  different family (``MScotchRoman``) and slightly different sizes.
  The empirical inspection of the fixture contradicted the upstream
  editorial analysis claim that "CAPITOLO is body-sized regular and
  must be detected purely textually": every body CAPITOLO in the
  fixture (82/82) is typographically distinct via the 7.73pt
  small-caps subscript;
- **dense apparatus of marginal headings (4051 blocks)**, the highest
  density of any corpus in the project. The 7.48pt regular or italic
  ``MScotchRoman`` blocks sit alternately on the left margin
  (``bbox.x0 < 80``) for even pages and the right margin
  (``bbox.x0 > 380``) for odd pages, never both. The pre-existing
  ``MARGINAL_HEADING`` category and its tier 1 generic resolver in
  :mod:`scabopdf_pipeline.apparatus.resolver` recover the body
  associations without profile-specific override;
- **inline cross-reference markers densissimi in BODY text via three
  distinct regex patterns**:

  * ``§ N`` (paragraph rinvio, 3501 occurrences) — internally bindable
    to the corresponding HEADING_4 paragrafo;
  * ``art. N c.c.`` (codice civile article reference, 2416 occurrences)
    — external reference, no internal binding target;
  * ``Cass. <date> n. <n>`` (Court of Cassation sentence citation,
    2687 occurrences) — external reference, no internal binding target.

  Each match is materialised as a synthetic ``CROSS_REFERENCE`` Node
  appended as a sibling immediately after the originating BODY Node,
  following the minting convention introduced by the Mosconi plugin
  (commit ``265e6d9``) and reused by the Mandrioli plugin (commit
  ``6ee8efa``). The full marker text is preserved as the synthetic
  Node's ``text`` (``"§ 130"``, ``"art. 476 c.c."``, ``"Cass. 19
  luglio 2019 n. 19504"``) so that Layer 2 can distinguish the
  three sub-types without a schema bump for a ``subtype`` field.
  The :meth:`refine_apparatus` hook performs the profile-specific
  global ``§ N`` → HEADING_4 binding (the only sub-type with an
  internal target) and filters the tier 1 generic resolver's noisy
  ``unparseable_cross_reference_*`` warnings on every minted Node
  (they fail the generic ``CROSS_REF_DIGITS_REGEX`` because the
  Torrente marker is never a pure digit);
- **global-document scope for the § N binding**, in contrast to the
  scope-locale (HEADING_2 ancestor) scope used by every prior plugin.
  The Torrente numbers paragrafi continuously from 1 to 693 across
  the whole manual (plus 17 ``-bis``/``-ter`` variants), so a
  ``§ 130`` reference is an anchor into the unique HEADING_4 node
  whose marker is ``130`` regardless of which CAPITOLO it sits
  under. The tier 1 generic ``_resolve_cross_references`` resolver
  scopes to the nearest HEADING_2 ancestor and would systematically
  fail on this manual; the plugin's :meth:`refine_apparatus`
  override builds its own marker → node_id index over the full
  document tree and binds globally;
- **filigrana copyright BIC on every body page**, a TimesNewRoman
  15.35pt single-span block sitting above the top margin
  (``bbox.y0 ∈ [-2.4, 18.3]``) whose text is the closed string
  ``"© Giuffrè Francis Lefebvre - Versione riservata Biblioteca It.
  Ciechi - Monza"``. Tier 1 generic ``filigree`` heuristic recognises
  it via the ``"Versione riservata"`` / ``"© Giuffrè"`` keywords
  already enumerated in
  :data:`scabopdf_pipeline.classification.tier1.FILIGREE_KEYWORDS`;
  the plugin does not override classification for these blocks;
- **back-matter Indice Analitico-Alfabetico in double column on pages
  1507-1556**, the only part of the manual to use double-column
  layout. The tier 1 mono-column ``(page, y0, x0)`` reading-order sort
  interleaves left and right column blocks on each index page,
  yielding alphabetically scrambled output. The plugin classifies the
  blocks as ``INDEX_ENTRY`` but documents the column ordering as a
  known limitation in v1; a future revision can reorder via a
  profile-specific column-aware sort in :meth:`refine_reconstruction`.

The empirical fixture inspection (PyMuPDF 1.27.2.3 on the 6.7 MB,
1559-page fixture) reports:

- producer / creator both ``"PDFsharp 1.31.1789-g (www.pdfsharp.com)"``,
  shared with Giuffrè codici and Annali/Tematici EdD — a marker of
  the editorial pipeline rather than the genre;
- 13 HEADING_1 PARTE blocks at body pages 35, 103, 305, 415, 559, 739,
  893, 929, 939, 1019, 1227, 1363, 1479;
- 82 HEADING_2 CAPITOLO blocks numbered I…LXXXI with one ``LXXII-BIS``;
- 58 HEADING_3 SOTTO-SEZIONE blocks (56 letter-keyed ``A)`` ``B)``
  ``C)``, 2 roman-keyed ``I.`` ``II.``);
- 710 HEADING_4 § PARAGRAFO blocks (693 numeric 1…693 plus 17
  ``-bis``/``-ter`` variants);
- 4051 MARGINAL_HEADING blocks, 1994 on even pages, 2057 on odd
  pages, zero leakage between margins;
- 1558 ARTIFACT_FILIGREE blocks (one per page except the last
  backcover);
- 0 traditional footnote markers (every reference inline in body text
  via the three regex patterns above);
- ~8600 inline cross-references across the three sub-types;
- size drift consistent at -0.03pt below nominal: body 11.47pt
  (nominal 11.5), notes 7.48pt (nominal 7.5), index entries 9.48pt
  (nominal 9.5), filigree 15.35pt (nominal 15.3), PARTE 12.97pt
  (nominal 13.0), § glyph 10.98pt (nominal 11.0), CAPITOLO small-caps
  subscript 7.73pt, sommario sub-level 6.24pt. The drift is a stable
  artefact of the PDFsharp pipeline.

Heading levels.

- **HEADING_1 — PARTE TEMATICA.** Single-span block whose leading span
  is ``TimesNewRomanPS-BoldMT`` 12.97pt. The size is unique to this
  category in the manual (no other body content uses 12.97pt). The
  predicate accepts both single-span and multi-span PARTE titles
  (some PARTE labels wrap onto two 12.97pt spans). HEADING_1 is also
  emitted for front-matter and back-matter top-level sections
  (``PREFAZIONE``, ``INDICE SOMMARIO``, ``INDICE ANALITICO-ALFABETICO``,
  ``ABBREVIAZIONI``) recognised via short-text pattern on a
  body-sized MScotchRoman block — these are not body-pages but
  navigation entry-points and they sit at the top of the document
  structure alongside the body PARTE.
- **HEADING_2 — CAPITOLO.** Block whose leading three spans match the
  small-caps composite ``("C", 11.47pt) + ("APITOLO ", 7.73pt) +
  ("<roman>", 11.47pt)`` joined as ``"CAPITOLO <roman>"``. The block
  carries the chapter title on its second line as additional 11.47pt
  spans; the plugin does not split the title into a separate
  HEADING_2 sibling because PyMuPDF emits the two-line CAPITOLO as a
  single block on this fixture (confirmed 82/82).
- **HEADING_3 — SOTTO-SEZIONE.** Block whose leading span is
  ``MScotchRoman`` 11.47pt regular (the body signature) AND whose
  text matches one of two short patterns: ``^[A-Z]\\)\\s+[A-Z]+``
  (letter-keyed, 56 occurrences) or ``^[IVX]+\\.\\s+[A-Z]+`` (roman-
  keyed, 2 occurrences). The body of the section title that follows
  the marker (``LA PERSONA FISICA``, ``L'ADEMPIMENTO``) is typeset
  in ``MScotchRoman-Italic`` 11.47pt — the predicate ignores the
  italic flag of the title span and relies on the leading-marker
  signature and bbox centering on the page horizontal centre
  (within :data:`SUBSECTION_CENTER_TOLERANCE` of the page midline).
  The geometric guard discriminates the 58 structural sotto-sezioni
  from inline ``A)``/``B)`` enumerations inside body paragraphs
  (which sit at the body column ``x0 ≈ 51``, not at the centered
  column ``x0 ≈ 100-200``).
- **HEADING_4 — § PARAGRAFO.** Block whose leading span is
  ``TimesNewRomanPS-BoldMT`` 10.98pt with text starting with the
  ``"§"`` glyph, followed by additional bold spans at 11.47pt
  (number ``"<n>."``) and bold-italic at 11.47pt (title), and whose
  joined text matches the pattern ``^§\\s*\\d+(?:[-\\s]?(?:bis|ter|
  quater))?\\.\\s+\\S``. The predicate uses the leading-span
  signature as the primary discriminator (the ``§`` glyph at 10.98pt
  is unique to this category) and the text pattern as the secondary
  confirmation. Numbers continuative 1..693 plus 17 ``-bis``/``-ter``
  variants (LXXII-bis, 130-bis, 691-bis, etc.).

Apparatus.

- **MARGINAL_HEADING — mini-titoletto al margine.** Block whose
  leading span is ``MScotchRoman`` or ``MScotchRoman-Italic`` at
  7.48pt with the block bbox sitting against either the left margin
  (``x0 < LEFT_MARGIN_X_THRESHOLD = 80``) or the right margin
  (``x0 > RIGHT_MARGIN_X_THRESHOLD = 380``). The 7.48pt size is
  unique to this category in the manual; no other block uses this
  signature. Roughly 2.6 marginals per body page, with a max of 9 on
  the most apparatus-dense pages. The tier 1 generic
  ``_resolve_marginal_positions`` resolver binds each marginal to
  the body Node on the same page whose vertical centre is closest;
  the plugin does not override this binding.
- **CROSS_REFERENCE — inline rinvio.** Synthetic Node minted by
  :meth:`refine_reconstruction` for each match of the three regex
  patterns (``§ N``, ``art. N c.c.``, ``Cass. <date> n. N``) inside
  any BODY Node's text. The marker text is preserved verbatim on
  the Node's ``text`` so Layer 2 can distinguish the three sub-types
  by inspecting the leading character (``§``, ``a``, ``C``). Three
  warning templates record the mint per sub-type (paragraph,
  article, sentence). The ``§ N`` synthetic Nodes are bound globally
  to their HEADING_4 target in :meth:`refine_apparatus` via a
  marker → node_id index built over the whole document tree
  (overriding the tier 1 generic scope to HEADING_2 ancestor, which
  would systematically fail on Torrente given the manual's
  continuative numbering); the ``art.`` and ``Cass.`` synthetic
  Nodes have no internal binding target and remain with empty
  ``apparatus_refs``.
- **NOTE — nota a piè con asterisco.** A unique one-off NOTE on
  PDF page index 6 (book p.7) inside the Indice Sommario: a
  ``MScotchRoman`` 7.98pt block whose text starts with the literal
  ``(*)`` marker, carrying the editorial division of curatorship
  between Anelli (capitoli I-VI, IX, XXV-L, LXV-LXXXI) and Granelli
  (capitoli VII-VIII, X-XXIV, LI-LXIV). The block is intercepted by
  :meth:`refine_classification` via the ``(*)`` text predicate and
  classified as ``NOTE`` despite the apparently anomalous size
  (7.98pt is also used for the Indice Analitico subtitle ``(Il
  numero indica il paragrafo)`` and for the asterisk note itself —
  the text-prefix check disambiguates).

Artifacts.

- **ARTIFACT_FILIGREE** — caught by tier 1 generic ``filigree``
  heuristic via the ``"Versione riservata"`` / ``"© Giuffrè"``
  keywords. 1558 occurrences across the body pages.
- **ARTIFACT_RUNNING_HEADER** — caught by tier 1 generic
  ``header_zone`` heuristic (top 8% of page, low character count).
  The Torrente page header is ``"<title parte> <num pagina libro>
  [§ N]"`` at MScotchRoman-Italic 11.47pt y ≈ 44-56; the plugin
  could in principle classify it as ``ARTIFACT_PAGE_HEADER`` (the
  semantically more precise category) but the v1 decision keeps the
  generic ``ARTIFACT_RUNNING_HEADER`` to avoid a profile-specific
  override of a tier 1 heuristic that already works. A future
  revision can promote to ``ARTIFACT_PAGE_HEADER`` and extract the
  book-page number into a synthetic ``BOOK_PAGE_ANCHOR`` Node for
  Layer 2 navigation.

Index entries.

- **INDEX_ENTRY** — emitted for two distinct page ranges:

  * Front-matter **Indice Sommario** on pp.7-34 (PDF indices 6-33):
    ``MScotchRoman`` 9.48pt main entries plus ``MScotchRoman``
    6.24pt sub-level capitolo titles. Hierarchical TOC of the whole
    manual with book-page references in the right column. The
    plugin does NOT parse the entries into a structured
    ``TOC_GENERAL`` with ``toc_items`` — that would require brittle
    text parsing and v1 favours a uniform ``INDEX_ENTRY``
    classification across both ranges.
  * Back-matter **Indice Analitico-Alfabetico** on pp.1507-1556
    (PDF indices 1506-1555): ``MScotchRoman`` 9.48pt regular and
    italic entries on a double-column layout (split at
    ``x ≈ 230pt``). The tier 1 mono-column reading-order sort
    interleaves left and right column blocks on each index page,
    yielding alphabetically scrambled output. The plugin classifies
    the blocks as ``INDEX_ENTRY`` and emits a per-page warning
    ``index_analitico_double_column_unordered_page_<p>`` to surface
    the known v1 limitation. A future revision will reorder columns
    in :meth:`refine_reconstruction`.

Pipeline integration.

- :meth:`get_post_processing` returns ``["dehyphenate_with_log"]``.
  The empirical inspection observed end-of-line hyphenation in
  roughly 10 % of body lines (substantial drift typical of a native
  PDFsharp pipeline rendering Italian text with tight line-breaking
  rules); the generic dehyphenator with Italian lexicon recovers
  the unbroken word forms. No ``merge_cross_page_notes`` is declared
  because the manual has zero traditional notes; no
  ``recompose_marginal_ellipsis`` because Torrente marginals are
  short single-line mini-headings without typographic continuation
  markers.
- :meth:`get_layouts_disabled` returns ``[DisabledLayout(layout="L4",
  reason=...)]``. Layout 4 (Dottrina Inline) is the
  inline-footnote-marker rendering mode designed for treatises with
  traditional footnote apparatus. The Torrente has zero such
  apparatus: every reference is inline in the body text and the
  apparatus categories the manual exposes are MARGINAL_HEADING
  (mini-titoletti, semantically distinct from notes) and synthetic
  CROSS_REFERENCE (rinvii, also semantically distinct). Layer 2
  greys out L4 for this profile and offers L1/L2/L3 instead.
- :meth:`refine_apparatus` performs three profile-specific actions:
  (a) build a global marker → HEADING_4 node_id index over the
  full document tree; (b) bind each synthetic ``§ N`` CROSS_REFERENCE
  Node to its HEADING_4 target via this index, populating
  ``apparatus_refs`` with ``CROSS_REF_TARGET``; (c) filter the
  Document's warnings tuple to drop the tier 1 generic
  ``unparseable_cross_reference_node_<id>`` strings the resolver
  emitted for every synthetic Node minted by this plugin (every
  Torrente cross-reference text starts with a non-digit character
  so the generic ``CROSS_REF_DIGITS_REGEX`` fails universally,
  generating ~8600 spurious warnings the plugin owns and removes).

Instance state.

The plugin keeps:

- ``_pending_warnings``: queued warnings produced during
  :meth:`refine_classification` (which has no Document to attach them
  to) and flushed into ``Document.warnings`` by
  :meth:`refine_reconstruction`.
- ``_minted_crossref_ids``: the set of synthetic CROSS_REFERENCE
  node ids :meth:`refine_reconstruction` produced. Consumed by
  :meth:`refine_apparatus` to (a) decide which Nodes to bind
  globally and (b) decide which tier 1 warnings to filter out.

Closed warning vocabulary, prefix ``plugin:giuffre_diretto:``. See
:data:`WARNING_TEMPLATES` for the eight entries.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, replace
from typing import ClassVar

from scabopdf_pipeline.apparatus.resolver import filter_tier1_crossref_warnings
from scabopdf_pipeline.apparatus.types import ApparatusRef, ApparatusRefKind
from scabopdf_pipeline.classification.types import ClassifiedBlock
from scabopdf_pipeline.extraction.types import Block, ExtractionResult, Span
from scabopdf_pipeline.profiling.plugin import ProfilePlugin
from scabopdf_pipeline.profiling.profile import DisabledLayout
from scabopdf_pipeline.profiling.signals import ProfilingSignals
from scabopdf_pipeline.profiling.typography_constants import (
    APPARATUS_PRESENCE_THRESHOLD,
    SIZE_TOLERANCE,
)
from scabopdf_pipeline.reconstruction.geometry_helpers import is_centered_x
from scabopdf_pipeline.reconstruction.minting import (
    NodeIdMinter,
    iter_nodes_pre_order,
    max_existing_node_counter,
)
from scabopdf_pipeline.reconstruction.types import Document, Node
from scabopdf_pipeline.schema.categories import SemanticCategory

WARNING_PREFIX = "plugin:giuffre_diretto"
"""Common prefix for every warning string this plugin may emit.

See ``docs/SCHEMA_v0.5.0.md § 6`` for the rationale of the prefix
convention and :data:`WARNING_TEMPLATES` for the closed vocabulary.
"""

WARNING_TEMPLATES: tuple[str, ...] = (
    "plugin:giuffre_diretto:cross_reference_paragraph_minted_node_<id>_page_<p>",
    "plugin:giuffre_diretto:cross_reference_article_minted_node_<id>_page_<p>",
    "plugin:giuffre_diretto:cross_reference_sentence_minted_node_<id>_page_<p>",
    "plugin:giuffre_diretto:cross_reference_paragraph_unresolved_node_<id>_marker_<marker>",
    "plugin:giuffre_diretto:asterisk_footnote_isolated_block_<idx>_page_<p>",
    "plugin:giuffre_diretto:index_analitico_double_column_unordered_page_<p>",
    "plugin:giuffre_diretto:capitolo_signature_unmatched_block_<idx>_page_<p>",
    "plugin:giuffre_diretto:paragraph_heading_pattern_unmatched_block_<idx>_page_<p>",
)
"""Closed vocabulary of warnings the plugin may emit on
``Document.warnings``. Placeholders are replaced with concrete values
at emission time. Consumers should match on the prefix.

The three ``cross_reference_*_minted_*`` templates document the three
inline-rinvio sub-types (§ N, art. N c.c., Cass. <date> n. N) and are
emitted in :meth:`refine_reconstruction` once per minted Node. They
are noisy by design (~8600 instances total on the fixture) and are
intended for audit; consumers can filter by the ``_minted_`` infix.
"""

# ---------------------------------------------------------------------------
# Typographic family fragments.

BODY_FONT_PREFIX = "MScotchRoman"
"""Font family prefix of the Torrente body, marginal headings, capitolo
small-caps composite, sotto-sezione marker, and index entries.

PyMuPDF reports both ``MScotchRoman`` (Roman) and
``MScotchRoman-Italic`` (Italic) for this family; the prefix check
accepts both via :meth:`str.startswith`.
"""

HEADING_FONT_PREFIX = "TimesNewRomanPS-BoldMT"
"""Font family prefix of the HEADING_1 PARTE TEMATICA blocks and the
HEADING_4 § PARAGRAFO composite ``§`` glyph + number spans.

Distinct from the ``TimesNewRoman`` (no PS, no BoldMT) family used by
the filigrana copyright at 15.35pt — a separate fragment kept in
:data:`FILIGREE_FONT_PREFIX`.
"""

HEADING_ITAL_FONT_PREFIX = "TimesNewRomanPS-BoldItal"
"""Font family of the HEADING_4 § PARAGRAFO title span (bold italic).

PyMuPDF truncates the canonical ``TimesNewRomanPS-BoldItalic`` to
``TimesNewRomanPS-BoldItal`` in the embedded font table; the prefix
admits the truncated form.
"""

FILIGREE_FONT_PREFIX = "TimesNewRoman"
"""Font family prefix of the BIC copyright filigrana — TimesNewRoman
15.35pt.

Distinct from ``TimesNewRomanPS-BoldMT`` (the PARTE heading family).
The plugin does not classify filigrane: tier 1 generic ``filigree``
heuristic recognises them via keyword match.
"""

# ---------------------------------------------------------------------------
# Empirical sizes (PyMuPDF metrics, -0.03pt drift from nominal typesetting
# documented in the module docstring).

BODY_SIZE = 11.47
"""Body / sotto-sezione marker / capitolo composite leading-span /
front-matter & back-matter heading size, in points. Nominal 11.5pt.
"""

PARAGRAFO_SIGN_SIZE = 10.98
"""HEADING_4 § PARAGRAFO leading ``§`` glyph size, in points. Nominal 11.0pt.

The composite continues with the number span and the title span at
:data:`BODY_SIZE` (11.47pt), but the leading ``§`` glyph is at the
slightly smaller 10.98pt — the unique size discriminator for this
category.
"""

PARTE_SIZE = 12.97
"""HEADING_1 PARTE TEMATICA leading span size, in points. Nominal 13.0pt.

Unique to this category in the manual — no other content uses 12.97pt.
"""

CAPITOLO_SUBSCRIPT_SIZE = 7.73
"""HEADING_2 CAPITOLO small-caps subscript span size, in points.

The ``"APITOLO "`` tail of the small-caps three-span composite
``("C", 11.47pt) + ("APITOLO ", 7.73pt) + ("<roman>", 11.47pt)``.
Unique to this category in the manual.
"""

MARGINAL_HEADING_SIZE = 7.48
"""MARGINAL_HEADING leading-span size, in points. Nominal 7.5pt.

Unique to this category in the manual — no other block uses 7.48pt.
"""

INDEX_ENTRY_SIZE = 9.48
"""INDEX_ENTRY main-level size for both front-matter sommario and
back-matter analitico, in points. Nominal 9.5pt.
"""

INDEX_ENTRY_SUB_SIZE = 6.24
"""INDEX_ENTRY sub-level size used in the front-matter sommario for
capitolo titles indented under each parte. Nominal 6.25pt.
"""

ASTERISK_FOOTNOTE_SIZE = 7.98
"""Size of the one-off asterisk footnote on book p.7 (PDF index 6).

Distinct from :data:`MARGINAL_HEADING_SIZE` (7.48pt) and overlapping
with the Indice Analitico subtitle (also 7.98pt). The text prefix
check on ``(*)`` disambiguates.
"""

# ``SIZE_TOLERANCE`` was promoted to
# :mod:`scabopdf_pipeline.profiling.typography_constants` (P-036). The
# Torrente has tightly-clustered sizes (11.47 body, 10.98 § glyph, 12.97
# PARTE, 13.02 in adjacent categories) and the 0.15 cushion avoids edge
# misses without overlapping categories.

# ---------------------------------------------------------------------------
# Geometric thresholds.

LEFT_MARGIN_X_THRESHOLD = 80.0
"""``bbox.x0`` upper bound for a left-margin MARGINAL_HEADING block.

Empirical inspection reports left-margin marginal x0 values in the
range 34.2-66.1pt; the 80pt cap leaves a 14-pt cushion. The body
column starts at ``x ≈ 85``; the threshold leaves a 5-pt gap so a
body span with x0 just under 85 cannot pass the predicate.
"""

RIGHT_MARGIN_X_THRESHOLD = 380.0
"""``bbox.x0`` lower bound for a right-margin MARGINAL_HEADING block.

Empirical inspection reports right-margin marginal x0 essentially
constant at 402.9pt; the 380pt threshold leaves a 22-pt cushion.
The body column ends at ``x ≈ 430``; the threshold is well below
the body so a body span cannot trigger the right-margin predicate.
"""

INDEX_COLUMN_SPLIT_X = 230.0
"""``bbox.x0`` threshold separating the left column from the right
column of the back-matter Indice Analitico double-column layout on
pages 1507-1556.

Empirical inspection of the fixture reports left-column x0 ≈ 51-110
and right-column x0 ≈ 211-360 with a clean gap at x0 ∈ [166, 210]. The
230pt threshold sits in the middle of that gap. Used only by the v1
diagnostic warning ``index_analitico_double_column_unordered_page_<p>``;
a future revision will use it to actively reorder columns in
:meth:`refine_reconstruction`.
"""

SUBSECTION_PAGE_CENTER_X = 240.95
"""Page horizontal centre, in points. Half of the standard page width
481.9pt.
"""

SUBSECTION_CENTER_TOLERANCE = 60.0
"""Maximum distance in points between a sotto-sezione block's bbox
horizontal centre and the page horizontal centre.

A centered block sits at ``bbox.x_mid ≈ 240 ± 60``; an inline
enumeration sits at the body column left edge (``x_mid ≈ 200`` for the
40-character wrap or even further left for shorter spans). The 60-pt
window admits every structural sotto-sezione observed (max observed
deviation 35pt) while excluding inline ``B) Accettazione tacita.``
enumerations whose blocks centre around the body-column midpoint.
"""

PAGE_WIDTH_STANDARD = 481.9
"""Standard page width in points for the Torrente fixture. Used only by
:data:`SUBSECTION_PAGE_CENTER_X`. Outlier pages (4 pre-frontespizio
pages at 483.5pt and 1 backcover at 493.2pt) are tolerated within
:data:`SUBSECTION_CENTER_TOLERANCE`.
"""

# ---------------------------------------------------------------------------
# Page index ranges for category-by-range discrimination.

SOMMARIO_PAGE_INDEX_MIN = 4
"""First PDF page index of the front-matter Indice Sommario range.

The front matter actually opens with the title page on PDF index 1;
the Indice Sommario itself runs roughly pp.7-34 (PDF indices 6-33).
The :data:`SOMMARIO_PAGE_INDEX_MIN` cap is widened to 4 to admit any
9.48pt block in the very early front matter that happens to be
sommario-like (premessa table, etc.) without classifying body blocks
of the same size.
"""

SOMMARIO_PAGE_INDEX_MAX = 33
"""Last PDF page index of the front-matter Indice Sommario range.

The first chapter body starts on PDF index 34 (book p.1).
"""

INDEX_ANALITICO_PAGE_INDEX_MIN = 1506
"""First PDF page index of the back-matter Indice Analitico-Alfabetico
range. Book p.1507. The transition is marked by the
``"INDICE ANALITICO-ALFABETICO"`` heading on this page.
"""

INDEX_ANALITICO_PAGE_INDEX_MAX = 1556
"""Last PDF page index of the back-matter index range, before the
final ``"ABBREVIAZIONI"`` page on PDF index 1556.
"""

ABBREVIAZIONI_PAGE_INDEX = 1556
"""PDF page index of the final ``"ABBREVIAZIONI"`` page (book p.1557).

Treated as part of the back-matter Indice scope: the 9.48pt content
on this page (tabular abbreviations like ``c.c.`` ``c.p.c.`` etc.) is
classified as ``INDEX_ENTRY`` for uniformity with the analitico.
"""

# ---------------------------------------------------------------------------
# Regular expressions.

_PARTE_TEXT_PATTERN = re.compile(r"^[A-Z][A-ZÀ-ÚÌÒÈÉ '\-]+$")
"""Pattern for a PARTE TEMATICA block text: all-uppercase short phrase.

Not strictly required (the 12.97pt size is already a unique
discriminator) but used as a safety net to avoid false positives on
any hypothetical 12.97pt block that happens to carry mixed-case text.
"""

_CAPITOLO_TEXT_PATTERN = re.compile(
    r"^CAPITOLO\s+[IVXLCDM]+",
    re.IGNORECASE,
)
"""Pattern matching the joined text of a CAPITOLO block.

Anchored on a Roman-numeral prefix without trailing ``\\b``: the
PDFsharp pipeline produces a known typographic concatenation bug
where the chapter title runs into the Roman numeral with no
intervening whitespace (e.g. ``CAPITOLO XXIXLA RAPPRESENTANZA`` ←
``CAPITOLO XXIX`` + ``LA RAPPRESENTANZA``). A ``\\b`` anchor would
force the regex to find a word-boundary that does not exist when
the title opens with a Roman-numeral character like ``L``/``I``
(every greedy ``[IVXLCDM]+`` match ends followed by a word
character with no boundary in between). The relaxed regex matches
greedily and is secondary to the small-caps three-span typographic
signature; the optional ``-BIS``/``-TER``/``-QUATER`` ordinal
variants are admitted implicitly because ``[IVXLCDM]+`` captures
the Roman prefix and the rest of the line is the title.
"""

_PARAGRAFO_TEXT_PATTERN = re.compile(
    r"^§\s*\d+(?:[-\s]?(?:bis|ter|quater))?\.",
    re.IGNORECASE,
)
"""Pattern matching the joined text of a § PARAGRAFO heading.

Anchored on the ``§ N.`` prefix without a trailing post-dot whitespace
check: the PDFsharp pipeline emits the dot in the number span and the
title text in a separate bold-italic span with no joining whitespace
(``§ 1.L'ordinamento giuridico.`` is the joined block text). A
``\\.\\s+\\S`` trailer would reject every Torrente paragrafo. Numbers
are continuative 1…693 plus optional ``-bis``/``-ter``/``-quater``
variants.
"""

_PARAGRAFO_MARKER_PATTERN = re.compile(
    r"§\s*(\d+(?:[-\s]?(?:bis|ter|quater))?)",
    re.IGNORECASE,
)
"""Pattern that extracts the marker portion of a § cross-reference.

Captured group is the marker number with optional ordinal variant
(e.g. ``"130"``, ``"130-bis"``, ``"130 bis"``). The plugin normalises
to a lower-case hyphenated form via :func:`_normalise_marker` before
storing in the marker index for binding.
"""

_PARAGRAFO_TITLE_MARKER_PATTERN = re.compile(
    r"^§\s*(\d+(?:[-\s]?(?:bis|ter|quater))?)\.",
    re.IGNORECASE,
)
"""Pattern that extracts the marker portion of a HEADING_4 paragrafo
title text. Used to build the global marker → node_id index in
:meth:`refine_apparatus`.

The trailing post-dot ``\\s`` is intentionally absent: the PDFsharp
pipeline emits the dot in the number span and the title text in a
separate bold-italic span with no joining whitespace, so the joined
HEADING_4 text is ``"§ 1.L'ordinamento giuridico."`` (no space after
``1.``). Same rationale as :data:`_PARAGRAFO_TEXT_PATTERN`.
"""

_SUBSECTION_LETTER_PATTERN = re.compile(r"^[A-Z]\)\s+[A-ZÀ-Ú]")
"""Pattern matching the letter-keyed sotto-sezione marker
``^A) X``, ``^B) X``, ... The trailing character must be uppercase to
discriminate from a mid-sentence ``a) elemento`` enumeration.
"""

_SUBSECTION_ROMAN_PATTERN = re.compile(r"^[IVX]+\.\s+[A-ZÀ-Ú]")
"""Pattern matching the roman-keyed sotto-sezione marker
``^I. X``, ``^II. X``, ... The trailing character must be uppercase.
"""

_FRONT_BACK_MATTER_HEADING_PATTERN = re.compile(
    r"^(?:PREFAZIONE|INDICE\s+SOMMARIO|INDICE\s+ANALITICO-ALFABETICO|ABBREVIAZIONI)\b",
    re.IGNORECASE,
)
"""Pattern matching the top-level section labels of the front matter
and back matter. Used to promote a body-sized MScotchRoman block to
HEADING_1 when its text matches.
"""

_CROSSREF_PARAGRAPH_PATTERN = re.compile(
    r"§\s*\d+(?:[-\s]?(?:bis|ter|quater))?",
    re.IGNORECASE,
)
"""Pattern matching every inline ``§ N`` cross-reference inside BODY
text. The match span is the full marker including the leading ``§``
glyph; the plugin uses the match text verbatim as the synthetic
CROSS_REFERENCE Node's ``text``.
"""

_CROSSREF_ARTICLE_PATTERN = re.compile(
    r"art\.\s*\d+(?:[-\s]?(?:bis|ter|quater))?(?:[-\s]?\d+)?\s*(?:c\.\s*c\.|c\.c\.)",
    re.IGNORECASE,
)
"""Pattern matching every inline ``art. N c.c.`` (codice civile)
cross-reference inside BODY text. The article number admits the
optional ``-bis``/``-ter``/``-quater`` variant and a compound form
like ``art. 2659-1``. The ``c.c.`` suffix admits both spaced
(``c. c.``) and tight (``c.c.``) variants.
"""

_CROSSREF_SENTENCE_PATTERN = re.compile(
    r"Cass\.\s*(?:S\.U\.\s*)?\d{1,2}\s+\w+\s+\d{4}(?:,?\s*n\.\s*\d+)?",
)
"""Pattern matching every inline ``Cass. <date> n. <n>`` Court of
Cassation sentence citation inside BODY text. Admits an optional
``S.U.`` (Sezioni Unite) prefix between ``Cass.`` and the date. The
date is ``<day> <month-word> <year>``; the trailing ``n. <n>`` is
optional to admit citations like ``Cass. 19 luglio 2019`` without a
case number.
"""

# ---------------------------------------------------------------------------
# Match() confidence weights and thresholds.

CONFIDENCE_BODY_DOMINANT = 0.35
"""Confidence contribution when MScotchRoman 11.47pt dominates the
typographic signature above the body-share floor.

Sized to clear the 0.6 dispatcher threshold in combination with the
marginal-apparatus and filigree contributions; the Torrente body
share is roughly 62 % of total spans on the fixture.
"""

CONFIDENCE_MARGINAL_APPARATUS = 0.25
"""Confidence contribution when the marginal-heading count clears the
apparatus floor.

The Torrente apparatus signal: 4051 marginal headings reported in the
typographic signal. The single strongest discriminator vs prior
plugins (Patriarca has 0, Tesauro/Mosconi/Mandrioli have hundreds at
most).
"""

CONFIDENCE_FILIGREE_BIC = 0.15
"""Confidence contribution when the BIC copyright filigrana is present
via the TimesNewRoman 15.35pt signature.

The filigrana is unique to BIC-distributed PDFs (the Marrone uses a
different mechanism, the EdD and codici Giuffrè have none); the
combination of TimesNewRoman 15.35pt + the MScotchRoman family is
diagnostic of this profile.
"""

CONFIDENCE_PARTE_HEADING = 0.10
"""Confidence contribution when TimesNewRomanPS-BoldMT 12.97pt is
present in the typographic signature.

The PARTE TEMATICA heading family. A weaker contribution because the
family is also used by the § glyph at 10.98pt and the number span at
11.47pt — but the 12.97pt size is unique to PARTE.
"""

CONFIDENCE_PDFSHARP_PRODUCER = 0.05
"""Confidence contribution when the producer/creator string matches the
Giuffrè PDFsharp pipeline.

A weak signal (the PDFsharp 1.31 pipeline is shared with Giuffrè
codici and Annali/Tematici EdD) but a positive corroboration.
"""

CONFIDENCE_TRADITIONAL_NOTES_PENALTY = -0.30
"""Penalty when the document carries a traditional footnote apparatus.

Symmetric to the discriminator penalties of the prior plugins. The
Torrente has zero footnote markers; any document where the apparatus
presence reports a substantial ``footnote_markers`` count is not a
Torrente candidate and this plugin steps back.
"""

CONFIDENCE_OTHER_BODY_FAMILY_PENALTY = -0.20
"""Penalty when the dominant body family is not MScotchRoman.

A document whose primary body font is TimesTenLTStd, SimonciniGaramondStd,
Verdana or Times-New-Roman cannot be the Torrente. The penalty is
applied when no MScotchRoman size clears the body-dominance floor.
"""

# ``APPARATUS_PRESENCE_THRESHOLD`` was promoted to
# :mod:`scabopdf_pipeline.profiling.typography_constants` (P-035). The
# Torrente reports 4051 marginal headings; any document above the 50
# floor is a candidate. Patriarca / Tesauro / Mandrioli Vol. I-II report
# zero; the rest fail the contributions for other reasons.

NOTES_PRESENCE_THRESHOLD = 50
"""Threshold above which traditional footnote markers are considered
"present", triggering the :data:`CONFIDENCE_TRADITIONAL_NOTES_PENALTY`.
"""

BODY_DOMINANCE_MIN_PERCENT = 40.0
"""Minimum body-family dominance percent to credit the body signal.

The Torrente body dominates at ~62 %; the 40 % floor leaves headroom
while still discriminating against documents where MScotchRoman is a
minor incidental face.
"""

PDFSHARP_PRODUCER_FRAGMENT = "PDFsharp"
"""Producer/creator substring signalling the Giuffrè PDFsharp pipeline."""

BIC_FILIGREE_FRAGMENT_PATTERN = re.compile(
    r"Versione riservata|Biblioteca\s+It\.\s+Ciechi|©\s*Giuffr[èe]",
    re.IGNORECASE,
)
"""Pattern matching the BIC copyright filigrana fragment in any
ProfilingSignals specific marker. Used by :meth:`matches` if a
profiler signal carries the filigrana text as a marker; otherwise the
plugin falls back to the TimesNewRoman 15.35pt typographic check.
"""

# ---------------------------------------------------------------------------
# Helpers — block view, node-id minter, max-existing-counter walker.


@dataclass(frozen=True)
class _BlockView:
    """Pre-computed view of a block exposed to the plugin's tier 2 logic.

    The block carries its position in the flat extraction list, the
    full ``Span`` tuple, and the joined text. Every predicate inspects
    the spans directly via the indices it cares about; a leading-span
    helper is not exposed because several predicates (CAPITOLO,
    paragrafo) read multiple early spans jointly.
    """

    block_index: int
    block: Block
    spans: tuple[Span, ...]
    text: str


def _normalise_marker(raw: str) -> str:
    """Normalise a paragraph-marker text into a canonical form.

    Examples
    --------
    ``"130"``      → ``"130"``
    ``"130-bis"``  → ``"130-bis"``
    ``"130 bis"``  → ``"130-bis"``
    ``"130bis"``   → ``"130-bis"``
    ``" 130-Bis "``→ ``"130-bis"``

    The canonical form lower-cases the ordinal suffix and uses a
    hyphen-joined form. Used by :meth:`refine_apparatus` to build the
    global marker → node_id index that is consulted by the synthetic
    ``§ N`` CROSS_REFERENCE binding logic.
    """
    cleaned = raw.strip().lower()
    cleaned = re.sub(r"\s+", "-", cleaned)
    cleaned = re.sub(r"(\d)(bis|ter|quater)", r"\1-\2", cleaned)
    return cleaned


def _is_index_analitico_page(page_index: int) -> bool:
    """Return True if the page is in the back-matter Indice Analitico
    range (or the ABBREVIAZIONI page).
    """
    return INDEX_ANALITICO_PAGE_INDEX_MIN <= page_index <= ABBREVIAZIONI_PAGE_INDEX


def _is_sommario_page(page_index: int) -> bool:
    """Return True if the page is in the front-matter Indice Sommario range."""
    return SOMMARIO_PAGE_INDEX_MIN <= page_index <= SOMMARIO_PAGE_INDEX_MAX


# ---------------------------------------------------------------------------
# Main class.


class ManualeGiuffreDirectoProfile(ProfilePlugin):
    """Corpus plugin for the Giuffrè diretto manual series — Torrente-Schlesinger 25ª ed."""

    profile_id: ClassVar[str] = "manuale_giuffre_diretto"
    editorial_family: ClassVar[str] = "giuffre_diretto"
    genre: ClassVar[str] = "manuale"

    def __init__(self) -> None:
        self._pending_warnings: list[str] = []
        self._minted_crossref_ids: set[str] = set()

    # ------------------------------------------------------------------
    # ProfilePlugin declarative methods

    @classmethod
    def matches(cls, signals: ProfilingSignals) -> float:
        """Score the document against the Torrente-Schlesinger fingerprint.

        Five positive contributions (body dominance, marginal apparatus,
        BIC filigrana, PARTE heading family, PDFsharp producer) and two
        symmetric penalties (traditional notes apparatus → not Torrente;
        non-MScotchRoman body family → not Torrente). The combination
        on the fixture clears the 0.6 dispatcher threshold by a wide
        margin while staying below the threshold on the four prior
        plugins' fixtures via the body-family penalty.
        """
        score = 0.0

        body_present = any(
            font.family.startswith(BODY_FONT_PREFIX)
            and abs(font.size - BODY_SIZE) < SIZE_TOLERANCE
            and font.dominance_percent >= BODY_DOMINANCE_MIN_PERCENT
            for font in signals.typographic_signature.fonts
        )
        if body_present:
            score += CONFIDENCE_BODY_DOMINANT
        else:
            score += CONFIDENCE_OTHER_BODY_FAMILY_PENALTY

        if signals.apparatus_presence.marginal_headings >= APPARATUS_PRESENCE_THRESHOLD:
            score += CONFIDENCE_MARGINAL_APPARATUS

        filigree_present = any(
            font.family.startswith(FILIGREE_FONT_PREFIX) and abs(font.size - 15.35) < SIZE_TOLERANCE
            for font in signals.typographic_signature.fonts
        )
        if not filigree_present:
            filigree_present = any(
                marker.present and BIC_FILIGREE_FRAGMENT_PATTERN.search(str(marker.value or ""))
                for marker in signals.specific_markers
            )
        if filigree_present:
            score += CONFIDENCE_FILIGREE_BIC

        parte_family_present = any(
            font.family.startswith(HEADING_FONT_PREFIX)
            and abs(font.size - PARTE_SIZE) < SIZE_TOLERANCE
            for font in signals.typographic_signature.fonts
        )
        if parte_family_present:
            score += CONFIDENCE_PARTE_HEADING

        producer = (signals.producer_creator.producer or "").strip()
        creator = (signals.producer_creator.creator or "").strip()
        if PDFSHARP_PRODUCER_FRAGMENT in producer or PDFSHARP_PRODUCER_FRAGMENT in creator:
            score += CONFIDENCE_PDFSHARP_PRODUCER

        if signals.apparatus_presence.footnote_markers >= NOTES_PRESENCE_THRESHOLD:
            score += CONFIDENCE_TRADITIONAL_NOTES_PENALTY

        return max(0.0, score)

    def get_categories(self) -> set[SemanticCategory]:
        """Closed set of categories the plugin may emit on the Torrente
        fixture and on any other manual of the Giuffrè diretto series.
        """
        return {
            SemanticCategory.HEADING_1,
            SemanticCategory.HEADING_2,
            SemanticCategory.HEADING_3,
            SemanticCategory.HEADING_4,
            SemanticCategory.BODY,
            SemanticCategory.MARGINAL_HEADING,
            SemanticCategory.CROSS_REFERENCE,
            SemanticCategory.INDEX_ENTRY,
            SemanticCategory.NOTE,
            SemanticCategory.ARTIFACT_FILIGREE,
            SemanticCategory.ARTIFACT_RUNNING_HEADER,
            SemanticCategory.ARTIFACT_FOOTER,
            SemanticCategory.UNCLASSIFIED,
            SemanticCategory.EMPTY_PAGE,
        }

    def get_post_processing(self) -> list[str]:
        """Return the ordered list of post-processing step IDs for the
        Torrente profile.

        Only ``dehyphenate_with_log``: the empirical inspection of the
        fixture observed roughly 10 % of body lines ending in a hyphen
        followed by a lower-case word on the next line, which the
        generic Italian-lexicon dehyphenator can recover. No
        ``merge_cross_page_notes`` because the manual has zero notes;
        no ``recompose_marginal_ellipsis`` because the marginals are
        short single-line mini-headings without typographic continuation.
        """
        return ["dehyphenate_with_log"]

    def get_layouts_disabled(self) -> list[DisabledLayout]:
        """Disable Layout 4 (Dottrina Inline).

        The L4 layout renders inline footnote markers as anchored
        cross-references to a pinned notes panel. The Torrente has
        zero traditional footnote apparatus: every cross-reference is
        a textual inline rinvio (``§ N``, ``art. N c.c.``,
        ``Cass. <date> n. N``) without a bound NOTE counterpart inside
        the document, so the L4 rendering would be meaningless. Layer 2
        greys out L4 for this profile and offers L1 (linear prose),
        L2 (consultation), and L3 (structure view) instead.
        """
        return [
            DisabledLayout(
                layout="L4",
                reason=(
                    "Il manuale Torrente-Schlesinger non ha apparato note tradizionale: "
                    "ogni rinvio (§ N, art. N c.c., Cass. <data> n. N) è inline al testo. "
                    "Il layout Dottrina Inline non si applica."
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
        """Promote UNCLASSIFIED blocks to the plugin's category vocabulary.

        Single-pass sweep over the tier 1 verdicts. Tier 1 generic
        heuristics already classify the filigrana, page header
        (running-header zone) and any tiny-font anchors; the plugin
        leaves those verdicts untouched and operates only on
        UNCLASSIFIED blocks plus the rare ARTIFACT_FOOTER-residue
        rescue for blocks the y-band heuristic mis-attributed.

        Predicate order (first match wins, conservatively narrow to
        wide):

        1. Asterisk footnote on book p.7 (text starts with ``(*)`` at
           7.98pt MScotchRoman) → NOTE.
        2. MARGINAL_HEADING (leading span MScotchRoman 7.48pt at
           ``x0 < 80`` or ``x0 > 380``).
        3. HEADING_1 PARTE TEMATICA (leading span
           TimesNewRomanPS-BoldMT 12.97pt).
        4. HEADING_2 CAPITOLO (small-caps three-span pattern
           ``("C", 11.47pt) + ("APITOLO ", 7.73pt) + ("<roman>",
           11.47pt)`` AND text matches CAPITOLO regex).
        5. HEADING_4 § PARAGRAFO (leading span
           TimesNewRomanPS-BoldMT 10.98pt with text ``§ N. ...``).
        6. HEADING_3 SOTTO-SEZIONE (leading span MScotchRoman 11.47pt
           regular AND text matches ``A) X``/``I. X`` AND block is
           short AND bbox horizontally centered within the page).
        7. HEADING_1 front/back-matter sections (leading span
           MScotchRoman 11.47pt AND text matches PREFAZIONE /
           INDICE SOMMARIO / INDICE ANALITICO / ABBREVIAZIONI).
        8. INDEX_ENTRY (leading span MScotchRoman at 9.48pt or
           6.24pt on the sommario or analitico page ranges).
        9. BODY (leading span MScotchRoman 11.47pt regular or italic).

        Anything not matched by the predicates above stays UNCLASSIFIED.
        """
        self._pending_warnings = []
        self._minted_crossref_ids = set()

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
            # Tier 1 already handled this block (filigree, header zone,
            # footer zone, tiny-font anchor, superscript cross-reference).
            # Surface the diagnostic warning for INDEX_ANALITICO double-
            # column pages so the audit log records the v1 limitation.
            refined.append(verdict)

        self._emit_index_analitico_column_warnings(refined, extraction)
        return refined

    def refine_reconstruction(
        self,
        document: Document,
        extraction: ExtractionResult,
        classified_blocks: list[ClassifiedBlock],
    ) -> Document:
        """Mint synthetic inline CROSS_REFERENCE nodes and flush warnings.

        Walks every BODY Node in the tree and scans its ``text`` with
        the three inline-rinvio regex patterns (§ N, art. N c.c.,
        Cass. <date> n. <n>). For each match a synthetic
        CROSS_REFERENCE Node is appended as a sibling immediately
        after the BODY in the parent's children list, with ``text``
        set to the verbatim matched marker. The synthetic node IDs
        follow the tier 1 ``node_NNNN`` convention starting one past
        the maximum counter already assigned by tier 1.

        The synthetic Node ids are tracked in
        :attr:`_minted_crossref_ids` so :meth:`refine_apparatus` can
        (a) bind ``§ N`` Nodes globally to their HEADING_4 target and
        (b) filter the tier 1 generic resolver's noisy
        ``unparseable_cross_reference_*`` warnings on every minted
        Node.

        Pending warnings queued by :meth:`refine_classification` are
        flushed into ``Document.warnings`` here together with the
        per-mint warnings produced by this method.
        """
        del classified_blocks

        new_warnings = list(self._pending_warnings)
        self._pending_warnings = []

        minter = NodeIdMinter(start=max_existing_node_counter(document.root) + 1)
        new_roots = self._mint_cross_references_in_forest(document.root, new_warnings, minter)

        return Document(
            root=new_roots,
            warnings=tuple(document.warnings) + tuple(new_warnings),
            transformations=document.transformations,
        )

    def refine_apparatus(
        self,
        document: Document,
        extraction: ExtractionResult,
        classified_blocks: list[ClassifiedBlock],
    ) -> Document:
        """Bind synthetic ``§ N`` cross-references globally and filter
        the noisy tier 1 ``unparseable_cross_reference_*`` warnings on
        every Node this plugin minted.

        Three responsibilities:

        1. Build a global marker → node_id index over the full
           document tree by scanning every HEADING_4 paragrafo title
           with :data:`_PARAGRAFO_TITLE_MARKER_PATTERN` and storing
           the canonical marker form (via :func:`_normalise_marker`).
        2. Walk every synthetic CROSS_REFERENCE Node minted by
           :meth:`refine_reconstruction` (identified by ``id`` in
           :attr:`_minted_crossref_ids`); for nodes whose text starts
           with ``"§"``, extract the marker, look it up in the index,
           and attach an :class:`ApparatusRef` with
           ``CROSS_REF_TARGET``. ``art.`` and ``Cass.`` synthetic
           Nodes have no internal binding target and are left as is.
        3. Filter the Document's warnings tuple to drop every tier 1
           ``unparseable_cross_reference_node_<id>`` and
           ``unresolved_cross_reference_node_<id>_n_<N>`` string whose
           ``<id>`` belongs to one of this plugin's synthetic Nodes
           (the tier 1 resolver fails universally on every Torrente
           cross-reference because the generic
           ``CROSS_REF_DIGITS_REGEX`` requires the text to be a pure
           digit, which the Torrente marker never is). Profile-level
           ``cross_reference_paragraph_unresolved_node_<id>_marker_<marker>``
           warnings are emitted for any ``§ N`` synthetic Node whose
           marker is not present in the global index.
        """
        del extraction, classified_blocks

        marker_index = self._build_paragraph_marker_index(document.root)
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
        if self._is_asterisk_footnote(view):
            self._pending_warnings.append(
                f"{WARNING_PREFIX}:asterisk_footnote_isolated_block_"
                f"{verdict.block_index}_page_{view.block.page}"
            )
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.NOTE,
                reason="giuffre_diretto_asterisk_footnote",
            )

        if self._is_marginal_heading(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.MARGINAL_HEADING,
                reason="giuffre_diretto_marginal_heading",
            )

        if self._is_parte_signature(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.HEADING_1,
                reason="giuffre_diretto_parte_tematica",
            )

        if self._is_capitolo_signature(view):
            if not _CAPITOLO_TEXT_PATTERN.match(view.text.strip()):
                self._pending_warnings.append(
                    f"{WARNING_PREFIX}:capitolo_signature_unmatched_block_"
                    f"{verdict.block_index}_page_{view.block.page}"
                )
                return verdict
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.HEADING_2,
                reason="giuffre_diretto_capitolo",
            )

        if self._is_paragrafo_signature(view):
            if not _PARAGRAFO_TEXT_PATTERN.match(view.text.strip()):
                self._pending_warnings.append(
                    f"{WARNING_PREFIX}:paragraph_heading_pattern_unmatched_block_"
                    f"{verdict.block_index}_page_{view.block.page}"
                )
                return verdict
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.HEADING_4,
                reason="giuffre_diretto_paragrafo",
            )

        if self._is_sotto_sezione(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.HEADING_3,
                reason="giuffre_diretto_sotto_sezione",
            )

        if self._is_front_back_matter_heading(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.HEADING_1,
                reason="giuffre_diretto_front_back_matter_heading",
            )

        if self._is_index_entry(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.INDEX_ENTRY,
                reason="giuffre_diretto_index_entry",
            )

        if self._is_body_signature(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.BODY,
                reason="giuffre_diretto_body",
            )

        return verdict

    # ------------------------------------------------------------------
    # Signature predicates

    @staticmethod
    def _is_asterisk_footnote(view: _BlockView) -> bool:
        """A one-off ``(*)`` footnote at 7.98pt MScotchRoman on book p.7."""
        if not view.spans:
            return False
        leading = view.spans[0]
        family_ok = leading.font.startswith(BODY_FONT_PREFIX)
        size_ok = abs(leading.size - ASTERISK_FOOTNOTE_SIZE) < SIZE_TOLERANCE
        if not (family_ok and size_ok):
            return False
        return view.text.lstrip().startswith("(*)")

    @staticmethod
    def _is_marginal_heading(view: _BlockView) -> bool:
        """A MARGINAL_HEADING block sits against the page edge at 7.48pt."""
        if not view.spans:
            return False
        leading = view.spans[0]
        family_ok = leading.font.startswith(BODY_FONT_PREFIX)
        size_ok = abs(leading.size - MARGINAL_HEADING_SIZE) < SIZE_TOLERANCE
        if not (family_ok and size_ok):
            return False
        x0 = view.block.bbox[0]
        return x0 < LEFT_MARGIN_X_THRESHOLD or x0 > RIGHT_MARGIN_X_THRESHOLD

    @staticmethod
    def _is_parte_signature(view: _BlockView) -> bool:
        """A HEADING_1 PARTE TEMATICA block opens with TimesNewRomanPS-BoldMT 12.97pt.

        The 12.97pt size is unique to this category in the manual.
        Multi-line PARTE titles (e.g. "L'ATTIVITÀ GIURIDICA / E LA TUTELA
        GIURISDIZIONALE DEI DIRITTI") have all spans at 12.97pt; the
        predicate checks the leading span only.
        """
        if not view.spans:
            return False
        leading = view.spans[0]
        family_ok = leading.font.startswith(HEADING_FONT_PREFIX)
        size_ok = abs(leading.size - PARTE_SIZE) < SIZE_TOLERANCE
        return family_ok and size_ok

    @staticmethod
    def _is_capitolo_signature(view: _BlockView) -> bool:
        """A HEADING_2 CAPITOLO block opens with the small-caps three-span
        composite ``("C", 11.47pt) + ("APITOLO ", 7.73pt) + ("<roman>",
        11.47pt)``.

        The predicate verifies the size pair (11.47pt + 7.73pt) jointly
        on the first two spans plus the textual ``"C"`` + ``"APITOLO"``
        prefix. The small-caps subscript at 7.73pt is unique to this
        category in the manual.
        """
        if len(view.spans) < 3:
            return False
        s0, s1, s2 = view.spans[0], view.spans[1], view.spans[2]
        if not (
            s0.font.startswith(BODY_FONT_PREFIX)
            and abs(s0.size - BODY_SIZE) < SIZE_TOLERANCE
            and s0.text == "C"
        ):
            return False
        if not (
            s1.font.startswith(BODY_FONT_PREFIX)
            and abs(s1.size - CAPITOLO_SUBSCRIPT_SIZE) < SIZE_TOLERANCE
            and s1.text.startswith("APITOLO")
        ):
            return False
        return s2.font.startswith(BODY_FONT_PREFIX) and abs(s2.size - BODY_SIZE) < SIZE_TOLERANCE

    @staticmethod
    def _is_paragrafo_signature(view: _BlockView) -> bool:
        """A HEADING_4 § PARAGRAFO block opens with TimesNewRomanPS-BoldMT
        10.98pt carrying the ``§`` glyph.

        The leading span at 10.98pt is unique to this category; the
        predicate is therefore a pure signature check and the text
        pattern is verified separately in :meth:`_reclassify`.
        """
        if not view.spans:
            return False
        leading = view.spans[0]
        family_ok = leading.font.startswith(HEADING_FONT_PREFIX)
        size_ok = abs(leading.size - PARAGRAFO_SIGN_SIZE) < SIZE_TOLERANCE
        if not (family_ok and size_ok):
            return False
        return leading.text.lstrip().startswith("§")

    @staticmethod
    def _is_sotto_sezione(view: _BlockView) -> bool:
        """A HEADING_3 SOTTO-SEZIONE block opens with MScotchRoman 11.47pt
        regular AND its text matches ``A) X`` or ``I. X`` AND it is
        bbox-centered on the page AND it is short.

        The three guards together discriminate the 58 structural
        sotto-sezioni from inline ``B) Accettazione tacita.``
        enumerations inside body paragraphs (which sit at the body
        column ``x0 ≈ 51``, fail the centering check, and are usually
        longer than the cap because the enumeration is inline within
        a regular body block).
        """
        if not view.spans:
            return False
        leading = view.spans[0]
        family_ok = leading.font.startswith(BODY_FONT_PREFIX)
        size_ok = abs(leading.size - BODY_SIZE) < SIZE_TOLERANCE
        if not (family_ok and size_ok):
            return False
        text = view.text.strip()
        if len(text) >= 200:
            return False
        if not (_SUBSECTION_LETTER_PATTERN.match(text) or _SUBSECTION_ROMAN_PATTERN.match(text)):
            return False
        return is_centered_x(
            view.block.bbox,
            page_center_x=SUBSECTION_PAGE_CENTER_X,
            tolerance=SUBSECTION_CENTER_TOLERANCE,
        )

    @staticmethod
    def _is_front_back_matter_heading(view: _BlockView) -> bool:
        """A HEADING_1 front/back-matter section label.

        Short MScotchRoman 11.47pt block whose text matches PREFAZIONE
        / INDICE SOMMARIO / INDICE ANALITICO-ALFABETICO / ABBREVIAZIONI.
        """
        if not view.spans:
            return False
        leading = view.spans[0]
        family_ok = leading.font.startswith(BODY_FONT_PREFIX)
        size_ok = abs(leading.size - BODY_SIZE) < SIZE_TOLERANCE
        if not (family_ok and size_ok):
            return False
        text = view.text.strip()
        if len(text) >= 200:
            return False
        return bool(_FRONT_BACK_MATTER_HEADING_PATTERN.match(text))

    @staticmethod
    def _is_index_entry(view: _BlockView) -> bool:
        """An INDEX_ENTRY block sits on the sommario or analitico pages
        with MScotchRoman 9.48pt or 6.24pt leading span.
        """
        if not view.spans:
            return False
        leading = view.spans[0]
        if not leading.font.startswith(BODY_FONT_PREFIX):
            return False
        size_ok = (
            abs(leading.size - INDEX_ENTRY_SIZE) < SIZE_TOLERANCE
            or abs(leading.size - INDEX_ENTRY_SUB_SIZE) < SIZE_TOLERANCE
        )
        if not size_ok:
            return False
        page = view.block.page
        return _is_sommario_page(page) or _is_index_analitico_page(page)

    @staticmethod
    def _is_body_signature(view: _BlockView) -> bool:
        """A BODY block opens with MScotchRoman or MScotchRoman-Italic at 11.47pt."""
        if not view.spans:
            return False
        leading = view.spans[0]
        family_ok = leading.font.startswith(BODY_FONT_PREFIX)
        size_ok = abs(leading.size - BODY_SIZE) < SIZE_TOLERANCE
        return family_ok and size_ok

    # ------------------------------------------------------------------
    # Index analitico column warnings

    def _emit_index_analitico_column_warnings(
        self,
        refined: list[ClassifiedBlock],
        extraction: ExtractionResult,
    ) -> None:
        """Emit the one-warning-per-page diagnostic for the back-matter
        Indice Analitico double-column ordering limitation.

        The tier 1 mono-column ``(page, y0, x0)`` reading-order sort
        interleaves left and right column blocks; the v1 plugin
        classifies them as INDEX_ENTRY without reordering. The warning
        surfaces the limitation for the audit log; a future revision
        can reorder columns in :meth:`refine_reconstruction` and stop
        emitting the warning.
        """
        pages_with_entries: set[int] = set()
        for verdict in refined:
            if verdict.category is not SemanticCategory.INDEX_ENTRY:
                continue
            if verdict.block_index < 0 or verdict.block_index >= len(extraction.blocks):
                continue
            page = extraction.blocks[verdict.block_index].page
            if _is_index_analitico_page(page):
                pages_with_entries.add(page)
        for page in sorted(pages_with_entries):
            self._pending_warnings.append(
                f"{WARNING_PREFIX}:index_analitico_double_column_unordered_page_{page}"
            )

    # ------------------------------------------------------------------
    # Synthetic cross-reference minting (refine_reconstruction)

    def _mint_cross_references_in_forest(
        self,
        roots: tuple[Node, ...],
        warnings: list[str],
        minter: NodeIdMinter,
    ) -> tuple[Node, ...]:
        """Walk the forest pre-order, minting CROSS_REFERENCE siblings
        after every BODY Node with inline rinvii in its text.
        """
        out: list[Node] = []
        for node in roots:
            new_children = self._mint_cross_references_in_forest(node.children, warnings, minter)
            if new_children != node.children:
                node = replace(node, children=new_children)
            out.append(node)
            if node.category is SemanticCategory.BODY and node.text:
                out.extend(self._mint_for_body(node, warnings, minter))
        return tuple(out)

    def _mint_for_body(
        self,
        body: Node,
        warnings: list[str],
        minter: NodeIdMinter,
    ) -> list[Node]:
        """Mint synthetic CROSS_REFERENCE nodes for every inline rinvio
        match inside ``body.text``.

        Order of patterns inside the same text:
        :data:`_CROSSREF_PARAGRAPH_PATTERN`,
        :data:`_CROSSREF_ARTICLE_PATTERN`,
        :data:`_CROSSREF_SENTENCE_PATTERN`. Matches are emitted in
        their textual occurrence order across the patterns combined.

        The patterns are mutually disjoint by design — ``§`` is the
        unique leading char of the paragraph pattern, ``art.`` of the
        article pattern, ``Cass.`` of the sentence pattern — so no
        match overlaps. The block_indices and page_index of each
        synthetic Node mirror the host BODY's.
        """
        assert body.text is not None
        matches: list[tuple[int, str, str]] = []  # (start_pos, subtype, marker_text)
        for m in _CROSSREF_PARAGRAPH_PATTERN.finditer(body.text):
            matches.append((m.start(), "paragraph", m.group(0)))
        for m in _CROSSREF_ARTICLE_PATTERN.finditer(body.text):
            matches.append((m.start(), "article", m.group(0)))
        for m in _CROSSREF_SENTENCE_PATTERN.finditer(body.text):
            matches.append((m.start(), "sentence", m.group(0)))
        matches.sort(key=lambda t: t[0])

        minted: list[Node] = []
        for _, subtype, marker_text in matches:
            crossref = Node(
                id=minter.mint(),
                category=SemanticCategory.CROSS_REFERENCE,
                page_index=body.page_index,
                block_indices=body.block_indices,
                text=marker_text,
            )
            minted.append(crossref)
            self._minted_crossref_ids.add(crossref.id)
            warnings.append(
                f"{WARNING_PREFIX}:cross_reference_{subtype}_minted_node_"
                f"{crossref.id}_page_{crossref.page_index}"
            )
        return minted

    # ------------------------------------------------------------------
    # Global paragraph-marker index + binding (refine_apparatus)

    @staticmethod
    def _build_paragraph_marker_index(roots: tuple[Node, ...]) -> dict[str, str]:
        """Build a canonical marker → HEADING_4 node_id map.

        Walks every HEADING_4 paragrafo node in the document tree,
        parses its text with :data:`_PARAGRAFO_TITLE_MARKER_PATTERN`
        to extract the marker, normalises via :func:`_normalise_marker`
        and stores the mapping. On collision (two HEADING_4 with the
        same canonical marker, which the empirical inspection
        confirmed does not happen on the Torrente fixture) the first
        wins.
        """
        index: dict[str, str] = {}
        for node in iter_nodes_pre_order(roots):
            if node.category is not SemanticCategory.HEADING_4:
                continue
            if node.text is None:
                continue
            match = _PARAGRAFO_TITLE_MARKER_PATTERN.match(node.text.strip())
            if match is None:
                continue
            canonical = _normalise_marker(match.group(1))
            index.setdefault(canonical, node.id)
        return index

    def _bind_cross_references_globally(
        self,
        roots: tuple[Node, ...],
        marker_index: dict[str, str],
    ) -> tuple[tuple[Node, ...], list[str]]:
        """Walk the forest, bind every synthetic ``§ N`` CROSS_REFERENCE
        Node to its HEADING_4 target, and emit unresolved warnings.

        Returns the rebuilt forest and the list of new warnings.
        Synthetic art./Cass. CROSS_REFERENCE Nodes are left with empty
        ``apparatus_refs`` (no internal binding target).
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
                stripped = node.text.lstrip()
                if stripped.startswith("§"):
                    match = _PARAGRAFO_MARKER_PATTERN.match(stripped)
                    if match is not None:
                        canonical = _normalise_marker(match.group(1))
                        target_id = marker_index.get(canonical)
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
                                f"{WARNING_PREFIX}:cross_reference_paragraph_unresolved_node_"
                                f"{node.id}_marker_{canonical}"
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

        The tier 1 generic resolver in
        :mod:`scabopdf_pipeline.apparatus.resolver` emits a warning per
        synthetic Node whose text never matches its generic
        ``CROSS_REF_DIGITS_REGEX`` pattern (which requires a pure-digit
        text). The plugin owns the synthetic Nodes and resolves the
        bindable subset (``§ N``) via its own global marker index, so
        the tier 1 warnings are uninformative noise.

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
