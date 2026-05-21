"""Corpus plugin for the UTET / Wolters Kluwer treatise series — Mosconi-Campiglio.

Third real corpus plugin of the project. Handles the Mosconi-Campiglio
"Diritto internazionale privato e processuale — Volume I" (UTET
Giuridica / Wolters Kluwer Italia, 11th edition, 2024) — see
``docs/analysis/ANALYSIS_MOSCONI_CAMPIGLIO.md`` for the editorial
analysis the plugin is built against.

The manual is the most apparatus-heavy in the project to date: dense
footnotes, marginal headings on both page edges, example boxes
interleaved with the prose, and inline cross-reference superscripts
that bind body mentions to the footnotes at the bottom of the page.
The editorial pipeline (Adobe InDesign CS6 + PDF Library 10.0.1) and
the typographic family (``TimesTenLTStd``) are shared with the
:class:`scabopdf_pipeline.profiles.compendio_utet.CompendioUtetProfile`
plugin (Tesauro Compendio) but the two prodotti editoriali are
structurally opposite: the Tesauro is a compendium with zero
apparatus, the Mosconi is a treatise with apparato denso. The
``matches()`` discriminators on both plugins are deliberately
symmetric: the Tesauro penalises apparato heavy with ``-0.30`` to stay
below the dispatcher threshold on Mosconi, and this plugin penalises
apparato assente by the same amount to stay below the threshold on
the Tesauro.

Heading levels.

- **HEADING_1 — front matter heading.** Pre-volume content carries
  short uppercase titles at ``TimesTenLTStd-Roman`` 12.0pt: ``INDICE``,
  ``ABBREVIAZIONI``, ``PREMESSA ALLA UNDICESIMA EDIZIONE``, prior
  editorial introductions, etc. The signature is identical to the
  chapter heading; discrimination is by text pattern (anything 12.0pt
  that does not match the chapter ordinal whitelist).
- **HEADING_2 — chapter.** Two consecutive blocks fused in
  :meth:`refine_reconstruction`: the ``"Capitolo <ordinale>"`` block in
  ``TimesTenLTStd-Roman`` 12.0pt and the title block in ``TimesTenLTStd``
  12.0pt that follows. The Italian ordinal is preserved verbatim (e.g.
  ``"Capitolo Primo. NOZIONE E OGGETTO DEL DIRITTO INTERNAZIONALE
  PRIVATO E PROCESSUALE"``). The ordinal whitelist is closed on the
  Mosconi 11th edition (``primo..settimo``); future editions will add
  entries if needed.
- **HEADING_3 — paragraph numerato.** Composite block: a short
  ``TimesTenLTStd-Roman`` 10.5pt span carrying ``"<n>."`` followed by a
  ``TimesTenLTStd-Bold`` 10.5pt span carrying the title. Numerazione
  restarts at 1 in each chapter; 148 paragraphs in total per
  Mosconi-Campiglio 11th edition.

Apparatus.

- **NOTE — footnote.** Block opens with a small ``TimesTenLTStd-Roman``
  4.7pt span carrying the footnote number, followed by a
  ``TimesTenLTStd-Roman`` 8.0pt body span. Notes can span several
  PyMuPDF blocks: an intra-page continuation is a NOTE whose text does
  not open with ``^\\s*\\d+\\.\\s`` and that immediately follows
  another NOTE on the same page; the plugin's
  :meth:`refine_reconstruction` fuses such continuations into the
  preceding NOTE. Cross-page note merging is performed by the tier 1
  resolver in :mod:`scabopdf_pipeline.apparatus.resolver` and needs no
  plugin override on Mosconi.
- **MARGINAL_HEADING — marginal mini-title.** Block whose first span
  is ``TimesTenLTStd-Roman`` 7.0pt with the block bbox sitting against
  either the left margin (``x0 < 80``) or the right margin
  (``x0 > 370``). 593 marginals in total per Mosconi-Campiglio 11th
  edition, roughly 13 % of which the typesetter split across two
  consecutive nodes by a ``...`` continuation marker. The marginal
  ellipsis recomposition is performed in the
  ``recompose_marginal_ellipsis`` post-processing step (see
  :mod:`postprocessing.steps.recompose_marginal_ellipsis`) that this
  plugin promoted from placeholder to real implementation.
- **EXAMPLE_BOX — Approfondimento.** Block whose first span is
  ``TimesTenLTStd-Italic`` 9.0pt with body text exceeding the front
  matter index minimum (100 characters) and not opening with one of
  the index section keywords (``Sezione``, ``Capitolo``, ``Parte``,
  ``Premessa``, ``Indice``, ``Abbreviazioni``). 420 boxes in total per
  Mosconi-Campiglio 11th edition, the most extreme apparatus density
  in the project.
- **CROSS_REFERENCE — inline footnote marker.** Mosconi superscripts
  the footnote number inline inside the body text using a
  ``TimesTenLTStd-Roman`` span at 5.2pt or 5.8pt with PyMuPDF's
  ``SUPERSCRIPT`` flag (bit 0) set. The tier 1 generic classifier
  recognises ``CROSS_REFERENCE`` only when the entire block is a
  single superscript-digit span; inline superscripts embedded inside
  larger BODY blocks are invisible to tier 1. The plugin's
  :meth:`refine_reconstruction` walks every BODY node, examines its
  underlying extraction spans, and mints a synthetic
  ``CROSS_REFERENCE`` ``Node`` as a sibling immediately after the
  BODY for each inline superscript digit found. The body text retains
  the digit in its surface form — what the reader sees in the PDF —
  but the apparatus resolver in
  :mod:`scabopdf_pipeline.apparatus.resolver` picks up the synthetic
  ``CROSS_REFERENCE`` nodes and binds each to its target NOTE within
  the scope of the nearest HEADING_2 ancestor (the chapter, in
  Mosconi). The digit duplication is harmless: Layer 2 can render
  either source.

Artifacts.

- **ARTIFACT_STAMP — editorial-proof watermark.** The InDesign
  filename pattern (``\\d+_<label>\\.indb?``) and the date/time pattern
  (``dd/mm/yy H:MM``) inherited from the Tesauro plugin (commit
  ``c7840ef``) cover the Mosconi front matter watermarks too: stamps
  like ``265955_Terza_Bozza.indb`` and ``13/06/24 3:39 PM``. The
  rescue codepath that promotes ``ARTIFACT_FOOTER`` to
  ``ARTIFACT_STAMP`` when the text matches the stamp regex is the
  same.

Pipeline integration.

- ``get_post_processing`` returns
  ``["dehyphenate_with_log", "recompose_marginal_ellipsis"]``. The
  dehyphenator handles end-of-line word hyphenations in the body and
  in the notes; the marginal ellipsis recomposition fuses the 13 %
  of marginals split across pages.
- ``get_layouts_disabled`` returns the empty list. Mosconi is the
  first plugin in the project that exercises every layout the
  reader-side renderer offers: Layout 1 (linear prose), Layout 2
  (notes pinned), Layout 3 (marginal columns), Layout 4 (Dottrina
  with inline footnote markers).
- ``refine_apparatus`` is pass-through. The five tier 1 resolvers in
  :mod:`scabopdf_pipeline.apparatus.resolver` already do the work
  Mosconi needs: cross-page NOTE merging
  (``_resolve_cross_page_note_merging``), inline ``CROSS_REFERENCE``
  binding to NOTE within HEADING_2 scope (``_resolve_cross_references``)
  and ``MARGINAL_HEADING`` body anchoring
  (``_resolve_marginal_positions``).

Instance state.

The plugin keeps a small bag of pending warnings and a pair of
block-index sets between :meth:`refine_classification` and
:meth:`refine_reconstruction`. The warnings flush into
``Document.warnings``; the block-index sets record which blocks were
classified as the ``"Capitolo <ord>"`` half and the title half of a
chapter heading pair, so that :meth:`refine_reconstruction` can fuse
the two consecutive ``HEADING_2`` siblings into a single node
carrying the combined text and both ``block_indices``. This mirrors
the convention established by the Tesauro plugin.

Closed warning vocabulary, prefixed ``plugin:utet_wolterskluwer:``.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import ClassVar

from scabopdf_pipeline.classification.types import ClassifiedBlock
from scabopdf_pipeline.extraction.types import Block, ExtractionResult, Span
from scabopdf_pipeline.profiling.plugin import ProfilePlugin
from scabopdf_pipeline.profiling.profile import DisabledLayout
from scabopdf_pipeline.profiling.signals import ProfilingSignals
from scabopdf_pipeline.profiling.typography_constants import APPARATUS_PRESENCE_THRESHOLD
from scabopdf_pipeline.reconstruction.minting import NodeIdMinter, max_existing_node_counter
from scabopdf_pipeline.reconstruction.types import Document, Node, compute_note_length_category
from scabopdf_pipeline.schema.categories import SemanticCategory

WARNING_PREFIX = "plugin:utet_wolterskluwer"
"""Common prefix for every warning string this plugin may emit.

