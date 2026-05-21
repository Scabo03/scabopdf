"""Constants and helpers shared by the three DeJure corpus plugins.

The three plugins targeting the DeJure / Aspose-Arial-Letter editorial
pipeline — :mod:`dejure_nota_sentenza`, :mod:`dejure_massime`,
:mod:`dejure_dottrina` — share a substantial subset of typographic
constants, regex patterns, helper dataclasses and one helper function.
This module promotes the duplicated parts to a single canonical
location (Stage 2 of the Promotion Analysis Fase 1, P-009/010/011/012/013/015).

The three plugins differ on:

- The 13pt bold Arial title (NS-only signature).
- The genre banner text value (``DOTTRINA`` for DT vs
  ``NOTE E DOTTRINA`` for NS; MM has no banner).
- The bidirectional matches() penalty magnitudes (intentional, see
  pattern (ss) and (vv) of CLAUDE.md).
- Plugin-specific section headings, notes-section consolidation,
  cross-reference minting.

Everything below is byte-equivalent across the three plugins. Plugins
import what they need from this module; the legacy local names remain
as ``from ._dejure_shared import X as Y`` re-aliases at the plugin
level until a future refactor decides whether to drop the alias.
"""

from __future__ import annotations

import re
from collections.abc import Callable, Iterable
from dataclasses import dataclass
from dataclasses import replace as dc_replace

from scabopdf_pipeline.classification.types import ClassifiedBlock
from scabopdf_pipeline.extraction.types import Block, Span
from scabopdf_pipeline.postprocessing.types import Transformation
from scabopdf_pipeline.reconstruction.types import Node
from scabopdf_pipeline.schema.categories import SemanticCategory

# ---------------------------------------------------------------------------
# Typographic constants (P-010, P-011)

ARIAL_FAMILY_PREFIX = "Arial"
"""PyMuPDF prefix shared by every Arial variant the Aspose pipeline emits
(``ArialMT``, ``Arial-BoldMT``, ``Arial-ItalicMT``, ``ArialItalic``).
"""

ARIAL_REGULAR_FAMILY = "ArialMT"
"""Exact PyMuPDF family for the Arial regular body face."""

ARIAL_BOLD_FAMILY = "Arial-BoldMT"
"""Exact PyMuPDF family for the Arial bold face used by the banner and
title spans.
"""

ASPOSE_PRODUCER_FRAGMENT = "Aspose.PDF"
"""Substring identifying the DeJure Aspose pipeline in the PDF producer
or creator field.
"""

# ---------------------------------------------------------------------------
# Banner discrimination via SpecificMarker (P-012)
#
# The three plugins use the same SpecificMarker name; the literal banner
# values differ (DT carries ``DOTTRINA``, NS carries ``NOTE E DOTTRINA``,
# MM has no banner). The constants below cover both directions of the
# bidirectional discrimination.

SPECIFIC_MARKER_BANNER_TEXT_NAME = "dejure_banner_text"
"""Name of the SpecificMarker the real-fixture signal builder emits with
the dominant Arial-BoldMT 9pt banner text scanned on page 0. The three
DeJure plugins consume it in their :meth:`matches` to apply the
bidirectional sibling penalty (pattern (vv) of CLAUDE.md).
"""

BANNER_TEXT_DOTTRINA = "DOTTRINA"
"""Literal banner value the DT fixtures carry."""

BANNER_TEXT_NOTE_E_DOTTRINA = "NOTE E DOTTRINA"
"""Literal banner value the NS fixtures carry."""

# ---------------------------------------------------------------------------
# Regex patterns (P-009, P-015)

FOOTER_PATTERN = re.compile(r"^Pagina\s+\d+\s+di\s+\d+\s*$")
"""Regex that matches the Aspose ``Pagina N di M`` running footer.

The three DeJure plugins use it verbatim in their ARTIFACT_FOOTER
classifier. Byte-equivalent in all three plugins before promotion.
"""

# ---------------------------------------------------------------------------
# Notes-section marker vocabulary (P-016, Promotion Fase 3)

NOTES_MARKER_TEXT_VARIANTS: tuple[str, ...] = ("Note:", "Note :")
"""Closed set of accepted ``"Note:"`` marker variants for the
``SECTION_LABEL`` that opens the notes region inside a DeJure document.

Aspose has been observed to emit either ``Note:`` (compact) or
``Note :`` (space before the colon) depending on the editorial
template; both variants are admitted. Byte-equivalent across the
NS and DT plugins before promotion.
"""


