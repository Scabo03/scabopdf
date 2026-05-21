# ruff: noqa: RUF001, RUF002
r"""Corpus plugin for the Enciclopedia del Diritto Giuffrè — native modern variant.

Tenth real corpus plugin of the project and **first plugin operating on
the SimonciniGaramond editorial pipeline** of the Giuffrè Enciclopedia
del Diritto (EdD). Handles the **native** modern variant of the EdD,
spanning the Aggiornamenti (1989-2003), Annali (2007-2014) and Tematici
(2021+) volumes, all sharing the same typographic system (SimonciniGaramond
9.0pt body / 7.5pt note / 5.0pt apici / 9.0pt bold heading / 6.5pt
sommario / TimesNewRoman 12.0pt footer ente / Helvetica-Bold 6.0pt
copyright stamp) and the same two-column geometry. The historical
variant (Volumes I-XLVI 1958-1985, Times-Roman OCR via Adobe Paper
Capture) is handled by the sister plugin
:class:`~scabopdf_pipeline.profiles.enciclopedia_storica.EnciclopediaStoricaProfile`.

Calibrated on three private fixtures spanning the genre's editorial
continuum:

- ``pipeline/tests/fixtures/private/edd_abuso_posizione_dominante.pdf``
  (52 pp, PDFsharp 2012) — voce-saggio singola monografica with
  drop-cap iniziale, dense apparato note (~186 notes including the
  bimodal distribution of brief bibliographic citations and "saggio"
  notes up to ~5242 chars), 10 Sezioni romane internal divisions.
- ``pipeline/tests/fixtures/private/edd_factoring.pdf`` (14 pp,
  PDFsharp 2025) — voce-saggio dei Tematici geometria 482×699 with
  drop-cap iniziale, 16 paragrafi numerati flat (no Sezioni), 95
  notes with balanced distribution, 12 ``v. NOMEVOCE`` cross-references
  intra-EdD.
- ``pipeline/tests/fixtures/private/edd_giudizio_legittimita_costituzionale.pdf``
  (69 pp, Acrobat Distiller 4.0 2001) — voce-saggio constitutional law
  with **no drop-cap** (Distiller pipeline does not emit it as text
  span), dense apparato (~396 notes, 51 ``v.`` cross-references), 21
  Sezioni romane.

The three fixtures combined exercise three different producer pipelines
(PDFsharp 2012, PDFsharp 2025, Acrobat Distiller 2001) within the same
typographic system, confirming that the SimonciniGaramond signature is
**producer-invariant** (also confirmed by the analysis § 12.1 across
five empirical campioni 1997-2025) and that ``matches()`` must lean on
typography rather than producer.

Schema invariato a 0.5.0. The plugin lights up three EdD-specific
categories declared at 0.5.0 but never used in production until this
landing:

- ``HEADING_LETTER_INITIAL``: the drop-cap iniziale gigante 35.92pt of
  voces opening a new alphabetic section in the source volume (analysis
  § 12.6). Present in PDFsharp fixtures (Abuso, Factoring), absent in
  the Distiller fixture (Giudizio legittimità). Classified as a
  decoration that Layer 2 may hide from VoiceOver
  (``accessibilityElementsHidden = true`` semantics).
- ``FONTI``: the explicit FONTI bibliographic section (norme richiamate)
  preceding LETTERATURA. Triggered by the ``FONTI.`` label block; the
  subsequent BODY blocks up to the next SECTION_LABEL or end of
  document are retagged as ``FONTI``.
- ``LETTERATURA``: the explicit LETTERATURA bibliographic section
  (final apparato). Triggered by the ``LETTERATURA.`` label block;
  subsequent BODY blocks are retagged as ``LETTERATURA``.

No schema bump, no contract.py update, no converter.py change, no
docs/SCHEMA_v0.5.0.md update — the three categories were already
declared in the 0.5.0 ``SemanticCategory`` enum.

Pipeline integration.

- :meth:`get_post_processing` returns
  ``["dehyphenate_with_log", "merge_cross_page_notes"]``. EdD moderna
  has 25-30 sillabazioni per pagina from the two-column tight
  justification (legitimate editorial hyphenation, not OCR noise), and
  notes that frequently continue across page breaks (~31-46 % rate per
  the analysis empirical numbers); both steps are applicable.
- :meth:`get_layouts_disabled` returns ``[]``. Every layout is enabled.
- :meth:`refine_apparatus` performs two profile-specific actions:
  (a) walk every synthetic ``CROSS_REFERENCE`` Node minted in
  :meth:`refine_reconstruction`, extract the marker, look up in the
  global ``marker → NOTE node_id`` index, and attach an
  :class:`ApparatusRef` of kind ``CROSS_REF_TARGET``; (b) filter the
  Document's warnings tuple to drop tier 1 generic resolver warnings on
  the plugin's synthetic Nodes (same convention as NS, DT, Torrente).

Closed warning vocabulary, prefix ``plugin:enciclopedia_moderna:``.
See :data:`WARNING_TEMPLATES`.

New structural patterns introduced by this plugin (numbered after the
DT plugin's (ww) per the CLAUDE.md convention):

- **(xx) HEADING_LETTER_INITIAL minted from a typographic super-size
  drop-cap span**, when an editorial pipeline emits the first letter
  of a voce opening a new alphabetic section in the source volume as
  a single-character span at a size >> body (~35.9pt SimonciniGaramond
  vs ~9.0pt body in EdD moderna). The predicate
  :meth:`_is_letter_initial_drop_cap` checks for a single uppercase
  ASCII letter at size > :data:`DROP_CAP_MIN_SIZE`. Reusable by any
  future corpus that uses a similar typographic device.

- **(yy) FONTI / LETTERATURA region retagging in
  refine_classification via stateful walk**, when an editorial pipeline
  emits two distinct named bibliographic apparatus sections at the
  end of the voce. The plugin's classifier walks the tier 1 verdicts
  in reading order: when ``SECTION_LABEL`` ``"FONTI."`` is encountered,
  sets ``in_fonti=True``; subsequent BODY blocks are retagged as
  ``FONTI``. When ``SECTION_LABEL`` ``"LETTERATURA."`` is encountered,
  switches to ``in_letteratura=True``. The two regions are mutually
  exclusive and the walker terminates at end-of-document. The pattern
  is structurally identical to the NS (pp) notes-region retagging but
  scoped to two named sections rather than one. Reusable by any corpus
  with named bibliographic sections terminating the document.

- **(zz) Intra-corpus CROSS_REFERENCE multi-subtype minting via two
  regex patterns**, when a corpus uses two textually-distinct inline
  reference forms (EdD moderna uses both ``(N)`` numbered footnote
  markers and ``v. NOMEVOCE[, ANNO]`` intra-EdD voice references).
  The plugin's :meth:`_maybe_mint_cross_references` runs the two
  regex patterns in sequence over the BODY text and mints one synthetic
  CROSS_REFERENCE Node per match, encoding the subtype in the leading
  character of ``Node.text`` (``"("`` for numbered footnote, ``"v."``
  for intra-EdD voice). Generalises Torrente pattern (cc) which uses
  three patterns for ``§``, ``art.``, ``Cass.``; here two patterns
  serve the same purpose. The per-mint warning template encodes the
  subtype (``cross_reference_note_minted_*`` vs
  ``cross_reference_voce_minted_*``).
"""