See ``docs/SCHEMA_v0.4.0.md § 6`` for the rationale of the prefix
convention and :data:`WARNING_TEMPLATES` for the closed vocabulary.
"""

WARNING_TEMPLATES: tuple[str, ...] = (
    "plugin:utet_wolterskluwer:chapter_title_not_adjacent_block_<idx>_page_<p>",
    "plugin:utet_wolterskluwer:paragraph_heading_pattern_unmatched_block_<idx>_page_<p>",
    "plugin:utet_wolterskluwer:note_continuation_merged_node_<id>_page_<p>",
    "plugin:utet_wolterskluwer:marginal_ellipsis_orphan_marker_node_<id>_page_<p>",
    "plugin:utet_wolterskluwer:inline_cross_reference_minted_node_<id>_page_<p>",
    "plugin:utet_wolterskluwer:example_box_in_front_matter_filtered_block_<idx>_page_<p>",
    "plugin:utet_wolterskluwer:back_matter_index_column_rejected_block_<idx>_page_<p>",
)
"""Closed vocabulary of warnings the plugin may emit on
``Document.warnings``. Placeholders are replaced with concrete values
at emission time. Consumers should match on the prefix.
"""

ITALIAN_ORDINALS: tuple[str, ...] = (
    "primo",
    "secondo",
    "terzo",
    "quarto",
    "quinto",
    "sesto",
    "settimo",
)
"""Closed list of Italian ordinals the Mosconi 11th edition chapter
headings use. Volume I of the manual is split into seven chapters; the
whitelist is intentionally tight so that 12pt blocks carrying any
other text — including the front matter headings — fall through the
chapter test and are reclassified by other branches. Future editions
will add entries if they extend the volume.
"""

_CHAPTER_NUMBER_PATTERN = re.compile(
    r"^Capitolo\s+(" + "|".join(ITALIAN_ORDINALS) + r")\s*$",
    re.IGNORECASE,
)
"""Pattern matching the ``"Capitolo <ordinale>"`` block text exactly.

Anchored on both ends with optional trailing whitespace; the
case-insensitive flag covers minor casing drift across editions.
"""

_PARAGRAPH_NUMBER_PATTERN = re.compile(r"^\d+\.\s*$")
"""Pattern for the leading number-only span of a paragraph heading.

In the Mosconi typesetting a paragraph heading opens with a short
``TimesTenLTStd-Roman`` 10.5pt span carrying just ``"<n>."`` followed
by a ``TimesTenLTStd-Bold`` 10.5pt span carrying the title. The
pattern is anchored on both ends so that ``"1."`` matches but
``"1. Premessa"`` does not — body paragraphs that happen to open with
a numbered marker are not paragraph headings.
"""

_PARAGRAPH_HEADING_FULL_PATTERN = re.compile(r"^\d+\.\s+\S")
"""Pattern for the full text of a paragraph heading block.

When the typesetter collapses the number span and the title span into
a single PyMuPDF span (rare but observed in some blocks), the full
text matches ``"<n>. <title>"``. The plugin admits this collapsed
form as a fallback when the leading-span pattern does not apply.
"""

_NOTE_MARKER_PATTERN = re.compile(r"^\s*\d+\.?\s")
"""Pattern for the leading marker of a footnote text.

A note opens with a number followed by an optional ``"."`` and at
least one whitespace character before the body. The dot is optional
because the Mosconi typesetting renders the marker as the digit
followed by an em-space (``\\u2002``) and the body text, without a
literal ``"."`` in the PyMuPDF text layer. The pattern still admits
the dotted form (``"5. Foo"``) so future UTET PDFs with that
convention work without modification.
A block whose typographic signature is NOTE-like but whose text
does not match this pattern, and that immediately follows another
NOTE on the same page, is treated as an intra-page continuation of
the preceding NOTE.
"""

_STAMP_FILENAME_PATTERN = re.compile(r"^\d+_[A-Za-z0-9_]+\.indb?")
"""Pattern for the InDesign filename watermark.

