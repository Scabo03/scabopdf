"""Corpus plugin for the UTET "Compendio" series — Tesauro tax law manual.

Second real corpus plugin of the project. Handles the Tesauro
"Compendio di Diritto Tributario" (UTET Giuridica, 9th edition, 2023) —
see ``docs/analysis/ANALYSIS_TESAURO_COMPENDIO.md`` for the editorial
analysis the plugin is built against.

The manual is a **pure compendium**: single-column body in
``TimesTenLTStd-Roman`` 10.2pt at 88.7 % typographic dominance, **zero
apparatus** (no footnotes, no marginal headings, no example boxes), a
front-matter ``TOC_GENERAL`` (typeset in the ``TimesTen`` non-LT
variant at 8.5pt with the ``»`` page-number marker), a
``CHAPTER_SUMMARY`` opening each of the 27 chapters (typeset in
``TimesTen-Roman`` 8.0pt with the ``TimesTen-Roman-SC700`` small-caps
label), two paragraph levels and an editorial-proof watermark on every
page (``261887_Quarta_Bozza.indb`` + a date/time stamp) that the plugin
filters as ``ARTIFACT_STAMP``.

Four heading-like levels:

- **H2 — chapter.** Two consecutive blocks the plugin merges into one
  node: the "Capitolo `<ord>`" block in ``TimesTenLTStd-Roman`` 12.0pt
  (non-bold) and the title block in ``TimesTenLTStd-Bold`` 12.0pt
  immediately following. The Italian ordinal is preserved verbatim
  (e.g. ``"Capitolo decimo. L'AVVISO DI ACCERTAMENTO"``), not mapped to
  a digit: ordinals are kept as strings, sequence position is inferred
  from order of appearance when needed.
- **H3 — paragraph L1.** Pattern ``^\\d+\\.\\s+\\w`` with
  ``TimesTenLTStd-Bold/Italic`` 10.0pt signature. 275 entries expected.
- **H4 — sub-paragraph L2.** Pattern ``^\\d+\\.\\d+\\.\\s+\\w`` with
  the same ``Bold/Italic`` signature at 10.2pt (the body size). The
  0.2pt size difference between L1 and L2 is below the noise floor of
  PyMuPDF's metric extraction; the plugin therefore uses
  **pattern-over-signature** discrimination: a block with two dots in
  the numeric prefix is L2 regardless of the exact size measured. 216
  entries expected.

Apparatus-like structures:

- ``CHAPTER_SUMMARY`` blocks (one per chapter) opening with the
  ``"Sommario:"`` label and listing the chapter's paragraphs separated
  by en-dashes. Parsed into ``SummaryItem(number, title)`` tuples by
  ``refine_reconstruction`` using the same en-dash splitter as the
  Zanichelli plugin.
- ``TOC_GENERAL`` blocks in the front matter (pages with TimesTen
  non-LT 8.5pt and the ``»`` marker) listing every paragraph of the
  manual with its book page number. Parsed into
  ``TocGeneralItem(number, title, page_number)`` triples. The page
  number is the **1-based book page** printed after the ``»`` glyph,
  semantically distinct from the 0-based ``page_index`` of the source
  block.

The ``LIST_ITEM`` category is emitted for body sub-blocks whose first
character (after whitespace stripping) is an en-dash codepoint
(U+2013) followed by whitespace. The manual uses these as inline
lists; surfacing them as a dedicated category lets Layer 2 announce
list semantics on screen-reader playback.

The ``ARTIFACT_STAMP`` category is recognised by a **general** regex
pattern matching either ``^\\d+_[A-Za-z0-9_]+\\.indb`` (the InDesign
filename) or ``^\\d{2}/\\d{2}/\\d{2}\\s+\\d{1,2}:\\d{2}`` (the
date/time stamp). Generalising the pattern means future UTET PDFs
carrying analogous pre-print residue will be handled by the same
plugin without modification.

The plugin's ``matches()`` discriminator is built to clear 0.6
confidence on Tesauro and stay safely below 0.6 on the future
``manuale_utet_wolterskluwer`` profile (Mosconi-Campiglio), which
shares the editorial pipeline (Adobe InDesign CS6 + PDF Library
10.0.1) and the typographic family (TimesTenLTStd) but has a dense
apparatus (≈965 footnotes + ≈593 marginal headings). The
discrimination uses **negative apparatus signals**: a low
``footnote_markers`` / ``marginal_headings`` count contributes a
positive bonus, a high one a negative penalty large enough to drive
the score below the 0.6 threshold. The current matches() returns
~0.95 on Tesauro signals and ~0.30 on Mosconi-like signals.

The plugin keeps a small bag of pending warnings and a pair of
block-index sets as instance state between
:meth:`refine_classification` and :meth:`refine_reconstruction`. The
warnings flush into ``Document.warnings`` analogously to the Zanichelli
plugin; the block-index sets record which blocks were classified as
the "Capitolo `<ord>`" half and the title half of a chapter heading
pair, so that ``refine_reconstruction`` can fuse the two consecutive
``HEADING_2`` siblings into a single node carrying the combined text
and both ``block_indices``.

The closed warning vocabulary uses the ``plugin:tesauro:`` prefix and
is documented in ``docs/SCHEMA_v0.4.0.md`` § 6.
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
from scabopdf_pipeline.reconstruction.types import Document, Node, SummaryItem, TocGeneralItem
from scabopdf_pipeline.schema.categories import SemanticCategory

WARNING_PREFIX = "plugin:tesauro"
"""Common prefix for every warning string this plugin may emit.