from __future__ import annotations

import re
from dataclasses import dataclass, replace
from typing import ClassVar

from scabopdf_pipeline.apparatus.constants import (
    INLINE_PARENTHESISED_CROSSREF_REGEX as _CROSSREF_INLINE_NOTE_PATTERN,
)
from scabopdf_pipeline.apparatus.constants import (
    LEADING_PARENTHESISED_NOTE_MARKER_REGEX as _NOTE_LEADING_MARKER_PATTERN,
)
from scabopdf_pipeline.apparatus.resolver import filter_tier1_crossref_warnings
from scabopdf_pipeline.apparatus.types import ApparatusRef, ApparatusRefKind
from scabopdf_pipeline.classification.types import ClassifiedBlock
from scabopdf_pipeline.extraction.types import Block, ExtractionResult, Span
from scabopdf_pipeline.postprocessing.types import Transformation
from scabopdf_pipeline.profiling.plugin import ProfilePlugin
from scabopdf_pipeline.profiling.profile import DisabledLayout
from scabopdf_pipeline.profiling.signals import ProfilingSignals
from scabopdf_pipeline.profiling.typography_constants import SIZE_TOLERANCE
from scabopdf_pipeline.reconstruction.minting import (
    NodeIdMinter,
    iter_nodes_pre_order,
    max_existing_node_counter,
)
from scabopdf_pipeline.reconstruction.types import (
    Document,
    Node,
    TocGeneralItem,
)
from scabopdf_pipeline.schema.categories import SemanticCategory

WARNING_PREFIX = "plugin:enciclopedia_moderna"
"""Common prefix for every warning string this plugin may emit."""

WARNING_TEMPLATES: tuple[str, ...] = (
    "plugin:enciclopedia_moderna:drop_cap_letter_initial_block_<idx>_page_<p>",
    "plugin:enciclopedia_moderna:fonti_section_opened_block_<idx>_page_<p>",
    "plugin:enciclopedia_moderna:letteratura_section_opened_block_<idx>_page_<p>",
    "plugin:enciclopedia_moderna:toc_general_parsed_node_<id>_items_<n>",
    "plugin:enciclopedia_moderna:toc_general_unparseable_node_<id>",
    "plugin:enciclopedia_moderna:cross_reference_note_minted_node_<id>_page_<p>_marker_<n>",
    "plugin:enciclopedia_moderna:cross_reference_voce_minted_node_<id>_page_<p>_voce_<v>",
    "plugin:enciclopedia_moderna:cross_reference_note_unresolved_node_<id>_marker_<n>",
)
"""Closed vocabulary of warnings the plugin may emit. Placeholders
``<idx>``, ``<id>``, ``<p>``, ``<n>``, ``<v>`` are replaced with concrete
values at emission time.
"""

# ---------------------------------------------------------------------------
# Typographic family names (exact match — EdD uses ``SimonciniGaramond``,
# the Giappichelli/Mandrioli plugin uses ``SimonciniGaramondStd`` and they
# must not collide).

SIMONCINI_REGULAR_FAMILY = "SimonciniGaramond"
"""Exact family of the regular SimonciniGaramond spans (body, note, apici,
sommario, page number, drop-cap)."""

SIMONCINI_BOLD_FAMILY = "SimonciniGaramond-Bold"
"""Exact family of the SimonciniGaramond bold spans (heading paragrafo
numerato, Sezione, title voce, FONTI/LETTERATURA labels)."""

SIMONCINI_ITALIC_FAMILY = "SimonciniGaramond-Italic"
"""Exact family of the SimonciniGaramond italic spans (italic notes,
italic body, italic sommario)."""

TIMES_NEW_ROMAN_FAMILY = "TimesNewRoman"
"""Exact family of the TimesNewRoman footer ente span."""

HELVETICA_BOLD_FAMILY_FRAGMENT = "Helvetica-Bold"
"""Family-prefix of the Helvetica-Bold copyright stamp span. Uses
prefix match because PyMuPDF may emit either the exact family or a
subset-truncated variant on some pipelines.
"""

# ---------------------------------------------------------------------------
# Empirical sizes (PyMuPDF reports a uniform -0.02pt drift below nominal on
# the SimonciniGaramond family across all PDFsharp/PDFlib/Distiller pipelines
# observed; the tolerance below absorbs the drift plus measurement noise).

BODY_SIZE = 9.0
"""Nominal body size. PyMuPDF emits 8.98pt empirically."""

NOTE_SIZE = 7.5
"""Nominal note size. PyMuPDF emits 7.48pt empirically."""

APICE_SIZE = 5.0
"""Nominal apice / footnote marker size. PyMuPDF emits 4.99pt
empirically."""

SOMMARIO_SIZE = 6.5
"""Nominal sommario size. PyMuPDF emits 6.49pt empirically."""

PAGE_NUMBER_SIZE = 12.0
"""Nominal page number size (SimonciniGaramond regular). PyMuPDF emits
11.97pt empirically."""

FOOTER_ENTE_SIZE = 12.0
"""Nominal footer ente size (TimesNewRoman regular). Exact match on
PyMuPDF (no drift on TimesNewRoman across the observed pipelines).
"""

