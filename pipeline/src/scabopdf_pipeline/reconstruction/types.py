"""Reconstruction dataclasses — output of § 5 (structural reconstruction).

See ARCHITECTURE.md § 5 for the canonical specification.

A ``Document`` is the reading-order tree produced by tier 1 generic logic
and optionally refined by a profile plugin's tier 2 in
``refine_reconstruction``. All dataclasses are frozen: once
``reconstruct()`` returns, the tree is immutable. The post-processing
phase (§ 7) returns a new ``Document`` whose ``transformations`` field
carries the reversible log of text rewrites it performed.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import TYPE_CHECKING

from scabopdf_pipeline.extraction.types import PageIndex
from scabopdf_pipeline.schema.categories import NoteLengthCategory, SemanticCategory

if TYPE_CHECKING:
    from scabopdf_pipeline.apparatus.types import ApparatusRef
    from scabopdf_pipeline.postprocessing.types import Transformation


_NOTE_MARKER_STRIP_REGEX = re.compile(r"^\s*\(?\d+\)\s*")
"""Strip the leading numeric marker before measuring NOTE text length.

Matches both the parenthesised form ``(N)`` (Mandrioli, BIC, NS, DT,
EM, ES, codici) and the bare form ``N`` followed by whitespace
(Mosconi, Torrente asterisk-footnote-after-stripping). Identical in
shape to the marker regex used by the empirical analyser
``pipeline/scripts/analyze_note_length_distribution.py`` that decided
the six thresholds.
"""


def compute_note_length_category(text: str | None) -> NoteLengthCategory | None:
    """Compute the acoustic regime of a NOTE Node from its text.

    Strips the leading numeric marker via :data:`_NOTE_MARKER_STRIP_REGEX`
    before measuring ``len()``. Returns ``None`` for ``text is None`` and
    for empty strings, otherwise one of the six closed values of
    :data:`scabopdf_pipeline.schema.contract.NoteLengthCategory`.

    The thresholds are the empirically-decided 50 / 100 / 500 / 1000 /
    3000 boundaries (see ``docs/SCHEMA_v0.6.0.md`` § 3 for the
    motivation): they partition the cross-corpus distribution into
    proportions ~10 % / ~19 % / ~50 % / ~14 % / ~7 % / ~1 % so that
    Layer 2's verbal intro lands at sensible frequencies and never feels
    like a constant warning. ``None`` is reserved for the absence of a
    measurable text (synthetic ``EMPTY_PAGE`` carries ``text=None``);
    every other NOTE Node receives a categorical value.
    """
    if text is None:
        return None
    stripped = _NOTE_MARKER_STRIP_REGEX.sub("", text)
    n = len(stripped)
    if n == 0:
        return None
    if n < 50:
        return "MICRO"
    if n < 100:
        return "SHORT"
    if n < 500:
        return "MEDIUM"
    if n < 1000:
        return "LONG"
    if n < 3000:
        return "VERY_LONG"
    return "MEGA"


@dataclass(frozen=True, kw_only=True)
class SummaryItem:
    """A single parsed entry of a ``CHAPTER_SUMMARY`` node.

    Mirrors :class:`scabopdf_pipeline.schema.contract.ChapterSummaryItem`
    on the Python side. Produced by a corpus plugin's
    ``refine_reconstruction`` when it recognises and parses a chapter
    summary block. See ``ChapterSummaryItem`` for the rationale of
    ``number`` being a string rather than an integer.
    """

    number: str
    title: str


@dataclass(frozen=True, kw_only=True)
class TocGeneralItem:
    """A single parsed entry of a ``TOC_GENERAL`` node.

    Mirrors :class:`scabopdf_pipeline.schema.contract.TocGeneralItem`
    on the Python side. Produced by a corpus plugin's
    ``refine_reconstruction`` when it recognises and parses a
    document-level table of contents block.

    ``number`` is a string for the same reason as
    :class:`SummaryItem.number`: composite numerations (``"1.1"``,
    ``"2-bis"``) cannot be represented by an integer.

    ``title`` is the textual title of the TOC entry, with internal
    whitespace already normalised by the plugin (single spaces, no
    leading or trailing whitespace, no dotted leader, no line breaks).

    ``page_number`` is the **1-based book page number** printed on the
    TOC line (typically after a typographic marker such as ``»``).
    It is deliberately distinct from the 0-based ``PageIndex`` used
    everywhere else in Layer 1: a book page number is what the manual
    advertises to the reader, not the PDF page index. ``None`` when the
    plugin could not parse a page reference from the entry (a few TOC
    rows may carry a non-numeric pagination such as ``"III"`` that the
    plugin leaves unparsed rather than encoding fragility).
    """

    number: str
    title: str
    page_number: int | None = None


@dataclass(frozen=True, kw_only=True)
class Node:
    """A node in the document reading-order tree.

    ``id`` is unique within the document and deterministic over
    ``reconstruct()`` invocations on the same input. The format is
    ``"node_NNNN"`` zero-padded on the emission order.

    ``page_index`` is the page number of the originating block, using the
    same numbering as ``extraction.Block.page``. For synthetic nodes
    without an originating block (currently only ``EMPTY_PAGE``) it is the
    page being annotated.

    ``block_indices`` lists the flat indices into
    ``ExtractionResult.blocks`` that contributed to this node. A node may
    aggregate several original blocks because of cross-page paragraph
    merging (see ARCHITECTURE.md § 5.5). Synthetic nodes without an
    originating block carry an empty tuple.

    ``text`` is the concatenated text of the originating block(s), produced
    by joining the underlying ``Span.text`` values with no separator inside
    a block and a single space across cross-page-merged blocks. ``text`` is
    ``None`` only for synthetic nodes without a real source block, such as
    ``EMPTY_PAGE``.

    ``level`` is the heading level (1-4) for ``HEADING_N`` nodes, ``None``
    for every other category.

    ``summary_items`` is the tuple of parsed entries for
    ``CHAPTER_SUMMARY`` nodes whose textual content a corpus plugin
    could decompose into structured items, ``None`` for every other
    node type and for ``CHAPTER_SUMMARY`` nodes the plugin chose not to
    parse or could not parse. The converter maps it field-by-field to
    ``NodeDict.items``.

    ``toc_items`` is the symmetric tuple of parsed entries for
    ``TOC_GENERAL`` nodes whose textual content a corpus plugin could
    decompose into a structured list of ``(number, title, page_number)``
    triples. ``None`` for every other node type and for ``TOC_GENERAL``
    nodes the plugin chose not to parse or could not parse. The
    converter maps it field-by-field to ``NodeDict.toc_items``.

    ``apparatus_refs`` lists the relationships inferred during apparatus
    resolution (ARCHITECTURE.md § 6). It is populated by
    ``apparatus.resolve_apparatus`` and stays empty if that step is not
    invoked. The tuple is ordered by emission and may contain refs of
    different kinds on the same node, though tier 1 only produces one ref
    per node.

    ``length_category`` (added at schema 0.6.0) is the acoustic regime
    of a ``NOTE`` Node, one of ``MICRO`` / ``SHORT`` / ``MEDIUM`` /
    ``LONG`` / ``VERY_LONG`` / ``MEGA``. It is computed via
    :func:`compute_note_length_category` from the stripped textual
    content (marker ``(N)`` removed) and serves Layer 2's choice of
    verbal intro before reading the note text aloud. ``None`` for every
    category that is not ``NOTE``, including the sibling
    ``EDITORIAL_NOTE`` whose acoustic regime is deferred to a future
    schema version. The field is populated at minting time by tier 1
    reconstruction (for ``NOTE`` Nodes materialised from a
    ``ClassifiedBlock``) and by each corpus plugin's helper that mints
    synthetic ``NOTE`` Nodes (Mandrioli body+note splitter, BIC
    multi-block splitter and continuation rescuer, NS / DT
    multi-sibling notes consolidator, codici multi-note splitter,
    Mosconi cross-page consolidator); the apparatus resolver preserves
    the value through its mutable / immutable round-trip, and the
    post-processing ``merge_cross_page_notes`` step recomputes it on
    the surviving head when a continuation extends the text.
    """

    id: str
    category: SemanticCategory
    children: tuple[Node, ...] = ()
    page_index: PageIndex
    block_indices: tuple[int, ...] = ()
    text: str | None = None
    level: int | None = None
    summary_items: tuple[SummaryItem, ...] | None = None
    toc_items: tuple[TocGeneralItem, ...] | None = None
    length_category: NoteLengthCategory | None = None
    apparatus_refs: tuple[ApparatusRef, ...] = ()


@dataclass(frozen=True, kw_only=True)
class Document:
    """The reconstructed reading-order tree.

    ``root`` is the top-level node sequence. The tree is rigorously typed:
    every ``Node.children`` is a tuple, so the structure is deeply
    immutable.

    ``warnings`` is a tuple of short identifiers emitted during tier 1
    hierarchy assembly. The tier 1 vocabulary is closed (see
    ``reconstruction.tier1.TIER1_WARNING_TEMPLATES``); tier 2 plugins may
    emit any string.

    ``transformations`` is the reversible log of text rewrites the
    post-processing phase (§ 7) recorded on this document. It is empty
    before post-processing runs, populated by
    :func:`scabopdf_pipeline.postprocessing.apply_post_processing` as the
    plugin's declared steps execute, and surfaces in the emitted JSON
    (``ARCHITECTURE.md § 8.6``). Each entry pins together the step ID,
    the node whose text was rewritten, the original substring, the
    normalized replacement, and the half-open ``(start, end)`` offset
    into the Node text *as it was immediately before that
    transformation was applied*. See
    :class:`scabopdf_pipeline.postprocessing.types.Transformation` for
    the full reversibility convention.
    """

    root: tuple[Node, ...] = ()
    warnings: tuple[str, ...] = ()
    transformations: tuple[Transformation, ...] = ()