Same generalised pattern the Tesauro plugin uses (commit ``c7840ef``):
``\\d+_<label>\\.indb`` or ``\\d+_<label>\\.indb`` covers UTET
pre-print residue across both manuals.
"""

_STAMP_DATETIME_PATTERN = re.compile(r"^\d{2}/\d{2}/\d{2}\s+\d{1,2}:\d{2}")
"""Pattern for the date/time watermark accompanying the filename stamp."""

_FRONT_MATTER_INDEX_OPENERS = re.compile(
    r"^(?:Sezione|Capitolo|Parte|Premessa|Indice|Abbreviazioni)\b",
    re.IGNORECASE,
)
"""Pattern that flags an italic-9.0pt block as front-matter index residue.

The Mosconi front matter index (book pages 5-32) uses
``TimesTenLTStd-Italic`` 9.0pt — the same signature as the
``EXAMPLE_BOX`` body — for the sub-section entries it lists. A
candidate ``EXAMPLE_BOX`` block whose text opens with one of these
keywords is rejected and left ``UNCLASSIFIED``; a warning records the
filter for audit. The list is closed and tight on purpose: any
``EXAMPLE_BOX`` whose body legitimately opens with one of those words
would lose the box classification, but the editorial analysis
confirms the boxes never open that way.
"""

BODY_FONT_PREFIX = "TimesTenLTStd"
"""Font family prefix of the Mosconi body, headings and most apparatus."""

BODY_FONT_SIZE = 10.0
"""Body size in points. Distinct from the Tesauro body size of 10.2."""

PARAGRAPH_HEADING_SIZE = 10.5
"""Paragraph heading (HEADING_3) size in points."""

CHAPTER_HEADING_SIZE = 12.0
"""Chapter heading (HEADING_1, HEADING_2) size in points."""

MARGINAL_HEADING_SIZE = 7.0
"""Marginal heading (MARGINAL_HEADING) size in points."""

NOTE_BODY_SIZE = 8.0
"""Footnote body size in points."""

NOTE_MARKER_SIZE = 4.7
"""Nominal footnote marker (small leading number) size in points.

The value reflects the dominant case in the Mosconi 11th edition; PyMuPDF
metrics drift across pages and editions, so the actual range admitted
by :meth:`ManualeUtetWolterskluwerProfile._is_note` is
``[NOTE_MARKER_SIZE_MIN, NOTE_MARKER_SIZE_MAX]``.
"""

NOTE_MARKER_SIZE_MIN = 4.0
"""Minimum size in points admitted for a footnote marker leading span."""

NOTE_MARKER_SIZE_MAX = 6.5
"""Maximum size in points admitted for a footnote marker leading span.

The range covers the 4.7pt observed dominance plus the 5.2 / 5.8 pt
variants PyMuPDF occasionally emits, and the slightly larger sizes
seen at chapter-edge footnotes. The upper bound stays below the
6.7pt minimum of the 7.0pt marginal heading family so the predicates
do not overlap.
"""

EXAMPLE_BOX_SIZE = 9.0
"""Example box (EXAMPLE_BOX) size in points."""

CROSS_REFERENCE_SIZES: frozenset[float] = frozenset({5.2, 5.8})
"""Sizes (in points) at which Mosconi typesets inline superscript
cross-reference markers. PyMuPDF reports the size at either of these
two values depending on the line; the plugin admits both.
"""

LEFT_MARGIN_X_THRESHOLD = 80.0
"""``bbox.x0`` upper bound for the left-margin marginal column.

A 7.0pt block whose ``x0`` is below this threshold is on the left
margin and qualifies as a marginal heading. The Mosconi body starts
at ``x ≈ 87``; the threshold leaves a 7-pt cushion.
"""

RIGHT_MARGIN_X_THRESHOLD = 370.0
"""``bbox.x0`` lower bound for the right-margin marginal column.

A 7.0pt block whose ``x0`` is above this threshold is on the right
margin. The Mosconi body ends at ``x ≈ 413``; the threshold leaves a
43-pt cushion for the marginal column.
"""

CHAPTER_HEADING_TEXT_LIMIT = 30
"""Max text length for a candidate chapter-number block.

``Capitolo settimo`` is 16 characters; the cap leaves room for the
longest closed-list ordinal plus minor variants.
"""

CHAPTER_TITLE_TEXT_LIMIT = 200
"""Max text length for a candidate chapter-title block.

The Mosconi chapter titles are short uppercase phrases. The cap
discriminates against incidental 12.0pt blocks that carry more text
(e.g. some front matter prose).
"""

FRONT_MATTER_HEADING_TEXT_LIMIT = 200
"""Max text length for a HEADING_1 front matter heading.

``PREMESSA ALLA UNDICESIMA EDIZIONE`` is the longest expected (34
characters); the cap leaves substantial margin while still rejecting
12.0pt blocks that are clearly prose.
"""

PARAGRAPH_HEADING_TEXT_LIMIT = 300
"""Max text length for a paragraph heading.

Paragraph headings are one-liners. Above the cap the plugin refuses to
commit and leaves the block ``UNCLASSIFIED``.
"""

EXAMPLE_BOX_MIN_TEXT_LENGTH = 100
"""Minimum text length for an italic-9.0pt block to qualify as ``EXAMPLE_BOX``.

The shortest observed example box is 106 characters; the cap leaves a
6-character margin. Below the cap, italic-9.0pt blocks are residue of
the front matter index and stay ``UNCLASSIFIED``.
"""

BOLD_FLAG_BIT = 0x10
"""PyMuPDF's bold flag bit on ``Span.flags``.

Used to detect the Bold title span inside the composite ``HEADING_3``
paragraph heading (number + bold title at 10.5pt). The chapter
heading family in Mosconi is non-bold at 12.0pt for both number and
title, so the discriminator between chapter number and chapter title
is purely textual (whether the text matches the chapter-number
pattern), not typographic.
"""

CONFIDENCE_BODY_DOMINANT = 0.40
"""Confidence contribution when ``TimesTenLTStd`` 10.0pt is present.

Sized to clear the 0.6 dispatcher threshold together with the
apparatus-presence contributions. The threshold for body dominance is
deliberately permissive: in apparatus-heavy documents like Mosconi
the body share of total spans drops below the typical 70 %+ of a
compendium, so a 25 % floor is used here.
"""

CONFIDENCE_FOOTNOTE_APPARATUS = 0.25
"""Confidence contribution when ``footnote_markers`` clears the apparatus threshold.

