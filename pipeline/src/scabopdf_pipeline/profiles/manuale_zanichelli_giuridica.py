"""Corpus plugin for the Zanichelli "Diritto delle imprese e delle società" manual.

First real corpus plugin of the project. Handles Patriarca-Benazzo
(Zanichelli, Editoria Giuridica, Torino, 2022) — see
``docs/analysis/ANALYSIS_PATRIARCA_BENAZZO.md`` for the editorial
analysis the plugin is built against.

The manual is the simplest of the analysed corpus by a long margin:
single-column body in Times New Roman 11pt at 81 % typographic
dominance, no apparatus (zero footnotes, zero marginals, zero
example boxes), no inline cross-references. The only auxiliary
structure is a per-chapter "Sommario" in Helvetica 9pt that lists the
paragraphs of the chapter.

Three heading levels:

- **H1 — chapter.** Single span in ``TimesNewRomanPSMT`` 19pt regular,
  text matches ``^Capitolo [IVXLCDM]+``.
- **H2 — section** (only chapters XIII and XIX). Single span in the
  same ``TimesNewRomanPSMT`` 19pt signature, text matches
  ``^Sezione [ABC]``.
- **H3 — paragraph.** Single span in ``TimesNewRomanPS-BoldMT`` 12pt,
  text matches ``^\\d+\\.\\s+\\w`` (the generic PARAGRAPH pattern in
  ``classification.headings``).

The H3 signature ``TimesNewRomanPS-BoldMT`` 12pt is shared with the
front-matter ``Sommario generale`` (pp. 5-18) where it labels chapter
entries; the disambiguation is made by checking that the block is
isolated (one short line, ``^\\d+\\.``). Pure summary entries are
inside larger blocks and do not match the heading pattern.

The chapter ``CHAPTER_SUMMARY`` block is detected by the presence of
any Helvetica 9pt span (Bold for the "Sommario" label or numeric
markers, Light for the entries) and parsed into a list of
``SummaryItem(number, title)`` via the en-dash separator the manual
uses uniformly. When parsing fails the node is still emitted with
``summary_items=None`` and a ``plugin:zanichelli:chapter_summary_unparseable``
warning is recorded.

The plugin keeps a small bag of pending warnings as instance state
between :meth:`refine_classification` and :meth:`refine_reconstruction`
because the API surfaces of those two hooks return narrowly scoped
objects (a list of ``ClassifiedBlock`` and a ``Document``) and warnings
discovered during classification need a channel to bubble up to
``Document.warnings``. The state is consumed and cleared by
``refine_reconstruction`` and never persisted across multiple
end-to-end runs of the same plugin instance — a caller that reuses the
instance must re-run the whole pipeline.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import ClassVar

from scabopdf_pipeline.classification.headings import HeadingKind, detect_heading_pattern
from scabopdf_pipeline.classification.types import ClassifiedBlock
from scabopdf_pipeline.extraction.types import Block, ExtractionResult, Span
from scabopdf_pipeline.profiling.plugin import ProfilePlugin
from scabopdf_pipeline.profiling.profile import DisabledLayout
from scabopdf_pipeline.profiling.signals import ProfilingSignals
from scabopdf_pipeline.reconstruction.types import Document, Node, SummaryItem
from scabopdf_pipeline.schema.categories import SemanticCategory

WARNING_PREFIX = "plugin:zanichelli"
"""Common prefix for every warning string this plugin may emit.

The closed vocabulary lives in :data:`WARNING_TEMPLATES`. See
``docs/SCHEMA_v0.3.0.md § 6`` for the rationale of the prefix
convention.
"""

WARNING_TEMPLATES: tuple[str, ...] = (
    "plugin:zanichelli:chapter_summary_unparseable_node_<id>",
    "plugin:zanichelli:chapter_summary_without_chapter_node_<id>_page_<p>",
    "plugin:zanichelli:heading_19pt_pattern_unmatched_block_<idx>_page_<p>",
)
"""Closed vocabulary of warnings the plugin may emit on ``Document.warnings``.

