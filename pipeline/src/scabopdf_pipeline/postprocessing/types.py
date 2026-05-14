"""Core dataclasses and protocol for the post-processing phase.

See ARCHITECTURE.md § 7 for the canonical specification.

This module exposes two public symbols:

- :class:`Transformation`, the frozen record of a single reversible
  text substitution applied during post-processing.
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
for each ``Transformation``. See ``docs/SCHEMA_v0.4.0.md`` for the same
convention from the schema side.
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
    """A single reversible text substitution recorded by a post-processing step.

    Transformations are reversible: Layer 2 can revert ``original`` from
    ``normalized`` using ``position`` and the length of ``normalized``.
    The pre-step Node text satisfies ``pre[position[0]:position[1]] ==
    original`` and the post-step Node text satisfies
    ``post[position[0]:position[0] + len(normalized)] == normalized``.

    Fields
    ------
    step_id
        Identifier of the post-processing step that produced this
        transformation, matching the step's registration key in
        :class:`PostProcessingRegistry`.
    node_id
        Identifier of the :class:`scabopdf_pipeline.reconstruction.types.Node`
        whose ``text`` was rewritten.
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
    """

    step_id: str
    node_id: str
    page_index: PageIndex
    position: tuple[int, int]
    original: str
    normalized: str


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