COPYRIGHT_SIZE = 6.0
"""Nominal copyright stamp size (Helvetica-Bold)."""

DROP_CAP_MIN_SIZE = 30.0
"""Minimum size threshold for the drop-cap iniziale. The empirical
value is 35.92pt across the two PDFsharp fixtures; using a 30.0pt
floor leaves head-room for future variants while remaining well above
any text body size in the typographic system.
"""

# ``SIZE_TOLERANCE`` was promoted to
# :mod:`scabopdf_pipeline.profiling.typography_constants` (P-036). The
# 0.15pt cushion is appropriate for ``SimonciniGaramond`` and
# ``SimonciniGaramondStd`` (uniform -0.02pt drift below nominal), and
# remains below the 0.5pt inter-category gap of the EdD typographic
# system.

# ---------------------------------------------------------------------------
# Page geometry tolerance.
#
# The empirical inspection found three distinct geometries across the
# three calibrating fixtures: (~482x680), (~482x699 Tematici/Annali),
# (~482x680 again for Distiller). The analysis additionally documents
# (~504x725) for the Aggiornamenti pre-2014. The plugin admits any
# height in [670, 730] and any width in [475, 510] as a "EdD-like"
# geometry; tighter checks risk false negatives on legitimate variants.

PAGE_WIDTH_MIN = 475.0
PAGE_WIDTH_MAX = 580.0
PAGE_HEIGHT_MIN = 670.0
PAGE_HEIGHT_MAX = 730.0

# The 580pt upper bound on width covers the Acrobat Distiller 4.0 (2001)
# pipeline whose mediabox declares 567pt while the rendered page rect is
# ~482pt; both are legitimate EdD moderna geometries.

# ---------------------------------------------------------------------------
# Closed text predicates.

FOOTER_ENTE_TEXT_FRAGMENT = "Enciclopedia del Diritto"
"""Text fragment unique to the footer ente line."""

COPYRIGHT_STAMP_TEXT_FRAGMENTS: tuple[str, ...] = (
    "Copyright Giuffr",
    "RIPRODUZIONE RISERVATA",
)
"""Closed set of substrings that identify the copyright stamp."""

# ---------------------------------------------------------------------------
# Regular expressions.

_PARAGRAPH_HEADING_PATTERN = re.compile(r"^\s*(\d{1,3})\.\s+\S")
"""Pattern matching a numbered paragrafo heading.

Body weight: ``SimonciniGaramond-Bold`` 9pt. Captures the paragrafo
number. Constrained to 1-3 digits to avoid catching pagination
fragments.
"""

_SEZIONE_HEADING_PATTERN = re.compile(r"^\s*Sez\.\s+([IVXLCDM]+)\.")
"""Pattern matching a Sezione romana heading.

Body weight: ``SimonciniGaramond-Bold`` 9pt. Captures the Roman
numeral. The trailing period is required to avoid catching abbreviations
like ``Sez. I (`` that may sit inline in the body.
"""

_FONTI_LABEL_PATTERN = re.compile(r"^\s*FONTI\s*\.\s*[—\-]?")
"""Pattern matching the FONTI section opening label.

Either ``"FONTI. — "`` or ``"FONTI. - "`` or ``"FONTI."``. Body
weight ``SimonciniGaramond-Bold`` 9pt.
"""

_LETTERATURA_LABEL_PATTERN = re.compile(r"^\s*LETTERATURA\s*\.\s*[—\-]?")
"""Pattern matching the LETTERATURA section opening label.

Either ``"LETTERATURA. — "`` or ``"LETTERATURA. - "`` or
``"LETTERATURA."``. Body weight ``SimonciniGaramond-Bold`` 9pt.
"""

_SOMMARIO_TRIM_PATTERN = re.compile(r"^\s*S\s*OMMARIO\s*:?\s*", re.IGNORECASE)
"""Pattern that strips the leading ``"SOMMARIO:"`` or ``"S OMMARIO :"``
prefix from the sommario block before TOC parsing.

EdD typesets the sommario label as a small-caps three-span composite:
``("S", 6.49pt) + ("OMMARIO", 4.24pt) + (":", 6.49pt)``. After joining
the spans in the Node text the result is ``"SOMMARIO:"``. The trim
pattern accepts the optional internal whitespace from the span join
and the optional trailing colon.
"""

_TOC_ITEM_PATTERN = re.compile(r"^(\d+(?:\.\d+)?)\.\s+(.+?)\.?\s*$")
"""Pattern matching a single TOC entry ``"N. Title"`` after the sommario
trim. Capture groups: the number (which may be composite like
``"1.1"``) and the title.
"""

# ``_NOTE_LEADING_MARKER_PATTERN`` and ``_CROSSREF_INLINE_NOTE_PATTERN``
# were promoted to :mod:`apparatus.constants` (P-014). The plugin
# imports them at the top of the module under the legacy
# underscore-prefixed aliases.

_CROSSREF_INLINE_VOCE_PATTERN = re.compile(
    r"v\.\s+([A-ZÀÈÉÌÒÓÙ][A-ZÀÈÉÌÒÓÙ\s()/,'`’\.\-]{2,}?)(?=[.;,)]|\s+[a-z]|\Z|\s*$)"
)
"""Pattern matching every inline ``v. NOMEVOCE[, ANNO]`` intra-EdD
voice reference.

The voce name may carry parentheticals, slashes, apostrophes, commas
and hyphens; the lookahead caps the match before any lowercase
continuation (Italian prose resumes lowercase after an all-caps
voice name), before structural punctuation, or at end-of-string.
The optional year (e.g. ``", 2021"``) introduced by the Tematici
post-2021 is captured inside the voce name and preserved in the
synthetic Node text verbatim.
"""

_CROSSREF_MAX_MARKER_VALUE = 500
"""Magnitude cap on inline numbered cross-reference markers. Above this
threshold the ``(N)`` is interpreted as a year or sentence number, not
a footnote marker.
"""

# ---------------------------------------------------------------------------
# Match() confidence weights and thresholds.