The placeholders ``<id>``, ``<p>``, ``<idx>`` are replaced with
concrete values at emission time. Plugins consuming these warnings
should match the prefix rather than the exact template.
"""

CHAPTER_HEADING_PATTERN = re.compile(r"^Capitolo\s+[IVXLCDM]+")
"""Regex for the H1 textual marker on Patriarca-Benazzo.

Roman numerals up to ``MMM…``; the chapter title that often follows
on a second physical line is concatenated to the heading by tier 1
(blocks have no inter-line separator) so the regex deliberately does
not require a word boundary after the numerals.
"""

SECTION_HEADING_PATTERN = re.compile(r"^Sezione\s+[A-Z]")
"""Regex for the H2 textual marker on Patriarca-Benazzo.

Single capital letter (A, B, C in the fixture; broader range for
forward compatibility). No word boundary is required after the
letter because the section title runs into the same block without
separator and would otherwise defeat ``\\b``.
"""

CHAPTER_HEADING_FONT = "TimesNewRomanPSMT"
"""Font name of the H1 / H2 heading signature."""

CHAPTER_HEADING_SIZE = 19.0
"""Font size of the H1 / H2 heading signature, in points."""

PARAGRAPH_HEADING_FONT = "TimesNewRomanPS-BoldMT"
"""Font name of the H3 heading signature."""

PARAGRAPH_HEADING_SIZE = 12.0
"""Font size of the H3 heading signature, in points."""

BODY_FONT_PREFIX = "TimesNewRomanPS"
"""Prefix shared by every Times New Roman variant used for body text."""

BODY_FONT_SIZE = 11.0
"""Font size of the body signature, in points."""

SUMMARY_FONT_PREFIX = "Helvetica"
"""Family prefix of the chapter-summary signature (Bold and Light variants)."""

SUMMARY_FONT_SIZE = 9.0
"""Font size of the chapter-summary signature, in points."""

CHAPTER_HEADING_TEXT_LIMIT = 120
"""Maximum text length for a candidate H1/H2 block.

The chapter heading occupies one or two short lines (``Capitolo I``,
``IMPRENDITORE E IMPRESA``). A block sharing the 19pt signature but
carrying significantly more text is almost certainly a layout glitch
and is not promoted to H1 / H2.
"""

PARAGRAPH_HEADING_TEXT_LIMIT = 200
"""Maximum text length for a candidate H3 block.

H3 headings are one-liners (``3. Le forme del trasferimento``).
Front-matter ``Sommario generale`` entries share the 12pt bold
signature but typically run past this limit when they wrap to several
lines per entry.
"""

CONFIDENCE_BODY_DOMINANT = 0.5
"""Confidence contribution when Times New Roman 11pt dominates the body."""

CONFIDENCE_SUMMARY_FONT = 0.20
"""Confidence contribution when a Helvetica 9pt signature is present."""

CONFIDENCE_STRIPPED_METADATA = 0.10
"""Confidence contribution when Producer and Creator are both empty."""

CONFIDENCE_PAGE_SIZE = 0.05
"""Confidence contribution when the page size matches the expected geometry."""

CONFIDENCE_OUTLINE_ABSENT = 0.05
"""Confidence contribution when the PDF has no outline."""

EXPECTED_PAGE_WIDTH = 481.89
"""Expected page width of the Patriarca-Benazzo fixture, in points."""

EXPECTED_PAGE_HEIGHT = 680.31
"""Expected page height of the Patriarca-Benazzo fixture, in points."""

PAGE_SIZE_TOLERANCE = 1.0
"""Tolerance (in points) for the page-size diagnostic."""

BODY_DOMINANCE_MIN_PERCENT = 70.0
"""Minimum dominance percentage of Times New Roman 11pt to credit the body marker.

Patriarca-Benazzo measures 81 %; the threshold leaves headroom for
slightly different print runs of the same editorial pipeline.
"""

EN_DASH = "\u2013"
"""En-dash character used as the separator inside chapter summaries.

