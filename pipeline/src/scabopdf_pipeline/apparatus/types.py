"""Apparatus dataclasses — output of § 6 (apparatus resolution).

See ARCHITECTURE.md § 6 for the canonical specification.

An ``ApparatusRef`` is attached to a :class:`reconstruction.types.Node` to
record a directed relationship inferred during apparatus resolution: a
cross-reference points at a note, a marginal heading is anchored to a body
node, a marginal gloss is anchored to a note. Each ``ApparatusRef`` carries
the ``id`` of its target node, never the target node itself — refs are
plain string keys so this module has no typed dependency on
``reconstruction.types``.
"""

from __future__ import annotations

from dataclasses import dataclass
from enum import StrEnum


class ApparatusRefKind(StrEnum):
    """Closed enum of relationships produced by tier 1 apparatus resolution."""

    CROSS_REF_TARGET = "CROSS_REF_TARGET"
    """A ``CROSS_REFERENCE`` node points at a ``NOTE`` node."""

    BODY_ASSOCIATION = "BODY_ASSOCIATION"
    """A ``MARGINAL_HEADING`` node is anchored to a body/heading node."""

    GLOSS_TARGET = "GLOSS_TARGET"
    """A ``MARGINAL_GLOSS`` node is anchored to a ``NOTE`` node."""


@dataclass(frozen=True, kw_only=True)
class ApparatusRef:
    """A directed apparatus reference attached to a node.

    ``target_node_id`` is the ``Node.id`` of the destination. ``source_marker``
    carries the textual marker that produced the reference for
    ``CROSS_REF_TARGET`` (e.g. ``"(1)"``) and is ``None`` for the other kinds,
    which are resolved purely from spatial proximity.
    """

    kind: ApparatusRefKind
    target_node_id: str
    source_marker: str | None = None