CONFIDENCE_SIMONCINI_BODY_DOMINANT = 0.45
"""Confidence contribution when ``SimonciniGaramond`` (EXACT match, not
prefix) at body size dominates the typographic signature.

Strong contribution because the SimonciniGaramond family is the
single most diagnostic signal of EdD moderna across the three observed
producer pipelines. The exact-match constraint excludes
``SimonciniGaramondStd`` used by the Giappichelli/Mandrioli plugin.
"""

CONFIDENCE_NOTE_FAMILY_PRESENT = 0.10
"""Confidence contribution when ``SimonciniGaramond`` at note size
(7.5pt) is present in the signature.
"""

CONFIDENCE_BOLD_HEADING_PRESENT = 0.05
"""Confidence contribution when ``SimonciniGaramond-Bold`` at body size
(9.0pt) is present in the signature.
"""

CONFIDENCE_TIMES_FOOTER_PRESENT = 0.10
"""Confidence contribution when ``TimesNewRoman`` 12.0pt footer ente
size is present.
"""

CONFIDENCE_HELVETICA_COPYRIGHT_PRESENT = 0.10
"""Confidence contribution when ``Helvetica-Bold`` 6.0pt copyright stamp
size is present.
"""

CONFIDENCE_PAGE_GEOMETRY_OK = 0.05
"""Confidence contribution when page geometry falls within the EdD
moderna envelope.
"""

CONFIDENCE_NON_EDD_BODY_FAMILY_PENALTY = -0.40
"""Penalty when the dominant body family is not ``SimonciniGaramond``
exactly. Catches Arial-bodies (DeJure NS/MM/DT), Times-Roman bodies
(EdD storica OCR), TimesNewRomanPSMT (Marotta), Verdana (Marrone/BIC),
MScotchRoman (Torrente), PalatinoLinotype (Codici/Tesauro/Mosconi) and
``SimonciniGaramondStd`` (Giappichelli/Mandrioli).
"""

CONFIDENCE_APPARATUS_MARGINAL_PENALTY = -0.20
"""Penalty when the document carries a substantial marginal-heading
apparatus (Torrente, Mosconi, Mandrioli, Marrone, BIC).
"""

BODY_DOMINANCE_MIN_PERCENT = 30.0
"""Minimum body-family dominance percent to credit the body signal.

Lower than the 40% used by DT/NS because EdD documents with very
dense apparato note (e.g. Abuso fixture) emit ~50% body spans + ~45%
note spans + remainder. With 40% the body sometimes falls just below
threshold on dense fixtures.
"""

APPARATUS_PRESENCE_THRESHOLD = 200
"""Threshold above which marginal-heading counts trigger the penalty.

The signal builder's marginal-heading heuristic counts every block
with a 7-8pt leading span and a left/right margin position. On EdD
moderna two-column fixtures this includes the legitimate 7.5pt note
blocks in the LEFT column (which legitimately sit at ``block_x0 ~ 50``),
producing counts of 30-60 on dense fixtures. The 200 threshold keeps
the penalty effective for Mosconi/Mandrioli/Torrente (which have
hundreds-to-thousands of genuine marginal headings) while leaving
the EdD moderna note column unaffected.
"""


# ---------------------------------------------------------------------------
# Section-region retagging tables.

_FONTI_LETTERATURA_BOUNDARY_CATEGORIES: frozenset[SemanticCategory] = frozenset(
    {
        SemanticCategory.HEADING_1,
        SemanticCategory.HEADING_2,
        SemanticCategory.TITLE,
        SemanticCategory.HEADING_LETTER_INITIAL,
        SemanticCategory.TOC_GENERAL,
    }
)
"""Categories that **close** an open FONTI / LETTERATURA region (a new
structural heading would mark a different scope and the apparatus
retagging must stop).

Note: ARTIFACT_FOOTER, ARTIFACT_RUNNING_HEADER, ARTIFACT_STAMP,
EMPTY_PAGE, BOOK_PAGE_ANCHOR, UNCLASSIFIED do NOT close the region
because they may interleave with the apparato across page breaks.
"""


# ---------------------------------------------------------------------------
# Block view and node id minter helpers (mirror the DT plugin convention).


@dataclass(frozen=True)
class _BlockView:
    """Pre-computed view of a block exposed to the plugin's tier 2 logic."""

    block_index: int
    block: Block
    spans: tuple[Span, ...]
    text: str


# ---------------------------------------------------------------------------
# Main class.