The closed vocabulary lives in :data:`WARNING_TEMPLATES`. See
``docs/SCHEMA_v0.4.0.md § 6`` for the rationale of the prefix
convention.
"""

WARNING_TEMPLATES: tuple[str, ...] = (
    "plugin:tesauro:chapter_summary_unparseable_node_<id>",
    "plugin:tesauro:toc_general_unparseable_node_<id>",
    "plugin:tesauro:chapter_title_not_adjacent_block_<idx>_page_<p>",
)
"""Closed vocabulary of warnings the plugin may emit on
``Document.warnings``. Placeholders are replaced with concrete values
at emission time. Consumers should match on the prefix.
"""

EN_DASH = "\u2013"
"""En-dash character (U+2013) used as a separator and a list marker.

Kept as an explicit escape so ruff's ``RUF001`` does not flag the
character as ambiguous. This is the codepoint the Tesauro typesetting
emits in PyMuPDF's text output (both as a list marker at the start of
a body sub-block and as the separator inside CHAPTER_SUMMARY entries).
"""

ITALIAN_ORDINALS: tuple[str, ...] = (
    "primo",
    "secondo",
    "terzo",
    "quarto",
    "quinto",
    "sesto",
    "settimo",
    "ottavo",
    "nono",
    "decimo",
    "undicesimo",
    "dodicesimo",
    "tredicesimo",
    "quattordicesimo",
    "quindicesimo",
    "sedicesimo",
    "diciassettesimo",
    "diciottesimo",
    "diciannovesimo",
    "ventesimo",
    "ventunesimo",
    "ventiduesimo",
    "ventitreesimo",
    "ventiquattresimo",
    "venticinquesimo",
    "ventiseiesimo",
    "ventisettesimo",
    "ventottesimo",
)
"""Closed list of Italian ordinals the Tesauro chapter headings use.

The 9th-edition table of contents enumerates 27 chapters; ``ventottesimo``
is kept in the whitelist for forward compatibility with the 10th
edition. Preserving the ordinal verbatim in the emitted heading text
(see ``refine_reconstruction``) means the plugin never needs to map
the ordinal back to a digit — the user's design decision said order of
appearance is the only authoritative sequence indicator.
"""

_CHAPTER_NUMBER_PATTERN = re.compile(
    r"^Capitolo\s+(" + "|".join(ITALIAN_ORDINALS) + r")\s*$",
    re.IGNORECASE,
)
"""Pattern matching the "Capitolo `<ordinal>`" block text exactly.

Anchored on both ends with optional trailing whitespace; the
case-insensitive flag covers minor casing drift across editions
without sacrificing diagnostic power on the editorial intent
(``Capitolo decimo`` is what the Tesauro typesets).
"""

_PARAGRAPH_L1_PATTERN = re.compile(r"^\d+\.\s+\S")
"""Pattern for L1 paragraph headings: ``1. <title>``.

A single integer followed by a dot, whitespace, and at least one
non-whitespace character (the title). The pattern deliberately rejects
L2 entries (``1.1.``) because those carry an extra dotted segment.
See :data:`_PARAGRAPH_L2_PATTERN` and the pattern-over-signature
discussion in the module docstring.
"""

_PARAGRAPH_L2_PATTERN = re.compile(r"^\d+\.\d+\.\s+\S")
"""Pattern for L2 sub-paragraph headings: ``1.1. <title>``.

Two integers separated by a dot, then a final dot, whitespace and at
least one non-whitespace character. Matched **before** the L1 pattern
in :meth:`CompendioUtetProfile._reclassify` so that an entry like
``1.1. Profili costituzionali`` is recognised as L2 (HEADING_4) even
though its block signature size measured by PyMuPDF (10.2pt) accidents
to match the body's 10.2pt rather than the L1's nominal 10.0pt.
"""

_LIST_ITEM_PATTERN = re.compile(rf"^\s*{re.escape(EN_DASH)}\s+\S")
"""Pattern for inline list items: en-dash (U+2013) + whitespace + text.

The en-dash plus whitespace prefix is the convention the Tesauro uses
to introduce list items inside body paragraphs (see ANALYSIS § 5.4).
The plugin surfaces these as their own category so Layer 2 can
announce list semantics on screen-reader playback.
"""

_STAMP_FILENAME_PATTERN = re.compile(r"^\d+_[A-Za-z0-9_]+\.indb")
"""Pattern for the InDesign filename watermark.

