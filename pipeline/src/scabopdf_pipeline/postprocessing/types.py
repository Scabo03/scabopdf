"""Core dataclasses and protocol for the post-processing phase.

See ARCHITECTURE.md § 7 for the canonical specification.

This module exposes two public symbols:

- :class:`Transformation`, the frozen record of a single reversible
  text (and, from schema 0.5.0, optionally also structural) operation
  applied during post-processing.
- :data:`PostProcessingStep`, the type alias every step honours.

Both are deliberately minimal: the post-processing architecture stays
data-oriented and lets the orchestrator (``postprocessing.orchestrator``)
own all the control flow. Steps are plain callables, not classes; a
registry (``postprocessing.registry.PostProcessingRegistry``) maps step
IDs to callables.

Reversibility convention for :class:`Transformation`. Each
``Transformation`` records ``original`` as the **literal slice** of the
Node text at indices ``position[0]:position[1]`` **right before** the
transformation was applied (i.e. after every earlier transformation on
the same Node from the same step has already taken effect). When a
single step records several transformations on the same Node, the step
must apply the substitutions **right-to-left** so that the offsets
remain valid for the slices it has not yet rewritten. Layer 2 reverts
the log by walking it in reverse order, replacing
``text[position[0] : position[0] + len(normalized)]`` with ``original``
for each ``Transformation``. See ``docs/SCHEMA_v0.5.0.md`` for the same
convention from the schema side, plus the structural extension below.

Structural reversibility extension (schema 0.5.0). Two optional fields
were added to :class:`Transformation` to record structural changes that
the pre-0.5.0 model could only describe textually: ``split_into`` lists
the ids of synthetic sibling Nodes that a step minted from the host
Node (one BODY decomposed into BODY + N synthetic NOTE siblings, for
example) and ``merged_from`` lists the ids of sibling Nodes that a
step absorbed into the host Node (a chain of marginal-ellipsis
fragments fused into one head, or a cross-page note continuation
fused into its head). Both fields default to ``None`` for steps that
perform purely textual rewrites (``dehyphenate_with_log``). Layer 2 can
walk a 0.5.0 log in reverse and not only revert the textual rewrites
but also rematerialise the consumed or produced sibling Nodes.
"""

from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass
from typing import TYPE_CHECKING

from scabopdf_pipeline.extraction.types import PageIndex

if TYPE_CHECKING:
    from scabopdf_pipeline.classification.types import ClassifiedBlock
    from scabopdf_pipeline.extraction.types import ExtractionResult
    from scabopdf_pipeline.reconstruction.types import Document


@dataclass(frozen=True, kw_only=True)
class Transformation:
    """A single reversible operation recorded by a post-processing or tier 2 step.

    Transformations are reversible: Layer 2 can revert ``original`` from
    ``normalized`` using ``position`` and the length of ``normalized``.
    The pre-step Node text satisfies ``pre[position[0]:position[1]] ==
    original`` and the post-step Node text satisfies
    ``post[position[0]:position[0] + len(normalized)] == normalized``.

    Fields
    ------
    step_id
        Identifier of the step that produced this transformation. For
        post-processing steps this matches the step's registration key
        in :class:`PostProcessingRegistry`; for tier 2 plugin
        transformations recorded during ``refine_reconstruction``
        (e.g. the Giappichelli body+note splitter) this is the
        plugin-defined string conventionally prefixed with the plugin
        identifier.
    node_id
        Identifier of the :class:`scabopdf_pipeline.reconstruction.types.Node`
        whose ``text`` was rewritten (or, for a pure structural
        transformation, the surviving Node carrying the operation in
        the post-step tree).
    page_index
        Page index of the node (same convention as ``Node.page_index``).
    position
        Half-open ``(start, end)`` offset into the Node text **as it was
        immediately before this transformation was applied**. Within a
        single step that records several transformations on the same
        Node, the step must apply substitutions right-to-left so that
        the offsets of yet-to-be-applied substitutions remain valid.
    original
        Literal slice of the pre-transformation text. This is the raw
        substring including any embedded ``\\n`` or soft hyphen — not a
        cleaned-up form of the original word. Carries everything Layer 2
        needs to restore the source byte-for-byte.
    normalized
        Text that replaces ``original`` in the Node after the
        transformation.
    split_into
        Tuple of ids of synthetic sibling Nodes that this transformation
        minted from the host Node. Populated by structural steps that
        decompose a Node (the Giappichelli body+note splitter mints one
        synthetic ``NOTE`` Node per glued segment recovered from a
        single ``BODY`` Node). ``None`` for purely textual transformations.
    merged_from
        Tuple of ids of sibling Nodes that this transformation absorbed
        into the host Node. Populated by structural steps that fuse
        Nodes (the Mosconi marginal-ellipsis merger absorbs continuation
        fragments into a head; the Giappichelli cross-page note merger
        absorbs a continuation NOTE into its head NOTE). ``None`` for
        purely textual transformations.
    """

    step_id: str
    node_id: str
    page_index: PageIndex
    position: tuple[int, int]
    original: str
    normalized: str
    split_into: tuple[str, ...] | None = None
    merged_from: tuple[str, ...] | None = None


PostProcessingStep = Callable[
    ["Document", "ExtractionResult", list["ClassifiedBlock"]],
    tuple["Document", tuple[Transformation, ...]],
]
"""Signature every post-processing step honours.

A step receives the current :class:`Document` (already enriched by any
earlier steps in the plugin's declared order), the original
:class:`ExtractionResult` and the post-classification block list, and
returns a tuple ``(new_document, new_transformations)``.

The returned ``new_transformations`` tuple is the log of substitutions
**this** step performed — not the cumulative log. The orchestrator
concatenates the per-step tuples into ``Document.transformations``.

Steps are pure functions: they never mutate their inputs and never
read external state (filesystem, network, clocks). Determinism on the
same input is part of the contract.
"""