The single strongest apparatus signal of the Mosconi profile: 965
footnote markers in volume I.
"""

CONFIDENCE_MARGINAL_APPARATUS = 0.15
"""Confidence contribution when ``marginal_headings`` clears the apparatus threshold."""

CONFIDENCE_BOX_APPARATUS = 0.10
"""Confidence contribution when ``italic_9pt_blocks`` clears the apparatus threshold.

The signal proxies the ``EXAMPLE_BOX`` presence: Mosconi's 420 boxes
are typeset in ``TimesTenLTStd-Italic`` 9.0pt, the apparatus-presence
signature the profiling phase counts.
"""

CONFIDENCE_UTET_PIPELINE = 0.05
"""Confidence contribution when the producer/creator string matches the UTET pipeline."""

CONFIDENCE_OUTLINE_ABSENT = 0.05
"""Confidence contribution when the PDF carries no outline.

Wolters Kluwer / UTET PDFs typically have no outline; the bonus
mirrors the Tesauro plugin.
"""

CONFIDENCE_NO_APPARATUS_PENALTY = -0.30
"""Penalty when the document looks like a compendium instead of a treatise.

Symmetric to the Tesauro plugin's
:data:`scabopdf_pipeline.profiles.compendio_utet.CONFIDENCE_HAS_APPARATUS_PENALTY`:
when every apparatus signal is zero the document is not a Mosconi
treatise candidate and this plugin steps back. The score drops by 0.30
so that even if the body and pipeline signals scored the maximum 0.55
the final score lands at 0.25, safely below the 0.6 threshold.
"""

BODY_DOMINANCE_MIN_PERCENT = 25.0
"""Minimum body dominance required to credit the TimesTenLTStd body signal.

Apparatus-heavy documents distribute their spans across many
typographic signatures (body, notes, marginals, boxes, headings); the
single most dominant signature on Mosconi is the body at roughly
33 %. The threshold leaves headroom while still excluding documents
where ``TimesTenLTStd`` is a minor incidental face.
"""

# ``APPARATUS_PRESENCE_THRESHOLD`` was promoted to
# :mod:`scabopdf_pipeline.profiling.typography_constants` (P-035).
# Mosconi has 965/593/420 apparatus markers; the 50 floor leaves room
# for the treatise-vs-compendium discrimination on residual outliers.

UTET_PRODUCER_FRAGMENT = "PDF Library"
"""Producer-field substring signalling the UTET / Wolters Kluwer pipeline."""

UTET_CREATOR_FRAGMENT = "InDesign"
"""Creator-field substring signalling the UTET / Wolters Kluwer pipeline."""

_NOTE_BLOCK_SIZE_TOLERANCE = 0.3
"""Tolerance on PyMuPDF's reported size when checking the NOTE body signature.

PyMuPDF's text-extraction size can drift by up to ~0.2pt across
editions of the same font; 0.3 is a conservative cushion.
"""

_BACK_MATTER_INDEX_COLUMN_MAX_WIDTH_PT = 250.0
"""Upper bound on the bbox width of a back-matter index column.

The Mosconi 11th edition closes Vol. I with an ``Indice della
giurisprudenza`` typeset in two columns on pp.586-611. Each column
measures ~159pt wide (left column ``x0=64``, right column ``x0=237``,
both ending at the body-column right edge), well below the ~325pt of
the single-column body in which legitimate footnotes sit. Combined
with :data:`_BACK_MATTER_INDEX_COLUMN_MIN_HEIGHT_PT` this discriminates
the index from any footnote without false positives on the empirical
calibrating fixture (52 blocks matched, 0 legitimate notes affected).
"""

_BACK_MATTER_INDEX_COLUMN_MIN_HEIGHT_PT = 300.0
"""Lower bound on the bbox height of a back-matter index column.