class EnciclopediaModernaProfile(ProfilePlugin):
    """Corpus plugin for the Giuffrè Enciclopedia del Diritto moderna.

    Tenth real corpus plugin of the project; see the module docstring
    for the editorial, structural and design rationale.
    """

    profile_id: ClassVar[str] = "enciclopedia_moderna"
    editorial_family: ClassVar[str] = "giuffre_edd"
    genre: ClassVar[str] = "enciclopedia_moderna"

    def __init__(self) -> None:
        self._pending_warnings: list[str] = []
        self._minted_crossref_note_ids: set[str] = set()
        self._minted_crossref_voce_ids: set[str] = set()

    # ------------------------------------------------------------------
    # ProfilePlugin declarative methods

    @classmethod
    def get_warning_templates(cls) -> tuple[str, ...]:
        return WARNING_TEMPLATES

    @classmethod
    def matches(cls, signals: ProfilingSignals) -> float:
        """Score the document against the EdD moderna fingerprint.

        Six positive contributions (SimonciniGaramond body, note family,
        bold heading, TimesNewRoman footer ente, Helvetica-Bold copyright
        stamp, page geometry) and two penalties (non-EdD body family,
        substantial marginal apparatus). Total positive ceiling is 0.85;
        comfortably above the 0.6 dispatcher threshold on every EdD
        moderna fixture, comfortably below it on every non-EdD fixture
        thanks to the family penalty.
        """
        score = 0.0

        # Body family — EXACT match, not prefix, to discriminate from
        # ``SimonciniGaramondStd`` (Giappichelli) and other prefix-similar
        # families.
        body_present = any(
            font.family == SIMONCINI_REGULAR_FAMILY
            and abs(font.size - BODY_SIZE) < SIZE_TOLERANCE
            and font.dominance_percent >= BODY_DOMINANCE_MIN_PERCENT
            for font in signals.typographic_signature.fonts
        )
        if body_present:
            score += CONFIDENCE_SIMONCINI_BODY_DOMINANT
        else:
            # No SimonciniGaramond body at all → not EdD moderna.
            score += CONFIDENCE_NON_EDD_BODY_FAMILY_PENALTY

        note_family_present = any(
            font.family in {SIMONCINI_REGULAR_FAMILY, SIMONCINI_ITALIC_FAMILY}
            and abs(font.size - NOTE_SIZE) < SIZE_TOLERANCE
            for font in signals.typographic_signature.fonts
        )
        if note_family_present:
            score += CONFIDENCE_NOTE_FAMILY_PRESENT

        bold_heading_present = any(
            font.family == SIMONCINI_BOLD_FAMILY and abs(font.size - BODY_SIZE) < SIZE_TOLERANCE
            for font in signals.typographic_signature.fonts
        )
        if bold_heading_present:
            score += CONFIDENCE_BOLD_HEADING_PRESENT

        times_footer_present = any(
            font.family == TIMES_NEW_ROMAN_FAMILY
            and abs(font.size - FOOTER_ENTE_SIZE) < SIZE_TOLERANCE
            for font in signals.typographic_signature.fonts
        )
        if times_footer_present:
            score += CONFIDENCE_TIMES_FOOTER_PRESENT

        helvetica_copyright_present = any(
            font.family.startswith(HELVETICA_BOLD_FAMILY_FRAGMENT)
            and abs(font.size - COPYRIGHT_SIZE) < SIZE_TOLERANCE
            for font in signals.typographic_signature.fonts
        )
        if helvetica_copyright_present:
            score += CONFIDENCE_HELVETICA_COPYRIGHT_PRESENT

        width = signals.page_geometry.width_pt
        height = signals.page_geometry.height_pt
        if (
            PAGE_WIDTH_MIN <= width <= PAGE_WIDTH_MAX
            and PAGE_HEIGHT_MIN <= height <= PAGE_HEIGHT_MAX
        ):
            score += CONFIDENCE_PAGE_GEOMETRY_OK

        if signals.apparatus_presence.marginal_headings >= APPARATUS_PRESENCE_THRESHOLD:
            score += CONFIDENCE_APPARATUS_MARGINAL_PENALTY

        return max(0.0, score)

    def get_categories(self) -> set[SemanticCategory]:
        """Closed set of categories the plugin may emit."""
        return {
            SemanticCategory.HEADING_1,
            SemanticCategory.HEADING_2,
            SemanticCategory.HEADING_LETTER_INITIAL,
            SemanticCategory.TITLE,
            SemanticCategory.BODY,
            SemanticCategory.NOTE,
            SemanticCategory.CROSS_REFERENCE,
            SemanticCategory.SECTION_LABEL,
            SemanticCategory.FONTI,
            SemanticCategory.LETTERATURA,
            SemanticCategory.TOC_GENERAL,
            SemanticCategory.BOOK_PAGE_ANCHOR,
            SemanticCategory.ARTIFACT_RUNNING_HEADER,
            SemanticCategory.ARTIFACT_FOOTER,
            SemanticCategory.ARTIFACT_STAMP,
            SemanticCategory.EMPTY_PAGE,
            SemanticCategory.UNCLASSIFIED,
        }

    def get_post_processing(self) -> list[str]:
        """Return the post-processing step list.

        EdD moderna benefits from both dehyphenation (~25-30 sillabazioni
        per pagina from two-column tight justification) and cross-page
        note merging (~31-46 % of notes continue across page breaks
        per the analysis empirical numbers).
        """
        return ["dehyphenate_with_log", "merge_cross_page_notes"]

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
        """Promote tier 1 verdicts to the plugin's EdD-specific vocabulary.

        Two passes: first a predicate cascade on every tier 1 verdict,
        second a stateful walk that retags BODY blocks inside the FONTI
        and LETTERATURA regions opened by their respective
        ``SECTION_LABEL`` markers (pattern (yy) in the module docstring).
        """
        self._pending_warnings = []
        self._minted_crossref_note_ids = set()
        self._minted_crossref_voce_ids = set()

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
            refined.append(self._reclassify(verdict, view, extraction))

        # Pass 2: stateful retagging of BODY blocks inside FONTI / LETTERATURA
        # regions. The two regions are mutually exclusive and the walker
        # terminates at end-of-document or a structural boundary.
        in_fonti = False
        in_letteratura = False
        retagged: list[ClassifiedBlock] = []
        for verdict in refined:
            if verdict.block_index < 0:
                retagged.append(verdict)
                continue
            view = self._view(extraction, verdict.block_index)
            if view is None:
                retagged.append(verdict)
                continue

            # Detect SECTION_LABEL transitions.
            if verdict.category is SemanticCategory.SECTION_LABEL:
                text = view.text
                if _FONTI_LABEL_PATTERN.match(text):
                    in_fonti = True
                    in_letteratura = False
                    self._pending_warnings.append(
                        f"{WARNING_PREFIX}:fonti_section_opened_block_"
                        f"{verdict.block_index}_page_{view.block.page}"
                    )
                elif _LETTERATURA_LABEL_PATTERN.match(text):
                    in_fonti = False
                    in_letteratura = True
                    self._pending_warnings.append(
                        f"{WARNING_PREFIX}:letteratura_section_opened_block_"
                        f"{verdict.block_index}_page_{view.block.page}"
                    )
                retagged.append(verdict)
                continue

            # Structural boundaries close any open region.
            if verdict.category in _FONTI_LETTERATURA_BOUNDARY_CATEGORIES:
                in_fonti = False
                in_letteratura = False
                retagged.append(verdict)
                continue

            # Retag BODY inside the active region.
            if verdict.category is SemanticCategory.BODY and (in_fonti or in_letteratura):
                target = SemanticCategory.FONTI if in_fonti else SemanticCategory.LETTERATURA
                reason = (
                    "enciclopedia_moderna_fonti_region"
                    if in_fonti
                    else "enciclopedia_moderna_letteratura_region"
                )
                retagged.append(
                    ClassifiedBlock(
                        block_index=verdict.block_index,
                        category=target,
                        reason=reason,
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
        """Mint inline CROSS_REFERENCE Nodes and parse TOC_GENERAL items.

        Two transformations:

        1. For every BODY (or section-region) Node, scan the text for
           ``(N)`` numbered footnote markers and ``v. NOMEVOCE`` voice
           references; mint a synthetic CROSS_REFERENCE Node per match
           as a sibling immediately after the host Node (pattern (zz)).
        2. For every TOC_GENERAL Node, parse the sommario text into
           ``toc_items``.
        """
        del classified_blocks, extraction

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
        """Bind synthetic CROSS_REFERENCE (N) Nodes globally to their target NOTE.

        EdD moderna is a single voce-saggio per PDF (analysis § 11.7),
        so the apparatus scope is the whole document — no per-article
        scoping (DT pattern (vv)). The plugin builds a global
        ``marker → NOTE node_id`` index over every NOTE Node and binds
        each minted ``(N)`` CROSS_REFERENCE Node to its target. The
        ``v. NOMEVOCE`` voce references stay unbound (the target voce
        is external to this PDF; Layer 2 may surface them as
        free-standing inline links).
        """
        del extraction, classified_blocks

        # Build the global marker → NOTE node_id index.
        note_index: dict[str, str] = {}
        for node in iter_nodes_pre_order(document.root):
            if node.category is not SemanticCategory.NOTE:
                continue
            if node.text is None:
                continue
            match = _NOTE_LEADING_MARKER_PATTERN.match(node.text)
            if match is None:
                continue
            note_index.setdefault(match.group(1), node.id)

        new_warnings: list[str] = []

        def _walk(node: Node) -> Node:
            new_children = tuple(_walk(c) for c in node.children)
            new_apparatus_refs: tuple[ApparatusRef, ...] = node.apparatus_refs
            if (
                node.category is SemanticCategory.CROSS_REFERENCE
                and node.id in self._minted_crossref_note_ids
                and node.text is not None
            ):
                match = _NOTE_LEADING_MARKER_PATTERN.match(node.text)
                if match is not None:
                    marker = match.group(1)
                    target_id = note_index.get(marker)
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
                        new_warnings.append(
                            f"{WARNING_PREFIX}:cross_reference_note_unresolved_"
                            f"node_{node.id}_marker_{marker}"
                        )
            if new_children != node.children or new_apparatus_refs != node.apparatus_refs:
                return replace(
                    node,
                    children=new_children,
                    apparatus_refs=new_apparatus_refs,
                )
            return node

        new_root = tuple(_walk(r) for r in document.root)
        filtered = self._filter_tier1_crossref_warnings(document.warnings)
        return Document(
            root=new_root,
            warnings=filtered + tuple(new_warnings),
            transformations=document.transformations,
        )

    # ------------------------------------------------------------------
    # Per-block reclassification

    def _reclassify(
        self,
        verdict: ClassifiedBlock,
        view: _BlockView,
        extraction: ExtractionResult,
    ) -> ClassifiedBlock:
        """Apply the predicate cascade to a single tier 1 verdict.

        Ordering matters: the drop-cap iniziale predicate fires first
        because its 35.9pt size dominates and must not be absorbed by
        any other predicate; the FONTI/LETTERATURA labels fire before
        the generic paragrafo-heading predicate to avoid a false-positive
        promotion; the footer ente fires before the body predicate
        because the TimesNewRoman 12.0 footer line sits inside a page-
        bottom block that may otherwise pass the body predicate on
        certain page configurations.
        """
        del extraction
        if self._is_letter_initial_drop_cap(view):
            self._pending_warnings.append(
                f"{WARNING_PREFIX}:drop_cap_letter_initial_block_"
                f"{verdict.block_index}_page_{view.block.page}"
            )
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.HEADING_LETTER_INITIAL,
                reason="enciclopedia_moderna_drop_cap_letter_initial",
            )
        if self._is_footer_ente(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.ARTIFACT_FOOTER,
                reason="enciclopedia_moderna_footer_ente",
            )
        if self._is_copyright_stamp(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.ARTIFACT_STAMP,
                reason="enciclopedia_moderna_copyright_stamp",
            )
        if self._is_fonti_label(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.SECTION_LABEL,
                reason="enciclopedia_moderna_fonti_label",
            )
        if self._is_letteratura_label(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.SECTION_LABEL,
                reason="enciclopedia_moderna_letteratura_label",
            )
        if self._is_sommario(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.TOC_GENERAL,
                reason="enciclopedia_moderna_sommario",
            )
        if self._is_sezione_heading(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.HEADING_2,
                reason="enciclopedia_moderna_sezione_heading",
            )
        if self._is_paragraph_heading(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.HEADING_1,
                reason="enciclopedia_moderna_paragraph_heading",
            )
        if self._is_voce_title(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.TITLE,
                reason="enciclopedia_moderna_voce_title",
            )
        if self._is_note(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.NOTE,
                reason="enciclopedia_moderna_note",
            )
        if self._is_body(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.BODY,
                reason="enciclopedia_moderna_body",
            )
        return verdict

    # ------------------------------------------------------------------
    # Predicates

    @staticmethod
    def _is_letter_initial_drop_cap(view: _BlockView) -> bool:
        """Drop-cap iniziale gigante.

        A block whose only meaningful content is a single uppercase
        letter at SimonciniGaramond size >= ``DROP_CAP_MIN_SIZE``. The
        block may contain trailing whitespace spans inserted by the
        renderer.
        """
        if not view.spans:
            return False
        leading = view.spans[0]
        if leading.font != SIMONCINI_REGULAR_FAMILY:
            return False
        if leading.size < DROP_CAP_MIN_SIZE:
            return False
        stripped = view.text.strip()
        if len(stripped) != 1:
            return False
        return stripped.isupper() and stripped.isalpha()

    @staticmethod
    def _is_footer_ente(view: _BlockView) -> bool:
        """Footer ente ``"Enciclopedia del Diritto - ... - YYYY"``.

        TimesNewRoman 12.0pt with the literal text fragment.
        """
        if not view.spans:
            return False
        leading = view.spans[0]
        family_ok = leading.font == TIMES_NEW_ROMAN_FAMILY
        size_ok = abs(leading.size - FOOTER_ENTE_SIZE) < SIZE_TOLERANCE
        if not (family_ok and size_ok):
            return False
        return FOOTER_ENTE_TEXT_FRAGMENT in view.text

    @staticmethod
    def _is_copyright_stamp(view: _BlockView) -> bool:
        """Copyright stamp ``"Copyright Giuffrè ... RIPRODUZIONE RISERVATA"``.

        Helvetica-Bold 6.0pt with one of the closed text fragments.
        """
        if not view.spans:
            return False
        leading = view.spans[0]
        family_ok = leading.font.startswith(HELVETICA_BOLD_FAMILY_FRAGMENT)
        size_ok = abs(leading.size - COPYRIGHT_SIZE) < SIZE_TOLERANCE
        if not (family_ok and size_ok):
            return False
        return any(fragment in view.text for fragment in COPYRIGHT_STAMP_TEXT_FRAGMENTS)

    @staticmethod
    def _is_fonti_label(view: _BlockView) -> bool:
        """``"FONTI."`` opening label at SimonciniGaramond-Bold body size."""
        if not view.spans:
            return False
        leading = view.spans[0]
        family_ok = leading.font == SIMONCINI_BOLD_FAMILY
        size_ok = abs(leading.size - BODY_SIZE) < SIZE_TOLERANCE
        if not (family_ok and size_ok):
            return False
        return bool(_FONTI_LABEL_PATTERN.match(view.text))

    @staticmethod
    def _is_letteratura_label(view: _BlockView) -> bool:
        """``"LETTERATURA."`` opening label at SimonciniGaramond-Bold body size."""
        if not view.spans:
            return False
        leading = view.spans[0]
        family_ok = leading.font == SIMONCINI_BOLD_FAMILY
        size_ok = abs(leading.size - BODY_SIZE) < SIZE_TOLERANCE
        if not (family_ok and size_ok):
            return False
        return bool(_LETTERATURA_LABEL_PATTERN.match(view.text))

    @staticmethod
    def _is_sommario(view: _BlockView) -> bool:
        """Sommario block ``"SOMMARIO:"`` at SimonciniGaramond 6.5pt.

        Recognised via the small-caps three-span composite
        ``[("S", 6.49pt) + ("OMMARIO", 4.24pt) + (":", 6.49pt)]``: the
        leading span is at sommario size, the second span is smaller
        and contains the rest of the marker.

        The predicate combines the typographic check on the leading
        span with a textual check on the joined block text for the
        prefix ``"S OMMARIO"`` or ``"SOMMARIO"``.
        """
        if not view.spans:
            return False
        leading = view.spans[0]
        family_ok = leading.font == SIMONCINI_REGULAR_FAMILY
        size_ok = abs(leading.size - SOMMARIO_SIZE) < SIZE_TOLERANCE
        if not (family_ok and size_ok):
            return False
        return bool(_SOMMARIO_TRIM_PATTERN.match(view.text))

    @staticmethod
    def _is_sezione_heading(view: _BlockView) -> bool:
        """Sezione romana heading ``"Sez. N. Title"`` at SimonciniGaramond-Bold 9pt."""
        if not view.spans:
            return False
        leading = view.spans[0]
        family_ok = leading.font == SIMONCINI_BOLD_FAMILY
        size_ok = abs(leading.size - BODY_SIZE) < SIZE_TOLERANCE
        if not (family_ok and size_ok):
            return False
        return bool(_SEZIONE_HEADING_PATTERN.match(view.text))

    @staticmethod
    def _is_paragraph_heading(view: _BlockView) -> bool:
        """Paragrafo numerato heading ``"N. Title"`` at SimonciniGaramond-Bold 9pt.

        Bold weight is required (a body block opening with ``"3. "``
        from an enumeration in body text is not a paragrafo heading).
        """
        if not view.spans:
            return False
        leading = view.spans[0]
        family_ok = leading.font == SIMONCINI_BOLD_FAMILY
        size_ok = abs(leading.size - BODY_SIZE) < SIZE_TOLERANCE
        if not (family_ok and size_ok):
            return False
        return bool(_PARAGRAPH_HEADING_PATTERN.match(view.text))

    @staticmethod
    def _is_voce_title(view: _BlockView) -> bool:
        """Voce title at SimonciniGaramond-Bold 9pt — first significant
        bold block on page 1, no leading paragrafo number, not a FONTI
        or LETTERATURA label, not a Sezione heading.

        Heuristic: on page 1, a SimonciniGaramond-Bold 9pt block whose
        text starts with an uppercase letter and is NOT a numbered
        heading, sezione, fonti or letteratura is the voce title.
        """
        if view.block.page != 0:
            return False
        if not view.spans:
            return False
        leading = view.spans[0]
        family_ok = leading.font == SIMONCINI_BOLD_FAMILY
        size_ok = abs(leading.size - BODY_SIZE) < SIZE_TOLERANCE
        if not (family_ok and size_ok):
            return False
        stripped = view.text.strip()
        if not stripped:
            return False
        # Defensive: should not be a numbered heading, sezione, fonti
        # or letteratura — those predicates fire earlier in the cascade.
        if _PARAGRAPH_HEADING_PATTERN.match(stripped):
            return False
        if _SEZIONE_HEADING_PATTERN.match(stripped):
            return False
        if _FONTI_LABEL_PATTERN.match(stripped):
            return False
        if _LETTERATURA_LABEL_PATTERN.match(stripped):
            return False
        return stripped[0].isupper()

    @staticmethod
    def _is_note(view: _BlockView) -> bool:
        """NOTE block whose leading span is SimonciniGaramond at note size
        (7.5pt) or italic at note size.

        Notes share the same family prefix as the body but use a
        smaller size that is the most diagnostic discriminator. The
        check is on the leading span size, not on every span (notes
        may include inline italic spans, emphasised quotes, apici).
        """
        if not view.spans:
            return False
        leading = view.spans[0]
        family_ok = leading.font in {SIMONCINI_REGULAR_FAMILY, SIMONCINI_ITALIC_FAMILY}
        size_ok = abs(leading.size - NOTE_SIZE) < SIZE_TOLERANCE
        return family_ok and size_ok

    @staticmethod
    def _is_body(view: _BlockView) -> bool:
        """BODY block whose leading span is SimonciniGaramond regular or
        italic at body size (9.0pt).
        """
        if not view.spans:
            return False
        leading = view.spans[0]
        family_ok = leading.font in {SIMONCINI_REGULAR_FAMILY, SIMONCINI_ITALIC_FAMILY}
        size_ok = abs(leading.size - BODY_SIZE) < SIZE_TOLERANCE
        return family_ok and size_ok

    # ------------------------------------------------------------------
    # Refine reconstruction: CR minting + TOC parsing

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
        del transformations
        refined_roots: list[Node] = []
        for root in roots:
            new_children = self._refine_forest(root.children, warnings, [], minter)
            if new_children != root.children:
                root = replace(root, children=new_children)
            refined_roots.append(root)
        return self._refine_children_list(tuple(refined_roots), warnings, minter)

    def _refine_children_list(
        self,
        children: tuple[Node, ...],
        warnings: list[str],
        minter: NodeIdMinter,
    ) -> tuple[Node, ...]:
        """Apply the per-Node refinements to a parent's children list."""
        out: list[Node] = []
        for child in children:
            # TOC parsing.
            if child.category is SemanticCategory.TOC_GENERAL and child.text is not None:
                out.extend(self._parse_toc_general(child, warnings))
                continue
            # CR minting on BODY / FONTI / LETTERATURA Nodes only.
            if child.text is not None and child.category in {
                SemanticCategory.BODY,
                SemanticCategory.FONTI,
                SemanticCategory.LETTERATURA,
            }:
                out.extend(self._maybe_mint_cross_references(child, warnings, minter))
                continue
            out.append(child)
        return tuple(out)

    # ------------------------------------------------------------------
    # TOC_GENERAL parsing

    def _parse_toc_general(
        self,
        node: Node,
        warnings: list[str],
    ) -> list[Node]:
        """Parse a TOC_GENERAL Node into ``toc_items``.

        Strips the leading ``"SOMMARIO:"`` prefix and splits on the
        em-dash separator. Each segment is then parsed as ``"N. Title"``
        via :data:`_TOC_ITEM_PATTERN`. Numbers may be composite (e.g.
        ``"1.1"``).
        """
        assert node.text is not None
        stripped = _SOMMARIO_TRIM_PATTERN.sub("", node.text.strip())
        segments = re.split(r"\s*[—–-]\s*(?=\d)", stripped)
        items: list[TocGeneralItem] = []
        for seg in segments:
            seg = seg.strip()
            match = _TOC_ITEM_PATTERN.match(seg)
            if match:
                number = match.group(1)
                title = match.group(2).strip()
                if title:
                    items.append(TocGeneralItem(number=number, title=title, page_number=None))
        if not items:
            warnings.append(f"{WARNING_PREFIX}:toc_general_unparseable_node_{node.id}")
            return [node]
        warnings.append(f"{WARNING_PREFIX}:toc_general_parsed_node_{node.id}_items_{len(items)}")
        return [replace(node, toc_items=tuple(items))]

    # ------------------------------------------------------------------
    # Inline cross-reference minting (pattern (zz))

    def _maybe_mint_cross_references(
        self,
        node: Node,
        warnings: list[str],
        minter: NodeIdMinter,
    ) -> list[Node]:
        """Mint synthetic CROSS_REFERENCE siblings for inline ``(N)`` and
        ``v. NOMEVOCE`` matches.

        Two distinct regex patterns are applied in sequence to the host
        Node text. The matches are NOT sorted — Layer 2 will see the
        synthetic Nodes in the order they were minted (numbered first,
        then voce references), each carrying the verbatim marker text
        on its ``text`` field. The subtype is encoded both by the
        leading character of the marker text (``"("`` for numbered,
        ``"v."`` for voce) and by the warning template.
        """
        if node.text is None:
            return [node]
        text = node.text
        out: list[Node] = [node]

        # Numbered footnote markers (N).
        for match in _CROSSREF_INLINE_NOTE_PATTERN.finditer(text):
            marker_value = match.group(1)
            if int(marker_value) > _CROSSREF_MAX_MARKER_VALUE:
                continue
            marker_text = match.group(0)
            new_id = minter.mint()
            out.append(
                Node(
                    id=new_id,
                    category=SemanticCategory.CROSS_REFERENCE,
                    page_index=node.page_index,
                    block_indices=node.block_indices,
                    text=marker_text,
                )
            )
            self._minted_crossref_note_ids.add(new_id)
            warnings.append(
                f"{WARNING_PREFIX}:cross_reference_note_minted_node_"
                f"{new_id}_page_{node.page_index}_marker_{marker_value}"
            )

        # Intra-EdD voice references ``v. NOMEVOCE[, ANNO]``.
        for match in _CROSSREF_INLINE_VOCE_PATTERN.finditer(text):
            voce_raw = match.group(0).strip()
            voce_name = match.group(1).strip()
            new_id = minter.mint()
            out.append(
                Node(
                    id=new_id,
                    category=SemanticCategory.CROSS_REFERENCE,
                    page_index=node.page_index,
                    block_indices=node.block_indices,
                    text=voce_raw,
                )
            )
            self._minted_crossref_voce_ids.add(new_id)
            warnings.append(
                f"{WARNING_PREFIX}:cross_reference_voce_minted_node_"
                f"{new_id}_page_{node.page_index}_voce_{voce_name}"
            )

        return out

    # ------------------------------------------------------------------
    # Tier 1 generic warning filter (parallel to NS/DT/Torrente convention)

    def _filter_tier1_crossref_warnings(self, warnings: tuple[str, ...]) -> tuple[str, ...]:
        """Drop tier 1 cross-reference warnings on plugin synthetic Nodes.

        Both ``unparseable_cross_reference_node_<id>`` (text not pure-digit)
        and ``unresolved_cross_reference_node_<id>_n_<N>`` (resolver scope
        differs from plugin global scope) are filtered out for plugin-
        minted CR Nodes. The plugin's own
        ``cross_reference_note_unresolved_*`` warnings stay.

        Thin wrapper over
        :func:`apparatus.resolver.filter_tier1_crossref_warnings` (P-020).
        """
        all_synthetic = self._minted_crossref_note_ids | self._minted_crossref_voce_ids
        return filter_tier1_crossref_warnings(warnings, all_synthetic)

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
