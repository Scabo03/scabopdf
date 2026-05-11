"""Reconstruction dataclasses — output of § 5 (structural reconstruction).

See ARCHITECTURE.md § 5 for the canonical specification.

A ``Document`` is the reading-order tree produced by tier 1 generic logic
and optionally refined by a profile plugin's tier 2 in
``refine_reconstruction``. All dataclasses are frozen: once
``reconstruct()`` returns, the tree is immutable.
"""

from __future__ import annotations

from dataclasses import dataclass

from scabopdf_pipeline.schema.categories import SemanticCategory


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
    """

    id: str
    category: SemanticCategory
    children: tuple[Node, ...] = ()
    page_index: int
    block_indices: tuple[int, ...] = ()
    text: str | None = None
    level: int | None = None


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
    """

    root: tuple[Node, ...] = ()
    warnings: tuple[str, ...] = ()