def starts_with_notes_marker(text: str) -> bool:
    """Return True if ``text`` (after left-strip) opens with a notes marker.

    Promoted from the byte-equivalent ``_starts_with_notes_marker``
    static methods that NS and DT shipped privately. The check is
    intentionally permissive on trailing characters so the section
    label ``"Note:"`` followed by spurious trailing whitespace still
    matches.
    """
    stripped = text.lstrip()
    return any(stripped.startswith(marker) for marker in NOTES_MARKER_TEXT_VARIANTS)


def match_notes_marker(text: str) -> re.Match[str] | None:
    """Return a :class:`re.Match` over the leading notes marker, or ``None``.

    Used by the post-``Note:`` notes-section consolidator to extract
    the exact byte offset and length of the marker substring, so the
    walker can strip the marker from the head text without disturbing
    the encoded surrounding whitespace. Promoted from the byte-equivalent
    ``_match_notes_marker`` static methods of NS and DT.
    """
    stripped = text.lstrip()
    prefix_skip = len(text) - len(stripped)
    for marker in NOTES_MARKER_TEXT_VARIANTS:
        if stripped.startswith(marker):
            pattern = re.compile(re.escape(marker))
            return pattern.match(text, prefix_skip)
    return None


def retag_notes_region_continuation(
    classified_blocks: Iterable[ClassifiedBlock],
    *,
    is_notes_section_label: Callable[[ClassifiedBlock], bool],
    reason: str,
    article_boundary_categories: frozenset[SemanticCategory] = frozenset(),
) -> list[ClassifiedBlock]:
    """Retag ``BODY`` verdicts inside a notes region as ``NOTE``.

    Pattern (pp) of CLAUDE.md: once a ``SECTION_LABEL`` ``Note:`` marker
    has been emitted in reading order, every subsequent ``BODY`` verdict
    belongs to the notes-prose continuation and must be reclassified as
    ``NOTE`` so the tier 1 cross-page paragraph merger does not fuse it
    with the body paragraphs of the enclosing section.

    Parameters
    ----------
    classified_blocks
        The tier 1 verdicts already refined by the plugin's tier 2
        predicate cascade. Iterated once, in document reading order.
    is_notes_section_label
        Predicate invoked only when ``verdict.category is SECTION_LABEL``.
        Returns ``True`` when the verdict's underlying block text opens
        with a notes marker (see :func:`starts_with_notes_marker`).
        Typically a lambda that captures the plugin's ``extraction``
        instance and the plugin's view factory.
    reason
        The ``ClassifiedBlock.reason`` string attached to every retagged
        verdict. Plugin-specific (e.g.
        ``"dejure_nota_sentenza_notes_region_continuation"``).
    article_boundary_categories
        Categories that close any open notes region before the next
        ``Note:`` marker reopens it. The NS plugin uses ``frozenset()``
        (no per-article closure because the NS fixtures carry a single
        notes region per document); the DT plugin uses
        ``frozenset({SemanticCategory.GENRE_BANNER})`` to scope the
        region per-article inside a multi-article bundle.

    Returns
    -------
    A fresh list of ``ClassifiedBlock`` with the same length and the
    same ordering as ``classified_blocks``. Verdicts that are not
    inside an open notes region are returned verbatim.
    """
    in_notes_region = False
    retagged: list[ClassifiedBlock] = []
    for verdict in classified_blocks:
        if verdict.block_index < 0:
            retagged.append(verdict)
            continue
        if verdict.category in article_boundary_categories:
            in_notes_region = False
            retagged.append(verdict)
            continue
        if verdict.category is SemanticCategory.SECTION_LABEL:
            if is_notes_section_label(verdict):
                in_notes_region = True
            retagged.append(verdict)
            continue
        if in_notes_region and verdict.category is SemanticCategory.BODY:
            retagged.append(
                ClassifiedBlock(
                    block_index=verdict.block_index,
                    category=SemanticCategory.NOTE,
                    reason=reason,
                )
            )
            continue
        retagged.append(verdict)
    return retagged


# ---------------------------------------------------------------------------
# Multi-sibling notes-section consolidator (P-017, Promotion Fase 3)