Tesauro's pre-print artefact is ``261887_Quarta_Bozza.indb`` — a numeric
product code, an editorial label, and the ``.indb`` extension.
Generalised to ``\\d+_[A-Za-z0-9_]+\\.indb`` so the same plugin
recognises analogous residue in any future UTET PDF.
"""

_STAMP_DATETIME_PATTERN = re.compile(r"^\d{2}/\d{2}/\d{2}\s+\d{1,2}:\d{2}")
"""Pattern for the date/time watermark accompanying the filename stamp.

Tesauro's stamp reads ``05/09/23 3:50 PM`` (a calendar date plus a
24h-ish clock value). Generalised to allow any two-digit dd/mm/yy and
H:MM or HH:MM combination.
"""

BODY_FONT_PREFIX_LT = "TimesTenLTStd"
"""Font family of the body, headings, footer and stamp on Tesauro."""

BODY_FONT_PREFIX_NON_LT = "TimesTen"
"""Font family of the front-matter TOC and the chapter summaries.

The two ``TimesTen`` variants (``TimesTenLTStd`` vs plain ``TimesTen``)
are typographically distinct in the editorial pipeline: the first is
the body and headings, the second the navigation apparatus. The
plugin uses the second prefix to recognise both the ``TOC_GENERAL``
and the ``CHAPTER_SUMMARY`` signatures.

Because ``TimesTenLTStd`` starts with ``TimesTen`` as a substring, the
non-LT check must be performed with an *exact* family match (after
splitting on the dash separator the PyMuPDF font naming uses), not a
``startswith`` prefix test.
"""

BODY_FONT_SIZE = 10.2
"""Body and L2 paragraph heading size, in points."""

PARAGRAPH_L1_SIZE = 10.0
"""Nominal L1 paragraph heading size, in points (10.0 vs body 10.2)."""

CHAPTER_HEADING_SIZE = 12.0
"""Chapter heading size for both the number block and the title block."""

SUMMARY_SIZE = 8.0
"""``CHAPTER_SUMMARY`` body size; the small-caps label uses 5.6pt."""

TOC_GENERAL_SIZE = 8.5
"""``TOC_GENERAL`` entry size on the front-matter index."""

STAMP_SIZE = 9.0
"""``ARTIFACT_STAMP`` font size for both filename and date/time strings."""

CONFIDENCE_BODY_DOMINANT = 0.45
"""Confidence contribution when TimesTenLTStd 10.2pt dominates the body."""

CONFIDENCE_SUMMARY_SC_FONT = 0.20
"""Confidence contribution for the ``TimesTen-Roman-SC700`` small caps.

The small-caps variant is the strongest single typographic signal of
the UTET compendium profile: ``manuale_utet_wolterskluwer`` uses
TimesTenLTStd too but has no SC700 variant in its summaries.
"""

CONFIDENCE_TOC_FONT = 0.10
"""Confidence contribution when TimesTen 8.5pt is present (TOC signal)."""

CONFIDENCE_UTET_PIPELINE = 0.05
"""Confidence contribution when producer/creator match the UTET pipeline."""

CONFIDENCE_OUTLINE_ABSENT = 0.05
"""Confidence contribution when the PDF carries no outline."""

CONFIDENCE_NO_APPARATUS_BONUS = 0.10
"""Bonus when apparatus_presence reports zero footnotes and marginals.

This is the **positive compendium signal**: a UTET document with the
TimesTenLTStd body and no apparatus is almost certainly a compendium.
"""

CONFIDENCE_HAS_APPARATUS_PENALTY = -0.30
"""Penalty when the document looks like a treatise instead of a compendium.

When ``footnote_markers >= 50`` or ``marginal_headings >= 50`` the
document is structurally a treatise and a future ``manuale_utet_wolters
kluwer`` plugin should handle it. The Tesauro plugin steps back by
applying a large negative contribution: the typographic signals will
add up to ~0.6, the penalty drives the final score to ~0.3, safely
below the 0.6 dispatcher threshold.
"""

BODY_DOMINANCE_MIN_PERCENT = 70.0
"""Minimum dominance required to credit the TimesTenLTStd body signal.

Tesauro measures 88.7 %; the threshold leaves headroom for editorial
variants of the same pipeline.
"""

# ``APPARATUS_PRESENCE_THRESHOLD`` was promoted to
# :mod:`scabopdf_pipeline.profiling.typography_constants` (P-035 of the
# Promotion Analysis Fase 1). It is now imported at the top of this
# module from ``profiling.typography_constants``.

UTET_PRODUCER_FRAGMENT = "PDF Library"
"""Producer-field substring that signals the UTET editorial pipeline."""

UTET_CREATOR_FRAGMENT = "InDesign CS"
"""Creator-field substring that signals the UTET editorial pipeline."""

CHAPTER_HEADING_TEXT_LIMIT = 80
"""Max text length for a candidate chapter-number or chapter-title block.