Kept as an explicit escape so ruff's ``RUF001`` does not flag the
character as ambiguous; the codepoint is the standard Unicode en-dash
(U+2013), which is what the Patriarca typesetting actually emits in
the JSON output read by Layer 2.
"""

_SOMMARIO_LABEL = "Sommario"
"""Textual label that opens every chapter summary block."""

_SUMMARY_SPLITTER = re.compile(rf"\s*{re.escape(EN_DASH)}\s*")
"""Regex that splits the chapter summary text on its en-dash separators.

The separator inside Patriarca's typesetting is the en-dash padded by
single spaces; the regex is tolerant to slightly varying whitespace.
"""

_SUMMARY_ITEM_PATTERN = re.compile(
    r"^\s*(?P<num>\d+(?:\.\d+)*)\.\s*(?P<title>\S.+?)\s*$", re.DOTALL
)
"""Regex that parses one ``CHAPTER_SUMMARY`` entry into ``(number, title)``.

``number`` admits multi-level numerations (``"1.1"``, ``"2.3.4"``) for
forward compatibility with future Zanichelli manuals, even though
Patriarca only emits flat integers. ``re.DOTALL`` lets the title span
across a soft line break that the typesetter occasionally introduces
inside a long entry; ``_INTERNAL_WHITESPACE`` then normalises it to a
single space.
"""

_INTERNAL_WHITESPACE = re.compile(r"\s+")
"""Regex used to collapse runs of whitespace inside a summary item title."""


@dataclass(frozen=True)
class _BlockView:
    """Pre-computed view of a block exposed to the plugin's tier 2 logic.

    Wraps the original ``Block``, its slice of spans and the
    concatenated text. ``primary_font`` and ``primary_size`` reflect
    the first span: Patriarca headings and chapter summaries are
    monolithic single-font blocks, so the first span is enough to
    classify them. ``text`` is the concatenation of every span's text
    (without separators) — exactly the form ``Node.text`` will carry.
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