NOTES_SECTION_BOUNDARY_CATEGORIES: frozenset[SemanticCategory] = frozenset(
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
Byte-equivalent across the NS and DT plugins before promotion.
"""

NOTES_SECTION_PASSTHROUGH_CATEGORIES: frozenset[SemanticCategory] = frozenset(
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
Byte-equivalent across the NS and DT plugins before promotion.
"""

NOTES_SECTION_ABSORBABLE_CATEGORIES: frozenset[SemanticCategory] = frozenset(
    {SemanticCategory.BODY, SemanticCategory.NOTE}
)
"""Categories absorbed into the consolidated notes text.

``BODY`` covers the typical case (the post-``Note:`` text emerges as
BODY before the tier 2 retagging promotes it to NOTE); ``NOTE``
covers the case where the retagging in
:func:`retag_notes_region_continuation` has already promoted the
sibling. Byte-equivalent across NS and DT.
"""


SplitNotesTextFn = Callable[[str, int, tuple[int, ...]], list[Node]]
"""Plugin-provided callable that turns the consolidated notes text
into a list of synthetic ``NOTE`` (and optionally ``EDITORIAL_NOTE``)
Nodes. Takes ``(notes_text, page_index, block_indices)``. The plugin
encapsulates inside the closure: the split regex, the marker→category
dispatch, the minter, and the per-mint warning emission. Returns an
empty list when the text is unparseable, in which case the walker
emits the unparseable warning and leaves the anchor Node intact.
"""


def consolidate_notes_section_children(
    children: tuple[Node, ...],
    *,
    split_notes_text_fn: SplitNotesTextFn,
    transformation_step_id: str,
    unparseable_warning: Callable[[str], str],
    warnings: list[str],
    transformations: list[Transformation],
) -> tuple[Node, ...]:
    """Consolidate a notes-section into synthetic NOTE Nodes (pattern (qq)).

    Walks ``children`` looking for a ``SECTION_LABEL`` Node whose text
    opens with one of :data:`NOTES_MARKER_TEXT_VARIANTS`. When found,
    absorbs the post-marker text plus every contiguous ``BODY`` /
    ``NOTE`` sibling (passing through ARTIFACT_FOOTER and similar
    interleaved non-structural siblings) up to the next structural
    boundary, joins the absorbed text with spaces, and invokes the
    plugin-provided ``split_notes_text_fn`` to mint the synthetic
    NOTE (and optionally EDITORIAL_NOTE) Nodes. A single
    :class:`Transformation` is recorded with both ``split_into`` (the
    minted ids) and ``merged_from`` (the absorbed sibling ids) per
    the schema 0.5.0 structural reversibility convention.

    Parameters
    ----------
    children
        The parent Node's ``children`` tuple. Returned reshaped if any
        notes-section is found; otherwise returned verbatim.
    split_notes_text_fn
        Plugin-provided callable. See :data:`SplitNotesTextFn`. The
        plugin closes over the warnings list and the
        :class:`NodeIdMinter` so the walker stays signal-agnostic on
        the split logic.
    transformation_step_id
        The ``Transformation.step_id`` recorded per consolidation. Per
        plugin convention: ``"dejure_<plugin>_notes_section_consolidate"``.
    unparseable_warning
        Callable that builds the diagnostic warning string for the
        unparseable case, taking the anchor Node id. Per plugin
        convention: ``lambda nid: f"plugin:dejure_<plugin>:note_section_unparseable_node_{nid}"``.
    warnings
        Plugin warning list. Appended in place when the unparseable
        case fires.
    transformations
        Plugin transformation list. Appended in place per consolidation.

    Returns
    -------
    A fresh ``tuple[Node, ...]`` with the same ordering as ``children``,
    minus the absorbed siblings, plus the minted synthetic NOTE Nodes
    inserted after the surviving SECTION_LABEL (which keeps just the
    ``"Note:"`` marker text), with the absorbed-passthrough siblings
    re-emitted in reading order after the minted Nodes.
    """
    out: list[Node] = []
    i = 0
    n = len(children)
    while i < n:
        child = children[i]
        if not (
            child.category is SemanticCategory.SECTION_LABEL
            and child.text is not None
            and starts_with_notes_marker(child.text)
        ):
            out.append(child)
            i += 1
            continue

        # Found the SECTION_LABEL marker. Determine the post-marker
        # body of this Node and the contiguous absorbable siblings
        # that follow it in the list.
        marker_match = match_notes_marker(child.text)
        assert marker_match is not None
        marker_end = marker_match.end()
        host_post_text = child.text[marker_end:].strip()

        absorbed_block_indices: list[int] = list(child.block_indices)
        absorbed_text_parts: list[str] = []
        if host_post_text:
            absorbed_text_parts.append(host_post_text)

        j = i + 1
        absorbed_ids: list[str] = []
        passthrough: list[Node] = []
        while j < n:
            sibling = children[j]
            if sibling.category in NOTES_SECTION_BOUNDARY_CATEGORIES:
                break
            if sibling.category in NOTES_SECTION_ABSORBABLE_CATEGORIES and sibling.text is not None:
                absorbed_text_parts.append(sibling.text)
                absorbed_block_indices.extend(sibling.block_indices)
                absorbed_ids.append(sibling.id)
                j += 1
                continue
            if sibling.category in NOTES_SECTION_PASSTHROUGH_CATEGORIES:
                passthrough.append(sibling)
                j += 1
                continue
            # Unknown category — stop absorption to be safe.
            break

        if not absorbed_text_parts:
            # Standalone "Note:" marker with no glued notes and no
            # following absorbable siblings — nothing to consolidate.
            out.append(child)
            i += 1
            continue

        joined_notes_text = " ".join(absorbed_text_parts)
        split_result = split_notes_text_fn(
            joined_notes_text, child.page_index, tuple(absorbed_block_indices)
        )
        if not split_result:
            # Could not parse the notes text — leave the children list
            # intact and emit the plugin's diagnostic warning.
            warnings.append(unparseable_warning(child.id))
            out.append(child)
            i += 1
            continue

        # Surviving SECTION_LABEL keeps just the "Note:" marker text.
        marker_literal = child.text[:marker_end].strip() or "Note:"
        survivor = dc_replace(child, text=marker_literal)

        # Record a single Transformation that documents the
        # multi-sibling absorption.
        transformations.append(
            Transformation(
                step_id=transformation_step_id,
                node_id=child.id,
                page_index=child.page_index,
                position=(marker_end, len(child.text)),
                original=child.text[marker_end:],
                normalized="",
                split_into=tuple(node.id for node in split_result),
                merged_from=tuple(absorbed_ids) or None,
            )
        )

        out.append(survivor)
        out.extend(split_result)
        out.extend(passthrough)
        i = j
    return tuple(out)


# ---------------------------------------------------------------------------
# Helper dataclasses (P-013)


@dataclass(frozen=True)
class BlockView:
    """Pre-computed view of a block exposed to the plugin's tier 2 logic.

    Convention shared by the three DeJure plugins: ``block_index`` +
    ``block`` + ``spans`` + joined ``text``. Predicates inspect the
    leading span via ``view.spans[0]`` and the joined block text via
    ``view.text``.

    Promoted from the three byte-equivalent ``_BlockView`` dataclasses
    that the NS / MM / DT plugins shipped privately. Each plugin
    re-exports it as ``_BlockView = BlockView`` for backward
    compatibility with tests that import the underscore name.
    """

    block_index: int
    block: Block
    spans: tuple[Span, ...]
    text: str


__all__ = [
    "ARIAL_BOLD_FAMILY",
    "ARIAL_FAMILY_PREFIX",
    "ARIAL_REGULAR_FAMILY",
    "ASPOSE_PRODUCER_FRAGMENT",
    "BANNER_TEXT_DOTTRINA",
    "BANNER_TEXT_NOTE_E_DOTTRINA",
    "FOOTER_PATTERN",
    "NOTES_MARKER_TEXT_VARIANTS",
    "NOTES_SECTION_ABSORBABLE_CATEGORIES",
    "NOTES_SECTION_BOUNDARY_CATEGORIES",
    "NOTES_SECTION_PASSTHROUGH_CATEGORIES",
    "SPECIFIC_MARKER_BANNER_TEXT_NAME",
    "BlockView",
    "SplitNotesTextFn",
    "consolidate_notes_section_children",
    "match_notes_marker",
    "retag_notes_region_continuation",
    "starts_with_notes_marker",
]