Chapter number blocks are short (``Capitolo decimo``) and title blocks
are short uppercase labels (``L'AVVISO DI ACCERTAMENTO``). A block
sharing the 12pt signature but carrying significantly more text is
not a chapter heading and is left UNCLASSIFIED.
"""

PARAGRAPH_HEADING_TEXT_LIMIT = 200
"""Max text length for an L1 or L2 paragraph heading.

Paragraph headings are one-liners. A 12pt-bold block longer than this
is almost certainly something else (e.g. a stray formatting glitch);
the plugin refuses to commit to a heading verdict in that case.
"""

CHAPTER_TITLE_BOLD_FLAG_BIT = 0x10
"""PyMuPDF's bold flag bit on Span.flags (``flag_bits.BOLD = 16``).

Used to distinguish the "Capitolo `<ord>`" block (non-bold) from the
title block (bold) at the 12pt signature.
"""

_SOMMARIO_LABEL = "Sommario"
"""Textual label that opens every chapter summary block.

The Tesauro typesets ``Sommario:`` with a colon; the plugin accepts
both ``Sommario`` and ``Sommario:`` by stripping the trailing colon
during parsing.
"""

_SUMMARY_SPLITTER = re.compile(rf"\s*{re.escape(EN_DASH)}\s*")
"""Regex that splits a CHAPTER_SUMMARY text on its en-dash separators."""

_SUMMARY_ITEM_PATTERN = re.compile(
    r"^\s*(?P<num>\d+(?:\.\d+)*)\.\s*(?P<title>\S.+?)\s*$", re.DOTALL
)
"""Regex that parses one ``CHAPTER_SUMMARY`` entry into ``(number, title)``.

Composite numerations (``"1.1"``) are admitted for forward
compatibility. ``re.DOTALL`` lets the title span an embedded line
break that the typesetter sometimes introduces; the title is then
whitespace-normalised by :data:`_INTERNAL_WHITESPACE`.
"""

_TOC_ENTRY_PATTERN = re.compile(
    r"(?P<num>\d+(?:\.\d+)*)\.\s+"
    r"(?P<title>.+?)"
    rf"(?:\s*\.{{2,}}|\s+){re.escape('»')}\s*"
    r"(?P<page>\d+|[IVXLCDM]+)",
    re.DOTALL,
)
"""Regex that finds one ``TOC_GENERAL`` entry inside a longer block text.

A TOC entry has the shape ``<num>. <title> ........... » <page>``, with
the dotted leader sometimes collapsed into a sequence of spaces by
PyMuPDF's text extraction. The pattern is intentionally tolerant:

- ``<num>`` admits composite numerations.
- ``<title>`` is non-greedy and ``re.DOTALL`` so it can span line
  breaks the typesetter introduces inside very long titles.
- The leader between the title and the page is either two or more
  consecutive dots or one or more whitespace runs.
- ``<page>`` matches a positive integer (the common case) or a roman
  numeral (the rare front-matter back-reference). The parser then
  converts the integer form and emits ``page_number: None`` for the
  roman form, per the user's design decision documented in
  ``docs/SCHEMA_v0.4.0.md`` § 3 (``TocGeneralItem``).

The pattern is used with :meth:`re.Pattern.finditer` rather than
:meth:`re.Pattern.match` to extract every entry from the larger TOC
block.
"""

_INTERNAL_WHITESPACE = re.compile(r"\s+")
"""Regex used to collapse runs of whitespace inside parsed titles."""

_DOTTED_LEADER = re.compile(r"\.{2,}")
"""Regex used to strip the dotted leader from a TOC title before
whitespace normalisation."""


@dataclass(frozen=True)
class _BlockView:
    """Pre-computed view of a block exposed to the plugin's tier 2 logic.

    ``primary_font`` and ``primary_size`` reflect the first span. The
    Tesauro is uniform enough at the block level that the first span
    is a reliable proxy for the whole block's signature: heading
    blocks are single-font, paragraph blocks open with the bold number
    span, body blocks open with the Roman variant.
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
    def primary_is_bold(self) -> bool:
        if not self.spans:
            return False
        return bool(self.spans[0].flags & CHAPTER_TITLE_BOLD_FLAG_BIT)


def _font_family(font: str) -> str:
    """Return the family component of a PyMuPDF font name.

    PyMuPDF concatenates the family with a dash-prefixed weight/style
    (e.g. ``"TimesTenLTStd-Roman"``, ``"TimesTen-Roman-SC700"``,
    ``"TimesTenLTStd-Bold"``). The family is everything up to the
    first dash. When the font has no dash, the whole string is the
    family.
    """
    dash = font.find("-")
    return font if dash < 0 else font[:dash]


class CompendioUtetProfile(ProfilePlugin):
    """Corpus plugin for the UTET "Compendio" series — Tesauro 9th ed."""

    profile_id: ClassVar[str] = "compendio_utet"
    editorial_family: ClassVar[str] = "utet"
    genre: ClassVar[str] = "compendio"

    def __init__(self) -> None:
        self._pending_warnings: list[str] = []
        self._chapter_number_blocks: set[int] = set()
        self._chapter_title_blocks: set[int] = set()

    @classmethod
    def get_warning_templates(cls) -> tuple[str, ...]:
        return WARNING_TEMPLATES

    @classmethod
    def matches(cls, signals: ProfilingSignals) -> float:
        """Score the document against the Tesauro compendium fingerprint.

        Six additive contributions, with a deliberate sign flip on the
        apparatus presence axis to discriminate the Tesauro compendium
        from the future ``manuale_utet_wolterskluwer`` profile that
        shares the editorial pipeline. See the module docstring for the
        editorial rationale.
        """
        score = 0.0

        body_dominant = any(
            font.family.startswith(BODY_FONT_PREFIX_LT)
            and abs(font.size - BODY_FONT_SIZE) < 0.1
            and font.dominance_percent >= BODY_DOMINANCE_MIN_PERCENT
            for font in signals.typographic_signature.fonts
        )
        if body_dominant:
            score += CONFIDENCE_BODY_DOMINANT

        sc_font_present = any(
            "SC700" in font.family for font in signals.typographic_signature.fonts
        )
        if sc_font_present:
            score += CONFIDENCE_SUMMARY_SC_FONT

        toc_font_present = any(
            _font_family(font.family) == BODY_FONT_PREFIX_NON_LT
            and abs(font.size - TOC_GENERAL_SIZE) < 0.1
            for font in signals.typographic_signature.fonts
        )
        if toc_font_present:
            score += CONFIDENCE_TOC_FONT

        producer = (signals.producer_creator.producer or "").strip()
        creator = (signals.producer_creator.creator or "").strip()
        if UTET_PRODUCER_FRAGMENT in producer or UTET_CREATOR_FRAGMENT in creator:
            score += CONFIDENCE_UTET_PIPELINE

        if not signals.outline_structure.has_outline:
            score += CONFIDENCE_OUTLINE_ABSENT

        apparatus = signals.apparatus_presence
        if (
            apparatus.footnote_markers >= APPARATUS_PRESENCE_THRESHOLD
            or apparatus.marginal_headings >= APPARATUS_PRESENCE_THRESHOLD
        ):
            score += CONFIDENCE_HAS_APPARATUS_PENALTY
        elif apparatus.footnote_markers == 0 and apparatus.marginal_headings == 0:
            score += CONFIDENCE_NO_APPARATUS_BONUS

        return max(0.0, score)

    def get_categories(self) -> set[SemanticCategory]:
        """Closed set of categories the plugin may emit on Tesauro."""
        return {
            SemanticCategory.HEADING_2,
            SemanticCategory.HEADING_3,
            SemanticCategory.HEADING_4,
            SemanticCategory.BODY,
            SemanticCategory.LIST_ITEM,
            SemanticCategory.CHAPTER_SUMMARY,
            SemanticCategory.TOC_GENERAL,
            SemanticCategory.ARTIFACT_STAMP,
            SemanticCategory.ARTIFACT_FOOTER,
            SemanticCategory.ARTIFACT_RUNNING_HEADER,
            SemanticCategory.ARTIFACT_FILIGREE,
            SemanticCategory.BOOK_PAGE_ANCHOR,
            SemanticCategory.CROSS_REFERENCE,
            SemanticCategory.UNCLASSIFIED,
            SemanticCategory.EMPTY_PAGE,
        }

    def get_post_processing(self) -> list[str]:
        """No post-processing steps.

        Tesauro is digitally typeset (no OCR cleanup needed) and the
        editorial-proof watermark is filtered upstream by the tier 2
        classifier, not by a post-processing step. Layout 4 is
        disabled (no inline notes), so no acoustic-regime
        transformation is necessary either.
        """
        return []

    def get_layouts_disabled(self) -> list[DisabledLayout]:
        """Disable Layout 4: the manual has no inline footnotes."""
        return [
            DisabledLayout(
                layout="L4",
                reason=(
                    "Il compendio Tesauro è privo di apparato: niente note a "
                    "piè di pagina, niente note marginali, niente box. Il "
                    "Layout 4 (Dottrina), che si fonda sui marcatori inline "
                    "delle note, non si applica."
                ),
            )
        ]

    def refine_classification(
        self,
        extraction: ExtractionResult,
        tier1_results: list[ClassifiedBlock],
    ) -> list[ClassifiedBlock]:
        """Promote UNCLASSIFIED blocks to the plugin's category vocabulary.

        The pass touches only blocks tier 1 left as ``UNCLASSIFIED``;
        verdicts for filigree, running header, footer, book-page anchor
        and cross-reference are preserved. The pass is **two-pronged**:
        a first sweep classifies each block in isolation, a second
        sweep detects ``HEADING_2`` blocks whose text matches the
        ``Capitolo <ord>`` pattern and registers the next consecutive
        ``HEADING_2`` (if any) as their title partner, so that
        :meth:`refine_reconstruction` can fuse the pair into one node.
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
                # The editorial-proof watermark sits in the same vertical
                # band as the "© Wolters Kluwer Italia" footer, and tier 1
                # absorbs both into ARTIFACT_FOOTER. Rescue the stamps by
                # matching the textual signature and promoting them to
                # ARTIFACT_STAMP; leave the real footer untouched.
                refined.append(
                    ClassifiedBlock(
                        block_index=verdict.block_index,
                        category=SemanticCategory.ARTIFACT_STAMP,
                        reason="tesauro_stamp_from_footer",
                    )
                )
                continue
            refined.append(verdict)

        self._register_chapter_pairs(refined, extraction)
        return refined

    def refine_reconstruction(
        self,
        document: Document,
        extraction: ExtractionResult,
        classified_blocks: list[ClassifiedBlock],
    ) -> Document:
        """Fuse chapter heading pairs, parse summaries and TOC entries.

        Three responsibilities:

        - **Fuse chapter heading pairs.** Every sibling pair of
          ``HEADING_2`` nodes whose block_indices belong respectively
          to the registered "number" and "title" sets is fused into a
          single node carrying the concatenated text and both indices.
          A pair that is not adjacent (the title node missing, or
          separated by an intervening sibling) emits the
          ``chapter_title_not_adjacent_block_<idx>_page_<p>`` warning
          and is left unmerged.
        - **Parse chapter summaries.** Every ``CHAPTER_SUMMARY`` node
          is parsed by :meth:`_parse_chapter_summary` (en-dash splitter
          + ``(number, title)`` regex, same as Zanichelli). On success
          the node's ``summary_items`` field is populated; on failure
          ``summary_items`` is left ``None`` and a warning is emitted.
        - **Parse TOC entries.** Every ``TOC_GENERAL`` node is parsed
          by :meth:`_parse_toc_general` (``<num>. <title> ... »
          <page>`` regex over the whole block text, multiple matches
          per block). On success ``toc_items`` is populated; on
          failure ``toc_items`` stays ``None`` and a warning is
          emitted.

        Pending warnings queued by :meth:`refine_classification` are
        flushed into ``Document.warnings`` here.
        """
        del extraction, classified_blocks

        new_warnings = list(self._pending_warnings)
        self._pending_warnings = []

        new_roots = self._fuse_and_refine(document.root, new_warnings)

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
        """Pass-through: the Tesauro compendium has no apparatus to resolve.

        The editorial analysis confirms zero footnotes, zero marginals,
        zero example boxes and zero inline cross-references. Every
        node arrives without ``apparatus_refs``; the plugin returns
        the document unchanged.
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
                reason="tesauro_stamp",
            )

        if self._is_toc_general(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.TOC_GENERAL,
                reason="tesauro_toc_general",
            )

        if self._is_summary_signature(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.CHAPTER_SUMMARY,
                reason="tesauro_chapter_summary",
            )

        if self._is_chapter_12pt_signature(view) and len(view.text) <= CHAPTER_HEADING_TEXT_LIMIT:
            text = view.text.strip()
            if not view.primary_is_bold and _CHAPTER_NUMBER_PATTERN.match(text):
                return ClassifiedBlock(
                    block_index=verdict.block_index,
                    category=SemanticCategory.HEADING_2,
                    reason="tesauro_chapter_number",
                )
            if view.primary_is_bold:
                return ClassifiedBlock(
                    block_index=verdict.block_index,
                    category=SemanticCategory.HEADING_2,
                    reason="tesauro_chapter_title",
                )

        if self._is_paragraph_signature(view) and len(view.text) <= PARAGRAPH_HEADING_TEXT_LIMIT:
            if _PARAGRAPH_L2_PATTERN.match(view.text):
                return ClassifiedBlock(
                    block_index=verdict.block_index,
                    category=SemanticCategory.HEADING_4,
                    reason="tesauro_paragraph_l2",
                )
            if _PARAGRAPH_L1_PATTERN.match(view.text):
                return ClassifiedBlock(
                    block_index=verdict.block_index,
                    category=SemanticCategory.HEADING_3,
                    reason="tesauro_paragraph_l1",
                )

        if self._is_body_signature(view):
            if _LIST_ITEM_PATTERN.match(view.text):
                return ClassifiedBlock(
                    block_index=verdict.block_index,
                    category=SemanticCategory.LIST_ITEM,
                    reason="tesauro_list_item",
                )
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.BODY,
                reason="tesauro_body",
            )

        return verdict

    @staticmethod
    def _is_chapter_12pt_signature(view: _BlockView) -> bool:
        return (
            view.primary_font.startswith(BODY_FONT_PREFIX_LT)
            and abs(view.primary_size - CHAPTER_HEADING_SIZE) < 0.1
        )

    @staticmethod
    def _is_paragraph_signature(view: _BlockView) -> bool:
        """A paragraph heading is TimesTenLTStd-Bold at 10.0pt or 10.2pt."""
        if not view.spans:
            return False
        # A heading opens with a bold span; the title spans that follow may
        # be italic, but the leading span carries the number and is bold.
        leading = view.spans[0]
        family_ok = leading.font.startswith(BODY_FONT_PREFIX_LT)
        size_ok = abs(leading.size - PARAGRAPH_L1_SIZE) < 0.3
        bold_ok = bool(leading.flags & CHAPTER_TITLE_BOLD_FLAG_BIT)
        return family_ok and size_ok and bold_ok

    @staticmethod
    def _is_body_signature(view: _BlockView) -> bool:
        return (
            view.primary_font.startswith(BODY_FONT_PREFIX_LT)
            and abs(view.primary_size - BODY_FONT_SIZE) < 0.1
        )

    @staticmethod
    def _is_summary_signature(view: _BlockView) -> bool:
        """Detect a CHAPTER_SUMMARY block.

        Two corroborating signals must hold: an 8.0pt size on the
        leading span, and either the ``Sommario`` label opening the
        text or the presence of a ``SC700`` small-caps span in the
        block. The combination is highly specific to the Tesauro
        compendium: TOC entries use 8.5pt (not 8.0), and the footer
        uses 8.0pt but never opens with ``Sommario``.
        """
        if not view.spans:
            return False
        leading = view.spans[0]
        size_ok = abs(leading.size - SUMMARY_SIZE) < 0.3
        if not size_ok:
            return False
        family_ok = _font_family(leading.font) == BODY_FONT_PREFIX_NON_LT
        if not family_ok:
            return False
        opens_with_label = view.text.lstrip().lower().startswith(_SOMMARIO_LABEL.lower())
        has_sc_span = any("SC700" in span.font for span in view.spans)
        return opens_with_label or has_sc_span

    @staticmethod
    def _is_toc_general(view: _BlockView) -> bool:
        """Detect a TOC_GENERAL block.

        The signature is the non-LT TimesTen family at 8.5pt plus the
        presence of the ``»`` page marker anywhere in the block text.
        Both conditions are necessary: a TimesTen 8.5pt block without
        the marker is not a TOC entry (could be a residual front-matter
        paragraph); the marker without the size signature could be a
        body paragraph quoting a page reference.
        """
        if not view.spans:
            return False
        leading = view.spans[0]
        size_ok = abs(leading.size - TOC_GENERAL_SIZE) < 0.3
        family_ok = _font_family(leading.font) == BODY_FONT_PREFIX_NON_LT
        return size_ok and family_ok and "»" in view.text

    # ------------------------------------------------------------------
    # Chapter heading pair detection

    def _register_chapter_pairs(
        self,
        refined: list[ClassifiedBlock],
        extraction: ExtractionResult,
    ) -> None:
        """Walk the refined verdicts to register chapter heading pairs.

        For every block classified with reason ``tesauro_chapter_number``
        we record its block_index in
        :attr:`_chapter_number_blocks`. We then scan forward in the
        same sweep for the **next non-stamp block** and, if it is a
        ``HEADING_2`` with reason ``tesauro_chapter_title``, we add its
        index to :attr:`_chapter_title_blocks`. The forward scan
        tolerates intervening ``ARTIFACT_STAMP`` blocks because the
        editorial-proof watermark may sit between the two halves of
        the heading in PyMuPDF's reading order.

        The pair registration is consumed by :meth:`refine_reconstruction`.
        """
        del extraction
        n = len(refined)
        for i, verdict in enumerate(refined):
            if verdict.category is not SemanticCategory.HEADING_2:
                continue
            if verdict.reason != "tesauro_chapter_number":
                continue
            self._chapter_number_blocks.add(verdict.block_index)
            for j in range(i + 1, n):
                candidate = refined[j]
                if candidate.category is SemanticCategory.ARTIFACT_STAMP:
                    continue
                if (
                    candidate.category is SemanticCategory.HEADING_2
                    and candidate.reason == "tesauro_chapter_title"
                ):
                    self._chapter_title_blocks.add(candidate.block_index)
                break

    # ------------------------------------------------------------------
    # Tree refinement

    def _fuse_and_refine(self, roots: tuple[Node, ...], warnings: list[str]) -> tuple[Node, ...]:
        """Return a new forest with chapter pairs fused and apparatus parsed."""
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
                fused = self._fuse_chapter_pair(node, partner, warnings)
                new_nodes.append(fused)
                i += 2
                continue
            if self._is_chapter_number_node(node):
                warnings.append(
                    f"{WARNING_PREFIX}:chapter_title_not_adjacent_block_"
                    f"{node.block_indices[0] if node.block_indices else -1}_"
                    f"page_{node.page_index}"
                )
            new_nodes.append(self._refine_node(node, warnings))
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

    def _fuse_chapter_pair(self, number_node: Node, title_node: Node, warnings: list[str]) -> Node:
        """Merge two consecutive ``HEADING_2`` siblings into a single node.

        The number node's text (e.g. ``"Capitolo decimo"``) is
        concatenated with the title node's text (e.g.
        ``"L'AVVISO DI ACCERTAMENTO"``) separated by ``". "`` to give
        ``"Capitolo decimo. L'AVVISO DI ACCERTAMENTO"`` — the natural
        prose form for a screen-reader announcement. ``block_indices``
        carries both blocks. ``children`` is the concatenation of the
        two original children lists, both recursively refined.
        """
        number_text = (number_node.text or "").strip()
        title_text = (title_node.text or "").strip()
        if number_text and title_text:
            merged_text = f"{number_text}. {title_text}"
        elif number_text:
            merged_text = number_text
        else:
            merged_text = title_text or None  # type: ignore[assignment]
        merged_children = tuple(
            self._refine_node(c, warnings) for c in (*number_node.children, *title_node.children)
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

    def _refine_node(self, node: Node, warnings: list[str]) -> Node:
        """Recursively refine ``node`` and its descendants.

        ``CHAPTER_SUMMARY`` nodes are parsed into ``summary_items``.
        ``TOC_GENERAL`` nodes are parsed into ``toc_items``. Other
        nodes are forwarded with refined children only when at least
        one child changed.
        """
        new_children = self._fuse_and_refine(node.children, warnings)

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

        if node.category is SemanticCategory.TOC_GENERAL:
            toc = self._parse_toc_general(node.text)
            if toc is None:
                warnings.append(f"{WARNING_PREFIX}:toc_general_unparseable_node_{node.id}")
            return Node(
                id=node.id,
                category=node.category,
                children=new_children,
                page_index=node.page_index,
                block_indices=node.block_indices,
                text=node.text,
                level=node.level,
                summary_items=None,
                toc_items=toc,
                apparatus_refs=node.apparatus_refs,
            )

        if new_children is node.children:
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

    # ------------------------------------------------------------------
    # Text parsing helpers

    @staticmethod
    def _parse_chapter_summary(text: str | None) -> tuple[SummaryItem, ...] | None:
        """Parse a CHAPTER_SUMMARY text into structured entries, or None.

        Strips the ``Sommario`` label (with the optional trailing
        colon), splits on the en-dash separator, then parses each
        segment with :data:`_SUMMARY_ITEM_PATTERN`. Returns ``None``
        on any structural failure (empty text, unparseable segment,
        blank title after normalisation).
        """
        if text is None:
            return None
        stripped = text.strip()
        if stripped.lower().startswith(_SOMMARIO_LABEL.lower()):
            stripped = stripped[len(_SOMMARIO_LABEL) :].lstrip()
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
            if not title:
                return None
            items.append(SummaryItem(number=match.group("num"), title=title))
        if not items:
            return None
        return tuple(items)

    @staticmethod
    def _parse_toc_general(text: str | None) -> tuple[TocGeneralItem, ...] | None:
        """Parse a TOC_GENERAL text into structured entries, or None.

        Runs :data:`_TOC_ENTRY_PATTERN` as a finditer scan and converts
        each match into a :class:`TocGeneralItem`. Roman-numeral
        page references emit ``page_number: None`` per the design
        decision recorded in ``docs/SCHEMA_v0.4.0.md`` § 3. Returns
        ``None`` when the block produces zero matches — that means the
        plugin recognised the signature but could not extract any
        structured entry, which is worth surfacing as a warning rather
        than emitting an empty list.
        """
        if text is None:
            return None
        cleaned = _DOTTED_LEADER.sub(" ", text)
        items: list[TocGeneralItem] = []
        for match in _TOC_ENTRY_PATTERN.finditer(cleaned):
            title = _INTERNAL_WHITESPACE.sub(" ", match.group("title")).strip()
            if not title:
                continue
            raw_page = match.group("page")
            page_number: int | None
            try:
                page_number = int(raw_page)
            except ValueError:
                page_number = None
            items.append(
                TocGeneralItem(
                    number=match.group("num"),
                    title=title,
                    page_number=page_number,
                )
            )
        if not items:
            return None
        return tuple(items)

    @staticmethod
    def _view(extraction: ExtractionResult, block_index: int) -> _BlockView | None:
        block = extraction.blocks[block_index]
        start, end = block.span_range
        spans = tuple(extraction.spans[start:end])
        if not spans:
            return None
        text = "".join(s.text for s in spans)
        return _BlockView(block_index=block_index, block=block, spans=spans, text=text)