Legitimate Mosconi footnotes sit at the bottom of a page above the
``ARTIFACT_FOOTER``: the empirical maximum height across all 1038
NOTE-classified blocks of the calibrating fixture is well below 300pt
(q3=49.5pt, max~250pt on the longest single-block legitimate note).
The Indice della giurisprudenza columns span the full page height
(~568pt on every page pp.586-611). The threshold sits in the gap.
"""


@dataclass(frozen=True)
class _BlockView:
    """Pre-computed view of a block exposed to the plugin's tier 2 logic.

    Every signature predicate inspects the full ``spans`` tuple
    directly: for blocks where the discriminating signal is on a later
    span (notably ``HEADING_3`` paragraph headings, whose Bold title
    span comes after the Roman number span) the plugin reads the
    relevant indices explicitly, and for blocks where the leading span
    is representative it accesses ``spans[0]`` directly. No leading-
    span helper properties are exposed.
    """

    block_index: int
    block: Block
    spans: tuple[Span, ...]
    text: str


class ManualeUtetWolterskluwerProfile(ProfilePlugin):
    """Corpus plugin for the UTET / Wolters Kluwer treatise series — Mosconi-Campiglio 11th ed."""

    profile_id: ClassVar[str] = "manuale_utet_wolterskluwer"
    editorial_family: ClassVar[str] = "utet"
    genre: ClassVar[str] = "manuale"

    def __init__(self) -> None:
        self._pending_warnings: list[str] = []
        self._chapter_number_blocks: set[int] = set()
        self._chapter_title_blocks: set[int] = set()

    # ------------------------------------------------------------------
    # ProfilePlugin declarative methods

    @classmethod
    def get_warning_templates(cls) -> tuple[str, ...]:
        return WARNING_TEMPLATES

    @classmethod
    def matches(cls, signals: ProfilingSignals) -> float:
        """Score the document against the Mosconi-Campiglio fingerprint.

        Six positive contributions and one apparatus-absence penalty,
        deliberately symmetric to the Tesauro plugin's compendium
        discrimination. See the module docstring for the editorial
        rationale.
        """
        score = 0.0

        body_present = any(
            font.family.startswith(BODY_FONT_PREFIX)
            and abs(font.size - BODY_FONT_SIZE) < 0.1
            and font.dominance_percent >= BODY_DOMINANCE_MIN_PERCENT
            for font in signals.typographic_signature.fonts
        )
        if body_present:
            score += CONFIDENCE_BODY_DOMINANT

        apparatus = signals.apparatus_presence
        if apparatus.footnote_markers >= APPARATUS_PRESENCE_THRESHOLD:
            score += CONFIDENCE_FOOTNOTE_APPARATUS
        if apparatus.marginal_headings >= APPARATUS_PRESENCE_THRESHOLD:
            score += CONFIDENCE_MARGINAL_APPARATUS
        if apparatus.italic_9pt_blocks >= APPARATUS_PRESENCE_THRESHOLD:
            score += CONFIDENCE_BOX_APPARATUS

        producer = (signals.producer_creator.producer or "").strip()
        creator = (signals.producer_creator.creator or "").strip()
        if UTET_PRODUCER_FRAGMENT in producer or UTET_CREATOR_FRAGMENT in creator:
            score += CONFIDENCE_UTET_PIPELINE

        if not signals.outline_structure.has_outline:
            score += CONFIDENCE_OUTLINE_ABSENT

        if (
            apparatus.footnote_markers == 0
            and apparatus.marginal_headings == 0
            and apparatus.italic_9pt_blocks == 0
        ):
            score += CONFIDENCE_NO_APPARATUS_PENALTY

        return max(0.0, score)

    def get_categories(self) -> set[SemanticCategory]:
        """Closed set of categories the plugin may emit on Mosconi-Campiglio."""
        return {
            SemanticCategory.HEADING_1,
            SemanticCategory.HEADING_2,
            SemanticCategory.HEADING_3,
            SemanticCategory.BODY,
            SemanticCategory.NOTE,
            SemanticCategory.MARGINAL_HEADING,
            SemanticCategory.EXAMPLE_BOX,
            SemanticCategory.CROSS_REFERENCE,
            SemanticCategory.ARTIFACT_STAMP,
            SemanticCategory.ARTIFACT_FOOTER,
            SemanticCategory.ARTIFACT_RUNNING_HEADER,
            SemanticCategory.ARTIFACT_FILIGREE,
            SemanticCategory.BOOK_PAGE_ANCHOR,
            SemanticCategory.UNCLASSIFIED,
            SemanticCategory.EMPTY_PAGE,
        }

    def get_post_processing(self) -> list[str]:
        """Return the ordered list of post-processing step IDs for Mosconi.

        Two steps in sequence: end-of-line word de-hyphenation against
        the Italian lexicon, then marginal-ellipsis recomposition for
        the 13 % of marginals split across pages by the typesetter.
        """
        return ["dehyphenate_with_log", "recompose_marginal_ellipsis"]

    def get_layouts_disabled(self) -> list[DisabledLayout]:
        """No layout is disabled: Mosconi exercises every Layer 2 layout.

        The manual has the full editorial apparatus that Layer 2 was
        designed for: inline cross-reference markers binding the body
        to footnotes (Layout 4 / Dottrina), dense marginal headings on
        both edges of the page (Layout 3), pinned-note rendering of
        the apparatus (Layout 2), and standard linear prose for the
        body (Layout 1). Returning an empty list signals to Layer 2
        that every layout is meaningful for this profile.
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

        Two-pass sweep: a first pass classifies each block in isolation
        and rescues stamp residue absorbed by tier 1 into
        ``ARTIFACT_FOOTER``; a second pass registers the block_indices
        of chapter-number and chapter-title blocks so that
        :meth:`refine_reconstruction` can fuse the two consecutive
        ``HEADING_2`` siblings.
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
            if verdict.category is SemanticCategory.ARTIFACT_FOOTER and (
                _STAMP_FILENAME_PATTERN.match(view.text) or _STAMP_DATETIME_PATTERN.match(view.text)
            ):
                refined.append(
                    ClassifiedBlock(
                        block_index=verdict.block_index,
                        category=SemanticCategory.ARTIFACT_STAMP,
                        reason="utet_wolterskluwer_stamp_from_footer",
                    )
                )
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
        """Fuse chapter pairs, mint inline cross-references, consolidate notes.

        Four responsibilities executed in order:

        1. Fuse adjacent ``HEADING_2`` siblings registered as a chapter
           number / title pair into a single node (same pattern as the
           Tesauro plugin).
        2. Mint synthetic ``CROSS_REFERENCE`` nodes as siblings after
           every BODY node that carries inline superscript-digit spans
           in its underlying extraction block. The synthetic node IDs
           follow the tier 1 convention ``node_NNNN`` (the JSON schema
           constrains every node id to that shape via Pydantic's
           ``pattern`` validator on ``NodeDict.id``), starting from one
           past the maximum counter already assigned by tier 1. The
           tier 1 generic cross-reference resolver runs after
           :meth:`refine_apparatus` and binds each synthetic node to
           its target NOTE within the HEADING_2 scope.
        3. Consolidate adjacent NOTE siblings on the same page when the
           second NOTE does not open with the numeric marker pattern —
           the tier 1 cross-page note resolver only merges first notes
           of a page, not intra-page continuations.
        4. Walk the marginal headings looking for orphan continuation
           markers (a head ending in ``...`` with no successor starting
           in ``...``) and emit a diagnostic warning for each. The
           actual merging of valid chains happens later in the
           ``recompose_marginal_ellipsis`` post-processing step.

        Pending warnings queued by :meth:`refine_classification` are
        flushed into ``Document.warnings`` here.
        """
        del classified_blocks

        new_warnings = list(self._pending_warnings)
        self._pending_warnings = []

        next_id = NodeIdMinter(start=max_existing_node_counter(document.root) + 1)
        new_roots = self._fuse_and_refine(document.root, new_warnings, extraction, next_id)

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
        """Pass-through: the five tier 1 resolvers cover every Mosconi case.

        The generic ``_resolve_cross_page_note_merging``,
        ``_resolve_cross_references`` (scoped to the nearest
        ``HEADING_2`` ancestor, which is the chapter in Mosconi),
        ``_resolve_marginal_positions`` and ``_resolve_marginal_glosses``
        already produce the correct bindings on the Mosconi document
        tree. The plugin has no profile-specific apparatus refinement
        to add and returns the document unchanged.
        """
        del extraction, classified_blocks
        return document

    # ------------------------------------------------------------------
    # Per-block classification

    def _reclassify(self, verdict: ClassifiedBlock, view: _BlockView) -> ClassifiedBlock:
        if _STAMP_FILENAME_PATTERN.match(view.text) or _STAMP_DATETIME_PATTERN.match(view.text):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.ARTIFACT_STAMP,
                reason="utet_wolterskluwer_stamp",
            )

        if self._is_marginal_heading(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.MARGINAL_HEADING,
                reason="utet_wolterskluwer_marginal_heading",
            )

        if self._is_example_box(view):
            if self._looks_like_index_residue(view.text):
                self._pending_warnings.append(
                    f"{WARNING_PREFIX}:example_box_in_front_matter_filtered_block_"
                    f"{verdict.block_index}_page_{view.block.page}"
                )
                return verdict
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.EXAMPLE_BOX,
                reason="utet_wolterskluwer_example_box",
            )

        if self._is_note(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.NOTE,
                reason="utet_wolterskluwer_note",
            )

        if self._is_note_continuation(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.NOTE,
                reason="utet_wolterskluwer_note_continuation",
            )

        # The continuation predicate above has already rejected the
        # back-matter index columns via _is_back_matter_index_column.
        # Surface that decision in the audit log so it does not look
        # like a silent loss of a NOTE-typographic block.
        if self._looks_like_continuation_signature(view) and self._is_back_matter_index_column(
            view
        ):
            self._pending_warnings.append(
                f"{WARNING_PREFIX}:back_matter_index_column_rejected_block_"
                f"{verdict.block_index}_page_{view.block.page}"
            )

        if self._is_chapter_or_front_matter_signature(view):
            text = view.text.strip()
            if _CHAPTER_NUMBER_PATTERN.match(text) and len(text) <= CHAPTER_HEADING_TEXT_LIMIT:
                self._chapter_number_blocks.add(verdict.block_index)
                return ClassifiedBlock(
                    block_index=verdict.block_index,
                    category=SemanticCategory.HEADING_2,
                    reason="utet_wolterskluwer_chapter_number",
                )
            if text and len(text) <= FRONT_MATTER_HEADING_TEXT_LIMIT:
                # Provisional HEADING_1; the second pass in
                # :meth:`_register_chapter_pairs` may promote it to
                # HEADING_2 (chapter title) when it follows a chapter
                # number block in extraction order, tolerating
                # intervening ARTIFACT_STAMP blocks.
                return ClassifiedBlock(
                    block_index=verdict.block_index,
                    category=SemanticCategory.HEADING_1,
                    reason="utet_wolterskluwer_front_matter_heading",
                )

        if self._is_paragraph_heading(view):
            text = view.text.strip()
            if (
                _PARAGRAPH_HEADING_FULL_PATTERN.match(text)
                and len(text) <= PARAGRAPH_HEADING_TEXT_LIMIT
            ):
                return ClassifiedBlock(
                    block_index=verdict.block_index,
                    category=SemanticCategory.HEADING_3,
                    reason="utet_wolterskluwer_paragraph_heading",
                )
            self._pending_warnings.append(
                f"{WARNING_PREFIX}:paragraph_heading_pattern_unmatched_block_"
                f"{verdict.block_index}_page_{view.block.page}"
            )

        if self._is_body_signature(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.BODY,
                reason="utet_wolterskluwer_body",
            )

        return verdict

    # ------------------------------------------------------------------
    # Signature predicates

    @staticmethod
    def _is_body_signature(view: _BlockView) -> bool:
        """A body block opens with TimesTenLTStd-Roman or -Italic at 10.0pt."""
        if not view.spans:
            return False
        leading = view.spans[0]
        family_ok = leading.font.startswith(BODY_FONT_PREFIX)
        size_ok = abs(leading.size - BODY_FONT_SIZE) < 0.1
        return family_ok and size_ok

    @staticmethod
    def _is_chapter_or_front_matter_signature(view: _BlockView) -> bool:
        """A 12.0pt block in the TimesTenLTStd family."""
        if not view.spans:
            return False
        leading = view.spans[0]
        family_ok = leading.font.startswith(BODY_FONT_PREFIX)
        size_ok = abs(leading.size - CHAPTER_HEADING_SIZE) < 0.1
        return family_ok and size_ok

    @staticmethod
    def _is_paragraph_heading(view: _BlockView) -> bool:
        """A paragraph heading opens with a 10.5pt number span.

        The Mosconi typesetting puts the number in a non-bold
        ``TimesTenLTStd-Roman`` 10.5pt span and the title in a bold
        ``TimesTenLTStd-Bold`` 10.5pt span. Both are required to be
        present: a bare number block without a following bold title is
        more likely a stray formatting glitch than a heading.
        """
        if len(view.spans) < 2:
            return False
        first = view.spans[0]
        first_family = first.font.startswith(BODY_FONT_PREFIX)
        first_size = abs(first.size - PARAGRAPH_HEADING_SIZE) < 0.1
        if not (first_family and first_size):
            return False
        if not _PARAGRAPH_NUMBER_PATTERN.match(first.text):
            return False
        return any(
            span.font.startswith(BODY_FONT_PREFIX)
            and abs(span.size - PARAGRAPH_HEADING_SIZE) < 0.1
            and bool(span.flags & BOLD_FLAG_BIT)
            for span in view.spans[1:]
        )

    @staticmethod
    def _is_marginal_heading(view: _BlockView) -> bool:
        """A marginal heading is a 7.0pt block sitting against the page edge.

        Either left margin (``bbox.x0 < LEFT_MARGIN_X_THRESHOLD``) or
        right margin (``bbox.x0 > RIGHT_MARGIN_X_THRESHOLD``). The
        font family check accepts both Roman and Italic 7.0pt: a few
        marginals use the italic variant for emphasis.
        """
        if not view.spans:
            return False
        leading = view.spans[0]
        family_ok = leading.font.startswith(BODY_FONT_PREFIX)
        size_ok = abs(leading.size - MARGINAL_HEADING_SIZE) < 0.1
        if not (family_ok and size_ok):
            return False
        x0 = view.block.bbox[0]
        return x0 < LEFT_MARGIN_X_THRESHOLD or x0 > RIGHT_MARGIN_X_THRESHOLD

    @staticmethod
    def _is_example_box(view: _BlockView) -> bool:
        """An example box opens with TimesTenLTStd-Italic at 9.0pt and is long enough."""
        if not view.spans:
            return False
        leading = view.spans[0]
        family_ok = leading.font.startswith(BODY_FONT_PREFIX)
        size_ok = abs(leading.size - EXAMPLE_BOX_SIZE) < 0.1
        italic_ok = leading.is_italic
        long_enough = len(view.text) >= EXAMPLE_BOX_MIN_TEXT_LENGTH
        return family_ok and size_ok and italic_ok and long_enough

    @staticmethod
    def _is_note(view: _BlockView) -> bool:
        """A note block opens with a small marker number then 8.0pt body.

        The marker glyph is short (one or two digits) and rendered at a
        small size that varies in PyMuPDF's reported metrics between
        ~4pt and ~6pt depending on the line; the subsequent body is
        sized at :data:`NOTE_BODY_SIZE`. The textual marker pattern
        runs against the full concatenated block text rather than the
        leading span alone, because the small marker glyph and the
        following ``". "`` are typically split across two spans — the
        digit lives in the small-size span and the dot + space in the
        8.0pt body span.

        The discriminator is therefore: a 8.0pt body span is present
        in the block AND the leading span is in the small-marker size
        range AND the block text starts with the ``\\d+\\.\\s`` marker.
        The size range is set loose on the marker side (4.0 to 6.5 pt)
        to absorb the metric drift PyMuPDF reports across editions.
        """
        if len(view.spans) < 2:
            return False
        first = view.spans[0]
        family_ok = first.font.startswith(BODY_FONT_PREFIX)
        marker_size_ok = NOTE_MARKER_SIZE_MIN <= first.size <= NOTE_MARKER_SIZE_MAX
        if not (family_ok and marker_size_ok):
            return False
        if not _NOTE_MARKER_PATTERN.match(view.text.lstrip()):
            return False
        return any(
            span.font.startswith(BODY_FONT_PREFIX)
            and abs(span.size - NOTE_BODY_SIZE) < _NOTE_BLOCK_SIZE_TOLERANCE
            for span in view.spans[1:]
        )

    @staticmethod
    def _is_note_continuation(view: _BlockView) -> bool:
        """A note continuation is a pure 8.0pt body block on a footnote line.

        Used to recognise intra-page multi-block notes whose textual
        continuation does not open with the numeric marker. The
        decision whether to actually treat the block as a note
        continuation is delegated to :meth:`refine_reconstruction`,
        which checks the spatial / sibling context; this predicate
        only signals "the typographic signature is compatible with a
        continuation".

        A geometric guard rejects narrow full-column-height blocks
        that share the 8.0pt TimesTenLTStd-Roman signature but are
        structurally distinct from footnotes — namely the
        back-matter ``Indice della giurisprudenza`` columns on
        pp.586-611 of the calibrating fixture. Without the guard the
        downstream cross-page note merging resolver in
        :mod:`apparatus.resolver` chains every index column back to
        the most recent legitimate footnote, producing a single NOTE
        Node of >100k chars (Mosconi outlier ``node_3479`` on the
        2026-05-19 panoramica). Detection is delegated to
        :meth:`_is_back_matter_index_column`; the guarded blocks fall
        through ``_reclassify`` to UNCLASSIFIED.
        """
        if not view.spans:
            return False
        leading = view.spans[0]
        family_ok = leading.font.startswith(BODY_FONT_PREFIX)
        size_ok = abs(leading.size - NOTE_BODY_SIZE) < _NOTE_BLOCK_SIZE_TOLERANCE
        if not (family_ok and size_ok):
            return False
        if ManualeUtetWolterskluwerProfile._is_back_matter_index_column(view):
            return False
        # A continuation must not open with the numeric marker pattern;
        # if it does it is the start of a new note, not a continuation.
        return not _NOTE_MARKER_PATTERN.match(view.text.lstrip())

    @staticmethod
    def _looks_like_continuation_signature(view: _BlockView) -> bool:
        """Return True when the leading span carries the 8.0pt body
        TimesTenLTStd-Roman signature that a note continuation would
        match. Companion predicate of :meth:`_is_back_matter_index_column`
        used by ``_reclassify`` to surface a per-block warning when a
        back-matter index column is rejected on geometric grounds.
        """
        if not view.spans:
            return False
        leading = view.spans[0]
        return leading.font.startswith(BODY_FONT_PREFIX) and (
            abs(leading.size - NOTE_BODY_SIZE) < _NOTE_BLOCK_SIZE_TOLERANCE
        )

    @staticmethod
    def _is_back_matter_index_column(view: _BlockView) -> bool:
        """Recognise a back-matter index column by geometry.

        See the geometric-guard rationale on
        :meth:`_is_note_continuation`. The predicate is intentionally
        signal-redundant: it requires both a narrow width
        (``< _BACK_MATTER_INDEX_COLUMN_MAX_WIDTH_PT``, ruling out the
        single-column body) and a tall height
        (``> _BACK_MATTER_INDEX_COLUMN_MIN_HEIGHT_PT``, ruling out
        any short legitimate footnote that happens to fit in a narrow
        bbox). On the calibrating fixture exactly 52 blocks match,
        all on pp.586-611, with zero false positives among the
        legitimate notes.
        """
        bbox = view.block.bbox
        width = bbox[2] - bbox[0]
        height = bbox[3] - bbox[1]
        return (
            width < _BACK_MATTER_INDEX_COLUMN_MAX_WIDTH_PT
            and height > _BACK_MATTER_INDEX_COLUMN_MIN_HEIGHT_PT
        )

    @staticmethod
    def _looks_like_index_residue(text: str) -> bool:
        return bool(_FRONT_MATTER_INDEX_OPENERS.match(text.lstrip()))

    # ------------------------------------------------------------------
    # Chapter pair detection

    def _register_chapter_pairs(self, refined: list[ClassifiedBlock]) -> None:
        """Promote provisional front-matter headings to chapter titles where due.

        Two-pass design: :meth:`_reclassify` classifies every 12pt
        non-chapter-number block as HEADING_1 (front matter), provisional.
        This pass walks the refined verdicts in extraction order and, for
        each chapter-number verdict, promotes the next non-stamp HEADING_1
        provisional block to HEADING_2 (chapter title). The block_index
        of the promoted title is registered in
        :attr:`_chapter_title_blocks` for the pair fusion in
        :meth:`refine_reconstruction`. Intervening ``ARTIFACT_STAMP``
        blocks (the editorial-proof watermark) are tolerated; the search
        stops at the first non-stamp non-HEADING_1 block.
        """
        n = len(refined)
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
                    candidate.category is SemanticCategory.HEADING_1
                    and candidate.reason == "utet_wolterskluwer_front_matter_heading"
                ):
                    refined[j] = ClassifiedBlock(
                        block_index=candidate.block_index,
                        category=SemanticCategory.HEADING_2,
                        reason="utet_wolterskluwer_chapter_title",
                    )
                    self._chapter_title_blocks.add(candidate.block_index)
                break

    # ------------------------------------------------------------------
    # Tree refinement

    def _fuse_and_refine(
        self,
        roots: tuple[Node, ...],
        warnings: list[str],
        extraction: ExtractionResult,
        next_id: NodeIdMinter,
    ) -> tuple[Node, ...]:
        """Return a new forest with chapter pairs fused, cross-refs minted,
        notes consolidated, and orphan marginal markers diagnosed.
        """
        # Step 1: fuse chapter pairs and recurse into descendants.
        fused = self._fuse_chapters_recursive(roots, warnings, extraction)
        # Step 2: at every sibling level, mint cross-refs and consolidate notes.
        return self._refine_sibling_level(fused, warnings, extraction, next_id)

    def _fuse_chapters_recursive(
        self,
        roots: tuple[Node, ...],
        warnings: list[str],
        extraction: ExtractionResult,
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
                fused = self._fuse_chapter_pair(node, partner, warnings, extraction)
                new_nodes.append(fused)
                i += 2
                continue
            if self._is_chapter_number_node(node):
                warnings.append(
                    f"{WARNING_PREFIX}:chapter_title_not_adjacent_block_"
                    f"{node.block_indices[0] if node.block_indices else -1}_"
                    f"page_{node.page_index}"
                )
            new_children = self._fuse_chapters_recursive(node.children, warnings, extraction)
            if new_children == node.children:
                new_nodes.append(node)
            else:
                new_nodes.append(
                    Node(
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
                )
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
        warnings: list[str],
        extraction: ExtractionResult,
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
            tuple((*number_node.children, *title_node.children)), warnings, extraction
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

    def _refine_sibling_level(
        self,
        nodes: tuple[Node, ...],
        warnings: list[str],
        extraction: ExtractionResult,
        next_id: NodeIdMinter,
    ) -> tuple[Node, ...]:
        """Mint inline cross-references, consolidate adjacent notes, recurse."""
        # First recurse into descendants so that the children's own
        # CROSS_REFERENCE / NOTE refinement happens before this level.
        rebuilt: list[Node] = []
        for node in nodes:
            new_children = self._refine_sibling_level(node.children, warnings, extraction, next_id)
            if new_children == node.children:
                rebuilt.append(node)
            else:
                rebuilt.append(
                    Node(
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
                )

        # Apply the three tier 2 reconstruction steps to this sibling list.
        with_crossrefs = self._mint_cross_references(rebuilt, warnings, extraction, next_id)
        consolidated = self._consolidate_notes(with_crossrefs, warnings)
        self._diagnose_marginal_orphans(consolidated, warnings)
        return tuple(consolidated)

    def _mint_cross_references(
        self,
        nodes: list[Node],
        warnings: list[str],
        extraction: ExtractionResult,
        next_id: NodeIdMinter,
    ) -> list[Node]:
        """Insert synthetic CROSS_REFERENCE nodes after BODY nodes with inline superscripts."""
        result: list[Node] = []
        for node in nodes:
            result.append(node)
            if node.category is not SemanticCategory.BODY:
                continue
            for block_index in node.block_indices:
                if block_index < 0 or block_index >= len(extraction.blocks):
                    continue
                block = extraction.blocks[block_index]
                start, end = block.span_range
                for span in extraction.spans[start:end]:
                    if not self._is_inline_crossref_span(span):
                        continue
                    digit = span.text.strip()
                    crossref = Node(
                        id=next_id.mint(),
                        category=SemanticCategory.CROSS_REFERENCE,
                        page_index=node.page_index,
                        block_indices=(block_index,),
                        text=digit,
                    )
                    result.append(crossref)
                    warnings.append(
                        f"{WARNING_PREFIX}:inline_cross_reference_minted_node_"
                        f"{crossref.id}_page_{crossref.page_index}"
                    )
        return result

    @staticmethod
    def _is_inline_crossref_span(span: Span) -> bool:
        if not span.is_superscript:
            return False
        if not span.font.startswith(BODY_FONT_PREFIX):
            return False
        if not any(abs(span.size - sz) < 0.1 for sz in CROSS_REFERENCE_SIZES):
            return False
        return span.text.strip().isdigit()

    def _consolidate_notes(
        self,
        nodes: list[Node],
        warnings: list[str],
    ) -> list[Node]:
        """Fuse adjacent NOTE siblings on the same page when the second is a continuation."""
        result: list[Node] = []
        for node in nodes:
            if (
                result
                and node.category is SemanticCategory.NOTE
                and result[-1].category is SemanticCategory.NOTE
                and node.page_index == result[-1].page_index
                and node.text is not None
                and not _NOTE_MARKER_PATTERN.match(node.text.lstrip())
            ):
                previous = result[-1]
                assert previous.text is not None
                merged_text = f"{previous.text} {node.text.lstrip()}"
                merged = Node(
                    id=previous.id,
                    category=SemanticCategory.NOTE,
                    children=previous.children,
                    page_index=previous.page_index,
                    block_indices=previous.block_indices + node.block_indices,
                    text=merged_text,
                    level=previous.level,
                    summary_items=previous.summary_items,
                    toc_items=previous.toc_items,
                    length_category=compute_note_length_category(merged_text),
                    apparatus_refs=previous.apparatus_refs,
                )
                result[-1] = merged
                warnings.append(
                    f"{WARNING_PREFIX}:note_continuation_merged_node_"
                    f"{previous.id}_page_{previous.page_index}"
                )
                continue
            result.append(node)
        return result

    def _diagnose_marginal_orphans(
        self,
        nodes: list[Node],
        warnings: list[str],
    ) -> None:
        """Emit a warning for each MARGINAL_HEADING ending in ``...`` without a successor."""
        for i, node in enumerate(nodes):
            if node.category is not SemanticCategory.MARGINAL_HEADING:
                continue
            if node.text is None or not node.text.rstrip().endswith("..."):
                continue
            successor = nodes[i + 1] if i + 1 < len(nodes) else None
            if (
                successor is not None
                and successor.category is SemanticCategory.MARGINAL_HEADING
                and successor.text is not None
                and successor.text.lstrip().startswith("...")
            ):
                continue  # valid chain head, the step will merge it
            warnings.append(
                f"{WARNING_PREFIX}:marginal_ellipsis_orphan_marker_node_"
                f"{node.id}_page_{node.page_index}"
            )

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
