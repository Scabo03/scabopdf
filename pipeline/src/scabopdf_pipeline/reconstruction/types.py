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

from dataclasses import dataclass
from typing import TYPE_CHECKING

from scabopdf_pipeline.schema.categories import SemanticCategory

if TYPE_CHECKING:
    from scabopdf_pipeline.apparatus.types import ApparatusRef
    from scabopdf_pipeline.postprocessing.types import Transformation


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

    ``apparatus_refs`` lists the relationships inferred during apparatus
    resolution (ARCHITECTURE.md § 6). It is populated by
    ``apparatus.resolve_apparatus`` and stays empty if that step is not
    invoked. The tuple is ordered by emission and may contain refs of
    different kinds on the same node, though tier 1 only produces one ref
    per node.
    """

    id: str
    category: SemanticCategory
    children: tuple[Node, ...] = ()
    page_index: int
    block_indices: tuple[int, ...] = ()
    text: str | None = None
    level: int | None = None
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