class ManualeZanichelliGiuridicaProfile(ProfilePlugin):
    """Corpus plugin for the Zanichelli "Diritto delle imprese e delle società" manual."""

    profile_id: ClassVar[str] = "manuale_zanichelli_giuridica"
    editorial_family: ClassVar[str] = "zanichelli"
    genre: ClassVar[str] = "manuale_giuridico"

    def __init__(self) -> None:
        self._pending_warnings: list[str] = []

    @classmethod
    def matches(cls, signals: ProfilingSignals) -> float:
        """Score the document against the Patriarca-Benazzo diagnostic fingerprint.

        Five additive markers, weighted by how diagnostic they are.
        See module docstring for the editorial rationale.
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

        summary_font_present = any(
            font.family.startswith(SUMMARY_FONT_PREFIX) and abs(font.size - SUMMARY_FONT_SIZE) < 0.1
            for font in signals.typographic_signature.fonts
        )
        if summary_font_present:
            score += CONFIDENCE_SUMMARY_FONT

        producer = (signals.producer_creator.producer or "").strip()
        creator = (signals.producer_creator.creator or "").strip()
        if not producer and not creator:
            score += CONFIDENCE_STRIPPED_METADATA

        geom = signals.page_geometry
        if (
            abs(geom.width_pt - EXPECTED_PAGE_WIDTH) <= PAGE_SIZE_TOLERANCE
            and abs(geom.height_pt - EXPECTED_PAGE_HEIGHT) <= PAGE_SIZE_TOLERANCE
        ):
            score += CONFIDENCE_PAGE_SIZE

        if not signals.outline_structure.has_outline:
            score += CONFIDENCE_OUTLINE_ABSENT

        return score

    def get_categories(self) -> set[SemanticCategory]:
        """Closed set of semantic categories the plugin may emit on Patriarca-Benazzo."""
        return {
            SemanticCategory.HEADING_1,
            SemanticCategory.HEADING_2,
            SemanticCategory.HEADING_3,
            SemanticCategory.BODY,
            SemanticCategory.CHAPTER_SUMMARY,
            SemanticCategory.UNCLASSIFIED,
            SemanticCategory.ARTIFACT_FILIGREE,
            SemanticCategory.ARTIFACT_RUNNING_HEADER,
            SemanticCategory.ARTIFACT_FOOTER,
            SemanticCategory.BOOK_PAGE_ANCHOR,
            SemanticCategory.CROSS_REFERENCE,
            SemanticCategory.EMPTY_PAGE,
        }

    def get_post_processing(self) -> list[str]:
        """No post-processing steps: Patriarca is digitally typeset, no OCR cleanup needed."""
        return []

    def get_layouts_disabled(self) -> list[DisabledLayout]:
        """Disable Layout 4: the manual has no inline footnotes."""
        return [
            DisabledLayout(
                layout="L4",
                reason=(
                    "Il manuale non presenta apparato di note: né a piè di pagina, "
                    "né marginali, né a fine paragrafo. Il Layout 4 (Dottrina), "
                    "che si fonda sui marcatori inline delle note, non si applica."
                ),
            )
        ]

    def refine_classification(
        self,
        extraction: ExtractionResult,
        tier1_results: list[ClassifiedBlock],
    ) -> list[ClassifiedBlock]:
        """Promote UNCLASSIFIED blocks to HEADING_1/2/3, BODY or CHAPTER_SUMMARY.

        The classifier only touches blocks tier 1 left as
        ``UNCLASSIFIED``; verdicts for filigree, running header,
        footer, book-page anchor and cross-reference are preserved.

        See module docstring for the typographic signatures and
        textual patterns each level uses.
        """
        self._pending_warnings = []
        refined: list[ClassifiedBlock] = []
        for verdict in tier1_results:
            if verdict.block_index < 0:
                refined.append(verdict)
                continue
            if verdict.category is not SemanticCategory.UNCLASSIFIED:
                refined.append(verdict)
                continue
            view = self._view(extraction, verdict.block_index)
            if view is None:
                refined.append(verdict)
                continue
            refined.append(self._reclassify(verdict, view))
        return refined

    def refine_reconstruction(
        self,
        document: Document,
        extraction: ExtractionResult,
        classified_blocks: list[ClassifiedBlock],
    ) -> Document:
        """Populate ``summary_items`` on parseable CHAPTER_SUMMARY nodes.

        Walks the tree, parses every ``CHAPTER_SUMMARY`` text into a
        list of :class:`SummaryItem`, replaces the node with a copy
        carrying the populated tuple. Unparseable summaries are left
        with ``summary_items=None`` and a warning is recorded.

        Also flushes the pending warnings accumulated by
        :meth:`refine_classification` into ``Document.warnings``.
        """
        del extraction, classified_blocks
        new_warnings = list(self._pending_warnings)
        self._pending_warnings = []
        new_roots = tuple(self._refine_node(root, new_warnings) for root in document.root)
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
        """Pass-through: Patriarca-Benazzo has zero apparatus to resolve.

        The editorial analysis confirms the manual carries no
        footnotes, no marginals, no example boxes and no inline
        cross-references. Every node already arrives without
        ``apparatus_refs``; the plugin returns the document unchanged.
        """
        del extraction, classified_blocks
        return document

    def _reclassify(self, verdict: ClassifiedBlock, view: _BlockView) -> ClassifiedBlock:
        if self._is_summary_signature(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.CHAPTER_SUMMARY,
                reason="zanichelli_summary_helvetica_9pt",
            )
        if self._is_chapter_signature(view):
            return self._classify_chapter_block(verdict, view)
        if self._is_paragraph_signature(view):
            if detect_heading_pattern(view.text) is HeadingKind.PARAGRAPH and (
                len(view.text) <= PARAGRAPH_HEADING_TEXT_LIMIT
            ):
                return ClassifiedBlock(
                    block_index=verdict.block_index,
                    category=SemanticCategory.HEADING_3,
                    reason="zanichelli_heading_3_paragraph",
                )
            return verdict
        if self._is_body_signature(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.BODY,
                reason="zanichelli_body",
            )
        return verdict

    def _classify_chapter_block(
        self, verdict: ClassifiedBlock, view: _BlockView
    ) -> ClassifiedBlock:
        if len(view.text) > CHAPTER_HEADING_TEXT_LIMIT:
            return verdict
        if CHAPTER_HEADING_PATTERN.match(view.text):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.HEADING_1,
                reason="zanichelli_heading_1_chapter",
            )
        if SECTION_HEADING_PATTERN.match(view.text):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.HEADING_2,
                reason="zanichelli_heading_2_section",
            )
        self._pending_warnings.append(
            f"{WARNING_PREFIX}:heading_19pt_pattern_unmatched_block_"
            f"{verdict.block_index}_page_{view.block.page}"
        )
        return verdict

    @staticmethod
    def _is_chapter_signature(view: _BlockView) -> bool:
        return (
            view.primary_font == CHAPTER_HEADING_FONT
            and abs(view.primary_size - CHAPTER_HEADING_SIZE) < 0.1
        )

    @staticmethod
    def _is_paragraph_signature(view: _BlockView) -> bool:
        return (
            view.primary_font == PARAGRAPH_HEADING_FONT
            and abs(view.primary_size - PARAGRAPH_HEADING_SIZE) < 0.1
        )

    @staticmethod
    def _is_body_signature(view: _BlockView) -> bool:
        return (
            view.primary_font.startswith(BODY_FONT_PREFIX)
            and abs(view.primary_size - BODY_FONT_SIZE) < 0.1
        )

    @staticmethod
    def _is_summary_signature(view: _BlockView) -> bool:
        return any(
            span.font.startswith(SUMMARY_FONT_PREFIX) and abs(span.size - SUMMARY_FONT_SIZE) < 0.1
            for span in view.spans
        )

    @staticmethod
    def _view(extraction: ExtractionResult, block_index: int) -> _BlockView | None:
        block = extraction.blocks[block_index]
        start, end = block.span_range
        spans = tuple(extraction.spans[start:end])
        if not spans:
            return None
        text = "".join(s.text for s in spans)
        return _BlockView(block_index=block_index, block=block, spans=spans, text=text)

    def _refine_node(self, node: Node, warnings: list[str]) -> Node:
        new_children = tuple(self._refine_node(c, warnings) for c in node.children)
        if node.category is SemanticCategory.CHAPTER_SUMMARY:
            items = self._parse_chapter_summary(node.text)
            if items is None:
                warnings.append(f"{WARNING_PREFIX}:chapter_summary_unparseable_node_{node.id}")
                summary_items: tuple[SummaryItem, ...] | None = None
            else:
                summary_items = items
            return Node(
                id=node.id,
                category=node.category,
                children=new_children,
                page_index=node.page_index,
                block_indices=node.block_indices,
                text=node.text,
                level=node.level,
                summary_items=summary_items,
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
            apparatus_refs=node.apparatus_refs,
        )

    @staticmethod
    def _parse_chapter_summary(text: str | None) -> tuple[SummaryItem, ...] | None:
        """Parse a CHAPTER_SUMMARY block text into structured entries, or ``None``.

        Strips the leading ``Sommario`` label, splits on the en-dash
        separator, then parses each segment with
        :data:`_SUMMARY_ITEM_PATTERN`. Returns ``None`` (the
        unparseable sentinel) if the block is empty, if no separator
        is present and the block does not match a single-item pattern,
        or if any segment fails to match.
        """
        if text is None:
            return None
        stripped = text.strip()
        if stripped.startswith(_SOMMARIO_LABEL):
            stripped = stripped[len(_SOMMARIO_LABEL) :].lstrip()
        if not stripped:
            return None
        segments = _SUMMARY_SPLITTER.split(stripped)
        items: list[SummaryItem] = []
        for segment in segments:
            segment = segment.strip()
            if not segment:
                return None
            match = _SUMMARY_ITEM_PATTERN.match(segment)
            if match is None:
                return None
            title = _INTERNAL_WHITESPACE.sub(" ", match.group("title")).strip()
            if not title:
                return None
            items.append(SummaryItem(number=match.group("num"), title=title))
        if not items:
            return None
        return tuple(items)
